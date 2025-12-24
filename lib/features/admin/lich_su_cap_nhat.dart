import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/product_service.dart';

class LichSuCapNhatScreen extends StatefulWidget {
  const LichSuCapNhatScreen({super.key});

  @override
  State<LichSuCapNhatScreen> createState() => _LichSuCapNhatScreenState();
}

class _LichSuCapNhatScreenState extends State<LichSuCapNhatScreen> {
  final _service = ProductService();
  List<Map<String, dynamic>> _logs = [];
  bool _loading = true;
  int visibleCount = 10;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  String formatTimestamp(dynamic ts) {
    if (ts == null) return '---';
    try {
      if (ts is Timestamp)
        return DateFormat('dd/MM/yyyy HH:mm').format(ts.toDate());
      if (ts is DateTime) return DateFormat('dd/MM/yyyy HH:mm').format(ts);
      return ts.toString();
    } catch (_) {
      return ts.toString();
    }
  }

  Future<void> _loadLogs() async {
    final logs = await _service.getAdminUpdateLogs();

    logs.sort((a, b) {
      DateTime? at;
      DateTime? bt;

      final aTs = a['updated_at'];
      final bTs = b['updated_at'];

      if (aTs is Timestamp) {
        at = aTs.toDate();
      } else if (aTs is DateTime) {
        at = aTs;
      }

      if (bTs is Timestamp) {
        bt = bTs.toDate();
      } else if (bTs is DateTime) {
        bt = bTs;
      }

      if (at == null || bt == null) return 0;
      return bt.compareTo(at);
    });

    if (mounted) {
      setState(() {
        _logs = logs;
        _loading = false;
      });
    }
  }

  int parseQuantity(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final appBar = AppBar(
      title: const Text("Lịch sử cập nhật kho (Admin)"),
      backgroundColor: Colors.purple,
    );

    if (_loading) {
      return Scaffold(
        appBar: appBar,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_logs.isEmpty) {
      return Scaffold(
        appBar: appBar,
        body: const Center(child: Text("Chưa có lịch sử cập nhật")),
      );
    }

    final displayLogs = _logs.take(visibleCount).toList();

    return Scaffold(
      appBar: appBar,
      body: RefreshIndicator(
        onRefresh: _loadLogs,
        child: ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: displayLogs.length + 1,
          separatorBuilder: (_, __) => Container(
            height: 1,
            color: Colors.black26,
            margin: const EdgeInsets.symmetric(vertical: 6),
          ),
          itemBuilder: (_, i) {
            if (i < displayLogs.length) {
              final l = displayLogs[i];

              final category = l['category_name'] ?? '---';
              final product = l['product_name'] ?? '---';
              final batch = l['batch_number'] ?? '---';
              final admin = l['admin_name'] ?? '---';
              final role = l['admin_role'] ?? '';
              final time = formatTimestamp(l['updated_at']);

              final oldBatchQty = parseQuantity(l['old_batch_quantity']);
              final newBatchQty = parseQuantity(l['new_batch_quantity']);
              final oldTotalQty = parseQuantity(l['old_quantity']);
              final newTotalQty = parseQuantity(l['new_quantity']);

              final isIncrease = newBatchQty > oldBatchQty;
              final Color color = isIncrease
                  ? Colors.green.shade700
                  : Colors.red.shade700;
              final IconData icon = isIncrease
                  ? Icons.arrow_upward
                  : Icons.arrow_downward;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: color, size: 18),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        "Cập nhật sản phẩm",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text("Loại hàng: $category"),
                  Text("Sản phẩm: $product"),
                  Text("Mã lô: $batch"),
                  Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(text: "Số lượng lô: "),
                        TextSpan(
                          text: "$oldBatchQty → $newBatchQty",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Người cập nhật: $admin ${role.isNotEmpty ? '($role)' : ''}",
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Thời gian: $time",
                    style: const TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 6),
                  const Divider(color: Colors.black12, thickness: 0.5),
                  Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(text: "Tổng số lượng sản phẩm: "),
                        TextSpan(
                          text: "$oldTotalQty → $newTotalQty",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            } else {
              if (_logs.length > visibleCount) {
                return TextButton.icon(
                  onPressed: () {
                    setState(() {
                      visibleCount += 15;
                      if (visibleCount > _logs.length)
                        visibleCount = _logs.length;
                    });
                  },
                  icon: const Icon(Icons.keyboard_double_arrow_down),
                  label: const Text(
                    "Xem thêm",
                    style: TextStyle(color: Colors.blue),
                  ),
                );
              } else {
                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  alignment: Alignment.center,
                  child: const Text(
                    "Không có dữ liệu",
                    style: TextStyle(color: Colors.grey),
                  ),
                );
              }
            }
          },
        ),
      ),
    );
  }
}
