import Foundation
import Testing

@testable import OpenHereCore

struct SharedStorageTests {
  @Test func usesTheRealHomeDirectory() {
    let directory = SharedStorage.directory
    #expect(directory.path.hasPrefix("/"))
    #expect(directory.path.hasSuffix("/Library/Application Support/OpenHere"))
    #expect(!directory.path.contains("/Library/Containers/"))
  }

  @Test func extensionEntitlementMatchesTheStorageFolder() throws {
    // The sandbox exception in the extension must cover exactly the folder the app writes to.
    let root = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent()
    let entitlements = root.appending(path: "OpenHereFinderExtension/OpenHereFinderExtension.entitlements")
    let data = try Data(contentsOf: entitlements)
    let plist = try #require(
      try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
    let paths = try #require(
      plist["com.apple.security.temporary-exception.files.home-relative-path.read-only"] as? [String])
    #expect(paths.contains("/" + SharedStorage.relativePath + "/"))
    #expect(plist["com.apple.security.application-groups"] == nil)
  }
}
