import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../services/api_service.dart';

class AuthProvider with ChangeNotifier {
  User? _user;
  String? _token;
  bool _isLoading = false;

  User? get user => _user;
  String? get token => _token;
  bool get isAuthenticated => _token != null;
  bool get isLoading => _isLoading;

  AuthProvider() {
    Future.microtask(() => autoLogin());
  }

  Future<void> _saveAuthData() async {
    final prefs = await SharedPreferences.getInstance();
    if (_token != null && _user != null) {
      await prefs.setString('token', _token!);
      final userJson = jsonEncode(_user!.toJson());
      debugPrint('保存用户数据: $userJson');
      await prefs.setString('user', userJson);
    } else {
      await prefs.remove('token');
      await prefs.remove('user');
    }
  }

  /// 刷新当前登录用户的信息（用于资料修改后同步）
  Future<void> refreshUser(User updatedUser) async {
    _user = updatedUser;
    await _saveAuthData();
    notifyListeners();
  }

  Future<bool> autoLogin() async {
    _isLoading = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final userJson = prefs.getString('user');
      debugPrint('自动登录: token=$token, userJson=$userJson');
      if (token != null && userJson != null && userJson.isNotEmpty) {
        try {
          final userMap = jsonDecode(userJson) as Map<String, dynamic>;
          _token = token;
          _user = User.fromJson(userMap);
          ApiService.setToken(token);
          debugPrint('✅ 自动登录成功，用户: ${_user?.nickname}, id: ${_user?.id}');
          return true;
        } catch (e) {
          debugPrint('❌ 自动登录解析用户数据失败: $e');
          // 清除无效数据
          await prefs.remove('token');
          await prefs.remove('user');
          _token = null;
          _user = null;
          return false;
        }
      }
      debugPrint('自动登录: 无存储的 token 或 userJson');
      return false;
    } catch (e) {
      debugPrint('❌ 自动登录异常: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> register(String username, String password, String nickname,
      String email, String code) async {
    _isLoading = true;
    notifyListeners();
    try {
      await ApiService.register(username, password, nickname, email, code);
      return true;
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> login(String username, String password) async {
    debugPrint("🔐 开始登录，用户名: $username");
    _isLoading = true;
    notifyListeners();
    try {
      final result = await ApiService.login(username, password);
      debugPrint("✅ 登录返回结果: $result");
      _token = result['token'];
      if (result['user'] != null && result['user'] is Map<String, dynamic>) {
        _user = User.fromJson(result['user'] as Map<String, dynamic>);
      } else {
        throw Exception('用户数据无效');
      }
      ApiService.setToken(_token!);
      debugPrint("Token: $_token, 用户: ${_user?.toJson()}");
      await _saveAuthData();
      debugPrint("✅ 用户数据已保存");
      return true;
    } catch (e) {
      debugPrint("❌ 登录异常: $e");
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
      debugPrint("🔁 登录流程结束，isLoading = false");
    }
  }

  void logout() async {
    _token = null;
    _user = null;
    ApiService.setToken('');
    await _saveAuthData();
    notifyListeners();
  }
}
