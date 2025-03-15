import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class TVPage extends StatefulWidget {
  const TVPage({super.key});

  @override
  State<TVPage> createState() => _TVPageState();
}

class _TVPageState extends State<TVPage> {
  late VideoPlayerController _controller;
  bool _isError = false;
  bool _isLoading = true;
  
  // List of stream URLs to try in order of preference
  final List<String> _streamUrls = [
    'https://server-67.stream-server.nl:1936/Samen1TV/Samen1TV/playlist.m3u8', // HLS stream
    'https://server-67.stream-server.nl:2000/tunein/Samen1TV/v/m3u8', // VLC stream
    'rtsp://server-67.stream-server.nl/Samen1TV/Samen1TV', // RTSP stream
  ];
  
  int _currentStreamIndex = 0;

  @override
  void initState() {
    super.initState();
    _initializeVideoPlayer();
  }

  void _initializeVideoPlayer() {
    setState(() {
      _isLoading = true;
      _isError = false;
    });

    if (_currentStreamIndex >= _streamUrls.length) {
      setState(() {
        _isError = true;
        _isLoading = false;
      });
      return;
    }

    final streamUrl = _streamUrls[_currentStreamIndex];
    
    _controller = VideoPlayerController.networkUrl(
      Uri.parse(streamUrl),
      httpHeaders: {'User-Agent': 'Samen1TV-App'},
      formatHint: VideoFormat.hls, // Set the format hint for HLS streams
    )
      ..initialize().then((_) {
        // Ensure the first frame is shown and play video
        if (mounted) {
          setState(() {
            _isLoading = false;
            _controller.play();
          });
        }
      }).catchError((error) {
        print("Failed to initialize player: $error");
        // Try the next stream URL if this one fails
        _currentStreamIndex++;
        _controller.dispose();
        _initializeVideoPlayer();
      })
      ..addListener(() {
        if (_controller.value.hasError) {
          print("Video player error: ${_controller.value.errorDescription}");
          if (mounted && !_isError) {
            setState(() => _isError = true);
          }
        }
      });
  }

  void _retryWithNextStream() {
    _currentStreamIndex++;
    if (_controller.value.isInitialized) {
      _controller.dispose();
    }
    _initializeVideoPlayer();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Kon de video niet laden',
                          style: TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () {
                            // Try again with current stream
                            setState(() => _isError = false);
                            if (_controller.value.isInitialized) {
                              _controller.dispose();
                            }
                            _initializeVideoPlayer();
                          },
                          child: const Text('Probeer opnieuw'),
                        ),
                        const SizedBox(height: 8),
                        if (_currentStreamIndex < _streamUrls.length - 1)
                          TextButton(
                            onPressed: _retryWithNextStream,
                            child: const Text('Probeer alternatieve stream'),
                          ),
                      ],
                    ),
                  )
                : _isLoading
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Stream laden...'),
                          ],
                        ),
                      )
                    : _controller.value.isInitialized
                        ? Stack(
                            alignment: Alignment.bottomCenter,
                            children: [
                              VideoPlayer(_controller),
                              VideoProgressIndicator(
                                _controller,
                                allowScrubbing: true,
                                padding: const EdgeInsets.all(8),
                              ),
                              _VideoControls(controller: _controller),
                            ],
                          )
                        : const Center(child: CircularProgressIndicator()),
          ),
        ],
      ),
    );
  }
}

class _VideoControls extends StatefulWidget {
  final VideoPlayerController controller;

  const _VideoControls({required this.controller});

  @override
  State<_VideoControls> createState() => _VideoControlsState();
}

class _VideoControlsState extends State<_VideoControls> {
  bool _showControls = true;
  late bool _isPlaying;

  @override
  void initState() {
    super.initState();
    _isPlaying = widget.controller.value.isPlaying;
    widget.controller.addListener(_updateState);
    
    // Auto-hide controls after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _isPlaying) {
        setState(() => _showControls = false);
      }
    });
  }

  void _updateState() {
    if (mounted) {
      setState(() {
        _isPlaying = widget.controller.value.isPlaying;
      });
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_updateState);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() => _showControls = !_showControls);
        
        // Auto-hide controls after 3 seconds if playing
        if (_showControls && _isPlaying) {
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted && _isPlaying) {
              setState(() => _showControls = false);
            }
          });
        }
      },
      child: AnimatedOpacity(
        opacity: _showControls ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: Container(
          color: Colors.black26,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                color: Colors.white,
                iconSize: 32,
                onPressed: () {
                  _isPlaying ? widget.controller.pause() : widget.controller.play();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
