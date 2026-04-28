import Foundation

// MARK: - Raw RSS Item

struct RSSItem {
    var title: String
    var description: String
    var link: String
    var pubDate: Date
    var sourceName: String
    var category: String
}

// MARK: - RSS Feed Config

struct RSSFeed {
    let url: String
    let sourceName: String
    let category: String
}

// MARK: - NewsService

actor NewsService: NSObject, XMLParserDelegate {

    static let shared = NewsService()

    // All RSS feeds grouped by category
    private let feeds: [RSSFeed] = [
        // AI & Tech
        RSSFeed(url: "https://feeds.feedburner.com/TechCrunch", sourceName: "TechCrunch", category: "ai"),
        RSSFeed(url: "https://www.theverge.com/rss/index.xml", sourceName: "The Verge", category: "ai"),
        RSSFeed(url: "https://www.technologyreview.com/feed/", sourceName: "MIT Tech Review", category: "ai"),
        RSSFeed(url: "https://venturebeat.com/feed/", sourceName: "VentureBeat", category: "startup"),

        // Finance & Markets
        RSSFeed(url: "https://feeds.reuters.com/reuters/businessNews", sourceName: "Reuters Business", category: "finance"),
        RSSFeed(url: "https://feeds.marketwatch.com/marketwatch/topstories/", sourceName: "MarketWatch", category: "finance"),

        // Politics & World
        RSSFeed(url: "https://feeds.bbci.co.uk/news/world/rss.xml", sourceName: "BBC World", category: "world"),
        RSSFeed(url: "https://apnews.com/rss/apf-topnews", sourceName: "AP News", category: "politics"),

        // Healthcare & Science
        RSSFeed(url: "https://rss.statnews.com/", sourceName: "STAT News", category: "health"),
        RSSFeed(url: "https://feeds.sciencedaily.com/sciencedaily/top_news/top_health", sourceName: "Science Daily", category: "health"),

        // Austin & UT
        RSSFeed(url: "https://www.kut.org/rss.xml", sourceName: "KUT News", category: "austin"),
        RSSFeed(url: "https://news.utexas.edu/feed", sourceName: "UT Austin News", category: "austin"),

        // Tech Layoffs (search-filtered from TechCrunch + The Verge)
        RSSFeed(url: "https://techcrunch.com/tag/layoffs/feed/", sourceName: "TechCrunch Layoffs", category: "layoffs"),
    ]

    // MARK: - Fetch

    func fetchAllStories() async -> [RSSItem] {
        await withTaskGroup(of: [RSSItem].self) { group in
            for feed in feeds {
                group.addTask {
                    await self.fetchFeed(feed)
                }
            }
            var all: [RSSItem] = []
            for await items in group {
                all.append(contentsOf: items)
            }
            // Sort by date, newest first
            return all.sorted { $0.pubDate > $1.pubDate }
        }
    }

    func fetchFeed(_ feed: RSSFeed) async -> [RSSItem] {
        guard let url = URL(string: feed.url) else { return [] }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return parseRSS(data: data, sourceName: feed.sourceName, category: feed.category)
        } catch {
            print("Feed fetch failed [\(feed.sourceName)]: \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - XML Parsing (simple synchronous parser)

    private func parseRSS(data: Data, sourceName: String, category: String) -> [RSSItem] {
        let parser = SimpleRSSParser(data: data, sourceName: sourceName, category: category)
        return parser.parse()
    }
}

// MARK: - Simple RSS XML Parser

private class SimpleRSSParser: NSObject, XMLParserDelegate {
    private let data: Data
    private let sourceName: String
    private let category: String

    private var items: [RSSItem] = []
    private var currentElement = ""
    private var currentTitle = ""
    private var currentDescription = ""
    private var currentLink = ""
    private var currentPubDate = ""
    private var inItem = false
    private var buffer = ""

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        return f
    }()

    init(data: Data, sourceName: String, category: String) {
        self.data = data
        self.sourceName = sourceName
        self.category = category
    }

    func parse() -> [RSSItem] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return Array(items.prefix(8)) // max 8 per feed
    }

    // MARK: XMLParserDelegate

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attributeDict: [String: String] = [:]) {
        currentElement = elementName
        if elementName == "item" || elementName == "entry" {
            inItem = true
            currentTitle = ""
            currentDescription = ""
            currentLink = ""
            currentPubDate = ""
        }
        buffer = ""
        // Atom <link href="...">
        if elementName == "link", let href = attributeDict["href"], inItem {
            currentLink = href
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        buffer += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        let text = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
        if inItem {
            switch elementName {
            case "title":             currentTitle = text
            case "description", "summary", "content:encoded": currentDescription = text
            case "link":             if currentLink.isEmpty { currentLink = text }
            case "pubDate", "published", "updated": currentPubDate = text
            case "item", "entry":
                let date = dateFormatter.date(from: currentPubDate) ?? Date()
                let cleanDesc = currentDescription
                    .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !currentTitle.isEmpty {
                    items.append(RSSItem(
                        title: currentTitle,
                        description: String(cleanDesc.prefix(300)),
                        link: currentLink,
                        pubDate: date,
                        sourceName: sourceName,
                        category: category
                    ))
                }
                inItem = false
            default: break
            }
        }
        buffer = ""
    }
}
