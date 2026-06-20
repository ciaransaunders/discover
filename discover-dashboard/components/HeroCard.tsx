import { Article } from "@/lib/types";
import { useReadState } from "./ReadStateProvider";
import { useFeedConfig } from "./FeedConfigProvider";
import { motion } from "framer-motion";
import { Clock, ArrowUpRight } from "@phosphor-icons/react";

interface HeroCardProps {
  article: Article;
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
  const weeks = Math.floor(days / 7);
  if (weeks >= 1) return `${weeks}w ago`;
  return `${days}d ago`;
}

function getDomain(url: string): string {
  try {
    return new URL(url).hostname;
  } catch {
    return "";
  }
}

export default function HeroCard({ article }: HeroCardProps) {
  const { isRead, markAsRead } = useReadState();
  const { categories } = useFeedConfig();
  const read = isRead(article.id);
  const category = categories.find((c) => c.slug === article.category);
  const domain = getDomain(article.link);

  const handleClick = () => {
    markAsRead(article.id);
    window.open(article.link, "_blank", "noopener,noreferrer");
  };

  return (
    <motion.button
      layout
      onClick={handleClick}
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: read ? 0.6 : 1, y: 0 }}
      whileHover={{ scale: 0.995 }}
      whileTap={{ scale: 0.985 }}
      transition={{ type: "spring", stiffness: 200, damping: 25 }}
      className="group relative w-full text-left glass-thick rounded-[2.5rem] overflow-hidden shadow-glass-lg border border-white/5"
    >
      <div className="flex flex-col lg:flex-row min-h-[400px]">
        {/* Content Side */}
        <div className="flex-1 p-8 lg:p-12 flex flex-col justify-between z-10">
          <div>
            {category && (
              <div className="flex items-center gap-2 mb-6">
                <span
                  className="w-2 h-2 rounded-full animate-pulse"
                  style={{ backgroundColor: category.color }}
                />
                <span
                  className="text-[11px] font-bold uppercase tracking-[0.2em]"
                  style={{ color: category.color }}
                >
                  {category.label}
                </span>
              </div>
            )}
            <h2 className="text-4xl md:text-5xl lg:text-6xl font-sans font-bold leading-[0.95] tracking-tighter text-white mb-6 group-hover:text-white/90 transition-colors">
              {article.title}
            </h2>
            {article.snippet && (
              <p className="text-lg text-white/50 leading-relaxed font-sans max-w-[45ch] line-clamp-3 mb-8">
                {article.snippet}
              </p>
            )}
          </div>

          <div className="flex items-center justify-between mt-auto">
            <div className="flex items-center gap-4 text-white/30 text-sm">
              <div className="flex items-center gap-1.5">
                {domain && (
                  <img
                    src={`https://www.google.com/s2/favicons?domain=${domain}&sz=32`}
                    alt=""
                    className="w-5 h-5 rounded-full grayscale opacity-50"
                  />
                )}
                <span className="font-medium text-white/40">{article.source}</span>
              </div>
              <span className="w-1 h-1 rounded-full bg-white/10" />
              <div className="flex items-center gap-1.5">
                <Clock size={16} weight="bold" />
                <span>{timeAgo(article.publishedAt)}</span>
              </div>
            </div>
            
            <div className="p-3 rounded-full border border-white/10 bg-white/5 opacity-0 group-hover:opacity-100 transform translate-x-4 group-hover:translate-x-0 transition-all duration-300">
              <ArrowUpRight size={20} weight="bold" className="text-white" />
            </div>
          </div>
        </div>

        {/* Media Side (Asymmetric Split) */}
        {article.thumbnail && (
          <div className="relative lg:w-[45%] aspect-video lg:aspect-auto overflow-hidden border-l border-white/5">
            <img
              src={article.thumbnail}
              alt=""
              className="w-full h-full object-cover grayscale-[0.2] transition-all duration-700 group-hover:scale-105 group-hover:grayscale-0"
              loading="eager"
            />
            <div className="absolute inset-0 bg-gradient-to-r from-black/60 to-transparent lg:block hidden" />
            <div className="absolute inset-0 bg-gradient-to-t from-black/60 to-transparent lg:hidden" />
            
            {/* Gloss Overlay */}
            <div className="absolute inset-0 opacity-0 group-hover:opacity-20 bg-gradient-to-br from-white via-transparent to-transparent transition-opacity duration-500" />
          </div>
        )}
      </div>

      {/* Edge Highlight */}
      <div className="absolute inset-0 border border-white/10 rounded-[2.5rem] pointer-events-none" />
    </motion.button>
  );
}
