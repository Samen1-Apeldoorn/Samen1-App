import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:workmanager/workmanager.dart';
import 'screens/news_page.dart'; 
import 'screens/radio_page.dart';
import 'screens/tv_page.dart';
import 'screens/settings_page.dart';
import 'services/notification_service.dart';
import 'services/rss_service.dart';
import 'services/log_service.dart';
import 'services/version_service.dart';

// Global navigation key to use for navigation from outside of widgets
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LogService.log('Application starting', category: 'app_lifecycle');
  
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
  
  // Then initialize workmanager
  await Workmanager().initialize(
    callbackDispatcher,
    isInDebugMode: true,
  );
  LogService.log('Workmanager initialized', category: 'initialization');
  
  runApp(const MyApp());
}

// Handle deep links from notifications
void handleDeepLink(String? url) {
  LogService.log('Attempting to handle deep link', category: 'navigation');
  if (url != null && url.isNotEmpty) {
    LogService.log('Deep link URL: $url', category: 'navigation');
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (context) => NewsArticleScreen(articleUrl: url),
      ),
    );
  } else {
    LogService.log('Empty or null deep link URL', category: 'navigation_error');
  }
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName == 'checkRSSFeed') {
      await RSSService.checkForNewContent();
    }
    return true;
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
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  @override
  void initState() {
    super.initState();
    LogService.log('Main screen initialized', category: 'navigation');
  }

  int _currentIndex = 0;
  final _pageNames = const ['Nieuws', 'Radio', 'TV', 'Instellingen'];
  final _pages = const [
    NewsPage(),
    RadioPage(),
    TVPage(),
    SettingsPage(),
  ];

  void _onTabChanged(int index) {
    if (_currentIndex != index) {
      setState(() {
        LogService.log(
          'Navigatie van ${_pageNames[_currentIndex]} naar ${_pageNames[index]}', 
          category: 'navigation'
        );
        _currentIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabChanged,
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFFFA6401),
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white70,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.newspaper), label: 'Nieuws'),
          BottomNavigationBarItem(icon: Icon(Icons.radio), label: 'Radio'),
          BottomNavigationBarItem(icon: Icon(Icons.tv), label: 'TV'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Instellingen'),
        ],
      ),
    );
  }
}
