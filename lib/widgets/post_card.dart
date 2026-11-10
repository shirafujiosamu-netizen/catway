import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/post.dart';
import '../services/api_service.dart';
import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';
import '../screens/forum/post_detail_screen.dart';
import '../services/config_service.dart';
import 'glass_container.dart';

class PostCard extends StatefulWidget {
  final Post post;
  final VoidCallback? onLikeChanged;
  final VoidCallback? onFollowChanged;
  final VoidCallback? onDelete;

  const PostCard({
    super.key,
    required this.post,
    this.onLikeChanged,
    this.onFollowChanged,
    this.onDelete,
  });

  @override
  PostCardState createState() => PostCardState();
}

class PostCardState extends State<PostCard> {
  bool _isLiked = false;
  int _likesCount = 0;
  bool _isFollowing = false;
  bool _isFollowingLoading = false;

  @override
  void initState() {
    super.initState();
    _likesCount = widget.post.likesCount;
    _isLiked = widget.post.isLiked; // 使用后端返回的点赞状态
    _checkFollowStatus();
  }

  void _checkFollowStatus() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = auth.user;
    if (currentUser != null && currentUser.id != widget.post.userId) {
      ApiService.isFollowing(widget.post.userId).then((isFollowing) {
        if (mounted) setState(() => _isFollowing = isFollowing);
      }).catchError((_) {});
    }
  }

  Future<void> _toggleFollow() async {
    if (_isFollowingLoading) return;
    setState(() => _isFollowingLoading = true);
    try {
      await ApiService.toggleFollow(widget.post.userId);
      if (!mounted) return;
      setState(() => _isFollowing = !_isFollowing);
      widget.onFollowChanged?.call();
      // 刷新 UserProvider，确保个人主页的粉丝/关注计数实时更新
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      await userProvider.refreshCurrentUser();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isFollowing ? '已关注' : '已取消关注')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isFollowingLoading = false);
    }
  }

  Future<void> _toggleLike() async {
    if (_isLiked) return;
    setState(() => _isLiked = true);
    _likesCount++;
    try {
      final result = await ApiService.likePost(widget.post.id);
      if (mounted) {
        setState(() {
          _likesCount = result['likesCount'];
          _isLiked = result['isLiked'] ?? true;
        });
        widget.onLikeChanged?.call();
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        await userProvider.refreshCurrentUser();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLiked = false;
          _likesCount = widget.post.likesCount;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('点赞失败: $e')),
        );
      }
    }
  }

  Future<void> _deletePost() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = auth.user?.id;
    final isOwnPost = currentUserId == widget.post.userId;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('删除后不可恢复，确定要删除这篇帖子吗？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('删除', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      if (isOwnPost) {
        await ApiService.deletePost(widget.post.id);
      } else {
        await ApiService.adminDeletePost(widget.post.id);
      }
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('帖子已删除')));
        widget.onDelete?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('删除失败: $e')));
      }
    }
  }

  void _showMenu() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = auth.user?.id;
    final isOwnPost = currentUserId == widget.post.userId;
    final isAdmin = auth.user?.role == 'admin';
    final canDelete = isOwnPost || isAdmin;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => GlassBottomSheet(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isOwnPost)
              ListTile(
                leading: const Icon(Icons.thumb_down, color: const Color(0xFFB8860B)),
                title: const Text('不感兴趣'),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('不感兴趣功能开发中')),
                  );
                },
              ),
            if (!isOwnPost)
              ListTile(
                leading: const Icon(Icons.report, color: const Color(0xFFB8860B)),
                title: const Text('举报'),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('举报功能开发中')),
                  );
                },
              ),
            if (canDelete)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('删除', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _deletePost();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showShareOptions() {
    final List<Widget> shareItems = [];

    shareItems.add(
      ListTile(
        leading: const Icon(Icons.person),
        title: const Text('猫径个人动态'),
        onTap: () {
          Navigator.pop(context);
          _shareToCatway();
        },
      ),
    );
    shareItems.add(const Divider());

    if (ConfigService.enableShareToQQ) {
      shareItems.addAll([
        ListTile(
          leading: const Icon(Icons.chat),
          title: const Text('QQ好友'),
          onTap: () => _shareToOther('qq'),
        ),
        ListTile(
          leading: const Icon(Icons.group),
          title: const Text('QQ群聊'),
          onTap: () => _shareToOther('qq_group'),
        ),
        ListTile(
          leading: const Icon(Icons.photo_library),
          title: const Text('QQ空间'),
          onTap: () => _shareToOther('qzone'),
        ),
        const Divider(),
      ]);
    }

    if (ConfigService.enableShareToWechat) {
      shareItems.addAll([
        ListTile(
          leading: const Icon(Icons.chat_bubble),
          title: const Text('微信好友'),
          onTap: () => _shareToOther('wechat'),
        ),
        ListTile(
          leading: const Icon(Icons.group_work),
          title: const Text('朋友圈'),
          onTap: () => _shareToOther('moments'),
        ),
        const Divider(),
      ]);
    }

    if (ConfigService.enableShareToWeibo) {
      shareItems.add(
        ListTile(
          leading: const Icon(Icons.web),
          title: const Text('微博'),
          onTap: () => _shareToOther('weibo'),
        ),
      );
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => GlassBottomSheet(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 8, bottom: 8, left: 16, right: 16),
              child: Text('分享到',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            ...shareItems,
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _shareToCatway() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ApiService.sharePostToCatway(widget.post.id);
      messenger.showSnackBar(
        const SnackBar(content: Text('已转发到个人动态')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('转发失败: $e')),
      );
    }
  }

  void _shareToOther(String platform) {
    final shareText =
        '【${widget.post.userName}】分享了帖子：${widget.post.title}\n${widget.post.content}\n来自猫径CatWay App 下载：https://theregolithjar.monster/downloads/app-release.apk';
    Share.share(shareText, subject: '猫径CatWay帖子分享');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已分享到$platform')),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays > 0) return '${diff.inDays}天前';
    if (diff.inHours > 0) return '${diff.inHours}小时前';
    if (diff.inMinutes > 0) return '${diff.inMinutes}分钟前';
    return '刚刚';
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final currentUserId = auth.user?.id;
    final isOwnPost = currentUserId == widget.post.userId;
    final isAdmin = auth.user?.role == 'admin';
    final canDelete = isOwnPost || isAdmin;

    return GlassContainer(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.transparent,
              backgroundImage: widget.post.userAvatar.isNotEmpty
                  ? NetworkImage(widget.post.userAvatar)
                  : null,
              child: widget.post.userAvatar.isEmpty
                  ? const Icon(Icons.person, color: const Color(0xFFB8860B))
                  : null,
            ),
            title: Text(widget.post.userName,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(
              '@${widget.post.userAccount}  ·  ${_formatDate(widget.post.createdAt)}',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isOwnPost)
                  TextButton(
                    onPressed: _isFollowingLoading ? null : _toggleFollow,
                    style: TextButton.styleFrom(
                        foregroundColor: _isFollowing
                            ? const Color(0xFFB8860B)
                            : const Color(0xFFB8860B)),
                    child: Text(_isFollowing ? '已关注' : '关注'),
                  ),
                if (canDelete)
                  IconButton(
                      icon: const Icon(Icons.more_vert),
                      onPressed: _showMenu,
                      tooltip: '更多'),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.post.title.isNotEmpty)
                  Text(widget.post.title,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(widget.post.content,
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                if (widget.post.productType != null ||
                    widget.post.shopType != null)
                  Wrap(
                    spacing: 4,
                    children: [
                      if (widget.post.productType != null &&
                          widget.post.productType!.isNotEmpty)
                        Chip(
                            label: Text(widget.post.productType!),
                            backgroundColor: const Color(0x1AD0D6E0),
                            labelStyle:
                                const TextStyle(color: Color(0xFFB8860B)),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            padding: EdgeInsets.zero),
                      if (widget.post.shopType != null &&
                          widget.post.shopType!.isNotEmpty)
                        Chip(
                            label: Text(widget.post.shopType!),
                            backgroundColor: const Color(0x1AD0D6E0),
                            labelStyle:
                                const TextStyle(color: Color(0xFFB8860B)),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            padding: EdgeInsets.zero),
                      if (widget.post.ip != null && widget.post.ip!.isNotEmpty)
                        Chip(
                            label: Text(widget.post.ip!),
                            backgroundColor: const Color(0x1AD0D6E0),
                            labelStyle:
                                const TextStyle(color: Color(0xFFB8860B)),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            padding: EdgeInsets.zero),
                    ],
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    InkWell(
                      onTap: _toggleLike,
                      child: Row(
                        children: [
                          Icon(
                              _isLiked ? Icons.favorite : Icons.favorite_border,
                              size: 16,
                              color: _isLiked ? Colors.red : const Color(0xFFB8860B)),
                          const SizedBox(width: 2),
                          Text('$_likesCount'),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.comment, size: 16, color: const Color(0xFFB8860B)),
                    const SizedBox(width: 2),
                    Text('${widget.post.commentCount}'),
                    const SizedBox(width: 12),
                    InkWell(
                      onTap: _showShareOptions,
                      child: const Row(
                        children: [
                          Icon(Icons.share, size: 16, color: const Color(0xFFB8860B)),
                          SizedBox(width: 2),
                          Text('0'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Divider(height: 1, thickness: 1, color: Colors.grey[200]),
          ListTile(
            title: const Text('查看详情'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => PostDetailScreen(post: widget.post))),
          ),
        ],
      ),
    );
  }
}
