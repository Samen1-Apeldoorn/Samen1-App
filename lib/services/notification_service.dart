import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../main.dart';
import '../services/log_service.dart';

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

    await _notifications.initialize(settings,
        onDidReceiveNotificationResponse: (details) async {
      LogService.log('Notification clicked with payload: ${details.payload}', category: 'notifications');
      handleDeepLink(details.payload); // Use the handleDeepLink method from main.dart
    });

    // Request permissions for Android
    final androidImplementation = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      final granted = await androidImplementation.requestNotificationsPermission();
      LogService.log('Notification permission granted: $granted', category: 'notifications');
    }
  }

  static Future<void> showNotification({
    required String title,
    required String body,
    required String payload,
    String? imageUrl,
  }) async {
    LogService.log('Preparing to show notification', category: 'notifications');
    LogService.log('Notification details - Title: $title, Payload: $payload', category: 'notifications');

    AndroidNotificationDetails androidDetails;

    if (imageUrl != null) {
      try {
        LogService.log('Downloading image from: $imageUrl', category: 'notifications');
        final response = await http.get(Uri.parse(imageUrl));
        final bytes = response.bodyBytes;
        final tempDir = await getTemporaryDirectory();
        final tempPath = '${tempDir.path}/notification_image.jpg';
        await File(tempPath).writeAsBytes(bytes);
        LogService.log('Image saved successfully', category: 'notifications');

        androidDetails = AndroidNotificationDetails(
          'samen1_news',
          ' ', 
          channelDescription: 'Nieuws updates van Samen1',
          importance: Importance.high,
          priority: Priority.high,
          color: const Color(0xFFFA6401),
          styleInformation: BigPictureStyleInformation(
            FilePathAndroidBitmap(tempPath),
            hideExpandedLargeIcon: false,
            contentTitle: title, // Use the article title here
            summaryText: body,
          ),
        );
      } catch (e) {
        LogService.log('Error processing image: $e', category: 'notifications_error');
        androidDetails = AndroidNotificationDetails(
          'samen1_news',
          ' ', // Empty or minimal channel name
          channelDescription: 'Nieuws updates van Samen1',
          importance: Importance.high,
          priority: Priority.high,
          color: const Color(0xFFFA6401),
          styleInformation: BigTextStyleInformation(
            body, // Use the article body here
            contentTitle: title, // Use the article title here
          ),
        );
      }
    } else {
      LogService.log('No image provided for notification', category: 'notifications');
      androidDetails = AndroidNotificationDetails(
        'samen1_news',
        ' ', // Empty or minimal channel name
        channelDescription: 'Nieuws updates van Samen1',
        importance: Importance.high,
        priority: Priority.high,
        color: const Color(0xFFFA6401),
        styleInformation: BigTextStyleInformation(
          body, // Use the article body here
          contentTitle: title, // Use the article title here
        ),
      );
    }

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(),
    );

    try {
      LogService.log('Showing notification', category: 'notifications');
      debugPrint('Attempting to show notification: $title');
      await _notifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        notificationDetails,
        payload: payload,
      );
      LogService.log('Notification shown successfully', category: 'notifications');
      debugPrint('Notification shown successfully');
    } catch (e) {
      LogService.log('Error showing notification: $e', category: 'notifications_error');
      debugPrint('Error showing notification: $e');
    }
  }
}
