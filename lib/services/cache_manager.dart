import 'dart:async';
import 'enhanced_news_service.dart';
import 'log_service.dart';
import 'database_service.dart';

class CacheManager {
  static Timer? _maintenanceTimer;
  static Timer? _preloadTimer;
  static bool _isInitialized = false;
  
  // Cache maintenance interval
  static const Duration _maintenanceInterval = Duration(hours: 6);
  
  // Preload interval
  static const Duration _preloadInterval = Duration(minutes: 30);
  
  // Initialize cache manager
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    LogService.log('Initializing cache manager', category: 'cache_manager');
    
    // Initialize database
    await DatabaseService.database;
    
    // Start maintenance timer
    _startMaintenanceTimer();
    
    // Start preload timer
    _startPreloadTimer();
    
    // Perform initial maintenance
    await EnhancedNewsService.performMaintenance();
    
    _isInitialized = true;
    LogService.log('Cache manager initialized', category: 'cache_manager');
  }
  
  // Start maintenance timer
  static void _startMaintenanceTimer() {
    _maintenanceTimer?.cancel();
    _maintenanceTimer = Timer.periodic(_maintenanceInterval, (timer) async {
      LogService.log('Running scheduled maintenance', category: 'cache_manager');
      await EnhancedNewsService.performMaintenance();
    });
  }
  
  // Start preload timer
  static void _startPreloadTimer() {
    _preloadTimer?.cancel();
    _preloadTimer = Timer.periodic(_preloadInterval, (timer) async {
      LogService.log('Running background preload', category: 'cache_manager');
      await _backgroundPreload();
    });
  }
  
  // Background preload strategy
  static Future<void> _backgroundPreload() async {
    try {
      // Preload general news (first 2 pages)
      await EnhancedNewsService.preloadArticles(
        categoryId: null,
        startPage: 1,
        endPage: 2,
      );
      
      // Preload category articles (first page each)
      final categories = [67, 73, 72, 71, 69, 1]; // 112, Cultuur, Evenementen, Gemeente, Politiek, Regio
      
      for (final categoryId in categories) {
        await EnhancedNewsService.preloadArticles(
          categoryId: categoryId,
          startPage: 1,
          endPage: 1,
        );
      }
      
      LogService.log('Background preload completed', category: 'cache_manager');
    } catch (e) {
      LogService.log('Background preload error: $e', category: 'cache_manager');
    }
  }
  
  // Manual cache refresh
  static Future<void> refreshCache() async {
    LogService.log('Manual cache refresh triggered', category: 'cache_manager');
    
    // Clear current caches
    await EnhancedNewsService.clearAllCaches();
    
    // Preload fresh data
    await _backgroundPreload();
    
    LogService.log('Manual cache refresh completed', category: 'cache_manager');
  }
  
  // Get cache statistics
  static Future<Map<String, dynamic>> getCacheStats() async {
    try {
      final db = await DatabaseService.database;
      
      // Get total articles count
      final articleCountResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM articles'
      );
      final articleCount = articleCountResult.first['count'] as int;
      
      // Get cache entries count
      final cacheCountResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM cache_metadata'
      );
      final cacheCount = cacheCountResult.first['count'] as int;
      
      // Get cache size (approximate)
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
      LogService.log('Error getting cache stats: $e', category: 'cache_manager');
      return {
        'articleCount': 0,
        'cacheEntries': 0,
        'databaseSize': 0,
        'databaseSizeMB': '0.00',
      };
    }
  }
  
  // Check if offline content is available
  static Future<bool> hasOfflineContent() async {
    return await EnhancedNewsService.hasOfflineArticles();
  }
  
  // Get offline articles for emergency use
  static Future<List<dynamic>> getOfflineArticles({
    int? categoryId,
    int limit = 20,
  }) async {
    return await EnhancedNewsService.getOfflineArticles(
      categoryId: categoryId,
      limit: limit,
    );
  }
  
  // Cleanup and dispose
  static void dispose() {
    LogService.log('Disposing cache manager', category: 'cache_manager');
    
    _maintenanceTimer?.cancel();
    _preloadTimer?.cancel();
    _maintenanceTimer = null;
    _preloadTimer = null;
    _isInitialized = false;
  }
  
  // Force cleanup old data
  static Future<void> forceCleanup() async {
    LogService.log('Force cleanup initiated', category: 'cache_manager');
    
    await DatabaseService.cleanExpiredCache();
    await DatabaseService.cleanOldArticles();
    
    LogService.log('Force cleanup completed', category: 'cache_manager');
  }
}
