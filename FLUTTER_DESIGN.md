# Flutter Design System

This document converts `DESIGN.md` into Flutter design tokens and theme rules for this app.

Principles:
- Use the source values from `DESIGN.md` where available.
- If Flutter needs a value that is not explicitly defined in `DESIGN.md`, use a reasonable fallback and mark it as `fallback`.
- Do not hardcode visual values inside screens. Add tokens to the theme layer first, then consume them from UI.

## 1. Color Tokens

Map these values into `AppColors` and expose them through `ThemeData` where appropriate.

```dart
class AppColors {
  static const Color primary = Color(0xFF111111);
  static const Color background = Color(0xFFF4F0E8);
  static const Color backgroundDark = Color(0xFF111111);

  static const Color textPrimary = Color(0xFF111111);
  static const Color textSecondary = Color(0xFF5C5C5C);
  static const Color textMuted = Color(0xFF666666);
  static const Color textInverse = Color(0xFFF4F0E8);

  static const Color accent = Color(0xFF5B0000);

  static const Color surfaceLight = Color(0xFFFDFCF9);
  static const Color surfaceNeutral = Color(0xFFECE8E1);
  static const Color border = Color(0xFFD8D2C8);

  static const Color primaryHover = Color(0xFF333333); // fallback: inferred in DESIGN.md
  static const Color secondaryHoverBackground = Color(0xFFECE8E1); // fallback: inferred in DESIGN.md
  static const Color secondaryActiveBackground = Color(0xFFD8D2C8); // fallback: inferred in DESIGN.md

  static const Color linkHover = Color(0xFF5B0000); // fallback: inferred in DESIGN.md
  static const Color linkVisited = Color(0xFF666666); // fallback: inferred in DESIGN.md

  static const Color focusRing = Color(0x33111111); // fallback: from rgba(17, 17, 17, 0.2)
  static const Color disabledOverlay = Color(0x80111111); // fallback: maps web opacity 0.5 to Flutter usage

  static const Color success = Color(0xFF2F6B2F); // fallback: app semantic state
  static const Color successSurface = Color(0xFFEAF3EA); // fallback: app semantic state
  static const Color warning = Color(0xFF9A5A00); // fallback: app semantic state
  static const Color warningSurface = Color(0xFFF6E8D1); // fallback: app semantic state
  static const Color error = Color(0xFF8A1F1F); // fallback: app semantic state
  static const Color errorSurface = Color(0xFFF7E5E5); // fallback: app semantic state
  static const Color infoSurface = Color(0xFFECE8E1); // fallback: app semantic state
}
```

Suggested Flutter `ColorScheme` mapping:

```dart
final colorScheme = ColorScheme(
  brightness: Brightness.light,
  primary: AppColors.primary,
  onPrimary: AppColors.textInverse,
  secondary: AppColors.accent,
  onSecondary: AppColors.textInverse,
  error: AppColors.accent, // fallback: no dedicated error color in source
  onError: AppColors.textInverse, // fallback
  surface: AppColors.surfaceLight,
  onSurface: AppColors.textPrimary,
  background: AppColors.background,
  onBackground: AppColors.textPrimary,
);
```

## 2. Typography

Map typography into `TextTheme`. Source fonts:
- Display: `Cormorant Garamond`
- All other text: `Inter`
- Monospace: `ui-monospace`

Notes:
- Flutter does not have direct `H1/H2/H3/H4` slots, so map to the closest `TextTheme` roles.
- Uppercase behavior should be applied in widget content where required; do not bake uppercase into the `TextStyle`.

```dart
final textTheme = TextTheme(
  displayLarge: TextStyle(
    fontFamily: 'CormorantGaramond',
    fontSize: 88,
    fontWeight: FontWeight.w400,
    height: 1.2,
    color: AppColors.textPrimary,
  ),
  headlineLarge: TextStyle(
    fontFamily: 'Inter',
    fontSize: 48,
    fontWeight: FontWeight.w500,
    height: 1.2,
    color: AppColors.textPrimary,
  ),
  headlineMedium: TextStyle(
    fontFamily: 'Inter',
    fontSize: 28,
    fontWeight: FontWeight.w500,
    height: 1.2,
    color: AppColors.textPrimary,
  ),
  titleMedium: TextStyle(
    fontFamily: 'Inter',
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.2,
    letterSpacing: 0.13 * 13, // 0.1em from source
    color: AppColors.textPrimary,
  ),
  titleSmall: TextStyle(
    fontFamily: 'Inter',
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.2,
    letterSpacing: 0.2 * 11, // 0.2em from source
    color: AppColors.textPrimary,
  ),
  bodyLarge: TextStyle(
    fontFamily: 'Inter',
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: AppColors.textPrimary,
  ),
  bodyMedium: TextStyle(
    fontFamily: 'Inter',
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: AppColors.textSecondary,
  ),
  bodySmall: TextStyle(
    fontFamily: 'Inter',
    fontSize: 11,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: AppColors.textMuted,
  ),
  labelLarge: TextStyle(
    fontFamily: 'Inter',
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.2,
    color: AppColors.textPrimary,
  ),
  labelMedium: TextStyle(
    fontFamily: 'Inter',
    fontSize: 12, // fallback: derived from button-small in source
    fontWeight: FontWeight.w500,
    height: 1.2,
    color: AppColors.textPrimary,
  ),
  labelSmall: TextStyle(
    fontFamily: 'Inter',
    fontSize: 11,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: AppColors.textMuted,
  ),
);
```

Monospace style:

```dart
const TextStyle appCodeStyle = TextStyle(
  fontFamily: 'ui-monospace',
  fontSize: 13,
  fontWeight: FontWeight.w400,
  height: 1.5,
  color: AppColors.textPrimary,
);
```

Responsive typography guidance:
- `displayLarge` 88 is desktop-first.
- On tablet/mobile, scale large display text down using responsive theme extensions or layout-aware widgets.
- `fallback`: use `displayLarge: 64` on tablet and `48` on mobile if a responsive display scale is needed and no app token exists yet.

## 3. Spacing Scale

Map into `AppSpacing`.

```dart
class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double section = 32;
  static const double sectionLarge = 48;
  static const double hero = 96;
}
```

Source scale:
- `4, 8, 12, 16, 20, 24, 32, 48, 96`

Usage guidance:
- `4`: icon-to-text gaps, tight inline spacing
- `8`: small gaps between related controls
- `12`: compact component padding
- `16`: standard content spacing
- `20`: medium control spacing
- `24`: card padding and content block spacing
- `32`: section padding and button horizontal padding
- `48`: major section spacing
- `96`: hero and large section separation

## 4. Border Radius Scale

Map into `AppRadius`.

```dart
class AppRadius {
  static const double sm = 4;
  static const double md = 4; // fallback: source only defines one radius
  static const double lg = 4; // fallback: source only defines one radius
}
```

Rule:
- Default component radius is `4`.
- If a component needs a different radius, add it to the token layer first. Do not invent per-screen radius values.

## 5. Shadow and Elevation

The source system is intentionally flat.

Token guidance:

```dart
class AppElevation {
  static const double level0 = 0;
  static const double level1 = 0; // fallback: keep flat by default
  static const double header = 0;
  static const double modal = 0;
}

class AppShadows {
  static const List<BoxShadow> none = [];

  static const List<BoxShadow> cardHover = [
    BoxShadow(
      color: Color(0x0D000000), // fallback: maps rgba(0,0,0,0.05)
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];
}
```

Rules:
- Default cards and surfaces use no shadow.
- Elevation is expressed mostly through border, contrast, spacing, and occasional hover motion.
- `fallback`: if desktop hover states are implemented in Flutter, use `AppShadows.cardHover` plus a slight upward translation.

Semantic feedback tokens:
- Success text/background should use `AppColors.success` and `AppColors.successSurface` (`fallback`)
- Warning text/background should use `AppColors.warning` and `AppColors.warningSurface` (`fallback`)
- Error text/background should use `AppColors.error` and `AppColors.errorSurface` (`fallback`)
- Neutral informational states may use `AppColors.infoSurface` (`fallback`)

## 6. Button Style

Use `ElevatedButtonThemeData`, `OutlinedButtonThemeData`, and optionally a compact button variant token.

Primary button:

```dart
final elevatedButtonTheme = ElevatedButtonThemeData(
  style: ElevatedButton.styleFrom(
    backgroundColor: AppColors.primary,
    foregroundColor: AppColors.textInverse,
    disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5), // fallback
    disabledForegroundColor: AppColors.textInverse.withValues(alpha: 0.5), // fallback
    elevation: 0,
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.section,
      vertical: AppSpacing.md,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.sm),
    ),
    textStyle: const TextStyle(
      fontFamily: 'Inter',
      fontSize: 13,
      fontWeight: FontWeight.w500,
      height: 1.2,
    ),
  ),
);
```

Secondary button:

```dart
final outlinedButtonTheme = OutlinedButtonThemeData(
  style: OutlinedButton.styleFrom(
    foregroundColor: AppColors.primary,
    backgroundColor: Colors.transparent,
    side: const BorderSide(
      color: AppColors.border,
      width: 1,
    ),
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.section,
      vertical: AppSpacing.md,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.sm),
    ),
    textStyle: const TextStyle(
      fontFamily: 'Inter',
      fontSize: 13,
      fontWeight: FontWeight.w500,
      height: 1.2,
    ),
  ),
);
```

Small button variant:

```dart
const EdgeInsets smallButtonPadding = EdgeInsets.symmetric(
  horizontal: AppSpacing.xl,
  vertical: AppSpacing.sm,
);

const TextStyle smallButtonTextStyle = TextStyle(
  fontFamily: 'Inter',
  fontSize: 12,
  fontWeight: FontWeight.w500,
  height: 1.2,
);
```

Interaction rules:
- Hover background for primary: `AppColors.primaryHover`
- Hover background for secondary: `AppColors.secondaryHoverBackground`
- Pressed background for secondary: `AppColors.secondaryActiveBackground`
- `fallback`: use `WidgetStateProperty.resolveWith` to express hover/pressed states in Flutter

## 7. TextField Style

Use `InputDecorationTheme`.

```dart
final inputDecorationTheme = InputDecorationTheme(
  filled: true,
  fillColor: AppColors.background,
  contentPadding: const EdgeInsets.symmetric(
    horizontal: AppSpacing.md,
    vertical: 10, // fallback: source gives 10px vertical input padding
  ),
  hintStyle: const TextStyle(
    fontFamily: 'Inter',
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: AppColors.textMuted,
  ),
  labelStyle: const TextStyle(
    fontFamily: 'Inter',
    fontSize: 14, // fallback: inferred in DESIGN.md
    fontWeight: FontWeight.w500, // fallback: inferred in DESIGN.md
    color: AppColors.textPrimary,
  ),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadius.sm),
    borderSide: const BorderSide(
      color: AppColors.border,
      width: 1,
    ),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadius.sm),
    borderSide: const BorderSide(
      color: AppColors.border,
      width: 1,
    ),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadius.sm),
    borderSide: const BorderSide(
      color: AppColors.primary,
      width: 1,
    ),
  ),
  disabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadius.sm),
    borderSide: const BorderSide(
      color: AppColors.border,
      width: 1,
    ),
  ),
);
```

Focus rule:
- The source uses a `2px` focus ring with `rgba(17, 17, 17, 0.2)`.
- `fallback`: in Flutter, add focus emphasis with a surrounding container, theme extension, or custom field wrapper when exact ring behavior is required.

Disabled rule:
- Disabled fields should visually reduce emphasis and may use `AppColors.surfaceNeutral` as fill.
- `fallback`: source implies disabled styling but does not provide a separate disabled token.

## 8. Card Style

Use `CardThemeData`.

```dart
final cardTheme = CardThemeData(
  color: AppColors.surfaceNeutral,
  elevation: AppElevation.level0,
  margin: EdgeInsets.zero,
  shape: RoundedRectangleBorder(
    side: const BorderSide(
      color: AppColors.border,
      width: 1,
    ),
    borderRadius: BorderRadius.circular(AppRadius.sm),
  ),
);
```

Card content guidance:
- Default internal padding: `AppSpacing.xxl`
- Default text color inside cards: `AppColors.textSecondary`
- Default shadow: none
- `fallback`: if hoverable desktop cards are needed, animate vertical offset by `-2` and apply `AppShadows.cardHover`

## 9. Bottom Navigation Style

No bottom navigation is defined in `DESIGN.md`.

Flutter guidance if bottom navigation is needed:

```dart
final bottomNavigationBarTheme = BottomNavigationBarThemeData(
  backgroundColor: AppColors.background,
  selectedItemColor: AppColors.primary,
  unselectedItemColor: AppColors.textSecondary,
  selectedLabelStyle: const TextStyle(
    fontFamily: 'Inter',
    fontSize: 13, // fallback
    fontWeight: FontWeight.w500,
    height: 1.2,
  ),
  unselectedLabelStyle: const TextStyle(
    fontFamily: 'Inter',
    fontSize: 13, // fallback
    fontWeight: FontWeight.w400,
    height: 1.2,
  ),
  type: BottomNavigationBarType.fixed, // fallback
  elevation: 0,
);
```

Bottom navigation rules:
- Mark all values above as `fallback` because the source only defines top navigation.
- Prefer a top app bar or drawer first if that aligns better with the original design.

## 10. Navigation and App Bar

Since the source defines a top navigation bar, map that to Flutter app structure.

Suggested app bar tokens:
- Background: `AppColors.background`
- Foreground/content: `AppColors.textPrimary`
- Bottom border: `1px` `AppColors.surfaceNeutral` (`fallback`: implement with `Divider` or custom bottom border)
- Horizontal padding: `48` (`fallback`: from inferred source layout)
- Vertical padding: `24` (`fallback`: from inferred source layout)
- Elevation: `0`

Navigation link text:
- Default: `TextTheme.bodyLarge` or `bodyMedium` with `AppColors.textPrimary`
- Active: same size, `FontWeight.w500`
- Hover: `AppColors.textSecondary` (`fallback`: inferred in source)

## 11. Motion

Motion values from source:
- Fast: `200ms`
- Base: `400ms`
- Slow: `1000ms`
- Curve: `Curves.easeOut` as Flutter equivalent

Suggested tokens:

```dart
class AppMotion {
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration base = Duration(milliseconds: 400);
  static const Duration slow = Duration(milliseconds: 1000);
  static const Curve standard = Curves.easeOut;
}
```

## 12. Responsive Rules

Support mobile and tablet at minimum.

Use these behavior rules:
- Use `LayoutBuilder` when layout structure changes.
- Below tablet widths, stack cards and form layouts vertically.
- Reduce large section spacing from `96` to `48` or `32` on small screens.
- Scale down display typography on smaller screens.
- Keep touch targets at least `44x44` (`fallback`: best-practice value noted in source, not a direct extracted token).

Suggested working breakpoints:
- Mobile: `< 768`
- Tablet: `>= 768` and `< 1024`
- Desktop: `>= 1024`

All breakpoint values above are `fallback` because the source marks them as suggested and inferred.

## 13. Rules for Using the Design System

Always:
- Use `AppColors`, `AppSpacing`, `AppRadius`, `AppTypography`, and `AppTheme`.
- Use `Theme.of(context)` plus theme tokens instead of inline visual values.
- Reuse shared widgets from `shared/widgets` and `shared/components` before creating new UI primitives.
- Keep the UI flat and restrained. Prefer spacing, borders, and typography over decorative effects.
- Use `Cormorant Garamond` only for major display text.
- Use `Inter` for headings, labels, buttons, body text, and forms.
- Keep body text at `16` with `1.5` line height unless a documented token says otherwise.
- Use the defined spacing scale only: `4, 8, 12, 16, 20, 24, 32, 48, 96`.
- Use `4` radius for buttons, cards, and text fields unless a new token is added first.

Never:
- Never use `Color(...)` directly in screens.
- Never use raw `TextStyle(fontSize: ...)` directly in screens.
- Never use raw `EdgeInsets` values that are not backed by `AppSpacing`.
- Never add shadows by default to cards or surfaces.
- Never introduce new weights such as `700` for display styles unless the source design is updated.
- Never use low-contrast colors like `AppColors.border` for regular text on `AppColors.background`.
- Never invent component variants inside feature screens. Add them to the shared design system first.

## 14. Implementation Order

When a token or component theme is missing:
1. Update this file.
2. Add the token to the theme layer (`AppColors`, `AppSpacing`, `AppRadius`, `AppTypography`, `AppTheme`).
3. Apply it from shared components or feature UI.

Do not skip the token layer and style widgets ad hoc in screens.
