import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';

class NewsPage extends StatelessWidget {
  const NewsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nieuws'),
        backgroundColor: const Color(0xFFFA6401),
        foregroundColor: Colors.white,
      ),
      body: InAppWebView(
        initialUrlRequest: URLRequest(url: WebUri('https://samen1.nl/nieuws/')),
        onLoadStop: (controller, url) {
          controller.injectCSSCode(source: '''
            header, footer, .site-header, .site-footer { display: none !important; }
            body { padding-top: 0 !important; }
          ''');
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
    );
  }
}
