import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/place.dart';
import '../home/place_detail_screen.dart';
import '../../widgets/glass_container.dart';

class CollectionsScreen extends StatefulWidget {
  const CollectionsScreen({super.key});

  @override
  CollectionsScreenState createState() => CollectionsScreenState();
}

class CollectionsScreenState extends State<CollectionsScreen> {
  List<Place> _favoritePlaces = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    setState(() => _isLoading = true);
    try {
      final places = await ApiService.getFavoritePlaces();
      setState(() {
        _favoritePlaces = places;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载收藏夹失败: $e')),
        );
      }
    }
  }

  Future<void> _removeFavorite(Place place) async {
    try {
      await ApiService.toggleFavorite(place.id);
      setState(() {
        _favoritePlaces.removeWhere((p) => p.id == place.id);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已取消收藏')),
        );
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
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: const GlassAppBarBackground(),
        title: const Text('我的收藏'),
        actions: [
          if (_favoritePlaces.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('清空收藏'),
                    content: const Text('确定要清空所有收藏吗？此操作不可逆。'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('取消'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('清空',
                            style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  try {
                    await ApiService.clearFavorites();
                    if (!mounted) return;
                    setState(() => _favoritePlaces.clear());
                    messenger.showSnackBar(
                      const SnackBar(content: Text('已清空收藏夹')),
                    );
                  } catch (e) {
                    messenger.showSnackBar(
                      SnackBar(content: Text('清空失败: $e')),
                    );
                  }
                }
              },
              tooltip: '清空收藏',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _favoritePlaces.isEmpty
              ? const Center(child: Text('暂无收藏，快去地图上添加吧~'))
              : ListView.builder(
                  itemCount: _favoritePlaces.length,
                  itemBuilder: (context, index) {
                    final place = _favoritePlaces[index];
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
                          icon: const Icon(Icons.favorite, color: Colors.red),
                          onPressed: () => _removeFavorite(place),
                          tooltip: '取消收藏',
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
