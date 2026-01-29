import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_web_plugins/flutter_web_plugins.dart'
    if (dart.library.io) 'web_url_strategy_stub.dart';

/// Configure URL strategy for web platform.
/// Uses path-based URLs (e.g., /document/3) instead of hash-based (/#/document/3).
void configureUrlStrategy() {
  if (kIsWeb) {
    setUrlStrategy(PathUrlStrategy());
  }
}
