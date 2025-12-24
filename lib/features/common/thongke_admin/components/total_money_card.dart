import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/thongke_utils.dart';

class TotalMoneyCard extends StatelessWidget {
  final List<Map<String, dynamic>> importLogs;
  final List<Map<String, dynamic>> exportLogs;
  final bool Function(DateTime date) isInRange;

  const TotalMoneyCard({
    super.key,
    required this.importLogs,
    required this.exportLogs,
    required this.isInRange,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFmt = NumberFormat('#,###', 'vi_VN');
    double totalImport = 0;
    double totalExport = 0;

    for (var e in importLogs) {
      final date = ThongkeUtils.convertTimestamp(e['updated_at']);
      if (date == null || !isInRange(date)) continue;
      final qty = ThongkeUtils.getQtyFromLog(e);
      final price = double.tryParse(e['price']?.toString() ?? '0') ?? 0.0;
      totalImport += qty * price;
    }

    for (var e in exportLogs) {
      final date = ThongkeUtils.convertTimestamp(e['exported_at']);
      if (date == null || !isInRange(date)) continue;
      final qty = ThongkeUtils.getQtyFromLog(e);
      final price = double.tryParse(e['price']?.toString() ?? '0') ?? 0.0;
      totalExport += qty * price;
    }

    return Card(
      color: Colors.white,
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tổng giá trị giao dịch',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tổng tiền nhập',
                      style: TextStyle(
                        color: Colors.blueAccent,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${currencyFmt.format(totalImport)} đ',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tổng tiền xuất',
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${currencyFmt.format(totalExport)} đ',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepOrange,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
