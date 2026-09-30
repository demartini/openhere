import AppKit
import OpenHereCore
import SwiftUI

struct ApplicationIcon: View {
  let url: URL?
  var size: CGFloat = 20

  var body: some View {
    if let url {
      Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
        .resizable().frame(width: size, height: size)
    } else {
      Image(systemName: "questionmark.app.dashed")
        .frame(width: size, height: size).foregroundStyle(.secondary)
    }
  }
}
