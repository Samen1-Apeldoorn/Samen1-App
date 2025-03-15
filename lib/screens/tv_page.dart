import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

/// Scherm voor het afspelen van de Samen1 TV livestream.
/// Deze pagina gebruikt een native video player om de HLS stream af te spelen.
class TVPage extends StatefulWidget {
  const TVPage({super.key});

  @override
  State<TVPage> createState() => _TVPageState();
}

class _TVPageState extends State<TVPage> {
  // Controller voor de video player
  late VideoPlayerController _controller;
  
  // Status variabelen
  bool _isError = false;
  bool _isLoading = true;
  bool _showDebugInfo = false;
  bool _isFullScreen = false;
  bool _isExitingFullScreen = false;
  
  // De constante URL naar de HLS stream
  static const String _hlsStreamUrl = 
      'https://server-67.stream-server.nl:1936/Samen1TV/Samen1TV/playlist.m3u8';

  @override
  void initState() {
    super.initState();
    // Start direct met het initialiseren van de video player
    _initializeVideoPlayer();
  }

  /// Initialiseert de video player met de HLS stream
  void _initializeVideoPlayer() {
    setState(() {
      _isLoading = true;
      _isError = false;
    });

    // Maak een nieuwe video controller met de HLS stream URL
    _controller = VideoPlayerController.networkUrl(
      Uri.parse(_hlsStreamUrl),
      // User-Agent header kan helpen bij toegang tot de stream
      httpHeaders: {'User-Agent': 'Samen1TV-App'},
      // Geef aan dat het een HLS stream is
      formatHint: VideoFormat.hls,
    )
      // Initialiseer de controller en start het afspelen
      ..initialize().then((_) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _controller.play();
          });
        }
      }).catchError((error) {
        print("Fout bij het initialiseren van de stream: $error");
        if (mounted) {
          setState(() {
            _isError = true;
            _isLoading = false;
          });
        }
      })
      // Luister naar eventuele fouten tijdens het afspelen
      ..addListener(() {
        if (_controller.value.hasError && mounted && !_isError) {
          print("Video player fout: ${_controller.value.errorDescription}");
          setState(() => _isError = true);
        }
      });
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
    // Reset de oriëntatie voorkeuren bij het afsluiten
    SystemChrome.setPreferredOrientations([]);
    // Zorg dat alle UI overlays weer zichtbaar zijn bij het afsluiten van het scherm
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    
    // Belangrijk: ruim de controller netjes op
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Als we in fullscreen modus zijn, toon alleen de video
    if (_isFullScreen) {
      return WillPopScope(
        // Handel terug-knop af om fullscreen mode te verlaten
        onWillPop: () async {
          if (_isFullScreen) {
            _toggleFullScreen();
            return false;
          }
          return true;
        },
        // Gebruik geen Scaffold in fullscreen modus om alle UI elementen te vermijden
        child: Container(
          color: Colors.black,
          child: _buildFullScreenPlayer(),
        ),
      );
    }
    
    // Normale weergave met AppBar
    return Scaffold(
      body: OrientationBuilder(
        builder: (context, orientation) {
          // Alleen reageren op oriëntatie als we niet bezig zijn met de transitie
          if (orientation == Orientation.landscape && !_isFullScreen && !_isExitingFullScreen) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && !_isFullScreen && !_isExitingFullScreen) {
                _toggleFullScreen();
              }
            });
          }
          
          // Centreer de video verticaal in het scherm
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
    return Stack(
      children: [
        // Gebruik Center en AspectRatio voor het centreren van de video
        Center(
          child: Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.black,
            child: _controller.value.isInitialized
                ? FittedBox(
                    fit: BoxFit.contain, // Behoud aspect ratio maar vul zo veel mogelijk ruimte
                    child: SizedBox(
                      width: _controller.value.size.width,
                      height: _controller.value.size.height,
                      child: VideoPlayer(_controller),
                    ),
                  )
                : const Center(child: CircularProgressIndicator()),
          ),
        ),
        
        // Video bedieningselementen
        _VideoControls(
          controller: _controller,
          onToggleFullScreen: _toggleFullScreen,
          isFullScreen: true,
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
                if (_controller.value.isInitialized) {
                  _controller.dispose();
                }
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
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _isPlaying) {
        setState(() => _showControls = false);
      }
    });
  }

  /// Update de lokale status wanneer de controller verandert
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
        // Toon of verberg de besturingselementen bij tik
        setState(() => _showControls = !_showControls);
        
        // Start de timer om te verbergen als ze net zichtbaar zijn geworden
        if (_showControls && _isPlaying) {
          _startHideTimer();
        }
      },
      behavior: HitTestBehavior.opaque, // Verzeker dat de tap altijd wordt geregistreerd
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
                  _isPlaying ? widget.controller.pause() : widget.controller.play();
                },
              ),
              
              // Volledig scherm knop
              IconButton(
                icon: Icon(widget.isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen),
                color: Colors.white,
                iconSize: 32,
                onPressed: widget.onToggleFullScreen,
                tooltip: widget.isFullScreen ? 'Verlaat volledig scherm' : 'Volledig scherm',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
