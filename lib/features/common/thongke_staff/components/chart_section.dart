// lib/features/common/thongke_staff/components/chart_section.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../utils/thongke_staff_utils.dart'; // giữ nguyên import tương đối

class ChartSection extends StatelessWidget {
  final Map<String, int> exportsByDay;
  final int totalExports; // thêm để hiển thị lời động viên

  const ChartSection({
    super.key,
    required this.exportsByDay,
    required this.totalExports,
  });

  List<BarChartGroupData> _buildBarGroups(List<String> allKeys) {
    int i = 0;
    const double barWidth = 22; // tăng nhẹ cho dễ nhìn trên mobile
    return allKeys.map((key) {
      final qty = exportsByDay[key]?.toDouble() ?? 0;
      return BarChartGroupData(
        x: i++,
        barRods: [
          BarChartRodData(
            toY: qty,
            width: barWidth,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
            color: Colors.orangeAccent,
            // thêm gradient nhẹ cho đẹp
            gradient: const LinearGradient(
              colors: [Colors.orangeAccent, Colors.deepOrangeAccent],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            ),
          ),
        ],
      );
    }).toList();
  }

  double _determineYAxisMax(double maxValue) {
    if (maxValue == 0) return 10;
    if (maxValue <= 10) return 10;
    if (maxValue <= 50) return 50;
    if (maxValue <= 100) return 100;
    if (maxValue <= 500) return 500;
    return (maxValue / 500).ceil() * 500 +
        100; // dư một chút để không chạm đỉnh
  }

  @override
  Widget build(BuildContext context) {
    final allKeys = exportsByDay.keys.toList()..sort();
    if (allKeys.isEmpty) {
      return const SizedBox.shrink(); // không hiển thị gì nếu không có dữ liệu
    }

    final maxValue = exportsByDay.values.fold<double>(
      0,
      (p, c) => c > p ? c.toDouble() : p,
    );
    final maxY = _determineYAxisMax(maxValue);

    // Lời động viên dựa trên tổng xuất
    String motivationText() {
      if (totalExports == 0) return "Hôm nay chưa có đơn nào, cố lên nhé!";
      if (totalExports < 20) return "Cố gắng thêm chút nữa nào!";
      if (totalExports < 50) return "Làm tốt lắm! Tiếp tục phát huy nhé ";
      return "Tuyệt vời! Bạn đang xuất sắc đấy";
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tiêu đề + icon
        Row(
          children: const [
            SizedBox(width: 10),
            Text(
              'Lượng xuất hàng theo ngày',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Lời động viên
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            motivationText(),
            style: TextStyle(
              fontSize: 14,
              color: totalExports >= 50
                  ? Colors.green.shade700
                  : Colors.orange.shade700,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),

        // Card biểu đồ đẹp hơn
        Card(
          elevation: 4,
          color: Colors.orange.shade50.withOpacity(0.7),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            child: SizedBox(
              height: 260, // giảm nhẹ để gọn hơn trên màn hình staff
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxY,
                  barGroups: _buildBarGroups(allKeys),
                  gridData: const FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: null,
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        interval: maxY / 5,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= allKeys.length) {
                            return const SizedBox.shrink();
                          }
                          final date = DateTime.parse(allKeys[index]);
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              labelFmt.format(date),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black87,
                              ),
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
        const SizedBox(height: 16),
      ],
    );
  }
}
