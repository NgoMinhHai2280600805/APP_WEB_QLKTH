import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'core/firebase_options.dart';
import 'core/services/user_service.dart';
import 'main.dart'; // để dùng MyApp

class SplashWrapper extends StatefulWidget {
  const SplashWrapper({super.key});

  @override
  State<SplashWrapper> createState() => _SplashWrapperState();
}

class _SplashWrapperState extends State<SplashWrapper> {
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    try {
      await UserService().ensureDefaultAdmin();
    } catch (_) {}

    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    setState(() {
      _isInitialized = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Nếu chưa load xong → hiện splash
    if (!_isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.blueAccent,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.warehouse, size: 80, color: Colors.white),
              SizedBox(height: 20),
              Text(
                "Quản Lý Kho Hàng",
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ],
          ),
        ),
      );
    }

    // Load xong → trả về MyApp
    return const MyApp();
  }
}
