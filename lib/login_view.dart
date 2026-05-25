import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'main.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isGoogleLoading = false; // 🍋 Separate loader just for Google button
  bool _isLoginMode = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _generateSecureSecret() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%';
    return List.generate(
        16, (index) => chars[Random.secure().nextInt(chars.length)]).join();
  }

  // ==========================================
  // 🍋 GOOGLE SIGN-IN (NOW ACTUALLY CONNECTED)
  // ==========================================
  Future<void> _signInWithGoogle() async {
    setState(() => _isGoogleLoading = true);

    try {
      // Step 1: Open the Google account picker
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

      // User cancelled — just stop loading, no error
      if (googleUser == null) {
        setState(() => _isGoogleLoading = false);
        return;
      }

      // Step 2: Get auth tokens from Google
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken, // ← idToken alone is sufficient
      );

      // Step 4: Sign in to Firebase
      final UserCredential userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);

      final user = userCredential.user!;
      final isNewUser =
          userCredential.additionalUserInfo?.isNewUser ?? false;

      if (isNewUser) {
        // First time Google login — create their Firestore profile
        final displayName = user.displayName ?? 'Lemon User';
        String autoUsername = (user.email ?? 'user')
            .split('@')
            .first
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9]'), '');

        // Make sure auto-generated username is unique
        final usernameCheck = await FirebaseFirestore.instance
            .collection('users')
            .where('username', isEqualTo: autoUsername)
            .limit(1)
            .get();

        if (usernameCheck.docs.isNotEmpty) {
          autoUsername += Random().nextInt(999).toString();
        }

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({
          'fullName': displayName,
          'username': autoUsername,
          'email': user.email ?? '',
          'profileImageUrl': user.photoURL ?? '',
          'createdAt': DateTime.now(),
          'totalEntries': 0,
        });
      }

      if (!mounted) return;

      // Navigate to the main screen
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 600),
          pageBuilder: (context, animation, secondaryAnimation) =>
              const MainScreen(),
          transitionsBuilder:
              (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    } catch (e) {
      print('=== GOOGLE SIGN-IN ERROR: $e ===');
      if (mounted) {
        setState(() => _isGoogleLoading = false);
        _showError('Google sign-in failed. Please try again.');
      }
    }
  }

  // ==========================================
  // 🍋 USERNAME / EMAIL SIGN-IN
  // ==========================================
  void _submitAuth() async {
    final String usernameInput =
        _usernameController.text.trim().toLowerCase();
    final String emailInput = _emailController.text.trim();
    final String passwordInput = _passwordController.text.trim();

    if (_isLoginMode && (usernameInput.isEmpty || passwordInput.isEmpty)) {
      _showError('Please enter both your username and password.');
      return;
    }
    if (!_isLoginMode && emailInput.isEmpty) {
      _showError('Please enter your email address.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_isLoginMode) {
        // --- SIGN IN: Username → Firestore → Firebase Auth ---
        final userQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('username', isEqualTo: usernameInput)
            .limit(1)
            .get();

        if (userQuery.docs.isEmpty) {
          throw FirebaseAuthException(
              code: 'user-not-found',
              message: 'Username does not exist.');
        }

        final userData = userQuery.docs.first.data();
        final String dynamicEmail = userData['email'];

        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: dynamicEmail,
          password: passwordInput,
        );

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 600),
            pageBuilder: (context, animation, secondaryAnimation) =>
                const MainScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
        );
      } else {
        // --- SIGN UP ---
        String derivedUsername = emailInput
            .split('@')
            .first
            .replaceAll(RegExp(r'[^\w]'), '')
            .toLowerCase();
        if (derivedUsername.isEmpty) derivedUsername = 'lemonuser';

        final uniquenessCheck = await FirebaseFirestore.instance
            .collection('users')
            .where('username', isEqualTo: derivedUsername)
            .get();

        if (uniquenessCheck.docs.isNotEmpty) {
          derivedUsername += Random().nextInt(999).toString();
        }

        final String registrationPassword = passwordInput.isNotEmpty
            ? passwordInput
            : _generateSecureSecret();

        UserCredential userCredential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
                email: emailInput, password: registrationPassword);

        await userCredential.user?.updateDisplayName(derivedUsername);

        await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .set({
          'fullName': derivedUsername,
          'username': derivedUsername,
          'email': emailInput,
          'createdAt': DateTime.now(),
          'totalEntries': 0,
        });

        await FirebaseAuth.instance.signOut();

        if (!mounted) return;

        setState(() {
          _isLoading = false;
          _isLoginMode = true;
          _emailController.clear();
          _passwordController.clear();
          _usernameController.text = derivedUsername;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Account ready as @$derivedUsername! Use your email password to sign in. 🍋'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _isLoading = false);
      String errorMessage =
          'Authentication failed. Please verify credentials.';
      if (e.code == 'user-not-found' ||
          e.code == 'wrong-password' ||
          e.code == 'invalid-credential') {
        errorMessage = 'Incorrect username or password.';
      } else if (e.code == 'email-already-in-use') {
        errorMessage = 'This email address is already registered.';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'Please enter a valid email format.';
      }
      _showError(errorMessage);
    } catch (e) {
      setState(() => _isLoading = false);
      print('=== CRUCIAL LOGIN ERROR LOG: $e ===');
      _showError('Something went wrong. Please check your console.');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('🍋',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 54)),
                const SizedBox(height: 16),
                Text(
                  _isLoginMode ? 'Welcome back' : 'Create Account',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                      letterSpacing: -0.3),
                ),
                const SizedBox(height: 4),
                Text(
                  _isLoginMode
                      ? 'Sign in to access your journal'
                      : 'Get started with just your email',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 36),

                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  reverseDuration: const Duration(milliseconds: 150),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder:
                      (Widget child, Animation<double> animation) {
                    final offsetAnimation = Tween<Offset>(
                            begin: const Offset(0.0, 0.08), end: Offset.zero)
                        .animate(animation);
                    return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                            position: offsetAnimation, child: child));
                  },
                  child: _isLoginMode
                      ? Column(
                          key: const ValueKey('login_fields_key'),
                          children: [
                            TextField(
                              controller: _usernameController,
                              enabled: !_isLoading,
                              style: const TextStyle(fontSize: 14),
                              decoration: InputDecoration(
                                labelText: 'Username',
                                prefixText: '@ ',
                                prefixStyle: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87),
                                filled: true,
                                fillColor: Colors.grey[50],
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide.none),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _passwordController,
                              obscureText: true,
                              enabled: !_isLoading,
                              style: const TextStyle(fontSize: 14),
                              decoration: InputDecoration(
                                labelText: 'Password',
                                filled: true,
                                fillColor: Colors.grey[50],
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide.none),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          key: const ValueKey('register_fields_key'),
                          children: [
                            TextField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              enabled: !_isLoading,
                              style: const TextStyle(fontSize: 14),
                              decoration: InputDecoration(
                                labelText: 'Email Address',
                                filled: true,
                                fillColor: Colors.grey[50],
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide.none),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ),
                ),
                const SizedBox(height: 24),

                ElevatedButton(
                  onPressed: _isLoading ? null : _submitAuth,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.yellow[600],
                    disabledBackgroundColor: Colors.yellow[200],
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              color: Colors.black54, strokeWidth: 2.5))
                      : Text(_isLoginMode ? 'Sign In' : 'Sign Up',
                          style: const TextStyle(
                              color: Colors.black,
                              fontSize: 15,
                              fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 12),

                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          setState(() {
                            _isLoginMode = !_isLoginMode;
                            _usernameController.clear();
                            _emailController.clear();
                            _passwordController.clear();
                          });
                        },
                  child: Text(
                    _isLoginMode
                        ? "Don't have an account? Sign Up"
                        : "Already have an account? Sign In",
                    style: TextStyle(
                        color: Colors.yellow[800],
                        fontWeight: FontWeight.w700,
                        fontSize: 13),
                  ),
                ),
                const SizedBox(height: 24),

                Row(
                  children: [
                    Expanded(
                        child:
                            Divider(color: Colors.grey[100], thickness: 1.5)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('or',
                          style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                    ),
                    Expanded(
                        child:
                            Divider(color: Colors.grey[100], thickness: 1.5)),
                  ],
                ),
                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 🍋 Google button now calls _signInWithGoogle!
                    _buildSocialButton(
                      imagePath: 'assets/logos/google_logo.png',
                      backgroundColor: Colors.white,
                      borderColor: Colors.grey[100]!,
                      isLoading: _isGoogleLoading,
                      onTap: (_isGoogleLoading || _isLoading)
                          ? null
                          : _signInWithGoogle,
                    ),
                    const SizedBox(width: 12),
                    _buildSocialButton(
                      imagePath: 'assets/logos/apple_logo.png',
                      backgroundColor: Colors.black,
                      borderColor: Colors.black,
                      onTap: () => print("Apple"),
                    ),
                    const SizedBox(width: 12),
                    _buildSocialButton(
                      imagePath: 'assets/logos/facebook_logo.png',
                      backgroundColor: const Color(0xFF1877F2),
                      borderColor: const Color(0xFF1877F2),
                      onTap: () => print("Facebook"),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSocialButton({
    required String imagePath,
    required Color backgroundColor,
    required Color borderColor,
    VoidCallback? onTap,
    bool isLoading = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 54,
        height: 44,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border.all(color: borderColor, width: 1.2),
          borderRadius: BorderRadius.circular(10),
        ),
        // 🍋 Shows a spinner inside the button while Google is loading
        child: isLoading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: backgroundColor == Colors.white
                      ? Colors.black54
                      : Colors.white,
                ),
              )
            : Image.asset(imagePath, fit: BoxFit.contain),
      ),
    );
  }
}