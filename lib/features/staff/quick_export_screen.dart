import 'package:flutter/material.dart';
import '../../../core/services/product_service.dart';
import '../../../core/current_user.dart';

class QuickExportScreen extends StatefulWidget {
  const QuickExportScreen({super.key});

  @override
  State<QuickExportScreen> createState() => _QuickExportScreenState();
}

class _QuickExportScreenState extends State<QuickExportScreen> {
  final _service = ProductService();
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _categories = [];
  final Map<String, TextEditingController> _controllers = {};

  String _searchQuery = '';
  String? _selectedCategoryId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prods = await _service.getProducts();
    final cats = await _service.getCategories();

    setState(() {
      _products = prods;
      _categories = cats;
      for (var p in prods) {
        _controllers[p['id']] = TextEditingController();
      }
    });
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

  Future<void> _save() async {
    setState(() => _isSaving = true);

    for (var p in _products) {
      final val = int.tryParse(_controllers[p['id']]?.text ?? '');
      if (val != null && val > 0) {
        final newQty = (p['quantity'] - val).clamp(0, 999999);
        await _service.updateProduct(p['id'], {'quantity': newQty});
        await _service.logExportHistory(
          productId: p['id'],
          productName: p['name'],
          quantity: val,
          price: double.tryParse(p['price'].toString()) ?? 0,
          remaining: newQty,
          staffName: CurrentUser.fullname ?? '',
          staffEmail: CurrentUser.email ?? CurrentUser.username ?? '',
        );
      }
    }

    setState(() => _isSaving = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("  Đã cập nhật xuất kho thành công")),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredProducts;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Xuất kho nhanh"),
        backgroundColor: Colors.orangeAccent,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: "Làm mới",
          ),
        ],
      ),

      // 💾 Nút lưu nổi
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isSaving ? null : _save,
        label: _isSaving
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
        backgroundColor: const Color.fromARGB(255, 16, 182, 243),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,

      body: Column(
        children: [
          // 🔍 Ô tìm kiếm
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: "Tìm sản phẩm...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
          const SizedBox(height: 6),

          // 🔽 Dropdown danh mục
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
                  const DropdownMenuItem(value: null, child: Text("Tất cả")),
                  ..._categories.map(
                    (c) => DropdownMenuItem(
                      value: c['id'].toString(),
                      child: Text(c['name'] ?? ''),
                    ),
                  ),
                ],
                onChanged: (val) => setState(() => _selectedCategoryId = val),
              ),
            ),
          const SizedBox(height: 8),

          // 🧾 Danh sách sản phẩm (hiển thị như chat)
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text(
                      "Không có sản phẩm nào phù hợp.",
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) => const Divider(
                      color: Colors.grey,
                      thickness: 0.5,
                      indent: 16,
                      endIndent: 16,
                    ),
                    padding: const EdgeInsets.only(bottom: 100),
                    itemBuilder: (_, i) {
                      final p = filtered[i];
                      final imageUrl = p['image']?.toString() ?? '';

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: (imageUrl.startsWith('http'))
                              ? Image.network(
                                  imageUrl,
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
                            "Tồn: ${p['quantity']}",
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        trailing: SizedBox(
                          width: 120,
                          child: TextField(
                            controller: _controllers[p['id']],
                            textAlign: TextAlign.center,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              hintText: "SL xuất",
                              hintStyle: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 8,
                                horizontal: 6,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
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
