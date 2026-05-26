# Code Review Checklist — Messaging & Logging

Use this checklist when reviewing any PR that touches UI text, error handling, or logging.

---

## Messages

- [ ] All user-facing strings are defined in `lib/constants/messages.dart`
- [ ] No hardcoded English string literals appear in widget `Text(...)` calls outside `messages.dart`
- [ ] No Vietnamese (or any other language) text in code, comments, or string literals
- [ ] Interpolated strings use `AppMessages.*` static methods (not inline template strings)
- [ ] New `MessageKey` values are added in alphabetical order within their category section

## Logging

- [ ] No `print()` or `debugPrint()` calls outside of `logger_service.dart` itself
- [ ] All `catch` blocks that swallow exceptions include an `AppLogger.log(...)` call
- [ ] `AppLogger` calls use the correct `LogCategory`:
  - `network` — HTTP requests, API calls, socket errors
  - `parse` — JSON decode, XML parse, metadata extraction
  - `ui` — user interaction events, screen transitions
  - `cache` — cache read/write/invalidate
  - `other` — everything else
- [ ] `AppLogger` messages describe context for a developer, not the user
  - ✅ `'OpenAlex metadata fetch failed'`
  - ❌ `'Something went wrong'`

## Error Handling

- [ ] Errors shown to users come from `AppMessages` (friendly English)
- [ ] Technical error details (stack traces, raw exception messages) go to `AppLogger` only
- [ ] `UserFacingException` is used when service-layer errors need to bubble up to the UI
- [ ] No raw `Exception('...')` messages with technical details reach `progressLogs` or `SnackBar`

## General

- [ ] New files in `lib/services/` follow the `AppLogger` import pattern
- [ ] `UserFacingException.toString()` is not relied upon for technical debugging
  (use `.technicalError` via `AppLogger` instead)
