import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import '../models/moment.dart';
import '../services/api_service.dart';
import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';
import '../screens/home/place_detail_screen.dart';
import '../services/config_service.dart';
import 'glass_container.dart';

class MomentCard extends StatefulWidget {
  final Moment moment;
  final VoidCallback? onLikeChanged;
  final VoidCallback? onCommentChanged;
  final VoidCallback? onFollowChanged;
  final VoidCallback? onDelete;
  final VoidCallback? onNotInterested;

  const MomentCard({
    super.key,
    required this.moment,
    this.onLikeChanged,
    this.onCommentChanged,
    this.onFollowChanged,
    this.onDelete,
    this.onNotInterested,
  });

  @override
  MomentCardState createState() => MomentCardState();
}

class MomentCardState extends State<MomentCard> {
  bool _isLiked = false;
  int _likesCount = 0;
  bool _isFollowing = false;
  bool _isFollowingLoading = false;

  List<Map<String, dynamic>> _topComments = [];
  bool _loadingComments = false;
  bool _showComments = false;
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _commentScrollController = ScrollController();
  bool _hasMoreComments = false;
  int _commentPage = 1;
  final int _commentLimit = 5;

  List<Widget> _contentWidgets = [];

  @override
  void initState() {
    super.initState();
    _likesCount = widget.moment.likesCount;
    _isLiked = widget.moment.isLiked; // 使用后端返回的点赞状态
    _parseContent();
    _checkFollowStatus();
  }

  void _parseContent() {
    final String text = widget.moment.content;
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
              color: const Color(0x1AB8860B),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0x60B8860B)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_pin,
                    size: 16, color: Color(0xFFB8860B)),
                const SizedBox(width: 4),
                Text(placeName,
                    style: const TextStyle(
                        color: Color(0xFFB8860B),
                        fontWeight: FontWeight.bold)),
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

  void _checkFollowStatus() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = auth.user;
    if (currentUser != null && currentUser.id != widget.moment.userId) {
      ApiService.isFollowing(widget.moment.userId).then((isFollowing) {
        if (mounted) setState(() => _isFollowing = isFollowing);
      }).catchError((_) {});
    }
  }

  Future<void> _toggleFollow() async {
    if (_isFollowingLoading) return;
    setState(() => _isFollowingLoading = true);
    try {
      await ApiService.toggleFollow(widget.moment.userId);
      if (!mounted) return;
      setState(() => _isFollowing = !_isFollowing);
      widget.onFollowChanged?.call();
      // 刷新 UserProvider，确保个人主页的粉丝/关注计数实时更新
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      await userProvider.refreshCurrentUser();
      if (!mounted) return;
      _showSnackBar(_isFollowing ? '已关注' : '已取消关注');
    } catch (e) {
      if (mounted) _showSnackBar('操作失败: $e');
    } finally {
      if (mounted) setState(() => _isFollowingLoading = false);
    }
  }

  Future<void> _toggleLike() async {
    if (_isLiked) return; // 后端已做防重复，前端也阻止
    setState(() => _isLiked = true);
    _likesCount++; // 乐观更新
    try {
      final result = await ApiService.likeMoment(widget.moment.id);
      if (mounted) {
        setState(() {
          _likesCount = result['likesCount'];
          _isLiked = result['isLiked'] ?? true;
        });
        widget.onLikeChanged?.call();
        // 刷新个人主页的获赞数
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        await userProvider.refreshCurrentUser();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLiked = false;
          _likesCount = widget.moment.likesCount;
        });
        _showSnackBar('点赞失败: $e');
      }
    }
  }

  void _showNotInterested() {
    widget.onNotInterested?.call();
    _showSnackBar('已标记不感兴趣，将减少类似内容');
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
    try {
      await ApiService.shareMomentToCatway(widget.moment.id);
      _showSnackBar('已转发到个人动态');
    } catch (e) {
      _showSnackBar('转发失败: $e');
    }
  }

  void _shareToOther(String platform) {
    final shareText =
        '【${widget.moment.userName}】分享了一条动态：${widget.moment.content}\n来自猫径CatWay App 下载：https://theregolithjar.monster/downloads/app-release.apk';
    Share.share(shareText, subject: '猫径CatWay动态分享');
    _showSnackBar('已分享到$platform');
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _deleteMoment() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('删除后不可恢复，确定要删除这条动态吗？'),
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
      await ApiService.deleteMoment(widget.moment.id);
      if (mounted) {
        _showSnackBar('动态已删除');
        widget.onDelete?.call();
      }
    } catch (e) {
      if (mounted) _showSnackBar('删除失败: $e');
    }
  }

  void _showMenu() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = auth.user?.id;
    final isOwnMoment = currentUserId == widget.moment.userId;
    final canDelete = isOwnMoment || (auth.user?.role == 'admin');

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => GlassBottomSheet(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isOwnMoment)
              ListTile(
                leading: const Icon(Icons.thumb_down, color: const Color(0xFFB8860B)),
                title: const Text('不感兴趣'),
                onTap: () {
                  Navigator.pop(context);
                  _showNotInterested();
                },
              ),
            if (!isOwnMoment)
              ListTile(
                leading: const Icon(Icons.report, color: const Color(0xFFB8860B)),
                title: const Text('举报'),
                onTap: () {
                  Navigator.pop(context);
                  _showSnackBar('举报功能开发中');
                },
              ),
            if (canDelete)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('删除', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _deleteMoment();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _loadTopComments() async {
    setState(() => _loadingComments = true);
    try {
      final comments = await ApiService.getTopComments(widget.moment.id);
      setState(() {
        _topComments = comments;
        _loadingComments = false;
        _hasMoreComments = comments.length == _commentLimit;
      });
    } catch (e) {
      setState(() => _loadingComments = false);
      _showSnackBar('加载评论失败: $e');
    }
  }

  Future<void> _loadMoreComments() async {
    if (!_hasMoreComments) return;
    setState(() => _loadingComments = true);
    try {
      final data = await ApiService.getMoreComments(widget.moment.id,
          page: _commentPage + 1, limit: _commentLimit);
      final newComments = (data['comments'] as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      setState(() {
        _topComments.addAll(newComments);
        _commentPage++;
        _hasMoreComments = newComments.length == _commentLimit;
        _loadingComments = false;
      });
    } catch (e) {
      setState(() => _loadingComments = false);
      _showSnackBar('加载更多失败: $e');
    }
  }

  Future<void> _sendComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty) {
      _showSnackBar('请输入评论内容');
      return;
    }
    try {
      await ApiService.addMomentComment(widget.moment.id, content);
      _commentController.clear();
      await _loadTopComments();
      widget.onCommentChanged?.call();
      _showSnackBar('评论发送成功');
    } catch (e) {
      _showSnackBar('发送失败: $e');
    }
  }

  Future<void> _likeComment(String commentId, bool isLiked) async {
    if (isLiked) return;
    try {
      await ApiService.likeMomentComment(commentId);
      setState(() {
        final index = _topComments.indexWhere((c) => c['id'] == commentId);
        if (index != -1) {
          _topComments[index]['isLiked'] = true;
          _topComments[index]['likesCount'] =
              (_topComments[index]['likesCount'] as int) + 1;
        }
      });
    } catch (e) {
      _showSnackBar('点赞失败: $e');
    }
  }

  void _scrollToComments() {
    setState(() => _showComments = true);
    if (!_loadingComments && _topComments.isEmpty) _loadTopComments();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_commentScrollController.hasClients) {
        _commentScrollController.animateTo(
          _commentScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
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
    final isOwnMoment = currentUserId == widget.moment.userId;

    return GlassContainer(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.transparent,
                  backgroundImage: widget.moment.userAvatar.isNotEmpty
                      ? NetworkImage(widget.moment.userAvatar)
                      : null,
                  child: widget.moment.userAvatar.isEmpty
                      ? const Icon(Icons.person, color: const Color(0xFFB8860B))
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.moment.userName,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('@${widget.moment.userAccount}',
                          style: const TextStyle(
                              fontSize: 12, color: const Color(0xFFB8860B))),
                    ],
                  ),
                ),
                if (!isOwnMoment)
                  TextButton(
                    onPressed: _isFollowingLoading ? null : _toggleFollow,
                    style: TextButton.styleFrom(
                        foregroundColor: _isFollowing
                            ? const Color(0xFFB8860B)
                            : const Color(0xFFB8860B)),
                    child: Text(_isFollowing ? '已关注' : '关注'),
                  ),
                IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: _showMenu,
                  tooltip: '更多',
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_contentWidgets.isNotEmpty) ...[
              ..._contentWidgets,
              const SizedBox(height: 8),
            ],
            if (widget.moment.images.isNotEmpty)
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3, crossAxisSpacing: 4, mainAxisSpacing: 4),
                itemCount: widget.moment.images.length,
                itemBuilder: (context, index) => GestureDetector(
                  onTap: () => showDialog(
                      context: context,
                      builder: (_) => Dialog(
                          child: Image.network(widget.moment.images[index]))),
                  child: Image.network(widget.moment.images[index],
                      fit: BoxFit.cover),
                ),
              ),
            const SizedBox(height: 8),
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
                      Text('${widget.moment.commentCount}'),
                    ],
                  ),
                ),
                InkWell(
                  onTap: _showShareOptions,
                  child: Row(
                    children: [
                      const Icon(Icons.share, size: 20, color: const Color(0xFFB8860B)),
                      const SizedBox(width: 4),
                      Text('${widget.moment.shareCount}'),
                    ],
                  ),
                ),
              ],
            ),
            if (_showComments) ...[
              const Divider(height: 16),
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
                            horizontal: 12, vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                      icon: const Icon(Icons.send), onPressed: _sendComment),
                ],
              ),
              const SizedBox(height: 8),
              if (_loadingComments && _topComments.isEmpty)
                const Center(child: CircularProgressIndicator())
              else if (_topComments.isEmpty)
                const Center(child: Text('暂无评论，快来抢沙发吧～'))
              else
                Column(
                  children: [
                    ..._topComments.map((comment) {
                      final isLiked = comment['isLiked'] ?? false;
                      final likesCount = comment['likesCount'] ?? 0;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.transparent,
                          backgroundImage: comment['avatar'] != null &&
                                  comment['avatar'].isNotEmpty
                              ? NetworkImage(comment['avatar'])
                              : null,
                          child: comment['avatar'] == null ||
                                  comment['avatar'].isEmpty
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
                                  isLiked
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  size: 16,
                                  color: isLiked ? Colors.red : null),
                              onPressed: () => _likeComment(
                                  comment['id'].toString(), isLiked),
                            ),
                            Text('$likesCount'),
                          ],
                        ),
                      );
                    }),
                    if (_hasMoreComments)
                      TextButton(
                          onPressed: _loadMoreComments,
                          child: const Text('展开更多评论')),
                    if (_loadingComments && _topComments.isNotEmpty)
                      const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Center(child: CircularProgressIndicator())),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }
}
