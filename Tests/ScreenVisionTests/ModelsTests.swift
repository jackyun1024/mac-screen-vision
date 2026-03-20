import XCTest
@testable import ScreenVisionLib

final class ModelsTests: XCTestCase {

    // MARK: - TextElement Codable

    func testTextElementEncodeDecode() throws {
        let element = TextElement(text: "Hello", x: 100, y: 200, w: 50, h: 20, confidence: 0.95)
        let data = try JSONEncoder().encode(element)
        let decoded = try JSONDecoder().decode(TextElement.self, from: data)
        XCTAssertEqual(element, decoded)
    }

    func testTextElementJSONKeys() throws {
        let element = TextElement(text: "Test", x: 1, y: 2, w: 3, h: 4, confidence: 1.0)
        let data = try JSONEncoder().encode(element)
        let dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(dict["text"] as? String, "Test")
        XCTAssertEqual(dict["x"] as? Int, 1)
        XCTAssertEqual(dict["y"] as? Int, 2)
        XCTAssertEqual(dict["w"] as? Int, 3)
        XCTAssertEqual(dict["h"] as? Int, 4)
        XCTAssertEqual(dict["confidence"] as! Double, 1.0, accuracy: 0.001)
    }

    // MARK: - FindResult Codable

    func testFindResultFound() throws {
        let result = FindResult(text: "OK", x: 300, y: 400, found: true)
        let data = try JSONEncoder().encode(result)
        let decoded = try JSONDecoder().decode(FindResult.self, from: data)
        XCTAssertEqual(result, decoded)
        XCTAssertTrue(decoded.found)
    }

    func testFindResultNotFound() throws {
        let result = FindResult(text: "Missing", x: 0, y: 0, found: false)
        let json = try JSONEncoder().encode(result)
        let decoded = try JSONDecoder().decode(FindResult.self, from: json)
        XCTAssertFalse(decoded.found)
        XCTAssertEqual(decoded.x, 0)
        XCTAssertEqual(decoded.y, 0)
    }

    // MARK: - TapResult Codable

    func testTapResultTapped() throws {
        let result = TapResult(text: "Submit", x: 500, y: 600, tapped: true)
        let data = try JSONEncoder().encode(result)
        let decoded = try JSONDecoder().decode(TapResult.self, from: data)
        XCTAssertEqual(result, decoded)
        XCTAssertTrue(decoded.tapped)
    }

    func testTapResultNotTapped() throws {
        let result = TapResult(text: "Ghost", x: 0, y: 0, tapped: false)
        let data = try JSONEncoder().encode(result)
        let decoded = try JSONDecoder().decode(TapResult.self, from: data)
        XCTAssertFalse(decoded.tapped)
    }
}
