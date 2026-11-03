import XCTest
@testable import GitHub

final class UtilityTests: XCTestCase {
    func testTokenNormalizationAcceptsBearerAndTokenPrefixes() {
        XCTAssertEqual(TokenKeychain.normalizedToken("  ghp_example  "), "ghp_example")
        XCTAssertEqual(TokenKeychain.normalizedToken("Bearer ghp_example"), "ghp_example")
        XCTAssertEqual(TokenKeychain.normalizedToken("token ghp_example"), "ghp_example")
        XCTAssertEqual(TokenKeychain.normalizedToken("Token ghp_example"), "ghp_example")
    }

    func testTokenNormalizationKeepsTokenBodyIntact() {
        XCTAssertEqual(TokenKeychain.normalizedToken("Bearer  abc def "), "abc def")
        XCTAssertEqual(TokenKeychain.normalizedToken(""), "")
        XCTAssertEqual(TokenKeychain.normalizedToken("  \n "), "")
    }

    func testVersionComparisonHandlesDifferentComponentCounts() {
        XCTAssertTrue(AppVersion.isNewerVersion(latest: "2.0", current: "1.9.9"))
        XCTAssertTrue(AppVersion.isNewerVersion(latest: "1.2.1", current: "1.2"))
        XCTAssertFalse(AppVersion.isNewerVersion(latest: "1.2", current: "1.2.0"))
        XCTAssertFalse(AppVersion.isNewerVersion(latest: "1.1.9", current: "1.2"))
    }

    func testJSONFormatterPrettyPrintsAndSortsKeys() {
        let formatted = CodeFormatter.shared.format(code: #"{"z":1,"a":2}"#, fileName: "payload.JSON")

        XCTAssertEqual(formatted, """
        {
          "a" : 2,
          "z" : 1
        }
        """)
    }

    func testJSONFormatterReturnsOriginalInputWhenInvalid() {
        let invalidJSON = #"{"missing": }"#

        XCTAssertEqual(
            CodeFormatter.shared.format(code: invalidJSON, fileName: "broken.json"),
            invalidJSON
        )
    }

    func testYAMLFormattingIsNotModified() {
        let yaml = "items:\n  - one\n  - two\n"

        XCTAssertEqual(CodeFormatter.shared.format(code: yaml, fileName: "config.yaml"), yaml)
        XCTAssertFalse(CodeFormatter.shared.isFormatSupported(fileName: "config.yml"))
    }

    func testGenericFormatterRemovesTrailingWhitespaceAndRepeatedBlankLines() {
        let input = "first  \n\n\nsecond\t\n"
        let output = CodeFormatter.shared.format(code: input, fileName: "notes.txt")

        XCTAssertEqual(output, "first\n\nsecond\n")
    }

    func testISO8601ParserSupportsFractionalAndWholeSeconds() {
        XCTAssertNotNil(TimeFormatter.date(fromISO8601: "2026-10-29T10:20:30.123Z"))
        XCTAssertNotNil(TimeFormatter.date(fromISO8601: "2026-10-29T10:20:30Z"))
        XCTAssertNil(TimeFormatter.date(fromISO8601: "not-a-date"))
    }
}
