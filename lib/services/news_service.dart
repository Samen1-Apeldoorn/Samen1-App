import 'package:html/parser.dart' as htmlparser;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'log_service.dart';

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
  
  static Future<List<NewsArticle>> getNews({
    int page = 1, 
    int perPage = 11,
    int skipFirst = 0,
  }) async {
    try {
      LogService.log(
        'Fetching news from: $_baseUrl?per_page=$perPage&page=$page (skip: $skipFirst)', 
        category: 'news_api'
      );
      
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
        
        // Skip the first n articles if specified
        final processedData = skipFirst > 0 ? data.skip(skipFirst).toList() : data;
        
        return processedData.map((json) => NewsArticle.fromJson(json)).toList();
      } else {
        LogService.log(
          'Failed to load news: ${response.statusCode} - ${response.body}', 
          category: 'news_error'
        );
        return [];
      }
    } catch (e) {
      LogService.log('Error fetching news: $e', category: 'news_error');
      return [];
    }
  }

  static Future<List<NewsArticle>> getNewsByCategory({
    required int categoryId,
    int page = 1, 
    int perPage = 15,
    int skipFirst = 0,
  }) async {
    try {
      final categoryUrl = 'https://api.omroepapeldoorn.nl/api/categorie?per_page=$perPage&page=$page&categorie=$categoryId&_embed=true';
      
      LogService.log(
        'Fetching category news from: $categoryUrl (skip: $skipFirst)', 
        category: 'news_api'
      );
      
      final response = await http.get(Uri.parse(categoryUrl));
      
      LogService.log('API response status: ${response.statusCode}', category: 'news_api');
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        LogService.log('Received ${data.length} category articles from API', category: 'news_api');
        
        if (data.isEmpty) {
          return [];
        }
        
        // Skip the first n articles if specified
        final processedData = skipFirst > 0 ? data.skip(skipFirst).toList() : data;
        
        return processedData.map((json) => NewsArticle.fromJson(json)).toList();
      } else if (response.statusCode == 429) {
        // Handle rate limiting with a small delay and retry
        LogService.log('Rate limited (429), waiting briefly before retry', category: 'news_api');
        await Future.delayed(const Duration(milliseconds: 500));
        
        // Retry the request once
        final retryResponse = await http.get(Uri.parse(categoryUrl));
        if (retryResponse.statusCode == 200) {
          final List<dynamic> data = json.decode(retryResponse.body);
          LogService.log('Retry successful, received ${data.length} category articles', category: 'news_api');
          
          if (data.isEmpty) {
            return [];
          }
          
          final processedData = skipFirst > 0 ? data.skip(skipFirst).toList() : data;
          return processedData.map((json) => NewsArticle.fromJson(json)).toList();
        }
        
        throw '${response.statusCode} - ${response.body}';
      } else {
        throw '${response.statusCode} - ${response.body}';
      }
    } catch (e) {
      LogService.log('Error fetching category news: $e', category: 'news_error');
      throw e;
    }
  }
}
