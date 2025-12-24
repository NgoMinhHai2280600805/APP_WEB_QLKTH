import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/current_user.dart';
import '../../../core/services/product_service.dart';
import 'chi_tiet_xuat_kho.dart';

class LichSuXuatKhoScreen extends StatefulWidget {
  const LichSuXuatKhoScreen({super.key});

  @override
  State<LichSuXuatKhoScreen> createState() => _LichSuXuatKhoScreenState();
}

class _LichSuXuatKhoScreenState extends State<LichSuXuatKhoScreen> {
  final _service = ProductService();
  List<Map<String, dynamic>> _logs = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;

  String _selectedUser = "Tất cả";
  String _selectedTime = "Tất cả";

  List<String> _userList = [];
  final List<String> _timeFilters = [
    'Tất cả',
    'Hôm nay',
    '7 ngày qua',
    '30 ngày qua',
  ];

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  int visibleCount = 10;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    final logs = await _service.getStaffExportLogs();

    // Sort mới nhất trước
    logs.sort((a, b) {
      final Timestamp? at = a['exported_at'] ?? a['created_at'];
      final Timestamp? bt = b['exported_at'] ?? b['created_at'];
      if (at == null || bt == null) return 0;
      return bt.compareTo(at);
    });

    // Xây dựng danh sách nhân viên cho filter
    final allEmails =
        logs
            .map((r) => (r['staff_email'] ?? '').toString().trim())
            .where((e) => e.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    final currentEmail = (CurrentUser.email ?? CurrentUser.username ?? '')
        .trim();
    final users = <String>['Tất cả'];
    if (currentEmail.isNotEmpty && allEmails.contains(currentEmail)) {
      users.add('Tôi');
      allEmails.remove(currentEmail);
    }

    final otherUsers = allEmails.map((e) {
      final match = logs.firstWhere(
        (l) => l['staff_email'] == e,
        orElse: () => <String, dynamic>{},
      );
      final name = (match['staff_name'] ?? '').toString();
      return name.isNotEmpty ? "$name ($e)" : e;
    }).toList();
    users.addAll(otherUsers);

    setState(() {
      _logs = logs;
      _filtered = logs;
      _userList = users;
      _loading = false;
      visibleCount = 10;
    });
  }

  void _applyFilter() {
    final now = DateTime.now();
    final currentEmail = (CurrentUser.email ?? CurrentUser.username ?? '')
        .trim();

    setState(() {
      _filtered = _logs.where((r) {
        final email = (r['staff_email'] ?? '').toString().trim();
        final Timestamp? ts = r['exported_at'] ?? r['created_at'];
        if (ts == null) return false;
        final date = ts.toDate();

        bool timeMatch = true;
        if (_selectedTime == 'Hôm nay') {
          timeMatch =
              date.day == now.day &&
              date.month == now.month &&
              date.year == now.year;
        } else if (_selectedTime == '7 ngày qua') {
          timeMatch = now.difference(date).inDays <= 7;
        } else if (_selectedTime == '30 ngày qua') {
          timeMatch = now.difference(date).inDays <= 30;
        }

        bool userMatch = true;
        if (_selectedUser == 'Tôi') {
          userMatch = email == currentEmail;
        } else if (_selectedUser != 'Tất cả') {
          final extractedEmail = _selectedUser.contains('(')
              ? _selectedUser.split('(').last.replaceAll(')', '').trim()
              : _selectedUser;
          userMatch = email == extractedEmail;
        }

        return timeMatch && userMatch;
      }).toList();

      visibleCount = 10;
    });
  }

  String _formatTime(dynamic ts) {
    if (ts == null) return 'N/A';
    final Timestamp timestamp = ts is Timestamp ? ts : Timestamp.now();
    return DateFormat('dd/MM/yyyy HH:mm').format(timestamp.toDate());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text("Lịch sử xuất kho"),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
        ],
      ),
      endDrawer: Drawer(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: StatefulBuilder(
              builder: (context, setDrawerState) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      "Bộ lọc",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(height: 32),
                    const Text(
                      "Nhân viên",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButton<String>(
                        value: _selectedUser,
                        isExpanded: true,
                        underline: const SizedBox(),
                        items: _userList
                            .map(
                              (u) => DropdownMenuItem(
                                value: u,
                                child: Text(u, overflow: TextOverflow.ellipsis),
                              ),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setDrawerState(() => _selectedUser = v!),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "Thời gian",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButton<String>(
                        value: _selectedTime,
                        isExpanded: true,
                        underline: const SizedBox(),
                        items: _timeFilters
                            .map(
                              (t) => DropdownMenuItem(
                                value: t,
                                child: Text(t, overflow: TextOverflow.ellipsis),
                              ),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setDrawerState(() => _selectedTime = v!),
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setDrawerState(() {
                                _selectedUser = 'Tất cả';
                                _selectedTime = 'Tất cả';
                              });
                              _applyFilter();
                            },
                            child: const Text("Đặt lại"),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _applyFilter();
                            },
                            child: const Text("Áp dụng"),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    "Tổng: ${_filtered.length} lượt xuất kho",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadLogs,
                    child: ScrollConfiguration(
                      behavior: const ScrollBehavior().copyWith(
                        overscroll: false,
                        physics: const ClampingScrollPhysics(),
                      ),
                      child: _filtered.isEmpty
                          ? const Center(
                              child: Text("Không có dữ liệu phù hợp"),
                            )
                          : ListView.separated(
                              itemCount: _filtered.length > visibleCount
                                  ? visibleCount + 1
                                  : _filtered.length + 1,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (_, i) {
                                if (i < visibleCount && i < _filtered.length) {
                                  final l = _filtered[i];
                                  final Timestamp? ts =
                                      l['exported_at'] ?? l['created_at'];
                                  final time = _formatTime(ts);

                                  // Mã phiếu
                                  final receiptNumber =
                                      l['receipt_number'] ?? 'N/A';

                                  // Đếm số lô
                                  final batches =
                                      (l['batches'] as List<dynamic>?) ?? [];
                                  final batchCount = batches.length;

                                  // Preview sản phẩm (tối đa 2 dòng)
                                  final Set<String> previewItems = {};
                                  for (final b in batches.take(2)) {
                                    final products =
                                        (b as Map)['products']
                                            as List<dynamic>? ??
                                        [];
                                    for (final p in products) {
                                      final prodName =
                                          p['product_name'] ?? 'Không rõ';
                                      final catName = p['category_name'] ?? '';
                                      if (catName.isNotEmpty) {
                                        previewItems.add(
                                          "$prodName ($catName)",
                                        );
                                      } else {
                                        previewItems.add(prodName);
                                      }
                                    }
                                  }
                                  final previewText = previewItems.isEmpty
                                      ? "Không có sản phẩm"
                                      : previewItems.join(" • ");

                                  return InkWell(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              ChiTietXuatKhoScreen(data: l),
                                        ),
                                      );
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 10,
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Icon(
                                            Icons.local_shipping_outlined,
                                            color: Colors.orange,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  "Mã phiếu: $receiptNumber",
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  previewText,
                                                  style: const TextStyle(
                                                    fontSize: 13.5,
                                                  ),
                                                ),
                                                if (batches.length > 2 ||
                                                    previewItems.length > 2)
                                                  const Text(
                                                    "... và các sản phẩm khác",
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey,
                                                    ),
                                                  ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  "Tổng xuất: ${l['total_export'] ?? 0} • Số lô: $batchCount",
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                Text(
                                                  "Nhân viên: ${l['staff_name'] ?? 'Không rõ'} (${l['staff_email'] ?? ''})",
                                                ),
                                                Text(
                                                  "Thời gian: $time",
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.black54,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                } else {
                                  if (_filtered.length > visibleCount) {
                                    return TextButton.icon(
                                      onPressed: () {
                                        setState(() {
                                          visibleCount += 10;
                                          if (visibleCount > _filtered.length)
                                            visibleCount = _filtered.length;
                                        });
                                      },
                                      icon: const Icon(
                                        Icons.keyboard_double_arrow_down,
                                      ),
                                      label: const Text(
                                        "Xem thêm",
                                        style: TextStyle(color: Colors.blue),
                                      ),
                                    );
                                  } else {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      alignment: Alignment.center,
                                      child: const Text(
                                        "Đã hiển thị hết",
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                    );
                                  }
                                }
                              },
                            ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
