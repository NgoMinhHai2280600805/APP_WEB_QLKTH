import 'package:flutter/material.dart';
import 'dart:io';
import '../../core/current_user.dart';
import '../../core/services/product_service.dart';

class QuickUpdateScreen extends StatefulWidget {
  const QuickUpdateScreen({super.key});

  @override
  State<QuickUpdateScreen> createState() => _QuickUpdateScreenState();
}

class _QuickUpdateScreenState extends State<QuickUpdateScreen> {
  final _productService = ProductService();

  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _categories = [];
  List<TextEditingController> _controllers = [];
  List<Map<String, dynamic>> _originalProducts = [];

  String _searchQuery = "";
  String? _selectedCategoryId;
  bool _isSavingAll = false;

  @override
  void initState() {
    super.initState();
    _loadProductsAndCategories();
  }

  ///   Dùng ProductService để lấy dữ liệu thay vì Firestore trực tiếp
  Future<void> _loadProductsAndCategories() async {
    final products = await _productService.getProducts();
    final categories = await _productService.getCategories();

    setState(() {
      _products = products;
      _categories = categories;
      _originalProducts = products
          .map((p) => Map<String, dynamic>.from(p))
          .toList();

      _controllers = _products
          .map(
            (p) => TextEditingController(text: (p['quantity'] ?? 0).toString()),
          )
          .toList();
    });
  }

  ///   Lưu tất cả thay đổi
  Future<void> _saveAll() async {
    print(
      "👀 CurrentUser debug: ${CurrentUser.email} / ${CurrentUser.fullname}",
    );

    setState(() => _isSavingAll = true);
    bool hasError = false;

    for (var i = 0; i < _products.length; i++) {
      try {
        final product = _products[i];
        final id = (product['id'] ?? '').toString();
        if (id.isEmpty) continue;

        //   Sao chép dữ liệu gốc đúng cách để so sánh
        final original = _originalProducts.firstWhere(
          (p) => p['id'] == id,
          orElse: () => {'quantity': -999}, // giá trị mặc định khác biệt
        );

        final oldQty = original['quantity'] ?? 0;
        final newQty = int.tryParse(_controllers[i].text.trim()) ?? 0;

        //   Bắt thay đổi đúng
        if (oldQty != newQty) {
          print("📦 Cập nhật $id: $oldQty ➜ $newQty");

          await _productService.updateProduct(id, {'quantity': newQty});

          //   Ghi lịch sử
          final productPrice =
              double.tryParse(product['price'].toString()) ?? 0;

          // Nếu admin giảm số lượng thì vẫn ghi log nhưng không tính giá
          //final isDecrease = newQty < oldQty;

          await _productService.logAdminUpdateHistory(
            productId: id,
            productName: product['name'] ?? '',
            oldQuantity: oldQty,
            newQuantity: newQty,
            price: productPrice,
            adminName: CurrentUser.fullname ?? '',
            adminEmail: CurrentUser.email ?? CurrentUser.username ?? '',
          );

          //   Cập nhật bộ nhớ cục bộ
          final oriIdx = _originalProducts.indexWhere((p) => p['id'] == id);
          if (oriIdx != -1) _originalProducts[oriIdx]['quantity'] = newQty;
          _products[i]['quantity'] = newQty;
        }
      } catch (e) {
        hasError = true;
        print(" Lỗi khi lưu sản phẩm ${_products[i]['name']}: $e");
      }
    }

    setState(() => _isSavingAll = false);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          hasError
              ? " Có lỗi khi lưu một số sản phẩm (xem Terminal)."
              : " Đã lưu toàn bộ thay đổi!",
        ),
      ),
    );

    await _loadProductsAndCategories();
  }

  List<Map<String, dynamic>> get _filteredProducts {
    return _products.where((p) {
      final name = (p['name'] ?? '').toString().toLowerCase();
      final matchSearch =
          _searchQuery.isEmpty || name.contains(_searchQuery.toLowerCase());
      final matchCategory =
          _selectedCategoryId == null ||
          p['category_id']?.toString() == _selectedCategoryId;
      return matchSearch && matchCategory;
    }).toList();
  }

  Future<void> _showEditQuantityDialog(Map<String, dynamic> product) async {
    final idx = _products.indexWhere((p) => p['id'] == product['id']);
    if (idx == -1) return;

    final currentQty = int.tryParse(_controllers[idx].text) ?? 0;
    final TextEditingController amountController = TextEditingController();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            Future<void> handleChange(bool increase) async {
              final amount = int.tryParse(amountController.text.trim()) ?? 0;
              if (amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Vui lòng nhập số lượng > 0")),
                );
                return;
              }

              int newQty = currentQty;
              if (increase) {
                newQty += amount;
              } else {
                if (amount > currentQty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Không thể giảm vượt quá SL hiện có"),
                    ),
                  );
                  return;
                }
                newQty -= amount;
              }

              Navigator.pop(context);
              setState(() {
                _controllers[idx].text = newQty.toString();
                _products[idx]['quantity'] = newQty;
              });
            }

            return AlertDialog(
              title: Text("Điều chỉnh số lượng - ${product['name'] ?? ''}"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Số lượng hiện tại: $currentQty"),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Số lượng (ví dụ: 5)",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Hủy"),
                ),
                ElevatedButton(
                  onPressed: () => handleChange(false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                  ),
                  child: const Text("Bớt"),
                ),
                ElevatedButton(
                  onPressed: () => handleChange(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                  child: const Text("Thêm"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredProducts;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Cập nhật số lượng nhanh"),
        backgroundColor: const Color.fromARGB(255, 243, 19, 191),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Làm mới",
            onPressed: _loadProductsAndCategories,
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isSavingAll ? null : _saveAll,
        label: _isSavingAll
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text(
                "Lưu tất cả",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
        backgroundColor: const Color.fromARGB(255, 243, 19, 191),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,

      body: Column(
        children: [
          // 🔍 Ô tìm kiếm
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: "Tìm kiếm sản phẩm...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) => setState(() => _searchQuery = value.trim()),
            ),
          ),

          // Dropdown danh mục
          if (_categories.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: DropdownButtonFormField<String?>(
                value: _selectedCategoryId,
                decoration: InputDecoration(
                  labelText: "Lọc theo danh mục",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text("Tất cả"),
                  ),
                  ..._categories.map((c) {
                    return DropdownMenuItem<String?>(
                      value: c['id'] as String?,
                      child: Text(c['name'] ?? ''),
                    );
                  }).toList(),
                ],
                onChanged: (value) {
                  setState(() => _selectedCategoryId = value);
                },
              ),
            ),

          const SizedBox(height: 8),

          // Danh sách sản phẩm
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text(
                      "Không có sản phẩm nào.",
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(
                      color: Colors.grey,
                      thickness: 0.5,
                      indent: 16,
                      endIndent: 16,
                    ),
                    padding: const EdgeInsets.only(bottom: 100),
                    itemBuilder: (_, i) {
                      final p = filtered[i];
                      final idx = _products.indexWhere(
                        (x) => x['id'] == p['id'],
                      );
                      final controller = _controllers[idx];

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child:
                              (p['image'] != null &&
                                  p['image'].toString().isNotEmpty)
                              ? (p['image'].toString().startsWith('http')
                                    ? Image.network(
                                        p['image'],
                                        width: 60,
                                        height: 60,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                          width: 60,
                                          height: 60,
                                          color: Colors.grey.shade300,
                                          child: const Icon(
                                            Icons.image,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      )
                                    : (File(p['image']).existsSync()
                                          ? Image.file(
                                              File(p['image']),
                                              width: 60,
                                              height: 60,
                                              fit: BoxFit.cover,
                                            )
                                          : Container(
                                              width: 60,
                                              height: 60,
                                              color: Colors.grey.shade300,
                                              child: const Icon(
                                                Icons.image,
                                                color: Colors.grey,
                                              ),
                                            )))
                              : Container(
                                  width: 60,
                                  height: 60,
                                  color: Colors.grey.shade300,
                                  child: const Icon(
                                    Icons.image,
                                    color: Colors.grey,
                                  ),
                                ),
                        ),
                        title: Text(
                          p['name'] ?? '',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            "Số lượng: ${p['quantity']}",
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        trailing: SizedBox(
                          width: 120,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              SizedBox(
                                width: 60,
                                child: TextField(
                                  controller: controller,
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  decoration: const InputDecoration(
                                    hintText: "SL",
                                    border: InputBorder.none,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_note),
                                tooltip: "Điều chỉnh (thêm/giảm)",
                                onPressed: () => _showEditQuantityDialog(p),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
