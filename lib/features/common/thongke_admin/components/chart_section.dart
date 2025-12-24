import 'package:app_qlkth_nhom8/features/common/thongke_admin/components/legend_dot.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../utils/thongke_utils.dart';

class ChartSection extends StatelessWidget {
  final List<String> allKeys;
  final Map<String, int> exportsByDay;
  final Map<String, int> importsByDay;
  final double maxY;

  const ChartSection({
    super.key,
    required this.allKeys,
    required this.exportsByDay,
    required this.importsByDay,
    required this.maxY,
  });

  List<BarChartGroupData> _buildBarGroups() {
    int i = 0;
    const double barWidth = 16;
    const double barsSpace = 10;

    return allKeys.map((key) {
      final exp = exportsByDay[key]?.toDouble() ?? 0;
      final imp = importsByDay[key]?.toDouble() ?? 0;

      return BarChartGroupData(
        x: i++,
        barsSpace: barsSpace,
        barRods: [
          BarChartRodData(
            toY: imp,
            width: barWidth,
            borderRadius: BorderRadius.circular(3),
            gradient: LinearGradient(
              colors: [Colors.lightBlue.shade200, Colors.blue.shade700],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            ),
          ),
          BarChartRodData(
            toY: exp,
            width: barWidth,
            borderRadius: BorderRadius.circular(3),
            gradient: LinearGradient(
              colors: [Colors.orange.shade300, Colors.orange.shade800],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            ),
          ),
        ],
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Biểu đồ nhập / xuất',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Row(
              children: [
                LegendDot(color: Colors.lightBlue, label: 'Nhập'),
                SizedBox(width: 8),
                LegendDot(color: Colors.orange, label: 'Xuất'),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              height: 300,
              child: BarChart(
                BarChartData(
                  maxY: maxY,
                  barGroups: _buildBarGroups(),
                  gridData: FlGridData(show: true),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                        interval: (maxY / 5).ceilToDouble(),
                        getTitlesWidget: (val, meta) => Text(
                          val.toInt().toString(),
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (val, meta) {
                          final index = val.toInt();
                          if (index < 0 || index >= allKeys.length) {
                            return const SizedBox.shrink();
                          }
                          final date = DateTime.parse(allKeys[index]);
                          return Padding(
                            padding: const EdgeInsets.only(top: 6.0),
                            child: Text(
                              ThongkeUtils.labelFormat.format(date),
                              style: const TextStyle(fontSize: 11),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
