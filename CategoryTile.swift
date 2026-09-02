import SwiftUI

struct CategoryTile: View {
    let category: LearningCategory

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(category.emoji)
                .font(.system(size: 40))

            Text(category.title)
                .font(.headline)
                .foregroundStyle(.primary)

            Text(category.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Label("Watch videos", systemImage: "play.circle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tint)
        }
        .frame(maxWidth: .infinity, minHeight: 155, alignment: .topLeading)
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }
}
