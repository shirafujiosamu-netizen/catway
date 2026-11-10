class Moment {
  final String id;
  final String userId;
  final String userName;
  final String userAvatar;
  final String userAccount;
  final String content;
  final List<String> images;
  final int likesCount;
  final int commentCount;
  final int shareCount;
  final DateTime createdAt;
  final bool isLiked; // 新增：当前用户是否已点赞

  Moment({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userAvatar,
    required this.userAccount,
    required this.content,
    required this.images,
    this.likesCount = 0,
    this.commentCount = 0,
    this.shareCount = 0,
    required this.createdAt,
    this.isLiked = false,
  });

  factory Moment.fromJson(Map<String, dynamic> json) {
    return Moment(
      id: json['_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      userName: json['userName']?.toString() ?? '神秘漫友',
      userAvatar: json['userAvatar']?.toString() ?? '',
      userAccount: json['userAccount']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      images:
          (json['images'] as List?)?.map((e) => e.toString()).toList() ?? [],
      likesCount: json['likesCount'] as int? ?? 0,
      commentCount: json['commentCount'] as int? ?? 0,
      shareCount: json['shareCount'] as int? ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'].toString())
          : DateTime.now(),
      isLiked: json['isLiked'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'content': content,
      'images': images,
      'type': 'moment',
    };
  }
}
