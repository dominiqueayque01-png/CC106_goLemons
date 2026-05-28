import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'entry_details_view.dart';
import 'modern_transitions.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView>
    with AutomaticKeepAliveClientMixin {
  bool _headerAnimated = false;
  bool _cardAnimated = false;

  final List<String> _motivations = [
    "A fresh week, a fresh start. Let's go!",
    "Small steps every day lead to big results.",
    "Consistency is your superpower.",
    "Your feelings are valid. Thanks for checking in!",
    "Squeeze the day! 🍋",
    "Take a deep breath. You're doing great.",
    "Tracking your mood is a form of self-care.",
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 50), () {
          if (mounted) setState(() => _headerAnimated = true);
        });
        Future.delayed(const Duration(milliseconds: 150), () {
          if (mounted) setState(() => _cardAnimated = true);
        });
      }
    });
  }

  int _calculateStreak(List<DateTime> allDates) {
    if (allDates.isEmpty) return 0;

    // Get unique days, sorted newest first
    final uniqueDays =
        allDates.map((d) => DateTime(d.year, d.month, d.day)).toSet().toList()
          ..sort((a, b) => b.compareTo(a));

    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    final yesterday = today.subtract(const Duration(days: 1));

    // 🍋 THE FIX: Start from today if logged today, yesterday if not.
    // If most recent entry is older than yesterday, streak is already broken.
    DateTime dateToCheck;
    if (uniqueDays.first == today) {
      dateToCheck = today;
    } else if (uniqueDays.first == yesterday) {
      dateToCheck = yesterday;
    } else {
      return 0; // Streak is broken — last entry was 2+ days ago
    }

    // Count backwards until the chain breaks
    int streak = 0;
    for (DateTime day in uniqueDays) {
      if (day == dateToCheck) {
        streak++;
        dateToCheck = dateToCheck.subtract(const Duration(days: 1));
      } else if (day.isBefore(dateToCheck)) {
        break; // Gap found — streak ends here
      }
    }

    return streak;
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    String dailyQuote = _motivations[DateTime.now().weekday - 1];
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Center(child: Text("Please log in to see your dashboard."));
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('entries')
              .orderBy('date', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.yellow),
              );
            }

            if (snapshot.hasError) {
              return const Center(
                child: Text('Something went wrong loading your entries.'),
              );
            }

            final cloudEntries = snapshot.hasData ? snapshot.data!.docs : [];

            List<DateTime> allDates = cloudEntries.map((doc) {
              return (doc['date'] as Timestamp).toDate();
            }).toList();
            int currentStreak = _calculateStreak(allDates);

            DateTime today = DateTime.now();
            var todaysDocs = cloudEntries.where((doc) {
              DateTime d = (doc['date'] as Timestamp).toDate();
              return d.year == today.year &&
                  d.month == today.month &&
                  d.day == today.day;
            }).toList();

            final bool loggedToday = todaysDocs.isNotEmpty;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),

                // --- 1. The Branded App Top Bar ---
                AnimatedOpacity(
                  opacity: _headerAnimated ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeInOut,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutCubic,
                    margin: EdgeInsets.only(
                      bottom: _headerAnimated ? 0.0 : 10.0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: const [
                                  Text('🍋', style: TextStyle(fontSize: 18)),
                                  SizedBox(width: 6),
                                  Text(
                                    'goLemons',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.3,
                                      color: Color.fromARGB(255, 143, 115, 4),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'How are you feeling today?',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.notifications_outlined,
                                size: 22,
                                color: Color.fromARGB(255, 143, 115, 4),
                              ),
                              constraints: const BoxConstraints(),
                              padding: const EdgeInsets.only(right: 8),
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("No new notifications! 🍋"),
                                  ),
                                );
                              },
                            ),
                            // 🍋 NEW: Dynamic Stream Profile Picture Loader!
                            StreamBuilder<DocumentSnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(user.uid)
                                  .snapshots(),
                              builder: (context, userSnapshot) {
                                String? profileImageUrl;
                                if (userSnapshot.hasData &&
                                    userSnapshot.data!.exists) {
                                  final userData =
                                      userSnapshot.data!.data()
                                          as Map<String, dynamic>;
                                  profileImageUrl =
                                      userData['profileImageUrl'] as String?;
                                }

                                return CircleAvatar(
                                  radius: 16,
                                  backgroundColor: Colors.yellow[100],
                                  backgroundImage:
                                      profileImageUrl != null &&
                                          profileImageUrl.isNotEmpty
                                      ? NetworkImage(profileImageUrl)
                                      : null,
                                  child:
                                      (profileImageUrl == null ||
                                          profileImageUrl.isEmpty)
                                      ? const Text(
                                          '🍋',
                                          style: TextStyle(fontSize: 14),
                                        )
                                      : null,
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // --- 2. The Daily Streak Hero Card (Compact Design) ---
                AnimatedOpacity(
                  opacity: _cardAnimated ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeInOut,
                  child: AnimatedScale(
                    scale: _cardAnimated ? 1.0 : 0.95,
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOutBack,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.yellow[400]!, Colors.yellow[600]!],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.yellow[600]!.withOpacity(0.25),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Your Momentum',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                  letterSpacing: 0.1,
                                ),
                              ),
                              // ✅ After
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 400),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: loggedToday
                                      ? Colors.white.withOpacity(0.9)
                                      : Colors.white.withOpacity(0.4),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.04),
                                      blurRadius: 6,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    // 🍋 Greyscale fire when not logged today, color when logged
                                    ColorFiltered(
                                      colorFilter: loggedToday
                                          ? const ColorFilter.mode(
                                              Colors.transparent,
                                              BlendMode.saturation,
                                            )
                                          : const ColorFilter.matrix(<double>[
                                              0.2126,
                                              0.7152,
                                              0.0722,
                                              0,
                                              0,
                                              0.2126,
                                              0.7152,
                                              0.0722,
                                              0,
                                              0,
                                              0.2126,
                                              0.7152,
                                              0.0722,
                                              0,
                                              0,
                                              0,
                                              0,
                                              0,
                                              1,
                                              0,
                                            ]),
                                      child: const Text(
                                        '🔥',
                                        style: TextStyle(fontSize: 13),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      loggedToday
                                          ? '$currentStreak Days'
                                          : '$currentStreak Days ·  Log to keep it!',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: loggedToday
                                            ? Colors.black87
                                            : Colors.black45,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            dailyQuote,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                              height: 1.25,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // --- 3. Today's Dashboard List Layout ---
                const Text(
                  "Today's Squeezes",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),

                Expanded(
                  child: RepaintBoundary(
                    child: todaysDocs.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Opacity(
                                  opacity: 0.5,
                                  child: Text(
                                    '🍋',
                                    style: TextStyle(fontSize: 44),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  "No squeezes yet today.",
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Tap the + button to log your mood!",
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            physics: const BouncingScrollPhysics(),
                            itemCount: todaysDocs.length,
                            itemBuilder: (context, index) {
                              var document = todaysDocs[index];
                              var data =
                                  document.data() as Map<String, dynamic>;

                              String docId = document.id;
                              String mood = data['mood'] ?? '';
                              String emoji = data['emoji'] ?? '🍋';
                              String note = data['note'] ?? '';
                              String title = data['title'] ?? '';
                              List<String> tags = List<String>.from(
                                data['tags'] ?? [],
                              );
                              DateTime entryDate =
                                  (document['date'] as Timestamp).toDate();

                              return FadeInSlideListItem(
                                index: index,
                                child: GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      ModernFadeRoute(
                                        page: EntryDetailsView(
                                          documentId: docId,
                                          mood: mood,
                                          emoji: emoji,
                                          initialNote: note,
                                          dateString: "Today",
                                          title: title,
                                          tags: tags,
                                          entryDate: entryDate, // 🍋 NEW
                                        ),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: Colors.yellow[200]!,
                                        width: 1.2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.yellow[600]!
                                              .withOpacity(0.03),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          height: 48,
                                          width: 48,
                                          decoration: BoxDecoration(
                                            color: Colors.yellow[50],
                                            shape: BoxShape.circle,
                                          ),
                                          child: Center(
                                            child: Text(
                                              emoji,
                                              style: const TextStyle(
                                                fontSize: 24,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              // 🍋 Title as the main headline
                                              if (title.isNotEmpty)
                                                Text(
                                                  title,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 15,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              // Mood as a smaller label underneath
                                              Text(
                                                mood,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w500,
                                                  fontSize: 13,
                                                  color: Colors.grey[500],
                                                ),
                                              ),
                                              if (note.isNotEmpty) ...[
                                                const SizedBox(height: 2),
                                                Text(
                                                  note,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color: Colors.grey[400],
                                                    height: 1.25,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        Icon(
                                          Icons.chevron_right,
                                          color: Colors.grey[300],
                                          size: 20,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class FadeInSlideListItem extends StatefulWidget {
  final int index;
  final Widget child;

  const FadeInSlideListItem({
    super.key,
    required this.index,
    required this.child,
  });

  @override
  State<FadeInSlideListItem> createState() => _FadeInSlideListItemState();
}

class _FadeInSlideListItemState extends State<FadeInSlideListItem> {
  bool _isVisible = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: 250 + (widget.index * 60)), () {
      if (mounted) {
        setState(() {
          _isVisible = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _isVisible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 550),
      curve: Curves.easeInOut,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 550),
        curve: Curves.easeOutCubic,
        margin: EdgeInsets.only(top: _isVisible ? 0.0 : 16.0),
        child: widget.child,
      ),
    );
  }
}
