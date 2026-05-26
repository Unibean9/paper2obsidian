import 'dart:developer' as developer;

/// Log categories for filtering in DevTools.
enum LogCategory {
  /// User interaction, screen transitions, state updates visible to user.
  ui,

  /// HTTP requests, responses, timeouts, connection errors.
  network,

  /// JSON parsing, metadata extraction, data transformation.
  parse,

  /// Cache hits, misses, invalidations.
  cache,

  /// Miscellaneous debug info that doesn't fit above categories.
  other,
}

/// Structured logging wrapper around [dart:developer.log].
///
/// Usage:
/// ```dart
/// AppLogger.log('Fetching metadata', category: LogCategory.network);
/// AppLogger.log('Parse error', category: LogCategory.parse, error: e, stackTrace: s);
/// ```
///
/// Logs appear in Flutter DevTools Console filtered by the name tag
/// `paper2obsidian.<category>`.
///
/// NOTE: Do NOT use AppLogger for user-facing messages — those are managed by
/// [AppMessages] and displayed via progressLogs or SnackBar in the UI.
class AppLogger {
  AppLogger._();

  /// Logs a structured message with the given [category].
  ///
  /// [message] — a concise description of what happened (no PII).
  /// [category] — LogCategory for DevTools filtering.
  /// [error] — optional exception/error object.
  /// [stackTrace] — optional stack trace; defaults to null.
  static void log(
    String message, {
    required LogCategory category,
    Object? error,
    StackTrace? stackTrace,
  }) {
    developer.log(
      message,
      name: 'paper2obsidian.${category.name}',
      error: error,
      stackTrace: stackTrace,
    );
  }
}
