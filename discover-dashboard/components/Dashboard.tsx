"use client";

import { useState, useEffect, useCallback, useRef } from "react";
import { Article } from "@/lib/types";
import HeroCard from "./HeroCard";
import MasonryGrid from "./MasonryGrid";
import FeedManager from "./FeedManager";
import Header from "./Header";
import { useFeedConfig } from "./FeedConfigProvider";

interface DashboardProps {
  initialArticles: Article[];
  lastUpdated: number;
}

export default function Dashboard({ initialArticles, lastUpdated }: DashboardProps) {
  const [activeCategory, setActiveCategory] = useState<string | null>(null);
  const [articles, setArticles] = useState<Article[]>(initialArticles);
  const [loading, setLoading] = useState(false);
  const [feedManagerOpen, setFeedManagerOpen] = useState(false);
  const [cacheAge, setCacheAge] = useState(lastUpdated);
  const { feeds } = useFeedConfig();

  // Ref to hold the latest feeds for refetching without stale closures
  const feedsRef = useRef(feeds);
  feedsRef.current = feeds;

  // Update displayed cache age every 30 seconds
  const [, setTick] = useState(0);
  useEffect(() => {
    const interval = setInterval(() => setTick((t) => t + 1), 30000);
    return () => clearInterval(interval);
  }, []);

  const refetchFeeds = useCallback(async () => {
    setLoading(true);
    try {
      const res = await fetch("/api/feeds", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ feeds: feedsRef.current }),
      });
      if (res.ok) {
        const data = await res.json();
        setArticles(data.articles);
        setCacheAge(Date.now());
      }
    } catch (e) {
      console.error("Failed to refetch feeds:", e);
    } finally {
      setLoading(false);
    }
  }, []);

  const filtered = activeCategory
    ? articles.filter((a) => a.category === activeCategory)
    : articles;

  const heroArticle = filtered[0];
  const gridArticles = filtered.slice(1);

  return (
    <div className="min-h-[100dvh]">
      <Header
        activeCategory={activeCategory}
        onCategoryChange={setActiveCategory}
        loading={loading}
        cacheAge={cacheAge}
        onRefetch={refetchFeeds}
        onOpenFeedManager={() => setFeedManagerOpen(true)}
        filteredCount={filtered.length}
        articleIds={filtered.map((a) => a.id)}
      />

      {/* Content */}
      <main className="max-w-[1400px] mx-auto px-4 sm:px-6 lg:px-8 py-12 md:py-20">
        <div className="space-y-12 md:space-y-20">
          {heroArticle && (
            <div className="w-full">
              <HeroCard article={heroArticle} />
            </div>
          )}
          
          <div className="relative">
            <MasonryGrid articles={gridArticles} />
          </div>
        </div>
      </main>

      {/* Feed Manager Panel */}
      <FeedManager
        open={feedManagerOpen}
        onClose={() => setFeedManagerOpen(false)}
        onFeedsChanged={refetchFeeds}
      />
    </div>
  );
}
