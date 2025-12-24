import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/product_service.dart';

class ExpiredBatchesScreen extends StatefulWidget {
  const ExpiredBatchesScreen({super.key});

  @override
  State<ExpiredBatchesScreen> createState() => _ExpiredBatchesScreenState();
}

class _ExpiredBatchesScreenState extends State<ExpiredBatchesScreen> {
  final ProductService _productService = ProductService();

  // Cấu trúc: categoryId -> { categoryName, products: [ {productName, batches: [...] } ] }
  Map<String, dynamic> _groupedData = {};
  bool _isLoading = true;

  bool _showExpired = true;
  static const int nearExpiryDays = 30;

  @override
  void initState() {
    super.initState();
    _loadBatches();
  }

  Future<void> _loadBatches() async {
    setState(() => _isLoading = true);
    try {
      // Lấy danh mục
      final categories = await _productService.getCategories();
      final Map<String, String> categoryNameMap = {
        for (var cat in categories)
          cat['id'] as String: cat['name'] as String? ?? 'Không phân loại',
      };

      // Lấy sản phẩm
      final products = await _productService.getProducts();

      final now = DateTime.now();

      // Nhóm theo danh mục → sản phẩm → lô
      final Map<String, Map<String, dynamic>> groupedByCategory = {};

      for (var product in products) {
        final productId = product['id'] as String;
        final productName = product['name'] as String? ?? 'Không tên';
        final categoryId = product['category_id'] as String? ?? 'uncategorized';
        final categoryName = categoryNameMap[categoryId] ?? 'Không phân loại';

        final batches = await _productService.getProductBatches(productId);
        final List<Map<String, dynamic>> validBatches = [];

        for (var batch in batches) {
          // SỬA LỖI: quantity có thể là num (int hoặc double)
          final int quantity = (batch['quantity'] as num?)?.toInt() ?? 0;
          if (quantity <= 0) continue;

          final expiryField = batch['exp_date'];
          DateTime? expiryDate;

          if (expiryField is Timestamp) {
            expiryDate = expiryField.toDate();
          } else if (expiryField is String && expiryField.isNotEmpty) {
            if (expiryField.contains('/')) {
              try {
                expiryDate = DateFormat('dd/MM/yyyy').parseStrict(expiryField);
              } catch (_) {}
            }
            if (expiryDate == null && expiryField.contains('-')) {
              try {
                expiryDate = DateTime.parse(expiryField);
              } catch (_) {}
            }
          }

          if (expiryDate == null) continue;

          final daysLeft = expiryDate.difference(now).inDays;
          final isExpired = daysLeft < 0;

          if (isExpired || (!isExpired && daysLeft <= nearExpiryDays)) {
            validBatches.add({
              'batch_number': batch['batch_number'] ?? '-',
              'quantity': quantity,
              'mfg_date': batch['mfg_date'],
              'expiry_date': expiryDate,
              'days_left': daysLeft,
              'is_expired': isExpired,
            });
          }
        }

        if (validBatches.isNotEmpty) {
          groupedByCategory.putIfAbsent(
            categoryId,
            () => {'category_name': categoryName, 'products': []},
          );

          groupedByCategory[categoryId]!['products'].add({
            'product_name': productName,
            'batches': validBatches,
          });
        }
      }

      // Sắp xếp danh mục và sản phẩm
      final sortedEntries = groupedByCategory.entries.toList()
        ..sort(
          (a, b) =>
              a.value['category_name'].compareTo(b.value['category_name']),
        );

      final Map<String, dynamic> finalGrouped = {};
      for (var entry in sortedEntries) {
        final products = entry.value['products'] as List;
        products.sort(
          (a, b) => (a['product_name'] as String).compareTo(
            b['product_name'] as String,
          ),
        );
        finalGrouped[entry.key] = {
          'category_name': entry.value['category_name'],
          'products': products,
        };
      }

      setState(() {
        _groupedData = finalGrouped;
      });
    } catch (e) {
      debugPrint('Lỗi tải lô hết hạn: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi tải dữ liệu: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatDate(dynamic dateField) {
    if (dateField == null) return '-';
    if (dateField is Timestamp) {
      return DateFormat('dd/MM/yyyy').format(dateField.toDate());
    }
    if (dateField is String && dateField.isNotEmpty) {
      return dateField;
    }
    return '-';
  }

  @override
  Widget build(BuildContext context) {
    // Lọc theo tab hiện tại và đếm tổng lô
    final Map<String, dynamic> filteredData = {};
    int totalCount = 0;

    _groupedData.forEach((catId, catData) {
      final List<dynamic> filteredProducts = [];
      for (var prod in catData['products']) {
        final filteredBatches = (prod['batches'] as List)
            .where((b) => _showExpired ? b['is_expired'] : !b['is_expired'])
            .toList();
        if (filteredBatches.isNotEmpty) {
          filteredProducts.add({
            'product_name': prod['product_name'],
            'batches': filteredBatches,
          });
          totalCount += filteredBatches.length;
        }
      }
      if (filteredProducts.isNotEmpty) {
        filteredData[catId] = {
          'category_name': catData['category_name'],
          'products': filteredProducts,
        };
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lô hàng hết hạn & sắp hết hạn'),
        centerTitle: true,
        elevation: 2,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadBatches,
              child: Column(
                children: [
                  // Tab chọn trạng thái
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Trạng thái lô hàng',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment<bool>(
                              value: true,
                              label: Text('Đã hết hạn'),
                              icon: Icon(Icons.error_outline, size: 18),
                            ),
                            ButtonSegment<bool>(
                              value: false,
                              label: Text('Sắp hết hạn'),
                              icon: Icon(Icons.warning_amber_rounded, size: 18),
                            ),
                          ],
                          selected: {_showExpired},
                          onSelectionChanged: (newSelection) {
                            setState(() => _showExpired = newSelection.first);
                          },
                          style: ButtonStyle(
                            backgroundColor: WidgetStateProperty.resolveWith((
                              states,
                            ) {
                              if (states.contains(WidgetState.selected)) {
                                return _showExpired
                                    ? Colors.red[600]
                                    : Colors.orange[600];
                              }
                              return null;
                            }),
                            foregroundColor: WidgetStateProperty.resolveWith((
                              states,
                            ) {
                              if (states.contains(WidgetState.selected))
                                return Colors.white;
                              return null;
                            }),
                            side: WidgetStateProperty.all(
                              BorderSide(color: Colors.grey[400]!),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _showExpired
                              ? 'Có $totalCount lô đã hết hạn hạn sử dụng'
                              : 'Có $totalCount lô sắp hết hạn (còn ≤ $nearExpiryDays ngày)',
                          style: TextStyle(
                            color: _showExpired
                                ? Colors.red[700]
                                : Colors.orange[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Danh sách theo danh mục → sản phẩm → lô
                  Expanded(
                    child: filteredData.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _showExpired
                                      ? Icons.error_outline
                                      : Icons.schedule,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _showExpired
                                      ? 'Không có lô hàng nào đã hết hạn'
                                      : 'Không có lô hàng nào sắp hết hạn',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey[600],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: filteredData.length,
                            itemBuilder: (context, catIndex) {
                              final catEntry = filteredData.entries.elementAt(
                                catIndex,
                              );
                              final categoryName =
                                  catEntry.value['category_name'];
                              final products =
                                  catEntry.value['products'] as List;

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Tiêu đề danh mục
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    color: _showExpired
                                        ? Colors.red[50]
                                        : Colors.orange[50],
                                    child: Text(
                                      categoryName.toUpperCase(),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: _showExpired
                                            ? Colors.red[800]
                                            : Colors.orange[800],
                                      ),
                                    ),
                                  ),

                                  // Các sản phẩm
                                  ...products.map((prod) {
                                    final batches = prod['batches'] as List;

                                    return Card(
                                      elevation: 3,
                                      margin: const EdgeInsets.fromLTRB(
                                        12,
                                        8,
                                        12,
                                        4,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      color: _showExpired
                                          ? Colors.red.withValues(alpha: 0.08)
                                          : Colors.orange.withValues(
                                              alpha: 0.08,
                                            ),
                                      child: ExpansionTile(
                                        title: Text(
                                          prod['product_name'],
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 17,
                                          ),
                                        ),
                                        subtitle: Text('${batches.length} lô'),
                                        childrenPadding:
                                            const EdgeInsets.fromLTRB(
                                              16,
                                              0,
                                              16,
                                              16,
                                            ),
                                        expandedCrossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: batches.map<Widget>((batch) {
                                          final days =
                                              batch['days_left'] as int;
                                          final isExpired =
                                              batch['is_expired'] as bool;

                                          return Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 8,
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                _buildInfoRow(
                                                  Icons.note,
                                                  'Mã lô: ${batch['batch_number']}',
                                                ),
                                                _buildInfoRow(
                                                  Icons.inventory_2,
                                                  'Số lượng còn: ${batch['quantity']}',
                                                ),
                                                _buildInfoRow(
                                                  Icons.calendar_today,
                                                  'NSX: ${_formatDate(batch['mfg_date'])}',
                                                ),
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons.event_available,
                                                      size: 16,
                                                      color: Colors.grey[700],
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      'Hạn sử dụng: ${DateFormat('dd/MM/yyyy').format(batch['expiry_date'])}',
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 8),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                        vertical: 6,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        (isExpired
                                                                ? Colors.red
                                                                : Colors.orange)
                                                            .withValues(
                                                              alpha: 0.2,
                                                            ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          20,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    isExpired
                                                        ? 'Đã hết hạn ${-days} ngày'
                                                        : 'Còn $days ngày',
                                                    style: TextStyle(
                                                      color: isExpired
                                                          ? Colors.red[800]
                                                          : const Color.fromARGB(
                                                              255,
                                                              223,
                                                              106,
                                                              11,
                                                            ),
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ),
                                                if (batch != batches.last)
                                                  const Divider(height: 24),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    );
                                  }).toList(),
                                ],
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(text),
        ],
      ),
    );
  }
}
