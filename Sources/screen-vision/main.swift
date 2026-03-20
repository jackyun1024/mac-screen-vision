import Foundation
import ScreenVisionLib

func printError(_ msg: String) {
    FileHandle.standardError.write(Data("Error: \(msg)\n".utf8))
}

func printUsage() {
    let usage = """
    screen-vision — macOS screen OCR & automation CLI (Apple Vision + ScreenCaptureKit)

    Usage:
      screen-vision ocr  [--app NAME] [--region x,y,w,h]   Full OCR -> JSON
      screen-vision list [--app NAME] [--region x,y,w,h]   OCR -> human-readable list
      screen-vision find "text" [--app NAME] [--region x,y,w,h]  Find text -> coordinates
      screen-vision has  "text" [--app NAME] [--region x,y,w,h]  Check if text exists (exit 0/1)
      screen-vision tap  "text" [--app NAME] [--region x,y,w,h] [--retry N]  Find + click
      screen-vision wait "text" [--app NAME] [--timeout SEC]     Poll until text appears

    Capture priority:
      --region  >  --app window  >  full screen (default)

    Options:
      --app NAME       Target app window by name (e.g. "Safari", "Finder")
      --region x,y,w,h Screen region to capture (x,y,width,height)
      --retry N        Retry up to N times with 1s interval (tap only)
      --timeout SEC    Max seconds to wait (wait only, default: 30)

    Examples:
      screen-vision list                            # OCR full screen
      screen-vision list --app "Safari"              # OCR Safari window
      screen-vision find "Search" --app "Chrome"     # Find text in Chrome
      screen-vision has "Submit"                     # Exit 0 if found, 1 if not
      screen-vision tap "OK" --retry 3               # Try clicking up to 3 times
      screen-vision wait "Complete" --timeout 60     # Wait up to 60s for text
      screen-vision ocr --region 135,25,1014,760     # OCR specific region
    """
    print(usage)
}

// MARK: - Commands

func cmdOCR(appName: String?, region: CGRect?) async {
    guard let (image, rect) = await captureTarget(appName: appName, region: region) else {
        printError("Failed to capture screen"); exit(1)
    }
    let elements = performOCR(image: image, screenRect: rect)
    if let json = encodeJSON(elements, sortKeys: true) {
        print(json)
    }
}

func cmdList(appName: String?, region: CGRect?) async {
    guard let (image, rect) = await captureTarget(appName: appName, region: region) else {
        printError("Failed to capture screen"); exit(1)
    }
    let elements = sortByPosition(performOCR(image: image, screenRect: rect))
    for el in elements {
        let conf = String(format: "%.0f%%", el.confidence * 100)
        print("  [\(el.x), \(el.y)]  \(el.text)  (\(conf))")
    }
    print("\n\(elements.count) elements found")
}

func cmdFind(appName: String?, query: String, region: CGRect?) async {
    guard let (image, rect) = await captureTarget(appName: appName, region: region) else {
        print(encodeJSON(FindResult(text: query, x: 0, y: 0, found: false))!)
        return
    }
    let elements = performOCR(image: image, screenRect: rect)
    if let m = findMatch(query: query, in: elements) {
        print(encodeJSON(FindResult(text: m.text, x: m.x, y: m.y, found: true))!)
    } else {
        print(encodeJSON(FindResult(text: query, x: 0, y: 0, found: false))!)
    }
}

func cmdHas(appName: String?, query: String, region: CGRect?) async {
    guard let (image, rect) = await captureTarget(appName: appName, region: region) else {
        exit(1)
    }
    let elements = performOCR(image: image, screenRect: rect)
    if findMatch(query: query, in: elements) != nil {
        exit(0)
    } else {
        exit(1)
    }
}

func cmdTap(appName: String?, query: String, region: CGRect?, retryCount: Int) async {
    for attempt in 0...retryCount {
        if let (image, rect) = await captureTarget(appName: appName, region: region) {
            let elements = performOCR(image: image, screenRect: rect)
            if let m = findMatch(query: query, in: elements) {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/cliclick")
                process.arguments = ["c:\(m.x),\(m.y)"]
                try? process.run()
                process.waitUntilExit()
                print(encodeJSON(TapResult(text: m.text, x: m.x, y: m.y, tapped: process.terminationStatus == 0))!)
                return
            }
        }
        if attempt < retryCount {
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1s
        }
    }
    print(encodeJSON(TapResult(text: query, x: 0, y: 0, tapped: false))!)
}

func cmdWait(appName: String?, query: String, region: CGRect?, timeout: Int) async {
    let deadline = Date().addingTimeInterval(Double(timeout))
    while Date() < deadline {
        if let (image, rect) = await captureTarget(appName: appName, region: region) {
            let elements = performOCR(image: image, screenRect: rect)
            if let m = findMatch(query: query, in: elements) {
                print(encodeJSON(FindResult(text: m.text, x: m.x, y: m.y, found: true))!)
                return
            }
        }
        try? await Task.sleep(nanoseconds: 1_000_000_000) // poll every 1s
    }
    print(encodeJSON(FindResult(text: query, x: 0, y: 0, found: false))!)
}

// MARK: - Main

let args = Array(CommandLine.arguments.dropFirst())

if args.isEmpty || args.first == "help" || args.first == "--help" {
    printUsage()
    exit(0)
}

var appName: String? = nil
var region: CGRect? = nil
var retryCount = 0
var timeout = 30
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
    case "--retry":
        i += 1
        if i < args.count { retryCount = Int(args[i]) ?? 0 }
    case "--timeout":
        i += 1
        if i < args.count { timeout = Int(args[i]) ?? 30 }
    default:
        if query.isEmpty { query = args[i] }
    }
    i += 1
}

let semaphore = DispatchSemaphore(value: 0)

Task {
    switch command {
    case "ocr":
        await cmdOCR(appName: appName, region: region)
    case "list":
        await cmdList(appName: appName, region: region)
    case "find":
        guard !query.isEmpty else {
            printError("Usage: screen-vision find \"text\""); exit(1)
        }
        await cmdFind(appName: appName, query: query, region: region)
    case "has":
        guard !query.isEmpty else {
            printError("Usage: screen-vision has \"text\""); exit(1)
        }
        await cmdHas(appName: appName, query: query, region: region)
    case "tap":
        guard !query.isEmpty else {
            printError("Usage: screen-vision tap \"text\""); exit(1)
        }
        await cmdTap(appName: appName, query: query, region: region, retryCount: retryCount)
    case "wait":
        guard !query.isEmpty else {
            printError("Usage: screen-vision wait \"text\""); exit(1)
        }
        await cmdWait(appName: appName, query: query, region: region, timeout: timeout)
    default:
        printError("Unknown command: \(command)")
        printUsage()
        exit(1)
    }
    semaphore.signal()
}

semaphore.wait()
