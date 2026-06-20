# Discover

A personalised RSS news aggregator with a dark-mode "Liquid Glass" UI.

Two implementations live in this repo:

| | Path | Status | Stack |
|---|---|---|---|
| **Native app** (primary) | `macos-app/` | Active development | Swift 6, SwiftUI, SwiftData |
| **Web dashboard** (reference) | `discover-dashboard/` | Reference only | Next.js 15, React 19, TypeScript |

## Quick start

### Native app (macOS)

```bash
open macos-app/Discover.xcodeproj
```

In Xcode: scheme **Discover**, destination **My Mac**, then `Cmd+R`. Tests: `Cmd+U`.

### Web dashboard

```bash
cd discover-dashboard
npm install
npm run dev     # http://localhost:3000
```

## For AI coding agents

Start here, in this order:

1. **`AGENTS.md`** — repo-wide routing and rules (Codex, Antigravity, Claude).
2. **`macos-app/AGENTS.md`** — native-app instructions (where most work happens).
3. **`discover-dashboard/AGENTS.md`** — dashboard instructions.
4. **`LLM_HANDOFF.md`** — most recent session state.
5. **`BUG_REPORT.md`** — known bugs and fix status.
6. **`docs/HANDOFF.md`** — comprehensive porting / architecture guide.
7. **`docs/IOS_TARGET_SETUP.md`** — how to add the iOS target.

Older overview docs (`AGENT_CONTEXT.md`, `PROJECT_MAP.md`) are still accurate for context but narrower in scope than `AGENTS.md`.

## Layout

```
.
├── AGENTS.md                 # agent entry point
├── README.md                 # you are here
├── macos-app/                # PRIMARY: SwiftUI Xcode project
├── discover-dashboard/       # REFERENCE: Next.js dashboard
├── docs/                     # HANDOFF, iOS setup, product spec
├── prototypes/               # Liquid Glass static design prototype
├── scripts/                  # build_app.sh (legacy WebView wrapper only)
├── assets/                   # app icon source
├── Latest app/               # legacy .app bundle (not the SwiftUI build)
├── NewsApp-Swift/            # parallel SPM experiment — NOT the active app
├── taste-skill-main/         # unrelated third-party skills collection
├── build/                    # Xcode build output (gitignored)
└── _archive/                 # superseded files (do not edit)
```

## Contributing

- No third-party dependencies in the native app.
- Dark mode only.
- SF Symbols only.
- Feed config is duplicated across `macos-app/Discover/Data/DefaultFeeds.swift` and `discover-dashboard/lib/feeds.ts` — keep them in sync.

See `AGENTS.md` for the full ruleset.
