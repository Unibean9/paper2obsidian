/// An exception that carries a user-friendly message alongside the technical error.
///
/// Service layer methods throw [UserFacingException] so that:
/// - The [userMessage] is shown in the UI (friendly English).
/// - The [technicalError] + [stackTrace] are logged via [AppLogger] for debugging.
///
/// [toString] returns [userMessage], so catch blocks that use `'$e'` automatically
/// display the friendly message without any changes to callers.
class UserFacingException implements Exception {
  const UserFacingException({
    required this.userMessage,
    this.technicalError,
    this.stackTrace,
  });

  /// Short, user-friendly message — shown in progressLogs or SnackBar.
  final String userMessage;

  /// The original exception captured before wrapping.
  final Object? technicalError;

  /// Stack trace at the point of wrapping.
  final StackTrace? stackTrace;

  @override
  String toString() => userMessage;
}
