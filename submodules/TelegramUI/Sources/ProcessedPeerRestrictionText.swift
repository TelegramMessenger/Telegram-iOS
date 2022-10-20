import Foundation

func processedPeerRestrictionText(_ text: String) -> String {
    if let range = text.range(of: ":") {
        return String(text[range.upperBound...])
    } else {
        return text
    }
}
