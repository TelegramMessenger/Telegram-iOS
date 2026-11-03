import Foundation
import TelegramCore

/// A post's identity in a list: an album keeps its identity when a later page adds a message to it. The feeds and
/// the search share it, so the search can tell when both feeds hold the same post.
public func newsPostIdentity(_ entry: EngineFeedEntry) -> AnyHashable {
    if let groupingKey = entry.groupingKey {
        return AnyHashable("album-\(entry.peerId.toInt64())-\(groupingKey)")
    }
    return AnyHashable("post-\(entry.peerId.toInt64())-\(entry.messageIds[0].namespace)-\(entry.messageIds[0].id)")
}

/// A post the News search can find: its entry, and the words of its text (each message's, so an album is found by
/// any of its captions) and of its channel's title.
public struct NewsSearchDocument {
    public let entry: EngineFeedEntry
    let words: [String]

    public init(entry: EngineFeedEntry, texts: [String], channelTitle: String) {
        self.entry = entry
        var words = Set<String>()
        for text in texts + [channelTitle] {
            words.formUnion(newsSearchWords(text))
        }
        self.words = Array(words)
    }
}

/// Words as the search compares them: runs of letters and digits, without case or diacritics. Anything else
/// separates words, as in the Postbox text index.
private func newsSearchWords(_ text: String) -> [String] {
    let folded = text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
    var words: [String] = []
    var current = String.UnicodeScalarView()
    for scalar in folded.unicodeScalars {
        if CharacterSet.alphanumerics.contains(scalar) {
            current.append(scalar)
        } else if !current.isEmpty {
            words.append(String(current))
            current = String.UnicodeScalarView()
        }
    }
    if !current.isEmpty {
        words.append(String(current))
    }
    return words
}

/// A query's words. Empty for a query without letters or digits, which finds nothing.
public func newsSearchQueryWords(_ query: String) -> [String] {
    return newsSearchWords(query)
}

/// Whether every query word begins one of the document's words.
public func newsSearchMatches(queryWords: [String], document: NewsSearchDocument) -> Bool {
    if queryWords.isEmpty {
        return false
    }
    for queryWord in queryWords {
        if !document.words.contains(where: { $0.hasPrefix(queryWord) }) {
            return false
        }
    }
    return true
}

/// The posts a query finds, newest first. Both feeds can hold the same post: it is found once, as the copy with
/// the most messages (an album one feed has only part of).
public func newsSearchResults(queryWords: [String], documents: [NewsSearchDocument]) -> [NewsSearchDocument] {
    var results: [NewsSearchDocument] = []
    var indexByIdentity: [AnyHashable: Int] = [:]
    for document in documents where newsSearchMatches(queryWords: queryWords, document: document) {
        let identity = newsPostIdentity(document.entry)
        if let index = indexByIdentity[identity] {
            if document.entry.messageIds.count > results[index].entry.messageIds.count {
                results[index] = document
            }
        } else {
            indexByIdentity[identity] = results.count
            results.append(document)
        }
    }
    return results.sorted(by: { $0.entry.position > $1.entry.position })
}
