import Foundation
import Testing

@testable import Eri

@Suite struct ConfigMatchTests {
  @Test func fallsBackToDefaultWhenNoRuleMatches() {
    let config = Config(
      default: .init(browser: "com.apple.Safari", profile: nil, args: nil),
      rule: [hostRule("github.com", browser: "com.google.Chrome")]
    )
    let target = config.match(url: URL(string: "https://example.com")!)
    #expect(target.browser == "com.apple.Safari")
  }

  @Test func defaultsToSafariWhenNoDefaultConfigured() {
    let config = Config(default: nil, rule: nil)
    let target = config.match(url: URL(string: "https://example.com")!)
    #expect(target.browser == "com.apple.Safari")
  }

  @Test func hostGlobMatchesSubdomainWildcard() {
    let config = Config(
      default: nil,
      rule: [hostRule("*.work.example.com", browser: "com.google.Chrome", profile: "Work")]
    )
    let target = config.match(url: URL(string: "https://docs.work.example.com/x")!)
    #expect(target.browser == "com.google.Chrome")
    #expect(target.profile == "Work")
  }

  @Test func firstMatchingRuleWins() {
    let config = Config(
      default: nil,
      rule: [
        hostRule("github.com", browser: "com.google.Chrome", profile: "A"),
        hostRule("github.com", browser: "org.mozilla.firefox"),
      ]
    )
    let target = config.match(url: URL(string: "https://github.com/anthropics")!)
    #expect(target.browser == "com.google.Chrome")
    #expect(target.profile == "A")
  }

  @Test func urlRegexMatchesLocalhostWithPort() {
    let rule = Config.Rule(
      host: nil,
      hostRegex: nil,
      urlRegex: "^https?://localhost(:\\d+)?(/.*)?$",
      browser: "org.mozilla.firefox",
      profile: nil,
      args: nil
    )
    let config = Config(default: nil, rule: [rule])
    let target = config.match(url: URL(string: "http://localhost:3000/foo")!)
    #expect(target.browser == "org.mozilla.firefox")
  }

  @Test func hostMatchIsCaseInsensitive() {
    let config = Config(
      default: nil,
      rule: [hostRule("GitHub.com", browser: "com.google.Chrome")]
    )
    let target = config.match(url: URL(string: "https://GITHUB.COM")!)
    #expect(target.browser == "com.google.Chrome")
  }

  private func hostRule(
    _ host: String, browser: String, profile: String? = nil
  ) -> Config.Rule {
    Config.Rule(
      host: host, hostRegex: nil, urlRegex: nil,
      browser: browser, profile: profile, args: nil
    )
  }
}
