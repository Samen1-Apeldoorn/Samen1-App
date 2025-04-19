import 'package:html/parser.dart' as htmlparser;
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../services/log_service.dart';
import 'dart:async'; // Import async library for Future.delayed

class NewsArticle {
  final int id;
  final String date;
  final String title;
  final String content;
  final String excerpt;
  final String link;
  final String imageUrl;
  final String? imageCaption;
  final String category;
  final String author;
  final Map<String, dynamic>? _mediaDetails; // Store media details for context-based selection

  static const Map<int, String> predefinedNames = {
    4: "Serge Poppelaars",
    20: "Donya Tijdink",
    7: "Christiaan Geitenbeek",
    8: "Floris van den Broek",
    25: "Vera Kaal",

  };

  NewsArticle({
    required this.id,
    required this.date,
    required this.title,
    required this.content,
    required this.excerpt,
    required this.link,
    required this.imageUrl, // Keep this as the default/primary URL
    this.imageCaption,
    required this.category,
    required this.author,
    Map<String, dynamic>? mediaDetails, // Add mediaDetails parameter
  }) : _mediaDetails = mediaDetails; // Initialize _mediaDetails
  
  // Extract the image sizes from the media object
  static String _extractImageUrl(Map<String, dynamic> media) {
    final sizes = media['media_details']?['sizes'];
    if (sizes == null) return media['source_url'] ?? '';
    
    return sizes['large']?['source_url'] ??
           sizes['medium_large']?['source_url'] ??
           sizes['medium']?['source_url'] ??
           media['source_url'] ?? '';
  }

  // Get the category from the class_list field
  static String _getCategoryFromClassList(List<dynamic>? classList) {
    if (classList == null || classList.isEmpty) return 'Regio';
    
    // Define the category mappings
    final categoryMap = {
      'category-67': '112',
      'category-112': '112',
      'category-73': 'Cultuur',
      'category-cultuur': 'Cultuur',
      'category-72': 'Evenementen',
      'category-evenementen': 'Evenementen',
      'category-71': 'Gemeente',
      'category-gemeente': 'Gemeente',
      'category-69': 'Politiek',
      'category-politiek': 'Politiek',
      'category-1': 'Regio',
      'category-regio': 'Regio',
    };
    
    // Find the first matching category
    for (final item in classList) {
      if (item == null) continue; // Skip null items
      final categoryString = item.toString().toLowerCase();
      if (categoryString.startsWith('category-')) {
        return categoryMap[item.toString()] ?? 'Regio';
      }
    }
    
    return 'Regio'; // Default if no category found
  }

  // New method to get image URL based on context
  String getImageUrlForContext(String context) {
    final sizes = _mediaDetails?['sizes'];
    final sourceUrl = _mediaDetails?['source_url'] ?? imageUrl; // Fallback to original imageUrl if needed

    if (sizes == null) return sourceUrl; // Return source_url if no sizes available

    switch (context) {
      case 'featured':
        return sizes['large']?['source_url'] ??
               sizes['medium_large']?['source_url'] ??
               sourceUrl; // Fallback to source_url
      case 'list_item':
        // Prefer medium for list items, fallback to thumbnail, then source_url
        return sizes['medium']?['source_url'] ??
               sizes['thumbnail']?['source_url'] ??
               sourceUrl; // Fallback to source_url
      default:
        // Default to the primary imageUrl (which should be large/medium_large)
        return imageUrl;
    }
  }

  // Create a NewsArticle object from JSON data
  factory NewsArticle.fromJson(Map<String, dynamic> json) {
    final featuredMedia = json['_embedded']?['wp:featuredmedia'];
    final media = featuredMedia != null && featuredMedia.isNotEmpty ? featuredMedia[0] : null;
    final mediaDetails = media?['media_details']; // Extract media_details
    
    // Handle class_list safely
    List<dynamic>? classList;
    try {
      classList = json['class_list'] as List<dynamic>?;
    } catch (e) {
      // If casting fails, set to null
      classList = null;
    }
    
    // Decode HTML entities in title
    String title = '';
    if (json['title']?['rendered'] != null) {
      final document = htmlparser.parse(json['title']['rendered']);
      title = document.body?.text ?? '';
    }
    
    // Decode HTML entities in excerpt
    String excerpt = '';
    if (json['excerpt']?['rendered'] != null) {
      final document = htmlparser.parse(json['excerpt']['rendered']);
      excerpt = document.body?.text ?? '';
    }
    
    return NewsArticle(
      id: json['id'],
      date: json['date'],
      title: title,
      content: json['content']?['rendered'] ?? '',
      excerpt: excerpt,
      link: json['link'] ?? '',
      // Set imageUrl to the largest available as default
      imageUrl: media != null ? _extractImageUrl(media) : '',
      imageCaption: media?['caption']?['rendered'] != null
          ? htmlparser.parse(media!['caption']['rendered']).body?.text
          : null,
      category: _getCategoryFromClassList(classList),
      author: predefinedNames[json['author']] ?? 'Onbekend: ${json['author']}',
      mediaDetails: mediaDetails, // Pass media details to constructor
    );
  }
}

class NewsService {
  static const String _baseUrl = 'https://api.omroepapeldoorn.nl/api/nieuws';
  static const String _categoryBaseUrl = 'https://api.omroepapeldoorn.nl/api/categorie';

  // Cache storage
  static final Map<String, List<NewsArticle>> _newsCache = {};
  static final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheDuration = Duration(minutes: 10); // Cache validity duration
  static const Duration _cacheReturnDelay = Duration(milliseconds: 150); // Artificial delay for cached data

  // Helper to generate cache key
  static String _getCacheKey({int? categoryId, required int page}) {
    return "cat_${categoryId ?? 'all'}_page_$page";
  }

  // Helper to check cache validity
  static bool _isCacheValid(String key) {
    final timestamp = _cacheTimestamps[key];
    if (timestamp == null) return false;
    return DateTime.now().difference(timestamp) < _cacheDuration;
  }

  static Future<List<NewsArticle>> getNews({
    int page = 1, 
    int perPage = 15,
    bool forceRefresh = false, // Add forceRefresh parameter
  }) async {
    final cacheKey = _getCacheKey(page: page); // No categoryId for general news

    // Check cache first, unless forceRefresh is true
    if (!forceRefresh && _isCacheValid(cacheKey)) {
      LogService.log('Returning cached news for page $page after delay', category: 'news_cache');
      // Add a small delay before returning cached data
      await Future.delayed(_cacheReturnDelay); 
      return _newsCache[cacheKey]!;
    }

    // Fetch from API if cache is invalid or forceRefresh is true
    final url = '$_baseUrl?per_page=$perPage&page=$page&_embed=true';
    LogService.log(
      'Fetching news from API: $url (ForceRefresh: $forceRefresh)', 
      category: 'news_api'
    );

    try {
      final response = await http.get(Uri.parse(url));
      LogService.log('API response status: ${response.statusCode}', category: 'news_api');
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final articles = data.map((json) => NewsArticle.fromJson(json)).toList();
        
        // Update cache
        _newsCache[cacheKey] = articles;
        _cacheTimestamps[cacheKey] = DateTime.now();
        LogService.log('Fetched and cached ${articles.length} articles for page $page', category: 'news_cache');
        
        return articles;
      } else {
        LogService.log(
          'Failed to load news: ${response.statusCode} - ${response.body}', 
          category: 'news_error'
        );
        // Return empty list on failure to prevent breaking the UI flow
        return []; 
      }
    } catch (e) {
      LogService.log('Error fetching news: $e', category: 'news_error');
      // Return empty list on error
      return []; 
    }
  }

  static Future<List<NewsArticle>> getNewsByCategory({
    required int categoryId,
    int page = 1, 
    int perPage = 15,
    bool forceRefresh = false, // Add forceRefresh parameter
  }) async {
    final cacheKey = _getCacheKey(categoryId: categoryId, page: page);

    // Check cache first, unless forceRefresh is true
    if (!forceRefresh && _isCacheValid(cacheKey)) {
      LogService.log('Returning cached news for category $categoryId, page $page after delay', category: 'news_cache');
      // Add a small delay before returning cached data
      await Future.delayed(_cacheReturnDelay);
      return _newsCache[cacheKey]!;
    }

    // Fetch from API if cache is invalid or forceRefresh is true
    final url = '$_categoryBaseUrl?per_page=$perPage&page=$page&categorie=$categoryId&_embed=true';
    LogService.log(
      'Fetching category news from API: $url (ForceRefresh: $forceRefresh)', 
      category: 'news_api'
    );

    try {
      final response = await http.get(Uri.parse(url));
      LogService.log('API response status: ${response.statusCode}', category: 'news_api');
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final articles = data.map((json) => NewsArticle.fromJson(json)).toList();

        // Update cache
        _newsCache[cacheKey] = articles;
        _cacheTimestamps[cacheKey] = DateTime.now();
        LogService.log('Fetched and cached ${articles.length} articles for category $categoryId, page $page', category: 'news_cache');

        return articles;
      } else if (response.statusCode == 429) {
        // Handle rate limiting (retry logic remains the same)
        LogService.log('Rate limited (429), waiting briefly before retry', category: 'news_api');
        await Future.delayed(const Duration(milliseconds: 500));
        
        final retryResponse = await http.get(Uri.parse(url));
        if (retryResponse.statusCode == 200) {
          final List<dynamic> data = json.decode(retryResponse.body);
          final articles = data.map((json) => NewsArticle.fromJson(json)).toList();

          // Update cache on successful retry
          _newsCache[cacheKey] = articles;
          _cacheTimestamps[cacheKey] = DateTime.now();
          LogService.log('Retry successful, cached ${articles.length} category articles for page $page', category: 'news_cache');

          return articles;
        }
        
        LogService.log(
          'Failed to load category news after retry: ${retryResponse.statusCode} - ${retryResponse.body}', 
          category: 'news_error'
        );
        return []; // Return empty on retry failure
      } else {
         LogService.log(
          'Failed to load category news: ${response.statusCode} - ${response.body}', 
          category: 'news_error'
        );
        return []; // Return empty on other failures
      }
    } catch (e) {
      LogService.log('Error fetching category news: $e', category: 'news_error');
      return []; // Return empty on exception
    }
  }
}
