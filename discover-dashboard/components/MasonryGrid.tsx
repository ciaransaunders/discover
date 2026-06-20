import { Article } from "@/lib/types";
import ArticleCard from "./ArticleCard";
import { AnimatePresence } from "framer-motion";

interface MasonryGridProps {
  articles: Article[];
}

export default function MasonryGrid({ articles }: MasonryGridProps) {
  if (articles.length === 0) {
    return (
      <div className="glass-medium rounded-[2.5rem] p-24 text-center border border-white/5 shadow-glass">
        <p className="text-white/40 text-xl font-sans font-medium">No articles found.</p>
        <p className="text-white/20 text-sm mt-3 font-sans">
          Try selecting a different category or refresh the page.
        </p>
      </div>
    );
  }

  return (
    <div className="columns-1 sm:columns-2 lg:columns-3 xl:columns-4 gap-8">
      <AnimatePresence mode="popLayout">
        {articles.map((article, i) => (
          <ArticleCard key={article.id} article={article} index={i} />
        ))}
      </AnimatePresence>
    </div>
  );
}
