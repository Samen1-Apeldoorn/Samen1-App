import 'package:http/http.dart' as http;
import 'dart:convert';
import 'log_service.dart';
import 'database_service.dart';
import '../Pages/News/news_service.dart';
import 'dart:async';

// Enhanced NewsService with persistent caching
class EnhancedNewsService {
  static const String _baseUrl = 'https://api.omroepapeldoorn.nl/api/nieuws';
  static const String _categoryBaseUrl = 'https://api.omroepapeldoorn.nl/api/categorie';

  // In-memory cache for quick access (L1 cache)
  static final Map<String, List<NewsArticle>> _memoryCache = {};
  static final Map<String, DateTime> _memoryCacheTimestamps = {};
  static const Duration _memoryCacheDuration = Duration(minutes: 5);
  static const Duration _persistentCacheDuration = Duration(hours: 2);

  // Helper to generate cache key
  static String _getCacheKey({int? categoryId, required int page}) {
    return "cat_${categoryId ?? 'all'}_page_$page";
  }

  // Check if memory cache is valid
  static bool _isMemoryCacheValid(String key) {
    final timestamp = _memoryCacheTimestamps[key];
    if (timestamp == null) return false;
    return DateTime.now().difference(timestamp) < _memoryCacheDuration;
  }

  // Enhanced news fetching with multi-level caching
  static Future<List<NewsArticle>> getNews({
    int page = 1,
    int perPage = 15,
    bool forceRefresh = false,
  }) async {
    final cacheKey = _getCacheKey(page: page);
    
    // L1 Cache: Check memory cache first
    if (!forceRefresh && _isMemoryCacheValid(cacheKey)) {
      return _memoryCache[cacheKey]!;
    }

    // L2 Cache: Check persistent cache
    if (!forceRefresh) {
      final cachedArticles = await DatabaseService.getCachedArticles(cacheKey);
      if (cachedArticles != null) {
        // Update memory cache
        _memoryCache[cacheKey] = cachedArticles;
        _memoryCacheTimestamps[cacheKey] = DateTime.now();
        return cachedArticles;
      }
    }

    // L3: Fetch from API
    return await _fetchFromAPI(
      url: '$_baseUrl?per_page=$perPage&page=$page&_embed=true',
      cacheKey: cacheKey,
      categoryId: null,
      page: page,
    );
  }

  // Enhanced category news fetching
  static Future<List<NewsArticle>> getNewsByCategory({
    required int categoryId,
    int page = 1,
    int perPage = 15,
    bool forceRefresh = false,
  }) async {
    final cacheKey = _getCacheKey(categoryId: categoryId, page: page);
    
    // L1 Cache: Check memory cache first
    if (!forceRefresh && _isMemoryCacheValid(cacheKey)) {
      return _memoryCache[cacheKey]!;
    }

    // L2 Cache: Check persistent cache
    if (!forceRefresh) {
      final cachedArticles = await DatabaseService.getCachedArticles(cacheKey);
      if (cachedArticles != null) {
        // Update memory cache
        _memoryCache[cacheKey] = cachedArticles;
        _memoryCacheTimestamps[cacheKey] = DateTime.now();
        return cachedArticles;
      }
    }

    // L3: Fetch from API
    return await _fetchFromAPI(
      url: '$_categoryBaseUrl?per_page=$perPage&page=$page&categorie=$categoryId&_embed=true',
      cacheKey: cacheKey,
      categoryId: categoryId,
      page: page,
    );
  }

  // Centralized API fetching with caching
  static Future<List<NewsArticle>> _fetchFromAPI({
    required String url,
    required String cacheKey,
    int? categoryId,
    required int page,
  }) async {
    try {
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          LogService.log('API request timeout', category: 'api_error');
          throw TimeoutException('Request timeout', const Duration(seconds: 30));
        },
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final articles = data.map((json) => NewsArticle.fromJson(json)).toList();
        
        // Cache the results
        await _cacheArticles(cacheKey, articles, categoryId, page);
        
        return articles;
      } else if (response.statusCode == 429) {
        // Rate limiting handling
        await Future.delayed(const Duration(milliseconds: 500));
        
        final retryResponse = await http.get(Uri.parse(url)).timeout(
          const Duration(seconds: 30),
        );
        if (retryResponse.statusCode == 200) {
          final List<dynamic> data = json.decode(retryResponse.body);
          final articles = data.map((json) => NewsArticle.fromJson(json)).toList();
          
          await _cacheArticles(cacheKey, articles, categoryId, page);
          return articles;
        }
      } 
      
      // If API fails, try to return stale cache
      final staleArticles = await DatabaseService.getCachedArticles(cacheKey);
      if (staleArticles != null) {
        return staleArticles;
      }
      
      return [];
    } on TimeoutException {
      // Return stale cache on timeout
      final staleArticles = await DatabaseService.getCachedArticles(cacheKey);
      return staleArticles ?? [];
    } catch (e) {
      LogService.log('API error: $e', category: 'api_error');
      
      // Return stale cache on error
      final staleArticles = await DatabaseService.getCachedArticles(cacheKey);
      return staleArticles ?? [];
    }
  }

  // Cache articles in both memory and persistent storage
  static Future<void> _cacheArticles(
    String cacheKey,
    List<NewsArticle> articles,
    int? categoryId,
    int page,
  ) async {
    final now = DateTime.now();
    
    // Update memory cache
    _memoryCache[cacheKey] = articles;
    _memoryCacheTimestamps[cacheKey] = now;
    
    // Update persistent cache
    await DatabaseService.saveArticles(articles);
    await DatabaseService.saveCacheMetadata(
      cacheKey,
      categoryId,
      page,
      articles.map((a) => a.id).toList(),
      now,
      _persistentCacheDuration,
    );
  }

  // Background cache maintenance
  static Future<void> performMaintenance() async {
    try {
      // Clean expired cache entries
      await DatabaseService.cleanExpiredCache();
      
      // Clean old articles
      await DatabaseService.cleanOldArticles();
      
      // Clear expired memory cache
      final now = DateTime.now();
      final expiredKeys = _memoryCacheTimestamps.entries
          .where((entry) => now.difference(entry.value) > _memoryCacheDuration)
          .map((entry) => entry.key)
          .toList();
      
      for (final key in expiredKeys) {
        _memoryCache.remove(key);
        _memoryCacheTimestamps.remove(key);
      }
    } catch (e) {
      LogService.log('Cache maintenance error: $e', category: 'cache_error');
    }
  }

  // Preload articles for better performance
  static Future<void> preloadArticles({
    int? categoryId,
    int startPage = 1,
    int endPage = 3,
  }) async {
    final futures = <Future<List<NewsArticle>>>[];
    
    for (int page = startPage; page <= endPage; page++) {
      if (categoryId == null) {
        futures.add(getNews(page: page));
      } else {
        futures.add(getNewsByCategory(categoryId: categoryId, page: page));
      }
    }
    
    await Future.wait(futures);
  }

  // Get offline articles
  static Future<List<NewsArticle>> getOfflineArticles({
    int? categoryId,
    int limit = 50,
  }) async {
    return await DatabaseService.getArticles(
      categoryId: categoryId,
      limit: limit,
    );
  }

  // Check if articles are available offline
  static Future<bool> hasOfflineArticles({int? categoryId}) async {
    final articles = await DatabaseService.getArticles(
      categoryId: categoryId,
      limit: 1,
    );
    return articles.isNotEmpty;
  }

  // Clear all caches
  static Future<void> clearAllCaches() async {
    // Clear memory cache
    _memoryCache.clear();
    _memoryCacheTimestamps.clear();
    
    // Clear persistent cache
    await DatabaseService.cleanExpiredCache();
  }
}
