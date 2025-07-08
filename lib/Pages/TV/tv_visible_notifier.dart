import 'package:flutter/widgets.dart';

// A simple notifier to track visibility state
class TVVisibleNotifier extends ValueNotifier<bool> {
  static final TVVisibleNotifier _instance = TVVisibleNotifier._internal();
  
  factory TVVisibleNotifier() => _instance;
  
  TVVisibleNotifier._internal() : super(false);
}
