import 'dart:async';
import 'package:flutter/material.dart';
import 'package:amap_flutter_map/amap_flutter_map.dart';
import 'package:amap_flutter_base/amap_flutter_base.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/navigation_service.dart';
import '../../services/api_service.dart';
import '../../widgets/glass_container.dart';

class SearchNavigationPanel extends StatefulWidget {
  final AMapController mapController;
  final Function(LatLng, LatLng, List<LatLng>?) onNavigate;

  const SearchNavigationPanel({
    super.key,
    required this.mapController,
    required this.onNavigate,
  });

  @override
  SearchNavigationPanelState createState() => SearchNavigationPanelState();
}

class SearchNavigationPanelState extends State<SearchNavigationPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final TextEditingController _currentDestController = TextEditingController();
  List<dynamic> _currentDestResults = [];
  bool _isSearchingCurrent = false;
  LatLng? _selectedCurrentDest;
  Timer? _currentDebounce;

  final TextEditingController _specStartController = TextEditingController();
  final TextEditingController _specEndController = TextEditingController();
  List<dynamic> _specStartResults = [];
  List<dynamic> _specEndResults = [];
  bool _isSearchingStart = false;
  bool _isSearchingEnd = false;
  LatLng? _selectedSpecStart;
  LatLng? _selectedSpecEnd;
  Timer? _startDebounce;
  Timer? _endDebounce;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    _currentDestController.addListener(() {
      _currentDebounce?.cancel();
      _currentDebounce = Timer(const Duration(milliseconds: 500), () {
        _searchPOI(_currentDestController.text, (r) {
          setState(() => _currentDestResults = r);
        }, (loading) {
          setState(() => _isSearchingCurrent = loading);
        });
      });
    });
    _specStartController.addListener(() {
      _startDebounce?.cancel();
      _startDebounce = Timer(const Duration(milliseconds: 500), () {
        _searchPOI(_specStartController.text, (r) {
          setState(() => _specStartResults = r);
        }, (loading) {
          setState(() => _isSearchingStart = loading);
        });
      });
    });
    _specEndController.addListener(() {
      _endDebounce?.cancel();
      _endDebounce = Timer(const Duration(milliseconds: 500), () {
        _searchPOI(_specEndController.text, (r) {
          setState(() => _specEndResults = r);
        }, (loading) {
          setState(() => _isSearchingEnd = loading);
        });
      });
    });
  }

  @override
  void dispose() {
    _currentDebounce?.cancel();
    _startDebounce?.cancel();
    _endDebounce?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _searchPOI(
    String keyword,
    void Function(List<dynamic>) setResults,
    void Function(bool) setLoading,
  ) async {
    if (keyword.trim().isEmpty) {
      setResults([]);
      return;
    }
    setLoading(true);
    try {
      final response = await ApiService.searchPOI(keyword);
      if (response['status'] == '1') {
        setResults(response['pois'] ?? []);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response['info'] ?? '搜索失败')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('搜索出错: $e')),
        );
      }
    } finally {
      setLoading(false);
    }
  }

  Future<void> _navigateFromCurrent() async {
    if (_selectedCurrentDest == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择终点')),
      );
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('需要位置权限')),
      );
      return;
    }
    final Position currentPos = await Geolocator.getCurrentPosition();
    final LatLng start = LatLng(currentPos.latitude, currentPos.longitude);
    final LatLng end = _selectedCurrentDest!;

    final origin = '${start.longitude},${start.latitude}';
    final dest = '${end.longitude},${end.latitude}';

    try {
      final data = await NavigationService.getDrivingRoute(
        origin: origin,
        destination: dest,
      );
      if (data['status'] == '1' && data['route']['paths'].isNotEmpty) {
        final path = data['route']['paths'][0];
        final steps = path['steps'] as List;
        final List<LatLng> routePoints = [];
        for (var step in steps) {
          final polyline = step['polyline'] as String;
          final coords = polyline.split(';');
          for (var coord in coords) {
            final parts = coord.split(',');
            if (parts.length == 2) {
              routePoints.add(
                LatLng(double.parse(parts[1]), double.parse(parts[0])),
              );
            }
          }
        }
        widget.onNavigate(start, end, routePoints);
        if (mounted) Navigator.pop(context);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('未找到路线')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导航失败: $e')),
      );
    }
  }

  Future<void> _navigateFromSpec() async {
    if (_selectedSpecStart == null || _selectedSpecEnd == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择起点和终点')),
      );
      return;
    }

    final origin =
        '${_selectedSpecStart!.longitude},${_selectedSpecStart!.latitude}';
    final dest = '${_selectedSpecEnd!.longitude},${_selectedSpecEnd!.latitude}';

    try {
      final data = await NavigationService.getDrivingRoute(
        origin: origin,
        destination: dest,
      );
      if (data['status'] == '1' && data['route']['paths'].isNotEmpty) {
        final path = data['route']['paths'][0];
        final steps = path['steps'] as List;
        final List<LatLng> routePoints = [];
        for (var step in steps) {
          final polyline = step['polyline'] as String;
          final coords = polyline.split(';');
          for (var coord in coords) {
            final parts = coord.split(',');
            if (parts.length == 2) {
              routePoints.add(
                LatLng(double.parse(parts[1]), double.parse(parts[0])),
              );
            }
          }
        }
        widget.onNavigate(_selectedSpecStart!, _selectedSpecEnd!, routePoints);
        if (mounted) Navigator.pop(context);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('未找到路线')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导航失败: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 固定高度为屏幕高度的 75%
    return GlassContainer(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.zero,
      customRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      tintColor: Colors.white,
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
        children: [
          Container(
            height: 4,
            width: 40,
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          TabBar(
            controller: _tabController,
            labelColor: const Color(0xFFB8860B),
            unselectedLabelColor: const Color(0xFFB8860B),
            indicatorColor: const Color(0xFFB8860B),
            tabs: const [
              Tab(text: '当前位置导航'),
              Tab(text: '指定起点导航'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildCurrentLocationTab(),
                _buildSpecifiedLocationTab(),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildCurrentLocationTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            controller: _currentDestController,
            decoration: const InputDecoration(
              hintText: '输入终点',
              suffixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 12),
          if (_isSearchingCurrent)
            const Center(child: CircularProgressIndicator())
          else
            Expanded(
              child: ListView.builder(
                itemCount: _currentDestResults.length,
                itemBuilder: (context, index) {
                  final poi = _currentDestResults[index];
                  return ListTile(
                    title: Text(poi['name'] ?? ''),
                    subtitle: Text(poi['address'] ?? ''),
                    onTap: () {
                      final lng = double.parse(poi['location'].split(',')[0]);
                      final lat = double.parse(poi['location'].split(',')[1]);
                      setState(() {
                        _selectedCurrentDest = LatLng(lat, lng);
                        _currentDestController.text = poi['name'] ?? '';
                        _currentDestResults.clear();
                      });
                    },
                  );
                },
              ),
            ),
          const Spacer(),
          ElevatedButton(
            onPressed: _navigateFromCurrent,
            child: const Text('开始导航'),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecifiedLocationTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            controller: _specStartController,
            decoration: const InputDecoration(
              hintText: '输入起点',
              suffixIcon: Icon(Icons.search),
            ),
          ),
          if (_isSearchingStart)
            const Center(child: CircularProgressIndicator())
          else
            Expanded(
              child: ListView.builder(
                itemCount: _specStartResults.length,
                itemBuilder: (context, index) {
                  final poi = _specStartResults[index];
                  return ListTile(
                    title: Text(poi['name'] ?? ''),
                    subtitle: Text(poi['address'] ?? ''),
                    onTap: () {
                      final lng = double.parse(poi['location'].split(',')[0]);
                      final lat = double.parse(poi['location'].split(',')[1]);
                      setState(() {
                        _selectedSpecStart = LatLng(lat, lng);
                        _specStartController.text = poi['name'] ?? '';
                        _specStartResults.clear();
                      });
                    },
                  );
                },
              ),
            ),
          const Divider(),
          TextField(
            controller: _specEndController,
            decoration: const InputDecoration(
              hintText: '输入终点',
              suffixIcon: Icon(Icons.search),
            ),
          ),
          if (_isSearchingEnd)
            const Center(child: CircularProgressIndicator())
          else
            Expanded(
              child: ListView.builder(
                itemCount: _specEndResults.length,
                itemBuilder: (context, index) {
                  final poi = _specEndResults[index];
                  return ListTile(
                    title: Text(poi['name'] ?? ''),
                    subtitle: Text(poi['address'] ?? ''),
                    onTap: () {
                      final lng = double.parse(poi['location'].split(',')[0]);
                      final lat = double.parse(poi['location'].split(',')[1]);
                      setState(() {
                        _selectedSpecEnd = LatLng(lat, lng);
                        _specEndController.text = poi['name'] ?? '';
                        _specEndResults.clear();
                      });
                    },
                  );
                },
              ),
            ),
          const Spacer(),
          ElevatedButton(
            onPressed: _navigateFromSpec,
            child: const Text('开始导航'),
          ),
        ],
      ),
    );
  }
}
