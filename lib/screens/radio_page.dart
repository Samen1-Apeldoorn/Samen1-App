import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class RadioPage extends StatefulWidget {
  const RadioPage({super.key});

  @override
  State<RadioPage> createState() => _RadioPageState();
}

class _RadioPageState extends State<RadioPage> {
  bool _isLoading = true;
  bool _isWebViewVisible = false;
  InAppWebViewController? _webViewController;

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
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ));

    return WillPopScope(
      onWillPop: () async {
        if (await _webViewController?.canGoBack() ?? false) {
          _webViewController?.goBack();
          return false;
        }
        return true;
      },
      child: Scaffold(
        body: Stack(
          children: <Widget>[
            AnimatedOpacity(
              opacity: _isWebViewVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 500),
              child: InAppWebView(
                initialUrlRequest: URLRequest(url: WebUri('https://samen1.nl/radio/')),
                onWebViewCreated: (controller) {
                  _webViewController = controller;
                },
                onLoadStart: (controller, url) async {
                  setState(() {
                    _isLoading = true;
                    _isWebViewVisible = false;
                  });

                  // Injecteer CSS bij het laden van de pagina
                  if (url.toString() == "https://samen1.nl/radio/") {
                    await controller.injectCSSCode(source: '''
                      footer, .site-header, .site-footer, #mobilebar, .page-title { display: none !important; }
                      body { padding-top: 0 !important; }
                      #top { padding-top: 1rem; }
                      #anchornav { top: 0; padding-top: 3rem }
                    ''');
                  } else {
                    await controller.injectCSSCode(source: '''
                      footer, .site-header, .site-footer, #mobilebar { display: none !important; }
                      body { padding-top: 0 !important; }
                      #top { padding-top: 1rem; }
                      #anchornav { top: 0; padding-top: 3rem }
                    ''');
                  }
                },
                onLoadStop: (controller, url) async {
                  setState(() {
                    _isLoading = false;
                    _isWebViewVisible = true;
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
            if (_isLoading)
              const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }
}
