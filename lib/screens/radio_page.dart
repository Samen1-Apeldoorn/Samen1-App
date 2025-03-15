import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class RadioPage extends StatefulWidget {
  const RadioPage({super.key});

  @override
  State<RadioPage> createState() => _RadioPageState();
}

class _RadioPageState extends State<RadioPage> {
  bool _isLoading = true;  // Laadstatus bijhouden
  bool _isWebViewVisible = false;  // Website zichtbaarheid bijhouden

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // WebView - deze is verborgen totdat de pagina is geladen
          AnimatedOpacity(
            opacity: _isWebViewVisible ? 1.0 : 0.0,  // Webview zichtbaar maken zodra geladen
            duration: const Duration(milliseconds: 500),
            child: InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri('https://samen1.nl/radio/')),
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

                  var headergay = document.getElementById('anchornav')
                  if(headergay){
                    headergay.style.top = 0
                  }
                ''');

                // Stop de laadindicator als de pagina geladen is
                setState(() {
                  _isLoading = false;  // Stop loading
                  _isWebViewVisible = true;  // Maak de webpagina zichtbaar
                });
              },
              onWebViewCreated: (controller) {
                // Eventueel een JavaScript handler toevoegen (indien nodig voor extra acties)
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
