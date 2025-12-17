import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/auth_service.dart';
import '../services/face_service.dart';
import 'main_app.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final email = TextEditingController();
  final password = TextEditingController();
  final auth = AuthService();
  final FaceService faceService = FaceService();

  bool loading = false;
  bool faceLoading = false;
  bool faceVerified = false;
  bool showFaceVerificationFirst = true;

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

  Future<void> login() async {
    final emailText = email.text.trim();
    final pass = password.text.trim();

    if (!faceVerified) {
      showError("Please verify your face first before logging in.");
      return;
    }

    if (emailText.isEmpty || pass.isEmpty) {
      showError("fill_all_fields".tr());
      return;
    }

    try {
      setState(() => loading = true);
      await auth.login(emailText, pass);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainApp()),
      );
    } catch (e) {
      showError(e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> verifyFace() async {
    try {
      setState(() => faceLoading = true);

      final bool faceDetected = await faceService.detectFaceFromCamera();

      if (faceDetected) {
        setState(() {
          faceVerified = true;
          showFaceVerificationFirst = false;
        });
        showSuccess("Face verified successfully! You can now login.");
      } else {
        setState(() => faceVerified = false);
        showError("Face verification failed. Please try again.");
      }
    } catch (e) {
      setState(() => faceVerified = false);
      showError("Face verification failed: ${e.toString()}");
    } finally {
      if (mounted) setState(() => faceLoading = false);
    }
  }

  void resetFaceVerification() {
    setState(() {
      faceVerified = false;
      showFaceVerificationFirst = true;
    });
  }

  @override
  void dispose() {
    faceService.dispose();
    email.dispose();
    password.dispose();
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
                  // keeps scrolling on small screens/keyboard, but still allows centering
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Logo
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
                                  // IMPORTANT: shrink wrap content (prevents extra empty space)
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      "login".tr(),
                                      style: const TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.lightBlue,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      "welcome_back".tr(),
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey[600],
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 22),

                                    // FIX: Use AnimatedSize so the card height follows the current section
                                    AnimatedSize(
                                      duration: const Duration(milliseconds: 250),
                                      curve: Curves.easeInOut,
                                      alignment: Alignment.topCenter,
                                      child: showFaceVerificationFirst
                                          ? _buildFaceVerificationSection()
                                          : _buildLoginFormSection(),
                                    ),

                                    // Only keep spacing + signup on login step
                                    if (!showFaceVerificationFirst) ...[
                                      const SizedBox(height: 20),
                                      TextButton(
                                        onPressed: loading
                                            ? null
                                            : () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => const SignupScreen(),
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
                                              TextSpan(text: "dont_have_account".tr()),
                                              TextSpan(
                                                text: " ${"sign_up".tr()}",
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

  Widget _buildFaceVerificationSection() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: faceVerified ? Colors.green.shade50 : Colors.orange.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: faceVerified ? Colors.green.shade200 : Colors.orange.shade200,
            ),
          ),
          child: Row(
            children: [
              Icon(
                faceVerified ? Icons.verified : Icons.face_retouching_off,
                color: faceVerified ? Colors.green : Colors.orange,
                size: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      faceVerified ? "Face Verified" : "Face Verification Required",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: faceVerified
                            ? Colors.green.shade800
                            : Colors.orange.shade800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      faceVerified
                          ? "You can now proceed to login"
                          : "Please verify your face to continue",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        ElevatedButton.icon(
          onPressed: faceLoading ? null : verifyFace,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            backgroundColor:
            faceVerified ? Colors.green.shade100 : Colors.lightBlue.shade50,
            foregroundColor:
            faceVerified ? Colors.green.shade800 : Colors.lightBlue.shade800,
            elevation: 2,
          ),
          icon: faceLoading
              ? const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
              : Icon(faceVerified ? Icons.check_circle : Icons.face),
          label: faceLoading
              ? Text("scanning_face".tr())
              : Text(faceVerified ? "face_verified".tr() : "verify_face".tr()),
        ),

        if (faceVerified) ...[
          const SizedBox(height: 10),
          TextButton(
            onPressed: () {
              setState(() {
                showFaceVerificationFirst = false;
              });
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("proceed_to_login".tr()),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward, size: 16),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLoginFormSection() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: resetFaceVerification,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified, color: Colors.green, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Face Verified",
                    style: TextStyle(
                      color: Colors.green.shade800,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: resetFaceVerification,
                  child: Text(
                    "change".tr(),
                    style: TextStyle(color: Colors.lightBlue.shade700),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(child: Divider(color: Colors.grey[300])),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                "enter_credentials".tr(),
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
            Expanded(child: Divider(color: Colors.grey[300])),
          ],
        ),

        const SizedBox(height: 16),

        TextField(
          controller: email,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: "email".tr(),
            prefixIcon: Icon(Icons.email, color: Colors.lightBlue.shade600),
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
          ),
        ),

        const SizedBox(height: 16),

        TextField(
          controller: password,
          obscureText: true,
          decoration: InputDecoration(
            labelText: "password".tr(),
            prefixIcon: Icon(Icons.lock, color: Colors.lightBlue.shade600),
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
          ),
          onSubmitted: (_) => login(),
        ),

        const SizedBox(height: 22),

        ElevatedButton(
          onPressed: (loading || !faceVerified) ? null : login,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            backgroundColor:
            faceVerified ? Colors.lightGreen.shade500 : Colors.grey.shade300,
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
            "login".tr(),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        if (!faceVerified) ...[
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: resetFaceVerification,
            icon: const Icon(Icons.warning, size: 16),
            label: Text(
              "face_verification_required".tr(),
              style: TextStyle(color: Colors.orange.shade700),
            ),
          ),
        ],
      ],
    );
  }
}
