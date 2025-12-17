import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/post_model.dart';

class PostService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<Post>> getPosts() {
    return _firestore
        .collection('posts')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .handleError((error) {
      print('Erreur Firestore: $error');
      throw error;
    })
        .map((snapshot) {
      try {
        final posts = snapshot.docs.map((doc) {
          return _convertDocumentToPost(doc);
        }).toList();

        print('=== ${posts.length} posts chargés avec succès ===');
        return posts;
      } catch (e) {
        print('Erreur conversion posts: $e');
        throw Exception('Erreur lors de la conversion des posts: $e');
      }
    });
  }
// Dans votre PostService, ajoutez cette méthode :

  Future<void> createPostWithImages(Post post) async {
    try {
      // Vérifier la taille des images avant de sauvegarder
      for (final image in post.images) {
        if (image.sizeInKB > 1000) { // 1MB limite
          throw Exception('L\'image ${image.caption ?? ''} est trop volumineuse (${image.sizeInKB}KB). Maximum: 1000KB');
        }
      }

      // Utiliser la méthode createPost existante
      await createPost(post);

      print('Post créé avec ${post.images.length} images');
    } catch (e) {
      print('Erreur création post avec images: $e');
      throw Exception('Impossible de créer le post avec images: $e');
    }
  }
  Post _convertDocumentToPost(DocumentSnapshot doc) {
    try {
      final data = doc.data() as Map<String, dynamic>? ?? {};

      // Conversion sécurisée du timestamp
      DateTime timestamp;
      if (data['timestamp'] is Timestamp) {
        timestamp = (data['timestamp'] as Timestamp).toDate();
      } else if (data['timestamp'] is String) {
        timestamp = DateTime.parse(data['timestamp']);
      } else {
        timestamp = DateTime.now();
        print('Timestamp manquant pour le post ${doc.id}, utilisation date actuelle');
      }

      // CORRECTION : Conversion des likes (int) et likedBy (List<String>)
      int likes = 0;
      if (data['likes'] is int) {
        likes = data['likes'] as int;
      } else if (data['likes'] is double) {
        likes = (data['likes'] as double).toInt();
      } else {
        // Si likes n'est pas un nombre, utiliser la longueur de likedBy
        likes = _getLikedByList(data).length;
      }

      // CORRECTION : Conversion de likedBy
      List<String> likedBy = _getLikedByList(data);

      // CORRECTION : Conversion des images
      List<PostImage> images = [];
      if (data['images'] is List) {
        images = (data['images'] as List).whereType<Map<String, dynamic>>().map((imageData) {
          try {
            return PostImage.fromMap(imageData);
          } catch (e) {
            print('Erreur conversion image: $e - Data: $imageData');
            return PostImage(
              base64Data: '',
              uploadedAt: DateTime.now(),
            );
          }
        }).toList();
      }

      // CORRECTION : Conversion des commentaires
      List<Comment> comments = [];
      if (data['comments'] is List) {
        comments = (data['comments'] as List).whereType<Map<String, dynamic>>().map((commentData) {
          try {
            return Comment.fromMap(commentData);
          } catch (e) {
            print('Erreur conversion commentaire: $e - Data: $commentData');
            return Comment(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              userId: 'error',
              userName: 'Utilisateur',
              userPhoto: '',
              content: 'Commentaire corrompu',
              timestamp: DateTime.now(),
            );
          }
        }).toList();
      }

      return Post(
        id: doc.id,
        userId: data['userId']?.toString() ?? 'unknown',
        userName: data['userName']?.toString() ?? 'Anonyme',
        userPhoto: data['userPhoto']?.toString() ?? '',
        content: data['content']?.toString() ?? 'Contenu non disponible',
        images: images,
        fishType: data['fishType']?.toString(),
        fishWeight: _parseFishWeight(data['fishWeight']),
        location: data['location']?.toString(),
        timestamp: timestamp,
        likes: likes,
        likedBy: likedBy,
        comments: comments,
        imageUrl: '', // Champ requis mais optionnel dans votre modèle
      );
    } catch (e) {
      print('Erreur critique conversion post ${doc.id}: $e');
      return Post(
        id: doc.id,
        userId: 'error',
        userName: 'Erreur',
        userPhoto: '',
        content: 'Ce post ne peut pas être affiché',
        images: [],
        timestamp: DateTime.now(),
        likes: 0,
        likedBy: [],
        comments: [],
        imageUrl: '', // Champ requis
      );
    }
  }

  // Méthode utilitaire pour parser likedBy
  List<String> _getLikedByList(Map<String, dynamic> data) {
    if (data['likedBy'] is List) {
      return (data['likedBy'] as List).whereType<String>().toList();
    }
    return [];
  }

  // Méthode utilitaire pour parser fishWeight
  double? _parseFishWeight(dynamic weight) {
    if (weight is double) return weight;
    if (weight is int) return weight.toDouble();
    if (weight is String) return double.tryParse(weight);
    return null;
  }

  // CORRECTION : Méthodes like/unlike mises à jour
  Future<void> likePost(String postId, String userId) async {
    try {
      final postRef = _firestore.collection('posts').doc(postId);

      await _firestore.runTransaction((transaction) async {
        final postDoc = await transaction.get(postRef);
        if (!postDoc.exists) {
          throw Exception('Post non trouvé');
        }

        final data = postDoc.data() as Map<String, dynamic>;
        final List<String> currentLikedBy = List<String>.from(data['likedBy'] ?? []);
        final int currentLikes = (data['likes'] as int?) ?? 0;

        if (currentLikedBy.contains(userId)) {
          // Déjà liké, rien à faire
          return;
        }

        // Ajouter l'utilisateur à likedBy et incrémenter likes
        currentLikedBy.add(userId);

        transaction.update(postRef, {
          'likedBy': currentLikedBy,
          'likes': currentLikes + 1,
        });
      });
    } catch (e) {
      print('Erreur like post: $e');
      throw Exception('Impossible d\'aimer le post');
    }
  }

  Future<void> unlikePost(String postId, String userId) async {
    try {
      final postRef = _firestore.collection('posts').doc(postId);

      await _firestore.runTransaction((transaction) async {
        final postDoc = await transaction.get(postRef);
        if (!postDoc.exists) {
          throw Exception('Post non trouvé');
        }

        final data = postDoc.data() as Map<String, dynamic>;
        final List<String> currentLikedBy = List<String>.from(data['likedBy'] ?? []);
        final int currentLikes = (data['likes'] as int?) ?? 0;

        if (!currentLikedBy.contains(userId)) {
          // Pas liké, rien à faire
          return;
        }

        // Retirer l'utilisateur de likedBy et décrémenter likes
        currentLikedBy.remove(userId);

        transaction.update(postRef, {
          'likedBy': currentLikedBy,
          'likes': currentLikes - 1,
        });
      });
    } catch (e) {
      print('Erreur unlike post: $e');
      throw Exception('Impossible de retirer le like');
    }
  }

  // Vérifier si un utilisateur a liké un post
  Future<bool> hasUserLikedPost(String postId, String userId) async {
    try {
      final postDoc = await _firestore.collection('posts').doc(postId).get();
      if (!postDoc.exists) return false;

      final data = postDoc.data() as Map<String, dynamic>;
      final List<String> likedBy = List<String>.from(data['likedBy'] ?? []);
      return likedBy.contains(userId);
    } catch (e) {
      print('Erreur vérification like: $e');
      return false;
    }
  }

  Future<void> addComment(String postId, Comment comment) async {
    try {
      await _firestore.collection('posts').doc(postId).update({
        'comments': FieldValue.arrayUnion([comment.toMap()])
      });
    } catch (e) {
      print('Erreur ajout commentaire: $e');
      throw Exception('Impossible d\'ajouter le commentaire');
    }
  }

  Future<void> createPost(Post post) async {
    try {
      await _firestore.collection('posts').add(post.toMap());
    } catch (e) {
      print('Erreur création post: $e');
      throw Exception('Impossible de créer le post');
    }
  }

  Future<void> deletePost(String postId) async {
    try {
      await _firestore.collection('posts').doc(postId).delete();
    } catch (e) {
      print('Erreur suppression post: $e');
      throw Exception('Impossible de supprimer le post');
    }
  }

  Future<List<Post>> getPostsOnce() async {
    try {
      final snapshot = await _firestore
          .collection('posts')
          .orderBy('timestamp', descending: true)
          .get();

      final posts = snapshot.docs.map((doc) {
        return _convertDocumentToPost(doc);
      }).toList();

      print('=== ${posts.length} posts chargés (one-time) ===');
      return posts;
    } catch (e) {
      print('Erreur chargement posts one-time: $e');
      throw Exception('Erreur lors du chargement des posts: $e');
    }
  }
  Future<List<Post>> getUserPosts(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('posts')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .get();

      final posts = snapshot.docs.map((doc) {
        return _convertDocumentToPost(doc);
      }).toList();

      print('=== ${posts.length} posts de l\'utilisateur $userId chargés ===');
      return posts;
    } catch (e) {
      print('Erreur chargement posts utilisateur: $e');
      throw Exception('Erreur lors du chargement des posts de l\'utilisateur: $e');
    }
  }
}