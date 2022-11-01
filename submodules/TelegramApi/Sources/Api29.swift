public extension Api.functions.account {
                static func acceptAuthorization(botId: Int64, scope: String, publicKey: String, valueHashes: [Api.SecureValueHash], credentials: Api.SecureCredentialsEncrypted) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-202552205)
                    serializeInt64(botId, buffer: buffer, boxed: false)
                    serializeString(scope, buffer: buffer, boxed: false)
                    serializeString(publicKey, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(valueHashes.count))
                    for item in valueHashes {
                        item.serialize(buffer, true)
                    }
                    credentials.serialize(buffer, true)
                    return (FunctionDescription(name: "account.acceptAuthorization", parameters: [("botId", String(describing: botId)), ("scope", String(describing: scope)), ("publicKey", String(describing: publicKey)), ("valueHashes", String(describing: valueHashes)), ("credentials", String(describing: credentials))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.account {
                static func cancelPasswordEmail() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
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
}
public extension Api.functions.account {
                static func changeAuthorizationSettings(flags: Int32, hash: Int64, encryptedRequestsDisabled: Api.Bool?, callRequestsDisabled: Api.Bool?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1089766498)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(hash, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {encryptedRequestsDisabled!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 1) != 0 {callRequestsDisabled!.serialize(buffer, true)}
                    return (FunctionDescription(name: "account.changeAuthorizationSettings", parameters: [("flags", String(describing: flags)), ("hash", String(describing: hash)), ("encryptedRequestsDisabled", String(describing: encryptedRequestsDisabled)), ("callRequestsDisabled", String(describing: callRequestsDisabled))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.account {
                static func changePhone(phoneNumber: String, phoneCodeHash: String, phoneCode: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.User>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1891839707)
                    serializeString(phoneNumber, buffer: buffer, boxed: false)
                    serializeString(phoneCodeHash, buffer: buffer, boxed: false)
                    serializeString(phoneCode, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "account.changePhone", parameters: [("phoneNumber", String(describing: phoneNumber)), ("phoneCodeHash", String(describing: phoneCodeHash)), ("phoneCode", String(describing: phoneCode))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.User? in
                        let reader = BufferReader(buffer)
                        var result: Api.User?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.User
                        }
                        return result
                    })
                }
}
public extension Api.functions.account {
                static func checkUsername(username: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(655677548)
                    serializeString(username, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "account.checkUsername", parameters: [("username", String(describing: username))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.account {
                static func clearRecentEmojiStatuses() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(404757166)
                    
                    return (FunctionDescription(name: "account.clearRecentEmojiStatuses", parameters: []), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.account {
                static func confirmPasswordEmail(code: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1881204448)
                    serializeString(code, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "account.confirmPasswordEmail", parameters: [("code", String(describing: code))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.account {
                static func confirmPhone(phoneCodeHash: String, phoneCode: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1596029123)
                    serializeString(phoneCodeHash, buffer: buffer, boxed: false)
                    serializeString(phoneCode, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "account.confirmPhone", parameters: [("phoneCodeHash", String(describing: phoneCodeHash)), ("phoneCode", String(describing: phoneCode))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.account {
                static func createTheme(flags: Int32, slug: String, title: String, document: Api.InputDocument?, settings: [Api.InputThemeSettings]?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Theme>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1697530880)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(slug, buffer: buffer, boxed: false)
                    serializeString(title, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 2) != 0 {document!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 3) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(settings!.count))
                    for item in settings! {
                        item.serialize(buffer, true)
                    }}
                    return (FunctionDescription(name: "account.createTheme", parameters: [("flags", String(describing: flags)), ("slug", String(describing: slug)), ("title", String(describing: title)), ("document", String(describing: document)), ("settings", String(describing: settings))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Theme? in
                        let reader = BufferReader(buffer)
                        var result: Api.Theme?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Theme
                        }
                        return result
                    })
                }
}
public extension Api.functions.account {
                static func declinePasswordReset() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1284770294)
                    
                    return (FunctionDescription(name: "account.declinePasswordReset", parameters: []), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.account {
                static func deleteAccount(flags: Int32, reason: String, password: Api.InputCheckPasswordSRP?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1564422284)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(reason, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {password!.serialize(buffer, true)}
                    return (FunctionDescription(name: "account.deleteAccount", parameters: [("flags", String(describing: flags)), ("reason", String(describing: reason)), ("password", String(describing: password))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.account {
                static func deleteSecureValue(types: [Api.SecureValueType]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1199522741)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(types.count))
                    for item in types {
                        item.serialize(buffer, true)
                    }
                    return (FunctionDescription(name: "account.deleteSecureValue", parameters: [("types", String(describing: types))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.account {
                static func finishTakeoutSession(flags: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(489050862)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "account.finishTakeoutSession", parameters: [("flags", String(describing: flags))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.account {
                static func getAccountTTL() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.AccountDaysTTL>) {
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
}
public extension Api.functions.account {
                static func getAllSecureValues() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Api.SecureValue]>) {
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
}
public extension Api.functions.account {
                static func getAuthorizationForm(botId: Int64, scope: String, publicKey: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.account.AuthorizationForm>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1456907910)
                    serializeInt64(botId, buffer: buffer, boxed: false)
                    serializeString(scope, buffer: buffer, boxed: false)
                    serializeString(publicKey, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "account.getAuthorizationForm", parameters: [("botId", String(describing: botId)), ("scope", String(describing: scope)), ("publicKey", String(describing: publicKey))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.account.AuthorizationForm? in
                        let reader = BufferReader(buffer)
                        var result: Api.account.AuthorizationForm?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.account.AuthorizationForm
                        }
                        return result
                    })
                }
}
public extension Api.functions.account {
                static func getAuthorizations() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.account.Authorizations>) {
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
}
public extension Api.functions.account {
                static func getAutoDownloadSettings() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.account.AutoDownloadSettings>) {
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
}
public extension Api.functions.account {
                static func getChatThemes(hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.account.Themes>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-700916087)
                    serializeInt64(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "account.getChatThemes", parameters: [("hash", String(describing: hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.account.Themes? in
                        let reader = BufferReader(buffer)
                        var result: Api.account.Themes?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.account.Themes
                        }
                        return result
                    })
                }
}
public extension Api.functions.account {
                static func getContactSignUpNotification() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
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
}
public extension Api.functions.account {
                static func getContentSettings() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.account.ContentSettings>) {
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
}
public extension Api.functions.account {
                static func getDefaultEmojiStatuses(hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.account.EmojiStatuses>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-696962170)
                    serializeInt64(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "account.getDefaultEmojiStatuses", parameters: [("hash", String(describing: hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.account.EmojiStatuses? in
                        let reader = BufferReader(buffer)
                        var result: Api.account.EmojiStatuses?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.account.EmojiStatuses
                        }
                        return result
                    })
                }
}
public extension Api.functions.account {
                static func getGlobalPrivacySettings() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.GlobalPrivacySettings>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-349483786)
                    
                    return (FunctionDescription(name: "account.getGlobalPrivacySettings", parameters: []), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.GlobalPrivacySettings? in
                        let reader = BufferReader(buffer)
                        var result: Api.GlobalPrivacySettings?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.GlobalPrivacySettings
                        }
                        return result
                    })
                }
}
public extension Api.functions.account {
                static func getMultiWallPapers(wallpapers: [Api.InputWallPaper]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Api.WallPaper]>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1705865692)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(wallpapers.count))
                    for item in wallpapers {
                        item.serialize(buffer, true)
                    }
                    return (FunctionDescription(name: "account.getMultiWallPapers", parameters: [("wallpapers", String(describing: wallpapers))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> [Api.WallPaper]? in
                        let reader = BufferReader(buffer)
                        var result: [Api.WallPaper]?
                        if let _ = reader.readInt32() {
                            result = Api.parseVector(reader, elementSignature: 0, elementType: Api.WallPaper.self)
                        }
                        return result
                    })
                }
}
public extension Api.functions.account {
                static func getNotifyExceptions(flags: Int32, peer: Api.InputNotifyPeer?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1398240377)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {peer!.serialize(buffer, true)}
                    return (FunctionDescription(name: "account.getNotifyExceptions", parameters: [("flags", String(describing: flags)), ("peer", String(describing: peer))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
}
public extension Api.functions.account {
                static func getNotifySettings(peer: Api.InputNotifyPeer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.PeerNotifySettings>) {
                    let buffer = Buffer()
                    buffer.appendInt32(313765169)
                    peer.serialize(buffer, true)
                    return (FunctionDescription(name: "account.getNotifySettings", parameters: [("peer", String(describing: peer))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.PeerNotifySettings? in
                        let reader = BufferReader(buffer)
                        var result: Api.PeerNotifySettings?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.PeerNotifySettings
                        }
                        return result
                    })
                }
}
public extension Api.functions.account {
                static func getPassword() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.account.Password>) {
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
}
public extension Api.functions.account {
                static func getPasswordSettings(password: Api.InputCheckPasswordSRP) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.account.PasswordSettings>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1663767815)
                    password.serialize(buffer, true)
                    return (FunctionDescription(name: "account.getPasswordSettings", parameters: [("password", String(describing: password))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.account.PasswordSettings? in
                        let reader = BufferReader(buffer)
                        var result: Api.account.PasswordSettings?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.account.PasswordSettings
                        }
                        return result
                    })
                }
}
public extension Api.functions.account {
                static func getPrivacy(key: Api.InputPrivacyKey) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.account.PrivacyRules>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-623130288)
                    key.serialize(buffer, true)
                    return (FunctionDescription(name: "account.getPrivacy", parameters: [("key", String(describing: key))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.account.PrivacyRules? in
                        let reader = BufferReader(buffer)
                        var result: Api.account.PrivacyRules?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.account.PrivacyRules
                        }
                        return result
                    })
                }
}
public extension Api.functions.account {
                static func getRecentEmojiStatuses(hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.account.EmojiStatuses>) {
                    let buffer = Buffer()
                    buffer.appendInt32(257392901)
                    serializeInt64(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "account.getRecentEmojiStatuses", parameters: [("hash", String(describing: hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.account.EmojiStatuses? in
                        let reader = BufferReader(buffer)
                        var result: Api.account.EmojiStatuses?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.account.EmojiStatuses
                        }
                        return result
                    })
                }
}
public extension Api.functions.account {
                static func getSavedRingtones(hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.account.SavedRingtones>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-510647672)
                    serializeInt64(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "account.getSavedRingtones", parameters: [("hash", String(describing: hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.account.SavedRingtones? in
                        let reader = BufferReader(buffer)
                        var result: Api.account.SavedRingtones?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.account.SavedRingtones
                        }
                        return result
                    })
                }
}
public extension Api.functions.account {
                static func getSecureValue(types: [Api.SecureValueType]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Api.SecureValue]>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1936088002)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(types.count))
                    for item in types {
                        item.serialize(buffer, true)
                    }
                    return (FunctionDescription(name: "account.getSecureValue", parameters: [("types", String(describing: types))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> [Api.SecureValue]? in
                        let reader = BufferReader(buffer)
                        var result: [Api.SecureValue]?
                        if let _ = reader.readInt32() {
                            result = Api.parseVector(reader, elementSignature: 0, elementType: Api.SecureValue.self)
                        }
                        return result
                    })
                }
}
public extension Api.functions.account {
                static func getTheme(format: String, theme: Api.InputTheme) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Theme>) {
                    let buffer = Buffer()
                    buffer.appendInt32(978872812)
                    serializeString(format, buffer: buffer, boxed: false)
                    theme.serialize(buffer, true)
                    return (FunctionDescription(name: "account.getTheme", parameters: [("format", String(describing: format)), ("theme", String(describing: theme))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Theme? in
                        let reader = BufferReader(buffer)
                        var result: Api.Theme?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Theme
                        }
                        return result
                    })
                }
}
public extension Api.functions.account {
                static func getThemes(format: String, hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.account.Themes>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1913054296)
                    serializeString(format, buffer: buffer, boxed: false)
                    serializeInt64(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "account.getThemes", parameters: [("format", String(describing: format)), ("hash", String(describing: hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.account.Themes? in
                        let reader = BufferReader(buffer)
                        var result: Api.account.Themes?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.account.Themes
                        }
                        return result
                    })
                }
}
public extension Api.functions.account {
                static func getTmpPassword(password: Api.InputCheckPasswordSRP, period: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.account.TmpPassword>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1151208273)
                    password.serialize(buffer, true)
                    serializeInt32(period, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "account.getTmpPassword", parameters: [("password", String(describing: password)), ("period", String(describing: period))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.account.TmpPassword? in
                        let reader = BufferReader(buffer)
                        var result: Api.account.TmpPassword?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.account.TmpPassword
                        }
                        return result
                    })
                }
}
public extension Api.functions.account {
                static func getWallPaper(wallpaper: Api.InputWallPaper) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.WallPaper>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-57811990)
                    wallpaper.serialize(buffer, true)
                    return (FunctionDescription(name: "account.getWallPaper", parameters: [("wallpaper", String(describing: wallpaper))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.WallPaper? in
                        let reader = BufferReader(buffer)
                        var result: Api.WallPaper?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.WallPaper
                        }
                        return result
                    })
                }
}
public extension Api.functions.account {
                static func getWallPapers(hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.account.WallPapers>) {
                    let buffer = Buffer()
                    buffer.appendInt32(127302966)
                    serializeInt64(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "account.getWallPapers", parameters: [("hash", String(describing: hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.account.WallPapers? in
                        let reader = BufferReader(buffer)
                        var result: Api.account.WallPapers?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.account.WallPapers
                        }
                        return result
                    })
                }
}
public extension Api.functions.account {
                static func getWebAuthorizations() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.account.WebAuthorizations>) {
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
}
public extension Api.functions.account {
                static func initTakeoutSession(flags: Int32, fileMaxSize: Int64?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.account.Takeout>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1896617296)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 5) != 0 {serializeInt64(fileMaxSize!, buffer: buffer, boxed: false)}
                    return (FunctionDescription(name: "account.initTakeoutSession", parameters: [("flags", String(describing: flags)), ("fileMaxSize", String(describing: fileMaxSize))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.account.Takeout? in
                        let reader = BufferReader(buffer)
                        var result: Api.account.Takeout?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.account.Takeout
                        }
                        return result
                    })
                }
}
public extension Api.functions.account {
                static func installTheme(flags: Int32, theme: Api.InputTheme?, format: String?, baseTheme: Api.BaseTheme?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-953697477)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {theme!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeString(format!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 3) != 0 {baseTheme!.serialize(buffer, true)}
                    return (FunctionDescription(name: "account.installTheme", parameters: [("flags", String(describing: flags)), ("theme", String(describing: theme)), ("format", String(describing: format)), ("baseTheme", String(describing: baseTheme))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.account {
                static func installWallPaper(wallpaper: Api.InputWallPaper, settings: Api.WallPaperSettings) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-18000023)
                    wallpaper.serialize(buffer, true)
                    settings.serialize(buffer, true)
                    return (FunctionDescription(name: "account.installWallPaper", parameters: [("wallpaper", String(describing: wallpaper)), ("settings", String(describing: settings))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.account {
                static func registerDevice(flags: Int32, tokenType: Int32, token: String, appSandbox: Api.Bool, secret: Buffer, otherUids: [Int64]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-326762118)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(tokenType, buffer: buffer, boxed: false)
                    serializeString(token, buffer: buffer, boxed: false)
                    appSandbox.serialize(buffer, true)
                    serializeBytes(secret, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(otherUids.count))
                    for item in otherUids {
                        serializeInt64(item, buffer: buffer, boxed: false)
                    }
                    return (FunctionDescription(name: "account.registerDevice", parameters: [("flags", String(describing: flags)), ("tokenType", String(describing: tokenType)), ("token", String(describing: token)), ("appSandbox", String(describing: appSandbox)), ("secret", String(describing: secret)), ("otherUids", String(describing: otherUids))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.account {
                static func reorderUsernames(order: [String]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-279966037)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(order.count))
                    for item in order {
                        serializeString(item, buffer: buffer, boxed: false)
                    }
                    return (FunctionDescription(name: "account.reorderUsernames", parameters: [("order", String(describing: order))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.account {
                static func reportPeer(peer: Api.InputPeer, reason: Api.ReportReason, message: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-977650298)
                    peer.serialize(buffer, true)
                    reason.serialize(buffer, true)
                    serializeString(message, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "account.reportPeer", parameters: [("peer", String(describing: peer)), ("reason", String(describing: reason)), ("message", String(describing: message))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.account {
                static func reportProfilePhoto(peer: Api.InputPeer, photoId: Api.InputPhoto, reason: Api.ReportReason, message: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-91437323)
                    peer.serialize(buffer, true)
                    photoId.serialize(buffer, true)
                    reason.serialize(buffer, true)
                    serializeString(message, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "account.reportProfilePhoto", parameters: [("peer", String(describing: peer)), ("photoId", String(describing: photoId)), ("reason", String(describing: reason)), ("message", String(describing: message))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.account {
                static func resendPasswordEmail() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
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
}
public extension Api.functions.account {
                static func resetAuthorization(hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-545786948)
                    serializeInt64(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "account.resetAuthorization", parameters: [("hash", String(describing: hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.account {
                static func resetNotifySettings() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
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
}
public extension Api.functions.account {
                static func resetPassword() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.account.ResetPasswordResult>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1828139493)
                    
                    return (FunctionDescription(name: "account.resetPassword", parameters: []), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.account.ResetPasswordResult? in
                        let reader = BufferReader(buffer)
                        var result: Api.account.ResetPasswordResult?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.account.ResetPasswordResult
                        }
                        return result
                    })
                }
}
public extension Api.functions.account {
                static func resetWallPapers() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
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
}
public extension Api.functions.account {
                static func resetWebAuthorization(hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(755087855)
                    serializeInt64(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "account.resetWebAuthorization", parameters: [("hash", String(describing: hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.account {
                static func resetWebAuthorizations() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
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
}
public extension Api.functions.account {
                static func saveAutoDownloadSettings(flags: Int32, settings: Api.AutoDownloadSettings) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1995661875)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    settings.serialize(buffer, true)
                    return (FunctionDescription(name: "account.saveAutoDownloadSettings", parameters: [("flags", String(describing: flags)), ("settings", String(describing: settings))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.account {
                static func saveRingtone(id: Api.InputDocument, unsave: Api.Bool) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.account.SavedRingtone>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1038768899)
                    id.serialize(buffer, true)
                    unsave.serialize(buffer, true)
                    return (FunctionDescription(name: "account.saveRingtone", parameters: [("id", String(describing: id)), ("unsave", String(describing: unsave))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.account.SavedRingtone? in
                        let reader = BufferReader(buffer)
                        var result: Api.account.SavedRingtone?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.account.SavedRingtone
                        }
                        return result
                    })
                }
}
public extension Api.functions.account {
                static func saveSecureValue(value: Api.InputSecureValue, secureSecretId: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.SecureValue>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1986010339)
                    value.serialize(buffer, true)
                    serializeInt64(secureSecretId, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "account.saveSecureValue", parameters: [("value", String(describing: value)), ("secureSecretId", String(describing: secureSecretId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.SecureValue? in
                        let reader = BufferReader(buffer)
                        var result: Api.SecureValue?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.SecureValue
                        }
                        return result
                    })
                }
}
public extension Api.functions.account {
                static func saveTheme(theme: Api.InputTheme, unsave: Api.Bool) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-229175188)
                    theme.serialize(buffer, true)
                    unsave.serialize(buffer, true)
                    return (FunctionDescription(name: "account.saveTheme", parameters: [("theme", String(describing: theme)), ("unsave", String(describing: unsave))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.account {
                static func saveWallPaper(wallpaper: Api.InputWallPaper, unsave: Api.Bool, settings: Api.WallPaperSettings) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1817860919)
                    wallpaper.serialize(buffer, true)
                    unsave.serialize(buffer, true)
                    settings.serialize(buffer, true)
                    return (FunctionDescription(name: "account.saveWallPaper", parameters: [("wallpaper", String(describing: wallpaper)), ("unsave", String(describing: unsave)), ("settings", String(describing: settings))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.account {
                static func sendChangePhoneCode(phoneNumber: String, settings: Api.CodeSettings) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.auth.SentCode>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-2108208411)
                    serializeString(phoneNumber, buffer: buffer, boxed: false)
                    settings.serialize(buffer, true)
                    return (FunctionDescription(name: "account.sendChangePhoneCode", parameters: [("phoneNumber", String(describing: phoneNumber)), ("settings", String(describing: settings))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.auth.SentCode? in
                        let reader = BufferReader(buffer)
                        var result: Api.auth.SentCode?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.auth.SentCode
                        }
                        return result
                    })
                }
}
public extension Api.functions.account {
                static func sendConfirmPhoneCode(hash: String, settings: Api.CodeSettings) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.auth.SentCode>) {
                    let buffer = Buffer()
                    buffer.appendInt32(457157256)
                    serializeString(hash, buffer: buffer, boxed: false)
                    settings.serialize(buffer, true)
                    return (FunctionDescription(name: "account.sendConfirmPhoneCode", parameters: [("hash", String(describing: hash)), ("settings", String(describing: settings))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.auth.SentCode? in
                        let reader = BufferReader(buffer)
                        var result: Api.auth.SentCode?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.auth.SentCode
                        }
                        return result
                    })
                }
}
public extension Api.functions.account {
                static func sendVerifyEmailCode(purpose: Api.EmailVerifyPurpose, email: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.account.SentEmailCode>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1730136133)
                    purpose.serialize(buffer, true)
                    serializeString(email, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "account.sendVerifyEmailCode", parameters: [("purpose", String(describing: purpose)), ("email", String(describing: email))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.account.SentEmailCode? in
                        let reader = BufferReader(buffer)
                        var result: Api.account.SentEmailCode?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.account.SentEmailCode
                        }
                        return result
                    })
                }
}
public extension Api.functions.account {
                static func sendVerifyPhoneCode(phoneNumber: String, settings: Api.CodeSettings) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.auth.SentCode>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1516022023)
                    serializeString(phoneNumber, buffer: buffer, boxed: false)
                    settings.serialize(buffer, true)
                    return (FunctionDescription(name: "account.sendVerifyPhoneCode", parameters: [("phoneNumber", String(describing: phoneNumber)), ("settings", String(describing: settings))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.auth.SentCode? in
                        let reader = BufferReader(buffer)
                        var result: Api.auth.SentCode?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.auth.SentCode
                        }
                        return result
                    })
                }
}
public extension Api.functions.account {
                static func setAccountTTL(ttl: Api.AccountDaysTTL) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(608323678)
                    ttl.serialize(buffer, true)
                    return (FunctionDescription(name: "account.setAccountTTL", parameters: [("ttl", String(describing: ttl))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.account {
                static func setAuthorizationTTL(authorizationTtlDays: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1081501024)
                    serializeInt32(authorizationTtlDays, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "account.setAuthorizationTTL", parameters: [("authorizationTtlDays", String(describing: authorizationTtlDays))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.account {
                static func setContactSignUpNotification(silent: Api.Bool) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-806076575)
                    silent.serialize(buffer, true)
                    return (FunctionDescription(name: "account.setContactSignUpNotification", parameters: [("silent", String(describing: silent))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.account {
                static func setContentSettings(flags: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1250643605)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "account.setContentSettings", parameters: [("flags", String(describing: flags))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.account {
                static func setGlobalPrivacySettings(settings: Api.GlobalPrivacySettings) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.GlobalPrivacySettings>) {
                    let buffer = Buffer()
                    buffer.appendInt32(517647042)
                    settings.serialize(buffer, true)
                    return (FunctionDescription(name: "account.setGlobalPrivacySettings", parameters: [("settings", String(describing: settings))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.GlobalPrivacySettings? in
                        let reader = BufferReader(buffer)
                        var result: Api.GlobalPrivacySettings?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.GlobalPrivacySettings
                        }
                        return result
                    })
                }
}
public extension Api.functions.account {
                static func setPrivacy(key: Api.InputPrivacyKey, rules: [Api.InputPrivacyRule]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.account.PrivacyRules>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-906486552)
                    key.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(rules.count))
                    for item in rules {
                        item.serialize(buffer, true)
                    }
                    return (FunctionDescription(name: "account.setPrivacy", parameters: [("key", String(describing: key)), ("rules", String(describing: rules))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.account.PrivacyRules? in
                        let reader = BufferReader(buffer)
                        var result: Api.account.PrivacyRules?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.account.PrivacyRules
                        }
                        return result
                    })
                }
}
public extension Api.functions.account {
                static func toggleUsername(username: String, active: Api.Bool) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1490465654)
                    serializeString(username, buffer: buffer, boxed: false)
                    active.serialize(buffer, true)
                    return (FunctionDescription(name: "account.toggleUsername", parameters: [("username", String(describing: username)), ("active", String(describing: active))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.account {
                static func unregisterDevice(tokenType: Int32, token: String, otherUids: [Int64]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1779249670)
                    serializeInt32(tokenType, buffer: buffer, boxed: false)
                    serializeString(token, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(otherUids.count))
                    for item in otherUids {
                        serializeInt64(item, buffer: buffer, boxed: false)
                    }
                    return (FunctionDescription(name: "account.unregisterDevice", parameters: [("tokenType", String(describing: tokenType)), ("token", String(describing: token)), ("otherUids", String(describing: otherUids))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.account {
                static func updateDeviceLocked(period: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(954152242)
                    serializeInt32(period, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "account.updateDeviceLocked", parameters: [("period", String(describing: period))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.account {
                static func updateEmojiStatus(emojiStatus: Api.EmojiStatus) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-70001045)
                    emojiStatus.serialize(buffer, true)
                    return (FunctionDescription(name: "account.updateEmojiStatus", parameters: [("emojiStatus", String(describing: emojiStatus))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.account {
                static func updateNotifySettings(peer: Api.InputNotifyPeer, settings: Api.InputPeerNotifySettings) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-2067899501)
                    peer.serialize(buffer, true)
                    settings.serialize(buffer, true)
                    return (FunctionDescription(name: "account.updateNotifySettings", parameters: [("peer", String(describing: peer)), ("settings", String(describing: settings))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.account {
                static func updatePasswordSettings(password: Api.InputCheckPasswordSRP, newSettings: Api.account.PasswordInputSettings) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1516564433)
                    password.serialize(buffer, true)
                    newSettings.serialize(buffer, true)
                    return (FunctionDescription(name: "account.updatePasswordSettings", parameters: [("password", String(describing: password)), ("newSettings", String(describing: newSettings))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.account {
                static func updateProfile(flags: Int32, firstName: String?, lastName: String?, about: String?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.User>) {
                    let buffer = Buffer()
                    buffer.appendInt32(2018596725)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(firstName!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(lastName!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeString(about!, buffer: buffer, boxed: false)}
                    return (FunctionDescription(name: "account.updateProfile", parameters: [("flags", String(describing: flags)), ("firstName", String(describing: firstName)), ("lastName", String(describing: lastName)), ("about", String(describing: about))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.User? in
                        let reader = BufferReader(buffer)
                        var result: Api.User?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.User
                        }
                        return result
                    })
                }
}
public extension Api.functions.account {
                static func updateStatus(offline: Api.Bool) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1713919532)
                    offline.serialize(buffer, true)
                    return (FunctionDescription(name: "account.updateStatus", parameters: [("offline", String(describing: offline))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.account {
                static func updateTheme(flags: Int32, format: String, theme: Api.InputTheme, slug: String?, title: String?, document: Api.InputDocument?, settings: [Api.InputThemeSettings]?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Theme>) {
                    let buffer = Buffer()
                    buffer.appendInt32(737414348)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(format, buffer: buffer, boxed: false)
                    theme.serialize(buffer, true)
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(slug!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(title!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {document!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 3) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(settings!.count))
                    for item in settings! {
                        item.serialize(buffer, true)
                    }}
                    return (FunctionDescription(name: "account.updateTheme", parameters: [("flags", String(describing: flags)), ("format", String(describing: format)), ("theme", String(describing: theme)), ("slug", String(describing: slug)), ("title", String(describing: title)), ("document", String(describing: document)), ("settings", String(describing: settings))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Theme? in
                        let reader = BufferReader(buffer)
                        var result: Api.Theme?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Theme
                        }
                        return result
                    })
                }
}
public extension Api.functions.account {
                static func updateUsername(username: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.User>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1040964988)
                    serializeString(username, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "account.updateUsername", parameters: [("username", String(describing: username))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.User? in
                        let reader = BufferReader(buffer)
                        var result: Api.User?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.User
                        }
                        return result
                    })
                }
}
public extension Api.functions.account {
                static func uploadRingtone(file: Api.InputFile, fileName: String, mimeType: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Document>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-2095414366)
                    file.serialize(buffer, true)
                    serializeString(fileName, buffer: buffer, boxed: false)
                    serializeString(mimeType, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "account.uploadRingtone", parameters: [("file", String(describing: file)), ("fileName", String(describing: fileName)), ("mimeType", String(describing: mimeType))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Document? in
                        let reader = BufferReader(buffer)
                        var result: Api.Document?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Document
                        }
                        return result
                    })
                }
}
public extension Api.functions.account {
                static func uploadTheme(flags: Int32, file: Api.InputFile, thumb: Api.InputFile?, fileName: String, mimeType: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Document>) {
                    let buffer = Buffer()
                    buffer.appendInt32(473805619)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    file.serialize(buffer, true)
                    if Int(flags) & Int(1 << 0) != 0 {thumb!.serialize(buffer, true)}
                    serializeString(fileName, buffer: buffer, boxed: false)
                    serializeString(mimeType, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "account.uploadTheme", parameters: [("flags", String(describing: flags)), ("file", String(describing: file)), ("thumb", String(describing: thumb)), ("fileName", String(describing: fileName)), ("mimeType", String(describing: mimeType))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Document? in
                        let reader = BufferReader(buffer)
                        var result: Api.Document?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Document
                        }
                        return result
                    })
                }
}
public extension Api.functions.account {
                static func uploadWallPaper(file: Api.InputFile, mimeType: String, settings: Api.WallPaperSettings) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.WallPaper>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-578472351)
                    file.serialize(buffer, true)
                    serializeString(mimeType, buffer: buffer, boxed: false)
                    settings.serialize(buffer, true)
                    return (FunctionDescription(name: "account.uploadWallPaper", parameters: [("file", String(describing: file)), ("mimeType", String(describing: mimeType)), ("settings", String(describing: settings))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.WallPaper? in
                        let reader = BufferReader(buffer)
                        var result: Api.WallPaper?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.WallPaper
                        }
                        return result
                    })
                }
}
public extension Api.functions.account {
                static func verifyEmail(purpose: Api.EmailVerifyPurpose, verification: Api.EmailVerification) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.account.EmailVerified>) {
                    let buffer = Buffer()
                    buffer.appendInt32(53322959)
                    purpose.serialize(buffer, true)
                    verification.serialize(buffer, true)
                    return (FunctionDescription(name: "account.verifyEmail", parameters: [("purpose", String(describing: purpose)), ("verification", String(describing: verification))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.account.EmailVerified? in
                        let reader = BufferReader(buffer)
                        var result: Api.account.EmailVerified?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.account.EmailVerified
                        }
                        return result
                    })
                }
}
public extension Api.functions.account {
                static func verifyPhone(phoneNumber: String, phoneCodeHash: String, phoneCode: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1305716726)
                    serializeString(phoneNumber, buffer: buffer, boxed: false)
                    serializeString(phoneCodeHash, buffer: buffer, boxed: false)
                    serializeString(phoneCode, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "account.verifyPhone", parameters: [("phoneNumber", String(describing: phoneNumber)), ("phoneCodeHash", String(describing: phoneCodeHash)), ("phoneCode", String(describing: phoneCode))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.auth {
                static func acceptLoginToken(token: Buffer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Authorization>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-392909491)
                    serializeBytes(token, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "auth.acceptLoginToken", parameters: [("token", String(describing: token))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Authorization? in
                        let reader = BufferReader(buffer)
                        var result: Api.Authorization?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Authorization
                        }
                        return result
                    })
                }
}
public extension Api.functions.auth {
                static func bindTempAuthKey(permAuthKeyId: Int64, nonce: Int64, expiresAt: Int32, encryptedMessage: Buffer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-841733627)
                    serializeInt64(permAuthKeyId, buffer: buffer, boxed: false)
                    serializeInt64(nonce, buffer: buffer, boxed: false)
                    serializeInt32(expiresAt, buffer: buffer, boxed: false)
                    serializeBytes(encryptedMessage, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "auth.bindTempAuthKey", parameters: [("permAuthKeyId", String(describing: permAuthKeyId)), ("nonce", String(describing: nonce)), ("expiresAt", String(describing: expiresAt)), ("encryptedMessage", String(describing: encryptedMessage))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.auth {
                static func cancelCode(phoneNumber: String, phoneCodeHash: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(520357240)
                    serializeString(phoneNumber, buffer: buffer, boxed: false)
                    serializeString(phoneCodeHash, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "auth.cancelCode", parameters: [("phoneNumber", String(describing: phoneNumber)), ("phoneCodeHash", String(describing: phoneCodeHash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.auth {
                static func checkPassword(password: Api.InputCheckPasswordSRP) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.auth.Authorization>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-779399914)
                    password.serialize(buffer, true)
                    return (FunctionDescription(name: "auth.checkPassword", parameters: [("password", String(describing: password))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.auth.Authorization? in
                        let reader = BufferReader(buffer)
                        var result: Api.auth.Authorization?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.auth.Authorization
                        }
                        return result
                    })
                }
}
public extension Api.functions.auth {
                static func checkRecoveryPassword(code: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(221691769)
                    serializeString(code, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "auth.checkRecoveryPassword", parameters: [("code", String(describing: code))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.auth {
                static func dropTempAuthKeys(exceptAuthKeys: [Int64]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1907842680)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(exceptAuthKeys.count))
                    for item in exceptAuthKeys {
                        serializeInt64(item, buffer: buffer, boxed: false)
                    }
                    return (FunctionDescription(name: "auth.dropTempAuthKeys", parameters: [("exceptAuthKeys", String(describing: exceptAuthKeys))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.auth {
                static func exportAuthorization(dcId: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.auth.ExportedAuthorization>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-440401971)
                    serializeInt32(dcId, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "auth.exportAuthorization", parameters: [("dcId", String(describing: dcId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.auth.ExportedAuthorization? in
                        let reader = BufferReader(buffer)
                        var result: Api.auth.ExportedAuthorization?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.auth.ExportedAuthorization
                        }
                        return result
                    })
                }
}
public extension Api.functions.auth {
                static func exportLoginToken(apiId: Int32, apiHash: String, exceptIds: [Int64]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.auth.LoginToken>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1210022402)
                    serializeInt32(apiId, buffer: buffer, boxed: false)
                    serializeString(apiHash, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(exceptIds.count))
                    for item in exceptIds {
                        serializeInt64(item, buffer: buffer, boxed: false)
                    }
                    return (FunctionDescription(name: "auth.exportLoginToken", parameters: [("apiId", String(describing: apiId)), ("apiHash", String(describing: apiHash)), ("exceptIds", String(describing: exceptIds))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.auth.LoginToken? in
                        let reader = BufferReader(buffer)
                        var result: Api.auth.LoginToken?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.auth.LoginToken
                        }
                        return result
                    })
                }
}
public extension Api.functions.auth {
                static func importAuthorization(id: Int64, bytes: Buffer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.auth.Authorization>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1518699091)
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeBytes(bytes, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "auth.importAuthorization", parameters: [("id", String(describing: id)), ("bytes", String(describing: bytes))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.auth.Authorization? in
                        let reader = BufferReader(buffer)
                        var result: Api.auth.Authorization?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.auth.Authorization
                        }
                        return result
                    })
                }
}
public extension Api.functions.auth {
                static func importBotAuthorization(flags: Int32, apiId: Int32, apiHash: String, botAuthToken: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.auth.Authorization>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1738800940)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(apiId, buffer: buffer, boxed: false)
                    serializeString(apiHash, buffer: buffer, boxed: false)
                    serializeString(botAuthToken, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "auth.importBotAuthorization", parameters: [("flags", String(describing: flags)), ("apiId", String(describing: apiId)), ("apiHash", String(describing: apiHash)), ("botAuthToken", String(describing: botAuthToken))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.auth.Authorization? in
                        let reader = BufferReader(buffer)
                        var result: Api.auth.Authorization?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.auth.Authorization
                        }
                        return result
                    })
                }
}
public extension Api.functions.auth {
                static func importLoginToken(token: Buffer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.auth.LoginToken>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1783866140)
                    serializeBytes(token, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "auth.importLoginToken", parameters: [("token", String(describing: token))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.auth.LoginToken? in
                        let reader = BufferReader(buffer)
                        var result: Api.auth.LoginToken?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.auth.LoginToken
                        }
                        return result
                    })
                }
}
public extension Api.functions.auth {
                static func logOut() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.auth.LoggedOut>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1047706137)
                    
                    return (FunctionDescription(name: "auth.logOut", parameters: []), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.auth.LoggedOut? in
                        let reader = BufferReader(buffer)
                        var result: Api.auth.LoggedOut?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.auth.LoggedOut
                        }
                        return result
                    })
                }
}
public extension Api.functions.auth {
                static func recoverPassword(flags: Int32, code: String, newSettings: Api.account.PasswordInputSettings?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.auth.Authorization>) {
                    let buffer = Buffer()
                    buffer.appendInt32(923364464)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(code, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {newSettings!.serialize(buffer, true)}
                    return (FunctionDescription(name: "auth.recoverPassword", parameters: [("flags", String(describing: flags)), ("code", String(describing: code)), ("newSettings", String(describing: newSettings))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.auth.Authorization? in
                        let reader = BufferReader(buffer)
                        var result: Api.auth.Authorization?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.auth.Authorization
                        }
                        return result
                    })
                }
}
public extension Api.functions.auth {
                static func requestPasswordRecovery() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.auth.PasswordRecovery>) {
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
}
public extension Api.functions.auth {
                static func resendCode(phoneNumber: String, phoneCodeHash: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.auth.SentCode>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1056025023)
                    serializeString(phoneNumber, buffer: buffer, boxed: false)
                    serializeString(phoneCodeHash, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "auth.resendCode", parameters: [("phoneNumber", String(describing: phoneNumber)), ("phoneCodeHash", String(describing: phoneCodeHash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.auth.SentCode? in
                        let reader = BufferReader(buffer)
                        var result: Api.auth.SentCode?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.auth.SentCode
                        }
                        return result
                    })
                }
}
public extension Api.functions.auth {
                static func resetAuthorizations() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
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
}
public extension Api.functions.auth {
                static func sendCode(phoneNumber: String, apiId: Int32, apiHash: String, settings: Api.CodeSettings) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.auth.SentCode>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1502141361)
                    serializeString(phoneNumber, buffer: buffer, boxed: false)
                    serializeInt32(apiId, buffer: buffer, boxed: false)
                    serializeString(apiHash, buffer: buffer, boxed: false)
                    settings.serialize(buffer, true)
                    return (FunctionDescription(name: "auth.sendCode", parameters: [("phoneNumber", String(describing: phoneNumber)), ("apiId", String(describing: apiId)), ("apiHash", String(describing: apiHash)), ("settings", String(describing: settings))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.auth.SentCode? in
                        let reader = BufferReader(buffer)
                        var result: Api.auth.SentCode?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.auth.SentCode
                        }
                        return result
                    })
                }
}
public extension Api.functions.auth {
                static func signIn(flags: Int32, phoneNumber: String, phoneCodeHash: String, phoneCode: String?, emailVerification: Api.EmailVerification?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.auth.Authorization>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1923962543)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(phoneNumber, buffer: buffer, boxed: false)
                    serializeString(phoneCodeHash, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(phoneCode!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {emailVerification!.serialize(buffer, true)}
                    return (FunctionDescription(name: "auth.signIn", parameters: [("flags", String(describing: flags)), ("phoneNumber", String(describing: phoneNumber)), ("phoneCodeHash", String(describing: phoneCodeHash)), ("phoneCode", String(describing: phoneCode)), ("emailVerification", String(describing: emailVerification))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.auth.Authorization? in
                        let reader = BufferReader(buffer)
                        var result: Api.auth.Authorization?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.auth.Authorization
                        }
                        return result
                    })
                }
}
public extension Api.functions.auth {
                static func signUp(phoneNumber: String, phoneCodeHash: String, firstName: String, lastName: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.auth.Authorization>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-2131827673)
                    serializeString(phoneNumber, buffer: buffer, boxed: false)
                    serializeString(phoneCodeHash, buffer: buffer, boxed: false)
                    serializeString(firstName, buffer: buffer, boxed: false)
                    serializeString(lastName, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "auth.signUp", parameters: [("phoneNumber", String(describing: phoneNumber)), ("phoneCodeHash", String(describing: phoneCodeHash)), ("firstName", String(describing: firstName)), ("lastName", String(describing: lastName))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.auth.Authorization? in
                        let reader = BufferReader(buffer)
                        var result: Api.auth.Authorization?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.auth.Authorization
                        }
                        return result
                    })
                }
}
public extension Api.functions.bots {
                static func answerWebhookJSONQuery(queryId: Int64, data: Api.DataJSON) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-434028723)
                    serializeInt64(queryId, buffer: buffer, boxed: false)
                    data.serialize(buffer, true)
                    return (FunctionDescription(name: "bots.answerWebhookJSONQuery", parameters: [("queryId", String(describing: queryId)), ("data", String(describing: data))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.bots {
                static func getBotCommands(scope: Api.BotCommandScope, langCode: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Api.BotCommand]>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-481554986)
                    scope.serialize(buffer, true)
                    serializeString(langCode, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "bots.getBotCommands", parameters: [("scope", String(describing: scope)), ("langCode", String(describing: langCode))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> [Api.BotCommand]? in
                        let reader = BufferReader(buffer)
                        var result: [Api.BotCommand]?
                        if let _ = reader.readInt32() {
                            result = Api.parseVector(reader, elementSignature: 0, elementType: Api.BotCommand.self)
                        }
                        return result
                    })
                }
}
public extension Api.functions.bots {
                static func getBotMenuButton(userId: Api.InputUser) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.BotMenuButton>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1671369944)
                    userId.serialize(buffer, true)
                    return (FunctionDescription(name: "bots.getBotMenuButton", parameters: [("userId", String(describing: userId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.BotMenuButton? in
                        let reader = BufferReader(buffer)
                        var result: Api.BotMenuButton?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.BotMenuButton
                        }
                        return result
                    })
                }
}
public extension Api.functions.bots {
                static func resetBotCommands(scope: Api.BotCommandScope, langCode: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1032708345)
                    scope.serialize(buffer, true)
                    serializeString(langCode, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "bots.resetBotCommands", parameters: [("scope", String(describing: scope)), ("langCode", String(describing: langCode))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.bots {
                static func sendCustomRequest(customMethod: String, params: Api.DataJSON) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.DataJSON>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1440257555)
                    serializeString(customMethod, buffer: buffer, boxed: false)
                    params.serialize(buffer, true)
                    return (FunctionDescription(name: "bots.sendCustomRequest", parameters: [("customMethod", String(describing: customMethod)), ("params", String(describing: params))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.DataJSON? in
                        let reader = BufferReader(buffer)
                        var result: Api.DataJSON?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.DataJSON
                        }
                        return result
                    })
                }
}
public extension Api.functions.bots {
                static func setBotBroadcastDefaultAdminRights(adminRights: Api.ChatAdminRights) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(2021942497)
                    adminRights.serialize(buffer, true)
                    return (FunctionDescription(name: "bots.setBotBroadcastDefaultAdminRights", parameters: [("adminRights", String(describing: adminRights))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.bots {
                static func setBotCommands(scope: Api.BotCommandScope, langCode: String, commands: [Api.BotCommand]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(85399130)
                    scope.serialize(buffer, true)
                    serializeString(langCode, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(commands.count))
                    for item in commands {
                        item.serialize(buffer, true)
                    }
                    return (FunctionDescription(name: "bots.setBotCommands", parameters: [("scope", String(describing: scope)), ("langCode", String(describing: langCode)), ("commands", String(describing: commands))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.bots {
                static func setBotGroupDefaultAdminRights(adminRights: Api.ChatAdminRights) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1839281686)
                    adminRights.serialize(buffer, true)
                    return (FunctionDescription(name: "bots.setBotGroupDefaultAdminRights", parameters: [("adminRights", String(describing: adminRights))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.bots {
                static func setBotMenuButton(userId: Api.InputUser, button: Api.BotMenuButton) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1157944655)
                    userId.serialize(buffer, true)
                    button.serialize(buffer, true)
                    return (FunctionDescription(name: "bots.setBotMenuButton", parameters: [("userId", String(describing: userId)), ("button", String(describing: button))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.channels {
                static func checkUsername(channel: Api.InputChannel, username: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(283557164)
                    channel.serialize(buffer, true)
                    serializeString(username, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "channels.checkUsername", parameters: [("channel", String(describing: channel)), ("username", String(describing: username))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.channels {
                static func convertToGigagroup(channel: Api.InputChannel) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(187239529)
                    channel.serialize(buffer, true)
                    return (FunctionDescription(name: "channels.convertToGigagroup", parameters: [("channel", String(describing: channel))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
}
public extension Api.functions.channels {
                static func createChannel(flags: Int32, title: String, about: String, geoPoint: Api.InputGeoPoint?, address: String?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1029681423)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(title, buffer: buffer, boxed: false)
                    serializeString(about, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 2) != 0 {geoPoint!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeString(address!, buffer: buffer, boxed: false)}
                    return (FunctionDescription(name: "channels.createChannel", parameters: [("flags", String(describing: flags)), ("title", String(describing: title)), ("about", String(describing: about)), ("geoPoint", String(describing: geoPoint)), ("address", String(describing: address))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
}
public extension Api.functions.channels {
                static func createForumTopic(flags: Int32, channel: Api.InputChannel, title: String, iconColor: Int32?, iconEmojiId: Int64?, randomId: Int64, sendAs: Api.InputPeer?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-200539612)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    channel.serialize(buffer, true)
                    serializeString(title, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(iconColor!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 3) != 0 {serializeInt64(iconEmojiId!, buffer: buffer, boxed: false)}
                    serializeInt64(randomId, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 2) != 0 {sendAs!.serialize(buffer, true)}
                    return (FunctionDescription(name: "channels.createForumTopic", parameters: [("flags", String(describing: flags)), ("channel", String(describing: channel)), ("title", String(describing: title)), ("iconColor", String(describing: iconColor)), ("iconEmojiId", String(describing: iconEmojiId)), ("randomId", String(describing: randomId)), ("sendAs", String(describing: sendAs))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
}
public extension Api.functions.channels {
                static func deactivateAllUsernames(channel: Api.InputChannel) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(170155475)
                    channel.serialize(buffer, true)
                    return (FunctionDescription(name: "channels.deactivateAllUsernames", parameters: [("channel", String(describing: channel))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.channels {
                static func deleteChannel(channel: Api.InputChannel) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1072619549)
                    channel.serialize(buffer, true)
                    return (FunctionDescription(name: "channels.deleteChannel", parameters: [("channel", String(describing: channel))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
}
public extension Api.functions.channels {
                static func deleteHistory(flags: Int32, channel: Api.InputChannel, maxId: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1683319225)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    channel.serialize(buffer, true)
                    serializeInt32(maxId, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "channels.deleteHistory", parameters: [("flags", String(describing: flags)), ("channel", String(describing: channel)), ("maxId", String(describing: maxId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
}
public extension Api.functions.channels {
                static func deleteMessages(channel: Api.InputChannel, id: [Int32]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.AffectedMessages>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-2067661490)
                    channel.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(id.count))
                    for item in id {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    return (FunctionDescription(name: "channels.deleteMessages", parameters: [("channel", String(describing: channel)), ("id", String(describing: id))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.AffectedMessages? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.AffectedMessages?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.AffectedMessages
                        }
                        return result
                    })
                }
}
public extension Api.functions.channels {
                static func deleteParticipantHistory(channel: Api.InputChannel, participant: Api.InputPeer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.AffectedHistory>) {
                    let buffer = Buffer()
                    buffer.appendInt32(913655003)
                    channel.serialize(buffer, true)
                    participant.serialize(buffer, true)
                    return (FunctionDescription(name: "channels.deleteParticipantHistory", parameters: [("channel", String(describing: channel)), ("participant", String(describing: participant))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.AffectedHistory? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.AffectedHistory?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.AffectedHistory
                        }
                        return result
                    })
                }
}
public extension Api.functions.channels {
                static func deleteTopicHistory(channel: Api.InputChannel, topMsgId: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.AffectedHistory>) {
                    let buffer = Buffer()
                    buffer.appendInt32(876830509)
                    channel.serialize(buffer, true)
                    serializeInt32(topMsgId, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "channels.deleteTopicHistory", parameters: [("channel", String(describing: channel)), ("topMsgId", String(describing: topMsgId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.AffectedHistory? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.AffectedHistory?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.AffectedHistory
                        }
                        return result
                    })
                }
}
public extension Api.functions.channels {
                static func editAdmin(channel: Api.InputChannel, userId: Api.InputUser, adminRights: Api.ChatAdminRights, rank: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-751007486)
                    channel.serialize(buffer, true)
                    userId.serialize(buffer, true)
                    adminRights.serialize(buffer, true)
                    serializeString(rank, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "channels.editAdmin", parameters: [("channel", String(describing: channel)), ("userId", String(describing: userId)), ("adminRights", String(describing: adminRights)), ("rank", String(describing: rank))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
}
public extension Api.functions.channels {
                static func editBanned(channel: Api.InputChannel, participant: Api.InputPeer, bannedRights: Api.ChatBannedRights) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1763259007)
                    channel.serialize(buffer, true)
                    participant.serialize(buffer, true)
                    bannedRights.serialize(buffer, true)
                    return (FunctionDescription(name: "channels.editBanned", parameters: [("channel", String(describing: channel)), ("participant", String(describing: participant)), ("bannedRights", String(describing: bannedRights))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
}
public extension Api.functions.channels {
                static func editCreator(channel: Api.InputChannel, userId: Api.InputUser, password: Api.InputCheckPasswordSRP) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1892102881)
                    channel.serialize(buffer, true)
                    userId.serialize(buffer, true)
                    password.serialize(buffer, true)
                    return (FunctionDescription(name: "channels.editCreator", parameters: [("channel", String(describing: channel)), ("userId", String(describing: userId)), ("password", String(describing: password))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
}
public extension Api.functions.channels {
                static func editForumTopic(flags: Int32, channel: Api.InputChannel, topicId: Int32, title: String?, iconEmojiId: Int64?, closed: Api.Bool?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1820868141)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    channel.serialize(buffer, true)
                    serializeInt32(topicId, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(title!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt64(iconEmojiId!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {closed!.serialize(buffer, true)}
                    return (FunctionDescription(name: "channels.editForumTopic", parameters: [("flags", String(describing: flags)), ("channel", String(describing: channel)), ("topicId", String(describing: topicId)), ("title", String(describing: title)), ("iconEmojiId", String(describing: iconEmojiId)), ("closed", String(describing: closed))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
}
public extension Api.functions.channels {
                static func editLocation(channel: Api.InputChannel, geoPoint: Api.InputGeoPoint, address: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1491484525)
                    channel.serialize(buffer, true)
                    geoPoint.serialize(buffer, true)
                    serializeString(address, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "channels.editLocation", parameters: [("channel", String(describing: channel)), ("geoPoint", String(describing: geoPoint)), ("address", String(describing: address))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.channels {
                static func editPhoto(channel: Api.InputChannel, photo: Api.InputChatPhoto) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-248621111)
                    channel.serialize(buffer, true)
                    photo.serialize(buffer, true)
                    return (FunctionDescription(name: "channels.editPhoto", parameters: [("channel", String(describing: channel)), ("photo", String(describing: photo))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
}
public extension Api.functions.channels {
                static func editTitle(channel: Api.InputChannel, title: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1450044624)
                    channel.serialize(buffer, true)
                    serializeString(title, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "channels.editTitle", parameters: [("channel", String(describing: channel)), ("title", String(describing: title))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
}
public extension Api.functions.channels {
                static func exportMessageLink(flags: Int32, channel: Api.InputChannel, id: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.ExportedMessageLink>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-432034325)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    channel.serialize(buffer, true)
                    serializeInt32(id, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "channels.exportMessageLink", parameters: [("flags", String(describing: flags)), ("channel", String(describing: channel)), ("id", String(describing: id))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.ExportedMessageLink? in
                        let reader = BufferReader(buffer)
                        var result: Api.ExportedMessageLink?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.ExportedMessageLink
                        }
                        return result
                    })
                }
}
public extension Api.functions.channels {
                static func getAdminLog(flags: Int32, channel: Api.InputChannel, q: String, eventsFilter: Api.ChannelAdminLogEventsFilter?, admins: [Api.InputUser]?, maxId: Int64, minId: Int64, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.channels.AdminLogResults>) {
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
                    return (FunctionDescription(name: "channels.getAdminLog", parameters: [("flags", String(describing: flags)), ("channel", String(describing: channel)), ("q", String(describing: q)), ("eventsFilter", String(describing: eventsFilter)), ("admins", String(describing: admins)), ("maxId", String(describing: maxId)), ("minId", String(describing: minId)), ("limit", String(describing: limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.channels.AdminLogResults? in
                        let reader = BufferReader(buffer)
                        var result: Api.channels.AdminLogResults?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.channels.AdminLogResults
                        }
                        return result
                    })
                }
}
public extension Api.functions.channels {
                static func getAdminedPublicChannels(flags: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.Chats>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-122669393)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "channels.getAdminedPublicChannels", parameters: [("flags", String(describing: flags))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.Chats? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.Chats?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.Chats
                        }
                        return result
                    })
                }
}
public extension Api.functions.channels {
                static func getChannels(id: [Api.InputChannel]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.Chats>) {
                    let buffer = Buffer()
                    buffer.appendInt32(176122811)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(id.count))
                    for item in id {
                        item.serialize(buffer, true)
                    }
                    return (FunctionDescription(name: "channels.getChannels", parameters: [("id", String(describing: id))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.Chats? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.Chats?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.Chats
                        }
                        return result
                    })
                }
}
public extension Api.functions.channels {
                static func getForumTopics(flags: Int32, channel: Api.InputChannel, q: String?, offsetDate: Int32, offsetId: Int32, offsetTopic: Int32, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.ForumTopics>) {
                    let buffer = Buffer()
                    buffer.appendInt32(233136337)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    channel.serialize(buffer, true)
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(q!, buffer: buffer, boxed: false)}
                    serializeInt32(offsetDate, buffer: buffer, boxed: false)
                    serializeInt32(offsetId, buffer: buffer, boxed: false)
                    serializeInt32(offsetTopic, buffer: buffer, boxed: false)
                    serializeInt32(limit, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "channels.getForumTopics", parameters: [("flags", String(describing: flags)), ("channel", String(describing: channel)), ("q", String(describing: q)), ("offsetDate", String(describing: offsetDate)), ("offsetId", String(describing: offsetId)), ("offsetTopic", String(describing: offsetTopic)), ("limit", String(describing: limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.ForumTopics? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.ForumTopics?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.ForumTopics
                        }
                        return result
                    })
                }
}
public extension Api.functions.channels {
                static func getForumTopicsByID(channel: Api.InputChannel, topics: [Int32]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.ForumTopics>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1333584199)
                    channel.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(topics.count))
                    for item in topics {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    return (FunctionDescription(name: "channels.getForumTopicsByID", parameters: [("channel", String(describing: channel)), ("topics", String(describing: topics))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.ForumTopics? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.ForumTopics?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.ForumTopics
                        }
                        return result
                    })
                }
}
public extension Api.functions.channels {
                static func getFullChannel(channel: Api.InputChannel) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.ChatFull>) {
                    let buffer = Buffer()
                    buffer.appendInt32(141781513)
                    channel.serialize(buffer, true)
                    return (FunctionDescription(name: "channels.getFullChannel", parameters: [("channel", String(describing: channel))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.ChatFull? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.ChatFull?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.ChatFull
                        }
                        return result
                    })
                }
}
public extension Api.functions.channels {
                static func getGroupsForDiscussion() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.Chats>) {
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
}
public extension Api.functions.channels {
                static func getInactiveChannels() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.InactiveChats>) {
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
public extension Api.functions.channels {
                static func getLeftChannels(offset: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.Chats>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-2092831552)
                    serializeInt32(offset, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "channels.getLeftChannels", parameters: [("offset", String(describing: offset))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.Chats? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.Chats?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.Chats
                        }
                        return result
                    })
                }
}
public extension Api.functions.channels {
                static func getMessages(channel: Api.InputChannel, id: [Api.InputMessage]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.Messages>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1383294429)
                    channel.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(id.count))
                    for item in id {
                        item.serialize(buffer, true)
                    }
                    return (FunctionDescription(name: "channels.getMessages", parameters: [("channel", String(describing: channel)), ("id", String(describing: id))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.Messages? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.Messages?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.Messages
                        }
                        return result
                    })
                }
}
public extension Api.functions.channels {
                static func getParticipant(channel: Api.InputChannel, participant: Api.InputPeer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.channels.ChannelParticipant>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1599378234)
                    channel.serialize(buffer, true)
                    participant.serialize(buffer, true)
                    return (FunctionDescription(name: "channels.getParticipant", parameters: [("channel", String(describing: channel)), ("participant", String(describing: participant))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.channels.ChannelParticipant? in
                        let reader = BufferReader(buffer)
                        var result: Api.channels.ChannelParticipant?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.channels.ChannelParticipant
                        }
                        return result
                    })
                }
}
public extension Api.functions.channels {
                static func getParticipants(channel: Api.InputChannel, filter: Api.ChannelParticipantsFilter, offset: Int32, limit: Int32, hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.channels.ChannelParticipants>) {
                    let buffer = Buffer()
                    buffer.appendInt32(2010044880)
                    channel.serialize(buffer, true)
                    filter.serialize(buffer, true)
                    serializeInt32(offset, buffer: buffer, boxed: false)
                    serializeInt32(limit, buffer: buffer, boxed: false)
                    serializeInt64(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "channels.getParticipants", parameters: [("channel", String(describing: channel)), ("filter", String(describing: filter)), ("offset", String(describing: offset)), ("limit", String(describing: limit)), ("hash", String(describing: hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.channels.ChannelParticipants? in
                        let reader = BufferReader(buffer)
                        var result: Api.channels.ChannelParticipants?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.channels.ChannelParticipants
                        }
                        return result
                    })
                }
}
public extension Api.functions.channels {
                static func getSendAs(peer: Api.InputPeer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.channels.SendAsPeers>) {
                    let buffer = Buffer()
                    buffer.appendInt32(231174382)
                    peer.serialize(buffer, true)
                    return (FunctionDescription(name: "channels.getSendAs", parameters: [("peer", String(describing: peer))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.channels.SendAsPeers? in
                        let reader = BufferReader(buffer)
                        var result: Api.channels.SendAsPeers?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.channels.SendAsPeers
                        }
                        return result
                    })
                }
}
public extension Api.functions.channels {
                static func getSponsoredMessages(channel: Api.InputChannel) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.SponsoredMessages>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-333377601)
                    channel.serialize(buffer, true)
                    return (FunctionDescription(name: "channels.getSponsoredMessages", parameters: [("channel", String(describing: channel))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.SponsoredMessages? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.SponsoredMessages?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.SponsoredMessages
                        }
                        return result
                    })
                }
}
public extension Api.functions.channels {
                static func inviteToChannel(channel: Api.InputChannel, users: [Api.InputUser]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(429865580)
                    channel.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    return (FunctionDescription(name: "channels.inviteToChannel", parameters: [("channel", String(describing: channel)), ("users", String(describing: users))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
}
public extension Api.functions.channels {
                static func joinChannel(channel: Api.InputChannel) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(615851205)
                    channel.serialize(buffer, true)
                    return (FunctionDescription(name: "channels.joinChannel", parameters: [("channel", String(describing: channel))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
}
public extension Api.functions.channels {
                static func leaveChannel(channel: Api.InputChannel) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-130635115)
                    channel.serialize(buffer, true)
                    return (FunctionDescription(name: "channels.leaveChannel", parameters: [("channel", String(describing: channel))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
}
public extension Api.functions.channels {
                static func readHistory(channel: Api.InputChannel, maxId: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-871347913)
                    channel.serialize(buffer, true)
                    serializeInt32(maxId, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "channels.readHistory", parameters: [("channel", String(describing: channel)), ("maxId", String(describing: maxId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.channels {
                static func readMessageContents(channel: Api.InputChannel, id: [Int32]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-357180360)
                    channel.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(id.count))
                    for item in id {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    return (FunctionDescription(name: "channels.readMessageContents", parameters: [("channel", String(describing: channel)), ("id", String(describing: id))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.channels {
                static func reorderUsernames(channel: Api.InputChannel, order: [String]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1268978403)
                    channel.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(order.count))
                    for item in order {
                        serializeString(item, buffer: buffer, boxed: false)
                    }
                    return (FunctionDescription(name: "channels.reorderUsernames", parameters: [("channel", String(describing: channel)), ("order", String(describing: order))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.channels {
                static func reportSpam(channel: Api.InputChannel, participant: Api.InputPeer, id: [Int32]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-196443371)
                    channel.serialize(buffer, true)
                    participant.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(id.count))
                    for item in id {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    return (FunctionDescription(name: "channels.reportSpam", parameters: [("channel", String(describing: channel)), ("participant", String(describing: participant)), ("id", String(describing: id))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.channels {
                static func setDiscussionGroup(broadcast: Api.InputChannel, group: Api.InputChannel) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1079520178)
                    broadcast.serialize(buffer, true)
                    group.serialize(buffer, true)
                    return (FunctionDescription(name: "channels.setDiscussionGroup", parameters: [("broadcast", String(describing: broadcast)), ("group", String(describing: group))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.channels {
                static func setStickers(channel: Api.InputChannel, stickerset: Api.InputStickerSet) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-359881479)
                    channel.serialize(buffer, true)
                    stickerset.serialize(buffer, true)
                    return (FunctionDescription(name: "channels.setStickers", parameters: [("channel", String(describing: channel)), ("stickerset", String(describing: stickerset))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.channels {
                static func toggleForum(channel: Api.InputChannel, enabled: Api.Bool) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1540781271)
                    channel.serialize(buffer, true)
                    enabled.serialize(buffer, true)
                    return (FunctionDescription(name: "channels.toggleForum", parameters: [("channel", String(describing: channel)), ("enabled", String(describing: enabled))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
}
public extension Api.functions.channels {
                static func toggleJoinRequest(channel: Api.InputChannel, enabled: Api.Bool) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1277789622)
                    channel.serialize(buffer, true)
                    enabled.serialize(buffer, true)
                    return (FunctionDescription(name: "channels.toggleJoinRequest", parameters: [("channel", String(describing: channel)), ("enabled", String(describing: enabled))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
}
public extension Api.functions.channels {
                static func toggleJoinToSend(channel: Api.InputChannel, enabled: Api.Bool) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-456419968)
                    channel.serialize(buffer, true)
                    enabled.serialize(buffer, true)
                    return (FunctionDescription(name: "channels.toggleJoinToSend", parameters: [("channel", String(describing: channel)), ("enabled", String(describing: enabled))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
}
public extension Api.functions.channels {
                static func togglePreHistoryHidden(channel: Api.InputChannel, enabled: Api.Bool) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-356796084)
                    channel.serialize(buffer, true)
                    enabled.serialize(buffer, true)
                    return (FunctionDescription(name: "channels.togglePreHistoryHidden", parameters: [("channel", String(describing: channel)), ("enabled", String(describing: enabled))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
}
public extension Api.functions.channels {
                static func toggleSignatures(channel: Api.InputChannel, enabled: Api.Bool) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(527021574)
                    channel.serialize(buffer, true)
                    enabled.serialize(buffer, true)
                    return (FunctionDescription(name: "channels.toggleSignatures", parameters: [("channel", String(describing: channel)), ("enabled", String(describing: enabled))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
}
public extension Api.functions.channels {
                static func toggleSlowMode(channel: Api.InputChannel, seconds: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-304832784)
                    channel.serialize(buffer, true)
                    serializeInt32(seconds, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "channels.toggleSlowMode", parameters: [("channel", String(describing: channel)), ("seconds", String(describing: seconds))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
}
public extension Api.functions.channels {
                static func toggleUsername(channel: Api.InputChannel, username: String, active: Api.Bool) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1358053637)
                    channel.serialize(buffer, true)
                    serializeString(username, buffer: buffer, boxed: false)
                    active.serialize(buffer, true)
                    return (FunctionDescription(name: "channels.toggleUsername", parameters: [("channel", String(describing: channel)), ("username", String(describing: username)), ("active", String(describing: active))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.channels {
                static func updatePinnedForumTopic(channel: Api.InputChannel, topicId: Int32, pinned: Api.Bool) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1814925350)
                    channel.serialize(buffer, true)
                    serializeInt32(topicId, buffer: buffer, boxed: false)
                    pinned.serialize(buffer, true)
                    return (FunctionDescription(name: "channels.updatePinnedForumTopic", parameters: [("channel", String(describing: channel)), ("topicId", String(describing: topicId)), ("pinned", String(describing: pinned))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
}
public extension Api.functions.channels {
                static func updateUsername(channel: Api.InputChannel, username: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(890549214)
                    channel.serialize(buffer, true)
                    serializeString(username, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "channels.updateUsername", parameters: [("channel", String(describing: channel)), ("username", String(describing: username))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.channels {
                static func viewSponsoredMessage(channel: Api.InputChannel, randomId: Buffer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1095836780)
                    channel.serialize(buffer, true)
                    serializeBytes(randomId, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "channels.viewSponsoredMessage", parameters: [("channel", String(describing: channel)), ("randomId", String(describing: randomId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.contacts {
                static func acceptContact(id: Api.InputUser) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-130964977)
                    id.serialize(buffer, true)
                    return (FunctionDescription(name: "contacts.acceptContact", parameters: [("id", String(describing: id))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
}
public extension Api.functions.contacts {
                static func addContact(flags: Int32, id: Api.InputUser, firstName: String, lastName: String, phone: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-386636848)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    id.serialize(buffer, true)
                    serializeString(firstName, buffer: buffer, boxed: false)
                    serializeString(lastName, buffer: buffer, boxed: false)
                    serializeString(phone, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "contacts.addContact", parameters: [("flags", String(describing: flags)), ("id", String(describing: id)), ("firstName", String(describing: firstName)), ("lastName", String(describing: lastName)), ("phone", String(describing: phone))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
}
public extension Api.functions.contacts {
                static func block(id: Api.InputPeer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1758204945)
                    id.serialize(buffer, true)
                    return (FunctionDescription(name: "contacts.block", parameters: [("id", String(describing: id))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.contacts {
                static func blockFromReplies(flags: Int32, msgId: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(698914348)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(msgId, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "contacts.blockFromReplies", parameters: [("flags", String(describing: flags)), ("msgId", String(describing: msgId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
}
public extension Api.functions.contacts {
                static func deleteByPhones(phones: [String]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(269745566)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(phones.count))
                    for item in phones {
                        serializeString(item, buffer: buffer, boxed: false)
                    }
                    return (FunctionDescription(name: "contacts.deleteByPhones", parameters: [("phones", String(describing: phones))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.contacts {
                static func deleteContacts(id: [Api.InputUser]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(157945344)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(id.count))
                    for item in id {
                        item.serialize(buffer, true)
                    }
                    return (FunctionDescription(name: "contacts.deleteContacts", parameters: [("id", String(describing: id))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
}
public extension Api.functions.contacts {
                static func getBlocked(offset: Int32, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.contacts.Blocked>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-176409329)
                    serializeInt32(offset, buffer: buffer, boxed: false)
                    serializeInt32(limit, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "contacts.getBlocked", parameters: [("offset", String(describing: offset)), ("limit", String(describing: limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.contacts.Blocked? in
                        let reader = BufferReader(buffer)
                        var result: Api.contacts.Blocked?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.contacts.Blocked
                        }
                        return result
                    })
                }
}
public extension Api.functions.contacts {
                static func getContactIDs(hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Int32]>) {
                    let buffer = Buffer()
                    buffer.appendInt32(2061264541)
                    serializeInt64(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "contacts.getContactIDs", parameters: [("hash", String(describing: hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> [Int32]? in
                        let reader = BufferReader(buffer)
                        var result: [Int32]?
                        if let _ = reader.readInt32() {
                            result = Api.parseVector(reader, elementSignature: -1471112230, elementType: Int32.self)
                        }
                        return result
                    })
                }
}
public extension Api.functions.contacts {
                static func getContacts(hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.contacts.Contacts>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1574346258)
                    serializeInt64(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "contacts.getContacts", parameters: [("hash", String(describing: hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.contacts.Contacts? in
                        let reader = BufferReader(buffer)
                        var result: Api.contacts.Contacts?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.contacts.Contacts
                        }
                        return result
                    })
                }
}
public extension Api.functions.contacts {
                static func getLocated(flags: Int32, geoPoint: Api.InputGeoPoint, selfExpires: Int32?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-750207932)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    geoPoint.serialize(buffer, true)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(selfExpires!, buffer: buffer, boxed: false)}
                    return (FunctionDescription(name: "contacts.getLocated", parameters: [("flags", String(describing: flags)), ("geoPoint", String(describing: geoPoint)), ("selfExpires", String(describing: selfExpires))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
}
public extension Api.functions.contacts {
                static func getSaved() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Api.SavedContact]>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-2098076769)
                    
                    return (FunctionDescription(name: "contacts.getSaved", parameters: []), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> [Api.SavedContact]? in
                        let reader = BufferReader(buffer)
                        var result: [Api.SavedContact]?
                        if let _ = reader.readInt32() {
                            result = Api.parseVector(reader, elementSignature: 0, elementType: Api.SavedContact.self)
                        }
                        return result
                    })
                }
}
public extension Api.functions.contacts {
                static func getStatuses() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Api.ContactStatus]>) {
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
}
public extension Api.functions.contacts {
                static func getTopPeers(flags: Int32, offset: Int32, limit: Int32, hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.contacts.TopPeers>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1758168906)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(offset, buffer: buffer, boxed: false)
                    serializeInt32(limit, buffer: buffer, boxed: false)
                    serializeInt64(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "contacts.getTopPeers", parameters: [("flags", String(describing: flags)), ("offset", String(describing: offset)), ("limit", String(describing: limit)), ("hash", String(describing: hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.contacts.TopPeers? in
                        let reader = BufferReader(buffer)
                        var result: Api.contacts.TopPeers?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.contacts.TopPeers
                        }
                        return result
                    })
                }
}
public extension Api.functions.contacts {
                static func importContacts(contacts: [Api.InputContact]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.contacts.ImportedContacts>) {
                    let buffer = Buffer()
                    buffer.appendInt32(746589157)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(contacts.count))
                    for item in contacts {
                        item.serialize(buffer, true)
                    }
                    return (FunctionDescription(name: "contacts.importContacts", parameters: [("contacts", String(describing: contacts))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.contacts.ImportedContacts? in
                        let reader = BufferReader(buffer)
                        var result: Api.contacts.ImportedContacts?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.contacts.ImportedContacts
                        }
                        return result
                    })
                }
}
public extension Api.functions.contacts {
                static func resetSaved() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
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
}
public extension Api.functions.contacts {
                static func resetTopPeerRating(category: Api.TopPeerCategory, peer: Api.InputPeer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(451113900)
                    category.serialize(buffer, true)
                    peer.serialize(buffer, true)
                    return (FunctionDescription(name: "contacts.resetTopPeerRating", parameters: [("category", String(describing: category)), ("peer", String(describing: peer))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.contacts {
                static func resolvePhone(phone: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.contacts.ResolvedPeer>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1963375804)
                    serializeString(phone, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "contacts.resolvePhone", parameters: [("phone", String(describing: phone))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.contacts.ResolvedPeer? in
                        let reader = BufferReader(buffer)
                        var result: Api.contacts.ResolvedPeer?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.contacts.ResolvedPeer
                        }
                        return result
                    })
                }
}
public extension Api.functions.contacts {
                static func resolveUsername(username: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.contacts.ResolvedPeer>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-113456221)
                    serializeString(username, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "contacts.resolveUsername", parameters: [("username", String(describing: username))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.contacts.ResolvedPeer? in
                        let reader = BufferReader(buffer)
                        var result: Api.contacts.ResolvedPeer?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.contacts.ResolvedPeer
                        }
                        return result
                    })
                }
}
public extension Api.functions.contacts {
                static func search(q: String, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.contacts.Found>) {
                    let buffer = Buffer()
                    buffer.appendInt32(301470424)
                    serializeString(q, buffer: buffer, boxed: false)
                    serializeInt32(limit, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "contacts.search", parameters: [("q", String(describing: q)), ("limit", String(describing: limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.contacts.Found? in
                        let reader = BufferReader(buffer)
                        var result: Api.contacts.Found?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.contacts.Found
                        }
                        return result
                    })
                }
}
public extension Api.functions.contacts {
                static func toggleTopPeers(enabled: Api.Bool) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-2062238246)
                    enabled.serialize(buffer, true)
                    return (FunctionDescription(name: "contacts.toggleTopPeers", parameters: [("enabled", String(describing: enabled))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.contacts {
                static func unblock(id: Api.InputPeer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1096393392)
                    id.serialize(buffer, true)
                    return (FunctionDescription(name: "contacts.unblock", parameters: [("id", String(describing: id))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.folders {
                static func deleteFolder(folderId: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(472471681)
                    serializeInt32(folderId, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "folders.deleteFolder", parameters: [("folderId", String(describing: folderId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
}
public extension Api.functions.folders {
                static func editPeerFolders(folderPeers: [Api.InputFolderPeer]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1749536939)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(folderPeers.count))
                    for item in folderPeers {
                        item.serialize(buffer, true)
                    }
                    return (FunctionDescription(name: "folders.editPeerFolders", parameters: [("folderPeers", String(describing: folderPeers))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
}
public extension Api.functions.help {
                static func acceptTermsOfService(id: Api.DataJSON) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-294455398)
                    id.serialize(buffer, true)
                    return (FunctionDescription(name: "help.acceptTermsOfService", parameters: [("id", String(describing: id))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.help {
                static func dismissSuggestion(peer: Api.InputPeer, suggestion: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-183649631)
                    peer.serialize(buffer, true)
                    serializeString(suggestion, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "help.dismissSuggestion", parameters: [("peer", String(describing: peer)), ("suggestion", String(describing: suggestion))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.help {
                static func editUserInfo(userId: Api.InputUser, message: String, entities: [Api.MessageEntity]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.help.UserInfo>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1723407216)
                    userId.serialize(buffer, true)
                    serializeString(message, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(entities.count))
                    for item in entities {
                        item.serialize(buffer, true)
                    }
                    return (FunctionDescription(name: "help.editUserInfo", parameters: [("userId", String(describing: userId)), ("message", String(describing: message)), ("entities", String(describing: entities))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.help.UserInfo? in
                        let reader = BufferReader(buffer)
                        var result: Api.help.UserInfo?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.help.UserInfo
                        }
                        return result
                    })
                }
}
public extension Api.functions.help {
                static func getAppChangelog(prevAppVersion: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1877938321)
                    serializeString(prevAppVersion, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "help.getAppChangelog", parameters: [("prevAppVersion", String(describing: prevAppVersion))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
}
public extension Api.functions.help {
                static func getAppConfig() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.JSONValue>) {
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
}
public extension Api.functions.help {
                static func getAppUpdate(source: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.help.AppUpdate>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1378703997)
                    serializeString(source, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "help.getAppUpdate", parameters: [("source", String(describing: source))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.help.AppUpdate? in
                        let reader = BufferReader(buffer)
                        var result: Api.help.AppUpdate?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.help.AppUpdate
                        }
                        return result
                    })
                }
}
public extension Api.functions.help {
                static func getCdnConfig() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.CdnConfig>) {
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
}
public extension Api.functions.help {
                static func getConfig() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Config>) {
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
}
public extension Api.functions.help {
                static func getCountriesList(langCode: String, hash: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.help.CountriesList>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1935116200)
                    serializeString(langCode, buffer: buffer, boxed: false)
                    serializeInt32(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "help.getCountriesList", parameters: [("langCode", String(describing: langCode)), ("hash", String(describing: hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.help.CountriesList? in
                        let reader = BufferReader(buffer)
                        var result: Api.help.CountriesList?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.help.CountriesList
                        }
                        return result
                    })
                }
}
public extension Api.functions.help {
                static func getDeepLinkInfo(path: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.help.DeepLinkInfo>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1072547679)
                    serializeString(path, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "help.getDeepLinkInfo", parameters: [("path", String(describing: path))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.help.DeepLinkInfo? in
                        let reader = BufferReader(buffer)
                        var result: Api.help.DeepLinkInfo?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.help.DeepLinkInfo
                        }
                        return result
                    })
                }
}
public extension Api.functions.help {
                static func getInviteText() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.help.InviteText>) {
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
}
public extension Api.functions.help {
                static func getNearestDc() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.NearestDc>) {
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
}
public extension Api.functions.help {
                static func getPassportConfig(hash: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.help.PassportConfig>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-966677240)
                    serializeInt32(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "help.getPassportConfig", parameters: [("hash", String(describing: hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.help.PassportConfig? in
                        let reader = BufferReader(buffer)
                        var result: Api.help.PassportConfig?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.help.PassportConfig
                        }
                        return result
                    })
                }
}
public extension Api.functions.help {
                static func getPremiumPromo() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.help.PremiumPromo>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1206152236)
                    
                    return (FunctionDescription(name: "help.getPremiumPromo", parameters: []), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.help.PremiumPromo? in
                        let reader = BufferReader(buffer)
                        var result: Api.help.PremiumPromo?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.help.PremiumPromo
                        }
                        return result
                    })
                }
}
public extension Api.functions.help {
                static func getPromoData() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.help.PromoData>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1063816159)
                    
                    return (FunctionDescription(name: "help.getPromoData", parameters: []), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.help.PromoData? in
                        let reader = BufferReader(buffer)
                        var result: Api.help.PromoData?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.help.PromoData
                        }
                        return result
                    })
                }
}
public extension Api.functions.help {
                static func getRecentMeUrls(referer: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.help.RecentMeUrls>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1036054804)
                    serializeString(referer, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "help.getRecentMeUrls", parameters: [("referer", String(describing: referer))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.help.RecentMeUrls? in
                        let reader = BufferReader(buffer)
                        var result: Api.help.RecentMeUrls?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.help.RecentMeUrls
                        }
                        return result
                    })
                }
}
public extension Api.functions.help {
                static func getSupport() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.help.Support>) {
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
}
public extension Api.functions.help {
                static func getSupportName() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.help.SupportName>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-748624084)
                    
                    return (FunctionDescription(name: "help.getSupportName", parameters: []), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.help.SupportName? in
                        let reader = BufferReader(buffer)
                        var result: Api.help.SupportName?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.help.SupportName
                        }
                        return result
                    })
                }
}
public extension Api.functions.help {
                static func getTermsOfServiceUpdate() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.help.TermsOfServiceUpdate>) {
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
}
public extension Api.functions.help {
                static func getUserInfo(userId: Api.InputUser) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.help.UserInfo>) {
                    let buffer = Buffer()
                    buffer.appendInt32(59377875)
                    userId.serialize(buffer, true)
                    return (FunctionDescription(name: "help.getUserInfo", parameters: [("userId", String(describing: userId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.help.UserInfo? in
                        let reader = BufferReader(buffer)
                        var result: Api.help.UserInfo?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.help.UserInfo
                        }
                        return result
                    })
                }
}
public extension Api.functions.help {
                static func hidePromoData(peer: Api.InputPeer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(505748629)
                    peer.serialize(buffer, true)
                    return (FunctionDescription(name: "help.hidePromoData", parameters: [("peer", String(describing: peer))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.help {
                static func saveAppLog(events: [Api.InputAppEvent]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1862465352)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(events.count))
                    for item in events {
                        item.serialize(buffer, true)
                    }
                    return (FunctionDescription(name: "help.saveAppLog", parameters: [("events", String(describing: events))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.help {
                static func setBotUpdatesStatus(pendingUpdatesCount: Int32, message: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-333262899)
                    serializeInt32(pendingUpdatesCount, buffer: buffer, boxed: false)
                    serializeString(message, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "help.setBotUpdatesStatus", parameters: [("pendingUpdatesCount", String(describing: pendingUpdatesCount)), ("message", String(describing: message))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.help {
                static func test() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
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
}
public extension Api.functions.langpack {
                static func getDifference(langPack: String, langCode: String, fromVersion: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.LangPackDifference>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-845657435)
                    serializeString(langPack, buffer: buffer, boxed: false)
                    serializeString(langCode, buffer: buffer, boxed: false)
                    serializeInt32(fromVersion, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "langpack.getDifference", parameters: [("langPack", String(describing: langPack)), ("langCode", String(describing: langCode)), ("fromVersion", String(describing: fromVersion))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.LangPackDifference? in
                        let reader = BufferReader(buffer)
                        var result: Api.LangPackDifference?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.LangPackDifference
                        }
                        return result
                    })
                }
}
public extension Api.functions.langpack {
                static func getLangPack(langPack: String, langCode: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.LangPackDifference>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-219008246)
                    serializeString(langPack, buffer: buffer, boxed: false)
                    serializeString(langCode, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "langpack.getLangPack", parameters: [("langPack", String(describing: langPack)), ("langCode", String(describing: langCode))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.LangPackDifference? in
                        let reader = BufferReader(buffer)
                        var result: Api.LangPackDifference?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.LangPackDifference
                        }
                        return result
                    })
                }
}
public extension Api.functions.langpack {
                static func getLanguage(langPack: String, langCode: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.LangPackLanguage>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1784243458)
                    serializeString(langPack, buffer: buffer, boxed: false)
                    serializeString(langCode, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "langpack.getLanguage", parameters: [("langPack", String(describing: langPack)), ("langCode", String(describing: langCode))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.LangPackLanguage? in
                        let reader = BufferReader(buffer)
                        var result: Api.LangPackLanguage?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.LangPackLanguage
                        }
                        return result
                    })
                }
}
public extension Api.functions.langpack {
                static func getLanguages(langPack: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Api.LangPackLanguage]>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1120311183)
                    serializeString(langPack, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "langpack.getLanguages", parameters: [("langPack", String(describing: langPack))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> [Api.LangPackLanguage]? in
                        let reader = BufferReader(buffer)
                        var result: [Api.LangPackLanguage]?
                        if let _ = reader.readInt32() {
                            result = Api.parseVector(reader, elementSignature: 0, elementType: Api.LangPackLanguage.self)
                        }
                        return result
                    })
                }
}
public extension Api.functions.langpack {
                static func getStrings(langPack: String, langCode: String, keys: [String]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Api.LangPackString]>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-269862909)
                    serializeString(langPack, buffer: buffer, boxed: false)
                    serializeString(langCode, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(keys.count))
                    for item in keys {
                        serializeString(item, buffer: buffer, boxed: false)
                    }
                    return (FunctionDescription(name: "langpack.getStrings", parameters: [("langPack", String(describing: langPack)), ("langCode", String(describing: langCode)), ("keys", String(describing: keys))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> [Api.LangPackString]? in
                        let reader = BufferReader(buffer)
                        var result: [Api.LangPackString]?
                        if let _ = reader.readInt32() {
                            result = Api.parseVector(reader, elementSignature: 0, elementType: Api.LangPackString.self)
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func acceptEncryption(peer: Api.InputEncryptedChat, gB: Buffer, keyFingerprint: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.EncryptedChat>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1035731989)
                    peer.serialize(buffer, true)
                    serializeBytes(gB, buffer: buffer, boxed: false)
                    serializeInt64(keyFingerprint, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.acceptEncryption", parameters: [("peer", String(describing: peer)), ("gB", String(describing: gB)), ("keyFingerprint", String(describing: keyFingerprint))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.EncryptedChat? in
                        let reader = BufferReader(buffer)
                        var result: Api.EncryptedChat?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.EncryptedChat
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func acceptUrlAuth(flags: Int32, peer: Api.InputPeer?, msgId: Int32?, buttonId: Int32?, url: String?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.UrlAuthResult>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1322487515)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {peer!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt32(msgId!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt32(buttonId!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeString(url!, buffer: buffer, boxed: false)}
                    return (FunctionDescription(name: "messages.acceptUrlAuth", parameters: [("flags", String(describing: flags)), ("peer", String(describing: peer)), ("msgId", String(describing: msgId)), ("buttonId", String(describing: buttonId)), ("url", String(describing: url))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.UrlAuthResult? in
                        let reader = BufferReader(buffer)
                        var result: Api.UrlAuthResult?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.UrlAuthResult
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func addChatUser(chatId: Int64, userId: Api.InputUser, fwdLimit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-230206493)
                    serializeInt64(chatId, buffer: buffer, boxed: false)
                    userId.serialize(buffer, true)
                    serializeInt32(fwdLimit, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.addChatUser", parameters: [("chatId", String(describing: chatId)), ("userId", String(describing: userId)), ("fwdLimit", String(describing: fwdLimit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func checkChatInvite(hash: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.ChatInvite>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1051570619)
                    serializeString(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.checkChatInvite", parameters: [("hash", String(describing: hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.ChatInvite? in
                        let reader = BufferReader(buffer)
                        var result: Api.ChatInvite?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.ChatInvite
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func checkHistoryImport(importHead: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.HistoryImportParsed>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1140726259)
                    serializeString(importHead, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.checkHistoryImport", parameters: [("importHead", String(describing: importHead))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.HistoryImportParsed? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.HistoryImportParsed?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.HistoryImportParsed
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func checkHistoryImportPeer(peer: Api.InputPeer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.CheckedHistoryImportPeer>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1573261059)
                    peer.serialize(buffer, true)
                    return (FunctionDescription(name: "messages.checkHistoryImportPeer", parameters: [("peer", String(describing: peer))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.CheckedHistoryImportPeer? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.CheckedHistoryImportPeer?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.CheckedHistoryImportPeer
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func clearAllDrafts() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(2119757468)
                    
                    return (FunctionDescription(name: "messages.clearAllDrafts", parameters: []), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func clearRecentReactions() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1644236876)
                    
                    return (FunctionDescription(name: "messages.clearRecentReactions", parameters: []), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func clearRecentStickers(flags: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1986437075)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.clearRecentStickers", parameters: [("flags", String(describing: flags))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func createChat(users: [Api.InputUser], title: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(164303470)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    serializeString(title, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.createChat", parameters: [("users", String(describing: users)), ("title", String(describing: title))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func deleteChat(chatId: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1540419152)
                    serializeInt64(chatId, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.deleteChat", parameters: [("chatId", String(describing: chatId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func deleteChatUser(flags: Int32, chatId: Int64, userId: Api.InputUser) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1575461717)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(chatId, buffer: buffer, boxed: false)
                    userId.serialize(buffer, true)
                    return (FunctionDescription(name: "messages.deleteChatUser", parameters: [("flags", String(describing: flags)), ("chatId", String(describing: chatId)), ("userId", String(describing: userId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func deleteExportedChatInvite(peer: Api.InputPeer, link: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-731601877)
                    peer.serialize(buffer, true)
                    serializeString(link, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.deleteExportedChatInvite", parameters: [("peer", String(describing: peer)), ("link", String(describing: link))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func deleteHistory(flags: Int32, peer: Api.InputPeer, maxId: Int32, minDate: Int32?, maxDate: Int32?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.AffectedHistory>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1332768214)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    serializeInt32(maxId, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 2) != 0 {serializeInt32(minDate!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 3) != 0 {serializeInt32(maxDate!, buffer: buffer, boxed: false)}
                    return (FunctionDescription(name: "messages.deleteHistory", parameters: [("flags", String(describing: flags)), ("peer", String(describing: peer)), ("maxId", String(describing: maxId)), ("minDate", String(describing: minDate)), ("maxDate", String(describing: maxDate))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.AffectedHistory? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.AffectedHistory?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.AffectedHistory
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func deleteMessages(flags: Int32, id: [Int32]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.AffectedMessages>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-443640366)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(id.count))
                    for item in id {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    return (FunctionDescription(name: "messages.deleteMessages", parameters: [("flags", String(describing: flags)), ("id", String(describing: id))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.AffectedMessages? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.AffectedMessages?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.AffectedMessages
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func deletePhoneCallHistory(flags: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.AffectedFoundMessages>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-104078327)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.deletePhoneCallHistory", parameters: [("flags", String(describing: flags))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.AffectedFoundMessages? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.AffectedFoundMessages?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.AffectedFoundMessages
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func deleteRevokedExportedChatInvites(peer: Api.InputPeer, adminId: Api.InputUser) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1452833749)
                    peer.serialize(buffer, true)
                    adminId.serialize(buffer, true)
                    return (FunctionDescription(name: "messages.deleteRevokedExportedChatInvites", parameters: [("peer", String(describing: peer)), ("adminId", String(describing: adminId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func deleteScheduledMessages(peer: Api.InputPeer, id: [Int32]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1504586518)
                    peer.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(id.count))
                    for item in id {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    return (FunctionDescription(name: "messages.deleteScheduledMessages", parameters: [("peer", String(describing: peer)), ("id", String(describing: id))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func discardEncryption(flags: Int32, chatId: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-208425312)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(chatId, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.discardEncryption", parameters: [("flags", String(describing: flags)), ("chatId", String(describing: chatId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func editChatAbout(peer: Api.InputPeer, about: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-554301545)
                    peer.serialize(buffer, true)
                    serializeString(about, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.editChatAbout", parameters: [("peer", String(describing: peer)), ("about", String(describing: about))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func editChatAdmin(chatId: Int64, userId: Api.InputUser, isAdmin: Api.Bool) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1470377534)
                    serializeInt64(chatId, buffer: buffer, boxed: false)
                    userId.serialize(buffer, true)
                    isAdmin.serialize(buffer, true)
                    return (FunctionDescription(name: "messages.editChatAdmin", parameters: [("chatId", String(describing: chatId)), ("userId", String(describing: userId)), ("isAdmin", String(describing: isAdmin))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func editChatDefaultBannedRights(peer: Api.InputPeer, bannedRights: Api.ChatBannedRights) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1517917375)
                    peer.serialize(buffer, true)
                    bannedRights.serialize(buffer, true)
                    return (FunctionDescription(name: "messages.editChatDefaultBannedRights", parameters: [("peer", String(describing: peer)), ("bannedRights", String(describing: bannedRights))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func editChatPhoto(chatId: Int64, photo: Api.InputChatPhoto) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(903730804)
                    serializeInt64(chatId, buffer: buffer, boxed: false)
                    photo.serialize(buffer, true)
                    return (FunctionDescription(name: "messages.editChatPhoto", parameters: [("chatId", String(describing: chatId)), ("photo", String(describing: photo))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func editChatTitle(chatId: Int64, title: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1937260541)
                    serializeInt64(chatId, buffer: buffer, boxed: false)
                    serializeString(title, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.editChatTitle", parameters: [("chatId", String(describing: chatId)), ("title", String(describing: title))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func editExportedChatInvite(flags: Int32, peer: Api.InputPeer, link: String, expireDate: Int32?, usageLimit: Int32?, requestNeeded: Api.Bool?, title: String?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.ExportedChatInvite>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1110823051)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    serializeString(link, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(expireDate!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt32(usageLimit!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 3) != 0 {requestNeeded!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 4) != 0 {serializeString(title!, buffer: buffer, boxed: false)}
                    return (FunctionDescription(name: "messages.editExportedChatInvite", parameters: [("flags", String(describing: flags)), ("peer", String(describing: peer)), ("link", String(describing: link)), ("expireDate", String(describing: expireDate)), ("usageLimit", String(describing: usageLimit)), ("requestNeeded", String(describing: requestNeeded)), ("title", String(describing: title))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.ExportedChatInvite? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.ExportedChatInvite?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.ExportedChatInvite
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func editInlineBotMessage(flags: Int32, id: Api.InputBotInlineMessageID, message: String?, media: Api.InputMedia?, replyMarkup: Api.ReplyMarkup?, entities: [Api.MessageEntity]?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
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
                    return (FunctionDescription(name: "messages.editInlineBotMessage", parameters: [("flags", String(describing: flags)), ("id", String(describing: id)), ("message", String(describing: message)), ("media", String(describing: media)), ("replyMarkup", String(describing: replyMarkup)), ("entities", String(describing: entities))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func editMessage(flags: Int32, peer: Api.InputPeer, id: Int32, message: String?, media: Api.InputMedia?, replyMarkup: Api.ReplyMarkup?, entities: [Api.MessageEntity]?, scheduleDate: Int32?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
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
                    return (FunctionDescription(name: "messages.editMessage", parameters: [("flags", String(describing: flags)), ("peer", String(describing: peer)), ("id", String(describing: id)), ("message", String(describing: message)), ("media", String(describing: media)), ("replyMarkup", String(describing: replyMarkup)), ("entities", String(describing: entities)), ("scheduleDate", String(describing: scheduleDate))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func exportChatInvite(flags: Int32, peer: Api.InputPeer, expireDate: Int32?, usageLimit: Int32?, title: String?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.ExportedChatInvite>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1607670315)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(expireDate!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt32(usageLimit!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 4) != 0 {serializeString(title!, buffer: buffer, boxed: false)}
                    return (FunctionDescription(name: "messages.exportChatInvite", parameters: [("flags", String(describing: flags)), ("peer", String(describing: peer)), ("expireDate", String(describing: expireDate)), ("usageLimit", String(describing: usageLimit)), ("title", String(describing: title))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.ExportedChatInvite? in
                        let reader = BufferReader(buffer)
                        var result: Api.ExportedChatInvite?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.ExportedChatInvite
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func faveSticker(id: Api.InputDocument, unfave: Api.Bool) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1174420133)
                    id.serialize(buffer, true)
                    unfave.serialize(buffer, true)
                    return (FunctionDescription(name: "messages.faveSticker", parameters: [("id", String(describing: id)), ("unfave", String(describing: unfave))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func forwardMessages(flags: Int32, fromPeer: Api.InputPeer, id: [Int32], randomId: [Int64], toPeer: Api.InputPeer, topMsgId: Int32?, scheduleDate: Int32?, sendAs: Api.InputPeer?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-966673468)
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
                    if Int(flags) & Int(1 << 9) != 0 {serializeInt32(topMsgId!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 10) != 0 {serializeInt32(scheduleDate!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 13) != 0 {sendAs!.serialize(buffer, true)}
                    return (FunctionDescription(name: "messages.forwardMessages", parameters: [("flags", String(describing: flags)), ("fromPeer", String(describing: fromPeer)), ("id", String(describing: id)), ("randomId", String(describing: randomId)), ("toPeer", String(describing: toPeer)), ("topMsgId", String(describing: topMsgId)), ("scheduleDate", String(describing: scheduleDate)), ("sendAs", String(describing: sendAs))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func getAdminsWithInvites(peer: Api.InputPeer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.ChatAdminsWithInvites>) {
                    let buffer = Buffer()
                    buffer.appendInt32(958457583)
                    peer.serialize(buffer, true)
                    return (FunctionDescription(name: "messages.getAdminsWithInvites", parameters: [("peer", String(describing: peer))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.ChatAdminsWithInvites? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.ChatAdminsWithInvites?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.ChatAdminsWithInvites
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func getAllChats(exceptIds: [Int64]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.Chats>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-2023787330)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(exceptIds.count))
                    for item in exceptIds {
                        serializeInt64(item, buffer: buffer, boxed: false)
                    }
                    return (FunctionDescription(name: "messages.getAllChats", parameters: [("exceptIds", String(describing: exceptIds))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.Chats? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.Chats?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.Chats
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func getAllDrafts() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
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
}
public extension Api.functions.messages {
                static func getAllStickers(hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.AllStickers>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1197432408)
                    serializeInt64(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.getAllStickers", parameters: [("hash", String(describing: hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.AllStickers? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.AllStickers?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.AllStickers
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func getArchivedStickers(flags: Int32, offsetId: Int64, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.ArchivedStickers>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1475442322)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(offsetId, buffer: buffer, boxed: false)
                    serializeInt32(limit, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.getArchivedStickers", parameters: [("flags", String(describing: flags)), ("offsetId", String(describing: offsetId)), ("limit", String(describing: limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.ArchivedStickers? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.ArchivedStickers?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.ArchivedStickers
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func getAttachMenuBot(bot: Api.InputUser) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.AttachMenuBotsBot>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1998676370)
                    bot.serialize(buffer, true)
                    return (FunctionDescription(name: "messages.getAttachMenuBot", parameters: [("bot", String(describing: bot))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.AttachMenuBotsBot? in
                        let reader = BufferReader(buffer)
                        var result: Api.AttachMenuBotsBot?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.AttachMenuBotsBot
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func getAttachMenuBots(hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.AttachMenuBots>) {
                    let buffer = Buffer()
                    buffer.appendInt32(385663691)
                    serializeInt64(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.getAttachMenuBots", parameters: [("hash", String(describing: hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.AttachMenuBots? in
                        let reader = BufferReader(buffer)
                        var result: Api.AttachMenuBots?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.AttachMenuBots
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func getAttachedStickers(media: Api.InputStickeredMedia) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Api.StickerSetCovered]>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-866424884)
                    media.serialize(buffer, true)
                    return (FunctionDescription(name: "messages.getAttachedStickers", parameters: [("media", String(describing: media))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> [Api.StickerSetCovered]? in
                        let reader = BufferReader(buffer)
                        var result: [Api.StickerSetCovered]?
                        if let _ = reader.readInt32() {
                            result = Api.parseVector(reader, elementSignature: 0, elementType: Api.StickerSetCovered.self)
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func getAvailableReactions(hash: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.AvailableReactions>) {
                    let buffer = Buffer()
                    buffer.appendInt32(417243308)
                    serializeInt32(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.getAvailableReactions", parameters: [("hash", String(describing: hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.AvailableReactions? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.AvailableReactions?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.AvailableReactions
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func getBotCallbackAnswer(flags: Int32, peer: Api.InputPeer, msgId: Int32, data: Buffer?, password: Api.InputCheckPasswordSRP?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.BotCallbackAnswer>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1824339449)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    serializeInt32(msgId, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeBytes(data!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {password!.serialize(buffer, true)}
                    return (FunctionDescription(name: "messages.getBotCallbackAnswer", parameters: [("flags", String(describing: flags)), ("peer", String(describing: peer)), ("msgId", String(describing: msgId)), ("data", String(describing: data)), ("password", String(describing: password))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.BotCallbackAnswer? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.BotCallbackAnswer?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.BotCallbackAnswer
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func getChatInviteImporters(flags: Int32, peer: Api.InputPeer, link: String?, q: String?, offsetDate: Int32, offsetUser: Api.InputUser, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.ChatInviteImporters>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-553329330)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(link!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeString(q!, buffer: buffer, boxed: false)}
                    serializeInt32(offsetDate, buffer: buffer, boxed: false)
                    offsetUser.serialize(buffer, true)
                    serializeInt32(limit, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.getChatInviteImporters", parameters: [("flags", String(describing: flags)), ("peer", String(describing: peer)), ("link", String(describing: link)), ("q", String(describing: q)), ("offsetDate", String(describing: offsetDate)), ("offsetUser", String(describing: offsetUser)), ("limit", String(describing: limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.ChatInviteImporters? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.ChatInviteImporters?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.ChatInviteImporters
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func getChats(id: [Int64]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.Chats>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1240027791)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(id.count))
                    for item in id {
                        serializeInt64(item, buffer: buffer, boxed: false)
                    }
                    return (FunctionDescription(name: "messages.getChats", parameters: [("id", String(describing: id))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.Chats? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.Chats?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.Chats
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func getCommonChats(userId: Api.InputUser, maxId: Int64, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.Chats>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-468934396)
                    userId.serialize(buffer, true)
                    serializeInt64(maxId, buffer: buffer, boxed: false)
                    serializeInt32(limit, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.getCommonChats", parameters: [("userId", String(describing: userId)), ("maxId", String(describing: maxId)), ("limit", String(describing: limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.Chats? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.Chats?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.Chats
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func getCustomEmojiDocuments(documentId: [Int64]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Api.Document]>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-643100844)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(documentId.count))
                    for item in documentId {
                        serializeInt64(item, buffer: buffer, boxed: false)
                    }
                    return (FunctionDescription(name: "messages.getCustomEmojiDocuments", parameters: [("documentId", String(describing: documentId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> [Api.Document]? in
                        let reader = BufferReader(buffer)
                        var result: [Api.Document]?
                        if let _ = reader.readInt32() {
                            result = Api.parseVector(reader, elementSignature: 0, elementType: Api.Document.self)
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func getDhConfig(version: Int32, randomLength: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.DhConfig>) {
                    let buffer = Buffer()
                    buffer.appendInt32(651135312)
                    serializeInt32(version, buffer: buffer, boxed: false)
                    serializeInt32(randomLength, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.getDhConfig", parameters: [("version", String(describing: version)), ("randomLength", String(describing: randomLength))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.DhConfig? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.DhConfig?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.DhConfig
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func getDialogFilters() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Api.DialogFilter]>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-241247891)
                    
                    return (FunctionDescription(name: "messages.getDialogFilters", parameters: []), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> [Api.DialogFilter]? in
                        let reader = BufferReader(buffer)
                        var result: [Api.DialogFilter]?
                        if let _ = reader.readInt32() {
                            result = Api.parseVector(reader, elementSignature: 0, elementType: Api.DialogFilter.self)
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func getDialogUnreadMarks() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Api.DialogPeer]>) {
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
}
public extension Api.functions.messages {
                static func getDialogs(flags: Int32, folderId: Int32?, offsetDate: Int32, offsetId: Int32, offsetPeer: Api.InputPeer, limit: Int32, hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.Dialogs>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1594569905)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt32(folderId!, buffer: buffer, boxed: false)}
                    serializeInt32(offsetDate, buffer: buffer, boxed: false)
                    serializeInt32(offsetId, buffer: buffer, boxed: false)
                    offsetPeer.serialize(buffer, true)
                    serializeInt32(limit, buffer: buffer, boxed: false)
                    serializeInt64(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.getDialogs", parameters: [("flags", String(describing: flags)), ("folderId", String(describing: folderId)), ("offsetDate", String(describing: offsetDate)), ("offsetId", String(describing: offsetId)), ("offsetPeer", String(describing: offsetPeer)), ("limit", String(describing: limit)), ("hash", String(describing: hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.Dialogs? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.Dialogs?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.Dialogs
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func getDiscussionMessage(peer: Api.InputPeer, msgId: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.DiscussionMessage>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1147761405)
                    peer.serialize(buffer, true)
                    serializeInt32(msgId, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.getDiscussionMessage", parameters: [("peer", String(describing: peer)), ("msgId", String(describing: msgId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.DiscussionMessage? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.DiscussionMessage?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.DiscussionMessage
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func getDocumentByHash(sha256: Buffer, size: Int64, mimeType: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Document>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1309538785)
                    serializeBytes(sha256, buffer: buffer, boxed: false)
                    serializeInt64(size, buffer: buffer, boxed: false)
                    serializeString(mimeType, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.getDocumentByHash", parameters: [("sha256", String(describing: sha256)), ("size", String(describing: size)), ("mimeType", String(describing: mimeType))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Document? in
                        let reader = BufferReader(buffer)
                        var result: Api.Document?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Document
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func getEmojiKeywords(langCode: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.EmojiKeywordsDifference>) {
                    let buffer = Buffer()
                    buffer.appendInt32(899735650)
                    serializeString(langCode, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.getEmojiKeywords", parameters: [("langCode", String(describing: langCode))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.EmojiKeywordsDifference? in
                        let reader = BufferReader(buffer)
                        var result: Api.EmojiKeywordsDifference?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.EmojiKeywordsDifference
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func getEmojiKeywordsDifference(langCode: String, fromVersion: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.EmojiKeywordsDifference>) {
                    let buffer = Buffer()
                    buffer.appendInt32(352892591)
                    serializeString(langCode, buffer: buffer, boxed: false)
                    serializeInt32(fromVersion, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.getEmojiKeywordsDifference", parameters: [("langCode", String(describing: langCode)), ("fromVersion", String(describing: fromVersion))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.EmojiKeywordsDifference? in
                        let reader = BufferReader(buffer)
                        var result: Api.EmojiKeywordsDifference?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.EmojiKeywordsDifference
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func getEmojiKeywordsLanguages(langCodes: [String]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Api.EmojiLanguage]>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1318675378)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(langCodes.count))
                    for item in langCodes {
                        serializeString(item, buffer: buffer, boxed: false)
                    }
                    return (FunctionDescription(name: "messages.getEmojiKeywordsLanguages", parameters: [("langCodes", String(describing: langCodes))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> [Api.EmojiLanguage]? in
                        let reader = BufferReader(buffer)
                        var result: [Api.EmojiLanguage]?
                        if let _ = reader.readInt32() {
                            result = Api.parseVector(reader, elementSignature: 0, elementType: Api.EmojiLanguage.self)
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func getEmojiStickers(hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.AllStickers>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-67329649)
                    serializeInt64(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.getEmojiStickers", parameters: [("hash", String(describing: hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.AllStickers? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.AllStickers?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.AllStickers
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func getEmojiURL(langCode: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.EmojiURL>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-709817306)
                    serializeString(langCode, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.getEmojiURL", parameters: [("langCode", String(describing: langCode))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.EmojiURL? in
                        let reader = BufferReader(buffer)
                        var result: Api.EmojiURL?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.EmojiURL
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func getExportedChatInvite(peer: Api.InputPeer, link: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.ExportedChatInvite>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1937010524)
                    peer.serialize(buffer, true)
                    serializeString(link, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.getExportedChatInvite", parameters: [("peer", String(describing: peer)), ("link", String(describing: link))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.ExportedChatInvite? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.ExportedChatInvite?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.ExportedChatInvite
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func getExportedChatInvites(flags: Int32, peer: Api.InputPeer, adminId: Api.InputUser, offsetDate: Int32?, offsetLink: String?, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.ExportedChatInvites>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1565154314)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    adminId.serialize(buffer, true)
                    if Int(flags) & Int(1 << 2) != 0 {serializeInt32(offsetDate!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeString(offsetLink!, buffer: buffer, boxed: false)}
                    serializeInt32(limit, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.getExportedChatInvites", parameters: [("flags", String(describing: flags)), ("peer", String(describing: peer)), ("adminId", String(describing: adminId)), ("offsetDate", String(describing: offsetDate)), ("offsetLink", String(describing: offsetLink)), ("limit", String(describing: limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.ExportedChatInvites? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.ExportedChatInvites?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.ExportedChatInvites
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func getExtendedMedia(peer: Api.InputPeer, id: [Int32]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-2064119788)
                    peer.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(id.count))
                    for item in id {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    return (FunctionDescription(name: "messages.getExtendedMedia", parameters: [("peer", String(describing: peer)), ("id", String(describing: id))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func getFavedStickers(hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.FavedStickers>) {
                    let buffer = Buffer()
                    buffer.appendInt32(82946729)
                    serializeInt64(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.getFavedStickers", parameters: [("hash", String(describing: hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.FavedStickers? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.FavedStickers?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.FavedStickers
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func getFeaturedEmojiStickers(hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.FeaturedStickers>) {
                    let buffer = Buffer()
                    buffer.appendInt32(248473398)
                    serializeInt64(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.getFeaturedEmojiStickers", parameters: [("hash", String(describing: hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.FeaturedStickers? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.FeaturedStickers?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.FeaturedStickers
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func getFeaturedStickers(hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.FeaturedStickers>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1685588756)
                    serializeInt64(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.getFeaturedStickers", parameters: [("hash", String(describing: hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.FeaturedStickers? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.FeaturedStickers?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.FeaturedStickers
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func getFullChat(chatId: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.ChatFull>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1364194508)
                    serializeInt64(chatId, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.getFullChat", parameters: [("chatId", String(describing: chatId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.ChatFull? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.ChatFull?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.ChatFull
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func getGameHighScores(peer: Api.InputPeer, id: Int32, userId: Api.InputUser) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.HighScores>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-400399203)
                    peer.serialize(buffer, true)
                    serializeInt32(id, buffer: buffer, boxed: false)
                    userId.serialize(buffer, true)
                    return (FunctionDescription(name: "messages.getGameHighScores", parameters: [("peer", String(describing: peer)), ("id", String(describing: id)), ("userId", String(describing: userId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.HighScores? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.HighScores?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.HighScores
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func getHistory(peer: Api.InputPeer, offsetId: Int32, offsetDate: Int32, addOffset: Int32, limit: Int32, maxId: Int32, minId: Int32, hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.Messages>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1143203525)
                    peer.serialize(buffer, true)
                    serializeInt32(offsetId, buffer: buffer, boxed: false)
                    serializeInt32(offsetDate, buffer: buffer, boxed: false)
                    serializeInt32(addOffset, buffer: buffer, boxed: false)
                    serializeInt32(limit, buffer: buffer, boxed: false)
                    serializeInt32(maxId, buffer: buffer, boxed: false)
                    serializeInt32(minId, buffer: buffer, boxed: false)
                    serializeInt64(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.getHistory", parameters: [("peer", String(describing: peer)), ("offsetId", String(describing: offsetId)), ("offsetDate", String(describing: offsetDate)), ("addOffset", String(describing: addOffset)), ("limit", String(describing: limit)), ("maxId", String(describing: maxId)), ("minId", String(describing: minId)), ("hash", String(describing: hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.Messages? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.Messages?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.Messages
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func getInlineBotResults(flags: Int32, bot: Api.InputUser, peer: Api.InputPeer, geoPoint: Api.InputGeoPoint?, query: String, offset: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.BotResults>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1364105629)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    bot.serialize(buffer, true)
                    peer.serialize(buffer, true)
                    if Int(flags) & Int(1 << 0) != 0 {geoPoint!.serialize(buffer, true)}
                    serializeString(query, buffer: buffer, boxed: false)
                    serializeString(offset, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.getInlineBotResults", parameters: [("flags", String(describing: flags)), ("bot", String(describing: bot)), ("peer", String(describing: peer)), ("geoPoint", String(describing: geoPoint)), ("query", String(describing: query)), ("offset", String(describing: offset))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.BotResults? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.BotResults?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.BotResults
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func getInlineGameHighScores(id: Api.InputBotInlineMessageID, userId: Api.InputUser) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.HighScores>) {
                    let buffer = Buffer()
                    buffer.appendInt32(258170395)
                    id.serialize(buffer, true)
                    userId.serialize(buffer, true)
                    return (FunctionDescription(name: "messages.getInlineGameHighScores", parameters: [("id", String(describing: id)), ("userId", String(describing: userId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.HighScores? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.HighScores?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.HighScores
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func getMaskStickers(hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.AllStickers>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1678738104)
                    serializeInt64(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.getMaskStickers", parameters: [("hash", String(describing: hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.AllStickers? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.AllStickers?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.AllStickers
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func getMessageEditData(peer: Api.InputPeer, id: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.MessageEditData>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-39416522)
                    peer.serialize(buffer, true)
                    serializeInt32(id, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.getMessageEditData", parameters: [("peer", String(describing: peer)), ("id", String(describing: id))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.MessageEditData? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.MessageEditData?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.MessageEditData
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func getMessageReactionsList(flags: Int32, peer: Api.InputPeer, id: Int32, reaction: Api.Reaction?, offset: String?, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.MessageReactionsList>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1176190792)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    serializeInt32(id, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {reaction!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(offset!, buffer: buffer, boxed: false)}
                    serializeInt32(limit, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.getMessageReactionsList", parameters: [("flags", String(describing: flags)), ("peer", String(describing: peer)), ("id", String(describing: id)), ("reaction", String(describing: reaction)), ("offset", String(describing: offset)), ("limit", String(describing: limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.MessageReactionsList? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.MessageReactionsList?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.MessageReactionsList
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func getMessageReadParticipants(peer: Api.InputPeer, msgId: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Int64]>) {
                    let buffer = Buffer()
                    buffer.appendInt32(745510839)
                    peer.serialize(buffer, true)
                    serializeInt32(msgId, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.getMessageReadParticipants", parameters: [("peer", String(describing: peer)), ("msgId", String(describing: msgId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> [Int64]? in
                        let reader = BufferReader(buffer)
                        var result: [Int64]?
                        if let _ = reader.readInt32() {
                            result = Api.parseVector(reader, elementSignature: 570911930, elementType: Int64.self)
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func getMessages(id: [Api.InputMessage]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.Messages>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1673946374)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(id.count))
                    for item in id {
                        item.serialize(buffer, true)
                    }
                    return (FunctionDescription(name: "messages.getMessages", parameters: [("id", String(describing: id))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.Messages? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.Messages?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.Messages
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func getMessagesReactions(peer: Api.InputPeer, id: [Int32]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1950707482)
                    peer.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(id.count))
                    for item in id {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    return (FunctionDescription(name: "messages.getMessagesReactions", parameters: [("peer", String(describing: peer)), ("id", String(describing: id))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func getMessagesViews(peer: Api.InputPeer, id: [Int32], increment: Api.Bool) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.MessageViews>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1468322785)
                    peer.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(id.count))
                    for item in id {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    increment.serialize(buffer, true)
                    return (FunctionDescription(name: "messages.getMessagesViews", parameters: [("peer", String(describing: peer)), ("id", String(describing: id)), ("increment", String(describing: increment))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.MessageViews? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.MessageViews?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.MessageViews
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func getOldFeaturedStickers(offset: Int32, limit: Int32, hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.FeaturedStickers>) {
                    let buffer = Buffer()
                    buffer.appendInt32(2127598753)
                    serializeInt32(offset, buffer: buffer, boxed: false)
                    serializeInt32(limit, buffer: buffer, boxed: false)
                    serializeInt64(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.getOldFeaturedStickers", parameters: [("offset", String(describing: offset)), ("limit", String(describing: limit)), ("hash", String(describing: hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.FeaturedStickers? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.FeaturedStickers?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.FeaturedStickers
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func getOnlines(peer: Api.InputPeer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.ChatOnlines>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1848369232)
                    peer.serialize(buffer, true)
                    return (FunctionDescription(name: "messages.getOnlines", parameters: [("peer", String(describing: peer))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.ChatOnlines? in
                        let reader = BufferReader(buffer)
                        var result: Api.ChatOnlines?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.ChatOnlines
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func getPeerDialogs(peers: [Api.InputDialogPeer]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.PeerDialogs>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-462373635)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(peers.count))
                    for item in peers {
                        item.serialize(buffer, true)
                    }
                    return (FunctionDescription(name: "messages.getPeerDialogs", parameters: [("peers", String(describing: peers))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.PeerDialogs? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.PeerDialogs?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.PeerDialogs
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func getPeerSettings(peer: Api.InputPeer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.PeerSettings>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-270948702)
                    peer.serialize(buffer, true)
                    return (FunctionDescription(name: "messages.getPeerSettings", parameters: [("peer", String(describing: peer))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.PeerSettings? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.PeerSettings?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.PeerSettings
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func getPinnedDialogs(folderId: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.PeerDialogs>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-692498958)
                    serializeInt32(folderId, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.getPinnedDialogs", parameters: [("folderId", String(describing: folderId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.PeerDialogs? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.PeerDialogs?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.PeerDialogs
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func getPollResults(peer: Api.InputPeer, msgId: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1941660731)
                    peer.serialize(buffer, true)
                    serializeInt32(msgId, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.getPollResults", parameters: [("peer", String(describing: peer)), ("msgId", String(describing: msgId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func getPollVotes(flags: Int32, peer: Api.InputPeer, id: Int32, option: Buffer?, offset: String?, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.VotesList>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1200736242)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    serializeInt32(id, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeBytes(option!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(offset!, buffer: buffer, boxed: false)}
                    serializeInt32(limit, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.getPollVotes", parameters: [("flags", String(describing: flags)), ("peer", String(describing: peer)), ("id", String(describing: id)), ("option", String(describing: option)), ("offset", String(describing: offset)), ("limit", String(describing: limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.VotesList? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.VotesList?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.VotesList
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func getRecentLocations(peer: Api.InputPeer, limit: Int32, hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.Messages>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1881817312)
                    peer.serialize(buffer, true)
                    serializeInt32(limit, buffer: buffer, boxed: false)
                    serializeInt64(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.getRecentLocations", parameters: [("peer", String(describing: peer)), ("limit", String(describing: limit)), ("hash", String(describing: hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.Messages? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.Messages?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.Messages
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func getRecentReactions(limit: Int32, hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.Reactions>) {
                    let buffer = Buffer()
                    buffer.appendInt32(960896434)
                    serializeInt32(limit, buffer: buffer, boxed: false)
                    serializeInt64(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.getRecentReactions", parameters: [("limit", String(describing: limit)), ("hash", String(describing: hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.Reactions? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.Reactions?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.Reactions
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func getRecentStickers(flags: Int32, hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.RecentStickers>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1649852357)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.getRecentStickers", parameters: [("flags", String(describing: flags)), ("hash", String(describing: hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.RecentStickers? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.RecentStickers?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.RecentStickers
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func getReplies(peer: Api.InputPeer, msgId: Int32, offsetId: Int32, offsetDate: Int32, addOffset: Int32, limit: Int32, maxId: Int32, minId: Int32, hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.Messages>) {
                    let buffer = Buffer()
                    buffer.appendInt32(584962828)
                    peer.serialize(buffer, true)
                    serializeInt32(msgId, buffer: buffer, boxed: false)
                    serializeInt32(offsetId, buffer: buffer, boxed: false)
                    serializeInt32(offsetDate, buffer: buffer, boxed: false)
                    serializeInt32(addOffset, buffer: buffer, boxed: false)
                    serializeInt32(limit, buffer: buffer, boxed: false)
                    serializeInt32(maxId, buffer: buffer, boxed: false)
                    serializeInt32(minId, buffer: buffer, boxed: false)
                    serializeInt64(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.getReplies", parameters: [("peer", String(describing: peer)), ("msgId", String(describing: msgId)), ("offsetId", String(describing: offsetId)), ("offsetDate", String(describing: offsetDate)), ("addOffset", String(describing: addOffset)), ("limit", String(describing: limit)), ("maxId", String(describing: maxId)), ("minId", String(describing: minId)), ("hash", String(describing: hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.Messages? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.Messages?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.Messages
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func getSavedGifs(hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.SavedGifs>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1559270965)
                    serializeInt64(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.getSavedGifs", parameters: [("hash", String(describing: hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.SavedGifs? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.SavedGifs?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.SavedGifs
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func getScheduledHistory(peer: Api.InputPeer, hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.Messages>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-183077365)
                    peer.serialize(buffer, true)
                    serializeInt64(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.getScheduledHistory", parameters: [("peer", String(describing: peer)), ("hash", String(describing: hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.Messages? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.Messages?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.Messages
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func getScheduledMessages(peer: Api.InputPeer, id: [Int32]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.Messages>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1111817116)
                    peer.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(id.count))
                    for item in id {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    return (FunctionDescription(name: "messages.getScheduledMessages", parameters: [("peer", String(describing: peer)), ("id", String(describing: id))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.Messages? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.Messages?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.Messages
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func getSearchCounters(flags: Int32, peer: Api.InputPeer, topMsgId: Int32?, filters: [Api.MessagesFilter]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Api.messages.SearchCounter]>) {
                    let buffer = Buffer()
                    buffer.appendInt32(11435201)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(topMsgId!, buffer: buffer, boxed: false)}
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(filters.count))
                    for item in filters {
                        item.serialize(buffer, true)
                    }
                    return (FunctionDescription(name: "messages.getSearchCounters", parameters: [("flags", String(describing: flags)), ("peer", String(describing: peer)), ("topMsgId", String(describing: topMsgId)), ("filters", String(describing: filters))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> [Api.messages.SearchCounter]? in
                        let reader = BufferReader(buffer)
                        var result: [Api.messages.SearchCounter]?
                        if let _ = reader.readInt32() {
                            result = Api.parseVector(reader, elementSignature: 0, elementType: Api.messages.SearchCounter.self)
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func getSearchResultsCalendar(peer: Api.InputPeer, filter: Api.MessagesFilter, offsetId: Int32, offsetDate: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.SearchResultsCalendar>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1240514025)
                    peer.serialize(buffer, true)
                    filter.serialize(buffer, true)
                    serializeInt32(offsetId, buffer: buffer, boxed: false)
                    serializeInt32(offsetDate, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.getSearchResultsCalendar", parameters: [("peer", String(describing: peer)), ("filter", String(describing: filter)), ("offsetId", String(describing: offsetId)), ("offsetDate", String(describing: offsetDate))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.SearchResultsCalendar? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.SearchResultsCalendar?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.SearchResultsCalendar
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func getSearchResultsPositions(peer: Api.InputPeer, filter: Api.MessagesFilter, offsetId: Int32, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.SearchResultsPositions>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1855292323)
                    peer.serialize(buffer, true)
                    filter.serialize(buffer, true)
                    serializeInt32(offsetId, buffer: buffer, boxed: false)
                    serializeInt32(limit, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.getSearchResultsPositions", parameters: [("peer", String(describing: peer)), ("filter", String(describing: filter)), ("offsetId", String(describing: offsetId)), ("limit", String(describing: limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.SearchResultsPositions? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.SearchResultsPositions?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.SearchResultsPositions
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func getSplitRanges() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Api.MessageRange]>) {
                    let buffer = Buffer()
                    buffer.appendInt32(486505992)
                    
                    return (FunctionDescription(name: "messages.getSplitRanges", parameters: []), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> [Api.MessageRange]? in
                        let reader = BufferReader(buffer)
                        var result: [Api.MessageRange]?
                        if let _ = reader.readInt32() {
                            result = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessageRange.self)
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func getStickerSet(stickerset: Api.InputStickerSet, hash: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.StickerSet>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-928977804)
                    stickerset.serialize(buffer, true)
                    serializeInt32(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.getStickerSet", parameters: [("stickerset", String(describing: stickerset)), ("hash", String(describing: hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.StickerSet? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.StickerSet?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.StickerSet
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func getStickers(emoticon: String, hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.Stickers>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-710552671)
                    serializeString(emoticon, buffer: buffer, boxed: false)
                    serializeInt64(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.getStickers", parameters: [("emoticon", String(describing: emoticon)), ("hash", String(describing: hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.Stickers? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.Stickers?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.Stickers
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func getSuggestedDialogFilters() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Api.DialogFilterSuggested]>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1566780372)
                    
                    return (FunctionDescription(name: "messages.getSuggestedDialogFilters", parameters: []), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> [Api.DialogFilterSuggested]? in
                        let reader = BufferReader(buffer)
                        var result: [Api.DialogFilterSuggested]?
                        if let _ = reader.readInt32() {
                            result = Api.parseVector(reader, elementSignature: 0, elementType: Api.DialogFilterSuggested.self)
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func getTopReactions(limit: Int32, hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.Reactions>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1149164102)
                    serializeInt32(limit, buffer: buffer, boxed: false)
                    serializeInt64(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.getTopReactions", parameters: [("limit", String(describing: limit)), ("hash", String(describing: hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.Reactions? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.Reactions?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.Reactions
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func getUnreadMentions(flags: Int32, peer: Api.InputPeer, topMsgId: Int32?, offsetId: Int32, addOffset: Int32, limit: Int32, maxId: Int32, minId: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.Messages>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-251140208)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(topMsgId!, buffer: buffer, boxed: false)}
                    serializeInt32(offsetId, buffer: buffer, boxed: false)
                    serializeInt32(addOffset, buffer: buffer, boxed: false)
                    serializeInt32(limit, buffer: buffer, boxed: false)
                    serializeInt32(maxId, buffer: buffer, boxed: false)
                    serializeInt32(minId, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.getUnreadMentions", parameters: [("flags", String(describing: flags)), ("peer", String(describing: peer)), ("topMsgId", String(describing: topMsgId)), ("offsetId", String(describing: offsetId)), ("addOffset", String(describing: addOffset)), ("limit", String(describing: limit)), ("maxId", String(describing: maxId)), ("minId", String(describing: minId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.Messages? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.Messages?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.Messages
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func getUnreadReactions(flags: Int32, peer: Api.InputPeer, topMsgId: Int32?, offsetId: Int32, addOffset: Int32, limit: Int32, maxId: Int32, minId: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.Messages>) {
                    let buffer = Buffer()
                    buffer.appendInt32(841173339)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(topMsgId!, buffer: buffer, boxed: false)}
                    serializeInt32(offsetId, buffer: buffer, boxed: false)
                    serializeInt32(addOffset, buffer: buffer, boxed: false)
                    serializeInt32(limit, buffer: buffer, boxed: false)
                    serializeInt32(maxId, buffer: buffer, boxed: false)
                    serializeInt32(minId, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.getUnreadReactions", parameters: [("flags", String(describing: flags)), ("peer", String(describing: peer)), ("topMsgId", String(describing: topMsgId)), ("offsetId", String(describing: offsetId)), ("addOffset", String(describing: addOffset)), ("limit", String(describing: limit)), ("maxId", String(describing: maxId)), ("minId", String(describing: minId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.Messages? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.Messages?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.Messages
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func getWebPage(url: String, hash: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.WebPage>) {
                    let buffer = Buffer()
                    buffer.appendInt32(852135825)
                    serializeString(url, buffer: buffer, boxed: false)
                    serializeInt32(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.getWebPage", parameters: [("url", String(describing: url)), ("hash", String(describing: hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.WebPage? in
                        let reader = BufferReader(buffer)
                        var result: Api.WebPage?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.WebPage
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func getWebPagePreview(flags: Int32, message: String, entities: [Api.MessageEntity]?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.MessageMedia>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1956073268)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(message, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 3) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(entities!.count))
                    for item in entities! {
                        item.serialize(buffer, true)
                    }}
                    return (FunctionDescription(name: "messages.getWebPagePreview", parameters: [("flags", String(describing: flags)), ("message", String(describing: message)), ("entities", String(describing: entities))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.MessageMedia? in
                        let reader = BufferReader(buffer)
                        var result: Api.MessageMedia?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.MessageMedia
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func hideAllChatJoinRequests(flags: Int32, peer: Api.InputPeer, link: String?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-528091926)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(link!, buffer: buffer, boxed: false)}
                    return (FunctionDescription(name: "messages.hideAllChatJoinRequests", parameters: [("flags", String(describing: flags)), ("peer", String(describing: peer)), ("link", String(describing: link))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func hideChatJoinRequest(flags: Int32, peer: Api.InputPeer, userId: Api.InputUser) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(2145904661)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    userId.serialize(buffer, true)
                    return (FunctionDescription(name: "messages.hideChatJoinRequest", parameters: [("flags", String(describing: flags)), ("peer", String(describing: peer)), ("userId", String(describing: userId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func hidePeerSettingsBar(peer: Api.InputPeer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1336717624)
                    peer.serialize(buffer, true)
                    return (FunctionDescription(name: "messages.hidePeerSettingsBar", parameters: [("peer", String(describing: peer))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func importChatInvite(hash: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1817183516)
                    serializeString(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.importChatInvite", parameters: [("hash", String(describing: hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func initHistoryImport(peer: Api.InputPeer, file: Api.InputFile, mediaCount: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.HistoryImport>) {
                    let buffer = Buffer()
                    buffer.appendInt32(873008187)
                    peer.serialize(buffer, true)
                    file.serialize(buffer, true)
                    serializeInt32(mediaCount, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.initHistoryImport", parameters: [("peer", String(describing: peer)), ("file", String(describing: file)), ("mediaCount", String(describing: mediaCount))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.HistoryImport? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.HistoryImport?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.HistoryImport
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func installStickerSet(stickerset: Api.InputStickerSet, archived: Api.Bool) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.StickerSetInstallResult>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-946871200)
                    stickerset.serialize(buffer, true)
                    archived.serialize(buffer, true)
                    return (FunctionDescription(name: "messages.installStickerSet", parameters: [("stickerset", String(describing: stickerset)), ("archived", String(describing: archived))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.StickerSetInstallResult? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.StickerSetInstallResult?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.StickerSetInstallResult
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func markDialogUnread(flags: Int32, peer: Api.InputDialogPeer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1031349873)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    return (FunctionDescription(name: "messages.markDialogUnread", parameters: [("flags", String(describing: flags)), ("peer", String(describing: peer))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func migrateChat(chatId: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1568189671)
                    serializeInt64(chatId, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.migrateChat", parameters: [("chatId", String(describing: chatId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func prolongWebView(flags: Int32, peer: Api.InputPeer, bot: Api.InputUser, queryId: Int64, replyToMsgId: Int32?, topMsgId: Int32?, sendAs: Api.InputPeer?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(2146648841)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    bot.serialize(buffer, true)
                    serializeInt64(queryId, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(replyToMsgId!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 9) != 0 {serializeInt32(topMsgId!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 13) != 0 {sendAs!.serialize(buffer, true)}
                    return (FunctionDescription(name: "messages.prolongWebView", parameters: [("flags", String(describing: flags)), ("peer", String(describing: peer)), ("bot", String(describing: bot)), ("queryId", String(describing: queryId)), ("replyToMsgId", String(describing: replyToMsgId)), ("topMsgId", String(describing: topMsgId)), ("sendAs", String(describing: sendAs))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func rateTranscribedAudio(peer: Api.InputPeer, msgId: Int32, transcriptionId: Int64, good: Api.Bool) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(2132608815)
                    peer.serialize(buffer, true)
                    serializeInt32(msgId, buffer: buffer, boxed: false)
                    serializeInt64(transcriptionId, buffer: buffer, boxed: false)
                    good.serialize(buffer, true)
                    return (FunctionDescription(name: "messages.rateTranscribedAudio", parameters: [("peer", String(describing: peer)), ("msgId", String(describing: msgId)), ("transcriptionId", String(describing: transcriptionId)), ("good", String(describing: good))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func readDiscussion(peer: Api.InputPeer, msgId: Int32, readMaxId: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-147740172)
                    peer.serialize(buffer, true)
                    serializeInt32(msgId, buffer: buffer, boxed: false)
                    serializeInt32(readMaxId, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.readDiscussion", parameters: [("peer", String(describing: peer)), ("msgId", String(describing: msgId)), ("readMaxId", String(describing: readMaxId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func readEncryptedHistory(peer: Api.InputEncryptedChat, maxDate: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(2135648522)
                    peer.serialize(buffer, true)
                    serializeInt32(maxDate, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.readEncryptedHistory", parameters: [("peer", String(describing: peer)), ("maxDate", String(describing: maxDate))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func readFeaturedStickers(id: [Int64]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1527873830)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(id.count))
                    for item in id {
                        serializeInt64(item, buffer: buffer, boxed: false)
                    }
                    return (FunctionDescription(name: "messages.readFeaturedStickers", parameters: [("id", String(describing: id))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func readHistory(peer: Api.InputPeer, maxId: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.AffectedMessages>) {
                    let buffer = Buffer()
                    buffer.appendInt32(238054714)
                    peer.serialize(buffer, true)
                    serializeInt32(maxId, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.readHistory", parameters: [("peer", String(describing: peer)), ("maxId", String(describing: maxId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.AffectedMessages? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.AffectedMessages?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.AffectedMessages
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func readMentions(flags: Int32, peer: Api.InputPeer, topMsgId: Int32?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.AffectedHistory>) {
                    let buffer = Buffer()
                    buffer.appendInt32(921026381)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(topMsgId!, buffer: buffer, boxed: false)}
                    return (FunctionDescription(name: "messages.readMentions", parameters: [("flags", String(describing: flags)), ("peer", String(describing: peer)), ("topMsgId", String(describing: topMsgId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.AffectedHistory? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.AffectedHistory?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.AffectedHistory
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func readMessageContents(id: [Int32]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.AffectedMessages>) {
                    let buffer = Buffer()
                    buffer.appendInt32(916930423)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(id.count))
                    for item in id {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    return (FunctionDescription(name: "messages.readMessageContents", parameters: [("id", String(describing: id))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.AffectedMessages? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.AffectedMessages?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.AffectedMessages
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func readReactions(flags: Int32, peer: Api.InputPeer, topMsgId: Int32?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.AffectedHistory>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1420459918)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(topMsgId!, buffer: buffer, boxed: false)}
                    return (FunctionDescription(name: "messages.readReactions", parameters: [("flags", String(describing: flags)), ("peer", String(describing: peer)), ("topMsgId", String(describing: topMsgId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.AffectedHistory? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.AffectedHistory?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.AffectedHistory
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func receivedMessages(maxId: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Api.ReceivedNotifyMessage]>) {
                    let buffer = Buffer()
                    buffer.appendInt32(94983360)
                    serializeInt32(maxId, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.receivedMessages", parameters: [("maxId", String(describing: maxId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> [Api.ReceivedNotifyMessage]? in
                        let reader = BufferReader(buffer)
                        var result: [Api.ReceivedNotifyMessage]?
                        if let _ = reader.readInt32() {
                            result = Api.parseVector(reader, elementSignature: 0, elementType: Api.ReceivedNotifyMessage.self)
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func receivedQueue(maxQts: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Int64]>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1436924774)
                    serializeInt32(maxQts, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.receivedQueue", parameters: [("maxQts", String(describing: maxQts))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> [Int64]? in
                        let reader = BufferReader(buffer)
                        var result: [Int64]?
                        if let _ = reader.readInt32() {
                            result = Api.parseVector(reader, elementSignature: 570911930, elementType: Int64.self)
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func reorderPinnedDialogs(flags: Int32, folderId: Int32, order: [Api.InputDialogPeer]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(991616823)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(folderId, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(order.count))
                    for item in order {
                        item.serialize(buffer, true)
                    }
                    return (FunctionDescription(name: "messages.reorderPinnedDialogs", parameters: [("flags", String(describing: flags)), ("folderId", String(describing: folderId)), ("order", String(describing: order))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func reorderStickerSets(flags: Int32, order: [Int64]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(2016638777)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(order.count))
                    for item in order {
                        serializeInt64(item, buffer: buffer, boxed: false)
                    }
                    return (FunctionDescription(name: "messages.reorderStickerSets", parameters: [("flags", String(describing: flags)), ("order", String(describing: order))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func report(peer: Api.InputPeer, id: [Int32], reason: Api.ReportReason, message: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1991005362)
                    peer.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(id.count))
                    for item in id {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    reason.serialize(buffer, true)
                    serializeString(message, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.report", parameters: [("peer", String(describing: peer)), ("id", String(describing: id)), ("reason", String(describing: reason)), ("message", String(describing: message))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func reportEncryptedSpam(peer: Api.InputEncryptedChat) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1259113487)
                    peer.serialize(buffer, true)
                    return (FunctionDescription(name: "messages.reportEncryptedSpam", parameters: [("peer", String(describing: peer))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func reportReaction(peer: Api.InputPeer, id: Int32, reactionPeer: Api.InputPeer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1063567478)
                    peer.serialize(buffer, true)
                    serializeInt32(id, buffer: buffer, boxed: false)
                    reactionPeer.serialize(buffer, true)
                    return (FunctionDescription(name: "messages.reportReaction", parameters: [("peer", String(describing: peer)), ("id", String(describing: id)), ("reactionPeer", String(describing: reactionPeer))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func reportSpam(peer: Api.InputPeer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-820669733)
                    peer.serialize(buffer, true)
                    return (FunctionDescription(name: "messages.reportSpam", parameters: [("peer", String(describing: peer))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func requestEncryption(userId: Api.InputUser, randomId: Int32, gA: Buffer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.EncryptedChat>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-162681021)
                    userId.serialize(buffer, true)
                    serializeInt32(randomId, buffer: buffer, boxed: false)
                    serializeBytes(gA, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.requestEncryption", parameters: [("userId", String(describing: userId)), ("randomId", String(describing: randomId)), ("gA", String(describing: gA))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.EncryptedChat? in
                        let reader = BufferReader(buffer)
                        var result: Api.EncryptedChat?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.EncryptedChat
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func requestSimpleWebView(flags: Int32, bot: Api.InputUser, url: String, themeParams: Api.DataJSON?, platform: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.SimpleWebViewResult>) {
                    let buffer = Buffer()
                    buffer.appendInt32(698084494)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    bot.serialize(buffer, true)
                    serializeString(url, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {themeParams!.serialize(buffer, true)}
                    serializeString(platform, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.requestSimpleWebView", parameters: [("flags", String(describing: flags)), ("bot", String(describing: bot)), ("url", String(describing: url)), ("themeParams", String(describing: themeParams)), ("platform", String(describing: platform))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.SimpleWebViewResult? in
                        let reader = BufferReader(buffer)
                        var result: Api.SimpleWebViewResult?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.SimpleWebViewResult
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func requestUrlAuth(flags: Int32, peer: Api.InputPeer?, msgId: Int32?, buttonId: Int32?, url: String?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.UrlAuthResult>) {
                    let buffer = Buffer()
                    buffer.appendInt32(428848198)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {peer!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt32(msgId!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt32(buttonId!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeString(url!, buffer: buffer, boxed: false)}
                    return (FunctionDescription(name: "messages.requestUrlAuth", parameters: [("flags", String(describing: flags)), ("peer", String(describing: peer)), ("msgId", String(describing: msgId)), ("buttonId", String(describing: buttonId)), ("url", String(describing: url))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.UrlAuthResult? in
                        let reader = BufferReader(buffer)
                        var result: Api.UrlAuthResult?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.UrlAuthResult
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func requestWebView(flags: Int32, peer: Api.InputPeer, bot: Api.InputUser, url: String?, startParam: String?, themeParams: Api.DataJSON?, platform: String, replyToMsgId: Int32?, topMsgId: Int32?, sendAs: Api.InputPeer?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.WebViewResult>) {
                    let buffer = Buffer()
                    buffer.appendInt32(395003915)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    bot.serialize(buffer, true)
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(url!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 3) != 0 {serializeString(startParam!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {themeParams!.serialize(buffer, true)}
                    serializeString(platform, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(replyToMsgId!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 9) != 0 {serializeInt32(topMsgId!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 13) != 0 {sendAs!.serialize(buffer, true)}
                    return (FunctionDescription(name: "messages.requestWebView", parameters: [("flags", String(describing: flags)), ("peer", String(describing: peer)), ("bot", String(describing: bot)), ("url", String(describing: url)), ("startParam", String(describing: startParam)), ("themeParams", String(describing: themeParams)), ("platform", String(describing: platform)), ("replyToMsgId", String(describing: replyToMsgId)), ("topMsgId", String(describing: topMsgId)), ("sendAs", String(describing: sendAs))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.WebViewResult? in
                        let reader = BufferReader(buffer)
                        var result: Api.WebViewResult?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.WebViewResult
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func saveDefaultSendAs(peer: Api.InputPeer, sendAs: Api.InputPeer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-855777386)
                    peer.serialize(buffer, true)
                    sendAs.serialize(buffer, true)
                    return (FunctionDescription(name: "messages.saveDefaultSendAs", parameters: [("peer", String(describing: peer)), ("sendAs", String(describing: sendAs))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func saveDraft(flags: Int32, replyToMsgId: Int32?, topMsgId: Int32?, peer: Api.InputPeer, message: String, entities: [Api.MessageEntity]?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1271718337)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(replyToMsgId!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeInt32(topMsgId!, buffer: buffer, boxed: false)}
                    peer.serialize(buffer, true)
                    serializeString(message, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 3) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(entities!.count))
                    for item in entities! {
                        item.serialize(buffer, true)
                    }}
                    return (FunctionDescription(name: "messages.saveDraft", parameters: [("flags", String(describing: flags)), ("replyToMsgId", String(describing: replyToMsgId)), ("topMsgId", String(describing: topMsgId)), ("peer", String(describing: peer)), ("message", String(describing: message)), ("entities", String(describing: entities))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func saveGif(id: Api.InputDocument, unsave: Api.Bool) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(846868683)
                    id.serialize(buffer, true)
                    unsave.serialize(buffer, true)
                    return (FunctionDescription(name: "messages.saveGif", parameters: [("id", String(describing: id)), ("unsave", String(describing: unsave))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func saveRecentSticker(flags: Int32, id: Api.InputDocument, unsave: Api.Bool) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(958863608)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    id.serialize(buffer, true)
                    unsave.serialize(buffer, true)
                    return (FunctionDescription(name: "messages.saveRecentSticker", parameters: [("flags", String(describing: flags)), ("id", String(describing: id)), ("unsave", String(describing: unsave))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func search(flags: Int32, peer: Api.InputPeer, q: String, fromId: Api.InputPeer?, topMsgId: Int32?, filter: Api.MessagesFilter, minDate: Int32, maxDate: Int32, offsetId: Int32, addOffset: Int32, limit: Int32, maxId: Int32, minId: Int32, hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.Messages>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1593989278)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    serializeString(q, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {fromId!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt32(topMsgId!, buffer: buffer, boxed: false)}
                    filter.serialize(buffer, true)
                    serializeInt32(minDate, buffer: buffer, boxed: false)
                    serializeInt32(maxDate, buffer: buffer, boxed: false)
                    serializeInt32(offsetId, buffer: buffer, boxed: false)
                    serializeInt32(addOffset, buffer: buffer, boxed: false)
                    serializeInt32(limit, buffer: buffer, boxed: false)
                    serializeInt32(maxId, buffer: buffer, boxed: false)
                    serializeInt32(minId, buffer: buffer, boxed: false)
                    serializeInt64(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.search", parameters: [("flags", String(describing: flags)), ("peer", String(describing: peer)), ("q", String(describing: q)), ("fromId", String(describing: fromId)), ("topMsgId", String(describing: topMsgId)), ("filter", String(describing: filter)), ("minDate", String(describing: minDate)), ("maxDate", String(describing: maxDate)), ("offsetId", String(describing: offsetId)), ("addOffset", String(describing: addOffset)), ("limit", String(describing: limit)), ("maxId", String(describing: maxId)), ("minId", String(describing: minId)), ("hash", String(describing: hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.Messages? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.Messages?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.Messages
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func searchGlobal(flags: Int32, folderId: Int32?, q: String, filter: Api.MessagesFilter, minDate: Int32, maxDate: Int32, offsetRate: Int32, offsetPeer: Api.InputPeer, offsetId: Int32, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.Messages>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1271290010)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(folderId!, buffer: buffer, boxed: false)}
                    serializeString(q, buffer: buffer, boxed: false)
                    filter.serialize(buffer, true)
                    serializeInt32(minDate, buffer: buffer, boxed: false)
                    serializeInt32(maxDate, buffer: buffer, boxed: false)
                    serializeInt32(offsetRate, buffer: buffer, boxed: false)
                    offsetPeer.serialize(buffer, true)
                    serializeInt32(offsetId, buffer: buffer, boxed: false)
                    serializeInt32(limit, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.searchGlobal", parameters: [("flags", String(describing: flags)), ("folderId", String(describing: folderId)), ("q", String(describing: q)), ("filter", String(describing: filter)), ("minDate", String(describing: minDate)), ("maxDate", String(describing: maxDate)), ("offsetRate", String(describing: offsetRate)), ("offsetPeer", String(describing: offsetPeer)), ("offsetId", String(describing: offsetId)), ("limit", String(describing: limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.Messages? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.Messages?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.Messages
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func searchSentMedia(q: String, filter: Api.MessagesFilter, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.Messages>) {
                    let buffer = Buffer()
                    buffer.appendInt32(276705696)
                    serializeString(q, buffer: buffer, boxed: false)
                    filter.serialize(buffer, true)
                    serializeInt32(limit, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.searchSentMedia", parameters: [("q", String(describing: q)), ("filter", String(describing: filter)), ("limit", String(describing: limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.Messages? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.Messages?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.Messages
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func searchStickerSets(flags: Int32, q: String, hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.FoundStickerSets>) {
                    let buffer = Buffer()
                    buffer.appendInt32(896555914)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(q, buffer: buffer, boxed: false)
                    serializeInt64(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.searchStickerSets", parameters: [("flags", String(describing: flags)), ("q", String(describing: q)), ("hash", String(describing: hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.FoundStickerSets? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.FoundStickerSets?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.FoundStickerSets
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func sendEncrypted(flags: Int32, peer: Api.InputEncryptedChat, randomId: Int64, data: Buffer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.SentEncryptedMessage>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1157265941)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    serializeInt64(randomId, buffer: buffer, boxed: false)
                    serializeBytes(data, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.sendEncrypted", parameters: [("flags", String(describing: flags)), ("peer", String(describing: peer)), ("randomId", String(describing: randomId)), ("data", String(describing: data))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.SentEncryptedMessage? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.SentEncryptedMessage?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.SentEncryptedMessage
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func sendEncryptedFile(flags: Int32, peer: Api.InputEncryptedChat, randomId: Int64, data: Buffer, file: Api.InputEncryptedFile) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.SentEncryptedMessage>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1431914525)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    serializeInt64(randomId, buffer: buffer, boxed: false)
                    serializeBytes(data, buffer: buffer, boxed: false)
                    file.serialize(buffer, true)
                    return (FunctionDescription(name: "messages.sendEncryptedFile", parameters: [("flags", String(describing: flags)), ("peer", String(describing: peer)), ("randomId", String(describing: randomId)), ("data", String(describing: data)), ("file", String(describing: file))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.SentEncryptedMessage? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.SentEncryptedMessage?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.SentEncryptedMessage
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func sendEncryptedService(peer: Api.InputEncryptedChat, randomId: Int64, data: Buffer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.SentEncryptedMessage>) {
                    let buffer = Buffer()
                    buffer.appendInt32(852769188)
                    peer.serialize(buffer, true)
                    serializeInt64(randomId, buffer: buffer, boxed: false)
                    serializeBytes(data, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.sendEncryptedService", parameters: [("peer", String(describing: peer)), ("randomId", String(describing: randomId)), ("data", String(describing: data))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.SentEncryptedMessage? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.SentEncryptedMessage?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.SentEncryptedMessage
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func sendInlineBotResult(flags: Int32, peer: Api.InputPeer, replyToMsgId: Int32?, topMsgId: Int32?, randomId: Int64, queryId: Int64, id: String, scheduleDate: Int32?, sendAs: Api.InputPeer?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-738468661)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(replyToMsgId!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 9) != 0 {serializeInt32(topMsgId!, buffer: buffer, boxed: false)}
                    serializeInt64(randomId, buffer: buffer, boxed: false)
                    serializeInt64(queryId, buffer: buffer, boxed: false)
                    serializeString(id, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 10) != 0 {serializeInt32(scheduleDate!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 13) != 0 {sendAs!.serialize(buffer, true)}
                    return (FunctionDescription(name: "messages.sendInlineBotResult", parameters: [("flags", String(describing: flags)), ("peer", String(describing: peer)), ("replyToMsgId", String(describing: replyToMsgId)), ("topMsgId", String(describing: topMsgId)), ("randomId", String(describing: randomId)), ("queryId", String(describing: queryId)), ("id", String(describing: id)), ("scheduleDate", String(describing: scheduleDate)), ("sendAs", String(describing: sendAs))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func sendMedia(flags: Int32, peer: Api.InputPeer, replyToMsgId: Int32?, topMsgId: Int32?, media: Api.InputMedia, message: String, randomId: Int64, replyMarkup: Api.ReplyMarkup?, entities: [Api.MessageEntity]?, scheduleDate: Int32?, sendAs: Api.InputPeer?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1967638886)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(replyToMsgId!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 9) != 0 {serializeInt32(topMsgId!, buffer: buffer, boxed: false)}
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
                    if Int(flags) & Int(1 << 13) != 0 {sendAs!.serialize(buffer, true)}
                    return (FunctionDescription(name: "messages.sendMedia", parameters: [("flags", String(describing: flags)), ("peer", String(describing: peer)), ("replyToMsgId", String(describing: replyToMsgId)), ("topMsgId", String(describing: topMsgId)), ("media", String(describing: media)), ("message", String(describing: message)), ("randomId", String(describing: randomId)), ("replyMarkup", String(describing: replyMarkup)), ("entities", String(describing: entities)), ("scheduleDate", String(describing: scheduleDate)), ("sendAs", String(describing: sendAs))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func sendMessage(flags: Int32, peer: Api.InputPeer, replyToMsgId: Int32?, topMsgId: Int32?, message: String, randomId: Int64, replyMarkup: Api.ReplyMarkup?, entities: [Api.MessageEntity]?, scheduleDate: Int32?, sendAs: Api.InputPeer?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(482476935)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(replyToMsgId!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 9) != 0 {serializeInt32(topMsgId!, buffer: buffer, boxed: false)}
                    serializeString(message, buffer: buffer, boxed: false)
                    serializeInt64(randomId, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 2) != 0 {replyMarkup!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 3) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(entities!.count))
                    for item in entities! {
                        item.serialize(buffer, true)
                    }}
                    if Int(flags) & Int(1 << 10) != 0 {serializeInt32(scheduleDate!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 13) != 0 {sendAs!.serialize(buffer, true)}
                    return (FunctionDescription(name: "messages.sendMessage", parameters: [("flags", String(describing: flags)), ("peer", String(describing: peer)), ("replyToMsgId", String(describing: replyToMsgId)), ("topMsgId", String(describing: topMsgId)), ("message", String(describing: message)), ("randomId", String(describing: randomId)), ("replyMarkup", String(describing: replyMarkup)), ("entities", String(describing: entities)), ("scheduleDate", String(describing: scheduleDate)), ("sendAs", String(describing: sendAs))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func sendMultiMedia(flags: Int32, peer: Api.InputPeer, replyToMsgId: Int32?, topMsgId: Int32?, multiMedia: [Api.InputSingleMedia], scheduleDate: Int32?, sendAs: Api.InputPeer?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1225713124)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(replyToMsgId!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 9) != 0 {serializeInt32(topMsgId!, buffer: buffer, boxed: false)}
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(multiMedia.count))
                    for item in multiMedia {
                        item.serialize(buffer, true)
                    }
                    if Int(flags) & Int(1 << 10) != 0 {serializeInt32(scheduleDate!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 13) != 0 {sendAs!.serialize(buffer, true)}
                    return (FunctionDescription(name: "messages.sendMultiMedia", parameters: [("flags", String(describing: flags)), ("peer", String(describing: peer)), ("replyToMsgId", String(describing: replyToMsgId)), ("topMsgId", String(describing: topMsgId)), ("multiMedia", String(describing: multiMedia)), ("scheduleDate", String(describing: scheduleDate)), ("sendAs", String(describing: sendAs))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func sendReaction(flags: Int32, peer: Api.InputPeer, msgId: Int32, reaction: [Api.Reaction]?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-754091820)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    serializeInt32(msgId, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(reaction!.count))
                    for item in reaction! {
                        item.serialize(buffer, true)
                    }}
                    return (FunctionDescription(name: "messages.sendReaction", parameters: [("flags", String(describing: flags)), ("peer", String(describing: peer)), ("msgId", String(describing: msgId)), ("reaction", String(describing: reaction))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func sendScheduledMessages(peer: Api.InputPeer, id: [Int32]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1120369398)
                    peer.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(id.count))
                    for item in id {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    return (FunctionDescription(name: "messages.sendScheduledMessages", parameters: [("peer", String(describing: peer)), ("id", String(describing: id))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func sendScreenshotNotification(peer: Api.InputPeer, replyToMsgId: Int32, randomId: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-914493408)
                    peer.serialize(buffer, true)
                    serializeInt32(replyToMsgId, buffer: buffer, boxed: false)
                    serializeInt64(randomId, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.sendScreenshotNotification", parameters: [("peer", String(describing: peer)), ("replyToMsgId", String(describing: replyToMsgId)), ("randomId", String(describing: randomId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func sendVote(peer: Api.InputPeer, msgId: Int32, options: [Buffer]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(283795844)
                    peer.serialize(buffer, true)
                    serializeInt32(msgId, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(options.count))
                    for item in options {
                        serializeBytes(item, buffer: buffer, boxed: false)
                    }
                    return (FunctionDescription(name: "messages.sendVote", parameters: [("peer", String(describing: peer)), ("msgId", String(describing: msgId)), ("options", String(describing: options))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func sendWebViewData(bot: Api.InputUser, randomId: Int64, buttonText: String, data: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-603831608)
                    bot.serialize(buffer, true)
                    serializeInt64(randomId, buffer: buffer, boxed: false)
                    serializeString(buttonText, buffer: buffer, boxed: false)
                    serializeString(data, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.sendWebViewData", parameters: [("bot", String(describing: bot)), ("randomId", String(describing: randomId)), ("buttonText", String(describing: buttonText)), ("data", String(describing: data))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func sendWebViewResultMessage(botQueryId: String, result: Api.InputBotInlineResult) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.WebViewMessageSent>) {
                    let buffer = Buffer()
                    buffer.appendInt32(172168437)
                    serializeString(botQueryId, buffer: buffer, boxed: false)
                    result.serialize(buffer, true)
                    return (FunctionDescription(name: "messages.sendWebViewResultMessage", parameters: [("botQueryId", String(describing: botQueryId)), ("result", String(describing: result))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.WebViewMessageSent? in
                        let reader = BufferReader(buffer)
                        var result: Api.WebViewMessageSent?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.WebViewMessageSent
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func setBotCallbackAnswer(flags: Int32, queryId: Int64, message: String?, url: String?, cacheTime: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-712043766)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(queryId, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(message!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeString(url!, buffer: buffer, boxed: false)}
                    serializeInt32(cacheTime, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.setBotCallbackAnswer", parameters: [("flags", String(describing: flags)), ("queryId", String(describing: queryId)), ("message", String(describing: message)), ("url", String(describing: url)), ("cacheTime", String(describing: cacheTime))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func setBotPrecheckoutResults(flags: Int32, queryId: Int64, error: String?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(163765653)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(queryId, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(error!, buffer: buffer, boxed: false)}
                    return (FunctionDescription(name: "messages.setBotPrecheckoutResults", parameters: [("flags", String(describing: flags)), ("queryId", String(describing: queryId)), ("error", String(describing: error))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func setBotShippingResults(flags: Int32, queryId: Int64, error: String?, shippingOptions: [Api.ShippingOption]?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
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
                    return (FunctionDescription(name: "messages.setBotShippingResults", parameters: [("flags", String(describing: flags)), ("queryId", String(describing: queryId)), ("error", String(describing: error)), ("shippingOptions", String(describing: shippingOptions))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func setChatAvailableReactions(peer: Api.InputPeer, availableReactions: Api.ChatReactions) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-21928079)
                    peer.serialize(buffer, true)
                    availableReactions.serialize(buffer, true)
                    return (FunctionDescription(name: "messages.setChatAvailableReactions", parameters: [("peer", String(describing: peer)), ("availableReactions", String(describing: availableReactions))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func setChatTheme(peer: Api.InputPeer, emoticon: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-432283329)
                    peer.serialize(buffer, true)
                    serializeString(emoticon, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.setChatTheme", parameters: [("peer", String(describing: peer)), ("emoticon", String(describing: emoticon))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func setDefaultReaction(reaction: Api.Reaction) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1330094102)
                    reaction.serialize(buffer, true)
                    return (FunctionDescription(name: "messages.setDefaultReaction", parameters: [("reaction", String(describing: reaction))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func setEncryptedTyping(peer: Api.InputEncryptedChat, typing: Api.Bool) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(2031374829)
                    peer.serialize(buffer, true)
                    typing.serialize(buffer, true)
                    return (FunctionDescription(name: "messages.setEncryptedTyping", parameters: [("peer", String(describing: peer)), ("typing", String(describing: typing))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func setGameScore(flags: Int32, peer: Api.InputPeer, id: Int32, userId: Api.InputUser, score: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1896289088)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    serializeInt32(id, buffer: buffer, boxed: false)
                    userId.serialize(buffer, true)
                    serializeInt32(score, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.setGameScore", parameters: [("flags", String(describing: flags)), ("peer", String(describing: peer)), ("id", String(describing: id)), ("userId", String(describing: userId)), ("score", String(describing: score))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func setHistoryTTL(peer: Api.InputPeer, period: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1207017500)
                    peer.serialize(buffer, true)
                    serializeInt32(period, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.setHistoryTTL", parameters: [("peer", String(describing: peer)), ("period", String(describing: period))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func setInlineBotResults(flags: Int32, queryId: Int64, results: [Api.InputBotInlineResult], cacheTime: Int32, nextOffset: String?, switchPm: Api.InlineBotSwitchPM?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
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
                    return (FunctionDescription(name: "messages.setInlineBotResults", parameters: [("flags", String(describing: flags)), ("queryId", String(describing: queryId)), ("results", String(describing: results)), ("cacheTime", String(describing: cacheTime)), ("nextOffset", String(describing: nextOffset)), ("switchPm", String(describing: switchPm))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func setInlineGameScore(flags: Int32, id: Api.InputBotInlineMessageID, userId: Api.InputUser, score: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(363700068)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    id.serialize(buffer, true)
                    userId.serialize(buffer, true)
                    serializeInt32(score, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.setInlineGameScore", parameters: [("flags", String(describing: flags)), ("id", String(describing: id)), ("userId", String(describing: userId)), ("score", String(describing: score))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func setTyping(flags: Int32, peer: Api.InputPeer, topMsgId: Int32?, action: Api.SendMessageAction) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1486110434)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(topMsgId!, buffer: buffer, boxed: false)}
                    action.serialize(buffer, true)
                    return (FunctionDescription(name: "messages.setTyping", parameters: [("flags", String(describing: flags)), ("peer", String(describing: peer)), ("topMsgId", String(describing: topMsgId)), ("action", String(describing: action))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func startBot(bot: Api.InputUser, peer: Api.InputPeer, randomId: Int64, startParam: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-421563528)
                    bot.serialize(buffer, true)
                    peer.serialize(buffer, true)
                    serializeInt64(randomId, buffer: buffer, boxed: false)
                    serializeString(startParam, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.startBot", parameters: [("bot", String(describing: bot)), ("peer", String(describing: peer)), ("randomId", String(describing: randomId)), ("startParam", String(describing: startParam))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func startHistoryImport(peer: Api.InputPeer, importId: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1271008444)
                    peer.serialize(buffer, true)
                    serializeInt64(importId, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.startHistoryImport", parameters: [("peer", String(describing: peer)), ("importId", String(describing: importId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func toggleBotInAttachMenu(bot: Api.InputUser, enabled: Api.Bool) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(451818415)
                    bot.serialize(buffer, true)
                    enabled.serialize(buffer, true)
                    return (FunctionDescription(name: "messages.toggleBotInAttachMenu", parameters: [("bot", String(describing: bot)), ("enabled", String(describing: enabled))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func toggleDialogPin(flags: Int32, peer: Api.InputDialogPeer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1489903017)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    return (FunctionDescription(name: "messages.toggleDialogPin", parameters: [("flags", String(describing: flags)), ("peer", String(describing: peer))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func toggleNoForwards(peer: Api.InputPeer, enabled: Api.Bool) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1323389022)
                    peer.serialize(buffer, true)
                    enabled.serialize(buffer, true)
                    return (FunctionDescription(name: "messages.toggleNoForwards", parameters: [("peer", String(describing: peer)), ("enabled", String(describing: enabled))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func toggleStickerSets(flags: Int32, stickersets: [Api.InputStickerSet]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1257951254)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(stickersets.count))
                    for item in stickersets {
                        item.serialize(buffer, true)
                    }
                    return (FunctionDescription(name: "messages.toggleStickerSets", parameters: [("flags", String(describing: flags)), ("stickersets", String(describing: stickersets))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func transcribeAudio(peer: Api.InputPeer, msgId: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.TranscribedAudio>) {
                    let buffer = Buffer()
                    buffer.appendInt32(647928393)
                    peer.serialize(buffer, true)
                    serializeInt32(msgId, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.transcribeAudio", parameters: [("peer", String(describing: peer)), ("msgId", String(describing: msgId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.TranscribedAudio? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.TranscribedAudio?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.TranscribedAudio
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func translateText(flags: Int32, peer: Api.InputPeer?, msgId: Int32?, text: String?, fromLang: String?, toLang: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.TranslatedText>) {
                    let buffer = Buffer()
                    buffer.appendInt32(617508334)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {peer!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(msgId!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(text!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeString(fromLang!, buffer: buffer, boxed: false)}
                    serializeString(toLang, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.translateText", parameters: [("flags", String(describing: flags)), ("peer", String(describing: peer)), ("msgId", String(describing: msgId)), ("text", String(describing: text)), ("fromLang", String(describing: fromLang)), ("toLang", String(describing: toLang))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.TranslatedText? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.TranslatedText?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.TranslatedText
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func uninstallStickerSet(stickerset: Api.InputStickerSet) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-110209570)
                    stickerset.serialize(buffer, true)
                    return (FunctionDescription(name: "messages.uninstallStickerSet", parameters: [("stickerset", String(describing: stickerset))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func unpinAllMessages(flags: Int32, peer: Api.InputPeer, topMsgId: Int32?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.AffectedHistory>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-299714136)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(topMsgId!, buffer: buffer, boxed: false)}
                    return (FunctionDescription(name: "messages.unpinAllMessages", parameters: [("flags", String(describing: flags)), ("peer", String(describing: peer)), ("topMsgId", String(describing: topMsgId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.AffectedHistory? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.AffectedHistory?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.AffectedHistory
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func updateDialogFilter(flags: Int32, id: Int32, filter: Api.DialogFilter?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(450142282)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(id, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {filter!.serialize(buffer, true)}
                    return (FunctionDescription(name: "messages.updateDialogFilter", parameters: [("flags", String(describing: flags)), ("id", String(describing: id)), ("filter", String(describing: filter))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func updateDialogFiltersOrder(order: [Int32]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-983318044)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(order.count))
                    for item in order {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    return (FunctionDescription(name: "messages.updateDialogFiltersOrder", parameters: [("order", String(describing: order))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func updatePinnedMessage(flags: Int32, peer: Api.InputPeer, id: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-760547348)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    serializeInt32(id, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.updatePinnedMessage", parameters: [("flags", String(describing: flags)), ("peer", String(describing: peer)), ("id", String(describing: id))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func uploadEncryptedFile(peer: Api.InputEncryptedChat, file: Api.InputEncryptedFile) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.EncryptedFile>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1347929239)
                    peer.serialize(buffer, true)
                    file.serialize(buffer, true)
                    return (FunctionDescription(name: "messages.uploadEncryptedFile", parameters: [("peer", String(describing: peer)), ("file", String(describing: file))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.EncryptedFile? in
                        let reader = BufferReader(buffer)
                        var result: Api.EncryptedFile?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.EncryptedFile
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func uploadImportedMedia(peer: Api.InputPeer, importId: Int64, fileName: String, media: Api.InputMedia) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.MessageMedia>) {
                    let buffer = Buffer()
                    buffer.appendInt32(713433234)
                    peer.serialize(buffer, true)
                    serializeInt64(importId, buffer: buffer, boxed: false)
                    serializeString(fileName, buffer: buffer, boxed: false)
                    media.serialize(buffer, true)
                    return (FunctionDescription(name: "messages.uploadImportedMedia", parameters: [("peer", String(describing: peer)), ("importId", String(describing: importId)), ("fileName", String(describing: fileName)), ("media", String(describing: media))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.MessageMedia? in
                        let reader = BufferReader(buffer)
                        var result: Api.MessageMedia?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.MessageMedia
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func uploadMedia(peer: Api.InputPeer, media: Api.InputMedia) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.MessageMedia>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1369162417)
                    peer.serialize(buffer, true)
                    media.serialize(buffer, true)
                    return (FunctionDescription(name: "messages.uploadMedia", parameters: [("peer", String(describing: peer)), ("media", String(describing: media))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.MessageMedia? in
                        let reader = BufferReader(buffer)
                        var result: Api.MessageMedia?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.MessageMedia
                        }
                        return result
                    })
                }
}
public extension Api.functions.payments {
                static func assignAppStoreTransaction(receipt: Buffer, purpose: Api.InputStorePaymentPurpose) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-2131921795)
                    serializeBytes(receipt, buffer: buffer, boxed: false)
                    purpose.serialize(buffer, true)
                    return (FunctionDescription(name: "payments.assignAppStoreTransaction", parameters: [("receipt", String(describing: receipt)), ("purpose", String(describing: purpose))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
}
public extension Api.functions.payments {
                static func assignPlayMarketTransaction(receipt: Api.DataJSON, purpose: Api.InputStorePaymentPurpose) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-537046829)
                    receipt.serialize(buffer, true)
                    purpose.serialize(buffer, true)
                    return (FunctionDescription(name: "payments.assignPlayMarketTransaction", parameters: [("receipt", String(describing: receipt)), ("purpose", String(describing: purpose))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
}
public extension Api.functions.payments {
                static func canPurchasePremium(purpose: Api.InputStorePaymentPurpose) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1614700874)
                    purpose.serialize(buffer, true)
                    return (FunctionDescription(name: "payments.canPurchasePremium", parameters: [("purpose", String(describing: purpose))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.payments {
                static func clearSavedInfo(flags: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-667062079)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "payments.clearSavedInfo", parameters: [("flags", String(describing: flags))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.payments {
                static func exportInvoice(invoiceMedia: Api.InputMedia) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.payments.ExportedInvoice>) {
                    let buffer = Buffer()
                    buffer.appendInt32(261206117)
                    invoiceMedia.serialize(buffer, true)
                    return (FunctionDescription(name: "payments.exportInvoice", parameters: [("invoiceMedia", String(describing: invoiceMedia))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.payments.ExportedInvoice? in
                        let reader = BufferReader(buffer)
                        var result: Api.payments.ExportedInvoice?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.payments.ExportedInvoice
                        }
                        return result
                    })
                }
}
public extension Api.functions.payments {
                static func getBankCardData(number: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.payments.BankCardData>) {
                    let buffer = Buffer()
                    buffer.appendInt32(779736953)
                    serializeString(number, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "payments.getBankCardData", parameters: [("number", String(describing: number))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.payments.BankCardData? in
                        let reader = BufferReader(buffer)
                        var result: Api.payments.BankCardData?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.payments.BankCardData
                        }
                        return result
                    })
                }
}
public extension Api.functions.payments {
                static func getPaymentForm(flags: Int32, invoice: Api.InputInvoice, themeParams: Api.DataJSON?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.payments.PaymentForm>) {
                    let buffer = Buffer()
                    buffer.appendInt32(924093883)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    invoice.serialize(buffer, true)
                    if Int(flags) & Int(1 << 0) != 0 {themeParams!.serialize(buffer, true)}
                    return (FunctionDescription(name: "payments.getPaymentForm", parameters: [("flags", String(describing: flags)), ("invoice", String(describing: invoice)), ("themeParams", String(describing: themeParams))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.payments.PaymentForm? in
                        let reader = BufferReader(buffer)
                        var result: Api.payments.PaymentForm?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.payments.PaymentForm
                        }
                        return result
                    })
                }
}
public extension Api.functions.payments {
                static func getPaymentReceipt(peer: Api.InputPeer, msgId: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.payments.PaymentReceipt>) {
                    let buffer = Buffer()
                    buffer.appendInt32(611897804)
                    peer.serialize(buffer, true)
                    serializeInt32(msgId, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "payments.getPaymentReceipt", parameters: [("peer", String(describing: peer)), ("msgId", String(describing: msgId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.payments.PaymentReceipt? in
                        let reader = BufferReader(buffer)
                        var result: Api.payments.PaymentReceipt?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.payments.PaymentReceipt
                        }
                        return result
                    })
                }
}
public extension Api.functions.payments {
                static func getSavedInfo() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.payments.SavedInfo>) {
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
}
public extension Api.functions.payments {
                static func sendPaymentForm(flags: Int32, formId: Int64, invoice: Api.InputInvoice, requestedInfoId: String?, shippingOptionId: String?, credentials: Api.InputPaymentCredentials, tipAmount: Int64?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.payments.PaymentResult>) {
                    let buffer = Buffer()
                    buffer.appendInt32(755192367)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(formId, buffer: buffer, boxed: false)
                    invoice.serialize(buffer, true)
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(requestedInfoId!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(shippingOptionId!, buffer: buffer, boxed: false)}
                    credentials.serialize(buffer, true)
                    if Int(flags) & Int(1 << 2) != 0 {serializeInt64(tipAmount!, buffer: buffer, boxed: false)}
                    return (FunctionDescription(name: "payments.sendPaymentForm", parameters: [("flags", String(describing: flags)), ("formId", String(describing: formId)), ("invoice", String(describing: invoice)), ("requestedInfoId", String(describing: requestedInfoId)), ("shippingOptionId", String(describing: shippingOptionId)), ("credentials", String(describing: credentials)), ("tipAmount", String(describing: tipAmount))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.payments.PaymentResult? in
                        let reader = BufferReader(buffer)
                        var result: Api.payments.PaymentResult?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.payments.PaymentResult
                        }
                        return result
                    })
                }
}
public extension Api.functions.payments {
                static func validateRequestedInfo(flags: Int32, invoice: Api.InputInvoice, info: Api.PaymentRequestedInfo) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.payments.ValidatedRequestedInfo>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1228345045)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    invoice.serialize(buffer, true)
                    info.serialize(buffer, true)
                    return (FunctionDescription(name: "payments.validateRequestedInfo", parameters: [("flags", String(describing: flags)), ("invoice", String(describing: invoice)), ("info", String(describing: info))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.payments.ValidatedRequestedInfo? in
                        let reader = BufferReader(buffer)
                        var result: Api.payments.ValidatedRequestedInfo?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.payments.ValidatedRequestedInfo
                        }
                        return result
                    })
                }
}
public extension Api.functions.phone {
                static func acceptCall(peer: Api.InputPhoneCall, gB: Buffer, `protocol`: Api.PhoneCallProtocol) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.phone.PhoneCall>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1003664544)
                    peer.serialize(buffer, true)
                    serializeBytes(gB, buffer: buffer, boxed: false)
                    `protocol`.serialize(buffer, true)
                    return (FunctionDescription(name: "phone.acceptCall", parameters: [("peer", String(describing: peer)), ("gB", String(describing: gB)), ("`protocol`", String(describing: `protocol`))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.phone.PhoneCall? in
                        let reader = BufferReader(buffer)
                        var result: Api.phone.PhoneCall?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.phone.PhoneCall
                        }
                        return result
                    })
                }
}
public extension Api.functions.phone {
                static func checkGroupCall(call: Api.InputGroupCall, sources: [Int32]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Int32]>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1248003721)
                    call.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(sources.count))
                    for item in sources {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    return (FunctionDescription(name: "phone.checkGroupCall", parameters: [("call", String(describing: call)), ("sources", String(describing: sources))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> [Int32]? in
                        let reader = BufferReader(buffer)
                        var result: [Int32]?
                        if let _ = reader.readInt32() {
                            result = Api.parseVector(reader, elementSignature: -1471112230, elementType: Int32.self)
                        }
                        return result
                    })
                }
}
public extension Api.functions.phone {
                static func confirmCall(peer: Api.InputPhoneCall, gA: Buffer, keyFingerprint: Int64, `protocol`: Api.PhoneCallProtocol) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.phone.PhoneCall>) {
                    let buffer = Buffer()
                    buffer.appendInt32(788404002)
                    peer.serialize(buffer, true)
                    serializeBytes(gA, buffer: buffer, boxed: false)
                    serializeInt64(keyFingerprint, buffer: buffer, boxed: false)
                    `protocol`.serialize(buffer, true)
                    return (FunctionDescription(name: "phone.confirmCall", parameters: [("peer", String(describing: peer)), ("gA", String(describing: gA)), ("keyFingerprint", String(describing: keyFingerprint)), ("`protocol`", String(describing: `protocol`))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.phone.PhoneCall? in
                        let reader = BufferReader(buffer)
                        var result: Api.phone.PhoneCall?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.phone.PhoneCall
                        }
                        return result
                    })
                }
}
public extension Api.functions.phone {
                static func createGroupCall(flags: Int32, peer: Api.InputPeer, randomId: Int32, title: String?, scheduleDate: Int32?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1221445336)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    serializeInt32(randomId, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(title!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt32(scheduleDate!, buffer: buffer, boxed: false)}
                    return (FunctionDescription(name: "phone.createGroupCall", parameters: [("flags", String(describing: flags)), ("peer", String(describing: peer)), ("randomId", String(describing: randomId)), ("title", String(describing: title)), ("scheduleDate", String(describing: scheduleDate))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
}
public extension Api.functions.phone {
                static func discardCall(flags: Int32, peer: Api.InputPhoneCall, duration: Int32, reason: Api.PhoneCallDiscardReason, connectionId: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1295269440)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    serializeInt32(duration, buffer: buffer, boxed: false)
                    reason.serialize(buffer, true)
                    serializeInt64(connectionId, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "phone.discardCall", parameters: [("flags", String(describing: flags)), ("peer", String(describing: peer)), ("duration", String(describing: duration)), ("reason", String(describing: reason)), ("connectionId", String(describing: connectionId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
}
public extension Api.functions.phone {
                static func discardGroupCall(call: Api.InputGroupCall) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(2054648117)
                    call.serialize(buffer, true)
                    return (FunctionDescription(name: "phone.discardGroupCall", parameters: [("call", String(describing: call))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
}
public extension Api.functions.phone {
                static func editGroupCallParticipant(flags: Int32, call: Api.InputGroupCall, participant: Api.InputPeer, muted: Api.Bool?, volume: Int32?, raiseHand: Api.Bool?, videoStopped: Api.Bool?, videoPaused: Api.Bool?, presentationPaused: Api.Bool?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1524155713)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    call.serialize(buffer, true)
                    participant.serialize(buffer, true)
                    if Int(flags) & Int(1 << 0) != 0 {muted!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt32(volume!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {raiseHand!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 3) != 0 {videoStopped!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 4) != 0 {videoPaused!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 5) != 0 {presentationPaused!.serialize(buffer, true)}
                    return (FunctionDescription(name: "phone.editGroupCallParticipant", parameters: [("flags", String(describing: flags)), ("call", String(describing: call)), ("participant", String(describing: participant)), ("muted", String(describing: muted)), ("volume", String(describing: volume)), ("raiseHand", String(describing: raiseHand)), ("videoStopped", String(describing: videoStopped)), ("videoPaused", String(describing: videoPaused)), ("presentationPaused", String(describing: presentationPaused))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
}
public extension Api.functions.phone {
                static func editGroupCallTitle(call: Api.InputGroupCall, title: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(480685066)
                    call.serialize(buffer, true)
                    serializeString(title, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "phone.editGroupCallTitle", parameters: [("call", String(describing: call)), ("title", String(describing: title))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
}
public extension Api.functions.phone {
                static func exportGroupCallInvite(flags: Int32, call: Api.InputGroupCall) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.phone.ExportedGroupCallInvite>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-425040769)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    call.serialize(buffer, true)
                    return (FunctionDescription(name: "phone.exportGroupCallInvite", parameters: [("flags", String(describing: flags)), ("call", String(describing: call))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.phone.ExportedGroupCallInvite? in
                        let reader = BufferReader(buffer)
                        var result: Api.phone.ExportedGroupCallInvite?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.phone.ExportedGroupCallInvite
                        }
                        return result
                    })
                }
}
public extension Api.functions.phone {
                static func getCallConfig() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.DataJSON>) {
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
}
public extension Api.functions.phone {
                static func getGroupCall(call: Api.InputGroupCall, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.phone.GroupCall>) {
                    let buffer = Buffer()
                    buffer.appendInt32(68699611)
                    call.serialize(buffer, true)
                    serializeInt32(limit, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "phone.getGroupCall", parameters: [("call", String(describing: call)), ("limit", String(describing: limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.phone.GroupCall? in
                        let reader = BufferReader(buffer)
                        var result: Api.phone.GroupCall?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.phone.GroupCall
                        }
                        return result
                    })
                }
}
public extension Api.functions.phone {
                static func getGroupCallJoinAs(peer: Api.InputPeer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.phone.JoinAsPeers>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-277077702)
                    peer.serialize(buffer, true)
                    return (FunctionDescription(name: "phone.getGroupCallJoinAs", parameters: [("peer", String(describing: peer))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.phone.JoinAsPeers? in
                        let reader = BufferReader(buffer)
                        var result: Api.phone.JoinAsPeers?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.phone.JoinAsPeers
                        }
                        return result
                    })
                }
}
public extension Api.functions.phone {
                static func getGroupCallStreamChannels(call: Api.InputGroupCall) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.phone.GroupCallStreamChannels>) {
                    let buffer = Buffer()
                    buffer.appendInt32(447879488)
                    call.serialize(buffer, true)
                    return (FunctionDescription(name: "phone.getGroupCallStreamChannels", parameters: [("call", String(describing: call))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.phone.GroupCallStreamChannels? in
                        let reader = BufferReader(buffer)
                        var result: Api.phone.GroupCallStreamChannels?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.phone.GroupCallStreamChannels
                        }
                        return result
                    })
                }
}
public extension Api.functions.phone {
                static func getGroupCallStreamRtmpUrl(peer: Api.InputPeer, revoke: Api.Bool) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.phone.GroupCallStreamRtmpUrl>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-558650433)
                    peer.serialize(buffer, true)
                    revoke.serialize(buffer, true)
                    return (FunctionDescription(name: "phone.getGroupCallStreamRtmpUrl", parameters: [("peer", String(describing: peer)), ("revoke", String(describing: revoke))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.phone.GroupCallStreamRtmpUrl? in
                        let reader = BufferReader(buffer)
                        var result: Api.phone.GroupCallStreamRtmpUrl?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.phone.GroupCallStreamRtmpUrl
                        }
                        return result
                    })
                }
}
public extension Api.functions.phone {
                static func getGroupParticipants(call: Api.InputGroupCall, ids: [Api.InputPeer], sources: [Int32], offset: String, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.phone.GroupParticipants>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-984033109)
                    call.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(ids.count))
                    for item in ids {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(sources.count))
                    for item in sources {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    serializeString(offset, buffer: buffer, boxed: false)
                    serializeInt32(limit, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "phone.getGroupParticipants", parameters: [("call", String(describing: call)), ("ids", String(describing: ids)), ("sources", String(describing: sources)), ("offset", String(describing: offset)), ("limit", String(describing: limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.phone.GroupParticipants? in
                        let reader = BufferReader(buffer)
                        var result: Api.phone.GroupParticipants?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.phone.GroupParticipants
                        }
                        return result
                    })
                }
}
public extension Api.functions.phone {
                static func inviteToGroupCall(call: Api.InputGroupCall, users: [Api.InputUser]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(2067345760)
                    call.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    return (FunctionDescription(name: "phone.inviteToGroupCall", parameters: [("call", String(describing: call)), ("users", String(describing: users))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
}
public extension Api.functions.phone {
                static func joinGroupCall(flags: Int32, call: Api.InputGroupCall, joinAs: Api.InputPeer, inviteHash: String?, params: Api.DataJSON) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1322057861)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    call.serialize(buffer, true)
                    joinAs.serialize(buffer, true)
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(inviteHash!, buffer: buffer, boxed: false)}
                    params.serialize(buffer, true)
                    return (FunctionDescription(name: "phone.joinGroupCall", parameters: [("flags", String(describing: flags)), ("call", String(describing: call)), ("joinAs", String(describing: joinAs)), ("inviteHash", String(describing: inviteHash)), ("params", String(describing: params))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
}
public extension Api.functions.phone {
                static func joinGroupCallPresentation(call: Api.InputGroupCall, params: Api.DataJSON) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-873829436)
                    call.serialize(buffer, true)
                    params.serialize(buffer, true)
                    return (FunctionDescription(name: "phone.joinGroupCallPresentation", parameters: [("call", String(describing: call)), ("params", String(describing: params))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
}
public extension Api.functions.phone {
                static func leaveGroupCall(call: Api.InputGroupCall, source: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1342404601)
                    call.serialize(buffer, true)
                    serializeInt32(source, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "phone.leaveGroupCall", parameters: [("call", String(describing: call)), ("source", String(describing: source))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
}
public extension Api.functions.phone {
                static func leaveGroupCallPresentation(call: Api.InputGroupCall) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(475058500)
                    call.serialize(buffer, true)
                    return (FunctionDescription(name: "phone.leaveGroupCallPresentation", parameters: [("call", String(describing: call))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
}
public extension Api.functions.phone {
                static func receivedCall(peer: Api.InputPhoneCall) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(399855457)
                    peer.serialize(buffer, true)
                    return (FunctionDescription(name: "phone.receivedCall", parameters: [("peer", String(describing: peer))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.phone {
                static func requestCall(flags: Int32, userId: Api.InputUser, randomId: Int32, gAHash: Buffer, `protocol`: Api.PhoneCallProtocol) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.phone.PhoneCall>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1124046573)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    userId.serialize(buffer, true)
                    serializeInt32(randomId, buffer: buffer, boxed: false)
                    serializeBytes(gAHash, buffer: buffer, boxed: false)
                    `protocol`.serialize(buffer, true)
                    return (FunctionDescription(name: "phone.requestCall", parameters: [("flags", String(describing: flags)), ("userId", String(describing: userId)), ("randomId", String(describing: randomId)), ("gAHash", String(describing: gAHash)), ("`protocol`", String(describing: `protocol`))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.phone.PhoneCall? in
                        let reader = BufferReader(buffer)
                        var result: Api.phone.PhoneCall?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.phone.PhoneCall
                        }
                        return result
                    })
                }
}
public extension Api.functions.phone {
                static func saveCallDebug(peer: Api.InputPhoneCall, debug: Api.DataJSON) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(662363518)
                    peer.serialize(buffer, true)
                    debug.serialize(buffer, true)
                    return (FunctionDescription(name: "phone.saveCallDebug", parameters: [("peer", String(describing: peer)), ("debug", String(describing: debug))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.phone {
                static func saveCallLog(peer: Api.InputPhoneCall, file: Api.InputFile) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1092913030)
                    peer.serialize(buffer, true)
                    file.serialize(buffer, true)
                    return (FunctionDescription(name: "phone.saveCallLog", parameters: [("peer", String(describing: peer)), ("file", String(describing: file))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.phone {
                static func saveDefaultGroupCallJoinAs(peer: Api.InputPeer, joinAs: Api.InputPeer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1465786252)
                    peer.serialize(buffer, true)
                    joinAs.serialize(buffer, true)
                    return (FunctionDescription(name: "phone.saveDefaultGroupCallJoinAs", parameters: [("peer", String(describing: peer)), ("joinAs", String(describing: joinAs))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.phone {
                static func sendSignalingData(peer: Api.InputPhoneCall, data: Buffer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-8744061)
                    peer.serialize(buffer, true)
                    serializeBytes(data, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "phone.sendSignalingData", parameters: [("peer", String(describing: peer)), ("data", String(describing: data))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.phone {
                static func setCallRating(flags: Int32, peer: Api.InputPhoneCall, rating: Int32, comment: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1508562471)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    serializeInt32(rating, buffer: buffer, boxed: false)
                    serializeString(comment, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "phone.setCallRating", parameters: [("flags", String(describing: flags)), ("peer", String(describing: peer)), ("rating", String(describing: rating)), ("comment", String(describing: comment))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
}
public extension Api.functions.phone {
                static func startScheduledGroupCall(call: Api.InputGroupCall) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1451287362)
                    call.serialize(buffer, true)
                    return (FunctionDescription(name: "phone.startScheduledGroupCall", parameters: [("call", String(describing: call))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
}
public extension Api.functions.phone {
                static func toggleGroupCallRecord(flags: Int32, call: Api.InputGroupCall, title: String?, videoPortrait: Api.Bool?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-248985848)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    call.serialize(buffer, true)
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(title!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {videoPortrait!.serialize(buffer, true)}
                    return (FunctionDescription(name: "phone.toggleGroupCallRecord", parameters: [("flags", String(describing: flags)), ("call", String(describing: call)), ("title", String(describing: title)), ("videoPortrait", String(describing: videoPortrait))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
}
public extension Api.functions.phone {
                static func toggleGroupCallSettings(flags: Int32, call: Api.InputGroupCall, joinMuted: Api.Bool?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1958458429)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    call.serialize(buffer, true)
                    if Int(flags) & Int(1 << 0) != 0 {joinMuted!.serialize(buffer, true)}
                    return (FunctionDescription(name: "phone.toggleGroupCallSettings", parameters: [("flags", String(describing: flags)), ("call", String(describing: call)), ("joinMuted", String(describing: joinMuted))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
}
public extension Api.functions.phone {
                static func toggleGroupCallStartSubscription(call: Api.InputGroupCall, subscribed: Api.Bool) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(563885286)
                    call.serialize(buffer, true)
                    subscribed.serialize(buffer, true)
                    return (FunctionDescription(name: "phone.toggleGroupCallStartSubscription", parameters: [("call", String(describing: call)), ("subscribed", String(describing: subscribed))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
}
public extension Api.functions.photos {
                static func deletePhotos(id: [Api.InputPhoto]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Int64]>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-2016444625)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(id.count))
                    for item in id {
                        item.serialize(buffer, true)
                    }
                    return (FunctionDescription(name: "photos.deletePhotos", parameters: [("id", String(describing: id))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> [Int64]? in
                        let reader = BufferReader(buffer)
                        var result: [Int64]?
                        if let _ = reader.readInt32() {
                            result = Api.parseVector(reader, elementSignature: 570911930, elementType: Int64.self)
                        }
                        return result
                    })
                }
}
public extension Api.functions.photos {
                static func getUserPhotos(userId: Api.InputUser, offset: Int32, maxId: Int64, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.photos.Photos>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1848823128)
                    userId.serialize(buffer, true)
                    serializeInt32(offset, buffer: buffer, boxed: false)
                    serializeInt64(maxId, buffer: buffer, boxed: false)
                    serializeInt32(limit, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "photos.getUserPhotos", parameters: [("userId", String(describing: userId)), ("offset", String(describing: offset)), ("maxId", String(describing: maxId)), ("limit", String(describing: limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.photos.Photos? in
                        let reader = BufferReader(buffer)
                        var result: Api.photos.Photos?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.photos.Photos
                        }
                        return result
                    })
                }
}
public extension Api.functions.photos {
                static func updateProfilePhoto(id: Api.InputPhoto) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.photos.Photo>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1926525996)
                    id.serialize(buffer, true)
                    return (FunctionDescription(name: "photos.updateProfilePhoto", parameters: [("id", String(describing: id))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.photos.Photo? in
                        let reader = BufferReader(buffer)
                        var result: Api.photos.Photo?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.photos.Photo
                        }
                        return result
                    })
                }
}
public extension Api.functions.photos {
                static func uploadProfilePhoto(flags: Int32, file: Api.InputFile?, video: Api.InputFile?, videoStartTs: Double?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.photos.Photo>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1980559511)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {file!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 1) != 0 {video!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeDouble(videoStartTs!, buffer: buffer, boxed: false)}
                    return (FunctionDescription(name: "photos.uploadProfilePhoto", parameters: [("flags", String(describing: flags)), ("file", String(describing: file)), ("video", String(describing: video)), ("videoStartTs", String(describing: videoStartTs))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.photos.Photo? in
                        let reader = BufferReader(buffer)
                        var result: Api.photos.Photo?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.photos.Photo
                        }
                        return result
                    })
                }
}
public extension Api.functions.stats {
                static func getBroadcastStats(flags: Int32, channel: Api.InputChannel) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.stats.BroadcastStats>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1421720550)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    channel.serialize(buffer, true)
                    return (FunctionDescription(name: "stats.getBroadcastStats", parameters: [("flags", String(describing: flags)), ("channel", String(describing: channel))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.stats.BroadcastStats? in
                        let reader = BufferReader(buffer)
                        var result: Api.stats.BroadcastStats?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.stats.BroadcastStats
                        }
                        return result
                    })
                }
}
public extension Api.functions.stats {
                static func getMegagroupStats(flags: Int32, channel: Api.InputChannel) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.stats.MegagroupStats>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-589330937)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    channel.serialize(buffer, true)
                    return (FunctionDescription(name: "stats.getMegagroupStats", parameters: [("flags", String(describing: flags)), ("channel", String(describing: channel))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.stats.MegagroupStats? in
                        let reader = BufferReader(buffer)
                        var result: Api.stats.MegagroupStats?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.stats.MegagroupStats
                        }
                        return result
                    })
                }
}
public extension Api.functions.stats {
                static func getMessagePublicForwards(channel: Api.InputChannel, msgId: Int32, offsetRate: Int32, offsetPeer: Api.InputPeer, offsetId: Int32, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.Messages>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1445996571)
                    channel.serialize(buffer, true)
                    serializeInt32(msgId, buffer: buffer, boxed: false)
                    serializeInt32(offsetRate, buffer: buffer, boxed: false)
                    offsetPeer.serialize(buffer, true)
                    serializeInt32(offsetId, buffer: buffer, boxed: false)
                    serializeInt32(limit, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "stats.getMessagePublicForwards", parameters: [("channel", String(describing: channel)), ("msgId", String(describing: msgId)), ("offsetRate", String(describing: offsetRate)), ("offsetPeer", String(describing: offsetPeer)), ("offsetId", String(describing: offsetId)), ("limit", String(describing: limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.Messages? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.Messages?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.Messages
                        }
                        return result
                    })
                }
}
public extension Api.functions.stats {
                static func getMessageStats(flags: Int32, channel: Api.InputChannel, msgId: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.stats.MessageStats>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1226791947)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    channel.serialize(buffer, true)
                    serializeInt32(msgId, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "stats.getMessageStats", parameters: [("flags", String(describing: flags)), ("channel", String(describing: channel)), ("msgId", String(describing: msgId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.stats.MessageStats? in
                        let reader = BufferReader(buffer)
                        var result: Api.stats.MessageStats?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.stats.MessageStats
                        }
                        return result
                    })
                }
}
public extension Api.functions.stats {
                static func loadAsyncGraph(flags: Int32, token: String, x: Int64?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.StatsGraph>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1646092192)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(token, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt64(x!, buffer: buffer, boxed: false)}
                    return (FunctionDescription(name: "stats.loadAsyncGraph", parameters: [("flags", String(describing: flags)), ("token", String(describing: token)), ("x", String(describing: x))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.StatsGraph? in
                        let reader = BufferReader(buffer)
                        var result: Api.StatsGraph?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.StatsGraph
                        }
                        return result
                    })
                }
}
public extension Api.functions.stickers {
                static func addStickerToSet(stickerset: Api.InputStickerSet, sticker: Api.InputStickerSetItem) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.StickerSet>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-2041315650)
                    stickerset.serialize(buffer, true)
                    sticker.serialize(buffer, true)
                    return (FunctionDescription(name: "stickers.addStickerToSet", parameters: [("stickerset", String(describing: stickerset)), ("sticker", String(describing: sticker))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.StickerSet? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.StickerSet?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.StickerSet
                        }
                        return result
                    })
                }
}
public extension Api.functions.stickers {
                static func changeStickerPosition(sticker: Api.InputDocument, position: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.StickerSet>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-4795190)
                    sticker.serialize(buffer, true)
                    serializeInt32(position, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "stickers.changeStickerPosition", parameters: [("sticker", String(describing: sticker)), ("position", String(describing: position))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.StickerSet? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.StickerSet?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.StickerSet
                        }
                        return result
                    })
                }
}
public extension Api.functions.stickers {
                static func checkShortName(shortName: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(676017721)
                    serializeString(shortName, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "stickers.checkShortName", parameters: [("shortName", String(describing: shortName))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.stickers {
                static func createStickerSet(flags: Int32, userId: Api.InputUser, title: String, shortName: String, thumb: Api.InputDocument?, stickers: [Api.InputStickerSetItem], software: String?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.StickerSet>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1876841625)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    userId.serialize(buffer, true)
                    serializeString(title, buffer: buffer, boxed: false)
                    serializeString(shortName, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 2) != 0 {thumb!.serialize(buffer, true)}
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(stickers.count))
                    for item in stickers {
                        item.serialize(buffer, true)
                    }
                    if Int(flags) & Int(1 << 3) != 0 {serializeString(software!, buffer: buffer, boxed: false)}
                    return (FunctionDescription(name: "stickers.createStickerSet", parameters: [("flags", String(describing: flags)), ("userId", String(describing: userId)), ("title", String(describing: title)), ("shortName", String(describing: shortName)), ("thumb", String(describing: thumb)), ("stickers", String(describing: stickers)), ("software", String(describing: software))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.StickerSet? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.StickerSet?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.StickerSet
                        }
                        return result
                    })
                }
}
public extension Api.functions.stickers {
                static func removeStickerFromSet(sticker: Api.InputDocument) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.StickerSet>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-143257775)
                    sticker.serialize(buffer, true)
                    return (FunctionDescription(name: "stickers.removeStickerFromSet", parameters: [("sticker", String(describing: sticker))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.StickerSet? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.StickerSet?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.StickerSet
                        }
                        return result
                    })
                }
}
public extension Api.functions.stickers {
                static func setStickerSetThumb(stickerset: Api.InputStickerSet, thumb: Api.InputDocument) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.StickerSet>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1707717072)
                    stickerset.serialize(buffer, true)
                    thumb.serialize(buffer, true)
                    return (FunctionDescription(name: "stickers.setStickerSetThumb", parameters: [("stickerset", String(describing: stickerset)), ("thumb", String(describing: thumb))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.StickerSet? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.StickerSet?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.StickerSet
                        }
                        return result
                    })
                }
}
public extension Api.functions.stickers {
                static func suggestShortName(title: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.stickers.SuggestedShortName>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1303364867)
                    serializeString(title, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "stickers.suggestShortName", parameters: [("title", String(describing: title))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.stickers.SuggestedShortName? in
                        let reader = BufferReader(buffer)
                        var result: Api.stickers.SuggestedShortName?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.stickers.SuggestedShortName
                        }
                        return result
                    })
                }
}
public extension Api.functions.updates {
                static func getChannelDifference(flags: Int32, channel: Api.InputChannel, filter: Api.ChannelMessagesFilter, pts: Int32, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.updates.ChannelDifference>) {
                    let buffer = Buffer()
                    buffer.appendInt32(51854712)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    channel.serialize(buffer, true)
                    filter.serialize(buffer, true)
                    serializeInt32(pts, buffer: buffer, boxed: false)
                    serializeInt32(limit, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "updates.getChannelDifference", parameters: [("flags", String(describing: flags)), ("channel", String(describing: channel)), ("filter", String(describing: filter)), ("pts", String(describing: pts)), ("limit", String(describing: limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.updates.ChannelDifference? in
                        let reader = BufferReader(buffer)
                        var result: Api.updates.ChannelDifference?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.updates.ChannelDifference
                        }
                        return result
                    })
                }
}
public extension Api.functions.updates {
                static func getDifference(flags: Int32, pts: Int32, ptsTotalLimit: Int32?, date: Int32, qts: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.updates.Difference>) {
                    let buffer = Buffer()
                    buffer.appendInt32(630429265)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(pts, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(ptsTotalLimit!, buffer: buffer, boxed: false)}
                    serializeInt32(date, buffer: buffer, boxed: false)
                    serializeInt32(qts, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "updates.getDifference", parameters: [("flags", String(describing: flags)), ("pts", String(describing: pts)), ("ptsTotalLimit", String(describing: ptsTotalLimit)), ("date", String(describing: date)), ("qts", String(describing: qts))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.updates.Difference? in
                        let reader = BufferReader(buffer)
                        var result: Api.updates.Difference?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.updates.Difference
                        }
                        return result
                    })
                }
}
public extension Api.functions.updates {
                static func getState() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.updates.State>) {
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
}
public extension Api.functions.upload {
                static func getCdnFile(fileToken: Buffer, offset: Int64, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.upload.CdnFile>) {
                    let buffer = Buffer()
                    buffer.appendInt32(962554330)
                    serializeBytes(fileToken, buffer: buffer, boxed: false)
                    serializeInt64(offset, buffer: buffer, boxed: false)
                    serializeInt32(limit, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "upload.getCdnFile", parameters: [("fileToken", String(describing: fileToken)), ("offset", String(describing: offset)), ("limit", String(describing: limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.upload.CdnFile? in
                        let reader = BufferReader(buffer)
                        var result: Api.upload.CdnFile?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.upload.CdnFile
                        }
                        return result
                    })
                }
}
public extension Api.functions.upload {
                static func getCdnFileHashes(fileToken: Buffer, offset: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Api.FileHash]>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1847836879)
                    serializeBytes(fileToken, buffer: buffer, boxed: false)
                    serializeInt64(offset, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "upload.getCdnFileHashes", parameters: [("fileToken", String(describing: fileToken)), ("offset", String(describing: offset))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> [Api.FileHash]? in
                        let reader = BufferReader(buffer)
                        var result: [Api.FileHash]?
                        if let _ = reader.readInt32() {
                            result = Api.parseVector(reader, elementSignature: 0, elementType: Api.FileHash.self)
                        }
                        return result
                    })
                }
}
public extension Api.functions.upload {
                static func getFile(flags: Int32, location: Api.InputFileLocation, offset: Int64, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.upload.File>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1101843010)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    location.serialize(buffer, true)
                    serializeInt64(offset, buffer: buffer, boxed: false)
                    serializeInt32(limit, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "upload.getFile", parameters: [("flags", String(describing: flags)), ("location", String(describing: location)), ("offset", String(describing: offset)), ("limit", String(describing: limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.upload.File? in
                        let reader = BufferReader(buffer)
                        var result: Api.upload.File?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.upload.File
                        }
                        return result
                    })
                }
}
public extension Api.functions.upload {
                static func getFileHashes(location: Api.InputFileLocation, offset: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Api.FileHash]>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1856595926)
                    location.serialize(buffer, true)
                    serializeInt64(offset, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "upload.getFileHashes", parameters: [("location", String(describing: location)), ("offset", String(describing: offset))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> [Api.FileHash]? in
                        let reader = BufferReader(buffer)
                        var result: [Api.FileHash]?
                        if let _ = reader.readInt32() {
                            result = Api.parseVector(reader, elementSignature: 0, elementType: Api.FileHash.self)
                        }
                        return result
                    })
                }
}
public extension Api.functions.upload {
                static func getWebFile(location: Api.InputWebFileLocation, offset: Int32, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.upload.WebFile>) {
                    let buffer = Buffer()
                    buffer.appendInt32(619086221)
                    location.serialize(buffer, true)
                    serializeInt32(offset, buffer: buffer, boxed: false)
                    serializeInt32(limit, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "upload.getWebFile", parameters: [("location", String(describing: location)), ("offset", String(describing: offset)), ("limit", String(describing: limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.upload.WebFile? in
                        let reader = BufferReader(buffer)
                        var result: Api.upload.WebFile?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.upload.WebFile
                        }
                        return result
                    })
                }
}
public extension Api.functions.upload {
                static func reuploadCdnFile(fileToken: Buffer, requestToken: Buffer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Api.FileHash]>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1691921240)
                    serializeBytes(fileToken, buffer: buffer, boxed: false)
                    serializeBytes(requestToken, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "upload.reuploadCdnFile", parameters: [("fileToken", String(describing: fileToken)), ("requestToken", String(describing: requestToken))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> [Api.FileHash]? in
                        let reader = BufferReader(buffer)
                        var result: [Api.FileHash]?
                        if let _ = reader.readInt32() {
                            result = Api.parseVector(reader, elementSignature: 0, elementType: Api.FileHash.self)
                        }
                        return result
                    })
                }
}
public extension Api.functions.upload {
                static func saveBigFilePart(fileId: Int64, filePart: Int32, fileTotalParts: Int32, bytes: Buffer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-562337987)
                    serializeInt64(fileId, buffer: buffer, boxed: false)
                    serializeInt32(filePart, buffer: buffer, boxed: false)
                    serializeInt32(fileTotalParts, buffer: buffer, boxed: false)
                    serializeBytes(bytes, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "upload.saveBigFilePart", parameters: [("fileId", String(describing: fileId)), ("filePart", String(describing: filePart)), ("fileTotalParts", String(describing: fileTotalParts)), ("bytes", String(describing: bytes))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.upload {
                static func saveFilePart(fileId: Int64, filePart: Int32, bytes: Buffer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1291540959)
                    serializeInt64(fileId, buffer: buffer, boxed: false)
                    serializeInt32(filePart, buffer: buffer, boxed: false)
                    serializeBytes(bytes, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "upload.saveFilePart", parameters: [("fileId", String(describing: fileId)), ("filePart", String(describing: filePart)), ("bytes", String(describing: bytes))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.users {
                static func getFullUser(id: Api.InputUser) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.users.UserFull>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1240508136)
                    id.serialize(buffer, true)
                    return (FunctionDescription(name: "users.getFullUser", parameters: [("id", String(describing: id))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.users.UserFull? in
                        let reader = BufferReader(buffer)
                        var result: Api.users.UserFull?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.users.UserFull
                        }
                        return result
                    })
                }
}
public extension Api.functions.users {
                static func getUsers(id: [Api.InputUser]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Api.User]>) {
                    let buffer = Buffer()
                    buffer.appendInt32(227648840)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(id.count))
                    for item in id {
                        item.serialize(buffer, true)
                    }
                    return (FunctionDescription(name: "users.getUsers", parameters: [("id", String(describing: id))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> [Api.User]? in
                        let reader = BufferReader(buffer)
                        var result: [Api.User]?
                        if let _ = reader.readInt32() {
                            result = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
                        }
                        return result
                    })
                }
}
public extension Api.functions.users {
                static func setSecureValueErrors(id: Api.InputUser, errors: [Api.SecureValueError]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1865902923)
                    id.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(errors.count))
                    for item in errors {
                        item.serialize(buffer, true)
                    }
                    return (FunctionDescription(name: "users.setSecureValueErrors", parameters: [("id", String(describing: id)), ("errors", String(describing: errors))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
