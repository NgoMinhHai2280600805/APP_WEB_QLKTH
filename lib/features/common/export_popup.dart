import 'package:flutter/material.dart';
import '../../core/services/product_service.dart';
import 'package:intl/intl.dart';

class ExportPopup {
  static Future<void> open({
    required BuildContext context,
    required Map<String, dynamic> product,
    required VoidCallback onUpdated,
  }) async {
    final _firebaseService = ProductService();
    final List<Map<String, dynamic>> batches = await _firebaseService
        .getProductBatches(product['id'].toString());

    final Map<String, TextEditingController> qtyControllers = {};
    final Map<String, bool> selected = {};

    for (var b in batches) {
      final id = b['id'].toString();
      qtyControllers[id] = TextEditingController();
      selected[id] = false;
    }

    String _format(dynamic ts) {
      if (ts == null) return '-';
      try {
        if (ts is DateTime) return DateFormat("dd/MM/yyyy").format(ts);
        if (ts.toDate != null)
          return DateFormat("dd/MM/yyyy").format(ts.toDate());
      } catch (_) {}
      return ts.toString();
    }

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx2, setPop) {
            return AlertDialog(
              title: Text("Xuất kho — ${product['name']}"),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.85,
                height: 380,
                child: batches.isEmpty
                    ? const Center(child: Text("Không có lô hàng"))
                    : SingleChildScrollView(
                        child: Column(
                          children: batches.map((b) {
                            final id = b['id'].toString();
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 8.0,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Checkbox(
                                    value: selected[id],
                                    onChanged: (v) {
                                      setPop(() => selected[id] = v ?? false);
                                    },
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text("Lô: ${b['batch_number']}"),
                                        Text("Tồn: ${b['quantity']}"),
                                        Text(
                                          "SX: ${_format(b['mfg_date'])} | HSD: ${_format(b['exp_date'])}",
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(
                                    width: 110,
                                    child: TextField(
                                      controller: qtyControllers[id],
                                      keyboardType: TextInputType.number,
                                      enabled: selected[id] ?? false,
                                      decoration: const InputDecoration(
                                        labelText: "SL xuất",
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx2),
                  child: const Text("Hủy"),
                ),
                ElevatedButton(
                  child: const Text("Xác nhận"),
                  onPressed: () async {
                    final chosen = <Map<String, dynamic>>[];

                    for (var b in batches) {
                      final id = b['id'].toString();
                      if (selected[id] == true) {
                        final qty =
                            int.tryParse(qtyControllers[id]?.text ?? "") ?? 0;

                        if (qty <= 0 || qty > (b['quantity'] as int)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                "Lỗi số lượng ở lô ${b['batch_number']}",
                              ),
                            ),
                          );
                          return;
                        }

                        chosen.add({
                          'id': id,
                          'batch_number': b['batch_number'],
                          'available': b['quantity'],
                          'export_qty': qty,
                        });
                      }
                    }

                    if (chosen.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Chọn ít nhất 1 lô")),
                      );
                      return;
                    }

                    Navigator.pop(ctx2);

                    // chạy function xử lý từ ProductService
                    for (var s in chosen) {
                      await _firebaseService.updateProductBatch(s['id'], {
                        'quantity': s['available'] - s['export_qty'],
                      });
                    }

                    await _firebaseService.updateProductTotalQuantity(
                      product['id'].toString(),
                    );

                    onUpdated();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }
}
