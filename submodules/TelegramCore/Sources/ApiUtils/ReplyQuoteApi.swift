import Foundation
import Postbox
internal import TelegramApi

/// `inputReplyToMessage`'s quote fields and the flags they set.
struct ApiReplyQuoteFields {
    var flags: Int32 = 0
    var text: String?
    var entities: [Api.MessageEntity]?
    var offset: Int32?
    var rich: [Api.RichText]?
}

/// The quote fields for `quote`. A rich quote travels as `quote_rich` alone: the server rejects it
/// alongside `quote_text`/`quote_entities` (`QUOTE_TEXT_INVALID`).
func apiReplyQuoteFields(_ quote: EngineMessageReplyQuote?, peer: (PeerId) -> Peer?) -> ApiReplyQuoteFields {
    var result = ApiReplyQuoteFields()
    guard let quote else {
        return result
    }
    if let richText = quote.richText {
        result.flags |= 1 << 8
        result.rich = richText.map { $0.apiRichText() }
    } else {
        result.flags |= 1 << 2
        result.text = quote.text
        if !quote.entities.isEmpty {
            var associatedPeers = SimpleDictionary<PeerId, Peer>()
            for entity in quote.entities {
                for associatedPeerId in entity.associatedPeerIds where associatedPeers[associatedPeerId] == nil {
                    if let associatedPeer = peer(associatedPeerId) {
                        associatedPeers[associatedPeerId] = associatedPeer
                    }
                }
            }
            result.flags |= 1 << 3
            result.entities = apiEntitiesFromMessageTextEntities(quote.entities, associatedPeers: associatedPeers)
        }
    }
    if let offset = quote.offset {
        result.flags |= 1 << 4
        result.offset = Int32(clamping: offset)
    }
    return result
}

/// The quote a reply header or a draft's `inputReplyToMessage` carries; a non-empty `quote_rich`
/// wins over the flat fields.
func engineReplyQuote(text: String?, entities: [Api.MessageEntity]?, offset: Int32?, rich: [Api.RichText]?, media: Media?) -> EngineMessageReplyQuote? {
    if let rich, !rich.isEmpty {
        return EngineMessageReplyQuote(richText: rich.map(RichText.init(apiText:)), offset: offset.flatMap(Int.init), media: media)
    }
    if text != nil || media != nil {
        return EngineMessageReplyQuote(text: text ?? "", offset: offset.flatMap(Int.init), entities: messageTextEntitiesFromApiEntities(entities ?? []), media: media)
    }
    return nil
}
