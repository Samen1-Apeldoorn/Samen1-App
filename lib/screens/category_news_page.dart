import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../styles/news_styles.dart';
import '../services/log_service.dart';
import '../services/news_service.dart';
import 'news_article_screen.dart';

class CategoryNewsPage extends StatefulWidget {
  final String title;
  final int categoryId;
  final bool isInContainer;

  const CategoryNewsPage({
    super.key, 
    required this.title,
    required this.categoryId,
    this.isInContainer = true,
  });

  @override
  State<CategoryNewsPage> createState() => _CategoryNewsPageState();
}

class _CategoryNewsPageState extends State<CategoryNewsPage> {
  final List<NewsArticle> _articles = [];
  List<NewsArticle> _preloadedArticles = [];
  bool _isLoading = false;
  bool _isPreloading = false;
  bool _hasError = false;
  bool _hasMoreArticles = true;
  int _currentPage = 1;
  final ScrollController _scrollController = ScrollController();
  DateTime _lastLoadTime = DateTime.now();
  bool _loadingTriggered = false;
  static const int _initialLoadCount = 6;
  static const int _fullPageCount = 15;
  bool _loadingRemainingArticles = false;
  bool _isDisposed = false;  // Track if widget is disposed

  @override
  void initState() {
    super.initState();
    _loadInitialNews();
    _scrollController.addListener(_scrollListener);
    LogService.log('Category page opened: ${widget.title}', category: 'news');
  }

  @override
  void dispose() {
    _isDisposed = true;  // Mark as disposed
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  // Scroll listener with debouncing
  void _scrollListener() {
    if (!mounted || _isDisposed) return;  // Early return if not mounted
    
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
          if (mounted && !_isDisposed) _loadNews();
        });
      }
    }
  }

  Future<void> _preloadNextPage() async {
    if (_isPreloading || !_hasMoreArticles || !mounted || _isDisposed) return;
    
    _isPreloading = true;
    LogService.log('Preloading category news page ${_currentPage + 1}', category: 'news');
    
    try {
      // Use the category-specific method to fetch news
      final articles = await NewsService.getNewsByCategory(
        categoryId: widget.categoryId,
        page: _currentPage + 1, 
        perPage: 15
      );
      
      if (!mounted || _isDisposed) return;  // Check again after async operation
      
      if (articles.isEmpty) {
        _hasMoreArticles = false;
      } else {
        _preloadedArticles = articles;
        LogService.log('Successfully preloaded ${articles.length} articles for page ${_currentPage + 1}', 
            category: 'news');
      }
    } catch (e) {
      LogService.log('Failed to preload category news page ${_currentPage + 1}: $e', category: 'news_error');
    } finally {
      if (mounted && !_isDisposed) {
        setState(() {
          _isPreloading = false;
        });
      }
    }
  }

  // Load news articles
  Future<void> _loadNews() async {
    if (_isLoading || !_hasMoreArticles || !mounted || _isDisposed) return;
    
    _lastLoadTime = DateTime.now();
    _loadingTriggered = false;
    
    if (!mounted || _isDisposed) return;  // Double check
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
        // Otherwise load from API using the category-specific method
        LogService.log('Loading page $_currentPage directly', category: 'news');
        articles = await NewsService.getNewsByCategory(
          categoryId: widget.categoryId,
          page: _currentPage, 
          perPage: 15
        );
      }
      
      if (!mounted || _isDisposed) return;  // Check again after async operation
      
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
      if (!mounted || _isDisposed) return;  // Check again after async error
      
      setState(() {
        _isLoading = false;
        _hasError = _articles.isEmpty;
      });
      
      LogService.log('Failed to load news: $e', category: 'news_error');
    }
  }

  Future<void> _loadInitialNews() async {
    if (_isLoading || !_hasMoreArticles || !mounted || _isDisposed) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      // Load initial batch of articles using the category-specific method
      final articles = await NewsService.getNewsByCategory(
        categoryId: widget.categoryId,
        page: _currentPage, 
        perPage: _initialLoadCount
      );
      
      if (!mounted || _isDisposed) return;  // Check again after async operation
      
      setState(() {
        _articles.addAll(articles);
        _isLoading = false;
        if (articles.isEmpty) {
          _hasError = _currentPage == 1;
          _hasMoreArticles = false;
        }
      });
      
      // Load remaining articles for the current page in the background
      if (mounted && !_isDisposed) {
        _loadRemainingArticles();
      }
    } catch (e) {
      if (!mounted || _isDisposed) return;  // Check again after async error
      
      setState(() {
        _isLoading = false;
        _hasError = _articles.isEmpty;
      });
      
      LogService.log('Failed to load initial news: $e', category: 'news_error');
    }
  }

  Future<void> _loadRemainingArticles() async {
    if (_loadingRemainingArticles || !mounted || _isDisposed) return;
    
    _loadingRemainingArticles = true;
    LogService.log('Loading remaining articles for current page', category: 'news');
    
    try {
      final remainingArticles = await NewsService.getNewsByCategory(
        categoryId: widget.categoryId,
        page: _currentPage,
        perPage: _fullPageCount,
        skipFirst: _initialLoadCount
      );
      
      if (!mounted || _isDisposed) {
        // Critical check - this is where the error was happening
        LogService.log('Widget disposed before remaining articles loaded', category: 'news');
        return;
      }
      
      setState(() {
        _articles.addAll(remainingArticles);
        _loadingRemainingArticles = false;
      });
      
      // Start preloading next page after loading remaining articles
      if (_hasMoreArticles && _preloadedArticles.isEmpty && mounted && !_isDisposed) {
        await _preloadNextPage();
        
        if (mounted && !_isDisposed) {
          setState(() {
            _currentPage++;
          });
        }
      }
    } catch (e) {
      if (mounted && !_isDisposed) {
        _loadingRemainingArticles = false;
      }
      LogService.log('Failed to load remaining articles: $e', category: 'news_error');
    }
  }

  Future<void> _refreshNews() async {
    if (!mounted || _isDisposed) return;
    
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
      appBar: widget.isInContainer ? null : PreferredSize(
        preferredSize: const Size.fromHeight(40.0), // Smaller height
        child: AppBar(
          title: Text(
            widget.title,
            style: const TextStyle(fontSize: 16.0), // Smaller text
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
            Text(
              'Geen artikelen gevonden in ${widget.title}.\nProbeer het later nog eens.',
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
        if (_articles.isNotEmpty) _buildFeaturedArticle(_articles.first),
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
        constraints: BoxConstraints(
          minHeight: NewsStyles.horizontalArticleHeight,
        ),
        padding: EdgeInsets.zero,
        margin: const EdgeInsets.symmetric(horizontal: 2.0),
        decoration: NewsStyles.horizontalItemDecoration,
        clipBehavior: Clip.antiAlias,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (article.imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.only(
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
            Expanded(
              child: Padding(
                padding: NewsStyles.horizontalArticleTextPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          article.category,
                          style: NewsStyles.categoryLabelGrid,
                        ),
                        NewsStyles.smallSpaceHorizontal,
                        const Text(
                          "•",
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                          ),
                        ),
                        NewsStyles.smallSpaceHorizontal,
                        Text(
                          _formatDate(article.date),
                          style: NewsStyles.gridDateStyle,
                        ),
                      ],
                    ),
                    NewsStyles.smallSpaceVertical,
                    Text(
                      article.title,
                      style: NewsStyles.horizontalTitleStyle,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
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
    if (!mounted || _isDisposed) return;
    
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
