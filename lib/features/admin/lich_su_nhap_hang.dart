import 'package:flutter/material.dart';
import '../../core/services/product_service.dart';
import 'chi_tiet_nhap_hang.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class LichSuNhapHang extends StatefulWidget {
  const LichSuNhapHang({super.key});

  @override
  State<LichSuNhapHang> createState() => _LichSuNhapHangState();
}

class _LichSuNhapHangState extends State<LichSuNhapHang> {
  final _service = ProductService();
  List<dynamic> logs = [];
  int visibleCount = 10; // Số dòng hiển thị lần đầu
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    final data = await _service.getImportLogs();
    setState(() {
      logs = data;
      loading = false;
    });
  }

  String _fmtDate(dynamic ts) {
    if (ts == null) return "Không rõ";
    if (ts is Timestamp)
      return DateFormat('yyyy-MM-dd HH:mm').format(ts.toDate());
    if (ts is DateTime) return DateFormat('yyyy-MM-dd HH:mm').format(ts);
    return ts.toString();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        appBar: AppBar(title: const Text("Lịch sử nhập hàng")),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (logs.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text("Lịch sử nhập hàng")),
        body: const Center(child: Text("Chưa có lịch sử nhập hàng")),
      );
    }

    final displayLogs = logs.take(visibleCount).toList();

    return Scaffold(
      appBar: AppBar(title: const Text("Lịch sử nhập hàng")),
      body: Column(
        children: [
          Expanded(
            child: ScrollConfiguration(
              behavior: const ScrollBehavior().copyWith(
                overscroll: false, // tắt hiệu ứng co giãn
                physics: const ClampingScrollPhysics(), // khóa cứng scroll
              ),
              child: ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount:
                    displayLogs.length + 1, // +1 cho nút xem thêm / thông báo
                separatorBuilder: (_, __) =>
                    Divider(color: Colors.grey.shade300, height: 1),
                itemBuilder: (context, index) {
                  if (index < displayLogs.length) {
                    final log = displayLogs[index];
                    final createdTime = log['created_at'];
                    final batchCount = (log['batches'] as List).length;

                    return ListTile(
                      title: Text(
                        "Nhập ngày: ${_fmtDate(createdTime)}",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        "Người nhập: ${log['admin_name']}\n"
                        "Số lô hàng: $batchCount",
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChiTietNhapHang(data: log),
                          ),
                        );
                      },
                    );
                  } else {
                    // Item cuối cùng: nút xem thêm hoặc thông báo không còn dữ liệu
                    if (logs.length > visibleCount) {
                      return TextButton.icon(
                        onPressed: () {
                          setState(() {
                            visibleCount += 15;
                            if (visibleCount > logs.length)
                              visibleCount = logs.length;
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

            // Nút xem thêm hoặc thông báo không có lịch sử
          ),
        ],
      ),
    );
  }
}
