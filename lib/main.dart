import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';

// Services
import 'services/auth_service.dart';
import 'services/user_service.dart';
import 'services/post_service.dart';
import 'services/spot_service.dart';
import 'services/marketplace_service.dart';
import 'services/image_service.dart';

// Screens
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/feed_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/map_screen.dart';
import 'screens/marketplace_screen.dart';
import 'screens/create_post_screen.dart';
import 'screens/add_spot_screen.dart';
import 'screens/add_marketplace_item_screen.dart';
import 'screens/edit_profile_screen.dart';
import 'screens/settings_screen.dart';

// Theme
import 'theme/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await EasyLocalization.ensureInitialized();

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('fr')],
      path: 'lib/translations', // CORRECTION: Chemin correct
      fallbackLocale: const Locale('en'),
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          Provider(create: (_) => AuthService()),
          Provider(create: (_) => UserService()),
          Provider(create: (_) => PostService()),
          Provider(create: (_) => SpotService()),
          Provider(create: (_) => MarketplaceService()),
          Provider(create: (_) => ImageService()),
        ],
        child: const MyApp(),
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'Fisher Community',
          theme: themeProvider.currentTheme,
          darkTheme: ThemeData.dark(),
          themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          initialRoute: '/',
          routes: {
            '/': (context) => const AuthWrapper(),
            '/login': (context) => const LoginScreen(),
            '/signup': (context) => const SignupScreen(),
            '/feed': (context) => const FeedScreen(),
            '/profile': (context) => const ProfileScreen(),
            '/map': (context) => const MapScreen(),
            '/marketplace': (context) => const MarketplaceScreen(),
            '/create_post': (context) => const CreatePostScreen(),
            '/add_spot': (context) => const AddSpotScreen(),
            '/add_marketplace_item': (context) => const AddMarketplaceItemScreen(),
            '/edit_profile': (context) => const EditProfileScreen(),
            '/settings': (context) => const SettingsScreen(),
          },
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final AuthService _authService = AuthService();
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final user = snapshot.data;

        if (user == null) {
          return const LoginScreen();
        }

        return Scaffold(
          body: _getCurrentScreen(),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            type: BottomNavigationBarType.fixed,
            items: [
              BottomNavigationBarItem(
                icon: const Icon(Icons.home),
                label: 'feed'.tr(),
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.map),
                label: 'spots'.tr(),
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.shopping_bag),
                label: 'marketplace'.tr(),
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.person),
                label: 'profile'.tr(),
              ),
            ],
          ),
          floatingActionButton: _buildFloatingActionButton(),
        );
      },
    );
  }

  Widget? _buildFloatingActionButton() {
    switch (_currentIndex) {
      case 0:
        return FloatingActionButton(
          onPressed: () => Navigator.pushNamed(context, '/create_post'),
          child: const Icon(Icons.add),
        );
      case 1:
        return FloatingActionButton(
          onPressed: () => Navigator.pushNamed(context, '/add_spot'),
          child: const Icon(Icons.add_location),
        );
      case 2:
        return FloatingActionButton(
          onPressed: () => Navigator.pushNamed(context, '/add_marketplace_item'),
          child: const Icon(Icons.add),
        );
      default:
        return null;
    }
  }

  Widget _getCurrentScreen() {
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
        return const FeedScreen();
    }
  }
}