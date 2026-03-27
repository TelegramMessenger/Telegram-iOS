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
        return (FunctionDescription(name: "account.acceptAuthorization", parameters: [("botId", FunctionParameterDescription(botId)), ("scope", FunctionParameterDescription(scope)), ("publicKey", FunctionParameterDescription(publicKey)), ("valueHashes", FunctionParameterDescription(valueHashes)), ("credentials", FunctionParameterDescription(credentials))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        if Int(flags) & Int(1 << 0) != 0 {
            encryptedRequestsDisabled!.serialize(buffer, true)
        }
        if Int(flags) & Int(1 << 1) != 0 {
            callRequestsDisabled!.serialize(buffer, true)
        }
        return (FunctionDescription(name: "account.changeAuthorizationSettings", parameters: [("flags", FunctionParameterDescription(flags)), ("hash", FunctionParameterDescription(hash)), ("encryptedRequestsDisabled", FunctionParameterDescription(encryptedRequestsDisabled)), ("callRequestsDisabled", FunctionParameterDescription(callRequestsDisabled))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "account.changePhone", parameters: [("phoneNumber", FunctionParameterDescription(phoneNumber)), ("phoneCodeHash", FunctionParameterDescription(phoneCodeHash)), ("phoneCode", FunctionParameterDescription(phoneCode))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.User? in
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
        return (FunctionDescription(name: "account.checkUsername", parameters: [("username", FunctionParameterDescription(username))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "account.confirmPasswordEmail", parameters: [("code", FunctionParameterDescription(code))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "account.confirmPhone", parameters: [("phoneCodeHash", FunctionParameterDescription(phoneCodeHash)), ("phoneCode", FunctionParameterDescription(phoneCode))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "account.createBusinessChatLink", parameters: [("link", FunctionParameterDescription(link))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.BusinessChatLink? in
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
        if Int(flags) & Int(1 << 2) != 0 {
            document!.serialize(buffer, true)
        }
        if Int(flags) & Int(1 << 3) != 0 {
            buffer.appendInt32(481674261)
            buffer.appendInt32(Int32(settings!.count))
            for item in settings! {
                item.serialize(buffer, true)
            }
        }
        return (FunctionDescription(name: "account.createTheme", parameters: [("flags", FunctionParameterDescription(flags)), ("slug", FunctionParameterDescription(slug)), ("title", FunctionParameterDescription(title)), ("document", FunctionParameterDescription(document)), ("settings", FunctionParameterDescription(settings))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Theme? in
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
        if Int(flags) & Int(1 << 0) != 0 {
            password!.serialize(buffer, true)
        }
        return (FunctionDescription(name: "account.deleteAccount", parameters: [("flags", FunctionParameterDescription(flags)), ("reason", FunctionParameterDescription(reason)), ("password", FunctionParameterDescription(password))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "account.deleteBusinessChatLink", parameters: [("slug", FunctionParameterDescription(slug))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
    static func deletePasskey(id: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let buffer = Buffer()
        buffer.appendInt32(-172665281)
        serializeString(id, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "account.deletePasskey", parameters: [("id", FunctionParameterDescription(id))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "account.deleteSecureValue", parameters: [("types", FunctionParameterDescription(types))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "account.disablePeerConnectedBot", parameters: [("peer", FunctionParameterDescription(peer))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "account.editBusinessChatLink", parameters: [("slug", FunctionParameterDescription(slug)), ("link", FunctionParameterDescription(link))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.BusinessChatLink? in
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
        return (FunctionDescription(name: "account.finishTakeoutSession", parameters: [("flags", FunctionParameterDescription(flags))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "account.getAuthorizationForm", parameters: [("botId", FunctionParameterDescription(botId)), ("scope", FunctionParameterDescription(scope)), ("publicKey", FunctionParameterDescription(publicKey))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.account.AuthorizationForm? in
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
        return (FunctionDescription(name: "account.getBotBusinessConnection", parameters: [("connectionId", FunctionParameterDescription(connectionId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        return (FunctionDescription(name: "account.getChannelDefaultEmojiStatuses", parameters: [("hash", FunctionParameterDescription(hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.account.EmojiStatuses? in
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
        return (FunctionDescription(name: "account.getChannelRestrictedStatusEmojis", parameters: [("hash", FunctionParameterDescription(hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.EmojiList? in
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
        return (FunctionDescription(name: "account.getChatThemes", parameters: [("hash", FunctionParameterDescription(hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.account.Themes? in
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
        return (FunctionDescription(name: "account.getCollectibleEmojiStatuses", parameters: [("hash", FunctionParameterDescription(hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.account.EmojiStatuses? in
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
        return (FunctionDescription(name: "account.getDefaultBackgroundEmojis", parameters: [("hash", FunctionParameterDescription(hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.EmojiList? in
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
        return (FunctionDescription(name: "account.getDefaultEmojiStatuses", parameters: [("hash", FunctionParameterDescription(hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.account.EmojiStatuses? in
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
        return (FunctionDescription(name: "account.getDefaultGroupPhotoEmojis", parameters: [("hash", FunctionParameterDescription(hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.EmojiList? in
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
        return (FunctionDescription(name: "account.getDefaultProfilePhotoEmojis", parameters: [("hash", FunctionParameterDescription(hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.EmojiList? in
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
        return (FunctionDescription(name: "account.getMultiWallPapers", parameters: [("wallpapers", FunctionParameterDescription(wallpapers))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> [Api.WallPaper]? in
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
        if Int(flags) & Int(1 << 0) != 0 {
            peer!.serialize(buffer, true)
        }
        return (FunctionDescription(name: "account.getNotifyExceptions", parameters: [("flags", FunctionParameterDescription(flags)), ("peer", FunctionParameterDescription(peer))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        return (FunctionDescription(name: "account.getNotifySettings", parameters: [("peer", FunctionParameterDescription(peer))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.PeerNotifySettings? in
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
        if Int(flags) & Int(1 << 0) != 0 {
            parentPeer!.serialize(buffer, true)
        }
        userId.serialize(buffer, true)
        return (FunctionDescription(name: "account.getPaidMessagesRevenue", parameters: [("flags", FunctionParameterDescription(flags)), ("parentPeer", FunctionParameterDescription(parentPeer)), ("userId", FunctionParameterDescription(userId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.account.PaidMessagesRevenue? in
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
    static func getPasskeys() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.account.Passkeys>) {
        let buffer = Buffer()
        buffer.appendInt32(-367063982)
        return (FunctionDescription(name: "account.getPasskeys", parameters: []), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.account.Passkeys? in
            let reader = BufferReader(buffer)
            var result: Api.account.Passkeys?
            if let signature = reader.readInt32() {
                result = Api.parse(reader, signature: signature) as? Api.account.Passkeys
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
        return (FunctionDescription(name: "account.getPasswordSettings", parameters: [("password", FunctionParameterDescription(password))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.account.PasswordSettings? in
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
        return (FunctionDescription(name: "account.getPrivacy", parameters: [("key", FunctionParameterDescription(key))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.account.PrivacyRules? in
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
        return (FunctionDescription(name: "account.getRecentEmojiStatuses", parameters: [("hash", FunctionParameterDescription(hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.account.EmojiStatuses? in
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
    static func getSavedMusicIds(hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.account.SavedMusicIds>) {
        let buffer = Buffer()
        buffer.appendInt32(-526557265)
        serializeInt64(hash, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "account.getSavedMusicIds", parameters: [("hash", FunctionParameterDescription(hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.account.SavedMusicIds? in
            let reader = BufferReader(buffer)
            var result: Api.account.SavedMusicIds?
            if let signature = reader.readInt32() {
                result = Api.parse(reader, signature: signature) as? Api.account.SavedMusicIds
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
        return (FunctionDescription(name: "account.getSavedRingtones", parameters: [("hash", FunctionParameterDescription(hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.account.SavedRingtones? in
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
        return (FunctionDescription(name: "account.getSecureValue", parameters: [("types", FunctionParameterDescription(types))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> [Api.SecureValue]? in
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
        return (FunctionDescription(name: "account.getTheme", parameters: [("format", FunctionParameterDescription(format)), ("theme", FunctionParameterDescription(theme))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Theme? in
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
        return (FunctionDescription(name: "account.getThemes", parameters: [("format", FunctionParameterDescription(format)), ("hash", FunctionParameterDescription(hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.account.Themes? in
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
        return (FunctionDescription(name: "account.getTmpPassword", parameters: [("password", FunctionParameterDescription(password)), ("period", FunctionParameterDescription(period))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.account.TmpPassword? in
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
    static func getUniqueGiftChatThemes(offset: String, limit: Int32, hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.account.ChatThemes>) {
        let buffer = Buffer()
        buffer.appendInt32(-466818615)
        serializeString(offset, buffer: buffer, boxed: false)
        serializeInt32(limit, buffer: buffer, boxed: false)
        serializeInt64(hash, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "account.getUniqueGiftChatThemes", parameters: [("offset", FunctionParameterDescription(offset)), ("limit", FunctionParameterDescription(limit)), ("hash", FunctionParameterDescription(hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.account.ChatThemes? in
            let reader = BufferReader(buffer)
            var result: Api.account.ChatThemes?
            if let signature = reader.readInt32() {
                result = Api.parse(reader, signature: signature) as? Api.account.ChatThemes
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
        return (FunctionDescription(name: "account.getWallPaper", parameters: [("wallpaper", FunctionParameterDescription(wallpaper))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.WallPaper? in
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
        return (FunctionDescription(name: "account.getWallPapers", parameters: [("hash", FunctionParameterDescription(hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.account.WallPapers? in
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
    static func initPasskeyRegistration() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.account.PasskeyRegistrationOptions>) {
        let buffer = Buffer()
        buffer.appendInt32(1117079528)
        return (FunctionDescription(name: "account.initPasskeyRegistration", parameters: []), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.account.PasskeyRegistrationOptions? in
            let reader = BufferReader(buffer)
            var result: Api.account.PasskeyRegistrationOptions?
            if let signature = reader.readInt32() {
                result = Api.parse(reader, signature: signature) as? Api.account.PasskeyRegistrationOptions
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
        if Int(flags) & Int(1 << 5) != 0 {
            serializeInt64(fileMaxSize!, buffer: buffer, boxed: false)
        }
        return (FunctionDescription(name: "account.initTakeoutSession", parameters: [("flags", FunctionParameterDescription(flags)), ("fileMaxSize", FunctionParameterDescription(fileMaxSize))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.account.Takeout? in
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
        if Int(flags) & Int(1 << 1) != 0 {
            theme!.serialize(buffer, true)
        }
        if Int(flags) & Int(1 << 2) != 0 {
            serializeString(format!, buffer: buffer, boxed: false)
        }
        if Int(flags) & Int(1 << 3) != 0 {
            baseTheme!.serialize(buffer, true)
        }
        return (FunctionDescription(name: "account.installTheme", parameters: [("flags", FunctionParameterDescription(flags)), ("theme", FunctionParameterDescription(theme)), ("format", FunctionParameterDescription(format)), ("baseTheme", FunctionParameterDescription(baseTheme))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "account.installWallPaper", parameters: [("wallpaper", FunctionParameterDescription(wallpaper)), ("settings", FunctionParameterDescription(settings))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "account.invalidateSignInCodes", parameters: [("codes", FunctionParameterDescription(codes))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "account.registerDevice", parameters: [("flags", FunctionParameterDescription(flags)), ("tokenType", FunctionParameterDescription(tokenType)), ("token", FunctionParameterDescription(token)), ("appSandbox", FunctionParameterDescription(appSandbox)), ("secret", FunctionParameterDescription(secret)), ("otherUids", FunctionParameterDescription(otherUids))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
    static func registerPasskey(credential: Api.InputPasskeyCredential) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Passkey>) {
        let buffer = Buffer()
        buffer.appendInt32(1437867990)
        credential.serialize(buffer, true)
        return (FunctionDescription(name: "account.registerPasskey", parameters: [("credential", FunctionParameterDescription(credential))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Passkey? in
            let reader = BufferReader(buffer)
            var result: Api.Passkey?
            if let signature = reader.readInt32() {
                result = Api.parse(reader, signature: signature) as? Api.Passkey
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
        return (FunctionDescription(name: "account.reorderUsernames", parameters: [("order", FunctionParameterDescription(order))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "account.reportPeer", parameters: [("peer", FunctionParameterDescription(peer)), ("reason", FunctionParameterDescription(reason)), ("message", FunctionParameterDescription(message))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "account.reportProfilePhoto", parameters: [("peer", FunctionParameterDescription(peer)), ("photoId", FunctionParameterDescription(photoId)), ("reason", FunctionParameterDescription(reason)), ("message", FunctionParameterDescription(message))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "account.resetAuthorization", parameters: [("hash", FunctionParameterDescription(hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "account.resetWebAuthorization", parameters: [("hash", FunctionParameterDescription(hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "account.resolveBusinessChatLink", parameters: [("slug", FunctionParameterDescription(slug))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.account.ResolvedBusinessChatLinks? in
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
        return (FunctionDescription(name: "account.saveAutoDownloadSettings", parameters: [("flags", FunctionParameterDescription(flags)), ("settings", FunctionParameterDescription(settings))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        if Int(flags) & Int(1 << 3) != 0 {
            peer!.serialize(buffer, true)
        }
        settings.serialize(buffer, true)
        return (FunctionDescription(name: "account.saveAutoSaveSettings", parameters: [("flags", FunctionParameterDescription(flags)), ("peer", FunctionParameterDescription(peer)), ("settings", FunctionParameterDescription(settings))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
    static func saveMusic(flags: Int32, id: Api.InputDocument, afterId: Api.InputDocument?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let buffer = Buffer()
        buffer.appendInt32(-1301859671)
        serializeInt32(flags, buffer: buffer, boxed: false)
        id.serialize(buffer, true)
        if Int(flags) & Int(1 << 1) != 0 {
            afterId!.serialize(buffer, true)
        }
        return (FunctionDescription(name: "account.saveMusic", parameters: [("flags", FunctionParameterDescription(flags)), ("id", FunctionParameterDescription(id)), ("afterId", FunctionParameterDescription(afterId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "account.saveRingtone", parameters: [("id", FunctionParameterDescription(id)), ("unsave", FunctionParameterDescription(unsave))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.account.SavedRingtone? in
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
        return (FunctionDescription(name: "account.saveSecureValue", parameters: [("value", FunctionParameterDescription(value)), ("secureSecretId", FunctionParameterDescription(secureSecretId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.SecureValue? in
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
        return (FunctionDescription(name: "account.saveTheme", parameters: [("theme", FunctionParameterDescription(theme)), ("unsave", FunctionParameterDescription(unsave))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "account.saveWallPaper", parameters: [("wallpaper", FunctionParameterDescription(wallpaper)), ("unsave", FunctionParameterDescription(unsave)), ("settings", FunctionParameterDescription(settings))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "account.sendChangePhoneCode", parameters: [("phoneNumber", FunctionParameterDescription(phoneNumber)), ("settings", FunctionParameterDescription(settings))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.auth.SentCode? in
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
        return (FunctionDescription(name: "account.sendConfirmPhoneCode", parameters: [("hash", FunctionParameterDescription(hash)), ("settings", FunctionParameterDescription(settings))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.auth.SentCode? in
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
        return (FunctionDescription(name: "account.sendVerifyEmailCode", parameters: [("purpose", FunctionParameterDescription(purpose)), ("email", FunctionParameterDescription(email))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.account.SentEmailCode? in
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
        return (FunctionDescription(name: "account.sendVerifyPhoneCode", parameters: [("phoneNumber", FunctionParameterDescription(phoneNumber)), ("settings", FunctionParameterDescription(settings))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.auth.SentCode? in
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
        return (FunctionDescription(name: "account.setAccountTTL", parameters: [("ttl", FunctionParameterDescription(ttl))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "account.setAuthorizationTTL", parameters: [("authorizationTtlDays", FunctionParameterDescription(authorizationTtlDays))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "account.setContactSignUpNotification", parameters: [("silent", FunctionParameterDescription(silent))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "account.setContentSettings", parameters: [("flags", FunctionParameterDescription(flags))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "account.setGlobalPrivacySettings", parameters: [("settings", FunctionParameterDescription(settings))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.GlobalPrivacySettings? in
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
    static func setMainProfileTab(tab: Api.ProfileTab) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let buffer = Buffer()
        buffer.appendInt32(1575909552)
        tab.serialize(buffer, true)
        return (FunctionDescription(name: "account.setMainProfileTab", parameters: [("tab", FunctionParameterDescription(tab))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
    static func setPrivacy(key: Api.InputPrivacyKey, rules: [Api.InputPrivacyRule]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.account.PrivacyRules>) {
        let buffer = Buffer()
        buffer.appendInt32(-906486552)
        key.serialize(buffer, true)
        buffer.appendInt32(481674261)
        buffer.appendInt32(Int32(rules.count))
        for item in rules {
            item.serialize(buffer, true)
        }
        return (FunctionDescription(name: "account.setPrivacy", parameters: [("key", FunctionParameterDescription(key)), ("rules", FunctionParameterDescription(rules))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.account.PrivacyRules? in
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
        return (FunctionDescription(name: "account.setReactionsNotifySettings", parameters: [("settings", FunctionParameterDescription(settings))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.ReactionsNotifySettings? in
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
        return (FunctionDescription(name: "account.toggleConnectedBotPaused", parameters: [("peer", FunctionParameterDescription(peer)), ("paused", FunctionParameterDescription(paused))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        if Int(flags) & Int(1 << 1) != 0 {
            parentPeer!.serialize(buffer, true)
        }
        userId.serialize(buffer, true)
        return (FunctionDescription(name: "account.toggleNoPaidMessagesException", parameters: [("flags", FunctionParameterDescription(flags)), ("parentPeer", FunctionParameterDescription(parentPeer)), ("userId", FunctionParameterDescription(userId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "account.toggleSponsoredMessages", parameters: [("enabled", FunctionParameterDescription(enabled))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "account.toggleUsername", parameters: [("username", FunctionParameterDescription(username)), ("active", FunctionParameterDescription(active))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "account.unregisterDevice", parameters: [("tokenType", FunctionParameterDescription(tokenType)), ("token", FunctionParameterDescription(token)), ("otherUids", FunctionParameterDescription(otherUids))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        if Int(flags) & Int(1 << 0) != 0 {
            birthday!.serialize(buffer, true)
        }
        return (FunctionDescription(name: "account.updateBirthday", parameters: [("flags", FunctionParameterDescription(flags)), ("birthday", FunctionParameterDescription(birthday))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        if Int(flags) & Int(1 << 0) != 0 {
            message!.serialize(buffer, true)
        }
        return (FunctionDescription(name: "account.updateBusinessAwayMessage", parameters: [("flags", FunctionParameterDescription(flags)), ("message", FunctionParameterDescription(message))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        if Int(flags) & Int(1 << 0) != 0 {
            message!.serialize(buffer, true)
        }
        return (FunctionDescription(name: "account.updateBusinessGreetingMessage", parameters: [("flags", FunctionParameterDescription(flags)), ("message", FunctionParameterDescription(message))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        if Int(flags) & Int(1 << 0) != 0 {
            intro!.serialize(buffer, true)
        }
        return (FunctionDescription(name: "account.updateBusinessIntro", parameters: [("flags", FunctionParameterDescription(flags)), ("intro", FunctionParameterDescription(intro))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        if Int(flags) & Int(1 << 1) != 0 {
            geoPoint!.serialize(buffer, true)
        }
        if Int(flags) & Int(1 << 0) != 0 {
            serializeString(address!, buffer: buffer, boxed: false)
        }
        return (FunctionDescription(name: "account.updateBusinessLocation", parameters: [("flags", FunctionParameterDescription(flags)), ("geoPoint", FunctionParameterDescription(geoPoint)), ("address", FunctionParameterDescription(address))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        if Int(flags) & Int(1 << 0) != 0 {
            businessWorkHours!.serialize(buffer, true)
        }
        return (FunctionDescription(name: "account.updateBusinessWorkHours", parameters: [("flags", FunctionParameterDescription(flags)), ("businessWorkHours", FunctionParameterDescription(businessWorkHours))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
    static func updateColor(flags: Int32, color: Api.PeerColor?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let buffer = Buffer()
        buffer.appendInt32(1749885262)
        serializeInt32(flags, buffer: buffer, boxed: false)
        if Int(flags) & Int(1 << 2) != 0 {
            color!.serialize(buffer, true)
        }
        return (FunctionDescription(name: "account.updateColor", parameters: [("flags", FunctionParameterDescription(flags)), ("color", FunctionParameterDescription(color))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        if Int(flags) & Int(1 << 0) != 0 {
            rights!.serialize(buffer, true)
        }
        bot.serialize(buffer, true)
        recipients.serialize(buffer, true)
        return (FunctionDescription(name: "account.updateConnectedBot", parameters: [("flags", FunctionParameterDescription(flags)), ("rights", FunctionParameterDescription(rights)), ("bot", FunctionParameterDescription(bot)), ("recipients", FunctionParameterDescription(recipients))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        return (FunctionDescription(name: "account.updateDeviceLocked", parameters: [("period", FunctionParameterDescription(period))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "account.updateEmojiStatus", parameters: [("emojiStatus", FunctionParameterDescription(emojiStatus))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "account.updateNotifySettings", parameters: [("peer", FunctionParameterDescription(peer)), ("settings", FunctionParameterDescription(settings))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "account.updatePasswordSettings", parameters: [("password", FunctionParameterDescription(password)), ("newSettings", FunctionParameterDescription(newSettings))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "account.updatePersonalChannel", parameters: [("channel", FunctionParameterDescription(channel))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        if Int(flags) & Int(1 << 0) != 0 {
            serializeString(firstName!, buffer: buffer, boxed: false)
        }
        if Int(flags) & Int(1 << 1) != 0 {
            serializeString(lastName!, buffer: buffer, boxed: false)
        }
        if Int(flags) & Int(1 << 2) != 0 {
            serializeString(about!, buffer: buffer, boxed: false)
        }
        return (FunctionDescription(name: "account.updateProfile", parameters: [("flags", FunctionParameterDescription(flags)), ("firstName", FunctionParameterDescription(firstName)), ("lastName", FunctionParameterDescription(lastName)), ("about", FunctionParameterDescription(about))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.User? in
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
        return (FunctionDescription(name: "account.updateStatus", parameters: [("offline", FunctionParameterDescription(offline))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        if Int(flags) & Int(1 << 0) != 0 {
            serializeString(slug!, buffer: buffer, boxed: false)
        }
        if Int(flags) & Int(1 << 1) != 0 {
            serializeString(title!, buffer: buffer, boxed: false)
        }
        if Int(flags) & Int(1 << 2) != 0 {
            document!.serialize(buffer, true)
        }
        if Int(flags) & Int(1 << 3) != 0 {
            buffer.appendInt32(481674261)
            buffer.appendInt32(Int32(settings!.count))
            for item in settings! {
                item.serialize(buffer, true)
            }
        }
        return (FunctionDescription(name: "account.updateTheme", parameters: [("flags", FunctionParameterDescription(flags)), ("format", FunctionParameterDescription(format)), ("theme", FunctionParameterDescription(theme)), ("slug", FunctionParameterDescription(slug)), ("title", FunctionParameterDescription(title)), ("document", FunctionParameterDescription(document)), ("settings", FunctionParameterDescription(settings))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Theme? in
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
        return (FunctionDescription(name: "account.updateUsername", parameters: [("username", FunctionParameterDescription(username))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.User? in
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
        return (FunctionDescription(name: "account.uploadRingtone", parameters: [("file", FunctionParameterDescription(file)), ("fileName", FunctionParameterDescription(fileName)), ("mimeType", FunctionParameterDescription(mimeType))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Document? in
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
        if Int(flags) & Int(1 << 0) != 0 {
            thumb!.serialize(buffer, true)
        }
        serializeString(fileName, buffer: buffer, boxed: false)
        serializeString(mimeType, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "account.uploadTheme", parameters: [("flags", FunctionParameterDescription(flags)), ("file", FunctionParameterDescription(file)), ("thumb", FunctionParameterDescription(thumb)), ("fileName", FunctionParameterDescription(fileName)), ("mimeType", FunctionParameterDescription(mimeType))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Document? in
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
        return (FunctionDescription(name: "account.uploadWallPaper", parameters: [("flags", FunctionParameterDescription(flags)), ("file", FunctionParameterDescription(file)), ("mimeType", FunctionParameterDescription(mimeType)), ("settings", FunctionParameterDescription(settings))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.WallPaper? in
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
        return (FunctionDescription(name: "account.verifyEmail", parameters: [("purpose", FunctionParameterDescription(purpose)), ("verification", FunctionParameterDescription(verification))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.account.EmailVerified? in
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
        return (FunctionDescription(name: "account.verifyPhone", parameters: [("phoneNumber", FunctionParameterDescription(phoneNumber)), ("phoneCodeHash", FunctionParameterDescription(phoneCodeHash)), ("phoneCode", FunctionParameterDescription(phoneCode))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "auth.acceptLoginToken", parameters: [("token", FunctionParameterDescription(token))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Authorization? in
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
        return (FunctionDescription(name: "auth.bindTempAuthKey", parameters: [("permAuthKeyId", FunctionParameterDescription(permAuthKeyId)), ("nonce", FunctionParameterDescription(nonce)), ("expiresAt", FunctionParameterDescription(expiresAt)), ("encryptedMessage", FunctionParameterDescription(encryptedMessage))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "auth.cancelCode", parameters: [("phoneNumber", FunctionParameterDescription(phoneNumber)), ("phoneCodeHash", FunctionParameterDescription(phoneCodeHash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
    static func checkPaidAuth(phoneNumber: String, phoneCodeHash: String, formId: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.auth.SentCode>) {
        let buffer = Buffer()
        buffer.appendInt32(1457889180)
        serializeString(phoneNumber, buffer: buffer, boxed: false)
        serializeString(phoneCodeHash, buffer: buffer, boxed: false)
        serializeInt64(formId, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "auth.checkPaidAuth", parameters: [("phoneNumber", FunctionParameterDescription(phoneNumber)), ("phoneCodeHash", FunctionParameterDescription(phoneCodeHash)), ("formId", FunctionParameterDescription(formId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.auth.SentCode? in
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
    static func checkPassword(password: Api.InputCheckPasswordSRP) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.auth.Authorization>) {
        let buffer = Buffer()
        buffer.appendInt32(-779399914)
        password.serialize(buffer, true)
        return (FunctionDescription(name: "auth.checkPassword", parameters: [("password", FunctionParameterDescription(password))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.auth.Authorization? in
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
        return (FunctionDescription(name: "auth.checkRecoveryPassword", parameters: [("code", FunctionParameterDescription(code))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "auth.dropTempAuthKeys", parameters: [("exceptAuthKeys", FunctionParameterDescription(exceptAuthKeys))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "auth.exportAuthorization", parameters: [("dcId", FunctionParameterDescription(dcId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.auth.ExportedAuthorization? in
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
        return (FunctionDescription(name: "auth.exportLoginToken", parameters: [("apiId", FunctionParameterDescription(apiId)), ("apiHash", FunctionParameterDescription(apiHash)), ("exceptIds", FunctionParameterDescription(exceptIds))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.auth.LoginToken? in
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
    static func finishPasskeyLogin(flags: Int32, credential: Api.InputPasskeyCredential, fromDcId: Int32?, fromAuthKeyId: Int64?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.auth.Authorization>) {
        let buffer = Buffer()
        buffer.appendInt32(-1739084537)
        serializeInt32(flags, buffer: buffer, boxed: false)
        credential.serialize(buffer, true)
        if Int(flags) & Int(1 << 0) != 0 {
            serializeInt32(fromDcId!, buffer: buffer, boxed: false)
        }
        if Int(flags) & Int(1 << 0) != 0 {
            serializeInt64(fromAuthKeyId!, buffer: buffer, boxed: false)
        }
        return (FunctionDescription(name: "auth.finishPasskeyLogin", parameters: [("flags", FunctionParameterDescription(flags)), ("credential", FunctionParameterDescription(credential)), ("fromDcId", FunctionParameterDescription(fromDcId)), ("fromAuthKeyId", FunctionParameterDescription(fromAuthKeyId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.auth.Authorization? in
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
    static func importAuthorization(id: Int64, bytes: Buffer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.auth.Authorization>) {
        let buffer = Buffer()
        buffer.appendInt32(-1518699091)
        serializeInt64(id, buffer: buffer, boxed: false)
        serializeBytes(bytes, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "auth.importAuthorization", parameters: [("id", FunctionParameterDescription(id)), ("bytes", FunctionParameterDescription(bytes))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.auth.Authorization? in
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
        return (FunctionDescription(name: "auth.importBotAuthorization", parameters: [("flags", FunctionParameterDescription(flags)), ("apiId", FunctionParameterDescription(apiId)), ("apiHash", FunctionParameterDescription(apiHash)), ("botAuthToken", FunctionParameterDescription(botAuthToken))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.auth.Authorization? in
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
        return (FunctionDescription(name: "auth.importLoginToken", parameters: [("token", FunctionParameterDescription(token))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.auth.LoginToken? in
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
        return (FunctionDescription(name: "auth.importWebTokenAuthorization", parameters: [("apiId", FunctionParameterDescription(apiId)), ("apiHash", FunctionParameterDescription(apiHash)), ("webAuthToken", FunctionParameterDescription(webAuthToken))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.auth.Authorization? in
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
    static func initPasskeyLogin(apiId: Int32, apiHash: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.auth.PasskeyLoginOptions>) {
        let buffer = Buffer()
        buffer.appendInt32(1368051895)
        serializeInt32(apiId, buffer: buffer, boxed: false)
        serializeString(apiHash, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "auth.initPasskeyLogin", parameters: [("apiId", FunctionParameterDescription(apiId)), ("apiHash", FunctionParameterDescription(apiHash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.auth.PasskeyLoginOptions? in
            let reader = BufferReader(buffer)
            var result: Api.auth.PasskeyLoginOptions?
            if let signature = reader.readInt32() {
                result = Api.parse(reader, signature: signature) as? Api.auth.PasskeyLoginOptions
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
        if Int(flags) & Int(1 << 0) != 0 {
            newSettings!.serialize(buffer, true)
        }
        return (FunctionDescription(name: "auth.recoverPassword", parameters: [("flags", FunctionParameterDescription(flags)), ("code", FunctionParameterDescription(code)), ("newSettings", FunctionParameterDescription(newSettings))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.auth.Authorization? in
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
        return (FunctionDescription(name: "auth.reportMissingCode", parameters: [("phoneNumber", FunctionParameterDescription(phoneNumber)), ("phoneCodeHash", FunctionParameterDescription(phoneCodeHash)), ("mnc", FunctionParameterDescription(mnc))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        if Int(flags) & Int(1 << 0) != 0 {
            serializeString(safetyNetToken!, buffer: buffer, boxed: false)
        }
        if Int(flags) & Int(1 << 2) != 0 {
            serializeString(playIntegrityToken!, buffer: buffer, boxed: false)
        }
        if Int(flags) & Int(1 << 1) != 0 {
            serializeString(iosPushSecret!, buffer: buffer, boxed: false)
        }
        return (FunctionDescription(name: "auth.requestFirebaseSms", parameters: [("flags", FunctionParameterDescription(flags)), ("phoneNumber", FunctionParameterDescription(phoneNumber)), ("phoneCodeHash", FunctionParameterDescription(phoneCodeHash)), ("safetyNetToken", FunctionParameterDescription(safetyNetToken)), ("playIntegrityToken", FunctionParameterDescription(playIntegrityToken)), ("iosPushSecret", FunctionParameterDescription(iosPushSecret))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        if Int(flags) & Int(1 << 0) != 0 {
            serializeString(reason!, buffer: buffer, boxed: false)
        }
        return (FunctionDescription(name: "auth.resendCode", parameters: [("flags", FunctionParameterDescription(flags)), ("phoneNumber", FunctionParameterDescription(phoneNumber)), ("phoneCodeHash", FunctionParameterDescription(phoneCodeHash)), ("reason", FunctionParameterDescription(reason))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.auth.SentCode? in
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
        return (FunctionDescription(name: "auth.resetLoginEmail", parameters: [("phoneNumber", FunctionParameterDescription(phoneNumber)), ("phoneCodeHash", FunctionParameterDescription(phoneCodeHash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.auth.SentCode? in
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
        return (FunctionDescription(name: "auth.sendCode", parameters: [("phoneNumber", FunctionParameterDescription(phoneNumber)), ("apiId", FunctionParameterDescription(apiId)), ("apiHash", FunctionParameterDescription(apiHash)), ("settings", FunctionParameterDescription(settings))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.auth.SentCode? in
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
        if Int(flags) & Int(1 << 0) != 0 {
            serializeString(phoneCode!, buffer: buffer, boxed: false)
        }
        if Int(flags) & Int(1 << 1) != 0 {
            emailVerification!.serialize(buffer, true)
        }
        return (FunctionDescription(name: "auth.signIn", parameters: [("flags", FunctionParameterDescription(flags)), ("phoneNumber", FunctionParameterDescription(phoneNumber)), ("phoneCodeHash", FunctionParameterDescription(phoneCodeHash)), ("phoneCode", FunctionParameterDescription(phoneCode)), ("emailVerification", FunctionParameterDescription(emailVerification))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.auth.Authorization? in
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
        return (FunctionDescription(name: "auth.signUp", parameters: [("flags", FunctionParameterDescription(flags)), ("phoneNumber", FunctionParameterDescription(phoneNumber)), ("phoneCodeHash", FunctionParameterDescription(phoneCodeHash)), ("firstName", FunctionParameterDescription(firstName)), ("lastName", FunctionParameterDescription(lastName))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.auth.Authorization? in
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
        return (FunctionDescription(name: "bots.addPreviewMedia", parameters: [("bot", FunctionParameterDescription(bot)), ("langCode", FunctionParameterDescription(langCode)), ("media", FunctionParameterDescription(media))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.BotPreviewMedia? in
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
        return (FunctionDescription(name: "bots.allowSendMessage", parameters: [("bot", FunctionParameterDescription(bot))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        return (FunctionDescription(name: "bots.answerWebhookJSONQuery", parameters: [("queryId", FunctionParameterDescription(queryId)), ("data", FunctionParameterDescription(data))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "bots.canSendMessage", parameters: [("bot", FunctionParameterDescription(bot))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "bots.checkDownloadFileParams", parameters: [("bot", FunctionParameterDescription(bot)), ("fileName", FunctionParameterDescription(fileName)), ("url", FunctionParameterDescription(url))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
    static func checkUsername(username: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let buffer = Buffer()
        buffer.appendInt32(-2014174821)
        serializeString(username, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "bots.checkUsername", parameters: [("username", FunctionParameterDescription(username))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
    static func createBot(flags: Int32, name: String, username: String, managerId: Api.InputUser) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.User>) {
        let buffer = Buffer()
        buffer.appendInt32(-441352405)
        serializeInt32(flags, buffer: buffer, boxed: false)
        serializeString(name, buffer: buffer, boxed: false)
        serializeString(username, buffer: buffer, boxed: false)
        managerId.serialize(buffer, true)
        return (FunctionDescription(name: "bots.createBot", parameters: [("flags", FunctionParameterDescription(flags)), ("name", FunctionParameterDescription(name)), ("username", FunctionParameterDescription(username)), ("managerId", FunctionParameterDescription(managerId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.User? in
            let reader = BufferReader(buffer)
            var result: Api.User?
            if let signature = reader.readInt32() {
                result = Api.parse(reader, signature: signature) as? Api.User
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
        return (FunctionDescription(name: "bots.deletePreviewMedia", parameters: [("bot", FunctionParameterDescription(bot)), ("langCode", FunctionParameterDescription(langCode)), ("media", FunctionParameterDescription(media))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "bots.editPreviewMedia", parameters: [("bot", FunctionParameterDescription(bot)), ("langCode", FunctionParameterDescription(langCode)), ("media", FunctionParameterDescription(media)), ("newMedia", FunctionParameterDescription(newMedia))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.BotPreviewMedia? in
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
    static func exportBotToken(bot: Api.InputUser, revoke: Api.Bool) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.bots.ExportedBotToken>) {
        let buffer = Buffer()
        buffer.appendInt32(-1123182101)
        bot.serialize(buffer, true)
        revoke.serialize(buffer, true)
        return (FunctionDescription(name: "bots.exportBotToken", parameters: [("bot", FunctionParameterDescription(bot)), ("revoke", FunctionParameterDescription(revoke))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.bots.ExportedBotToken? in
            let reader = BufferReader(buffer)
            var result: Api.bots.ExportedBotToken?
            if let signature = reader.readInt32() {
                result = Api.parse(reader, signature: signature) as? Api.bots.ExportedBotToken
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
        return (FunctionDescription(name: "bots.getBotCommands", parameters: [("scope", FunctionParameterDescription(scope)), ("langCode", FunctionParameterDescription(langCode))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> [Api.BotCommand]? in
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
        if Int(flags) & Int(1 << 0) != 0 {
            bot!.serialize(buffer, true)
        }
        serializeString(langCode, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "bots.getBotInfo", parameters: [("flags", FunctionParameterDescription(flags)), ("bot", FunctionParameterDescription(bot)), ("langCode", FunctionParameterDescription(langCode))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.bots.BotInfo? in
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
        return (FunctionDescription(name: "bots.getBotMenuButton", parameters: [("userId", FunctionParameterDescription(userId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.BotMenuButton? in
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
        return (FunctionDescription(name: "bots.getBotRecommendations", parameters: [("bot", FunctionParameterDescription(bot))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.users.Users? in
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
        return (FunctionDescription(name: "bots.getPopularAppBots", parameters: [("offset", FunctionParameterDescription(offset)), ("limit", FunctionParameterDescription(limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.bots.PopularAppBots? in
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
        return (FunctionDescription(name: "bots.getPreviewInfo", parameters: [("bot", FunctionParameterDescription(bot)), ("langCode", FunctionParameterDescription(langCode))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.bots.PreviewInfo? in
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
        return (FunctionDescription(name: "bots.getPreviewMedias", parameters: [("bot", FunctionParameterDescription(bot))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> [Api.BotPreviewMedia]? in
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
    static func getRequestedWebViewButton(bot: Api.InputUser, webappReqId: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.KeyboardButton>) {
        let buffer = Buffer()
        buffer.appendInt32(-1088047117)
        bot.serialize(buffer, true)
        serializeString(webappReqId, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "bots.getRequestedWebViewButton", parameters: [("bot", FunctionParameterDescription(bot)), ("webappReqId", FunctionParameterDescription(webappReqId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.KeyboardButton? in
            let reader = BufferReader(buffer)
            var result: Api.KeyboardButton?
            if let signature = reader.readInt32() {
                result = Api.parse(reader, signature: signature) as? Api.KeyboardButton
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
        return (FunctionDescription(name: "bots.invokeWebViewCustomMethod", parameters: [("bot", FunctionParameterDescription(bot)), ("customMethod", FunctionParameterDescription(customMethod)), ("params", FunctionParameterDescription(params))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.DataJSON? in
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
        return (FunctionDescription(name: "bots.reorderPreviewMedias", parameters: [("bot", FunctionParameterDescription(bot)), ("langCode", FunctionParameterDescription(langCode)), ("order", FunctionParameterDescription(order))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "bots.reorderUsernames", parameters: [("bot", FunctionParameterDescription(bot)), ("order", FunctionParameterDescription(order))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
    static func requestWebViewButton(userId: Api.InputUser, button: Api.KeyboardButton) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.bots.RequestedButton>) {
        let buffer = Buffer()
        buffer.appendInt32(832742238)
        userId.serialize(buffer, true)
        button.serialize(buffer, true)
        return (FunctionDescription(name: "bots.requestWebViewButton", parameters: [("userId", FunctionParameterDescription(userId)), ("button", FunctionParameterDescription(button))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.bots.RequestedButton? in
            let reader = BufferReader(buffer)
            var result: Api.bots.RequestedButton?
            if let signature = reader.readInt32() {
                result = Api.parse(reader, signature: signature) as? Api.bots.RequestedButton
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
        return (FunctionDescription(name: "bots.resetBotCommands", parameters: [("scope", FunctionParameterDescription(scope)), ("langCode", FunctionParameterDescription(langCode))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "bots.sendCustomRequest", parameters: [("customMethod", FunctionParameterDescription(customMethod)), ("params", FunctionParameterDescription(params))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.DataJSON? in
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
        return (FunctionDescription(name: "bots.setBotBroadcastDefaultAdminRights", parameters: [("adminRights", FunctionParameterDescription(adminRights))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "bots.setBotCommands", parameters: [("scope", FunctionParameterDescription(scope)), ("langCode", FunctionParameterDescription(langCode)), ("commands", FunctionParameterDescription(commands))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "bots.setBotGroupDefaultAdminRights", parameters: [("adminRights", FunctionParameterDescription(adminRights))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        if Int(flags) & Int(1 << 2) != 0 {
            bot!.serialize(buffer, true)
        }
        serializeString(langCode, buffer: buffer, boxed: false)
        if Int(flags) & Int(1 << 3) != 0 {
            serializeString(name!, buffer: buffer, boxed: false)
        }
        if Int(flags) & Int(1 << 0) != 0 {
            serializeString(about!, buffer: buffer, boxed: false)
        }
        if Int(flags) & Int(1 << 1) != 0 {
            serializeString(description!, buffer: buffer, boxed: false)
        }
        return (FunctionDescription(name: "bots.setBotInfo", parameters: [("flags", FunctionParameterDescription(flags)), ("bot", FunctionParameterDescription(bot)), ("langCode", FunctionParameterDescription(langCode)), ("name", FunctionParameterDescription(name)), ("about", FunctionParameterDescription(about)), ("description", FunctionParameterDescription(description))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "bots.setBotMenuButton", parameters: [("userId", FunctionParameterDescription(userId)), ("button", FunctionParameterDescription(button))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        if Int(flags) & Int(1 << 0) != 0 {
            bot!.serialize(buffer, true)
        }
        peer.serialize(buffer, true)
        if Int(flags) & Int(1 << 2) != 0 {
            serializeString(customDescription!, buffer: buffer, boxed: false)
        }
        return (FunctionDescription(name: "bots.setCustomVerification", parameters: [("flags", FunctionParameterDescription(flags)), ("bot", FunctionParameterDescription(bot)), ("peer", FunctionParameterDescription(peer)), ("customDescription", FunctionParameterDescription(customDescription))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "bots.toggleUserEmojiStatusPermission", parameters: [("bot", FunctionParameterDescription(bot)), ("enabled", FunctionParameterDescription(enabled))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "bots.toggleUsername", parameters: [("bot", FunctionParameterDescription(bot)), ("username", FunctionParameterDescription(username)), ("active", FunctionParameterDescription(active))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        if Int(flags) & Int(1 << 0) != 0 {
            serializeInt32(durationMonths!, buffer: buffer, boxed: false)
        }
        return (FunctionDescription(name: "bots.updateStarRefProgram", parameters: [("flags", FunctionParameterDescription(flags)), ("bot", FunctionParameterDescription(bot)), ("commissionPermille", FunctionParameterDescription(commissionPermille)), ("durationMonths", FunctionParameterDescription(durationMonths))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.StarRefProgram? in
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
        return (FunctionDescription(name: "bots.updateUserEmojiStatus", parameters: [("userId", FunctionParameterDescription(userId)), ("emojiStatus", FunctionParameterDescription(emojiStatus))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
    static func checkSearchPostsFlood(flags: Int32, query: String?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.SearchPostsFlood>) {
        let buffer = Buffer()
        buffer.appendInt32(576090389)
        serializeInt32(flags, buffer: buffer, boxed: false)
        if Int(flags) & Int(1 << 0) != 0 {
            serializeString(query!, buffer: buffer, boxed: false)
        }
        return (FunctionDescription(name: "channels.checkSearchPostsFlood", parameters: [("flags", FunctionParameterDescription(flags)), ("query", FunctionParameterDescription(query))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.SearchPostsFlood? in
            let reader = BufferReader(buffer)
            var result: Api.SearchPostsFlood?
            if let signature = reader.readInt32() {
                result = Api.parse(reader, signature: signature) as? Api.SearchPostsFlood
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
        return (FunctionDescription(name: "channels.checkUsername", parameters: [("channel", FunctionParameterDescription(channel)), ("username", FunctionParameterDescription(username))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "channels.convertToGigagroup", parameters: [("channel", FunctionParameterDescription(channel))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        if Int(flags) & Int(1 << 2) != 0 {
            geoPoint!.serialize(buffer, true)
        }
        if Int(flags) & Int(1 << 2) != 0 {
            serializeString(address!, buffer: buffer, boxed: false)
        }
        if Int(flags) & Int(1 << 4) != 0 {
            serializeInt32(ttlPeriod!, buffer: buffer, boxed: false)
        }
        return (FunctionDescription(name: "channels.createChannel", parameters: [("flags", FunctionParameterDescription(flags)), ("title", FunctionParameterDescription(title)), ("about", FunctionParameterDescription(about)), ("geoPoint", FunctionParameterDescription(geoPoint)), ("address", FunctionParameterDescription(address)), ("ttlPeriod", FunctionParameterDescription(ttlPeriod))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        return (FunctionDescription(name: "channels.deactivateAllUsernames", parameters: [("channel", FunctionParameterDescription(channel))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "channels.deleteChannel", parameters: [("channel", FunctionParameterDescription(channel))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        return (FunctionDescription(name: "channels.deleteHistory", parameters: [("flags", FunctionParameterDescription(flags)), ("channel", FunctionParameterDescription(channel)), ("maxId", FunctionParameterDescription(maxId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        return (FunctionDescription(name: "channels.deleteMessages", parameters: [("channel", FunctionParameterDescription(channel)), ("id", FunctionParameterDescription(id))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.AffectedMessages? in
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
        return (FunctionDescription(name: "channels.deleteParticipantHistory", parameters: [("channel", FunctionParameterDescription(channel)), ("participant", FunctionParameterDescription(participant))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.AffectedHistory? in
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
    static func editAdmin(flags: Int32, channel: Api.InputChannel, userId: Api.InputUser, adminRights: Api.ChatAdminRights, rank: String?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let buffer = Buffer()
        buffer.appendInt32(-1701270168)
        serializeInt32(flags, buffer: buffer, boxed: false)
        channel.serialize(buffer, true)
        userId.serialize(buffer, true)
        adminRights.serialize(buffer, true)
        if Int(flags) & Int(1 << 0) != 0 {
            serializeString(rank!, buffer: buffer, boxed: false)
        }
        return (FunctionDescription(name: "channels.editAdmin", parameters: [("flags", FunctionParameterDescription(flags)), ("channel", FunctionParameterDescription(channel)), ("userId", FunctionParameterDescription(userId)), ("adminRights", FunctionParameterDescription(adminRights)), ("rank", FunctionParameterDescription(rank))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        return (FunctionDescription(name: "channels.editBanned", parameters: [("channel", FunctionParameterDescription(channel)), ("participant", FunctionParameterDescription(participant)), ("bannedRights", FunctionParameterDescription(bannedRights))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        return (FunctionDescription(name: "channels.editLocation", parameters: [("channel", FunctionParameterDescription(channel)), ("geoPoint", FunctionParameterDescription(geoPoint)), ("address", FunctionParameterDescription(address))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "channels.editPhoto", parameters: [("channel", FunctionParameterDescription(channel)), ("photo", FunctionParameterDescription(photo))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        return (FunctionDescription(name: "channels.editTitle", parameters: [("channel", FunctionParameterDescription(channel)), ("title", FunctionParameterDescription(title))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        return (FunctionDescription(name: "channels.exportMessageLink", parameters: [("flags", FunctionParameterDescription(flags)), ("channel", FunctionParameterDescription(channel)), ("id", FunctionParameterDescription(id))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.ExportedMessageLink? in
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
        if Int(flags) & Int(1 << 0) != 0 {
            eventsFilter!.serialize(buffer, true)
        }
        if Int(flags) & Int(1 << 1) != 0 {
            buffer.appendInt32(481674261)
            buffer.appendInt32(Int32(admins!.count))
            for item in admins! {
                item.serialize(buffer, true)
            }
        }
        serializeInt64(maxId, buffer: buffer, boxed: false)
        serializeInt64(minId, buffer: buffer, boxed: false)
        serializeInt32(limit, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "channels.getAdminLog", parameters: [("flags", FunctionParameterDescription(flags)), ("channel", FunctionParameterDescription(channel)), ("q", FunctionParameterDescription(q)), ("eventsFilter", FunctionParameterDescription(eventsFilter)), ("admins", FunctionParameterDescription(admins)), ("maxId", FunctionParameterDescription(maxId)), ("minId", FunctionParameterDescription(minId)), ("limit", FunctionParameterDescription(limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.channels.AdminLogResults? in
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
        return (FunctionDescription(name: "channels.getAdminedPublicChannels", parameters: [("flags", FunctionParameterDescription(flags))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.Chats? in
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
        if Int(flags) & Int(1 << 0) != 0 {
            channel!.serialize(buffer, true)
        }
        return (FunctionDescription(name: "channels.getChannelRecommendations", parameters: [("flags", FunctionParameterDescription(flags)), ("channel", FunctionParameterDescription(channel))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.Chats? in
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
        return (FunctionDescription(name: "channels.getChannels", parameters: [("id", FunctionParameterDescription(id))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.Chats? in
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
    static func getFullChannel(channel: Api.InputChannel) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.ChatFull>) {
        let buffer = Buffer()
        buffer.appendInt32(141781513)
        channel.serialize(buffer, true)
        return (FunctionDescription(name: "channels.getFullChannel", parameters: [("channel", FunctionParameterDescription(channel))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.ChatFull? in
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
        return (FunctionDescription(name: "channels.getLeftChannels", parameters: [("offset", FunctionParameterDescription(offset))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.Chats? in
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
        return (FunctionDescription(name: "channels.getMessageAuthor", parameters: [("channel", FunctionParameterDescription(channel)), ("id", FunctionParameterDescription(id))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.User? in
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
        return (FunctionDescription(name: "channels.getMessages", parameters: [("channel", FunctionParameterDescription(channel)), ("id", FunctionParameterDescription(id))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.Messages? in
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
        return (FunctionDescription(name: "channels.getParticipant", parameters: [("channel", FunctionParameterDescription(channel)), ("participant", FunctionParameterDescription(participant))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.channels.ChannelParticipant? in
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
        return (FunctionDescription(name: "channels.getParticipants", parameters: [("channel", FunctionParameterDescription(channel)), ("filter", FunctionParameterDescription(filter)), ("offset", FunctionParameterDescription(offset)), ("limit", FunctionParameterDescription(limit)), ("hash", FunctionParameterDescription(hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.channels.ChannelParticipants? in
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
        return (FunctionDescription(name: "channels.getSendAs", parameters: [("flags", FunctionParameterDescription(flags)), ("peer", FunctionParameterDescription(peer))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.channels.SendAsPeers? in
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
        return (FunctionDescription(name: "channels.inviteToChannel", parameters: [("channel", FunctionParameterDescription(channel)), ("users", FunctionParameterDescription(users))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.InvitedUsers? in
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
        return (FunctionDescription(name: "channels.joinChannel", parameters: [("channel", FunctionParameterDescription(channel))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        return (FunctionDescription(name: "channels.leaveChannel", parameters: [("channel", FunctionParameterDescription(channel))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        return (FunctionDescription(name: "channels.readHistory", parameters: [("channel", FunctionParameterDescription(channel)), ("maxId", FunctionParameterDescription(maxId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "channels.readMessageContents", parameters: [("channel", FunctionParameterDescription(channel)), ("id", FunctionParameterDescription(id))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "channels.reorderUsernames", parameters: [("channel", FunctionParameterDescription(channel)), ("order", FunctionParameterDescription(order))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "channels.reportAntiSpamFalsePositive", parameters: [("channel", FunctionParameterDescription(channel)), ("msgId", FunctionParameterDescription(msgId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "channels.reportSpam", parameters: [("channel", FunctionParameterDescription(channel)), ("participant", FunctionParameterDescription(participant)), ("id", FunctionParameterDescription(id))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "channels.restrictSponsoredMessages", parameters: [("channel", FunctionParameterDescription(channel)), ("restricted", FunctionParameterDescription(restricted))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
    static func searchPosts(flags: Int32, hashtag: String?, query: String?, offsetRate: Int32, offsetPeer: Api.InputPeer, offsetId: Int32, limit: Int32, allowPaidStars: Int64?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.Messages>) {
        let buffer = Buffer()
        buffer.appendInt32(-221973939)
        serializeInt32(flags, buffer: buffer, boxed: false)
        if Int(flags) & Int(1 << 0) != 0 {
            serializeString(hashtag!, buffer: buffer, boxed: false)
        }
        if Int(flags) & Int(1 << 1) != 0 {
            serializeString(query!, buffer: buffer, boxed: false)
        }
        serializeInt32(offsetRate, buffer: buffer, boxed: false)
        offsetPeer.serialize(buffer, true)
        serializeInt32(offsetId, buffer: buffer, boxed: false)
        serializeInt32(limit, buffer: buffer, boxed: false)
        if Int(flags) & Int(1 << 2) != 0 {
            serializeInt64(allowPaidStars!, buffer: buffer, boxed: false)
        }
        return (FunctionDescription(name: "channels.searchPosts", parameters: [("flags", FunctionParameterDescription(flags)), ("hashtag", FunctionParameterDescription(hashtag)), ("query", FunctionParameterDescription(query)), ("offsetRate", FunctionParameterDescription(offsetRate)), ("offsetPeer", FunctionParameterDescription(offsetPeer)), ("offsetId", FunctionParameterDescription(offsetId)), ("limit", FunctionParameterDescription(limit)), ("allowPaidStars", FunctionParameterDescription(allowPaidStars))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.Messages? in
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
        return (FunctionDescription(name: "channels.setBoostsToUnblockRestrictions", parameters: [("channel", FunctionParameterDescription(channel)), ("boosts", FunctionParameterDescription(boosts))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        return (FunctionDescription(name: "channels.setDiscussionGroup", parameters: [("broadcast", FunctionParameterDescription(broadcast)), ("group", FunctionParameterDescription(group))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "channels.setEmojiStickers", parameters: [("channel", FunctionParameterDescription(channel)), ("stickerset", FunctionParameterDescription(stickerset))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
    static func setMainProfileTab(channel: Api.InputChannel, tab: Api.ProfileTab) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let buffer = Buffer()
        buffer.appendInt32(897842353)
        channel.serialize(buffer, true)
        tab.serialize(buffer, true)
        return (FunctionDescription(name: "channels.setMainProfileTab", parameters: [("channel", FunctionParameterDescription(channel)), ("tab", FunctionParameterDescription(tab))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "channels.setStickers", parameters: [("channel", FunctionParameterDescription(channel)), ("stickerset", FunctionParameterDescription(stickerset))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "channels.toggleAntiSpam", parameters: [("channel", FunctionParameterDescription(channel)), ("enabled", FunctionParameterDescription(enabled))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        return (FunctionDescription(name: "channels.toggleAutotranslation", parameters: [("channel", FunctionParameterDescription(channel)), ("enabled", FunctionParameterDescription(enabled))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        return (FunctionDescription(name: "channels.toggleForum", parameters: [("channel", FunctionParameterDescription(channel)), ("enabled", FunctionParameterDescription(enabled)), ("tabs", FunctionParameterDescription(tabs))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        return (FunctionDescription(name: "channels.toggleJoinRequest", parameters: [("channel", FunctionParameterDescription(channel)), ("enabled", FunctionParameterDescription(enabled))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        return (FunctionDescription(name: "channels.toggleJoinToSend", parameters: [("channel", FunctionParameterDescription(channel)), ("enabled", FunctionParameterDescription(enabled))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        return (FunctionDescription(name: "channels.toggleParticipantsHidden", parameters: [("channel", FunctionParameterDescription(channel)), ("enabled", FunctionParameterDescription(enabled))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        return (FunctionDescription(name: "channels.togglePreHistoryHidden", parameters: [("channel", FunctionParameterDescription(channel)), ("enabled", FunctionParameterDescription(enabled))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        return (FunctionDescription(name: "channels.toggleSignatures", parameters: [("flags", FunctionParameterDescription(flags)), ("channel", FunctionParameterDescription(channel))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        return (FunctionDescription(name: "channels.toggleSlowMode", parameters: [("channel", FunctionParameterDescription(channel)), ("seconds", FunctionParameterDescription(seconds))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        return (FunctionDescription(name: "channels.toggleUsername", parameters: [("channel", FunctionParameterDescription(channel)), ("username", FunctionParameterDescription(username)), ("active", FunctionParameterDescription(active))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "channels.toggleViewForumAsMessages", parameters: [("channel", FunctionParameterDescription(channel)), ("enabled", FunctionParameterDescription(enabled))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        if Int(flags) & Int(1 << 2) != 0 {
            serializeInt32(color!, buffer: buffer, boxed: false)
        }
        if Int(flags) & Int(1 << 0) != 0 {
            serializeInt64(backgroundEmojiId!, buffer: buffer, boxed: false)
        }
        return (FunctionDescription(name: "channels.updateColor", parameters: [("flags", FunctionParameterDescription(flags)), ("channel", FunctionParameterDescription(channel)), ("color", FunctionParameterDescription(color)), ("backgroundEmojiId", FunctionParameterDescription(backgroundEmojiId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        return (FunctionDescription(name: "channels.updateEmojiStatus", parameters: [("channel", FunctionParameterDescription(channel)), ("emojiStatus", FunctionParameterDescription(emojiStatus))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        return (FunctionDescription(name: "channels.updatePaidMessagesPrice", parameters: [("flags", FunctionParameterDescription(flags)), ("channel", FunctionParameterDescription(channel)), ("sendPaidMessagesStars", FunctionParameterDescription(sendPaidMessagesStars))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        return (FunctionDescription(name: "channels.updateUsername", parameters: [("channel", FunctionParameterDescription(channel)), ("username", FunctionParameterDescription(username))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "chatlists.checkChatlistInvite", parameters: [("slug", FunctionParameterDescription(slug))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.chatlists.ChatlistInvite? in
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
        return (FunctionDescription(name: "chatlists.deleteExportedInvite", parameters: [("chatlist", FunctionParameterDescription(chatlist)), ("slug", FunctionParameterDescription(slug))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        if Int(flags) & Int(1 << 1) != 0 {
            serializeString(title!, buffer: buffer, boxed: false)
        }
        if Int(flags) & Int(1 << 2) != 0 {
            buffer.appendInt32(481674261)
            buffer.appendInt32(Int32(peers!.count))
            for item in peers! {
                item.serialize(buffer, true)
            }
        }
        return (FunctionDescription(name: "chatlists.editExportedInvite", parameters: [("flags", FunctionParameterDescription(flags)), ("chatlist", FunctionParameterDescription(chatlist)), ("slug", FunctionParameterDescription(slug)), ("title", FunctionParameterDescription(title)), ("peers", FunctionParameterDescription(peers))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.ExportedChatlistInvite? in
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
        return (FunctionDescription(name: "chatlists.exportChatlistInvite", parameters: [("chatlist", FunctionParameterDescription(chatlist)), ("title", FunctionParameterDescription(title)), ("peers", FunctionParameterDescription(peers))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.chatlists.ExportedChatlistInvite? in
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
        return (FunctionDescription(name: "chatlists.getChatlistUpdates", parameters: [("chatlist", FunctionParameterDescription(chatlist))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.chatlists.ChatlistUpdates? in
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
        return (FunctionDescription(name: "chatlists.getExportedInvites", parameters: [("chatlist", FunctionParameterDescription(chatlist))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.chatlists.ExportedInvites? in
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
        return (FunctionDescription(name: "chatlists.getLeaveChatlistSuggestions", parameters: [("chatlist", FunctionParameterDescription(chatlist))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> [Api.Peer]? in
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
        return (FunctionDescription(name: "chatlists.hideChatlistUpdates", parameters: [("chatlist", FunctionParameterDescription(chatlist))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "chatlists.joinChatlistInvite", parameters: [("slug", FunctionParameterDescription(slug)), ("peers", FunctionParameterDescription(peers))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        return (FunctionDescription(name: "chatlists.joinChatlistUpdates", parameters: [("chatlist", FunctionParameterDescription(chatlist)), ("peers", FunctionParameterDescription(peers))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        return (FunctionDescription(name: "chatlists.leaveChatlist", parameters: [("chatlist", FunctionParameterDescription(chatlist)), ("peers", FunctionParameterDescription(peers))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        return (FunctionDescription(name: "contacts.acceptContact", parameters: [("id", FunctionParameterDescription(id))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
    static func addContact(flags: Int32, id: Api.InputUser, firstName: String, lastName: String, phone: String, note: Api.TextWithEntities?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let buffer = Buffer()
        buffer.appendInt32(-642109868)
        serializeInt32(flags, buffer: buffer, boxed: false)
        id.serialize(buffer, true)
        serializeString(firstName, buffer: buffer, boxed: false)
        serializeString(lastName, buffer: buffer, boxed: false)
        serializeString(phone, buffer: buffer, boxed: false)
        if Int(flags) & Int(1 << 1) != 0 {
            note!.serialize(buffer, true)
        }
        return (FunctionDescription(name: "contacts.addContact", parameters: [("flags", FunctionParameterDescription(flags)), ("id", FunctionParameterDescription(id)), ("firstName", FunctionParameterDescription(firstName)), ("lastName", FunctionParameterDescription(lastName)), ("phone", FunctionParameterDescription(phone)), ("note", FunctionParameterDescription(note))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        return (FunctionDescription(name: "contacts.block", parameters: [("flags", FunctionParameterDescription(flags)), ("id", FunctionParameterDescription(id))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "contacts.blockFromReplies", parameters: [("flags", FunctionParameterDescription(flags)), ("msgId", FunctionParameterDescription(msgId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        return (FunctionDescription(name: "contacts.deleteByPhones", parameters: [("phones", FunctionParameterDescription(phones))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "contacts.deleteContacts", parameters: [("id", FunctionParameterDescription(id))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        return (FunctionDescription(name: "contacts.editCloseFriends", parameters: [("id", FunctionParameterDescription(id))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "contacts.getBlocked", parameters: [("flags", FunctionParameterDescription(flags)), ("offset", FunctionParameterDescription(offset)), ("limit", FunctionParameterDescription(limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.contacts.Blocked? in
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
        return (FunctionDescription(name: "contacts.getContactIDs", parameters: [("hash", FunctionParameterDescription(hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> [Int32]? in
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
        return (FunctionDescription(name: "contacts.getContacts", parameters: [("hash", FunctionParameterDescription(hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.contacts.Contacts? in
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
        if Int(flags) & Int(1 << 0) != 0 {
            serializeInt32(selfExpires!, buffer: buffer, boxed: false)
        }
        return (FunctionDescription(name: "contacts.getLocated", parameters: [("flags", FunctionParameterDescription(flags)), ("geoPoint", FunctionParameterDescription(geoPoint)), ("selfExpires", FunctionParameterDescription(selfExpires))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        return (FunctionDescription(name: "contacts.getSponsoredPeers", parameters: [("q", FunctionParameterDescription(q))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.contacts.SponsoredPeers? in
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
        return (FunctionDescription(name: "contacts.getTopPeers", parameters: [("flags", FunctionParameterDescription(flags)), ("offset", FunctionParameterDescription(offset)), ("limit", FunctionParameterDescription(limit)), ("hash", FunctionParameterDescription(hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.contacts.TopPeers? in
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
        return (FunctionDescription(name: "contacts.importContactToken", parameters: [("token", FunctionParameterDescription(token))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.User? in
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
        return (FunctionDescription(name: "contacts.importContacts", parameters: [("contacts", FunctionParameterDescription(contacts))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.contacts.ImportedContacts? in
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
        return (FunctionDescription(name: "contacts.resetTopPeerRating", parameters: [("category", FunctionParameterDescription(category)), ("peer", FunctionParameterDescription(peer))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "contacts.resolvePhone", parameters: [("phone", FunctionParameterDescription(phone))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.contacts.ResolvedPeer? in
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
        if Int(flags) & Int(1 << 0) != 0 {
            serializeString(referer!, buffer: buffer, boxed: false)
        }
        return (FunctionDescription(name: "contacts.resolveUsername", parameters: [("flags", FunctionParameterDescription(flags)), ("username", FunctionParameterDescription(username)), ("referer", FunctionParameterDescription(referer))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.contacts.ResolvedPeer? in
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
        return (FunctionDescription(name: "contacts.search", parameters: [("q", FunctionParameterDescription(q)), ("limit", FunctionParameterDescription(limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.contacts.Found? in
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
        return (FunctionDescription(name: "contacts.setBlocked", parameters: [("flags", FunctionParameterDescription(flags)), ("id", FunctionParameterDescription(id)), ("limit", FunctionParameterDescription(limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "contacts.toggleTopPeers", parameters: [("enabled", FunctionParameterDescription(enabled))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "contacts.unblock", parameters: [("flags", FunctionParameterDescription(flags)), ("id", FunctionParameterDescription(id))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
    static func updateContactNote(id: Api.InputUser, note: Api.TextWithEntities) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let buffer = Buffer()
        buffer.appendInt32(329212923)
        id.serialize(buffer, true)
        note.serialize(buffer, true)
        return (FunctionDescription(name: "contacts.updateContactNote", parameters: [("id", FunctionParameterDescription(id)), ("note", FunctionParameterDescription(note))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "folders.editPeerFolders", parameters: [("folderPeers", FunctionParameterDescription(folderPeers))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        return (FunctionDescription(name: "fragment.getCollectibleInfo", parameters: [("collectible", FunctionParameterDescription(collectible))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.fragment.CollectibleInfo? in
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
        return (FunctionDescription(name: "help.acceptTermsOfService", parameters: [("id", FunctionParameterDescription(id))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "help.dismissSuggestion", parameters: [("peer", FunctionParameterDescription(peer)), ("suggestion", FunctionParameterDescription(suggestion))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "help.editUserInfo", parameters: [("userId", FunctionParameterDescription(userId)), ("message", FunctionParameterDescription(message)), ("entities", FunctionParameterDescription(entities))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.help.UserInfo? in
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
        return (FunctionDescription(name: "help.getAppConfig", parameters: [("hash", FunctionParameterDescription(hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.help.AppConfig? in
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
        return (FunctionDescription(name: "help.getAppUpdate", parameters: [("source", FunctionParameterDescription(source))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.help.AppUpdate? in
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
        return (FunctionDescription(name: "help.getCountriesList", parameters: [("langCode", FunctionParameterDescription(langCode)), ("hash", FunctionParameterDescription(hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.help.CountriesList? in
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
        return (FunctionDescription(name: "help.getDeepLinkInfo", parameters: [("path", FunctionParameterDescription(path))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.help.DeepLinkInfo? in
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
        return (FunctionDescription(name: "help.getPassportConfig", parameters: [("hash", FunctionParameterDescription(hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.help.PassportConfig? in
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
        return (FunctionDescription(name: "help.getPeerColors", parameters: [("hash", FunctionParameterDescription(hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.help.PeerColors? in
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
        return (FunctionDescription(name: "help.getPeerProfileColors", parameters: [("hash", FunctionParameterDescription(hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.help.PeerColors? in
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
        return (FunctionDescription(name: "help.getRecentMeUrls", parameters: [("referer", FunctionParameterDescription(referer))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.help.RecentMeUrls? in
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
        return (FunctionDescription(name: "help.getTimezonesList", parameters: [("hash", FunctionParameterDescription(hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.help.TimezonesList? in
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
        return (FunctionDescription(name: "help.getUserInfo", parameters: [("userId", FunctionParameterDescription(userId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.help.UserInfo? in
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
        return (FunctionDescription(name: "help.hidePromoData", parameters: [("peer", FunctionParameterDescription(peer))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "help.saveAppLog", parameters: [("events", FunctionParameterDescription(events))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "help.setBotUpdatesStatus", parameters: [("pendingUpdatesCount", FunctionParameterDescription(pendingUpdatesCount)), ("message", FunctionParameterDescription(message))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "langpack.getDifference", parameters: [("langPack", FunctionParameterDescription(langPack)), ("langCode", FunctionParameterDescription(langCode)), ("fromVersion", FunctionParameterDescription(fromVersion))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.LangPackDifference? in
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
        return (FunctionDescription(name: "langpack.getLangPack", parameters: [("langPack", FunctionParameterDescription(langPack)), ("langCode", FunctionParameterDescription(langCode))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.LangPackDifference? in
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
        return (FunctionDescription(name: "langpack.getLanguage", parameters: [("langPack", FunctionParameterDescription(langPack)), ("langCode", FunctionParameterDescription(langCode))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.LangPackLanguage? in
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
        return (FunctionDescription(name: "langpack.getLanguages", parameters: [("langPack", FunctionParameterDescription(langPack))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> [Api.LangPackLanguage]? in
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
        return (FunctionDescription(name: "langpack.getStrings", parameters: [("langPack", FunctionParameterDescription(langPack)), ("langCode", FunctionParameterDescription(langCode)), ("keys", FunctionParameterDescription(keys))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> [Api.LangPackString]? in
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
        return (FunctionDescription(name: "messages.acceptEncryption", parameters: [("peer", FunctionParameterDescription(peer)), ("gB", FunctionParameterDescription(gB)), ("keyFingerprint", FunctionParameterDescription(keyFingerprint))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.EncryptedChat? in
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
    static func acceptUrlAuth(flags: Int32, peer: Api.InputPeer?, msgId: Int32?, buttonId: Int32?, url: String?, matchCode: String?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.UrlAuthResult>) {
        let buffer = Buffer()
        buffer.appendInt32(1738797278)
        serializeInt32(flags, buffer: buffer, boxed: false)
        if Int(flags) & Int(1 << 1) != 0 {
            peer!.serialize(buffer, true)
        }
        if Int(flags) & Int(1 << 1) != 0 {
            serializeInt32(msgId!, buffer: buffer, boxed: false)
        }
        if Int(flags) & Int(1 << 1) != 0 {
            serializeInt32(buttonId!, buffer: buffer, boxed: false)
        }
        if Int(flags) & Int(1 << 2) != 0 {
            serializeString(url!, buffer: buffer, boxed: false)
        }
        if Int(flags) & Int(1 << 4) != 0 {
            serializeString(matchCode!, buffer: buffer, boxed: false)
        }
        return (FunctionDescription(name: "messages.acceptUrlAuth", parameters: [("flags", FunctionParameterDescription(flags)), ("peer", FunctionParameterDescription(peer)), ("msgId", FunctionParameterDescription(msgId)), ("buttonId", FunctionParameterDescription(buttonId)), ("url", FunctionParameterDescription(url)), ("matchCode", FunctionParameterDescription(matchCode))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.UrlAuthResult? in
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
        return (FunctionDescription(name: "messages.addChatUser", parameters: [("chatId", FunctionParameterDescription(chatId)), ("userId", FunctionParameterDescription(userId)), ("fwdLimit", FunctionParameterDescription(fwdLimit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.InvitedUsers? in
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
    static func addPollAnswer(peer: Api.InputPeer, msgId: Int32, answer: Api.PollAnswer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let buffer = Buffer()
        buffer.appendInt32(431770477)
        peer.serialize(buffer, true)
        serializeInt32(msgId, buffer: buffer, boxed: false)
        answer.serialize(buffer, true)
        return (FunctionDescription(name: "messages.addPollAnswer", parameters: [("peer", FunctionParameterDescription(peer)), ("msgId", FunctionParameterDescription(msgId)), ("answer", FunctionParameterDescription(answer))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        return (FunctionDescription(name: "messages.appendTodoList", parameters: [("peer", FunctionParameterDescription(peer)), ("msgId", FunctionParameterDescription(msgId)), ("list", FunctionParameterDescription(list))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        return (FunctionDescription(name: "messages.checkChatInvite", parameters: [("hash", FunctionParameterDescription(hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.ChatInvite? in
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
        return (FunctionDescription(name: "messages.checkHistoryImport", parameters: [("importHead", FunctionParameterDescription(importHead))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.HistoryImportParsed? in
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
        return (FunctionDescription(name: "messages.checkHistoryImportPeer", parameters: [("peer", FunctionParameterDescription(peer))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.CheckedHistoryImportPeer? in
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
        return (FunctionDescription(name: "messages.checkQuickReplyShortcut", parameters: [("shortcut", FunctionParameterDescription(shortcut))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
    static func checkUrlAuthMatchCode(url: String, matchCode: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let buffer = Buffer()
        buffer.appendInt32(-911967477)
        serializeString(url, buffer: buffer, boxed: false)
        serializeString(matchCode, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "messages.checkUrlAuthMatchCode", parameters: [("url", FunctionParameterDescription(url)), ("matchCode", FunctionParameterDescription(matchCode))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "messages.clearRecentStickers", parameters: [("flags", FunctionParameterDescription(flags))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "messages.clickSponsoredMessage", parameters: [("flags", FunctionParameterDescription(flags)), ("randomId", FunctionParameterDescription(randomId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
    static func composeMessageWithAI(flags: Int32, text: Api.TextWithEntities, translateToLang: String?, changeTone: String?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.ComposedMessageWithAI>) {
        let buffer = Buffer()
        buffer.appendInt32(-45978882)
        serializeInt32(flags, buffer: buffer, boxed: false)
        text.serialize(buffer, true)
        if Int(flags) & Int(1 << 1) != 0 {
            serializeString(translateToLang!, buffer: buffer, boxed: false)
        }
        if Int(flags) & Int(1 << 2) != 0 {
            serializeString(changeTone!, buffer: buffer, boxed: false)
        }
        return (FunctionDescription(name: "messages.composeMessageWithAI", parameters: [("flags", FunctionParameterDescription(flags)), ("text", FunctionParameterDescription(text)), ("translateToLang", FunctionParameterDescription(translateToLang)), ("changeTone", FunctionParameterDescription(changeTone))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.ComposedMessageWithAI? in
            let reader = BufferReader(buffer)
            var result: Api.messages.ComposedMessageWithAI?
            if let signature = reader.readInt32() {
                result = Api.parse(reader, signature: signature) as? Api.messages.ComposedMessageWithAI
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
        if Int(flags) & Int(1 << 0) != 0 {
            serializeInt32(ttlPeriod!, buffer: buffer, boxed: false)
        }
        return (FunctionDescription(name: "messages.createChat", parameters: [("flags", FunctionParameterDescription(flags)), ("users", FunctionParameterDescription(users)), ("title", FunctionParameterDescription(title)), ("ttlPeriod", FunctionParameterDescription(ttlPeriod))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.InvitedUsers? in
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
    static func createForumTopic(flags: Int32, peer: Api.InputPeer, title: String, iconColor: Int32?, iconEmojiId: Int64?, randomId: Int64, sendAs: Api.InputPeer?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let buffer = Buffer()
        buffer.appendInt32(798540757)
        serializeInt32(flags, buffer: buffer, boxed: false)
        peer.serialize(buffer, true)
        serializeString(title, buffer: buffer, boxed: false)
        if Int(flags) & Int(1 << 0) != 0 {
            serializeInt32(iconColor!, buffer: buffer, boxed: false)
        }
        if Int(flags) & Int(1 << 3) != 0 {
            serializeInt64(iconEmojiId!, buffer: buffer, boxed: false)
        }
        serializeInt64(randomId, buffer: buffer, boxed: false)
        if Int(flags) & Int(1 << 2) != 0 {
            sendAs!.serialize(buffer, true)
        }
        return (FunctionDescription(name: "messages.createForumTopic", parameters: [("flags", FunctionParameterDescription(flags)), ("peer", FunctionParameterDescription(peer)), ("title", FunctionParameterDescription(title)), ("iconColor", FunctionParameterDescription(iconColor)), ("iconEmojiId", FunctionParameterDescription(iconEmojiId)), ("randomId", FunctionParameterDescription(randomId)), ("sendAs", FunctionParameterDescription(sendAs))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
    static func declineUrlAuth(url: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let buffer = Buffer()
        buffer.appendInt32(893610940)
        serializeString(url, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "messages.declineUrlAuth", parameters: [("url", FunctionParameterDescription(url))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
    static func deleteChat(chatId: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let buffer = Buffer()
        buffer.appendInt32(1540419152)
        serializeInt64(chatId, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "messages.deleteChat", parameters: [("chatId", FunctionParameterDescription(chatId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "messages.deleteChatUser", parameters: [("flags", FunctionParameterDescription(flags)), ("chatId", FunctionParameterDescription(chatId)), ("userId", FunctionParameterDescription(userId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        return (FunctionDescription(name: "messages.deleteExportedChatInvite", parameters: [("peer", FunctionParameterDescription(peer)), ("link", FunctionParameterDescription(link))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "messages.deleteFactCheck", parameters: [("peer", FunctionParameterDescription(peer)), ("msgId", FunctionParameterDescription(msgId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        if Int(flags) & Int(1 << 2) != 0 {
            serializeInt32(minDate!, buffer: buffer, boxed: false)
        }
        if Int(flags) & Int(1 << 3) != 0 {
            serializeInt32(maxDate!, buffer: buffer, boxed: false)
        }
        return (FunctionDescription(name: "messages.deleteHistory", parameters: [("flags", FunctionParameterDescription(flags)), ("peer", FunctionParameterDescription(peer)), ("maxId", FunctionParameterDescription(maxId)), ("minDate", FunctionParameterDescription(minDate)), ("maxDate", FunctionParameterDescription(maxDate))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.AffectedHistory? in
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
        return (FunctionDescription(name: "messages.deleteMessages", parameters: [("flags", FunctionParameterDescription(flags)), ("id", FunctionParameterDescription(id))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.AffectedMessages? in
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
        return (FunctionDescription(name: "messages.deletePhoneCallHistory", parameters: [("flags", FunctionParameterDescription(flags))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.AffectedFoundMessages? in
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
    static func deletePollAnswer(peer: Api.InputPeer, msgId: Int32, option: Buffer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let buffer = Buffer()
        buffer.appendInt32(-1400568411)
        peer.serialize(buffer, true)
        serializeInt32(msgId, buffer: buffer, boxed: false)
        serializeBytes(option, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "messages.deletePollAnswer", parameters: [("peer", FunctionParameterDescription(peer)), ("msgId", FunctionParameterDescription(msgId)), ("option", FunctionParameterDescription(option))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
    static func deleteQuickReplyMessages(shortcutId: Int32, id: [Int32]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let buffer = Buffer()
        buffer.appendInt32(-519706352)
        serializeInt32(shortcutId, buffer: buffer, boxed: false)
        buffer.appendInt32(481674261)
        buffer.appendInt32(Int32(id.count))
        for item in id {
            serializeInt32(item, buffer: buffer, boxed: false)
        }
        return (FunctionDescription(name: "messages.deleteQuickReplyMessages", parameters: [("shortcutId", FunctionParameterDescription(shortcutId)), ("id", FunctionParameterDescription(id))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        return (FunctionDescription(name: "messages.deleteQuickReplyShortcut", parameters: [("shortcutId", FunctionParameterDescription(shortcutId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "messages.deleteRevokedExportedChatInvites", parameters: [("peer", FunctionParameterDescription(peer)), ("adminId", FunctionParameterDescription(adminId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        if Int(flags) & Int(1 << 0) != 0 {
            parentPeer!.serialize(buffer, true)
        }
        peer.serialize(buffer, true)
        serializeInt32(maxId, buffer: buffer, boxed: false)
        if Int(flags) & Int(1 << 2) != 0 {
            serializeInt32(minDate!, buffer: buffer, boxed: false)
        }
        if Int(flags) & Int(1 << 3) != 0 {
            serializeInt32(maxDate!, buffer: buffer, boxed: false)
        }
        return (FunctionDescription(name: "messages.deleteSavedHistory", parameters: [("flags", FunctionParameterDescription(flags)), ("parentPeer", FunctionParameterDescription(parentPeer)), ("peer", FunctionParameterDescription(peer)), ("maxId", FunctionParameterDescription(maxId)), ("minDate", FunctionParameterDescription(minDate)), ("maxDate", FunctionParameterDescription(maxDate))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.AffectedHistory? in
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
        return (FunctionDescription(name: "messages.deleteScheduledMessages", parameters: [("peer", FunctionParameterDescription(peer)), ("id", FunctionParameterDescription(id))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
    static func deleteTopicHistory(peer: Api.InputPeer, topMsgId: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.AffectedHistory>) {
        let buffer = Buffer()
        buffer.appendInt32(-763269360)
        peer.serialize(buffer, true)
        serializeInt32(topMsgId, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "messages.deleteTopicHistory", parameters: [("peer", FunctionParameterDescription(peer)), ("topMsgId", FunctionParameterDescription(topMsgId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.AffectedHistory? in
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
    static func discardEncryption(flags: Int32, chatId: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let buffer = Buffer()
        buffer.appendInt32(-208425312)
        serializeInt32(flags, buffer: buffer, boxed: false)
        serializeInt32(chatId, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "messages.discardEncryption", parameters: [("flags", FunctionParameterDescription(flags)), ("chatId", FunctionParameterDescription(chatId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "messages.editChatAbout", parameters: [("peer", FunctionParameterDescription(peer)), ("about", FunctionParameterDescription(about))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "messages.editChatAdmin", parameters: [("chatId", FunctionParameterDescription(chatId)), ("userId", FunctionParameterDescription(userId)), ("isAdmin", FunctionParameterDescription(isAdmin))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
    static func editChatCreator(peer: Api.InputPeer, userId: Api.InputUser, password: Api.InputCheckPasswordSRP) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let buffer = Buffer()
        buffer.appendInt32(-146556841)
        peer.serialize(buffer, true)
        userId.serialize(buffer, true)
        password.serialize(buffer, true)
        return (FunctionDescription(name: "messages.editChatCreator", parameters: [("peer", FunctionParameterDescription(peer)), ("userId", FunctionParameterDescription(userId)), ("password", FunctionParameterDescription(password))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
    static func editChatDefaultBannedRights(peer: Api.InputPeer, bannedRights: Api.ChatBannedRights) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let buffer = Buffer()
        buffer.appendInt32(-1517917375)
        peer.serialize(buffer, true)
        bannedRights.serialize(buffer, true)
        return (FunctionDescription(name: "messages.editChatDefaultBannedRights", parameters: [("peer", FunctionParameterDescription(peer)), ("bannedRights", FunctionParameterDescription(bannedRights))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
    static func editChatParticipantRank(peer: Api.InputPeer, participant: Api.InputPeer, rank: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let buffer = Buffer()
        buffer.appendInt32(-1609616720)
        peer.serialize(buffer, true)
        participant.serialize(buffer, true)
        serializeString(rank, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "messages.editChatParticipantRank", parameters: [("peer", FunctionParameterDescription(peer)), ("participant", FunctionParameterDescription(participant)), ("rank", FunctionParameterDescription(rank))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        return (FunctionDescription(name: "messages.editChatPhoto", parameters: [("chatId", FunctionParameterDescription(chatId)), ("photo", FunctionParameterDescription(photo))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        return (FunctionDescription(name: "messages.editChatTitle", parameters: [("chatId", FunctionParameterDescription(chatId)), ("title", FunctionParameterDescription(title))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        if Int(flags) & Int(1 << 0) != 0 {
            serializeInt32(expireDate!, buffer: buffer, boxed: false)
        }
        if Int(flags) & Int(1 << 1) != 0 {
            serializeInt32(usageLimit!, buffer: buffer, boxed: false)
        }
        if Int(flags) & Int(1 << 3) != 0 {
            requestNeeded!.serialize(buffer, true)
        }
        if Int(flags) & Int(1 << 4) != 0 {
            serializeString(title!, buffer: buffer, boxed: false)
        }
        return (FunctionDescription(name: "messages.editExportedChatInvite", parameters: [("flags", FunctionParameterDescription(flags)), ("peer", FunctionParameterDescription(peer)), ("link", FunctionParameterDescription(link)), ("expireDate", FunctionParameterDescription(expireDate)), ("usageLimit", FunctionParameterDescription(usageLimit)), ("requestNeeded", FunctionParameterDescription(requestNeeded)), ("title", FunctionParameterDescription(title))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.ExportedChatInvite? in
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
        return (FunctionDescription(name: "messages.editFactCheck", parameters: [("peer", FunctionParameterDescription(peer)), ("msgId", FunctionParameterDescription(msgId)), ("text", FunctionParameterDescription(text))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
    static func editForumTopic(flags: Int32, peer: Api.InputPeer, topicId: Int32, title: String?, iconEmojiId: Int64?, closed: Api.Bool?, hidden: Api.Bool?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let buffer = Buffer()
        buffer.appendInt32(-825487052)
        serializeInt32(flags, buffer: buffer, boxed: false)
        peer.serialize(buffer, true)
        serializeInt32(topicId, buffer: buffer, boxed: false)
        if Int(flags) & Int(1 << 0) != 0 {
            serializeString(title!, buffer: buffer, boxed: false)
        }
        if Int(flags) & Int(1 << 1) != 0 {
            serializeInt64(iconEmojiId!, buffer: buffer, boxed: false)
        }
        if Int(flags) & Int(1 << 2) != 0 {
            closed!.serialize(buffer, true)
        }
        if Int(flags) & Int(1 << 3) != 0 {
            hidden!.serialize(buffer, true)
        }
        return (FunctionDescription(name: "messages.editForumTopic", parameters: [("flags", FunctionParameterDescription(flags)), ("peer", FunctionParameterDescription(peer)), ("topicId", FunctionParameterDescription(topicId)), ("title", FunctionParameterDescription(title)), ("iconEmojiId", FunctionParameterDescription(iconEmojiId)), ("closed", FunctionParameterDescription(closed)), ("hidden", FunctionParameterDescription(hidden))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        if Int(flags) & Int(1 << 11) != 0 {
            serializeString(message!, buffer: buffer, boxed: false)
        }
        if Int(flags) & Int(1 << 14) != 0 {
            media!.serialize(buffer, true)
        }
        if Int(flags) & Int(1 << 2) != 0 {
            replyMarkup!.serialize(buffer, true)
        }
        if Int(flags) & Int(1 << 3) != 0 {
            buffer.appendInt32(481674261)
            buffer.appendInt32(Int32(entities!.count))
            for item in entities! {
                item.serialize(buffer, true)
            }
        }
        return (FunctionDescription(name: "messages.editInlineBotMessage", parameters: [("flags", FunctionParameterDescription(flags)), ("id", FunctionParameterDescription(id)), ("message", FunctionParameterDescription(message)), ("media", FunctionParameterDescription(media)), ("replyMarkup", FunctionParameterDescription(replyMarkup)), ("entities", FunctionParameterDescription(entities))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
    static func editMessage(flags: Int32, peer: Api.InputPeer, id: Int32, message: String?, media: Api.InputMedia?, replyMarkup: Api.ReplyMarkup?, entities: [Api.MessageEntity]?, scheduleDate: Int32?, scheduleRepeatPeriod: Int32?, quickReplyShortcutId: Int32?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let buffer = Buffer()
        buffer.appendInt32(1374175969)
        serializeInt32(flags, buffer: buffer, boxed: false)
        peer.serialize(buffer, true)
        serializeInt32(id, buffer: buffer, boxed: false)
        if Int(flags) & Int(1 << 11) != 0 {
            serializeString(message!, buffer: buffer, boxed: false)
        }
        if Int(flags) & Int(1 << 14) != 0 {
            media!.serialize(buffer, true)
        }
        if Int(flags) & Int(1 << 2) != 0 {
            replyMarkup!.serialize(buffer, true)
        }
        if Int(flags) & Int(1 << 3) != 0 {
            buffer.appendInt32(481674261)
            buffer.appendInt32(Int32(entities!.count))
            for item in entities! {
                item.serialize(buffer, true)
            }
        }
        if Int(flags) & Int(1 << 15) != 0 {
            serializeInt32(scheduleDate!, buffer: buffer, boxed: false)
        }
        if Int(flags) & Int(1 << 18) != 0 {
            serializeInt32(scheduleRepeatPeriod!, buffer: buffer, boxed: false)
        }
        if Int(flags) & Int(1 << 17) != 0 {
            serializeInt32(quickReplyShortcutId!, buffer: buffer, boxed: false)
        }
        return (FunctionDescription(name: "messages.editMessage", parameters: [("flags", FunctionParameterDescription(flags)), ("peer", FunctionParameterDescription(peer)), ("id", FunctionParameterDescription(id)), ("message", FunctionParameterDescription(message)), ("media", FunctionParameterDescription(media)), ("replyMarkup", FunctionParameterDescription(replyMarkup)), ("entities", FunctionParameterDescription(entities)), ("scheduleDate", FunctionParameterDescription(scheduleDate)), ("scheduleRepeatPeriod", FunctionParameterDescription(scheduleRepeatPeriod)), ("quickReplyShortcutId", FunctionParameterDescription(quickReplyShortcutId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        return (FunctionDescription(name: "messages.editQuickReplyShortcut", parameters: [("shortcutId", FunctionParameterDescription(shortcutId)), ("shortcut", FunctionParameterDescription(shortcut))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        if Int(flags) & Int(1 << 0) != 0 {
            serializeInt32(expireDate!, buffer: buffer, boxed: false)
        }
        if Int(flags) & Int(1 << 1) != 0 {
            serializeInt32(usageLimit!, buffer: buffer, boxed: false)
        }
        if Int(flags) & Int(1 << 4) != 0 {
            serializeString(title!, buffer: buffer, boxed: false)
        }
        if Int(flags) & Int(1 << 5) != 0 {
            subscriptionPricing!.serialize(buffer, true)
        }
        return (FunctionDescription(name: "messages.exportChatInvite", parameters: [("flags", FunctionParameterDescription(flags)), ("peer", FunctionParameterDescription(peer)), ("expireDate", FunctionParameterDescription(expireDate)), ("usageLimit", FunctionParameterDescription(usageLimit)), ("title", FunctionParameterDescription(title)), ("subscriptionPricing", FunctionParameterDescription(subscriptionPricing))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.ExportedChatInvite? in
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
        return (FunctionDescription(name: "messages.faveSticker", parameters: [("id", FunctionParameterDescription(id)), ("unfave", FunctionParameterDescription(unfave))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
    static func forwardMessages(flags: Int32, fromPeer: Api.InputPeer, id: [Int32], randomId: [Int64], toPeer: Api.InputPeer, topMsgId: Int32?, replyTo: Api.InputReplyTo?, scheduleDate: Int32?, scheduleRepeatPeriod: Int32?, sendAs: Api.InputPeer?, quickReplyShortcut: Api.InputQuickReplyShortcut?, effect: Int64?, videoTimestamp: Int32?, allowPaidStars: Int64?, suggestedPost: Api.SuggestedPost?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let buffer = Buffer()
        buffer.appendInt32(326126204)
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
        if Int(flags) & Int(1 << 9) != 0 {
            serializeInt32(topMsgId!, buffer: buffer, boxed: false)
        }
        if Int(flags) & Int(1 << 22) != 0 {
            replyTo!.serialize(buffer, true)
        }
        if Int(flags) & Int(1 << 10) != 0 {
            serializeInt32(scheduleDate!, buffer: buffer, boxed: false)
        }
        if Int(flags) & Int(1 << 24) != 0 {
            serializeInt32(scheduleRepeatPeriod!, buffer: buffer, boxed: false)
        }
        if Int(flags) & Int(1 << 13) != 0 {
            sendAs!.serialize(buffer, true)
        }
        if Int(flags) & Int(1 << 17) != 0 {
            quickReplyShortcut!.serialize(buffer, true)
        }
        if Int(flags) & Int(1 << 18) != 0 {
            serializeInt64(effect!, buffer: buffer, boxed: false)
        }
        if Int(flags) & Int(1 << 20) != 0 {
            serializeInt32(videoTimestamp!, buffer: buffer, boxed: false)
        }
        if Int(flags) & Int(1 << 21) != 0 {
            serializeInt64(allowPaidStars!, buffer: buffer, boxed: false)
        }
        if Int(flags) & Int(1 << 23) != 0 {
            suggestedPost!.serialize(buffer, true)
        }
        return (FunctionDescription(name: "messages.forwardMessages", parameters: [("flags", FunctionParameterDescription(flags)), ("fromPeer", FunctionParameterDescription(fromPeer)), ("id", FunctionParameterDescription(id)), ("randomId", FunctionParameterDescription(randomId)), ("toPeer", FunctionParameterDescription(toPeer)), ("topMsgId", FunctionParameterDescription(topMsgId)), ("replyTo", FunctionParameterDescription(replyTo)), ("scheduleDate", FunctionParameterDescription(scheduleDate)), ("scheduleRepeatPeriod", FunctionParameterDescription(scheduleRepeatPeriod)), ("sendAs", FunctionParameterDescription(sendAs)), ("quickReplyShortcut", FunctionParameterDescription(quickReplyShortcut)), ("effect", FunctionParameterDescription(effect)), ("videoTimestamp", FunctionParameterDescription(videoTimestamp)), ("allowPaidStars", FunctionParameterDescription(allowPaidStars)), ("suggestedPost", FunctionParameterDescription(suggestedPost))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        return (FunctionDescription(name: "messages.getAdminsWithInvites", parameters: [("peer", FunctionParameterDescription(peer))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.ChatAdminsWithInvites? in
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
        return (FunctionDescription(name: "messages.getAllStickers", parameters: [("hash", FunctionParameterDescription(hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.AllStickers? in
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
        return (FunctionDescription(name: "messages.getArchivedStickers", parameters: [("flags", FunctionParameterDescription(flags)), ("offsetId", FunctionParameterDescription(offsetId)), ("limit", FunctionParameterDescription(limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.ArchivedStickers? in
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
        return (FunctionDescription(name: "messages.getAttachMenuBot", parameters: [("bot", FunctionParameterDescription(bot))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.AttachMenuBotsBot? in
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
        return (FunctionDescription(name: "messages.getAttachMenuBots", parameters: [("hash", FunctionParameterDescription(hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.AttachMenuBots? in
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
        return (FunctionDescription(name: "messages.getAttachedStickers", parameters: [("media", FunctionParameterDescription(media))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> [Api.StickerSetCovered]? in
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
        return (FunctionDescription(name: "messages.getAvailableEffects", parameters: [("hash", FunctionParameterDescription(hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.AvailableEffects? in
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
        return (FunctionDescription(name: "messages.getAvailableReactions", parameters: [("hash", FunctionParameterDescription(hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.AvailableReactions? in
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
        return (FunctionDescription(name: "messages.getBotApp", parameters: [("app", FunctionParameterDescription(app)), ("hash", FunctionParameterDescription(hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.BotApp? in
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
        if Int(flags) & Int(1 << 0) != 0 {
            serializeBytes(data!, buffer: buffer, boxed: false)
        }
        if Int(flags) & Int(1 << 2) != 0 {
            password!.serialize(buffer, true)
        }
        return (FunctionDescription(name: "messages.getBotCallbackAnswer", parameters: [("flags", FunctionParameterDescription(flags)), ("peer", FunctionParameterDescription(peer)), ("msgId", FunctionParameterDescription(msgId)), ("data", FunctionParameterDescription(data)), ("password", FunctionParameterDescription(password))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.BotCallbackAnswer? in
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
        if Int(flags) & Int(1 << 1) != 0 {
            serializeString(link!, buffer: buffer, boxed: false)
        }
        if Int(flags) & Int(1 << 2) != 0 {
            serializeString(q!, buffer: buffer, boxed: false)
        }
        serializeInt32(offsetDate, buffer: buffer, boxed: false)
        offsetUser.serialize(buffer, true)
        serializeInt32(limit, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "messages.getChatInviteImporters", parameters: [("flags", FunctionParameterDescription(flags)), ("peer", FunctionParameterDescription(peer)), ("link", FunctionParameterDescription(link)), ("q", FunctionParameterDescription(q)), ("offsetDate", FunctionParameterDescription(offsetDate)), ("offsetUser", FunctionParameterDescription(offsetUser)), ("limit", FunctionParameterDescription(limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.ChatInviteImporters? in
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
        return (FunctionDescription(name: "messages.getChats", parameters: [("id", FunctionParameterDescription(id))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.Chats? in
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
        return (FunctionDescription(name: "messages.getCommonChats", parameters: [("userId", FunctionParameterDescription(userId)), ("maxId", FunctionParameterDescription(maxId)), ("limit", FunctionParameterDescription(limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.Chats? in
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
        return (FunctionDescription(name: "messages.getCustomEmojiDocuments", parameters: [("documentId", FunctionParameterDescription(documentId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> [Api.Document]? in
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
        return (FunctionDescription(name: "messages.getDefaultTagReactions", parameters: [("hash", FunctionParameterDescription(hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.Reactions? in
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
        return (FunctionDescription(name: "messages.getDhConfig", parameters: [("version", FunctionParameterDescription(version)), ("randomLength", FunctionParameterDescription(randomLength))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.DhConfig? in
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
        if Int(flags) & Int(1 << 0) != 0 {
            parentPeer!.serialize(buffer, true)
        }
        return (FunctionDescription(name: "messages.getDialogUnreadMarks", parameters: [("flags", FunctionParameterDescription(flags)), ("parentPeer", FunctionParameterDescription(parentPeer))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> [Api.DialogPeer]? in
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
        if Int(flags) & Int(1 << 1) != 0 {
            serializeInt32(folderId!, buffer: buffer, boxed: false)
        }
        serializeInt32(offsetDate, buffer: buffer, boxed: false)
        serializeInt32(offsetId, buffer: buffer, boxed: false)
        offsetPeer.serialize(buffer, true)
        serializeInt32(limit, buffer: buffer, boxed: false)
        serializeInt64(hash, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "messages.getDialogs", parameters: [("flags", FunctionParameterDescription(flags)), ("folderId", FunctionParameterDescription(folderId)), ("offsetDate", FunctionParameterDescription(offsetDate)), ("offsetId", FunctionParameterDescription(offsetId)), ("offsetPeer", FunctionParameterDescription(offsetPeer)), ("limit", FunctionParameterDescription(limit)), ("hash", FunctionParameterDescription(hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.Dialogs? in
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
        return (FunctionDescription(name: "messages.getDiscussionMessage", parameters: [("peer", FunctionParameterDescription(peer)), ("msgId", FunctionParameterDescription(msgId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.DiscussionMessage? in
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
        return (FunctionDescription(name: "messages.getDocumentByHash", parameters: [("sha256", FunctionParameterDescription(sha256)), ("size", FunctionParameterDescription(size)), ("mimeType", FunctionParameterDescription(mimeType))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Document? in
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
    static func getEmojiGameInfo() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.EmojiGameInfo>) {
        let buffer = Buffer()
        buffer.appendInt32(-75592537)
        return (FunctionDescription(name: "messages.getEmojiGameInfo", parameters: []), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.EmojiGameInfo? in
            let reader = BufferReader(buffer)
            var result: Api.messages.EmojiGameInfo?
            if let signature = reader.readInt32() {
                result = Api.parse(reader, signature: signature) as? Api.messages.EmojiGameInfo
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
        return (FunctionDescription(name: "messages.getEmojiGroups", parameters: [("hash", FunctionParameterDescription(hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.EmojiGroups? in
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
        return (FunctionDescription(name: "messages.getEmojiKeywords", parameters: [("langCode", FunctionParameterDescription(langCode))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.EmojiKeywordsDifference? in
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
        return (FunctionDescription(name: "messages.getEmojiKeywordsDifference", parameters: [("langCode", FunctionParameterDescription(langCode)), ("fromVersion", FunctionParameterDescription(fromVersion))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.EmojiKeywordsDifference? in
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
        return (FunctionDescription(name: "messages.getEmojiKeywordsLanguages", parameters: [("langCodes", FunctionParameterDescription(langCodes))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> [Api.EmojiLanguage]? in
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
        return (FunctionDescription(name: "messages.getEmojiProfilePhotoGroups", parameters: [("hash", FunctionParameterDescription(hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.EmojiGroups? in
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
        return (FunctionDescription(name: "messages.getEmojiStatusGroups", parameters: [("hash", FunctionParameterDescription(hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.EmojiGroups? in
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
        return (FunctionDescription(name: "messages.getEmojiStickerGroups", parameters: [("hash", FunctionParameterDescription(hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.EmojiGroups? in
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
        return (FunctionDescription(name: "messages.getEmojiStickers", parameters: [("hash", FunctionParameterDescription(hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.AllStickers? in
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
        return (FunctionDescription(name: "messages.getEmojiURL", parameters: [("langCode", FunctionParameterDescription(langCode))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.EmojiURL? in
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
        return (FunctionDescription(name: "messages.getExportedChatInvite", parameters: [("peer", FunctionParameterDescription(peer)), ("link", FunctionParameterDescription(link))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.ExportedChatInvite? in
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
        if Int(flags) & Int(1 << 2) != 0 {
            serializeInt32(offsetDate!, buffer: buffer, boxed: false)
        }
        if Int(flags) & Int(1 << 2) != 0 {
            serializeString(offsetLink!, buffer: buffer, boxed: false)
        }
        serializeInt32(limit, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "messages.getExportedChatInvites", parameters: [("flags", FunctionParameterDescription(flags)), ("peer", FunctionParameterDescription(peer)), ("adminId", FunctionParameterDescription(adminId)), ("offsetDate", FunctionParameterDescription(offsetDate)), ("offsetLink", FunctionParameterDescription(offsetLink)), ("limit", FunctionParameterDescription(limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.ExportedChatInvites? in
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
        return (FunctionDescription(name: "messages.getExtendedMedia", parameters: [("peer", FunctionParameterDescription(peer)), ("id", FunctionParameterDescription(id))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        return (FunctionDescription(name: "messages.getFactCheck", parameters: [("peer", FunctionParameterDescription(peer)), ("msgId", FunctionParameterDescription(msgId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> [Api.FactCheck]? in
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
        return (FunctionDescription(name: "messages.getFavedStickers", parameters: [("hash", FunctionParameterDescription(hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.FavedStickers? in
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
        return (FunctionDescription(name: "messages.getFeaturedEmojiStickers", parameters: [("hash", FunctionParameterDescription(hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.FeaturedStickers? in
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
        return (FunctionDescription(name: "messages.getFeaturedStickers", parameters: [("hash", FunctionParameterDescription(hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.FeaturedStickers? in
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
    static func getForumTopics(flags: Int32, peer: Api.InputPeer, q: String?, offsetDate: Int32, offsetId: Int32, offsetTopic: Int32, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.ForumTopics>) {
        let buffer = Buffer()
        buffer.appendInt32(1000635391)
        serializeInt32(flags, buffer: buffer, boxed: false)
        peer.serialize(buffer, true)
        if Int(flags) & Int(1 << 0) != 0 {
            serializeString(q!, buffer: buffer, boxed: false)
        }
        serializeInt32(offsetDate, buffer: buffer, boxed: false)
        serializeInt32(offsetId, buffer: buffer, boxed: false)
        serializeInt32(offsetTopic, buffer: buffer, boxed: false)
        serializeInt32(limit, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "messages.getForumTopics", parameters: [("flags", FunctionParameterDescription(flags)), ("peer", FunctionParameterDescription(peer)), ("q", FunctionParameterDescription(q)), ("offsetDate", FunctionParameterDescription(offsetDate)), ("offsetId", FunctionParameterDescription(offsetId)), ("offsetTopic", FunctionParameterDescription(offsetTopic)), ("limit", FunctionParameterDescription(limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.ForumTopics? in
            let reader = BufferReader(buffer)
            var result: Api.messages.ForumTopics?
            if let signature = reader.readInt32() {
                result = Api.parse(reader, signature: signature) as? Api.messages.ForumTopics
            }
            return result
        })
    }
}
public extension Api.functions.messages {
    static func getForumTopicsByID(peer: Api.InputPeer, topics: [Int32]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.ForumTopics>) {
        let buffer = Buffer()
        buffer.appendInt32(-1358280184)
        peer.serialize(buffer, true)
        buffer.appendInt32(481674261)
        buffer.appendInt32(Int32(topics.count))
        for item in topics {
            serializeInt32(item, buffer: buffer, boxed: false)
        }
        return (FunctionDescription(name: "messages.getForumTopicsByID", parameters: [("peer", FunctionParameterDescription(peer)), ("topics", FunctionParameterDescription(topics))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.ForumTopics? in
            let reader = BufferReader(buffer)
            var result: Api.messages.ForumTopics?
            if let signature = reader.readInt32() {
                result = Api.parse(reader, signature: signature) as? Api.messages.ForumTopics
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
        return (FunctionDescription(name: "messages.getFullChat", parameters: [("chatId", FunctionParameterDescription(chatId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.ChatFull? in
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
    static func getFutureChatCreatorAfterLeave(peer: Api.InputPeer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.User>) {
        let buffer = Buffer()
        buffer.appendInt32(998051494)
        peer.serialize(buffer, true)
        return (FunctionDescription(name: "messages.getFutureChatCreatorAfterLeave", parameters: [("peer", FunctionParameterDescription(peer))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.User? in
            let reader = BufferReader(buffer)
            var result: Api.User?
            if let signature = reader.readInt32() {
                result = Api.parse(reader, signature: signature) as? Api.User
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
        return (FunctionDescription(name: "messages.getGameHighScores", parameters: [("peer", FunctionParameterDescription(peer)), ("id", FunctionParameterDescription(id)), ("userId", FunctionParameterDescription(userId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.HighScores? in
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
        return (FunctionDescription(name: "messages.getHistory", parameters: [("peer", FunctionParameterDescription(peer)), ("offsetId", FunctionParameterDescription(offsetId)), ("offsetDate", FunctionParameterDescription(offsetDate)), ("addOffset", FunctionParameterDescription(addOffset)), ("limit", FunctionParameterDescription(limit)), ("maxId", FunctionParameterDescription(maxId)), ("minId", FunctionParameterDescription(minId)), ("hash", FunctionParameterDescription(hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.Messages? in
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
        if Int(flags) & Int(1 << 0) != 0 {
            geoPoint!.serialize(buffer, true)
        }
        serializeString(query, buffer: buffer, boxed: false)
        serializeString(offset, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "messages.getInlineBotResults", parameters: [("flags", FunctionParameterDescription(flags)), ("bot", FunctionParameterDescription(bot)), ("peer", FunctionParameterDescription(peer)), ("geoPoint", FunctionParameterDescription(geoPoint)), ("query", FunctionParameterDescription(query)), ("offset", FunctionParameterDescription(offset))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.BotResults? in
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
        return (FunctionDescription(name: "messages.getInlineGameHighScores", parameters: [("id", FunctionParameterDescription(id)), ("userId", FunctionParameterDescription(userId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.HighScores? in
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
        return (FunctionDescription(name: "messages.getMaskStickers", parameters: [("hash", FunctionParameterDescription(hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.AllStickers? in
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
        return (FunctionDescription(name: "messages.getMessageEditData", parameters: [("peer", FunctionParameterDescription(peer)), ("id", FunctionParameterDescription(id))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.MessageEditData? in
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
        if Int(flags) & Int(1 << 0) != 0 {
            reaction!.serialize(buffer, true)
        }
        if Int(flags) & Int(1 << 1) != 0 {
            serializeString(offset!, buffer: buffer, boxed: false)
        }
        serializeInt32(limit, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "messages.getMessageReactionsList", parameters: [("flags", FunctionParameterDescription(flags)), ("peer", FunctionParameterDescription(peer)), ("id", FunctionParameterDescription(id)), ("reaction", FunctionParameterDescription(reaction)), ("offset", FunctionParameterDescription(offset)), ("limit", FunctionParameterDescription(limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.MessageReactionsList? in
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
        return (FunctionDescription(name: "messages.getMessageReadParticipants", parameters: [("peer", FunctionParameterDescription(peer)), ("msgId", FunctionParameterDescription(msgId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> [Api.ReadParticipantDate]? in
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
        return (FunctionDescription(name: "messages.getMessages", parameters: [("id", FunctionParameterDescription(id))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.Messages? in
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
        return (FunctionDescription(name: "messages.getMessagesReactions", parameters: [("peer", FunctionParameterDescription(peer)), ("id", FunctionParameterDescription(id))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        return (FunctionDescription(name: "messages.getMessagesViews", parameters: [("peer", FunctionParameterDescription(peer)), ("id", FunctionParameterDescription(id)), ("increment", FunctionParameterDescription(increment))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.MessageViews? in
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
        return (FunctionDescription(name: "messages.getMyStickers", parameters: [("offsetId", FunctionParameterDescription(offsetId)), ("limit", FunctionParameterDescription(limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.MyStickers? in
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
        return (FunctionDescription(name: "messages.getOldFeaturedStickers", parameters: [("offset", FunctionParameterDescription(offset)), ("limit", FunctionParameterDescription(limit)), ("hash", FunctionParameterDescription(hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.FeaturedStickers? in
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
        return (FunctionDescription(name: "messages.getOnlines", parameters: [("peer", FunctionParameterDescription(peer))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.ChatOnlines? in
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
        return (FunctionDescription(name: "messages.getOutboxReadDate", parameters: [("peer", FunctionParameterDescription(peer)), ("msgId", FunctionParameterDescription(msgId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.OutboxReadDate? in
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
        return (FunctionDescription(name: "messages.getPeerDialogs", parameters: [("peers", FunctionParameterDescription(peers))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.PeerDialogs? in
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
        return (FunctionDescription(name: "messages.getPeerSettings", parameters: [("peer", FunctionParameterDescription(peer))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.PeerSettings? in
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
        return (FunctionDescription(name: "messages.getPinnedDialogs", parameters: [("folderId", FunctionParameterDescription(folderId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.PeerDialogs? in
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
    static func getPollResults(peer: Api.InputPeer, msgId: Int32, pollHash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let buffer = Buffer()
        buffer.appendInt32(-308026565)
        peer.serialize(buffer, true)
        serializeInt32(msgId, buffer: buffer, boxed: false)
        serializeInt64(pollHash, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "messages.getPollResults", parameters: [("peer", FunctionParameterDescription(peer)), ("msgId", FunctionParameterDescription(msgId)), ("pollHash", FunctionParameterDescription(pollHash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        if Int(flags) & Int(1 << 0) != 0 {
            serializeBytes(option!, buffer: buffer, boxed: false)
        }
        if Int(flags) & Int(1 << 1) != 0 {
            serializeString(offset!, buffer: buffer, boxed: false)
        }
        serializeInt32(limit, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "messages.getPollVotes", parameters: [("flags", FunctionParameterDescription(flags)), ("peer", FunctionParameterDescription(peer)), ("id", FunctionParameterDescription(id)), ("option", FunctionParameterDescription(option)), ("offset", FunctionParameterDescription(offset)), ("limit", FunctionParameterDescription(limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.VotesList? in
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
        return (FunctionDescription(name: "messages.getPreparedInlineMessage", parameters: [("bot", FunctionParameterDescription(bot)), ("id", FunctionParameterDescription(id))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.PreparedInlineMessage? in
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
        return (FunctionDescription(name: "messages.getQuickReplies", parameters: [("hash", FunctionParameterDescription(hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.QuickReplies? in
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
        if Int(flags) & Int(1 << 0) != 0 {
            buffer.appendInt32(481674261)
            buffer.appendInt32(Int32(id!.count))
            for item in id! {
                serializeInt32(item, buffer: buffer, boxed: false)
            }
        }
        serializeInt64(hash, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "messages.getQuickReplyMessages", parameters: [("flags", FunctionParameterDescription(flags)), ("shortcutId", FunctionParameterDescription(shortcutId)), ("id", FunctionParameterDescription(id)), ("hash", FunctionParameterDescription(hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.Messages? in
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
        return (FunctionDescription(name: "messages.getRecentLocations", parameters: [("peer", FunctionParameterDescription(peer)), ("limit", FunctionParameterDescription(limit)), ("hash", FunctionParameterDescription(hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.Messages? in
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
        return (FunctionDescription(name: "messages.getRecentReactions", parameters: [("limit", FunctionParameterDescription(limit)), ("hash", FunctionParameterDescription(hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.Reactions? in
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
        return (FunctionDescription(name: "messages.getRecentStickers", parameters: [("flags", FunctionParameterDescription(flags)), ("hash", FunctionParameterDescription(hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.RecentStickers? in
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
        return (FunctionDescription(name: "messages.getReplies", parameters: [("peer", FunctionParameterDescription(peer)), ("msgId", FunctionParameterDescription(msgId)), ("offsetId", FunctionParameterDescription(offsetId)), ("offsetDate", FunctionParameterDescription(offsetDate)), ("addOffset", FunctionParameterDescription(addOffset)), ("limit", FunctionParameterDescription(limit)), ("maxId", FunctionParameterDescription(maxId)), ("minId", FunctionParameterDescription(minId)), ("hash", FunctionParameterDescription(hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.Messages? in
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
        if Int(flags) & Int(1 << 1) != 0 {
            parentPeer!.serialize(buffer, true)
        }
        serializeInt32(offsetDate, buffer: buffer, boxed: false)
        serializeInt32(offsetId, buffer: buffer, boxed: false)
        offsetPeer.serialize(buffer, true)
        serializeInt32(limit, buffer: buffer, boxed: false)
        serializeInt64(hash, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "messages.getSavedDialogs", parameters: [("flags", FunctionParameterDescription(flags)), ("parentPeer", FunctionParameterDescription(parentPeer)), ("offsetDate", FunctionParameterDescription(offsetDate)), ("offsetId", FunctionParameterDescription(offsetId)), ("offsetPeer", FunctionParameterDescription(offsetPeer)), ("limit", FunctionParameterDescription(limit)), ("hash", FunctionParameterDescription(hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.SavedDialogs? in
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
        if Int(flags) & Int(1 << 1) != 0 {
            parentPeer!.serialize(buffer, true)
        }
        buffer.appendInt32(481674261)
        buffer.appendInt32(Int32(ids.count))
        for item in ids {
            item.serialize(buffer, true)
        }
        return (FunctionDescription(name: "messages.getSavedDialogsByID", parameters: [("flags", FunctionParameterDescription(flags)), ("parentPeer", FunctionParameterDescription(parentPeer)), ("ids", FunctionParameterDescription(ids))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.SavedDialogs? in
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
        return (FunctionDescription(name: "messages.getSavedGifs", parameters: [("hash", FunctionParameterDescription(hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.SavedGifs? in
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
        if Int(flags) & Int(1 << 0) != 0 {
            parentPeer!.serialize(buffer, true)
        }
        peer.serialize(buffer, true)
        serializeInt32(offsetId, buffer: buffer, boxed: false)
        serializeInt32(offsetDate, buffer: buffer, boxed: false)
        serializeInt32(addOffset, buffer: buffer, boxed: false)
        serializeInt32(limit, buffer: buffer, boxed: false)
        serializeInt32(maxId, buffer: buffer, boxed: false)
        serializeInt32(minId, buffer: buffer, boxed: false)
        serializeInt64(hash, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "messages.getSavedHistory", parameters: [("flags", FunctionParameterDescription(flags)), ("parentPeer", FunctionParameterDescription(parentPeer)), ("peer", FunctionParameterDescription(peer)), ("offsetId", FunctionParameterDescription(offsetId)), ("offsetDate", FunctionParameterDescription(offsetDate)), ("addOffset", FunctionParameterDescription(addOffset)), ("limit", FunctionParameterDescription(limit)), ("maxId", FunctionParameterDescription(maxId)), ("minId", FunctionParameterDescription(minId)), ("hash", FunctionParameterDescription(hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.Messages? in
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
        if Int(flags) & Int(1 << 0) != 0 {
            peer!.serialize(buffer, true)
        }
        serializeInt64(hash, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "messages.getSavedReactionTags", parameters: [("flags", FunctionParameterDescription(flags)), ("peer", FunctionParameterDescription(peer)), ("hash", FunctionParameterDescription(hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.SavedReactionTags? in
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
        return (FunctionDescription(name: "messages.getScheduledHistory", parameters: [("peer", FunctionParameterDescription(peer)), ("hash", FunctionParameterDescription(hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.Messages? in
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
        return (FunctionDescription(name: "messages.getScheduledMessages", parameters: [("peer", FunctionParameterDescription(peer)), ("id", FunctionParameterDescription(id))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.Messages? in
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
        if Int(flags) & Int(1 << 2) != 0 {
            savedPeerId!.serialize(buffer, true)
        }
        if Int(flags) & Int(1 << 0) != 0 {
            serializeInt32(topMsgId!, buffer: buffer, boxed: false)
        }
        buffer.appendInt32(481674261)
        buffer.appendInt32(Int32(filters.count))
        for item in filters {
            item.serialize(buffer, true)
        }
        return (FunctionDescription(name: "messages.getSearchCounters", parameters: [("flags", FunctionParameterDescription(flags)), ("peer", FunctionParameterDescription(peer)), ("savedPeerId", FunctionParameterDescription(savedPeerId)), ("topMsgId", FunctionParameterDescription(topMsgId)), ("filters", FunctionParameterDescription(filters))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> [Api.messages.SearchCounter]? in
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
        if Int(flags) & Int(1 << 2) != 0 {
            savedPeerId!.serialize(buffer, true)
        }
        filter.serialize(buffer, true)
        serializeInt32(offsetId, buffer: buffer, boxed: false)
        serializeInt32(offsetDate, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "messages.getSearchResultsCalendar", parameters: [("flags", FunctionParameterDescription(flags)), ("peer", FunctionParameterDescription(peer)), ("savedPeerId", FunctionParameterDescription(savedPeerId)), ("filter", FunctionParameterDescription(filter)), ("offsetId", FunctionParameterDescription(offsetId)), ("offsetDate", FunctionParameterDescription(offsetDate))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.SearchResultsCalendar? in
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
        if Int(flags) & Int(1 << 2) != 0 {
            savedPeerId!.serialize(buffer, true)
        }
        filter.serialize(buffer, true)
        serializeInt32(offsetId, buffer: buffer, boxed: false)
        serializeInt32(limit, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "messages.getSearchResultsPositions", parameters: [("flags", FunctionParameterDescription(flags)), ("peer", FunctionParameterDescription(peer)), ("savedPeerId", FunctionParameterDescription(savedPeerId)), ("filter", FunctionParameterDescription(filter)), ("offsetId", FunctionParameterDescription(offsetId)), ("limit", FunctionParameterDescription(limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.SearchResultsPositions? in
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
        if Int(flags) & Int(1 << 0) != 0 {
            serializeInt32(msgId!, buffer: buffer, boxed: false)
        }
        return (FunctionDescription(name: "messages.getSponsoredMessages", parameters: [("flags", FunctionParameterDescription(flags)), ("peer", FunctionParameterDescription(peer)), ("msgId", FunctionParameterDescription(msgId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.SponsoredMessages? in
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
        return (FunctionDescription(name: "messages.getStickerSet", parameters: [("stickerset", FunctionParameterDescription(stickerset)), ("hash", FunctionParameterDescription(hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.StickerSet? in
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
        return (FunctionDescription(name: "messages.getStickers", parameters: [("emoticon", FunctionParameterDescription(emoticon)), ("hash", FunctionParameterDescription(hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.Stickers? in
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
        return (FunctionDescription(name: "messages.getTopReactions", parameters: [("limit", FunctionParameterDescription(limit)), ("hash", FunctionParameterDescription(hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.Reactions? in
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
        if Int(flags) & Int(1 << 0) != 0 {
            serializeInt32(topMsgId!, buffer: buffer, boxed: false)
        }
        serializeInt32(offsetId, buffer: buffer, boxed: false)
        serializeInt32(addOffset, buffer: buffer, boxed: false)
        serializeInt32(limit, buffer: buffer, boxed: false)
        serializeInt32(maxId, buffer: buffer, boxed: false)
        serializeInt32(minId, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "messages.getUnreadMentions", parameters: [("flags", FunctionParameterDescription(flags)), ("peer", FunctionParameterDescription(peer)), ("topMsgId", FunctionParameterDescription(topMsgId)), ("offsetId", FunctionParameterDescription(offsetId)), ("addOffset", FunctionParameterDescription(addOffset)), ("limit", FunctionParameterDescription(limit)), ("maxId", FunctionParameterDescription(maxId)), ("minId", FunctionParameterDescription(minId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.Messages? in
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
    static func getUnreadPollVotes(flags: Int32, peer: Api.InputPeer, topMsgId: Int32?, offsetId: Int32, addOffset: Int32, limit: Int32, maxId: Int32, minId: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.Messages>) {
        let buffer = Buffer()
        buffer.appendInt32(1126722802)
        serializeInt32(flags, buffer: buffer, boxed: false)
        peer.serialize(buffer, true)
        if Int(flags) & Int(1 << 0) != 0 {
            serializeInt32(topMsgId!, buffer: buffer, boxed: false)
        }
        serializeInt32(offsetId, buffer: buffer, boxed: false)
        serializeInt32(addOffset, buffer: buffer, boxed: false)
        serializeInt32(limit, buffer: buffer, boxed: false)
        serializeInt32(maxId, buffer: buffer, boxed: false)
        serializeInt32(minId, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "messages.getUnreadPollVotes", parameters: [("flags", FunctionParameterDescription(flags)), ("peer", FunctionParameterDescription(peer)), ("topMsgId", FunctionParameterDescription(topMsgId)), ("offsetId", FunctionParameterDescription(offsetId)), ("addOffset", FunctionParameterDescription(addOffset)), ("limit", FunctionParameterDescription(limit)), ("maxId", FunctionParameterDescription(maxId)), ("minId", FunctionParameterDescription(minId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.Messages? in
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
        if Int(flags) & Int(1 << 0) != 0 {
            serializeInt32(topMsgId!, buffer: buffer, boxed: false)
        }
        if Int(flags) & Int(1 << 1) != 0 {
            savedPeerId!.serialize(buffer, true)
        }
        serializeInt32(offsetId, buffer: buffer, boxed: false)
        serializeInt32(addOffset, buffer: buffer, boxed: false)
        serializeInt32(limit, buffer: buffer, boxed: false)
        serializeInt32(maxId, buffer: buffer, boxed: false)
        serializeInt32(minId, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "messages.getUnreadReactions", parameters: [("flags", FunctionParameterDescription(flags)), ("peer", FunctionParameterDescription(peer)), ("topMsgId", FunctionParameterDescription(topMsgId)), ("savedPeerId", FunctionParameterDescription(savedPeerId)), ("offsetId", FunctionParameterDescription(offsetId)), ("addOffset", FunctionParameterDescription(addOffset)), ("limit", FunctionParameterDescription(limit)), ("maxId", FunctionParameterDescription(maxId)), ("minId", FunctionParameterDescription(minId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.Messages? in
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
        return (FunctionDescription(name: "messages.getWebPage", parameters: [("url", FunctionParameterDescription(url)), ("hash", FunctionParameterDescription(hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.WebPage? in
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
        if Int(flags) & Int(1 << 3) != 0 {
            buffer.appendInt32(481674261)
            buffer.appendInt32(Int32(entities!.count))
            for item in entities! {
                item.serialize(buffer, true)
            }
        }
        return (FunctionDescription(name: "messages.getWebPagePreview", parameters: [("flags", FunctionParameterDescription(flags)), ("message", FunctionParameterDescription(message)), ("entities", FunctionParameterDescription(entities))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.WebPagePreview? in
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
        if Int(flags) & Int(1 << 1) != 0 {
            serializeString(link!, buffer: buffer, boxed: false)
        }
        return (FunctionDescription(name: "messages.hideAllChatJoinRequests", parameters: [("flags", FunctionParameterDescription(flags)), ("peer", FunctionParameterDescription(peer)), ("link", FunctionParameterDescription(link))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        return (FunctionDescription(name: "messages.hideChatJoinRequest", parameters: [("flags", FunctionParameterDescription(flags)), ("peer", FunctionParameterDescription(peer)), ("userId", FunctionParameterDescription(userId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        return (FunctionDescription(name: "messages.hidePeerSettingsBar", parameters: [("peer", FunctionParameterDescription(peer))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "messages.importChatInvite", parameters: [("hash", FunctionParameterDescription(hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        return (FunctionDescription(name: "messages.initHistoryImport", parameters: [("peer", FunctionParameterDescription(peer)), ("file", FunctionParameterDescription(file)), ("mediaCount", FunctionParameterDescription(mediaCount))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.HistoryImport? in
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
        return (FunctionDescription(name: "messages.installStickerSet", parameters: [("stickerset", FunctionParameterDescription(stickerset)), ("archived", FunctionParameterDescription(archived))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.StickerSetInstallResult? in
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
        if Int(flags) & Int(1 << 1) != 0 {
            parentPeer!.serialize(buffer, true)
        }
        peer.serialize(buffer, true)
        return (FunctionDescription(name: "messages.markDialogUnread", parameters: [("flags", FunctionParameterDescription(flags)), ("parentPeer", FunctionParameterDescription(parentPeer)), ("peer", FunctionParameterDescription(peer))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "messages.migrateChat", parameters: [("chatId", FunctionParameterDescription(chatId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        if Int(flags) & Int(1 << 0) != 0 {
            replyTo!.serialize(buffer, true)
        }
        if Int(flags) & Int(1 << 13) != 0 {
            sendAs!.serialize(buffer, true)
        }
        return (FunctionDescription(name: "messages.prolongWebView", parameters: [("flags", FunctionParameterDescription(flags)), ("peer", FunctionParameterDescription(peer)), ("bot", FunctionParameterDescription(bot)), ("queryId", FunctionParameterDescription(queryId)), ("replyTo", FunctionParameterDescription(replyTo)), ("sendAs", FunctionParameterDescription(sendAs))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "messages.rateTranscribedAudio", parameters: [("peer", FunctionParameterDescription(peer)), ("msgId", FunctionParameterDescription(msgId)), ("transcriptionId", FunctionParameterDescription(transcriptionId)), ("good", FunctionParameterDescription(good))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "messages.readDiscussion", parameters: [("peer", FunctionParameterDescription(peer)), ("msgId", FunctionParameterDescription(msgId)), ("readMaxId", FunctionParameterDescription(readMaxId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "messages.readEncryptedHistory", parameters: [("peer", FunctionParameterDescription(peer)), ("maxDate", FunctionParameterDescription(maxDate))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "messages.readFeaturedStickers", parameters: [("id", FunctionParameterDescription(id))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "messages.readHistory", parameters: [("peer", FunctionParameterDescription(peer)), ("maxId", FunctionParameterDescription(maxId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.AffectedMessages? in
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
        if Int(flags) & Int(1 << 0) != 0 {
            serializeInt32(topMsgId!, buffer: buffer, boxed: false)
        }
        return (FunctionDescription(name: "messages.readMentions", parameters: [("flags", FunctionParameterDescription(flags)), ("peer", FunctionParameterDescription(peer)), ("topMsgId", FunctionParameterDescription(topMsgId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.AffectedHistory? in
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
        return (FunctionDescription(name: "messages.readMessageContents", parameters: [("id", FunctionParameterDescription(id))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.AffectedMessages? in
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
    static func readPollVotes(flags: Int32, peer: Api.InputPeer, topMsgId: Int32?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.AffectedHistory>) {
        let buffer = Buffer()
        buffer.appendInt32(388019416)
        serializeInt32(flags, buffer: buffer, boxed: false)
        peer.serialize(buffer, true)
        if Int(flags) & Int(1 << 0) != 0 {
            serializeInt32(topMsgId!, buffer: buffer, boxed: false)
        }
        return (FunctionDescription(name: "messages.readPollVotes", parameters: [("flags", FunctionParameterDescription(flags)), ("peer", FunctionParameterDescription(peer)), ("topMsgId", FunctionParameterDescription(topMsgId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.AffectedHistory? in
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
    static func readReactions(flags: Int32, peer: Api.InputPeer, topMsgId: Int32?, savedPeerId: Api.InputPeer?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.AffectedHistory>) {
        let buffer = Buffer()
        buffer.appendInt32(-1631301741)
        serializeInt32(flags, buffer: buffer, boxed: false)
        peer.serialize(buffer, true)
        if Int(flags) & Int(1 << 0) != 0 {
            serializeInt32(topMsgId!, buffer: buffer, boxed: false)
        }
        if Int(flags) & Int(1 << 1) != 0 {
            savedPeerId!.serialize(buffer, true)
        }
        return (FunctionDescription(name: "messages.readReactions", parameters: [("flags", FunctionParameterDescription(flags)), ("peer", FunctionParameterDescription(peer)), ("topMsgId", FunctionParameterDescription(topMsgId)), ("savedPeerId", FunctionParameterDescription(savedPeerId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.AffectedHistory? in
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
        return (FunctionDescription(name: "messages.readSavedHistory", parameters: [("parentPeer", FunctionParameterDescription(parentPeer)), ("peer", FunctionParameterDescription(peer)), ("maxId", FunctionParameterDescription(maxId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "messages.receivedMessages", parameters: [("maxId", FunctionParameterDescription(maxId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> [Api.ReceivedNotifyMessage]? in
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
        return (FunctionDescription(name: "messages.receivedQueue", parameters: [("maxQts", FunctionParameterDescription(maxQts))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> [Int64]? in
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
        return (FunctionDescription(name: "messages.reorderPinnedDialogs", parameters: [("flags", FunctionParameterDescription(flags)), ("folderId", FunctionParameterDescription(folderId)), ("order", FunctionParameterDescription(order))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
    static func reorderPinnedForumTopics(flags: Int32, peer: Api.InputPeer, order: [Int32]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let buffer = Buffer()
        buffer.appendInt32(242762224)
        serializeInt32(flags, buffer: buffer, boxed: false)
        peer.serialize(buffer, true)
        buffer.appendInt32(481674261)
        buffer.appendInt32(Int32(order.count))
        for item in order {
            serializeInt32(item, buffer: buffer, boxed: false)
        }
        return (FunctionDescription(name: "messages.reorderPinnedForumTopics", parameters: [("flags", FunctionParameterDescription(flags)), ("peer", FunctionParameterDescription(peer)), ("order", FunctionParameterDescription(order))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
    static func reorderPinnedSavedDialogs(flags: Int32, order: [Api.InputDialogPeer]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let buffer = Buffer()
        buffer.appendInt32(-1955502713)
        serializeInt32(flags, buffer: buffer, boxed: false)
        buffer.appendInt32(481674261)
        buffer.appendInt32(Int32(order.count))
        for item in order {
            item.serialize(buffer, true)
        }
        return (FunctionDescription(name: "messages.reorderPinnedSavedDialogs", parameters: [("flags", FunctionParameterDescription(flags)), ("order", FunctionParameterDescription(order))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "messages.reorderQuickReplies", parameters: [("order", FunctionParameterDescription(order))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "messages.reorderStickerSets", parameters: [("flags", FunctionParameterDescription(flags)), ("order", FunctionParameterDescription(order))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "messages.report", parameters: [("peer", FunctionParameterDescription(peer)), ("id", FunctionParameterDescription(id)), ("option", FunctionParameterDescription(option)), ("message", FunctionParameterDescription(message))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.ReportResult? in
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
        return (FunctionDescription(name: "messages.reportEncryptedSpam", parameters: [("peer", FunctionParameterDescription(peer))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "messages.reportMessagesDelivery", parameters: [("flags", FunctionParameterDescription(flags)), ("peer", FunctionParameterDescription(peer)), ("id", FunctionParameterDescription(id))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
    static func reportMusicListen(id: Api.InputDocument, listenedDuration: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let buffer = Buffer()
        buffer.appendInt32(-574826471)
        id.serialize(buffer, true)
        serializeInt32(listenedDuration, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "messages.reportMusicListen", parameters: [("id", FunctionParameterDescription(id)), ("listenedDuration", FunctionParameterDescription(listenedDuration))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "messages.reportReaction", parameters: [("peer", FunctionParameterDescription(peer)), ("id", FunctionParameterDescription(id)), ("reactionPeer", FunctionParameterDescription(reactionPeer))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
    static func reportReadMetrics(peer: Api.InputPeer, metrics: [Api.InputMessageReadMetric]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let buffer = Buffer()
        buffer.appendInt32(1080542694)
        peer.serialize(buffer, true)
        buffer.appendInt32(481674261)
        buffer.appendInt32(Int32(metrics.count))
        for item in metrics {
            item.serialize(buffer, true)
        }
        return (FunctionDescription(name: "messages.reportReadMetrics", parameters: [("peer", FunctionParameterDescription(peer)), ("metrics", FunctionParameterDescription(metrics))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "messages.reportSpam", parameters: [("peer", FunctionParameterDescription(peer))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "messages.reportSponsoredMessage", parameters: [("randomId", FunctionParameterDescription(randomId)), ("option", FunctionParameterDescription(option))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.channels.SponsoredMessageReportResult? in
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
        if Int(flags) & Int(1 << 1) != 0 {
            serializeString(startParam!, buffer: buffer, boxed: false)
        }
        if Int(flags) & Int(1 << 2) != 0 {
            themeParams!.serialize(buffer, true)
        }
        serializeString(platform, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "messages.requestAppWebView", parameters: [("flags", FunctionParameterDescription(flags)), ("peer", FunctionParameterDescription(peer)), ("app", FunctionParameterDescription(app)), ("startParam", FunctionParameterDescription(startParam)), ("themeParams", FunctionParameterDescription(themeParams)), ("platform", FunctionParameterDescription(platform))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.WebViewResult? in
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
        return (FunctionDescription(name: "messages.requestEncryption", parameters: [("userId", FunctionParameterDescription(userId)), ("randomId", FunctionParameterDescription(randomId)), ("gA", FunctionParameterDescription(gA))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.EncryptedChat? in
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
        if Int(flags) & Int(1 << 1) != 0 {
            serializeString(startParam!, buffer: buffer, boxed: false)
        }
        if Int(flags) & Int(1 << 0) != 0 {
            themeParams!.serialize(buffer, true)
        }
        serializeString(platform, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "messages.requestMainWebView", parameters: [("flags", FunctionParameterDescription(flags)), ("peer", FunctionParameterDescription(peer)), ("bot", FunctionParameterDescription(bot)), ("startParam", FunctionParameterDescription(startParam)), ("themeParams", FunctionParameterDescription(themeParams)), ("platform", FunctionParameterDescription(platform))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.WebViewResult? in
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
        if Int(flags) & Int(1 << 3) != 0 {
            serializeString(url!, buffer: buffer, boxed: false)
        }
        if Int(flags) & Int(1 << 4) != 0 {
            serializeString(startParam!, buffer: buffer, boxed: false)
        }
        if Int(flags) & Int(1 << 0) != 0 {
            themeParams!.serialize(buffer, true)
        }
        serializeString(platform, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "messages.requestSimpleWebView", parameters: [("flags", FunctionParameterDescription(flags)), ("bot", FunctionParameterDescription(bot)), ("url", FunctionParameterDescription(url)), ("startParam", FunctionParameterDescription(startParam)), ("themeParams", FunctionParameterDescription(themeParams)), ("platform", FunctionParameterDescription(platform))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.WebViewResult? in
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
    static func requestUrlAuth(flags: Int32, peer: Api.InputPeer?, msgId: Int32?, buttonId: Int32?, url: String?, inAppOrigin: String?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.UrlAuthResult>) {
        let buffer = Buffer()
        buffer.appendInt32(-1991456356)
        serializeInt32(flags, buffer: buffer, boxed: false)
        if Int(flags) & Int(1 << 1) != 0 {
            peer!.serialize(buffer, true)
        }
        if Int(flags) & Int(1 << 1) != 0 {
            serializeInt32(msgId!, buffer: buffer, boxed: false)
        }
        if Int(flags) & Int(1 << 1) != 0 {
            serializeInt32(buttonId!, buffer: buffer, boxed: false)
        }
        if Int(flags) & Int(1 << 2) != 0 {
            serializeString(url!, buffer: buffer, boxed: false)
        }
        if Int(flags) & Int(1 << 3) != 0 {
            serializeString(inAppOrigin!, buffer: buffer, boxed: false)
        }
        return (FunctionDescription(name: "messages.requestUrlAuth", parameters: [("flags", FunctionParameterDescription(flags)), ("peer", FunctionParameterDescription(peer)), ("msgId", FunctionParameterDescription(msgId)), ("buttonId", FunctionParameterDescription(buttonId)), ("url", FunctionParameterDescription(url)), ("inAppOrigin", FunctionParameterDescription(inAppOrigin))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.UrlAuthResult? in
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
        if Int(flags) & Int(1 << 1) != 0 {
            serializeString(url!, buffer: buffer, boxed: false)
        }
        if Int(flags) & Int(1 << 3) != 0 {
            serializeString(startParam!, buffer: buffer, boxed: false)
        }
        if Int(flags) & Int(1 << 2) != 0 {
            themeParams!.serialize(buffer, true)
        }
        serializeString(platform, buffer: buffer, boxed: false)
        if Int(flags) & Int(1 << 0) != 0 {
            replyTo!.serialize(buffer, true)
        }
        if Int(flags) & Int(1 << 13) != 0 {
            sendAs!.serialize(buffer, true)
        }
        return (FunctionDescription(name: "messages.requestWebView", parameters: [("flags", FunctionParameterDescription(flags)), ("peer", FunctionParameterDescription(peer)), ("bot", FunctionParameterDescription(bot)), ("url", FunctionParameterDescription(url)), ("startParam", FunctionParameterDescription(startParam)), ("themeParams", FunctionParameterDescription(themeParams)), ("platform", FunctionParameterDescription(platform)), ("replyTo", FunctionParameterDescription(replyTo)), ("sendAs", FunctionParameterDescription(sendAs))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.WebViewResult? in
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
        return (FunctionDescription(name: "messages.saveDefaultSendAs", parameters: [("peer", FunctionParameterDescription(peer)), ("sendAs", FunctionParameterDescription(sendAs))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        if Int(flags) & Int(1 << 4) != 0 {
            replyTo!.serialize(buffer, true)
        }
        peer.serialize(buffer, true)
        serializeString(message, buffer: buffer, boxed: false)
        if Int(flags) & Int(1 << 3) != 0 {
            buffer.appendInt32(481674261)
            buffer.appendInt32(Int32(entities!.count))
            for item in entities! {
                item.serialize(buffer, true)
            }
        }
        if Int(flags) & Int(1 << 5) != 0 {
            media!.serialize(buffer, true)
        }
        if Int(flags) & Int(1 << 7) != 0 {
            serializeInt64(effect!, buffer: buffer, boxed: false)
        }
        if Int(flags) & Int(1 << 8) != 0 {
            suggestedPost!.serialize(buffer, true)
        }
        return (FunctionDescription(name: "messages.saveDraft", parameters: [("flags", FunctionParameterDescription(flags)), ("replyTo", FunctionParameterDescription(replyTo)), ("peer", FunctionParameterDescription(peer)), ("message", FunctionParameterDescription(message)), ("entities", FunctionParameterDescription(entities)), ("media", FunctionParameterDescription(media)), ("effect", FunctionParameterDescription(effect)), ("suggestedPost", FunctionParameterDescription(suggestedPost))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "messages.saveGif", parameters: [("id", FunctionParameterDescription(id)), ("unsave", FunctionParameterDescription(unsave))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        if Int(flags) & Int(1 << 0) != 0 {
            buffer.appendInt32(481674261)
            buffer.appendInt32(Int32(peerTypes!.count))
            for item in peerTypes! {
                item.serialize(buffer, true)
            }
        }
        return (FunctionDescription(name: "messages.savePreparedInlineMessage", parameters: [("flags", FunctionParameterDescription(flags)), ("result", FunctionParameterDescription(result)), ("userId", FunctionParameterDescription(userId)), ("peerTypes", FunctionParameterDescription(peerTypes))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.BotPreparedInlineMessage? in
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
        return (FunctionDescription(name: "messages.saveRecentSticker", parameters: [("flags", FunctionParameterDescription(flags)), ("id", FunctionParameterDescription(id)), ("unsave", FunctionParameterDescription(unsave))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        if Int(flags) & Int(1 << 0) != 0 {
            fromId!.serialize(buffer, true)
        }
        if Int(flags) & Int(1 << 2) != 0 {
            savedPeerId!.serialize(buffer, true)
        }
        if Int(flags) & Int(1 << 3) != 0 {
            buffer.appendInt32(481674261)
            buffer.appendInt32(Int32(savedReaction!.count))
            for item in savedReaction! {
                item.serialize(buffer, true)
            }
        }
        if Int(flags) & Int(1 << 1) != 0 {
            serializeInt32(topMsgId!, buffer: buffer, boxed: false)
        }
        filter.serialize(buffer, true)
        serializeInt32(minDate, buffer: buffer, boxed: false)
        serializeInt32(maxDate, buffer: buffer, boxed: false)
        serializeInt32(offsetId, buffer: buffer, boxed: false)
        serializeInt32(addOffset, buffer: buffer, boxed: false)
        serializeInt32(limit, buffer: buffer, boxed: false)
        serializeInt32(maxId, buffer: buffer, boxed: false)
        serializeInt32(minId, buffer: buffer, boxed: false)
        serializeInt64(hash, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "messages.search", parameters: [("flags", FunctionParameterDescription(flags)), ("peer", FunctionParameterDescription(peer)), ("q", FunctionParameterDescription(q)), ("fromId", FunctionParameterDescription(fromId)), ("savedPeerId", FunctionParameterDescription(savedPeerId)), ("savedReaction", FunctionParameterDescription(savedReaction)), ("topMsgId", FunctionParameterDescription(topMsgId)), ("filter", FunctionParameterDescription(filter)), ("minDate", FunctionParameterDescription(minDate)), ("maxDate", FunctionParameterDescription(maxDate)), ("offsetId", FunctionParameterDescription(offsetId)), ("addOffset", FunctionParameterDescription(addOffset)), ("limit", FunctionParameterDescription(limit)), ("maxId", FunctionParameterDescription(maxId)), ("minId", FunctionParameterDescription(minId)), ("hash", FunctionParameterDescription(hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.Messages? in
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
        return (FunctionDescription(name: "messages.searchCustomEmoji", parameters: [("emoticon", FunctionParameterDescription(emoticon)), ("hash", FunctionParameterDescription(hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.EmojiList? in
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
        return (FunctionDescription(name: "messages.searchEmojiStickerSets", parameters: [("flags", FunctionParameterDescription(flags)), ("q", FunctionParameterDescription(q)), ("hash", FunctionParameterDescription(hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.FoundStickerSets? in
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
        if Int(flags) & Int(1 << 0) != 0 {
            serializeInt32(folderId!, buffer: buffer, boxed: false)
        }
        serializeString(q, buffer: buffer, boxed: false)
        filter.serialize(buffer, true)
        serializeInt32(minDate, buffer: buffer, boxed: false)
        serializeInt32(maxDate, buffer: buffer, boxed: false)
        serializeInt32(offsetRate, buffer: buffer, boxed: false)
        offsetPeer.serialize(buffer, true)
        serializeInt32(offsetId, buffer: buffer, boxed: false)
        serializeInt32(limit, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "messages.searchGlobal", parameters: [("flags", FunctionParameterDescription(flags)), ("folderId", FunctionParameterDescription(folderId)), ("q", FunctionParameterDescription(q)), ("filter", FunctionParameterDescription(filter)), ("minDate", FunctionParameterDescription(minDate)), ("maxDate", FunctionParameterDescription(maxDate)), ("offsetRate", FunctionParameterDescription(offsetRate)), ("offsetPeer", FunctionParameterDescription(offsetPeer)), ("offsetId", FunctionParameterDescription(offsetId)), ("limit", FunctionParameterDescription(limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.Messages? in
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
        return (FunctionDescription(name: "messages.searchSentMedia", parameters: [("q", FunctionParameterDescription(q)), ("filter", FunctionParameterDescription(filter)), ("limit", FunctionParameterDescription(limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.Messages? in
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
        return (FunctionDescription(name: "messages.searchStickerSets", parameters: [("flags", FunctionParameterDescription(flags)), ("q", FunctionParameterDescription(q)), ("hash", FunctionParameterDescription(hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.FoundStickerSets? in
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
        return (FunctionDescription(name: "messages.searchStickers", parameters: [("flags", FunctionParameterDescription(flags)), ("q", FunctionParameterDescription(q)), ("emoticon", FunctionParameterDescription(emoticon)), ("langCode", FunctionParameterDescription(langCode)), ("offset", FunctionParameterDescription(offset)), ("limit", FunctionParameterDescription(limit)), ("hash", FunctionParameterDescription(hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.FoundStickers? in
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
    static func sendBotRequestedPeer(flags: Int32, peer: Api.InputPeer, msgId: Int32?, webappReqId: String?, buttonId: Int32, requestedPeers: [Api.InputPeer]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let buffer = Buffer()
        buffer.appendInt32(1818030759)
        serializeInt32(flags, buffer: buffer, boxed: false)
        peer.serialize(buffer, true)
        if Int(flags) & Int(1 << 0) != 0 {
            serializeInt32(msgId!, buffer: buffer, boxed: false)
        }
        if Int(flags) & Int(1 << 1) != 0 {
            serializeString(webappReqId!, buffer: buffer, boxed: false)
        }
        serializeInt32(buttonId, buffer: buffer, boxed: false)
        buffer.appendInt32(481674261)
        buffer.appendInt32(Int32(requestedPeers.count))
        for item in requestedPeers {
            item.serialize(buffer, true)
        }
        return (FunctionDescription(name: "messages.sendBotRequestedPeer", parameters: [("flags", FunctionParameterDescription(flags)), ("peer", FunctionParameterDescription(peer)), ("msgId", FunctionParameterDescription(msgId)), ("webappReqId", FunctionParameterDescription(webappReqId)), ("buttonId", FunctionParameterDescription(buttonId)), ("requestedPeers", FunctionParameterDescription(requestedPeers))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        return (FunctionDescription(name: "messages.sendEncrypted", parameters: [("flags", FunctionParameterDescription(flags)), ("peer", FunctionParameterDescription(peer)), ("randomId", FunctionParameterDescription(randomId)), ("data", FunctionParameterDescription(data))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.SentEncryptedMessage? in
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
        return (FunctionDescription(name: "messages.sendEncryptedFile", parameters: [("flags", FunctionParameterDescription(flags)), ("peer", FunctionParameterDescription(peer)), ("randomId", FunctionParameterDescription(randomId)), ("data", FunctionParameterDescription(data)), ("file", FunctionParameterDescription(file))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.SentEncryptedMessage? in
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
        return (FunctionDescription(name: "messages.sendEncryptedService", parameters: [("peer", FunctionParameterDescription(peer)), ("randomId", FunctionParameterDescription(randomId)), ("data", FunctionParameterDescription(data))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.SentEncryptedMessage? in
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
        if Int(flags) & Int(1 << 0) != 0 {
            replyTo!.serialize(buffer, true)
        }
        serializeInt64(randomId, buffer: buffer, boxed: false)
        serializeInt64(queryId, buffer: buffer, boxed: false)
        serializeString(id, buffer: buffer, boxed: false)
        if Int(flags) & Int(1 << 10) != 0 {
            serializeInt32(scheduleDate!, buffer: buffer, boxed: false)
        }
        if Int(flags) & Int(1 << 13) != 0 {
            sendAs!.serialize(buffer, true)
        }
        if Int(flags) & Int(1 << 17) != 0 {
            quickReplyShortcut!.serialize(buffer, true)
        }
        if Int(flags) & Int(1 << 21) != 0 {
            serializeInt64(allowPaidStars!, buffer: buffer, boxed: false)
        }
        return (FunctionDescription(name: "messages.sendInlineBotResult", parameters: [("flags", FunctionParameterDescription(flags)), ("peer", FunctionParameterDescription(peer)), ("replyTo", FunctionParameterDescription(replyTo)), ("randomId", FunctionParameterDescription(randomId)), ("queryId", FunctionParameterDescription(queryId)), ("id", FunctionParameterDescription(id)), ("scheduleDate", FunctionParameterDescription(scheduleDate)), ("sendAs", FunctionParameterDescription(sendAs)), ("quickReplyShortcut", FunctionParameterDescription(quickReplyShortcut)), ("allowPaidStars", FunctionParameterDescription(allowPaidStars))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
    static func sendMedia(flags: Int32, peer: Api.InputPeer, replyTo: Api.InputReplyTo?, media: Api.InputMedia, message: String, randomId: Int64, replyMarkup: Api.ReplyMarkup?, entities: [Api.MessageEntity]?, scheduleDate: Int32?, scheduleRepeatPeriod: Int32?, sendAs: Api.InputPeer?, quickReplyShortcut: Api.InputQuickReplyShortcut?, effect: Int64?, allowPaidStars: Int64?, suggestedPost: Api.SuggestedPost?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let buffer = Buffer()
        buffer.appendInt32(53536639)
        serializeInt32(flags, buffer: buffer, boxed: false)
        peer.serialize(buffer, true)
        if Int(flags) & Int(1 << 0) != 0 {
            replyTo!.serialize(buffer, true)
        }
        media.serialize(buffer, true)
        serializeString(message, buffer: buffer, boxed: false)
        serializeInt64(randomId, buffer: buffer, boxed: false)
        if Int(flags) & Int(1 << 2) != 0 {
            replyMarkup!.serialize(buffer, true)
        }
        if Int(flags) & Int(1 << 3) != 0 {
            buffer.appendInt32(481674261)
            buffer.appendInt32(Int32(entities!.count))
            for item in entities! {
                item.serialize(buffer, true)
            }
        }
        if Int(flags) & Int(1 << 10) != 0 {
            serializeInt32(scheduleDate!, buffer: buffer, boxed: false)
        }
        if Int(flags) & Int(1 << 24) != 0 {
            serializeInt32(scheduleRepeatPeriod!, buffer: buffer, boxed: false)
        }
        if Int(flags) & Int(1 << 13) != 0 {
            sendAs!.serialize(buffer, true)
        }
        if Int(flags) & Int(1 << 17) != 0 {
            quickReplyShortcut!.serialize(buffer, true)
        }
        if Int(flags) & Int(1 << 18) != 0 {
            serializeInt64(effect!, buffer: buffer, boxed: false)
        }
        if Int(flags) & Int(1 << 21) != 0 {
            serializeInt64(allowPaidStars!, buffer: buffer, boxed: false)
        }
        if Int(flags) & Int(1 << 22) != 0 {
            suggestedPost!.serialize(buffer, true)
        }
        return (FunctionDescription(name: "messages.sendMedia", parameters: [("flags", FunctionParameterDescription(flags)), ("peer", FunctionParameterDescription(peer)), ("replyTo", FunctionParameterDescription(replyTo)), ("media", FunctionParameterDescription(media)), ("message", FunctionParameterDescription(message)), ("randomId", FunctionParameterDescription(randomId)), ("replyMarkup", FunctionParameterDescription(replyMarkup)), ("entities", FunctionParameterDescription(entities)), ("scheduleDate", FunctionParameterDescription(scheduleDate)), ("scheduleRepeatPeriod", FunctionParameterDescription(scheduleRepeatPeriod)), ("sendAs", FunctionParameterDescription(sendAs)), ("quickReplyShortcut", FunctionParameterDescription(quickReplyShortcut)), ("effect", FunctionParameterDescription(effect)), ("allowPaidStars", FunctionParameterDescription(allowPaidStars)), ("suggestedPost", FunctionParameterDescription(suggestedPost))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
    static func sendMessage(flags: Int32, peer: Api.InputPeer, replyTo: Api.InputReplyTo?, message: String, randomId: Int64, replyMarkup: Api.ReplyMarkup?, entities: [Api.MessageEntity]?, scheduleDate: Int32?, scheduleRepeatPeriod: Int32?, sendAs: Api.InputPeer?, quickReplyShortcut: Api.InputQuickReplyShortcut?, effect: Int64?, allowPaidStars: Int64?, suggestedPost: Api.SuggestedPost?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let buffer = Buffer()
        buffer.appendInt32(1415369050)
        serializeInt32(flags, buffer: buffer, boxed: false)
        peer.serialize(buffer, true)
        if Int(flags) & Int(1 << 0) != 0 {
            replyTo!.serialize(buffer, true)
        }
        serializeString(message, buffer: buffer, boxed: false)
        serializeInt64(randomId, buffer: buffer, boxed: false)
        if Int(flags) & Int(1 << 2) != 0 {
            replyMarkup!.serialize(buffer, true)
        }
        if Int(flags) & Int(1 << 3) != 0 {
            buffer.appendInt32(481674261)
            buffer.appendInt32(Int32(entities!.count))
            for item in entities! {
                item.serialize(buffer, true)
            }
        }
        if Int(flags) & Int(1 << 10) != 0 {
            serializeInt32(scheduleDate!, buffer: buffer, boxed: false)
        }
        if Int(flags) & Int(1 << 24) != 0 {
            serializeInt32(scheduleRepeatPeriod!, buffer: buffer, boxed: false)
        }
        if Int(flags) & Int(1 << 13) != 0 {
            sendAs!.serialize(buffer, true)
        }
        if Int(flags) & Int(1 << 17) != 0 {
            quickReplyShortcut!.serialize(buffer, true)
        }
        if Int(flags) & Int(1 << 18) != 0 {
            serializeInt64(effect!, buffer: buffer, boxed: false)
        }
        if Int(flags) & Int(1 << 21) != 0 {
            serializeInt64(allowPaidStars!, buffer: buffer, boxed: false)
        }
        if Int(flags) & Int(1 << 22) != 0 {
            suggestedPost!.serialize(buffer, true)
        }
        return (FunctionDescription(name: "messages.sendMessage", parameters: [("flags", FunctionParameterDescription(flags)), ("peer", FunctionParameterDescription(peer)), ("replyTo", FunctionParameterDescription(replyTo)), ("message", FunctionParameterDescription(message)), ("randomId", FunctionParameterDescription(randomId)), ("replyMarkup", FunctionParameterDescription(replyMarkup)), ("entities", FunctionParameterDescription(entities)), ("scheduleDate", FunctionParameterDescription(scheduleDate)), ("scheduleRepeatPeriod", FunctionParameterDescription(scheduleRepeatPeriod)), ("sendAs", FunctionParameterDescription(sendAs)), ("quickReplyShortcut", FunctionParameterDescription(quickReplyShortcut)), ("effect", FunctionParameterDescription(effect)), ("allowPaidStars", FunctionParameterDescription(allowPaidStars)), ("suggestedPost", FunctionParameterDescription(suggestedPost))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        if Int(flags) & Int(1 << 0) != 0 {
            replyTo!.serialize(buffer, true)
        }
        buffer.appendInt32(481674261)
        buffer.appendInt32(Int32(multiMedia.count))
        for item in multiMedia {
            item.serialize(buffer, true)
        }
        if Int(flags) & Int(1 << 10) != 0 {
            serializeInt32(scheduleDate!, buffer: buffer, boxed: false)
        }
        if Int(flags) & Int(1 << 13) != 0 {
            sendAs!.serialize(buffer, true)
        }
        if Int(flags) & Int(1 << 17) != 0 {
            quickReplyShortcut!.serialize(buffer, true)
        }
        if Int(flags) & Int(1 << 18) != 0 {
            serializeInt64(effect!, buffer: buffer, boxed: false)
        }
        if Int(flags) & Int(1 << 21) != 0 {
            serializeInt64(allowPaidStars!, buffer: buffer, boxed: false)
        }
        return (FunctionDescription(name: "messages.sendMultiMedia", parameters: [("flags", FunctionParameterDescription(flags)), ("peer", FunctionParameterDescription(peer)), ("replyTo", FunctionParameterDescription(replyTo)), ("multiMedia", FunctionParameterDescription(multiMedia)), ("scheduleDate", FunctionParameterDescription(scheduleDate)), ("sendAs", FunctionParameterDescription(sendAs)), ("quickReplyShortcut", FunctionParameterDescription(quickReplyShortcut)), ("effect", FunctionParameterDescription(effect)), ("allowPaidStars", FunctionParameterDescription(allowPaidStars))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        if Int(flags) & Int(1 << 0) != 0 {
            `private`!.serialize(buffer, true)
        }
        return (FunctionDescription(name: "messages.sendPaidReaction", parameters: [("flags", FunctionParameterDescription(flags)), ("peer", FunctionParameterDescription(peer)), ("msgId", FunctionParameterDescription(msgId)), ("count", FunctionParameterDescription(count)), ("randomId", FunctionParameterDescription(randomId)), ("`private`", FunctionParameterDescription(`private`))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        return (FunctionDescription(name: "messages.sendQuickReplyMessages", parameters: [("peer", FunctionParameterDescription(peer)), ("shortcutId", FunctionParameterDescription(shortcutId)), ("id", FunctionParameterDescription(id)), ("randomId", FunctionParameterDescription(randomId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        if Int(flags) & Int(1 << 0) != 0 {
            buffer.appendInt32(481674261)
            buffer.appendInt32(Int32(reaction!.count))
            for item in reaction! {
                item.serialize(buffer, true)
            }
        }
        return (FunctionDescription(name: "messages.sendReaction", parameters: [("flags", FunctionParameterDescription(flags)), ("peer", FunctionParameterDescription(peer)), ("msgId", FunctionParameterDescription(msgId)), ("reaction", FunctionParameterDescription(reaction))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        return (FunctionDescription(name: "messages.sendScheduledMessages", parameters: [("peer", FunctionParameterDescription(peer)), ("id", FunctionParameterDescription(id))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        return (FunctionDescription(name: "messages.sendScreenshotNotification", parameters: [("peer", FunctionParameterDescription(peer)), ("replyTo", FunctionParameterDescription(replyTo)), ("randomId", FunctionParameterDescription(randomId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        return (FunctionDescription(name: "messages.sendVote", parameters: [("peer", FunctionParameterDescription(peer)), ("msgId", FunctionParameterDescription(msgId)), ("options", FunctionParameterDescription(options))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        return (FunctionDescription(name: "messages.sendWebViewData", parameters: [("bot", FunctionParameterDescription(bot)), ("randomId", FunctionParameterDescription(randomId)), ("buttonText", FunctionParameterDescription(buttonText)), ("data", FunctionParameterDescription(data))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        return (FunctionDescription(name: "messages.sendWebViewResultMessage", parameters: [("botQueryId", FunctionParameterDescription(botQueryId)), ("result", FunctionParameterDescription(result))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.WebViewMessageSent? in
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
        if Int(flags) & Int(1 << 0) != 0 {
            serializeString(message!, buffer: buffer, boxed: false)
        }
        if Int(flags) & Int(1 << 2) != 0 {
            serializeString(url!, buffer: buffer, boxed: false)
        }
        serializeInt32(cacheTime, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "messages.setBotCallbackAnswer", parameters: [("flags", FunctionParameterDescription(flags)), ("queryId", FunctionParameterDescription(queryId)), ("message", FunctionParameterDescription(message)), ("url", FunctionParameterDescription(url)), ("cacheTime", FunctionParameterDescription(cacheTime))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        if Int(flags) & Int(1 << 0) != 0 {
            serializeString(error!, buffer: buffer, boxed: false)
        }
        return (FunctionDescription(name: "messages.setBotPrecheckoutResults", parameters: [("flags", FunctionParameterDescription(flags)), ("queryId", FunctionParameterDescription(queryId)), ("error", FunctionParameterDescription(error))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        if Int(flags) & Int(1 << 0) != 0 {
            serializeString(error!, buffer: buffer, boxed: false)
        }
        if Int(flags) & Int(1 << 1) != 0 {
            buffer.appendInt32(481674261)
            buffer.appendInt32(Int32(shippingOptions!.count))
            for item in shippingOptions! {
                item.serialize(buffer, true)
            }
        }
        return (FunctionDescription(name: "messages.setBotShippingResults", parameters: [("flags", FunctionParameterDescription(flags)), ("queryId", FunctionParameterDescription(queryId)), ("error", FunctionParameterDescription(error)), ("shippingOptions", FunctionParameterDescription(shippingOptions))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        if Int(flags) & Int(1 << 0) != 0 {
            serializeInt32(reactionsLimit!, buffer: buffer, boxed: false)
        }
        if Int(flags) & Int(1 << 1) != 0 {
            paidEnabled!.serialize(buffer, true)
        }
        return (FunctionDescription(name: "messages.setChatAvailableReactions", parameters: [("flags", FunctionParameterDescription(flags)), ("peer", FunctionParameterDescription(peer)), ("availableReactions", FunctionParameterDescription(availableReactions)), ("reactionsLimit", FunctionParameterDescription(reactionsLimit)), ("paidEnabled", FunctionParameterDescription(paidEnabled))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
    static func setChatTheme(peer: Api.InputPeer, theme: Api.InputChatTheme) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let buffer = Buffer()
        buffer.appendInt32(135398089)
        peer.serialize(buffer, true)
        theme.serialize(buffer, true)
        return (FunctionDescription(name: "messages.setChatTheme", parameters: [("peer", FunctionParameterDescription(peer)), ("theme", FunctionParameterDescription(theme))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        if Int(flags) & Int(1 << 0) != 0 {
            wallpaper!.serialize(buffer, true)
        }
        if Int(flags) & Int(1 << 2) != 0 {
            settings!.serialize(buffer, true)
        }
        if Int(flags) & Int(1 << 1) != 0 {
            serializeInt32(id!, buffer: buffer, boxed: false)
        }
        return (FunctionDescription(name: "messages.setChatWallPaper", parameters: [("flags", FunctionParameterDescription(flags)), ("peer", FunctionParameterDescription(peer)), ("wallpaper", FunctionParameterDescription(wallpaper)), ("settings", FunctionParameterDescription(settings)), ("id", FunctionParameterDescription(id))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        return (FunctionDescription(name: "messages.setDefaultHistoryTTL", parameters: [("period", FunctionParameterDescription(period))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "messages.setDefaultReaction", parameters: [("reaction", FunctionParameterDescription(reaction))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "messages.setEncryptedTyping", parameters: [("peer", FunctionParameterDescription(peer)), ("typing", FunctionParameterDescription(typing))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "messages.setGameScore", parameters: [("flags", FunctionParameterDescription(flags)), ("peer", FunctionParameterDescription(peer)), ("id", FunctionParameterDescription(id)), ("userId", FunctionParameterDescription(userId)), ("score", FunctionParameterDescription(score))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        return (FunctionDescription(name: "messages.setHistoryTTL", parameters: [("peer", FunctionParameterDescription(peer)), ("period", FunctionParameterDescription(period))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        if Int(flags) & Int(1 << 2) != 0 {
            serializeString(nextOffset!, buffer: buffer, boxed: false)
        }
        if Int(flags) & Int(1 << 3) != 0 {
            switchPm!.serialize(buffer, true)
        }
        if Int(flags) & Int(1 << 4) != 0 {
            switchWebview!.serialize(buffer, true)
        }
        return (FunctionDescription(name: "messages.setInlineBotResults", parameters: [("flags", FunctionParameterDescription(flags)), ("queryId", FunctionParameterDescription(queryId)), ("results", FunctionParameterDescription(results)), ("cacheTime", FunctionParameterDescription(cacheTime)), ("nextOffset", FunctionParameterDescription(nextOffset)), ("switchPm", FunctionParameterDescription(switchPm)), ("switchWebview", FunctionParameterDescription(switchWebview))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "messages.setInlineGameScore", parameters: [("flags", FunctionParameterDescription(flags)), ("id", FunctionParameterDescription(id)), ("userId", FunctionParameterDescription(userId)), ("score", FunctionParameterDescription(score))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        if Int(flags) & Int(1 << 0) != 0 {
            serializeInt32(topMsgId!, buffer: buffer, boxed: false)
        }
        action.serialize(buffer, true)
        return (FunctionDescription(name: "messages.setTyping", parameters: [("flags", FunctionParameterDescription(flags)), ("peer", FunctionParameterDescription(peer)), ("topMsgId", FunctionParameterDescription(topMsgId)), ("action", FunctionParameterDescription(action))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "messages.startBot", parameters: [("bot", FunctionParameterDescription(bot)), ("peer", FunctionParameterDescription(peer)), ("randomId", FunctionParameterDescription(randomId)), ("startParam", FunctionParameterDescription(startParam))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        return (FunctionDescription(name: "messages.startHistoryImport", parameters: [("peer", FunctionParameterDescription(peer)), ("importId", FunctionParameterDescription(importId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
    static func summarizeText(flags: Int32, peer: Api.InputPeer, id: Int32, toLang: String?, tone: String?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.TextWithEntities>) {
        let buffer = Buffer()
        buffer.appendInt32(-1413754042)
        serializeInt32(flags, buffer: buffer, boxed: false)
        peer.serialize(buffer, true)
        serializeInt32(id, buffer: buffer, boxed: false)
        if Int(flags) & Int(1 << 0) != 0 {
            serializeString(toLang!, buffer: buffer, boxed: false)
        }
        if Int(flags) & Int(1 << 2) != 0 {
            serializeString(tone!, buffer: buffer, boxed: false)
        }
        return (FunctionDescription(name: "messages.summarizeText", parameters: [("flags", FunctionParameterDescription(flags)), ("peer", FunctionParameterDescription(peer)), ("id", FunctionParameterDescription(id)), ("toLang", FunctionParameterDescription(toLang)), ("tone", FunctionParameterDescription(tone))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.TextWithEntities? in
            let reader = BufferReader(buffer)
            var result: Api.TextWithEntities?
            if let signature = reader.readInt32() {
                result = Api.parse(reader, signature: signature) as? Api.TextWithEntities
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
        return (FunctionDescription(name: "messages.toggleBotInAttachMenu", parameters: [("flags", FunctionParameterDescription(flags)), ("bot", FunctionParameterDescription(bot)), ("enabled", FunctionParameterDescription(enabled))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "messages.toggleDialogFilterTags", parameters: [("enabled", FunctionParameterDescription(enabled))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "messages.toggleDialogPin", parameters: [("flags", FunctionParameterDescription(flags)), ("peer", FunctionParameterDescription(peer))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
    static func toggleNoForwards(flags: Int32, peer: Api.InputPeer, enabled: Api.Bool, requestMsgId: Int32?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let buffer = Buffer()
        buffer.appendInt32(-1308091851)
        serializeInt32(flags, buffer: buffer, boxed: false)
        peer.serialize(buffer, true)
        enabled.serialize(buffer, true)
        if Int(flags) & Int(1 << 0) != 0 {
            serializeInt32(requestMsgId!, buffer: buffer, boxed: false)
        }
        return (FunctionDescription(name: "messages.toggleNoForwards", parameters: [("flags", FunctionParameterDescription(flags)), ("peer", FunctionParameterDescription(peer)), ("enabled", FunctionParameterDescription(enabled)), ("requestMsgId", FunctionParameterDescription(requestMsgId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        return (FunctionDescription(name: "messages.togglePaidReactionPrivacy", parameters: [("peer", FunctionParameterDescription(peer)), ("msgId", FunctionParameterDescription(msgId)), ("`private`", FunctionParameterDescription(`private`))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "messages.togglePeerTranslations", parameters: [("flags", FunctionParameterDescription(flags)), ("peer", FunctionParameterDescription(peer))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "messages.toggleSavedDialogPin", parameters: [("flags", FunctionParameterDescription(flags)), ("peer", FunctionParameterDescription(peer))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "messages.toggleStickerSets", parameters: [("flags", FunctionParameterDescription(flags)), ("stickersets", FunctionParameterDescription(stickersets))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        if Int(flags) & Int(1 << 0) != 0 {
            serializeInt32(scheduleDate!, buffer: buffer, boxed: false)
        }
        if Int(flags) & Int(1 << 2) != 0 {
            serializeString(rejectComment!, buffer: buffer, boxed: false)
        }
        return (FunctionDescription(name: "messages.toggleSuggestedPostApproval", parameters: [("flags", FunctionParameterDescription(flags)), ("peer", FunctionParameterDescription(peer)), ("msgId", FunctionParameterDescription(msgId)), ("scheduleDate", FunctionParameterDescription(scheduleDate)), ("rejectComment", FunctionParameterDescription(rejectComment))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        return (FunctionDescription(name: "messages.toggleTodoCompleted", parameters: [("peer", FunctionParameterDescription(peer)), ("msgId", FunctionParameterDescription(msgId)), ("completed", FunctionParameterDescription(completed)), ("incompleted", FunctionParameterDescription(incompleted))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        return (FunctionDescription(name: "messages.transcribeAudio", parameters: [("peer", FunctionParameterDescription(peer)), ("msgId", FunctionParameterDescription(msgId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.TranscribedAudio? in
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
    static func translateText(flags: Int32, peer: Api.InputPeer?, id: [Int32]?, text: [Api.TextWithEntities]?, toLang: String, tone: String?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.TranslatedText>) {
        let buffer = Buffer()
        buffer.appendInt32(-1511079099)
        serializeInt32(flags, buffer: buffer, boxed: false)
        if Int(flags) & Int(1 << 0) != 0 {
            peer!.serialize(buffer, true)
        }
        if Int(flags) & Int(1 << 0) != 0 {
            buffer.appendInt32(481674261)
            buffer.appendInt32(Int32(id!.count))
            for item in id! {
                serializeInt32(item, buffer: buffer, boxed: false)
            }
        }
        if Int(flags) & Int(1 << 1) != 0 {
            buffer.appendInt32(481674261)
            buffer.appendInt32(Int32(text!.count))
            for item in text! {
                item.serialize(buffer, true)
            }
        }
        serializeString(toLang, buffer: buffer, boxed: false)
        if Int(flags) & Int(1 << 2) != 0 {
            serializeString(tone!, buffer: buffer, boxed: false)
        }
        return (FunctionDescription(name: "messages.translateText", parameters: [("flags", FunctionParameterDescription(flags)), ("peer", FunctionParameterDescription(peer)), ("id", FunctionParameterDescription(id)), ("text", FunctionParameterDescription(text)), ("toLang", FunctionParameterDescription(toLang)), ("tone", FunctionParameterDescription(tone))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.TranslatedText? in
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
        return (FunctionDescription(name: "messages.uninstallStickerSet", parameters: [("stickerset", FunctionParameterDescription(stickerset))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        if Int(flags) & Int(1 << 0) != 0 {
            serializeInt32(topMsgId!, buffer: buffer, boxed: false)
        }
        if Int(flags) & Int(1 << 1) != 0 {
            savedPeerId!.serialize(buffer, true)
        }
        return (FunctionDescription(name: "messages.unpinAllMessages", parameters: [("flags", FunctionParameterDescription(flags)), ("peer", FunctionParameterDescription(peer)), ("topMsgId", FunctionParameterDescription(topMsgId)), ("savedPeerId", FunctionParameterDescription(savedPeerId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.AffectedHistory? in
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
        if Int(flags) & Int(1 << 0) != 0 {
            filter!.serialize(buffer, true)
        }
        return (FunctionDescription(name: "messages.updateDialogFilter", parameters: [("flags", FunctionParameterDescription(flags)), ("id", FunctionParameterDescription(id)), ("filter", FunctionParameterDescription(filter))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "messages.updateDialogFiltersOrder", parameters: [("order", FunctionParameterDescription(order))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
    static func updatePinnedForumTopic(peer: Api.InputPeer, topicId: Int32, pinned: Api.Bool) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let buffer = Buffer()
        buffer.appendInt32(392032849)
        peer.serialize(buffer, true)
        serializeInt32(topicId, buffer: buffer, boxed: false)
        pinned.serialize(buffer, true)
        return (FunctionDescription(name: "messages.updatePinnedForumTopic", parameters: [("peer", FunctionParameterDescription(peer)), ("topicId", FunctionParameterDescription(topicId)), ("pinned", FunctionParameterDescription(pinned))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
    static func updatePinnedMessage(flags: Int32, peer: Api.InputPeer, id: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let buffer = Buffer()
        buffer.appendInt32(-760547348)
        serializeInt32(flags, buffer: buffer, boxed: false)
        peer.serialize(buffer, true)
        serializeInt32(id, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "messages.updatePinnedMessage", parameters: [("flags", FunctionParameterDescription(flags)), ("peer", FunctionParameterDescription(peer)), ("id", FunctionParameterDescription(id))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        if Int(flags) & Int(1 << 0) != 0 {
            serializeString(title!, buffer: buffer, boxed: false)
        }
        return (FunctionDescription(name: "messages.updateSavedReactionTag", parameters: [("flags", FunctionParameterDescription(flags)), ("reaction", FunctionParameterDescription(reaction)), ("title", FunctionParameterDescription(title))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "messages.uploadEncryptedFile", parameters: [("peer", FunctionParameterDescription(peer)), ("file", FunctionParameterDescription(file))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.EncryptedFile? in
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
        return (FunctionDescription(name: "messages.uploadImportedMedia", parameters: [("peer", FunctionParameterDescription(peer)), ("importId", FunctionParameterDescription(importId)), ("fileName", FunctionParameterDescription(fileName)), ("media", FunctionParameterDescription(media))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.MessageMedia? in
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
        if Int(flags) & Int(1 << 0) != 0 {
            serializeString(businessConnectionId!, buffer: buffer, boxed: false)
        }
        peer.serialize(buffer, true)
        media.serialize(buffer, true)
        return (FunctionDescription(name: "messages.uploadMedia", parameters: [("flags", FunctionParameterDescription(flags)), ("businessConnectionId", FunctionParameterDescription(businessConnectionId)), ("peer", FunctionParameterDescription(peer)), ("media", FunctionParameterDescription(media))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.MessageMedia? in
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
        return (FunctionDescription(name: "messages.viewSponsoredMessage", parameters: [("randomId", FunctionParameterDescription(randomId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "payments.applyGiftCode", parameters: [("slug", FunctionParameterDescription(slug))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        return (FunctionDescription(name: "payments.assignAppStoreTransaction", parameters: [("receipt", FunctionParameterDescription(receipt)), ("purpose", FunctionParameterDescription(purpose))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        return (FunctionDescription(name: "payments.assignPlayMarketTransaction", parameters: [("receipt", FunctionParameterDescription(receipt)), ("purpose", FunctionParameterDescription(purpose))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        return (FunctionDescription(name: "payments.botCancelStarsSubscription", parameters: [("flags", FunctionParameterDescription(flags)), ("userId", FunctionParameterDescription(userId)), ("chargeId", FunctionParameterDescription(chargeId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "payments.canPurchaseStore", parameters: [("purpose", FunctionParameterDescription(purpose))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        if Int(flags) & Int(1 << 0) != 0 {
            canceled!.serialize(buffer, true)
        }
        return (FunctionDescription(name: "payments.changeStarsSubscription", parameters: [("flags", FunctionParameterDescription(flags)), ("peer", FunctionParameterDescription(peer)), ("subscriptionId", FunctionParameterDescription(subscriptionId)), ("canceled", FunctionParameterDescription(canceled))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
    static func checkCanSendGift(giftId: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.payments.CheckCanSendGiftResult>) {
        let buffer = Buffer()
        buffer.appendInt32(-1060835895)
        serializeInt64(giftId, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "payments.checkCanSendGift", parameters: [("giftId", FunctionParameterDescription(giftId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.payments.CheckCanSendGiftResult? in
            let reader = BufferReader(buffer)
            var result: Api.payments.CheckCanSendGiftResult?
            if let signature = reader.readInt32() {
                result = Api.parse(reader, signature: signature) as? Api.payments.CheckCanSendGiftResult
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
        return (FunctionDescription(name: "payments.checkGiftCode", parameters: [("slug", FunctionParameterDescription(slug))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.payments.CheckedGiftCode? in
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
        return (FunctionDescription(name: "payments.clearSavedInfo", parameters: [("flags", FunctionParameterDescription(flags))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "payments.connectStarRefBot", parameters: [("peer", FunctionParameterDescription(peer)), ("bot", FunctionParameterDescription(bot))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.payments.ConnectedStarRefBots? in
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
        return (FunctionDescription(name: "payments.convertStarGift", parameters: [("stargift", FunctionParameterDescription(stargift))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
    static func craftStarGift(stargift: [Api.InputSavedStarGift]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let buffer = Buffer()
        buffer.appendInt32(-1325832113)
        buffer.appendInt32(481674261)
        buffer.appendInt32(Int32(stargift.count))
        for item in stargift {
            item.serialize(buffer, true)
        }
        return (FunctionDescription(name: "payments.craftStarGift", parameters: [("stargift", FunctionParameterDescription(stargift))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
    static func createStarGiftCollection(peer: Api.InputPeer, title: String, stargift: [Api.InputSavedStarGift]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.StarGiftCollection>) {
        let buffer = Buffer()
        buffer.appendInt32(524947079)
        peer.serialize(buffer, true)
        serializeString(title, buffer: buffer, boxed: false)
        buffer.appendInt32(481674261)
        buffer.appendInt32(Int32(stargift.count))
        for item in stargift {
            item.serialize(buffer, true)
        }
        return (FunctionDescription(name: "payments.createStarGiftCollection", parameters: [("peer", FunctionParameterDescription(peer)), ("title", FunctionParameterDescription(title)), ("stargift", FunctionParameterDescription(stargift))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.StarGiftCollection? in
            let reader = BufferReader(buffer)
            var result: Api.StarGiftCollection?
            if let signature = reader.readInt32() {
                result = Api.parse(reader, signature: signature) as? Api.StarGiftCollection
            }
            return result
        })
    }
}
public extension Api.functions.payments {
    static func deleteStarGiftCollection(peer: Api.InputPeer, collectionId: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let buffer = Buffer()
        buffer.appendInt32(-1386854168)
        peer.serialize(buffer, true)
        serializeInt32(collectionId, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "payments.deleteStarGiftCollection", parameters: [("peer", FunctionParameterDescription(peer)), ("collectionId", FunctionParameterDescription(collectionId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "payments.editConnectedStarRefBot", parameters: [("flags", FunctionParameterDescription(flags)), ("peer", FunctionParameterDescription(peer)), ("link", FunctionParameterDescription(link))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.payments.ConnectedStarRefBots? in
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
        return (FunctionDescription(name: "payments.exportInvoice", parameters: [("invoiceMedia", FunctionParameterDescription(invoiceMedia))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.payments.ExportedInvoice? in
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
        return (FunctionDescription(name: "payments.fulfillStarsSubscription", parameters: [("peer", FunctionParameterDescription(peer)), ("subscriptionId", FunctionParameterDescription(subscriptionId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "payments.getBankCardData", parameters: [("number", FunctionParameterDescription(number))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.payments.BankCardData? in
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
        return (FunctionDescription(name: "payments.getConnectedStarRefBot", parameters: [("peer", FunctionParameterDescription(peer)), ("bot", FunctionParameterDescription(bot))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.payments.ConnectedStarRefBots? in
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
        if Int(flags) & Int(1 << 2) != 0 {
            serializeInt32(offsetDate!, buffer: buffer, boxed: false)
        }
        if Int(flags) & Int(1 << 2) != 0 {
            serializeString(offsetLink!, buffer: buffer, boxed: false)
        }
        serializeInt32(limit, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "payments.getConnectedStarRefBots", parameters: [("flags", FunctionParameterDescription(flags)), ("peer", FunctionParameterDescription(peer)), ("offsetDate", FunctionParameterDescription(offsetDate)), ("offsetLink", FunctionParameterDescription(offsetLink)), ("limit", FunctionParameterDescription(limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.payments.ConnectedStarRefBots? in
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
    static func getCraftStarGifts(giftId: Int64, offset: String, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.payments.SavedStarGifts>) {
        let buffer = Buffer()
        buffer.appendInt32(-49947392)
        serializeInt64(giftId, buffer: buffer, boxed: false)
        serializeString(offset, buffer: buffer, boxed: false)
        serializeInt32(limit, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "payments.getCraftStarGifts", parameters: [("giftId", FunctionParameterDescription(giftId)), ("offset", FunctionParameterDescription(offset)), ("limit", FunctionParameterDescription(limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.payments.SavedStarGifts? in
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
    static func getGiveawayInfo(peer: Api.InputPeer, msgId: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.payments.GiveawayInfo>) {
        let buffer = Buffer()
        buffer.appendInt32(-198994907)
        peer.serialize(buffer, true)
        serializeInt32(msgId, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "payments.getGiveawayInfo", parameters: [("peer", FunctionParameterDescription(peer)), ("msgId", FunctionParameterDescription(msgId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.payments.GiveawayInfo? in
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
        if Int(flags) & Int(1 << 0) != 0 {
            themeParams!.serialize(buffer, true)
        }
        return (FunctionDescription(name: "payments.getPaymentForm", parameters: [("flags", FunctionParameterDescription(flags)), ("invoice", FunctionParameterDescription(invoice)), ("themeParams", FunctionParameterDescription(themeParams))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.payments.PaymentForm? in
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
        return (FunctionDescription(name: "payments.getPaymentReceipt", parameters: [("peer", FunctionParameterDescription(peer)), ("msgId", FunctionParameterDescription(msgId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.payments.PaymentReceipt? in
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
        if Int(flags) & Int(1 << 0) != 0 {
            boostPeer!.serialize(buffer, true)
        }
        return (FunctionDescription(name: "payments.getPremiumGiftCodeOptions", parameters: [("flags", FunctionParameterDescription(flags)), ("boostPeer", FunctionParameterDescription(boostPeer))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> [Api.PremiumGiftCodeOption]? in
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
        if Int(flags) & Int(1 << 0) != 0 {
            serializeInt64(attributesHash!, buffer: buffer, boxed: false)
        }
        serializeInt64(giftId, buffer: buffer, boxed: false)
        if Int(flags) & Int(1 << 3) != 0 {
            buffer.appendInt32(481674261)
            buffer.appendInt32(Int32(attributes!.count))
            for item in attributes! {
                item.serialize(buffer, true)
            }
        }
        serializeString(offset, buffer: buffer, boxed: false)
        serializeInt32(limit, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "payments.getResaleStarGifts", parameters: [("flags", FunctionParameterDescription(flags)), ("attributesHash", FunctionParameterDescription(attributesHash)), ("giftId", FunctionParameterDescription(giftId)), ("attributes", FunctionParameterDescription(attributes)), ("offset", FunctionParameterDescription(offset)), ("limit", FunctionParameterDescription(limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.payments.ResaleStarGifts? in
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
        return (FunctionDescription(name: "payments.getSavedStarGift", parameters: [("stargift", FunctionParameterDescription(stargift))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.payments.SavedStarGifts? in
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
    static func getSavedStarGifts(flags: Int32, peer: Api.InputPeer, collectionId: Int32?, offset: String, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.payments.SavedStarGifts>) {
        let buffer = Buffer()
        buffer.appendInt32(-1558583959)
        serializeInt32(flags, buffer: buffer, boxed: false)
        peer.serialize(buffer, true)
        if Int(flags) & Int(1 << 6) != 0 {
            serializeInt32(collectionId!, buffer: buffer, boxed: false)
        }
        serializeString(offset, buffer: buffer, boxed: false)
        serializeInt32(limit, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "payments.getSavedStarGifts", parameters: [("flags", FunctionParameterDescription(flags)), ("peer", FunctionParameterDescription(peer)), ("collectionId", FunctionParameterDescription(collectionId)), ("offset", FunctionParameterDescription(offset)), ("limit", FunctionParameterDescription(limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.payments.SavedStarGifts? in
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
    static func getStarGiftActiveAuctions(hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.payments.StarGiftActiveAuctions>) {
        let buffer = Buffer()
        buffer.appendInt32(-1513074355)
        serializeInt64(hash, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "payments.getStarGiftActiveAuctions", parameters: [("hash", FunctionParameterDescription(hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.payments.StarGiftActiveAuctions? in
            let reader = BufferReader(buffer)
            var result: Api.payments.StarGiftActiveAuctions?
            if let signature = reader.readInt32() {
                result = Api.parse(reader, signature: signature) as? Api.payments.StarGiftActiveAuctions
            }
            return result
        })
    }
}
public extension Api.functions.payments {
    static func getStarGiftAuctionAcquiredGifts(giftId: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.payments.StarGiftAuctionAcquiredGifts>) {
        let buffer = Buffer()
        buffer.appendInt32(1805831148)
        serializeInt64(giftId, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "payments.getStarGiftAuctionAcquiredGifts", parameters: [("giftId", FunctionParameterDescription(giftId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.payments.StarGiftAuctionAcquiredGifts? in
            let reader = BufferReader(buffer)
            var result: Api.payments.StarGiftAuctionAcquiredGifts?
            if let signature = reader.readInt32() {
                result = Api.parse(reader, signature: signature) as? Api.payments.StarGiftAuctionAcquiredGifts
            }
            return result
        })
    }
}
public extension Api.functions.payments {
    static func getStarGiftAuctionState(auction: Api.InputStarGiftAuction, version: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.payments.StarGiftAuctionState>) {
        let buffer = Buffer()
        buffer.appendInt32(1553986774)
        auction.serialize(buffer, true)
        serializeInt32(version, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "payments.getStarGiftAuctionState", parameters: [("auction", FunctionParameterDescription(auction)), ("version", FunctionParameterDescription(version))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.payments.StarGiftAuctionState? in
            let reader = BufferReader(buffer)
            var result: Api.payments.StarGiftAuctionState?
            if let signature = reader.readInt32() {
                result = Api.parse(reader, signature: signature) as? Api.payments.StarGiftAuctionState
            }
            return result
        })
    }
}
public extension Api.functions.payments {
    static func getStarGiftCollections(peer: Api.InputPeer, hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.payments.StarGiftCollections>) {
        let buffer = Buffer()
        buffer.appendInt32(-1743023651)
        peer.serialize(buffer, true)
        serializeInt64(hash, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "payments.getStarGiftCollections", parameters: [("peer", FunctionParameterDescription(peer)), ("hash", FunctionParameterDescription(hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.payments.StarGiftCollections? in
            let reader = BufferReader(buffer)
            var result: Api.payments.StarGiftCollections?
            if let signature = reader.readInt32() {
                result = Api.parse(reader, signature: signature) as? Api.payments.StarGiftCollections
            }
            return result
        })
    }
}
public extension Api.functions.payments {
    static func getStarGiftUpgradeAttributes(giftId: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.payments.StarGiftUpgradeAttributes>) {
        let buffer = Buffer()
        buffer.appendInt32(1828948824)
        serializeInt64(giftId, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "payments.getStarGiftUpgradeAttributes", parameters: [("giftId", FunctionParameterDescription(giftId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.payments.StarGiftUpgradeAttributes? in
            let reader = BufferReader(buffer)
            var result: Api.payments.StarGiftUpgradeAttributes?
            if let signature = reader.readInt32() {
                result = Api.parse(reader, signature: signature) as? Api.payments.StarGiftUpgradeAttributes
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
        return (FunctionDescription(name: "payments.getStarGiftUpgradePreview", parameters: [("giftId", FunctionParameterDescription(giftId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.payments.StarGiftUpgradePreview? in
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
        return (FunctionDescription(name: "payments.getStarGiftWithdrawalUrl", parameters: [("stargift", FunctionParameterDescription(stargift)), ("password", FunctionParameterDescription(password))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.payments.StarGiftWithdrawalUrl? in
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
        return (FunctionDescription(name: "payments.getStarGifts", parameters: [("hash", FunctionParameterDescription(hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.payments.StarGifts? in
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
        if Int(flags) & Int(1 << 0) != 0 {
            userId!.serialize(buffer, true)
        }
        return (FunctionDescription(name: "payments.getStarsGiftOptions", parameters: [("flags", FunctionParameterDescription(flags)), ("userId", FunctionParameterDescription(userId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> [Api.StarsGiftOption]? in
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
        return (FunctionDescription(name: "payments.getStarsRevenueAdsAccountUrl", parameters: [("peer", FunctionParameterDescription(peer))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.payments.StarsRevenueAdsAccountUrl? in
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
        return (FunctionDescription(name: "payments.getStarsRevenueStats", parameters: [("flags", FunctionParameterDescription(flags)), ("peer", FunctionParameterDescription(peer))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.payments.StarsRevenueStats? in
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
        if Int(flags) & Int(1 << 1) != 0 {
            serializeInt64(amount!, buffer: buffer, boxed: false)
        }
        password.serialize(buffer, true)
        return (FunctionDescription(name: "payments.getStarsRevenueWithdrawalUrl", parameters: [("flags", FunctionParameterDescription(flags)), ("peer", FunctionParameterDescription(peer)), ("amount", FunctionParameterDescription(amount)), ("password", FunctionParameterDescription(password))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.payments.StarsRevenueWithdrawalUrl? in
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
        return (FunctionDescription(name: "payments.getStarsStatus", parameters: [("flags", FunctionParameterDescription(flags)), ("peer", FunctionParameterDescription(peer))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.payments.StarsStatus? in
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
        return (FunctionDescription(name: "payments.getStarsSubscriptions", parameters: [("flags", FunctionParameterDescription(flags)), ("peer", FunctionParameterDescription(peer)), ("offset", FunctionParameterDescription(offset))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.payments.StarsStatus? in
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
        if Int(flags) & Int(1 << 3) != 0 {
            serializeString(subscriptionId!, buffer: buffer, boxed: false)
        }
        peer.serialize(buffer, true)
        serializeString(offset, buffer: buffer, boxed: false)
        serializeInt32(limit, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "payments.getStarsTransactions", parameters: [("flags", FunctionParameterDescription(flags)), ("subscriptionId", FunctionParameterDescription(subscriptionId)), ("peer", FunctionParameterDescription(peer)), ("offset", FunctionParameterDescription(offset)), ("limit", FunctionParameterDescription(limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.payments.StarsStatus? in
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
        return (FunctionDescription(name: "payments.getStarsTransactionsByID", parameters: [("flags", FunctionParameterDescription(flags)), ("peer", FunctionParameterDescription(peer)), ("id", FunctionParameterDescription(id))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.payments.StarsStatus? in
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
        return (FunctionDescription(name: "payments.getSuggestedStarRefBots", parameters: [("flags", FunctionParameterDescription(flags)), ("peer", FunctionParameterDescription(peer)), ("offset", FunctionParameterDescription(offset)), ("limit", FunctionParameterDescription(limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.payments.SuggestedStarRefBots? in
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
        return (FunctionDescription(name: "payments.getUniqueStarGift", parameters: [("slug", FunctionParameterDescription(slug))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.payments.UniqueStarGift? in
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
    static func getUniqueStarGiftValueInfo(slug: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.payments.UniqueStarGiftValueInfo>) {
        let buffer = Buffer()
        buffer.appendInt32(1130737515)
        serializeString(slug, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "payments.getUniqueStarGiftValueInfo", parameters: [("slug", FunctionParameterDescription(slug))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.payments.UniqueStarGiftValueInfo? in
            let reader = BufferReader(buffer)
            var result: Api.payments.UniqueStarGiftValueInfo?
            if let signature = reader.readInt32() {
                result = Api.parse(reader, signature: signature) as? Api.payments.UniqueStarGiftValueInfo
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
        return (FunctionDescription(name: "payments.launchPrepaidGiveaway", parameters: [("peer", FunctionParameterDescription(peer)), ("giveawayId", FunctionParameterDescription(giveawayId)), ("purpose", FunctionParameterDescription(purpose))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        return (FunctionDescription(name: "payments.refundStarsCharge", parameters: [("userId", FunctionParameterDescription(userId)), ("chargeId", FunctionParameterDescription(chargeId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
    static func reorderStarGiftCollections(peer: Api.InputPeer, order: [Int32]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let buffer = Buffer()
        buffer.appendInt32(-1020594996)
        peer.serialize(buffer, true)
        buffer.appendInt32(481674261)
        buffer.appendInt32(Int32(order.count))
        for item in order {
            serializeInt32(item, buffer: buffer, boxed: false)
        }
        return (FunctionDescription(name: "payments.reorderStarGiftCollections", parameters: [("peer", FunctionParameterDescription(peer)), ("order", FunctionParameterDescription(order))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
    static func resolveStarGiftOffer(flags: Int32, offerMsgId: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let buffer = Buffer()
        buffer.appendInt32(-372344804)
        serializeInt32(flags, buffer: buffer, boxed: false)
        serializeInt32(offerMsgId, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "payments.resolveStarGiftOffer", parameters: [("flags", FunctionParameterDescription(flags)), ("offerMsgId", FunctionParameterDescription(offerMsgId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        return (FunctionDescription(name: "payments.saveStarGift", parameters: [("flags", FunctionParameterDescription(flags)), ("stargift", FunctionParameterDescription(stargift))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        if Int(flags) & Int(1 << 0) != 0 {
            serializeString(requestedInfoId!, buffer: buffer, boxed: false)
        }
        if Int(flags) & Int(1 << 1) != 0 {
            serializeString(shippingOptionId!, buffer: buffer, boxed: false)
        }
        credentials.serialize(buffer, true)
        if Int(flags) & Int(1 << 2) != 0 {
            serializeInt64(tipAmount!, buffer: buffer, boxed: false)
        }
        return (FunctionDescription(name: "payments.sendPaymentForm", parameters: [("flags", FunctionParameterDescription(flags)), ("formId", FunctionParameterDescription(formId)), ("invoice", FunctionParameterDescription(invoice)), ("requestedInfoId", FunctionParameterDescription(requestedInfoId)), ("shippingOptionId", FunctionParameterDescription(shippingOptionId)), ("credentials", FunctionParameterDescription(credentials)), ("tipAmount", FunctionParameterDescription(tipAmount))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.payments.PaymentResult? in
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
    static func sendStarGiftOffer(flags: Int32, peer: Api.InputPeer, slug: String, price: Api.StarsAmount, duration: Int32, randomId: Int64, allowPaidStars: Int64?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let buffer = Buffer()
        buffer.appendInt32(-1883739327)
        serializeInt32(flags, buffer: buffer, boxed: false)
        peer.serialize(buffer, true)
        serializeString(slug, buffer: buffer, boxed: false)
        price.serialize(buffer, true)
        serializeInt32(duration, buffer: buffer, boxed: false)
        serializeInt64(randomId, buffer: buffer, boxed: false)
        if Int(flags) & Int(1 << 0) != 0 {
            serializeInt64(allowPaidStars!, buffer: buffer, boxed: false)
        }
        return (FunctionDescription(name: "payments.sendStarGiftOffer", parameters: [("flags", FunctionParameterDescription(flags)), ("peer", FunctionParameterDescription(peer)), ("slug", FunctionParameterDescription(slug)), ("price", FunctionParameterDescription(price)), ("duration", FunctionParameterDescription(duration)), ("randomId", FunctionParameterDescription(randomId)), ("allowPaidStars", FunctionParameterDescription(allowPaidStars))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
    static func sendStarsForm(formId: Int64, invoice: Api.InputInvoice) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.payments.PaymentResult>) {
        let buffer = Buffer()
        buffer.appendInt32(2040056084)
        serializeInt64(formId, buffer: buffer, boxed: false)
        invoice.serialize(buffer, true)
        return (FunctionDescription(name: "payments.sendStarsForm", parameters: [("formId", FunctionParameterDescription(formId)), ("invoice", FunctionParameterDescription(invoice))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.payments.PaymentResult? in
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
        return (FunctionDescription(name: "payments.toggleChatStarGiftNotifications", parameters: [("flags", FunctionParameterDescription(flags)), ("peer", FunctionParameterDescription(peer))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "payments.toggleStarGiftsPinnedToTop", parameters: [("peer", FunctionParameterDescription(peer)), ("stargift", FunctionParameterDescription(stargift))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "payments.transferStarGift", parameters: [("stargift", FunctionParameterDescription(stargift)), ("toId", FunctionParameterDescription(toId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
    static func updateStarGiftCollection(flags: Int32, peer: Api.InputPeer, collectionId: Int32, title: String?, deleteStargift: [Api.InputSavedStarGift]?, addStargift: [Api.InputSavedStarGift]?, order: [Api.InputSavedStarGift]?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.StarGiftCollection>) {
        let buffer = Buffer()
        buffer.appendInt32(1339932391)
        serializeInt32(flags, buffer: buffer, boxed: false)
        peer.serialize(buffer, true)
        serializeInt32(collectionId, buffer: buffer, boxed: false)
        if Int(flags) & Int(1 << 0) != 0 {
            serializeString(title!, buffer: buffer, boxed: false)
        }
        if Int(flags) & Int(1 << 1) != 0 {
            buffer.appendInt32(481674261)
            buffer.appendInt32(Int32(deleteStargift!.count))
            for item in deleteStargift! {
                item.serialize(buffer, true)
            }
        }
        if Int(flags) & Int(1 << 2) != 0 {
            buffer.appendInt32(481674261)
            buffer.appendInt32(Int32(addStargift!.count))
            for item in addStargift! {
                item.serialize(buffer, true)
            }
        }
        if Int(flags) & Int(1 << 3) != 0 {
            buffer.appendInt32(481674261)
            buffer.appendInt32(Int32(order!.count))
            for item in order! {
                item.serialize(buffer, true)
            }
        }
        return (FunctionDescription(name: "payments.updateStarGiftCollection", parameters: [("flags", FunctionParameterDescription(flags)), ("peer", FunctionParameterDescription(peer)), ("collectionId", FunctionParameterDescription(collectionId)), ("title", FunctionParameterDescription(title)), ("deleteStargift", FunctionParameterDescription(deleteStargift)), ("addStargift", FunctionParameterDescription(addStargift)), ("order", FunctionParameterDescription(order))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.StarGiftCollection? in
            let reader = BufferReader(buffer)
            var result: Api.StarGiftCollection?
            if let signature = reader.readInt32() {
                result = Api.parse(reader, signature: signature) as? Api.StarGiftCollection
            }
            return result
        })
    }
}
public extension Api.functions.payments {
    static func updateStarGiftPrice(stargift: Api.InputSavedStarGift, resellAmount: Api.StarsAmount) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let buffer = Buffer()
        buffer.appendInt32(-306287413)
        stargift.serialize(buffer, true)
        resellAmount.serialize(buffer, true)
        return (FunctionDescription(name: "payments.updateStarGiftPrice", parameters: [("stargift", FunctionParameterDescription(stargift)), ("resellAmount", FunctionParameterDescription(resellAmount))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        return (FunctionDescription(name: "payments.upgradeStarGift", parameters: [("flags", FunctionParameterDescription(flags)), ("stargift", FunctionParameterDescription(stargift))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        return (FunctionDescription(name: "payments.validateRequestedInfo", parameters: [("flags", FunctionParameterDescription(flags)), ("invoice", FunctionParameterDescription(invoice)), ("info", FunctionParameterDescription(info))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.payments.ValidatedRequestedInfo? in
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
        return (FunctionDescription(name: "phone.acceptCall", parameters: [("peer", FunctionParameterDescription(peer)), ("gB", FunctionParameterDescription(gB)), ("`protocol`", FunctionParameterDescription(`protocol`))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.phone.PhoneCall? in
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
        return (FunctionDescription(name: "phone.checkGroupCall", parameters: [("call", FunctionParameterDescription(call)), ("sources", FunctionParameterDescription(sources))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> [Int32]? in
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
        return (FunctionDescription(name: "phone.confirmCall", parameters: [("peer", FunctionParameterDescription(peer)), ("gA", FunctionParameterDescription(gA)), ("keyFingerprint", FunctionParameterDescription(keyFingerprint)), ("`protocol`", FunctionParameterDescription(`protocol`))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.phone.PhoneCall? in
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
        if Int(flags) & Int(1 << 3) != 0 {
            serializeInt256(publicKey!, buffer: buffer, boxed: false)
        }
        if Int(flags) & Int(1 << 3) != 0 {
            serializeBytes(block!, buffer: buffer, boxed: false)
        }
        if Int(flags) & Int(1 << 3) != 0 {
            params!.serialize(buffer, true)
        }
        return (FunctionDescription(name: "phone.createConferenceCall", parameters: [("flags", FunctionParameterDescription(flags)), ("randomId", FunctionParameterDescription(randomId)), ("publicKey", FunctionParameterDescription(publicKey)), ("block", FunctionParameterDescription(block)), ("params", FunctionParameterDescription(params))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        if Int(flags) & Int(1 << 0) != 0 {
            serializeString(title!, buffer: buffer, boxed: false)
        }
        if Int(flags) & Int(1 << 1) != 0 {
            serializeInt32(scheduleDate!, buffer: buffer, boxed: false)
        }
        return (FunctionDescription(name: "phone.createGroupCall", parameters: [("flags", FunctionParameterDescription(flags)), ("peer", FunctionParameterDescription(peer)), ("randomId", FunctionParameterDescription(randomId)), ("title", FunctionParameterDescription(title)), ("scheduleDate", FunctionParameterDescription(scheduleDate))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        return (FunctionDescription(name: "phone.declineConferenceCallInvite", parameters: [("msgId", FunctionParameterDescription(msgId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        return (FunctionDescription(name: "phone.deleteConferenceCallParticipants", parameters: [("flags", FunctionParameterDescription(flags)), ("call", FunctionParameterDescription(call)), ("ids", FunctionParameterDescription(ids)), ("block", FunctionParameterDescription(block))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
    static func deleteGroupCallMessages(flags: Int32, call: Api.InputGroupCall, messages: [Int32]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let buffer = Buffer()
        buffer.appendInt32(-162573065)
        serializeInt32(flags, buffer: buffer, boxed: false)
        call.serialize(buffer, true)
        buffer.appendInt32(481674261)
        buffer.appendInt32(Int32(messages.count))
        for item in messages {
            serializeInt32(item, buffer: buffer, boxed: false)
        }
        return (FunctionDescription(name: "phone.deleteGroupCallMessages", parameters: [("flags", FunctionParameterDescription(flags)), ("call", FunctionParameterDescription(call)), ("messages", FunctionParameterDescription(messages))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
    static func deleteGroupCallParticipantMessages(flags: Int32, call: Api.InputGroupCall, participant: Api.InputPeer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let buffer = Buffer()
        buffer.appendInt32(499117216)
        serializeInt32(flags, buffer: buffer, boxed: false)
        call.serialize(buffer, true)
        participant.serialize(buffer, true)
        return (FunctionDescription(name: "phone.deleteGroupCallParticipantMessages", parameters: [("flags", FunctionParameterDescription(flags)), ("call", FunctionParameterDescription(call)), ("participant", FunctionParameterDescription(participant))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        return (FunctionDescription(name: "phone.discardCall", parameters: [("flags", FunctionParameterDescription(flags)), ("peer", FunctionParameterDescription(peer)), ("duration", FunctionParameterDescription(duration)), ("reason", FunctionParameterDescription(reason)), ("connectionId", FunctionParameterDescription(connectionId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        return (FunctionDescription(name: "phone.discardGroupCall", parameters: [("call", FunctionParameterDescription(call))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        if Int(flags) & Int(1 << 0) != 0 {
            muted!.serialize(buffer, true)
        }
        if Int(flags) & Int(1 << 1) != 0 {
            serializeInt32(volume!, buffer: buffer, boxed: false)
        }
        if Int(flags) & Int(1 << 2) != 0 {
            raiseHand!.serialize(buffer, true)
        }
        if Int(flags) & Int(1 << 3) != 0 {
            videoStopped!.serialize(buffer, true)
        }
        if Int(flags) & Int(1 << 4) != 0 {
            videoPaused!.serialize(buffer, true)
        }
        if Int(flags) & Int(1 << 5) != 0 {
            presentationPaused!.serialize(buffer, true)
        }
        return (FunctionDescription(name: "phone.editGroupCallParticipant", parameters: [("flags", FunctionParameterDescription(flags)), ("call", FunctionParameterDescription(call)), ("participant", FunctionParameterDescription(participant)), ("muted", FunctionParameterDescription(muted)), ("volume", FunctionParameterDescription(volume)), ("raiseHand", FunctionParameterDescription(raiseHand)), ("videoStopped", FunctionParameterDescription(videoStopped)), ("videoPaused", FunctionParameterDescription(videoPaused)), ("presentationPaused", FunctionParameterDescription(presentationPaused))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        return (FunctionDescription(name: "phone.editGroupCallTitle", parameters: [("call", FunctionParameterDescription(call)), ("title", FunctionParameterDescription(title))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        return (FunctionDescription(name: "phone.exportGroupCallInvite", parameters: [("flags", FunctionParameterDescription(flags)), ("call", FunctionParameterDescription(call))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.phone.ExportedGroupCallInvite? in
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
        return (FunctionDescription(name: "phone.getGroupCall", parameters: [("call", FunctionParameterDescription(call)), ("limit", FunctionParameterDescription(limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.phone.GroupCall? in
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
        return (FunctionDescription(name: "phone.getGroupCallChainBlocks", parameters: [("call", FunctionParameterDescription(call)), ("subChainId", FunctionParameterDescription(subChainId)), ("offset", FunctionParameterDescription(offset)), ("limit", FunctionParameterDescription(limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        return (FunctionDescription(name: "phone.getGroupCallJoinAs", parameters: [("peer", FunctionParameterDescription(peer))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.phone.JoinAsPeers? in
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
    static func getGroupCallStars(call: Api.InputGroupCall) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.phone.GroupCallStars>) {
        let buffer = Buffer()
        buffer.appendInt32(1868784386)
        call.serialize(buffer, true)
        return (FunctionDescription(name: "phone.getGroupCallStars", parameters: [("call", FunctionParameterDescription(call))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.phone.GroupCallStars? in
            let reader = BufferReader(buffer)
            var result: Api.phone.GroupCallStars?
            if let signature = reader.readInt32() {
                result = Api.parse(reader, signature: signature) as? Api.phone.GroupCallStars
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
        return (FunctionDescription(name: "phone.getGroupCallStreamChannels", parameters: [("call", FunctionParameterDescription(call))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.phone.GroupCallStreamChannels? in
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
    static func getGroupCallStreamRtmpUrl(flags: Int32, peer: Api.InputPeer, revoke: Api.Bool) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.phone.GroupCallStreamRtmpUrl>) {
        let buffer = Buffer()
        buffer.appendInt32(1525991226)
        serializeInt32(flags, buffer: buffer, boxed: false)
        peer.serialize(buffer, true)
        revoke.serialize(buffer, true)
        return (FunctionDescription(name: "phone.getGroupCallStreamRtmpUrl", parameters: [("flags", FunctionParameterDescription(flags)), ("peer", FunctionParameterDescription(peer)), ("revoke", FunctionParameterDescription(revoke))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.phone.GroupCallStreamRtmpUrl? in
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
        return (FunctionDescription(name: "phone.getGroupParticipants", parameters: [("call", FunctionParameterDescription(call)), ("ids", FunctionParameterDescription(ids)), ("sources", FunctionParameterDescription(sources)), ("offset", FunctionParameterDescription(offset)), ("limit", FunctionParameterDescription(limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.phone.GroupParticipants? in
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
        return (FunctionDescription(name: "phone.inviteConferenceCallParticipant", parameters: [("flags", FunctionParameterDescription(flags)), ("call", FunctionParameterDescription(call)), ("userId", FunctionParameterDescription(userId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        return (FunctionDescription(name: "phone.inviteToGroupCall", parameters: [("call", FunctionParameterDescription(call)), ("users", FunctionParameterDescription(users))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        if Int(flags) & Int(1 << 1) != 0 {
            serializeString(inviteHash!, buffer: buffer, boxed: false)
        }
        if Int(flags) & Int(1 << 3) != 0 {
            serializeInt256(publicKey!, buffer: buffer, boxed: false)
        }
        if Int(flags) & Int(1 << 3) != 0 {
            serializeBytes(block!, buffer: buffer, boxed: false)
        }
        params.serialize(buffer, true)
        return (FunctionDescription(name: "phone.joinGroupCall", parameters: [("flags", FunctionParameterDescription(flags)), ("call", FunctionParameterDescription(call)), ("joinAs", FunctionParameterDescription(joinAs)), ("inviteHash", FunctionParameterDescription(inviteHash)), ("publicKey", FunctionParameterDescription(publicKey)), ("block", FunctionParameterDescription(block)), ("params", FunctionParameterDescription(params))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        return (FunctionDescription(name: "phone.joinGroupCallPresentation", parameters: [("call", FunctionParameterDescription(call)), ("params", FunctionParameterDescription(params))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        return (FunctionDescription(name: "phone.leaveGroupCall", parameters: [("call", FunctionParameterDescription(call)), ("source", FunctionParameterDescription(source))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        return (FunctionDescription(name: "phone.leaveGroupCallPresentation", parameters: [("call", FunctionParameterDescription(call))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        return (FunctionDescription(name: "phone.receivedCall", parameters: [("peer", FunctionParameterDescription(peer))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "phone.requestCall", parameters: [("flags", FunctionParameterDescription(flags)), ("userId", FunctionParameterDescription(userId)), ("randomId", FunctionParameterDescription(randomId)), ("gAHash", FunctionParameterDescription(gAHash)), ("`protocol`", FunctionParameterDescription(`protocol`))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.phone.PhoneCall? in
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
        return (FunctionDescription(name: "phone.saveCallDebug", parameters: [("peer", FunctionParameterDescription(peer)), ("debug", FunctionParameterDescription(debug))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "phone.saveCallLog", parameters: [("peer", FunctionParameterDescription(peer)), ("file", FunctionParameterDescription(file))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "phone.saveDefaultGroupCallJoinAs", parameters: [("peer", FunctionParameterDescription(peer)), ("joinAs", FunctionParameterDescription(joinAs))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
    static func saveDefaultSendAs(call: Api.InputGroupCall, sendAs: Api.InputPeer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let buffer = Buffer()
        buffer.appendInt32(1097313745)
        call.serialize(buffer, true)
        sendAs.serialize(buffer, true)
        return (FunctionDescription(name: "phone.saveDefaultSendAs", parameters: [("call", FunctionParameterDescription(call)), ("sendAs", FunctionParameterDescription(sendAs))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "phone.sendConferenceCallBroadcast", parameters: [("call", FunctionParameterDescription(call)), ("block", FunctionParameterDescription(block))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
    static func sendGroupCallEncryptedMessage(call: Api.InputGroupCall, encryptedMessage: Buffer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let buffer = Buffer()
        buffer.appendInt32(-441473683)
        call.serialize(buffer, true)
        serializeBytes(encryptedMessage, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "phone.sendGroupCallEncryptedMessage", parameters: [("call", FunctionParameterDescription(call)), ("encryptedMessage", FunctionParameterDescription(encryptedMessage))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
    static func sendGroupCallMessage(flags: Int32, call: Api.InputGroupCall, randomId: Int64, message: Api.TextWithEntities, allowPaidStars: Int64?, sendAs: Api.InputPeer?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let buffer = Buffer()
        buffer.appendInt32(-1311697904)
        serializeInt32(flags, buffer: buffer, boxed: false)
        call.serialize(buffer, true)
        serializeInt64(randomId, buffer: buffer, boxed: false)
        message.serialize(buffer, true)
        if Int(flags) & Int(1 << 0) != 0 {
            serializeInt64(allowPaidStars!, buffer: buffer, boxed: false)
        }
        if Int(flags) & Int(1 << 1) != 0 {
            sendAs!.serialize(buffer, true)
        }
        return (FunctionDescription(name: "phone.sendGroupCallMessage", parameters: [("flags", FunctionParameterDescription(flags)), ("call", FunctionParameterDescription(call)), ("randomId", FunctionParameterDescription(randomId)), ("message", FunctionParameterDescription(message)), ("allowPaidStars", FunctionParameterDescription(allowPaidStars)), ("sendAs", FunctionParameterDescription(sendAs))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        return (FunctionDescription(name: "phone.sendSignalingData", parameters: [("peer", FunctionParameterDescription(peer)), ("data", FunctionParameterDescription(data))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "phone.setCallRating", parameters: [("flags", FunctionParameterDescription(flags)), ("peer", FunctionParameterDescription(peer)), ("rating", FunctionParameterDescription(rating)), ("comment", FunctionParameterDescription(comment))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        return (FunctionDescription(name: "phone.startScheduledGroupCall", parameters: [("call", FunctionParameterDescription(call))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        if Int(flags) & Int(1 << 1) != 0 {
            serializeString(title!, buffer: buffer, boxed: false)
        }
        if Int(flags) & Int(1 << 2) != 0 {
            videoPortrait!.serialize(buffer, true)
        }
        return (FunctionDescription(name: "phone.toggleGroupCallRecord", parameters: [("flags", FunctionParameterDescription(flags)), ("call", FunctionParameterDescription(call)), ("title", FunctionParameterDescription(title)), ("videoPortrait", FunctionParameterDescription(videoPortrait))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
    static func toggleGroupCallSettings(flags: Int32, call: Api.InputGroupCall, joinMuted: Api.Bool?, messagesEnabled: Api.Bool?, sendPaidMessagesStars: Int64?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let buffer = Buffer()
        buffer.appendInt32(-1757179150)
        serializeInt32(flags, buffer: buffer, boxed: false)
        call.serialize(buffer, true)
        if Int(flags) & Int(1 << 0) != 0 {
            joinMuted!.serialize(buffer, true)
        }
        if Int(flags) & Int(1 << 2) != 0 {
            messagesEnabled!.serialize(buffer, true)
        }
        if Int(flags) & Int(1 << 3) != 0 {
            serializeInt64(sendPaidMessagesStars!, buffer: buffer, boxed: false)
        }
        return (FunctionDescription(name: "phone.toggleGroupCallSettings", parameters: [("flags", FunctionParameterDescription(flags)), ("call", FunctionParameterDescription(call)), ("joinMuted", FunctionParameterDescription(joinMuted)), ("messagesEnabled", FunctionParameterDescription(messagesEnabled)), ("sendPaidMessagesStars", FunctionParameterDescription(sendPaidMessagesStars))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        return (FunctionDescription(name: "phone.toggleGroupCallStartSubscription", parameters: [("call", FunctionParameterDescription(call)), ("subscribed", FunctionParameterDescription(subscribed))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        return (FunctionDescription(name: "photos.deletePhotos", parameters: [("id", FunctionParameterDescription(id))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> [Int64]? in
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
        return (FunctionDescription(name: "photos.getUserPhotos", parameters: [("userId", FunctionParameterDescription(userId)), ("offset", FunctionParameterDescription(offset)), ("maxId", FunctionParameterDescription(maxId)), ("limit", FunctionParameterDescription(limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.photos.Photos? in
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
        if Int(flags) & Int(1 << 1) != 0 {
            bot!.serialize(buffer, true)
        }
        id.serialize(buffer, true)
        return (FunctionDescription(name: "photos.updateProfilePhoto", parameters: [("flags", FunctionParameterDescription(flags)), ("bot", FunctionParameterDescription(bot)), ("id", FunctionParameterDescription(id))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.photos.Photo? in
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
        if Int(flags) & Int(1 << 0) != 0 {
            file!.serialize(buffer, true)
        }
        if Int(flags) & Int(1 << 1) != 0 {
            video!.serialize(buffer, true)
        }
        if Int(flags) & Int(1 << 2) != 0 {
            serializeDouble(videoStartTs!, buffer: buffer, boxed: false)
        }
        if Int(flags) & Int(1 << 5) != 0 {
            videoEmojiMarkup!.serialize(buffer, true)
        }
        return (FunctionDescription(name: "photos.uploadContactProfilePhoto", parameters: [("flags", FunctionParameterDescription(flags)), ("userId", FunctionParameterDescription(userId)), ("file", FunctionParameterDescription(file)), ("video", FunctionParameterDescription(video)), ("videoStartTs", FunctionParameterDescription(videoStartTs)), ("videoEmojiMarkup", FunctionParameterDescription(videoEmojiMarkup))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.photos.Photo? in
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
        if Int(flags) & Int(1 << 5) != 0 {
            bot!.serialize(buffer, true)
        }
        if Int(flags) & Int(1 << 0) != 0 {
            file!.serialize(buffer, true)
        }
        if Int(flags) & Int(1 << 1) != 0 {
            video!.serialize(buffer, true)
        }
        if Int(flags) & Int(1 << 2) != 0 {
            serializeDouble(videoStartTs!, buffer: buffer, boxed: false)
        }
        if Int(flags) & Int(1 << 4) != 0 {
            videoEmojiMarkup!.serialize(buffer, true)
        }
        return (FunctionDescription(name: "photos.uploadProfilePhoto", parameters: [("flags", FunctionParameterDescription(flags)), ("bot", FunctionParameterDescription(bot)), ("file", FunctionParameterDescription(file)), ("video", FunctionParameterDescription(video)), ("videoStartTs", FunctionParameterDescription(videoStartTs)), ("videoEmojiMarkup", FunctionParameterDescription(videoEmojiMarkup))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.photos.Photo? in
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
        if Int(flags) & Int(1 << 0) != 0 {
            buffer.appendInt32(481674261)
            buffer.appendInt32(Int32(slots!.count))
            for item in slots! {
                serializeInt32(item, buffer: buffer, boxed: false)
            }
        }
        peer.serialize(buffer, true)
        return (FunctionDescription(name: "premium.applyBoost", parameters: [("flags", FunctionParameterDescription(flags)), ("slots", FunctionParameterDescription(slots)), ("peer", FunctionParameterDescription(peer))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.premium.MyBoosts? in
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
        return (FunctionDescription(name: "premium.getBoostsList", parameters: [("flags", FunctionParameterDescription(flags)), ("peer", FunctionParameterDescription(peer)), ("offset", FunctionParameterDescription(offset)), ("limit", FunctionParameterDescription(limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.premium.BoostsList? in
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
        return (FunctionDescription(name: "premium.getBoostsStatus", parameters: [("peer", FunctionParameterDescription(peer))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.premium.BoostsStatus? in
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
        return (FunctionDescription(name: "premium.getUserBoosts", parameters: [("peer", FunctionParameterDescription(peer)), ("userId", FunctionParameterDescription(userId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.premium.BoostsList? in
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
        if Int(flags) & Int(1 << 0) != 0 {
            serializeString(error!, buffer: buffer, boxed: false)
        }
        return (FunctionDescription(name: "smsjobs.finishJob", parameters: [("flags", FunctionParameterDescription(flags)), ("jobId", FunctionParameterDescription(jobId)), ("error", FunctionParameterDescription(error))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "smsjobs.getSmsJob", parameters: [("jobId", FunctionParameterDescription(jobId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.SmsJob? in
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
        return (FunctionDescription(name: "smsjobs.updateSettings", parameters: [("flags", FunctionParameterDescription(flags))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "stats.getBroadcastStats", parameters: [("flags", FunctionParameterDescription(flags)), ("channel", FunctionParameterDescription(channel))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.stats.BroadcastStats? in
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
        return (FunctionDescription(name: "stats.getMegagroupStats", parameters: [("flags", FunctionParameterDescription(flags)), ("channel", FunctionParameterDescription(channel))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.stats.MegagroupStats? in
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
        return (FunctionDescription(name: "stats.getMessagePublicForwards", parameters: [("channel", FunctionParameterDescription(channel)), ("msgId", FunctionParameterDescription(msgId)), ("offset", FunctionParameterDescription(offset)), ("limit", FunctionParameterDescription(limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.stats.PublicForwards? in
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
        return (FunctionDescription(name: "stats.getMessageStats", parameters: [("flags", FunctionParameterDescription(flags)), ("channel", FunctionParameterDescription(channel)), ("msgId", FunctionParameterDescription(msgId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.stats.MessageStats? in
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
        return (FunctionDescription(name: "stats.getStoryPublicForwards", parameters: [("peer", FunctionParameterDescription(peer)), ("id", FunctionParameterDescription(id)), ("offset", FunctionParameterDescription(offset)), ("limit", FunctionParameterDescription(limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.stats.PublicForwards? in
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
        return (FunctionDescription(name: "stats.getStoryStats", parameters: [("flags", FunctionParameterDescription(flags)), ("peer", FunctionParameterDescription(peer)), ("id", FunctionParameterDescription(id))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.stats.StoryStats? in
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
        if Int(flags) & Int(1 << 0) != 0 {
            serializeInt64(x!, buffer: buffer, boxed: false)
        }
        return (FunctionDescription(name: "stats.loadAsyncGraph", parameters: [("flags", FunctionParameterDescription(flags)), ("token", FunctionParameterDescription(token)), ("x", FunctionParameterDescription(x))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.StatsGraph? in
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
        return (FunctionDescription(name: "stickers.addStickerToSet", parameters: [("stickerset", FunctionParameterDescription(stickerset)), ("sticker", FunctionParameterDescription(sticker))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.StickerSet? in
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
        if Int(flags) & Int(1 << 0) != 0 {
            serializeString(emoji!, buffer: buffer, boxed: false)
        }
        if Int(flags) & Int(1 << 1) != 0 {
            maskCoords!.serialize(buffer, true)
        }
        if Int(flags) & Int(1 << 2) != 0 {
            serializeString(keywords!, buffer: buffer, boxed: false)
        }
        return (FunctionDescription(name: "stickers.changeSticker", parameters: [("flags", FunctionParameterDescription(flags)), ("sticker", FunctionParameterDescription(sticker)), ("emoji", FunctionParameterDescription(emoji)), ("maskCoords", FunctionParameterDescription(maskCoords)), ("keywords", FunctionParameterDescription(keywords))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.StickerSet? in
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
        return (FunctionDescription(name: "stickers.changeStickerPosition", parameters: [("sticker", FunctionParameterDescription(sticker)), ("position", FunctionParameterDescription(position))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.StickerSet? in
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
        return (FunctionDescription(name: "stickers.checkShortName", parameters: [("shortName", FunctionParameterDescription(shortName))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        if Int(flags) & Int(1 << 2) != 0 {
            thumb!.serialize(buffer, true)
        }
        buffer.appendInt32(481674261)
        buffer.appendInt32(Int32(stickers.count))
        for item in stickers {
            item.serialize(buffer, true)
        }
        if Int(flags) & Int(1 << 3) != 0 {
            serializeString(software!, buffer: buffer, boxed: false)
        }
        return (FunctionDescription(name: "stickers.createStickerSet", parameters: [("flags", FunctionParameterDescription(flags)), ("userId", FunctionParameterDescription(userId)), ("title", FunctionParameterDescription(title)), ("shortName", FunctionParameterDescription(shortName)), ("thumb", FunctionParameterDescription(thumb)), ("stickers", FunctionParameterDescription(stickers)), ("software", FunctionParameterDescription(software))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.StickerSet? in
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
        return (FunctionDescription(name: "stickers.deleteStickerSet", parameters: [("stickerset", FunctionParameterDescription(stickerset))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "stickers.removeStickerFromSet", parameters: [("sticker", FunctionParameterDescription(sticker))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.StickerSet? in
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
        return (FunctionDescription(name: "stickers.renameStickerSet", parameters: [("stickerset", FunctionParameterDescription(stickerset)), ("title", FunctionParameterDescription(title))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.StickerSet? in
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
        return (FunctionDescription(name: "stickers.replaceSticker", parameters: [("sticker", FunctionParameterDescription(sticker)), ("newSticker", FunctionParameterDescription(newSticker))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.StickerSet? in
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
        if Int(flags) & Int(1 << 0) != 0 {
            thumb!.serialize(buffer, true)
        }
        if Int(flags) & Int(1 << 1) != 0 {
            serializeInt64(thumbDocumentId!, buffer: buffer, boxed: false)
        }
        return (FunctionDescription(name: "stickers.setStickerSetThumb", parameters: [("flags", FunctionParameterDescription(flags)), ("stickerset", FunctionParameterDescription(stickerset)), ("thumb", FunctionParameterDescription(thumb)), ("thumbDocumentId", FunctionParameterDescription(thumbDocumentId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.messages.StickerSet? in
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
        return (FunctionDescription(name: "stickers.suggestShortName", parameters: [("title", FunctionParameterDescription(title))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.stickers.SuggestedShortName? in
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
        return (FunctionDescription(name: "stories.activateStealthMode", parameters: [("flags", FunctionParameterDescription(flags))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        return (FunctionDescription(name: "stories.canSendStory", parameters: [("peer", FunctionParameterDescription(peer))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.stories.CanSendStoryCount? in
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
    static func createAlbum(peer: Api.InputPeer, title: String, stories: [Int32]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.StoryAlbum>) {
        let buffer = Buffer()
        buffer.appendInt32(-1553754395)
        peer.serialize(buffer, true)
        serializeString(title, buffer: buffer, boxed: false)
        buffer.appendInt32(481674261)
        buffer.appendInt32(Int32(stories.count))
        for item in stories {
            serializeInt32(item, buffer: buffer, boxed: false)
        }
        return (FunctionDescription(name: "stories.createAlbum", parameters: [("peer", FunctionParameterDescription(peer)), ("title", FunctionParameterDescription(title)), ("stories", FunctionParameterDescription(stories))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.StoryAlbum? in
            let reader = BufferReader(buffer)
            var result: Api.StoryAlbum?
            if let signature = reader.readInt32() {
                result = Api.parse(reader, signature: signature) as? Api.StoryAlbum
            }
            return result
        })
    }
}
public extension Api.functions.stories {
    static func deleteAlbum(peer: Api.InputPeer, albumId: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let buffer = Buffer()
        buffer.appendInt32(-1925949744)
        peer.serialize(buffer, true)
        serializeInt32(albumId, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "stories.deleteAlbum", parameters: [("peer", FunctionParameterDescription(peer)), ("albumId", FunctionParameterDescription(albumId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
    static func deleteStories(peer: Api.InputPeer, id: [Int32]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Int32]>) {
        let buffer = Buffer()
        buffer.appendInt32(-1369842849)
        peer.serialize(buffer, true)
        buffer.appendInt32(481674261)
        buffer.appendInt32(Int32(id.count))
        for item in id {
            serializeInt32(item, buffer: buffer, boxed: false)
        }
        return (FunctionDescription(name: "stories.deleteStories", parameters: [("peer", FunctionParameterDescription(peer)), ("id", FunctionParameterDescription(id))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> [Int32]? in
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
        if Int(flags) & Int(1 << 0) != 0 {
            media!.serialize(buffer, true)
        }
        if Int(flags) & Int(1 << 3) != 0 {
            buffer.appendInt32(481674261)
            buffer.appendInt32(Int32(mediaAreas!.count))
            for item in mediaAreas! {
                item.serialize(buffer, true)
            }
        }
        if Int(flags) & Int(1 << 1) != 0 {
            serializeString(caption!, buffer: buffer, boxed: false)
        }
        if Int(flags) & Int(1 << 1) != 0 {
            buffer.appendInt32(481674261)
            buffer.appendInt32(Int32(entities!.count))
            for item in entities! {
                item.serialize(buffer, true)
            }
        }
        if Int(flags) & Int(1 << 2) != 0 {
            buffer.appendInt32(481674261)
            buffer.appendInt32(Int32(privacyRules!.count))
            for item in privacyRules! {
                item.serialize(buffer, true)
            }
        }
        return (FunctionDescription(name: "stories.editStory", parameters: [("flags", FunctionParameterDescription(flags)), ("peer", FunctionParameterDescription(peer)), ("id", FunctionParameterDescription(id)), ("media", FunctionParameterDescription(media)), ("mediaAreas", FunctionParameterDescription(mediaAreas)), ("caption", FunctionParameterDescription(caption)), ("entities", FunctionParameterDescription(entities)), ("privacyRules", FunctionParameterDescription(privacyRules))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        return (FunctionDescription(name: "stories.exportStoryLink", parameters: [("peer", FunctionParameterDescription(peer)), ("id", FunctionParameterDescription(id))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.ExportedStoryLink? in
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
    static func getAlbumStories(peer: Api.InputPeer, albumId: Int32, offset: Int32, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.stories.Stories>) {
        let buffer = Buffer()
        buffer.appendInt32(-1400869535)
        peer.serialize(buffer, true)
        serializeInt32(albumId, buffer: buffer, boxed: false)
        serializeInt32(offset, buffer: buffer, boxed: false)
        serializeInt32(limit, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "stories.getAlbumStories", parameters: [("peer", FunctionParameterDescription(peer)), ("albumId", FunctionParameterDescription(albumId)), ("offset", FunctionParameterDescription(offset)), ("limit", FunctionParameterDescription(limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.stories.Stories? in
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
    static func getAlbums(peer: Api.InputPeer, hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.stories.Albums>) {
        let buffer = Buffer()
        buffer.appendInt32(632548039)
        peer.serialize(buffer, true)
        serializeInt64(hash, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "stories.getAlbums", parameters: [("peer", FunctionParameterDescription(peer)), ("hash", FunctionParameterDescription(hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.stories.Albums? in
            let reader = BufferReader(buffer)
            var result: Api.stories.Albums?
            if let signature = reader.readInt32() {
                result = Api.parse(reader, signature: signature) as? Api.stories.Albums
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
        if Int(flags) & Int(1 << 0) != 0 {
            serializeString(state!, buffer: buffer, boxed: false)
        }
        return (FunctionDescription(name: "stories.getAllStories", parameters: [("flags", FunctionParameterDescription(flags)), ("state", FunctionParameterDescription(state))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.stories.AllStories? in
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
    static func getPeerMaxIDs(id: [Api.InputPeer]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Api.RecentStory]>) {
        let buffer = Buffer()
        buffer.appendInt32(2018087280)
        buffer.appendInt32(481674261)
        buffer.appendInt32(Int32(id.count))
        for item in id {
            item.serialize(buffer, true)
        }
        return (FunctionDescription(name: "stories.getPeerMaxIDs", parameters: [("id", FunctionParameterDescription(id))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> [Api.RecentStory]? in
            let reader = BufferReader(buffer)
            var result: [Api.RecentStory]?
            if let _ = reader.readInt32() {
                result = Api.parseVector(reader, elementSignature: 0, elementType: Api.RecentStory.self)
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
        return (FunctionDescription(name: "stories.getPeerStories", parameters: [("peer", FunctionParameterDescription(peer))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.stories.PeerStories? in
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
        return (FunctionDescription(name: "stories.getPinnedStories", parameters: [("peer", FunctionParameterDescription(peer)), ("offsetId", FunctionParameterDescription(offsetId)), ("limit", FunctionParameterDescription(limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.stories.Stories? in
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
        return (FunctionDescription(name: "stories.getStoriesArchive", parameters: [("peer", FunctionParameterDescription(peer)), ("offsetId", FunctionParameterDescription(offsetId)), ("limit", FunctionParameterDescription(limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.stories.Stories? in
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
        return (FunctionDescription(name: "stories.getStoriesByID", parameters: [("peer", FunctionParameterDescription(peer)), ("id", FunctionParameterDescription(id))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.stories.Stories? in
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
        return (FunctionDescription(name: "stories.getStoriesViews", parameters: [("peer", FunctionParameterDescription(peer)), ("id", FunctionParameterDescription(id))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.stories.StoryViews? in
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
        if Int(flags) & Int(1 << 0) != 0 {
            reaction!.serialize(buffer, true)
        }
        if Int(flags) & Int(1 << 1) != 0 {
            serializeString(offset!, buffer: buffer, boxed: false)
        }
        serializeInt32(limit, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "stories.getStoryReactionsList", parameters: [("flags", FunctionParameterDescription(flags)), ("peer", FunctionParameterDescription(peer)), ("id", FunctionParameterDescription(id)), ("reaction", FunctionParameterDescription(reaction)), ("offset", FunctionParameterDescription(offset)), ("limit", FunctionParameterDescription(limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.stories.StoryReactionsList? in
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
        if Int(flags) & Int(1 << 1) != 0 {
            serializeString(q!, buffer: buffer, boxed: false)
        }
        serializeInt32(id, buffer: buffer, boxed: false)
        serializeString(offset, buffer: buffer, boxed: false)
        serializeInt32(limit, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "stories.getStoryViewsList", parameters: [("flags", FunctionParameterDescription(flags)), ("peer", FunctionParameterDescription(peer)), ("q", FunctionParameterDescription(q)), ("id", FunctionParameterDescription(id)), ("offset", FunctionParameterDescription(offset)), ("limit", FunctionParameterDescription(limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.stories.StoryViewsList? in
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
        return (FunctionDescription(name: "stories.incrementStoryViews", parameters: [("peer", FunctionParameterDescription(peer)), ("id", FunctionParameterDescription(id))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "stories.readStories", parameters: [("peer", FunctionParameterDescription(peer)), ("maxId", FunctionParameterDescription(maxId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> [Int32]? in
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
    static func reorderAlbums(peer: Api.InputPeer, order: [Int32]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let buffer = Buffer()
        buffer.appendInt32(-2060059687)
        peer.serialize(buffer, true)
        buffer.appendInt32(481674261)
        buffer.appendInt32(Int32(order.count))
        for item in order {
            serializeInt32(item, buffer: buffer, boxed: false)
        }
        return (FunctionDescription(name: "stories.reorderAlbums", parameters: [("peer", FunctionParameterDescription(peer)), ("order", FunctionParameterDescription(order))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "stories.report", parameters: [("peer", FunctionParameterDescription(peer)), ("id", FunctionParameterDescription(id)), ("option", FunctionParameterDescription(option)), ("message", FunctionParameterDescription(message))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.ReportResult? in
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
        if Int(flags) & Int(1 << 0) != 0 {
            serializeString(hashtag!, buffer: buffer, boxed: false)
        }
        if Int(flags) & Int(1 << 1) != 0 {
            area!.serialize(buffer, true)
        }
        if Int(flags) & Int(1 << 2) != 0 {
            peer!.serialize(buffer, true)
        }
        serializeString(offset, buffer: buffer, boxed: false)
        serializeInt32(limit, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "stories.searchPosts", parameters: [("flags", FunctionParameterDescription(flags)), ("hashtag", FunctionParameterDescription(hashtag)), ("area", FunctionParameterDescription(area)), ("peer", FunctionParameterDescription(peer)), ("offset", FunctionParameterDescription(offset)), ("limit", FunctionParameterDescription(limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.stories.FoundStories? in
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
        return (FunctionDescription(name: "stories.sendReaction", parameters: [("flags", FunctionParameterDescription(flags)), ("peer", FunctionParameterDescription(peer)), ("storyId", FunctionParameterDescription(storyId)), ("reaction", FunctionParameterDescription(reaction))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
    static func sendStory(flags: Int32, peer: Api.InputPeer, media: Api.InputMedia, mediaAreas: [Api.MediaArea]?, caption: String?, entities: [Api.MessageEntity]?, privacyRules: [Api.InputPrivacyRule], randomId: Int64, period: Int32?, fwdFromId: Api.InputPeer?, fwdFromStory: Int32?, albums: [Int32]?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let buffer = Buffer()
        buffer.appendInt32(1937752812)
        serializeInt32(flags, buffer: buffer, boxed: false)
        peer.serialize(buffer, true)
        media.serialize(buffer, true)
        if Int(flags) & Int(1 << 5) != 0 {
            buffer.appendInt32(481674261)
            buffer.appendInt32(Int32(mediaAreas!.count))
            for item in mediaAreas! {
                item.serialize(buffer, true)
            }
        }
        if Int(flags) & Int(1 << 0) != 0 {
            serializeString(caption!, buffer: buffer, boxed: false)
        }
        if Int(flags) & Int(1 << 1) != 0 {
            buffer.appendInt32(481674261)
            buffer.appendInt32(Int32(entities!.count))
            for item in entities! {
                item.serialize(buffer, true)
            }
        }
        buffer.appendInt32(481674261)
        buffer.appendInt32(Int32(privacyRules.count))
        for item in privacyRules {
            item.serialize(buffer, true)
        }
        serializeInt64(randomId, buffer: buffer, boxed: false)
        if Int(flags) & Int(1 << 3) != 0 {
            serializeInt32(period!, buffer: buffer, boxed: false)
        }
        if Int(flags) & Int(1 << 6) != 0 {
            fwdFromId!.serialize(buffer, true)
        }
        if Int(flags) & Int(1 << 6) != 0 {
            serializeInt32(fwdFromStory!, buffer: buffer, boxed: false)
        }
        if Int(flags) & Int(1 << 8) != 0 {
            buffer.appendInt32(481674261)
            buffer.appendInt32(Int32(albums!.count))
            for item in albums! {
                serializeInt32(item, buffer: buffer, boxed: false)
            }
        }
        return (FunctionDescription(name: "stories.sendStory", parameters: [("flags", FunctionParameterDescription(flags)), ("peer", FunctionParameterDescription(peer)), ("media", FunctionParameterDescription(media)), ("mediaAreas", FunctionParameterDescription(mediaAreas)), ("caption", FunctionParameterDescription(caption)), ("entities", FunctionParameterDescription(entities)), ("privacyRules", FunctionParameterDescription(privacyRules)), ("randomId", FunctionParameterDescription(randomId)), ("period", FunctionParameterDescription(period)), ("fwdFromId", FunctionParameterDescription(fwdFromId)), ("fwdFromStory", FunctionParameterDescription(fwdFromStory)), ("albums", FunctionParameterDescription(albums))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
    static func startLive(flags: Int32, peer: Api.InputPeer, caption: String?, entities: [Api.MessageEntity]?, privacyRules: [Api.InputPrivacyRule], randomId: Int64, messagesEnabled: Api.Bool?, sendPaidMessagesStars: Int64?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let buffer = Buffer()
        buffer.appendInt32(-798372642)
        serializeInt32(flags, buffer: buffer, boxed: false)
        peer.serialize(buffer, true)
        if Int(flags) & Int(1 << 0) != 0 {
            serializeString(caption!, buffer: buffer, boxed: false)
        }
        if Int(flags) & Int(1 << 1) != 0 {
            buffer.appendInt32(481674261)
            buffer.appendInt32(Int32(entities!.count))
            for item in entities! {
                item.serialize(buffer, true)
            }
        }
        buffer.appendInt32(481674261)
        buffer.appendInt32(Int32(privacyRules.count))
        for item in privacyRules {
            item.serialize(buffer, true)
        }
        serializeInt64(randomId, buffer: buffer, boxed: false)
        if Int(flags) & Int(1 << 6) != 0 {
            messagesEnabled!.serialize(buffer, true)
        }
        if Int(flags) & Int(1 << 7) != 0 {
            serializeInt64(sendPaidMessagesStars!, buffer: buffer, boxed: false)
        }
        return (FunctionDescription(name: "stories.startLive", parameters: [("flags", FunctionParameterDescription(flags)), ("peer", FunctionParameterDescription(peer)), ("caption", FunctionParameterDescription(caption)), ("entities", FunctionParameterDescription(entities)), ("privacyRules", FunctionParameterDescription(privacyRules)), ("randomId", FunctionParameterDescription(randomId)), ("messagesEnabled", FunctionParameterDescription(messagesEnabled)), ("sendPaidMessagesStars", FunctionParameterDescription(sendPaidMessagesStars))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
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
        return (FunctionDescription(name: "stories.toggleAllStoriesHidden", parameters: [("hidden", FunctionParameterDescription(hidden))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "stories.togglePeerStoriesHidden", parameters: [("peer", FunctionParameterDescription(peer)), ("hidden", FunctionParameterDescription(hidden))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "stories.togglePinned", parameters: [("peer", FunctionParameterDescription(peer)), ("id", FunctionParameterDescription(id)), ("pinned", FunctionParameterDescription(pinned))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> [Int32]? in
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
        return (FunctionDescription(name: "stories.togglePinnedToTop", parameters: [("peer", FunctionParameterDescription(peer)), ("id", FunctionParameterDescription(id))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
    static func updateAlbum(flags: Int32, peer: Api.InputPeer, albumId: Int32, title: String?, deleteStories: [Int32]?, addStories: [Int32]?, order: [Int32]?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.StoryAlbum>) {
        let buffer = Buffer()
        buffer.appendInt32(1582455222)
        serializeInt32(flags, buffer: buffer, boxed: false)
        peer.serialize(buffer, true)
        serializeInt32(albumId, buffer: buffer, boxed: false)
        if Int(flags) & Int(1 << 0) != 0 {
            serializeString(title!, buffer: buffer, boxed: false)
        }
        if Int(flags) & Int(1 << 1) != 0 {
            buffer.appendInt32(481674261)
            buffer.appendInt32(Int32(deleteStories!.count))
            for item in deleteStories! {
                serializeInt32(item, buffer: buffer, boxed: false)
            }
        }
        if Int(flags) & Int(1 << 2) != 0 {
            buffer.appendInt32(481674261)
            buffer.appendInt32(Int32(addStories!.count))
            for item in addStories! {
                serializeInt32(item, buffer: buffer, boxed: false)
            }
        }
        if Int(flags) & Int(1 << 3) != 0 {
            buffer.appendInt32(481674261)
            buffer.appendInt32(Int32(order!.count))
            for item in order! {
                serializeInt32(item, buffer: buffer, boxed: false)
            }
        }
        return (FunctionDescription(name: "stories.updateAlbum", parameters: [("flags", FunctionParameterDescription(flags)), ("peer", FunctionParameterDescription(peer)), ("albumId", FunctionParameterDescription(albumId)), ("title", FunctionParameterDescription(title)), ("deleteStories", FunctionParameterDescription(deleteStories)), ("addStories", FunctionParameterDescription(addStories)), ("order", FunctionParameterDescription(order))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.StoryAlbum? in
            let reader = BufferReader(buffer)
            var result: Api.StoryAlbum?
            if let signature = reader.readInt32() {
                result = Api.parse(reader, signature: signature) as? Api.StoryAlbum
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
        return (FunctionDescription(name: "updates.getChannelDifference", parameters: [("flags", FunctionParameterDescription(flags)), ("channel", FunctionParameterDescription(channel)), ("filter", FunctionParameterDescription(filter)), ("pts", FunctionParameterDescription(pts)), ("limit", FunctionParameterDescription(limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.updates.ChannelDifference? in
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
        if Int(flags) & Int(1 << 1) != 0 {
            serializeInt32(ptsLimit!, buffer: buffer, boxed: false)
        }
        if Int(flags) & Int(1 << 0) != 0 {
            serializeInt32(ptsTotalLimit!, buffer: buffer, boxed: false)
        }
        serializeInt32(date, buffer: buffer, boxed: false)
        serializeInt32(qts, buffer: buffer, boxed: false)
        if Int(flags) & Int(1 << 2) != 0 {
            serializeInt32(qtsLimit!, buffer: buffer, boxed: false)
        }
        return (FunctionDescription(name: "updates.getDifference", parameters: [("flags", FunctionParameterDescription(flags)), ("pts", FunctionParameterDescription(pts)), ("ptsLimit", FunctionParameterDescription(ptsLimit)), ("ptsTotalLimit", FunctionParameterDescription(ptsTotalLimit)), ("date", FunctionParameterDescription(date)), ("qts", FunctionParameterDescription(qts)), ("qtsLimit", FunctionParameterDescription(qtsLimit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.updates.Difference? in
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
        return (FunctionDescription(name: "upload.getCdnFile", parameters: [("fileToken", FunctionParameterDescription(fileToken)), ("offset", FunctionParameterDescription(offset)), ("limit", FunctionParameterDescription(limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.upload.CdnFile? in
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
        return (FunctionDescription(name: "upload.getCdnFileHashes", parameters: [("fileToken", FunctionParameterDescription(fileToken)), ("offset", FunctionParameterDescription(offset))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> [Api.FileHash]? in
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
        return (FunctionDescription(name: "upload.getFile", parameters: [("flags", FunctionParameterDescription(flags)), ("location", FunctionParameterDescription(location)), ("offset", FunctionParameterDescription(offset)), ("limit", FunctionParameterDescription(limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.upload.File? in
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
        return (FunctionDescription(name: "upload.getFileHashes", parameters: [("location", FunctionParameterDescription(location)), ("offset", FunctionParameterDescription(offset))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> [Api.FileHash]? in
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
        return (FunctionDescription(name: "upload.getWebFile", parameters: [("location", FunctionParameterDescription(location)), ("offset", FunctionParameterDescription(offset)), ("limit", FunctionParameterDescription(limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.upload.WebFile? in
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
        return (FunctionDescription(name: "upload.reuploadCdnFile", parameters: [("fileToken", FunctionParameterDescription(fileToken)), ("requestToken", FunctionParameterDescription(requestToken))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> [Api.FileHash]? in
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
        return (FunctionDescription(name: "upload.saveBigFilePart", parameters: [("fileId", FunctionParameterDescription(fileId)), ("filePart", FunctionParameterDescription(filePart)), ("fileTotalParts", FunctionParameterDescription(fileTotalParts)), ("bytes", FunctionParameterDescription(bytes))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "upload.saveFilePart", parameters: [("fileId", FunctionParameterDescription(fileId)), ("filePart", FunctionParameterDescription(filePart)), ("bytes", FunctionParameterDescription(bytes))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
        return (FunctionDescription(name: "users.getFullUser", parameters: [("id", FunctionParameterDescription(id))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.users.UserFull? in
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
        return (FunctionDescription(name: "users.getRequirementsToContact", parameters: [("id", FunctionParameterDescription(id))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> [Api.RequirementToContact]? in
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
    static func getSavedMusic(id: Api.InputUser, offset: Int32, limit: Int32, hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.users.SavedMusic>) {
        let buffer = Buffer()
        buffer.appendInt32(2022539235)
        id.serialize(buffer, true)
        serializeInt32(offset, buffer: buffer, boxed: false)
        serializeInt32(limit, buffer: buffer, boxed: false)
        serializeInt64(hash, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "users.getSavedMusic", parameters: [("id", FunctionParameterDescription(id)), ("offset", FunctionParameterDescription(offset)), ("limit", FunctionParameterDescription(limit)), ("hash", FunctionParameterDescription(hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.users.SavedMusic? in
            let reader = BufferReader(buffer)
            var result: Api.users.SavedMusic?
            if let signature = reader.readInt32() {
                result = Api.parse(reader, signature: signature) as? Api.users.SavedMusic
            }
            return result
        })
    }
}
public extension Api.functions.users {
    static func getSavedMusicByID(id: Api.InputUser, documents: [Api.InputDocument]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.users.SavedMusic>) {
        let buffer = Buffer()
        buffer.appendInt32(1970513129)
        id.serialize(buffer, true)
        buffer.appendInt32(481674261)
        buffer.appendInt32(Int32(documents.count))
        for item in documents {
            item.serialize(buffer, true)
        }
        return (FunctionDescription(name: "users.getSavedMusicByID", parameters: [("id", FunctionParameterDescription(id)), ("documents", FunctionParameterDescription(documents))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.users.SavedMusic? in
            let reader = BufferReader(buffer)
            var result: Api.users.SavedMusic?
            if let signature = reader.readInt32() {
                result = Api.parse(reader, signature: signature) as? Api.users.SavedMusic
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
        return (FunctionDescription(name: "users.getUsers", parameters: [("id", FunctionParameterDescription(id))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> [Api.User]? in
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
        return (FunctionDescription(name: "users.setSecureValueErrors", parameters: [("id", FunctionParameterDescription(id)), ("errors", FunctionParameterDescription(errors))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
    static func suggestBirthday(id: Api.InputUser, birthday: Api.Birthday) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let buffer = Buffer()
        buffer.appendInt32(-61656206)
        id.serialize(buffer, true)
        birthday.serialize(buffer, true)
        return (FunctionDescription(name: "users.suggestBirthday", parameters: [("id", FunctionParameterDescription(id)), ("birthday", FunctionParameterDescription(birthday))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
            let reader = BufferReader(buffer)
            var result: Api.Updates?
            if let signature = reader.readInt32() {
                result = Api.parse(reader, signature: signature) as? Api.Updates
            }
            return result
        })
    }
}
