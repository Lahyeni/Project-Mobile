import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  final confirmPassword = TextEditingController();
  final auth = AuthService();

  bool loading = false;

  void showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> register() async {
    final emailText = email.text.trim();
    final pass = password.text.trim();
    final confirm = confirmPassword.text.trim();

    if (emailText.isEmpty || pass.isEmpty || confirm.isEmpty) {
      showError("fill_all_fields".tr());
      return;
    }

    if (pass.length < 6) {
      showError("Le mot de passe doit contenir au moins 6 caractères");
      return;
    }

    if (pass != confirm) {
      showError("passwords_not_match".tr());
      return;
    }

    if (!emailText.contains('@')) {
      showError("Veuillez entrer un email valide");
      return;
    }

    try {
      setState(() => loading = true);

      await auth.signup(emailText, pass);

      if (!mounted) return;
      showSuccess("Compte créé avec succès!");

      await Future.delayed(const Duration(seconds: 1));

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } catch (e) {
      showError(e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.lightBlue.shade600),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.lightBlue.shade400),
      ),
      filled: true,
      fillColor: Colors.white,
    );
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    confirmPassword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SizedBox.expand(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.lightBlue.shade100,
                Colors.lightGreen.shade100,
              ],
              stops: const [0.0, 0.8],
            ),
          ),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Logo (same style as login)
                            Container(
                              width: 170,
                              height: 170,
                              decoration: const BoxDecoration(shape: BoxShape.circle),
                              child: ClipOval(
                                child: Image.asset(
                                  'lib/assets/fish.png',
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: Colors.lightBlue.shade100,
                                      child: Icon(
                                        Icons.phishing,
                                        size: 50,
                                        color: Colors.lightBlue.shade800,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),

                            const SizedBox(height: 18),

                            Card(
                              elevation: 8,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      "signup".tr(),
                                      style: const TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.lightBlue,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      "create_account".tr(),
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey[600],
                                      ),
                                      textAlign: TextAlign.center,
                                    ),

                                    const SizedBox(height: 22),

                                    TextField(
                                      controller: email,
                                      keyboardType: TextInputType.emailAddress,
                                      decoration: _inputDecoration(
                                        label: "email".tr(),
                                        icon: Icons.email,
                                      ),
                                    ),

                                    const SizedBox(height: 16),

                                    TextField(
                                      controller: password,
                                      obscureText: true,
                                      decoration: _inputDecoration(
                                        label: "password".tr(),
                                        icon: Icons.lock,
                                      ),
                                    ),

                                    const SizedBox(height: 16),

                                    TextField(
                                      controller: confirmPassword,
                                      obscureText: true,
                                      decoration: _inputDecoration(
                                        label: "confirm_password".tr(),
                                        icon: Icons.lock_outline,
                                      ),
                                      onSubmitted: (_) => register(),
                                    ),

                                    const SizedBox(height: 22),

                                    ElevatedButton(
                                      onPressed: loading ? null : register,
                                      style: ElevatedButton.styleFrom(
                                        minimumSize: const Size(double.infinity, 50),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        backgroundColor: Colors.lightGreen.shade500,
                                        foregroundColor: Colors.white,
                                        elevation: 3,
                                      ),
                                      child: loading
                                          ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                          : Text(
                                        "signup".tr(),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),

                                    const SizedBox(height: 16),

                                    TextButton(
                                      onPressed: loading
                                          ? null
                                          : () {
                                        Navigator.pushReplacement(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => const LoginScreen(),
                                          ),
                                        );
                                      },
                                      child: RichText(
                                        text: TextSpan(
                                          style: TextStyle(
                                            color: Colors.grey[700],
                                            fontSize: 14,
                                          ),
                                          children: [
                                            TextSpan(text: "already_have_account".tr()),
                                            TextSpan(
                                              text: " ${"login".tr()}",
                                              style: TextStyle(
                                                color: Colors.lightBlue.shade700,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
