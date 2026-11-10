import 'profile_screen.dart';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../widgets/glass_container.dart';

class FollowersFollowingScreen extends StatefulWidget {
  final String userId;
  final bool isFollowers; // true: 粉丝列表, false: 关注列表

  const FollowersFollowingScreen({
    super.key,
    required this.userId,
    required this.isFollowers,
  });

  @override
  FollowersFollowingScreenState createState() =>
      FollowersFollowingScreenState();
}

class FollowersFollowingScreenState extends State<FollowersFollowingScreen> {
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final data = widget.isFollowers
          ? await ApiService.getFollowers(widget.userId)
          : await ApiService.getFollowing(widget.userId);
      final List<dynamic> raw =
          widget.isFollowers ? data['followers'] : data['following'];
      final List<Map<String, dynamic>> parsed =
          raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      setState(() {
        _users = parsed;
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: const GlassAppBarBackground(),
        title: Text(widget.isFollowers ? '粉丝' : '关注'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _users.isEmpty
              ? Center(
                  child: Text(widget.isFollowers ? '暂无粉丝' : '暂无关注'),
                )
              : ListView.builder(
                  itemCount: _users.length,
                  itemBuilder: (context, index) {
                    final user = _users[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage:
                            user['avatar'] != null && user['avatar'].isNotEmpty
                                ? NetworkImage(user['avatar'])
                                : null,
                        child: user['avatar'] == null || user['avatar'].isEmpty
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      title: Text(user['nickname'] ?? user['username'] ?? '用户'),
                      subtitle: Text('@${user['username'] ?? ''}'),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProfileScreen(userId: user['_id']),
                          ),
                        );
                      },
                    );
                  },
                ),
    );
  }
}
