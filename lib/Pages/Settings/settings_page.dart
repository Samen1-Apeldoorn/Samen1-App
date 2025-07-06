import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'package:permission_handler/permission_handler.dart'; // Import permission_handler
import '../../services/rss_service.dart';
import '../../services/notification_service.dart';
import '../../services/log_service.dart';
import '../../services/discord_service.dart';
import '../../services/version_service.dart';
import '../../services/cache_manager.dart';
import '../Radio/radio_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notificationsEnabled = false;
  PermissionStatus _notificationStatus = PermissionStatus.denied; // Store permission status
  final AudioService _audioService = AudioService(); // Use the singleton AudioService
  bool _isRadioPlaying = false;
  final List<String> _categories = ["Regio", "112", "Gemeente", "Politiek", "Evenementen", "Cultuur"];
  List<String> _enabledCategories = [];

  @override
  void initState() {
    super.initState();
    LogService.log('SettingsPage: Page opened', category: 'settings');
    _loadSettings();
    _checkRadioStatus();
  }

  void _checkRadioStatus() {
    LogService.log('SettingsPage: Checking radio playback status', category: 'settings_detail');
    // This checks if the radio is playing in the background
    _audioService.player.playerStateStream.listen((state) {
      LogService.log(
        'SettingsPage: Radio state update - Playing: ${state.playing}, '
        'Processing: ${state.processingState}',
        category: 'settings_detail'
      );
      
      if (mounted) {
        setState(() {
          _isRadioPlaying = state.playing;
        });
      }
    });
  }

  Future<void> _loadSettings() async {
    try {
      LogService.log('SettingsPage: Loading user preferences and checking permission', category: 'settings');
      final prefs = await SharedPreferences.getInstance();
      final permissionStatus = await NotificationService.checkNotificationPermissionStatus();

      // Load saved preference, default to false
      final savedNotificationsPref = prefs.getBool('notifications_enabled') ?? false;
      final enabledCategories = prefs.getStringList('enabled_categories') ?? _categories.toList();

      // Determine actual enabled state based on permission
      final bool actualNotificationsEnabled = savedNotificationsPref && permissionStatus.isGranted;

      LogService.log(
        'SettingsPage: Loaded preferences - SavedPref: $savedNotificationsPref, Permission: $permissionStatus, ActualEnabled: $actualNotificationsEnabled, '
        'Categories: ${enabledCategories.join(", ")}',
        category: 'settings'
      );

      if (mounted) {
        setState(() {
          _notificationStatus = permissionStatus;
          _notificationsEnabled = actualNotificationsEnabled;
          // Only keep categories if actually enabled
          _enabledCategories = actualNotificationsEnabled ? enabledCategories : [];
        });

        // If saved pref was true but permission isn't granted, update saved pref to false
        if (savedNotificationsPref && !permissionStatus.isGranted) {
           LogService.log('SettingsPage: Permission not granted, updating saved preference to false', category: 'settings');
           await prefs.setBool('notifications_enabled', false);
           // Also clear saved categories if they existed
           if (enabledCategories.isNotEmpty) {
              await prefs.setStringList('enabled_categories', []);
           }
        }
      }
    } catch (e, stack) {
      LogService.log(
        'SettingsPage: Error loading settings: $e\n$stack', 
        category: 'settings_error'
      );
      // If there's an error, use default values and assume denied
      if (mounted) {
        setState(() {
          _notificationStatus = PermissionStatus.denied;
          _notificationsEnabled = false;
          _enabledCategories = [];
        });
      }
    }
  }

  // Modified save settings to handle permission request flow
  Future<void> _handleNotificationToggle(bool value) async {
    if (!mounted) return;

    if (value) {
      // Trying to enable notifications
      LogService.log('SettingsPage: User attempting to enable notifications', category: 'settings');
      final status = await NotificationService.requestNotificationPermission();
      setState(() { _notificationStatus = status; }); // Update status

      if (status.isGranted) {
        LogService.log('SettingsPage: Permission granted. Enabling notifications.', category: 'settings');
        setState(() {
          _notificationsEnabled = true;
          _enabledCategories = _categories.toList(); // Enable all by default
        });
        await _saveAndConfigureNotifications(true); // Save and register task
      } else if (status.isPermanentlyDenied) {
        LogService.log('SettingsPage: Permission permanently denied.', category: 'settings_warning');
        setState(() { _notificationsEnabled = false; }); // Keep disabled
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Meldingen zijn geblokkeerd. Schakel ze in via app-instellingen.'),
              action: SnackBarAction(
                label: 'Instellingen',
                onPressed: openAppSettings,
              ),
            ),
          );
        }
      } else { // Denied but not permanently
        LogService.log('SettingsPage: Permission denied.', category: 'settings_warning');
        setState(() { _notificationsEnabled = false; }); // Keep disabled
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Toestemming voor meldingen is vereist.')),
          );
        }
      }
    } else {
      // Disabling notifications
      LogService.log('SettingsPage: User disabling notifications', category: 'settings');
      setState(() {
        _notificationsEnabled = false;
        _enabledCategories.clear();
      });
      await _saveAndConfigureNotifications(false); // Save and cancel task
    }
  }


  // Extracted saving logic
  Future<void> _saveAndConfigureNotifications(bool enable) async {
     try {
       LogService.log(
         'SettingsPage: Saving settings - Notifications: $enable, '
         'Categories: ${_enabledCategories.join(", ")}',
         category: 'settings'
       );

       final prefs = await SharedPreferences.getInstance();
       await prefs.setBool('notifications_enabled', enable);
       await prefs.setStringList('enabled_categories', _enabledCategories);

       if (enable) {
         LogService.log(
           'SettingsPage: Setting up background tasks with 15 minute interval',
           category: 'settings'
         );

         await Workmanager().registerPeriodicTask(
           'samen1-rss-check',
           'checkRSSFeed',
           frequency: const Duration(minutes: 15),
           // Add constraints if needed, e.g., network connectivity
           // constraints: Constraints(networkType: NetworkType.connected),
         );
         
         // Register cache maintenance task
         await Workmanager().registerPeriodicTask(
           'samen1-cache-maintenance',
           'cacheMaintenance',
           frequency: const Duration(hours: 6),
         );
       } else {
         LogService.log('SettingsPage: Canceling background tasks', category: 'settings');
         await Workmanager().cancelByUniqueName('samen1-rss-check');
         await Workmanager().cancelByUniqueName('samen1-cache-maintenance');
       }

       LogService.log('SettingsPage: Settings saved and tasks configured successfully', category: 'settings');
     } catch (e, stack) {
       LogService.log(
         'SettingsPage: Error saving settings or configuring tasks: $e\n$stack',
         category: 'settings_error'
       );

       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Kon instellingen niet opslaan. Probeer het later opnieuw.'))
         );
         // Revert UI state if saving failed? Maybe not, could cause confusion.
         // setState(() { _notificationsEnabled = !enable; });
       }
     }
  }


  Future<void> _stopBackgroundRadio() async {
    try {
      LogService.log('SettingsPage: Stopping background radio playback', category: 'settings_action');
      await _audioService.stop();
      
      LogService.log('SettingsPage: Background radio stopped successfully', category: 'settings');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Radio is gestopt'))
        );
        setState(() {
          _isRadioPlaying = false;
        });
      }
    } catch (e, stack) {
      LogService.log(
        'SettingsPage: Error stopping radio playback: $e\n$stack', 
        category: 'settings_error'
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Probleem bij het stoppen van de radio'))
        );
      }
    }
  }

  Future<void> _sendTestNotification() async {
    LogService.log('Test notification requested', category: 'settings');
    await NotificationService.initialize();
    await RSSService.sendTestNotification();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Test melding verzonden')),
      );
    }
  }

  // Restored original function to show battery optimization instructions
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
              descriptionController.text,
              emailController.text,
            ),
            child: const Text('Versturen'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _submitBugReport(String description, String email) async {
    if (description.isEmpty) {
      LogService.log('SettingsPage: Bug report submission canceled - empty description', category: 'settings');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Geef een beschrijving van het probleem'))
        );
      }
      return;
    }
    
    if (!mounted) return;
    Navigator.pop(context);
    
    String reportText = description;
    if (email.isNotEmpty) {
      reportText = 'Email: $email\n\n$description';
      LogService.log('SettingsPage: Bug report includes contact email', category: 'settings_detail');
    }
    
    LogService.log('SettingsPage: Generating and submitting bug report', category: 'settings');
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bug report versturen...'),
          duration: Duration(milliseconds: 1500),
        ),
      );
    }
    
    try {
      final report = await LogService.generateReport(reportText);
      LogService.log('SettingsPage: Bug report generated successfully', category: 'settings_detail');
      
      final success = await DiscordService.sendBugReport(report);
      
      LogService.log(
        success ? 'SettingsPage: Bug report sent successfully' : 'SettingsPage: Bug report failed to send',
        category: success ? 'settings' : 'settings_error'
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
    } catch (e, stack) {
      LogService.log('SettingsPage: Error submitting bug report: $e\n$stack', category: 'settings_error');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Er is een probleem opgetreden bij het versturen.'),
            action: SnackBarAction(
              label: 'Opnieuw',
              onPressed: _showBugReportDialog,
            ),
          ),
        );
      }
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
                if (_isRadioPlaying) _buildRadioControls(),
                _buildBugReportTile(),
                const Divider(),
                _buildCacheManagementSection(),
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

  Widget _buildRadioControls() {
    return ListTile(
      leading: const Icon(Icons.radio),
      title: const Text('Radio speelt af in achtergrond'),
      subtitle: const Text('Tik om de radio te stoppen'),
      trailing: IconButton(
        icon: const Icon(Icons.stop),
        onPressed: _stopBackgroundRadio,
      ),
      onTap: _stopBackgroundRadio,
    );
  }

  Widget _buildNotificationSettings() {
    // Determine if the switch should be visually disabled
    final bool isPermanentlyDenied = _notificationStatus.isPermanentlyDenied;

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
          subtitle: Text(isPermanentlyDenied
              ? 'Toestemming geblokkeerd in instellingen'
              : 'Ontvang meldingen bij nieuwe artikelen'),
          value: _notificationsEnabled,
          // Disable interaction if permanently denied
          onChanged: isPermanentlyDenied ? null : _handleNotificationToggle,
          // Visually grey out if permanently denied
          activeColor: isPermanentlyDenied ? Colors.grey : null,
          inactiveThumbColor: isPermanentlyDenied ? Colors.grey[400] : null,
        ),
        // Conditionally show category selection only if enabled AND permission granted
        if (_notificationsEnabled && _notificationStatus.isGranted) ...[
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
                    // Save category changes immediately (only if notifications are enabled)
                    _saveAndConfigureNotifications(true);
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
        // Test notification button - maybe disable if permission not granted?
        ListTile(
          title: const Text('Test melding'),
          subtitle: const Text('Stuur een test melding om te controleren'),
          trailing: IconButton(
            icon: const Icon(Icons.notifications_active),
            // Only allow sending if permission is granted
            onPressed: _notificationStatus.isGranted ? _sendTestNotification : null,
          ),
          enabled: _notificationStatus.isGranted, // Visually disable if no permission
        ),
        // Reverted Battery Optimization ListTile for Android
        if (Theme.of(context).platform == TargetPlatform.android)
          ListTile(
            title: const Text('Batterij optimalisatie'),
            subtitle: const Text('Schakel batterij optimalisatie uit voor betrouwbare meldingen'), // Kept updated subtitle
            trailing: IconButton(
              icon: const Icon(Icons.battery_saver), // Restored original icon
              onPressed: _openBatterySettings, // Call the restored function
            ),
            onTap: _openBatterySettings, // Also allow tapping the tile
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

  Widget _buildCacheManagementSection() {
    return ExpansionTile(
      leading: const Icon(Icons.storage),
      title: const Text('Cache Beheer'),
      subtitle: const Text('Beheer opgeslagen artikelen'),
      children: [
        ListTile(
          leading: const Icon(Icons.refresh),
          title: const Text('Cache Verversen'),
          subtitle: const Text('Ververs cache op de achtergrond'),
          onTap: _refreshCache,
        ),
        ListTile(
          leading: const Icon(Icons.clear_all, color: Colors.red),
          title: const Text('Cache Wissen', style: TextStyle(color: Colors.red)),
          subtitle: const Text('Wis alle opgeslagen artikelen'),
          onTap: _clearCache,
        ),
      ],
    );
  }

  Future<void> _refreshCache() async {
    try {
      await CacheManager.refreshCache();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cache wordt op de achtergrond ververst')),
        );
      }
    } catch (e) {
      LogService.log('Error refreshing cache: $e', category: 'settings_error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fout bij verversen cache')),
        );
      }
    }
  }

  Future<void> _clearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cache Wissen'),
        content: const Text('Weet je zeker dat je alle opgeslagen artikelen wilt verwijderen? Dit kan niet ongedaan gemaakt worden.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuleren'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Wissen'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await CacheManager.forceCleanup();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cache succesvol gewist')),
          );
        }
      } catch (e) {
        LogService.log('Error clearing cache: $e', category: 'settings_error');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Fout bij wissen cache')),
          );
        }
      }
    }
  }
}
