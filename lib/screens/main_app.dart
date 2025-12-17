import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'feed_screen.dart';
import 'profile_screen.dart';
import 'map_screen.dart';
import 'marketplace_screen.dart';

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  int _currentIndex = 0;

  // Méthode sécurisée pour obtenir l'écran actuel
  Widget _getCurrentScreen() {
    try {
      switch (_currentIndex) {
        case 0:
          return const FeedScreen();
        case 1:
          return const MapScreen();
        case 2:
          return const MarketplaceScreen();
        case 3:
          return const ProfileScreen();
        default:
          return _buildErrorScreen('Index invalide: $_currentIndex');
      }
    } catch (e) {
      return _buildErrorScreen('Erreur: $e');
    }
  }

  // Écran d'erreur en cas de problème - MÉTHODE AJOUTÉE
  Widget _buildErrorScreen(String message) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Erreur'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'Erreur de navigation',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _currentIndex = 0; // Retour au feed
                });
              },
              child: const Text('Retour au feed'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _getCurrentScreen(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          // Validation de l'index
          if (index >= 0 && index <= 3) {
            setState(() {
              _currentIndex = index;
            });
          } else {
            print('Index invalide: $index');
            setState(() {
              _currentIndex = 0; // Retour à l'écran principal
            });
          }
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home),
            label: "feed".tr(),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.map),
            label: "spots".tr(),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.shopping_bag),
            label: "marketplace".tr(),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person),
            label: "profile".tr(),
          ),
        ],
      ),
    );
  }
}