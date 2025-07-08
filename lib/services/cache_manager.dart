import 'dart:async';
import 'enhanced_news_service.dart';
import 'log_service.dart';
import 'database_service.dart';

class CacheManager {
  static Timer? _maintenanceTimer;
  static Timer? _preloadTimer;
  static bool _isInitialized = false;
  
  static const Duration _maintenanceInterval = Duration(hours: 6);
  static const Duration _preloadInterval = Duration(minutes: 30);
  
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    await DatabaseService.database;
    _startMaintenanceTimer();
    _startPreloadTimer();
    await EnhancedNewsService.performMaintenance();
    
    _isInitialized = true;
  }
  
  static void _startMaintenanceTimer() {
    _maintenanceTimer?.cancel();
    _maintenanceTimer = Timer.periodic(_maintenanceInterval, (timer) async {
      await EnhancedNewsService.performMaintenance();
    });
  }
  
  static void _startPreloadTimer() {
    _preloadTimer?.cancel();
    _preloadTimer = Timer.periodic(_preloadInterval, (timer) async {
      await _backgroundPreload();
    });
  }
  
  static Future<void> _backgroundPreload() async {
    try {
      await EnhancedNewsService.preloadArticles(
        categoryId: null,
        startPage: 1,
        endPage: 2,
      );
      
      final categories = [67, 73, 72, 71, 69, 1];
      
      for (final categoryId in categories) {
        await EnhancedNewsService.preloadArticles(
          categoryId: categoryId,
          startPage: 1,
          endPage: 1,
        );
      }
    } catch (e) {
      LogService.log('Background preload error: $e', category: 'cache_error');
    }
  }
  
  static Future<void> refreshCache() async {
    await EnhancedNewsService.clearAllCaches();
    await _backgroundPreload();
  }
  
  static Future<Map<String, dynamic>> getCacheStats() async {
    try {
      final db = await DatabaseService.database;
      
      final articleCountResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM articles'
      );
      final articleCount = articleCountResult.first['count'] as int;
      
      final cacheCountResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM cache_metadata'
      );
      final cacheCount = cacheCountResult.first['count'] as int;
      
      final sizeResult = await db.rawQuery(
        'SELECT page_size * page_count as size FROM pragma_page_size(), pragma_page_count()'
      );
      final dbSize = sizeResult.first['size'] as int;
      
      return {
        'articleCount': articleCount,
        'cacheEntries': cacheCount,
        'databaseSize': dbSize,
        'databaseSizeMB': (dbSize / 1024 / 1024).toStringAsFixed(2),
      };
    } catch (e) {
      LogService.log('Error getting cache stats: $e', category: 'cache_error');
      return {
        'articleCount': 0,
        'cacheEntries': 0,
        'databaseSize': 0,
        'databaseSizeMB': '0.00',
      };
    }
  }
  
  static Future<bool> hasOfflineContent() async {
    return await EnhancedNewsService.hasOfflineArticles();
  }
  
  static Future<List<dynamic>> getOfflineArticles({
    int? categoryId,
    int limit = 20,
  }) async {
    return await EnhancedNewsService.getOfflineArticles(
      categoryId: categoryId,
      limit: limit,
    );
  }
  
  static void dispose() {
    _maintenanceTimer?.cancel();
    _preloadTimer?.cancel();
    _maintenanceTimer = null;
    _preloadTimer = null;
    _isInitialized = false;
  }
  
  static Future<void> forceCleanup() async {
    await DatabaseService.cleanExpiredCache();
    await DatabaseService.cleanOldArticles();
  }
}
