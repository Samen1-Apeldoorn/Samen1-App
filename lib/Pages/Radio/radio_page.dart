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

class _RadioPageState extends State<RadioPage> {
  // Use the singleton AudioService instead of creating a new AudioPlayer
  final AudioService _audioService = AudioService();
  bool _isLoading = true;
  bool _isPlaying = false;
  String _errorMessage = ''; // Added to store initialization errors
  bool _isPlayerInitialized = false; // Track successful initialization
  
  // Stream info variables
  String _currentTrack = 'Laden...';
  String _coverArtUrl = '';
  Timer? _streamInfoTimer;
  bool _isLoadingInfo = true;

  static const String _radioInfoUrl = 'https://server-67.stream-server.nl:2000/json/stream/ValouweMediaStichting';
  static const String _radioStationName = 'Samen1 Radio';
  
  @override
  void initState() {
    super.initState();
    LogService.log('RadioPage: Initializing page and enabling wakelock', category: 'radio');
    _enableWakelock(); // Extracted wakelock logic

    // Initialize player first
    _initializePlayer().then((success) {
      if (success && mounted) {
        _isPlayerInitialized = true;
        // Fetch initial stream info ONLY after successful player init
        _fetchStreamInfo();
        // Setup periodic updates ONLY after successful player init
        _setupPeriodicStreamInfoUpdates();
      }
    });

    // Listen to player state changes - moved setup here for clarity
    _setupPlayerStateListener();
  }

  // Helper method for enabling wakelock
  void _enableWakelock() {
     WakelockPlus.enable().then((_) {
       LogService.log('RadioPage: Wakelock enabled successfully', category: 'radio');
     }).catchError((error) {
       LogService.log('RadioPage: Failed to enable wakelock: $error', category: 'radio_error');
     });
  }

  // Helper method for setting up the listener
  void _setupPlayerStateListener() {
     _audioService.player.playerStateStream.listen((state) {
       if (!mounted) return; // Check mounted state first

       LogService.log(
         'RadioPage: Player state update - Playing: ${state.playing}, '
         'Processing: ${state.processingState}',
         category: 'radio_detail'
       );

       bool shouldUpdateState = false;
       bool newIsPlaying = _isPlaying; // Assume no change initially

       // Handle loading/buffering indication
       if (state.processingState == ProcessingState.loading || state.processingState == ProcessingState.buffering) {
         if (!_isLoading) { // Only set state if not already loading
            // Optionally show a specific buffering indicator here
            // setState(() { _isLoading = true; }); // Or a different flag like _isBuffering
         }
       } else if (_isLoading && state.processingState != ProcessingState.idle) {
         // If we were loading, but now we are ready/completed, stop loading indicator
         // _isLoading should be primarily controlled by _initializePlayer result now
         // setState(() { _isLoading = false; });
       }

       // Update playing state based on player
       if (newIsPlaying != state.playing) {
          newIsPlaying = state.playing;
          shouldUpdateState = true;
       }

       // If player becomes idle unexpectedly after init, reflect paused state
       if (state.processingState == ProcessingState.idle && _isPlayerInitialized && newIsPlaying) {
          newIsPlaying = false;
          shouldUpdateState = true;
          LogService.log('RadioPage: Player became idle, setting UI to paused.', category: 'radio_warning');
       }

       // Apply state changes if needed
       if (shouldUpdateState) {
         setState(() {
           _isPlaying = newIsPlaying;
         });
       }
     });
  }

  // Helper method for periodic updates
  void _setupPeriodicStreamInfoUpdates() {
    LogService.log('RadioPage: Setting up periodic stream info updates (30s interval)', category: 'radio');
    _streamInfoTimer?.cancel(); // Cancel previous timer if any
    _streamInfoTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      // Only fetch if player is initialized and page is mounted
      if (_isPlayerInitialized && mounted) {
        LogService.log('RadioPage: Periodic stream info update triggered', category: 'radio_detail');
        _fetchStreamInfo();
      } else {
         LogService.log('RadioPage: Skipping periodic update (player not ready or page disposed)', category: 'radio_detail');
         _streamInfoTimer?.cancel(); // Stop timer if player/page not valid
      }
    });
  }

  @override
  void dispose() {
    LogService.log('RadioPage: Disposing page and canceling timers', category: 'radio');
    _streamInfoTimer?.cancel();
    
    WakelockPlus.disable().then((_) {
      LogService.log('RadioPage: Wakelock disabled successfully', category: 'radio');
    }).catchError((error) {
      LogService.log('RadioPage: Failed to disable wakelock: $error', category: 'radio_error');
    });
    
    LogService.log('RadioPage: Page closed, playback continues in background', category: 'radio');
    super.dispose();
  }

  Future<void> _fetchStreamInfo() async {
    // Ensure player is initialized before fetching
    if (!_isPlayerInitialized) {
       LogService.log('RadioPage: Skipping fetchStreamInfo - player not initialized.', category: 'radio_warning');
       return;
    }
    try {
      LogService.log('RadioPage: Fetching stream info from $_radioInfoUrl', category: 'radio_detail');
      final response = await http.get(Uri.parse(_radioInfoUrl));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final nowPlaying = data['nowplaying'] ?? 'Onbekend nummer';
        final coverArt = data['coverart'] ?? '';
        
        LogService.log(
          'RadioPage: Stream info fetched - Now Playing: "$nowPlaying"', 
          category: 'radio'
        );

        // --- Define coverUrl outside setState ---
        String processedCoverUrl = coverArt; 
        if (processedCoverUrl.isNotEmpty && processedCoverUrl.contains('mzstatic.com')) {
          final int lastSlashIndex = processedCoverUrl.lastIndexOf('/');
          if (lastSlashIndex != -1) {
            processedCoverUrl = '${processedCoverUrl.substring(0, lastSlashIndex + 1)}512x512bb.jpg';
            LogService.log(
              'RadioPage: Resized cover art to 512x512: $processedCoverUrl',
              category: 'radio_detail'
            );
          }
        }
        // --- End processing coverUrl ---

        // Check if info actually changed before calling setState or updating media item
        final bool trackChanged = _currentTrack != nowPlaying;
        final bool artChanged = _coverArtUrl != processedCoverUrl; // Compare state variable with processed URL
        
        if (mounted && (trackChanged || artChanged || _isLoadingInfo)) { // Also update if it was loading info
          setState(() {
            _currentTrack = nowPlaying;
            _coverArtUrl = processedCoverUrl; // Assign processed URL to state variable
            _isLoadingInfo = false;
          });
        }
        
        // Update the notification ONLY if playing AND if track info or artwork actually changed
        if (_isPlaying && (trackChanged || artChanged)) {
          LogService.log('RadioPage: Updating media notification because track or art changed.', category: 'radio');
          // _updateMediaItem uses the state variable _coverArtUrl which was just updated in setState
          _updateMediaItem(); 
        }
      } else {
        LogService.log(
          'RadioPage: Failed to fetch stream info - HTTP ${response.statusCode}',
          category: 'radio_error'
        );
        // Optionally set isLoadingInfo to false even on error if needed
        if (mounted && _isLoadingInfo) {
           setState(() { _isLoadingInfo = false; });
        }
      }
    } catch (e, stack) {
      LogService.log(
        'RadioPage: Error fetching stream info: $e\n$stack', 
        category: 'radio_error'
      );
      if (mounted && _isLoadingInfo) { // Ensure loading indicator is turned off on error
        setState(() {
          _isLoadingInfo = false;
        });
      }
    }
  }

  void _updateMediaItem() {
    // Parse artist and title from the nowplaying string
    String artist = _radioStationName;
    String title = _currentTrack;
    
    if (_currentTrack.contains(' - ')) {
      final parts = _currentTrack.split(' - ');
      if (parts.length >= 2) {
        artist = parts[0];
        title = parts.sublist(1).join(' - ');
        LogService.log(
          'RadioPage: Parsed track info - Artist: "$artist", Title: "$title"',
          category: 'radio_detail'
        );
      }
    }
    
    // Update media item using our service
    _audioService.updateMediaItem(
      title: title,
      artist: artist,
      artworkUrl: _coverArtUrl,
    );
  }

  // Modified to return bool indicating success
  Future<bool> _initializePlayer() async {
    setState(() {
      _isLoading = true; // Ensure loading indicator is shown
      _errorMessage = '';
    });
    try {
      LogService.log('RadioPage: Initializing audio player', category: 'radio');
      await _audioService.setupRadioPlayer();

      if (!mounted) return false; // Check mount status after async gap

      setState(() {
        _isLoading = false;
        _errorMessage = '';
        _isPlaying = _audioService.player.playing; // Initial state
      });
      LogService.log(
        'RadioPage: Audio player initialized successfully. Is playing: $_isPlaying',
        category: 'radio'
      );
      return true; // Indicate success
    } catch (e, stack) {
      LogService.log(
        'RadioPage: Error initializing audio player: $e\n$stack',
        category: 'radio_error'
      );
      if (!mounted) return false; // Check mount status after async gap
      setState(() {
        _isLoading = false;
        _errorMessage = 'Fout bij initialiseren van de radio. Controleer de internetverbinding.'; // More specific message
      });
      return false; // Indicate failure
    }
  }

  Future<void> _togglePlayPause() async {
    // Prevent action if player isn't initialized or had an error
    if (!_isPlayerInitialized || _errorMessage.isNotEmpty) {
       LogService.log('RadioPage: Play/Pause blocked - player not ready or error occurred.', category: 'radio_warning');
       return;
    }

    try {
      if (_isPlaying) {
        LogService.log('RadioPage: User initiated pause', category: 'radio_action');
        await _audioService.pause();
      } else {
        LogService.log('RadioPage: User initiated play', category: 'radio_action');
        // Ensure the player is ready or becomes ready before updating media item
        // The state listener will handle the _isPlaying state update
        await _audioService.play();
        // Update media item immediately ONLY if info is already loaded
        // Otherwise, _fetchStreamInfo will handle it when called periodically or initially
        if (!_isLoadingInfo) {
           _updateMediaItem();
        }
      }
    } catch (e, stack) {
      LogService.log(
        'RadioPage: Error toggling playback: $e\n$stack', 
        category: 'radio_error'
      );
      
      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Probleem met afspelen: ${e.toString().split('\n')[0]}'))
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use cover art from stream info if available, otherwise use fallback
    final displayArtUrl = _coverArtUrl.isNotEmpty ? _coverArtUrl : AudioService.fallbackArtworkUrl;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Radio Player'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
            onPressed: _togglePlayPause,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Show loading indicator OR error message OR main content
          // Use _isLoading which is now primarily controlled by _initializePlayer
          if (_isLoading)
            const Center(child: CircularProgressIndicator()),
          // Display error message if initialization failed
          if (!_isLoading && _errorMessage.isNotEmpty) 
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(
                  _errorMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 16),
                ),
              ),
            ),
          // Display main content only if not loading and no error
          if (!_isLoading && _errorMessage.isEmpty)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Album artwork with proper error handling
                  Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.grey[200],
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(51),
                          spreadRadius: 2,
                          blurRadius: 5,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: CachedNetworkImage(
                        imageUrl: displayArtUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Center(
                          child: CircularProgressIndicator(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        errorWidget: (context, url, error) => Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.radio, 
                                size: 50, 
                                color: Theme.of(context).colorScheme.primary
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Samen1',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  const Text(
                    _radioStationName,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  // Currently playing track
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      // Show loading text if player is init but info isn't, else show track
                      _isPlayerInitialized && _isLoadingInfo ? 'Laden...' : _currentTrack,
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 40),
                  // Play/Pause button - Disable if player not ready
                  ElevatedButton(
                    // Disable button if player not initialized or error occurred
                    onPressed: (_isPlayerInitialized && _errorMessage.isEmpty) ? _togglePlayPause : null,
                    style: ElevatedButton.styleFrom(
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(20),
                      backgroundColor: (_isPlayerInitialized && _errorMessage.isEmpty)
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey, // Indicate disabled state
                    ),
                    child: Icon(
                      _isPlaying ? Icons.pause : Icons.play_arrow,
                      size: 48,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
