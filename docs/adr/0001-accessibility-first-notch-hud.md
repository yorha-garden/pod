# 1. Build the notch HUD accessibility-first

- **Status:** accepted
- **Date:** 2026-10-26

## Context

The commercial notch apps are hover-driven overlays. Inspecting one of them
turned up no accessibility label strings and no references to the system
Reduce Motion, Reduce Transparency or Differentiate Without Colour settings.
That is suggestive rather than conclusive — SwiftUI modifiers do not always
leave literals in a binary — but the interaction model is the real tell: the
island is summoned by hover, dismissed on a short fixed timer, and has no
keyboard affordance at all.

None of that is fixable from outside. The apps are signed and notarised, so
patching them breaks both, and they are someone else's commercial software.

## Decision

Build a replacement, and treat accessibility as the architecture rather than a
later pass:

1. Every decision with a rule in it goes in a pure value type in `PodKit`, so
   the rule can be asserted rather than described.
2. The keyboard path is built first and is not optional. The panel overrides
   `canBecomeKey`; the hotkey uses Carbon so it needs no permission.
3. Dismiss timing is derived from context, never a constant, and never applies
   while the user holds focus.
4. The system accessibility settings resolve into one `IslandStyle` value,
   which the views read. They cannot quietly ignore a setting, because they do
   not read the settings directly.
5. The contract is written down in `docs/accessibility.md` with the test names
   that enforce each line, and the manual checks for the lines that cannot be.

## Consequences

Good:

- The awkward cases — no camera housing, oversized content, a screen reader
  appearing mid-presentation — are unit-testable, and are tested.
- Adding a surface means filling in an `IslandStyle`, so new UI inherits the
  behaviour instead of re-deciding it.
- The accessibility work does not depend on the media backend, which is still
  a placeholder.

Costs:

- More indirection than a single view file. `IslandStyle` exists only to keep
  the views from reading `NSWorkspace` themselves.
- Preferences are injected rather than observed, so the coordinator has to
  remember to wire the observer. The alternative made the controller
  untestable.
- Pure geometry means duplicating a little of what AppKit would compute, in
  exchange for being able to test it without a screen.

## Alternatives rejected

- **Patch an existing app.** Breaks the signature and the notarisation, and it
  is not our software to modify.
- **Retrofit accessibility onto a working hover UI.** This is the usual order
  and it is why the category is in the state it is in. The hover affordance is
  the easy part and goes last.
- **Private MediaRemote for real Now Playing.** Deferred. A private API
  dependency is a poor foundation, and the accessibility work does not need it.
