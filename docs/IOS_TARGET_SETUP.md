# iOS Target Setup — DiscoverMobile

These steps **must be performed in Xcode's UI** — they cannot be done from the command line or by editing `project.pbxproj` while Xcode is open.

Open `macos-app/Discover.xcodeproj` in Xcode before starting.

---

## Step 1 — Create the iOS target

1. In Xcode menu: **File > New > Target...**
2. Select the **iOS** tab at the top
3. Choose **App** and click **Next**
4. Set these values:
   - Product Name: `DiscoverMobile`
   - Bundle Identifier: `com.discover.app.mobile`
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Testing System: **Swift Testing**
5. Click **Finish**

## Step 2 — Add all shared source files to the new target

1. In the Project Navigator, select all of these files (Cmd+click each):
   - `Discover/App/DiscoverApp.swift`
   - `Discover/App/ContentView.swift`
   - `Discover/Features/` — every `.swift` file in all subdirectories
   - `Discover/Core/` — every `.swift` file in all subdirectories
   - `Discover/Data/DefaultFeeds.swift`
   - `Discover/UI/` — every `.swift` file in all subdirectories
   - `Discover/Resources/Assets.xcassets`
2. Open the **File Inspector** (right panel, first tab)
3. Under **Target Membership**, check the box for **DiscoverMobile** (keep **Discover** checked too)

## Step 3 — Set deployment target

1. Select the **Discover** project in the navigator (the blue icon at top)
2. Select the **DiscoverMobile** target
3. Go to the **General** tab
4. Set **Minimum Deployments > iOS** to **26.0**
5. Go to **Build Settings**, search for "Swift Language Version" and set to **6.0**

## Step 4 — Delete the auto-generated files

Xcode will have created a `DiscoverMobile/` folder with its own `DiscoverMobileApp.swift`, `ContentView.swift`, and `Assets.xcassets`. **Delete those files** since we're sharing the existing ones from the `Discover/` folder.

---

## Verification

After completing these steps, you should be able to:
1. Select the **DiscoverMobile** scheme in the toolbar
2. Choose an iOS Simulator (e.g. iPhone 16)
3. Press **Cmd+B** to build — it should compile without errors
