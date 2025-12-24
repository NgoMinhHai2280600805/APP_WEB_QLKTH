import 'package:app_qlkth_nhom8/features/common/product_xuat_kho.dart';
import 'package:flutter/material.dart';
import '../../core/services/product_service.dart';
import '../../widgets/drawer.dart';
//import '../common/product_detail.dart';
import '../../../core/current_user.dart';
import '../../../main.dart';
import 'lich_su_xuat_kho.dart';
import 'yeu_cau_nhap_kho.dart';
import 'quick_export_screen.dart';
//import 'dart:io';
import '../common/export_popup.dart';
import 'package:url_launcher/url_launcher.dart';

class XuatKhoScreen extends StatefulWidget {
  const XuatKhoScreen({super.key});

  @override
  State<XuatKhoScreen> createState() => _XuatKhoScreenState();
}

// --- Hàm build badge dựa trên số lượng ---
Widget _buildQuantityBadge(int quantity) {
  if (quantity == 0) {
    return _AnimatedStatusBadge(
      text: "Hết hàng",
      color: Colors.red,
      shake: true,
      bubble: true,
    );
  } else if (quantity < 10) {
    return _AnimatedStatusBadge(
      text: "Sắp hết hàng",
      color: Colors.orange,
      shake: true,
      bubble: true,
    );
  }
  return const SizedBox.shrink();
}

// --- Widget badge động ---
class _AnimatedStatusBadge extends StatefulWidget {
  final String text;
  final Color color;
  final bool shake;
  final bool bubble;

  const _AnimatedStatusBadge({
    required this.text,
    required this.color,
    this.shake = false,
    this.bubble = false,
  });

  @override
  State<_AnimatedStatusBadge> createState() => _AnimatedStatusBadgeState();
}

class _AnimatedStatusBadgeState extends State<_AnimatedStatusBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _shakeAnim;
  late Animation<double> _bubbleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _shakeAnim = Tween<double>(
      begin: -2,
      end: 2,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticIn));

    _bubbleAnim = Tween<double>(
      begin: 0,
      end: 6,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        double offsetX = widget.shake ? _shakeAnim.value : 0;
        double bubbleOffset = widget.bubble ? _bubbleAnim.value : 0;

        return Transform.translate(
          offset: Offset(offsetX, 0),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: widget.color.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withOpacity(0.5),
                      blurRadius: 4,
                      offset: const Offset(2, 2),
                    ),
                  ],
                ),
                child: Text(
                  widget.text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              if (widget.bubble)
                Positioned(
                  top: -bubbleOffset,
                  right: -bubbleOffset,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.8),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _XuatKhoScreenState extends State<XuatKhoScreen> {
  final _firebaseService = ProductService();

  List<Map<String, dynamic>> _categories = [];
  Map<String, List<Map<String, dynamic>>> _categoryProducts = {};
  String _searchQuery = '';
  String? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final categories = await _firebaseService.getCategories();
    final products = await _firebaseService.getProducts();

    final grouped = <String, List<Map<String, dynamic>>>{};
    for (var c in categories) {
      final categoryId = c['id'].toString();
      grouped[categoryId] = products
          .where((p) => (p['category_id']?.toString() ?? '') == categoryId)
          .toList();
    }

    setState(() {
      _categories = categories;
      _categoryProducts = grouped;
    });
  }

  Future<void> openExportPage() async {
    final url = Uri.parse(
      "https://6a5ebf5eb173.ngrok-free.app/employee/export",
    );

    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception("Không mở được trang nhập hàng");
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isAdmin = CurrentUser.role == "admin";

    return Scaffold(
      drawer: const CustomDrawer(),
      drawerScrimColor: Colors.black.withOpacity(0.6),
      appBar: AppBar(
        title: const Text("Xuất kho"),
        backgroundColor: Colors.blue,
        automaticallyImplyLeading: false,

        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (_) => const HomePage(initialIndex: 0),
              ),
              (route) => false,
            );
          },
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) async {
              if (value == 'history') {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const LichSuXuatKhoScreen(),
                  ),
                );
                if (mounted) _loadData();
              } else if (value == 'export_web') {
                await openExportPage();
                if (mounted) _loadData();
              } else if (value == 'requests') {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const YeuCauNhapKhoScreen(),
                  ),
                );
                if (mounted) _loadData();
              } else if (value == 'quick_export') {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const QuickExportScreen()),
                );
                if (mounted) _loadData();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'export_web',
                child: Row(
                  children: [
                    Icon(Icons.history, color: Colors.blue),
                    SizedBox(width: 8),
                    Text("Xuất kho (web)"),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'history',
                child: Row(
                  children: [
                    Icon(Icons.history, color: Colors.blue),
                    SizedBox(width: 8),
                    Text("Lịch sử xuất kho"),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'requests',
                child: Row(
                  children: [
                    Icon(Icons.assignment_add, color: Colors.green),
                    SizedBox(width: 8),
                    Text("Yêu cầu nhập kho"),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'quick_export',
                child: Row(
                  children: [
                    Icon(Icons.local_shipping, color: Colors.orange),
                    SizedBox(width: 8),
                    Text("Xuất kho nhanh"),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: isAdmin
          ? const Center(
              child: Text(
                "Admin không sử dụng chức năng này!",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            )
          : _categories.isEmpty
          ? const Center(child: Text("Chưa có danh mục hoặc sản phẩm"))
          : RefreshIndicator(
              onRefresh: _loadData,
              child: Column(
                children: [
                  // 🔍 Ô tìm kiếm
                  // 🔍 Thanh tìm kiếm (7) + 🔽 Dropdown (3)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        // Ô tìm kiếm — chiếm 6 phần
                        Expanded(
                          flex: 6,
                          child: Container(
                            height: 45,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: TextField(
                              decoration: InputDecoration(
                                hintText: "Tìm sản phẩm...",
                                prefixIcon: const Icon(Icons.search, size: 20),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                              ),
                              onChanged: (value) {
                                setState(
                                  () => _searchQuery = value.toLowerCase(),
                                );
                              },
                            ),
                          ),
                        ),

                        const SizedBox(width: 10),

                        // Dropdown — chiếm 3 phần
                        Expanded(
                          flex: 4,
                          child: Container(
                            height: 45,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedCategoryId,
                                icon: const Icon(Icons.arrow_drop_down),
                                isExpanded: true, // để text không bị cắt
                                items: [
                                  const DropdownMenuItem(
                                    value: null,
                                    child: Text("Tất cả"),
                                  ),
                                  ..._categories.map(
                                    (c) => DropdownMenuItem(
                                      value: c['id'].toString(),
                                      child: Text(c['name']),
                                    ),
                                  ),
                                ],
                                onChanged: (val) =>
                                    setState(() => _selectedCategoryId = val),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // 🔹 Danh sách sản phẩm theo danh mục
                  Expanded(
                    //hàm chặn co giãn nd
                    child: ScrollConfiguration(
                      behavior: const ScrollBehavior().copyWith(
                        overscroll: false, // tắt hiệu ứng co giãn
                        physics:
                            const ClampingScrollPhysics(), // khóa cứng scroll
                      ),

                      //
                      child: ListView.builder(
                        itemCount: _categories.length,
                        padding: const EdgeInsets.all(8),
                        itemBuilder: (_, index) {
                          final cat = _categories[index];
                          final prods =
                              _categoryProducts[cat['id'].toString()] ?? [];

                          // Lọc theo danh mục và tìm kiếm
                          final visible = prods.where((p) {
                            final name =
                                p['name']?.toString().toLowerCase() ?? '';
                            final matchSearch =
                                _searchQuery.isEmpty ||
                                name.contains(_searchQuery);
                            final matchCat =
                                _selectedCategoryId == null ||
                                p['category_id'].toString() ==
                                    _selectedCategoryId;
                            return matchSearch && matchCat;
                          }).toList();

                          if (visible.isEmpty) return const SizedBox.shrink();

                          return Card(
                            elevation: 3,
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    cat['name'] ?? '',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blueAccent,
                                    ),
                                  ),
                                  if ((cat['description'] ?? '')
                                      .toString()
                                      .trim()
                                      .isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 10,
                                      ),
                                      child: Text(
                                        cat['description'],
                                        style: const TextStyle(
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ),

                                  // --- Lưới sản phẩm ---
                                  GridView.builder(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount: visible.length,
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 2,
                                          mainAxisSpacing: 12,
                                          crossAxisSpacing: 12,
                                          childAspectRatio: 3 / 4,
                                        ),
                                    itemBuilder: (_, i) {
                                      final p = visible[i];
                                      return InkWell(
                                        onTap: () async {
                                          await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  ProductXuatKhoScreen(
                                                    product: p,
                                                    onUpdate: _loadData,
                                                  ),
                                            ),
                                          );
                                          _loadData();
                                        },

                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black12,
                                                blurRadius: 4,
                                                offset: const Offset(2, 2),
                                              ),
                                            ],
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.all(8),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Expanded(
                                                  child: Container(
                                                    width: double.infinity,
                                                    decoration: BoxDecoration(
                                                      color:
                                                          Colors.grey.shade300,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                      image:
                                                          (p['image'] != null &&
                                                              p['image']
                                                                  .toString()
                                                                  .isNotEmpty)
                                                          ? DecorationImage(
                                                              image:
                                                                  NetworkImage(
                                                                    p['image'],
                                                                  ),
                                                              fit: BoxFit.cover,
                                                            )
                                                          : null,
                                                    ),
                                                    child:
                                                        (p['image'] == null ||
                                                            p['image']
                                                                .toString()
                                                                .isEmpty)
                                                        ? const Icon(
                                                            Icons.image,
                                                            size: 50,
                                                            color: Colors.grey,
                                                          )
                                                        : null,
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  p['name'] ?? '',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                  ),
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                Text(
                                                  "SL: ${p['quantity'] ?? 0}",
                                                  style: const TextStyle(
                                                    color: Colors.black54,
                                                  ),
                                                ),
                                                // --- Badge động ---
                                                _buildQuantityBadge(
                                                  p['quantity'] ?? 0,
                                                ),

                                                Text(
                                                  "Giá: ${p['price']}₫",
                                                  style: const TextStyle(
                                                    color: Colors.green,
                                                  ),
                                                ),
                                                Align(
                                                  alignment:
                                                      Alignment.centerRight,
                                                  child: PopupMenuButton<String>(
                                                    onSelected: (value) async {
                                                      if (value == 'xuatkho') {
                                                        ExportPopup.open(
                                                          context: context,
                                                          product: p,
                                                          onUpdated: _loadData,
                                                        );
                                                      } else if (value ==
                                                          'yeucaunhap') {
                                                        ScaffoldMessenger.of(
                                                          context,
                                                        ).showSnackBar(
                                                          const SnackBar(
                                                            content: Text(
                                                              "Đã gửi yêu cầu nhập kho cho quản trị viên.",
                                                            ),
                                                          ),
                                                        );
                                                      } else if (value ==
                                                          'baosailech') {
                                                        ScaffoldMessenger.of(
                                                          context,
                                                        ).showSnackBar(
                                                          const SnackBar(
                                                            content: Text(
                                                              "Đã gửi báo cáo sai lệch tồn kho.",
                                                            ),
                                                          ),
                                                        );
                                                      }
                                                    },
                                                    itemBuilder: (context) => const [
                                                      PopupMenuItem(
                                                        value: 'xuatkho',
                                                        child: Row(
                                                          children: [
                                                            Icon(
                                                              Icons
                                                                  .local_shipping_outlined,
                                                              color:
                                                                  Colors.orange,
                                                            ),
                                                            SizedBox(width: 8),
                                                            Text("Xuất kho"),
                                                          ],
                                                        ),
                                                      ),
                                                      PopupMenuItem(
                                                        value: 'yeucaunhap',
                                                        child: Row(
                                                          children: [
                                                            Icon(
                                                              Icons
                                                                  .add_box_outlined,
                                                              color:
                                                                  Colors.green,
                                                            ),
                                                            SizedBox(width: 8),
                                                            Text(
                                                              "Yêu cầu nhập kho",
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      PopupMenuItem(
                                                        value: 'baosailech',
                                                        child: Row(
                                                          children: [
                                                            Icon(
                                                              Icons
                                                                  .warning_amber,
                                                              color: Colors.red,
                                                            ),
                                                            SizedBox(width: 8),
                                                            Text(
                                                              "Báo sai lệch tồn kho",
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
