import SwiftUI

enum Route: Hashable {
  case articleDetail(id: String)
  case categoryFeed(slug: String)
  case settings
}

@Observable
final class NavigationRouter {
  var path: [Route] = []

  func push(_ route: Route) {
    path.append(route)
  }

  func pop() {
    if !path.isEmpty {
      path.removeLast()
    }
  }

  func popToRoot() {
    path.removeAll()
  }
}
