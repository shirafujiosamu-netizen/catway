import 'package:flutter/material.dart';
import 'package:amap_flutter_map/amap_flutter_map.dart';
import 'package:amap_flutter_base/amap_flutter_base.dart';
import '../../services/navigation_service.dart';
import '../../widgets/glass_container.dart';

class NavigationScreen extends StatefulWidget {
  final LatLng? start;
  final LatLng? end;
  const NavigationScreen({super.key, this.start, this.end});

  @override
  NavigationScreenState createState() => NavigationScreenState();
}

class NavigationScreenState extends State<NavigationScreen> {
  final TextEditingController _startController = TextEditingController();
  final TextEditingController _endController = TextEditingController();
  LatLng? _startPoint;
  LatLng? _endPoint;
  List<LatLng> _routePoints = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.start != null) {
      _startPoint = widget.start;
      _startController.text =
          '${widget.start!.latitude},${widget.start!.longitude}';
    }
    if (widget.end != null) {
      _endPoint = widget.end;
      _endController.text = '${widget.end!.latitude},${widget.end!.longitude}';
    }
  }

  Future<void> _searchRoute() async {
    if (_startPoint == null || _endPoint == null) return;
    setState(() => _isLoading = true);
    try {
      final origin = '${_startPoint!.longitude},${_startPoint!.latitude}';
      final dest = '${_endPoint!.longitude},${_endPoint!.latitude}';
      final data = await NavigationService.getDrivingRoute(
          origin: origin, destination: dest);
      if (data['status'] == '1' && data['route']['paths'].isNotEmpty) {
        final path = data['route']['paths'][0];
        final steps = path['steps'] as List;
        final points = <LatLng>[];
        for (var step in steps) {
          final polyline = step['polyline'] as String;
          final coords = polyline.split(';');
          for (var coord in coords) {
            final parts = coord.split(',');
            if (parts.length == 2) {
              points
                  .add(LatLng(double.parse(parts[1]), double.parse(parts[0])));
            }
          }
        }
        if (mounted) setState(() => _routePoints = points);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('未找到路线')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导航失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: const GlassAppBarBackground(),title: const Text('导航')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                TextField(
                  controller: _startController,
                  decoration: const InputDecoration(
                    labelText: '起点（经纬度或地址）',
                    hintText: '例如：121.4737,31.2304',
                  ),
                  onChanged: (val) {
                    final parts = val.split(',');
                    if (parts.length == 2) {
                      _startPoint = LatLng(
                          double.parse(parts[1]), double.parse(parts[0]));
                    }
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _endController,
                  decoration: const InputDecoration(
                    labelText: '终点（经纬度或地址）',
                    hintText: '例如：121.4737,31.2304',
                  ),
                  onChanged: (val) {
                    final parts = val.split(',');
                    if (parts.length == 2) {
                      _endPoint = LatLng(
                          double.parse(parts[1]), double.parse(parts[0]));
                    }
                  },
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _isLoading ? null : _searchRoute,
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : const Text('规划路线'),
                ),
              ],
            ),
          ),
          Expanded(
            child: AMapWidget(
              onMapCreated: (controller) {},
              initialCameraPosition: CameraPosition(
                target: _startPoint ?? const LatLng(31.2304, 121.4737),
                zoom: 12,
              ),
              polylines: _routePoints.isEmpty
                  ? {}
                  : {
                      Polyline(
                        points: _routePoints,
                        color: Colors.blue,
                        width: 6,
                      ),
                    },
            ),
          ),
        ],
      ),
    );
  }
}
