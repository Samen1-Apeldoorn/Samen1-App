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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(  // Hier beginnen we de lijst van widgets
        children: <Widget>[  // Zorg ervoor dat we een lijst van widgets doorgeven
          // WebView - deze is verborgen totdat de pagina is geladen
          AnimatedOpacity(
            opacity: _isWebViewVisible ? 1.0 : 0.0,  // Webview zichtbaar maken zodra geladen
            duration: const Duration(milliseconds: 500),
            child: InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri('https://samen1.nl/nieuws/')),
              onLoadStart: (controller, url) {
                setState(() {
                  _isLoading = true;  // Start loading indicator
                });
              },
              onLoadStop: (controller, url) async {
                // Eerst de JavaScript-code uitvoeren voordat we de webview zichtbaar maken
                await controller.evaluateJavascript(source: '''
                  document.querySelector('.play-button')?.click();

                  var navbar = document.getElementById('mobilebar');
                  if(navbar){
                    navbar.remove();
                  }

                  var header = document.getElementsByClassName('page-title')[0];
                  if(header){
                    header.remove();
                  }

                  var headerContainer = document.getElementById('top');
                  if(headerContainer){
                    headerContainer.style.paddingTop = 0;
                  }
                ''');

                // Injecteer CSS om elementen te verbergen
                await controller.injectCSSCode(source: '''
                  footer, .site-header, .site-footer { display: none !important; }
                  body { padding-top: 0 !important; }
                ''');

                // Stop de laadindicator als de pagina geladen is
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
    );
  }
}
