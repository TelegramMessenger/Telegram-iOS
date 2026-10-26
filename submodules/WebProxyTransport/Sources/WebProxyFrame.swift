import Foundation

public enum WebProxyProtocol {
    public static let headerSize = 8
    public static let initialWindow = 4 * 1024 * 1024
    public static let maximumPayload = 1024 * 1024
    public static let maximumDataPayload = 64 * 1024
    public static let defaultBatchSize = 2 * 1024 * 1024
    public static let maximumBatchFrames = 4096
    public static let maximumQueuedBytes = 32 * 1024 * 1024
    public static let maximumQueuedItems = 16384
    public static let tombstoneCount = 4096
    public static let maximumStreamId: UInt32 = 0x00ff_ffff
}

public enum WebProxyFrameType: UInt8, CaseIterable {
    case open = 0x01
    case data = 0x02
    case close = 0x03
    case window = 0x04
    case ping = 0x05
    case pong = 0x06
    case hello = 0x10
    case welcome = 0x11
    case bye = 0x1f
}

public struct WebProxyFrame: Equatable {
    public let type: WebProxyFrameType
    public let streamId: UInt32
    public let payload: Data

    public init(type: WebProxyFrameType, streamId: UInt32, payload: Data = Data()) {
        self.type = type
        self.streamId = streamId
        self.payload = payload
    }

    public func validated() throws -> WebProxyFrame {
        guard self.streamId <= WebProxyProtocol.maximumStreamId,
              self.payload.count <= WebProxyProtocol.maximumPayload else {
            throw WebProxyFrameError.invalidFrame
        }
        switch self.type {
        case .open, .close:
            guard self.streamId != 0 && self.payload.isEmpty else { throw WebProxyFrameError.invalidFrame }
        case .data:
            guard self.streamId != 0 && !self.payload.isEmpty else { throw WebProxyFrameError.invalidFrame }
        case .window:
            guard self.streamId != 0, self.payload.count == 4, self.windowDelta != 0 else { throw WebProxyFrameError.invalidFrame }
        case .ping, .pong:
            guard self.streamId == 0 else { throw WebProxyFrameError.invalidFrame }
        case .hello:
            guard self.streamId == 0 && self.payload == Data([1]) else { throw WebProxyFrameError.invalidFrame }
        case .welcome:
            guard self.streamId == 0 && self.payload.isEmpty else { throw WebProxyFrameError.invalidFrame }
        case .bye:
            guard self.streamId == 0 else { throw WebProxyFrameError.invalidFrame }
        }
        return self
    }

    public var windowDelta: UInt32? {
        guard self.payload.count == 4 else { return nil }
        return self.payload.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
    }

    public static func window(streamId: UInt32, delta: UInt32) -> WebProxyFrame {
        return WebProxyFrame(type: .window, streamId: streamId, payload: Data([
            UInt8((delta >> 24) & 0xff), UInt8((delta >> 16) & 0xff),
            UInt8((delta >> 8) & 0xff), UInt8(delta & 0xff)
        ]))
    }
}

public enum WebProxyFrameError: Error, Equatable {
    case invalidFrame
    case unknownType
    case bufferLimitExceeded
}

public enum WebProxyFrameEncoder {
    public static func encode(_ frame: WebProxyFrame) throws -> Data {
        let frame = try frame.validated()
        let length = UInt32(frame.payload.count)
        var data = Data(capacity: WebProxyProtocol.headerSize + frame.payload.count)
        data.append(frame.type.rawValue)
        data.append(UInt8((frame.streamId >> 16) & 0xff))
        data.append(UInt8((frame.streamId >> 8) & 0xff))
        data.append(UInt8(frame.streamId & 0xff))
        data.append(UInt8((length >> 24) & 0xff))
        data.append(UInt8((length >> 16) & 0xff))
        data.append(UInt8((length >> 8) & 0xff))
        data.append(UInt8(length & 0xff))
        data.append(frame.payload)
        return data
    }
}

public final class WebProxyFrameDecoder {
    private var buffer = Data()

    public init() {
    }

    public func append(_ data: Data) throws -> [WebProxyFrame] {
        let maximumBufferedSize = WebProxyProtocol.maximumQueuedBytes
        guard self.buffer.count <= maximumBufferedSize,
              data.count <= maximumBufferedSize - self.buffer.count else {
            throw WebProxyFrameError.bufferLimitExceeded
        }
        self.buffer.append(data)
        var result: [WebProxyFrame] = []
        while self.buffer.count >= WebProxyProtocol.headerSize {
            guard let type = WebProxyFrameType(rawValue: self.buffer[0]) else {
                throw WebProxyFrameError.unknownType
            }
            let streamId = (UInt32(self.buffer[1]) << 16) | (UInt32(self.buffer[2]) << 8) | UInt32(self.buffer[3])
            let length = (UInt32(self.buffer[4]) << 24) | (UInt32(self.buffer[5]) << 16) | (UInt32(self.buffer[6]) << 8) | UInt32(self.buffer[7])
            guard length <= UInt32(WebProxyProtocol.maximumPayload) else {
                throw WebProxyFrameError.invalidFrame
            }
            let frameLength = WebProxyProtocol.headerSize + Int(length)
            guard self.buffer.count >= frameLength else { break }
            let payload = self.buffer.subdata(in: WebProxyProtocol.headerSize ..< frameLength)
            let frame = try WebProxyFrame(type: type, streamId: streamId, payload: payload).validated()
            result.append(frame)
            guard result.count <= WebProxyProtocol.maximumBatchFrames else {
                throw WebProxyFrameError.bufferLimitExceeded
            }
            self.buffer.removeSubrange(0 ..< frameLength)
        }
        return result
    }
}
