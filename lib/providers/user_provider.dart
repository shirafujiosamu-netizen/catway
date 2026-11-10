import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/api_service.dart';

class UserProvider extends ChangeNotifier {
  User? _user;
  bool _isLoading = false;

  User? get user => _user;
  bool get isLoading => _isLoading;

  Future<void> fetchUserProfile(String userId) async {
    _isLoading = true;
    notifyListeners();
    try {
      final data = await ApiService.getUserProfile(userId);
      _user = User.fromJson(data);
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 新增：刷新当前用户资料（用于点赞后自动更新获赞数）
  Future<void> refreshCurrentUser() async {
    if (_user == null) return;
    await fetchUserProfile(_user!.id);
  }

  Future<void> updateProfile({
    String? nickname,
    String? bio,
    String? avatar,
    String? coverImage,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final updated = await ApiService.updateUserProfile({
        if (nickname != null) 'nickname': nickname,
        if (bio != null) 'bio': bio,
        if (avatar != null) 'avatar': avatar,
        if (coverImage != null) 'coverImage': coverImage,
      });
      _user = User.fromJson(updated);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggleFavorite(String placeId) async {
    if (_user == null) return;
    try {
      final newFavs = await ApiService.toggleFavorite(placeId);
      _user = User.fromJson({..._user!.toJson(), 'favoritePlaces': newFavs});
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> addFootprint(String placeId) async {
    if (_user == null) return;
    try {
      final newFootprints = await ApiService.addFootprint(placeId);
      _user = User.fromJson({..._user!.toJson(), 'footprints': newFootprints});
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> checkIn(String placeId) async {
    if (_user == null) return;
    try {
      final newCheckins = await ApiService.checkIn(placeId);
      _user = User.fromJson({..._user!.toJson(), 'checkins': newCheckins});
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> addToHistory(String placeId) async {
    if (_user == null) return;
    try {
      final newHistory = await ApiService.addToHistory(placeId);
      _user = User.fromJson({..._user!.toJson(), 'viewHistory': newHistory});
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> toggleFollow(String targetUserId) async {
    try {
      final result = await ApiService.toggleFollow(targetUserId);
      _user = User.fromJson({
        ..._user!.toJson(),
        'followingCount': result['followingCount'],
        'followersCount': result['followersCount']
      });
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }
}
