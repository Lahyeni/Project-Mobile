import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../services/image_service.dart';
import '../services/post_service.dart';
import '../services/auth_service.dart';
import '../models/post_model.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final ImageService _imageService = ImageService();
  final PostService _postService = PostService();
  final AuthService _authService = AuthService();

  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _fishTypeController = TextEditingController();
  final TextEditingController _fishWeightController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  final List<PostImage> _images = [];
  bool _isLoading = false;
  bool _isUploadingImage = false;

  // NEW: make background removal optional (same as Marketplace/Spot)
  bool _removeBackground = true;

  // Ajouter une image depuis la caméra
  Future<void> _addImageFromCamera() async {
    try {
      setState(() => _isUploadingImage = true);

      final String base64Image = await _imageService.captureAndConvertToBase64(
        removeBackground: _removeBackground,
      );

      setState(() {
        _images.add(PostImage(
          base64Data: base64Image,
          uploadedAt: DateTime.now(),
        ));
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  // Ajouter une image depuis la galerie
  Future<void> _addImageFromGallery() async {
    try {
      setState(() => _isUploadingImage = true);

      final String base64Image = await _imageService.pickAndConvertToBase64(
        removeBackground: _removeBackground,
      );

      setState(() {
        _images.add(PostImage(
          base64Data: base64Image,
          uploadedAt: DateTime.now(),
        ));
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  // Supprimer une image
  void _removeImage(int index) {
    setState(() {
      _images.removeAt(index);
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  // Créer le post
  Future<void> _createPost() async {
    if (_contentController.text.trim().isEmpty && _images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("post_content_required".tr())),
      );
      return;
    }

    final user = _authService.getCurrentUser();
    if (user == null) {
      _showError('Connectez-vous pour créer un post');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userData = await _authService.getUserData(user.uid);

      final post = Post(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: user.uid,
        userName: userData?['displayName'] ?? user.displayName ?? 'Pêcheur',
        userPhoto: userData?['photoURL'] ?? user.photoURL ?? '',
        content: _contentController.text.trim(),
        images: _images,
        fishType: _fishTypeController.text.trim().isNotEmpty
            ? _fishTypeController.text.trim()
            : null,
        fishWeight: _fishWeightController.text.trim().isNotEmpty
            ? double.tryParse(_fishWeightController.text.trim())
            : null,
        location: _locationController.text.trim().isNotEmpty
            ? _locationController.text.trim()
            : null,
        timestamp: DateTime.now(),
        likes: 0,
        likedBy: [],
        comments: [],
        imageUrl: '',
      );

      await _postService.createPostWithImages(post);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("post_published".tr())),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur: ${e.toString()}")),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    _fishTypeController.dispose();
    _fishWeightController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("create_post".tr()),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _createPost,
            child: _isLoading
                ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : Text(
              "publish".tr(),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Zone de texte principale
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _contentController,
                  maxLines: 5,
                  decoration: InputDecoration.collapsed(
                    hintText: "share_your_fishing_story".tr(),
                  ),
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Ajout d'images
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "📷 ${"add_images".tr()}",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    // NEW toggle (optional background removal)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text("Retirer le fond (optionnel)"),
                      value: _removeBackground,
                      onChanged: (v) => setState(() => _removeBackground = v),
                    ),

                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isUploadingImage ? null : _addImageFromCamera,
                            icon: const Icon(Icons.camera_alt),
                            label: Text("take_photo".tr()),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isUploadingImage ? null : _addImageFromGallery,
                            icon: const Icon(Icons.photo_library),
                            label: Text("from_gallery".tr()),
                          ),
                        ),
                      ],
                    ),

                    if (_isUploadingImage) ...[
                      const SizedBox(height: 12),
                      const Center(child: CircularProgressIndicator()),
                    ],

                    if (_images.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        "${_images.length} ${"images_added".tr()}",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(height: 8),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: _images.length,
                        itemBuilder: (context, index) {
                          return Stack(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  image: DecorationImage(
                                    image: MemoryImage(
                                      _imageService.base64ToImage(
                                        _images[index].base64Data,
                                      ),
                                    ),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () => _removeImage(index),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 4,
                                left: 4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.7),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${_images[index].sizeInKB}KB',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Détails de pêche
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "🎣 ${"fishing_details".tr()}",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _fishTypeController,
                      decoration: InputDecoration(
                        labelText: "fish_type".tr(),
                        prefixIcon: const Icon(Icons.phishing),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _fishWeightController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: "⚖️ ${"weight_kg".tr()}",
                        prefixIcon: const Icon(Icons.fitness_center),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _locationController,
                      decoration: InputDecoration(
                        labelText: "📍 ${"fishing_spot".tr()}",
                        prefixIcon: const Icon(Icons.location_on),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Information sur le stockage
            Card(
              color: Colors.blue[50],
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Les images sont stockées directement dans la base de données (base64)",
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
