class User {
  final String id;
  final String username;
  final String nickname;
  final String email;
  final String avatar;
  final String coverImage;
  final String bio;
  final int followersCount;
  final int followingCount;
  final int likesReceived; // 新增
  final List<String> favoritePlaces;
  final List<String> footprints;
  final List<String> checkins;
  final List<String> viewHistory;
  final List<String> strategies;
  final String role;

  User({
    required this.id,
    required this.username,
    required this.nickname,
    required this.email,
    required this.avatar,
    required this.coverImage,
    required this.bio,
    required this.followersCount,
    required this.followingCount,
    required this.likesReceived, // 新增
    required this.favoritePlaces,
    required this.footprints,
    required this.checkins,
    required this.viewHistory,
    required this.strategies,
    required this.role,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      nickname: json['nickname']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      avatar: json['avatar']?.toString() ?? '',
      coverImage: json['coverImage']?.toString() ?? '',
      bio: json['bio']?.toString() ?? '',
      followersCount: json['followersCount'] as int? ?? 0,
      followingCount: json['followingCount'] as int? ?? 0,
      likesReceived: json['likesReceived'] as int? ?? 0, // 新增
      favoritePlaces: (json['favoritePlaces'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      footprints:
          (json['footprints'] as List?)?.map((e) => e.toString()).toList() ??
              [],
      checkins:
          (json['checkins'] as List?)?.map((e) => e.toString()).toList() ?? [],
      viewHistory:
          (json['viewHistory'] as List?)?.map((e) => e.toString()).toList() ??
              [],
      strategies:
          (json['strategies'] as List?)?.map((e) => e.toString()).toList() ??
              [],
      role: json['role']?.toString() ?? 'user',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'nickname': nickname,
      'email': email,
      'avatar': avatar,
      'coverImage': coverImage,
      'bio': bio,
      'followersCount': followersCount,
      'followingCount': followingCount,
      'likesReceived': likesReceived,
      'favoritePlaces': favoritePlaces,
      'footprints': footprints,
      'checkins': checkins,
      'viewHistory': viewHistory,
      'strategies': strategies,
      'role': role,
    };
  }
}
