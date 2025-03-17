import 'package:package_info_plus/package_info_plus.dart';

class VersionService {
  static PackageInfo? _packageInfo;

  static Future<void> initialize() async {
    _packageInfo = await PackageInfo.fromPlatform();
  }

  static String get versionString {
    if (_packageInfo == null) return 'V?.?.?';
    return 'V${_packageInfo!.version}';
  }

  static String get fullVersionString {
    if (_packageInfo == null) return 'Versie onbekend';
    return 'Versie ${_packageInfo!.version} (${_packageInfo!.buildNumber})';
  }

  static String get copyright {
    return 'Copyright Samen1 2025 - $versionString';
  }
}
