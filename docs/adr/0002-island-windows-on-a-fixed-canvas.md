# 2. Draw the island on a fixed canvas, above the shield, in a Space of its own

- **Status:** accepted
- **Date:** 2026-11-08

## Context

The first island was one floating panel at the status-bar level, resized to
the island for every state with `setFrame(_:display:animate:)`. That had three
problems:

- **The motion was AppKit's, not ours.** A window frame animates on AppKit's
  fixed curve. The island is meant to grow out of the camera housing on a
  spring, and shrink back without bouncing past it; a window resize cannot do
  either, and it moved the window and the content on separate clocks.
- **It did not reach everywhere.** A status-bar-level window sits under a
  full-screen app's menu bar and never appears on the lock screen. Full-screen
  apps and the lock screen are Spaces of their own, and window levels only
  order windows within a Space.
- **It did not look like the notch.** A pill floating under the housing reads
  as a separate thing. The island should be the housing, grown.

## Decision

1. **Two panels, one fixed canvas.** The island is drawn into two stacked
   borderless, non-activating panels that share one frame: a transparent canvas
   at the top centre of the display, larger than the island gets. The panels
   are placed once and never resized per state; SwiftUI morphs the island's
   shape inside the canvas. AppKit's window animation is off.
2. **Above the shield.** The content panel sits one level above
   `CGShieldingWindowLevel()`, the backdrop panel at it. Both join every Space,
   stay put during Space switches, skip the window cycle, and may sit beside a
   full-screen app.
3. **The canvas is clear and lets the pointer through.** The content panel keeps
   AppKit's per-pixel hit-testing, so clicks land on the island and pass
   through everywhere else. Anything decorative — the shadow — goes in the
   backdrop panel, which ignores the pointer, so a shadow's soft edge is never
   a target. Hover is tracked over the island's own rect with event monitors,
   not over the window.
4. **A private Space above the lock screen.** Both panels are moved into a
   window-server Space created by Pod at absolute level 400, one above the
   lock screen's 300, and shown everywhere. This is undocumented CoreGraphics
   API (`CGSSpaceCreate`, `CGSAddWindowsToSpaces` and friends), declared with
   `@_silgen_name` in `IslandSpace.swift` and nowhere else.
5. **Behind a switch.** `UsePrivateWindowServerAPI` (on by default) turns the
   private Space and the full-screen check off. The lock screen is opt-in on
   top of that (`ShowIslandOnLockScreen`, off by default), because what is
   playing is not something to show to whoever walks past a locked machine.
6. **The island is the housing, grown.** Black, square-topped and flush with
   the display's edge, with continuous rounded bottom corners and two small
   concave ears at the top. At rest it is the housing exactly; open, it is the
   housing grown by 160 × 142 points, to at least 345 × 175.

## Consequences

Good:

- One spring drives the island's size, corners and content together. Opening
  overshoots a little; closing is critically damped. Reduce Motion replaces
  both with a fade in place, as before.
- The island stays at the notch over full-screen apps, across desktops and
  during Space switches, and can be allowed on the lock screen.
- The window setup is a value (`IslandWindowConfiguration`) and the visibility
  rules are a pure function (`IslandWindowing.panelsBelongOnScreen`), both
  covered by tests without a window.

Costs:

- **Private API.** Pod cannot ship on the Mac App Store with the switch on, and
  a future macOS can change or remove the calls. They are confined to one file
  and one switch; with it off Pod runs on public API only and loses the lock
  screen. Pod is distributed locally and ad-hoc signed, so this is acceptable
  for now.
- Ordering a window in puts it back on the Space in front, so every
  `orderFront` has to be followed by re-adding the panels to the private Space.
- The canvas is larger than the island, so the app layer has to know where the
  island actually is: SwiftUI reports its laid-out size, and the coordinator
  sizes the canvas and the hover region from it.
- A panel at this level, in this Space, can sit over the lock screen. It must
  never take the keyboard there, and does not.

## Alternatives rejected

- **Keep resizing the window.** Simple, but the motion stays AppKit's and the
  island stays a pill under the housing.
- **`ignoresMouseEvents` toggled by hover.** Turning click-through on and off
  from a mouse-moved monitor races the pointer, and a shadow in the same window
  as the island would still catch clicks. Per-pixel hit-testing and a separate
  backdrop panel need no bookkeeping.
- **Public API only.** Reaches full-screen apps through
  `.fullScreenAuxiliary`, but not the lock screen and not reliably during Space
  transitions. Kept available as the switch's off position.
