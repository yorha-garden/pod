# Contributing to Pod

Every change to Pod takes the same route. An issue says what and why, a
short-lived branch holds the work in small commits, a pull request carries it
towards `main`, and the owner merges it once its checks are green. This file is
the detail of each step.

Some of it is checked by machine. `CI` builds and runs the suite, and
`Conventions` reads the commit subjects, the branch name and the PR title. The
rest is up to whoever makes the change, and is written down here so nobody has
to guess.

## The workflow

1. **Create or find an issue.** Say what the problem is before solving it. If
   the issue already exists, comment on it with the approach you have in mind
   and wait for the owner to agree. That is cheaper than a rewritten PR, and
   it stops two people building the same thing. *New issue* offers a bug form
   and a feature form.
2. **Branch from `main`**, one branch per issue. See [Branches](#branches).
3. **Make the change in small commits**, with its tests and docs alongside the
   code. See [Commits](#commits).
4. **Test it**: the suite, and the app itself. See
   [Before each commit](#before-each-commit).
5. **Open a pull request** from the template. See
   [Pull requests](#pull-requests).
6. **Merge.** The owner merges once CI is green. See [Merging](#merging).

## Branches

Pod is developed trunk-based. There are two long-lived branches, and no others:

| Branch | Holds |
| --- | --- |
| `main` | The trunk. Releasable at every commit: it builds, the suite passes, the app runs. |
| `release` | The version currently in production. |

There is no `develop`, `staging` or anything like them. Pod has no production
build yet (see [Deployment](README.md#deployment)), so `release` is cut from
`main` when the first signed build ships. Until then `main` is the only
long-lived branch.

Everything else is a short-lived branch off `main`, named for the change:

```
feature/<short-description>    feature/pointer-expand
fix/<bug-description>          fix/first-presentation-frame
chore/<maintenance>            chore/add-ci-workflow
```

Lowercase, with words joined by hyphens. Docs, tests and refactors go on
whichever of the three fits: the `feature/` or `fix/` branch they belong to,
or a `chore/` branch of their own. `Conventions` fails any other name. If a
tool created the branch under its own prefix, rename it before you open the PR:

```bash
git branch -m feature/<short-description>
```

Nobody commits straight to `main`; every change reaches it through a branch and
a pull request. The one exception is an incident that needs a hotfix sooner
than a pull request can go through. Then push the smallest fix that ends it,
and open an issue recording what went in and why, so there is a record of it.

## Commits

### Size

A commit is one logical change: small enough to read in one sitting, and to
revert without taking anything else with it. As a guide:

- roughly 5 to 100 changed lines;
- one concern, which you can describe in one sentence;
- never a refactor mixed into a feature, or a fix mixed with reformatting. Make
  those two commits.

Commit when a step is done: a function written, a bug fixed, a test passing.
While you are actively coding that tends to be every 15 to 60 minutes. A fair
test is that if you stopped work now, what you have should be committable.

Avoid:

- large commits. A thousand lines across many files and concerns cannot be
  read properly or reverted cleanly;
- `WIP` commits on any branch someone else can see. Tidy them into real steps
  locally before you push;
- panic commits: a long burst of changes with no intermediate commit and no
  cleanup afterwards.

`Conventions` fails `WIP`, `fixup!` and `squash!` subjects in a pull request.

### Messages

Subjects follow [Conventional Commits](https://www.conventionalcommits.org/):

```
type(scope): description
```

| Type | For |
| --- | --- |
| `feat` | a new feature or behaviour |
| `fix` | a bug fix |
| `refactor` | restructuring that changes no behaviour |
| `docs` | documentation only |
| `chore` | maintenance: build scripts, CI, repository setup |
| `test` | tests only |

These six are the only types `Conventions` accepts. Build and CI changes are
`chore(build)` and `chore(ci)`; the one `build:` commit on `main` predates this
guide.

The scope is optional. It names the part of Pod that changed, in lowercase:
`a11y`, `island`, `views`, `input`, `model`, `app`, `style`, `ci`. The
description is lowercase and imperative, says what the commit does, and ends
without a full stop.

Good, from Pod's own history:

```
feat(island): expand on hover intent and on click
fix(app): place the island before showing it
test(style): cover when a frame change may animate
docs: add appearing in place to the reduce motion contract
```

Bad:

```
update code
fix bugs
final fix beneran
```

#### Breaking changes

Mark a breaking change with `!` after the type or scope, and say what breaks in
a `BREAKING CHANGE:` footer:

```
feat(input)!: move the summon hotkey to Control-Option-P

BREAKING CHANGE: Control-Option-Space no longer opens the island.
```

For Pod, breaking means anything a user or a later build would notice as lost:
a higher minimum macOS, a renamed or dropped `UserDefaults` key, a changed
default shortcut, a new system permission, or a line of the
[accessibility contract](docs/accessibility.md) that no longer holds.

### Before each commit

Testing before committing keeps `main` releasable at every commit, and means
the author finds a failure rather than CI.

- `swift build` compiles with no new warnings. Pod has no linter, so a new
  compiler warning is the lint error.
- `./Scripts/test.sh` passes.
- New behaviour comes with a test. Anything with a decision in it lives in
  `PodKit` as a pure value so that it can be asserted; see
  [ADR 0001](docs/adr/0001-accessibility-first-notch-hud.md).
- You have run it. For anything a user can see, build the app with
  `./Scripts/build-app.sh`, open `dist/Pod.app`, and drive the change from the
  keyboard (Control-Option-Space, Tab, Escape), with the pointer, and with
  VoiceOver for anything it reads. If it touches the style, try Reduce Motion,
  Reduce Transparency and Increase Contrast as well.
  [What still needs a person](docs/accessibility.md#what-still-needs-a-person)
  is the list of manual checks.

Before you push, `./Scripts/check-conventions.sh` runs the same check as
`Conventions` over the commits on your branch.

## Pull requests

### Talk first

Comment on the issue before you start, and confirm the approach with the owner.
That avoids duplicate work and solutions that pull against where Pod is going.
A draft pull request is a good way to ask about a direction with code in hand;
mark it ready when it is.

### Keep it small

One problem per pull request. Unrelated fixes and tidying, however small, go in
a PR of their own. Aim for under about 500 changed lines: small PRs are easier
to follow, roll back cleanly and carry less risk when they merge.

When a change is bigger than that, split it into a stack. Each PR branches from
the one below it and targets that branch instead of `main`:

```
main ← feature/pointer-hold ← feature/pointer-expand ← feature/pointer-docs
```

Both workflows run on stacked PRs, since neither filters on the base branch.
Merge from the bottom up. Once the lowest PR merges, the next one is retargeted
at `main`; GitHub does that for you when the merged branch is deleted. More on
the technique: [stacked PRs](https://graphite.com/blog/stacked-prs),
[daisy-chaining pull requests](https://tinyideasxyz.medium.com/daisy-chaining-pull-requests-0d5a41a87b23),
and [a worked example](https://medium.com/inside-bukalapak/smaller-faster-code-review-with-stacked-merge-request-1dc130705bc1).

### What a pull request needs

Required:

- **The issue id in the title**, after a Conventional Commit subject:
  `feat(ui): open the island with the pointer [#13]`. The title becomes the
  merge commit's subject, so it follows the same rules as a commit, and
  `Conventions` checks it.
- **A description.** The [template](.github/pull_request_template.md) fills in
  when you open the PR.
- **The linked issue**, as `Closes #13` in the description, so the merge closes
  it.
- **Tests and documentation** for what changed. See
  [Documentation](#documentation).
- **Deployment prerequisites.** Pod reads no environment variables, so here
  this means anything that has to be true before a build ships: a new
  `Info.plist` entry, a new system permission or entitlement, a higher minimum
  macOS, a `UserDefaults` migration, a change to signing or to
  `Scripts/build-app.sh`. Write "None" when there are none.
- **Green CI**: both *CI / Build and test* and *Conventions / Commits, branch
  and title*.

Recommended:

- **Screenshots or a screen recording** of anything visible. Pod is almost all
  interface, so that is most PRs. Show the normal path and a few edge cases:
  the keyboard path, what VoiceOver reads, Reduce Motion, a Mac without a
  notch, a second display.
- **Before and after numbers** when performance is the point of the change.
- **Migration steps** for a breaking change.

### The description

The template asks for:

- **Summary**: the change in a sentence or two.
- **Problem**: what it fixes or makes possible.
- **Solution**: how, and where to look first.
- **Test Evidence**: how it was tested, with screenshots or a recording.
- **Deployment Prerequisite / Breaking Changes**: as above.
- **Notes**: anything else worth knowing before it merges.

Write it for someone who has not read the code you just wrote. The change should
make sense from the description without tracing the codebase.

## Merging

The owner merges a pull request once:

- every CI check passes: *CI / Build and test* and *Conventions / Commits,
  branch and title*. If one fails, the PR is updated until it does not;
- the commit subjects and the title follow this guide, which `Conventions`
  checks.

Merge with a merge commit, not a squash or a rebase. The small commits are the
history worth keeping, and each one stays revertable on its own. The merge
commit's subject is the PR title followed by its number, as on every merge so
far:

```bash
gh pr merge 14 --merge --subject "feat(ui): open the island with the pointer [#13] (#14)"
```

The merge button works too, if you edit its subject to match. Delete the branch
once it has merged.

## Security

Never commit:

- `.env` files;
- keys and signing material: API keys, Developer ID exports (`.p12`),
  notarisation keys (`.p8`), anything ending in `.pem` or `.key`;
- logs.

`.gitignore` covers all of these, but read `git status` before each commit
anyway. Pod reads no environment and talks to no network service, so it has no
secrets of its own to leak. Keep it that way: if a change needs one, raise it in
the issue first. If a secret is ever pushed, deleting it in a later commit does
not take it out of history. Revoke it, issue a new one, and tell the owner.

## Documentation

- The [README](README.md) keeps its sections current: overview, tech stack,
  setup and run, environment variables, deployment.
- [`docs/architecture.md`](docs/architecture.md) holds the module shape and the
  data-flow diagram. Update it when either changes.
- [`docs/adr/`](docs/adr/) is the decision log. A decision that would otherwise
  be lost, such as a new dependency, a change of approach or a rule the code is
  now expected to keep, gets a numbered record in the shape of
  [ADR 0001](docs/adr/0001-accessibility-first-notch-hud.md).
- [`docs/accessibility.md`](docs/accessibility.md) is the contract. A change in
  behaviour updates it in the same PR, with the tests that enforce each line
  and a written manual check for the rest.
- Pod has no network API, so there is no API spec to keep.

## Further reading

- [Trunk-based development](https://trunkbaseddevelopment.com/)
- [Conventional Commits](https://www.conventionalcommits.org/)
