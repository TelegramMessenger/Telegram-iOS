import UIKit

public func findSubstringRanges(in string: String, query: String) -> ([Range<String.Index>], String) {
    var ranges: [Range<String.Index>] = []
    let queryWords = query.split { !$0.isLetter && !$0.isNumber && $0 != "#" && $0 != "@" }.filter { !$0.isEmpty && !["#", "@"].contains($0) }.map { $0.lowercased() }
    
    let text = string.lowercased()
    let searchRange = text.startIndex ..< text.endIndex
    text.enumerateSubstrings(in: searchRange, options: .byWords) { (rawSubstring, rawRange, _, _) in
        guard let rawSubstring = rawSubstring else {
            return
        }
        var substrings: [(String, Range<String.Index>)] = []
        if let index = rawSubstring.firstIndex(of: "'") {
            let leftString = String(rawSubstring[..<index])
            let rightString = String(rawSubstring[rawSubstring.index(after: index)...])
            if !leftString.isEmpty {
                substrings.append((leftString, rawRange.lowerBound ..< text.index(rawRange.lowerBound, offsetBy: leftString.count)))
            }
            if !rightString.isEmpty {
                substrings.append((rightString, text.index(rawRange.lowerBound, offsetBy: leftString.count + 1) ..< rawRange.upperBound))
            }
        } else {
            substrings.append((rawSubstring, rawRange))
        }
        
        for (substring, range) in substrings {
            for var word in queryWords {
                var count = 0
                var hasLeadingSymbol = false
                if word.hasPrefix("#") || word.hasPrefix("@") {
                    hasLeadingSymbol = true
                    word.removeFirst()
                }
                inner: for (c1, c2) in zip(word, substring) {
                    if c1 != c2 {
                        break inner
                    }
                    count += 1
                }
                if count > 0 {
                    let length = Double(max(word.count, substring.count))
                    if length > 0 {
                        let difference = abs(length - Double(count))
                        let rating = difference / length
                        if rating < 0.37 {
                            var range = range
                            if hasLeadingSymbol && range.lowerBound > searchRange.lowerBound {
                                range = text.index(before: range.lowerBound)..<range.upperBound
                            }
                            ranges.append(range)
                        }
                    }
                }
            }
        }
    }
    return (ranges, text)
}
