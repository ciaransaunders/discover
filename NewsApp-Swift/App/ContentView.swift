import SwiftData
import SwiftUI

struct ContentView: View {
  @State private var router = NavigationRouter()

  var body: some View {
    NavigationStack(path: $router.path) {
      ArticleListView()
        .navigationDestination(for: Route.self) { route in
          switch route {
          case .articleDetail(let id):
            Text("Article Detail: \(id)")
          // NOTE: Could extract to another feature folder
          case .categoryFeed(let slug):
            Text("Category: \(slug)")
          case .settings:
            Text("Settings")
          }
        }
    }
    .environment(router)
  }
}

#Preview {
  ContentView()
    .modelContainer(for: [ArticleModel.self, FeedModel.self, CategoryModel.self], inMemory: true)
}
