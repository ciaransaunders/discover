import Foundation

/// Compile-time seed data ported directly from `lib/feeds.ts` in the web dashboard.
///
/// These values are written to SwiftData on first launch by `ContentView.seedDefaults()`.
/// They serve as the canonical starting point; users can customise via the Feed Manager.
enum DefaultFeeds {

    // MARK: - Value types

    struct CategorySeed: Sendable {
        let slug: String
        let label: String
        let color: String  // Hex string, e.g. "#8b5cf6"
    }

    struct FeedSeed: Sendable {
        let name: String
        let url: String
        let category: String
        let useOgImage: Bool

        init(name: String, url: String, category: String, useOgImage: Bool = false) {
            self.name = name
            self.url = url
            self.category = category
            self.useOgImage = useOgImage
        }
    }

    // MARK: - Categories (13 total, matching web app + General)

    static let categories: [CategorySeed] = [
        CategorySeed(slug: "general",  label: "General",         color: "#9ca3af"),
        CategorySeed(slug: "ai",       label: "AI / ML",        color: "#8b5cf6"),
        CategorySeed(slug: "tech",     label: "Tech",            color: "#3b82f6"),
        CategorySeed(slug: "gaming",   label: "Gaming",          color: "#ef4444"),
        CategorySeed(slug: "film",     label: "Film",            color: "#f59e0b"),
        CategorySeed(slug: "chelsea",  label: "Chelsea FC",      color: "#0347fc"),
        CategorySeed(slug: "uk",       label: "UK News",         color: "#10b981"),
        CategorySeed(slug: "science",  label: "Science",         color: "#06b6d4"),
        CategorySeed(slug: "finance",  label: "Finance",         color: "#22d3ee"),
        CategorySeed(slug: "business", label: "Business",        color: "#facc15"),
        CategorySeed(slug: "lego",     label: "Lego",            color: "#f97316"),
        CategorySeed(slug: "legal",    label: "Legal Tech",      color: "#a78bfa"),
        CategorySeed(slug: "adhd",     label: "ADHD Research",   color: "#ec4899"),
    ]

    // MARK: - Feeds (50 total, matching web app)

    static let feeds: [FeedSeed] = [

        // AI / ML
        FeedSeed(name: "The Verge AI",
                 url: "https://www.theverge.com/rss/ai-artificial-intelligence/index.xml",
                 category: "ai"),
        FeedSeed(name: "Ars Technica AI",
                 url: "https://feeds.arstechnica.com/arstechnica/technology-lab",
                 category: "ai"),
        FeedSeed(name: "MIT Tech Review",
                 url: "https://www.technologyreview.com/feed/",
                 category: "ai"),
        FeedSeed(name: "MarkTechPost",
                 url: "https://marktechpost.com/feed",
                 category: "ai"),
        FeedSeed(name: "Simon Willison's Weblog",
                 url: "https://simonwillison.net/atom/everything/",
                 category: "ai"),
        FeedSeed(name: "Interconnects",
                 url: "https://www.interconnects.ai/feed",
                 category: "ai"),
        FeedSeed(name: "One Useful Thing",
                 url: "https://www.oneusefulthing.org/feed",
                 category: "ai"),
        FeedSeed(name: "The Gradient",
                 url: "https://thegradient.pub/rss/",
                 category: "ai"),
        FeedSeed(name: "AI Snake Oil",
                 url: "https://www.aisnakeoil.com/feed",
                 category: "ai"),
        FeedSeed(name: "MIT Tech Review AI",
                 url: "https://www.technologyreview.com/topic/artificial-intelligence/feed/",
                 category: "ai"),
        FeedSeed(name: "VentureBeat AI",
                 url: "https://venturebeat.com/category/ai/feed/",
                 category: "ai"),

        // Tech Industry
        FeedSeed(name: "TechCrunch",
                 url: "https://techcrunch.com/feed/",
                 category: "tech"),
        FeedSeed(name: "The Verge",
                 url: "https://www.theverge.com/rss/index.xml",
                 category: "tech"),
        FeedSeed(name: "Ars Technica",
                 url: "https://feeds.arstechnica.com/arstechnica/index",
                 category: "tech"),
        FeedSeed(name: "Wired",
                 url: "https://www.wired.com/feed/rss",
                 category: "tech"),
        FeedSeed(name: "Stratechery",
                 url: "https://stratechery.com/feed/",
                 category: "tech"),
        FeedSeed(name: "Sifted",
                 url: "https://sifted.eu/feed",
                 category: "tech"),
        FeedSeed(name: "Benedict Evans",
                 url: "https://www.ben-evans.com/benedictevans?format=RSS",
                 category: "tech"),
        FeedSeed(name: "The Register",
                 url: "https://theregister.com/headlines.atom",
                 category: "tech"),

        // Gaming
        FeedSeed(name: "IGN",
                 url: "https://feeds.feedburner.com/ign/all",
                 category: "gaming"),
        FeedSeed(name: "Eurogamer",
                 url: "https://www.eurogamer.net/feed",
                 category: "gaming"),
        FeedSeed(name: "Rock Paper Shotgun",
                 url: "https://www.rockpapershotgun.com/feed",
                 category: "gaming"),
        FeedSeed(name: "GamesIndustry.biz",
                 url: "https://www.gamesindustry.biz/feed",
                 category: "gaming"),
        FeedSeed(name: "Polygon",
                 url: "https://www.polygon.com/rss/index.xml",
                 category: "gaming"),
        FeedSeed(name: "PC Gamer",
                 url: "https://www.pcgamer.com/rss",
                 category: "gaming"),

        // Film
        FeedSeed(name: "IndieWire",
                 url: "https://www.indiewire.com/feed/",
                 category: "film"),
        FeedSeed(name: "No Film School",
                 url: "https://nofilmschool.com/rss.xml",
                 category: "film"),
        FeedSeed(name: "Screen Rant",
                 url: "https://screenrant.com/feed/",
                 category: "film"),
        FeedSeed(name: "CineD",
                 url: "https://www.cined.com/feed/",
                 category: "film"),
        FeedSeed(name: "Film Riot",
                 url: "https://www.youtube.com/feeds/videos.xml?channel_id=UC6P24bhhCmMPOcujA9PKPTA",
                 category: "film"),
        FeedSeed(name: "Gerald Undone",
                 url: "https://www.youtube.com/feeds/videos.xml?channel_id=UC09qASY4ixFS-KXIH6Nw0rg",
                 category: "film"),

        // Chelsea FC
        FeedSeed(name: "Football London Chelsea",
                 url: "https://www.football.london/chelsea-fc/?service=rss",
                 category: "chelsea",
                 useOgImage: true),
        FeedSeed(name: "BBC Sport Chelsea",
                 url: "https://feeds.bbci.co.uk/sport/football/teams/chelsea/rss.xml",
                 category: "chelsea",
                 useOgImage: true),
        FeedSeed(name: "We Ain't Got No History",
                 url: "https://weaintgotnohistory.sbnation.com/rss/index.xml",
                 category: "chelsea"),

        // UK News
        FeedSeed(name: "BBC News UK",
                 url: "https://feeds.bbci.co.uk/news/uk/rss.xml",
                 category: "uk",
                 useOgImage: true),
        FeedSeed(name: "The Guardian UK",
                 url: "https://www.theguardian.com/uk-news/rss",
                 category: "uk"),
        FeedSeed(name: "Sky News UK",
                 url: "https://feeds.skynews.com/feeds/rss/uk.xml",
                 category: "uk",
                 useOgImage: true),

        // Science
        FeedSeed(name: "NASA",
                 url: "https://www.nasa.gov/rss/dyn/breaking_news.rss",
                 category: "science"),
        FeedSeed(name: "New Scientist",
                 url: "https://www.newscientist.com/feed/home/",
                 category: "science"),
        FeedSeed(name: "Ars Technica Science",
                 url: "https://feeds.arstechnica.com/arstechnica/science",
                 category: "science"),

        // Finance
        FeedSeed(name: "CoinDesk",
                 url: "https://www.coindesk.com/arc/outboundfeeds/rss/",
                 category: "finance"),

        // Business
        FeedSeed(name: "Business Insider",
                 url: "https://feeds.businessinsider.com/custom/all",
                 category: "business"),

        // Lego
        FeedSeed(name: "The Brothers Brick",
                 url: "https://www.brothers-brick.com/feed/",
                 category: "lego"),
        FeedSeed(name: "Brickset",
                 url: "https://brickset.com/feed",
                 category: "lego"),
        FeedSeed(name: "BrickFanatics",
                 url: "https://www.brickfanatics.com/feed/",
                 category: "lego"),

        // Legal Tech
        FeedSeed(name: "Artificial Lawyer",
                 url: "https://www.artificiallawyer.com/feed/",
                 category: "legal"),
        FeedSeed(name: "Legal IT Insider",
                 url: "https://legaltechnology.com/feed/",
                 category: "legal"),
        FeedSeed(name: "Law.com Legal Tech",
                 url: "https://feeds.feedblitz.com/americanlawyer/legaltechnews",
                 category: "legal"),

        // ADHD Research
        FeedSeed(name: "ADDitude Magazine",
                 url: "https://www.additudemag.com/feed/",
                 category: "adhd"),
        FeedSeed(name: "Neuroscience News",
                 url: "https://neurosciencenews.com/feed/",
                 category: "adhd"),
        FeedSeed(name: "PsyPost",
                 url: "https://www.psypost.org/feed/",
                 category: "adhd"),
    ]
}
