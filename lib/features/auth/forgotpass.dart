import 'dart:math';
import 'package:flutter/material.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server/gmail.dart';
import '../../core/services/user_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

enum ForgotStep { email, otp, newPassword }

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPassController = TextEditingController();

  ForgotStep _currentStep = ForgotStep.email;
  String _userEmail = "";

  final UserService _userService = UserService();

  // Thêm biến loading
  bool _isLoading = false;

  Future<void> _sendOtp() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showSnack("Vui lòng nhập email hợp lệ");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = await _userService.getUserByEmail(email);
      if (user == null) {
        _showSnack("Email không tồn tại trong hệ thống");
        return;
      }

      final otp = (100000 + Random().nextInt(900000)).toString();

      final success = await _userService.saveOtp(email, otp);
      if (!success) {
        _showSnack("Lỗi hệ thống, vui lòng thử lại sau");
        return;
      }

      final smtpServer = gmail("longphimon003@gmail.com", "yxayandgvceiyvww");

      final message = Message()
        ..from = const Address("longphimon003@gmail.com", "App Quản Lý Kho")
        ..recipients.add(email)
        ..subject = "Mã OTP đặt lại mật khẩu"
        ..text = "Mã OTP của bạn là: $otp\n\nMã có hiệu lực trong 10 phút.";

      await send(message, smtpServer);

      if (mounted) {
        setState(() {
          _currentStep = ForgotStep.otp;
          _userEmail = email;
        });
        _showSnack("Mã OTP đã được gửi đến email của bạn");
      }
    } catch (e) {
      _showSnack("Gửi email thất bại. Vui lòng kiểm tra kết nối mạng.");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.isEmpty || otp.length != 6) {
      _showSnack("Vui lòng nhập mã OTP 6 chữ số");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = await _userService.verifyOtp(_userEmail, otp);
      if (user == null) {
        _showSnack("Mã OTP không đúng hoặc đã hết hạn");
        return;
      }

      if (mounted) {
        setState(() {
          _currentStep = ForgotStep.newPassword;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _resetPassword() async {
    final newPass = _newPassController.text.trim();

    if (!_isPasswordValid(newPass)) {
      _showSnack("Mật khẩu không đủ mạnh. Vui lòng kiểm tra lại điều kiện.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final success = await _userService.updatePasswordByEmail(
        _userEmail,
        newPass,
      );
      if (success) {
        _showSnack("Đặt lại mật khẩu thành công! Vui lòng đăng nhập lại.");
        if (mounted) Navigator.pop(context);
      } else {
        _showSnack("Có lỗi xảy ra, vui lòng thử lại");
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  bool _isPasswordValid(String pass) {
    return pass.length >= 12 &&
        pass.length <= 20 &&
        RegExp(r'[A-Z]').hasMatch(pass) &&
        RegExp(r'[a-z]').hasMatch(pass) &&
        RegExp(r'[0-9]').hasMatch(pass) &&
        RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(pass);
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  // Hàm chung để tạo nút có loading
  Widget _loadingButton({
    required String text,
    required VoidCallback? onPressed,
  }) {
    return ElevatedButton(
      onPressed: _isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 48), // Nút rộng hơn
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
      child: _isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Text(text),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
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
                    "Quên mật khẩu",
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
                    child: _buildCurrentStep(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case ForgotStep.email:
        return Column(
          children: [
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: "Nhập email",
                prefixIcon: Icon(Icons.email),
              ),
            ),
            const SizedBox(height: 20),
            _loadingButton(text: "Gửi mã OTP", onPressed: _sendOtp),
          ],
        );

      case ForgotStep.otp:
        return Column(
          children: [
            Text(
              "Mã OTP đã được gửi đến $_userEmail",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Nhập mã OTP",
                prefixIcon: Icon(Icons.pin),
              ),
            ),
            const SizedBox(height: 20),
            _loadingButton(text: "Xác nhận", onPressed: _verifyOtp),
          ],
        );

      case ForgotStep.newPassword:
        final pass = _newPassController.text;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _newPassController,
              obscureText: true,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: "Mật khẩu mới",
                prefixIcon: Icon(Icons.lock),
              ),
            ),
            const SizedBox(height: 20),
            _buildRule("12-20 ký tự", pass.length >= 12 && pass.length <= 20),
            _buildRule(
              "Có chữ hoa, thường, số",
              RegExp(r'[A-Z]').hasMatch(pass) &&
                  RegExp(r'[a-z]').hasMatch(pass) &&
                  RegExp(r'[0-9]').hasMatch(pass),
            ),
            _buildRule(
              "Có ít nhất 1 ký tự đặc biệt",
              RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(pass),
            ),
            const SizedBox(height: 20),
            _loadingButton(text: "Đặt lại mật khẩu", onPressed: _resetPassword),
          ],
        );
    }
  }

  Widget _buildRule(String text, bool ok) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle : Icons.cancel,
            color: ok ? Colors.green : Colors.red,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(text, style: TextStyle(color: ok ? Colors.green : Colors.red)),
        ],
      ),
    );
  }
}
