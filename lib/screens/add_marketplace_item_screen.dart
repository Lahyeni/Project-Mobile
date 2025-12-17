import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../services/auth_service.dart';
import '../services/marketplace_service.dart';
import '../services/image_service.dart';
import '../models/marketplace_model.dart';

class AddMarketplaceItemScreen extends StatefulWidget {
  const AddMarketplaceItemScreen({super.key});

  @override
  State<AddMarketplaceItemScreen> createState() =>
      _AddMarketplaceItemScreenState();
}

class _AddMarketplaceItemScreenState extends State<AddMarketplaceItemScreen> {
  final AuthService _authService = AuthService();
  final MarketplaceService _marketplaceService = MarketplaceService();
  final ImageService _imageService = ImageService();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  String _category = "tools";
  String _condition = "used";
  final List<ItemImage> _images = [];
  bool _isLoading = false;
  bool _isUploadingImage = false;

  // NEW: make background removal optional
  bool _removeBackground = true;

  final List<Map<String, String>> _categoryOptions = [
    {"value": "tools", "label": "🛠️ Outils de pêche"},
    {"value": "baits", "label": "🐛 Appâts"},
    {"value": "fresh_fish", "label": "🐟 Poisson frais"},
  ];

  final List<Map<String, String>> _conditionOptions = [
    {"value": "new", "label": "Neuf"},
    {"value": "excellent", "label": "Excellent état"},
    {"value": "used", "label": "Occasion"},
  ];

  Future<void> _addImageFromCamera() async {
    try {
      setState(() => _isUploadingImage = true);

      final File? file = await _imageService.takePhoto();
      if (file == null) return;

      final String base64Image = await _imageService.imageToBase64(
        file,
        removeBackground: _removeBackground,
      );

      setState(() {
        _images.add(ItemImage(
          base64Data: base64Image,
          uploadedAt: DateTime.now(),
        ));
      });
    } catch (e) {
      _showError('Erreur: $e');
    } finally {
      setState(() => _isUploadingImage = false);
    }
  }

  Future<void> _addImageFromGallery() async {
    try {
      setState(() => _isUploadingImage = true);

      final File? file = await _imageService.pickImageFromGallery();
      if (file == null) return;

      final String base64Image = await _imageService.imageToBase64(
        file,
        removeBackground: _removeBackground,
      );

      setState(() {
        _images.add(ItemImage(
          base64Data: base64Image,
          uploadedAt: DateTime.now(),
        ));
      });
    } catch (e) {
      _showError('Erreur: $e');
    } finally {
      setState(() => _isUploadingImage = false);
    }
  }

  void _removeImage(int index) {
    setState(() {
      _images.removeAt(index);
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  Widget _buildImageWidget(String base64Data) {
    try {
      final String cleanBase64 =
      base64Data.contains(',') ? base64Data.split(',').last : base64Data;
      final bytes = base64.decode(cleanBase64);

      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(
          bytes,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Colors.grey[300],
              child: const Icon(Icons.error, color: Colors.red),
            );
          },
        ),
      );
    } catch (e) {
      return Container(
        color: Colors.grey[300],
        child: const Icon(Icons.error, color: Colors.red),
      );
    }
  }

  Future<void> _createItem() async {
    if (_titleController.text.isEmpty || _priceController.text.isEmpty) {
      _showError('Titre et prix sont requis');
      return;
    }

    final price = double.tryParse(_priceController.text);
    if (price == null || price <= 0) {
      _showError('Prix invalide');
      return;
    }

    final user = _authService.getCurrentUser();
    if (user == null) {
      _showError('Connectez-vous pour vendre un item');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userData = await _authService.getUserData(user.uid);

      final item = MarketplaceItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleController.text,
        description: _descriptionController.text,
        price: price,
        category: _category,
        images: _images,
        sellerId: user.uid,
        sellerName: userData?['displayName'] ?? user.displayName ?? 'Pêcheur',
        sellerPhoto: userData?['photoURL'] ?? user.photoURL ?? '',
        location: _locationController.text,
        condition: _condition,
        createdAt: DateTime.now(),
        likes: 0,
        likedBy: [],
      );

      await _marketplaceService.createItemWithImages(item);
      _showSuccess('Article publié avec succès!');
      Navigator.pop(context);
    } catch (e) {
      _showError('Erreur: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("sell_item".tr()),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _createItem,
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
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "item_information".tr(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        labelText: "item_title".tr(),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _descriptionController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: "description".tr(),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: "price_euros".tr(),
                        prefixText: '€',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "details".tr(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _category,
                      decoration: InputDecoration(
                        labelText: "category".tr(),
                        border: const OutlineInputBorder(),
                      ),
                      items: _categoryOptions.map((option) {
                        return DropdownMenuItem<String>(
                          value: option["value"],
                          child: Text(option["label"]!),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _category = newValue!;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _condition,
                      decoration: InputDecoration(
                        labelText: "condition".tr(),
                        border: const OutlineInputBorder(),
                      ),
                      items: _conditionOptions.map((option) {
                        return DropdownMenuItem<String>(
                          value: option["value"],
                          child: Text(option["label"]!),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _condition = newValue!;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _locationController,
                      decoration: InputDecoration(
                        labelText: "location".tr(),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Images
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

                    // NEW toggle
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text("Retirer le fond (optionnel)"),
                      value: _removeBackground,
                      onChanged: (v) {
                        setState(() => _removeBackground = v);
                      },
                    ),

                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isUploadingImage
                                ? null
                                : _addImageFromCamera,
                            icon: const Icon(Icons.camera_alt),
                            label: Text("take_photo".tr()),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isUploadingImage
                                ? null
                                : _addImageFromGallery,
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
                          childAspectRatio: 1,
                        ),
                        itemCount: _images.length,
                        itemBuilder: (context, index) {
                          return Stack(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  color: Colors.grey[200],
                                ),
                                child: _buildImageWidget(
                                  _images[index].base64Data,
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
                        "Les images sont stockées en base64. Maximum 1MB par image.",
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
