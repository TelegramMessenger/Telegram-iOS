import TelegramApiObjC
public extension Api.functions.account {
    static func acceptAuthorization(botId: Int64, scope: String, publicKey: String, valueHashes: [Api.SecureValueHash], credentials: Api.SecureCredentialsEncrypted) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(0))
        tlStore(_tlObject, 24, botId)
        tlStoreReference(_tlObject, 32, scope as NSString)
        tlStoreReference(_tlObject, 40, publicKey as NSString)
        tlStoreReference(_tlObject, 48, valueHashes.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 56, credentials.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func cancelPasswordEmail() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(1))
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func changeAuthorizationSettings(flags: Int32, hash: Int64, encryptedRequestsDisabled: Api.Bool?, callRequestsDisabled: Api.Bool?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(2))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 32, hash)
        tlStoreReference(_tlObject, 40, encryptedRequestsDisabled?.tlObject)
        tlStoreReference(_tlObject, 48, callRequestsDisabled?.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func changePhone(phoneNumber: String, phoneCodeHash: String, phoneCode: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.User>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(3))
        tlStoreReference(_tlObject, 24, phoneNumber as NSString)
        tlStoreReference(_tlObject, 32, phoneCodeHash as NSString)
        tlStoreReference(_tlObject, 40, phoneCode as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func checkUsername(username: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(4))
        tlStoreReference(_tlObject, 24, username as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func clearRecentEmojiStatuses() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(5))
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func confirmBotConnection(botId: Api.InputUser) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(6))
        tlStoreReference(_tlObject, 24, botId.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func confirmPasswordEmail(code: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(7))
        tlStoreReference(_tlObject, 24, code as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func confirmPhone(phoneCodeHash: String, phoneCode: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(8))
        tlStoreReference(_tlObject, 24, phoneCodeHash as NSString)
        tlStoreReference(_tlObject, 32, phoneCode as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func createBusinessChatLink(link: Api.InputBusinessChatLink) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.BusinessChatLink>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(9))
        tlStoreReference(_tlObject, 24, link.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func createTheme(flags: Int32, slug: String, title: String, document: Api.InputDocument?, settings: [Api.InputThemeSettings]?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Theme>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(10))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, slug as NSString)
        tlStoreReference(_tlObject, 40, title as NSString)
        tlStoreReference(_tlObject, 48, document?.tlObject)
        tlStoreReference(_tlObject, 56, settings.map { value in value.map { item in item.tlObject } as NSArray })
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func declinePasswordReset() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(11))
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func deleteAccount(flags: Int32, reason: String, password: Api.InputCheckPasswordSRP?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(12))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, reason as NSString)
        tlStoreReference(_tlObject, 40, password?.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func deleteAutoSaveExceptions() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(13))
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func deleteBusinessChatLink(slug: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(14))
        tlStoreReference(_tlObject, 24, slug as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func deletePasskey(id: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(15))
        tlStoreReference(_tlObject, 24, id as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func deleteSecureValue(types: [Api.SecureValueType]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(16))
        tlStoreReference(_tlObject, 24, types.map { item in item.tlObject } as NSArray)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func deleteWebBrowserSettingsExceptions() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.account.WebBrowserSettings>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(17))
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func disablePeerConnectedBot(peer: Api.InputPeer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(18))
        tlStoreReference(_tlObject, 24, peer.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func editBusinessChatLink(slug: String, link: Api.InputBusinessChatLink) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.BusinessChatLink>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(19))
        tlStoreReference(_tlObject, 24, slug as NSString)
        tlStoreReference(_tlObject, 32, link.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func finishTakeoutSession(flags: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(20))
        tlStore(_tlObject, 24, flags)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func getAccountTTL() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.AccountDaysTTL>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(21))
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func getAllSecureValues() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Api.SecureValue]>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(22))
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func getAuthorizationForm(botId: Int64, scope: String, publicKey: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.account.AuthorizationForm>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(23))
        tlStore(_tlObject, 24, botId)
        tlStoreReference(_tlObject, 32, scope as NSString)
        tlStoreReference(_tlObject, 40, publicKey as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func getAuthorizations() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.account.Authorizations>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(24))
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func getAutoDownloadSettings() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.account.AutoDownloadSettings>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(25))
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func getAutoSaveSettings() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.account.AutoSaveSettings>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(26))
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func getBotBusinessConnection(connectionId: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(27))
        tlStoreReference(_tlObject, 24, connectionId as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func getBusinessChatLinks() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.account.BusinessChatLinks>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(28))
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func getChannelDefaultEmojiStatuses(hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.account.EmojiStatuses>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(29))
        tlStore(_tlObject, 24, hash)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func getChannelRestrictedStatusEmojis(hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.EmojiList>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(30))
        tlStore(_tlObject, 24, hash)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func getChatThemes(hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.account.Themes>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(31))
        tlStore(_tlObject, 24, hash)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func getCollectibleEmojiStatuses(hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.account.EmojiStatuses>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(32))
        tlStore(_tlObject, 24, hash)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func getConnectedBots() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.account.ConnectedBots>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(33))
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func getContactSignUpNotification() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(34))
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func getContentSettings() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.account.ContentSettings>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(35))
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func getDefaultBackgroundEmojis(hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.EmojiList>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(36))
        tlStore(_tlObject, 24, hash)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func getDefaultEmojiStatuses(hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.account.EmojiStatuses>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(37))
        tlStore(_tlObject, 24, hash)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func getDefaultGroupPhotoEmojis(hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.EmojiList>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(38))
        tlStore(_tlObject, 24, hash)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func getDefaultProfilePhotoEmojis(hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.EmojiList>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(39))
        tlStore(_tlObject, 24, hash)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func getGlobalPrivacySettings() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.GlobalPrivacySettings>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(40))
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func getMultiWallPapers(wallpapers: [Api.InputWallPaper]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Api.WallPaper]>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(41))
        tlStoreReference(_tlObject, 24, wallpapers.map { item in item.tlObject } as NSArray)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func getNotifyExceptions(flags: Int32, peer: Api.InputNotifyPeer?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(42))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, peer?.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func getNotifySettings(peer: Api.InputNotifyPeer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.PeerNotifySettings>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(43))
        tlStoreReference(_tlObject, 24, peer.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func getPaidMessagesRevenue(flags: Int32, parentPeer: Api.InputPeer?, userId: Api.InputUser) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.account.PaidMessagesRevenue>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(44))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, parentPeer?.tlObject)
        tlStoreReference(_tlObject, 40, userId.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func getPasskeys() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.account.Passkeys>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(45))
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func getPassword() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.account.Password>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(46))
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func getPasswordSettings(password: Api.InputCheckPasswordSRP) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.account.PasswordSettings>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(47))
        tlStoreReference(_tlObject, 24, password.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func getPrivacy(key: Api.InputPrivacyKey) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.account.PrivacyRules>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(48))
        tlStoreReference(_tlObject, 24, key.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func getReactionsNotifySettings() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.ReactionsNotifySettings>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(49))
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func getRecentEmojiStatuses(hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.account.EmojiStatuses>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(50))
        tlStore(_tlObject, 24, hash)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func getSavedMusicIds(hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.account.SavedMusicIds>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(51))
        tlStore(_tlObject, 24, hash)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func getSavedRingtones(hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.account.SavedRingtones>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(52))
        tlStore(_tlObject, 24, hash)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func getSecureValue(types: [Api.SecureValueType]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Api.SecureValue]>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(53))
        tlStoreReference(_tlObject, 24, types.map { item in item.tlObject } as NSArray)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func getTheme(format: String, theme: Api.InputTheme) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Theme>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(54))
        tlStoreReference(_tlObject, 24, format as NSString)
        tlStoreReference(_tlObject, 32, theme.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func getThemes(format: String, hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.account.Themes>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(55))
        tlStoreReference(_tlObject, 24, format as NSString)
        tlStore(_tlObject, 32, hash)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func getTmpPassword(password: Api.InputCheckPasswordSRP, period: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.account.TmpPassword>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(56))
        tlStoreReference(_tlObject, 32, password.tlObject)
        tlStore(_tlObject, 24, period)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func getUniqueGiftChatThemes(offset: String, limit: Int32, hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.account.ChatThemes>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(57))
        tlStoreReference(_tlObject, 32, offset as NSString)
        tlStore(_tlObject, 24, limit)
        tlStore(_tlObject, 40, hash)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func getWallPaper(wallpaper: Api.InputWallPaper) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.WallPaper>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(58))
        tlStoreReference(_tlObject, 24, wallpaper.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func getWallPapers(hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.account.WallPapers>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(59))
        tlStore(_tlObject, 24, hash)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func getWebAuthorizations() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.account.WebAuthorizations>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(60))
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func getWebBrowserSettings(hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.account.WebBrowserSettings>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(61))
        tlStore(_tlObject, 24, hash)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func initPasskeyRegistration() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.account.PasskeyRegistrationOptions>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(62))
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func initTakeoutSession(flags: Int32, fileMaxSize: Int64?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.account.Takeout>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(63))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        if let _tlValue = fileMaxSize { tlStore(_tlObject, 32, _tlValue); _tlPresent |= 1 << 0 }
        tlStore(_tlObject, 40, _tlPresent)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func installTheme(flags: Int32, theme: Api.InputTheme?, format: String?, baseTheme: Api.BaseTheme?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(64))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, theme?.tlObject)
        tlStoreReference(_tlObject, 40, format.map { value in value as NSString })
        tlStoreReference(_tlObject, 48, baseTheme?.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func installWallPaper(wallpaper: Api.InputWallPaper, settings: Api.WallPaperSettings) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(65))
        tlStoreReference(_tlObject, 24, wallpaper.tlObject)
        tlStoreReference(_tlObject, 32, settings.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func invalidateSignInCodes(codes: [String]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(66))
        tlStoreReference(_tlObject, 24, codes as NSArray)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func registerDevice(flags: Int32, tokenType: Int32, token: String, appSandbox: Api.Bool, secret: Buffer, otherUids: [Int64]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(67))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 28, tokenType)
        tlStoreReference(_tlObject, 32, token as NSString)
        tlStoreReference(_tlObject, 40, appSandbox.tlObject)
        tlStoreReference(_tlObject, 48, secret.makeData() as NSData)
        tlStoreReference(_tlObject, 56, tlPackInt64(otherUids) as NSData)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func registerPasskey(credential: Api.InputPasskeyCredential) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Passkey>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(68))
        tlStoreReference(_tlObject, 24, credential.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func reorderUsernames(order: [String]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(69))
        tlStoreReference(_tlObject, 24, order as NSArray)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func reportPeer(peer: Api.InputPeer, reason: Api.ReportReason, message: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(70))
        tlStoreReference(_tlObject, 24, peer.tlObject)
        tlStoreReference(_tlObject, 32, reason.tlObject)
        tlStoreReference(_tlObject, 40, message as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func reportProfilePhoto(peer: Api.InputPeer, photoId: Api.InputPhoto, reason: Api.ReportReason, message: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(71))
        tlStoreReference(_tlObject, 24, peer.tlObject)
        tlStoreReference(_tlObject, 32, photoId.tlObject)
        tlStoreReference(_tlObject, 40, reason.tlObject)
        tlStoreReference(_tlObject, 48, message as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func resendPasswordEmail() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(72))
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func resetAuthorization(hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(73))
        tlStore(_tlObject, 24, hash)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func resetNotifySettings() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(74))
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func resetPassword() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.account.ResetPasswordResult>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(75))
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func resetWallPapers() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(76))
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func resetWebAuthorization(hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(77))
        tlStore(_tlObject, 24, hash)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func resetWebAuthorizations() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(78))
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func resolveBusinessChatLink(slug: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.account.ResolvedBusinessChatLinks>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(79))
        tlStoreReference(_tlObject, 24, slug as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func saveAutoDownloadSettings(flags: Int32, settings: Api.AutoDownloadSettings) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(80))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, settings.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func saveAutoSaveSettings(flags: Int32, peer: Api.InputPeer?, settings: Api.AutoSaveSettings) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(81))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, peer?.tlObject)
        tlStoreReference(_tlObject, 40, settings.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func saveMusic(flags: Int32, id: Api.InputDocument, afterId: Api.InputDocument?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(82))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, id.tlObject)
        tlStoreReference(_tlObject, 40, afterId?.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func saveRingtone(id: Api.InputDocument, unsave: Api.Bool) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.account.SavedRingtone>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(83))
        tlStoreReference(_tlObject, 24, id.tlObject)
        tlStoreReference(_tlObject, 32, unsave.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func saveSecureValue(value: Api.InputSecureValue, secureSecretId: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.SecureValue>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(84))
        tlStoreReference(_tlObject, 24, value.tlObject)
        tlStore(_tlObject, 32, secureSecretId)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func saveTheme(theme: Api.InputTheme, unsave: Api.Bool) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(85))
        tlStoreReference(_tlObject, 24, theme.tlObject)
        tlStoreReference(_tlObject, 32, unsave.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func saveWallPaper(wallpaper: Api.InputWallPaper, unsave: Api.Bool, settings: Api.WallPaperSettings) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(86))
        tlStoreReference(_tlObject, 24, wallpaper.tlObject)
        tlStoreReference(_tlObject, 32, unsave.tlObject)
        tlStoreReference(_tlObject, 40, settings.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func sendChangePhoneCode(phoneNumber: String, settings: Api.CodeSettings) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.auth.SentCode>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(87))
        tlStoreReference(_tlObject, 24, phoneNumber as NSString)
        tlStoreReference(_tlObject, 32, settings.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func sendConfirmPhoneCode(hash: String, settings: Api.CodeSettings) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.auth.SentCode>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(88))
        tlStoreReference(_tlObject, 24, hash as NSString)
        tlStoreReference(_tlObject, 32, settings.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func sendVerifyEmailCode(purpose: Api.EmailVerifyPurpose, email: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.account.SentEmailCode>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(89))
        tlStoreReference(_tlObject, 24, purpose.tlObject)
        tlStoreReference(_tlObject, 32, email as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func sendVerifyPhoneCode(phoneNumber: String, settings: Api.CodeSettings) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.auth.SentCode>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(90))
        tlStoreReference(_tlObject, 24, phoneNumber as NSString)
        tlStoreReference(_tlObject, 32, settings.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func setAccountTTL(ttl: Api.AccountDaysTTL) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(91))
        tlStoreReference(_tlObject, 24, ttl.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func setAuthorizationTTL(authorizationTtlDays: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(92))
        tlStore(_tlObject, 24, authorizationTtlDays)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func setContactSignUpNotification(silent: Api.Bool) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(93))
        tlStoreReference(_tlObject, 24, silent.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func setContentSettings(flags: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(94))
        tlStore(_tlObject, 24, flags)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func setGlobalPrivacySettings(settings: Api.GlobalPrivacySettings) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.GlobalPrivacySettings>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(95))
        tlStoreReference(_tlObject, 24, settings.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func setMainProfileTab(tab: Api.ProfileTab) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(96))
        tlStoreReference(_tlObject, 24, tab.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func setPrivacy(key: Api.InputPrivacyKey, rules: [Api.InputPrivacyRule]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.account.PrivacyRules>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(97))
        tlStoreReference(_tlObject, 24, key.tlObject)
        tlStoreReference(_tlObject, 32, rules.map { item in item.tlObject } as NSArray)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func setReactionsNotifySettings(settings: Api.ReactionsNotifySettings) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.ReactionsNotifySettings>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(98))
        tlStoreReference(_tlObject, 24, settings.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func toggleConnectedBotPaused(peer: Api.InputPeer, paused: Api.Bool) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(99))
        tlStoreReference(_tlObject, 24, peer.tlObject)
        tlStoreReference(_tlObject, 32, paused.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func toggleNoPaidMessagesException(flags: Int32, parentPeer: Api.InputPeer?, userId: Api.InputUser) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(100))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, parentPeer?.tlObject)
        tlStoreReference(_tlObject, 40, userId.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func toggleSponsoredMessages(enabled: Api.Bool) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(101))
        tlStoreReference(_tlObject, 24, enabled.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func toggleUsername(username: String, active: Api.Bool) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(102))
        tlStoreReference(_tlObject, 24, username as NSString)
        tlStoreReference(_tlObject, 32, active.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func toggleWebBrowserSettingsException(flags: Int32, openExternalBrowser: Api.Bool?, url: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(103))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, openExternalBrowser?.tlObject)
        tlStoreReference(_tlObject, 40, url as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func unregisterDevice(tokenType: Int32, token: String, otherUids: [Int64]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(104))
        tlStore(_tlObject, 24, tokenType)
        tlStoreReference(_tlObject, 32, token as NSString)
        tlStoreReference(_tlObject, 40, tlPackInt64(otherUids) as NSData)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func updateBirthday(flags: Int32, birthday: Api.Birthday?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(105))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, birthday?.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func updateBusinessAwayMessage(flags: Int32, message: Api.InputBusinessAwayMessage?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(106))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, message?.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func updateBusinessGreetingMessage(flags: Int32, message: Api.InputBusinessGreetingMessage?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(107))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, message?.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func updateBusinessIntro(flags: Int32, intro: Api.InputBusinessIntro?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(108))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, intro?.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func updateBusinessLocation(flags: Int32, geoPoint: Api.InputGeoPoint?, address: String?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(109))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, geoPoint?.tlObject)
        tlStoreReference(_tlObject, 40, address.map { value in value as NSString })
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func updateBusinessWorkHours(flags: Int32, businessWorkHours: Api.BusinessWorkHours?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(110))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, businessWorkHours?.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func updateColor(flags: Int32, color: Api.PeerColor?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(111))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, color?.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func updateConnectedBot(flags: Int32, rights: Api.BusinessBotRights?, bot: Api.InputUser, recipients: Api.InputBusinessBotRecipients) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(112))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, rights?.tlObject)
        tlStoreReference(_tlObject, 40, bot.tlObject)
        tlStoreReference(_tlObject, 48, recipients.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func updateDeviceLocked(period: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(113))
        tlStore(_tlObject, 24, period)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func updateEmojiStatus(emojiStatus: Api.EmojiStatus) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(114))
        tlStoreReference(_tlObject, 24, emojiStatus.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func updateNotifySettings(peer: Api.InputNotifyPeer, settings: Api.InputPeerNotifySettings) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(115))
        tlStoreReference(_tlObject, 24, peer.tlObject)
        tlStoreReference(_tlObject, 32, settings.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func updatePasswordSettings(password: Api.InputCheckPasswordSRP, newSettings: Api.account.PasswordInputSettings) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(116))
        tlStoreReference(_tlObject, 24, password.tlObject)
        tlStoreReference(_tlObject, 32, newSettings.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func updatePersonalChannel(channel: Api.InputChannel) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(117))
        tlStoreReference(_tlObject, 24, channel.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func updateProfile(flags: Int32, firstName: String?, lastName: String?, about: String?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.User>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(118))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, firstName.map { value in value as NSString })
        tlStoreReference(_tlObject, 40, lastName.map { value in value as NSString })
        tlStoreReference(_tlObject, 48, about.map { value in value as NSString })
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func updateStatus(offline: Api.Bool) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(119))
        tlStoreReference(_tlObject, 24, offline.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func updateTheme(flags: Int32, format: String, theme: Api.InputTheme, slug: String?, title: String?, document: Api.InputDocument?, settings: [Api.InputThemeSettings]?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Theme>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(120))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, format as NSString)
        tlStoreReference(_tlObject, 40, theme.tlObject)
        tlStoreReference(_tlObject, 48, slug.map { value in value as NSString })
        tlStoreReference(_tlObject, 56, title.map { value in value as NSString })
        tlStoreReference(_tlObject, 64, document?.tlObject)
        tlStoreReference(_tlObject, 72, settings.map { value in value.map { item in item.tlObject } as NSArray })
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func updateUsername(username: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.User>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(121))
        tlStoreReference(_tlObject, 24, username as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func updateWebBrowserSettings(flags: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.account.WebBrowserSettings>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(122))
        tlStore(_tlObject, 24, flags)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func uploadRingtone(file: Api.InputFile, fileName: String, mimeType: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Document>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(123))
        tlStoreReference(_tlObject, 24, file.tlObject)
        tlStoreReference(_tlObject, 32, fileName as NSString)
        tlStoreReference(_tlObject, 40, mimeType as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func uploadTheme(flags: Int32, file: Api.InputFile, thumb: Api.InputFile?, fileName: String, mimeType: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Document>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(124))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, file.tlObject)
        tlStoreReference(_tlObject, 40, thumb?.tlObject)
        tlStoreReference(_tlObject, 48, fileName as NSString)
        tlStoreReference(_tlObject, 56, mimeType as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func uploadWallPaper(flags: Int32, file: Api.InputFile, mimeType: String, settings: Api.WallPaperSettings) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.WallPaper>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(125))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, file.tlObject)
        tlStoreReference(_tlObject, 40, mimeType as NSString)
        tlStoreReference(_tlObject, 48, settings.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func verifyEmail(purpose: Api.EmailVerifyPurpose, verification: Api.EmailVerification) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.account.EmailVerified>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(126))
        tlStoreReference(_tlObject, 24, purpose.tlObject)
        tlStoreReference(_tlObject, 32, verification.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.account {
    static func verifyPhone(phoneNumber: String, phoneCodeHash: String, phoneCode: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(127))
        tlStoreReference(_tlObject, 24, phoneNumber as NSString)
        tlStoreReference(_tlObject, 32, phoneCodeHash as NSString)
        tlStoreReference(_tlObject, 40, phoneCode as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.aicompose {
    static func createTone(flags: Int32, emojiId: Int64, title: String, prompt: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.AiComposeTone>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(128))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 32, emojiId)
        tlStoreReference(_tlObject, 40, title as NSString)
        tlStoreReference(_tlObject, 48, prompt as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.aicompose {
    static func deleteTone(tone: Api.InputAiComposeTone) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(129))
        tlStoreReference(_tlObject, 24, tone.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.aicompose {
    static func getTone(tone: Api.InputAiComposeTone) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.aicompose.Tones>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(130))
        tlStoreReference(_tlObject, 24, tone.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.aicompose {
    static func getToneExample(tone: Api.InputAiComposeTone, num: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.AiComposeToneExample>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(131))
        tlStoreReference(_tlObject, 32, tone.tlObject)
        tlStore(_tlObject, 24, num)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.aicompose {
    static func getTones(hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.aicompose.Tones>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(132))
        tlStore(_tlObject, 24, hash)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.aicompose {
    static func saveTone(tone: Api.InputAiComposeTone, unsave: Api.Bool) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(133))
        tlStoreReference(_tlObject, 24, tone.tlObject)
        tlStoreReference(_tlObject, 32, unsave.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.aicompose {
    static func updateTone(flags: Int32, tone: Api.InputAiComposeTone, displayAuthor: Api.Bool?, emojiId: Int64?, title: String?, prompt: String?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.AiComposeTone>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(134))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, tone.tlObject)
        tlStoreReference(_tlObject, 40, displayAuthor?.tlObject)
        if let _tlValue = emojiId { tlStore(_tlObject, 48, _tlValue); _tlPresent |= 1 << 0 }
        tlStoreReference(_tlObject, 56, title.map { value in value as NSString })
        tlStoreReference(_tlObject, 64, prompt.map { value in value as NSString })
        tlStore(_tlObject, 72, _tlPresent)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.auth {
    static func acceptLoginToken(token: Buffer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Authorization>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(135))
        tlStoreReference(_tlObject, 24, token.makeData() as NSData)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.auth {
    static func bindTempAuthKey(permAuthKeyId: Int64, nonce: Int64, expiresAt: Int32, encryptedMessage: Buffer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(136))
        tlStore(_tlObject, 32, permAuthKeyId)
        tlStore(_tlObject, 40, nonce)
        tlStore(_tlObject, 24, expiresAt)
        tlStoreReference(_tlObject, 48, encryptedMessage.makeData() as NSData)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.auth {
    static func cancelCode(phoneNumber: String, phoneCodeHash: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(137))
        tlStoreReference(_tlObject, 24, phoneNumber as NSString)
        tlStoreReference(_tlObject, 32, phoneCodeHash as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.auth {
    static func cancelWebTokenAuthorization(webAuthToken: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(138))
        tlStoreReference(_tlObject, 24, webAuthToken as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.auth {
    static func checkPaidAuth(phoneNumber: String, phoneCodeHash: String, formId: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.auth.SentCode>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(139))
        tlStoreReference(_tlObject, 24, phoneNumber as NSString)
        tlStoreReference(_tlObject, 32, phoneCodeHash as NSString)
        tlStore(_tlObject, 40, formId)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.auth {
    static func checkPassword(password: Api.InputCheckPasswordSRP) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.auth.Authorization>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(140))
        tlStoreReference(_tlObject, 24, password.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.auth {
    static func checkRecoveryPassword(code: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(141))
        tlStoreReference(_tlObject, 24, code as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.auth {
    static func dropTempAuthKeys(exceptAuthKeys: [Int64]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(142))
        tlStoreReference(_tlObject, 24, tlPackInt64(exceptAuthKeys) as NSData)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.auth {
    static func exportAuthorization(dcId: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.auth.ExportedAuthorization>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(143))
        tlStore(_tlObject, 24, dcId)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.auth {
    static func exportLoginToken(apiId: Int32, apiHash: String, exceptIds: [Int64]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.auth.LoginToken>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(144))
        tlStore(_tlObject, 24, apiId)
        tlStoreReference(_tlObject, 32, apiHash as NSString)
        tlStoreReference(_tlObject, 40, tlPackInt64(exceptIds) as NSData)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.auth {
    static func finishFirebasePnvLogin(googleToken: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.auth.Authorization>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(145))
        tlStoreReference(_tlObject, 24, googleToken as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.auth {
    static func finishPasskeyLogin(flags: Int32, credential: Api.InputPasskeyCredential, fromDcId: Int32?, fromAuthKeyId: Int64?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.auth.Authorization>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(146))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, credential.tlObject)
        if let _tlValue = fromDcId { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        if let _tlValue = fromAuthKeyId { tlStore(_tlObject, 40, _tlValue); _tlPresent |= 1 << 1 }
        tlStore(_tlObject, 48, _tlPresent)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.auth {
    static func firebasePnvSignUp(flags: Int32, firstName: String, lastName: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.auth.Authorization>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(147))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, firstName as NSString)
        tlStoreReference(_tlObject, 40, lastName as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.auth {
    static func importAuthorization(id: Int64, bytes: Buffer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.auth.Authorization>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(148))
        tlStore(_tlObject, 24, id)
        tlStoreReference(_tlObject, 32, bytes.makeData() as NSData)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.auth {
    static func importBotAuthorization(flags: Int32, apiId: Int32, apiHash: String, botAuthToken: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.auth.Authorization>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(149))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 28, apiId)
        tlStoreReference(_tlObject, 32, apiHash as NSString)
        tlStoreReference(_tlObject, 40, botAuthToken as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.auth {
    static func importLoginToken(token: Buffer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.auth.LoginToken>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(150))
        tlStoreReference(_tlObject, 24, token.makeData() as NSData)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.auth {
    static func importWebTokenAuthorization(apiId: Int32, apiHash: String, webAuthToken: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.auth.Authorization>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(151))
        tlStore(_tlObject, 24, apiId)
        tlStoreReference(_tlObject, 32, apiHash as NSString)
        tlStoreReference(_tlObject, 40, webAuthToken as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.auth {
    static func initFirebasePnvLogin(flags: Int32, exceptIds: [Int64]?, apiId: Int32, apiHash: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.auth.FirebasePnvIntent>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(152))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, exceptIds.map { value in tlPackInt64(value) as NSData })
        tlStore(_tlObject, 28, apiId)
        tlStoreReference(_tlObject, 40, apiHash as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.auth {
    static func initPasskeyLogin(apiId: Int32, apiHash: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.auth.PasskeyLoginOptions>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(153))
        tlStore(_tlObject, 24, apiId)
        tlStoreReference(_tlObject, 32, apiHash as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.auth {
    static func logOut() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.auth.LoggedOut>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(154))
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.auth {
    static func recoverPassword(flags: Int32, code: String, newSettings: Api.account.PasswordInputSettings?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.auth.Authorization>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(155))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, code as NSString)
        tlStoreReference(_tlObject, 40, newSettings?.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.auth {
    static func reportMissingCode(phoneNumber: String, phoneCodeHash: String, mnc: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(156))
        tlStoreReference(_tlObject, 24, phoneNumber as NSString)
        tlStoreReference(_tlObject, 32, phoneCodeHash as NSString)
        tlStoreReference(_tlObject, 40, mnc as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.auth {
    static func requestFirebaseSms(flags: Int32, phoneNumber: String, phoneCodeHash: String, safetyNetToken: String?, playIntegrityToken: String?, iosPushSecret: String?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(157))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, phoneNumber as NSString)
        tlStoreReference(_tlObject, 40, phoneCodeHash as NSString)
        tlStoreReference(_tlObject, 48, safetyNetToken.map { value in value as NSString })
        tlStoreReference(_tlObject, 56, playIntegrityToken.map { value in value as NSString })
        tlStoreReference(_tlObject, 64, iosPushSecret.map { value in value as NSString })
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.auth {
    static func requestPasswordRecovery() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.auth.PasswordRecovery>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(158))
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.auth {
    static func resendCode(flags: Int32, phoneNumber: String, phoneCodeHash: String, reason: String?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.auth.SentCode>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(159))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, phoneNumber as NSString)
        tlStoreReference(_tlObject, 40, phoneCodeHash as NSString)
        tlStoreReference(_tlObject, 48, reason.map { value in value as NSString })
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.auth {
    static func resetAuthorizations() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(160))
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.auth {
    static func resetLoginEmail(phoneNumber: String, phoneCodeHash: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.auth.SentCode>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(161))
        tlStoreReference(_tlObject, 24, phoneNumber as NSString)
        tlStoreReference(_tlObject, 32, phoneCodeHash as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.auth {
    static func sendCode(phoneNumber: String, apiId: Int32, apiHash: String, settings: Api.CodeSettings) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.auth.SentCode>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(162))
        tlStoreReference(_tlObject, 32, phoneNumber as NSString)
        tlStore(_tlObject, 24, apiId)
        tlStoreReference(_tlObject, 40, apiHash as NSString)
        tlStoreReference(_tlObject, 48, settings.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.auth {
    static func signIn(flags: Int32, phoneNumber: String, phoneCodeHash: String, phoneCode: String?, emailVerification: Api.EmailVerification?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.auth.Authorization>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(163))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, phoneNumber as NSString)
        tlStoreReference(_tlObject, 40, phoneCodeHash as NSString)
        tlStoreReference(_tlObject, 48, phoneCode.map { value in value as NSString })
        tlStoreReference(_tlObject, 56, emailVerification?.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.auth {
    static func signUp(flags: Int32, phoneNumber: String, phoneCodeHash: String, firstName: String, lastName: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.auth.Authorization>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(164))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, phoneNumber as NSString)
        tlStoreReference(_tlObject, 40, phoneCodeHash as NSString)
        tlStoreReference(_tlObject, 48, firstName as NSString)
        tlStoreReference(_tlObject, 56, lastName as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.bots {
    static func addPreviewMedia(bot: Api.InputUser, langCode: String, media: Api.InputMedia) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.BotPreviewMedia>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(165))
        tlStoreReference(_tlObject, 24, bot.tlObject)
        tlStoreReference(_tlObject, 32, langCode as NSString)
        tlStoreReference(_tlObject, 40, media.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.bots {
    static func addUsername(bot: Api.InputUser, username: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(166))
        tlStoreReference(_tlObject, 24, bot.tlObject)
        tlStoreReference(_tlObject, 32, username as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.bots {
    static func allowSendMessage(bot: Api.InputUser) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(167))
        tlStoreReference(_tlObject, 24, bot.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.bots {
    static func answerWebhookJSONQuery(queryId: Int64, data: Api.DataJSON) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(168))
        tlStore(_tlObject, 24, queryId)
        tlStoreReference(_tlObject, 32, data.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.bots {
    static func canSendMessage(bot: Api.InputUser) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(169))
        tlStoreReference(_tlObject, 24, bot.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.bots {
    static func checkDownloadFileParams(bot: Api.InputUser, fileName: String, url: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(170))
        tlStoreReference(_tlObject, 24, bot.tlObject)
        tlStoreReference(_tlObject, 32, fileName as NSString)
        tlStoreReference(_tlObject, 40, url as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.bots {
    static func checkUsername(flags: Int32, username: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(171))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, username as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.bots {
    static func createBot(flags: Int32, name: String, username: String, managerId: Api.InputUser) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.User>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(172))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, name as NSString)
        tlStoreReference(_tlObject, 40, username as NSString)
        tlStoreReference(_tlObject, 48, managerId.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.bots {
    static func deletePreviewMedia(bot: Api.InputUser, langCode: String, media: [Api.InputMedia]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(173))
        tlStoreReference(_tlObject, 24, bot.tlObject)
        tlStoreReference(_tlObject, 32, langCode as NSString)
        tlStoreReference(_tlObject, 40, media.map { item in item.tlObject } as NSArray)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.bots {
    static func editAccessSettings(flags: Int32, bot: Api.InputUser, addUsers: [Api.InputUser]?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(174))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, bot.tlObject)
        tlStoreReference(_tlObject, 40, addUsers.map { value in value.map { item in item.tlObject } as NSArray })
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.bots {
    static func editPreviewMedia(bot: Api.InputUser, langCode: String, media: Api.InputMedia, newMedia: Api.InputMedia) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.BotPreviewMedia>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(175))
        tlStoreReference(_tlObject, 24, bot.tlObject)
        tlStoreReference(_tlObject, 32, langCode as NSString)
        tlStoreReference(_tlObject, 40, media.tlObject)
        tlStoreReference(_tlObject, 48, newMedia.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.bots {
    static func exportBotToken(bot: Api.InputUser, revoke: Api.Bool) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.bots.ExportedBotToken>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(176))
        tlStoreReference(_tlObject, 24, bot.tlObject)
        tlStoreReference(_tlObject, 32, revoke.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.bots {
    static func getAccessSettings(bot: Api.InputUser) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.bots.AccessSettings>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(177))
        tlStoreReference(_tlObject, 24, bot.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.bots {
    static func getAdminedBots() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Api.User]>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(178))
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.bots {
    static func getBotCommands(scope: Api.BotCommandScope, langCode: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Api.BotCommand]>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(179))
        tlStoreReference(_tlObject, 24, scope.tlObject)
        tlStoreReference(_tlObject, 32, langCode as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.bots {
    static func getBotInfo(flags: Int32, bot: Api.InputUser?, langCode: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.bots.BotInfo>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(180))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, bot?.tlObject)
        tlStoreReference(_tlObject, 40, langCode as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.bots {
    static func getBotMenuButton(userId: Api.InputUser) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.BotMenuButton>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(181))
        tlStoreReference(_tlObject, 24, userId.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.bots {
    static func getBotRecommendations(bot: Api.InputUser) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.users.Users>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(182))
        tlStoreReference(_tlObject, 24, bot.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.bots {
    static func getPopularAppBots(offset: String, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.bots.PopularAppBots>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(183))
        tlStoreReference(_tlObject, 32, offset as NSString)
        tlStore(_tlObject, 24, limit)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.bots {
    static func getPreviewInfo(bot: Api.InputUser, langCode: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.bots.PreviewInfo>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(184))
        tlStoreReference(_tlObject, 24, bot.tlObject)
        tlStoreReference(_tlObject, 32, langCode as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.bots {
    static func getPreviewMedias(bot: Api.InputUser) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Api.BotPreviewMedia]>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(185))
        tlStoreReference(_tlObject, 24, bot.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.bots {
    static func getRequestedWebViewButton(bot: Api.InputUser, webappReqId: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.KeyboardButton>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(186))
        tlStoreReference(_tlObject, 24, bot.tlObject)
        tlStoreReference(_tlObject, 32, webappReqId as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.bots {
    static func invokeWebViewCustomMethod(bot: Api.InputUser, customMethod: String, params: Api.DataJSON) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.DataJSON>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(187))
        tlStoreReference(_tlObject, 24, bot.tlObject)
        tlStoreReference(_tlObject, 32, customMethod as NSString)
        tlStoreReference(_tlObject, 40, params.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.bots {
    static func removeUsername(bot: Api.InputUser, username: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(188))
        tlStoreReference(_tlObject, 24, bot.tlObject)
        tlStoreReference(_tlObject, 32, username as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.bots {
    static func reorderPreviewMedias(bot: Api.InputUser, langCode: String, order: [Api.InputMedia]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(189))
        tlStoreReference(_tlObject, 24, bot.tlObject)
        tlStoreReference(_tlObject, 32, langCode as NSString)
        tlStoreReference(_tlObject, 40, order.map { item in item.tlObject } as NSArray)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.bots {
    static func reorderUsernames(bot: Api.InputUser, order: [String]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(190))
        tlStoreReference(_tlObject, 24, bot.tlObject)
        tlStoreReference(_tlObject, 32, order as NSArray)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.bots {
    static func requestWebViewButton(userId: Api.InputUser, button: Api.KeyboardButton) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.bots.RequestedButton>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(191))
        tlStoreReference(_tlObject, 24, userId.tlObject)
        tlStoreReference(_tlObject, 32, button.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.bots {
    static func resetBotCommands(scope: Api.BotCommandScope, langCode: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(192))
        tlStoreReference(_tlObject, 24, scope.tlObject)
        tlStoreReference(_tlObject, 32, langCode as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.bots {
    static func sendCustomRequest(customMethod: String, params: Api.DataJSON) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.DataJSON>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(193))
        tlStoreReference(_tlObject, 24, customMethod as NSString)
        tlStoreReference(_tlObject, 32, params.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.bots {
    static func setBotBroadcastDefaultAdminRights(adminRights: Api.ChatAdminRights) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(194))
        tlStoreReference(_tlObject, 24, adminRights.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.bots {
    static func setBotCommands(scope: Api.BotCommandScope, langCode: String, commands: [Api.BotCommand]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(195))
        tlStoreReference(_tlObject, 24, scope.tlObject)
        tlStoreReference(_tlObject, 32, langCode as NSString)
        tlStoreReference(_tlObject, 40, commands.map { item in item.tlObject } as NSArray)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.bots {
    static func setBotGroupDefaultAdminRights(adminRights: Api.ChatAdminRights) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(196))
        tlStoreReference(_tlObject, 24, adminRights.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.bots {
    static func setBotInfo(flags: Int32, bot: Api.InputUser?, langCode: String, name: String?, about: String?, description: String?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(197))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, bot?.tlObject)
        tlStoreReference(_tlObject, 40, langCode as NSString)
        tlStoreReference(_tlObject, 48, name.map { value in value as NSString })
        tlStoreReference(_tlObject, 56, about.map { value in value as NSString })
        tlStoreReference(_tlObject, 64, description.map { value in value as NSString })
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.bots {
    static func setBotMenuButton(userId: Api.InputUser, button: Api.BotMenuButton) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(198))
        tlStoreReference(_tlObject, 24, userId.tlObject)
        tlStoreReference(_tlObject, 32, button.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.bots {
    static func setCustomVerification(flags: Int32, bot: Api.InputUser?, peer: Api.InputPeer, customDescription: Api.TextWithEntities?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(199))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, bot?.tlObject)
        tlStoreReference(_tlObject, 40, peer.tlObject)
        tlStoreReference(_tlObject, 48, customDescription?.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.bots {
    static func setJoinChatResults(queryId: Int64, result: Api.JoinChatBotResult) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(200))
        tlStore(_tlObject, 24, queryId)
        tlStoreReference(_tlObject, 32, result.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.bots {
    static func toggleUserEmojiStatusPermission(bot: Api.InputUser, enabled: Api.Bool) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(201))
        tlStoreReference(_tlObject, 24, bot.tlObject)
        tlStoreReference(_tlObject, 32, enabled.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.bots {
    static func toggleUsername(bot: Api.InputUser, username: String, active: Api.Bool) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(202))
        tlStoreReference(_tlObject, 24, bot.tlObject)
        tlStoreReference(_tlObject, 32, username as NSString)
        tlStoreReference(_tlObject, 40, active.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.bots {
    static func updateStarRefProgram(flags: Int32, bot: Api.InputUser, commissionPermille: Int32, durationMonths: Int32?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.StarRefProgram>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(203))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 40, bot.tlObject)
        tlStore(_tlObject, 28, commissionPermille)
        if let _tlValue = durationMonths { tlStore(_tlObject, 32, _tlValue); _tlPresent |= 1 << 0 }
        tlStore(_tlObject, 48, _tlPresent)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.bots {
    static func updateUserEmojiStatus(userId: Api.InputUser, emojiStatus: Api.EmojiStatus) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(204))
        tlStoreReference(_tlObject, 24, userId.tlObject)
        tlStoreReference(_tlObject, 32, emojiStatus.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.channels {
    static func checkSearchPostsFlood(flags: Int32, query: String?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.SearchPostsFlood>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(205))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, query.map { value in value as NSString })
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.channels {
    static func checkUsername(channel: Api.InputChannel, username: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(206))
        tlStoreReference(_tlObject, 24, channel.tlObject)
        tlStoreReference(_tlObject, 32, username as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.channels {
    static func convertToGigagroup(channel: Api.InputChannel) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(207))
        tlStoreReference(_tlObject, 24, channel.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.channels {
    static func createChannel(flags: Int32, title: String, about: String, geoPoint: Api.InputGeoPoint?, address: String?, ttlPeriod: Int32?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(208))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, title as NSString)
        tlStoreReference(_tlObject, 40, about as NSString)
        tlStoreReference(_tlObject, 48, geoPoint?.tlObject)
        tlStoreReference(_tlObject, 56, address.map { value in value as NSString })
        if let _tlValue = ttlPeriod { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        tlStore(_tlObject, 64, _tlPresent)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.channels {
    static func deactivateAllUsernames(channel: Api.InputChannel) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(209))
        tlStoreReference(_tlObject, 24, channel.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.channels {
    static func deleteChannel(channel: Api.InputChannel) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(210))
        tlStoreReference(_tlObject, 24, channel.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.channels {
    static func deleteHistory(flags: Int32, channel: Api.InputChannel, maxId: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(211))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, channel.tlObject)
        tlStore(_tlObject, 28, maxId)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.channels {
    static func deleteMessages(channel: Api.InputChannel, id: [Int32]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.AffectedMessages>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(212))
        tlStoreReference(_tlObject, 24, channel.tlObject)
        tlStoreReference(_tlObject, 32, tlPackInt32(id) as NSData)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.channels {
    static func deleteParticipantHistory(channel: Api.InputChannel, participant: Api.InputPeer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.AffectedHistory>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(213))
        tlStoreReference(_tlObject, 24, channel.tlObject)
        tlStoreReference(_tlObject, 32, participant.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.channels {
    static func editAdmin(flags: Int32, channel: Api.InputChannel, userId: Api.InputUser, adminRights: Api.ChatAdminRights, rank: String?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(214))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, channel.tlObject)
        tlStoreReference(_tlObject, 40, userId.tlObject)
        tlStoreReference(_tlObject, 48, adminRights.tlObject)
        tlStoreReference(_tlObject, 56, rank.map { value in value as NSString })
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.channels {
    static func editBanned(channel: Api.InputChannel, participant: Api.InputPeer, bannedRights: Api.ChatBannedRights) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(215))
        tlStoreReference(_tlObject, 24, channel.tlObject)
        tlStoreReference(_tlObject, 32, participant.tlObject)
        tlStoreReference(_tlObject, 40, bannedRights.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.channels {
    static func editLocation(channel: Api.InputChannel, geoPoint: Api.InputGeoPoint, address: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(216))
        tlStoreReference(_tlObject, 24, channel.tlObject)
        tlStoreReference(_tlObject, 32, geoPoint.tlObject)
        tlStoreReference(_tlObject, 40, address as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.channels {
    static func editPhoto(channel: Api.InputChannel, photo: Api.InputChatPhoto) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(217))
        tlStoreReference(_tlObject, 24, channel.tlObject)
        tlStoreReference(_tlObject, 32, photo.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.channels {
    static func editTitle(channel: Api.InputChannel, title: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(218))
        tlStoreReference(_tlObject, 24, channel.tlObject)
        tlStoreReference(_tlObject, 32, title as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.channels {
    static func exportMessageLink(flags: Int32, channel: Api.InputChannel, id: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.ExportedMessageLink>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(219))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, channel.tlObject)
        tlStore(_tlObject, 28, id)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.channels {
    static func getAdminLog(flags: Int32, channel: Api.InputChannel, q: String, eventsFilter: Api.ChannelAdminLogEventsFilter?, admins: [Api.InputUser]?, maxId: Int64, minId: Int64, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.channels.AdminLogResults>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(220))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, channel.tlObject)
        tlStoreReference(_tlObject, 40, q as NSString)
        tlStoreReference(_tlObject, 48, eventsFilter?.tlObject)
        tlStoreReference(_tlObject, 56, admins.map { value in value.map { item in item.tlObject } as NSArray })
        tlStore(_tlObject, 64, maxId)
        tlStore(_tlObject, 72, minId)
        tlStore(_tlObject, 28, limit)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.channels {
    static func getAdminedPublicChannels(flags: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.Chats>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(221))
        tlStore(_tlObject, 24, flags)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.channels {
    static func getChannelRecommendations(flags: Int32, channel: Api.InputChannel?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.Chats>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(222))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, channel?.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.channels {
    static func getChannels(id: [Api.InputChannel]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.Chats>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(223))
        tlStoreReference(_tlObject, 24, id.map { item in item.tlObject } as NSArray)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.channels {
    static func getFullChannel(channel: Api.InputChannel) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.ChatFull>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(224))
        tlStoreReference(_tlObject, 24, channel.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.channels {
    static func getGroupsForDiscussion() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.Chats>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(225))
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.channels {
    static func getInactiveChannels() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.InactiveChats>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(226))
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.channels {
    static func getLeftChannels(offset: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.Chats>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(227))
        tlStore(_tlObject, 24, offset)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.channels {
    static func getMessageAuthor(channel: Api.InputChannel, id: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.User>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(228))
        tlStoreReference(_tlObject, 32, channel.tlObject)
        tlStore(_tlObject, 24, id)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.channels {
    static func getMessages(channel: Api.InputChannel, id: [Api.InputMessage]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.Messages>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(229))
        tlStoreReference(_tlObject, 24, channel.tlObject)
        tlStoreReference(_tlObject, 32, id.map { item in item.tlObject } as NSArray)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.channels {
    static func getParticipant(channel: Api.InputChannel, participant: Api.InputPeer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.channels.ChannelParticipant>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(230))
        tlStoreReference(_tlObject, 24, channel.tlObject)
        tlStoreReference(_tlObject, 32, participant.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.channels {
    static func getParticipants(channel: Api.InputChannel, filter: Api.ChannelParticipantsFilter, offset: Int32, limit: Int32, hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.channels.ChannelParticipants>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(231))
        tlStoreReference(_tlObject, 32, channel.tlObject)
        tlStoreReference(_tlObject, 40, filter.tlObject)
        tlStore(_tlObject, 24, offset)
        tlStore(_tlObject, 28, limit)
        tlStore(_tlObject, 48, hash)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.channels {
    static func getSendAs(flags: Int32, peer: Api.InputPeer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.channels.SendAsPeers>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(232))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, peer.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.channels {
    static func inviteToChannel(channel: Api.InputChannel, users: [Api.InputUser]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.InvitedUsers>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(233))
        tlStoreReference(_tlObject, 24, channel.tlObject)
        tlStoreReference(_tlObject, 32, users.map { item in item.tlObject } as NSArray)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.channels {
    static func joinChannel(channel: Api.InputChannel) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.ChatInviteJoinResult>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(234))
        tlStoreReference(_tlObject, 24, channel.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.channels {
    static func leaveChannel(channel: Api.InputChannel) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(235))
        tlStoreReference(_tlObject, 24, channel.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.channels {
    static func readHistory(channel: Api.InputChannel, maxId: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(236))
        tlStoreReference(_tlObject, 32, channel.tlObject)
        tlStore(_tlObject, 24, maxId)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.channels {
    static func readMessageContents(channel: Api.InputChannel, id: [Int32]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(237))
        tlStoreReference(_tlObject, 24, channel.tlObject)
        tlStoreReference(_tlObject, 32, tlPackInt32(id) as NSData)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.channels {
    static func reorderUsernames(channel: Api.InputChannel, order: [String]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(238))
        tlStoreReference(_tlObject, 24, channel.tlObject)
        tlStoreReference(_tlObject, 32, order as NSArray)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.channels {
    static func reportAntiSpamFalsePositive(channel: Api.InputChannel, msgId: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(239))
        tlStoreReference(_tlObject, 32, channel.tlObject)
        tlStore(_tlObject, 24, msgId)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.channels {
    static func reportSpam(channel: Api.InputChannel, participant: Api.InputPeer, id: [Int32]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(240))
        tlStoreReference(_tlObject, 24, channel.tlObject)
        tlStoreReference(_tlObject, 32, participant.tlObject)
        tlStoreReference(_tlObject, 40, tlPackInt32(id) as NSData)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.channels {
    static func restrictSponsoredMessages(channel: Api.InputChannel, restricted: Api.Bool) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(241))
        tlStoreReference(_tlObject, 24, channel.tlObject)
        tlStoreReference(_tlObject, 32, restricted.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.channels {
    static func searchPosts(flags: Int32, hashtag: String?, query: String?, offsetRate: Int32, offsetPeer: Api.InputPeer, offsetId: Int32, limit: Int32, allowPaidStars: Int64?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.Messages>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(242))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 40, hashtag.map { value in value as NSString })
        tlStoreReference(_tlObject, 48, query.map { value in value as NSString })
        tlStore(_tlObject, 28, offsetRate)
        tlStoreReference(_tlObject, 56, offsetPeer.tlObject)
        tlStore(_tlObject, 32, offsetId)
        tlStore(_tlObject, 36, limit)
        if let _tlValue = allowPaidStars { tlStore(_tlObject, 64, _tlValue); _tlPresent |= 1 << 0 }
        tlStore(_tlObject, 72, _tlPresent)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.channels {
    static func setBoostsToUnblockRestrictions(channel: Api.InputChannel, boosts: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(243))
        tlStoreReference(_tlObject, 32, channel.tlObject)
        tlStore(_tlObject, 24, boosts)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.channels {
    static func setDiscussionGroup(broadcast: Api.InputChannel, group: Api.InputChannel) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(244))
        tlStoreReference(_tlObject, 24, broadcast.tlObject)
        tlStoreReference(_tlObject, 32, group.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.channels {
    static func setEmojiStickers(channel: Api.InputChannel, stickerset: Api.InputStickerSet) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(245))
        tlStoreReference(_tlObject, 24, channel.tlObject)
        tlStoreReference(_tlObject, 32, stickerset.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.channels {
    static func setMainProfileTab(channel: Api.InputChannel, tab: Api.ProfileTab) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(246))
        tlStoreReference(_tlObject, 24, channel.tlObject)
        tlStoreReference(_tlObject, 32, tab.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.channels {
    static func setStickers(channel: Api.InputChannel, stickerset: Api.InputStickerSet) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(247))
        tlStoreReference(_tlObject, 24, channel.tlObject)
        tlStoreReference(_tlObject, 32, stickerset.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.channels {
    static func toggleAntiSpam(channel: Api.InputChannel, enabled: Api.Bool) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(248))
        tlStoreReference(_tlObject, 24, channel.tlObject)
        tlStoreReference(_tlObject, 32, enabled.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.channels {
    static func toggleAutotranslation(channel: Api.InputChannel, enabled: Api.Bool) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(249))
        tlStoreReference(_tlObject, 24, channel.tlObject)
        tlStoreReference(_tlObject, 32, enabled.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.channels {
    static func toggleForum(channel: Api.InputChannel, enabled: Api.Bool, tabs: Api.Bool) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(250))
        tlStoreReference(_tlObject, 24, channel.tlObject)
        tlStoreReference(_tlObject, 32, enabled.tlObject)
        tlStoreReference(_tlObject, 40, tabs.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.channels {
    static func toggleJoinRequest(flags: Int32, channel: Api.InputChannel, enabled: Api.Bool, guardBot: Api.InputUser?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(251))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, channel.tlObject)
        tlStoreReference(_tlObject, 40, enabled.tlObject)
        tlStoreReference(_tlObject, 48, guardBot?.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.channels {
    static func toggleJoinToSend(channel: Api.InputChannel, enabled: Api.Bool) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(252))
        tlStoreReference(_tlObject, 24, channel.tlObject)
        tlStoreReference(_tlObject, 32, enabled.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.channels {
    static func toggleParticipantsHidden(channel: Api.InputChannel, enabled: Api.Bool) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(253))
        tlStoreReference(_tlObject, 24, channel.tlObject)
        tlStoreReference(_tlObject, 32, enabled.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.channels {
    static func togglePreHistoryHidden(channel: Api.InputChannel, enabled: Api.Bool) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(254))
        tlStoreReference(_tlObject, 24, channel.tlObject)
        tlStoreReference(_tlObject, 32, enabled.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.channels {
    static func toggleSignatures(flags: Int32, channel: Api.InputChannel) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(255))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, channel.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.channels {
    static func toggleSlowMode(channel: Api.InputChannel, seconds: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(256))
        tlStoreReference(_tlObject, 32, channel.tlObject)
        tlStore(_tlObject, 24, seconds)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.channels {
    static func toggleUsername(channel: Api.InputChannel, username: String, active: Api.Bool) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(257))
        tlStoreReference(_tlObject, 24, channel.tlObject)
        tlStoreReference(_tlObject, 32, username as NSString)
        tlStoreReference(_tlObject, 40, active.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.channels {
    static func toggleViewForumAsMessages(channel: Api.InputChannel, enabled: Api.Bool) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(258))
        tlStoreReference(_tlObject, 24, channel.tlObject)
        tlStoreReference(_tlObject, 32, enabled.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.channels {
    static func updateColor(flags: Int32, channel: Api.InputChannel, color: Int32?, backgroundEmojiId: Int64?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(259))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, channel.tlObject)
        if let _tlValue = color { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        if let _tlValue = backgroundEmojiId { tlStore(_tlObject, 40, _tlValue); _tlPresent |= 1 << 1 }
        tlStore(_tlObject, 48, _tlPresent)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.channels {
    static func updateEmojiStatus(channel: Api.InputChannel, emojiStatus: Api.EmojiStatus) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(260))
        tlStoreReference(_tlObject, 24, channel.tlObject)
        tlStoreReference(_tlObject, 32, emojiStatus.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.channels {
    static func updatePaidMessagesPrice(flags: Int32, channel: Api.InputChannel, sendPaidMessagesStars: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(261))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, channel.tlObject)
        tlStore(_tlObject, 40, sendPaidMessagesStars)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.channels {
    static func updateUsername(channel: Api.InputChannel, username: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(262))
        tlStoreReference(_tlObject, 24, channel.tlObject)
        tlStoreReference(_tlObject, 32, username as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.chatlists {
    static func checkChatlistInvite(slug: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.chatlists.ChatlistInvite>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(263))
        tlStoreReference(_tlObject, 24, slug as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.chatlists {
    static func deleteExportedInvite(chatlist: Api.InputChatlist, slug: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(264))
        tlStoreReference(_tlObject, 24, chatlist.tlObject)
        tlStoreReference(_tlObject, 32, slug as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.chatlists {
    static func editExportedInvite(flags: Int32, chatlist: Api.InputChatlist, slug: String, title: String?, peers: [Api.InputPeer]?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.ExportedChatlistInvite>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(265))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, chatlist.tlObject)
        tlStoreReference(_tlObject, 40, slug as NSString)
        tlStoreReference(_tlObject, 48, title.map { value in value as NSString })
        tlStoreReference(_tlObject, 56, peers.map { value in value.map { item in item.tlObject } as NSArray })
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.chatlists {
    static func exportChatlistInvite(chatlist: Api.InputChatlist, title: String, peers: [Api.InputPeer]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.chatlists.ExportedChatlistInvite>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(266))
        tlStoreReference(_tlObject, 24, chatlist.tlObject)
        tlStoreReference(_tlObject, 32, title as NSString)
        tlStoreReference(_tlObject, 40, peers.map { item in item.tlObject } as NSArray)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.chatlists {
    static func getChatlistUpdates(chatlist: Api.InputChatlist) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.chatlists.ChatlistUpdates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(267))
        tlStoreReference(_tlObject, 24, chatlist.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.chatlists {
    static func getExportedInvites(chatlist: Api.InputChatlist) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.chatlists.ExportedInvites>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(268))
        tlStoreReference(_tlObject, 24, chatlist.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.chatlists {
    static func getLeaveChatlistSuggestions(chatlist: Api.InputChatlist) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Api.Peer]>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(269))
        tlStoreReference(_tlObject, 24, chatlist.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.chatlists {
    static func hideChatlistUpdates(chatlist: Api.InputChatlist) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(270))
        tlStoreReference(_tlObject, 24, chatlist.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.chatlists {
    static func joinChatlistInvite(slug: String, peers: [Api.InputPeer]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(271))
        tlStoreReference(_tlObject, 24, slug as NSString)
        tlStoreReference(_tlObject, 32, peers.map { item in item.tlObject } as NSArray)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.chatlists {
    static func joinChatlistUpdates(chatlist: Api.InputChatlist, peers: [Api.InputPeer]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(272))
        tlStoreReference(_tlObject, 24, chatlist.tlObject)
        tlStoreReference(_tlObject, 32, peers.map { item in item.tlObject } as NSArray)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.chatlists {
    static func leaveChatlist(chatlist: Api.InputChatlist, peers: [Api.InputPeer]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(273))
        tlStoreReference(_tlObject, 24, chatlist.tlObject)
        tlStoreReference(_tlObject, 32, peers.map { item in item.tlObject } as NSArray)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.communities {
    static func create(flags: Int32, title: String, about: String?, peer: Api.InputPeer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(274))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, title as NSString)
        tlStoreReference(_tlObject, 40, about.map { value in value as NSString })
        tlStoreReference(_tlObject, 48, peer.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.communities {
    static func getJoinedCommunities() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.Chats>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(275))
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.communities {
    static func getParticipantJoinedChats(community: Api.InputChannel, participant: Api.InputPeer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.communities.ParticipantJoinedChats>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(276))
        tlStoreReference(_tlObject, 24, community.tlObject)
        tlStoreReference(_tlObject, 32, participant.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.communities {
    static func getPeerLinkRequests(community: Api.InputChannel, offset: String, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.communities.PeerLinkRequests>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(277))
        tlStoreReference(_tlObject, 32, community.tlObject)
        tlStoreReference(_tlObject, 40, offset as NSString)
        tlStore(_tlObject, 24, limit)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.communities {
    static func toggleAllPeerLinkRequestApproval(flags: Int32, community: Api.InputChannel) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(278))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, community.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.communities {
    static func toggleCommunityCollapsedInDialogs(flags: Int32, community: Api.InputChannel) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(279))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, community.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.communities {
    static func toggleParticipantBanned(flags: Int32, community: Api.InputChannel, participant: Api.InputPeer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(280))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, community.tlObject)
        tlStoreReference(_tlObject, 40, participant.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.communities {
    static func togglePeerLink(flags: Int32, community: Api.InputChannel, peer: Api.InputPeer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(281))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, community.tlObject)
        tlStoreReference(_tlObject, 40, peer.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.communities {
    static func togglePeerLinkRequestApproval(flags: Int32, community: Api.InputChannel, peer: Api.InputPeer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(282))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, community.tlObject)
        tlStoreReference(_tlObject, 40, peer.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.contacts {
    static func acceptContact(id: Api.InputUser) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(283))
        tlStoreReference(_tlObject, 24, id.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.contacts {
    static func addContact(flags: Int32, id: Api.InputUser, firstName: String, lastName: String, phone: String, note: Api.TextWithEntities?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(284))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, id.tlObject)
        tlStoreReference(_tlObject, 40, firstName as NSString)
        tlStoreReference(_tlObject, 48, lastName as NSString)
        tlStoreReference(_tlObject, 56, phone as NSString)
        tlStoreReference(_tlObject, 64, note?.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.contacts {
    static func block(flags: Int32, id: Api.InputPeer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(285))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, id.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.contacts {
    static func blockFromReplies(flags: Int32, msgId: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(286))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 28, msgId)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.contacts {
    static func deleteByPhones(phones: [String]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(287))
        tlStoreReference(_tlObject, 24, phones as NSArray)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.contacts {
    static func deleteContacts(id: [Api.InputUser]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(288))
        tlStoreReference(_tlObject, 24, id.map { item in item.tlObject } as NSArray)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.contacts {
    static func editCloseFriends(id: [Int64]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(289))
        tlStoreReference(_tlObject, 24, tlPackInt64(id) as NSData)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.contacts {
    static func exportContactToken() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.ExportedContactToken>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(290))
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.contacts {
    static func getBirthdays() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.contacts.ContactBirthdays>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(291))
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.contacts {
    static func getBlocked(flags: Int32, offset: Int32, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.contacts.Blocked>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(292))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 28, offset)
        tlStore(_tlObject, 32, limit)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.contacts {
    static func getContactIDs(hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Int32]>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(293))
        tlStore(_tlObject, 24, hash)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.contacts {
    static func getContacts(hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.contacts.Contacts>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(294))
        tlStore(_tlObject, 24, hash)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.contacts {
    static func getLocated(flags: Int32, geoPoint: Api.InputGeoPoint, selfExpires: Int32?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(295))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, geoPoint.tlObject)
        if let _tlValue = selfExpires { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        tlStore(_tlObject, 40, _tlPresent)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.contacts {
    static func getSaved() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Api.SavedContact]>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(296))
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.contacts {
    static func getSponsoredPeers(q: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.contacts.SponsoredPeers>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(297))
        tlStoreReference(_tlObject, 24, q as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.contacts {
    static func getStatuses() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Api.ContactStatus]>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(298))
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.contacts {
    static func getTopPeers(flags: Int32, offset: Int32, limit: Int32, hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.contacts.TopPeers>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(299))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 28, offset)
        tlStore(_tlObject, 32, limit)
        tlStore(_tlObject, 40, hash)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.contacts {
    static func importContactToken(token: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.User>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(300))
        tlStoreReference(_tlObject, 24, token as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.contacts {
    static func importContacts(contacts: [Api.InputContact]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.contacts.ImportedContacts>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(301))
        tlStoreReference(_tlObject, 24, contacts.map { item in item.tlObject } as NSArray)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.contacts {
    static func resetSaved() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(302))
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.contacts {
    static func resetTopPeerRating(category: Api.TopPeerCategory, peer: Api.InputPeer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(303))
        tlStoreReference(_tlObject, 24, category.tlObject)
        tlStoreReference(_tlObject, 32, peer.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.contacts {
    static func resolvePhone(phone: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.contacts.ResolvedPeer>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(304))
        tlStoreReference(_tlObject, 24, phone as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.contacts {
    static func resolveUsername(flags: Int32, username: String, referer: String?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.contacts.ResolvedPeer>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(305))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, username as NSString)
        tlStoreReference(_tlObject, 40, referer.map { value in value as NSString })
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.contacts {
    static func search(flags: Int32, q: String, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.contacts.Found>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(306))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, q as NSString)
        tlStore(_tlObject, 28, limit)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.contacts {
    static func setBlocked(flags: Int32, id: [Api.InputPeer], limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(307))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, id.map { item in item.tlObject } as NSArray)
        tlStore(_tlObject, 28, limit)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.contacts {
    static func toggleTopPeers(enabled: Api.Bool) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(308))
        tlStoreReference(_tlObject, 24, enabled.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.contacts {
    static func unblock(flags: Int32, id: Api.InputPeer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(309))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, id.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.contacts {
    static func updateContactNote(id: Api.InputUser, note: Api.TextWithEntities) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(310))
        tlStoreReference(_tlObject, 24, id.tlObject)
        tlStoreReference(_tlObject, 32, note.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.ephemeral {
    static func deleteAllWelcomeMessages(peer: Api.InputPeer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(311))
        tlStoreReference(_tlObject, 24, peer.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.ephemeral {
    static func deleteMessage(flags: Int32, peer: Api.InputPeer?, receiverId: Api.InputUser, id: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(312))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, peer?.tlObject)
        tlStoreReference(_tlObject, 40, receiverId.tlObject)
        tlStore(_tlObject, 28, id)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.ephemeral {
    static func deleteWelcomeMessage(peer: Api.InputPeer, id: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(313))
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStore(_tlObject, 24, id)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.ephemeral {
    static func editMessage(flags: Int32, peer: Api.InputPeer?, receiverId: Api.InputUser, id: Int32, message: String?, media: Api.InputMedia?, entities: [Api.MessageEntity]?, replyMarkup: Api.ReplyMarkup?, richMessage: Api.InputRichMessage?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(314))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, peer?.tlObject)
        tlStoreReference(_tlObject, 40, receiverId.tlObject)
        tlStore(_tlObject, 28, id)
        tlStoreReference(_tlObject, 48, message.map { value in value as NSString })
        tlStoreReference(_tlObject, 56, media?.tlObject)
        tlStoreReference(_tlObject, 64, entities.map { value in value.map { item in item.tlObject } as NSArray })
        tlStoreReference(_tlObject, 72, replyMarkup?.tlObject)
        tlStoreReference(_tlObject, 80, richMessage?.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.ephemeral {
    static func getCallbackAnswer(flags: Int32, peer: Api.InputPeer, id: Int32, data: Buffer?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.BotCallbackAnswer>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(315))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStore(_tlObject, 28, id)
        tlStoreReference(_tlObject, 40, data.map { value in value.makeData() as NSData })
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.ephemeral {
    static func getWelcomeMessages(peer: Api.InputPeer, hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.ephemeral.WelcomeMessages>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(316))
        tlStoreReference(_tlObject, 24, peer.tlObject)
        tlStore(_tlObject, 32, hash)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.ephemeral {
    static func reportMessage(peer: Api.InputPeer, id: Int32, option: Buffer, message: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.ReportResult>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(317))
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStore(_tlObject, 24, id)
        tlStoreReference(_tlObject, 40, option.makeData() as NSData)
        tlStoreReference(_tlObject, 48, message as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.ephemeral {
    static func sendMessage(flags: Int32, peer: Api.InputPeer?, receiverId: Api.InputUser, queryId: Int64?, message: String, entities: [Api.MessageEntity]?, media: Api.InputMedia?, replyMarkup: Api.ReplyMarkup?, richMessage: Api.InputRichMessage?, randomId: Int64, replyTo: Api.InputReplyTo?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(318))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, peer?.tlObject)
        tlStoreReference(_tlObject, 40, receiverId.tlObject)
        if let _tlValue = queryId { tlStore(_tlObject, 48, _tlValue); _tlPresent |= 1 << 0 }
        tlStoreReference(_tlObject, 56, message as NSString)
        tlStoreReference(_tlObject, 64, entities.map { value in value.map { item in item.tlObject } as NSArray })
        tlStoreReference(_tlObject, 72, media?.tlObject)
        tlStoreReference(_tlObject, 80, replyMarkup?.tlObject)
        tlStoreReference(_tlObject, 88, richMessage?.tlObject)
        tlStore(_tlObject, 96, randomId)
        tlStoreReference(_tlObject, 104, replyTo?.tlObject)
        tlStore(_tlObject, 112, _tlPresent)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.folders {
    static func editPeerFolders(folderPeers: [Api.InputFolderPeer]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(319))
        tlStoreReference(_tlObject, 24, folderPeers.map { item in item.tlObject } as NSArray)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.fragment {
    static func getCollectibleInfo(collectible: Api.InputCollectible) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.fragment.CollectibleInfo>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(320))
        tlStoreReference(_tlObject, 24, collectible.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.help {
    static func acceptTermsOfService(id: Api.DataJSON) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(321))
        tlStoreReference(_tlObject, 24, id.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.help {
    static func dismissSuggestion(peer: Api.InputPeer, suggestion: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(322))
        tlStoreReference(_tlObject, 24, peer.tlObject)
        tlStoreReference(_tlObject, 32, suggestion as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.help {
    static func editUserInfo(userId: Api.InputUser, message: String, entities: [Api.MessageEntity]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.help.UserInfo>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(323))
        tlStoreReference(_tlObject, 24, userId.tlObject)
        tlStoreReference(_tlObject, 32, message as NSString)
        tlStoreReference(_tlObject, 40, entities.map { item in item.tlObject } as NSArray)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.help {
    static func getAppConfig(hash: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.help.AppConfig>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(324))
        tlStore(_tlObject, 24, hash)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.help {
    static func getAppUpdate(source: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.help.AppUpdate>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(325))
        tlStoreReference(_tlObject, 24, source as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.help {
    static func getCdnConfig() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.CdnConfig>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(326))
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.help {
    static func getConfig() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Config>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(327))
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.help {
    static func getCountriesList(langCode: String, hash: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.help.CountriesList>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(328))
        tlStoreReference(_tlObject, 32, langCode as NSString)
        tlStore(_tlObject, 24, hash)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.help {
    static func getDeepLinkInfo(path: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.help.DeepLinkInfo>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(329))
        tlStoreReference(_tlObject, 24, path as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.help {
    static func getInviteText() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.help.InviteText>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(330))
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.help {
    static func getNearestDc() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.NearestDc>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(331))
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.help {
    static func getPassportConfig(hash: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.help.PassportConfig>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(332))
        tlStore(_tlObject, 24, hash)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.help {
    static func getPeerColors(hash: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.help.PeerColors>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(333))
        tlStore(_tlObject, 24, hash)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.help {
    static func getPeerProfileColors(hash: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.help.PeerColors>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(334))
        tlStore(_tlObject, 24, hash)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.help {
    static func getPremiumPromo() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.help.PremiumPromo>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(335))
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.help {
    static func getPromoData() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.help.PromoData>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(336))
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.help {
    static func getRecentMeUrls(referer: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.help.RecentMeUrls>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(337))
        tlStoreReference(_tlObject, 24, referer as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.help {
    static func getSupport() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.help.Support>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(338))
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.help {
    static func getSupportName() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.help.SupportName>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(339))
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.help {
    static func getTermsOfServiceUpdate() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.help.TermsOfServiceUpdate>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(340))
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.help {
    static func getTimezonesList(hash: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.help.TimezonesList>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(341))
        tlStore(_tlObject, 24, hash)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.help {
    static func getUserInfo(userId: Api.InputUser) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.help.UserInfo>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(342))
        tlStoreReference(_tlObject, 24, userId.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.help {
    static func hidePromoData(peer: Api.InputPeer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(343))
        tlStoreReference(_tlObject, 24, peer.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.help {
    static func saveAppLog(events: [Api.InputAppEvent]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(344))
        tlStoreReference(_tlObject, 24, events.map { item in item.tlObject } as NSArray)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.help {
    static func setBotUpdatesStatus(pendingUpdatesCount: Int32, message: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(345))
        tlStore(_tlObject, 24, pendingUpdatesCount)
        tlStoreReference(_tlObject, 32, message as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.help {
    static func test() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(346))
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.langpack {
    static func getDifference(langPack: String, langCode: String, fromVersion: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.LangPackDifference>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(347))
        tlStoreReference(_tlObject, 32, langPack as NSString)
        tlStoreReference(_tlObject, 40, langCode as NSString)
        tlStore(_tlObject, 24, fromVersion)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.langpack {
    static func getLangPack(langPack: String, langCode: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.LangPackDifference>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(348))
        tlStoreReference(_tlObject, 24, langPack as NSString)
        tlStoreReference(_tlObject, 32, langCode as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.langpack {
    static func getLanguage(langPack: String, langCode: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.LangPackLanguage>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(349))
        tlStoreReference(_tlObject, 24, langPack as NSString)
        tlStoreReference(_tlObject, 32, langCode as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.langpack {
    static func getLanguages(langPack: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Api.LangPackLanguage]>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(350))
        tlStoreReference(_tlObject, 24, langPack as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.langpack {
    static func getStrings(langPack: String, langCode: String, keys: [String]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Api.LangPackString]>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(351))
        tlStoreReference(_tlObject, 24, langPack as NSString)
        tlStoreReference(_tlObject, 32, langCode as NSString)
        tlStoreReference(_tlObject, 40, keys as NSArray)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func acceptEncryption(peer: Api.InputEncryptedChat, gB: Buffer, keyFingerprint: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.EncryptedChat>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(352))
        tlStoreReference(_tlObject, 24, peer.tlObject)
        tlStoreReference(_tlObject, 32, gB.makeData() as NSData)
        tlStore(_tlObject, 40, keyFingerprint)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func acceptUrlAuth(flags: Int32, peer: Api.InputPeer?, msgId: Int32?, buttonId: Int32?, url: String?, matchCode: String?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.UrlAuthResult>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(353))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 40, peer?.tlObject)
        if let _tlValue = msgId { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        if let _tlValue = buttonId { tlStore(_tlObject, 32, _tlValue); _tlPresent |= 1 << 1 }
        tlStoreReference(_tlObject, 48, url.map { value in value as NSString })
        tlStoreReference(_tlObject, 56, matchCode.map { value in value as NSString })
        tlStore(_tlObject, 64, _tlPresent)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func addChatUser(chatId: Int64, userId: Api.InputUser, fwdLimit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.InvitedUsers>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(354))
        tlStore(_tlObject, 32, chatId)
        tlStoreReference(_tlObject, 40, userId.tlObject)
        tlStore(_tlObject, 24, fwdLimit)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func addPollAnswer(peer: Api.InputPeer, msgId: Int32, answer: Api.PollAnswer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(355))
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStore(_tlObject, 24, msgId)
        tlStoreReference(_tlObject, 40, answer.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func appendTodoList(peer: Api.InputPeer, msgId: Int32, list: [Api.TodoItem]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(356))
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStore(_tlObject, 24, msgId)
        tlStoreReference(_tlObject, 40, list.map { item in item.tlObject } as NSArray)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func checkChatInvite(hash: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.ChatInvite>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(357))
        tlStoreReference(_tlObject, 24, hash as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func checkHistoryImport(importHead: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.HistoryImportParsed>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(358))
        tlStoreReference(_tlObject, 24, importHead as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func checkHistoryImportPeer(peer: Api.InputPeer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.CheckedHistoryImportPeer>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(359))
        tlStoreReference(_tlObject, 24, peer.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func checkQuickReplyShortcut(shortcut: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(360))
        tlStoreReference(_tlObject, 24, shortcut as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func checkUrlAuthMatchCode(url: String, matchCode: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(361))
        tlStoreReference(_tlObject, 24, url as NSString)
        tlStoreReference(_tlObject, 32, matchCode as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func clearAllDrafts() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(362))
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func clearRecentReactions() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(363))
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func clearRecentStickers(flags: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(364))
        tlStore(_tlObject, 24, flags)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func clickSponsoredMessage(flags: Int32, randomId: Buffer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(365))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, randomId.makeData() as NSData)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func composeMessageWithAI(flags: Int32, text: Api.TextWithEntities, translateToLang: String?, tone: Api.InputAiComposeTone?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.ComposedMessageWithAI>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(366))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, text.tlObject)
        tlStoreReference(_tlObject, 40, translateToLang.map { value in value as NSString })
        tlStoreReference(_tlObject, 48, tone?.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func composeRichMessageWithAI(flags: Int32, text: Api.InputRichMessage?, translateToLang: String?, tone: Api.InputAiComposeTone?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.ComposedRichMessageWithAI>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(367))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, text?.tlObject)
        tlStoreReference(_tlObject, 40, translateToLang.map { value in value as NSString })
        tlStoreReference(_tlObject, 48, tone?.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func createChat(flags: Int32, users: [Api.InputUser], title: String, ttlPeriod: Int32?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.InvitedUsers>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(368))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, users.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 40, title as NSString)
        if let _tlValue = ttlPeriod { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        tlStore(_tlObject, 48, _tlPresent)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func createForumTopic(flags: Int32, peer: Api.InputPeer, title: String, iconColor: Int32?, iconEmojiId: Int64?, randomId: Int64, sendAs: Api.InputPeer?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(369))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStoreReference(_tlObject, 40, title as NSString)
        if let _tlValue = iconColor { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        if let _tlValue = iconEmojiId { tlStore(_tlObject, 48, _tlValue); _tlPresent |= 1 << 1 }
        tlStore(_tlObject, 56, randomId)
        tlStoreReference(_tlObject, 64, sendAs?.tlObject)
        tlStore(_tlObject, 72, _tlPresent)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func declineUrlAuth(url: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(370))
        tlStoreReference(_tlObject, 24, url as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func deleteChat(chatId: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(371))
        tlStore(_tlObject, 24, chatId)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func deleteChatUser(flags: Int32, chatId: Int64, userId: Api.InputUser) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(372))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 32, chatId)
        tlStoreReference(_tlObject, 40, userId.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func deleteExportedChatInvite(peer: Api.InputPeer, link: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(373))
        tlStoreReference(_tlObject, 24, peer.tlObject)
        tlStoreReference(_tlObject, 32, link as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func deleteFactCheck(peer: Api.InputPeer, msgId: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(374))
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStore(_tlObject, 24, msgId)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func deleteHistory(flags: Int32, peer: Api.InputPeer, maxId: Int32, minDate: Int32?, maxDate: Int32?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.AffectedHistory>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(375))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 40, peer.tlObject)
        tlStore(_tlObject, 28, maxId)
        if let _tlValue = minDate { tlStore(_tlObject, 32, _tlValue); _tlPresent |= 1 << 0 }
        if let _tlValue = maxDate { tlStore(_tlObject, 36, _tlValue); _tlPresent |= 1 << 1 }
        tlStore(_tlObject, 48, _tlPresent)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func deleteMessages(flags: Int32, id: [Int32]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.AffectedMessages>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(376))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, tlPackInt32(id) as NSData)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func deleteParticipantReaction(peer: Api.InputPeer, msgId: Int32, participant: Api.InputPeer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(377))
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStore(_tlObject, 24, msgId)
        tlStoreReference(_tlObject, 40, participant.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func deleteParticipantReactions(peer: Api.InputPeer, participant: Api.InputPeer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(378))
        tlStoreReference(_tlObject, 24, peer.tlObject)
        tlStoreReference(_tlObject, 32, participant.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func deletePhoneCallHistory(flags: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.AffectedFoundMessages>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(379))
        tlStore(_tlObject, 24, flags)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func deletePollAnswer(peer: Api.InputPeer, msgId: Int32, option: Buffer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(380))
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStore(_tlObject, 24, msgId)
        tlStoreReference(_tlObject, 40, option.makeData() as NSData)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func deleteQuickReplyMessages(shortcutId: Int32, id: [Int32]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(381))
        tlStore(_tlObject, 24, shortcutId)
        tlStoreReference(_tlObject, 32, tlPackInt32(id) as NSData)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func deleteQuickReplyShortcut(shortcutId: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(382))
        tlStore(_tlObject, 24, shortcutId)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func deleteRevokedExportedChatInvites(peer: Api.InputPeer, adminId: Api.InputUser) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(383))
        tlStoreReference(_tlObject, 24, peer.tlObject)
        tlStoreReference(_tlObject, 32, adminId.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func deleteSavedHistory(flags: Int32, parentPeer: Api.InputPeer?, peer: Api.InputPeer, maxId: Int32, minDate: Int32?, maxDate: Int32?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.AffectedHistory>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(384))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 40, parentPeer?.tlObject)
        tlStoreReference(_tlObject, 48, peer.tlObject)
        tlStore(_tlObject, 28, maxId)
        if let _tlValue = minDate { tlStore(_tlObject, 32, _tlValue); _tlPresent |= 1 << 0 }
        if let _tlValue = maxDate { tlStore(_tlObject, 36, _tlValue); _tlPresent |= 1 << 1 }
        tlStore(_tlObject, 56, _tlPresent)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func deleteScheduledMessages(peer: Api.InputPeer, id: [Int32]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(385))
        tlStoreReference(_tlObject, 24, peer.tlObject)
        tlStoreReference(_tlObject, 32, tlPackInt32(id) as NSData)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func deleteTopicHistory(peer: Api.InputPeer, topMsgId: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.AffectedHistory>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(386))
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStore(_tlObject, 24, topMsgId)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func discardEncryption(flags: Int32, chatId: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(387))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 28, chatId)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func editChatAbout(peer: Api.InputPeer, about: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(388))
        tlStoreReference(_tlObject, 24, peer.tlObject)
        tlStoreReference(_tlObject, 32, about as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func editChatAdmin(chatId: Int64, userId: Api.InputUser, isAdmin: Api.Bool) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(389))
        tlStore(_tlObject, 24, chatId)
        tlStoreReference(_tlObject, 32, userId.tlObject)
        tlStoreReference(_tlObject, 40, isAdmin.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func editChatCreator(peer: Api.InputPeer, userId: Api.InputUser, password: Api.InputCheckPasswordSRP) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(390))
        tlStoreReference(_tlObject, 24, peer.tlObject)
        tlStoreReference(_tlObject, 32, userId.tlObject)
        tlStoreReference(_tlObject, 40, password.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func editChatDefaultBannedRights(peer: Api.InputPeer, bannedRights: Api.ChatBannedRights) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(391))
        tlStoreReference(_tlObject, 24, peer.tlObject)
        tlStoreReference(_tlObject, 32, bannedRights.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func editChatParticipantRank(peer: Api.InputPeer, participant: Api.InputPeer, rank: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(392))
        tlStoreReference(_tlObject, 24, peer.tlObject)
        tlStoreReference(_tlObject, 32, participant.tlObject)
        tlStoreReference(_tlObject, 40, rank as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func editChatPhoto(chatId: Int64, photo: Api.InputChatPhoto) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(393))
        tlStore(_tlObject, 24, chatId)
        tlStoreReference(_tlObject, 32, photo.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func editChatTitle(chatId: Int64, title: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(394))
        tlStore(_tlObject, 24, chatId)
        tlStoreReference(_tlObject, 32, title as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func editExportedChatInvite(flags: Int32, peer: Api.InputPeer, link: String, expireDate: Int32?, usageLimit: Int32?, requestNeeded: Api.Bool?, title: String?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.ExportedChatInvite>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(395))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 40, peer.tlObject)
        tlStoreReference(_tlObject, 48, link as NSString)
        if let _tlValue = expireDate { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        if let _tlValue = usageLimit { tlStore(_tlObject, 32, _tlValue); _tlPresent |= 1 << 1 }
        tlStoreReference(_tlObject, 56, requestNeeded?.tlObject)
        tlStoreReference(_tlObject, 64, title.map { value in value as NSString })
        tlStore(_tlObject, 72, _tlPresent)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func editFactCheck(peer: Api.InputPeer, msgId: Int32, text: Api.TextWithEntities) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(396))
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStore(_tlObject, 24, msgId)
        tlStoreReference(_tlObject, 40, text.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func editForumTopic(flags: Int32, peer: Api.InputPeer, topicId: Int32, title: String?, iconEmojiId: Int64?, closed: Api.Bool?, hidden: Api.Bool?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(397))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStore(_tlObject, 28, topicId)
        tlStoreReference(_tlObject, 40, title.map { value in value as NSString })
        if let _tlValue = iconEmojiId { tlStore(_tlObject, 48, _tlValue); _tlPresent |= 1 << 0 }
        tlStoreReference(_tlObject, 56, closed?.tlObject)
        tlStoreReference(_tlObject, 64, hidden?.tlObject)
        tlStore(_tlObject, 72, _tlPresent)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func editInlineBotMessage(flags: Int32, id: Api.InputBotInlineMessageID, message: String?, media: Api.InputMedia?, replyMarkup: Api.ReplyMarkup?, entities: [Api.MessageEntity]?, richMessage: Api.InputRichMessage?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(398))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, id.tlObject)
        tlStoreReference(_tlObject, 40, message.map { value in value as NSString })
        tlStoreReference(_tlObject, 48, media?.tlObject)
        tlStoreReference(_tlObject, 56, replyMarkup?.tlObject)
        tlStoreReference(_tlObject, 64, entities.map { value in value.map { item in item.tlObject } as NSArray })
        tlStoreReference(_tlObject, 72, richMessage?.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func editMessage(flags: Int32, peer: Api.InputPeer, id: Int32, message: String?, media: Api.InputMedia?, replyMarkup: Api.ReplyMarkup?, entities: [Api.MessageEntity]?, scheduleDate: Int32?, scheduleRepeatPeriod: Int32?, quickReplyShortcutId: Int32?, richMessage: Api.InputRichMessage?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(399))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 48, peer.tlObject)
        tlStore(_tlObject, 28, id)
        tlStoreReference(_tlObject, 56, message.map { value in value as NSString })
        tlStoreReference(_tlObject, 64, media?.tlObject)
        tlStoreReference(_tlObject, 72, replyMarkup?.tlObject)
        tlStoreReference(_tlObject, 80, entities.map { value in value.map { item in item.tlObject } as NSArray })
        if let _tlValue = scheduleDate { tlStore(_tlObject, 32, _tlValue); _tlPresent |= 1 << 0 }
        if let _tlValue = scheduleRepeatPeriod { tlStore(_tlObject, 36, _tlValue); _tlPresent |= 1 << 1 }
        if let _tlValue = quickReplyShortcutId { tlStore(_tlObject, 40, _tlValue); _tlPresent |= 1 << 2 }
        tlStoreReference(_tlObject, 88, richMessage?.tlObject)
        tlStore(_tlObject, 96, _tlPresent)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func editQuickReplyShortcut(shortcutId: Int32, shortcut: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(400))
        tlStore(_tlObject, 24, shortcutId)
        tlStoreReference(_tlObject, 32, shortcut as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func exportChatInvite(flags: Int32, peer: Api.InputPeer, expireDate: Int32?, usageLimit: Int32?, title: String?, subscriptionPricing: Api.StarsSubscriptionPricing?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.ExportedChatInvite>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(401))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 40, peer.tlObject)
        if let _tlValue = expireDate { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        if let _tlValue = usageLimit { tlStore(_tlObject, 32, _tlValue); _tlPresent |= 1 << 1 }
        tlStoreReference(_tlObject, 48, title.map { value in value as NSString })
        tlStoreReference(_tlObject, 56, subscriptionPricing?.tlObject)
        tlStore(_tlObject, 64, _tlPresent)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func faveSticker(id: Api.InputDocument, unfave: Api.Bool) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(402))
        tlStoreReference(_tlObject, 24, id.tlObject)
        tlStoreReference(_tlObject, 32, unfave.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func forwardMessages(flags: Int32, fromPeer: Api.InputPeer, id: [Int32], randomId: [Int64], toPeer: Api.InputPeer, topMsgId: Int32?, replyTo: Api.InputReplyTo?, scheduleDate: Int32?, scheduleRepeatPeriod: Int32?, sendAs: Api.InputPeer?, quickReplyShortcut: Api.InputQuickReplyShortcut?, effect: Int64?, videoTimestamp: Int32?, allowPaidStars: Int64?, suggestedPost: Api.SuggestedPost?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(403))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 48, fromPeer.tlObject)
        tlStoreReference(_tlObject, 56, tlPackInt32(id) as NSData)
        tlStoreReference(_tlObject, 64, tlPackInt64(randomId) as NSData)
        tlStoreReference(_tlObject, 72, toPeer.tlObject)
        if let _tlValue = topMsgId { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        tlStoreReference(_tlObject, 80, replyTo?.tlObject)
        if let _tlValue = scheduleDate { tlStore(_tlObject, 32, _tlValue); _tlPresent |= 1 << 1 }
        if let _tlValue = scheduleRepeatPeriod { tlStore(_tlObject, 36, _tlValue); _tlPresent |= 1 << 2 }
        tlStoreReference(_tlObject, 88, sendAs?.tlObject)
        tlStoreReference(_tlObject, 96, quickReplyShortcut?.tlObject)
        if let _tlValue = effect { tlStore(_tlObject, 104, _tlValue); _tlPresent |= 1 << 3 }
        if let _tlValue = videoTimestamp { tlStore(_tlObject, 40, _tlValue); _tlPresent |= 1 << 4 }
        if let _tlValue = allowPaidStars { tlStore(_tlObject, 112, _tlValue); _tlPresent |= 1 << 5 }
        tlStoreReference(_tlObject, 120, suggestedPost?.tlObject)
        tlStore(_tlObject, 128, _tlPresent)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func getAdminsWithInvites(peer: Api.InputPeer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.ChatAdminsWithInvites>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(404))
        tlStoreReference(_tlObject, 24, peer.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func getAllDrafts() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(405))
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func getAllStickers(hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.AllStickers>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(406))
        tlStore(_tlObject, 24, hash)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func getArchivedStickers(flags: Int32, offsetId: Int64, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.ArchivedStickers>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(407))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 32, offsetId)
        tlStore(_tlObject, 28, limit)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func getAttachMenuBot(bot: Api.InputUser) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.AttachMenuBotsBot>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(408))
        tlStoreReference(_tlObject, 24, bot.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func getAttachMenuBots(hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.AttachMenuBots>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(409))
        tlStore(_tlObject, 24, hash)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func getAttachedStickers(media: Api.InputStickeredMedia) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Api.StickerSetCovered]>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(410))
        tlStoreReference(_tlObject, 24, media.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func getAvailableEffects(hash: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.AvailableEffects>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(411))
        tlStore(_tlObject, 24, hash)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func getAvailableReactions(hash: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.AvailableReactions>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(412))
        tlStore(_tlObject, 24, hash)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func getBotApp(app: Api.InputBotApp, hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.BotApp>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(413))
        tlStoreReference(_tlObject, 24, app.tlObject)
        tlStore(_tlObject, 32, hash)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func getBotCallbackAnswer(flags: Int32, peer: Api.InputPeer, msgId: Int32, data: Buffer?, password: Api.InputCheckPasswordSRP?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.BotCallbackAnswer>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(414))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStore(_tlObject, 28, msgId)
        tlStoreReference(_tlObject, 40, data.map { value in value.makeData() as NSData })
        tlStoreReference(_tlObject, 48, password?.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func getChatInviteImporters(flags: Int32, peer: Api.InputPeer, link: String?, q: String?, offsetDate: Int32, offsetUser: Api.InputUser, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.ChatInviteImporters>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(415))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 40, peer.tlObject)
        tlStoreReference(_tlObject, 48, link.map { value in value as NSString })
        tlStoreReference(_tlObject, 56, q.map { value in value as NSString })
        tlStore(_tlObject, 28, offsetDate)
        tlStoreReference(_tlObject, 64, offsetUser.tlObject)
        tlStore(_tlObject, 32, limit)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func getChats(id: [Int64]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.Chats>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(416))
        tlStoreReference(_tlObject, 24, tlPackInt64(id) as NSData)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func getCommonChats(userId: Api.InputUser, maxId: Int64, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.Chats>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(417))
        tlStoreReference(_tlObject, 32, userId.tlObject)
        tlStore(_tlObject, 40, maxId)
        tlStore(_tlObject, 24, limit)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func getCustomEmojiDocuments(documentId: [Int64]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Api.Document]>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(418))
        tlStoreReference(_tlObject, 24, tlPackInt64(documentId) as NSData)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func getDefaultHistoryTTL() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.DefaultHistoryTTL>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(419))
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func getDefaultTagReactions(hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.Reactions>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(420))
        tlStore(_tlObject, 24, hash)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func getDhConfig(version: Int32, randomLength: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.DhConfig>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(421))
        tlStore(_tlObject, 24, version)
        tlStore(_tlObject, 28, randomLength)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func getDialogFilters() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.DialogFilters>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(422))
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func getDialogUnreadMarks(flags: Int32, parentPeer: Api.InputPeer?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Api.DialogPeer]>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(423))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, parentPeer?.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func getDialogs(flags: Int32, folderId: Int32?, offsetDate: Int32, offsetId: Int32, offsetPeer: Api.InputPeer, limit: Int32, hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.Dialogs>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(424))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        if let _tlValue = folderId { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        tlStore(_tlObject, 32, offsetDate)
        tlStore(_tlObject, 36, offsetId)
        tlStoreReference(_tlObject, 48, offsetPeer.tlObject)
        tlStore(_tlObject, 40, limit)
        tlStore(_tlObject, 56, hash)
        tlStore(_tlObject, 64, _tlPresent)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func getDiscussionMessage(peer: Api.InputPeer, msgId: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.DiscussionMessage>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(425))
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStore(_tlObject, 24, msgId)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func getDocumentByHash(sha256: Buffer, size: Int64, mimeType: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Document>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(426))
        tlStoreReference(_tlObject, 24, sha256.makeData() as NSData)
        tlStore(_tlObject, 32, size)
        tlStoreReference(_tlObject, 40, mimeType as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func getEmojiGameInfo() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.EmojiGameInfo>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(427))
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func getEmojiGroups(hash: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.EmojiGroups>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(428))
        tlStore(_tlObject, 24, hash)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func getEmojiKeywords(langCode: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.EmojiKeywordsDifference>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(429))
        tlStoreReference(_tlObject, 24, langCode as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func getEmojiKeywordsDifference(langCode: String, fromVersion: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.EmojiKeywordsDifference>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(430))
        tlStoreReference(_tlObject, 32, langCode as NSString)
        tlStore(_tlObject, 24, fromVersion)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func getEmojiKeywordsLanguages(langCodes: [String]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Api.EmojiLanguage]>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(431))
        tlStoreReference(_tlObject, 24, langCodes as NSArray)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func getEmojiProfilePhotoGroups(hash: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.EmojiGroups>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(432))
        tlStore(_tlObject, 24, hash)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func getEmojiStatusGroups(hash: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.EmojiGroups>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(433))
        tlStore(_tlObject, 24, hash)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func getEmojiStickerGroups(hash: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.EmojiGroups>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(434))
        tlStore(_tlObject, 24, hash)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func getEmojiStickers(hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.AllStickers>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(435))
        tlStore(_tlObject, 24, hash)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func getEmojiURL(langCode: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.EmojiURL>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(436))
        tlStoreReference(_tlObject, 24, langCode as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func getExportedChatInvite(peer: Api.InputPeer, link: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.ExportedChatInvite>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(437))
        tlStoreReference(_tlObject, 24, peer.tlObject)
        tlStoreReference(_tlObject, 32, link as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func getExportedChatInvites(flags: Int32, peer: Api.InputPeer, adminId: Api.InputUser, offsetDate: Int32?, offsetLink: String?, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.ExportedChatInvites>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(438))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 40, peer.tlObject)
        tlStoreReference(_tlObject, 48, adminId.tlObject)
        if let _tlValue = offsetDate { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        tlStoreReference(_tlObject, 56, offsetLink.map { value in value as NSString })
        tlStore(_tlObject, 32, limit)
        tlStore(_tlObject, 64, _tlPresent)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func getExtendedMedia(peer: Api.InputPeer, id: [Int32]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(439))
        tlStoreReference(_tlObject, 24, peer.tlObject)
        tlStoreReference(_tlObject, 32, tlPackInt32(id) as NSData)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func getFactCheck(peer: Api.InputPeer, msgId: [Int32]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Api.FactCheck]>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(440))
        tlStoreReference(_tlObject, 24, peer.tlObject)
        tlStoreReference(_tlObject, 32, tlPackInt32(msgId) as NSData)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func getFavedStickers(hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.FavedStickers>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(441))
        tlStore(_tlObject, 24, hash)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func getFeaturedEmojiStickers(hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.FeaturedStickers>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(442))
        tlStore(_tlObject, 24, hash)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func getFeaturedStickers(hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.FeaturedStickers>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(443))
        tlStore(_tlObject, 24, hash)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func getForumTopics(flags: Int32, peer: Api.InputPeer, q: String?, offsetDate: Int32, offsetId: Int32, offsetTopic: Int32, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.ForumTopics>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(444))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 48, peer.tlObject)
        tlStoreReference(_tlObject, 56, q.map { value in value as NSString })
        tlStore(_tlObject, 28, offsetDate)
        tlStore(_tlObject, 32, offsetId)
        tlStore(_tlObject, 36, offsetTopic)
        tlStore(_tlObject, 40, limit)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func getForumTopicsByID(peer: Api.InputPeer, topics: [Int32]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.ForumTopics>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(445))
        tlStoreReference(_tlObject, 24, peer.tlObject)
        tlStoreReference(_tlObject, 32, tlPackInt32(topics) as NSData)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func getFullChat(chatId: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.ChatFull>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(446))
        tlStore(_tlObject, 24, chatId)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func getFutureChatCreatorAfterLeave(peer: Api.InputPeer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.User>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(447))
        tlStoreReference(_tlObject, 24, peer.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func getGameHighScores(peer: Api.InputPeer, id: Int32, userId: Api.InputUser) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.HighScores>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(448))
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStore(_tlObject, 24, id)
        tlStoreReference(_tlObject, 40, userId.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func getHistory(peer: Api.InputPeer, offsetId: Int32, offsetDate: Int32, addOffset: Int32, limit: Int32, maxId: Int32, minId: Int32, hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.Messages>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(449))
        tlStoreReference(_tlObject, 48, peer.tlObject)
        tlStore(_tlObject, 24, offsetId)
        tlStore(_tlObject, 28, offsetDate)
        tlStore(_tlObject, 32, addOffset)
        tlStore(_tlObject, 36, limit)
        tlStore(_tlObject, 40, maxId)
        tlStore(_tlObject, 44, minId)
        tlStore(_tlObject, 56, hash)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func getInlineBotResults(flags: Int32, bot: Api.InputUser, peer: Api.InputPeer, geoPoint: Api.InputGeoPoint?, query: String, offset: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.BotResults>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(450))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, bot.tlObject)
        tlStoreReference(_tlObject, 40, peer.tlObject)
        tlStoreReference(_tlObject, 48, geoPoint?.tlObject)
        tlStoreReference(_tlObject, 56, query as NSString)
        tlStoreReference(_tlObject, 64, offset as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func getInlineGameHighScores(id: Api.InputBotInlineMessageID, userId: Api.InputUser) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.HighScores>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(451))
        tlStoreReference(_tlObject, 24, id.tlObject)
        tlStoreReference(_tlObject, 32, userId.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func getMaskStickers(hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.AllStickers>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(452))
        tlStore(_tlObject, 24, hash)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func getMessageEditData(peer: Api.InputPeer, id: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.MessageEditData>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(453))
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStore(_tlObject, 24, id)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func getMessageReactionsList(flags: Int32, peer: Api.InputPeer, id: Int32, reaction: Api.Reaction?, offset: String?, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.MessageReactionsList>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(454))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 40, peer.tlObject)
        tlStore(_tlObject, 28, id)
        tlStoreReference(_tlObject, 48, reaction?.tlObject)
        tlStoreReference(_tlObject, 56, offset.map { value in value as NSString })
        tlStore(_tlObject, 32, limit)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func getMessageReadParticipants(peer: Api.InputPeer, msgId: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Api.ReadParticipantDate]>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(455))
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStore(_tlObject, 24, msgId)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func getMessages(id: [Api.InputMessage]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.Messages>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(456))
        tlStoreReference(_tlObject, 24, id.map { item in item.tlObject } as NSArray)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func getMessagesReactions(peer: Api.InputPeer, id: [Int32]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(457))
        tlStoreReference(_tlObject, 24, peer.tlObject)
        tlStoreReference(_tlObject, 32, tlPackInt32(id) as NSData)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func getMessagesViews(peer: Api.InputPeer, id: [Int32], increment: Api.Bool) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.MessageViews>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(458))
        tlStoreReference(_tlObject, 24, peer.tlObject)
        tlStoreReference(_tlObject, 32, tlPackInt32(id) as NSData)
        tlStoreReference(_tlObject, 40, increment.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func getMyStickers(offsetId: Int64, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.MyStickers>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(459))
        tlStore(_tlObject, 32, offsetId)
        tlStore(_tlObject, 24, limit)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func getOldFeaturedStickers(offset: Int32, limit: Int32, hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.FeaturedStickers>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(460))
        tlStore(_tlObject, 24, offset)
        tlStore(_tlObject, 28, limit)
        tlStore(_tlObject, 32, hash)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func getOnlines(peer: Api.InputPeer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.ChatOnlines>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(461))
        tlStoreReference(_tlObject, 24, peer.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func getOutboxReadDate(peer: Api.InputPeer, msgId: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.OutboxReadDate>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(462))
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStore(_tlObject, 24, msgId)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func getPaidReactionPrivacy() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(463))
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func getPeerDialogs(peers: [Api.InputDialogPeer]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.PeerDialogs>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(464))
        tlStoreReference(_tlObject, 24, peers.map { item in item.tlObject } as NSArray)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func getPeerSettings(peer: Api.InputPeer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.PeerSettings>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(465))
        tlStoreReference(_tlObject, 24, peer.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func getPersonalChannelHistory(userId: Api.InputUser, limit: Int32, maxId: Int32, minId: Int32, hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.Messages>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(466))
        tlStoreReference(_tlObject, 40, userId.tlObject)
        tlStore(_tlObject, 24, limit)
        tlStore(_tlObject, 28, maxId)
        tlStore(_tlObject, 32, minId)
        tlStore(_tlObject, 48, hash)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func getPinnedDialogs(folderId: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.PeerDialogs>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(467))
        tlStore(_tlObject, 24, folderId)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func getPinnedSavedDialogs() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.SavedDialogs>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(468))
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func getPollResults(peer: Api.InputPeer, msgId: Int32, pollHash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(469))
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStore(_tlObject, 24, msgId)
        tlStore(_tlObject, 40, pollHash)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func getPollVotes(flags: Int32, peer: Api.InputPeer, id: Int32, option: Buffer?, offset: String?, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.VotesList>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(470))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 40, peer.tlObject)
        tlStore(_tlObject, 28, id)
        tlStoreReference(_tlObject, 48, option.map { value in value.makeData() as NSData })
        tlStoreReference(_tlObject, 56, offset.map { value in value as NSString })
        tlStore(_tlObject, 32, limit)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func getPreparedInlineMessage(bot: Api.InputUser, id: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.PreparedInlineMessage>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(471))
        tlStoreReference(_tlObject, 24, bot.tlObject)
        tlStoreReference(_tlObject, 32, id as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func getQuickReplies(hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.QuickReplies>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(472))
        tlStore(_tlObject, 24, hash)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func getQuickReplyMessages(flags: Int32, shortcutId: Int32, id: [Int32]?, hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.Messages>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(473))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 28, shortcutId)
        tlStoreReference(_tlObject, 32, id.map { value in tlPackInt32(value) as NSData })
        tlStore(_tlObject, 40, hash)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func getRecentLocations(peer: Api.InputPeer, limit: Int32, hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.Messages>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(474))
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStore(_tlObject, 24, limit)
        tlStore(_tlObject, 40, hash)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func getRecentReactions(limit: Int32, hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.Reactions>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(475))
        tlStore(_tlObject, 24, limit)
        tlStore(_tlObject, 32, hash)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func getRecentStickers(flags: Int32, hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.RecentStickers>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(476))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 32, hash)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func getReplies(peer: Api.InputPeer, msgId: Int32, offsetId: Int32, offsetDate: Int32, addOffset: Int32, limit: Int32, maxId: Int32, minId: Int32, hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.Messages>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(477))
        tlStoreReference(_tlObject, 56, peer.tlObject)
        tlStore(_tlObject, 24, msgId)
        tlStore(_tlObject, 28, offsetId)
        tlStore(_tlObject, 32, offsetDate)
        tlStore(_tlObject, 36, addOffset)
        tlStore(_tlObject, 40, limit)
        tlStore(_tlObject, 44, maxId)
        tlStore(_tlObject, 48, minId)
        tlStore(_tlObject, 64, hash)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func getRichMessage(peer: Api.InputPeer, id: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.Messages>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(478))
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStore(_tlObject, 24, id)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func getSavedDialogs(flags: Int32, parentPeer: Api.InputPeer?, offsetDate: Int32, offsetId: Int32, offsetPeer: Api.InputPeer, limit: Int32, hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.SavedDialogs>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(479))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 40, parentPeer?.tlObject)
        tlStore(_tlObject, 28, offsetDate)
        tlStore(_tlObject, 32, offsetId)
        tlStoreReference(_tlObject, 48, offsetPeer.tlObject)
        tlStore(_tlObject, 36, limit)
        tlStore(_tlObject, 56, hash)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func getSavedDialogsByID(flags: Int32, parentPeer: Api.InputPeer?, ids: [Api.InputPeer]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.SavedDialogs>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(480))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, parentPeer?.tlObject)
        tlStoreReference(_tlObject, 40, ids.map { item in item.tlObject } as NSArray)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func getSavedGifs(hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.SavedGifs>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(481))
        tlStore(_tlObject, 24, hash)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func getSavedHistory(flags: Int32, parentPeer: Api.InputPeer?, peer: Api.InputPeer, offsetId: Int32, offsetDate: Int32, addOffset: Int32, limit: Int32, maxId: Int32, minId: Int32, hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.Messages>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(482))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 56, parentPeer?.tlObject)
        tlStoreReference(_tlObject, 64, peer.tlObject)
        tlStore(_tlObject, 28, offsetId)
        tlStore(_tlObject, 32, offsetDate)
        tlStore(_tlObject, 36, addOffset)
        tlStore(_tlObject, 40, limit)
        tlStore(_tlObject, 44, maxId)
        tlStore(_tlObject, 48, minId)
        tlStore(_tlObject, 72, hash)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func getSavedReactionTags(flags: Int32, peer: Api.InputPeer?, hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.SavedReactionTags>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(483))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, peer?.tlObject)
        tlStore(_tlObject, 40, hash)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func getScheduledHistory(peer: Api.InputPeer, hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.Messages>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(484))
        tlStoreReference(_tlObject, 24, peer.tlObject)
        tlStore(_tlObject, 32, hash)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func getScheduledMessages(peer: Api.InputPeer, id: [Int32]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.Messages>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(485))
        tlStoreReference(_tlObject, 24, peer.tlObject)
        tlStoreReference(_tlObject, 32, tlPackInt32(id) as NSData)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func getSearchCounters(flags: Int32, peer: Api.InputPeer, savedPeerId: Api.InputPeer?, topMsgId: Int32?, filters: [Api.MessagesFilter]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Api.messages.SearchCounter]>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(486))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStoreReference(_tlObject, 40, savedPeerId?.tlObject)
        if let _tlValue = topMsgId { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        tlStoreReference(_tlObject, 48, filters.map { item in item.tlObject } as NSArray)
        tlStore(_tlObject, 56, _tlPresent)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func getSearchResultsCalendar(flags: Int32, peer: Api.InputPeer, savedPeerId: Api.InputPeer?, filter: Api.MessagesFilter, offsetId: Int32, offsetDate: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.SearchResultsCalendar>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(487))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 40, peer.tlObject)
        tlStoreReference(_tlObject, 48, savedPeerId?.tlObject)
        tlStoreReference(_tlObject, 56, filter.tlObject)
        tlStore(_tlObject, 28, offsetId)
        tlStore(_tlObject, 32, offsetDate)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func getSearchResultsPositions(flags: Int32, peer: Api.InputPeer, savedPeerId: Api.InputPeer?, filter: Api.MessagesFilter, offsetId: Int32, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.SearchResultsPositions>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(488))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 40, peer.tlObject)
        tlStoreReference(_tlObject, 48, savedPeerId?.tlObject)
        tlStoreReference(_tlObject, 56, filter.tlObject)
        tlStore(_tlObject, 28, offsetId)
        tlStore(_tlObject, 32, limit)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func getSplitRanges() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Api.MessageRange]>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(489))
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func getSponsoredMessages(flags: Int32, peer: Api.InputPeer, msgId: Int32?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.SponsoredMessages>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(490))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, peer.tlObject)
        if let _tlValue = msgId { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        tlStore(_tlObject, 40, _tlPresent)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func getStickerSet(stickerset: Api.InputStickerSet, hash: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.StickerSet>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(491))
        tlStoreReference(_tlObject, 32, stickerset.tlObject)
        tlStore(_tlObject, 24, hash)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func getStickers(emoticon: String, hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.Stickers>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(492))
        tlStoreReference(_tlObject, 24, emoticon as NSString)
        tlStore(_tlObject, 32, hash)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func getSuggestedDialogFilters() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Api.DialogFilterSuggested]>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(493))
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func getTopReactions(limit: Int32, hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.Reactions>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(494))
        tlStore(_tlObject, 24, limit)
        tlStore(_tlObject, 32, hash)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func getUnreadMentions(flags: Int32, peer: Api.InputPeer, topMsgId: Int32?, offsetId: Int32, addOffset: Int32, limit: Int32, maxId: Int32, minId: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.Messages>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(495))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 56, peer.tlObject)
        if let _tlValue = topMsgId { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        tlStore(_tlObject, 32, offsetId)
        tlStore(_tlObject, 36, addOffset)
        tlStore(_tlObject, 40, limit)
        tlStore(_tlObject, 44, maxId)
        tlStore(_tlObject, 48, minId)
        tlStore(_tlObject, 64, _tlPresent)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func getUnreadPollVotes(flags: Int32, peer: Api.InputPeer, topMsgId: Int32?, offsetId: Int32, addOffset: Int32, limit: Int32, maxId: Int32, minId: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.Messages>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(496))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 56, peer.tlObject)
        if let _tlValue = topMsgId { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        tlStore(_tlObject, 32, offsetId)
        tlStore(_tlObject, 36, addOffset)
        tlStore(_tlObject, 40, limit)
        tlStore(_tlObject, 44, maxId)
        tlStore(_tlObject, 48, minId)
        tlStore(_tlObject, 64, _tlPresent)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func getUnreadReactions(flags: Int32, peer: Api.InputPeer, topMsgId: Int32?, savedPeerId: Api.InputPeer?, offsetId: Int32, addOffset: Int32, limit: Int32, maxId: Int32, minId: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.Messages>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(497))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 56, peer.tlObject)
        if let _tlValue = topMsgId { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        tlStoreReference(_tlObject, 64, savedPeerId?.tlObject)
        tlStore(_tlObject, 32, offsetId)
        tlStore(_tlObject, 36, addOffset)
        tlStore(_tlObject, 40, limit)
        tlStore(_tlObject, 44, maxId)
        tlStore(_tlObject, 48, minId)
        tlStore(_tlObject, 72, _tlPresent)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func getWebPage(url: String, hash: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.WebPage>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(498))
        tlStoreReference(_tlObject, 32, url as NSString)
        tlStore(_tlObject, 24, hash)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func getWebPagePreview(flags: Int32, message: String, entities: [Api.MessageEntity]?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.WebPagePreview>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(499))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, message as NSString)
        tlStoreReference(_tlObject, 40, entities.map { value in value.map { item in item.tlObject } as NSArray })
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func hideAllChatJoinRequests(flags: Int32, peer: Api.InputPeer, link: String?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(500))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStoreReference(_tlObject, 40, link.map { value in value as NSString })
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func hideChatJoinRequest(flags: Int32, peer: Api.InputPeer, userId: Api.InputUser) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(501))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStoreReference(_tlObject, 40, userId.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func hidePeerSettingsBar(peer: Api.InputPeer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(502))
        tlStoreReference(_tlObject, 24, peer.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func importChatInvite(hash: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.ChatInviteJoinResult>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(503))
        tlStoreReference(_tlObject, 24, hash as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func initHistoryImport(peer: Api.InputPeer, file: Api.InputFile, mediaCount: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.HistoryImport>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(504))
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStoreReference(_tlObject, 40, file.tlObject)
        tlStore(_tlObject, 24, mediaCount)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func installStickerSet(stickerset: Api.InputStickerSet, archived: Api.Bool) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.StickerSetInstallResult>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(505))
        tlStoreReference(_tlObject, 24, stickerset.tlObject)
        tlStoreReference(_tlObject, 32, archived.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func markDialogUnread(flags: Int32, parentPeer: Api.InputPeer?, peer: Api.InputDialogPeer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(506))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, parentPeer?.tlObject)
        tlStoreReference(_tlObject, 40, peer.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func migrateChat(chatId: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(507))
        tlStore(_tlObject, 24, chatId)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func prolongWebView(flags: Int32, peer: Api.InputPeer, bot: Api.InputUser, queryId: Int64, replyTo: Api.InputReplyTo?, sendAs: Api.InputPeer?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(508))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStoreReference(_tlObject, 40, bot.tlObject)
        tlStore(_tlObject, 48, queryId)
        tlStoreReference(_tlObject, 56, replyTo?.tlObject)
        tlStoreReference(_tlObject, 64, sendAs?.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func rateTranscribedAudio(peer: Api.InputPeer, msgId: Int32, transcriptionId: Int64, good: Api.Bool) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(509))
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStore(_tlObject, 24, msgId)
        tlStore(_tlObject, 40, transcriptionId)
        tlStoreReference(_tlObject, 48, good.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func readDiscussion(peer: Api.InputPeer, msgId: Int32, readMaxId: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(510))
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStore(_tlObject, 24, msgId)
        tlStore(_tlObject, 28, readMaxId)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func readEncryptedHistory(peer: Api.InputEncryptedChat, maxDate: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(511))
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStore(_tlObject, 24, maxDate)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func readFeaturedStickers(id: [Int64]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(512))
        tlStoreReference(_tlObject, 24, tlPackInt64(id) as NSData)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func readHistory(peer: Api.InputPeer, maxId: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.AffectedMessages>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(513))
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStore(_tlObject, 24, maxId)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func readMentions(flags: Int32, peer: Api.InputPeer, topMsgId: Int32?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.AffectedHistory>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(514))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, peer.tlObject)
        if let _tlValue = topMsgId { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        tlStore(_tlObject, 40, _tlPresent)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func readMessageContents(id: [Int32]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.AffectedMessages>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(515))
        tlStoreReference(_tlObject, 24, tlPackInt32(id) as NSData)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func readPollVotes(flags: Int32, peer: Api.InputPeer, topMsgId: Int32?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.AffectedHistory>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(516))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, peer.tlObject)
        if let _tlValue = topMsgId { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        tlStore(_tlObject, 40, _tlPresent)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func readReactions(flags: Int32, peer: Api.InputPeer, topMsgId: Int32?, savedPeerId: Api.InputPeer?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.AffectedHistory>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(517))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, peer.tlObject)
        if let _tlValue = topMsgId { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        tlStoreReference(_tlObject, 40, savedPeerId?.tlObject)
        tlStore(_tlObject, 48, _tlPresent)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func readSavedHistory(parentPeer: Api.InputPeer, peer: Api.InputPeer, maxId: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(518))
        tlStoreReference(_tlObject, 32, parentPeer.tlObject)
        tlStoreReference(_tlObject, 40, peer.tlObject)
        tlStore(_tlObject, 24, maxId)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func receivedMessages(maxId: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Api.ReceivedNotifyMessage]>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(519))
        tlStore(_tlObject, 24, maxId)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func receivedQueue(maxQts: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Int64]>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(520))
        tlStore(_tlObject, 24, maxQts)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func reorderPinnedDialogs(flags: Int32, folderId: Int32, order: [Api.InputDialogPeer]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(521))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 28, folderId)
        tlStoreReference(_tlObject, 32, order.map { item in item.tlObject } as NSArray)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func reorderPinnedForumTopics(flags: Int32, peer: Api.InputPeer, order: [Int32]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(522))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStoreReference(_tlObject, 40, tlPackInt32(order) as NSData)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func reorderPinnedSavedDialogs(flags: Int32, order: [Api.InputDialogPeer]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(523))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, order.map { item in item.tlObject } as NSArray)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func reorderQuickReplies(order: [Int32]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(524))
        tlStoreReference(_tlObject, 24, tlPackInt32(order) as NSData)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func reorderStickerSets(flags: Int32, order: [Int64]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(525))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, tlPackInt64(order) as NSData)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func report(peer: Api.InputPeer, id: [Int32], option: Buffer, message: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.ReportResult>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(526))
        tlStoreReference(_tlObject, 24, peer.tlObject)
        tlStoreReference(_tlObject, 32, tlPackInt32(id) as NSData)
        tlStoreReference(_tlObject, 40, option.makeData() as NSData)
        tlStoreReference(_tlObject, 48, message as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func reportEncryptedSpam(peer: Api.InputEncryptedChat) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(527))
        tlStoreReference(_tlObject, 24, peer.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func reportMessagesDelivery(flags: Int32, peer: Api.InputPeer, id: [Int32]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(528))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStoreReference(_tlObject, 40, tlPackInt32(id) as NSData)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func reportMusicListen(id: Api.InputDocument, listenedDuration: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(529))
        tlStoreReference(_tlObject, 32, id.tlObject)
        tlStore(_tlObject, 24, listenedDuration)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func reportReaction(peer: Api.InputPeer, id: Int32, reactionPeer: Api.InputPeer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(530))
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStore(_tlObject, 24, id)
        tlStoreReference(_tlObject, 40, reactionPeer.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func reportReadMetrics(peer: Api.InputPeer, metrics: [Api.InputMessageReadMetric]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(531))
        tlStoreReference(_tlObject, 24, peer.tlObject)
        tlStoreReference(_tlObject, 32, metrics.map { item in item.tlObject } as NSArray)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func reportSpam(peer: Api.InputPeer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(532))
        tlStoreReference(_tlObject, 24, peer.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func reportSponsoredMessage(randomId: Buffer, option: Buffer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.channels.SponsoredMessageReportResult>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(533))
        tlStoreReference(_tlObject, 24, randomId.makeData() as NSData)
        tlStoreReference(_tlObject, 32, option.makeData() as NSData)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func requestAppWebView(flags: Int32, peer: Api.InputPeer, app: Api.InputBotApp, startParam: String?, themeParams: Api.DataJSON?, platform: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.WebViewResult>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(534))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStoreReference(_tlObject, 40, app.tlObject)
        tlStoreReference(_tlObject, 48, startParam.map { value in value as NSString })
        tlStoreReference(_tlObject, 56, themeParams?.tlObject)
        tlStoreReference(_tlObject, 64, platform as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func requestChatJoinWebView(flags: Int32, queryId: Int64, themeParams: Api.DataJSON?, platform: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.WebViewResult>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(535))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 32, queryId)
        tlStoreReference(_tlObject, 40, themeParams?.tlObject)
        tlStoreReference(_tlObject, 48, platform as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func requestEncryption(userId: Api.InputUser, randomId: Int32, gA: Buffer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.EncryptedChat>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(536))
        tlStoreReference(_tlObject, 32, userId.tlObject)
        tlStore(_tlObject, 24, randomId)
        tlStoreReference(_tlObject, 40, gA.makeData() as NSData)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func requestMainWebView(flags: Int32, peer: Api.InputPeer, bot: Api.InputUser, startParam: String?, themeParams: Api.DataJSON?, platform: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.WebViewResult>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(537))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStoreReference(_tlObject, 40, bot.tlObject)
        tlStoreReference(_tlObject, 48, startParam.map { value in value as NSString })
        tlStoreReference(_tlObject, 56, themeParams?.tlObject)
        tlStoreReference(_tlObject, 64, platform as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func requestSimpleWebView(flags: Int32, bot: Api.InputUser, url: String?, startParam: String?, themeParams: Api.DataJSON?, platform: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.WebViewResult>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(538))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, bot.tlObject)
        tlStoreReference(_tlObject, 40, url.map { value in value as NSString })
        tlStoreReference(_tlObject, 48, startParam.map { value in value as NSString })
        tlStoreReference(_tlObject, 56, themeParams?.tlObject)
        tlStoreReference(_tlObject, 64, platform as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func requestUrlAuth(flags: Int32, peer: Api.InputPeer?, msgId: Int32?, buttonId: Int32?, url: String?, inAppOrigin: String?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.UrlAuthResult>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(539))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 40, peer?.tlObject)
        if let _tlValue = msgId { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        if let _tlValue = buttonId { tlStore(_tlObject, 32, _tlValue); _tlPresent |= 1 << 1 }
        tlStoreReference(_tlObject, 48, url.map { value in value as NSString })
        tlStoreReference(_tlObject, 56, inAppOrigin.map { value in value as NSString })
        tlStore(_tlObject, 64, _tlPresent)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func requestWebView(flags: Int32, peer: Api.InputPeer, bot: Api.InputUser, url: String?, startParam: String?, themeParams: Api.DataJSON?, platform: String, replyTo: Api.InputReplyTo?, sendAs: Api.InputPeer?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.WebViewResult>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(540))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStoreReference(_tlObject, 40, bot.tlObject)
        tlStoreReference(_tlObject, 48, url.map { value in value as NSString })
        tlStoreReference(_tlObject, 56, startParam.map { value in value as NSString })
        tlStoreReference(_tlObject, 64, themeParams?.tlObject)
        tlStoreReference(_tlObject, 72, platform as NSString)
        tlStoreReference(_tlObject, 80, replyTo?.tlObject)
        tlStoreReference(_tlObject, 88, sendAs?.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func saveDefaultSendAs(peer: Api.InputPeer, sendAs: Api.InputPeer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(541))
        tlStoreReference(_tlObject, 24, peer.tlObject)
        tlStoreReference(_tlObject, 32, sendAs.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func saveDraft(flags: Int32, replyTo: Api.InputReplyTo?, peer: Api.InputPeer, message: String, entities: [Api.MessageEntity]?, media: Api.InputMedia?, effect: Int64?, suggestedPost: Api.SuggestedPost?, richMessage: Api.InputRichMessage?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(542))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, replyTo?.tlObject)
        tlStoreReference(_tlObject, 40, peer.tlObject)
        tlStoreReference(_tlObject, 48, message as NSString)
        tlStoreReference(_tlObject, 56, entities.map { value in value.map { item in item.tlObject } as NSArray })
        tlStoreReference(_tlObject, 64, media?.tlObject)
        if let _tlValue = effect { tlStore(_tlObject, 72, _tlValue); _tlPresent |= 1 << 0 }
        tlStoreReference(_tlObject, 80, suggestedPost?.tlObject)
        tlStoreReference(_tlObject, 88, richMessage?.tlObject)
        tlStore(_tlObject, 96, _tlPresent)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func saveGif(id: Api.InputDocument, unsave: Api.Bool) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(543))
        tlStoreReference(_tlObject, 24, id.tlObject)
        tlStoreReference(_tlObject, 32, unsave.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func savePreparedInlineMessage(flags: Int32, result: Api.InputBotInlineResult, userId: Api.InputUser, peerTypes: [Api.InlineQueryPeerType]?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.BotPreparedInlineMessage>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(544))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, result.tlObject)
        tlStoreReference(_tlObject, 40, userId.tlObject)
        tlStoreReference(_tlObject, 48, peerTypes.map { value in value.map { item in item.tlObject } as NSArray })
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func saveRecentSticker(flags: Int32, id: Api.InputDocument, unsave: Api.Bool) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(545))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, id.tlObject)
        tlStoreReference(_tlObject, 40, unsave.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func search(flags: Int32, peer: Api.InputPeer, q: String, fromId: Api.InputPeer?, savedPeerId: Api.InputPeer?, savedReaction: [Api.Reaction]?, topMsgId: Int32?, filter: Api.MessagesFilter, minDate: Int32, maxDate: Int32, offsetId: Int32, addOffset: Int32, limit: Int32, maxId: Int32, minId: Int32, hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.Messages>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(546))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 64, peer.tlObject)
        tlStoreReference(_tlObject, 72, q as NSString)
        tlStoreReference(_tlObject, 80, fromId?.tlObject)
        tlStoreReference(_tlObject, 88, savedPeerId?.tlObject)
        tlStoreReference(_tlObject, 96, savedReaction.map { value in value.map { item in item.tlObject } as NSArray })
        if let _tlValue = topMsgId { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        tlStoreReference(_tlObject, 104, filter.tlObject)
        tlStore(_tlObject, 32, minDate)
        tlStore(_tlObject, 36, maxDate)
        tlStore(_tlObject, 40, offsetId)
        tlStore(_tlObject, 44, addOffset)
        tlStore(_tlObject, 48, limit)
        tlStore(_tlObject, 52, maxId)
        tlStore(_tlObject, 56, minId)
        tlStore(_tlObject, 112, hash)
        tlStore(_tlObject, 120, _tlPresent)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func searchCustomEmoji(emoticon: String, hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.EmojiList>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(547))
        tlStoreReference(_tlObject, 24, emoticon as NSString)
        tlStore(_tlObject, 32, hash)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func searchEmojiStickerSets(flags: Int32, q: String, hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.FoundStickerSets>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(548))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, q as NSString)
        tlStore(_tlObject, 40, hash)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func searchGlobal(flags: Int32, folderId: Int32?, community: Api.InputChannel?, q: String, filter: Api.MessagesFilter, minDate: Int32, maxDate: Int32, offsetRate: Int32, offsetPeer: Api.InputPeer, offsetId: Int32, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.Messages>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(549))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        if let _tlValue = folderId { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        tlStoreReference(_tlObject, 56, community?.tlObject)
        tlStoreReference(_tlObject, 64, q as NSString)
        tlStoreReference(_tlObject, 72, filter.tlObject)
        tlStore(_tlObject, 32, minDate)
        tlStore(_tlObject, 36, maxDate)
        tlStore(_tlObject, 40, offsetRate)
        tlStoreReference(_tlObject, 80, offsetPeer.tlObject)
        tlStore(_tlObject, 44, offsetId)
        tlStore(_tlObject, 48, limit)
        tlStore(_tlObject, 88, _tlPresent)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func searchSentMedia(q: String, filter: Api.MessagesFilter, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.Messages>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(550))
        tlStoreReference(_tlObject, 32, q as NSString)
        tlStoreReference(_tlObject, 40, filter.tlObject)
        tlStore(_tlObject, 24, limit)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func searchStickerSets(flags: Int32, q: String, hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.FoundStickerSets>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(551))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, q as NSString)
        tlStore(_tlObject, 40, hash)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func searchStickers(flags: Int32, q: String, emoticon: String, langCode: [String], offset: Int32, limit: Int32, hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.FoundStickers>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(552))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 40, q as NSString)
        tlStoreReference(_tlObject, 48, emoticon as NSString)
        tlStoreReference(_tlObject, 56, langCode as NSArray)
        tlStore(_tlObject, 28, offset)
        tlStore(_tlObject, 32, limit)
        tlStore(_tlObject, 64, hash)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func sendBotRequestedPeer(flags: Int32, peer: Api.InputPeer, msgId: Int32?, webappReqId: String?, buttonId: Int32, requestedPeers: [Api.InputPeer]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(553))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 40, peer.tlObject)
        if let _tlValue = msgId { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        tlStoreReference(_tlObject, 48, webappReqId.map { value in value as NSString })
        tlStore(_tlObject, 32, buttonId)
        tlStoreReference(_tlObject, 56, requestedPeers.map { item in item.tlObject } as NSArray)
        tlStore(_tlObject, 64, _tlPresent)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func sendEncrypted(flags: Int32, peer: Api.InputEncryptedChat, randomId: Int64, data: Buffer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.SentEncryptedMessage>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(554))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStore(_tlObject, 40, randomId)
        tlStoreReference(_tlObject, 48, data.makeData() as NSData)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func sendEncryptedFile(flags: Int32, peer: Api.InputEncryptedChat, randomId: Int64, data: Buffer, file: Api.InputEncryptedFile) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.SentEncryptedMessage>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(555))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStore(_tlObject, 40, randomId)
        tlStoreReference(_tlObject, 48, data.makeData() as NSData)
        tlStoreReference(_tlObject, 56, file.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func sendEncryptedService(peer: Api.InputEncryptedChat, randomId: Int64, data: Buffer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.SentEncryptedMessage>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(556))
        tlStoreReference(_tlObject, 24, peer.tlObject)
        tlStore(_tlObject, 32, randomId)
        tlStoreReference(_tlObject, 40, data.makeData() as NSData)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func sendInlineBotResult(flags: Int32, peer: Api.InputPeer, replyTo: Api.InputReplyTo?, randomId: Int64, queryId: Int64, id: String, scheduleDate: Int32?, sendAs: Api.InputPeer?, quickReplyShortcut: Api.InputQuickReplyShortcut?, allowPaidStars: Int64?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(557))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStoreReference(_tlObject, 40, replyTo?.tlObject)
        tlStore(_tlObject, 48, randomId)
        tlStore(_tlObject, 56, queryId)
        tlStoreReference(_tlObject, 64, id as NSString)
        if let _tlValue = scheduleDate { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        tlStoreReference(_tlObject, 72, sendAs?.tlObject)
        tlStoreReference(_tlObject, 80, quickReplyShortcut?.tlObject)
        if let _tlValue = allowPaidStars { tlStore(_tlObject, 88, _tlValue); _tlPresent |= 1 << 1 }
        tlStore(_tlObject, 96, _tlPresent)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func sendMedia(flags: Int32, peer: Api.InputPeer, replyTo: Api.InputReplyTo?, media: Api.InputMedia, message: String, randomId: Int64, replyMarkup: Api.ReplyMarkup?, entities: [Api.MessageEntity]?, scheduleDate: Int32?, scheduleRepeatPeriod: Int32?, sendAs: Api.InputPeer?, quickReplyShortcut: Api.InputQuickReplyShortcut?, effect: Int64?, allowPaidStars: Int64?, suggestedPost: Api.SuggestedPost?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(558))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 40, peer.tlObject)
        tlStoreReference(_tlObject, 48, replyTo?.tlObject)
        tlStoreReference(_tlObject, 56, media.tlObject)
        tlStoreReference(_tlObject, 64, message as NSString)
        tlStore(_tlObject, 72, randomId)
        tlStoreReference(_tlObject, 80, replyMarkup?.tlObject)
        tlStoreReference(_tlObject, 88, entities.map { value in value.map { item in item.tlObject } as NSArray })
        if let _tlValue = scheduleDate { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        if let _tlValue = scheduleRepeatPeriod { tlStore(_tlObject, 32, _tlValue); _tlPresent |= 1 << 1 }
        tlStoreReference(_tlObject, 96, sendAs?.tlObject)
        tlStoreReference(_tlObject, 104, quickReplyShortcut?.tlObject)
        if let _tlValue = effect { tlStore(_tlObject, 112, _tlValue); _tlPresent |= 1 << 2 }
        if let _tlValue = allowPaidStars { tlStore(_tlObject, 120, _tlValue); _tlPresent |= 1 << 3 }
        tlStoreReference(_tlObject, 128, suggestedPost?.tlObject)
        tlStore(_tlObject, 136, _tlPresent)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func sendMessage(flags: Int32, peer: Api.InputPeer, replyTo: Api.InputReplyTo?, message: String, randomId: Int64, replyMarkup: Api.ReplyMarkup?, entities: [Api.MessageEntity]?, scheduleDate: Int32?, scheduleRepeatPeriod: Int32?, sendAs: Api.InputPeer?, quickReplyShortcut: Api.InputQuickReplyShortcut?, effect: Int64?, allowPaidStars: Int64?, suggestedPost: Api.SuggestedPost?, richMessage: Api.InputRichMessage?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(559))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 40, peer.tlObject)
        tlStoreReference(_tlObject, 48, replyTo?.tlObject)
        tlStoreReference(_tlObject, 56, message as NSString)
        tlStore(_tlObject, 64, randomId)
        tlStoreReference(_tlObject, 72, replyMarkup?.tlObject)
        tlStoreReference(_tlObject, 80, entities.map { value in value.map { item in item.tlObject } as NSArray })
        if let _tlValue = scheduleDate { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        if let _tlValue = scheduleRepeatPeriod { tlStore(_tlObject, 32, _tlValue); _tlPresent |= 1 << 1 }
        tlStoreReference(_tlObject, 88, sendAs?.tlObject)
        tlStoreReference(_tlObject, 96, quickReplyShortcut?.tlObject)
        if let _tlValue = effect { tlStore(_tlObject, 104, _tlValue); _tlPresent |= 1 << 2 }
        if let _tlValue = allowPaidStars { tlStore(_tlObject, 112, _tlValue); _tlPresent |= 1 << 3 }
        tlStoreReference(_tlObject, 120, suggestedPost?.tlObject)
        tlStoreReference(_tlObject, 128, richMessage?.tlObject)
        tlStore(_tlObject, 136, _tlPresent)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func sendMultiMedia(flags: Int32, peer: Api.InputPeer, replyTo: Api.InputReplyTo?, multiMedia: [Api.InputSingleMedia], scheduleDate: Int32?, sendAs: Api.InputPeer?, quickReplyShortcut: Api.InputQuickReplyShortcut?, effect: Int64?, allowPaidStars: Int64?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(560))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStoreReference(_tlObject, 40, replyTo?.tlObject)
        tlStoreReference(_tlObject, 48, multiMedia.map { item in item.tlObject } as NSArray)
        if let _tlValue = scheduleDate { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        tlStoreReference(_tlObject, 56, sendAs?.tlObject)
        tlStoreReference(_tlObject, 64, quickReplyShortcut?.tlObject)
        if let _tlValue = effect { tlStore(_tlObject, 72, _tlValue); _tlPresent |= 1 << 1 }
        if let _tlValue = allowPaidStars { tlStore(_tlObject, 80, _tlValue); _tlPresent |= 1 << 2 }
        tlStore(_tlObject, 88, _tlPresent)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func sendPaidReaction(flags: Int32, peer: Api.InputPeer, msgId: Int32, count: Int32, randomId: Int64, `private`: Api.PaidReactionPrivacy?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(561))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 40, peer.tlObject)
        tlStore(_tlObject, 28, msgId)
        tlStore(_tlObject, 32, count)
        tlStore(_tlObject, 48, randomId)
        tlStoreReference(_tlObject, 56, `private`?.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func sendQuickReplyMessages(peer: Api.InputPeer, shortcutId: Int32, id: [Int32], randomId: [Int64]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(562))
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStore(_tlObject, 24, shortcutId)
        tlStoreReference(_tlObject, 40, tlPackInt32(id) as NSData)
        tlStoreReference(_tlObject, 48, tlPackInt64(randomId) as NSData)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func sendReaction(flags: Int32, peer: Api.InputPeer, msgId: Int32, reaction: [Api.Reaction]?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(563))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStore(_tlObject, 28, msgId)
        tlStoreReference(_tlObject, 40, reaction.map { value in value.map { item in item.tlObject } as NSArray })
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func sendScheduledMessages(peer: Api.InputPeer, id: [Int32]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(564))
        tlStoreReference(_tlObject, 24, peer.tlObject)
        tlStoreReference(_tlObject, 32, tlPackInt32(id) as NSData)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func sendScreenshotNotification(peer: Api.InputPeer, replyTo: Api.InputReplyTo, randomId: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(565))
        tlStoreReference(_tlObject, 24, peer.tlObject)
        tlStoreReference(_tlObject, 32, replyTo.tlObject)
        tlStore(_tlObject, 40, randomId)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func sendVote(peer: Api.InputPeer, msgId: Int32, options: [Buffer]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(566))
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStore(_tlObject, 24, msgId)
        tlStoreReference(_tlObject, 40, options.map { item in item.makeData() } as NSArray)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func sendWebViewData(bot: Api.InputUser, randomId: Int64, buttonText: String, data: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(567))
        tlStoreReference(_tlObject, 24, bot.tlObject)
        tlStore(_tlObject, 32, randomId)
        tlStoreReference(_tlObject, 40, buttonText as NSString)
        tlStoreReference(_tlObject, 48, data as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func sendWebViewResultMessage(botQueryId: String, result: Api.InputBotInlineResult) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.WebViewMessageSent>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(568))
        tlStoreReference(_tlObject, 24, botQueryId as NSString)
        tlStoreReference(_tlObject, 32, result.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func setBotCallbackAnswer(flags: Int32, queryId: Int64, message: String?, url: String?, cacheTime: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(569))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 32, queryId)
        tlStoreReference(_tlObject, 40, message.map { value in value as NSString })
        tlStoreReference(_tlObject, 48, url.map { value in value as NSString })
        tlStore(_tlObject, 28, cacheTime)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func setBotGuestChatResult(queryId: Int64, result: Api.InputBotInlineResult) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.InputBotInlineMessageID>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(570))
        tlStore(_tlObject, 24, queryId)
        tlStoreReference(_tlObject, 32, result.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func setBotPrecheckoutResults(flags: Int32, queryId: Int64, error: String?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(571))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 32, queryId)
        tlStoreReference(_tlObject, 40, error.map { value in value as NSString })
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func setBotShippingResults(flags: Int32, queryId: Int64, error: String?, shippingOptions: [Api.ShippingOption]?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(572))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 32, queryId)
        tlStoreReference(_tlObject, 40, error.map { value in value as NSString })
        tlStoreReference(_tlObject, 48, shippingOptions.map { value in value.map { item in item.tlObject } as NSArray })
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func setChatAvailableReactions(flags: Int32, peer: Api.InputPeer, availableReactions: Api.ChatReactions, reactionsLimit: Int32?, paidEnabled: Api.Bool?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(573))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStoreReference(_tlObject, 40, availableReactions.tlObject)
        if let _tlValue = reactionsLimit { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        tlStoreReference(_tlObject, 48, paidEnabled?.tlObject)
        tlStore(_tlObject, 56, _tlPresent)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func setChatTheme(peer: Api.InputPeer, theme: Api.InputChatTheme) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(574))
        tlStoreReference(_tlObject, 24, peer.tlObject)
        tlStoreReference(_tlObject, 32, theme.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func setChatWallPaper(flags: Int32, peer: Api.InputPeer, wallpaper: Api.InputWallPaper?, settings: Api.WallPaperSettings?, id: Int32?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(575))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStoreReference(_tlObject, 40, wallpaper?.tlObject)
        tlStoreReference(_tlObject, 48, settings?.tlObject)
        if let _tlValue = id { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        tlStore(_tlObject, 56, _tlPresent)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func setDefaultHistoryTTL(period: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(576))
        tlStore(_tlObject, 24, period)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func setDefaultReaction(reaction: Api.Reaction) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(577))
        tlStoreReference(_tlObject, 24, reaction.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func setEncryptedTyping(peer: Api.InputEncryptedChat, typing: Api.Bool) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(578))
        tlStoreReference(_tlObject, 24, peer.tlObject)
        tlStoreReference(_tlObject, 32, typing.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func setGameScore(flags: Int32, peer: Api.InputPeer, id: Int32, userId: Api.InputUser, score: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(579))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 40, peer.tlObject)
        tlStore(_tlObject, 28, id)
        tlStoreReference(_tlObject, 48, userId.tlObject)
        tlStore(_tlObject, 32, score)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func setHistoryTTL(peer: Api.InputPeer, period: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(580))
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStore(_tlObject, 24, period)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func setInlineBotResults(flags: Int32, queryId: Int64, results: [Api.InputBotInlineResult], cacheTime: Int32, nextOffset: String?, switchPm: Api.InlineBotSwitchPM?, switchWebview: Api.InlineBotWebView?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(581))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 32, queryId)
        tlStoreReference(_tlObject, 40, results.map { item in item.tlObject } as NSArray)
        tlStore(_tlObject, 28, cacheTime)
        tlStoreReference(_tlObject, 48, nextOffset.map { value in value as NSString })
        tlStoreReference(_tlObject, 56, switchPm?.tlObject)
        tlStoreReference(_tlObject, 64, switchWebview?.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func setInlineGameScore(flags: Int32, id: Api.InputBotInlineMessageID, userId: Api.InputUser, score: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(582))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, id.tlObject)
        tlStoreReference(_tlObject, 40, userId.tlObject)
        tlStore(_tlObject, 28, score)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func setTyping(flags: Int32, peer: Api.InputPeer, topMsgId: Int32?, action: Api.SendMessageAction) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(583))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, peer.tlObject)
        if let _tlValue = topMsgId { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        tlStoreReference(_tlObject, 40, action.tlObject)
        tlStore(_tlObject, 48, _tlPresent)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func startBot(bot: Api.InputUser, peer: Api.InputPeer, randomId: Int64, startParam: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(584))
        tlStoreReference(_tlObject, 24, bot.tlObject)
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStore(_tlObject, 40, randomId)
        tlStoreReference(_tlObject, 48, startParam as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func startHistoryImport(peer: Api.InputPeer, importId: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(585))
        tlStoreReference(_tlObject, 24, peer.tlObject)
        tlStore(_tlObject, 32, importId)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func summarizeText(flags: Int32, peer: Api.InputPeer, id: Int32, toLang: String?, tone: String?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.TextWithEntities>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(586))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStore(_tlObject, 28, id)
        tlStoreReference(_tlObject, 40, toLang.map { value in value as NSString })
        tlStoreReference(_tlObject, 48, tone.map { value in value as NSString })
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func toggleBotInAttachMenu(flags: Int32, bot: Api.InputUser, enabled: Api.Bool) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(587))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, bot.tlObject)
        tlStoreReference(_tlObject, 40, enabled.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func toggleDialogFilterTags(enabled: Api.Bool) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(588))
        tlStoreReference(_tlObject, 24, enabled.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func toggleDialogPin(flags: Int32, peer: Api.InputDialogPeer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(589))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, peer.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func toggleNoForwards(flags: Int32, peer: Api.InputPeer, enabled: Api.Bool, requestMsgId: Int32?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(590))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStoreReference(_tlObject, 40, enabled.tlObject)
        if let _tlValue = requestMsgId { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        tlStore(_tlObject, 48, _tlPresent)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func togglePaidReactionPrivacy(peer: Api.InputPeer, msgId: Int32, `private`: Api.PaidReactionPrivacy) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(591))
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStore(_tlObject, 24, msgId)
        tlStoreReference(_tlObject, 40, `private`.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func togglePeerTranslations(flags: Int32, peer: Api.InputPeer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(592))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, peer.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func toggleSavedDialogPin(flags: Int32, peer: Api.InputDialogPeer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(593))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, peer.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func toggleStickerSets(flags: Int32, stickersets: [Api.InputStickerSet]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(594))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, stickersets.map { item in item.tlObject } as NSArray)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func toggleSuggestedPostApproval(flags: Int32, peer: Api.InputPeer, msgId: Int32, scheduleDate: Int32?, rejectComment: String?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(595))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 40, peer.tlObject)
        tlStore(_tlObject, 28, msgId)
        if let _tlValue = scheduleDate { tlStore(_tlObject, 32, _tlValue); _tlPresent |= 1 << 0 }
        tlStoreReference(_tlObject, 48, rejectComment.map { value in value as NSString })
        tlStore(_tlObject, 56, _tlPresent)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func toggleTodoCompleted(peer: Api.InputPeer, msgId: Int32, completed: [Int32], incompleted: [Int32]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(596))
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStore(_tlObject, 24, msgId)
        tlStoreReference(_tlObject, 40, tlPackInt32(completed) as NSData)
        tlStoreReference(_tlObject, 48, tlPackInt32(incompleted) as NSData)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func transcribeAudio(peer: Api.InputPeer, msgId: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.TranscribedAudio>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(597))
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStore(_tlObject, 24, msgId)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func translateRichMessage(flags: Int32, peer: Api.InputPeer?, id: [Int32]?, text: [Api.InputRichMessage]?, toLang: String, tone: String?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.TranslatedRichMessage>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(598))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, peer?.tlObject)
        tlStoreReference(_tlObject, 40, id.map { value in tlPackInt32(value) as NSData })
        tlStoreReference(_tlObject, 48, text.map { value in value.map { item in item.tlObject } as NSArray })
        tlStoreReference(_tlObject, 56, toLang as NSString)
        tlStoreReference(_tlObject, 64, tone.map { value in value as NSString })
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func translateText(flags: Int32, peer: Api.InputPeer?, id: [Int32]?, text: [Api.TextWithEntities]?, toLang: String, tone: String?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.TranslatedText>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(599))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, peer?.tlObject)
        tlStoreReference(_tlObject, 40, id.map { value in tlPackInt32(value) as NSData })
        tlStoreReference(_tlObject, 48, text.map { value in value.map { item in item.tlObject } as NSArray })
        tlStoreReference(_tlObject, 56, toLang as NSString)
        tlStoreReference(_tlObject, 64, tone.map { value in value as NSString })
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func uninstallStickerSet(stickerset: Api.InputStickerSet) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(600))
        tlStoreReference(_tlObject, 24, stickerset.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func unpinAllMessages(flags: Int32, peer: Api.InputPeer, topMsgId: Int32?, savedPeerId: Api.InputPeer?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.AffectedHistory>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(601))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, peer.tlObject)
        if let _tlValue = topMsgId { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        tlStoreReference(_tlObject, 40, savedPeerId?.tlObject)
        tlStore(_tlObject, 48, _tlPresent)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func updateDialogFilter(flags: Int32, id: Int32, filter: Api.DialogFilter?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(602))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 28, id)
        tlStoreReference(_tlObject, 32, filter?.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func updateDialogFiltersOrder(order: [Int32]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(603))
        tlStoreReference(_tlObject, 24, tlPackInt32(order) as NSData)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func updatePinnedForumTopic(peer: Api.InputPeer, topicId: Int32, pinned: Api.Bool) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(604))
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStore(_tlObject, 24, topicId)
        tlStoreReference(_tlObject, 40, pinned.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func updatePinnedMessage(flags: Int32, peer: Api.InputPeer, id: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(605))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStore(_tlObject, 28, id)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func updateSavedReactionTag(flags: Int32, reaction: Api.Reaction, title: String?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(606))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, reaction.tlObject)
        tlStoreReference(_tlObject, 40, title.map { value in value as NSString })
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func uploadEncryptedFile(peer: Api.InputEncryptedChat, file: Api.InputEncryptedFile) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.EncryptedFile>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(607))
        tlStoreReference(_tlObject, 24, peer.tlObject)
        tlStoreReference(_tlObject, 32, file.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func uploadImportedMedia(peer: Api.InputPeer, importId: Int64, fileName: String, media: Api.InputMedia) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.MessageMedia>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(608))
        tlStoreReference(_tlObject, 24, peer.tlObject)
        tlStore(_tlObject, 32, importId)
        tlStoreReference(_tlObject, 40, fileName as NSString)
        tlStoreReference(_tlObject, 48, media.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func uploadMedia(flags: Int32, businessConnectionId: String?, peer: Api.InputPeer, media: Api.InputMedia) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.MessageMedia>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(609))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, businessConnectionId.map { value in value as NSString })
        tlStoreReference(_tlObject, 40, peer.tlObject)
        tlStoreReference(_tlObject, 48, media.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.messages {
    static func viewSponsoredMessage(randomId: Buffer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(610))
        tlStoreReference(_tlObject, 24, randomId.makeData() as NSData)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.payments {
    static func applyGiftCode(slug: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(611))
        tlStoreReference(_tlObject, 24, slug as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.payments {
    static func assignAppStoreTransaction(receipt: Buffer, purpose: Api.InputStorePaymentPurpose) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(612))
        tlStoreReference(_tlObject, 24, receipt.makeData() as NSData)
        tlStoreReference(_tlObject, 32, purpose.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.payments {
    static func assignPlayMarketTransaction(receipt: Api.DataJSON, purpose: Api.InputStorePaymentPurpose) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(613))
        tlStoreReference(_tlObject, 24, receipt.tlObject)
        tlStoreReference(_tlObject, 32, purpose.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.payments {
    static func botCancelStarsSubscription(flags: Int32, userId: Api.InputUser, chargeId: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(614))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, userId.tlObject)
        tlStoreReference(_tlObject, 40, chargeId as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.payments {
    static func canPurchaseStore(purpose: Api.InputStorePaymentPurpose) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(615))
        tlStoreReference(_tlObject, 24, purpose.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.payments {
    static func changeStarsSubscription(flags: Int32, peer: Api.InputPeer, subscriptionId: String, canceled: Api.Bool?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(616))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStoreReference(_tlObject, 40, subscriptionId as NSString)
        tlStoreReference(_tlObject, 48, canceled?.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.payments {
    static func checkCanSendGift(giftId: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.payments.CheckCanSendGiftResult>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(617))
        tlStore(_tlObject, 24, giftId)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.payments {
    static func checkGiftCode(slug: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.payments.CheckedGiftCode>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(618))
        tlStoreReference(_tlObject, 24, slug as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.payments {
    static func clearSavedInfo(flags: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(619))
        tlStore(_tlObject, 24, flags)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.payments {
    static func connectStarRefBot(peer: Api.InputPeer, bot: Api.InputUser) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.payments.ConnectedStarRefBots>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(620))
        tlStoreReference(_tlObject, 24, peer.tlObject)
        tlStoreReference(_tlObject, 32, bot.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.payments {
    static func convertStarGift(stargift: Api.InputSavedStarGift) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(621))
        tlStoreReference(_tlObject, 24, stargift.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.payments {
    static func craftStarGift(stargift: [Api.InputSavedStarGift]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(622))
        tlStoreReference(_tlObject, 24, stargift.map { item in item.tlObject } as NSArray)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.payments {
    static func createOnrampSession(flags: Int32, provider: String, cryptoCurrency: String, address: String, paymentMethod: String?, baseCurrency: String?, baseAmount: String?, memo: String?, theme: String?, successReturnUrl: String?, failReturnUrl: String?, cryptoAmount: String?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.OnrampSession>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(623))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, provider as NSString)
        tlStoreReference(_tlObject, 40, cryptoCurrency as NSString)
        tlStoreReference(_tlObject, 48, address as NSString)
        tlStoreReference(_tlObject, 56, paymentMethod.map { value in value as NSString })
        tlStoreReference(_tlObject, 64, baseCurrency.map { value in value as NSString })
        tlStoreReference(_tlObject, 72, baseAmount.map { value in value as NSString })
        tlStoreReference(_tlObject, 80, memo.map { value in value as NSString })
        tlStoreReference(_tlObject, 88, theme.map { value in value as NSString })
        tlStoreReference(_tlObject, 96, successReturnUrl.map { value in value as NSString })
        tlStoreReference(_tlObject, 104, failReturnUrl.map { value in value as NSString })
        tlStoreReference(_tlObject, 112, cryptoAmount.map { value in value as NSString })
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.payments {
    static func createStarGiftCollection(peer: Api.InputPeer, title: String, stargift: [Api.InputSavedStarGift]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.StarGiftCollection>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(624))
        tlStoreReference(_tlObject, 24, peer.tlObject)
        tlStoreReference(_tlObject, 32, title as NSString)
        tlStoreReference(_tlObject, 40, stargift.map { item in item.tlObject } as NSArray)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.payments {
    static func deleteStarGiftCollection(peer: Api.InputPeer, collectionId: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(625))
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStore(_tlObject, 24, collectionId)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.payments {
    static func editConnectedStarRefBot(flags: Int32, peer: Api.InputPeer, link: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.payments.ConnectedStarRefBots>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(626))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStoreReference(_tlObject, 40, link as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.payments {
    static func exportInvoice(invoiceMedia: Api.InputMedia) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.payments.ExportedInvoice>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(627))
        tlStoreReference(_tlObject, 24, invoiceMedia.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.payments {
    static func fulfillStarsSubscription(peer: Api.InputPeer, subscriptionId: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(628))
        tlStoreReference(_tlObject, 24, peer.tlObject)
        tlStoreReference(_tlObject, 32, subscriptionId as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.payments {
    static func getBankCardData(number: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.payments.BankCardData>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(629))
        tlStoreReference(_tlObject, 24, number as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.payments {
    static func getConnectedStarRefBot(peer: Api.InputPeer, bot: Api.InputUser) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.payments.ConnectedStarRefBots>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(630))
        tlStoreReference(_tlObject, 24, peer.tlObject)
        tlStoreReference(_tlObject, 32, bot.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.payments {
    static func getConnectedStarRefBots(flags: Int32, peer: Api.InputPeer, offsetDate: Int32?, offsetLink: String?, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.payments.ConnectedStarRefBots>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(631))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 40, peer.tlObject)
        if let _tlValue = offsetDate { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        tlStoreReference(_tlObject, 48, offsetLink.map { value in value as NSString })
        tlStore(_tlObject, 32, limit)
        tlStore(_tlObject, 56, _tlPresent)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.payments {
    static func getCraftStarGifts(giftId: Int64, offset: String, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.payments.SavedStarGifts>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(632))
        tlStore(_tlObject, 32, giftId)
        tlStoreReference(_tlObject, 40, offset as NSString)
        tlStore(_tlObject, 24, limit)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.payments {
    static func getCurrencyRates() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.payments.CurrencyRates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(633))
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.payments {
    static func getGiveawayInfo(peer: Api.InputPeer, msgId: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.payments.GiveawayInfo>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(634))
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStore(_tlObject, 24, msgId)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.payments {
    static func getOnrampAvailability(flags: Int32, provider: String, cryptoCurrency: String, baseCurrency: String?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.OnrampAvailability>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(635))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, provider as NSString)
        tlStoreReference(_tlObject, 40, cryptoCurrency as NSString)
        tlStoreReference(_tlObject, 48, baseCurrency.map { value in value as NSString })
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.payments {
    static func getOnrampBaseCurrencies(provider: String, cryptoCurrency: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[String]>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(636))
        tlStoreReference(_tlObject, 24, provider as NSString)
        tlStoreReference(_tlObject, 32, cryptoCurrency as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.payments {
    static func getOnrampLimits(flags: Int32, provider: String, cryptoCurrency: String, baseCurrency: String, paymentMethod: String?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.OnrampLimits>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(637))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, provider as NSString)
        tlStoreReference(_tlObject, 40, cryptoCurrency as NSString)
        tlStoreReference(_tlObject, 48, baseCurrency as NSString)
        tlStoreReference(_tlObject, 56, paymentMethod.map { value in value as NSString })
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.payments {
    static func getOnrampProviders(flags: Int32, cryptoCurrency: String?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Api.OnrampProviderInfo]>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(638))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, cryptoCurrency.map { value in value as NSString })
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.payments {
    static func getOnrampQuote(flags: Int32, provider: String, cryptoCurrency: String, baseCurrency: String, baseAmount: String?, cryptoAmount: String?, paymentMethod: String?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.OnrampQuote>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(639))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, provider as NSString)
        tlStoreReference(_tlObject, 40, cryptoCurrency as NSString)
        tlStoreReference(_tlObject, 48, baseCurrency as NSString)
        tlStoreReference(_tlObject, 56, baseAmount.map { value in value as NSString })
        tlStoreReference(_tlObject, 64, cryptoAmount.map { value in value as NSString })
        tlStoreReference(_tlObject, 72, paymentMethod.map { value in value as NSString })
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.payments {
    static func getPaymentForm(flags: Int32, invoice: Api.InputInvoice, themeParams: Api.DataJSON?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.payments.PaymentForm>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(640))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, invoice.tlObject)
        tlStoreReference(_tlObject, 40, themeParams?.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.payments {
    static func getPaymentReceipt(peer: Api.InputPeer, msgId: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.payments.PaymentReceipt>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(641))
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStore(_tlObject, 24, msgId)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.payments {
    static func getPremiumGiftCodeOptions(flags: Int32, boostPeer: Api.InputPeer?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Api.PremiumGiftCodeOption]>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(642))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, boostPeer?.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.payments {
    static func getResaleStarGifts(flags: Int32, attributesHash: Int64?, giftId: Int64, attributes: [Api.StarGiftAttributeId]?, offset: String, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.payments.ResaleStarGifts>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(643))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        if let _tlValue = attributesHash { tlStore(_tlObject, 32, _tlValue); _tlPresent |= 1 << 0 }
        tlStore(_tlObject, 40, giftId)
        tlStoreReference(_tlObject, 48, attributes.map { value in value.map { item in item.tlObject } as NSArray })
        tlStoreReference(_tlObject, 56, offset as NSString)
        tlStore(_tlObject, 28, limit)
        tlStore(_tlObject, 64, _tlPresent)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.payments {
    static func getSavedInfo() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.payments.SavedInfo>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(644))
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.payments {
    static func getSavedStarGift(stargift: [Api.InputSavedStarGift]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.payments.SavedStarGifts>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(645))
        tlStoreReference(_tlObject, 24, stargift.map { item in item.tlObject } as NSArray)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.payments {
    static func getSavedStarGifts(flags: Int32, peer: Api.InputPeer, collectionId: Int32?, offset: String, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.payments.SavedStarGifts>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(646))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 40, peer.tlObject)
        if let _tlValue = collectionId { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        tlStoreReference(_tlObject, 48, offset as NSString)
        tlStore(_tlObject, 32, limit)
        tlStore(_tlObject, 56, _tlPresent)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.payments {
    static func getStarGiftActiveAuctions(hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.payments.StarGiftActiveAuctions>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(647))
        tlStore(_tlObject, 24, hash)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.payments {
    static func getStarGiftAuctionAcquiredGifts(giftId: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.payments.StarGiftAuctionAcquiredGifts>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(648))
        tlStore(_tlObject, 24, giftId)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.payments {
    static func getStarGiftAuctionState(auction: Api.InputStarGiftAuction, version: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.payments.StarGiftAuctionState>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(649))
        tlStoreReference(_tlObject, 32, auction.tlObject)
        tlStore(_tlObject, 24, version)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.payments {
    static func getStarGiftCollections(peer: Api.InputPeer, hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.payments.StarGiftCollections>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(650))
        tlStoreReference(_tlObject, 24, peer.tlObject)
        tlStore(_tlObject, 32, hash)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.payments {
    static func getStarGiftUpgradeAttributes(giftId: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.payments.StarGiftUpgradeAttributes>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(651))
        tlStore(_tlObject, 24, giftId)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.payments {
    static func getStarGiftUpgradePreview(giftId: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.payments.StarGiftUpgradePreview>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(652))
        tlStore(_tlObject, 24, giftId)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.payments {
    static func getStarGiftWithdrawalUrl(stargift: Api.InputSavedStarGift, password: Api.InputCheckPasswordSRP) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.payments.StarGiftWithdrawalUrl>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(653))
        tlStoreReference(_tlObject, 24, stargift.tlObject)
        tlStoreReference(_tlObject, 32, password.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.payments {
    static func getStarGifts(hash: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.payments.StarGifts>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(654))
        tlStore(_tlObject, 24, hash)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.payments {
    static func getStarsGiftOptions(flags: Int32, userId: Api.InputUser?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Api.StarsGiftOption]>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(655))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, userId?.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.payments {
    static func getStarsGiveawayOptions() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Api.StarsGiveawayOption]>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(656))
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.payments {
    static func getStarsRevenueAdsAccountUrl(peer: Api.InputPeer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.payments.StarsRevenueAdsAccountUrl>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(657))
        tlStoreReference(_tlObject, 24, peer.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.payments {
    static func getStarsRevenueStats(flags: Int32, peer: Api.InputPeer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.payments.StarsRevenueStats>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(658))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, peer.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.payments {
    static func getStarsRevenueWithdrawalUrl(flags: Int32, peer: Api.InputPeer, amount: Int64?, password: Api.InputCheckPasswordSRP) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.payments.StarsRevenueWithdrawalUrl>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(659))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, peer.tlObject)
        if let _tlValue = amount { tlStore(_tlObject, 40, _tlValue); _tlPresent |= 1 << 0 }
        tlStoreReference(_tlObject, 48, password.tlObject)
        tlStore(_tlObject, 56, _tlPresent)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.payments {
    static func getStarsStatus(flags: Int32, peer: Api.InputPeer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.payments.StarsStatus>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(660))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, peer.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.payments {
    static func getStarsSubscriptions(flags: Int32, peer: Api.InputPeer, offset: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.payments.StarsStatus>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(661))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStoreReference(_tlObject, 40, offset as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.payments {
    static func getStarsTopupOptions() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Api.StarsTopupOption]>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(662))
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.payments {
    static func getStarsTransactions(flags: Int32, subscriptionId: String?, peer: Api.InputPeer, offset: String, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.payments.StarsStatus>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(663))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, subscriptionId.map { value in value as NSString })
        tlStoreReference(_tlObject, 40, peer.tlObject)
        tlStoreReference(_tlObject, 48, offset as NSString)
        tlStore(_tlObject, 28, limit)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.payments {
    static func getStarsTransactionsByID(flags: Int32, peer: Api.InputPeer, id: [Api.InputStarsTransaction]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.payments.StarsStatus>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(664))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStoreReference(_tlObject, 40, id.map { item in item.tlObject } as NSArray)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.payments {
    static func getSuggestedStarRefBots(flags: Int32, peer: Api.InputPeer, offset: String, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.payments.SuggestedStarRefBots>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(665))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStoreReference(_tlObject, 40, offset as NSString)
        tlStore(_tlObject, 28, limit)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.payments {
    static func getUniqueStarGift(slug: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.payments.UniqueStarGift>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(666))
        tlStoreReference(_tlObject, 24, slug as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.payments {
    static func getUniqueStarGiftValueInfo(slug: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.payments.UniqueStarGiftValueInfo>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(667))
        tlStoreReference(_tlObject, 24, slug as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.payments {
    static func launchPrepaidGiveaway(peer: Api.InputPeer, giveawayId: Int64, purpose: Api.InputStorePaymentPurpose) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(668))
        tlStoreReference(_tlObject, 24, peer.tlObject)
        tlStore(_tlObject, 32, giveawayId)
        tlStoreReference(_tlObject, 40, purpose.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.payments {
    static func refundStarsCharge(userId: Api.InputUser, chargeId: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(669))
        tlStoreReference(_tlObject, 24, userId.tlObject)
        tlStoreReference(_tlObject, 32, chargeId as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.payments {
    static func reorderStarGiftCollections(peer: Api.InputPeer, order: [Int32]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(670))
        tlStoreReference(_tlObject, 24, peer.tlObject)
        tlStoreReference(_tlObject, 32, tlPackInt32(order) as NSData)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.payments {
    static func resolveStarGiftOffer(flags: Int32, offerMsgId: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(671))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 28, offerMsgId)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.payments {
    static func saveStarGift(flags: Int32, stargift: Api.InputSavedStarGift) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(672))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, stargift.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.payments {
    static func sendPaymentForm(flags: Int32, formId: Int64, invoice: Api.InputInvoice, requestedInfoId: String?, shippingOptionId: String?, credentials: Api.InputPaymentCredentials, tipAmount: Int64?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.payments.PaymentResult>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(673))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 32, formId)
        tlStoreReference(_tlObject, 40, invoice.tlObject)
        tlStoreReference(_tlObject, 48, requestedInfoId.map { value in value as NSString })
        tlStoreReference(_tlObject, 56, shippingOptionId.map { value in value as NSString })
        tlStoreReference(_tlObject, 64, credentials.tlObject)
        if let _tlValue = tipAmount { tlStore(_tlObject, 72, _tlValue); _tlPresent |= 1 << 0 }
        tlStore(_tlObject, 80, _tlPresent)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.payments {
    static func sendStarGiftOffer(flags: Int32, peer: Api.InputPeer, slug: String, price: Api.StarsAmount, duration: Int32, randomId: Int64, allowPaidStars: Int64?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(674))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStoreReference(_tlObject, 40, slug as NSString)
        tlStoreReference(_tlObject, 48, price.tlObject)
        tlStore(_tlObject, 28, duration)
        tlStore(_tlObject, 56, randomId)
        if let _tlValue = allowPaidStars { tlStore(_tlObject, 64, _tlValue); _tlPresent |= 1 << 0 }
        tlStore(_tlObject, 72, _tlPresent)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.payments {
    static func sendStarsForm(formId: Int64, invoice: Api.InputInvoice) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.payments.PaymentResult>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(675))
        tlStore(_tlObject, 24, formId)
        tlStoreReference(_tlObject, 32, invoice.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.payments {
    static func toggleChatStarGiftNotifications(flags: Int32, peer: Api.InputPeer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(676))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, peer.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.payments {
    static func toggleStarGiftsPinnedToTop(peer: Api.InputPeer, stargift: [Api.InputSavedStarGift]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(677))
        tlStoreReference(_tlObject, 24, peer.tlObject)
        tlStoreReference(_tlObject, 32, stargift.map { item in item.tlObject } as NSArray)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.payments {
    static func transferStarGift(stargift: Api.InputSavedStarGift, toId: Api.InputPeer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(678))
        tlStoreReference(_tlObject, 24, stargift.tlObject)
        tlStoreReference(_tlObject, 32, toId.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.payments {
    static func updateStarGiftCollection(flags: Int32, peer: Api.InputPeer, collectionId: Int32, title: String?, deleteStargift: [Api.InputSavedStarGift]?, addStargift: [Api.InputSavedStarGift]?, order: [Api.InputSavedStarGift]?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.StarGiftCollection>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(679))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStore(_tlObject, 28, collectionId)
        tlStoreReference(_tlObject, 40, title.map { value in value as NSString })
        tlStoreReference(_tlObject, 48, deleteStargift.map { value in value.map { item in item.tlObject } as NSArray })
        tlStoreReference(_tlObject, 56, addStargift.map { value in value.map { item in item.tlObject } as NSArray })
        tlStoreReference(_tlObject, 64, order.map { value in value.map { item in item.tlObject } as NSArray })
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.payments {
    static func updateStarGiftPrice(stargift: Api.InputSavedStarGift, resellAmount: Api.StarsAmount) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(680))
        tlStoreReference(_tlObject, 24, stargift.tlObject)
        tlStoreReference(_tlObject, 32, resellAmount.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.payments {
    static func upgradeStarGift(flags: Int32, stargift: Api.InputSavedStarGift) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(681))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, stargift.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.payments {
    static func validateRequestedInfo(flags: Int32, invoice: Api.InputInvoice, info: Api.PaymentRequestedInfo) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.payments.ValidatedRequestedInfo>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(682))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, invoice.tlObject)
        tlStoreReference(_tlObject, 40, info.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.phone {
    static func acceptCall(peer: Api.InputPhoneCall, gB: Buffer, `protocol`: Api.PhoneCallProtocol) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.phone.PhoneCall>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(683))
        tlStoreReference(_tlObject, 24, peer.tlObject)
        tlStoreReference(_tlObject, 32, gB.makeData() as NSData)
        tlStoreReference(_tlObject, 40, `protocol`.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.phone {
    static func checkGroupCall(call: Api.InputGroupCall, sources: [Int32]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Int32]>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(684))
        tlStoreReference(_tlObject, 24, call.tlObject)
        tlStoreReference(_tlObject, 32, tlPackInt32(sources) as NSData)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.phone {
    static func confirmCall(peer: Api.InputPhoneCall, gA: Buffer, keyFingerprint: Int64, `protocol`: Api.PhoneCallProtocol) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.phone.PhoneCall>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(685))
        tlStoreReference(_tlObject, 24, peer.tlObject)
        tlStoreReference(_tlObject, 32, gA.makeData() as NSData)
        tlStore(_tlObject, 40, keyFingerprint)
        tlStoreReference(_tlObject, 48, `protocol`.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.phone {
    static func createConferenceCall(flags: Int32, randomId: Int32, publicKey: Int256?, block: Buffer?, params: Api.DataJSON?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(686))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 28, randomId)
        if let _tlValue = publicKey { tlStore(_tlObject, 32, TLInt256(_0: _tlValue._0, _1: _tlValue._1, _2: _tlValue._2, _3: _tlValue._3)); _tlPresent |= 1 << 0 }
        tlStoreReference(_tlObject, 64, block.map { value in value.makeData() as NSData })
        tlStoreReference(_tlObject, 72, params?.tlObject)
        tlStore(_tlObject, 80, _tlPresent)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.phone {
    static func createGroupCall(flags: Int32, peer: Api.InputPeer, randomId: Int32, title: String?, scheduleDate: Int32?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(687))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 40, peer.tlObject)
        tlStore(_tlObject, 28, randomId)
        tlStoreReference(_tlObject, 48, title.map { value in value as NSString })
        if let _tlValue = scheduleDate { tlStore(_tlObject, 32, _tlValue); _tlPresent |= 1 << 0 }
        tlStore(_tlObject, 56, _tlPresent)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.phone {
    static func declineConferenceCallInvite(msgId: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(688))
        tlStore(_tlObject, 24, msgId)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.phone {
    static func deleteConferenceCallParticipants(flags: Int32, call: Api.InputGroupCall, ids: [Int64], block: Buffer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(689))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, call.tlObject)
        tlStoreReference(_tlObject, 40, tlPackInt64(ids) as NSData)
        tlStoreReference(_tlObject, 48, block.makeData() as NSData)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.phone {
    static func deleteGroupCallMessages(flags: Int32, call: Api.InputGroupCall, messages: [Int32]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(690))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, call.tlObject)
        tlStoreReference(_tlObject, 40, tlPackInt32(messages) as NSData)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.phone {
    static func deleteGroupCallParticipantMessages(flags: Int32, call: Api.InputGroupCall, participant: Api.InputPeer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(691))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, call.tlObject)
        tlStoreReference(_tlObject, 40, participant.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.phone {
    static func discardCall(flags: Int32, peer: Api.InputPhoneCall, duration: Int32, reason: Api.PhoneCallDiscardReason, connectionId: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(692))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStore(_tlObject, 28, duration)
        tlStoreReference(_tlObject, 40, reason.tlObject)
        tlStore(_tlObject, 48, connectionId)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.phone {
    static func discardGroupCall(call: Api.InputGroupCall) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(693))
        tlStoreReference(_tlObject, 24, call.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.phone {
    static func editGroupCallParticipant(flags: Int32, call: Api.InputGroupCall, participant: Api.InputPeer, muted: Api.Bool?, volume: Int32?, raiseHand: Api.Bool?, videoStopped: Api.Bool?, videoPaused: Api.Bool?, presentationPaused: Api.Bool?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(694))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, call.tlObject)
        tlStoreReference(_tlObject, 40, participant.tlObject)
        tlStoreReference(_tlObject, 48, muted?.tlObject)
        if let _tlValue = volume { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        tlStoreReference(_tlObject, 56, raiseHand?.tlObject)
        tlStoreReference(_tlObject, 64, videoStopped?.tlObject)
        tlStoreReference(_tlObject, 72, videoPaused?.tlObject)
        tlStoreReference(_tlObject, 80, presentationPaused?.tlObject)
        tlStore(_tlObject, 88, _tlPresent)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.phone {
    static func editGroupCallTitle(call: Api.InputGroupCall, title: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(695))
        tlStoreReference(_tlObject, 24, call.tlObject)
        tlStoreReference(_tlObject, 32, title as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.phone {
    static func exportGroupCallInvite(flags: Int32, call: Api.InputGroupCall) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.phone.ExportedGroupCallInvite>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(696))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, call.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.phone {
    static func getCallConfig() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.DataJSON>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(697))
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.phone {
    static func getGroupCall(call: Api.InputGroupCall, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.phone.GroupCall>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(698))
        tlStoreReference(_tlObject, 32, call.tlObject)
        tlStore(_tlObject, 24, limit)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.phone {
    static func getGroupCallChainBlocks(call: Api.InputGroupCall, subChainId: Int32, offset: Int32, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(699))
        tlStoreReference(_tlObject, 40, call.tlObject)
        tlStore(_tlObject, 24, subChainId)
        tlStore(_tlObject, 28, offset)
        tlStore(_tlObject, 32, limit)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.phone {
    static func getGroupCallJoinAs(peer: Api.InputPeer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.phone.JoinAsPeers>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(700))
        tlStoreReference(_tlObject, 24, peer.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.phone {
    static func getGroupCallStars(call: Api.InputGroupCall) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.phone.GroupCallStars>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(701))
        tlStoreReference(_tlObject, 24, call.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.phone {
    static func getGroupCallStreamChannels(call: Api.InputGroupCall) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.phone.GroupCallStreamChannels>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(702))
        tlStoreReference(_tlObject, 24, call.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.phone {
    static func getGroupCallStreamRtmpUrl(flags: Int32, peer: Api.InputPeer, revoke: Api.Bool) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.phone.GroupCallStreamRtmpUrl>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(703))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStoreReference(_tlObject, 40, revoke.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.phone {
    static func getGroupParticipants(call: Api.InputGroupCall, ids: [Api.InputPeer], sources: [Int32], offset: String, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.phone.GroupParticipants>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(704))
        tlStoreReference(_tlObject, 32, call.tlObject)
        tlStoreReference(_tlObject, 40, ids.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 48, tlPackInt32(sources) as NSData)
        tlStoreReference(_tlObject, 56, offset as NSString)
        tlStore(_tlObject, 24, limit)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.phone {
    static func inviteConferenceCallParticipant(flags: Int32, call: Api.InputGroupCall, userId: Api.InputUser) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(705))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, call.tlObject)
        tlStoreReference(_tlObject, 40, userId.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.phone {
    static func inviteToGroupCall(call: Api.InputGroupCall, users: [Api.InputUser]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(706))
        tlStoreReference(_tlObject, 24, call.tlObject)
        tlStoreReference(_tlObject, 32, users.map { item in item.tlObject } as NSArray)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.phone {
    static func joinGroupCall(flags: Int32, call: Api.InputGroupCall, joinAs: Api.InputPeer, inviteHash: String?, publicKey: Int256?, block: Buffer?, params: Api.DataJSON) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(707))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, call.tlObject)
        tlStoreReference(_tlObject, 40, joinAs.tlObject)
        tlStoreReference(_tlObject, 48, inviteHash.map { value in value as NSString })
        if let _tlValue = publicKey { tlStore(_tlObject, 56, TLInt256(_0: _tlValue._0, _1: _tlValue._1, _2: _tlValue._2, _3: _tlValue._3)); _tlPresent |= 1 << 0 }
        tlStoreReference(_tlObject, 88, block.map { value in value.makeData() as NSData })
        tlStoreReference(_tlObject, 96, params.tlObject)
        tlStore(_tlObject, 104, _tlPresent)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.phone {
    static func joinGroupCallPresentation(call: Api.InputGroupCall, params: Api.DataJSON) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(708))
        tlStoreReference(_tlObject, 24, call.tlObject)
        tlStoreReference(_tlObject, 32, params.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.phone {
    static func leaveGroupCall(call: Api.InputGroupCall, source: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(709))
        tlStoreReference(_tlObject, 32, call.tlObject)
        tlStore(_tlObject, 24, source)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.phone {
    static func leaveGroupCallPresentation(call: Api.InputGroupCall) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(710))
        tlStoreReference(_tlObject, 24, call.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.phone {
    static func receivedCall(peer: Api.InputPhoneCall) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(711))
        tlStoreReference(_tlObject, 24, peer.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.phone {
    static func requestCall(flags: Int32, userId: Api.InputUser, randomId: Int32, gAHash: Buffer, `protocol`: Api.PhoneCallProtocol) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.phone.PhoneCall>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(712))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, userId.tlObject)
        tlStore(_tlObject, 28, randomId)
        tlStoreReference(_tlObject, 40, gAHash.makeData() as NSData)
        tlStoreReference(_tlObject, 48, `protocol`.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.phone {
    static func saveCallDebug(peer: Api.InputPhoneCall, debug: Api.DataJSON) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(713))
        tlStoreReference(_tlObject, 24, peer.tlObject)
        tlStoreReference(_tlObject, 32, debug.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.phone {
    static func saveCallLog(peer: Api.InputPhoneCall, file: Api.InputFile) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(714))
        tlStoreReference(_tlObject, 24, peer.tlObject)
        tlStoreReference(_tlObject, 32, file.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.phone {
    static func saveDefaultGroupCallJoinAs(peer: Api.InputPeer, joinAs: Api.InputPeer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(715))
        tlStoreReference(_tlObject, 24, peer.tlObject)
        tlStoreReference(_tlObject, 32, joinAs.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.phone {
    static func saveDefaultSendAs(call: Api.InputGroupCall, sendAs: Api.InputPeer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(716))
        tlStoreReference(_tlObject, 24, call.tlObject)
        tlStoreReference(_tlObject, 32, sendAs.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.phone {
    static func sendConferenceCallBroadcast(call: Api.InputGroupCall, block: Buffer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(717))
        tlStoreReference(_tlObject, 24, call.tlObject)
        tlStoreReference(_tlObject, 32, block.makeData() as NSData)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.phone {
    static func sendGroupCallEncryptedMessage(call: Api.InputGroupCall, encryptedMessage: Buffer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(718))
        tlStoreReference(_tlObject, 24, call.tlObject)
        tlStoreReference(_tlObject, 32, encryptedMessage.makeData() as NSData)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.phone {
    static func sendGroupCallMessage(flags: Int32, call: Api.InputGroupCall, randomId: Int64, message: Api.TextWithEntities, allowPaidStars: Int64?, sendAs: Api.InputPeer?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(719))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, call.tlObject)
        tlStore(_tlObject, 40, randomId)
        tlStoreReference(_tlObject, 48, message.tlObject)
        if let _tlValue = allowPaidStars { tlStore(_tlObject, 56, _tlValue); _tlPresent |= 1 << 0 }
        tlStoreReference(_tlObject, 64, sendAs?.tlObject)
        tlStore(_tlObject, 72, _tlPresent)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.phone {
    static func sendSignalingData(peer: Api.InputPhoneCall, data: Buffer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(720))
        tlStoreReference(_tlObject, 24, peer.tlObject)
        tlStoreReference(_tlObject, 32, data.makeData() as NSData)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.phone {
    static func setCallRating(flags: Int32, peer: Api.InputPhoneCall, rating: Int32, comment: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(721))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStore(_tlObject, 28, rating)
        tlStoreReference(_tlObject, 40, comment as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.phone {
    static func startScheduledGroupCall(call: Api.InputGroupCall) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(722))
        tlStoreReference(_tlObject, 24, call.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.phone {
    static func toggleGroupCallRecord(flags: Int32, call: Api.InputGroupCall, title: String?, videoPortrait: Api.Bool?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(723))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, call.tlObject)
        tlStoreReference(_tlObject, 40, title.map { value in value as NSString })
        tlStoreReference(_tlObject, 48, videoPortrait?.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.phone {
    static func toggleGroupCallSettings(flags: Int32, call: Api.InputGroupCall, joinMuted: Api.Bool?, messagesEnabled: Api.Bool?, sendPaidMessagesStars: Int64?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(724))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, call.tlObject)
        tlStoreReference(_tlObject, 40, joinMuted?.tlObject)
        tlStoreReference(_tlObject, 48, messagesEnabled?.tlObject)
        if let _tlValue = sendPaidMessagesStars { tlStore(_tlObject, 56, _tlValue); _tlPresent |= 1 << 0 }
        tlStore(_tlObject, 64, _tlPresent)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.phone {
    static func toggleGroupCallStartSubscription(call: Api.InputGroupCall, subscribed: Api.Bool) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(725))
        tlStoreReference(_tlObject, 24, call.tlObject)
        tlStoreReference(_tlObject, 32, subscribed.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.photos {
    static func deletePhotos(id: [Api.InputPhoto]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Int64]>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(726))
        tlStoreReference(_tlObject, 24, id.map { item in item.tlObject } as NSArray)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.photos {
    static func getUserPhotos(userId: Api.InputUser, offset: Int32, maxId: Int64, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.photos.Photos>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(727))
        tlStoreReference(_tlObject, 32, userId.tlObject)
        tlStore(_tlObject, 24, offset)
        tlStore(_tlObject, 40, maxId)
        tlStore(_tlObject, 28, limit)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.photos {
    static func updateProfilePhoto(flags: Int32, bot: Api.InputUser?, id: Api.InputPhoto) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.photos.Photo>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(728))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, bot?.tlObject)
        tlStoreReference(_tlObject, 40, id.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.photos {
    static func uploadContactProfilePhoto(flags: Int32, userId: Api.InputUser, file: Api.InputFile?, video: Api.InputFile?, videoStartTs: Double?, videoEmojiMarkup: Api.VideoSize?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.photos.Photo>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(729))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, userId.tlObject)
        tlStoreReference(_tlObject, 40, file?.tlObject)
        tlStoreReference(_tlObject, 48, video?.tlObject)
        if let _tlValue = videoStartTs { tlStore(_tlObject, 56, _tlValue); _tlPresent |= 1 << 0 }
        tlStoreReference(_tlObject, 64, videoEmojiMarkup?.tlObject)
        tlStore(_tlObject, 72, _tlPresent)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.photos {
    static func uploadProfilePhoto(flags: Int32, bot: Api.InputUser?, file: Api.InputFile?, video: Api.InputFile?, videoStartTs: Double?, videoEmojiMarkup: Api.VideoSize?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.photos.Photo>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(730))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, bot?.tlObject)
        tlStoreReference(_tlObject, 40, file?.tlObject)
        tlStoreReference(_tlObject, 48, video?.tlObject)
        if let _tlValue = videoStartTs { tlStore(_tlObject, 56, _tlValue); _tlPresent |= 1 << 0 }
        tlStoreReference(_tlObject, 64, videoEmojiMarkup?.tlObject)
        tlStore(_tlObject, 72, _tlPresent)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.premium {
    static func applyBoost(flags: Int32, slots: [Int32]?, peer: Api.InputPeer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.premium.MyBoosts>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(731))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, slots.map { value in tlPackInt32(value) as NSData })
        tlStoreReference(_tlObject, 40, peer.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.premium {
    static func getBoostsList(flags: Int32, peer: Api.InputPeer, offset: String, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.premium.BoostsList>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(732))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStoreReference(_tlObject, 40, offset as NSString)
        tlStore(_tlObject, 28, limit)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.premium {
    static func getBoostsStatus(peer: Api.InputPeer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.premium.BoostsStatus>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(733))
        tlStoreReference(_tlObject, 24, peer.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.premium {
    static func getMyBoosts() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.premium.MyBoosts>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(734))
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.premium {
    static func getUserBoosts(peer: Api.InputPeer, userId: Api.InputUser) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.premium.BoostsList>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(735))
        tlStoreReference(_tlObject, 24, peer.tlObject)
        tlStoreReference(_tlObject, 32, userId.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.smsjobs {
    static func finishJob(flags: Int32, jobId: String, error: String?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(736))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, jobId as NSString)
        tlStoreReference(_tlObject, 40, error.map { value in value as NSString })
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.smsjobs {
    static func getSmsJob(jobId: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.SmsJob>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(737))
        tlStoreReference(_tlObject, 24, jobId as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.smsjobs {
    static func getStatus() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.smsjobs.Status>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(738))
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.smsjobs {
    static func isEligibleToJoin() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.smsjobs.EligibilityToJoin>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(739))
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.smsjobs {
    static func join() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(740))
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.smsjobs {
    static func leave() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(741))
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.smsjobs {
    static func updateSettings(flags: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(742))
        tlStore(_tlObject, 24, flags)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.stats {
    static func getBroadcastStats(flags: Int32, channel: Api.InputChannel) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.stats.BroadcastStats>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(743))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, channel.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.stats {
    static func getMegagroupStats(flags: Int32, channel: Api.InputChannel) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.stats.MegagroupStats>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(744))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, channel.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.stats {
    static func getMessagePublicForwards(channel: Api.InputChannel, msgId: Int32, offset: String, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.stats.PublicForwards>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(745))
        tlStoreReference(_tlObject, 32, channel.tlObject)
        tlStore(_tlObject, 24, msgId)
        tlStoreReference(_tlObject, 40, offset as NSString)
        tlStore(_tlObject, 28, limit)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.stats {
    static func getMessageStats(flags: Int32, channel: Api.InputChannel, msgId: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.stats.MessageStats>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(746))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, channel.tlObject)
        tlStore(_tlObject, 28, msgId)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.stats {
    static func getPollStats(flags: Int32, peer: Api.InputPeer, msgId: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.stats.PollStats>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(747))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStore(_tlObject, 28, msgId)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.stats {
    static func getStoryPublicForwards(peer: Api.InputPeer, id: Int32, offset: String, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.stats.PublicForwards>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(748))
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStore(_tlObject, 24, id)
        tlStoreReference(_tlObject, 40, offset as NSString)
        tlStore(_tlObject, 28, limit)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.stats {
    static func getStoryStats(flags: Int32, peer: Api.InputPeer, id: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.stats.StoryStats>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(749))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStore(_tlObject, 28, id)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.stats {
    static func loadAsyncGraph(flags: Int32, token: String, x: Int64?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.StatsGraph>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(750))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, token as NSString)
        if let _tlValue = x { tlStore(_tlObject, 40, _tlValue); _tlPresent |= 1 << 0 }
        tlStore(_tlObject, 48, _tlPresent)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.stickers {
    static func addStickerToSet(stickerset: Api.InputStickerSet, sticker: Api.InputStickerSetItem) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.StickerSet>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(751))
        tlStoreReference(_tlObject, 24, stickerset.tlObject)
        tlStoreReference(_tlObject, 32, sticker.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.stickers {
    static func changeSticker(flags: Int32, sticker: Api.InputDocument, emoji: String?, maskCoords: Api.MaskCoords?, keywords: String?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.StickerSet>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(752))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, sticker.tlObject)
        tlStoreReference(_tlObject, 40, emoji.map { value in value as NSString })
        tlStoreReference(_tlObject, 48, maskCoords?.tlObject)
        tlStoreReference(_tlObject, 56, keywords.map { value in value as NSString })
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.stickers {
    static func changeStickerPosition(sticker: Api.InputDocument, position: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.StickerSet>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(753))
        tlStoreReference(_tlObject, 32, sticker.tlObject)
        tlStore(_tlObject, 24, position)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.stickers {
    static func checkShortName(shortName: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(754))
        tlStoreReference(_tlObject, 24, shortName as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.stickers {
    static func createStickerSet(flags: Int32, userId: Api.InputUser, title: String, shortName: String, thumb: Api.InputDocument?, stickers: [Api.InputStickerSetItem], software: String?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.StickerSet>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(755))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, userId.tlObject)
        tlStoreReference(_tlObject, 40, title as NSString)
        tlStoreReference(_tlObject, 48, shortName as NSString)
        tlStoreReference(_tlObject, 56, thumb?.tlObject)
        tlStoreReference(_tlObject, 64, stickers.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 72, software.map { value in value as NSString })
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.stickers {
    static func deleteStickerSet(stickerset: Api.InputStickerSet) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(756))
        tlStoreReference(_tlObject, 24, stickerset.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.stickers {
    static func removeStickerFromSet(sticker: Api.InputDocument) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.StickerSet>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(757))
        tlStoreReference(_tlObject, 24, sticker.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.stickers {
    static func renameStickerSet(stickerset: Api.InputStickerSet, title: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.StickerSet>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(758))
        tlStoreReference(_tlObject, 24, stickerset.tlObject)
        tlStoreReference(_tlObject, 32, title as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.stickers {
    static func replaceSticker(sticker: Api.InputDocument, newSticker: Api.InputStickerSetItem) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.StickerSet>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(759))
        tlStoreReference(_tlObject, 24, sticker.tlObject)
        tlStoreReference(_tlObject, 32, newSticker.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.stickers {
    static func setStickerSetThumb(flags: Int32, stickerset: Api.InputStickerSet, thumb: Api.InputDocument?, thumbDocumentId: Int64?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.StickerSet>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(760))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, stickerset.tlObject)
        tlStoreReference(_tlObject, 40, thumb?.tlObject)
        if let _tlValue = thumbDocumentId { tlStore(_tlObject, 48, _tlValue); _tlPresent |= 1 << 0 }
        tlStore(_tlObject, 56, _tlPresent)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.stickers {
    static func suggestShortName(title: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.stickers.SuggestedShortName>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(761))
        tlStoreReference(_tlObject, 24, title as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.stories {
    static func activateStealthMode(flags: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(762))
        tlStore(_tlObject, 24, flags)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.stories {
    static func canSendStory(peer: Api.InputPeer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.stories.CanSendStoryCount>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(763))
        tlStoreReference(_tlObject, 24, peer.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.stories {
    static func createAlbum(peer: Api.InputPeer, title: String, stories: [Int32]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.StoryAlbum>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(764))
        tlStoreReference(_tlObject, 24, peer.tlObject)
        tlStoreReference(_tlObject, 32, title as NSString)
        tlStoreReference(_tlObject, 40, tlPackInt32(stories) as NSData)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.stories {
    static func deleteAlbum(peer: Api.InputPeer, albumId: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(765))
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStore(_tlObject, 24, albumId)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.stories {
    static func deleteStories(peer: Api.InputPeer, id: [Int32]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Int32]>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(766))
        tlStoreReference(_tlObject, 24, peer.tlObject)
        tlStoreReference(_tlObject, 32, tlPackInt32(id) as NSData)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.stories {
    static func editStory(flags: Int32, peer: Api.InputPeer, id: Int32, media: Api.InputMedia?, mediaAreas: [Api.MediaArea]?, caption: String?, entities: [Api.MessageEntity]?, privacyRules: [Api.InputPrivacyRule]?, music: Api.InputDocument?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(767))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStore(_tlObject, 28, id)
        tlStoreReference(_tlObject, 40, media?.tlObject)
        tlStoreReference(_tlObject, 48, mediaAreas.map { value in value.map { item in item.tlObject } as NSArray })
        tlStoreReference(_tlObject, 56, caption.map { value in value as NSString })
        tlStoreReference(_tlObject, 64, entities.map { value in value.map { item in item.tlObject } as NSArray })
        tlStoreReference(_tlObject, 72, privacyRules.map { value in value.map { item in item.tlObject } as NSArray })
        tlStoreReference(_tlObject, 80, music?.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.stories {
    static func exportStoryLink(peer: Api.InputPeer, id: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.ExportedStoryLink>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(768))
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStore(_tlObject, 24, id)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.stories {
    static func getAlbumStories(peer: Api.InputPeer, albumId: Int32, offset: Int32, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.stories.Stories>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(769))
        tlStoreReference(_tlObject, 40, peer.tlObject)
        tlStore(_tlObject, 24, albumId)
        tlStore(_tlObject, 28, offset)
        tlStore(_tlObject, 32, limit)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.stories {
    static func getAlbums(peer: Api.InputPeer, hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.stories.Albums>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(770))
        tlStoreReference(_tlObject, 24, peer.tlObject)
        tlStore(_tlObject, 32, hash)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.stories {
    static func getAllReadPeerStories() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(771))
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.stories {
    static func getAllStories(flags: Int32, state: String?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.stories.AllStories>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(772))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, state.map { value in value as NSString })
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.stories {
    static func getChatsToSend() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.messages.Chats>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(773))
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.stories {
    static func getPeerMaxIDs(id: [Api.InputPeer]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Api.RecentStory]>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(774))
        tlStoreReference(_tlObject, 24, id.map { item in item.tlObject } as NSArray)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.stories {
    static func getPeerStories(peer: Api.InputPeer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.stories.PeerStories>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(775))
        tlStoreReference(_tlObject, 24, peer.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.stories {
    static func getPinnedStories(peer: Api.InputPeer, offsetId: Int32, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.stories.Stories>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(776))
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStore(_tlObject, 24, offsetId)
        tlStore(_tlObject, 28, limit)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.stories {
    static func getStoriesArchive(peer: Api.InputPeer, offsetId: Int32, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.stories.Stories>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(777))
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStore(_tlObject, 24, offsetId)
        tlStore(_tlObject, 28, limit)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.stories {
    static func getStoriesByID(peer: Api.InputPeer, id: [Int32]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.stories.Stories>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(778))
        tlStoreReference(_tlObject, 24, peer.tlObject)
        tlStoreReference(_tlObject, 32, tlPackInt32(id) as NSData)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.stories {
    static func getStoriesViews(peer: Api.InputPeer, id: [Int32]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.stories.StoryViews>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(779))
        tlStoreReference(_tlObject, 24, peer.tlObject)
        tlStoreReference(_tlObject, 32, tlPackInt32(id) as NSData)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.stories {
    static func getStoryReactionsList(flags: Int32, peer: Api.InputPeer, id: Int32, reaction: Api.Reaction?, offset: String?, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.stories.StoryReactionsList>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(780))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 40, peer.tlObject)
        tlStore(_tlObject, 28, id)
        tlStoreReference(_tlObject, 48, reaction?.tlObject)
        tlStoreReference(_tlObject, 56, offset.map { value in value as NSString })
        tlStore(_tlObject, 32, limit)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.stories {
    static func getStoryViewsList(flags: Int32, peer: Api.InputPeer, q: String?, id: Int32, offset: String, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.stories.StoryViewsList>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(781))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 40, peer.tlObject)
        tlStoreReference(_tlObject, 48, q.map { value in value as NSString })
        tlStore(_tlObject, 28, id)
        tlStoreReference(_tlObject, 56, offset as NSString)
        tlStore(_tlObject, 32, limit)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.stories {
    static func incrementStoryViews(peer: Api.InputPeer, id: [Int32]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(782))
        tlStoreReference(_tlObject, 24, peer.tlObject)
        tlStoreReference(_tlObject, 32, tlPackInt32(id) as NSData)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.stories {
    static func readStories(peer: Api.InputPeer, maxId: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Int32]>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(783))
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStore(_tlObject, 24, maxId)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.stories {
    static func reorderAlbums(peer: Api.InputPeer, order: [Int32]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(784))
        tlStoreReference(_tlObject, 24, peer.tlObject)
        tlStoreReference(_tlObject, 32, tlPackInt32(order) as NSData)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.stories {
    static func report(peer: Api.InputPeer, id: [Int32], option: Buffer, message: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.ReportResult>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(785))
        tlStoreReference(_tlObject, 24, peer.tlObject)
        tlStoreReference(_tlObject, 32, tlPackInt32(id) as NSData)
        tlStoreReference(_tlObject, 40, option.makeData() as NSData)
        tlStoreReference(_tlObject, 48, message as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.stories {
    static func searchPosts(flags: Int32, hashtag: String?, area: Api.MediaArea?, peer: Api.InputPeer?, offset: String, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.stories.FoundStories>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(786))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, hashtag.map { value in value as NSString })
        tlStoreReference(_tlObject, 40, area?.tlObject)
        tlStoreReference(_tlObject, 48, peer?.tlObject)
        tlStoreReference(_tlObject, 56, offset as NSString)
        tlStore(_tlObject, 28, limit)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.stories {
    static func sendReaction(flags: Int32, peer: Api.InputPeer, storyId: Int32, reaction: Api.Reaction) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(787))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStore(_tlObject, 28, storyId)
        tlStoreReference(_tlObject, 40, reaction.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.stories {
    static func sendStory(flags: Int32, peer: Api.InputPeer, media: Api.InputMedia, mediaAreas: [Api.MediaArea]?, caption: String?, entities: [Api.MessageEntity]?, privacyRules: [Api.InputPrivacyRule], randomId: Int64, period: Int32?, fwdFromId: Api.InputPeer?, fwdFromStory: Int32?, albums: [Int32]?, music: Api.InputDocument?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(788))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 40, peer.tlObject)
        tlStoreReference(_tlObject, 48, media.tlObject)
        tlStoreReference(_tlObject, 56, mediaAreas.map { value in value.map { item in item.tlObject } as NSArray })
        tlStoreReference(_tlObject, 64, caption.map { value in value as NSString })
        tlStoreReference(_tlObject, 72, entities.map { value in value.map { item in item.tlObject } as NSArray })
        tlStoreReference(_tlObject, 80, privacyRules.map { item in item.tlObject } as NSArray)
        tlStore(_tlObject, 88, randomId)
        if let _tlValue = period { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        tlStoreReference(_tlObject, 96, fwdFromId?.tlObject)
        if let _tlValue = fwdFromStory { tlStore(_tlObject, 32, _tlValue); _tlPresent |= 1 << 1 }
        tlStoreReference(_tlObject, 104, albums.map { value in tlPackInt32(value) as NSData })
        tlStoreReference(_tlObject, 112, music?.tlObject)
        tlStore(_tlObject, 120, _tlPresent)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.stories {
    static func startLive(flags: Int32, peer: Api.InputPeer, caption: String?, entities: [Api.MessageEntity]?, privacyRules: [Api.InputPrivacyRule], randomId: Int64, messagesEnabled: Api.Bool?, sendPaidMessagesStars: Int64?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(789))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStoreReference(_tlObject, 40, caption.map { value in value as NSString })
        tlStoreReference(_tlObject, 48, entities.map { value in value.map { item in item.tlObject } as NSArray })
        tlStoreReference(_tlObject, 56, privacyRules.map { item in item.tlObject } as NSArray)
        tlStore(_tlObject, 64, randomId)
        tlStoreReference(_tlObject, 72, messagesEnabled?.tlObject)
        if let _tlValue = sendPaidMessagesStars { tlStore(_tlObject, 80, _tlValue); _tlPresent |= 1 << 0 }
        tlStore(_tlObject, 88, _tlPresent)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.stories {
    static func toggleAllStoriesHidden(hidden: Api.Bool) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(790))
        tlStoreReference(_tlObject, 24, hidden.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.stories {
    static func togglePeerStoriesHidden(peer: Api.InputPeer, hidden: Api.Bool) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(791))
        tlStoreReference(_tlObject, 24, peer.tlObject)
        tlStoreReference(_tlObject, 32, hidden.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.stories {
    static func togglePinned(peer: Api.InputPeer, id: [Int32], pinned: Api.Bool) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Int32]>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(792))
        tlStoreReference(_tlObject, 24, peer.tlObject)
        tlStoreReference(_tlObject, 32, tlPackInt32(id) as NSData)
        tlStoreReference(_tlObject, 40, pinned.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.stories {
    static func togglePinnedToTop(peer: Api.InputPeer, id: [Int32]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(793))
        tlStoreReference(_tlObject, 24, peer.tlObject)
        tlStoreReference(_tlObject, 32, tlPackInt32(id) as NSData)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.stories {
    static func updateAlbum(flags: Int32, peer: Api.InputPeer, albumId: Int32, title: String?, deleteStories: [Int32]?, addStories: [Int32]?, order: [Int32]?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.StoryAlbum>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(794))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStore(_tlObject, 28, albumId)
        tlStoreReference(_tlObject, 40, title.map { value in value as NSString })
        tlStoreReference(_tlObject, 48, deleteStories.map { value in tlPackInt32(value) as NSData })
        tlStoreReference(_tlObject, 56, addStories.map { value in tlPackInt32(value) as NSData })
        tlStoreReference(_tlObject, 64, order.map { value in tlPackInt32(value) as NSData })
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.toncenter {
    static func getStreamingUrl() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.toncenter.StreamingUrl>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(795))
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.toncenter {
    static func performApiRequest(flags: Int32, endpoint: String, query: String?, payload: String?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.toncenter.ApiResponse>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(796))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, endpoint as NSString)
        tlStoreReference(_tlObject, 40, query.map { value in value as NSString })
        tlStoreReference(_tlObject, 48, payload.map { value in value as NSString })
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.updates {
    static func getChannelDifference(flags: Int32, channel: Api.InputChannel, filter: Api.ChannelMessagesFilter, pts: Int32, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.updates.ChannelDifference>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(797))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 40, channel.tlObject)
        tlStoreReference(_tlObject, 48, filter.tlObject)
        tlStore(_tlObject, 28, pts)
        tlStore(_tlObject, 32, limit)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.updates {
    static func getDifference(flags: Int32, pts: Int32, ptsLimit: Int32?, ptsTotalLimit: Int32?, date: Int32, qts: Int32, qtsLimit: Int32?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.updates.Difference>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(798))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 28, pts)
        if let _tlValue = ptsLimit { tlStore(_tlObject, 32, _tlValue); _tlPresent |= 1 << 0 }
        if let _tlValue = ptsTotalLimit { tlStore(_tlObject, 36, _tlValue); _tlPresent |= 1 << 1 }
        tlStore(_tlObject, 40, date)
        tlStore(_tlObject, 44, qts)
        if let _tlValue = qtsLimit { tlStore(_tlObject, 48, _tlValue); _tlPresent |= 1 << 2 }
        tlStore(_tlObject, 56, _tlPresent)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.updates {
    static func getState() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.updates.State>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(799))
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.upload {
    static func getCdnFile(fileToken: Buffer, offset: Int64, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.upload.CdnFile>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(800))
        tlStoreReference(_tlObject, 32, fileToken.makeData() as NSData)
        tlStore(_tlObject, 40, offset)
        tlStore(_tlObject, 24, limit)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.upload {
    static func getCdnFileHashes(fileToken: Buffer, offset: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Api.FileHash]>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(801))
        tlStoreReference(_tlObject, 24, fileToken.makeData() as NSData)
        tlStore(_tlObject, 32, offset)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.upload {
    static func getFile(flags: Int32, location: Api.InputFileLocation, offset: Int64, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.upload.File>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(802))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, location.tlObject)
        tlStore(_tlObject, 40, offset)
        tlStore(_tlObject, 28, limit)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.upload {
    static func getFileHashes(location: Api.InputFileLocation, offset: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Api.FileHash]>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(803))
        tlStoreReference(_tlObject, 24, location.tlObject)
        tlStore(_tlObject, 32, offset)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.upload {
    static func getWebFile(location: Api.InputWebFileLocation, offset: Int32, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.upload.WebFile>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(804))
        tlStoreReference(_tlObject, 32, location.tlObject)
        tlStore(_tlObject, 24, offset)
        tlStore(_tlObject, 28, limit)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.upload {
    static func reuploadCdnFile(fileToken: Buffer, requestToken: Buffer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Api.FileHash]>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(805))
        tlStoreReference(_tlObject, 24, fileToken.makeData() as NSData)
        tlStoreReference(_tlObject, 32, requestToken.makeData() as NSData)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.upload {
    static func saveBigFilePart(fileId: Int64, filePart: Int32, fileTotalParts: Int32, bytes: Buffer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(806))
        tlStore(_tlObject, 32, fileId)
        tlStore(_tlObject, 24, filePart)
        tlStore(_tlObject, 28, fileTotalParts)
        tlStoreReference(_tlObject, 40, bytes.makeData() as NSData)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.upload {
    static func saveFilePart(fileId: Int64, filePart: Int32, bytes: Buffer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(807))
        tlStore(_tlObject, 32, fileId)
        tlStore(_tlObject, 24, filePart)
        tlStoreReference(_tlObject, 40, bytes.makeData() as NSData)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.users {
    static func getFullUser(id: Api.InputUser) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.users.UserFull>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(808))
        tlStoreReference(_tlObject, 24, id.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.users {
    static func getRequirementsToContact(id: [Api.InputUser]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Api.RequirementToContact]>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(809))
        tlStoreReference(_tlObject, 24, id.map { item in item.tlObject } as NSArray)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.users {
    static func getSavedMusic(id: Api.InputUser, offset: Int32, limit: Int32, hash: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.users.SavedMusic>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(810))
        tlStoreReference(_tlObject, 32, id.tlObject)
        tlStore(_tlObject, 24, offset)
        tlStore(_tlObject, 28, limit)
        tlStore(_tlObject, 40, hash)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.users {
    static func getSavedMusicByID(id: Api.InputUser, documents: [Api.InputDocument]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.users.SavedMusic>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(811))
        tlStoreReference(_tlObject, 24, id.tlObject)
        tlStoreReference(_tlObject, 32, documents.map { item in item.tlObject } as NSArray)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.users {
    static func getUsers(id: [Api.InputUser]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Api.User]>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(812))
        tlStoreReference(_tlObject, 24, id.map { item in item.tlObject } as NSArray)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.users {
    static func setSecureValueErrors(id: Api.InputUser, errors: [Api.SecureValueError]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(813))
        tlStoreReference(_tlObject, 24, id.tlObject)
        tlStoreReference(_tlObject, 32, errors.map { item in item.tlObject } as NSArray)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.users {
    static func suggestBirthday(id: Api.InputUser, birthday: Api.Birthday) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(814))
        tlStoreReference(_tlObject, 24, id.tlObject)
        tlStoreReference(_tlObject, 32, birthday.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.wallet {
    static func disableBackup(flags: Int32, password: Api.InputCheckPasswordSRP?, newPublicKey: Buffer?, proof: Api.WalletOwnershipProof?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.WalletState>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(815))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, password?.tlObject)
        tlStoreReference(_tlObject, 40, newPublicKey.map { value in value.makeData() as NSData })
        tlStoreReference(_tlObject, 48, proof?.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.wallet {
    static func enableBackup(flags: Int32, parts: [Buffer], newPublicKey: Buffer?, proof: Api.WalletOwnershipProof?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.WalletState>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(816))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, parts.map { item in item.makeData() } as NSArray)
        tlStoreReference(_tlObject, 40, newPublicKey.map { value in value.makeData() as NSData })
        tlStoreReference(_tlObject, 48, proof?.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.wallet {
    static func exportSecretPhrase(flags: Int32, password: Api.InputCheckPasswordSRP?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.wallet.SecretPhraseParts>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(817))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, password?.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.wallet {
    static func fetchEncryptedSecretPhrasePart(token: String, publicKey: Buffer) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.wallet.EncryptedSecretPhrasePart>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(818))
        tlStoreReference(_tlObject, 24, token as NSString)
        tlStoreReference(_tlObject, 32, publicKey.makeData() as NSData)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.wallet {
    static func getBackupHolderDcs() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Api.wallet.HolderDc]>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(819))
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.wallet {
    static func getExistingWaltBalance() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.wallet.ExistingBalance>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(820))
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.wallet {
    static func getGaslessInfo() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(821))
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.wallet {
    static func getNfts(offset: String, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.wallet.NftItems>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(822))
        tlStoreReference(_tlObject, 32, offset as NSString)
        tlStore(_tlObject, 24, limit)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.wallet {
    static func getProofChallenge() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.wallet.ProofChallenge>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(823))
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.wallet {
    static func getState() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.WalletState>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(824))
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.wallet {
    static func getTransactions(flags: Int32, offset: String, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.wallet.Transactions>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(825))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, offset as NSString)
        tlStore(_tlObject, 28, limit)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.wallet {
    static func getTransactionsByIDs(id: [String]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.wallet.Transactions>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(826))
        tlStoreReference(_tlObject, 24, id as NSArray)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.wallet {
    static func getTransactionsByMsgHash(msgHash: [String]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.wallet.Transactions>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(827))
        tlStoreReference(_tlObject, 24, msgHash as NSArray)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.wallet {
    static func getUserAddresses(flags: Int32, id: [Api.InputUser], addresses: [String]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.wallet.UserAddresses>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(828))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, id.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 40, addresses as NSArray)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.wallet {
    static func replaceWallet(flags: Int32, wallet: Api.InputWalletReplacement, password: Api.InputCheckPasswordSRP?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.WalletState>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(829))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, wallet.tlObject)
        tlStoreReference(_tlObject, 40, password?.tlObject)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.wallet {
    static func sendTransfer(flags: Int32, dataNormal: Buffer, dataGasless: Buffer?, userId: Api.InputUser, randomId: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(830))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, dataNormal.makeData() as NSData)
        tlStoreReference(_tlObject, 40, dataGasless.map { value in value.makeData() as NSData })
        tlStoreReference(_tlObject, 48, userId.tlObject)
        tlStore(_tlObject, 56, randomId)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.wallet {
    static func tonConnectClaimRequest(flags: Int32, sessionId: Int64, msgId: Int32, appRequestId: String, challengeAnswer: Buffer?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(831))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 32, sessionId)
        tlStore(_tlObject, 28, msgId)
        tlStoreReference(_tlObject, 40, appRequestId as NSString)
        tlStoreReference(_tlObject, 48, challengeAnswer.map { value in value.makeData() as NSData })
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.wallet {
    static func tonConnectCloseSession(flags: Int32, sessionId: Int64, body: Buffer?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(832))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 32, sessionId)
        tlStoreReference(_tlObject, 40, body.map { value in value.makeData() as NSData })
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.wallet {
    static func tonConnectCreateSession(dappClientId: String, manifestUrl: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.TonConnectSession>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(833))
        tlStoreReference(_tlObject, 24, dappClientId as NSString)
        tlStoreReference(_tlObject, 32, manifestUrl as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.wallet {
    static func tonConnectGetPending(flags: Int32, dappClientId: String?, sessionId: Int64?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.wallet.TonConnectPending>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(834))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, dappClientId.map { value in value as NSString })
        if let _tlValue = sessionId { tlStore(_tlObject, 40, _tlValue); _tlPresent |= 1 << 0 }
        tlStore(_tlObject, 48, _tlPresent)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.wallet {
    static func tonConnectGetSessions() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.wallet.TonConnectSessions>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(835))
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.wallet {
    static func tonConnectNextEventId(sessionId: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.TonConnectNextEventId>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(836))
        tlStore(_tlObject, 24, sessionId)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.wallet {
    static func tonConnectRegisterKey(sessionId: Int64, clientId: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.wallet.TonConnectChallenge>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(837))
        tlStore(_tlObject, 24, sessionId)
        tlStoreReference(_tlObject, 32, clientId as NSString)
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.wallet {
    static func tonConnectSubmitConnectResult(flags: Int32, sessionId: Int64, challengeAnswer: Buffer, body: Buffer, traceId: String?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(838))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 32, sessionId)
        tlStoreReference(_tlObject, 40, challengeAnswer.makeData() as NSData)
        tlStoreReference(_tlObject, 48, body.makeData() as NSData)
        tlStoreReference(_tlObject, 56, traceId.map { value in value as NSString })
        return tlFunction(_tlObject)
    }
}
public extension Api.functions.wallet {
    static func tonConnectSubmitResponse(flags: Int32, sessionId: Int64, msgId: Int32, body: Buffer, traceId: String?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(839))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 32, sessionId)
        tlStore(_tlObject, 28, msgId)
        tlStoreReference(_tlObject, 40, body.makeData() as NSData)
        tlStoreReference(_tlObject, 48, traceId.map { value in value as NSString })
        return tlFunction(_tlObject)
    }
}
