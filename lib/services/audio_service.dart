import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import '../services/log_service.dart';

/// Singleton service to manage a single AudioPlayer instance across the app
/// just_audio_background only supports a single player instance
class AudioService {
  // Singleton instance
  static final AudioService _instance = AudioService._internal();
  
  // Factory constructor to return the singleton instance
  factory AudioService() => _instance;
  
  // Private constructor for singleton
  AudioService._internal() {
    LogService.log('AudioService: Initializing singleton instance', category: 'audio');
    
    // Listen to player state changes for logging
    player.playerStateStream.listen((state) {
      final processingState = state.processingState;
      final playing = state.playing;
      
      LogService.log(
        'AudioService: Player state changed - '
        'Processing: ${_processingStateToString(processingState)}, '
        'Playing: $playing', 
        category: 'audio_state'
      );
    });
    
    // Log playback exceptions
    player.playbackEventStream.listen((event) {}, 
      onError: (error) {
        LogService.log(
          'AudioService: Playback event error: $error',
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

  // Update player with new track information
  Future<void> updateMediaItem({
    required String title,
    required String artist,
    required String artworkUrl,
  }) async {
    try {
      LogService.log(
        'AudioService: Updating media item - Title: "$title", Artist: "$artist"',
        category: 'audio'
      );
      
      final effectiveArtUrl = artworkUrl.isNotEmpty ? artworkUrl : fallbackArtworkUrl;
      final wasPlaying = player.playing;
      
      final audioSource = AudioSource.uri(
        Uri.parse(radioStreamUrl),
        tag: MediaItem(
          id: radioStationId,
          title: title,
          artist: artist,
          artUri: Uri.parse(effectiveArtUrl),
          displayTitle: title,
          displaySubtitle: artist,
        ),
      );
      
      // Update the audio source
      await player.setAudioSource(audioSource, preload: false);
      
      // Restore playing state if needed
      if (wasPlaying && !player.playing) {
        LogService.log('AudioService: Restoring playing state after media item update', 
          category: 'audio');
        player.play();
      }
    } catch (e, stack) {
      LogService.log(
        'AudioService: Error updating media item: $e\n$stack', 
        category: 'audio_error'
      );
    }
  }

  // Play the current stream
  Future<void> play() async {
    try {
      LogService.log('AudioService: Starting playback', category: 'audio');
      await player.play();
    } catch (e, stack) {
      LogService.log(
        'AudioService: Error starting playback: $e\n$stack', 
        category: 'audio_error'
      );
      rethrow;
    }
  }

  // Pause the current stream
  Future<void> pause() async {
    try {
      LogService.log('AudioService: Pausing playback', category: 'audio');
      await player.pause();
    } catch (e, stack) {
      LogService.log(
        'AudioService: Error pausing playback: $e\n$stack', 
        category: 'audio_error'
      );
      rethrow;
    }
  }

  // Stop the current stream
  Future<void> stop() async {
    try {
      LogService.log('AudioService: Stopping playback', category: 'audio');
      await player.stop();
    } catch (e, stack) {
      LogService.log(
        'AudioService: Error stopping playback: $e\n$stack', 
        category: 'audio_error'
      );
      rethrow;
    }
  }

  // Dispose the player (call this when app is shutting down)
  void dispose() {
    LogService.log('AudioService: Disposing player resources', category: 'audio');
    player.dispose();
  }
}
