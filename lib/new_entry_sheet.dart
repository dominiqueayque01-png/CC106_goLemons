import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt; 
import 'package:audioplayers/audioplayers.dart'; // 🍋 NEW: Import the Audio Players package!
import 'cloud_service.dart'; 

class NewEntrySheet extends StatefulWidget {
  const NewEntrySheet({super.key});

  @override
  State<NewEntrySheet> createState() => _NewEntrySheetState();
}

class _NewEntrySheetState extends State<NewEntrySheet> with TickerProviderStateMixin {
  String? _selectedMood; 
  final TextEditingController _noteController = TextEditingController(); 
  final TextEditingController _tagController = TextEditingController(); 
  final List<String> _tags = []; 
  
  bool _isSaving = false; 

  // Speech to text variables
  late stt.SpeechToText _speech; 
  bool _isListening = false; 
  bool _speechEnabled = false; 

  // Fluid Animation Utilities
  bool _showSuccessAnimation = false;
  late AnimationController _successController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;

  // 🍋 NEW: Audio Engine Controller
  late AudioPlayer _audioPlayer;

  List<Map<String, String>> _moods = [
    {'label': 'Happy', 'emoji': '😊'},
    {'label': 'Neutral', 'emoji': '😐'},
    {'label': 'Sad', 'emoji': '😢'},
    {'label': 'Angry', 'emoji': '😡'},
    {'label': 'Anxious', 'emoji': '😨'},
  ]; 

  @override
  void initState() {
    super.initState(); 
    _speech = stt.SpeechToText(); 
    _initSpeech(); 

    // 🍋 Initialize the Audio Player
    _audioPlayer = AudioPlayer();

    // Initialize the success orchestration timeline controller
    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _successController,
      curve: Curves.easeOutBack,
    );

    _rotationAnimation = Tween<double>(begin: -0.2, end: 0.0).animate(
      CurvedAnimation(
        parent: _successController,
        curve: Curves.elasticOut,
      ),
    );
  }

  @override
  void dispose() {
    _successController.dispose();
    _audioPlayer.dispose(); // 🍋 NEW: Clean up the audio hardware when sheet closes
    _noteController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  // 🍋 NEW: Play the success sound tracking from local assets pool
  void _playSuccessSound() async {
    try {
      await _audioPlayer.play(AssetSource('success.mp3'));
    } catch (e) {
      print("Audio Playback Error: $e");
    }
  }

  void _initSpeech() async {
    try {
      bool available = await _speech.initialize(
        onError: (val) => print('Speech Init Error: $val'),
        onStatus: (val) => print('Speech Init Status: $val'),
      ); 
      if (mounted) {
        setState(() {
          _speechEnabled = available; 
        });
      }
    } catch (e) {
      print("Speech Initialization Failed completely: $e"); 
    }
  }

  void _toggleListening() async {
    if (!_isListening) {
      bool available = await _speech.initialize(); 
      if (available) {
        setState(() => _isListening = true); 
        String baseText = _noteController.text; 
        _speech.listen(
          onResult: (val) {
            setState(() {
              if (val.recognizedWords.isNotEmpty) {
                _noteController.text = baseText.isEmpty 
                    ? val.recognizedWords 
                    : '$baseText ${val.recognizedWords}'; 
                
                _noteController.selection = TextSelection.fromPosition(
                  TextPosition(offset: _noteController.text.length), 
                );
              }
            });
          },
        );
      } else {
        _showMicError("Microphone hardware or device permissions not granted."); 
      }
    } else {
      _speech.stop(); 
      setState(() => _isListening = false); 
    }
  }

  void _showMicError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent), 
    );
  }

  void _addTag(String tag) {
    if (tag.trim().isNotEmpty && !_tags.contains(tag.trim())) {
      setState(() {
        _tags.add(tag.trim()); 
      });
      _tagController.clear(); 
    }
  }

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
    return Scaffold(
      backgroundColor: Colors.white, 
      
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0), 
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, 
                children: [
                  const SizedBox(height: 35), 

                  // --- Header inside the safe area ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                    children: [
                      const Text('New Entry', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black)), 
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.black, size: 28), 
                        onPressed: () {
                          if (_isListening) _speech.stop(); 
                          Navigator.pop(context); 
                        }, 
                      ),
                    ],
                  ),
                  const SizedBox(height: 24), 

                  // --- Mood Selector ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween, 
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

                  // --- Notes Field Header and Mic Action Row ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "What's on your mind? (optional)", 
                        style: TextStyle(fontWeight: FontWeight.bold) 
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: _isListening ? Colors.red[50] : Colors.yellow[100], 
                          shape: BoxShape.circle, 
                        ),
                        child: IconButton(
                          icon: Icon(
                            _isListening ? Icons.stop : Icons.mic, 
                            color: _isListening ? Colors.red : Colors.yellow[800], 
                            size: 20, 
                          ),
                          onPressed: _isSaving ? null : _toggleListening, 
                          tooltip: _isListening ? 'Stop listening' : 'Record voice note', 
                          constraints: const BoxConstraints(), 
                          padding: const EdgeInsets.all(8), 
                        ),
                      ),
                    ],
                  ),
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
                  const SizedBox(height: 16), 
                ],
              ),
            ),
          ),

          // --- Animated Success Overlay ---
          if (_showSuccessAnimation)
            Positioned.fill(
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 250),
                builder: (context, opacityValue, child) {
                  return Opacity(
                    opacity: opacityValue,
                    child: child,
                  );
                },
                child: Container(
                  color: Colors.white.withOpacity(0.97),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ScaleTransition(
                          scale: _scaleAnimation,
                          child: RotationTransition(
                            turns: _rotationAnimation,
                            child: const Text('🍋', style: TextStyle(fontSize: 110)),
                          ),
                        ),
                        const SizedBox(height: 20),
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 15.0, end: 0.0),
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeOutCubic,
                          builder: (context, slideValue, child) {
                            return Transform.translate(
                              offset: Offset(0, slideValue),
                              child: child,
                            );
                          },
                          child: const Text(
                            'Squeezed Successfully!',
                            style: TextStyle(
                              fontSize: 24, 
                              fontWeight: FontWeight.bold, 
                              color: Colors.black,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),

      // --- Action Buttons docked at the bottom ---
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24), 
          child: Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: _isSaving ? null : () {
                    if (_isListening) _speech.stop(); 
                    Navigator.pop(context); 
                  },
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontSize: 16)), 
                ),
              ),
              const SizedBox(width: 16), 
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSaving ? null : () async { 
                    if (_selectedMood == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please select a mood first!')), 
                      );
                      return;
                    }

                    if (_isListening) {
                      _speech.stop(); 
                      setState(() => _isListening = false); 
                    }

                    setState(() {
                      _isSaving = true; 
                    });

                    final emoji = _moods.firstWhere((m) => m['label'] == _selectedMood)['emoji']!; 
                    await CloudService.saveMoodEntry(
                      _selectedMood!, 
                      emoji, 
                      _noteController.text.trim(), 
                      List.from(_tags), 
                    );

                    if (mounted) {
                      setState(() {
                        _showSuccessAnimation = true;
                      });
                      _successController.forward();
                      _playSuccessSound(); // 🍋 NEW: Fire the audio playback engine synchronously!
                    }

                    await Future.delayed(const Duration(milliseconds: 1400));

                    if (context.mounted) {
                      Navigator.pop(context, true); 
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.yellow[600], 
                    padding: const EdgeInsets.symmetric(vertical: 16), 
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), 
                  ),
                  child: Text(
                    _isSaving ? 'Saving...' : 'Save', 
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16) 
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