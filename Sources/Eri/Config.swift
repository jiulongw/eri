import Foundation
import TOMLKit

struct Config: Decodable {
  let `default`: BrowserRef?
  let rule: [Rule]?

  struct BrowserRef: Decodable {
    let browser: String
    let profile: String?
    let args: [String]?
  }

  struct Rule: Decodable {
    let host: String?
    let hostRegex: String?
    let urlRegex: String?
    let browser: String
    let profile: String?
    let args: [String]?

    enum CodingKeys: String, CodingKey {
      case host
      case hostRegex = "host_regex"
      case urlRegex = "url_regex"
      case browser
      case profile
      case args
    }
  }

  static func load() throws -> Config {
    let url = try resolveConfigPath()
    let text = try String(contentsOf: url, encoding: .utf8)
    do {
      return try TOMLDecoder().decode(Config.self, from: text)
    } catch {
      throw ConfigError.parseFailed(path: url.path, underlying: error)
    }
  }

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
    throw ConfigError.notFound(searched: candidates.map { $0.path })
  }

  func match(url: URL) -> BrowserRef {
    if let rules = rule {
      for r in rules where r.matches(url: url) {
        return BrowserRef(browser: r.browser, profile: r.profile, args: r.args)
      }
    }
    return self.default ?? BrowserRef(browser: "com.apple.Safari", profile: nil, args: nil)
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
  case notFound(searched: [String])
  case parseFailed(path: String, underlying: Error)

  var errorDescription: String? {
    switch self {
    case .notFound(let paths):
      return "No config file found. Searched:\n" + paths.joined(separator: "\n")
    case .parseFailed(let path, let underlying):
      return "Failed to parse \(path): \(underlying.localizedDescription)"
    }
  }
}
