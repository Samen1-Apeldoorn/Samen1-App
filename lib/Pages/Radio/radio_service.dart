import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'dart:async';
import '../../services/log_service.dart';

/// Optimized singleton service to manage a single AudioPlayer instance across the app
/// for background playback using just_audio_background with enhanced performance.
class AudioService {
  // Singleton instance
  static final AudioService _instance = AudioService._internal();
  
  // Factory constructor to return the singleton instance
  factory AudioService() => _instance;
  
  // Private constructor for singleton
  AudioService._internal() {
    LogService.log('AudioService: Initializing optimized singleton instance', category: 'audio');
    
    // Initialize with optimized settings
    _initializePlayer();
  }
  
  // The single audio player instance for the entire app
  final AudioPlayer player = AudioPlayer();
  
  // Connection state tracking
  bool _isInitialized = false;
  bool _isConnecting = false;
  StreamSubscription? _stateSubscription;
  StreamSubscription? _eventSubscription;
  
  // Metadata for the radio stream
  static const String radioStreamUrl = 'https://server-67.stream-server.nl:18752/stream';
  static const String radioStationId = 'samen1_live_radio';
  static const String radioStationName = 'Samen1 Radio';
  static const String fallbackArtworkUrl = 'https://samen1.nl/bestanden/uploads/samen1-radioimg-1.png';
  
  // Enhanced player initialization
  void _initializePlayer() {
    // Listen to player state changes with enhanced logging
    _stateSubscription = player.playerStateStream.listen((state) {
      final processingState = state.processingState;
      final playing = state.playing;
      
      LogService.log(
        'AudioService: Player state changed - '
        'Processing: ${_processingStateToString(processingState)}, '
        'Playing: $playing', 
        category: 'audio_state'
      );

      // Update connection state
      _isConnecting = processingState == ProcessingState.loading || 
                     processingState == ProcessingState.buffering;

      // Handle potential errors signaled by the idle state after playing/loading
      if (processingState == ProcessingState.idle && !_isDisposing && player.audioSource != null) {
        LogService.log(
          'AudioService: Player entered idle state unexpectedly after source was set.',
          category: 'audio_warning'
        );
      }

    }, onError: (error, stackTrace) {
      LogService.log(
        'AudioService: Player state stream error: $error\n$stackTrace',
        category: 'audio_error'
      );
    });
    
    // Listen to playback events for enhanced error handling
    _eventSubscription = player.playbackEventStream.listen(
      (event) {
        // Handle successful buffering completion
        if (event.bufferedPosition > Duration.zero) {
          LogService.log(
            'AudioService: Buffered ${event.bufferedPosition.inSeconds}s',
            category: 'audio_detail'
          );
        }
      },
      onError: (error, stackTrace) {
        LogService.log(
          'AudioService: Playback event error: $error\n$stackTrace',
          category: 'audio_error'
        );
      }
    );
  }
  
  // Enhanced radio player setup with optimized buffering
  Future<void> setupRadioPlayer() async {
    try {
      LogService.log('AudioService: Setting up optimized radio player with stream URL: $radioStreamUrl', 
        category: 'audio_setup');
      
      // Set optimized audio session
      await player.setAudioSource(
        AudioSource.uri(
          Uri.parse(radioStreamUrl),
          tag: MediaItem(
            id: radioStationId,
            title: radioStationName,
            artist: radioStationName,
            artUri: Uri.parse(fallbackArtworkUrl),
            displayTitle: radioStationName,
            displaySubtitle: radioStationName,
          ),
        ),
        // Optimize for streaming with reduced preload
        preload: false,
      );
      
      // Set optimized buffer settings for live streaming
      await player.setSpeed(1.0);
      await player.setVolume(1.0);
      
      _isInitialized = true;
      LogService.log('AudioService: Radio player set up successfully', category: 'audio');
      
      // Log current capabilities
      final hasAudio = player.audioSource != null;
      LogService.log(
        'AudioService: Player ready with audio source: $hasAudio, '
        'Volume: ${player.volume}, '
        'Speed: ${player.speed}', 
        category: 'audio_setup'
      );
    } catch (e, stack) {
      LogService.log(
        'AudioService: Error setting up radio player: $e\n$stack', 
        category: 'audio_error'
      );
      _isInitialized = false;
      rethrow;
    }
  }

  // Enhanced media item update with optimized performance
  Future<void> updateMediaItem({
    required String title,
    required String artist,
    required String artworkUrl,
  }) async {
    if (!_isInitialized || player.audioSource == null) {
      LogService.log('AudioService: Cannot update media item, player not initialized.', category: 'audio_warning');
      return;
    }
    
    try {
      LogService.log(
        'AudioService: Updating media item - Title: "$title", Artist: "$artist"',
        category: 'audio_update'
      );
      
      final effectiveArtUrl = artworkUrl.isNotEmpty ? artworkUrl : fallbackArtworkUrl;
      
      // Create optimized MediaItem
      final newMediaItem = MediaItem(
        id: radioStationId,
        title: title,
        artist: artist,
        artUri: Uri.parse(effectiveArtUrl),
        displayTitle: title,
        displaySubtitle: artist,
        // Add additional metadata for better notification experience
        duration: null, // Live stream has no duration
        extras: {
          'isLive': true,
          'station': radioStationName,
        },
      );

      // Optimized audio source recreation with minimal disruption
      final audioSource = AudioSource.uri(
        Uri.parse(radioStreamUrl),
        tag: newMediaItem,
      );

      // Preserve playback position and state
      final wasPlaying = player.playing;
      final currentPosition = player.position;
      
      await player.setAudioSource(
        audioSource, 
        preload: false,
        initialPosition: currentPosition,
      );
      
      // Resume playback if it was playing
      if (wasPlaying && !player.playing) {
        await player.play();
      }
      
      LogService.log('AudioService: Media item updated successfully', category: 'audio_update');

    } catch (e, stack) {
      LogService.log(
        'AudioService: Error updating media item: $e\n$stack', 
        category: 'audio_error'
      );
    }
  }

  // Enhanced play method with connection state tracking
  Future<void> play() async {
    if (!_isInitialized) {
      LogService.log('AudioService: Cannot play - player not initialized', category: 'audio_warning');
      return;
    }
    
    try {
      if (!player.playing) {
        LogService.log('AudioService: Starting optimized playback', category: 'audio_action');
        _isConnecting = true;
        await player.play();
      }
    } catch (e, stack) {
      LogService.log(
        'AudioService: Error starting playback: $e\n$stack', 
        category: 'audio_error'
      );
      _isConnecting = false;
    }
  }

  // Enhanced pause method
  Future<void> pause() async {
    if (!_isInitialized) {
      LogService.log('AudioService: Cannot pause - player not initialized', category: 'audio_warning');
      return;
    }
    
    try {
      if (player.playing) {
        LogService.log('AudioService: Pausing playback', category: 'audio_action');
        await player.pause();
        _isConnecting = false;
      }
    } catch (e, stack) {
      LogService.log(
        'AudioService: Error pausing playback: $e\n$stack', 
        category: 'audio_error'
      );
    }
  }

  // Enhanced stop method
  Future<void> stop() async {
    if (!_isInitialized) {
      LogService.log('AudioService: Cannot stop - player not initialized', category: 'audio_warning');
      return;
    }
    
    try {
      LogService.log('AudioService: Stopping playback', category: 'audio_action');
      await player.stop();
      _isConnecting = false;
    } catch (e, stack) {
      LogService.log(
        'AudioService: Error stopping playback: $e\n$stack', 
        category: 'audio_error'
      );
    }
  }

  // Enhanced dispose method
  void dispose() {
    _isDisposing = true;
    LogService.log('AudioService: Disposing optimized player resources', category: 'audio');
    
    // Cancel subscriptions
    _stateSubscription?.cancel();
    _eventSubscription?.cancel();
    
    // Reset state
    _isInitialized = false;
    _isConnecting = false;
    
    // Dispose player
    player.dispose();
  }

  // Flag to prevent logging errors during disposal
  bool _isDisposing = false; 
  
  // Helper method to convert ProcessingState to a readable string
  String _processingStateToString(ProcessingState state) {
    switch (state) {
      case ProcessingState.idle: return 'idle';
      case ProcessingState.loading: return 'loading';
      case ProcessingState.buffering: return 'buffering';
      case ProcessingState.ready: return 'ready';
      case ProcessingState.completed: return 'completed';
    }
  }
  
  // Getter for connection state
  bool get isConnecting => _isConnecting;
  bool get isInitialized => _isInitialized;
}
