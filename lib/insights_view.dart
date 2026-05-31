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

  // ==========================================
  // 🍋 MATH HELPERS
  // ==========================================

  int _countRecentEntries(int days, List<DateTime> allDates) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return allDates.where((date) => date.isAfter(cutoff)).length;
  }

  int _calculateStreak(List<DateTime> allDates) {
    if (allDates.isEmpty) return 0;
    final uniqueDays = allDates
        .map((d) => DateTime(d.year, d.month, d.day))
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));

    final today = DateTime(
        DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final yesterday = today.subtract(const Duration(days: 1));

    DateTime dateToCheck;
    if (uniqueDays.first == today) {
      dateToCheck = today;
    } else if (uniqueDays.first == yesterday) {
      dateToCheck = yesterday;
    } else {
      return 0;
    }

    int streak = 0;
    for (DateTime day in uniqueDays) {
      if (day == dateToCheck) {
        streak++;
        dateToCheck = dateToCheck.subtract(const Duration(days: 1));
      } else if (day.isBefore(dateToCheck)) {
        break;
      }
    }
    return streak;
  }

  // 🍋 REAL bar chart: counts entries per weekday (Mon=0 .. Sun=6)
  List<double> _getWeekdayCounts(List<DateTime> allDates) {
    final counts = List<double>.filled(7, 0);
    for (final date in allDates) {
      // DateTime weekday: Mon=1 .. Sun=7 → index 0..6
      counts[date.weekday - 1] += 1;
    }
    return counts;
  }

  // 🍋 Best day of the week
  String _getBestDay(List<double> counts) {
    const days = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday'
    ];
    int maxIdx = 0;
    for (int i = 1; i < counts.length; i++) {
      if (counts[i] > counts[maxIdx]) maxIdx = i;
    }
    return counts[maxIdx] == 0 ? 'N/A' : days[maxIdx];
  }

  // 🍋 Most used tag across all entries
  String _getMostUsedTag(List<dynamic> docs) {
    final tagCounts = <String, int>{};
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final tags = List<dynamic>.from(data['tags'] ?? []);
      for (final tag in tags) {
        final t = tag.toString();
        tagCounts[t] = (tagCounts[t] ?? 0) + 1;
      }
    }
    if (tagCounts.isEmpty) return '';
    return tagCounts.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;
  }

  Color _getColor(int index) {
    const palette = [
      Color(0xFFFFCA28), // yellow
      Color(0xFFFFA726), // orange
      Color(0xFFEF5350), // red
      Color(0xFF42A5F5), // blue
      Color(0xFF66BB6A), // green
      Color(0xFFAB47BC), // purple
    ];
    return palette[index % palette.length];
  }

  // ==========================================
  // 🍋 DYNAMIC MILESTONES
  // ==========================================
  List<Map<String, dynamic>> _getMilestones(
      int totalEntries, int streak, int daysLogged) {
    final List<Map<String, dynamic>> all = [
      {
        'icon': '🍋',
        'title': 'First Squeeze',
        'desc': 'You logged your very first mood entry!',
        'unlocked': totalEntries >= 1,
      },
      {
        'icon': '🔥',
        'title': '3-Day Streak',
        'desc': 'You logged your mood 3 days in a row.',
        'unlocked': streak >= 3,
      },
      {
        'icon': '📅',
        'title': 'Week Warrior',
        'desc': 'You logged entries on 7 different days.',
        'unlocked': daysLogged >= 7,
      },
      {
        'icon': '⭐',
        'title': '25 Squeezes',
        'desc': 'You have logged over 25 total entries!',
        'unlocked': totalEntries >= 25,
      },
      {
        'icon': '💪',
        'title': '7-Day Streak',
        'desc': 'You kept your streak alive for a full week!',
        'unlocked': streak >= 7,
      },
      {
        'icon': '👑',
        'title': 'Master Squeezer',
        'desc': 'Over 50 entries logged. You\'re a journaling pro!',
        'unlocked': totalEntries >= 50,
      },
      {
        'icon': '🏆',
        'title': '30-Day Streak',
        'desc': 'An entire month of consistent logging. Legendary!',
        'unlocked': streak >= 30,
      },
    ];

    // Show unlocked first, then locked (greyed out)
    all.sort((a, b) {
      if (a['unlocked'] == b['unlocked']) return 0;
      return (a['unlocked'] as bool) ? -1 : 1;
    });

    return all;
  }

  Widget _buildSummaryBox(String title, int count, String emptyMessage) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.black87)),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding:
              const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          decoration: BoxDecoration(
            color: count > 0
                ? Colors.yellow[50]!.withOpacity(0.4)
                : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: count > 0 ? Colors.yellow[100]! : Colors.grey[100]!,
              width: 1.2,
            ),
          ),
          child: Center(
            child: Text(
              count > 0 ? '$count entries squeezed!' : emptyMessage,
              style: TextStyle(
                fontSize: 14,
                color: count > 0 ? Colors.yellow[800] : Colors.grey[400],
                fontWeight:
                    count > 0 ? FontWeight.w700 : FontWeight.normal,
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
      return const Center(
          child: Text("Please log in to see your insights."));
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
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(
                  child: CircularProgressIndicator(color: Colors.yellow));
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
                    const Text("Not enough data yet!",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(
                      "Keep squeezing lemons to unlock your insights.",
                      style:
                          TextStyle(color: Colors.grey[400], fontSize: 13),
                    ),
                  ],
                ),
              );
            }

            // ==========================================
            // 🍋 DATA PROCESSING
            // ==========================================
            final List<DateTime> allDates = docs.map((doc) {
              return (doc['date'] as Timestamp).toDate();
            }).toList();

            final int totalEntries = docs.length;
            final int streak = _calculateStreak(allDates);
            final int daysLogged = allDates
                .map((d) => DateTime(d.year, d.month, d.day))
                .toSet()
                .length;

            // Mood counts
            final Map<String, int> moodCounts = {};
            final Map<String, String> moodEmojis = {};
            final Map<String, Map<String, int>> tagAssociations = {};

            for (var doc in docs) {
              final data = doc.data() as Map<String, dynamic>;
              final mood = data['mood'] as String? ?? 'Unknown';
              final emoji = data['emoji'] as String? ?? '🍋';
              final tags = List<dynamic>.from(data['tags'] ?? []);

              moodCounts[mood] = (moodCounts[mood] ?? 0) + 1;
              moodEmojis[mood] = emoji;

              if (tags.isNotEmpty) {
                tagAssociations[mood] ??= {};
                for (var tag in tags) {
                  final t = tag.toString();
                  tagAssociations[mood]![t] =
                      (tagAssociations[mood]![t] ?? 0) + 1;
                }
              }
            }

            // Most frequent mood
            String topMood = '';
            String topMoodEmoji = '🍋';
            int topMoodCount = 0;
            moodCounts.forEach((mood, count) {
              if (count > topMoodCount) {
                topMood = mood;
                topMoodCount = count;
                topMoodEmoji = moodEmojis[mood] ?? '🍋';
              }
            });

            // 🍋 Real bar chart data
            final weekdayCounts = _getWeekdayCounts(allDates);
            final double maxY =
                weekdayCounts.reduce((a, b) => a > b ? a : b);
            final bestDay = _getBestDay(weekdayCounts);

            // Most used tag
            final mostUsedTag = _getMostUsedTag(docs);

            // Milestones
            final milestones =
                _getMilestones(totalEntries, streak, daysLogged);

            // Insight cards
            final List<Widget> insightCards = [];
            tagAssociations.forEach((mood, tagsMap) {
              if (tagsMap.isNotEmpty) {
                final sortedTags = tagsMap.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value));
                final topTag = sortedTags.first.key;
                final emoji = moodEmojis[mood] ?? '🍋';
                insightCards.add(
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(
                          color: Colors.grey[100]!, width: 1.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Text(emoji,
                            style: const TextStyle(fontSize: 24)),
                        const SizedBox(width: 14),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.black87,
                                  height: 1.3),
                              children: [
                                const TextSpan(text: 'When you feel '),
                                TextSpan(
                                  text: mood,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700),
                                ),
                                const TextSpan(
                                    text: ', your top tag is '),
                                TextSpan(
                                  text: '#$topTag',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: Colors.yellow[800]),
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

                  // --- Header ---
                  const Text(
                    'Squeeze Insights',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: Color.fromARGB(255, 143, 115, 4),
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ==========================================
                  // 🍋 MOST FREQUENT MOOD HIGHLIGHT CARD
                  // ==========================================
                  if (topMood.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.yellow[400]!,
                            Colors.yellow[600]!
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.yellow[400]!.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Text(topMoodEmoji,
                              style: const TextStyle(fontSize: 36)),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Most Frequent Mood',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black54,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  topMood,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.black87,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                Text(
                                  '$topMoodCount out of $totalEntries entries',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // --- Stats Row ---
                  Row(
                    children: [
                      _StatCard(
                        value: totalEntries.toString(),
                        label: 'Total Entries',
                        icon: '📝',
                      ),
                      const SizedBox(width: 12),
                      _StatCard(
                        value: streak.toString(),
                        label: 'Day Streak',
                        icon: '🔥',
                      ),
                      const SizedBox(width: 12),
                      _StatCard(
                        value: daysLogged.toString(),
                        label: 'Days Logged',
                        icon: '📅',
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // --- Summaries ---
                  _buildSummaryBox('Last 7 Days',
                      _countRecentEntries(7, allDates), 'No entries this week'),
                  const SizedBox(height: 12),
                  _buildSummaryBox('Last 30 Days',
                      _countRecentEntries(30, allDates), 'No entries this month'),
                  const SizedBox(height: 28),

                  // ==========================================
                  // 🍋 MOST USED TAG CALLOUT
                  // ==========================================
                  if (mostUsedTag.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: Colors.grey[100]!, width: 1.2),
                      ),
                      child: Row(
                        children: [
                          const Text('🏷️',
                              style: TextStyle(fontSize: 22)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black87,
                                    height: 1.3),
                                children: [
                                  const TextSpan(
                                      text: 'Your most used tag is '),
                                  TextSpan(
                                    text: '#$mostUsedTag',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: Colors.yellow[800]),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                  ],

                  // --- Emotional Balance Pie Chart ---
                  const Text('Emotional Balance',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87)),
                  const SizedBox(height: 12),
                  Container(
                    height: 220,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.yellow[50]!.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: Colors.yellow[100]!, width: 1),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('$totalEntries',
                                style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.black87)),
                            Text('Squeezes',
                                style: TextStyle(
                                    color:
                                        Colors.yellow[800]!.withOpacity(0.8),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11)),
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
                              return PieChartSectionData(
                                color: _getColor(entry.key),
                                value: entry.value.value.toDouble(),
                                title: moodEmojis[entry.value.key],
                                radius: 36,
                                titleStyle:
                                    const TextStyle(fontSize: 18),
                              );
                            }).toList(),
                          ),
                          swapAnimationDuration:
                              const Duration(milliseconds: 600),
                          swapAnimationCurve: Curves.easeOutCubic,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 6,
                    children: moodCounts.entries
                        .toList()
                        .asMap()
                        .entries
                        .map((entry) {
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                                color: _getColor(entry.key),
                                shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${entry.value.key} (${entry.value.value})',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                                color: Colors.black87),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 28),

                  // ==========================================
                  // 🍋 REAL WEEKLY BAR CHART
                  // ==========================================
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Weekly Squeeze Frequency',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Colors.black87)),
                      // 🍋 Best day badge
                      if (bestDay != 'N/A')
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.yellow[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Best: $bestDay',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.yellow[800],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: 180,
                    padding: const EdgeInsets.fromLTRB(12, 24, 12, 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: Colors.grey[100]!, width: 1.2),
                    ),
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        // 🍋 Dynamic maxY from real data
                        maxY: maxY < 1 ? 5 : (maxY * 1.3).ceilToDouble(),
                        barTouchData: BarTouchData(
                          enabled: true,
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipColor: (_) => Colors.yellow[600]!,
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              const days = [
                                'Mon', 'Tue', 'Wed', 'Thu',
                                'Fri', 'Sat', 'Sun'
                              ];
                              return BarTooltipItem(
                                '${days[group.x]}\n${rod.toY.toInt()} entries',
                                const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              );
                            },
                          ),
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget:
                                  (double value, TitleMeta meta) {
                                const weekdays = [
                                  'M', 'T', 'W', 'T', 'F', 'S', 'S'
                                ];
                                return Padding(
                                  padding: const EdgeInsets.only(top: 6.0),
                                  child: Text(
                                    weekdays[value.toInt() % 7],
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          leftTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                        ),
                        gridData: const FlGridData(show: false),
                        borderData: FlBorderData(show: false),
                        // 🍋 Real data from Firestore
                        barGroups: List.generate(7, (i) {
                          final isToday =
                              i == (DateTime.now().weekday - 1);
                          return BarChartGroupData(
                            x: i,
                            barRods: [
                              BarChartRodData(
                                toY: weekdayCounts[i],
                                color: isToday
                                    ? Colors.yellow[800]
                                    : Colors.yellow[500],
                                width: 14,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ],
                          );
                        }),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ==========================================
                  // 🍋 DYNAMIC MILESTONES
                  // ==========================================
                  const Text('Milestones & Achievements',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87)),
                  const SizedBox(height: 12),
                  ...milestones.map((m) {
                    final bool unlocked = m['unlocked'] as bool;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: unlocked
                            ? Colors.white
                            : Colors.grey[50],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: unlocked
                              ? Colors.yellow[100]!
                              : Colors.grey[100]!,
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        children: [
                          // Icon — greyed out if locked
                          ColorFiltered(
                            colorFilter: unlocked
                                ? const ColorFilter.mode(
                                    Colors.transparent,
                                    BlendMode.saturation)
                                : const ColorFilter.matrix(<double>[
                                    0.2126, 0.7152, 0.0722, 0, 0,
                                    0.2126, 0.7152, 0.0722, 0, 0,
                                    0.2126, 0.7152, 0.0722, 0, 0,
                                    0, 0, 0, 1, 0,
                                  ]),
                            child: Text(m['icon'] as String,
                                style: const TextStyle(fontSize: 28)),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      m['title'] as String,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                        color: unlocked
                                            ? Colors.black87
                                            : Colors.grey[400],
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    if (unlocked)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.yellow[100],
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text('Unlocked',
                                            style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.yellow[800])),
                                      )
                                    else
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[100],
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text('Locked',
                                            style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.grey[400])),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  m['desc'] as String,
                                  style: TextStyle(
                                    color: unlocked
                                        ? Colors.grey[600]
                                        : Colors.grey[400],
                                    fontSize: 12,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 28),

                  // --- The "Why" Behind Your Moods ---
                  const Text('The "Why" Behind Your Moods',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87)),
                  const SizedBox(height: 4),
                  Text('Patterns found based on your saved tags.',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 12),

                  if (insightCards.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: Colors.grey[100]!, width: 1),
                      ),
                      child: Text(
                        "Start using tags (like #Work or #Gym) when you save an entry to unlock this feature!",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                            fontWeight: FontWeight.w500),
                      ),
                    )
                  else
                    ...insightCards,

                  const SizedBox(height: 32),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ==========================================
// 🍋 REUSABLE STAT CARD
// ==========================================
class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final String icon;

  const _StatCard({
    required this.value,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey[100]!, width: 1.2),
        ),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 11,
                    fontWeight: FontWeight.w500),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}