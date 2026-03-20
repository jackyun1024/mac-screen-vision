import XCTest
@testable import ScreenVisionLib

final class CoordinateTests: XCTestCase {

    // MARK: - Basic coordinate conversion

    func testOriginTopLeft() {
        // Vision box at top-left: origin (0, 0.9), size (0.1, 0.1)
        // In Vision: y=0.9 means near top (y goes bottom→top)
        let coords = convertToScreenCoords(
            boundingBox: CGRect(x: 0, y: 0.9, width: 0.1, height: 0.1),
            imageWidth: 1000,
            imageHeight: 1000,
            screenRect: CGRect(x: 0, y: 0, width: 1000, height: 1000)
        )
        // FP rounding may give 49 or 50
        XCTAssertTrue((49...50).contains(coords.centerX), "centerX=\(coords.centerX)")
        XCTAssertTrue((49...50).contains(coords.centerY), "centerY=\(coords.centerY)")
        XCTAssertEqual(coords.width, 100)
        XCTAssertEqual(coords.height, 100)
    }

    func testOriginBottomRight() {
        // Vision box at bottom-right: origin (0.9, 0), size (0.1, 0.1)
        let coords = convertToScreenCoords(
            boundingBox: CGRect(x: 0.9, y: 0, width: 0.1, height: 0.1),
            imageWidth: 1000,
            imageHeight: 1000,
            screenRect: CGRect(x: 0, y: 0, width: 1000, height: 1000)
        )
        // pixelX = 0.9 * 1000 = 900, pixelY = (1-0-0.1)*1000 = 900
        // centerX = 900+50 = 950, centerY = 900+50 = 950
        XCTAssertEqual(coords.centerX, 950)
        XCTAssertEqual(coords.centerY, 950)
    }

    func testCenterBox() {
        // Vision box centered: origin (0.25, 0.25), size (0.5, 0.5)
        let coords = convertToScreenCoords(
            boundingBox: CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5),
            imageWidth: 1000,
            imageHeight: 1000,
            screenRect: CGRect(x: 0, y: 0, width: 1000, height: 1000)
        )
        // pixelX = 250, pixelY = (1-0.25-0.5)*1000 = 250
        // centerX = 250+250 = 500, centerY = 250+250 = 500
        XCTAssertEqual(coords.centerX, 500)
        XCTAssertEqual(coords.centerY, 500)
        XCTAssertEqual(coords.width, 500)
        XCTAssertEqual(coords.height, 500)
    }

    // MARK: - Screen offset

    func testScreenOffset() {
        // Screen rect starts at (100, 200)
        let coords = convertToScreenCoords(
            boundingBox: CGRect(x: 0, y: 0.9, width: 0.1, height: 0.1),
            imageWidth: 1000,
            imageHeight: 1000,
            screenRect: CGRect(x: 100, y: 200, width: 1000, height: 1000)
        )
        // FP rounding may give 149 or 150
        XCTAssertTrue((149...150).contains(coords.centerX), "centerX=\(coords.centerX)")
        XCTAssertTrue((249...250).contains(coords.centerY), "centerY=\(coords.centerY)")
    }

    // MARK: - Retina scaling (image larger than screen rect)

    func testRetinaScaling() {
        // Image 2000x2000 (Retina) but screen rect 1000x1000
        let coords = convertToScreenCoords(
            boundingBox: CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5),
            imageWidth: 2000,
            imageHeight: 2000,
            screenRect: CGRect(x: 0, y: 0, width: 1000, height: 1000)
        )
        // scaleX = 1000/2000 = 0.5
        // pixelX = 0.25*2000 = 500, screenX = 500*0.5 = 250
        // pixelW = 0.5*2000 = 1000, screenW = 1000*0.5 = 500
        // centerX = 250 + 250 = 500
        XCTAssertEqual(coords.centerX, 500)
        XCTAssertEqual(coords.centerY, 500)
        XCTAssertEqual(coords.width, 500)
        XCTAssertEqual(coords.height, 500)
    }

    // MARK: - Full box

    func testFullScreenBox() {
        // Vision box covering entire image: origin (0,0), size (1,1)
        let coords = convertToScreenCoords(
            boundingBox: CGRect(x: 0, y: 0, width: 1, height: 1),
            imageWidth: 800,
            imageHeight: 600,
            screenRect: CGRect(x: 0, y: 0, width: 800, height: 600)
        )
        XCTAssertEqual(coords.centerX, 400)
        XCTAssertEqual(coords.centerY, 300)
        XCTAssertEqual(coords.width, 800)
        XCTAssertEqual(coords.height, 600)
    }

    // MARK: - Non-square

    func testNonSquareImage() {
        // Wide image
        let coords = convertToScreenCoords(
            boundingBox: CGRect(x: 0, y: 0.5, width: 1, height: 0.5),
            imageWidth: 1920,
            imageHeight: 1080,
            screenRect: CGRect(x: 0, y: 0, width: 1920, height: 1080)
        )
        // pixelY = (1-0.5-0.5)*1080 = 0, pixelH = 0.5*1080 = 540
        // centerY = 0 + 270 = 270
        XCTAssertEqual(coords.centerX, 960)
        XCTAssertEqual(coords.centerY, 270)
    }
}
