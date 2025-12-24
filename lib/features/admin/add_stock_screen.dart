import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/services/product_service.dart';
import 'dart:io'; // để dùng File
import 'package:image_picker/image_picker.dart'; // để dùng ImagePicker và ImageSource
import '../../core/current_user.dart';

class AddStockScreen extends StatefulWidget {
  const AddStockScreen({super.key});

  @override
  State<AddStockScreen> createState() => _AddStockScreenState();
}

class _AddStockScreenState extends State<AddStockScreen> {
  final _firebaseService = ProductService();
  List<StockBatch> batches = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    batches.add(StockBatch(lotNumberController: TextEditingController()));
  }

  @override
  void dispose() {
    for (var batch in batches) batch.dispose();
    super.dispose();
  }

  Future<void> _saveStock() async {
    if (_saving) return;
    setState(() => _saving = true);

    // danh sách để ghi log nhập hàng
    List<Map<String, dynamic>> importLogBatches = [];

    try {
      for (var batch in batches) {
        final batchNumber = batch.lotNumberController.text.trim();

        // entry ghi log của batch
        final batchEntry = {
          'batch_number': batchNumber,
          'products': <Map<String, dynamic>>[], // ⭐ luôn là List Map
        };

        for (var category in batch.categories) {
          for (var product in category.products) {
            final quantity = int.tryParse(product.quantityController.text) ?? 0;
            if (quantity <= 0) continue;

            final mfgDate = product.mfgDate != null
                ? Timestamp.fromDate(product.mfgDate!)
                : null;

            final expDate = product.expDate != null
                ? Timestamp.fromDate(product.expDate!)
                : null;

            // ⭐ 1. Lưu batch vào Firestore như cũ
            await _firebaseService.addProductBatch(product.productId!, {
              'batch_number': batchNumber,
              'quantity': quantity,
              'mfg_date': mfgDate,
              'expiry_date': expDate,
            });

            // ⭐ 2. Ghi vào log
            (batchEntry['products'] as List).add({
              'product_id': product.productId,
              'product_name': product.name, // ✅ đã có
              'category_id': category.categoryId,
              'category_name': category.name, // ✅ đã có
              'quantity': quantity,
              'mfg_date': mfgDate,
              'exp_date': expDate,
            });
          }
        }

        importLogBatches.add(batchEntry);
      }

      // ⭐ 3. Ghi toàn bộ log nhập hàng
      await _firebaseService.logImportHistory(
        batches: importLogBatches,
        adminName: CurrentUser.fullname ?? "Unknown",
        adminEmail: CurrentUser.email ?? "Unknown",
      );

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Lỗi khi lưu: $e")));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _addNewBatch() {
    setState(() {
      batches.add(StockBatch(lotNumberController: TextEditingController()));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Nhập hàng")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: batches.length,
              itemBuilder: (context, batchIndex) {
                final batch = batches[batchIndex];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        TextField(
                          controller: batch.lotNumberController,
                          decoration: const InputDecoration(labelText: "Mã lô"),
                        ),
                        const SizedBox(height: 10),
                        ...batch.categories.asMap().entries.map(
                          (entry) => CategoryInputWidget(
                            category: entry.value,
                            onRemove: () {
                              setState(
                                () => batch.categories.removeAt(entry.key),
                              );
                            },
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            setState(
                              () => batch.categories.add(CategoryInput()),
                            );
                          },
                          icon: const Icon(Icons.add),
                          label: const Text("Thêm danh mục"),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(Icons.add),
              label: const Text("Thêm lô hàng"),
              onPressed: _addNewBatch,
            ),

            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saving ? null : _saveStock,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: _saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text("Lưu tất cả"),
            ),
          ],
        ),
      ),
    );
  }
}

class StockBatch {
  final TextEditingController lotNumberController;
  List<CategoryInput> categories = [];

  StockBatch({required this.lotNumberController});

  void dispose() {
    lotNumberController.dispose();
    for (var c in categories) c.dispose();
  }
}

class CategoryInput {
  String? categoryId;
  String? name;
  List<ProductInput> products = [];

  void dispose() {
    for (var p in products) p.dispose();
  }
}

class ProductInput {
  String? productId;
  String? name;
  final TextEditingController quantityController = TextEditingController();
  DateTime? mfgDate;
  DateTime? expDate;

  void dispose() {
    quantityController.dispose();
  }
}

class CategoryInputWidget extends StatefulWidget {
  final CategoryInput category;
  final VoidCallback onRemove;

  const CategoryInputWidget({
    super.key,
    required this.category,
    required this.onRemove,
  });

  @override
  State<CategoryInputWidget> createState() => _CategoryInputWidgetState();
}

class _CategoryInputWidgetState extends State<CategoryInputWidget> {
  final _firebaseService = ProductService();
  List<Map<String, dynamic>> availableCategories = [];
  List<Map<String, dynamic>> availableProducts = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final cats = await _firebaseService.getCategories();
    setState(() => availableCategories = cats);
  }

  Future<void> _loadProducts(String categoryId) async {
    final products = await _firebaseService.getProducts();
    setState(() {
      availableProducts = products
          .where((p) => p['category_id'] == categoryId)
          .toList();
    });
  }

  DateTime? _categoryMfgDate;
  DateTime? _categoryExpDate;

  Future<void> _pickCategoryMfg() async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2010),
      lastDate: DateTime(2100),
    );
    if (d != null) {
      setState(() {
        _categoryMfgDate = d;
        // áp dụng cho tất cả sản phẩm hiện tại
        for (var p in widget.category.products) {
          p.mfgDate = d;
        }
      });
    }
  }

  Future<void> _pickCategoryExp() async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2010),
      lastDate: DateTime(2100),
    );
    if (d != null) {
      setState(() {
        _categoryExpDate = d;
        for (var p in widget.category.products) {
          p.expDate = d;
        }
      });
    }
  }

  /////
  ///
  ///
  /// phần form thêm danh mục
  Future<Map<String, dynamic>?> _showAddCategoryDialog() async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text("Danh mục mới"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: "Tên"),
                  ),
                  TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(labelText: "Mô tả"),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Hủy"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final newName = nameCtrl.text.trim();
                    if (newName.isEmpty) return;

                    // 🔹 Kiểm tra trùng tên với danh mục hiện có
                    final duplicate = availableCategories.any(
                      (c) =>
                          (c['name']?.toString().toLowerCase() ?? '') ==
                          newName.toLowerCase(),
                    );

                    if (duplicate) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Tên danh mục đã tồn tại."),
                        ),
                      );
                      return;
                    }

                    // 🔹 Thêm danh mục mới
                    final id = await _firebaseService.addCategory({
                      'name': newName,
                      'description': descCtrl.text.trim(),
                    });

                    Navigator.pop(context, {
                      'id': id,
                      'name': newName,
                      'description': descCtrl.text.trim(),
                    });
                  },
                  child: const Text("OK"),
                ),
              ],
            );
          },
        );
      },
    );

    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: Colors.grey[50],
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: widget.category.categoryId,
                    decoration: InputDecoration(
                      labelText: "Chọn danh mục",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),

                    items: [
                      const DropdownMenuItem<String>(
                        value: "__new_category__",
                        child: Row(
                          children: [
                            Icon(Icons.add, color: Colors.blue),
                            SizedBox(width: 6),
                            Text("Danh mục mới"),
                          ],
                        ),
                      ),
                      ...availableCategories.map(
                        (c) => DropdownMenuItem<String>(
                          value: c['id'].toString(),
                          child: Text(c['name']),
                        ),
                      ),
                    ],
                    onChanged: (value) async {
                      if (value == "__new_category__") {
                        final newCat = await _showAddCategoryDialog();
                        if (newCat != null) {
                          setState(() {
                            availableCategories.add(newCat);
                            widget.category.categoryId = newCat['id'];
                            widget.category.name = newCat['name'];
                          });
                          _loadProducts(newCat['id']);
                        }
                        return;
                      }

                      setState(() {
                        widget.category.categoryId = value;
                        widget.category.name = availableCategories.firstWhere(
                          (c) => c['id'] == value,
                          orElse: () => {'name': 'Unknown'},
                        )['name'];
                        widget.category.products.clear();
                      });
                      if (value != null) _loadProducts(value);
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: widget.onRemove,
                ),
              ],
            ),

            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _pickCategoryMfg,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: "Ngày sản xuất chung",
                      ),
                      child: Text(
                        _categoryMfgDate == null
                            ? "Chọn ngày"
                            : DateFormat(
                                'yyyy-MM-dd',
                              ).format(_categoryMfgDate!),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: _pickCategoryExp,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: "Ngày hết hạn chung",
                      ),
                      child: Text(
                        _categoryExpDate == null
                            ? "Chọn ngày"
                            : DateFormat(
                                'yyyy-MM-dd',
                              ).format(_categoryExpDate!),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            ...widget.category.products.asMap().entries.map(
              (entry) => ProductInputWidget(
                categoryId: widget.category.categoryId ?? "",
                product: entry.value,
                availableProducts: availableProducts,
                onRemove: () => setState(
                  () => widget.category.products.removeAt(entry.key),
                ),
              ),
            ),

            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () {
                  if (widget.category.categoryId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Vui lòng chọn danh mục trước"),
                      ),
                    );
                    return;
                  }
                  setState(() {
                    final newProduct = ProductInput();
                    newProduct.mfgDate = _categoryMfgDate;
                    newProduct.expDate = _categoryExpDate;
                    widget.category.products.add(newProduct);
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProductInputWidget extends StatefulWidget {
  final ProductInput product;
  final List<Map<String, dynamic>> availableProducts;
  final VoidCallback onRemove;
  final String categoryId;

  const ProductInputWidget({
    required this.categoryId,
    super.key,
    required this.product,
    required this.availableProducts,
    required this.onRemove,
  });

  @override
  State<ProductInputWidget> createState() => _ProductInputWidgetState();
}

class _ProductInputWidgetState extends State<ProductInputWidget> {
  DateTime? _mfgDate;
  DateTime? _expDate;

  String _formatDate(DateTime? d) =>
      d == null ? "Chọn ngày" : DateFormat('yyyy-MM-dd').format(d);

  Future<void> _pickMfg() async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2010),
      lastDate: DateTime(2100),
    );
    if (d != null)
      setState(() {
        _mfgDate = d;
        widget.product.mfgDate = d;
      });
  }

  Future<void> _pickExp() async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2010),
      lastDate: DateTime(2100),
    );
    if (d != null)
      setState(() {
        _expDate = d;
        widget.product.expDate = d;
      });
  }

  Future<Map<String, dynamic>?> _showAddProductDialog() async {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String? imagePath;

    Future<void> _pickImage() async {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked != null) {
        final file = File(picked.path);
        final url = await ProductService().uploadImage(file);
        if (url != null) {
          imagePath = url;
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Tải ảnh lên thất bại")),
            );
          }
        }
      }
    }

    return await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text("Sản phẩm mới"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () async {
                        await _pickImage();
                        setStateDialog(() {}); // cập nhật image
                      },
                      child: Container(
                        height: 120,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.shade200),
                          image: imagePath != null
                              ? DecorationImage(
                                  image: NetworkImage(imagePath!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: Stack(
                          children: [
                            if (imagePath == null)
                              const Center(
                                child: Text(
                                  "Nhấn để thêm hình ảnh",
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                            if (imagePath != null)
                              Positioned(
                                top: 4,
                                right: 4,
                                child: CircleAvatar(
                                  radius: 14,
                                  backgroundColor: Colors.red,
                                  child: IconButton(
                                    icon: const Icon(
                                      Icons.close,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                    onPressed: () =>
                                        setStateDialog(() => imagePath = null),
                                    padding: EdgeInsets.zero,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: "Tên sản phẩm",
                      ),
                    ),
                    TextField(
                      controller: priceCtrl,
                      decoration: const InputDecoration(labelText: "Giá"),
                      keyboardType: TextInputType.number,
                    ),
                    TextField(
                      controller: descCtrl,
                      decoration: const InputDecoration(labelText: "Mô tả"),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Hủy"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty) return;

                    final id = await ProductService().addProduct({
                      'name': nameCtrl.text.trim(),
                      'price': int.tryParse(priceCtrl.text) ?? 0,
                      'description': descCtrl.text.trim(),
                      'image': imagePath,
                      'category_id': widget.categoryId,
                    });

                    Navigator.pop(context, {
                      'id': id,
                      'name': nameCtrl.text.trim(),
                      'price': int.tryParse(priceCtrl.text) ?? 0,
                      'description': descCtrl.text.trim(),
                      'image': imagePath,
                    });
                  },
                  child: const Text("OK"),
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
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: widget.product.productId,
                    hint: const Text("Chọn sản phẩm"),
                    isExpanded: true, // quan trọng: icon sẽ nằm sát phải
                    decoration: InputDecoration(
                      labelText: "Sản phẩm",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: "__new_product__",
                        child: Row(
                          children: [
                            Icon(Icons.add, color: Colors.blue),
                            SizedBox(width: 6),
                            Text("Sản phẩm mới"),
                          ],
                        ),
                      ),
                      ...widget.availableProducts.map(
                        (p) => DropdownMenuItem<String>(
                          value: p['id'].toString(),
                          child: Text(p['name']),
                        ),
                      ),
                    ],
                    onChanged: (value) async {
                      if (value == "__new_product__") {
                        final newP =
                            await _showAddProductDialog(); // categoryId được truyền
                        if (newP != null) {
                          setState(() {
                            widget.availableProducts.add(newP);
                            widget.product.productId = newP['id'];
                            widget.product.name = newP['name'];
                          });
                        }
                        return;
                      }
                      setState(() => widget.product.productId = value);
                      widget.product.name = widget.availableProducts.firstWhere(
                        (p) => p['id'] == value,
                        orElse: () => {'name': 'Unknown'},
                      )['name'];
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: widget.onRemove,
                ),
              ],
            ),
            TextField(
              controller: widget.product.quantityController,
              decoration: InputDecoration(
                labelText: "Số lượng",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              keyboardType: TextInputType.number,
            ),

            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _pickMfg,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: "Ngày sản xuất",
                      ),
                      child: Text(_formatDate(_mfgDate)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: _pickExp,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: "Ngày hết hạn",
                      ),
                      child: Text(_formatDate(_expDate)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
