import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('warehouse.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(
      path,
      version: 4, // ✅ nâng version để đảm bảo upgrade chạy
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  // ===================== TẠO DATABASE BAN ĐẦU =====================
  Future _createDB(Database db, int version) async {
    await db.execute('''
    CREATE TABLE categories (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL UNIQUE,
      description TEXT,
      is_deleted INTEGER DEFAULT 0
    )
  ''');

    await db.execute('''
    CREATE TABLE users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      username TEXT NOT NULL UNIQUE,
      password TEXT NOT NULL,
      email TEXT NOT NULL UNIQUE,
      role TEXT NOT NULL DEFAULT 'staff',
      otp_code TEXT,
      otp_expire INTEGER,
      is_locked INTEGER DEFAULT 0,
      avatar TEXT
    )
  ''');

    await db.execute('''
    CREATE TABLE products (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      code TEXT NOT NULL,
      price REAL NOT NULL,
      avatar TEXT,
      quantity INTEGER NOT NULL,
      category_id INTEGER,
      description TEXT,
      image TEXT,
      is_deleted INTEGER DEFAULT 0,
      FOREIGN KEY(category_id) REFERENCES categories(id)
    )
  ''');

    await db.execute('''
    CREATE TABLE exports (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER,
      product_id INTEGER,
      quantity INTEGER,
      date TEXT,
      FOREIGN KEY(user_id) REFERENCES users(id),
      FOREIGN KEY(product_id) REFERENCES products(id)
    )
  ''');

    await db.execute('''
    CREATE TABLE import_requests (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER,
      product_id INTEGER,
      quantity INTEGER,
      reason TEXT,
      status TEXT DEFAULT 'pending',
      FOREIGN KEY(user_id) REFERENCES users(id),
      FOREIGN KEY(product_id) REFERENCES products(id)
    )
  ''');

    await db.execute('''
    CREATE TABLE settings (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      allow_register INTEGER DEFAULT 1
    )
  ''');

    await db.insert('settings', {'allow_register': 1});

    // ===== TẠO ADMIN MẶC ĐỊNH =====
    String defaultPassword = "@Syegenta12345555+";
    String hashed = hashPassword(defaultPassword);

    await db.insert('users', {
      'username': 'duatienday5',
      'password': hashed,
      'email': 'longphimon0047@gmail.com',
      'role': 'staff',
    });
  }

  // ===================== HASH PASSWORD =====================
  String hashPassword(String input) {
    return sha256.convert(utf8.encode(input)).toString();
  }

  // ===================== UPGRADE DATABASE =====================
  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute("ALTER TABLE users ADD COLUMN otp_code TEXT");
      await db.execute("ALTER TABLE users ADD COLUMN otp_expire INTEGER");
      await db.execute(
        "ALTER TABLE users ADD COLUMN is_locked INTEGER DEFAULT 0",
      );

      await db.execute('''
        CREATE TABLE IF NOT EXISTS settings (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          allow_register INTEGER DEFAULT 1
        )
      ''');

      final check = await db.query('settings');
      if (check.isEmpty) {
        await db.insert('settings', {'allow_register': 1});
      }
    }
  }

  // ===================== CATEGORIES =====================
  Future<int> insertCategory(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('categories', row);
  }

  Future<List<Map<String, dynamic>>> queryAllCategories() async {
    final db = await instance.database;
    return await db.query('categories');
  }

  Future<int> updateCategory(Map<String, dynamic> row) async {
    final db = await instance.database;
    int id = row['id'];
    return await db.update('categories', row, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteCategory(int id) async {
    final db = await instance.database;
    return await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  // ===================== PRODUCTS =====================
  Future<int> insertProduct(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('products', row);
  }

  Future<List<Map<String, dynamic>>> queryAllProducts() async {
    final db = await instance.database;
    return await db.query('products');
  }

  Future<int> updateProduct(Map<String, dynamic> row) async {
    final db = await instance.database;
    int id = row['id'];
    return await db.update('products', row, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteProduct(int id) async {
    final db = await instance.database;
    return await db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  // ===================== USERS =====================
  Future<int> insertUser(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('users', row);
  }

  Future<Map<String, dynamic>?> getUser(
    String username,
    String password,
  ) async {
    final db = await instance.database;
    final res = await db.query(
      'users',
      where: 'username = ? AND password = ?',
      whereArgs: [username, password],
    );
    if (res.isNotEmpty) return res.first;
    return null;
  }

  Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    final db = await instance.database;
    final res = await db.query('users', where: 'email = ?', whereArgs: [email]);
    if (res.isNotEmpty) return res.first;
    return null;
  }

  Future<int> updatePassword(String email, String newPassword) async {
    final db = await instance.database;
    return await db.update(
      'users',
      {'password': newPassword, 'otp_code': null, 'otp_expire': null},
      where: 'email = ?',
      whereArgs: [email],
    );
  }

  Future<int> updateUserAvatar(int userId, String path) async {
    final db = await instance.database;
    return await db.update(
      'users',
      {'avatar': path},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  // ===================== OTP =====================
  Future<int> saveOtp(String email, String otp, int expireTime) async {
    final db = await instance.database;
    return await db.update(
      'users',
      {'otp_code': otp, 'otp_expire': expireTime},
      where: 'email = ?',
      whereArgs: [email],
    );
  }

  Future<Map<String, dynamic>?> verifyOtp(String email, String otp) async {
    final db = await instance.database;
    final res = await db.query(
      'users',
      where: 'email = ? AND otp_code = ?',
      whereArgs: [email, otp],
    );
    if (res.isNotEmpty) return res.first;
    return null;
  }

  Future<void> clearOtp(String email) async {
    final db = await instance.database;
    await db.update(
      'users',
      {'otp_code': null, 'otp_expire': null},
      where: 'email = ?',
      whereArgs: [email],
    );
  }

  // ===================== USER MANAGEMENT =====================
  Future<List<Map<String, dynamic>>> queryAllUsers() async {
    final db = await instance.database;
    return await db.query('users');
  }

  Future<int> deleteUser(int id) async {
    final db = await instance.database;
    return await db.delete('users', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> lockUser(int id, bool locked) async {
    final db = await instance.database;
    return await db.update(
      'users',
      {'is_locked': locked ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ===================== SETTINGS =====================
  Future<bool> isRegisterAllowed() async {
    final db = await instance.database;
    final res = await db.query('settings', limit: 1);
    if (res.isNotEmpty) {
      return res.first['allow_register'] == 1;
    }
    return true;
  }

  Future<int> setRegisterAllowed(bool allowed) async {
    final db = await instance.database;
    return await db.update('settings', {'allow_register': allowed ? 1 : 0});
  }

  // ===================== IMPORT REQUESTS =====================
  Future<int> insertImportRequest(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('import_requests', row);
  }

  Future<List<Map<String, dynamic>>> getImportRequests({
    bool adminView = false,
    int? userId,
  }) async {
    final db = await instance.database;
    if (adminView) {
      return await db.query('import_requests');
    } else {
      return await db.query(
        'import_requests',
        where: 'user_id = ?',
        whereArgs: [userId],
      );
    }
  }

  Future<int> updateImportRequestStatus(int id, String status) async {
    final db = await instance.database;
    return await db.update(
      'import_requests',
      {'status': status},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> increaseProductQuantity(int productId, int amount) async {
    final db = await instance.database;
    await db.rawUpdate(
      'UPDATE products SET quantity = quantity + ? WHERE id = ?',
      [amount, productId],
    );
  }

  // lấy tt dm
  Future<Map<String, dynamic>?> getCategoryById(int id) async {
    final db = await instance.database;
    final result = await db.query(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (result.isNotEmpty) return result.first;
    return null;
  }
}
