import Foundation
import OpenHereCore

enum ProjectLinks {
  static let repository = URL(string: "https://github.com/\(OpenHereConstants.repository)")!
  static let releases = repository.appending(path: "releases")
  static let issues = repository.appending(path: "issues")
  static let newIssue = repository.appending(path: "issues/new/choose")
  static let license = repository.appending(path: "blob/main/LICENSE")
  static let help = repository.appending(path: "blob/main/README.md")
}
