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

    var url: URL {
        URL(string: "https://www.youtube.com/watch?v=\(id)")!
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

    func search(category: LearningCategory) async throws -> [YouTubeVideo] {
        guard !apiKey.isEmpty else {
            throw YouTubeError.missingAPIKey
        }

        var components = URLComponents(
            string: "https://www.googleapis.com/youtube/v3/search"
        )

        var items = [
            URLQueryItem(name: "part", value: "snippet"),
            URLQueryItem(name: "q", value: category.searchQuery),
            URLQueryItem(name: "type", value: "video"),
            URLQueryItem(name: "maxResults", value: "25"),
            URLQueryItem(name: "order", value: "relevance"),
            URLQueryItem(name: "regionCode", value: "IN"),
            URLQueryItem(name: "relevanceLanguage", value: "en"),
            URLQueryItem(name: "safeSearch", value: "strict"),
            URLQueryItem(name: "key", value: apiKey)
        ]

        // Vehicle/farm categories come specifically from Pramod's Life.
        // Educational categories search YouTube generally because they are
        // not expected to exist on the Pramod's Life channel.
        if category.usesPramodsLifeChannel {
            items.append(URLQueryItem(name: "channelId", value: pramodsLifeChannelID))
        }

        components?.queryItems = items

        guard let url = components?.url else {
            throw YouTubeError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)

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

            return YouTubeVideo(
                id: videoID,
                title: item.snippet.title,
                channelTitle: item.snippet.channelTitle,
                thumbnailURL: URL(string: item.snippet.thumbnails?.medium?.url
                    ?? item.snippet.thumbnails?.high?.url
                    ?? item.snippet.thumbnails?.defaultThumbnail?.url
                    ?? "")
            )
        }
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
            return "YouTube is not configured yet. Add YOUTUBE_API_KEY as a Codemagic Secret."
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
