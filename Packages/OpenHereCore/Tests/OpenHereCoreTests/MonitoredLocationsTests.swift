import Foundation
import Testing

@testable import OpenHereCore

struct MonitoredLocationsTests {
  private func url(_ path: String) -> URL { URL(fileURLWithPath: path) }

  @Test func includesVolumesThatMacOSReportsAsHidden() {
    // Real output on a Mac with an external disk that Finder shows in its sidebar.
    let visible = [url("/"), url("/Users/me/OrbStack")]
    let all = [
      url("/"), url("/System/Volumes/VM"), url("/System/Volumes/Preboot"), url("/Volumes/Demartini"),
      url("/Users/me/OrbStack"), url("/Library/Developer/CoreSimulator/Volumes/iOS_24A434"),
      url("/private/var/run/com.apple.security.cryptexd/mnt/x"),
    ]
    let result = MonitoredLocations.urls(visibleVolumes: visible, allVolumes: all)
    #expect(result.contains(url("/")))
    #expect(result.contains(url("/Volumes/Demartini")))
    #expect(result.contains(url("/Users/me/OrbStack")))
    #expect(!result.contains(url("/System/Volumes/VM")))
    #expect(!result.contains(url("/Library/Developer/CoreSimulator/Volumes/iOS_24A434")))
    #expect(result.count == 3)
  }

  @Test func alwaysWatchesTheStartupDisk() {
    #expect(MonitoredLocations.urls(visibleVolumes: [], allVolumes: []) == [url("/")])
  }

  @Test func currentAlwaysContainsTheStartupDisk() {
    #expect(MonitoredLocations.current().contains(url("/")))
  }
}
