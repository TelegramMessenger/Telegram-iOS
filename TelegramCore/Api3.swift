public extension Api {
public struct photos {
    public enum Photo {
        case photo(photo: Api.Photo, users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .photo(let photo, let users):
                    if boxed {
                        buffer.appendInt32(539045032)
                    }
                    photo.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
        static func parse_photo(_ reader: BufferReader) -> Photo? {
            var _1: Api.Photo?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Photo
            }
            var _2: [Api.User]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.photos.Photo.photo(photo: _1!, users: _2!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum Photos {
        case photos(photos: [Api.Photo], users: [Api.User])
        case photosSlice(count: Int32, photos: [Api.Photo], users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .photos(let photos, let users):
                    if boxed {
                        buffer.appendInt32(-1916114267)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(photos.count))
                    for item in photos {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    break
                case .photosSlice(let count, let photos, let users):
                    if boxed {
                        buffer.appendInt32(352657236)
                    }
                    serializeInt32(count, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(photos.count))
                    for item in photos {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
        static func parse_photos(_ reader: BufferReader) -> Photos? {
            var _1: [Api.Photo]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Photo.self)
            }
            var _2: [Api.User]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.photos.Photos.photos(photos: _1!, users: _2!)
            }
            else {
                return nil
            }
        }
        static func parse_photosSlice(_ reader: BufferReader) -> Photos? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Api.Photo]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Photo.self)
            }
            var _3: [Api.User]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.photos.Photos.photosSlice(count: _1!, photos: _2!, users: _3!)
            }
            else {
                return nil
            }
        }
    
    }
}
}
public extension Api {
public struct phone {
    public enum PhoneCall {
        case phoneCall(phoneCall: Api.PhoneCall, users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .phoneCall(let phoneCall, let users):
                    if boxed {
                        buffer.appendInt32(-326966976)
                    }
                    phoneCall.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
        static func parse_phoneCall(_ reader: BufferReader) -> PhoneCall? {
            var _1: Api.PhoneCall?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.PhoneCall
            }
            var _2: [Api.User]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.phone.PhoneCall.phoneCall(phoneCall: _1!, users: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
}
private final class FunctionDescription: CustomStringConvertible {
    let generator: () -> String
    init(_ generator: @escaping () -> String) {
        self.generator = generator
    }

    var description: String {
        return self.generator()
    }
}

public extension Api {
    public struct functions {
            public struct messages {
                public static func getDialogs(flags: Int32, offsetDate: Int32, offsetId: Int32, offsetPeer: Api.InputPeer, limit: Int32) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.messages.Dialogs?) {
                    let buffer = Buffer()
                    buffer.appendInt32(421243333)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(offsetDate, buffer: buffer, boxed: false)
                    serializeInt32(offsetId, buffer: buffer, boxed: false)
                    offsetPeer.serialize(buffer, true)
                    serializeInt32(limit, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(messages.getDialogs flags: \(flags), offsetDate: \(offsetDate), offsetId: \(offsetId), offsetPeer: \(offsetPeer), limit: \(limit))"}), buffer, { (buffer: Buffer) -> Api.messages.Dialogs? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.Dialogs?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.Dialogs
                        }
                        return result
                    })
                }
            
                public static func getHistory(peer: Api.InputPeer, offsetId: Int32, offsetDate: Int32, addOffset: Int32, limit: Int32, maxId: Int32, minId: Int32, hash: Int32) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.messages.Messages?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-591691168)
                    peer.serialize(buffer, true)
                    serializeInt32(offsetId, buffer: buffer, boxed: false)
                    serializeInt32(offsetDate, buffer: buffer, boxed: false)
                    serializeInt32(addOffset, buffer: buffer, boxed: false)
                    serializeInt32(limit, buffer: buffer, boxed: false)
                    serializeInt32(maxId, buffer: buffer, boxed: false)
                    serializeInt32(minId, buffer: buffer, boxed: false)
                    serializeInt32(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(messages.getHistory peer: \(peer), offsetId: \(offsetId), offsetDate: \(offsetDate), addOffset: \(addOffset), limit: \(limit), maxId: \(maxId), minId: \(minId), hash: \(hash))"}), buffer, { (buffer: Buffer) -> Api.messages.Messages? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.Messages?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.Messages
                        }
                        return result
                    })
                }
            
                public static func readHistory(peer: Api.InputPeer, maxId: Int32) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.messages.AffectedMessages?) {
                    let buffer = Buffer()
                    buffer.appendInt32(238054714)
                    peer.serialize(buffer, true)
                    serializeInt32(maxId, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(messages.readHistory peer: \(peer), maxId: \(maxId))"}), buffer, { (buffer: Buffer) -> Api.messages.AffectedMessages? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.AffectedMessages?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.AffectedMessages
                        }
                        return result
                    })
                }
            
                public static func deleteHistory(flags: Int32, peer: Api.InputPeer, maxId: Int32) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.messages.AffectedHistory?) {
                    let buffer = Buffer()
                    buffer.appendInt32(469850889)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    serializeInt32(maxId, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(messages.deleteHistory flags: \(flags), peer: \(peer), maxId: \(maxId))"}), buffer, { (buffer: Buffer) -> Api.messages.AffectedHistory? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.AffectedHistory?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.AffectedHistory
                        }
                        return result
                    })
                }
            
                public static func deleteMessages(flags: Int32, id: [Int32]) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.messages.AffectedMessages?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-443640366)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(id.count))
                    for item in id {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    return (FunctionDescription({return "(messages.deleteMessages flags: \(flags), id: \(id))"}), buffer, { (buffer: Buffer) -> Api.messages.AffectedMessages? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.AffectedMessages?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.AffectedMessages
                        }
                        return result
                    })
                }
            
                public static func receivedMessages(maxId: Int32) -> (CustomStringConvertible, Buffer, (Buffer) -> [Api.ReceivedNotifyMessage]?) {
                    let buffer = Buffer()
                    buffer.appendInt32(94983360)
                    serializeInt32(maxId, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(messages.receivedMessages maxId: \(maxId))"}), buffer, { (buffer: Buffer) -> [Api.ReceivedNotifyMessage]? in
                        let reader = BufferReader(buffer)
                        var result: [Api.ReceivedNotifyMessage]?
                        if let _ = reader.readInt32() {
                            result = Api.parseVector(reader, elementSignature: 0, elementType: Api.ReceivedNotifyMessage.self)
                        }
                        return result
                    })
                }
            
                public static func setTyping(peer: Api.InputPeer, action: Api.SendMessageAction) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Bool?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1551737264)
                    peer.serialize(buffer, true)
                    action.serialize(buffer, true)
                    return (FunctionDescription({return "(messages.setTyping peer: \(peer), action: \(action))"}), buffer, { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func sendMessage(flags: Int32, peer: Api.InputPeer, replyToMsgId: Int32?, message: String, randomId: Int64, replyMarkup: Api.ReplyMarkup?, entities: [Api.MessageEntity]?) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Updates?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-91733382)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(replyToMsgId!, buffer: buffer, boxed: false)}
                    serializeString(message, buffer: buffer, boxed: false)
                    serializeInt64(randomId, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 2) != 0 {replyMarkup!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 3) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(entities!.count))
                    for item in entities! {
                        item.serialize(buffer, true)
                    }}
                    return (FunctionDescription({return "(messages.sendMessage flags: \(flags), peer: \(peer), replyToMsgId: \(String(describing: replyToMsgId)), message: \(message), randomId: \(randomId), replyMarkup: \(String(describing: replyMarkup)), entities: \(String(describing: entities)))"}), buffer, { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
            
                public static func reportSpam(peer: Api.InputPeer) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Bool?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-820669733)
                    peer.serialize(buffer, true)
                    return (FunctionDescription({return "(messages.reportSpam peer: \(peer))"}), buffer, { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func hideReportSpam(peer: Api.InputPeer) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Bool?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1460572005)
                    peer.serialize(buffer, true)
                    return (FunctionDescription({return "(messages.hideReportSpam peer: \(peer))"}), buffer, { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func getPeerSettings(peer: Api.InputPeer) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.PeerSettings?) {
                    let buffer = Buffer()
                    buffer.appendInt32(913498268)
                    peer.serialize(buffer, true)
                    return (FunctionDescription({return "(messages.getPeerSettings peer: \(peer))"}), buffer, { (buffer: Buffer) -> Api.PeerSettings? in
                        let reader = BufferReader(buffer)
                        var result: Api.PeerSettings?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.PeerSettings
                        }
                        return result
                    })
                }
            
                public static func getChats(id: [Int32]) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.messages.Chats?) {
                    let buffer = Buffer()
                    buffer.appendInt32(1013621127)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(id.count))
                    for item in id {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    return (FunctionDescription({return "(messages.getChats id: \(id))"}), buffer, { (buffer: Buffer) -> Api.messages.Chats? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.Chats?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.Chats
                        }
                        return result
                    })
                }
            
                public static func getFullChat(chatId: Int32) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.messages.ChatFull?) {
                    let buffer = Buffer()
                    buffer.appendInt32(998448230)
                    serializeInt32(chatId, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(messages.getFullChat chatId: \(chatId))"}), buffer, { (buffer: Buffer) -> Api.messages.ChatFull? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.ChatFull?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.ChatFull
                        }
                        return result
                    })
                }
            
                public static func editChatTitle(chatId: Int32, title: String) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Updates?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-599447467)
                    serializeInt32(chatId, buffer: buffer, boxed: false)
                    serializeString(title, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(messages.editChatTitle chatId: \(chatId), title: \(title))"}), buffer, { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
            
                public static func editChatPhoto(chatId: Int32, photo: Api.InputChatPhoto) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Updates?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-900957736)
                    serializeInt32(chatId, buffer: buffer, boxed: false)
                    photo.serialize(buffer, true)
                    return (FunctionDescription({return "(messages.editChatPhoto chatId: \(chatId), photo: \(photo))"}), buffer, { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
            
                public static func addChatUser(chatId: Int32, userId: Api.InputUser, fwdLimit: Int32) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Updates?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-106911223)
                    serializeInt32(chatId, buffer: buffer, boxed: false)
                    userId.serialize(buffer, true)
                    serializeInt32(fwdLimit, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(messages.addChatUser chatId: \(chatId), userId: \(userId), fwdLimit: \(fwdLimit))"}), buffer, { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
            
                public static func deleteChatUser(chatId: Int32, userId: Api.InputUser) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Updates?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-530505962)
                    serializeInt32(chatId, buffer: buffer, boxed: false)
                    userId.serialize(buffer, true)
                    return (FunctionDescription({return "(messages.deleteChatUser chatId: \(chatId), userId: \(userId))"}), buffer, { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
            
                public static func createChat(users: [Api.InputUser], title: String) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Updates?) {
                    let buffer = Buffer()
                    buffer.appendInt32(164303470)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    serializeString(title, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(messages.createChat users: \(users), title: \(title))"}), buffer, { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
            
                public static func forwardMessage(peer: Api.InputPeer, id: Int32, randomId: Int64) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Updates?) {
                    let buffer = Buffer()
                    buffer.appendInt32(865483769)
                    peer.serialize(buffer, true)
                    serializeInt32(id, buffer: buffer, boxed: false)
                    serializeInt64(randomId, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(messages.forwardMessage peer: \(peer), id: \(id), randomId: \(randomId))"}), buffer, { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
            
                public static func getDhConfig(version: Int32, randomLength: Int32) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.messages.DhConfig?) {
                    let buffer = Buffer()
                    buffer.appendInt32(651135312)
                    serializeInt32(version, buffer: buffer, boxed: false)
                    serializeInt32(randomLength, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(messages.getDhConfig version: \(version), randomLength: \(randomLength))"}), buffer, { (buffer: Buffer) -> Api.messages.DhConfig? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.DhConfig?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.DhConfig
                        }
                        return result
                    })
                }
            
                public static func requestEncryption(userId: Api.InputUser, randomId: Int32, gA: Buffer) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.EncryptedChat?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-162681021)
                    userId.serialize(buffer, true)
                    serializeInt32(randomId, buffer: buffer, boxed: false)
                    serializeBytes(gA, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(messages.requestEncryption userId: \(userId), randomId: \(randomId), gA: \(gA))"}), buffer, { (buffer: Buffer) -> Api.EncryptedChat? in
                        let reader = BufferReader(buffer)
                        var result: Api.EncryptedChat?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.EncryptedChat
                        }
                        return result
                    })
                }
            
                public static func acceptEncryption(peer: Api.InputEncryptedChat, gB: Buffer, keyFingerprint: Int64) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.EncryptedChat?) {
                    let buffer = Buffer()
                    buffer.appendInt32(1035731989)
                    peer.serialize(buffer, true)
                    serializeBytes(gB, buffer: buffer, boxed: false)
                    serializeInt64(keyFingerprint, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(messages.acceptEncryption peer: \(peer), gB: \(gB), keyFingerprint: \(keyFingerprint))"}), buffer, { (buffer: Buffer) -> Api.EncryptedChat? in
                        let reader = BufferReader(buffer)
                        var result: Api.EncryptedChat?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.EncryptedChat
                        }
                        return result
                    })
                }
            
                public static func discardEncryption(chatId: Int32) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Bool?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-304536635)
                    serializeInt32(chatId, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(messages.discardEncryption chatId: \(chatId))"}), buffer, { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func setEncryptedTyping(peer: Api.InputEncryptedChat, typing: Api.Bool) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Bool?) {
                    let buffer = Buffer()
                    buffer.appendInt32(2031374829)
                    peer.serialize(buffer, true)
                    typing.serialize(buffer, true)
                    return (FunctionDescription({return "(messages.setEncryptedTyping peer: \(peer), typing: \(typing))"}), buffer, { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func readEncryptedHistory(peer: Api.InputEncryptedChat, maxDate: Int32) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Bool?) {
                    let buffer = Buffer()
                    buffer.appendInt32(2135648522)
                    peer.serialize(buffer, true)
                    serializeInt32(maxDate, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(messages.readEncryptedHistory peer: \(peer), maxDate: \(maxDate))"}), buffer, { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func sendEncrypted(peer: Api.InputEncryptedChat, randomId: Int64, data: Buffer) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.messages.SentEncryptedMessage?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1451792525)
                    peer.serialize(buffer, true)
                    serializeInt64(randomId, buffer: buffer, boxed: false)
                    serializeBytes(data, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(messages.sendEncrypted peer: \(peer), randomId: \(randomId), data: \(data))"}), buffer, { (buffer: Buffer) -> Api.messages.SentEncryptedMessage? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.SentEncryptedMessage?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.SentEncryptedMessage
                        }
                        return result
                    })
                }
            
                public static func sendEncryptedFile(peer: Api.InputEncryptedChat, randomId: Int64, data: Buffer, file: Api.InputEncryptedFile) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.messages.SentEncryptedMessage?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1701831834)
                    peer.serialize(buffer, true)
                    serializeInt64(randomId, buffer: buffer, boxed: false)
                    serializeBytes(data, buffer: buffer, boxed: false)
                    file.serialize(buffer, true)
                    return (FunctionDescription({return "(messages.sendEncryptedFile peer: \(peer), randomId: \(randomId), data: \(data), file: \(file))"}), buffer, { (buffer: Buffer) -> Api.messages.SentEncryptedMessage? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.SentEncryptedMessage?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.SentEncryptedMessage
                        }
                        return result
                    })
                }
            
                public static func sendEncryptedService(peer: Api.InputEncryptedChat, randomId: Int64, data: Buffer) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.messages.SentEncryptedMessage?) {
                    let buffer = Buffer()
                    buffer.appendInt32(852769188)
                    peer.serialize(buffer, true)
                    serializeInt64(randomId, buffer: buffer, boxed: false)
                    serializeBytes(data, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(messages.sendEncryptedService peer: \(peer), randomId: \(randomId), data: \(data))"}), buffer, { (buffer: Buffer) -> Api.messages.SentEncryptedMessage? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.SentEncryptedMessage?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.SentEncryptedMessage
                        }
                        return result
                    })
                }
            
                public static func receivedQueue(maxQts: Int32) -> (CustomStringConvertible, Buffer, (Buffer) -> [Int64]?) {
                    let buffer = Buffer()
                    buffer.appendInt32(1436924774)
                    serializeInt32(maxQts, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(messages.receivedQueue maxQts: \(maxQts))"}), buffer, { (buffer: Buffer) -> [Int64]? in
                        let reader = BufferReader(buffer)
                        var result: [Int64]?
                        if let _ = reader.readInt32() {
                            result = Api.parseVector(reader, elementSignature: 570911930, elementType: Int64.self)
                        }
                        return result
                    })
                }
            
                public static func reportEncryptedSpam(peer: Api.InputEncryptedChat) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Bool?) {
                    let buffer = Buffer()
                    buffer.appendInt32(1259113487)
                    peer.serialize(buffer, true)
                    return (FunctionDescription({return "(messages.reportEncryptedSpam peer: \(peer))"}), buffer, { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func readMessageContents(id: [Int32]) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.messages.AffectedMessages?) {
                    let buffer = Buffer()
                    buffer.appendInt32(916930423)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(id.count))
                    for item in id {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    return (FunctionDescription({return "(messages.readMessageContents id: \(id))"}), buffer, { (buffer: Buffer) -> Api.messages.AffectedMessages? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.AffectedMessages?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.AffectedMessages
                        }
                        return result
                    })
                }
            
                public static func getAllStickers(hash: Int32) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.messages.AllStickers?) {
                    let buffer = Buffer()
                    buffer.appendInt32(479598769)
                    serializeInt32(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(messages.getAllStickers hash: \(hash))"}), buffer, { (buffer: Buffer) -> Api.messages.AllStickers? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.AllStickers?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.AllStickers
                        }
                        return result
                    })
                }
            
                public static func exportChatInvite(chatId: Int32) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.ExportedChatInvite?) {
                    let buffer = Buffer()
                    buffer.appendInt32(2106086025)
                    serializeInt32(chatId, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(messages.exportChatInvite chatId: \(chatId))"}), buffer, { (buffer: Buffer) -> Api.ExportedChatInvite? in
                        let reader = BufferReader(buffer)
                        var result: Api.ExportedChatInvite?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.ExportedChatInvite
                        }
                        return result
                    })
                }
            
                public static func checkChatInvite(hash: String) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.ChatInvite?) {
                    let buffer = Buffer()
                    buffer.appendInt32(1051570619)
                    serializeString(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(messages.checkChatInvite hash: \(hash))"}), buffer, { (buffer: Buffer) -> Api.ChatInvite? in
                        let reader = BufferReader(buffer)
                        var result: Api.ChatInvite?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.ChatInvite
                        }
                        return result
                    })
                }
            
                public static func importChatInvite(hash: String) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Updates?) {
                    let buffer = Buffer()
                    buffer.appendInt32(1817183516)
                    serializeString(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(messages.importChatInvite hash: \(hash))"}), buffer, { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
            
                public static func getStickerSet(stickerset: Api.InputStickerSet) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.messages.StickerSet?) {
                    let buffer = Buffer()
                    buffer.appendInt32(639215886)
                    stickerset.serialize(buffer, true)
                    return (FunctionDescription({return "(messages.getStickerSet stickerset: \(stickerset))"}), buffer, { (buffer: Buffer) -> Api.messages.StickerSet? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.StickerSet?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.StickerSet
                        }
                        return result
                    })
                }
            
                public static func installStickerSet(stickerset: Api.InputStickerSet, archived: Api.Bool) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.messages.StickerSetInstallResult?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-946871200)
                    stickerset.serialize(buffer, true)
                    archived.serialize(buffer, true)
                    return (FunctionDescription({return "(messages.installStickerSet stickerset: \(stickerset), archived: \(archived))"}), buffer, { (buffer: Buffer) -> Api.messages.StickerSetInstallResult? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.StickerSetInstallResult?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.StickerSetInstallResult
                        }
                        return result
                    })
                }
            
                public static func uninstallStickerSet(stickerset: Api.InputStickerSet) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Bool?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-110209570)
                    stickerset.serialize(buffer, true)
                    return (FunctionDescription({return "(messages.uninstallStickerSet stickerset: \(stickerset))"}), buffer, { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func startBot(bot: Api.InputUser, peer: Api.InputPeer, randomId: Int64, startParam: String) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Updates?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-421563528)
                    bot.serialize(buffer, true)
                    peer.serialize(buffer, true)
                    serializeInt64(randomId, buffer: buffer, boxed: false)
                    serializeString(startParam, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(messages.startBot bot: \(bot), peer: \(peer), randomId: \(randomId), startParam: \(startParam))"}), buffer, { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
            
                public static func getMessagesViews(peer: Api.InputPeer, id: [Int32], increment: Api.Bool) -> (CustomStringConvertible, Buffer, (Buffer) -> [Int32]?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-993483427)
                    peer.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(id.count))
                    for item in id {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    increment.serialize(buffer, true)
                    return (FunctionDescription({return "(messages.getMessagesViews peer: \(peer), id: \(id), increment: \(increment))"}), buffer, { (buffer: Buffer) -> [Int32]? in
                        let reader = BufferReader(buffer)
                        var result: [Int32]?
                        if let _ = reader.readInt32() {
                            result = Api.parseVector(reader, elementSignature: -1471112230, elementType: Int32.self)
                        }
                        return result
                    })
                }
            
                public static func toggleChatAdmins(chatId: Int32, enabled: Api.Bool) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Updates?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-326379039)
                    serializeInt32(chatId, buffer: buffer, boxed: false)
                    enabled.serialize(buffer, true)
                    return (FunctionDescription({return "(messages.toggleChatAdmins chatId: \(chatId), enabled: \(enabled))"}), buffer, { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
            
                public static func editChatAdmin(chatId: Int32, userId: Api.InputUser, isAdmin: Api.Bool) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Bool?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1444503762)
                    serializeInt32(chatId, buffer: buffer, boxed: false)
                    userId.serialize(buffer, true)
                    isAdmin.serialize(buffer, true)
                    return (FunctionDescription({return "(messages.editChatAdmin chatId: \(chatId), userId: \(userId), isAdmin: \(isAdmin))"}), buffer, { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func migrateChat(chatId: Int32) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Updates?) {
                    let buffer = Buffer()
                    buffer.appendInt32(363051235)
                    serializeInt32(chatId, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(messages.migrateChat chatId: \(chatId))"}), buffer, { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
            
                public static func searchGlobal(q: String, offsetDate: Int32, offsetPeer: Api.InputPeer, offsetId: Int32, limit: Int32) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.messages.Messages?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1640190800)
                    serializeString(q, buffer: buffer, boxed: false)
                    serializeInt32(offsetDate, buffer: buffer, boxed: false)
                    offsetPeer.serialize(buffer, true)
                    serializeInt32(offsetId, buffer: buffer, boxed: false)
                    serializeInt32(limit, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(messages.searchGlobal q: \(q), offsetDate: \(offsetDate), offsetPeer: \(offsetPeer), offsetId: \(offsetId), limit: \(limit))"}), buffer, { (buffer: Buffer) -> Api.messages.Messages? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.Messages?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.Messages
                        }
                        return result
                    })
                }
            
                public static func reorderStickerSets(flags: Int32, order: [Int64]) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Bool?) {
                    let buffer = Buffer()
                    buffer.appendInt32(2016638777)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(order.count))
                    for item in order {
                        serializeInt64(item, buffer: buffer, boxed: false)
                    }
                    return (FunctionDescription({return "(messages.reorderStickerSets flags: \(flags), order: \(order))"}), buffer, { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func getDocumentByHash(sha256: Buffer, size: Int32, mimeType: String) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Document?) {
                    let buffer = Buffer()
                    buffer.appendInt32(864953444)
                    serializeBytes(sha256, buffer: buffer, boxed: false)
                    serializeInt32(size, buffer: buffer, boxed: false)
                    serializeString(mimeType, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(messages.getDocumentByHash sha256: \(sha256), size: \(size), mimeType: \(mimeType))"}), buffer, { (buffer: Buffer) -> Api.Document? in
                        let reader = BufferReader(buffer)
                        var result: Api.Document?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Document
                        }
                        return result
                    })
                }
            
                public static func searchGifs(q: String, offset: Int32) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.messages.FoundGifs?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1080395925)
                    serializeString(q, buffer: buffer, boxed: false)
                    serializeInt32(offset, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(messages.searchGifs q: \(q), offset: \(offset))"}), buffer, { (buffer: Buffer) -> Api.messages.FoundGifs? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.FoundGifs?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.FoundGifs
                        }
                        return result
                    })
                }
            
                public static func getSavedGifs(hash: Int32) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.messages.SavedGifs?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-2084618926)
                    serializeInt32(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(messages.getSavedGifs hash: \(hash))"}), buffer, { (buffer: Buffer) -> Api.messages.SavedGifs? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.SavedGifs?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.SavedGifs
                        }
                        return result
                    })
                }
            
                public static func saveGif(id: Api.InputDocument, unsave: Api.Bool) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Bool?) {
                    let buffer = Buffer()
                    buffer.appendInt32(846868683)
                    id.serialize(buffer, true)
                    unsave.serialize(buffer, true)
                    return (FunctionDescription({return "(messages.saveGif id: \(id), unsave: \(unsave))"}), buffer, { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func getInlineBotResults(flags: Int32, bot: Api.InputUser, peer: Api.InputPeer, geoPoint: Api.InputGeoPoint?, query: String, offset: String) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.messages.BotResults?) {
                    let buffer = Buffer()
                    buffer.appendInt32(1364105629)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    bot.serialize(buffer, true)
                    peer.serialize(buffer, true)
                    if Int(flags) & Int(1 << 0) != 0 {geoPoint!.serialize(buffer, true)}
                    serializeString(query, buffer: buffer, boxed: false)
                    serializeString(offset, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(messages.getInlineBotResults flags: \(flags), bot: \(bot), peer: \(peer), geoPoint: \(String(describing: geoPoint)), query: \(query), offset: \(offset))"}), buffer, { (buffer: Buffer) -> Api.messages.BotResults? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.BotResults?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.BotResults
                        }
                        return result
                    })
                }
            
                public static func setInlineBotResults(flags: Int32, queryId: Int64, results: [Api.InputBotInlineResult], cacheTime: Int32, nextOffset: String?, switchPm: Api.InlineBotSwitchPM?) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Bool?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-346119674)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(queryId, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(results.count))
                    for item in results {
                        item.serialize(buffer, true)
                    }
                    serializeInt32(cacheTime, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 2) != 0 {serializeString(nextOffset!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 3) != 0 {switchPm!.serialize(buffer, true)}
                    return (FunctionDescription({return "(messages.setInlineBotResults flags: \(flags), queryId: \(queryId), results: \(results), cacheTime: \(cacheTime), nextOffset: \(String(describing: nextOffset)), switchPm: \(String(describing: switchPm)))"}), buffer, { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func sendInlineBotResult(flags: Int32, peer: Api.InputPeer, replyToMsgId: Int32?, randomId: Int64, queryId: Int64, id: String) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Updates?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1318189314)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(replyToMsgId!, buffer: buffer, boxed: false)}
                    serializeInt64(randomId, buffer: buffer, boxed: false)
                    serializeInt64(queryId, buffer: buffer, boxed: false)
                    serializeString(id, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(messages.sendInlineBotResult flags: \(flags), peer: \(peer), replyToMsgId: \(String(describing: replyToMsgId)), randomId: \(randomId), queryId: \(queryId), id: \(id))"}), buffer, { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
            
                public static func getMessageEditData(peer: Api.InputPeer, id: Int32) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.messages.MessageEditData?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-39416522)
                    peer.serialize(buffer, true)
                    serializeInt32(id, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(messages.getMessageEditData peer: \(peer), id: \(id))"}), buffer, { (buffer: Buffer) -> Api.messages.MessageEditData? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.MessageEditData?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.MessageEditData
                        }
                        return result
                    })
                }
            
                public static func editMessage(flags: Int32, peer: Api.InputPeer, id: Int32, message: String?, replyMarkup: Api.ReplyMarkup?, entities: [Api.MessageEntity]?, geoPoint: Api.InputGeoPoint?) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Updates?) {
                    let buffer = Buffer()
                    buffer.appendInt32(97630429)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    serializeInt32(id, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 11) != 0 {serializeString(message!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {replyMarkup!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 3) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(entities!.count))
                    for item in entities! {
                        item.serialize(buffer, true)
                    }}
                    if Int(flags) & Int(1 << 13) != 0 {geoPoint!.serialize(buffer, true)}
                    return (FunctionDescription({return "(messages.editMessage flags: \(flags), peer: \(peer), id: \(id), message: \(String(describing: message)), replyMarkup: \(String(describing: replyMarkup)), entities: \(String(describing: entities)), geoPoint: \(String(describing: geoPoint)))"}), buffer, { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
            
                public static func editInlineBotMessage(flags: Int32, id: Api.InputBotInlineMessageID, message: String?, replyMarkup: Api.ReplyMarkup?, entities: [Api.MessageEntity]?) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Bool?) {
                    let buffer = Buffer()
                    buffer.appendInt32(319564933)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    id.serialize(buffer, true)
                    if Int(flags) & Int(1 << 11) != 0 {serializeString(message!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {replyMarkup!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 3) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(entities!.count))
                    for item in entities! {
                        item.serialize(buffer, true)
                    }}
                    return (FunctionDescription({return "(messages.editInlineBotMessage flags: \(flags), id: \(id), message: \(String(describing: message)), replyMarkup: \(String(describing: replyMarkup)), entities: \(String(describing: entities)))"}), buffer, { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func getBotCallbackAnswer(flags: Int32, peer: Api.InputPeer, msgId: Int32, data: Buffer?) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.messages.BotCallbackAnswer?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-2130010132)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    serializeInt32(msgId, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeBytes(data!, buffer: buffer, boxed: false)}
                    return (FunctionDescription({return "(messages.getBotCallbackAnswer flags: \(flags), peer: \(peer), msgId: \(msgId), data: \(String(describing: data)))"}), buffer, { (buffer: Buffer) -> Api.messages.BotCallbackAnswer? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.BotCallbackAnswer?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.BotCallbackAnswer
                        }
                        return result
                    })
                }
            
                public static func setBotCallbackAnswer(flags: Int32, queryId: Int64, message: String?, url: String?, cacheTime: Int32) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Bool?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-712043766)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(queryId, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(message!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeString(url!, buffer: buffer, boxed: false)}
                    serializeInt32(cacheTime, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(messages.setBotCallbackAnswer flags: \(flags), queryId: \(queryId), message: \(String(describing: message)), url: \(String(describing: url)), cacheTime: \(cacheTime))"}), buffer, { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func saveDraft(flags: Int32, replyToMsgId: Int32?, peer: Api.InputPeer, message: String, entities: [Api.MessageEntity]?) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Bool?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1137057461)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(replyToMsgId!, buffer: buffer, boxed: false)}
                    peer.serialize(buffer, true)
                    serializeString(message, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 3) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(entities!.count))
                    for item in entities! {
                        item.serialize(buffer, true)
                    }}
                    return (FunctionDescription({return "(messages.saveDraft flags: \(flags), replyToMsgId: \(String(describing: replyToMsgId)), peer: \(peer), message: \(message), entities: \(String(describing: entities)))"}), buffer, { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func getAllDrafts() -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Updates?) {
                    let buffer = Buffer()
                    buffer.appendInt32(1782549861)
                    
                    return (FunctionDescription({return "(messages.getAllDrafts )"}), buffer, { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
            
                public static func getFeaturedStickers(hash: Int32) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.messages.FeaturedStickers?) {
                    let buffer = Buffer()
                    buffer.appendInt32(766298703)
                    serializeInt32(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(messages.getFeaturedStickers hash: \(hash))"}), buffer, { (buffer: Buffer) -> Api.messages.FeaturedStickers? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.FeaturedStickers?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.FeaturedStickers
                        }
                        return result
                    })
                }
            
                public static func readFeaturedStickers(id: [Int64]) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Bool?) {
                    let buffer = Buffer()
                    buffer.appendInt32(1527873830)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(id.count))
                    for item in id {
                        serializeInt64(item, buffer: buffer, boxed: false)
                    }
                    return (FunctionDescription({return "(messages.readFeaturedStickers id: \(id))"}), buffer, { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func getRecentStickers(flags: Int32, hash: Int32) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.messages.RecentStickers?) {
                    let buffer = Buffer()
                    buffer.appendInt32(1587647177)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(messages.getRecentStickers flags: \(flags), hash: \(hash))"}), buffer, { (buffer: Buffer) -> Api.messages.RecentStickers? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.RecentStickers?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.RecentStickers
                        }
                        return result
                    })
                }
            
                public static func saveRecentSticker(flags: Int32, id: Api.InputDocument, unsave: Api.Bool) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Bool?) {
                    let buffer = Buffer()
                    buffer.appendInt32(958863608)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    id.serialize(buffer, true)
                    unsave.serialize(buffer, true)
                    return (FunctionDescription({return "(messages.saveRecentSticker flags: \(flags), id: \(id), unsave: \(unsave))"}), buffer, { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func clearRecentStickers(flags: Int32) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Bool?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1986437075)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(messages.clearRecentStickers flags: \(flags))"}), buffer, { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func getArchivedStickers(flags: Int32, offsetId: Int64, limit: Int32) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.messages.ArchivedStickers?) {
                    let buffer = Buffer()
                    buffer.appendInt32(1475442322)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(offsetId, buffer: buffer, boxed: false)
                    serializeInt32(limit, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(messages.getArchivedStickers flags: \(flags), offsetId: \(offsetId), limit: \(limit))"}), buffer, { (buffer: Buffer) -> Api.messages.ArchivedStickers? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.ArchivedStickers?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.ArchivedStickers
                        }
                        return result
                    })
                }
            
                public static func getMaskStickers(hash: Int32) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.messages.AllStickers?) {
                    let buffer = Buffer()
                    buffer.appendInt32(1706608543)
                    serializeInt32(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(messages.getMaskStickers hash: \(hash))"}), buffer, { (buffer: Buffer) -> Api.messages.AllStickers? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.AllStickers?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.AllStickers
                        }
                        return result
                    })
                }
            
                public static func getAttachedStickers(media: Api.InputStickeredMedia) -> (CustomStringConvertible, Buffer, (Buffer) -> [Api.StickerSetCovered]?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-866424884)
                    media.serialize(buffer, true)
                    return (FunctionDescription({return "(messages.getAttachedStickers media: \(media))"}), buffer, { (buffer: Buffer) -> [Api.StickerSetCovered]? in
                        let reader = BufferReader(buffer)
                        var result: [Api.StickerSetCovered]?
                        if let _ = reader.readInt32() {
                            result = Api.parseVector(reader, elementSignature: 0, elementType: Api.StickerSetCovered.self)
                        }
                        return result
                    })
                }
            
                public static func setGameScore(flags: Int32, peer: Api.InputPeer, id: Int32, userId: Api.InputUser, score: Int32) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Updates?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1896289088)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    serializeInt32(id, buffer: buffer, boxed: false)
                    userId.serialize(buffer, true)
                    serializeInt32(score, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(messages.setGameScore flags: \(flags), peer: \(peer), id: \(id), userId: \(userId), score: \(score))"}), buffer, { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
            
                public static func setInlineGameScore(flags: Int32, id: Api.InputBotInlineMessageID, userId: Api.InputUser, score: Int32) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Bool?) {
                    let buffer = Buffer()
                    buffer.appendInt32(363700068)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    id.serialize(buffer, true)
                    userId.serialize(buffer, true)
                    serializeInt32(score, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(messages.setInlineGameScore flags: \(flags), id: \(id), userId: \(userId), score: \(score))"}), buffer, { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func getGameHighScores(peer: Api.InputPeer, id: Int32, userId: Api.InputUser) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.messages.HighScores?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-400399203)
                    peer.serialize(buffer, true)
                    serializeInt32(id, buffer: buffer, boxed: false)
                    userId.serialize(buffer, true)
                    return (FunctionDescription({return "(messages.getGameHighScores peer: \(peer), id: \(id), userId: \(userId))"}), buffer, { (buffer: Buffer) -> Api.messages.HighScores? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.HighScores?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.HighScores
                        }
                        return result
                    })
                }
            
                public static func getInlineGameHighScores(id: Api.InputBotInlineMessageID, userId: Api.InputUser) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.messages.HighScores?) {
                    let buffer = Buffer()
                    buffer.appendInt32(258170395)
                    id.serialize(buffer, true)
                    userId.serialize(buffer, true)
                    return (FunctionDescription({return "(messages.getInlineGameHighScores id: \(id), userId: \(userId))"}), buffer, { (buffer: Buffer) -> Api.messages.HighScores? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.HighScores?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.HighScores
                        }
                        return result
                    })
                }
            
                public static func getCommonChats(userId: Api.InputUser, maxId: Int32, limit: Int32) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.messages.Chats?) {
                    let buffer = Buffer()
                    buffer.appendInt32(218777796)
                    userId.serialize(buffer, true)
                    serializeInt32(maxId, buffer: buffer, boxed: false)
                    serializeInt32(limit, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(messages.getCommonChats userId: \(userId), maxId: \(maxId), limit: \(limit))"}), buffer, { (buffer: Buffer) -> Api.messages.Chats? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.Chats?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.Chats
                        }
                        return result
                    })
                }
            
                public static func getAllChats(exceptIds: [Int32]) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.messages.Chats?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-341307408)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(exceptIds.count))
                    for item in exceptIds {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    return (FunctionDescription({return "(messages.getAllChats exceptIds: \(exceptIds))"}), buffer, { (buffer: Buffer) -> Api.messages.Chats? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.Chats?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.Chats
                        }
                        return result
                    })
                }
            
                public static func getWebPage(url: String, hash: Int32) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.WebPage?) {
                    let buffer = Buffer()
                    buffer.appendInt32(852135825)
                    serializeString(url, buffer: buffer, boxed: false)
                    serializeInt32(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(messages.getWebPage url: \(url), hash: \(hash))"}), buffer, { (buffer: Buffer) -> Api.WebPage? in
                        let reader = BufferReader(buffer)
                        var result: Api.WebPage?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.WebPage
                        }
                        return result
                    })
                }
            
                public static func getPinnedDialogs() -> (CustomStringConvertible, Buffer, (Buffer) -> Api.messages.PeerDialogs?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-497756594)
                    
                    return (FunctionDescription({return "(messages.getPinnedDialogs )"}), buffer, { (buffer: Buffer) -> Api.messages.PeerDialogs? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.PeerDialogs?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.PeerDialogs
                        }
                        return result
                    })
                }
            
                public static func setBotShippingResults(flags: Int32, queryId: Int64, error: String?, shippingOptions: [Api.ShippingOption]?) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Bool?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-436833542)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(queryId, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(error!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(shippingOptions!.count))
                    for item in shippingOptions! {
                        item.serialize(buffer, true)
                    }}
                    return (FunctionDescription({return "(messages.setBotShippingResults flags: \(flags), queryId: \(queryId), error: \(String(describing: error)), shippingOptions: \(String(describing: shippingOptions)))"}), buffer, { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func setBotPrecheckoutResults(flags: Int32, queryId: Int64, error: String?) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Bool?) {
                    let buffer = Buffer()
                    buffer.appendInt32(163765653)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(queryId, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(error!, buffer: buffer, boxed: false)}
                    return (FunctionDescription({return "(messages.setBotPrecheckoutResults flags: \(flags), queryId: \(queryId), error: \(String(describing: error)))"}), buffer, { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func sendScreenshotNotification(peer: Api.InputPeer, replyToMsgId: Int32, randomId: Int64) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Updates?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-914493408)
                    peer.serialize(buffer, true)
                    serializeInt32(replyToMsgId, buffer: buffer, boxed: false)
                    serializeInt64(randomId, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(messages.sendScreenshotNotification peer: \(peer), replyToMsgId: \(replyToMsgId), randomId: \(randomId))"}), buffer, { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
            
                public static func getFavedStickers(hash: Int32) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.messages.FavedStickers?) {
                    let buffer = Buffer()
                    buffer.appendInt32(567151374)
                    serializeInt32(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(messages.getFavedStickers hash: \(hash))"}), buffer, { (buffer: Buffer) -> Api.messages.FavedStickers? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.FavedStickers?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.FavedStickers
                        }
                        return result
                    })
                }
            
                public static func faveSticker(id: Api.InputDocument, unfave: Api.Bool) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Bool?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1174420133)
                    id.serialize(buffer, true)
                    unfave.serialize(buffer, true)
                    return (FunctionDescription({return "(messages.faveSticker id: \(id), unfave: \(unfave))"}), buffer, { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func getUnreadMentions(peer: Api.InputPeer, offsetId: Int32, addOffset: Int32, limit: Int32, maxId: Int32, minId: Int32) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.messages.Messages?) {
                    let buffer = Buffer()
                    buffer.appendInt32(1180140658)
                    peer.serialize(buffer, true)
                    serializeInt32(offsetId, buffer: buffer, boxed: false)
                    serializeInt32(addOffset, buffer: buffer, boxed: false)
                    serializeInt32(limit, buffer: buffer, boxed: false)
                    serializeInt32(maxId, buffer: buffer, boxed: false)
                    serializeInt32(minId, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(messages.getUnreadMentions peer: \(peer), offsetId: \(offsetId), addOffset: \(addOffset), limit: \(limit), maxId: \(maxId), minId: \(minId))"}), buffer, { (buffer: Buffer) -> Api.messages.Messages? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.Messages?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.Messages
                        }
                        return result
                    })
                }
            
                public static func readMentions(peer: Api.InputPeer) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.messages.AffectedHistory?) {
                    let buffer = Buffer()
                    buffer.appendInt32(251759059)
                    peer.serialize(buffer, true)
                    return (FunctionDescription({return "(messages.readMentions peer: \(peer))"}), buffer, { (buffer: Buffer) -> Api.messages.AffectedHistory? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.AffectedHistory?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.AffectedHistory
                        }
                        return result
                    })
                }
            
                public static func editGeoLive(flags: Int32, peer: Api.InputPeer, id: Int32, geoPoint: Api.InputGeoPoint?) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Updates?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1701695410)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    serializeInt32(id, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {geoPoint!.serialize(buffer, true)}
                    return (FunctionDescription({return "(messages.editGeoLive flags: \(flags), peer: \(peer), id: \(id), geoPoint: \(String(describing: geoPoint)))"}), buffer, { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
            
                public static func uploadMedia(peer: Api.InputPeer, media: Api.InputMedia) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.MessageMedia?) {
                    let buffer = Buffer()
                    buffer.appendInt32(1369162417)
                    peer.serialize(buffer, true)
                    media.serialize(buffer, true)
                    return (FunctionDescription({return "(messages.uploadMedia peer: \(peer), media: \(media))"}), buffer, { (buffer: Buffer) -> Api.MessageMedia? in
                        let reader = BufferReader(buffer)
                        var result: Api.MessageMedia?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.MessageMedia
                        }
                        return result
                    })
                }
            
                public static func sendMultiMedia(flags: Int32, peer: Api.InputPeer, replyToMsgId: Int32?, multiMedia: [Api.InputSingleMedia]) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Updates?) {
                    let buffer = Buffer()
                    buffer.appendInt32(546656559)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(replyToMsgId!, buffer: buffer, boxed: false)}
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(multiMedia.count))
                    for item in multiMedia {
                        item.serialize(buffer, true)
                    }
                    return (FunctionDescription({return "(messages.sendMultiMedia flags: \(flags), peer: \(peer), replyToMsgId: \(String(describing: replyToMsgId)), multiMedia: \(multiMedia))"}), buffer, { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
            
                public static func forwardMessages(flags: Int32, fromPeer: Api.InputPeer, id: [Int32], randomId: [Int64], toPeer: Api.InputPeer) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Updates?) {
                    let buffer = Buffer()
                    buffer.appendInt32(1888354709)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    fromPeer.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(id.count))
                    for item in id {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(randomId.count))
                    for item in randomId {
                        serializeInt64(item, buffer: buffer, boxed: false)
                    }
                    toPeer.serialize(buffer, true)
                    return (FunctionDescription({return "(messages.forwardMessages flags: \(flags), fromPeer: \(fromPeer), id: \(id), randomId: \(randomId), toPeer: \(toPeer))"}), buffer, { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
            
                public static func uploadEncryptedFile(peer: Api.InputEncryptedChat, file: Api.InputEncryptedFile) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.EncryptedFile?) {
                    let buffer = Buffer()
                    buffer.appendInt32(1347929239)
                    peer.serialize(buffer, true)
                    file.serialize(buffer, true)
                    return (FunctionDescription({return "(messages.uploadEncryptedFile peer: \(peer), file: \(file))"}), buffer, { (buffer: Buffer) -> Api.EncryptedFile? in
                        let reader = BufferReader(buffer)
                        var result: Api.EncryptedFile?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.EncryptedFile
                        }
                        return result
                    })
                }
            
                public static func getWebPagePreview(flags: Int32, message: String, entities: [Api.MessageEntity]?) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.MessageMedia?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1956073268)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(message, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 3) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(entities!.count))
                    for item in entities! {
                        item.serialize(buffer, true)
                    }}
                    return (FunctionDescription({return "(messages.getWebPagePreview flags: \(flags), message: \(message), entities: \(String(describing: entities)))"}), buffer, { (buffer: Buffer) -> Api.MessageMedia? in
                        let reader = BufferReader(buffer)
                        var result: Api.MessageMedia?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.MessageMedia
                        }
                        return result
                    })
                }
            
                public static func sendMedia(flags: Int32, peer: Api.InputPeer, replyToMsgId: Int32?, media: Api.InputMedia, message: String, randomId: Int64, replyMarkup: Api.ReplyMarkup?, entities: [Api.MessageEntity]?) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Updates?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1194252757)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(replyToMsgId!, buffer: buffer, boxed: false)}
                    media.serialize(buffer, true)
                    serializeString(message, buffer: buffer, boxed: false)
                    serializeInt64(randomId, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 2) != 0 {replyMarkup!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 3) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(entities!.count))
                    for item in entities! {
                        item.serialize(buffer, true)
                    }}
                    return (FunctionDescription({return "(messages.sendMedia flags: \(flags), peer: \(peer), replyToMsgId: \(String(describing: replyToMsgId)), media: \(media), message: \(message), randomId: \(randomId), replyMarkup: \(String(describing: replyMarkup)), entities: \(String(describing: entities)))"}), buffer, { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
            
                public static func getMessages(id: [Api.InputMessage]) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.messages.Messages?) {
                    let buffer = Buffer()
                    buffer.appendInt32(1673946374)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(id.count))
                    for item in id {
                        item.serialize(buffer, true)
                    }
                    return (FunctionDescription({return "(messages.getMessages id: \(id))"}), buffer, { (buffer: Buffer) -> Api.messages.Messages? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.Messages?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.Messages
                        }
                        return result
                    })
                }
            
                public static func report(peer: Api.InputPeer, id: [Int32], reason: Api.ReportReason) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Bool?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1115507112)
                    peer.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(id.count))
                    for item in id {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    reason.serialize(buffer, true)
                    return (FunctionDescription({return "(messages.report peer: \(peer), id: \(id), reason: \(reason))"}), buffer, { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func getRecentLocations(peer: Api.InputPeer, limit: Int32, hash: Int32) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.messages.Messages?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1144759543)
                    peer.serialize(buffer, true)
                    serializeInt32(limit, buffer: buffer, boxed: false)
                    serializeInt32(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(messages.getRecentLocations peer: \(peer), limit: \(limit), hash: \(hash))"}), buffer, { (buffer: Buffer) -> Api.messages.Messages? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.Messages?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.Messages
                        }
                        return result
                    })
                }
            
                public static func search(flags: Int32, peer: Api.InputPeer, q: String, fromId: Api.InputUser?, filter: Api.MessagesFilter, minDate: Int32, maxDate: Int32, offsetId: Int32, addOffset: Int32, limit: Int32, maxId: Int32, minId: Int32, hash: Int32) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.messages.Messages?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-2045448344)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    serializeString(q, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {fromId!.serialize(buffer, true)}
                    filter.serialize(buffer, true)
                    serializeInt32(minDate, buffer: buffer, boxed: false)
                    serializeInt32(maxDate, buffer: buffer, boxed: false)
                    serializeInt32(offsetId, buffer: buffer, boxed: false)
                    serializeInt32(addOffset, buffer: buffer, boxed: false)
                    serializeInt32(limit, buffer: buffer, boxed: false)
                    serializeInt32(maxId, buffer: buffer, boxed: false)
                    serializeInt32(minId, buffer: buffer, boxed: false)
                    serializeInt32(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(messages.search flags: \(flags), peer: \(peer), q: \(q), fromId: \(String(describing: fromId)), filter: \(filter), minDate: \(minDate), maxDate: \(maxDate), offsetId: \(offsetId), addOffset: \(addOffset), limit: \(limit), maxId: \(maxId), minId: \(minId), hash: \(hash))"}), buffer, { (buffer: Buffer) -> Api.messages.Messages? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.Messages?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.Messages
                        }
                        return result
                    })
                }
            
                public static func toggleDialogPin(flags: Int32, peer: Api.InputDialogPeer) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Bool?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1489903017)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    return (FunctionDescription({return "(messages.toggleDialogPin flags: \(flags), peer: \(peer))"}), buffer, { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func reorderPinnedDialogs(flags: Int32, order: [Api.InputDialogPeer]) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Bool?) {
                    let buffer = Buffer()
                    buffer.appendInt32(1532089919)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(order.count))
                    for item in order {
                        item.serialize(buffer, true)
                    }
                    return (FunctionDescription({return "(messages.reorderPinnedDialogs flags: \(flags), order: \(order))"}), buffer, { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func getPeerDialogs(peers: [Api.InputDialogPeer]) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.messages.PeerDialogs?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-462373635)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(peers.count))
                    for item in peers {
                        item.serialize(buffer, true)
                    }
                    return (FunctionDescription({return "(messages.getPeerDialogs peers: \(peers))"}), buffer, { (buffer: Buffer) -> Api.messages.PeerDialogs? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.PeerDialogs?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.PeerDialogs
                        }
                        return result
                    })
                }
            
                public static func searchStickerSets(flags: Int32, q: String, hash: Int32) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.messages.FoundStickerSets?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1028140917)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(q, buffer: buffer, boxed: false)
                    serializeInt32(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(messages.searchStickerSets flags: \(flags), q: \(q), hash: \(hash))"}), buffer, { (buffer: Buffer) -> Api.messages.FoundStickerSets? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.FoundStickerSets?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.FoundStickerSets
                        }
                        return result
                    })
                }
            
                public static func getStickers(emoticon: String, hash: Int32) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.messages.Stickers?) {
                    let buffer = Buffer()
                    buffer.appendInt32(71126828)
                    serializeString(emoticon, buffer: buffer, boxed: false)
                    serializeInt32(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(messages.getStickers emoticon: \(emoticon), hash: \(hash))"}), buffer, { (buffer: Buffer) -> Api.messages.Stickers? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.Stickers?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.Stickers
                        }
                        return result
                    })
                }
            }
            public struct channels {
                public static func readHistory(channel: Api.InputChannel, maxId: Int32) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Bool?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-871347913)
                    channel.serialize(buffer, true)
                    serializeInt32(maxId, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(channels.readHistory channel: \(channel), maxId: \(maxId))"}), buffer, { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func deleteMessages(channel: Api.InputChannel, id: [Int32]) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.messages.AffectedMessages?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-2067661490)
                    channel.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(id.count))
                    for item in id {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    return (FunctionDescription({return "(channels.deleteMessages channel: \(channel), id: \(id))"}), buffer, { (buffer: Buffer) -> Api.messages.AffectedMessages? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.AffectedMessages?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.AffectedMessages
                        }
                        return result
                    })
                }
            
                public static func deleteUserHistory(channel: Api.InputChannel, userId: Api.InputUser) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.messages.AffectedHistory?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-787622117)
                    channel.serialize(buffer, true)
                    userId.serialize(buffer, true)
                    return (FunctionDescription({return "(channels.deleteUserHistory channel: \(channel), userId: \(userId))"}), buffer, { (buffer: Buffer) -> Api.messages.AffectedHistory? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.AffectedHistory?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.AffectedHistory
                        }
                        return result
                    })
                }
            
                public static func reportSpam(channel: Api.InputChannel, userId: Api.InputUser, id: [Int32]) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Bool?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-32999408)
                    channel.serialize(buffer, true)
                    userId.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(id.count))
                    for item in id {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    return (FunctionDescription({return "(channels.reportSpam channel: \(channel), userId: \(userId), id: \(id))"}), buffer, { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func getParticipant(channel: Api.InputChannel, userId: Api.InputUser) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.channels.ChannelParticipant?) {
                    let buffer = Buffer()
                    buffer.appendInt32(1416484774)
                    channel.serialize(buffer, true)
                    userId.serialize(buffer, true)
                    return (FunctionDescription({return "(channels.getParticipant channel: \(channel), userId: \(userId))"}), buffer, { (buffer: Buffer) -> Api.channels.ChannelParticipant? in
                        let reader = BufferReader(buffer)
                        var result: Api.channels.ChannelParticipant?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.channels.ChannelParticipant
                        }
                        return result
                    })
                }
            
                public static func getChannels(id: [Api.InputChannel]) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.messages.Chats?) {
                    let buffer = Buffer()
                    buffer.appendInt32(176122811)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(id.count))
                    for item in id {
                        item.serialize(buffer, true)
                    }
                    return (FunctionDescription({return "(channels.getChannels id: \(id))"}), buffer, { (buffer: Buffer) -> Api.messages.Chats? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.Chats?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.Chats
                        }
                        return result
                    })
                }
            
                public static func getFullChannel(channel: Api.InputChannel) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.messages.ChatFull?) {
                    let buffer = Buffer()
                    buffer.appendInt32(141781513)
                    channel.serialize(buffer, true)
                    return (FunctionDescription({return "(channels.getFullChannel channel: \(channel))"}), buffer, { (buffer: Buffer) -> Api.messages.ChatFull? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.ChatFull?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.ChatFull
                        }
                        return result
                    })
                }
            
                public static func createChannel(flags: Int32, title: String, about: String) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Updates?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-192332417)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(title, buffer: buffer, boxed: false)
                    serializeString(about, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(channels.createChannel flags: \(flags), title: \(title), about: \(about))"}), buffer, { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
            
                public static func editAbout(channel: Api.InputChannel, about: String) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Bool?) {
                    let buffer = Buffer()
                    buffer.appendInt32(333610782)
                    channel.serialize(buffer, true)
                    serializeString(about, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(channels.editAbout channel: \(channel), about: \(about))"}), buffer, { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func editTitle(channel: Api.InputChannel, title: String) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Updates?) {
                    let buffer = Buffer()
                    buffer.appendInt32(1450044624)
                    channel.serialize(buffer, true)
                    serializeString(title, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(channels.editTitle channel: \(channel), title: \(title))"}), buffer, { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
            
                public static func editPhoto(channel: Api.InputChannel, photo: Api.InputChatPhoto) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Updates?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-248621111)
                    channel.serialize(buffer, true)
                    photo.serialize(buffer, true)
                    return (FunctionDescription({return "(channels.editPhoto channel: \(channel), photo: \(photo))"}), buffer, { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
            
                public static func checkUsername(channel: Api.InputChannel, username: String) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Bool?) {
                    let buffer = Buffer()
                    buffer.appendInt32(283557164)
                    channel.serialize(buffer, true)
                    serializeString(username, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(channels.checkUsername channel: \(channel), username: \(username))"}), buffer, { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func updateUsername(channel: Api.InputChannel, username: String) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Bool?) {
                    let buffer = Buffer()
                    buffer.appendInt32(890549214)
                    channel.serialize(buffer, true)
                    serializeString(username, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(channels.updateUsername channel: \(channel), username: \(username))"}), buffer, { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func joinChannel(channel: Api.InputChannel) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Updates?) {
                    let buffer = Buffer()
                    buffer.appendInt32(615851205)
                    channel.serialize(buffer, true)
                    return (FunctionDescription({return "(channels.joinChannel channel: \(channel))"}), buffer, { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
            
                public static func leaveChannel(channel: Api.InputChannel) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Updates?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-130635115)
                    channel.serialize(buffer, true)
                    return (FunctionDescription({return "(channels.leaveChannel channel: \(channel))"}), buffer, { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
            
                public static func inviteToChannel(channel: Api.InputChannel, users: [Api.InputUser]) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Updates?) {
                    let buffer = Buffer()
                    buffer.appendInt32(429865580)
                    channel.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    return (FunctionDescription({return "(channels.inviteToChannel channel: \(channel), users: \(users))"}), buffer, { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
            
                public static func kickFromChannel(channel: Api.InputChannel, userId: Api.InputUser, kicked: Api.Bool) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Updates?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1502421484)
                    channel.serialize(buffer, true)
                    userId.serialize(buffer, true)
                    kicked.serialize(buffer, true)
                    return (FunctionDescription({return "(channels.kickFromChannel channel: \(channel), userId: \(userId), kicked: \(kicked))"}), buffer, { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
            
                public static func exportInvite(channel: Api.InputChannel) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.ExportedChatInvite?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-950663035)
                    channel.serialize(buffer, true)
                    return (FunctionDescription({return "(channels.exportInvite channel: \(channel))"}), buffer, { (buffer: Buffer) -> Api.ExportedChatInvite? in
                        let reader = BufferReader(buffer)
                        var result: Api.ExportedChatInvite?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.ExportedChatInvite
                        }
                        return result
                    })
                }
            
                public static func deleteChannel(channel: Api.InputChannel) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Updates?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1072619549)
                    channel.serialize(buffer, true)
                    return (FunctionDescription({return "(channels.deleteChannel channel: \(channel))"}), buffer, { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
            
                public static func toggleInvites(channel: Api.InputChannel, enabled: Api.Bool) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Updates?) {
                    let buffer = Buffer()
                    buffer.appendInt32(1231065863)
                    channel.serialize(buffer, true)
                    enabled.serialize(buffer, true)
                    return (FunctionDescription({return "(channels.toggleInvites channel: \(channel), enabled: \(enabled))"}), buffer, { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
            
                public static func toggleSignatures(channel: Api.InputChannel, enabled: Api.Bool) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Updates?) {
                    let buffer = Buffer()
                    buffer.appendInt32(527021574)
                    channel.serialize(buffer, true)
                    enabled.serialize(buffer, true)
                    return (FunctionDescription({return "(channels.toggleSignatures channel: \(channel), enabled: \(enabled))"}), buffer, { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
            
                public static func updatePinnedMessage(flags: Int32, channel: Api.InputChannel, id: Int32) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Updates?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1490162350)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    channel.serialize(buffer, true)
                    serializeInt32(id, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(channels.updatePinnedMessage flags: \(flags), channel: \(channel), id: \(id))"}), buffer, { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
            
                public static func getAdminedPublicChannels() -> (CustomStringConvertible, Buffer, (Buffer) -> Api.messages.Chats?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1920105769)
                    
                    return (FunctionDescription({return "(channels.getAdminedPublicChannels )"}), buffer, { (buffer: Buffer) -> Api.messages.Chats? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.Chats?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.Chats
                        }
                        return result
                    })
                }
            
                public static func editAdmin(channel: Api.InputChannel, userId: Api.InputUser, adminRights: Api.ChannelAdminRights) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Updates?) {
                    let buffer = Buffer()
                    buffer.appendInt32(548962836)
                    channel.serialize(buffer, true)
                    userId.serialize(buffer, true)
                    adminRights.serialize(buffer, true)
                    return (FunctionDescription({return "(channels.editAdmin channel: \(channel), userId: \(userId), adminRights: \(adminRights))"}), buffer, { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
            
                public static func editBanned(channel: Api.InputChannel, userId: Api.InputUser, bannedRights: Api.ChannelBannedRights) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Updates?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1076292147)
                    channel.serialize(buffer, true)
                    userId.serialize(buffer, true)
                    bannedRights.serialize(buffer, true)
                    return (FunctionDescription({return "(channels.editBanned channel: \(channel), userId: \(userId), bannedRights: \(bannedRights))"}), buffer, { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
            
                public static func getAdminLog(flags: Int32, channel: Api.InputChannel, q: String, eventsFilter: Api.ChannelAdminLogEventsFilter?, admins: [Api.InputUser]?, maxId: Int64, minId: Int64, limit: Int32) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.channels.AdminLogResults?) {
                    let buffer = Buffer()
                    buffer.appendInt32(870184064)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    channel.serialize(buffer, true)
                    serializeString(q, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {eventsFilter!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 1) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(admins!.count))
                    for item in admins! {
                        item.serialize(buffer, true)
                    }}
                    serializeInt64(maxId, buffer: buffer, boxed: false)
                    serializeInt64(minId, buffer: buffer, boxed: false)
                    serializeInt32(limit, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(channels.getAdminLog flags: \(flags), channel: \(channel), q: \(q), eventsFilter: \(String(describing: eventsFilter)), admins: \(String(describing: admins)), maxId: \(maxId), minId: \(minId), limit: \(limit))"}), buffer, { (buffer: Buffer) -> Api.channels.AdminLogResults? in
                        let reader = BufferReader(buffer)
                        var result: Api.channels.AdminLogResults?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.channels.AdminLogResults
                        }
                        return result
                    })
                }
            
                public static func setStickers(channel: Api.InputChannel, stickerset: Api.InputStickerSet) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Bool?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-359881479)
                    channel.serialize(buffer, true)
                    stickerset.serialize(buffer, true)
                    return (FunctionDescription({return "(channels.setStickers channel: \(channel), stickerset: \(stickerset))"}), buffer, { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func readMessageContents(channel: Api.InputChannel, id: [Int32]) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Bool?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-357180360)
                    channel.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(id.count))
                    for item in id {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    return (FunctionDescription({return "(channels.readMessageContents channel: \(channel), id: \(id))"}), buffer, { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func deleteHistory(channel: Api.InputChannel, maxId: Int32) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Bool?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1355375294)
                    channel.serialize(buffer, true)
                    serializeInt32(maxId, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(channels.deleteHistory channel: \(channel), maxId: \(maxId))"}), buffer, { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func togglePreHistoryHidden(channel: Api.InputChannel, enabled: Api.Bool) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Updates?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-356796084)
                    channel.serialize(buffer, true)
                    enabled.serialize(buffer, true)
                    return (FunctionDescription({return "(channels.togglePreHistoryHidden channel: \(channel), enabled: \(enabled))"}), buffer, { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
            
                public static func getParticipants(channel: Api.InputChannel, filter: Api.ChannelParticipantsFilter, offset: Int32, limit: Int32, hash: Int32) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.channels.ChannelParticipants?) {
                    let buffer = Buffer()
                    buffer.appendInt32(306054633)
                    channel.serialize(buffer, true)
                    filter.serialize(buffer, true)
                    serializeInt32(offset, buffer: buffer, boxed: false)
                    serializeInt32(limit, buffer: buffer, boxed: false)
                    serializeInt32(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(channels.getParticipants channel: \(channel), filter: \(filter), offset: \(offset), limit: \(limit), hash: \(hash))"}), buffer, { (buffer: Buffer) -> Api.channels.ChannelParticipants? in
                        let reader = BufferReader(buffer)
                        var result: Api.channels.ChannelParticipants?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.channels.ChannelParticipants
                        }
                        return result
                    })
                }
            
                public static func exportMessageLink(channel: Api.InputChannel, id: Int32, grouped: Api.Bool) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.ExportedMessageLink?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-826838685)
                    channel.serialize(buffer, true)
                    serializeInt32(id, buffer: buffer, boxed: false)
                    grouped.serialize(buffer, true)
                    return (FunctionDescription({return "(channels.exportMessageLink channel: \(channel), id: \(id), grouped: \(grouped))"}), buffer, { (buffer: Buffer) -> Api.ExportedMessageLink? in
                        let reader = BufferReader(buffer)
                        var result: Api.ExportedMessageLink?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.ExportedMessageLink
                        }
                        return result
                    })
                }
            
                public static func getMessages(channel: Api.InputChannel, id: [Api.InputMessage]) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.messages.Messages?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1383294429)
                    channel.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(id.count))
                    for item in id {
                        item.serialize(buffer, true)
                    }
                    return (FunctionDescription({return "(channels.getMessages channel: \(channel), id: \(id))"}), buffer, { (buffer: Buffer) -> Api.messages.Messages? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.Messages?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.Messages
                        }
                        return result
                    })
                }
            }
            public struct payments {
                public static func getPaymentForm(msgId: Int32) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.payments.PaymentForm?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1712285883)
                    serializeInt32(msgId, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(payments.getPaymentForm msgId: \(msgId))"}), buffer, { (buffer: Buffer) -> Api.payments.PaymentForm? in
                        let reader = BufferReader(buffer)
                        var result: Api.payments.PaymentForm?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.payments.PaymentForm
                        }
                        return result
                    })
                }
            
                public static func getPaymentReceipt(msgId: Int32) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.payments.PaymentReceipt?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1601001088)
                    serializeInt32(msgId, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(payments.getPaymentReceipt msgId: \(msgId))"}), buffer, { (buffer: Buffer) -> Api.payments.PaymentReceipt? in
                        let reader = BufferReader(buffer)
                        var result: Api.payments.PaymentReceipt?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.payments.PaymentReceipt
                        }
                        return result
                    })
                }
            
                public static func validateRequestedInfo(flags: Int32, msgId: Int32, info: Api.PaymentRequestedInfo) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.payments.ValidatedRequestedInfo?) {
                    let buffer = Buffer()
                    buffer.appendInt32(1997180532)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(msgId, buffer: buffer, boxed: false)
                    info.serialize(buffer, true)
                    return (FunctionDescription({return "(payments.validateRequestedInfo flags: \(flags), msgId: \(msgId), info: \(info))"}), buffer, { (buffer: Buffer) -> Api.payments.ValidatedRequestedInfo? in
                        let reader = BufferReader(buffer)
                        var result: Api.payments.ValidatedRequestedInfo?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.payments.ValidatedRequestedInfo
                        }
                        return result
                    })
                }
            
                public static func sendPaymentForm(flags: Int32, msgId: Int32, requestedInfoId: String?, shippingOptionId: String?, credentials: Api.InputPaymentCredentials) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.payments.PaymentResult?) {
                    let buffer = Buffer()
                    buffer.appendInt32(730364339)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(msgId, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(requestedInfoId!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(shippingOptionId!, buffer: buffer, boxed: false)}
                    credentials.serialize(buffer, true)
                    return (FunctionDescription({return "(payments.sendPaymentForm flags: \(flags), msgId: \(msgId), requestedInfoId: \(String(describing: requestedInfoId)), shippingOptionId: \(String(describing: shippingOptionId)), credentials: \(credentials))"}), buffer, { (buffer: Buffer) -> Api.payments.PaymentResult? in
                        let reader = BufferReader(buffer)
                        var result: Api.payments.PaymentResult?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.payments.PaymentResult
                        }
                        return result
                    })
                }
            
                public static func getSavedInfo() -> (CustomStringConvertible, Buffer, (Buffer) -> Api.payments.SavedInfo?) {
                    let buffer = Buffer()
                    buffer.appendInt32(578650699)
                    
                    return (FunctionDescription({return "(payments.getSavedInfo )"}), buffer, { (buffer: Buffer) -> Api.payments.SavedInfo? in
                        let reader = BufferReader(buffer)
                        var result: Api.payments.SavedInfo?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.payments.SavedInfo
                        }
                        return result
                    })
                }
            
                public static func clearSavedInfo(flags: Int32) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Bool?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-667062079)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(payments.clearSavedInfo flags: \(flags))"}), buffer, { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            }
            public struct auth {
                public static func checkPhone(phoneNumber: String) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.auth.CheckedPhone?) {
                    let buffer = Buffer()
                    buffer.appendInt32(1877286395)
                    serializeString(phoneNumber, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(auth.checkPhone phoneNumber: \(phoneNumber))"}), buffer, { (buffer: Buffer) -> Api.auth.CheckedPhone? in
                        let reader = BufferReader(buffer)
                        var result: Api.auth.CheckedPhone?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.auth.CheckedPhone
                        }
                        return result
                    })
                }
            
                public static func sendCode(flags: Int32, phoneNumber: String, currentNumber: Api.Bool?, apiId: Int32, apiHash: String) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.auth.SentCode?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-2035355412)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(phoneNumber, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {currentNumber!.serialize(buffer, true)}
                    serializeInt32(apiId, buffer: buffer, boxed: false)
                    serializeString(apiHash, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(auth.sendCode flags: \(flags), phoneNumber: \(phoneNumber), currentNumber: \(String(describing: currentNumber)), apiId: \(apiId), apiHash: \(apiHash))"}), buffer, { (buffer: Buffer) -> Api.auth.SentCode? in
                        let reader = BufferReader(buffer)
                        var result: Api.auth.SentCode?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.auth.SentCode
                        }
                        return result
                    })
                }
            
                public static func signUp(phoneNumber: String, phoneCodeHash: String, phoneCode: String, firstName: String, lastName: String) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.auth.Authorization?) {
                    let buffer = Buffer()
                    buffer.appendInt32(453408308)
                    serializeString(phoneNumber, buffer: buffer, boxed: false)
                    serializeString(phoneCodeHash, buffer: buffer, boxed: false)
                    serializeString(phoneCode, buffer: buffer, boxed: false)
                    serializeString(firstName, buffer: buffer, boxed: false)
                    serializeString(lastName, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(auth.signUp phoneNumber: \(phoneNumber), phoneCodeHash: \(phoneCodeHash), phoneCode: \(phoneCode), firstName: \(firstName), lastName: \(lastName))"}), buffer, { (buffer: Buffer) -> Api.auth.Authorization? in
                        let reader = BufferReader(buffer)
                        var result: Api.auth.Authorization?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.auth.Authorization
                        }
                        return result
                    })
                }
            
                public static func signIn(phoneNumber: String, phoneCodeHash: String, phoneCode: String) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.auth.Authorization?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1126886015)
                    serializeString(phoneNumber, buffer: buffer, boxed: false)
                    serializeString(phoneCodeHash, buffer: buffer, boxed: false)
                    serializeString(phoneCode, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(auth.signIn phoneNumber: \(phoneNumber), phoneCodeHash: \(phoneCodeHash), phoneCode: \(phoneCode))"}), buffer, { (buffer: Buffer) -> Api.auth.Authorization? in
                        let reader = BufferReader(buffer)
                        var result: Api.auth.Authorization?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.auth.Authorization
                        }
                        return result
                    })
                }
            
                public static func logOut() -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Bool?) {
                    let buffer = Buffer()
                    buffer.appendInt32(1461180992)
                    
                    return (FunctionDescription({return "(auth.logOut )"}), buffer, { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func resetAuthorizations() -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Bool?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1616179942)
                    
                    return (FunctionDescription({return "(auth.resetAuthorizations )"}), buffer, { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func sendInvites(phoneNumbers: [String], message: String) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Bool?) {
                    let buffer = Buffer()
                    buffer.appendInt32(1998331287)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(phoneNumbers.count))
                    for item in phoneNumbers {
                        serializeString(item, buffer: buffer, boxed: false)
                    }
                    serializeString(message, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(auth.sendInvites phoneNumbers: \(phoneNumbers), message: \(message))"}), buffer, { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func exportAuthorization(dcId: Int32) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.auth.ExportedAuthorization?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-440401971)
                    serializeInt32(dcId, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(auth.exportAuthorization dcId: \(dcId))"}), buffer, { (buffer: Buffer) -> Api.auth.ExportedAuthorization? in
                        let reader = BufferReader(buffer)
                        var result: Api.auth.ExportedAuthorization?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.auth.ExportedAuthorization
                        }
                        return result
                    })
                }
            
                public static func importAuthorization(id: Int32, bytes: Buffer) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.auth.Authorization?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-470837741)
                    serializeInt32(id, buffer: buffer, boxed: false)
                    serializeBytes(bytes, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(auth.importAuthorization id: \(id), bytes: \(bytes))"}), buffer, { (buffer: Buffer) -> Api.auth.Authorization? in
                        let reader = BufferReader(buffer)
                        var result: Api.auth.Authorization?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.auth.Authorization
                        }
                        return result
                    })
                }
            
                public static func bindTempAuthKey(permAuthKeyId: Int64, nonce: Int64, expiresAt: Int32, encryptedMessage: Buffer) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Bool?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-841733627)
                    serializeInt64(permAuthKeyId, buffer: buffer, boxed: false)
                    serializeInt64(nonce, buffer: buffer, boxed: false)
                    serializeInt32(expiresAt, buffer: buffer, boxed: false)
                    serializeBytes(encryptedMessage, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(auth.bindTempAuthKey permAuthKeyId: \(permAuthKeyId), nonce: \(nonce), expiresAt: \(expiresAt), encryptedMessage: \(encryptedMessage))"}), buffer, { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func importBotAuthorization(flags: Int32, apiId: Int32, apiHash: String, botAuthToken: String) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.auth.Authorization?) {
                    let buffer = Buffer()
                    buffer.appendInt32(1738800940)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(apiId, buffer: buffer, boxed: false)
                    serializeString(apiHash, buffer: buffer, boxed: false)
                    serializeString(botAuthToken, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(auth.importBotAuthorization flags: \(flags), apiId: \(apiId), apiHash: \(apiHash), botAuthToken: \(botAuthToken))"}), buffer, { (buffer: Buffer) -> Api.auth.Authorization? in
                        let reader = BufferReader(buffer)
                        var result: Api.auth.Authorization?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.auth.Authorization
                        }
                        return result
                    })
                }
            
                public static func checkPassword(passwordHash: Buffer) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.auth.Authorization?) {
                    let buffer = Buffer()
                    buffer.appendInt32(174260510)
                    serializeBytes(passwordHash, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(auth.checkPassword passwordHash: \(passwordHash))"}), buffer, { (buffer: Buffer) -> Api.auth.Authorization? in
                        let reader = BufferReader(buffer)
                        var result: Api.auth.Authorization?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.auth.Authorization
                        }
                        return result
                    })
                }
            
                public static func requestPasswordRecovery() -> (CustomStringConvertible, Buffer, (Buffer) -> Api.auth.PasswordRecovery?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-661144474)
                    
                    return (FunctionDescription({return "(auth.requestPasswordRecovery )"}), buffer, { (buffer: Buffer) -> Api.auth.PasswordRecovery? in
                        let reader = BufferReader(buffer)
                        var result: Api.auth.PasswordRecovery?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.auth.PasswordRecovery
                        }
                        return result
                    })
                }
            
                public static func recoverPassword(code: String) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.auth.Authorization?) {
                    let buffer = Buffer()
                    buffer.appendInt32(1319464594)
                    serializeString(code, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(auth.recoverPassword code: \(code))"}), buffer, { (buffer: Buffer) -> Api.auth.Authorization? in
                        let reader = BufferReader(buffer)
                        var result: Api.auth.Authorization?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.auth.Authorization
                        }
                        return result
                    })
                }
            
                public static func resendCode(phoneNumber: String, phoneCodeHash: String) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.auth.SentCode?) {
                    let buffer = Buffer()
                    buffer.appendInt32(1056025023)
                    serializeString(phoneNumber, buffer: buffer, boxed: false)
                    serializeString(phoneCodeHash, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(auth.resendCode phoneNumber: \(phoneNumber), phoneCodeHash: \(phoneCodeHash))"}), buffer, { (buffer: Buffer) -> Api.auth.SentCode? in
                        let reader = BufferReader(buffer)
                        var result: Api.auth.SentCode?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.auth.SentCode
                        }
                        return result
                    })
                }
            
                public static func cancelCode(phoneNumber: String, phoneCodeHash: String) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Bool?) {
                    let buffer = Buffer()
                    buffer.appendInt32(520357240)
                    serializeString(phoneNumber, buffer: buffer, boxed: false)
                    serializeString(phoneCodeHash, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(auth.cancelCode phoneNumber: \(phoneNumber), phoneCodeHash: \(phoneCodeHash))"}), buffer, { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func dropTempAuthKeys(exceptAuthKeys: [Int64]) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Bool?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1907842680)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(exceptAuthKeys.count))
                    for item in exceptAuthKeys {
                        serializeInt64(item, buffer: buffer, boxed: false)
                    }
                    return (FunctionDescription({return "(auth.dropTempAuthKeys exceptAuthKeys: \(exceptAuthKeys))"}), buffer, { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            }
            public struct bots {
                public static func sendCustomRequest(customMethod: String, params: Api.DataJSON) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.DataJSON?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1440257555)
                    serializeString(customMethod, buffer: buffer, boxed: false)
                    params.serialize(buffer, true)
                    return (FunctionDescription({return "(bots.sendCustomRequest customMethod: \(customMethod), params: \(params))"}), buffer, { (buffer: Buffer) -> Api.DataJSON? in
                        let reader = BufferReader(buffer)
                        var result: Api.DataJSON?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.DataJSON
                        }
                        return result
                    })
                }
            
                public static func answerWebhookJSONQuery(queryId: Int64, data: Api.DataJSON) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Bool?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-434028723)
                    serializeInt64(queryId, buffer: buffer, boxed: false)
                    data.serialize(buffer, true)
                    return (FunctionDescription({return "(bots.answerWebhookJSONQuery queryId: \(queryId), data: \(data))"}), buffer, { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            }
            public struct users {
                public static func getUsers(id: [Api.InputUser]) -> (CustomStringConvertible, Buffer, (Buffer) -> [Api.User]?) {
                    let buffer = Buffer()
                    buffer.appendInt32(227648840)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(id.count))
                    for item in id {
                        item.serialize(buffer, true)
                    }
                    return (FunctionDescription({return "(users.getUsers id: \(id))"}), buffer, { (buffer: Buffer) -> [Api.User]? in
                        let reader = BufferReader(buffer)
                        var result: [Api.User]?
                        if let _ = reader.readInt32() {
                            result = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
                        }
                        return result
                    })
                }
            
                public static func getFullUser(id: Api.InputUser) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.UserFull?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-902781519)
                    id.serialize(buffer, true)
                    return (FunctionDescription({return "(users.getFullUser id: \(id))"}), buffer, { (buffer: Buffer) -> Api.UserFull? in
                        let reader = BufferReader(buffer)
                        var result: Api.UserFull?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.UserFull
                        }
                        return result
                    })
                }
            
                public static func setSecureValueErrors(id: Api.InputUser, errors: [Api.SecureValueError]) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Bool?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1865902923)
                    id.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(errors.count))
                    for item in errors {
                        item.serialize(buffer, true)
                    }
                    return (FunctionDescription({return "(users.setSecureValueErrors id: \(id), errors: \(errors))"}), buffer, { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            }
            public struct contacts {
                public static func getStatuses() -> (CustomStringConvertible, Buffer, (Buffer) -> [Api.ContactStatus]?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-995929106)
                    
                    return (FunctionDescription({return "(contacts.getStatuses )"}), buffer, { (buffer: Buffer) -> [Api.ContactStatus]? in
                        let reader = BufferReader(buffer)
                        var result: [Api.ContactStatus]?
                        if let _ = reader.readInt32() {
                            result = Api.parseVector(reader, elementSignature: 0, elementType: Api.ContactStatus.self)
                        }
                        return result
                    })
                }
            
                public static func deleteContact(id: Api.InputUser) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.contacts.Link?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1902823612)
                    id.serialize(buffer, true)
                    return (FunctionDescription({return "(contacts.deleteContact id: \(id))"}), buffer, { (buffer: Buffer) -> Api.contacts.Link? in
                        let reader = BufferReader(buffer)
                        var result: Api.contacts.Link?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.contacts.Link
                        }
                        return result
                    })
                }
            
                public static func deleteContacts(id: [Api.InputUser]) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Bool?) {
                    let buffer = Buffer()
                    buffer.appendInt32(1504393374)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(id.count))
                    for item in id {
                        item.serialize(buffer, true)
                    }
                    return (FunctionDescription({return "(contacts.deleteContacts id: \(id))"}), buffer, { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func block(id: Api.InputUser) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Bool?) {
                    let buffer = Buffer()
                    buffer.appendInt32(858475004)
                    id.serialize(buffer, true)
                    return (FunctionDescription({return "(contacts.block id: \(id))"}), buffer, { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func unblock(id: Api.InputUser) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Bool?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-448724803)
                    id.serialize(buffer, true)
                    return (FunctionDescription({return "(contacts.unblock id: \(id))"}), buffer, { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func getBlocked(offset: Int32, limit: Int32) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.contacts.Blocked?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-176409329)
                    serializeInt32(offset, buffer: buffer, boxed: false)
                    serializeInt32(limit, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(contacts.getBlocked offset: \(offset), limit: \(limit))"}), buffer, { (buffer: Buffer) -> Api.contacts.Blocked? in
                        let reader = BufferReader(buffer)
                        var result: Api.contacts.Blocked?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.contacts.Blocked
                        }
                        return result
                    })
                }
            
                public static func exportCard() -> (CustomStringConvertible, Buffer, (Buffer) -> [Int32]?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-2065352905)
                    
                    return (FunctionDescription({return "(contacts.exportCard )"}), buffer, { (buffer: Buffer) -> [Int32]? in
                        let reader = BufferReader(buffer)
                        var result: [Int32]?
                        if let _ = reader.readInt32() {
                            result = Api.parseVector(reader, elementSignature: -1471112230, elementType: Int32.self)
                        }
                        return result
                    })
                }
            
                public static func importCard(exportCard: [Int32]) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.User?) {
                    let buffer = Buffer()
                    buffer.appendInt32(1340184318)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(exportCard.count))
                    for item in exportCard {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    return (FunctionDescription({return "(contacts.importCard exportCard: \(exportCard))"}), buffer, { (buffer: Buffer) -> Api.User? in
                        let reader = BufferReader(buffer)
                        var result: Api.User?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.User
                        }
                        return result
                    })
                }
            
                public static func search(q: String, limit: Int32) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.contacts.Found?) {
                    let buffer = Buffer()
                    buffer.appendInt32(301470424)
                    serializeString(q, buffer: buffer, boxed: false)
                    serializeInt32(limit, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(contacts.search q: \(q), limit: \(limit))"}), buffer, { (buffer: Buffer) -> Api.contacts.Found? in
                        let reader = BufferReader(buffer)
                        var result: Api.contacts.Found?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.contacts.Found
                        }
                        return result
                    })
                }
            
                public static func resolveUsername(username: String) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.contacts.ResolvedPeer?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-113456221)
                    serializeString(username, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(contacts.resolveUsername username: \(username))"}), buffer, { (buffer: Buffer) -> Api.contacts.ResolvedPeer? in
                        let reader = BufferReader(buffer)
                        var result: Api.contacts.ResolvedPeer?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.contacts.ResolvedPeer
                        }
                        return result
                    })
                }
            
                public static func getTopPeers(flags: Int32, offset: Int32, limit: Int32, hash: Int32) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.contacts.TopPeers?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-728224331)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(offset, buffer: buffer, boxed: false)
                    serializeInt32(limit, buffer: buffer, boxed: false)
                    serializeInt32(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(contacts.getTopPeers flags: \(flags), offset: \(offset), limit: \(limit), hash: \(hash))"}), buffer, { (buffer: Buffer) -> Api.contacts.TopPeers? in
                        let reader = BufferReader(buffer)
                        var result: Api.contacts.TopPeers?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.contacts.TopPeers
                        }
                        return result
                    })
                }
            
                public static func resetTopPeerRating(category: Api.TopPeerCategory, peer: Api.InputPeer) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Bool?) {
                    let buffer = Buffer()
                    buffer.appendInt32(451113900)
                    category.serialize(buffer, true)
                    peer.serialize(buffer, true)
                    return (FunctionDescription({return "(contacts.resetTopPeerRating category: \(category), peer: \(peer))"}), buffer, { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func importContacts(contacts: [Api.InputContact]) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.contacts.ImportedContacts?) {
                    let buffer = Buffer()
                    buffer.appendInt32(746589157)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(contacts.count))
                    for item in contacts {
                        item.serialize(buffer, true)
                    }
                    return (FunctionDescription({return "(contacts.importContacts contacts: \(contacts))"}), buffer, { (buffer: Buffer) -> Api.contacts.ImportedContacts? in
                        let reader = BufferReader(buffer)
                        var result: Api.contacts.ImportedContacts?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.contacts.ImportedContacts
                        }
                        return result
                    })
                }
            
                public static func resetSaved() -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Bool?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-2020263951)
                    
                    return (FunctionDescription({return "(contacts.resetSaved )"}), buffer, { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func getContacts(hash: Int32) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.contacts.Contacts?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1071414113)
                    serializeInt32(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(contacts.getContacts hash: \(hash))"}), buffer, { (buffer: Buffer) -> Api.contacts.Contacts? in
                        let reader = BufferReader(buffer)
                        var result: Api.contacts.Contacts?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.contacts.Contacts
                        }
                        return result
                    })
                }
            }
            public struct help {
                public static func getConfig() -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Config?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-990308245)
                    
                    return (FunctionDescription({return "(help.getConfig )"}), buffer, { (buffer: Buffer) -> Api.Config? in
                        let reader = BufferReader(buffer)
                        var result: Api.Config?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Config
                        }
                        return result
                    })
                }
            
                public static func getNearestDc() -> (CustomStringConvertible, Buffer, (Buffer) -> Api.NearestDc?) {
                    let buffer = Buffer()
                    buffer.appendInt32(531836966)
                    
                    return (FunctionDescription({return "(help.getNearestDc )"}), buffer, { (buffer: Buffer) -> Api.NearestDc? in
                        let reader = BufferReader(buffer)
                        var result: Api.NearestDc?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.NearestDc
                        }
                        return result
                    })
                }
            
                public static func getAppUpdate() -> (CustomStringConvertible, Buffer, (Buffer) -> Api.help.AppUpdate?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1372724842)
                    
                    return (FunctionDescription({return "(help.getAppUpdate )"}), buffer, { (buffer: Buffer) -> Api.help.AppUpdate? in
                        let reader = BufferReader(buffer)
                        var result: Api.help.AppUpdate?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.help.AppUpdate
                        }
                        return result
                    })
                }
            
                public static func saveAppLog(events: [Api.InputAppEvent]) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Bool?) {
                    let buffer = Buffer()
                    buffer.appendInt32(1862465352)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(events.count))
                    for item in events {
                        item.serialize(buffer, true)
                    }
                    return (FunctionDescription({return "(help.saveAppLog events: \(events))"}), buffer, { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func getInviteText() -> (CustomStringConvertible, Buffer, (Buffer) -> Api.help.InviteText?) {
                    let buffer = Buffer()
                    buffer.appendInt32(1295590211)
                    
                    return (FunctionDescription({return "(help.getInviteText )"}), buffer, { (buffer: Buffer) -> Api.help.InviteText? in
                        let reader = BufferReader(buffer)
                        var result: Api.help.InviteText?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.help.InviteText
                        }
                        return result
                    })
                }
            
                public static func getSupport() -> (CustomStringConvertible, Buffer, (Buffer) -> Api.help.Support?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1663104819)
                    
                    return (FunctionDescription({return "(help.getSupport )"}), buffer, { (buffer: Buffer) -> Api.help.Support? in
                        let reader = BufferReader(buffer)
                        var result: Api.help.Support?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.help.Support
                        }
                        return result
                    })
                }
            
                public static func getAppChangelog(prevAppVersion: String) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Updates?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1877938321)
                    serializeString(prevAppVersion, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(help.getAppChangelog prevAppVersion: \(prevAppVersion))"}), buffer, { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
            
                public static func getTermsOfService() -> (CustomStringConvertible, Buffer, (Buffer) -> Api.help.TermsOfService?) {
                    let buffer = Buffer()
                    buffer.appendInt32(889286899)
                    
                    return (FunctionDescription({return "(help.getTermsOfService )"}), buffer, { (buffer: Buffer) -> Api.help.TermsOfService? in
                        let reader = BufferReader(buffer)
                        var result: Api.help.TermsOfService?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.help.TermsOfService
                        }
                        return result
                    })
                }
            
                public static func setBotUpdatesStatus(pendingUpdatesCount: Int32, message: String) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Bool?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-333262899)
                    serializeInt32(pendingUpdatesCount, buffer: buffer, boxed: false)
                    serializeString(message, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(help.setBotUpdatesStatus pendingUpdatesCount: \(pendingUpdatesCount), message: \(message))"}), buffer, { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func getCdnConfig() -> (CustomStringConvertible, Buffer, (Buffer) -> Api.CdnConfig?) {
                    let buffer = Buffer()
                    buffer.appendInt32(1375900482)
                    
                    return (FunctionDescription({return "(help.getCdnConfig )"}), buffer, { (buffer: Buffer) -> Api.CdnConfig? in
                        let reader = BufferReader(buffer)
                        var result: Api.CdnConfig?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.CdnConfig
                        }
                        return result
                    })
                }
            
                public static func test() -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Bool?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1058929929)
                    
                    return (FunctionDescription({return "(help.test )"}), buffer, { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func getRecentMeUrls(referer: String) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.help.RecentMeUrls?) {
                    let buffer = Buffer()
                    buffer.appendInt32(1036054804)
                    serializeString(referer, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(help.getRecentMeUrls referer: \(referer))"}), buffer, { (buffer: Buffer) -> Api.help.RecentMeUrls? in
                        let reader = BufferReader(buffer)
                        var result: Api.help.RecentMeUrls?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.help.RecentMeUrls
                        }
                        return result
                    })
                }
            
                public static func getProxyData() -> (CustomStringConvertible, Buffer, (Buffer) -> Api.help.ProxyData?) {
                    let buffer = Buffer()
                    buffer.appendInt32(1031231713)
                    
                    return (FunctionDescription({return "(help.getProxyData )"}), buffer, { (buffer: Buffer) -> Api.help.ProxyData? in
                        let reader = BufferReader(buffer)
                        var result: Api.help.ProxyData?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.help.ProxyData
                        }
                        return result
                    })
                }
            
                public static func getDeepLinkInfo(path: String) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.help.DeepLinkInfo?) {
                    let buffer = Buffer()
                    buffer.appendInt32(1072547679)
                    serializeString(path, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(help.getDeepLinkInfo path: \(path))"}), buffer, { (buffer: Buffer) -> Api.help.DeepLinkInfo? in
                        let reader = BufferReader(buffer)
                        var result: Api.help.DeepLinkInfo?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.help.DeepLinkInfo
                        }
                        return result
                    })
                }
            }
            public struct updates {
                public static func getState() -> (CustomStringConvertible, Buffer, (Buffer) -> Api.updates.State?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-304838614)
                    
                    return (FunctionDescription({return "(updates.getState )"}), buffer, { (buffer: Buffer) -> Api.updates.State? in
                        let reader = BufferReader(buffer)
                        var result: Api.updates.State?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.updates.State
                        }
                        return result
                    })
                }
            
                public static func getDifference(flags: Int32, pts: Int32, ptsTotalLimit: Int32?, date: Int32, qts: Int32) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.updates.Difference?) {
                    let buffer = Buffer()
                    buffer.appendInt32(630429265)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(pts, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(ptsTotalLimit!, buffer: buffer, boxed: false)}
                    serializeInt32(date, buffer: buffer, boxed: false)
                    serializeInt32(qts, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(updates.getDifference flags: \(flags), pts: \(pts), ptsTotalLimit: \(String(describing: ptsTotalLimit)), date: \(date), qts: \(qts))"}), buffer, { (buffer: Buffer) -> Api.updates.Difference? in
                        let reader = BufferReader(buffer)
                        var result: Api.updates.Difference?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.updates.Difference
                        }
                        return result
                    })
                }
            
                public static func getChannelDifference(flags: Int32, channel: Api.InputChannel, filter: Api.ChannelMessagesFilter, pts: Int32, limit: Int32) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.updates.ChannelDifference?) {
                    let buffer = Buffer()
                    buffer.appendInt32(51854712)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    channel.serialize(buffer, true)
                    filter.serialize(buffer, true)
                    serializeInt32(pts, buffer: buffer, boxed: false)
                    serializeInt32(limit, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(updates.getChannelDifference flags: \(flags), channel: \(channel), filter: \(filter), pts: \(pts), limit: \(limit))"}), buffer, { (buffer: Buffer) -> Api.updates.ChannelDifference? in
                        let reader = BufferReader(buffer)
                        var result: Api.updates.ChannelDifference?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.updates.ChannelDifference
                        }
                        return result
                    })
                }
            }
            public struct upload {
                public static func saveFilePart(fileId: Int64, filePart: Int32, bytes: Buffer) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Bool?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1291540959)
                    serializeInt64(fileId, buffer: buffer, boxed: false)
                    serializeInt32(filePart, buffer: buffer, boxed: false)
                    serializeBytes(bytes, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(upload.saveFilePart fileId: \(fileId), filePart: \(filePart), bytes: \(bytes))"}), buffer, { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func getFile(location: Api.InputFileLocation, offset: Int32, limit: Int32) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.upload.File?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-475607115)
                    location.serialize(buffer, true)
                    serializeInt32(offset, buffer: buffer, boxed: false)
                    serializeInt32(limit, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(upload.getFile location: \(location), offset: \(offset), limit: \(limit))"}), buffer, { (buffer: Buffer) -> Api.upload.File? in
                        let reader = BufferReader(buffer)
                        var result: Api.upload.File?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.upload.File
                        }
                        return result
                    })
                }
            
                public static func saveBigFilePart(fileId: Int64, filePart: Int32, fileTotalParts: Int32, bytes: Buffer) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Bool?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-562337987)
                    serializeInt64(fileId, buffer: buffer, boxed: false)
                    serializeInt32(filePart, buffer: buffer, boxed: false)
                    serializeInt32(fileTotalParts, buffer: buffer, boxed: false)
                    serializeBytes(bytes, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(upload.saveBigFilePart fileId: \(fileId), filePart: \(filePart), fileTotalParts: \(fileTotalParts), bytes: \(bytes))"}), buffer, { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func getWebFile(location: Api.InputWebFileLocation, offset: Int32, limit: Int32) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.upload.WebFile?) {
                    let buffer = Buffer()
                    buffer.appendInt32(619086221)
                    location.serialize(buffer, true)
                    serializeInt32(offset, buffer: buffer, boxed: false)
                    serializeInt32(limit, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(upload.getWebFile location: \(location), offset: \(offset), limit: \(limit))"}), buffer, { (buffer: Buffer) -> Api.upload.WebFile? in
                        let reader = BufferReader(buffer)
                        var result: Api.upload.WebFile?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.upload.WebFile
                        }
                        return result
                    })
                }
            
                public static func getCdnFile(fileToken: Buffer, offset: Int32, limit: Int32) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.upload.CdnFile?) {
                    let buffer = Buffer()
                    buffer.appendInt32(536919235)
                    serializeBytes(fileToken, buffer: buffer, boxed: false)
                    serializeInt32(offset, buffer: buffer, boxed: false)
                    serializeInt32(limit, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(upload.getCdnFile fileToken: \(fileToken), offset: \(offset), limit: \(limit))"}), buffer, { (buffer: Buffer) -> Api.upload.CdnFile? in
                        let reader = BufferReader(buffer)
                        var result: Api.upload.CdnFile?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.upload.CdnFile
                        }
                        return result
                    })
                }
            
                public static func reuploadCdnFile(fileToken: Buffer, requestToken: Buffer) -> (CustomStringConvertible, Buffer, (Buffer) -> [Api.FileHash]?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1691921240)
                    serializeBytes(fileToken, buffer: buffer, boxed: false)
                    serializeBytes(requestToken, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(upload.reuploadCdnFile fileToken: \(fileToken), requestToken: \(requestToken))"}), buffer, { (buffer: Buffer) -> [Api.FileHash]? in
                        let reader = BufferReader(buffer)
                        var result: [Api.FileHash]?
                        if let _ = reader.readInt32() {
                            result = Api.parseVector(reader, elementSignature: 0, elementType: Api.FileHash.self)
                        }
                        return result
                    })
                }
            
                public static func getCdnFileHashes(fileToken: Buffer, offset: Int32) -> (CustomStringConvertible, Buffer, (Buffer) -> [Api.FileHash]?) {
                    let buffer = Buffer()
                    buffer.appendInt32(1302676017)
                    serializeBytes(fileToken, buffer: buffer, boxed: false)
                    serializeInt32(offset, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(upload.getCdnFileHashes fileToken: \(fileToken), offset: \(offset))"}), buffer, { (buffer: Buffer) -> [Api.FileHash]? in
                        let reader = BufferReader(buffer)
                        var result: [Api.FileHash]?
                        if let _ = reader.readInt32() {
                            result = Api.parseVector(reader, elementSignature: 0, elementType: Api.FileHash.self)
                        }
                        return result
                    })
                }
            
                public static func getFileHashes(location: Api.InputFileLocation, offset: Int32) -> (CustomStringConvertible, Buffer, (Buffer) -> [Api.FileHash]?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-956147407)
                    location.serialize(buffer, true)
                    serializeInt32(offset, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(upload.getFileHashes location: \(location), offset: \(offset))"}), buffer, { (buffer: Buffer) -> [Api.FileHash]? in
                        let reader = BufferReader(buffer)
                        var result: [Api.FileHash]?
                        if let _ = reader.readInt32() {
                            result = Api.parseVector(reader, elementSignature: 0, elementType: Api.FileHash.self)
                        }
                        return result
                    })
                }
            }
            public struct account {
                public static func updateNotifySettings(peer: Api.InputNotifyPeer, settings: Api.InputPeerNotifySettings) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Bool?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-2067899501)
                    peer.serialize(buffer, true)
                    settings.serialize(buffer, true)
                    return (FunctionDescription({return "(account.updateNotifySettings peer: \(peer), settings: \(settings))"}), buffer, { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func getNotifySettings(peer: Api.InputNotifyPeer) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.PeerNotifySettings?) {
                    let buffer = Buffer()
                    buffer.appendInt32(313765169)
                    peer.serialize(buffer, true)
                    return (FunctionDescription({return "(account.getNotifySettings peer: \(peer))"}), buffer, { (buffer: Buffer) -> Api.PeerNotifySettings? in
                        let reader = BufferReader(buffer)
                        var result: Api.PeerNotifySettings?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.PeerNotifySettings
                        }
                        return result
                    })
                }
            
                public static func resetNotifySettings() -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Bool?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-612493497)
                    
                    return (FunctionDescription({return "(account.resetNotifySettings )"}), buffer, { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func updateProfile(flags: Int32, firstName: String?, lastName: String?, about: String?) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.User?) {
                    let buffer = Buffer()
                    buffer.appendInt32(2018596725)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(firstName!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(lastName!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeString(about!, buffer: buffer, boxed: false)}
                    return (FunctionDescription({return "(account.updateProfile flags: \(flags), firstName: \(String(describing: firstName)), lastName: \(String(describing: lastName)), about: \(String(describing: about)))"}), buffer, { (buffer: Buffer) -> Api.User? in
                        let reader = BufferReader(buffer)
                        var result: Api.User?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.User
                        }
                        return result
                    })
                }
            
                public static func updateStatus(offline: Api.Bool) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Bool?) {
                    let buffer = Buffer()
                    buffer.appendInt32(1713919532)
                    offline.serialize(buffer, true)
                    return (FunctionDescription({return "(account.updateStatus offline: \(offline))"}), buffer, { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func getWallPapers() -> (CustomStringConvertible, Buffer, (Buffer) -> [Api.WallPaper]?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1068696894)
                    
                    return (FunctionDescription({return "(account.getWallPapers )"}), buffer, { (buffer: Buffer) -> [Api.WallPaper]? in
                        let reader = BufferReader(buffer)
                        var result: [Api.WallPaper]?
                        if let _ = reader.readInt32() {
                            result = Api.parseVector(reader, elementSignature: 0, elementType: Api.WallPaper.self)
                        }
                        return result
                    })
                }
            
                public static func reportPeer(peer: Api.InputPeer, reason: Api.ReportReason) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Bool?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1374118561)
                    peer.serialize(buffer, true)
                    reason.serialize(buffer, true)
                    return (FunctionDescription({return "(account.reportPeer peer: \(peer), reason: \(reason))"}), buffer, { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func checkUsername(username: String) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Bool?) {
                    let buffer = Buffer()
                    buffer.appendInt32(655677548)
                    serializeString(username, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(account.checkUsername username: \(username))"}), buffer, { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func updateUsername(username: String) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.User?) {
                    let buffer = Buffer()
                    buffer.appendInt32(1040964988)
                    serializeString(username, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(account.updateUsername username: \(username))"}), buffer, { (buffer: Buffer) -> Api.User? in
                        let reader = BufferReader(buffer)
                        var result: Api.User?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.User
                        }
                        return result
                    })
                }
            
                public static func getPrivacy(key: Api.InputPrivacyKey) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.account.PrivacyRules?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-623130288)
                    key.serialize(buffer, true)
                    return (FunctionDescription({return "(account.getPrivacy key: \(key))"}), buffer, { (buffer: Buffer) -> Api.account.PrivacyRules? in
                        let reader = BufferReader(buffer)
                        var result: Api.account.PrivacyRules?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.account.PrivacyRules
                        }
                        return result
                    })
                }
            
                public static func setPrivacy(key: Api.InputPrivacyKey, rules: [Api.InputPrivacyRule]) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.account.PrivacyRules?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-906486552)
                    key.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(rules.count))
                    for item in rules {
                        item.serialize(buffer, true)
                    }
                    return (FunctionDescription({return "(account.setPrivacy key: \(key), rules: \(rules))"}), buffer, { (buffer: Buffer) -> Api.account.PrivacyRules? in
                        let reader = BufferReader(buffer)
                        var result: Api.account.PrivacyRules?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.account.PrivacyRules
                        }
                        return result
                    })
                }
            
                public static func deleteAccount(reason: String) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Bool?) {
                    let buffer = Buffer()
                    buffer.appendInt32(1099779595)
                    serializeString(reason, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(account.deleteAccount reason: \(reason))"}), buffer, { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func getAccountTTL() -> (CustomStringConvertible, Buffer, (Buffer) -> Api.AccountDaysTTL?) {
                    let buffer = Buffer()
                    buffer.appendInt32(150761757)
                    
                    return (FunctionDescription({return "(account.getAccountTTL )"}), buffer, { (buffer: Buffer) -> Api.AccountDaysTTL? in
                        let reader = BufferReader(buffer)
                        var result: Api.AccountDaysTTL?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.AccountDaysTTL
                        }
                        return result
                    })
                }
            
                public static func setAccountTTL(ttl: Api.AccountDaysTTL) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Bool?) {
                    let buffer = Buffer()
                    buffer.appendInt32(608323678)
                    ttl.serialize(buffer, true)
                    return (FunctionDescription({return "(account.setAccountTTL ttl: \(ttl))"}), buffer, { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func sendChangePhoneCode(flags: Int32, phoneNumber: String, currentNumber: Api.Bool?) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.auth.SentCode?) {
                    let buffer = Buffer()
                    buffer.appendInt32(149257707)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(phoneNumber, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {currentNumber!.serialize(buffer, true)}
                    return (FunctionDescription({return "(account.sendChangePhoneCode flags: \(flags), phoneNumber: \(phoneNumber), currentNumber: \(String(describing: currentNumber)))"}), buffer, { (buffer: Buffer) -> Api.auth.SentCode? in
                        let reader = BufferReader(buffer)
                        var result: Api.auth.SentCode?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.auth.SentCode
                        }
                        return result
                    })
                }
            
                public static func changePhone(phoneNumber: String, phoneCodeHash: String, phoneCode: String) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.User?) {
                    let buffer = Buffer()
                    buffer.appendInt32(1891839707)
                    serializeString(phoneNumber, buffer: buffer, boxed: false)
                    serializeString(phoneCodeHash, buffer: buffer, boxed: false)
                    serializeString(phoneCode, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(account.changePhone phoneNumber: \(phoneNumber), phoneCodeHash: \(phoneCodeHash), phoneCode: \(phoneCode))"}), buffer, { (buffer: Buffer) -> Api.User? in
                        let reader = BufferReader(buffer)
                        var result: Api.User?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.User
                        }
                        return result
                    })
                }
            
                public static func updateDeviceLocked(period: Int32) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Bool?) {
                    let buffer = Buffer()
                    buffer.appendInt32(954152242)
                    serializeInt32(period, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(account.updateDeviceLocked period: \(period))"}), buffer, { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func getAuthorizations() -> (CustomStringConvertible, Buffer, (Buffer) -> Api.account.Authorizations?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-484392616)
                    
                    return (FunctionDescription({return "(account.getAuthorizations )"}), buffer, { (buffer: Buffer) -> Api.account.Authorizations? in
                        let reader = BufferReader(buffer)
                        var result: Api.account.Authorizations?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.account.Authorizations
                        }
                        return result
                    })
                }
            
                public static func resetAuthorization(hash: Int64) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Bool?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-545786948)
                    serializeInt64(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(account.resetAuthorization hash: \(hash))"}), buffer, { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func getPassword() -> (CustomStringConvertible, Buffer, (Buffer) -> Api.account.Password?) {
                    let buffer = Buffer()
                    buffer.appendInt32(1418342645)
                    
                    return (FunctionDescription({return "(account.getPassword )"}), buffer, { (buffer: Buffer) -> Api.account.Password? in
                        let reader = BufferReader(buffer)
                        var result: Api.account.Password?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.account.Password
                        }
                        return result
                    })
                }
            
                public static func getPasswordSettings(currentPasswordHash: Buffer) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.account.PasswordSettings?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1131605573)
                    serializeBytes(currentPasswordHash, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(account.getPasswordSettings currentPasswordHash: \(currentPasswordHash))"}), buffer, { (buffer: Buffer) -> Api.account.PasswordSettings? in
                        let reader = BufferReader(buffer)
                        var result: Api.account.PasswordSettings?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.account.PasswordSettings
                        }
                        return result
                    })
                }
            
                public static func updatePasswordSettings(currentPasswordHash: Buffer, newSettings: Api.account.PasswordInputSettings) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Bool?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-92517498)
                    serializeBytes(currentPasswordHash, buffer: buffer, boxed: false)
                    newSettings.serialize(buffer, true)
                    return (FunctionDescription({return "(account.updatePasswordSettings currentPasswordHash: \(currentPasswordHash), newSettings: \(newSettings))"}), buffer, { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func sendConfirmPhoneCode(flags: Int32, hash: String, currentNumber: Api.Bool?) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.auth.SentCode?) {
                    let buffer = Buffer()
                    buffer.appendInt32(353818557)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(hash, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {currentNumber!.serialize(buffer, true)}
                    return (FunctionDescription({return "(account.sendConfirmPhoneCode flags: \(flags), hash: \(hash), currentNumber: \(String(describing: currentNumber)))"}), buffer, { (buffer: Buffer) -> Api.auth.SentCode? in
                        let reader = BufferReader(buffer)
                        var result: Api.auth.SentCode?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.auth.SentCode
                        }
                        return result
                    })
                }
            
                public static func confirmPhone(phoneCodeHash: String, phoneCode: String) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Bool?) {
                    let buffer = Buffer()
                    buffer.appendInt32(1596029123)
                    serializeString(phoneCodeHash, buffer: buffer, boxed: false)
                    serializeString(phoneCode, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(account.confirmPhone phoneCodeHash: \(phoneCodeHash), phoneCode: \(phoneCode))"}), buffer, { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func getTmpPassword(passwordHash: Buffer, period: Int32) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.account.TmpPassword?) {
                    let buffer = Buffer()
                    buffer.appendInt32(1250046590)
                    serializeBytes(passwordHash, buffer: buffer, boxed: false)
                    serializeInt32(period, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(account.getTmpPassword passwordHash: \(passwordHash), period: \(period))"}), buffer, { (buffer: Buffer) -> Api.account.TmpPassword? in
                        let reader = BufferReader(buffer)
                        var result: Api.account.TmpPassword?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.account.TmpPassword
                        }
                        return result
                    })
                }
            
                public static func unregisterDevice(tokenType: Int32, token: String, otherUids: [Int32]) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Bool?) {
                    let buffer = Buffer()
                    buffer.appendInt32(813089983)
                    serializeInt32(tokenType, buffer: buffer, boxed: false)
                    serializeString(token, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(otherUids.count))
                    for item in otherUids {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    return (FunctionDescription({return "(account.unregisterDevice tokenType: \(tokenType), token: \(token), otherUids: \(otherUids))"}), buffer, { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func getWebAuthorizations() -> (CustomStringConvertible, Buffer, (Buffer) -> Api.account.WebAuthorizations?) {
                    let buffer = Buffer()
                    buffer.appendInt32(405695855)
                    
                    return (FunctionDescription({return "(account.getWebAuthorizations )"}), buffer, { (buffer: Buffer) -> Api.account.WebAuthorizations? in
                        let reader = BufferReader(buffer)
                        var result: Api.account.WebAuthorizations?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.account.WebAuthorizations
                        }
                        return result
                    })
                }
            
                public static func resetWebAuthorization(hash: Int64) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Bool?) {
                    let buffer = Buffer()
                    buffer.appendInt32(755087855)
                    serializeInt64(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(account.resetWebAuthorization hash: \(hash))"}), buffer, { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func resetWebAuthorizations() -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Bool?) {
                    let buffer = Buffer()
                    buffer.appendInt32(1747789204)
                    
                    return (FunctionDescription({return "(account.resetWebAuthorizations )"}), buffer, { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func registerDevice(tokenType: Int32, token: String, appSandbox: Api.Bool, secret: Buffer, otherUids: [Int32]) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Bool?) {
                    let buffer = Buffer()
                    buffer.appendInt32(1555998096)
                    serializeInt32(tokenType, buffer: buffer, boxed: false)
                    serializeString(token, buffer: buffer, boxed: false)
                    appSandbox.serialize(buffer, true)
                    serializeBytes(secret, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(otherUids.count))
                    for item in otherUids {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    return (FunctionDescription({return "(account.registerDevice tokenType: \(tokenType), token: \(token), appSandbox: \(appSandbox), secret: \(secret), otherUids: \(otherUids))"}), buffer, { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func getAllSecureValues() -> (CustomStringConvertible, Buffer, (Buffer) -> [Api.SecureValue]?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1299661699)
                    
                    return (FunctionDescription({return "(account.getAllSecureValues )"}), buffer, { (buffer: Buffer) -> [Api.SecureValue]? in
                        let reader = BufferReader(buffer)
                        var result: [Api.SecureValue]?
                        if let _ = reader.readInt32() {
                            result = Api.parseVector(reader, elementSignature: 0, elementType: Api.SecureValue.self)
                        }
                        return result
                    })
                }
            
                public static func getSecureValue(types: [Api.SecureValueType]) -> (CustomStringConvertible, Buffer, (Buffer) -> [Api.SecureValue]?) {
                    let buffer = Buffer()
                    buffer.appendInt32(1936088002)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(types.count))
                    for item in types {
                        item.serialize(buffer, true)
                    }
                    return (FunctionDescription({return "(account.getSecureValue types: \(types))"}), buffer, { (buffer: Buffer) -> [Api.SecureValue]? in
                        let reader = BufferReader(buffer)
                        var result: [Api.SecureValue]?
                        if let _ = reader.readInt32() {
                            result = Api.parseVector(reader, elementSignature: 0, elementType: Api.SecureValue.self)
                        }
                        return result
                    })
                }
            
                public static func saveSecureValue(value: Api.InputSecureValue, secureSecretId: Int64) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.SecureValue?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1986010339)
                    value.serialize(buffer, true)
                    serializeInt64(secureSecretId, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(account.saveSecureValue value: \(value), secureSecretId: \(secureSecretId))"}), buffer, { (buffer: Buffer) -> Api.SecureValue? in
                        let reader = BufferReader(buffer)
                        var result: Api.SecureValue?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.SecureValue
                        }
                        return result
                    })
                }
            
                public static func deleteSecureValue(types: [Api.SecureValueType]) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Bool?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1199522741)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(types.count))
                    for item in types {
                        item.serialize(buffer, true)
                    }
                    return (FunctionDescription({return "(account.deleteSecureValue types: \(types))"}), buffer, { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func getAuthorizationForm(botId: Int32, scope: String, publicKey: String) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.account.AuthorizationForm?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1200903967)
                    serializeInt32(botId, buffer: buffer, boxed: false)
                    serializeString(scope, buffer: buffer, boxed: false)
                    serializeString(publicKey, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(account.getAuthorizationForm botId: \(botId), scope: \(scope), publicKey: \(publicKey))"}), buffer, { (buffer: Buffer) -> Api.account.AuthorizationForm? in
                        let reader = BufferReader(buffer)
                        var result: Api.account.AuthorizationForm?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.account.AuthorizationForm
                        }
                        return result
                    })
                }
            
                public static func acceptAuthorization(botId: Int32, scope: String, publicKey: String, valueHashes: [Api.SecureValueHash], credentials: Api.SecureCredentialsEncrypted) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Bool?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-419267436)
                    serializeInt32(botId, buffer: buffer, boxed: false)
                    serializeString(scope, buffer: buffer, boxed: false)
                    serializeString(publicKey, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(valueHashes.count))
                    for item in valueHashes {
                        item.serialize(buffer, true)
                    }
                    credentials.serialize(buffer, true)
                    return (FunctionDescription({return "(account.acceptAuthorization botId: \(botId), scope: \(scope), publicKey: \(publicKey), valueHashes: \(valueHashes), credentials: \(credentials))"}), buffer, { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func sendVerifyPhoneCode(flags: Int32, phoneNumber: String, currentNumber: Api.Bool?) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.auth.SentCode?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-2110553932)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(phoneNumber, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {currentNumber!.serialize(buffer, true)}
                    return (FunctionDescription({return "(account.sendVerifyPhoneCode flags: \(flags), phoneNumber: \(phoneNumber), currentNumber: \(String(describing: currentNumber)))"}), buffer, { (buffer: Buffer) -> Api.auth.SentCode? in
                        let reader = BufferReader(buffer)
                        var result: Api.auth.SentCode?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.auth.SentCode
                        }
                        return result
                    })
                }
            
                public static func verifyPhone(phoneNumber: String, phoneCodeHash: String, phoneCode: String) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Bool?) {
                    let buffer = Buffer()
                    buffer.appendInt32(1305716726)
                    serializeString(phoneNumber, buffer: buffer, boxed: false)
                    serializeString(phoneCodeHash, buffer: buffer, boxed: false)
                    serializeString(phoneCode, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(account.verifyPhone phoneNumber: \(phoneNumber), phoneCodeHash: \(phoneCodeHash), phoneCode: \(phoneCode))"}), buffer, { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func sendVerifyEmailCode(email: String) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.account.SentEmailCode?) {
                    let buffer = Buffer()
                    buffer.appendInt32(1880182943)
                    serializeString(email, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(account.sendVerifyEmailCode email: \(email))"}), buffer, { (buffer: Buffer) -> Api.account.SentEmailCode? in
                        let reader = BufferReader(buffer)
                        var result: Api.account.SentEmailCode?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.account.SentEmailCode
                        }
                        return result
                    })
                }
            
                public static func verifyEmail(email: String, code: String) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Bool?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-323339813)
                    serializeString(email, buffer: buffer, boxed: false)
                    serializeString(code, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(account.verifyEmail email: \(email), code: \(code))"}), buffer, { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            }
            public struct langpack {
                public static func getLangPack(langCode: String) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.LangPackDifference?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1699363442)
                    serializeString(langCode, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(langpack.getLangPack langCode: \(langCode))"}), buffer, { (buffer: Buffer) -> Api.LangPackDifference? in
                        let reader = BufferReader(buffer)
                        var result: Api.LangPackDifference?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.LangPackDifference
                        }
                        return result
                    })
                }
            
                public static func getStrings(langCode: String, keys: [String]) -> (CustomStringConvertible, Buffer, (Buffer) -> [Api.LangPackString]?) {
                    let buffer = Buffer()
                    buffer.appendInt32(773776152)
                    serializeString(langCode, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(keys.count))
                    for item in keys {
                        serializeString(item, buffer: buffer, boxed: false)
                    }
                    return (FunctionDescription({return "(langpack.getStrings langCode: \(langCode), keys: \(keys))"}), buffer, { (buffer: Buffer) -> [Api.LangPackString]? in
                        let reader = BufferReader(buffer)
                        var result: [Api.LangPackString]?
                        if let _ = reader.readInt32() {
                            result = Api.parseVector(reader, elementSignature: 0, elementType: Api.LangPackString.self)
                        }
                        return result
                    })
                }
            
                public static func getDifference(fromVersion: Int32) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.LangPackDifference?) {
                    let buffer = Buffer()
                    buffer.appendInt32(187583869)
                    serializeInt32(fromVersion, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(langpack.getDifference fromVersion: \(fromVersion))"}), buffer, { (buffer: Buffer) -> Api.LangPackDifference? in
                        let reader = BufferReader(buffer)
                        var result: Api.LangPackDifference?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.LangPackDifference
                        }
                        return result
                    })
                }
            
                public static func getLanguages() -> (CustomStringConvertible, Buffer, (Buffer) -> [Api.LangPackLanguage]?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-2146445955)
                    
                    return (FunctionDescription({return "(langpack.getLanguages )"}), buffer, { (buffer: Buffer) -> [Api.LangPackLanguage]? in
                        let reader = BufferReader(buffer)
                        var result: [Api.LangPackLanguage]?
                        if let _ = reader.readInt32() {
                            result = Api.parseVector(reader, elementSignature: 0, elementType: Api.LangPackLanguage.self)
                        }
                        return result
                    })
                }
            }
            public struct photos {
                public static func updateProfilePhoto(id: Api.InputPhoto) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.UserProfilePhoto?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-256159406)
                    id.serialize(buffer, true)
                    return (FunctionDescription({return "(photos.updateProfilePhoto id: \(id))"}), buffer, { (buffer: Buffer) -> Api.UserProfilePhoto? in
                        let reader = BufferReader(buffer)
                        var result: Api.UserProfilePhoto?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.UserProfilePhoto
                        }
                        return result
                    })
                }
            
                public static func uploadProfilePhoto(file: Api.InputFile) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.photos.Photo?) {
                    let buffer = Buffer()
                    buffer.appendInt32(1328726168)
                    file.serialize(buffer, true)
                    return (FunctionDescription({return "(photos.uploadProfilePhoto file: \(file))"}), buffer, { (buffer: Buffer) -> Api.photos.Photo? in
                        let reader = BufferReader(buffer)
                        var result: Api.photos.Photo?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.photos.Photo
                        }
                        return result
                    })
                }
            
                public static func deletePhotos(id: [Api.InputPhoto]) -> (CustomStringConvertible, Buffer, (Buffer) -> [Int64]?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-2016444625)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(id.count))
                    for item in id {
                        item.serialize(buffer, true)
                    }
                    return (FunctionDescription({return "(photos.deletePhotos id: \(id))"}), buffer, { (buffer: Buffer) -> [Int64]? in
                        let reader = BufferReader(buffer)
                        var result: [Int64]?
                        if let _ = reader.readInt32() {
                            result = Api.parseVector(reader, elementSignature: 570911930, elementType: Int64.self)
                        }
                        return result
                    })
                }
            
                public static func getUserPhotos(userId: Api.InputUser, offset: Int32, maxId: Int64, limit: Int32) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.photos.Photos?) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1848823128)
                    userId.serialize(buffer, true)
                    serializeInt32(offset, buffer: buffer, boxed: false)
                    serializeInt64(maxId, buffer: buffer, boxed: false)
                    serializeInt32(limit, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(photos.getUserPhotos userId: \(userId), offset: \(offset), maxId: \(maxId), limit: \(limit))"}), buffer, { (buffer: Buffer) -> Api.photos.Photos? in
                        let reader = BufferReader(buffer)
                        var result: Api.photos.Photos?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.photos.Photos
                        }
                        return result
                    })
                }
            }
            public struct phone {
                public static func getCallConfig() -> (CustomStringConvertible, Buffer, (Buffer) -> Api.DataJSON?) {
                    let buffer = Buffer()
                    buffer.appendInt32(1430593449)
                    
                    return (FunctionDescription({return "(phone.getCallConfig )"}), buffer, { (buffer: Buffer) -> Api.DataJSON? in
                        let reader = BufferReader(buffer)
                        var result: Api.DataJSON?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.DataJSON
                        }
                        return result
                    })
                }
            
                public static func requestCall(userId: Api.InputUser, randomId: Int32, gAHash: Buffer, `protocol`: Api.PhoneCallProtocol) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.phone.PhoneCall?) {
                    let buffer = Buffer()
                    buffer.appendInt32(1536537556)
                    userId.serialize(buffer, true)
                    serializeInt32(randomId, buffer: buffer, boxed: false)
                    serializeBytes(gAHash, buffer: buffer, boxed: false)
                    `protocol`.serialize(buffer, true)
                    return (FunctionDescription({return "(phone.requestCall userId: \(userId), randomId: \(randomId), gAHash: \(gAHash), `protocol`: \(`protocol`))"}), buffer, { (buffer: Buffer) -> Api.phone.PhoneCall? in
                        let reader = BufferReader(buffer)
                        var result: Api.phone.PhoneCall?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.phone.PhoneCall
                        }
                        return result
                    })
                }
            
                public static func acceptCall(peer: Api.InputPhoneCall, gB: Buffer, `protocol`: Api.PhoneCallProtocol) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.phone.PhoneCall?) {
                    let buffer = Buffer()
                    buffer.appendInt32(1003664544)
                    peer.serialize(buffer, true)
                    serializeBytes(gB, buffer: buffer, boxed: false)
                    `protocol`.serialize(buffer, true)
                    return (FunctionDescription({return "(phone.acceptCall peer: \(peer), gB: \(gB), `protocol`: \(`protocol`))"}), buffer, { (buffer: Buffer) -> Api.phone.PhoneCall? in
                        let reader = BufferReader(buffer)
                        var result: Api.phone.PhoneCall?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.phone.PhoneCall
                        }
                        return result
                    })
                }
            
                public static func confirmCall(peer: Api.InputPhoneCall, gA: Buffer, keyFingerprint: Int64, `protocol`: Api.PhoneCallProtocol) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.phone.PhoneCall?) {
                    let buffer = Buffer()
                    buffer.appendInt32(788404002)
                    peer.serialize(buffer, true)
                    serializeBytes(gA, buffer: buffer, boxed: false)
                    serializeInt64(keyFingerprint, buffer: buffer, boxed: false)
                    `protocol`.serialize(buffer, true)
                    return (FunctionDescription({return "(phone.confirmCall peer: \(peer), gA: \(gA), keyFingerprint: \(keyFingerprint), `protocol`: \(`protocol`))"}), buffer, { (buffer: Buffer) -> Api.phone.PhoneCall? in
                        let reader = BufferReader(buffer)
                        var result: Api.phone.PhoneCall?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.phone.PhoneCall
                        }
                        return result
                    })
                }
            
                public static func receivedCall(peer: Api.InputPhoneCall) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Bool?) {
                    let buffer = Buffer()
                    buffer.appendInt32(399855457)
                    peer.serialize(buffer, true)
                    return (FunctionDescription({return "(phone.receivedCall peer: \(peer))"}), buffer, { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func discardCall(peer: Api.InputPhoneCall, duration: Int32, reason: Api.PhoneCallDiscardReason, connectionId: Int64) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Updates?) {
                    let buffer = Buffer()
                    buffer.appendInt32(2027164582)
                    peer.serialize(buffer, true)
                    serializeInt32(duration, buffer: buffer, boxed: false)
                    reason.serialize(buffer, true)
                    serializeInt64(connectionId, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(phone.discardCall peer: \(peer), duration: \(duration), reason: \(reason), connectionId: \(connectionId))"}), buffer, { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
            
                public static func setCallRating(peer: Api.InputPhoneCall, rating: Int32, comment: String) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Updates?) {
                    let buffer = Buffer()
                    buffer.appendInt32(475228724)
                    peer.serialize(buffer, true)
                    serializeInt32(rating, buffer: buffer, boxed: false)
                    serializeString(comment, buffer: buffer, boxed: false)
                    return (FunctionDescription({return "(phone.setCallRating peer: \(peer), rating: \(rating), comment: \(comment))"}), buffer, { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
            
                public static func saveCallDebug(peer: Api.InputPhoneCall, debug: Api.DataJSON) -> (CustomStringConvertible, Buffer, (Buffer) -> Api.Bool?) {
                    let buffer = Buffer()
                    buffer.appendInt32(662363518)
                    peer.serialize(buffer, true)
                    debug.serialize(buffer, true)
                    return (FunctionDescription({return "(phone.saveCallDebug peer: \(peer), debug: \(debug))"}), buffer, { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            }
    }
}
