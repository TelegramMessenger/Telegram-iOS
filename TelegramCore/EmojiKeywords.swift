import Foundation
#if os(macOS)
import PostboxMac
import SwiftSignalKitMac
#else
import Postbox
import SwiftSignalKit
#endif

public enum EmojiKeyword: Equatable {
    case keyword(String, [String])
    case keywordSubtrahend(String, [String])
    
    var name: String {
        switch self {
            case let .keyword(name, _), let .keywordSubtrahend(name, _):
                return name
        }
    }
    
    func union(_ emojiKeyword: EmojiKeyword) -> EmojiKeyword {
        if case let .keyword(name, lhsEmoticons) = self, name == emojiKeyword.name {
            switch emojiKeyword {
                case let .keyword(_, rhsEmoticons):
                    var existingEmoticons = Set(lhsEmoticons)
                    var updatedEmoticons = lhsEmoticons
                    for emoticon in rhsEmoticons {
                        if !existingEmoticons.contains(emoticon) {
                            existingEmoticons.insert(emoticon)
                            updatedEmoticons.append(emoticon)
                        }
                    }
                    return .keyword(name, updatedEmoticons)
                case let .keywordSubtrahend(_, rhsEmoticons):
                    let substractedEmoticons = Set(rhsEmoticons)
                    let updatedEmoticons = lhsEmoticons.filter { !substractedEmoticons.contains($0) }
                    return .keyword(name, updatedEmoticons)
            }
        } else {
            return self
        }
    }
}

private func writeString(_ buffer: WriteBuffer, _ string: String) {
    if let data = string.data(using: .utf8) {
        var length: Int32 = Int32(data.count)
        buffer.write(&length, offset: 0, length: 4)
        buffer.write(data)
    } else {
        var length: Int32 = 0
        buffer.write(&length, offset: 0, length: 4)
    }
}

private func writeStringArray(_ buffer: WriteBuffer, _ array: [String]) {
    var length = Int32(array.count)
    buffer.write(&length, offset: 0, length: 4)
    for string in array {
        writeString(buffer, string)
    }
}

public final class EmojiKeywords: PostboxCoding, Equatable {
    public let languageCode: String
    public let inputLanguageCode: String
    public let version: Int32
    public let timestamp: Int32
    public let entries: [String: EmojiKeyword]
    
    public init(languageCode: String, inputLanguageCode: String, version: Int32, timestamp: Int32, entries: [String: EmojiKeyword]) {
        self.languageCode = languageCode
        self.inputLanguageCode = inputLanguageCode
        self.version = version
        self.timestamp = timestamp
        self.entries = entries
    }
    
    public init(decoder: PostboxDecoder) {
        self.languageCode = decoder.decodeStringForKey("l", orElse: "")
        self.inputLanguageCode = decoder.decodeStringForKey("i", orElse: "")
        self.version = decoder.decodeInt32ForKey("v", orElse: 0)
        self.timestamp = decoder.decodeInt32ForKey("t", orElse: 0)
        
        let count = decoder.decodeInt32ForKey("c", orElse: 0)
        var entries: [String: EmojiKeyword] = [:]
        if let data = decoder.decodeBytesForKey("d") {
            for _ in 0 ..< count {
                var length: Int32 = 0
                data.read(&length, offset: 0, length: 4)
                
                let nameData = Data(bytes: data.memory.advanced(by: data.offset), count: Int(length))
                let name = String(data: nameData, encoding: .utf8)
                data.skip(Int(length))
                
                var emoticonsCount: Int32 = 0
                data.read(&emoticonsCount, offset: 0, length: 4)
                
                var emoticons: [String] = []
                for _ in 0 ..< emoticonsCount {
                    var length: Int32 = 0
                    data.read(&length, offset: 0, length: 4)
                    
                    let emoticonData = Data(bytes: data.memory.advanced(by: data.offset), count: Int(length))
                    let emoticon = String(data: emoticonData, encoding: .utf8)
                    data.skip(Int(length))
                    
                    if let emoticon = emoticon {
                        emoticons.append(emoticon)
                    }
                }
                
                if let name = name {
                    entries[name] = .keyword(name, emoticons)
                }
            }
        }
        self.entries = entries
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(self.languageCode, forKey: "l")
        encoder.encodeString(self.inputLanguageCode, forKey: "i")
        encoder.encodeInt32(self.version, forKey: "v")
        encoder.encodeInt32(self.timestamp, forKey: "t")
        
        encoder.encodeInt32(Int32(self.entries.count), forKey: "c")

        let buffer = WriteBuffer()
        for case let .keyword(name, emoticons) in self.entries.values {
            writeString(buffer, name)
            writeStringArray(buffer, emoticons)
        }
        encoder.encodeBytes(buffer, forKey: "d")
    }
    
    public static func ==(lhs: EmojiKeywords, rhs: EmojiKeywords) -> Bool {
        if lhs === rhs {
            return true
        }
        
        if lhs.languageCode == rhs.languageCode && lhs.inputLanguageCode == rhs.inputLanguageCode && lhs.entries == rhs.entries && lhs.timestamp == rhs.timestamp {
            return true
        }
        return false
    }
}

extension EmojiKeyword {
    init(apiEmojiKeyword: Api.EmojiKeyword) {
        switch apiEmojiKeyword {
            case let .emojiKeyword(keyword, emoticons):
                self = .keyword(keyword, emoticons)
            case let .emojiKeywordDeleted(keyword, emoticons):
                self = .keywordSubtrahend(keyword, emoticons)
        }
    }
}

public final class EmojiKeywordsMap: PreferencesEntry, Equatable {
    public let entries: [String: EmojiKeywords]
    
    public static var defaultValue: EmojiKeywordsMap {
        return EmojiKeywordsMap(entries: [:])
    }
    
    public init(entries: [String: EmojiKeywords]) {
        self.entries = entries
    }
    
    public init(decoder: PostboxDecoder) {
        self.entries = decoder.decodeObjectDictionaryForKey("entries", keyDecoder: { decoder in
            return decoder.decodeStringForKey("k", orElse: "")
        }, valueDecoder: { decoder in
            return EmojiKeywords(decoder: decoder)
        })
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObjectDictionary(self.entries, forKey: "entries", keyEncoder: { key, encoder in
            encoder.encodeString(key, forKey: "k")
        })
    }
    
    public func isEqual(to: PreferencesEntry) -> Bool {
        if let to = to as? EmojiKeywordsMap {
            return self == to
        } else {
            return false
        }
    }
    
    public static func ==(lhs: EmojiKeywordsMap, rhs: EmojiKeywordsMap) -> Bool {
        return lhs.entries == rhs.entries
    }
}

private func updateEmojiKeywordsList(accountManager: AccountManager, _ f: @escaping (EmojiKeywordsMap) -> EmojiKeywordsMap) -> Void {
    let _ = accountManager.transaction({ transaction -> Void in
        transaction.updateSharedData(SharedDataKeys.emojiKeywords, { entry in
            let current: EmojiKeywordsMap
            if let entry = entry as? EmojiKeywordsMap {
                current = entry
            } else {
                current = .defaultValue
            }
            return f(current)
        })
    }).start()
}

private let refreshTimeout: Int32 = 60 * 60

public enum DownloadEmojiKeywordsError {
    case generic
    case invalidLanguageCode
}

private func downloadEmojiKeywords(network: Network, inputLanguageCode: String) -> Signal<EmojiKeywords, DownloadEmojiKeywordsError> {
    return network.request(Api.functions.messages.getEmojiKeywords(langCode: inputLanguageCode))
    |> mapError { _ -> DownloadEmojiKeywordsError in
        return .generic
    }
    |> map { result -> EmojiKeywords in
        switch result {
            case let .emojiKeywordsDifference(langCode, _, version, keywords):
                var entries: [String: EmojiKeyword] = [:]
                for apiEmojiKeyword in keywords {
                    let emojiKeyword = EmojiKeyword(apiEmojiKeyword: apiEmojiKeyword)
                    entries[emojiKeyword.name] = emojiKeyword
                }
                return EmojiKeywords(languageCode: langCode, inputLanguageCode: inputLanguageCode, version: version, timestamp: Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970), entries: entries)
        }
    }
}

private func downloadEmojiKeywordsDifference(network: Network, languageCode: String, inputLanguageCode: String, fromVersion: Int32) -> Signal<EmojiKeywords, DownloadEmojiKeywordsError> {
    return network.request(Api.functions.messages.getEmojiKeywordsDifference(langCode: languageCode, fromVersion: fromVersion))
    |> mapError { _ -> DownloadEmojiKeywordsError in
        return .generic
    }
    |> mapToSignal { result -> Signal<EmojiKeywords, DownloadEmojiKeywordsError> in
        switch result {
            case let .emojiKeywordsDifference(langCode, _, version, keywords):
                if langCode == languageCode {
                    var entries: [String: EmojiKeyword] = [:]
                    for apiEmojiKeyword in keywords {
                        let emojiKeyword = EmojiKeyword(apiEmojiKeyword: apiEmojiKeyword)
                        entries[emojiKeyword.name] = emojiKeyword
                    }
                    return .single(EmojiKeywords(languageCode: langCode, inputLanguageCode: inputLanguageCode, version: version, timestamp: Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970), entries: entries))
                } else {
                    return .fail(.invalidLanguageCode)
                }
        }
    }
}

public func emojiKeywords(accountManager: AccountManager, network: Network, inputLanguageCode: String) -> Signal<EmojiKeywords?, NoError> {
    return accountManager.sharedData(keys: [SharedDataKeys.emojiKeywords])
//    |> take(1)
    |> map { sharedData in
        return sharedData.entries[SharedDataKeys.emojiKeywords] as? EmojiKeywordsMap ?? .defaultValue
    }
    |> mapToSignal { keywordsMap -> Signal<EmojiKeywords?, NoError> in
        let timestamp = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
        
        let downloadEmojiKeywordsSignal: Signal<EmojiKeywords?, NoError> = downloadEmojiKeywords(network: network, inputLanguageCode: inputLanguageCode)
        |> map(Optional.init)
        |> `catch` { _ -> Signal<EmojiKeywords?, NoError> in
            return .single(nil)
        }
        |> mapToSignal { keywords -> Signal<EmojiKeywords?, NoError> in
            if let keywords = keywords {
                updateEmojiKeywordsList(accountManager: accountManager, { keywordsMap -> EmojiKeywordsMap in
                    var entries = keywordsMap.entries
                    entries[inputLanguageCode] = keywords
                    return EmojiKeywordsMap(entries: entries)
                })
            }
            return .complete()
        }
        
        if let emojiKeywords = keywordsMap.entries[inputLanguageCode] {
            if emojiKeywords.timestamp + refreshTimeout > timestamp {
                return .single(emojiKeywords)
            } else {
                return .single(emojiKeywords) |> then(downloadEmojiKeywordsDifference(network: network, languageCode: emojiKeywords.languageCode, inputLanguageCode: inputLanguageCode, fromVersion: emojiKeywords.version)
                    |> map(Optional.init)
                    |> `catch` { _ -> Signal<EmojiKeywords?, NoError> in
                        return .single(nil)
                    }
                    |> mapToSignal { differenceKeywords -> Signal<EmojiKeywords?, NoError> in
                        if let differenceKeywords = differenceKeywords {
                            var updatedKeywords = emojiKeywords
                            var updatedKeywordEntries: [String: EmojiKeyword] = emojiKeywords.entries
                            for differenceKeywordEntry in differenceKeywords.entries.values {
                                let name = differenceKeywordEntry.name
                                if let existingKeyword = updatedKeywordEntries[name] {
                                    updatedKeywordEntries[name] = existingKeyword.union(differenceKeywordEntry)
                                } else if case .keyword = differenceKeywordEntry {
                                    updatedKeywordEntries[name] = differenceKeywordEntry
                                }
                            }
                            updatedKeywords = EmojiKeywords(languageCode: differenceKeywords.languageCode, inputLanguageCode: inputLanguageCode, version: differenceKeywords.version, timestamp: Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970), entries: updatedKeywordEntries)
                            
                            updateEmojiKeywordsList(accountManager: accountManager, { keywordsMap -> EmojiKeywordsMap in
                                var entries = keywordsMap.entries
                                entries[inputLanguageCode] = updatedKeywords
                                return EmojiKeywordsMap(entries: entries)
                            })
                            return .single(updatedKeywords)
                        } else {
                            return downloadEmojiKeywordsSignal
                        }
                })
            }
        } else {
            return downloadEmojiKeywordsSignal
        }
    }
}

public func searchEmojiKeywords(keywords: EmojiKeywords, query: String, completeMatch: Bool) -> Signal<[(String, String)], NoError> {
    return Signal { subscriber in
        let query = query.lowercased()
        
        var existing = Set<String>()
        var matched: [(String, String)] = []
        if completeMatch {
            if let keyword = keywords.entries[query], case let .keyword(name, emoticons) = keyword {
                for emoticon in emoticons {
                    if !existing.contains(emoticon) {
                        existing.insert(emoticon)
                        matched.append((name, emoticon))
                    }
                }
            }
        } else {
            let sortedEntries = keywords.entries.sorted(by: { lhs, rhs -> Bool in
                if lhs.key.count == rhs.key.count {
                    return lhs.key < rhs.key
                } else {
                    return lhs.key.count < rhs.key.count
                }
            })
            for case let .keyword(name, emoticons) in sortedEntries.map ({ $0.value }) {
                if name.hasPrefix(query) {
                    for emoticon in emoticons {
                        if !existing.contains(emoticon) {
                            existing.insert(emoticon)
                            matched.append((name, emoticon))
                        }
                    }
                }
            }
        }
        
        subscriber.putNext(matched)
        subscriber.putCompletion()
        
        return EmptyDisposable
    } |> runOn(Queue.concurrentDefaultQueue())
}
