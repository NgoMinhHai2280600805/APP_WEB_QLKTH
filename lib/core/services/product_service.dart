import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;

class ProductService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ==============================================================
  // ==================== CHỨC NĂNG DÀNH CHO ADMIN =================
  // ==============================================================

  //  Tải ảnh lên Google Drive
  Future<String?> uploadImage(File imageFile) async {
    try {
      final googleSignIn = GoogleSignIn.standard(
        scopes: [drive.DriveApi.driveFileScope],
      );
      final account = await googleSignIn.signIn();
      if (account == null) throw Exception("Người dùng chưa đăng nhập Google");
      final authHeaders = await account.authHeaders;
      final authenticateClient = GoogleAuthClient(authHeaders);
      final driveApi = drive.DriveApi(authenticateClient);
      String folderId;
      final folderList = await driveApi.files.list(
        q: "mimeType='application/vnd.google-apps.folder' and name='AnhSP'",
        spaces: 'drive',
      );
      if (folderList.files != null && folderList.files!.isNotEmpty) {
        folderId = folderList.files!.first.id!;
      } else {
        final folder = drive.File()
          ..name = 'AnhSP'
          ..mimeType = 'application/vnd.google-apps.folder';
        final createdFolder = await driveApi.files.create(folder);
        folderId = createdFolder.id!;
      }
      final fileName = path.basename(imageFile.path);
      final driveFile = drive.File()
        ..name = fileName
        ..parents = [folderId];
      final uploadedFile = await driveApi.files.create(
        driveFile,
        uploadMedia: drive.Media(imageFile.openRead(), imageFile.lengthSync()),
      );
      await driveApi.permissions.create(
        drive.Permission(type: 'anyone', role: 'reader'),
        uploadedFile.id!,
      );
      final link =
          "https://drive.google.com/uc?export=view&id=${uploadedFile.id}";
      return link;
    } catch (e) {
      print("Lỗi upload Drive: $e");
      return null;
    }
  }

  //  Xóa ảnh khỏi Google Drive
  Future<void> deleteImage(String imageUrl) async {
    try {
      final reg = RegExp(r"id=([a-zA-Z0-9_-]+)");
      final match = reg.firstMatch(imageUrl);
      final id = match?.group(1);
      if (id == null) return;
      final googleSignIn = GoogleSignIn.standard(
        scopes: [drive.DriveApi.driveFileScope],
      );
      final account = await googleSignIn.signIn();
      if (account == null) return;
      final authHeaders = await account.authHeaders;
      final authenticateClient = GoogleAuthClient(authHeaders);
      final driveApi = drive.DriveApi(authenticateClient);
      await driveApi.files.delete(id);
    } catch (e) {
      print("Lỗi xóa ảnh Drive: $e");
    }
  }

  //  Thêm sản phẩm mới
  Future<String?> addProduct(Map<String, dynamic> data) async {
    final docRef = await _db.collection('products').add({
      'name': data['name'] ?? '',
      'price': data['price'] ?? 0,
      'quantity': data['quantity'] ?? 0,
      'description': data['description'] ?? '',
      'category_id': data['category_id'] ?? '',
      'image': data['image'] ?? '',
      'batch_no': data['batch_no'] ?? '',
      'mfg_date': data['mfg_date'] ?? null,
      'exp_date': data['exp_date'] ?? null,
      'is_deleted': false,
      'created_at': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  //  Cập nhật thông tin sản phẩm
  Future<void> updateProduct(String id, Map<String, dynamic> data) async {
    await _db.collection('products').doc(id).update({
      'name': data['name'],
      'price': data['price'],
      'quantity': data['quantity'],
      'description': data['description'],
      'category_id': data['category_id'],
      'image': data['image'],
      'batch_no': data['batch_no'],
      'mfg_date': data['mfg_date'],
      'exp_date': data['exp_date'],
    });
  }

  //  Thêm lô hàng mới cho sản phẩm
  Future<void> addProductBatch(
    String productId,
    Map<String, dynamic> data,
  ) async {
    await _db.collection('product_batches').add({
      'product_id': productId,
      'batch_number': data['batch_number'] ?? '',
      'quantity': data['quantity'] ?? 0,
      'mfg_date': data['mfg_date'] ?? null,
      'expiry_date': data['expiry_date'] ?? null,
      'created_at': FieldValue.serverTimestamp(),
      'is_deleted': data['is_deleted'] ?? false,
    });
    await updateProductTotalQuantity(productId);
  }

  //  Cập nhật / xóa mềm / khôi phục lô hàng
  Future<void> updateProductBatch(
    String batchId,
    Map<String, dynamic> data, {
    bool softDelete = false,
    bool hardDelete = false,
    bool restore = false,
  }) async {
    final doc = await _db.collection('product_batches').doc(batchId).get();
    if (!doc.exists) return;
    final productId = doc['product_id'];
    if (hardDelete) {
      await _db.collection('product_batches').doc(batchId).delete();
    } else if (softDelete) {
      await _db.collection('product_batches').doc(batchId).update({
        'is_deleted': true,
      });
    } else if (restore) {
      await _db.collection('product_batches').doc(batchId).update({
        'is_deleted': false,
      });
    } else {
      await _db.collection('product_batches').doc(batchId).update({
        'batch_number': data['batch_number'],
        'quantity': data['quantity'],
        'mfg_date': data['mfg_date'],
        'expiry_date': data['expiry_date'],
      });
    }
    await updateProductTotalQuantity(productId);
  }

  //  Lấy danh sách lô hàng của sản phẩm
  Future<List<Map<String, dynamic>>> getProductBatches(String productId) async {
    try {
      final snapshot = await _db
          .collection('product_batches')
          .where('product_id', isEqualTo: productId)
          .where('is_deleted', isEqualTo: false)
          .get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'batch_number': data['batch_number']?.toString() ?? '',
          'quantity': (data['quantity'] as num? ?? 0).toInt(),
          'mfg_date': data['mfg_date'],
          'exp_date': data['expiry_date'],
          'created_at': data['created_at'],
        };
      }).toList();
    } catch (e) {
      print("Error loading batches: $e");
      return [];
    }
  }

  //  Cập nhật tổng số lượng sản phẩm từ các lô
  Future<void> updateProductTotalQuantity(String productId) async {
    final batchSnap = await _db
        .collection('product_batches')
        .where('product_id', isEqualTo: productId)
        .get();
    int total = 0;
    for (var doc in batchSnap.docs) {
      total += (doc['quantity'] ?? 0) as int;
    }
    await _db.collection('products').doc(productId).update({'quantity': total});
  }

  //  Ghi lịch sử nhập kho
  Future<void> logImportHistory({
    required List<Map<String, dynamic>> batches,
    required String adminName,
    required String adminEmail,
  }) async {
    await _db.collection('import_logs').add({
      'batches': batches,
      'admin_name': adminName,
      'admin_email': adminEmail,
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  // Lấy toàn bộ lịch sử xuất kho của nhân viên (dành cho admin xem thống kê)
  Future<List<Map<String, dynamic>>> getAllStaffExportLogs() async {
    final snap = await _db
        .collection('staff_export_logs')
        .orderBy('exported_at', descending: true)
        .get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  //  Lấy lịch sử nhập kho (ko xài)
  Future<List<Map<String, dynamic>>> getImportLogs() async {
    final snap = await _db
        .collection('import_logs')
        .orderBy('created_at', descending: true)
        .get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  //  Lấy danh sách sản phẩm
  Future<List<Map<String, dynamic>>> getProducts() async {
    final snapshot = await _db
        .collection('products')
        .where('is_deleted', isEqualTo: false)
        .get();
    return snapshot.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  //  Xóa mềm sản phẩm
  Future<void> softDeleteProduct(String id) async {
    await _db.collection('products').doc(id).update({'is_deleted': true});
  }

  //  Lấy danh sách danh mục
  Future<List<Map<String, dynamic>>> getCategories() async {
    final snapshot = await _db
        .collection('categories')
        .where('is_deleted', isEqualTo: false)
        .get();
    return snapshot.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  //  Thêm danh mục mới
  Future<String> addCategory(Map<String, dynamic> data) async {
    final docRef = await _db.collection('categories').add({
      'name': data['name'] ?? '',
      'description': data['description'] ?? '',
      'is_deleted': false,
      'created_at': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  //  Cập nhật danh mục
  Future<void> updateCategory(String id, Map<String, dynamic> data) async {
    await _db.collection('categories').doc(id).update(data);
  }

  //  Xóa mềm danh mục
  Future<void> softDeleteCategory(String id) async {
    await _db.collection('categories').doc(id).update({'is_deleted': true});
  }

  //  Lấy lịch sử xuất kho (có thể xem của nhân viên)

  //  Ghi lịch sử xuất kho (nếu cần)
  Future<void> logExportHistory({
    required String productId,
    required String productName,
    required int quantity,
    required double price,
    required int remaining,
    required String staffName,
    required String staffEmail,
  }) async {
    await _db.collection('export_logs').add({
      'product_id': productId,
      'product_name': productName,
      'quantity': quantity,
      'price': price,
      'remaining': remaining,
      'staff_name': staffName,
      'staff_email': staffEmail,
      'exported_at': FieldValue.serverTimestamp(),
    });
  }

  //  Ghi log khi admin chỉnh sửa sản phẩm
  Future<void> logAdminUpdateHistory({
    required String productId,
    required String productName,
    required int oldQuantity,
    required int newQuantity,
    double? price,
    String? adminRole,
    required String adminName,
    required String adminEmail,
    String? categoryName,
    String? batchNumber,
    int? oldBatchQuantity,
    int? newBatchQuantity,
  }) async {
    final roleToSave = adminRole ?? "admin";
    try {
      await _db.collection('admin_update_logs').add({
        'product_id': productId,
        'product_name': productName,
        'old_quantity': oldQuantity,
        'new_quantity': newQuantity,
        'price': price ?? 0,
        'admin_name': adminName,
        'admin_role': roleToSave,
        'admin_email': adminEmail,
        'category_name': categoryName ?? "",
        'batch_number': batchNumber ?? "",
        'old_batch_quantity': oldBatchQuantity ?? 0,
        'new_batch_quantity': newBatchQuantity ?? 0,
        'updated_at': FieldValue.serverTimestamp(),
      });
      print("Đã ghi log (vai trò: $roleToSave)");
    } catch (e) {
      print("Lỗi ghi log admin: $e");
    }
  }

  //  Lấy lịch sử cập nhật của admin
  Future<List<Map<String, dynamic>>> getAdminUpdateLogs() async {
    final snap = await _db
        .collection('admin_update_logs')
        .orderBy('updated_at', descending: true)
        .get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  //  Lấy chi tiết sản phẩm theo ID
  Future<Map<String, dynamic>?> getProductById(String productId) async {
    try {
      final doc = await _db.collection('products').doc(productId).get();
      if (doc.exists) return {'id': doc.id, ...doc.data()!};
      return null;
    } catch (e) {
      print("Lỗi getProductById: $e");
      return null;
    }
  }

  //  Lấy chi tiết danh mục theo ID
  Future<Map<String, dynamic>?> getCategoryById(String categoryId) async {
    try {
      final doc = await _db.collection('categories').doc(categoryId).get();
      if (doc.exists) return {'id': doc.id, ...doc.data()!};
      return null;
    } catch (e) {
      print("Lỗi getCategoryById: $e");
      return null;
    }
  }

  // ==============================================================
  // ================== CHỨC NĂNG DÀNH CHO NHÂN VIÊN ================
  // ==============================================================

  //  Ghi lịch sử xuất kho khi bán hàng
  Future<void> logStaffExportHistory({
    required List<Map<String, dynamic>> cartItems,
    required Map<String, dynamic> staffInfo,
  }) async {
    if (cartItems.isEmpty) return;
    final receiptNumber = 'XK-${DateTime.now().millisecondsSinceEpoch}';
    final batchesForLog = cartItems.map((item) {
      return {
        'batch_number': item['batchNumber'],
        'products': [
          {
            'product_id': item['productId'],
            'product_name': item['productName'],
            'category_id': item['categoryId'] ?? '',
            'category_name': item['categoryName'] ?? '',
            'quantity': item['exportQty'],
            'old_quantity': item['oldQty'],
            'new_quantity': item['newQty'],
            'mfg_date': item['mfgDate'],
            'exp_date': item['expDate'],
          },
        ],
      };
    }).toList();
    final totalExport = cartItems.fold<int>(0, (sum, item) {
      final qty = item['exportQty'];
      if (qty is int) return sum + qty;
      if (qty is num) return sum + qty.toInt();
      return sum;
    });
    await _db.collection('staff_export_logs').add({
      'receipt_number': receiptNumber,
      'staff_id': staffInfo['id'] ?? null,
      'staff_name': staffInfo['name'] ?? 'Nhân viên',
      'staff_email': staffInfo['email'] ?? '',
      'staff_phone': staffInfo['phone'] ?? '',
      'staff_role': staffInfo['role'] ?? 'staff',
      'batches': batchesForLog,
      'total_export': totalExport,
      'created_at': FieldValue.serverTimestamp(),
      'exported_at': FieldValue.serverTimestamp(),
    });
  }

  //  Lấy lịch sử xuất kho của mình
  Future<List<Map<String, dynamic>>> getStaffExportLogs() async {
    final snap = await _db
        .collection('staff_export_logs')
        .orderBy('exported_at', descending: true)
        .get();
    return snap.docs.map((d) {
      final data = d.data();
      return {'id': d.id, ...data};
    }).toList();
  }

  //  Lấy chi tiết một phiếu xuất kho
  Future<Map<String, dynamic>?> getStaffExportLogById(String id) async {
    final doc = await _db.collection('staff_export_logs').doc(id).get();
    if (!doc.exists) return null;
    return {'id': doc.id, ...doc.data()!};
  }

  //  Gửi yêu cầu nhập thêm hàng
  Future<void> sendImportRequest({
    required String productName,
    required int quantity,
    required String staffName,
    required String staffEmail,
  }) async {
    await _db.collection('import_requests').add({
      'product_name': productName,
      'quantity': quantity,
      'status': 'Đang chờ duyệt',
      'staff_name': staffName,
      'staff_email': staffEmail,
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  //  Xem danh sách yêu cầu nhập hàng
  Future<List<Map<String, dynamic>>> getImportRequests() async {
    final snap = await _db
        .collection('import_requests')
        .orderBy('created_at', descending: true)
        .get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }
}

class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();
  GoogleAuthClient(this._headers);
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _client.send(request..headers.addAll(_headers));
}
