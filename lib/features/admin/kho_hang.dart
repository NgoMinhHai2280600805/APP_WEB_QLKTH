import 'package:flutter/material.dart';
//import '../../core/db.dartj';
import '../../widgets/drawer.dart';
import '../common/product_detail.dart';
import '../../../main.dart';
//import 'dart:io';
//import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'deleted_products_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/services/product_service.dart';
//import 'package:cloud_firestore/cloud_firestore.dart';
import 'lich_su_cap_nhat.dart';
import 'add_product_screen.dart';
import 'add_stock_screen.dart';
import 'lich_su_nhap_hang.dart';
import 'dart:math';

final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

class KhoHangScreen extends StatefulWidget {
  const KhoHangScreen({super.key});

  @override
  State<KhoHangScreen> createState() => _KhoHangScreenState();
}

class _KhoHangScreenState extends State<KhoHangScreen> with RouteAware {
  final _firebaseService = ProductService();

  List<Map<String, dynamic>> _categories = [];
  Map<String, List<Map<String, dynamic>>> _categoryProducts = {};

  String _searchQuery = "";
  String? _selectedCategoryId;
  List<Map<String, dynamic>> _allProducts = [];

  String formatCurrency(num value) {
    final formatter = NumberFormat("#,###", "vi_VN");
    return formatter.format(value.toInt());
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 🔹 Đăng ký theo dõi khi route này active trở lại
    routeObserver.subscribe(this, ModalRoute.of(context)! as PageRoute);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  // 🔹 Khi quay lại từ trang khác → reload lại dữ liệu
  @override
  void didPopNext() {
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.delayed(const Duration(milliseconds: 150));

    final categories = await _firebaseService.getCategories();
    final products = await _firebaseService.getProducts();

    if (!mounted) return; //   thêm dòng này

    setState(() {
      _categories = categories;
      _allProducts = products;
      final exists = _categories.any(
        (c) => c['id'].toString() == _selectedCategoryId,
      );

      if (!exists) _selectedCategoryId = null;
      _applyFilters();
    });
  }

  // Hàm lọc theo tìm kiếm + danh mục
  void _applyFilters() {
    // Sao chép danh sách sản phẩm gốc
    List<Map<String, dynamic>> result = List.from(_allProducts);

    // 🔹 Lọc theo danh mục (nếu có chọn)
    if (_selectedCategoryId != null) {
      result = result
          .where(
            (p) =>
                (p['category_id']?.toString() ?? '') ==
                (_selectedCategoryId ?? ''),
          )
          .toList();
    }

    // 🔹 Lọc theo từ khóa tìm kiếm
    if (_searchQuery.isNotEmpty) {
      final keyword = _normalize(_searchQuery);
      result = result.where((p) {
        final name = _normalize(p['name'] ?? '');
        return name.contains(keyword);
      }).toList();
    }

    // 🔹 Nhóm sản phẩm theo danh mục (ép toàn bộ key về String)
    final Map<String, List<Map<String, dynamic>>> grouped = {};

    for (var c in _categories) {
      final categoryId = c['id']?.toString() ?? '';
      grouped[categoryId] = result
          .where((p) => (p['category_id']?.toString() ?? '') == categoryId)
          .toList();
    }

    setState(() {
      _categoryProducts = grouped;
    });
  }

  // Hàm bỏ dấu tiếng Việt
  String _normalize(String text) {
    final withDiacritics =
        'áàảãạăắặằẳẵâấầẩẫậđéèẻẽẹêếềểễệíìỉĩịóòỏõọôốồổỗộơớờởỡợúùủũụưứừửữựýỳỷỹỵ';
    final withoutDiacritics =
        'aaaaaaaaaaaaaaaaadeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyy';

    for (int i = 0; i < withDiacritics.length; i++) {
      text = text.replaceAll(withDiacritics[i], withoutDiacritics[i]);
    }
    return text.toLowerCase();
  }

  Future<void> openImportPage() async {
    final url = Uri.parse("https://6a5ebf5eb173.ngrok-free.app/import");

    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception("Không mở được trang nhập hàng");
    }
  }

  Future<void> _showCategoryForm({Map<String, dynamic>? category}) async {
    final parentContext = context;
    final nameController = TextEditingController(text: category?['name'] ?? '');
    final descController = TextEditingController(
      text: category?['description'] ?? '',
    );

    await showDialog(
      context: parentContext,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Text(category == null ? "Thêm danh mục" : "Sửa danh mục"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "Tên danh mục"),
            ),
            TextField(
              controller: descController,
              decoration: const InputDecoration(labelText: "Mô tả"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(parentContext),
            child: const Text("Hủy"),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = nameController.text.trim();
              final newDesc = descController.text.trim();

              // 🔹 Lấy danh mục hiện có từ Firestore
              final all = await _firebaseService.getCategories();

              // 🔹 Kiểm tra trùng tên (không phân biệt hoa thường)
              final duplicate = all.any(
                (c) =>
                    (c['name']?.toString().toLowerCase() ?? '') ==
                        newName.toLowerCase() &&
                    (category == null ||
                        c['id'].toString() != category['id'].toString()),
              );

              if (duplicate) {
                ScaffoldMessenger.of(parentContext).showSnackBar(
                  const SnackBar(content: Text("Tên danh mục đã tồn tại.")),
                );
                return;
              }

              if (category == null) {
                await _firebaseService.addCategory({
                  'name': newName,
                  'description': newDesc,
                });
              } else {
                await _firebaseService.updateCategory(
                  category['id'].toString(),
                  {'name': newName, 'description': newDesc},
                );
              }

              Navigator.pop(parentContext);

              //   Gọi loadData sau khi dialog đóng hẳn
              if (mounted) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _loadData();
                });
              }
            },
            child: const Text("Lưu"),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCategory(dynamic id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: const Text("Xóa danh mục"),
        content: const Text(
          "Nếu bạn xóa danh mục này, tất cả sản phẩm thuộc danh mục cũng sẽ bị xóa. Bạn có chắc chắn không?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Hủy"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Xóa"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final products = await _firebaseService.getProducts();

      // 🔹 So sánh bằng cách ép cả hai về String
      for (var p in products) {
        if (p['category_id']?.toString() == id.toString()) {
          await _firebaseService.softDeleteProduct(p['id'].toString());
        }
      }

      // 🔹 Cũng ép id về String khi xóa category
      await _firebaseService.softDeleteCategory(id.toString());

      if (mounted) _loadData();
    }
  }

  Future<bool?> _showProductForm({
    Map<String, dynamic>? product,
    required String categoryId,
  }) async {
    // Nếu product == null → đang bấm nút + → CHUYỂN QUA TRANG THÊM SẢN PHẨM
    if (product == null) {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AddProductScreen(categoryId: categoryId),
        ),
      );

      if (result == true) {
        _loadData();
        return true;
      }
    }

    // Nếu product != null, không làm gì cả (không hiện popup sửa)
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        drawer: const CustomDrawer(),
        drawerScrimColor: Colors.black.withOpacity(0.6),
        appBar: AppBar(
          title: const Text("Kho hàng"),
          backgroundColor: const Color.fromARGB(255, 243, 19, 191),
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (_) => const HomePage(initialIndex: 0),
                ),
                (route) => false,
              );
            },
          ),
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) async {
                if (value == 'add_category') {
                  _showCategoryForm();
                } else if (value == 'deleted_products') {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DeletedProductsScreen(
                        onRestore: () async {
                          await _loadData();
                        },
                      ),
                    ),
                  );
                  if (mounted) _loadData();
                } else if (value == 'admin_history') {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LichSuCapNhatScreen(),
                    ),
                  );
                } else if (value == 'add_stock_web') {
                  await openImportPage();
                  if (mounted) _loadData();
                } else if (value == 'add_stock_app') {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AddStockScreen()),
                  );
                  if (mounted) _loadData();
                } else if (value == 'history') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LichSuNhapHang()),
                  );
                }
              },

              itemBuilder: (context) => [
                const PopupMenuItem<String>(
                  value: 'add_stock_web',
                  child: Row(
                    children: [
                      //Icon(Icons.add, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('Nhập hàng (từ web)'),
                    ],
                  ),
                ),

                const PopupMenuItem<String>(
                  value: 'add_stock_app',
                  child: Row(
                    children: [
                      //Icon(Icons.add, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('Nhập hàng (nhập tay từ app)'),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'add_category',
                  child: Row(
                    children: [
                      //Icon(Icons.add, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('Thêm danh mục'),
                    ],
                  ),
                ),

                const PopupMenuItem<String>(
                  value: 'history',
                  child: Row(
                    children: [
                      //Icon(Icons.history, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('Lịch sử nhập hàng'),
                    ],
                  ),
                ),

                const PopupMenuItem<String>(
                  value: 'admin_history',
                  child: Row(
                    children: [
                      //Icon(Icons.history, color: Colors.purple),
                      SizedBox(width: 8),
                      Text('Lịch sử cập nhật (Admin)'),
                    ],
                  ),
                ),

                const PopupMenuItem<String>(
                  value: 'deleted_products',
                  child: Row(
                    children: [
                      //Icon(Icons.delete_outline, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Sản phẩm đã xóa'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        body: _categories.isEmpty
            ? const Center(child: Text("Chưa có danh mục nào"))
            : RefreshIndicator(
                onRefresh: _loadData,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          // Ô tìm kiếm — chiếm 7 phần
                          Expanded(
                            flex: 6,
                            child: Container(
                              height: 45,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: TextField(
                                decoration: const InputDecoration(
                                  hintText: "Tìm kiếm sản phẩm...",
                                  prefixIcon: Icon(Icons.search, size: 20),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                ),
                                onChanged: (value) {
                                  setState(() {
                                    _searchQuery = value.trim();
                                    _applyFilters();
                                  });
                                },
                              ),
                            ),
                          ),

                          const SizedBox(width: 10),

                          // Dropdown — chiếm 3 phần
                          Expanded(
                            flex: 4,
                            child: Container(
                              height: 45,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String?>(
                                  value: _selectedCategoryId,
                                  isExpanded: true,
                                  icon: const Icon(Icons.arrow_drop_down),
                                  items: [
                                    const DropdownMenuItem(
                                      value: null,
                                      child: Text("Tất cả"),
                                    ),
                                    ..._categories.map(
                                      (c) => DropdownMenuItem(
                                        value: c['id'].toString(),
                                        child: Text(c['name'] ?? ''),
                                      ),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedCategoryId = value;
                                      _applyFilters();
                                    });
                                  },
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    //   DANH SÁCH SẢN PHẨM ĐÃ LỌC
                    Expanded(
                      //hàm chặn co giãn nd
                      child: ScrollConfiguration(
                        behavior: const ScrollBehavior().copyWith(
                          overscroll: false, // tắt hiệu ứng co giãn
                          physics:
                              const ClampingScrollPhysics(), // khóa cứng scroll
                        ),
                        child: Builder(
                          builder: (_) {
                            // Danh sách danh mục có sản phẩm (đã lọc)
                            final List<Map<String, dynamic>> visibleCategories =
                                _categories.where((cat) {
                                  final prods =
                                      _categoryProducts[cat['id'].toString()] ??
                                      [];
                                  if (_searchQuery.isNotEmpty) {
                                    return prods.isNotEmpty;
                                  }
                                  return true;
                                }).toList();

                            // Nếu đang tìm kiếm mà không có danh mục nào có sản phẩm khớp
                            final noResult =
                                _searchQuery.isNotEmpty &&
                                !visibleCategories.any(
                                  (cat) => (_categoryProducts[cat['id']] ?? [])
                                      .isNotEmpty,
                                );

                            if (noResult) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.only(top: 50),
                                  child: Text(
                                    "Không tìm thấy sản phẩm nào phù hợp",
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                              );
                            }

                            return ListView.builder(
                              itemCount: _selectedCategoryId == null
                                  ? visibleCategories.length
                                  : 1,
                              padding: const EdgeInsets.all(8),
                              itemBuilder: (_, index) {
                                // 🔹 Ép kiểu thủ công cho Dart khỏi suy luận sai
                                final Map<String, dynamic> cat;
                                if (_selectedCategoryId == null) {
                                  cat = Map<String, dynamic>.from(
                                    visibleCategories[index],
                                  );
                                } else {
                                  final found = visibleCategories
                                      .cast<Map<String, dynamic>>()
                                      .firstWhere(
                                        (c) =>
                                            c['id'].toString() ==
                                            _selectedCategoryId,
                                        orElse: () => <String, dynamic>{},
                                      );
                                  cat = Map<String, dynamic>.from(found);
                                }

                                final prods =
                                    _categoryProducts[cat['id'].toString()] ??
                                    [];

                                final displayProducts = [
                                  ...prods,
                                  if (_searchQuery.isEmpty)
                                    {'is_add_button': true},
                                ];

                                // Nếu đang tìm kiếm và danh mục trống → bỏ qua
                                if (_searchQuery.isNotEmpty && prods.isEmpty) {
                                  return const SizedBox.shrink();
                                }
                                return Card(
                                  elevation: 3,
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              cat['name'] ?? '',
                                              style: const TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                                color: Color.fromARGB(
                                                  255,
                                                  255,
                                                  8,
                                                  8,
                                                ),
                                              ),
                                            ),
                                            Row(
                                              children: [
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.edit,
                                                    color: Colors.orange,
                                                  ),
                                                  onPressed: () =>
                                                      _showCategoryForm(
                                                        category: cat,
                                                      ),
                                                ),
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.delete,
                                                    color: Colors.red,
                                                  ),
                                                  onPressed: () =>
                                                      _deleteCategory(
                                                        cat['id'],
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        if ((cat['description'] ?? '')
                                            .toString()
                                            .trim()
                                            .isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 10,
                                            ),
                                            child: Text(
                                              cat['description'],
                                              style: const TextStyle(
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ),

                                        // grid sản phẩm
                                        GridView.builder(
                                          shrinkWrap: true,
                                          physics:
                                              const NeverScrollableScrollPhysics(),
                                          itemCount: displayProducts.length,
                                          gridDelegate:
                                              const SliverGridDelegateWithFixedCrossAxisCount(
                                                crossAxisCount: 2,
                                                mainAxisSpacing: 12,
                                                crossAxisSpacing: 12,
                                                childAspectRatio: 3 / 4,
                                              ),
                                          itemBuilder: (_, i) {
                                            final p = displayProducts[i];
                                            final int quantity =
                                                p['quantity'] ?? 0;
                                            if (p['is_add_button'] == true) {
                                              return InkWell(
                                                onTap: () => _showProductForm(
                                                  categoryId: cat['id']
                                                      .toString(), //   giữ nguyên dạng String
                                                ),
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey.shade200,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                    border: Border.all(
                                                      color:
                                                          Colors.grey.shade400,
                                                    ),
                                                  ),
                                                  child: const Center(
                                                    child: Icon(
                                                      Icons.add,
                                                      size: 48,
                                                      color: Colors.blue,
                                                    ),
                                                  ),
                                                ),
                                              );
                                            }

                                            return InkWell(
                                              onTap: () async {
                                                final updated = await Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) =>
                                                        ProductDetailScreen(
                                                          product: p,
                                                          onUpdate: () async {
                                                            await _loadData(); // reload dữ liệu kho hàng
                                                          },
                                                        ),
                                                  ),
                                                );
                                                if (updated == true)
                                                  _loadData();
                                              },
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black12,
                                                      blurRadius: 4,
                                                      offset: const Offset(
                                                        2,
                                                        2,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                child: Padding(
                                                  padding: const EdgeInsets.all(
                                                    8,
                                                  ),
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      //   ẢNH KHÔNG BỊ ẢNH HƯỞNG
                                                      Expanded(
                                                        child: Container(
                                                          width:
                                                              double.infinity,
                                                          decoration: BoxDecoration(
                                                            color: Colors
                                                                .grey
                                                                .shade300,
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  8,
                                                                ),
                                                            image:
                                                                (p['image'] !=
                                                                        null &&
                                                                    p['image']
                                                                        .toString()
                                                                        .isNotEmpty)
                                                                ? DecorationImage(
                                                                    image: NetworkImage(
                                                                      p['image'],
                                                                    ), //  load từ URL online
                                                                    fit: BoxFit
                                                                        .cover,
                                                                  )
                                                                : null,
                                                          ),
                                                          child:
                                                              (p['image'] ==
                                                                      null ||
                                                                  p['image']
                                                                      .toString()
                                                                      .isEmpty)
                                                              ? const Icon(
                                                                  Icons.image,
                                                                  size: 50,
                                                                  color: Colors
                                                                      .grey,
                                                                )
                                                              : null,
                                                        ),
                                                      ),

                                                      const SizedBox(height: 8),

                                                      // TÊN
                                                      Text(
                                                        "Tên: ${p['name'] ?? ''}",
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 16,
                                                        ),
                                                        maxLines: 2,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),

                                                      const SizedBox(height: 8),

                                                      //   SL
                                                      Text(
                                                        "SL: $quantity",
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 14,
                                                          color: Colors.black87,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 6),

                                                      // Cảnh báo
                                                      if (quantity == 0)
                                                        Container(
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 10,
                                                                vertical: 4,
                                                              ),
                                                          decoration: BoxDecoration(
                                                            color: Colors.red,
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  12,
                                                                ),
                                                            boxShadow: [
                                                              BoxShadow(
                                                                color: Colors
                                                                    .red
                                                                    .withOpacity(
                                                                      0.5,
                                                                    ),
                                                                blurRadius: 4,
                                                                offset:
                                                                    const Offset(
                                                                      2,
                                                                      2,
                                                                    ),
                                                              ),
                                                            ],
                                                          ),
                                                          child: const Text(
                                                            "Hết hàng",
                                                            style: TextStyle(
                                                              color:
                                                                  Colors.white,
                                                              fontSize: 12,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              shadows: [
                                                                Shadow(
                                                                  color: Colors
                                                                      .black26,
                                                                  offset:
                                                                      Offset(
                                                                        1,
                                                                        1,
                                                                      ),
                                                                  blurRadius: 1,
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        )
                                                      else if (quantity < 10)
                                                        const AnimatedLowStockBadge(),

                                                      const SizedBox(height: 8),

                                                      //   GIÁ + NÚT 3 CHẤM
                                                      Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .spaceBetween,
                                                        children: [
                                                          Row(
                                                            children: [
                                                              const Text(
                                                                "Giá: ",
                                                                style: TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  color: Colors
                                                                      .black,
                                                                  fontSize: 14,
                                                                ),
                                                              ),
                                                              Text(
                                                                "${formatCurrency(p['price'] ?? 0)} đ",
                                                                style: const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  color: Colors
                                                                      .green,
                                                                  fontSize: 14,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                          PopupMenuButton(
                                                            icon: const Icon(
                                                              Icons.more_vert,
                                                            ),
                                                            onSelected: (value) async {
                                                              if (value ==
                                                                  'edit') {
                                                                final updated = await Navigator.push(
                                                                  context,
                                                                  MaterialPageRoute(
                                                                    builder: (_) => ProductDetailScreen(
                                                                      product:
                                                                          p,
                                                                      onUpdate:
                                                                          () async {
                                                                            await _loadData(); // reload dữ liệu kho hàng
                                                                          },
                                                                    ),
                                                                  ),
                                                                );
                                                                if (updated ==
                                                                    true)
                                                                  _loadData(); // reload nếu đã lưu thay đổi
                                                              } else if (value ==
                                                                  'delete') {
                                                                await _firebaseService
                                                                    .softDeleteProduct(
                                                                      p['id'],
                                                                    );
                                                                if (mounted)
                                                                  _loadData();
                                                              }
                                                            },

                                                            itemBuilder: (context) => [
                                                              const PopupMenuItem(
                                                                value: 'edit',
                                                                child: Row(
                                                                  children: [
                                                                    Icon(
                                                                      Icons
                                                                          .edit,
                                                                      color: Colors
                                                                          .orange,
                                                                    ),
                                                                    SizedBox(
                                                                      width: 8,
                                                                    ),
                                                                    Text(
                                                                      "Chỉnh sửa",
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                              const PopupMenuItem(
                                                                value: 'delete',
                                                                child: Row(
                                                                  children: [
                                                                    Icon(
                                                                      Icons
                                                                          .delete,
                                                                      color: Colors
                                                                          .red,
                                                                    ),
                                                                    SizedBox(
                                                                      width: 8,
                                                                    ),
                                                                    Text("Xóa"),
                                                                  ],
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class AnimatedLowStockBadge extends StatefulWidget {
  const AnimatedLowStockBadge({super.key});

  @override
  State<AnimatedLowStockBadge> createState() => _AnimatedLowStockBadgeState();
}

class _AnimatedLowStockBadgeState extends State<AnimatedLowStockBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<_Particle> particles;
  final int particleCount = 6;

  @override
  void initState() {
    super.initState();

    // Controller để lắc
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    // Tạo các hạt bay xung quanh
    particles = List.generate(particleCount, (_) => _Particle());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final angle = 0.03 * sin(2 * pi * _controller.value);
            return Transform.rotate(
              angle: angle, // lắc trái-phải
              child: child,
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFA726), Color(0xFFFF5722)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withOpacity(0.5),
                  blurRadius: 4,
                  offset: const Offset(2, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 14,
                  color: Colors.white,
                ),
                SizedBox(width: 4),
                Text(
                  "Sắp hết hàng",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        color: Colors.black26,
                        offset: Offset(1, 1),
                        blurRadius: 1,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // hạt bay xung quanh
        ...particles.map((p) {
          final posX = p.offset.dx + Random().nextDouble() * 4 - 2;
          final posY = p.offset.dy + Random().nextDouble() * 4 - 2;
          return Positioned(
            left: posX,
            top: posY,
            child: Opacity(
              opacity: p.opacity,
              child: Container(
                width: p.size,
                height: p.size,
                decoration: BoxDecoration(
                  color: Colors.yellowAccent.withOpacity(0.8),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          );
        }).toList(),
      ],
    );
  }
}

class _Particle {
  Offset offset;
  double size;
  double opacity;

  _Particle()
    : offset = Offset(Random().nextDouble() * 40, Random().nextDouble() * 10),
      size = Random().nextDouble() * 3 + 2,
      opacity = Random().nextDouble() * 0.8 + 0.2;
}
