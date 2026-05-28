import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:intl/intl.dart';
import 'cloud_service.dart';

class EntryDetailsView extends StatefulWidget {
  final String documentId;
  final String mood;
  final String emoji;
  final String initialNote;
  final String dateString;
  final String title;
  final List<String> tags;
  final DateTime? entryDate;

  const EntryDetailsView({
    super.key,
    required this.documentId,
    required this.mood,
    required this.emoji,
    required this.initialNote,
    required this.dateString,
    this.title = '',
    this.tags = const [],
    this.entryDate,
  });

  @override
  State<EntryDetailsView> createState() => _EntryDetailsViewState();
}

class _EntryDetailsViewState extends State<EntryDetailsView> {
  late TextEditingController _noteController;
  bool _isEditing = false;
  bool _isLoading = false;

  late stt.SpeechToText _speech;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(text: widget.initialNote);
    _speech = stt.SpeechToText();
    _speech.initialize();
  }

  @override
  void dispose() {
    _noteController.dispose();
    if (_isListening) _speech.stop();
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    if (!_isEditing) return true;

    final shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Discard changes?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'You have unsaved changes. Are you sure you want to go back?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Keep Editing',
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

    return shouldDiscard ?? false;
  }

  void _toggleListening() async {
    if (!_isEditing) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Tap the edit button first to start editing.'),
          backgroundColor: Colors.grey[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Microphone permission not granted.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } else {
      _speech.stop();
      setState(() => _isListening = false);
    }
  }

  Future<void> _saveChanges() async {
    setState(() => _isLoading = true);
    if (_isListening) {
      _speech.stop();
      setState(() => _isListening = false);
    }
    await CloudService.updateMoodEntry(
      widget.documentId,
      _noteController.text.trim(),
    );
    setState(() {
      _isLoading = false;
      _isEditing = false;
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Changes saved! 🍋'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _deleteEntry() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Entry?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to permanently delete this memory?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
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
              'Delete',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    setState(() => _isLoading = true);
    await CloudService.deleteMoodEntry(widget.documentId);
    if (!mounted) return;
    Navigator.pop(context);
  }

  String _formattedDate() {
    final date = widget.entryDate ?? DateTime.now();
    return DateFormat('MM/dd/yyyy').format(date);
  }

  String _formattedTime() {
    final date = widget.entryDate ?? DateTime.now();
    return DateFormat('hh:mma').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.black87),
          centerTitle: true,
          title: Column(
            children: [
              Text(
                _formattedDate(),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              Text(
                _formattedTime(),
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: _isLoading ? null : _deleteEntry,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.yellow),
              )
            : SafeArea(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- Title + Emoji inline ---
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              widget.title.isNotEmpty
                                  ? widget.title
                                  : widget.mood,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.5,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.yellow[50],
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.yellow[200]!,
                                width: 1.5,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                widget.emoji,
                                style: const TextStyle(fontSize: 24),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // --- Tags below title ---
                      if (widget.tags.isNotEmpty) ...[
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: widget.tags
                              .map(
                                (tag) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.grey[200]!,
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    '#$tag',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                        const SizedBox(height: 16),
                      ] else
                        const SizedBox(height: 4),

                      // --- Mic button (always visible, right aligned) ---
                      Align(
                        alignment: Alignment.centerRight,
                        child: GestureDetector(
                          onTap: _toggleListening,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.all(10),
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
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // --- Journal Note Card ---
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.grey[200]!,
                            width: 1,
                          ),
                        ),
                        child: TextField(
                          controller: _noteController,
                          enabled: _isEditing,
                          maxLines: null,
                          style: TextStyle(
                            fontSize: 16,
                            height: 1.65,
                            color: _isEditing
                                ? Colors.black87
                                : Colors.grey[700],
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: _isEditing
                                ? 'Write your thoughts here...'
                                : 'No note added.',
                            hintStyle: TextStyle(color: Colors.grey[400]),
                            filled: false,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        floatingActionButton: FloatingActionButton(
          onPressed: _isLoading
              ? null
              : () {
                  if (_isEditing) {
                    _saveChanges();
                  } else {
                    setState(() => _isEditing = true);
                  }
                },
          backgroundColor: _isEditing ? Colors.green[400] : Colors.yellow[600],
          elevation: 4,
          child: Icon(
            _isEditing ? Icons.check : Icons.edit,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }
}
