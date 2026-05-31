import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'entry_details_view.dart';
import 'modern_transitions.dart';

class CalendarView extends StatefulWidget {
  const CalendarView({super.key});

  @override
  State<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<CalendarView> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  bool _calendarAnimated = false;
  late Stream<QuerySnapshot> _entriesStream;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _entriesStream = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('entries')
          .orderBy('date', descending: true)
          .snapshots();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _calendarAnimated = true);
    });
  }

  String _formatDate(DateTime date) => '${date.month}/${date.day}/${date.year}';

  DateTime _normalizeDate(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day);

  // ==========================================
  // 🍋 BOTTOM SHEET — no firstWhere needed
  // ==========================================
  void _showDayBottomSheet(
    BuildContext context,
    DateTime day,
    List<Map<String, dynamic>> events,
  ) {
    if (events.isEmpty) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.85,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 16),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),

                // Date + count header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        DateFormat('MMMM d, yyyy').format(day),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.yellow[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${events.length} ${events.length == 1 ? 'entry' : 'entries'}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.yellow[800],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Divider(height: 1),
                ),
                const SizedBox(height: 8),

                // Entry list
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    physics: const BouncingScrollPhysics(),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    itemCount: events.length,
                    itemBuilder: (context, index) {
                      final entry = events[index];
                      // 🍋 documentId was injected during grouping — no firstWhere needed
                      final String docId = entry['documentId'] as String? ?? '';
                      final String title = entry['title'] as String? ?? '';
                      final String mood = entry['mood'] as String? ?? 'Unknown';
                      final String emoji = entry['emoji'] as String? ?? '🍋';
                      final String note = entry['note'] as String? ?? '';
                      final List<String> tags =
                          List<String>.from(entry['tags'] as List? ?? []);
                      final DateTime entryDate =
                          (entry['date'] as Timestamp).toDate();

                      return GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            ModernFadeRoute(
                              page: EntryDetailsView(
                                documentId: docId,
                                mood: mood,
                                emoji: emoji,
                                initialNote: note,
                                dateString:
                                    DateFormat('MMMM d, yyyy').format(entryDate),
                                title: title,
                                tags: tags,
                                entryDate: entryDate,
                              ),
                            ),
                          );
                        },
                        child: _EntryCard(
                          title: title,
                          mood: mood,
                          emoji: emoji,
                          note: note,
                          tags: tags,
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
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
          padding:
              const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: StreamBuilder<QuerySnapshot>(
            stream: _entriesStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(
                    child: CircularProgressIndicator(color: Colors.yellow));
              }
              if (snapshot.hasError) {
                return const Center(
                    child: Text('Error loading calendar data.'));
              }

              final allDocs = snapshot.hasData
                  ? snapshot.data!.docs
                  : <QueryDocumentSnapshot>[];

              // 🍋 Group by date AND inject documentId so we never need firstWhere
              final Map<DateTime, List<Map<String, dynamic>>> groupedEntries = {};
              for (final doc in allDocs) {
                final raw = doc.data() as Map<String, dynamic>;
                // Copy the map and inject the doc ID
                final data = Map<String, dynamic>.from(raw);
                data['documentId'] = doc.id;

                if (data['date'] != null) {
                  final entryDate = (data['date'] as Timestamp).toDate();
                  final key = _normalizeDate(entryDate);
                  groupedEntries[key] ??= [];
                  groupedEntries[key]!.add(data);
                }
              }

              List<Map<String, dynamic>> getEventsForDay(DateTime day) =>
                  groupedEntries[_normalizeDate(day)] ?? [];

              final selectedDayEvents =
                  getEventsForDay(_selectedDay ?? _focusedDay);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Header ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Journal',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: Color.fromARGB(255, 143, 115, 4),
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        _formatDate(_selectedDay ?? _focusedDay),
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // --- Tab Bar ---
                  Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.yellow[50]!.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.yellow[100]!, width: 1),
                    ),
                    child: TabBar(
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicator: BoxDecoration(
                        color: Colors.yellow[600],
                        borderRadius: BorderRadius.circular(9),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.yellow[600]!.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      labelColor: Colors.black,
                      labelStyle: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14),
                      unselectedLabelColor:
                          Colors.yellow[800]!.withOpacity(0.7),
                      dividerColor: Colors.transparent,
                      tabs: const [
                        Tab(text: 'Patterns'),
                        Tab(text: 'Daily Notes'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // --- Tab Content ---
                  Expanded(
                    child: TabBarView(
                      physics: const BouncingScrollPhysics(),
                      children: [

                        // ==========================================
                        // TAB 1: Patterns (Calendar)
                        // ==========================================
                        AnimatedOpacity(
                          opacity: _calendarAnimated ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 400),
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: Colors.grey[100]!, width: 1.5),
                              ),
                              child: TableCalendar(
                                firstDay: DateTime.utc(2020, 1, 1),
                                lastDay: DateTime.utc(2030, 12, 31),
                                focusedDay: _focusedDay,
                                selectedDayPredicate: (day) =>
                                    isSameDay(_selectedDay, day),
                                onDaySelected: (selectedDay, focusedDay) {
                                  setState(() {
                                    _selectedDay = selectedDay;
                                    _focusedDay = focusedDay;
                                  });
                                  // 🍋 Show bottom sheet if entries exist
                                  final events = getEventsForDay(selectedDay);
                                  if (events.isNotEmpty) {
                                    _showDayBottomSheet(
                                        context, selectedDay, events);
                                  }
                                },
                                calendarBuilders: CalendarBuilders(
                                  markerBuilder: (context, date, _) {
                                    final dayEvents = getEventsForDay(date);
                                    if (dayEvents.isEmpty) {
                                      return const SizedBox.shrink();
                                    }
                                    return Positioned(
                                      bottom: 2,
                                      child: Text(
                                        dayEvents.first['emoji'] as String? ??
                                            '🍋',
                                        style:
                                            const TextStyle(fontSize: 13),
                                      ),
                                    );
                                  },
                                ),
                                headerStyle: HeaderStyle(
                                  formatButtonVisible: false,
                                  titleCentered: true,
                                  titleTextStyle: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                    color: Colors.black87,
                                  ),
                                  leftChevronIcon: Icon(Icons.chevron_left,
                                      color: Colors.yellow[700]),
                                  rightChevronIcon: Icon(Icons.chevron_right,
                                      color: Colors.yellow[700]),
                                ),
                                calendarStyle: CalendarStyle(
                                  todayDecoration: BoxDecoration(
                                    color: Colors.yellow[100],
                                    shape: BoxShape.circle,
                                  ),
                                  selectedDecoration: BoxDecoration(
                                    color: Colors.yellow[500],
                                    shape: BoxShape.circle,
                                  ),
                                  selectedTextStyle: const TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  todayTextStyle: const TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  defaultTextStyle:
                                      const TextStyle(color: Colors.black87),
                                  outsideTextStyle:
                                      const TextStyle(color: Colors.grey),
                                ),
                              ),
                            ),
                          ),
                        ),

                        // ==========================================
                        // TAB 2: Daily Notes
                        // ==========================================
                        selectedDayEvents.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text('🍋',
                                        style: TextStyle(
                                            fontSize: 36,
                                            color: Colors.grey[300])),
                                    const SizedBox(height: 8),
                                    Text(
                                      'No entries on this day!',
                                      style: TextStyle(
                                        color: Colors.grey[400],
                                        fontWeight: FontWeight.w500,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Tap a day on Patterns to browse',
                                      style: TextStyle(
                                        color: Colors.grey[300],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                physics: const BouncingScrollPhysics(),
                                itemCount: selectedDayEvents.length,
                                itemBuilder: (context, index) {
                                  final entry = selectedDayEvents[index];
                                  final String docId =
                                      entry['documentId'] as String? ?? '';
                                  final String title =
                                      entry['title'] as String? ?? '';
                                  final String mood =
                                      entry['mood'] as String? ?? 'Unknown';
                                  final String emoji =
                                      entry['emoji'] as String? ?? '🍋';
                                  final String note =
                                      entry['note'] as String? ?? '';
                                  final List<String> tags = List<String>.from(
                                      entry['tags'] as List? ?? []);
                                  final DateTime entryDate =
                                      (entry['date'] as Timestamp).toDate();

                                  return GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        ModernFadeRoute(
                                          page: EntryDetailsView(
                                            documentId: docId,
                                            mood: mood,
                                            emoji: emoji,
                                            initialNote: note,
                                            dateString:
                                                DateFormat('MMMM d, yyyy')
                                                    .format(entryDate),
                                            title: title,
                                            tags: tags,
                                            entryDate: entryDate,
                                          ),
                                        ),
                                      );
                                    },
                                    child: _EntryCard(
                                      title: title,
                                      mood: mood,
                                      emoji: emoji,
                                      note: note,
                                      tags: tags,
                                    ),
                                  );
                                },
                              ),
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
}

// ==========================================
// 🍋 SHARED ENTRY CARD WIDGET
// ==========================================
class _EntryCard extends StatelessWidget {
  final String title;
  final String mood;
  final String emoji;
  final String note;
  final List<String> tags;

  const _EntryCard({
    required this.title,
    required this.mood,
    required this.emoji,
    required this.note,
    required this.tags,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.yellow[100]!, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.yellow[200]!.withOpacity(0.15),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Emoji circle
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.yellow[50],
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.isNotEmpty ? title : mood,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  mood,
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w500),
                ),
                if (note.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    note,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                ],
                if (tags.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    children: tags
                        .take(3)
                        .map((tag) => Text(
                              '#$tag',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.yellow[800],
                                fontWeight: FontWeight.w600,
                              ),
                            ))
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: Colors.grey[300], size: 20),
        ],
      ),
    );
  }
}