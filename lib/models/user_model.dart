import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp, FieldValue;

class UserProfile {
  final String uid;
  final String email;
  final String? displayName;
  final String? photoURL;
  final String? bio;
  final String? location;
  final String? favoriteSpot;
  final List<String> fishingGear;
  final List<String> preferredFishTypes;
  final String? phoneNumber;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDarkMode;
  final String language;
  final int postCount;
  final int followerCount;
  final int followingCount;

  UserProfile({
    required this.uid,
    required this.email,
    this.displayName,
    this.photoURL,
    this.bio,
    this.location,
    this.favoriteSpot,
    this.fishingGear = const [],
    this.preferredFishTypes = const [],
    this.phoneNumber,
    required this.createdAt,
    required this.updatedAt,
    this.isDarkMode = false,
    this.language = 'fr',
    this.postCount = 0,
    this.followerCount = 0,
    this.followingCount = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'photoURL': photoURL,
      'bio': bio,
      'location': location,
      'favoriteSpot': favoriteSpot,
      'fishingGear': fishingGear,
      'preferredFishTypes': preferredFishTypes,
      'phoneNumber': phoneNumber,
      'createdAt': Timestamp.fromDate(createdAt), // CORRECTION: Convertir en Timestamp
      'updatedAt': Timestamp.fromDate(updatedAt), // CORRECTION: Convertir en Timestamp
      'isDarkMode': isDarkMode,
      'language': language,
      'postCount': postCount,
      'followerCount': followerCount,
      'followingCount': followingCount,
    };
  }

  // AJOUT: Méthode pour Firestore avec FieldValue
  Map<String, dynamic> toFirestoreMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'photoURL': photoURL,
      'bio': bio,
      'location': location,
      'favoriteSpot': favoriteSpot,
      'fishingGear': fishingGear,
      'preferredFishTypes': preferredFishTypes,
      'phoneNumber': phoneNumber,
      'createdAt': FieldValue.serverTimestamp(), // Pour la création
      'updatedAt': FieldValue.serverTimestamp(), // Pour la mise à jour
      'isDarkMode': isDarkMode,
      'language': language,
      'postCount': postCount,
      'followerCount': followerCount,
      'followingCount': followingCount,
    };
  }

  // AJOUT: Méthode pour les mises à jour partielles
  Map<String, dynamic> toUpdateMap() {
    return {
      'displayName': displayName,
      'photoURL': photoURL,
      'bio': bio,
      'location': location,
      'favoriteSpot': favoriteSpot,
      'fishingGear': fishingGear,
      'preferredFishTypes': preferredFishTypes,
      'phoneNumber': phoneNumber,
      'updatedAt': FieldValue.serverTimestamp(),
      'isDarkMode': isDarkMode,
      'language': language,
      'postCount': postCount,
      'followerCount': followerCount,
      'followingCount': followingCount,
    };
  }

  factory UserProfile.fromFirestore(String uid, Map<String, dynamic> data) {
    return UserProfile(
      uid: uid,
      email: data['email'] ?? '',
      displayName: data['displayName'],
      photoURL: data['photoURL'],
      bio: data['bio'],
      location: data['location'],
      favoriteSpot: data['favoriteSpot'],
      fishingGear: List<String>.from(data['fishingGear'] ?? []),
      preferredFishTypes: List<String>.from(data['preferredFishTypes'] ?? []),
      phoneNumber: data['phoneNumber'],
      createdAt: _parseTimestamp(data['createdAt']),
      updatedAt: _parseTimestamp(data['updatedAt']),
      isDarkMode: data['isDarkMode'] ?? false,
      language: data['language'] ?? 'fr',
      postCount: data['postCount'] ?? 0,
      followerCount: data['followerCount'] ?? 0,
      followingCount: data['followingCount'] ?? 0,
    );
  }

  // AJOUT: Factory pour la création d'un nouveau profil
  factory UserProfile.createNew({
    required String uid,
    required String email,
    String? displayName,
    String? photoURL,
  }) {
    final now = DateTime.now();
    return UserProfile(
      uid: uid,
      email: email,
      displayName: displayName,
      photoURL: photoURL,
      bio: null,
      location: null,
      favoriteSpot: null,
      fishingGear: [],
      preferredFishTypes: [],
      phoneNumber: null,
      createdAt: now,
      updatedAt: now,
      isDarkMode: false,
      language: 'fr',
      postCount: 0,
      followerCount: 0,
      followingCount: 0,
    );
  }

  static DateTime _parseTimestamp(dynamic timestamp) {
    if (timestamp == null) return DateTime.now();
    if (timestamp is DateTime) return timestamp;
    if (timestamp is Timestamp) return timestamp.toDate();

    // AJOUT: Gestion des strings
    if (timestamp is String) {
      try {
        return DateTime.parse(timestamp);
      } catch (e) {
        print('Erreur parsing timestamp string: $e');
        return DateTime.now();
      }
    }

    return DateTime.now();
  }

  UserProfile copyWith({
    String? displayName,
    String? photoURL,
    String? bio,
    String? location,
    String? favoriteSpot,
    List<String>? fishingGear,
    List<String>? preferredFishTypes,
    String? phoneNumber,
    bool? isDarkMode,
    String? language,
    int? postCount,
    int? followerCount,
    int? followingCount,
  }) {
    return UserProfile(
      uid: uid,
      email: email,
      displayName: displayName ?? this.displayName,
      photoURL: photoURL ?? this.photoURL,
      bio: bio ?? this.bio,
      location: location ?? this.location,
      favoriteSpot: favoriteSpot ?? this.favoriteSpot,
      fishingGear: fishingGear ?? this.fishingGear,
      preferredFishTypes: preferredFishTypes ?? this.preferredFishTypes,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      isDarkMode: isDarkMode ?? this.isDarkMode,
      language: language ?? this.language,
      postCount: postCount ?? this.postCount,
      followerCount: followerCount ?? this.followerCount,
      followingCount: followingCount ?? this.followingCount,
    );
  }

  // AJOUT: Méthode pour incrémenter les compteurs
  UserProfile incrementPostCount() {
    return copyWith(postCount: postCount + 1);
  }

  UserProfile incrementFollowerCount() {
    return copyWith(followerCount: followerCount + 1);
  }

  UserProfile decrementFollowerCount() {
    return copyWith(followerCount: followerCount - 1);
  }

  UserProfile incrementFollowingCount() {
    return copyWith(followingCount: followingCount + 1);
  }

  UserProfile decrementFollowingCount() {
    return copyWith(followingCount: followingCount - 1);
  }

  bool get hasProfileImage => photoURL != null && photoURL!.isNotEmpty;

  String get displayNameOrEmail => displayName ?? email.split('@')[0];

  // AJOUT: Méthode pour vérifier si le profil est complet
  bool get isProfileComplete {
    return displayName != null &&
        displayName!.isNotEmpty &&
        photoURL != null &&
        photoURL!.isNotEmpty;
  }

  // AJOUT: Méthode pour obtenir les données de base pour l'affichage
  Map<String, dynamic> get basicInfo {
    return {
      'displayName': displayNameOrEmail,
      'photoURL': photoURL,
      'bio': bio,
      'location': location,
      'postCount': postCount,
      'followerCount': followerCount,
      'followingCount': followingCount,
    };
  }

  // AJOUT: Méthode toString pour le débogage
  @override
  String toString() {
    return 'UserProfile{uid: $uid, displayName: $displayName, email: $email, postCount: $postCount, followers: $followerCount, following: $followingCount}';
  }

  // AJOUT: Méthode pour comparer deux profils
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is UserProfile &&
              runtimeType == other.runtimeType &&
              uid == other.uid;

  @override
  int get hashCode => uid.hashCode;
}