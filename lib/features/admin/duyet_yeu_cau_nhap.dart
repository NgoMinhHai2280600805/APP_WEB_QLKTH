import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/services/product_service.dart';
import '../../../main.dart';

class DuyetYeuCauNhapScreen extends StatefulWidget {
  const DuyetYeuCauNhapScreen({super.key});

  @override
  State<DuyetYeuCauNhapScreen> createState() => _DuyetYeuCauNhapScreenState();
}

class _DuyetYeuCauNhapScreenState extends State<DuyetYeuCauNhapScreen> {
  final _service = ProductService();
  List<Map<String, dynamic>> _requests = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;
  String _selectedUser = "Tất cả";
  String _selectedTime = "Tất cả";
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    final data = await _service.getImportRequests();

    // Ưu tiên hiển thị các yêu cầu đang chờ duyệt
    data.sort((a, b) {
      final sA = (a['status'] ?? '').toString().toLowerCase();
      final sB = (b['status'] ?? '').toString().toLowerCase();
      if (sA == 'đang chờ duyệt' && sB != 'đang chờ duyệt') return -1;
      if (sA != 'đang chờ duyệt' && sB == 'đang chờ duyệt') return 1;
      return 0;
    });

    setState(() {
      _requests = data;
      _filtered = data;
      _loading = false;
    });
  }

  List<String> get _userList {
    final users = _requests
        .map((r) => (r['staff_email'] ?? '').toString())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    users.sort();
    return ['Tất cả', ...users];
  }

  List<String> get _timeFilters => [
    'Tất cả',
    'Hôm nay',
    '7 ngày qua',
    '30 ngày qua',
  ];

  void _applyFilter() {
    final now = DateTime.now();
    setState(() {
      _filtered = _requests.where((r) {
        final email = (r['staff_email'] ?? '').toString();
        final ts = r['created_at'];
        if (ts == null) return false;
        final date = ts.toDate() as DateTime;

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

        bool userMatch = _selectedUser == 'Tất cả'
            ? true
            : email == _selectedUser;

        return timeMatch && userMatch;
      }).toList();
    });
  }

  Future<void> _approveRequest(Map<String, dynamic> req) async {
    await FirebaseFirestore.instance
        .collection('import_requests')
        .doc(req['id'])
        .update({
          'status': 'Đã duyệt',
          'updated_at': FieldValue.serverTimestamp(), // thêm dòng này
        });
  }

  Future<void> _rejectRequest(String id, String currentStatus) async {
    if (currentStatus.toLowerCase() == 'đã duyệt')
      return; // ❌ Không từ chối nếu đã duyệt
    await FirebaseFirestore.instance
        .collection('import_requests')
        .doc(id)
        .update({
          'status': 'Từ chối',
          'updated_at': FieldValue.serverTimestamp(), // thêm dòng này
        });
  }

  Future<void> _deleteRequest(String id) async {
    await FirebaseFirestore.instance
        .collection('import_requests')
        .doc(id)
        .delete();
    _loadRequests();
  }

  Future<void> _approveAll() async {
    for (var id in _selectedIds) {
      await FirebaseFirestore.instance
          .collection('import_requests')
          .doc(id)
          .update({'status': 'Đã duyệt'});
    }
    _selectedIds.clear();
    _loadRequests();
  }

  Future<void> _rejectAll() async {
    for (var id in _selectedIds) {
      final req = _filtered.firstWhere((r) => r['id'] == id);
      final status = (req['status'] ?? '').toString().toLowerCase();
      if (status != 'đã duyệt') {
        await FirebaseFirestore.instance
            .collection('import_requests')
            .doc(id)
            .update({'status': 'Từ chối'});
      }
    }
    _selectedIds.clear();
    _loadRequests();
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'đã duyệt':
        return Colors.green;
      case 'từ chối':
        return Colors.red;
      case 'đã hủy':
        return Colors.grey;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Duyệt yêu cầu nhập kho"),
        backgroundColor: Colors.blue,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (_) => const HomePage(initialIndex: 0),
              ),
              (route) => false,
            );
          },
        ),
        actions: [
          if (_selectedIds.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.check_circle, color: Colors.black),
              tooltip: "Duyệt tất cả",
              onPressed: _approveAll,
            ),
          if (_selectedIds.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.cancel, color: Colors.black),
              tooltip: "Từ chối tất cả",
              onPressed: _rejectAll,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // --- Bộ lọc ---
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      Flexible(
                        flex: 1,
                        child: DropdownButtonFormField<String>(
                          value: _selectedUser,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: "Nhân viên",
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                          ),
                          items: _userList
                              .map(
                                (u) => DropdownMenuItem(
                                  value: u,
                                  child: Text(
                                    u,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {
                            _selectedUser = val!;
                            _applyFilter();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        flex: 1,
                        child: DropdownButtonFormField<String>(
                          value: _selectedTime,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: "Thời gian",
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                          ),
                          items: _timeFilters
                              .map(
                                (t) => DropdownMenuItem(
                                  value: t,
                                  child: Text(
                                    t,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {
                            _selectedTime = val!;
                            _applyFilter();
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    "Tổng: ${_filtered.length} yêu cầu",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),

                // --- Danh sách ---
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadRequests,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: _filtered.length,
                      itemBuilder: (context, i) {
                        final r = _filtered[i];
                        final id = r['id'];
                        final status = (r['status'] ?? 'Đang chờ duyệt')
                            .toString();
                        final category = r['category_name'] ?? 'Không xác định';
                        final productNames = (r['product_names'] is List)
                            ? (r['product_names'] as List)
                                  .map((e) => "• $e")
                                  .join('\n')
                            : r['product_name'] ?? '';
                        final time = (r['created_at'] != null)
                            ? DateFormat(
                                'dd/MM/yyyy HH:mm',
                              ).format(r['created_at'].toDate())
                            : 'N/A';
                        final isSelected = _selectedIds.contains(id);

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Checkbox(
                                  value: isSelected,
                                  onChanged: (val) {
                                    setState(() {
                                      if (val == true) {
                                        _selectedIds.add(id);
                                      } else {
                                        _selectedIds.remove(id);
                                      }
                                    });
                                  },
                                  activeColor: Colors.black,
                                ),
                                Flexible(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Danh mục: $category",
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text("Sản phẩm:\n$productNames"),
                                      const SizedBox(height: 4),
                                      Text(
                                        "Người gửi: ${r['staff_name'] ?? 'N/A'} (${r['staff_email'] ?? ''})",
                                        style: const TextStyle(
                                          color: Colors.black54,
                                          fontSize: 13,
                                        ),
                                      ),
                                      Text(
                                        "Thời gian: $time",
                                        style: const TextStyle(
                                          color: Colors.black54,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                SizedBox(
                                  width: 70,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        status,
                                        style: TextStyle(
                                          color: _statusColor(status),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      if (status.toLowerCase() ==
                                          'đang chờ duyệt') ...[
                                        IconButton(
                                          icon: const Icon(Icons.check),
                                          color: Colors.black,
                                          iconSize: 20,
                                          onPressed: () => _approveRequest(r),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.close),
                                          color: Colors.black,
                                          iconSize: 20,
                                          onPressed: () =>
                                              _rejectRequest(id, status),
                                        ),
                                      ],
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline),
                                        color: Colors.black,
                                        iconSize: 20,
                                        onPressed: () => _deleteRequest(id),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
