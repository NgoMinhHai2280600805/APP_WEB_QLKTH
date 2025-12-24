// lib/features/common/thongke_admin/components/summary_cards.dart

import 'package:flutter/material.dart';

class SummaryCards extends StatelessWidget {
  final int totalImportQty;
  final int totalExportQty;
  final double totalExportValue;
  final int currentStock;
  final double totalStockValue; // ← MỚI: Tổng giá trị tồn kho

  const SummaryCards({
    super.key,
    required this.totalImportQty,
    required this.totalExportQty,
    required this.totalExportValue,
    required this.currentStock,
    required this.totalStockValue,
  });

  String _formatMoney(double amount) {
    return amount
        .toStringAsFixed(0)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (match) => '${match[1]}.',
        );
  }

  Widget _buildRow({
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: valueColor ?? Colors.black87,
              ),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildRow(
            label: 'Tổng nhập kho',
            value: '$totalImportQty',
            valueColor: Colors.green[700],
          ),
          const Divider(height: 1, thickness: 0.5),
          _buildRow(
            label: 'Tổng xuất kho',
            value: '$totalExportQty',
            valueColor: Colors.red[700],
          ),
          const Divider(height: 1, thickness: 0.5),
          _buildRow(
            label: 'Giá trị xuất',
            value: '${_formatMoney(totalExportValue)} đ',
            valueColor: Colors.blue[700],
          ),
          const Divider(height: 1, thickness: 0.5),
          _buildRow(
            label: 'Tồn kho hiện tại',
            value: '$currentStock',
            valueColor: Colors.orange[700],
          ),
          const Divider(height: 1, thickness: 0.5),
          _buildRow(
            label: 'Tổng giá trị tồn kho',
            value: '${_formatMoney(totalStockValue)} đ',
            valueColor: Colors.purple[700],
          ),
        ],
      ),
    );
  }
}
