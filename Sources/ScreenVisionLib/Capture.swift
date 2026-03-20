import AppKit
import Foundation
import ScreenCaptureKit

public func captureDisplay(region: CGRect? = nil) async -> (CGImage, CGRect)? {
    guard let content = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true),
          let display = content.displays.first else { return nil }

    let filter = SCContentFilter(display: display, excludingWindows: [])
    let config = SCStreamConfiguration()
    config.width = display.width
    config.height = display.height
    config.showsCursor = false

    if let region = region {
        config.sourceRect = region
        config.width = Int(region.width) * 2
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

public func captureWindow(appName: String) async -> (CGImage, CGRect)? {
    guard let content = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true) else {
        return nil
    }

    guard let window = content.windows.first(where: {
        $0.owningApplication?.applicationName == appName && $0.frame.width > 100 && $0.frame.height > 100
    }) else { return nil }

    let filter = SCContentFilter(desktopIndependentWindow: window)
    let config = SCStreamConfiguration()
    config.width = Int(window.frame.width) * 2
    config.height = Int(window.frame.height) * 2
    config.showsCursor = false

    guard let image = try? await SCScreenshotManager.captureImage(
        contentFilter: filter,
        configuration: config
    ) else { return nil }

    return (image, window.frame)
}

/// Resolve capture target: explicit region > app window > full screen
public func captureTarget(appName: String?, region: CGRect?) async -> (CGImage, CGRect)? {
    if let region = region {
        return await captureDisplay(region: region)
    }
    if let app = appName {
        return await captureWindow(appName: app)
    }
    return await captureDisplay()
}
