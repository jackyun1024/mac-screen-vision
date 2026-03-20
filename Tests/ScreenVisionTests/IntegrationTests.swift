import XCTest
import AppKit
@testable import ScreenVisionLib

/// Integration tests that require Screen Recording permission and a GUI session.
/// Run with: swift test --filter IntegrationTests
///
/// These tests will be skipped in headless/CI environments.
final class IntegrationTests: XCTestCase {

    /// Check if we're in a GUI session that supports ScreenCaptureKit
    private func requireGUISession() throws {
        guard NSScreen.main != nil else {
            throw XCTSkip("No GUI session available (headless environment)")
        }
    }

    // MARK: - Full screen capture

    func testCaptureFullScreen() async throws {
        try requireGUISession()
        let result = await captureDisplay()
        XCTAssertNotNil(result, "Full screen capture failed — check Screen Recording permission")
        if let (image, rect) = result {
            XCTAssertGreaterThan(image.width, 0)
            XCTAssertGreaterThan(image.height, 0)
            XCTAssertGreaterThan(rect.width, 0)
            XCTAssertGreaterThan(rect.height, 0)
        }
    }

    // MARK: - Full screen OCR

    func testFullScreenOCR() async throws {
        try requireGUISession()
        guard let (image, rect) = await captureDisplay() else {
            throw XCTSkip("Screen capture unavailable")
        }
        let elements = performOCR(image: image, screenRect: rect)
        XCTAssertGreaterThan(elements.count, 0, "OCR should find at least some text on screen")

        for el in elements {
            XCTAssertFalse(el.text.isEmpty)
            XCTAssertGreaterThanOrEqual(el.confidence, 0)
            XCTAssertLessThanOrEqual(el.confidence, 1)
        }
    }

    // MARK: - Region capture

    func testCaptureRegion() async throws {
        try requireGUISession()
        let region = CGRect(x: 0, y: 0, width: 500, height: 500)
        let result = await captureDisplay(region: region)
        XCTAssertNotNil(result, "Region capture failed")
        if let (image, rect) = result {
            XCTAssertGreaterThan(image.width, 0)
            XCTAssertEqual(rect, region)
        }
    }

    // MARK: - Window capture (Finder should always exist)

    func testCaptureFinderWindow() async throws {
        try requireGUISession()
        let finderURL = URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app")
        try await NSWorkspace.shared.openApplication(at: finderURL, configuration: .init())
        try await Task.sleep(nanoseconds: 500_000_000)

        let result = await captureWindow(appName: "Finder")
        // Finder might not have a visible window, so best-effort
        if let (image, rect) = result {
            XCTAssertGreaterThan(image.width, 0)
            XCTAssertGreaterThan(rect.width, 100)
            XCTAssertGreaterThan(rect.height, 100)
        }
    }

    // MARK: - captureTarget priority

    func testCaptureTargetFullScreen() async throws {
        try requireGUISession()
        let result = await captureTarget(appName: nil, region: nil)
        XCTAssertNotNil(result)
    }

    func testCaptureTargetNonExistentApp() async throws {
        try requireGUISession()
        let result = await captureTarget(appName: "ThisAppDoesNotExist12345", region: nil)
        XCTAssertNil(result)
    }

    // MARK: - End-to-end: find text on screen

    func testFindMenuBarText() async throws {
        try requireGUISession()
        guard let (image, rect) = await captureDisplay() else {
            throw XCTSkip("Screen capture unavailable")
        }
        let elements = performOCR(image: image, screenRect: rect)

        let hasMenuText = elements.contains { el in
            ["Finder", "파일", "File", "Edit", "수정", "보기", "View", "Chrome", "Safari", "Code"]
                .contains(where: { el.text.contains($0) })
        }
        XCTAssertTrue(hasMenuText, "Should find at least one menu bar item. Found: \(elements.map(\.text).prefix(10))")
    }
}
