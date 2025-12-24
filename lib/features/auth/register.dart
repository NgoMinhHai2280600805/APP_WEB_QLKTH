import 'package:flutter/material.dart';

// import thêm
import '../../core/services/user_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPassController = TextEditingController();
  final _emailController = TextEditingController();
  final _fullnameController = TextEditingController();
  final userService = UserService();
  bool _isLoading = false;

  bool _isPasswordValid(String pass) {
    final hasLength = pass.length >= 12 && pass.length <= 20;
    final hasUpperLowerNumber =
        pass.contains(RegExp(r'[A-Z]')) &&
        pass.contains(RegExp(r'[a-z]')) &&
        pass.contains(RegExp(r'[0-9]'));
    final hasSpecial = pass.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'));
    return hasLength && hasUpperLowerNumber && hasSpecial;
  }

  Future<void> _register() async {
    final username = _usernameController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPass = _confirmPassController.text.trim();
    final email = _emailController.text.trim();
    final fullname = _fullnameController.text.trim();

    if (username.isEmpty ||
        password.isEmpty ||
        confirmPass.isEmpty ||
        email.isEmpty ||
        fullname.isEmpty ||
        phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Vui lòng nhập đầy đủ thông tin")),
      );
      return;
    }

    if (password != confirmPass) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Mật khẩu nhập lại không khớp")),
      );
      return;
    }

    if (!_isPasswordValid(password)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Mật khẩu chưa đáp ứng đủ điều kiện")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await userService.registerUser(
        username: username,
        email: email,
        password: password,
        fullname: fullname,
        role: 'staff',
        phone: phone,
      );

      if (result == 'OK') {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Đăng ký thành công!")));
        Navigator.pop(context);
      } else if (result == 'USERNAME_EXISTS') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Tên đăng nhập đã tồn tại")),
        );
      } else if (result == 'EMAIL_EXISTS') {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Email đã tồn tại")));
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Lỗi: $result")));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Lỗi: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildCondition(String text, bool passed) {
    return Row(
      children: [
        Icon(
          passed ? Icons.check_circle : Icons.cancel,
          color: passed ? Colors.green : Colors.red,
          size: 20,
        ),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(color: passed ? Colors.green : Colors.red)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final pass = _passwordController.text;

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
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
                      "Đăng ký",
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
                            controller: _fullnameController,
                            decoration: const InputDecoration(
                              labelText: "Họ tên",
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                          ),
                          SizedBox(height: 16),

                          TextField(
                            controller: _usernameController,
                            decoration: const InputDecoration(
                              labelText: "Tên đăng nhập",
                              prefixIcon: Icon(Icons.person),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _emailController,
                            decoration: const InputDecoration(
                              labelText: "Email",
                              prefixIcon: Icon(Icons.email),
                            ),
                          ),
                          TextField(
                            controller: _phoneController,
                            decoration: const InputDecoration(
                              labelText: "Số điện thoại",
                              prefixIcon: Icon(Icons.phone),
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
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 10),
                          // Điều kiện mật khẩu
                          _buildCondition(
                            "Có ít nhất 12-20 ký tự",
                            pass.length >= 12 && pass.length <= 20,
                          ),
                          _buildCondition(
                            "Bao gồm số, chữ viết hoa, chữ viết thường",
                            pass.contains(RegExp(r'[A-Z]')) &&
                                pass.contains(RegExp(r'[a-z]')) &&
                                pass.contains(RegExp(r'[0-9]')),
                          ),
                          _buildCondition(
                            "Ít nhất 1 ký tự đặc biệt",
                            pass.contains(RegExp(r'[!@#\$%^&*(),.?\":{}|<>]')),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _confirmPassController,
                            decoration: const InputDecoration(
                              labelText: "Nhập lại mật khẩu",
                              prefixIcon: Icon(Icons.lock_outline),
                            ),
                            obscureText: false,
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: _isLoading ? null : _register,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              minimumSize: const Size(double.infinity, 48),
                            ),
                            child: _isLoading
                                ? const CircularProgressIndicator(
                                    color: Colors.white,
                                  )
                                : const Text(
                                    "Đăng ký",
                                    style: TextStyle(color: Colors.white),
                                  ),
                          ),
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text("Quay lại đăng nhập"),
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
