import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class NotificationService {
  static final _notifications = FlutterLocalNotificationsPlugin();
  
  static Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(android: androidSettings, iOS: iosSettings);

    await _notifications.initialize(settings,
        onDidReceiveNotificationResponse: (details) async {
      debugPrint('Notification clicked: ${details.payload}');
    });

    // Request permissions for Android
    final androidImplementation = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
      debugPrint('Notification permission requested');
    }
  }

  static Future<void> showNotification({
    required String title,
    required String body,
    required String payload,
    String? imageUrl,
  }) async {
    AndroidNotificationDetails androidDetails;

    if (imageUrl != null) {
      try {
        debugPrint('Downloading image from: $imageUrl'); // Debug logging
        final response = await http.get(Uri.parse(imageUrl));
        final bytes = response.bodyBytes;
        final tempDir = await getTemporaryDirectory();
        final tempPath = '${tempDir.path}/notification_image.jpg';
        await File(tempPath).writeAsBytes(bytes);
        debugPrint('Image saved to: $tempPath'); // Debug logging

        androidDetails = AndroidNotificationDetails(
          'samen1_news',
          'Samen1 Nieuws',
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
        debugPrint('Error processing image: $e');
        androidDetails = const AndroidNotificationDetails(
          'samen1_news',
          'Samen1 Nieuws',
          channelDescription: 'Nieuws updates van Samen1',
          importance: Importance.high,
          priority: Priority.high,
          color: Color(0xFFFA6401),
        );
      }
    } else {
      androidDetails = const AndroidNotificationDetails(
        'samen1_news',
        'Samen1 Nieuws',
        channelDescription: 'Nieuws updates van Samen1',
        importance: Importance.high,
        priority: Priority.high,
        color: Color(0xFFFA6401),
      );
    }

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(),
    );

    try {
      debugPrint('Attempting to show notification: $title');
      await _notifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        notificationDetails,
        payload: payload,
      );
      debugPrint('Notification shown successfully');
    } catch (e) {
      debugPrint('Error showing notification: $e');
    }
  }
}
