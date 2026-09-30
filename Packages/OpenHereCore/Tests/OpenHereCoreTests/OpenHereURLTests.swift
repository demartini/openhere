import Foundation
import Testing

@testable import OpenHereCore

struct OpenHereURLTests {
  private static let nastyPaths = [
    "/Users/test/My Project/\"weird\"/$folder",
    "/tmp/a&path=/etc/passwd&token=x",
    "/tmp/100% + more=equal #hash ?query",
    "/tmp/line\nbreak/emoji😀/日本語",
    "/tmp/' ; rm -rf ~ ; '",
  ]

  @Test func roundTripsHostilePaths() throws {
    let request = OpenHereURL(action: .open(applicationID: "ghostty"), paths: Self.nastyPaths, token: "abc")
    let url = try #require(request.url)
    let decoded = try #require(OpenHereURL(url: url))
    #expect(decoded == request)
  }

  @Test func roundTripsDefaultAndSettings() throws {
    let a = OpenHereURL(action: .openDefault(kind: .editor), paths: ["/tmp"], token: "t")
    #expect(OpenHereURL(url: try #require(a.url)) == a)
    let b = OpenHereURL(action: .settings)
    #expect(OpenHereURL(url: try #require(b.url)) == b)
  }

  @Test func rejectsForeignAndMalformedURLs() {
    #expect(OpenHereURL(url: URL(string: "https://example.com")!) == nil)
    #expect(OpenHereURL(url: URL(string: "openhere://open")!) == nil)
    #expect(OpenHereURL(url: URL(string: "openhere://open?default=bogus")!) == nil)
    #expect(OpenHereURL(url: URL(string: "openhere://launch?app=x")!) == nil)
  }

  @Test func capsNumberOfPaths() throws {
    let many = (0..<500).map { "/tmp/\($0)" }
    let url = try #require(OpenHereURL(action: .open(applicationID: "x"), paths: many).url)
    #expect(OpenHereURL(url: url)?.paths.count == OpenHereURL.maximumPaths)
  }

  @Test func pathValidatorRejectsUnsafeInput() {
    let fs = FakeFileSystem(directories: ["/tmp"], files: ["/tmp/a.txt"])
    #expect(PathValidator.validatedURL("/tmp", fileSystem: fs) != nil)
    #expect(PathValidator.validatedURL("/tmp/a.txt", fileSystem: fs) != nil)
    #expect(PathValidator.validatedURL("/tmp/../tmp", fileSystem: fs)?.path == "/tmp")
    #expect(PathValidator.validatedURL("relative/path", fileSystem: fs) == nil)
    #expect(PathValidator.validatedURL("-rf", fileSystem: fs) == nil)
    #expect(PathValidator.validatedURL("/tmp/missing", fileSystem: fs) == nil)
    #expect(PathValidator.validatedURL("/tmp\0/x", fileSystem: fs) == nil)
    #expect(PathValidator.validatedURL("/" + String(repeating: "a", count: 5000), fileSystem: fs) == nil)
  }
}

struct RequestAuthenticatorTests {
  @Test func acceptsOnlyTheExactToken() {
    #expect(RequestAuthenticator.isTrusted(provided: "abc123", expected: "abc123"))
    #expect(!RequestAuthenticator.isTrusted(provided: "abc124", expected: "abc123"))
    #expect(!RequestAuthenticator.isTrusted(provided: "abc12", expected: "abc123"))
    #expect(!RequestAuthenticator.isTrusted(provided: nil, expected: "abc123"))
    #expect(!RequestAuthenticator.isTrusted(provided: "", expected: ""))
    #expect(!RequestAuthenticator.isTrusted(provided: nil, expected: nil))
  }
}
