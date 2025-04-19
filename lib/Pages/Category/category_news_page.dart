import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../News/news_styles.dart';
import '../../services/log_service.dart';
import '../News/news_service.dart';
import '../../Popup/news_article_screen.dart';

// Define LoadState enum (same as in news_page.dart)
enum LoadState { initial, loadingInitial, loadingMore, preloading, refreshing, idle, error, allLoaded }

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
  // Replace boolean flags with LoadState
  LoadState _loadState = LoadState.initial;
  bool _hasMoreArticles = true;
  int _currentPage = 1; // Represents the page *to load next*
  final ScrollController _scrollController = ScrollController();
  static const int _fullPageCount = 15;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    // Load the first full page directly
    _loadNews(isInitialLoad: true); 
    _scrollController.addListener(_scrollListener);
    LogService.log('Category page opened: ${widget.title}', category: 'news');
  }

  @override
  void dispose() {
    _isDisposed = true;
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  // Updated scroll listener using LoadState
  void _scrollListener() {
    if (!mounted || _isDisposed) return;

    final scrollThreshold = 0.8 * _scrollController.position.maxScrollExtent;
    final nearBottom = _scrollController.position.pixels >= 
                      _scrollController.position.maxScrollExtent - 1200;

    // Preload trigger
    if (_scrollController.position.pixels >= scrollThreshold &&
        _loadState == LoadState.idle && // Only preload when idle
        _hasMoreArticles && 
        _preloadedArticles.isEmpty) {
      _preloadNextPage();
    }
    
    // Load more trigger
    if (nearBottom && 
        _loadState == LoadState.idle && // Only load more when idle
        _hasMoreArticles) {
      // Use Future.delayed
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted && !_isDisposed && _loadState == LoadState.idle) { // Double check state
          LogService.log('Nearing end of list, loading more articles for page $_currentPage', category: 'news');
          _loadNews(); 
        }
      });
    }
  }

  // Updated preload function using LoadState
  Future<void> _preloadNextPage() async {
    final pageToPreload = _currentPage;
    if (_loadState == LoadState.preloading || !_hasMoreArticles || !mounted || _isDisposed) return;
    
    _loadState = LoadState.preloading;
    LogService.log('Preloading category news page $pageToPreload', category: 'news');
    
    try {
      final articles = await NewsService.getNewsByCategory(
        categoryId: widget.categoryId,
        page: pageToPreload, 
        perPage: _fullPageCount
      );
      
      if (!mounted || _isDisposed) return;
      
      if (articles.isEmpty) {
        LogService.log('Preload found no articles for page $pageToPreload', category: 'news');
         _preloadedArticles = [];
      } else {
        _preloadedArticles = articles;
        LogService.log('Successfully preloaded ${articles.length} articles for page $pageToPreload', 
            category: 'news');
      }
    } catch (e) {
      LogService.log('Failed to preload category news page $pageToPreload: $e', category: 'news_error');
       _preloadedArticles = [];
    } finally {
      if (mounted && !_isDisposed && _loadState == LoadState.preloading) {
        _loadState = LoadState.idle;
      }
    }
  }

  // Updated loading function using LoadState
  Future<void> _loadNews({bool isInitialLoad = false}) async {
    if (!mounted || _isDisposed ||
        (_loadState != LoadState.idle && 
         _loadState != LoadState.initial &&
         _loadState != LoadState.error)) {
      return;
    }
    
    setState(() {
       _loadState = isInitialLoad ? LoadState.loadingInitial : LoadState.loadingMore;
    });
    LogService.log('Loading category news page $_currentPage (Initial: $isInitialLoad)', category: 'news');

    try {
      List<NewsArticle> articles;
      
      // Use preloaded articles if available
      if (_preloadedArticles.isNotEmpty) {
        LogService.log('Using preloaded articles for page $_currentPage', category: 'news');
        articles = _preloadedArticles;
        _preloadedArticles = [];
      } else {
        // Otherwise load from API
        LogService.log('Loading page $_currentPage directly from API', category: 'news');
        articles = await NewsService.getNewsByCategory(
          categoryId: widget.categoryId,
          page: _currentPage, 
          perPage: _fullPageCount
        );
      }
      
      if (!mounted || _isDisposed) return;
      
      if (articles.isEmpty) {
        _hasMoreArticles = false;
        LogService.log('Loaded 0 articles for page $_currentPage. Reached end.', category: 'news');
        if (_articles.isEmpty) {
           _loadState = LoadState.error;
           LogService.log('No articles found on initial load (page 1). Setting error state.', category: 'news_warning');
        } else {
           _loadState = LoadState.allLoaded;
        }
      } else {
        _articles.addAll(articles);
        _currentPage++; 
        _loadState = LoadState.idle;
        LogService.log('Loaded ${articles.length} articles. Total: ${_articles.length}. Next page to load/preload: $_currentPage', category: 'news');
      }

      // Trigger preload for the next page
      if (_loadState == LoadState.idle && _hasMoreArticles && _preloadedArticles.isEmpty) {
        _preloadNextPage();
      }
      
    } catch (e) {
      LogService.log('Failed to load category news for page $_currentPage: $e', category: 'news_error');
      if (mounted && !_isDisposed) {
         _loadState = _articles.isEmpty ? LoadState.error : LoadState.idle;
      }
    } finally {
      if (mounted && !_isDisposed) {
        setState(() {});
      }
    }
  }

  // Smarter refresh function
  Future<void> _refreshNews() async {
    if (!mounted || _isDisposed || _loadState == LoadState.refreshing) return;
    LogService.log('Refreshing category news...', category: 'news');
    
    setState(() {
      _loadState = LoadState.refreshing;
       _preloadedArticles = [];
    });
    
    try {
      // Fetch the very first page
      final List<NewsArticle> fetchedArticles = await NewsService.getNewsByCategory(
        categoryId: widget.categoryId, 
        page: 1, 
        perPage: _fullPageCount
      );

      if (!mounted || _isDisposed) return;

      if (fetchedArticles.isNotEmpty) {
        final currentIds = _articles.map((a) => a.id).toSet();
        final newArticles = fetchedArticles.where((a) => !currentIds.contains(a.id)).toList();

        if (newArticles.isNotEmpty) {
          LogService.log('Found ${newArticles.length} new articles during refresh.', category: 'news');
          setState(() {
            _articles.insertAll(0, newArticles);
          });
        } else {
          LogService.log('No new articles found during refresh.', category: 'news');
        }
      } else {
         LogService.log('Refresh fetch returned empty list.', category: 'news_warning');
      }

      // Reset state after refresh logic
      setState(() {
        _currentPage = 1; 
        _hasMoreArticles = true; 
        _loadState = LoadState.idle;
      });
      
      // Trigger preload for page 2
      _preloadNextPage();

    } catch (e) {
      LogService.log('Error during category news refresh: $e', category: 'news_error');
      if (mounted && !_isDisposed) {
        setState(() {
           _loadState = _articles.isEmpty ? LoadState.error : LoadState.idle;
        });
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kon nieuws niet vernieuwen.'))
        );
      }
    }
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
        child: _loadState == LoadState.loadingInitial && _articles.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : _loadState == LoadState.error && _articles.isEmpty
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
            'Oeps, het laden van het nieuws is niet gelukt.\nProbeer het over een paar minuten opnieuw.\nBlijft dit gebeuren? Laat het ons weten via een bugrapport in de instellingen..',
            textAlign: TextAlign.center,
          ),
          NewsStyles.extraLargeSpaceVertical,
          ElevatedButton(
            onPressed: () => _loadNews(isInitialLoad: true), // Retry initial load
            child: const Text('Opnieuw proberen'),
          ),
        ],
      ),
    );
  }

  Widget _buildNewsLayout() {
     if (_articles.isEmpty && (_loadState == LoadState.idle || _loadState == LoadState.allLoaded)) {
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
      padding: EdgeInsets.zero, 
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
        // Footer showing loading indicator or end message
        Container(
          padding: NewsStyles.verticalPadding,
          alignment: Alignment.center,
          child: _loadState == LoadState.loadingMore
              ? const CircularProgressIndicator()
              : _loadState == LoadState.allLoaded && _articles.isNotEmpty
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
    // Use context 'featured'
    final imageUrl = article.getImageUrlForContext('featured');
    return GestureDetector(
      onTap: () => _openArticle(article),
      child: Container(
        clipBehavior: Clip.none,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageUrl.isNotEmpty) // Check the context-specific URL
              Stack(
                children: [
                  CachedNetworkImage(
                    imageUrl: imageUrl, // Use context-specific URL
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
            if (imageUrl.isEmpty) // Check the context-specific URL
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
    // Use context 'list_item'
    final imageUrl = article.getImageUrlForContext('list_item');
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
            if (imageUrl.isNotEmpty) // Check the context-specific URL
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  bottomLeft: Radius.circular(8),
                ),
                child: SizedBox(
                  width: NewsStyles.horizontalImageWidth,
                  height: NewsStyles.horizontalArticleHeight,
                  child: CachedNetworkImage(
                    imageUrl: imageUrl, // Use context-specific URL
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
