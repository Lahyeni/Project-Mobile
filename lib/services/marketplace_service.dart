import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/marketplace_model.dart';

class MarketplaceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<List<MarketplaceItem>> getItems() {
    return _firestore
        .collection('marketplace_items')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .handleError((error) {
      print('Erreur Firestore marketplace: $error');
      throw error;
    })
        .map((snapshot) {
      try {
        final items = snapshot.docs.map((doc) {
          return _convertDocumentToItem(doc);
        }).toList();

        print('=== ${items.length} items marketplace chargés ===');
        return items;
      } catch (e) {
        print('Erreur conversion items: $e');
        throw Exception('Erreur lors de la conversion des items: $e');
      }
    });
  }

  Stream<List<MarketplaceItem>> getItemsByCategory(String category) {
    return _firestore
        .collection('marketplace_items')
        .where('category', isEqualTo: category)
        .where('isAvailable', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return _convertDocumentToItem(doc);
      }).toList();
    });
  }

  MarketplaceItem _convertDocumentToItem(DocumentSnapshot doc) {
    try {
      final data = doc.data() as Map<String, dynamic>? ?? {};

      // CORRECTION: Conversion sécurisée de tous les champs
      DateTime createdAt;
      if (data['createdAt'] is Timestamp) {
        createdAt = (data['createdAt'] as Timestamp).toDate();
      } else if (data['createdAt'] is String) {
        createdAt = DateTime.parse(data['createdAt']);
      } else {
        createdAt = DateTime.now();
      }

      // CORRECTION: Conversion sécurisée des images
      List<ItemImage> images = [];
      if (data['images'] is List) {
        images = (data['images'] as List).whereType<Map<String, dynamic>>().map((imageData) {
          try {
            return ItemImage.fromMap(imageData);
          } catch (e) {
            print('Erreur conversion image item: $e - Data: $imageData');
            return ItemImage(
              base64Data: '',
              uploadedAt: DateTime.now(),
            );
          }
        }).toList();
      }

      // CORRECTION: Conversion sécurisée de likedBy
      List<String> likedBy = [];
      if (data['likedBy'] is List) {
        likedBy = (data['likedBy'] as List).map((item) => item.toString()).toList();
      }

      // CORRECTION: Conversion sécurisée du prix
      double price = 0.0;
      if (data['price'] is double) {
        price = data['price'] as double;
      } else if (data['price'] is int) {
        price = (data['price'] as int).toDouble();
      } else if (data['price'] is String) {
        price = double.tryParse(data['price']) ?? 0.0;
      }

      // CORRECTION: Conversion sécurisée des likes
      int likes = 0;
      if (data['likes'] is int) {
        likes = data['likes'] as int;
      } else if (data['likes'] is double) {
        likes = (data['likes'] as double).toInt();
      } else if (data['likes'] is String) {
        likes = int.tryParse(data['likes']) ?? 0;
      } else {
        // Si likes n'est pas un nombre, utiliser la longueur de likedBy
        likes = likedBy.length;
      }

      // CORRECTION: Conversion sécurisée de isAvailable
      bool isAvailable = true;
      if (data['isAvailable'] is bool) {
        isAvailable = data['isAvailable'] as bool;
      } else if (data['isAvailable'] is String) {
        isAvailable = data['isAvailable'] == 'true';
      }

      return MarketplaceItem(
        id: doc.id,
        title: data['title']?.toString() ?? 'Sans titre',
        description: data['description']?.toString() ?? '',
        price: price,
        category: data['category']?.toString() ?? 'tools',
        images: images,
        sellerId: data['sellerId']?.toString() ?? 'unknown',
        sellerName: data['sellerName']?.toString() ?? 'Vendeur',
        sellerPhoto: data['sellerPhoto']?.toString() ?? '',
        location: data['location']?.toString() ?? '',
        condition: data['condition']?.toString() ?? 'used',
        isAvailable: isAvailable,
        createdAt: createdAt,
        likes: likes,
        likedBy: likedBy,
      );
    } catch (e) {
      print('Erreur critique conversion item ${doc.id}: $e');
      return MarketplaceItem(
        id: doc.id,
        title: 'Erreur de chargement',
        description: 'Cet item ne peut pas être affiché',
        price: 0,
        category: 'tools',
        images: [],
        sellerId: 'error',
        sellerName: 'Erreur',
        sellerPhoto: '',
        location: '',
        condition: 'used',
        isAvailable: false,
        createdAt: DateTime.now(),
        likes: 0,
        likedBy: [],
      );
    }
  }

  // ... (le reste des méthodes reste inchangé)
  Future<void> createItem(MarketplaceItem item) async {
    try {
      await _firestore.collection('marketplace_items').add(item.toMap());
      print('Item créé avec succès: ${item.title}');
    } catch (e) {
      print('Erreur création item: $e');
      throw Exception('Impossible de créer l\'item');
    }
  }

  Future<void> createItemWithImages(MarketplaceItem item) async {
    try {
      for (final image in item.images) {
        if (image.sizeInKB > 1000) {
          throw Exception('L\'image est trop volumineuse (${image.sizeInKB}KB). Maximum: 1000KB');
        }
      }

      await createItem(item);
      print('Item créé avec ${item.images.length} images');
    } catch (e) {
      print('Erreur création item avec images: $e');
      throw Exception('Impossible de créer l\'item avec images: $e');
    }
  }

  Future<void> updateItem(String itemId, Map<String, dynamic> updates) async {
    try {
      await _firestore.collection('marketplace_items').doc(itemId).update(updates);
    } catch (e) {
      print('Erreur mise à jour item: $e');
      throw Exception('Impossible de mettre à jour l\'item');
    }
  }

  Future<void> deleteItem(String itemId) async {
    try {
      await _firestore.collection('marketplace_items').doc(itemId).delete();
    } catch (e) {
      print('Erreur suppression item: $e');
      throw Exception('Impossible de supprimer l\'item');
    }
  }

  Future<void> toggleLikeItem(String itemId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Utilisateur non connecté');

    try {
      final itemRef = _firestore.collection('marketplace_items').doc(itemId);

      await _firestore.runTransaction((transaction) async {
        final itemDoc = await transaction.get(itemRef);
        if (!itemDoc.exists) {
          throw Exception('Item non trouvé');
        }

        final data = itemDoc.data() as Map<String, dynamic>;
        final List<String> currentLikedBy = List<String>.from(data['likedBy'] ?? []);
        final int currentLikes = (data['likes'] as int?) ?? 0;

        if (currentLikedBy.contains(user.uid)) {
          currentLikedBy.remove(user.uid);
          transaction.update(itemRef, {
            'likedBy': currentLikedBy,
            'likes': currentLikes - 1,
          });
        } else {
          currentLikedBy.add(user.uid);
          transaction.update(itemRef, {
            'likedBy': currentLikedBy,
            'likes': currentLikes + 1,
          });
        }
      });
    } catch (e) {
      print('Erreur toggle like item: $e');
      throw Exception('Impossible de liker l\'item');
    }
  }

  Future<void> toggleAvailability(String itemId, bool isAvailable) async {
    try {
      await _firestore.collection('marketplace_items').doc(itemId).update({
        'isAvailable': isAvailable,
      });
    } catch (e) {
      print('Erreur changement disponibilité: $e');
      throw Exception('Impossible de changer la disponibilité');
    }
  }

  Stream<List<MarketplaceItem>> getUserItems(String userId) {
    return _firestore
        .collection('marketplace_items')
        .where('sellerId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return _convertDocumentToItem(doc);
      }).toList();
    });
  }

  Stream<List<MarketplaceItem>> getUserFavorites() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('favorite_items')
        .snapshots()
        .asyncMap((favoritesSnapshot) async {
      final favoriteIds = favoritesSnapshot.docs.map((doc) => doc.id).toList();

      if (favoriteIds.isEmpty) return [];

      final itemsSnapshot = await _firestore
          .collection('marketplace_items')
          .where(FieldPath.documentId, whereIn: favoriteIds)
          .get();

      return itemsSnapshot.docs.map((doc) {
        return _convertDocumentToItem(doc);
      }).toList();
    });
  }

  Future<void> toggleFavoriteItem(String itemId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Utilisateur non connecté');

    try {
      final favoriteRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('favorite_items')
          .doc(itemId);

      final favoriteDoc = await favoriteRef.get();

      if (favoriteDoc.exists) {
        await favoriteRef.delete();
        print('Item retiré des favoris');
      } else {
        await favoriteRef.set({
          'itemId': itemId,
          'addedAt': FieldValue.serverTimestamp(),
        });
        print('Item ajouté aux favoris');
      }
    } catch (e) {
      print('Erreur toggle favorite item: $e');
      throw Exception('Impossible d\'ajouter aux favoris');
    }
  }

  Future<bool> isItemFavorite(String itemId) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final favoriteDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('favorite_items')
          .doc(itemId)
          .get();

      return favoriteDoc.exists;
    } catch (e) {
      print('Erreur vérification favori: $e');
      return false;
    }
  }
}