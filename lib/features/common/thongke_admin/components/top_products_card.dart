import 'package:flutter/material.dart';
import '../utils/thongke_utils.dart';

class TopProductsCard extends StatelessWidget {
  final List<Map<String, dynamic>> exportLogs;
  final bool Function(DateTime date) isInRange;

  const TopProductsCard({
    super.key,
    required this.exportLogs,
    required this.isInRange,
  });

  @override
  Widget build(BuildContext context) {
    final Map<String, int> totalByProduct = {};

    for (var e in exportLogs) {
      final date = ThongkeUtils.convertTimestamp(e['exported_at']);
      if (date == null || !isInRange(date)) continue;
      final name = e['product_name'] ?? '---';
      final qty = int.tryParse((e['quantity'] ?? '0').toString()) ?? 0;
      totalByProduct[name] = (totalByProduct[name] ?? 0) + qty;
    }

    final top5 = totalByProduct.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value))
      ..take(5);

    if (top5.isEmpty) {
      return const Text('Không có dữ liệu xuất hàng trong giai đoạn này.');
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sản phẩm xuất nhiều nhất',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const Divider(thickness: 0.5, color: Colors.black26),
            ...top5.map(
              (e) => Column(
                children: [
                  ListTile(
                    dense: true,
                    title: Text(e.key),
                    trailing: Text('${e.value} sp'),
                  ),
                  const Divider(thickness: 0.3, color: Colors.black12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
