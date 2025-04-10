import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../services/log_service.dart';
import '../services/audio_service.dart';

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
    WakelockPlus.enable().then((_) {
      LogService.log('RadioPage: Wakelock enabled successfully', category: 'radio');
    }).catchError((error) {
      LogService.log('RadioPage: Failed to enable wakelock: $error', category: 'radio_error');
    });

    // Initialize the audio player with background capability
    _initializePlayer();
    
    // Fetch initial stream info
    _fetchStreamInfo();
    
    LogService.log('RadioPage: Setting up periodic stream info updates (30s interval)', category: 'radio');
    // Set up periodic fetching of stream info
    _streamInfoTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      LogService.log('RadioPage: Periodic stream info update triggered', category: 'radio_detail');
      _fetchStreamInfo();
    });
    
    // Listen to player state changes
    _audioService.player.playerStateStream.listen((state) {
      LogService.log(
        'RadioPage: Player state update - Playing: ${state.playing}, '
        'Processing: ${state.processingState}',
        category: 'radio_detail'
      );
      
      if (state.processingState == ProcessingState.ready) {
        setState(() {
          _isPlaying = state.playing;
        });
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
        
        if (mounted) {
          setState(() {
            _currentTrack = nowPlaying;
            
            // Get cover art URL and ensure it's 512x512 for Apple Music images
            String coverUrl = coverArt;
            if (coverUrl.isNotEmpty && coverUrl.contains('mzstatic.com')) {
              // Extract the base part of the URL (before the size specification)
              final int lastSlashIndex = coverUrl.lastIndexOf('/');
              if (lastSlashIndex != -1) {
                // Replace whatever size with 512x512
                coverUrl = '${coverUrl.substring(0, lastSlashIndex + 1)}512x512bb.jpg';
                LogService.log(
                  'RadioPage: Resized cover art to 512x512: $coverUrl',
                  category: 'radio_detail'
                );
              }
            }
            _coverArtUrl = coverUrl;
            _isLoadingInfo = false;
          });
        }
        
        // Update the notification with current track info
        if (_isPlaying) {
          LogService.log('RadioPage: Updating media notification with new track info', category: 'radio');
          _updateMediaItem();
        }
      } else {
        LogService.log(
          'RadioPage: Failed to fetch stream info - HTTP ${response.statusCode}',
          category: 'radio_error'
        );
      }
    } catch (e, stack) {
      LogService.log(
        'RadioPage: Error fetching stream info: $e\n$stack', 
        category: 'radio_error'
      );
      if (mounted) {
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

  Future<void> _initializePlayer() async {
    try {
      LogService.log('RadioPage: Initializing audio player', category: 'radio');
      // Setup the player using our service
      await _audioService.setupRadioPlayer();
      
      setState(() {
        _isLoading = false;
        // Update the playing state based on the current player state
        _isPlaying = _audioService.player.playing;
        LogService.log(
          'RadioPage: Audio player initialized successfully. Is playing: $_isPlaying', 
          category: 'radio'
        );
      });
    } catch (e, stack) {
      LogService.log(
        'RadioPage: Error initializing audio player: $e\n$stack', 
        category: 'radio_error'
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _togglePlayPause() async {
    try {
      if (_isPlaying) {
        LogService.log('RadioPage: User initiated pause', category: 'radio_action');
        await _audioService.player.pause();
      } else {
        LogService.log('RadioPage: User initiated play', category: 'radio_action');
        await _audioService.player.play();
        // Update media item with latest info when starting playback
        _updateMediaItem();
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
          if (_isLoading)
            const Center(child: CircularProgressIndicator()),
          if (!_isLoading)
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
                          color: Colors.black.withOpacity(0.2),
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
                      _isLoadingInfo ? 'Laden...' : _currentTrack,
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 40),
                  // Play/Pause button
                  ElevatedButton(
                    onPressed: _togglePlayPause,
                    style: ElevatedButton.styleFrom(
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(20),
                      backgroundColor: Theme.of(context).colorScheme.primary,
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
