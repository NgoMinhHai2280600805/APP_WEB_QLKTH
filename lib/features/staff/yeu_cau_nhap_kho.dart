import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/product_service.dart';
import 'tao_yeu_cau_nhap_kho.dart';

class YeuCauNhapKhoScreen extends StatefulWidget {
  const YeuCauNhapKhoScreen({super.key});

  @override
  State<YeuCauNhapKhoScreen> createState() => _YeuCauNhapKhoScreenState();
}

class _YeuCauNhapKhoScreenState extends State<YeuCauNhapKhoScreen> {
  final _service = ProductService();
  List<Map<String, dynamic>> _requests = [];
  bool _loading = true;

  int _itemsPerPage = 15; // Số lượng hiển thị mặc định

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    final reqs = await _service.getImportRequests();
    reqs.sort((a, b) {
      final at = a['created_at'];
      final bt = b['created_at'];
      if (at == null || bt == null) return 0;
      return bt.compareTo(at);
    });

    setState(() {
      _requests = reqs;
      _loading = false;
    });
  }

  Color _getStatusColor(String status) {
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

  Future<void> _cancelRequest(String requestId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Xác nhận hủy yêu cầu"),
        content: const Text("Bạn có chắc muốn hủy yêu cầu này không?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Không"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text("Hủy yêu cầu"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('import_requests')
          .doc(requestId)
          .update({'status': 'Đã hủy'});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(" Đã hủy yêu cầu nhập kho")),
        );
      }

      _loadRequests();
    }
  }

  Future<void> _openCreate() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TaoYeuCauNhapKhoScreen()),
    );
    _loadRequests();
  }

  @override
  Widget build(BuildContext context) {
    // Giới hạn hiển thị theo số lượng được chọn
    final displayedRequests = (_itemsPerPage == 0)
        ? _requests
        : _requests.take(_itemsPerPage).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Yêu cầu nhập kho"),
        backgroundColor: Colors.green,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: "Tạo yêu cầu mới",
            onPressed: _openCreate,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _requests.isEmpty
          ? const Center(child: Text("Chưa có yêu cầu nhập kho nào"))
          : Column(
              children: [
                // Bộ chọn số lượng hiển thị
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Hiển thị:",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      DropdownButton<int>(
                        value: _itemsPerPage,
                        items: const [
                          DropdownMenuItem(value: 15, child: Text("15")),
                          DropdownMenuItem(value: 30, child: Text("30")),
                          DropdownMenuItem(value: 50, child: Text("50")),
                          DropdownMenuItem(value: 0, child: Text("Tất cả")),
                        ],
                        onChanged: (val) {
                          setState(() {
                            _itemsPerPage = val!;
                          });
                        },
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadRequests,
                    child: ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: displayedRequests.length,
                      separatorBuilder: (_, __) => const Divider(
                        color: Colors.grey,
                        thickness: 0.5,
                        indent: 16,
                        endIndent: 16,
                      ),
                      itemBuilder: (_, i) {
                        final r = displayedRequests[i];
                        final id = r['id'];
                        final status = (r['status'] ?? 'Đang chờ duyệt')
                            .toString();
                        final time = (r['created_at'] != null)
                            ? DateFormat(
                                'dd/MM/yyyy HH:mm',
                              ).format(r['created_at'].toDate())
                            : 'N/A';

                        final productNames = (r['product_names'] is List)
                            ? (r['product_names'] as List)
                                  .map((e) => e.toString())
                                  .join(', ')
                            : '';

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 12,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 55,
                                  height: 55,
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade100,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(
                                    Icons.inventory_2,
                                    color: Colors.green,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        r['category_name'] ?? 'Không xác định',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        "Sản phẩm: $productNames",
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                      const SizedBox(height: 2),
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
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      status,
                                      style: TextStyle(
                                        color: _getStatusColor(status),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (status.toLowerCase() ==
                                        'đang chờ duyệt')
                                      TextButton(
                                        onPressed: () => _cancelRequest(id),
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.red,
                                          padding: EdgeInsets.zero,
                                          minimumSize: const Size(0, 30),
                                        ),
                                        child: const Text(
                                          "Hủy",
                                          style: TextStyle(fontSize: 13),
                                        ),
                                      ),
                                  ],
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
