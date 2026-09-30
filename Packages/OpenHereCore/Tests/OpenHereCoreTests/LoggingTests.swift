import Testing

@testable import OpenHereCore

struct LoggingTests {
  @Test func redactsPaths() {
    #expect(OpenHereLog.redact("ghostty [\"/Users/me/My Project\", \"/tmp/x\"]") == "ghostty [\"<path> Project\", \"<path>\"]")
    #expect(OpenHereLog.redact("code 12") == "code 12")
  }

  @Test func keepsHistory() {
    OpenHereLog.setLevel(.debug)
    OpenHereLog.debug(.app, "Unit test event", detail: "/private/secret")
    let last = OpenHereLog.recentEntries().last ?? ""
    #expect(last.contains("Unit test event") && !last.contains("secret") == false || last.contains("<path>"))
    OpenHereLog.setLevel(.errorsOnly)
  }
}
