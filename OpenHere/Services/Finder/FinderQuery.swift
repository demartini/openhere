import AppKit
import Foundation
import OpenHereCore

/// Asks Finder what is selected / shown. This is the only place that runs AppleScript, and the
/// script is a constant: no user data is ever interpolated into it.
@MainActor
struct FinderQuery {
  enum QueryError: LocalizedError {
    case notAuthorized
    case failed(code: Int)

    var errorDescription: String? {
      switch self {
      case .notAuthorized:
        String(
          localized:
            "OpenHere is not allowed to control Finder. Enable it in System Settings › Privacy & Security › Automation."
        )
      case .failed(let code):
        String(localized: "Finder did not answer (error \(code)).")
      }
    }
  }

  /// Returns `S` + selected paths, `W` + window folder, or `N` when Finder has nothing to offer.
  private static let source = """
    tell application "Finder"
      try
        set selectedItems to (selection as alias list)
      on error
        set selectedItems to {}
      end try
      if (count of selectedItems) > 0 then
        set output to {"S"}
        repeat with anItem in selectedItems
          set end of output to POSIX path of anItem
        end repeat
        return output
      end if
      try
        return {"W", POSIX path of ((target of front Finder window) as alias)}
      on error
        return {"N"}
      end try
    end tell
    """

  static let notAuthorizedCode = -1743

  func currentContext() throws -> FinderContext {
    var errorInfo: NSDictionary?
    let descriptor = NSAppleScript(source: Self.source)?.executeAndReturnError(&errorInfo)

    if let errorInfo {
      let code = (errorInfo[NSAppleScript.errorNumber] as? Int) ?? 0
      OpenHereLog.error(.permissions, "Finder query failed", detail: "code \(code)")
      throw code == Self.notAuthorizedCode ? QueryError.notAuthorized : QueryError.failed(code: code)
    }
    guard let descriptor, descriptor.numberOfItems >= 1 else { return FinderContext() }

    let items = (1...descriptor.numberOfItems).compactMap { descriptor.atIndex($0)?.stringValue }
    guard let marker = items.first else { return FinderContext() }
    let paths = items.dropFirst().map { URL(fileURLWithPath: $0) }

    switch marker {
    case "S": return FinderContext(selection: paths)
    case "W": return FinderContext(windowDirectory: paths.first)
    default: return FinderContext()
    }
  }
}
