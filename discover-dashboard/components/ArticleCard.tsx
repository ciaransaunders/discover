import { Article } from "@/lib/types";
import { useReadState } from "./ReadStateProvider";
import { useFeedConfig } from "./FeedConfigProvider";
import { motion, AnimatePresence } from "framer-motion";
import { ArrowUpRight } from "@phosphor-icons/react";
import { useEffect, useState } from "react";

interface ArticleCardProps {
  article: Article;
  index?: number;
}

function timeAgo(dateStr: string): string {
  const now = Date.now();
  const then = new Date(dateStr).getTime();
  const diff = now - then;
  const mins = Math.floor(diff / 60000);
  if (mins < 1) return "just now";
  if (mins < 60) return `${mins}m ago`;
  const hours = Math.floor(mins / 60);
  if (hours < 24) return `${hours}h ago`;
  const days = Math.floor(hours / 24);
  return `${days}d ago`;
}

function getDomain(url: string): string {
  try {
    return new URL(url).hostname;
  } catch {
    return "";
  }
}

export default function ArticleCard({ article, index = 0 }: ArticleCardProps) {
  const { isRead, markAsRead } = useReadState();
  const { categories } = useFeedConfig();
  const read = isRead(article.id);
  const category = categories.find((c) => c.slug === article.category);
  const domain = getDomain(article.link);

  // Alive Switch Mechanic: Trigger a subtle "ping" when the card is refreshed or at random intervals
  const [pulse, setPulse] = useState(false);
  useEffect(() => {
    const timer = setInterval(() => {
      if (Math.random() > 0.8) {
        setPulse(true);
        setTimeout(() => setPulse(false), 2000);
      }
    }, 15000);
    return () => clearInterval(timer);
  }, []);

  const handleClick = () => {
    markAsRead(article.id);
    window.open(article.link, "_blank", "noopener,noreferrer");
  };

  return (
    <motion.div
      layout
      initial={{ opacity: 0, y: 10 }}
      animate={{ opacity: read ? 0.5 : 1, y: 0 }}
      exit={{ opacity: 0, scale: 0.95 }}
      transition={{ 
        delay: Math.min(index * 0.02, 0.4),
        type: "spring",
        stiffness: 260,
        damping: 20 
      }}
      className="break-inside-avoid inline-block w-full mb-6"
    >
      <motion.button
        onClick={handleClick}
        whileHover={{ y: -4, scale: 1.01 }}
        whileTap={{ scale: 0.98 }}
        className="group relative w-full text-left glass-medium rounded-[2rem] overflow-hidden shadow-glass border border-white/5 transition-colors hover:bg-white/[0.04]"
      >
        {/* Alive Ping Effect */}
        <AnimatePresence>
          {pulse && (
            <motion.div
              initial={{ opacity: 0, scale: 0.8 }}
              animate={{ opacity: 0.15, scale: 1.2 }}
              exit={{ opacity: 0, scale: 1.5 }}
              className="absolute inset-0 bg-white pointer-events-none z-20"
            />
          )}
        </AnimatePresence>

        {article.thumbnail && (
          <div className="relative w-full aspect-[16/10] overflow-hidden">
            <img
              src={article.thumbnail}
              alt=""
              className="w-full h-full object-cover grayscale-[0.3] transition-all duration-700 group-hover:scale-105 group-hover:grayscale-0"
              loading="lazy"
            />
            <div className="absolute inset-0 bg-gradient-to-t from-black/40 to-transparent" />
          </div>
        )}

        <div className="p-6">
          <div className="flex items-center justify-between mb-3 text-[10px] font-bold uppercase tracking-[0.15em]">
            {category && (
              <span style={{ color: category.color }}>{category.label}</span>
            )}
            <span className="text-white/20">{timeAgo(article.publishedAt)}</span>
          </div>

          <h3 className="text-lg font-sans font-semibold leading-tight text-white mb-3 group-hover:text-white transition-colors line-clamp-3 tracking-tight">
            {article.title}
          </h3>

          {article.snippet && (
            <p className="text-sm font-sans text-white/40 leading-relaxed line-clamp-2 mb-4">
              {article.snippet}
            </p>
          )}

          <div className="flex items-center justify-between mt-4">
            <div className="flex items-center gap-2 text-xs text-white/30">
              {domain && (
                <img
                  src={`https://www.google.com/s2/favicons?domain=${domain}&sz=32`}
                  alt=""
                  className="w-4 h-4 rounded-full grayscale opacity-40"
                />
              )}
              <span className="font-medium text-white/40">{article.source}</span>
            </div>
            
            <div className="opacity-0 group-hover:opacity-100 transition-opacity duration-300">
              <ArrowUpRight size={16} weight="bold" className="text-white/40" />
            </div>
          </div>
        </div>

        {/* Refraction edge */}
        <div className="absolute inset-0 border border-white/10 rounded-[2rem] pointer-events-none" />
      </motion.button>
    </motion.div>
  );
}
