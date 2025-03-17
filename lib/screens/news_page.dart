import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter/services.dart';
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
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent, 
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ));

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
            onWebViewCreated: (controller) {
              // Removed unused controller assignment
            },
            onLoadStart: (controller, url) async {
              setState(() => _isLoading = true); // Begin met laden
               await _injectCSS(controller, url.toString());
            },
            onLoadStop: (controller, url) async {
              // Injecteer de CSS na het laden
              setState(() => _isLoading = false); // Stop het laden
            },
            shouldOverrideUrlLoading: (controller, navigation) async {
              final url = navigation.request.url.toString().toLowerCase();
              // Alleen exacte samen1.nl URLs toestaan
              if (url.startsWith('https://samen1.nl/') || 
                  url.startsWith('http://samen1.nl/')) {
                return NavigationActionPolicy.ALLOW;
              }
              // Alle andere URLs extern openen
              await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
              return NavigationActionPolicy.CANCEL;
            },
          ),
          if (_isLoading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }

  // Injecteer de CSS na de pagina is geladen
  Future<void> _injectCSS(InAppWebViewController controller, String url) async {
    String cssCode;
    if (url == 'https://samen1.nl/nieuws/') {
      cssCode = '''
        footer, .site-header, .site-footer, #mobilebar, .page-title { display: none !important; }
        body { padding-top: 0 !important; }
        #top { padding-top: 1rem; }
      ''';
    } else {
      cssCode = '''
        footer, .site-header, .site-footer, #mobilebar { display: none !important; }
        body { padding-top: 0 !important; }
        #top { padding-top: 1rem; }
      ''';
    }
    await controller.injectCSSCode(source: cssCode);
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
                initialUrlRequest: URLRequest(url: WebUri('https://samen1.nl/nieuws/')),
                onWebViewCreated: (controller) {
                  _webViewController = controller;
                },
                onLoadStart: (controller, url) async {
                  setState(() {
                    _isLoading = true;
                    _isWebViewVisible = false; // Verberg de WebView tijdens het laden
                  });
                  await _injectCSS(controller, url.toString());
                },
                onLoadStop: (controller, url) async {
                  // Injecteer de CSS na het laden
                  setState(() {
                    _isLoading = false;
                    _isWebViewVisible = true; // Maak de WebView zichtbaar
                  });
                  await _injectCSS(controller, url.toString());
                },
                shouldOverrideUrlLoading: (controller, navigation) async {
                  final url = navigation.request.url.toString().toLowerCase();
                  // Alleen exacte samen1.nl URLs toestaan
                  if (url.startsWith('https://samen1.nl/') || 
                      url.startsWith('http://samen1.nl/')) {
                    return NavigationActionPolicy.ALLOW;
                  }
                  // Alle andere URLs extern openen
                  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                  return NavigationActionPolicy.CANCEL;
                },
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
      LogService.log('Navigating back in WebView', category: 'news');
      return false;
    }
    return true;
  }

  // Injecteer de CSS na de pagina is geladen
  Future<void> _injectCSS(InAppWebViewController controller, String url) async {
    String cssCode;
    if (url == 'https://samen1.nl/nieuws/') {
      cssCode = '''
        footer, .site-header, .site-footer, #mobilebar, .page-title { display: none !important; }
        body { padding-top: 0 !important; }
        #top { padding-top: 1rem; }
      ''';
    } else {
      cssCode = '''
        footer, .site-header, .site-footer, #mobilebar { display: none !important; }
        body { padding-top: 0 !important; }
        #top { padding-top: 1rem; }
      ''';
    }
    await controller.injectCSSCode(source: cssCode);
  }
}
