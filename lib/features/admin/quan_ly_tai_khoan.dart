import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/services/user_service.dart';

class QuanLyTaiKhoanScreen extends StatefulWidget {
  const QuanLyTaiKhoanScreen({super.key});

  @override
  State<QuanLyTaiKhoanScreen> createState() => _QuanLyTaiKhoanScreenState();
}

class _QuanLyTaiKhoanScreenState extends State<QuanLyTaiKhoanScreen> {
  final UserService _userService = UserService();
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = false;
  bool _allowRegister = false;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);

    try {
      final data = await _userService.getAllUsers();
      // chỉ lấy staff, bỏ qua admin
      _users = data.where((u) => (u['role'] ?? '') == 'staff').toList();

      // đọc cài đặt cho phép đăng ký (từ Firestore collection settings)
      final settingDoc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('app')
          .get();
      _allowRegister = settingDoc.data()?['allow_register'] ?? false;
    } catch (e) {
      debugPrint('❌ Lỗi load users: $e');
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _deleteUser(String id) async {
    try {
      await _userService.deleteUser(id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Đã xóa tài khoản.')));
        _loadUsers();
      }
    } catch (e) {
      debugPrint('❌ Lỗi xóa user: $e');
    }
  }

  Future<void> _lockUser(String id, bool locked) async {
    try {
      await _userService.lockUser(id, locked);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              locked ? 'Đã khóa tài khoản.' : 'Đã mở khóa tài khoản.',
            ),
          ),
        );
        _loadUsers();
      }
    } catch (e) {
      debugPrint('❌ Lỗi khóa user: $e');
    }
  }

  Future<void> _toggleAllowRegister(bool value) async {
    setState(() => _allowRegister = value);
    await FirebaseFirestore.instance.collection('settings').doc('app').set({
      'allow_register': value,
    }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý tài khoản'),
        actions: [
          Row(
            children: [
              const Text("Cho phép đăng ký"),
              Switch(
                value: _allowRegister,
                onChanged: (v) => _toggleAllowRegister(v),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadUsers,
              child: _users.isEmpty
                  ? const Center(child: Text('Không có tài khoản nào.'))
                  : ListView.builder(
                      itemCount: _users.length,
                      itemBuilder: (context, index) {
                        final user = _users[index];
                        final isLocked = user['is_locked'] ?? false;

                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          child: ListTile(
                            title: Text(
                              user['username'] ?? 'Không rõ',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(user['email'] ?? ''),
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'delete') {
                                  _confirmDelete(user['id']);
                                } else if (value == 'lock') {
                                  _lockUser(user['id'], !isLocked);
                                }
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'lock',
                                  child: Text(
                                    isLocked
                                        ? '🔓 Mở khóa'
                                        : '🔒 Khóa tài khoản',
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Text('🗑️ Xóa tài khoản'),
                                ),
                              ],
                            ),
                            leading: CircleAvatar(
                              backgroundColor: isLocked
                                  ? Colors.red[300]
                                  : Colors.green[400],
                              child: Icon(
                                isLocked ? Icons.lock : Icons.person,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }

  void _confirmDelete(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: const Text('Bạn có chắc muốn xóa tài khoản này không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteUser(id);
            },
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
