// common/product_xuat_kho.dart
import 'package:flutter/material.dart';
import '../../../core/current_user.dart';
import '../../core/services/product_service.dart';
import 'package:intl/intl.dart';

class ProductXuatKhoScreen extends StatefulWidget {
  final Map<String, dynamic> product;
  final VoidCallback? onUpdate;
  const ProductXuatKhoScreen({super.key, required this.product, this.onUpdate});

  @override
  State<ProductXuatKhoScreen> createState() => _ProductXuatKhoScreenState();
}

class _ProductXuatKhoScreenState extends State<ProductXuatKhoScreen> {
  final _firebaseService = ProductService();

  late Map<String, dynamic> _product;
  List<Map<String, dynamic>> _batches = [];
  bool _loadingBatches = true;

  // popup xuất kho
  final Map<String, TextEditingController> _exportQtyControllers = {};
  final Map<String, bool> _selectedForExport = {};
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _product = Map<String, dynamic>.from(widget.product);
    _loadBatches();
  }

  @override
  void dispose() {
    for (var c in _exportQtyControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadBatches() async {
    setState(() => _loadingBatches = true);

    final list = await _firebaseService.getProductBatches(
      _product['id'].toString(),
    );

    // tạo controller & checkbox state cho mỗi batch
    for (var b in list) {
      final id = b['id'].toString();
      if (!_exportQtyControllers.containsKey(id)) {
        _exportQtyControllers[id] = TextEditingController();
      }
      _selectedForExport[id] = false;
    }

    setState(() {
      _batches = list;
      _loadingBatches = false;
    });

    // reload thông tin product
    final prod = await _firebaseService.getProductById(
      _product['id'].toString(),
    );
    if (prod != null) setState(() => _product = prod);
  }

  String _formatDate(dynamic ts) {
    if (ts == null) return '-';
    try {
      if (ts is DateTime) return DateFormat("dd/MM/yyyy").format(ts);
      if (ts.toDate != null)
        return DateFormat("dd/MM/yyyy").format(ts.toDate());
      return ts.toString();
    } catch (e) {
      return ts.toString();
    }
  }

  Future<void> _openExportPopup() async {
    // reset lựa chọn
    for (var b in _batches) {
      final id = b['id'].toString();
      _selectedForExport[id] = false;
      _exportQtyControllers[id]?.text = '';
    }

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx2, setPop) {
            Widget row(Map<String, dynamic> b) {
              final id = b['id'].toString();
              final selected = _selectedForExport[id] ?? false;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: selected,
                      onChanged: (v) {
                        setPop(() => _selectedForExport[id] = v ?? false);
                      },
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Lô: ${b['batch_number']}"),
                          Text("Tồn: ${b['quantity']}"),
                          Text(
                            "SX: ${_formatDate(b['mfg_date'])} | HSD: ${_formatDate(b['exp_date'])}",
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 120,
                      child: TextField(
                        controller: _exportQtyControllers[id],
                        enabled: selected,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: "SL xuất",
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            return AlertDialog(
              title: const Text("Xuất kho"),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.85,
                height: 380,
                child: _loadingBatches
                    ? const Center(child: CircularProgressIndicator())
                    : _batches.isEmpty
                    ? const Center(child: Text("Không có lô hàng"))
                    : SingleChildScrollView(
                        child: Column(children: _batches.map(row).toList()),
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx2),
                  child: const Text("Hủy"),
                ),
                ElevatedButton(
                  onPressed: _isExporting
                      ? null
                      : () async {
                          final selected = <Map<String, dynamic>>[];

                          for (var b in _batches) {
                            final id = b['id'].toString();
                            if (_selectedForExport[id] == true) {
                              final qty =
                                  int.tryParse(
                                    _exportQtyControllers[id]?.text ?? "",
                                  ) ??
                                  0;

                              selected.add({
                                'id': id,
                                'batch_number': b['batch_number'],
                                'available': b['quantity'],
                                'export_qty': qty,
                              });
                            }
                          }

                          if (selected.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Chọn ít nhất 1 lô để xuất"),
                              ),
                            );
                            return;
                          }

                          for (var s in selected) {
                            if (s['export_qty'] <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    "Số lượng lô ${s['batch_number']} không hợp lệ",
                                  ),
                                ),
                              );
                              return;
                            }
                            if (s['export_qty'] > s['available']) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    "Không thể xuất ${s['export_qty']} / tồn ${s['available']} (lô ${s['batch_number']})",
                                  ),
                                ),
                              );
                              return;
                            }
                          }

                          Navigator.pop(ctx2);
                          await _processExport(selected);
                        },
                  child: _isExporting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text("Xác nhận"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Trong _processExport của ProductXuatKhoScreen

  Future<void> _processExport(List<Map<String, dynamic>> selected) async {
    if (_isExporting) return;
    setState(() => _isExporting = true);

    try {
      final productId = _product['id'].toString();

      // Lấy category name (giống web)
      String categoryName = "";
      final catId = _product['category_id'];
      if (catId != null && catId.toString().isNotEmpty) {
        final cat = await _firebaseService.getCategoryById(catId.toString());
        categoryName = cat?['name'] ?? "";
      }

      // Chuẩn bị cartItems giống hệt web
      final cartItems = <Map<String, dynamic>>[];
      int totalExported = 0;

      for (var s in selected) {
        final batchId = s['id'];
        final exportQty = s['export_qty'] as int;
        final oldQty = s['available'] as int;
        final newQty = oldQty - exportQty;

        // Cập nhật tồn kho lô
        await _firebaseService.updateProductBatch(batchId, {
          'quantity': newQty,
        });

        // Thêm vào cartItems để ghi log
        cartItems.add({
          'productId': productId,
          'productName': _product['name'] ?? '',
          'productPrice': (_product['price'] as num?)?.toInt() ?? 0,
          'batchId': batchId,
          'batchNumber': s['batch_number'],
          'exportQty': exportQty,
          'oldQty': oldQty,
          'newQty': newQty,
          'mfgDate': s['mfg_date'],
          'expDate': s['exp_date'],
          'categoryId': _product['category_id'] ?? '',
          'categoryName': categoryName,
        });

        totalExported += exportQty;
      }

      // Cập nhật tổng tồn sản phẩm
      await _firebaseService.updateProductTotalQuantity(productId);

      // Chuẩn bị thông tin nhân viên (giống web)
      final staffInfo = {
        'id': CurrentUser.id, // nếu bạn có lưu user ID
        'name': CurrentUser.fullname ?? CurrentUser.username ?? 'Nhân viên',
        'email': CurrentUser.email ?? '',
        'phone': CurrentUser.phone ?? '', // nếu có lưu
        'role': CurrentUser.role,
      };

      // GHI LOG ĐÚNG CHUẨN WEB
      await _firebaseService.logStaffExportHistory(
        cartItems: cartItems,
        staffInfo: staffInfo,
      );

      // Thành công
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green,
          content: Text(
            "Xuất kho thành công!\nTổng: $totalExported sản phẩm",
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );

      // Reload dữ liệu
      await _loadBatches();
      if (widget.onUpdate != null) widget.onUpdate!();
    } catch (e) {
      print("Lỗi xuất kho: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.red, content: Text("Lỗi: $e")),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_product['name'] ?? "Chi tiết sản phẩm"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (widget.onUpdate != null) widget.onUpdate!();
            Navigator.pop(context);
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        //hàm chặn co giãn nd
        child: ScrollConfiguration(
          behavior: const ScrollBehavior().copyWith(
            overscroll: false, // tắt hiệu ứng co giãn
            physics: const ClampingScrollPhysics(), // khóa cứng scroll
          ),
          child: ListView(
            children: [
              // Ảnh SP
              Container(
                height: 180,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.grey.shade200,
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
                    ? const Center(child: Text("Không có ảnh"))
                    : null,
              ),

              const SizedBox(height: 20),

              // Tên SP
              TextField(
                readOnly: true,
                controller: TextEditingController(text: _product['name'] ?? ''),
                decoration: const InputDecoration(labelText: "Tên sản phẩm"),
              ),
              const SizedBox(height: 12),

              // Giá
              TextField(
                readOnly: true,
                controller: TextEditingController(
                  text: (_product['price'] ?? 0).toString(),
                ),
                decoration: const InputDecoration(labelText: "Giá"),
              ),
              const SizedBox(height: 12),

              // Số lượng tồn
              TextField(
                readOnly: true,
                controller: TextEditingController(
                  text: (_product['quantity'] ?? 0).toString(),
                ),
                decoration: const InputDecoration(
                  labelText: "Số lượng hiện có",
                ),
              ),

              const SizedBox(height: 20),

              // NÚt xuất kho đặt ở đây (nút DUY NHẤT)
              Center(
                child: ElevatedButton.icon(
                  onPressed: _batches.isEmpty ? null : () => _openExportPopup(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    minimumSize: const Size(200, 48),
                  ),
                  icon: const Icon(Icons.local_shipping_outlined),
                  label: const Text("Xuất kho"),
                ),
              ),

              const SizedBox(height: 30),

              // Danh sách lô
              const Text(
                "Danh sách lô hàng",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),

              _loadingBatches
                  ? const Center(child: CircularProgressIndicator())
                  : _batches.isEmpty
                  ? const Text("Không có lô hàng")
                  : Column(
                      children: _batches.map((b) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Lô: ${b['batch_number']}"),
                            Text("Số lượng: ${b['quantity']}"),
                            Text(
                              "SX: ${_formatDate(b['mfg_date'])} | HSD: ${_formatDate(b['exp_date'])}",
                            ),
                            const Divider(),
                          ],
                        );
                      }).toList(),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
