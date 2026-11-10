import 'package:flutter/material.dart';
import '../../models/moment.dart';
import '../../services/api_service.dart';
import '../../widgets/moment_card.dart';
import '../../widgets/glass_container.dart';

class UserMomentsScreen extends StatefulWidget {
  final String userId;

  const UserMomentsScreen({super.key, required this.userId});

  @override
  UserMomentsScreenState createState() => UserMomentsScreenState();
}

class UserMomentsScreenState extends State<UserMomentsScreen> {
  List<Moment> _moments = [];
  bool _isLoading = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadMoments();
  }

  Future<void> _loadMoments() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.getUserMoments(widget.userId);
      setState(() {
        _moments = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: const GlassAppBarBackground(),title: const Text('用户动态')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _moments.isEmpty
              ? const Center(child: Text('暂无动态'))
              : ListView.builder(
                  controller: _scrollController,
                  itemCount: _moments.length,
                  itemBuilder: (context, index) {
                    return MomentCard(moment: _moments[index]);
                  },
                ),
    );
  }
}
