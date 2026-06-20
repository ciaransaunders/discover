"use client";

import {
  createContext,
  useContext,
  useState,
  useCallback,
  useEffect,
  ReactNode,
} from "react";
import { FeedConfig, CategoryConfig } from "@/lib/types";
import {
  feeds as defaultFeeds,
  categories as defaultCategories,
} from "@/lib/feeds";

interface FeedConfigContextType {
  feeds: FeedConfig[];
  categories: CategoryConfig[];
  addFeed: (feed: FeedConfig) => void;
  removeFeed: (url: string) => void;
  addCategory: (category: CategoryConfig) => void;
  removeCategory: (slug: string) => void;
  resetToDefaults: () => void;
  hasCustomConfig: boolean;
}

const FeedConfigContext = createContext<FeedConfigContextType>({
  feeds: defaultFeeds,
  categories: defaultCategories,
  addFeed: () => {},
  removeFeed: () => {},
  addCategory: () => {},
  removeCategory: () => {},
  resetToDefaults: () => {},
  hasCustomConfig: false,
});

const FEEDS_KEY = "discover-dashboard-feeds";
const CATEGORIES_KEY = "discover-dashboard-categories";

export function FeedConfigProvider({ children }: { children: ReactNode }) {
  const [feeds, setFeeds] = useState<FeedConfig[]>(defaultFeeds);
  const [categories, setCategories] =
    useState<CategoryConfig[]>(defaultCategories);
  const [hasCustomConfig, setHasCustomConfig] = useState(false);

  useEffect(() => {
    try {
      const storedFeeds = localStorage.getItem(FEEDS_KEY);
      const storedCats = localStorage.getItem(CATEGORIES_KEY);
      if (storedFeeds) {
        setFeeds(JSON.parse(storedFeeds));
        setHasCustomConfig(true);
      }
      if (storedCats) {
        setCategories(JSON.parse(storedCats));
      }
    } catch {
      // ignore
    }
  }, []);

  const persistFeeds = useCallback((f: FeedConfig[]) => {
    localStorage.setItem(FEEDS_KEY, JSON.stringify(f));
    setHasCustomConfig(true);
  }, []);

  const persistCategories = useCallback((c: CategoryConfig[]) => {
    localStorage.setItem(CATEGORIES_KEY, JSON.stringify(c));
  }, []);

  const addFeed = useCallback(
    (feed: FeedConfig) => {
      setFeeds((prev) => {
        // Don't add duplicate URLs
        if (prev.some((f) => f.url === feed.url)) return prev;
        const next = [...prev, feed];
        persistFeeds(next);
        return next;
      });
    },
    [persistFeeds]
  );

  const removeFeed = useCallback(
    (url: string) => {
      setFeeds((prev) => {
        const next = prev.filter((f) => f.url !== url);
        persistFeeds(next);
        return next;
      });
    },
    [persistFeeds]
  );

  const addCategory = useCallback(
    (category: CategoryConfig) => {
      setCategories((prev) => {
        if (prev.some((c) => c.slug === category.slug)) return prev;
        const next = [...prev, category];
        persistCategories(next);
        return next;
      });
    },
    [persistCategories]
  );

  const removeCategory = useCallback(
    (slug: string) => {
      setCategories((prev) => {
        const next = prev.filter((c) => c.slug !== slug);
        persistCategories(next);
        return next;
      });
      // Also remove all feeds in that category
      setFeeds((prev) => {
        const next = prev.filter((f) => f.category !== slug);
        persistFeeds(next);
        return next;
      });
    },
    [persistCategories, persistFeeds]
  );

  const resetToDefaults = useCallback(() => {
    setFeeds(defaultFeeds);
    setCategories(defaultCategories);
    localStorage.removeItem(FEEDS_KEY);
    localStorage.removeItem(CATEGORIES_KEY);
    setHasCustomConfig(false);
  }, []);

  return (
    <FeedConfigContext.Provider
      value={{
        feeds,
        categories,
        addFeed,
        removeFeed,
        addCategory,
        removeCategory,
        resetToDefaults,
        hasCustomConfig,
      }}
    >
      {children}
    </FeedConfigContext.Provider>
  );
}

export function useFeedConfig() {
  return useContext(FeedConfigContext);
}
