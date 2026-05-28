import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:audioplayers/audioplayers.dart';
import 'cloud_service.dart';

class NewEntrySheet extends StatefulWidget {
  const NewEntrySheet({super.key});

  @override
  State<NewEntrySheet> createState() => _NewEntrySheetState();
}

class _NewEntrySheetState extends State<NewEntrySheet>
    with TickerProviderStateMixin {
  String? _selectedMood;
  final TextEditingController _titleController = TextEditingController();
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

  // Audio Engine Controller
  late AudioPlayer _audioPlayer;

  // 🍋 Uniform, singular emoji maps
  final List<Map<String, String>> _moods = [
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

    _audioPlayer = AudioPlayer();

    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _successController,
      curve: Curves.easeOutBack,
    );

    _rotationAnimation = Tween<double>(begin: -0.2, end: 0.0).animate(
      CurvedAnimation(parent: _successController, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _successController.dispose();
    _audioPlayer.dispose();
    _titleController.dispose();
    _noteController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  void _playSuccessSound() async {
    try {
      await _audioPlayer.play(AssetSource('audios/success.mp3'));
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
          backgroundColor: Colors.white,
          title: const Text(
            'Add Custom Mood',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: customEmojiController,
                  decoration: const InputDecoration(
                    labelText: 'Emoji (e.g., 🍕)',
                    hintText: 'Enter an emoji',
                  ),
                  maxLength: 1,
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
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.yellow[600],
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Add',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
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
            // 🍋 FIX: Added SingleChildScrollView to make the page scrollable when the keyboard is open
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),

                  // --- Header ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'New Entry',
                        style: TextStyle(
                          fontSize: 26,
                          color: Colors.black,
                          letterSpacing: -0.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: Colors.black,
                          size: 26,
                        ),
                        onPressed: () {
                          if (_isListening) _speech.stop();
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // --- Title Input Field ---
                  const Text(
                    "Title",
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _titleController,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Give your entry a title...',
                      filled: true,
                      fillColor: Colors.grey[50],
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // --- Mood Selector Area ---
                  const Text(
                    "Select Mood",
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 10),

                  SizedBox(
                    height: 86,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: _moods.length + 1,
                      itemBuilder: (context, index) {
                        if (index == _moods.length) {
                          return Padding(
                            padding: const EdgeInsets.only(
                              right: 8.0,
                              top: 4,
                              bottom: 4,
                            ),
                            child: GestureDetector(
                              onTap: _showAddCustomMoodDialog,
                              child: Container(
                                width: 68,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(
                                    color: Colors.grey[200]!,
                                    width: 1.5,
                                  ),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add,
                                      size: 24,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Custom',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }

                        final _mood = _moods[index];
                        final isSelected = _selectedMood == _mood['label'];

                        return Padding(
                          padding: const EdgeInsets.only(
                            right: 10.0,
                            top: 4,
                            bottom: 4,
                          ),
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _selectedMood = _mood['label']),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOutCubic,
                              width: 68,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.yellow[50]
                                    : Colors.grey[50],
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.yellow[600]!
                                      : Colors.transparent,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: Colors.yellow[600]!
                                              .withOpacity(0.15),
                                          blurRadius: 6,
                                          offset: const Offset(0, 3),
                                        ),
                                      ]
                                    : [],
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  AnimatedScale(
                                    scale: isSelected ? 1.15 : 1.0,
                                    duration: const Duration(milliseconds: 200),
                                    child: Text(
                                      _mood['emoji']!,
                                      style: const TextStyle(fontSize: 26),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _mood['label']!,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: isSelected
                                          ? FontWeight.w800
                                          : Kish().weightMapping,
                                      color: isSelected
                                          ? Colors.yellow[900]
                                          : Colors.black87,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),

                  // --- Notes Field Header and Mic Action Row ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "What's on your mind? (optional)",
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: _isListening
                              ? Colors.red[50]
                              : Colors.yellow[100],
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: Icon(
                            _isListening ? Icons.stop : Icons.mic,
                            color: _isListening
                                ? Colors.red
                                : Colors.yellow[800],
                            size: 18,
                          ),
                          onPressed: _isSaving ? null : _toggleListening,
                          tooltip: _isListening
                              ? 'Stop listening'
                              : 'Record voice note',
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(6),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // 🍋 FIX: Swapped Expanded to a fixed height Container so it plays nice inside the ScrollView
                  Container(
                    height: 160,
                    child: TextField(
                      controller: _noteController,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      decoration: InputDecoration(
                        hintText: 'Write a note...',
                        filled: true,
                        fillColor: Colors.grey[50],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // --- Tags Field ---
                  // ✅ After
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Tags (optional)",
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                      // 🍋 "+" button that opens the input sheet
                      GestureDetector(
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.white,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(20),
                              ),
                            ),
                            builder: (context) => Padding(
                              padding: EdgeInsets.only(
                                bottom: MediaQuery.of(
                                  context,
                                ).viewInsets.bottom,
                                left: 24,
                                right: 24,
                                top: 24,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Add a tag',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: _tagController,
                                    autofocus: true,
                                    decoration: InputDecoration(
                                      hintText: 'e.g. Work, Gym, Family',
                                      filled: true,
                                      fillColor: Colors.grey[50],
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide.none,
                                      ),
                                    ),
                                    onSubmitted: (val) {
                                      _addTag(val);
                                      Navigator.pop(context);
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: () {
                                        _addTag(_tagController.text);
                                        Navigator.pop(context);
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.yellow[600],
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 14,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                      child: const Text(
                                        'Add Tag',
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                ],
                              ),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Icon(
                            Icons.add,
                            size: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // 🍋 Chips only appear once tags are added
                  if (_tags.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _tags
                          .map(
                            (tag) => Chip(
                              label: Text(
                                tag,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              onDeleted: () =>
                                  setState(() => _tags.remove(tag)),
                              backgroundColor: Colors.white,
                              side: BorderSide(color: Colors.grey[200]!),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  const SizedBox(height: 24),
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
                  return Opacity(opacity: opacityValue, child: child);
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
                            child: const Text(
                              '🍋',
                              style: TextStyle(fontSize: 110),
                            ),
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
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: _isSaving
                      ? null
                      : () {
                          if (_isListening) _speech.stop();
                          Navigator.pop(context);
                        },
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSaving
                      ? null
                      : () async {
                          if (_titleController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Please give your entry a title first!',
                                ),
                              ),
                            );
                            return;
                          }

                          if (_selectedMood == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please select a mood first!'),
                              ),
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

                          final emoji = _moods.firstWhere(
                            (m) => m['label'] == _selectedMood,
                          )['emoji']!;

                          await CloudService.saveMoodEntry(
                            _titleController.text.trim(),
                            _selectedMood!,
                            emoji,
                            _noteController.text.trim(),
                            List<String>.from(_tags),
                          );

                          if (mounted) {
                            setState(() {
                              _showSuccessAnimation = true;
                            });
                            _successController.forward();
                            _playSuccessSound();
                          }

                          await Future.delayed(
                            const Duration(milliseconds: 1400),
                          );

                          if (context.mounted) {
                            Navigator.pop(context, true);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.yellow[600],
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    _isSaving ? 'Saving...' : 'Save',
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
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

class Kish {
  FontWeight get weightMapping => FontWeight.w500;
}
