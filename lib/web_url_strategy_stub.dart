// Stub for non-web platforms.
// This file is imported when dart.library.io is available (i.e., not web).

class PathUrlStrategy {
  const PathUrlStrategy();
}

void setUrlStrategy(dynamic strategy) {
  // No-op on non-web platforms
}
