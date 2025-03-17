import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'dart:async'; // Add for better async handling

/// Scherm voor het afspelen van de Samen1 TV livestream.
/// Deze pagina gebruikt een native video player om de HLS stream af te spelen.
class TVPage extends StatefulWidget {
  const TVPage({super.key});

  @override
  State<TVPage> createState() => _TVPageState();
}

class _TVPageState extends State<TVPage> with WidgetsBindingObserver {
  // Controller voor de video player
  late VideoPlayerController _controller;
  
  // Status variabelen
  bool _isError = false;
  bool _isLoading = true;
  final bool _showDebugInfo = false;
  bool _isFullScreen = false;
  bool _isExitingFullScreen = false;
  Timer? _initRetryTimer;
  int _retryCount = 0;
  static const int _maxRetryCount = 3;
  
  // De constante URL naar de HLS stream
  static const String _hlsStreamUrl = 
      'https://server-67.stream-server.nl:1936/Samen1TV/Samen1TV/playlist.m3u8';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // Add lifecycle observer
    
    // Delay initialization slightly to improve UI responsiveness
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _initializeVideoPlayer();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Optimize resource usage when app goes to background
    if (state == AppLifecycleState.paused) {
      _controller.pause();
    } else if (state == AppLifecycleState.resumed) {
      // Check if player is in good state before resuming
      if (_controller.value.isInitialized && !_isError) {
        _controller.play();
      } else {
        // Reinitialize if needed
        _disposeAndRecreatePlayer();
      }
    }
  }

  /// Initialiseert de video player met de HLS stream
  Future<void> _initializeVideoPlayer() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _isError = false;
    });

    // Cancel any pending retry timer
    _initRetryTimer?.cancel();

    try {
      // Maak een nieuwe video controller met de HLS stream URL
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
      
      // Use a timeout to avoid hanging initialization
      await _controller.initialize().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException('Video initialization timed out');
        },
      );
      
      // Only proceed if still mounted after async operation
      if (mounted) {
        setState(() {
          _isLoading = false;
          _retryCount = 0; // Reset retry count on success
        });
        
        _controller.addListener(_onVideoStatusChanged);
        _controller.setLooping(true);
        await _controller.play();
      }
    } catch (error) {
      if (mounted) {
        // If there's an initialization error, try to recover
        _handleInitializationError();
      }
    }
  }
  
  void _handleInitializationError() {
    // Clean up the failed controller
    if (_controller.value.isInitialized) {
      _controller.removeListener(_onVideoStatusChanged);
      _controller.dispose();
    }

    if (_retryCount < _maxRetryCount) {
      // Incremental backoff for retries
      final retryDelay = Duration(seconds: (_retryCount + 1) * 2);
      _retryCount++;
      
      setState(() {
        _isLoading = true;
        _isError = false;
      });
      
      // Retry initialization after delay
      _initRetryTimer = Timer(retryDelay, _initializeVideoPlayer);
    } else {
      // After max retries, show error state
      setState(() {
        _isError = true;
        _isLoading = false;
      });
    }
  }
  
  void _onVideoStatusChanged() {
    // Handle error state changes
    final hasError = _controller.value.hasError;
    
    if (hasError && mounted && !_isError) {
      setState(() => _isError = true);
    }
    
    // Handle video size changes for better layout
    if (_controller.value.isInitialized && mounted) {
      // Force rebuild if video size changed significantly
      setState(() {});
    }
  }
  
  // Clean method to dispose and recreate player
  void _disposeAndRecreatePlayer() {
    _controller.removeListener(_onVideoStatusChanged);
    _controller.dispose();
    _initializeVideoPlayer();
  }

  /// Schakelt tussen normaal en volledig scherm
  void _toggleFullScreen() async {
    // Als we al bezig zijn met de transitie, doe niets
    if (_isExitingFullScreen) return;
    
    final wasFullScreen = _isFullScreen;
    
    setState(() {
      _isFullScreen = !_isFullScreen;
      
      if (_isFullScreen) {
        // Volledig scherm (landschap) modus
        SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.immersiveSticky,
          overlays: [], // Verberg alle overlays
        );
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      } else {
        // Exit fullscreen - markeer dat we bezig zijn met de transitie
        _isExitingFullScreen = true;
        
        // Reset UI overlays
        SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.manual,
          overlays: SystemUiOverlay.values, // Toon alle overlays weer
        );
        
        // Zet oriëntatie terug naar portrait
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
        ]);
      }
    });
    
    // Als we uit fullscreen gaan, wacht tot de oriëntatie is bijgewerkt
    if (wasFullScreen) {
      // Wacht even om de overgang te laten voltooien
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (mounted) {
        setState(() {
          _isExitingFullScreen = false;
        });
      }
    }
  }

  @override
  void dispose() {
    // Clean up resources
    _initRetryTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    
    if (_controller.value.isInitialized) {
      _controller.removeListener(_onVideoStatusChanged);
      _controller.dispose();
    }
    
    // Reset orientation preferences when exiting
    SystemChrome.setPreferredOrientations([]);
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Optimize UI overlay setting - only set once per build
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ));
    
    // Return optimized fullscreen or normal layout
    return _isFullScreen 
        ? _buildFullscreenLayout()
        : _buildNormalLayout();
  }
  
  Widget _buildFullscreenLayout() {
    return WillPopScope(
      onWillPop: () async {
        if (_isFullScreen) {
          _toggleFullScreen();
          return false;
        }
        return true;
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
          // Only respond to orientation if not in transition
          if (orientation == Orientation.landscape && 
              !_isFullScreen && 
              !_isExitingFullScreen) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && !_isFullScreen && !_isExitingFullScreen) {
                _toggleFullScreen();
              }
            });
          }
          
          // Simplified layout with error boundary
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

  /// Bouwt een volledig-scherm-vullende videoplayer
  Widget _buildFullScreenPlayer() {
    if (!_controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    
    // More efficient widget structure
    return Stack(
      children: [
        // Optimized video display
        Center(
          child: _controller.value.isInitialized
              ? AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  child: VideoPlayer(_controller),
                )
              : const SizedBox.shrink(),
        ),
        
        // Video controls
        _VideoControls(
          controller: _controller,
          onToggleFullScreen: _toggleFullScreen,
          isFullScreen: true,
        ),
        
        // Debug overlay
        if (_showDebugInfo)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.all(4),
              color: Colors.black54,
              child: const Text(
                'HLS Stream (Fullscreen)',
                style: TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),
          ),
      ],
    );
  }

  /// Bouwt de juiste widget op basis van de huidige status (fout, laden, afspelen)
  Widget _buildVideoContent() {
    // Toon foutmelding als er een fout is opgetreden
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
              onPressed: () {
                // Probeer opnieuw te laden
                _controller.dispose();
                _initializeVideoPlayer();
              },
              child: const Text('Probeer opnieuw'),
            ),
          ],
        ),
      );
    }
    
    // Toon laad-indicator tijdens het initialiseren
    if (_isLoading) {
      return const Center( // Added const keyword here
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
    
    // Toon de video player als deze is geïnitialiseerd
    if (_controller.value.isInitialized) {
      return _buildVideoPlayer();
    }
    
    // Fallback - zou niet moeten gebeuren
    return const Center(child: CircularProgressIndicator());
  }
  
  /// Bouwt de normale video player widget met besturingselementen
  Widget _buildVideoPlayer() {
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        // De video player zelf
        VideoPlayer(_controller),
        
        // Video controls (afspelen/pauzeren en volledig scherm)
        _VideoControls(
          controller: _controller,
          onToggleFullScreen: _toggleFullScreen,
          isFullScreen: _isFullScreen,
        ),
        
        // Debug overlay (indien ingeschakeld)
        if (_showDebugInfo)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.all(4),
              color: Colors.black54,
              child: const Text(
                'HLS Stream',
                style: TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),
          ),
      ],
    );
  }
}

/// Widget voor de video besturingselementen (afspelen/pauzeren en volledig scherm)
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
  // Bepaalt of de besturingselementen zichtbaar zijn
  bool _showControls = true;
  late bool _isPlaying;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _isPlaying = widget.controller.value.isPlaying;
    
    // Luister naar status veranderingen van de controller
    widget.controller.addListener(_updateState);
    
    // Verberg de besturingselementen automatisch na 3 seconden
    _startHideTimer();
  }

  /// Start een timer om de besturingselementen na 3 seconden te verbergen
  void _startHideTimer() {
    // Cancel any existing timer first
    _hideTimer?.cancel();
    
    // Set a new timer
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _isPlaying) {
        setState(() => _showControls = false);
      }
    });
  }
  
  /// Explicitly show the controls and restart the hide timer
  void _showControlsWithTimer() {
    if (mounted) {
      setState(() => _showControls = true);
      _startHideTimer();
    }
  }

  /// Update de lokale status wanneer de controller verandert
  void _updateState() {
    if (mounted) {
      final wasPlaying = _isPlaying;
      _isPlaying = widget.controller.value.isPlaying;
      
      // If playback state changed, update the controls visibility
      if (wasPlaying != _isPlaying) {
        if (_isPlaying) {
          // If we just started playing, start the auto-hide timer
          _startHideTimer();
        } else {
          // If we just paused, make controls visible and cancel hide timer
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
        // Invisible tap detector covering the entire video area
        Positioned.fill(
          child: GestureDetector(
            onTap: _showControlsWithTimer,
            behavior: HitTestBehavior.opaque,
            child: const SizedBox.expand(),
          ),
        ),
        
        // The actual controls that fade in/out
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
                  // Afspeel/pauseer knop
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
                  
                  // Volledig scherm knop
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
