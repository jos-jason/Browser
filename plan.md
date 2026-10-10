# Gesture Shortcuts Feature — Implementation Plan

## Overview
Add an invisible drawing canvas to the home screen (the area below the search bar). When the user draws a shape with their finger, the app recognizes it and navigates to the corresponding favorite website. The canvas is invisible until the user starts drawing, at which point a sparkly turquoise trail follows their finger. On recognition, the site name briefly flashes before navigating.

---

## New File: `GestureShortcuts.swift`

This single new file will contain all the gesture shortcut logic: the data model, the recognizer, and the canvas view.

### 1. `GestureShortcut` Model
- Simple struct: `shape` (enum), `label` (String), `url` (URL), `systemIcon` (String)
- `GestureShape` enum with cases: `circle`, `triangle`, `square`, `zigzag`, `checkmark`
- A static `defaults` array providing 5 hardcoded mappings:
  - **Circle** → Google (`google.com`)
  - **Triangle** → YouTube (`youtube.com`)
  - **Square** → Reddit (`reddit.com`)
  - **Zigzag (lightning)** → Wikipedia (`wikipedia.org`)
  - **Checkmark** → GitHub (`github.com`)

### 2. `GestureRecognizer` (struct with static methods)
Analyzes an array of `CGPoint` to classify the drawn shape. The approach:

- **Preprocessing**: Resample the raw points to ~64 evenly-spaced points, normalize into a unit bounding box.
- **Corner detection**: Walk the resampled points, compute the angle change at each point. Points where the cumulative direction change exceeds a threshold (~40°) are "corners."
- **Classification logic** (checked in order):
  - **Circle**: Shape is closed (start ≈ end), few sharp corners (≤1), and the path wraps roughly 360°. Validate by checking the ratio of the area to the bounding box area (circularity).
  - **Triangle**: 3 corners detected, shape is roughly closed.
  - **Square/Rectangle**: 4 corners detected, shape is roughly closed, corner angles are roughly 90°.
  - **Checkmark**: 1 corner, shape is open, the first segment goes downward-right and the second goes upward-right (a "V" rotated).
  - **Zigzag**: 3+ corners, shape is open, alternating up-down direction changes.
- Returns an optional `GestureShape` (nil if no confident match).

### 3. `GestureCanvasView` (SwiftUI View)
- **State**: `@State var points: [CGPoint]`, `@State var recognizedShape: GestureShape?`, `@State var isDrawing: Bool`
- **Gesture**: A `DragGesture(minimumDistance: 10)` that:
  - `onChanged`: appends each point to the array, sets `isDrawing = true`
  - `onEnded`: runs the recognizer on the collected points, sets `recognizedShape` if matched
- **Drawing the trail**: A `Canvas` view that draws the points as a path. The stroke style:
  - Main line: `Color.tealAccent` (~turquoise) at ~2pt width, with slight opacity variation
  - "Sparkle" effect: At intervals along the path, draw tiny dots/circles of varying size and opacity slightly offset from the line — gives it a sparse magical/sparkly feel without being heavy
  - The trail fades out over ~0.5s after the finger lifts (using an opacity animation)
- **Recognition feedback**: When a shape is recognized:
  - If "quick navigate" setting is ON → immediately call the navigation callback
  - If OFF → briefly show the matched site name + icon (centered, ~0.8s) with a scale-in animation, then call the navigation callback
- **Props**: Takes a `shortcuts: [GestureShortcut]` array and an `onNavigate: (URL) -> Void` closure
- **Hit testing**: The canvas uses `.contentShape(Rectangle())` so the entire area is tappable, but it doesn't visually alter the background — the cream color shows through

### 4. Sparkle Trail Rendering Detail
- The main stroke: `Color(red: 0.35, green: 0.67, blue: 0.64)` (matches existing `tealAccent`) at ~2.5pt, opacity 0.7
- Sparkle dots: Every ~20pt along the path, draw 1-2 small circles (radius 1-3pt) at random slight offsets (±3pt perpendicular to the stroke direction), with opacity 0.3-0.8, using a slightly lighter turquoise
- This gives a "sparse magical" look without being busy

---

## Changes to `ContentView.swift`

### In `ContentView` (the home page)
- Add the `GestureCanvasView` as an overlay/background of the area below the search bar
- Specifically: place it in the lower `Spacer()` area (line ~749), or wrap the bottom spacer in a `ZStack` with the canvas behind it
- The canvas fills all available space below the search bar + Go button, but is visually invisible until a finger touches
- Wire `onNavigate` to set `webItem = IdentifiableURL(url:)` — the same mechanism the search bar uses
- Gate the entire canvas on the `gestureShortcutsEnabled` AppStorage setting

### In `SettingsView`
Add a new "Gesture Shortcuts" section (below the existing "Privacy" section) with:
- **Toggle: "Gesture Shortcuts"** — enables/disables the feature entirely (`@AppStorage("gestureShortcutsEnabled")`, default: `true`)
- **Toggle: "Quick Navigate"** — when ON, skips the name/icon flash and navigates immediately on recognition (`@AppStorage("gestureQuickNavigate")`, default: `false`)
- **Legend display**: A small grid/list showing each shape's icon + name + mapped website, so users know what shapes are available. Uses SF Symbols for the shape icons (e.g., `circle`, `triangle`, `square`, `bolt.fill`, `checkmark`)

---

## Files Touched

| File | Change |
|------|--------|
| `Browser/Browser/GestureShortcuts.swift` | **NEW** — model, recognizer, canvas view |
| `Browser/Browser/ContentView.swift` | Add canvas to home screen, add settings section |

---

## Summary of Settings Added
- `gestureShortcutsEnabled` (Bool, default `true`) — master on/off
- `gestureQuickNavigate` (Bool, default `false`) — skip animation, navigate immediately

## No External Dependencies
Everything uses built-in SwiftUI (`Canvas`, `DragGesture`, `Path`) and basic geometry math. No ML frameworks, no third-party packages.
