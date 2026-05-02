import Foundation

enum ChromeProfileResolver {
  private static let localStateRelativePath =
    "Library/Application Support/Google/Chrome/Local State"

  // Resolves a user-supplied profile token to the directory name Chrome's
  // --profile-directory flag expects. Lookup order: directory name → signed-in
  // email (user_name) → display name (name). Returns nil when no entry matches,
  // which signals the caller to omit the flag and let Chrome fall back to its
  // default profile.
  static func resolve(_ requested: String) -> String? {
    guard let infoCache = loadInfoCache() else {
      return requested
    }
    if infoCache[requested] != nil {
      return requested
    }
    if let dir = match(in: infoCache, key: "user_name", value: requested) {
      return dir
    }
    if let dir = match(in: infoCache, key: "name", value: requested) {
      return dir
    }
    return nil
  }

  private static func loadInfoCache() -> [String: [String: Any]]? {
    let url = FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent(localStateRelativePath)
    guard let data = try? Data(contentsOf: url),
      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let profile = json["profile"] as? [String: Any],
      let infoCache = profile["info_cache"] as? [String: [String: Any]]
    else {
      return nil
    }
    return infoCache
  }

  private static func match(in cache: [String: [String: Any]], key: String, value: String)
    -> String?
  {
    for (dir, info) in cache {
      if let candidate = info[key] as? String,
        candidate.caseInsensitiveCompare(value) == .orderedSame
      {
        return dir
      }
    }
    return nil
  }
}
