# Architecture

## Shape

```
Sources/PodKit/            the library — everything with a decision in it
  Accessibility/           preferences, resolved style, announcements, timing
  Island/                  geometry, the panel, the controller
  Model/                   now playing, battery
  Views/                   SwiftUI, one file per surface
  Input/                   the global hotkey
  AppCoordinator.swift     wiring
Sources/Pod/Main.swift     the agent entry point, and nothing else
Tests/PodKitTests/         over PodKit
```

The split exists for one reason: a test target can import a library but not an
executable. So anything worth asserting lives in `PodKit`, and `Pod` is twelve
lines that hand it an `NSApplication`.

## Data flow

```
NSWorkspace ──▶ AccessibilityPreferencesObserver
                        │  (@Published preferences)
                        ▼
                 AppCoordinator ──▶ IslandController.updatePreferences
                        │                   │
BatteryMonitor ─────────┤                   ├─▶ style  (IslandStyle.resolve)
NowPlayingStore ────────┤                   ├─▶ state  (IslandState)
GlobalHotKey ───────────┘                   └─▶ announcements ─▶ VoiceOverSink
                        │
                        ▼
              IslandPanel  ◀── NotchGeometry.frame(forContentOfSize:)
                   └─ NSHostingView(IslandRootView)
```

The controller does not observe anything. Preferences arrive through
`updatePreferences`, which keeps Combine and `NSWorkspace` out of it and is
what makes the dismiss scheduling directly testable.

## Why the pure core

`NotchGeometry`, `IslandStyle`, `AnnouncementCoalescer` and `DismissPolicy` are
value types with no framework dependencies. That is not purity for its own
sake — it is what lets the suite cover the cases that are painful to reproduce
by hand: an external display with no camera housing, content larger than the
screen, a screen reader switched on halfway through a presentation, and all
sixteen combinations of the display accessibility settings.

The AppKit-facing pieces — `IslandPanel`, `AccessibilityPreferencesObserver`,
`VoiceOverSink`, `BatteryMonitor` — are kept thin for the same reason: there is
little in them left to get wrong.

## Concurrency

Swift 5 language mode, with `@MainActor` on everything that touches UI. This is
a deliberate holding position: the code is annotated as if it were in Swift 6
mode, so moving over should be mechanical, but the move is not part of the
first pass.
