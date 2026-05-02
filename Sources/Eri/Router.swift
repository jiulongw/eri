import Foundation

enum Router {
  static func open(url: URL, config: Config) throws {
    let target = config.match(url: url)
    try launch(target: target, url: url)
  }

  private static func launch(target: Config.BrowserRef, url: URL) throws {
    var passthrough: [String] = []
    // Safari has no CLI/URL-scheme way to select a profile, so silently
    // drop it rather than letting the --args path swallow the URL.
    if let profile = target.profile, target.browser != "com.apple.Safari" {
      let resolved =
        target.browser == "com.google.Chrome"
        ? ChromeProfileResolver.resolve(profile)
        : profile
      if let resolved {
        passthrough.append("--profile-directory=\(resolved)")
      }
    }
    if let extra = target.args {
      passthrough.append(contentsOf: extra)
    }

    var arguments: [String] = []
    if passthrough.isEmpty {
      arguments += ["-b", target.browser, url.absoluteString]
    } else {
      // -n forces a fresh launch; without it, `open` skips --args entirely
      // when the target is already running, dropping both the profile flag
      // and the URL. Chromium's single-instance handler IPCs the args to
      // the existing process, so no duplicate sticks around.
      arguments += ["-n", "-b", target.browser, "--args"]
      arguments += passthrough
      arguments.append(url.absoluteString)
    }

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    process.arguments = arguments
    try process.run()
    process.waitUntilExit()

    if process.terminationStatus != 0 {
      throw RouterError.openFailed(bundleId: target.browser, status: process.terminationStatus)
    }
  }
}

enum RouterError: LocalizedError {
  case openFailed(bundleId: String, status: Int32)

  var errorDescription: String? {
    switch self {
    case .openFailed(let bundleId, let status):
      return "open(1) failed for \(bundleId): exit \(status)"
    }
  }
}
