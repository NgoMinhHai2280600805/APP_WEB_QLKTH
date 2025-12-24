// lib/features/common/thongke_staff/thongke_staff_screen.dart
import 'package:flutter/material.dart';

import '../../../core/services/product_service.dart';
import '../../../core/current_user.dart';
import '../../../main.dart';

import 'components/time_filter_section.dart';
import 'components/total_quantity_card.dart';
import 'components/chart_section.dart';
import 'components/daily_exports_card.dart';
import 'components/recent_exports_list.dart';
import 'utils/thongke_staff_utils.dart';

class ThongKeStaffScreen extends StatefulWidget {
  const ThongKeStaffScreen({super.key});

  @override
  State<ThongKeStaffScreen> createState() => _ThongKeStaffScreenState();
}

class _ThongKeStaffScreenState extends State<ThongKeStaffScreen> {
  final ProductService _service = ProductService();
  bool _loading = true;
  List<Map<String, dynamic>> _exportLogs = [];

  int _totalExports = 0;
  Map<String, int> _exportsByDay = {};

  String _selectedTime = 'Hôm nay';
  DateTimeRange? _customRange;

  @override
  void initState() {
    super.initState();
    loadData(); // Chỉ load lần đầu khi mở màn hình
  }

  // Không còn timer auto-refresh nữa

  Future<void> loadData() async {
    setState(() => _loading = true);
    try {
      final exports = await _service.getStaffExportLogs();
      final email = (CurrentUser.email ?? CurrentUser.username ?? '').trim();

      final newLogs = exports
          .where((e) => (e['staff_email'] ?? '') == email)
          .toList();

      // Cập nhật dữ liệu và tính toán lại stats
      _exportLogs = newLogs;
      _computeStats();
    } catch (e) {
      print("Load error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Lỗi tải dữ liệu, thử lại sau")),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _computeStats() {
    _exportsByDay = {};
    _totalExports = 0;

    for (var e in _exportLogs) {
      final date = convertTimestamp(e['exported_at']);
      if (date == null || !isInRange(date, _selectedTime, _customRange)) {
        continue;
      }

      final key = keyFmt.format(date);
      final qty = int.tryParse(e['total_export'].toString()) ?? 0;

      _exportsByDay[key] = (_exportsByDay[key] ?? 0) + qty;
      _totalExports += qty;
    }

    if (mounted) setState(() {}); // Cập nhật chart và card
  }

  void _updateTimeFilter(String newTime, DateTimeRange? newRange) {
    setState(() {
      _selectedTime = newTime;
      _customRange = newRange;
      _computeStats(); // Chỉ recalculate, không reload dữ liệu mới
    });
  }

  @override
  Widget build(BuildContext context) {
    final allKeys = _exportsByDay.keys.toList()..sort();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thống kê cá nhân'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => const HomePage(initialIndex: 0),
                ),
              );
            }
          },
        ),
        actions: [
          IconButton(
            onPressed: loadData, // Refresh thủ công bằng nút
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _exportLogs.isEmpty
          ? const Center(
              child: Text(
                "Chưa có dữ liệu xuất kho nào",
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : RefreshIndicator(
              onRefresh: loadData, // Kéo xuống để refresh
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TimeFilterSection(
                    selectedTime: _selectedTime,
                    customRange: _customRange,
                    onTimeChanged: _updateTimeFilter,
                  ),
                  const SizedBox(height: 12),
                  TotalQuantityCard(totalExports: _totalExports),
                  const SizedBox(height: 16),

                  if (allKeys.isNotEmpty) ...[
                    ChartSection(
                      exportsByDay: _exportsByDay,
                      totalExports: _totalExports,
                    ),
                    const SizedBox(height: 16),
                    DailyExportsCard(exportsByDay: _exportsByDay),
                    const SizedBox(height: 16),
                  ],

                  RecentExportsList(exportLogs: _exportLogs),
                ],
              ),
            ),
    );
  }
}
