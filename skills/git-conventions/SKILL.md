---
name: git-conventions
description: >-
  Standardized git workflow for AI agents: conventional commit format, branch
  naming, PR creation via gh, diff review, and safe git operations. Use when
  writing commit messages, creating branches, opening PRs, or reviewing changes
  in any git repo on Windows or Linux. Keywords: git, commit, branch, PR, gh,
  github, conventional commit, commit message, rebase, merge, push, gpg.
---

# Git conventions

Standardized patterns for agent-driven git operations. Keeps commits consistent, PRs reviewable, and the git history clean.

## Commit messages (Conventional Commits)

```
<type>(<scope>): <short summary>

<body (optional)>

<footer (optional)>
```

**Types:** `feat`, `fix`, `chore`, `docs`, `style`, `refactor`, `perf`, `test`, `ci`, `build`, `revert`.

```
feat(auth): add OAuth2 PKCE flow
fix(parser): handle empty input in tokenizer
docs(readme): update install instructions
refactor(api): extract validation middleware
test(cli): add coverage for --json flag
```

Rules:
- Summary: imperative mood, no period, ≤72 chars
- Body: wrap at 72 chars, explain **what** and **why**, not **how**
- Footer: `BREAKING CHANGE:` or `Closes #123`

## Branch naming

```
<type>/<short-description>
```

```
feat/oauth-pkce
fix/empty-input-handling
docs/readme-update
chore/upgrade-deps
```

Use the same type prefixes as commits. Use hyphens, not underscores or slashes in the description.

## Workflow

### Starting new work

```powershell
# Ensure up to date:
git checkout main
git pull --rebase

# Create branch:
git checkout -b feat/my-feature
```

### Committing

```powershell
# Stage related changes only (not `git add .`):
git add src/auth/foo.ts src/auth/foo.test.ts

# Commit with conventional message:
git commit -m "feat(auth): add OAuth2 PKCE flow"
```

Use `git add -p` for partial staging when a file has unrelated changes.

### Before pushing

```powershell
# Rebase on main to keep history linear:
git fetch origin
git rebase origin/main

# Verify:
git log --oneline -10
```

### Pushing and PR

```powershell
# Push (first time needs -u):
git push -u origin feat/my-feature

# Create PR via gh:
gh pr create --title "feat(auth): add OAuth2 PKCE flow" --body "Summary of changes..."
```

### Reviewing changes

```powershell
# What changed:
git diff main...HEAD           # diff from main to current branch
git log --oneline main..HEAD   # commits on this branch only
git diff --stat main...HEAD    # files changed summary

# Own changes before commit:
git diff --cached              # staged changes only
```

## When to use full git vs aliases

| Operation | Use | Why |
|-----------|-----|-----|
| Status | `git status` | Full output, not abbreviated like `gst` |
| Diff | `git diff` or `gd` | `gd` uses delta pager when installed |
| Add | `git add <paths>` | Explicit, never `ga .` |
| Commit | `git commit -m "..."` | Full conventional message, not `gc` |
| Log | `git log --oneline -10` or `gl` | Both fine; `gl` shows graph |
| Push | `git push` | Explicit, not `gp` |

**Never** use `gc` (it prompts for editor) — always `git commit -m "msg"`.

## PR conventions

```powershell
# Title: same as the conventional commit for the main change
# Body: include what changed, why, and any breaking changes

gh pr create --title "feat(auth): add OAuth2 PKCE flow" `
  --body "## Summary

Adds PKCE (Proof Key for Code Exchange) flow to the OAuth2 client.

## Changes

- New PKCE middleware in \`src/auth/pkce.ts\`
- Updated token endpoint to accept code_verifier
- Added tests for all PKCE paths

Closes #42" `
  --label enhancement
```

### PR review

```powershell
# Checkout PR locally:
gh pr checkout <number>

# Review changes:
git diff main...HEAD

# Add review (inline comments via code review tools).
```

## Safe git operations

| Action | Safe? | Guidance |
|--------|-------|----------|
| `git status` | ✅ Always | First command in any task |
| `git diff` | ✅ Always | |
| `git log` | ✅ Always | |
| `git add <path>` | ✅ If intentional | Don't use `git add .` |
| `git commit` | ✅ Always | |
| `git push` | ✅ Default branch | Ask before force push |
| `git push --force` | ⚠️ Only if needed | Use `--force-with-lease` instead |
| `git reset` | ⚠️ Risk of data loss | Ask before `--hard` |
| `git rebase` | ⚠️ Only own branch | Never rebase shared branches |
| `git merge` | ✅ If fast-forward | Prefer rebase for feature branches |
| `git revert` | ✅ Safe | Use instead of reset for public history |

## Also see

- **pwsh-profile** — git aliases (gd, gst, gl), delta pager
- **just-recipes** — `just commit`, `just pr` recipes
