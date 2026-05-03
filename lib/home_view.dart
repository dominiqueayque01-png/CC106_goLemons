import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'entry_details_view.dart'; // 🍋 NEW: Import the edit screen we built!
import 'modern_transitions.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  // 1. Dynamic Motivation Quotes
  final List<String> _motivations = [
    "A fresh week, a fresh start. Let's go!", // Monday
    "Small steps every day lead to big results.", // Tuesday
    "Consistency is your superpower.", // Wednesday
    "Your feelings are valid. Thanks for checking in!", // Thursday
    "Squeeze the day! 🍋", // Friday
    "Take a deep breath. You're doing great.", // Saturday
    "Tracking your mood is a form of self-care." // Sunday
  ];

  // 2. Upgraded Streak Engine (Now accepts cloud dates!)
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
        currentDateToCheck = currentDateToCheck.subtract(const Duration(days: 1));
      } else if (i == 0 && uniqueDates[i] == currentDateToCheck.subtract(const Duration(days: 1))) {
        streak++;
        currentDateToCheck = currentDateToCheck.subtract(const Duration(days: 2));
      } else {
        break; 
      }
    }
    return streak;
  }

  @override
  Widget build(BuildContext context) {
    final brandColor = Colors.yellow[600]!; 
    String dailyQuote = _motivations[DateTime.now().weekday - 1];

    // 🍋 1. Check who is logged in
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text("Please log in to see your dashboard."));
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        // 🍋 2. Open the live pipe to the specific user's database folder!
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('entries')
              .orderBy('date', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            
            // Show a spinner while the data loads from the cloud
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Colors.yellow));
            }

            if (snapshot.hasError) {
              return const Center(child: Text('Something went wrong loading your entries.'));
            }

            // Get the cloud documents (or an empty list if they have none)
            final cloudEntries = snapshot.hasData ? snapshot.data!.docs : [];

            // --- DATA PROCESSING ---
            
            // A. Extract all dates for the streak calculator
            List<DateTime> allDates = cloudEntries.map((doc) {
              return (doc['date'] as Timestamp).toDate();
            }).toList();
            int currentStreak = _calculateStreak(allDates);

            // B. Filter the cloud entries to ONLY show today's entries in the list
            DateTime today = DateTime.now();
            var todaysDocs = cloudEntries.where((doc) {
              DateTime d = (doc['date'] as Timestamp).toDate();
              return d.year == today.year && d.month == today.month && d.day == today.day;
            }).toList();

            // --- THE UI ---
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- 1. The Greeting ---
                const Text('Hello! 👋', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('How are you feeling today?', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
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
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                const Text('🔥 ', style: TextStyle(fontSize: 16)),
                                Text(
                                  '$currentStreak Days', 
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 16)
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        dailyQuote,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black, height: 1.3),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // --- 3. Today's Dashboard List ---
                const Text("Today's Squeezes", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                
                Expanded(
                  child: todaysDocs.isEmpty
                    ? Center(child: Text("You haven't logged anything today yet!", style: TextStyle(color: Colors.grey[500], fontStyle: FontStyle.italic)))
                    : ListView.builder(
                        itemCount: todaysDocs.length,
                        itemBuilder: (context, index) {
                          // Extract the data from the cloud document
                          var document = todaysDocs[index];
                          var data = document.data() as Map<String, dynamic>;
                          
                          String docId = document.id;
                          String mood = data['mood'] ?? '';
                          String emoji = data['emoji'] ?? '🍋';
                          String note = data['note'] ?? '';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            color: Colors.yellow[50], 
                            elevation: 0,
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              leading: Text(emoji, style: const TextStyle(fontSize: 32)),
                              title: Text(mood, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                              subtitle: note.isNotEmpty 
                                  ? Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: Text(note, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey[800])),
                                    )
                                  : null,
                              // 🍋 3. Navigates to your new Edit Screen!
                              onTap: () {
                                Navigator.push(
                                  context,
                                  // 🍋 Swapped MaterialPageRoute for ModernFadeRoute!
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
                          );
                        },
                      ),
                ),
              ],
            );
          }
        ),
      ),
    );
  }
}