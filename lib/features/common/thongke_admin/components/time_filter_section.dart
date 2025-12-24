import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TimeFilterSection extends StatelessWidget {
  final String selectedTime;
  final DateTimeRange? customRange;
  final VoidCallback onAll;
  final VoidCallback onToday;
  final VoidCallback on7Days;
  final VoidCallback on30Days;
  final VoidCallback onCustom;

  const TimeFilterSection({
    super.key,
    required this.selectedTime,
    required this.customRange,
    required this.onAll,
    required this.onToday,
    required this.on7Days,
    required this.on30Days,
    required this.onCustom,
  });

  Widget _timeButton(String label, VoidCallback onTap, bool isSelected) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? Colors.blue : Colors.grey.shade300,
        foregroundColor: isSelected ? Colors.white : Colors.black87,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: Text(label),
    );
  }

  @override
  Widget build(BuildContext context) {
    final timeLabel = selectedTime == 'Tùy chọn' && customRange != null
        ? '${DateFormat('dd/MM').format(customRange!.start)} - ${DateFormat('dd/MM').format(customRange!.end)}'
        : selectedTime;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _timeButton('Tất cả', onAll, selectedTime == 'Tất cả'),
            _timeButton('Hôm nay', onToday, selectedTime == 'Hôm nay'),
            _timeButton('7 ngày qua', on7Days, selectedTime == '7 ngày qua'),
            _timeButton('30 ngày qua', on30Days, selectedTime == '30 ngày qua'),
            _timeButton('Tùy chọn', onCustom, selectedTime == 'Tùy chọn'),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '($timeLabel)',
          style: const TextStyle(fontSize: 13, color: Colors.black54),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
