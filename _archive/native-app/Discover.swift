import Cocoa
import Foundation
import SwiftUI
import WebKit

// MARK: - Configuration

enum Config {
  static let appPort: UInt16 = 3456
  static let projectDir = NSString(string: "~/Desktop/NEWS PORJECT/.claude/worktrees/silly-goodall")
    .expandingTildeInPath
  static let serverURL = "http://localhost:\(appPort)"
}

// MARK: - Server Manager

class ServerManager: ObservableObject {
  private var process: Process?
  private var outputPipe: Pipe?
  @Published var isReady = false
  @Published var initializationFailed = false

  var isRunning: Bool {
    process?.isRunning ?? false
  }

  func findNodePath() -> String? {
    let candidates = [
      "/opt/homebrew/bin/node",
      "/usr/local/bin/node",
      "/usr/bin/node",
      NSString(string: "~/.nvm/versions/node").expandingTildeInPath,
    ]

    for path in candidates {
      if path.contains(".nvm") {
        let fm = FileManager.default
        if let versions = try? fm.contentsOfDirectory(atPath: path) {
          let sorted = versions.sorted().reversed()
          for version in sorted {
            let nodePath = "\(path)/\(version)/bin/node"
            if fm.isExecutableFile(atPath: nodePath) { return nodePath }
          }
        }
      } else if FileManager.default.isExecutableFile(atPath: path) {
        return path
      }
    }

    let whichProcess = Process()
    whichProcess.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    whichProcess.arguments = ["which", "node"]
    let pipe = Pipe()
    whichProcess.standardOutput = pipe
    var env = ProcessInfo.processInfo.environment
    env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:" + (env["PATH"] ?? "")
    whichProcess.environment = env
    try? whichProcess.run()
    whichProcess.waitUntilExit()

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)

    if let path = path, !path.isEmpty, FileManager.default.isExecutableFile(atPath: path) {
      return path
    }
    return nil
  }

  func start() {
    guard let nodePath = findNodePath() else {
      DispatchQueue.main.async { self.initializationFailed = true }
      return
    }

    let nodeDir = (nodePath as NSString).deletingLastPathComponent

    let killProcess = Process()
    killProcess.executableURL = URL(fileURLWithPath: "/bin/bash")
    killProcess.arguments = ["-c", "lsof -ti:\(Config.appPort) | xargs kill -9 2>/dev/null; true"]
    try? killProcess.run()
    killProcess.waitUntilExit()

    let proc = Process()
    proc.executableURL = URL(fileURLWithPath: "/bin/bash")
    proc.arguments = ["-c", "npx next start -p \(Config.appPort)"]
    proc.currentDirectoryURL = URL(fileURLWithPath: Config.projectDir)

    var env = ProcessInfo.processInfo.environment
    env["PATH"] = "\(nodeDir):/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
    env["NODE_ENV"] = "production"
    proc.environment = env

    outputPipe = Pipe()
    proc.standardOutput = outputPipe
    proc.standardError = outputPipe

    do {
      try proc.run()
      process = proc
      waitForReady()
    } catch {
      NSLog("Failed to start server: \(error)")
      DispatchQueue.main.async { self.initializationFailed = true }
    }
  }

  func stop() {
    process?.terminate()
    process = nil
    let killProcess = Process()
    killProcess.executableURL = URL(fileURLWithPath: "/bin/bash")
    killProcess.arguments = ["-c", "lsof -ti:\(Config.appPort) | xargs kill -9 2>/dev/null; true"]
    try? killProcess.run()
    killProcess.waitUntilExit()
  }

  private func waitForReady(timeout: TimeInterval = 30) {
    let startTime = Date()
    func check() {
      if Date().timeIntervalSince(startTime) > timeout {
        DispatchQueue.main.async { self.initializationFailed = true }
        return
      }
      guard let url = URL(string: Config.serverURL) else { return }
      var request = URLRequest(url: url)
      request.timeoutInterval = 2

      let task = URLSession.shared.dataTask(with: request) { _, response, _ in
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
          DispatchQueue.main.async { self.isReady = true }
        } else {
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { check() }
        }
      }
      task.resume()
    }
    check()
  }
}

// MARK: - WebView Representable

struct WebViewTemplate: NSViewRepresentable {
  let targetURL: URL

  class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
    func webView(
      _ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
      for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
      if let url = navigationAction.request.url {
        NSWorkspace.shared.open(url)
      }
      return nil
    }

    func webView(
      _ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
      decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
      if let url = navigationAction.request.url {
        if url.host == "localhost" || url.host == "127.0.0.1" {
          decisionHandler(.allow)
        } else if navigationAction.navigationType == .linkActivated {
          NSWorkspace.shared.open(url)
          decisionHandler(.cancel)
        } else {
          decisionHandler(.allow)
        }
      } else {
        decisionHandler(.allow)
      }
    }
  }

  func makeCoordinator() -> Coordinator {
    Coordinator()
  }

  func makeNSView(context: Context) -> WKWebView {
    let config = WKWebViewConfiguration()
    config.preferences.setValue(true, forKey: "developerExtrasEnabled")
    // Required, otherwise next.js scrollbars interfere
    config.preferences.setValue(false, forKey: "minimumFontSize")

    let webView = WKWebView(frame: .zero, configuration: config)
    webView.navigationDelegate = context.coordinator
    webView.uiDelegate = context.coordinator

    // Critical for "Liquid Glass" - webview must be entirely transparent
    webView.setValue(false, forKey: "drawsBackground")
    webView.layer?.backgroundColor = NSColor.clear.cgColor
    if let scrollView = webView.enclosingScrollView {
      scrollView.drawsBackground = false
      scrollView.backgroundColor = .clear
    }

    return webView
  }

  func updateNSView(_ nsView: WKWebView, context: Context) {
    if nsView.url?.absoluteString != targetURL.absoluteString {
      nsView.load(URLRequest(url: targetURL))
    }
  }
}

// MARK: - SwiftUI Views

struct LiquidBackground: View {
  var body: some View {
    if #available(macOS 14.0, *) {
      TimelineView(.periodic(from: .now, by: 0.25)) { timeline in
        let time = timeline.date.timeIntervalSince1970
        MeshGradient(
          width: 3,
          height: 3,
          points: [
            [0, 0], [0.5, 0], [1, 0],
            [0, 0.5],
            [Float(0.5 + 0.15 * sin(time * 0.4)), Float(0.5 + 0.15 * cos(time * 0.3))],
            [1, 0.5],
            [0, 1], [0.5, 1], [1, 1],
          ],
          colors: [
            Color(red: 0.1, green: 0.1, blue: 0.4), Color(red: 0.2, green: 0.1, blue: 0.6),
            Color(red: 0.1, green: 0.2, blue: 0.5),
            Color(red: 0.0, green: 0.3, blue: 0.5), Color(red: 0.4, green: 0.1, blue: 0.6),
            Color(red: 0.0, green: 0.2, blue: 0.4),
            Color(red: 0.0, green: 0.1, blue: 0.3), Color(red: 0.1, green: 0.0, blue: 0.3),
            Color(red: 0.0, green: 0.2, blue: 0.2),
          ],
          background: .black
        )
        .ignoresSafeArea()
      }
    } else {
      Color(red: 0.04, green: 0.04, blue: 0.06)
        .ignoresSafeArea()
    }
  }
}

struct LiquidGlassAppView: View {
  @StateObject private var serverManager = ServerManager()

  var body: some View {
    ZStack {
      LiquidBackground()

      // Frosted Glass layer (no blend mode for performance)
      VisualEffectView(material: .underWindowBackground, blendingMode: .behindWindow)
        .ignoresSafeArea()

      // Main WebContent
      if serverManager.isReady {
        WebViewTemplate(targetURL: URL(string: Config.serverURL)!)
      } else if serverManager.initializationFailed {
        VStack(spacing: 20) {
          Image(systemName: "exclamationmark.triangle.fill")
            .font(.system(size: 40))
            .foregroundColor(.yellow)
          Text("Initialization Failed")
            .font(.title2)
            .fontWeight(.semibold)
          Text("Could not start node server or find dependencies.")
            .foregroundColor(.secondary)
          Button("Quit") {
            NSApplication.shared.terminate(nil)
          }
          .buttonStyle(.borderedProminent)
        }
      } else {
        VStack(spacing: 20) {
          ProgressView()
            .controlSize(.large)
          Text("Initializing Liquid Glass Discover...")
            .fontWeight(.medium)
            .foregroundColor(.primary.opacity(0.8))
        }
      }
    }
    .onAppear {
      serverManager.start()
    }
    .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) {
      _ in
      serverManager.stop()
    }
  }
}

// SwiftUI wrap for older VisualEffect (Fallback)
struct VisualEffectView: NSViewRepresentable {
  let material: NSVisualEffectView.Material
  let blendingMode: NSVisualEffectView.BlendingMode

  func makeNSView(context: Context) -> NSVisualEffectView {
    let view = NSVisualEffectView()
    view.material = material
    view.blendingMode = blendingMode
    view.state = .active
    return view
  }

  func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

// MARK: - App Delegate & Main

@main
struct DiscoverApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

  var body: some Scene {
    WindowGroup {
      LiquidGlassAppView()
        .frame(minWidth: 800, minHeight: 600)
        // Ensures glass extends under title bar
        .edgesIgnoringSafeArea(.top)
    }
    .windowStyle(.hiddenTitleBar)
  }
}

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
  func applicationDidFinishLaunching(_ notification: Notification) {
    if let window = NSApplication.shared.windows.first {
      window.titlebarAppearsTransparent = true
      window.titleVisibility = .hidden
      window.styleMask.insert(.fullSizeContentView)
      window.isOpaque = false
      window.backgroundColor = .clear

      window.isReleasedWhenClosed = false

      // Allow the webview beneath it to manage traffic light clicking
      window.standardWindowButton(.closeButton)?.superview?.isHidden = false
    }
  }

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool
  {
    if !flag {
      NSApplication.shared.windows.first?.makeKeyAndOrderFront(nil)
    }
    return true
  }
}
