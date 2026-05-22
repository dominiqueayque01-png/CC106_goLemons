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

// 🍋 OPTIMIZATION 1: Added 'AutomaticKeepAliveClientMixin' to freeze this tab in memory when you swipe away!
class _HomeViewState extends State<HomeView>
    with AutomaticKeepAliveClientMixin {
  final List<String> _motivations = [
    "A fresh week, a fresh start. Let's go!",
    "Small steps every day lead to big results.",
    "Consistency is your superpower.",
    "Your feelings are valid. Thanks for checking in!",
    "Squeeze the day! 🍋",
    "Take a deep breath. You're doing great.",
    "Tracking your mood is a form of self-care.",
  ];

  int _calculateStreak(List<DateTime> allDates) {
    if (allDates.isEmpty) return 0;

    List<DateTime> uniqueDates = [];
    for (var date in allDates) {
      DateTime justDate = DateTime(date.year, date.month, date.day);
      if (!uniqueDates.contains(justDate)) {
        uniqueDates.add(justDate);
      }
    }

    if (uniqueDates.isEmpty) return 0;

    DateTime today = DateTime.now();
    DateTime justToday = DateTime(today.year, today.month, today.day);

    int streak = 0;
    DateTime currentDateToCheck = justToday;

    if (uniqueDates.first != justToday &&
        uniqueDates.first != justToday.subtract(const Duration(days: 1))) {
      return 0;
    }

    for (int i = 0; i < uniqueDates.length; i++) {
      if (uniqueDates[i] == currentDateToCheck) {
        streak++;
        currentDateToCheck = currentDateToCheck.subtract(
          const Duration(days: 1),
        );
      } else if (i == 0 &&
          uniqueDates[i] ==
              currentDateToCheck.subtract(const Duration(days: 1))) {
        streak++;
        currentDateToCheck = currentDateToCheck.subtract(
          const Duration(days: 2),
        );
      } else {
        break;
      }
    }
    return streak;
  }

  // 🍋 OPTIMIZATION 2: You MUST override wantKeepAlive and return true!
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    // 🍋 OPTIMIZATION 3: You MUST call super.build(context) at the top of your build method!
    super.build(context);

    final brandColor = Colors.yellow[600]!;
    String dailyQuote = _motivations[DateTime.now().weekday - 1];

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text("Please log in to see your dashboard."));
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
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

            // --- DATA PROCESSING ---
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

            // --- THE UI ---
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- 1. The Greeting ---
                const Text(
                  'Hello! 👋',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'How are you feeling today?',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
                const SizedBox(height: 24),

                // --- 2. The Daily Streak Hero Card ---
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: brandColor,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: brandColor.withOpacity(0.4),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
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
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                const Text(
                                  '🔥 ',
                                  style: TextStyle(fontSize: 16),
                                ),
                                Text(
                                  '$currentStreak Days',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        dailyQuote,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // --- 3. Today's Dashboard List ---
                const Text(
                  "Today's Squeezes",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                Expanded(
                  // 🍋 OPTIMIZATION 4: Wrapped the animated list in a RepaintBoundary so sliding transitions don't force heavy layout redraws!
                  child: RepaintBoundary(
                    child: todaysDocs.isEmpty
                        ? Center(
                            child: Text(
                              "You haven't logged anything today yet!",
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: todaysDocs.length,
                            itemBuilder: (context, index) {
                              var document = todaysDocs[index];
                              var data =
                                  document.data() as Map<String, dynamic>;

                              String docId = document.id;
                              String mood = data['mood'] ?? '';
                              String emoji = data['emoji'] ?? '🍋';
                              String note = data['note'] ?? '';

                              return FadeInSlideListItem(
                                index: index,
                                child: Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  color: Colors.yellow[50],
                                  elevation: 0,
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.all(16),
                                    leading: Text(
                                      emoji,
                                      style: const TextStyle(fontSize: 32),
                                    ),
                                    title: Text(
                                      mood,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                    subtitle: note.isNotEmpty
                                        ? Padding(
                                            padding: const EdgeInsets.only(
                                              top: 8.0,
                                            ),
                                            child: Text(
                                              note,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: Colors.grey[800],
                                              ),
                                            ),
                                          )
                                        : null,
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
                                          ),
                                        ),
                                      );
                                    },
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
    Future.delayed(Duration(milliseconds: widget.index * 50), () {
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
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
        margin: EdgeInsets.only(top: _isVisible ? 0.0 : 20.0),
        child: widget.child,
      ),
    );
  }
}
