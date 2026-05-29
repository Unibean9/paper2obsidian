import 'user_facing_exception.dart';

class ZoteroException extends UserFacingException {
  const ZoteroException({
    required super.userMessage,
    super.technicalError,
    super.stackTrace,
    this.statusCode,
  });

  final int? statusCode;
}
