import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart'; 

class InsightsView extends StatefulWidget {
  const InsightsView({super.key});

  @override
  State<InsightsView> createState() => _InsightsViewState();
}

class _InsightsViewState extends State<InsightsView>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true; 

  int _countRecentEntries(int days, List<DateTime> allDates) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return allDates.where((date) => date.isAfter(cutoff)).length;
  }

  int _calculateStreak(List<DateTime> allDates) {
    if (allDates.isEmpty) return 0;

    final uniqueDays = allDates
        .map((d) => DateTime(d.year, d.month, d.day))
        .toSet()
        .toList();
    uniqueDays.sort((a, b) => b.compareTo(a)); 

    int streak = 0;
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );

    DateTime dateToCheck = today;
    if (!uniqueDays.contains(today)) {
      dateToCheck = today.subtract(const Duration(days: 1));
      if (!uniqueDays.contains(dateToCheck)) return 0; 
    }

    while (uniqueDays.contains(dateToCheck)) {
      streak++;
      dateToCheck = dateToCheck.subtract(const Duration(days: 1));
    }

    return streak;
  }

  Color _getColor(int index) {
    List<Color> palette = [
      Colors.yellow[600]!,
      Colors.orange[400]!,
      Colors.red[400]!,
      Colors.blue[400]!,
      Colors.green[400]!,
      Colors.purple[400]!,
    ];
    return palette[index % palette.length];
  }

  Widget _buildSummaryBox(String title, int count, String emptyMessage) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.black87),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          decoration: BoxDecoration(
            color: count > 0 ? Colors.yellow[50]!.withOpacity(0.4) : Colors.white,
            borderRadius: BorderRadius.circular(10), // 🍋 Modernized tighter corner radius
            border: Border.all(color: count > 0 ? Colors.yellow[100]! : Colors.grey[100]!, width: 1.2),
          ),
          child: Center(
            child: Text(
              count > 0 ? '$count entries squeezed!' : emptyMessage,
              style: TextStyle(
                fontSize: 14,
                color: count > 0 ? Colors.yellow[800] : Colors.grey[400],
                fontWeight: count > 0 ? FontWeight.w700 : FontWeight.normal,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); 
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Center(child: Text("Please log in to see your insights."));
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('entries')
              .orderBy('date', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.yellow),
              );
            }

            if (snapshot.hasError) {
              return const Center(child: Text('Error loading insights.'));
            }

            final docs = snapshot.hasData ? snapshot.data!.docs : [];

            if (docs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('📊', style: TextStyle(fontSize: 44)),
                    const SizedBox(height: 12),
                    Text(
                      "Not enough data yet!",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Keep squeezing lemons to unlock your insights.",
                      style: TextStyle(color: Colors.grey[400], fontSize: 13),
                    ),
                  ],
                ),
              );
            }

            List<DateTime> allDates = docs.map((doc) {
              return (doc['date'] as Timestamp).toDate();
            }).toList();

            final totalEntries = docs.length;
            final streak = _calculateStreak(allDates);

            Map<String, int> moodCounts = {};
            Map<String, String> moodEmojis = {};
            Map<String, Map<String, int>> tagAssociations = {};

            for (var doc in docs) {
              final data = doc.data() as Map<String, dynamic>;
              final mood = data['mood'] as String? ?? 'Unknown';
              final emoji = data['emoji'] as String? ?? '🍋';
              final tags = List<dynamic>.from(data['tags'] ?? []);

              moodCounts[mood] = (moodCounts[mood] ?? 0) + 1;
              moodEmojis[mood] = emoji;

              if (tags.isNotEmpty) {
                if (!tagAssociations.containsKey(mood)) {
                  tagAssociations[mood] = {};
                }
                for (var tag in tags) {
                  String tagStr = tag.toString();
                  tagAssociations[mood]![tagStr] =
                      (tagAssociations[mood]![tagStr] ?? 0) + 1;
                }
              }
            }

            List<Widget> insightCards = [];
            tagAssociations.forEach((mood, tagsMap) {
              if (tagsMap.isNotEmpty) {
                var sortedTags = tagsMap.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value));

                String topTag = sortedTags.first.key;
                String emoji = moodEmojis[mood] ?? '🍋';

                insightCards.add(
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey[100]!, width: 1.2),
                      borderRadius: BorderRadius.circular(10), // 🍋 Matching modern 10px radius
                    ),
                    child: Row(
                      children: [
                        Text(emoji, style: const TextStyle(fontSize: 24)),
                        const SizedBox(width: 14),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                                height: 1.3,
                              ),
                              children: [
                                const TextSpan(text: 'When you feel '),
                                TextSpan(
                                  text: mood,
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                                const TextSpan(text: ', your top tag is '),
                                TextSpan(
                                  text: '#$topTag',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: Colors.yellow[800],
                                  ),
                                ),
                                const TextSpan(text: '.'),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
            });

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- 1. Header (Reduced Size & Semi-Bold) ---
                  const Text(
                    'Squeeze Insights',
                    style: TextStyle(
                      fontSize: 22, // 🍋 Cohesive downscale
                      fontWeight: FontWeight.w600, // 🍋 Elegant Semi-Bold
                      color: Color.fromARGB(255, 143, 115, 4),
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // --- 2. Grid Stats Row (Matching geometric profiles) ---
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10), // 🍋 Shrunk corner profiles
                            border: Border.all(color: Colors.grey[100]!, width: 1.2),
                          ),
                          child: Column(
                            children: [
                              Text(
                                totalEntries.toString(),
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Total Entries',
                                style: TextStyle(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10), // 🍋 Consistent sizing
                            border: Border.all(color: Colors.grey[100]!, width: 1.2),
                          ),
                          child: Column(
                            children: [
                              Text(
                                streak.toString(),
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Day Streak',
                                style: TextStyle(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // --- 3. Summaries Blocks ---
                  _buildSummaryBox(
                    'Last 7 Days',
                    _countRecentEntries(7, allDates),
                    'No entries this week',
                  ),
                  const SizedBox(height: 16),
                  _buildSummaryBox(
                    'Last 30 Days',
                    _countRecentEntries(30, allDates),
                    'No entries this month',
                  ),
                  const SizedBox(height: 28),

                  // --- 4. Pie Chart Module Container ---
                  const Text(
                    'Emotional Balance',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.black87),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: 220,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.yellow[50]!.withOpacity(0.4), // 🍋 Added premium subtle tint background
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.yellow[100]!, width: 1),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$totalEntries',
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: Colors.black87,
                              ),
                            ),
                            Text(
                              'Squeezes',
                              style: TextStyle(
                                color: Colors.yellow[800]!.withOpacity(0.8),
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        PieChart(
                          PieChartData(
                            sectionsSpace: 3,
                            centerSpaceRadius: 52,
                            sections: moodCounts.entries
                                .toList()
                                .asMap()
                                .entries
                                .map((entry) {
                                  int idx = entry.key;
                                  var mapEntry = entry.value;
                                  return PieChartSectionData(
                                    color: _getColor(idx),
                                    value: mapEntry.value.toDouble(),
                                    title: moodEmojis[mapEntry.key],
                                    radius: 36,
                                    titleStyle: const TextStyle(
                                      fontSize: 18,
                                    ),
                                  );
                                })
                                .toList(),
                          ),
                          swapAnimationDuration: const Duration(milliseconds: 600),
                          swapAnimationCurve: Curves.easeOutCubic,
                        ),
                      ],
                    ),
                  ),

                  // Legend Block
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 6,
                    children: moodCounts.entries.toList().asMap().entries.map((entry) {
                      int idx = entry.key;
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _getColor(idx),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${entry.value.key} (${entry.value.value})',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.black87),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 28),

                  // --- 5. Custom Tag Associations Module Layout ---
                  const Text(
                    'The "Why" Behind Your Moods',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.black87),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Patterns found based on your saved tags.',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 12),

                  if (insightCards.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey[100]!, width: 1),
                      ),
                      child: Text(
                        "Start using tags (like #Work or #Gym) when you save an entry to unlock this feature!",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    )
                  else
                    ...insightCards,

                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}