import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../database/database_helper.dart';
import '../providers/settings_provider.dart';
import '../services/notification_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _hasLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hasLoaded) {
      return;
    }

    _hasLoaded = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SettingsProvider>().loadSettings();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (BuildContext context, SettingsProvider settingsProvider, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Settings'),
          ),
          body: RefreshIndicator(
            onRefresh: settingsProvider.loadSettings,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: <Widget>[
                Text(
                  'Push Notification Times',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'FlashLang will send one vocabulary reminder at each scheduled time.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                SegmentedButton<NotificationScheduleMode>(
                  segments:
                      const <ButtonSegment<NotificationScheduleMode>>[
                    ButtonSegment<NotificationScheduleMode>(
                      value: NotificationScheduleMode.fixedTimes,
                      label: Text('Specific Times'),
                      icon: Icon(Icons.schedule_rounded),
                    ),
                    ButtonSegment<NotificationScheduleMode>(
                      value: NotificationScheduleMode.interval,
                      label: Text('Every N Minutes'),
                      icon: Icon(Icons.repeat_rounded),
                    ),
                  ],
                  selected: <NotificationScheduleMode>{
                    settingsProvider.scheduleMode,
                  },
                  onSelectionChanged: settingsProvider.isLoading
                      ? null
                      : (Set<NotificationScheduleMode> selection) {
                          _changeMode(selection.first);
                        },
                ),
                const SizedBox(height: 20),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.notifications_active_outlined),
                    title: Text(
                      settingsProvider.isIntervalMode
                          ? 'Notification mode'
                          : 'Push count per day',
                    ),
                    subtitle: Text(
                      settingsProvider.isIntervalMode
                          ? 'Notification repeats every ${settingsProvider.intervalMinutes ?? 60} minute(s)'
                          : 'Automatically matches the number of scheduled times',
                    ),
                    trailing: Text(
                      settingsProvider.isIntervalMode
                          ? '${settingsProvider.intervalMinutes ?? 60}m'
                          : '${settingsProvider.pushCount}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.update_rounded),
                    title: const Text('Next notification'),
                    subtitle: Text(settingsProvider.nextScheduledNotificationLabel),
                  ),
                ),
                const SizedBox(height: 20),
                if (settingsProvider.isFixedTimesMode)
                  FilledButton.icon(
                    onPressed: settingsProvider.isLoading ? null : _pickAndAddTime,
                    icon: const Icon(Icons.add_alarm_rounded),
                    label: const Text('Add Time'),
                  )
                else
                  FilledButton.icon(
                    onPressed: settingsProvider.isLoading ? null : _editInterval,
                    icon: const Icon(Icons.timer_outlined),
                    label: const Text('Set Interval'),
                  ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed:
                      settingsProvider.isLoading ? null : _sendTestNotification,
                  icon: const Icon(Icons.notification_add_outlined),
                  label: const Text('Send Test Notification'),
                ),
                const SizedBox(height: 20),
                if (settingsProvider.isIntervalMode) ...<Widget>[
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.timer_outlined),
                      title: const Text('Interval'),
                      subtitle: Text(
                        'Send a notification every ${settingsProvider.intervalMinutes ?? 60} minute(s).',
                      ),
                      onTap: settingsProvider.isLoading ? null : _editInterval,
                    ),
                  ),
                ] else if (settingsProvider.isLoading &&
                    settingsProvider.pushTimes.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (settingsProvider.pushTimes.isEmpty)
                  const _SettingsStatusView(
                    icon: Icons.schedule_outlined,
                    title: 'No push times configured',
                    message: 'Add at least one time to receive flashcard reminders.',
                  )
                else
                  ...settingsProvider.pushTimes.map(
                    (String time) => Dismissible(
                      key: ValueKey<String>(time),
                      direction: DismissDirection.endToStart,
                      confirmDismiss: (_) => _removeTime(time),
                      background: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        alignment: Alignment.centerRight,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Icon(
                          Icons.delete_outline_rounded,
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                      child: Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: const Icon(Icons.schedule_rounded),
                          title: Text(time),
                          subtitle: const Text('Tap to edit'),
                          onTap: settingsProvider.isLoading
                              ? null
                              : () => _editTime(time),
                          trailing: IconButton(
                            onPressed: settingsProvider.isLoading
                                ? null
                                : () => _removeTime(time),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (settingsProvider.errorMessage != null) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(
                    settingsProvider.errorMessage!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _sendTestNotification() async {
    try {
      await NotificationService.instance.showRandomCardNotification();
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Test notification sent.'),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send test notification: $error'),
        ),
      );
    }
  }

  Future<void> _changeMode(NotificationScheduleMode mode) async {
    final SettingsProvider settingsProvider = context.read<SettingsProvider>();
    final bool success = await settingsProvider.updateScheduleMode(mode);
    if (!mounted || success) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          settingsProvider.errorMessage ?? 'Failed to update mode.',
        ),
      ),
    );
  }

  Future<void> _editInterval() async {
    final SettingsProvider settingsProvider = context.read<SettingsProvider>();
    final TextEditingController controller = TextEditingController(
      text: '${settingsProvider.intervalMinutes ?? 60}',
    );

    final int? value = await showDialog<int>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Notification Interval'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Minutes',
              hintText: 'Example: 60',
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(int.tryParse(controller.text.trim())),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (!mounted || value == null) {
      return;
    }

    final bool success = await settingsProvider.updateIntervalMinutes(value);
    if (!mounted || success) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          settingsProvider.errorMessage ?? 'Failed to update interval.',
        ),
      ),
    );
  }

  Future<void> _pickAndAddTime() async {
    final TimeOfDay? selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (selectedTime == null || !mounted) {
      return;
    }

    final String formattedTime =
        '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}';

    final SettingsProvider settingsProvider = context.read<SettingsProvider>();
    final bool success = await settingsProvider.addPushTime(formattedTime);

    if (!mounted || success) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          settingsProvider.errorMessage ?? 'Failed to add push time.',
        ),
      ),
    );
  }

  Future<void> _editTime(String originalTime) async {
    final List<String> parts = originalTime.split(':');
    final int hour = int.tryParse(parts.first) ?? 0;
    final int minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;

    final TimeOfDay? selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: hour, minute: minute),
    );

    if (selectedTime == null || !mounted) {
      return;
    }

    final String updatedTime =
        '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}';
    final SettingsProvider settingsProvider = context.read<SettingsProvider>();
    final List<String> updatedTimes = settingsProvider.pushTimes
        .map((String time) => time == originalTime ? updatedTime : time)
        .toList();

    final bool success = await settingsProvider.replacePushTimes(updatedTimes);
    if (!mounted || success) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          settingsProvider.errorMessage ?? 'Failed to update push time.',
        ),
      ),
    );
  }

  Future<bool> _removeTime(String time) async {
    final bool confirmed = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Remove time?'),
              content: Text('Stop sending notifications at $time each day?'),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Remove'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmed || !mounted) {
      return false;
    }

    final SettingsProvider settingsProvider = context.read<SettingsProvider>();
    final bool success = await settingsProvider.removePushTime(time);

    if (!mounted) {
      return false;
    }

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            settingsProvider.errorMessage ?? 'Failed to remove push time.',
          ),
        ),
      );
      return false;
    }

    return true;
  }
}

class _SettingsStatusView extends StatelessWidget {
  const _SettingsStatusView({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 12),
      child: Column(
        children: <Widget>[
          Icon(icon, size: 52, color: theme.colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}
