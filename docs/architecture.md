# Architecture

## Shape

```
Sources/PodKit/            the library — everything with a decision in it
  Accessibility/           preferences, resolved style, announcements, timing
  Island/                  geometry, the panels and their Space, the controller
  Model/                   now playing, battery
  Views/                   SwiftUI, one file per surface
  Input/                   the global hotkey, the pointer
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
   IslandPanel  (shield + 1)  ─┐   one fixed canvas: NotchGeometry.canvasFrame
   IslandBackdropPanel (shield)┘   both in IslandSpace (private, absolute level 400)
        └─ IslandHostingView(IslandRootView, .content / .backdrop)
                  │  reads IslandLayout.geometry, reports IslandLayout.islandSize
                  ▼
   AppCoordinator ──▶ PointerTracker.region (HoverRegion over the island)
                  └─▶ grows the canvas if the island outgrows it

SystemPresenceObserver (lock, user switch, sleep, Space kind)
        └─▶ IslandWindowing.panelsBelongOnScreen ──▶ order the panels in / out
```

The controller does not observe anything. Preferences arrive through
`updatePreferences`, which keeps Combine and `NSWorkspace` out of it and is
what makes the dismiss scheduling directly testable.

## The windows

The island is drawn into two stacked, borderless, non-activating panels that
share one fixed frame: a transparent canvas hanging from the top centre of the
display, larger than the island will ever be. The panels are never resized to
follow the island — SwiftUI morphs the island's shape inside the canvas, so
its springs are the only motion there is and AppKit's window animation is off.

- The **content** panel, one level above the window server's shielding level,
  holds the island. It leaves AppKit's per-pixel hit-testing in place, so the
  clear canvas lets clicks through to whatever is underneath.
- The **backdrop** panel, at the shielding level, holds only the island's
  shadow. It ignores the pointer, so the shadow's soft edge is never a target.
- Both live in a window-server Space of Pod's own at absolute level 400, above
  the lock screen's, which is what keeps them over full-screen apps and on
  every desktop. That is private API, behind `IslandWindowing`'s switch; see
  [ADR 2](adr/0002-island-windows-on-a-fixed-canvas.md).

`IslandWindowConfiguration` holds every window setting as a value, so the
setup is asserted in tests without a window. `IslandWindowing` decides from
`SystemPresence` whether the panels belong on screen at all.

## Why the pure core

`NotchGeometry`, `IslandStyle`, `AnnouncementCoalescer`, `DismissPolicy`,
`IslandWindowing`, `HoverRegion` and `LowBatteryWarning` are value types with
no framework dependencies. That is not purity for its own
sake — it is what lets the suite cover the cases that are painful to reproduce
by hand: an external display with no camera housing, content larger than the
screen, a screen reader switched on halfway through a presentation, and all
sixteen combinations of the display accessibility settings.

The AppKit-facing pieces — `IslandPanel`, `IslandSpace`,
`SystemPresenceObserver`, `PointerTracker`, `AccessibilityPreferencesObserver`,
`VoiceOverSink`, `BatteryMonitor` — are kept thin for the same reason: there is
little in them left to get wrong.

## Concurrency

Swift 5 language mode, with `@MainActor` on everything that touches UI. This is
a deliberate holding position: the code is annotated as if it were in Swift 6
mode, so moving over should be mechanical, but the move is not part of the
first pass.
