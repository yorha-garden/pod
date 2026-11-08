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
- The panel never takes the keyboard while the screen is locked, even when the
  island is allowed on the lock screen: the password field keeps it.
  *Test: "The island never takes the keyboard on the lock screen".*
- `GlobalHotKey` registers Control-Option-Space through Carbon, which needs no
  accessibility permission. An event tap would need one, and gating the
  keyboard path behind a permission dialog is backwards.
- Every control carries an explicit `.focusable()`, so Tab reaches it whether
  or not Full Keyboard Access is switched on.
- Escape dismisses, through both `cancelOperation` on the panel and the root
  view, matching every other transient macOS surface.

## 2. A screen reader gets sentences, not fragments

- Collapsed is one button with a summary label, so VoiceOver reads a sentence
  about the machine's state rather than stepping through three unlabelled
  glyphs — and pressing it expands the island, from VoiceOver or the pointer
  alike.
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
also the effect most likely to provoke vestibular symptoms. By default the
island grows out of the housing on a spring that overshoots a little, and
shrinks back on one that does not — it never bounces past the housing it is
returning into. Each state has an explicit size, so it is the island's own
frame that springs between them. Reduce Motion replaces all of it with a fade
in place rather than merely shortening it: no spring, no scale, no travel, the
shape takes its new size at once, and the hover lift and the press dip are
gone.
*Tests: "Reduce Motion replaces the morph with a fade in place", "Reduce Motion
fades every transition in place and drops the hover lift", "Reduce Motion drops
the dip as well as the lift", "Opening springs out with a bounce, closing
settles without one", "The open island is pinned to the housing grown, whatever
its content measures".*

Nothing is ever animated at the window level, for anyone. The island's two
panels are a fixed canvas: they are placed once, never resized to follow the
island, and AppKit's own window animation is switched off. The island morphs
inside the canvas, so how it moves is decided by the style alone.
*Test: "Neither panel lets AppKit animate it: the island's motion is the style's
alone".*

## 6. Contrast does not depend on the wallpaper

The island is flat black — the camera housing grown outward — so light text on
it has the same contrast over any wallpaper. Nothing translucent is drawn
behind the text. What Reduce Transparency and Increase Contrast take away is
the soft shadow that lifts the island off the desktop: with either on, the
island's edge is exactly where its fill ends. Increase Contrast also adds a
border, drawn inside the outline so the island's footprint does not change.
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
decorative. The island's own height never falls below the same floor once it
shows anything — collapsed, it is a few points taller than the housing on a
14" display rather than shorter than the floor. Only the invisible resting
target is the housing's exact size.
*Tests: "Content shorter than the hit floor still gets a reachable target",
"Collapsed, the island is at least the housing, and never below the hit
floor".*

## 9. Larger text grows the island, it does not shrink the text

The island's size comes from its content as laid out at the user's text size:
collapsed it is whatever the content measures, open it keeps a fixed width and
grows downward when the content needs more height, all clamped to the display.
Text wraps with `.fixedSize(horizontal: false, vertical: true)` and there is
deliberately no `minimumScaleFactor` anywhere — shrinking text is the wrong
trade for someone who chose a larger size on purpose.
*Tests: "Growing content grows the island rather than clipping it",
"Oversized content is clamped to the display, not grown off-screen", "Larger
text still grows the open island downward, never wider", "The island's size is
clamped to the display".*

## 10. Nothing readable hides behind the camera housing

`NotchGeometry.occlusion(in:)` reports the band the physical housing covers,
and `topInsetClearingHousing(in:)` gives the inset that clears it. On a display
without a housing both resolve to nothing, so the same layout code works on an
external monitor. Collapsed, the island's content sits in two ears either side
of the housing with the housing's width left empty between them; open, the
content starts below the housing's band.
*Tests: "The occluded band matches the housing height", "There is nothing to
clear on a display without a housing".*

## 11. The pointer is the extra, and it follows the hover rules

Clicking the island, or resting the pointer on it, expands it. Content that
appears that way has to meet WCAG 2.2's 1.4.13, *Content on Hover or Focus*:

- **Hoverable and persistent.** While the pointer is over the island it is never
  dismissed on a timer — the rule keyboard focus already had, user preference
  included. Leaving restarts the clock.
  *Tests: "The pointer resting on the island holds it open", "A fixed preference
  still yields to the pointer", "The pointer holds an expanded island open past
  its timeout", "Leaving the island restarts its timeout".*
- **Dismissible.** Control-Option-Space closes it without moving the pointer,
  and so does Escape once the panel has focus.
- **Not by accident.** Hover expands only after the pointer has rested for
  0.25s, so crossing the notch on the way to the menu bar does not open it. A
  click expands at once and is announced, like the hotkey.
  *Tests: "Resting the pointer on the island expands it after the intent delay",
  "Passing over the island does not expand it", "A click expands at once, from
  hidden, and says so", "An explicit dismiss outranks a hover that was about to
  expand".*
- **Never takes the keyboard.** Hovering does not make the panel key, so typing
  elsewhere keeps working. Only a click or the hotkey hands the panel focus, and
  before the island goes back to rest the panel gives the keyboard back.
- **Invisible and harmless at rest.** While hidden, the island stays as a black
  shape exactly over the camera housing. The display has no pixels there, so
  nobody sees it, but the pointer can rest on it and VoiceOver finds a "Show
  Pod" button. On a display without a housing there is no resting target at
  all, because it would cover part of the menu bar — the hotkey is the way in
  there.
  *Test: "At rest the island is the housing exactly, so it draws nowhere the
  display has pixels".*
- **Only the island, never the space around it.** The panels are a canvas
  larger than the island, and the canvas lets the pointer through wherever
  nothing is drawn; the shadow lives in a second panel that never takes the
  pointer at all. Hover is tracked over the island's own shape, with a few
  points of slack to leave by so the hover lift cannot flicker it.
  *Tests: "The content panel takes the pointer only where it draws; the
  backdrop never does", "The pointer enters only over the island itself",
  "Once in, the pointer may drift a little before it counts as gone".*
- **Acknowledged, then opened.** While the pointer rests on the island it grows
  a few points before it opens, so the pointer is seen to have been noticed; a
  held click dips it back a little, and the release opens it — except under
  Reduce Motion, where the opening is the acknowledgement.
  *Tests: "A held click dips the lifted island 8 by 5 points, on a spring that
  does not bounce", "Pressing the island only records the press; the release
  is what opens it", "A held click holds off the hover that was about to open
  the island".*
- **Closed by clicking elsewhere.** A click anywhere but the island closes an
  open island, like any other transient surface.

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
7. **Pointer.** Rest the pointer on the notch: the island lifts, then expands
   after a beat and stays for as long as the pointer is on it. Sweep across the
   notch quickly: nothing opens. Click it: it expands at once. Hover while
   typing in another app: the typing still lands there, not in Pod. Click a
   window just below the open island: the click reaches that window, and the
   island closes.
8. **Full screen and the lock screen.** Put an app in full screen: the island is
   still at the notch. Lock the screen: the island is gone, unless
   `ShowIslandOnLockScreen` is set, in which case it is there and typing still
   goes to the password field.

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
- Hover expansion cannot be turned off. Someone who triggers it by accident —
  a tremor, a habit of parking the pointer at the top of the screen — needs
  that switch, and it belongs with the settings UI.
