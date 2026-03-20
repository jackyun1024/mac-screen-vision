import Foundation

public struct TextElement: Codable, Equatable {
    public let text: String
    public let x: Int
    public let y: Int
    public let w: Int
    public let h: Int
    public let confidence: Float

    public init(text: String, x: Int, y: Int, w: Int, h: Int, confidence: Float) {
        self.text = text
        self.x = x
        self.y = y
        self.w = w
        self.h = h
        self.confidence = confidence
    }
}

public struct FindResult: Codable, Equatable {
    public let text: String
    public let x: Int
    public let y: Int
    public let found: Bool

    public init(text: String, x: Int, y: Int, found: Bool) {
        self.text = text
        self.x = x
        self.y = y
        self.found = found
    }
}

public struct TapResult: Codable, Equatable {
    public let text: String
    public let x: Int
    public let y: Int
    public let tapped: Bool

    public init(text: String, x: Int, y: Int, tapped: Bool) {
        self.text = text
        self.x = x
        self.y = y
        self.tapped = tapped
    }
}
