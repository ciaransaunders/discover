import SwiftData
import SwiftUI

struct ArticleListView: View {
  @Environment(\.modelContext) private var modelContext
  @State private var viewModel = ArticleListViewModel()

  @Query(sort: \ArticleModel.publishedAt, order: .reverse) private var articles: [ArticleModel]

  var body: some View {
    ScrollView {
      LazyVStack(spacing: Theme.padding) {
        if articles.isEmpty {
          ContentUnavailableView(
            "No News",
            systemImage: "newspaper",
            description: Text("Pull to refresh or check your feed settings.")
          )
          .padding(.top, 40)
        } else {
          ForEach(articles) { article in
            ArticleCardView(article: article)
              .onTapGesture {
                viewModel.toggleReadState(for: article, context: modelContext)
                if let url = URL(string: article.link) {
                  #if os(macOS)
                    NSWorkspace.shared.open(url)
                  #else
                    UIApplication.shared.open(url)
                  #endif
                }
              }
          }
        }
      }
      .padding()
    }
    .navigationTitle("Discover")
    #if os(iOS)
      .refreshable {
        await viewModel.refresh(context: modelContext)
      }
    #endif
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Button {
          Task {
            await viewModel.refresh(context: modelContext)
          }
        } label: {
          if viewModel.isRefreshing {
            ProgressView()
          } else {
            Image(systemName: "arrow.clockwise")
          }
        }
        .disabled(viewModel.isRefreshing)
      }
    }
    .task {
      if articles.isEmpty {
        await viewModel.refresh(context: modelContext)
      }
    }
  }
}

#Preview {
  NavigationStack {
    ArticleListView()
      .modelContainer(for: [ArticleModel.self, FeedModel.self, CategoryModel.self], inMemory: true)
  }
}
