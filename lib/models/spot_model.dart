import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
class FishingSpot {
  final String id;
  final String name;
  final String location;
  final String description;
  final List<String> fishTypes;
  final double rating;
  final String difficulty;
  final String bestSeason;
  final String coordinates;
  final String type; // AJOUT: Type de spot
  final List<SpotImage> images;
  final String createdBy;
  final DateTime createdAt;
  final int likes;
  final List<String> likedBy;

  FishingSpot({
    required this.id,
    required this.name,
    required this.location,
    required this.description,
    required this.fishTypes,
    required this.rating,
    required this.difficulty,
    required this.bestSeason,
    required this.coordinates,
    required this.type, // AJOUT: Type de spot
    this.images = const [],
    required this.createdBy,
    required this.createdAt,
    this.likes = 0,
    this.likedBy = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'location': location,
      'description': description,
      'fishTypes': fishTypes,
      'rating': rating,
      'difficulty': difficulty,
      'bestSeason': bestSeason,
      'coordinates': coordinates,
      'type': type, // AJOUT: Type de spot
      'images': images.map((image) => image.toMap()).toList(),
      'createdBy': createdBy,
      'createdAt': createdAt,
      'likes': likes,
      'likedBy': likedBy,
    };
  }

  factory FishingSpot.fromFirestore(String id, Map<String, dynamic> data) {
    return FishingSpot(
      id: id,
      name: data['name'] ?? '',
      location: data['location'] ?? '',
      description: data['description'] ?? '',
      fishTypes: List<String>.from(data['fishTypes'] ?? []),
      rating: (data['rating'] ?? 0).toDouble(),
      difficulty: data['difficulty'] ?? 'Facile',
      bestSeason: data['bestSeason'] ?? 'Toute l\'année',
      coordinates: data['coordinates'] ?? '',
      type: data['type'] ?? 'other', // AJOUT: Type de spot avec valeur par défaut
      images: _parseImages(data['images']),
      createdBy: data['createdBy'] ?? '',
      createdAt: _parseTimestamp(data['createdAt']),
      likes: data['likes'] ?? 0,
      likedBy: List<String>.from(data['likedBy'] ?? []),
    );
  }


  static List<SpotImage> _parseImages(dynamic imagesData) {
    if (imagesData is! List) return [];

    try {
      return (imagesData as List).whereType<Map<String, dynamic>>().map((imageData) {
        return SpotImage.fromMap(imageData);
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




  bool get hasImages => images.isNotEmpty;

  String? get firstImageBase64 {
    if (images.isEmpty) return null;
    return images.first.base64Data;
  }

  @override
  String toString() {
    return 'FishingSpot{id: $id, name: $name, location: $location, rating: $rating, images: ${images.length}}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is FishingSpot &&
              runtimeType == other.runtimeType &&
              id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class SpotImage {
  final String base64Data;
  final String? caption;
  final DateTime uploadedAt;

  SpotImage({
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

  factory SpotImage.fromMap(Map<String, dynamic> map) {
    return SpotImage(
      base64Data: map['base64Data'] ?? '',
      caption: map['caption'],
      uploadedAt: DateTime.parse(map['uploadedAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  int get sizeInKB {
    return (base64Data.length * 3 / 4 / 1024).ceil();
  }
}