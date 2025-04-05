import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'log_service.dart';

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
    await _notifications.initialize(settings);



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
    LogService.log('Preparing notification: $title', category: 'notifications');
    
    AndroidNotificationDetails androidDetails;

    if (imageUrl != null) {
      try {
        LogService.log('Downloading image from: $imageUrl', category: 'notifications');
        final response = await http.get(Uri.parse(imageUrl));
        final bytes = response.bodyBytes;
        final tempDir = await getTemporaryDirectory();
        final tempPath = '${tempDir.path}/notification_image.jpg';
        await File(tempPath).writeAsBytes(bytes);
        
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
            contentTitle: title,
            summaryText: body,
          ),
        );
      } catch (e) {
        LogService.log('Error processing image: $e', category: 'notifications_error');
        androidDetails = _createTextNotification(title, body);
      }
    } else {
      androidDetails = _createTextNotification(title, body);
    }

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(),
    );

    try {
      await _notifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        notificationDetails,
        payload: payload,
      );
      LogService.log('Notification shown successfully', category: 'notifications');
    } catch (e) {
      LogService.log('Error showing notification: $e', category: 'notifications_error');
    }
  }
  
  static AndroidNotificationDetails _createTextNotification(String title, String body) {
    return AndroidNotificationDetails(
      'samen1_news',
      ' ',
      channelDescription: 'Nieuws updates van Samen1',
      importance: Importance.high,
      priority: Priority.high,
      color: const Color(0xFFFA6401),
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
      ),
    );
  }
}
