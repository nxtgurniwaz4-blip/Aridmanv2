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
                    .buttonStyle(PlainButtonStyle()) // Preserves standard row click appearance
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(category.title)
        .task(id: category) {
            await loadVideos()
        }
        // 3. Spans a clean presentation screen for the video player container
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

// MARK: - 4. Real-Sized Immersive Video Sheet Container
struct InlineVideoPlayerSheet: View {
    let video: YouTubeVideo
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if let targetURL = video.url {
                    let videoID = extractVideoID(from: targetURL)
                    
                    // Fills the maximum layout width and height area cleanly for the iPad screen space
                    YouTubeInlinePlayerView(videoID: videoID)
                        .edgesIgnoringSafeArea(.bottom)
                } else {
                    ContentUnavailableView("Playback Error", systemImage: "video.slash")
                }
            }
            .navigationTitle(video.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle()) // Enforces clean uniform layout presentation rules
    }
    
    // Safely reads the text ID characters from your video URL feed configuration
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

// MARK: - 5. Embedded Rendering Interface (Bypasses Playback Blockages & Expands Frame)
struct YouTubeInlinePlayerView: UIViewRepresentable {
    let videoID: String
    
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        // Prevents the system context from throwing the video out into a default Apple full-screen frame player
        configuration.allowsInlineMediaPlayback = true
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.backgroundColor = .black
        webView.scrollView.isScrollEnabled = false 
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Embed code structure explicitly configuring safe origin referrer properties to clear security blocks
        let htmlPayload = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>
                html, body {
                    margin: 0; padding: 0; width: 100%; height: 100%; background-color: #000000; overflow: hidden;
                }
                .video-container {
                    position: absolute; top: 0; left: 0; width: 100%; height: 100%;
                }
            </style>
        </head>
        <body>
            <iframe class="video-container" 
                    src="https://youtube.com\(videoID)?playsinline=1&modestbranding=1&rel=0&autoplay=1" 
                    frameborder="0" 
                    allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture" 
                    referrerpolicy="strict-origin-when-cross-origin" 
                    allowfullscreen>
            </iframe>
        </body>
        </html>
        """
        
        // Providing an official base URL context allows the player component to securely render the video feed streams
        if let primaryBaseURL = URL(string: "https://youtube.com") {
            uiView.loadHTMLString(htmlPayload, baseURL: primaryBaseURL)
        }
    }
}
