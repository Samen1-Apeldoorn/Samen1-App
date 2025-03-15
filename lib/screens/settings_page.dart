import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import '../services/rss_service.dart';
import '../services/notification_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notificationsEnabled = false;
  String _checkInterval = '60';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? false;
      _checkInterval = prefs.getString('check_interval') ?? '60';
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', _notificationsEnabled);
    await prefs.setString('check_interval', _checkInterval);
    
    if (_notificationsEnabled) {
      await Workmanager().registerPeriodicTask(
        'samen1-rss-check',
        'checkRSSFeed',
        frequency: Duration(minutes: int.parse(_checkInterval)),
      );
    } else {
      await Workmanager().cancelByUniqueName('samen1-rss-check');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Instellingen'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Meldingen',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Meldingen inschakelen'),
                  subtitle: const Text('Ontvang meldingen bij nieuwe artikelen'),
                  value: _notificationsEnabled,
                  onChanged: (value) {
                    setState(() => _notificationsEnabled = value);
                    _saveSettings();
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Controle interval'),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: '10', label: Text('10m')),
                            ButtonSegment(value: '30', label: Text('30m')),
                            ButtonSegment(value: '60', label: Text('1u')),
                            ButtonSegment(value: '240', label: Text('4u')),
                          ],
                          selected: {_checkInterval},
                          onSelectionChanged: _notificationsEnabled
                              ? (Set<String> newSelection) {
                                  setState(() => _checkInterval = newSelection.first);
                                  _saveSettings();
                                }
                              : null,
                          style: ButtonStyle(
                            visualDensity: VisualDensity.compact,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                ListTile(
                  title: const Text('Test melding'),
                  subtitle: const Text('Stuur een test melding om te controleren'),
                  trailing: IconButton(
                    icon: const Icon(Icons.notifications_active),
                    onPressed: () async {
                      await NotificationService.initialize();
                      final result = await RSSService.sendTestNotification();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(result)),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
