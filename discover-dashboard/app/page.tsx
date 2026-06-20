import { fetchAllFeeds } from "@/lib/fetchFeeds";
import Dashboard from "@/components/Dashboard";
import { ReadStateProvider } from "@/components/ReadStateProvider";
import { FeedConfigProvider } from "@/components/FeedConfigProvider";

export const dynamic = "force-dynamic"; // Use our own file-system cache instead of Next.js ISR

export default async function Home() {
  const { articles, lastUpdated } = await fetchAllFeeds();

  return (
    <FeedConfigProvider>
      <ReadStateProvider>
        <Dashboard initialArticles={articles} lastUpdated={lastUpdated} />
      </ReadStateProvider>
    </FeedConfigProvider>
  );
}
