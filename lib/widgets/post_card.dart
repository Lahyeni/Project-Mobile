import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../models/post_model.dart';
import '../services/auth_service.dart';
import '../services/image_service.dart';

class PostCard extends StatefulWidget {
  final Post post;
  final VoidCallback onLike;
  final Function(String) onComment;
  final VoidCallback onShare;
  final VoidCallback onDelete;
  final VoidCallback onUserTap;
  final VoidCallback? onCommenterTap; // NEW: Optional callback for commenter tap

  const PostCard({
    super.key,
    required this.post,
    required this.onLike,
    required this.onComment,
    required this.onShare,
    required this.onDelete,
    required this.onUserTap,
    this.onCommenterTap, // NEW
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  final AuthService _authService = AuthService();
  final ImageService _imageService = ImageService();
  final TextEditingController _commentController = TextEditingController();
  bool _showComments = false;
  bool _isLiked = false;

  @override
  void initState() {
    super.initState();
    _checkIfLiked();
  }

  void _checkIfLiked() {
    final currentUserId = _authService.getCurrentUser()?.uid;
    if (currentUserId != null) {
      setState(() {
        _isLiked = widget.post.likedBy.contains(currentUserId);
      });
    }
  }

  // Méthode pour l'avatar du posteur
  Widget _buildUserAvatar(String userPhoto, String userName) {
    // Vérifier si c'est une image base64
    if (userPhoto.isNotEmpty && _isBase64Image(userPhoto)) {
      try {
        final Uint8List imageBytes = _imageService.base64ToImage(userPhoto);
        return CircleAvatar(
          radius: 20,
          backgroundImage: MemoryImage(imageBytes),
        );
      } catch (e) {
        print('❌ Erreur décodage base64 photo utilisateur: $e');
        return _buildDefaultAvatar(userName);
      }
    }
    // Vérifier si c'est une URL valide
    else if (userPhoto.isNotEmpty && userPhoto.startsWith('http')) {
      return CircleAvatar(
        radius: 20,
        backgroundImage: NetworkImage(userPhoto),
        onBackgroundImageError: (exception, stackTrace) {
          print('❌ Erreur chargement photo URL: $exception');
        },
        child: _buildDefaultAvatar(userName),
      );
    } else {
      // Fallback avec initiales
      return _buildDefaultAvatar(userName);
    }
  }

  // Avatar par défaut avec initiales
  Widget _buildDefaultAvatar(String userName) {
    return CircleAvatar(
      radius: 20,
      backgroundColor: _getAvatarColor(userName),
      child: Text(
        _getInitials(userName),
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  // Vérifier si c'est une chaîne base64
  bool _isBase64Image(String data) {
    if (data.isEmpty) return false;
    return data.startsWith('data:image/') ||
        data.startsWith('/9j/') || // JPEG
        data.startsWith('iVBOR') || // PNG
        data.length > 100; // Les vraies images base64 sont longues
  }

  // Obtenir les initiales du nom
  String _getInitials(String name) {
    if (name.isEmpty) return '?';

    final parts = name.trim().split(' ');
    if (parts.length == 1) {
      return parts[0][0].toUpperCase();
    } else {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
  }

  // Obtenir une couleur basée sur le nom
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

    if (name.isEmpty) return colors[0];

    final index = name.codeUnits.fold(0, (a, b) => a + b) % colors.length;
    return colors[index];
  }

  void _toggleLike() {
    setState(() {
      _isLiked = !_isLiked;
    });
    widget.onLike();
  }

  void _submitComment() {
    final comment = _commentController.text.trim();
    if (comment.isNotEmpty) {
      widget.onComment(comment);
      _commentController.clear();
      setState(() {
        _showComments = true;
      });
    }
  }

  void _toggleComments() {
    setState(() {
      _showComments = !_showComments;
    });
  }

  bool _canDeletePost() {
    final currentUserId = _authService.getCurrentUser()?.uid;
    return currentUserId == widget.post.userId;
  }

  // NEW: Build comment item with user profile picture and name
  Widget _buildCommentItem(Comment comment) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: GestureDetector(
        onTap: widget.onCommenterTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Commenter profile picture
            _buildCommenterAvatar(comment.userPhoto, comment.userName),

            const SizedBox(width: 8),

            // Comment content with user info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User name and timestamp row
                  Row(
                    children: [
                      // User name
                      Text(
                        comment.userName.isNotEmpty ? comment.userName : 'Anonyme',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Colors.black87,
                        ),
                      ),

                      const SizedBox(width: 8),

                      // Timestamp
                      Text(
                        _formatCommentTimestamp(comment.timestamp),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 2),

                  // Comment text
                  Text(
                    comment.content,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.left,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // NEW: Build commenter avatar
  Widget _buildCommenterAvatar(String userPhoto, String userName) {
    // Check if it's a base64 image
    if (userPhoto.isNotEmpty && _isBase64Image(userPhoto)) {
      try {
        final Uint8List imageBytes = _imageService.base64ToImage(userPhoto);
        return CircleAvatar(
          radius: 16, // Slightly smaller than post author avatar
          backgroundImage: MemoryImage(imageBytes),
        );
      } catch (e) {
        print('❌ Erreur décodage base64 photo commentateur: $e');
        return _buildDefaultCommenterAvatar(userName);
      }
    }
    // Check if it's a valid URL
    else if (userPhoto.isNotEmpty && userPhoto.startsWith('http')) {
      return CircleAvatar(
        radius: 16,
        backgroundImage: NetworkImage(userPhoto),
        onBackgroundImageError: (exception, stackTrace) {
          print('❌ Erreur chargement photo URL commentateur: $exception');
        },
        child: _buildDefaultCommenterAvatar(userName),
      );
    } else {
      // Fallback with initials
      return _buildDefaultCommenterAvatar(userName);
    }
  }

  // NEW: Default avatar for commenter
  Widget _buildDefaultCommenterAvatar(String userName) {
    return CircleAvatar(
      radius: 16,
      backgroundColor: _getAvatarColor(userName),
      child: Text(
        _getInitials(userName),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  // NEW: Format timestamp for comments
  String _formatCommentTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) return "à l'instant";
    if (difference.inMinutes < 60) return "il y a ${difference.inMinutes} min";
    if (difference.inHours < 24) return "il y a ${difference.inHours} h";
    if (difference.inDays < 7) return "il y a ${difference.inDays} j";

    // Format date if older than a week
    return "${timestamp.day}/${timestamp.month}/${timestamp.year}";
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête du post
            _buildPostHeader(),

            const SizedBox(height: 12),

            // Contenu du post
            _buildPostContent(),

            // Détails de pêche
            _buildFishingDetails(),

            // Images
            _buildPostImages(),

            const SizedBox(height: 12),

            // Actions (like, comment, share)
            _buildPostActions(),

            // Zone de commentaire
            _buildCommentSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildPostHeader() {
    return GestureDetector(
      onTap: widget.onUserTap,
      child: Row(
        children: [
          _buildUserAvatar(widget.post.userPhoto, widget.post.userName),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.post.userName.isNotEmpty
                      ? widget.post.userName
                      : 'Pêcheur',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  _formatTimestamp(widget.post.timestamp),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (_canDeletePost())
            IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: _showDeleteMenu,
            ),
        ],
      ),
    );
  }

  Widget _buildPostContent() {
    if (widget.post.content.isEmpty) return const SizedBox();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        widget.post.content,
        style: const TextStyle(
          fontSize: 14,
          height: 1.4,
        ),
        textAlign: TextAlign.left,
      ),
    );
  }

  Widget _buildFishingDetails() {
    final hasFishingDetails = widget.post.fishType != null ||
        widget.post.fishWeight != null ||
        widget.post.location != null;

    if (!hasFishingDetails) return const SizedBox();

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[100]!),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          if (widget.post.fishType != null)
            _buildFishInfo(Icons.phishing, '${widget.post.fishType}'),
          if (widget.post.fishWeight != null)
            _buildFishInfo(Icons.fitness_center, '${widget.post.fishWeight}kg'),
          if (widget.post.location != null)
            _buildFishInfo(Icons.location_on, widget.post.location!),
        ].where((widget) => widget != null).cast<Widget>().toList(),
      ),
    );
  }

  Widget _buildFishInfo(IconData icon, String text) {
    return Flexible(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.blue[700]),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: Colors.blue[700],
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostImages() {
    if (widget.post.images.isEmpty) return const SizedBox();

    return Column(
      children: [
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            mainAxisExtent: 150,
          ),
          itemCount: widget.post.images.length,
          itemBuilder: (context, index) {
            final image = widget.post.images[index];
            return ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  image: DecorationImage(
                    image: MemoryImage(base64Decode(image.base64Data)),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPostActions() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          _buildActionButton(
            icon: _isLiked ? Icons.favorite : Icons.favorite_border,
            label: '${widget.post.likedBy.length}',
            color: _isLiked ? Colors.red : Colors.grey[600],
            onPressed: _toggleLike,
          ),
          const SizedBox(width: 16),
          _buildActionButton(
            icon: Icons.comment,
            label: '${widget.post.comments.length}',
            color: Colors.grey[600],
            onPressed: _toggleComments,
          ),
          const Spacer(),
          _buildActionButton(
            icon: Icons.share,
            label: 'share'.tr(),
            color: Colors.grey[600],
            onPressed: widget.onShare,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color? color,
    required VoidCallback onPressed,
  }) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20, color: color),
      label: Text(
        label,
        style: TextStyle(color: color, fontSize: 12),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: Size.zero,
      ),
    );
  }

  Widget _buildCommentSection() {
    return Column(
      children: [
        // Comments list
        if (_showComments && widget.post.comments.isNotEmpty) ...[
          const SizedBox(height: 12),

          // Comments header
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              'Commentaires (${widget.post.comments.length})',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ),

          // Comments list
          ...widget.post.comments.map((comment) => _buildCommentItem(comment)),

          const SizedBox(height: 8),
        ],

        // Comment input field
        Row(
          children: [
            // Current user's avatar in comment input
            CircleAvatar(
              radius: 16,
              backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
              child: _buildCurrentUserAvatar(),
            ),

            const SizedBox(width: 8),

            Expanded(
              child: TextField(
                controller: _commentController,
                decoration: InputDecoration(
                  hintText: "write_comment".tr(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(color: Colors.grey[400]!),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  suffixIcon: IconButton(
                    icon: Icon(Icons.send, color: Theme.of(context).primaryColor),
                    onPressed: _submitComment,
                  ),
                ),
                onSubmitted: (_) => _submitComment(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // NEW: Build current user's avatar for comment input
  Widget _buildCurrentUserAvatar() {
    final currentUser = _authService.getCurrentUser();
    if (currentUser == null) {
      return const Icon(Icons.person, size: 16, color: Colors.grey);
    }

    final userName = currentUser.displayName ?? currentUser.email?.split('@').first ?? 'U';
    final userPhoto = currentUser.photoURL ?? '';

    if (userPhoto.isNotEmpty && _isBase64Image(userPhoto)) {
      try {
        final Uint8List imageBytes = _imageService.base64ToImage(userPhoto);
        return CircleAvatar(
          radius: 16,
          backgroundImage: MemoryImage(imageBytes),
        );
      } catch (e) {
        return _buildDefaultCurrentUserAvatar(userName);
      }
    } else if (userPhoto.isNotEmpty && userPhoto.startsWith('http')) {
      return CircleAvatar(
        radius: 16,
        backgroundImage: NetworkImage(userPhoto),
        child: _buildDefaultCurrentUserAvatar(userName),
      );
    } else {
      return _buildDefaultCurrentUserAvatar(userName);
    }
  }

  // NEW: Default avatar for current user in comment input
  Widget _buildDefaultCurrentUserAvatar(String userName) {
    return CircleAvatar(
      radius: 16,
      backgroundColor: _getAvatarColor(userName),
      child: Text(
        _getInitials(userName),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  void _showDeleteMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: Text("delete_post".tr()),
              onTap: () {
                Navigator.pop(context);
                widget.onDelete();
              },
            ),
            ListTile(
              leading: const Icon(Icons.cancel),
              title: Text("cancel".tr()),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) return "now".tr();
    if (difference.inHours < 1) return "${difference.inMinutes}min";
    if (difference.inDays < 1) return "${difference.inHours}h";
    if (difference.inDays < 7) return "${difference.inDays}j";

    return "${timestamp.day}/${timestamp.month}/${timestamp.year}";
  }
}