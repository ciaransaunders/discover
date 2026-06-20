# `app/` - Next.js App Router

This directory contains the entry points for the React application.

- `page.tsx`: The main visual load. It is designated as fully dynamic and bypasses conventional static generation to hit the `fetchFeeds` mechanism.
- `layout.tsx`: Houses the core HTML wrapper and injects the global `bg-orbs` animation layer underneath the layout grid. 
- `globals.css`: Contains crucial styling mechanisms that must be recreated in SwiftUI using `.ultraThinMaterial` / Mesh Gradients. The "Liquid Glass" theme variables here define the opacity layers applied to components.
- `api/feeds/route.ts`: A serverless proxy exposing the refetch mechanism explicitly for when user runtime client configuration asks for fresh content across custom URLs.
