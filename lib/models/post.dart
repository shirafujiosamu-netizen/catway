class Post {
  final String id;
  final String userId;
  final String userName;
  final String userAccount;
  final String userAvatar;
  final String title;
  final String content;
  final List<String> images;
  final String category;
  final int likesCount;
  final int commentCount;
  final DateTime createdAt;
  final String? ip;
  final String? productType;
  final String? shopType;
  final String summary;
  final String keywords;
  final bool isLiked; // 新增：当前用户是否已点赞

  Post({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userAccount,
    required this.userAvatar,
    required this.title,
    required this.content,
    required this.images,
    required this.category,
    this.likesCount = 0,
    this.commentCount = 0,
    required this.createdAt,
    this.ip,
    this.productType,
    this.shopType,
    this.summary = '',
    this.keywords = '',
    this.isLiked = false, // 默认 false
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      userName: json['userName']?.toString() ?? '神秘漫友',
      userAccount: json['userAccount']?.toString() ?? '',
      userAvatar: json['userAvatar']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      images:
          (json['images'] as List?)?.map((e) => e.toString()).toList() ?? [],
      category: json['category']?.toString() ?? '闲聊',
      likesCount: json['likesCount'] as int? ?? 0,
      commentCount: json['commentCount'] as int? ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'].toString())
          : DateTime.now(),
      ip: json['ip']?.toString(),
      productType: json['productType']?.toString(),
      shopType: json['shopType']?.toString(),
      summary: json['summary']?.toString() ?? '',
      keywords: json['keywords']?.toString() ?? '',
      isLiked: json['isLiked'] as bool? ?? false,
    );
  }
}
