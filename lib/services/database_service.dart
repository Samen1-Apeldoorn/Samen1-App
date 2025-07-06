import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';
import '../Pages/News/news_service.dart';
import 'log_service.dart';

class DatabaseService {
  static Database? _database;
  static const String _dbName = 'samen1_news.db';
  static const int _dbVersion = 1;

  // Table names
  static const String _articlesTable = 'articles';
  static const String _cacheMetadataTable = 'cache_metadata';

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), _dbName);
    LogService.log('Initializing database at: $path', category: 'database');
    
    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _createDatabase,
    );
  }

  static Future<void> _createDatabase(Database db, int version) async {
    LogService.log('Creating database tables', category: 'database');
    
    // Articles table
    await db.execute('''
      CREATE TABLE $_articlesTable (
        id INTEGER PRIMARY KEY,
        date TEXT NOT NULL,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        excerpt TEXT NOT NULL,
        link TEXT NOT NULL,
        imageUrl TEXT NOT NULL,
        imageCaption TEXT,
        category TEXT NOT NULL,
        author TEXT NOT NULL,
        mediaDetails TEXT,
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL
      )
    ''');

    // Cache metadata table
    await db.execute('''
      CREATE TABLE $_cacheMetadataTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cacheKey TEXT UNIQUE NOT NULL,
        categoryId INTEGER,
        page INTEGER NOT NULL,
        articleIds TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        expiresAt INTEGER NOT NULL
      )
    ''');

    // Create indices for better query performance
    await db.execute('CREATE INDEX idx_articles_category ON $_articlesTable(category)');
    await db.execute('CREATE INDEX idx_articles_date ON $_articlesTable(date DESC)');
    await db.execute('CREATE INDEX idx_cache_key ON $_cacheMetadataTable(cacheKey)');
  }

  // Save articles to database
  static Future<void> saveArticles(List<NewsArticle> articles) async {
    final db = await database;
    final batch = db.batch();
    final now = DateTime.now().millisecondsSinceEpoch;

    for (final article in articles) {
      batch.insert(
        _articlesTable,
        {
          'id': article.id,
          'date': article.date,
          'title': article.title,
          'content': article.content,
          'excerpt': article.excerpt,
          'link': article.link,
          'imageUrl': article.imageUrl,
          'imageCaption': article.imageCaption,
          'category': article.category,
          'author': article.author,
          'mediaDetails': article.mediaDetails != null ? 
              json.encode(article.mediaDetails!) : null,
          'createdAt': now,
          'updatedAt': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
    LogService.log('Saved ${articles.length} articles to database', category: 'database');
  }

  // Get articles from database
  static Future<List<NewsArticle>> getArticles({
    int? categoryId,
    int limit = 50,
    int offset = 0,
  }) async {
    final db = await database;
    
    final List<Map<String, dynamic>> maps = await db.query(
      _articlesTable,
      orderBy: 'date DESC',
      limit: limit,
      offset: offset,
      where: categoryId != null ? 'category = ?' : null,
      whereArgs: categoryId != null ? [_getCategoryName(categoryId)] : null,
    );

    return maps.map((map) => _articleFromMap(map)).toList();
  }

  // Save cache metadata
  static Future<void> saveCacheMetadata(
    String cacheKey,
    int? categoryId,
    int page,
    List<int> articleIds,
    DateTime timestamp,
    Duration cacheDuration,
  ) async {
    final db = await database;
    final expiresAt = timestamp.add(cacheDuration).millisecondsSinceEpoch;
    
    await db.insert(
      _cacheMetadataTable,
      {
        'cacheKey': cacheKey,
        'categoryId': categoryId,
        'page': page,
        'articleIds': articleIds.join(','),
        'timestamp': timestamp.millisecondsSinceEpoch,
        'expiresAt': expiresAt,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Check if cache is valid
  static Future<bool> isCacheValid(String cacheKey) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    
    final result = await db.query(
      _cacheMetadataTable,
      where: 'cacheKey = ? AND expiresAt > ?',
      whereArgs: [cacheKey, now],
    );
    
    return result.isNotEmpty;
  }

  // Get cached articles
  static Future<List<NewsArticle>?> getCachedArticles(String cacheKey) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    
    final cacheResult = await db.query(
      _cacheMetadataTable,
      where: 'cacheKey = ? AND expiresAt > ?',
      whereArgs: [cacheKey, now],
    );
    
    if (cacheResult.isEmpty) return null;
    
    final articleIds = cacheResult.first['articleIds'].toString()
        .split(',')
        .map((id) => int.parse(id))
        .toList();
    
    final articles = <NewsArticle>[];
    for (final id in articleIds) {
      final articleResult = await db.query(
        _articlesTable,
        where: 'id = ?',
        whereArgs: [id],
      );
      
      if (articleResult.isNotEmpty) {
        articles.add(_articleFromMap(articleResult.first));
      }
    }
    
    return articles;
  }

  // Clean expired cache entries
  static Future<void> cleanExpiredCache() async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    
    await db.delete(
      _cacheMetadataTable,
      where: 'expiresAt < ?',
      whereArgs: [now],
    );
    
    LogService.log('Cleaned expired cache entries', category: 'database');
  }

  // Clean old articles (keep only last 1000 articles)
  static Future<void> cleanOldArticles() async {
    final db = await database;
    
    // Get count of articles
    final countResult = await db.rawQuery('SELECT COUNT(*) as count FROM $_articlesTable');
    final count = countResult.first['count'] as int;
    
    if (count > 1000) {
      // Delete oldest articles beyond 1000
      await db.rawDelete('''
        DELETE FROM $_articlesTable 
        WHERE id NOT IN (
          SELECT id FROM $_articlesTable 
          ORDER BY date DESC 
          LIMIT 1000
        )
      ''');
      
      LogService.log('Cleaned old articles, kept latest 1000', category: 'database');
    }
  }

  // Helper method to convert database map to NewsArticle
  static NewsArticle _articleFromMap(Map<String, dynamic> map) {
    return NewsArticle(
      id: map['id'],
      date: map['date'],
      title: map['title'],
      content: map['content'],
      excerpt: map['excerpt'],
      link: map['link'],
      imageUrl: map['imageUrl'],
      imageCaption: map['imageCaption'],
      category: map['category'],
      author: map['author'],
      mediaDetails: map['mediaDetails'] != null ? 
          json.decode(map['mediaDetails']) : null,
    );
  }

  // Helper method to get category name from ID
  static String _getCategoryName(int categoryId) {
    const categoryMap = {
      67: '112',
      73: 'Cultuur',
      72: 'Evenementen',
      71: 'Gemeente',
      69: 'Politiek',
      1: 'Regio',
    };
    return categoryMap[categoryId] ?? 'Regio';
  }
}
