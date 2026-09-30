import Foundation

/// Which locations the Finder extension asks Finder to watch. Finder Sync only shows menus inside
/// the folders it was given, so every volume the user can browse needs an entry.
public enum MonitoredLocations {
  /// - Parameters:
  ///   - visibleVolumes: `mountedVolumeURLs(options: [.skipHiddenVolumes])`
  ///   - allVolumes: `mountedVolumeURLs(options: [])`
  ///
  /// `skipHiddenVolumes` alone is not enough: macOS reports some volumes that Finder shows in its
  /// sidebar (an external disk, for example) as hidden, so they would never get a menu. Everything
  /// mounted under `/Volumes` is therefore added, while system volumes (`/System/Volumes/VM`,
  /// cryptex and simulator images …) stay out.
  public static func urls(visibleVolumes: [URL], allVolumes: [URL]) -> Set<URL> {
    var result: Set<URL> = [URL(fileURLWithPath: "/")]
    result.formUnion(visibleVolumes)
    result.formUnion(allVolumes.filter { $0.path.hasPrefix("/Volumes/") })
    return result
  }

  public static func current(fileManager: FileManager = .default) -> Set<URL> {
    urls(
      visibleVolumes: fileManager.mountedVolumeURLs(
        includingResourceValuesForKeys: nil, options: [.skipHiddenVolumes]) ?? [],
      allVolumes: fileManager.mountedVolumeURLs(includingResourceValuesForKeys: nil, options: []) ?? [])
  }
}
