// lib/mood_entry.dart

class MoodEntry {
  final String mood;
  final String emoji;
  final String note;
  final List<String> tags;
  final DateTime date;

  MoodEntry({
    required this.mood,
    required this.emoji,
    required this.note,
    required this.tags,
    required this.date,
  });
}

// This global list acts as our temporary "database" while we prototype!
List<MoodEntry> myJournalEntries = [];