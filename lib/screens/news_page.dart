import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';

// Move this class to the beginning of the file for better visibility/export
class NewsArticleScreen extends StatefulWidget {
  final String articleUrl;
  
  const NewsArticleScreen({super.key, required this.articleUrl});

  @override
  State<NewsArticleScreen> createState() => _NewsArticleScreenState();
}

class _NewsArticleScreenState extends State<NewsArticleScreen> {
  bool _isLoading = true;
  InAppWebViewController? _webViewController;

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
            onWebViewCreated: (controller) {
              _webViewController = controller;
            },
            onLoadStart: (controller, url) {
              setState(() => _isLoading = true);
            },
            onLoadStop: (controller, url) async {
              if (url.toString() == 'https://samen1.nl/nieuws/') {
                // CSS voor de homepage
                await controller.injectCSSCode(source: '''
                  footer, .site-header, .site-footer, #mobilebar, .page-title { display: none !important; }
                  body { padding-top: 0 !important; }
                  #top { padding-top: 1rem; }
                ''');
              } else {
                // CSS voor andere pagina's
                await controller.injectCSSCode(source: '''
                  footer, .site-header, .site-footer, #mobilebar { display: none !important; }
                  body { padding-top: 0 !important; }
                  #top { padding-top: 1rem; }
                ''');
              }

              setState(() => _isLoading = false);
            },
            shouldOverrideUrlLoading: (controller, navigation) async {
              final url = navigation.request.url.toString();
              if (!url.contains('samen1.nl')) {
                launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                return NavigationActionPolicy.CANCEL;
              }
              return NavigationActionPolicy.ALLOW;
            },
          ),
          if (_isLoading)
            const Center(child: CircularProgressIndicator()),
        ],
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
  bool _isLoading = true;  // Laadstatus bijhouden
  bool _isWebViewVisible = false;  // Website zichtbaarheid bijhouden
  InAppWebViewController? _webViewController;  // Controller voor de WebView

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (await _webViewController?.canGoBack() ?? false) {
          // Als de webview een geschiedenis heeft, ga dan terug naar de vorige pagina
          _webViewController?.goBack();
          return false;  // Voorkom dat de app sluit
        }
        return true;  // Sluit de app als er geen geschiedenis is
      },
      child: Scaffold(
        body: Stack(
          children: <Widget>[
            // WebView - deze is verborgen totdat de pagina is geladen
            AnimatedOpacity(
              opacity: _isWebViewVisible ? 1.0 : 0.0,  // Webview zichtbaar maken zodra geladen
              duration: const Duration(milliseconds: 500),
              child: InAppWebView(
                initialUrlRequest: URLRequest(url: WebUri('https://samen1.nl/nieuws/')),
                onWebViewCreated: (controller) {
                  _webViewController = controller;  // Initialiseer de controller
                },
                onLoadStart: (controller, url) {
                  setState(() {
                    _isLoading = true;  // Start loading indicator
                    _isWebViewVisible = false;  // Webview blijft verborgen tijdens het laden
                  });
                },
                onLoadStop: (controller, url) async {
                  // Controleer de URL en pas de CSS aan op basis van de pagina
                  if (url.toString() == 'https://samen1.nl/nieuws/') {
                    // CSS voor de homepage
                    await controller.injectCSSCode(source: '''
                      footer, .site-header, .site-footer, #mobilebar, .page-title { display: none !important; }
                      body { padding-top: 0 !important; }
                      #top { padding-top: 1rem; }
                    ''');
                  } else {
                    // CSS voor andere pagina's
                    await controller.injectCSSCode(source: '''
                      footer, .site-header, .site-footer, #mobilebar { display: none !important; }
                      body { padding-top: 0 !important; }
                      #top { padding-top: 1rem; }
                    ''');
                  }

                  setState(() {
                    _isLoading = false;  // Stop loading
                    _isWebViewVisible = true;  // Maak de webpagina zichtbaar
                  });
                },
                shouldOverrideUrlLoading: (controller, navigation) async {
                  final url = navigation.request.url.toString();
                  if (!url.contains('samen1.nl')) {
                    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                    return NavigationActionPolicy.CANCEL;
                  }
                  return NavigationActionPolicy.ALLOW;
                },
              ),
            ),
            // Laadindicator zichtbaar zolang _isLoading true is
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }
}
