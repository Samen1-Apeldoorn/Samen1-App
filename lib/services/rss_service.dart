import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'notification_service.dart';

class RSSService {
  static const _feedUrl = 'https://samen1.nl/feed/';
  static const _lastCheckKey = 'last_rss_check';

  static Future<String> checkForNewContent() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastCheck = prefs.getString(_lastCheckKey) ?? '';

      final firstItem = await _fetchLatestItem();
      if (firstItem == null) {
        return 'Fout bij ophalen feed';
      }
      
      if (firstItem.pubDate != lastCheck) {
        await NotificationService.showNotification(
          title: firstItem.title,
          body: firstItem.description,
          payload: firstItem.link,
        );
        await prefs.setString(_lastCheckKey, firstItem.pubDate);
        return 'Nieuwe melding verzonden: ${firstItem.title}';
      }
      return 'Geen nieuwe artikelen gevonden';
    } catch (e) {
      return 'Fout: $e';
    }
  }

  static Future<String> sendTestNotification() async {
    try {
      debugPrint('Sending test notification...');
      final firstItem = await _fetchLatestItem();
      if (firstItem == null) {
        return 'Fout bij ophalen feed';
      }

      debugPrint('Sending notification for: ${firstItem.title}');
      await NotificationService.showNotification(
        title: 'Samen1 Nieuws',  // Duidelijke titel voor de notificatie
        body: firstItem.title,   // Artikel titel als inhoud
        payload: firstItem.link,
      );
      return 'Test melding verzonden voor: ${firstItem.title}';
    } catch (e) {
      debugPrint('Error in sendTestNotification: $e');
      return 'Fout: $e';
    }
  }

  static Future<RSSItem?> _fetchLatestItem() async {
    final response = await http.get(Uri.parse(_feedUrl));
    if (response.statusCode != 200) return null;
    return _parseFirstItem(response.body);
  }

  static RSSItem? _parseFirstItem(String xmlString) {
    debugPrint('Parsing RSS feed...');

    // Match everything between first <item> and </item>
    final itemRegex = RegExp(r'<item>(.*?)</item>', dotAll: true);
    final itemMatch = itemRegex.firstMatch(xmlString);

    if (itemMatch != null) {
      final itemContent = itemMatch.group(1) ?? '';
      debugPrint('Found item content: $itemContent');

      // Updated regex patterns to better match the actual feed structure
      final titleRegex = RegExp(r'<title>\s*(.*?)\s*</title>', dotAll: true);
      final linkRegex = RegExp(r'<link>\s*(.*?)\s*</link>', dotAll: true);
      final dateRegex = RegExp(r'<pubDate>\s*(.*?)\s*</pubDate>', dotAll: true);
      final descRegex = RegExp(r'<description><!\[CDATA\[(.*?)\]\]></description>', dotAll: true);

      final title = titleRegex.firstMatch(itemContent)?.group(1)?.trim();
      final link = linkRegex.firstMatch(itemContent)?.group(1)?.trim();
      final pubDate = dateRegex.firstMatch(itemContent)?.group(1)?.trim();
      final description = descRegex.firstMatch(itemContent)?.group(1)?.trim();

      if (title != null && link != null && pubDate != null) {
        debugPrint('Successfully parsed RSS item:');
        debugPrint('Title: $title');
        debugPrint('Link: $link');
        debugPrint('Date: $pubDate');
        debugPrint('Description: ${description ?? "No description"}');

        return RSSItem(
          title: title,
          link: link,
          pubDate: pubDate,
          description: description ?? title,
        );
      }
    }
    debugPrint('No valid RSS item found');
    return null;
  }
}

class RSSItem {
  final String title;
  final String link;
  final String pubDate;
  final String description;

  RSSItem({
    required this.title, 
    required this.link, 
    required this.pubDate, 
    required this.description,
  });
}
