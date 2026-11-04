import Foundation

enum LearningCategory: String, CaseIterable, Identifiable {
    case buses
    case tractors
    case jcbs
    case trucks
    case cars
    case farms
    case villages
    case construction
    case abcd
    case counting
    case days
    case months
    case fruits
    case vegetables

    var id: String { rawValue }

    var title: String {
        switch self {
        case .buses: return "Buses"
        case .tractors: return "Tractors"
        case .jcbs: return "JCBs"
        case .trucks: return "Trucks"
        case .cars: return "Cars"
        case .farms: return "Farms"
        case .villages: return "Villages"
        case .construction: return "Construction"
        case .abcd: return "ABCD / Alphabet"
        case .counting: return "Counting / Numbers"
        case .days: return "Days of the Week"
        case .months: return "Months"
        case .fruits: return "Fruits"
        case .vegetables: return "Vegetables"
        }
    }

    var subtitle: String {
        switch self {
        case .buses: return "Buses and bus videos"
        case .tractors: return "Tractors and farming machines"
        case .jcbs: return "JCB and excavator videos"
        case .trucks: return "Trucks and heavy vehicles"
        case .cars: return "Cars and vehicles"
        case .farms: return "Farming and farm life"
        case .villages: return "Village life videos"
        case .construction: return "Construction machines"
        case .abcd: return "Learn A to Z"
        case .counting: return "Learn to count"
        case .days: return "Learn the days"
        case .months: return "Learn the months"
        case .fruits: return "Fruit names"
        case .vegetables: return "Vegetable names"
        }
    }

    var emoji: String {
        switch self {
        case .buses: return "🚌"
        case .tractors: return "🚜"
        case .jcbs: return "🚧"
        case .trucks: return "🚛"
        case .cars: return "🚗"
        case .farms: return "🌾"
        case .villages: return "🏘️"
        case .construction: return "🏗️"
        case .abcd: return "🔤"
        case .counting: return "🔢"
        case .days: return "📅"
        case .months: return "🗓️"
        case .fruits: return "🍎"
        case .vegetables: return "🥕"
        }
    }

    var searchQuery: String {
        switch self {
        case .buses: return "bus buses"
        case .tractors: return "tractor tractors"
        case .jcbs: return "JCB excavator"
        case .trucks: return "truck trucks"
        case .cars: return "car cars"
        case .farms: return "farming farm"
        case .villages: return "Indian village life"
        case .construction: return "construction machines"
        case .abcd: return "ABC alphabet phonics for kids"
        case .counting: return "counting numbers 1 10 for kids"
        case .days: return "days of the week names for kids"
        case .months: return "months of the year names for kids"
        case .fruits: return "fruit names for kids"
        case .vegetables: return "vegetable names for kids"
        }
    }

    var usesPramodsLifeChannel: Bool {
        switch self {
        case .buses, .tractors, .jcbs, .trucks, .cars, .farms, .villages, .construction:
            return true
        case .abcd, .counting, .days, .months, .fruits, .vegetables:
            return false
        }
    }
}

struct YouTubeVideo: Identifiable, Hashable {
    let id: String
    let title: String
    let channelTitle: String
    let thumbnailURL: URL?

    var url: URL? {
        URL(string: "https://www.youtube.com/watch?v=\(id)")
    }
}

actor YouTubeService {
    static let shared = YouTubeService()

    // Set YOUTUBE_API_KEY as a Secret environment variable in Codemagic.
    // Codemagic injects it into Info.plist during the build; it is not stored in Git.
    private var apiKey: String {
        Bundle.main.object(forInfoDictionaryKey: "YOUTUBE_API_KEY") as? String ?? ""
    }

    private let pramodsLifeChannelID = "UC1V1PQT_ZVRjzuzioG05rrQ"

    // Pramod's Life also posts accident and rescue videos. Any video whose title
    // contains one of these words is hidden. Add more words if you spot something
    // unsuitable for a toddler.
    private static let blockedWords: Set<String> = [
        "accident", "accidents", "crash", "crashed", "rescue", "rescued", "fire",
        "burnt", "burning", "dead", "death", "died", "killed", "injured", "blood",
        "fight", "overturned", "drown", "drowned", "collision", "flood", "flooded"
    ]

    func search(category: LearningCategory) async throws -> [YouTubeVideo] {
        // An empty key or an unfilled "$(YOUTUBE_API_KEY)" means the build did not
        // pass the key to the app. Say so instead of showing an empty list.
        guard !apiKey.isEmpty, !apiKey.hasPrefix("$(") else {
            throw YouTubeError.missingAPIKey
        }

        // Strictest search first. If YouTube returns nothing, loosen the filters;
        // unsuitable titles are still removed afterwards.
        let attempts: [(safeSearch: String?, localized: Bool)] = [
            ("strict", true),
            ("moderate", false),
            (nil, false)
        ]

        for attempt in attempts {
            var items = [
                URLQueryItem(name: "part", value: "snippet"),
                URLQueryItem(name: "q", value: category.searchQuery),
                URLQueryItem(name: "type", value: "video"),
                URLQueryItem(name: "maxResults", value: "25"),
                URLQueryItem(name: "order", value: "relevance"),
                URLQueryItem(name: "key", value: apiKey)
            ]
            if let safeSearch = attempt.safeSearch {
                items.append(URLQueryItem(name: "safeSearch", value: safeSearch))
            }
            if attempt.localized {
                items.append(URLQueryItem(name: "regionCode", value: "IN"))
                items.append(URLQueryItem(name: "relevanceLanguage", value: "en"))
            }

            // Vehicle/farm categories come specifically from Pramod's Life.
            // Educational categories search YouTube generally because they are
            // not expected to exist on the Pramod's Life channel.
            if category.usesPramodsLifeChannel {
                items.append(URLQueryItem(name: "channelId", value: pramodsLifeChannelID))
            }

            let videos = try await fetchVideos(queryItems: items)
            if !videos.isEmpty {
                return videos
            }
        }
        return []
    }

    private func fetchVideos(queryItems: [URLQueryItem]) async throws -> [YouTubeVideo] {
        var components = URLComponents(
            string: "https://www.googleapis.com/youtube/v3/search"
        )
        components?.queryItems = queryItems

        guard let url = components?.url else {
            throw YouTubeError.invalidURL
        }

        var request = URLRequest(url: url)
        // Needed if the key is restricted to this iOS app in Google Cloud.
        request.setValue(
            Bundle.main.bundleIdentifier,
            forHTTPHeaderField: "X-Ios-Bundle-Identifier"
        )

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw YouTubeError.requestFailed
        }

        guard (200...299).contains(http.statusCode) else {
            if let apiError = try? JSONDecoder().decode(YouTubeAPIErrorResponse.self, from: data),
               let message = apiError.error?.message {
                throw YouTubeError.api(message)
            }
            throw YouTubeError.httpStatus(http.statusCode)
        }

        let decoded = try JSONDecoder().decode(YouTubeSearchResponse.self, from: data)

        return decoded.items.compactMap { item in
            guard let videoID = item.id.videoID else { return nil }

            let title = Self.cleanTitle(item.snippet.title)
            guard !Self.isUnsuitable(title) else { return nil }

            let thumbnailString = item.snippet.thumbnails?.medium?.url
                ?? item.snippet.thumbnails?.high?.url
                ?? item.snippet.thumbnails?.defaultThumbnail?.url

            return YouTubeVideo(
                id: videoID,
                title: title,
                channelTitle: item.snippet.channelTitle,
                thumbnailURL: thumbnailString.flatMap { URL(string: $0) }
            )
        }
    }

    private static func isUnsuitable(_ title: String) -> Bool {
        let words = Set(
            title.lowercased()
                .split(whereSeparator: { !$0.isLetter })
                .map(String.init)
        )
        return !words.isDisjoint(with: blockedWords)
    }

    private static func cleanTitle(_ title: String) -> String {
        title
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
    }
}

private struct YouTubeSearchResponse: Decodable {
    let items: [YouTubeItem]
}

private struct YouTubeItem: Decodable {
    let id: YouTubeID
    let snippet: YouTubeSnippet
}

private struct YouTubeID: Decodable {
    let videoID: String?

    enum CodingKeys: String, CodingKey {
        case videoID = "videoId"
    }
}

private struct YouTubeSnippet: Decodable {
    let title: String
    let channelTitle: String
    let thumbnails: YouTubeThumbnails?
}

private struct YouTubeThumbnails: Decodable {
    let medium: YouTubeThumbnail?
    let high: YouTubeThumbnail?
    let defaultThumbnail: YouTubeThumbnail?

    enum CodingKeys: String, CodingKey {
        case medium
        case high
        case defaultThumbnail = "default"
    }
}

private struct YouTubeThumbnail: Decodable {
    let url: String
}

private struct YouTubeAPIErrorResponse: Decodable {
    let error: YouTubeAPIError?
}

private struct YouTubeAPIError: Decodable {
    let message: String?
}

private enum YouTubeError: LocalizedError {
    case missingAPIKey
    case invalidURL
    case requestFailed
    case httpStatus(Int)
    case api(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "No YouTube key in this build. The YOUTUBE_API_KEY from Codemagic is not reaching the app. Check the Codemagic variable group named youtube."
        case .invalidURL:
            return "The YouTube request URL is invalid."
        case .requestFailed:
            return "YouTube could not complete the request."
        case .httpStatus(let code):
            return "YouTube returned HTTP \(code)."
        case .api(let message):
            return message
        }
    }
}
