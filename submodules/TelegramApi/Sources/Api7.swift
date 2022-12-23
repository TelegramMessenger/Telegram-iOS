public extension Api {
    indirect enum InputChannel: TypeConstructorDescription {
        case inputChannel(channelId: Int64, accessHash: Int64)
        case inputChannelEmpty
        case inputChannelFromMessage(peer: Api.InputPeer, msgId: Int32, channelId: Int64)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputChannel(let channelId, let accessHash):
                    if boxed {
                        buffer.appendInt32(-212145112)
                    }
                    serializeInt64(channelId, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    break
                case .inputChannelEmpty:
                    if boxed {
                        buffer.appendInt32(-292807034)
                    }
                    
                    break
                case .inputChannelFromMessage(let peer, let msgId, let channelId):
                    if boxed {
                        buffer.appendInt32(1536380829)
                    }
                    peer.serialize(buffer, true)
                    serializeInt32(msgId, buffer: buffer, boxed: false)
                    serializeInt64(channelId, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputChannel(let channelId, let accessHash):
                return ("inputChannel", [("channelId", String(describing: channelId)), ("accessHash", String(describing: accessHash))])
                case .inputChannelEmpty:
                return ("inputChannelEmpty", [])
                case .inputChannelFromMessage(let peer, let msgId, let channelId):
                return ("inputChannelFromMessage", [("peer", String(describing: peer)), ("msgId", String(describing: msgId)), ("channelId", String(describing: channelId))])
    }
    }
    
        public static func parse_inputChannel(_ reader: BufferReader) -> InputChannel? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputChannel.inputChannel(channelId: _1!, accessHash: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputChannelEmpty(_ reader: BufferReader) -> InputChannel? {
            return Api.InputChannel.inputChannelEmpty
        }
        public static func parse_inputChannelFromMessage(_ reader: BufferReader) -> InputChannel? {
            var _1: Api.InputPeer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputPeer
            }
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int64?
            _3 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.InputChannel.inputChannelFromMessage(peer: _1!, msgId: _2!, channelId: _3!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum InputChatPhoto: TypeConstructorDescription {
        case inputChatPhoto(id: Api.InputPhoto)
        case inputChatPhotoEmpty
        case inputChatUploadedPhoto(flags: Int32, file: Api.InputFile?, video: Api.InputFile?, videoStartTs: Double?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputChatPhoto(let id):
                    if boxed {
                        buffer.appendInt32(-1991004873)
                    }
                    id.serialize(buffer, true)
                    break
                case .inputChatPhotoEmpty:
                    if boxed {
                        buffer.appendInt32(480546647)
                    }
                    
                    break
                case .inputChatUploadedPhoto(let flags, let file, let video, let videoStartTs):
                    if boxed {
                        buffer.appendInt32(-968723890)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {file!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 1) != 0 {video!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeDouble(videoStartTs!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputChatPhoto(let id):
                return ("inputChatPhoto", [("id", String(describing: id))])
                case .inputChatPhotoEmpty:
                return ("inputChatPhotoEmpty", [])
                case .inputChatUploadedPhoto(let flags, let file, let video, let videoStartTs):
                return ("inputChatUploadedPhoto", [("flags", String(describing: flags)), ("file", String(describing: file)), ("video", String(describing: video)), ("videoStartTs", String(describing: videoStartTs))])
    }
    }
    
        public static func parse_inputChatPhoto(_ reader: BufferReader) -> InputChatPhoto? {
            var _1: Api.InputPhoto?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputPhoto
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputChatPhoto.inputChatPhoto(id: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputChatPhotoEmpty(_ reader: BufferReader) -> InputChatPhoto? {
            return Api.InputChatPhoto.inputChatPhotoEmpty
        }
        public static func parse_inputChatUploadedPhoto(_ reader: BufferReader) -> InputChatPhoto? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.InputFile?
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.InputFile
            } }
            var _3: Api.InputFile?
            if Int(_1!) & Int(1 << 1) != 0 {if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.InputFile
            } }
            var _4: Double?
            if Int(_1!) & Int(1 << 2) != 0 {_4 = reader.readDouble() }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 2) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.InputChatPhoto.inputChatUploadedPhoto(flags: _1!, file: _2, video: _3, videoStartTs: _4)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum InputCheckPasswordSRP: TypeConstructorDescription {
        case inputCheckPasswordEmpty
        case inputCheckPasswordSRP(srpId: Int64, A: Buffer, M1: Buffer)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputCheckPasswordEmpty:
                    if boxed {
                        buffer.appendInt32(-1736378792)
                    }
                    
                    break
                case .inputCheckPasswordSRP(let srpId, let A, let M1):
                    if boxed {
                        buffer.appendInt32(-763367294)
                    }
                    serializeInt64(srpId, buffer: buffer, boxed: false)
                    serializeBytes(A, buffer: buffer, boxed: false)
                    serializeBytes(M1, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputCheckPasswordEmpty:
                return ("inputCheckPasswordEmpty", [])
                case .inputCheckPasswordSRP(let srpId, let A, let M1):
                return ("inputCheckPasswordSRP", [("srpId", String(describing: srpId)), ("A", String(describing: A)), ("M1", String(describing: M1))])
    }
    }
    
        public static func parse_inputCheckPasswordEmpty(_ reader: BufferReader) -> InputCheckPasswordSRP? {
            return Api.InputCheckPasswordSRP.inputCheckPasswordEmpty
        }
        public static func parse_inputCheckPasswordSRP(_ reader: BufferReader) -> InputCheckPasswordSRP? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Buffer?
            _2 = parseBytes(reader)
            var _3: Buffer?
            _3 = parseBytes(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.InputCheckPasswordSRP.inputCheckPasswordSRP(srpId: _1!, A: _2!, M1: _3!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum InputClientProxy: TypeConstructorDescription {
        case inputClientProxy(address: String, port: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputClientProxy(let address, let port):
                    if boxed {
                        buffer.appendInt32(1968737087)
                    }
                    serializeString(address, buffer: buffer, boxed: false)
                    serializeInt32(port, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputClientProxy(let address, let port):
                return ("inputClientProxy", [("address", String(describing: address)), ("port", String(describing: port))])
    }
    }
    
        public static func parse_inputClientProxy(_ reader: BufferReader) -> InputClientProxy? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputClientProxy.inputClientProxy(address: _1!, port: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum InputContact: TypeConstructorDescription {
        case inputPhoneContact(clientId: Int64, phone: String, firstName: String, lastName: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputPhoneContact(let clientId, let phone, let firstName, let lastName):
                    if boxed {
                        buffer.appendInt32(-208488460)
                    }
                    serializeInt64(clientId, buffer: buffer, boxed: false)
                    serializeString(phone, buffer: buffer, boxed: false)
                    serializeString(firstName, buffer: buffer, boxed: false)
                    serializeString(lastName, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputPhoneContact(let clientId, let phone, let firstName, let lastName):
                return ("inputPhoneContact", [("clientId", String(describing: clientId)), ("phone", String(describing: phone)), ("firstName", String(describing: firstName)), ("lastName", String(describing: lastName))])
    }
    }
    
        public static func parse_inputPhoneContact(_ reader: BufferReader) -> InputContact? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: String?
            _2 = parseString(reader)
            var _3: String?
            _3 = parseString(reader)
            var _4: String?
            _4 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.InputContact.inputPhoneContact(clientId: _1!, phone: _2!, firstName: _3!, lastName: _4!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    indirect enum InputDialogPeer: TypeConstructorDescription {
        case inputDialogPeer(peer: Api.InputPeer)
        case inputDialogPeerFolder(folderId: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputDialogPeer(let peer):
                    if boxed {
                        buffer.appendInt32(-55902537)
                    }
                    peer.serialize(buffer, true)
                    break
                case .inputDialogPeerFolder(let folderId):
                    if boxed {
                        buffer.appendInt32(1684014375)
                    }
                    serializeInt32(folderId, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputDialogPeer(let peer):
                return ("inputDialogPeer", [("peer", String(describing: peer))])
                case .inputDialogPeerFolder(let folderId):
                return ("inputDialogPeerFolder", [("folderId", String(describing: folderId))])
    }
    }
    
        public static func parse_inputDialogPeer(_ reader: BufferReader) -> InputDialogPeer? {
            var _1: Api.InputPeer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputPeer
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputDialogPeer.inputDialogPeer(peer: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputDialogPeerFolder(_ reader: BufferReader) -> InputDialogPeer? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputDialogPeer.inputDialogPeerFolder(folderId: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum InputDocument: TypeConstructorDescription {
        case inputDocument(id: Int64, accessHash: Int64, fileReference: Buffer)
        case inputDocumentEmpty
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputDocument(let id, let accessHash, let fileReference):
                    if boxed {
                        buffer.appendInt32(448771445)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    serializeBytes(fileReference, buffer: buffer, boxed: false)
                    break
                case .inputDocumentEmpty:
                    if boxed {
                        buffer.appendInt32(1928391342)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputDocument(let id, let accessHash, let fileReference):
                return ("inputDocument", [("id", String(describing: id)), ("accessHash", String(describing: accessHash)), ("fileReference", String(describing: fileReference))])
                case .inputDocumentEmpty:
                return ("inputDocumentEmpty", [])
    }
    }
    
        public static func parse_inputDocument(_ reader: BufferReader) -> InputDocument? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Buffer?
            _3 = parseBytes(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.InputDocument.inputDocument(id: _1!, accessHash: _2!, fileReference: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputDocumentEmpty(_ reader: BufferReader) -> InputDocument? {
            return Api.InputDocument.inputDocumentEmpty
        }
    
    }
}
public extension Api {
    enum InputEncryptedChat: TypeConstructorDescription {
        case inputEncryptedChat(chatId: Int32, accessHash: Int64)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputEncryptedChat(let chatId, let accessHash):
                    if boxed {
                        buffer.appendInt32(-247351839)
                    }
                    serializeInt32(chatId, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputEncryptedChat(let chatId, let accessHash):
                return ("inputEncryptedChat", [("chatId", String(describing: chatId)), ("accessHash", String(describing: accessHash))])
    }
    }
    
        public static func parse_inputEncryptedChat(_ reader: BufferReader) -> InputEncryptedChat? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputEncryptedChat.inputEncryptedChat(chatId: _1!, accessHash: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum InputEncryptedFile: TypeConstructorDescription {
        case inputEncryptedFile(id: Int64, accessHash: Int64)
        case inputEncryptedFileBigUploaded(id: Int64, parts: Int32, keyFingerprint: Int32)
        case inputEncryptedFileEmpty
        case inputEncryptedFileUploaded(id: Int64, parts: Int32, md5Checksum: String, keyFingerprint: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputEncryptedFile(let id, let accessHash):
                    if boxed {
                        buffer.appendInt32(1511503333)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    break
                case .inputEncryptedFileBigUploaded(let id, let parts, let keyFingerprint):
                    if boxed {
                        buffer.appendInt32(767652808)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt32(parts, buffer: buffer, boxed: false)
                    serializeInt32(keyFingerprint, buffer: buffer, boxed: false)
                    break
                case .inputEncryptedFileEmpty:
                    if boxed {
                        buffer.appendInt32(406307684)
                    }
                    
                    break
                case .inputEncryptedFileUploaded(let id, let parts, let md5Checksum, let keyFingerprint):
                    if boxed {
                        buffer.appendInt32(1690108678)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt32(parts, buffer: buffer, boxed: false)
                    serializeString(md5Checksum, buffer: buffer, boxed: false)
                    serializeInt32(keyFingerprint, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputEncryptedFile(let id, let accessHash):
                return ("inputEncryptedFile", [("id", String(describing: id)), ("accessHash", String(describing: accessHash))])
                case .inputEncryptedFileBigUploaded(let id, let parts, let keyFingerprint):
                return ("inputEncryptedFileBigUploaded", [("id", String(describing: id)), ("parts", String(describing: parts)), ("keyFingerprint", String(describing: keyFingerprint))])
                case .inputEncryptedFileEmpty:
                return ("inputEncryptedFileEmpty", [])
                case .inputEncryptedFileUploaded(let id, let parts, let md5Checksum, let keyFingerprint):
                return ("inputEncryptedFileUploaded", [("id", String(describing: id)), ("parts", String(describing: parts)), ("md5Checksum", String(describing: md5Checksum)), ("keyFingerprint", String(describing: keyFingerprint))])
    }
    }
    
        public static func parse_inputEncryptedFile(_ reader: BufferReader) -> InputEncryptedFile? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputEncryptedFile.inputEncryptedFile(id: _1!, accessHash: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputEncryptedFileBigUploaded(_ reader: BufferReader) -> InputEncryptedFile? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.InputEncryptedFile.inputEncryptedFileBigUploaded(id: _1!, parts: _2!, keyFingerprint: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputEncryptedFileEmpty(_ reader: BufferReader) -> InputEncryptedFile? {
            return Api.InputEncryptedFile.inputEncryptedFileEmpty
        }
        public static func parse_inputEncryptedFileUploaded(_ reader: BufferReader) -> InputEncryptedFile? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: String?
            _3 = parseString(reader)
            var _4: Int32?
            _4 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.InputEncryptedFile.inputEncryptedFileUploaded(id: _1!, parts: _2!, md5Checksum: _3!, keyFingerprint: _4!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum InputFile: TypeConstructorDescription {
        case inputFile(id: Int64, parts: Int32, name: String, md5Checksum: String)
        case inputFileBig(id: Int64, parts: Int32, name: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputFile(let id, let parts, let name, let md5Checksum):
                    if boxed {
                        buffer.appendInt32(-181407105)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt32(parts, buffer: buffer, boxed: false)
                    serializeString(name, buffer: buffer, boxed: false)
                    serializeString(md5Checksum, buffer: buffer, boxed: false)
                    break
                case .inputFileBig(let id, let parts, let name):
                    if boxed {
                        buffer.appendInt32(-95482955)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt32(parts, buffer: buffer, boxed: false)
                    serializeString(name, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputFile(let id, let parts, let name, let md5Checksum):
                return ("inputFile", [("id", String(describing: id)), ("parts", String(describing: parts)), ("name", String(describing: name)), ("md5Checksum", String(describing: md5Checksum))])
                case .inputFileBig(let id, let parts, let name):
                return ("inputFileBig", [("id", String(describing: id)), ("parts", String(describing: parts)), ("name", String(describing: name))])
    }
    }
    
        public static func parse_inputFile(_ reader: BufferReader) -> InputFile? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: String?
            _3 = parseString(reader)
            var _4: String?
            _4 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.InputFile.inputFile(id: _1!, parts: _2!, name: _3!, md5Checksum: _4!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputFileBig(_ reader: BufferReader) -> InputFile? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: String?
            _3 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.InputFile.inputFileBig(id: _1!, parts: _2!, name: _3!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    indirect enum InputFileLocation: TypeConstructorDescription {
        case inputDocumentFileLocation(id: Int64, accessHash: Int64, fileReference: Buffer, thumbSize: String)
        case inputEncryptedFileLocation(id: Int64, accessHash: Int64)
        case inputFileLocation(volumeId: Int64, localId: Int32, secret: Int64, fileReference: Buffer)
        case inputGroupCallStream(flags: Int32, call: Api.InputGroupCall, timeMs: Int64, scale: Int32, videoChannel: Int32?, videoQuality: Int32?)
        case inputPeerPhotoFileLocation(flags: Int32, peer: Api.InputPeer, photoId: Int64)
        case inputPhotoFileLocation(id: Int64, accessHash: Int64, fileReference: Buffer, thumbSize: String)
        case inputPhotoLegacyFileLocation(id: Int64, accessHash: Int64, fileReference: Buffer, volumeId: Int64, localId: Int32, secret: Int64)
        case inputSecureFileLocation(id: Int64, accessHash: Int64)
        case inputStickerSetThumb(stickerset: Api.InputStickerSet, thumbVersion: Int32)
        case inputTakeoutFileLocation
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputDocumentFileLocation(let id, let accessHash, let fileReference, let thumbSize):
                    if boxed {
                        buffer.appendInt32(-1160743548)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    serializeBytes(fileReference, buffer: buffer, boxed: false)
                    serializeString(thumbSize, buffer: buffer, boxed: false)
                    break
                case .inputEncryptedFileLocation(let id, let accessHash):
                    if boxed {
                        buffer.appendInt32(-182231723)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    break
                case .inputFileLocation(let volumeId, let localId, let secret, let fileReference):
                    if boxed {
                        buffer.appendInt32(-539317279)
                    }
                    serializeInt64(volumeId, buffer: buffer, boxed: false)
                    serializeInt32(localId, buffer: buffer, boxed: false)
                    serializeInt64(secret, buffer: buffer, boxed: false)
                    serializeBytes(fileReference, buffer: buffer, boxed: false)
                    break
                case .inputGroupCallStream(let flags, let call, let timeMs, let scale, let videoChannel, let videoQuality):
                    if boxed {
                        buffer.appendInt32(93890858)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    call.serialize(buffer, true)
                    serializeInt64(timeMs, buffer: buffer, boxed: false)
                    serializeInt32(scale, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(videoChannel!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(videoQuality!, buffer: buffer, boxed: false)}
                    break
                case .inputPeerPhotoFileLocation(let flags, let peer, let photoId):
                    if boxed {
                        buffer.appendInt32(925204121)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    serializeInt64(photoId, buffer: buffer, boxed: false)
                    break
                case .inputPhotoFileLocation(let id, let accessHash, let fileReference, let thumbSize):
                    if boxed {
                        buffer.appendInt32(1075322878)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    serializeBytes(fileReference, buffer: buffer, boxed: false)
                    serializeString(thumbSize, buffer: buffer, boxed: false)
                    break
                case .inputPhotoLegacyFileLocation(let id, let accessHash, let fileReference, let volumeId, let localId, let secret):
                    if boxed {
                        buffer.appendInt32(-667654413)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    serializeBytes(fileReference, buffer: buffer, boxed: false)
                    serializeInt64(volumeId, buffer: buffer, boxed: false)
                    serializeInt32(localId, buffer: buffer, boxed: false)
                    serializeInt64(secret, buffer: buffer, boxed: false)
                    break
                case .inputSecureFileLocation(let id, let accessHash):
                    if boxed {
                        buffer.appendInt32(-876089816)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    break
                case .inputStickerSetThumb(let stickerset, let thumbVersion):
                    if boxed {
                        buffer.appendInt32(-1652231205)
                    }
                    stickerset.serialize(buffer, true)
                    serializeInt32(thumbVersion, buffer: buffer, boxed: false)
                    break
                case .inputTakeoutFileLocation:
                    if boxed {
                        buffer.appendInt32(700340377)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputDocumentFileLocation(let id, let accessHash, let fileReference, let thumbSize):
                return ("inputDocumentFileLocation", [("id", String(describing: id)), ("accessHash", String(describing: accessHash)), ("fileReference", String(describing: fileReference)), ("thumbSize", String(describing: thumbSize))])
                case .inputEncryptedFileLocation(let id, let accessHash):
                return ("inputEncryptedFileLocation", [("id", String(describing: id)), ("accessHash", String(describing: accessHash))])
                case .inputFileLocation(let volumeId, let localId, let secret, let fileReference):
                return ("inputFileLocation", [("volumeId", String(describing: volumeId)), ("localId", String(describing: localId)), ("secret", String(describing: secret)), ("fileReference", String(describing: fileReference))])
                case .inputGroupCallStream(let flags, let call, let timeMs, let scale, let videoChannel, let videoQuality):
                return ("inputGroupCallStream", [("flags", String(describing: flags)), ("call", String(describing: call)), ("timeMs", String(describing: timeMs)), ("scale", String(describing: scale)), ("videoChannel", String(describing: videoChannel)), ("videoQuality", String(describing: videoQuality))])
                case .inputPeerPhotoFileLocation(let flags, let peer, let photoId):
                return ("inputPeerPhotoFileLocation", [("flags", String(describing: flags)), ("peer", String(describing: peer)), ("photoId", String(describing: photoId))])
                case .inputPhotoFileLocation(let id, let accessHash, let fileReference, let thumbSize):
                return ("inputPhotoFileLocation", [("id", String(describing: id)), ("accessHash", String(describing: accessHash)), ("fileReference", String(describing: fileReference)), ("thumbSize", String(describing: thumbSize))])
                case .inputPhotoLegacyFileLocation(let id, let accessHash, let fileReference, let volumeId, let localId, let secret):
                return ("inputPhotoLegacyFileLocation", [("id", String(describing: id)), ("accessHash", String(describing: accessHash)), ("fileReference", String(describing: fileReference)), ("volumeId", String(describing: volumeId)), ("localId", String(describing: localId)), ("secret", String(describing: secret))])
                case .inputSecureFileLocation(let id, let accessHash):
                return ("inputSecureFileLocation", [("id", String(describing: id)), ("accessHash", String(describing: accessHash))])
                case .inputStickerSetThumb(let stickerset, let thumbVersion):
                return ("inputStickerSetThumb", [("stickerset", String(describing: stickerset)), ("thumbVersion", String(describing: thumbVersion))])
                case .inputTakeoutFileLocation:
                return ("inputTakeoutFileLocation", [])
    }
    }
    
        public static func parse_inputDocumentFileLocation(_ reader: BufferReader) -> InputFileLocation? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Buffer?
            _3 = parseBytes(reader)
            var _4: String?
            _4 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.InputFileLocation.inputDocumentFileLocation(id: _1!, accessHash: _2!, fileReference: _3!, thumbSize: _4!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputEncryptedFileLocation(_ reader: BufferReader) -> InputFileLocation? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputFileLocation.inputEncryptedFileLocation(id: _1!, accessHash: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputFileLocation(_ reader: BufferReader) -> InputFileLocation? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: Buffer?
            _4 = parseBytes(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.InputFileLocation.inputFileLocation(volumeId: _1!, localId: _2!, secret: _3!, fileReference: _4!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputGroupCallStream(_ reader: BufferReader) -> InputFileLocation? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.InputGroupCall?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.InputGroupCall
            }
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {_5 = reader.readInt32() }
            var _6: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {_6 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 0) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 0) == 0) || _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.InputFileLocation.inputGroupCallStream(flags: _1!, call: _2!, timeMs: _3!, scale: _4!, videoChannel: _5, videoQuality: _6)
            }
            else {
                return nil
            }
        }
        public static func parse_inputPeerPhotoFileLocation(_ reader: BufferReader) -> InputFileLocation? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.InputPeer?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.InputPeer
            }
            var _3: Int64?
            _3 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.InputFileLocation.inputPeerPhotoFileLocation(flags: _1!, peer: _2!, photoId: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputPhotoFileLocation(_ reader: BufferReader) -> InputFileLocation? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Buffer?
            _3 = parseBytes(reader)
            var _4: String?
            _4 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.InputFileLocation.inputPhotoFileLocation(id: _1!, accessHash: _2!, fileReference: _3!, thumbSize: _4!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputPhotoLegacyFileLocation(_ reader: BufferReader) -> InputFileLocation? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Buffer?
            _3 = parseBytes(reader)
            var _4: Int64?
            _4 = reader.readInt64()
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: Int64?
            _6 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.InputFileLocation.inputPhotoLegacyFileLocation(id: _1!, accessHash: _2!, fileReference: _3!, volumeId: _4!, localId: _5!, secret: _6!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputSecureFileLocation(_ reader: BufferReader) -> InputFileLocation? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputFileLocation.inputSecureFileLocation(id: _1!, accessHash: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputStickerSetThumb(_ reader: BufferReader) -> InputFileLocation? {
            var _1: Api.InputStickerSet?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputStickerSet
            }
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputFileLocation.inputStickerSetThumb(stickerset: _1!, thumbVersion: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputTakeoutFileLocation(_ reader: BufferReader) -> InputFileLocation? {
            return Api.InputFileLocation.inputTakeoutFileLocation
        }
    
    }
}
public extension Api {
    indirect enum InputFolderPeer: TypeConstructorDescription {
        case inputFolderPeer(peer: Api.InputPeer, folderId: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputFolderPeer(let peer, let folderId):
                    if boxed {
                        buffer.appendInt32(-70073706)
                    }
                    peer.serialize(buffer, true)
                    serializeInt32(folderId, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputFolderPeer(let peer, let folderId):
                return ("inputFolderPeer", [("peer", String(describing: peer)), ("folderId", String(describing: folderId))])
    }
    }
    
        public static func parse_inputFolderPeer(_ reader: BufferReader) -> InputFolderPeer? {
            var _1: Api.InputPeer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputPeer
            }
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputFolderPeer.inputFolderPeer(peer: _1!, folderId: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
