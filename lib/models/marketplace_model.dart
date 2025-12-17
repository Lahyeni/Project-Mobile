import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

class MarketplaceItem {
  final String id;
  final String title;
  final String description;
  final double price;
  final String category; // 'tools', 'baits', 'fresh_fish'
  final List<ItemImage> images;
  final String sellerId;
  final String sellerName;
  final String sellerPhoto;
  final String location;
  final String condition; // 'new', 'used', 'excellent'
  final bool isAvailable;
  final DateTime createdAt;
  final int likes;
  final List<String> likedBy;

  MarketplaceItem({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.category,
    this.images = const [],
    required this.sellerId,
    required this.sellerName,
    required this.sellerPhoto,
    required this.location,
    required this.condition,
    this.isAvailable = true,
    required this.createdAt,
    this.likes = 0,
    this.likedBy = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'price': price,
      'category': category,
      'images': images.map((image) => image.toMap()).toList(),
      'sellerId': sellerId,
      'sellerName': sellerName,
      'sellerPhoto': sellerPhoto,
      'location': location,
      'condition': condition,
      'isAvailable': isAvailable,
      'createdAt': createdAt,
      'likes': likes,
      'likedBy': likedBy,
    };
  }

  factory MarketplaceItem.fromFirestore(String id, Map<String, dynamic> data) {
    return MarketplaceItem(
      id: id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      price: (data['price'] ?? 0).toDouble(),
      category: data['category'] ?? 'tools',
      images: _parseImages(data['images']),
      sellerId: data['sellerId'] ?? '',
      sellerName: data['sellerName'] ?? 'Vendeur',
      sellerPhoto: data['sellerPhoto'] ?? '',
      location: data['location'] ?? '',
      condition: data['condition'] ?? 'used',
      isAvailable: data['isAvailable'] ?? true,
      createdAt: _parseTimestamp(data['createdAt']),
      likes: data['likes'] ?? 0,
      likedBy: List<String>.from(data['likedBy'] ?? []),
    );
  }

  static List<ItemImage> _parseImages(dynamic imagesData) {
    if (imagesData is! List) return [];

    try {
      return (imagesData as List).whereType<Map<String, dynamic>>().map((imageData) {
        return ItemImage.fromMap(imageData);
      }).toList();
    } catch (e) {
      print('Erreur parsing images: $e');
      return [];
    }
  }

  static DateTime _parseTimestamp(dynamic timestamp) {
    if (timestamp == null) return DateTime.now();

    if (timestamp is DateTime) {
      return timestamp;
    }

    try {
      if (timestamp is Timestamp) {
        return timestamp.toDate();
      }
    } catch (e) {
      print('Erreur parsing timestamp: $e');
    }

    return DateTime.now();
  }

  factory MarketplaceItem.fromFormData({
    required String id,
    required String title,
    required String description,
    required double price,
    required String category,
    required List<ItemImage> images,
    required String sellerId,
    required String sellerName,
    required String sellerPhoto,
    required String location,
    required String condition,
  }) {
    return MarketplaceItem(
      id: id,
      title: title,
      description: description,
      price: price,
      category: category,
      images: images,
      sellerId: sellerId,
      sellerName: sellerName,
      sellerPhoto: sellerPhoto,
      location: location,
      condition: condition,
      createdAt: DateTime.now(),
      likes: 0,
      likedBy: [],
    );
  }

  bool get hasImages => images.isNotEmpty;

  String? get firstImageBase64 {
    if (images.isEmpty) return null;
    return images.first.base64Data;
  }

  String get formattedPrice {
    return '€${price.toStringAsFixed(2)}';
  }

  String get categoryLabel {
    switch (category) {
      case 'tools':
        return 'Outils de pêche';
      case 'baits':
        return 'Appâts';
      case 'fresh_fish':
        return 'Poisson frais';
      default:
        return 'Autre';
    }
  }

  String get conditionLabel {
    switch (condition) {
      case 'new':
        return 'Neuf';
      case 'used':
        return 'Occasion';
      case 'excellent':
        return 'Excellent état';
      default:
        return condition;
    }
  }

  @override
  String toString() {
    return 'MarketplaceItem{id: $id, title: $title, price: $price, category: $category}';
  }
}

class ItemImage {
  final String base64Data;
  final String? caption;
  final DateTime uploadedAt;

  ItemImage({
    required this.base64Data,
    this.caption,
    required this.uploadedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'base64Data': base64Data,
      'caption': caption,
      'uploadedAt': uploadedAt.toIso8601String(),
    };
  }

  factory ItemImage.fromMap(Map<String, dynamic> map) {
    return ItemImage(
      base64Data: map['base64Data'] ?? '',
      caption: map['caption'],
      uploadedAt: DateTime.parse(map['uploadedAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  int get sizeInKB {
    return (base64Data.length * 3 / 4 / 1024).ceil();
  }
}