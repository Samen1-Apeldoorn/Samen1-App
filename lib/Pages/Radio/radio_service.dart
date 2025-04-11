import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import '../../services/log_service.dart';

/// Singleton service to manage a single AudioPlayer instance across the app
/// for background playback using just_audio_background.
class AudioService {
  // Singleton instance
  static final AudioService _instance = AudioService._internal();
  
  // Factory constructor to return the singleton instance
  factory AudioService() => _instance;
  
  // Private constructor for singleton
  AudioService._internal() {
    LogService.log('AudioService: Initializing singleton instance', category: 'audio');
    
    // Listen to player state changes for logging and potential error handling
    player.playerStateStream.listen((state) {
      final processingState = state.processingState;
      final playing = state.playing;
      
      LogService.log(
        'AudioService: Player state changed - '
        'Processing: ${_processingStateToString(processingState)}, '
        'Playing: $playing', 
        category: 'audio_state'
      );

      // Handle potential errors signaled by the idle state after playing/loading
      if (processingState == ProcessingState.idle && !_isDisposing && player.audioSource != null) {
         // Log only if it becomes idle *after* an audio source has been set
         LogService.log(
           'AudioService: Player entered idle state unexpectedly after source was set.',
           category: 'audio_warning'
         );
      }

    }, onError: (error, stackTrace) { // Added onError callback for the stream
       LogService.log(
         'AudioService: Player state stream error: $error\n$stackTrace',
         category: 'audio_error'
       );
    });
    
    // Log general playback errors
    player.playbackEventStream.listen((_) {}, 
      onError: (error, stackTrace) { // Added stackTrace
        LogService.log(
          'AudioService: Playback event error: $error\n$stackTrace',
          category: 'audio_error'
        );
      }
    );
  }
  
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
  
  // The single audio player instance for the entire app
  final AudioPlayer player = AudioPlayer();
  
  // Metadata for the radio stream
  static const String radioStreamUrl = 'https://server-67.stream-server.nl:18752/stream';
  static const String radioStationId = 'samen1_live_radio';
  static const String radioStationName = 'Samen1 Radio';
  static const String fallbackArtworkUrl = 'https://samen1.nl/bestanden/uploads/samen1-radioimg-1.png';
  
  // Set up radio stream with initial metadata
  Future<void> setupRadioPlayer() async {
    try {
      LogService.log('AudioService: Setting up radio player with stream URL: $radioStreamUrl', 
        category: 'audio_setup');
      
      final audioSource = AudioSource.uri(
        Uri.parse(radioStreamUrl),
        tag: MediaItem(
          id: radioStationId,
          title: radioStationName,
          artist: 'Live Stream',
          artUri: Uri.parse(fallbackArtworkUrl),
          displayTitle: radioStationName,
          displaySubtitle: 'Live Stream',
        ),
      );
      
      await player.setAudioSource(audioSource);
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
      rethrow;
    }
  }

  // Update player notification with new track information
  Future<void> updateMediaItem({
    required String title,
    required String artist,
    required String artworkUrl,
  }) async {
    try {
      LogService.log(
        'AudioService: Updating media item via setAudioSource - Title: "$title", Artist: "$artist"',
        category: 'audio_update'
      );
      
      final effectiveArtUrl = artworkUrl.isNotEmpty ? artworkUrl : fallbackArtworkUrl;
      
      // Create a new MediaItem with updated info
      final newMediaItem = MediaItem(
        id: radioStationId,
        title: title,
        artist: artist,
        artUri: Uri.parse(effectiveArtUrl),
        displayTitle: title, // Use actual title/artist for display fields
        displaySubtitle: artist,
      );

      // Recreate the audio source with the new tag.
      // This is necessary for just_audio_background to update the notification.
      // It might cause a brief interruption or require the player to re-buffer.
      final audioSource = AudioSource.uri(
        Uri.parse(radioStreamUrl),
        tag: newMediaItem,
      );

      // Use setAudioSource to apply the changes. preload: false might help reduce interruption.
      await player.setAudioSource(audioSource, preload: false, initialPosition: player.position); // Try preserving position
      LogService.log('AudioService: Audio source reset with new media item tag.', category: 'audio_update');

    } catch (e, stack) {
      LogService.log(
        'AudioService: Error updating media item: $e\n$stack', 
        category: 'audio_error'
      );
      // Do not rethrow here, just log the error. UI should react to player state.
    }
  }

  // Play the current stream
  Future<void> play() async {
    try {
      if (!player.playing) { // Avoid calling play if already playing
        LogService.log('AudioService: Starting playback', category: 'audio_action');
        await player.play();
      }
    } catch (e, stack) {
      LogService.log(
        'AudioService: Error starting playback: $e\n$stack', 
        category: 'audio_error'
      );
      // Removed rethrow
    }
  }

  // Pause the current stream
  Future<void> pause() async {
    try {
      if (player.playing) { // Avoid calling pause if already paused
        LogService.log('AudioService: Pausing playback', category: 'audio_action');
        await player.pause();
      }
    } catch (e, stack) {
      LogService.log(
        'AudioService: Error pausing playback: $e\n$stack', 
        category: 'audio_error'
      );
      // Removed rethrow
    }
  }

  // Stop the current stream and release some resources
  Future<void> stop() async {
    try {
      LogService.log('AudioService: Stopping playback', category: 'audio_action');
      await player.stop(); // stop releases fewer resources than dispose
    } catch (e, stack) {
      LogService.log(
        'AudioService: Error stopping playback: $e\n$stack', 
        category: 'audio_error'
      );
      // Removed rethrow
    }
  }

  // Dispose the player (call this only when the app is completely shutting down)
  void dispose() {
    _isDisposing = true; // Set flag to avoid error logs during disposal
    LogService.log('AudioService: Disposing player resources', category: 'audio');
    player.dispose();
  }

  // Flag to prevent logging errors during disposal
  bool _isDisposing = false; 
}
