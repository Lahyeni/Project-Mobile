import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/spot_model.dart';

class SpotService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<List<FishingSpot>> getSpots() {
    return _firestore
        .collection('fishing_spots')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .handleError((error) {
      print('Erreur Firestore spots: $error');
      throw error;
    })
        .map((snapshot) {
      try {
        final spots = snapshot.docs.map((doc) {
          return _convertDocumentToSpot(doc);
        }).toList();

        print('=== ${spots.length} spots chargés avec succès ===');
        return spots;
      } catch (e) {
        print('Erreur conversion spots: $e');
        throw Exception('Erreur lors de la conversion des spots: $e');
      }
    });
  }

  FishingSpot _convertDocumentToSpot(DocumentSnapshot doc) {
    try {
      final data = doc.data() as Map<String, dynamic>? ?? {};

      DateTime createdAt;
      if (data['createdAt'] is Timestamp) {
        createdAt = (data['createdAt'] as Timestamp).toDate();
      } else if (data['createdAt'] is String) {
        createdAt = DateTime.parse(data['createdAt']);
      } else {
        createdAt = DateTime.now();
      }

      List<String> fishTypes = [];
      if (data['fishTypes'] is List) {
        fishTypes = (data['fishTypes'] as List).whereType<String>().toList();
      }

      List<String> likedBy = [];
      if (data['likedBy'] is List) {
        likedBy = (data['likedBy'] as List).whereType<String>().toList();
      }

      List<SpotImage> images = [];
      if (data['images'] is List) {
        images = (data['images'] as List).whereType<Map<String, dynamic>>().map((imageData) {
          try {
            return SpotImage.fromMap(imageData);
          } catch (e) {
            print('Erreur conversion image spot: $e - Data: $imageData');
            return SpotImage(
              base64Data: '',
              uploadedAt: DateTime.now(),
            );
          }
        }).toList();
      }

      double rating = 0.0;
      if (data['rating'] is double) {
        rating = data['rating'] as double;
      } else if (data['rating'] is int) {
        rating = (data['rating'] as int).toDouble();
      }

      int likes = 0;
      if (data['likes'] is int) {
        likes = data['likes'] as int;
      } else if (data['likes'] is double) {
        likes = (data['likes'] as double).toInt();
      } else {
        likes = likedBy.length;
      }

      // AJOUT: Récupération du type avec valeur par défaut
      String type = 'other';
      if (data['type'] is String && data['type'].isNotEmpty) {
        type = data['type'] as String;
      }

      return FishingSpot(
        id: doc.id,
        name: data['name']?.toString() ?? 'Nom inconnu',
        location: data['location']?.toString() ?? 'Localisation inconnue',
        description: data['description']?.toString() ?? '',
        fishTypes: fishTypes,
        rating: rating,
        difficulty: data['difficulty']?.toString() ?? 'Facile',
        bestSeason: data['bestSeason']?.toString() ?? 'Toute l\'année',
        coordinates: data['coordinates']?.toString() ?? '',
        type: type, // AJOUT: Type de spot
        images: images,
        createdBy: data['createdBy']?.toString() ?? 'unknown',
        createdAt: createdAt,
        likes: likes,
        likedBy: likedBy,
      );
    } catch (e) {
      print('Erreur critique conversion spot ${doc.id}: $e');
      return FishingSpot(
        id: doc.id,
        name: 'Erreur de chargement',
        location: 'Localisation inconnue',
        description: 'Ce spot ne peut pas être affiché',
        fishTypes: [],
        rating: 0.0,
        difficulty: 'Facile',
        bestSeason: 'Toute l\'année',
        coordinates: '',
        type: 'other', // AJOUT: Type par défaut en cas d'erreur
        images: [],
        createdBy: 'error',
        createdAt: DateTime.now(),
        likes: 0,
        likedBy: [],
      );
    }
  }

  Future<void> createSpot(FishingSpot spot) async {
    try {
      await _firestore.collection('fishing_spots').add(spot.toMap());
      print('Spot créé avec succès: ${spot.name} - Type: ${spot.type}');
    } catch (e) {
      print('Erreur création spot: $e');
      throw Exception('Impossible de créer le spot');
    }
  }

  Future<void> createSpotWithImages(FishingSpot spot) async {
    try {
      for (final image in spot.images) {
        if (image.sizeInKB > 1000) {
          throw Exception('L\'image ${image.caption ?? ''} est trop volumineuse (${image.sizeInKB}KB). Maximum: 1000KB');
        }
      }

      await createSpot(spot);

      print('Spot créé avec ${spot.images.length} images - Type: ${spot.type}');
    } catch (e) {
      print('Erreur création spot avec images: $e');
      throw Exception('Impossible de créer le spot avec images: $e');
    }
  }

  Future<void> updateSpot(String spotId, Map<String, dynamic> updates) async {
    try {
      await _firestore.collection('fishing_spots').doc(spotId).update(updates);
    } catch (e) {
      print('Erreur mise à jour spot: $e');
      throw Exception('Impossible de mettre à jour le spot');
    }
  }

  Future<void> deleteSpot(String spotId) async {
    try {
      await _firestore.collection('fishing_spots').doc(spotId).delete();
    } catch (e) {
      print('Erreur suppression spot: $e');
      throw Exception('Impossible de supprimer le spot');
    }
  }

  Future<void> toggleLikeSpot(String spotId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Utilisateur non connecté');

    try {
      final spotRef = _firestore.collection('fishing_spots').doc(spotId);

      await _firestore.runTransaction((transaction) async {
        final spotDoc = await transaction.get(spotRef);
        if (!spotDoc.exists) {
          throw Exception('Spot non trouvé');
        }

        final data = spotDoc.data() as Map<String, dynamic>;
        final List<String> currentLikedBy = List<String>.from(data['likedBy'] ?? []);
        final int currentLikes = (data['likes'] as int?) ?? 0;

        if (currentLikedBy.contains(user.uid)) {
          currentLikedBy.remove(user.uid);
          transaction.update(spotRef, {
            'likedBy': currentLikedBy,
            'likes': currentLikes - 1,
          });
        } else {
          currentLikedBy.add(user.uid);
          transaction.update(spotRef, {
            'likedBy': currentLikedBy,
            'likes': currentLikes + 1,
          });
        }
      });
    } catch (e) {
      print('Erreur toggle like spot: $e');
      throw Exception('Impossible de liker le spot');
    }
  }

  Future<void> toggleFavoriteSpot(String spotId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Utilisateur non connecté');

    try {
      final favoriteRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('favorite_spots')
          .doc(spotId);

      final favoriteDoc = await favoriteRef.get();

      if (favoriteDoc.exists) {
        await favoriteRef.delete();
        print('Spot retiré des favoris');
      } else {
        await favoriteRef.set({
          'spotId': spotId,
          'addedAt': FieldValue.serverTimestamp(),
        });
        print('Spot ajouté aux favoris');
      }
    } catch (e) {
      print('Erreur toggle favorite spot: $e');
      throw Exception('Impossible d\'ajouter aux favoris');
    }
  }

  Stream<List<FishingSpot>> getUserFavorites() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('favorite_spots')
        .snapshots()
        .asyncMap((favoritesSnapshot) async {
      final favoriteIds = favoritesSnapshot.docs.map((doc) => doc.id).toList();

      if (favoriteIds.isEmpty) return [];

      final spotsSnapshot = await _firestore
          .collection('fishing_spots')
          .where(FieldPath.documentId, whereIn: favoriteIds)
          .get();

      return spotsSnapshot.docs.map((doc) {
        return _convertDocumentToSpot(doc);
      }).toList();
    });
  }

  Future<bool> isSpotFavorite(String spotId) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final favoriteDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('favorite_spots')
          .doc(spotId)
          .get();

      return favoriteDoc.exists;
    } catch (e) {
      print('Erreur vérification favori: $e');
      return false;
    }
  }

  Future<bool> hasUserLikedSpot(String spotId) async {
    try {
      final spotDoc = await _firestore.collection('fishing_spots').doc(spotId).get();
      if (!spotDoc.exists) return false;

      final data = spotDoc.data() as Map<String, dynamic>;
      final List<String> likedBy = List<String>.from(data['likedBy'] ?? []);
      final user = _auth.currentUser;

      return user != null && likedBy.contains(user.uid);
    } catch (e) {
      print('Erreur vérification like: $e');
      return false;
    }
  }

  Future<List<FishingSpot>> getSpotsOnce() async {
    try {
      final snapshot = await _firestore
          .collection('fishing_spots')
          .orderBy('createdAt', descending: true)
          .get();

      final spots = snapshot.docs.map((doc) {
        return _convertDocumentToSpot(doc);
      }).toList();

      print('=== ${spots.length} spots chargés (one-time) ===');
      return spots;
    } catch (e) {
      print('Erreur chargement spots one-time: $e');
      throw Exception('Erreur lors du chargement des spots: $e');
    }
  }

  // AJOUT: Méthode pour récupérer les spots par type
  Stream<List<FishingSpot>> getSpotsByType(String type) {
    if (type == 'all') {
      return getSpots();
    }

    return _firestore
        .collection('fishing_spots')
        .where('type', isEqualTo: type)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .handleError((error) {
      print('Erreur Firestore spots par type: $error');
      throw error;
    })
        .map((snapshot) {
      try {
        final spots = snapshot.docs.map((doc) {
          return _convertDocumentToSpot(doc);
        }).toList();

        print('=== ${spots.length} spots de type $type chargés avec succès ===');
        return spots;
      } catch (e) {
        print('Erreur conversion spots par type: $e');
        throw Exception('Erreur lors de la conversion des spots par type: $e');
      }
    });
  }

  // AJOUT: Méthode pour récupérer les spots une fois par type
  Future<List<FishingSpot>> getSpotsByTypeOnce(String type) async {
    if (type == 'all') {
      return getSpotsOnce();
    }

    try {
      final snapshot = await _firestore
          .collection('fishing_spots')
          .where('type', isEqualTo: type)
          .orderBy('createdAt', descending: true)
          .get();

      final spots = snapshot.docs.map((doc) {
        return _convertDocumentToSpot(doc);
      }).toList();

      print('=== ${spots.length} spots de type $type chargés (one-time) ===');
      return spots;
    } catch (e) {
      print('Erreur chargement spots par type one-time: $e');
      throw Exception('Erreur lors du chargement des spots par type: $e');
    }
  }
}