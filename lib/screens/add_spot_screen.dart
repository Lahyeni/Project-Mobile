import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../services/auth_service.dart';
import '../services/spot_service.dart';
import '../services/image_service.dart';
import '../models/spot_model.dart';

class AddSpotScreen extends StatefulWidget {
  const AddSpotScreen({super.key});

  @override
  State<AddSpotScreen> createState() => _AddSpotScreenState();
}

class _AddSpotScreenState extends State<AddSpotScreen> {
  final AuthService _authService = AuthService();
  final SpotService _spotService = SpotService();
  final ImageService _imageService = ImageService();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _fishTypesController = TextEditingController();
  final TextEditingController _coordinatesController = TextEditingController();

  String _difficulty = "Facile";
  String _bestSeason = "Printemps";
  String _type = "lake";
  double _rating = 4.0;
  final List<String> _fishTypes = [];
  final List<SpotImage> _images = [];
  bool _isLoading = false;
  bool _isUploadingImage = false;

  // NEW: make background removal optional
  bool _removeBackground = true;

  final List<String> _difficultyOptions = ["Facile", "Moyen", "Difficile"];
  final List<String> _seasonOptions = [
    "Printemps",
    "Été",
    "Automne",
    "Hiver",
    "Toute l'année"
  ];
  final List<Map<String, String>> _typeOptions = [
    {"value": "lake", "label": "🛶 Lac/Étang", "icon": "🛶"},
    {"value": "river", "label": "🌊 Rivière/Fleuve", "icon": "🌊"},
    {"value": "beach", "label": "🏖️ Plage/Mer", "icon": "🏖️"},
    {"value": "other", "label": "📍 Autre", "icon": "📍"},
  ];

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _addImageFromCamera() async {
    try {
      setState(() => _isUploadingImage = true);

      final String base64Image = await _imageService.captureAndConvertToBase64(
        removeBackground: _removeBackground,
      );

      setState(() {
        _images.add(SpotImage(
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

      final String base64Image = await _imageService.pickAndConvertToBase64(
        removeBackground: _removeBackground,
      );

      setState(() {
        _images.add(SpotImage(
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

  void _addFishType() {
    final fishType = _fishTypesController.text.trim();
    if (fishType.isNotEmpty && !_fishTypes.contains(fishType)) {
      setState(() {
        _fishTypes.add(fishType);
        _fishTypesController.clear();
      });
    }
  }

  void _removeFishType(int index) {
    setState(() {
      _fishTypes.removeAt(index);
    });
  }

  Future<void> _createSpot() async {
    if (_nameController.text.isEmpty || _locationController.text.isEmpty) {
      _showError('Nom et localisation requis');
      return;
    }

    final user = _authService.getCurrentUser();
    if (user == null) {
      _showError('Connectez-vous pour ajouter un spot');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final spot = FishingSpot(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text,
        location: _locationController.text,
        description: _descriptionController.text,
        fishTypes: _fishTypes,
        rating: _rating,
        difficulty: _difficulty,
        bestSeason: _bestSeason,
        coordinates: _coordinatesController.text,
        type: _type,
        images: _images,
        createdBy: user.uid,
        createdAt: DateTime.now(),
        likes: 0,
        likedBy: [],
      );

      await _spotService.createSpotWithImages(spot);
      _showSuccess('Spot ajouté avec succès!');
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
        title: Text("add_fishing_spot".tr()),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _createSpot,
            child: _isLoading
                ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : Text(
              "add_spot".tr(),
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
            // Informations de base
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "spot_information".tr(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: "spot_name".tr(),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _locationController,
                      decoration: InputDecoration(
                        labelText: "location".tr(),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _type,
                      decoration: InputDecoration(
                        labelText: "type_spot".tr(),
                        border: const OutlineInputBorder(),
                      ),
                      items: _typeOptions.map((option) {
                        return DropdownMenuItem<String>(
                          value: option["value"],
                          child: Text(option["label"]!),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _type = newValue!;
                        });
                      },
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
                            ],
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Détails de pêche
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "fishing_details".tr(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _difficulty,
                      decoration: InputDecoration(
                        labelText: "difficulty".tr(),
                        border: const OutlineInputBorder(),
                      ),
                      items: _difficultyOptions.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _difficulty = newValue!;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _bestSeason,
                      decoration: InputDecoration(
                        labelText: "best_season".tr(),
                        border: const OutlineInputBorder(),
                      ),
                      items: _seasonOptions.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _bestSeason = newValue!;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("rating".tr()),
                        Slider(
                          value: _rating,
                          min: 1,
                          max: 5,
                          divisions: 4,
                          label: _rating.toStringAsFixed(1),
                          onChanged: (double value) {
                            setState(() {
                              _rating = value;
                            });
                          },
                        ),
                        Text('${_rating.toStringAsFixed(1)}/5'),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Types de poissons
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "fish_types".tr(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _fishTypesController,
                            decoration: InputDecoration(
                              labelText: "add_fish_type".tr(),
                              border: const OutlineInputBorder(),
                            ),
                            onSubmitted: (_) => _addFishType(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: _addFishType,
                        ),
                      ],
                    ),
                    if (_fishTypes.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        children: _fishTypes.asMap().entries.map((entry) {
                          final index = entry.key;
                          final fish = entry.value;
                          return Chip(
                            label: Text(fish),
                            onDeleted: () => _removeFishType(index),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Coordonnées (optionnel)
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "coordinates".tr(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _coordinatesController,
                      decoration: InputDecoration(
                        labelText: "coordinates_optional".tr(),
                        hintText: "48.8566, 2.3522",
                        border: const OutlineInputBorder(),
                      ),
                    ),
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
                        "Les images sont stockées directement dans la base de données (base64).",
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
