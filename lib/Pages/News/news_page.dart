import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'news_styles.dart';
import '../../services/log_service.dart';
import 'news_service.dart';
import '../../Popup/news_article_screen.dart';

// Define LoadState enum
enum LoadState { initial, loadingInitial, loadingMore, preloading, refreshing, idle, error, allLoaded }

class NewsPage extends StatefulWidget {
  final bool isInContainer;
  final int? categoryId; // Optional category ID
  final String? title;    // Optional title for AppBar

  const NewsPage({
    super.key, 
    this.isInContainer = false,
    this.categoryId,     // Add categoryId parameter
    this.title,          // Add title parameter
  });

  @override
  State<NewsPage> createState() => _NewsPageState();
}

class _NewsPageState extends State<NewsPage> {
  final List<NewsArticle> _articles = [];
  List<NewsArticle> _preloadedArticles = [];
  // Replace boolean flags with LoadState
  LoadState _loadState = LoadState.initial; 
  bool _hasMoreArticles = true;
  int _currentPage = 1; // Represents the page *to load next*
  final ScrollController _scrollController = ScrollController();
  static const int _fullPageCount = 15;

  @override
  void initState() {
    super.initState();
    // Load the first full page directly
    _loadNews(isInitialLoad: true); 
    _scrollController.addListener(_scrollListener);
    LogService.log('News page opened ${widget.categoryId != null ? 'for category ${widget.categoryId}' : 'for general news'}', category: 'news');
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  // Updated scroll listener using LoadState
  void _scrollListener() {
    if (!mounted) return;

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
      // Use Future.delayed to slightly defer loading
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted && _loadState == LoadState.idle) { // Double check state
           LogService.log('Nearing end of list, loading more articles for page $_currentPage', category: 'news');
           _loadNews(); 
        }
      });
    }
  }

  // Updated preload function using LoadState and categoryId
  Future<void> _preloadNextPage() async {
    final pageToPreload = _currentPage; // Preload the page we expect to load next
    if (_loadState == LoadState.preloading || !_hasMoreArticles || !mounted) return;
    
    // Set state without setState for background task
    _loadState = LoadState.preloading; 
    LogService.log('Preloading news page $pageToPreload ${widget.categoryId != null ? 'for category ${widget.categoryId}' : ''}', category: 'news');
    
    try {
      // Use correct service method based on categoryId
      final articles = widget.categoryId == null
          ? await NewsService.getNews(page: pageToPreload, perPage: _fullPageCount)
          : await NewsService.getNewsByCategory(categoryId: widget.categoryId!, page: pageToPreload, perPage: _fullPageCount);
      
      if (!mounted) return; 

      if (articles.isEmpty) {
        // Don't set _hasMoreArticles here, let _loadNews handle it
        LogService.log('Preload found no articles for page $pageToPreload', category: 'news');
        _preloadedArticles = []; // Ensure preload cache is empty
      } else {
        _preloadedArticles = articles;
        LogService.log('Successfully preloaded ${articles.length} articles for page $pageToPreload', 
            category: 'news');
      }
    } catch (e) {
      LogService.log('Failed to preload news page $pageToPreload: $e', category: 'news_error');
      _preloadedArticles = []; // Clear cache on error
    } finally {
      if (mounted && _loadState == LoadState.preloading) {
         // Only revert to idle if still in preloading state
        _loadState = LoadState.idle; 
        // No setState needed as this doesn't directly affect UI until _loadNews uses it
      }
    }
  }

  // Updated loading function using LoadState and categoryId
  Future<void> _loadNews({bool isInitialLoad = false}) async {
    // Prevent concurrent loads/refreshes
    if (!mounted || 
        (_loadState != LoadState.idle && 
         _loadState != LoadState.initial &&
         _loadState != LoadState.error)) {
      return;
    }
    
    setState(() {
      _loadState = isInitialLoad ? LoadState.loadingInitial : LoadState.loadingMore;
    });
    LogService.log('Loading news page $_currentPage ${widget.categoryId != null ? 'for category ${widget.categoryId}' : ''} (Initial: $isInitialLoad)', category: 'news');

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
        // Use correct service method based on categoryId
        articles = widget.categoryId == null
            ? await NewsService.getNews(page: _currentPage, perPage: _fullPageCount)
            : await NewsService.getNewsByCategory(categoryId: widget.categoryId!, page: _currentPage, perPage: _fullPageCount);
      }
      
      if (!mounted) return; 

      if (articles.isEmpty) {
        _hasMoreArticles = false;
        LogService.log('Loaded 0 articles for page $_currentPage. Reached end.', category: 'news');
        if (_articles.isEmpty) {
          _loadState = LoadState.error; // Set error state if first load failed
          LogService.log('No articles found on initial load (page 1). Setting error state.', category: 'news_warning');
        } else {
          _loadState = LoadState.allLoaded; // Set allLoaded state if subsequent load is empty
        }
      } else {
        _articles.addAll(articles);
        _currentPage++; 
        _loadState = LoadState.idle; // Back to idle after successful load
        LogService.log('Loaded ${articles.length} articles. Total: ${_articles.length}. Next page to load/preload: $_currentPage', category: 'news');
      }

      // Trigger preload for the *next* page if idle and more might exist
      if (_loadState == LoadState.idle && _hasMoreArticles && _preloadedArticles.isEmpty) {
         _preloadNextPage();
      }
      
    } catch (e) {
      LogService.log('Failed to load news for page $_currentPage: $e', category: 'news_error');
      if (mounted) {
        _loadState = _articles.isEmpty ? LoadState.error : LoadState.idle; // Error only if list empty, else idle
      }
    } finally {
       if (mounted) {
        setState(() {}); // Update UI with final state
      }
    }
  }

  // Smarter refresh function
  Future<void> _refreshNews() async {
     if (!mounted || _loadState == LoadState.refreshing) return; // Prevent concurrent refreshes
     LogService.log('Refreshing news ${widget.categoryId != null ? 'for category ${widget.categoryId}' : ''}...', category: 'news');
     
    setState(() {
      _loadState = LoadState.refreshing;
      _preloadedArticles = []; // Clear preload during refresh
    });

    try {
      // Use correct service method based on categoryId
      final List<NewsArticle> fetchedArticles = widget.categoryId == null
          ? await NewsService.getNews(page: 1, perPage: _fullPageCount)
          : await NewsService.getNewsByCategory(categoryId: widget.categoryId!, page: 1, perPage: _fullPageCount);

      if (!mounted) return;

      if (fetchedArticles.isNotEmpty) {
        // Get IDs of currently displayed articles
        final currentIds = _articles.map((a) => a.id).toSet();
        // Filter fetched articles to find only the new ones
        final newArticles = fetchedArticles.where((a) => !currentIds.contains(a.id)).toList();

        if (newArticles.isNotEmpty) {
          LogService.log('Found ${newArticles.length} new articles during refresh.', category: 'news');
          setState(() {
            _articles.insertAll(0, newArticles); // Prepend new articles
          });
        } else {
          LogService.log('No new articles found during refresh.', category: 'news');
          // Optionally show a snackbar: ScaffoldMessenger.of(context).showSnackBar(...)
        }
      } else {
         LogService.log('Refresh fetch returned empty list.', category: 'news_warning');
         // Handle case where refresh fails to get page 1 - maybe show error?
      }

      // Reset state after refresh logic
      setState(() {
        // Reset currentPage to 2 because page 1 was just fetched for the refresh.
        // The next page to actually load into the list via _loadNews will be 2.
        _currentPage = 2; 
        _hasMoreArticles = true; // Assume there might be more after refresh
        _loadState = LoadState.idle; // Back to idle
      });
      
      // Trigger preload for page 2 after successful refresh
      _preloadNextPage(); 

    } catch (e) {
      LogService.log('Error during news refresh: $e', category: 'news_error');
      if (mounted) {
        setState(() {
          // Revert to idle, keep existing articles. Error state only if list was initially empty.
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
    // Determine the title for the AppBar
    final appBarTitle = widget.title ?? 'Nieuws'; 

    return Scaffold(
      // Use conditional AppBar based on isInContainer and provide dynamic title
      appBar: widget.isInContainer ? null : PreferredSize(
        preferredSize: const Size.fromHeight(40.0), // Smaller height
        child: AppBar(
          title: Text(
            appBarTitle, // Use dynamic title
            style: const TextStyle(fontSize: 16.0), // Smaller text
          ),
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
          centerTitle: false, // Align text to left
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshNews,
        // Show main loading indicator only on initial load
        child: _loadState == LoadState.loadingInitial && _articles.isEmpty
            ? const Center(child: CircularProgressIndicator())
            // Show error view only if in error state
            : _loadState == LoadState.error && _articles.isEmpty 
                ? _buildErrorView()
                : _buildNewsLayout(),
      ),
    );
  }

  Widget _buildErrorView() {
    // Generic error message
    const String errorMessage = 'Oeps, het laden van het nieuws is niet gelukt.\nProbeer het over een paar minuten opnieuw.\nBlijft dit gebeuren? Laat het ons weten via een bugrapport in de instellingen..';

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: NewsStyles.errorIconSize, color: NewsStyles.errorIconColor),
          NewsStyles.largeSpaceVertical,
          const Text(
            errorMessage, // Use generic message
            textAlign: TextAlign.center,
          ),
          NewsStyles.extraLargeSpaceVertical,
          ElevatedButton(
            // Retry triggers initial load again
            onPressed: () => _loadNews(isInitialLoad: true), 
            child: const Text('Opnieuw proberen'),
          ),
        ],
      ),
    );
  }

  Widget _buildNewsLayout() {
    // Show empty state message if idle and list is empty (after trying to load)
    if (_articles.isEmpty && (_loadState == LoadState.idle || _loadState == LoadState.allLoaded)) {
      // Dynamic empty message
      final String emptyMessage = widget.categoryId != null 
          ? 'Geen artikelen gevonden in ${widget.title ?? 'deze categorie'}.\nProbeer het later nog eens.'
          : 'Geen nieuwsartikelen gevonden.\nProbeer het later nog eens.';

      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.article_outlined, size: NewsStyles.infoIconSize, color: NewsStyles.infoIconColor),
            NewsStyles.largeSpaceVertical,
            Text(
              emptyMessage, // Use dynamic message
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
        // Ensure _articles is not empty before accessing first
        if (_articles.isNotEmpty) _buildFeaturedArticle(_articles.first), 
        NewsStyles.largeSpaceVertical,
        if (_articles.length > 1)
          Padding(
            padding: NewsStyles.horizontalPadding, // Using reduced horizontal padding
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              // Adjust itemCount for the case where there's only one article
              itemCount: _articles.length > 1 ? _articles.length - 1 : 0, 
              separatorBuilder: (context, index) => const Divider(height: 16),
              itemBuilder: (context, index) {
                // Check index bounds just in case, though itemCount should handle it
                if (index + 1 < _articles.length) {
                  return _buildHorizontalArticleItem(_articles[index + 1]);
                }
                return const SizedBox.shrink(); // Should not happen
              },
            ),
          ),
        // Footer showing loading indicator or end message
        Container(
          padding: NewsStyles.verticalPadding,
          alignment: Alignment.center,
          // Show loading more indicator
          child: _loadState == LoadState.loadingMore
              ? const CircularProgressIndicator()
              // Show all loaded message
              : _loadState == LoadState.allLoaded && _articles.isNotEmpty 
                  ? Text(
                      'Alle artikelen zijn geladen',
                      style: NewsStyles.noMoreArticlesStyle,
                    )
                  : const SizedBox.shrink(), // Hide otherwise
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
            if (imageUrl.isNotEmpty) // Check the context-specific URL
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