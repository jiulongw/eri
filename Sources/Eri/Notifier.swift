import Foundation
import UserNotifications
import os.log

final class Notifier {
  static let shared = Notifier()

  private let logger = Logger(subsystem: "cc.novacore.eri", category: "general")
  private var authorizationRequested = false

  func error(title: String, body: String) {
    logger.error("\(title, privacy: .public): \(body, privacy: .public)")
    send(title: title, body: body)
  }

  private func send(title: String, body: String) {
    let center = UNUserNotificationCenter.current()

    if !authorizationRequested {
      authorizationRequested = true
      center.requestAuthorization(options: [.alert]) { [weak self] _, error in
        if let error = error {
          self?.logger.error(
            "notification auth failed: \(error.localizedDescription, privacy: .public)")
        }
      }
    }

    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body

    let request = UNNotificationRequest(
      identifier: UUID().uuidString,
      content: content,
      trigger: nil
    )
    center.add(request) { [weak self] error in
      if let error = error {
        self?.logger.error(
          "notification deliver failed: \(error.localizedDescription, privacy: .public)")
      }
    }
  }
}
