import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'version_service.dart';

class LogService {
  static final List<LogEntry> _sessionLogs = [];

  static void log(String message, {String? category}) {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      message: message,
      category: category ?? 'general',
    );
    _sessionLogs.add(entry);
    debugPrint('${entry.timestamp}: ${entry.category} - ${entry.message}');
  }

  static Future<String> generateReport(String userDescription) async {
    final buffer = StringBuffer();
    
    buffer.writeln('Bug Report - ${DateTime.now()}');
    buffer.writeln('User Description: $userDescription\n');
    
    try {
      buffer.writeln('App Version: ${VersionService.fullVersionString}');
      
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        buffer.writeln('Device: ${androidInfo.manufacturer} ${androidInfo.model}');
        buffer.writeln('Android Version: ${androidInfo.version.release} (SDK ${androidInfo.version.sdkInt})');
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        buffer.writeln('Device: ${iosInfo.name} ${iosInfo.model}');
        buffer.writeln('iOS Version: ${iosInfo.systemVersion}');
      }
    } catch (e) {
      buffer.writeln('Error getting device info: $e');
    }

    buffer.writeln('\nSession Logs:');
    if (_sessionLogs.isEmpty) {
      buffer.writeln('No logs recorded in this session.');
    } else {
      for (var entry in _sessionLogs) {
        buffer.writeln('${entry.timestamp} [${entry.category}] ${entry.message}');
      }
    }
    
    return buffer.toString();
  }
}

class LogEntry {
  final DateTime timestamp;
  final String message;
  final String category;

  LogEntry({
    required this.timestamp,
    required this.message,
    required this.category,
  });
}
