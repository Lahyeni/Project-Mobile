import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<User?> login(String email, String password) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      print("yoooods ${result.user}");
      return result.user;
    } catch (e) {
      throw e.toString();
    }
  }

  Future<User?> signup(String email, String password) async {
    try {
      // Vérifier si l'email existe déjà
      final existingUsers = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .get();

      if (existingUsers.docs.isNotEmpty) {
        throw 'Email déjà utilisé';
      }

      // Créer l'utilisateur dans Firebase Auth
      final result = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);

      // Ajouter l'utilisateur dans Firestore
      if (result.user != null) {
        await _firestore.collection('users').doc(result.user!.uid).set({
          'uid': result.user!.uid,
          'email': email,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      return result.user;
    } catch (e) {
      throw e.toString();
    }
  }

  // Récupérer les données utilisateur depuis Firestore
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      return doc.data();
    } catch (e) {
      return null;
    }
  }
  User? getCurrentUser() {
    return _auth.currentUser;
  }
  Map<String, String> getUserInfoForPost() {
    final user = _auth.currentUser;
    return {
      'uid': user?.uid ?? '',
      'name': user?.displayName ?? 'Pêcheur Anonyme',
      'photo': user?.photoURL ?? '',
    };
  }
  Future<void> logout() async => _auth.signOut();
}
///import 'package:firebase_auth/firebase_auth.dart';
//
// class AuthService {
//   final FirebaseAuth _auth = FirebaseAuth.instance;
//
//   // Connexion email/mot de passe
//   Future<User?> login(String email, String password) async {
//     try {
//       final userCredential = await _auth.signInWithEmailAndPassword(
//         email: email,
//         password: password,
//       );
//       return userCredential.user;
//     } catch (e) {
//       throw Exception('Erreur de connexion: $e');
//     }
//   }
//
//   // Inscription
//   Future<User?> signup(String email, String password) async {
//     try {
//       final userCredential = await _auth.createUserWithEmailAndPassword(
//         email: email,
//         password: password,
//       );
//       return userCredential.user;
//     } catch (e) {
//       throw Exception('Erreur d\'inscription: $e');
//     }
//   }
//
//   // Déconnexion
//   Future<void> logout() async {
//     await _auth.signOut();
//   }
//
//   // Utilisateur actuel
//   User? getCurrentUser() {
//     return _auth.currentUser;
//   }
//
//   // Vérifier si connecté
//   bool isLoggedIn() {
//     return _auth.currentUser != null;
//   }
//
//   // Stream pour les changements d'authentification
//   Stream<User?> get authStateChanges {
//     return _auth.authStateChanges();
//   }
// }
//code a tester///