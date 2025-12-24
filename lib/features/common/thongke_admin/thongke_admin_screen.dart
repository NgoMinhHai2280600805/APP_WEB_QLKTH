// lib/features/common/thongke_admin/thongke_admin_screen.dart

import 'package:flutter/material.dart';

import '../../../core/services/product_service.dart';
import '../../../main.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'components/chart_section.dart';
import 'components/daily_quantity_card.dart';
import 'components/time_filter_section.dart';
import 'components/transaction_list_card.dart';
import 'components/import_history_card.dart';
import 'components/summary_cards.dart';
import 'utils/thongke_utils.dart';
import 'expired_batches_screen.dart';
import '../../../widgets/gemini_chat_window.dart';

class ThongKeAdminScreen extends StatefulWidget {
  const ThongKeAdminScreen({super.key});

  @override
  State<ThongKeAdminScreen> createState() => _ThongKeAdminScreenState();
}

class _ThongKeAdminScreenState extends State<ThongKeAdminScreen> {
  final ProductService _service = ProductService();

  bool _loading = true;

  List<Map<String, dynamic>> _staffExportLogs = [];
  List<Map<String, dynamic>> _realImportLogs = [];
  List<Map<String, dynamic>> _products = [];

  String _selectedTime = 'Tất cả';
  DateTimeRange? _customRange;

  Map<String, int> _exportsByDay = {};
  Map<String, int> _importsByDay = {};

  int _totalImportQty = 0;
  int _totalExportQty = 0;
  double _totalExportValue = 0.0;
  int _currentStock = 0;
  double _totalStockValue = 0.0;

  Map<String, dynamic> _expiredBatchesData = {};
  int _expiredCount = 0;
  int _nearExpiredCount = 0;
  static const int nearExpiryDays = 30;

  Future<void> _loadExpiredBatchesSummary() async {
    // (giữ nguyên hoàn toàn hàm này như cũ)
    try {
      final categories = await _service.getCategories();
      final Map<String, String> categoryNameMap = {
        for (var cat in categories)
          cat['id'] as String: cat['name'] as String? ?? 'Không phân loại',
      };

      final products = await _service.getProducts();
      final now = DateTime.now();

      int expiredCount = 0;
      int nearExpiredCount = 0;
      final List<String> summaryLines = [];

      for (var product in products) {
        final productName = product['name'] as String? ?? 'Không tên';
        final categoryId = product['category_id'] as String? ?? 'uncategorized';
        final categoryName = categoryNameMap[categoryId] ?? 'Không phân loại';

        final productId = product['id'] as String;
        final batches = await _service.getProductBatches(productId);

        final List<String> productLines = [];

        for (var batch in batches) {
          final int quantity = (batch['quantity'] as num?)?.toInt() ?? 0;
          if (quantity <= 0) continue;

          DateTime? expiryDate;
          final expiryField = batch['exp_date'];
          if (expiryField is Timestamp) {
            expiryDate = expiryField.toDate();
          } else if (expiryField is String && expiryField.isNotEmpty) {
            try {
              expiryDate = DateFormat('dd/MM/yyyy').parseStrict(expiryField);
            } catch (_) {}
            if (expiryDate == null)
              try {
                expiryDate = DateTime.parse(expiryField);
              } catch (_) {}
          }
          if (expiryDate == null) continue;

          final daysLeft = expiryDate.difference(now).inDays;
          final isExpired = daysLeft < 0;

          if (isExpired) {
            expiredCount++;
            productLines.add(
              '- Lô ${batch['batch_number'] ?? '-'} ($quantity sp), hết hạn ${-daysLeft} ngày',
            );
          } else if (daysLeft <= nearExpiryDays) {
            nearExpiredCount++;
            productLines.add(
              '- Lô ${batch['batch_number'] ?? '-'} ($quantity sp), còn $daysLeft ngày',
            );
          }
        }

        if (productLines.isNotEmpty) {
          summaryLines.add('$categoryName > $productName:');
          summaryLines.addAll(productLines.map((line) => '  $line'));
        }
      }

      setState(() {
        _expiredCount = expiredCount;
        _nearExpiredCount = nearExpiredCount;
        _expiredBatchesData = {
          'summary': summaryLines.isEmpty
              ? 'Không có lô nào hết hạn hoặc sắp hết hạn.'
              : summaryLines.join('\n'),
        };
      });
    } catch (e) {
      debugPrint('Lỗi load lô hết hạn summary: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // (giữ nguyên)
    setState(() => _loading = true);
    try {
      final futures = await Future.wait([
        _service.getAllStaffExportLogs(),
        _service.getImportLogs(),
        _service.getProducts(),
        _service.getCategories(),
      ]);

      _staffExportLogs = (futures[0] as List).cast<Map<String, dynamic>>();
      _realImportLogs = (futures[1] as List).cast<Map<String, dynamic>>();
      _products = (futures[2] as List).cast<Map<String, dynamic>>();
      _computeStats();
      await _loadExpiredBatchesSummary();
    } catch (e) {
      debugPrint('Lỗi thống kê admin: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi tải dữ liệu: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _computeStats() {
    // (giữ nguyên toàn bộ)
    _exportsByDay.clear();
    _importsByDay.clear();

    _totalImportQty = 0;
    _totalExportQty = 0;
    _totalExportValue = 0.0;
    _currentStock = 0;
    _totalStockValue = 0.0;

    final Map<String, double> productPriceMap = {};
    for (var p in _products) {
      final id = p['id'] as String;
      final price = (p['price'] as num?)?.toDouble() ?? 0.0;
      productPriceMap[id] = price;
    }

    for (var log in _staffExportLogs) {
      final date = ThongkeUtils.convertTimestamp(log['exported_at']);
      if (date == null || !_isInRange(date)) continue;

      final key = ThongkeUtils.keyFormat.format(date);
      int logQty = 0;
      double logValue = 0.0;

      final batches = log['batches'] as List<dynamic>? ?? [];
      for (var batch in batches) {
        final products = (batch['products'] as List<dynamic>? ?? []);
        for (var p in products) {
          final qty = (p['quantity'] as num?)?.toInt() ?? 0;
          final productId = p['product_id'] as String?;
          final price = productId != null
              ? (productPriceMap[productId] ?? 0.0)
              : 0.0;

          logQty += qty;
          logValue += qty * price;
        }
      }

      _exportsByDay[key] = (_exportsByDay[key] ?? 0) + logQty;
      _totalExportQty += logQty;
      _totalExportValue += logValue;
    }

    for (var log in _realImportLogs) {
      final date = ThongkeUtils.convertTimestamp(log['created_at']);
      if (date == null || !_isInRange(date)) continue;

      final key = ThongkeUtils.keyFormat.format(date);
      int logQty = 0;

      final batches = log['batches'] as List<dynamic>? ?? [];
      for (var batch in batches) {
        final products = (batch['products'] as List<dynamic>? ?? []);
        for (var p in products) {
          logQty += (p['quantity'] as num?)?.toInt() ?? 0;
        }
      }

      if (logQty > 0) {
        _importsByDay[key] = (_importsByDay[key] ?? 0) + logQty;
        _totalImportQty += logQty;
      }
    }

    for (var product in _products) {
      final qty = (product['quantity'] as num?)?.toInt() ?? 0;
      final price = (product['price'] as num?)?.toDouble() ?? 0.0;
      _currentStock += qty;
      _totalStockValue += qty * price;
    }

    setState(() {});
  }

  bool _isInRange(DateTime date) {
    // (giữ nguyên)
    if (_selectedTime == 'Tất cả') return true;
    final now = DateTime.now();
    switch (_selectedTime) {
      case 'Hôm nay':
        return date.year == now.year &&
            date.month == now.month &&
            date.day == now.day;
      case '7 ngày qua':
        return now.difference(date).inDays < 7;
      case '30 ngày qua':
        return now.difference(date).inDays < 30;
      case 'Tùy chọn':
        if (_customRange == null) return true;
        return date.isAfter(
              _customRange!.start.subtract(const Duration(days: 1)),
            ) &&
            date.isBefore(_customRange!.end.add(const Duration(days: 1)));
      default:
        return true;
    }
  }

  void _selectTime(String time, {DateTimeRange? range}) {
    setState(() {
      _selectedTime = time;
      _customRange = range;
      _computeStats();
    });
  }

  Future<void> _selectCustomRange() async {
    // (giữ nguyên)
    final start = await showDatePicker(
      context: context,
      initialDate: _customRange?.start ?? DateTime.now(),
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      helpText: 'Chọn ngày bắt đầu',
    );
    if (start == null) return;

    final end = await showDatePicker(
      context: context,
      initialDate: _customRange?.end ?? start,
      firstDate: start,
      lastDate: DateTime.now(),
      helpText: 'Chọn ngày kết thúc',
    );

    if (end != null) {
      _selectTime(
        'Tùy chọn',
        range: DateTimeRange(start: start, end: end),
      );
    }
  }

  double _determineYAxisMax(double maxValue) {
    // (giữ nguyên)
    if (maxValue <= 10) return 10;
    if (maxValue <= 100) return 100;
    if (maxValue <= 500) return 500;
    if (maxValue <= 1000) return 1000;
    if (maxValue <= 5000) return 5000;
    if (maxValue <= 10000) return 10000;
    return (maxValue / 10000).ceil() * 10000;
  }

  Widget _buildNoStretchListView({required List<Widget> children}) {
    return ScrollConfiguration(
      behavior: ScrollBehavior().copyWith(
        overscroll: false,
        physics: const ClampingScrollPhysics(),
      ),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        children: children,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allKeys = {..._exportsByDay.keys, ..._importsByDay.keys}.toList()
      ..sort((a, b) => b.compareTo(a));
    final maxValue = [
      ..._exportsByDay.values,
      ..._importsByDay.values,
    ].fold(0, (p, c) => c > p ? c : p);
    final maxY = _determineYAxisMax(maxValue.toDouble());
    final hasData = allKeys.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thống kê hệ thống'),
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
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'expired_batches') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ExpiredBatchesScreen(),
                  ),
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'expired_batches',
                child: Text('Xem lô hàng hết hạn, sắp hết hạn'),
              ),
            ],
          ),
        ],
      ),

      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                RefreshIndicator(
                  onRefresh: _loadData,
                  child: _buildNoStretchListView(
                    children: [
                      TimeFilterSection(
                        selectedTime: _selectedTime,
                        customRange: _customRange,
                        onAll: () => _selectTime('Tất cả'),
                        onToday: () => _selectTime('Hôm nay'),
                        on7Days: () => _selectTime('7 ngày qua'),
                        on30Days: () => _selectTime('30 ngày qua'),
                        onCustom: _selectCustomRange,
                      ),
                      const SizedBox(height: 16),
                      SummaryCards(
                        totalImportQty: _totalImportQty,
                        totalExportQty: _totalExportQty,
                        totalExportValue: _totalExportValue,
                        currentStock: _currentStock,
                        totalStockValue: _totalStockValue,
                      ),
                      const SizedBox(height: 20),
                      if (hasData) ...[
                        ChartSection(
                          allKeys: allKeys,
                          exportsByDay: _exportsByDay,
                          importsByDay: _importsByDay,
                          maxY: maxY,
                        ),
                        const SizedBox(height: 12),
                        DailyQuantityCard(
                          allKeys: allKeys,
                          exportsByDay: _exportsByDay,
                          importsByDay: _importsByDay,
                        ),
                        const SizedBox(height: 16),
                        ImportHistoryCard(
                          importLogs: _realImportLogs,
                          isInRange: _isInRange,
                        ),
                        const SizedBox(height: 16),
                        TransactionListCard(
                          title: 'Phiếu xuất kho (nhân viên)',
                          data: _staffExportLogs,
                          timeField: 'exported_at',
                          isInRange: _isInRange,
                        ),
                      ] else ...[
                        const SizedBox(height: 100),
                        Center(
                          child: Text(
                            'Không có dữ liệu nhập/xuất trong khoảng thời gian này',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ),
                      ],
                      const SizedBox(
                        height: 100,
                      ), // Đệm dưới để FAB không che nội dung
                    ],
                  ),
                ),

                // FAB Chat cố định góc phải dưới - đẹp, mượt, dùng ảnh icon.png
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: FloatingActionButton(
                    elevation: 8,
                    backgroundColor: Colors.white,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        image: DecorationImage(
                          image: AssetImage('assets/icon.png'),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => DraggableScrollableSheet(
                          initialChildSize: 0.9,
                          minChildSize: 0.7,
                          maxChildSize: 0.95,
                          builder: (context, scrollController) {
                            return Container(
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(20),
                                ),
                              ),
                              child: GeminiChatWindow(
                                statsContext:
                                    '''
DỮ LIỆU THỐNG KÊ KHO HÀNG HIỆN TẠI (thời gian lọc: $_selectedTime${_customRange != null ? ' từ ${_customRange!.start.day}/${_customRange!.start.month} đến ${_customRange!.end.day}/${_customRange!.end.month}' : ''}):
- Tổng nhập kho: $_totalImportQty sản phẩm
- Tổng xuất kho: $_totalExportQty sản phẩm
- Doanh thu xuất kho: ${_totalExportValue.toStringAsFixed(0)} đồng
- Tồn kho hiện tại: $_currentStock sản phẩm (giá trị khoảng ${_totalStockValue.toStringAsFixed(0)} đồng)

LÔ HÀNG HẾT HẠN & SẮP HẾT HẠN (còn ≤ $nearExpiryDays ngày):
- Số lô đã hết hạn: $_expiredCount lô
- Số lô sắp hết hạn: $_nearExpiredCount lô
${_expiredBatchesData['summary'] ?? 'Đang tải...'}

Bạn là trợ lý AI thân thiện, vui vẻ của app quản lý kho hàng. 
Trả lời bằng tiếng Việt, tự nhiên như đang trò chuyện với bạn bè.
- Nếu người dùng chào hỏi, chit chat → trả lời vui vẻ, không cần nhắc dữ liệu kho.
- Chỉ dùng dữ liệu khi hỏi về thống kê, tồn kho, lô hết hạn...
- Nếu có lô hết hạn → gợi ý xử lý phù hợp.
- Không có dữ liệu → nói "Hiện tại chưa có dữ liệu nhé!".

Câu hỏi của người dùng sẽ ở phần cuối.
''',
                                isFromThongKe: true,
                                onClose: () => Navigator.pop(
                                  context,
                                ), // ← Dòng quan trọng này!
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
