/// PDF view modes for displaying pages
enum PdfViewMode {
  /// Single page at a time (default)
  single,

  /// Book-style: pages 1-2, 3-4, 5-6 (odd-even pairs)
  booklet,

  /// Sliding window: pages 1-2, 2-3, 3-4
  continuousDouble;

  /// Display name for UI
  String get displayName {
    switch (this) {
      case PdfViewMode.single:
        return 'Single Page';
      case PdfViewMode.booklet:
        return 'Booklet';
      case PdfViewMode.continuousDouble:
        return 'Continuous Double';
    }
  }

  /// Convert to string for database storage
  String toStorageString() => name;

  /// Parse from database storage string
  static PdfViewMode fromStorageString(String value) {
    return PdfViewMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => PdfViewMode.single,
    );
  }

  /// Whether this mode displays two pages
  bool get isTwoPage => this != PdfViewMode.single;
}

/// Which page is active in two-page view
enum PageSide { left, right }
