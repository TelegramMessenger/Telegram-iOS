import Foundation
import AppBundle

private func loadStaticEmojiMapping() -> [(EmojiPagerContentComponent.StaticEmojiSegment, [String])] {
    guard let path = getAppBundle().path(forResource: "emoji1", ofType: "txt") else {
        return []
    }
    guard let string = try? String(contentsOf: URL(fileURLWithPath: path)) else {
        return []
    }

    // Convert \r\n to \n for consistent line ending handling
    let normalizedString = string.replacingOccurrences(of: "\r\n", with: "\n")

    // Split into 4 large sections divided by =========================================
    let largeSections = normalizedString.components(separatedBy: "=========================================")
    
    if largeSections.count < 4 {
        return []
    }
    
    // Use the first large section
    let firstLargeSection = largeSections[0].trimmingCharacters(in: .whitespacesAndNewlines)
    
    // Split into 8 sections divided by triple-newline
    let emojiSections = firstLargeSection.components(separatedBy: "\n\n\n")
    
    if emojiSections.count < 8 {
        return []
    }
    
    var result: [(EmojiPagerContentComponent.StaticEmojiSegment, [String])] = []
    
    let orderedSegments = EmojiPagerContentComponent.StaticEmojiSegment.allCases
    
    for i in 0..<min(emojiSections.count, orderedSegments.count) {
        let sectionContent = emojiSections[i].trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Parse emoji from this section and filter out skin-colored variants
        let emojiList = parseEmojiSection(sectionContent)
        
        result.append((orderedSegments[i], emojiList))
    }
    
    return result
}

private func parseEmojiSection(_ sectionContent: String) -> [String] {
    // Remove quotes first
    let cleanedContent = sectionContent.replacingOccurrences(of: "\"", with: "")
    let items = cleanedContent.components(separatedBy: ",")
    
    var result: [String] = []
    var i = 0
    
    while i < items.count {
        let item = items[i]
        let cleanItem = item.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Skip empty items
        if cleanItem.isEmpty {
            i += 1
            continue
        }
        
        result.append(cleanItem)
        i += 1
        
        // If this item started with a newline, it's the beginning of a skin-colored emoji group
        // Skip all following items until we find the next item that starts with a newline (or reach the end)
        if item.hasPrefix("\n") {
            while i < items.count {
                let nextItem = items[i]
                if nextItem.hasPrefix("\n") {
                    // Found the start of the next group, break to process it
                    break
                } else {
                    // Skip this skin-colored variant
                    i += 1
                }
            }
        }
    }
    
    return result
}

public extension EmojiPagerContentComponent {
    static let staticEmojiMapping: [(EmojiPagerContentComponent.StaticEmojiSegment, [String])] = loadStaticEmojiMapping()
}
