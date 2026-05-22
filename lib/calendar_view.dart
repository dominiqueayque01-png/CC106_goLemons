import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CalendarView extends StatefulWidget {
  const CalendarView({super.key});

  @override
  State<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<CalendarView> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // 🍋 ANIMATION STATE: Controls the smooth swelling entrance of the calendar grid
  bool _calendarAnimated = false;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;

    // Trigger the calendar scale animation immediately after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _calendarAnimated = true;
        });
      }
    });
  }

  // A quick helper to format the date nicely (e.g., "3/15/2026")
  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  // Helper to strip time from dates so TableCalendar matches them perfectly
  DateTime _normalizeDate(DateTime date) {
    return DateTime.utc(date.year, date.month, date.day);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text("Please log in to see your calendar."));
    }

    return DefaultTabController(
      length: 2,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),

          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('entries')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.yellow),
                );
              }

              if (snapshot.hasError) {
                return const Center(
                  child: Text('Error loading calendar data.'),
                );
              }

              final cloudEntries = snapshot.hasData ? snapshot.data!.docs : [];
              // Group the cloud data by date so the calendar can read it!
              Map<DateTime, List<Map<String, dynamic>>> groupedEntries = {};

              for (var doc in cloudEntries) {
                final data = doc.data() as Map<String, dynamic>;

                if (data['date'] != null) {
                  DateTime entryDate = (data['date'] as Timestamp).toDate();

                  DateTime normalizedDate = _normalizeDate(entryDate);

                  if (groupedEntries[normalizedDate] == null) {
                    groupedEntries[normalizedDate] = [];
                  }
                  groupedEntries[normalizedDate]!.add(data);
                }
              }

              List<Map<String, dynamic>> getEventsForDay(DateTime day) {
                return groupedEntries[_normalizeDate(day)] ?? [];
              }

              List<Map<String, dynamic>> selectedDayEvents = getEventsForDay(
                _selectedDay ?? _focusedDay,
              );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Journal',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  // --- The Custom Tab Bar ---
                  Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: TabBar(
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicator: BoxDecoration(
                        color: Colors.yellow[600],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      labelColor: Colors.black,
                      labelStyle: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      unselectedLabelColor: Colors.grey[500],
                      dividerColor: Colors.transparent,
                      tabs: const [
                        Tab(text: 'Patterns'),
                        Tab(text: 'Daily Notes'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // --- The Tab Views ---
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildPatternTab(getEventsForDay),
                        _buildNotesTab(selectedDayEvents),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ==========================================
  // TAB 1: PATTERN RECOGNITION (CALENDAR)
  // ==========================================
  Widget _buildPatternTab(
    List<Map<String, dynamic>> Function(DateTime) getEvents,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Pattern Recognition',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              _selectedDay != null ? _formatDate(_selectedDay!) : '',
              style: TextStyle(
                color: Colors.yellow[800],
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 🍋 NEW ANIMATION STEP: Scale and Fade implementation for the Calendar Card container
        AnimatedOpacity(
          opacity: _calendarAnimated ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutBack,
          child: AnimatedScale(
            scale: _calendarAnimated ? 1.0 : 0.95,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutBack,
            child: Card(
              elevation: 0,
              color: Colors.yellow[50],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: TableCalendar(
                  firstDay: DateTime.utc(2023, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: _focusedDay,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),

                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                  },

                  eventLoader: getEvents,

                  calendarBuilders: CalendarBuilders(
                    markerBuilder: (context, date, events) {
                      if (events.isNotEmpty) {
                        final entry = events.last as Map<String, dynamic>;
                        String emoji = entry['emoji'] ?? '🍋';
                        return Positioned(
                          bottom: -2,
                          child: Text(
                            emoji,
                            style: const TextStyle(fontSize: 16),
                          ),
                        );
                      }
                      return null;
                    },
                  ),
                  headerStyle: const HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                    titleTextStyle: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  calendarStyle: CalendarStyle(
                    todayDecoration: BoxDecoration(
                      color: Colors.yellow[300],
                      shape: BoxShape.circle,
                    ),
                    selectedDecoration: BoxDecoration(
                      color: Colors.yellow[700],
                      shape: BoxShape.circle,
                    ),
                    markerDecoration: const BoxDecoration(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // TAB 2: DAILY NOTES & ANALYTICS
  // ==========================================
  Widget _buildNotesTab(List<Map<String, dynamic>> dailyEvents) {
    Map<String, int> moodTallies = {};
    for (var entry in dailyEvents) {
      String emoji = entry['emoji'] ?? '🍋';
      moodTallies[emoji] = (moodTallies[emoji] ?? 0) + 1;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Notes for ${_formatDate(_selectedDay ?? _focusedDay)}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.yellow[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${dailyEvents.length} Entries',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        Expanded(
          child: dailyEvents.isEmpty
              ? Center(
                  child: Text(
                    'No lemonade squeezed on this day!',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: dailyEvents.length,
                  itemBuilder: (context, index) {
                    final entry = dailyEvents[index];
                    String mood = entry['mood'] ?? '';
                    String emoji = entry['emoji'] ?? '🍋';
                    String note = entry['note'] ?? '';
                    List<dynamic> tags = entry['tags'] ?? [];

                    // 🍋 NEW ANIMATION STEP: Applied the staggered wrapper to fluidly deploy calendar notes
                    return CalendarFadeInSlideItem(
                      index: index,
                      // We give it a key based on the day string so it re-triggers the ripple when you click a different date!
                      key: ValueKey(
                        '${_formatDate(_selectedDay ?? _focusedDay)}_$index',
                      ),
                      child: Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        color: Colors.yellow[100],
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
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (note.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  note,
                                  style: TextStyle(color: Colors.grey[800]),
                                ),
                              ],
                              if (tags.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 4,
                                  children: tags
                                      .map(
                                        (tag) => Text(
                                          '#$tag',
                                          style: TextStyle(
                                            color: Colors.yellow[800],
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),

        // The Mini Analytics Bottom Card
        if (dailyEvents.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border.all(color: Colors.grey[200]!),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daily Analytics',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  children: moodTallies.entries.map((tally) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(tally.key, style: const TextStyle(fontSize: 24)),
                        const SizedBox(width: 4),
                        Text(
                          'x${tally.value}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// 🍋 NEW WIDGET PARADIGM: Staggers notes sequentially whenever a user interacts with different calendar timelines
class CalendarFadeInSlideItem extends StatefulWidget {
  final int index;
  final Widget child;

  const CalendarFadeInSlideItem({
    super.key,
    required this.index,
    required this.child,
  });

  @override
  State<CalendarFadeInSlideItem> createState() =>
      _CalendarFadeInSlideItemState();
}

class _CalendarFadeInSlideItemState extends State<CalendarFadeInSlideItem> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.index * 40), () {
      if (mounted) {
        setState(() {
          _visible = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _visible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutQuad,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutQuad,
        margin: EdgeInsets.only(top: _visible ? 0.0 : 15.0),
        child: widget.child,
      ),
    );
  }
}
