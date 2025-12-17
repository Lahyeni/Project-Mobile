import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/user_service.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';

class EditProfileScreen extends StatefulWidget {
  final UserProfile? userProfile;

  const EditProfileScreen({super.key, this.userProfile});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final UserService _userService = UserService();
  final AuthService _authService = AuthService();

  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _favoriteSpotController = TextEditingController();
  final TextEditingController _fishingGearController = TextEditingController();

  List<String> _fishingGear = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  void _initializeForm() {
    if (widget.userProfile != null) {
      _displayNameController.text = widget.userProfile!.displayName ?? '';
      _bioController.text = widget.userProfile!.bio ?? '';
      _locationController.text = widget.userProfile!.location ?? '';
      _favoriteSpotController.text = widget.userProfile!.favoriteSpot ?? '';
      _fishingGear = List.from(widget.userProfile!.fishingGear);
    }
  }

  void _addFishingGear() {
    final gear = _fishingGearController.text.trim();
    if (gear.isNotEmpty && !_fishingGear.contains(gear)) {
      setState(() {
        _fishingGear.add(gear);
        _fishingGearController.clear();
      });
    }
  }

  void _removeFishingGear(int index) {
    setState(() {
      _fishingGear.removeAt(index);
    });
  }

  Future<void> _saveProfile() async {
    final user = _authService.getCurrentUser();
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      final userProfile = UserProfile(
        uid: user.uid,
        email: user.email!,
        displayName: _displayNameController.text.trim(),
        bio: _bioController.text.trim(),
        location: _locationController.text.trim(),
        favoriteSpot: _favoriteSpotController.text.trim(),
        fishingGear: _fishingGear,
        createdAt: widget.userProfile?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        isDarkMode: widget.userProfile?.isDarkMode ?? false,
        language: widget.userProfile?.language ?? 'fr',
      );

      await _userService.saveUserProfile(userProfile);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('profile_updated'.tr())),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('error_updating_profile'.tr())),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("edit_profile".tr()),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveProfile,
            child: _isLoading
                ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : Text(
              "save".tr(),
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
          children: [
            // Informations de base
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "basic_information".tr(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _displayNameController,
                      decoration: InputDecoration(
                        labelText: "display_name".tr(),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _bioController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: "bio".tr(),
                        hintText: "tell_us_about_yourself".tr(),
                        border: const OutlineInputBorder(),
                      ),
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
                    Text(
                      "location".tr(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _locationController,
                      decoration: InputDecoration(
                        labelText: "your_location".tr(),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _favoriteSpotController,
                      decoration: InputDecoration(
                        labelText: "favorite_fishing_spot".tr(),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Matériel de pêche
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "fishing_gear".tr(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _fishingGearController,
                            decoration: InputDecoration(
                              labelText: "add_fishing_gear".tr(),
                              border: const OutlineInputBorder(),
                            ),
                            onSubmitted: (_) => _addFishingGear(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: _addFishingGear,
                        ),
                      ],
                    ),
                    if (_fishingGear.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _fishingGear.asMap().entries.map((entry) {
                          final index = entry.key;
                          final gear = entry.value;
                          return Chip(
                            label: Text(gear),
                            onDeleted: () => _removeFishingGear(index),
                          );
                        }).toList(),
                      ),
                    ],
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