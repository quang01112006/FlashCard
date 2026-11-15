import 'package:flutter/material.dart';

class ManageCardsScreen extends StatelessWidget {
  const ManageCardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý thẻ'),
        centerTitle: true,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.style_outlined, size: 72, color: Colors.orange),
            SizedBox(height: 16),
            Text(
              'Màn hình Quản lý thẻ (Danh sách thẻ & Nhập CSV)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
