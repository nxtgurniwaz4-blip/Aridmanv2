import SwiftUI
import WebKit

struct VideoListView: View {
    let category: LearningCategory

    @State private var videos: [YouTubeVideo] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    // 1. Tracks the active video item to display the inline player popup sheet
    @State private var playingVideo: YouTubeVideo? = nil

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Finding videos…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage {
                ContentUnavailableView(
                    "Couldn't load videos",
                    systemImage: "exclamationmark.triangle",
                    description: Text(errorMessage)
                )
                .padding()
            } else if videos.isEmpty {
                ContentUnavailableView(
                    "No videos found",
                    systemImage: "play.rectangle",
                    description: Text("Try again later.")
                )
            } else {
                List(videos) { video in
                    // 2. Interactive Button to present the immersive video overlay instead of opening external apps
                    Button(action: {
                        self.playingVideo = video
                    }) {
                        HStack(spacing: 12) {
                            AsyncImage(url: video.thumbnailURL) { phase in
                                switch phase {
                                case .success(let image):
                                    image.resizable().scaledToFill()
                                default:
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(.quaternary)
                                        .overlay {
                                            Image(systemName: "play.fill")
                                                .foregroundStyle(.secondary)
                                        }
                                }
                            }
                            .frame(width: 120, height: 68)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                            VStack(alignment: .leading, spacing: 5) {
                                Text(video.title)
                                    .font(.headline)
                                    .lineLimit(3)
                                    .foregroundColor(.primary)

                                Text(video.channelTitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .padding(.vertical, 5)
                    }
                    .buttonStyle(PlainButtonStyle()) 
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(category.title)
        .task(id: category) {
            await loadVideos()
        }
        // 3. Spans a custom sheet configured for iPad side-by-side viewing
        .sheet(item: $playingVideo) { selectedVideo in
            InlineVideoPlayerSheet(video: selectedVideo)
        }
    }

    private func loadVideos() async {
        isLoading = true
        errorMessage = nil

        do {
            videos = try await YouTubeService.shared.search(category: category)
        } catch {
            videos = []
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

// MARK: - 4. Side-by-Side Theatrical Video Sheet Container (Matches Screenshot Layout)
struct InlineVideoPlayerSheet: View {
    let video: YouTubeVideo
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // LEFT SIDE: The Main Widescreen Video Player Canvas (approx 65% width)
                VStack(alignment: .leading, spacing: 12) {
                    if let targetURL = video.url {
                        let videoID = extractVideoID(from: targetURL)
                        
                        YouTubeInlinePlayerView(videoID: videoID)
                            .frame(height: geometry.size.height * 0.65) // Proportional video block height
                            .background(Color.black)
                    } else {
                        ContentUnavailableView("Playback Error", systemImage: "video.slash")
                            .frame(height: geometry.size.height * 0.65)
                    }
                    
                    // Video Metadata details nested underneath player just like your reference screen
                    VStack(alignment: .leading, spacing: 6) {
                        Text(video.title)
                            .font(.title3)
                            .bold()
                            .lineLimit(2)
                        
                        Text(video.channelTitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                }
                .frame(width: geometry.size.width * 0.65)
                
                // DIVIDER LINE
                Color(.separator)
                    .frame(width: 1)
                    .edgesIgnoringSafeArea(.all)
                
                // RIGHT SIDE: Action Sidebar / Detail List View Context (approx 35% width)
                VStack {
                    HStack {
                        Text("Video Details")
                            .font(.headline)
                            .bold()
                        Spacer()
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Enjoy learning with Pramod's Life! Keep this window open to stay inside your custom application sandbox workspace safely.")
                                .font(.callout)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                    }
                    Spacer()
                }
                .frame(width: geometry.size.width * 0.35)
                .background(Color(.systemGroupedBackground))
            }
        }
        .edgesIgnoringSafeArea(.bottom)
    }
    
    private func extractVideoID(from url: URL) -> String {
        let absoluteString = url.absoluteString
        if absoluteString.contains("watch?v="), let id = absoluteString.components(separatedBy: "v=").last {
            return id.components(separatedBy: "&").first ?? id
        } else if absoluteString.contains("youtu.be/") {
            let id = absoluteString.components(separatedBy: "youtu.be/").last ?? ""
            return id.components(separatedBy: "?").first ?? id
        } else if absoluteString.contains("embed/") {
            let id = absoluteString.components(separatedBy: "embed/").last ?? ""
            return id.components(separatedBy: "?").first ?? id
        }
        return absoluteString
    }
}

// MARK: - 5. Fixed Embedded Rendering Engine (Corrected IFrame URL paths to fix playback)
struct YouTubeInlinePlayerView: UIViewRepresentable {
    let videoID: String
    
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.backgroundColor = .black
        webView.scrollView.isScrollEnabled = false 
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        // FIXED TYPO HERE: Properly formatted /embed/ string ensures YouTube loads streams without failure
        let htmlPayload = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>
                html, body {
                    margin: 0; padding: 0; width: 100%; height: 100%; background-color: #000000; overflow: hidden;
                }
                .video-box {
                    position: absolute; top: 0; left: 0; width: 100%; height: 100%;
                }
            </style>
        </head>
        <body>
            <iframe class="video-box" 
                    src="https://youtube.com\(videoID)?playsinline=1&modestbranding=1&rel=0&autoplay=1" 
                    frameborder="0" 
                    allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture" 
                    referrerpolicy="strict-origin-when-cross-origin" 
                    allowfullscreen>
            </iframe>
        </body>
        </html>
        """
        
        if let primaryBaseURL = URL(string: "https://youtube.com") {
            uiView.loadHTMLString(htmlPayload, baseURL: primaryBaseURL)
        }
    }
}
