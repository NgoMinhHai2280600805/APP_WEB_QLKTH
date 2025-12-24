import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationDetailScreen extends StatelessWidget {
  final Map<String, dynamic> logData;

  const NotificationDetailScreen({super.key, required this.logData});

  @override
  Widget build(BuildContext context) {
    final timestamp = (logData['timestamp'] as Timestamp?)?.toDate().toLocal();

    final timeString = timestamp != null
        ? '${timestamp.toString().split('.')[0]}' // Cắt mili giây
        : 'Không xác định';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết thông báo'),
        backgroundColor: Colors.blue,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Thông tin đăng nhập',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Divider(),

            _buildInfoRow(
              'Thiết bị',
              logData['deviceName'] ?? 'Không xác định',
            ),
            _buildInfoRow('IP Public', logData['ipPublic'] ?? 'Không xác định'),
            _buildInfoRow(
              'Trình duyệt',
              logData['browserName'] ?? 'Không xác định',
            ),
            _buildInfoRow(
              'Hệ điều hành',
              logData['platform'] ?? 'Không xác định',
            ),
            _buildInfoRow(
              'Loại thiết bị',
              logData['deviceType'] ?? 'Không xác định',
            ),
            _buildInfoRow('Thời gian đăng nhập', timeString),
            _buildInfoRow(
              'Tên người dùng',
              logData['username'] ?? 'Không xác định',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 16))),
        ],
      ),
    );
  }
}
