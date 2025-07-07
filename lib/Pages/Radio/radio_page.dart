import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../../services/log_service.dart';
import 'radio_service.dart';

class RadioPage extends StatefulWidget {
  const RadioPage({super.key});

  @override
  State<RadioPage> createState() => _RadioPageState();
}

class _RadioPageState extends State<RadioPage> with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  // Use the singleton AudioService instead of creating a new AudioPlayer
  final AudioService _audioService = AudioService();
  
  // State variables with better organization
  bool _isLoading = true;
  bool _isPlaying = false;
  bool _isConnecting = false;
  String _errorMessage = '';
  bool _isPlayerInitialized = false;
  
  // Stream info variables
  String _currentTrack = '';
  String _currentArtist = 'Samen1 Radio';
  String _coverArtUrl = '';
  Timer? _streamInfoTimer;
  bool _isLoadingInfo = true;
  
  // Animation controllers for smooth UI transitions
  late AnimationController _playButtonController;
  late AnimationController _artworkController;
  late AnimationController _trackInfoController;
  
  // Connection retry logic
  int _retryCount = 0;
  static const int _maxRetries = 3;
  Timer? _retryTimer;

  static const String _radioInfoUrl = 'https://server-67.stream-server.nl:2000/json/stream/ValouweMediaStichting';
  static const String _radioStationName = 'Samen1 Radio';
  
  // Keep the widget alive to preserve radio state
  @override
  bool get wantKeepAlive => true;
  
  @override
  void initState() {
    super.initState();
    LogService.log('RadioPage: Initializing optimized page', category: 'radio');
    
    // Initialize animation controllers
    _playButtonController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _artworkController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _trackInfoController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    // Start artwork animation
    _artworkController.forward();
    
    // Enable wakelock
    _enableWakelock();
    
    // Initialize everything in parallel for faster startup
    _initializeEverything();
  }
  
  // Parallel initialization for better performance
  Future<void> _initializeEverything() async {
    final List<Future> futures = [
      _initializePlayer(),
      _preloadStreamInfo(),
    ];
    
    // Wait for both operations to complete
    await Future.wait(futures);
    
    if (_isPlayerInitialized && mounted) {
      _setupPlayerStateListener();
      _setupPeriodicStreamInfoUpdates();
      _trackInfoController.forward();
      
      // Fetch stream info immediately after setup
      _fetchStreamInfo(isInitialLoad: true);
    }
  }
  
  // Preload stream info to reduce initial loading time
  Future<void> _preloadStreamInfo() async {
    try {
      LogService.log('RadioPage: Preloading stream info', category: 'radio_optimization');
      await _fetchStreamInfo(isInitialLoad: true);
    } catch (e) {
      LogService.log('RadioPage: Failed to preload stream info: $e', category: 'radio_error');
    }
  }

  // Helper method for enabling wakelock with retry logic
  void _enableWakelock() {
    WakelockPlus.enable().then((_) {
      LogService.log('RadioPage: Wakelock enabled successfully', category: 'radio');
    }).catchError((error) {
      LogService.log('RadioPage: Failed to enable wakelock: $error', category: 'radio_error');
      // Retry after 2 seconds
      Timer(const Duration(seconds: 2), () {
        WakelockPlus.enable().catchError((e) {
          LogService.log('RadioPage: Wakelock retry failed: $e', category: 'radio_error');
        });
      });
    });
  }

  // Enhanced player state listener with better error handling
  void _setupPlayerStateListener() {
    _audioService.player.playerStateStream.listen((state) {
      if (!mounted) return;

      LogService.log(
        'RadioPage: Player state update - Playing: ${state.playing}, '
        'Processing: ${state.processingState}',
        category: 'radio_detail'
      );

      bool shouldUpdateState = false;
      bool newIsPlaying = _isPlaying;
      bool newIsConnecting = _isConnecting;

      // Handle different processing states
      switch (state.processingState) {
        case ProcessingState.loading:
        case ProcessingState.buffering:
          if (!newIsConnecting) {
            newIsConnecting = true;
            shouldUpdateState = true;
          }
          break;
        case ProcessingState.ready:
          if (newIsConnecting) {
            newIsConnecting = false;
            shouldUpdateState = true;
          }
          if (newIsPlaying != state.playing) {
            newIsPlaying = state.playing;
            shouldUpdateState = true;
            
            // Animate play button
            if (state.playing) {
              _playButtonController.forward();
            } else {
              _playButtonController.reverse();
            }
          }
          break;
        case ProcessingState.idle:
          if (_isPlayerInitialized && newIsPlaying) {
            newIsPlaying = false;
            newIsConnecting = false;
            shouldUpdateState = true;
            _playButtonController.reverse();
            LogService.log('RadioPage: Player became idle, setting UI to paused.', category: 'radio_warning');
          }
          break;
        case ProcessingState.completed:
          // Handle stream completion (shouldn't happen with live streams)
          break;
      }

      if (shouldUpdateState) {
        setState(() {
          _isPlaying = newIsPlaying;
          _isConnecting = newIsConnecting;
        });
      }
    }, onError: (error) {
      LogService.log('RadioPage: Player state stream error: $error', category: 'radio_error');
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _isConnecting = false;
        });
      }
    });
  }

  // Optimized periodic updates with adaptive interval
  void _setupPeriodicStreamInfoUpdates() {
    LogService.log('RadioPage: Setting up optimized periodic stream info updates', category: 'radio');
    _streamInfoTimer?.cancel();
    
    // Fetch stream info immediately first
    _fetchStreamInfo(isInitialLoad: false);
    
    // Use shorter interval when playing, longer when paused
    Duration interval = _isPlaying ? const Duration(seconds: 20) : const Duration(seconds: 60);
    
    _streamInfoTimer = Timer.periodic(interval, (_) { 
      if (_isPlayerInitialized && mounted) {
        LogService.log('RadioPage: Periodic stream info update triggered', category: 'radio_detail');
        _fetchStreamInfo();
        
        // Adjust interval based on playing state
        if (_isPlaying && _streamInfoTimer?.tick == 1) {
          _streamInfoTimer?.cancel();
          _setupPeriodicStreamInfoUpdates(); // Restart with correct interval
        }
      } else {
        LogService.log('RadioPage: Stopping periodic updates (player not ready or page disposed)', category: 'radio_detail');
        _streamInfoTimer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    LogService.log('RadioPage: Disposing optimized page', category: 'radio');
    
    // Cancel all timers
    _streamInfoTimer?.cancel();
    _retryTimer?.cancel();
    
    // Dispose animation controllers
    _playButtonController.dispose();
    _artworkController.dispose();
    _trackInfoController.dispose();
    
    // Disable wakelock
    WakelockPlus.disable().then((_) {
      LogService.log('RadioPage: Wakelock disabled successfully', category: 'radio');
    }).catchError((error) {
      LogService.log('RadioPage: Failed to disable wakelock: $error', category: 'radio_error');
    });
    
    LogService.log('RadioPage: Page closed, playback continues in background', category: 'radio');
    super.dispose();
  }

  // Enhanced stream info fetching with caching and error recovery
  Future<void> _fetchStreamInfo({bool isInitialLoad = false}) async {
    if (!_isPlayerInitialized) {
      LogService.log('RadioPage: Skipping fetchStreamInfo - player not initialized.', category: 'radio_warning');
      return;
    }
    
    final bool wasLoadingInfo = _isLoadingInfo;
    
    try {
      LogService.log('RadioPage: Fetching stream info from $_radioInfoUrl', category: 'radio_detail');
      
      // Use shorter timeout for initial load to get faster response
      final timeoutDuration = isInitialLoad ? const Duration(seconds: 5) : const Duration(seconds: 10);
      
      final response = await http.get(Uri.parse(_radioInfoUrl))
          .timeout(timeoutDuration);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final nowPlaying = data['nowplaying'] ?? 'Onbekend nummer';
        final coverArt = data['coverart'] ?? '';

        LogService.log(
          'RadioPage: Stream info fetched - Now Playing: "$nowPlaying"',
          category: 'radio'
        );

        // Process cover art URL
        String processedCoverUrl = _processCoverArtUrl(coverArt);
        
        // Parse artist and title
        String artist = _radioStationName;
        String title = nowPlaying;
        
        if (nowPlaying.contains(' - ')) {
          final parts = nowPlaying.split(' - ');
          if (parts.length >= 2) {
            artist = parts[0].trim();
            title = parts.sublist(1).join(' - ').trim();
          }
        }
        
        // Ensure we don't have empty titles
        if (title.isEmpty || title == 'Onbekend nummer') {
          title = _radioStationName;
        }

        // Check if info actually changed (with caching)
        final bool trackChanged = _currentTrack != title || _currentArtist != artist;
        final bool artChanged = _coverArtUrl != processedCoverUrl;

        // Only update if changed or initial load
        if (mounted && (trackChanged || artChanged || wasLoadingInfo)) {
          setState(() {
            _currentTrack = title;
            _currentArtist = artist;
            _coverArtUrl = processedCoverUrl;
            _isLoadingInfo = false;
          });
          
          // Animate track info change
          if (trackChanged) {
            _trackInfoController.reset();
            _trackInfoController.forward();
          }
        }

        // Update media item if needed
        if (trackChanged || artChanged || wasLoadingInfo) {
          LogService.log('RadioPage: Updating media notification', category: 'radio');
          _updateMediaItem();
        }
        
        // Reset retry count on success
        _retryCount = 0;
        
      } else {
        LogService.log(
          'RadioPage: Failed to fetch stream info - HTTP ${response.statusCode}',
          category: 'radio_error'
        );
        _handleStreamInfoError();
      }
    } catch (e, stack) {
      LogService.log(
        'RadioPage: Error fetching stream info: $e\n$stack',
        category: 'radio_error'
      );
      _handleStreamInfoError();
    }
  }
  
  // Process cover art URL for optimal loading
  String _processCoverArtUrl(String coverArt) {
    if (coverArt.isEmpty) return '';
    
    if (coverArt.contains('mzstatic.com')) {
      final int lastSlashIndex = coverArt.lastIndexOf('/');
      if (lastSlashIndex != -1) {
        final optimizedUrl = '${coverArt.substring(0, lastSlashIndex + 1)}512x512bb.jpg';
        LogService.log(
          'RadioPage: Optimized cover art URL: $optimizedUrl',
          category: 'radio_detail'
        );
        return optimizedUrl;
      }
    }
    
    return coverArt;
  }
  
  // Handle stream info fetch errors with retry logic
  void _handleStreamInfoError() {
    if (mounted && _isLoadingInfo) {
      setState(() {
        _isLoadingInfo = false;
      });
    }
    
    // Implement retry logic
    if (_retryCount < _maxRetries) {
      _retryCount++;
      final delay = Duration(seconds: _retryCount * 5); // Progressive backoff
      
      LogService.log(
        'RadioPage: Retrying stream info fetch in ${delay.inSeconds}s (attempt $_retryCount/$_maxRetries)',
        category: 'radio_warning'
      );
      
      _retryTimer?.cancel();
      _retryTimer = Timer(delay, () {
        if (mounted && _isPlayerInitialized) {
          _fetchStreamInfo();
        }
      });
    }
  }

  // Enhanced media item update
  void _updateMediaItem() {
    _audioService.updateMediaItem(
      title: _currentTrack,
      artist: _currentArtist,
      artworkUrl: _coverArtUrl,
    );
  }

  // Enhanced player initialization with better error handling
  Future<bool> _initializePlayer() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      LogService.log('RadioPage: Initializing optimized audio player', category: 'radio');
      await _audioService.setupRadioPlayer();

      if (!mounted) return false;

      setState(() {
        _isLoading = false;
        _errorMessage = '';
        _isPlaying = _audioService.player.playing;
        _isPlayerInitialized = true;
      });
      
      LogService.log(
        'RadioPage: Audio player initialized successfully. Is playing: $_isPlaying',
        category: 'radio'
      );
      
      return true;
    } catch (e, stack) {
      LogService.log(
        'RadioPage: Error initializing audio player: $e\n$stack',
        category: 'radio_error'
      );
      
      if (!mounted) return false;
      
      setState(() {
        _isLoading = false;
        _errorMessage = 'Kon radio niet laden. Controleer je internetverbinding.';
        _isPlayerInitialized = false;
      });
      
      return false;
    }
  }

  // Enhanced toggle with connection state handling
  Future<void> _togglePlayPause() async {
    if (!_isPlayerInitialized || _errorMessage.isNotEmpty) {
      LogService.log('RadioPage: Play/Pause blocked - player not ready', category: 'radio_warning');
      return;
    }

    // Prevent multiple rapid taps
    if (_isConnecting) {
      LogService.log('RadioPage: Play/Pause blocked - already connecting', category: 'radio_warning');
      return;
    }

    try {
      if (_isPlaying) {
        LogService.log('RadioPage: User initiated pause', category: 'radio_action');
        await _audioService.pause();
      } else {
        LogService.log('RadioPage: User initiated play', category: 'radio_action');
        
        // Set connecting state
        setState(() {
          _isConnecting = true;
        });
        
        await _audioService.play();
        
        // Fetch stream info immediately when starting playback
        if (mounted) {
          _fetchStreamInfo(isInitialLoad: true);
        }
        
        // Update media item if info is available
        if (!_isLoadingInfo) {
          _updateMediaItem();
        }
      }
    } catch (e, stack) {
      LogService.log(
        'RadioPage: Error toggling playback: $e\n$stack', 
        category: 'radio_error'
      );
      
      // Reset connecting state on error
      if (mounted) {
        setState(() {
          _isConnecting = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verbindingsfout: ${e.toString().split('\n')[0]}'),
            action: SnackBarAction(
              label: 'Opnieuw',
              onPressed: _togglePlayPause,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Samen1 Radio'),
            const SizedBox(width: 12),
            _buildCompactStatusIndicator(),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow,
                key: ValueKey(_isPlaying),
              ),
            ),
            onPressed: (_isPlayerInitialized && _errorMessage.isEmpty) ? _togglePlayPause : null,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }
  
  Widget _buildBody() {
    if (_isLoading) {
      return _buildLoadingScreen();
    }
    
    if (_errorMessage.isNotEmpty) {
      return _buildErrorScreen();
    }
    
    return _buildPlayerScreen();
  }
  
  Widget _buildLoadingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder(
            tween: Tween<double>(begin: 0, end: 1),
            duration: const Duration(milliseconds: 1000),
            builder: (context, double value, child) {
              return Transform.scale(
                scale: 0.8 + (value * 0.2),
                child: CircularProgressIndicator(
                  value: value,
                  strokeWidth: 3,
                  color: Theme.of(context).colorScheme.primary,
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          const Text(
            'Radio wordt geladen...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildErrorScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 24),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => _initializePlayer(),
              icon: const Icon(Icons.refresh),
              label: const Text('Opnieuw proberen'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPlayerScreen() {
    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: MediaQuery.of(context).size.height - kToolbarHeight - 32, // Full height minus app bar
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center, // Center everything vertically
            children: [
              _buildArtworkSection(),
              const SizedBox(height: 20),
              _buildTrackInfoSection(),
              const SizedBox(height: 28),
              _buildControlsSection(),
              const SizedBox(height: 80), // Extra space for pull-to-refresh
            ],
          ),
        ),
      ),
    );
  }
  
  // Pull-to-refresh handler
  Future<void> _onRefresh() async {
    LogService.log('RadioPage: Pull-to-refresh triggered', category: 'radio_action');
    
    // Fetch fresh stream info
    await _fetchStreamInfo();
    
    // Update media item
    _updateMediaItem();
    
    // Show feedback
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Radio informatie ververst'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
  
  Widget _buildArtworkSection() {
    final displayArtUrl = _coverArtUrl.isNotEmpty ? _coverArtUrl : AudioService.fallbackArtworkUrl;
    
    return FadeTransition(
      opacity: _artworkController,
      child: Column(
        children: [
          // Artwork container
          Container(
            width: 260, // Reduced from 280
            height: 260, // Reduced from 280
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  spreadRadius: 2,
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                children: [
                  // Background gradient
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Theme.of(context).colorScheme.primary.withOpacity(0.1),
                          Theme.of(context).colorScheme.primary.withOpacity(0.05),
                        ],
                      ),
                    ),
                  ),
                  // Artwork image
                  CachedNetworkImage(
                    imageUrl: displayArtUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    placeholder: (context, url) => Container(
                      color: Colors.grey[100],
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Theme.of(context).colorScheme.primary,
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[100],
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.radio,
                            size: 80,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Samen1 Radio',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Connecting overlay
                  if (_isConnecting)
                    Container(
                      color: Colors.black.withOpacity(0.3),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                  // Status indicator in top-right corner
                  Positioned(
                    top: 12, // Closer to the edge
                    right: 12, // Closer to the edge
                    child: _buildStatusBadge(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTrackInfoSection() {
    return FadeTransition(
      opacity: _trackInfoController,
      child: Column(
        children: [
          Text(
            _radioStationName,
            style: const TextStyle(
              fontSize: 24, // Reduced from 28
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6), // Reduced from 8
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), // Reduced vertical padding
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _isLoadingInfo ? 'Laadt trackinformatie...' : 
              (_currentTrack.isEmpty ? 'Onbekend nummer' : _currentTrack),
              style: TextStyle(
                fontSize: 15, // Reduced from 16
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildControlsSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 70, // Reduced from 80
          height: 70, // Reduced from 80
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: (_isPlayerInitialized && _errorMessage.isEmpty)
                ? Theme.of(context).colorScheme.primary
                : Colors.grey[400],
            boxShadow: [
              if (_isPlayerInitialized && _errorMessage.isEmpty)
                BoxShadow(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                  spreadRadius: 2,
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(35), // Updated for new size
              onTap: (_isPlayerInitialized && _errorMessage.isEmpty) ? _togglePlayPause : null,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (_isConnecting)
                    const CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    )
                  else
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 150),
                      child: Icon(
                        _isPlaying ? Icons.pause : Icons.play_arrow,
                        key: ValueKey(_isPlaying),
                        size: 32, // Reduced from 36
                        color: Colors.white,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  // Compact status badge for in the artwork
  Widget _buildStatusBadge() {
    Color backgroundColor;
    Color textColor;
    String statusText;
    IconData icon;
    
    if (_isPlaying) {
      backgroundColor = Colors.green;
      textColor = Colors.white;
      statusText = 'LIVE';
      icon = Icons.radio;
    } else if (_isConnecting) {
      backgroundColor = Colors.orange;
      textColor = Colors.white;
      statusText = 'VERBINDEN';
      icon = Icons.sync;
    } else {
      backgroundColor = Colors.grey.shade700;
      textColor = Colors.white;
      statusText = 'PAUZE';
      icon = Icons.pause;
    }
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), // More compact padding
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16), // Smaller border radius
        boxShadow: [
          BoxShadow(
            color: backgroundColor.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12, // Smaller icon
            color: textColor,
          ),
          const SizedBox(width: 4), // Less spacing
          Text(
            statusText,
            style: TextStyle(
              color: textColor,
              fontSize: 10, // Smaller text
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3, // Less letter spacing
            ),
          ),
        ],
      ),
    );
  }
  
  // Compact status indicator for app bar
  Widget _buildCompactStatusIndicator() {
    Color color;
    if (_isPlaying) {
      color = Colors.green;
    } else if (_isConnecting) {
      color = Colors.orange;
    } else {
      color = Colors.grey.shade400;
    }
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}
