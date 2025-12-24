// lib/features/thongke_staff/components/total_value_card.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TotalValueCard extends StatelessWidget {
  final double totalValue;

  const TotalValueCard({super.key, required this.totalValue});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: const Text('Tổng giá trị xuất'),
        trailing: Text(
          NumberFormat('#,###', 'vi_VN').format(totalValue),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }
}
