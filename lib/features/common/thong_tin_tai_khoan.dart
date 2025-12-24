import 'dart:io';
import 'package:flutter/material.dart';
import '../../widgets/drawer.dart';
import '../../../core/current_user.dart';

class ThongTinTaiKhoanScreen extends StatefulWidget {
  const ThongTinTaiKhoanScreen({super.key});

  @override
  State<ThongTinTaiKhoanScreen> createState() => _ThongTinTaiKhoanScreenState();
}

class _ThongTinTaiKhoanScreenState extends State<ThongTinTaiKhoanScreen> {
  String? avatar;
  String? username;
  String? email;
  String? role;
  int? id;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  void _loadUserInfo() {
    setState(() {
      avatar = CurrentUser.avatar;
      username = CurrentUser.username;
      email = CurrentUser.email;
      role = CurrentUser.role;
      //id = CurrentUser.id;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Drawer vẫn giữ nguyên — vẫn có thể vuốt từ trái ra
      drawer: const CustomDrawer(),
      appBar: AppBar(
        title: const Text("Thông tin tài khoản"),
        backgroundColor: Colors.blue,
        //   Thay nút 3 gạch bằng nút mũi tên quay lại
        automaticallyImplyLeading: false, // tắt nút mặc định (menu)
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundImage:
                      (avatar != null && File(avatar!).existsSync())
                      ? FileImage(File(avatar!))
                      : const AssetImage('assets/default_anh.png')
                            as ImageProvider,
                  backgroundColor: Colors.grey[200],
                ),
                const SizedBox(height: 16),
                Text(
                  username ?? "Người dùng",
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  email ?? "Chưa có email",
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    role == "admin" ? "Quản trị viên" : "Nhân viên",
                    style: const TextStyle(color: Colors.blue),
                  ),
                ),
                const Divider(height: 30),
                _buildInfoRow(
                  Icons.badge,
                  "ID người dùng",
                  id?.toString() ?? "Không có",
                ),
                _buildInfoRow(
                  Icons.person_outline,
                  "Tên đăng nhập",
                  username ?? "Không có",
                ),
                _buildInfoRow(Icons.email, "Email", email ?? "Không có"),
                _buildInfoRow(
                  Icons.work_outline,
                  "Chức vụ",
                  role ?? "Không có",
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text("Quay lại"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Text(value, style: const TextStyle(color: Colors.black87)),
        ],
      ),
    );
  }
}
