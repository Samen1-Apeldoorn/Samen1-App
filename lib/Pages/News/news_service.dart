import 'package:html/parser.dart' as htmlparser;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/log_service.dart';

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

  NewsArticle({
    required this.id,
    required this.date,
    required this.title,
    required this.content,
    required this.excerpt,
    required this.link,
    required this.imageUrl,
    this.imageCaption,
    required this.category,
  });
  
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

  // Create a NewsArticle object from JSON data
  factory NewsArticle.fromJson(Map<String, dynamic> json) {
    final featuredMedia = json['_embedded']?['wp:featuredmedia'];
    final media = featuredMedia != null && featuredMedia.isNotEmpty ? featuredMedia[0] : null;
    
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
      imageUrl: media != null ? _extractImageUrl(media) : '',
      imageCaption: media?['caption']?['rendered'] != null
          ? htmlparser.parse(media!['caption']['rendered']).body?.text
          : null,
      category: _getCategoryFromClassList(classList),
    );
  }
}

class NewsService {
  static const String _baseUrl = 'https://api.omroepapeldoorn.nl/api/nieuws';
  
  // Cache settings
  static const int _cacheExpiryMinutes = 15; // How long to cache results
  static const String _cacheKeyPrefix = 'news_cache_';
  static const String _lastFetchTimeKey = 'last_fetch_time';
  
  // Request limiting queue
  static final List<_QueuedRequest> _requestQueue = [];
  static bool _processingQueue = false;
  static DateTime _lastRequestTime = DateTime.now().subtract(const Duration(seconds: 10));
  static int _requestsInWindow = 0;
  static const int _maxRequestsPerWindow = 8; // Leave room for error - max 10 per 10s
  static const int _windowDurationSeconds = 10;
  
  // In-memory cache for quick access without loading from preferences
  static final Map<String, _CachedData> _memoryCache = {};
  
  // Adding a throttle timer
  static Timer? _throttleTimer;
  
  // Main method to get news with caching and request limiting
  static Future<List<NewsArticle>> getNews({
    int page = 1, 
    int perPage = 11,
    int skipFirst = 0,
    bool bypassCache = false,
  }) async {
    final cacheKey = '${_cacheKeyPrefix}main_$page\_$perPage';
    
    // Check memory cache first (fastest)
    if (!bypassCache && _memoryCache.containsKey(cacheKey)) {
      final cachedData = _memoryCache[cacheKey]!;
      if (!cachedData.isExpired()) {
        LogService.log('Using memory cache for news page $page', category: 'news_cache');
        
        final articles = cachedData.data;
        // Apply skipFirst after retrieving from cache
        return skipFirst > 0 ? articles.skip(skipFirst).toList() : articles;
      }
    }
    
    // Check disk cache if not in memory
    if (!bypassCache) {
      final cachedArticles = await _getCachedArticles(cacheKey);
      if (cachedArticles != null) {
        LogService.log('Using disk cache for news page $page', category: 'news_cache');
        
        // Apply skipFirst after retrieving from cache
        return skipFirst > 0 ? cachedArticles.skip(skipFirst).toList() : cachedArticles;
      }
    }
    
    // Not in cache, queue API request
    LogService.log('Queuing API request for news page $page', category: 'news_api');
    
    final completer = Completer<List<NewsArticle>>();
    
    _queueRequest(
      requestFunction: () async {
        try {
          final articles = await _fetchNewsFromApi(page: page, perPage: perPage);
          
          // Cache the full response before applying skipFirst
          if (articles.isNotEmpty) {
            await _cacheArticles(cacheKey, articles);
          }
          
          // Apply skipFirst only to the returned result
          return skipFirst > 0 ? articles.skip(skipFirst).toList() : articles;
        } catch (e) {
          LogService.log('API request failed for news page $page: $e', category: 'news_error');
          rethrow;
        }
      },
      completer: completer,
    );
    
    // Start processing queue if it's not already running
    _processQueue();
    
    return completer.future;
  }
  
  // Method to get news by category with caching and request limiting
  static Future<List<NewsArticle>> getNewsByCategory({
    required int categoryId,
    int page = 1, 
    int perPage = 15,
    int skipFirst = 0,
    bool bypassCache = false,
  }) async {
    final cacheKey = '${_cacheKeyPrefix}category_${categoryId}_$page\_$perPage';
    
    // Check memory cache first
    if (!bypassCache && _memoryCache.containsKey(cacheKey)) {
      final cachedData = _memoryCache[cacheKey]!;
      if (!cachedData.isExpired()) {
        LogService.log('Using memory cache for category $categoryId page $page', category: 'news_cache');
        
        final articles = cachedData.data;
        return skipFirst > 0 ? articles.skip(skipFirst).toList() : articles;
      }
    }
    
    // Check disk cache if not in memory
    if (!bypassCache) {
      final cachedArticles = await _getCachedArticles(cacheKey);
      if (cachedArticles != null) {
        LogService.log('Using disk cache for category $categoryId page $page', category: 'news_cache');
        
        return skipFirst > 0 ? cachedArticles.skip(skipFirst).toList() : cachedArticles;
      }
    }
    
    // Not in cache, queue API request
    LogService.log('Queuing API request for category $categoryId page $page', category: 'news_api');
    
    final completer = Completer<List<NewsArticle>>();
    
    _queueRequest(
      requestFunction: () async {
        try {
          final articles = await _fetchCategoryNewsFromApi(
            categoryId: categoryId,
            page: page,
            perPage: perPage,
          );
          
          // Cache the full response
          if (articles.isNotEmpty) {
            await _cacheArticles(cacheKey, articles);
          }
          
          return skipFirst > 0 ? articles.skip(skipFirst).toList() : articles;
        } catch (e) {
          LogService.log('API request failed for category $categoryId page $page: $e', category: 'news_error');
          rethrow;
        }
      },
      completer: completer,
    );
    
    // Start processing queue if it's not already running
    _processQueue();
    
    return completer.future;
  }
  
  // Private method to fetch news directly from API
  static Future<List<NewsArticle>> _fetchNewsFromApi({
    required int page,
    required int perPage,
  }) async {
    LogService.log(
      'Fetching news from API: $_baseUrl?per_page=$perPage&page=$page', 
      category: 'news_api'
    );
    
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl?per_page=$perPage&page=$page&_embed=true')
      );
      
      LogService.log('API response status: ${response.statusCode}', category: 'news_api');
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        LogService.log('Received ${data.length} articles from API', category: 'news_api');
        
        if (data.isEmpty) {
          return [];
        }
        
        return data.map((json) => NewsArticle.fromJson(json)).toList();
      } else if (response.statusCode == 429) {
        LogService.log('Rate limit exceeded (429), backing off', category: 'news_error');
        // Wait longer than usual to recover from rate limiting
        await Future.delayed(const Duration(seconds: 5));
        throw 'Rate limit exceeded (429)';
      } else {
        LogService.log(
          'Failed to load news: ${response.statusCode} - ${response.body}', 
          category: 'news_error'
        );
        return [];
      }
    } catch (e) {
      LogService.log('Error fetching news from API: $e', category: 'news_error');
      rethrow;
    }
  }
  
  // Private method to fetch category news directly from API
  static Future<List<NewsArticle>> _fetchCategoryNewsFromApi({
    required int categoryId,
    required int page,
    required int perPage,
  }) async {
    final categoryUrl = 'https://api.omroepapeldoorn.nl/api/categorie?per_page=$perPage&page=$page&categorie=$categoryId&_embed=true';
    
    LogService.log(
      'Fetching category news from API: $categoryUrl', 
      category: 'news_api'
    );
    
    try {
      final response = await http.get(Uri.parse(categoryUrl));
      
      LogService.log('API response status: ${response.statusCode}', category: 'news_api');
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        LogService.log('Received ${data.length} category articles from API', category: 'news_api');
        
        if (data.isEmpty) {
          return [];
        }
        
        return data.map((json) => NewsArticle.fromJson(json)).toList();
      } else if (response.statusCode == 429) {
        LogService.log('Rate limit exceeded (429), backing off', category: 'news_error');
        // Wait longer than usual to recover from rate limiting
        await Future.delayed(const Duration(seconds: 5));
        throw 'Rate limit exceeded (429)';
      } else {
        throw '${response.statusCode} - ${response.body}';
      }
    } catch (e) {
      LogService.log('Error fetching category news from API: $e', category: 'news_error');
      rethrow;
    }
  }
  
  // Add a request to the queue
  static void _queueRequest({
    required Future<List<NewsArticle>> Function() requestFunction,
    required Completer<List<NewsArticle>> completer,
  }) {
    _requestQueue.add(_QueuedRequest(
      requestFunction: requestFunction,
      completer: completer,
    ));
  }
  
  // Process the queue with rate limiting
  static Future<void> _processQueue() async {
    if (_processingQueue || _requestQueue.isEmpty) return;
    
    _processingQueue = true;
    
    while (_requestQueue.isNotEmpty) {
      // Check if we're making too many requests too quickly
      final now = DateTime.now();
      final timeSinceLastRequest = now.difference(_lastRequestTime).inSeconds;
      
      // Reset counter if window has passed
      if (timeSinceLastRequest >= _windowDurationSeconds) {
        _requestsInWindow = 0;
      }
      
      // If we're at the limit, wait until the window resets
      if (_requestsInWindow >= _maxRequestsPerWindow) {
        LogService.log(
          'Request limit reached ($_maxRequestsPerWindow/$_windowDurationSeconds sec), waiting ${_windowDurationSeconds - timeSinceLastRequest} seconds', 
          category: 'news_api'
        );
        
        // Wait for the remainder of the window plus a little buffer
        final waitTime = _windowDurationSeconds - timeSinceLastRequest + 1;
        await Future.delayed(Duration(seconds: waitTime > 0 ? waitTime : 1));
        continue; // Recheck conditions after waiting
      }
      
      // If it's been less than 1 second since last request, add a small delay
      if (timeSinceLastRequest < 1) {
        await Future.delayed(const Duration(milliseconds: 1100));
      }
      
      // Process next request
      final request = _requestQueue.removeAt(0);
      
      try {
        _requestsInWindow++;
        _lastRequestTime = DateTime.now();
        
        final result = await request.requestFunction();
        request.completer.complete(result);
      } catch (e) {
        request.completer.completeError(e);
      }
    }
    
    _processingQueue = false;
  }
  
  // Save articles to cache
  static Future<void> _cacheArticles(String key, List<NewsArticle> articles) async {
    try {
      // Save to memory cache
      _memoryCache[key] = _CachedData(
        data: articles,
        timestamp: DateTime.now(),
      );
      
      // Save to persistent storage
      final prefs = await SharedPreferences.getInstance();
      
      // Convert articles to JSON for storage
      final List<Map<String, dynamic>> articlesJson = articles.map((article) => {
        'id': article.id,
        'date': article.date,
        'title': article.title,
        'content': article.content,
        'excerpt': article.excerpt,
        'link': article.link,
        'imageUrl': article.imageUrl,
        'imageCaption': article.imageCaption,
        'category': article.category,
      }).toList();
      
      // Save serialized data
      await prefs.setString(key, json.encode({
        'timestamp': DateTime.now().toIso8601String(),
        'articles': articlesJson,
      }));
      
      LogService.log('Cached ${articles.length} articles with key $key', category: 'news_cache');
    } catch (e) {
      LogService.log('Error caching articles: $e', category: 'news_error');
    }
  }
  
  // Get articles from cache if available and not expired
  static Future<List<NewsArticle>?> _getCachedArticles(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString(key);
      
      if (cachedData == null) {
        return null;
      }
      
      final data = json.decode(cachedData) as Map<String, dynamic>;
      final timestamp = DateTime.parse(data['timestamp']);
      
      // Check if cache is expired
      if (DateTime.now().difference(timestamp).inMinutes > _cacheExpiryMinutes) {
        LogService.log('Cache expired for key $key', category: 'news_cache');
        return null;
      }
      
      // Reconstruct articles from cache
      final articlesJson = data['articles'] as List<dynamic>;
      final articles = articlesJson.map((articleJson) => NewsArticle(
        id: articleJson['id'],
        date: articleJson['date'],
        title: articleJson['title'],
        content: articleJson['content'],
        excerpt: articleJson['excerpt'],
        link: articleJson['link'],
        imageUrl: articleJson['imageUrl'],
        imageCaption: articleJson['imageCaption'],
        category: articleJson['category'],
      )).toList();
      
      // Also update memory cache
      _memoryCache[key] = _CachedData(
        data: articles,
        timestamp: timestamp,
      );
      
      LogService.log('Retrieved ${articles.length} articles from cache with key $key', category: 'news_cache');
      return articles;
    } catch (e) {
      LogService.log('Error retrieving cached articles: $e', category: 'news_error');
      return null;
    }
  }
  
  // Clear all caches - useful for development or if data structure changes
  static Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      // Remove all cache entries
      for (final key in keys) {
        if (key.startsWith(_cacheKeyPrefix)) {
          await prefs.remove(key);
        }
      }
      
      // Clear memory cache
      _memoryCache.clear();
      
      LogService.log('News cache cleared', category: 'news_cache');
    } catch (e) {
      LogService.log('Error clearing cache: $e', category: 'news_error');
    }
  }
}

// Helper class for request queue
class _QueuedRequest {
  final Future<List<NewsArticle>> Function() requestFunction;
  final Completer<List<NewsArticle>> completer;
  
  _QueuedRequest({
    required this.requestFunction,
    required this.completer,
  });
}

// Helper class for memory cache
class _CachedData {
  final List<NewsArticle> data;
  final DateTime timestamp;
  
  _CachedData({
    required this.data,
    required this.timestamp,
  });
  
  bool isExpired() {
    return DateTime.now().difference(timestamp).inMinutes > NewsService._cacheExpiryMinutes;
  }
}
