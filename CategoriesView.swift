import SwiftUI

struct CategoriesView: View {
    private let columns = [
        GridItem(.adaptive(minimum: 150), spacing: 14)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    NavigationLink {
                        LearnHubView()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "graduationcap.fill")
                                .font(.title)
                            Text("Learn: Counting, Fruits, Vegetables")
                                .font(.headline)
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
                    }
                    .buttonStyle(.plain)

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
                }
                .padding()
            }
            .navigationTitle("Aridman's Happy Place")
        }
    }
}
