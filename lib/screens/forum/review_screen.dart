import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../models/place.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/glass_container.dart';

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});

  @override
  ReviewScreenState createState() => ReviewScreenState();
}

class ReviewScreenState extends State<ReviewScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Place> _pendingPlaces = [];
  List<Place> _adminPlaces = [];
  bool _loadingPending = true;
  bool _loadingAdmin = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadPendingPlaces(),
      _loadAdminPlaces(),
    ]);
  }

  Future<void> _loadPendingPlaces() async {
    if (!mounted) return;
    setState(() => _loadingPending = true);
    try {
      final places = await ApiService.getPendingPlaces();
      if (mounted) setState(() => _pendingPlaces = places);
    } catch (e) {
      // 静默失败
    } finally {
      if (mounted) setState(() => _loadingPending = false);
    }
  }

  Future<void> _loadAdminPlaces() async {
    if (!mounted) return;
    setState(() => _loadingAdmin = true);
    try {
      final places = await ApiService.getAdminReviewPlaces();
      if (mounted) setState(() => _adminPlaces = places);
    } catch (e) {
      // 静默失败
    } finally {
      if (mounted) setState(() => _loadingAdmin = false);
    }
  }

  Future<void> _vote(Place place, bool approve) async {
    try {
      await ApiService.submitVote(place.id, approve);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(approve ? '已投票同意' : '已投票拒绝')),
        );
        await _loadPendingPlaces();
      }
    } catch (e) {
      if (mounted) {
        String errorMsg = e.toString();
        if (errorMsg.contains('already voted') ||
            errorMsg.contains('已投票') ||
            errorMsg.contains('400') ||
            errorMsg.contains('duplicate')) {
          errorMsg = '你已经投过一票了喵~';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('投票失败: $errorMsg')),
        );
      }
    }
  }

  Future<void> _adminApprove(Place place) async {
    try {
      await ApiService.adminApprovePlace(place.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('地点已通过审核')),
        );
        await _loadAdminPlaces();
        await _loadPendingPlaces();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e')),
        );
      }
    }
  }

  Future<void> _adminReject(Place place) async {
    try {
      await ApiService.adminRejectPlace(place.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('地点已拒绝')),
        );
        await _loadAdminPlaces();
        await _loadPendingPlaces();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).user;
    final isAdmin = (user?.role == 'admin') || (user?.username == 'RandomIX');

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: const GlassAppBarBackground(),
        title: const Text('审核区'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFFB8860B),
          unselectedLabelColor: const Color(0xFFB8860B),
          indicatorColor: const Color(0xFFB8860B),
          tabs: const [
            Tab(text: '用户公审'),
            Tab(text: '管理员审核'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPendingTab(),
          isAdmin ? _buildAdminTab() : const Center(child: Text('无权限查看')),
        ],
      ),
    );
  }

  Widget _buildPendingTab() {
    if (_loadingPending) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_pendingPlaces.isEmpty) {
      return const Center(child: Text('暂无待审核地点'));
    }
    return ListView.builder(
      itemCount: _pendingPlaces.length,
      itemBuilder: (context, index) {
        final place = _pendingPlaces[index];
        return Card(
          margin: const EdgeInsets.all(8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  place.name,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(place.address),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton(
                      onPressed: () => _vote(place, true),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green),
                      child: const Text('同意'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () => _vote(place, false),
                      style:
                          ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text('拒绝'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAdminTab() {
    if (_loadingAdmin) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_adminPlaces.isEmpty) {
      return const Center(child: Text('暂无待管理员审核地点'));
    }
    return ListView.builder(
      itemCount: _adminPlaces.length,
      itemBuilder: (context, index) {
        final place = _adminPlaces[index];
        return Card(
          margin: const EdgeInsets.all(8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  place.name,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(place.address),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton(
                      onPressed: () => _adminApprove(place),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green),
                      child: const Text('通过'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () => _adminReject(place),
                      style:
                          ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text('拒绝'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
