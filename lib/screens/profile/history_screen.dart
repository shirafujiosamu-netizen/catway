import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/place.dart';
import '../home/place_detail_screen.dart';
import '../../widgets/glass_container.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  HistoryScreenState createState() => HistoryScreenState();
}

class HistoryScreenState extends State<HistoryScreen> {
  List<Place> _historyPlaces = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final places = await ApiService.getHistoryPlaces();
      setState(() {
        _historyPlaces = places;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载浏览历史失败: $e')),
        );
      }
    }
  }

  Future<void> _clearHistory() async {
    final messenger = ScaffoldMessenger.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空历史'),
        content: const Text('确定要清空所有浏览历史吗？此操作不可逆。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('清空', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await ApiService.clearHistory();
        if (!mounted) return;
        setState(() => _historyPlaces.clear());
        messenger.showSnackBar(
          const SnackBar(content: Text('已清空浏览历史')),
        );
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text('清空失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: const GlassAppBarBackground(),
        title: const Text('浏览历史'),
        actions: [
          if (_historyPlaces.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: _clearHistory,
              tooltip: '清空历史',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _historyPlaces.isEmpty
              ? const Center(child: Text('暂无浏览历史，去地图上逛逛吧~'))
              : ListView.builder(
                  itemCount: _historyPlaces.length,
                  itemBuilder: (context, index) {
                    final place = _historyPlaces[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
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
                        subtitle: Text(place.address),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: const Color(0xFFB8860B)),
                          onPressed: () async {
                            try {
                              await ApiService.removeFromHistory(place.id);
                              if (!mounted) return;
                              setState(() {
                                _historyPlaces
                                    .removeWhere((p) => p.id == place.id);
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('已从历史中移除')),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('操作失败: $e')),
                              );
                            }
                          },
                          tooltip: '移除',
                        ),
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) => PlaceDetailScreen(
                              place: place,
                              onDelete: () {},
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
