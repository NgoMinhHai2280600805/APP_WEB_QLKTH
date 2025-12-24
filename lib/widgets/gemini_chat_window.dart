// lib/widgets/gemini_chat_window.dart

import 'package:flutter/material.dart';
import '../../core/services/gemini_service.dart';

class GeminiChatWindow extends StatefulWidget {
  final String? statsContext;
  final bool isFromThongKe;
  final VoidCallback? onClose;

  const GeminiChatWindow({
    super.key,
    this.statsContext,
    this.isFromThongKe = false,
    this.onClose,
  });

  @override
  State<GeminiChatWindow> createState() => _GeminiChatWindowState();
}

class _GeminiChatWindowState extends State<GeminiChatWindow> {
  final List<Map<String, String>> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController =
      ScrollController(); // ← THÊM DÒNG NÀY
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.isFromThongKe) {
      _messages.add({
        'role': 'ai',
        'text':
            'Bạn cần hỗ trợ gì về thống kê kho hàng hôm nay không? 😊\nMình có thể giúp xem doanh thu, tồn kho, lô sắp hết hạn đây!',
      });
    }

    // Cuộn xuống cuối khi mở chat lần đầu (nếu có tin chào)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose(); // ← Giải phóng controller
    super.dispose();
  }

  // Hàm cuộn xuống cuối danh sách
  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _sendMessage() async {
    if (_controller.text.trim().isEmpty) return;

    final userMessage = _controller.text.trim();
    setState(() {
      _messages.add({'role': 'user', 'text': userMessage});
      _isLoading = true;
    });
    _controller.clear();
    _focusNode.unfocus();

    // Cuộn xuống ngay sau khi thêm tin nhắn người dùng
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });

    try {
      final fullPrompt =
          '''
Bạn là AI trợ lý quản lý kho hàng thông minh, trả lời bằng tiếng Việt, ngắn gọn, chính xác.
Luôn sử dụng dữ liệu thống kê hiện tại để trả lời, không đoán mò.

${widget.statsContext ?? 'Không có dữ liệu thống kê hiện tại.'}

Câu hỏi của người dùng: $userMessage
''';

      final stream = GeminiService().streamContent(fullPrompt);
      String aiResponse = '';

      setState(() {
        _messages.add({'role': 'ai', 'text': ''});
      });

      // Cuộn xuống khi bắt đầu nhận phản hồi từ AI
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });

      await for (final chunk in stream) {
        final text = chunk.text ?? '';
        aiResponse += text;
        setState(() {
          _messages.last['text'] = aiResponse;
        });

        // Cuộn xuống mỗi khi có chunk mới (đang streaming)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom();
        });
      }
    } catch (e) {
      setState(() {
        _messages.last['text'] = 'Lỗi kết nối Gemini: $e';
      });
      _scrollToBottom();
    } finally {
      setState(() => _isLoading = false);
      _scrollToBottom(); // Cuộn lần cuối khi xong
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _focusNode.unfocus();
      },
      behavior: HitTestBehavior.translucent,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                const Text(
                  'AI Trợ Lý Kho Hàng',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple,
                  ),
                ),
                const Spacer(),
                if (widget.onClose != null)
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: widget.onClose,
                    tooltip: 'Đóng',
                  ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1),

          // Danh sách tin nhắn - THÊM ScrollController
          Expanded(
            child: ListView.builder(
              controller: _scrollController, // ← QUAN TRỌNG: gắn controller
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _isLoading) {
                  return const Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: CircularProgressIndicator(
                        color: Colors.purple,
                        strokeWidth: 3,
                      ),
                    ),
                  );
                }

                final msg = _messages[index];
                final isUser = msg['role'] == 'user';

                return Align(
                  alignment: isUser
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.all(14),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.purple : Colors.grey[200],
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: SelectableText(
                      msg['text'] ?? '',
                      style: TextStyle(
                        color: isUser ? Colors.white : Colors.black87,
                        fontSize: 16,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Input area
          Container(
            color: Colors.white,
            padding: EdgeInsets.only(
              left: 12,
              right: 12,
              top: 12,
              bottom: MediaQuery.of(context).viewInsets.bottom + 12,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    decoration: InputDecoration(
                      hintText: 'Hỏi về doanh thu, tồn kho, sản phẩm...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 10),
                FloatingActionButton(
                  mini: true,
                  backgroundColor: Colors.purple,
                  onPressed: _isLoading ? null : _sendMessage,
                  child: _isLoading
                      ? const CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        )
                      : const Icon(Icons.send, size: 20),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
