import 'package:flutter/material.dart';
import 'package:html/parser.dart' as htmlparser;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:flutter_html/flutter_html.dart';
import '../styles/news_styles.dart';
import '../services/log_service.dart';
import '../services/news_service.dart';

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
                      style: NewsStyles.categoryLabelDark,
                    ),
                    NewsStyles.mediumSpaceHorizontal,
                    Text(
                      "•",
                      style: NewsStyles.separatorStyleLarge,
                    ),
                    NewsStyles.mediumSpaceHorizontal,
                    Text(
                      _formatDate(article.date),
                      style: NewsStyles.articleDateStyle,
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
                    NewsStyles.smallSpaceVertical,
                    Row(
                      children: [
                        Text(
                          article.category,
                          style: NewsStyles.categoryLabelDark,
                        ),
                        NewsStyles.mediumSpaceHorizontal,
                        Text(
                          "•",
                          style: NewsStyles.separatorStyleLarge,
                        ),
                        NewsStyles.mediumSpaceHorizontal,
                        Text(
                          _formatDate(article.date),
                          style: NewsStyles.articleDateStyle,
                        ),
                      ],
                    ),
                    NewsStyles.largeSpaceVertical,
                  ],
                  // The HTML content renderer
                  _buildRichHtmlContent(article.content, context),
                  NewsStyles.largeSpaceVertical,
                  if (article.imageCaption != null && article.imageCaption!.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: NewsStyles.imageCaptionContainer,
                      child: Row(
                        children: [
                          const Icon(Icons.photo_camera, size: 16, color: Colors.grey),
                          NewsStyles.mediumSpaceHorizontal,
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

String _formatDate(String dateString) {
  try {
    final date = DateTime.parse(dateString);
    return DateFormat('d MMMM yyyy').format(date);
  } catch (e) {
    return dateString;
  }
}

Widget _buildRichHtmlContent(String htmlContent, BuildContext context) {
  return Html(
    data: htmlContent,
    style: {
      "body": Style(
        fontSize: FontSize(NewsStyles.htmlBodyFontSize),
        fontWeight: FontWeight.normal,
        color: Colors.black87,
        lineHeight: LineHeight(NewsStyles.htmlLineHeight),
      ),
      "p": Style(
        margin: Margins.only(bottom: NewsStyles.htmlMarginBottom),
      ),
      "strong": Style(
        fontWeight: FontWeight.bold,
      ),
      "img": Style(
        padding: HtmlPaddings.zero,
        margin: Margins.only(top: 8.0, bottom: 8.0),
        display: Display.block,
      ),
      "figure": Style(
        margin: Margins.symmetric(vertical: NewsStyles.htmlFigureMargin),
        display: Display.block,
      ),
      "figcaption": Style(
        padding: HtmlPaddings.all(NewsStyles.htmlCaptionPadding),
        fontSize: FontSize(NewsStyles.htmlCaptionFontSize),
        color: Colors.grey,
        textAlign: TextAlign.center,
        backgroundColor: NewsStyles.backgroundGreyColor,
      ),
    },
    onLinkTap: (url, _, __) {
      if (url != null) {
        // Handle link taps if needed
      }
    },
  );
}