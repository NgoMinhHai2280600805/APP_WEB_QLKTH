import 'package:flutter/material.dart';
import '../../widgets/drawer.dart';
import '../auth/login.dart';
import '../../../core/current_user.dart';
import '../../../core/services/user_service.dart';
import '../../../main.dart';

// 🔹 Admin screens
import '../admin/duyet_yeu_cau_nhap.dart';
import '../admin/quan_ly_tai_khoan.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  String? avatarUrl;
  String? fullname;
  String? email;
  String role = 'staff';
  bool _isRefreshing = false;
  final _userService = UserService();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() {
      avatarUrl = CurrentUser.avatar;
      fullname = CurrentUser.fullname;
      email = CurrentUser.email;
      role = CurrentUser.role;
    });

    final currentEmail = CurrentUser.email;
    if (currentEmail == null || currentEmail.isEmpty) return;

    try {
      final snapshot = await _userService.getUserByEmail(currentEmail);
      if (snapshot == null) return;

      setState(() {
        avatarUrl = (snapshot['avatar'] ?? '').toString();
        fullname = (snapshot['fullname'] ?? '').toString();
        email = (snapshot['email'] ?? '').toString();
        role = (snapshot['role'] ?? 'staff').toString();
      });

      CurrentUser.avatar = avatarUrl ?? '';
      CurrentUser.fullname = fullname ?? '';
      CurrentUser.email = email ?? '';
      CurrentUser.role = role;
      await CurrentUser.saveToPrefs();
    } catch (e) {
      debugPrint("Lỗi khi tải thông tin người dùng: $e");
    }
  }

  Future<void> _onRefresh() async {
    setState(() => _isRefreshing = true);
    await _loadUserData();
    setState(() => _isRefreshing = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Đã làm mới thông tin người dùng")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    //   Danh sách menu cơ bản
    final List<Map<String, dynamic>> menuItems = [
      {
        'icon': Icons.person,
        'label': 'Tài khoản',
        'color': Colors.blue,
        'onTap': () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Tính năng đang phát triển...")),
          );
        },
      },
      if (role != 'admin')
        {
          'icon': Icons.lock,
          'label': 'Đổi mật khẩu',
          'color': Colors.orangeAccent,
          'onTap': () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Tính năng đang phát triển...")),
            );
          },
        },
      {
        'icon': Icons.help_outline,
        'label': 'Hướng dẫn',
        'color': Colors.green,
        'onTap': () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Tính năng đang phát triển...")),
          );
        },
      },
      if (role == 'admin') ...[
        {
          'icon': Icons.approval,
          'label': 'Duyệt yêu cầu nhập',
          'color': Colors.teal,
          'onTap': () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DuyetYeuCauNhapScreen()),
            );
          },
        },
        {
          'icon': Icons.admin_panel_settings,
          'label': 'Quản lý tài khoản',
          'color': Colors.deepPurple,
          'onTap': () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const QuanLyTaiKhoanScreen()),
            );
          },
        },
      ],
      {
        'icon': Icons.logout,
        'label': 'Đăng xuất',
        'color': Colors.redAccent,
        'onTap': () async {
          await CurrentUser.clearPrefs();
          if (context.mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
            );
          }
        },
      },
    ];

    return Scaffold(
      drawer: const CustomDrawer(),
      appBar: AppBar(
        title: const Text("Menu"),
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
      ),

      //   Cho phép kéo làm mới
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        color: Colors.blueAccent,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),

          children: [
            // 🧑 Thông tin người dùng
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 45,
                    backgroundImage:
                        (avatarUrl != null && avatarUrl!.isNotEmpty)
                        ? NetworkImage(avatarUrl!)
                        : const AssetImage('assets/defautl_anh.png')
                              as ImageProvider,
                    backgroundColor: Colors.grey[200],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    fullname?.isNotEmpty == true ? fullname! : "Người dùng",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (email != null && email!.isNotEmpty)
                    Text(
                      email!,
                      style: const TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    role == "admin" ? "Quản trị viên" : "Nhân viên",
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  if (_isRefreshing)
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 25),

            // 🔹 Lưới menu 3 cột
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: menuItems.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1,
              ),
              itemBuilder: (context, index) {
                final item = menuItems[index];
                return _buildMenuItem(
                  icon: item['icon'],
                  label: item['label'],
                  color: item['color'],
                  onTap: item['onTap'],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        //hàm chặn co giãn nd
        child: ScrollConfiguration(
          behavior: const ScrollBehavior().copyWith(
            overscroll: false, // tắt hiệu ứng co giãn
            physics: const ClampingScrollPhysics(), // khóa cứng scroll
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 36),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
