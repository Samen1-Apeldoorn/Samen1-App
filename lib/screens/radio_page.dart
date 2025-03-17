import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../services/log_service.dart';

class RadioPage extends StatefulWidget {
  const RadioPage({super.key});

  @override
  State<RadioPage> createState() => _RadioPageState();
}

class _RadioPageState extends State<RadioPage> {
  bool _isLoading = true;
  bool _isWebViewVisible = false;
  InAppWebViewController? _webViewController;
  
  static const String _radioUrl = 'https://samen1.nl/radio/';

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    LogService.log('Radio page opened', category: 'radio');
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    LogService.log('Radio page closed', category: 'radio');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _handleBackPress,
      child: Scaffold(
        body: Stack(
          children: [
            AnimatedOpacity(
              opacity: _isWebViewVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 500),
              child: InAppWebView(
                initialUrlRequest: URLRequest(url: WebUri(_radioUrl)),
                onWebViewCreated: (controller) {
                  _webViewController = controller;
                  LogService.log('Radio WebView created', category: 'radio');
                },
                onLoadStart: (controller, url) async {
                  LogService.log('Loading radio content: ${url.toString()}', category: 'radio');
                  setState(() => _isLoading = true);
                  
                  // Auto-play radio when possible
                  await _attemptAutoPlay(controller);
                },
                onLoadStop: (controller, url) async {
                  await _injectCSS(controller, url.toString());
                  LogService.log('Radio content loaded', category: 'radio');
                  
                  setState(() {
                    _isLoading = false;
                    _isWebViewVisible = true;
                  });
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

  Future<bool> _handleBackPress() async {
    if (await _webViewController?.canGoBack() ?? false) {
      _webViewController?.goBack();
      LogService.log('Navigating back in WebView', category: 'radio');
      return false;
    }
    return true;
  }

  Future<void> _attemptAutoPlay(InAppWebViewController controller) async {
    try {
      await controller.evaluateJavascript(source: '''
        setTimeout(function() {
          const playButton = document.querySelector('.play-button');
          if (playButton) {
            playButton.click();
            console.log('Auto-play initiated');
          }
        }, 1500);
      ''');
      LogService.log('Auto-play script injected', category: 'radio');
    } catch (e) {
      LogService.log('Error injecting auto-play: $e', category: 'radio_error');
    }
  }

  Future<void> _injectCSS(InAppWebViewController controller, String url) async {
    try {
      String cssCode = '''
        footer, .site-header, .site-footer, #mobilebar { display: none !important; }
        body { padding-top: 0 !important; }
        #top { padding-top: 1rem; }
        #anchornav { top: 0; padding-top: 3rem }
      ''';
      
      // Add special handling for the main radio page
      if (url == _radioUrl) {
        cssCode += '''
          .page-title { display: none !important; }
        ''';
      }
      
      await controller.injectCSSCode(source: cssCode);
      LogService.log('CSS injected for radio page', category: 'radio');
    } catch (e) {
      LogService.log('Error injecting CSS: $e', category: 'radio_error');
    }
  }
}
