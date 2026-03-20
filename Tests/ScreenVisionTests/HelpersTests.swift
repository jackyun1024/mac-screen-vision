import XCTest
@testable import ScreenVisionLib

final class HelpersTests: XCTestCase {

    // MARK: - parseRegion

    func testParseRegionValid() {
        let rect = parseRegion("100,200,800,600")
        XCTAssertNotNil(rect)
        XCTAssertEqual(rect!.origin.x, 100)
        XCTAssertEqual(rect!.origin.y, 200)
        XCTAssertEqual(rect!.width, 800)
        XCTAssertEqual(rect!.height, 600)
    }

    func testParseRegionDecimal() {
        let rect = parseRegion("10.5,20.3,100.7,50.9")
        XCTAssertNotNil(rect)
        XCTAssertEqual(rect!.origin.x, 10.5)
        XCTAssertEqual(rect!.origin.y, 20.3)
        XCTAssertEqual(rect!.width, 100.7)
        XCTAssertEqual(rect!.height, 50.9)
    }

    func testParseRegionZeros() {
        let rect = parseRegion("0,0,0,0")
        XCTAssertNotNil(rect)
        XCTAssertEqual(rect!, CGRect.zero)
    }

    func testParseRegionTooFewParts() {
        XCTAssertNil(parseRegion("100,200,300"))
    }

    func testParseRegionTooManyParts() {
        // 5 parts → only first 4 parsed, but count check requires exactly 4
        XCTAssertNil(parseRegion("1,2,3,4,5"))
    }

    func testParseRegionEmpty() {
        XCTAssertNil(parseRegion(""))
    }

    func testParseRegionInvalidChars() {
        XCTAssertNil(parseRegion("abc,def,ghi,jkl"))
    }

    func testParseRegionNegativeValues() {
        let rect = parseRegion("-10,-20,800,600")
        XCTAssertNotNil(rect)
        XCTAssertEqual(rect!.origin.x, -10)
        XCTAssertEqual(rect!.origin.y, -20)
    }

    // MARK: - encodeJSON

    func testEncodeJSONPrettyPrint() {
        let element = TextElement(text: "Hi", x: 1, y: 2, w: 3, h: 4, confidence: 1.0)
        let json = encodeJSON(element, prettyPrint: true)
        XCTAssertNotNil(json)
        XCTAssertTrue(json!.contains("\n"))  // pretty printed has newlines
        XCTAssertTrue(json!.contains("\"Hi\""))
    }

    func testEncodeJSONCompact() {
        let result = FindResult(text: "Test", x: 0, y: 0, found: false)
        let json = encodeJSON(result, prettyPrint: false)
        XCTAssertNotNil(json)
        XCTAssertFalse(json!.contains("\n"))
    }

    func testEncodeJSONSortedKeys() {
        let element = TextElement(text: "A", x: 1, y: 2, w: 3, h: 4, confidence: 0.5)
        let json = encodeJSON(element, prettyPrint: false, sortKeys: true)!
        // Keys should appear alphabetically: confidence, h, text, w, x, y
        let confIdx = json.range(of: "confidence")!.lowerBound
        let textIdx = json.range(of: "\"text\"")!.lowerBound
        XCTAssertTrue(confIdx < textIdx)
    }

    // MARK: - sortByPosition

    func testSortByPositionTopToBottom() {
        let elements = [
            TextElement(text: "C", x: 100, y: 300, w: 10, h: 10, confidence: 1),
            TextElement(text: "A", x: 100, y: 100, w: 10, h: 10, confidence: 1),
            TextElement(text: "B", x: 100, y: 200, w: 10, h: 10, confidence: 1),
        ]
        let sorted = sortByPosition(elements)
        XCTAssertEqual(sorted.map(\.text), ["A", "B", "C"])
    }

    func testSortByPositionLeftToRightSameRow() {
        let elements = [
            TextElement(text: "B", x: 200, y: 100, w: 10, h: 10, confidence: 1),
            TextElement(text: "A", x: 100, y: 100, w: 10, h: 10, confidence: 1),
            TextElement(text: "C", x: 300, y: 100, w: 10, h: 10, confidence: 1),
        ]
        let sorted = sortByPosition(elements)
        XCTAssertEqual(sorted.map(\.text), ["A", "B", "C"])
    }

    func testSortByPositionEmpty() {
        XCTAssertEqual(sortByPosition([]), [])
    }

    func testSortByPositionSingle() {
        let el = TextElement(text: "Only", x: 50, y: 50, w: 10, h: 10, confidence: 1)
        XCTAssertEqual(sortByPosition([el]), [el])
    }
}
