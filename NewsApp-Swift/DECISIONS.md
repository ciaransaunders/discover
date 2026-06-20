# Architecture Decisions Log

1. **Pure Swift Package Manager (SPM):**
   Due to local constraints with Homebrew preventing the installation of `xcodegen`, the project falls back to a pure `Package.swift` executable setup as instructed by the constraints. This allows building the entire iOS application architecture without `.xcodeproj` or `.pbxproj` files resolving merge conflict metadata.

2. **Observation Framework (`@Observable`) over Combine (`ObservableObject`):**
   The project requires iOS 17+. The Observation framework is modern, lightweight, reduces view re-evaluations, and does not require manual `@Published` annotations for all properties.

3. **Routing Enum for Navigation:**
   Navigation logic is detached from the views in favor of a centralized type-safe `Route` enum. A `NavigationStack` is bound to a state array of these routes to manage the stack securely and avoiding deprecated APIs (like `NavigationView`).

4. **Service-Oriented Architecture (Protocol-based):**
   External dependencies and APIs are mocked by defining a Protocol (e.g., `RSSFetcherServiceType`) that guarantees the ViewModels and Views don't have hardcoded networking. This makes unit tests fast and resilient.
