import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../styles/news_styles.dart';
import '../services/log_service.dart';
import '../services/news_service.dart';
import 'news_article_screen.dart';

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
  static const int _initialLoadCount = 6;
  static const int _fullPageCount = 15;
  bool _loadingRemainingArticles = false;

  @override
  void initState() {
    super.initState();
    _loadInitialNews();
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
    final scrollThreshold = 0.8 * _scrollController.position.maxScrollExtent;
    
    // Check if we should preload next page (when 80% through the list)
    if (_scrollController.position.pixels >= scrollThreshold && 
        !_isPreloading && 
        !_loadingTriggered && 
        _hasMoreArticles && 
        _preloadedArticles.isEmpty) {
      _preloadNextPage();
    }
    
    // Load more when near the bottom (about 4-5 articles from bottom)
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 1200) {
      if (!_isLoading && 
          !_loadingTriggered && 
          _hasMoreArticles && 
          DateTime.now().difference(_lastLoadTime).inMilliseconds > 1500) {
        
        _loadingTriggered = true;
        LogService.log('Nearing end of list, loading more articles', category: 'news');
        
        // Use Future.delayed to slightly defer loading to prevent janky scrolling
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) _loadNews();
        });
      }
    }
  }

  Future<void> _preloadNextPage() async {
    if (_isPreloading || !_hasMoreArticles) return;
    
    _isPreloading = true;
    LogService.log('Preloading news page ${_currentPage + 1}', category: 'news');
    
    try {
      // Use 15 articles per page instead of 11
      final articles = await NewsService.getNews(page: _currentPage + 1, perPage: 15);
      
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
        // Otherwise load from API (15 articles per page instead of 11)
        LogService.log('Loading page $_currentPage directly', category: 'news');
        articles = await NewsService.getNews(page: _currentPage, perPage: 15);
      }
      
      if (articles.isEmpty && _currentPage == 1) {
        LogService.log('No articles found on first page', category: 'news_warning');
        if (mounted) {
          setState(() {
            _isLoading = false;
            _hasError = true;
          });
        }
        return;
      } else if (articles.isEmpty) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _hasMoreArticles = false;
          });
        }
        return;
      }
      
      if (mounted) {
        setState(() {
          _articles.addAll(articles);
          _isLoading = false;
          _currentPage++;
        });
      }

      // Start preloading next page immediately after current page is loaded
      if (_hasMoreArticles && _preloadedArticles.isEmpty) {
        _preloadNextPage();
      }
      
      LogService.log('Loaded ${articles.length} articles. Total: ${_articles.length}', category: 'news');
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = _articles.isEmpty;
        });
      }
      LogService.log('Failed to load news: $e', category: 'news_error');
    }
  }

  Future<void> _loadInitialNews() async {
    if (_isLoading || !_hasMoreArticles) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      // Load initial batch of articles
      final articles = await NewsService.getNews(page: _currentPage, perPage: _initialLoadCount);
      
      if (mounted) {
        setState(() {
          _articles.addAll(articles);
          _isLoading = false;
          if (articles.isEmpty) {
            _hasError = _currentPage == 1;
            _hasMoreArticles = false;
          }
        });
        
        // Load remaining articles for the current page in the background
        _loadRemainingArticles();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = _articles.isEmpty;
        });
      }
      LogService.log('Failed to load initial news: $e', category: 'news_error');
    }
  }

  Future<void> _loadRemainingArticles() async {
    if (_loadingRemainingArticles) return;
    
    _loadingRemainingArticles = true;
    LogService.log('Loading remaining articles for current page', category: 'news');
    
    try {
      final remainingArticles = await NewsService.getNews(
        page: _currentPage,
        perPage: _fullPageCount,
        skipFirst: _initialLoadCount
      );
      
      if (mounted) {
        setState(() {
          _articles.addAll(remainingArticles);
          _loadingRemainingArticles = false;
        });
        
        // Start preloading next page after loading remaining articles
        // Alleen increment currentPage nadat we de preload zijn gestart
        if (_hasMoreArticles && _preloadedArticles.isEmpty) {
          await _preloadNextPage();
          setState(() {
            _currentPage++;
          });
        }
      }
    } catch (e) {
      _loadingRemainingArticles = false;
      LogService.log('Failed to load remaining articles: $e', category: 'news_error');
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
      _loadingRemainingArticles = false;
    });
    await _loadInitialNews();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(40.0), // Smaller height
        child: AppBar(
          title: const Text(
            'Nieuws',
            style: TextStyle(fontSize: 16.0), // Smaller text
          ),
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
          centerTitle: false, // Align text to left
        ),
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
          Icon(Icons.error_outline, size: NewsStyles.errorIconSize, color: NewsStyles.errorIconColor),
          NewsStyles.largeSpaceVertical,
          const Text(
            'Er is iets misgegaan bij het laden van het nieuws.\nMogelijk is de API tijdelijk niet beschikbaar.',
            textAlign: TextAlign.center,
          ),
          NewsStyles.extraLargeSpaceVertical,
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.article_outlined, size: NewsStyles.infoIconSize, color: NewsStyles.infoIconColor),
            NewsStyles.largeSpaceVertical,
            const Text(
              'Geen nieuwsartikelen gevonden.\nProbeer het later nog eens.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView(
      controller: _scrollController,
      padding: EdgeInsets.zero, // Remove default ListView padding
      children: [
        // Featured article - no padding, full width
        _buildFeaturedArticle(_articles.first),
        NewsStyles.largeSpaceVertical,
        if (_articles.length > 1)
          Padding(
            padding: NewsStyles.horizontalPadding, // Using reduced horizontal padding
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _articles.length - 1,
              separatorBuilder: (context, index) => const Divider(height: 16),
              itemBuilder: (context, index) {
                return _buildHorizontalArticleItem(_articles[index + 1]);
              },
            ),
          ),
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
        clipBehavior: Clip.none,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (article.imageUrl.isNotEmpty)
              Stack(
                children: [
                  CachedNetworkImage(
                    imageUrl: article.imageUrl,
                    height: NewsStyles.featuredImageHeightLarge,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      height: NewsStyles.featuredImageHeightLarge,
                      color: NewsStyles.placeholderColor,
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: NewsStyles.featuredImageHeightLarge,
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
                            style: NewsStyles.categoryLabelLight,
                          ),
                          NewsStyles.smallSpaceVertical,
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
                      style: NewsStyles.categoryLabelDark,
                    ),
                    NewsStyles.smallSpaceVertical,
                    Text(
                      article.title,
                      style: NewsStyles.articleTitleStyle,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    NewsStyles.smallSpaceVertical,
                    Text(
                      _formatDate(article.date),
                      style: NewsStyles.articleDateStyle,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHorizontalArticleItem(NewsArticle article) {
    return GestureDetector(
      onTap: () => _openArticle(article),
      child: Container(
        // Use min height constraint but allow it to grow for longer titles
        constraints: BoxConstraints(
          minHeight: NewsStyles.horizontalArticleHeight,
        ),
        padding: EdgeInsets.zero, // Remove any container padding
        margin: const EdgeInsets.symmetric(horizontal: 2.0), // Add small margin instead of padding
        decoration: NewsStyles.horizontalItemDecoration,
        clipBehavior: Clip.antiAlias,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left side - Image with NO border radius on left
            if (article.imageUrl.isNotEmpty)
              ClipRRect(
                // Only apply border radius to right side corners
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(0),
                  bottomRight: Radius.circular(0),
                  topLeft: Radius.circular(8),
                  bottomLeft: Radius.circular(8),
                ),
                child: SizedBox(
                  width: NewsStyles.horizontalImageWidth,
                  height: NewsStyles.horizontalArticleHeight,
                  child: CachedNetworkImage(
                    imageUrl: article.imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: NewsStyles.placeholderColor,
                      child: Center(
                        child: SizedBox(
                          width: NewsStyles.smallLoaderSize,
                          height: NewsStyles.smallLoaderSize,
                          child: CircularProgressIndicator(strokeWidth: NewsStyles.smallLoaderStrokeWidth),
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: NewsStyles.placeholderColor,
                      child: const Icon(Icons.error, size: 30),
                    ),
                  ),
                ),
              ),
            // Right side - Content with slightly more space
            Expanded(
              child: Padding(
                padding: NewsStyles.horizontalArticleTextPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category and date row
                    Row(
                      children: [
                        Text(
                          article.category,
                          style: NewsStyles.categoryLabelGrid,
                        ),
                        NewsStyles.smallSpaceHorizontal,
                        Text(
                          "•",
                          style: NewsStyles.separatorStyle,
                        ),
                        NewsStyles.smallSpaceHorizontal,
                        Text(
                          _formatDate(article.date),
                          style: NewsStyles.gridDateStyle,
                        ),
                      ],
                    ),
                    NewsStyles.smallSpaceVertical,
                    // Title with more space for longer titles
                    Text(
                      article.title,
                      style: NewsStyles.horizontalTitleStyle,
                      maxLines: 3, // Explicitly allow 3 lines
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10), // More bottom spacing to ensure content fits
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
}

String _formatDate(String dateString) {
  try {
    final date = DateTime.parse(dateString);
    return DateFormat('d MMMM yyyy').format(date);
  } catch (e) {
    return dateString;
  }
}