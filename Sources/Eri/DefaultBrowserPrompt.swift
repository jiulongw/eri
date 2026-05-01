import AppKit

enum DefaultBrowserPrompt {
  private static let skipKey = "EriSkipDefaultBrowserPrompt"
  private static let probeURL = URL(string: "https://example.com")!

  static func runIfNeeded() {
    guard let bundleId = Bundle.main.bundleIdentifier else { return }
    if UserDefaults.standard.bool(forKey: skipKey) { return }
    if isDefaultBrowser(bundleId: bundleId) { return }
    prompt(bundleId: bundleId)
  }

  private static func isDefaultBrowser(bundleId: String) -> Bool {
    guard let appURL = NSWorkspace.shared.urlForApplication(toOpen: probeURL),
      let id = Bundle(url: appURL)?.bundleIdentifier
    else {
      return false
    }
    return id == bundleId
  }

  private static func prompt(bundleId: String) {
    NSApp.activate(ignoringOtherApps: true)

    let alert = NSAlert()
    alert.messageText = "Set Eri as your default web browser?"
    alert.informativeText = """
      Eri is a link router — it does not display web pages itself. To do its job, macOS needs to send all http and https links to Eri first; Eri then forwards each link to the real browser (Safari, Chrome with a specific profile, …) configured in ~/.config/eri/config.toml.

      macOS will ask you to confirm the change.
      """
    alert.alertStyle = .informational
    alert.addButton(withTitle: "Set as Default")
    alert.addButton(withTitle: "Not Now")
    alert.addButton(withTitle: "Don't Ask Again")

    switch alert.runModal() {
    case .alertFirstButtonReturn:
      setAsDefault()
    case .alertThirdButtonReturn:
      UserDefaults.standard.set(true, forKey: skipKey)
    default:
      break
    }
  }

  private static func setAsDefault() {
    let appURL = Bundle.main.bundleURL
    let workspace = NSWorkspace.shared
    workspace.setDefaultApplication(at: appURL, toOpenURLsWithScheme: "http")
    workspace.setDefaultApplication(at: appURL, toOpenURLsWithScheme: "https")
  }
}
