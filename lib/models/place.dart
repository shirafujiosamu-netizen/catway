class Place {
  final String id;
  final String name;
  final String address;
  final double lat;
  final double lng;
  final String type;
  final List<String> photos;
  final String status;
  final List<String> tags;
  final String? submittedBy; // 新增：提交者用户ID

  Place({
    required this.id,
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
    required this.type,
    this.photos = const [],
    this.status = 'pending_review',
    this.tags = const [],
    this.submittedBy,
  });

  factory Place.fromJson(Map<String, dynamic> json) {
    return Place(
      id: json['_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0.0,
      type: json['type']?.toString() ?? 'shop',
      photos:
          (json['photos'] as List?)?.map((e) => e.toString()).toList() ?? [],
      status: json['status']?.toString() ?? 'pending_review',
      tags: (json['tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
      submittedBy: json['submittedBy']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'address': address,
      'lat': lat,
      'lng': lng,
      'type': type,
      'photos': photos,
      'status': status,
      'tags': tags,
      'submittedBy': submittedBy,
    };
  }
}
