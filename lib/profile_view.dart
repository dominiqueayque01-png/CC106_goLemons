import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'login_view.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  File? _selectedImage;
  bool _isSigningOut = false;
  bool _isUploadingImage = false;
  bool _isPickerActive = false;

  Future<void> _pickProfilePicture() async {
    if (_isPickerActive) return;
    _isPickerActive = true;

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
          _isUploadingImage = true;
        });

        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          setState(() => _isUploadingImage = false);
          return;
        }

        final storageRef = FirebaseStorage.instance
            .ref()
            .child('profile_pictures')
            .child('${user.uid}.jpg');

        await storageRef.putFile(_selectedImage!);
        final downloadUrl = await storageRef.getDownloadURL();

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'profileImageUrl': downloadUrl});

        // BUG FIX #2: Clear _selectedImage after upload so NetworkImage takes
        // over with the freshly uploaded URL instead of keeping the stale local file.
        if (mounted) {
          setState(() {
            _selectedImage = null;
            _isUploadingImage = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile picture saved! 🍋'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Failed to pick or upload profile picture: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to open gallery or save picture.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      _isPickerActive = false;
      if (mounted && _isUploadingImage) {
        setState(() => _isUploadingImage = false);
      }
    }
  }

  void _showEditProfileSheet(String currentName, String currentUsername) {
    final TextEditingController nameController =
        TextEditingController(text: currentName);
    final TextEditingController usernameController =
        TextEditingController(text: currentUsername);
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Edit Profile',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 22),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Center(
                    child: TextButton.icon(
                      // BUG FIX #3: Use Future.microtask so the bottom sheet
                      // fully closes before the image picker opens, preventing
                      // a flicker or picker failure on some devices.
                      onPressed: () {
                        Navigator.pop(context);
                        Future.microtask(() => _pickProfilePicture());
                      },
                      icon: const Icon(
                        Icons.camera_alt,
                        color: Colors.black87,
                        size: 18,
                      ),
                      label: const Text(
                        'Change Profile Photo',
                        style: TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.yellow[50],
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  const Text(
                    'Full Name',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: nameController,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.grey[50],
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  const Text(
                    'Username',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: usernameController,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.grey[50],
                      prefixText: '@ ',
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      prefixStyle: const TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isSaving
                          ? null
                          : () async {
                              final newName = nameController.text.trim();
                              final newUsername =
                                  usernameController.text.trim();

                              if (newName.isEmpty || newUsername.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Fields cannot be empty!'),
                                  ),
                                );
                                return;
                              }

                              setSheetState(() => isSaving = true);

                              final user = FirebaseAuth.instance.currentUser;
                              if (user != null) {
                                // BUG FIX (username uniqueness): Check if the
                                // new username is already taken by another user
                                // before saving to Firestore.
                                if (newUsername != currentUsername) {
                                  final existing = await FirebaseFirestore
                                      .instance
                                      .collection('users')
                                      .where(
                                        'username',
                                        isEqualTo: newUsername,
                                      )
                                      .get();

                                  if (existing.docs.isNotEmpty &&
                                      existing.docs.first.id != user.uid) {
                                    setSheetState(() => isSaving = false);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Username already taken. Try another one!',
                                          ),
                                          backgroundColor: Colors.redAccent,
                                        ),
                                      );
                                    }
                                    return;
                                  }
                                }

                                await FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(user.uid)
                                    .update({
                                      'fullName': newName,
                                      'username': newUsername,
                                    });
                              }

                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Profile updated! 🍋'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.yellow[600],
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        isSaving ? 'Saving...' : 'Save Changes',
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showSettingsMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Settings',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.logout,
                      color: Colors.redAccent,
                      size: 20,
                    ),
                  ),
                  title: const Text(
                    'Sign Out',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: Colors.redAccent,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _handleSignOut();
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleSignOut() async {
    final bool? shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Row(
            children: [
              Icon(Icons.logout, color: Colors.redAccent, size: 22),
              SizedBox(width: 8),
              Text(
                'Sign Out',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          content: const Text(
            'Are you sure you want to sign out of goLemons?',
            style: TextStyle(fontSize: 14),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Sign Out',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (shouldSignOut != true) return;

    setState(() => _isSigningOut = true);

    await Future.delayed(const Duration(milliseconds: 800));
    await FirebaseAuth.instance.signOut();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Successfully signed out. See you later! 🍋'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginView()),
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Stack(
      children: [
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 16.0,
            ),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // --- Header ---
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Text(
                              'Profile',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                                letterSpacing: -0.3,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.settings_outlined,
                                size: 24,
                                color: Colors.black87,
                              ),
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
                              onPressed: _showSettingsMenu,
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // --- Profile Card ---
                        if (currentUser != null)
                          StreamBuilder<DocumentSnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('users')
                                .doc(currentUser.uid)
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

                              if (snapshot.hasError ||
                                  !snapshot.hasData ||
                                  !snapshot.data!.exists) {
                                return const Center(
                                  child: Text('Could not load profile data.'),
                                );
                              }

                              final userData = snapshot.data!.data()
                                  as Map<String, dynamic>;
                              final fullName =
                                  userData['fullName'] ?? 'No Name';
                              final username =
                                  userData['username'] ?? 'No Username';

                              // BUG FIX #1: Fall back to FirebaseAuth email
                              // when the Firestore 'email' field is missing or null.
                              final email = (userData['email'] as String?)
                                      ?.isNotEmpty ==
                                      true
                                  ? userData['email'] as String
                                  : (currentUser.email?.isNotEmpty == true
                                      ? currentUser.email!
                                      : 'No Email');

                              final profileImageUrl =
                                  userData['profileImageUrl'] as String?;

                              return Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.grey[100]!,
                                    width: 1.2,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Stack(
                                      alignment: Alignment.bottomRight,
                                      children: [
                                        CircleAvatar(
                                          radius: 40,
                                          backgroundColor: Colors.yellow[100],
                                          // BUG FIX #2 (avatar display): After upload
                                          // _selectedImage is cleared to null, so the
                                          // avatar correctly switches to the new NetworkImage.
                                          backgroundImage: _selectedImage !=
                                                  null
                                              ? FileImage(_selectedImage!)
                                              : (profileImageUrl != null
                                                  ? NetworkImage(
                                                      profileImageUrl,
                                                    )
                                                  : null) as ImageProvider?,
                                          child: (_selectedImage == null &&
                                                  profileImageUrl == null)
                                              ? const Text(
                                                  '🍋',
                                                  style: TextStyle(
                                                    fontSize: 34,
                                                  ),
                                                )
                                              : null,
                                        ),
                                        if (_isUploadingImage)
                                          Positioned.fill(
                                            child: Container(
                                              decoration: const BoxDecoration(
                                                color: Colors.black45,
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Center(
                                                child: SizedBox(
                                                  height: 20,
                                                  width: 20,
                                                  child:
                                                      CircularProgressIndicator(
                                                    color: Colors.yellow,
                                                    strokeWidth: 2.5,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        GestureDetector(
                                          onTap: () => _showEditProfileSheet(
                                            fullName,
                                            username,
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: Colors.yellow[600],
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: Colors.white,
                                                width: 2,
                                              ),
                                            ),
                                            child: const Icon(
                                              Icons.edit,
                                              size: 14,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      fullName,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '@$username',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.yellow[800],
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      email,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[500],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        const SizedBox(height: 24),

                        // --- Stats Section ---
                        const Text(
                          'Your Stats',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.black87,
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
                                  : <QueryDocumentSnapshot>[];
                              final totalEntries = docs.length;
                              final daysLogged = docs
                                  .map((doc) {
                                    final d =
                                        (doc['date'] as Timestamp).toDate();
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
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.grey[100]!,
                                    width: 1.2,
                                  ),
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
                                      height: 30,
                                      width: 1,
                                      color: Colors.grey[200],
                                    ),
                                    _buildStatColumn(
                                      daysLogged.toString(),
                                      'Days Logged',
                                    ),
                                    Container(
                                      height: 30,
                                      width: 1,
                                      color: Colors.grey[200],
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
                        const SizedBox(height: 24),

                        // --- About Section ---
                        const Text(
                          'About',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.grey[100]!,
                              width: 1.2,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'goLemons',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Track your moods, understand your patterns, and take care of your mental wellbeing.',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  height: 1.4,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Version 1.0.0',
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
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
              ],
            ),
          ),
        ),

        if (_isSigningOut)
          Container(
            color: Colors.white70,
            child: const Center(
              child: CircularProgressIndicator(
                color: Colors.yellow,
                strokeWidth: 3,
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
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[500],
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}