import 'package:flutter/material.dart';
import '../../models/place.dart';
import '../../services/api_service.dart';
import '../home/place_detail_screen.dart';
import '../../widgets/glass_container.dart';

class MyPlacesScreen extends StatefulWidget {
  const MyPlacesScreen({super.key});

  @override
  MyPlacesScreenState createState() => MyPlacesScreenState();
}

class MyPlacesScreenState extends State<MyPlacesScreen> {
  List<Place> _pendingPlaces = [];
  List<Place> _approvedPlaces = [];
  List<Place> _adminReviewPlaces = [];
  List<Place> _rejectedPlaces = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserPlaces();
  }

  Future<void> _loadUserPlaces() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.getUserPlaces();
      setState(() {
        _pendingPlaces = (data['pending'] as List?)
                ?.map((e) => Place.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [];
        _approvedPlaces = (data['approved'] as List?)
                ?.map((e) => Place.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [];
        _adminReviewPlaces = (data['adminReview'] as List?)
                ?.map((e) => Place.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [];
        _rejectedPlaces = (data['rejected'] as List?)
                ?.map((e) => Place.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [];
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

  void _showPlaceDetail(Place place) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PlaceDetailScreen(
        place: place,
        onDelete: () => _loadUserPlaces(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
        flexibleSpace: const GlassAppBarBackground(),
          title: const Text('我的标点'),
          bottom: const TabBar(
            labelColor: Color(0xFFB8860B), // 激活标签颜色（金色）
            unselectedLabelColor: const Color(0xFFB8860B), // 未激活标签颜色
            indicatorColor: Color(0xFFB8860B),
            tabs: [
              Tab(text: '待审核'),
              Tab(text: '已通过'),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildPendingList(),
                  _buildApprovedList(),
                ],
              ),
      ),
    );
  }

  Widget _buildPendingList() {
    final pending = [..._pendingPlaces, ..._adminReviewPlaces];
    if (pending.isEmpty && _rejectedPlaces.isEmpty) {
      return const Center(child: Text('暂无待审核标点'));
    }
    // 合并列表：先显示 pending，再显示 rejected，中间不加分隔线
    final List<Place> allItems = [...pending, ..._rejectedPlaces];
    return ListView.builder(
      itemCount: allItems.length,
      itemBuilder: (context, index) {
        final place = allItems[index];
        final isRejected = index >= pending.length;
        return _buildPlaceCard(place,
            isPending: !isRejected, isRejected: isRejected);
      },
    );
  }

  Widget _buildApprovedList() {
    if (_approvedPlaces.isEmpty) {
      return const Center(child: Text('暂无已通过标点'));
    }
    return ListView.builder(
      itemCount: _approvedPlaces.length,
      itemBuilder: (context, index) {
        return _buildPlaceCard(_approvedPlaces[index]);
      },
    );
  }

  Widget _buildPlaceCard(Place place,
      {bool isPending = false, bool isRejected = false}) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: place.photos.isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  place.photos.first,
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.image, size: 50),
                ),
              )
            : Container(
                width: 50,
                height: 50,
                color: Colors.grey[200],
                child: const Icon(Icons.store),
              ),
        title: Text(place.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(place.address, maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(
              isPending
                  ? '状态: ${place.status == 'pending_review' ? '公审中' : '管理员审核中'}'
                  : (isRejected ? '状态: 已拒绝' : '状态: 已通过'),
              style: TextStyle(
                fontSize: 12,
                color: isPending
                    ? Colors.orange
                    : (isRejected ? Colors.red : Colors.green),
              ),
            ),
          ],
        ),
        onTap: () => _showPlaceDetail(place),
      ),
    );
  }
}
