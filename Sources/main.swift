import AppKit
import Vision
import Foundation
import ScreenCaptureKit

// MARK: - Models

struct TextElement: Codable {
    let text: String
    let x: Int       // center x (screen coords)
    let y: Int       // center y (screen coords)
    let w: Int       // width
    let h: Int       // height
    let confidence: Float
}

struct FindResult: Codable {
    let text: String
    let x: Int
    let y: Int
    let found: Bool
}

struct TapResult: Codable {
    let text: String
    let x: Int
    let y: Int
    let tapped: Bool
}

// MARK: - Screen Capture (ScreenCaptureKit)

func captureDisplay(region: CGRect? = nil) async -> (CGImage, CGRect)? {
    guard let content = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true),
          let display = content.displays.first else { return nil }

    let filter = SCContentFilter(display: display, excludingWindows: [])
    let config = SCStreamConfiguration()
    config.width = display.width
    config.height = display.height
    config.showsCursor = false

    if let region = region {
        config.sourceRect = region
        config.width = Int(region.width) * 2   // Retina
        config.height = Int(region.height) * 2
    }

    guard let image = try? await SCScreenshotManager.captureImage(
        contentFilter: filter,
        configuration: config
    ) else { return nil }

    let screenRect = region ?? CGRect(
        x: CGFloat(display.frame.origin.x),
        y: CGFloat(display.frame.origin.y),
        width: CGFloat(display.width),
        height: CGFloat(display.height)
    )

    return (image, screenRect)
}

func captureWindow(appName: String) async -> (CGImage, CGRect)? {
    guard let content = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true) else {
        return nil
    }

    guard let window = content.windows.first(where: {
        $0.owningApplication?.applicationName == appName && $0.frame.width > 100 && $0.frame.height > 100
    }) else { return nil }

    let filter = SCContentFilter(desktopIndependentWindow: window)
    let config = SCStreamConfiguration()
    config.width = Int(window.frame.width) * 2   // Retina
    config.height = Int(window.frame.height) * 2
    config.showsCursor = false

    guard let image = try? await SCScreenshotManager.captureImage(
        contentFilter: filter,
        configuration: config
    ) else { return nil }

    return (image, window.frame)
}

/// Resolve capture target: explicit region > app window > full screen
func captureTarget(appName: String?, region: CGRect?) async -> (CGImage, CGRect)? {
    if let region = region {
        return await captureDisplay(region: region)
    }
    if let app = appName {
        return await captureWindow(appName: app)
    }
    return await captureDisplay()
}

// MARK: - OCR

func performOCR(image: CGImage, screenRect: CGRect) -> [TextElement] {
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.recognitionLanguages = ["ko-KR", "en-US"]
    request.usesLanguageCorrection = true

    let handler = VNImageRequestHandler(cgImage: image, options: [:])
    try? handler.perform([request])

    guard let results = request.results else { return [] }

    let imgW = CGFloat(image.width)
    let imgH = CGFloat(image.height)

    let scaleX = screenRect.width / imgW
    let scaleY = screenRect.height / imgH

    var elements: [TextElement] = []

    for observation in results {
        guard let candidate = observation.topCandidates(1).first else { continue }

        let box = observation.boundingBox
        // Vision coordinates: origin bottom-left, normalized [0,1]
        let pixelX = box.origin.x * imgW
        let pixelY = (1.0 - box.origin.y - box.height) * imgH
        let pixelW = box.width * imgW
        let pixelH = box.height * imgH

        let screenX = screenRect.origin.x + pixelX * scaleX
        let screenY = screenRect.origin.y + pixelY * scaleY
        let screenW = pixelW * scaleX
        let screenH = pixelH * scaleY

        let centerX = Int(screenX + screenW / 2)
        let centerY = Int(screenY + screenH / 2)

        elements.append(TextElement(
            text: candidate.string,
            x: centerX,
            y: centerY,
            w: Int(screenW),
            h: Int(screenH),
            confidence: candidate.confidence
        ))
    }

    return elements
}

// MARK: - Commands

func cmdOCR(appName: String?, region: CGRect?) async {
    guard let (image, rect) = await captureTarget(appName: appName, region: region) else {
        printError("Failed to capture screen")
        exit(1)
    }

    let elements = performOCR(image: image, screenRect: rect)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    if let json = try? encoder.encode(elements) {
        print(String(data: json, encoding: .utf8) ?? "[]")
    }
}

func cmdFind(appName: String?, query: String, region: CGRect?) async {
    guard let (image, rect) = await captureTarget(appName: appName, region: region) else {
        printJSON(FindResult(text: query, x: 0, y: 0, found: false))
        return
    }

    let elements = performOCR(image: image, screenRect: rect)
    let queryLower = query.lowercased()

    let exact = elements.first { $0.text.lowercased() == queryLower }
    let partial = elements.first { $0.text.lowercased().contains(queryLower) }
    let match = exact ?? partial

    if let m = match {
        printJSON(FindResult(text: m.text, x: m.x, y: m.y, found: true))
    } else {
        printJSON(FindResult(text: query, x: 0, y: 0, found: false))
    }
}

func cmdTap(appName: String?, query: String, region: CGRect?) async {
    guard let (image, rect) = await captureTarget(appName: appName, region: region) else {
        printJSON(TapResult(text: query, x: 0, y: 0, tapped: false))
        return
    }

    let elements = performOCR(image: image, screenRect: rect)
    let queryLower = query.lowercased()

    let exact = elements.first { $0.text.lowercased() == queryLower }
    let partial = elements.first { $0.text.lowercased().contains(queryLower) }
    let match = exact ?? partial

    if let m = match {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/cliclick")
        process.arguments = ["c:\(m.x),\(m.y)"]
        try? process.run()
        process.waitUntilExit()

        printJSON(TapResult(text: m.text, x: m.x, y: m.y, tapped: process.terminationStatus == 0))
    } else {
        printJSON(TapResult(text: query, x: 0, y: 0, tapped: false))
    }
}

func cmdList(appName: String?, region: CGRect?) async {
    guard let (image, rect) = await captureTarget(appName: appName, region: region) else {
        printError("Failed to capture screen")
        exit(1)
    }

    let elements = performOCR(image: image, screenRect: rect)
        .sorted { $0.y == $1.y ? $0.x < $1.x : $0.y < $1.y }

    for el in elements {
        let conf = String(format: "%.0f%%", el.confidence * 100)
        print("  [\(el.x), \(el.y)]  \(el.text)  (\(conf))")
    }
    print("\n\(elements.count) elements found")
}

// MARK: - Helpers

func printJSON<T: Codable>(_ value: T) {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted]
    if let json = try? encoder.encode(value) {
        print(String(data: json, encoding: .utf8) ?? "{}")
    }
}

func printError(_ msg: String) {
    FileHandle.standardError.write(Data("Error: \(msg)\n".utf8))
}

func parseRegion(_ str: String) -> CGRect? {
    let parts = str.split(separator: ",").compactMap { Double($0) }
    guard parts.count == 4 else { return nil }
    return CGRect(x: parts[0], y: parts[1], width: parts[2], height: parts[3])
}

func printUsage() {
    let usage = """
    screen-vision — macOS screen OCR & automation CLI (Apple Vision + ScreenCaptureKit)

    Usage:
      screen-vision ocr  [--app NAME] [--region x,y,w,h]   Full OCR -> JSON
      screen-vision list [--app NAME] [--region x,y,w,h]   OCR -> human-readable list
      screen-vision find "text" [--app NAME] [--region x,y,w,h]  Find text -> coordinates
      screen-vision tap  "text" [--app NAME] [--region x,y,w,h]  Find + click

    Capture priority:
      --region  >  --app window  >  full screen (default)

    Options:
      --app NAME       Target app window by name (e.g. "Safari", "Finder")
      --region x,y,w,h Screen region to capture (x,y,width,height)

    Examples:
      screen-vision list                            # OCR full screen
      screen-vision list --app "Safari"              # OCR Safari window
      screen-vision find "Search" --app "Chrome"     # Find text in Chrome
      screen-vision tap "OK"                         # Find & click on full screen
      screen-vision ocr --region 135,25,1014,760     # OCR specific region
    """
    print(usage)
}

// MARK: - Main

let args = Array(CommandLine.arguments.dropFirst())

if args.isEmpty || args.first == "help" || args.first == "--help" {
    printUsage()
    exit(0)
}

var appName: String? = nil
var region: CGRect? = nil
var command = args[0]
var query = ""

var i = 1
while i < args.count {
    switch args[i] {
    case "--app":
        i += 1
        if i < args.count { appName = args[i] }
    case "--region":
        i += 1
        if i < args.count { region = parseRegion(args[i]) }
    default:
        if query.isEmpty { query = args[i] }
    }
    i += 1
}

// Run async main
let semaphore = DispatchSemaphore(value: 0)

Task {
    switch command {
    case "ocr":
        await cmdOCR(appName: appName, region: region)
    case "list":
        await cmdList(appName: appName, region: region)
    case "find":
        guard !query.isEmpty else {
            printError("Usage: screen-vision find \"text\"")
            exit(1)
        }
        await cmdFind(appName: appName, query: query, region: region)
    case "tap":
        guard !query.isEmpty else {
            printError("Usage: screen-vision tap \"text\"")
            exit(1)
        }
        await cmdTap(appName: appName, query: query, region: region)
    default:
        printError("Unknown command: \(command)")
        printUsage()
        exit(1)
    }
    semaphore.signal()
}

semaphore.wait()
