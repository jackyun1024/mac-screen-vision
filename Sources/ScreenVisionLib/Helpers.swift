import Foundation

public func parseRegion(_ str: String) -> CGRect? {
    let parts = str.split(separator: ",").compactMap { Double($0) }
    guard parts.count == 4 else { return nil }
    return CGRect(x: parts[0], y: parts[1], width: parts[2], height: parts[3])
}

public func encodeJSON<T: Codable>(_ value: T, prettyPrint: Bool = true, sortKeys: Bool = false) -> String? {
    let encoder = JSONEncoder()
    var formatting: JSONEncoder.OutputFormatting = []
    if prettyPrint { formatting.insert(.prettyPrinted) }
    if sortKeys { formatting.insert(.sortedKeys) }
    encoder.outputFormatting = formatting
    guard let data = try? encoder.encode(value) else { return nil }
    return String(data: data, encoding: .utf8)
}

/// Sort elements by position: top to bottom, left to right.
public func sortByPosition(_ elements: [TextElement]) -> [TextElement] {
    elements.sorted { $0.y == $1.y ? $0.x < $1.x : $0.y < $1.y }
}
