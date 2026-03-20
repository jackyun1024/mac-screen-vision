import Foundation

/// Find the best matching element: exact match first, then partial (contains).
public func findMatch(query: String, in elements: [TextElement]) -> TextElement? {
    let queryLower = query.lowercased()
    let exact = elements.first { $0.text.lowercased() == queryLower }
    let partial = elements.first { $0.text.lowercased().contains(queryLower) }
    return exact ?? partial
}
