import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:html/parser.dart' as htmlparser;
import 'notification_service.dart';
import 'log_service.dart';

class RSSService {
  static const _feedUrl = 'https://samen1.nl/feed/';
  static const _lastCheckKey = 'last_rss_check';

  static Future<String> checkForNewContent() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final notificationsEnabled = prefs.getBool('notifications_enabled') ?? false;
      if (!notificationsEnabled) {
        return '';
      }
      
      final lastCheck = prefs.getString(_lastCheckKey) ?? '';

      final firstItem = await _fetchLatestItem();
      if (firstItem == null) {
        return '';
      }
      
      final enabledCategories = prefs.getStringList('enabled_categories') ?? [];
      
      final isEnabled = enabledCategories.any(
        (enabled) => enabled.toLowerCase() == firstItem.category.toLowerCase()
      );
      
      if (!isEnabled) {
        await prefs.setString(_lastCheckKey, firstItem.pubDate);
        return '';
      }
      
      if (firstItem.pubDate != lastCheck) {
        final sanitizedTitle = _sanitizeText(firstItem.title);
        await NotificationService.showNotification(
          title: firstItem.category,
          body: sanitizedTitle,
          payload: sanitizedTitle,
          imageUrl: firstItem.imageUrl,
        );
        await prefs.setString(_lastCheckKey, firstItem.pubDate);
        return '';
      }
      
      return '';
    } catch (e) {
      LogService.log('Error checking RSS: $e', category: 'rss_error');
      return '';
    }
  }

  static Future<String> sendTestNotification() async {
    try {
      final firstItem = await _fetchLatestItem();
      if (firstItem == null) {
        return 'Fout bij ophalen feed';
      }

      final sanitizedTitle = _sanitizeText(firstItem.title);
      await NotificationService.showNotification(
        title: firstItem.category,
        body: sanitizedTitle,
        payload: sanitizedTitle,
        imageUrl: firstItem.imageUrl,
      );
      
      return 'Test notificatie verzonden';
    } catch (e) {
      LogService.log('Error sending test notification: $e', category: 'rss_error');
      return 'Fout bij versturen test notificatie';
    }
  }
  
  static Future<RSSItem?> _fetchLatestItem() async {
    try {
      final response = await http.get(Uri.parse(_feedUrl));
      if (response.statusCode != 200) {
        LogService.log('Failed to fetch RSS feed: ${response.statusCode}', category: 'rss_error');
        return null;
      }

      final content = response.body;
      final itemRegex = RegExp(r'<item>(.*?)</item>', dotAll: true);
      
      final itemMatch = itemRegex.firstMatch(content);
      if (itemMatch == null) {
        return null;
      }
      
      final itemContent = itemMatch.group(1) ?? '';
      
      final titleRegex = RegExp(r'<title>\s*(.*?)\s*</title>', dotAll: true);
      final linkRegex = RegExp(r'<link>\s*(.*?)\s*</link>', dotAll: true);
      final dateRegex = RegExp(r'<pubDate>\s*(.*?)\s*</pubDate>', dotAll: true);
      final imageRegex = RegExp(r'<(media:content|enclosure)[^>]*(?:url|src)="([^"]*)"', dotAll: true);
      final descRegex = RegExp(r'<description><!\[CDATA\[(.*?)\]\]></description>', dotAll: true);
      final categoryRegex = RegExp(r'<category>(?:\s*<!\[CDATA\[)?(.*?)(?:\]\]>\s*)?</category>', dotAll: true);

      final title = titleRegex.firstMatch(itemContent)?.group(1)?.trim();
      final link = linkRegex.firstMatch(itemContent)?.group(1)?.trim();
      final pubDate = dateRegex.firstMatch(itemContent)?.group(1)?.trim();
      final imageMatch = imageRegex.firstMatch(itemContent);
      var imageUrl = imageMatch?.group(2)?.trim();
      final description = descRegex.firstMatch(itemContent)?.group(1)?.trim() ?? '';
      final categoryMatch = categoryRegex.firstMatch(itemContent);
      final category = categoryMatch?.group(1)?.trim() ?? 'Overig';
      
      if (imageUrl != null && imageUrl.contains('-150x150')) {
        imageUrl = imageUrl.replaceAll('-150x150', '');
      }

      if (title != null && link != null && pubDate != null) {
        return RSSItem(
          title: title,
          link: link,
          pubDate: pubDate,
          description: description,
          imageUrl: imageUrl,
          category: category.isEmpty ? 'Overig' : category,
        );
      }
      return null;
    } catch (e) {
      LogService.log('Error parsing RSS feed: $e', category: 'rss_error');
      return null;
    }
  }

  static String _sanitizeText(String text) {
    String sanitized = text
      .replaceAll('&#8217;', "'")
      .replaceAll('&#8216;', "'")
      .replaceAll('&#8220;', '"')
      .replaceAll('&#8221;', '"')
      .replaceAll('&quot;', '"')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&rsquo;', "'")
      .replaceAll('&lsquo;', "'")
      .replaceAll('&rdquo;', '"')
      .replaceAll('&ldquo;', '"')
      .replaceAll('&ndash;', '–')
      .replaceAll('&mdash;', '—')
      .replaceAll('&#39;', "'");
    
    try {
      return htmlparser.parse(sanitized).body?.text ?? sanitized;
    } catch (e) {
      return sanitized;
    }
  }
}

class RSSItem {
  final String title;
  final String link;
  final String pubDate;
  final String description;
  final String? imageUrl;
  final String category;

  RSSItem({
    required this.title,
    required this.link,
    required this.pubDate,
    required this.description,
    this.imageUrl,
    required this.category,
  });
}
