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
