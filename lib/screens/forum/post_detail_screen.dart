import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import '../../models/post.dart';
import '../../services/api_service.dart';
import '../../providers/auth_provider.dart';
import '../home/place_detail_screen.dart';
import '../../widgets/glass_container.dart';

class PostDetailScreen extends StatefulWidget {
  final Post post;

  const PostDetailScreen({super.key, required this.post});

  @override
  PostDetailScreenState createState() => PostDetailScreenState();
}

class PostDetailScreenState extends State<PostDetailScreen> {
  bool _isLiked = false;
  int _likesCount = 0;
  bool _isFollowing = false;
  bool _isFollowingLoading = false;

  // 评论相关
  List<Map<String, dynamic>> _comments = [];
  bool _loadingComments = false;
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _commentScrollController = ScrollController();

  // 解析后的内容 Widget 列表
  List<Widget> _contentWidgets = [];

  @override
  void initState() {
    super.initState();
    _likesCount = widget.post.likesCount;
    _checkFollowStatus();
    _parseContent();
    _loadComments();
  }

  void _checkFollowStatus() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = auth.user;
    if (currentUser != null && currentUser.id != widget.post.userId) {
      // 实际应查询关注状态，简化：先设为 false，后续可通过接口获取
      setState(() => _isFollowing = false);
    }
  }

  Future<void> _toggleFollow() async {
    if (_isFollowingLoading) return;
    setState(() => _isFollowingLoading = true);
    try {
      await ApiService.toggleFollow(widget.post.userId);
      if (!mounted) return;
      setState(() => _isFollowing = !_isFollowing);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isFollowing ? '已关注' : '已取消关注')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('操作失败: $e')),
      );
    } finally {
      if (mounted) setState(() => _isFollowingLoading = false);
    }
  }

  void _parseContent() {
    final String text = widget.post.content;
    final RegExp placeRegex = RegExp(r'\[\[place:([^:]+):([^\]]+)\]\]');
    final List<Widget> widgets = [];
    int lastIndex = 0;
    for (final match in placeRegex.allMatches(text)) {
      if (match.start > lastIndex) {
        widgets.add(Text(text.substring(lastIndex, match.start)));
      }
      final placeId = match.group(1)!;
      final placeName = match.group(2)!;
      widgets.add(
        GestureDetector(
          onTap: () => _showPlaceDetail(placeId, placeName),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0B3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFB8860B)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_pin,
                    size: 16, color: Color(0xFFB8860B)),
                const SizedBox(width: 4),
                Text(placeName,
                    style: const TextStyle(
                        color: Color(0xFFB8860B), fontWeight: FontWeight.bold)),
                const Icon(Icons.chevron_right,
                    size: 16, color: Color(0xFFB8860B)),
              ],
            ),
          ),
        ),
      );
      lastIndex = match.end;
    }
    if (lastIndex < text.length) {
      widgets.add(Text(text.substring(lastIndex)));
    }
    setState(() => _contentWidgets = widgets);
  }

  Future<void> _showPlaceDetail(String placeId, String placeName) async {
    try {
      final place = await ApiService.getPlaceById(placeId);
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => PlaceDetailScreen(place: place, onDelete: () {}),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('无法加载地点详情: $e')),
        );
      }
    }
  }

  Future<void> _loadComments() async {
    setState(() => _loadingComments = true);
    try {
      final comments = await ApiService.getPostComments(widget.post.id);
      setState(() {
        _comments = comments;
        _loadingComments = false;
      });
    } catch (e) {
      setState(() => _loadingComments = false);
      _showSnackBar('加载评论失败: $e');
    }
  }

  Future<void> _toggleLike() async {
    if (_isLiked) return;
    setState(() => _isLiked = true);
    try {
      final result = await ApiService.likePost(widget.post.id);
      setState(() => _likesCount = result['likesCount']);
    } catch (e) {
      setState(() {
        _isLiked = false;
        _likesCount = widget.post.likesCount;
      });
      _showSnackBar('点赞失败: $e');
    }
  }

  Future<void> _sendComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty) {
      _showSnackBar('请输入评论内容');
      return;
    }
    try {
      await ApiService.addComment(widget.post.id, content);
      _commentController.clear();
      await _loadComments();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _commentScrollController.animateTo(
          _commentScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
      _showSnackBar('评论发送成功');
    } catch (e) {
      _showSnackBar('发送失败: $e');
    }
  }

  Future<void> _toggleCommentLike(String commentId, bool isLiked) async {
    if (isLiked) return;
    try {
      await ApiService.likeComment(commentId);
      setState(() {
        final index = _comments.indexWhere((c) => c['id'] == commentId);
        if (index != -1) {
          _comments[index]['isLiked'] = true;
          _comments[index]['likesCount'] =
              (_comments[index]['likesCount'] as int) + 1;
        }
      });
    } catch (e) {
      _showSnackBar('点赞评论失败: $e');
    }
  }

  void _scrollToComments() {
    _commentScrollController.animateTo(
      _commentScrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _showShareOptions() {
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
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('猫径个人动态'),
              onTap: () {
                Navigator.pop(context);
                _shareToCatway();
              },
            ),
            const Divider(),
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
            ListTile(
              leading: const Icon(Icons.web),
              title: const Text('微博'),
              onTap: () => _shareToOther('weibo'),
            ),
          ],
        ),
      ),
    );
  }

  void _shareToCatway() async {
    try {
      await ApiService.sharePostToCatway(widget.post.id);
      _showSnackBar('已转发到个人动态');
    } catch (e) {
      _showSnackBar('转发失败: $e');
    }
  }

  void _shareToOther(String platform) {
    final shareText =
        '【${widget.post.userName}】分享了帖子：${widget.post.title}\n${widget.post.content}\n来自猫径CatWay App 下载：https://theregolithjar.monster/downloads/app-release.apk';
    Share.share(shareText, subject: '猫径CatWay帖子分享');
    _showSnackBar('已分享到$platform');
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final currentUserId = auth.user?.id;
    final isOwnPost = currentUserId == widget.post.userId;

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: const GlassAppBarBackground(),
        title: Text(widget.post.title.isNotEmpty ? widget.post.title : '帖子详情'),
        actions: [
          IconButton(
            icon: const Icon(Icons.comment),
            onPressed: _scrollToComments,
            tooltip: '滚动到评论',
          ),
        ],
      ),
      body: SingleChildScrollView(
        controller: _commentScrollController,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 用户信息行（含关注按钮）
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.transparent,
                  backgroundImage: widget.post.userAvatar.isNotEmpty
                      ? NetworkImage(widget.post.userAvatar)
                      : null,
                  child: widget.post.userAvatar.isEmpty
                      ? const Icon(Icons.person, color: const Color(0xFFB8860B))
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.post.userName,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('@${widget.post.userName}',
                          style: const TextStyle(
                              fontSize: 12, color: const Color(0xFFB8860B))),
                    ],
                  ),
                ),
                if (!isOwnPost)
                  TextButton(
                    onPressed: _isFollowingLoading ? null : _toggleFollow,
                    style: TextButton.styleFrom(
                        foregroundColor: _isFollowing
                            ? const Color(0xFFB8860B)
                            : const Color(0xFFB8860B)),
                    child: Text(_isFollowing ? '已关注' : '关注'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (widget.post.title.isNotEmpty)
              Text(widget.post.title,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (widget.post.productType != null || widget.post.shopType != null)
              Wrap(
                spacing: 8,
                children: [
                  if (widget.post.productType != null &&
                      widget.post.productType!.isNotEmpty)
                    Chip(
                        label: Text(widget.post.productType!),
                        backgroundColor: const Color(0xFFFFF0B3),
                        labelStyle: const TextStyle(color: Color(0xFF8B6508))),
                  if (widget.post.shopType != null &&
                      widget.post.shopType!.isNotEmpty)
                    Chip(
                        label: Text(widget.post.shopType!),
                        backgroundColor: const Color(0xFFFFF0B3),
                        labelStyle: const TextStyle(color: Color(0xFF8B6508))),
                  if (widget.post.ip != null && widget.post.ip!.isNotEmpty)
                    Chip(
                        label: Text(widget.post.ip!),
                        backgroundColor: const Color(0xFFFFF0B3),
                        labelStyle: const TextStyle(color: Color(0xFF8B6508))),
                ],
              ),
            const SizedBox(height: 16),
            ..._contentWidgets,
            const SizedBox(height: 16),
            if (widget.post.images.isNotEmpty)
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3, crossAxisSpacing: 4, mainAxisSpacing: 4),
                itemCount: widget.post.images.length,
                itemBuilder: (context, index) => GestureDetector(
                  onTap: () => showDialog(
                      context: context,
                      builder: (_) => Dialog(
                          child: Image.network(widget.post.images[index]))),
                  child: Image.network(widget.post.images[index],
                      fit: BoxFit.cover),
                ),
              ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                InkWell(
                  onTap: _toggleLike,
                  child: Row(
                    children: [
                      Icon(_isLiked ? Icons.favorite : Icons.favorite_border,
                          color: _isLiked ? Colors.red : const Color(0xFFB8860B), size: 20),
                      const SizedBox(width: 4),
                      Text('$_likesCount'),
                    ],
                  ),
                ),
                InkWell(
                  onTap: _scrollToComments,
                  child: Row(
                    children: [
                      const Icon(Icons.comment, size: 20, color: const Color(0xFFB8860B)),
                      const SizedBox(width: 4),
                      Text('${widget.post.commentCount}'),
                    ],
                  ),
                ),
                InkWell(
                  onTap: _showShareOptions,
                  child: const Row(
                    children: [
                      Icon(Icons.share, size: 20, color: const Color(0xFFB8860B)),
                      SizedBox(width: 4),
                      Text('0'),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            const Text('评论',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: '写评论...',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                    icon: const Icon(Icons.send), onPressed: _sendComment),
              ],
            ),
            const SizedBox(height: 16),
            if (_loadingComments)
              const Center(child: CircularProgressIndicator())
            else if (_comments.isEmpty)
              const Center(child: Text('暂无评论，快来抢沙发吧～'))
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _comments.length,
                itemBuilder: (context, index) {
                  final comment = _comments[index];
                  final isLiked = comment['isLiked'] ?? false;
                  final likesCount = comment['likesCount'] ?? 0;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.transparent,
                      backgroundImage: comment['avatar'] != null &&
                              comment['avatar'].isNotEmpty
                          ? NetworkImage(comment['avatar'])
                          : null,
                      child:
                          comment['avatar'] == null || comment['avatar'].isEmpty
                              ? const Icon(Icons.person, color: const Color(0xFFB8860B))
                              : null,
                    ),
                    title: Text(comment['userName'] ?? '用户'),
                    subtitle: Text(comment['content'] ?? ''),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                              isLiked ? Icons.favorite : Icons.favorite_border,
                              size: 16,
                              color: isLiked ? Colors.red : null),
                          onPressed: () => _toggleCommentLike(
                              comment['id'].toString(), isLiked),
                        ),
                        Text('$likesCount'),
                      ],
                    ),
                  );
                },
              ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}
