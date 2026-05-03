import 'package:flutter/material.dart';
import 'cloud_service.dart';

class EntryDetailsView extends StatefulWidget {
  // We pass in the data from the Home Screen when they tap a journal card
  final String documentId; 
  final String mood;
  final String emoji;
  final String initialNote;
  final String dateString;

  const EntryDetailsView({
    super.key,
    required this.documentId,
    required this.mood,
    required this.emoji,
    required this.initialNote,
    required this.dateString,
  });

  @override
  State<EntryDetailsView> createState() => _EntryDetailsViewState();
}

class _EntryDetailsViewState extends State<EntryDetailsView> {
  late TextEditingController _noteController;
  bool _isEditing = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Fill the text box with the journal entry's current text
    _noteController = TextEditingController(text: widget.initialNote);
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  // --- Backend Actions ---

  Future<void> _saveChanges() async {
    setState(() => _isLoading = true);
    
    // Call our new CloudService function!
    await CloudService.updateMoodEntry(widget.documentId, _noteController.text.trim());
    
    setState(() {
      _isLoading = false;
      _isEditing = false; // Turn off editing mode when saved
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Changes saved successfully! 🍋'), backgroundColor: Colors.green),
    );
  }

  Future<void> _deleteEntry() async {
    // 1. Ask for confirmation first so they don't accidentally delete!
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Entry?'),
        content: const Text('Are you sure you want to permanently delete this memory?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // 2. Delete from the cloud
    setState(() => _isLoading = true);
    await CloudService.deleteMoodEntry(widget.documentId);
    
    if (!mounted) return;
    Navigator.pop(context); // Close the screen and go back to Home
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          // The Trash Can Icon
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            onPressed: _isLoading ? null : _deleteEntry,
          ),
          // The Edit / Save Toggle Button
          IconButton(
            icon: Icon(_isEditing ? Icons.check : Icons.edit, color: Colors.blueAccent),
            onPressed: _isLoading 
              ? null 
              : () {
                  if (_isEditing) {
                    _saveChanges(); // If they were editing, hitting the checkmark saves it
                  } else {
                    setState(() => _isEditing = true); // Turn on editing mode
                  }
                },
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Header: The Mood and Date ---
                  Center(
                    child: Column(
                      children: [
                        Text(widget.emoji, style: const TextStyle(fontSize: 64)),
                        const SizedBox(height: 8),
                        Text(
                          widget.mood, 
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.dateString,
                          style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),

                  // --- The Journal Content ---
                  TextField(
                    controller: _noteController,
                    enabled: _isEditing, // Only editable if they clicked the Edit pencil!
                    maxLines: null, // Allows the text field to grow dynamically
                    style: TextStyle(
                      fontSize: 18, 
                      height: 1.6, 
                      color: _isEditing ? Colors.black : Colors.grey[800]
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none, // Removes the standard box for a clean paper look
                      hintText: 'Write your thoughts here...',
                      // Give it a subtle background only when editing so they know they can type
                      filled: _isEditing,
                      fillColor: Colors.yellow[50], 
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }
}