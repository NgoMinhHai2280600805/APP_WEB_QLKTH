import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:photo_view/photo_view.dart';
import 'package:permission_handler/permission_handler.dart';

class ImageReviewScreen extends StatefulWidget {
  final String imagePath;
  const ImageReviewScreen({super.key, required this.imagePath});

  @override
  State<ImageReviewScreen> createState() => _ImageReviewScreenState();
}

class _ImageReviewScreenState extends State<ImageReviewScreen> {
  late String _currentImagePath;

  @override
  void initState() {
    super.initState();
    _currentImagePath = widget.imagePath;
  }

  // Cắt ảnh (chuẩn cho image_cropper 11.x)
  Future<void> _cropImage() async {
    //   Kiểm tra quyền trước
    Map<Permission, PermissionStatus> statuses = await [
      Permission.camera,
      Permission.storage, // Android cũ
      Permission.photos, // iOS
    ].request();

    if (statuses[Permission.camera]!.isDenied ||
        statuses[Permission.storage]!.isDenied) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng cấp quyền để cắt ảnh.')),
      );
      return;
    }

    try {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: _currentImagePath,
        compressQuality: 90,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Cắt ảnh',
            toolbarColor: Colors.blue,
            toolbarWidgetColor: Colors.white,
            hideBottomControls: false,
            lockAspectRatio: false,
            initAspectRatio: CropAspectRatioPreset.original,
          ),
          IOSUiSettings(title: 'Cắt ảnh', aspectRatioLockEnabled: false),
        ],
      );

      if (croppedFile != null && mounted) {
        setState(() => _currentImagePath = croppedFile.path);
      }
    } catch (e) {
      debugPrint("Lỗi khi cắt ảnh: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể cắt ảnh. Vui lòng thử lại.')),
      );
    }
  }

  /// 🖼️ Xem ảnh toàn màn hình (zoom, pan)
  void _viewFullScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text("Xem ảnh toàn màn hình")),
          body: Center(
            child: PhotoView(
              imageProvider: FileImage(File(_currentImagePath)),
              backgroundDecoration: const BoxDecoration(color: Colors.black),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Xem và chỉnh sửa ảnh"),
        backgroundColor: Colors.blue,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                File(_currentImagePath),
                fit: BoxFit.contain,
                height: screenHeight * 0.5,
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _cropImage,
                  icon: const Icon(Icons.crop),
                  label: const Text("Cắt ảnh"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    minimumSize: const Size(140, 48),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _viewFullScreen(context),
                  icon: const Icon(Icons.zoom_in),
                  label: const Text("Phóng to"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    minimumSize: const Size(140, 48),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context, _currentImagePath),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text("Xác nhận"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    minimumSize: const Size(140, 48),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text("Hủy bỏ"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    minimumSize: const Size(140, 48),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
