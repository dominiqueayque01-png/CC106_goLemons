import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'login_view.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  File? _selectedImage;
  // 🍋 NEW: Track the loading state for signing out!
  bool _isSigningOut = false;

  Future<void> _pickProfilePicture() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }

  // 🍋 NEW: The Confirmation Modal & Logout Logic
  Future<void> _handleSignOut() async {
    // 1. Show the dialog and wait for the user's choice
    final bool? shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.logout, color: Colors.redAccent),
              SizedBox(width: 8),
              Text('Sign Out'),
            ],
          ),
          content: const Text('Are you sure you want to sign out of goLemons?'),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(false), // User clicked Cancel
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.of(context).pop(true), // User clicked Sign Out
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Sign Out',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );

    // 2. If they clicked "Cancel" or tapped outside the box, stop here!
    if (shouldSignOut != true) return;

    // 3. Trigger the loading overlay
    setState(() {
      _isSigningOut = true;
    });

    // Optional: Add a tiny 800ms delay so the loading screen feels natural and not glitched
    await Future.delayed(const Duration(milliseconds: 800));

    // 4. Actually sign them out
    await FirebaseAuth.instance.signOut();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Successfully signed out. See you later! 🍋'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );

    // 5. Send them back to LoginView
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginView()),
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    // 🍋 NEW: Wrapped the SafeArea in a Stack to allow for the floating overlay!
    return Stack(
      children: [
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Profile',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // --- User Profile Card ---
                        if (currentUser != null)
                          FutureBuilder<DocumentSnapshot>(
                            future: FirebaseFirestore.instance
                                .collection('users')
                                .doc(currentUser.uid)
                                .get(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.yellow,
                                  ),
                                );
                              }

                              if (snapshot.hasError ||
                                  !snapshot.hasData ||
                                  !snapshot.data!.exists) {
                                return const Center(
                                  child: Text('Could not load profile data.'),
                                );
                              }

                              final userData =
                                  snapshot.data!.data() as Map<String, dynamic>;
                              final fullName =
                                  userData['fullName'] ?? 'No Name';
                              final username =
                                  userData['username'] ?? 'No Username';
                              final email = userData['email'] ?? 'No Email';

                              return Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.grey[200]!),
                                ),
                                child: Column(
                                  children: [
                                    Stack(
                                      alignment: Alignment.bottomRight,
                                      children: [
                                        CircleAvatar(
                                          radius: 45,
                                          backgroundColor: Colors.yellow[100],
                                          backgroundImage:
                                              _selectedImage != null
                                              ? FileImage(_selectedImage!)
                                              : null,
                                          child: _selectedImage == null
                                              ? const Text(
                                                  '🍋',
                                                  style: TextStyle(
                                                    fontSize: 40,
                                                  ),
                                                )
                                              : null,
                                        ),
                                        GestureDetector(
                                          onTap: _pickProfilePicture,
                                          child: Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Colors.yellow[600],
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: Colors.white,
                                                width: 2,
                                              ),
                                            ),
                                            child: const Icon(
                                              Icons.camera_alt,
                                              size: 18,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      fullName,
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '@$username',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.yellow[800],
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      email,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        const SizedBox(height: 32),

                        // --- Your Stats Section ---
                        const Text(
                          'Your Stats',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),

                        if (currentUser != null)
                          StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('users')
                                .doc(currentUser.uid)
                                .collection('entries')
                                .snapshots(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.yellow,
                                  ),
                                );
                              }

                              final docs = snapshot.hasData
                                  ? snapshot.data!.docs
                                  : [];

                              final totalEntries = docs.length;

                              final daysLogged = docs
                                  .map((doc) {
                                    final d = (doc['date'] as Timestamp)
                                        .toDate();
                                    return DateTime(d.year, d.month, d.day);
                                  })
                                  .toSet()
                                  .length;

                              final tagsUsed = docs
                                  .expand((doc) {
                                    final data =
                                        doc.data() as Map<String, dynamic>;
                                    return (data['tags'] as List<dynamic>? ??
                                        []);
                                  })
                                  .toSet()
                                  .length;

                              return Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.grey[200]!),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    _buildStatColumn(
                                      totalEntries.toString(),
                                      'Total Entries',
                                    ),
                                    Container(
                                      height: 40,
                                      width: 1,
                                      color: Colors.grey[300],
                                    ),
                                    _buildStatColumn(
                                      daysLogged.toString(),
                                      'Days Logged',
                                    ),
                                    Container(
                                      height: 40,
                                      width: 1,
                                      color: Colors.grey[300],
                                    ),
                                    _buildStatColumn(
                                      tagsUsed.toString(),
                                      'Tags Used',
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        const SizedBox(height: 32),

                        // --- About Section ---
                        const Text(
                          'About',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'goLemons',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Track your moods, understand your patterns, and take care of your mental wellbeing.',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Version 1.0.0',
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),

                // --- Sticky Sign Out Button ---
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    // 🍋 NEW: Tied the button to our fresh _handleSignOut function!
                    onPressed: _isSigningOut ? null : _handleSignOut,
                    icon: const Icon(Icons.logout, color: Colors.redAccent),
                    label: const Text(
                      'Sign Out',
                      style: TextStyle(color: Colors.redAccent, fontSize: 16),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: Colors.redAccent),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // 🍋 NEW: The Loading Overlay that sits on top of everything!
        if (_isSigningOut)
          Container(
            color: Colors.white70, // Adds a nice white fade over the UI
            child: const Center(
              child: CircularProgressIndicator(
                color: Colors.yellow,
                strokeWidth: 4,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStatColumn(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }
}
