import 'package:app_qlkth_nhom8/features/admin/home_admin.dart';
import 'package:flutter/material.dart';
import 'features/auth/login.dart';
import 'features/staff/xuatkho.dart';
import 'features/admin/kho_hang.dart';
import 'features/common/menu.dart';
import 'core/current_user.dart';
import 'package:sqflite/sqflite.dart';
import 'widgets/drawer.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/firebase_options.dart';
import 'core/services/user_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'features/common/thongke_staff/thongke_staff_screen.dart';
import 'features/staff/home_staff.dart';
import 'features/common/thongke_admin/thongke_admin_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/services/gemini_service.dart';

Future<void> deleteOldDatabase() async {
  final dbPath = await getDatabasesPath();
  await deleteDatabase('$dbPath/warehouse.db');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  //await deleteOldDatabase();
  await dotenv.load(fileName: ".env");
  GeminiService().init();
  try {
    await UserService().ensureDefaultAdmin();
  } catch (e) {
    print('Lỗi khi đảm bảo admin mặc định: $e');
  }
  runApp(const MyApp());
}

// MyApp Stateful để kiểm tra trạng thái đăng nhập
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Widget _home = const Scaffold(
    body: Center(child: CircularProgressIndicator()),
  );

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    bool loggedIn = await CurrentUser.loadFromPrefs();

    if (!loggedIn) {
      final prefs = await SharedPreferences.getInstance();
      final loginTime = prefs.getInt('login_time');

      if (loginTime != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text("Thông báo"),
              content: const Text(
                "Phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại.",
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text("Đồng ý"),
                ),
              ],
            ),
          );
        });
      }
    }

    setState(() {
      _home = loggedIn ? const HomePage() : const LoginScreen();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quản Lý Kho',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: _home,
      debugShowCheckedModeBanner: false,
    );
  }
}

// HomePage chính với behavior nhấn 2 lần back để thoát
class HomePage extends StatefulWidget {
  final int initialIndex;
  const HomePage({super.key, this.initialIndex = 0});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  late List<Widget> _screens;
  late List<BottomNavigationBarItem> _items;
  DateTime? _lastPressed; // Biến lưu thời gian nhấn back lần cuối

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;

    if (CurrentUser.role == 'admin') {
      _screens = [
        const HomeAdminScreen(),
        const KhoHangScreen(),
        const ThongKeAdminScreen(),
        const MenuScreen(),
      ];

      _items = const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: "Trang chủ"),
        BottomNavigationBarItem(
          icon: Icon(Icons.inventory_2),
          label: "Kho hàng",
        ),
        BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: "Thống kê"),
        BottomNavigationBarItem(icon: Icon(Icons.menu), label: "Menu"),
      ];
    } else {
      _screens = [
        const HomeStaffScreen(),
        const XuatKhoScreen(),
        const ThongKeStaffScreen(),
        const MenuScreen(),
      ];

      _items = const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: "Trang chủ"),
        BottomNavigationBarItem(icon: Icon(Icons.outbox), label: "Xuất kho"),
        BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: "Thống kê"),
        BottomNavigationBarItem(icon: Icon(Icons.menu), label: "Menu"),
      ];
    }
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        final now = DateTime.now();
        if (_lastPressed == null ||
            now.difference(_lastPressed!) > const Duration(seconds: 2)) {
          _lastPressed = now;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Nhấn thêm lần nữa để thoát ứng dụng"),
              duration: Duration(seconds: 2),
            ),
          );
          return false;
        }
        return true;
      },
      child: Scaffold(
        extendBodyBehindAppBar: false,
        drawerScrimColor: Colors.black.withOpacity(0.5),
        drawerEdgeDragWidth: MediaQuery.of(context).size.width,
        drawer: const CustomDrawer(),
        body: IndexedStack(index: _selectedIndex, children: _screens),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: (_selectedIndex >= 0 && _selectedIndex < _items.length)
              ? _selectedIndex
              : 0,
          onTap: _onItemTapped,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Colors.blue,
          unselectedItemColor: Colors.grey,
          items: _items,
        ),
      ),
    );
  }
}
