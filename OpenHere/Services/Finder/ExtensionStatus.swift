import AppKit
import FinderSync

enum FinderExtensionStatus {
  static var isEnabled: Bool { FIFinderSyncController.isExtensionEnabled }

  /// Opens the "Added Extensions" pane where the user enables OpenHere for Finder.
  static func openManagementInterface() {
    FIFinderSyncController.showExtensionManagementInterface()
  }
}
