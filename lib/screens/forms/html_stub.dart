// Stub implementation for dart:html to support non-web platforms
// This file is only used when building for mobile/desktop (not web)
// It provides minimal interface compatibility for conditional imports

class Window {
  Location get location => Location();
}

class Location {
  String get href => '';
}

// Global instance to match dart:html API
final window = Window();




