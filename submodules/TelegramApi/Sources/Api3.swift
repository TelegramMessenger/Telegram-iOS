public extension Api {
public struct upload {
    public enum WebFile: TypeConstructorDescription {
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
                return ("webFile", [("size", size), ("mimeType", mimeType), ("fileType", fileType), ("mtime", mtime), ("bytes", bytes)])
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
    public enum File: TypeConstructorDescription {
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
                return ("file", [("type", type), ("mtime", mtime), ("bytes", bytes)])
                case .fileCdnRedirect(let dcId, let fileToken, let encryptionKey, let encryptionIv, let fileHashes):
                return ("fileCdnRedirect", [("dcId", dcId), ("fileToken", fileToken), ("encryptionKey", encryptionKey), ("encryptionIv", encryptionIv), ("fileHashes", fileHashes)])
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
    public enum CdnFile: TypeConstructorDescription {
        case cdnFileReuploadNeeded(requestToken: Buffer)
        case cdnFile(bytes: Buffer)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .cdnFileReuploadNeeded(let requestToken):
                    if boxed {
                        buffer.appendInt32(-290921362)
                    }
                    serializeBytes(requestToken, buffer: buffer, boxed: false)
                    break
                case .cdnFile(let bytes):
                    if boxed {
                        buffer.appendInt32(-1449145777)
                    }
                    serializeBytes(bytes, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .cdnFileReuploadNeeded(let requestToken):
                return ("cdnFileReuploadNeeded", [("requestToken", requestToken)])
                case .cdnFile(let bytes):
                return ("cdnFile", [("bytes", bytes)])
    }
    }
    
        public static func parse_cdnFileReuploadNeeded(_ reader: BufferReader) -> CdnFile? {
            var _1: Buffer?
            _1 = parseBytes(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.upload.CdnFile.cdnFileReuploadNeeded(requestToken: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_cdnFile(_ reader: BufferReader) -> CdnFile? {
            var _1: Buffer?
            _1 = parseBytes(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.upload.CdnFile.cdnFile(bytes: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
}
public extension Api {
public struct storage {
    public enum FileType: TypeConstructorDescription {
        case fileUnknown
        case filePartial
        case fileJpeg
        case fileGif
        case filePng
        case filePdf
        case fileMp3
        case fileMov
        case fileMp4
        case fileWebp
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .fileUnknown:
                    if boxed {
                        buffer.appendInt32(-1432995067)
                    }
                    
                    break
                case .filePartial:
                    if boxed {
                        buffer.appendInt32(1086091090)
                    }
                    
                    break
                case .fileJpeg:
                    if boxed {
                        buffer.appendInt32(8322574)
                    }
                    
                    break
                case .fileGif:
                    if boxed {
                        buffer.appendInt32(-891180321)
                    }
                    
                    break
                case .filePng:
                    if boxed {
                        buffer.appendInt32(172975040)
                    }
                    
                    break
                case .filePdf:
                    if boxed {
                        buffer.appendInt32(-1373745011)
                    }
                    
                    break
                case .fileMp3:
                    if boxed {
                        buffer.appendInt32(1384777335)
                    }
                    
                    break
                case .fileMov:
                    if boxed {
                        buffer.appendInt32(1258941372)
                    }
                    
                    break
                case .fileMp4:
                    if boxed {
                        buffer.appendInt32(-1278304028)
                    }
                    
                    break
                case .fileWebp:
                    if boxed {
                        buffer.appendInt32(276907596)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .fileUnknown:
                return ("fileUnknown", [])
                case .filePartial:
                return ("filePartial", [])
                case .fileJpeg:
                return ("fileJpeg", [])
                case .fileGif:
                return ("fileGif", [])
                case .filePng:
                return ("filePng", [])
                case .filePdf:
                return ("filePdf", [])
                case .fileMp3:
                return ("fileMp3", [])
                case .fileMov:
                return ("fileMov", [])
                case .fileMp4:
                return ("fileMp4", [])
                case .fileWebp:
                return ("fileWebp", [])
    }
    }
    
        public static func parse_fileUnknown(_ reader: BufferReader) -> FileType? {
            return Api.storage.FileType.fileUnknown
        }
        public static func parse_filePartial(_ reader: BufferReader) -> FileType? {
            return Api.storage.FileType.filePartial
        }
        public static func parse_fileJpeg(_ reader: BufferReader) -> FileType? {
            return Api.storage.FileType.fileJpeg
        }
        public static func parse_fileGif(_ reader: BufferReader) -> FileType? {
            return Api.storage.FileType.fileGif
        }
        public static func parse_filePng(_ reader: BufferReader) -> FileType? {
            return Api.storage.FileType.filePng
        }
        public static func parse_filePdf(_ reader: BufferReader) -> FileType? {
            return Api.storage.FileType.filePdf
        }
        public static func parse_fileMp3(_ reader: BufferReader) -> FileType? {
            return Api.storage.FileType.fileMp3
        }
        public static func parse_fileMov(_ reader: BufferReader) -> FileType? {
            return Api.storage.FileType.fileMov
        }
        public static func parse_fileMp4(_ reader: BufferReader) -> FileType? {
            return Api.storage.FileType.fileMp4
        }
        public static func parse_fileWebp(_ reader: BufferReader) -> FileType? {
            return Api.storage.FileType.fileWebp
        }
    
    }
}
}
public extension Api {
public struct account {
    public enum TmpPassword: TypeConstructorDescription {
        case tmpPassword(tmpPassword: Buffer, validUntil: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .tmpPassword(let tmpPassword, let validUntil):
                    if boxed {
                        buffer.appendInt32(-614138572)
                    }
                    serializeBytes(tmpPassword, buffer: buffer, boxed: false)
                    serializeInt32(validUntil, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .tmpPassword(let tmpPassword, let validUntil):
                return ("tmpPassword", [("tmpPassword", tmpPassword), ("validUntil", validUntil)])
    }
    }
    
        public static func parse_tmpPassword(_ reader: BufferReader) -> TmpPassword? {
            var _1: Buffer?
            _1 = parseBytes(reader)
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.account.TmpPassword.tmpPassword(tmpPassword: _1!, validUntil: _2!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum PasswordSettings: TypeConstructorDescription {
        case passwordSettings(flags: Int32, email: String?, secureSettings: Api.SecureSecretSettings?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .passwordSettings(let flags, let email, let secureSettings):
                    if boxed {
                        buffer.appendInt32(-1705233435)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(email!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {secureSettings!.serialize(buffer, true)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .passwordSettings(let flags, let email, let secureSettings):
                return ("passwordSettings", [("flags", flags), ("email", email), ("secureSettings", secureSettings)])
    }
    }
    
        public static func parse_passwordSettings(_ reader: BufferReader) -> PasswordSettings? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            if Int(_1!) & Int(1 << 0) != 0 {_2 = parseString(reader) }
            var _3: Api.SecureSecretSettings?
            if Int(_1!) & Int(1 << 1) != 0 {if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.SecureSecretSettings
            } }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.account.PasswordSettings.passwordSettings(flags: _1!, email: _2, secureSettings: _3)
            }
            else {
                return nil
            }
        }
    
    }
    public enum Themes: TypeConstructorDescription {
        case themesNotModified
        case themes(hash: Int32, themes: [Api.Theme])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .themesNotModified:
                    if boxed {
                        buffer.appendInt32(-199313886)
                    }
                    
                    break
                case .themes(let hash, let themes):
                    if boxed {
                        buffer.appendInt32(2137482273)
                    }
                    serializeInt32(hash, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(themes.count))
                    for item in themes {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .themesNotModified:
                return ("themesNotModified", [])
                case .themes(let hash, let themes):
                return ("themes", [("hash", hash), ("themes", themes)])
    }
    }
    
        public static func parse_themesNotModified(_ reader: BufferReader) -> Themes? {
            return Api.account.Themes.themesNotModified
        }
        public static func parse_themes(_ reader: BufferReader) -> Themes? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Api.Theme]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Theme.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.account.Themes.themes(hash: _1!, themes: _2!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum WallPapers: TypeConstructorDescription {
        case wallPapersNotModified
        case wallPapers(hash: Int32, wallpapers: [Api.WallPaper])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .wallPapersNotModified:
                    if boxed {
                        buffer.appendInt32(471437699)
                    }
                    
                    break
                case .wallPapers(let hash, let wallpapers):
                    if boxed {
                        buffer.appendInt32(1881892265)
                    }
                    serializeInt32(hash, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(wallpapers.count))
                    for item in wallpapers {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .wallPapersNotModified:
                return ("wallPapersNotModified", [])
                case .wallPapers(let hash, let wallpapers):
                return ("wallPapers", [("hash", hash), ("wallpapers", wallpapers)])
    }
    }
    
        public static func parse_wallPapersNotModified(_ reader: BufferReader) -> WallPapers? {
            return Api.account.WallPapers.wallPapersNotModified
        }
        public static func parse_wallPapers(_ reader: BufferReader) -> WallPapers? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Api.WallPaper]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.WallPaper.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.account.WallPapers.wallPapers(hash: _1!, wallpapers: _2!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum PasswordInputSettings: TypeConstructorDescription {
        case passwordInputSettings(flags: Int32, newAlgo: Api.PasswordKdfAlgo?, newPasswordHash: Buffer?, hint: String?, email: String?, newSecureSettings: Api.SecureSecretSettings?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .passwordInputSettings(let flags, let newAlgo, let newPasswordHash, let hint, let email, let newSecureSettings):
                    if boxed {
                        buffer.appendInt32(-1036572727)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {newAlgo!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 0) != 0 {serializeBytes(newPasswordHash!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(hint!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(email!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {newSecureSettings!.serialize(buffer, true)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .passwordInputSettings(let flags, let newAlgo, let newPasswordHash, let hint, let email, let newSecureSettings):
                return ("passwordInputSettings", [("flags", flags), ("newAlgo", newAlgo), ("newPasswordHash", newPasswordHash), ("hint", hint), ("email", email), ("newSecureSettings", newSecureSettings)])
    }
    }
    
        public static func parse_passwordInputSettings(_ reader: BufferReader) -> PasswordInputSettings? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.PasswordKdfAlgo?
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.PasswordKdfAlgo
            } }
            var _3: Buffer?
            if Int(_1!) & Int(1 << 0) != 0 {_3 = parseBytes(reader) }
            var _4: String?
            if Int(_1!) & Int(1 << 0) != 0 {_4 = parseString(reader) }
            var _5: String?
            if Int(_1!) & Int(1 << 1) != 0 {_5 = parseString(reader) }
            var _6: Api.SecureSecretSettings?
            if Int(_1!) & Int(1 << 2) != 0 {if let signature = reader.readInt32() {
                _6 = Api.parse(reader, signature: signature) as? Api.SecureSecretSettings
            } }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 1) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 2) == 0) || _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.account.PasswordInputSettings.passwordInputSettings(flags: _1!, newAlgo: _2, newPasswordHash: _3, hint: _4, email: _5, newSecureSettings: _6)
            }
            else {
                return nil
            }
        }
    
    }
    public enum WebAuthorizations: TypeConstructorDescription {
        case webAuthorizations(authorizations: [Api.WebAuthorization], users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .webAuthorizations(let authorizations, let users):
                    if boxed {
                        buffer.appendInt32(-313079300)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(authorizations.count))
                    for item in authorizations {
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
                case .webAuthorizations(let authorizations, let users):
                return ("webAuthorizations", [("authorizations", authorizations), ("users", users)])
    }
    }
    
        public static func parse_webAuthorizations(_ reader: BufferReader) -> WebAuthorizations? {
            var _1: [Api.WebAuthorization]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.WebAuthorization.self)
            }
            var _2: [Api.User]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.account.WebAuthorizations.webAuthorizations(authorizations: _1!, users: _2!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum SentEmailCode: TypeConstructorDescription {
        case sentEmailCode(emailPattern: String, length: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .sentEmailCode(let emailPattern, let length):
                    if boxed {
                        buffer.appendInt32(-2128640689)
                    }
                    serializeString(emailPattern, buffer: buffer, boxed: false)
                    serializeInt32(length, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .sentEmailCode(let emailPattern, let length):
                return ("sentEmailCode", [("emailPattern", emailPattern), ("length", length)])
    }
    }
    
        public static func parse_sentEmailCode(_ reader: BufferReader) -> SentEmailCode? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.account.SentEmailCode.sentEmailCode(emailPattern: _1!, length: _2!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum ContentSettings: TypeConstructorDescription {
        case contentSettings(flags: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .contentSettings(let flags):
                    if boxed {
                        buffer.appendInt32(1474462241)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .contentSettings(let flags):
                return ("contentSettings", [("flags", flags)])
    }
    }
    
        public static func parse_contentSettings(_ reader: BufferReader) -> ContentSettings? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.account.ContentSettings.contentSettings(flags: _1!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum Authorizations: TypeConstructorDescription {
        case authorizations(authorizations: [Api.Authorization])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .authorizations(let authorizations):
                    if boxed {
                        buffer.appendInt32(307276766)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(authorizations.count))
                    for item in authorizations {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .authorizations(let authorizations):
                return ("authorizations", [("authorizations", authorizations)])
    }
    }
    
        public static func parse_authorizations(_ reader: BufferReader) -> Authorizations? {
            var _1: [Api.Authorization]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Authorization.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.account.Authorizations.authorizations(authorizations: _1!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum AuthorizationForm: TypeConstructorDescription {
        case authorizationForm(flags: Int32, requiredTypes: [Api.SecureRequiredType], values: [Api.SecureValue], errors: [Api.SecureValueError], users: [Api.User], privacyPolicyUrl: String?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .authorizationForm(let flags, let requiredTypes, let values, let errors, let users, let privacyPolicyUrl):
                    if boxed {
                        buffer.appendInt32(-1389486888)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(requiredTypes.count))
                    for item in requiredTypes {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(values.count))
                    for item in values {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(errors.count))
                    for item in errors {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(privacyPolicyUrl!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .authorizationForm(let flags, let requiredTypes, let values, let errors, let users, let privacyPolicyUrl):
                return ("authorizationForm", [("flags", flags), ("requiredTypes", requiredTypes), ("values", values), ("errors", errors), ("users", users), ("privacyPolicyUrl", privacyPolicyUrl)])
    }
    }
    
        public static func parse_authorizationForm(_ reader: BufferReader) -> AuthorizationForm? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Api.SecureRequiredType]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.SecureRequiredType.self)
            }
            var _3: [Api.SecureValue]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.SecureValue.self)
            }
            var _4: [Api.SecureValueError]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.SecureValueError.self)
            }
            var _5: [Api.User]?
            if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            var _6: String?
            if Int(_1!) & Int(1 << 0) != 0 {_6 = parseString(reader) }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 0) == 0) || _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.account.AuthorizationForm.authorizationForm(flags: _1!, requiredTypes: _2!, values: _3!, errors: _4!, users: _5!, privacyPolicyUrl: _6)
            }
            else {
                return nil
            }
        }
    
    }
    public enum Password: TypeConstructorDescription {
        case password(flags: Int32, currentAlgo: Api.PasswordKdfAlgo?, srpB: Buffer?, srpId: Int64?, hint: String?, emailUnconfirmedPattern: String?, newAlgo: Api.PasswordKdfAlgo, newSecureAlgo: Api.SecurePasswordKdfAlgo, secureRandom: Buffer)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .password(let flags, let currentAlgo, let srpB, let srpId, let hint, let emailUnconfirmedPattern, let newAlgo, let newSecureAlgo, let secureRandom):
                    if boxed {
                        buffer.appendInt32(-1390001672)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 2) != 0 {currentAlgo!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeBytes(srpB!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeInt64(srpId!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 3) != 0 {serializeString(hint!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 4) != 0 {serializeString(emailUnconfirmedPattern!, buffer: buffer, boxed: false)}
                    newAlgo.serialize(buffer, true)
                    newSecureAlgo.serialize(buffer, true)
                    serializeBytes(secureRandom, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .password(let flags, let currentAlgo, let srpB, let srpId, let hint, let emailUnconfirmedPattern, let newAlgo, let newSecureAlgo, let secureRandom):
                return ("password", [("flags", flags), ("currentAlgo", currentAlgo), ("srpB", srpB), ("srpId", srpId), ("hint", hint), ("emailUnconfirmedPattern", emailUnconfirmedPattern), ("newAlgo", newAlgo), ("newSecureAlgo", newSecureAlgo), ("secureRandom", secureRandom)])
    }
    }
    
        public static func parse_password(_ reader: BufferReader) -> Password? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.PasswordKdfAlgo?
            if Int(_1!) & Int(1 << 2) != 0 {if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.PasswordKdfAlgo
            } }
            var _3: Buffer?
            if Int(_1!) & Int(1 << 2) != 0 {_3 = parseBytes(reader) }
            var _4: Int64?
            if Int(_1!) & Int(1 << 2) != 0 {_4 = reader.readInt64() }
            var _5: String?
            if Int(_1!) & Int(1 << 3) != 0 {_5 = parseString(reader) }
            var _6: String?
            if Int(_1!) & Int(1 << 4) != 0 {_6 = parseString(reader) }
            var _7: Api.PasswordKdfAlgo?
            if let signature = reader.readInt32() {
                _7 = Api.parse(reader, signature: signature) as? Api.PasswordKdfAlgo
            }
            var _8: Api.SecurePasswordKdfAlgo?
            if let signature = reader.readInt32() {
                _8 = Api.parse(reader, signature: signature) as? Api.SecurePasswordKdfAlgo
            }
            var _9: Buffer?
            _9 = parseBytes(reader)
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 2) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 2) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 2) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 3) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 4) == 0) || _6 != nil
            let _c7 = _7 != nil
            let _c8 = _8 != nil
            let _c9 = _9 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 {
                return Api.account.Password.password(flags: _1!, currentAlgo: _2, srpB: _3, srpId: _4, hint: _5, emailUnconfirmedPattern: _6, newAlgo: _7!, newSecureAlgo: _8!, secureRandom: _9!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum PrivacyRules: TypeConstructorDescription {
        case privacyRules(rules: [Api.PrivacyRule], chats: [Api.Chat], users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .privacyRules(let rules, let chats, let users):
                    if boxed {
                        buffer.appendInt32(1352683077)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(rules.count))
                    for item in rules {
                        item.serialize(buffer, true)
                    }
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
                case .privacyRules(let rules, let chats, let users):
                return ("privacyRules", [("rules", rules), ("chats", chats), ("users", users)])
    }
    }
    
        public static func parse_privacyRules(_ reader: BufferReader) -> PrivacyRules? {
            var _1: [Api.PrivacyRule]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.PrivacyRule.self)
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
                return Api.account.PrivacyRules.privacyRules(rules: _1!, chats: _2!, users: _3!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum AutoDownloadSettings: TypeConstructorDescription {
        case autoDownloadSettings(low: Api.AutoDownloadSettings, medium: Api.AutoDownloadSettings, high: Api.AutoDownloadSettings)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .autoDownloadSettings(let low, let medium, let high):
                    if boxed {
                        buffer.appendInt32(1674235686)
                    }
                    low.serialize(buffer, true)
                    medium.serialize(buffer, true)
                    high.serialize(buffer, true)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .autoDownloadSettings(let low, let medium, let high):
                return ("autoDownloadSettings", [("low", low), ("medium", medium), ("high", high)])
    }
    }
    
        public static func parse_autoDownloadSettings(_ reader: BufferReader) -> AutoDownloadSettings? {
            var _1: Api.AutoDownloadSettings?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.AutoDownloadSettings
            }
            var _2: Api.AutoDownloadSettings?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.AutoDownloadSettings
            }
            var _3: Api.AutoDownloadSettings?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.AutoDownloadSettings
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.account.AutoDownloadSettings.autoDownloadSettings(low: _1!, medium: _2!, high: _3!)
            }
            else {
                return nil
            }
        }
    
    }
}
}
public extension Api {
public struct wallet {
    public enum KeySecretSalt: TypeConstructorDescription {
        case secretSalt(salt: Buffer)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .secretSalt(let salt):
                    if boxed {
                        buffer.appendInt32(-582464156)
                    }
                    serializeBytes(salt, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .secretSalt(let salt):
                return ("secretSalt", [("salt", salt)])
    }
    }
    
        public static func parse_secretSalt(_ reader: BufferReader) -> KeySecretSalt? {
            var _1: Buffer?
            _1 = parseBytes(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.wallet.KeySecretSalt.secretSalt(salt: _1!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum LiteResponse: TypeConstructorDescription {
        case liteResponse(response: Buffer)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .liteResponse(let response):
                    if boxed {
                        buffer.appendInt32(1984136919)
                    }
                    serializeBytes(response, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .liteResponse(let response):
                return ("liteResponse", [("response", response)])
    }
    }
    
        public static func parse_liteResponse(_ reader: BufferReader) -> LiteResponse? {
            var _1: Buffer?
            _1 = parseBytes(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.wallet.LiteResponse.liteResponse(response: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
}
public extension Api {
public struct photos {
    public enum Photo: TypeConstructorDescription {
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
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .photo(let photo, let users):
                return ("photo", [("photo", photo), ("users", users)])
    }
    }
    
        public static func parse_photo(_ reader: BufferReader) -> Photo? {
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
    public enum Photos: TypeConstructorDescription {
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
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .photos(let photos, let users):
                return ("photos", [("photos", photos), ("users", users)])
                case .photosSlice(let count, let photos, let users):
                return ("photosSlice", [("count", count), ("photos", photos), ("users", users)])
    }
    }
    
        public static func parse_photos(_ reader: BufferReader) -> Photos? {
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
        public static func parse_photosSlice(_ reader: BufferReader) -> Photos? {
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
    public enum PhoneCall: TypeConstructorDescription {
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
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .phoneCall(let phoneCall, let users):
                return ("phoneCall", [("phoneCall", phoneCall), ("users", users)])
    }
    }
    
        public static func parse_phoneCall(_ reader: BufferReader) -> PhoneCall? {
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
public extension Api {
    public struct functions {
            public struct messages {
                public static func getHistory(peer: Api.InputPeer, offsetId: Int32, offsetDate: Int32, addOffset: Int32, limit: Int32, maxId: Int32, minId: Int32, hash: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.Messages>) {
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
                    return (FunctionDescription(name: "messages.getHistory", parameters: [("peer", peer), ("offsetId", offsetId), ("offsetDate", offsetDate), ("addOffset", addOffset), ("limit", limit), ("maxId", maxId), ("minId", minId), ("hash", hash)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.Messages? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.Messages?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.Messages
                        }
                        return result
                    })
                }
            
                public static func readHistory(peer: Api.InputPeer, maxId: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.AffectedMessages>) {
                    let buffer = Buffer()
                    buffer.appendInt32(238054714)
                    peer.serialize(buffer, true)
                    serializeInt32(maxId, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.readHistory", parameters: [("peer", peer), ("maxId", maxId)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.AffectedMessages? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.AffectedMessages?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.AffectedMessages
                        }
                        return result
                    })
                }
            
                public static func deleteHistory(flags: Int32, peer: Api.InputPeer, maxId: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.AffectedHistory>) {
                    let buffer = Buffer()
                    buffer.appendInt32(469850889)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    serializeInt32(maxId, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.deleteHistory", parameters: [("flags", flags), ("peer", peer), ("maxId", maxId)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.AffectedHistory? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.AffectedHistory?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.AffectedHistory
                        }
                        return result
                    })
                }
            
                public static func deleteMessages(flags: Int32, id: [Int32]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.AffectedMessages>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-443640366)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(id.count))
                    for item in id {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    return (FunctionDescription(name: "messages.deleteMessages", parameters: [("flags", flags), ("id", id)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.AffectedMessages? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.AffectedMessages?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.AffectedMessages
                        }
                        return result
                    })
                }
            
                public static func receivedMessages(maxId: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Api.ReceivedNotifyMessage]>) {
                    let buffer = Buffer()
                    buffer.appendInt32(94983360)
                    serializeInt32(maxId, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.receivedMessages", parameters: [("maxId", maxId)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> [Api.ReceivedNotifyMessage]? in
                        let reader = BufferReader(buffer)
                        var result: [Api.ReceivedNotifyMessage]?
                        if let _ = reader.readInt32() {
                            result = Api.parseVector(reader, elementSignature: 0, elementType: Api.ReceivedNotifyMessage.self)
                        }
                        return result
                    })
                }
            
                public static func setTyping(peer: Api.InputPeer, action: Api.SendMessageAction) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1551737264)
                    peer.serialize(buffer, true)
                    action.serialize(buffer, true)
                    return (FunctionDescription(name: "messages.setTyping", parameters: [("peer", peer), ("action", action)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func reportSpam(peer: Api.InputPeer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-820669733)
                    peer.serialize(buffer, true)
                    return (FunctionDescription(name: "messages.reportSpam", parameters: [("peer", peer)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func getPeerSettings(peer: Api.InputPeer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.PeerSettings>) {
                    let buffer = Buffer()
                    buffer.appendInt32(913498268)
                    peer.serialize(buffer, true)
                    return (FunctionDescription(name: "messages.getPeerSettings", parameters: [("peer", peer)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.PeerSettings? in
                        let reader = BufferReader(buffer)
                        var result: Api.PeerSettings?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.PeerSettings
                        }
                        return result
                    })
                }
            
                public static func getChats(id: [Int32]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.Chats>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1013621127)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(id.count))
                    for item in id {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    return (FunctionDescription(name: "messages.getChats", parameters: [("id", id)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.Chats? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.Chats?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.Chats
                        }
                        return result
                    })
                }
            
                public static func getFullChat(chatId: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.ChatFull>) {
                    let buffer = Buffer()
                    buffer.appendInt32(998448230)
                    serializeInt32(chatId, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.getFullChat", parameters: [("chatId", chatId)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.ChatFull? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.ChatFull?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.ChatFull
                        }
                        return result
                    })
                }
            
                public static func editChatTitle(chatId: Int32, title: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-599447467)
                    serializeInt32(chatId, buffer: buffer, boxed: false)
                    serializeString(title, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.editChatTitle", parameters: [("chatId", chatId), ("title", title)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
            
                public static func editChatPhoto(chatId: Int32, photo: Api.InputChatPhoto) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-900957736)
                    serializeInt32(chatId, buffer: buffer, boxed: false)
                    photo.serialize(buffer, true)
                    return (FunctionDescription(name: "messages.editChatPhoto", parameters: [("chatId", chatId), ("photo", photo)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
            
                public static func addChatUser(chatId: Int32, userId: Api.InputUser, fwdLimit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-106911223)
                    serializeInt32(chatId, buffer: buffer, boxed: false)
                    userId.serialize(buffer, true)
                    serializeInt32(fwdLimit, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.addChatUser", parameters: [("chatId", chatId), ("userId", userId), ("fwdLimit", fwdLimit)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
            
                public static func deleteChatUser(chatId: Int32, userId: Api.InputUser) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-530505962)
                    serializeInt32(chatId, buffer: buffer, boxed: false)
                    userId.serialize(buffer, true)
                    return (FunctionDescription(name: "messages.deleteChatUser", parameters: [("chatId", chatId), ("userId", userId)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
            
                public static func createChat(users: [Api.InputUser], title: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(164303470)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    serializeString(title, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.createChat", parameters: [("users", users), ("title", title)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
            
                public static func forwardMessage(peer: Api.InputPeer, id: Int32, randomId: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(865483769)
                    peer.serialize(buffer, true)
                    serializeInt32(id, buffer: buffer, boxed: false)
                    serializeInt64(randomId, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.forwardMessage", parameters: [("peer", peer), ("id", id), ("randomId", randomId)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
            
                public static func getDhConfig(version: Int32, randomLength: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.DhConfig>) {
                    let buffer = Buffer()
                    buffer.appendInt32(651135312)
                    serializeInt32(version, buffer: buffer, boxed: false)
                    serializeInt32(randomLength, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.getDhConfig", parameters: [("version", version), ("randomLength", randomLength)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.DhConfig? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.DhConfig?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.DhConfig
                        }
                        return result
                    })
                }
            
                public static func requestEncryption(userId: Api.InputUser, randomId: Int32, gA: Buffer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.EncryptedChat>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-162681021)
                    userId.serialize(buffer, true)
                    serializeInt32(randomId, buffer: buffer, boxed: false)
                    serializeBytes(gA, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.requestEncryption", parameters: [("userId", userId), ("randomId", randomId), ("gA", gA)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.EncryptedChat? in
                        let reader = BufferReader(buffer)
                        var result: Api.EncryptedChat?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.EncryptedChat
                        }
                        return result
                    })
                }
            
                public static func acceptEncryption(peer: Api.InputEncryptedChat, gB: Buffer, keyFingerprint: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.EncryptedChat>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1035731989)
                    peer.serialize(buffer, true)
                    serializeBytes(gB, buffer: buffer, boxed: false)
                    serializeInt64(keyFingerprint, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.acceptEncryption", parameters: [("peer", peer), ("gB", gB), ("keyFingerprint", keyFingerprint)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.EncryptedChat? in
                        let reader = BufferReader(buffer)
                        var result: Api.EncryptedChat?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.EncryptedChat
                        }
                        return result
                    })
                }
            
                public static func discardEncryption(chatId: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-304536635)
                    serializeInt32(chatId, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.discardEncryption", parameters: [("chatId", chatId)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func setEncryptedTyping(peer: Api.InputEncryptedChat, typing: Api.Bool) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(2031374829)
                    peer.serialize(buffer, true)
                    typing.serialize(buffer, true)
                    return (FunctionDescription(name: "messages.setEncryptedTyping", parameters: [("peer", peer), ("typing", typing)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func readEncryptedHistory(peer: Api.InputEncryptedChat, maxDate: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(2135648522)
                    peer.serialize(buffer, true)
                    serializeInt32(maxDate, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.readEncryptedHistory", parameters: [("peer", peer), ("maxDate", maxDate)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func sendEncrypted(peer: Api.InputEncryptedChat, randomId: Int64, data: Buffer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.SentEncryptedMessage>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1451792525)
                    peer.serialize(buffer, true)
                    serializeInt64(randomId, buffer: buffer, boxed: false)
                    serializeBytes(data, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.sendEncrypted", parameters: [("peer", peer), ("randomId", randomId), ("data", data)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.SentEncryptedMessage? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.SentEncryptedMessage?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.SentEncryptedMessage
                        }
                        return result
                    })
                }
            
                public static func sendEncryptedFile(peer: Api.InputEncryptedChat, randomId: Int64, data: Buffer, file: Api.InputEncryptedFile) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.SentEncryptedMessage>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1701831834)
                    peer.serialize(buffer, true)
                    serializeInt64(randomId, buffer: buffer, boxed: false)
                    serializeBytes(data, buffer: buffer, boxed: false)
                    file.serialize(buffer, true)
                    return (FunctionDescription(name: "messages.sendEncryptedFile", parameters: [("peer", peer), ("randomId", randomId), ("data", data), ("file", file)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.SentEncryptedMessage? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.SentEncryptedMessage?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.SentEncryptedMessage
                        }
                        return result
                    })
                }
            
                public static func sendEncryptedService(peer: Api.InputEncryptedChat, randomId: Int64, data: Buffer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.SentEncryptedMessage>) {
                    let buffer = Buffer()
                    buffer.appendInt32(852769188)
                    peer.serialize(buffer, true)
                    serializeInt64(randomId, buffer: buffer, boxed: false)
                    serializeBytes(data, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.sendEncryptedService", parameters: [("peer", peer), ("randomId", randomId), ("data", data)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.SentEncryptedMessage? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.SentEncryptedMessage?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.SentEncryptedMessage
                        }
                        return result
                    })
                }
            
                public static func receivedQueue(maxQts: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Int64]>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1436924774)
                    serializeInt32(maxQts, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.receivedQueue", parameters: [("maxQts", maxQts)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> [Int64]? in
                        let reader = BufferReader(buffer)
                        var result: [Int64]?
                        if let _ = reader.readInt32() {
                            result = Api.parseVector(reader, elementSignature: 570911930, elementType: Int64.self)
                        }
                        return result
                    })
                }
            
                public static func reportEncryptedSpam(peer: Api.InputEncryptedChat) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1259113487)
                    peer.serialize(buffer, true)
                    return (FunctionDescription(name: "messages.reportEncryptedSpam", parameters: [("peer", peer)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func readMessageContents(id: [Int32]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.AffectedMessages>) {
                    let buffer = Buffer()
                    buffer.appendInt32(916930423)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(id.count))
                    for item in id {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    return (FunctionDescription(name: "messages.readMessageContents", parameters: [("id", id)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.AffectedMessages? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.AffectedMessages?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.AffectedMessages
                        }
                        return result
                    })
                }
            
                public static func getAllStickers(hash: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.AllStickers>) {
                    let buffer = Buffer()
                    buffer.appendInt32(479598769)
                    serializeInt32(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.getAllStickers", parameters: [("hash", hash)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.AllStickers? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.AllStickers?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.AllStickers
                        }
                        return result
                    })
                }
            
                public static func checkChatInvite(hash: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.ChatInvite>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1051570619)
                    serializeString(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.checkChatInvite", parameters: [("hash", hash)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.ChatInvite? in
                        let reader = BufferReader(buffer)
                        var result: Api.ChatInvite?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.ChatInvite
                        }
                        return result
                    })
                }
            
                public static func importChatInvite(hash: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1817183516)
                    serializeString(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.importChatInvite", parameters: [("hash", hash)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
            
                public static func getStickerSet(stickerset: Api.InputStickerSet) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.StickerSet>) {
                    let buffer = Buffer()
                    buffer.appendInt32(639215886)
                    stickerset.serialize(buffer, true)
                    return (FunctionDescription(name: "messages.getStickerSet", parameters: [("stickerset", stickerset)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.StickerSet? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.StickerSet?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.StickerSet
                        }
                        return result
                    })
                }
            
                public static func installStickerSet(stickerset: Api.InputStickerSet, archived: Api.Bool) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.StickerSetInstallResult>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-946871200)
                    stickerset.serialize(buffer, true)
                    archived.serialize(buffer, true)
                    return (FunctionDescription(name: "messages.installStickerSet", parameters: [("stickerset", stickerset), ("archived", archived)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.StickerSetInstallResult? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.StickerSetInstallResult?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.StickerSetInstallResult
                        }
                        return result
                    })
                }
            
                public static func uninstallStickerSet(stickerset: Api.InputStickerSet) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-110209570)
                    stickerset.serialize(buffer, true)
                    return (FunctionDescription(name: "messages.uninstallStickerSet", parameters: [("stickerset", stickerset)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func startBot(bot: Api.InputUser, peer: Api.InputPeer, randomId: Int64, startParam: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-421563528)
                    bot.serialize(buffer, true)
                    peer.serialize(buffer, true)
                    serializeInt64(randomId, buffer: buffer, boxed: false)
                    serializeString(startParam, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.startBot", parameters: [("bot", bot), ("peer", peer), ("randomId", randomId), ("startParam", startParam)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
            
                public static func getMessagesViews(peer: Api.InputPeer, id: [Int32], increment: Api.Bool) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Int32]>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-993483427)
                    peer.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(id.count))
                    for item in id {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    increment.serialize(buffer, true)
                    return (FunctionDescription(name: "messages.getMessagesViews", parameters: [("peer", peer), ("id", id), ("increment", increment)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> [Int32]? in
                        let reader = BufferReader(buffer)
                        var result: [Int32]?
                        if let _ = reader.readInt32() {
                            result = Api.parseVector(reader, elementSignature: -1471112230, elementType: Int32.self)
                        }
                        return result
                    })
                }
            
                public static func editChatAdmin(chatId: Int32, userId: Api.InputUser, isAdmin: Api.Bool) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1444503762)
                    serializeInt32(chatId, buffer: buffer, boxed: false)
                    userId.serialize(buffer, true)
                    isAdmin.serialize(buffer, true)
                    return (FunctionDescription(name: "messages.editChatAdmin", parameters: [("chatId", chatId), ("userId", userId), ("isAdmin", isAdmin)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func migrateChat(chatId: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(363051235)
                    serializeInt32(chatId, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.migrateChat", parameters: [("chatId", chatId)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
            
                public static func reorderStickerSets(flags: Int32, order: [Int64]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(2016638777)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(order.count))
                    for item in order {
                        serializeInt64(item, buffer: buffer, boxed: false)
                    }
                    return (FunctionDescription(name: "messages.reorderStickerSets", parameters: [("flags", flags), ("order", order)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func getDocumentByHash(sha256: Buffer, size: Int32, mimeType: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Document>) {
                    let buffer = Buffer()
                    buffer.appendInt32(864953444)
                    serializeBytes(sha256, buffer: buffer, boxed: false)
                    serializeInt32(size, buffer: buffer, boxed: false)
                    serializeString(mimeType, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.getDocumentByHash", parameters: [("sha256", sha256), ("size", size), ("mimeType", mimeType)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Document? in
                        let reader = BufferReader(buffer)
                        var result: Api.Document?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Document
                        }
                        return result
                    })
                }
            
                public static func searchGifs(q: String, offset: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.FoundGifs>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1080395925)
                    serializeString(q, buffer: buffer, boxed: false)
                    serializeInt32(offset, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.searchGifs", parameters: [("q", q), ("offset", offset)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.FoundGifs? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.FoundGifs?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.FoundGifs
                        }
                        return result
                    })
                }
            
                public static func getSavedGifs(hash: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.SavedGifs>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-2084618926)
                    serializeInt32(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.getSavedGifs", parameters: [("hash", hash)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.SavedGifs? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.SavedGifs?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.SavedGifs
                        }
                        return result
                    })
                }
            
                public static func saveGif(id: Api.InputDocument, unsave: Api.Bool) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(846868683)
                    id.serialize(buffer, true)
                    unsave.serialize(buffer, true)
                    return (FunctionDescription(name: "messages.saveGif", parameters: [("id", id), ("unsave", unsave)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func getInlineBotResults(flags: Int32, bot: Api.InputUser, peer: Api.InputPeer, geoPoint: Api.InputGeoPoint?, query: String, offset: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.BotResults>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1364105629)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    bot.serialize(buffer, true)
                    peer.serialize(buffer, true)
                    if Int(flags) & Int(1 << 0) != 0 {geoPoint!.serialize(buffer, true)}
                    serializeString(query, buffer: buffer, boxed: false)
                    serializeString(offset, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.getInlineBotResults", parameters: [("flags", flags), ("bot", bot), ("peer", peer), ("geoPoint", geoPoint), ("query", query), ("offset", offset)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.BotResults? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.BotResults?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.BotResults
                        }
                        return result
                    })
                }
            
                public static func setInlineBotResults(flags: Int32, queryId: Int64, results: [Api.InputBotInlineResult], cacheTime: Int32, nextOffset: String?, switchPm: Api.InlineBotSwitchPM?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
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
                    return (FunctionDescription(name: "messages.setInlineBotResults", parameters: [("flags", flags), ("queryId", queryId), ("results", results), ("cacheTime", cacheTime), ("nextOffset", nextOffset), ("switchPm", switchPm)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func getMessageEditData(peer: Api.InputPeer, id: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.MessageEditData>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-39416522)
                    peer.serialize(buffer, true)
                    serializeInt32(id, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.getMessageEditData", parameters: [("peer", peer), ("id", id)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.MessageEditData? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.MessageEditData?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.MessageEditData
                        }
                        return result
                    })
                }
            
                public static func getBotCallbackAnswer(flags: Int32, peer: Api.InputPeer, msgId: Int32, data: Buffer?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.BotCallbackAnswer>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-2130010132)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    serializeInt32(msgId, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeBytes(data!, buffer: buffer, boxed: false)}
                    return (FunctionDescription(name: "messages.getBotCallbackAnswer", parameters: [("flags", flags), ("peer", peer), ("msgId", msgId), ("data", data)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.BotCallbackAnswer? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.BotCallbackAnswer?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.BotCallbackAnswer
                        }
                        return result
                    })
                }
            
                public static func setBotCallbackAnswer(flags: Int32, queryId: Int64, message: String?, url: String?, cacheTime: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-712043766)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(queryId, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(message!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeString(url!, buffer: buffer, boxed: false)}
                    serializeInt32(cacheTime, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.setBotCallbackAnswer", parameters: [("flags", flags), ("queryId", queryId), ("message", message), ("url", url), ("cacheTime", cacheTime)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func saveDraft(flags: Int32, replyToMsgId: Int32?, peer: Api.InputPeer, message: String, entities: [Api.MessageEntity]?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
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
                    return (FunctionDescription(name: "messages.saveDraft", parameters: [("flags", flags), ("replyToMsgId", replyToMsgId), ("peer", peer), ("message", message), ("entities", entities)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func getAllDrafts() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1782549861)
                    
                    return (FunctionDescription(name: "messages.getAllDrafts", parameters: []), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
            
                public static func getFeaturedStickers(hash: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.FeaturedStickers>) {
                    let buffer = Buffer()
                    buffer.appendInt32(766298703)
                    serializeInt32(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.getFeaturedStickers", parameters: [("hash", hash)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.FeaturedStickers? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.FeaturedStickers?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.FeaturedStickers
                        }
                        return result
                    })
                }
            
                public static func readFeaturedStickers(id: [Int64]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1527873830)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(id.count))
                    for item in id {
                        serializeInt64(item, buffer: buffer, boxed: false)
                    }
                    return (FunctionDescription(name: "messages.readFeaturedStickers", parameters: [("id", id)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func getRecentStickers(flags: Int32, hash: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.RecentStickers>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1587647177)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.getRecentStickers", parameters: [("flags", flags), ("hash", hash)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.RecentStickers? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.RecentStickers?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.RecentStickers
                        }
                        return result
                    })
                }
            
                public static func saveRecentSticker(flags: Int32, id: Api.InputDocument, unsave: Api.Bool) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(958863608)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    id.serialize(buffer, true)
                    unsave.serialize(buffer, true)
                    return (FunctionDescription(name: "messages.saveRecentSticker", parameters: [("flags", flags), ("id", id), ("unsave", unsave)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func clearRecentStickers(flags: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1986437075)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.clearRecentStickers", parameters: [("flags", flags)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func getArchivedStickers(flags: Int32, offsetId: Int64, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.ArchivedStickers>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1475442322)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(offsetId, buffer: buffer, boxed: false)
                    serializeInt32(limit, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.getArchivedStickers", parameters: [("flags", flags), ("offsetId", offsetId), ("limit", limit)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.ArchivedStickers? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.ArchivedStickers?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.ArchivedStickers
                        }
                        return result
                    })
                }
            
                public static func getMaskStickers(hash: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.AllStickers>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1706608543)
                    serializeInt32(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.getMaskStickers", parameters: [("hash", hash)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.AllStickers? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.AllStickers?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.AllStickers
                        }
                        return result
                    })
                }
            
                public static func getAttachedStickers(media: Api.InputStickeredMedia) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Api.StickerSetCovered]>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-866424884)
                    media.serialize(buffer, true)
                    return (FunctionDescription(name: "messages.getAttachedStickers", parameters: [("media", media)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> [Api.StickerSetCovered]? in
                        let reader = BufferReader(buffer)
                        var result: [Api.StickerSetCovered]?
                        if let _ = reader.readInt32() {
                            result = Api.parseVector(reader, elementSignature: 0, elementType: Api.StickerSetCovered.self)
                        }
                        return result
                    })
                }
            
                public static func setGameScore(flags: Int32, peer: Api.InputPeer, id: Int32, userId: Api.InputUser, score: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1896289088)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    serializeInt32(id, buffer: buffer, boxed: false)
                    userId.serialize(buffer, true)
                    serializeInt32(score, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.setGameScore", parameters: [("flags", flags), ("peer", peer), ("id", id), ("userId", userId), ("score", score)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
            
                public static func setInlineGameScore(flags: Int32, id: Api.InputBotInlineMessageID, userId: Api.InputUser, score: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(363700068)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    id.serialize(buffer, true)
                    userId.serialize(buffer, true)
                    serializeInt32(score, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.setInlineGameScore", parameters: [("flags", flags), ("id", id), ("userId", userId), ("score", score)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func getGameHighScores(peer: Api.InputPeer, id: Int32, userId: Api.InputUser) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.HighScores>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-400399203)
                    peer.serialize(buffer, true)
                    serializeInt32(id, buffer: buffer, boxed: false)
                    userId.serialize(buffer, true)
                    return (FunctionDescription(name: "messages.getGameHighScores", parameters: [("peer", peer), ("id", id), ("userId", userId)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.HighScores? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.HighScores?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.HighScores
                        }
                        return result
                    })
                }
            
                public static func getInlineGameHighScores(id: Api.InputBotInlineMessageID, userId: Api.InputUser) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.HighScores>) {
                    let buffer = Buffer()
                    buffer.appendInt32(258170395)
                    id.serialize(buffer, true)
                    userId.serialize(buffer, true)
                    return (FunctionDescription(name: "messages.getInlineGameHighScores", parameters: [("id", id), ("userId", userId)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.HighScores? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.HighScores?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.HighScores
                        }
                        return result
                    })
                }
            
                public static func getCommonChats(userId: Api.InputUser, maxId: Int32, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.Chats>) {
                    let buffer = Buffer()
                    buffer.appendInt32(218777796)
                    userId.serialize(buffer, true)
                    serializeInt32(maxId, buffer: buffer, boxed: false)
                    serializeInt32(limit, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.getCommonChats", parameters: [("userId", userId), ("maxId", maxId), ("limit", limit)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.Chats? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.Chats?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.Chats
                        }
                        return result
                    })
                }
            
                public static func getAllChats(exceptIds: [Int32]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.Chats>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-341307408)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(exceptIds.count))
                    for item in exceptIds {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    return (FunctionDescription(name: "messages.getAllChats", parameters: [("exceptIds", exceptIds)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.Chats? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.Chats?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.Chats
                        }
                        return result
                    })
                }
            
                public static func getWebPage(url: String, hash: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.WebPage>) {
                    let buffer = Buffer()
                    buffer.appendInt32(852135825)
                    serializeString(url, buffer: buffer, boxed: false)
                    serializeInt32(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.getWebPage", parameters: [("url", url), ("hash", hash)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.WebPage? in
                        let reader = BufferReader(buffer)
                        var result: Api.WebPage?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.WebPage
                        }
                        return result
                    })
                }
            
                public static func setBotShippingResults(flags: Int32, queryId: Int64, error: String?, shippingOptions: [Api.ShippingOption]?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
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
                    return (FunctionDescription(name: "messages.setBotShippingResults", parameters: [("flags", flags), ("queryId", queryId), ("error", error), ("shippingOptions", shippingOptions)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func setBotPrecheckoutResults(flags: Int32, queryId: Int64, error: String?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(163765653)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(queryId, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(error!, buffer: buffer, boxed: false)}
                    return (FunctionDescription(name: "messages.setBotPrecheckoutResults", parameters: [("flags", flags), ("queryId", queryId), ("error", error)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func sendScreenshotNotification(peer: Api.InputPeer, replyToMsgId: Int32, randomId: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-914493408)
                    peer.serialize(buffer, true)
                    serializeInt32(replyToMsgId, buffer: buffer, boxed: false)
                    serializeInt64(randomId, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.sendScreenshotNotification", parameters: [("peer", peer), ("replyToMsgId", replyToMsgId), ("randomId", randomId)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
            
                public static func getFavedStickers(hash: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.FavedStickers>) {
                    let buffer = Buffer()
                    buffer.appendInt32(567151374)
                    serializeInt32(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.getFavedStickers", parameters: [("hash", hash)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.FavedStickers? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.FavedStickers?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.FavedStickers
                        }
                        return result
                    })
                }
            
                public static func faveSticker(id: Api.InputDocument, unfave: Api.Bool) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1174420133)
                    id.serialize(buffer, true)
                    unfave.serialize(buffer, true)
                    return (FunctionDescription(name: "messages.faveSticker", parameters: [("id", id), ("unfave", unfave)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func getUnreadMentions(peer: Api.InputPeer, offsetId: Int32, addOffset: Int32, limit: Int32, maxId: Int32, minId: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.Messages>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1180140658)
                    peer.serialize(buffer, true)
                    serializeInt32(offsetId, buffer: buffer, boxed: false)
                    serializeInt32(addOffset, buffer: buffer, boxed: false)
                    serializeInt32(limit, buffer: buffer, boxed: false)
                    serializeInt32(maxId, buffer: buffer, boxed: false)
                    serializeInt32(minId, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.getUnreadMentions", parameters: [("peer", peer), ("offsetId", offsetId), ("addOffset", addOffset), ("limit", limit), ("maxId", maxId), ("minId", minId)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.Messages? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.Messages?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.Messages
                        }
                        return result
                    })
                }
            
                public static func readMentions(peer: Api.InputPeer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.AffectedHistory>) {
                    let buffer = Buffer()
                    buffer.appendInt32(251759059)
                    peer.serialize(buffer, true)
                    return (FunctionDescription(name: "messages.readMentions", parameters: [("peer", peer)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.AffectedHistory? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.AffectedHistory?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.AffectedHistory
                        }
                        return result
                    })
                }
            
                public static func uploadMedia(peer: Api.InputPeer, media: Api.InputMedia) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.MessageMedia>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1369162417)
                    peer.serialize(buffer, true)
                    media.serialize(buffer, true)
                    return (FunctionDescription(name: "messages.uploadMedia", parameters: [("peer", peer), ("media", media)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.MessageMedia? in
                        let reader = BufferReader(buffer)
                        var result: Api.MessageMedia?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.MessageMedia
                        }
                        return result
                    })
                }
            
                public static func uploadEncryptedFile(peer: Api.InputEncryptedChat, file: Api.InputEncryptedFile) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.EncryptedFile>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1347929239)
                    peer.serialize(buffer, true)
                    file.serialize(buffer, true)
                    return (FunctionDescription(name: "messages.uploadEncryptedFile", parameters: [("peer", peer), ("file", file)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.EncryptedFile? in
                        let reader = BufferReader(buffer)
                        var result: Api.EncryptedFile?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.EncryptedFile
                        }
                        return result
                    })
                }
            
                public static func getWebPagePreview(flags: Int32, message: String, entities: [Api.MessageEntity]?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.MessageMedia>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1956073268)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(message, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 3) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(entities!.count))
                    for item in entities! {
                        item.serialize(buffer, true)
                    }}
                    return (FunctionDescription(name: "messages.getWebPagePreview", parameters: [("flags", flags), ("message", message), ("entities", entities)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.MessageMedia? in
                        let reader = BufferReader(buffer)
                        var result: Api.MessageMedia?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.MessageMedia
                        }
                        return result
                    })
                }
            
                public static func getMessages(id: [Api.InputMessage]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.Messages>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1673946374)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(id.count))
                    for item in id {
                        item.serialize(buffer, true)
                    }
                    return (FunctionDescription(name: "messages.getMessages", parameters: [("id", id)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.Messages? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.Messages?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.Messages
                        }
                        return result
                    })
                }
            
                public static func report(peer: Api.InputPeer, id: [Int32], reason: Api.ReportReason) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1115507112)
                    peer.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(id.count))
                    for item in id {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    reason.serialize(buffer, true)
                    return (FunctionDescription(name: "messages.report", parameters: [("peer", peer), ("id", id), ("reason", reason)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func getRecentLocations(peer: Api.InputPeer, limit: Int32, hash: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.Messages>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1144759543)
                    peer.serialize(buffer, true)
                    serializeInt32(limit, buffer: buffer, boxed: false)
                    serializeInt32(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.getRecentLocations", parameters: [("peer", peer), ("limit", limit), ("hash", hash)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.Messages? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.Messages?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.Messages
                        }
                        return result
                    })
                }
            
                public static func search(flags: Int32, peer: Api.InputPeer, q: String, fromId: Api.InputUser?, filter: Api.MessagesFilter, minDate: Int32, maxDate: Int32, offsetId: Int32, addOffset: Int32, limit: Int32, maxId: Int32, minId: Int32, hash: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.Messages>) {
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
                    return (FunctionDescription(name: "messages.search", parameters: [("flags", flags), ("peer", peer), ("q", q), ("fromId", fromId), ("filter", filter), ("minDate", minDate), ("maxDate", maxDate), ("offsetId", offsetId), ("addOffset", addOffset), ("limit", limit), ("maxId", maxId), ("minId", minId), ("hash", hash)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.Messages? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.Messages?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.Messages
                        }
                        return result
                    })
                }
            
                public static func toggleDialogPin(flags: Int32, peer: Api.InputDialogPeer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1489903017)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    return (FunctionDescription(name: "messages.toggleDialogPin", parameters: [("flags", flags), ("peer", peer)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func getPeerDialogs(peers: [Api.InputDialogPeer]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.PeerDialogs>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-462373635)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(peers.count))
                    for item in peers {
                        item.serialize(buffer, true)
                    }
                    return (FunctionDescription(name: "messages.getPeerDialogs", parameters: [("peers", peers)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.PeerDialogs? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.PeerDialogs?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.PeerDialogs
                        }
                        return result
                    })
                }
            
                public static func searchStickerSets(flags: Int32, q: String, hash: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.FoundStickerSets>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1028140917)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(q, buffer: buffer, boxed: false)
                    serializeInt32(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.searchStickerSets", parameters: [("flags", flags), ("q", q), ("hash", hash)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.FoundStickerSets? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.FoundStickerSets?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.FoundStickerSets
                        }
                        return result
                    })
                }
            
                public static func getStickers(emoticon: String, hash: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.Stickers>) {
                    let buffer = Buffer()
                    buffer.appendInt32(71126828)
                    serializeString(emoticon, buffer: buffer, boxed: false)
                    serializeInt32(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.getStickers", parameters: [("emoticon", emoticon), ("hash", hash)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.Stickers? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.Stickers?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.Stickers
                        }
                        return result
                    })
                }
            
                public static func markDialogUnread(flags: Int32, peer: Api.InputDialogPeer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1031349873)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    return (FunctionDescription(name: "messages.markDialogUnread", parameters: [("flags", flags), ("peer", peer)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func getDialogUnreadMarks() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Api.DialogPeer]>) {
                    let buffer = Buffer()
                    buffer.appendInt32(585256482)
                    
                    return (FunctionDescription(name: "messages.getDialogUnreadMarks", parameters: []), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> [Api.DialogPeer]? in
                        let reader = BufferReader(buffer)
                        var result: [Api.DialogPeer]?
                        if let _ = reader.readInt32() {
                            result = Api.parseVector(reader, elementSignature: 0, elementType: Api.DialogPeer.self)
                        }
                        return result
                    })
                }
            
                public static func updatePinnedMessage(flags: Int32, peer: Api.InputPeer, id: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-760547348)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    serializeInt32(id, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.updatePinnedMessage", parameters: [("flags", flags), ("peer", peer), ("id", id)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
            
                public static func sendVote(peer: Api.InputPeer, msgId: Int32, options: [Buffer]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(283795844)
                    peer.serialize(buffer, true)
                    serializeInt32(msgId, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(options.count))
                    for item in options {
                        serializeBytes(item, buffer: buffer, boxed: false)
                    }
                    return (FunctionDescription(name: "messages.sendVote", parameters: [("peer", peer), ("msgId", msgId), ("options", options)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
            
                public static func getPollResults(peer: Api.InputPeer, msgId: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1941660731)
                    peer.serialize(buffer, true)
                    serializeInt32(msgId, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.getPollResults", parameters: [("peer", peer), ("msgId", msgId)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
            
                public static func getOnlines(peer: Api.InputPeer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.ChatOnlines>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1848369232)
                    peer.serialize(buffer, true)
                    return (FunctionDescription(name: "messages.getOnlines", parameters: [("peer", peer)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.ChatOnlines? in
                        let reader = BufferReader(buffer)
                        var result: Api.ChatOnlines?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.ChatOnlines
                        }
                        return result
                    })
                }
            
                public static func getStatsURL(flags: Int32, peer: Api.InputPeer, params: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.StatsURL>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-2127811866)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    serializeString(params, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.getStatsURL", parameters: [("flags", flags), ("peer", peer), ("params", params)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.StatsURL? in
                        let reader = BufferReader(buffer)
                        var result: Api.StatsURL?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.StatsURL
                        }
                        return result
                    })
                }
            
                public static func editInlineBotMessage(flags: Int32, id: Api.InputBotInlineMessageID, message: String?, media: Api.InputMedia?, replyMarkup: Api.ReplyMarkup?, entities: [Api.MessageEntity]?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-2091549254)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    id.serialize(buffer, true)
                    if Int(flags) & Int(1 << 11) != 0 {serializeString(message!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 14) != 0 {media!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 2) != 0 {replyMarkup!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 3) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(entities!.count))
                    for item in entities! {
                        item.serialize(buffer, true)
                    }}
                    return (FunctionDescription(name: "messages.editInlineBotMessage", parameters: [("flags", flags), ("id", id), ("message", message), ("media", media), ("replyMarkup", replyMarkup), ("entities", entities)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func editChatAbout(peer: Api.InputPeer, about: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-554301545)
                    peer.serialize(buffer, true)
                    serializeString(about, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.editChatAbout", parameters: [("peer", peer), ("about", about)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func editChatDefaultBannedRights(peer: Api.InputPeer, bannedRights: Api.ChatBannedRights) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1517917375)
                    peer.serialize(buffer, true)
                    bannedRights.serialize(buffer, true)
                    return (FunctionDescription(name: "messages.editChatDefaultBannedRights", parameters: [("peer", peer), ("bannedRights", bannedRights)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
            
                public static func exportChatInvite(peer: Api.InputPeer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.ExportedChatInvite>) {
                    let buffer = Buffer()
                    buffer.appendInt32(234312524)
                    peer.serialize(buffer, true)
                    return (FunctionDescription(name: "messages.exportChatInvite", parameters: [("peer", peer)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.ExportedChatInvite? in
                        let reader = BufferReader(buffer)
                        var result: Api.ExportedChatInvite?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.ExportedChatInvite
                        }
                        return result
                    })
                }
            
                public static func getEmojiKeywords(langCode: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.EmojiKeywordsDifference>) {
                    let buffer = Buffer()
                    buffer.appendInt32(899735650)
                    serializeString(langCode, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.getEmojiKeywords", parameters: [("langCode", langCode)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.EmojiKeywordsDifference? in
                        let reader = BufferReader(buffer)
                        var result: Api.EmojiKeywordsDifference?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.EmojiKeywordsDifference
                        }
                        return result
                    })
                }
            
                public static func getEmojiKeywordsDifference(langCode: String, fromVersion: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.EmojiKeywordsDifference>) {
                    let buffer = Buffer()
                    buffer.appendInt32(352892591)
                    serializeString(langCode, buffer: buffer, boxed: false)
                    serializeInt32(fromVersion, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.getEmojiKeywordsDifference", parameters: [("langCode", langCode), ("fromVersion", fromVersion)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.EmojiKeywordsDifference? in
                        let reader = BufferReader(buffer)
                        var result: Api.EmojiKeywordsDifference?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.EmojiKeywordsDifference
                        }
                        return result
                    })
                }
            
                public static func getEmojiURL(langCode: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.EmojiURL>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-709817306)
                    serializeString(langCode, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.getEmojiURL", parameters: [("langCode", langCode)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.EmojiURL? in
                        let reader = BufferReader(buffer)
                        var result: Api.EmojiURL?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.EmojiURL
                        }
                        return result
                    })
                }
            
                public static func reorderPinnedDialogs(flags: Int32, folderId: Int32, order: [Api.InputDialogPeer]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(991616823)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(folderId, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(order.count))
                    for item in order {
                        item.serialize(buffer, true)
                    }
                    return (FunctionDescription(name: "messages.reorderPinnedDialogs", parameters: [("flags", flags), ("folderId", folderId), ("order", order)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func getPinnedDialogs(folderId: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.PeerDialogs>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-692498958)
                    serializeInt32(folderId, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.getPinnedDialogs", parameters: [("folderId", folderId)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.PeerDialogs? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.PeerDialogs?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.PeerDialogs
                        }
                        return result
                    })
                }
            
                public static func getDialogs(flags: Int32, folderId: Int32?, offsetDate: Int32, offsetId: Int32, offsetPeer: Api.InputPeer, limit: Int32, hash: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.Dialogs>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1594999949)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt32(folderId!, buffer: buffer, boxed: false)}
                    serializeInt32(offsetDate, buffer: buffer, boxed: false)
                    serializeInt32(offsetId, buffer: buffer, boxed: false)
                    offsetPeer.serialize(buffer, true)
                    serializeInt32(limit, buffer: buffer, boxed: false)
                    serializeInt32(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.getDialogs", parameters: [("flags", flags), ("folderId", folderId), ("offsetDate", offsetDate), ("offsetId", offsetId), ("offsetPeer", offsetPeer), ("limit", limit), ("hash", hash)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.Dialogs? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.Dialogs?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.Dialogs
                        }
                        return result
                    })
                }
            
                public static func getSearchCounters(peer: Api.InputPeer, filters: [Api.MessagesFilter]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Api.messages.SearchCounter]>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1932455680)
                    peer.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(filters.count))
                    for item in filters {
                        item.serialize(buffer, true)
                    }
                    return (FunctionDescription(name: "messages.getSearchCounters", parameters: [("peer", peer), ("filters", filters)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> [Api.messages.SearchCounter]? in
                        let reader = BufferReader(buffer)
                        var result: [Api.messages.SearchCounter]?
                        if let _ = reader.readInt32() {
                            result = Api.parseVector(reader, elementSignature: 0, elementType: Api.messages.SearchCounter.self)
                        }
                        return result
                    })
                }
            
                public static func requestUrlAuth(peer: Api.InputPeer, msgId: Int32, buttonId: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.UrlAuthResult>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-482388461)
                    peer.serialize(buffer, true)
                    serializeInt32(msgId, buffer: buffer, boxed: false)
                    serializeInt32(buttonId, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.requestUrlAuth", parameters: [("peer", peer), ("msgId", msgId), ("buttonId", buttonId)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.UrlAuthResult? in
                        let reader = BufferReader(buffer)
                        var result: Api.UrlAuthResult?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.UrlAuthResult
                        }
                        return result
                    })
                }
            
                public static func acceptUrlAuth(flags: Int32, peer: Api.InputPeer, msgId: Int32, buttonId: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.UrlAuthResult>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-148247912)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    serializeInt32(msgId, buffer: buffer, boxed: false)
                    serializeInt32(buttonId, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.acceptUrlAuth", parameters: [("flags", flags), ("peer", peer), ("msgId", msgId), ("buttonId", buttonId)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.UrlAuthResult? in
                        let reader = BufferReader(buffer)
                        var result: Api.UrlAuthResult?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.UrlAuthResult
                        }
                        return result
                    })
                }
            
                public static func hidePeerSettingsBar(peer: Api.InputPeer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1336717624)
                    peer.serialize(buffer, true)
                    return (FunctionDescription(name: "messages.hidePeerSettingsBar", parameters: [("peer", peer)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func searchGlobal(flags: Int32, folderId: Int32?, q: String, offsetRate: Int32, offsetPeer: Api.InputPeer, offsetId: Int32, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.Messages>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1083038300)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(folderId!, buffer: buffer, boxed: false)}
                    serializeString(q, buffer: buffer, boxed: false)
                    serializeInt32(offsetRate, buffer: buffer, boxed: false)
                    offsetPeer.serialize(buffer, true)
                    serializeInt32(offsetId, buffer: buffer, boxed: false)
                    serializeInt32(limit, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.searchGlobal", parameters: [("flags", flags), ("folderId", folderId), ("q", q), ("offsetRate", offsetRate), ("offsetPeer", offsetPeer), ("offsetId", offsetId), ("limit", limit)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.Messages? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.Messages?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.Messages
                        }
                        return result
                    })
                }
            
                public static func sendMessage(flags: Int32, peer: Api.InputPeer, replyToMsgId: Int32?, message: String, randomId: Int64, replyMarkup: Api.ReplyMarkup?, entities: [Api.MessageEntity]?, scheduleDate: Int32?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1376532592)
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
                    if Int(flags) & Int(1 << 10) != 0 {serializeInt32(scheduleDate!, buffer: buffer, boxed: false)}
                    return (FunctionDescription(name: "messages.sendMessage", parameters: [("flags", flags), ("peer", peer), ("replyToMsgId", replyToMsgId), ("message", message), ("randomId", randomId), ("replyMarkup", replyMarkup), ("entities", entities), ("scheduleDate", scheduleDate)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
            
                public static func sendMedia(flags: Int32, peer: Api.InputPeer, replyToMsgId: Int32?, media: Api.InputMedia, message: String, randomId: Int64, replyMarkup: Api.ReplyMarkup?, entities: [Api.MessageEntity]?, scheduleDate: Int32?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(881978281)
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
                    if Int(flags) & Int(1 << 10) != 0 {serializeInt32(scheduleDate!, buffer: buffer, boxed: false)}
                    return (FunctionDescription(name: "messages.sendMedia", parameters: [("flags", flags), ("peer", peer), ("replyToMsgId", replyToMsgId), ("media", media), ("message", message), ("randomId", randomId), ("replyMarkup", replyMarkup), ("entities", entities), ("scheduleDate", scheduleDate)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
            
                public static func sendInlineBotResult(flags: Int32, peer: Api.InputPeer, replyToMsgId: Int32?, randomId: Int64, queryId: Int64, id: String, scheduleDate: Int32?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(570955184)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(replyToMsgId!, buffer: buffer, boxed: false)}
                    serializeInt64(randomId, buffer: buffer, boxed: false)
                    serializeInt64(queryId, buffer: buffer, boxed: false)
                    serializeString(id, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 10) != 0 {serializeInt32(scheduleDate!, buffer: buffer, boxed: false)}
                    return (FunctionDescription(name: "messages.sendInlineBotResult", parameters: [("flags", flags), ("peer", peer), ("replyToMsgId", replyToMsgId), ("randomId", randomId), ("queryId", queryId), ("id", id), ("scheduleDate", scheduleDate)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
            
                public static func sendMultiMedia(flags: Int32, peer: Api.InputPeer, replyToMsgId: Int32?, multiMedia: [Api.InputSingleMedia], scheduleDate: Int32?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-872345397)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(replyToMsgId!, buffer: buffer, boxed: false)}
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(multiMedia.count))
                    for item in multiMedia {
                        item.serialize(buffer, true)
                    }
                    if Int(flags) & Int(1 << 10) != 0 {serializeInt32(scheduleDate!, buffer: buffer, boxed: false)}
                    return (FunctionDescription(name: "messages.sendMultiMedia", parameters: [("flags", flags), ("peer", peer), ("replyToMsgId", replyToMsgId), ("multiMedia", multiMedia), ("scheduleDate", scheduleDate)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
            
                public static func forwardMessages(flags: Int32, fromPeer: Api.InputPeer, id: [Int32], randomId: [Int64], toPeer: Api.InputPeer, scheduleDate: Int32?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-637606386)
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
                    if Int(flags) & Int(1 << 10) != 0 {serializeInt32(scheduleDate!, buffer: buffer, boxed: false)}
                    return (FunctionDescription(name: "messages.forwardMessages", parameters: [("flags", flags), ("fromPeer", fromPeer), ("id", id), ("randomId", randomId), ("toPeer", toPeer), ("scheduleDate", scheduleDate)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
            
                public static func getScheduledHistory(peer: Api.InputPeer, hash: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.Messages>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-490575781)
                    peer.serialize(buffer, true)
                    serializeInt32(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.getScheduledHistory", parameters: [("peer", peer), ("hash", hash)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.Messages? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.Messages?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.Messages
                        }
                        return result
                    })
                }
            
                public static func getScheduledMessages(peer: Api.InputPeer, id: [Int32]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.Messages>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1111817116)
                    peer.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(id.count))
                    for item in id {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    return (FunctionDescription(name: "messages.getScheduledMessages", parameters: [("peer", peer), ("id", id)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.Messages? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.Messages?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.Messages
                        }
                        return result
                    })
                }
            
                public static func sendScheduledMessages(peer: Api.InputPeer, id: [Int32]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1120369398)
                    peer.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(id.count))
                    for item in id {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    return (FunctionDescription(name: "messages.sendScheduledMessages", parameters: [("peer", peer), ("id", id)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
            
                public static func deleteScheduledMessages(peer: Api.InputPeer, id: [Int32]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1504586518)
                    peer.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(id.count))
                    for item in id {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    return (FunctionDescription(name: "messages.deleteScheduledMessages", parameters: [("peer", peer), ("id", id)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
            
                public static func editMessage(flags: Int32, peer: Api.InputPeer, id: Int32, message: String?, media: Api.InputMedia?, replyMarkup: Api.ReplyMarkup?, entities: [Api.MessageEntity]?, scheduleDate: Int32?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1224152952)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    serializeInt32(id, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 11) != 0 {serializeString(message!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 14) != 0 {media!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 2) != 0 {replyMarkup!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 3) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(entities!.count))
                    for item in entities! {
                        item.serialize(buffer, true)
                    }}
                    if Int(flags) & Int(1 << 15) != 0 {serializeInt32(scheduleDate!, buffer: buffer, boxed: false)}
                    return (FunctionDescription(name: "messages.editMessage", parameters: [("flags", flags), ("peer", peer), ("id", id), ("message", message), ("media", media), ("replyMarkup", replyMarkup), ("entities", entities), ("scheduleDate", scheduleDate)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
            
                public static func getPollVotes(flags: Int32, peer: Api.InputPeer, id: Int32, option: Buffer?, offset: String?, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.VotesList>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1200736242)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    serializeInt32(id, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeBytes(option!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(offset!, buffer: buffer, boxed: false)}
                    serializeInt32(limit, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.getPollVotes", parameters: [("flags", flags), ("peer", peer), ("id", id), ("option", option), ("offset", offset), ("limit", limit)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.VotesList? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.VotesList?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.VotesList
                        }
                        return result
                    })
                }
            }
            public struct channels {
                public static func readHistory(channel: Api.InputChannel, maxId: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-871347913)
                    channel.serialize(buffer, true)
                    serializeInt32(maxId, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "channels.readHistory", parameters: [("channel", channel), ("maxId", maxId)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func deleteMessages(channel: Api.InputChannel, id: [Int32]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.AffectedMessages>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-2067661490)
                    channel.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(id.count))
                    for item in id {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    return (FunctionDescription(name: "channels.deleteMessages", parameters: [("channel", channel), ("id", id)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.AffectedMessages? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.AffectedMessages?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.AffectedMessages
                        }
                        return result
                    })
                }
            
                public static func deleteUserHistory(channel: Api.InputChannel, userId: Api.InputUser) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.AffectedHistory>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-787622117)
                    channel.serialize(buffer, true)
                    userId.serialize(buffer, true)
                    return (FunctionDescription(name: "channels.deleteUserHistory", parameters: [("channel", channel), ("userId", userId)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.AffectedHistory? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.AffectedHistory?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.AffectedHistory
                        }
                        return result
                    })
                }
            
                public static func reportSpam(channel: Api.InputChannel, userId: Api.InputUser, id: [Int32]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-32999408)
                    channel.serialize(buffer, true)
                    userId.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(id.count))
                    for item in id {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    return (FunctionDescription(name: "channels.reportSpam", parameters: [("channel", channel), ("userId", userId), ("id", id)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func getParticipant(channel: Api.InputChannel, userId: Api.InputUser) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.channels.ChannelParticipant>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1416484774)
                    channel.serialize(buffer, true)
                    userId.serialize(buffer, true)
                    return (FunctionDescription(name: "channels.getParticipant", parameters: [("channel", channel), ("userId", userId)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.channels.ChannelParticipant? in
                        let reader = BufferReader(buffer)
                        var result: Api.channels.ChannelParticipant?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.channels.ChannelParticipant
                        }
                        return result
                    })
                }
            
                public static func getChannels(id: [Api.InputChannel]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.Chats>) {
                    let buffer = Buffer()
                    buffer.appendInt32(176122811)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(id.count))
                    for item in id {
                        item.serialize(buffer, true)
                    }
                    return (FunctionDescription(name: "channels.getChannels", parameters: [("id", id)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.Chats? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.Chats?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.Chats
                        }
                        return result
                    })
                }
            
                public static func getFullChannel(channel: Api.InputChannel) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.ChatFull>) {
                    let buffer = Buffer()
                    buffer.appendInt32(141781513)
                    channel.serialize(buffer, true)
                    return (FunctionDescription(name: "channels.getFullChannel", parameters: [("channel", channel)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.ChatFull? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.ChatFull?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.ChatFull
                        }
                        return result
                    })
                }
            
                public static func editTitle(channel: Api.InputChannel, title: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1450044624)
                    channel.serialize(buffer, true)
                    serializeString(title, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "channels.editTitle", parameters: [("channel", channel), ("title", title)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
            
                public static func editPhoto(channel: Api.InputChannel, photo: Api.InputChatPhoto) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-248621111)
                    channel.serialize(buffer, true)
                    photo.serialize(buffer, true)
                    return (FunctionDescription(name: "channels.editPhoto", parameters: [("channel", channel), ("photo", photo)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
            
                public static func checkUsername(channel: Api.InputChannel, username: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(283557164)
                    channel.serialize(buffer, true)
                    serializeString(username, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "channels.checkUsername", parameters: [("channel", channel), ("username", username)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func updateUsername(channel: Api.InputChannel, username: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(890549214)
                    channel.serialize(buffer, true)
                    serializeString(username, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "channels.updateUsername", parameters: [("channel", channel), ("username", username)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func joinChannel(channel: Api.InputChannel) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(615851205)
                    channel.serialize(buffer, true)
                    return (FunctionDescription(name: "channels.joinChannel", parameters: [("channel", channel)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
            
                public static func leaveChannel(channel: Api.InputChannel) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-130635115)
                    channel.serialize(buffer, true)
                    return (FunctionDescription(name: "channels.leaveChannel", parameters: [("channel", channel)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
            
                public static func inviteToChannel(channel: Api.InputChannel, users: [Api.InputUser]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(429865580)
                    channel.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    return (FunctionDescription(name: "channels.inviteToChannel", parameters: [("channel", channel), ("users", users)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
            
                public static func kickFromChannel(channel: Api.InputChannel, userId: Api.InputUser, kicked: Api.Bool) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1502421484)
                    channel.serialize(buffer, true)
                    userId.serialize(buffer, true)
                    kicked.serialize(buffer, true)
                    return (FunctionDescription(name: "channels.kickFromChannel", parameters: [("channel", channel), ("userId", userId), ("kicked", kicked)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
            
                public static func deleteChannel(channel: Api.InputChannel) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1072619549)
                    channel.serialize(buffer, true)
                    return (FunctionDescription(name: "channels.deleteChannel", parameters: [("channel", channel)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
            
                public static func toggleSignatures(channel: Api.InputChannel, enabled: Api.Bool) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(527021574)
                    channel.serialize(buffer, true)
                    enabled.serialize(buffer, true)
                    return (FunctionDescription(name: "channels.toggleSignatures", parameters: [("channel", channel), ("enabled", enabled)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
            
                public static func getAdminLog(flags: Int32, channel: Api.InputChannel, q: String, eventsFilter: Api.ChannelAdminLogEventsFilter?, admins: [Api.InputUser]?, maxId: Int64, minId: Int64, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.channels.AdminLogResults>) {
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
                    return (FunctionDescription(name: "channels.getAdminLog", parameters: [("flags", flags), ("channel", channel), ("q", q), ("eventsFilter", eventsFilter), ("admins", admins), ("maxId", maxId), ("minId", minId), ("limit", limit)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.channels.AdminLogResults? in
                        let reader = BufferReader(buffer)
                        var result: Api.channels.AdminLogResults?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.channels.AdminLogResults
                        }
                        return result
                    })
                }
            
                public static func setStickers(channel: Api.InputChannel, stickerset: Api.InputStickerSet) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-359881479)
                    channel.serialize(buffer, true)
                    stickerset.serialize(buffer, true)
                    return (FunctionDescription(name: "channels.setStickers", parameters: [("channel", channel), ("stickerset", stickerset)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func readMessageContents(channel: Api.InputChannel, id: [Int32]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-357180360)
                    channel.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(id.count))
                    for item in id {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    return (FunctionDescription(name: "channels.readMessageContents", parameters: [("channel", channel), ("id", id)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func deleteHistory(channel: Api.InputChannel, maxId: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1355375294)
                    channel.serialize(buffer, true)
                    serializeInt32(maxId, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "channels.deleteHistory", parameters: [("channel", channel), ("maxId", maxId)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func togglePreHistoryHidden(channel: Api.InputChannel, enabled: Api.Bool) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-356796084)
                    channel.serialize(buffer, true)
                    enabled.serialize(buffer, true)
                    return (FunctionDescription(name: "channels.togglePreHistoryHidden", parameters: [("channel", channel), ("enabled", enabled)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
            
                public static func getParticipants(channel: Api.InputChannel, filter: Api.ChannelParticipantsFilter, offset: Int32, limit: Int32, hash: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.channels.ChannelParticipants>) {
                    let buffer = Buffer()
                    buffer.appendInt32(306054633)
                    channel.serialize(buffer, true)
                    filter.serialize(buffer, true)
                    serializeInt32(offset, buffer: buffer, boxed: false)
                    serializeInt32(limit, buffer: buffer, boxed: false)
                    serializeInt32(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "channels.getParticipants", parameters: [("channel", channel), ("filter", filter), ("offset", offset), ("limit", limit), ("hash", hash)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.channels.ChannelParticipants? in
                        let reader = BufferReader(buffer)
                        var result: Api.channels.ChannelParticipants?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.channels.ChannelParticipants
                        }
                        return result
                    })
                }
            
                public static func exportMessageLink(channel: Api.InputChannel, id: Int32, grouped: Api.Bool) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.ExportedMessageLink>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-826838685)
                    channel.serialize(buffer, true)
                    serializeInt32(id, buffer: buffer, boxed: false)
                    grouped.serialize(buffer, true)
                    return (FunctionDescription(name: "channels.exportMessageLink", parameters: [("channel", channel), ("id", id), ("grouped", grouped)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.ExportedMessageLink? in
                        let reader = BufferReader(buffer)
                        var result: Api.ExportedMessageLink?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.ExportedMessageLink
                        }
                        return result
                    })
                }
            
                public static func getMessages(channel: Api.InputChannel, id: [Api.InputMessage]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.Messages>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1383294429)
                    channel.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(id.count))
                    for item in id {
                        item.serialize(buffer, true)
                    }
                    return (FunctionDescription(name: "channels.getMessages", parameters: [("channel", channel), ("id", id)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.Messages? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.Messages?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.Messages
                        }
                        return result
                    })
                }
            
                public static func editBanned(channel: Api.InputChannel, userId: Api.InputUser, bannedRights: Api.ChatBannedRights) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1920559378)
                    channel.serialize(buffer, true)
                    userId.serialize(buffer, true)
                    bannedRights.serialize(buffer, true)
                    return (FunctionDescription(name: "channels.editBanned", parameters: [("channel", channel), ("userId", userId), ("bannedRights", bannedRights)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
            
                public static func getGroupsForDiscussion() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.Chats>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-170208392)
                    
                    return (FunctionDescription(name: "channels.getGroupsForDiscussion", parameters: []), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.Chats? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.Chats?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.Chats
                        }
                        return result
                    })
                }
            
                public static func getBroadcastsForDiscussion() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.Chats>) {
                    let buffer = Buffer()
                    buffer.appendInt32(445117188)
                    
                    return (FunctionDescription(name: "channels.getBroadcastsForDiscussion", parameters: []), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.Chats? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.Chats?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.Chats
                        }
                        return result
                    })
                }
            
                public static func setDiscussionGroup(broadcast: Api.InputChannel, group: Api.InputChannel) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1079520178)
                    broadcast.serialize(buffer, true)
                    group.serialize(buffer, true)
                    return (FunctionDescription(name: "channels.setDiscussionGroup", parameters: [("broadcast", broadcast), ("group", group)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func editCreator(channel: Api.InputChannel, userId: Api.InputUser, password: Api.InputCheckPasswordSRP) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1892102881)
                    channel.serialize(buffer, true)
                    userId.serialize(buffer, true)
                    password.serialize(buffer, true)
                    return (FunctionDescription(name: "channels.editCreator", parameters: [("channel", channel), ("userId", userId), ("password", password)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
            
                public static func editLocation(channel: Api.InputChannel, geoPoint: Api.InputGeoPoint, address: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1491484525)
                    channel.serialize(buffer, true)
                    geoPoint.serialize(buffer, true)
                    serializeString(address, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "channels.editLocation", parameters: [("channel", channel), ("geoPoint", geoPoint), ("address", address)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func createChannel(flags: Int32, title: String, about: String, geoPoint: Api.InputGeoPoint?, address: String?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1029681423)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(title, buffer: buffer, boxed: false)
                    serializeString(about, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 2) != 0 {geoPoint!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeString(address!, buffer: buffer, boxed: false)}
                    return (FunctionDescription(name: "channels.createChannel", parameters: [("flags", flags), ("title", title), ("about", about), ("geoPoint", geoPoint), ("address", address)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
            
                public static func getAdminedPublicChannels(flags: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.Chats>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-122669393)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "channels.getAdminedPublicChannels", parameters: [("flags", flags)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.Chats? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.Chats?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.Chats
                        }
                        return result
                    })
                }
            
                public static func toggleSlowMode(channel: Api.InputChannel, seconds: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-304832784)
                    channel.serialize(buffer, true)
                    serializeInt32(seconds, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "channels.toggleSlowMode", parameters: [("channel", channel), ("seconds", seconds)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
            
                public static func editAdmin(channel: Api.InputChannel, userId: Api.InputUser, adminRights: Api.ChatAdminRights, rank: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-751007486)
                    channel.serialize(buffer, true)
                    userId.serialize(buffer, true)
                    adminRights.serialize(buffer, true)
                    serializeString(rank, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "channels.editAdmin", parameters: [("channel", channel), ("userId", userId), ("adminRights", adminRights), ("rank", rank)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
            
                public static func getInactiveChannels() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.InactiveChats>) {
                    let buffer = Buffer()
                    buffer.appendInt32(300429806)
                    
                    return (FunctionDescription(name: "channels.getInactiveChannels", parameters: []), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.InactiveChats? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.InactiveChats?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.InactiveChats
                        }
                        return result
                    })
                }
            }
            public struct payments {
                public static func getPaymentForm(msgId: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.payments.PaymentForm>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1712285883)
                    serializeInt32(msgId, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "payments.getPaymentForm", parameters: [("msgId", msgId)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.payments.PaymentForm? in
                        let reader = BufferReader(buffer)
                        var result: Api.payments.PaymentForm?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.payments.PaymentForm
                        }
                        return result
                    })
                }
            
                public static func getPaymentReceipt(msgId: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.payments.PaymentReceipt>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1601001088)
                    serializeInt32(msgId, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "payments.getPaymentReceipt", parameters: [("msgId", msgId)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.payments.PaymentReceipt? in
                        let reader = BufferReader(buffer)
                        var result: Api.payments.PaymentReceipt?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.payments.PaymentReceipt
                        }
                        return result
                    })
                }
            
                public static func validateRequestedInfo(flags: Int32, msgId: Int32, info: Api.PaymentRequestedInfo) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.payments.ValidatedRequestedInfo>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1997180532)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(msgId, buffer: buffer, boxed: false)
                    info.serialize(buffer, true)
                    return (FunctionDescription(name: "payments.validateRequestedInfo", parameters: [("flags", flags), ("msgId", msgId), ("info", info)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.payments.ValidatedRequestedInfo? in
                        let reader = BufferReader(buffer)
                        var result: Api.payments.ValidatedRequestedInfo?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.payments.ValidatedRequestedInfo
                        }
                        return result
                    })
                }
            
                public static func sendPaymentForm(flags: Int32, msgId: Int32, requestedInfoId: String?, shippingOptionId: String?, credentials: Api.InputPaymentCredentials) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.payments.PaymentResult>) {
                    let buffer = Buffer()
                    buffer.appendInt32(730364339)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(msgId, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(requestedInfoId!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(shippingOptionId!, buffer: buffer, boxed: false)}
                    credentials.serialize(buffer, true)
                    return (FunctionDescription(name: "payments.sendPaymentForm", parameters: [("flags", flags), ("msgId", msgId), ("requestedInfoId", requestedInfoId), ("shippingOptionId", shippingOptionId), ("credentials", credentials)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.payments.PaymentResult? in
                        let reader = BufferReader(buffer)
                        var result: Api.payments.PaymentResult?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.payments.PaymentResult
                        }
                        return result
                    })
                }
            
                public static func getSavedInfo() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.payments.SavedInfo>) {
                    let buffer = Buffer()
                    buffer.appendInt32(578650699)
                    
                    return (FunctionDescription(name: "payments.getSavedInfo", parameters: []), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.payments.SavedInfo? in
                        let reader = BufferReader(buffer)
                        var result: Api.payments.SavedInfo?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.payments.SavedInfo
                        }
                        return result
                    })
                }
            
                public static func clearSavedInfo(flags: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-667062079)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "payments.clearSavedInfo", parameters: [("flags", flags)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func getBankCardData(number: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.payments.BankCardData>) {
                    let buffer = Buffer()
                    buffer.appendInt32(779736953)
                    serializeString(number, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "payments.getBankCardData", parameters: [("number", number)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.payments.BankCardData? in
                        let reader = BufferReader(buffer)
                        var result: Api.payments.BankCardData?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.payments.BankCardData
                        }
                        return result
                    })
                }
            }
            public struct auth {
                public static func checkPhone(phoneNumber: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.auth.CheckedPhone>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1877286395)
                    serializeString(phoneNumber, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "auth.checkPhone", parameters: [("phoneNumber", phoneNumber)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.auth.CheckedPhone? in
                        let reader = BufferReader(buffer)
                        var result: Api.auth.CheckedPhone?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.auth.CheckedPhone
                        }
                        return result
                    })
                }
            
                public static func sendCode(flags: Int32, phoneNumber: String, currentNumber: Api.Bool?, apiId: Int32, apiHash: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.auth.SentCode>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-2035355412)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(phoneNumber, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {currentNumber!.serialize(buffer, true)}
                    serializeInt32(apiId, buffer: buffer, boxed: false)
                    serializeString(apiHash, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "auth.sendCode", parameters: [("flags", flags), ("phoneNumber", phoneNumber), ("currentNumber", currentNumber), ("apiId", apiId), ("apiHash", apiHash)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.auth.SentCode? in
                        let reader = BufferReader(buffer)
                        var result: Api.auth.SentCode?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.auth.SentCode
                        }
                        return result
                    })
                }
            
                public static func signIn(phoneNumber: String, phoneCodeHash: String, phoneCode: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.auth.Authorization>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1126886015)
                    serializeString(phoneNumber, buffer: buffer, boxed: false)
                    serializeString(phoneCodeHash, buffer: buffer, boxed: false)
                    serializeString(phoneCode, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "auth.signIn", parameters: [("phoneNumber", phoneNumber), ("phoneCodeHash", phoneCodeHash), ("phoneCode", phoneCode)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.auth.Authorization? in
                        let reader = BufferReader(buffer)
                        var result: Api.auth.Authorization?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.auth.Authorization
                        }
                        return result
                    })
                }
            
                public static func logOut() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1461180992)
                    
                    return (FunctionDescription(name: "auth.logOut", parameters: []), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func resetAuthorizations() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1616179942)
                    
                    return (FunctionDescription(name: "auth.resetAuthorizations", parameters: []), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func sendInvites(phoneNumbers: [String], message: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1998331287)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(phoneNumbers.count))
                    for item in phoneNumbers {
                        serializeString(item, buffer: buffer, boxed: false)
                    }
                    serializeString(message, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "auth.sendInvites", parameters: [("phoneNumbers", phoneNumbers), ("message", message)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func exportAuthorization(dcId: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.auth.ExportedAuthorization>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-440401971)
                    serializeInt32(dcId, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "auth.exportAuthorization", parameters: [("dcId", dcId)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.auth.ExportedAuthorization? in
                        let reader = BufferReader(buffer)
                        var result: Api.auth.ExportedAuthorization?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.auth.ExportedAuthorization
                        }
                        return result
                    })
                }
            
                public static func importAuthorization(id: Int32, bytes: Buffer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.auth.Authorization>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-470837741)
                    serializeInt32(id, buffer: buffer, boxed: false)
                    serializeBytes(bytes, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "auth.importAuthorization", parameters: [("id", id), ("bytes", bytes)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.auth.Authorization? in
                        let reader = BufferReader(buffer)
                        var result: Api.auth.Authorization?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.auth.Authorization
                        }
                        return result
                    })
                }
            
                public static func bindTempAuthKey(permAuthKeyId: Int64, nonce: Int64, expiresAt: Int32, encryptedMessage: Buffer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-841733627)
                    serializeInt64(permAuthKeyId, buffer: buffer, boxed: false)
                    serializeInt64(nonce, buffer: buffer, boxed: false)
                    serializeInt32(expiresAt, buffer: buffer, boxed: false)
                    serializeBytes(encryptedMessage, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "auth.bindTempAuthKey", parameters: [("permAuthKeyId", permAuthKeyId), ("nonce", nonce), ("expiresAt", expiresAt), ("encryptedMessage", encryptedMessage)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func importBotAuthorization(flags: Int32, apiId: Int32, apiHash: String, botAuthToken: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.auth.Authorization>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1738800940)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(apiId, buffer: buffer, boxed: false)
                    serializeString(apiHash, buffer: buffer, boxed: false)
                    serializeString(botAuthToken, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "auth.importBotAuthorization", parameters: [("flags", flags), ("apiId", apiId), ("apiHash", apiHash), ("botAuthToken", botAuthToken)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.auth.Authorization? in
                        let reader = BufferReader(buffer)
                        var result: Api.auth.Authorization?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.auth.Authorization
                        }
                        return result
                    })
                }
            
                public static func requestPasswordRecovery() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.auth.PasswordRecovery>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-661144474)
                    
                    return (FunctionDescription(name: "auth.requestPasswordRecovery", parameters: []), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.auth.PasswordRecovery? in
                        let reader = BufferReader(buffer)
                        var result: Api.auth.PasswordRecovery?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.auth.PasswordRecovery
                        }
                        return result
                    })
                }
            
                public static func recoverPassword(code: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.auth.Authorization>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1319464594)
                    serializeString(code, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "auth.recoverPassword", parameters: [("code", code)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.auth.Authorization? in
                        let reader = BufferReader(buffer)
                        var result: Api.auth.Authorization?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.auth.Authorization
                        }
                        return result
                    })
                }
            
                public static func resendCode(phoneNumber: String, phoneCodeHash: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.auth.SentCode>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1056025023)
                    serializeString(phoneNumber, buffer: buffer, boxed: false)
                    serializeString(phoneCodeHash, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "auth.resendCode", parameters: [("phoneNumber", phoneNumber), ("phoneCodeHash", phoneCodeHash)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.auth.SentCode? in
                        let reader = BufferReader(buffer)
                        var result: Api.auth.SentCode?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.auth.SentCode
                        }
                        return result
                    })
                }
            
                public static func cancelCode(phoneNumber: String, phoneCodeHash: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(520357240)
                    serializeString(phoneNumber, buffer: buffer, boxed: false)
                    serializeString(phoneCodeHash, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "auth.cancelCode", parameters: [("phoneNumber", phoneNumber), ("phoneCodeHash", phoneCodeHash)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func dropTempAuthKeys(exceptAuthKeys: [Int64]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1907842680)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(exceptAuthKeys.count))
                    for item in exceptAuthKeys {
                        serializeInt64(item, buffer: buffer, boxed: false)
                    }
                    return (FunctionDescription(name: "auth.dropTempAuthKeys", parameters: [("exceptAuthKeys", exceptAuthKeys)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func checkPassword(password: Api.InputCheckPasswordSRP) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.auth.Authorization>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-779399914)
                    password.serialize(buffer, true)
                    return (FunctionDescription(name: "auth.checkPassword", parameters: [("password", password)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.auth.Authorization? in
                        let reader = BufferReader(buffer)
                        var result: Api.auth.Authorization?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.auth.Authorization
                        }
                        return result
                    })
                }
            
                public static func signUp(phoneNumber: String, phoneCodeHash: String, firstName: String, lastName: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.auth.Authorization>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-2131827673)
                    serializeString(phoneNumber, buffer: buffer, boxed: false)
                    serializeString(phoneCodeHash, buffer: buffer, boxed: false)
                    serializeString(firstName, buffer: buffer, boxed: false)
                    serializeString(lastName, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "auth.signUp", parameters: [("phoneNumber", phoneNumber), ("phoneCodeHash", phoneCodeHash), ("firstName", firstName), ("lastName", lastName)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.auth.Authorization? in
                        let reader = BufferReader(buffer)
                        var result: Api.auth.Authorization?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.auth.Authorization
                        }
                        return result
                    })
                }
            
                public static func exportLoginToken(apiId: Int32, apiHash: String, exceptIds: [Int32]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.auth.LoginToken>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1313598185)
                    serializeInt32(apiId, buffer: buffer, boxed: false)
                    serializeString(apiHash, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(exceptIds.count))
                    for item in exceptIds {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    return (FunctionDescription(name: "auth.exportLoginToken", parameters: [("apiId", apiId), ("apiHash", apiHash), ("exceptIds", exceptIds)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.auth.LoginToken? in
                        let reader = BufferReader(buffer)
                        var result: Api.auth.LoginToken?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.auth.LoginToken
                        }
                        return result
                    })
                }
            
                public static func importLoginToken(token: Buffer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.auth.LoginToken>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1783866140)
                    serializeBytes(token, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "auth.importLoginToken", parameters: [("token", token)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.auth.LoginToken? in
                        let reader = BufferReader(buffer)
                        var result: Api.auth.LoginToken?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.auth.LoginToken
                        }
                        return result
                    })
                }
            
                public static func acceptLoginToken(token: Buffer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Authorization>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-392909491)
                    serializeBytes(token, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "auth.acceptLoginToken", parameters: [("token", token)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Authorization? in
                        let reader = BufferReader(buffer)
                        var result: Api.Authorization?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Authorization
                        }
                        return result
                    })
                }
            }
            public struct bots {
                public static func sendCustomRequest(customMethod: String, params: Api.DataJSON) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.DataJSON>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1440257555)
                    serializeString(customMethod, buffer: buffer, boxed: false)
                    params.serialize(buffer, true)
                    return (FunctionDescription(name: "bots.sendCustomRequest", parameters: [("customMethod", customMethod), ("params", params)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.DataJSON? in
                        let reader = BufferReader(buffer)
                        var result: Api.DataJSON?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.DataJSON
                        }
                        return result
                    })
                }
            
                public static func answerWebhookJSONQuery(queryId: Int64, data: Api.DataJSON) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-434028723)
                    serializeInt64(queryId, buffer: buffer, boxed: false)
                    data.serialize(buffer, true)
                    return (FunctionDescription(name: "bots.answerWebhookJSONQuery", parameters: [("queryId", queryId), ("data", data)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
                public static func getUsers(id: [Api.InputUser]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Api.User]>) {
                    let buffer = Buffer()
                    buffer.appendInt32(227648840)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(id.count))
                    for item in id {
                        item.serialize(buffer, true)
                    }
                    return (FunctionDescription(name: "users.getUsers", parameters: [("id", id)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> [Api.User]? in
                        let reader = BufferReader(buffer)
                        var result: [Api.User]?
                        if let _ = reader.readInt32() {
                            result = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
                        }
                        return result
                    })
                }
            
                public static func setSecureValueErrors(id: Api.InputUser, errors: [Api.SecureValueError]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1865902923)
                    id.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(errors.count))
                    for item in errors {
                        item.serialize(buffer, true)
                    }
                    return (FunctionDescription(name: "users.setSecureValueErrors", parameters: [("id", id), ("errors", errors)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func getFullUser(id: Api.InputUser) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.UserFull>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-902781519)
                    id.serialize(buffer, true)
                    return (FunctionDescription(name: "users.getFullUser", parameters: [("id", id)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.UserFull? in
                        let reader = BufferReader(buffer)
                        var result: Api.UserFull?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.UserFull
                        }
                        return result
                    })
                }
            }
            public struct contacts {
                public static func getStatuses() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Api.ContactStatus]>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-995929106)
                    
                    return (FunctionDescription(name: "contacts.getStatuses", parameters: []), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> [Api.ContactStatus]? in
                        let reader = BufferReader(buffer)
                        var result: [Api.ContactStatus]?
                        if let _ = reader.readInt32() {
                            result = Api.parseVector(reader, elementSignature: 0, elementType: Api.ContactStatus.self)
                        }
                        return result
                    })
                }
            
                public static func block(id: Api.InputUser) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(858475004)
                    id.serialize(buffer, true)
                    return (FunctionDescription(name: "contacts.block", parameters: [("id", id)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func unblock(id: Api.InputUser) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-448724803)
                    id.serialize(buffer, true)
                    return (FunctionDescription(name: "contacts.unblock", parameters: [("id", id)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func getBlocked(offset: Int32, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.contacts.Blocked>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-176409329)
                    serializeInt32(offset, buffer: buffer, boxed: false)
                    serializeInt32(limit, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "contacts.getBlocked", parameters: [("offset", offset), ("limit", limit)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.contacts.Blocked? in
                        let reader = BufferReader(buffer)
                        var result: Api.contacts.Blocked?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.contacts.Blocked
                        }
                        return result
                    })
                }
            
                public static func exportCard() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Int32]>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-2065352905)
                    
                    return (FunctionDescription(name: "contacts.exportCard", parameters: []), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> [Int32]? in
                        let reader = BufferReader(buffer)
                        var result: [Int32]?
                        if let _ = reader.readInt32() {
                            result = Api.parseVector(reader, elementSignature: -1471112230, elementType: Int32.self)
                        }
                        return result
                    })
                }
            
                public static func importCard(exportCard: [Int32]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.User>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1340184318)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(exportCard.count))
                    for item in exportCard {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    return (FunctionDescription(name: "contacts.importCard", parameters: [("exportCard", exportCard)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.User? in
                        let reader = BufferReader(buffer)
                        var result: Api.User?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.User
                        }
                        return result
                    })
                }
            
                public static func search(q: String, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.contacts.Found>) {
                    let buffer = Buffer()
                    buffer.appendInt32(301470424)
                    serializeString(q, buffer: buffer, boxed: false)
                    serializeInt32(limit, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "contacts.search", parameters: [("q", q), ("limit", limit)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.contacts.Found? in
                        let reader = BufferReader(buffer)
                        var result: Api.contacts.Found?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.contacts.Found
                        }
                        return result
                    })
                }
            
                public static func resolveUsername(username: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.contacts.ResolvedPeer>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-113456221)
                    serializeString(username, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "contacts.resolveUsername", parameters: [("username", username)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.contacts.ResolvedPeer? in
                        let reader = BufferReader(buffer)
                        var result: Api.contacts.ResolvedPeer?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.contacts.ResolvedPeer
                        }
                        return result
                    })
                }
            
                public static func getTopPeers(flags: Int32, offset: Int32, limit: Int32, hash: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.contacts.TopPeers>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-728224331)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(offset, buffer: buffer, boxed: false)
                    serializeInt32(limit, buffer: buffer, boxed: false)
                    serializeInt32(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "contacts.getTopPeers", parameters: [("flags", flags), ("offset", offset), ("limit", limit), ("hash", hash)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.contacts.TopPeers? in
                        let reader = BufferReader(buffer)
                        var result: Api.contacts.TopPeers?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.contacts.TopPeers
                        }
                        return result
                    })
                }
            
                public static func resetTopPeerRating(category: Api.TopPeerCategory, peer: Api.InputPeer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(451113900)
                    category.serialize(buffer, true)
                    peer.serialize(buffer, true)
                    return (FunctionDescription(name: "contacts.resetTopPeerRating", parameters: [("category", category), ("peer", peer)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func importContacts(contacts: [Api.InputContact]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.contacts.ImportedContacts>) {
                    let buffer = Buffer()
                    buffer.appendInt32(746589157)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(contacts.count))
                    for item in contacts {
                        item.serialize(buffer, true)
                    }
                    return (FunctionDescription(name: "contacts.importContacts", parameters: [("contacts", contacts)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.contacts.ImportedContacts? in
                        let reader = BufferReader(buffer)
                        var result: Api.contacts.ImportedContacts?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.contacts.ImportedContacts
                        }
                        return result
                    })
                }
            
                public static func resetSaved() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-2020263951)
                    
                    return (FunctionDescription(name: "contacts.resetSaved", parameters: []), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func getContacts(hash: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.contacts.Contacts>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1071414113)
                    serializeInt32(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "contacts.getContacts", parameters: [("hash", hash)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.contacts.Contacts? in
                        let reader = BufferReader(buffer)
                        var result: Api.contacts.Contacts?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.contacts.Contacts
                        }
                        return result
                    })
                }
            
                public static func toggleTopPeers(enabled: Api.Bool) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-2062238246)
                    enabled.serialize(buffer, true)
                    return (FunctionDescription(name: "contacts.toggleTopPeers", parameters: [("enabled", enabled)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func getContactIDs(hash: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Int32]>) {
                    let buffer = Buffer()
                    buffer.appendInt32(749357634)
                    serializeInt32(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "contacts.getContactIDs", parameters: [("hash", hash)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> [Int32]? in
                        let reader = BufferReader(buffer)
                        var result: [Int32]?
                        if let _ = reader.readInt32() {
                            result = Api.parseVector(reader, elementSignature: -1471112230, elementType: Int32.self)
                        }
                        return result
                    })
                }
            
                public static func addContact(flags: Int32, id: Api.InputUser, firstName: String, lastName: String, phone: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-386636848)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    id.serialize(buffer, true)
                    serializeString(firstName, buffer: buffer, boxed: false)
                    serializeString(lastName, buffer: buffer, boxed: false)
                    serializeString(phone, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "contacts.addContact", parameters: [("flags", flags), ("id", id), ("firstName", firstName), ("lastName", lastName), ("phone", phone)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
            
                public static func acceptContact(id: Api.InputUser) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-130964977)
                    id.serialize(buffer, true)
                    return (FunctionDescription(name: "contacts.acceptContact", parameters: [("id", id)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
            
                public static func deleteContacts(id: [Api.InputUser]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(157945344)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(id.count))
                    for item in id {
                        item.serialize(buffer, true)
                    }
                    return (FunctionDescription(name: "contacts.deleteContacts", parameters: [("id", id)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
            
                public static func getLocated(flags: Int32, geoPoint: Api.InputGeoPoint, selfExpires: Int32?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-750207932)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    geoPoint.serialize(buffer, true)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(selfExpires!, buffer: buffer, boxed: false)}
                    return (FunctionDescription(name: "contacts.getLocated", parameters: [("flags", flags), ("geoPoint", geoPoint), ("selfExpires", selfExpires)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
            }
            public struct help {
                public static func getConfig() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Config>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-990308245)
                    
                    return (FunctionDescription(name: "help.getConfig", parameters: []), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Config? in
                        let reader = BufferReader(buffer)
                        var result: Api.Config?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Config
                        }
                        return result
                    })
                }
            
                public static func getNearestDc() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.NearestDc>) {
                    let buffer = Buffer()
                    buffer.appendInt32(531836966)
                    
                    return (FunctionDescription(name: "help.getNearestDc", parameters: []), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.NearestDc? in
                        let reader = BufferReader(buffer)
                        var result: Api.NearestDc?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.NearestDc
                        }
                        return result
                    })
                }
            
                public static func getInviteText() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.help.InviteText>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1295590211)
                    
                    return (FunctionDescription(name: "help.getInviteText", parameters: []), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.help.InviteText? in
                        let reader = BufferReader(buffer)
                        var result: Api.help.InviteText?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.help.InviteText
                        }
                        return result
                    })
                }
            
                public static func getSupport() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.help.Support>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1663104819)
                    
                    return (FunctionDescription(name: "help.getSupport", parameters: []), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.help.Support? in
                        let reader = BufferReader(buffer)
                        var result: Api.help.Support?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.help.Support
                        }
                        return result
                    })
                }
            
                public static func getAppChangelog(prevAppVersion: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1877938321)
                    serializeString(prevAppVersion, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "help.getAppChangelog", parameters: [("prevAppVersion", prevAppVersion)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
            
                public static func setBotUpdatesStatus(pendingUpdatesCount: Int32, message: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-333262899)
                    serializeInt32(pendingUpdatesCount, buffer: buffer, boxed: false)
                    serializeString(message, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "help.setBotUpdatesStatus", parameters: [("pendingUpdatesCount", pendingUpdatesCount), ("message", message)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func getCdnConfig() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.CdnConfig>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1375900482)
                    
                    return (FunctionDescription(name: "help.getCdnConfig", parameters: []), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.CdnConfig? in
                        let reader = BufferReader(buffer)
                        var result: Api.CdnConfig?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.CdnConfig
                        }
                        return result
                    })
                }
            
                public static func test() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1058929929)
                    
                    return (FunctionDescription(name: "help.test", parameters: []), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func getRecentMeUrls(referer: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.help.RecentMeUrls>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1036054804)
                    serializeString(referer, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "help.getRecentMeUrls", parameters: [("referer", referer)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.help.RecentMeUrls? in
                        let reader = BufferReader(buffer)
                        var result: Api.help.RecentMeUrls?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.help.RecentMeUrls
                        }
                        return result
                    })
                }
            
                public static func getProxyData() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.help.ProxyData>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1031231713)
                    
                    return (FunctionDescription(name: "help.getProxyData", parameters: []), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.help.ProxyData? in
                        let reader = BufferReader(buffer)
                        var result: Api.help.ProxyData?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.help.ProxyData
                        }
                        return result
                    })
                }
            
                public static func getTermsOfServiceUpdate() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.help.TermsOfServiceUpdate>) {
                    let buffer = Buffer()
                    buffer.appendInt32(749019089)
                    
                    return (FunctionDescription(name: "help.getTermsOfServiceUpdate", parameters: []), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.help.TermsOfServiceUpdate? in
                        let reader = BufferReader(buffer)
                        var result: Api.help.TermsOfServiceUpdate?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.help.TermsOfServiceUpdate
                        }
                        return result
                    })
                }
            
                public static func acceptTermsOfService(id: Api.DataJSON) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-294455398)
                    id.serialize(buffer, true)
                    return (FunctionDescription(name: "help.acceptTermsOfService", parameters: [("id", id)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func getDeepLinkInfo(path: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.help.DeepLinkInfo>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1072547679)
                    serializeString(path, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "help.getDeepLinkInfo", parameters: [("path", path)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.help.DeepLinkInfo? in
                        let reader = BufferReader(buffer)
                        var result: Api.help.DeepLinkInfo?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.help.DeepLinkInfo
                        }
                        return result
                    })
                }
            
                public static func getPassportConfig(hash: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.help.PassportConfig>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-966677240)
                    serializeInt32(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "help.getPassportConfig", parameters: [("hash", hash)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.help.PassportConfig? in
                        let reader = BufferReader(buffer)
                        var result: Api.help.PassportConfig?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.help.PassportConfig
                        }
                        return result
                    })
                }
            
                public static func getAppConfig() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.JSONValue>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1735311088)
                    
                    return (FunctionDescription(name: "help.getAppConfig", parameters: []), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.JSONValue? in
                        let reader = BufferReader(buffer)
                        var result: Api.JSONValue?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.JSONValue
                        }
                        return result
                    })
                }
            
                public static func saveAppLog(events: [Api.InputAppEvent]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1862465352)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(events.count))
                    for item in events {
                        item.serialize(buffer, true)
                    }
                    return (FunctionDescription(name: "help.saveAppLog", parameters: [("events", events)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func getAppUpdate(source: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.help.AppUpdate>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1378703997)
                    serializeString(source, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "help.getAppUpdate", parameters: [("source", source)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.help.AppUpdate? in
                        let reader = BufferReader(buffer)
                        var result: Api.help.AppUpdate?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.help.AppUpdate
                        }
                        return result
                    })
                }
            
                public static func editUserInfo(userId: Api.InputUser, message: String, entities: [Api.MessageEntity]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.help.UserInfo>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1723407216)
                    userId.serialize(buffer, true)
                    serializeString(message, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(entities.count))
                    for item in entities {
                        item.serialize(buffer, true)
                    }
                    return (FunctionDescription(name: "help.editUserInfo", parameters: [("userId", userId), ("message", message), ("entities", entities)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.help.UserInfo? in
                        let reader = BufferReader(buffer)
                        var result: Api.help.UserInfo?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.help.UserInfo
                        }
                        return result
                    })
                }
            
                public static func getUserInfo(userId: Api.InputUser) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.help.UserInfo>) {
                    let buffer = Buffer()
                    buffer.appendInt32(59377875)
                    userId.serialize(buffer, true)
                    return (FunctionDescription(name: "help.getUserInfo", parameters: [("userId", userId)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.help.UserInfo? in
                        let reader = BufferReader(buffer)
                        var result: Api.help.UserInfo?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.help.UserInfo
                        }
                        return result
                    })
                }
            }
            public struct updates {
                public static func getState() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.updates.State>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-304838614)
                    
                    return (FunctionDescription(name: "updates.getState", parameters: []), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.updates.State? in
                        let reader = BufferReader(buffer)
                        var result: Api.updates.State?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.updates.State
                        }
                        return result
                    })
                }
            
                public static func getDifference(flags: Int32, pts: Int32, ptsTotalLimit: Int32?, date: Int32, qts: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.updates.Difference>) {
                    let buffer = Buffer()
                    buffer.appendInt32(630429265)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(pts, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(ptsTotalLimit!, buffer: buffer, boxed: false)}
                    serializeInt32(date, buffer: buffer, boxed: false)
                    serializeInt32(qts, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "updates.getDifference", parameters: [("flags", flags), ("pts", pts), ("ptsTotalLimit", ptsTotalLimit), ("date", date), ("qts", qts)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.updates.Difference? in
                        let reader = BufferReader(buffer)
                        var result: Api.updates.Difference?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.updates.Difference
                        }
                        return result
                    })
                }
            
                public static func getChannelDifference(flags: Int32, channel: Api.InputChannel, filter: Api.ChannelMessagesFilter, pts: Int32, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.updates.ChannelDifference>) {
                    let buffer = Buffer()
                    buffer.appendInt32(51854712)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    channel.serialize(buffer, true)
                    filter.serialize(buffer, true)
                    serializeInt32(pts, buffer: buffer, boxed: false)
                    serializeInt32(limit, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "updates.getChannelDifference", parameters: [("flags", flags), ("channel", channel), ("filter", filter), ("pts", pts), ("limit", limit)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.updates.ChannelDifference? in
                        let reader = BufferReader(buffer)
                        var result: Api.updates.ChannelDifference?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.updates.ChannelDifference
                        }
                        return result
                    })
                }
            }
            public struct folders {
                public static func editPeerFolders(folderPeers: [Api.InputFolderPeer]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1749536939)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(folderPeers.count))
                    for item in folderPeers {
                        item.serialize(buffer, true)
                    }
                    return (FunctionDescription(name: "folders.editPeerFolders", parameters: [("folderPeers", folderPeers)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
            
                public static func deleteFolder(folderId: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(472471681)
                    serializeInt32(folderId, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "folders.deleteFolder", parameters: [("folderId", folderId)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
            }
            public struct upload {
                public static func saveFilePart(fileId: Int64, filePart: Int32, bytes: Buffer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1291540959)
                    serializeInt64(fileId, buffer: buffer, boxed: false)
                    serializeInt32(filePart, buffer: buffer, boxed: false)
                    serializeBytes(bytes, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "upload.saveFilePart", parameters: [("fileId", fileId), ("filePart", filePart), ("bytes", bytes)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func saveBigFilePart(fileId: Int64, filePart: Int32, fileTotalParts: Int32, bytes: Buffer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-562337987)
                    serializeInt64(fileId, buffer: buffer, boxed: false)
                    serializeInt32(filePart, buffer: buffer, boxed: false)
                    serializeInt32(fileTotalParts, buffer: buffer, boxed: false)
                    serializeBytes(bytes, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "upload.saveBigFilePart", parameters: [("fileId", fileId), ("filePart", filePart), ("fileTotalParts", fileTotalParts), ("bytes", bytes)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func getWebFile(location: Api.InputWebFileLocation, offset: Int32, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.upload.WebFile>) {
                    let buffer = Buffer()
                    buffer.appendInt32(619086221)
                    location.serialize(buffer, true)
                    serializeInt32(offset, buffer: buffer, boxed: false)
                    serializeInt32(limit, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "upload.getWebFile", parameters: [("location", location), ("offset", offset), ("limit", limit)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.upload.WebFile? in
                        let reader = BufferReader(buffer)
                        var result: Api.upload.WebFile?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.upload.WebFile
                        }
                        return result
                    })
                }
            
                public static func getCdnFile(fileToken: Buffer, offset: Int32, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.upload.CdnFile>) {
                    let buffer = Buffer()
                    buffer.appendInt32(536919235)
                    serializeBytes(fileToken, buffer: buffer, boxed: false)
                    serializeInt32(offset, buffer: buffer, boxed: false)
                    serializeInt32(limit, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "upload.getCdnFile", parameters: [("fileToken", fileToken), ("offset", offset), ("limit", limit)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.upload.CdnFile? in
                        let reader = BufferReader(buffer)
                        var result: Api.upload.CdnFile?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.upload.CdnFile
                        }
                        return result
                    })
                }
            
                public static func reuploadCdnFile(fileToken: Buffer, requestToken: Buffer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Api.FileHash]>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1691921240)
                    serializeBytes(fileToken, buffer: buffer, boxed: false)
                    serializeBytes(requestToken, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "upload.reuploadCdnFile", parameters: [("fileToken", fileToken), ("requestToken", requestToken)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> [Api.FileHash]? in
                        let reader = BufferReader(buffer)
                        var result: [Api.FileHash]?
                        if let _ = reader.readInt32() {
                            result = Api.parseVector(reader, elementSignature: 0, elementType: Api.FileHash.self)
                        }
                        return result
                    })
                }
            
                public static func getCdnFileHashes(fileToken: Buffer, offset: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Api.FileHash]>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1302676017)
                    serializeBytes(fileToken, buffer: buffer, boxed: false)
                    serializeInt32(offset, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "upload.getCdnFileHashes", parameters: [("fileToken", fileToken), ("offset", offset)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> [Api.FileHash]? in
                        let reader = BufferReader(buffer)
                        var result: [Api.FileHash]?
                        if let _ = reader.readInt32() {
                            result = Api.parseVector(reader, elementSignature: 0, elementType: Api.FileHash.self)
                        }
                        return result
                    })
                }
            
                public static func getFileHashes(location: Api.InputFileLocation, offset: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Api.FileHash]>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-956147407)
                    location.serialize(buffer, true)
                    serializeInt32(offset, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "upload.getFileHashes", parameters: [("location", location), ("offset", offset)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> [Api.FileHash]? in
                        let reader = BufferReader(buffer)
                        var result: [Api.FileHash]?
                        if let _ = reader.readInt32() {
                            result = Api.parseVector(reader, elementSignature: 0, elementType: Api.FileHash.self)
                        }
                        return result
                    })
                }
            
                public static func getFile(flags: Int32, location: Api.InputFileLocation, offset: Int32, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.upload.File>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1319462148)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    location.serialize(buffer, true)
                    serializeInt32(offset, buffer: buffer, boxed: false)
                    serializeInt32(limit, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "upload.getFile", parameters: [("flags", flags), ("location", location), ("offset", offset), ("limit", limit)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.upload.File? in
                        let reader = BufferReader(buffer)
                        var result: Api.upload.File?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.upload.File
                        }
                        return result
                    })
                }
            }
            public struct account {
                public static func updateNotifySettings(peer: Api.InputNotifyPeer, settings: Api.InputPeerNotifySettings) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-2067899501)
                    peer.serialize(buffer, true)
                    settings.serialize(buffer, true)
                    return (FunctionDescription(name: "account.updateNotifySettings", parameters: [("peer", peer), ("settings", settings)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func getNotifySettings(peer: Api.InputNotifyPeer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.PeerNotifySettings>) {
                    let buffer = Buffer()
                    buffer.appendInt32(313765169)
                    peer.serialize(buffer, true)
                    return (FunctionDescription(name: "account.getNotifySettings", parameters: [("peer", peer)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.PeerNotifySettings? in
                        let reader = BufferReader(buffer)
                        var result: Api.PeerNotifySettings?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.PeerNotifySettings
                        }
                        return result
                    })
                }
            
                public static func resetNotifySettings() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-612493497)
                    
                    return (FunctionDescription(name: "account.resetNotifySettings", parameters: []), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func updateProfile(flags: Int32, firstName: String?, lastName: String?, about: String?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.User>) {
                    let buffer = Buffer()
                    buffer.appendInt32(2018596725)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(firstName!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(lastName!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeString(about!, buffer: buffer, boxed: false)}
                    return (FunctionDescription(name: "account.updateProfile", parameters: [("flags", flags), ("firstName", firstName), ("lastName", lastName), ("about", about)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.User? in
                        let reader = BufferReader(buffer)
                        var result: Api.User?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.User
                        }
                        return result
                    })
                }
            
                public static func updateStatus(offline: Api.Bool) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1713919532)
                    offline.serialize(buffer, true)
                    return (FunctionDescription(name: "account.updateStatus", parameters: [("offline", offline)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func reportPeer(peer: Api.InputPeer, reason: Api.ReportReason) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1374118561)
                    peer.serialize(buffer, true)
                    reason.serialize(buffer, true)
                    return (FunctionDescription(name: "account.reportPeer", parameters: [("peer", peer), ("reason", reason)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func checkUsername(username: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(655677548)
                    serializeString(username, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "account.checkUsername", parameters: [("username", username)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func updateUsername(username: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.User>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1040964988)
                    serializeString(username, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "account.updateUsername", parameters: [("username", username)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.User? in
                        let reader = BufferReader(buffer)
                        var result: Api.User?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.User
                        }
                        return result
                    })
                }
            
                public static func getPrivacy(key: Api.InputPrivacyKey) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.account.PrivacyRules>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-623130288)
                    key.serialize(buffer, true)
                    return (FunctionDescription(name: "account.getPrivacy", parameters: [("key", key)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.account.PrivacyRules? in
                        let reader = BufferReader(buffer)
                        var result: Api.account.PrivacyRules?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.account.PrivacyRules
                        }
                        return result
                    })
                }
            
                public static func setPrivacy(key: Api.InputPrivacyKey, rules: [Api.InputPrivacyRule]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.account.PrivacyRules>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-906486552)
                    key.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(rules.count))
                    for item in rules {
                        item.serialize(buffer, true)
                    }
                    return (FunctionDescription(name: "account.setPrivacy", parameters: [("key", key), ("rules", rules)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.account.PrivacyRules? in
                        let reader = BufferReader(buffer)
                        var result: Api.account.PrivacyRules?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.account.PrivacyRules
                        }
                        return result
                    })
                }
            
                public static func deleteAccount(reason: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1099779595)
                    serializeString(reason, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "account.deleteAccount", parameters: [("reason", reason)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func getAccountTTL() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.AccountDaysTTL>) {
                    let buffer = Buffer()
                    buffer.appendInt32(150761757)
                    
                    return (FunctionDescription(name: "account.getAccountTTL", parameters: []), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.AccountDaysTTL? in
                        let reader = BufferReader(buffer)
                        var result: Api.AccountDaysTTL?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.AccountDaysTTL
                        }
                        return result
                    })
                }
            
                public static func setAccountTTL(ttl: Api.AccountDaysTTL) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(608323678)
                    ttl.serialize(buffer, true)
                    return (FunctionDescription(name: "account.setAccountTTL", parameters: [("ttl", ttl)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func sendChangePhoneCode(flags: Int32, phoneNumber: String, currentNumber: Api.Bool?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.auth.SentCode>) {
                    let buffer = Buffer()
                    buffer.appendInt32(149257707)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(phoneNumber, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {currentNumber!.serialize(buffer, true)}
                    return (FunctionDescription(name: "account.sendChangePhoneCode", parameters: [("flags", flags), ("phoneNumber", phoneNumber), ("currentNumber", currentNumber)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.auth.SentCode? in
                        let reader = BufferReader(buffer)
                        var result: Api.auth.SentCode?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.auth.SentCode
                        }
                        return result
                    })
                }
            
                public static func changePhone(phoneNumber: String, phoneCodeHash: String, phoneCode: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.User>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1891839707)
                    serializeString(phoneNumber, buffer: buffer, boxed: false)
                    serializeString(phoneCodeHash, buffer: buffer, boxed: false)
                    serializeString(phoneCode, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "account.changePhone", parameters: [("phoneNumber", phoneNumber), ("phoneCodeHash", phoneCodeHash), ("phoneCode", phoneCode)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.User? in
                        let reader = BufferReader(buffer)
                        var result: Api.User?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.User
                        }
                        return result
                    })
                }
            
                public static func updateDeviceLocked(period: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(954152242)
                    serializeInt32(period, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "account.updateDeviceLocked", parameters: [("period", period)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func getAuthorizations() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.account.Authorizations>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-484392616)
                    
                    return (FunctionDescription(name: "account.getAuthorizations", parameters: []), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.account.Authorizations? in
                        let reader = BufferReader(buffer)
                        var result: Api.account.Authorizations?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.account.Authorizations
                        }
                        return result
                    })
                }
            
                public static func resetAuthorization(hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-545786948)
                    serializeInt64(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "account.resetAuthorization", parameters: [("hash", hash)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func getPassword() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.account.Password>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1418342645)
                    
                    return (FunctionDescription(name: "account.getPassword", parameters: []), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.account.Password? in
                        let reader = BufferReader(buffer)
                        var result: Api.account.Password?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.account.Password
                        }
                        return result
                    })
                }
            
                public static func sendConfirmPhoneCode(flags: Int32, hash: String, currentNumber: Api.Bool?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.auth.SentCode>) {
                    let buffer = Buffer()
                    buffer.appendInt32(353818557)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(hash, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {currentNumber!.serialize(buffer, true)}
                    return (FunctionDescription(name: "account.sendConfirmPhoneCode", parameters: [("flags", flags), ("hash", hash), ("currentNumber", currentNumber)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.auth.SentCode? in
                        let reader = BufferReader(buffer)
                        var result: Api.auth.SentCode?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.auth.SentCode
                        }
                        return result
                    })
                }
            
                public static func confirmPhone(phoneCodeHash: String, phoneCode: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1596029123)
                    serializeString(phoneCodeHash, buffer: buffer, boxed: false)
                    serializeString(phoneCode, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "account.confirmPhone", parameters: [("phoneCodeHash", phoneCodeHash), ("phoneCode", phoneCode)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func unregisterDevice(tokenType: Int32, token: String, otherUids: [Int32]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(813089983)
                    serializeInt32(tokenType, buffer: buffer, boxed: false)
                    serializeString(token, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(otherUids.count))
                    for item in otherUids {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    return (FunctionDescription(name: "account.unregisterDevice", parameters: [("tokenType", tokenType), ("token", token), ("otherUids", otherUids)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func getWebAuthorizations() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.account.WebAuthorizations>) {
                    let buffer = Buffer()
                    buffer.appendInt32(405695855)
                    
                    return (FunctionDescription(name: "account.getWebAuthorizations", parameters: []), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.account.WebAuthorizations? in
                        let reader = BufferReader(buffer)
                        var result: Api.account.WebAuthorizations?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.account.WebAuthorizations
                        }
                        return result
                    })
                }
            
                public static func resetWebAuthorization(hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(755087855)
                    serializeInt64(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "account.resetWebAuthorization", parameters: [("hash", hash)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func resetWebAuthorizations() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1747789204)
                    
                    return (FunctionDescription(name: "account.resetWebAuthorizations", parameters: []), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func getAllSecureValues() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Api.SecureValue]>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1299661699)
                    
                    return (FunctionDescription(name: "account.getAllSecureValues", parameters: []), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> [Api.SecureValue]? in
                        let reader = BufferReader(buffer)
                        var result: [Api.SecureValue]?
                        if let _ = reader.readInt32() {
                            result = Api.parseVector(reader, elementSignature: 0, elementType: Api.SecureValue.self)
                        }
                        return result
                    })
                }
            
                public static func getSecureValue(types: [Api.SecureValueType]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Api.SecureValue]>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1936088002)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(types.count))
                    for item in types {
                        item.serialize(buffer, true)
                    }
                    return (FunctionDescription(name: "account.getSecureValue", parameters: [("types", types)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> [Api.SecureValue]? in
                        let reader = BufferReader(buffer)
                        var result: [Api.SecureValue]?
                        if let _ = reader.readInt32() {
                            result = Api.parseVector(reader, elementSignature: 0, elementType: Api.SecureValue.self)
                        }
                        return result
                    })
                }
            
                public static func saveSecureValue(value: Api.InputSecureValue, secureSecretId: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.SecureValue>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1986010339)
                    value.serialize(buffer, true)
                    serializeInt64(secureSecretId, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "account.saveSecureValue", parameters: [("value", value), ("secureSecretId", secureSecretId)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.SecureValue? in
                        let reader = BufferReader(buffer)
                        var result: Api.SecureValue?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.SecureValue
                        }
                        return result
                    })
                }
            
                public static func deleteSecureValue(types: [Api.SecureValueType]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1199522741)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(types.count))
                    for item in types {
                        item.serialize(buffer, true)
                    }
                    return (FunctionDescription(name: "account.deleteSecureValue", parameters: [("types", types)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func getAuthorizationForm(botId: Int32, scope: String, publicKey: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.account.AuthorizationForm>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1200903967)
                    serializeInt32(botId, buffer: buffer, boxed: false)
                    serializeString(scope, buffer: buffer, boxed: false)
                    serializeString(publicKey, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "account.getAuthorizationForm", parameters: [("botId", botId), ("scope", scope), ("publicKey", publicKey)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.account.AuthorizationForm? in
                        let reader = BufferReader(buffer)
                        var result: Api.account.AuthorizationForm?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.account.AuthorizationForm
                        }
                        return result
                    })
                }
            
                public static func acceptAuthorization(botId: Int32, scope: String, publicKey: String, valueHashes: [Api.SecureValueHash], credentials: Api.SecureCredentialsEncrypted) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
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
                    return (FunctionDescription(name: "account.acceptAuthorization", parameters: [("botId", botId), ("scope", scope), ("publicKey", publicKey), ("valueHashes", valueHashes), ("credentials", credentials)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func sendVerifyPhoneCode(flags: Int32, phoneNumber: String, currentNumber: Api.Bool?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.auth.SentCode>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-2110553932)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(phoneNumber, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {currentNumber!.serialize(buffer, true)}
                    return (FunctionDescription(name: "account.sendVerifyPhoneCode", parameters: [("flags", flags), ("phoneNumber", phoneNumber), ("currentNumber", currentNumber)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.auth.SentCode? in
                        let reader = BufferReader(buffer)
                        var result: Api.auth.SentCode?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.auth.SentCode
                        }
                        return result
                    })
                }
            
                public static func verifyPhone(phoneNumber: String, phoneCodeHash: String, phoneCode: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1305716726)
                    serializeString(phoneNumber, buffer: buffer, boxed: false)
                    serializeString(phoneCodeHash, buffer: buffer, boxed: false)
                    serializeString(phoneCode, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "account.verifyPhone", parameters: [("phoneNumber", phoneNumber), ("phoneCodeHash", phoneCodeHash), ("phoneCode", phoneCode)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func sendVerifyEmailCode(email: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.account.SentEmailCode>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1880182943)
                    serializeString(email, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "account.sendVerifyEmailCode", parameters: [("email", email)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.account.SentEmailCode? in
                        let reader = BufferReader(buffer)
                        var result: Api.account.SentEmailCode?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.account.SentEmailCode
                        }
                        return result
                    })
                }
            
                public static func verifyEmail(email: String, code: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-323339813)
                    serializeString(email, buffer: buffer, boxed: false)
                    serializeString(code, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "account.verifyEmail", parameters: [("email", email), ("code", code)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func getTmpPassword(password: Api.InputCheckPasswordSRP, period: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.account.TmpPassword>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1151208273)
                    password.serialize(buffer, true)
                    serializeInt32(period, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "account.getTmpPassword", parameters: [("password", password), ("period", period)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.account.TmpPassword? in
                        let reader = BufferReader(buffer)
                        var result: Api.account.TmpPassword?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.account.TmpPassword
                        }
                        return result
                    })
                }
            
                public static func updatePasswordSettings(password: Api.InputCheckPasswordSRP, newSettings: Api.account.PasswordInputSettings) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1516564433)
                    password.serialize(buffer, true)
                    newSettings.serialize(buffer, true)
                    return (FunctionDescription(name: "account.updatePasswordSettings", parameters: [("password", password), ("newSettings", newSettings)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func getPasswordSettings(password: Api.InputCheckPasswordSRP) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.account.PasswordSettings>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1663767815)
                    password.serialize(buffer, true)
                    return (FunctionDescription(name: "account.getPasswordSettings", parameters: [("password", password)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.account.PasswordSettings? in
                        let reader = BufferReader(buffer)
                        var result: Api.account.PasswordSettings?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.account.PasswordSettings
                        }
                        return result
                    })
                }
            
                public static func confirmPasswordEmail(code: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1881204448)
                    serializeString(code, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "account.confirmPasswordEmail", parameters: [("code", code)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func resendPasswordEmail() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(2055154197)
                    
                    return (FunctionDescription(name: "account.resendPasswordEmail", parameters: []), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func cancelPasswordEmail() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1043606090)
                    
                    return (FunctionDescription(name: "account.cancelPasswordEmail", parameters: []), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func getContactSignUpNotification() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1626880216)
                    
                    return (FunctionDescription(name: "account.getContactSignUpNotification", parameters: []), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func setContactSignUpNotification(silent: Api.Bool) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-806076575)
                    silent.serialize(buffer, true)
                    return (FunctionDescription(name: "account.setContactSignUpNotification", parameters: [("silent", silent)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func getNotifyExceptions(flags: Int32, peer: Api.InputNotifyPeer?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1398240377)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {peer!.serialize(buffer, true)}
                    return (FunctionDescription(name: "account.getNotifyExceptions", parameters: [("flags", flags), ("peer", peer)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
            
                public static func getWallPapers(hash: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.account.WallPapers>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1430579357)
                    serializeInt32(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "account.getWallPapers", parameters: [("hash", hash)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.account.WallPapers? in
                        let reader = BufferReader(buffer)
                        var result: Api.account.WallPapers?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.account.WallPapers
                        }
                        return result
                    })
                }
            
                public static func uploadWallPaper(file: Api.InputFile, mimeType: String, settings: Api.WallPaperSettings) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.WallPaper>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-578472351)
                    file.serialize(buffer, true)
                    serializeString(mimeType, buffer: buffer, boxed: false)
                    settings.serialize(buffer, true)
                    return (FunctionDescription(name: "account.uploadWallPaper", parameters: [("file", file), ("mimeType", mimeType), ("settings", settings)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.WallPaper? in
                        let reader = BufferReader(buffer)
                        var result: Api.WallPaper?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.WallPaper
                        }
                        return result
                    })
                }
            
                public static func getWallPaper(wallpaper: Api.InputWallPaper) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.WallPaper>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-57811990)
                    wallpaper.serialize(buffer, true)
                    return (FunctionDescription(name: "account.getWallPaper", parameters: [("wallpaper", wallpaper)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.WallPaper? in
                        let reader = BufferReader(buffer)
                        var result: Api.WallPaper?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.WallPaper
                        }
                        return result
                    })
                }
            
                public static func saveWallPaper(wallpaper: Api.InputWallPaper, unsave: Api.Bool, settings: Api.WallPaperSettings) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1817860919)
                    wallpaper.serialize(buffer, true)
                    unsave.serialize(buffer, true)
                    settings.serialize(buffer, true)
                    return (FunctionDescription(name: "account.saveWallPaper", parameters: [("wallpaper", wallpaper), ("unsave", unsave), ("settings", settings)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func installWallPaper(wallpaper: Api.InputWallPaper, settings: Api.WallPaperSettings) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-18000023)
                    wallpaper.serialize(buffer, true)
                    settings.serialize(buffer, true)
                    return (FunctionDescription(name: "account.installWallPaper", parameters: [("wallpaper", wallpaper), ("settings", settings)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func resetWallPapers() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1153722364)
                    
                    return (FunctionDescription(name: "account.resetWallPapers", parameters: []), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func getAutoDownloadSettings() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.account.AutoDownloadSettings>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1457130303)
                    
                    return (FunctionDescription(name: "account.getAutoDownloadSettings", parameters: []), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.account.AutoDownloadSettings? in
                        let reader = BufferReader(buffer)
                        var result: Api.account.AutoDownloadSettings?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.account.AutoDownloadSettings
                        }
                        return result
                    })
                }
            
                public static func saveAutoDownloadSettings(flags: Int32, settings: Api.AutoDownloadSettings) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1995661875)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    settings.serialize(buffer, true)
                    return (FunctionDescription(name: "account.saveAutoDownloadSettings", parameters: [("flags", flags), ("settings", settings)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func registerDevice(flags: Int32, tokenType: Int32, token: String, appSandbox: Api.Bool, secret: Buffer, otherUids: [Int32]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1754754159)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(tokenType, buffer: buffer, boxed: false)
                    serializeString(token, buffer: buffer, boxed: false)
                    appSandbox.serialize(buffer, true)
                    serializeBytes(secret, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(otherUids.count))
                    for item in otherUids {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    return (FunctionDescription(name: "account.registerDevice", parameters: [("flags", flags), ("tokenType", tokenType), ("token", token), ("appSandbox", appSandbox), ("secret", secret), ("otherUids", otherUids)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func uploadTheme(flags: Int32, file: Api.InputFile, thumb: Api.InputFile?, fileName: String, mimeType: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Document>) {
                    let buffer = Buffer()
                    buffer.appendInt32(473805619)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    file.serialize(buffer, true)
                    if Int(flags) & Int(1 << 0) != 0 {thumb!.serialize(buffer, true)}
                    serializeString(fileName, buffer: buffer, boxed: false)
                    serializeString(mimeType, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "account.uploadTheme", parameters: [("flags", flags), ("file", file), ("thumb", thumb), ("fileName", fileName), ("mimeType", mimeType)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Document? in
                        let reader = BufferReader(buffer)
                        var result: Api.Document?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Document
                        }
                        return result
                    })
                }
            
                public static func saveTheme(theme: Api.InputTheme, unsave: Api.Bool) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-229175188)
                    theme.serialize(buffer, true)
                    unsave.serialize(buffer, true)
                    return (FunctionDescription(name: "account.saveTheme", parameters: [("theme", theme), ("unsave", unsave)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func installTheme(flags: Int32, format: String?, theme: Api.InputTheme?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(2061776695)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(format!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {theme!.serialize(buffer, true)}
                    return (FunctionDescription(name: "account.installTheme", parameters: [("flags", flags), ("format", format), ("theme", theme)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func getTheme(format: String, theme: Api.InputTheme, documentId: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Theme>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1919060949)
                    serializeString(format, buffer: buffer, boxed: false)
                    theme.serialize(buffer, true)
                    serializeInt64(documentId, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "account.getTheme", parameters: [("format", format), ("theme", theme), ("documentId", documentId)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Theme? in
                        let reader = BufferReader(buffer)
                        var result: Api.Theme?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Theme
                        }
                        return result
                    })
                }
            
                public static func getThemes(format: String, hash: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.account.Themes>) {
                    let buffer = Buffer()
                    buffer.appendInt32(676939512)
                    serializeString(format, buffer: buffer, boxed: false)
                    serializeInt32(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "account.getThemes", parameters: [("format", format), ("hash", hash)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.account.Themes? in
                        let reader = BufferReader(buffer)
                        var result: Api.account.Themes?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.account.Themes
                        }
                        return result
                    })
                }
            
                public static func setContentSettings(flags: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1250643605)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "account.setContentSettings", parameters: [("flags", flags)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func getContentSettings() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.account.ContentSettings>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1952756306)
                    
                    return (FunctionDescription(name: "account.getContentSettings", parameters: []), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.account.ContentSettings? in
                        let reader = BufferReader(buffer)
                        var result: Api.account.ContentSettings?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.account.ContentSettings
                        }
                        return result
                    })
                }
            
                public static func createTheme(flags: Int32, slug: String, title: String, document: Api.InputDocument?, settings: Api.InputThemeSettings?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Theme>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-2077048289)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(slug, buffer: buffer, boxed: false)
                    serializeString(title, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 2) != 0 {document!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 3) != 0 {settings!.serialize(buffer, true)}
                    return (FunctionDescription(name: "account.createTheme", parameters: [("flags", flags), ("slug", slug), ("title", title), ("document", document), ("settings", settings)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Theme? in
                        let reader = BufferReader(buffer)
                        var result: Api.Theme?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Theme
                        }
                        return result
                    })
                }
            
                public static func updateTheme(flags: Int32, format: String, theme: Api.InputTheme, slug: String?, title: String?, document: Api.InputDocument?, settings: Api.InputThemeSettings?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Theme>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1555261397)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(format, buffer: buffer, boxed: false)
                    theme.serialize(buffer, true)
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(slug!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(title!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {document!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 3) != 0 {settings!.serialize(buffer, true)}
                    return (FunctionDescription(name: "account.updateTheme", parameters: [("flags", flags), ("format", format), ("theme", theme), ("slug", slug), ("title", title), ("document", document), ("settings", settings)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Theme? in
                        let reader = BufferReader(buffer)
                        var result: Api.Theme?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Theme
                        }
                        return result
                    })
                }
            
                public static func getMultiWallPapers(wallpapers: [Api.InputWallPaper]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Api.WallPaper]>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1705865692)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(wallpapers.count))
                    for item in wallpapers {
                        item.serialize(buffer, true)
                    }
                    return (FunctionDescription(name: "account.getMultiWallPapers", parameters: [("wallpapers", wallpapers)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> [Api.WallPaper]? in
                        let reader = BufferReader(buffer)
                        var result: [Api.WallPaper]?
                        if let _ = reader.readInt32() {
                            result = Api.parseVector(reader, elementSignature: 0, elementType: Api.WallPaper.self)
                        }
                        return result
                    })
                }
            }
            public struct wallet {
                public static func sendLiteRequest(body: Buffer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.wallet.LiteResponse>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-490089666)
                    serializeBytes(body, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "wallet.sendLiteRequest", parameters: [("body", body)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.wallet.LiteResponse? in
                        let reader = BufferReader(buffer)
                        var result: Api.wallet.LiteResponse?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.wallet.LiteResponse
                        }
                        return result
                    })
                }
            
                public static func getKeySecretSalt(revoke: Api.Bool) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.wallet.KeySecretSalt>) {
                    let buffer = Buffer()
                    buffer.appendInt32(190313286)
                    revoke.serialize(buffer, true)
                    return (FunctionDescription(name: "wallet.getKeySecretSalt", parameters: [("revoke", revoke)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.wallet.KeySecretSalt? in
                        let reader = BufferReader(buffer)
                        var result: Api.wallet.KeySecretSalt?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.wallet.KeySecretSalt
                        }
                        return result
                    })
                }
            }
            public struct langpack {
                public static func getLangPack(langPack: String, langCode: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.LangPackDifference>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-219008246)
                    serializeString(langPack, buffer: buffer, boxed: false)
                    serializeString(langCode, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "langpack.getLangPack", parameters: [("langPack", langPack), ("langCode", langCode)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.LangPackDifference? in
                        let reader = BufferReader(buffer)
                        var result: Api.LangPackDifference?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.LangPackDifference
                        }
                        return result
                    })
                }
            
                public static func getStrings(langPack: String, langCode: String, keys: [String]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Api.LangPackString]>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-269862909)
                    serializeString(langPack, buffer: buffer, boxed: false)
                    serializeString(langCode, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(keys.count))
                    for item in keys {
                        serializeString(item, buffer: buffer, boxed: false)
                    }
                    return (FunctionDescription(name: "langpack.getStrings", parameters: [("langPack", langPack), ("langCode", langCode), ("keys", keys)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> [Api.LangPackString]? in
                        let reader = BufferReader(buffer)
                        var result: [Api.LangPackString]?
                        if let _ = reader.readInt32() {
                            result = Api.parseVector(reader, elementSignature: 0, elementType: Api.LangPackString.self)
                        }
                        return result
                    })
                }
            
                public static func getLanguages(langPack: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Api.LangPackLanguage]>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1120311183)
                    serializeString(langPack, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "langpack.getLanguages", parameters: [("langPack", langPack)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> [Api.LangPackLanguage]? in
                        let reader = BufferReader(buffer)
                        var result: [Api.LangPackLanguage]?
                        if let _ = reader.readInt32() {
                            result = Api.parseVector(reader, elementSignature: 0, elementType: Api.LangPackLanguage.self)
                        }
                        return result
                    })
                }
            
                public static func getDifference(langCode: String, fromVersion: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.LangPackDifference>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1655576556)
                    serializeString(langCode, buffer: buffer, boxed: false)
                    serializeInt32(fromVersion, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "langpack.getDifference", parameters: [("langCode", langCode), ("fromVersion", fromVersion)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.LangPackDifference? in
                        let reader = BufferReader(buffer)
                        var result: Api.LangPackDifference?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.LangPackDifference
                        }
                        return result
                    })
                }
            
                public static func getLanguage(langPack: String, langCode: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.LangPackLanguage>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1784243458)
                    serializeString(langPack, buffer: buffer, boxed: false)
                    serializeString(langCode, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "langpack.getLanguage", parameters: [("langPack", langPack), ("langCode", langCode)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.LangPackLanguage? in
                        let reader = BufferReader(buffer)
                        var result: Api.LangPackLanguage?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.LangPackLanguage
                        }
                        return result
                    })
                }
            }
            public struct photos {
                public static func updateProfilePhoto(id: Api.InputPhoto) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.UserProfilePhoto>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-256159406)
                    id.serialize(buffer, true)
                    return (FunctionDescription(name: "photos.updateProfilePhoto", parameters: [("id", id)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.UserProfilePhoto? in
                        let reader = BufferReader(buffer)
                        var result: Api.UserProfilePhoto?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.UserProfilePhoto
                        }
                        return result
                    })
                }
            
                public static func uploadProfilePhoto(file: Api.InputFile) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.photos.Photo>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1328726168)
                    file.serialize(buffer, true)
                    return (FunctionDescription(name: "photos.uploadProfilePhoto", parameters: [("file", file)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.photos.Photo? in
                        let reader = BufferReader(buffer)
                        var result: Api.photos.Photo?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.photos.Photo
                        }
                        return result
                    })
                }
            
                public static func deletePhotos(id: [Api.InputPhoto]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Int64]>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-2016444625)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(id.count))
                    for item in id {
                        item.serialize(buffer, true)
                    }
                    return (FunctionDescription(name: "photos.deletePhotos", parameters: [("id", id)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> [Int64]? in
                        let reader = BufferReader(buffer)
                        var result: [Int64]?
                        if let _ = reader.readInt32() {
                            result = Api.parseVector(reader, elementSignature: 570911930, elementType: Int64.self)
                        }
                        return result
                    })
                }
            
                public static func getUserPhotos(userId: Api.InputUser, offset: Int32, maxId: Int64, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.photos.Photos>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1848823128)
                    userId.serialize(buffer, true)
                    serializeInt32(offset, buffer: buffer, boxed: false)
                    serializeInt64(maxId, buffer: buffer, boxed: false)
                    serializeInt32(limit, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "photos.getUserPhotos", parameters: [("userId", userId), ("offset", offset), ("maxId", maxId), ("limit", limit)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.photos.Photos? in
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
                public static func getCallConfig() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.DataJSON>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1430593449)
                    
                    return (FunctionDescription(name: "phone.getCallConfig", parameters: []), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.DataJSON? in
                        let reader = BufferReader(buffer)
                        var result: Api.DataJSON?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.DataJSON
                        }
                        return result
                    })
                }
            
                public static func acceptCall(peer: Api.InputPhoneCall, gB: Buffer, `protocol`: Api.PhoneCallProtocol) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.phone.PhoneCall>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1003664544)
                    peer.serialize(buffer, true)
                    serializeBytes(gB, buffer: buffer, boxed: false)
                    `protocol`.serialize(buffer, true)
                    return (FunctionDescription(name: "phone.acceptCall", parameters: [("peer", peer), ("gB", gB), ("`protocol`", `protocol`)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.phone.PhoneCall? in
                        let reader = BufferReader(buffer)
                        var result: Api.phone.PhoneCall?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.phone.PhoneCall
                        }
                        return result
                    })
                }
            
                public static func confirmCall(peer: Api.InputPhoneCall, gA: Buffer, keyFingerprint: Int64, `protocol`: Api.PhoneCallProtocol) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.phone.PhoneCall>) {
                    let buffer = Buffer()
                    buffer.appendInt32(788404002)
                    peer.serialize(buffer, true)
                    serializeBytes(gA, buffer: buffer, boxed: false)
                    serializeInt64(keyFingerprint, buffer: buffer, boxed: false)
                    `protocol`.serialize(buffer, true)
                    return (FunctionDescription(name: "phone.confirmCall", parameters: [("peer", peer), ("gA", gA), ("keyFingerprint", keyFingerprint), ("`protocol`", `protocol`)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.phone.PhoneCall? in
                        let reader = BufferReader(buffer)
                        var result: Api.phone.PhoneCall?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.phone.PhoneCall
                        }
                        return result
                    })
                }
            
                public static func receivedCall(peer: Api.InputPhoneCall) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(399855457)
                    peer.serialize(buffer, true)
                    return (FunctionDescription(name: "phone.receivedCall", parameters: [("peer", peer)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func saveCallDebug(peer: Api.InputPhoneCall, debug: Api.DataJSON) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(662363518)
                    peer.serialize(buffer, true)
                    debug.serialize(buffer, true)
                    return (FunctionDescription(name: "phone.saveCallDebug", parameters: [("peer", peer), ("debug", debug)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
            
                public static func setCallRating(flags: Int32, peer: Api.InputPhoneCall, rating: Int32, comment: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1508562471)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    serializeInt32(rating, buffer: buffer, boxed: false)
                    serializeString(comment, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "phone.setCallRating", parameters: [("flags", flags), ("peer", peer), ("rating", rating), ("comment", comment)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
            
                public static func requestCall(flags: Int32, userId: Api.InputUser, randomId: Int32, gAHash: Buffer, `protocol`: Api.PhoneCallProtocol) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.phone.PhoneCall>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1124046573)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    userId.serialize(buffer, true)
                    serializeInt32(randomId, buffer: buffer, boxed: false)
                    serializeBytes(gAHash, buffer: buffer, boxed: false)
                    `protocol`.serialize(buffer, true)
                    return (FunctionDescription(name: "phone.requestCall", parameters: [("flags", flags), ("userId", userId), ("randomId", randomId), ("gAHash", gAHash), ("`protocol`", `protocol`)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.phone.PhoneCall? in
                        let reader = BufferReader(buffer)
                        var result: Api.phone.PhoneCall?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.phone.PhoneCall
                        }
                        return result
                    })
                }
            
                public static func discardCall(flags: Int32, peer: Api.InputPhoneCall, duration: Int32, reason: Api.PhoneCallDiscardReason, connectionId: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1295269440)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    serializeInt32(duration, buffer: buffer, boxed: false)
                    reason.serialize(buffer, true)
                    serializeInt64(connectionId, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "phone.discardCall", parameters: [("flags", flags), ("peer", peer), ("duration", duration), ("reason", reason), ("connectionId", connectionId)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
            }
    }
}
