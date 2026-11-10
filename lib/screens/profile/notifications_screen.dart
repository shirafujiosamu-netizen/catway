import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../widgets/glass_container.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  NotificationsScreenState createState() => NotificationsScreenState();
}

class NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  bool _hasMore = true;
  int _currentPage = 1;
  final int _limit = 20;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        _hasMore) {
      _loadMore();
    }
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    try {
      final data =
          await ApiService.getNotifications(page: _currentPage, limit: _limit);
      final List<dynamic> raw = data['notifications'] ?? [];
      final List<Map<String, dynamic>> parsed =
          raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      setState(() {
        _notifications = parsed;
        _hasMore = parsed.length == _limit;
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

  Future<void> _loadMore() async {
    if (!_hasMore) return;
    setState(() => _isLoading = true);
    try {
      final nextPage = _currentPage + 1;
      final data =
          await ApiService.getNotifications(page: nextPage, limit: _limit);
      final List<dynamic> raw = data['notifications'] ?? [];
      final List<Map<String, dynamic>> newNotifications =
          raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      if (newNotifications.isNotEmpty) {
        setState(() {
          _notifications.addAll(newNotifications);
          _currentPage = nextPage;
          _hasMore = newNotifications.length == _limit;
        });
      } else {
        _hasMore = false;
      }
    } catch (e) {
      // 静默失败
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markAsRead(String id) async {
    try {
      await ApiService.markNotificationRead(id);
      setState(() {
        final index = _notifications.indexWhere((n) => n['_id'] == id);
        if (index != -1) {
          _notifications[index]['isRead'] = true;
        }
      });
    } catch (e) {
      // 忽略错误
    }
  }

  Future<void> _markAllRead() async {
    try {
      await ApiService.markAllNotificationsRead();
      setState(() {
        for (var n in _notifications) {
          n['isRead'] = true;
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('操作失败: $e')),
      );
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
        flexibleSpace: const GlassAppBarBackground(),
        title: const Text('通知'),
        actions: [
          if (_notifications.any((n) => !n['isRead']))
            TextButton(
              onPressed: _markAllRead,
              child: const Text('全部已读'),
            ),
        ],
      ),
      body: _isLoading && _notifications.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? const Center(child: Text('暂无通知'))
              : ListView.builder(
                  controller: _scrollController,
                  itemCount: _notifications.length + (_hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _notifications.length) {
                      return const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final notification = _notifications[index];
                    return InkWell(
                      onTap: () => _markAsRead(notification['_id']),
                      child: Container(
                        color: notification['isRead'] == true
                            ? null
                            : Colors.blue.withOpacity(0.05),
                        child: ListTile(
                          title: Text(notification['title'] ?? '系统通知'),
                          subtitle: Text(notification['content'] ?? ''),
                          trailing: notification['isRead'] == true
                              ? null
                              : const Icon(Icons.circle,
                                  size: 12, color: Colors.blue),
                          isThreeLine: true,
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
