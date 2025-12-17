import 'package:cloud_firestore/cloud_firestore.dart';

class Post {
  final String id;
  final String userId;
  final String userPhoto;
  final String userName;
  final String content;
  final List<PostImage> images;
  final String? fishType;
  final double? fishWeight;
  final String? location;
  final DateTime timestamp;
  final int likes;
  final List<String> likedBy;
  final List<Comment> comments;

  Post({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userPhoto,
    required this.content,
    this.images = const [],
    this.fishType,
    this.fishWeight,
    this.location,
    required this.timestamp,
    this.likes = 0,
    this.likedBy = const [],
    this.comments = const [], required String imageUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'userPhoto': userPhoto,
      'content': content,
      'images': images.map((image) => image.toMap()).toList(),
      'fishType': fishType,
      'fishWeight': fishWeight,
      'location': location,
      'timestamp': timestamp,
      'likes': likes,
      'likedBy': likedBy,
      'comments': comments.map((comment) => comment.toMap()).toList(),
    };
  }

  // Vérifier si le post a des images
  bool get hasImages => images.isNotEmpty;

  // Obtenir la première image (pour vignette)
  String? get firstImageBase64 {
    if (images.isEmpty) return null;
    return images.first.base64Data;
  }
}

class PostImage {
  final String base64Data; // Image en base64
  final String? caption; // Légende optionnelle
  final DateTime uploadedAt;

  PostImage({
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

  factory PostImage.fromMap(Map<String, dynamic> map) {
    return PostImage(
      base64Data: map['base64Data'] ?? '',
      caption: map['caption'],
      uploadedAt: DateTime.parse(map['uploadedAt']),
    );
  }

  // Taille approximative de l'image
  int get sizeInKB {
    return (base64Data.length * 3 / 4 / 1024).ceil();
  }
}
class Comment {
  final String id;
  final String userId;
  final String userName;
  final String userPhoto; // AJOUT: Ce champ doit contenir l'URL base64 ou URL
  final String content;
  final DateTime timestamp;

  Comment({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userPhoto, // AJOUT
    required this.content,
    required this.timestamp,
  });

  // Dans post_model.dart - Classe Comment
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'userPhoto': userPhoto, // DOIT ÊTRE INCLUS
      'content': content,
      'timestamp': Timestamp.fromDate(timestamp), // CRITIQUE: Convertir en Timestamp
    };
  }

  factory Comment.fromMap(Map<String, dynamic> map) {
    return Comment(
      id: map['id'],
      userId: map['userId'],
      userName: map['userName'],
      userPhoto: map['userPhoto'] ?? '', // AJOUT avec fallback
      content: map['content'],
      timestamp: map['timestamp'].toDate(),
    );
  }
}