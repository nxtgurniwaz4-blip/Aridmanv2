import SwiftUI

struct VideoListView: View {
    let category: LearningCategory

    @State private var videos: [YouTubeVideo] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

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
                    Link(destination: video.url) {
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

                                Text(video.channelTitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .padding(.vertical, 5)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(category.title)
        .task(id: category) {
            await loadVideos()
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
