import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class InsightsView extends StatelessWidget {
  const InsightsView({super.key});

  // 🧠 THE MATH: Counts how many entries happened in the last X days from the cloud
  int _countRecentEntries(int days, List<DateTime> allDates) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return allDates.where((date) => date.isAfter(cutoff)).length;
  }

  // 🧠 THE MATH: Calculates the current daily streak from the cloud
  int _calculateStreak(List<DateTime> allDates) {
    if (allDates.isEmpty) return 0;
    
    // Get a list of just the unique days
    final uniqueDays = allDates.map((d) => DateTime(d.year, d.month, d.day)).toSet().toList();
    uniqueDays.sort((a, b) => b.compareTo(a)); // Newest first

    int streak = 0;
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    
    // Check if they started their streak today or yesterday
    DateTime dateToCheck = today;
    if (!uniqueDays.contains(today)) {
      dateToCheck = today.subtract(const Duration(days: 1));
      if (!uniqueDays.contains(dateToCheck)) return 0; // Streak broken!
    }

    // Count backwards until the streak breaks
    while (uniqueDays.contains(dateToCheck)) {
      streak++;
      dateToCheck = dateToCheck.subtract(const Duration(days: 1));
    }
    
    return streak;
  }

  Widget _buildSummaryBox(String title, int count, String emptyMessage) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: count > 0 ? Colors.yellow[50] : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Center(
            child: Text(
              count > 0 ? '$count entries squeezed!' : emptyMessage,
              style: TextStyle(
                fontSize: 16, 
                color: count > 0 ? Colors.yellow[800] : Colors.grey[500],
                fontWeight: count > 0 ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Center(child: Text("Please log in to see your insights."));
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        // 🍋 NEW: The StreamBuilder pulls your exact data from the cloud
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('entries')
              .snapshots(),
          builder: (context, snapshot) {
            
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Colors.yellow));
            }

            if (snapshot.hasError) {
              return const Center(child: Text('Error loading insights.'));
            }

            // Extract all dates from the cloud documents
            final docs = snapshot.hasData ? snapshot.data!.docs : [];
            List<DateTime> allDates = docs.map((doc) {
              return (doc['date'] as Timestamp).toDate();
            }).toList();

            final totalEntries = docs.length;
            final streak = _calculateStreak(allDates);

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Insights', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),

                  // --- Top Stats Row ---
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Column(
                            children: [
                              Text(totalEntries.toString(), style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text('Total Entries', style: TextStyle(color: Colors.grey[600])),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Column(
                            children: [
                              Text(streak.toString(), style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text('Day Streak', style: TextStyle(color: Colors.grey[600])),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // --- Weekly and Monthly Summaries ---
                  _buildSummaryBox('Last 7 Days', _countRecentEntries(7, allDates), 'No entries this week'),
                  const SizedBox(height: 24),
                  _buildSummaryBox('Last 30 Days', _countRecentEntries(30, allDates), 'No entries this month'),
                ],
              ),
            );
          }
        ),
      ),
    );
  }
}