import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../services/log_service.dart';

class RadioPage extends StatefulWidget {
  const RadioPage({super.key});

  @override
  State<RadioPage> createState() => _RadioPageState();
}

class _RadioPageState extends State<RadioPage> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isLoading = true;
  bool _isPlaying = false;

  static const String _radioStreamUrl = 'https://server-67.stream-server.nl:18752/stream';

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    LogService.log('Radio page opened', category: 'radio');

    // Start de audio stream zodra de pagina wordt geopend
    _initializePlayer();
    
    // Luister naar veranderingen in de spelerstatus
    _audioPlayer.playerStateStream.listen((state) {
      // Als de speler klaar is en aan het afspelen is, werk de UI bij
      if (state.processingState == ProcessingState.ready) {
        setState(() {
          _isPlaying = state.playing;
        });
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    WakelockPlus.disable();
    LogService.log('Radio page closed', category: 'radio');
    super.dispose();
  }

  Future<void> _initializePlayer() async {
    try {
      // Laad de stream URL
      await _audioPlayer.setUrl(_radioStreamUrl);
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      LogService.log('Error loading radio stream: $e', category: 'radio_error');
    }
  }

  Future<void> _togglePlayPause() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play();
    }
    // We hoeven _isPlaying hier niet opnieuw in te stellen, omdat de status wordt bijgewerkt door playerStateStream.
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _handleBackPress,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Radio Player'),
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
                    const Text(
                      'Samen1 Radio',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),
                    IconButton(
                      icon: Icon(
                        _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                        size: 64,
                      ),
                      onPressed: _togglePlayPause,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<bool> _handleBackPress() async {
    if (_isPlaying) {
      await _audioPlayer.stop();
      setState(() {
        _isPlaying = false;
      });
    }
    return true;
  }
}
