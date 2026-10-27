import Foundation
import XCTest
import TelegramApi

/// A chat as the truth server names it. `selfUser` is `inputPeerSelf`, the account's own chat (Saved Messages).
enum TruthPeer: Hashable, CustomStringConvertible {
    case user(Int64)
    case chat(Int64)
    case channel(Int64)
    case selfUser

    var description: String {
        switch self {
        case let .user(id):
            return "user\(id)"
        case let .chat(id):
            return "chat\(id)"
        case let .channel(id):
            return "channel\(id)"
        case .selfUser:
            return "self"
        }
    }
}

/// A request state sync sends, with the arguments the truth server answers from, decoded from the bytes
/// `ScriptedServer` records (`ScriptedRequest.payload`, the boxed function). Layouts are `swift_scheme.tl`'s.
enum TruthRequest: Equatable {
    case getState
    case getDifference(pts: Int32, ptsLimit: Int32?, ptsTotalLimit: Int32?, date: Int32, qts: Int32)
    case getChannelDifference(channelId: Int64, pts: Int32, limit: Int32)
    case getHistory(peer: TruthPeer, offsetId: Int32, addOffset: Int32, limit: Int32, maxId: Int32, minId: Int32)
    case getMessages(ids: [Int32])
    case channelsGetMessages(channelId: Int64, ids: [Int32])
    case getDialogs(folderId: Int32?, offsetDate: Int32, offsetId: Int32, offsetPeer: TruthPeer?, limit: Int32)
    case getPinnedDialogs(folderId: Int32)
    /// `inputDialogPeerFolder` entries are left out: the truth server keeps no folders.
    case getPeerDialogs(peers: [TruthPeer])
    case other(name: String)
}

private enum TruthTL {
    static let vector = Int32(bitPattern: 0x1cb5c415)

    static let getState = Int32(bitPattern: 0xedd4882a)
    static let getDifference = Int32(bitPattern: 0x19c2f763)
    static let getChannelDifference = Int32(bitPattern: 0x03173d78)
    static let getHistory = Int32(bitPattern: 0x4423e6c5)
    static let getMessages = Int32(bitPattern: 0x63c66506)
    static let channelsGetMessages = Int32(bitPattern: 0xad8c9a23)
    static let getDialogs = Int32(bitPattern: 0xa0f4cb4f)
    static let getPinnedDialogs = Int32(bitPattern: 0xd6b94df2)
    static let getPeerDialogs = Int32(bitPattern: 0xe470bcfd)

    static let inputPeerEmpty = Int32(bitPattern: 0x7f3b18ea)
    static let inputPeerSelf = Int32(bitPattern: 0x7da07ec9)
    static let inputPeerChat = Int32(bitPattern: 0x35a95cb9)
    static let inputPeerUser = Int32(bitPattern: 0xdde8a54c)
    static let inputPeerChannel = Int32(bitPattern: 0x27bcbbfc)
    static let inputChannel = Int32(bitPattern: 0xf35aec28)
    static let inputMessageID = Int32(bitPattern: 0xa676a322)
    static let inputMessageReplyTo = Int32(bitPattern: 0xbad88395)
    static let inputDialogPeer = Int32(bitPattern: 0xfcaafeb7)
    static let inputDialogPeerFolder = Int32(bitPattern: 0x64600527)
    static let channelMessagesFilterEmpty = Int32(bitPattern: 0x94d42ee7)
}

private struct TruthDecodeError: Error {
    let what: String
}

/// Reads one boxed function, field by field, and throws on anything it does not expect.
private final class TruthTLReader {
    private let reader: BufferReader

    init(_ data: Data) {
        self.reader = BufferReader(Buffer(data: data))
    }

    func int32(_ what: String) throws -> Int32 {
        guard let value = self.reader.readInt32() else {
            throw TruthDecodeError(what: what)
        }
        return value
    }

    func int64(_ what: String) throws -> Int64 {
        guard let value = self.reader.readInt64() else {
            throw TruthDecodeError(what: what)
        }
        return value
    }

    func vector<T>(_ what: String, _ item: () throws -> T?) throws -> [T] {
        guard try self.int32("\(what) vector") == TruthTL.vector else {
            throw TruthDecodeError(what: "\(what) vector constructor")
        }
        let count = try self.int32("\(what) count")
        var result: [T] = []
        for _ in 0 ..< Int(count) {
            if let value = try item() {
                result.append(value)
            }
        }
        return result
    }

    /// `inputPeerEmpty` is nil.
    func inputPeer() throws -> TruthPeer? {
        let constructor = try self.int32("InputPeer")
        switch constructor {
        case TruthTL.inputPeerEmpty:
            return nil
        case TruthTL.inputPeerSelf:
            return .selfUser
        case TruthTL.inputPeerChat:
            return .chat(try self.int64("chat_id"))
        case TruthTL.inputPeerUser:
            let userId = try self.int64("user_id")
            let _ = try self.int64("access_hash")
            return .user(userId)
        case TruthTL.inputPeerChannel:
            let channelId = try self.int64("channel_id")
            let _ = try self.int64("access_hash")
            return .channel(channelId)
        default:
            throw TruthDecodeError(what: "InputPeer \(String(UInt32(bitPattern: constructor), radix: 16))")
        }
    }

    func inputChannelId() throws -> Int64 {
        guard try self.int32("InputChannel") == TruthTL.inputChannel else {
            throw TruthDecodeError(what: "InputChannel constructor")
        }
        let channelId = try self.int64("channel_id")
        let _ = try self.int64("access_hash")
        return channelId
    }

    func inputMessageId() throws -> Int32 {
        let constructor = try self.int32("InputMessage")
        switch constructor {
        case TruthTL.inputMessageID, TruthTL.inputMessageReplyTo:
            return try self.int32("id")
        default:
            throw TruthDecodeError(what: "InputMessage \(String(UInt32(bitPattern: constructor), radix: 16))")
        }
    }
}

private func decodeTruthRequestOrThrow(_ payload: Data) throws -> TruthRequest? {
    let reader = TruthTLReader(payload)
    let constructor = try reader.int32("constructor")
    switch constructor {
    case TruthTL.getState:
        return .getState
    case TruthTL.getDifference:
        let flags = try reader.int32("flags")
        let pts = try reader.int32("pts")
        let ptsLimit: Int32? = try (flags & (1 << 1)) != 0 ? reader.int32("pts_limit") : nil
        let ptsTotalLimit: Int32? = try (flags & (1 << 0)) != 0 ? reader.int32("pts_total_limit") : nil
        let date = try reader.int32("date")
        let qts = try reader.int32("qts")
        return .getDifference(pts: pts, ptsLimit: ptsLimit, ptsTotalLimit: ptsTotalLimit, date: date, qts: qts)
    case TruthTL.getChannelDifference:
        let _ = try reader.int32("flags")
        let channelId = try reader.inputChannelId()
        guard try reader.int32("filter") == TruthTL.channelMessagesFilterEmpty else {
            throw TruthDecodeError(what: "a channel difference filter other than channelMessagesFilterEmpty")
        }
        let pts = try reader.int32("pts")
        let limit = try reader.int32("limit")
        return .getChannelDifference(channelId: channelId, pts: pts, limit: limit)
    case TruthTL.getHistory:
        guard let peer = try reader.inputPeer() else {
            throw TruthDecodeError(what: "getHistory of inputPeerEmpty")
        }
        let offsetId = try reader.int32("offset_id")
        let _ = try reader.int32("offset_date")
        let addOffset = try reader.int32("add_offset")
        let limit = try reader.int32("limit")
        let maxId = try reader.int32("max_id")
        let minId = try reader.int32("min_id")
        let _ = try reader.int64("hash")
        return .getHistory(peer: peer, offsetId: offsetId, addOffset: addOffset, limit: limit, maxId: maxId, minId: minId)
    case TruthTL.getMessages:
        return .getMessages(ids: try reader.vector("id") { try reader.inputMessageId() })
    case TruthTL.channelsGetMessages:
        let channelId = try reader.inputChannelId()
        return .channelsGetMessages(channelId: channelId, ids: try reader.vector("id") { try reader.inputMessageId() })
    case TruthTL.getDialogs:
        let flags = try reader.int32("flags")
        let folderId: Int32? = try (flags & (1 << 1)) != 0 ? reader.int32("folder_id") : nil
        let offsetDate = try reader.int32("offset_date")
        let offsetId = try reader.int32("offset_id")
        let offsetPeer = try reader.inputPeer()
        let limit = try reader.int32("limit")
        let _ = try reader.int64("hash")
        return .getDialogs(folderId: folderId, offsetDate: offsetDate, offsetId: offsetId, offsetPeer: offsetPeer, limit: limit)
    case TruthTL.getPinnedDialogs:
        return .getPinnedDialogs(folderId: try reader.int32("folder_id"))
    case TruthTL.getPeerDialogs:
        let peers = try reader.vector("peers") { () -> TruthPeer? in
            let constructor = try reader.int32("InputDialogPeer")
            switch constructor {
            case TruthTL.inputDialogPeer:
                return try reader.inputPeer()
            case TruthTL.inputDialogPeerFolder:
                let _ = try reader.int32("folder_id")
                return nil
            default:
                throw TruthDecodeError(what: "InputDialogPeer \(String(UInt32(bitPattern: constructor), radix: 16))")
            }
        }
        return .getPeerDialogs(peers: peers)
    default:
        return nil
    }
}

/// The request `payload` carries (`name` is the function's name, `ScriptedRequest.name`). A function the truth server
/// does not know is `.other`; one it knows whose bytes do not decode fails the running test, naming the field.
func decodeTruthRequest(name: String, payload: Data) -> TruthRequest {
    do {
        if let request = try decodeTruthRequestOrThrow(payload) {
            return request
        }
    } catch let error as TruthDecodeError {
        XCTFail("truth server: \(name) does not decode: \(error.what)")
    } catch {
        XCTFail("truth server: \(name) does not decode: \(error)")
    }
    return .other(name: name)
}
