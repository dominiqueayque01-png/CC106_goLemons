import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'mood_entry.dart';

class CalendarView extends StatefulWidget {
  const CalendarView({super.key});

  @override
  State<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<CalendarView> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  
  // We use a ValueNotifier to instantly update the list when a day is tapped!
  late final ValueNotifier<List<MoodEntry>> _selectedEvents;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _selectedEvents = ValueNotifier(_getMoodsForDay(_selectedDay!));
  }

  @override
  void dispose() {
    _selectedEvents.dispose();
    super.dispose();
  }

  // The scanner that grabs moods for a specific day
  List<MoodEntry> _getMoodsForDay(DateTime day) {
    return myJournalEntries.where((entry) {
      return entry.date.year == day.year &&
             entry.date.month == day.month &&
             entry.date.day == day.day;
    }).toList();
  }

  // A quick helper to format the date nicely (e.g., "3/15/2026")
  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    // 🍋 1. Wrap everything in a TabController to handle the swipeable views!
    return DefaultTabController(
      length: 2, // We have 2 tabs: Patterns and Notes
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Journal', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),

              // --- 2. The Custom Tab Bar ---
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
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  unselectedLabelColor: Colors.grey[500],
                  dividerColor: Colors.transparent, // Hides the default bottom underline
                  tabs: const [
                    Tab(text: 'Patterns'),
                    Tab(text: 'Daily Notes'),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              // --- 3. The Tab Views ---
              Expanded(
                child: TabBarView(
                  children: [
                    _buildPatternTab(),
                    _buildNotesTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // TAB 1: PATTERN RECOGNITION (CALENDAR)
  // ==========================================
  Widget _buildPatternTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Pattern Recognition', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            // Displays the currently selected date
            Text(
              _selectedDay != null ? _formatDate(_selectedDay!) : '', 
              style: TextStyle(color: Colors.yellow[800], fontWeight: FontWeight.bold)
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        Card(
          elevation: 0,
          color: Colors.yellow[50],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: TableCalendar(
              firstDay: DateTime.utc(2023, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              
              onDaySelected: (selectedDay, focusedDay) {
                if (!isSameDay(_selectedDay, selectedDay)) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                  _selectedEvents.value = _getMoodsForDay(selectedDay);
                }
              },
              
              eventLoader: _getMoodsForDay,
              calendarBuilders: CalendarBuilders(
                markerBuilder: (context, date, events) {
                  if (events.isNotEmpty) {
                    final entry = events.last as MoodEntry;
                    return Positioned(
                      bottom: -2,
                      child: Text(entry.emoji, style: const TextStyle(fontSize: 16)),
                    );
                  }
                  return null;
                },
              ),
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              calendarStyle: CalendarStyle(
                todayDecoration: BoxDecoration(color: Colors.yellow[300], shape: BoxShape.circle),
                selectedDecoration: BoxDecoration(color: Colors.yellow[700], shape: BoxShape.circle),
                markerDecoration: const BoxDecoration(), 
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
  Widget _buildNotesTab() {
    return ValueListenableBuilder<List<MoodEntry>>(
      valueListenable: _selectedEvents,
      builder: (context, value, _) {
        
        // 🍋 Mini Analytics Logic: Count how many times each emoji appears!
        Map<String, int> moodTallies = {};
        for (var entry in value) {
          moodTallies[entry.emoji] = (moodTallies[entry.emoji] ?? 0) + 1;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header showing total notes
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Notes for ${_formatDate(_selectedDay!)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: Colors.yellow[200], borderRadius: BorderRadius.circular(12)),
                  child: Text('${value.length} Entries', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // The Scrollable List of Notes
            Expanded(
              child: value.isEmpty 
                ? Center(child: Text('No lemonade squeezed on this day!', style: TextStyle(color: Colors.grey[500], fontStyle: FontStyle.italic)))
                : ListView.builder(
                    itemCount: value.length,
                    itemBuilder: (context, index) {
                      final entry = value[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        color: Colors.yellow[100], 
                        elevation: 0,
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: Text(entry.emoji, style: const TextStyle(fontSize: 32)),
                          title: Text(entry.mood, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (entry.note.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(entry.note, style: TextStyle(color: Colors.grey[800])),
                              ],
                              if (entry.tags.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 4,
                                  children: entry.tags.map((tag) => Text('#$tag', style: TextStyle(color: Colors.yellow[800], fontWeight: FontWeight.bold))).toList(),
                                )
                              ]
                            ],
                          ),
                        ),
                      );
                    },
                  ),
            ),

            // 🍋 The Mini Analytics Bottom Card
            if (value.isNotEmpty) ...[
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
                    Text('Daily Analytics', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[600])),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      children: moodTallies.entries.map((tally) {
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(tally.key, style: const TextStyle(fontSize: 24)), // The Emoji
                            const SizedBox(width: 4),
                            Text('x${tally.value}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), // The Count
                          ],
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ]
          ],
        );
      },
    );
  }
}