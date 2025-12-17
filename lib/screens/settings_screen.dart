import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../theme/theme_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();

  bool _isDarkMode = false;
  String _selectedLanguage = 'fr';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    // Charger les paramètres depuis les préférences utilisateur
    final user = _authService.getCurrentUser();
    if (user != null) {
      _userService.getUserProfile(user.uid).listen((profile) {
        if (profile != null && mounted) {
          setState(() {
            _isDarkMode = profile.isDarkMode;
            _selectedLanguage = profile.language;
          });
        }
      });
    }
  }

  Future<void> _updateDarkMode(bool value) async {
    final user = _authService.getCurrentUser();
    if (user == null) return;

    setState(() => _isDarkMode = value);

    // Mettre à jour dans Firebase
    await _userService.updateUserPreferences(
      uid: user.uid,
      isDarkMode: value,
    );

    // Mettre à jour le thème de l'application
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    themeProvider.setDarkMode(value);
  }

  Future<void> _updateLanguage(String language) async {
    final user = _authService.getCurrentUser();
    if (user == null) return;

    setState(() => _selectedLanguage = language);

    // Mettre à jour dans Firebase
    await _userService.updateUserPreferences(
      uid: user.uid,
      language: language,
    );

    // CORRECTION: Utiliser EasyLocalization pour changer la langue
    if (mounted) {
      final newLocale = language == 'fr' ? const Locale('fr') : const Locale('en');
      await context.setLocale(newLocale);

      // Forcer le rebuild de l'interface
      setState(() {});
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("logout".tr()),
        content: Text("logout_confirm".tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("cancel".tr()),
          ),
          ElevatedButton(
            onPressed: () {
              _authService.logout();
              Navigator.pop(context);
              Navigator.pop(context); // Retour à l'écran précédent
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text("logout".tr()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("settings".tr()),
      ),
      body: ListView(
        children: [
          // Apparence
          Card(
            margin: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    "appearance".tr(),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SwitchListTile(
                  title: Text("dark_mode".tr()),
                  value: _isDarkMode,
                  onChanged: _updateDarkMode,
                ),
              ],
            ),
          ),

          // Langue
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    "language".tr(),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // CORRECTION: Utiliser les traductions pour les langues
                RadioListTile<String>(
                  title: Text(languageName('fr')),
                  value: 'fr',
                  groupValue: _selectedLanguage,
                  onChanged: (value) => _updateLanguage(value!),
                ),
                RadioListTile<String>(
                  title: Text(languageName('en')),
                  value: 'en',
                  groupValue: _selectedLanguage,
                  onChanged: (value) => _updateLanguage(value!),
                ),
              ],
            ),
          ),

          // Compte
          Card(
            margin: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    "account".tr(),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.privacy_tip),
                  title: Text("privacy_policy".tr()),
                  onTap: () {
                    // Naviguer vers politique de confidentialité
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.help),
                  title: Text("help_support".tr()),
                  onTap: () {
                    // Naviguer vers aide
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.info),
                  title: Text("about".tr()),
                  onTap: () {
                    // Naviguer vers à propos
                  },
                ),
              ],
            ),
          ),

          // Déconnexion
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: _showLogoutDialog,
              icon: const Icon(Icons.logout),
              label: Text("logout".tr()),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // AJOUT: Méthode pour obtenir le nom de la langue traduit
  String languageName(String code) {
    switch (code) {
      case 'fr':
        return context.locale.languageCode == 'fr' ? 'Français' : 'French';
      case 'en':
        return context.locale.languageCode == 'fr' ? 'Anglais' : 'English';
      default:
        return code;
    }
  }
}