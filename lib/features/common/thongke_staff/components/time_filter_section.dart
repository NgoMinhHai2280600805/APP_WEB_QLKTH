// lib/features/thongke_staff/components/time_filter_section.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TimeFilterSection extends StatelessWidget {
  final String selectedTime;
  final DateTimeRange? customRange;
  final Function(String, DateTimeRange?) onTimeChanged;

  const TimeFilterSection({
    super.key,
    required this.selectedTime,
    required this.customRange,
    required this.onTimeChanged,
  });

  Future<void> _selectCustomRange(BuildContext context) async {
    final start = await showDatePicker(
      context: context,
      initialDate: customRange?.start ?? DateTime.now(),
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      helpText: 'Chọn ngày bắt đầu',
    );

    if (start == null) return;

    final end = await showDatePicker(
      context: context,
      initialDate: customRange?.end ?? start,
      firstDate: start,
      lastDate: DateTime.now(),
      helpText: 'Chọn ngày kết thúc',
    );

    if (end != null) {
      onTimeChanged('Tùy chọn', DateTimeRange(start: start, end: end));
    }
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
            _timeButton('Hôm nay'),
            _timeButton('7 ngày qua'),
            _timeButton('30 ngày qua'),
            _timeButton('Tùy chọn', onTap: () => _selectCustomRange(context)),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '($timeLabel)',
          style: const TextStyle(fontSize: 13, color: Colors.black54),
        ),
      ],
    );
  }

  Widget _timeButton(String label, {VoidCallback? onTap}) {
    final selected = selectedTime == label;
    return ElevatedButton(
      onPressed:
          onTap ??
          () {
            onTimeChanged(label, null);
          },
      style: ElevatedButton.styleFrom(
        backgroundColor: selected ? Colors.blue : Colors.grey.shade300,
        foregroundColor: selected ? Colors.white : Colors.black87,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: Text(label),
    );
  }
}
