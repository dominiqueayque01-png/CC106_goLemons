import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CloudService {
  // 🍋 A helper function to save a new squeeze to the cloud (Now with Title!)
  static Future<void> saveMoodEntry(String title, String mood, String emoji, String note, List<String> tags) async {
    // 1. Find out who is currently using the app
    final user = FirebaseAuth.instance.currentUser;
    
    // Safety check: if nobody is logged in, cancel the save
    if (user == null) return; 

    // 2. Navigate through the folders: users -> [Their ID] -> entries
    // The .add() function automatically creates a random ID for the new entry!
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('entries')
        .add({
      'title': title, // 🍋 Now correctly resolves to the method parameter!
      'mood': mood,
      'emoji': emoji,
      'note': note,
      'tags': tags,
      'date': Timestamp.now(), // 🍋 Upgraded to Timestamp for cleaner TableCalendar compatibility
    });
  }

  static Future<void> updateMoodEntry(String entryId, String newNote) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return; 

    // We use .update() instead of .set() so we only overwrite the note, not the date or mood!
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('entries')
        .doc(entryId)
        .update({
      'note': newNote,
    });
  }

  static Future<void> deleteMoodEntry(String entryId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return; 

    // Finds the specific document by its ID and deletes it
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('entries')
        .doc(entryId)
        .delete();
  }
}