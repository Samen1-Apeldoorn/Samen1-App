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
      LogService.log('Returning from memory cache for page $page', category: 'enhanced_cache');
      return _memoryCache[cacheKey]!;
    }

    // L2 Cache: Check persistent cache
    if (!forceRefresh) {
      final cachedArticles = await DatabaseService.getCachedArticles(cacheKey);
      if (cachedArticles != null) {
        LogService.log('Returning from persistent cache for page $page', category: 'enhanced_cache');
        
        // Update memory cache
        _memoryCache[cacheKey] = cachedArticles;
        _memoryCacheTimestamps[cacheKey] = DateTime.now();
        
        return cachedArticles;
      }
    }

    // L3: Fetch from API
    LogService.log('Fetching from API for page $page', category: 'enhanced_cache');
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
      LogService.log('Returning from memory cache for category $categoryId, page $page', category: 'enhanced_cache');
      return _memoryCache[cacheKey]!;
    }

    // L2 Cache: Check persistent cache
    if (!forceRefresh) {
      final cachedArticles = await DatabaseService.getCachedArticles(cacheKey);
      if (cachedArticles != null) {
        LogService.log('Returning from persistent cache for category $categoryId, page $page', category: 'enhanced_cache');
        
        // Update memory cache
        _memoryCache[cacheKey] = cachedArticles;
        _memoryCacheTimestamps[cacheKey] = DateTime.now();
        
        return cachedArticles;
      }
    }

    // L3: Fetch from API
    LogService.log('Fetching from API for category $categoryId, page $page', category: 'enhanced_cache');
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
          LogService.log('API request timeout for $url', category: 'enhanced_cache');
          throw TimeoutException('Request timeout', const Duration(seconds: 30));
        },
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final articles = data.map((json) => NewsArticle.fromJson(json)).toList();
        
        // Cache the results
        await _cacheArticles(cacheKey, articles, categoryId, page);
        
        LogService.log('Successfully fetched ${articles.length} articles from API', category: 'enhanced_cache');
        return articles;
      } else if (response.statusCode == 429) {
        // Rate limiting handling
        LogService.log('Rate limited (429), retrying after delay', category: 'enhanced_cache');
        await Future.delayed(const Duration(milliseconds: 500));
        
        final retryResponse = await http.get(Uri.parse(url)).timeout(
          const Duration(seconds: 30),
        );
        if (retryResponse.statusCode == 200) {
          final List<dynamic> data = json.decode(retryResponse.body);
          final articles = data.map((json) => NewsArticle.fromJson(json)).toList();
          
          await _cacheArticles(cacheKey, articles, categoryId, page);
          LogService.log('Retry successful after rate limit', category: 'enhanced_cache');
          return articles;
        }
      } else {
        LogService.log('API returned status ${response.statusCode}: ${response.body}', category: 'enhanced_cache');
      }
      
      // If API fails, try to return stale cache
      final staleArticles = await DatabaseService.getCachedArticles(cacheKey);
      if (staleArticles != null) {
        LogService.log('API failed (${response.statusCode}), returning stale cache with ${staleArticles.length} articles', category: 'enhanced_cache');
        return staleArticles;
      }
      
      return [];
    } on TimeoutException catch (e) {
      LogService.log('API timeout: $e', category: 'enhanced_cache');
      
      // Return stale cache on timeout
      final staleArticles = await DatabaseService.getCachedArticles(cacheKey);
      if (staleArticles != null) {
        LogService.log('Timeout occurred, returning stale cache with ${staleArticles.length} articles', category: 'enhanced_cache');
        return staleArticles;
      }
      
      return [];
    } catch (e) {
      LogService.log('API error: $e', category: 'enhanced_cache');
      
      // Return stale cache on error
      final staleArticles = await DatabaseService.getCachedArticles(cacheKey);
      if (staleArticles != null) {
        LogService.log('Error occurred, returning stale cache with ${staleArticles.length} articles', category: 'enhanced_cache');
        return staleArticles;
      }
      
      return [];
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
    
    LogService.log('Cached ${articles.length} articles for $cacheKey', category: 'enhanced_cache');
  }

  // Background cache maintenance
  static Future<void> performMaintenance() async {
    try {
      LogService.log('Starting cache maintenance', category: 'enhanced_cache');
      
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
      
      LogService.log('Cache maintenance completed', category: 'enhanced_cache');
    } catch (e) {
      LogService.log('Cache maintenance error: $e', category: 'enhanced_cache');
    }
  }

  // Preload articles for better performance
  static Future<void> preloadArticles({
    int? categoryId,
    int startPage = 1,
    int endPage = 3,
  }) async {
    LogService.log('Preloading articles for category $categoryId, pages $startPage-$endPage', category: 'enhanced_cache');
    
    final futures = <Future<List<NewsArticle>>>[];
    
    for (int page = startPage; page <= endPage; page++) {
      if (categoryId == null) {
        futures.add(getNews(page: page));
      } else {
        futures.add(getNewsByCategory(categoryId: categoryId, page: page));
      }
    }
    
    await Future.wait(futures);
    LogService.log('Preloading completed', category: 'enhanced_cache');
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
    LogService.log('Clearing all caches', category: 'enhanced_cache');
    
    // Clear memory cache
    _memoryCache.clear();
    _memoryCacheTimestamps.clear();
    
    // Clear persistent cache
    await DatabaseService.cleanExpiredCache();
    
    LogService.log('All caches cleared', category: 'enhanced_cache');
  }
}
