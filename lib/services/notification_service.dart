import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart'; // Import permission_handler
import 'log_service.dart';
import '../main.dart'; // For navigatorKey
import '../Pages/News/news_service.dart'; // For NewsService and NewsArticle
import '../Popup/news_article_screen.dart'; // For article display

class NotificationService {
  static final _notifications = FlutterLocalNotificationsPlugin();
  static bool _isInitialized = false; // Track initialization

  static Future<void> initialize() async {
    if (_isInitialized) return; // Prevent multiple initializations
    LogService.log('Initializing notifications plugin', category: 'notifications');
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    // For iOS, don't request permissions here initially.
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(android: androidSettings, iOS: iosSettings);

    // Add notification response handler
    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTap,
      onDidReceiveBackgroundNotificationResponse: _onNotificationTap,
    );
    _isInitialized = true;
    LogService.log('Notifications plugin initialized', category: 'notifications');

    // Removed permission request from here
  }

  // New method to check permission status
  static Future<PermissionStatus> checkNotificationPermissionStatus() async {
    final status = await Permission.notification.status;
    LogService.log('Checked notification permission status: $status', category: 'permissions');
    return status;
  }

  // New method to request permission
  static Future<PermissionStatus> requestNotificationPermission() async {
    final status = await Permission.notification.request();
    LogService.log('Requested notification permission. Result: $status', category: 'permissions');
    return status;
  }

  // Handler for notification taps
  static void _onNotificationTap(NotificationResponse notificationResponse) async {
    final String? payload = notificationResponse.payload; // This is the article title
    LogService.log('Notification tapped with payload: $payload', category: 'notifications');
    
    if (payload == null || payload.isEmpty) {
      LogService.log('Notification payload is empty, cannot find article', category: 'notifications_warning');
      _navigateToNewsPage();
      return;
    }
    
    try {
      // Fetch recent articles from the API to find a match
      LogService.log('Fetching recent news articles to match notification title...', category: 'notifications');
      final articles = await NewsService.getNews(page: 1, perPage: 50);
      
      if (articles.isEmpty) {
        LogService.log('Failed to fetch articles from API', category: 'notifications_error');
        _navigateToNewsPage();
        return;
      }
      
      // Find a matching article by title
      NewsArticle? matchedArticle;
      for (final article in articles) {
        if (article.title.toLowerCase() == payload.toLowerCase()) {
          matchedArticle = article;
          LogService.log('Found matching article with ID: ${article.id}', category: 'notifications');
          break;
        }
      }
      
      if (matchedArticle != null) {
        // Open the article screen
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (context) => NewsArticleScreen(article: matchedArticle!),
          ),
        );
      } else {
        LogService.log('No matching article found for title: "$payload"', category: 'notifications_warning');
        _navigateToNewsPage();
      }
    } catch (e, stack) {
      LogService.log('Error handling notification tap: $e\n$stack', category: 'notifications_error');
      _navigateToNewsPage();
    }
  }
  
  // Helper method to navigate to news page as fallback
  static void _navigateToNewsPage() {
    LogService.log('Navigating to main news page', category: 'notifications');
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => const MainScreen(initialIndex: 0), // Go to news tab
      ),
      (route) => false, // Remove all previous routes
    );
  }

  static Future<void> showNotification({
    required String title,
    required String body,
    required String payload,
    String? imageUrl,
  }) async {
    // Ensure initialized before showing
    if (!_isInitialized) {
      LogService.log('Notification service not initialized, cannot show notification.', category: 'notifications_error');
      return;
    }
    // Check permission before attempting to show
    final status = await checkNotificationPermissionStatus();
    if (!status.isGranted) {
      LogService.log('Notification permission not granted ($status), cannot show notification.', category: 'notifications_warning');
      return; // Don't show if permission isn't granted
    }

    LogService.log('Preparing notification: Title="$title", Body="$body", Payload="$payload"', category: 'notifications');

    // ... rest of the existing showNotification logic ...
    AndroidNotificationDetails androidDetails;

    if (imageUrl != null && imageUrl.isNotEmpty) { // Corrected: added parentheses to isNotEmpty
      try {
        LogService.log('Downloading image from: $imageUrl', category: 'notifications');
        final response = await http.get(Uri.parse(imageUrl)).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final bytes = response.bodyBytes;
          final tempDir = await getTemporaryDirectory();
          final tempPath = '${tempDir.path}/notification_image_${DateTime.now().millisecondsSinceEpoch}.jpg';
          await File(tempPath).writeAsBytes(bytes);

          androidDetails = AndroidNotificationDetails(
            'samen1_news',
            'Nieuws Updates',
            channelDescription: 'Nieuws updates van Samen1',
            importance: Importance.high,
            priority: Priority.high,
            color: const Color(0xFFFA6401),
            styleInformation: BigPictureStyleInformation(
              FilePathAndroidBitmap(tempPath),
              hideExpandedLargeIcon: false,
              contentTitle: title,
              summaryText: body,
              htmlFormatContentTitle: true,
              htmlFormatSummaryText: true,
            ),
            largeIcon: FilePathAndroidBitmap(tempPath), // Use image as icon too
          );
        } else {
          LogService.log('Failed to download image: HTTP ${response.statusCode}', category: 'notifications_error');
          androidDetails = _createTextNotification(title, body);
        }
      } catch (e) {
        LogService.log('Error processing image: $e', category: 'notifications_error');
        androidDetails = _createTextNotification(title, body);
      }
    } else {
      androidDetails = _createTextNotification(title, body);
    }

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(presentSound: true),
    );

    try {
      // Use a stable ID based on payload to prevent duplicate notifications
      final notificationId = payload.hashCode;

      await _notifications.show(
        notificationId,
        title,
        body,
        notificationDetails,
        payload: payload,
      );
      LogService.log('Notification shown successfully with ID: $notificationId', category: 'notifications');
    } catch (e) {
      LogService.log('Error showing notification: $e', category: 'notifications_error');
    }
  }

  static AndroidNotificationDetails _createTextNotification(String title, String body) {
    return AndroidNotificationDetails(
      'samen1_news',
      'Nieuws Updates',
      channelDescription: 'Nieuws updates van Samen1',
      importance: Importance.high,
      priority: Priority.high,
      color: const Color(0xFFFA6401),
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
        htmlFormatBigText: true,
        htmlFormatContentTitle: true,
      ),
    );
  }
}
