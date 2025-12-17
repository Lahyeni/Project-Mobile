import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../services/post_service.dart';
import '../services/image_service.dart';
import '../models/user_model.dart';
import '../models/post_model.dart';
import '../widgets/post_card.dart';
import 'edit_profile_screen.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();
  final PostService _postService = PostService();
  final ImageService _imageService = ImageService();

  int _selectedTab = 0;
  UserProfile? _userProfile;
  StreamSubscription<UserProfile?>? _profileSubscription;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  @override
  void dispose() {
    _profileSubscription?.cancel();
    super.dispose();
  }

  void _loadUserProfile() {
    final user = _authService.getCurrentUser();
    if (user != null) {
      print('=== CHARGEMENT PROFIL UTILISATEUR: ${user.uid} ===');
      _profileSubscription = _userService.getUserProfile(user.uid).listen((profile) {
        if (mounted) {
          print('=== PROFIL MIS À JOUR ===');
          print('DisplayName: ${profile?.displayName}');
          print('PhotoURL: ${profile?.photoURL != null ? "EXISTE" : "NULL"}');
          if (profile?.photoURL != null) {
            print('Longueur PhotoURL: ${profile!.photoURL!.length}');
            print('Début PhotoURL: ${profile.photoURL!.substring(0, min(30, profile.photoURL!.length))}...');
          }

          setState(() {
            _userProfile = profile;
            _isRefreshing = false;
          });
        }
      }, onError: (error) {
        print('=== ERREUR STREAM PROFIL: $error ===');
        if (mounted) {
          setState(() {
            _isRefreshing = false;
          });
        }
      });
    }
  }

  bool _isBase64Image(String? photoUrl) {
    if (photoUrl == null) return false;
    return photoUrl.startsWith('data:image') || photoUrl.length > 500;
  }

  Future<void> _updateProfileImage() async {
    final user = _authService.getCurrentUser();
    if (user == null) return;

    try {
      setState(() => _isRefreshing = true);

      print('=== DÉBUT MISE À JOUR PHOTO ===');
      final String base64Image = await _imageService.pickAndConvertToBase64();
      print('✅ Image base64 obtenue - Longueur: ${base64Image.length}');

      await _userService.updateProfileImage(user.uid, base64Image);
      print('✅ Photo sauvegardée dans Firestore');

      // FORCER le rechargement après un délai
      await Future.delayed(const Duration(seconds: 1));
      _refreshProfile();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('profile_picture_updated'.tr()),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('❌ ERREUR MISE À JOUR PHOTO: $e');
      setState(() => _isRefreshing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('error_updating_picture'.tr()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _refreshProfile() {
    final user = _authService.getCurrentUser();
    if (user != null) {
      // Recharger les données manuellement
      _userService.getUserData(user.uid).then((data) {
        if (data != null && mounted) {
          setState(() {
            _userProfile = UserProfile.fromFirestore(user.uid, data);
            _isRefreshing = false;
          });
        }
      });
    }
  }

  Widget _buildProfileImage() {
    if (_isRefreshing) {
      return const CircleAvatar(
        radius: 50,
        backgroundColor: Colors.grey,
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    final hasCustomImage = _isBase64Image(_userProfile?.photoURL);

    print('=== CONSTRUCTION IMAGE PROFIL ===');
    print('Has custom image: $hasCustomImage');
    print('Profile photoURL: ${_userProfile?.photoURL != null ? "EXISTE" : "NULL"}');

    if (hasCustomImage) {
      try {
        print('🔄 Conversion base64 -> Uint8List');
        final Uint8List imageBytes = _imageService.base64ToImage(_userProfile!.photoURL!);
        print('✅ Conversion réussie');

        return CircleAvatar(
          radius: 50,
          backgroundImage: MemoryImage(imageBytes),
        );
      } catch (e) {
        print('❌ Erreur conversion base64: $e');
        return _buildDefaultAvatar();
      }
    } else {
      return _buildDefaultAvatar();
    }
  }

  Widget _buildDefaultAvatar() {
    return CircleAvatar(
      radius: 50,
      backgroundColor: Colors.blue[100],
      child: const Icon(
        Icons.person,
        size: 50,
        color: Colors.blue,
      ),
    );
  }

  // AJOUT: Méthode pour l'état non connecté
  Widget _buildNotLoggedIn() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.person_off, size: 80, color: Colors.grey),
          const SizedBox(height: 20),
          Text(
            "not_logged_in".tr(),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(
            "login_to_see_profile".tr(),
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              // Naviguer vers l'écran de login
              Navigator.pushNamed(context, '/login');
            },
            child: Text("login".tr()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _authService.getCurrentUser();

    return Scaffold(
      appBar: AppBar(
        title: Text("profile".tr()),
        actions: [
          if (currentUser != null) ...[
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _refreshProfile,
              tooltip: 'refresh'.tr(),
            ),
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
            ),
          ],
        ],
      ),
      body: currentUser == null
          ? _buildNotLoggedIn()
          : _buildProfile(currentUser),
    );
  }

  Widget _buildProfile(User user) {
    final displayName = _userProfile?.displayName ?? user.displayName ?? 'Pêcheur Anonyme';
    final bio = _userProfile?.bio ?? "bio_placeholder".tr();
    final location = _userProfile?.location ?? "unknown_location".tr();
    final favoriteSpot = _userProfile?.favoriteSpot ?? "no_favorite_spot".tr();
    final fishingGear = _userProfile?.fishingGear ?? [];
    final stats = _userProfile ?? UserProfile(
      uid: user.uid,
      email: user.email!,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    return SingleChildScrollView(
      child: Column(
        children: [
          // En-tête du profil
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.blue[400]!, Colors.blue[600]!],
              ),
            ),
            child: Column(
              children: [
                // Photo de profil avec édition
                GestureDetector(
                  onTap: _updateProfileImage,
                  child: Stack(
                    children: [
                      _buildProfileImage(),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.camera_alt, size: 16, color: Colors.blue[700]),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Nom et email
                Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user.email ?? '',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),

                const SizedBox(height: 16),

                // Bouton éditer profil
                ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditProfileScreen(userProfile: _userProfile),
                    ),
                  ),
                  icon: const Icon(Icons.edit, size: 16),
                  label: Text("edit_profile".tr()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.blue[700],
                  ),
                ),

                const SizedBox(height: 16),

                // Statistiques
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatColumn(stats.postCount.toString(), "posts".tr()),
                    _buildStatColumn(stats.followerCount.toString(), "followers".tr()),
                    _buildStatColumn(stats.followingCount.toString(), "following".tr()),
                  ],
                ),
              ],
            ),
          ),

          // Bio et informations
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Bio
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info, color: Colors.blue[700]),
                            const SizedBox(width: 8),
                            Text(
                              "bio".tr(),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          bio,
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Localisation
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.location_on, color: Colors.green[700]),
                            const SizedBox(width: 8),
                            Text(
                              "location".tr(),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          location,
                          style: TextStyle(
                            color: Colors.green[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Spot favori
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.favorite, color: Colors.red[700]),
                            const SizedBox(width: 8),
                            Text(
                              "favorite_spot".tr(),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          favoriteSpot,
                          style: TextStyle(
                            color: Colors.red[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Matériel de pêche
                if (fishingGear.isNotEmpty) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.phishing, color: Colors.orange[700]),
                              const SizedBox(width: 8),
                              Text(
                                "fishing_gear".tr(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: fishingGear.map((gear) => _buildGearChip(gear)).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ],
            ),
          ),

          // TabBar pour Posts/Favoris
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => setState(() => _selectedTab = 0),
                          style: TextButton.styleFrom(
                            backgroundColor: _selectedTab == 0 ? Colors.blue[50] : Colors.transparent,
                          ),
                          child: Text(
                            "my_posts".tr(),
                            style: TextStyle(
                              color: _selectedTab == 0 ? Colors.blue[700] : Colors.grey[600],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: TextButton(
                          onPressed: () => setState(() => _selectedTab = 1),
                          style: TextButton.styleFrom(
                            backgroundColor: _selectedTab == 1 ? Colors.blue[50] : Colors.transparent,
                          ),
                          child: Text(
                            "favorites".tr(),
                            style: TextStyle(
                              color: _selectedTab == 1 ? Colors.blue[700] : Colors.grey[600],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Liste des posts ou favoris
          _selectedTab == 0 ? _buildMyPosts() : _buildFavorites(),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String count, String label) {
    return Column(
      children: [
        Text(
          count,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildGearChip(String text) {
    return Chip(
      label: Text(text),
      backgroundColor: Colors.orange[50],
      labelStyle: TextStyle(color: Colors.orange[700]),
    );
  }

  Widget _buildMyPosts() {
    return StreamBuilder<List<Post>>(
      stream: _postService.getPosts(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: Text(
                "error_loading_posts".tr(),
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
          );
        }

        final posts = snapshot.data ?? [];
        final user = _authService.getCurrentUser();
        final userPosts = posts.where((post) => post.userId == user?.uid).toList();

        return _buildPostsList(userPosts);
      },
    );
  }

  Widget _buildFavorites() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Icon(Icons.favorite_border, size: 60, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            "no_favorites".tr(),
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "add_posts_to_favorites".tr(),
            style: TextStyle(color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPostsList(List<Post> posts) {
    if (posts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(Icons.phishing, size: 60, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              "no_posts_shared".tr(),
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "share_your_first_catch".tr(),
              style: TextStyle(color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, '/create_post');
              },
              icon: const Icon(Icons.add),
              label: Text("create_first_post".tr()),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: posts.length,
      itemBuilder: (context, index) {
        return PostCard(
          post: posts[index],
          onLike: () => _handleLikePost(posts[index]),
          onComment: (comment) => _handleAddComment(posts[index], comment),
          onShare: () => _handleSharePost(posts[index]),
          onDelete: () => _handleDeletePost(posts[index]), onUserTap: () {  },
        );
      },
    );
  }

  void _handleLikePost(Post post) {
    final user = _authService.getCurrentUser();
    if (user == null) return;
    _postService.likePost(post.id, user.uid);
  }

  void _handleAddComment(Post post, String comment) {
    final user = _authService.getCurrentUser();
    if (user == null) return;

    _postService.addComment(
      post.id,
      Comment(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: user.uid,
        userName: user.displayName ?? 'Anonyme',
        userPhoto: user.photoURL ?? '',
        content: comment,
        timestamp: DateTime.now(),
      ),
    );
  }

  void _handleSharePost(Post post) {
    // Implémentez le partage
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('share_coming_soon'.tr())),
    );
  }

  void _handleDeletePost(Post post) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("delete_post".tr()),
        content: Text("delete_post_confirm".tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("cancel".tr()),
          ),
          ElevatedButton(
            onPressed: () {
              _postService.deletePost(post.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('post_deleted'.tr())),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text("delete".tr()),
          ),
        ],
      ),
    );
  }
}