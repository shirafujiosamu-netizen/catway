import 'package:flutter/material.dart';
import '../../models/post.dart';
import '../../services/api_service.dart';
import '../../widgets/post_card.dart';
import '../../widgets/glass_container.dart';

class StrategiesScreen extends StatefulWidget {
  final String? userId; // 可选，不传则获取当前用户的攻略

  const StrategiesScreen({super.key, this.userId});

  @override
  StrategiesScreenState createState() => StrategiesScreenState();
}

class StrategiesScreenState extends State<StrategiesScreen> {
  List<Post> _posts = [];
  bool _isLoading = true;
  bool _hasMore = true;
  int _currentPage = 1;
  final int _limit = 10;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadPosts();
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

  Future<void> _loadPosts() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.getUserStrategies(
        userId: widget.userId,
        page: _currentPage,
        limit: _limit,
      );
      setState(() {
        _posts =
            (data['posts'] as List).map((json) => Post.fromJson(json)).toList();
        _hasMore = _posts.length == _limit;
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
      final data = await ApiService.getUserStrategies(
        userId: widget.userId,
        page: nextPage,
        limit: _limit,
      );
      final newPosts =
          (data['posts'] as List).map((json) => Post.fromJson(json)).toList();
      if (newPosts.isNotEmpty) {
        setState(() {
          _posts.addAll(newPosts);
          _currentPage = nextPage;
          _hasMore = newPosts.length == _limit;
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

  Future<void> _refresh() async {
    setState(() {
      _currentPage = 1;
      _hasMore = true;
      _isLoading = true;
    });
    await _loadPosts();
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
        title: const Text('我的攻略'),
      ),
      body: _isLoading && _posts.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _posts.isEmpty
              ? const Center(child: Text('暂无攻略'))
              : RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: _posts.length + (_hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _posts.length) {
                        return const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final post = _posts[index];
                      return PostCard(
                        post: post,
                        onDelete: () {
                          _refresh();
                        },
                      );
                    },
                  ),
                ),
    );
  }
}
