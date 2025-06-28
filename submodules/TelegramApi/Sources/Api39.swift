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
                static func createBusinessChatLink(link: Api.InputBusinessChatLink) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.BusinessChatLink>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-2007898482)
                    link.serialize(buffer, true)
                    return (FunctionDescription(name: "account.createBusinessChatLink", parameters: [("link", String(describing: link))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.BusinessChatLink? in
                        let reader = BufferReader(buffer)
                        var result: Api.BusinessChatLink?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.BusinessChatLink
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
                static func deleteAutoSaveExceptions() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1404829728)
                    
                    return (FunctionDescription(name: "account.deleteAutoSaveExceptions", parameters: []), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
                static func deleteBusinessChatLink(slug: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1611085428)
                    serializeString(slug, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "account.deleteBusinessChatLink", parameters: [("slug", String(describing: slug))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
                static func disablePeerConnectedBot(peer: Api.InputPeer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1581481689)
                    peer.serialize(buffer, true)
                    return (FunctionDescription(name: "account.disablePeerConnectedBot", parameters: [("peer", String(describing: peer))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
                static func editBusinessChatLink(slug: String, link: Api.InputBusinessChatLink) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.BusinessChatLink>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1942744913)
                    serializeString(slug, buffer: buffer, boxed: false)
                    link.serialize(buffer, true)
                    return (FunctionDescription(name: "account.editBusinessChatLink", parameters: [("slug", String(describing: slug)), ("link", String(describing: link))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.BusinessChatLink? in
                        let reader = BufferReader(buffer)
                        var result: Api.BusinessChatLink?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.BusinessChatLink
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
                static func getAutoSaveSettings() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.account.AutoSaveSettings>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1379156774)
                    
                    return (FunctionDescription(name: "account.getAutoSaveSettings", parameters: []), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.account.AutoSaveSettings? in
                        let reader = BufferReader(buffer)
                        var result: Api.account.AutoSaveSettings?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.account.AutoSaveSettings
                        }
                        return result
                    })
                }
}
public extension Api.functions.account {
                static func getBotBusinessConnection(connectionId: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1990746736)
                    serializeString(connectionId, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "account.getBotBusinessConnection", parameters: [("connectionId", String(describing: connectionId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
                static func getBusinessChatLinks() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.account.BusinessChatLinks>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1869667809)
                    
                    return (FunctionDescription(name: "account.getBusinessChatLinks", parameters: []), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.account.BusinessChatLinks? in
                        let reader = BufferReader(buffer)
                        var result: Api.account.BusinessChatLinks?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.account.BusinessChatLinks
                        }
                        return result
                    })
                }
}
public extension Api.functions.account {
                static func getChannelDefaultEmojiStatuses(hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.account.EmojiStatuses>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1999087573)
                    serializeInt64(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "account.getChannelDefaultEmojiStatuses", parameters: [("hash", String(describing: hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.account.EmojiStatuses? in
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
                static func getChannelRestrictedStatusEmojis(hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.EmojiList>) {
                    let buffer = Buffer()
                    buffer.appendInt32(900325589)
                    serializeInt64(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "account.getChannelRestrictedStatusEmojis", parameters: [("hash", String(describing: hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.EmojiList? in
                        let reader = BufferReader(buffer)
                        var result: Api.EmojiList?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.EmojiList
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
                static func getCollectibleEmojiStatuses(hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.account.EmojiStatuses>) {
                    let buffer = Buffer()
                    buffer.appendInt32(779830595)
                    serializeInt64(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "account.getCollectibleEmojiStatuses", parameters: [("hash", String(describing: hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.account.EmojiStatuses? in
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
                static func getConnectedBots() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.account.ConnectedBots>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1319421967)
                    
                    return (FunctionDescription(name: "account.getConnectedBots", parameters: []), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.account.ConnectedBots? in
                        let reader = BufferReader(buffer)
                        var result: Api.account.ConnectedBots?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.account.ConnectedBots
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
                static func getDefaultBackgroundEmojis(hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.EmojiList>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1509246514)
                    serializeInt64(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "account.getDefaultBackgroundEmojis", parameters: [("hash", String(describing: hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.EmojiList? in
                        let reader = BufferReader(buffer)
                        var result: Api.EmojiList?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.EmojiList
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
                static func getDefaultGroupPhotoEmojis(hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.EmojiList>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1856479058)
                    serializeInt64(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "account.getDefaultGroupPhotoEmojis", parameters: [("hash", String(describing: hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.EmojiList? in
                        let reader = BufferReader(buffer)
                        var result: Api.EmojiList?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.EmojiList
                        }
                        return result
                    })
                }
}
public extension Api.functions.account {
                static func getDefaultProfilePhotoEmojis(hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.EmojiList>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-495647960)
                    serializeInt64(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "account.getDefaultProfilePhotoEmojis", parameters: [("hash", String(describing: hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.EmojiList? in
                        let reader = BufferReader(buffer)
                        var result: Api.EmojiList?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.EmojiList
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
                static func getPaidMessagesRevenue(flags: Int32, parentPeer: Api.InputPeer?, userId: Api.InputUser) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.account.PaidMessagesRevenue>) {
                    let buffer = Buffer()
                    buffer.appendInt32(431639143)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {parentPeer!.serialize(buffer, true)}
                    userId.serialize(buffer, true)
                    return (FunctionDescription(name: "account.getPaidMessagesRevenue", parameters: [("flags", String(describing: flags)), ("parentPeer", String(describing: parentPeer)), ("userId", String(describing: userId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.account.PaidMessagesRevenue? in
                        let reader = BufferReader(buffer)
                        var result: Api.account.PaidMessagesRevenue?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.account.PaidMessagesRevenue
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
                static func getReactionsNotifySettings() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.ReactionsNotifySettings>) {
                    let buffer = Buffer()
                    buffer.appendInt32(115172684)
                    
                    return (FunctionDescription(name: "account.getReactionsNotifySettings", parameters: []), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.ReactionsNotifySettings? in
                        let reader = BufferReader(buffer)
                        var result: Api.ReactionsNotifySettings?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.ReactionsNotifySettings
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
                static func invalidateSignInCodes(codes: [String]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-896866118)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(codes.count))
                    for item in codes {
                        serializeString(item, buffer: buffer, boxed: false)
                    }
                    return (FunctionDescription(name: "account.invalidateSignInCodes", parameters: [("codes", String(describing: codes))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
                static func resolveBusinessChatLink(slug: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.account.ResolvedBusinessChatLinks>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1418913262)
                    serializeString(slug, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "account.resolveBusinessChatLink", parameters: [("slug", String(describing: slug))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.account.ResolvedBusinessChatLinks? in
                        let reader = BufferReader(buffer)
                        var result: Api.account.ResolvedBusinessChatLinks?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.account.ResolvedBusinessChatLinks
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
                static func saveAutoSaveSettings(flags: Int32, peer: Api.InputPeer?, settings: Api.AutoSaveSettings) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-694451359)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 3) != 0 {peer!.serialize(buffer, true)}
                    settings.serialize(buffer, true)
                    return (FunctionDescription(name: "account.saveAutoSaveSettings", parameters: [("flags", String(describing: flags)), ("peer", String(describing: peer)), ("settings", String(describing: settings))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
                static func setReactionsNotifySettings(settings: Api.ReactionsNotifySettings) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.ReactionsNotifySettings>) {
                    let buffer = Buffer()
                    buffer.appendInt32(829220168)
                    settings.serialize(buffer, true)
                    return (FunctionDescription(name: "account.setReactionsNotifySettings", parameters: [("settings", String(describing: settings))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.ReactionsNotifySettings? in
                        let reader = BufferReader(buffer)
                        var result: Api.ReactionsNotifySettings?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.ReactionsNotifySettings
                        }
                        return result
                    })
                }
}
public extension Api.functions.account {
                static func toggleConnectedBotPaused(peer: Api.InputPeer, paused: Api.Bool) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1684934807)
                    peer.serialize(buffer, true)
                    paused.serialize(buffer, true)
                    return (FunctionDescription(name: "account.toggleConnectedBotPaused", parameters: [("peer", String(describing: peer)), ("paused", String(describing: paused))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
                static func toggleNoPaidMessagesException(flags: Int32, parentPeer: Api.InputPeer?, userId: Api.InputUser) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-30483850)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {parentPeer!.serialize(buffer, true)}
                    userId.serialize(buffer, true)
                    return (FunctionDescription(name: "account.toggleNoPaidMessagesException", parameters: [("flags", String(describing: flags)), ("parentPeer", String(describing: parentPeer)), ("userId", String(describing: userId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
                static func toggleSponsoredMessages(enabled: Api.Bool) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1176919155)
                    enabled.serialize(buffer, true)
                    return (FunctionDescription(name: "account.toggleSponsoredMessages", parameters: [("enabled", String(describing: enabled))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
                static func updateBirthday(flags: Int32, birthday: Api.Birthday?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-865203183)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {birthday!.serialize(buffer, true)}
                    return (FunctionDescription(name: "account.updateBirthday", parameters: [("flags", String(describing: flags)), ("birthday", String(describing: birthday))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
                static func updateBusinessAwayMessage(flags: Int32, message: Api.InputBusinessAwayMessage?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1570078811)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {message!.serialize(buffer, true)}
                    return (FunctionDescription(name: "account.updateBusinessAwayMessage", parameters: [("flags", String(describing: flags)), ("message", String(describing: message))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
                static func updateBusinessGreetingMessage(flags: Int32, message: Api.InputBusinessGreetingMessage?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1724755908)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {message!.serialize(buffer, true)}
                    return (FunctionDescription(name: "account.updateBusinessGreetingMessage", parameters: [("flags", String(describing: flags)), ("message", String(describing: message))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
                static func updateBusinessIntro(flags: Int32, intro: Api.InputBusinessIntro?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1508585420)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {intro!.serialize(buffer, true)}
                    return (FunctionDescription(name: "account.updateBusinessIntro", parameters: [("flags", String(describing: flags)), ("intro", String(describing: intro))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
                static func updateBusinessLocation(flags: Int32, geoPoint: Api.InputGeoPoint?, address: String?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1637149926)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {geoPoint!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(address!, buffer: buffer, boxed: false)}
                    return (FunctionDescription(name: "account.updateBusinessLocation", parameters: [("flags", String(describing: flags)), ("geoPoint", String(describing: geoPoint)), ("address", String(describing: address))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
                static func updateBusinessWorkHours(flags: Int32, businessWorkHours: Api.BusinessWorkHours?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1258348646)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {businessWorkHours!.serialize(buffer, true)}
                    return (FunctionDescription(name: "account.updateBusinessWorkHours", parameters: [("flags", String(describing: flags)), ("businessWorkHours", String(describing: businessWorkHours))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
                static func updateColor(flags: Int32, color: Int32?, backgroundEmojiId: Int64?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(2096079197)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 2) != 0 {serializeInt32(color!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt64(backgroundEmojiId!, buffer: buffer, boxed: false)}
                    return (FunctionDescription(name: "account.updateColor", parameters: [("flags", String(describing: flags)), ("color", String(describing: color)), ("backgroundEmojiId", String(describing: backgroundEmojiId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
                static func updateConnectedBot(flags: Int32, rights: Api.BusinessBotRights?, bot: Api.InputUser, recipients: Api.InputBusinessBotRecipients) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1721797758)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {rights!.serialize(buffer, true)}
                    bot.serialize(buffer, true)
                    recipients.serialize(buffer, true)
                    return (FunctionDescription(name: "account.updateConnectedBot", parameters: [("flags", String(describing: flags)), ("rights", String(describing: rights)), ("bot", String(describing: bot)), ("recipients", String(describing: recipients))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
                static func updatePersonalChannel(channel: Api.InputChannel) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-649919008)
                    channel.serialize(buffer, true)
                    return (FunctionDescription(name: "account.updatePersonalChannel", parameters: [("channel", String(describing: channel))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
                static func uploadWallPaper(flags: Int32, file: Api.InputFile, mimeType: String, settings: Api.WallPaperSettings) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.WallPaper>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-476410109)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    file.serialize(buffer, true)
                    serializeString(mimeType, buffer: buffer, boxed: false)
                    settings.serialize(buffer, true)
                    return (FunctionDescription(name: "account.uploadWallPaper", parameters: [("flags", String(describing: flags)), ("file", String(describing: file)), ("mimeType", String(describing: mimeType)), ("settings", String(describing: settings))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.WallPaper? in
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
                static func importWebTokenAuthorization(apiId: Int32, apiHash: String, webAuthToken: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.auth.Authorization>) {
                    let buffer = Buffer()
                    buffer.appendInt32(767062953)
                    serializeInt32(apiId, buffer: buffer, boxed: false)
                    serializeString(apiHash, buffer: buffer, boxed: false)
                    serializeString(webAuthToken, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "auth.importWebTokenAuthorization", parameters: [("apiId", String(describing: apiId)), ("apiHash", String(describing: apiHash)), ("webAuthToken", String(describing: webAuthToken))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.auth.Authorization? in
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
                static func reportMissingCode(phoneNumber: String, phoneCodeHash: String, mnc: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-878841866)
                    serializeString(phoneNumber, buffer: buffer, boxed: false)
                    serializeString(phoneCodeHash, buffer: buffer, boxed: false)
                    serializeString(mnc, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "auth.reportMissingCode", parameters: [("phoneNumber", String(describing: phoneNumber)), ("phoneCodeHash", String(describing: phoneCodeHash)), ("mnc", String(describing: mnc))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
                static func requestFirebaseSms(flags: Int32, phoneNumber: String, phoneCodeHash: String, safetyNetToken: String?, playIntegrityToken: String?, iosPushSecret: String?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1908857314)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(phoneNumber, buffer: buffer, boxed: false)
                    serializeString(phoneCodeHash, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(safetyNetToken!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeString(playIntegrityToken!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(iosPushSecret!, buffer: buffer, boxed: false)}
                    return (FunctionDescription(name: "auth.requestFirebaseSms", parameters: [("flags", String(describing: flags)), ("phoneNumber", String(describing: phoneNumber)), ("phoneCodeHash", String(describing: phoneCodeHash)), ("safetyNetToken", String(describing: safetyNetToken)), ("playIntegrityToken", String(describing: playIntegrityToken)), ("iosPushSecret", String(describing: iosPushSecret))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
                static func resendCode(flags: Int32, phoneNumber: String, phoneCodeHash: String, reason: String?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.auth.SentCode>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-890997469)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(phoneNumber, buffer: buffer, boxed: false)
                    serializeString(phoneCodeHash, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(reason!, buffer: buffer, boxed: false)}
                    return (FunctionDescription(name: "auth.resendCode", parameters: [("flags", String(describing: flags)), ("phoneNumber", String(describing: phoneNumber)), ("phoneCodeHash", String(describing: phoneCodeHash)), ("reason", String(describing: reason))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.auth.SentCode? in
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
                static func resetLoginEmail(phoneNumber: String, phoneCodeHash: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.auth.SentCode>) {
                    let buffer = Buffer()
                    buffer.appendInt32(2123760019)
                    serializeString(phoneNumber, buffer: buffer, boxed: false)
                    serializeString(phoneCodeHash, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "auth.resetLoginEmail", parameters: [("phoneNumber", String(describing: phoneNumber)), ("phoneCodeHash", String(describing: phoneCodeHash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.auth.SentCode? in
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
                static func signUp(flags: Int32, phoneNumber: String, phoneCodeHash: String, firstName: String, lastName: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.auth.Authorization>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1429752041)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(phoneNumber, buffer: buffer, boxed: false)
                    serializeString(phoneCodeHash, buffer: buffer, boxed: false)
                    serializeString(firstName, buffer: buffer, boxed: false)
                    serializeString(lastName, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "auth.signUp", parameters: [("flags", String(describing: flags)), ("phoneNumber", String(describing: phoneNumber)), ("phoneCodeHash", String(describing: phoneCodeHash)), ("firstName", String(describing: firstName)), ("lastName", String(describing: lastName))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.auth.Authorization? in
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
                static func addPreviewMedia(bot: Api.InputUser, langCode: String, media: Api.InputMedia) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.BotPreviewMedia>) {
                    let buffer = Buffer()
                    buffer.appendInt32(397326170)
                    bot.serialize(buffer, true)
                    serializeString(langCode, buffer: buffer, boxed: false)
                    media.serialize(buffer, true)
                    return (FunctionDescription(name: "bots.addPreviewMedia", parameters: [("bot", String(describing: bot)), ("langCode", String(describing: langCode)), ("media", String(describing: media))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.BotPreviewMedia? in
                        let reader = BufferReader(buffer)
                        var result: Api.BotPreviewMedia?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.BotPreviewMedia
                        }
                        return result
                    })
                }
}
public extension Api.functions.bots {
                static func allowSendMessage(bot: Api.InputUser) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-248323089)
                    bot.serialize(buffer, true)
                    return (FunctionDescription(name: "bots.allowSendMessage", parameters: [("bot", String(describing: bot))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
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
                static func canSendMessage(bot: Api.InputUser) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(324662502)
                    bot.serialize(buffer, true)
                    return (FunctionDescription(name: "bots.canSendMessage", parameters: [("bot", String(describing: bot))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
                static func checkDownloadFileParams(bot: Api.InputUser, fileName: String, url: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1342666121)
                    bot.serialize(buffer, true)
                    serializeString(fileName, buffer: buffer, boxed: false)
                    serializeString(url, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "bots.checkDownloadFileParams", parameters: [("bot", String(describing: bot)), ("fileName", String(describing: fileName)), ("url", String(describing: url))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
                static func deletePreviewMedia(bot: Api.InputUser, langCode: String, media: [Api.InputMedia]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(755054003)
                    bot.serialize(buffer, true)
                    serializeString(langCode, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(media.count))
                    for item in media {
                        item.serialize(buffer, true)
                    }
                    return (FunctionDescription(name: "bots.deletePreviewMedia", parameters: [("bot", String(describing: bot)), ("langCode", String(describing: langCode)), ("media", String(describing: media))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
                static func editPreviewMedia(bot: Api.InputUser, langCode: String, media: Api.InputMedia, newMedia: Api.InputMedia) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.BotPreviewMedia>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-2061148049)
                    bot.serialize(buffer, true)
                    serializeString(langCode, buffer: buffer, boxed: false)
                    media.serialize(buffer, true)
                    newMedia.serialize(buffer, true)
                    return (FunctionDescription(name: "bots.editPreviewMedia", parameters: [("bot", String(describing: bot)), ("langCode", String(describing: langCode)), ("media", String(describing: media)), ("newMedia", String(describing: newMedia))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.BotPreviewMedia? in
                        let reader = BufferReader(buffer)
                        var result: Api.BotPreviewMedia?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.BotPreviewMedia
                        }
                        return result
                    })
                }
}
public extension Api.functions.bots {
                static func getAdminedBots() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Api.User]>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1334764157)
                    
                    return (FunctionDescription(name: "bots.getAdminedBots", parameters: []), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> [Api.User]? in
                        let reader = BufferReader(buffer)
                        var result: [Api.User]?
                        if let _ = reader.readInt32() {
                            result = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
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
                static func getBotInfo(flags: Int32, bot: Api.InputUser?, langCode: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.bots.BotInfo>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-589753091)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {bot!.serialize(buffer, true)}
                    serializeString(langCode, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "bots.getBotInfo", parameters: [("flags", String(describing: flags)), ("bot", String(describing: bot)), ("langCode", String(describing: langCode))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.bots.BotInfo? in
                        let reader = BufferReader(buffer)
                        var result: Api.bots.BotInfo?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.bots.BotInfo
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
                static func getBotRecommendations(bot: Api.InputUser) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.users.Users>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1581840363)
                    bot.serialize(buffer, true)
                    return (FunctionDescription(name: "bots.getBotRecommendations", parameters: [("bot", String(describing: bot))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.users.Users? in
                        let reader = BufferReader(buffer)
                        var result: Api.users.Users?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.users.Users
                        }
                        return result
                    })
                }
}
public extension Api.functions.bots {
                static func getPopularAppBots(offset: String, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.bots.PopularAppBots>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1034878574)
                    serializeString(offset, buffer: buffer, boxed: false)
                    serializeInt32(limit, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "bots.getPopularAppBots", parameters: [("offset", String(describing: offset)), ("limit", String(describing: limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.bots.PopularAppBots? in
                        let reader = BufferReader(buffer)
                        var result: Api.bots.PopularAppBots?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.bots.PopularAppBots
                        }
                        return result
                    })
                }
}
public extension Api.functions.bots {
                static func getPreviewInfo(bot: Api.InputUser, langCode: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.bots.PreviewInfo>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1111143341)
                    bot.serialize(buffer, true)
                    serializeString(langCode, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "bots.getPreviewInfo", parameters: [("bot", String(describing: bot)), ("langCode", String(describing: langCode))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.bots.PreviewInfo? in
                        let reader = BufferReader(buffer)
                        var result: Api.bots.PreviewInfo?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.bots.PreviewInfo
                        }
                        return result
                    })
                }
}
public extension Api.functions.bots {
                static func getPreviewMedias(bot: Api.InputUser) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Api.BotPreviewMedia]>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1566222003)
                    bot.serialize(buffer, true)
                    return (FunctionDescription(name: "bots.getPreviewMedias", parameters: [("bot", String(describing: bot))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> [Api.BotPreviewMedia]? in
                        let reader = BufferReader(buffer)
                        var result: [Api.BotPreviewMedia]?
                        if let _ = reader.readInt32() {
                            result = Api.parseVector(reader, elementSignature: 0, elementType: Api.BotPreviewMedia.self)
                        }
                        return result
                    })
                }
}
public extension Api.functions.bots {
                static func invokeWebViewCustomMethod(bot: Api.InputUser, customMethod: String, params: Api.DataJSON) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.DataJSON>) {
                    let buffer = Buffer()
                    buffer.appendInt32(142591463)
                    bot.serialize(buffer, true)
                    serializeString(customMethod, buffer: buffer, boxed: false)
                    params.serialize(buffer, true)
                    return (FunctionDescription(name: "bots.invokeWebViewCustomMethod", parameters: [("bot", String(describing: bot)), ("customMethod", String(describing: customMethod)), ("params", String(describing: params))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.DataJSON? in
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
                static func reorderPreviewMedias(bot: Api.InputUser, langCode: String, order: [Api.InputMedia]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1238895702)
                    bot.serialize(buffer, true)
                    serializeString(langCode, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(order.count))
                    for item in order {
                        item.serialize(buffer, true)
                    }
                    return (FunctionDescription(name: "bots.reorderPreviewMedias", parameters: [("bot", String(describing: bot)), ("langCode", String(describing: langCode)), ("order", String(describing: order))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
                static func reorderUsernames(bot: Api.InputUser, order: [String]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1760972350)
                    bot.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(order.count))
                    for item in order {
                        serializeString(item, buffer: buffer, boxed: false)
                    }
                    return (FunctionDescription(name: "bots.reorderUsernames", parameters: [("bot", String(describing: bot)), ("order", String(describing: order))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
                static func setBotInfo(flags: Int32, bot: Api.InputUser?, langCode: String, name: String?, about: String?, description: String?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(282013987)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 2) != 0 {bot!.serialize(buffer, true)}
                    serializeString(langCode, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 3) != 0 {serializeString(name!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(about!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(description!, buffer: buffer, boxed: false)}
                    return (FunctionDescription(name: "bots.setBotInfo", parameters: [("flags", String(describing: flags)), ("bot", String(describing: bot)), ("langCode", String(describing: langCode)), ("name", String(describing: name)), ("about", String(describing: about)), ("description", String(describing: description))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
public extension Api.functions.bots {
                static func setCustomVerification(flags: Int32, bot: Api.InputUser?, peer: Api.InputPeer, customDescription: String?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1953898563)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {bot!.serialize(buffer, true)}
                    peer.serialize(buffer, true)
                    if Int(flags) & Int(1 << 2) != 0 {serializeString(customDescription!, buffer: buffer, boxed: false)}
                    return (FunctionDescription(name: "bots.setCustomVerification", parameters: [("flags", String(describing: flags)), ("bot", String(describing: bot)), ("peer", String(describing: peer)), ("customDescription", String(describing: customDescription))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
                static func toggleUserEmojiStatusPermission(bot: Api.InputUser, enabled: Api.Bool) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(115237778)
                    bot.serialize(buffer, true)
                    enabled.serialize(buffer, true)
                    return (FunctionDescription(name: "bots.toggleUserEmojiStatusPermission", parameters: [("bot", String(describing: bot)), ("enabled", String(describing: enabled))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
                static func toggleUsername(bot: Api.InputUser, username: String, active: Api.Bool) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(87861619)
                    bot.serialize(buffer, true)
                    serializeString(username, buffer: buffer, boxed: false)
                    active.serialize(buffer, true)
                    return (FunctionDescription(name: "bots.toggleUsername", parameters: [("bot", String(describing: bot)), ("username", String(describing: username)), ("active", String(describing: active))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
                static func updateStarRefProgram(flags: Int32, bot: Api.InputUser, commissionPermille: Int32, durationMonths: Int32?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.StarRefProgram>) {
                    let buffer = Buffer()
                    buffer.appendInt32(2005621427)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    bot.serialize(buffer, true)
                    serializeInt32(commissionPermille, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(durationMonths!, buffer: buffer, boxed: false)}
                    return (FunctionDescription(name: "bots.updateStarRefProgram", parameters: [("flags", String(describing: flags)), ("bot", String(describing: bot)), ("commissionPermille", String(describing: commissionPermille)), ("durationMonths", String(describing: durationMonths))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.StarRefProgram? in
                        let reader = BufferReader(buffer)
                        var result: Api.StarRefProgram?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.StarRefProgram
                        }
                        return result
                    })
                }
}
public extension Api.functions.bots {
                static func updateUserEmojiStatus(userId: Api.InputUser, emojiStatus: Api.EmojiStatus) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-308334395)
                    userId.serialize(buffer, true)
                    emojiStatus.serialize(buffer, true)
                    return (FunctionDescription(name: "bots.updateUserEmojiStatus", parameters: [("userId", String(describing: userId)), ("emojiStatus", String(describing: emojiStatus))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
                static func createChannel(flags: Int32, title: String, about: String, geoPoint: Api.InputGeoPoint?, address: String?, ttlPeriod: Int32?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1862244601)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(title, buffer: buffer, boxed: false)
                    serializeString(about, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 2) != 0 {geoPoint!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeString(address!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 4) != 0 {serializeInt32(ttlPeriod!, buffer: buffer, boxed: false)}
                    return (FunctionDescription(name: "channels.createChannel", parameters: [("flags", String(describing: flags)), ("title", String(describing: title)), ("about", String(describing: about)), ("geoPoint", String(describing: geoPoint)), ("address", String(describing: address)), ("ttlPeriod", String(describing: ttlPeriod))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
                static func editForumTopic(flags: Int32, channel: Api.InputChannel, topicId: Int32, title: String?, iconEmojiId: Int64?, closed: Api.Bool?, hidden: Api.Bool?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-186670715)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    channel.serialize(buffer, true)
                    serializeInt32(topicId, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(title!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt64(iconEmojiId!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {closed!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 3) != 0 {hidden!.serialize(buffer, true)}
                    return (FunctionDescription(name: "channels.editForumTopic", parameters: [("flags", String(describing: flags)), ("channel", String(describing: channel)), ("topicId", String(describing: topicId)), ("title", String(describing: title)), ("iconEmojiId", String(describing: iconEmojiId)), ("closed", String(describing: closed)), ("hidden", String(describing: hidden))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
                static func getChannelRecommendations(flags: Int32, channel: Api.InputChannel?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.Chats>) {
                    let buffer = Buffer()
                    buffer.appendInt32(631707458)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {channel!.serialize(buffer, true)}
                    return (FunctionDescription(name: "channels.getChannelRecommendations", parameters: [("flags", String(describing: flags)), ("channel", String(describing: channel))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.Chats? in
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
                static func getMessageAuthor(channel: Api.InputChannel, id: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.User>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-320691994)
                    channel.serialize(buffer, true)
                    serializeInt32(id, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "channels.getMessageAuthor", parameters: [("channel", String(describing: channel)), ("id", String(describing: id))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.User? in
                        let reader = BufferReader(buffer)
                        var result: Api.User?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.User
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
                static func getSendAs(flags: Int32, peer: Api.InputPeer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.channels.SendAsPeers>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-410672065)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    return (FunctionDescription(name: "channels.getSendAs", parameters: [("flags", String(describing: flags)), ("peer", String(describing: peer))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.channels.SendAsPeers? in
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
                static func inviteToChannel(channel: Api.InputChannel, users: [Api.InputUser]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.InvitedUsers>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-907854508)
                    channel.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    return (FunctionDescription(name: "channels.inviteToChannel", parameters: [("channel", String(describing: channel)), ("users", String(describing: users))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.InvitedUsers? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.InvitedUsers?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.InvitedUsers
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
                static func reorderPinnedForumTopics(flags: Int32, channel: Api.InputChannel, order: [Int32]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(693150095)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    channel.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(order.count))
                    for item in order {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    return (FunctionDescription(name: "channels.reorderPinnedForumTopics", parameters: [("flags", String(describing: flags)), ("channel", String(describing: channel)), ("order", String(describing: order))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
                static func reportAntiSpamFalsePositive(channel: Api.InputChannel, msgId: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1471109485)
                    channel.serialize(buffer, true)
                    serializeInt32(msgId, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "channels.reportAntiSpamFalsePositive", parameters: [("channel", String(describing: channel)), ("msgId", String(describing: msgId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
                static func restrictSponsoredMessages(channel: Api.InputChannel, restricted: Api.Bool) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1696000743)
                    channel.serialize(buffer, true)
                    restricted.serialize(buffer, true)
                    return (FunctionDescription(name: "channels.restrictSponsoredMessages", parameters: [("channel", String(describing: channel)), ("restricted", String(describing: restricted))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
                static func searchPosts(hashtag: String, offsetRate: Int32, offsetPeer: Api.InputPeer, offsetId: Int32, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.Messages>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-778069893)
                    serializeString(hashtag, buffer: buffer, boxed: false)
                    serializeInt32(offsetRate, buffer: buffer, boxed: false)
                    offsetPeer.serialize(buffer, true)
                    serializeInt32(offsetId, buffer: buffer, boxed: false)
                    serializeInt32(limit, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "channels.searchPosts", parameters: [("hashtag", String(describing: hashtag)), ("offsetRate", String(describing: offsetRate)), ("offsetPeer", String(describing: offsetPeer)), ("offsetId", String(describing: offsetId)), ("limit", String(describing: limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.Messages? in
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
                static func setBoostsToUnblockRestrictions(channel: Api.InputChannel, boosts: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1388733202)
                    channel.serialize(buffer, true)
                    serializeInt32(boosts, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "channels.setBoostsToUnblockRestrictions", parameters: [("channel", String(describing: channel)), ("boosts", String(describing: boosts))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
                static func setEmojiStickers(channel: Api.InputChannel, stickerset: Api.InputStickerSet) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1020866743)
                    channel.serialize(buffer, true)
                    stickerset.serialize(buffer, true)
                    return (FunctionDescription(name: "channels.setEmojiStickers", parameters: [("channel", String(describing: channel)), ("stickerset", String(describing: stickerset))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
                static func toggleAntiSpam(channel: Api.InputChannel, enabled: Api.Bool) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1760814315)
                    channel.serialize(buffer, true)
                    enabled.serialize(buffer, true)
                    return (FunctionDescription(name: "channels.toggleAntiSpam", parameters: [("channel", String(describing: channel)), ("enabled", String(describing: enabled))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
                static func toggleAutotranslation(channel: Api.InputChannel, enabled: Api.Bool) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(377471137)
                    channel.serialize(buffer, true)
                    enabled.serialize(buffer, true)
                    return (FunctionDescription(name: "channels.toggleAutotranslation", parameters: [("channel", String(describing: channel)), ("enabled", String(describing: enabled))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
                static func toggleForum(channel: Api.InputChannel, enabled: Api.Bool, tabs: Api.Bool) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1073174324)
                    channel.serialize(buffer, true)
                    enabled.serialize(buffer, true)
                    tabs.serialize(buffer, true)
                    return (FunctionDescription(name: "channels.toggleForum", parameters: [("channel", String(describing: channel)), ("enabled", String(describing: enabled)), ("tabs", String(describing: tabs))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
                static func toggleParticipantsHidden(channel: Api.InputChannel, enabled: Api.Bool) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1785624660)
                    channel.serialize(buffer, true)
                    enabled.serialize(buffer, true)
                    return (FunctionDescription(name: "channels.toggleParticipantsHidden", parameters: [("channel", String(describing: channel)), ("enabled", String(describing: enabled))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
                static func toggleSignatures(flags: Int32, channel: Api.InputChannel) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1099781276)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    channel.serialize(buffer, true)
                    return (FunctionDescription(name: "channels.toggleSignatures", parameters: [("flags", String(describing: flags)), ("channel", String(describing: channel))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
                static func toggleViewForumAsMessages(channel: Api.InputChannel, enabled: Api.Bool) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1757889771)
                    channel.serialize(buffer, true)
                    enabled.serialize(buffer, true)
                    return (FunctionDescription(name: "channels.toggleViewForumAsMessages", parameters: [("channel", String(describing: channel)), ("enabled", String(describing: enabled))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
                static func updateColor(flags: Int32, channel: Api.InputChannel, color: Int32?, backgroundEmojiId: Int64?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-659933583)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    channel.serialize(buffer, true)
                    if Int(flags) & Int(1 << 2) != 0 {serializeInt32(color!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt64(backgroundEmojiId!, buffer: buffer, boxed: false)}
                    return (FunctionDescription(name: "channels.updateColor", parameters: [("flags", String(describing: flags)), ("channel", String(describing: channel)), ("color", String(describing: color)), ("backgroundEmojiId", String(describing: backgroundEmojiId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
                static func updateEmojiStatus(channel: Api.InputChannel, emojiStatus: Api.EmojiStatus) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-254548312)
                    channel.serialize(buffer, true)
                    emojiStatus.serialize(buffer, true)
                    return (FunctionDescription(name: "channels.updateEmojiStatus", parameters: [("channel", String(describing: channel)), ("emojiStatus", String(describing: emojiStatus))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
                static func updatePaidMessagesPrice(flags: Int32, channel: Api.InputChannel, sendPaidMessagesStars: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1259483771)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    channel.serialize(buffer, true)
                    serializeInt64(sendPaidMessagesStars, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "channels.updatePaidMessagesPrice", parameters: [("flags", String(describing: flags)), ("channel", String(describing: channel)), ("sendPaidMessagesStars", String(describing: sendPaidMessagesStars))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
public extension Api.functions.chatlists {
                static func checkChatlistInvite(slug: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.chatlists.ChatlistInvite>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1103171583)
                    serializeString(slug, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "chatlists.checkChatlistInvite", parameters: [("slug", String(describing: slug))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.chatlists.ChatlistInvite? in
                        let reader = BufferReader(buffer)
                        var result: Api.chatlists.ChatlistInvite?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.chatlists.ChatlistInvite
                        }
                        return result
                    })
                }
}
public extension Api.functions.chatlists {
                static func deleteExportedInvite(chatlist: Api.InputChatlist, slug: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1906072670)
                    chatlist.serialize(buffer, true)
                    serializeString(slug, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "chatlists.deleteExportedInvite", parameters: [("chatlist", String(describing: chatlist)), ("slug", String(describing: slug))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.chatlists {
                static func editExportedInvite(flags: Int32, chatlist: Api.InputChatlist, slug: String, title: String?, peers: [Api.InputPeer]?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.ExportedChatlistInvite>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1698543165)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    chatlist.serialize(buffer, true)
                    serializeString(slug, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(title!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(peers!.count))
                    for item in peers! {
                        item.serialize(buffer, true)
                    }}
                    return (FunctionDescription(name: "chatlists.editExportedInvite", parameters: [("flags", String(describing: flags)), ("chatlist", String(describing: chatlist)), ("slug", String(describing: slug)), ("title", String(describing: title)), ("peers", String(describing: peers))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.ExportedChatlistInvite? in
                        let reader = BufferReader(buffer)
                        var result: Api.ExportedChatlistInvite?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.ExportedChatlistInvite
                        }
                        return result
                    })
                }
}
public extension Api.functions.chatlists {
                static func exportChatlistInvite(chatlist: Api.InputChatlist, title: String, peers: [Api.InputPeer]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.chatlists.ExportedChatlistInvite>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-2072885362)
                    chatlist.serialize(buffer, true)
                    serializeString(title, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(peers.count))
                    for item in peers {
                        item.serialize(buffer, true)
                    }
                    return (FunctionDescription(name: "chatlists.exportChatlistInvite", parameters: [("chatlist", String(describing: chatlist)), ("title", String(describing: title)), ("peers", String(describing: peers))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.chatlists.ExportedChatlistInvite? in
                        let reader = BufferReader(buffer)
                        var result: Api.chatlists.ExportedChatlistInvite?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.chatlists.ExportedChatlistInvite
                        }
                        return result
                    })
                }
}
public extension Api.functions.chatlists {
                static func getChatlistUpdates(chatlist: Api.InputChatlist) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.chatlists.ChatlistUpdates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1992190687)
                    chatlist.serialize(buffer, true)
                    return (FunctionDescription(name: "chatlists.getChatlistUpdates", parameters: [("chatlist", String(describing: chatlist))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.chatlists.ChatlistUpdates? in
                        let reader = BufferReader(buffer)
                        var result: Api.chatlists.ChatlistUpdates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.chatlists.ChatlistUpdates
                        }
                        return result
                    })
                }
}
public extension Api.functions.chatlists {
                static func getExportedInvites(chatlist: Api.InputChatlist) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.chatlists.ExportedInvites>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-838608253)
                    chatlist.serialize(buffer, true)
                    return (FunctionDescription(name: "chatlists.getExportedInvites", parameters: [("chatlist", String(describing: chatlist))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.chatlists.ExportedInvites? in
                        let reader = BufferReader(buffer)
                        var result: Api.chatlists.ExportedInvites?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.chatlists.ExportedInvites
                        }
                        return result
                    })
                }
}
public extension Api.functions.chatlists {
                static func getLeaveChatlistSuggestions(chatlist: Api.InputChatlist) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Api.Peer]>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-37955820)
                    chatlist.serialize(buffer, true)
                    return (FunctionDescription(name: "chatlists.getLeaveChatlistSuggestions", parameters: [("chatlist", String(describing: chatlist))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> [Api.Peer]? in
                        let reader = BufferReader(buffer)
                        var result: [Api.Peer]?
                        if let _ = reader.readInt32() {
                            result = Api.parseVector(reader, elementSignature: 0, elementType: Api.Peer.self)
                        }
                        return result
                    })
                }
}
public extension Api.functions.chatlists {
                static func hideChatlistUpdates(chatlist: Api.InputChatlist) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1726252795)
                    chatlist.serialize(buffer, true)
                    return (FunctionDescription(name: "chatlists.hideChatlistUpdates", parameters: [("chatlist", String(describing: chatlist))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.chatlists {
                static func joinChatlistInvite(slug: String, peers: [Api.InputPeer]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1498291302)
                    serializeString(slug, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(peers.count))
                    for item in peers {
                        item.serialize(buffer, true)
                    }
                    return (FunctionDescription(name: "chatlists.joinChatlistInvite", parameters: [("slug", String(describing: slug)), ("peers", String(describing: peers))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
}
public extension Api.functions.chatlists {
                static func joinChatlistUpdates(chatlist: Api.InputChatlist, peers: [Api.InputPeer]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-527828747)
                    chatlist.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(peers.count))
                    for item in peers {
                        item.serialize(buffer, true)
                    }
                    return (FunctionDescription(name: "chatlists.joinChatlistUpdates", parameters: [("chatlist", String(describing: chatlist)), ("peers", String(describing: peers))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
}
public extension Api.functions.chatlists {
                static func leaveChatlist(chatlist: Api.InputChatlist, peers: [Api.InputPeer]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1962598714)
                    chatlist.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(peers.count))
                    for item in peers {
                        item.serialize(buffer, true)
                    }
                    return (FunctionDescription(name: "chatlists.leaveChatlist", parameters: [("chatlist", String(describing: chatlist)), ("peers", String(describing: peers))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
                static func block(flags: Int32, id: Api.InputPeer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(774801204)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    id.serialize(buffer, true)
                    return (FunctionDescription(name: "contacts.block", parameters: [("flags", String(describing: flags)), ("id", String(describing: id))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
                static func editCloseFriends(id: [Int64]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1167653392)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(id.count))
                    for item in id {
                        serializeInt64(item, buffer: buffer, boxed: false)
                    }
                    return (FunctionDescription(name: "contacts.editCloseFriends", parameters: [("id", String(describing: id))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
                static func exportContactToken() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.ExportedContactToken>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-127582169)
                    
                    return (FunctionDescription(name: "contacts.exportContactToken", parameters: []), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.ExportedContactToken? in
                        let reader = BufferReader(buffer)
                        var result: Api.ExportedContactToken?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.ExportedContactToken
                        }
                        return result
                    })
                }
}
public extension Api.functions.contacts {
                static func getBirthdays() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.contacts.ContactBirthdays>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-621959068)
                    
                    return (FunctionDescription(name: "contacts.getBirthdays", parameters: []), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.contacts.ContactBirthdays? in
                        let reader = BufferReader(buffer)
                        var result: Api.contacts.ContactBirthdays?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.contacts.ContactBirthdays
                        }
                        return result
                    })
                }
}
public extension Api.functions.contacts {
                static func getBlocked(flags: Int32, offset: Int32, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.contacts.Blocked>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1702457472)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(offset, buffer: buffer, boxed: false)
                    serializeInt32(limit, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "contacts.getBlocked", parameters: [("flags", String(describing: flags)), ("offset", String(describing: offset)), ("limit", String(describing: limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.contacts.Blocked? in
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
                static func getSponsoredPeers(q: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.contacts.SponsoredPeers>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1228356717)
                    serializeString(q, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "contacts.getSponsoredPeers", parameters: [("q", String(describing: q))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.contacts.SponsoredPeers? in
                        let reader = BufferReader(buffer)
                        var result: Api.contacts.SponsoredPeers?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.contacts.SponsoredPeers
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
                static func importContactToken(token: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.User>) {
                    let buffer = Buffer()
                    buffer.appendInt32(318789512)
                    serializeString(token, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "contacts.importContactToken", parameters: [("token", String(describing: token))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.User? in
                        let reader = BufferReader(buffer)
                        var result: Api.User?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.User
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
                static func resolveUsername(flags: Int32, username: String, referer: String?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.contacts.ResolvedPeer>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1918565308)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(username, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(referer!, buffer: buffer, boxed: false)}
                    return (FunctionDescription(name: "contacts.resolveUsername", parameters: [("flags", String(describing: flags)), ("username", String(describing: username)), ("referer", String(describing: referer))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.contacts.ResolvedPeer? in
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
                static func setBlocked(flags: Int32, id: [Api.InputPeer], limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1798939530)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(id.count))
                    for item in id {
                        item.serialize(buffer, true)
                    }
                    serializeInt32(limit, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "contacts.setBlocked", parameters: [("flags", String(describing: flags)), ("id", String(describing: id)), ("limit", String(describing: limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
                static func unblock(flags: Int32, id: Api.InputPeer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1252994264)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    id.serialize(buffer, true)
                    return (FunctionDescription(name: "contacts.unblock", parameters: [("flags", String(describing: flags)), ("id", String(describing: id))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
public extension Api.functions.fragment {
                static func getCollectibleInfo(collectible: Api.InputCollectible) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.fragment.CollectibleInfo>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1105295942)
                    collectible.serialize(buffer, true)
                    return (FunctionDescription(name: "fragment.getCollectibleInfo", parameters: [("collectible", String(describing: collectible))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.fragment.CollectibleInfo? in
                        let reader = BufferReader(buffer)
                        var result: Api.fragment.CollectibleInfo?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.fragment.CollectibleInfo
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
                static func getAppConfig(hash: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.help.AppConfig>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1642330196)
                    serializeInt32(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "help.getAppConfig", parameters: [("hash", String(describing: hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.help.AppConfig? in
                        let reader = BufferReader(buffer)
                        var result: Api.help.AppConfig?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.help.AppConfig
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
                static func getPeerColors(hash: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.help.PeerColors>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-629083089)
                    serializeInt32(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "help.getPeerColors", parameters: [("hash", String(describing: hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.help.PeerColors? in
                        let reader = BufferReader(buffer)
                        var result: Api.help.PeerColors?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.help.PeerColors
                        }
                        return result
                    })
                }
}
public extension Api.functions.help {
                static func getPeerProfileColors(hash: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.help.PeerColors>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1412453891)
                    serializeInt32(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "help.getPeerProfileColors", parameters: [("hash", String(describing: hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.help.PeerColors? in
                        let reader = BufferReader(buffer)
                        var result: Api.help.PeerColors?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.help.PeerColors
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
                static func getTimezonesList(hash: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.help.TimezonesList>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1236468288)
                    serializeInt32(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "help.getTimezonesList", parameters: [("hash", String(describing: hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.help.TimezonesList? in
                        let reader = BufferReader(buffer)
                        var result: Api.help.TimezonesList?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.help.TimezonesList
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
                static func addChatUser(chatId: Int64, userId: Api.InputUser, fwdLimit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.InvitedUsers>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-876162809)
                    serializeInt64(chatId, buffer: buffer, boxed: false)
                    userId.serialize(buffer, true)
                    serializeInt32(fwdLimit, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.addChatUser", parameters: [("chatId", String(describing: chatId)), ("userId", String(describing: userId)), ("fwdLimit", String(describing: fwdLimit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.InvitedUsers? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.InvitedUsers?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.InvitedUsers
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func appendTodoList(peer: Api.InputPeer, msgId: Int32, list: [Api.TodoItem]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(564531287)
                    peer.serialize(buffer, true)
                    serializeInt32(msgId, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(list.count))
                    for item in list {
                        item.serialize(buffer, true)
                    }
                    return (FunctionDescription(name: "messages.appendTodoList", parameters: [("peer", String(describing: peer)), ("msgId", String(describing: msgId)), ("list", String(describing: list))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
                static func checkQuickReplyShortcut(shortcut: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-237962285)
                    serializeString(shortcut, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.checkQuickReplyShortcut", parameters: [("shortcut", String(describing: shortcut))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
                static func clickSponsoredMessage(flags: Int32, randomId: Buffer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-2110454402)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeBytes(randomId, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.clickSponsoredMessage", parameters: [("flags", String(describing: flags)), ("randomId", String(describing: randomId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
                static func createChat(flags: Int32, users: [Api.InputUser], title: String, ttlPeriod: Int32?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.InvitedUsers>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1831936556)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    serializeString(title, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(ttlPeriod!, buffer: buffer, boxed: false)}
                    return (FunctionDescription(name: "messages.createChat", parameters: [("flags", String(describing: flags)), ("users", String(describing: users)), ("title", String(describing: title)), ("ttlPeriod", String(describing: ttlPeriod))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.InvitedUsers? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.InvitedUsers?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.InvitedUsers
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
                static func deleteFactCheck(peer: Api.InputPeer, msgId: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-774204404)
                    peer.serialize(buffer, true)
                    serializeInt32(msgId, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.deleteFactCheck", parameters: [("peer", String(describing: peer)), ("msgId", String(describing: msgId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
                static func deleteQuickReplyMessages(shortcutId: Int32, id: [Int32]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-519706352)
                    serializeInt32(shortcutId, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(id.count))
                    for item in id {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    return (FunctionDescription(name: "messages.deleteQuickReplyMessages", parameters: [("shortcutId", String(describing: shortcutId)), ("id", String(describing: id))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
                static func deleteQuickReplyShortcut(shortcutId: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1019234112)
                    serializeInt32(shortcutId, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.deleteQuickReplyShortcut", parameters: [("shortcutId", String(describing: shortcutId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
                static func deleteSavedHistory(flags: Int32, parentPeer: Api.InputPeer?, peer: Api.InputPeer, maxId: Int32, minDate: Int32?, maxDate: Int32?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.AffectedHistory>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1304758367)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {parentPeer!.serialize(buffer, true)}
                    peer.serialize(buffer, true)
                    serializeInt32(maxId, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 2) != 0 {serializeInt32(minDate!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 3) != 0 {serializeInt32(maxDate!, buffer: buffer, boxed: false)}
                    return (FunctionDescription(name: "messages.deleteSavedHistory", parameters: [("flags", String(describing: flags)), ("parentPeer", String(describing: parentPeer)), ("peer", String(describing: peer)), ("maxId", String(describing: maxId)), ("minDate", String(describing: minDate)), ("maxDate", String(describing: maxDate))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.AffectedHistory? in
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
                static func editFactCheck(peer: Api.InputPeer, msgId: Int32, text: Api.TextWithEntities) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(92925557)
                    peer.serialize(buffer, true)
                    serializeInt32(msgId, buffer: buffer, boxed: false)
                    text.serialize(buffer, true)
                    return (FunctionDescription(name: "messages.editFactCheck", parameters: [("peer", String(describing: peer)), ("msgId", String(describing: msgId)), ("text", String(describing: text))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
                static func editMessage(flags: Int32, peer: Api.InputPeer, id: Int32, message: String?, media: Api.InputMedia?, replyMarkup: Api.ReplyMarkup?, entities: [Api.MessageEntity]?, scheduleDate: Int32?, quickReplyShortcutId: Int32?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-539934715)
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
                    if Int(flags) & Int(1 << 17) != 0 {serializeInt32(quickReplyShortcutId!, buffer: buffer, boxed: false)}
                    return (FunctionDescription(name: "messages.editMessage", parameters: [("flags", String(describing: flags)), ("peer", String(describing: peer)), ("id", String(describing: id)), ("message", String(describing: message)), ("media", String(describing: media)), ("replyMarkup", String(describing: replyMarkup)), ("entities", String(describing: entities)), ("scheduleDate", String(describing: scheduleDate)), ("quickReplyShortcutId", String(describing: quickReplyShortcutId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
                static func editQuickReplyShortcut(shortcutId: Int32, shortcut: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1543519471)
                    serializeInt32(shortcutId, buffer: buffer, boxed: false)
                    serializeString(shortcut, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.editQuickReplyShortcut", parameters: [("shortcutId", String(describing: shortcutId)), ("shortcut", String(describing: shortcut))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
                static func exportChatInvite(flags: Int32, peer: Api.InputPeer, expireDate: Int32?, usageLimit: Int32?, title: String?, subscriptionPricing: Api.StarsSubscriptionPricing?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.ExportedChatInvite>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1537876336)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(expireDate!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt32(usageLimit!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 4) != 0 {serializeString(title!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 5) != 0 {subscriptionPricing!.serialize(buffer, true)}
                    return (FunctionDescription(name: "messages.exportChatInvite", parameters: [("flags", String(describing: flags)), ("peer", String(describing: peer)), ("expireDate", String(describing: expireDate)), ("usageLimit", String(describing: usageLimit)), ("title", String(describing: title)), ("subscriptionPricing", String(describing: subscriptionPricing))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.ExportedChatInvite? in
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
                static func forwardMessages(flags: Int32, fromPeer: Api.InputPeer, id: [Int32], randomId: [Int64], toPeer: Api.InputPeer, topMsgId: Int32?, replyTo: Api.InputReplyTo?, scheduleDate: Int32?, sendAs: Api.InputPeer?, quickReplyShortcut: Api.InputQuickReplyShortcut?, videoTimestamp: Int32?, allowPaidStars: Int64?, suggestedPost: Api.SuggestedPost?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1752618806)
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
                    if Int(flags) & Int(1 << 22) != 0 {replyTo!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 10) != 0 {serializeInt32(scheduleDate!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 13) != 0 {sendAs!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 17) != 0 {quickReplyShortcut!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 20) != 0 {serializeInt32(videoTimestamp!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 21) != 0 {serializeInt64(allowPaidStars!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 23) != 0 {suggestedPost!.serialize(buffer, true)}
                    return (FunctionDescription(name: "messages.forwardMessages", parameters: [("flags", String(describing: flags)), ("fromPeer", String(describing: fromPeer)), ("id", String(describing: id)), ("randomId", String(describing: randomId)), ("toPeer", String(describing: toPeer)), ("topMsgId", String(describing: topMsgId)), ("replyTo", String(describing: replyTo)), ("scheduleDate", String(describing: scheduleDate)), ("sendAs", String(describing: sendAs)), ("quickReplyShortcut", String(describing: quickReplyShortcut)), ("videoTimestamp", String(describing: videoTimestamp)), ("allowPaidStars", String(describing: allowPaidStars)), ("suggestedPost", String(describing: suggestedPost))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
                static func getAvailableEffects(hash: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.AvailableEffects>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-559805895)
                    serializeInt32(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.getAvailableEffects", parameters: [("hash", String(describing: hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.AvailableEffects? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.AvailableEffects?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.AvailableEffects
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
                static func getBotApp(app: Api.InputBotApp, hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.BotApp>) {
                    let buffer = Buffer()
                    buffer.appendInt32(889046467)
                    app.serialize(buffer, true)
                    serializeInt64(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.getBotApp", parameters: [("app", String(describing: app)), ("hash", String(describing: hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.BotApp? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.BotApp?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.BotApp
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
                static func getDefaultHistoryTTL() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.DefaultHistoryTTL>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1703637384)
                    
                    return (FunctionDescription(name: "messages.getDefaultHistoryTTL", parameters: []), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.DefaultHistoryTTL? in
                        let reader = BufferReader(buffer)
                        var result: Api.DefaultHistoryTTL?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.DefaultHistoryTTL
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func getDefaultTagReactions(hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.Reactions>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1107741656)
                    serializeInt64(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.getDefaultTagReactions", parameters: [("hash", String(describing: hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.Reactions? in
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
                static func getDialogFilters() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.DialogFilters>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-271283063)
                    
                    return (FunctionDescription(name: "messages.getDialogFilters", parameters: []), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.DialogFilters? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.DialogFilters?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.DialogFilters
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func getDialogUnreadMarks(flags: Int32, parentPeer: Api.InputPeer?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Api.DialogPeer]>) {
                    let buffer = Buffer()
                    buffer.appendInt32(555754018)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {parentPeer!.serialize(buffer, true)}
                    return (FunctionDescription(name: "messages.getDialogUnreadMarks", parameters: [("flags", String(describing: flags)), ("parentPeer", String(describing: parentPeer))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> [Api.DialogPeer]? in
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
                static func getEmojiGroups(hash: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.EmojiGroups>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1955122779)
                    serializeInt32(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.getEmojiGroups", parameters: [("hash", String(describing: hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.EmojiGroups? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.EmojiGroups?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.EmojiGroups
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
                static func getEmojiProfilePhotoGroups(hash: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.EmojiGroups>) {
                    let buffer = Buffer()
                    buffer.appendInt32(564480243)
                    serializeInt32(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.getEmojiProfilePhotoGroups", parameters: [("hash", String(describing: hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.EmojiGroups? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.EmojiGroups?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.EmojiGroups
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func getEmojiStatusGroups(hash: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.EmojiGroups>) {
                    let buffer = Buffer()
                    buffer.appendInt32(785209037)
                    serializeInt32(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.getEmojiStatusGroups", parameters: [("hash", String(describing: hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.EmojiGroups? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.EmojiGroups?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.EmojiGroups
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func getEmojiStickerGroups(hash: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.EmojiGroups>) {
                    let buffer = Buffer()
                    buffer.appendInt32(500711669)
                    serializeInt32(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.getEmojiStickerGroups", parameters: [("hash", String(describing: hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.EmojiGroups? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.EmojiGroups?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.EmojiGroups
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
                static func getFactCheck(peer: Api.InputPeer, msgId: [Int32]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Api.FactCheck]>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1177696786)
                    peer.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(msgId.count))
                    for item in msgId {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    return (FunctionDescription(name: "messages.getFactCheck", parameters: [("peer", String(describing: peer)), ("msgId", String(describing: msgId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> [Api.FactCheck]? in
                        let reader = BufferReader(buffer)
                        var result: [Api.FactCheck]?
                        if let _ = reader.readInt32() {
                            result = Api.parseVector(reader, elementSignature: 0, elementType: Api.FactCheck.self)
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
                static func getMessageReadParticipants(peer: Api.InputPeer, msgId: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Api.ReadParticipantDate]>) {
                    let buffer = Buffer()
                    buffer.appendInt32(834782287)
                    peer.serialize(buffer, true)
                    serializeInt32(msgId, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.getMessageReadParticipants", parameters: [("peer", String(describing: peer)), ("msgId", String(describing: msgId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> [Api.ReadParticipantDate]? in
                        let reader = BufferReader(buffer)
                        var result: [Api.ReadParticipantDate]?
                        if let _ = reader.readInt32() {
                            result = Api.parseVector(reader, elementSignature: 0, elementType: Api.ReadParticipantDate.self)
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
                static func getMyStickers(offsetId: Int64, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.MyStickers>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-793386500)
                    serializeInt64(offsetId, buffer: buffer, boxed: false)
                    serializeInt32(limit, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.getMyStickers", parameters: [("offsetId", String(describing: offsetId)), ("limit", String(describing: limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.MyStickers? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.MyStickers?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.MyStickers
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
                static func getOutboxReadDate(peer: Api.InputPeer, msgId: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.OutboxReadDate>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1941176739)
                    peer.serialize(buffer, true)
                    serializeInt32(msgId, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.getOutboxReadDate", parameters: [("peer", String(describing: peer)), ("msgId", String(describing: msgId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.OutboxReadDate? in
                        let reader = BufferReader(buffer)
                        var result: Api.OutboxReadDate?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.OutboxReadDate
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func getPaidReactionPrivacy() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1193563562)
                    
                    return (FunctionDescription(name: "messages.getPaidReactionPrivacy", parameters: []), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
                static func getPinnedSavedDialogs() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.SavedDialogs>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-700607264)
                    
                    return (FunctionDescription(name: "messages.getPinnedSavedDialogs", parameters: []), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.SavedDialogs? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.SavedDialogs?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.SavedDialogs
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
                static func getPreparedInlineMessage(bot: Api.InputUser, id: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.PreparedInlineMessage>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-2055291464)
                    bot.serialize(buffer, true)
                    serializeString(id, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.getPreparedInlineMessage", parameters: [("bot", String(describing: bot)), ("id", String(describing: id))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.PreparedInlineMessage? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.PreparedInlineMessage?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.PreparedInlineMessage
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func getQuickReplies(hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.QuickReplies>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-729550168)
                    serializeInt64(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.getQuickReplies", parameters: [("hash", String(describing: hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.QuickReplies? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.QuickReplies?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.QuickReplies
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func getQuickReplyMessages(flags: Int32, shortcutId: Int32, id: [Int32]?, hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.Messages>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1801153085)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(shortcutId, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(id!.count))
                    for item in id! {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }}
                    serializeInt64(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.getQuickReplyMessages", parameters: [("flags", String(describing: flags)), ("shortcutId", String(describing: shortcutId)), ("id", String(describing: id)), ("hash", String(describing: hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.Messages? in
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
                static func getSavedDialogs(flags: Int32, parentPeer: Api.InputPeer?, offsetDate: Int32, offsetId: Int32, offsetPeer: Api.InputPeer, limit: Int32, hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.SavedDialogs>) {
                    let buffer = Buffer()
                    buffer.appendInt32(512883865)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {parentPeer!.serialize(buffer, true)}
                    serializeInt32(offsetDate, buffer: buffer, boxed: false)
                    serializeInt32(offsetId, buffer: buffer, boxed: false)
                    offsetPeer.serialize(buffer, true)
                    serializeInt32(limit, buffer: buffer, boxed: false)
                    serializeInt64(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.getSavedDialogs", parameters: [("flags", String(describing: flags)), ("parentPeer", String(describing: parentPeer)), ("offsetDate", String(describing: offsetDate)), ("offsetId", String(describing: offsetId)), ("offsetPeer", String(describing: offsetPeer)), ("limit", String(describing: limit)), ("hash", String(describing: hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.SavedDialogs? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.SavedDialogs?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.SavedDialogs
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func getSavedDialogsByID(flags: Int32, parentPeer: Api.InputPeer?, ids: [Api.InputPeer]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.SavedDialogs>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1869585558)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {parentPeer!.serialize(buffer, true)}
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(ids.count))
                    for item in ids {
                        item.serialize(buffer, true)
                    }
                    return (FunctionDescription(name: "messages.getSavedDialogsByID", parameters: [("flags", String(describing: flags)), ("parentPeer", String(describing: parentPeer)), ("ids", String(describing: ids))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.SavedDialogs? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.SavedDialogs?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.SavedDialogs
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
                static func getSavedHistory(flags: Int32, parentPeer: Api.InputPeer?, peer: Api.InputPeer, offsetId: Int32, offsetDate: Int32, addOffset: Int32, limit: Int32, maxId: Int32, minId: Int32, hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.Messages>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1718964215)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {parentPeer!.serialize(buffer, true)}
                    peer.serialize(buffer, true)
                    serializeInt32(offsetId, buffer: buffer, boxed: false)
                    serializeInt32(offsetDate, buffer: buffer, boxed: false)
                    serializeInt32(addOffset, buffer: buffer, boxed: false)
                    serializeInt32(limit, buffer: buffer, boxed: false)
                    serializeInt32(maxId, buffer: buffer, boxed: false)
                    serializeInt32(minId, buffer: buffer, boxed: false)
                    serializeInt64(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.getSavedHistory", parameters: [("flags", String(describing: flags)), ("parentPeer", String(describing: parentPeer)), ("peer", String(describing: peer)), ("offsetId", String(describing: offsetId)), ("offsetDate", String(describing: offsetDate)), ("addOffset", String(describing: addOffset)), ("limit", String(describing: limit)), ("maxId", String(describing: maxId)), ("minId", String(describing: minId)), ("hash", String(describing: hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.Messages? in
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
                static func getSavedReactionTags(flags: Int32, peer: Api.InputPeer?, hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.SavedReactionTags>) {
                    let buffer = Buffer()
                    buffer.appendInt32(909631579)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {peer!.serialize(buffer, true)}
                    serializeInt64(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.getSavedReactionTags", parameters: [("flags", String(describing: flags)), ("peer", String(describing: peer)), ("hash", String(describing: hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.SavedReactionTags? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.SavedReactionTags?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.SavedReactionTags
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
                static func getSearchCounters(flags: Int32, peer: Api.InputPeer, savedPeerId: Api.InputPeer?, topMsgId: Int32?, filters: [Api.MessagesFilter]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Api.messages.SearchCounter]>) {
                    let buffer = Buffer()
                    buffer.appendInt32(465367808)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    if Int(flags) & Int(1 << 2) != 0 {savedPeerId!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(topMsgId!, buffer: buffer, boxed: false)}
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(filters.count))
                    for item in filters {
                        item.serialize(buffer, true)
                    }
                    return (FunctionDescription(name: "messages.getSearchCounters", parameters: [("flags", String(describing: flags)), ("peer", String(describing: peer)), ("savedPeerId", String(describing: savedPeerId)), ("topMsgId", String(describing: topMsgId)), ("filters", String(describing: filters))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> [Api.messages.SearchCounter]? in
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
                static func getSearchResultsCalendar(flags: Int32, peer: Api.InputPeer, savedPeerId: Api.InputPeer?, filter: Api.MessagesFilter, offsetId: Int32, offsetDate: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.SearchResultsCalendar>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1789130429)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    if Int(flags) & Int(1 << 2) != 0 {savedPeerId!.serialize(buffer, true)}
                    filter.serialize(buffer, true)
                    serializeInt32(offsetId, buffer: buffer, boxed: false)
                    serializeInt32(offsetDate, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.getSearchResultsCalendar", parameters: [("flags", String(describing: flags)), ("peer", String(describing: peer)), ("savedPeerId", String(describing: savedPeerId)), ("filter", String(describing: filter)), ("offsetId", String(describing: offsetId)), ("offsetDate", String(describing: offsetDate))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.SearchResultsCalendar? in
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
                static func getSearchResultsPositions(flags: Int32, peer: Api.InputPeer, savedPeerId: Api.InputPeer?, filter: Api.MessagesFilter, offsetId: Int32, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.SearchResultsPositions>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1669386480)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    if Int(flags) & Int(1 << 2) != 0 {savedPeerId!.serialize(buffer, true)}
                    filter.serialize(buffer, true)
                    serializeInt32(offsetId, buffer: buffer, boxed: false)
                    serializeInt32(limit, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.getSearchResultsPositions", parameters: [("flags", String(describing: flags)), ("peer", String(describing: peer)), ("savedPeerId", String(describing: savedPeerId)), ("filter", String(describing: filter)), ("offsetId", String(describing: offsetId)), ("limit", String(describing: limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.SearchResultsPositions? in
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
                static func getSponsoredMessages(flags: Int32, peer: Api.InputPeer, msgId: Int32?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.SponsoredMessages>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1030547536)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(msgId!, buffer: buffer, boxed: false)}
                    return (FunctionDescription(name: "messages.getSponsoredMessages", parameters: [("flags", String(describing: flags)), ("peer", String(describing: peer)), ("msgId", String(describing: msgId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.SponsoredMessages? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.SponsoredMessages?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.SponsoredMessages
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
                static func getUnreadReactions(flags: Int32, peer: Api.InputPeer, topMsgId: Int32?, savedPeerId: Api.InputPeer?, offsetId: Int32, addOffset: Int32, limit: Int32, maxId: Int32, minId: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.Messages>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1115713364)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(topMsgId!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {savedPeerId!.serialize(buffer, true)}
                    serializeInt32(offsetId, buffer: buffer, boxed: false)
                    serializeInt32(addOffset, buffer: buffer, boxed: false)
                    serializeInt32(limit, buffer: buffer, boxed: false)
                    serializeInt32(maxId, buffer: buffer, boxed: false)
                    serializeInt32(minId, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.getUnreadReactions", parameters: [("flags", String(describing: flags)), ("peer", String(describing: peer)), ("topMsgId", String(describing: topMsgId)), ("savedPeerId", String(describing: savedPeerId)), ("offsetId", String(describing: offsetId)), ("addOffset", String(describing: addOffset)), ("limit", String(describing: limit)), ("maxId", String(describing: maxId)), ("minId", String(describing: minId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.Messages? in
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
                static func getWebPage(url: String, hash: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.WebPage>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1919511901)
                    serializeString(url, buffer: buffer, boxed: false)
                    serializeInt32(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.getWebPage", parameters: [("url", String(describing: url)), ("hash", String(describing: hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.WebPage? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.WebPage?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.WebPage
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func getWebPagePreview(flags: Int32, message: String, entities: [Api.MessageEntity]?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.WebPagePreview>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1460498287)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(message, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 3) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(entities!.count))
                    for item in entities! {
                        item.serialize(buffer, true)
                    }}
                    return (FunctionDescription(name: "messages.getWebPagePreview", parameters: [("flags", String(describing: flags)), ("message", String(describing: message)), ("entities", String(describing: entities))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.WebPagePreview? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.WebPagePreview?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.WebPagePreview
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
                static func markDialogUnread(flags: Int32, parentPeer: Api.InputPeer?, peer: Api.InputDialogPeer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1940912392)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {parentPeer!.serialize(buffer, true)}
                    peer.serialize(buffer, true)
                    return (FunctionDescription(name: "messages.markDialogUnread", parameters: [("flags", String(describing: flags)), ("parentPeer", String(describing: parentPeer)), ("peer", String(describing: peer))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
                static func prolongWebView(flags: Int32, peer: Api.InputPeer, bot: Api.InputUser, queryId: Int64, replyTo: Api.InputReplyTo?, sendAs: Api.InputPeer?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1328014717)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    bot.serialize(buffer, true)
                    serializeInt64(queryId, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {replyTo!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 13) != 0 {sendAs!.serialize(buffer, true)}
                    return (FunctionDescription(name: "messages.prolongWebView", parameters: [("flags", String(describing: flags)), ("peer", String(describing: peer)), ("bot", String(describing: bot)), ("queryId", String(describing: queryId)), ("replyTo", String(describing: replyTo)), ("sendAs", String(describing: sendAs))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
                static func readReactions(flags: Int32, peer: Api.InputPeer, topMsgId: Int32?, savedPeerId: Api.InputPeer?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.AffectedHistory>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1631301741)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(topMsgId!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {savedPeerId!.serialize(buffer, true)}
                    return (FunctionDescription(name: "messages.readReactions", parameters: [("flags", String(describing: flags)), ("peer", String(describing: peer)), ("topMsgId", String(describing: topMsgId)), ("savedPeerId", String(describing: savedPeerId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.AffectedHistory? in
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
                static func readSavedHistory(parentPeer: Api.InputPeer, peer: Api.InputPeer, maxId: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1169540261)
                    parentPeer.serialize(buffer, true)
                    peer.serialize(buffer, true)
                    serializeInt32(maxId, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.readSavedHistory", parameters: [("parentPeer", String(describing: parentPeer)), ("peer", String(describing: peer)), ("maxId", String(describing: maxId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
                static func reorderPinnedSavedDialogs(flags: Int32, order: [Api.InputDialogPeer]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1955502713)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(order.count))
                    for item in order {
                        item.serialize(buffer, true)
                    }
                    return (FunctionDescription(name: "messages.reorderPinnedSavedDialogs", parameters: [("flags", String(describing: flags)), ("order", String(describing: order))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
                static func reorderQuickReplies(order: [Int32]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1613961479)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(order.count))
                    for item in order {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    return (FunctionDescription(name: "messages.reorderQuickReplies", parameters: [("order", String(describing: order))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
                static func report(peer: Api.InputPeer, id: [Int32], option: Buffer, message: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.ReportResult>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-59199589)
                    peer.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(id.count))
                    for item in id {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    serializeBytes(option, buffer: buffer, boxed: false)
                    serializeString(message, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.report", parameters: [("peer", String(describing: peer)), ("id", String(describing: id)), ("option", String(describing: option)), ("message", String(describing: message))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.ReportResult? in
                        let reader = BufferReader(buffer)
                        var result: Api.ReportResult?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.ReportResult
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
                static func reportMessagesDelivery(flags: Int32, peer: Api.InputPeer, id: [Int32]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1517122453)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(id.count))
                    for item in id {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    return (FunctionDescription(name: "messages.reportMessagesDelivery", parameters: [("flags", String(describing: flags)), ("peer", String(describing: peer)), ("id", String(describing: id))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
                static func reportSponsoredMessage(randomId: Buffer, option: Buffer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.channels.SponsoredMessageReportResult>) {
                    let buffer = Buffer()
                    buffer.appendInt32(315355332)
                    serializeBytes(randomId, buffer: buffer, boxed: false)
                    serializeBytes(option, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.reportSponsoredMessage", parameters: [("randomId", String(describing: randomId)), ("option", String(describing: option))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.channels.SponsoredMessageReportResult? in
                        let reader = BufferReader(buffer)
                        var result: Api.channels.SponsoredMessageReportResult?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.channels.SponsoredMessageReportResult
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func requestAppWebView(flags: Int32, peer: Api.InputPeer, app: Api.InputBotApp, startParam: String?, themeParams: Api.DataJSON?, platform: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.WebViewResult>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1398901710)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    app.serialize(buffer, true)
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(startParam!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {themeParams!.serialize(buffer, true)}
                    serializeString(platform, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.requestAppWebView", parameters: [("flags", String(describing: flags)), ("peer", String(describing: peer)), ("app", String(describing: app)), ("startParam", String(describing: startParam)), ("themeParams", String(describing: themeParams)), ("platform", String(describing: platform))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.WebViewResult? in
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
                static func requestMainWebView(flags: Int32, peer: Api.InputPeer, bot: Api.InputUser, startParam: String?, themeParams: Api.DataJSON?, platform: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.WebViewResult>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-908059013)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    bot.serialize(buffer, true)
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(startParam!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 0) != 0 {themeParams!.serialize(buffer, true)}
                    serializeString(platform, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.requestMainWebView", parameters: [("flags", String(describing: flags)), ("peer", String(describing: peer)), ("bot", String(describing: bot)), ("startParam", String(describing: startParam)), ("themeParams", String(describing: themeParams)), ("platform", String(describing: platform))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.WebViewResult? in
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
                static func requestSimpleWebView(flags: Int32, bot: Api.InputUser, url: String?, startParam: String?, themeParams: Api.DataJSON?, platform: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.WebViewResult>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1094336115)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    bot.serialize(buffer, true)
                    if Int(flags) & Int(1 << 3) != 0 {serializeString(url!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 4) != 0 {serializeString(startParam!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 0) != 0 {themeParams!.serialize(buffer, true)}
                    serializeString(platform, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.requestSimpleWebView", parameters: [("flags", String(describing: flags)), ("bot", String(describing: bot)), ("url", String(describing: url)), ("startParam", String(describing: startParam)), ("themeParams", String(describing: themeParams)), ("platform", String(describing: platform))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.WebViewResult? in
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
                static func requestWebView(flags: Int32, peer: Api.InputPeer, bot: Api.InputUser, url: String?, startParam: String?, themeParams: Api.DataJSON?, platform: String, replyTo: Api.InputReplyTo?, sendAs: Api.InputPeer?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.WebViewResult>) {
                    let buffer = Buffer()
                    buffer.appendInt32(647873217)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    bot.serialize(buffer, true)
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(url!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 3) != 0 {serializeString(startParam!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {themeParams!.serialize(buffer, true)}
                    serializeString(platform, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {replyTo!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 13) != 0 {sendAs!.serialize(buffer, true)}
                    return (FunctionDescription(name: "messages.requestWebView", parameters: [("flags", String(describing: flags)), ("peer", String(describing: peer)), ("bot", String(describing: bot)), ("url", String(describing: url)), ("startParam", String(describing: startParam)), ("themeParams", String(describing: themeParams)), ("platform", String(describing: platform)), ("replyTo", String(describing: replyTo)), ("sendAs", String(describing: sendAs))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.WebViewResult? in
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
                static func saveDraft(flags: Int32, replyTo: Api.InputReplyTo?, peer: Api.InputPeer, message: String, entities: [Api.MessageEntity]?, media: Api.InputMedia?, effect: Int64?, suggestedPost: Api.SuggestedPost?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1420701838)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 4) != 0 {replyTo!.serialize(buffer, true)}
                    peer.serialize(buffer, true)
                    serializeString(message, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 3) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(entities!.count))
                    for item in entities! {
                        item.serialize(buffer, true)
                    }}
                    if Int(flags) & Int(1 << 5) != 0 {media!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 7) != 0 {serializeInt64(effect!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 8) != 0 {suggestedPost!.serialize(buffer, true)}
                    return (FunctionDescription(name: "messages.saveDraft", parameters: [("flags", String(describing: flags)), ("replyTo", String(describing: replyTo)), ("peer", String(describing: peer)), ("message", String(describing: message)), ("entities", String(describing: entities)), ("media", String(describing: media)), ("effect", String(describing: effect)), ("suggestedPost", String(describing: suggestedPost))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
                static func savePreparedInlineMessage(flags: Int32, result: Api.InputBotInlineResult, userId: Api.InputUser, peerTypes: [Api.InlineQueryPeerType]?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.BotPreparedInlineMessage>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-232816849)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    result.serialize(buffer, true)
                    userId.serialize(buffer, true)
                    if Int(flags) & Int(1 << 0) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(peerTypes!.count))
                    for item in peerTypes! {
                        item.serialize(buffer, true)
                    }}
                    return (FunctionDescription(name: "messages.savePreparedInlineMessage", parameters: [("flags", String(describing: flags)), ("result", String(describing: result)), ("userId", String(describing: userId)), ("peerTypes", String(describing: peerTypes))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.BotPreparedInlineMessage? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.BotPreparedInlineMessage?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.BotPreparedInlineMessage
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
                static func search(flags: Int32, peer: Api.InputPeer, q: String, fromId: Api.InputPeer?, savedPeerId: Api.InputPeer?, savedReaction: [Api.Reaction]?, topMsgId: Int32?, filter: Api.MessagesFilter, minDate: Int32, maxDate: Int32, offsetId: Int32, addOffset: Int32, limit: Int32, maxId: Int32, minId: Int32, hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.Messages>) {
                    let buffer = Buffer()
                    buffer.appendInt32(703497338)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    serializeString(q, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {fromId!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 2) != 0 {savedPeerId!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 3) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(savedReaction!.count))
                    for item in savedReaction! {
                        item.serialize(buffer, true)
                    }}
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
                    return (FunctionDescription(name: "messages.search", parameters: [("flags", String(describing: flags)), ("peer", String(describing: peer)), ("q", String(describing: q)), ("fromId", String(describing: fromId)), ("savedPeerId", String(describing: savedPeerId)), ("savedReaction", String(describing: savedReaction)), ("topMsgId", String(describing: topMsgId)), ("filter", String(describing: filter)), ("minDate", String(describing: minDate)), ("maxDate", String(describing: maxDate)), ("offsetId", String(describing: offsetId)), ("addOffset", String(describing: addOffset)), ("limit", String(describing: limit)), ("maxId", String(describing: maxId)), ("minId", String(describing: minId)), ("hash", String(describing: hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.Messages? in
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
                static func searchCustomEmoji(emoticon: String, hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.EmojiList>) {
                    let buffer = Buffer()
                    buffer.appendInt32(739360983)
                    serializeString(emoticon, buffer: buffer, boxed: false)
                    serializeInt64(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.searchCustomEmoji", parameters: [("emoticon", String(describing: emoticon)), ("hash", String(describing: hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.EmojiList? in
                        let reader = BufferReader(buffer)
                        var result: Api.EmojiList?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.EmojiList
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func searchEmojiStickerSets(flags: Int32, q: String, hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.FoundStickerSets>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1833678516)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(q, buffer: buffer, boxed: false)
                    serializeInt64(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.searchEmojiStickerSets", parameters: [("flags", String(describing: flags)), ("q", String(describing: q)), ("hash", String(describing: hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.FoundStickerSets? in
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
                static func searchStickers(flags: Int32, q: String, emoticon: String, langCode: [String], offset: Int32, limit: Int32, hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.FoundStickers>) {
                    let buffer = Buffer()
                    buffer.appendInt32(699516522)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(q, buffer: buffer, boxed: false)
                    serializeString(emoticon, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(langCode.count))
                    for item in langCode {
                        serializeString(item, buffer: buffer, boxed: false)
                    }
                    serializeInt32(offset, buffer: buffer, boxed: false)
                    serializeInt32(limit, buffer: buffer, boxed: false)
                    serializeInt64(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.searchStickers", parameters: [("flags", String(describing: flags)), ("q", String(describing: q)), ("emoticon", String(describing: emoticon)), ("langCode", String(describing: langCode)), ("offset", String(describing: offset)), ("limit", String(describing: limit)), ("hash", String(describing: hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.FoundStickers? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.FoundStickers?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.FoundStickers
                        }
                        return result
                    })
                }
}
public extension Api.functions.messages {
                static func sendBotRequestedPeer(peer: Api.InputPeer, msgId: Int32, buttonId: Int32, requestedPeers: [Api.InputPeer]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1850552224)
                    peer.serialize(buffer, true)
                    serializeInt32(msgId, buffer: buffer, boxed: false)
                    serializeInt32(buttonId, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(requestedPeers.count))
                    for item in requestedPeers {
                        item.serialize(buffer, true)
                    }
                    return (FunctionDescription(name: "messages.sendBotRequestedPeer", parameters: [("peer", String(describing: peer)), ("msgId", String(describing: msgId)), ("buttonId", String(describing: buttonId)), ("requestedPeers", String(describing: requestedPeers))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
                static func sendInlineBotResult(flags: Int32, peer: Api.InputPeer, replyTo: Api.InputReplyTo?, randomId: Int64, queryId: Int64, id: String, scheduleDate: Int32?, sendAs: Api.InputPeer?, quickReplyShortcut: Api.InputQuickReplyShortcut?, allowPaidStars: Int64?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1060145594)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    if Int(flags) & Int(1 << 0) != 0 {replyTo!.serialize(buffer, true)}
                    serializeInt64(randomId, buffer: buffer, boxed: false)
                    serializeInt64(queryId, buffer: buffer, boxed: false)
                    serializeString(id, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 10) != 0 {serializeInt32(scheduleDate!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 13) != 0 {sendAs!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 17) != 0 {quickReplyShortcut!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 21) != 0 {serializeInt64(allowPaidStars!, buffer: buffer, boxed: false)}
                    return (FunctionDescription(name: "messages.sendInlineBotResult", parameters: [("flags", String(describing: flags)), ("peer", String(describing: peer)), ("replyTo", String(describing: replyTo)), ("randomId", String(describing: randomId)), ("queryId", String(describing: queryId)), ("id", String(describing: id)), ("scheduleDate", String(describing: scheduleDate)), ("sendAs", String(describing: sendAs)), ("quickReplyShortcut", String(describing: quickReplyShortcut)), ("allowPaidStars", String(describing: allowPaidStars))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
                static func sendMedia(flags: Int32, peer: Api.InputPeer, replyTo: Api.InputReplyTo?, media: Api.InputMedia, message: String, randomId: Int64, replyMarkup: Api.ReplyMarkup?, entities: [Api.MessageEntity]?, scheduleDate: Int32?, sendAs: Api.InputPeer?, quickReplyShortcut: Api.InputQuickReplyShortcut?, effect: Int64?, allowPaidStars: Int64?, suggestedPost: Api.SuggestedPost?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1403659839)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    if Int(flags) & Int(1 << 0) != 0 {replyTo!.serialize(buffer, true)}
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
                    if Int(flags) & Int(1 << 17) != 0 {quickReplyShortcut!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 18) != 0 {serializeInt64(effect!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 21) != 0 {serializeInt64(allowPaidStars!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 22) != 0 {suggestedPost!.serialize(buffer, true)}
                    return (FunctionDescription(name: "messages.sendMedia", parameters: [("flags", String(describing: flags)), ("peer", String(describing: peer)), ("replyTo", String(describing: replyTo)), ("media", String(describing: media)), ("message", String(describing: message)), ("randomId", String(describing: randomId)), ("replyMarkup", String(describing: replyMarkup)), ("entities", String(describing: entities)), ("scheduleDate", String(describing: scheduleDate)), ("sendAs", String(describing: sendAs)), ("quickReplyShortcut", String(describing: quickReplyShortcut)), ("effect", String(describing: effect)), ("allowPaidStars", String(describing: allowPaidStars)), ("suggestedPost", String(describing: suggestedPost))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
                static func sendMessage(flags: Int32, peer: Api.InputPeer, replyTo: Api.InputReplyTo?, message: String, randomId: Int64, replyMarkup: Api.ReplyMarkup?, entities: [Api.MessageEntity]?, scheduleDate: Int32?, sendAs: Api.InputPeer?, quickReplyShortcut: Api.InputQuickReplyShortcut?, effect: Int64?, allowPaidStars: Int64?, suggestedPost: Api.SuggestedPost?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-33170278)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    if Int(flags) & Int(1 << 0) != 0 {replyTo!.serialize(buffer, true)}
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
                    if Int(flags) & Int(1 << 17) != 0 {quickReplyShortcut!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 18) != 0 {serializeInt64(effect!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 21) != 0 {serializeInt64(allowPaidStars!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 22) != 0 {suggestedPost!.serialize(buffer, true)}
                    return (FunctionDescription(name: "messages.sendMessage", parameters: [("flags", String(describing: flags)), ("peer", String(describing: peer)), ("replyTo", String(describing: replyTo)), ("message", String(describing: message)), ("randomId", String(describing: randomId)), ("replyMarkup", String(describing: replyMarkup)), ("entities", String(describing: entities)), ("scheduleDate", String(describing: scheduleDate)), ("sendAs", String(describing: sendAs)), ("quickReplyShortcut", String(describing: quickReplyShortcut)), ("effect", String(describing: effect)), ("allowPaidStars", String(describing: allowPaidStars)), ("suggestedPost", String(describing: suggestedPost))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
                static func sendMultiMedia(flags: Int32, peer: Api.InputPeer, replyTo: Api.InputReplyTo?, multiMedia: [Api.InputSingleMedia], scheduleDate: Int32?, sendAs: Api.InputPeer?, quickReplyShortcut: Api.InputQuickReplyShortcut?, effect: Int64?, allowPaidStars: Int64?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(469278068)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    if Int(flags) & Int(1 << 0) != 0 {replyTo!.serialize(buffer, true)}
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(multiMedia.count))
                    for item in multiMedia {
                        item.serialize(buffer, true)
                    }
                    if Int(flags) & Int(1 << 10) != 0 {serializeInt32(scheduleDate!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 13) != 0 {sendAs!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 17) != 0 {quickReplyShortcut!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 18) != 0 {serializeInt64(effect!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 21) != 0 {serializeInt64(allowPaidStars!, buffer: buffer, boxed: false)}
                    return (FunctionDescription(name: "messages.sendMultiMedia", parameters: [("flags", String(describing: flags)), ("peer", String(describing: peer)), ("replyTo", String(describing: replyTo)), ("multiMedia", String(describing: multiMedia)), ("scheduleDate", String(describing: scheduleDate)), ("sendAs", String(describing: sendAs)), ("quickReplyShortcut", String(describing: quickReplyShortcut)), ("effect", String(describing: effect)), ("allowPaidStars", String(describing: allowPaidStars))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
                static func sendPaidReaction(flags: Int32, peer: Api.InputPeer, msgId: Int32, count: Int32, randomId: Int64, `private`: Api.PaidReactionPrivacy?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1488702288)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    serializeInt32(msgId, buffer: buffer, boxed: false)
                    serializeInt32(count, buffer: buffer, boxed: false)
                    serializeInt64(randomId, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {`private`!.serialize(buffer, true)}
                    return (FunctionDescription(name: "messages.sendPaidReaction", parameters: [("flags", String(describing: flags)), ("peer", String(describing: peer)), ("msgId", String(describing: msgId)), ("count", String(describing: count)), ("randomId", String(describing: randomId)), ("`private`", String(describing: `private`))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
                static func sendQuickReplyMessages(peer: Api.InputPeer, shortcutId: Int32, id: [Int32], randomId: [Int64]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1819610593)
                    peer.serialize(buffer, true)
                    serializeInt32(shortcutId, buffer: buffer, boxed: false)
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
                    return (FunctionDescription(name: "messages.sendQuickReplyMessages", parameters: [("peer", String(describing: peer)), ("shortcutId", String(describing: shortcutId)), ("id", String(describing: id)), ("randomId", String(describing: randomId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
                static func sendScreenshotNotification(peer: Api.InputPeer, replyTo: Api.InputReplyTo, randomId: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1589618665)
                    peer.serialize(buffer, true)
                    replyTo.serialize(buffer, true)
                    serializeInt64(randomId, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.sendScreenshotNotification", parameters: [("peer", String(describing: peer)), ("replyTo", String(describing: replyTo)), ("randomId", String(describing: randomId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
                static func setChatAvailableReactions(flags: Int32, peer: Api.InputPeer, availableReactions: Api.ChatReactions, reactionsLimit: Int32?, paidEnabled: Api.Bool?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-2041895551)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    availableReactions.serialize(buffer, true)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(reactionsLimit!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {paidEnabled!.serialize(buffer, true)}
                    return (FunctionDescription(name: "messages.setChatAvailableReactions", parameters: [("flags", String(describing: flags)), ("peer", String(describing: peer)), ("availableReactions", String(describing: availableReactions)), ("reactionsLimit", String(describing: reactionsLimit)), ("paidEnabled", String(describing: paidEnabled))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
                static func setChatWallPaper(flags: Int32, peer: Api.InputPeer, wallpaper: Api.InputWallPaper?, settings: Api.WallPaperSettings?, id: Int32?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1879389471)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    if Int(flags) & Int(1 << 0) != 0 {wallpaper!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 2) != 0 {settings!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt32(id!, buffer: buffer, boxed: false)}
                    return (FunctionDescription(name: "messages.setChatWallPaper", parameters: [("flags", String(describing: flags)), ("peer", String(describing: peer)), ("wallpaper", String(describing: wallpaper)), ("settings", String(describing: settings)), ("id", String(describing: id))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
                static func setDefaultHistoryTTL(period: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1632299963)
                    serializeInt32(period, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.setDefaultHistoryTTL", parameters: [("period", String(describing: period))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
                static func setInlineBotResults(flags: Int32, queryId: Int64, results: [Api.InputBotInlineResult], cacheTime: Int32, nextOffset: String?, switchPm: Api.InlineBotSwitchPM?, switchWebview: Api.InlineBotWebView?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1156406247)
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
                    if Int(flags) & Int(1 << 4) != 0 {switchWebview!.serialize(buffer, true)}
                    return (FunctionDescription(name: "messages.setInlineBotResults", parameters: [("flags", String(describing: flags)), ("queryId", String(describing: queryId)), ("results", String(describing: results)), ("cacheTime", String(describing: cacheTime)), ("nextOffset", String(describing: nextOffset)), ("switchPm", String(describing: switchPm)), ("switchWebview", String(describing: switchWebview))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
                static func toggleBotInAttachMenu(flags: Int32, bot: Api.InputUser, enabled: Api.Bool) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1777704297)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    bot.serialize(buffer, true)
                    enabled.serialize(buffer, true)
                    return (FunctionDescription(name: "messages.toggleBotInAttachMenu", parameters: [("flags", String(describing: flags)), ("bot", String(describing: bot)), ("enabled", String(describing: enabled))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
                static func toggleDialogFilterTags(enabled: Api.Bool) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-47326647)
                    enabled.serialize(buffer, true)
                    return (FunctionDescription(name: "messages.toggleDialogFilterTags", parameters: [("enabled", String(describing: enabled))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
                static func togglePaidReactionPrivacy(peer: Api.InputPeer, msgId: Int32, `private`: Api.PaidReactionPrivacy) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1129874869)
                    peer.serialize(buffer, true)
                    serializeInt32(msgId, buffer: buffer, boxed: false)
                    `private`.serialize(buffer, true)
                    return (FunctionDescription(name: "messages.togglePaidReactionPrivacy", parameters: [("peer", String(describing: peer)), ("msgId", String(describing: msgId)), ("`private`", String(describing: `private`))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
                static func togglePeerTranslations(flags: Int32, peer: Api.InputPeer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-461589127)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    return (FunctionDescription(name: "messages.togglePeerTranslations", parameters: [("flags", String(describing: flags)), ("peer", String(describing: peer))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
                static func toggleSavedDialogPin(flags: Int32, peer: Api.InputDialogPeer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1400783906)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    return (FunctionDescription(name: "messages.toggleSavedDialogPin", parameters: [("flags", String(describing: flags)), ("peer", String(describing: peer))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
                static func toggleSuggestedPostApproval(flags: Int32, peer: Api.InputPeer, msgId: Int32, scheduleDate: Int32?, rejectComment: String?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-2130229924)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    serializeInt32(msgId, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(scheduleDate!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeString(rejectComment!, buffer: buffer, boxed: false)}
                    return (FunctionDescription(name: "messages.toggleSuggestedPostApproval", parameters: [("flags", String(describing: flags)), ("peer", String(describing: peer)), ("msgId", String(describing: msgId)), ("scheduleDate", String(describing: scheduleDate)), ("rejectComment", String(describing: rejectComment))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
                static func toggleTodoCompleted(peer: Api.InputPeer, msgId: Int32, completed: [Int32], incompleted: [Int32]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-740282076)
                    peer.serialize(buffer, true)
                    serializeInt32(msgId, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(completed.count))
                    for item in completed {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(incompleted.count))
                    for item in incompleted {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    return (FunctionDescription(name: "messages.toggleTodoCompleted", parameters: [("peer", String(describing: peer)), ("msgId", String(describing: msgId)), ("completed", String(describing: completed)), ("incompleted", String(describing: incompleted))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
                static func translateText(flags: Int32, peer: Api.InputPeer?, id: [Int32]?, text: [Api.TextWithEntities]?, toLang: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.TranslatedText>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1662529584)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {peer!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 0) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(id!.count))
                    for item in id! {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }}
                    if Int(flags) & Int(1 << 1) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(text!.count))
                    for item in text! {
                        item.serialize(buffer, true)
                    }}
                    serializeString(toLang, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.translateText", parameters: [("flags", String(describing: flags)), ("peer", String(describing: peer)), ("id", String(describing: id)), ("text", String(describing: text)), ("toLang", String(describing: toLang))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.TranslatedText? in
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
                static func unpinAllMessages(flags: Int32, peer: Api.InputPeer, topMsgId: Int32?, savedPeerId: Api.InputPeer?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.AffectedHistory>) {
                    let buffer = Buffer()
                    buffer.appendInt32(103667527)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(topMsgId!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {savedPeerId!.serialize(buffer, true)}
                    return (FunctionDescription(name: "messages.unpinAllMessages", parameters: [("flags", String(describing: flags)), ("peer", String(describing: peer)), ("topMsgId", String(describing: topMsgId)), ("savedPeerId", String(describing: savedPeerId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.AffectedHistory? in
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
                static func updateSavedReactionTag(flags: Int32, reaction: Api.Reaction, title: String?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1613331948)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    reaction.serialize(buffer, true)
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(title!, buffer: buffer, boxed: false)}
                    return (FunctionDescription(name: "messages.updateSavedReactionTag", parameters: [("flags", String(describing: flags)), ("reaction", String(describing: reaction)), ("title", String(describing: title))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
                static func uploadMedia(flags: Int32, businessConnectionId: String?, peer: Api.InputPeer, media: Api.InputMedia) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.MessageMedia>) {
                    let buffer = Buffer()
                    buffer.appendInt32(345405816)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(businessConnectionId!, buffer: buffer, boxed: false)}
                    peer.serialize(buffer, true)
                    media.serialize(buffer, true)
                    return (FunctionDescription(name: "messages.uploadMedia", parameters: [("flags", String(describing: flags)), ("businessConnectionId", String(describing: businessConnectionId)), ("peer", String(describing: peer)), ("media", String(describing: media))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.MessageMedia? in
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
                static func viewSponsoredMessage(randomId: Buffer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(647902787)
                    serializeBytes(randomId, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "messages.viewSponsoredMessage", parameters: [("randomId", String(describing: randomId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
                static func applyGiftCode(slug: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-152934316)
                    serializeString(slug, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "payments.applyGiftCode", parameters: [("slug", String(describing: slug))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
                static func botCancelStarsSubscription(flags: Int32, userId: Api.InputUser, chargeId: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1845102114)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    userId.serialize(buffer, true)
                    serializeString(chargeId, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "payments.botCancelStarsSubscription", parameters: [("flags", String(describing: flags)), ("userId", String(describing: userId)), ("chargeId", String(describing: chargeId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
                static func canPurchaseStore(purpose: Api.InputStorePaymentPurpose) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1339842215)
                    purpose.serialize(buffer, true)
                    return (FunctionDescription(name: "payments.canPurchaseStore", parameters: [("purpose", String(describing: purpose))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
                static func changeStarsSubscription(flags: Int32, peer: Api.InputPeer, subscriptionId: String, canceled: Api.Bool?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-948500360)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    serializeString(subscriptionId, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {canceled!.serialize(buffer, true)}
                    return (FunctionDescription(name: "payments.changeStarsSubscription", parameters: [("flags", String(describing: flags)), ("peer", String(describing: peer)), ("subscriptionId", String(describing: subscriptionId)), ("canceled", String(describing: canceled))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
                static func checkGiftCode(slug: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.payments.CheckedGiftCode>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1907247935)
                    serializeString(slug, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "payments.checkGiftCode", parameters: [("slug", String(describing: slug))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.payments.CheckedGiftCode? in
                        let reader = BufferReader(buffer)
                        var result: Api.payments.CheckedGiftCode?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.payments.CheckedGiftCode
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
                static func connectStarRefBot(peer: Api.InputPeer, bot: Api.InputUser) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.payments.ConnectedStarRefBots>) {
                    let buffer = Buffer()
                    buffer.appendInt32(2127901834)
                    peer.serialize(buffer, true)
                    bot.serialize(buffer, true)
                    return (FunctionDescription(name: "payments.connectStarRefBot", parameters: [("peer", String(describing: peer)), ("bot", String(describing: bot))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.payments.ConnectedStarRefBots? in
                        let reader = BufferReader(buffer)
                        var result: Api.payments.ConnectedStarRefBots?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.payments.ConnectedStarRefBots
                        }
                        return result
                    })
                }
}
public extension Api.functions.payments {
                static func convertStarGift(stargift: Api.InputSavedStarGift) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1958676331)
                    stargift.serialize(buffer, true)
                    return (FunctionDescription(name: "payments.convertStarGift", parameters: [("stargift", String(describing: stargift))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
                static func editConnectedStarRefBot(flags: Int32, peer: Api.InputPeer, link: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.payments.ConnectedStarRefBots>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-453204829)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    serializeString(link, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "payments.editConnectedStarRefBot", parameters: [("flags", String(describing: flags)), ("peer", String(describing: peer)), ("link", String(describing: link))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.payments.ConnectedStarRefBots? in
                        let reader = BufferReader(buffer)
                        var result: Api.payments.ConnectedStarRefBots?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.payments.ConnectedStarRefBots
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
                static func fulfillStarsSubscription(peer: Api.InputPeer, subscriptionId: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-866391117)
                    peer.serialize(buffer, true)
                    serializeString(subscriptionId, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "payments.fulfillStarsSubscription", parameters: [("peer", String(describing: peer)), ("subscriptionId", String(describing: subscriptionId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
                static func getConnectedStarRefBot(peer: Api.InputPeer, bot: Api.InputUser) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.payments.ConnectedStarRefBots>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1210476304)
                    peer.serialize(buffer, true)
                    bot.serialize(buffer, true)
                    return (FunctionDescription(name: "payments.getConnectedStarRefBot", parameters: [("peer", String(describing: peer)), ("bot", String(describing: bot))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.payments.ConnectedStarRefBots? in
                        let reader = BufferReader(buffer)
                        var result: Api.payments.ConnectedStarRefBots?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.payments.ConnectedStarRefBots
                        }
                        return result
                    })
                }
}
public extension Api.functions.payments {
                static func getConnectedStarRefBots(flags: Int32, peer: Api.InputPeer, offsetDate: Int32?, offsetLink: String?, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.payments.ConnectedStarRefBots>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1483318611)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    if Int(flags) & Int(1 << 2) != 0 {serializeInt32(offsetDate!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeString(offsetLink!, buffer: buffer, boxed: false)}
                    serializeInt32(limit, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "payments.getConnectedStarRefBots", parameters: [("flags", String(describing: flags)), ("peer", String(describing: peer)), ("offsetDate", String(describing: offsetDate)), ("offsetLink", String(describing: offsetLink)), ("limit", String(describing: limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.payments.ConnectedStarRefBots? in
                        let reader = BufferReader(buffer)
                        var result: Api.payments.ConnectedStarRefBots?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.payments.ConnectedStarRefBots
                        }
                        return result
                    })
                }
}
public extension Api.functions.payments {
                static func getGiveawayInfo(peer: Api.InputPeer, msgId: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.payments.GiveawayInfo>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-198994907)
                    peer.serialize(buffer, true)
                    serializeInt32(msgId, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "payments.getGiveawayInfo", parameters: [("peer", String(describing: peer)), ("msgId", String(describing: msgId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.payments.GiveawayInfo? in
                        let reader = BufferReader(buffer)
                        var result: Api.payments.GiveawayInfo?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.payments.GiveawayInfo
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
                static func getPremiumGiftCodeOptions(flags: Int32, boostPeer: Api.InputPeer?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Api.PremiumGiftCodeOption]>) {
                    let buffer = Buffer()
                    buffer.appendInt32(660060756)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {boostPeer!.serialize(buffer, true)}
                    return (FunctionDescription(name: "payments.getPremiumGiftCodeOptions", parameters: [("flags", String(describing: flags)), ("boostPeer", String(describing: boostPeer))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> [Api.PremiumGiftCodeOption]? in
                        let reader = BufferReader(buffer)
                        var result: [Api.PremiumGiftCodeOption]?
                        if let _ = reader.readInt32() {
                            result = Api.parseVector(reader, elementSignature: 0, elementType: Api.PremiumGiftCodeOption.self)
                        }
                        return result
                    })
                }
}
public extension Api.functions.payments {
                static func getResaleStarGifts(flags: Int32, attributesHash: Int64?, giftId: Int64, attributes: [Api.StarGiftAttributeId]?, offset: String, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.payments.ResaleStarGifts>) {
                    let buffer = Buffer()
                    buffer.appendInt32(2053087798)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt64(attributesHash!, buffer: buffer, boxed: false)}
                    serializeInt64(giftId, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 3) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(attributes!.count))
                    for item in attributes! {
                        item.serialize(buffer, true)
                    }}
                    serializeString(offset, buffer: buffer, boxed: false)
                    serializeInt32(limit, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "payments.getResaleStarGifts", parameters: [("flags", String(describing: flags)), ("attributesHash", String(describing: attributesHash)), ("giftId", String(describing: giftId)), ("attributes", String(describing: attributes)), ("offset", String(describing: offset)), ("limit", String(describing: limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.payments.ResaleStarGifts? in
                        let reader = BufferReader(buffer)
                        var result: Api.payments.ResaleStarGifts?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.payments.ResaleStarGifts
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
                static func getSavedStarGift(stargift: [Api.InputSavedStarGift]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.payments.SavedStarGifts>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1269456634)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(stargift.count))
                    for item in stargift {
                        item.serialize(buffer, true)
                    }
                    return (FunctionDescription(name: "payments.getSavedStarGift", parameters: [("stargift", String(describing: stargift))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.payments.SavedStarGifts? in
                        let reader = BufferReader(buffer)
                        var result: Api.payments.SavedStarGifts?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.payments.SavedStarGifts
                        }
                        return result
                    })
                }
}
public extension Api.functions.payments {
                static func getSavedStarGifts(flags: Int32, peer: Api.InputPeer, offset: String, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.payments.SavedStarGifts>) {
                    let buffer = Buffer()
                    buffer.appendInt32(595791337)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    serializeString(offset, buffer: buffer, boxed: false)
                    serializeInt32(limit, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "payments.getSavedStarGifts", parameters: [("flags", String(describing: flags)), ("peer", String(describing: peer)), ("offset", String(describing: offset)), ("limit", String(describing: limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.payments.SavedStarGifts? in
                        let reader = BufferReader(buffer)
                        var result: Api.payments.SavedStarGifts?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.payments.SavedStarGifts
                        }
                        return result
                    })
                }
}
public extension Api.functions.payments {
                static func getStarGiftUpgradePreview(giftId: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.payments.StarGiftUpgradePreview>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1667580751)
                    serializeInt64(giftId, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "payments.getStarGiftUpgradePreview", parameters: [("giftId", String(describing: giftId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.payments.StarGiftUpgradePreview? in
                        let reader = BufferReader(buffer)
                        var result: Api.payments.StarGiftUpgradePreview?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.payments.StarGiftUpgradePreview
                        }
                        return result
                    })
                }
}
public extension Api.functions.payments {
                static func getStarGiftWithdrawalUrl(stargift: Api.InputSavedStarGift, password: Api.InputCheckPasswordSRP) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.payments.StarGiftWithdrawalUrl>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-798059608)
                    stargift.serialize(buffer, true)
                    password.serialize(buffer, true)
                    return (FunctionDescription(name: "payments.getStarGiftWithdrawalUrl", parameters: [("stargift", String(describing: stargift)), ("password", String(describing: password))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.payments.StarGiftWithdrawalUrl? in
                        let reader = BufferReader(buffer)
                        var result: Api.payments.StarGiftWithdrawalUrl?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.payments.StarGiftWithdrawalUrl
                        }
                        return result
                    })
                }
}
public extension Api.functions.payments {
                static func getStarGifts(hash: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.payments.StarGifts>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1000983152)
                    serializeInt32(hash, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "payments.getStarGifts", parameters: [("hash", String(describing: hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.payments.StarGifts? in
                        let reader = BufferReader(buffer)
                        var result: Api.payments.StarGifts?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.payments.StarGifts
                        }
                        return result
                    })
                }
}
public extension Api.functions.payments {
                static func getStarsGiftOptions(flags: Int32, userId: Api.InputUser?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Api.StarsGiftOption]>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-741774392)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {userId!.serialize(buffer, true)}
                    return (FunctionDescription(name: "payments.getStarsGiftOptions", parameters: [("flags", String(describing: flags)), ("userId", String(describing: userId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> [Api.StarsGiftOption]? in
                        let reader = BufferReader(buffer)
                        var result: [Api.StarsGiftOption]?
                        if let _ = reader.readInt32() {
                            result = Api.parseVector(reader, elementSignature: 0, elementType: Api.StarsGiftOption.self)
                        }
                        return result
                    })
                }
}
public extension Api.functions.payments {
                static func getStarsGiveawayOptions() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Api.StarsGiveawayOption]>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1122042562)
                    
                    return (FunctionDescription(name: "payments.getStarsGiveawayOptions", parameters: []), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> [Api.StarsGiveawayOption]? in
                        let reader = BufferReader(buffer)
                        var result: [Api.StarsGiveawayOption]?
                        if let _ = reader.readInt32() {
                            result = Api.parseVector(reader, elementSignature: 0, elementType: Api.StarsGiveawayOption.self)
                        }
                        return result
                    })
                }
}
public extension Api.functions.payments {
                static func getStarsRevenueAdsAccountUrl(peer: Api.InputPeer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.payments.StarsRevenueAdsAccountUrl>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-774377531)
                    peer.serialize(buffer, true)
                    return (FunctionDescription(name: "payments.getStarsRevenueAdsAccountUrl", parameters: [("peer", String(describing: peer))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.payments.StarsRevenueAdsAccountUrl? in
                        let reader = BufferReader(buffer)
                        var result: Api.payments.StarsRevenueAdsAccountUrl?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.payments.StarsRevenueAdsAccountUrl
                        }
                        return result
                    })
                }
}
public extension Api.functions.payments {
                static func getStarsRevenueStats(flags: Int32, peer: Api.InputPeer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.payments.StarsRevenueStats>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-652215594)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    return (FunctionDescription(name: "payments.getStarsRevenueStats", parameters: [("flags", String(describing: flags)), ("peer", String(describing: peer))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.payments.StarsRevenueStats? in
                        let reader = BufferReader(buffer)
                        var result: Api.payments.StarsRevenueStats?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.payments.StarsRevenueStats
                        }
                        return result
                    })
                }
}
public extension Api.functions.payments {
                static func getStarsRevenueWithdrawalUrl(flags: Int32, peer: Api.InputPeer, amount: Int64?, password: Api.InputCheckPasswordSRP) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.payments.StarsRevenueWithdrawalUrl>) {
                    let buffer = Buffer()
                    buffer.appendInt32(607378578)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt64(amount!, buffer: buffer, boxed: false)}
                    password.serialize(buffer, true)
                    return (FunctionDescription(name: "payments.getStarsRevenueWithdrawalUrl", parameters: [("flags", String(describing: flags)), ("peer", String(describing: peer)), ("amount", String(describing: amount)), ("password", String(describing: password))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.payments.StarsRevenueWithdrawalUrl? in
                        let reader = BufferReader(buffer)
                        var result: Api.payments.StarsRevenueWithdrawalUrl?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.payments.StarsRevenueWithdrawalUrl
                        }
                        return result
                    })
                }
}
public extension Api.functions.payments {
                static func getStarsStatus(flags: Int32, peer: Api.InputPeer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.payments.StarsStatus>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1319744447)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    return (FunctionDescription(name: "payments.getStarsStatus", parameters: [("flags", String(describing: flags)), ("peer", String(describing: peer))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.payments.StarsStatus? in
                        let reader = BufferReader(buffer)
                        var result: Api.payments.StarsStatus?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.payments.StarsStatus
                        }
                        return result
                    })
                }
}
public extension Api.functions.payments {
                static func getStarsSubscriptions(flags: Int32, peer: Api.InputPeer, offset: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.payments.StarsStatus>) {
                    let buffer = Buffer()
                    buffer.appendInt32(52761285)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    serializeString(offset, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "payments.getStarsSubscriptions", parameters: [("flags", String(describing: flags)), ("peer", String(describing: peer)), ("offset", String(describing: offset))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.payments.StarsStatus? in
                        let reader = BufferReader(buffer)
                        var result: Api.payments.StarsStatus?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.payments.StarsStatus
                        }
                        return result
                    })
                }
}
public extension Api.functions.payments {
                static func getStarsTopupOptions() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Api.StarsTopupOption]>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1072773165)
                    
                    return (FunctionDescription(name: "payments.getStarsTopupOptions", parameters: []), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> [Api.StarsTopupOption]? in
                        let reader = BufferReader(buffer)
                        var result: [Api.StarsTopupOption]?
                        if let _ = reader.readInt32() {
                            result = Api.parseVector(reader, elementSignature: 0, elementType: Api.StarsTopupOption.self)
                        }
                        return result
                    })
                }
}
public extension Api.functions.payments {
                static func getStarsTransactions(flags: Int32, subscriptionId: String?, peer: Api.InputPeer, offset: String, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.payments.StarsStatus>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1775912279)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 3) != 0 {serializeString(subscriptionId!, buffer: buffer, boxed: false)}
                    peer.serialize(buffer, true)
                    serializeString(offset, buffer: buffer, boxed: false)
                    serializeInt32(limit, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "payments.getStarsTransactions", parameters: [("flags", String(describing: flags)), ("subscriptionId", String(describing: subscriptionId)), ("peer", String(describing: peer)), ("offset", String(describing: offset)), ("limit", String(describing: limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.payments.StarsStatus? in
                        let reader = BufferReader(buffer)
                        var result: Api.payments.StarsStatus?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.payments.StarsStatus
                        }
                        return result
                    })
                }
}
public extension Api.functions.payments {
                static func getStarsTransactionsByID(flags: Int32, peer: Api.InputPeer, id: [Api.InputStarsTransaction]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.payments.StarsStatus>) {
                    let buffer = Buffer()
                    buffer.appendInt32(768218808)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(id.count))
                    for item in id {
                        item.serialize(buffer, true)
                    }
                    return (FunctionDescription(name: "payments.getStarsTransactionsByID", parameters: [("flags", String(describing: flags)), ("peer", String(describing: peer)), ("id", String(describing: id))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.payments.StarsStatus? in
                        let reader = BufferReader(buffer)
                        var result: Api.payments.StarsStatus?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.payments.StarsStatus
                        }
                        return result
                    })
                }
}
public extension Api.functions.payments {
                static func getSuggestedStarRefBots(flags: Int32, peer: Api.InputPeer, offset: String, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.payments.SuggestedStarRefBots>) {
                    let buffer = Buffer()
                    buffer.appendInt32(225134839)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    serializeString(offset, buffer: buffer, boxed: false)
                    serializeInt32(limit, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "payments.getSuggestedStarRefBots", parameters: [("flags", String(describing: flags)), ("peer", String(describing: peer)), ("offset", String(describing: offset)), ("limit", String(describing: limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.payments.SuggestedStarRefBots? in
                        let reader = BufferReader(buffer)
                        var result: Api.payments.SuggestedStarRefBots?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.payments.SuggestedStarRefBots
                        }
                        return result
                    })
                }
}
public extension Api.functions.payments {
                static func getUniqueStarGift(slug: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.payments.UniqueStarGift>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1583919758)
                    serializeString(slug, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "payments.getUniqueStarGift", parameters: [("slug", String(describing: slug))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.payments.UniqueStarGift? in
                        let reader = BufferReader(buffer)
                        var result: Api.payments.UniqueStarGift?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.payments.UniqueStarGift
                        }
                        return result
                    })
                }
}
public extension Api.functions.payments {
                static func launchPrepaidGiveaway(peer: Api.InputPeer, giveawayId: Int64, purpose: Api.InputStorePaymentPurpose) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1609928480)
                    peer.serialize(buffer, true)
                    serializeInt64(giveawayId, buffer: buffer, boxed: false)
                    purpose.serialize(buffer, true)
                    return (FunctionDescription(name: "payments.launchPrepaidGiveaway", parameters: [("peer", String(describing: peer)), ("giveawayId", String(describing: giveawayId)), ("purpose", String(describing: purpose))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
                static func refundStarsCharge(userId: Api.InputUser, chargeId: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(632196938)
                    userId.serialize(buffer, true)
                    serializeString(chargeId, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "payments.refundStarsCharge", parameters: [("userId", String(describing: userId)), ("chargeId", String(describing: chargeId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
                static func saveStarGift(flags: Int32, stargift: Api.InputSavedStarGift) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(707422588)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    stargift.serialize(buffer, true)
                    return (FunctionDescription(name: "payments.saveStarGift", parameters: [("flags", String(describing: flags)), ("stargift", String(describing: stargift))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
                static func sendStarsForm(formId: Int64, invoice: Api.InputInvoice) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.payments.PaymentResult>) {
                    let buffer = Buffer()
                    buffer.appendInt32(2040056084)
                    serializeInt64(formId, buffer: buffer, boxed: false)
                    invoice.serialize(buffer, true)
                    return (FunctionDescription(name: "payments.sendStarsForm", parameters: [("formId", String(describing: formId)), ("invoice", String(describing: invoice))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.payments.PaymentResult? in
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
                static func toggleChatStarGiftNotifications(flags: Int32, peer: Api.InputPeer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1626009505)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    return (FunctionDescription(name: "payments.toggleChatStarGiftNotifications", parameters: [("flags", String(describing: flags)), ("peer", String(describing: peer))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
                static func toggleStarGiftsPinnedToTop(peer: Api.InputPeer, stargift: [Api.InputSavedStarGift]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(353626032)
                    peer.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(stargift.count))
                    for item in stargift {
                        item.serialize(buffer, true)
                    }
                    return (FunctionDescription(name: "payments.toggleStarGiftsPinnedToTop", parameters: [("peer", String(describing: peer)), ("stargift", String(describing: stargift))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
                static func transferStarGift(stargift: Api.InputSavedStarGift, toId: Api.InputPeer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(2132285290)
                    stargift.serialize(buffer, true)
                    toId.serialize(buffer, true)
                    return (FunctionDescription(name: "payments.transferStarGift", parameters: [("stargift", String(describing: stargift)), ("toId", String(describing: toId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
                static func updateStarGiftPrice(stargift: Api.InputSavedStarGift, resellStars: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1001301217)
                    stargift.serialize(buffer, true)
                    serializeInt64(resellStars, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "payments.updateStarGiftPrice", parameters: [("stargift", String(describing: stargift)), ("resellStars", String(describing: resellStars))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
                static func upgradeStarGift(flags: Int32, stargift: Api.InputSavedStarGift) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1361648395)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    stargift.serialize(buffer, true)
                    return (FunctionDescription(name: "payments.upgradeStarGift", parameters: [("flags", String(describing: flags)), ("stargift", String(describing: stargift))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
                static func createConferenceCall(flags: Int32, randomId: Int32, publicKey: Int256?, block: Buffer?, params: Api.DataJSON?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(2097431739)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(randomId, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 3) != 0 {serializeInt256(publicKey!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 3) != 0 {serializeBytes(block!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 3) != 0 {params!.serialize(buffer, true)}
                    return (FunctionDescription(name: "phone.createConferenceCall", parameters: [("flags", String(describing: flags)), ("randomId", String(describing: randomId)), ("publicKey", String(describing: publicKey)), ("block", String(describing: block)), ("params", String(describing: params))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
                static func declineConferenceCallInvite(msgId: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1011325297)
                    serializeInt32(msgId, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "phone.declineConferenceCallInvite", parameters: [("msgId", String(describing: msgId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
                static func deleteConferenceCallParticipants(flags: Int32, call: Api.InputGroupCall, ids: [Int64], block: Buffer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1935276763)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    call.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(ids.count))
                    for item in ids {
                        serializeInt64(item, buffer: buffer, boxed: false)
                    }
                    serializeBytes(block, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "phone.deleteConferenceCallParticipants", parameters: [("flags", String(describing: flags)), ("call", String(describing: call)), ("ids", String(describing: ids)), ("block", String(describing: block))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
                static func getGroupCallChainBlocks(call: Api.InputGroupCall, subChainId: Int32, offset: Int32, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-291534682)
                    call.serialize(buffer, true)
                    serializeInt32(subChainId, buffer: buffer, boxed: false)
                    serializeInt32(offset, buffer: buffer, boxed: false)
                    serializeInt32(limit, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "phone.getGroupCallChainBlocks", parameters: [("call", String(describing: call)), ("subChainId", String(describing: subChainId)), ("offset", String(describing: offset)), ("limit", String(describing: limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
                static func inviteConferenceCallParticipant(flags: Int32, call: Api.InputGroupCall, userId: Api.InputUser) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1124981115)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    call.serialize(buffer, true)
                    userId.serialize(buffer, true)
                    return (FunctionDescription(name: "phone.inviteConferenceCallParticipant", parameters: [("flags", String(describing: flags)), ("call", String(describing: call)), ("userId", String(describing: userId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
                static func joinGroupCall(flags: Int32, call: Api.InputGroupCall, joinAs: Api.InputPeer, inviteHash: String?, publicKey: Int256?, block: Buffer?, params: Api.DataJSON) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1883951017)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    call.serialize(buffer, true)
                    joinAs.serialize(buffer, true)
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(inviteHash!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 3) != 0 {serializeInt256(publicKey!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 3) != 0 {serializeBytes(block!, buffer: buffer, boxed: false)}
                    params.serialize(buffer, true)
                    return (FunctionDescription(name: "phone.joinGroupCall", parameters: [("flags", String(describing: flags)), ("call", String(describing: call)), ("joinAs", String(describing: joinAs)), ("inviteHash", String(describing: inviteHash)), ("publicKey", String(describing: publicKey)), ("block", String(describing: block)), ("params", String(describing: params))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
                static func sendConferenceCallBroadcast(call: Api.InputGroupCall, block: Buffer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-965732096)
                    call.serialize(buffer, true)
                    serializeBytes(block, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "phone.sendConferenceCallBroadcast", parameters: [("call", String(describing: call)), ("block", String(describing: block))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
                static func updateProfilePhoto(flags: Int32, bot: Api.InputUser?, id: Api.InputPhoto) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.photos.Photo>) {
                    let buffer = Buffer()
                    buffer.appendInt32(166207545)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {bot!.serialize(buffer, true)}
                    id.serialize(buffer, true)
                    return (FunctionDescription(name: "photos.updateProfilePhoto", parameters: [("flags", String(describing: flags)), ("bot", String(describing: bot)), ("id", String(describing: id))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.photos.Photo? in
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
                static func uploadContactProfilePhoto(flags: Int32, userId: Api.InputUser, file: Api.InputFile?, video: Api.InputFile?, videoStartTs: Double?, videoEmojiMarkup: Api.VideoSize?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.photos.Photo>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-515093903)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    userId.serialize(buffer, true)
                    if Int(flags) & Int(1 << 0) != 0 {file!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 1) != 0 {video!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeDouble(videoStartTs!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 5) != 0 {videoEmojiMarkup!.serialize(buffer, true)}
                    return (FunctionDescription(name: "photos.uploadContactProfilePhoto", parameters: [("flags", String(describing: flags)), ("userId", String(describing: userId)), ("file", String(describing: file)), ("video", String(describing: video)), ("videoStartTs", String(describing: videoStartTs)), ("videoEmojiMarkup", String(describing: videoEmojiMarkup))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.photos.Photo? in
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
                static func uploadProfilePhoto(flags: Int32, bot: Api.InputUser?, file: Api.InputFile?, video: Api.InputFile?, videoStartTs: Double?, videoEmojiMarkup: Api.VideoSize?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.photos.Photo>) {
                    let buffer = Buffer()
                    buffer.appendInt32(59286453)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 5) != 0 {bot!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 0) != 0 {file!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 1) != 0 {video!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeDouble(videoStartTs!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 4) != 0 {videoEmojiMarkup!.serialize(buffer, true)}
                    return (FunctionDescription(name: "photos.uploadProfilePhoto", parameters: [("flags", String(describing: flags)), ("bot", String(describing: bot)), ("file", String(describing: file)), ("video", String(describing: video)), ("videoStartTs", String(describing: videoStartTs)), ("videoEmojiMarkup", String(describing: videoEmojiMarkup))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.photos.Photo? in
                        let reader = BufferReader(buffer)
                        var result: Api.photos.Photo?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.photos.Photo
                        }
                        return result
                    })
                }
}
public extension Api.functions.premium {
                static func applyBoost(flags: Int32, slots: [Int32]?, peer: Api.InputPeer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.premium.MyBoosts>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1803396934)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(slots!.count))
                    for item in slots! {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }}
                    peer.serialize(buffer, true)
                    return (FunctionDescription(name: "premium.applyBoost", parameters: [("flags", String(describing: flags)), ("slots", String(describing: slots)), ("peer", String(describing: peer))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.premium.MyBoosts? in
                        let reader = BufferReader(buffer)
                        var result: Api.premium.MyBoosts?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.premium.MyBoosts
                        }
                        return result
                    })
                }
}
public extension Api.functions.premium {
                static func getBoostsList(flags: Int32, peer: Api.InputPeer, offset: String, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.premium.BoostsList>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1626764896)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    serializeString(offset, buffer: buffer, boxed: false)
                    serializeInt32(limit, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "premium.getBoostsList", parameters: [("flags", String(describing: flags)), ("peer", String(describing: peer)), ("offset", String(describing: offset)), ("limit", String(describing: limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.premium.BoostsList? in
                        let reader = BufferReader(buffer)
                        var result: Api.premium.BoostsList?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.premium.BoostsList
                        }
                        return result
                    })
                }
}
public extension Api.functions.premium {
                static func getBoostsStatus(peer: Api.InputPeer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.premium.BoostsStatus>) {
                    let buffer = Buffer()
                    buffer.appendInt32(70197089)
                    peer.serialize(buffer, true)
                    return (FunctionDescription(name: "premium.getBoostsStatus", parameters: [("peer", String(describing: peer))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.premium.BoostsStatus? in
                        let reader = BufferReader(buffer)
                        var result: Api.premium.BoostsStatus?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.premium.BoostsStatus
                        }
                        return result
                    })
                }
}
public extension Api.functions.premium {
                static func getMyBoosts() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.premium.MyBoosts>) {
                    let buffer = Buffer()
                    buffer.appendInt32(199719754)
                    
                    return (FunctionDescription(name: "premium.getMyBoosts", parameters: []), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.premium.MyBoosts? in
                        let reader = BufferReader(buffer)
                        var result: Api.premium.MyBoosts?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.premium.MyBoosts
                        }
                        return result
                    })
                }
}
public extension Api.functions.premium {
                static func getUserBoosts(peer: Api.InputPeer, userId: Api.InputUser) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.premium.BoostsList>) {
                    let buffer = Buffer()
                    buffer.appendInt32(965037343)
                    peer.serialize(buffer, true)
                    userId.serialize(buffer, true)
                    return (FunctionDescription(name: "premium.getUserBoosts", parameters: [("peer", String(describing: peer)), ("userId", String(describing: userId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.premium.BoostsList? in
                        let reader = BufferReader(buffer)
                        var result: Api.premium.BoostsList?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.premium.BoostsList
                        }
                        return result
                    })
                }
}
public extension Api.functions.smsjobs {
                static func finishJob(flags: Int32, jobId: String, error: String?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1327415076)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(jobId, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(error!, buffer: buffer, boxed: false)}
                    return (FunctionDescription(name: "smsjobs.finishJob", parameters: [("flags", String(describing: flags)), ("jobId", String(describing: jobId)), ("error", String(describing: error))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.smsjobs {
                static func getSmsJob(jobId: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.SmsJob>) {
                    let buffer = Buffer()
                    buffer.appendInt32(2005766191)
                    serializeString(jobId, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "smsjobs.getSmsJob", parameters: [("jobId", String(describing: jobId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.SmsJob? in
                        let reader = BufferReader(buffer)
                        var result: Api.SmsJob?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.SmsJob
                        }
                        return result
                    })
                }
}
public extension Api.functions.smsjobs {
                static func getStatus() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.smsjobs.Status>) {
                    let buffer = Buffer()
                    buffer.appendInt32(279353576)
                    
                    return (FunctionDescription(name: "smsjobs.getStatus", parameters: []), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.smsjobs.Status? in
                        let reader = BufferReader(buffer)
                        var result: Api.smsjobs.Status?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.smsjobs.Status
                        }
                        return result
                    })
                }
}
public extension Api.functions.smsjobs {
                static func isEligibleToJoin() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.smsjobs.EligibilityToJoin>) {
                    let buffer = Buffer()
                    buffer.appendInt32(249313744)
                    
                    return (FunctionDescription(name: "smsjobs.isEligibleToJoin", parameters: []), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.smsjobs.EligibilityToJoin? in
                        let reader = BufferReader(buffer)
                        var result: Api.smsjobs.EligibilityToJoin?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.smsjobs.EligibilityToJoin
                        }
                        return result
                    })
                }
}
public extension Api.functions.smsjobs {
                static func join() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1488007635)
                    
                    return (FunctionDescription(name: "smsjobs.join", parameters: []), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.smsjobs {
                static func leave() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1734824589)
                    
                    return (FunctionDescription(name: "smsjobs.leave", parameters: []), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.smsjobs {
                static func updateSettings(flags: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(155164863)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "smsjobs.updateSettings", parameters: [("flags", String(describing: flags))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
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
                static func getMessagePublicForwards(channel: Api.InputChannel, msgId: Int32, offset: String, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.stats.PublicForwards>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1595212100)
                    channel.serialize(buffer, true)
                    serializeInt32(msgId, buffer: buffer, boxed: false)
                    serializeString(offset, buffer: buffer, boxed: false)
                    serializeInt32(limit, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "stats.getMessagePublicForwards", parameters: [("channel", String(describing: channel)), ("msgId", String(describing: msgId)), ("offset", String(describing: offset)), ("limit", String(describing: limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.stats.PublicForwards? in
                        let reader = BufferReader(buffer)
                        var result: Api.stats.PublicForwards?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.stats.PublicForwards
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
                static func getStoryPublicForwards(peer: Api.InputPeer, id: Int32, offset: String, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.stats.PublicForwards>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1505526026)
                    peer.serialize(buffer, true)
                    serializeInt32(id, buffer: buffer, boxed: false)
                    serializeString(offset, buffer: buffer, boxed: false)
                    serializeInt32(limit, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "stats.getStoryPublicForwards", parameters: [("peer", String(describing: peer)), ("id", String(describing: id)), ("offset", String(describing: offset)), ("limit", String(describing: limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.stats.PublicForwards? in
                        let reader = BufferReader(buffer)
                        var result: Api.stats.PublicForwards?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.stats.PublicForwards
                        }
                        return result
                    })
                }
}
public extension Api.functions.stats {
                static func getStoryStats(flags: Int32, peer: Api.InputPeer, id: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.stats.StoryStats>) {
                    let buffer = Buffer()
                    buffer.appendInt32(927985472)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    serializeInt32(id, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "stats.getStoryStats", parameters: [("flags", String(describing: flags)), ("peer", String(describing: peer)), ("id", String(describing: id))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.stats.StoryStats? in
                        let reader = BufferReader(buffer)
                        var result: Api.stats.StoryStats?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.stats.StoryStats
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
                static func changeSticker(flags: Int32, sticker: Api.InputDocument, emoji: String?, maskCoords: Api.MaskCoords?, keywords: String?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.StickerSet>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-179077444)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    sticker.serialize(buffer, true)
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(emoji!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {maskCoords!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeString(keywords!, buffer: buffer, boxed: false)}
                    return (FunctionDescription(name: "stickers.changeSticker", parameters: [("flags", String(describing: flags)), ("sticker", String(describing: sticker)), ("emoji", String(describing: emoji)), ("maskCoords", String(describing: maskCoords)), ("keywords", String(describing: keywords))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.StickerSet? in
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
                static func deleteStickerSet(stickerset: Api.InputStickerSet) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-2022685804)
                    stickerset.serialize(buffer, true)
                    return (FunctionDescription(name: "stickers.deleteStickerSet", parameters: [("stickerset", String(describing: stickerset))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
                static func renameStickerSet(stickerset: Api.InputStickerSet, title: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.StickerSet>) {
                    let buffer = Buffer()
                    buffer.appendInt32(306912256)
                    stickerset.serialize(buffer, true)
                    serializeString(title, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "stickers.renameStickerSet", parameters: [("stickerset", String(describing: stickerset)), ("title", String(describing: title))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.StickerSet? in
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
                static func replaceSticker(sticker: Api.InputDocument, newSticker: Api.InputStickerSetItem) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.StickerSet>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1184253338)
                    sticker.serialize(buffer, true)
                    newSticker.serialize(buffer, true)
                    return (FunctionDescription(name: "stickers.replaceSticker", parameters: [("sticker", String(describing: sticker)), ("newSticker", String(describing: newSticker))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.StickerSet? in
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
                static func setStickerSetThumb(flags: Int32, stickerset: Api.InputStickerSet, thumb: Api.InputDocument?, thumbDocumentId: Int64?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.StickerSet>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1486204014)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    stickerset.serialize(buffer, true)
                    if Int(flags) & Int(1 << 0) != 0 {thumb!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt64(thumbDocumentId!, buffer: buffer, boxed: false)}
                    return (FunctionDescription(name: "stickers.setStickerSetThumb", parameters: [("flags", String(describing: flags)), ("stickerset", String(describing: stickerset)), ("thumb", String(describing: thumb)), ("thumbDocumentId", String(describing: thumbDocumentId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.StickerSet? in
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
public extension Api.functions.stories {
                static func activateStealthMode(flags: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1471926630)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "stories.activateStealthMode", parameters: [("flags", String(describing: flags))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
}
public extension Api.functions.stories {
                static func canSendStory(peer: Api.InputPeer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.stories.CanSendStoryCount>) {
                    let buffer = Buffer()
                    buffer.appendInt32(820732912)
                    peer.serialize(buffer, true)
                    return (FunctionDescription(name: "stories.canSendStory", parameters: [("peer", String(describing: peer))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.stories.CanSendStoryCount? in
                        let reader = BufferReader(buffer)
                        var result: Api.stories.CanSendStoryCount?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.stories.CanSendStoryCount
                        }
                        return result
                    })
                }
}
public extension Api.functions.stories {
                static func deleteStories(peer: Api.InputPeer, id: [Int32]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Int32]>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1369842849)
                    peer.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(id.count))
                    for item in id {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    return (FunctionDescription(name: "stories.deleteStories", parameters: [("peer", String(describing: peer)), ("id", String(describing: id))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> [Int32]? in
                        let reader = BufferReader(buffer)
                        var result: [Int32]?
                        if let _ = reader.readInt32() {
                            result = Api.parseVector(reader, elementSignature: -1471112230, elementType: Int32.self)
                        }
                        return result
                    })
                }
}
public extension Api.functions.stories {
                static func editStory(flags: Int32, peer: Api.InputPeer, id: Int32, media: Api.InputMedia?, mediaAreas: [Api.MediaArea]?, caption: String?, entities: [Api.MessageEntity]?, privacyRules: [Api.InputPrivacyRule]?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1249658298)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    serializeInt32(id, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {media!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 3) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(mediaAreas!.count))
                    for item in mediaAreas! {
                        item.serialize(buffer, true)
                    }}
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(caption!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(entities!.count))
                    for item in entities! {
                        item.serialize(buffer, true)
                    }}
                    if Int(flags) & Int(1 << 2) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(privacyRules!.count))
                    for item in privacyRules! {
                        item.serialize(buffer, true)
                    }}
                    return (FunctionDescription(name: "stories.editStory", parameters: [("flags", String(describing: flags)), ("peer", String(describing: peer)), ("id", String(describing: id)), ("media", String(describing: media)), ("mediaAreas", String(describing: mediaAreas)), ("caption", String(describing: caption)), ("entities", String(describing: entities)), ("privacyRules", String(describing: privacyRules))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
}
public extension Api.functions.stories {
                static func exportStoryLink(peer: Api.InputPeer, id: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.ExportedStoryLink>) {
                    let buffer = Buffer()
                    buffer.appendInt32(2072899360)
                    peer.serialize(buffer, true)
                    serializeInt32(id, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "stories.exportStoryLink", parameters: [("peer", String(describing: peer)), ("id", String(describing: id))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.ExportedStoryLink? in
                        let reader = BufferReader(buffer)
                        var result: Api.ExportedStoryLink?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.ExportedStoryLink
                        }
                        return result
                    })
                }
}
public extension Api.functions.stories {
                static func getAllReadPeerStories() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1688541191)
                    
                    return (FunctionDescription(name: "stories.getAllReadPeerStories", parameters: []), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
}
public extension Api.functions.stories {
                static func getAllStories(flags: Int32, state: String?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.stories.AllStories>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-290400731)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(state!, buffer: buffer, boxed: false)}
                    return (FunctionDescription(name: "stories.getAllStories", parameters: [("flags", String(describing: flags)), ("state", String(describing: state))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.stories.AllStories? in
                        let reader = BufferReader(buffer)
                        var result: Api.stories.AllStories?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.stories.AllStories
                        }
                        return result
                    })
                }
}
public extension Api.functions.stories {
                static func getChatsToSend() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.Chats>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1519744160)
                    
                    return (FunctionDescription(name: "stories.getChatsToSend", parameters: []), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.Chats? in
                        let reader = BufferReader(buffer)
                        var result: Api.messages.Chats?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.messages.Chats
                        }
                        return result
                    })
                }
}
public extension Api.functions.stories {
                static func getPeerMaxIDs(id: [Api.InputPeer]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Int32]>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1398375363)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(id.count))
                    for item in id {
                        item.serialize(buffer, true)
                    }
                    return (FunctionDescription(name: "stories.getPeerMaxIDs", parameters: [("id", String(describing: id))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> [Int32]? in
                        let reader = BufferReader(buffer)
                        var result: [Int32]?
                        if let _ = reader.readInt32() {
                            result = Api.parseVector(reader, elementSignature: -1471112230, elementType: Int32.self)
                        }
                        return result
                    })
                }
}
public extension Api.functions.stories {
                static func getPeerStories(peer: Api.InputPeer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.stories.PeerStories>) {
                    let buffer = Buffer()
                    buffer.appendInt32(743103056)
                    peer.serialize(buffer, true)
                    return (FunctionDescription(name: "stories.getPeerStories", parameters: [("peer", String(describing: peer))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.stories.PeerStories? in
                        let reader = BufferReader(buffer)
                        var result: Api.stories.PeerStories?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.stories.PeerStories
                        }
                        return result
                    })
                }
}
public extension Api.functions.stories {
                static func getPinnedStories(peer: Api.InputPeer, offsetId: Int32, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.stories.Stories>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1478600156)
                    peer.serialize(buffer, true)
                    serializeInt32(offsetId, buffer: buffer, boxed: false)
                    serializeInt32(limit, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "stories.getPinnedStories", parameters: [("peer", String(describing: peer)), ("offsetId", String(describing: offsetId)), ("limit", String(describing: limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.stories.Stories? in
                        let reader = BufferReader(buffer)
                        var result: Api.stories.Stories?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.stories.Stories
                        }
                        return result
                    })
                }
}
public extension Api.functions.stories {
                static func getStoriesArchive(peer: Api.InputPeer, offsetId: Int32, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.stories.Stories>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1271586794)
                    peer.serialize(buffer, true)
                    serializeInt32(offsetId, buffer: buffer, boxed: false)
                    serializeInt32(limit, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "stories.getStoriesArchive", parameters: [("peer", String(describing: peer)), ("offsetId", String(describing: offsetId)), ("limit", String(describing: limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.stories.Stories? in
                        let reader = BufferReader(buffer)
                        var result: Api.stories.Stories?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.stories.Stories
                        }
                        return result
                    })
                }
}
public extension Api.functions.stories {
                static func getStoriesByID(peer: Api.InputPeer, id: [Int32]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.stories.Stories>) {
                    let buffer = Buffer()
                    buffer.appendInt32(1467271796)
                    peer.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(id.count))
                    for item in id {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    return (FunctionDescription(name: "stories.getStoriesByID", parameters: [("peer", String(describing: peer)), ("id", String(describing: id))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.stories.Stories? in
                        let reader = BufferReader(buffer)
                        var result: Api.stories.Stories?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.stories.Stories
                        }
                        return result
                    })
                }
}
public extension Api.functions.stories {
                static func getStoriesViews(peer: Api.InputPeer, id: [Int32]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.stories.StoryViews>) {
                    let buffer = Buffer()
                    buffer.appendInt32(685862088)
                    peer.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(id.count))
                    for item in id {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    return (FunctionDescription(name: "stories.getStoriesViews", parameters: [("peer", String(describing: peer)), ("id", String(describing: id))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.stories.StoryViews? in
                        let reader = BufferReader(buffer)
                        var result: Api.stories.StoryViews?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.stories.StoryViews
                        }
                        return result
                    })
                }
}
public extension Api.functions.stories {
                static func getStoryReactionsList(flags: Int32, peer: Api.InputPeer, id: Int32, reaction: Api.Reaction?, offset: String?, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.stories.StoryReactionsList>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1179482081)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    serializeInt32(id, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {reaction!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(offset!, buffer: buffer, boxed: false)}
                    serializeInt32(limit, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "stories.getStoryReactionsList", parameters: [("flags", String(describing: flags)), ("peer", String(describing: peer)), ("id", String(describing: id)), ("reaction", String(describing: reaction)), ("offset", String(describing: offset)), ("limit", String(describing: limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.stories.StoryReactionsList? in
                        let reader = BufferReader(buffer)
                        var result: Api.stories.StoryReactionsList?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.stories.StoryReactionsList
                        }
                        return result
                    })
                }
}
public extension Api.functions.stories {
                static func getStoryViewsList(flags: Int32, peer: Api.InputPeer, q: String?, id: Int32, offset: String, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.stories.StoryViewsList>) {
                    let buffer = Buffer()
                    buffer.appendInt32(2127707223)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(q!, buffer: buffer, boxed: false)}
                    serializeInt32(id, buffer: buffer, boxed: false)
                    serializeString(offset, buffer: buffer, boxed: false)
                    serializeInt32(limit, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "stories.getStoryViewsList", parameters: [("flags", String(describing: flags)), ("peer", String(describing: peer)), ("q", String(describing: q)), ("id", String(describing: id)), ("offset", String(describing: offset)), ("limit", String(describing: limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.stories.StoryViewsList? in
                        let reader = BufferReader(buffer)
                        var result: Api.stories.StoryViewsList?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.stories.StoryViewsList
                        }
                        return result
                    })
                }
}
public extension Api.functions.stories {
                static func incrementStoryViews(peer: Api.InputPeer, id: [Int32]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1308456197)
                    peer.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(id.count))
                    for item in id {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    return (FunctionDescription(name: "stories.incrementStoryViews", parameters: [("peer", String(describing: peer)), ("id", String(describing: id))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.stories {
                static func readStories(peer: Api.InputPeer, maxId: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Int32]>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1521034552)
                    peer.serialize(buffer, true)
                    serializeInt32(maxId, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "stories.readStories", parameters: [("peer", String(describing: peer)), ("maxId", String(describing: maxId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> [Int32]? in
                        let reader = BufferReader(buffer)
                        var result: [Int32]?
                        if let _ = reader.readInt32() {
                            result = Api.parseVector(reader, elementSignature: -1471112230, elementType: Int32.self)
                        }
                        return result
                    })
                }
}
public extension Api.functions.stories {
                static func report(peer: Api.InputPeer, id: [Int32], option: Buffer, message: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.ReportResult>) {
                    let buffer = Buffer()
                    buffer.appendInt32(433646405)
                    peer.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(id.count))
                    for item in id {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    serializeBytes(option, buffer: buffer, boxed: false)
                    serializeString(message, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "stories.report", parameters: [("peer", String(describing: peer)), ("id", String(describing: id)), ("option", String(describing: option)), ("message", String(describing: message))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.ReportResult? in
                        let reader = BufferReader(buffer)
                        var result: Api.ReportResult?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.ReportResult
                        }
                        return result
                    })
                }
}
public extension Api.functions.stories {
                static func searchPosts(flags: Int32, hashtag: String?, area: Api.MediaArea?, peer: Api.InputPeer?, offset: String, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.stories.FoundStories>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-780072697)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(hashtag!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {area!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 2) != 0 {peer!.serialize(buffer, true)}
                    serializeString(offset, buffer: buffer, boxed: false)
                    serializeInt32(limit, buffer: buffer, boxed: false)
                    return (FunctionDescription(name: "stories.searchPosts", parameters: [("flags", String(describing: flags)), ("hashtag", String(describing: hashtag)), ("area", String(describing: area)), ("peer", String(describing: peer)), ("offset", String(describing: offset)), ("limit", String(describing: limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.stories.FoundStories? in
                        let reader = BufferReader(buffer)
                        var result: Api.stories.FoundStories?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.stories.FoundStories
                        }
                        return result
                    })
                }
}
public extension Api.functions.stories {
                static func sendReaction(flags: Int32, peer: Api.InputPeer, storyId: Int32, reaction: Api.Reaction) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(2144810674)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    serializeInt32(storyId, buffer: buffer, boxed: false)
                    reaction.serialize(buffer, true)
                    return (FunctionDescription(name: "stories.sendReaction", parameters: [("flags", String(describing: flags)), ("peer", String(describing: peer)), ("storyId", String(describing: storyId)), ("reaction", String(describing: reaction))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
}
public extension Api.functions.stories {
                static func sendStory(flags: Int32, peer: Api.InputPeer, media: Api.InputMedia, mediaAreas: [Api.MediaArea]?, caption: String?, entities: [Api.MessageEntity]?, privacyRules: [Api.InputPrivacyRule], randomId: Int64, period: Int32?, fwdFromId: Api.InputPeer?, fwdFromStory: Int32?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-454661813)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    media.serialize(buffer, true)
                    if Int(flags) & Int(1 << 5) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(mediaAreas!.count))
                    for item in mediaAreas! {
                        item.serialize(buffer, true)
                    }}
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(caption!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(entities!.count))
                    for item in entities! {
                        item.serialize(buffer, true)
                    }}
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(privacyRules.count))
                    for item in privacyRules {
                        item.serialize(buffer, true)
                    }
                    serializeInt64(randomId, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 3) != 0 {serializeInt32(period!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 6) != 0 {fwdFromId!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 6) != 0 {serializeInt32(fwdFromStory!, buffer: buffer, boxed: false)}
                    return (FunctionDescription(name: "stories.sendStory", parameters: [("flags", String(describing: flags)), ("peer", String(describing: peer)), ("media", String(describing: media)), ("mediaAreas", String(describing: mediaAreas)), ("caption", String(describing: caption)), ("entities", String(describing: entities)), ("privacyRules", String(describing: privacyRules)), ("randomId", String(describing: randomId)), ("period", String(describing: period)), ("fwdFromId", String(describing: fwdFromId)), ("fwdFromStory", String(describing: fwdFromStory))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
                        let reader = BufferReader(buffer)
                        var result: Api.Updates?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Updates
                        }
                        return result
                    })
                }
}
public extension Api.functions.stories {
                static func toggleAllStoriesHidden(hidden: Api.Bool) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(2082822084)
                    hidden.serialize(buffer, true)
                    return (FunctionDescription(name: "stories.toggleAllStoriesHidden", parameters: [("hidden", String(describing: hidden))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.stories {
                static func togglePeerStoriesHidden(peer: Api.InputPeer, hidden: Api.Bool) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1123805756)
                    peer.serialize(buffer, true)
                    hidden.serialize(buffer, true)
                    return (FunctionDescription(name: "stories.togglePeerStoriesHidden", parameters: [("peer", String(describing: peer)), ("hidden", String(describing: hidden))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
                        }
                        return result
                    })
                }
}
public extension Api.functions.stories {
                static func togglePinned(peer: Api.InputPeer, id: [Int32], pinned: Api.Bool) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Int32]>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-1703566865)
                    peer.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(id.count))
                    for item in id {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    pinned.serialize(buffer, true)
                    return (FunctionDescription(name: "stories.togglePinned", parameters: [("peer", String(describing: peer)), ("id", String(describing: id)), ("pinned", String(describing: pinned))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> [Int32]? in
                        let reader = BufferReader(buffer)
                        var result: [Int32]?
                        if let _ = reader.readInt32() {
                            result = Api.parseVector(reader, elementSignature: -1471112230, elementType: Int32.self)
                        }
                        return result
                    })
                }
}
public extension Api.functions.stories {
                static func togglePinnedToTop(peer: Api.InputPeer, id: [Int32]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
                    let buffer = Buffer()
                    buffer.appendInt32(187268763)
                    peer.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(id.count))
                    for item in id {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    return (FunctionDescription(name: "stories.togglePinnedToTop", parameters: [("peer", String(describing: peer)), ("id", String(describing: id))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
                        let reader = BufferReader(buffer)
                        var result: Api.Bool?
                        if let signature = reader.readInt32() {
                            result = Api.parse(reader, signature: signature) as? Api.Bool
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
                static func getDifference(flags: Int32, pts: Int32, ptsLimit: Int32?, ptsTotalLimit: Int32?, date: Int32, qts: Int32, qtsLimit: Int32?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.updates.Difference>) {
                    let buffer = Buffer()
                    buffer.appendInt32(432207715)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(pts, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt32(ptsLimit!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(ptsTotalLimit!, buffer: buffer, boxed: false)}
                    serializeInt32(date, buffer: buffer, boxed: false)
                    serializeInt32(qts, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 2) != 0 {serializeInt32(qtsLimit!, buffer: buffer, boxed: false)}
                    return (FunctionDescription(name: "updates.getDifference", parameters: [("flags", String(describing: flags)), ("pts", String(describing: pts)), ("ptsLimit", String(describing: ptsLimit)), ("ptsTotalLimit", String(describing: ptsTotalLimit)), ("date", String(describing: date)), ("qts", String(describing: qts)), ("qtsLimit", String(describing: qtsLimit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.updates.Difference? in
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
                static func getRequirementsToContact(id: [Api.InputUser]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Api.RequirementToContact]>) {
                    let buffer = Buffer()
                    buffer.appendInt32(-660962397)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(id.count))
                    for item in id {
                        item.serialize(buffer, true)
                    }
                    return (FunctionDescription(name: "users.getRequirementsToContact", parameters: [("id", String(describing: id))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> [Api.RequirementToContact]? in
                        let reader = BufferReader(buffer)
                        var result: [Api.RequirementToContact]?
                        if let _ = reader.readInt32() {
                            result = Api.parseVector(reader, elementSignature: 0, elementType: Api.RequirementToContact.self)
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
