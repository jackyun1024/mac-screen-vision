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

func cmdTap(appName: String?, query: String, region: CGRect?) async {
    guard let (image, rect) = await captureTarget(appName: appName, region: region) else {
        print(encodeJSON(TapResult(text: query, x: 0, y: 0, tapped: false))!)
        return
    }
    let elements = performOCR(image: image, screenRect: rect)
    if let m = findMatch(query: query, in: elements) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/cliclick")
        process.arguments = ["c:\(m.x),\(m.y)"]
        try? process.run()
        process.waitUntilExit()
        print(encodeJSON(TapResult(text: m.text, x: m.x, y: m.y, tapped: process.terminationStatus == 0))!)
    } else {
        print(encodeJSON(TapResult(text: query, x: 0, y: 0, tapped: false))!)
    }
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
    case "tap":
        guard !query.isEmpty else {
            printError("Usage: screen-vision tap \"text\""); exit(1)
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
