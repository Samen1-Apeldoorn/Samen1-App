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
      LogService.log('Checking for new RSS content', category: 'rss');
      final prefs = await SharedPreferences.getInstance();
      final lastCheck = prefs.getString(_lastCheckKey) ?? '';

      final firstItem = await _fetchLatestItem();
      if (firstItem == null) {
        LogService.log('Failed to fetch RSS feed', category: 'rss_error');
        return '';
      }
      
      // Check if category is enabled
      final enabledCategories = prefs.getStringList('enabled_categories') ?? [];
      if (!enabledCategories.contains(firstItem.category)) {
        LogService.log('Skipping notification - category ${firstItem.category} is disabled', category: 'rss');
        return '';
      }
      
      if (firstItem.pubDate != lastCheck) {
        LogService.log('New content found, sending notification', category: 'rss');
        await NotificationService.showNotification(
          title: 'Samen1 Nieuws',
          body: _sanitizeText(firstItem.title),
          payload: firstItem.link,
          imageUrl: firstItem.imageUrl,
        );
        await prefs.setString(_lastCheckKey, firstItem.pubDate);
        return '';
      }
      
      LogService.log('No new content found', category: 'rss');
      return '';
    } catch (e) {
      LogService.log('Error checking RSS: $e', category: 'rss_error');
      return '';
    }
  }

  static Future<String> sendTestNotification() async {
    try {
      LogService.log('Sending test notification', category: 'rss');
      final firstItem = await _fetchLatestItem();
      if (firstItem == null) {
        return 'Fout bij ophalen feed';
      }

      LogService.log('Sending notification for: ${firstItem.title}', category: 'rss');
      await NotificationService.showNotification(
        title: 'Samen1 Nieuws',
        body: _sanitizeText(firstItem.title),
        payload: firstItem.link,
        imageUrl: firstItem.imageUrl,
      );
      return '';
    } catch (e) {
      LogService.log('Error sending test notification: $e', category: 'rss_error');
      return 'Fout: $e';
    }
  }

  static Future<RSSItem?> _fetchLatestItem() async {
    final response = await http.get(Uri.parse(_feedUrl));
    if (response.statusCode != 200) return null;
    return _parseFirstItem(response.body);
  }

  static RSSItem? _parseFirstItem(String xmlString) {
    LogService.log('Parsing RSS feed', category: 'rss');

    final itemRegex = RegExp(r'<item>(.*?)</item>', dotAll: true);
    final itemMatch = itemRegex.firstMatch(xmlString);

    if (itemMatch != null) {
      final itemContent = itemMatch.group(1) ?? '';
      
      final titleRegex = RegExp(r'<title>\s*(.*?)\s*</title>', dotAll: true);
      final linkRegex = RegExp(r'<link>\s*(.*?)\s*</link>', dotAll: true);
      final dateRegex = RegExp(r'<pubDate>\s*(.*?)\s*</pubDate>', dotAll: true);
      final imageRegex = RegExp(r'<(media:content|enclosure)[^>]*(?:url|src)="([^"]*)"', dotAll: true);
      final descRegex = RegExp(r'<description><!\[CDATA\[(.*?)\]\]></description>', dotAll: true);
      final categoryRegex = RegExp(r'<category>\s*(.*?)\s*</category>', dotAll: true);

      final title = titleRegex.firstMatch(itemContent)?.group(1)?.trim();
      final link = linkRegex.firstMatch(itemContent)?.group(1)?.trim();
      final pubDate = dateRegex.firstMatch(itemContent)?.group(1)?.trim();
      final imageMatch = imageRegex.firstMatch(itemContent);
      var imageUrl = imageMatch?.group(2)?.trim();
      final description = descRegex.firstMatch(itemContent)?.group(1)?.trim() ?? '';
      final category = categoryRegex.firstMatch(itemContent)?.group(1)?.trim() ?? 'Overig';
      
      // Transform thumbnail URL to full image URL
      if (imageUrl != null && imageUrl.contains('-150x150')) {
        imageUrl = imageUrl.replaceAll('-150x150', '');
        LogService.log('Transformed image URL: $imageUrl', category: 'rss');
      }

      if (title != null && link != null && pubDate != null) {
        LogService.log('Successfully parsed RSS item', category: 'rss');
        return RSSItem(
          title: title,
          link: link,
          pubDate: pubDate,
          description: description,
          imageUrl: imageUrl,
          category: category,
        );
      }
    }
    LogService.log('No valid RSS item found', category: 'rss_error');
    return null;
  }

  // New helper method to sanitize text
  static String _sanitizeText(String text) {
    // Replace common HTML entities and special characters
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
    
    // For any remaining HTML entities, try to decode them
    try {
      // Parse as HTML and get text content to decode any remaining entities
      final document = htmlparser.parse(sanitized);
      sanitized = document.body?.text ?? sanitized;
    } catch (e) {
      LogService.log('Error decoding HTML entities: $e', category: 'rss_error');
    }
    
    return sanitized;
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
