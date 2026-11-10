import 'package:flutter/material.dart';
import '../../widgets/glass_container.dart';

class FootprintScreen extends StatelessWidget {
  const FootprintScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: const GlassAppBarBackground(),title: const Text('我的足迹')),
      body: const Center(
        child: Text('足迹功能开发中'),
      ),
    );
  }
}
