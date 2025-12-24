// lib/features/common/thongke_staff/components/daily_exports_card.dart
import 'package:flutter/material.dart';
import '../utils/thongke_staff_utils.dart';

class DailyExportsCard extends StatelessWidget {
  final Map<String, int> exportsByDay;

  const DailyExportsCard({super.key, required this.exportsByDay});

  @override
  Widget build(BuildContext context) {
    if (exportsByDay.isEmpty) {
      return const SizedBox.shrink(); // Không hiển thị gì nếu chưa có dữ liệu
      // Hoặc có thể để lại thông báo nhẹ:
      // return const Padding(
      //   padding: EdgeInsets.symmetric(vertical: 20),
      //   child: Center(
      //     child: Text(
      //       'Chưa có dữ liệu xuất kho',
      //       style: TextStyle(color: Colors.grey, fontSize: 14),
      //     ),
      //   ),
      // );
    }

    // Lấy tối đa 10 ngày gần nhất, sắp xếp từ mới → cũ
    final sortedKeys = exportsByDay.keys.toList()
      ..sort((a, b) => b.compareTo(a)); // Đảo ngược để ngày mới nhất lên trên

    final recentDays = sortedKeys.take(10).toList();

    // Tính tổng trong khoảng hiển thị
    final totalInPeriod = recentDays.fold<int>(
      0,
      (sum, key) => sum + (exportsByDay[key] ?? 0),
    );

    return Card(
      elevation: 2,
      color: Colors.grey.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tiêu đề + tổng
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Xuất kho theo ngày",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  "Tổng: $totalInPeriod sp",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1, thickness: 0.5),

            // Danh sách ngày
            ...recentDays.map((key) {
              final date = DateTime.parse(key);
              final qty = exportsByDay[key] ?? 0;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      labelFmt.format(date),
                      style: const TextStyle(fontSize: 14),
                    ),
                    Text(
                      "$qty sp",
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.orangeAccent,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),

            // Nếu có nhiều hơn 10 ngày → thông báo nhẹ
            if (sortedKeys.length > 10)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Center(
                  child: Text(
                    "... và ${sortedKeys.length - 10} ngày khác",
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
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
