// lib/features/common/thongke_staff/components/recent_exports_list.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/thongke_staff_utils.dart';
import '../../../staff/chi_tiet_xuat_kho.dart';

class RecentExportsList extends StatelessWidget {
  final List<Map<String, dynamic>> exportLogs;

  const RecentExportsList({super.key, required this.exportLogs});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    // Lọc chỉ các log trong ngày hôm nay
    final todayLogs = exportLogs.where((log) {
      final DateTime? date = convertTimestamp(
        log['exported_at'] ?? log['created_at'],
      );
      if (date == null) return false;
      return date.isAfter(todayStart.subtract(const Duration(seconds: 1))) &&
          date.isBefore(todayStart.add(const Duration(days: 1)));
    }).toList();

    // Sắp xếp mới nhất lên trên
    todayLogs.sort((a, b) {
      final DateTime? timeA = convertTimestamp(
        a['exported_at'] ?? a['created_at'],
      );
      final DateTime? timeB = convertTimestamp(
        b['exported_at'] ?? b['created_at'],
      );
      if (timeA == null || timeB == null) return 0;
      return timeB.compareTo(timeA);
    });

    if (todayLogs.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 30),
        child: Center(
          child: Text(
            'Hôm nay chưa có lượt xuất kho nào',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tiêu đề
        const Text(
          'Xuất kho hôm nay',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 17,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),

        // Danh sách tất cả các lần xuất hôm nay
        ...List.generate(todayLogs.length, (index) {
          final log = todayLogs[index];
          final DateTime date =
              convertTimestamp(log['exported_at'] ?? log['created_at']) ??
              DateTime.now();

          final String receiptNumber = log['receipt_number'] ?? 'Chưa có mã';
          final int totalExport = log['total_export'] ?? 0;

          return Column(
            children: [
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChiTietXuatKhoScreen(data: log),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              receiptNumber,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Xuất $totalExport sp',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.orange,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        DateFormat('HH:mm').format(date), // Chỉ hiển thị giờ
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Divider mờ giữa các item (trừ item cuối)
              if (index < todayLogs.length - 1)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Divider(height: 1, thickness: 0.5, color: Colors.grey),
                ),
            ],
          );
        }).toList(),

        const SizedBox(height: 10),
      ],
    );
  }
}
