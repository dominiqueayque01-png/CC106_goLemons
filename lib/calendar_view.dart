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
          .snapshots();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _calendarAnimated = true;
        });
      }
    });
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

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
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: StreamBuilder<QuerySnapshot>(
            stream: _entriesStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
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
                  // --- 1. Balanced Header (Less Size, Semi-Bold Weight) ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Journal',
                        style: TextStyle(
                          fontSize: 22, // 🍋 Shrunk down from 32
                          fontWeight: FontWeight.w600, // 🍋 Clean Semi-Bold instead of Bold/Black
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

                  // --- 2. Clean Custom Tab Bar (Less Corner Radius, Added Accent Colors) ---
                  Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.yellow[50]!.withOpacity(0.5), // 🍋 Aesthetic tint background
                      borderRadius: BorderRadius.circular(10), // 🍋 Shrunk radius from 16 to 10
                      border: Border.all(color: Colors.yellow[100]!, width: 1),
                    ),
                    child: TabBar(
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicator: BoxDecoration(
                        color: Colors.yellow[600],
                        borderRadius: BorderRadius.circular(9), // 🍋 Inside matching radius
                        boxShadow: [
                          BoxShadow(
                            color: Colors.yellow[600]!.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          )
                        ],
                      ),
                      labelColor: Colors.black,
                      labelStyle: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                      unselectedLabelColor: Colors.yellow[800]!.withOpacity(0.7),
                      dividerColor: Colors.transparent,
                      tabs: const [
                        Tab(text: 'Patterns'),
                        Tab(text: 'Daily Notes'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // --- 3. Viewports Content Area ---
                  Expanded(
                    child: TabBarView(
                      physics: const BouncingScrollPhysics(),
                      children: [
                        // TAB 1: Patterns View (The Interactive Calendar Container)
                        AnimatedOpacity(
                          opacity: _calendarAnimated ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 400),
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12), // 🍋 Modern corner look
                                border: Border.all(color: Colors.grey[100]!, width: 1.5),
                              ),
                              child: TableCalendar(
                                firstDay: DateTime.utc(2020, 1, 1),
                                lastDay: DateTime.utc(2030, 12, 31),
                                focusedDay: _focusedDay,
                                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                                onDaySelected: (selectedDay, focusedDay) {
                                  setState(() {
                                    _selectedDay = selectedDay;
                                    _focusedDay = focusedDay;
                                  });
                                },
                                calendarBuilders: CalendarBuilders(
                                  markerBuilder: (context, date, events) {
                                    final dayEvents = getEventsForDay(date);
                                    if (dayEvents.isEmpty) return const SizedBox.shrink();
                                    
                                    String displayEmoji = dayEvents.first['emoji'] ?? '🍋';
                                    return Positioned(
                                      bottom: 2,
                                      child: Text(
                                        displayEmoji,
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    );
                                  },
                                ),
                                // 🍋 FIXED: Updated parameter property to titleTextStyle to avoid syntax warnings
                                headerStyle: HeaderStyle(
                                  formatButtonVisible: false,
                                  titleCentered: true,
                                  titleTextStyle: const TextStyle(
                                    fontWeight: FontWeight.w700, 
                                    fontSize: 16,
                                    color: Colors.black87,
                                  ),
                                  leftChevronIcon: Icon(Icons.chevron_left, color: Colors.yellow[700]),
                                  rightChevronIcon: Icon(Icons.chevron_right, color: Colors.yellow[700]),
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
                                  defaultTextStyle: const TextStyle(color: Colors.black87),
                                  outsideTextStyle: const TextStyle(color: Colors.grey),
                                ),
                              ),
                            ),
                          ),
                        ),

                        // TAB 2: Daily Feed Note Items View Layout
                        selectedDayEvents.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text('🍋', style: TextStyle(fontSize: 36, color: Colors.grey[300])),
                                    const SizedBox(height: 8),
                                    Text(
                                      'No entries on this day!',
                                      style: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.w500, fontSize: 14),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                physics: const BouncingScrollPhysics(),
                                itemCount: selectedDayEvents.length,
                                itemBuilder: (context, index) {
                                  final entry = selectedDayEvents[index];
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[50],
                                      borderRadius: BorderRadius.circular(10), // 🍋 Matching corner design
                                      border: Border.all(color: Colors.grey[100]!, width: 1),
                                    ),
                                    child: Row(
                                      children: [
                                        Text(entry['emoji'] ?? '🍋', style: const TextStyle(fontSize: 22)),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                entry['mood'] ?? 'Unknown',
                                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                              ),
                                              if (entry['note'] != null && entry['note'].toString().isNotEmpty) ...[
                                                const SizedBox(height: 3),
                                                Text(
                                                  entry['note'],
                                                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                                ),
                                              ]
                                            ],
                                          ),
                                        ),
                                      ],
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