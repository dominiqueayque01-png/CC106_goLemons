import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt; // 🍋 Import Speech engine [cite: 113]
import 'cloud_service.dart'; // 🍋 Import our database engine! [cite: 113]

class NewEntrySheet extends StatefulWidget {
  const NewEntrySheet({super.key});

  @override
  State<NewEntrySheet> createState() => _NewEntrySheetState();
}

class _NewEntrySheetState extends State<NewEntrySheet> {
  String? _selectedMood; // [cite: 115]
  final TextEditingController _noteController = TextEditingController(); // [cite: 115]
  final TextEditingController _tagController = TextEditingController(); // [cite: 115]
  final List<String> _tags = []; // [cite: 116]
  
  bool _isSaving = false; // [cite: 116]

  // 🍋 Speech to text variables [cite: 116]
  late stt.SpeechToText _speech; // [cite: 116]
  bool _isListening = false; // [cite: 117]
  bool _speechEnabled = false; // [cite: 117]

  List<Map<String, String>> _moods = [
    {'label': 'Happy', 'emoji': '😊'},
    {'label': 'Neutral', 'emoji': '😐'},
    {'label': 'Sad', 'emoji': '😢'},
    {'label': 'Angry', 'emoji': '😡'},
    {'label': 'Anxious', 'emoji': '😨'},
  ]; // [cite: 117]

  @override
  void initState() {
    super.initState(); // [cite: 118]
    _speech = stt.SpeechToText(); // [cite: 118]
    _initSpeech(); // Start speech services on widget load [cite: 118, 119]
  }

  // 🍋 Initialize phone hardware speech engine safely [cite: 119]
  void _initSpeech() async {
    try {
      bool available = await _speech.initialize(
        onError: (val) => print('Speech Init Error: $val'),
        onStatus: (val) => print('Speech Init Status: $val'),
      ); // [cite: 119]
      if (mounted) {
        setState(() {
          _speechEnabled = available; // [cite: 120]
        });
      }
    } catch (e) {
      print("Speech Initialization Failed completely: $e"); // [cite: 121]
    }
  }

  // 🍋 Microphone record execution loop [cite: 122]
  void _toggleListening() async {
    if (!_isListening) {
      bool available = await _speech.initialize(); // [cite: 122]
      if (available) {
        setState(() => _isListening = true); // [cite: 123]
        // Save whatever user already typed out so we don't clear it! [cite: 124]
        String baseText = _noteController.text; // [cite: 124]
        _speech.listen(
          onResult: (val) {
            setState(() {
              // Append newly spoken words seamlessly to old note inputs! [cite: 125]
              if (val.recognizedWords.isNotEmpty) {
                _noteController.text = baseText.isEmpty 
                    ? val.recognizedWords // [cite: 125]
                    : '$baseText ${val.recognizedWords}'; // [cite: 126]
                
                // Keep the typing selection cursor right at the end of the text [cite: 126]
                _noteController.selection = TextSelection.fromPosition(
                  TextPosition(offset: _noteController.text.length), // [cite: 127]
                );
              }
            });
          },
        );
      } else {
        _showMicError("Microphone hardware or device permissions not granted."); // [cite: 128]
      }
    } else {
      // User tapped button again, stop the session [cite: 129]
      _speech.stop(); // [cite: 129]
      setState(() => _isListening = false); // [cite: 130]
    }
  }

  void _showMicError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent), // [cite: 130]
    );
  }

  void _addTag(String tag) {
    if (tag.trim().isNotEmpty && !_tags.contains(tag.trim())) {
      setState(() {
        _tags.add(tag.trim()); // [cite: 131]
      });
      _tagController.clear(); // [cite: 132]
    }
  }

  void _showAddCustomMoodDialog() {
    final TextEditingController customEmojiController = TextEditingController(); // [cite: 132]
    final TextEditingController customLabelController = TextEditingController(); // [cite: 133]

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Custom Mood'), // [cite: 133]
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: customEmojiController, // [cite: 134]
                decoration: const InputDecoration(
                  labelText: 'Emoji (e.g., 🍕)', // [cite: 134]
                  hintText: 'Enter an emoji',
                ),
                maxLength: 2, // [cite: 135]
              ),
              TextField(
                controller: customLabelController, // [cite: 135]
                decoration: const InputDecoration(
                  labelText: 'Label (e.g., Hungry)', // [cite: 135]
                  hintText: 'Enter a feeling', // [cite: 136]
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), // [cite: 137]
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)), // [cite: 137]
            ),
            ElevatedButton(
              onPressed: () {
                final emoji = customEmojiController.text.trim(); // [cite: 137]
                final label = customLabelController.text.trim(); // [cite: 138]

                if (emoji.isNotEmpty && label.isNotEmpty) {
                  setState(() {
                    _moods.add({'label': label, 'emoji': emoji}); // [cite: 138]
                    _selectedMood = label; // [cite: 138]
                  });
                  Navigator.pop(context); // [cite: 139]
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.yellow[600]), // [cite: 139]
              child: const Text('Add', style: TextStyle(color: Colors.black)), // [cite: 139]
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // [cite: 140]
      
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0), // [cite: 140]
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, // [cite: 140]
            children: [
              const SizedBox(height: 35), // Your perfect manually adjusted height block! [cite: 141]

              // --- Header inside the safe area ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween, // [cite: 141]
                children: [
                  const Text('New Entry', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black)), // [cite: 142]
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.black, size: 28), // [cite: 142]
                    onPressed: () {
                      if (_isListening) _speech.stop(); // Stop mic if closed abruptly [cite: 143]
                      Navigator.pop(context); // [cite: 143]
                    }, 
                  ),
                ],
              ),
              const SizedBox(height: 24), // [cite: 144]

              // --- Mood Selector ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween, // [cite: 145]
                children: [
                  ..._moods.map((mood) {
                    final isSelected = _selectedMood == mood['label']; // [cite: 145]
                    
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 6.0), // [cite: 146]
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedMood = mood['label']), // [cite: 147]
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10), // [cite: 147]
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.yellow[100] : Colors.grey[50], // [cite: 148]
                              border: Border.all(
                                color: isSelected ? Colors.yellow[700]! : Colors.grey[200]!, // [cite: 149, 150]
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(12), // [cite: 150]
                            ),
                            child: Column(
                              children: [
                                Text(mood['emoji']!, style: const TextStyle(fontSize: 26)), // [cite: 152]
                                const SizedBox(height: 2), // [cite: 152]
                                Text(
                                  mood['label']!, // [cite: 153]
                                  style: TextStyle(
                                    fontSize: 10, // [cite: 153]
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal // [cite: 154]
                                  ),
                                  overflow: TextOverflow.ellipsis, // [cite: 155]
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
                      onTap: _showAddCustomMoodDialog, // [cite: 157]
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10), // [cite: 158]
                        decoration: BoxDecoration(
                          color: Colors.white, // [cite: 158]
                          border: Border.all(color: Colors.grey[300]!, width: 2), // [cite: 158]
                          borderRadius: BorderRadius.circular(12), // [cite: 159]
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.add, size: 30, color: Colors.grey[400]), // [cite: 160]
                            const SizedBox(height: 2), // [cite: 160]
                            const Text(
                              'Custom', // [cite: 161]
                              style: TextStyle(fontSize: 10, color: Colors.grey), // [cite: 161]
                              overflow: TextOverflow.ellipsis, // [cite: 161]
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24), // [cite: 163]

              // --- Notes Field Header and Mic Action Row ---
              // 🍋 NEW: Bound the section title and microphone button together in a responsive Row!
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "What's on your mind? (optional)", 
                    style: TextStyle(fontWeight: FontWeight.bold) // [cite: 164]
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: _isListening ? Colors.red[50] : Colors.yellow[100], // [cite: 169, 170]
                      shape: BoxShape.circle, // [cite: 170]
                    ),
                    child: IconButton(
                      icon: Icon(
                        _isListening ? Icons.stop : Icons.mic, // [cite: 171]
                        color: _isListening ? Colors.red : Colors.yellow[800], // [cite: 171]
                        size: 20, // Clean, proportional scaling next to the text
                      ),
                      onPressed: _isSaving ? null : _toggleListening, // [cite: 172]
                      tooltip: _isListening ? 'Stop listening' : 'Record voice note', // [cite: 173]
                      constraints: const BoxConstraints(), // Removes extra button padding bloating the row
                      padding: const EdgeInsets.all(8), // Tight, uniform circle padding bounding the icon
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8), // [cite: 164]
              
              Expanded(
                child: TextField(
                  controller: _noteController, // [cite: 164]
                  maxLines: null, // [cite: 165]
                  expands: true,  // [cite: 165]
                  textAlignVertical: TextAlignVertical.top, // [cite: 165]
                  decoration: InputDecoration(
                    hintText: 'Write a note...', // [cite: 165]
                    filled: true, // [cite: 166]
                    fillColor: Colors.grey[50], // [cite: 166]
                    // 🍋 REMOVED: suffixIcon structure deleted to maximize available character printing lines!
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), // [cite: 166]
                  ),
                ),
              ),
              const SizedBox(height: 20), // [cite: 174]

              // --- Tags Field ---
              const Text("Add tags (optional)", style: TextStyle(fontWeight: FontWeight.bold)), // [cite: 175]
              const SizedBox(height: 8), // [cite: 175]
              TextField(
                controller: _tagController, // [cite: 175]
                decoration: InputDecoration(
                  hintText: 'Type a tag and press enter', // [cite: 176]
                  filled: true, // [cite: 176]
                  fillColor: Colors.grey[50], // [cite: 176]
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), // [cite: 176]
                ),
                onSubmitted: _addTag, // [cite: 176]
              ),
              const SizedBox(height: 12), // [cite: 177]
              
              Wrap(
                spacing: 8, // [cite: 177]
                children: _tags.map((tag) => Chip(
                  label: Text(tag), // [cite: 178]
                  onDeleted: () => setState(() => _tags.remove(tag)), // [cite: 178]
                  backgroundColor: Colors.white, // [cite: 178]
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), // [cite: 178]
                )).toList(),
              ),
              const SizedBox(height: 16), // [cite: 179]
            ],
          ),
        ),
      ),

      // --- Action Buttons perfectly docked at the bottom ---
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24), // [cite: 180]
          child: Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () {
                    if (_isListening) _speech.stop(); // [cite: 180]
                    Navigator.pop(context); // [cite: 181]
                  },
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontSize: 16)), // [cite: 181]
                ),
              ),
              const SizedBox(width: 16), // [cite: 181]
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSaving ? null : () async { // [cite: 182]
                    if (_selectedMood == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please select a mood first!')), // [cite: 182, 183]
                      );
                      return;
                    }

                    // Turn off active mic sessions safely before running cloud push logic
                    if (_isListening) {
                      _speech.stop(); // [cite: 184]
                      setState(() => _isListening = false); // [cite: 184]
                    }

                    setState(() {
                      _isSaving = true; // [cite: 185]
                    });

                    final emoji = _moods.firstWhere((m) => m['label'] == _selectedMood)['emoji']!; // [cite: 185]
                    await CloudService.saveMoodEntry(
                      _selectedMood!, // [cite: 186]
                      emoji, // [cite: 186]
                      _noteController.text.trim(), // [cite: 186]
                      List.from(_tags), // [cite: 186]
                    );

                    if (context.mounted) {
                      Navigator.pop(context, true); // [cite: 188]
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.yellow[600], // [cite: 189]
                    padding: const EdgeInsets.symmetric(vertical: 16), // [cite: 189]
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), // [cite: 190]
                  ),
                  child: Text(
                    _isSaving ? 'Saving...' : 'Save', // [cite: 190]
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16) // [cite: 190]
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}