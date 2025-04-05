import 'package:flutter/material.dart';
import 'package:html/parser.dart' as htmlparser;
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/log_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../styles/news_styles.dart';

class NewsArticle {
  final int id;
  final String date;
  final String title;
  final String content;
  final String excerpt;
  final String link;
  final String imageUrl;
  final String? imageCaption;

  NewsArticle({
    required this.id,
    required this.date,
    required this.title,
    required this.content,
    required this.excerpt,
    required this.link,
    required this.imageUrl,
    this.imageCaption,
  });

  static String _extractImageUrl(Map<String, dynamic> media) {
    final sizes = media['media_details']?['sizes'];
    if (sizes == null) return media['source_url'] ?? '';
    
    return sizes['large']?['source_url'] ??
           sizes['medium_large']?['source_url'] ??
           sizes['medium']?['source_url'] ??
           media['source_url'] ?? '';
  }

  factory NewsArticle.fromJson(Map<String, dynamic> json) {
    final media = json['_embedded']?['wp:featuredmedia']?.firstOrNull;
    
    return NewsArticle(
      id: json['id'],
      date: json['date'],
      title: json['title']?['rendered'] ?? '',
      content: json['content']?['rendered'] ?? '',
      excerpt: json['excerpt']?['rendered'] ?? '',
      link: json['link'] ?? '',
      imageUrl: media != null ? _extractImageUrl(media) : '',
      imageCaption: media?['caption']?['rendered'] != null
          ? htmlparser.parse(media!['caption']['rendered']).body?.text
          : null,
    );
  }
}

class NewsService {
  static const String _baseUrl = 'https://api.omroepapeldoorn.nl/api/nieuws';
  
  static Future<List<NewsArticle>> getNews({int page = 1, int perPage = 10}) async {
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
  
  const NewsArticleScreen({Key? key, required this.article}) : super(key: key);

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
            // Hero image with title overlay
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            article.title,
                            style: NewsStyles.titleStyle,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _formatDate(article.date),
                            style: NewsStyles.dateStyle,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
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
                    Text(
                      _formatDate(article.date),
                      style: NewsStyles.articleDateStyle,
                    ),
                    const SizedBox(height: 16),
                  ],
                  _buildHtmlContent(article.content),
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
  const NewsPage({Key? key}) : super(key: key);

  @override
  State<NewsPage> createState() => _NewsPageState();
}

class _NewsPageState extends State<NewsPage> {
  final List<NewsArticle> _articles = [];
  List<NewsArticle> _preloadedArticles = []; // New: store preloaded articles
  bool _isLoading = false;
  bool _isPreloading = false; // New: track preloading state
  bool _hasError = false;
  bool _hasMoreArticles = true; // New flag to track if more articles are available
  int _currentPage = 1;
  final ScrollController _scrollController = ScrollController(); // New scroll controller

  @override
  void initState() {
    super.initState();
    _loadNews();
    // Add scroll listener to detect when user reaches the bottom
    _scrollController.addListener(_scrollListener);
    LogService.log('News page opened', category: 'news');
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  // Scroll listener to detect when user is near the bottom
  void _scrollListener() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 500) {
      // Load more when we're 500 pixels from the bottom
      if (!_isLoading && _hasMoreArticles) {
        LogService.log('Nearing end of list, loading more articles', category: 'news');
        _loadNews();
      }
    }
  }

  // New: method to preload next page
  Future<void> _preloadNextPage() async {
    if (_isPreloading || !_hasMoreArticles) return;
    
    _isPreloading = true;
    try {
      LogService.log('Preloading news page ${_currentPage + 1}', category: 'news');
      final articles = await NewsService.getNews(page: _currentPage + 1, perPage: 10);
      
      if (articles.isEmpty) {
        _hasMoreArticles = false;
      } else {
        _preloadedArticles = articles;
      }
    } catch (e) {
      LogService.log('Failed to preload news: $e', category: 'news_error');
    } finally {
      _isPreloading = false;
    }
  }

  Future<void> _loadNews() async {
    if (_isLoading || !_hasMoreArticles) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      List<NewsArticle> articles;
      if (_preloadedArticles.isNotEmpty) {
        // Use preloaded articles if available
        articles = _preloadedArticles;
        _preloadedArticles = [];
      } else {
        // Otherwise load from API
        articles = await NewsService.getNews(page: _currentPage, perPage: 10);
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

      // Start preloading next page
      _preloadNextPage();
      
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
      _preloadedArticles.clear(); // Clear preloaded articles
      _currentPage = 1;
      _hasMoreArticles = true; // Reset this flag on refresh
      _hasError = false;
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
        // Featured article
        Padding(
          padding: NewsStyles.defaultPadding,
          child: _buildFeaturedArticle(_articles.first),
        ),
        
        // Divider between featured and grid articles
        Padding(
          padding: NewsStyles.horizontalPadding,
          child: Divider(color: Colors.grey[300], height: 32),
        ),
        
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
        decoration: NewsStyles.cardDecoration,
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (article.imageUrl.isNotEmpty)
              Stack(
                children: [
                  CachedNetworkImage(
                    imageUrl: article.imageUrl,
                    height: NewsStyles.featuredImageHeight,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      height: NewsStyles.featuredImageHeight,
                      color: NewsStyles.placeholderColor,
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: NewsStyles.featuredImageHeight,
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
                            article.title,
                            style: NewsStyles.titleStyle,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _formatDate(article.date),
                            style: NewsStyles.dateStyle,
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
                      article.title,
                      style: NewsStyles.articleTitleStyle,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatDate(article.date),
                      style: NewsStyles.articleDateStyle,
                    ),
                  ],
                ),
              ),
            Padding(
              padding: NewsStyles.defaultPadding,
              child: Text(
                _getPlainText(article.excerpt),
                style: NewsStyles.excerptStyle,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
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
            Padding(
              padding: NewsStyles.smallPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    article.title,
                    style: NewsStyles.gridTitleStyle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(article.date),
                    style: NewsStyles.gridDateStyle,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getPlainText(article.excerpt),
                    style: NewsStyles.gridExcerptStyle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
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

// Utility function to parse HTML content - add outside the class to avoid duplication
Widget _buildHtmlContent(String htmlContent) {
  final document = htmlparser.parse(htmlContent);
  final String plainText = document.body?.text ?? '';
  
  return Text(
    plainText,
    style: NewsStyles.contentStyle,
  );
}
