import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'dart:async';
import '../../services/log_service.dart';
import 'tv_visible_notifier.dart';

class TVPage extends StatefulWidget {
  const TVPage({super.key});

  @override
  State<TVPage> createState() => _TVPageState();
}

class _TVPageState extends State<TVPage> with WidgetsBindingObserver {
  late VideoPlayerController _controller;
  final _visibilityNotifier = TVVisibleNotifier();
  
  // Status variables
  bool _isError = false;
  bool _isLoading = true;
  bool _isFullScreen = false;
  bool _isExitingFullScreen = false;
  Timer? _initRetryTimer;
  int _retryCount = 0;
  static const int _maxRetryCount = 3;
  
  // HLS stream URL
  static const String _hlsStreamUrl = 
      'https://server-67.stream-server.nl:1936/Samen1TV/Samen1TV/playlist.m3u8';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    LogService.log('TV Page initialized', category: 'tv');
    
    // Listen to visibility changes
    _visibilityNotifier.addListener(_onVisibilityChanged);
  }

  void _onVisibilityChanged() {
    if (_visibilityNotifier.value) {
      LogService.log('TV tab became visible', category: 'tv');
      if (!_controller.value.isInitialized) {
        // Delay initialization slightly to improve UI responsiveness
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted && _visibilityNotifier.value) _initializeVideoPlayer();
        });
      }
    } else {
      LogService.log('TV tab became invisible', category: 'tv');
      if (_controller.value.isInitialized) {
        _controller.pause();
        if (_controller.value.isInitialized) {
          _controller.removeListener(_onVideoStatusChanged);
          _controller.dispose();
        }
        _initRetryTimer?.cancel();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_visibilityNotifier.value) return; // Only handle lifecycle if tab is visible
    
    if (state == AppLifecycleState.paused) {
      _controller.pause();
      LogService.log('TV stream paused due to app lifecycle change', category: 'tv');
    } else if (state == AppLifecycleState.resumed) {
      if (_controller.value.isInitialized && !_isError) {
        _controller.play();
        LogService.log('TV stream resumed', category: 'tv');
      } else {
        _disposeAndRecreatePlayer();
        LogService.log('TV stream recreated after resume', category: 'tv');
      }
    }
  }

  Future<void> _initializeVideoPlayer() async {
    if (!mounted || !_visibilityNotifier.value) return;
    
    setState(() {
      _isLoading = true;
      _isError = false;
    });

    _initRetryTimer?.cancel();
    LogService.log('Initializing TV stream player', category: 'tv');

    try {
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(_hlsStreamUrl),
        httpHeaders: {
          'User-Agent': 'Samen1TV-App/1.0',
          'Connection': 'keep-alive',
        },
        formatHint: VideoFormat.hls,
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: false,
          allowBackgroundPlayback: false,
        ),
      );
      
      await _controller.initialize().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException('Video initialization timed out');
        },
      );
      
      if (mounted && _visibilityNotifier.value) {
        setState(() {
          _isLoading = false;
          _retryCount = 0;
        });
        
        _controller.addListener(_onVideoStatusChanged);
        _controller.setLooping(true);
        await _controller.play();
        LogService.log('TV stream player initialized successfully', category: 'tv');
      } else {
        _disposeController();
      }
    } catch (error) {
      LogService.log('Error initializing TV stream: $error', category: 'tv_error');
      if (mounted && _visibilityNotifier.value) {
        _handleInitializationError();
      }
    }
  }
  
  void _handleInitializationError() {
    if (_controller.value.isInitialized) {
      _controller.removeListener(_onVideoStatusChanged);
      _controller.dispose();
    }

    if (_retryCount < _maxRetryCount && _visibilityNotifier.value) {
      final retryDelay = Duration(seconds: (_retryCount + 1) * 2);
      _retryCount++;
      
      setState(() {
        _isLoading = true;
        _isError = false;
      });
      
      LogService.log('Retrying TV stream initialization (attempt $_retryCount)', category: 'tv');
      _initRetryTimer = Timer(retryDelay, _initializeVideoPlayer);
    } else {
      setState(() {
        _isError = true;
        _isLoading = false;
      });
      LogService.log('Max retry attempts reached for TV stream', category: 'tv_error');
    }
  }

  void _onVideoStatusChanged() {
    final hasError = _controller.value.hasError;
    
    if (hasError && mounted && !_isError) {
      LogService.log('Video player reported error', category: 'tv_error');
      setState(() => _isError = true);
    }
    
    if (_controller.value.isInitialized && mounted) {
      setState(() {});
    }
  }
  
  void _disposeAndRecreatePlayer() {
    _controller.removeListener(_onVideoStatusChanged);
    _controller.dispose();
    _initializeVideoPlayer();
  }

  void _toggleFullScreen() async {
    if (_isExitingFullScreen) return;
    
    final wasFullScreen = _isFullScreen;
    
    setState(() {
      _isFullScreen = !_isFullScreen;
      
      if (_isFullScreen) {
        LogService.log('Entering fullscreen mode', category: 'tv');
        SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.immersiveSticky,
          overlays: [],
        );
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      } else {
        _isExitingFullScreen = true;
        LogService.log('Exiting fullscreen mode', category: 'tv');
        
        SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.manual,
          overlays: SystemUiOverlay.values,
        );
        
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
        ]);
      }
    });
    
    if (wasFullScreen) {
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (mounted) {
        setState(() {
          _isExitingFullScreen = false;
        });
      }
    }
  }

  void _disposeController() {
    if (_controller.value.isInitialized) {
      _controller.removeListener(_onVideoStatusChanged);
      _controller.dispose();
    }
    _initRetryTimer?.cancel();
  }

  @override
  void dispose() {
    _initRetryTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _visibilityNotifier.removeListener(_onVisibilityChanged);
    _disposeController();
    
    SystemChrome.setPreferredOrientations([]);
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    
    LogService.log('TV Page disposed', category: 'tv');
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
    
    return _isFullScreen 
        ? _buildFullscreenLayout()
        : _buildNormalLayout();
  }
  
  Widget _buildFullscreenLayout() {
    return PopScope(
      canPop: !_isFullScreen,
      onPopInvokedWithResult: (didPop, result) {
        if (_isFullScreen && !didPop) {
          _toggleFullScreen();
        }
      },
      child: ColoredBox(
        color: Colors.black,
        child: _buildFullScreenPlayer(),
      ),
    );
  }
  
  Widget _buildNormalLayout() {
    return Scaffold(
      body: OrientationBuilder(
        builder: (context, orientation) {
          if (orientation == Orientation.landscape && 
              !_isFullScreen && 
              !_isExitingFullScreen) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && !_isFullScreen && !_isExitingFullScreen) {
                _toggleFullScreen();
              }
            });
          }
          
          return Center(
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: _buildVideoContent(),
            ),
          );
        }
      ),
    );
  }

  Widget _buildFullScreenPlayer() {
    return Stack(
      children: [
        Center(
          child: _controller.value.isInitialized
              ? AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  child: VideoPlayer(_controller),
                )
              : const SizedBox.shrink(),
        ),
        
        _VideoControls(
          controller: _controller,
          onToggleFullScreen: _toggleFullScreen,
          isFullScreen: true,
        ),
      ],
    );
  }

  Widget _buildVideoContent() {
    if (_isError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Kon de video niet laden',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => _disposeAndRecreatePlayer(),
              child: const Text('Probeer opnieuw'),
            ),
          ],
        ),
      );
    }
    
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Stream laden...'),
          ],
        ),
      );
    }
    
    if (_controller.value.isInitialized) {
      return _buildVideoPlayer();
    }
    
    return const Center(child: CircularProgressIndicator());
  }
  
  Widget _buildVideoPlayer() {
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        VideoPlayer(_controller),
        
        _VideoControls(
          controller: _controller,
          onToggleFullScreen: _toggleFullScreen,
          isFullScreen: _isFullScreen,
        ),
      ],
    );
  }
}

class _VideoControls extends StatefulWidget {
  final VideoPlayerController controller;
  final VoidCallback onToggleFullScreen;
  final bool isFullScreen;

  const _VideoControls({
    required this.controller, 
    required this.onToggleFullScreen,
    required this.isFullScreen,
  });

  @override
  State<_VideoControls> createState() => _VideoControlsState();
}

class _VideoControlsState extends State<_VideoControls> {
  bool _showControls = true;
  late bool _isPlaying;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _isPlaying = widget.controller.value.isPlaying;
    widget.controller.addListener(_updateState);
    _startHideTimer();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _isPlaying) {
        setState(() => _showControls = false);
      }
    });
  }
  
  void _showControlsWithTimer() {
    if (mounted) {
      setState(() => _showControls = true);
      _startHideTimer();
    }
  }

  void _updateState() {
    if (mounted) {
      final wasPlaying = _isPlaying;
      _isPlaying = widget.controller.value.isPlaying;
      
      if (wasPlaying != _isPlaying) {
        if (_isPlaying) {
          _startHideTimer();
        } else {
          _hideTimer?.cancel();
          setState(() => _showControls = true);
        }
      }
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    widget.controller.removeListener(_updateState);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: _showControlsWithTimer,
            behavior: HitTestBehavior.opaque,
            child: const SizedBox.expand(),
          ),
        ),
        
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: AnimatedOpacity(
            opacity: _showControls ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: Container(
              color: Colors.black26,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                    color: Colors.white,
                    iconSize: 32,
                    onPressed: () {
                      if (_isPlaying) {
                        widget.controller.pause();
                      } else {
                        widget.controller.play();
                        _startHideTimer();
                      }
                    },
                  ),
                  
                  IconButton(
                    icon: Icon(widget.isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen),
                    color: Colors.white,
                    iconSize: 32,
                    onPressed: () {
                      widget.onToggleFullScreen();
                      _showControlsWithTimer();
                    },
                    tooltip: widget.isFullScreen ? 'Verlaat volledig scherm' : 'Volledig scherm',
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
