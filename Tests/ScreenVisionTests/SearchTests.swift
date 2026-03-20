import XCTest
@testable import ScreenVisionLib

final class SearchTests: XCTestCase {

    let elements = [
        TextElement(text: "매출 리포트", x: 100, y: 100, w: 80, h: 20, confidence: 1.0),
        TextElement(text: "Submit", x: 200, y: 200, w: 60, h: 20, confidence: 0.95),
        TextElement(text: "OK", x: 300, y: 300, w: 30, h: 20, confidence: 1.0),
        TextElement(text: "Cancel Order", x: 400, y: 400, w: 100, h: 20, confidence: 0.9),
    ]

    // MARK: - Exact match

    func testExactMatchCaseInsensitive() {
        let match = findMatch(query: "ok", in: elements)
        XCTAssertNotNil(match)
        XCTAssertEqual(match!.text, "OK")
    }

    func testExactMatchExact() {
        let match = findMatch(query: "Submit", in: elements)
        XCTAssertNotNil(match)
        XCTAssertEqual(match!.text, "Submit")
    }

    func testExactMatchKorean() {
        let match = findMatch(query: "매출 리포트", in: elements)
        XCTAssertNotNil(match)
        XCTAssertEqual(match!.x, 100)
    }

    // MARK: - Partial match

    func testPartialMatch() {
        let match = findMatch(query: "Cancel", in: elements)
        XCTAssertNotNil(match)
        XCTAssertEqual(match!.text, "Cancel Order")
    }

    func testPartialMatchCaseInsensitive() {
        let match = findMatch(query: "cancel", in: elements)
        XCTAssertNotNil(match)
        XCTAssertEqual(match!.text, "Cancel Order")
    }

    func testPartialMatchSubstring() {
        let match = findMatch(query: "Order", in: elements)
        XCTAssertNotNil(match)
        XCTAssertEqual(match!.text, "Cancel Order")
    }

    func testPartialMatchKorean() {
        let match = findMatch(query: "매출", in: elements)
        XCTAssertNotNil(match)
        XCTAssertEqual(match!.text, "매출 리포트")
    }

    // MARK: - Exact preferred over partial

    func testExactPreferredOverPartial() {
        let elements = [
            TextElement(text: "OK Button", x: 100, y: 100, w: 80, h: 20, confidence: 1.0),
            TextElement(text: "OK", x: 200, y: 200, w: 30, h: 20, confidence: 1.0),
        ]
        let match = findMatch(query: "OK", in: elements)
        XCTAssertNotNil(match)
        XCTAssertEqual(match!.text, "OK")  // exact match, not "OK Button"
        XCTAssertEqual(match!.x, 200)
    }

    // MARK: - No match

    func testNoMatch() {
        let match = findMatch(query: "NonExistent", in: elements)
        XCTAssertNil(match)
    }

    func testNoMatchEmpty() {
        let match = findMatch(query: "anything", in: [])
        XCTAssertNil(match)
    }

    func testEmptyQuery() {
        // Empty query: exact match requires "" == text (no match),
        // partial match requires text.contains("") which is always true
        // But lowercased empty string matching depends on implementation
        let match = findMatch(query: "", in: elements)
        // Behavior: empty string partial matches first element or nil — either is acceptable
        // Just verify it doesn't crash
        _ = match
    }
}
