import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/place.dart';
import '../../models/post.dart';
import '../../services/api_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../forum/post_detail_screen.dart';
import 'edit_place_sheet.dart';

class PlaceDetailScreen extends StatefulWidget {
  final Place place;
  final VoidCallback onDelete;

  const PlaceDetailScreen({
    super.key,
    required this.place,
    required this.onDelete,
  });

  @override
  PlaceDetailScreenState createState() => PlaceDetailScreenState();
}

class PlaceDetailScreenState extends State<PlaceDetailScreen> {
  List<Post> _relatedPosts = [];
  bool _loadingPosts = false;
  bool _isFavorited = false;

  @override
  void initState() {
    super.initState();
    _loadRelatedPosts();
    _checkFavoriteStatus();
  }

  void _checkFavoriteStatus() {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user != null) {
      setState(() {
        _isFavorited = user.favoritePlaces.contains(widget.place.id);
      });
    }
  }

  Future<void> _loadRelatedPosts() async {
    if (!mounted) return;
    setState(() => _loadingPosts = true);
    try {
      final posts = await ApiService.getPlaceRelatedPosts(widget.place.id);
      if (mounted) setState(() => _relatedPosts = posts);
    } catch (e) {
      // 静默失败
    } finally {
      if (mounted) setState(() => _loadingPosts = false);
    }
  }

  Future<void> _toggleFavorite() async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      await userProvider.toggleFavorite(widget.place.id);
      if (!mounted) return;
      setState(() {
        _isFavorited = !_isFavorited;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isFavorited ? '已收藏' : '已取消收藏')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('操作失败: $e')),
      );
    }
  }

  Future<void> _deletePlace() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这个地点吗？此操作不可逆。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await ApiService.adminDeletePlace(widget.place.id);
      if (mounted) {
        Navigator.pop(context);
        widget.onDelete();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('地点已删除')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败: $e')),
        );
      }
    }
  }

  void _editPlace() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EditPlaceSheet(
        place: widget.place,
        onUpdated: () => widget.onDelete(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).user;
    final isAdmin = (user?.role == 'admin') || (user?.username == 'RandomIX');
    // 修改行：直接比较可空字符串，无需 ?.toString()，消除 warning
    final isSubmitter = (widget.place.submittedBy == user?.id);
    final canEdit = isAdmin || isSubmitter;

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.85,
      child: DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.85,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.92),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border(
              top:
                  BorderSide(color: Colors.white.withOpacity(0.6), width: 1),
            ),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, -4)),
            ],
          ),
          child: Column(
            children: [
              Container(
                height: 4,
                width: 40,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: widget.place.photos.isNotEmpty
                          ? Image.network(
                              widget.place.photos.first,
                              height: 150,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.image, size: 80),
                            )
                          : Container(
                              height: 150,
                              color: Colors.grey[200],
                              child: const Icon(Icons.store, size: 80),
                            ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.place.name,
                            style: const TextStyle(
                                fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            _isFavorited
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: _isFavorited ? Colors.red : const Color(0xFFB8860B),
                          ),
                          onPressed: _toggleFavorite,
                          tooltip: _isFavorited ? '取消收藏' : '收藏',
                        ),
                        if (canEdit)
                          IconButton(
                            icon: const Icon(Icons.edit, color: Color(0xFF8090A8)),
                            onPressed: _editPlace,
                            tooltip: '编辑地点',
                          ),
                        if (isAdmin && widget.place.status == 'approved')
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: _deletePlace,
                            tooltip: '删除地点',
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.location_pin,
                            size: 18, color: Color(0xFFB8860B)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            widget.place.address,
                            style: const TextStyle(color: Color(0xFFB8860B)),
                          ),
                        ),
                      ],
                    ),
                    if (widget.place.tags.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: widget.place.tags.map((tag) {
                          return Chip(
                            label: Text(tag),
                            backgroundColor: const Color(0x1AD0D6E0),
                            labelStyle:
                                const TextStyle(color: Color(0xFFB8860B)),
                          );
                        }).toList(),
                      ),
                    ],
                    const Divider(height: 32),
                    const Text(
                      '相关帖子推荐',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    if (_loadingPosts)
                      const Center(child: CircularProgressIndicator())
                    else if (_relatedPosts.isEmpty)
                      const Center(child: Text('暂无相关帖子'))
                    else
                      ..._relatedPosts.map((post) => Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              title: Text(
                                  post.title.isNotEmpty ? post.title : '(无标题)'),
                              subtitle: Text(
                                '${post.userName}  ·  ${post.category}\n${post.content.length > 80 ? '${post.content.substring(0, 80)}...' : post.content}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        PostDetailScreen(post: post),
                                  ),
                                );
                              },
                            ),
                          )),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
