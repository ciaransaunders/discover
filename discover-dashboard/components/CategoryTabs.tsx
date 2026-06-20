import { CategoryConfig } from "@/lib/types";
import { motion } from "framer-motion";

interface CategoryTabsProps {
  activeCategory: string | null;
  onCategoryChange: (slug: string | null) => void;
  categories: CategoryConfig[];
}

export default function CategoryTabs({
  activeCategory,
  onCategoryChange,
  categories,
}: CategoryTabsProps) {
  return (
    <div className="relative">
      <div className="flex gap-3 overflow-x-auto pb-4 scrollbar-hide px-1">
        <motion.button
          whileHover={{ scale: 1.02 }}
          whileTap={{ scale: 0.98 }}
          onClick={() => onCategoryChange(null)}
          className={`shrink-0 px-6 py-2.5 rounded-2xl text-[13px] font-sans font-bold tracking-tight transition-all duration-300 border ${activeCategory === null
              ? "bg-white/10 text-white border-white/20 shadow-glass-sm"
              : "text-white/30 border-transparent hover:text-white/60 hover:bg-white/5"
            }`}
        >
          All Stories
        </motion.button>
        {categories.map((cat) => (
          <motion.button
            key={cat.slug}
            whileHover={{ scale: 1.02 }}
            whileTap={{ scale: 0.98 }}
            onClick={() => onCategoryChange(cat.slug)}
            className={`shrink-0 px-6 py-2.5 rounded-2xl text-[13px] font-sans font-bold tracking-tight transition-all duration-300 flex items-center gap-2 border ${activeCategory === cat.slug
                ? "bg-white/10 text-white border-white/20 shadow-glass-sm"
                : "text-white/30 border-transparent hover:text-white/60 hover:bg-white/5"
              }`}
          >
            {/* Category colour dot */}
            <span
              className={`w-1.5 h-1.5 rounded-full shrink-0 ${activeCategory === cat.slug ? 'animate-pulse' : 'opacity-40'}`}
              style={{ backgroundColor: cat.color }}
            />
            {cat.label}
          </motion.button>
        ))}
      </div>
    </div>
  );
}
