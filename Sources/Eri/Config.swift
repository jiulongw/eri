import Foundation

struct Config {
  let `default`: BrowserRef?
  let rule: [Rule]?
  let browsers: [String: BrowserRef]?

  struct BrowserRef {
    let browser: String
    let profile: String?
    let args: [String]?
  }

  struct Rule {
    let host: String?
    let hostRegex: String?
    let urlRegex: String?
    let domain: String?
    let browser: String
    let profile: String?
    let args: [String]?
  }

  static func load() throws -> Config {
    let url = try resolveConfigPath()
    let text = try String(contentsOf: url, encoding: .utf8)
    return try Config.decode(text: text, path: url.path)
  }

  static let defaultScaffold = """
    [default]
    browser = "com.apple.Safari"

    """

  private static func resolveConfigPath() throws -> URL {
    let fm = FileManager.default
    let home = fm.homeDirectoryForCurrentUser
    let candidates = [
      home.appendingPathComponent(".config/eri/config.toml"),
      home.appendingPathComponent("Library/Application Support/Eri/config.toml"),
    ]
    for url in candidates where fm.fileExists(atPath: url.path) {
      return url
    }
    let primary = candidates[0]
    do {
      try fm.createDirectory(
        at: primary.deletingLastPathComponent(),
        withIntermediateDirectories: true
      )
      try defaultScaffold.write(to: primary, atomically: true, encoding: .utf8)
    } catch {
      throw ConfigError.scaffoldFailed(path: primary.path, underlying: error)
    }
    return primary
  }

  func match(url: URL) -> BrowserRef {
    if let rules = rule {
      for r in rules where r.matches(url: url) {
        return resolve(browser: r.browser, profile: r.profile, args: r.args)
      }
    }
    return defaultTarget()
  }

  func defaultTarget() -> BrowserRef {
    if let d = self.default {
      return resolve(browser: d.browser, profile: d.profile, args: d.args)
    }
    return BrowserRef(browser: "com.apple.Safari", profile: nil, args: nil)
  }

  // Look up `ref` in the [browsers] table; on hit, the table entry supplies
  // browser+profile and rule-level args are appended after browser-level
  // args. On miss, treat `ref` as a bundle id and use the caller's own
  // profile/args (the inline form).
  private func resolve(browser ref: String, profile: String?, args: [String]?) -> BrowserRef {
    if let def = browsers?[ref] {
      let merged = (def.args ?? []) + (args ?? [])
      return BrowserRef(
        browser: def.browser,
        profile: def.profile,
        args: merged.isEmpty ? nil : merged
      )
    }
    return BrowserRef(browser: ref, profile: profile, args: args)
  }
}

extension Config.Rule {
  func matches(url: URL) -> Bool {
    let absolute = url.absoluteString
    if let pattern = urlRegex, regexMatches(pattern: pattern, in: absolute) {
      return true
    }
    guard let host = url.host?.lowercased() else { return false }
    if let pattern = hostRegex, regexMatches(pattern: pattern, in: host) {
      return true
    }
    if let d = domain?.lowercased() {
      return host == d || host.hasSuffix("." + d)
    }
    if let glob = self.host?.lowercased() {
      return globMatches(pattern: glob, host: host)
    }
    return false
  }

  private func regexMatches(pattern: String, in string: String) -> Bool {
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
    let range = NSRange(string.startIndex..., in: string)
    return regex.firstMatch(in: string, range: range) != nil
  }

  private func globMatches(pattern: String, host: String) -> Bool {
    let escaped = NSRegularExpression.escapedPattern(for: pattern)
    let regexPattern = "^" + escaped.replacingOccurrences(of: "\\*", with: ".*") + "$"
    return regexMatches(pattern: regexPattern, in: host)
  }
}

enum ConfigError: LocalizedError {
  case parseFailed(path: String, underlying: Error)
  case scaffoldFailed(path: String, underlying: Error)

  var errorDescription: String? {
    switch self {
    case .parseFailed(let path, let underlying):
      return "Failed to parse \(path): \(underlying.localizedDescription)"
    case .scaffoldFailed(let path, let underlying):
      return "Failed to write default config to \(path): \(underlying.localizedDescription)"
    }
  }
}
