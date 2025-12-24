import 'package:shared_preferences/shared_preferences.dart';

class CurrentUser {
  static String? id; // lưu id doc Firestore
  static String role = 'staff';
  static String? username;
  static String? avatar;
  static String? email;
  static String? fullname;
  static String? phone;

  static bool get isAdmin => role == "admin";

  ///   Lưu dữ liệu người dùng vào SharedPreferences (ép tất cả về String)
  static Future<void> saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('user_id', id ?? '');
    await prefs.setString('username', username ?? '');
    await prefs.setString('email', email ?? '');
    await prefs.setString('role', role);
    await prefs.setString('avatar', avatar ?? '');
    await prefs.setString('fullname', fullname ?? '');
    await prefs.setString('user_phone', phone ?? '');
    // thời điểm đăng nhập (để tính thời hạn 7 ngày)
    await prefs.setInt('login_time', DateTime.now().millisecondsSinceEpoch);
  }

  ///   Đọc dữ liệu từ SharedPreferences (ép kiểu an toàn)
  static Future<bool> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    // xử lý login_time (có thể là int hoặc String)
    final dynamic loginRaw = prefs.get('login_time');
    int? loginTime;

    if (loginRaw is int) {
      loginTime = loginRaw;
    } else if (loginRaw is String) {
      loginTime = int.tryParse(loginRaw);
    }

    if (loginTime == null) return false;

    // nếu quá 7 ngày → xóa phiên
    final diff = DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(loginTime))
        .inDays;
    if (diff > 7) {
      await clearPrefs();
      return false;
    }

    // ⚙️ Đọc các giá trị, ép kiểu về String an toàn
    id = prefs.get('user_id')?.toString();
    username = prefs.get('username')?.toString();
    email = prefs.get('email')?.toString();
    role = prefs.get('role')?.toString() ?? 'staff';
    avatar = prefs.get('avatar')?.toString();
    fullname = prefs.get('fullname')?.toString();

    phone = prefs.getString('user_phone');

    return (id != null &&
        id!.isNotEmpty &&
        username != null &&
        username!.isNotEmpty);
  }

  ///   Tạo ID chat dựa trên vai trò
  static String get chatIdString {
    if (role == "admin") return "admin";
    return "staff_${id ?? 'unknown'}";
  }

  ///   Xóa dữ liệu khi đăng xuất hoặc hết hạn phiên
  static Future<void> clearPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    id = null;
    username = null;
    email = null;
    role = 'staff';
    avatar = null;
    fullname = null;
    phone = null;
  }
}
