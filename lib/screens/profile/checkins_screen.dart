import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/place.dart';
import '../home/place_detail_screen.dart';
import '../../widgets/glass_container.dart';

class CheckinsScreen extends StatefulWidget {
  const CheckinsScreen({super.key});

  @override
  CheckinsScreenState createState() => CheckinsScreenState();
}

class CheckinsScreenState extends State<CheckinsScreen> {
  List<Place> _checkins = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCheckins();
  }

  Future<void> _loadCheckins() async {
    setState(() => _isLoading = true);
    try {
      final places = await ApiService.getCheckins();
      setState(() {
        _checkins = places;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载打卡记录失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: const GlassAppBarBackground(),title: const Text('已打卡')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _checkins.isEmpty
              ? const Center(child: Text('暂无打卡记录，去地图上打卡吧~'))
              : ListView.builder(
                  itemCount: _checkins.length,
                  itemBuilder: (context, index) {
                    final place = _checkins[index];
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
                        trailing:
                            const Icon(Icons.check_circle, color: Colors.green),
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
