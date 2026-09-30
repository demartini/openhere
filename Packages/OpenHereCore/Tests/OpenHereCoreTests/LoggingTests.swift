import Testing

@testable import OpenHereCore

struct LoggingTests {
  @Test func redactsPaths() {
    #expect(
      OpenHereLog.redact("ghostty [\"/Users/me/My Project\", \"/tmp/x\"]")
        == "ghostty [\"<path> Project\", \"<path>\"]")
    #expect(OpenHereLog.redact("code 12") == "code 12")
  }

  @Test func historyKeepsEventsWithoutPaths() {
    OpenHereLog.setLevel(.debug)
    defer { OpenHereLog.setLevel(.errorsOnly) }
    OpenHereLog.debug(.app, "History test event", detail: "/private/secret/folder")

    // Other tests may log too, so look the entry up instead of assuming it is the last one.
    let entry = OpenHereLog.recentEntries().last { $0.contains("History test event") }
    #expect(entry != nil)
    #expect(entry?.contains("<path>") == true)
    #expect(entry?.contains("secret") == false)
  }
}
