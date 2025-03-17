import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/log_service.dart';

class NewsArticleScreen extends StatefulWidget {
  final String articleUrl;
  
  const NewsArticleScreen({super.key, required this.articleUrl});

  @override
  State<NewsArticleScreen> createState() => _NewsArticleScreenState();
}

class _NewsArticleScreenState extends State<NewsArticleScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    LogService.log('Opening article: ${widget.articleUrl}', category: 'news');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Samen1 Nieuws'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: <Widget>[
          InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(widget.articleUrl)),
            onLoadStart: (controller, url) async {
              setState(() => _isLoading = true);
              await _injectStyleSheet(controller, url.toString());
            },
            onLoadStop: (controller, url) async {
              await _injectStyleSheet(controller, url.toString());
              setState(() => _isLoading = false);
            },
            shouldOverrideUrlLoading: _handleExternalLinks,
          ),
          if (_isLoading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }

  Future<NavigationActionPolicy> _handleExternalLinks(
      InAppWebViewController controller, NavigationAction navigation) async {
    final url = navigation.request.url.toString().toLowerCase();
    
    // Only allow samen1.nl URLs to navigate within the WebView
    if (url.startsWith('https://samen1.nl/') || url.startsWith('http://samen1.nl/')) {
      LogService.log('Internal navigation: $url', category: 'news');
      return NavigationActionPolicy.ALLOW;
    }
    
    // Launch external URLs in browser
    try {
      LogService.log('Launching external URL: $url', category: 'news');
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      LogService.log('Error launching URL $url: $e', category: 'news_error');
    }
    return NavigationActionPolicy.CANCEL;
  }

  Future<void> _injectStyleSheet(InAppWebViewController controller, String url) async {
    try {
      final cssCode = '''
        footer, .site-header, .site-footer, #mobilebar { display: none !important; }
        body { padding-top: 0 !important; }
        #top { padding-top: 1rem; }
        ${url == 'https://samen1.nl/nieuws/' ? '.page-title { display: none !important; }' : ''}
      ''';
      
      await controller.injectCSSCode(source: cssCode);
      LogService.log('CSS injected for article page', category: 'news');
    } catch (e) {
      LogService.log('Error injecting CSS: $e', category: 'news_error');
    }
  }
}

class NewsPage extends StatefulWidget {
  const NewsPage({super.key});

  @override
  State<NewsPage> createState() => _NewsPageState();
}

class _NewsPageState extends State<NewsPage> {
  bool _isLoading = true;
  bool _isWebViewVisible = false;
  InAppWebViewController? _webViewController;
  static const String _newsUrl = 'https://samen1.nl/nieuws/';

  @override
  void initState() {
    super.initState();
    LogService.log('News page opened', category: 'news');
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _handleBack,
      child: Scaffold(
        body: Stack(
          children: <Widget>[
            AnimatedOpacity(
              opacity: _isWebViewVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 500),
              child: InAppWebView(
                initialUrlRequest: URLRequest(url: WebUri(_newsUrl)),
                onWebViewCreated: (controller) {
                  _webViewController = controller;
                  LogService.log('News WebView created', category: 'news');
                },
                onLoadStart: (controller, url) async {
                  LogService.log('Loading news content: ${url.toString()}', category: 'news');
                  setState(() {
                    _isLoading = true;
                    _isWebViewVisible = false;
                  });
                  await _injectStyleSheet(controller, url.toString());
                },
                onLoadStop: (controller, url) async {
                  await _injectStyleSheet(controller, url.toString());
                  LogService.log('News content loaded', category: 'news');
                  
                  setState(() {
                    _isLoading = false;
                    _isWebViewVisible = true;
                  });
                },
                shouldOverrideUrlLoading: _handleExternalLinks,
              ),
            ),
            if (_isLoading)
              const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }

  Future<bool> _handleBack() async {
    if (await _webViewController?.canGoBack() ?? false) {
      _webViewController?.goBack();
      LogService.log('Navigating back in news WebView', category: 'news');
      return false;
    }
    return true;
  }
  
  Future<NavigationActionPolicy> _handleExternalLinks(
      InAppWebViewController controller, NavigationAction navigation) async {
    final url = navigation.request.url.toString().toLowerCase();
    
    // Only allow samen1.nl URLs
    if (url.startsWith('https://samen1.nl/') || url.startsWith('http://samen1.nl/')) {
      LogService.log('Internal navigation: $url', category: 'news');
      return NavigationActionPolicy.ALLOW;
    }
    
    // Launch external URLs in browser
    try {
      LogService.log('Launching external URL: $url', category: 'news');
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      LogService.log('Error launching URL $url: $e', category: 'news_error');
    }
    return NavigationActionPolicy.CANCEL;
  }

  Future<void> _injectStyleSheet(InAppWebViewController controller, String url) async {
    try {
      final cssCode = '''
        footer, .site-header, .site-footer, #mobilebar { display: none !important; }
        body { padding-top: 0 !important; }
        #top { padding-top: 1rem; }
        ${url == _newsUrl ? '.page-title { display: none !important; }' : ''}
      ''';
      
      await controller.injectCSSCode(source: cssCode);
      LogService.log('CSS injected for news page', category: 'news');
    } catch (e) {
      LogService.log('Error injecting CSS: $e', category: 'news_error');
    }
  }
}
