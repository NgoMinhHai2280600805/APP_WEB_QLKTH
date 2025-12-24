import 'package:app_qlkth_nhom8/features/staff/yeu_cau_nhap_kho.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/current_user.dart';
import '../chat/chat_screen.dart';
import 'notification_list_screen.dart'; // Đảm bảo tên file đúng (StaffNotificationListScreen)

class HomeStaffScreen extends StatefulWidget {
  const HomeStaffScreen({super.key});

  @override
  State<HomeStaffScreen> createState() => _HomeStaffScreenState();
}

class _HomeStaffScreenState extends State<HomeStaffScreen>
    with TickerProviderStateMixin {
  final String adminId = "admin";
  final String adminName = "Admin";

  // Tin nhắn chat
  bool _hasNewMessage = false;
  Timestamp? _lastSeenMessageTime;

  // Yêu cầu nhập kho
  bool _hasNewRequestUpdate = false;
  Timestamp? _lastSeenRequestTime;

  // Thông báo đăng nhập web
  int _unreadNotificationCount = 0;
  bool _hasNewNotifications = false;
  late AnimationController _bellController;
  Animation<double>? _bellAnimation;
  int get unreadNotificationCount => _unreadNotificationCount;
  @override
  void initState() {
    super.initState();
    _loadData();

    // Animation cho chuông rung
    _bellController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _bellAnimation = Tween<double>(begin: -0.05, end: 0.05).animate(
      CurvedAnimation(parent: _bellController, curve: Curves.easeInOut),
    );

    _listenForWebNotifications();
  }

  @override
  void dispose() {
    _bellController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    _listenForMessages();
    _listenForImportRequestUpdates();
    _listenForWebNotifications();
  }

  // Lắng nghe tin nhắn mới từ Admin
  void _listenForMessages() {
    final myId = CurrentUser.chatIdString;
    final chatId = (myId.compareTo(adminId) < 0)
        ? '${myId}_$adminId'
        : '${adminId}_$myId';

    FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
          if (snapshot.docs.isEmpty) return;
          final msg = snapshot.docs.first.data();
          final senderId = msg['senderId'];
          final timestamp = msg['timestamp'] as Timestamp?;

          final hasNew =
              senderId == adminId &&
              (_lastSeenMessageTime == null ||
                  (timestamp != null &&
                      timestamp.compareTo(_lastSeenMessageTime!) > 0));

          if (mounted && hasNew != _hasNewMessage) {
            setState(() => _hasNewMessage = hasNew);
          }
        });
  }

  // Lắng nghe cập nhật yêu cầu nhập kho
  void _listenForImportRequestUpdates() {
    FirebaseFirestore.instance
        .collection('import_requests')
        .where('staff_email', isEqualTo: CurrentUser.email)
        .snapshots()
        .listen((snapshot) {
          bool hasUpdate = false;
          for (var doc in snapshot.docs) {
            final data = doc.data();
            final status = (data['status'] ?? '').toString().toLowerCase();
            final createdAt = (data['created_at'] as Timestamp?)?.toDate();
            final updatedAt = (data['updated_at'] as Timestamp?)?.toDate();

            if ((status == 'đã duyệt' || status == 'từ chối') &&
                updatedAt != null &&
                (createdAt == null || updatedAt.isAfter(createdAt)) &&
                (_lastSeenRequestTime == null ||
                    updatedAt.isAfter(_lastSeenRequestTime!.toDate()))) {
              hasUpdate = true;
              break;
            }
          }

          if (mounted && hasUpdate != _hasNewRequestUpdate) {
            setState(() => _hasNewRequestUpdate = hasUpdate);
          }
        });
  }

  // Lắng nghe thông báo đăng nhập web
  void _listenForWebNotifications() {
    if (CurrentUser.id == null || CurrentUser.id!.isEmpty) return;

    FirebaseFirestore.instance
        .collection('staff_web_logins')
        .where('staffId', isEqualTo: CurrentUser.id)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) {
          int unreadCount = 0;
          for (var doc in snapshot.docs) {
            final data = doc.data();
            if (data['isRead'] == false || data['isRead'] == null) {
              unreadCount++;
            }
          }

          if (mounted) {
            setState(() {
              _unreadNotificationCount = unreadCount;
              _hasNewNotifications = unreadCount > 0;

              if (_hasNewNotifications) {
                _bellController.repeat(reverse: true);
              } else {
                _bellController.stop();
                _bellController.reset();
              }
            });
          }
        });
  }

  // Mở trang danh sách thông báo đăng nhập web
  void _openWebNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const StaffNotificationListScreen()),
    ).then((_) {
      // Khi quay lại từ trang thông báo → refresh lại badge (giống admin)
      _listenForWebNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    final name = CurrentUser.fullname ?? "Nhân viên";

    return Scaffold(
      appBar: AppBar(
        title: const Text("Trang chủ nhân viên"),
        backgroundColor: Colors.blue,
        actions: [
          // Icon chuông thông báo (giống hệt admin)
          IconButton(
            onPressed: _openWebNotifications,
            icon: Stack(
              children: [
                AnimatedBuilder(
                  animation: _bellAnimation!,
                  builder: (context, child) {
                    final angle = _hasNewNotifications
                        ? _bellAnimation!.value
                        : 0.0;
                    return Transform.rotate(
                      angle: angle,
                      child: const Icon(Icons.notifications, size: 28),
                    );
                  },
                ),
                if (_hasNewNotifications)
                  const Positioned(
                    right: 4,
                    top: 4,
                    child: Icon(
                      Icons.brightness_1,
                      size: 10,
                      color: Colors.red,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),

              // Lời chào
              Row(
                children: [
                  const CircleAvatar(
                    radius: 35,
                    backgroundColor: Colors.blueAccent,
                    child: Icon(Icons.person, color: Colors.white, size: 32),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Xin chào, $name 👋",
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Chúc bạn một ngày làm việc hiệu quả!",
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 40),

              // Chat với Admin
              GestureDetector(
                onTap: () async {
                  setState(() {
                    _hasNewMessage = false;
                    _lastSeenMessageTime = Timestamp.now();
                  });
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        receiverId: adminId,
                        receiverName: adminName,
                      ),
                    ),
                  );
                },
                child: _buildTile(
                  icon: Icons.chat_bubble,
                  title: "Chat với Admin",
                  color: Colors.blue,
                  showDot: _hasNewMessage,
                ),
              ),

              // Yêu cầu nhập kho
              GestureDetector(
                onTap: () async {
                  setState(() {
                    _hasNewRequestUpdate = false;
                    _lastSeenRequestTime = Timestamp.now();
                  });
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const YeuCauNhapKhoScreen(),
                    ),
                  );
                },
                child: _buildTile(
                  icon: Icons.inventory_2,
                  title: "Yêu cầu nhập kho",
                  color: Colors.green,
                  showDot: _hasNewRequestUpdate,
                ),
              ),

              // → ĐÃ BỎ MỤC "Thông báo đăng nhập web" Ở ĐÂY (giống admin)
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTile({
    required IconData icon,
    required String title,
    required Color color,
    bool showDot = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(top: 20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: color,
                child: Icon(icon, color: Colors.white),
              ),
              if (showDot)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}
