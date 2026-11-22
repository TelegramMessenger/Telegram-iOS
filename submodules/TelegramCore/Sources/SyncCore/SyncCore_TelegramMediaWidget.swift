import Foundation
import Postbox
import MtProtoKit
import zlib

/// A widget message's media (`messageMediaWidget flags:# is_copy:flags.0?true can_query:flags.1?true
/// background_query:flags.2?true width:int height:int payload:bytes public_data:flags.3?string
/// public_data_hash:flags.3?long chat_data:flags.4?string widget_id:flags.5?long`, layer 233, the 2026-10-27 schema;
/// widget-sandbox tgw-format.md): the bot's size anchors and the widget's HTML,
/// compressed by the server: a zlib stream since v0.1.3 (PHP's `gzcompress($html, 9)`), gzip before. The client inflates
/// either and adds no size check of its own: the server bounds the HTML at 32 KB and the payload at 4 KB. Never
/// Compression's `COMPRESSION_ZLIB`: raw deflate despite the name. Since widget-sandbox v0.2 it also carries the server's
/// flags for what the widget may do here and the bot's state (sdk-v1 §2.13, §2.14).
public final class TelegramMediaWidget: Media, Equatable {
    /// The width anchor in CSS px; 0 is auto (the bubble's width).
    public let width: Int32
    /// The height anchor in CSS px; 0 is auto (the content's height).
    public let height: Int32
    /// The widget's HTML, compressed, as the server sends it.
    public let payload: Data
    /// `is_copy`: a forwarded copy (never any chat state).
    public let isCopy: Bool
    /// `can_query`: the widget may send requests to its bot, on a tap.
    public let canQuery: Bool
    /// `background_query`: requests without a tap too (the original in the private chat with the bot).
    public let backgroundQuery: Bool
    /// `chat_data`, the bot's chat state, as the server sent it: text of up to 1024 bytes by the server's rule, but kept as
    /// bytes, so that the runtime's check (not a lenient decode here) decides what the widget sees.
    public let chatData: Data?
    /// `public_data`, the bot's shared state, kept as bytes like `chatData`.
    public let publicData: Data?
    /// `public_data_hash`: the hash of `publicData` (2026-10-27 schema), which a poll of the shared widget starts from.
    public let publicDataHash: Int64?
    /// `widget_id`: the shared widget this message carries (its shared state is polled by this id).
    public let widgetId: Int64?

    public let peerIds: [PeerId] = []

    public var id: MediaId? {
        return nil
    }

    public init(width: Int32, height: Int32, payload: Data, isCopy: Bool = false, canQuery: Bool = false, backgroundQuery: Bool = false, chatData: Data? = nil, publicData: Data? = nil, publicDataHash: Int64? = nil, widgetId: Int64? = nil) {
        self.width = width
        self.height = height
        self.payload = payload
        self.isCopy = isCopy
        self.canQuery = canQuery
        self.backgroundQuery = backgroundQuery
        self.chatData = chatData
        self.publicData = publicData
        self.publicDataHash = publicDataHash
        self.widgetId = widgetId
    }

    /// `html` compressed as the server compresses it, zlib at level 9 (for local messages); nil only if compression fails.
    public convenience init?(html: String, width: Int32, height: Int32) {
        let source = Data(html.utf8)
        var payload = Data(count: Int(compressBound(uLong(source.count))))
        var length = uLongf(payload.count)
        let status = payload.withUnsafeMutableBytes { output in
            source.withUnsafeBytes { input in
                compress2(output.bindMemory(to: Bytef.self).baseAddress, &length, input.bindMemory(to: Bytef.self).baseAddress, uLong(source.count), 9)
            }
        }
        guard status == Z_OK else {
            return nil
        }
        payload.count = Int(length)
        self.init(width: width, height: height, payload: payload)
    }

    public init(decoder: PostboxDecoder) {
        self.width = decoder.decodeInt32ForKey("w", orElse: 0)
        self.height = decoder.decodeInt32ForKey("h", orElse: 0)
        self.payload = decoder.decodeDataForKey("p") ?? Data()
        // A message stored before widget-sandbox v0.2 has none of these.
        let flags = decoder.decodeInt32ForKey("f", orElse: 0)
        self.isCopy = (flags & (1 << 0)) != 0
        self.canQuery = (flags & (1 << 1)) != 0
        self.backgroundQuery = (flags & (1 << 2)) != 0
        self.chatData = decoder.decodeDataForKey("cd")
        self.publicData = decoder.decodeDataForKey("pd")
        self.publicDataHash = decoder.decodeOptionalInt64ForKey("ph")
        self.widgetId = decoder.decodeOptionalInt64ForKey("wi")
    }

    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.width, forKey: "w")
        encoder.encodeInt32(self.height, forKey: "h")
        encoder.encodeData(self.payload, forKey: "p")
        var flags: Int32 = 0
        if self.isCopy {
            flags |= 1 << 0
        }
        if self.canQuery {
            flags |= 1 << 1
        }
        if self.backgroundQuery {
            flags |= 1 << 2
        }
        encoder.encodeInt32(flags, forKey: "f")
        if let chatData = self.chatData {
            encoder.encodeData(chatData, forKey: "cd")
        }
        if let publicData = self.publicData {
            encoder.encodeData(publicData, forKey: "pd")
        }
        if let publicDataHash = self.publicDataHash {
            encoder.encodeInt64(publicDataHash, forKey: "ph")
        }
        if let widgetId = self.widgetId {
            encoder.encodeInt64(widgetId, forKey: "wi")
        }
    }

    /// The widget's HTML: the payload inflated (strictly: nil on any inflate error or an unfinished stream), nil unless
    /// it is zlib or gzip and UTF-8.
    public func html() -> String? {
        guard self.payload.count >= 2 else {
            return nil
        }
        let first = self.payload[self.payload.startIndex]
        let second = self.payload[self.payload.startIndex + 1]
        // gzip's magic, or a zlib header (RFC 1950): deflate, and CMF·256 + FLG a multiple of 31. MTGzip inflates both.
        let isGzip = first == 0x1f && second == 0x8b
        let isZlib = first & 0x0f == 8 && (UInt16(first) << 8 | UInt16(second)) % 31 == 0
        guard isGzip || isZlib else {
            return nil
        }
        guard let data = MTGzip.decompress(self.payload) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    public static func ==(lhs: TelegramMediaWidget, rhs: TelegramMediaWidget) -> Bool {
        return lhs.isEqual(to: rhs)
    }

    public func isEqual(to other: Media) -> Bool {
        guard let other = other as? TelegramMediaWidget else {
            return false
        }
        return self.width == other.width && self.height == other.height && self.payload == other.payload && self.isCopy == other.isCopy && self.canQuery == other.canQuery && self.backgroundQuery == other.backgroundQuery && self.chatData == other.chatData && self.publicData == other.publicData && self.publicDataHash == other.publicDataHash && self.widgetId == other.widgetId
    }

    public func isSemanticallyEqual(to other: Media) -> Bool {
        return self.isEqual(to: other)
    }

    /// The widget as a forward has it (widget-sandbox v0.2, tgw-format.md: "a forward is a copy"): a copy with no queries
    /// and no chat state; its shared state and widget id stay. A forward's local echo shows this until the server's
    /// message, with the server's own flags, replaces it.
    public func forwardedCopy() -> TelegramMediaWidget {
        return TelegramMediaWidget(width: self.width, height: self.height, payload: self.payload, isCopy: true, canQuery: false, backgroundQuery: false, chatData: nil, publicData: self.publicData, publicDataHash: self.publicDataHash, widgetId: self.widgetId)
    }
}
