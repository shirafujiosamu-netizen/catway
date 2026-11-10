import 'package:dio/dio.dart';

class ConfigService {
  static final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://theregolithjar.monster/anime-api',
    connectTimeout: const Duration(seconds: 5),
  ));

  static Map<String, dynamic> _config = {};

  static Future<void> loadConfig() async {
    try {
      final response = await _dio.get('/config');
      _config = response.data;
    } catch (e) {
      _config = {
        'primaryColor': '#C8D0E0',
        'secondaryColor': '#7A8599',
        'backgroundColor': '#0A0E1A',
        'features': {
          'showReviewTab': true,
          'enableShareToQQ': true,
          'enableShareToWechat': true,
          'enableShareToWeibo': true,
          'enableMomentComments': true,
        },
        'strings': {
          'appName': '猫径CatWay',
          'loginWelcome': '二次元地图社区',
          'homeTabMap': '地图',
          'homeTabForum': '广场',
          'homeTabProfile': '我的',
        },
        'limits': {
          'maxPostImages': 9,
          'maxMomentImages': 9,
          'maxPostContentLength': 10000,
          'maxMomentContentLength': 500,
          'strategyDefaultLimit': 10,
        },
      };
    }
  }

  static String get primaryColor => _config['primaryColor'] ?? '#C8D0E0';
  static String get secondaryColor => _config['secondaryColor'] ?? '#7A8599';
  static String get backgroundColor => _config['backgroundColor'] ?? '#0A0E1A';

  static bool get showReviewTab =>
      _config['features']?['showReviewTab'] ?? true;
  static bool get enableShareToQQ =>
      _config['features']?['enableShareToQQ'] ?? true;
  static bool get enableShareToWechat =>
      _config['features']?['enableShareToWechat'] ?? true;
  static bool get enableShareToWeibo =>
      _config['features']?['enableShareToWeibo'] ?? true;
  static bool get enableMomentComments =>
      _config['features']?['enableMomentComments'] ?? true;

  static String get appName => _config['strings']?['appName'] ?? '猫径CatWay';
  static String get loginWelcome =>
      _config['strings']?['loginWelcome'] ?? '二次元地图社区';
  static String get homeTabMap => _config['strings']?['homeTabMap'] ?? '地图';
  static String get homeTabForum => _config['strings']?['homeTabForum'] ?? '广场';
  static String get homeTabProfile =>
      _config['strings']?['homeTabProfile'] ?? '我的';

  static int get maxPostImages => _config['limits']?['maxPostImages'] ?? 9;
  static int get maxMomentImages => _config['limits']?['maxMomentImages'] ?? 9;
  static int get maxPostContentLength =>
      _config['limits']?['maxPostContentLength'] ?? 10000;
  static int get maxMomentContentLength =>
      _config['limits']?['maxMomentContentLength'] ?? 500;
  static int get strategyDefaultLimit =>
      _config['limits']?['strategyDefaultLimit'] ?? 10;

  static Map<String, dynamic> get all => _config;
}
