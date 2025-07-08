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
  static bool _isInitialized = false;

  static Future<void> initialize() async {
    if (_isInitialized) return;
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(android: androidSettings, iOS: iosSettings);

    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTap,
      onDidReceiveBackgroundNotificationResponse: _onNotificationTap,
    );
    _isInitialized = true;
  }

  static Future<PermissionStatus> checkNotificationPermissionStatus() async {
    return await Permission.notification.status;
  }

  static Future<PermissionStatus> requestNotificationPermission() async {
    final status = await Permission.notification.request();
    LogService.log('Notification permission request result: $status', category: 'permissions');
    return status;
  }

  static void _onNotificationTap(NotificationResponse notificationResponse) async {
    final String? payload = notificationResponse.payload;
    
    if (payload == null || payload.isEmpty) {
      _navigateToNewsPage();
      return;
    }
    
    try {
      final articles = await NewsService.getNews(page: 1, perPage: 50);
      
      if (articles.isEmpty) {
        _navigateToNewsPage();
        return;
      }
      
      NewsArticle? matchedArticle;
      for (final article in articles) {
        if (article.title.toLowerCase() == payload.toLowerCase()) {
          matchedArticle = article;
          break;
        }
      }
      
      if (matchedArticle != null) {
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (context) => NewsArticleScreen(article: matchedArticle!),
          ),
        );
      } else {
        _navigateToNewsPage();
      }
    } catch (e, stack) {
      LogService.log('Error handling notification tap: $e\n$stack', category: 'notifications_error');
      _navigateToNewsPage();
    }
  }
  
  static void _navigateToNewsPage() {
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => const MainScreen(initialIndex: 0),
      ),
      (route) => false,
    );
  }

  static Future<void> showNotification({
    required String title,
    required String body,
    required String payload,
    String? imageUrl,
  }) async {
    if (!_isInitialized) {
      LogService.log('Notification service not initialized', category: 'notifications_error');
      return;
    }

    final status = await checkNotificationPermissionStatus();
    if (!status.isGranted) {
      LogService.log('Notification permission not granted', category: 'notifications_warning');
      return;
    }

    AndroidNotificationDetails androidDetails;

    if (imageUrl != null && imageUrl.isNotEmpty) {
      try {
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
            largeIcon: FilePathAndroidBitmap(tempPath),
          );
        } else {
          androidDetails = _createTextNotification(title, body);
        }
      } catch (e) {
        LogService.log('Error processing notification image: $e', category: 'notifications_error');
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
      final notificationId = payload.hashCode;
      await _notifications.show(
        notificationId,
        title,
        body,
        notificationDetails,
        payload: payload,
      );
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
