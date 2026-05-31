import 'package:flutter/material.dart';
import 'notification_service.dart';

class NotificationSettingsSheet extends StatefulWidget {
  const NotificationSettingsSheet({super.key});

  @override
  State<NotificationSettingsSheet> createState() =>
      _NotificationSettingsSheetState();
}

class _NotificationSettingsSheetState
    extends State<NotificationSettingsSheet> {
  bool _isEnabled = false;
  TimeOfDay _selectedTime = const TimeOfDay(hour: 20, minute: 0);
  bool _isLoading = true;
  bool _isSaving = false;
  bool _notifPermissionGranted = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final prefs = await NotificationService.loadPreferences();
    final permitted = await NotificationService.areNotificationsEnabled();
    setState(() {
      _isEnabled = prefs['enabled'] as bool;
      _selectedTime = TimeOfDay(
        hour: prefs['hour'] as int,
        minute: prefs['minute'] as int,
      );
      _notifPermissionGranted = permitted;
      _isLoading = false;
    });
  }

  Future<void> _pickTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.yellow[700]!,
              onPrimary: Colors.black,
              onSurface: Colors.black87,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.yellow[800],
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedTime) {
      setState(() => _selectedTime = picked);
      if (_isEnabled) await _save();
    }
  }

  Future<void> _toggleEnabled(bool value) async {
    setState(() => _isEnabled = value);
    if (value) {
      await _save();
    } else {
      await NotificationService.cancelReminder();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Daily reminder turned off.'),
            backgroundColor: Colors.grey,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final success =
        await NotificationService.scheduleDailyReminder(_selectedTime);
    setState(() => _isSaving = false);

    if (!mounted) return;
    if (success) {
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Reminder set for ${_formatTime(_selectedTime)} daily! 🍋',
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Failed to schedule reminder. Check Alarms & Reminders permission in Settings.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // 🍋 Sends an immediate notification to verify it works
  Future<void> _testNow() async {
    await NotificationService.showImmediateNotification();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Test notification sent! Check your notification bar 🍋'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.yellow))
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),

                // Header + toggle
                Row(
                  children: [
                    const Text('🔔', style: TextStyle(fontSize: 24)),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Daily Reminder',
                              style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold)),
                          Text('Get nudged to journal every day',
                              style: TextStyle(
                                  fontSize: 13, color: Colors.grey)),
                        ],
                      ),
                    ),
                    Switch(
                      value: _isEnabled,
                      onChanged: _toggleEnabled,
                      activeColor: Colors.yellow[700],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 🍋 Permission warning if not granted
                if (!_notifPermissionGranted) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(10),
                      border:
                          Border.all(color: Colors.red[200]!, width: 1),
                    ),
                    child: Row(
                      children: [
                        const Text('⚠️',
                            style: TextStyle(fontSize: 18)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Notifications not permitted',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: Colors.redAccent),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Go to Settings → Apps → goLemons → Notifications and enable them. Also enable Alarms & Reminders.',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.red[700],
                                    height: 1.4),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                const Divider(height: 1),
                const SizedBox(height: 16),

                // Time picker
                const Text('Reminder Time',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87)),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _pickTime,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _isEnabled
                          ? Colors.yellow[50]
                          : Colors.grey[50],
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _isEnabled
                            ? Colors.yellow[300]!
                            : Colors.grey[200]!,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.access_time_rounded,
                            color: _isEnabled
                                ? Colors.yellow[800]
                                : Colors.grey[400],
                            size: 22),
                        const SizedBox(width: 12),
                        Text(
                          _formatTime(_selectedTime),
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: _isEnabled
                                ? Colors.black87
                                : Colors.grey[400],
                            letterSpacing: -0.5,
                          ),
                        ),
                        const Spacer(),
                        Icon(Icons.chevron_right,
                            color: _isEnabled
                                ? Colors.grey[400]
                                : Colors.grey[300]),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isEnabled
                      ? 'You\'ll get a daily nudge at ${_formatTime(_selectedTime)} 🍋'
                      : 'Turn on the toggle to enable daily reminders.',
                  style: TextStyle(
                      fontSize: 12,
                      color: _isEnabled
                          ? Colors.yellow[800]
                          : Colors.grey[400],
                      fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 20),

                // Action buttons
                if (_isEnabled) ...[
                  // Save button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.yellow[600],
                        disabledBackgroundColor: Colors.yellow[200],
                        elevation: 0,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        _isSaving ? 'Saving...' : 'Save Reminder',
                        style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // 🍋 Test button — sends immediate notification
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _testNow,
                      icon: const Text('🍋',
                          style: TextStyle(fontSize: 16)),
                      label: const Text('Send Test Notification Now',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.yellow[800],
                        side: BorderSide(
                            color: Colors.yellow[300]!, width: 1.5),
                        padding:
                            const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],

                SizedBox(
                    height: MediaQuery.of(context).padding.bottom + 8),
              ],
            ),
    );
  }
}