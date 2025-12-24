// lib/core/services/user_service.dart
import 'dart:io';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _inner = http.Client();
  GoogleAuthClient(this._headers);
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _inner.send(request..headers.addAll(_headers));
}

class UserService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String _hash(String input) {
    return sha256.convert(utf8.encode(input)).toString();
  }

  Future<String?> _ensureAvatarFolder(drive.DriveApi driveApi) async {
    try {
      // Tìm folder có tên "Avatar" ở root
      final q =
          "mimeType='application/vnd.google-apps.folder' and name='Avatar' and trashed = false";
      final found = await driveApi.files.list(
        q: q,
        spaces: 'drive',
        $fields: 'files(id,name)',
        pageSize: 1,
      );
      if (found.files != null && found.files!.isNotEmpty) {
        return found.files!.first.id;
      }

      // Tạo mới
      final folder = drive.File()
        ..name = 'Avatar'
        ..mimeType = 'application/vnd.google-apps.folder'
        ..parents = ['root'];
      final created = await driveApi.files.create(folder);
      return created.id;
    } catch (e) {
      print('Lỗi ensureAvatarFolder: $e');
      return null;
    }
  }

  Future<String?> uploadAvatarToDrive(File imageFile) async {
    try {
      final googleSignIn = GoogleSignIn.standard(
        scopes: [drive.DriveApi.driveScope],
      );
      final account = await googleSignIn.signIn();
      if (account == null) throw Exception("Người dùng chưa đăng nhập Google");

      final headers = await account.authHeaders;
      final client = GoogleAuthClient(headers);
      final driveApi = drive.DriveApi(client);

      // đảm bảo folder tồn tại hoặc tạo mới
      final folderId = await _ensureAvatarFolder(driveApi);

      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${p.basename(imageFile.path)}';
      final gFile = drive.File()
        ..name = fileName
        ..parents = folderId != null ? [folderId] : ['root'];

      final media = drive.Media(imageFile.openRead(), imageFile.lengthSync());
      final uploaded = await driveApi.files.create(gFile, uploadMedia: media);

      // đặt quyền công khai đọc
      await driveApi.permissions.create(
        drive.Permission()
          ..type = 'anyone'
          ..role = 'reader',
        uploaded.id!,
      );

      final link = "https://drive.google.com/uc?export=view&id=${uploaded.id}";
      return link;
    } catch (e) {
      print("Lỗi uploadAvatarToDrive: $e");
      return null;
    }
  }

  Future<String> registerUser({
    required String username,
    required String email,
    required String password,
    required String phone,
    required String fullname,
    String role = 'staff',
    String? avatarUrl,
  }) async {
    final hashed = _hash(password);

    // kiểm tra username/email đã tồn tại
    final q1 = await _db
        .collection('users')
        .where('username', isEqualTo: username)
        .get();
    if (q1.docs.isNotEmpty) return 'USERNAME_EXISTS';

    final q2 = await _db
        .collection('users')
        .where('email', isEqualTo: email)
        .get();
    if (q2.docs.isNotEmpty) return 'EMAIL_EXISTS';

    final doc = {
      'username': username,
      'email': email,
      'password': hashed,
      'role': role,
      'fullname': fullname,
      'phone': phone,
      'avatar': avatarUrl ?? '',
      'is_locked': false,
      'created_at': FieldValue.serverTimestamp(),
    };

    await _db.collection('users').add(doc);
    return 'OK';
  }

  // ===========================
  Future<Map<String, dynamic>?> login(
    String identifier,
    String password,
  ) async {
    final hashed = _hash(password);

    QuerySnapshot<Map<String, dynamic>> q;

    // Nếu chứa @ => login bằng email
    if (identifier.contains("@")) {
      q = await _db
          .collection('users')
          .where('email', isEqualTo: identifier)
          .where('password', isEqualTo: hashed)
          .limit(1)
          .get();
    }
    // Nếu chỉ là số => login bằng phone
    else if (RegExp(r'^[0-9]+$').hasMatch(identifier)) {
      q = await _db
          .collection('users')
          .where('phone', isEqualTo: identifier)
          .where('password', isEqualTo: hashed)
          .limit(1)
          .get();
    }
    // Mặc định là username
    else {
      q = await _db
          .collection('users')
          .where('username', isEqualTo: identifier)
          .where('password', isEqualTo: hashed)
          .limit(1)
          .get();
    }

    if (q.docs.isEmpty) return null;

    final doc = q.docs.first;
    return {'id': doc.id, ...doc.data()};
  }

  Future<void> ensureDefaultAdmin() async {
    try {
      final q = await _db
          .collection('users')
          .where('username', isEqualTo: 'duatienday')
          .limit(1)
          .get();
      if (q.docs.isNotEmpty) return; // có rồi

      final defaultPassword = "@Syegenta12345555+";
      final hashed = _hash(defaultPassword);

      await _db.collection('users').add({
        'username': 'duatienday',
        'email': 'longphimon003@gmail.com',
        'password': hashed,
        'role': 'admin',
        'fullname': 'Ngô Minh Hải',
        'phone': '0389306604',
        'avatar': '',
        'is_locked': false,
        'created_at': FieldValue.serverTimestamp(),
      });
      print('=> Default admin created in Firestore');
    } catch (e) {
      print('Lỗi ensureDefaultAdmin: $e');
    }
  }

  //////////////////////////
  ///
  ///
  ///
  //// Ghi log đăng nhập
  Future<String> getIp() async {
    try {
      final response = await http.get(
        Uri.parse('https://api.ipify.org?format=json'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['ip'] ?? 'unknown';
      }
    } catch (e) {
      print('Lỗi getIp: $e');
    }
    return 'unknown';
  }

  Future<void> logLogin(Map<String, dynamic> user) async {
    String os = 'unknown';
    String osVersion = 'unknown';
    String device = 'unknown';

    final deviceInfo = DeviceInfoPlugin();

    try {
      if (kIsWeb) {
        final webInfo = await deviceInfo.webBrowserInfo;
        os = webInfo.platform ?? 'web';
        osVersion = webInfo.userAgent ?? 'unknown';
        device = webInfo.userAgent ?? 'unknown';
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        os = 'Android';
        osVersion = androidInfo.version.release;
        device = '${androidInfo.manufacturer} ${androidInfo.model}'.trim();
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        os = 'iOS';
        osVersion = iosInfo.systemVersion;
        device = iosInfo.name;
      }
    } catch (e) {
      print('Lỗi lấy thông tin thiết bị: $e');
    }

    final ip = await getIp();

    try {
      await _db.collection('user_logins').add({
        'userId': user['id'],
        'username': user['username'],
        'role': user['role'] ?? 'staff',
        'ip': ip,
        'platform': os,
        'osVersion': osVersion,
        'device': device,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Lỗi ghi log đăng nhập: $e');
    }
  }

  /////////////
  ///
  ///
  ///
  ///
  // Cập nhật avatar link cho user

  Future<void> updateAvatarLink(String userDocId, String avatarLink) async {
    await _db.collection('users').doc(userDocId).update({'avatar': avatarLink});
  }

  // lấy user theo email (dùng quên mật khẩu)
  Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    final q = await _db
        .collection('users')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();
    if (q.docs.isEmpty) return null;
    return {'id': q.docs.first.id, ...q.docs.first.data()};
  }

  Future<List<Map<String, dynamic>>> getAllUsers() async {
    final snapshot = await _db.collection('users').get();
    return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
  }

  /// 🗑️ Xóa user
  Future<void> deleteUser(String id) async {
    await _db.collection('users').doc(id).delete();
  }

  /// 🔒 Khóa / mở khóa user
  Future<void> lockUser(String id, bool locked) async {
    await _db.collection('users').doc(id).update({'is_locked': locked});
  }

  /// 👤 Thêm user mới
  Future<void> addUser(Map<String, dynamic> data) async {
    await _db.collection('users').add(data);
  }

  // ===================== QUÊN MẬT KHẨU - OTP =====================

  /// Lưu OTP và thời gian hết hạn vào Firestore
  Future<bool> saveOtp(String email, String otp) async {
    try {
      final user = await getUserByEmail(email);
      if (user == null) return false;

      final expireTime =
          DateTime.now().millisecondsSinceEpoch + 10 * 60 * 1000; // 10 phút

      await _db.collection('users').doc(user['id']).update({
        'otp_code': otp,
        'otp_expire': expireTime,
      });
      return true;
    } catch (e) {
      print('Lỗi saveOtp: $e');
      return false;
    }
  }

  /// Xác thực OTP
  Future<Map<String, dynamic>?> verifyOtp(String email, String otp) async {
    try {
      final snapshot = await _db
          .collection('users')
          .where('email', isEqualTo: email)
          .where('otp_code', isEqualTo: otp)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;

      final userData = snapshot.docs.first.data();
      final expire = userData['otp_expire'] as int?;

      if (expire == null || DateTime.now().millisecondsSinceEpoch > expire) {
        return null; // Hết hạn
      }

      return {'id': snapshot.docs.first.id, ...userData};
    } catch (e) {
      print('Lỗi verifyOtp: $e');
      return null;
    }
  }

  /// Xóa OTP sau khi dùng xong hoặc hết hạn
  Future<void> clearOtp(String email) async {
    try {
      final user = await getUserByEmail(email);
      if (user == null) return;

      await _db.collection('users').doc(user['id']).update({
        'otp_code': null,
        'otp_expire': null,
      });
    } catch (e) {
      print('Lỗi clearOtp: $e');
    }
  }

  /// Cập nhật mật khẩu mới (đã hash)
  Future<bool> updatePasswordByEmail(String email, String newPassword) async {
    try {
      final hashed = _hash(newPassword);
      final user = await getUserByEmail(email);
      if (user == null) return false;

      await _db.collection('users').doc(user['id']).update({
        'password': hashed,
        'otp_code': null,
        'otp_expire': null,
      });
      return true;
    } catch (e) {
      print('Lỗi updatePasswordByEmail: $e');
      return false;
    }
  }
}
