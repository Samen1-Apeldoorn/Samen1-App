import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'package:url_launcher/url_launcher.dart';
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

  Future<void> _launchEmail() async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'floris.vandenbroek@samen1.nl',
      query: 'subject=Feedback Samen1 App',
    );
    
    if (!await launchUrl(emailLaunchUri)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kon email app niet openen')),
        );
      }
    }
  }

  Future<void> _openBatterySettings() async {
    if (context.mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Batterij optimalisatie'),
          content: const Text(
            '1. Houd de Samen1 app ingedrukt\n'
            '2. Selecteer "App-info"\n'
            '3. Tik op "Batterij"\n'
            '4. Selecteer "Onbeperkt" of "Niet optimaliseren"\n'
            '5. Bevestig je keuze'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
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
                ExpansionTile(
                  title: Text(
                    'Meldingen',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  initiallyExpanded: true,
                  shape: const Border(), // removes the bottom line
                  collapsedShape: const Border(), // removes the top line
                  children: [
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
                    if (Theme.of(context).platform == TargetPlatform.android)
                      ListTile(
                        title: const Text('Batterij optimalisatie'),
                        subtitle: const Text('Schakel batterij optimalisatie uit voor betrouwbare meldingen'),
                        trailing: IconButton(
                          icon: const Icon(Icons.battery_saver),
                          onPressed: _openBatterySettings,
                        ),
                      ),
                  ],
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.feedback),
                  title: const Text('Feedback'),
                  subtitle: const Text('Stuur ons je feedback via email'),
                  onTap: _launchEmail,
                ),
                const SizedBox(height: 32),
                Center(
                  child: Text(
                    'Copyright Samen1 2025 - Versie 0.04',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
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
