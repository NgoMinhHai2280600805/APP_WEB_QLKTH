import 'package:intl/intl.dart';

class ThongkeUtils {
  static final DateFormat keyFormat = DateFormat('yyyy-MM-dd');
  static final DateFormat labelFormat = DateFormat('dd/MM');

  static DateTime? convertTimestamp(dynamic ts) {
    try {
      if (ts == null) return null;
      if (ts is DateTime) return ts;
      if (ts.toString().contains('Timestamp')) return (ts as dynamic).toDate();
      if (ts is Map && ts.containsKey('_seconds')) {
        return DateTime.fromMillisecondsSinceEpoch(ts['_seconds'] * 1000);
      }
      return DateTime.tryParse(ts.toString());
    } catch (_) {
      return null;
    }
  }

  static int getQtyFromLog(Map<String, dynamic> e) {
    if (e.containsKey('quantity')) {
      return int.tryParse(e['quantity'].toString()) ?? 0;
    }
    final newQ = int.tryParse((e['new_quantity'] ?? '').toString()) ?? 0;
    final oldQ = int.tryParse((e['old_quantity'] ?? '').toString()) ?? 0;
    final added = newQ - oldQ;
    if (added > 0) return added;
    return int.tryParse((e['quantity_added'] ?? '').toString()) ?? 0;
  }
}
