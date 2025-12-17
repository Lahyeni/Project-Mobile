import 'dart:async';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/auth_service.dart';
import '../services/spot_service.dart';
import '../services/image_service.dart';
import '../models/spot_model.dart';
import 'add_spot_screen.dart';
import 'dart:typed_data';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final AuthService _authService = AuthService();
  final SpotService _spotService = SpotService();
  final ImageService _imageService = ImageService();

  List<FishingSpot> _spots = [];
  List<FishingSpot> _favoriteSpots = [];
  String _selectedFilter = "all";
  bool _isLoading = true;
  StreamSubscription<List<FishingSpot>>? _spotsSubscription;
  StreamSubscription<List<FishingSpot>>? _favoritesSubscription;

  @override
  void initState() {
    super.initState();
    _loadSpots();
    _loadFavorites();
  }

  @override
  void dispose() {
    _spotsSubscription?.cancel();
    _favoritesSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadSpots() async {
    print('=== DÉBUT CHARGEMENT SPOTS ===');
    setState(() => _isLoading = true);

    try {
      _spotsSubscription = _spotService.getSpots().listen(
            (spots) {
          print('=== STREAM SPOTS: ${spots.length} spots reçus ===');
          for (var spot in spots) {
            print('Spot ${spot.id}: ${spot.name} - Type: ${spot.type} - Images: ${spot.images.length}');
          }

          if (mounted) {
            setState(() {
              _spots = spots;
              _isLoading = false;
            });
          }
        },
        onError: (error) {
          print('=== ERREUR STREAM SPOTS: $error ===');
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
        },
      );
    } catch (e) {
      print('=== ERREUR INIT STREAM SPOTS: $e ===');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadFavorites() async {
    final user = _authService.getCurrentUser();
    if (user == null) return;

    try {
      _favoritesSubscription = _spotService.getUserFavorites().listen(
            (favoriteSpots) {
          print('=== FAVORIS: ${favoriteSpots.length} spots ===');
          if (mounted) {
            setState(() {
              _favoriteSpots = favoriteSpots;
            });
          }
        },
        onError: (error) {
          print('=== ERREUR FAVORIS: $error ===');
        },
      );
    } catch (e) {
      print('Erreur chargement favoris: $e');
    }
  }

  Future<void> _toggleFavorite(FishingSpot spot) async {
    try {
      await _spotService.toggleFavoriteSpot(spot.id);
    } catch (e) {
      print('Erreur toggle favorite: $e');
      _showError('Erreur: $e');
    }
  }

  Future<void> _toggleLike(FishingSpot spot) async {
    try {
      await _spotService.toggleLikeSpot(spot.id);
    } catch (e) {
      print('Erreur toggle like: $e');
      _showError('Erreur: $e');
    }
  }

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

  bool _isFavorite(FishingSpot spot) {
    return _favoriteSpots.any((s) => s.id == spot.id);
  }

  Widget _buildSpotImage(FishingSpot spot) {
    if (spot.hasImages && spot.firstImageBase64 != null) {
      try {
        final Uint8List imageBytes = _imageService.base64ToImage(spot.firstImageBase64!);
        return Image.memory(
          imageBytes,
          fit: BoxFit.cover,
          width: double.infinity,
          height: 120,
        );
      } catch (e) {
        print('Erreur affichage image spot ${spot.id}: $e');
        return _buildDefaultImage();
      }
    } else {
      return _buildDefaultImage();
    }
  }

  Widget _buildDefaultImage() {
    return Container(
      color: Colors.grey[200],
      child: const Center(
        child: Icon(
          Icons.location_on,
          size: 50,
          color: Colors.grey,
        ),
      ),
    );
  }

  String _getTypeIcon(String type) {
    switch (type) {
      case 'lake':
        return '🛶';
      case 'river':
        return '🌊';
      case 'beach':
        return '🏖️';
      default:
        return '📍';
    }
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'lake':
        return 'Lac/Étang';
      case 'river':
        return 'Rivière/Fleuve';
      case 'beach':
        return 'Plage/Mer';
      default:
        return 'Autre';
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredSpots = _filterSpots();

    return Scaffold(
      appBar: AppBar(
        title: Text("fishing_spots".tr()),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _searchSpots,
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          _buildMapHeader(),
          _buildQuickFilters(),
          Expanded(child: _buildSpotsList(filteredSpots)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewSpot,
        child: const Icon(Icons.add_location),
      ),
    );
  }

  Widget _buildMapHeader() {
    return Container(
      height: 150,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.green[400]!, Colors.blue[400]!],
        ),
      ),
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.map, size: 50, color: Colors.white),
                const SizedBox(height: 8),
                Text(
                  "explore_fishing_spots".tr(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "${_spots.length} ${"spots_available".tr()}",
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickFilters() {
    final List<Map<String, dynamic>> filters = [
      {"value": "all", "label": "all_spots".tr(), "icon": Icons.all_inclusive},
      {"value": "lake", "label": "lakes".tr(), "icon": Icons.water},
      {"value": "river", "label": "rivers".tr(), "icon": Icons.waves},
      {"value": "beach", "label": "beaches".tr(), "icon": Icons.beach_access},
      {"value": "other", "label": "other".tr(), "icon": Icons.location_on},
      {"value": "favorites", "label": "favorites".tr(), "icon": Icons.favorite},
    ];

    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final filterValue = filter["value"] as String;
          final filterLabel = filter["label"] as String;
          final isSelected = _selectedFilter == filterValue;

          return Container(
            margin: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: isSelected,
              onSelected: (_) => setState(() => _selectedFilter = filterValue),
              label: Text(filterLabel),
              avatar: Icon(filter["icon"] as IconData, size: 16),
              backgroundColor: isSelected ? Colors.blue[50] : Colors.grey[200],
              selectedColor: Colors.blue[100],
              checkmarkColor: Colors.blue,
              labelStyle: TextStyle(
                color: isSelected ? Colors.blue[700] : Colors.grey[700],
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSpotsList(List<FishingSpot> spots) {
    if (spots.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_off, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              "no_spots_found".tr(),
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _selectedFilter == "favorites"
                  ? "no_favorite_spots".tr()
                  : "adjust_filters".tr(),
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: spots.length,
      itemBuilder: (context, index) => _buildSpotCard(spots[index]),
    );
  }

  Widget _buildSpotCard(FishingSpot spot) {
    final isFavorite = _isFavorite(spot);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                  color: Colors.grey[200],
                ),
                child: _buildSpotImage(spot),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star, size: 14, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        spot.rating.toStringAsFixed(1),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _getTypeIcon(spot.type),
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _getTypeLabel(spot.type),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            spot.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            spot.location,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.favorite,
                            color: spot.likedBy.isNotEmpty ? Colors.red : Colors.grey,
                          ),
                          onPressed: () => _toggleLike(spot),
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(),
                        ),
                        IconButton(
                          icon: Icon(
                            isFavorite ? Icons.bookmark : Icons.bookmark_border,
                            color: isFavorite ? Colors.blue : Colors.grey,
                          ),
                          onPressed: () => _toggleFavorite(spot),
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  spot.description,
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: spot.fishTypes.map((fish) => Chip(
                    label: Text(fish),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    backgroundColor: Colors.green[50],
                    labelStyle: TextStyle(
                      color: Colors.green[700],
                      fontSize: 12,
                    ),
                  )).toList(),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildInfoChip(Icons.landscape, spot.difficulty),
                    _buildInfoChip(Icons.calendar_today, spot.bestSeason),
                    _buildInfoChip(Icons.favorite, '${spot.likes}'),
                    if (spot.images.isNotEmpty)
                      _buildInfoChip(Icons.photo, '${spot.images.length}'),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () => _showSpotDetails(spot),
                    icon: const Icon(Icons.info, size: 16),
                    label: Text("details".tr()),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  List<FishingSpot> _filterSpots() {
    switch (_selectedFilter) {
      case "lake":
        return _spots.where((spot) => spot.type == "lake").toList();
      case "river":
        return _spots.where((spot) => spot.type == "river").toList();
      case "beach":
        return _spots.where((spot) => spot.type == "beach").toList();
      case "other":
        return _spots.where((spot) => spot.type == "other").toList();
      case "favorites":
        return _favoriteSpots;
      default:
        return _spots;
    }
  }

  void _searchSpots() {
    showSearch(
      context: context,
      delegate: _SpotSearchDelegate(_spots),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("filter_spots".tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.star),
              title: Text("top_rated".tr()),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _spots.sort((a, b) => b.rating.compareTo(a.rating));
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.favorite),
              title: Text("most_liked".tr()),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _spots.sort((a, b) => b.likes.compareTo(a.likes));
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.new_releases),
              title: Text("newest_first".tr()),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _spots.sort((a, b) => b.createdAt.compareTo(a.createdAt));
                });
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("cancel".tr()),
          ),
        ],
      ),
    );
  }

  void _showSpotDetails(FishingSpot spot) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _SpotDetailsSheet(spot: spot, imageService: _imageService),
    );
  }

  void _addNewSpot() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddSpotScreen()),
    );
  }
}

class _SpotDetailsSheet extends StatelessWidget {
  final FishingSpot spot;
  final ImageService imageService;

  const _SpotDetailsSheet({required this.spot, required this.imageService});

  String _getTypeIcon(String type) {
    switch (type) {
      case 'lake':
        return '🛶';
      case 'river':
        return '🌊';
      case 'beach':
        return '🏖️';
      default:
        return '📍';
    }
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'lake':
        return 'Lac/Étang';
      case 'river':
        return 'Rivière/Fleuve';
      case 'beach':
        return 'Plage/Mer';
      default:
        return 'Autre';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            spot.name,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.location_on, size: 16, color: Colors.grey),
              const SizedBox(width: 4),
              Expanded(child: Text(spot.location)),
              const SizedBox(width: 8),
              Text(
                _getTypeIcon(spot.type),
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(width: 4),
              Text(
                _getTypeLabel(spot.type),
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(spot.description),
          const SizedBox(height: 16),
          if (spot.images.isNotEmpty) ...[
            Text(
              "Photos du spot",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: spot.images.length,
                itemBuilder: (context, index) {
                  return Container(
                    width: 100,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      image: DecorationImage(
                        image: MemoryImage(imageService.base64ToImage(spot.images[index].base64Data)),
                        fit: BoxFit.cover,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
          Text(
            "fish_species".tr(),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: spot.fishTypes.map((fish) => Chip(label: Text(fish))).toList(),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildDetailChip(Icons.star, '${spot.rating}/5'),
              const SizedBox(width: 8),
              _buildDetailChip(Icons.landscape, spot.difficulty),
              const SizedBox(width: 8),
              _buildDetailChip(Icons.calendar_today, spot.bestSeason),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: Text("close".tr()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.blue[700]),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: Colors.blue[700],
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _SpotSearchDelegate extends SearchDelegate {
  final List<FishingSpot> spots;

  _SpotSearchDelegate(this.spots);

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults();
  }

  Widget _buildSearchResults() {
    final results = spots.where((spot) =>
    spot.name.toLowerCase().contains(query.toLowerCase()) ||
        spot.location.toLowerCase().contains(query.toLowerCase()) ||
        spot.fishTypes.any((fish) => fish.toLowerCase().contains(query.toLowerCase()))).toList();

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) => ListTile(
        leading: const Icon(Icons.location_on),
        title: Text(results[index].name),
        subtitle: Text(results[index].location),
        trailing: Text(results[index].rating.toStringAsFixed(1)),
        onTap: () {
          close(context, results[index]);
        },
      ),
    );
  }
}