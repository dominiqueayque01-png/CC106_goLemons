import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  // FIX: Removed 'late' — controllers are initialized to empty objects at
  // declaration time so Flutter never hits a LateInitializationError if the
  // widget tree builds before initState fully completes.
  TextEditingController _titleController = TextEditingController();
  TextEditingController _noteController = TextEditingController();
  List<String> _tags = [];

  final TextEditingController _tagController = TextEditingController();

  bool _isEditing = false;
  bool _isLoading = false;
  DateTime? _editedAt;

  late stt.SpeechToText _speech;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    // Assign values after safe initialization above.
    _titleController.text = widget.title.isNotEmpty
        ? widget.title
        : widget.mood;
    _noteController.text = widget.initialNote;
    _tags = List<String>.from(widget.tags);

    _speech = stt.SpeechToText();
    _speech.initialize();

    _loadEditedAt();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    _tagController.dispose();
    if (_isListening) _speech.stop();
    super.dispose();
  }

  // ==========================================
  // 🍋 LOAD EDITED TIMESTAMP
  // ==========================================
  Future<void> _loadEditedAt() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('entries')
          .doc(widget.documentId)
          .get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['editedAt'] != null) {
          setState(() {
            _editedAt = (data['editedAt'] as Timestamp).toDate();
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading editedAt: $e');
    }
  }

  // ==========================================
  // 🍋 DISCARD WARNING
  // ==========================================
  bool get _hasChanges {
    final originalTitle = widget.title.isNotEmpty ? widget.title : widget.mood;
    return _titleController.text.trim() != originalTitle ||
        _noteController.text.trim() != widget.initialNote ||
        !_listEquals(_tags, widget.tags);
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<bool> _onWillPop() async {
    if (!_isEditing || !_hasChanges) return true;

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

  // ==========================================
  // 🍋 MIC TOGGLE
  // ==========================================
  void _toggleListening() async {
    if (!_isEditing) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Tap the edit button first.'),
          backgroundColor: Colors.grey[700],
          behavior: SnackBarBehavior.floating,
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
      }
    } else {
      _speech.stop();
      setState(() => _isListening = false);
    }
  }

  // ==========================================
  // 🍋 SAVE
  // ==========================================
  Future<void> _saveChanges() async {
    setState(() => _isLoading = true);
    if (_isListening) {
      _speech.stop();
      setState(() => _isListening = false);
    }

    final now = DateTime.now();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('entries')
          .doc(widget.documentId)
          .update({
            'title': _titleController.text.trim(),
            'note': _noteController.text.trim(),
            'tags': _tags,
            'editedAt': Timestamp.fromDate(now),
          });
    }

    setState(() {
      _isLoading = false;
      _isEditing = false;
      _editedAt = now;
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Changes saved! 🍋'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ==========================================
  // 🍋 DELETE
  // ==========================================
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

  // ==========================================
  // 🍋 TAG SHEET
  // ==========================================
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

  void _addTag(String tag) {
    if (tag.trim().isNotEmpty && !_tags.contains(tag.trim())) {
      setState(() => _tags.add(tag.trim()));
      _tagController.clear();
    }
  }

  // ==========================================
  // 🍋 FORMAT HELPERS
  // ==========================================
  String _formatDateTime(DateTime dt) => DateFormat('MM/dd/yyyy').format(dt);
  String _formatTime(DateTime dt) => DateFormat('hh:mma').format(dt);

  @override
  Widget build(BuildContext context) {
    final createdAt = widget.entryDate ?? DateTime.now();
    final dateStr = DateFormat('MMMM d, yyyy').format(createdAt).toUpperCase();
    final timeStr = DateFormat('hh:mm a').format(createdAt);

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) Navigator.of(context).pop();
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
                _formatDateTime(createdAt),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              Text(
                _formatTime(createdAt),
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
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- Mood emoji chip ---
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.yellow[50],
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.yellow[200]!,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  widget.emoji,
                                  style: const TextStyle(fontSize: 16),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  widget.mood,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.yellow[900],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // --- Journal Card ---
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _isEditing
                                ? Colors.yellow[300]!
                                : Colors.grey[200]!,
                            width: _isEditing ? 1.5 : 1.2,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
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
                                  size: 12,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  timeStr,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[400],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (_editedAt != null) ...[
                                  Text(
                                    '  •  ',
                                    style: TextStyle(
                                      color: Colors.grey[300],
                                      fontSize: 11,
                                    ),
                                  ),
                                  Icon(
                                    Icons.edit_outlined,
                                    size: 11,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    'Edited ${DateFormat('MMM d, hh:mma').format(_editedAt!)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[400],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 14),
                            const Divider(height: 1, thickness: 1),
                            const SizedBox(height: 14),

                            // Title
                            TextField(
                              controller: _titleController,
                              enabled: _isEditing,
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
                              maxLines: null,
                            ),
                            const SizedBox(height: 10),

                            // Note
                            TextField(
                              controller: _noteController,
                              enabled: _isEditing,
                              maxLines: null,
                              minLines: 4,
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.grey[700],
                                height: 1.6,
                              ),
                              decoration: InputDecoration(
                                hintText: _isEditing
                                    ? 'Write your thoughts here...'
                                    : 'No note added.',
                                hintStyle: TextStyle(
                                  fontSize: 15,
                                  color: Colors.grey[300],
                                  height: 1.6,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),

                            // Mic button
                            Align(
                              alignment: Alignment.centerRight,
                              child: GestureDetector(
                                onTap: _toggleListening,
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
                          Text(
                            'Tags',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: Colors.black54,
                              letterSpacing: 0.3,
                            ),
                          ),
                          if (_isEditing)
                            GestureDetector(
                              onTap: _showAddTagSheet,
                              child: Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                child: Icon(
                                  Icons.add,
                                  size: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_tags.isNotEmpty)
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: _tags
                              .map(
                                (tag) => _isEditing
                                    ? Chip(
                                        label: Text(
                                          '#$tag',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        onDeleted: () =>
                                            setState(() => _tags.remove(tag)),
                                        backgroundColor: Colors.white,
                                        side: BorderSide(
                                          color: Colors.grey[200]!,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      )
                                    : Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[100],
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
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
                        )
                      else
                        Text(
                          _isEditing ? 'Tap + to add tags' : 'No tags added.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[400],
                            fontStyle: FontStyle.italic,
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
