public extension Api.upload {
    enum File: TypeConstructorDescription {
        case file(type: Api.storage.FileType, mtime: Int32, bytes: Buffer)
        case fileCdnRedirect(dcId: Int32, fileToken: Buffer, encryptionKey: Buffer, encryptionIv: Buffer, fileHashes: [Api.FileHash])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .file(let type, let mtime, let bytes):
                    if boxed {
                        buffer.appendInt32(157948117)
                    }
                    type.serialize(buffer, true)
                    serializeInt32(mtime, buffer: buffer, boxed: false)
                    serializeBytes(bytes, buffer: buffer, boxed: false)
                    break
                case .fileCdnRedirect(let dcId, let fileToken, let encryptionKey, let encryptionIv, let fileHashes):
                    if boxed {
                        buffer.appendInt32(-242427324)
                    }
                    serializeInt32(dcId, buffer: buffer, boxed: false)
                    serializeBytes(fileToken, buffer: buffer, boxed: false)
                    serializeBytes(encryptionKey, buffer: buffer, boxed: false)
                    serializeBytes(encryptionIv, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(fileHashes.count))
                    for item in fileHashes {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .file(let type, let mtime, let bytes):
                return ("file", [("type", type as Any), ("mtime", mtime as Any), ("bytes", bytes as Any)])
                case .fileCdnRedirect(let dcId, let fileToken, let encryptionKey, let encryptionIv, let fileHashes):
                return ("fileCdnRedirect", [("dcId", dcId as Any), ("fileToken", fileToken as Any), ("encryptionKey", encryptionKey as Any), ("encryptionIv", encryptionIv as Any), ("fileHashes", fileHashes as Any)])
    }
    }
    
        public static func parse_file(_ reader: BufferReader) -> File? {
            var _1: Api.storage.FileType?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.storage.FileType
            }
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Buffer?
            _3 = parseBytes(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.upload.File.file(type: _1!, mtime: _2!, bytes: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_fileCdnRedirect(_ reader: BufferReader) -> File? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Buffer?
            _2 = parseBytes(reader)
            var _3: Buffer?
            _3 = parseBytes(reader)
            var _4: Buffer?
            _4 = parseBytes(reader)
            var _5: [Api.FileHash]?
            if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.FileHash.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.upload.File.fileCdnRedirect(dcId: _1!, fileToken: _2!, encryptionKey: _3!, encryptionIv: _4!, fileHashes: _5!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.upload {
    enum WebFile: TypeConstructorDescription {
        case webFile(size: Int32, mimeType: String, fileType: Api.storage.FileType, mtime: Int32, bytes: Buffer)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .webFile(let size, let mimeType, let fileType, let mtime, let bytes):
                    if boxed {
                        buffer.appendInt32(568808380)
                    }
                    serializeInt32(size, buffer: buffer, boxed: false)
                    serializeString(mimeType, buffer: buffer, boxed: false)
                    fileType.serialize(buffer, true)
                    serializeInt32(mtime, buffer: buffer, boxed: false)
                    serializeBytes(bytes, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .webFile(let size, let mimeType, let fileType, let mtime, let bytes):
                return ("webFile", [("size", size as Any), ("mimeType", mimeType as Any), ("fileType", fileType as Any), ("mtime", mtime as Any), ("bytes", bytes as Any)])
    }
    }
    
        public static func parse_webFile(_ reader: BufferReader) -> WebFile? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: Api.storage.FileType?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.storage.FileType
            }
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Buffer?
            _5 = parseBytes(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.upload.WebFile.webFile(size: _1!, mimeType: _2!, fileType: _3!, mtime: _4!, bytes: _5!)
            }
            else {
                return nil
            }
        }
    
    }
}
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
public extension Api.users {
    enum Users: TypeConstructorDescription {
        case users(users: [Api.User])
        case usersSlice(count: Int32, users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .users(let users):
                    if boxed {
                        buffer.appendInt32(1658259128)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    break
                case .usersSlice(let count, let users):
                    if boxed {
                        buffer.appendInt32(828000628)
                    }
                    serializeInt32(count, buffer: buffer, boxed: false)
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
                case .users(let users):
                return ("users", [("users", users as Any)])
                case .usersSlice(let count, let users):
                return ("usersSlice", [("count", count as Any), ("users", users as Any)])
    }
    }
    
        public static func parse_users(_ reader: BufferReader) -> Users? {
            var _1: [Api.User]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.users.Users.users(users: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_usersSlice(_ reader: BufferReader) -> Users? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Api.User]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.users.Users.usersSlice(count: _1!, users: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
