import SwiftUI

struct CategoriesView: View {
    private let columns = [
        GridItem(.adaptive(minimum: 150), spacing: 14)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(LearningCategory.allCases) { category in
                        NavigationLink {
                            VideoListView(category: category)
                        } label: {
                            CategoryTile(category: category)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .navigationTitle("Aridman's Happy Place")
        }
    }
}
