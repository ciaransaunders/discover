# AGENTS.md — Discover

This file is the canonical entry point for AI coding agents (OpenAI Codex, Google Antigravity, Claude Code, etc.) working in this repository. Read it before any task.

For Codex: this is a layered `AGENTS.md` workspace. Sub-projects have their own `AGENTS.md` with narrower scope — read the nearest one to the file you are editing.

For Antigravity: treat missions in this repo as scoped to a single sub-project at a time (`macos-app/` or `discover-dashboard/`). Use the "Sub-project routing" table below before dispatching agents.

---

## Project in one paragraph

**Discover** is a personalised RSS news aggregator with a dark-mode "Liquid Glass" UI. It exists in two forms: a **native SwiftUI app** (`macos-app/`, the active codebase, targets macOS 14+/iPadOS 17+/iOS 17+) and a **Next.js 15 web dashboard** (`discover-dashboard/`, the original and now reference implementation). The native app is the primary development target; the dashboard is kept as a spec/reference.

## Sub-project routing

| You are working on… | Go to | Primary agent doc |
|---|---|---|
| Anything SwiftUI / Xcode / the app itself | `macos-app/` | `macos-app/AGENTS.md` |
| Next.js web dashboard | `discover-dashboard/` | `discover-dashboard/AGENTS.md` |
| Design prototypes / glassmorphism CSS | `prototypes/liquid-glass-demo/` | this file |
| Shared docs / spec / handoff | `docs/` | this file |
| Build scripts (WebView wrapper only) | `scripts/` | this file |

If a task touches both sub-projects (e.g. keeping feed config in sync), treat `macos-app/` as primary and `discover-dashboard/` as reference.

### Folders that are NOT the active codebase

| Folder | What it is | How to treat it |
|---|---|---|
| `NewsApp-Swift/` | A parallel Swift Package Manager experiment (separate `Package.swift`, its own README and DECISIONS.md). **Not** the active app. | Do not modify unless the task explicitly names this folder. If a user request could plausibly mean either `macos-app/` or `NewsApp-Swift/`, confirm before editing. |
| `taste-skill-main/` | A third-party collection of AI "taste skills" (see its README); unrelated to the news app itself. | Do not modify. Do not treat as project source. |
| `Latest app/` | Legacy `.app` bundle wrapping the Next.js dashboard in a WKWebView. | Read-only. Not a build of the SwiftUI app. |
| `_archive/` | Superseded files kept for history. | Read-only. |
| `build/` | Xcode build output (DerivedData-like tree). | Ignore. Gitignored. Safe to delete locally. |
| `.claude/worktrees/silly-goodall/` | Stale git worktree duplicating the dashboard. | Do not edit. Gitignored. |

## Repository layout

```
.
├── AGENTS.md                  # this file — read first
├── README.md                  # human landing page
├── macos-app/                 # PRIMARY codebase (Swift 6 / SwiftUI / SwiftData)
│   ├── AGENTS.md              #   agent instructions scoped to the app
│   ├── CLAUDE.md              #   same content, kept for Claude Code compatibility
│   ├── Discover.xcodeproj/
│   ├── Discover/              #   app source
│   └── DiscoverTests/         #   unit tests + XML fixtures
├── discover-dashboard/        # REFERENCE Next.js 15 web app
│   └── AGENTS.md              #   agent instructions scoped to the dashboard
├── docs/
│   ├── HANDOFF.md             #   comprehensive porting guide
│   ├── IOS_TARGET_SETUP.md    #   how to add the iOS target in Xcode UI
│   └── discover-dashboard-spec.md
├── prototypes/liquid-glass-demo/   # static HTML/CSS design prototype
├── scripts/build_app.sh       # builds the legacy WebView wrapper, NOT the SwiftUI app
├── assets/                    # shared assets (app icon source)
├── Latest app/                # legacy WebView wrapper .app (not the SwiftUI build)
├── NewsApp-Swift/             # parallel SPM experiment — NOT the active app
├── taste-skill-main/          # unrelated third-party skills collection
├── build/                     # Xcode build output; gitignored
├── _archive/                  # superseded files; don't modify
├── AGENT_CONTEXT.md           # legacy agent briefing (still accurate, narrower scope)
├── PROJECT_MAP.md             # directory-tree map with move history
├── LLM_HANDOFF.md             # dated session handoff (2026-04-16)
└── BUG_REPORT.md              # tracked bug list (most fixed)
```

## Canonical documents (order of priority)

1. **This file** (`AGENTS.md`) — routing and repo-wide rules.
2. **`macos-app/AGENTS.md`** — primary app instructions.
3. **`docs/HANDOFF.md`** — deeper architecture / porting context.
4. **`LLM_HANDOFF.md`** — most recent session state (what works, what changed).
5. **`BUG_REPORT.md`** — known bugs and their fix status.
6. **`AGENT_CONTEXT.md` / `PROJECT_MAP.md`** — older but still accurate overviews.

`CLAUDE.md` files mirror `AGENTS.md` files so Claude Code and Codex see the same instructions. Keep them in sync when updating either.

## How to run / test

### Native app (primary)
```bash
open macos-app/Discover.xcodeproj
# In Xcode: select scheme "Discover", destination "My Mac", then Cmd+R. Cmd+U for tests.
```

CLI (works on normal macOS dev machines; fails in some sandboxes due to Swift macro plugin issues):
```bash
xcodebuild test \
  -project macos-app/Discover.xcodeproj \
  -scheme Discover \
  -destination 'platform=macOS' \
  -configuration Debug
```

### Web dashboard (reference)
```bash
cd discover-dashboard
npm install
npm run dev        # http://localhost:3000
npm run build      # production build
npm run lint       # next lint
```

## Repo-wide rules for agents

- **Do not modify `_archive/`.** Files there are superseded and kept only for historical reference.
- **Do not modify `Latest app/`.** It is a legacy WebView wrapper `.app` bundle, not a build of the SwiftUI app.
- **Do not run or rely on `scripts/build_app.sh`.** It builds the legacy wrapper only.
- **Do not commit build artifacts:** `build/`, `DerivedData/`, `.next/`, `node_modules/`, `xcuserdata/`, `*.xcuserstate`, `.DS_Store`. The root `.gitignore` covers these — leave it alone unless adding new patterns.
- **Feed config is duplicated** in `macos-app/Discover/Data/DefaultFeeds.swift` and `discover-dashboard/lib/feeds.ts`. When changing feed/category definitions, update both unless a task scopes to one platform.
- **djb2 hashing must match** across Swift (`IDGenerator.swift`) and TypeScript (`discover-dashboard/lib/fetchFeeds.ts`) — they produce article IDs that are meant to be interchangeable. Don't change the algorithm without updating both and planning for read-state reset.
- **No new third-party dependencies in the native app.** It is intentionally zero-dependency (Foundation + SwiftUI only).
- **Dark mode only** for the native app. Don't add light-mode styling.
- **SF Symbols only** for native-app icons.
- **Strict concurrency:** SwiftData usage is `@MainActor`; async work goes through actors (`RSSFetcherActor`, `OGImageActor`).

## Validation expectations (Antigravity-style artifacts)

When an agent completes a meaningful change, produce at least one of:
- A compiling diff confirmed by `xcodebuild` (native) or `npm run build` (web).
- Screenshots of the affected view(s) for UI changes.
- Output of `Cmd+U` / `xcodebuild test` for logic changes.
- Before/after snippet for refactors.

When writing a test is faster than setting up a screenshot, prefer tests.

## Known environment gotchas

- The workspace is **not** a git repo root — `git rev-parse --show-toplevel` resolves to `/Users/ciaran/Desktop`. Git commands may behave unexpectedly.
- Some sandboxed environments (including certain Codex setups) fail `xcodebuild` due to Swift macro plugin (`swift-plugin-server`) issues affecting `@Model`, `@Query`, `@Observable`. This is environmental, not a project defect — verify locally in Xcode when possible.
- `.claude/worktrees/silly-goodall/` is a stale git worktree duplicating the dashboard source. Don't edit code inside it; flag it for deletion if touched.
- Folder name contains a typo (`NEWS PORJECT copy`) — don't "fix" it; paths are hardcoded in some docs.

## Where to record progress

- For ongoing session state, update `LLM_HANDOFF.md` with the date and what changed.
- For newly discovered bugs, add an entry to `BUG_REPORT.md` with location and status.
- For structural moves, append to `PROJECT_MAP.md` "Files Moved During Reorganisation" table.
- Don't create new top-level `*_HANDOFF.md` / `*_CONTEXT.md` files; extend the existing ones.
