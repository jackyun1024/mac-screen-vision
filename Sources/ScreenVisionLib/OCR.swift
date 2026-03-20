import AppKit
import Vision
import Foundation

public func performOCR(image: CGImage, screenRect: CGRect) -> [TextElement] {
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.recognitionLanguages = ["ko-KR", "en-US"]
    request.usesLanguageCorrection = true

    let handler = VNImageRequestHandler(cgImage: image, options: [:])
    try? handler.perform([request])

    guard let results = request.results else { return [] }

    return results.compactMap { observation in
        guard let candidate = observation.topCandidates(1).first else { return nil }
        let coords = convertToScreenCoords(
            boundingBox: observation.boundingBox,
            imageWidth: CGFloat(image.width),
            imageHeight: CGFloat(image.height),
            screenRect: screenRect
        )
        return TextElement(
            text: candidate.string,
            x: coords.centerX,
            y: coords.centerY,
            w: coords.width,
            h: coords.height,
            confidence: candidate.confidence
        )
    }
}

public struct ScreenCoords: Equatable {
    public let centerX: Int
    public let centerY: Int
    public let width: Int
    public let height: Int
}

/// Convert Vision normalized bounding box to screen coordinates.
/// Vision box: origin bottom-left, normalized [0,1].
public func convertToScreenCoords(
    boundingBox box: CGRect,
    imageWidth imgW: CGFloat,
    imageHeight imgH: CGFloat,
    screenRect: CGRect
) -> ScreenCoords {
    let scaleX = screenRect.width / imgW
    let scaleY = screenRect.height / imgH

    let pixelX = box.origin.x * imgW
    let pixelY = (1.0 - box.origin.y - box.height) * imgH
    let pixelW = box.width * imgW
    let pixelH = box.height * imgH

    let screenX = screenRect.origin.x + pixelX * scaleX
    let screenY = screenRect.origin.y + pixelY * scaleY
    let screenW = pixelW * scaleX
    let screenH = pixelH * scaleY

    return ScreenCoords(
        centerX: Int(screenX + screenW / 2),
        centerY: Int(screenY + screenH / 2),
        width: Int(screenW),
        height: Int(screenH)
    )
}
