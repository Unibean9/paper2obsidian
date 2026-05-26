# Refactoring Summary: English Messaging + Structured Logging

**Date:** 2026-05-27  
**Commit scope:** `lib/constants/`, `lib/exceptions/`, `lib/services/logger_service.dart`, and all consumer files

---

## Overview

This refactor standardises all user-facing messages to **English-only**, separates technical
logging from UI output, and introduces a centralized message management system.

---

## Architecture

Three new layers were added:

### 1. Constants Layer — `lib/constants/messages.dart`

- `MessageKey` enum — 37+ compile-time keys organised by category
  (`statusStep*`, `error*`, `chat*`, `library*`, `settings*`)
- `AppMessages` class — `const Map<MessageKey, String>` for static strings + static methods
  for interpolated strings (e.g. `AppMessages.statusTextExtracted(int chars)`)
- **All Vietnamese strings removed** from the UI layer and replaced with English constants

### 2. Logging Layer — `lib/services/logger_service.dart`

- `LogCategory` enum: `ui`, `network`, `parse`, `cache`, `other`
- `AppLogger.log(message, category: LogCategory.x, error: e, stackTrace: s)`
- Wraps `dart:developer.log()` with a name tag `paper2obsidian.<category>`
- Filter by tag in Flutter DevTools → Console

### 3. Exception Layer — `lib/exceptions/user_facing_exception.dart`

- `UserFacingException` — carries `userMessage` (shown in UI) + `technicalError` (logged)
- `toString()` returns `userMessage` so existing `catch (e)` / `'$e'` call sites show the
  friendly message without any change to callers

---

## Files Changed

| File | Change |
|------|--------|
| `lib/constants/messages.dart` | **NEW** — all user-facing strings |
| `lib/services/logger_service.dart` | **NEW** — AppLogger wrapper |
| `lib/exceptions/user_facing_exception.dart` | **NEW** — UserFacingException |
| `lib/controllers/paper_controller.dart` | Replace `onLog('...')` → `AppMessages.*`; `debugPrint` → `AppLogger`; remove Vietnamese comments |
| `lib/screens/main_screen.dart` | Replace all hardcoded strings → `AppMessages.*`; replace `debugPrint` → `AppLogger`; remove Vietnamese |
| `lib/widgets/chat_tab.dart` | Replace Vietnamese suggestion chips + UI strings → `AppMessages.*` |
| `lib/widgets/library_tab.dart` | Replace Vietnamese tooltip + empty-state → `AppMessages.*` |
| `lib/widgets/actions_panel.dart` | Remove Vietnamese comment |
| `lib/widgets/metadata_tab.dart` | Remove Vietnamese comment |
| `lib/services/api_service.dart` | Add `AppLogger` to all catch blocks |
| `lib/services/bedrock_client.dart` | Add `AppLogger` on HTTP error responses |

---

## Key Patterns

### Adding a new user-facing string

```dart
// 1. Add a key to the enum in messages.dart
enum MessageKey {
  // ...
  myNewMessage,
}

// 2. Add the string to _map in AppMessages
MessageKey.myNewMessage: 'Your friendly English message here.',

// 3. Use it in UI/controller code
onLog(AppMessages.get(MessageKey.myNewMessage));
```

### Logging a technical error (never shown to users)

```dart
AppLogger.log(
  'Descriptive context for the developer',
  category: LogCategory.network,  // or parse / ui / cache / other
  error: e,
  stackTrace: stackTrace,
);
```

### Interpolated strings

```dart
// In AppMessages:
static String statusTextExtracted(int chars) =>
    '✅ Text extracted ($chars chars).';

// Usage:
onLog(AppMessages.statusTextExtracted(fullPdfText.length));
```

---

## Tradeoffs

- **No file logging** in this phase — `dart:developer.log()` outputs to DevTools only;
  file/remote logging can be added as a future extension to `AppLogger`.
- **Developer discipline required** — no linter rule enforces `AppLogger` over `print()`,
  so code reviews must catch any regressions (see `CODE_REVIEW_CHECKLIST.md`).
- **No i18n yet** — `AppMessages` is structured to make a future `intl` migration
  straightforward (swap `_map` lookup for `Intl.message()` calls).
