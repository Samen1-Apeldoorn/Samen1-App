import 'package:flutter/material.dart';
import 'package:html/parser.dart' as htmlparser;
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/log_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../styles/news_styles.dart';
import 'package:flutter_html/flutter_html.dart';

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

  static String _extractImageUrl(Map<String, dynamic> media) {
    final sizes = media['media_details']?['sizes'];
    if (sizes == null) return media['source_url'] ?? '';
    
    return sizes['large']?['source_url'] ??
           sizes['medium_large']?['source_url'] ??
           sizes['medium']?['source_url'] ??
           media['source_url'] ?? '';
  }

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
  
  static Future<List<NewsArticle>> getNews({int page = 1, int perPage = 11}) async {
    try {
      LogService.log('Fetching news from: $_baseUrl?per_page=$perPage&page=$page', category: 'news_api');
      
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
        
        // Check first article for debugging
        if (data.isNotEmpty) {
          LogService.log('First article ID: ${data.first['id']}', category: 'news_api');
        }
        
        return data.map((json) => NewsArticle.fromJson(json)).toList();
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
}

class NewsArticleScreen extends StatelessWidget {
  final NewsArticle article;
  
  const NewsArticleScreen({super.key, required this.article});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: NewsStyles.backButtonContainer,
            child: const Icon(Icons.arrow_back),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero image with only title overlay
            if (article.imageUrl.isNotEmpty)
              Stack(
                children: [
                  CachedNetworkImage(
                    imageUrl: article.imageUrl,
                    width: double.infinity,
                    height: NewsStyles.articleImageHeight,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      height: NewsStyles.articleImageHeight,
                      color: NewsStyles.placeholderColor,
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: NewsStyles.articleImageHeight,
                      color: NewsStyles.placeholderColor,
                      child: const Icon(Icons.error, size: 40),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: NewsStyles.defaultPadding,
                      decoration: NewsStyles.gradientOverlay,
                      child: Text(
                        article.title,
                        style: NewsStyles.titleStyle,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            
            // Category and date moved below the image
            if (article.imageUrl.isNotEmpty)
              Padding(
                padding: NewsStyles.defaultPadding,
                child: Row(
                  children: [
                    Text(
                      article.category,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      "•",
                      style: TextStyle(
                        color: Colors.black45,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatDate(article.date),
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            
            // Content
            Padding(
              padding: NewsStyles.defaultPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (article.imageUrl.isEmpty) ...[
                    Text(
                      article.title,
                      style: NewsStyles.articleTitleStyle,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          article.category,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          "•",
                          style: TextStyle(
                            color: Colors.black45,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatDate(article.date),
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                  // The HTML content renderer
                  _buildRichHtmlContent(article.content, context),
                  const SizedBox(height: 20),
                  if (article.imageCaption != null && article.imageCaption!.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: NewsStyles.imageCaptionContainer,
                      child: Row(
                        children: [
                          const Icon(Icons.photo_camera, size: 16, color: Colors.grey),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              article.imageCaption!,
                              style: NewsStyles.imageCaptionStyle,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NewsPage extends StatefulWidget {
  const NewsPage({super.key});

  @override
  State<NewsPage> createState() => _NewsPageState();
}

class _NewsPageState extends State<NewsPage> {
  final List<NewsArticle> _articles = [];
  List<NewsArticle> _preloadedArticles = [];
  bool _isLoading = false;
  bool _isPreloading = false;
  bool _hasError = false;
  bool _hasMoreArticles = true;
  int _currentPage = 1;
  final ScrollController _scrollController = ScrollController();
  // Add debounce timer to prevent multiple rapid requests
  DateTime _lastLoadTime = DateTime.now();
  bool _loadingTriggered = false;

  @override
  void initState() {
    super.initState();
    _loadNews();
    _scrollController.addListener(_scrollListener);
    LogService.log('News page opened', category: 'news');
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  // Improved scroll listener with debouncing
  void _scrollListener() {
    // Start preloading earlier - when we're 70% through the content
    final scrollThreshold = 0.7 * _scrollController.position.maxScrollExtent;
    
    // Check if we should preload next page (when 70% through the list)
    if (_scrollController.position.pixels >= scrollThreshold && 
        !_isPreloading && 
        !_loadingTriggered && 
        _hasMoreArticles && 
        _preloadedArticles.isEmpty) {
      _preloadNextPage();
    }
    
    // Load more when near the bottom (about 2-3 articles from bottom)
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 800) {
      // Debounce - prevent multiple loads within 1 second
      if (!_isLoading && 
          !_loadingTriggered && 
          _hasMoreArticles && 
          DateTime.now().difference(_lastLoadTime).inMilliseconds > 1000) {
        
        _loadingTriggered = true;
        LogService.log('Nearing end of list, loading more articles', category: 'news');
        
        // Use Future.delayed to slightly defer loading to prevent janky scrolling
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) _loadNews();
        });
      }
    }
  }

  // Improved preload method with better error handling
  Future<void> _preloadNextPage() async {
    if (_isPreloading || !_hasMoreArticles) return;
    
    _isPreloading = true;
    LogService.log('Preloading news page ${_currentPage + 1}', category: 'news');
    
    try {
      // Use 11 articles per page
      final articles = await NewsService.getNews(page: _currentPage + 1, perPage: 11);
      
      if (mounted) {
        if (articles.isEmpty) {
          _hasMoreArticles = false;
        } else {
          _preloadedArticles = articles;
          LogService.log('Successfully preloaded ${articles.length} articles for page ${_currentPage + 1}', 
              category: 'news');
        }
      }
    } catch (e) {
      LogService.log('Failed to preload news page ${_currentPage + 1}: $e', category: 'news_error');
      // Don't set _hasMoreArticles to false on error - we'll retry later
    } finally {
      if (mounted) {
        _isPreloading = false;
      }
    }
  }

  // Improved loading with better state management
  Future<void> _loadNews() async {
    if (_isLoading || !_hasMoreArticles) return;
    
    _lastLoadTime = DateTime.now();
    _loadingTriggered = false;
    
    setState(() {
      _isLoading = true;
    });

    try {
      List<NewsArticle> articles;
      
      // Use preloaded articles if available
      if (_preloadedArticles.isNotEmpty) {
        LogService.log('Using preloaded articles for page $_currentPage', category: 'news');
        articles = _preloadedArticles;
        _preloadedArticles = [];
      } else {
        // Otherwise load from API (11 articles per page)
        LogService.log('Loading page $_currentPage directly', category: 'news');
        articles = await NewsService.getNews(page: _currentPage, perPage: 11);
      }
      
      if (articles.isEmpty && _currentPage == 1) {
        LogService.log('No articles found on first page', category: 'news_warning');
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
        return;
      } else if (articles.isEmpty) {
        setState(() {
          _isLoading = false;
          _hasMoreArticles = false;
        });
        return;
      }
      
      setState(() {
        _articles.addAll(articles);
        _isLoading = false;
        _currentPage++;
      });

      // Start preloading next page immediately after current page is loaded
      if (_hasMoreArticles && _preloadedArticles.isEmpty) {
        _preloadNextPage();
      }
      
      LogService.log('Loaded ${articles.length} articles. Total: ${_articles.length}', category: 'news');
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = _articles.isEmpty;
      });
      LogService.log('Failed to load news: $e', category: 'news_error');
    }
  }

  Future<void> _refreshNews() async {
    setState(() {
      _articles.clear();
      _preloadedArticles.clear();
      _currentPage = 1;
      _hasMoreArticles = true;
      _hasError = false;
      _loadingTriggered = false;
    });
    await _loadNews();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nieuws'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _refreshNews,
        child: _isLoading && _articles.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : _hasError && _articles.isEmpty
                ? _buildErrorView()
                : _buildNewsLayout(),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          const Text(
            'Er is iets misgegaan bij het laden van het nieuws.\nMogelijk is de API tijdelijk niet beschikbaar.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _refreshNews,
            child: const Text('Opnieuw proberen'),
          ),
        ],
      ),
    );
  }

  Widget _buildNewsLayout() {
    if (_articles.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.article_outlined, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Geen nieuwsartikelen gevonden.\nProbeer het later nog eens.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // New implementation using ListView + GridView for better infinite scrolling
    return ListView(
      controller: _scrollController,
      children: [
        // Featured article - no padding, full width
        _buildFeaturedArticle(_articles.first),
        
        // Add spacing between featured article and grid
        const SizedBox(height: 16),
        
        // Remaining articles in grid
        if (_articles.length > 1)
          Padding(
            padding: NewsStyles.horizontalPadding,
            child: GridView.builder(
              shrinkWrap: true, // Important for ListView > GridView nesting
              physics: const NeverScrollableScrollPhysics(), // GridView shouldn't scroll
              gridDelegate: NewsStyles.gridDelegate,
              itemCount: _articles.length - 1,
              itemBuilder: (context, index) {
                // Add 1 to skip featured article
                return _buildGridArticleItem(_articles[index + 1]);
              },
            ),
          ),
        
        // Loading indicator or end of list message
        Container(
          padding: NewsStyles.verticalPadding,
          alignment: Alignment.center,
          child: _isLoading
              ? const CircularProgressIndicator()
              : !_hasMoreArticles && _articles.isNotEmpty
                  ? Text(
                      'Alle artikelen zijn geladen',
                      style: NewsStyles.noMoreArticlesStyle,
                    )
                  : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildFeaturedArticle(NewsArticle article) {
    return GestureDetector(
      onTap: () => _openArticle(article),
      child: Container(
        // Remove decoration to eliminate rounded corners for full-width
        clipBehavior: Clip.none,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (article.imageUrl.isNotEmpty)
              Stack(
                children: [
                  CachedNetworkImage(
                    imageUrl: article.imageUrl,
                    height: NewsStyles.featuredImageHeight + 40, // Slightly increase height
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      height: NewsStyles.featuredImageHeight + 40,
                      color: NewsStyles.placeholderColor,
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: NewsStyles.featuredImageHeight + 40,
                      color: NewsStyles.placeholderColor,
                      child: const Icon(Icons.error, size: 40),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: NewsStyles.defaultPadding,
                      decoration: NewsStyles.gradientOverlay,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            article.category,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            article.title,
                            style: NewsStyles.titleStyle,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            if (article.imageUrl.isEmpty)
              Padding(
                padding: NewsStyles.defaultPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      article.category,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      article.title,
                      style: NewsStyles.articleTitleStyle,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(article.date),
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridArticleItem(NewsArticle article) {
    return GestureDetector(
      onTap: () => _openArticle(article),
      child: Container(
        decoration: NewsStyles.gridItemDecoration,
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (article.imageUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: article.imageUrl,
                height: NewsStyles.gridImageHeight,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  height: NewsStyles.gridImageHeight,
                  color: NewsStyles.placeholderColor,
                  child: const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  height: NewsStyles.gridImageHeight,
                  color: NewsStyles.placeholderColor,
                  child: const Icon(Icons.error, size: 30),
                ),
              ),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.only(left: 8, right: 8, top: 8, bottom: 0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (article.imageUrl.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          article.category,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    Text(
                      article.title,
                      style: NewsStyles.gridTitleStyle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      _getPlainText(article.excerpt),
                      style: NewsStyles.gridExcerptStyle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Text(
                            article.category,
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            "•",
                            style: TextStyle(
                              color: Colors.black45,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _formatDate(article.date),
                            style: const TextStyle(
                              color: Colors.black45,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openArticle(NewsArticle article) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NewsArticleScreen(article: article),
      ),
    );
    LogService.log('Opening article: ${article.id}', category: 'news');
  }

  String _getPlainText(String htmlString) {
    final document = htmlparser.parse(htmlString);
    return document.body?.text ?? '';
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('d MMMM yyyy').format(date);
    } catch (e) {
      return dateString;
    }
  }
}

// Utility function for date formatting - add outside the class to avoid duplication
String _formatDate(String dateString) {
  try {
    final date = DateTime.parse(dateString);
    return DateFormat('d MMMM yyyy').format(date);
  } catch (e) {
    return dateString;
  }
}

// Fix the HTML renderer to make images visible at the correct width
Widget _buildRichHtmlContent(String htmlContent, BuildContext context) {
  return Html(
    data: htmlContent,
    style: {
      "body": Style(
        fontSize: FontSize(16),
        fontWeight: FontWeight.normal,
        color: Colors.black87,
        lineHeight: LineHeight(1.6),
      ),
      "p": Style(
        margin: Margins.only(bottom: 16),
      ),
      "strong": Style(
        fontWeight: FontWeight.bold,
      ),
      "img": Style(
        padding: HtmlPaddings.zero,
        margin: Margins.only(top: 8.0, bottom: 8.0),
        // Make sure images are displayed at 100% of container width
        display: Display.block,
      ),
      "figure": Style(
        margin: Margins.symmetric(vertical: 12),
        display: Display.block,
      ),
      "figcaption": Style(
        padding: HtmlPaddings.all(8),
        fontSize: FontSize(14),
        color: Colors.grey,
        textAlign: TextAlign.center,
        backgroundColor: Colors.grey[100],
      ),
    },
    // Remove the onImageTap parameter that's causing an error
    onLinkTap: (url, _, __) {
      if (url != null) {
        // Handle link taps if needed
      }
    },
  );
}
