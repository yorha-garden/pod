# YoRHa Pod

A notch HUD for the YoRHa desktop. Pod hangs from the camera housing, stays out
of the way, and reports what the machine is doing — media, battery, volume —
the way Pod 042 reports to 2B.

Sibling repos: [`yorha-system`](../desktop-environment) (desktop),
[`yorha-launcher`](../launcher) (Raycast layer) and [`yorha-bunker`](../bunker)
(pi agent). Pod inherits their palette and runs as its own agent process.

---

## What this repo is

A from-scratch replacement for the commercial notch apps, written because every
one of them treats the notch overlay as a mouse-only decoration. Pod is built
the other way round: the accessibility tree, the keyboard path and the system
accessibility preferences come first, and the hover affordance is the extra.

That inversion is the whole point of the project, so it is written down as a
contract the code is expected to keep — see
[`docs/accessibility.md`](docs/accessibility.md) and the decision log in
[`docs/adr/`](docs/adr/).

## Tech stack

| Layer | Choice |
| --- | --- |
| Language | Swift 6.4, Swift 5 language mode |
| UI | SwiftUI inside an AppKit `NSPanel` |
| Build | Swift Package Manager — no Xcode project |
| Platform | macOS 14+ (built and run against macOS 27) |
| Tests | swift-testing over `PodKit` |

`PodKit` is a library target holding the logic; `Pod` is a thin executable that
boots it. Everything with a decision in it — geometry, dismiss timing, style
resolution, announcements — lives in `PodKit` behind pure functions, which is
why the test target can reach it without a screen.

## Setup & run

Requires the Swift toolchain. Command Line Tools is enough; full Xcode is not
needed.

```bash
swift build          # compile
./Scripts/test.sh    # run the suite
./Scripts/build-app.sh   # assemble dist/Pod.app
open dist/Pod.app    # run it
```

Pod is an agent (`LSUIElement`) — it has no Dock icon and no window of its own.
It appears at the notch; press its hotkey to summon it from the keyboard.

## Environment variables

None. Pod reads no configuration from the environment and talks to no network
service. User preferences live in `UserDefaults` under the app's own domain.

## Deployment

Local only for now — `Scripts/build-app.sh` assembles an unsigned bundle into
`dist/`. Signing and notarisation are not wired up.
