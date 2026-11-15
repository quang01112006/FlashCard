import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trang chủ'),
        centerTitle: true,
      ),
      body: const Center(
        child: Text(
          'Màn hình Trang chủ (Đang phát triển...)',
          style: TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}
