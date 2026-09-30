# Issue tracker: GitHub

Issues and specs for this repo live as GitHub issues at [dis0neplay/female-character-creation-workflow](https://github.com/dis0neplay/female-character-creation-workflow). Use the `gh` CLI for all operations.

Repository: `https://github.com/dis0neplay/female-character-creation-workflow.git`

## Conventions

- **Create an issue**: `gh issue create --repo dis0neplay/female-character-creation-workflow --title "..." --body "..."`.
- **Read an issue**: `gh issue view <number> --repo dis0neplay/female-character-creation-workflow --comments`, including labels.
- **List issues**: `gh issue list --repo dis0neplay/female-character-creation-workflow --state open --json number,title,body,labels,comments` with appropriate label filters.
- **Comment on an issue**: `gh issue comment <number> --repo dis0neplay/female-character-creation-workflow --body "..."`.
- **Apply / remove labels**: `gh issue edit <number> --repo dis0neplay/female-character-creation-workflow --add-label "..."` / `--remove-label "..."`.
- **Close**: `gh issue close <number> --repo dis0neplay/female-character-creation-workflow --comment "..."`.

## Pull requests as a triage surface

**PRs as a request surface: no.**

## Wayfinding operations

Used by `/wayfinder`. The map is a single issue labelled `wayfinder:map`, with child issues as tickets. Child tickets use exactly one type label from `wayfinder:research`, `wayfinder:prototype`, `wayfinder:grilling`, or `wayfinder:task`. Use GitHub native sub-issues and native issue dependencies where available; otherwise record `Part of #<map>` and `Blocked by: #<n>` in the issue body.

## When a skill says "publish to the issue tracker"

Create a GitHub issue in `dis0neplay/female-character-creation-workflow`.

## When a skill says "fetch the relevant ticket"

Run `gh issue view <number> --repo dis0neplay/female-character-creation-workflow --comments`.
