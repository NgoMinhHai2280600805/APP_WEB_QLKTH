import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/current_user.dart';
import '../../../core/services/product_service.dart';

class TaoYeuCauNhapKhoScreen extends StatefulWidget {
  const TaoYeuCauNhapKhoScreen({super.key});

  @override
  State<TaoYeuCauNhapKhoScreen> createState() => _TaoYeuCauNhapKhoScreenState();
}

class _TaoYeuCauNhapKhoScreenState extends State<TaoYeuCauNhapKhoScreen> {
  final _service = ProductService();
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _products = [];
  String? _selectedCategoryId;
  final Set<String> _selectedProducts = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final cats = await _service.getCategories();
    final prods = await _service.getProducts();
    setState(() {
      _categories = cats;
      _products = prods;
    });
  }

  List<Map<String, dynamic>> get _filteredProducts {
    if (_selectedCategoryId == null || _selectedCategoryId == 'all') {
      return _products;
    }
    return _products
        .where((p) => p['category_id']?.toString() == _selectedCategoryId)
        .toList();
  }

  Future<void> _confirmAndSend() async {
    if (_selectedProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Vui lòng chọn ít nhất một sản phẩm.")),
      );
      return;
    }

    final grouped = <String, List<String>>{};
    for (var p in _products) {
      if (_selectedProducts.contains(p['id'])) {
        final cat = _categories
            .firstWhere(
              (c) => c['id'].toString() == p['category_id'].toString(),
              orElse: () => {'name': 'Không xác định'},
            )['name']
            .toString();
        grouped.putIfAbsent(cat, () => []);
        grouped[cat]!.add(p['name'] ?? '');
      }
    }

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Xác nhận yêu cầu nhập kho"),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: grouped.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Tên danh mục: ${entry.key}",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      const Text("Sản phẩm:"),
                      ...entry.value.map((name) => Text("• $name")),
                      const Divider(),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Hủy"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(context);
              await _sendRequest(grouped);
            },
            child: const Text("Xác nhận"),
          ),
        ],
      ),
    );
  }

  Future<void> _sendRequest(Map<String, List<String>> grouped) async {
    setState(() => _saving = true);

    for (var entry in grouped.entries) {
      await FirebaseFirestore.instance.collection('import_requests').add({
        'category_name': entry.key,
        'product_names': entry.value,
        'status': 'Đang chờ duyệt',
        'staff_name': CurrentUser.fullname ?? '',
        'staff_email': CurrentUser.email ?? CurrentUser.username ?? '',
        'created_at': FieldValue.serverTimestamp(),
      });
    }

    setState(() => _saving = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("  Đã tạo yêu cầu nhập kho")),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredProducts;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Tạo yêu cầu nhập kho"),
        backgroundColor: Colors.green,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saving ? null : _confirmAndSend,
        label: _saving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text("Tạo yêu cầu"),
        backgroundColor: Colors.green,
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: _selectedCategoryId ?? 'all',
              decoration: InputDecoration(
                labelText: "Chọn danh mục",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: [
                const DropdownMenuItem(value: 'all', child: Text("Tất cả")),
                ..._categories.map(
                  (c) => DropdownMenuItem(
                    value: c['id'].toString(),
                    child: Text(c['name'] ?? ''),
                  ),
                ),
              ],
              onChanged: (val) => setState(() => _selectedCategoryId = val),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.separated(
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const Divider(
                  color: Colors.grey,
                  indent: 16,
                  endIndent: 16,
                ),
                itemBuilder: (_, i) {
                  final p = filtered[i];
                  final isSelected = _selectedProducts.contains(p['id']);
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child:
                          (p['image'] != null &&
                              p['image'].toString().isNotEmpty)
                          ? (p['image'].toString().startsWith('http')
                                ? Image.network(
                                    p['image'],
                                    width: 60,
                                    height: 60,
                                    fit: BoxFit.cover,
                                  )
                                : (File(p['image']).existsSync()
                                      ? Image.file(
                                          File(p['image']),
                                          width: 60,
                                          height: 60,
                                          fit: BoxFit.cover,
                                        )
                                      : _placeholder()))
                          : _placeholder(),
                    ),
                    title: Text(
                      p['name'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      "Tồn kho: ${p['quantity']}",
                      style: const TextStyle(color: Colors.black54),
                    ),
                    trailing: Checkbox(
                      value: isSelected,
                      onChanged: (val) {
                        setState(() {
                          val == true
                              ? _selectedProducts.add(p['id'])
                              : _selectedProducts.remove(p['id']);
                        });
                      },
                      activeColor: Colors.green,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
    width: 60,
    height: 60,
    color: Colors.grey.shade300,
    child: const Icon(Icons.image),
  );
}
