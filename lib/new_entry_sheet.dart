import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:audioplayers/audioplayers.dart';
import 'package:intl/intl.dart';
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
  final FocusNode _titleFocus = FocusNode();
  final FocusNode _noteFocus = FocusNode();

  bool _isSaving = false;

  // Speech to text
  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _speechEnabled = false;

  // Success animation
  bool _showSuccessAnimation = false;
  late AnimationController _successController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;

  // Audio
  late AudioPlayer _audioPlayer;

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
    _titleFocus.dispose();
    _noteFocus.dispose();
    super.dispose();
  }

  void _playSuccessSound() async {
    try {
      await _audioPlayer.play(AssetSource('audios/success.mp3'));
    } catch (e) {
      print("Audio error: $e");
    }
  }

  void _initSpeech() async {
    try {
      bool available = await _speech.initialize(
        onError: (val) => print('Speech error: $val'),
      );
      if (mounted) setState(() => _speechEnabled = available);
    } catch (e) {
      print("Speech init failed: $e");
    }
  }

  // 🍋 True if user has typed anything or selected a mood
  bool get _hasChanges =>
      _titleController.text.trim().isNotEmpty ||
      _noteController.text.trim().isNotEmpty ||
      _tags.isNotEmpty ||
      _selectedMood != null;

  // 🍋 Warning dialog shown when closing with unsaved changes
  Future<void> _confirmDiscard() async {
    if (!_hasChanges) {
      if (_isListening) _speech.stop();
      Navigator.pop(context);
      return;
    }

    final shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Discard entry?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'You have unsaved changes. Are you sure you want to leave?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Keep Writing',
              style: TextStyle(
                color: Colors.yellow[800],
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Discard',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (shouldDiscard == true) {
      if (_isListening) _speech.stop();
      if (context.mounted) Navigator.pop(context);
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Microphone permission not granted.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } else {
      _speech.stop();
      setState(() => _isListening = false);
    }
  }

  void _addTag(String tag) {
    if (tag.trim().isNotEmpty && !_tags.contains(tag.trim())) {
      setState(() => _tags.add(tag.trim()));
      _tagController.clear();
    }
  }

  void _showAddCustomMoodDialog() {
    final TextEditingController customEmojiController = TextEditingController();
    final TextEditingController customLabelController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Add Custom Mood',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: customEmojiController,
              decoration: const InputDecoration(
                labelText: 'Emoji (e.g. 🍕)',
                hintText: 'Enter an emoji',
              ),
              maxLength: 2,
            ),
            TextField(
              controller: customLabelController,
              decoration: const InputDecoration(
                labelText: 'Label (e.g. Hungry)',
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
      ),
    );
  }

  void _showAddTagSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
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
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
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
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateStr = DateFormat('MMMM d, yyyy').format(now).toUpperCase();
    final timeStr = DateFormat('hh:mm a').format(now);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12), // 🍋 reduced from 24
                  // --- Top bar: Title + Close ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'New Entry',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.3,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: Colors.black,
                          size: 22,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: _confirmDiscard,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12), // 🍋 reduced from 20
                  // --- Mood Selector ---
                  const Text(
                    'Select Mood',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: Colors.black54,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 8), // 🍋 reduced from 10
                  // 🍋 Smaller carousel — height 64, width 52, emoji 20
                  SizedBox(
                    height: 64,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: _moods.length + 1,
                      itemBuilder: (context, index) {
                        if (index == _moods.length) {
                          return Padding(
                            padding: const EdgeInsets.only(
                              right: 6.0,
                              top: 2,
                              bottom: 2,
                            ),
                            child: GestureDetector(
                              onTap: _showAddCustomMoodDialog,
                              child: Container(
                                width: 52,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(
                                    color: Colors.grey[200]!,
                                    width: 1.2,
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add,
                                      size: 18,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Custom',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey[400],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }
                        final mood = _moods[index];
                        final isSelected = _selectedMood == mood['label'];
                        return Padding(
                          padding: const EdgeInsets.only(
                            right: 8.0,
                            top: 2,
                            bottom: 2,
                          ),
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _selectedMood = mood['label']),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOutCubic,
                              width: 52,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.yellow[50]
                                    : Colors.grey[50],
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.yellow[600]!
                                      : Colors.transparent,
                                  width: 1.8,
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: Colors.yellow[600]!
                                              .withOpacity(0.12),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : [],
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  AnimatedScale(
                                    scale: isSelected ? 1.12 : 1.0,
                                    duration: const Duration(milliseconds: 200),
                                    child: Text(
                                      mood['emoji']!,
                                      style: const TextStyle(fontSize: 20),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    mood['label']!,
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: isSelected
                                          ? FontWeight.w800
                                          : FontWeight.w500,
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
                  const SizedBox(height: 16), // 🍋 reduced from 24
                  // ==========================================
                  // 🍋 UNIFIED JOURNAL CARD
                  // ==========================================
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey[200]!, width: 1.2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Date + Time header inside the card
                        Text(
                          dateStr,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Colors.grey[500],
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              size: 13,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              timeStr,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[400],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(height: 1, thickness: 1),
                        const SizedBox(height: 16),

                        // 🍋 Title field — large, bold
                        TextField(
                          controller: _titleController,
                          focusNode: _titleFocus,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                            letterSpacing: -0.3,
                            height: 1.3,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Title your thoughts...',
                            hintStyle: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey[300],
                              letterSpacing: -0.3,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          textInputAction: TextInputAction.next,
                          onSubmitted: (_) =>
                              FocusScope.of(context).requestFocus(_noteFocus),
                          maxLines: null,
                        ),
                        const SizedBox(height: 12),

                        // 🍋 Note field — seamlessly below title
                        TextField(
                          controller: _noteController,
                          focusNode: _noteFocus,
                          maxLines: null,
                          minLines: 5,
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey[700],
                            height: 1.6,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Begin writing your story here...',
                            hintStyle: TextStyle(
                              fontSize: 15,
                              color: Colors.grey[350] ?? Colors.grey[300],
                              height: 1.6,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),

                        // Mic button inside the card — bottom right
                        Align(
                          alignment: Alignment.centerRight,
                          child: GestureDetector(
                            onTap: _isSaving ? null : _toggleListening,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _isListening
                                    ? Colors.red[50]
                                    : Colors.yellow[100],
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _isListening ? Icons.stop : Icons.mic,
                                color: _isListening
                                    ? Colors.redAccent
                                    : Colors.yellow[800],
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // --- Tags ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Tags (optional)',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: Colors.black54,
                          letterSpacing: 0.3,
                        ),
                      ),
                      GestureDetector(
                        onTap: _showAddTagSheet,
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
                  if (_tags.isNotEmpty) ...[
                    const SizedBox(height: 10),
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
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // --- Success Overlay ---
          if (_showSuccessAnimation)
            Positioned.fill(
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 250),
                builder: (context, value, child) =>
                    Opacity(opacity: value, child: child),
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
                          builder: (context, slide, child) =>
                              Transform.translate(
                                offset: Offset(0, slide),
                                child: child,
                              ),
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

      // --- Bottom Action Buttons ---
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: _isSaving ? null : _confirmDiscard,
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
                          if (_isListening) {
                            _speech.stop();
                            setState(() => _isListening = false);
                          }
                          setState(() => _isSaving = true);

                          // 🍋 Use defaults if title or mood not provided
                          final String finalTitle =
                              _titleController.text.trim().isEmpty
                              ? 'Unnamed Journal'
                              : _titleController.text.trim();

                          final String finalMood = _selectedMood ?? 'No Mood';

                          final String finalEmoji = _selectedMood != null
                              ? _moods.firstWhere(
                                  (m) => m['label'] == _selectedMood,
                                  orElse: () => {
                                    'label': 'No Mood',
                                    'emoji': '🍋',
                                  },
                                )['emoji']!
                              : '🍋';

                          await CloudService.saveMoodEntry(
                            finalTitle,
                            finalMood,
                            finalEmoji,
                            _noteController.text.trim(),
                            List<String>.from(_tags),
                          );

                          if (mounted) {
                            setState(() => _showSuccessAnimation = true);
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
