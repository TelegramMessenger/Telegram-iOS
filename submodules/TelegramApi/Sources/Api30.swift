public extension Api.users {
    enum UserFull: TypeConstructorDescription {
        case userFull(fullUser: Api.UserFull, chats: [Api.Chat], users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .userFull(let fullUser, let chats, let users):
                    if boxed {
                        buffer.appendInt32(997004590)
                    }
                    fullUser.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(chats.count))
                    for item in chats {
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
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .userFull(let fullUser, let chats, let users):
                return ("userFull", [("fullUser", fullUser as Any), ("chats", chats as Any), ("users", users as Any)])
    }
    }
    
        public static func parse_userFull(_ reader: BufferReader) -> UserFull? {
            var _1: Api.UserFull?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.UserFull
            }
            var _2: [Api.Chat]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            var _3: [Api.User]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.users.UserFull.userFull(fullUser: _1!, chats: _2!, users: _3!)
            }
            else {
                return nil
            }
        }
    
    }
}
