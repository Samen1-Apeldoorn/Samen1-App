import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'log_service.dart';
import '../main.dart'; // For navigatorKey
import '../Pages/News/news_service.dart'; // For NewsService and NewsArticle
import '../Popup/news_article_screen.dart'; // For article display

class NotificationService {
  static final _notifications = FlutterLocalNotificationsPlugin();
  
  static Future<void> initialize() async {
    LogService.log('Initializing notifications', category: 'notifications');
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(android: androidSettings, iOS: iosSettings);
    
    // Add notification response handler
    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTap,
      onDidReceiveBackgroundNotificationResponse: _onNotificationTap,
    );

    // Request permissions for Android
    final androidImplementation = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      final granted = await androidImplementation.requestNotificationsPermission();
      LogService.log('Notification permission granted: $granted', category: 'notifications');
    }
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
    LogService.log('Preparing notification: Title="$title", Body="$body", Payload="$payload"', category: 'notifications');
    
    AndroidNotificationDetails androidDetails;

    if (imageUrl != null && imageUrl.isNotEmpty) {
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
