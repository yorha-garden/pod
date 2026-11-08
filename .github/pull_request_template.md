<!--
Title: type(scope): description [#issue]
  e.g. feat(ui): open the island with the pointer [#13]
The title becomes the merge commit's subject. CONTRIBUTING.md has the rest.
-->

Closes #

## Summary

<!-- The change in a sentence or two. -->

## Problem

<!-- What this fixes or makes possible, and why it matters. -->

## Solution

<!-- How it works, and where a reviewer should look first. -->

## Test Evidence

<!--
Screenshots or a screen recording of the normal path and a few edge cases.
Pod is a notch interface, so for anything visible include the keyboard path
(Control-Option-Space, Tab, Escape), what VoiceOver reads, and Reduce Motion
where the change moves. Note a Mac without a notch or a second display when
placement is involved. List the tests added or changed.
-->

## Deployment Prerequisite / Breaking Changes

<!--
Anything that must be true before a build ships: a new Info.plist entry, a
system permission or entitlement, a higher minimum macOS, a UserDefaults
migration, a signing or Scripts/build-app.sh change. For a breaking change,
the migration steps. Write "None" if there are none.
-->

## Notes

<!-- Anything else reviewers should know or focus on. -->

## Checklist

- [ ] The title is `type(scope): description [#issue]`
- [ ] The issue is linked above with `Closes #`
- [ ] One problem, under about 500 lines, or split into a stack
- [ ] `swift build` has no new warnings and `./Scripts/test.sh` passes
- [ ] New behaviour has tests
- [ ] Docs are updated: `docs/accessibility.md` when behaviour changes, `docs/architecture.md` when the module shape or data flow does, an ADR for a decision
- [ ] Screenshots or a recording are attached for anything visible
- [ ] No `.env`, keys or logs are committed
- [ ] CI is green
