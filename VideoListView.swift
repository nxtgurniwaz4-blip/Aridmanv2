import SwiftUI
import WebKit

struct VideoListView: View {
    let category: LearningCategory

    @State private var videos: [YouTubeVideo] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    // 1. Tracks the active video item to cleanly load it into our inline frame overlay
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
                    // 2. Transformed the system Link layer into an internal UI Button action
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
                                    .foregroundColor(.primary) // Assures normal text color layout inside Button

                                Text(video.channelTitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .padding(.vertical, 5)
                    }
                    .buttonStyle(PlainButtonStyle()) // Ensures your custom list rows look perfectly normal
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(category.title)
        .task(id: category) {
            await loadVideos()
        }
        // 3. Captures the item tap to present the clean native web player container sheet
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

// MARK: - 4. Inline Structural Video Popup Container
struct InlineVideoPlayerSheet: View {
    let video: YouTubeVideo
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // Safely handles the fallback evaluation of the parsed URL configuration
                if let targetURL = video.url {
                    YouTubeInlinePlayerView(videoURL: targetURL)
                        .aspectRatio(16/9, contentMode: .fit)
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                        .padding()
                } else {
                    ContentUnavailableView("Playback Error", systemImage: "video.slash")
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(video.title)
                        .font(.title3)
                        .bold()
                    
                    Text(video.channelTitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - 5. Platform Rendering Engine (Enforces Inline iPad Layout)
struct YouTubeInlinePlayerView: UIViewRepresentable {
    let videoURL: URL
    
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        // iPad critical setting: strictly locks the rendering instance 
        // to prevent the native player from automatically exploding full-screen
        configuration.allowsInlineMediaPlayback = true
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.backgroundColor = .black
        webView.scrollView.isScrollEnabled = false 
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Formats the destination link with embed configuration options safely
        let originalString = videoURL.absoluteString
        var finalURL = videoURL
        
        // Converts standard watch URLs to standard background embed strings dynamically
        if originalString.contains("watch?v="), let videoID = originalString.components(separatedBy: "v=").last {
            let cleanID = videoID.components(separatedBy: "&").first ?? videoID
            if let embedURL = URL(string: "https://www.youtube.com/embed/\(cleanID)?playsinline=1&modestbranding=1&rel=0") {
                finalURL = embedURL
            }
        } else if originalString.contains("youtu.be/") {
            let videoID = originalString.components(separatedBy: "youtu.be/").last ?? ""
            let cleanID = videoID.components(separatedBy: "?").first ?? videoID
            if let embedURL = URL(string: "https://www.youtube.com/embed/\(cleanID)?playsinline=1&modestbranding=1&rel=0") {
                finalURL = embedURL
            }
        }
        
        uiView.load(URLRequest(url: finalURL))
    }
}
