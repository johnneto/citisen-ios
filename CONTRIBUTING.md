# Contributing to Citisen

## Branching model

| Branch | Role |
|---|---|
| `main` | Release branch. Only ever updated by a PR from `develop`. |
| `develop` | Integration branch. Always green (SwiftLint strict passes). |
| `feat/…`, `fix/…`, … | Short-lived work branches. Cut from `develop`, merged back into `develop` by PR. |

**Never commit directly to `develop` or `main`.** Every change reaches `develop`
through a pull request from its own branch. `develop` should only ever advance via
merge commits.

### Branch naming

`<type>/<short-kebab-description>`, where `<type>` is the same set used for commit
prefixes:

| Prefix | Use for |
|---|---|
| `feat/` | New user-facing capability — `feat/searched-place-pin-and-keep` |
| `fix/` | Bug fix — `fix/map-pinch-zoom-blocked-by-pins` |
| `refactor/` | Restructuring with no behaviour change — `refactor/native-tabview` |
| `chore/` | Tooling, CI, dependencies, project settings |
| `docs/` | Documentation only |

Describe the change, not the ticket: `fix/map-pinch-zoom-blocked-by-pins` beats
`fix/ticket-42`. Reference the issue number in the PR body instead. Keep branches
narrow — one reviewable concern each.

## Workflow

### 1. Start from an up-to-date `develop`

```bash
git checkout develop && git pull --ff-only origin develop
```

If `--ff-only` fails, your local `develop` has drifted — see
[Recovering](#recovering-from-commits-made-on-develop) below.

### 2. Cut the branch

```bash
git checkout -b feat/short-description
```

### 3. Commit as you go

Commits follow [Conventional Commits](https://www.conventionalcommits.org/) with the
feature area as the scope:

```bash
git commit -m "feat(map): keep searched place pinned after dismiss"
```

Common scopes in this repo: `map`, `spots`, `search`, `poi`, `saved`, `onboarding`.
Omit the scope for changes that span the app.

### 4. Verify before pushing

```bash
swiftlint lint --strict
```

```bash
xcodebuild test -project Citisen.xcodeproj -scheme Citisen -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

CI only runs SwiftLint, so the test run is on you.

### 5. Push and open the PR against `develop`

```bash
git push -u origin HEAD
```

```bash
gh pr create --base develop --fill --body-file .github/pull_request_template.md
```

The `--base develop` is the important part: `gh` defaults to the repository's default
branch, which is `main`. Opening the PR in the browser (`gh pr create --web`) picks up
the template automatically.

Fill in the template, especially the **API & cost impact** section if you touched the
Gemini or Places pipeline.

### 6. Keep the branch current

If `develop` moves while your PR is open, rebase rather than merging `develop` into
your branch — it keeps the PR diff limited to your own changes:

```bash
git fetch origin && git rebase origin/develop
```

```bash
git push --force-with-lease
```

Use `--force-with-lease`, never plain `--force`. If someone else has commits on your
branch, merge instead of rebasing so you don't rewrite their history.

### 7. After the merge

```bash
git checkout develop && git pull --ff-only origin develop && git branch -d feat/short-description
```

```bash
git push origin --delete feat/short-description
```

### Releasing

`main` advances only by PR from `develop`, at the point you want to ship a TestFlight
build. Same rule: no direct commits.

## Recovering from commits made on `develop`

If you've already committed to local `develop` and haven't pushed, move the work onto
a branch and rewind `develop`:

```bash
git checkout -b fix/short-description
```

```bash
git checkout develop && git reset --hard origin/develop
```

`git reset --hard` discards anything on `develop` that isn't on the new branch and
isn't pushed — confirm `git log origin/develop..develop` is empty on the branch you
just created before running it.

If the commits are already pushed to `origin/develop`, don't rewrite the shared
branch. Leave them and open the next change as a proper branch, or revert them with
`git revert` through a PR.

## Optional guardrails

Make the rule enforce itself rather than relying on memory.

**Branch protection (recommended).** In the repository settings on GitHub, add a rule
for `develop` and `main` requiring a pull request before merging and blocking direct
pushes. Anything pushed straight to `develop` is then rejected by the server. This
changes repository settings, so make the change yourself under
`Settings → Branches → Add branch ruleset`.

**Local pre-commit hook.** A per-clone safety net that refuses commits on the
protected branches. Save as `.git/hooks/pre-commit` and `chmod +x` it (hooks live
outside version control, so each clone needs its own):

```bash
#!/bin/sh
branch=$(git rev-parse --abbrev-ref HEAD)
case "$branch" in
  develop|main)
    echo "Refusing to commit directly to $branch — cut a branch first:"
    echo "  git checkout -b feat/your-change"
    exit 1
    ;;
esac
```
