import CTomlPlusPlus
import Foundation

enum TomlDecodeError: LocalizedError {
  case parse(message: String, line: Int, column: Int)
  case typeMismatch(path: String, expected: String)
  case missingField(path: String)

  var errorDescription: String? {
    switch self {
    case .parse(let message, let line, let column):
      return "TOML parse error at line \(line), column \(column): \(message)"
    case .typeMismatch(let path, let expected):
      return "Expected \(expected) at \(path)"
    case .missingField(let path):
      return "Missing required field at \(path)"
    }
  }
}

final class TomlDocument {
  let root: OpaquePointer

  init(text: String) throws {
    var errPtr: OpaquePointer?
    let parsed: OpaquePointer? = text.withCString { cstr in
      eri_toml_parse(cstr, strlen(cstr), &errPtr)
    }
    if let parsed {
      self.root = parsed
      return
    }
    let message =
      errPtr.flatMap { eri_toml_error_message($0).map(String.init(cString:)) } ?? "unknown error"
    let line = errPtr.map { Int(eri_toml_error_line($0)) } ?? 0
    let column = errPtr.map { Int(eri_toml_error_column($0)) } ?? 0
    if let errPtr { eri_toml_error_free(errPtr) }
    throw TomlDecodeError.parse(message: message, line: line, column: column)
  }

  deinit { eri_toml_node_free(root) }
}

private func tomlString(_ node: OpaquePointer, path: String) throws -> String {
  var ptr: UnsafePointer<CChar>?
  var len: Int = 0
  guard eri_toml_as_string(node, &ptr, &len), let ptr else {
    throw TomlDecodeError.typeMismatch(path: path, expected: "string")
  }
  let bytes = UnsafeBufferPointer(
    start: UnsafeRawPointer(ptr).assumingMemoryBound(to: UInt8.self), count: len)
  return String(decoding: bytes, as: UTF8.self)
}

private func tomlStringArray(_ node: OpaquePointer, path: String) throws -> [String] {
  guard eri_toml_is_array(node) else {
    throw TomlDecodeError.typeMismatch(path: path, expected: "array")
  }
  let count = eri_toml_array_size(node)
  var out: [String] = []
  out.reserveCapacity(count)
  for i in 0..<count {
    guard let item = eri_toml_array_at(node, i) else { continue }
    out.append(try tomlString(item, path: "\(path)[\(i)]"))
  }
  return out
}

private func optionalString(_ table: OpaquePointer, _ key: String, path: String) throws -> String? {
  guard let v = eri_toml_table_get(table, key) else { return nil }
  return try tomlString(v, path: "\(path).\(key)")
}

private func requiredString(_ table: OpaquePointer, _ key: String, path: String) throws -> String {
  guard let v = eri_toml_table_get(table, key) else {
    throw TomlDecodeError.missingField(path: "\(path).\(key)")
  }
  return try tomlString(v, path: "\(path).\(key)")
}

private func optionalStringArray(_ table: OpaquePointer, _ key: String, path: String) throws
  -> [String]?
{
  guard let v = eri_toml_table_get(table, key) else { return nil }
  return try tomlStringArray(v, path: "\(path).\(key)")
}

private func decodeBrowserRef(_ node: OpaquePointer, path: String) throws -> Config.BrowserRef {
  guard eri_toml_is_table(node) else {
    throw TomlDecodeError.typeMismatch(path: path, expected: "table")
  }
  return Config.BrowserRef(
    browser: try requiredString(node, "browser", path: path),
    profile: try optionalString(node, "profile", path: path),
    args: try optionalStringArray(node, "args", path: path)
  )
}

private func decodeRule(_ node: OpaquePointer, path: String) throws -> Config.Rule {
  guard eri_toml_is_table(node) else {
    throw TomlDecodeError.typeMismatch(path: path, expected: "table")
  }
  return Config.Rule(
    host: try optionalString(node, "host", path: path),
    hostRegex: try optionalString(node, "host_regex", path: path),
    urlRegex: try optionalString(node, "url_regex", path: path),
    domain: try optionalString(node, "domain", path: path),
    browser: try requiredString(node, "browser", path: path),
    profile: try optionalString(node, "profile", path: path),
    args: try optionalStringArray(node, "args", path: path)
  )
}

extension Config {
  static func decode(text: String, path: String) throws -> Config {
    do {
      let doc = try TomlDocument(text: text)
      let root = doc.root

      var defaultRef: BrowserRef? = nil
      if let node = eri_toml_table_get(root, "default") {
        defaultRef = try decodeBrowserRef(node, path: "default")
      }

      var rules: [Rule]? = nil
      if let node = eri_toml_table_get(root, "rule") {
        guard eri_toml_is_array(node) else {
          throw TomlDecodeError.typeMismatch(path: "rule", expected: "array of tables")
        }
        let count = eri_toml_array_size(node)
        var collected: [Rule] = []
        collected.reserveCapacity(count)
        for i in 0..<count {
          guard let item = eri_toml_array_at(node, i) else { continue }
          collected.append(try decodeRule(item, path: "rule[\(i)]"))
        }
        rules = collected
      }

      var browsers: [String: BrowserRef]? = nil
      if let node = eri_toml_table_get(root, "browsers") {
        guard eri_toml_is_table(node) else {
          throw TomlDecodeError.typeMismatch(path: "browsers", expected: "table")
        }
        let count = eri_toml_table_size(node)
        var map: [String: BrowserRef] = [:]
        map.reserveCapacity(count)
        for i in 0..<count {
          var keyLen: Int = 0
          guard let keyPtr = eri_toml_table_key_at(node, i, &keyLen),
            let value = eri_toml_table_value_at(node, i)
          else { continue }
          let keyBytes = UnsafeBufferPointer(
            start: UnsafeRawPointer(keyPtr).assumingMemoryBound(to: UInt8.self),
            count: keyLen
          )
          let key = String(decoding: keyBytes, as: UTF8.self)
          map[key] = try decodeBrowserRef(value, path: "browsers.\(key)")
        }
        browsers = map
      }

      return Config(default: defaultRef, rule: rules, browsers: browsers)
    } catch let e as TomlDecodeError {
      throw ConfigError.parseFailed(path: path, underlying: e)
    }
  }
}
