import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ChiTietNhapHang extends StatelessWidget {
  final Map<String, dynamic> data;

  const ChiTietNhapHang({super.key, required this.data});

  String _fmt(dynamic d) {
    if (d == null) return "Không có";
    if (d is Timestamp) {
      return DateFormat('dd/MM/yyyy').format(d.toDate());
    }
    return d.toString();
  }

  String _formatMoney(double amount) {
    return NumberFormat.currency(
          locale: 'vi_VN',
          symbol: '',
        ).format(amount).trim() +
        ' đ';
  }

  @override
  Widget build(BuildContext context) {
    final createdAt = (data['created_at'] as Timestamp?)?.toDate();
    final batches = List<Map<String, dynamic>>.from(data['batches']);

    // Tổng tiền toàn bộ lần nhập
    double totalImportValue = 0.0;
    for (var batch in batches) {
      final products = List<Map<String, dynamic>>.from(batch['products'] ?? []);
      for (var p in products) {
        final qty = (p['quantity'] as num?)?.toDouble() ?? 0.0;
        final price = (p['price'] as num?)?.toDouble() ?? 0.0;
        totalImportValue += qty * price;
      }
    }

    // Gom theo danh mục → 1 card cho mỗi danh mục
    final Map<String, List<Map<String, dynamic>>> categoryGroups = {};
    for (var batch in batches) {
      final products = List<Map<String, dynamic>>.from(batch['products'] ?? []);
      for (var p in products) {
        final catName = p['category_name'] ?? 'Không rõ';
        if (!categoryGroups.containsKey(catName)) {
          categoryGroups[catName] = [];
        }
        categoryGroups[catName]!.add({
          ...p,
          'batch_number': batch['batch_number'] ?? '',
        });
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Chi tiết nhập hàng")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ============ THÔNG TIN CHUNG ============
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              title: const Text(
                "Thông tin chung",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Text(
                    "Ngày nhập: ${createdAt != null ? DateFormat('dd/MM/yyyy HH:mm').format(createdAt) : 'Không rõ'}",
                    style: const TextStyle(fontSize: 15),
                  ),
                  Text(
                    "Người nhập: ${data['admin_name'] ?? 'Không rõ'}",
                    style: const TextStyle(fontSize: 15),
                  ),
                  Text(
                    "Email: ${data['admin_email'] ?? 'Không rõ'}",
                    style: const TextStyle(fontSize: 15),
                  ),
                  if (data['admin_phone']?.toString().isNotEmpty == true)
                    Text(
                      "SĐT: ${data['admin_phone']}",
                      style: const TextStyle(fontSize: 15),
                    ),
                  if (data['admin_username']?.toString().isNotEmpty == true)
                    Text(
                      "Username: ${data['admin_username']}",
                      style: const TextStyle(fontSize: 15),
                    ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      "Tổng tiền nhập: ${_formatMoney(totalImportValue)}",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ============ DANH SÁCH THEO DANH MỤC ============
          ...categoryGroups.entries.map((catEntry) {
            final catName = catEntry.key.toUpperCase(); // ← IN HOA TOÀN BỘ
            final catItems = catEntry.value;

            // Gom theo tên sản phẩm trong danh mục
            final Map<String, List<Map<String, dynamic>>> productInCatGroups =
                {};
            for (var item in catItems) {
              final productName = item['product_name'] ?? 'Không rõ';
              productInCatGroups.putIfAbsent(productName, () => []).add(item);
            }

            return Card(
              margin: const EdgeInsets.only(
                bottom: 20,
              ), // Khoảng cách lớn giữa các danh mục
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 6,
              shadowColor: Colors.grey.withOpacity(0.2),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // === TIÊU ĐỀ DANH MỤC: TO HƠN, IN HOA, IN ĐẬM, CĂN TRÁI ===
                    Text(
                      catName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 21, // ← To hơn (từ 19 → 21)
                        color: Colors.black87,
                        letterSpacing:
                            0.5, // Thêm chút khoảng cách chữ cho dễ đọc khi in hoa
                      ),
                    ),
                    const SizedBox(height: 16),

                    // === NỘI DUNG CHI TIẾT ===
                    ...productInCatGroups.entries.map((prodEntry) {
                      final productName = prodEntry.key;
                      final prodItems = prodEntry.value;

                      int totalQtyProd = 0;
                      double totalValueProd = 0.0;
                      for (var item in prodItems) {
                        final qty = (item['quantity'] as num?)?.toInt() ?? 0;
                        final price =
                            (item['price'] as num?)?.toDouble() ?? 0.0;
                        totalQtyProd += qty;
                        totalValueProd += qty * price;
                      }

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              productName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 6),

                            // Các lô hàng
                            ...prodItems.map((item) {
                              final qty =
                                  (item['quantity'] as num?)?.toInt() ?? 0;
                              final price =
                                  (item['price'] as num?)?.toDouble() ?? 0.0;
                              final batchNo =
                                  item['batch_number'] ?? 'Không rõ';

                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                  horizontal: 8,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Lô: $batchNo",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      "Số lượng: $qty",
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                    Text(
                                      "Đơn giá: ${_formatMoney(price)}",
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                    Text(
                                      "Thành tiền: ${_formatMoney(qty * price)}",
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                    Text(
                                      "NSX: ${_fmt(item['mfg_date'])}  -  HSD: ${_fmt(item['exp_date'])}",
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),

                            if (prodItems.length > 1)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Divider(
                                  height: 1,
                                  thickness: 0.5,
                                  color: Colors.grey,
                                ),
                              ),

                            const SizedBox(height: 4),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    "Tổng sản phẩm: $totalQtyProd",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    "Tổng tiền: ${_formatMoney(totalValueProd)}",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Colors.deepPurple,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Phân cách sản phẩm bằng gạch nét đứt
                            if (prodEntry.key !=
                                productInCatGroups.keys.last) ...[
                              const SizedBox(height: 16),
                              CustomPaint(
                                size: const Size(double.infinity, 1),
                                painter: DashedLinePainter(),
                              ),
                              const SizedBox(height: 16),
                            ],
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}

class DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const dashWidth = 6.0;
    const dashSpace = 4.0;
    final paint = Paint()
      ..color = Colors.grey
      ..strokeWidth = 1.5;

    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + dashWidth, 0), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
