---
name: SLRS
url: https://slr.hyperdatalab.org/
colors:
  primary: '#111111'
  background: '#f4f0e8'
  background-dark: '#111111'
  text-primary: '#111111'
  text-secondary: '#5c5c5c'
  text-muted: '#666666'
  text-inverse: '#f4f0e8'
  accent: '#5b0000'
  surface-light: '#fdfcf9'
  surface-neutral: '#ece8e1'
  border: '#d8d2c8'
  primary-hover: '#333333' # Inferred for primary button hover
  secondary-hover-bg: '#ece8e1' # Inferred for secondary button hover
  secondary-active-bg: '#d8d2c8' # Inferred for secondary button active
  link-hover: '#5b0000' # Inferred for link hover
  link-visited: '#666666' # Inferred for link visited
typography:
  display:
    family: 'Cormorant Garamond'
    size: 88px
    weight: 400
    line-height: 1.2
  heading-h1:
    family: 'Inter'
    size: 48px
    weight: 500
    line-height: 1.2
  heading-h2:
    family: 'Inter'
    size: 28px
    weight: 500
    line-height: 1.2
  heading-h3:
    family: 'Inter'
    size: 13px
    weight: 500
    line-height: 1.2
  heading-h4:
    family: 'Inter'
    size: 11px
    weight: 500
    line-height: 1.2
  body:
    family: 'Inter'
    size: 16px
    weight: 400
    line-height: 1.5
  caption:
    family: 'Inter'
    size: 11px
    weight: 400
    line-height: 1.5
  code:
    family: 'ui-monospace'
    size: 13px
    weight: 400
    line-height: 1.5
spacing:
  base: 4px
  scale: [4, 8, 12, 16, 20, 24, 32, 48, 96]
radius:
  sm: 4px
elevation:
  header:
    z: 100
  modal:
    z: 9999
components:
  button-primary:
    bg: '{colors.primary}'
    text: '{colors.text-inverse}'
    radius: '{radius.sm}'
    padding: '12px 32px'
    font-weight: 500
    font-size: 13px
  button-secondary:
    bg: 'transparent'
    text: '{colors.primary}'
    border: '1px solid {colors.border}'
    radius: '{radius.sm}'
    padding: '12px 32px'
    font-weight: 500
    font-size: 13px
  button-small:
    bg: '{colors.primary}'
    text: '{colors.text-inverse}'
    radius: '{radius.sm}'
    padding: '8px 20px'
    font-weight: 500
    font-size: 12px
motion:
  duration-fast: '0.2s'
  duration-base: '0.4s'
  duration-slow: '1s'
  easing-standard: 'ease-out'
---

# Design System Inspired by SLRS

## 1. Visual Theme & Atmosphere
The SLRS design system establishes a sophisticated and academic aesthetic through a warm, muted color palette and a clear typographic hierarchy. The primary background color, a subtle `#f4f0e8` off-white, provides a soft canvas for the dark `#111111` primary text and interactive elements. This contrast is balanced by the elegant serif `Cormorant Garamond` font used for large display headings, set at 88px with a 400 weight, paired with the highly legible sans-serif `Inter` for all other textual content. Minimal use of shadows maintains a clean, flat appearance, while subtle `0.2s ease-out` transitions on interactive elements provide a refined user experience.

The visual identity is further defined by monochrome line iconography and a structured layout that emphasizes ample whitespace, contributing to a sense of clarity and professionalism. A dark section background of `#111111` with `#f4f0e8` inverse text creates a strong visual break, adding depth without relying on complex gradients or heavy graphical elements. The overall impression is one of rigorous academic precision delivered with understated elegance, with no complex animations detected beyond subtle CSS transitions.

Key Characteristics:
- Warm, muted `#f4f0e8` background palette.
- Elegant `Cormorant Garamond` display typography.
- Clear `Inter` sans-serif for body and headings.
- Subtle `0.2s ease-out` transitions on interactions.
- Monochrome line iconography for clarity.
- Structured layout with generous 24px+ whitespace.
- Strong `#111111` dark sections with inverse text.

## 2. Color Palette & Roles
- **Primary** (`#111111`) — The dominant dark color used for primary text, main call-to-action buttons, and as a background for prominent sections.
- **Background** (`#f4f0e8`) — The main light background color for the overall page, providing a warm, neutral canvas.
- **Background Dark** (`#111111`) — Used for sections requiring high contrast or visual emphasis, typically paired with inverse text.
- **Text Primary** (`#111111`) — Standard color for main headings and body text on light backgrounds.
- **Text Secondary** (`#5c5c5c`) — Used for secondary text, descriptions, and less emphasized content on light backgrounds.
- **Text Muted** (`#666666`) — A softer dark gray for tertiary text, footnotes, or subtle hints.
- **Text Inverse** (`#f4f0e8`) — Used for text placed on dark backgrounds, such as the primary button or dark sections.
- **Accent** (`#5b0000`) — A deep red used sparingly for small accent text or potentially error states.
- **Surface Light** (`#fdfcf9`) — A very light, almost white, background used for subtle lifts or contained elements.
- **Surface Neutral** (`#ece8e1`) — A neutral off-white used for subtle background variations, borders, or hover states.
- **Border** (`#d8d2c8`) — A light, subtle gray used for borders around interactive elements or containers.
- **Primary Hover** (`#333333`) — The inferred darker shade for primary button hover states.
- **Secondary Hover Background** (`#ece8e1`) — The inferred background color for secondary button hover states.
- **Secondary Active Background** (`#d8d2c8`) — The inferred background color for secondary button active states.
- **Link Hover** (`#5b0000`) — The inferred accent color for interactive link hover states.
- **Link Visited** (`#666666`) — The inferred muted text color for visited links.

## 3. Typography Rules
- **Font Family**: Primary content is set in `Inter`, with `Cormorant Garamond` for display headings. Monospace content uses `ui-monospace`.
- **Hierarchy**:
  - **Display**: `Cormorant Garamond` `88px` `400` · line-height `1.2` · tracking `normal` · Used for prominent hero sections.
  - **H1**: `Inter` `48px` `500` · line-height `1.2` · tracking `normal` · Main section titles.
  - **H2**: `Inter` `28px` `500` · line-height `1.2` · tracking `normal` · Sub-section headings.
  - **H3**: `Inter` `13px` `500` · line-height `1.2` · tracking `0.1em` · uppercase · Used for feature titles.
  - **H4**: `Inter` `11px` `500` · line-height `1.2` · tracking `0.2em` · uppercase · Used for step titles in workflows.
  - **Body**: `Inter` `16px` `400` · line-height `1.5` · tracking `normal` · Standard paragraph text.
  - **Caption**: `Inter` `11px` `400` · line-height `1.5` · tracking `normal` · Small descriptive text.
  - **Code/Mono**: `ui-monospace` `13px` `400` · line-height `1.5` · tracking `normal` · For code snippets or technical labels.
- **Principles**:
  - **Serif for Impact**: `Cormorant Garamond` is reserved for the largest, most impactful display text, emphasizing elegance and academic authority.
  - **Sans-serif for Readability**: `Inter` is the workhorse font, used across all body text and hierarchical headings to ensure optimal readability and modern clarity.
  - **Controlled Tracking**: Headings H3 and H4 use subtle letter-spacing (`0.1em` and `0.2em` respectively) and are uppercase to add structure and visual distinction.
  - **Generous Line Height**: A consistent line-height of `1.5` for body and caption text ensures comfortable reading, especially in longer passages.

## 4. Component Stylings

### Buttons
Buttons convey calls to action with clear visual hierarchy and subtle interaction feedback.

#### Primary Button
A solid dark button for primary actions, providing high contrast against light backgrounds.
```css
.button-primary {
  background-color: var(--color-primary, #111111);
  color: var(--color-text-inverse, #f4f0e8);
  font-family: var(--typography-body-family, 'Inter');
  font-size: 13px;
  font-weight: 500;
  padding: 12px 32px;
  border: none;
  border-radius: var(--radius-sm, 4px);
  cursor: pointer;
  transition: background-color var(--motion-duration-fast, 0.2s) var(--motion-easing-standard, ease-out);
}

.button-primary:hover {
  background-color: var(--color-primary-hover, #333333); /* inferred from screenshot */
}

.button-primary:active {
  background-color: var(--color-background-dark, #111111); /* inferred from screenshot */
  transform: translateY(1px); /* inferred from screenshot */
}

.button-primary:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}
```

#### Secondary Button
A transparent button with a light border for secondary actions, offering a less prominent visual presence.
```css
.button-secondary {
  background-color: transparent;
  color: var(--color-primary, #111111);
  font-family: var(--typography-body-family, 'Inter');
  font-size: 13px;
  font-weight: 500;
  padding: 12px 32px;
  border: 1px solid var(--color-border, #d8d2c8);
  border-radius: var(--radius-sm, 4px);
  cursor: pointer;
  transition: background-color var(--motion-duration-fast, 0.2s) var(--motion-easing-standard, ease-out),
              border-color var(--motion-duration-fast, 0.2s) var(--motion-easing-standard, ease-out);
}

.button-secondary:hover {
  background-color: var(--color-secondary-hover-bg, #ece8e1); /* inferred from screenshot */
  border-color: var(--color-secondary-hover-bg, #ece8e1); /* inferred from screenshot */
}

.button-secondary:active {
  background-color: var(--color-secondary-active-bg, #d8d2c8); /* inferred from screenshot */
  border-color: var(--color-secondary-active-bg, #d8d2c8); /* inferred from screenshot */
  transform: translateY(1px); /* inferred from screenshot */
}

.button-secondary:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}
```

#### Small Button
A compact dark button for less critical actions like "Sign In" in the header.
```css
.button-small {
  background-color: var(--color-primary, #111111);
  color: var(--color-text-inverse, #f4f0e8);
  font-family: var(--typography-body-family, 'Inter');
  font-size: 12px;
  font-weight: 500;
  padding: 8px 20px;
  border: none;
  border-radius: var(--radius-sm, 4px);
  cursor: pointer;
  transition: background-color var(--motion-duration-fast, 0.2s) var(--motion-easing-standard, ease-out);
}

.button-small:hover {
  background-color: var(--color-primary-hover, #333333); /* inferred from screenshot */
}

.button-small:active {
  background-color: var(--color-background-dark, #111111); /* inferred from screenshot */
  transform: translateY(1px); /* inferred from screenshot */
}

.button-small:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}
```

### Cards & Containers

#### Standard Card
Used for the workflow visualization steps, these cards feature a light background and a subtle border, indicating distinct content blocks.
```css
.card {
  background-color: var(--color-surface-neutral, #ece8e1);
  color: var(--color-text-secondary, #5c5c5c);
  font-family: var(--typography-body-family, 'Inter');
  padding: 24px;
  border: 1px solid var(--color-border, #d8d2c8);
  border-radius: var(--radius-sm, 4px);
  box-shadow: none; /* As per extracted shadows */
  transition: transform var(--motion-duration-fast, 0.2s) var(--motion-easing-standard, ease-out),
              box-shadow var(--motion-duration-fast, 0.2s) var(--motion-easing-standard, ease-out);
}

.card:hover {
  transform: translateY(-2px); /* inferred from screenshot */
  box-shadow: 0px 2px 8px rgba(0,0,0,0.05); /* inferred from screenshot */
}
```

### Inputs & Forms

#### Text Input
A standard text input field with a light background and subtle border, designed for clear data entry.
```css
.text-input {
  background-color: var(--color-background, #f4f0e8);
  color: var(--color-text-primary, #111111);
  font-family: var(--typography-body-family, 'Inter');
  font-size: 16px;
  font-weight: 400;
  padding: 10px 12px; /* inferred from screenshot */
  border: 1px solid var(--color-border, #d8d2c8);
  border-radius: var(--radius-sm, 4px);
  transition: border-color var(--motion-duration-fast, 0.2s) var(--motion-easing-standard, ease-out),
              box-shadow var(--motion-duration-fast, 0.2s) var(--motion-easing-standard, ease-out);
}

.text-input:focus {
  outline: none;
  border-color: var(--color-primary, #111111); /* inferred from screenshot */
  box-shadow: 0 0 0 2px rgba(17, 17, 17, 0.2); /* inferred from screenshot */
}

.text-input:disabled {
  opacity: 0.5;
  cursor: not-allowed;
  background-color: var(--color-surface-neutral, #ece8e1); /* inferred from screenshot */
}
```

#### Form Label
Labels are visually distinct and clearly associated with their input fields.
```css
.form-label {
  color: var(--color-text-primary, #111111);
  font-family: var(--typography-body-family, 'Inter');
  font-size: 14px; /* inferred from screenshot */
  font-weight: 500; /* inferred from screenshot */
  margin-bottom: 8px;
  display: block;
  transition: color var(--motion-duration-fast, 0.2s) var(--motion-easing-standard, ease-out);
}
```

#### Checkbox/Radio
Custom-styled checkboxes and radio buttons for consistent form interactions.
```css
.checkbox-radio {
  appearance: none;
  width: 16px; /* inferred from screenshot */
  height: 16px; /* inferred from screenshot */
  border: 1px solid var(--color-border, #d8d2c8);
  border-radius: 2px; /* inferred from screenshot */
  background-color: var(--color-background, #f4f0e8);
  cursor: pointer;
  display: inline-block;
  vertical-align: middle;
  transition: background-color var(--motion-duration-fast, 0.2s) var(--motion-easing-standard, ease-out),
              border-color var(--motion-duration-fast, 0.2s) var(--motion-easing-standard, ease-out);
}

.checkbox-radio:checked {
  background-color: var(--color-primary, #111111);
  border-color: var(--color-primary, #111111);
  /* Checkmark icon would be added via ::before or background-image */
}

.checkbox-radio:focus {
  outline: 2px solid rgba(17, 17, 17, 0.2); /* inferred from screenshot */
  outline-offset: 2px;
}

.checkbox-radio:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

/* Radio buttons have a circular shape */
.radio {
  border-radius: 50%;
}

.radio:checked {
  background-color: var(--color-primary, #111111);
  border-color: var(--color-primary, #111111);
  /* Inner circle for radio button */
  position: relative;
}

.radio:checked::before {
  content: '';
  display: block;
  width: 8px; /* inferred from screenshot */
  height: 8px; /* inferred from screenshot */
  background-color: var(--color-text-inverse, #f4f0e8);
  border-radius: 50%;
  position: absolute;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%);
}
```

### Navigation

#### Top Navigation Bar
The main header bar provides site navigation and branding, maintaining a fixed position.
```css
.top-nav-bar {
  background-color: var(--color-background, #f4f0e8);
  border-bottom: 1px solid var(--color-surface-neutral, #ece8e1); /* inferred from screenshot */
  padding: 24px 48px; /* inferred from screenshot */
  display: flex;
  justify-content: space-between;
  align-items: center;
  position: sticky;
  top: 0;
  width: 100%;
  z-index: var(--elevation-header-z, 100);
}
```

#### Navigation Link
Individual links within the navigation bar, designed for clear interaction and active state indication.
```css
.nav-link {
  color: var(--color-text-primary, #111111);
  font-family: var(--typography-body-family, 'Inter');
  font-size: 16px;
  font-weight: 400;
  text-decoration: none;
  padding: 8px 12px; /* inferred from screenshot */
  transition: color var(--motion-duration-fast, 0.2s) var(--motion-easing-standard, ease-out);
}

.nav-link:hover {
  color: var(--color-text-secondary, #5c5c5c); /* inferred from screenshot */
}

.nav-link.active,
.nav-link[aria-current="page"] {
  font-weight: 500; /* inferred from screenshot */
  color: var(--color-primary, #111111);
}
```

#### Dropdown Menu
(None observed in source)

### Links

#### Standard Link
Inline text links, typically using the primary text color and providing visual feedback on hover.
```css
.standard-link {
  color: var(--color-text-primary, #111111); /* inferred from screenshot */
  text-decoration: none;
  transition: color var(--motion-duration-fast, 0.2s) var(--motion-easing-standard, ease-out),
              text-decoration var(--motion-duration-fast, 0.2s) var(--motion-easing-standard, ease-out);
}

.standard-link:hover {
  color: var(--color-link-hover, #5b0000); /* inferred from screenshot */
  text-decoration: underline;
}

.standard-link:visited {
  color: var(--color-link-visited, #666666); /* inferred from screenshot */
}
```

#### Secondary Link
Links used for less prominent actions or within muted content, using a secondary text color.
```css
.secondary-link {
  color: var(--color-text-secondary, #5c5c5c);
  text-decoration: none;
  transition: color var(--motion-duration-fast, 0.2s) var(--motion-easing-standard, ease-out),
              text-decoration var(--motion-duration-fast, 0.2s) var(--motion-easing-standard, ease-out);
}

.secondary-link:hover {
  color: var(--color-link-hover, #5b0000); /* inferred from screenshot */
  text-decoration: underline;
}

.secondary-link:visited {
  color: var(--color-link-visited, #666666); /* inferred from screenshot */
}
```

### Badges
(none observed in source)

## 5. Layout Principles
- **Spacing System**: The design system uses a base unit of `4px` with a comprehensive scale for consistent spacing.
  - Scale: `4px`, `8px`, `12px`, `16px`, `20px`, `24px`, `32px`, `48px`, `96px`.
  - Usage Context:
    - `4px`: Smallest element spacing, e.g., icon to text.
    - `8px`: Inline element separation, small vertical gaps.
    - `12px`: Padding within smaller components, list item spacing.
    - `16px`: Standard paragraph margins, input field padding.
    - `20px`: Button horizontal padding, moderate vertical spacing.
    - `24px`: Component internal padding, vertical spacing between related elements.
    - `32px`: Button horizontal padding, section internal padding.
    - `48px`: Section vertical padding, major element separation.
    - `96px`: Large section breaks, significant whitespace for visual breathing room.
- **Grid & Container**:
  - Max Width: `1280px` (inferred from screenshot)
  - Columns: `12` (inferred from screenshot)
  - Gutter: `24px` (inferred from screenshot)
  - Section Padding: `96px` vertical, `48px` horizontal (inferred from screenshot)
- **Whitespace Philosophy**: SLRS employs generous whitespace, particularly large vertical and horizontal padding around major sections and components. This creates a clean, uncluttered interface that enhances readability and directs user focus. The ample negative space contributes to the academic and sophisticated atmosphere, preventing visual fatigue.
- **Border Radius Scale**:
  - `sm`: `4px` — Applied consistently to all interactive elements like buttons, input fields, and cards for a subtly softened, modern aesthetic.

## 6. Depth & Elevation
The SLRS design system maintains a predominantly flat aesthetic, with minimal use of shadows. Elevation is primarily managed through `z-index` for stacking context.
- **Flat (z-0)**: `none` — Default state for most content, including cards and background elements.
- **Header (z-100)**: `none` — Used for the fixed top navigation bar to ensure it remains above scrolling content.
- **Modal (z-9999)**: `none` — Reserved for critical overlays like modals or tooltips to ensure they appear on top of all other content.

Shadow Philosophy: The design system intentionally avoids complex `box-shadow` properties, aligning with a clean, modern, and flat aesthetic. When elevation is required, it is subtly introduced via `transform` on hover for interactive elements or through `z-index` for stacking context, maintaining visual lightness and clarity.

## 7. Do's and Don'ts

### Do's
- **Do** use `Cormorant Garamond` `88px` `400` for the main display heading to convey academic elegance.
- **Do** ensure all body text uses `Inter` `16px` `400` with a line-height of `1.5` for optimal readability on `#f4f0e8` backgrounds.
- **Do** use `#111111` for primary button backgrounds and `#f4f0e8` for their text, ensuring a WCAG AAA contrast ratio of 16.61.
- **Do** maintain at least `24px` of vertical spacing between `Card` components to prevent visual clutter.
- **Do** apply a `4px` border-radius consistently to all `Button` and `Input` components.
- **Do** use `#5c5c5c` for secondary text on `#f4f0e8` backgrounds, which achieves a WCAG AA contrast ratio of 5.88.
- **Do** provide `12px 32px` padding for `Primary Button` and `Secondary Button` to ensure adequate touch targets and visual weight.
- **Do** use `1px solid #d8d2c8` for `Secondary Button` borders to define interactive areas without heavy fills.
- **Do** ensure `Text Input` fields display a `2px solid rgba(17, 17, 17, 0.2)` focus ring for accessibility.
- **Do** use `Inter` `13px` `500` uppercase with `0.1em` tracking for `H3` headings to create clear feature titles.

### Don'ts
- **Don't** use `#d8d2c8` for any text on `#f4f0e8` backgrounds, as its contrast ratio of 1.32 fails WCAG AA.
- **Don't** introduce custom spacing values; adhere strictly to the `4px`, `8px`, `12px`, `16px`, `20px`, `24px`, `32px`, `48px`, `96px` scale.
- **Don't** use `Inter` with a `700` weight for display headings, as the brand's extracted weights are `400` and `500`.
- **Don't** apply `box-shadow` effects to `Card` components in their default state; use `transform: translateY(-2px)` on hover for subtle interaction.
- **Don't** use `background-color: transparent` for `Primary Button` hover states; instead, transition to `#333333`.
- **Don't** use a `font-weight` other than `400` for `Body` text to maintain its light and readable appearance.
- **Don't** mix `Cormorant Garamond` with `Inter` for inline text within a single sentence or paragraph.
- **Don't** omit the `1px solid #d8d2c8` border on `Text Input` fields in their default state.
- **Don't** use `11px` text for body copy; `16px` is the minimum for standard paragraphs.
- **Don't** use the `#5b0000` accent color for large blocks of text; reserve it for small, specific accents.

## 8. Responsive Behavior
Note: breakpoints below are measured from the source's CSS.

- **Suggested Breakpoints**:
  - **Mobile Small** (~375px): Typography scales down; primary navigation collapses to a hamburger menu.
  - **Mobile Large** (~640px): Layout shifts to single-column; larger touch targets.
  - **Tablet** (~768px): Cards may arrange in two columns; increased horizontal padding.
  - **Desktop** (~1024px): Standard multi-column layouts; full navigation visible.
  - **Desktop Large** (~1440px): Max container width reached; increased whitespace.
- **Touch Targets**:
  - All interactive elements like `Button` and `Link` components should have a minimum tap area of `44px` by `44px` (inferred from best practices).
  - Ensure a minimum `8px` clear space around touch targets to prevent accidental taps (inferred from best practices).
- **Collapsing Strategy**:
  - **Navigation**: The `Top Navigation Bar` should transition from a horizontal list of `Navigation Link` items to a hamburger menu icon on viewports below `1024px`.
  - **Cards**: `Card` components, such as those in the workflow visualization, should stack vertically on mobile breakpoints (`<768px`).
  - **Typography**: `Display` and `Heading-H1` font sizes should scale down proportionally on smaller screens to prevent overflow and maintain hierarchy.
  - **Padding**: Section padding should reduce from `96px` vertical to `48px` or `32px` on mobile for better content density.
  - **Forms**: `Text Input` fields should occupy 100% width of their container on mobile devices.
  - **Spacing**: Larger spacing values (`48px`, `96px`) should be reduced to `24px` or `32px` on smaller viewports.

## 9. Agent Prompt Guide
- **Quick Color Reference**:
  - primary: `#111111`
  - background: `#f4f0e8`
  - background-dark: `#111111`
  - text-primary: `#111111`
  - text-secondary: `#5c5c5c`
  - text-muted: `#666666`
  - text-inverse: `#f4f0e8`
  - accent: `#5b0000`
  - surface-light: `#fdfcf9`
  - surface-neutral: `#ece8e1`
  - border: `#d8d2c8`
  - primary-hover: `#333333`
  - secondary-hover-bg: `#ece8e1`
  - secondary-active-bg: `#d8d2c8`
  - link-hover: `#5b0000`
  - link-visited: `#666666`
- **Iteration Guide**:
  1. Always use `Cormorant Garamond` `88px` `400` for the main hero text.
  2. All `Button` components must have a `4px` border-radius.
  3. `Primary Button` uses `12px 32px` padding and `background-color: #111111`.
  4. `Secondary Button` uses `1px solid #d8d2c8` border and transparent background.
  5. `Text Input` fields must show a `2px` dark focus ring on interaction.
  6. Ensure `Inter` `16px` `400` with `1.5` line-height is used for body text.
  7. Apply spacing from the `4px` base scale: `4, 8, 12, 16, 20, 24, 32, 48, 96`.
  8. The `Top Navigation Bar` has `z-index: 100` and a `1px` light bottom border.
  9. `Card` components should not have shadows by default, only subtle `translateY(-2px)` on hover.
  10. Text color `#d8d2c8` on background `#f4f0e8` is forbidden due to low contrast.
  11. On mobile, collapse navigation into a hamburger menu below `1024px`.
  12. Use `0.2s ease-out` for all micro-interactions and state changes.