import 'package:flutter/material.dart';
import 'package:amap_flutter_map/amap_flutter_map.dart';
import 'package:amap_flutter_base/amap_flutter_base.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/api_service.dart';
import '../../services/navigation_service.dart';
import '../../models/place.dart';
import '../../utils/marker_icon.dart';
import 'search_navigation_panel.dart';
import 'place_detail_screen.dart';
import 'create_place_sheet.dart';
import '../../widgets/glass_container.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  MapScreenState createState() => MapScreenState();
}

class MapScreenState extends State<MapScreen> {
  AMapController? _mapController;
  List<Place> _places = [];
  Set<Marker> _markers = {};
  bool _isLoading = true;

  // 多目标点选择相关
  bool _selectingWaypoints = false;
  final Set<String> _selectedPlaceIds = {};
  final List<Place> _selectedPlaces = [];

  // 路线相关
  Set<Polyline> _polylines = {};

  // 图标缓存
  final Map<String, BitmapDescriptor> _typeIcons = {};
  final Map<String, BitmapDescriptor> _selectedIcons = {};

  @override
  void initState() {
    super.initState();
    _loadPlaces();
  }

  Future<void> _loadPlaces() async {
    try {
      final places = await ApiService.getPlaces();
      if (mounted) {
        final types = places.map((p) => p.type).toSet();
        for (final type in types) {
          if (!_typeIcons.containsKey(type)) {
            _typeIcons[type] =
                await MarkerIconGenerator.generate(type, isSelected: false);
          }
        }
        setState(() {
          _places = places;
          _isLoading = false;
          _updateMarkers();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError("加载地点失败: $e");
      }
    }
  }

  void _updateMarkers() {
    final newMarkers = <Marker>{};
    for (var place in _places) {
      final isSelected =
          _selectingWaypoints && _selectedPlaceIds.contains(place.id);
      BitmapDescriptor icon;
      if (isSelected) {
        icon = _selectedIcons[place.type] ?? _typeIcons[place.type]!;
      } else {
        icon = _typeIcons[place.type]!;
      }

      newMarkers.add(
        Marker(
          position: LatLng(place.lat, place.lng),
          infoWindow: InfoWindow(
            title: place.name,
            snippet: place.address,
          ),
          icon: icon,
          onTap: (markerId) => _onMarkerTap(place),
        ),
      );
    }
    setState(() {
      _markers = newMarkers;
    });
  }

  void _onMarkerTap(Place tappedPlace) {
    if (_selectingWaypoints) {
      setState(() {
        if (_selectedPlaceIds.contains(tappedPlace.id)) {
          _selectedPlaceIds.remove(tappedPlace.id);
          _selectedPlaces.removeWhere((p) => p.id == tappedPlace.id);
        } else {
          _selectedPlaceIds.add(tappedPlace.id);
          _selectedPlaces.add(tappedPlace);
        }
      });
      _updateMarkers();
    } else {
      final nearbyPlaces = _places
          .where((p) =>
              (p.lat - tappedPlace.lat).abs() < 0.0001 &&
              (p.lng - tappedPlace.lng).abs() < 0.0001)
          .toList();

      if (nearbyPlaces.length > 1) {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (context) => GlassBottomSheet(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: nearbyPlaces.map((place) {
                return ListTile(
                  leading: place.photos.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(place.photos.first,
                              width: 40, height: 40, fit: BoxFit.cover),
                        )
                      : const Icon(Icons.store, size: 40),
                  title: Text(place.name),
                  subtitle: Text(place.address),
                  onTap: () {
                    Navigator.pop(context);
                    _showPlaceDetail(place);
                  },
                );
              }).toList(),
            ),
          ),
        );
      } else {
        _showPlaceDetail(tappedPlace);
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
        onDelete: () => _loadPlaces(),
      ),
    );
  }

  void _showError(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  void _onMapLongPress(LatLng position) async {
    if (_selectingWaypoints) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CreatePlaceSheet(
        position: position,
        onCreated: _loadPlaces,
      ),
    );
  }

  Future<void> _goToMyLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showError("需要位置权限");
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      _showError("请在设置中开启位置权限");
      return;
    }
    try {
      Position position = await Geolocator.getCurrentPosition();
      _mapController?.moveCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(position.latitude, position.longitude),
            zoom: 15,
          ),
        ),
        duration: 300,
      );
    } catch (e) {
      _showError("获取位置失败: $e");
    }
  }

  void _startSelecting() {
    setState(() {
      _selectingWaypoints = true;
      _selectedPlaceIds.clear();
      _selectedPlaces.clear();
      _polylines.clear();
    });
    _updateMarkers();
    _showError('点击地图上的标记选择目标点，完成后点击右上角"完成"');
  }

  void _cancelSelecting() {
    setState(() {
      _selectingWaypoints = false;
      _selectedPlaceIds.clear();
      _selectedPlaces.clear();
      _polylines.clear();
    });
    _updateMarkers();
  }

  Future<void> _finishSelecting() async {
    if (_selectedPlaces.length < 2) {
      _showError("请至少选择两个目标点");
      return;
    }

    setState(() => _isLoading = true);
    try {
      final currentPos = await Geolocator.getCurrentPosition();
      final startPoint = LatLng(currentPos.latitude, currentPos.longitude);
      final allPoints = [
        {'lat': startPoint.latitude, 'lng': startPoint.longitude},
        ..._selectedPlaces.map((p) => {'lat': p.lat, 'lng': p.lng}),
      ];

      final order = await NavigationService.planMultiDestination(allPoints);
      final orderedPlaces = order.map((idx) => _selectedPlaces[idx]).toList();

      final origin = '${startPoint.longitude},${startPoint.latitude}';
      final destination = '${orderedPlaces.last.lng},${orderedPlaces.last.lat}';
      final waypoints = orderedPlaces.length > 1
          ? orderedPlaces
              .sublist(0, orderedPlaces.length - 1)
              .map((p) => '${p.lng},${p.lat}')
              .join(';')
          : '';

      final routeData = await NavigationService.getDrivingRoute(
        origin: origin,
        destination: destination,
        waypoints: waypoints,
      );

      if (routeData['status'] == '1' &&
          routeData['route']['paths'] != null &&
          routeData['route']['paths'].isNotEmpty) {
        final path = routeData['route']['paths'][0];
        final steps = path['steps'] as List?;
        final routePoints = <LatLng>[];
        if (steps != null) {
          for (var step in steps) {
            final polyline = step['polyline'] as String?;
            if (polyline != null && polyline.isNotEmpty) {
              final coords = polyline.split(';');
              for (var coord in coords) {
                final parts = coord.split(',');
                if (parts.length == 2) {
                  routePoints.add(
                      LatLng(double.parse(parts[1]), double.parse(parts[0])));
                }
              }
            }
          }
        }
        if (routePoints.isNotEmpty) {
          setState(() {
            _polylines = {
              Polyline(
                points: routePoints,
                color: const Color(0xFF8090A8), // 中性灰蓝（非纯蓝）
                width: 5,
              ),
            };
          });
          if (routePoints.isNotEmpty) {
            _mapController?.moveCamera(CameraUpdate.newCameraPosition(
              CameraPosition(target: routePoints.first, zoom: 14),
            ));
          }
          _showError("路线规划成功！");
        } else {
          _showError("未找到有效路线点");
        }
      } else {
        _showError("未找到路线");
      }
    } catch (e) {
      _showError("路线规划失败: $e");
    } finally {
      if (mounted) {
        setState(() {
          _selectingWaypoints = false;
          _selectedPlaceIds.clear();
          _selectedPlaces.clear();
          _isLoading = false;
        });
        _updateMarkers();
      }
    }
  }

  void _onNavigate(LatLng start, LatLng end, List<LatLng>? routePoints) {
    if (routePoints != null && routePoints.isNotEmpty) {
      setState(() {
        _polylines = {
          Polyline(
            points: routePoints,
            color: Colors.blue, // 改为蓝色
            width: 5,
          ),
        };
      });
      if (routePoints.isNotEmpty) {
        _mapController?.moveCamera(CameraUpdate.newCameraPosition(
          CameraPosition(target: routePoints.first, zoom: 14),
        ));
      }
    }
  }

  void _clearRoute() {
    setState(() {
      _polylines.clear();
    });
    _showError("路线已清除");
  }

  void _showNavigationPanel() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SearchNavigationPanel(
        mapController: _mapController!,
        onNavigate: _onNavigate,
      ),
    );
  }

  Future<void> _searchPlaces() async {
    final TextEditingController searchController = TextEditingController();
    final List<Place> searchResults = [];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateSheet) {
          return GlassContainer(
            margin: EdgeInsets.zero,
            padding: EdgeInsets.zero,
            customRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            tintColor: Colors.white,
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.7,
              child: Column(
              children: [
                Container(
                  height: 4,
                  width: 40,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: '搜索地点名称、地址或标签',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => searchController.clear(),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    onSubmitted: (value) async {
                      if (value.trim().isEmpty) return;
                      setStateSheet(() => searchResults.clear());
                      try {
                        Position? currentPos;
                        if (await Geolocator.checkPermission() ==
                                LocationPermission.always ||
                            await Geolocator.checkPermission() ==
                                LocationPermission.whileInUse) {
                          currentPos = await Geolocator.getCurrentPosition();
                        }
                        final places = await ApiService.searchPlaces(
                          keyword: value.trim(),
                          lat: currentPos?.latitude,
                          lng: currentPos?.longitude,
                        );
                        setStateSheet(() {
                          searchResults.clear();
                          searchResults.addAll(places);
                        });
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('搜索失败: $e')),
                        );
                      }
                    },
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: searchResults.length,
                    itemBuilder: (context, index) {
                      final place = searchResults[index];
                      return ListTile(
                        leading: place.photos.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  place.photos.first,
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const Icon(Icons.image),
                                ),
                              )
                            : const Icon(Icons.store),
                        title: Text(place.name),
                        subtitle: Text(place.address),
                        trailing: const Icon(Icons.location_pin),
                        onTap: () {
                          Navigator.pop(context);
                          _mapController?.moveCamera(
                            CameraUpdate.newCameraPosition(
                              CameraPosition(
                                target: LatLng(place.lat, place.lng),
                                zoom: 16,
                              ),
                            ),
                            duration: 300,
                          );
                          _showPlaceDetail(place);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: const GlassAppBarBackground(),
        title: const Text("地图"),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _searchPlaces,
            tooltip: "搜索地点",
          ),
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _goToMyLocation,
            tooltip: "我的位置",
          ),
          if (_selectingWaypoints) ...[
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _cancelSelecting,
              tooltip: "取消选择",
            ),
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _finishSelecting,
              tooltip: "完成选择",
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.route),
              onPressed: _startSelecting,
              tooltip: "路线规划",
            ),
          ],
        ],
      ),
      body: Stack(
        children: [
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else
            AMapWidget(
              markers: _markers,
              polylines: _polylines,
              onMapCreated: (controller) {
                _mapController = controller;
              },
              onLongPress: _onMapLongPress,
              initialCameraPosition: const CameraPosition(
                target: LatLng(31.2304, 121.4737),
                zoom: 12,
              ),
              privacyStatement: const AMapPrivacyStatement(
                hasContains: true,
                hasAgree: true,
                hasShow: true,
              ),
              myLocationStyleOptions: MyLocationStyleOptions(
                true,
                circleFillColor: const Color(0xFF8090A8).withOpacity(0.2),
                circleStrokeColor: const Color(0xFF8090A8),
                circleStrokeWidth: 2,
              ),
            ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: GlassContainer(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              borderRadius: 30,
              tintColor: Colors.white,
              child: GestureDetector(
                onTap: _showNavigationPanel,
                child: Row(
                  children: [
                    Icon(Icons.search, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(
                      "搜索地点或导航",
                      style: TextStyle(color: Colors.grey[600], fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_polylines.isNotEmpty)
            Positioned(
              top: 16,
              right: 16,
              child: FloatingActionButton(
                mini: true,
                backgroundColor: const Color(0xFFB8860B),
                onPressed: _clearRoute,
                tooltip: "清空路线",
                child: const Icon(Icons.clear_all, color: Color(0xFF0a0e1a)),
              ),
            ),
        ],
      ),
    );
  }
}
