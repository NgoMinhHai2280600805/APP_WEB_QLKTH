import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';

class DeletedProductsScreen extends StatefulWidget {
  final VoidCallback? onRestore;
  const DeletedProductsScreen({super.key, this.onRestore});

  @override
  State<DeletedProductsScreen> createState() => _DeletedProductsScreenState();
}

class _DeletedProductsScreenState extends State<DeletedProductsScreen> {
  final _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _deletedProducts = [];
  List<Map<String, dynamic>> _deletedCategories = [];
  List<Map<String, dynamic>> _deletedBatches = [];

  @override
  void initState() {
    super.initState();
    _loadDeletedData();
  }

  Future<void> _loadDeletedData() async {
    final prodSnap = await _firestore
        .collection('products')
        .where('is_deleted', isEqualTo: true)
        .get();

    final catSnap = await _firestore
        .collection('categories')
        .where('is_deleted', isEqualTo: true)
        .get();

    final batchSnap = await _firestore
        .collection('product_batches')
        .where('is_deleted', isEqualTo: true)
        .get();

    setState(() {
      _deletedProducts = prodSnap.docs
          .map((d) => {'id': d.id, ...d.data()})
          .toList();
      _deletedCategories = catSnap.docs
          .map((d) => {'id': d.id, ...d.data()})
          .toList();
      _deletedBatches = batchSnap.docs
          .map((d) => {'id': d.id, ...d.data()})
          .toList();
    });
  }

  Future<void> _restoreProduct(Map<String, dynamic> p) async {
    if (p['category_id'] != null) {
      final catDoc = await _firestore
          .collection('categories')
          .doc(p['category_id'].toString())
          .get();
      if (catDoc.exists && catDoc.data()?['is_deleted'] == true) {
        await _firestore
            .collection('categories')
            .doc(p['category_id'].toString())
            .update({'is_deleted': false});
      }
    }

    await _firestore.collection('products').doc(p['id'].toString()).update({
      'is_deleted': false,
    });

    // 🔹 Cập nhật tổng số lượng từ batch còn hiển thị
    final batchSnap = await _firestore
        .collection('product_batches')
        .where('product_id', isEqualTo: p['id'])
        .where('is_deleted', isEqualTo: false)
        .get();

    int totalQty = batchSnap.docs.fold(0, (sum, b) {
      final qty = b['quantity'] ?? 0;
      return sum + (qty is int ? qty : (qty as num).toInt());
    });

    await _firestore.collection('products').doc(p['id']).update({
      'quantity': totalQty,
    });

    if (widget.onRestore != null) widget.onRestore!();
    _loadDeletedData();
  }

  Future<void> _restoreCategory(String id) async {
    await _firestore.collection('categories').doc(id).update({
      'is_deleted': false,
    });

    if (widget.onRestore != null) {
      widget.onRestore!();
    }

    _loadDeletedData();
  }

  Future<void> _restoreBatch(Map<String, dynamic> batch) async {
    if (batch['product_id'] != null) {
      final batchRef = _firestore
          .collection('product_batches')
          .doc(batch['id']);
      await batchRef.update({'is_deleted': false});

      // 🔹 Lấy tất cả batch còn hiển thị của product để tính tổng
      final batchSnap = await _firestore
          .collection('product_batches')
          .where('product_id', isEqualTo: batch['product_id'])
          .where('is_deleted', isEqualTo: false)
          .get();

      int totalQty = batchSnap.docs.fold(0, (sum, b) {
        final qty = b['quantity'] ?? 0;
        return sum + (qty is int ? qty : (qty as num).toInt());
      });

      // 🔹 Cập nhật tổng số lượng product
      await _firestore.collection('products').doc(batch['product_id']).update({
        'quantity': totalQty,
      });
    }

    if (widget.onRestore != null) {
      widget.onRestore!(); // reload KhoHangScreen
    }
    _loadDeletedData(); // reload danh sách DeletedProductsScreen
  }

  Future<void> _restoreAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Khôi phục tất cả"),
        content: const Text(
          "Một số sản phẩm khi khôi phục sẽ khôi phục cả danh mục. Bạn có muốn tiếp tục?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Hủy"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Đồng ý"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final prodSnap = await _firestore.collection('products').get();
      for (var d in prodSnap.docs) {
        if (d['is_deleted'] == true) {
          await d.reference.update({'is_deleted': false});
        }
      }

      final catSnap = await _firestore.collection('categories').get();
      for (var d in catSnap.docs) {
        if (d['is_deleted'] == true) {
          await d.reference.update({'is_deleted': false});
        }
      }

      final batchSnap = await _firestore.collection('product_batches').get();
      for (var d in batchSnap.docs) {
        if (d['is_deleted'] == true) {
          await d.reference.update({'is_deleted': false});
        }
      }

      _loadDeletedData();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Đã khôi phục toàn bộ sản phẩm, danh mục và lô hàng"),
        ),
      );
    }
  }

  Future<void> _emptyTrash() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Dọn sạch thùng rác"),
        content: const Text(
          "Toàn bộ sản phẩm, danh mục và lô hàng đã xóa sẽ bị xóa vĩnh viễn. Tiếp tục?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Hủy"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Dọn sạch"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      for (var p in _deletedProducts) {
        await _firestore
            .collection('products')
            .doc(p['id'].toString())
            .delete();
      }
      for (var c in _deletedCategories) {
        await _firestore
            .collection('categories')
            .doc(c['id'].toString())
            .delete();
      }
      for (var b in _deletedBatches) {
        await _firestore
            .collection('product_batches')
            .doc(b['id'].toString())
            .delete();
      }

      _loadDeletedData();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Đã dọn sạch thùng rác")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3, // 3 tab
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Lịch sử xóa"),
          backgroundColor: const Color.fromARGB(255, 243, 19, 191),
          actions: [
            PopupMenuButton<String>(
              onSelected: (val) {
                if (val == 'restoreAll') _restoreAll();
                if (val == 'clearAll') _emptyTrash();
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'restoreAll',
                  child: Row(
                    children: [
                      Icon(Icons.restore_page, color: Colors.green),
                      SizedBox(width: 8),
                      Text("Khôi phục tất cả"),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'clearAll',
                  child: Row(
                    children: [
                      Icon(Icons.delete_forever, color: Colors.red),
                      SizedBox(width: 8),
                      Text("Dọn sạch thùng rác"),
                    ],
                  ),
                ),
              ],
            ),
          ],
          bottom: const TabBar(
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: "Sản phẩm"),
              Tab(text: "Danh mục"),
              Tab(text: "Lô hàng"), // tab mới
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildList(_deletedProducts, true),
            _buildList(_deletedCategories, false),
            _buildBatchList(_deletedBatches), // tab lô hàng
          ],
        ),
      ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> items, bool isProduct) {
    if (items.isEmpty) {
      return const Center(
        child: Text("Không có dữ liệu", style: TextStyle(color: Colors.grey)),
      );
    }

    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (_, i) {
        final item = items[i];
        return Column(
          children: [
            isProduct
                ? ListTile(
                    leading:
                        (item['image'] != null &&
                            File(item['image']).existsSync())
                        ? Image.file(
                            File(item['image']),
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                          )
                        : const Icon(
                            Icons.image_not_supported,
                            size: 40,
                            color: Colors.grey,
                          ),
                    title: Text(
                      item['name'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text("SL: ${item['quantity'] ?? 0}"),
                    trailing: PopupMenuButton<String>(
                      onSelected: (val) {
                        if (val == 'restore') _restoreProduct(item);
                        if (val == 'delete')
                          _firestore
                              .collection('products')
                              .doc(item['id'].toString())
                              .delete()
                              .then((_) => _loadDeletedData());
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'restore',
                          child: Row(
                            children: [
                              Icon(Icons.restore, color: Colors.green),
                              SizedBox(width: 8),
                              Text("Khôi phục"),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_forever, color: Colors.red),
                              SizedBox(width: 8),
                              Text("Xóa vĩnh viễn"),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListTile(
                    leading: const Icon(
                      Icons.category,
                      size: 40,
                      color: Colors.grey,
                    ),
                    title: Text(
                      item['name'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(item['description'] ?? ''),
                    trailing: PopupMenuButton<String>(
                      onSelected: (val) {
                        if (val == 'restore') _restoreCategory(item['id']);
                        if (val == 'delete')
                          _firestore
                              .collection('categories')
                              .doc(item['id'].toString())
                              .delete()
                              .then((_) => _loadDeletedData());
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'restore',
                          child: Row(
                            children: [
                              Icon(Icons.restore, color: Colors.green),
                              SizedBox(width: 8),
                              Text("Khôi phục"),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_forever, color: Colors.red),
                              SizedBox(width: 8),
                              Text("Xóa vĩnh viễn"),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
            const Divider(height: 1, color: Colors.black26),
          ],
        );
      },
    );
  }

  Widget _buildBatchList(List<Map<String, dynamic>> batches) {
    if (batches.isEmpty) {
      return const Center(
        child: Text("Không có dữ liệu", style: TextStyle(color: Colors.grey)),
      );
    }

    return ListView.builder(
      itemCount: batches.length,
      itemBuilder: (_, i) {
        final batch = batches[i];
        final batchNo = batch['batch_number'] ?? '-';
        final qty = batch['quantity']?.toString() ?? '-';
        final mfg = batch['mfg_date']?.toString() ?? '-';
        final exp = batch['expiry_date']?.toString() ?? '-';
        return Column(
          children: [
            ListTile(
              title: Text("Lô: $batchNo"),
              subtitle: Text("SL: $qty\nNgày SX: $mfg | HSD: $exp"),
              trailing: PopupMenuButton<String>(
                onSelected: (val) async {
                  if (val == 'restore') {
                    await _restoreBatch(batch);
                  } else if (val == 'delete') {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text("Xóa vĩnh viễn"),
                        content: Text(
                          "Bạn có chắc chắn muốn xóa lô $batchNo vĩnh viễn?",
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text("Hủy"),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                            child: const Text("Xóa"),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await _firestore
                          .collection('product_batches')
                          .doc(batch['id'])
                          .delete();
                      _loadDeletedData();
                    }
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'restore', child: Text("Khôi phục")),
                  PopupMenuItem(value: 'delete', child: Text("Xóa vĩnh viễn")),
                ],
              ),
            ),
            const Divider(),
          ],
        );
      },
    );
  }
}
