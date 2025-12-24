import 'package:flutter/material.dart';
import '../../core/db.dart';
import '../../widgets/drawer.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> _products = [];

  @override
  void initState() {
    super.initState();
    _refreshProducts();
  }

  Future<void> _refreshProducts() async {
    final data = await DatabaseHelper.instance.queryAllProducts();
    setState(() {
      _products = data;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Danh sách sản phẩm'),
        backgroundColor: const Color.fromARGB(255, 66, 224, 255),
      ),
      //   KHÔNG dùng const vì CustomDrawer có logic động
      drawer: CustomDrawer(
        onRefresh: _refreshProducts, // cho phép làm mới danh sách
      ),
      body: _products.isEmpty
          ? const Center(child: Text('Chưa có sản phẩm nào'))
          : RefreshIndicator(
              onRefresh: _refreshProducts,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: _products.length,
                itemBuilder: (context, index) {
                  final item = _products[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    elevation: 2,
                    child: ListTile(
                      title: Text(item['name']),
                      subtitle: Text(
                        'Mã: ${item['code']} | SL: ${item['quantity']}',
                      ),
                      trailing: Text('${item['price']}₫'),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
