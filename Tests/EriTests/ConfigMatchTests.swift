import Foundation
import Testing

@testable import Eri

@Suite struct ConfigMatchTests {
  @Test func fallsBackToDefaultWhenNoRuleMatches() {
    let config = Config(
      default: .init(browser: "com.apple.Safari", profile: nil, args: nil),
      rule: [hostRule("github.com", browser: "com.google.Chrome")],
      browsers: nil
    )
    let target = config.match(url: URL(string: "https://example.com")!)
    #expect(target.browser == "com.apple.Safari")
  }

  @Test func defaultsToSafariWhenNoDefaultConfigured() {
    let config = Config(default: nil, rule: nil, browsers: nil)
    let target = config.match(url: URL(string: "https://example.com")!)
    #expect(target.browser == "com.apple.Safari")
  }

  @Test func hostGlobMatchesSubdomainWildcard() {
    let config = Config(
      default: nil,
      rule: [hostRule("*.work.example.com", browser: "com.google.Chrome", profile: "Work")],
      browsers: nil
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
      ],
      browsers: nil
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
      domain: nil,
      browser: "org.mozilla.firefox",
      profile: nil,
      args: nil
    )
    let config = Config(default: nil, rule: [rule], browsers: nil)
    let target = config.match(url: URL(string: "http://localhost:3000/foo")!)
    #expect(target.browser == "org.mozilla.firefox")
  }

  @Test func hostMatchIsCaseInsensitive() {
    let config = Config(
      default: nil,
      rule: [hostRule("GitHub.com", browser: "com.google.Chrome")],
      browsers: nil
    )
    let target = config.match(url: URL(string: "https://GITHUB.COM")!)
    #expect(target.browser == "com.google.Chrome")
  }

  @Test func domainMatchesExactHost() {
    let config = Config(
      default: nil,
      rule: [domainRule("google.com", browser: "com.google.Chrome")],
      browsers: nil
    )
    let target = config.match(url: URL(string: "https://google.com/search")!)
    #expect(target.browser == "com.google.Chrome")
  }

  @Test func domainMatchesSubdomains() {
    let config = Config(
      default: .init(browser: "com.apple.Safari", profile: nil, args: nil),
      rule: [domainRule("google.com", browser: "com.google.Chrome")],
      browsers: nil
    )
    #expect(
      config.match(url: URL(string: "https://www.google.com")!).browser == "com.google.Chrome")
    #expect(
      config.match(url: URL(string: "https://mail.foo.google.com")!).browser == "com.google.Chrome")
  }

  @Test func domainRejectsSuffixLookalikes() {
    let config = Config(
      default: .init(browser: "com.apple.Safari", profile: nil, args: nil),
      rule: [domainRule("google.com", browser: "com.google.Chrome")],
      browsers: nil
    )
    // evilgoogle.com is NOT a subdomain of google.com — must fall through to default.
    let target = config.match(url: URL(string: "https://evilgoogle.com")!)
    #expect(target.browser == "com.apple.Safari")
  }

  @Test func domainMatchIsCaseInsensitive() {
    let config = Config(
      default: nil,
      rule: [domainRule("Google.com", browser: "com.google.Chrome")],
      browsers: nil
    )
    let target = config.match(url: URL(string: "https://WWW.GOOGLE.COM")!)
    #expect(target.browser == "com.google.Chrome")
  }

  private func hostRule(
    _ host: String, browser: String, profile: String? = nil
  ) -> Config.Rule {
    Config.Rule(
      host: host, hostRegex: nil, urlRegex: nil, domain: nil,
      browser: browser, profile: profile, args: nil
    )
  }

  private func domainRule(
    _ domain: String, browser: String, profile: String? = nil
  ) -> Config.Rule {
    Config.Rule(
      host: nil, hostRegex: nil, urlRegex: nil, domain: domain,
      browser: browser, profile: profile, args: nil
    )
  }
}
