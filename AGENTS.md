# Flutter Design System Rules

This project follows DESIGN.md and FLUTTER_DESIGN.md.

## Design System

* Always follow FLUTTER_DESIGN.md before creating UI.
* Never hardcode colors.
* Never hardcode font sizes.
* Never hardcode spacing values.
* Never hardcode border radius values.

Use:

* AppColors
* AppSpacing
* AppRadius
* AppTypography
* AppTheme

## UI Components

Before creating a new widget, check:

* shared/widgets
* shared/components

Prefer reusable widgets over duplicated code.

## Architecture

Follow Clean Architecture:

* presentation
* application
* domain
* infrastructure

Feature-first structure:

lib/features/{feature_name}

## State Management

Use Riverpod.

Avoid:

* setState for business logic
* global mutable state

## Styling

All screens must use:

Theme.of(context)
AppColors
AppTypography
AppSpacing

Do not use:

Color(...)
EdgeInsets.all(16)
TextStyle(fontSize: 14)

directly inside screens.

## Responsive

Support:

* Mobile
* Tablet

Use LayoutBuilder when necessary.

## Generated Code Rules

When a required design token is missing:

1. Update FLUTTER_DESIGN.md
2. Create token in theme layer
3. Use token in UI

Never invent random styles inside screens.
