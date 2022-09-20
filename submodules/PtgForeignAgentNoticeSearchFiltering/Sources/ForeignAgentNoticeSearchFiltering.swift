import Foundation
import Postbox
import Display
import TelegramCore
import PtgForeignAgentNoticeRemoval

private let WebContentTextLimit = 500 // it seems Telegram indexes around 500 first characters of attached webpage text
private let ForeignAgentNoticeLen = 221 // don't need precise number here

// this function does not guarantee 100% match with search results from Telegram servers, but in most cases it should provide valid results
public func findSearchResultsMatchedOnlyBecauseOfForeignAgentNotice(messages: [Message], query: String) -> Set<MessageId> {
    if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        return []
    }
    
    var matchesOnlyBcOfFAN: Set<MessageId> = []
    
    for message in messages {
        if !message.text.isEmpty {
            let (cleanedText, cleanedEntities) = removeForeignAgentNotice(text: message.text, entities: message.textEntitiesAttribute?.entities ?? [], media: message.media)
            
            var webpageContent: TelegramMediaWebpageLoadedContent?
            var originalWebpageSearchedText: Substring?
            var cleanedWebpageSearchedText: Substring?
            
            if let webpage = message.media.first(where: { $0 is TelegramMediaWebpage }) as? TelegramMediaWebpage {
                if case let .Loaded(content) = webpage.content {
                    webpageContent = content
                    
                    if let contentText = content.text {
                        var endIndex = contentText.index(contentText.startIndex, offsetBy: WebContentTextLimit, limitedBy: contentText.endIndex) ?? contentText.endIndex
                        if let _ = content.instantPage, let newLineIndex = contentText[..<endIndex].firstIndex(where: { $0.isNewline }) {
                            endIndex = newLineIndex
                        }
                        
                        originalWebpageSearchedText = contentText[..<endIndex]
                        cleanedWebpageSearchedText = originalWebpageSearchedText

                        let searchEndIndex = contentText.index(endIndex, offsetBy: ForeignAgentNoticeLen, limitedBy: contentText.endIndex) ?? contentText.endIndex
                        if let matchResult = foreignAgentNoticeRegEx.firstMatch(in: contentText, range: NSRange(..<searchEndIndex, in: contentText)), let matchRange = Range(matchResult.range, in: contentText) {
                            cleanedWebpageSearchedText!.removeSubrange(matchRange.upperBound > endIndex ? matchRange.lowerBound..<endIndex : matchRange)
                        }
                    }
                }
            }

            if cleanedText != message.text || cleanedWebpageSearchedText != originalWebpageSearchedText {
                let cleanedSearchedTextCombined = combineSearchedText(cleanedText, entities: cleanedEntities, forwardInfo: message.forwardInfo, webpageTitle: webpageContent?.title, webpageText: cleanedWebpageSearchedText)

                let (cleanedTextRanges, _) = findSubstringRanges(in: cleanedSearchedTextCombined, query: query)
                if cleanedTextRanges.isEmpty {
                    let originalSearchedTextCombined = combineSearchedText(message.text, entities: message.textEntitiesAttribute?.entities, forwardInfo: message.forwardInfo, webpageTitle: webpageContent?.title, webpageText: originalWebpageSearchedText)

                    let (originalTextRanges, _) = findSubstringRanges(in: originalSearchedTextCombined, query: query)
                    if !originalTextRanges.isEmpty {
                        matchesOnlyBcOfFAN.insert(message.id)
                    }
                }
            }
        }
    }
    
    return matchesOnlyBcOfFAN
}

private func combineSearchedText(_ initialText: String, entities: [MessageTextEntity]?, forwardInfo: MessageForwardInfo?, webpageTitle: String?, webpageText: Substring?) -> String {
    var text = initialText
    
    if let entities = entities {
        for entity in entities {
            if case let .TextUrl(url) = entity.type {
                text.append(" ")
                text.append(url)
            }
        }
    }

    if let forwardInfo = forwardInfo, let author = forwardInfo.author {
        text.append(" ")
        text.append(author.debugDisplayTitle)
    }
    
    if let webpageTitle = webpageTitle {
        text.append(" ")
        text.append(webpageTitle)
    }
    
    if let webpageText = webpageText {
        text.append(" ")
        text.append(contentsOf: webpageText)
    }
    
    return text
}
