import Foundation
import Testing

@testable import OpenHereCore

struct PathFormatterTests {
  @Test(arguments: [
    ("/Users/test/plain", "/Users/test/plain"),
    ("/Users/test/My Project", "/Users/test/My\\ Project"),
    ("/Users/test/\"weird\"/$folder", "/Users/test/\\\"weird\\\"/\\$folder"),
    ("/Users/test/it's", "/Users/test/it\\'s"),
    ("/tmp/a;rm -rf ~", "/tmp/a\\;rm\\ -rf\\ \\~"),
    ("/tmp/`id`", "/tmp/\\`id\\`"),
    ("/tmp/(a)&[b]{c}|<d>*?!#", "/tmp/\\(a\\)\\&\\[b\\]\\{c\\}\\|\\<d\\>\\*\\?\\!\\#"),
    ("/Users/test/café/日本語/😀", "/Users/test/café/日本語/😀"),
  ])
  func escapesShellCharacters(input: String, expected: String) {
    #expect(PathFormatter.shellEscape(input) == expected)
  }

  @Test func usesAnsiCQuotingForControlCharacters() {
    #expect(PathFormatter.shellEscape("/tmp/a\nb") == "$'/tmp/a\\nb'")
    #expect(PathFormatter.shellEscape("/tmp/a\tb'c\\d") == "$'/tmp/a\\tb\\'c\\\\d'")
    #expect(PathFormatter.shellEscape("/tmp/a\u{1}b") == "$'/tmp/a\\x01b'")
  }

  @Test func relativePaths() {
    let base = URL(fileURLWithPath: "/Users/a/Projects")
    #expect(
      PathFormatter.relativePath(of: URL(fileURLWithPath: "/Users/a/Projects/x/y.txt"), to: base) == "x/y.txt"
    )
    #expect(PathFormatter.relativePath(of: base, to: base) == ".")
    #expect(
      PathFormatter.relativePath(of: URL(fileURLWithPath: "/Users/a/Other/z"), to: base) == "../Other/z")
    #expect(
      PathFormatter.relativePath(of: URL(fileURLWithPath: "/Volumes/X/z"), to: base) == "../../../Volumes/X/z"
    )
  }

  @Test func formatsMultipleSelections() {
    let urls = [URL(fileURLWithPath: "/a b"), URL(fileURLWithPath: "/c")]
    #expect(PathFormatter.format(urls, style: .posix, relativeTo: nil) == "/a b\n/c")
    #expect(PathFormatter.format(urls, style: .escaped, relativeTo: nil) == "/a\\ b /c")
    #expect(
      PathFormatter.format(urls, style: .relative, relativeTo: URL(fileURLWithPath: "/"))
        == "a b\nc")
  }
}
