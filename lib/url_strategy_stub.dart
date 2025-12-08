// Stub implementation for non-web platforms (Android, iOS)
// This file is used when building for mobile to avoid importing web-only libraries

// Dummy class that matches the web version's interface
class PathUrlStrategy {
  const PathUrlStrategy();
}

// Dummy function that does nothing on mobile platforms
void setUrlStrategy(PathUrlStrategy? strategy) {
  // No-op on mobile platforms
}



