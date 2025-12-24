//import 'dart:convert';
import 'package:flutter/material.dart';
//import 'package:crypto/crypto.dart';
import '../../core/services/user_service.dart';
import '../../../main.dart';
import '../auth/register.dart';
import '../auth/forgotpass.dart';
import '../../../core/current_user.dart';

/// Màn hình đăng nhập (sử dụng Firestore)
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _userService = UserService();
  bool _isLoading = false;

  /// Xử lý đăng nhập qua Firestore
  Future<void> _login() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      _showSnack("Vui lòng nhập tên đăng nhập và mật khẩu");
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = await _userService.login(username, password);

      if (user == null) {
        _showSnack("Tên đăng nhập hoặc mật khẩu không chính xác");
      } else if ((user['is_locked'] ?? false) == true) {
        _showSnack("Tài khoản của bạn đã bị khóa");
      } else {
        //   Lưu thông tin người dùng hiện tại
        // gán an toàn: convert -> String hoặc null nếu không có
        CurrentUser.id = user['id']?.toString();
        CurrentUser.username = user['username']?.toString() ?? '';
        CurrentUser.email = user['email']?.toString() ?? '';
        CurrentUser.role = (user['role'] ?? 'staff').toString();
        CurrentUser.avatar = (user['avatar'] ?? '').toString();
        CurrentUser.fullname = (user['fullname'] ?? '').toString();

        await CurrentUser.saveToPrefs();

        try {
          await _userService.logLogin(user);
        } catch (e) {
          print("Lỗi ghi log đăng nhập: $e");
        }

        //   Thông báo thành công và chuyển sang Home
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) {
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) {
                Navigator.of(context, rootNavigator: true).pop();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const HomePage()),
                );
              }
            });
            return const AlertDialog(
              title: Text("Thành công"),
              content: Text("Đăng nhập thành công!"),
            );
          },
        );
      }
    } catch (e) {
      _showSnack("Đã xảy ra lỗi khi đăng nhập: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Hiển thị thông báo nhanh
  void _showSnack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
  }

  /// Giao diện chính
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset("assets/anhnendangnhap.png", fit: BoxFit.cover),
            SingleChildScrollView(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 80,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      "App quản lý kho",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "Đăng nhập",
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 30),

                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          TextField(
                            controller: _usernameController,
                            decoration: const InputDecoration(
                              labelText: "Tên đăng nhập",
                              prefixIcon: Icon(Icons.person),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _passwordController,
                            decoration: const InputDecoration(
                              labelText: "Mật khẩu",
                              prefixIcon: Icon(Icons.lock),
                            ),
                            obscureText: false,
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const ForgotPasswordScreen(),
                                  ),
                                );
                              },
                              child: const Text(
                                "Quên mật khẩu?",
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: _isLoading ? null : _login,
                              child: _isLoading
                                  ? const CircularProgressIndicator(
                                      color: Colors.white,
                                    )
                                  : const Text(
                                      "Đăng nhập",
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text("Chưa có tài khoản? "),
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const RegisterScreen(),
                                    ),
                                  );
                                },
                                child: const Text(
                                  "Đăng ký",
                                  style: TextStyle(
                                    color: Colors.blue,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
