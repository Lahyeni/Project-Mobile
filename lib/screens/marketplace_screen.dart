import 'dart:async';

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'dart:typed_data';
import '../services/auth_service.dart';
import '../services/marketplace_service.dart';
import '../services/image_service.dart';
import '../models/marketplace_model.dart';
import 'add_marketplace_item_screen.dart';

class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  final AuthService _authService = AuthService();
  final MarketplaceService _marketplaceService = MarketplaceService();
  final ImageService _imageService = ImageService();

  List<MarketplaceItem> _items = [];
  List<MarketplaceItem> _favoriteItems = [];
  String _selectedCategory = "all";
  bool _isLoading = true;
  StreamSubscription<List<MarketplaceItem>>? _itemsSubscription;
  StreamSubscription<List<MarketplaceItem>>? _favoritesSubscription;

  @override
  void initState() {
    super.initState();
    _loadItems();
    _loadFavorites();
  }

  @override
  void dispose() {
    _itemsSubscription?.cancel();
    _favoritesSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadItems() async {
    print('=== DÉBUT CHARGEMENT ITEMS MARKETPLACE ===');
    setState(() => _isLoading = true);

    try {
      _itemsSubscription = _marketplaceService.getItems().listen(
            (items) {
          print('=== STREAM ITEMS: ${items.length} items reçus ===');
          if (mounted) {
            setState(() {
              _items = items;
              _isLoading = false;
            });
          }
        },
        onError: (error) {
          print('=== ERREUR STREAM ITEMS: $error ===');
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
        },
      );
    } catch (e) {
      print('=== ERREUR INIT STREAM ITEMS: $e ===');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadFavorites() async {
    final user = _authService.getCurrentUser();
    if (user == null) return;

    try {
      _favoritesSubscription = _marketplaceService.getUserFavorites().listen(
            (favoriteItems) {
          print('=== FAVORIS: ${favoriteItems.length} items ===');
          if (mounted) {
            setState(() {
              _favoriteItems = favoriteItems;
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

  Future<void> _toggleFavorite(MarketplaceItem item) async {
    try {
      await _marketplaceService.toggleFavoriteItem(item.id);
    } catch (e) {
      print('Erreur toggle favorite: $e');
      _showError('Erreur: $e');
    }
  }

  Future<void> _toggleLike(MarketplaceItem item) async {
    try {
      await _marketplaceService.toggleLikeItem(item.id);
    } catch (e) {
      print('Erreur toggle like: $e');
      _showError('Erreur: $e');
    }
  }

  Future<void> _toggleAvailability(MarketplaceItem item) async {
    try {
      await _marketplaceService.toggleAvailability(item.id, !item.isAvailable);
      _showSuccess('Disponibilité mise à jour');
    } catch (e) {
      print('Erreur toggle availability: $e');
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

  bool _isFavorite(MarketplaceItem item) {
    return _favoriteItems.any((i) => i.id == item.id);
  }

  bool _isOwner(MarketplaceItem item) {
    final user = _authService.getCurrentUser();
    return user != null && user.uid == item.sellerId;
  }

  Widget _buildItemImage(MarketplaceItem item) {
    if (item.hasImages && item.firstImageBase64 != null) {
      try {
        final Uint8List imageBytes = _imageService.base64ToImage(item.firstImageBase64!);
        return Image.memory(
          imageBytes,
          fit: BoxFit.cover,
          width: double.infinity,
          height: 120,
        );
      } catch (e) {
        print('Erreur affichage image item ${item.id}: $e');
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
          Icons.shopping_bag,
          size: 50,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildSellerAvatar(String sellerPhoto, String sellerName) {
    // Vérifier si c'est une image base64
    if (sellerPhoto.isNotEmpty && _isBase64Image(sellerPhoto)) {
      try {
        final Uint8List imageBytes = _imageService.base64ToImage(sellerPhoto);
        return CircleAvatar(
          radius: 20,
          backgroundImage: MemoryImage(imageBytes),
          child: sellerPhoto.isEmpty ? const Icon(Icons.person, size: 12) : null,
        );
      } catch (e) {
        print('❌ Erreur décodage base64 photo vendeur: $e');
        return _buildDefaultAvatar(sellerName);
      }
    } else {
      // Fallback avec initiales
      return _buildDefaultAvatar(sellerName);
    }
  }

// Vérifier si c'est une chaîne base64
  bool _isBase64Image(String data) {
    if (data.isEmpty) return false;

    // Les chaînes base64 d'image ont des motifs caractéristiques
    return data.startsWith('data:image/') ||
        data.startsWith('/9j/') || // JPEG
        data.startsWith('iVBOR') || // PNG
        data.length > 100; // Les vraies images base64 sont longues
  }

// Avatar par défaut avec initiales
  Widget _buildDefaultAvatar(String sellerName) {
    return CircleAvatar(
      radius: 20,
      backgroundColor: _getAvatarColor(sellerName),
      child: Text(
        _getInitials(sellerName),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
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
  @override
  Widget build(BuildContext context) {
    final filteredItems = _filterItems();

    return Scaffold(
      appBar: AppBar(
        title: Text("marketplace".tr()),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _searchItems,
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
          _buildMarketplaceHeader(),
          _buildCategoryFilters(),
          Expanded(child: _buildItemsList(filteredItems)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewItem,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildMarketplaceHeader() {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.orange[400]!, Colors.red[400]!],
        ),
      ),
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.shopping_bag, size: 40, color: Colors.white),
                const SizedBox(height: 8),
                Text(
                  "fisher_marketplace".tr(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "${_items.where((item) => item.isAvailable).length} ${"items_available".tr()}",
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilters() {
    final List<Map<String, dynamic>> filters = [
      {"value": "all", "label": "all".tr(), "icon": Icons.all_inclusive},
      {"value": "tools", "label": "tools".tr(), "icon": Icons.build},
      {"value": "baits", "label": "baits".tr(), "icon": Icons.bug_report},
      {"value": "fresh_fish", "label": "fresh_fish".tr(), "icon": Icons.set_meal},
      {"value": "favorites", "label": "favorites".tr(), "icon": Icons.favorite},
    ];

    return SizedBox(
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final filterValue = filter["value"] as String;
          final filterLabel = filter["label"] as String;
          final isSelected = _selectedCategory == filterValue;

          return Container(
            margin: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: isSelected,
              onSelected: (_) => setState(() => _selectedCategory = filterValue),
              label: Text(filterLabel),
              avatar: Icon(filter["icon"] as IconData, size: 16),
              backgroundColor: isSelected ? Colors.orange[50] : Colors.grey[200],
              selectedColor: Colors.orange[100],
              checkmarkColor: Colors.orange,
              labelStyle: TextStyle(
                color: isSelected ? Colors.orange[700] : Colors.grey[700],
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildItemsList(List<MarketplaceItem> items) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_bag_outlined, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              "no_items_found".tr(),
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "adjust_filters".tr(),
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) => _buildItemCard(items[index]),
    );
  }

  Widget _buildItemCard(MarketplaceItem item) {
    final isFavorite = _isFavorite(item);
    final isOwner = _isOwner(item);

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
                child: _buildItemImage(item),
              ),
              if (!item.isAvailable)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    color: Colors.black54,
                    child: const Center(
                      child: Text(
                        'VENDU',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
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
                  child: Text(
                    item.formattedPrice,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
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
                  child: Text(
                    item.categoryLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
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
                            item.title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.location,
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
                            color: item.likedBy.isNotEmpty ? Colors.red : Colors.grey,
                          ),
                          onPressed: () => _toggleLike(item),
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(),
                        ),
                        IconButton(
                          icon: Icon(
                            isFavorite ? Icons.bookmark : Icons.bookmark_border,
                            color: isFavorite ? Colors.blue : Colors.grey,
                          ),
                          onPressed: () => _toggleFavorite(item),
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  item.description,
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildInfoChip(Icons.category, item.categoryLabel),
                    _buildInfoChip(Icons.construction, item.conditionLabel),
                    _buildInfoChip(Icons.favorite, '${item.likes}'),
                    if (item.images.isNotEmpty)
                      _buildInfoChip(Icons.photo, '${item.images.length}'),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    // CORRECTION : Utilisation de la nouvelle méthode _buildSellerAvatar
                    _buildSellerAvatar(item.sellerPhoto, item.sellerName),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.sellerName,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 20,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isOwner) ...[
                      IconButton(
                        icon: Icon(
                          item.isAvailable ? Icons.check_circle : Icons.cancel,
                          color: item.isAvailable ? Colors.green : Colors.red,
                          size: 20,
                        ),
                        onPressed: () => _toggleAvailability(item),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 36),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, size: 20),
                        onPressed: () => _deleteItem(item),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 36),
                      ),
                    ],
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => _showItemDetails(item),
                      child: Text("details".tr()),
                    ),
                  ],
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

  List<MarketplaceItem> _filterItems() {
    switch (_selectedCategory) {
      case "tools":
        return _items.where((item) => item.category == "tools").toList();
      case "baits":
        return _items.where((item) => item.category == "baits").toList();
      case "fresh_fish":
        return _items.where((item) => item.category == "fresh_fish").toList();
      case "favorites":
        return _favoriteItems;
      default:
        return _items;
    }
  }

  void _searchItems() {
    showSearch(
      context: context,
      delegate: _ItemSearchDelegate(_items),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("filter_items".tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.arrow_upward),
              title: Text("price_low_to_high".tr()),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _items.sort((a, b) => a.price.compareTo(b.price));
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.arrow_downward),
              title: Text("price_high_to_low".tr()),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _items.sort((a, b) => b.price.compareTo(a.price));
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
                  _items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
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

  void _showItemDetails(MarketplaceItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ItemDetailsSheet(
        item: item,
        imageService: _imageService,
        isOwner: _isOwner(item),
        onToggleAvailability: () => _toggleAvailability(item),
        onDelete: () => _deleteItem(item),
      ),
    );
  }

  Future<void> _deleteItem(MarketplaceItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("delete_item".tr()),
        content: Text("delete_item_confirm".tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("cancel".tr()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text("delete".tr()),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _marketplaceService.deleteItem(item.id);
        _showSuccess('Article supprimé');
      } catch (e) {
        _showError('Erreur: $e');
      }
    }
  }

  void _addNewItem() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddMarketplaceItemScreen()),
    );
  }
}

class _ItemDetailsSheet extends StatelessWidget {
  final MarketplaceItem item;
  final ImageService imageService;
  final bool isOwner;
  final VoidCallback onToggleAvailability;
  final VoidCallback onDelete;

  const _ItemDetailsSheet({
    required this.item,
    required this.imageService,
    required this.isOwner,
    required this.onToggleAvailability,
    required this.onDelete,
  });

  Widget _buildSellerAvatar(String sellerPhoto, String sellerName) {
    if (sellerPhoto.isNotEmpty) {
      return CircleAvatar(
        radius: 16,
        backgroundImage: NetworkImage(sellerPhoto),
        onBackgroundImageError: (exception, stackTrace) {
          print('Erreur chargement photo vendeur: $exception');
        },
        child: const Icon(Icons.person, size: 16),
      );
    } else {
      return CircleAvatar(
        radius: 16,
        backgroundColor: Colors.grey[300],
        child: const Icon(Icons.person, size: 16, color: Colors.grey),
      );
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

          // Images
          if (item.images.isNotEmpty) ...[
            SizedBox(
              height: 200,
              child: PageView.builder(
                itemCount: item.images.length,
                itemBuilder: (context, index) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      image: DecorationImage(
                        image: MemoryImage(
                          imageService.base64ToImage(item.images[index].base64Data),
                        ),
                        fit: BoxFit.cover,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Titre et prix
          Row(
            children: [
              Expanded(
                child: Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                item.formattedPrice,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Localisation et vendeur
          Row(
            children: [
              const Icon(Icons.location_on, size: 16, color: Colors.grey),
              const SizedBox(width: 4),
              Text(item.location),
              const Spacer(),
              _buildSellerAvatar(item.sellerPhoto, item.sellerName),
              const SizedBox(width: 4),
              Text(item.sellerName),
            ],
          ),

          const SizedBox(height: 16),

          // Description
          Text(
            "description".tr(),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(item.description),

          const SizedBox(height: 16),

          // Détails
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildDetailChip(Icons.category, item.categoryLabel),
              _buildDetailChip(Icons.construction, item.conditionLabel),
              _buildDetailChip(Icons.favorite, '${item.likes} likes'),
              if (!item.isAvailable)
                _buildDetailChip(Icons.cancel, 'Vendu', color: Colors.red),
            ],
          ),

          const SizedBox(height: 20),

          // Actions
          if (isOwner) ...[
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onToggleAvailability,
                    icon: Icon(
                      item.isAvailable ? Icons.cancel : Icons.check_circle,
                    ),
                    label: Text(
                      item.isAvailable ? "mark_sold".tr() : "mark_available".tr(),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: item.isAvailable ? Colors.orange : Colors.green,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete),
                  label: Text("delete".tr()),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],

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

  Widget _buildDetailChip(IconData icon, String text, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color ?? Colors.blue[50],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color ?? Colors.blue[700]),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color ?? Colors.blue[700],
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemSearchDelegate extends SearchDelegate {
  final List<MarketplaceItem> items;

  _ItemSearchDelegate(this.items);

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
    final results = items.where((item) =>
    item.title.toLowerCase().contains(query.toLowerCase()) ||
        item.description.toLowerCase().contains(query.toLowerCase()) ||
        item.categoryLabel.toLowerCase().contains(query.toLowerCase())).toList();

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) => ListTile(
        leading: results[index].hasImages
            ? Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            image: DecorationImage(
              image: MemoryImage(
                // Note: Vous devrez injecter ImageService ici
                // Pour l'instant, on utilise une image par défaut
                // Vous pouvez adapter cette partie selon vos besoins
                Uint8List(0), // Placeholder
              ),
              fit: BoxFit.cover,
            ),
          ),
        )
            : const Icon(Icons.shopping_bag),
        title: Text(results[index].title),
        subtitle: Text(results[index].formattedPrice),
        trailing: Text(results[index].categoryLabel),
        onTap: () {
          close(context, results[index]);
        },
      ),
    );
  }
}