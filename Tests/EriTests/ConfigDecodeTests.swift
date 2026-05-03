import Foundation
import Testing

@testable import Eri

@Suite struct ConfigDecodeTests {
  private static let exampleConfigURL: URL = {
    URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .appendingPathComponent("config.example.toml")
  }()

  @Test func parsesShippedExampleConfig() throws {
    let text = try String(contentsOf: Self.exampleConfigURL, encoding: .utf8)
    let config = try Config.decode(text: text, path: Self.exampleConfigURL.path)

    #expect(config.default?.browser == "safari")
    #expect(config.browsers?["safari"]?.browser == "com.apple.Safari")
    #expect(config.browsers?["chrome-personal"]?.profile == "Personal")
    #expect(config.browsers?["chrome-work"]?.profile == "Work")
    #expect(config.rule?.count == 4)
    #expect(config.rule?.first?.host == "github.com")
    #expect(config.rule?.first?.browser == "chrome-personal")
    #expect(config.rule?[1].domain == "work.example.com")
    #expect(config.rule?.last?.urlRegex != nil)
    #expect(config.rule?.last?.browser == "org.mozilla.firefox")
  }

  @Test func exampleConfigRoutesGithubThroughChromePersonal() throws {
    let text = try String(contentsOf: Self.exampleConfigURL, encoding: .utf8)
    let config = try Config.decode(text: text, path: Self.exampleConfigURL.path)

    let target = config.match(url: URL(string: "https://github.com/anthropics/claude-code")!)
    #expect(target.browser == "com.google.Chrome")
    #expect(target.profile == "Personal")
  }

  @Test func decodesArgsArray() throws {
    let text = """
      [browsers.chrome]
      browser = "com.google.Chrome"
      args = ["--incognito", "--new-window"]
      """
    let config = try Config.decode(text: text, path: "<inline>")
    #expect(config.browsers?["chrome"]?.args == ["--incognito", "--new-window"])
  }

  @Test func malformedTomlThrowsParseFailed() {
    let text = "[default\nbrowser = \"x\""
    #expect(throws: ConfigError.self) {
      _ = try Config.decode(text: text, path: "<inline>")
    }
  }

  @Test func nonStringBrowserThrowsParseFailed() {
    let text = """
      [default]
      browser = 42
      """
    #expect(throws: ConfigError.self) {
      _ = try Config.decode(text: text, path: "<inline>")
    }
  }
}
