import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/glass_container.dart';
import 'profile_edit_screen.dart';
import 'followers_following_screen.dart';
import 'collections_screen.dart';
import 'history_screen.dart';
import 'checkins_screen.dart';
import 'strategies_screen.dart';
import 'settings_screen.dart';
import 'user_moments_screen.dart';
import 'my_places_screen.dart';
import 'notifications_screen.dart';
import '../../services/api_service.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:async';

class ProfileScreen extends StatefulWidget {
  final String? userId;
  const ProfileScreen({super.key, this.userId});

  @override
  ProfileScreenState createState() => ProfileScreenState();
}

class ProfileScreenState extends State<ProfileScreen> {
  bool _isOwnProfile = true;
  int _momentsCount = 0;

  // 背景亮度检测：true=暗色背景用白字，false=亮色背景用金字
  bool _useWhiteText = true;
  bool _analyzingImage = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserData();
    });
  }

  Future<void> _loadUserData() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final targetId = widget.userId ?? auth.user?.id;
    if (targetId == null) return;
    _isOwnProfile = targetId == auth.user?.id;
    try {
      await Provider.of<UserProvider>(context, listen: false)
          .fetchUserProfile(targetId);
      await _loadMomentsCount(targetId);
      // 获取用户数据后检测背景图亮度
      if (mounted) {
        final userP = Provider.of<UserProvider>(context, listen: false).user;
        if (userP != null && userP.coverImage.isNotEmpty) {
          _analyzeCoverBrightness(userP.coverImage);
        } else {
          // 无封面图→默认暗色渐变背景→用白字
          setState(() => _useWhiteText = true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载用户信息失败: $e')),
        );
      }
    }
  }

  /// 分析封面图平均亮度，决定文字颜色
  Future<void> _analyzeCoverBrightness(String imageUrl) async {
    if (_analyzingImage) return;
    setState(() => _analyzingImage = true);
    try {
      final imageProvider = NetworkImage(imageUrl);
      final completer = Completer<ui.Image>();
      final stream = imageProvider.resolve(ImageConfiguration.empty);
      stream.addListener(ImageStreamListener((ImageInfo info, bool _) {
        if (!completer.isCompleted) completer.complete(info.image);
      }, onError: (Object e, StackTrace? s) {
        if (!completer.isCompleted) completer.completeError(e);
      }));
      final ui.Image image = await completer.future;
      stream.removeListener(ImageStreamListener((_, __) {}, onError: (_, __) {}));

      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null || !mounted) return;

      // 采样像素计算亮度
      final bytes = byteData.buffer.asUint8List();
      final w = image.width;
      final h = image.height;
      int totalLuminance = 0;
      int sampleCount = 0;

      // 采样步长：大图每10px采一个，避免性能问题
      final step = (w > 200) ? 10 : 2;
      for (int y = 0; y < h; y += step) {
        for (int x = 0; x < w; x += step) {
          final idx = (y * w + x) * 4; // RGBA
          if (idx + 2 < bytes.length) {
            final r = bytes[idx];
            final g = bytes[idx + 1];
            final b = bytes[idx + 2];
            // 相对亮度公式 (ITU-R BT.709)
            totalLuminance += (r * 299 + g * 587 + b * 114) ~/ 1000;
            sampleCount++;
          }
        }
      }

      if (sampleCount > 0 && mounted) {
        final avgBrightness = totalLuminance ~/ sampleCount;
        // 阈值128：低于此值视为暗色背景→白字；高于此值→金字
        setState(() => _useWhiteText = avgBrightness < 130);
      }
      image.dispose();
    } catch (e) {
      // 分析失败默认用白字（暗色背景更常见）
      if (mounted) setState(() => _useWhiteText = true);
    } finally {
      if (mounted) setState(() => _analyzingImage = false);
    }
  }

  Future<void> _refreshData() async {
    await _loadUserData();
  }

  Future<void> _loadMomentsCount(String userId) async {
    try {
      final count = await ApiService.getUserMomentsCount(userId);
      if (mounted) setState(() => _momentsCount = count);
    } catch (e) {
      debugPrint('获取动态数失败: $e');
    }
  }

  void _navigateToEditProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfileEditScreen()),
    ).then((_) => _refreshData());
  }

  void _navigateToFollowers() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final targetUserId = widget.userId ?? auth.user?.id;
    if (targetUserId == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            FollowersFollowingScreen(userId: targetUserId, isFollowers: true),
      ),
    );
  }

  void _navigateToFollowing() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final targetUserId = widget.userId ?? auth.user?.id;
    if (targetUserId == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            FollowersFollowingScreen(userId: targetUserId, isFollowers: false),
      ),
    );
  }

  void _navigateToCollections() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CollectionsScreen()),
    );
  }

  void _navigateToHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HistoryScreen()),
    );
  }

  void _navigateToCheckins() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CheckinsScreen()),
    );
  }

  void _navigateToStrategies() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const StrategiesScreen()),
    );
  }

  void _navigateToSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

  void _navigateToUserMoments() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final targetUserId = widget.userId ?? auth.user?.id;
    if (targetUserId == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserMomentsScreen(userId: targetUserId),
      ),
    );
  }

  void _navigateToMyPlaces() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MyPlacesScreen()),
    );
  }

  void _navigateToNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final user = userProvider.user;
    final isLoading = userProvider.isLoading;

    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (user == null) {
      return const Scaffold(body: Center(child: Text('用户不存在')));
    }

    final hasCover = user.coverImage.isNotEmpty;
    final topPadding =
        MediaQuery.of(context).padding.top + 20;

    // 根据背景亮度动态选择颜色方案
    final textColor = _useWhiteText ? Colors.white : const Color(0xFFB8860B);
    final subtitleColor = _useWhiteText ? Colors.white70 : const Color(0xFF9C7A1E);
    final iconColor = _useWhiteText ? Colors.white70 : const Color(0xFFB8860B);
    final buttonBorderColor = _useWhiteText ? Colors.white60 : const Color(0xFFB8860B);
    final buttonTextColor = _useWhiteText ? Colors.white : const Color(0xFFB8860B);
    final glassTint = _useWhiteText
        ? Colors.white.withOpacity(0.10)
        : Colors.white.withOpacity(0.16);

    return Scaffold(
      body: Stack(
        children: [
          // 背景层
          if (hasCover)
            Positioned.fill(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 深色底层：当 coverImage 是透明底图片时显示渐变背景
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF1b2240), Color(0xFF3a2a4d)],
                      ),
                    ),
                  ),
                  Image.network(
                    user.coverImage,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF1b2240), Color(0xFF3a2a4d)],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1b2240), Color(0xFF3a2a4d)],
                  ),
                ),
              ),
            ),
          // 半透明遮罩（亮色背景时加深，保证文字可读）
          if (hasCover)
            Positioned.fill(
              child: Container(
                color: _useWhiteText
                    ? Colors.black.withOpacity(0.45)
                    : Colors.black.withOpacity(0.30),
              ),
            ),
          // 主内容
          RefreshIndicator(
            onRefresh: _refreshData,
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                SizedBox(height: topPadding),
                // 头像 + 昵称 + 编辑按钮
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: user.avatar.isNotEmpty
                            ? Image.network(
                                user.avatar,
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 80,
                                  height: 80,
                                  color: _useWhiteText ? Colors.white24 : Colors.white,
                                  child: Icon(Icons.person,
                                      size: 50, color: textColor),
                                ),
                              )
                            : Container(
                                width: 80,
                                height: 80,
                                color: _useWhiteText ? Colors.white24 : Colors.white,
                                child: Icon(Icons.person,
                                    size: 50, color: textColor),
                              ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.nickname,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '@${user.username}',
                              style: TextStyle(color: subtitleColor),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              user.bio.isNotEmpty ? user.bio : '这个人很懒，什么都没写',
                              style: TextStyle(color: subtitleColor),
                            ),
                          ],
                        ),
                      ),
                      if (_isOwnProfile)
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: buttonTextColor,
                            side: BorderSide(color: buttonBorderColor),
                          ),
                          onPressed: _navigateToEditProfile,
                          child: const Text('编辑资料'),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // 统计栏 — 毛玻璃
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: GlassContainer(
                    tintColor: glassTint,
                    borderRadius: 16,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _statItem('$_momentsCount', '动态', textColor,
                            subtitleColor,
                            onTap: _navigateToUserMoments),
                        _statItem('${user.followersCount}', '粉丝', textColor,
                            subtitleColor,
                            onTap: _navigateToFollowers),
                        _statItem('${user.followingCount}', '关注', textColor,
                            subtitleColor,
                            onTap: _navigateToFollowing),
                        _statItem('${user.likesReceived}', '获赞', textColor,
                            subtitleColor),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // 功能菜单 — 毛玻璃
                if (_isOwnProfile) ...[
                  _menuItem(Icons.notifications, '通知', iconColor, textColor,
                      subtitleColor, _navigateToNotifications, glassTint),
                  _menuItem(Icons.bookmark, '我的标点', iconColor, textColor,
                      subtitleColor, _navigateToMyPlaces, glassTint),
                ],
                _menuItem(Icons.favorite, '收藏夹', iconColor, textColor,
                    subtitleColor, _navigateToCollections, glassTint),
                _menuItem(Icons.article, '我的攻略', iconColor, textColor,
                    subtitleColor, _navigateToStrategies, glassTint),
                _menuItem(Icons.history, '浏览历史', iconColor, textColor,
                    subtitleColor, _navigateToHistory, glassTint),
                _menuItem(Icons.check_circle, '已打卡', iconColor, textColor,
                    subtitleColor, _navigateToCheckins, glassTint),
                if (_isOwnProfile)
                  _menuItem(Icons.settings, '设置', iconColor, textColor,
                      subtitleColor, _navigateToSettings, glassTint),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statItem(
      String value, String label, Color textColor, Color labelColor,
      {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(color: labelColor),
          ),
        ],
      ),
    );
  }

  Widget _menuItem(IconData icon, String title, Color iconColor,
      Color textColor, Color trailingColor, VoidCallback onTap,
      Color glassTint) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: GlassContainer(
        tintColor: glassTint,
        borderRadius: 12,
        child: ListTile(
          leading: Icon(icon, color: iconColor),
          title: Text(title, style: TextStyle(color: textColor)),
          trailing: Icon(Icons.chevron_right, color: trailingColor),
          onTap: onTap,
        ),
      ),
    );
  }
}
