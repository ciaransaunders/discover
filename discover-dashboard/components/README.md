# `components/` - React UI Elements

This directory encapsulates all React presentation and local-state handling logic.

- `Header.tsx` acts as the primary orchestrator that mounts state and handles refetch triggers.
- `ArticleCard.tsx` / `HeroCard.tsx` dictate the precise UI masking, gradients, spacing, and snippet line-clamping logic that forms the visual core of a feed item.
- `FeedManager.tsx` handles complex input parsing, color generation, and validation for custom JSON local storage overrides.
- `FeedConfigProvider.tsx` & `ReadStateProvider.tsx` are React contexts syncing to `localStorage` – these should be conceptually replaced by native `@AppStorage`/`SwiftData` architecture.
