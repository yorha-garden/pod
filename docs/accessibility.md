# The accessibility contract

This is what Pod is for. A notch overlay is a small, transient, hover-driven
surface floating above every other window — which is to say it is the shape of
UI most likely to be unusable for anyone not driving it with a mouse and a
clear look at the screen. Pod exists to be the same idea built the other way
round.

The list below is a contract, not a wish list. Where a line can be asserted in
code it is, and the test is named; where it cannot, the manual check is written
out so it can actually be repeated.

---

## 1. The island is reachable from the keyboard

A borderless `NSPanel` returns `false` from `canBecomeKey` by default. That one
default is the root of most of the problem: with no key window there is no
first responder, so there is no focus ring, nothing for Tab to land on, and
nothing for VoiceOver to navigate into. The overlay becomes decoration that
only a pointer can touch.

- `IslandPanel` overrides `canBecomeKey` to `true`, and leaves `canBecomeMain`
  `false` — Pod is an agent and should never become the active app.
- `.nonactivatingPanel` means taking key focus does not drag the user out of
  whatever they were working in.
- `GlobalHotKey` registers Control-Option-Space through Carbon, which needs no
  accessibility permission. An event tap would need one, and gating the
  keyboard path behind a permission dialog is backwards.
- Every control carries an explicit `.focusable()`, so Tab reaches it whether
  or not Full Keyboard Access is switched on.
- Escape dismisses, through both `cancelOperation` on the panel and the root
  view, matching every other transient macOS surface.

## 2. A screen reader gets sentences, not fragments

- Collapsed is one combined element (`.accessibilityElement(children: .combine)`)
  with a summary label, so VoiceOver reads a sentence about the machine's state
  rather than stepping through three unlabelled glyphs.
- Expanded is a container (`children: .contain`), because now there are
  controls, and each needs its own label and focus stop.
- The spoken strings are built on the models — `NowPlaying.accessibilityDescription`,
  `BatteryStatus.accessibilityDescription` — not concatenated in the view, so
  what a VoiceOver user hears is covered by tests.
  *Tests: "Now playing descriptions", "Battery status".*
- The panel is named, and carries the floating subrole it actually has.

## 3. Announcements do not talk over the user

A HUD updates constantly: progress ticks, volume nudges, battery percentages.
Posting each one turns VoiceOver into a stream that speaks over whatever the
user is actually doing.

- `AnnouncementCoalescer` drops repeats inside a short window, and drops low
  priority chatter inside a quiet period.
- High priority is never withheld, repeat or not.
- Reopening the island resets the history, because the user has moved on.
  *Tests: "Screen reader announcement coalescing".*

## 4. The island is never taken away on a timer the user is losing

The most common defect in this class of app. Four seconds is ample if you
glanced at it; it is nothing if a screen reader is still on the second line, or
if reaching the trackpad takes you a moment.

- `DismissPolicy` derives the timeout instead of hardcoding it.
- While the panel holds keyboard focus, there is no timeout at all — dismissing
  it would drop the user's place in the focus order with no warning.
- A deliberate keyboard summon never expires.
- Assistive use multiplies the timeout; a preference change reschedules the
  timeout already in flight, so switching VoiceOver on while the island is up
  extends the presentation the user is in, not merely the next one.
- `never` and `fixed` user preferences outrank all of it.
  *Tests: "Dismiss timing", "Island controller".*

## 5. Reduce Motion removes the motion

The springy morph out of the notch is the signature of this kind of UI, and
also the effect most likely to provoke vestibular symptoms. Reduce Motion
replaces it with a fade in place rather than merely shortening it: no spring,
no scale, no travel, and `NSPanel.setFrame` stops animating too.
*Test: "Reduce Motion replaces the morph with a fade in place".*

## 6. Contrast does not depend on the wallpaper

Reduce Transparency swaps the material for a flat fill. So does Increase
Contrast — a blur hands whatever is behind the island control of the text's
contrast, so a border alone would not be enough. Increase Contrast also adds
that border.
*Test: "Increase Contrast adds a border and drops the blur".*

## 7. Colour is never the only cue

A red battery bar is not a cue for anyone who cannot pick red out. Every state
carries a glyph and a word as well: the badge shows an icon, a number, and the
literal word "Low". This holds whether or not Differentiate Without Colour is
switched on — the setting only makes the lapse visible.
*Tests: "Colour is never the only state cue…" over all 16 preference
combinations, and "The low state carries a cue that is not colour".*

## 8. Targets are reachable

Controls are padded to a 44pt floor however small the glyph is drawn, with
`.contentShape(Rectangle())` so the padding is actually hittable rather than
decorative. The island's own height never falls below the same floor.
*Tests: "Content shorter than the hit floor still gets a reachable target".*

## 9. Larger text grows the island, it does not shrink the text

Panel frames come from the hosting view's `fittingSize`, and `NotchGeometry`
derives the frame from the content it is given, clamped to the display. Text
wraps with `.fixedSize(horizontal: false, vertical: true)` and there is
deliberately no `minimumScaleFactor` anywhere — shrinking text is the wrong
trade for someone who chose a larger size on purpose.
*Tests: "Growing content grows the island rather than clipping it",
"Oversized content is clamped to the display, not grown off-screen".*

## 10. Nothing readable hides behind the camera housing

`NotchGeometry.occlusion(in:)` reports the band the physical housing covers,
and `topInsetClearingHousing(in:)` gives the inset that clears it. On a display
without a housing both resolve to nothing, so the same layout code works on an
external monitor.
*Tests: "The occluded band matches the housing height", "There is nothing to
clear on a display without a housing".*

---

## What still needs a person

These cannot be asserted from a unit test, and should be walked through before
any release:

1. **VoiceOver, keyboard only.** Unplug the mouse. VO on (Command-F5).
   Control-Option-Space to summon. Confirm: the panel is announced as "Pod",
   its state is spoken, Tab reaches all three transport controls in order, each
   is announced with its own label, Escape dismisses, and focus returns
   somewhere sensible.
2. **Reduce Motion.** Switch it on in Accessibility → Display and summon the
   island. Nothing should travel or scale; it should fade in place.
3. **Reduce Transparency and Increase Contrast.** Put a high-contrast wallpaper
   behind the notch and confirm the text stays legible with each on.
4. **Larger text.** Raise the system text size and confirm the island grows and
   nothing clips or is cut off behind the housing.
5. **External display.** Run with the lid closed on a monitor with no housing,
   and confirm the island still places sensibly at the top centre.
6. **Accessibility Inspector.** Point it at the panel and confirm the element
   tree matches section 2 — one element collapsed, a container with three
   labelled buttons expanded.

## Known gaps

- There is no real Now Playing integration. Reading the system state on macOS
  needs the private MediaRemote framework, so `NowPlayingStore` is a seam with
  a local placeholder behind it. The accessibility work does not depend on
  which backend fills it.
- Screen reader detection is a heuristic — macOS exposes no public "is
  VoiceOver running" flag, so Pod looks for the process. It fails safe: a miss
  only returns the default timing, and the `never` preference still pins the
  island open.
- There is no settings UI yet. `DismissPolicy.UserPreference` is honoured by
  the controller but nothing writes it.
- The hotkey is fixed at Control-Option-Space and cannot be rebound.
