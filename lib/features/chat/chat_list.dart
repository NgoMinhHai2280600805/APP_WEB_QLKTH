import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/current_user.dart';
import '../../core/services/chat_service.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  final Map<String, bool>? unreadMap; // dữ liệu unread truyền từ HomeAdmin

  const ChatListScreen({super.key, this.unreadMap});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final ChatService _chatService = ChatService();
  Map<String, bool> _newMessageFlags = {};

  @override
  void initState() {
    super.initState();
    _newMessageFlags = widget.unreadMap ?? {};
    _listenForChatUpdates();
  }

  /// 🔹 Lắng nghe thay đổi trong collection 'chats'
  void _listenForChatUpdates() {
    FirebaseFirestore.instance.collection('chats').snapshots().listen((
      snapshot,
    ) {
      final Map<String, bool> updatedFlags = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final users = List<String>.from(data['users'] ?? []);
        final lastSender = data['lastSenderId'] ?? '';
        final lastMessage = data['lastMessage'] ?? '';

        if (!users.contains(CurrentUser.chatIdString)) continue;

        final isFromStaff =
            lastSender != CurrentUser.chatIdString &&
            lastSender.startsWith('staff_');
        updatedFlags[doc.id] = isFromStaff && lastMessage.isNotEmpty;
      }

      if (mounted) setState(() => _newMessageFlags = updatedFlags);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Tin nhắn với nhân viên")),
      body: StreamBuilder<QuerySnapshot>(
        stream: _chatService.getChatList(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text("Lỗi: ${snapshot.error}"));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("Chưa có cuộc trò chuyện nào"));
          }

          final chats = snapshot.data!.docs;

          return ListView.separated(
            itemCount: chats.length,
            separatorBuilder: (_, __) =>
                const Divider(indent: 16, endIndent: 16),
            itemBuilder: (context, index) {
              final chat = chats[index];
              final users = List<String>.from(chat['users']);
              final receiverId = users.firstWhere(
                (id) => id != CurrentUser.chatIdString,
                orElse: () => 'unknown',
              );

              final receiverName = receiverId.startsWith('staff_')
                  ? 'Nhân viên ${receiverId.replaceFirst('staff_', '')}'
                  : receiverId;

              final lastMessage = chat['lastMessage'] ?? '';
              final isNew = _newMessageFlags[chat.id] ?? false;

              return ListTile(
                leading: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.blueAccent,
                      child: Text(
                        receiverName.substring(0, 1).toUpperCase(),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    if (isNew)
                      const Positioned(
                        top: -2,
                        right: -2,
                        child: Icon(Icons.circle, color: Colors.red, size: 10),
                      ),
                  ],
                ),
                title: Text(
                  receiverName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                subtitle: Text(
                  lastMessage,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () {
                  setState(() => _newMessageFlags[chat.id] = false);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        receiverId: receiverId,
                        receiverName: receiverName,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
