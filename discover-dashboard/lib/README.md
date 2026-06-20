# `lib/` - Utilities & Core Business Logic

The engine room of the application. 

- `fetchFeeds.ts`: The heaviest lift file containing RSS standard ingestion rules, description snippet stripping logic, specific URL normalization heuristics to handle common tracking parameters (UTMs), and the core DJB2 hash-ID generator.
- `ogImage.ts`: Scrapes raw HTML for `<meta property="og:image">` specifically designed as an override system for feeds known to package low-quality images in the standard XML specification (e.g. BBC).
- `cache.ts`: Direct NodeJS filesystem operations writing raw JSON to `os.homedir()` - this caching structure is entirely unsupported on native iOS/macOS sandboxes and must be refactored utilizing the local `FileManager` API/App Group Containers.
- `feeds.ts`: The baseline arrays defining the visual color schema per topic slug, and listing out default endpoints to bootstrap an empty application.
