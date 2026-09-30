import FinderSync
import OpenHereCore

/// Reads the state Finder exposes to the extension. Only valid while a menu action runs.
struct FinderContextResolver {
  func currentContext() -> FinderContext {
    let controller = FIFinderSyncController.default()
    return FinderContext(
      selection: controller.selectedItemURLs() ?? [], windowDirectory: controller.targetedURL())
  }
}
