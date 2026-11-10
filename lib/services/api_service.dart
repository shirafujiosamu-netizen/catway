import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/place.dart';
import '../models/post.dart';
import '../models/moment.dart';

class ApiService {
  static final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://theregolithjar.monster/anime-api',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));
  static String? _token;

  /// 收到 401（token 失效/过期）时由 main 注入：清空登录态并跳回登录页
  static void Function()? onUnauthorized;

  static bool _interceptorReady = false;
  static bool _unauthorizedHandled = false;

  /// 在 main 中调用一次：确保请求拦截器已挂载
  static void init() => _ensureInterceptor();

  static void _ensureInterceptor() {
    if (_interceptorReady) return;
    _interceptorReady = true;
    _dio.interceptors.add(
      InterceptorsWrapper(
        // 每次请求都从 SharedPreferences 读取最新 token（来源唯一真值），
        // 避免静态变量 _token 未同步 / autoLogin 竞态导致漏带 Authorization。
        onRequest: (options, handler) async {
          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString('token') ?? _token;
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (err, handler) {
          if (err.response?.statusCode == 401) {
            // 仅触发一次，防止 401 循环；重新登录后由 setToken 复位该标记
            if (!_unauthorizedHandled) {
              _unauthorizedHandled = true;
              onUnauthorized?.call();
            }
          }
          handler.next(err);
        },
      ),
    );
  }

  static void setToken(String token) {
    _token = token;
    _unauthorizedHandled = false; // 重新登录成功后允许再次处理 401
    _ensureInterceptor();
  }

  static Future<String?> getStoredToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  static Future<String?> getCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('user');
    if (userJson != null) {
      try {
        final Map<String, dynamic> userMap = jsonDecode(userJson);
        return userMap['id']?.toString();
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  // ==================== 认证相关 ====================
  static Future<void> register(String username, String password,
      String nickname, String email, String code) async {
    await _dio.post('/auth/register', data: {
      'username': username,
      'password': password,
      'nickname': nickname,
      'email': email,
      'code': code,
    });
  }

  static Future<Map<String, dynamic>> login(
      String username, String password) async {
    final response = await _dio.post('/auth/login', data: {
      'username': username,
      'password': password,
    });
    return response.data;
  }

  static Future<void> sendVerificationCode(String email) async {
    await _dio.post('/auth/send-code', data: {'email': email});
  }

  static Future<void> forgotPassword(String email) async {
    await _dio.post('/auth/forgot-password', data: {'email': email});
  }

  static Future<void> resetPassword(
      String email, String code, String newPassword) async {
    await _dio.post('/auth/reset-password', data: {
      'email': email,
      'code': code,
      'newPassword': newPassword,
    });
  }

  // ==================== 地点相关 ====================
  static Future<List<Place>> getPlaces() async {
    final response = await _dio.get('/places');
    final List placesData = response.data['places'] ?? [];
    return placesData.map((json) => Place.fromJson(json)).toList();
  }

  static Future<Place> getPlaceById(String placeId) async {
    final response = await _dio.get('/places/$placeId');
    return Place.fromJson(response.data);
  }

  static Future<void> submitPlace(Map<String, dynamic> placeData) async {
    final options = Options(
      headers: {
        if (_token != null) 'Authorization': 'Bearer $_token',
      },
    );
    await _dio.post('/places', data: placeData, options: options);
  }

  // 新增：编辑地点
  static Future<void> editPlace(
      String placeId, Map<String, dynamic> placeData) async {
    final options = Options(
      headers: {
        if (_token != null) 'Authorization': 'Bearer $_token',
      },
    );
    await _dio.put('/places/$placeId', data: placeData, options: options);
  }

  static Future<List<Place>> getPendingPlaces() async {
    final response = await _dio.get('/places/pending');
    final List placesData = response.data['places'] ?? [];
    return placesData.map((json) => Place.fromJson(json)).toList();
  }

  static Future<List<Place>> getAdminReviewPlaces() async {
    final response = await _dio.get('/places/admin-review');
    final List placesData = response.data['places'] ?? [];
    return placesData.map((json) => Place.fromJson(json)).toList();
  }

  static Future<void> submitVote(String placeId, bool approve) async {
    final options = Options(
      headers: {
        if (_token != null) 'Authorization': 'Bearer $_token',
      },
    );
    await _dio.post('/places/$placeId/vote',
        data: {'approve': approve}, options: options);
  }

  static Future<void> adminApprovePlace(String placeId) async {
    final options = Options(
      headers: {
        if (_token != null) 'Authorization': 'Bearer $_token',
      },
    );
    await _dio.put('/places/$placeId/approve', options: options);
  }

  static Future<void> adminRejectPlace(String placeId) async {
    final options = Options(
      headers: {
        if (_token != null) 'Authorization': 'Bearer $_token',
      },
    );
    await _dio.put('/places/$placeId/reject', options: options);
  }

  static Future<void> adminDeletePlace(String placeId) async {
    final options = Options(
      headers: {
        if (_token != null) 'Authorization': 'Bearer $_token',
      },
    );
    await _dio.delete('/places/$placeId', options: options);
  }

  // ==================== POI 搜索 ====================
  static Future<Map<String, dynamic>> searchPOI(String keywords,
      {String city = '上海'}) async {
    final response = await _dio.get('/search/poi', queryParameters: {
      'keywords': keywords,
      'city': city,
    });
    return response.data;
  }

  // ==================== 用户相关 ====================
  static Future<Map<String, dynamic>> getUserProfile(String userId) async {
    final response = await _dio.get('/users/$userId');
    return response.data;
  }

  static Future<Map<String, dynamic>> updateUserProfile(
      Map<String, dynamic> data) async {
    final options = Options(
      headers: {
        if (_token != null) 'Authorization': 'Bearer $_token',
      },
    );
    final response =
        await _dio.put('/users/profile', data: data, options: options);
    return response.data;
  }

  static Future<List<String>> toggleFavorite(String placeId) async {
    final options = Options(
      headers: {
        if (_token != null) 'Authorization': 'Bearer $_token',
      },
    );
    final response =
        await _dio.post('/users/favorites/$placeId', options: options);
    return List<String>.from(response.data['favorites']);
  }

  static Future<List<String>> addFootprint(String placeId) async {
    final options = Options(
      headers: {
        if (_token != null) 'Authorization': 'Bearer $_token',
      },
    );
    final response =
        await _dio.post('/users/footprints/$placeId', options: options);
    return List<String>.from(response.data['footprints']);
  }

  static Future<List<String>> checkIn(String placeId) async {
    final options = Options(
      headers: {
        if (_token != null) 'Authorization': 'Bearer $_token',
      },
    );
    final response =
        await _dio.post('/users/checkins/$placeId', options: options);
    return List<String>.from(response.data['checkins']);
  }

  static Future<List<String>> addToHistory(String placeId) async {
    final options = Options(
      headers: {
        if (_token != null) 'Authorization': 'Bearer $_token',
      },
    );
    final response =
        await _dio.post('/users/history/$placeId', options: options);
    return List<String>.from(response.data['history']);
  }

  static Future<Map<String, dynamic>> toggleFollow(String targetUserId) async {
    final options = Options(
      headers: {
        if (_token != null) 'Authorization': 'Bearer $_token',
      },
    );
    final response =
        await _dio.post('/users/follow/$targetUserId', options: options);
    return response.data;
  }

  static Future<bool> isFollowing(String targetUserId) async {
    final options = Options(
      headers: {
        if (_token != null) 'Authorization': 'Bearer $_token',
      },
    );
    final response =
        await _dio.get('/users/is-following/$targetUserId', options: options);
    return response.data['isFollowing'] ?? false;
  }

  static Future<String> uploadImage(XFile file) async {
    final formData = FormData.fromMap({
      'image': await MultipartFile.fromFile(file.path, filename: file.name),
    });
    final options = Options(
      headers: {
        if (_token != null) 'Authorization': 'Bearer $_token',
      },
    );
    final response =
        await _dio.post('/upload', data: formData, options: options);
    const baseUrl = 'https://theregolithjar.monster';
    return baseUrl + response.data['url'];
  }

  // ==================== 帖子相关 ====================
  static Future<List<dynamic>> getPosts() async {
    final response = await _dio.get('/posts');
    return response.data;
  }

  static Future<void> createPost(Map<String, dynamic> data,
      {List<XFile>? images}) async {
    final options = Options(
      headers: {
        if (_token != null) 'Authorization': 'Bearer $_token',
      },
    );
    if (images != null && images.isNotEmpty) {
      final formData = FormData.fromMap(data);
      for (var i = 0; i < images.length; i++) {
        formData.files.add(MapEntry(
          'images',
          await MultipartFile.fromFile(images[i].path,
              filename: images[i].name),
        ));
      }
      await _dio.post('/posts', data: formData, options: options);
    } else {
      await _dio.post('/posts', data: data, options: options);
    }
  }

  static Future<List<Post>> searchPosts(String keyword) async {
    final response = await _dio.get('/posts/search', queryParameters: {
      'q': keyword,
    });
    final List data = response.data['posts'] ?? [];
    return data.map((json) => Post.fromJson(json)).toList();
  }

  static Future<List<Post>> getPlaceRelatedPosts(String placeId) async {
    final response = await _dio.get('/posts/place/$placeId');
    final List data = response.data['posts'] ?? [];
    return data.map((json) => Post.fromJson(json)).toList();
  }

  static Future<Map<String, dynamic>> getStrategyPosts({
    List<String>? ipList,
    List<String>? productTypeList,
    List<String>? shopTypeList,
    String? search,
    int page = 1,
    int limit = 10,
  }) async {
    final query = <String, dynamic>{};
    if (search != null && search.isNotEmpty) {
      query['search'] = search;
    } else {
      if (ipList != null && ipList.isNotEmpty) query['ip'] = ipList.join(',');
      if (productTypeList != null && productTypeList.isNotEmpty) {
        query['productType'] = productTypeList.join(',');
      }
      if (shopTypeList != null && shopTypeList.isNotEmpty) {
        query['shopType'] = shopTypeList.join(',');
      }
    }
    query['page'] = page;
    query['limit'] = limit;

    final response = await _dio.get('/posts/strategy', queryParameters: query);
    return response.data;
  }

  static Future<void> adminDeletePost(String postId) async {
    final options = Options(headers: {'Authorization': 'Bearer $_token'});
    await _dio.delete('/admin/posts/$postId', options: options);
  }

  static Future<void> deletePost(String postId) async {
    final options = Options(headers: {'Authorization': 'Bearer $_token'});
    await _dio.delete('/posts/$postId', options: options);
  }

  static Future<void> adminPinPost(String postId) async {
    final options = Options(headers: {'Authorization': 'Bearer $_token'});
    await _dio.put('/admin/posts/$postId/pin', options: options);
  }

  static Future<void> adminBanIp(String ip, {String? reason}) async {
    final options = Options(headers: {'Authorization': 'Bearer $_token'});
    await _dio.post('/admin/ban-ip',
        data: {'ip': ip, 'reason': reason}, options: options);
  }

  // ==================== 修改邮箱/密码 ====================
  static Future<void> changeEmail(String newEmail, String code) async {
    final options = Options(
      headers: {
        if (_token != null) 'Authorization': 'Bearer $_token',
      },
    );
    await _dio.put('/users/email',
        data: {'newEmail': newEmail, 'code': code}, options: options);
  }

  static Future<void> changePassword(
      String oldPassword, String newPassword) async {
    final options = Options(
      headers: {
        if (_token != null) 'Authorization': 'Bearer $_token',
      },
    );
    await _dio.put('/users/password',
        data: {'oldPassword': oldPassword, 'newPassword': newPassword},
        options: options);
  }

  // ==================== 动态相关 ====================
  static Future<Map<String, dynamic>> getMoments(
      {int page = 1, int limit = 10}) async {
    final response = await _dio.get('/moments', queryParameters: {
      'page': page,
      'limit': limit,
    });
    return response.data;
  }

  static Future<void> createMoment(Map<String, dynamic> data) async {
    final options = Options(
      headers: {
        if (_token != null) 'Authorization': 'Bearer $_token',
      },
    );
    await _dio.post('/moments', data: data, options: options);
  }

  static Future<Map<String, dynamic>> likeMoment(String momentId) async {
    final options = Options(
      headers: {
        if (_token != null) 'Authorization': 'Bearer $_token',
      },
    );
    final response =
        await _dio.post('/moments/$momentId/like', options: options);
    return response.data;
  }

  static Future<void> shareMomentToCatway(String momentId) async {
    final options = Options(
      headers: {
        if (_token != null) 'Authorization': 'Bearer $_token',
      },
    );
    await _dio.post('/moments/$momentId/share', options: options);
  }

  static Future<List<Map<String, dynamic>>> getTopComments(
      String momentId) async {
    final response = await _dio.get('/moments/$momentId/comments/top');
    final List data = response.data['comments'] ?? [];
    return data.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static Future<Map<String, dynamic>> getMoreComments(String momentId,
      {int page = 1, int limit = 10}) async {
    final response =
        await _dio.get('/moments/$momentId/comments/more', queryParameters: {
      'page': page,
      'limit': limit,
    });
    return response.data;
  }

  static Future<int> getUserMomentsCount(String userId) async {
    try {
      final response = await _dio.get('/users/$userId/moments/count');
      return response.data['count'] ?? 0;
    } catch (e) {
      return 0;
    }
  }

  static Future<List<Moment>> getUserMoments(String userId) async {
    final response = await _dio.get('/users/$userId/moments');
    final List data = response.data['moments'] ?? [];
    return data.map((json) => Moment.fromJson(json)).toList();
  }

  static Future<void> deleteMoment(String momentId) async {
    final options = Options(
      headers: {
        if (_token != null) 'Authorization': 'Bearer $_token',
      },
    );
    await _dio.delete('/moments/$momentId', options: options);
  }

  // ==================== 帖子扩展接口 ====================
  static Future<Map<String, dynamic>> likePost(String postId) async {
    final options = Options(
      headers: {
        if (_token != null) 'Authorization': 'Bearer $_token',
      },
    );
    final response = await _dio.post('/posts/$postId/like', options: options);
    return response.data;
  }

  static Future<void> sharePostToCatway(String postId) async {
    final options = Options(
      headers: {
        if (_token != null) 'Authorization': 'Bearer $_token',
      },
    );
    await _dio.post('/posts/$postId/share', options: options);
  }

  static Future<List<Map<String, dynamic>>> getPostComments(
      String postId) async {
    final response = await _dio.get('/posts/$postId/comments');
    final List data = response.data['comments'] ?? [];
    return data.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static Future<Map<String, dynamic>> getChatPosts(
      {int page = 1, int limit = 10}) async {
    final response = await _dio.get('/posts/chat', queryParameters: {
      'page': page,
      'limit': limit,
    });
    return response.data;
  }

  // 分类列表
  static Future<List<String>> getIpCategories() async {
    try {
      final response = await _dio.get('/posts/ip-categories');
      final List data = response.data;
      return data.map((e) => e['name'].toString()).toList();
    } catch (e) {
      return [];
    }
  }

  static Future<List<String>> getProductTypes() async {
    try {
      final response = await _dio.get('/posts/product-types');
      final List data = response.data;
      return data.map((e) => e['name'].toString()).toList();
    } catch (e) {
      return [];
    }
  }

  static Future<List<String>> getShopTypes() async {
    try {
      final response = await _dio.get('/posts/shop-types');
      final List data = response.data;
      return data.map((e) => e['name'].toString()).toList();
    } catch (e) {
      return [];
    }
  }

  // 评论
  static Future<void> addComment(String postId, String content) async {
    final options = Options(
      headers: {
        if (_token != null) 'Authorization': 'Bearer $_token',
      },
    );
    await _dio.post('/posts/$postId/comments',
        data: {'content': content}, options: options);
  }

  static Future<void> likeComment(String commentId) async {
    final options = Options(
      headers: {
        if (_token != null) 'Authorization': 'Bearer $_token',
      },
    );
    await _dio.post('/comments/$commentId/like', options: options);
  }

  // 收藏夹
  static Future<List<Place>> getFavoritePlaces() async {
    final options = Options(
      headers: {
        if (_token != null) 'Authorization': 'Bearer $_token',
      },
    );
    final response = await _dio.get('/users/favorites', options: options);
    final List data = response.data['places'] ?? [];
    return data.map((json) => Place.fromJson(json)).toList();
  }

  static Future<void> clearFavorites() async {
    final options = Options(
      headers: {
        if (_token != null) 'Authorization': 'Bearer $_token',
      },
    );
    await _dio.delete('/users/favorites', options: options);
  }

  // 浏览历史
  static Future<List<Place>> getHistoryPlaces() async {
    final options = Options(
      headers: {
        if (_token != null) 'Authorization': 'Bearer $_token',
      },
    );
    final response = await _dio.get('/users/history', options: options);
    final List data = response.data['places'] ?? [];
    return data.map((json) => Place.fromJson(json)).toList();
  }

  static Future<void> removeFromHistory(String placeId) async {
    final options = Options(
      headers: {
        if (_token != null) 'Authorization': 'Bearer $_token',
      },
    );
    await _dio.delete('/users/history/$placeId', options: options);
  }

  static Future<void> clearHistory() async {
    final options = Options(
      headers: {
        if (_token != null) 'Authorization': 'Bearer $_token',
      },
    );
    await _dio.delete('/users/history', options: options);
  }

  // 动态评论
  static Future<Map<String, dynamic>> addMomentComment(
      String momentId, String content) async {
    final options = Options(
      headers: {
        if (_token != null) 'Authorization': 'Bearer $_token',
      },
    );
    final response = await _dio.post('/moments/$momentId/comments',
        data: {'content': content}, options: options);
    return response.data;
  }

  static Future<void> likeMomentComment(String commentId) async {
    final options = Options(
      headers: {
        if (_token != null) 'Authorization': 'Bearer $_token',
      },
    );
    await _dio.post('/moments/comments/$commentId/like', options: options);
  }

  // 签到列表
  static Future<List<Place>> getCheckins() async {
    final options = Options(
      headers: {
        if (_token != null) 'Authorization': 'Bearer $_token',
      },
    );
    final response = await _dio.get('/users/checkins', options: options);
    final List data = response.data['places'] ?? [];
    return data.map((json) => Place.fromJson(json)).toList();
  }

  // ==================== 用户地点 ====================
  static Future<Map<String, dynamic>> getUserPlaces() async {
    final options = Options(
      headers: {
        if (_token != null) 'Authorization': 'Bearer $_token',
      },
    );
    final response = await _dio.get('/users/places', options: options);
    return response.data;
  }

  // ==================== 通知相关 ====================
  static Future<Map<String, dynamic>> getNotifications(
      {int page = 1, int limit = 20}) async {
    final options = Options(
      headers: {
        if (_token != null) 'Authorization': 'Bearer $_token',
      },
    );
    final response = await _dio.get('/notifications',
        queryParameters: {
          'page': page,
          'limit': limit,
        },
        options: options);
    return response.data;
  }

  static Future<void> markNotificationRead(String id) async {
    final options = Options(
      headers: {
        if (_token != null) 'Authorization': 'Bearer $_token',
      },
    );
    await _dio.put('/notifications/$id/read', options: options);
  }

  static Future<void> markAllNotificationsRead() async {
    final options = Options(
      headers: {
        if (_token != null) 'Authorization': 'Bearer $_token',
      },
    );
    await _dio.put('/notifications/read-all', options: options);
  }

  // ==================== 粉丝/关注/攻略列表 ====================
  static Future<Map<String, dynamic>> getFollowers(String userId) async {
    final response = await _dio.get('/users/followers/$userId');
    return response.data;
  }

  static Future<Map<String, dynamic>> getFollowing(String userId) async {
    final response = await _dio.get('/users/following/$userId');
    return response.data;
  }

  static Future<Map<String, dynamic>> getUserStrategies({
    String? userId,
    int page = 1,
    int limit = 10,
  }) async {
    String? targetUserId = userId;
    if (targetUserId == null || targetUserId.isEmpty) {
      targetUserId = await getCurrentUserId();
    }
    if (targetUserId == null || targetUserId.isEmpty) {
      throw Exception('无法获取当前用户信息');
    }
    if (!RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(targetUserId)) {
      throw Exception('无效的用户ID');
    }
    final response =
        await _dio.get('/users/strategies/$targetUserId', queryParameters: {
      'page': page,
      'limit': limit,
    });
    return response.data;
  }

  // ==================== 地点搜索 ====================
  static Future<List<Place>> searchPlaces({
    required String keyword,
    double? lat,
    double? lng,
  }) async {
    final query = <String, dynamic>{'keyword': keyword};
    if (lat != null && lng != null) {
      query['lat'] = lat;
      query['lng'] = lng;
    }
    final response = await _dio.get('/places/search', queryParameters: query);
    final List data = response.data['places'] ?? [];
    return data.map((json) => Place.fromJson(json)).toList();
  }
}
