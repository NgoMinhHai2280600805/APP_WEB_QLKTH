// lib/features/thongke_staff/utils/thongke_staff_utils.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

final DateFormat keyFmt = DateFormat('yyyy-MM-dd');
final DateFormat labelFmt = DateFormat('dd/MM');

DateTime? convertTimestamp(dynamic ts) {
  try {
    if (ts == null) return null;
    if (ts is DateTime) return ts;
    if (ts.toString().contains('Timestamp')) return ts.toDate();
    if (ts is Map && ts.containsKey('_seconds')) {
      return DateTime.fromMillisecondsSinceEpoch(ts['_seconds'] * 1000);
    }
    return DateTime.tryParse(ts.toString());
  } catch (_) {
    return null;
  }
}

bool isInRange(DateTime date, String selectedTime, DateTimeRange? customRange) {
  final now = DateTime.now();
  switch (selectedTime) {
    case 'Hôm nay':
      return date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;
    case '7 ngày qua':
      return now.difference(date).inDays < 7;
    case '30 ngày qua':
      return now.difference(date).inDays < 30;
    case 'Tùy chọn':
      if (customRange == null) return true;
      return date.isAfter(
            customRange.start.subtract(const Duration(days: 1)),
          ) &&
          date.isBefore(customRange.end.add(const Duration(days: 1)));
    default:
      return true;
  }
}
