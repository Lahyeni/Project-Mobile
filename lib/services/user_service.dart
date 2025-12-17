import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Créer ou mettre à jour le profil utilisateur
  Future<void> saveUserProfile(UserProfile userProfile) async {
    try {
      await _firestore
          .collection('users')
          .doc(userProfile.uid)
          .set(userProfile.toMap(), SetOptions(merge: true));
      print('Profil utilisateur sauvegardé: ${userProfile.uid}');
    } catch (e) {
      print('Erreur sauvegarde profil: $e');
      throw Exception('Impossible de sauvegarder le profil');
    }
  }

  // Récupérer le profil utilisateur
  Stream<UserProfile?> getUserProfile(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .snapshots(includeMetadataChanges: true)
        .map((snapshot) {
      if (!snapshot.exists) {
        print('❌ Document utilisateur $uid non trouvé');
        return null;
      }

      final data = snapshot.data()!;
      print('✅ Données utilisateur récupérées: ${data.keys}');
      print('📸 PhotoURL: ${data['photoURL']?.toString().substring(0, min(50, data['photoURL']?.toString().length ?? 0))}');

      return UserProfile.fromFirestore(uid, data);
    })
        .handleError((error) {
      print('❌ Erreur stream profil: $error');
      return null;
    });
  }

  // Mettre à jour la photo de profil (base64)
  Future<void> updateProfileImage(String uid, String base64Image) async {
    try {
      // FORMAT correct pour base64
      final String formattedImage = base64Image.startsWith('data:image')
          ? base64Image
          : 'data:image/jpeg;base64,$base64Image';

      print('🔄 Mise à jour photo profil: $uid');

      await _firestore.collection('users').doc(uid).update({
        'photoURL': formattedImage,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Photo profil mise à jour avec succès');

    } catch (e) {
      print('❌ Erreur mise à jour photo: $e');
      throw Exception('Impossible de mettre à jour la photo: $e');
    }
  }

  // Mettre à jour les préférences (dark mode, langue)
  Future<void> updateUserPreferences({
    required String uid,
    bool? isDarkMode,
    String? language,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (isDarkMode != null) updates['isDarkMode'] = isDarkMode;
      if (language != null) updates['language'] = language;

      await _firestore.collection('users').doc(uid).update(updates);
      print('Préférences utilisateur mises à jour');
    } catch (e) {
      print('Erreur mise à jour préférences: $e');
      throw Exception('Impossible de mettre à jour les préférences');
    }
  }

  // Mettre à jour les statistiques
  Future<void> updateUserStats(String uid, {
    int? postCount,
    int? followerCount,
    int? followingCount,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (postCount != null) updates['postCount'] = postCount;
      if (followerCount != null) updates['followerCount'] = followerCount;
      if (followingCount != null) updates['followingCount'] = followingCount;

      await _firestore.collection('users').doc(uid).update(updates);
    } catch (e) {
      print('Erreur mise à jour stats: $e');
    }
  }

  // Créer un profil utilisateur depuis Firebase Auth
  Future<void> createUserFromAuth(User user) async {
    try {
      final userProfile = UserProfile(
        uid: user.uid,
        email: user.email!,
        displayName: user.displayName,
        photoURL: user.photoURL,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await saveUserProfile(userProfile);
      print('Profil créé depuis Auth: ${user.uid}');
    } catch (e) {
      print('Erreur création profil depuis Auth: $e');
      throw Exception('Impossible de créer le profil');
    }
  }

  // Récupérer les données utilisateur (compatibilité avec votre AuthService)
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      return doc.data();
    } catch (e) {
      return null;
    }
  }

  // Rechercher des utilisateurs
  Stream<List<UserProfile>> searchUsers(String query) {
    return _firestore
        .collection('users')
        .where('displayName', isGreaterThanOrEqualTo: query)
        .where('displayName', isLessThan: query + 'z')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return UserProfile.fromFirestore(doc.id, doc.data());
      }).toList();
    });
  }

  // Vérifier si un utilisateur existe
  Future<bool> userExists(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.exists;
  }

  // Récupérer plusieurs utilisateurs par leurs IDs
  Future<List<UserProfile>> getUsersByIds(List<String> uids) async {
    if (uids.isEmpty) return [];

    final snapshot = await _firestore
        .collection('users')
        .where(FieldPath.documentId, whereIn: uids)
        .get();

    return snapshot.docs.map((doc) {
      return UserProfile.fromFirestore(doc.id, doc.data());
    }).toList();
  }

  // AJOUT: Récupérer un utilisateur par son ID
  Future<UserProfile?> getUserById(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return UserProfile.fromFirestore(userId, doc.data()!);
      }
      return null;
    } catch (e) {
      print('Erreur récupération utilisateur: $e');
      return null;
    }
  }

  // AJOUT: Follow un utilisateur
  Future<void> followUser(String followerId, String followingId) async {
    try {
      await _firestore
          .collection('users')
          .doc(followerId)
          .collection('following')
          .doc(followingId)
          .set({
        'followedAt': FieldValue.serverTimestamp(),
      });

      await _firestore
          .collection('users')
          .doc(followingId)
          .collection('followers')
          .doc(followerId)
          .set({
        'followedAt': FieldValue.serverTimestamp(),
      });

      // Mettre à jour les compteurs
      await _updateFollowerCount(followingId, 1);
      await _updateFollowingCount(followerId, 1);
    } catch (e) {
      print('Erreur follow user: $e');
      throw Exception('Impossible de suivre cet utilisateur');
    }
  }

  // AJOUT: Unfollow un utilisateur
  Future<void> unfollowUser(String followerId, String followingId) async {
    try {
      await _firestore
          .collection('users')
          .doc(followerId)
          .collection('following')
          .doc(followingId)
          .delete();

      await _firestore
          .collection('users')
          .doc(followingId)
          .collection('followers')
          .doc(followerId)
          .delete();

      // Mettre à jour les compteurs
      await _updateFollowerCount(followingId, -1);
      await _updateFollowingCount(followerId, -1);
    } catch (e) {
      print('Erreur unfollow user: $e');
      throw Exception('Impossible de ne plus suivre cet utilisateur');
    }
  }

  // AJOUT: Vérifier si on suit un utilisateur
  Future<bool> isFollowing(String followerId, String followingId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(followerId)
          .collection('following')
          .doc(followingId)
          .get();
      return doc.exists;
    } catch (e) {
      print('Erreur vérification follow: $e');
      return false;
    }
  }

  // AJOUT: Récupérer le nombre de followers
  Future<int> getFollowerCount(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('followers')
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      print('Erreur comptage followers: $e');
      return 0;
    }
  }

  // AJOUT: Récupérer le nombre de following
  Future<int> getFollowingCount(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('following')
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      print('Erreur comptage following: $e');
      return 0;
    }
  }

  // AJOUT: Mettre à jour le compteur de followers
  Future<void> _updateFollowerCount(String userId, int change) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'followerCount': FieldValue.increment(change),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Erreur mise à jour follower count: $e');
    }
  }

  // AJOUT: Mettre à jour le compteur de following
  Future<void> _updateFollowingCount(String userId, int change) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'followingCount': FieldValue.increment(change),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Erreur mise à jour following count: $e');
    }
  }

  // AJOUT: Récupérer les followers d'un utilisateur
  Stream<List<UserProfile>> getUserFollowers(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('followers')
        .snapshots()
        .asyncMap((snapshot) async {
      final followerIds = snapshot.docs.map((doc) => doc.id).toList();
      final users = <UserProfile>[];

      for (final id in followerIds) {
        final user = await getUserById(id);
        if (user != null) {
          users.add(user);
        }
      }

      return users;
    });
  }

  // AJOUT: Récupérer les following d'un utilisateur
  Stream<List<UserProfile>> getUserFollowing(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('following')
        .snapshots()
        .asyncMap((snapshot) async {
      final followingIds = snapshot.docs.map((doc) => doc.id).toList();
      final users = <UserProfile>[];

      for (final id in followingIds) {
        final user = await getUserById(id);
        if (user != null) {
          users.add(user);
        }
      }

      return users;
    });
  }

  // AJOUT: Mettre à jour le profil utilisateur
  Future<void> updateUserProfile(UserProfile userProfile) async {
    try {
      await _firestore.collection('users').doc(userProfile.uid).update({
        'displayName': userProfile.displayName,
        'photoURL': userProfile.photoURL,
        'bio': userProfile.bio,
        'location': userProfile.location,
        'favoriteSpot': userProfile.favoriteSpot,
        'fishingGear': userProfile.fishingGear,
        'preferredFishTypes': userProfile.preferredFishTypes,
        'phoneNumber': userProfile.phoneNumber,
        'updatedAt': FieldValue.serverTimestamp(),
        'isDarkMode': userProfile.isDarkMode,
        'language': userProfile.language,
      });
    } catch (e) {
      print('Erreur mise à jour profil: $e');
      throw Exception('Impossible de mettre à jour le profil');
    }
  }

  // AJOUT: Créer un profil utilisateur
  Future<void> createUserProfile(UserProfile userProfile) async {
    try {
      await _firestore.collection('users').doc(userProfile.uid).set(
        userProfile.toFirestoreMap(),
      );
    } catch (e) {
      print('Erreur création profil: $e');
      throw Exception('Impossible de créer le profil');
    }
  }

  // AJOUT: Incrémenter le compteur de posts
  Future<void> incrementPostCount(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'postCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Erreur incrémentation post count: $e');
    }
  }

  // AJOUT: Récupérer les utilisateurs populaires
  Future<List<UserProfile>> getPopularUsers({int limit = 10}) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .orderBy('followerCount', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) {
        return UserProfile.fromFirestore(doc.id, doc.data());
      }).toList();
    } catch (e) {
      print('Erreur récupération utilisateurs populaires: $e');
      return [];
    }
  }

  // AJOUT: Vérifier si l'utilisateur a liké un post
  Future<bool> hasUserLikedPost(String userId, String postId) async {
    try {
      final doc = await _firestore
          .collection('posts')
          .doc(postId)
          .collection('likes')
          .doc(userId)
          .get();
      return doc.exists;
    } catch (e) {
      print('Erreur vérification like: $e');
      return false;
    }
  }

  // AJOUT: Récupérer les utilisateurs suggérés
  Future<List<UserProfile>> getSuggestedUsers(String currentUserId, {int limit = 5}) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where(FieldPath.documentId, isNotEqualTo: currentUserId)
          .orderBy('followerCount', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) {
        return UserProfile.fromFirestore(doc.id, doc.data());
      }).toList();
    } catch (e) {
      print('Erreur récupération utilisateurs suggérés: $e');
      return [];
    }
  }
}