import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../widgets/glass_container.dart';

class AdminToolsScreen extends StatefulWidget {
  const AdminToolsScreen({super.key});

  @override
  AdminToolsScreenState createState() => AdminToolsScreenState();
}

class AdminToolsScreenState extends State<AdminToolsScreen> {
  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();

  Future<void> _banIp() async {
    if (_ipController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入IP地址')),
      );
      return;
    }
    try {
      await ApiService.adminBanIp(
        _ipController.text.trim(),
        reason: _reasonController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('IP已加入黑名单')),
        );
        _ipController.clear();
        _reasonController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: const GlassAppBarBackground(),title: const Text('管理员工具')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              '拉黑IP',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _ipController,
              decoration: const InputDecoration(
                labelText: 'IP地址',
                hintText: '例如：192.168.1.1',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reasonController,
              decoration: const InputDecoration(
                labelText: '原因（可选）',
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _banIp,
              child: const Text('拉黑IP'),
            ),
            const SizedBox(height: 30),
            const Text(
              '帖子管理',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text('长按任意帖子可删除或置顶', style: TextStyle(color: const Color(0xFFB8860B))),
          ],
        ),
      ),
    );
  }
}
