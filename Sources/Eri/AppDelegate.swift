import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
  private var config: Config?
  private var configError: Error?
  private var didReceiveURL = false

  func applicationWillFinishLaunching(_ notification: Notification) {
    NSAppleEventManager.shared().setEventHandler(
      self,
      andSelector: #selector(handleGetURL(event:replyEvent:)),
      forEventClass: AEEventClass(kInternetEventClass),
      andEventID: AEEventID(kAEGetURL)
    )
    loadConfig()
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    // If macOS launched us with a URL, the GetURL Apple Event has already
    // fired by the time we get here; otherwise treat this as a manual
    // launch: offer to set Eri as the default browser, then forward to
    // the configured default browser (Eri itself has no UI to show).
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
      guard let self = self, !self.didReceiveURL else { return }
      DefaultBrowserPrompt.runIfNeeded()
      self.launchDefaultBrowser()
      self.scheduleQuit()
    }
  }

  private func launchDefaultBrowser() {
    guard let config = config else { return }
    do {
      try Router.openDefault(config: config)
    } catch {
      Notifier.shared.error(
        title: "Eri",
        body: "Failed to launch default browser: \(error.localizedDescription)"
      )
    }
  }

  private func loadConfig() {
    do {
      config = try Config.load()
    } catch {
      configError = error
      Notifier.shared.error(
        title: "Eri config error",
        body: error.localizedDescription
      )
    }
  }

  @objc func handleGetURL(event: NSAppleEventDescriptor, replyEvent: NSAppleEventDescriptor) {
    didReceiveURL = true
    defer { scheduleQuit() }

    guard let urlString = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
      let url = URL(string: urlString)
    else {
      Notifier.shared.error(title: "Eri", body: "Received an invalid URL.")
      return
    }

    guard let config = config else {
      Notifier.shared.error(
        title: "Eri",
        body: configError?.localizedDescription ?? "Configuration not loaded."
      )
      return
    }

    do {
      try Router.open(url: url, config: config)
    } catch {
      Notifier.shared.error(
        title: "Eri",
        body: "Failed to open \(url.absoluteString): \(error.localizedDescription)"
      )
    }
  }

  private func scheduleQuit() {
    // Brief grace period so any pending notification request is delivered
    // before the process exits.
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
      NSApp.terminate(nil)
    }
  }
}
