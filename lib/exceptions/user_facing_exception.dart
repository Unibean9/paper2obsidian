class UserFacingException implements Exception {
  const UserFacingException({
    required this.userMessage,
    this.technicalError,
    this.stackTrace,
  });

  final String userMessage;

  final Object? technicalError;

  final StackTrace? stackTrace;

  @override
  String toString() => userMessage;
}
