import Foundation
import os

public enum LogCategory: String, Sendable, CaseIterable {
  case app = "OpenHere.app"
  case finderExtension = "OpenHere.FinderExtension"
  case launcher = "OpenHere.Launcher"
  case permissions = "OpenHere.Permissions"
}

/// Thin wrapper over `os.Logger` that honours the user's logging level. Free-form details are
/// logged with `.private` so paths never leave the machine in clear text.
public enum OpenHereLog {
  public static let subsystem = "dev.demartini.openhere"

  private static let level = OSAllocatedUnfairLock<LoggingLevel>(initialState: .errorsOnly)

  public static func setLevel(_ newValue: LoggingLevel) {
    level.withLock { $0 = newValue }
  }

  public static var currentLevel: LoggingLevel { level.withLock { $0 } }

  private static func logger(_ category: LogCategory) -> Logger {
    Logger(subsystem: subsystem, category: category.rawValue)
  }

  /// Recent events kept in memory for diagnostics (`OSLogStore` does not reliably return them).
  /// Paths are replaced so exports never contain private locations.
  private static let history = OSAllocatedUnfairLock<[String]>(initialState: [])
  private static let historyLimit = 500

  public static func recentEntries() -> [String] { history.withLock { $0 } }

  static func redact(_ text: String) -> String {
    text.replacingOccurrences(of: #"/[^\s"',\]\)]+"#, with: "<path>", options: .regularExpression)
  }

  private static func remember(_ level: String, _ category: LogCategory, _ event: String, _ detail: String) {
    let line = "\(Date().formatted(.iso8601)) [\(level)] [\(category.rawValue)] \(event) \(redact(detail))"
    history.withLock {
      $0.append(line)
      if $0.count > historyLimit { $0.removeFirst($0.count - historyLimit) }
    }
  }

  public static func debug(_ category: LogCategory, _ event: StaticString, detail: String = "") {
    guard currentLevel == .debug else { return }
    remember("debug", category, "\(event)", detail)
    logger(category).debug("\(event, privacy: .public) \(detail, privacy: .private)")
  }

  public static func error(_ category: LogCategory, _ event: StaticString, detail: String = "") {
    guard currentLevel != .disabled else { return }
    remember("error", category, "\(event)", detail)
    logger(category).error("\(event, privacy: .public) \(detail, privacy: .private)")
  }
}
