import 'package:flutter/material.dart';
import '../../../core/current_user.dart';
import '../../core/services/product_service.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProductDetailScreen extends StatefulWidget {
  final Map<String, dynamic> product;
  final bool isStaffView;
  final VoidCallback? onUpdate;
  const ProductDetailScreen({
    super.key,
    required this.product,
    this.isStaffView = false,
    this.onUpdate,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final _firebaseService = ProductService();

  late Map<String, dynamic> _product;
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _quantityController;
  late TextEditingController _descController;

  bool get isAdmin => !widget.isStaffView && CurrentUser.role == 'admin';

  List<Map<String, dynamic>> _batches = [];
  bool _loadingBatches = true;

  @override
  void initState() {
    super.initState();
    _product = Map<String, dynamic>.from(widget.product);
    _nameController = TextEditingController(text: _product['name']);
    _priceController = TextEditingController(
      text: _product['price'].toString(),
    );
    _quantityController = TextEditingController(
      text: _product['quantity'].toString(),
    );
    _descController = TextEditingController(
      text: _product['description'] ?? '',
    );

    _loadBatches();
  }

  Future<void> _loadBatches() async {
    setState(() => _loadingBatches = true);

    // Lấy tất cả batch chưa xóa
    final allBatches = await _firebaseService.getProductBatches(
      _product['id'].toString(),
    );

    final visibleBatches = allBatches
        .where((b) => b['is_deleted'] != true)
        .toList();

    // Tính tổng số lượng từ batch còn hiển thị
    int totalQty = visibleBatches.fold(0, (sum, b) {
      final qty = b['quantity'] ?? 0;
      return sum + (qty is num ? qty.toInt() : 0);
    });

    setState(() {
      _batches = visibleBatches; // chỉ hiển thị batch chưa xóa
      _loadingBatches = false;
    });

    _quantityController.text = totalQty.toString();
  }

  bool _isSaving = false;

  Future<void> _saveChanges() async {
    if (!isAdmin) return;
    if (_isSaving) return; // chặn nhấn liên tục

    setState(() {
      _isSaving = true; // bật loading
    });

    try {
      // ========= LẤY DANH SÁCH LÔ & TÍNH TỔNG =========
      final batches = await _firebaseService.getProductBatches(
        _product['id'].toString(),
      );

      int totalQty = batches.fold(0, (int sum, b) {
        final qty = b['quantity'] ?? 0;
        return sum + (qty is int ? qty : (qty as num).toInt());
      });

      // số lượng mới
      final int newQty = totalQty;

      // ========= DỮ LIỆU UPDATE =========
      final updated = {
        'name': _nameController.text,
        'price': double.tryParse(_priceController.text) ?? 0,
        'quantity': newQty,
        'description': _descController.text,
        'category_id': _product['category_id'],
        'image': _product['image'],
      };

      // ========= UPDATE SẢN PHẨM =========
      await _firebaseService.updateProduct(_product['id'].toString(), updated);

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Cập nhật thành công")));

      Navigator.pop(context, true); // trả về true → reload Kho Hàng
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false; // tắt loading dù thành công hay lỗi
        });
      }
    }
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return '-';
    try {
      if (timestamp is DateTime)
        return DateFormat('dd/MM/yyyy').format(timestamp);
      if (timestamp is Timestamp)
        return DateFormat('dd/MM/yyyy').format(timestamp.toDate());
      return timestamp.toString();
    } catch (e) {
      return timestamp.toString();
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);

    if (picked != null) {
      final file = File(picked.path);
      final imageUrl = await _firebaseService.uploadImage(file);

      if (imageUrl != null) {
        setState(() => _product['image'] = imageUrl);
        await _firebaseService.updateProduct(_product['id'].toString(), {
          'image': imageUrl,
        });
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Tải ảnh lên thất bại")));
      }
    }
  }

  //
  //
  //lưu khi thoát
  Future<void> _saveChangesOnly() async {
    if (!isAdmin) return;

    final batches = await _firebaseService.getProductBatches(
      _product['id'].toString(),
    );
    int totalQty = batches.fold(0, (int sum, b) {
      final qty = b['quantity'] ?? 0;
      return sum + (qty is int ? qty : (qty as num).toInt());
    });

    final updated = {
      'name': _nameController.text,
      'price': double.tryParse(_priceController.text) ?? 0,
      'quantity': totalQty,
      'description': _descController.text,
      'category_id': _product['category_id'],
      'image': _product['image'],
    };

    await _firebaseService.updateProduct(_product['id'].toString(), updated);
    //ScaffoldMessenger.of(context).showSnackBar(
    //const SnackBar(content: Text("Làm mới thông tin thành công")),
    //);
  }

  bool _isExiting = false;

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_isExiting) return false; // chặn pop liên tục
        _isExiting = true;

        if (isAdmin) {
          await _saveChangesOnly(); // lưu dữ liệu
        }

        if (widget.onUpdate != null) {
          widget.onUpdate!(); // reload kho hàng
        }

        Navigator.pop(context, true);
        return false;
      },

      child: Scaffold(
        appBar: AppBar(
          title: Text(_product['name'] ?? 'Chi tiết sản phẩm'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              if (_isExiting) return;
              _isExiting = true;

              if (isAdmin) {
                await _saveChangesOnly();
              }
              if (widget.onUpdate != null) widget.onUpdate!();
              Navigator.pop(context, true);
            },
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              // Ảnh sản phẩm
              GestureDetector(
                onTap: isAdmin ? _pickImage : null,
                child: Container(
                  height: 180,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey),
                    image:
                        (_product['image'] != null &&
                            _product['image'].toString().isNotEmpty)
                        ? DecorationImage(
                            image: NetworkImage(_product['image']),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child:
                      (_product['image'] == null ||
                          _product['image'].toString().isEmpty)
                      ? const Center(
                          child: Text(
                            "Tải ảnh lên",
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 20),

              // Thông tin sản phẩm
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: "Tên sản phẩm"),
                readOnly: !isAdmin,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Giá (₫)"),
                readOnly: !isAdmin,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _quantityController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: "Số lượng hiện có",
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descController,
                maxLines: 3,
                readOnly: !isAdmin,
                decoration: const InputDecoration(labelText: "Mô tả"),
              ),
              const SizedBox(height: 20),

              // 🔹 Batch list dạng hàng ngang
              const Text(
                "Chi tiết lô hàng",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _loadingBatches
                  ? const Center(child: CircularProgressIndicator())
                  : _batches.isEmpty
                  ? const Text("Chưa có lô hàng") // tổng số lượng = 0
                  : Column(
                      children: _batches.map((batch) {
                        final batchNo = batch['batch_number'] ?? '-';
                        final qty = batch['quantity']?.toString() ?? '-';
                        final mfg = _formatDate(batch['mfg_date']);
                        final exp = _formatDate(batch['exp_date']);
                        final created = _formatDate(batch['created_at']);

                        return Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text("Lô: $batchNo"),
                                      Text("Số lượng: $qty"),
                                      Text("Ngày nhập: $created"),
                                      Text("Ngày SX: $mfg | HSD: $exp"),
                                    ],
                                  ),
                                ),
                                if (isAdmin)
                                  PopupMenuButton<String>(
                                    icon: const Icon(
                                      Icons.more_vert,
                                      color: Colors.blue,
                                    ),
                                    onSelected: (value) async {
                                      if (value == 'edit') {
                                        final result = await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => BatchEditScreen(
                                              batch: Map<String, dynamic>.from(
                                                batch,
                                              ),
                                              productId: _product['id']
                                                  .toString(),
                                            ),
                                          ),
                                        );

                                        if (result == true) {
                                          await _loadBatches(); // reload batch
                                          if (widget.onUpdate != null)
                                            widget
                                                .onUpdate!(); // reload kho hàng
                                        }
                                      } else if (value == 'delete') {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (_) => AlertDialog(
                                            title: const Text('Xác nhận xóa'),
                                            content: Text(
                                              'Bạn có chắc chắn muốn xóa lô "$batchNo"?',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(
                                                  context,
                                                  false,
                                                ),
                                                child: const Text('Hủy'),
                                              ),
                                              ElevatedButton(
                                                onPressed: () => Navigator.pop(
                                                  context,
                                                  true,
                                                ),
                                                child: const Text('Xóa'),
                                              ),
                                            ],
                                          ),
                                        );

                                        if (confirm == true) {
                                          await _firebaseService
                                              .updateProductBatch(
                                                batch['id'],
                                                {},
                                                softDelete: true,
                                              );

                                          // reload batch
                                          await _loadBatches();

                                          // Cập nhật tổng số lượng product vào Firestore ngay
                                          int totalQty = _batches.fold(0, (
                                            sum,
                                            b,
                                          ) {
                                            final qty = b['quantity'] ?? 0;
                                            return sum +
                                                (qty is int
                                                    ? qty
                                                    : (qty as num).toInt());
                                          });

                                          await _firebaseService.updateProduct(
                                            _product['id'].toString(),
                                            {'quantity': totalQty},
                                          );

                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text("Đã xóa lô hàng"),
                                            ),
                                          );

                                          if (widget.onUpdate != null)
                                            widget
                                                .onUpdate!(); // reload kho hàng
                                        }
                                      }
                                    },

                                    itemBuilder: (_) => const [
                                      PopupMenuItem(
                                        value: 'edit',
                                        child: Text('Chỉnh sửa'),
                                      ),
                                      PopupMenuItem(
                                        value: 'delete',
                                        child: Text('Xóa'),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                            const Divider(color: Colors.grey),
                          ],
                        );
                      }).toList(),
                    ),
              const SizedBox(height: 20),

              if (isAdmin)
                ElevatedButton(
                  onPressed: _isSaving
                      ? null
                      : _saveChanges, // chặn nhấn khi đang lưu
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    minimumSize: const Size(double.infinity, 48),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.save),
                            SizedBox(width: 8),
                            Text("Lưu thay đổi"),
                          ],
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class BatchEditScreen extends StatefulWidget {
  final Map<String, dynamic> batch;

  final String productId;

  const BatchEditScreen({
    super.key,
    required this.batch,
    required this.productId,
  });

  @override
  State<BatchEditScreen> createState() => _BatchEditScreenState();
}

class _BatchEditScreenState extends State<BatchEditScreen> {
  final _firebaseService = ProductService();

  late TextEditingController _batchNoController;
  late TextEditingController _quantityController;
  late TextEditingController _mfgController;
  late TextEditingController _expController;

  String formatBatchDate(dynamic date) {
    if (date == null) return '';
    if (date is Timestamp) {
      return DateFormat('yyyy-MM-dd').format(date.toDate());
    } else if (date is DateTime) {
      return DateFormat('yyyy-MM-dd').format(date);
    } else if (date is String) {
      return date; // đã là string, không cần format
    } else {
      return date.toString();
    }
  }

  @override
  void initState() {
    super.initState();
    _batchNoController = TextEditingController(
      text: widget.batch['batch_number'] ?? '',
    );
    _quantityController = TextEditingController(
      text: widget.batch['quantity']?.toString() ?? '',
    );
    _mfgController = TextEditingController(
      text: formatBatchDate(widget.batch['mfg_date']),
    );
    _expController = TextEditingController(
      text: formatBatchDate(widget.batch['exp_date']),
    );
  }

  bool _isSavingBatch = false;

  Future<void> _saveBatch() async {
    if (_isSavingBatch) return; // chặn nhấn liên tục

    setState(() => _isSavingBatch = true); // bật loading

    try {
      // --- GIÁ TRỊ LÔ SAU KHI NHẬP ---
      final updatedBatch = {
        'batch_number': _batchNoController.text,
        'quantity': int.tryParse(_quantityController.text) ?? 0,
        'mfg_date': _mfgController.text.isNotEmpty
            ? DateTime.parse(_mfgController.text)
            : null,
        'expiry_date': _expController.text.isNotEmpty
            ? DateTime.parse(_expController.text)
            : null,
      };

      // --- Lấy số lượng cũ, tổng số lượng, cập nhật batch, cập nhật tổng product
      final oldBatchQty = widget.batch['quantity'] is int
          ? widget.batch['quantity'] as int
          : (widget.batch['quantity'] as num?)?.toInt() ?? 0;

      final newBatchQtyObj = updatedBatch['quantity'];
      final newBatchQty = newBatchQtyObj is int
          ? newBatchQtyObj
          : (newBatchQtyObj as num?)?.toInt() ?? 0;

      final batchesBefore = await _firebaseService.getProductBatches(
        widget.productId,
      );
      int oldTotalQty = batchesBefore.fold(0, (sum, b) {
        final qty = b['quantity'];
        return sum + (qty is int ? qty : (qty as num?)?.toInt() ?? 0);
      });

      await _firebaseService.updateProductBatch(
        widget.batch['id'].toString(),
        updatedBatch,
      );
      await _firebaseService.updateProductTotalQuantity(widget.productId);

      final batchesAfter = await _firebaseService.getProductBatches(
        widget.productId,
      );
      int newTotalQty = batchesAfter.fold(0, (sum, b) {
        final qty = b['quantity'];
        return sum + (qty is int ? qty : (qty as num?)?.toInt() ?? 0);
      });

      final productData = await _firebaseService.getProductById(
        widget.productId,
      );
      final productName = productData?['name'] ?? "Không rõ";
      final price = (productData?['price'] is num)
          ? (productData?['price'] as num).toDouble()
          : 0.0;

      String categoryName = "";
      final categoryId = productData?['category_id'];
      if (categoryId != null && categoryId.toString().isNotEmpty) {
        final catDoc = await _firebaseService.getCategoryById(
          categoryId.toString(),
        );
        if (catDoc != null) categoryName = catDoc['name'] ?? "";
      }

      await _firebaseService.logAdminUpdateHistory(
        productId: widget.productId,
        productName: productName,
        oldQuantity: oldTotalQty,
        newQuantity: newTotalQty,
        price: price,
        adminName: CurrentUser.fullname ?? CurrentUser.username ?? "Admin",
        adminEmail: CurrentUser.email ?? "",
        categoryName: categoryName,
        batchNumber: _batchNoController.text,
        oldBatchQuantity: oldBatchQty,
        newBatchQuantity: newBatchQty,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Cập nhật lô hàng thành công")),
      );

      Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _isSavingBatch = false); // tắt loading
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Chỉnh sửa lô hàng")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            TextField(
              controller: _batchNoController,
              decoration: const InputDecoration(labelText: "Số lô"),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _quantityController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Số lượng"),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _mfgController,
              decoration: const InputDecoration(
                labelText: "Ngày SX (yyyy-MM-dd)",
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _expController,
              decoration: const InputDecoration(labelText: "HSD (yyyy-MM-dd)"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isSavingBatch ? null : () async => await _saveBatch(),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
              child: _isSavingBatch
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text("Lưu"),
            ),
          ],
        ),
      ),
    );
  }
}
