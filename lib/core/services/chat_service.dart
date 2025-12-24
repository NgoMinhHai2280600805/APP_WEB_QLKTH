import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/current_user.dart';

class ChatService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Gửi tin nhắn
  Future<void> sendMessage({
    required String receiverId,
    required String message,
  }) async {
    final senderId = CurrentUser.chatIdString;
    final chatId = _getChatId(senderId, receiverId);

    await _db.collection('chats').doc(chatId).collection('messages').add({
      'senderId': senderId,
      'receiverId': receiverId,
      'message': message,
      'timestamp': FieldValue.serverTimestamp(),
    });

    await _db.collection('chats').doc(chatId).set({
      'users': [senderId, receiverId],
      'lastMessage': message,
      'lastTime': FieldValue.serverTimestamp(),
      'lastSenderId': senderId, //
    }, SetOptions(merge: true));
  }

  Stream<QuerySnapshot> getMessages(String receiverId) {
    final senderId = CurrentUser.chatIdString;
    final chatId = _getChatId(senderId, receiverId);
    return _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  Stream<QuerySnapshot> getChatList() {
    final userId = CurrentUser.chatIdString;
    print(" ROLE: ${CurrentUser.role}");
    print(" CHAT ID: ${CurrentUser.chatIdString}");

    return _db
        .collection('chats')
        .where('users', arrayContains: userId)
        .snapshots()
        .handleError((e) {
          print(" Firestore error: $e");
        });
  }

  String _getChatId(String u1, String u2) =>
      (u1.compareTo(u2) < 0) ? '${u1}_$u2' : '${u2}_$u1';
}
