import 'package:flutter/material.dart';
import 'search_screen.dart';
import 'strategy_screen.dart';
import 'review_screen.dart';
import 'chat_screen.dart';
import 'create_post_screen.dart';
import 'create_moment_screen.dart';
import '../../services/api_service.dart';
import '../../models/moment.dart';
import '../../widgets/moment_card.dart';
import '../../services/config_service.dart';
import '../../widgets/glass_container.dart';

class ForumScreen extends StatefulWidget {
  const ForumScreen({super.key});

  @override
  ForumScreenState createState() => ForumScreenState();
}

class ForumScreenState extends State<ForumScreen> {
  int _currentTab = 0;

  List<Moment> _moments = [];
  bool _loadingMoments = true;
  bool _hasMoreMoments = true;
  int _momentPage = 1;
  final int _momentLimit = 10;
  final ScrollController _momentScrollController = ScrollController();

  // 为攻略区和闲聊区添加 GlobalKey，以便调用其刷新方法
  final GlobalKey<StrategyScreenState> _strategyKey = GlobalKey();
  final GlobalKey<ChatScreenState> _chatKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadMoments();
    _momentScrollController.addListener(_onMomentScroll);
  }

  void _onMomentScroll() {
    if (_currentTab == 0 &&
        _momentScrollController.position.pixels >=
            _momentScrollController.position.maxScrollExtent - 200 &&
        !_loadingMoments &&
        _hasMoreMoments) {
      _loadMoreMoments();
    }
  }

  Future<void> _loadMoments({bool reset = true}) async {
    if (reset) {
      setState(() {
        _moments = [];
        _momentPage = 1;
        _hasMoreMoments = true;
        _loadingMoments = true;
      });
    } else {
      setState(() => _loadingMoments = true);
    }
    try {
      final data =
          await ApiService.getMoments(page: _momentPage, limit: _momentLimit);
      final newMoments = (data['moments'] as List)
          .map((json) => Moment.fromJson(json))
          .toList();
      setState(() {
        if (reset) {
          _moments = newMoments;
        } else {
          _moments.addAll(newMoments);
        }
        _hasMoreMoments = newMoments.length == _momentLimit;
        _momentPage++;
        _loadingMoments = false;
      });
    } catch (e) {
      setState(() => _loadingMoments = false);
      debugPrint('加载动态失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载动态失败: $e')),
        );
      }
    }
  }

  Future<void> _loadMoreMoments() async {
    if (!_hasMoreMoments) return;
    await _loadMoments(reset: false);
  }

  Future<void> _refreshMoments() async {
    await _loadMoments(reset: true);
  }

  // 不感兴趣：从列表中移除该动态
  void _removeMoment(String momentId) {
    setState(() {
      _moments.removeWhere((m) => m.id == momentId);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已标记不感兴趣，将减少类似内容')),
    );
  }

  void _onFabPressed() {
    if (_currentTab == 0) {
      // 发布动态
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CreateMomentScreen()),
      ).then((_) => _refreshMoments());
    } else if (_currentTab == 1) {
      // 发布攻略
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => const CreatePostScreen(initialCategory: '攻略')),
      ).then((_) {
        _strategyKey.currentState?.applyFilters();
      });
    } else {
      // 发布闲聊
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => const CreatePostScreen(initialCategory: '闲聊')),
      ).then((_) {
        _chatKey.currentState?.refresh();
      });
    }
  }

  @override
  void dispose() {
    _momentScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: const GlassAppBarBackground(),
        title: const Text('广场'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SearchScreen()),
            ),
          ),
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(context).openEndDrawer(),
            ),
          ),
        ],
      ),
      endDrawer: SizedBox(
        width: MediaQuery.of(context).size.width * 0.6,
        child: GlassContainer(
          margin: EdgeInsets.zero,
          padding: EdgeInsets.zero,
          borderRadius: 0,
          tintColor: Colors.white,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
                child: const Text('分区导航',
                    style: TextStyle(
                        color: Color(0xFFB8860B),
                        fontSize: 24,
                        fontWeight: FontWeight.bold)),
              ),
              ListTile(
                leading: const Icon(Icons.feed, color: Color(0xFFB8860B)),
                title:
                    const Text('动态', style: TextStyle(color: Color(0xFFB8860B))),
                selected: _currentTab == 0,
                selectedTileColor: Color(0xFFB8860B).withOpacity(0.15),
                onTap: () {
                  setState(() => _currentTab = 0);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.map, color: Color(0xFFB8860B)),
                title:
                    const Text('攻略', style: TextStyle(color: Color(0xFFB8860B))),
                selected: _currentTab == 1,
                selectedTileColor: Color(0xFFB8860B).withOpacity(0.15),
                onTap: () {
                  setState(() => _currentTab = 1);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.chat, color: Color(0xFFB8860B)),
                title:
                    const Text('闲聊', style: TextStyle(color: Color(0xFFB8860B))),
                selected: _currentTab == 2,
                selectedTileColor: Color(0xFFB8860B).withOpacity(0.15),
                onTap: () {
                  setState(() => _currentTab = 2);
                  Navigator.pop(context);
                },
              ),
              Divider(color: Color(0xFFB8860B).withOpacity(0.25)),
              if (ConfigService.showReviewTab)
                ListTile(
                  leading: const Icon(Icons.verified, color: Color(0xFFB8860B)),
                  title: const Text('审核区',
                      style: TextStyle(color: Color(0xFFB8860B))),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ReviewScreen()),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
      body: IndexedStack(
        index: _currentTab,
        children: [
          // 动态列表
          _loadingMoments && _moments.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _moments.isEmpty
                  ? const Center(child: Text('暂无动态，发布第一条吧~'))
                  : RefreshIndicator(
                      onRefresh: _refreshMoments,
                      child: ListView.builder(
                        controller: _momentScrollController,
                        itemCount: _moments.length + (_hasMoreMoments ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _moments.length) {
                            return const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          return MomentCard(
                            moment: _moments[index],
                            onDelete: () => _refreshMoments(),
                            onFollowChanged: () => _refreshMoments(),
                            onNotInterested: () =>
                                _removeMoment(_moments[index].id),
                          );
                        },
                      ),
                    ),
          // 攻略区（传入 GlobalKey）
          StrategyScreen(key: _strategyKey),
          // 闲聊区（传入 GlobalKey）
          ChatScreen(key: _chatKey),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _onFabPressed,
        tooltip: _currentTab == 0 ? '发布动态' : '发布帖子',
        child: _currentTab == 0
            ? const Icon(Icons.edit_note)
            : const Icon(Icons.add),
      ),
    );
  }
}
