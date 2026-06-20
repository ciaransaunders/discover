import { useReadState } from "./ReadStateProvider";
import { useFeedConfig } from "./FeedConfigProvider";
import CategoryTabs from "./CategoryTabs";
import { ArrowsClockwise, Gear, Check, Newspaper } from "@phosphor-icons/react";
import { motion } from "framer-motion";

interface HeaderProps {
  activeCategory: string | null;
  onCategoryChange: (category: string | null) => void;
  loading: boolean;
  cacheAge: number;
  onRefetch: () => Promise<void>;
  onOpenFeedManager: () => void;
  filteredCount: number;
  articleIds: string[];
}

function formatCacheAge(timestamp: number): string {
  const diff = Date.now() - timestamp;
  const mins = Math.floor(diff / 60000);
  if (mins < 1) return "just now";
  if (mins < 60) return `${mins}m ago`;
  const hours = Math.floor(mins / 60);
  if (hours < 24) return `${hours}h ago`;
  return `${Math.floor(hours / 24)}d ago`;
}

export default function Header({
  activeCategory,
  onCategoryChange,
  loading,
  cacheAge,
  onRefetch,
  onOpenFeedManager,
  filteredCount,
  articleIds,
}: HeaderProps) {
  const { markAllAsRead } = useReadState();
  const { categories } = useFeedConfig();

  return (
    <header className="sticky top-0 z-50 glass-header">
      <div className="max-w-[1400px] mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex items-center justify-between py-6">
          <div className="flex items-center gap-3">
            <div className="p-2 rounded-xl bg-white/5 border border-white/10">
              <Newspaper size={24} weight="duotone" className="text-white" />
            </div>
            <h1 className="text-2xl font-sans font-bold text-white tracking-tighter">
              Discover
            </h1>
          </div>

          <div className="flex items-center gap-6">
            <div className="hidden md:flex items-center gap-2 px-4 py-2 rounded-full bg-white/5 border border-white/5 text-[11px] font-medium text-white/30 tabular-nums">
              <span className={`w-1.5 h-1.5 rounded-full ${loading ? 'bg-amber-400 animate-pulse' : 'bg-emerald-400'}`} />
              Updated {formatCacheAge(cacheAge)}
            </div>

            <div className="flex items-center gap-2">
              <motion.button
                whileHover={{ scale: 1.05 }}
                whileTap={{ scale: 0.95 }}
                onClick={onRefetch}
                disabled={loading}
                className="p-2.5 rounded-xl bg-white/5 border border-white/10 text-white/40 hover:text-white hover:bg-white/10 disabled:opacity-20 transition-all"
                title="Refresh feeds"
              >
                <ArrowsClockwise 
                  size={18} 
                  weight="bold" 
                  className={loading ? "animate-spin" : ""} 
                />
              </motion.button>

              {filteredCount > 0 && (
                <motion.button
                  whileHover={{ scale: 1.05 }}
                  whileTap={{ scale: 0.95 }}
                  onClick={() => markAllAsRead(articleIds)}
                  className="hidden sm:flex items-center gap-2 px-4 py-2.5 rounded-xl bg-white/5 border border-white/10 text-xs font-bold text-white/40 hover:text-white hover:bg-white/10 transition-all"
                >
                  <Check size={14} weight="bold" />
                  Mark Read
                </motion.button>
              )}

              <div className="w-px h-6 bg-white/10 mx-1" />

              <motion.button
                whileHover={{ scale: 1.05 }}
                whileTap={{ scale: 0.95 }}
                onClick={onOpenFeedManager}
                className="p-2.5 rounded-xl bg-white/5 border border-white/10 text-white/40 hover:text-white hover:bg-white/10 transition-all"
                title="Manage feeds"
              >
                <Gear size={18} weight="bold" />
              </motion.button>
            </div>
          </div>
        </div>
        
        <div className="pb-4">
          <CategoryTabs
            activeCategory={activeCategory}
            onCategoryChange={onCategoryChange}
            categories={categories}
          />
        </div>
      </div>
    </header>
  );
}
