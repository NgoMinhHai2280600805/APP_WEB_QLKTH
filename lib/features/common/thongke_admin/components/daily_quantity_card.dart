// lib/features/common/thongke_admin/components/daily_quantity_card.dart

import 'package:flutter/material.dart';
import '../utils/thongke_utils.dart';

class DailyQuantityCard extends StatelessWidget {
  final List<String> allKeys;
  final Map<String, int> exportsByDay;
  final Map<String, int> importsByDay;

  const DailyQuantityCard({
    super.key,
    required this.allKeys,
    required this.exportsByDay,
    required this.importsByDay,
  });

  @override
  Widget build(BuildContext context) {
    if (allKeys.isEmpty) {
      return const SizedBox.shrink();
    }

    // Sắp xếp ngày từ mới nhất đến cũ nhất
    final sortedKeys = allKeys..sort((a, b) => b.compareTo(a));

    // Tính tổng nhập và xuất
    final totalImport = importsByDay.values.fold(
      0,
      (sum, value) => sum + value,
    );
    final totalExport = exportsByDay.values.fold(
      0,
      (sum, value) => sum + value,
    );

    return Card(
      color: Colors.grey.shade50,
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Số lượng nhập / xuất theo ngày",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 17,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            const Divider(thickness: 1, height: 1, color: Colors.grey),

            const SizedBox(height: 12),

            // Header bảng
            Row(
              children: const [
                Expanded(
                  flex: 3,
                  child: Text(
                    "Ngày",
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    "Nhập",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Colors.green,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    "Xuất",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Colors.red,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(thickness: 0.5),

            // Danh sách các ngày (mới nhất lên trên)
            ...sortedKeys.map((key) {
              final imp = importsByDay[key] ?? 0;
              final exp = exportsByDay[key] ?? 0;
              final date = DateTime.parse(key);

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 10.0),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        ThongkeUtils.labelFormat.format(date),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        imp > 0 ? '$imp' : '-',
                        style: TextStyle(
                          color: imp > 0 ? Colors.green[700] : Colors.grey[600],
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        exp > 0 ? '$exp' : '-',
                        style: TextStyle(
                          color: exp > 0 ? Colors.red[700] : Colors.grey[600],
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),

            const Divider(thickness: 1),

            // Tổng cộng
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  const Expanded(
                    flex: 3,
                    child: Text(
                      "TỔNG CỘNG",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      '$totalImport',
                      style: TextStyle(
                        color: Colors.green[800],
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      '$totalExport',
                      style: TextStyle(
                        color: Colors.red[800],
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
