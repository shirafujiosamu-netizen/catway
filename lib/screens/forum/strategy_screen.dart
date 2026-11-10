import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/post.dart';
import '../../widgets/post_card.dart';
import '../../services/config_service.dart';
import '../../widgets/glass_container.dart';

class StrategyScreen extends StatefulWidget {
  const StrategyScreen({super.key});

  @override
  StrategyScreenState createState() => StrategyScreenState();
}

class StrategyScreenState extends State<StrategyScreen> {
  Set<String> selectedIPs = {};
  Set<String> selectedProductTypes = {};
  Set<String> selectedShopTypes = {};

  List<Post> _posts = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 1;
  final int _limit = ConfigService.strategyDefaultLimit;
  final ScrollController _scrollController = ScrollController();

  List<String> allIPs = [];
  List<String> allProductTypes = [];
  List<String> allShopTypes = [];

  bool _loadingFilters = true;
  String _searchKeyword = '';

  final List<String> _fallbackIPs = ['败犬女主', '邦多利', '明日方舟', '咒术回战', '崩铁'];
  final List<String> _fallbackProductTypes = [
    '吧唧',
    '亚克力挂件',
    '亚克力摆件',
    '亚克力立牌',
    '手办',
    '色纸',
    '镭射票',
    '毛绒玩偶',
    'Lolita',
    '扭蛋',
    '汉服',
    'jk制服'
  ];
  final List<String> _fallbackShopTypes = ['谷店', '牌店', '快闪', '主题餐厅', '桌游店'];

  @override
  void initState() {
    super.initState();
    _loadFilters();
    _fetchPosts(reset: true);
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        _hasMore) {
      _fetchPosts(reset: false);
    }
  }

  Future<void> _loadFilters() async {
    try {
      final ips = await ApiService.getIpCategories();
      final products = await ApiService.getProductTypes();
      final shops = await ApiService.getShopTypes();

      setState(() {
        allIPs = ips.isNotEmpty ? ips : _fallbackIPs;
        allProductTypes =
            products.isNotEmpty ? products : _fallbackProductTypes;
        allShopTypes = shops.isNotEmpty ? shops : _fallbackShopTypes;
        _loadingFilters = false;
      });
    } catch (e) {
      debugPrint('加载筛选选项失败: $e，使用硬编码列表');
      setState(() {
        allIPs = _fallbackIPs;
        allProductTypes = _fallbackProductTypes;
        allShopTypes = _fallbackShopTypes;
        _loadingFilters = false;
      });
    }
  }

  Future<void> _fetchPosts({bool reset = true}) async {
    if (_isLoading) return;
    if (reset) {
      setState(() {
        _posts = [];
        _currentPage = 1;
        _hasMore = true;
        _isLoading = true;
      });
    } else {
      setState(() => _isLoading = true);
    }

    try {
      final data = await ApiService.getStrategyPosts(
        ipList: selectedIPs.toList(),
        productTypeList: selectedProductTypes.toList(),
        shopTypeList: selectedShopTypes.toList(),
        search: _searchKeyword.isEmpty ? null : _searchKeyword,
        page: _currentPage,
        limit: _limit,
      );
      final List<Post> newPosts =
          (data['posts'] as List).map((json) => Post.fromJson(json)).toList();
      setState(() {
        if (reset) {
          _posts = newPosts;
        } else {
          _posts.addAll(newPosts);
        }
        _hasMore = newPosts.length == _limit;
        _currentPage++;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e')),
        );
      }
    }
  }

  // 改为 public，供外部调用刷新
  Future<void> applyFilters() async {
    setState(() {
      _posts = [];
      _currentPage = 1;
      _hasMore = true;
    });
    await _fetchPosts(reset: true);
  }

  Future<void> _showFilterDialog({
    required String title,
    required Set<String> selectedValues,
    required List<String> allValues,
    required Function(Set<String>) onConfirm,
  }) async {
    Set<String> tempSelected = Set.from(selectedValues);
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.8,
          child: StatefulBuilder(
            builder: (context, setStateDialog) {
              return ListView(
                shrinkWrap: true,
                children: allValues.map((value) {
                  return CheckboxListTile(
                    title: Text(value),
                    value: tempSelected.contains(value),
                    onChanged: (checked) {
                      setStateDialog(() {
                        if (checked == true) {
                          tempSelected.add(value);
                        } else {
                          tempSelected.remove(value);
                        }
                      });
                    },
                  );
                }).toList(),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              onConfirm(tempSelected);
              Navigator.pop(context);
              applyFilters();
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton(
    String label,
    Set<String> selectedValues,
    List<String> allValues,
    Function(Set<String>) onConfirm,
  ) {
    return TextButton(
      onPressed: () => _showFilterDialog(
        title: label,
        selectedValues: selectedValues,
        allValues: allValues,
        onConfirm: onConfirm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label${selectedValues.isNotEmpty ? ' (${selectedValues.length})' : ''}',
            style: const TextStyle(fontSize: 14),
          ),
          const Icon(Icons.arrow_drop_down, size: 18),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingFilters) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        GlassContainer(
          margin: const EdgeInsets.all(8.0),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          borderRadius: 30,
          tintColor: Colors.white,
          child: TextField(
            decoration: InputDecoration(
              hintText: '搜索标题、内容或关键词...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchKeyword.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _searchKeyword = '';
                        });
                        applyFilters();
                      },
                    )
                  : null,
              border: InputBorder.none,
            ),
            onChanged: (value) {
              setState(() {
                _searchKeyword = value;
              });
              applyFilters();
            },
          ),
        ),
        GlassContainer(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          padding: const EdgeInsets.symmetric(vertical: 8),
          borderRadius: 16,
          tintColor: Colors.white,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildFilterButton('IP', selectedIPs, allIPs, (newSet) {
                setState(() => selectedIPs = newSet);
              }),
              _buildFilterButton('商品', selectedProductTypes, allProductTypes,
                  (newSet) {
                setState(() => selectedProductTypes = newSet);
              }),
              _buildFilterButton('店铺', selectedShopTypes, allShopTypes,
                  (newSet) {
                setState(() => selectedShopTypes = newSet);
              }),
            ],
          ),
        ),
        Expanded(
          child: _isLoading && _posts.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _posts.isEmpty
                  ? const Center(child: Text('没有符合条件的攻略'))
                  : RefreshIndicator(
                      onRefresh: applyFilters,
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
                              applyFilters();
                            },
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }
}
