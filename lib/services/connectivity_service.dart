import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'log_service.dart';

class ConnectivityService {
  static bool _isOnline = true;
  static StreamController<bool>? _connectivityController;
  static Timer? _connectivityTimer;
  
  // Get connectivity status stream
  static Stream<bool> get connectivityStream {
    _connectivityController ??= StreamController<bool>.broadcast();
    return _connectivityController!.stream;
  }
  
  // Get current connectivity status
  static bool get isOnline => _isOnline;
  
  // Initialize connectivity monitoring
  static void initialize() {
    LogService.log('Initializing connectivity service', category: 'connectivity');
    _startConnectivityMonitoring();
  }
  
  // Start monitoring connectivity
  static void _startConnectivityMonitoring() {
    _connectivityTimer?.cancel();
    _connectivityTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _checkConnectivity();
    });
    
    // Check initial connectivity
    _checkConnectivity();
  }
  
  // Check internet connectivity
  static Future<void> _checkConnectivity() async {
    final wasOnline = _isOnline;
    
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      _isOnline = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      _isOnline = false;
    }
    
    // If status changed, notify listeners
    if (wasOnline != _isOnline) {
      LogService.log(
        'Connectivity changed: ${_isOnline ? "Online" : "Offline"}', 
        category: 'connectivity'
      );
      _connectivityController?.add(_isOnline);
    }
  }
  
  // Force connectivity check
  static Future<bool> checkConnectivity() async {
    await _checkConnectivity();
    return _isOnline;
  }
  
  // Dispose service
  static void dispose() {
    LogService.log('Disposing connectivity service', category: 'connectivity');
    _connectivityTimer?.cancel();
    _connectivityController?.close();
    _connectivityController = null;
  }
  
  // Show offline dialog
  static void showOfflineDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: SizedBox(
          width: double.infinity,
          child: Row(
            children: [
              const Icon(Icons.wifi_off, color: Colors.red),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Geen Internetverbinding',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Je bent momenteel offline. De app toont nu opgeslagen artikelen.'),
            SizedBox(height: 16),
            Text('🔄 De app blijft op de achtergrond controleren op internetverbinding'),
            SizedBox(height: 8),
            Text('📱 Je kunt nog steeds eerder gelezen artikelen bekijken'),
            SizedBox(height: 8),
            Text('⚡ Zodra je weer online bent, worden nieuwe artikelen automatisch geladen'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Begrijpen'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final isOnline = await checkConnectivity();
              if (!isOnline) {
                // Still offline, show again after delay
                Future.delayed(const Duration(seconds: 2), () {
                  if (context.mounted) {
                    showOfflineDialog(context);
                  }
                });
              }
            },
            child: const Text('Opnieuw Proberen'),
          ),
        ],
      ),
    );
  }
  
  // Show back online notification
  static void showBackOnlineNotification(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: SizedBox(
          width: double.infinity,
          child: Row(
            children: [
              const Icon(Icons.wifi, color: Colors.white),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Internetverbinding hersteld!',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Vernieuwen',
          textColor: Colors.white,
          onPressed: () {
            // Trigger refresh - this could be passed as a callback
          },
        ),
      ),
    );
  }
}
