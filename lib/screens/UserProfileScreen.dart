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

class UserProfileScreen extends StatefulWidget {
  final String userId;
  final String? userName;
  final String? userPhoto;

  const UserProfileScreen({
    super.key,
    required this.userId,
    this.userName,
    this.userPhoto,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();
  final PostService _postService = PostService();
  final ImageService _imageService = ImageService();

  UserProfile? _userProfile;
  List<Post> _userPosts = [];
  bool _isLoading = true;
  bool _isFollowing = false;
  int _followerCount = 0;
  int _followingCount = 0;
  int _selectedTab = 0;
  StreamSubscription<List<Post>>? _postsSubscription;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _postsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      await Future.wait([
        _loadUserProfile(),
        _loadUserPosts(),
        _checkIfFollowing(),
      ]);
    } catch (e) {
      print('Erreur chargement données utilisateur: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadUserProfile() async {
    try {
      final user = await _userService.getUserById(widget.userId);
      if (mounted) {
        setState(() {
          _userProfile = user;
        });
      }
    } catch (e) {
      print('Erreur chargement profil: $e');
    }
  }

  Future<void> _loadUserPosts() async {
    try {
      // Utiliser la méthode stream pour les mises à jour en temps réel
      _postsSubscription = _postService.getPosts().listen((posts) {
        if (mounted) {
          final userPosts = posts.where((post) => post.userId == widget.userId).toList();
          setState(() {
            _userPosts = userPosts;
          });
        }
      }, onError: (error) {
        print('Erreur stream posts: $error');
      });

      // Chargement initial
      final posts = await _postService.getPostsOnce();
      final userPosts = posts.where((post) => post.userId == widget.userId).toList();
      if (mounted) {
        setState(() {
          _userPosts = userPosts;
        });
      }
      print('✅ ${userPosts.length} posts chargés pour l\'utilisateur ${widget.userId}');
    } catch (e) {
      print('❌ Erreur chargement posts utilisateur: $e');
      if (mounted) {
        setState(() {
          _userPosts = [];
        });
      }
    }
  }

  Future<void> _checkIfFollowing() async {
    final currentUser = _authService.getCurrentUser();
    if (currentUser == null) return;

    try {
      final isFollowing = await _userService.isFollowing(currentUser.uid, widget.userId);
      final followerCount = await _userService.getFollowerCount(widget.userId);
      final followingCount = await _userService.getFollowingCount(widget.userId);

      if (mounted) {
        setState(() {
          _isFollowing = isFollowing;
          _followerCount = followerCount;
          _followingCount = followingCount;
        });
      }
    } catch (e) {
      print('Erreur vérification follow: $e');
    }
  }

  Future<void> _toggleFollow() async {
    final currentUser = _authService.getCurrentUser();
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('connect_to_follow'.tr())),
      );
      return;
    }

    try {
      if (_isFollowing) {
        await _userService.unfollowUser(currentUser.uid, widget.userId);
        setState(() {
          _isFollowing = false;
          _followerCount = _followerCount > 0 ? _followerCount - 1 : 0;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('unfollowed'.tr())),
        );
      } else {
        await _userService.followUser(currentUser.uid, widget.userId);
        setState(() {
          _isFollowing = true;
          _followerCount++;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('followed'.tr())),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('follow_error'.tr())),
      );
    }
  }

  bool _isCurrentUser() {
    final currentUser = _authService.getCurrentUser();
    return currentUser?.uid == widget.userId;
  }

  // Méthode pour afficher l'avatar avec support base64
  Widget _buildUserAvatar(String? photoUrl, String displayName) {
    if (photoUrl == null || photoUrl.isEmpty) {
      return _buildDefaultAvatar(displayName);
    }

    // Vérifier si c'est une image base64
    if (_isBase64Image(photoUrl)) {
      try {
        final Uint8List imageBytes = _imageService.base64ToImage(photoUrl);
        return CircleAvatar(
          radius: 50,
          backgroundImage: MemoryImage(imageBytes),
        );
      } catch (e) {
        print('❌ Erreur décodage base64: $e');
        return _buildDefaultAvatar(displayName);
      }
    }
    // Vérifier si c'est une URL
    else if (photoUrl.startsWith('http')) {
      return CircleAvatar(
        radius: 50,
        backgroundImage: NetworkImage(photoUrl),
        onBackgroundImageError: (exception, stackTrace) {
          print('❌ Erreur chargement image réseau: $exception');
        },
        child: _buildDefaultAvatar(displayName),
      );
    } else {
      return _buildDefaultAvatar(displayName);
    }
  }

  // Vérifier si c'est base64
  bool _isBase64Image(String data) {
    return data.startsWith('data:image/') ||
        data.startsWith('/9j/') ||
        data.startsWith('iVBOR') ||
        data.length > 100;
  }

  // Avatar par défaut
  Widget _buildDefaultAvatar(String name) {
    return CircleAvatar(
      radius: 50,
      backgroundColor: _getAvatarColor(name),
      child: Text(
        _getInitials(name),
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  // Obtenir les initiales
  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  // Couleur d'avatar
  Color _getAvatarColor(String name) {
    final colors = [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.indigo,
      Colors.brown,
    ];
    final index = name.isEmpty ? 0 : name.codeUnits.fold(0, (a, b) => a + b) % colors.length;
    return colors[index];
  }

  // Gestion des likes dans les posts
  void _handleLikePost(Post post) async {
    try {
      final currentUser = _authService.getCurrentUser();
      if (currentUser == null) return;

      if (post.likedBy.contains(currentUser.uid)) {
        await _postService.unlikePost(post.id, currentUser.uid);
      } else {
        await _postService.likePost(post.id, currentUser.uid);
      }
    } catch (e) {
      print('Erreur like post: $e');
    }
  }

  // Gestion des commentaires
  void _handleAddComment(Post post, String comment) async {
    try {
      final currentUser = _authService.getCurrentUser();
      if (currentUser == null) return;

      await _postService.addComment(
        post.id,
        Comment(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          userId: currentUser.uid,
          userName: currentUser.displayName ?? 'Anonyme',
          userPhoto: currentUser.photoURL ?? '',
          content: comment.trim(),
          timestamp: DateTime.now(),
        ),
      );
    } catch (e) {
      print('Erreur ajout commentaire: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('profile'.tr()),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _loadUserData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // En-tête du profil
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Avatar utilisateur
                      _buildUserAvatar(_userProfile?.photoURL ?? widget.userPhoto,
                          _userProfile?.displayName ?? widget.userName ?? 'Pêcheur'),
                      const SizedBox(height: 16),

                      // Nom d'affichage
                      Text(
                        _userProfile?.displayName ?? widget.userName ?? 'Pêcheur',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Bio
                      if (_userProfile?.bio != null && _userProfile!.bio!.isNotEmpty)
                        Text(
                          _userProfile!.bio!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      const SizedBox(height: 16),

                      // Statistiques
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildStatColumn(_userPosts.length, 'posts'.tr()),
                          _buildStatColumn(_followerCount, 'followers'.tr()),
                          _buildStatColumn(_followingCount, 'following'.tr()),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Bouton Follow/Unfollow
                      if (!_isCurrentUser())
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _toggleFollow,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isFollowing ? Colors.grey : Theme.of(context).primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Text(
                              _isFollowing ? 'unfollow'.tr() : 'follow'.tr(),
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Informations supplémentaires
              if (_userProfile != null) _buildUserInfo(),

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
                                "posts".tr(),
                                style: TextStyle(
                                  color: _selectedTab == 0 ? Colors.blue[700] : Colors.grey[600],
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

              // Contenu des tabs
              _selectedTab == 0 ? _buildPostsTab() : _buildAboutTab(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatColumn(int count, String label) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildUserInfo() {
    return Column(
      children: [
        if (_userProfile?.location != null && _userProfile!.location!.isNotEmpty) ...[
          _buildInfoCard(
            icon: Icons.location_on,
            title: "location".tr(),
            content: _userProfile!.location!,
            color: Colors.green,
          ),
          const SizedBox(height: 12),
        ],

        if (_userProfile?.favoriteSpot != null && _userProfile!.favoriteSpot!.isNotEmpty) ...[
          _buildInfoCard(
            icon: Icons.favorite,
            title: "favorite_spot".tr(),
            content: _userProfile!.favoriteSpot!,
            color: Colors.red,
          ),
          const SizedBox(height: 12),
        ],

        if (_userProfile?.fishingGear.isNotEmpty == true) ...[
          _buildGearCard(),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String content,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    content,
                    style: TextStyle(
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGearCard() {
    return Card(
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
              children: _userProfile!.fishingGear.map((gear) => Chip(
                label: Text(gear),
                backgroundColor: Colors.orange[50],
                labelStyle: TextStyle(color: Colors.orange[700]),
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostsTab() {
    if (_userPosts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(Icons.phishing, size: 60, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _isCurrentUser() ? 'no_posts_shared'.tr() : 'no_posts_user'.tr(),
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isCurrentUser() ? 'share_your_first_catch'.tr() : 'user_has_no_posts'.tr(),
              style: TextStyle(color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _userPosts.length,
      itemBuilder: (context, index) {
        final post = _userPosts[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: PostCard(
            post: post,
            onLike: () => _handleLikePost(post),
            onComment: (comment) => _handleAddComment(post, comment),
            onShare: () {
              // Implémenter le partage
            },
            onDelete: () {
              // Seulement si c'est le propriétaire
              if (_isCurrentUser()) {
                _handleDeletePost(post);
              }
            },
            onUserTap: () {
              // Ne rien faire car on est déjà sur le profil
            },
          ),
        );
      },
    );
  }

  Widget _buildAboutTab() {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Les informations sont déjà affichées dans _buildUserInfo()
          // Cette tab peut être utilisée pour d'autres informations
        ],
      ),
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