import 'package:dio/dio.dart';

class NavigationService {
  static final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://theregolithjar.monster/anime-api',
  ));

  // 获取驾车路线
  static Future<Map<String, dynamic>> getDrivingRoute({
    required String origin, // 格式: "lng,lat"
    required String destination, // 格式: "lng,lat"
    String waypoints = '',
  }) async {
    final response = await _dio.get('/navigation/direction', queryParameters: {
      'origin': origin,
      'destination': destination,
      'waypoints': waypoints,
    });
    return response.data;
  }

  // 多目标点顺序规划（暂返回原顺序）
  static Future<List<int>> planMultiDestination(
      List<Map<String, double>> points) async {
    final response = await _dio
        .post('/navigation/multi-destination', data: {'points': points});
    final List<dynamic> order = response.data['order'];
    return order.cast<int>();
  }
}
