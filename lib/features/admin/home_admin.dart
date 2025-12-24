import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/current_user.dart';
import '../chat/chat_list.dart';
import 'add_stock_screen.dart';
import 'notification_list_screen.dart';

class HomeAdminScreen extends StatefulWidget {
  const HomeAdminScreen({super.key});

  @override
  State<HomeAdminScreen> createState() => _HomeAdminScreenState();
}

class _HomeAdminScreenState extends State<HomeAdminScreen>
    with TickerProviderStateMixin {
  bool _hasNewFeedback = false;
  Map<String, bool> _chatUnreadStatus = {};

  bool _isFeedbackPressed = false;
  bool _isAddStockPressed = false;

  late AnimationController _gradientController;

  // Thông báo
  int _unreadNotificationCount = 0;
  bool _hasNewNotifications = false;
  late AnimationController _bellController;
  Animation<double>? _bellAnimation;
  int get unreadNotificationCount => _unreadNotificationCount;
  @override
  void initState() {
    super.initState();
    _loadData();

    // Gradient animation
    _gradientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    // Bell shake animation
    _bellController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _bellAnimation = Tween<double>(begin: -0.05, end: 0.05).animate(
      CurvedAnimation(parent: _bellController, curve: Curves.easeInOut),
    );

    _listenForNotifications();
  }

  @override
  void dispose() {
    _gradientController.dispose();
    _bellController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    _listenForNewFeedback();
  }

  void _listenForNewFeedback() {
    FirebaseFirestore.instance.collection('chats').snapshots().listen((
      snapshot,
    ) {
      bool hasUnread = false;
      final Map<String, bool> updatedStatus = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final users = List<String>.from(data['users'] ?? []);
        final lastSender = data['lastSenderId'] ?? '';
        final lastMessage = data['lastMessage'] ?? '';

        if (!users.contains(CurrentUser.chatIdString)) continue;

        final isUnread =
            lastSender != CurrentUser.chatIdString &&
            lastSender.startsWith('staff_') &&
            lastMessage.isNotEmpty;

        updatedStatus[doc.id] = isUnread;
        if (isUnread) hasUnread = true;
      }

      if (mounted) {
        setState(() {
          _chatUnreadStatus = updatedStatus;
          _hasNewFeedback = hasUnread;
        });
      }
    });
  }

  void _listenForNotifications() {
    if (CurrentUser.id == null || CurrentUser.id!.isEmpty) {
      return;
    }

    FirebaseFirestore.instance
        .collection('admin_web_logins')
        .where('adminId', isEqualTo: CurrentUser.id)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen(
          (snapshot) {
            int unreadCount = 0;
            for (var doc in snapshot.docs) {
              final data = doc.data();
              if (data['isRead'] == false || data['isRead'] == null) {
                unreadCount++;
              }
            }

            print(
              "[NOTI] Total logs: ${snapshot.docs.length}, Unread: $unreadCount",
            );

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
          },
          onError: (error) {
            print("[NOTI] Error: $error");
          },
        );
  }

  Future<void> _openChatList(BuildContext context) async {
    setState(() => _hasNewFeedback = false);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatListScreen(unreadMap: _chatUnreadStatus),
      ),
    );
  }

  Future<void> _openAddStockScreen() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddStockScreen()),
    );
    _loadData();
  }

  void _openNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationListScreen()),
    ).then((_) {
      // ← THÊM DÒNG NÀY: Refresh khi quay lại từ trang list
      _listenForNotifications();
    });
  }

  Widget _buildAnimatedGradientCard({
    required Widget child,
    required VoidCallback onTap,
    required bool isPressed,
    required Function(bool) setPressed,
    required List<Color> gradientColors,
  }) {
    return GestureDetector(
      onTapDown: (_) => setPressed(true),
      onTapUp: (_) {
        setPressed(false);
        onTap();
      },
      onTapCancel: () => setPressed(false),
      child: AnimatedBuilder(
        animation: _gradientController,
        builder: (context, _) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: isPressed
                  ? []
                  : [
                      const BoxShadow(
                        color: Colors.black12,
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
              gradient: LinearGradient(
                begin: Alignment(-1 + _gradientController.value * 2, 0),
                end: Alignment(1 + _gradientController.value * 2, 1),
                colors: gradientColors,
              ),
            ),
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = CurrentUser.fullname ?? "Admin";

    return Scaffold(
      appBar: AppBar(
        title: const Text("Trang chủ Admin"),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            onPressed: _openNotifications,
            icon: Stack(
              children: [
                AnimatedBuilder(
                  animation: _bellAnimation ?? _gradientController,
                  builder: (context, child) {
                    final angle = _hasNewNotifications
                        ? (_bellAnimation?.value ?? 0)
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
              Row(
                children: [
                  const CircleAvatar(
                    radius: 35,
                    backgroundColor: Colors.blueAccent,
                    child: Icon(
                      Icons.admin_panel_settings,
                      color: Colors.white,
                      size: 32,
                    ),
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
                          "Chúc bạn một ngày làm việc năng suất!",
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

              _buildAnimatedGradientCard(
                isPressed: _isFeedbackPressed,
                setPressed: (v) => setState(() => _isFeedbackPressed = v),
                onTap: () => _openChatList(context),
                gradientColors: [
                  Colors.orange.shade200,
                  Colors.orangeAccent,
                  Colors.deepOrange.shade200,
                ],
                child: Row(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const CircleAvatar(
                          radius: 26,
                          backgroundColor: Colors.orange,
                          child: Icon(Icons.forum, color: Colors.white),
                        ),
                        if (_hasNewFeedback)
                          const Positioned(
                            top: -2,
                            right: -2,
                            child: Icon(
                              Icons.brightness_1,
                              size: 12,
                              color: Colors.red,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    const Text(
                      "Phản hồi từ nhân viên",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              _buildAnimatedGradientCard(
                isPressed: _isAddStockPressed,
                setPressed: (v) => setState(() => _isAddStockPressed = v),
                onTap: _openAddStockScreen,
                gradientColors: [
                  Colors.green.shade200,
                  Colors.lightGreenAccent,
                  Colors.greenAccent,
                ],
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 26,
                      backgroundColor: Colors.green,
                      child: Icon(Icons.add_shopping_cart, color: Colors.white),
                    ),
                    const SizedBox(width: 16),
                    const Text(
                      "Nhập hàng",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
