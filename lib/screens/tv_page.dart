import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';

class TVPage extends StatefulWidget {
  const TVPage({super.key});

  @override
  State<TVPage> createState() => _TVPageState();
}

class _TVPageState extends State<TVPage> {
  bool _isError = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TV'),
        backgroundColor: const Color(0xFFFA6401),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: _isError
                ? Center(
                    child: ElevatedButton(
                      onPressed: () => launchUrl(
                        Uri.parse('https://www.twitch.tv/samen1_events'),
                        mode: LaunchMode.externalApplication,
                      ),
                      child: const Text('Kijk op Twitch'),
                    ),
                  )
                : InAppWebView(
                    initialData: InAppWebViewInitialData(data: '''
                      <html>
                        <body style="margin:0">
                          <video style="width:100%;height:100%" controls autoplay>
                            <source src="https://server-67.stream-server.nl:2000/VideoPlayer/Samen1TV" type="video/mp4">
                          </video>
                        </body>
                      </html>
                    '''),
                    onReceivedError: (controller, request, error) {
                      setState(() => _isError = true);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
