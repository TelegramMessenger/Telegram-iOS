import Foundation
import Postbox
import MtProtoKit

/// A widget message's media (`messageMediaWidget width:int height:int payload:bytes`, layer 233; widget-sandbox v0.1.0
/// tgw-format.md): the bot's size anchors and the widget's HTML, gzipped by the server. The client gunzips it and adds no
/// size check of its own: the server bounds the HTML at 32 KB and the payload at 4 KB.
public final class TelegramMediaWidget: Media, Equatable {
    /// The width anchor in CSS px; 0 is auto (the bubble's width).
    public let width: Int32
    /// The height anchor in CSS px; 0 is auto (the content's height).
    public let height: Int32
    /// The widget's HTML, gzipped, as the server sends it.
    public let payload: Data

    public let peerIds: [PeerId] = []

    public var id: MediaId? {
        return nil
    }

    public init(width: Int32, height: Int32, payload: Data) {
        self.width = width
        self.height = height
        self.payload = payload
    }

    /// `html` gzipped as the server gzips it (for local messages); nil only if compression fails.
    public convenience init?(html: String, width: Int32, height: Int32) {
        guard let payload = MTGzip.compress(Data(html.utf8)) else {
            return nil
        }
        self.init(width: width, height: height, payload: payload)
    }

    public init(decoder: PostboxDecoder) {
        self.width = decoder.decodeInt32ForKey("w", orElse: 0)
        self.height = decoder.decodeInt32ForKey("h", orElse: 0)
        self.payload = decoder.decodeDataForKey("p") ?? Data()
    }

    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.width, forKey: "w")
        encoder.encodeInt32(self.height, forKey: "h")
        encoder.encodeData(self.payload, forKey: "p")
    }

    /// The widget's HTML: the payload gunzipped (strictly: nil on any inflate error or an unfinished stream), nil unless
    /// it is gzip and UTF-8.
    public func html() -> String? {
        guard self.payload.count >= 2, self.payload[self.payload.startIndex] == 0x1f, self.payload[self.payload.startIndex + 1] == 0x8b else {
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
        return self.width == other.width && self.height == other.height && self.payload == other.payload
    }

    public func isSemanticallyEqual(to other: Media) -> Bool {
        return self.isEqual(to: other)
    }
}
