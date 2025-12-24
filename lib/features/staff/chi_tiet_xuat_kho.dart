import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ChiTietXuatKhoScreen extends StatelessWidget {
  final Map<String, dynamic> data;

  const ChiTietXuatKhoScreen({super.key, required this.data});

  String _fmt(dynamic d) {
    if (d == null) return "Không có";
    if (d is Timestamp) {
      return DateFormat('dd/MM/yyyy').format(d.toDate());
    }
    return d.toString();
  }

  @override
  Widget build(BuildContext context) {
    // Thời gian xuất
    final Timestamp? timestamp = data['exported_at'] ?? data['created_at'];
    final DateTime? exportedAt = timestamp?.toDate();

    // Thu thập tất cả sản phẩm từ các lô
    final List<Map<String, dynamic>> allProducts = [];
    for (final batch in (data['batches'] as List<dynamic>?) ?? []) {
      final batchMap = batch as Map<String, dynamic>;
      final batchNumber = batchMap['batch_number'] ?? 'Không rõ';
      for (final p in (batchMap['products'] as List<dynamic>?) ?? []) {
        final prod = Map<String, dynamic>.from(p as Map);
        prod['batch_number'] =
            batchNumber; // thêm thông tin lô vào từng sản phẩm
        allProducts.add(prod);
      }
    }

    // Gom nhóm theo danh mục trước
    final Map<String, List<Map<String, dynamic>>> categoryGroups = {};
    for (final p in allProducts) {
      final catName = p['category_name']?.toString().trim().isNotEmpty == true
          ? p['category_name']
          : 'Không rõ';
      categoryGroups.putIfAbsent(catName, () => []);
      categoryGroups[catName]!.add(p);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Chi tiết xuất kho"),
        backgroundColor: Colors.blue,
      ),
      body: ScrollConfiguration(
        // <-- Thêm ScrollConfiguration ở đây (bao toàn bộ body)
        behavior: const ScrollBehavior().copyWith(
          overscroll:
              false, // Tắt hiệu ứng co giãn (bouncy) khi kéo quá đầu/cuối
          physics:
              const ClampingScrollPhysics(), // Khóa cứng scroll (không cho kéo quá giới hạn)
        ),
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            // Thông tin chung
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                title: const Text(
                  "Thông tin chung",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  "Mã phiếu: ${data['receipt_number'] ?? 'Không rõ'}\n"
                  "Ngày xuất: ${exportedAt != null ? DateFormat('dd/MM/yyyy HH:mm').format(exportedAt) : 'Không rõ'}\n"
                  "Nhân viên: ${data['staff_name'] ?? 'Không rõ'}\n"
                  "Email: ${data['staff_email'] ?? 'Không rõ'}\n"
                  "SĐT: ${data['staff_phone'] ?? 'Không rõ'}",
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Tổng số lượng xuất
            Card(
              color: Colors.orange.shade50,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Tổng số lượng xuất",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      "${data['total_export'] ?? 0}",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Nhóm theo danh mục
            ...categoryGroups.entries.map((catEntry) {
              final catName = catEntry.key;
              final catProducts = catEntry.value;

              // Gom nhóm tiếp theo sản phẩm (cùng product_name)
              final Map<String, List<Map<String, dynamic>>> productGroups = {};
              for (final p in catProducts) {
                final prodName = p['product_name'] ?? 'Không rõ';
                productGroups.putIfAbsent(prodName, () => []);
                productGroups[prodName]!.add(p);
              }

              // Tổng SL của danh mục
              final totalCatQty = catProducts.fold<int>(
                0,
                (sum, p) => sum + ((p['quantity'] ?? 0) as num).toInt(),
              );

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tiêu đề danh mục
                      Text(
                        "Loại hàng: $catName",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Các sản phẩm trong danh mục
                      ...productGroups.entries.map((prodEntry) {
                        final prodName = prodEntry.key;
                        final prodItems = prodEntry.value;

                        final totalProdQty = prodItems.fold<int>(
                          0,
                          (sum, p) =>
                              sum + ((p['quantity'] ?? 0) as num).toInt(),
                        );

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Tên sản phẩm
                              Text(
                                "Sản phẩm: $prodName",
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 6),

                              // Danh sách các lô của sản phẩm này
                              ...prodItems.map(
                                (p) => Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                    horizontal: 12,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text("• Lô: ${p['batch_number']}"),
                                      Text(
                                        "   SL xuất: ${p['quantity']} (Trước: ${p['old_quantity']} → Sau: ${p['new_quantity']})",
                                      ),
                                      Text(
                                        "   NSX: ${_fmt(p['mfg_date'])} - HSD: ${_fmt(p['exp_date'])}",
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              const SizedBox(height: 6),
                              // Tổng SL sản phẩm
                              Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  "Tổng $prodName: $totalProdQty",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Đường kẻ đứt phân cách sản phẩm
                              CustomPaint(
                                size: const Size(double.infinity, 1),
                                painter: DashedLinePainter(),
                              ),
                            ],
                          ),
                        );
                      }),

                      const SizedBox(height: 8),
                      // Tổng của toàn danh mục
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          "Tổng loại hàng $catName: $totalCatQty",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),

            // Không có dữ liệu
            if (categoryGroups.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text("Không có chi tiết lô hàng"),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// Đường kẻ đứt
class DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const dashWidth = 5.0;
    const dashSpace = 3.0;
    final paint = Paint()
      ..color = Colors.grey
      ..strokeWidth = 1;

    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + dashWidth, 0), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
