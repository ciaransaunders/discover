import SwiftData
import SwiftUI

struct ArticleCardView: View {
  @Bindable var article: ArticleModel

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(article.title)
        .font(.headline)
        .lineLimit(2)

      Text(article.snippet)
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .lineLimit(3)

      HStack {
        Text(article.source)
          .font(.caption)
          .foregroundStyle(.tertiary)
        Spacer()
        if article.isRead {
          Image(systemName: "checkmark.circle.fill")
            .foregroundStyle(.green)
        }
      }
    }
    .padding(Theme.padding)
    .background(Theme.cardBackground)
    .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
    .opacity(article.isRead ? 0.6 : 1.0)
  }
}

#Preview {
  let mockArticle = ArticleModel(
    id: UUID().uuidString,
    title: "Apple announces Swift 6.0",
    snippet:
      "Strict concurrency checking is now the default for all new Swift projects, drastically improving safety.",
    link: "https://apple.com",
    source: "Apple Developer",
    categorySlug: "tech",
    publishedAt: .now
  )
  ArticleCardView(article: mockArticle)
    .padding()
}
