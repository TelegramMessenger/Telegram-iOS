import Foundation
import Postbox
import MtProtoKit
import zlib

/// A widget message's media (`messageMediaWidget width:int height:int payload:bytes`, layer 233; widget-sandbox
/// tgw-format.md): the bot's size anchors and the widget's HTML, compressed by the server: a zlib stream since v0.1.3
/// (PHP's `gzcompress($html, 9)`), gzip before. The client inflates either and adds no size check of its own: the server
/// bounds the HTML at 32 KB and the payload at 4 KB. Never Compression's `COMPRESSION_ZLIB`: raw deflate despite the name.
public final class TelegramMediaWidget: Media, EngineCustomMedia, Equatable {
    /// The width anchor in CSS px; 0 is auto (the bubble's width).
    public let width: Int32
    /// The height anchor in CSS px; 0 is auto (the content's height).
    public let height: Int32
    /// The widget's HTML, compressed, as the server sends it.
    public let payload: Data
    public let flags: Int32
    public let publicData: Data?
    public let chatData: Data?
    public let widgetId: Int64?

    public var isCopy: Bool { flags & (1 << 0) != 0 }
    public var canQuery: Bool { flags & (1 << 1) != 0 }
    public var backgroundQuery: Bool { flags & (1 << 2) != 0 }

    public func withUpdatedData(publicData: Data?, chatData: Data?) -> TelegramMediaWidget {
        return TelegramMediaWidget(width: width, height: height, payload: payload, flags: flags, publicData: publicData ?? self.publicData, chatData: chatData ?? self.chatData, widgetId: widgetId)
    }

    public let peerIds: [PeerId] = []

    public var id: MediaId? {
        return nil
    }

    public init(width: Int32, height: Int32, payload: Data, flags: Int32 = 0, publicData: Data? = nil, chatData: Data? = nil, widgetId: Int64? = nil) {
        self.width = width
        self.height = height
        self.payload = payload
        self.flags = flags
        self.publicData = publicData
        self.chatData = chatData
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
        self.flags = decoder.decodeInt32ForKey("f", orElse: 0)
        self.publicData = decoder.decodeDataForKey("pd")
        self.chatData = decoder.decodeDataForKey("cd")
        self.widgetId = decoder.decodeOptionalInt64ForKey("wi")
        self.width = decoder.decodeInt32ForKey("w", orElse: 0)
        self.height = decoder.decodeInt32ForKey("h", orElse: 0)
        self.payload = decoder.decodeDataForKey("p") ?? Data()
    }

    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.width, forKey: "w")
        encoder.encodeInt32(self.height, forKey: "h")
        encoder.encodeData(self.payload, forKey: "p")
        encoder.encodeInt32(flags, forKey: "f")
        if let publicData { encoder.encodeData(publicData, forKey: "pd") } else { encoder.encodeNil(forKey: "pd") }
        if let chatData { encoder.encodeData(chatData, forKey: "cd") } else { encoder.encodeNil(forKey: "cd") }
        if let widgetId { encoder.encodeInt64(widgetId, forKey: "wi") } else { encoder.encodeNil(forKey: "wi") }
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
        return self.width == other.width && self.height == other.height && self.payload == other.payload && flags == other.flags && publicData == other.publicData && chatData == other.chatData && widgetId == other.widgetId
    }

    public func isSemanticallyEqual(to other: Media) -> Bool {
        return self.isEqual(to: other)
    }
}
