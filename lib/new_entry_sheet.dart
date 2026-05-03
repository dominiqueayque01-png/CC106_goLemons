import 'package:flutter/material.dart';
import 'cloud_service.dart'; // 🍋 NEW: Import our database engine!

class NewEntrySheet extends StatefulWidget {
  const NewEntrySheet({super.key});

  @override
  State<NewEntrySheet> createState() => _NewEntrySheetState();
}

class _NewEntrySheetState extends State<NewEntrySheet> {
  // 1. Variables to remember what the user selects
  String? _selectedMood;
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _tagController = TextEditingController();
  final List<String> _tags = []; 
  
  bool _isSaving = false; // 🍋 NEW: Keeps track of when we are talking to the cloud

  // List of default moods
  List<Map<String, String>> _moods = [
    {'label': 'Happy', 'emoji': '😊'},
    {'label': 'Neutral', 'emoji': '😐'},
    {'label': 'Sad', 'emoji': '😢'},
    {'label': 'Angry', 'emoji': '😡'},
    {'label': 'Anxious', 'emoji': '😨'},
  ];

  // Logic to add a tag when the user presses Enter
  void _addTag(String tag) {
    if (tag.trim().isNotEmpty && !_tags.contains(tag.trim())) {
      setState(() {
        _tags.add(tag.trim());
      });
      _tagController.clear();
    }
  }

  // Function to show a pop-up dialog for custom moods
  void _showAddCustomMoodDialog() {
    final TextEditingController customEmojiController = TextEditingController();
    final TextEditingController customLabelController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Custom Mood'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: customEmojiController,
                decoration: const InputDecoration(
                  labelText: 'Emoji (e.g., 🍕)',
                  hintText: 'Enter an emoji',
                ),
                maxLength: 2, 
              ),
              TextField(
                controller: customLabelController,
                decoration: const InputDecoration(
                  labelText: 'Label (e.g., Hungry)',
                  hintText: 'Enter a feeling',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                final emoji = customEmojiController.text.trim();
                final label = customLabelController.text.trim();

                if (emoji.isNotEmpty && label.isNotEmpty) {
                  setState(() {
                    _moods.add({'label': label, 'emoji': emoji});
                    _selectedMood = label; 
                  });
                  Navigator.pop(context); 
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.yellow[600]),
              child: const Text('Add', style: TextStyle(color: Colors.black)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: screenHeight * 0.9,
      padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: bottomInset + 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Header ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('New Entry', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context), 
              ),
            ],
          ),
          const SizedBox(height: 20),

          // --- Mood Selector ---
          Row(
            children: [
              ..._moods.map((mood) {
                final isSelected = _selectedMood == mood['label'];
                
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6.0),
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedMood = mood['label']),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.yellow[100] : Colors.grey[50],
                          border: Border.all(
                            color: isSelected ? Colors.yellow[700]! : Colors.grey[200]!,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Text(mood['emoji']!, style: const TextStyle(fontSize: 26)), 
                            const SizedBox(height: 2),
                            Text(
                              mood['label']!, 
                              style: TextStyle(
                                fontSize: 10, 
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
                              ),
                              overflow: TextOverflow.ellipsis, 
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }), 

              Expanded(
                child: GestureDetector(
                  onTap: _showAddCustomMoodDialog,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey[300]!, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.add, size: 30, color: Colors.grey[400]),
                        const SizedBox(height: 2),
                        const Text(
                          'Custom', 
                          style: TextStyle(fontSize: 10, color: Colors.grey),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // --- Notes Field ---
          const Text("What's on your mind? (optional)", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          
          Expanded(
            child: TextField(
              controller: _noteController,
              maxLines: null, 
              expands: true,  
              textAlignVertical: TextAlignVertical.top, 
              decoration: InputDecoration(
                hintText: 'Write a note...',
                filled: true,
                fillColor: Colors.grey[50],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // --- Tags Field ---
          const Text("Add tags (optional)", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: _tagController,
            decoration: InputDecoration(
              hintText: 'Type a tag and press enter',
              filled: true,
              fillColor: Colors.grey[50],
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
            onSubmitted: _addTag,
          ),
          const SizedBox(height: 12),
          
          Wrap(
            spacing: 8,
            children: _tags.map((tag) => Chip(
              label: Text(tag),
              onDeleted: () => setState(() => _tags.remove(tag)),
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            )).toList(),
          ),
          const SizedBox(height: 24),

          // --- Action Buttons ---
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontSize: 16)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  // 🍋 NEW: Disable the button while it's saving to prevent double-entries
                  onPressed: _isSaving ? null : () async {
                    if (_selectedMood == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please select a mood first!')),
                      );
                      return;
                    }

                    // 1. Turn on the loading state
                    setState(() {
                      _isSaving = true;
                    });

                    final emoji = _moods.firstWhere((m) => m['label'] == _selectedMood)['emoji']!;

                    // 🍋 2. Send the exact same data to the Cloud instead of the local list!
                    await CloudService.saveMoodEntry(
                      _selectedMood!,
                      emoji,
                      _noteController.text.trim(),
                      List.from(_tags),
                    );

                    // 3. Once Firebase finishes, close the bottom sheet
                    if (context.mounted) {
                      Navigator.pop(context, true);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.yellow[600],
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  // 🍋 NEW: Show "Saving..." text while the cloud is working
                  child: Text(
                    _isSaving ? 'Saving...' : 'Save', 
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}