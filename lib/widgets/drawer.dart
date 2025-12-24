import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../features/auth/login.dart';
import '../features/admin/quan_ly_tai_khoan.dart';
import '../features/admin/duyet_yeu_cau_nhap.dart';
import '../features/chat/chat_screen.dart';
import '../features/chat/chat_list.dart';
import '../core/current_user.dart';
import '../core/services/user_service.dart';
import '../main.dart';
import 'image_review_screen.dart';

class CustomDrawer extends StatefulWidget {
  final VoidCallback? onRefresh;

  const CustomDrawer({super.key, this.onRefresh});

  @override
  State<CustomDrawer> createState() => _CustomDrawerState();
}

class _CustomDrawerState extends State<CustomDrawer> {
  String? _avatarUrl;
  String? _fullname;
  String? _email;
  String? _role;

  final ImagePicker _picker = ImagePicker();
  final _userService = UserService();

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    _avatarUrl = CurrentUser.avatar;
    _fullname = CurrentUser.fullname;
    _email = CurrentUser.email;
    _role = CurrentUser.role;
    setState(() {});
  }

  /// Upload ảnh lên Google Drive và cập nhật Firestore
  Future<void> _updateAvatar(String localPath) async {
    try {
      final imageFile = File(localPath);
      if (!imageFile.existsSync()) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Không tìm thấy ảnh!")));
        return;
      }

      // 🔹 Upload lên Google Drive
      final link = await _userService.uploadAvatarToDrive(imageFile);

      if (link != null && link.isNotEmpty) {
        final uid = CurrentUser.id?.toString() ?? '';
        if (uid.isNotEmpty) {
          await _userService.updateAvatarLink(uid, link);
          CurrentUser.avatar = link;
          await CurrentUser.saveToPrefs();
        }

        setState(() => _avatarUrl = link);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Ảnh đại diện đã được cập nhật")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Lỗi khi upload ảnh đại diện")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Lỗi cập nhật ảnh: $e")));
    }
  }

  /// Chọn / xem / xóa ảnh đại diện
  Future<void> _showAvatarOptions() async {
    final hasAvatar = _avatarUrl != null && _avatarUrl!.isNotEmpty;

    final options = <String>[
      "Chụp ảnh mới",
      "Chọn ảnh từ thư viện",
      if (hasAvatar) "Xem ảnh đại diện",
      if (hasAvatar) "Xóa ảnh đại diện",
    ];

    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: options
              .map(
                (e) => ListTile(
                  leading: Icon(
                    e == "Chụp ảnh mới"
                        ? Icons.camera_alt
                        : e == "Chọn ảnh từ thư viện"
                        ? Icons.photo
                        : e == "Xem ảnh đại diện"
                        ? Icons.visibility
                        : Icons.delete,
                  ),
                  title: Text(e),
                  onTap: () => Navigator.pop(context, e),
                ),
              )
              .toList(),
        ),
      ),
    );

    if (selected == null) return;

    switch (selected) {
      case "Chụp ảnh mới":
        final picked = await _picker.pickImage(source: ImageSource.camera);
        if (picked != null) {
          final reviewedPath = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ImageReviewScreen(imagePath: picked.path),
            ),
          );
          if (reviewedPath != null && reviewedPath is String) {
            await _updateAvatar(reviewedPath);
          }
        }
        break;

      case "Chọn ảnh từ thư viện":
        final picked = await _picker.pickImage(source: ImageSource.gallery);
        if (picked != null) {
          final reviewedPath = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ImageReviewScreen(imagePath: picked.path),
            ),
          );
          if (reviewedPath != null && reviewedPath is String) {
            await _updateAvatar(reviewedPath);
          }
        }
        break;

      case "Xem ảnh đại diện":
        if (_avatarUrl != null && _avatarUrl!.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => Scaffold(
                appBar: AppBar(title: const Text("Ảnh đại diện")),
                body: Center(child: Image.network(_avatarUrl!)),
              ),
            ),
          );
        }
        break;

      case "Xóa ảnh đại diện":
        final uid = CurrentUser.id?.toString() ?? '';
        if (uid.isNotEmpty) {
          await _userService.updateAvatarLink(uid, "");
          CurrentUser.avatar = "";
          await CurrentUser.saveToPrefs();
        }
        setState(() => _avatarUrl = null);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Ảnh đại diện đã được xóa")),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DrawerTheme(
      data: const DrawerThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
      child: Drawer(
        elevation: 16,
        backgroundColor: Colors.white,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: Colors.blue,
              padding: const EdgeInsets.only(top: 60, bottom: 20),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _showAvatarOptions,
                    child: CircleAvatar(
                      radius: 45,
                      backgroundColor: Colors.white,
                      backgroundImage:
                          (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                          ? NetworkImage(_avatarUrl!) as ImageProvider
                          : null,
                      child: (_avatarUrl == null || _avatarUrl!.isEmpty)
                          ? const Icon(
                              Icons.camera_alt,
                              size: 40,
                              color: Colors.grey,
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // ten
                  Text(
                    _fullname?.isNotEmpty == true ? _fullname! : "Người dùng",
                    style: const TextStyle(
                      fontSize: 20,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _email!,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  //mail
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    //vt
                    child: Text(
                      _role == "admin" ? "Quản trị viên" : "Nhân viên",
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  ListTile(
                    leading: const Icon(Icons.home),
                    title: const Text("Trang chủ"),
                    onTap: () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const HomePage(initialIndex: 0),
                        ),
                        (route) => false,
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.refresh),
                    title: const Text("Làm mới"),
                    onTap: () {
                      Navigator.pop(context);
                      widget.onRefresh?.call();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.chat_bubble_outline),
                    title: Text(
                      _role == "admin"
                          ? "Tin nhắn với nhân viên"
                          : "Liên hệ Quản trị viên",
                    ),
                    onTap: () {
                      if (_role == "admin") {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ChatListScreen(),
                          ),
                        );
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ChatScreen(
                              receiverId: "admin",
                              receiverName: "Admin",
                            ),
                          ),
                        );
                      }
                    },
                  ),
                  if (_role == "admin") ...[
                    ListTile(
                      leading: const Icon(Icons.admin_panel_settings),
                      title: const Text("Quản lý tài khoản"),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const QuanLyTaiKhoanScreen(),
                          ),
                        );
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.approval),
                      title: const Text("Duyệt yêu cầu nhập kho"),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const DuyetYeuCauNhapScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),
            SafeArea(
              top: false,
              child: ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text("Đăng xuất"),
                onTap: () async {
                  await CurrentUser.clearPrefs();
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
