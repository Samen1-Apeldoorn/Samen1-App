import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';

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
                  });
                },
                onLoadStop: (controller, url) async {
                  await controller.evaluateJavascript(source: '''
                    document.querySelector('.play-button')?.click();
                    var navbar = document.getElementById('mobilebar');
                    if(navbar) navbar.remove();
                    var header = document.getElementsByClassName('page-title')[0];
                    if(header) header.remove();
                    var headerContainer = document.getElementById('top');
                    if(headerContainer) headerContainer.style.paddingTop = 0;
                  ''');

                  await controller.injectCSSCode(source: '''
                    footer, .site-header, .site-footer { display: none !important; }
                    body { padding-top: 0 !important; }
                  ''');

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
            if (_isLoading)  // Laadindicator zichtbaar zolang _isLoading true is
              const Center(
                child: CircularProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }
}
