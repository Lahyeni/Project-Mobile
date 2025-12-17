import 'dart:async';

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/post_service.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../models/post_model.dart';
import '../models/user_model.dart';
import '../widgets/post_card.dart';
import 'create_post_screen.dart';
import 'UserProfileScreen.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final PostService _postService = PostService();
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();

  List<Post> _posts = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  StreamSubscription<List<Post>>? _postsSubscription;

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  @override
  void dispose() {
    _postsSubscription?.cancel();
    super.dispose();
  }

  void _navigateToUserProfile(String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(userId: userId),
      ),
    );
  }

  void _navigateToMyProfile() {
    final currentUser = _authService.getCurrentUser();
    if (currentUser != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => UserProfileScreen(userId: currentUser.uid),
        ),
      );
    }
  }

  Future<void> _loadPosts() async {
    print('=== DÉBUT CHARGEMENT POSTS ===');
    if (mounted) {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _posts = [];
      });
    }

    try {
      _postsSubscription = _postService.getPosts().listen(
            (posts) {
          print('=== STREAM: ${posts.length} posts reçus ===');
          if (mounted) {
            setState(() {
              _posts = posts;
              _isLoading = false;
              _hasError = false;
            });
          }
        },
        onError: (error) {
          print('=== ERREUR STREAM: $error ===');
          if (mounted) {
            setState(() {
              _hasError = true;
              _errorMessage = error.toString();
              _isLoading = false;
            });
          }
        },
        cancelOnError: false,
      );
    } catch (e) {
      print('=== ERREUR INIT STREAM: $e ===');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshPosts() async {
    print('=== RAFRAÎCHISSEMENT MANUEL ===');
    _postsSubscription?.cancel();
    await _loadPosts();
  }

  Future<void> _loadPostsOnce() async {
    print('=== CHARGEMENT ONE-TIME ===');
    if (mounted) {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });
    }

    try {
      final posts = await _postService.getPostsOnce();
      if (mounted) {
        setState(() {
          _posts = posts;
          _isLoading = false;
          _hasError = false;
        });
      }
    } catch (e) {
      print('=== ERREUR ONE-TIME: $e ===');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _showErrorSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showSuccessSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _handleLikePost(Post post) async {
    try {
      final currentUser = _authService.getCurrentUser();
      if (currentUser == null) {
        _showErrorSnackbar('connect_to_like'.tr());
        return;
      }

      if (post.likedBy.contains(currentUser.uid)) {
        await _postService.unlikePost(post.id, currentUser.uid);
      } else {
        await _postService.likePost(post.id, currentUser.uid);
      }
    } catch (e) {
      _showErrorSnackbar('like_error'.tr());
    }
  }

// In your FeedScreen or wherever you handle comments
  Future<void> _handleAddComment(Post post, String comment) async {
    try {
      final currentUser = _authService.getCurrentUser();
      if (currentUser == null) {
        _showErrorSnackbar('connect_to_comment'.tr());
        return;
      }

      if (comment.trim().isEmpty) {
        _showErrorSnackbar('empty_comment'.tr());
        return;
      }

      // Get user profile to get the latest user photo
      final userProfile = await _userService.getUserById(currentUser.uid);

      final newComment = Comment(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: currentUser.uid,
        userName: userProfile?.displayName ?? currentUser.displayName ?? 'Anonyme',
        userPhoto: userProfile?.photoURL ?? currentUser.photoURL ?? '',
        content: comment.trim(),
        timestamp: DateTime.now(),
      );

      await _postService.addComment(post.id, newComment);
      _showSuccessSnackbar('comment_added'.tr());
    } catch (e) {
      _showErrorSnackbar('comment_error'.tr());
    }
  }
  void _handleSharePost(Post post) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("share_post".tr()),
        content: Text("share_post_message".tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("cancel".tr()),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showSuccessSnackbar('post_shared'.tr());
            },
            child: Text("share".tr()),
          ),
        ],
      ),
    );
  }

  void _handleDeletePost(Post post) {
    final currentUser = _authService.getCurrentUser();
    if (currentUser == null || currentUser.uid != post.userId) {
      _showErrorSnackbar('not_authorized'.tr());
      return;
    }

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
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _postService.deletePost(post.id);
                _showSuccessSnackbar('post_deleted'.tr());
              } catch (e) {
                _showErrorSnackbar('delete_error'.tr());
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text("delete".tr()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "fisher_community".tr(),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: _navigateToMyProfile,
            tooltip: 'my_profile'.tr(),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreatePostScreen()),
              ).then((_) => _refreshPosts());
            },
            tooltip: 'create_post'.tr(),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'refresh') {
                _refreshPosts();
              } else if (value == 'load_once') {
                _loadPostsOnce();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'refresh',
                child: Row(
                  children: [
                    const Icon(Icons.refresh),
                    const SizedBox(width: 8),
                    Text('refresh'.tr()),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'load_once',
                child: Row(
                  children: [
                    const Icon(Icons.download),
                    const SizedBox(width: 8),
                    Text('load_once'.tr()),
                  ],
                ),
              ),
            ],
          ),
        ],
        // SUPPRIMÉ: backgroundColor: Colors.transparent,
        // OU remplacez par une couleur solide :
        // backgroundColor: Theme.of(context).primaryColor,
        // backgroundColor: Colors.white,
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreatePostScreen()),
          ).then((_) => _refreshPosts());
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _posts.isEmpty) {
      return _buildLoadingState();
    }

    if (_hasError && _posts.isEmpty) {
      return _buildErrorState();
    }

    if (_posts.isEmpty && !_isLoading) {
      return _buildEmptyState();
    }

    return _buildPostsList();
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Chargement des posts...'),
        ],
      ),
    );
  }

  Widget _buildPostsList() {
    return RefreshIndicator(
      onRefresh: _refreshPosts,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(8),
        itemCount: _posts.length,
        itemBuilder: (context, index) {
          final post = _posts[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: PostCard(
              post: post,
              onLike: () => _handleLikePost(post),
              onComment: (comment) => _handleAddComment(post, comment),
              onShare: () => _handleSharePost(post),
              onDelete: () => _handleDeletePost(post),
              onUserTap: () => _navigateToUserProfile(post.userId),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.phishing, size: 100, color: Colors.grey[400]),
          const SizedBox(height: 20),
          Text(
            "no_posts_yet".tr(),
            style: TextStyle(
              fontSize: 20,
              color: Colors.grey[600],
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "be_first_to_share".tr(),
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreatePostScreen()),
              ).then((_) => _refreshPosts());
            },
            icon: const Icon(Icons.add),
            label: Text("create_first_post".tr()),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 80, color: Colors.red),
          const SizedBox(height: 20),
          Text(
            "error_loading_posts".tr(),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _errorMessage,
            style: TextStyle(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: _refreshPosts,
                child: Text("retry".tr()),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: _loadPostsOnce,
                child: Text("try_alternative".tr()),
              ),
            ],
          ),
        ],
      ),
    );
  }
}