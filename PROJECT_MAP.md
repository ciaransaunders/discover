# Project Map — Discover

## What This Project Does

**Discover** is a personalised news aggregator that fetches RSS feeds across curated categories (AI/ML, Tech, Gaming, Film, Chelsea FC, UK News, Science, Finance, Lego, Legal Tech, Neuroscience) and displays them in a dark-mode "Liquid Glass" (glassmorphism) UI. The project exists in two forms: a **Next.js web dashboard** (the original) and a **native SwiftUI macOS app** (the active port). The goal is a cross-platform Apple app targeting macOS, iPadOS, and iOS.

---

## Directory Tree

```
.
├── macos-app/                      # Native SwiftUI app (Xcode project) — PRIMARY CODEBASE
│   ├── Discover.xcodeproj/         #   Xcode project file
│   ├── Discover/                   #   App source code
│   │   ├── App/                    #     Entry point: DiscoverApp.swift, ContentView.swift
│   │   ├── Core/                   #     Business logic
│   │   │   ├── Models/             #       Data models (Article, Category, Feed)
│   │   │   ├── Parsing/            #       RSS XML parsing + thumbnail extraction
│   │   │   ├── Services/           #       Network actors (RSS fetch, OG image scraping)
│   │   │   └── Utilities/          #       HTML stripping, ID generation, URL normalising
│   │   ├── Data/                   #     Default feed configuration (DefaultFeeds.swift)
│   │   ├── Features/               #     Feature modules (UI + ViewModel pairs)
│   │   │   ├── ArticleCard/        #       Standard + hero article card views
│   │   │   ├── ArticleList/        #       Article list view + view model
│   │   │   ├── CategorySidebar/    #       Category filter sidebar
│   │   │   ├── FeedManager/        #       Feed add/remove UI + view model
│   │   │   └── Preferences/        #       App preferences view
│   │   ├── UI/                     #     Shared UI components
│   │   │   ├── Components/         #       CategoryBadge, FaviconImage, GlassCard, TimeAgoText
│   │   │   └── Extensions/         #       Color+Hex extension
│   │   └── Resources/              #     Assets.xcassets, entitlements, Info.plist
│   └── DiscoverTests/              #   Unit tests
│       └── DiscoverTests.swift
│
├── discover-dashboard/             # Original Next.js web dashboard
│   ├── app/                        #   Next.js App Router (page.tsx, layout.tsx, API route)
│   ├── components/                 #   React components (ArticleCard, Header, HeroCard, etc.)
│   ├── lib/                        #   Utilities (feeds config, fetch logic, types, cache, OG image)
│   ├── _discovery/                 #   UI reference screenshots
│   ├── package.json                #   Dependencies
│   └── [config files]              #   tsconfig, tailwind, postcss, next.config
│
├── docs/                           # Project documentation
│   ├── HANDOFF.md                  #   Comprehensive handoff doc for the SwiftUI port
│   └── discover-dashboard-spec.md  #   Original product spec for the web dashboard
│
├── scripts/                        # Build & utility scripts
│   └── build_app.sh                #   Shell script to compile the WebView wrapper .app
│
├── assets/                         # Shared project assets
│   └── discover_app_icon.png       #   App icon source image (1024px)
│
├── prototypes/                     # Design prototypes & experiments
│   └── liquid-glass-demo/          #   Static HTML/CSS/JS glassmorphism design system demo
│       ├── index.html
│       ├── style.css
│       └── script.js
│
├── Latest app/                     # Copy of the latest built macOS .app bundle
│   └── DiscoverPlatform.app        #   Built Feb 22 — WebView wrapper around the Next.js dashboard
│
├── _archive/                       # Archived/superseded files (kept for reference)
│   ├── native-app/                 #   Early WebView wrapper (single Discover.swift file)
│   │   └── Discover.swift          #   Superseded by macos-app/ Xcode project
│   ├── Discover.app                #   Older compiled app (Feb 21, superseded by DiscoverPlatform.app)
│   ├── DiscoverPlatform.app        #   Original location of the compiled WebView wrapper
│   ├── test.swift                  #   Test file containing only print("Hello")
│   └── build_output.log            #   Failed build log (permission denied error)
│
├── .claude/                        # Claude Code configuration (do not modify)
│   ├── launch.json
│   ├── settings.local.json
│   └── worktrees/silly-goodall/    #   Git worktree — duplicate of discover-dashboard source
│
├── PROJECT_MAP.md                  # This file
└── AGENT_CONTEXT.md                # Briefing document for agentic IDE assistants
```

---

## Files Moved During Reorganisation

| Original Location | New Location | Reason |
|---|---|---|
| `HANDOFF.md` | `docs/HANDOFF.md` | Documentation consolidation |
| `discover-dashboard-spec.md` | `docs/discover-dashboard-spec.md` | Documentation consolidation |
| `build_app.sh` | `scripts/build_app.sh` | Scripts folder |
| `discover_app_icon.png` | `assets/discover_app_icon.png` | Assets folder |
| `index.html`, `style.css`, `script.js` | `prototypes/liquid-glass-demo/` | Design prototype, not app source |
| `test.swift` | `_archive/test.swift` | Orphaned test file (single print statement) |
| `build_output.log` | `_archive/build_output.log` | Failed build log, no longer relevant |
| `native-app/` | `_archive/native-app/` | Superseded by `macos-app/` Xcode project |
| `Discover.app` | `_archive/Discover.app` | Older compiled app, superseded |
| `DiscoverPlatform.app` | `_archive/DiscoverPlatform.app` | Original location preserved in archive; copy in `Latest app/` |

No files were renamed. No file contents were modified.

---

## Needs Review

- **`.claude/worktrees/silly-goodall/`** — This is a full git worktree containing a duplicate of the `discover-dashboard` source code plus a `.next` build cache and `node_modules`. It takes up significant space. Consider deleting it if the worktree branch has been merged, or keeping it if work is ongoing.
- **`discover-dashboard/.next/` and `node_modules/`** — Build artifacts and dependencies. Not checked into version control typically. Consider adding a `.gitignore` if one doesn't exist at the dashboard level.
- **`macos-app/Discover.xcodeproj/xcuserdata/`** — Xcode user-specific state. Should be in `.gitignore`.

---

## Missing Files

- **No `.gitignore`** at the project root (the worktree has one but the main project does not)
- **No `README.md`** at the project root
- **No `LICENSE` file**
- **No `.gitignore` entries** for `.DS_Store` files (several present throughout)
