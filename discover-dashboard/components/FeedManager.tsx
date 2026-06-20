"use client";

import { useState, useRef, useEffect } from "react";
import { useFeedConfig } from "./FeedConfigProvider";

const PRESET_COLORS = [
  "#8b5cf6", "#3b82f6", "#ef4444", "#f59e0b", "#0347fc",
  "#10b981", "#06b6d4", "#22c55e", "#f97316", "#a855f7",
  "#ec4899", "#6366f1", "#14b8a6", "#e11d48", "#84cc16",
];

interface FeedManagerProps {
  open: boolean;
  onClose: () => void;
  onFeedsChanged: () => void;
}

export default function FeedManager({
  open,
  onClose,
  onFeedsChanged,
}: FeedManagerProps) {
  const {
    feeds,
    categories,
    addFeed,
    removeFeed,
    addCategory,
    removeCategory,
    resetToDefaults,
  } = useFeedConfig();

  const [tab, setTab] = useState<"feeds" | "categories">("feeds");

  // Add feed form
  const [newName, setNewName] = useState("");
  const [newUrl, setNewUrl] = useState("");
  const [newCategory, setNewCategory] = useState(categories[0]?.slug || "");
  const [feedError, setFeedError] = useState("");

  // Add category form
  const [newCatLabel, setNewCatLabel] = useState("");
  const [newCatSlug, setNewCatSlug] = useState("");
  const [newCatColor, setNewCatColor] = useState(PRESET_COLORS[0]);
  const [catError, setCatError] = useState("");

  // Search/filter
  const [search, setSearch] = useState("");

  const panelRef = useRef<HTMLDivElement>(null);

  // Sync default category selection when categories change (e.g. after localStorage load)
  useEffect(() => {
    setNewCategory((prev) => {
      if (categories.some((c) => c.slug === prev)) return prev;
      return categories[0]?.slug || "";
    });
  }, [categories]);

  // Close on escape
  useEffect(() => {
    const handler = (e: KeyboardEvent) => {
      if (e.key === "Escape") onClose();
    };
    if (open) window.addEventListener("keydown", handler);
    return () => window.removeEventListener("keydown", handler);
  }, [open, onClose]);

  // Close on click outside
  useEffect(() => {
    const handler = (e: MouseEvent) => {
      if (panelRef.current && !panelRef.current.contains(e.target as Node)) {
        onClose();
      }
    };
    if (open) {
      setTimeout(() => window.addEventListener("mousedown", handler), 0);
    }
    return () => window.removeEventListener("mousedown", handler);
  }, [open, onClose]);

  const handleAddFeed = () => {
    setFeedError("");
    if (!newName.trim()) {
      setFeedError("Name is required");
      return;
    }
    if (!newUrl.trim()) {
      setFeedError("URL is required");
      return;
    }
    try {
      new URL(newUrl.trim());
    } catch {
      setFeedError("Invalid URL");
      return;
    }
    if (!newCategory) {
      setFeedError("Select a category");
      return;
    }
    if (feeds.some((f) => f.url === newUrl.trim())) {
      setFeedError("This feed URL already exists");
      return;
    }
    addFeed({ name: newName.trim(), url: newUrl.trim(), category: newCategory });
    setNewName("");
    setNewUrl("");
    setFeedError("");
    onFeedsChanged();
  };

  const handleRemoveFeed = (url: string) => {
    removeFeed(url);
    onFeedsChanged();
  };

  const handleAddCategory = () => {
    setCatError("");
    if (!newCatLabel.trim()) {
      setCatError("Label is required");
      return;
    }
    const slug = newCatSlug.trim() || newCatLabel.trim().toLowerCase().replace(/[^a-z0-9]+/g, "-");
    if (categories.some((c) => c.slug === slug)) {
      setCatError("Category slug already exists");
      return;
    }
    addCategory({ slug, label: newCatLabel.trim(), color: newCatColor });
    setNewCatLabel("");
    setNewCatSlug("");
    setCatError("");
  };

  const handleRemoveCategory = (slug: string) => {
    removeCategory(slug);
    onFeedsChanged();
  };

  const handleReset = () => {
    resetToDefaults();
    onFeedsChanged();
  };

  const filteredFeeds = search
    ? feeds.filter(
      (f) =>
        f.name.toLowerCase().includes(search.toLowerCase()) ||
        f.url.toLowerCase().includes(search.toLowerCase()) ||
        f.category.toLowerCase().includes(search.toLowerCase())
    )
    : feeds;

  // Group feeds by category
  const groupedFeeds = categories.map((cat) => ({
    ...cat,
    feeds: filteredFeeds.filter((f) => f.category === cat.slug),
  }));

  // Include uncategorized feeds
  const uncategorized = filteredFeeds.filter(
    (f) => !categories.some((c) => c.slug === f.category)
  );

  if (!open) return null;

  return (
    <>
      {/* Backdrop */}
      <div className="fixed inset-0 z-[60] bg-black/50 backdrop-blur-sm transition-opacity" />

      {/* Panel */}
      <div
        ref={panelRef}
        className="fixed right-0 top-0 bottom-0 z-[70] w-full max-w-lg overflow-hidden flex flex-col glass-header border-l border-white/5 shadow-2xl shadow-black/50 animate-slide-in"
      >
        {/* Panel header */}
        <div className="flex items-center justify-between px-6 py-4 border-b border-white/5">
          <h2 className="text-lg font-semibold text-white">Feed Manager</h2>
          <div className="flex items-center gap-2">
            <button
              onClick={handleReset}
              className="text-xs text-white/30 hover:text-orange-400 transition-colors px-3 py-1.5 rounded-lg hover:bg-white/5"
            >
              Reset defaults
            </button>
            <button
              onClick={onClose}
              className="text-white/40 hover:text-white transition-colors p-1.5 rounded-lg hover:bg-white/5"
            >
              <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                <line x1="18" y1="6" x2="6" y2="18" />
                <line x1="6" y1="6" x2="18" y2="18" />
              </svg>
            </button>
          </div>
        </div>

        {/* Tabs */}
        <div className="flex border-b border-white/5">
          <button
            onClick={() => setTab("feeds")}
            className={`flex-1 py-3 text-sm font-medium transition-colors ${tab === "feeds"
                ? "text-white border-b-2 border-white/40"
                : "text-white/40 hover:text-white/60"
              }`}
          >
            Feeds ({feeds.length})
          </button>
          <button
            onClick={() => setTab("categories")}
            className={`flex-1 py-3 text-sm font-medium transition-colors ${tab === "categories"
                ? "text-white border-b-2 border-white/40"
                : "text-white/40 hover:text-white/60"
              }`}
          >
            Categories ({categories.length})
          </button>
        </div>

        {/* Content */}
        <div className="flex-1 overflow-y-auto">
          {tab === "feeds" && (
            <div>
              {/* Add feed form */}
              <div className="p-4 border-b border-white/5">
                <h3 className="text-sm font-medium text-white/60 mb-3">Add a feed</h3>
                <div className="space-y-2">
                  <input
                    type="text"
                    placeholder="Feed name (e.g. TechCrunch)"
                    value={newName}
                    onChange={(e) => setNewName(e.target.value)}
                    className="w-full px-3 py-2 rounded-lg bg-white/5 border border-white/10 text-white text-sm placeholder:text-white/20 focus:outline-none focus:border-white/20 transition-colors"
                  />
                  <input
                    type="url"
                    placeholder="RSS feed URL"
                    value={newUrl}
                    onChange={(e) => setNewUrl(e.target.value)}
                    className="w-full px-3 py-2 rounded-lg bg-white/5 border border-white/10 text-white text-sm placeholder:text-white/20 focus:outline-none focus:border-white/20 transition-colors"
                    onKeyDown={(e) => {
                      if (e.key === "Enter") handleAddFeed();
                    }}
                  />
                  <div className="flex gap-2">
                    <select
                      value={newCategory}
                      onChange={(e) => setNewCategory(e.target.value)}
                      className="flex-1 px-3 py-2 rounded-lg bg-white/5 border border-white/10 text-white text-sm focus:outline-none focus:border-white/20 transition-colors"
                    >
                      {categories.map((cat) => (
                        <option key={cat.slug} value={cat.slug} className="bg-[#1a1a1a]">
                          {cat.label}
                        </option>
                      ))}
                    </select>
                    <button
                      onClick={handleAddFeed}
                      className="px-4 py-2 rounded-lg bg-white/10 hover:bg-white/15 text-white text-sm font-medium transition-colors border border-white/10"
                    >
                      Add
                    </button>
                  </div>
                  {feedError && (
                    <p className="text-red-400 text-xs">{feedError}</p>
                  )}
                </div>
              </div>

              {/* Search */}
              <div className="px-4 pt-3 pb-2">
                <input
                  type="text"
                  placeholder="Search feeds..."
                  value={search}
                  onChange={(e) => setSearch(e.target.value)}
                  className="w-full px-3 py-2 rounded-lg bg-white/5 border border-white/10 text-white text-sm placeholder:text-white/20 focus:outline-none focus:border-white/20 transition-colors"
                />
              </div>

              {/* Feed list grouped by category */}
              <div className="px-4 pb-4">
                {groupedFeeds.map((group) => {
                  if (group.feeds.length === 0) return null;
                  return (
                    <div key={group.slug} className="mt-4">
                      <div className="flex items-center gap-2 mb-2">
                        <div
                          className="w-2.5 h-2.5 rounded-full"
                          style={{ backgroundColor: group.color }}
                        />
                        <h4 className="text-xs font-semibold text-white/40 uppercase tracking-wider">
                          {group.label}
                        </h4>
                        <span className="text-xs text-white/20">{group.feeds.length}</span>
                      </div>
                      <div className="space-y-1">
                        {group.feeds.map((feed) => (
                          <div
                            key={feed.url}
                            className="group/item flex items-center gap-3 px-3 py-2 rounded-lg hover:bg-white/5 transition-colors"
                          >
                            <div className="flex-1 min-w-0">
                              <p className="text-sm text-white/80 truncate">
                                {feed.name}
                              </p>
                              <p className="text-xs text-white/20 truncate">
                                {feed.url}
                              </p>
                            </div>
                            <button
                              onClick={() => handleRemoveFeed(feed.url)}
                              className="shrink-0 opacity-0 group-hover/item:opacity-100 text-white/30 hover:text-red-400 transition-all p-1 rounded hover:bg-white/5"
                              title="Remove feed"
                            >
                              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                                <polyline points="3,6 5,6 21,6" />
                                <path d="M19,6v14a2,2,0,0,1-2,2H7a2,2,0,0,1-2-2V6m3,0V4a2,2,0,0,1,2-2h4a2,2,0,0,1,2,2v2" />
                              </svg>
                            </button>
                          </div>
                        ))}
                      </div>
                    </div>
                  );
                })}
                {uncategorized.length > 0 && (
                  <div className="mt-4">
                    <h4 className="text-xs font-semibold text-white/40 uppercase tracking-wider mb-2">
                      Uncategorized
                    </h4>
                    <div className="space-y-1">
                      {uncategorized.map((feed) => (
                        <div
                          key={feed.url}
                          className="group/item flex items-center gap-3 px-3 py-2 rounded-lg hover:bg-white/5 transition-colors"
                        >
                          <div className="flex-1 min-w-0">
                            <p className="text-sm text-white/80 truncate">{feed.name}</p>
                            <p className="text-xs text-white/20 truncate">{feed.url}</p>
                          </div>
                          <button
                            onClick={() => handleRemoveFeed(feed.url)}
                            className="shrink-0 opacity-0 group-hover/item:opacity-100 text-white/30 hover:text-red-400 transition-all p-1 rounded hover:bg-white/5"
                          >
                            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                              <polyline points="3,6 5,6 21,6" />
                              <path d="M19,6v14a2,2,0,0,1-2,2H7a2,2,0,0,1-2-2V6m3,0V4a2,2,0,0,1,2-2h4a2,2,0,0,1,2,2v2" />
                            </svg>
                          </button>
                        </div>
                      ))}
                    </div>
                  </div>
                )}
                {filteredFeeds.length === 0 && (
                  <p className="text-center text-white/20 text-sm py-8">
                    {search ? "No feeds match your search." : "No feeds configured."}
                  </p>
                )}
              </div>
            </div>
          )}

          {tab === "categories" && (
            <div>
              {/* Add category form */}
              <div className="p-4 border-b border-white/5">
                <h3 className="text-sm font-medium text-white/60 mb-3">Add a category</h3>
                <div className="space-y-2">
                  <input
                    type="text"
                    placeholder="Category label (e.g. Music)"
                    value={newCatLabel}
                    onChange={(e) => setNewCatLabel(e.target.value)}
                    className="w-full px-3 py-2 rounded-lg bg-white/5 border border-white/10 text-white text-sm placeholder:text-white/20 focus:outline-none focus:border-white/20 transition-colors"
                  />
                  <input
                    type="text"
                    placeholder="Slug (optional, auto-generated)"
                    value={newCatSlug}
                    onChange={(e) => setNewCatSlug(e.target.value)}
                    className="w-full px-3 py-2 rounded-lg bg-white/5 border border-white/10 text-white text-sm placeholder:text-white/20 focus:outline-none focus:border-white/20 transition-colors"
                  />
                  <div>
                    <p className="text-xs text-white/30 mb-2">Color</p>
                    <div className="flex flex-wrap gap-2">
                      {PRESET_COLORS.map((color) => (
                        <button
                          key={color}
                          onClick={() => setNewCatColor(color)}
                          className={`w-7 h-7 rounded-full transition-all ${newCatColor === color
                              ? "ring-2 ring-white ring-offset-2 ring-offset-[#0a0a0a] scale-110"
                              : "hover:scale-110"
                            }`}
                          style={{ backgroundColor: color }}
                        />
                      ))}
                    </div>
                  </div>
                  <button
                    onClick={handleAddCategory}
                    className="w-full px-4 py-2 rounded-lg bg-white/10 hover:bg-white/15 text-white text-sm font-medium transition-colors border border-white/10"
                  >
                    Add category
                  </button>
                  {catError && (
                    <p className="text-red-400 text-xs">{catError}</p>
                  )}
                </div>
              </div>

              {/* Category list */}
              <div className="px-4 pb-4">
                <div className="space-y-1 mt-3">
                  {categories.map((cat) => {
                    const feedCount = feeds.filter(
                      (f) => f.category === cat.slug
                    ).length;
                    return (
                      <div
                        key={cat.slug}
                        className="group/item flex items-center gap-3 px-3 py-2.5 rounded-lg hover:bg-white/5 transition-colors"
                      >
                        <div
                          className="w-3 h-3 rounded-full shrink-0"
                          style={{ backgroundColor: cat.color }}
                        />
                        <div className="flex-1 min-w-0">
                          <p className="text-sm text-white/80">{cat.label}</p>
                          <p className="text-xs text-white/20">
                            {cat.slug} · {feedCount} feed{feedCount !== 1 ? "s" : ""}
                          </p>
                        </div>
                        <button
                          onClick={() => handleRemoveCategory(cat.slug)}
                          className="shrink-0 opacity-0 group-hover/item:opacity-100 text-white/30 hover:text-red-400 transition-all p-1 rounded hover:bg-white/5"
                          title="Remove category and its feeds"
                        >
                          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                            <polyline points="3,6 5,6 21,6" />
                            <path d="M19,6v14a2,2,0,0,1-2,2H7a2,2,0,0,1-2-2V6m3,0V4a2,2,0,0,1,2-2h4a2,2,0,0,1,2,2v2" />
                          </svg>
                        </button>
                      </div>
                    );
                  })}
                </div>
              </div>
            </div>
          )}
        </div>

        {/* Footer */}
        <div className="px-6 py-3 border-t border-white/5 text-xs text-white/20">
          {feeds.length} feeds across {categories.length} categories
        </div>
      </div>
    </>
  );
}
