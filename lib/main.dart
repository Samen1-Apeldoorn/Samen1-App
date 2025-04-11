import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:workmanager/workmanager.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'Navigation/category_navigation.dart'; // Update the import
import 'Pages/Radio/radio_page.dart';
import 'Pages/TV/tv_page.dart';
import 'Pages/Settings/settings_page.dart';
import 'services/notification_service.dart';
import 'services/rss_service.dart';
import 'services/log_service.dart';
import 'services/version_service.dart';
import 'Pages/Radio/radio_service.dart';

// Global navigation key to use for navigation from outside of widgets
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LogService.log('Application starting', category: 'app_lifecycle');
  
  // Initialize just_audio_background
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.example.samen1appv5.channel.audio',
    androidNotificationChannelName: 'Samen1 Radio',
    androidNotificationOngoing: true,
    androidShowNotificationBadge: true,
  );
  LogService.log('Audio background service initialized', category: 'initialization');
  
  // Pre-initialize the AudioService singleton
  AudioService();
  
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await VersionService.initialize();
  LogService.log('Version service initialized: ${VersionService.fullVersionString}', category: 'initialization');

  // Stel de statusbalkkleur en icoontjes in
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent, // Transparante achtergrond
    statusBarIconBrightness: Brightness.dark, // Donkere icoontjes (voor een lichte achtergrond)
    systemNavigationBarColor: Colors.white, // Optioneel: pas de navigatiebalk aan
    systemNavigationBarIconBrightness: Brightness.dark,
  ));

  // Initialize notifications first
  await NotificationService.initialize();
  LogService.log('Notification service initialized', category: 'initialization');
  
  // Update the Workmanager initialization
  try {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: true
    );
    LogService.log('Workmanager initialized', category: 'initialization');
  } catch (e) {
    LogService.log('Error initializing Workmanager: $e', category: 'initialization_error');
  }
  
  runApp(const MyApp());
}


@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    try {
      // Initialize required services for background task
      WidgetsFlutterBinding.ensureInitialized();
      await NotificationService.initialize();
      
      LogService.log('Background task started: $taskName', category: 'background_task');
      
      if (taskName == 'checkRSSFeed') {
        await RSSService.checkForNewContent();
      }
      
      LogService.log('Background task completed successfully', category: 'background_task');
      return true;
    } catch (e, stack) {
      LogService.log('Background task error: $e\n$stack', category: 'background_task_error');
      return false;
    }
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey, // Set the navigator key
      title: 'Samen1',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFA6401),
          primary: const Color(0xFFFA6401),
          secondary: const Color(0xFFB94B01),
        ),
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  final int initialIndex;

  const MainScreen({
    super.key,
    this.initialIndex = 0, // Default to news tab
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late int _currentIndex; // Change from final to late
  
  // Update to use NewsContainer instead of NewsPage
  final List<({String name, Widget page, IconData icon})> _pageData = const [
    (name: 'Nieuws', page: NewsContainer(), icon: Icons.newspaper),
    (name: 'Radio', page: RadioPage(), icon: Icons.radio),
    (name: 'TV', page: TVPage(), icon: Icons.tv),
    (name: 'Instellingen', page: SettingsPage(), icon: Icons.settings),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex; // Use initialIndex from widget
    LogService.log('Main screen initialized at index: $_currentIndex', category: 'navigation');
  }

  // Add didUpdateWidget to handle updates to initialIndex
  @override
  void didUpdateWidget(covariant MainScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialIndex != oldWidget.initialIndex) {
      setState(() {
        _currentIndex = widget.initialIndex;
        LogService.log('Main screen index updated to: $_currentIndex', category: 'navigation');
      });
    }
  }

  void _onTabChanged(int index) {
    if (_currentIndex != index) {
      LogService.log(
        'Navigatie van ${_pageData[_currentIndex].name} naar ${_pageData[index].name}', 
        category: 'navigation'
      );
      setState(() => _currentIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pageData[_currentIndex].page,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabChanged,
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFFFA6401),
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white70,
        items: [
          for (final data in _pageData)
            BottomNavigationBarItem(icon: Icon(data.icon), label: data.name),
        ],
      ),
    );
  }
}
