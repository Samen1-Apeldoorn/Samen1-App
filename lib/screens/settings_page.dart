import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import '../services/rss_service.dart';
import '../services/notification_service.dart';
import '../services/log_service.dart';
import '../services/discord_service.dart';
import '../services/version_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notificationsEnabled = false;
  final List<String> _categories = ["Regio", "112", "Gemeente", "Politiek", "Evenementen", "Cultuur"];
  List<String> _enabledCategories = [];

  @override
  void initState() {
    super.initState();
    LogService.log('Settings page opened', category: 'settings');
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    LogService.log('Loading settings', category: 'settings');
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? false;
      _enabledCategories = prefs.getStringList('enabled_categories') ?? _categories.toList();
    });
  }

  Future<void> _saveSettings() async {
    LogService.log(
      'Saving settings - Notifications: $_notificationsEnabled, Categories: $_enabledCategories', 
      category: 'settings'
    );
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', _notificationsEnabled);
    await prefs.setStringList('enabled_categories', _enabledCategories);

    if (_notificationsEnabled) {
      await Workmanager().registerPeriodicTask(
        'samen1-rss-check',
        'checkRSSFeed',
        frequency: const Duration(minutes: 10),
      );
      LogService.log('Background task registered with 10 minute interval', category: 'settings');
    } else {
      await Workmanager().cancelByUniqueName('samen1-rss-check');
      LogService.log('Background task cancelled', category: 'settings');
    }
  }

  Future<void> _sendTestNotification() async {
    LogService.log('Test notification requested', category: 'settings');
    await NotificationService.initialize();
    final result = await RSSService.sendTestNotification();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result)),
      );
    }
  }

  Future<void> _openBatterySettings() async {
    LogService.log('Battery optimization help requested', category: 'settings');
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Batterij optimalisatie'),
          content: const Text(
            '1. Houd de Samen1 app ingedrukt\n'
            '2. Selecteer "App-info"\n'
            '3. Tik op "Batterij"\n'
            '4. Selecteer "Onbeperkt" of "Niet optimaliseren"\n'
            '5. Bevestig je keuze',
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

  Future<void> _showBugReportDialog() async {
    LogService.log('Bug report dialog opened', category: 'settings');
    final TextEditingController descriptionController = TextEditingController();
    final TextEditingController emailController = TextEditingController();
    
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bug rapporteren'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Beschrijf het probleem zo duidelijk mogelijk:'),
            const SizedBox(height: 8),
            TextField(
              controller: descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Beschrijf het probleem...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                hintText: 'E-mail (optioneel)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuleren'),
          ),
          ElevatedButton(
            onPressed: () => _submitBugReport(
              context,
              descriptionController.text,
              emailController.text,
            ),
            child: const Text('Versturen'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _submitBugReport(BuildContext context, String description, String email) async {
    if (description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geef een beschrijving van het probleem')),
      );
      return;
    }
    
    Navigator.pop(context);
    
    String reportText = description;
    if (email.isNotEmpty) {
      reportText = 'Email: $email\n\n$description';
    }
    
    LogService.log('Submitting bug report', category: 'settings');
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bug report versturen...'),
          duration: Duration(milliseconds: 1500),
        ),
      );
    }
    
    final report = await LogService.generateReport(reportText);
    final success = await DiscordService.sendBugReport(report);
    
    LogService.log(
      success ? 'Bug report sent successfully' : 'Bug report failed to send',
      category: 'settings'
    );
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success 
              ? 'Bedankt voor je melding! We gaan er mee aan de slag.' 
              : 'Er ging iets mis bij het versturen. Probeer het later opnieuw.'
          ),
          duration: const Duration(seconds: 4),
          action: success ? null : SnackBarAction(
            label: 'Opnieuw',
            onPressed: _showBugReportDialog,
          ),
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
                _buildNotificationSettings(),
                const Divider(),
                _buildBugReportTile(),
                const SizedBox(height: 32),
                Center(
                  child: Text(
                    VersionService.copyright,
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

  Widget _buildNotificationSettings() {
    return ExpansionTile(
      title: Text(
        'Meldingen',
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
      ),
      initiallyExpanded: true,
      shape: const Border(),
      collapsedShape: const Border(),
      children: [
        SwitchListTile(
          title: const Text('Meldingen inschakelen'),
          subtitle: const Text('Ontvang meldingen bij nieuwe artikelen'),
          value: _notificationsEnabled,
          onChanged: (value) {
            setState(() {
              _notificationsEnabled = value;
              if (value) {
                _enabledCategories = _categories.toList();
              } else {
                _enabledCategories.clear();
              }
            });
            _saveSettings();
          },
        ),
        if (_notificationsEnabled) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              'Selecteer meldings categorieën',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: GridView.count(
              shrinkWrap: true,
              crossAxisCount: 2,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 3.5,
              physics: const NeverScrollableScrollPhysics(),
              children: _categories.map((category) {
                final isSelected = _enabledCategories.contains(category);
                return InkWell(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _enabledCategories.remove(category);
                      } else {
                        _enabledCategories.add(category);
                      }
                    });
                    _saveSettings();
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: isSelected 
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey[200],
                    ),
                    child: Center(
                      child: Text(
                        category,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
        ListTile(
          title: const Text('Test melding'),
          subtitle: const Text('Stuur een test melding om te controleren'),
          trailing: IconButton(
            icon: const Icon(Icons.notifications_active),
            onPressed: _sendTestNotification,
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
    );
  }

  Widget _buildBugReportTile() {
    return ListTile(
      leading: const Icon(Icons.bug_report),
      title: const Text('Bug rapporteren'),
      subtitle: const Text('Stuur een probleem rapport'),
      onTap: _showBugReportDialog,
    );
  }
}
