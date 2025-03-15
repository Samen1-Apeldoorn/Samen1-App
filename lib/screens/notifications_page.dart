import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import '../services/rss_service.dart';
import '../services/notification_service.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
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
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Meldingen inschakelen'),
            value: _notificationsEnabled,
            onChanged: (value) {
              setState(() => _notificationsEnabled = value);
              _saveSettings();
            },
          ),
          ListTile(
            title: const Text('Controle interval'),
            subtitle: DropdownButton<String>(
              value: _checkInterval,
              items: const [
                DropdownMenuItem(value: '10', child: Text('10 minuten')),
                DropdownMenuItem(value: '30', child: Text('30 minuten')),
                DropdownMenuItem(value: '60', child: Text('1 uur')),
                DropdownMenuItem(value: '240', child: Text('4 uur')),
              ],
              onChanged: _notificationsEnabled
                  ? (value) {
                      setState(() => _checkInterval = value!);
                      _saveSettings();
                    }
                  : null,
            ),
          ),
          const Divider(),
          ListTile(
            title: const Text('Test melding'),
            subtitle: const Text('Toon de meest recente artikel als melding'),
            trailing: IconButton(
              icon: const Icon(Icons.notifications_active),
              onPressed: () async {
                await NotificationService.initialize();
                
                final result = await RSSService.sendTestNotification();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(result),
                      duration: const Duration(seconds: 5),
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

