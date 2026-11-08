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
It appears at the notch, as the camera housing grown outward. Rest the pointer
on the notch and it lifts; click it to open the island, or press
Control-Option-Space to summon it from the keyboard.

## Environment variables

None. Pod reads no configuration from the environment and talks to no network
service. User preferences live in `UserDefaults` under the app's own domain,
`dev.yorha.pod`. Four switches decide how far the island reaches and what opens it:

| Key | Default | Effect |
| --- | --- | --- |
| `UsePrivateWindowServerAPI` | `YES` | Keeps the island in a window-server Space of its own, above full-screen apps and the lock screen. Undocumented API — see [ADR 2](docs/adr/0002-island-windows-on-a-fixed-canvas.md). |
| `ShowIslandOnLockScreen` | `NO` | Leaves the island on the lock screen. Needs the switch above. |
| `HideIslandInFullScreen` | `NO` | Takes the island away while a full-screen app is in front. |
| `ExpandIslandOnHover` | `NO` | Opens the island when the pointer rests on it for 0.25s, not only on a click. |

```bash
defaults write dev.yorha.pod ShowIslandOnLockScreen -bool YES
```

## Deployment

Local only for now. `Scripts/build-app.sh` assembles `dist/Pod.app` and ad-hoc
signs it, which is enough to run it here. Real signing and notarisation are not
wired up, so Gatekeeper will want a first-run approval on any other machine.
With `UsePrivateWindowServerAPI` on, Pod uses undocumented CoreGraphics calls
and is not eligible for the Mac App Store; turn it off for a public-API-only
build.

## Documentation

- [`docs/accessibility.md`](docs/accessibility.md) — the contract, with the test
  names that enforce each line and the manual checks for the rest
- [`docs/architecture.md`](docs/architecture.md) — module shape and data flow
- [`docs/adr/`](docs/adr/) — decision log
- [`CONTRIBUTING.md`](CONTRIBUTING.md) — branches, commits and pull requests:
  how a change gets into Pod
- [`.github/pull_request_template.md`](.github/pull_request_template.md) and
  [`.github/ISSUE_TEMPLATE/`](.github/ISSUE_TEMPLATE/) — what a PR and an issue
  are expected to say
