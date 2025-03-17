import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class DiscordService {
  static Future<bool> sendBugReport(String report) async {
    try {
      final chunks = _splitIntoChunks(report, 1900);
      
      for (var i = 0; i < chunks.length; i++) {
        final response = await http.post(
          Uri.parse(AppConfig.discordWebhookUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'content': '```\n${chunks[i]}\n```',
            'username': 'Samen1 Bug Reporter',
          }),
        );
        
        if (response.statusCode != 204) {
          return false;
        }
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  static List<String> _splitIntoChunks(String text, int chunkSize) {
    List<String> chunks = [];
    for (var i = 0; i < text.length; i += chunkSize) {
      var end = (i + chunkSize < text.length) ? i + chunkSize : text.length;
      chunks.add(text.substring(i, end));
    }
    return chunks;
  }
}
