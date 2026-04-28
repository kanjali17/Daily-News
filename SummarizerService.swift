import Foundation

// MARK: - Summary Result

struct StorySummary {
    let headline: String
    let summary: String
    let whyItMatters: String
}

// MARK: - SummarizerService

actor SummarizerService {
    static let shared = SummarizerService()

    private let endpoint = "https://api.anthropic.com/v1/messages"
    private var apiKey: String {
        // Read from Keychain in production; for now reads from UserDefaults
        UserDefaults.standard.string(forKey: "anthropicAPIKey") ?? ""
    }

    var isEnabled: Bool {
        !apiKey.isEmpty && UserDefaults.standard.bool(forKey: "aiSummarizationEnabled")
    }

    // MARK: - Summarize a single RSS item

    func summarize(_ item: RSSItem) async -> StorySummary? {
        guard isEnabled else { return nil }

        let prompt = """
        Summarize this news story in a neutral, factual tone. Return ONLY valid JSON with no preamble or markdown.

        Story title: \(item.title)
        Story content: \(item.description)

        Return exactly this JSON structure:
        {
          "headline": "A clear, concise headline under 15 words",
          "summary": "1-2 sentences explaining what happened, completely neutral",
          "whyItMatters": "One sentence explaining the significance"
        }
        """

        guard let url = URL(string: endpoint) else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": "claude-sonnet-4-20250514",
            "max_tokens": 256,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, _) = try await URLSession.shared.data(for: request)

            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let content = json["content"] as? [[String: Any]],
               let firstBlock = content.first,
               let text = firstBlock["text"] as? String,
               let summaryData = text.data(using: .utf8),
               let parsed = try JSONSerialization.jsonObject(with: summaryData) as? [String: String] {
                return StorySummary(
                    headline: parsed["headline"] ?? item.title,
                    summary: parsed["summary"] ?? item.description,
                    whyItMatters: parsed["whyItMatters"] ?? "Relevant to current events."
                )
            }
        } catch {
            print("Summarizer error: \(error.localizedDescription)")
        }
        return nil
    }

    // MARK: - Batch summarize with concurrency limit

    func summarizeBatch(_ items: [RSSItem]) async -> [String: StorySummary] {
        guard isEnabled else { return [:] }
        var results: [String: StorySummary] = [:]

        // Process 3 at a time to respect rate limits
        let chunks = stride(from: 0, to: items.count, by: 3).map {
            Array(items[$0..<min($0 + 3, items.count)])
        }

        for chunk in chunks {
            await withTaskGroup(of: (String, StorySummary?).self) { group in
                for item in chunk {
                    group.addTask {
                        let summary = await self.summarize(item)
                        return (item.link, summary)
                    }
                }
                for await (key, summary) in group {
                    if let s = summary { results[key] = s }
                }
            }
            // Small delay between chunks
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
        return results
    }

    // MARK: - Generate learning blurbs

    func generateLearnBlurbs(forCategories categories: [String]) async -> [LearnBlurbData] {
        guard isEnabled else { return LearnBlurbData.defaults }

        let prompt = """
        Generate 5 short, beginner-friendly educational blurbs about topics in these categories: \(categories.joined(separator: ", ")).

        Focus on concepts like: IPOs, AI agents, venture capital, the Federal Reserve, tech layoffs, healthcare data privacy, startup funding rounds, market cap, LLMs, etc.

        Return ONLY valid JSON array, no markdown:
        [
          {
            "question": "What is X?",
            "answer": "2-3 sentence beginner explanation",
            "category": "finance",
            "emoji": "📈"
          }
        ]
        """

        guard let url = URL(string: endpoint) else { return LearnBlurbData.defaults }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": "claude-sonnet-4-20250514",
            "max_tokens": 1000,
            "messages": [["role": "user", "content": prompt]]
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, _) = try await URLSession.shared.data(for: request)

            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let content = json["content"] as? [[String: Any]],
               let text = content.first?["text"] as? String {

                let clean = text
                    .replacingOccurrences(of: "```json", with: "")
                    .replacingOccurrences(of: "```", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                if let arrayData = clean.data(using: .utf8),
                   let parsed = try JSONSerialization.jsonObject(with: arrayData) as? [[String: String]] {
                    return parsed.compactMap { dict in
                        guard let q = dict["question"], let a = dict["answer"],
                              let cat = dict["category"], let emoji = dict["emoji"] else { return nil }
                        return LearnBlurbData(question: q, answer: a, category: cat, emoji: emoji)
                    }
                }
            }
        } catch {
            print("Learn blurb generation error: \(error)")
        }
        return LearnBlurbData.defaults
    }
}

// MARK: - Learn Blurb Data Transfer

struct LearnBlurbData {
    let question: String
    let answer: String
    let category: String
    let emoji: String

    static let defaults: [LearnBlurbData] = [
        LearnBlurbData(
            question: "What is an IPO?",
            answer: "An Initial Public Offering is when a private company sells shares to the public on a stock exchange for the first time. It lets early investors cash out and raises capital for growth — but also means quarterly scrutiny from public shareholders.",
            category: "finance", emoji: "📈"
        ),
        LearnBlurbData(
            question: "How do AI agents work?",
            answer: "AI agents use large language models to take actions autonomously — like browsing the web, writing code, or managing files. They work by breaking a goal into steps, executing tools at each step, and adjusting based on results.",
            category: "ai", emoji: "🤖"
        ),
        LearnBlurbData(
            question: "What is venture capital?",
            answer: "Venture capital is private equity funding given to early-stage startups with high growth potential. VCs receive equity in return. Most investments fail, but the few that succeed return the whole fund many times over.",
            category: "finance", emoji: "💸"
        ),
        LearnBlurbData(
            question: "What does the Federal Reserve do?",
            answer: "The Fed is the US central bank. It controls inflation and employment by setting the federal funds rate. When rates go up, borrowing gets more expensive, which cools spending and brings inflation down.",
            category: "finance", emoji: "🏦"
        ),
        LearnBlurbData(
            question: "What causes tech layoffs?",
            answer: "Tech layoffs usually happen when companies over-hired during growth periods, interest rates rise (making investor capital expensive), or revenue projections miss. In 2022–23 many companies hired aggressively during the pandemic then cut staff when growth slowed.",
            category: "layoffs", emoji: "📉"
        ),
        LearnBlurbData(
            question: "How does healthcare data privacy work?",
            answer: "HIPAA (Health Insurance Portability and Accountability Act) governs US healthcare data. It requires hospitals and insurers to protect your medical records, get your consent before sharing them, and notify you if there's a breach.",
            category: "health", emoji: "🏥"
        ),
    ]
}
