import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'main.dart'; 

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  // Controllers for user input
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isLoginMode = true; 

  // Clean up memory when this screen is closed
  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // --- FIREBASE EMAIL/PASSWORD AUTHENTICATION ---
  void _submitAuth() async {
    final String name = _nameController.text.trim();
    final String username = _usernameController.text.trim();
    final String email = _emailController.text.trim();
    final String password = _passwordController.text.trim();

    // Validation: Require all fields if they are signing up!
    if (email.isEmpty || password.isEmpty || (!_isLoginMode && (name.isEmpty || username.isEmpty))) {
      _showError('Please fill in all required fields.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (_isLoginMode) {
        // --- LOG IN MODE ---
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      } else {
        // --- SIGN UP MODE ---
        UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        
        // Immediately update their Firebase profile with their new Username!
        await userCredential.user?.updateDisplayName(username);

        // Create their permanent database folder
        await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
          'fullName': name,
          'username': username,
          'email': email,
          'createdAt': DateTime.now(), 
          'totalEntries': 0, 
        });
      }

      if (!mounted) return;

      // Success! Navigate to the dashboard
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 600),
          pageBuilder: (context, animation, secondaryAnimation) => const MainScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );

    } on FirebaseAuthException catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('FIREBASE ERROR CODE: ${e.code}');

      String errorMessage = 'An error occurred. Please try again.';
      if (e.code == 'user-not-found') {
        errorMessage = 'No user found for that email.';
      } else if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        errorMessage = 'Incorrect email or password.';
      } else if (e.code == 'email-already-in-use') {
        errorMessage = 'An account already exists for that email.';
      } else if (e.code == 'weak-password') {
        errorMessage = 'The password provided is too weak (min 6 characters).';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'Please enter a valid email address.';
      }

      _showError(errorMessage);
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showError('Something went wrong. Please try again.');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
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
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // --- Header ---
                Icon(Icons.sentiment_satisfied_alt, size: 100, color: Colors.yellow[700]),
                const SizedBox(height: 24),
                Text(
                  _isLoginMode ? 'Welcome back' : 'Create an Account',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  _isLoginMode ? 'Sign in to track your moods' : 'Tell us a bit about yourself',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
                const SizedBox(height: 48),

                // --- Dynamic Extra Fields (Only show if signing up!) ---
                if (!_isLoginMode) ...[
                  TextField(
                    controller: _nameController,
                    enabled: !_isLoading, 
                    decoration: InputDecoration(
                      labelText: 'Full Name',
                      filled: true,
                      fillColor: Colors.grey[50],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  TextField(
                    controller: _usernameController,
                    enabled: !_isLoading, 
                    decoration: InputDecoration(
                      labelText: 'Username',
                      filled: true,
                      fillColor: Colors.grey[50],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // --- Standard Email & Password Fields ---
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  enabled: !_isLoading, 
                  decoration: InputDecoration(
                    labelText: 'Email',
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  enabled: !_isLoading, 
                  decoration: InputDecoration(
                    labelText: 'Password',
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 32),

                // --- Main Action Button ---
                ElevatedButton(
                  onPressed: _isLoading ? null : _submitAuth,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.yellow[600],
                    disabledBackgroundColor: Colors.yellow[300], 
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24, width: 24,
                          child: CircularProgressIndicator(color: Colors.black54, strokeWidth: 3),
                        )
                      : Text(
                          _isLoginMode ? 'Sign In' : 'Sign Up',
                          style: const TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                ),
                const SizedBox(height: 16),

                // --- The Mode Toggle ---
                TextButton(
                  onPressed: _isLoading 
                      ? null 
                      : () {
                          setState(() {
                            _isLoginMode = !_isLoginMode;
                            _nameController.clear();
                            _usernameController.clear();
                          });
                        },
                  child: Text(
                    _isLoginMode ? "Don't have an account? Sign Up" : "Already have an account? Sign In",
                    style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 32), // Increased spacing for visual separation

                // --- OR Divider ---
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.grey[300], thickness: 1)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text('Or continue with', style: TextStyle(color: Colors.grey[600])),
                    ),
                    Expanded(child: Divider(color: Colors.grey[300], thickness: 1)),
                  ],
                ),
                const SizedBox(height: 24),

                // 🍋 --- Social Login Buttons (Redesigned to match image_7.png!) ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.center, // Center the row
                  children: [
                    // 🍋 Google Button: Now full color 'G' on white background with grey border
                    _buildSocialButton(
                      imagePath: 'assets/logos/google_logo.png', // Requires image asset!
                      backgroundColor: Colors.white,
                      borderColor: Colors.grey[200]!, // Subtle grey border like in the image
                      onTap: () {
                        print("Google Login Tapped!");
                      },
                    ),
                    const SizedBox(width: 16), // Sizing between buttons
                    
                    // 🍋 Apple Button: Solid black background with white logo
                    _buildSocialButton(
                      imagePath: 'assets/logos/apple_logo.png', // Requires image asset!
                      backgroundColor: Colors.black,
                      borderColor: Colors.black, // Match border to background
                      onTap: () {
                        print("Apple Login Tapped!");
                      },
                    ),
                    const SizedBox(width: 16),

                    // 🍋 Facebook Button: Solid brand blue background with white 'f' logo
                    _buildSocialButton(
                      imagePath: 'assets/logos/facebook_logo.png', // Requires image asset!
                      backgroundColor: const Color(0xFF1877F2), // Official Facebook Blue
                      borderColor: const Color(0xFF1877F2), // Match border to background
                      onTap: () {
                        print("Facebook Login Tapped!");
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 🍋 --- REFACTORED Social Button Helper ---
  // Now uses images, handles aspect ratios, and custom coloring to match image_7.png exactly.
  Widget _buildSocialButton({
    required String imagePath,
    required Color backgroundColor,
    required Color borderColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12), // Matching the rectangular look in image_7.png
      child: Container(
        // Set fixed width/height to make perfect square buttons
        width: 60, 
        height: 50,
        padding: const EdgeInsets.all(12), // Inner padding for the logo
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border.all(color: borderColor, width: 1.5),
          borderRadius: BorderRadius.circular(12), // Rounded corners like the reference
        ),
        // We use Image.asset now instead of Icon!
        child: Image.asset(
          imagePath,
          fit: BoxFit.contain, // Ensures the full logo fits inside the container
          // Note: Standard images like the Google 'G' don't need a color property.
          // For Apple/Facebook (white logos), ensure the PNG asset you have is white on a transparent background.
        ),
      ),
    );
  }
}