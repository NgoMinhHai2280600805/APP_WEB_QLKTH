// lib/features/common/thongke_admin/components/transaction_list_card.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // ← THÊM DÒNG NÀY
import '../utils/thongke_utils.dart';
import '../../../staff/chi_tiet_xuat_kho.dart';

class TransactionListCard extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> data;
  final String timeField;
  final bool Function(DateTime) isInRange;

  const TransactionListCard({
    super.key,
    required this.title,
    required this.data,
    required this.timeField,
    required this.isInRange,
  });

  @override
  Widget build(BuildContext context) {
    // Lọc theo khoảng thời gian
    final filteredLogs = data.where((log) {
      final date = ThongkeUtils.convertTimestamp(log[timeField]);
      return date != null && isInRange(date);
    }).toList();

    // Sắp xếp mới nhất lên trên
    filteredLogs.sort((a, b) {
      final timeA = (a[timeField] as Timestamp?)?.toDate() ?? DateTime(1970);
      final timeB = (b[timeField] as Timestamp?)?.toDate() ?? DateTime(1970);
      return timeB.compareTo(timeA);
    });

    // Chỉ hiển thị tối đa 5 phiếu gần nhất
    final displayLogs = filteredLogs.take(5).toList();

    if (displayLogs.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      color: Colors.grey.shade50,
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                    color: Colors.black87,
                  ),
                ),
                Icon(Icons.output, color: Colors.orange.shade600),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(thickness: 1, color: Colors.grey),
            const SizedBox(height: 8),

            ...displayLogs.map((log) {
              final receiptNumber = log['receipt_number'] ?? 'N/A';
              final totalExport = log['total_export'] ?? 0;
              final staffName = log['staff_name'] ?? 'Không rõ';
              final staffEmail = log['staff_email'] ?? '';
              final timestamp = log[timeField] as Timestamp?;
              final timeStr = timestamp != null
                  ? DateFormat('dd/MM/yyyy HH:mm').format(timestamp.toDate())
                  : 'Không rõ';

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChiTietXuatKhoScreen(data: log),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Mã phiếu: $receiptNumber",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "Tổng xuất: $totalExport sản phẩm",
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: Colors.orange,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "Nhân viên: $staffName${staffEmail.isNotEmpty ? ' ($staffEmail)' : ''}",
                              style: const TextStyle(fontSize: 13.5),
                            ),
                            Text(
                              "Thời gian: $timeStr",
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),

            if (filteredLogs.length > 5)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Center(
                  child: Text(
                    "Và ${filteredLogs.length - 5} phiếu xuất khác...",
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
