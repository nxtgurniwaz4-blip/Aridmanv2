import SwiftUI
import AVFoundation
import AVKit
import WebKit

// MARK: - Speech

final class LearnSpeaker {
    static let shared = LearnSpeaker()
    private let synth = AVSpeechSynthesizer()

    static let numberWords = [
        "zero", "one", "two", "three", "four", "five", "six", "seven", "eight",
        "nine", "ten", "eleven", "twelve", "thirteen", "fourteen", "fifteen",
        "sixteen", "seventeen", "eighteen", "nineteen", "twenty"
    ]

    private init() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    func say(_ text: String, interrupt: Bool = true) {
        if interrupt { synth.stopSpeaking(at: .immediate) }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.4
        utterance.pitchMultiplier = 1.2
        synth.speak(utterance)
    }
}

// MARK: - YouTube Data API
//
// The key is read from Info.plist (YOUTUBE_API_KEY). Never type the key into
// this file: the repo is public.

enum YouTubeAPI {
    enum Failure: LocalizedError {
        case missingKey
        case http(Int)
        case noResults

        var errorDescription: String? {
            switch self {
            case .missingKey:
                return "No API key found in the app. The build is not passing YOUTUBE_API_KEY to Info.plist."
            case .http(let code):
                return "YouTube refused the request (error \(code)). Check that YouTube Data API v3 is enabled and the key's restrictions allow this app."
            case .noResults:
                return "No video found for this item."
            }
        }
    }

    private struct SearchResponse: Decodable {
        struct Item: Decodable {
            struct ID: Decodable { let videoId: String? }
            let id: ID
        }
        let items: [Item]
    }

    static var apiKey: String? {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "YOUTUBE_API_KEY") as? String,
              !key.isEmpty, !key.hasPrefix("$(") else { return nil }
        return key
    }

    /// Finds the first kid-safe, embeddable video for a search phrase.
    /// Results are cached on the device to save daily quota.
    static func firstVideoID(for query: String) async throws -> String {
        let cacheKey = "learn_yt_" + query
        if let cached = UserDefaults.standard.string(forKey: cacheKey) { return cached }
        guard let key = apiKey else { throw Failure.missingKey }

        var components = URLComponents(string: "https://www.googleapis.com/youtube/v3/search")!
        components.queryItems = [
            URLQueryItem(name: "part", value: "snippet"),
            URLQueryItem(name: "type", value: "video"),
            URLQueryItem(name: "videoEmbeddable", value: "true"),
            URLQueryItem(name: "safeSearch", value: "strict"),
            URLQueryItem(name: "maxResults", value: "1"),
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "key", value: key)
        ]
        var request = URLRequest(url: components.url!)
        request.setValue(Bundle.main.bundleIdentifier, forHTTPHeaderField: "X-Ios-Bundle-Identifier")

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw Failure.http(http.statusCode)
        }
        let decoded = try JSONDecoder().decode(SearchResponse.self, from: data)
        guard let id = decoded.items.first?.id.videoId else { throw Failure.noResults }
        UserDefaults.standard.set(id, forKey: cacheKey)
        return id
    }
}

// MARK: - Data
//
// PHOTOS (automatic): each item loads a photo from Wikipedia on its own, no setup.
// PHOTOS (your own, optional): add an image to Assets.xcassets named "learn_" + lowercase name with
//         underscores, e.g. learn_apple, learn_banana, learn_sweet_potato.
//         (Or set imageURL to a photo you have the rights to use.)
// VIDEOS: loaded automatically from YouTube using your API key. To force a
//         specific video, set youtubeID (the part after v= in the link), or add
//         an .mp4 to the app and set videoFile to its name without ".mp4".

struct LearnItem: Identifiable {
    let name: String
    var imageURL: URL? = nil
    var youtubeID: String? = nil
    var videoFile: String? = nil

    var id: String { name }
    var slug: String { name.lowercased().replacingOccurrences(of: " ", with: "_") }
    var assetName: String { "learn_" + slug }

    /// Wikipedia article whose lead photo is used when no photo is bundled.
    private static let wikiOverrides: [String: String] = [
        "Orange": "Orange (fruit)", "Grapes": "Grape", "Kiwi": "Kiwifruit",
        "Corn": "Maize", "Blueberries": "Blueberry", "Bell Pepper": "Bell pepper",
        "Chili Pepper": "Chili pepper", "Sweet Potato": "Sweet potato",
        "Ice Cream": "Ice cream", "Yoyo": "Yo-yo", "Juice": "Juice"
    ]
    var wikiTitle: String { Self.wikiOverrides[name] ?? name }
}

enum LearnData {
    static let countingQuery = "counting 1 to 20 for toddlers"
    static let countingYouTubeID: String? = nil

    static let fruits: [LearnItem] = [
        LearnItem(name: "Apple"), LearnItem(name: "Banana"), LearnItem(name: "Orange"),
        LearnItem(name: "Grapes"), LearnItem(name: "Strawberry"), LearnItem(name: "Watermelon"),
        LearnItem(name: "Pineapple"), LearnItem(name: "Cherry"), LearnItem(name: "Mango"),
        LearnItem(name: "Pear"), LearnItem(name: "Peach"), LearnItem(name: "Lemon"),
        LearnItem(name: "Kiwi"), LearnItem(name: "Coconut"), LearnItem(name: "Blueberries")
    ]

    static let vegetables: [LearnItem] = [
        LearnItem(name: "Carrot"), LearnItem(name: "Broccoli"), LearnItem(name: "Tomato"),
        LearnItem(name: "Potato"), LearnItem(name: "Corn"), LearnItem(name: "Cucumber"),
        LearnItem(name: "Onion"), LearnItem(name: "Garlic"), LearnItem(name: "Bell Pepper"),
        LearnItem(name: "Eggplant"), LearnItem(name: "Lettuce"), LearnItem(name: "Sweet Potato"),
        LearnItem(name: "Chili Pepper")
    ]
}

// MARK: - Automatic photos from Wikipedia
//
// No key needed. Looks up the lead photo of a Wikipedia article and caches the
// link on the device. Wikipedia photos have free licenses, but many need credit
// (e.g. CC BY-SA). Fine for personal use; add credits before publishing to the App Store.

enum WikipediaPhoto {
    private struct Summary: Decodable {
        struct Img: Decodable {
            let source: String
            let width: Int?
        }
        let thumbnail: Img?
        let originalimage: Img?
    }

    static func url(for title: String) async -> URL? {
        let cacheKey = "learn_wiki_" + title
        if let cached = UserDefaults.standard.string(forKey: cacheKey), let url = URL(string: cached) {
            return url
        }
        let underscored = title.replacingOccurrences(of: " ", with: "_")
        guard let escaped = underscored.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let endpoint = URL(string: "https://en.wikipedia.org/api/rest_v1/page/summary/" + escaped)
        else { return nil }

        var request = URLRequest(url: endpoint)
        request.setValue("AridmansHappyPlace/1.0 (iOS app)", forHTTPHeaderField: "User-Agent")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            let summary = try JSONDecoder().decode(Summary.self, from: data)
            var source = summary.thumbnail?.source
            if let original = summary.originalimage, let width = original.width, width <= 1600 {
                source = original.source
            }
            guard let chosen = source, let url = URL(string: chosen) else { return nil }
            UserDefaults.standard.set(chosen, forKey: cacheKey)
            return url
        } catch {
            return nil
        }
    }
}

// MARK: - Photo + video building blocks

struct LearnPhoto: View {
    let item: LearnItem
    var corner: CGFloat = 16

    var body: some View {
        Color.gray.opacity(0.12)
            .aspectRatio(1, contentMode: .fit)
            .overlay(content)
            .clipShape(RoundedRectangle(cornerRadius: corner))
            .task { await resolve() }
    }

    @State private var resolved: URL?
    @State private var failed = false

    private func resolve() async {
        if let url = item.imageURL {
            resolved = url
            return
        }
        if let url = await WikipediaPhoto.url(for: item.wikiTitle) {
            resolved = url
        } else {
            failed = true
        }
    }

    @ViewBuilder private var content: some View {
        if UIImage(named: item.assetName) != nil {
            Image(item.assetName).resizable().scaledToFill()
        } else if let url = resolved {
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else if phase.error != nil {
                    placeholder
                } else {
                    ProgressView()
                }
            }
        } else if failed {
            placeholder
        } else {
            ProgressView()
        }
    }

    private var placeholder: some View {
        Image(systemName: "photo")
            .font(.largeTitle)
            .foregroundColor(.gray)
    }
}

struct YouTubePlayer: UIViewRepresentable {
    let videoID: String

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        let web = WKWebView(frame: .zero, configuration: config)
        web.scrollView.isScrollEnabled = false
        web.isOpaque = false
        return web
    }

    func updateUIView(_ web: WKWebView, context: Context) {
        let html = """
        <html><head><meta name="viewport" content="width=device-width, initial-scale=1">
        <style>html,body{margin:0;background:transparent}iframe{width:100%;height:100vh;border:0}</style></head>
        <body><iframe src="https://www.youtube.com/embed/\(videoID)?playsinline=1&rel=0&modestbranding=1&enablejsapi=1&origin=https://www.youtube.com"
        referrerpolicy="strict-origin-when-cross-origin"
        allow="autoplay; encrypted-media; picture-in-picture" allowfullscreen></iframe></body></html>
        """
        web.loadHTMLString(html, baseURL: URL(string: "https://www.youtube.com"))
    }
}

/// Shows a video for a search phrase (or a known video ID), with a clear message if it fails.
struct RemoteVideoView: View {
    let query: String
    var knownID: String? = nil

    @State private var videoID: String?
    @State private var message: String?

    var body: some View {
        Group {
            if let id = videoID {
                VStack(spacing: 10) {
                    YouTubePlayer(videoID: id)
                        .aspectRatio(16 / 9, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                    if let url = URL(string: "https://www.youtube.com/watch?v=\(id)") {
                        Link(destination: url) {
                            Label("Open in YouTube", systemImage: "arrow.up.right.square")
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                        }
                    }
                }
            } else if let message = message {
                Text(message)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                ProgressView()
            }
        }
        .padding(.horizontal)
        .task { await load() }
    }

    private func load() async {
        if let known = knownID {
            videoID = known
            return
        }
        do {
            videoID = try await YouTubeAPI.firstVideoID(for: query)
        } catch {
            message = error.localizedDescription
        }
    }
}

struct BundledVideo: View {
    @State private var player: AVPlayer

    init(url: URL) {
        _player = State(initialValue: AVPlayer(url: url))
    }

    var body: some View {
        VideoPlayer(player: player)
    }
}

// MARK: - Alphabet (ABC with voices)
//
// Each letter shows a photo of its word. Add photos named like the others:
// learn_apple, learn_ball, learn_cat ... (see the PHOTOS note above).

struct AlphabetEntry: Identifiable {
    let letter: String
    let spoken: String   // how the voice says the letter's name
    let word: String
    var id: String { letter }
    var item: LearnItem { LearnItem(name: word) }
    var sentence: String { "\(spoken). \(spoken) is for \(word)." }
}

enum Alphabet {
    static let all: [AlphabetEntry] = [
        AlphabetEntry(letter: "A", spoken: "ay", word: "Apple"),
        AlphabetEntry(letter: "B", spoken: "bee", word: "Ball"),
        AlphabetEntry(letter: "C", spoken: "see", word: "Cat"),
        AlphabetEntry(letter: "D", spoken: "dee", word: "Dog"),
        AlphabetEntry(letter: "E", spoken: "ee", word: "Elephant"),
        AlphabetEntry(letter: "F", spoken: "eff", word: "Fish"),
        AlphabetEntry(letter: "G", spoken: "gee", word: "Grapes"),
        AlphabetEntry(letter: "H", spoken: "aitch", word: "Horse"),
        AlphabetEntry(letter: "I", spoken: "eye", word: "Ice Cream"),
        AlphabetEntry(letter: "J", spoken: "jay", word: "Juice"),
        AlphabetEntry(letter: "K", spoken: "kay", word: "Kite"),
        AlphabetEntry(letter: "L", spoken: "el", word: "Lion"),
        AlphabetEntry(letter: "M", spoken: "em", word: "Mango"),
        AlphabetEntry(letter: "N", spoken: "en", word: "Nest"),
        AlphabetEntry(letter: "O", spoken: "oh", word: "Orange"),
        AlphabetEntry(letter: "P", spoken: "pee", word: "Pineapple"),
        AlphabetEntry(letter: "Q", spoken: "cue", word: "Quail"),
        AlphabetEntry(letter: "R", spoken: "ar", word: "Rabbit"),
        AlphabetEntry(letter: "S", spoken: "es", word: "Strawberry"),
        AlphabetEntry(letter: "T", spoken: "tee", word: "Tomato"),
        AlphabetEntry(letter: "U", spoken: "you", word: "Umbrella"),
        AlphabetEntry(letter: "V", spoken: "vee", word: "Violin"),
        AlphabetEntry(letter: "W", spoken: "double you", word: "Watermelon"),
        AlphabetEntry(letter: "X", spoken: "ex", word: "Xylophone"),
        AlphabetEntry(letter: "Y", spoken: "why", word: "Yoyo"),
        AlphabetEntry(letter: "Z", spoken: "zee", word: "Zebra")
    ]
}

struct AlphabetView: View {
    @State private var playing = false
    @State private var highlighted: String?
    @State private var task: Task<Void, Never>?

    private let columns = [GridItem(.adaptive(minimum: 90), spacing: 12)]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Button(action: playAll) {
                    Label(playing ? "Saying the ABCs..." : "Say the ABCs", systemImage: "play.circle.fill")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.purple, in: RoundedRectangle(cornerRadius: 20))
                        .foregroundColor(.white)
                }
                .disabled(playing)

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(Alphabet.all) { entry in
                        NavigationLink(destination: LetterDetailView(entry: entry)) {
                            Text(entry.letter)
                                .font(.system(size: 44, weight: .heavy, design: .rounded))
                                .frame(maxWidth: .infinity)
                                .aspectRatio(1, contentMode: .fit)
                                .background(
                                    Color.purple.opacity(highlighted == entry.letter ? 0.6 : 0.15),
                                    in: RoundedRectangle(cornerRadius: 18)
                                )
                                .foregroundColor(.primary)
                                .scaleEffect(highlighted == entry.letter ? 1.15 : 1)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("ABC")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            task?.cancel()
            playing = false
            highlighted = nil
        }
    }

    private func playAll() {
        guard !playing else { return }
        playing = true
        task = Task { @MainActor in
            for entry in Alphabet.all {
                if Task.isCancelled { break }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { highlighted = entry.letter }
                LearnSpeaker.shared.say(entry.spoken, interrupt: false)
                try? await Task.sleep(nanoseconds: 900_000_000)
            }
            highlighted = nil
            playing = false
        }
    }
}

struct LetterDetailView: View {
    let entry: AlphabetEntry

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("\(entry.letter)\(entry.letter.lowercased())")
                    .font(.system(size: 130, weight: .heavy, design: .rounded))
                    .foregroundColor(.purple)

                LearnPhoto(item: entry.item, corner: 28)
                    .frame(maxWidth: 320)

                Text("\(entry.letter) is for \(entry.word)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)

                Button(action: speak) {
                    Label("Say it", systemImage: "speaker.wave.2.fill")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .background(Color.purple, in: Capsule())
                        .foregroundColor(.white)
                }
            }
            .padding()
        }
        .navigationTitle(entry.letter)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: speak)
    }

    private func speak() {
        LearnSpeaker.shared.say(entry.sentence)
    }
}

// MARK: - Hub (push this from your categories screen)

struct LearnHubView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                NavigationLink(destination: AlphabetView()) {
                    LearnHubCard(symbol: "textformat.abc", title: "ABC", color: .purple)
                }
                NavigationLink(destination: CountingView()) {
                    LearnHubCard(symbol: "number", title: "Counting", color: .orange)
                }
                NavigationLink(destination: NameListView(title: "Fruits", items: LearnData.fruits, color: .red)) {
                    LearnHubCard(symbol: "applelogo", title: "Fruits", color: .red)
                }
                NavigationLink(destination: NameListView(title: "Vegetables", items: LearnData.vegetables, color: .green)) {
                    LearnHubCard(symbol: "leaf.fill", title: "Vegetables", color: .green)
                }
            }
            .buttonStyle(.plain)
            .padding()
        }
        .navigationTitle("Learn")
    }
}

struct LearnHubCard: View {
    let symbol: String
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: symbol)
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(color)
                .frame(width: 60)
            Text(title)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(color.opacity(0.2), in: RoundedRectangle(cornerRadius: 24))
    }
}

// MARK: - Counting

struct CountingView: View {
    @State private var number = 1
    @State private var highlighted = 0
    @State private var counting = false
    @State private var showVideo = false

    private let maxNumber = 20
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 5)

    // One fruit repeated, so kids count identical things.
    private let countingFruits = ["Apple", "Orange", "Strawberry", "Lemon", "Pear"]

    private var item: LearnItem {
        LearnItem(name: countingFruits[(number - 1) % countingFruits.count])
    }

    var body: some View {
        VStack(spacing: 14) {
            Text("\(number)")
                .font(.system(size: 100, weight: .heavy, design: .rounded))
                .foregroundColor(.orange)
            Text(LearnSpeaker.numberWords[number].capitalized)
                .font(.system(size: 30, weight: .bold, design: .rounded))

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(1...number, id: \.self) { i in
                    LearnPhoto(item: item, corner: 12)
                        .scaleEffect(highlighted == i ? 1.15 : 1)
                        .opacity(highlighted == 0 || i <= highlighted ? 1 : 0.25)
                }
            }
            .padding(.horizontal)
            .frame(maxWidth: 600)

            Spacer()

            Button(action: countAloud) {
                Label("Count it!", systemImage: "speaker.wave.2.fill")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.orange, in: RoundedRectangle(cornerRadius: 20))
                    .foregroundColor(.white)
            }
            .disabled(counting)
            .padding(.horizontal)

            HStack(spacing: 16) {
                stepButton(symbol: "chevron.left", enabled: number > 1) { change(-1) }
                stepButton(symbol: "chevron.right", enabled: number < maxNumber) { change(1) }
            }
            .padding(.horizontal)

            Button { showVideo = true } label: {
                Label("Watch counting video", systemImage: "play.rectangle.fill")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
            }
        }
        .padding(.bottom)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { LearnSpeaker.shared.say(LearnSpeaker.numberWords[number]) }
        .sheet(isPresented: $showVideo) {
            RemoteVideoView(query: LearnData.countingQuery, knownID: LearnData.countingYouTubeID)
                .presentationDetents([.medium])
        }
    }

    private func stepButton(symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 28, weight: .bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.orange.opacity(0.2), in: RoundedRectangle(cornerRadius: 20))
        }
        .disabled(!enabled || counting)
    }

    private func change(_ delta: Int) {
        number = min(max(number + delta, 1), maxNumber)
        highlighted = 0
        LearnSpeaker.shared.say(LearnSpeaker.numberWords[number])
    }

    private func countAloud() {
        guard !counting else { return }
        counting = true
        Task { @MainActor in
            for i in 1...number {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { highlighted = i }
                LearnSpeaker.shared.say(LearnSpeaker.numberWords[i], interrupt: false)
                try? await Task.sleep(nanoseconds: 800_000_000)
            }
            highlighted = 0
            counting = false
        }
    }
}

// MARK: - Name lists (fruits, vegetables)

struct NameListView: View {
    let title: String
    let items: [LearnItem]
    let color: Color

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 16)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(items) { item in
                    NavigationLink(destination: ItemDetailView(item: item, color: color)) {
                        VStack(spacing: 8) {
                            LearnPhoto(item: item)
                            Text(item.name)
                                .font(.system(.title3, design: .rounded).bold())
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(10)
                        .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 20))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ItemDetailView: View {
    let item: LearnItem
    let color: Color

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                LearnPhoto(item: item, corner: 28)
                    .padding(.horizontal)

                Text(item.name)
                    .font(.system(size: 44, weight: .heavy, design: .rounded))

                Button { LearnSpeaker.shared.say(item.name) } label: {
                    Label("Say it", systemImage: "speaker.wave.2.fill")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .background(color, in: Capsule())
                        .foregroundColor(.white)
                }

                video
            }
            .padding(.vertical)
        }
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { LearnSpeaker.shared.say(item.name) }
    }

    @ViewBuilder private var video: some View {
        if let file = item.videoFile,
           let url = Bundle.main.url(forResource: file, withExtension: "mp4") {
            BundledVideo(url: url)
                .aspectRatio(16 / 9, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .padding(.horizontal)
        } else {
            RemoteVideoView(query: "\(item.name) name for kids learn", knownID: item.youtubeID)
        }
    }
}
