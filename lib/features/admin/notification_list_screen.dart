import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/current_user.dart';
import 'notification_detail_screen.dart';

class NotificationListScreen extends StatefulWidget {
  const NotificationListScreen({super.key});

  @override
  State<NotificationListScreen> createState() => _NotificationListScreenState();
}

class _NotificationListScreenState extends State<NotificationListScreen> {
  // Chế độ chọn nhiều
  bool _isSelectionMode = false;
  final Set<String> _selectedDocIds = <String>{};

  // Phân trang
  static const int _pageSize = 25;
  DocumentSnapshot? _lastDocument;
  bool _isLoadingMore = false;
  bool _hasMoreData = true;

  final List<QueryDocumentSnapshot> _logs = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final query = FirebaseFirestore.instance
        .collection('admin_web_logins')
        .where('adminId', isEqualTo: CurrentUser.id)
        .orderBy('timestamp', descending: true)
        .limit(_pageSize);

    final snapshot = await query.get();
    if (mounted) {
      setState(() {
        _logs.clear();
        _logs.addAll(snapshot.docs);
        _lastDocument = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
        _hasMoreData = snapshot.docs.length == _pageSize;
      });
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMoreData || _isLoadingMore || _lastDocument == null) return;

    setState(() {
      _isLoadingMore = true;
    });

    final query = FirebaseFirestore.instance
        .collection('admin_web_logins')
        .where('adminId', isEqualTo: CurrentUser.id)
        .orderBy('timestamp', descending: true)
        .startAfterDocument(_lastDocument!)
        .limit(_pageSize);

    final snapshot = await query.get();

    if (mounted) {
      setState(() {
        _logs.addAll(snapshot.docs);
        _lastDocument = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
        _hasMoreData = snapshot.docs.length == _pageSize;
        _isLoadingMore = false;
      });
    }
  }

  // Đánh dấu các mục đã chọn là đã đọc
  Future<void> _markSelectedAsRead() async {
    if (_selectedDocIds.isEmpty) return;

    final batch = FirebaseFirestore.instance.batch();

    for (final docId in _selectedDocIds) {
      final docRef = FirebaseFirestore.instance
          .collection('admin_web_logins')
          .doc(docId);
      batch.update(docRef, {'isRead': true});
    }

    await batch.commit();

    setState(() {
      _isSelectionMode = false;
      _selectedDocIds.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Trường hợp không có dữ liệu
    if (_logs.isEmpty && !_isLoadingMore) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.blue,
          title: const Text('Thông báo'),
        ),
        body: const Center(
          child: Text(
            'Không có dữ liệu',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        title: _isSelectionMode
            ? Text('${_selectedDocIds.length} đã chọn')
            : const Text('Thông báo'),
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _isSelectionMode = false;
                    _selectedDocIds.clear();
                  });
                },
              )
            : null,
        actions: _isSelectionMode
            ? [
                TextButton(
                  onPressed: () {
                    setState(() {
                      if (_selectedDocIds.length == _logs.length) {
                        _selectedDocIds.clear();
                      } else {
                        _selectedDocIds.addAll(_logs.map((doc) => doc.id));
                      }
                    });
                  },
                  child: Text(
                    _selectedDocIds.length == _logs.length
                        ? 'Bỏ chọn tất cả'
                        : 'Chọn tất cả',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ]
            : null,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount:
                  _logs.length + (_hasMoreData || _isLoadingMore ? 1 : 0),
              itemBuilder: (context, index) {
                // Nút Xem thêm hoặc loading
                if (index == _logs.length) {
                  if (_isLoadingMore) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  if (_hasMoreData) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                          ),
                          onPressed: _loadMore,
                          child: const Text(
                            'Xem thêm',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    );
                  }
                }

                final doc = _logs[index];
                final docId = doc.id;
                final data = doc.data() as Map<String, dynamic>;
                final bool isRead = data['isRead'] ?? true;

                final timestamp =
                    (data['timestamp'] as Timestamp?)
                        ?.toDate()
                        .toLocal()
                        .toString()
                        .split('.')[0] ??
                    'Không xác định';

                final bool isSelected = _selectedDocIds.contains(docId);

                return Card(
                  color: isSelected ? Colors.blue.withOpacity(0.2) : null,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: _isSelectionMode
                        ? Checkbox(
                            value: isSelected,
                            onChanged: (value) {
                              setState(() {
                                if (value == true) {
                                  _selectedDocIds.add(docId);
                                } else {
                                  _selectedDocIds.remove(docId);
                                }
                                if (_selectedDocIds.isEmpty) {
                                  _isSelectionMode = false;
                                }
                              });
                            },
                          )
                        : (isRead
                              ? null
                              : const Icon(
                                  Icons.circle,
                                  color: Colors.red,
                                  size: 12,
                                )),
                    title: Text(
                      'Đăng nhập từ ${data['deviceName'] ?? 'Thiết bị không xác định'}',
                      style: TextStyle(
                        fontWeight: isRead
                            ? FontWeight.normal
                            : FontWeight.bold,
                      ),
                    ),
                    subtitle: Text('Thời gian: $timestamp'),
                    trailing: _isSelectionMode
                        ? null
                        : (isRead
                              ? null
                              : Container(
                                  width: 10,
                                  height: 10,
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                )),
                    onLongPress: () {
                      if (!_isSelectionMode) {
                        setState(() {
                          _isSelectionMode = true;
                          _selectedDocIds.add(docId);
                        });
                      }
                    },
                    onTap: () {
                      if (_isSelectionMode) {
                        setState(() {
                          if (isSelected) {
                            _selectedDocIds.remove(docId);
                          } else {
                            _selectedDocIds.add(docId);
                          }
                          if (_selectedDocIds.isEmpty) {
                            _isSelectionMode = false;
                          }
                        });
                      } else {
                        if (!isRead) {
                          doc.reference.update({'isRead': true});
                        }
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                NotificationDetailScreen(logData: data),
                          ),
                        );
                      }
                    },
                  ),
                );
              },
            ),
          ),

          // Chỉ hiển thị nút đánh dấu khi đang ở chế độ chọn nhiều
          if (_isSelectionMode)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.grey[100],
              child: ElevatedButton.icon(
                icon: const Icon(Icons.done_all),
                label: Text(
                  _selectedDocIds.length == _logs.length
                      ? 'Đánh dấu tất cả đã đọc'
                      : 'Đánh dấu ${_selectedDocIds.length} mục đã đọc',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                onPressed: _selectedDocIds.isEmpty ? null : _markSelectedAsRead,
              ),
            ),
        ],
      ),
    );
  }
}
