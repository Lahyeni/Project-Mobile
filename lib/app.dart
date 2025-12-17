import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'theme/light_theme.dart';
import 'theme/dark_theme.dart';
import 'screens/login_screen.dart';

class FisherSpace extends StatelessWidget {
  const FisherSpace({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "FisherSpace",
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.system,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      home: const LoginScreen(),
    );
  }
}
