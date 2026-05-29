import 'dart:developer' as developer;

enum LogCategory { ui, network, parse, cache, other }

class AppLogger {
  AppLogger._();

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
