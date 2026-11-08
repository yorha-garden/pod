# Contributing to Pod

Every change to Pod takes the same route. An issue says what and why, a
short-lived branch holds the work in small commits, a pull request carries it
to review, and a merge puts it on `main`. This file is the detail of each step.

Some of it is checked by machine. `CI` builds and runs the suite, and
`Conventions` reads the commit subjects, the branch name and the PR title. The
rest is up to the author and the reviewer, and is written down here so neither
has to guess.

## The workflow

1. **Create or find an issue.** Say what the problem is before solving it. If
   the issue already exists, comment on it with the approach you have in mind
   and wait for a maintainer to agree. That is cheaper than a rewritten PR, and
   it stops two people building the same thing. *New issue* offers a bug form
   and a feature form.
2. **Branch from `main`**, one branch per issue. See [Branches](#branches).
3. **Make the change in small commits**, with its tests and docs alongside the
   code. See [Commits](#commits).
4. **Test it**: the suite, and the app itself. See
   [Before each commit](#before-each-commit).
5. **Open a pull request** from the template. See
   [Pull requests](#pull-requests).
6. **Review.** Reviewers comment, the author revises, and the cycle repeats
   until it is approved. See [Review](#review).
7. **Merge** once CI is green, every thread is resolved and a reviewer has
   approved. See [Merging](#merging).

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
than a review can happen. Then push the smallest fix that ends it, and open an
issue recording what went in and why, so the change still gets read.

## Commits

### Size

A commit is one logical change: small enough to review in one sitting, and to
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
  reviewed properly or reverted cleanly;
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

Testing first means review time goes on design and correctness, not on
discovering that something does not build.

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

Comment on the issue before you start, and confirm the approach with a
maintainer. That avoids duplicate work and solutions that pull against where
Pod is going. A draft pull request is a good way to ask about a direction with
code in hand; mark it ready for review when it is.

### Keep it small

One problem per pull request. Unrelated fixes and tidying, however small, go in
a PR of their own. Aim for under about 500 changed lines: small PRs are reviewed
sooner, roll back cleanly and carry less risk when they merge.

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
- **Solution**: how, and where a reviewer should look first.
- **Test Evidence**: how it was tested, with screenshots or a recording.
- **Deployment Prerequisite / Breaking Changes**: as above.
- **Notes**: anything else a reviewer should know.

Write it for someone who has not read the code you just wrote. A reviewer should
understand the change from the description without tracing the codebase.

## Review

### The cycle

A reviewer is assigned and leaves feedback. Author and reviewer discuss it, the
author revises, and the cycle repeats until the reviewer approves. Then the PR
merges.

### What reviewers look for

The aim is a better change, not a verdict on its author. Read for:

- **Correctness.** Does it solve the problem in the issue? Are the edge cases
  handled: no notch, a second display, VoiceOver running, Reduce Motion on?
- **Readability.** Can you follow it? Is any function too large or doing too
  much?
- **Architecture.** Does it fit [`docs/architecture.md`](docs/architecture.md)?
  Decisions belong in `PodKit` as pure values, not in views or the coordinator,
  and the controller observes nothing. Does it add coupling it does not need?
- **Testing.** Are there tests, and would they fail if the change were wrong?
- **Documentation.** If behaviour changed, did
  [`docs/accessibility.md`](docs/accessibility.md) change with it, naming the
  tests that enforce each new line?
- **Performance and security.** Does it do work on every frame or pointer move
  that it could skip? Does it ask for a permission, read something private, or
  add a dependency?

### Writing feedback

- Be respectful, and give the reasoning behind each comment.
- Say which comments are required and which are optional. Prefix optional ones
  with `nit:`. Anything without it is a change you need before you approve.
- Ask when something is unclear, rather than assuming.
- Do not block on trivia. If only nits are left, approve and leave them to the
  author.

Use GitHub's review states to match: *Request changes* when something is
required, *Comment* for questions and nits, *Approve* when it is ready.

### Responding to feedback

- Answer every comment: fix it, or reply saying why not.
- Ask when a comment is unclear, and give your reasoning when you disagree.
  Review is a discussion.
- Do not apply a suggestion you do not understand.
- Push fixes as new commits with real subjects, such as
  `fix(island): cancel the dismiss timer on focus` rather than
  `address review`, so the reviewer can see what changed. Prefer that to
  rewriting the branch while it is under review.
- Then re-request review, and say in a comment which changes matter most.

## Merging

A pull request merges when:

- every CI check passes. If one fails, the PR is updated until it does not;
- every review thread is resolved;
- the required reviewers have approved: at least one maintainer other than the
  author;
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
