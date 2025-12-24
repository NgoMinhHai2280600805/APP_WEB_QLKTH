import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/services/product_service.dart';

class AddProductScreen extends StatefulWidget {
  final String categoryId;

  const AddProductScreen({super.key, required this.categoryId});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _firebaseService = ProductService();

  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _quantityController = TextEditingController();
  final _lotController = TextEditingController();
  final _descController = TextEditingController();

  DateTime? _mfgDate;
  DateTime? _expDate;
  String? _imagePath;

  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    _lotController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      final file = File(picked.path);
      final url = await _firebaseService.uploadImage(file);
      if (url != null) {
        setState(() => _imagePath = url);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("Tải ảnh lên thất bại")));
        }
      }
    }
  }

  Future<void> _pickMfgDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _mfgDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _mfgDate = picked);
  }

  Future<void> _pickExpDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _expDate = picked);
  }

  String _formatDate(DateTime? d) =>
      d == null ? 'Chọn ngày' : DateFormat('yyyy-MM-dd').format(d);

  Future<void> _saveProduct() async {
    if (_saving) return;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Nhập tên sản phẩm")));
      return;
    }

    setState(() => _saving = true);

    try {
      // tạo document mới (lấy id trước để dùng cho batch)
      final docRef = FirebaseFirestore.instance.collection('products').doc();

      final productData = {
        'id': docRef.id,
        'batch_number': _lotController.text.trim(),
        'name': name,
        'price': double.tryParse(_priceController.text) ?? 0,
        'quantity': int.tryParse(_quantityController.text) ?? 0,
        'description': _descController.text.trim(),
        'category_id': widget.categoryId,
        'image': _imagePath,
        // lưu Timestamp hoặc null
        'mfg_date': _mfgDate != null ? Timestamp.fromDate(_mfgDate!) : null,
        'exp_date': _expDate != null ? Timestamp.fromDate(_expDate!) : null,
        'is_deleted': false,
        'created_at': FieldValue.serverTimestamp(),
      };

      // set dữ liệu product
      await docRef.set(productData);

      // thêm batch nếu user nhập batch_no không rỗng
      if ((_lotController.text.trim()).isNotEmpty) {
        await _firebaseService.addProductBatch(docRef.id, {
          'batch_number': _lotController.text.trim(),
          'quantity': int.tryParse(_quantityController.text) ?? 0,
          // gửi Timestamp hoặc null (service sẽ xử lý)
          'mfg_date': _mfgDate != null ? Timestamp.fromDate(_mfgDate!) : null,
          'expiry_date': _expDate != null
              ? Timestamp.fromDate(_expDate!)
              : null,
          'product_id': docRef.id,
          'created_at': FieldValue.serverTimestamp(),
          'is_deleted': false,
        });
      }

      // trả true để screen gọi biết cần reload dữ liệu
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Lỗi khi lưu: $e")));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Thêm sản phẩm")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 150,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey),
                  image: (_imagePath?.isNotEmpty ?? false)
                      ? DecorationImage(
                          image: NetworkImage(_imagePath!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: (_imagePath?.isEmpty ?? true)
                    ? const Center(child: Text("Thêm hình ảnh"))
                    : Stack(
                        alignment: Alignment.topRight,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.red),
                            onPressed: () => setState(() => _imagePath = null),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _lotController,
              decoration: const InputDecoration(labelText: "Mã lô"),
            ),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: "Tên sản phẩm"),
            ),
            TextField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Giá"),
            ),
            TextField(
              controller: _quantityController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Số lượng"),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _pickMfgDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: "Ngày sản xuất",
                      ),
                      child: Text(_formatDate(_mfgDate)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: _pickExpDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: "Ngày hết hạn",
                      ),
                      child: Text(_formatDate(_expDate)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: "Mô tả"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saving ? null : _saveProduct,
              child: _saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text("Lưu"),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
