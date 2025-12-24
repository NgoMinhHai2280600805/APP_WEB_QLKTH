// lib/features/common/thongke_admin/components/import_history_card.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../admin/chi_tiet_nhap_hang.dart';
import '../utils/thongke_utils.dart';

class ImportHistoryCard extends StatelessWidget {
  final List<Map<String, dynamic>> importLogs;
  final bool Function(DateTime) isInRange;

  const ImportHistoryCard({
    super.key,
    required this.importLogs,
    required this.isInRange,
  });

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'Không rõ';
    final date = timestamp.toDate();
    return DateFormat('dd/MM/yyyy HH:mm').format(date);
  }

  int _calculateTotalQuantity(Map<String, dynamic> log) {
    int total = 0;
    final batches = log['batches'] as List<dynamic>? ?? [];
    for (var batch in batches) {
      final products = (batch['products'] as List<dynamic>? ?? []);
      for (var p in products) {
        total += (p['quantity'] as num?)?.toInt() ?? 0;
      }
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    // Lọc theo khoảng thời gian đã chọn
    final filteredLogs = importLogs.where((log) {
      final date = ThongkeUtils.convertTimestamp(log['created_at']);
      return date != null && isInRange(date);
    }).toList();

    // Sắp xếp mới nhất lên trên
    filteredLogs.sort((a, b) {
      final timeA = (a['created_at'] as Timestamp?)?.toDate() ?? DateTime(1970);
      final timeB = (b['created_at'] as Timestamp?)?.toDate() ?? DateTime(1970);
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
                const Text(
                  "Lịch sử nhập hàng gần đây",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                    color: Colors.black87,
                  ),
                ),
                Icon(Icons.import_export, color: Colors.green.shade600),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(thickness: 1, color: Colors.grey),
            const SizedBox(height: 8),

            ...displayLogs.map((log) {
              final totalQty = _calculateTotalQuantity(log);
              final adminName = log['admin_name'] ?? 'Không rõ';
              final createdAt = log['created_at'] as Timestamp?;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    "Nhập lúc: ${_formatDate(createdAt)}",
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    "Người nhập: $adminName\nTổng số lượng: $totalQty sản phẩm",
                    style: const TextStyle(fontSize: 13),
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey,
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChiTietNhapHang(data: log),
                      ),
                    );
                  },
                ),
              );
            }).toList(),

            if (filteredLogs.length > 5)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Center(
                  child: Text(
                    "Và ${filteredLogs.length - 5} phiếu nhập khác...",
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
