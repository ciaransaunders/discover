import { FeedConfig, CategoryConfig } from "./types";

export const categories: CategoryConfig[] = [
  { slug: "general", label: "General", color: "#9ca3af" },
  { slug: "ai", label: "AI / ML", color: "#8b5cf6" },
  { slug: "tech", label: "Tech", color: "#3b82f6" },
  { slug: "gaming", label: "Gaming", color: "#ef4444" },
  { slug: "film", label: "Film", color: "#f59e0b" },
  { slug: "chelsea", label: "Chelsea FC", color: "#0347fc" },
  { slug: "uk", label: "UK News", color: "#10b981" },
  { slug: "science", label: "Science", color: "#06b6d4" },
  { slug: "finance", label: "Finance", color: "#22d3ee" },
  { slug: "business", label: "Business", color: "#facc15" },
  { slug: "lego", label: "Lego", color: "#f97316" },
  { slug: "legal", label: "Legal Tech", color: "#a78bfa" },
  { slug: "adhd", label: "ADHD Research", color: "#ec4899" },
];

export const feeds: FeedConfig[] = [
  // AI / LLMs / ML
  {
    name: "The Verge AI",
    url: "https://www.theverge.com/rss/ai-artificial-intelligence/index.xml",
    category: "ai",
  },
  {
    name: "Ars Technica AI",
    url: "https://feeds.arstechnica.com/arstechnica/technology-lab",
    category: "ai",
  },
  {
    name: "MIT Tech Review",
    url: "https://www.technologyreview.com/feed/",
    category: "ai",
  },
  {
    name: "MarkTechPost",
    url: "https://marktechpost.com/feed",
    category: "ai",
  },
  {
    name: "Simon Willison's Weblog",
    url: "https://simonwillison.net/atom/everything/",
    category: "ai",
  },
  {
    name: "Interconnects",
    url: "https://www.interconnects.ai/feed",
    category: "ai",
  },
  {
    name: "One Useful Thing",
    url: "https://www.oneusefulthing.org/feed",
    category: "ai",
  },
  {
    name: "The Gradient",
    url: "https://thegradient.pub/rss/",
    category: "ai",
  },
  {
    name: "AI Snake Oil",
    url: "https://www.aisnakeoil.com/feed",
    category: "ai",
  },
  {
    name: "MIT Tech Review AI",
    url: "https://www.technologyreview.com/topic/artificial-intelligence/feed/",
    category: "ai",
  },
  {
    name: "VentureBeat AI",
    url: "https://venturebeat.com/category/ai/feed/",
    category: "ai",
  },

  // Tech Industry
  {
    name: "TechCrunch",
    url: "https://techcrunch.com/feed/",
    category: "tech",
  },
  {
    name: "The Verge",
    url: "https://www.theverge.com/rss/index.xml",
    category: "tech",
  },
  {
    name: "Ars Technica",
    url: "https://feeds.arstechnica.com/arstechnica/index",
    category: "tech",
  },
  {
    name: "Wired",
    url: "https://www.wired.com/feed/rss",
    category: "tech",
  },
  {
    name: "Stratechery",
    url: "https://stratechery.com/feed/",
    category: "tech",
  },
  {
    name: "Sifted",
    url: "https://sifted.eu/feed",
    category: "tech",
  },
  {
    name: "Benedict Evans",
    url: "https://www.ben-evans.com/benedictevans?format=RSS",
    category: "tech",
  },
  {
    name: "The Register",
    url: "https://theregister.com/headlines.atom",
    category: "tech",
  },

  // Gaming
  {
    name: "IGN",
    url: "https://feeds.feedburner.com/ign/all",
    category: "gaming",
  },
  {
    name: "Eurogamer",
    url: "https://www.eurogamer.net/feed",
    category: "gaming",
  },
  {
    name: "Rock Paper Shotgun",
    url: "https://www.rockpapershotgun.com/feed",
    category: "gaming",
  },
  {
    name: "GamesIndustry.biz",
    url: "https://www.gamesindustry.biz/feed",
    category: "gaming",
  },
  {
    name: "Polygon",
    url: "https://www.polygon.com/rss/index.xml",
    category: "gaming",
  },
  {
    name: "PC Gamer",
    url: "https://www.pcgamer.com/rss",
    category: "gaming",
  },

  // Filmmaking / Cinema
  {
    name: "IndieWire",
    url: "https://www.indiewire.com/feed/",
    category: "film",
  },
  {
    name: "No Film School",
    url: "https://nofilmschool.com/rss.xml",
    category: "film",
  },
  {
    name: "Screen Rant",
    url: "https://screenrant.com/feed/",
    category: "film",
  },
  {
    name: "CineD",
    url: "https://www.cined.com/feed/",
    category: "film",
  },
  {
    name: "Film Riot",
    url: "https://www.youtube.com/feeds/videos.xml?channel_id=UC6P24bhhCmMPOcujA9PKPTA",
    category: "film",
  },
  {
    name: "Gerald Undone",
    url: "https://www.youtube.com/feeds/videos.xml?channel_id=UC09qASY4ixFS-KXIH6Nw0rg",
    category: "film",
  },

  // Chelsea FC
  {
    name: "Football London Chelsea",
    url: "https://www.football.london/chelsea-fc/?service=rss",
    category: "chelsea",
    useOgImage: true,
  },
  {
    name: "BBC Sport Chelsea",
    url: "https://feeds.bbci.co.uk/sport/football/teams/chelsea/rss.xml",
    category: "chelsea",
    useOgImage: true,
  },
  {
    name: "We Ain't Got No History",
    url: "https://weaintgotnohistory.sbnation.com/rss/index.xml",
    category: "chelsea",
  },

  // UK Politics / Current Affairs
  {
    name: "BBC News UK",
    url: "https://feeds.bbci.co.uk/news/uk/rss.xml",
    category: "uk",
    useOgImage: true,
  },
  {
    name: "The Guardian UK",
    url: "https://www.theguardian.com/uk-news/rss",
    category: "uk",
  },
  {
    name: "Sky News UK",
    url: "https://feeds.skynews.com/feeds/rss/uk.xml",
    category: "uk",
    useOgImage: true,
  },

  // Science / Space
  {
    name: "NASA",
    url: "https://www.nasa.gov/rss/dyn/breaking_news.rss",
    category: "science",
  },
  {
    name: "New Scientist",
    url: "https://www.newscientist.com/feed/home/",
    category: "science",
  },
  {
    name: "Ars Technica Science",
    url: "https://feeds.arstechnica.com/arstechnica/science",
    category: "science",
  },

  // Finance / Markets / Crypto
  {
    name: "CoinDesk",
    url: "https://www.coindesk.com/arc/outboundfeeds/rss/",
    category: "finance",
  },

  // Business / Markets
  {
    name: "Business Insider",
    url: "https://feeds.businessinsider.com/custom/all",
    category: "business",
  },

  // Lego / Hobbies
  {
    name: "The Brothers Brick",
    url: "https://www.brothers-brick.com/feed/",
    category: "lego",
  },
  {
    name: "Brickset",
    url: "https://brickset.com/feed",
    category: "lego",
  },
  {
    name: "BrickFanatics",
    url: "https://www.brickfanatics.com/feed/",
    category: "lego",
  },

  // Legal Tech
  {
    name: "Artificial Lawyer",
    url: "https://www.artificiallawyer.com/feed/",
    category: "legal",
  },
  {
    name: "Legal IT Insider",
    url: "https://legaltechnology.com/feed/",
    category: "legal",
  },
  {
    name: "Law.com Legal Tech",
    url: "https://feeds.feedblitz.com/americanlawyer/legaltechnews",
    category: "legal",
  },

  // ADHD Research
  {
    name: "ADDitude Magazine",
    url: "https://www.additudemag.com/feed/",
    category: "adhd",
  },
  {
    name: "Neuroscience News",
    url: "https://neurosciencenews.com/feed/",
    category: "adhd",
  },
  {
    name: "PsyPost",
    url: "https://www.psypost.org/feed/",
    category: "adhd",
  },
];
