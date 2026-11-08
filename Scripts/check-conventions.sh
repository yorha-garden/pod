#!/usr/bin/env bash
#
# Checks a branch against CONTRIBUTING.md: every commit subject is a
# Conventional Commit, the branch is a feature/, fix/ or chore/ branch, and —
# when PR_TITLE is set — the pull request title is a Conventional Commit that
# ends in its issue, like "[#13]".
#
# CI runs this on every pull request. Run it before pushing to get the same
# answer locally:
#
#   ./Scripts/check-conventions.sh                  # origin/main..HEAD
#   ./Scripts/check-conventions.sh <base> [<head>]  # a stacked branch, say
#   PR_TITLE='fix(app): … [#11]' ./Scripts/check-conventions.sh
#
# Merge commits are skipped, since GitHub writes those. So are the subjects,
# branches and titles that `git revert` and GitHub's revert button produce:
# backing a change out should never wait on this check.
#
# Kept to what the bash 3.2 that ships with macOS understands.
set -euo pipefail

base="${1:-origin/main}"
head="${2:-HEAD}"
branch="${BRANCH_NAME:-$(git symbolic-ref --quiet --short HEAD || true)}"
title="${PR_TITLE:-}"

types='feat|fix|refactor|docs|chore|test'
subject_re="^(${types})(\([a-z0-9][a-z0-9-]*\))?!?: [^ ]"
title_re="${subject_re}.* \[#[0-9]+\]$"
ticket_re='\[#[0-9]+\]'
revert_re='^(Revert|Reapply) ".+"'
autosquash_re='^(fixup|squash|amend)! '
wip_re='^wip([^a-z]|$)'
branch_re='^(feature|fix|chore)/[a-z0-9][a-z0-9._/-]*$'
revert_branch_re='^revert-[0-9]+-'

failures=0

fail() {
    failures=$((failures + 1))
    if [[ "${GITHUB_ACTIONS:-}" == true ]]; then
        # Workflow commands treat % as an escape, so it is escaped first.
        local message="${1//%/%25}"
        echo "::error::${message}"
    else
        echo "✗ $1" >&2
    fi
}

check_subject() {
    local sha="$1" subject="$2" description

    if [[ "$subject" =~ $revert_re ]]; then
        return 0
    fi
    if [[ "$subject" =~ $autosquash_re ]]; then
        fail "${sha} \"${subject}\": squash it into the commit it fixes before pushing"
        return 0
    fi
    if [[ ! "$subject" =~ $subject_re ]]; then
        fail "${sha} \"${subject}\": want type(scope): description, with type one of ${types//|/, }"
        return 0
    fi

    description="$(printf '%s' "${subject#*: }" | tr '[:upper:]' '[:lower:]')"
    if [[ "$description" =~ $wip_re ]]; then
        fail "${sha} \"${subject}\": no WIP commits on a pushed branch; finish the step or fold it into the next commit"
    fi
}

check_commits() {
    local ref sha subject count=0

    for ref in "$base" "$head"; do
        if ! git rev-parse --verify --quiet "${ref}^{commit}" >/dev/null; then
            fail "no commit ${ref}; fetch it, or pass the base to compare against"
            return 0
        fi
    done

    while IFS=' ' read -r sha subject; do
        count=$((count + 1))
        check_subject "$sha" "$subject"
    done < <(git log --no-merges --reverse --format='%h %s' "${base}..${head}")

    echo "Checked ${count} commit subject(s) in ${base}..${head}."
}

check_branch() {
    if [[ -z "$branch" ]]; then
        echo "Detached HEAD and no BRANCH_NAME; skipped the branch name."
        return 0
    fi
    if [[ "$branch" == main ]]; then
        fail "main takes changes through pull requests; move these commits with: git switch -c feature/<short-description>"
        return 0
    fi
    if [[ "$branch" =~ $branch_re || "$branch" =~ $revert_branch_re ]]; then
        echo "Checked branch ${branch}."
        return 0
    fi
    fail "branch ${branch}: want feature/<short-description>, fix/<bug-description> or chore/<maintenance>; rename it with: git branch -m <new-name>"
}

check_title() {
    if [[ -z "$title" ]]; then
        return 0
    fi
    if [[ "$title" =~ $revert_re && "$title" =~ $ticket_re ]] || [[ "$title" =~ $title_re ]]; then
        echo "Checked title \"${title}\"."
        return 0
    fi
    fail "title \"${title}\": want type(scope): description [#issue], e.g. feat(ui): open the island with the pointer [#13]"
}

check_commits
check_branch
check_title

if (( failures > 0 )); then
    echo "${failures} problem(s). The conventions are in CONTRIBUTING.md." >&2
    exit 1
fi
