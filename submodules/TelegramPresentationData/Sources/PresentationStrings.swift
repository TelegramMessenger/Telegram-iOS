import Foundation
import AppBundle
import StringPluralization

private let fallbackDict: [String: String] = {
    guard let mainPath = getAppBundle().path(forResource: "en", ofType: "lproj"), let bundle = Bundle(path: mainPath) else {
        return [:]
    }
    guard let path = bundle.path(forResource: "Localizable", ofType: "strings") else {
        return [:]
    }
    guard let dict = NSDictionary(contentsOf: URL(fileURLWithPath: path)) as? [String: String] else {
        return [:]
    }
    return dict
}()

private extension PluralizationForm {
    var canonicalSuffix: String {
        switch self {
            case .zero:
                return "_0"
            case .one:
                return "_1"
            case .two:
                return "_2"
            case .few:
                return "_3_10"
            case .many:
                return "_many"
            case .other:
                return "_any"
        }
    }
}

public final class PresentationStringsComponent {
    public let languageCode: String
    public let localizedName: String
    public let pluralizationRulesCode: String?
    public let dict: [String: String]
    
    public init(languageCode: String, localizedName: String, pluralizationRulesCode: String?, dict: [String: String]) {
        self.languageCode = languageCode
        self.localizedName = localizedName
        self.pluralizationRulesCode = pluralizationRulesCode
        self.dict = dict
    }
}
        
private func getValue(_ primaryComponent: PresentationStringsComponent, _ secondaryComponent: PresentationStringsComponent?, _ key: String) -> String {
    if let value = primaryComponent.dict[key] {
        return value
    } else if let secondaryComponent = secondaryComponent, let value = secondaryComponent.dict[key] {
        return value
    } else if let value = fallbackDict[key] {
        return value
    } else {
        return key
    }
}

private func getValueWithForm(_ primaryComponent: PresentationStringsComponent, _ secondaryComponent: PresentationStringsComponent?, _ key: String, _ form: PluralizationForm) -> String {
    let builtKey = key + form.canonicalSuffix
    if let value = primaryComponent.dict[builtKey] {
        return value
    } else if let secondaryComponent = secondaryComponent, let value = secondaryComponent.dict[builtKey] {
        return value
    } else if let value = fallbackDict[builtKey] {
        return value
    }
    return key
}
        
private let argumentRegex = try! NSRegularExpression(pattern: "%(((\\d+)\\$)?)([@df])", options: [])
private func extractArgumentRanges(_ value: String) -> [(Int, NSRange)] {
    var result: [(Int, NSRange)] = []
    let string = value as NSString
    let matches = argumentRegex.matches(in: string as String, options: [], range: NSRange(location: 0, length: string.length))
    var index = 0
    for match in matches {
        var currentIndex = index
        if match.range(at: 3).location != NSNotFound {
            currentIndex = Int(string.substring(with: match.range(at: 3)))! - 1
        }
        result.append((currentIndex, match.range(at: 0)))
        index += 1
    }
    result.sort(by: { $0.1.location < $1.1.location })
    return result
}
    
public func formatWithArgumentRanges(_ value: String, _ ranges: [(Int, NSRange)], _ arguments: [String]) -> (String, [(Int, NSRange)]) {
    let string = value as NSString
    
    var resultingRanges: [(Int, NSRange)] = []

    var currentLocation = 0

    let result = NSMutableString()
    for (index, range) in ranges {
        if currentLocation < range.location {
            result.append(string.substring(with: NSRange(location: currentLocation, length: range.location - currentLocation)))
        }
        resultingRanges.append((index, NSRange(location: result.length, length: (arguments[index] as NSString).length)))
        result.append(arguments[index])
        currentLocation = range.location + range.length
    }
    if currentLocation != string.length {
        result.append(string.substring(with: NSRange(location: currentLocation, length: string.length - currentLocation)))
    }
    return (result as String, resultingRanges)
}
        
private final class DataReader {
    private let data: Data
    private var ptr: Int = 0

    init(_ data: Data) {
        self.data = data
    }

    func readInt32() -> Int32 {
        assert(self.ptr + 4 <= self.data.count)
        let result = self.data.withUnsafeBytes { (bytes: UnsafePointer<Int8>) -> Int32 in
            var value: Int32 = 0
            memcpy(&value, bytes.advanced(by: self.ptr), 4)
            return value
        }
        self.ptr += 4
        return result
    }

    func readString() -> String {
        let length = Int(self.readInt32())
        assert(self.ptr + length <= self.data.count)
        let value = String(data: self.data.subdata(in: self.ptr ..< self.ptr + length), encoding: .utf8)!
        self.ptr += length
        return value
    }
}
        
private func loadMapping() -> ([Int], [String], [Int], [Int], [String]) {
    guard let filePath = getAppBundle().path(forResource: "PresentationStrings", ofType: "mapping") else {
        fatalError()
    }
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)) else {
        fatalError()
    }

    let reader = DataReader(data)

    let idCount = Int(reader.readInt32())
    var sIdList: [Int] = []
    var sKeyList: [String] = []
    var sArgIdList: [Int] = []
    for _ in 0 ..< idCount {
        let id = Int(reader.readInt32())
        sIdList.append(id)
        sKeyList.append(reader.readString())
        if reader.readInt32() != 0 {
            sArgIdList.append(id)
        }
    }

    let pCount = Int(reader.readInt32())
    var pIdList: [Int] = []
    var pKeyList: [String] = []
    for _ in 0 ..< Int(pCount) {
        pIdList.append(Int(reader.readInt32()))
        pKeyList.append(reader.readString())
    }

    return (sIdList, sKeyList, sArgIdList, pIdList, pKeyList)
}

private let keyMapping: ([Int], [String], [Int], [Int], [String]) = loadMapping()
        
public final class PresentationStrings: Equatable {
    public let lc: UInt32
    
    public let primaryComponent: PresentationStringsComponent
    public let secondaryComponent: PresentationStringsComponent?
    public let baseLanguageCode: String
    public let groupingSeparator: String
        
    private let _s: [Int: String]
    private let _r: [Int: [(Int, NSRange)]]
    private let _ps: [Int: String]
    public var CallFeedback_ReasonSilentLocal: String { return self._s[0]! }
    public var StickerPack_ShowStickers: String { return self._s[1]! }
    public var Map_PullUpForPlaces: String { return self._s[2]! }
    public var Channel_Status: String { return self._s[4]! }
    public var Wallet_Updated_JustNow: String { return self._s[5]! }
    public var TwoStepAuth_ChangePassword: String { return self._s[6]! }
    public var Map_LiveLocationFor1Hour: String { return self._s[7]! }
    public var CheckoutInfo_ShippingInfoAddress2Placeholder: String { return self._s[8]! }
    public var Settings_AppleWatch: String { return self._s[9]! }
    public var Login_InvalidCountryCode: String { return self._s[10]! }
    public var WebSearch_RecentSectionTitle: String { return self._s[11]! }
    public var UserInfo_DeleteContact: String { return self._s[12]! }
    public var ShareFileTip_CloseTip: String { return self._s[13]! }
    public var UserInfo_Invite: String { return self._s[14]! }
    public var Passport_Identity_MiddleName: String { return self._s[15]! }
    public var Passport_Identity_FrontSideHelp: String { return self._s[16]! }
    public var Month_GenDecember: String { return self._s[18]! }
    public var Common_Yes: String { return self._s[19]! }
    public func EncryptionKey_Description(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[20]!, self._r[20]!, [_1, _2])
    }
    public var Channel_AdminLogFilter_EventsLeaving: String { return self._s[21]! }
    public var WallpaperPreview_PreviewBottomText: String { return self._s[22]! }
    public func Notification_PinnedStickerMessage(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[23]!, self._r[23]!, [_0])
    }
    public var Passport_Address_ScansHelp: String { return self._s[24]! }
    public var FastTwoStepSetup_PasswordHelp: String { return self._s[25]! }
    public var SettingsSearch_Synonyms_Notifications_Title: String { return self._s[26]! }
    public var StickerPacksSettings_AnimatedStickers: String { return self._s[27]! }
    public var Wallet_WordCheck_IncorrectText: String { return self._s[28]! }
    public func Items_NOfM(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[29]!, self._r[29]!, [_1, _2])
    }
    public var AutoDownloadSettings_Files: String { return self._s[30]! }
    public var TextFormat_AddLinkPlaceholder: String { return self._s[31]! }
    public var LastSeen_Lately: String { return self._s[36]! }
    public func PUSH_CHANNEL_MESSAGE_VIDEOS(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[37]!, self._r[37]!, [_1, _2])
    }
    public var Camera_Discard: String { return self._s[38]! }
    public var Channel_EditAdmin_PermissinAddAdminOff: String { return self._s[39]! }
    public var Login_InvalidPhoneError: String { return self._s[41]! }
    public var SettingsSearch_Synonyms_Privacy_AuthSessions: String { return self._s[42]! }
    public var GroupInfo_LabelOwner: String { return self._s[43]! }
    public var Conversation_Moderate_Delete: String { return self._s[44]! }
    public var Conversation_DeleteMessagesForEveryone: String { return self._s[45]! }
    public var WatchRemote_AlertOpen: String { return self._s[46]! }
    public func MediaPicker_Nof(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[47]!, self._r[47]!, [_0])
    }
    public var EditTheme_Expand_Preview_IncomingReplyName: String { return self._s[48]! }
    public var AutoDownloadSettings_MediaTypes: String { return self._s[50]! }
    public var Watch_GroupInfo_Title: String { return self._s[51]! }
    public var Passport_Identity_AddPersonalDetails: String { return self._s[52]! }
    public var Channel_Info_Members: String { return self._s[53]! }
    public var LoginPassword_InvalidPasswordError: String { return self._s[55]! }
    public var Conversation_LiveLocation: String { return self._s[56]! }
    public var Wallet_Month_ShortNovember: String { return self._s[57]! }
    public var PrivacyLastSeenSettings_CustomShareSettingsHelp: String { return self._s[58]! }
    public var NetworkUsageSettings_BytesReceived: String { return self._s[60]! }
    public var Stickers_Search: String { return self._s[62]! }
    public var NotificationsSound_Synth: String { return self._s[63]! }
    public var LogoutOptions_LogOutInfo: String { return self._s[64]! }
    public func VoiceOver_Chat_ForwardedFrom(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[66]!, self._r[66]!, [_0])
    }
    public var NetworkUsageSettings_MediaAudioDataSection: String { return self._s[67]! }
    public var ChatList_Context_HideArchive: String { return self._s[69]! }
    public var AutoNightTheme_UseSunsetSunrise: String { return self._s[70]! }
    public var FastTwoStepSetup_Title: String { return self._s[71]! }
    public var EditTheme_Create_Preview_IncomingReplyText: String { return self._s[72]! }
    public var Channel_Info_BlackList: String { return self._s[73]! }
    public var Channel_AdminLog_InfoPanelTitle: String { return self._s[74]! }
    public var Conversation_OpenFile: String { return self._s[75]! }
    public var SecretTimer_ImageDescription: String { return self._s[76]! }
    public var StickerSettings_ContextInfo: String { return self._s[77]! }
    public var TwoStepAuth_GenericHelp: String { return self._s[79]! }
    public var AutoDownloadSettings_Unlimited: String { return self._s[80]! }
    public var PrivacyLastSeenSettings_NeverShareWith_Title: String { return self._s[81]! }
    public var AutoDownloadSettings_DataUsageHigh: String { return self._s[82]! }
    public func PUSH_CHAT_MESSAGE_VIDEO(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[83]!, self._r[83]!, [_1, _2])
    }
    public var Notifications_AddExceptionTitle: String { return self._s[84]! }
    public var Watch_MessageView_Reply: String { return self._s[85]! }
    public var Tour_Text6: String { return self._s[86]! }
    public var TwoStepAuth_SetupPasswordEnterPasswordChange: String { return self._s[87]! }
    public func Notification_PinnedAnimationMessage(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[88]!, self._r[88]!, [_0])
    }
    public func ShareFileTip_Text(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[89]!, self._r[89]!, [_0])
    }
    public var AccessDenied_LocationDenied: String { return self._s[90]! }
    public var CallSettings_RecentCalls: String { return self._s[91]! }
    public var ConversationProfile_LeaveDeleteAndExit: String { return self._s[92]! }
    public var Channel_Members_AddAdminErrorBlacklisted: String { return self._s[93]! }
    public var Passport_Authorize: String { return self._s[94]! }
    public var StickerPacksSettings_ArchivedMasks_Info: String { return self._s[95]! }
    public var AutoDownloadSettings_Videos: String { return self._s[96]! }
    public var TwoStepAuth_ReEnterPasswordTitle: String { return self._s[97]! }
    public var Wallet_Info_Send: String { return self._s[98]! }
    public var Wallet_TransactionInfo_SendGrams: String { return self._s[99]! }
    public var Tour_StartButton: String { return self._s[100]! }
    public var Watch_AppName: String { return self._s[102]! }
    public var StickerPack_ErrorNotFound: String { return self._s[103]! }
    public var Channel_Info_Subscribers: String { return self._s[104]! }
    public func Channel_AdminLog_MessageGroupPreHistoryVisible(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[105]!, self._r[105]!, [_0])
    }
    public func DialogList_PinLimitError(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[106]!, self._r[106]!, [_0])
    }
    public var Appearance_RemoveTheme: String { return self._s[107]! }
    public func Wallet_Info_TransactionBlockchainFee(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[108]!, self._r[108]!, [_0])
    }
    public var Conversation_StopLiveLocation: String { return self._s[110]! }
    public var Channel_AdminLogFilter_EventsAll: String { return self._s[111]! }
    public var GroupInfo_InviteLink_CopyAlert_Success: String { return self._s[113]! }
    public var Username_LinkCopied: String { return self._s[115]! }
    public var GroupRemoved_Title: String { return self._s[116]! }
    public var SecretVideo_Title: String { return self._s[117]! }
    public func PUSH_PINNED_VIDEO(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[118]!, self._r[118]!, [_1])
    }
    public var AccessDenied_PhotosAndVideos: String { return self._s[119]! }
    public var Appearance_ThemePreview_Chat_1_Text: String { return self._s[120]! }
    public func PUSH_CHANNEL_MESSAGE_GEOLIVE(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[122]!, self._r[122]!, [_1])
    }
    public var Map_OpenInGoogleMaps: String { return self._s[123]! }
    public func Time_PreciseDate_m12(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[124]!, self._r[124]!, [_1, _2, _3])
    }
    public func Channel_AdminLog_MessageKickedNameUsername(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[125]!, self._r[125]!, [_1, _2])
    }
    public var Call_StatusRinging: String { return self._s[126]! }
    public var SettingsSearch_Synonyms_EditProfile_Username: String { return self._s[127]! }
    public var Group_Username_InvalidStartsWithNumber: String { return self._s[128]! }
    public var UserInfo_NotificationsEnabled: String { return self._s[129]! }
    public var Map_Search: String { return self._s[130]! }
    public var Login_TermsOfServiceHeader: String { return self._s[132]! }
    public func Notification_PinnedVideoMessage(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[133]!, self._r[133]!, [_0])
    }
    public func Channel_AdminLog_MessageToggleSignaturesOn(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[134]!, self._r[134]!, [_0])
    }
    public var Wallet_Sent_Title: String { return self._s[135]! }
    public var TwoStepAuth_SetupPasswordConfirmPassword: String { return self._s[136]! }
    public var Weekday_Today: String { return self._s[137]! }
    public func InstantPage_AuthorAndDateTitle(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[139]!, self._r[139]!, [_1, _2])
    }
    public func Conversation_MessageDialogRetryAll(_ _1: Int) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[140]!, self._r[140]!, ["\(_1)"])
    }
    public var Notification_PassportValuePersonalDetails: String { return self._s[142]! }
    public var Channel_AdminLog_MessagePreviousLink: String { return self._s[143]! }
    public var ChangePhoneNumberNumber_NewNumber: String { return self._s[144]! }
    public var ApplyLanguage_LanguageNotSupportedError: String { return self._s[145]! }
    public var TwoStepAuth_ChangePasswordDescription: String { return self._s[146]! }
    public var PhotoEditor_BlurToolLinear: String { return self._s[147]! }
    public var Contacts_PermissionsAllowInSettings: String { return self._s[148]! }
    public var Weekday_ShortMonday: String { return self._s[149]! }
    public var Cache_KeepMedia: String { return self._s[150]! }
    public var Passport_FieldIdentitySelfieHelp: String { return self._s[151]! }
    public func PUSH_PINNED_STICKER(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[152]!, self._r[152]!, [_1, _2])
    }
    public func Chat_SlowmodeTooltip(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[153]!, self._r[153]!, [_0])
    }
    public var Wallet_Receive_ShareUrlInfo: String { return self._s[154]! }
    public var Conversation_ClousStorageInfo_Description4: String { return self._s[155]! }
    public var Wallet_RestoreFailed_Title: String { return self._s[156]! }
    public var Passport_Language_ru: String { return self._s[157]! }
    public func Notification_CreatedChatWithTitle(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[158]!, self._r[158]!, [_0, _1])
    }
    public var WallpaperPreview_PatternIntensity: String { return self._s[159]! }
    public var TwoStepAuth_RecoveryUnavailable: String { return self._s[160]! }
    public var EnterPasscode_TouchId: String { return self._s[161]! }
    public var PhotoEditor_QualityVeryHigh: String { return self._s[164]! }
    public var Checkout_NewCard_SaveInfo: String { return self._s[166]! }
    public var Gif_NoGifsPlaceholder: String { return self._s[168]! }
    public var Conversation_OpenBotLinkTitle: String { return self._s[170]! }
    public var ChatSettings_AutoDownloadEnabled: String { return self._s[171]! }
    public var NetworkUsageSettings_BytesSent: String { return self._s[172]! }
    public var Checkout_PasswordEntry_Pay: String { return self._s[173]! }
    public var AuthSessions_TerminateSession: String { return self._s[174]! }
    public var Message_File: String { return self._s[175]! }
    public var MediaPicker_VideoMuteDescription: String { return self._s[176]! }
    public var SocksProxySetup_ProxyStatusConnected: String { return self._s[177]! }
    public var TwoStepAuth_RecoveryCode: String { return self._s[178]! }
    public var EnterPasscode_EnterCurrentPasscode: String { return self._s[179]! }
    public func TwoStepAuth_EnterPasswordHint(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[180]!, self._r[180]!, [_0])
    }
    public var Conversation_Moderate_Report: String { return self._s[182]! }
    public var TwoStepAuth_EmailInvalid: String { return self._s[183]! }
    public var Passport_Language_ms: String { return self._s[184]! }
    public var Channel_Edit_AboutItem: String { return self._s[186]! }
    public var DialogList_SearchSectionGlobal: String { return self._s[190]! }
    public var AttachmentMenu_WebSearch: String { return self._s[191]! }
    public var PasscodeSettings_TurnPasscodeOn: String { return self._s[192]! }
    public var Channel_BanUser_Title: String { return self._s[193]! }
    public var WallpaperPreview_SwipeTopText: String { return self._s[194]! }
    public var ChatList_DeleteSavedMessagesConfirmationText: String { return self._s[195]! }
    public var ArchivedChats_IntroText2: String { return self._s[196]! }
    public var Notification_Exceptions_DeleteAll: String { return self._s[197]! }
    public var ChatSearch_SearchPlaceholder: String { return self._s[199]! }
    public func Channel_AdminLog_MessageTransferedNameUsername(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[200]!, self._r[200]!, [_1, _2])
    }
    public var Passport_FieldAddressTranslationHelp: String { return self._s[201]! }
    public var NotificationsSound_Aurora: String { return self._s[202]! }
    public func FileSize_GB(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[203]!, self._r[203]!, [_0])
    }
    public var AuthSessions_LoggedInWithTelegram: String { return self._s[206]! }
    public func Privacy_GroupsAndChannels_InviteToGroupError(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[207]!, self._r[207]!, [_0, _1])
    }
    public var Passport_PasswordNext: String { return self._s[208]! }
    public var Bot_GroupStatusReadsHistory: String { return self._s[209]! }
    public var EmptyGroupInfo_Line2: String { return self._s[210]! }
    public var VoiceOver_Chat_SeenByRecipients: String { return self._s[211]! }
    public var Settings_FAQ_Intro: String { return self._s[214]! }
    public var PrivacySettings_PasscodeAndTouchId: String { return self._s[216]! }
    public var FeaturedStickerPacks_Title: String { return self._s[217]! }
    public var TwoStepAuth_PasswordRemoveConfirmation: String { return self._s[219]! }
    public var Username_Title: String { return self._s[220]! }
    public func Message_StickerText(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[221]!, self._r[221]!, [_0])
    }
    public var PasscodeSettings_AlphanumericCode: String { return self._s[222]! }
    public var Localization_LanguageOther: String { return self._s[223]! }
    public var Stickers_SuggestStickers: String { return self._s[224]! }
    public func Channel_AdminLog_MessageRemovedGroupUsername(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[225]!, self._r[225]!, [_0])
    }
    public var NotificationSettings_ShowNotificationsFromAccountsSection: String { return self._s[226]! }
    public var Channel_AdminLogFilter_EventsAdmins: String { return self._s[227]! }
    public var Conversation_DefaultRestrictedStickers: String { return self._s[228]! }
    public func Notification_PinnedDeletedMessage(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[229]!, self._r[229]!, [_0])
    }
    public var Wallet_TransactionInfo_CopyAddress: String { return self._s[231]! }
    public var Group_UpgradeConfirmation: String { return self._s[232]! }
    public var DialogList_Unpin: String { return self._s[233]! }
    public var Passport_Identity_DateOfBirth: String { return self._s[234]! }
    public var Month_ShortOctober: String { return self._s[235]! }
    public var SettingsSearch_Synonyms_Privacy_Data_ContactsSync: String { return self._s[236]! }
    public var Notification_CallCanceledShort: String { return self._s[237]! }
    public var Passport_Phone_Help: String { return self._s[238]! }
    public var Passport_Language_az: String { return self._s[240]! }
    public var CreatePoll_TextPlaceholder: String { return self._s[242]! }
    public var VoiceOver_Chat_AnonymousPoll: String { return self._s[243]! }
    public var Passport_Identity_DocumentNumber: String { return self._s[244]! }
    public var PhotoEditor_CurvesRed: String { return self._s[245]! }
    public var PhoneNumberHelp_Alert: String { return self._s[247]! }
    public var SocksProxySetup_Port: String { return self._s[248]! }
    public var Checkout_PayNone: String { return self._s[249]! }
    public var AutoDownloadSettings_WiFi: String { return self._s[250]! }
    public var GroupInfo_GroupType: String { return self._s[251]! }
    public var StickerSettings_ContextHide: String { return self._s[252]! }
    public var Passport_Address_OneOfTypeTemporaryRegistration: String { return self._s[253]! }
    public var Group_Setup_HistoryTitle: String { return self._s[255]! }
    public var Passport_Identity_FilesUploadNew: String { return self._s[256]! }
    public var PasscodeSettings_AutoLock: String { return self._s[257]! }
    public var Passport_Title: String { return self._s[258]! }
    public var VoiceOver_Chat_ContactPhoneNumber: String { return self._s[259]! }
    public var Channel_AdminLogFilter_EventsNewSubscribers: String { return self._s[260]! }
    public var GroupPermission_NoSendGifs: String { return self._s[261]! }
    public var PrivacySettings_PasscodeOn: String { return self._s[262]! }
    public func Conversation_ScheduleMessage_SendTomorrow(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[263]!, self._r[263]!, [_0])
    }
    public var State_WaitingForNetwork: String { return self._s[265]! }
    public func Notification_Invited(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[266]!, self._r[266]!, [_0, _1])
    }
    public var Calls_NotNow: String { return self._s[268]! }
    public func Channel_DiscussionGroup_HeaderSet(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[269]!, self._r[269]!, [_0])
    }
    public var UserInfo_SendMessage: String { return self._s[270]! }
    public var TwoStepAuth_PasswordSet: String { return self._s[271]! }
    public var Passport_DeleteDocument: String { return self._s[272]! }
    public var SocksProxySetup_AddProxyTitle: String { return self._s[273]! }
    public func PUSH_MESSAGE_VIDEO(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[274]!, self._r[274]!, [_1])
    }
    public var GroupRemoved_Remove: String { return self._s[275]! }
    public var Passport_FieldIdentity: String { return self._s[276]! }
    public var Group_Setup_TypePrivateHelp: String { return self._s[277]! }
    public var Conversation_Processing: String { return self._s[280]! }
    public var ChatSettings_AutoPlayAnimations: String { return self._s[282]! }
    public var AuthSessions_LogOutApplicationsHelp: String { return self._s[285]! }
    public var Month_GenFebruary: String { return self._s[286]! }
    public var Wallet_Send_NetworkErrorTitle: String { return self._s[287]! }
    public func Login_InvalidPhoneEmailBody(_ _1: String, _ _2: String, _ _3: String, _ _4: String, _ _5: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[289]!, self._r[289]!, [_1, _2, _3, _4, _5])
    }
    public var Passport_Identity_TypeIdentityCard: String { return self._s[290]! }
    public var Wallet_Month_ShortJune: String { return self._s[292]! }
    public var AutoDownloadSettings_DataUsageMedium: String { return self._s[293]! }
    public var GroupInfo_AddParticipant: String { return self._s[294]! }
    public var KeyCommand_SendMessage: String { return self._s[295]! }
    public var VoiceOver_Chat_YourContact: String { return self._s[297]! }
    public var Map_LiveLocationShowAll: String { return self._s[298]! }
    public var WallpaperSearch_ColorOrange: String { return self._s[300]! }
    public var Appearance_AppIconDefaultX: String { return self._s[301]! }
    public var Checkout_Receipt_Title: String { return self._s[302]! }
    public var Group_OwnershipTransfer_ErrorPrivacyRestricted: String { return self._s[303]! }
    public var WallpaperPreview_PreviewTopText: String { return self._s[304]! }
    public var Message_Contact: String { return self._s[305]! }
    public var Call_StatusIncoming: String { return self._s[306]! }
    public var Wallet_TransactionInfo_StorageFeeInfo: String { return self._s[307]! }
    public func Channel_AdminLog_MessageKickedName(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[308]!, self._r[308]!, [_1])
    }
    public func PUSH_ENCRYPTED_MESSAGE(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[310]!, self._r[310]!, [_1])
    }
    public var VoiceOver_Media_PlaybackRate: String { return self._s[311]! }
    public var Passport_FieldIdentityDetailsHelp: String { return self._s[312]! }
    public var Conversation_ViewChannel: String { return self._s[313]! }
    public func Time_TodayAt(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[314]!, self._r[314]!, [_0])
    }
    public var Passport_Language_nl: String { return self._s[316]! }
    public var Camera_Retake: String { return self._s[317]! }
    public func UserInfo_BlockActionTitle(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[318]!, self._r[318]!, [_0])
    }
    public var AuthSessions_LogOutApplications: String { return self._s[319]! }
    public var ApplyLanguage_ApplySuccess: String { return self._s[320]! }
    public var Tour_Title6: String { return self._s[321]! }
    public var Map_ChooseAPlace: String { return self._s[322]! }
    public var CallSettings_Never: String { return self._s[324]! }
    public func Notification_ChangedGroupPhoto(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[325]!, self._r[325]!, [_0])
    }
    public var ChannelRemoved_RemoveInfo: String { return self._s[326]! }
    public func AutoDownloadSettings_PreloadVideoInfo(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[327]!, self._r[327]!, [_0])
    }
    public var SettingsSearch_Synonyms_Notifications_MessageNotificationsExceptions: String { return self._s[328]! }
    public func Conversation_ClearChatConfirmation(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[329]!, self._r[329]!, [_0])
    }
    public var GroupInfo_InviteLink_Title: String { return self._s[330]! }
    public func Channel_AdminLog_MessageUnkickedNameUsername(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[331]!, self._r[331]!, [_1, _2])
    }
    public var KeyCommand_ScrollUp: String { return self._s[332]! }
    public var ContactInfo_URLLabelHomepage: String { return self._s[333]! }
    public var Channel_OwnershipTransfer_ChangeOwner: String { return self._s[334]! }
    public func Channel_AdminLog_DisabledSlowmode(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[335]!, self._r[335]!, [_0])
    }
    public func Conversation_EncryptedPlaceholderTitleOutgoing(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[336]!, self._r[336]!, [_0])
    }
    public var CallFeedback_ReasonDistortedSpeech: String { return self._s[337]! }
    public var Watch_LastSeen_WithinAWeek: String { return self._s[338]! }
    public var ContactList_Context_SendMessage: String { return self._s[340]! }
    public var Weekday_Tuesday: String { return self._s[341]! }
    public var Wallet_Created_Title: String { return self._s[343]! }
    public var ScheduledMessages_Delete: String { return self._s[344]! }
    public var UserInfo_StartSecretChat: String { return self._s[345]! }
    public var Passport_Identity_FilesTitle: String { return self._s[346]! }
    public var Permissions_NotificationsAllow_v0: String { return self._s[347]! }
    public var DialogList_DeleteConversationConfirmation: String { return self._s[349]! }
    public var ChatList_UndoArchiveRevealedTitle: String { return self._s[350]! }
    public var AuthSessions_Sessions: String { return self._s[351]! }
    public func Settings_KeepPhoneNumber(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[353]!, self._r[353]!, [_0])
    }
    public var TwoStepAuth_RecoveryEmailChangeDescription: String { return self._s[354]! }
    public var Call_StatusWaiting: String { return self._s[355]! }
    public var CreateGroup_SoftUserLimitAlert: String { return self._s[356]! }
    public var FastTwoStepSetup_HintHelp: String { return self._s[357]! }
    public var WallpaperPreview_CustomColorBottomText: String { return self._s[358]! }
    public var EditTheme_Expand_Preview_OutgoingText: String { return self._s[359]! }
    public var LogoutOptions_AddAccountText: String { return self._s[360]! }
    public var PasscodeSettings_6DigitCode: String { return self._s[361]! }
    public var Settings_LogoutConfirmationText: String { return self._s[362]! }
    public var Passport_Identity_TypePassport: String { return self._s[364]! }
    public func PUSH_MESSAGE_VIDEOS(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[367]!, self._r[367]!, [_1, _2])
    }
    public var SocksProxySetup_SaveProxy: String { return self._s[368]! }
    public var AccessDenied_SaveMedia: String { return self._s[369]! }
    public var Checkout_ErrorInvoiceAlreadyPaid: String { return self._s[371]! }
    public var Settings_Title: String { return self._s[373]! }
    public var VoiceOver_Chat_RecordModeVideoMessageInfo: String { return self._s[374]! }
    public var Contacts_InviteSearchLabel: String { return self._s[376]! }
    public var ConvertToSupergroup_Title: String { return self._s[377]! }
    public func Channel_AdminLog_CaptionEdited(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[378]!, self._r[378]!, [_0])
    }
    public var InfoPlist_NSSiriUsageDescription: String { return self._s[379]! }
    public func PUSH_MESSAGE_CHANNEL_MESSAGE_GAME_SCORE(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[380]!, self._r[380]!, [_1, _2, _3])
    }
    public var ChatSettings_AutomaticPhotoDownload: String { return self._s[381]! }
    public var UserInfo_BotHelp: String { return self._s[382]! }
    public var PrivacySettings_LastSeenEverybody: String { return self._s[383]! }
    public var Checkout_Name: String { return self._s[384]! }
    public var AutoDownloadSettings_DataUsage: String { return self._s[385]! }
    public var Channel_BanUser_BlockFor: String { return self._s[386]! }
    public var Checkout_ShippingAddress: String { return self._s[387]! }
    public var AutoDownloadSettings_MaxVideoSize: String { return self._s[388]! }
    public var Privacy_PaymentsClearInfoDoneHelp: String { return self._s[389]! }
    public var Privacy_Forwards: String { return self._s[390]! }
    public var Channel_BanUser_PermissionSendPolls: String { return self._s[391]! }
    public var Appearance_ThemeCarouselNewNight: String { return self._s[392]! }
    public func SecretVideo_NotViewedYet(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[395]!, self._r[395]!, [_0])
    }
    public var Contacts_SortedByName: String { return self._s[396]! }
    public var Group_OwnershipTransfer_Title: String { return self._s[397]! }
    public var VoiceOver_Chat_OpenHint: String { return self._s[398]! }
    public var Group_LeaveGroup: String { return self._s[399]! }
    public var Settings_UsernameEmpty: String { return self._s[400]! }
    public func Notification_PinnedPollMessage(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[401]!, self._r[401]!, [_0])
    }
    public func TwoStepAuth_ConfirmEmailDescription(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[402]!, self._r[402]!, [_1])
    }
    public func Channel_OwnershipTransfer_DescriptionInfo(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[403]!, self._r[403]!, [_1, _2])
    }
    public var Message_ImageExpired: String { return self._s[404]! }
    public var TwoStepAuth_RecoveryFailed: String { return self._s[406]! }
    public var EditTheme_Edit_Preview_OutgoingText: String { return self._s[407]! }
    public var UserInfo_AddToExisting: String { return self._s[408]! }
    public var TwoStepAuth_EnabledSuccess: String { return self._s[409]! }
    public var SettingsSearch_Synonyms_Appearance_ChatBackground_SetColor: String { return self._s[410]! }
    public func PUSH_CHANNEL_MESSAGE(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[411]!, self._r[411]!, [_1])
    }
    public var Notifications_GroupNotificationsAlert: String { return self._s[412]! }
    public var Passport_Language_km: String { return self._s[413]! }
    public var SocksProxySetup_AdNoticeHelp: String { return self._s[415]! }
    public var VoiceOver_Media_PlaybackPlay: String { return self._s[416]! }
    public var Notification_CallMissedShort: String { return self._s[417]! }
    public var Wallet_Info_YourBalance: String { return self._s[418]! }
    public var ReportPeer_ReasonOther_Send: String { return self._s[419]! }
    public var Watch_Compose_Send: String { return self._s[420]! }
    public var Passport_Identity_TypeInternalPassportUploadScan: String { return self._s[423]! }
    public var Conversation_HoldForVideo: String { return self._s[424]! }
    public var Wallet_TransactionInfo_CommentHeader: String { return self._s[425]! }
    public var CheckoutInfo_ErrorCityInvalid: String { return self._s[427]! }
    public var Appearance_AutoNightThemeDisabled: String { return self._s[429]! }
    public var Channel_LinkItem: String { return self._s[430]! }
    public func PrivacySettings_LastSeenContactsMinusPlus(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[431]!, self._r[431]!, [_0, _1])
    }
    public func Passport_Identity_NativeNameTitle(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[434]!, self._r[434]!, [_0])
    }
    public var VoiceOver_Recording_StopAndPreview: String { return self._s[435]! }
    public var Passport_Language_dv: String { return self._s[436]! }
    public var Undo_LeftChannel: String { return self._s[437]! }
    public var Notifications_ExceptionsMuted: String { return self._s[438]! }
    public var ChatList_UnhideAction: String { return self._s[439]! }
    public var Conversation_ContextMenuShare: String { return self._s[440]! }
    public var Conversation_ContextMenuStickerPackInfo: String { return self._s[441]! }
    public var ShareFileTip_Title: String { return self._s[442]! }
    public var NotificationsSound_Chord: String { return self._s[443]! }
    public var Wallet_TransactionInfo_OtherFeeHeader: String { return self._s[444]! }
    public func PUSH_CHAT_RETURNED(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[445]!, self._r[445]!, [_1, _2])
    }
    public var Passport_Address_EditTemporaryRegistration: String { return self._s[446]! }
    public func Notification_Joined(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[447]!, self._r[447]!, [_0])
    }
    public func Wallet_Time_PreciseDate_m3(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[448]!, self._r[448]!, [_1, _2, _3])
    }
    public var Wallpaper_ErrorNotFound: String { return self._s[449]! }
    public var Notification_CallOutgoingShort: String { return self._s[451]! }
    public var Wallet_WordImport_IncorrectText: String { return self._s[452]! }
    public func Watch_Time_ShortFullAt(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[453]!, self._r[453]!, [_1, _2])
    }
    public var Passport_Address_TypeUtilityBill: String { return self._s[454]! }
    public var Privacy_Forwards_LinkIfAllowed: String { return self._s[455]! }
    public var ReportPeer_Report: String { return self._s[456]! }
    public var SettingsSearch_Synonyms_Proxy_Title: String { return self._s[457]! }
    public var GroupInfo_DeactivatedStatus: String { return self._s[458]! }
    public func VoiceOver_Chat_MusicTitle(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[459]!, self._r[459]!, [_1, _2])
    }
    public var StickerPack_Send: String { return self._s[460]! }
    public var Login_CodeSentInternal: String { return self._s[461]! }
    public var Wallet_Month_GenJanuary: String { return self._s[462]! }
    public var GroupInfo_InviteLink_LinkSection: String { return self._s[463]! }
    public func Channel_AdminLog_MessageDeleted(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[464]!, self._r[464]!, [_0])
    }
    public func Conversation_EncryptionWaiting(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[466]!, self._r[466]!, [_0])
    }
    public var Channel_BanUser_PermissionSendStickersAndGifs: String { return self._s[467]! }
    public func PUSH_PINNED_GAME(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[468]!, self._r[468]!, [_1])
    }
    public var ReportPeer_ReasonViolence: String { return self._s[470]! }
    public var Map_Locating: String { return self._s[471]! }
    public func VoiceOver_Chat_VideoFrom(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[472]!, self._r[472]!, [_0])
    }
    public func PUSH_ALBUM(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[473]!, self._r[473]!, [_1])
    }
    public var AutoDownloadSettings_GroupChats: String { return self._s[475]! }
    public var CheckoutInfo_SaveInfo: String { return self._s[476]! }
    public var SharedMedia_EmptyLinksText: String { return self._s[478]! }
    public var Passport_Address_CityPlaceholder: String { return self._s[479]! }
    public var CheckoutInfo_ErrorStateInvalid: String { return self._s[480]! }
    public var Privacy_ProfilePhoto_CustomHelp: String { return self._s[481]! }
    public var Channel_AdminLog_CanAddAdmins: String { return self._s[483]! }
    public func PUSH_CHANNEL_MESSAGE_FWD(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[484]!, self._r[484]!, [_1])
    }
    public func Time_MonthOfYear_m8(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[485]!, self._r[485]!, [_0])
    }
    public var InfoPlist_NSLocationWhenInUseUsageDescription: String { return self._s[486]! }
    public var GroupInfo_InviteLink_RevokeAlert_Success: String { return self._s[487]! }
    public var ChangePhoneNumberCode_Code: String { return self._s[488]! }
    public var Appearance_CreateTheme: String { return self._s[489]! }
    public func UserInfo_NotificationsDefaultSound(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[490]!, self._r[490]!, [_0])
    }
    public var TwoStepAuth_SetupEmail: String { return self._s[491]! }
    public var HashtagSearch_AllChats: String { return self._s[492]! }
    public var SettingsSearch_Synonyms_Data_AutoDownloadUsingCellular: String { return self._s[494]! }
    public func ChatList_DeleteForEveryone(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[495]!, self._r[495]!, [_0])
    }
    public var PhotoEditor_QualityHigh: String { return self._s[497]! }
    public func Passport_Phone_UseTelegramNumber(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[498]!, self._r[498]!, [_0])
    }
    public var ApplyLanguage_ApplyLanguageAction: String { return self._s[499]! }
    public var SettingsSearch_Synonyms_Notifications_ChannelNotificationsPreview: String { return self._s[500]! }
    public var Message_LiveLocation: String { return self._s[501]! }
    public var Cache_LowDiskSpaceText: String { return self._s[502]! }
    public var Wallet_Receive_ShareAddress: String { return self._s[503]! }
    public var EditTheme_ErrorLinkTaken: String { return self._s[504]! }
    public var Conversation_SendMessage: String { return self._s[505]! }
    public var AuthSessions_EmptyTitle: String { return self._s[506]! }
    public var Privacy_PhoneNumber: String { return self._s[507]! }
    public var PeopleNearby_CreateGroup: String { return self._s[508]! }
    public var CallSettings_UseLessData: String { return self._s[509]! }
    public var NetworkUsageSettings_MediaDocumentDataSection: String { return self._s[510]! }
    public var Stickers_AddToFavorites: String { return self._s[511]! }
    public var Wallet_WordImport_Title: String { return self._s[512]! }
    public var PhotoEditor_QualityLow: String { return self._s[513]! }
    public var Watch_UserInfo_Unblock: String { return self._s[514]! }
    public var Settings_Logout: String { return self._s[515]! }
    public func PUSH_MESSAGE_ROUND(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[516]!, self._r[516]!, [_1])
    }
    public var ContactInfo_PhoneLabelWork: String { return self._s[517]! }
    public var ChannelInfo_Stats: String { return self._s[518]! }
    public var TextFormat_Link: String { return self._s[519]! }
    public func Date_ChatDateHeader(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[520]!, self._r[520]!, [_1, _2])
    }
    public var Wallet_TransactionInfo_Title: String { return self._s[521]! }
    public func Message_ForwardedMessage(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[522]!, self._r[522]!, [_0])
    }
    public var Watch_Notification_Joined: String { return self._s[523]! }
    public var Group_Setup_TypePublicHelp: String { return self._s[524]! }
    public var Passport_Scans_UploadNew: String { return self._s[525]! }
    public var Checkout_LiabilityAlertTitle: String { return self._s[526]! }
    public var DialogList_Title: String { return self._s[529]! }
    public var NotificationSettings_ContactJoined: String { return self._s[530]! }
    public var GroupInfo_LabelAdmin: String { return self._s[531]! }
    public var KeyCommand_ChatInfo: String { return self._s[532]! }
    public var Conversation_EditingCaptionPanelTitle: String { return self._s[533]! }
    public var Call_ReportIncludeLog: String { return self._s[534]! }
    public func Notifications_ExceptionsChangeSound(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[537]!, self._r[537]!, [_0])
    }
    public var LocalGroup_IrrelevantWarning: String { return self._s[538]! }
    public var ChatAdmins_AllMembersAreAdmins: String { return self._s[539]! }
    public var Conversation_DefaultRestrictedInline: String { return self._s[540]! }
    public var Message_Sticker: String { return self._s[541]! }
    public var LastSeen_JustNow: String { return self._s[543]! }
    public var Passport_Email_EmailPlaceholder: String { return self._s[545]! }
    public var SettingsSearch_Synonyms_AppLanguage: String { return self._s[546]! }
    public var Channel_AdminLogFilter_EventsEditedMessages: String { return self._s[547]! }
    public var Channel_EditAdmin_PermissionsHeader: String { return self._s[548]! }
    public var TwoStepAuth_Email: String { return self._s[549]! }
    public var SettingsSearch_Synonyms_Notifications_ChannelNotificationsSound: String { return self._s[550]! }
    public var PhotoEditor_BlurToolOff: String { return self._s[551]! }
    public var Message_PinnedStickerMessage: String { return self._s[552]! }
    public var ContactInfo_PhoneLabelPager: String { return self._s[553]! }
    public var SettingsSearch_Synonyms_Appearance_TextSize: String { return self._s[554]! }
    public var Passport_DiscardMessageTitle: String { return self._s[555]! }
    public var Privacy_PaymentsTitle: String { return self._s[556]! }
    public var EditTheme_Edit_Preview_IncomingReplyName: String { return self._s[557]! }
    public var Channel_DiscussionGroup_Header: String { return self._s[559]! }
    public var VoiceOver_Chat_OptionSelected: String { return self._s[560]! }
    public var Appearance_ColorTheme: String { return self._s[561]! }
    public var UserInfo_ShareContact: String { return self._s[562]! }
    public var Passport_Address_TypePassportRegistration: String { return self._s[563]! }
    public var Common_More: String { return self._s[564]! }
    public var Watch_Message_Call: String { return self._s[565]! }
    public var Profile_EncryptionKey: String { return self._s[568]! }
    public var Privacy_TopPeers: String { return self._s[569]! }
    public var Conversation_StopPollConfirmation: String { return self._s[570]! }
    public var Wallet_Words_NotDoneText: String { return self._s[572]! }
    public var Privacy_TopPeersWarning: String { return self._s[574]! }
    public var SettingsSearch_Synonyms_Data_DownloadInBackground: String { return self._s[575]! }
    public var SettingsSearch_Synonyms_Data_Storage_KeepMedia: String { return self._s[576]! }
    public var Wallet_RestoreFailed_EnterWords: String { return self._s[579]! }
    public var DialogList_SearchSectionMessages: String { return self._s[580]! }
    public var Notifications_ChannelNotifications: String { return self._s[581]! }
    public var CheckoutInfo_ShippingInfoAddress1Placeholder: String { return self._s[582]! }
    public var Passport_Language_sk: String { return self._s[583]! }
    public var Notification_MessageLifetime1h: String { return self._s[584]! }
    public var Wallpaper_ResetWallpapersInfo: String { return self._s[585]! }
    public var Call_ReportSkip: String { return self._s[587]! }
    public var Cache_ServiceFiles: String { return self._s[588]! }
    public var Group_ErrorAddTooMuchAdmins: String { return self._s[589]! }
    public var VoiceOver_Chat_YourFile: String { return self._s[590]! }
    public var Map_Hybrid: String { return self._s[591]! }
    public var Contacts_SearchUsersAndGroupsLabel: String { return self._s[593]! }
    public var ChatSettings_AutoDownloadVideos: String { return self._s[595]! }
    public var Channel_BanUser_PermissionEmbedLinks: String { return self._s[596]! }
    public var InfoPlist_NSLocationAlwaysAndWhenInUseUsageDescription: String { return self._s[597]! }
    public var SocksProxySetup_ProxyTelegram: String { return self._s[600]! }
    public func PUSH_MESSAGE_AUDIO(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[601]!, self._r[601]!, [_1])
    }
    public var Channel_Username_CreatePrivateLinkHelp: String { return self._s[603]! }
    public var ScheduledMessages_ScheduledToday: String { return self._s[604]! }
    public func PUSH_CHAT_TITLE_EDITED(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[605]!, self._r[605]!, [_1, _2])
    }
    public var Conversation_LiveLocationYou: String { return self._s[606]! }
    public var SettingsSearch_Synonyms_Privacy_Calls: String { return self._s[607]! }
    public var SettingsSearch_Synonyms_Notifications_MessageNotificationsPreview: String { return self._s[608]! }
    public var UserInfo_ShareBot: String { return self._s[611]! }
    public func PUSH_AUTH_REGION(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[612]!, self._r[612]!, [_1, _2])
    }
    public var PhotoEditor_ShadowsTint: String { return self._s[613]! }
    public var Message_Audio: String { return self._s[614]! }
    public var Passport_Language_lt: String { return self._s[615]! }
    public func Message_PinnedTextMessage(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[616]!, self._r[616]!, [_0])
    }
    public var Permissions_SiriText_v0: String { return self._s[617]! }
    public var Conversation_FileICloudDrive: String { return self._s[618]! }
    public var ChatList_DeleteForEveryoneConfirmationTitle: String { return self._s[619]! }
    public var Notifications_Badge_IncludeMutedChats: String { return self._s[620]! }
    public func Notification_NewAuthDetected(_ _1: String, _ _2: String, _ _3: String, _ _4: String, _ _5: String, _ _6: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[621]!, self._r[621]!, [_1, _2, _3, _4, _5, _6])
    }
    public var DialogList_ProxyConnectionIssuesTooltip: String { return self._s[622]! }
    public func Time_MonthOfYear_m5(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[623]!, self._r[623]!, [_0])
    }
    public var Channel_SignMessages: String { return self._s[624]! }
    public func PUSH_MESSAGE_NOTEXT(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[625]!, self._r[625]!, [_1])
    }
    public var Compose_ChannelTokenListPlaceholder: String { return self._s[626]! }
    public var Passport_ScanPassport: String { return self._s[627]! }
    public var Watch_Suggestion_Thanks: String { return self._s[628]! }
    public var BlockedUsers_AddNew: String { return self._s[629]! }
    public func PUSH_CHAT_MESSAGE(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[630]!, self._r[630]!, [_1, _2])
    }
    public var Watch_Message_Invoice: String { return self._s[631]! }
    public var SettingsSearch_Synonyms_Privacy_LastSeen: String { return self._s[632]! }
    public var Month_GenJuly: String { return self._s[633]! }
    public var SocksProxySetup_ProxySocks5: String { return self._s[634]! }
    public var Notification_Exceptions_DeleteAllConfirmation: String { return self._s[636]! }
    public var Notification_ChannelInviterSelf: String { return self._s[637]! }
    public var CheckoutInfo_ReceiverInfoEmail: String { return self._s[638]! }
    public func ApplyLanguage_ChangeLanguageUnofficialText(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[639]!, self._r[639]!, [_1, _2])
    }
    public var CheckoutInfo_Title: String { return self._s[640]! }
    public var Watch_Stickers_RecentPlaceholder: String { return self._s[641]! }
    public func Map_DistanceAway(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[642]!, self._r[642]!, [_0])
    }
    public var Passport_Identity_MainPage: String { return self._s[643]! }
    public var TwoStepAuth_ConfirmEmailResendCode: String { return self._s[644]! }
    public var Passport_Language_de: String { return self._s[645]! }
    public var Update_Title: String { return self._s[646]! }
    public var ContactInfo_PhoneLabelWorkFax: String { return self._s[647]! }
    public var Channel_AdminLog_BanEmbedLinks: String { return self._s[648]! }
    public var Passport_Email_UseTelegramEmailHelp: String { return self._s[649]! }
    public var Notifications_ChannelNotificationsPreview: String { return self._s[650]! }
    public var NotificationsSound_Telegraph: String { return self._s[651]! }
    public var Watch_LastSeen_ALongTimeAgo: String { return self._s[652]! }
    public var ChannelMembers_WhoCanAddMembers: String { return self._s[653]! }
    public func AutoDownloadSettings_UpTo(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[654]!, self._r[654]!, [_0])
    }
    public var Stickers_SuggestAll: String { return self._s[655]! }
    public var Conversation_ForwardTitle: String { return self._s[656]! }
    public var Appearance_ThemePreview_ChatList_7_Name: String { return self._s[657]! }
    public func Notification_JoinedChannel(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[658]!, self._r[658]!, [_0])
    }
    public var Calls_NewCall: String { return self._s[659]! }
    public var Call_StatusEnded: String { return self._s[660]! }
    public var AutoDownloadSettings_DataUsageLow: String { return self._s[661]! }
    public var Settings_ProxyConnected: String { return self._s[662]! }
    public var Channel_AdminLogFilter_EventsPinned: String { return self._s[663]! }
    public var PhotoEditor_QualityVeryLow: String { return self._s[664]! }
    public var Channel_AdminLogFilter_EventsDeletedMessages: String { return self._s[665]! }
    public var Passport_PasswordPlaceholder: String { return self._s[666]! }
    public var Message_PinnedInvoice: String { return self._s[667]! }
    public var Passport_Identity_IssueDate: String { return self._s[668]! }
    public var Passport_Language_pl: String { return self._s[669]! }
    public func ChannelInfo_ChannelForbidden(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[670]!, self._r[670]!, [_0])
    }
    public var SocksProxySetup_PasteFromClipboard: String { return self._s[671]! }
    public var Call_StatusConnecting: String { return self._s[672]! }
    public func Username_UsernameIsAvailable(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[673]!, self._r[673]!, [_0])
    }
    public var ChatSettings_ConnectionType_UseProxy: String { return self._s[675]! }
    public var Common_Edit: String { return self._s[676]! }
    public var PrivacySettings_LastSeenNobody: String { return self._s[677]! }
    public func Notification_LeftChat(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[678]!, self._r[678]!, [_0])
    }
    public var GroupInfo_ChatAdmins: String { return self._s[679]! }
    public var PrivateDataSettings_Title: String { return self._s[680]! }
    public var Login_CancelPhoneVerificationStop: String { return self._s[681]! }
    public var ChatList_Read: String { return self._s[682]! }
    public var Wallet_WordImport_Text: String { return self._s[683]! }
    public var Undo_ChatClearedForBothSides: String { return self._s[684]! }
    public var GroupPermission_SectionTitle: String { return self._s[685]! }
    public func PUSH_CHAT_LEFT(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[687]!, self._r[687]!, [_1, _2])
    }
    public var Checkout_ErrorPaymentFailed: String { return self._s[688]! }
    public var Update_UpdateApp: String { return self._s[689]! }
    public var Group_Username_RevokeExistingUsernamesInfo: String { return self._s[690]! }
    public var Settings_Appearance: String { return self._s[691]! }
    public var SettingsSearch_Synonyms_Stickers_SuggestStickers: String { return self._s[695]! }
    public var Watch_Location_Access: String { return self._s[696]! }
    public var ShareMenu_CopyShareLink: String { return self._s[698]! }
    public var TwoStepAuth_SetupHintTitle: String { return self._s[699]! }
    public var Conversation_Theme: String { return self._s[701]! }
    public func DialogList_SingleRecordingVideoMessageSuffix(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[702]!, self._r[702]!, [_0])
    }
    public var Notifications_ClassicTones: String { return self._s[703]! }
    public var Weekday_ShortWednesday: String { return self._s[704]! }
    public var WallpaperPreview_SwipeColorsBottomText: String { return self._s[705]! }
    public var Undo_LeftGroup: String { return self._s[708]! }
    public var Wallet_RestoreFailed_Text: String { return self._s[709]! }
    public var Conversation_LinkDialogCopy: String { return self._s[710]! }
    public var Wallet_TransactionInfo_NoAddress: String { return self._s[712]! }
    public var Wallet_Navigation_Back: String { return self._s[713]! }
    public var KeyCommand_FocusOnInputField: String { return self._s[714]! }
    public var Contacts_SelectAll: String { return self._s[715]! }
    public var Preview_SaveToCameraRoll: String { return self._s[716]! }
    public var PrivacySettings_PasscodeOff: String { return self._s[717]! }
    public var Appearance_ThemePreview_ChatList_6_Name: String { return self._s[718]! }
    public var Wallpaper_Title: String { return self._s[719]! }
    public var Conversation_FilePhotoOrVideo: String { return self._s[720]! }
    public var AccessDenied_Camera: String { return self._s[721]! }
    public var Watch_Compose_CurrentLocation: String { return self._s[722]! }
    public var Channel_DiscussionGroup_MakeHistoryPublicProceed: String { return self._s[724]! }
    public func SecretImage_NotViewedYet(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[725]!, self._r[725]!, [_0])
    }
    public var GroupInfo_InvitationLinkDoesNotExist: String { return self._s[726]! }
    public var Passport_Language_ro: String { return self._s[727]! }
    public var EditTheme_UploadNewTheme: String { return self._s[728]! }
    public var CheckoutInfo_SaveInfoHelp: String { return self._s[729]! }
    public var Wallet_Intro_Terms: String { return self._s[730]! }
    public func Notification_SecretChatMessageScreenshot(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[731]!, self._r[731]!, [_0])
    }
    public var Login_CancelPhoneVerification: String { return self._s[732]! }
    public var State_ConnectingToProxy: String { return self._s[733]! }
    public var Calls_RatingTitle: String { return self._s[734]! }
    public var Generic_ErrorMoreInfo: String { return self._s[735]! }
    public var Appearance_PreviewReplyText: String { return self._s[736]! }
    public var CheckoutInfo_ShippingInfoPostcodePlaceholder: String { return self._s[737]! }
    public func Wallet_Send_Balance(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[738]!, self._r[738]!, [_0])
    }
    public var SharedMedia_CategoryLinks: String { return self._s[739]! }
    public var Calls_Missed: String { return self._s[740]! }
    public var Cache_Photos: String { return self._s[744]! }
    public var GroupPermission_NoAddMembers: String { return self._s[745]! }
    public var ScheduledMessages_Title: String { return self._s[746]! }
    public func Channel_AdminLog_MessageUnpinned(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[747]!, self._r[747]!, [_0])
    }
    public var Conversation_ShareBotLocationConfirmationTitle: String { return self._s[748]! }
    public var Settings_ProxyDisabled: String { return self._s[749]! }
    public func Settings_ApplyProxyAlertCredentials(_ _1: String, _ _2: String, _ _3: String, _ _4: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[750]!, self._r[750]!, [_1, _2, _3, _4])
    }
    public func Conversation_RestrictedMediaTimed(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[751]!, self._r[751]!, [_0])
    }
    public var ChatList_Context_RemoveFromRecents: String { return self._s[753]! }
    public var Appearance_Title: String { return self._s[754]! }
    public func Time_MonthOfYear_m2(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[756]!, self._r[756]!, [_0])
    }
    public var Conversation_WalletRequiredText: String { return self._s[757]! }
    public var StickerPacksSettings_ShowStickersButtonHelp: String { return self._s[758]! }
    public var Channel_EditMessageErrorGeneric: String { return self._s[759]! }
    public var Privacy_Calls_IntegrationHelp: String { return self._s[760]! }
    public var Preview_DeletePhoto: String { return self._s[761]! }
    public var Appearance_AppIconFilledX: String { return self._s[762]! }
    public var PrivacySettings_PrivacyTitle: String { return self._s[763]! }
    public func Conversation_BotInteractiveUrlAlert(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[764]!, self._r[764]!, [_0])
    }
    public var Coub_TapForSound: String { return self._s[766]! }
    public var Map_LocatingError: String { return self._s[767]! }
    public var TwoStepAuth_EmailChangeSuccess: String { return self._s[769]! }
    public var Conversation_SendMessage_SendSilently: String { return self._s[770]! }
    public var VoiceOver_MessageContextOpenMessageMenu: String { return self._s[771]! }
    public func Wallet_Time_PreciseDate_m8(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[772]!, self._r[772]!, [_1, _2, _3])
    }
    public var Passport_ForgottenPassword: String { return self._s[773]! }
    public var GroupInfo_InviteLink_RevokeLink: String { return self._s[774]! }
    public var StickerPacksSettings_ArchivedPacks: String { return self._s[775]! }
    public var Login_TermsOfServiceSignupDecline: String { return self._s[777]! }
    public var Channel_Moderator_AccessLevelRevoke: String { return self._s[778]! }
    public var Message_Location: String { return self._s[779]! }
    public var Passport_Identity_NamePlaceholder: String { return self._s[780]! }
    public var Channel_Management_Title: String { return self._s[781]! }
    public var DialogList_SearchSectionDialogs: String { return self._s[783]! }
    public var Compose_NewChannel_Members: String { return self._s[784]! }
    public func DialogList_SingleUploadingFileSuffix(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[785]!, self._r[785]!, [_0])
    }
    public var GroupInfo_Location: String { return self._s[786]! }
    public var Appearance_ThemePreview_ChatList_5_Name: String { return self._s[787]! }
    public var AutoNightTheme_ScheduledFrom: String { return self._s[788]! }
    public var PhotoEditor_WarmthTool: String { return self._s[789]! }
    public var Passport_Language_tr: String { return self._s[790]! }
    public func PUSH_MESSAGE_GAME_SCORE(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[791]!, self._r[791]!, [_1, _2, _3])
    }
    public var Login_ResetAccountProtected_Reset: String { return self._s[793]! }
    public var Watch_PhotoView_Title: String { return self._s[794]! }
    public var Passport_Phone_Delete: String { return self._s[795]! }
    public var Undo_ChatDeletedForBothSides: String { return self._s[796]! }
    public var Conversation_EditingMessageMediaEditCurrentPhoto: String { return self._s[797]! }
    public var GroupInfo_Permissions: String { return self._s[798]! }
    public var PasscodeSettings_TurnPasscodeOff: String { return self._s[799]! }
    public var Profile_ShareContactButton: String { return self._s[800]! }
    public var ChatSettings_Other: String { return self._s[801]! }
    public var UserInfo_NotificationsDisabled: String { return self._s[802]! }
    public var CheckoutInfo_ShippingInfoCity: String { return self._s[803]! }
    public var LastSeen_WithinAMonth: String { return self._s[804]! }
    public var VoiceOver_Chat_PlayHint: String { return self._s[805]! }
    public var Conversation_ReportGroupLocation: String { return self._s[806]! }
    public var Conversation_EncryptionCanceled: String { return self._s[807]! }
    public var MediaPicker_GroupDescription: String { return self._s[808]! }
    public var WebSearch_Images: String { return self._s[809]! }
    public func Channel_Management_PromotedBy(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[810]!, self._r[810]!, [_0])
    }
    public var Message_Photo: String { return self._s[811]! }
    public var PasscodeSettings_HelpBottom: String { return self._s[812]! }
    public var AutoDownloadSettings_VideosTitle: String { return self._s[813]! }
    public var VoiceOver_Media_PlaybackRateChange: String { return self._s[814]! }
    public var Passport_Identity_AddDriversLicense: String { return self._s[815]! }
    public var TwoStepAuth_EnterPasswordPassword: String { return self._s[816]! }
    public var NotificationsSound_Calypso: String { return self._s[817]! }
    public var Map_Map: String { return self._s[818]! }
    public var CheckoutInfo_ReceiverInfoTitle: String { return self._s[820]! }
    public var ChatSettings_TextSizeUnits: String { return self._s[821]! }
    public func VoiceOver_Chat_FileFrom(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[822]!, self._r[822]!, [_0])
    }
    public var Common_of: String { return self._s[823]! }
    public var Conversation_ForwardContacts: String { return self._s[826]! }
    public func Call_AnsweringWithAccount(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[828]!, self._r[828]!, [_0])
    }
    public var Passport_Language_hy: String { return self._s[829]! }
    public var Notifications_MessageNotificationsHelp: String { return self._s[830]! }
    public var AutoDownloadSettings_Reset: String { return self._s[831]! }
    public var Wallet_TransactionInfo_AddressCopied: String { return self._s[832]! }
    public var Paint_ClearConfirm: String { return self._s[833]! }
    public var Camera_VideoMode: String { return self._s[834]! }
    public func Conversation_RestrictedStickersTimed(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[835]!, self._r[835]!, [_0])
    }
    public var Privacy_Calls_AlwaysAllow_Placeholder: String { return self._s[836]! }
    public var Conversation_ViewBackground: String { return self._s[837]! }
    public func Wallet_Info_TransactionDateHeaderYear(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[838]!, self._r[838]!, [_1, _2, _3])
    }
    public var Passport_Language_el: String { return self._s[839]! }
    public var PhotoEditor_Original: String { return self._s[840]! }
    public var Settings_FAQ_Button: String { return self._s[842]! }
    public var Channel_Setup_PublicNoLink: String { return self._s[844]! }
    public var Conversation_UnsupportedMedia: String { return self._s[845]! }
    public var Conversation_SlideToCancel: String { return self._s[846]! }
    public var Appearance_ThemePreview_ChatList_4_Name: String { return self._s[847]! }
    public var Passport_Identity_OneOfTypeInternalPassport: String { return self._s[848]! }
    public var CheckoutInfo_ShippingInfoPostcode: String { return self._s[849]! }
    public var Conversation_ReportSpamChannelConfirmation: String { return self._s[850]! }
    public var AutoNightTheme_NotAvailable: String { return self._s[851]! }
    public var Conversation_Owner: String { return self._s[852]! }
    public var Common_Create: String { return self._s[853]! }
    public var Settings_ApplyProxyAlertEnable: String { return self._s[854]! }
    public var ContactList_Context_Call: String { return self._s[855]! }
    public var Localization_ChooseLanguage: String { return self._s[857]! }
    public var ChatList_Context_AddToContacts: String { return self._s[859]! }
    public var Settings_Proxy: String { return self._s[861]! }
    public var Privacy_TopPeersHelp: String { return self._s[862]! }
    public var CheckoutInfo_ShippingInfoCountryPlaceholder: String { return self._s[863]! }
    public var Chat_UnsendMyMessages: String { return self._s[864]! }
    public func VoiceOver_Chat_Duration(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[865]!, self._r[865]!, [_0])
    }
    public var TwoStepAuth_ConfirmationAbort: String { return self._s[866]! }
    public func Contacts_AccessDeniedHelpPortrait(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[868]!, self._r[868]!, [_0])
    }
    public var Contacts_SortedByPresence: String { return self._s[869]! }
    public var Passport_Identity_SurnamePlaceholder: String { return self._s[870]! }
    public var Cache_Title: String { return self._s[871]! }
    public func Login_PhoneBannedEmailSubject(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[872]!, self._r[872]!, [_0])
    }
    public var TwoStepAuth_EmailCodeExpired: String { return self._s[873]! }
    public var Channel_Moderator_Title: String { return self._s[874]! }
    public var InstantPage_AutoNightTheme: String { return self._s[876]! }
    public func PUSH_MESSAGE_POLL(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[879]!, self._r[879]!, [_1])
    }
    public var Passport_Scans_Upload: String { return self._s[880]! }
    public var Undo_Undo: String { return self._s[882]! }
    public var Contacts_AccessDeniedHelpON: String { return self._s[883]! }
    public var TwoStepAuth_RemovePassword: String { return self._s[884]! }
    public var Common_Delete: String { return self._s[885]! }
    public var Contacts_AddPeopleNearby: String { return self._s[887]! }
    public var Conversation_ContextMenuDelete: String { return self._s[888]! }
    public var SocksProxySetup_Credentials: String { return self._s[889]! }
    public var Appearance_EditTheme: String { return self._s[891]! }
    public var PasscodeSettings_AutoLock_Disabled: String { return self._s[892]! }
    public var Wallet_Send_NetworkErrorText: String { return self._s[893]! }
    public var Passport_Address_OneOfTypeRentalAgreement: String { return self._s[896]! }
    public var Conversation_ShareBotContactConfirmationTitle: String { return self._s[897]! }
    public var Passport_Language_id: String { return self._s[899]! }
    public var WallpaperSearch_ColorTeal: String { return self._s[900]! }
    public var ChannelIntro_Title: String { return self._s[901]! }
    public func Channel_AdminLog_MessageToggleSignaturesOff(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[902]!, self._r[902]!, [_0])
    }
    public var VoiceOver_Chat_OpenLinkHint: String { return self._s[904]! }
    public var VoiceOver_Chat_Reply: String { return self._s[905]! }
    public var ScheduledMessages_BotActionUnavailable: String { return self._s[906]! }
    public var Channel_Info_Description: String { return self._s[907]! }
    public var Stickers_FavoriteStickers: String { return self._s[908]! }
    public var Channel_BanUser_PermissionAddMembers: String { return self._s[909]! }
    public var Notifications_DisplayNamesOnLockScreen: String { return self._s[910]! }
    public var ChatSearch_ResultsTooltip: String { return self._s[911]! }
    public var Wallet_VoiceOver_Editing_ClearText: String { return self._s[912]! }
    public var Calls_NoMissedCallsPlacehoder: String { return self._s[913]! }
    public var Group_PublicLink_Placeholder: String { return self._s[914]! }
    public var Notifications_ExceptionsDefaultSound: String { return self._s[915]! }
    public func PUSH_CHANNEL_MESSAGE_POLL(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[916]!, self._r[916]!, [_1])
    }
    public var TextFormat_Underline: String { return self._s[917]! }
    public func DialogList_SearchSubtitleFormat(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[918]!, self._r[918]!, [_1, _2])
    }
    public func Channel_AdminLog_MessageRemovedGroupStickerPack(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[919]!, self._r[919]!, [_0])
    }
    public var Appearance_ThemePreview_ChatList_3_Name: String { return self._s[920]! }
    public func Channel_OwnershipTransfer_TransferCompleted(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[921]!, self._r[921]!, [_1, _2])
    }
    public var Wallet_Intro_ImportExisting: String { return self._s[922]! }
    public var GroupPermission_Delete: String { return self._s[923]! }
    public var Passport_Language_uk: String { return self._s[924]! }
    public var StickerPack_HideStickers: String { return self._s[926]! }
    public var ChangePhoneNumberNumber_NumberPlaceholder: String { return self._s[927]! }
    public func PUSH_CHAT_MESSAGE_PHOTO(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[928]!, self._r[928]!, [_1, _2])
    }
    public var Activity_UploadingVideoMessage: String { return self._s[929]! }
    public func GroupPermission_ApplyAlertText(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[930]!, self._r[930]!, [_0])
    }
    public var Channel_TitleInfo: String { return self._s[931]! }
    public var StickerPacksSettings_ArchivedPacks_Info: String { return self._s[932]! }
    public var Settings_CallSettings: String { return self._s[933]! }
    public var Camera_SquareMode: String { return self._s[934]! }
    public var Conversation_SendMessage_ScheduleMessage: String { return self._s[935]! }
    public var GroupInfo_SharedMediaNone: String { return self._s[936]! }
    public func PUSH_MESSAGE_VIDEO_SECRET(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[937]!, self._r[937]!, [_1])
    }
    public var Bot_GenericBotStatus: String { return self._s[938]! }
    public var Application_Update: String { return self._s[940]! }
    public var Month_ShortJanuary: String { return self._s[941]! }
    public var Contacts_PermissionsKeepDisabled: String { return self._s[942]! }
    public var Channel_AdminLog_BanReadMessages: String { return self._s[943]! }
    public var Settings_AppLanguage_Unofficial: String { return self._s[944]! }
    public var Passport_Address_Street2Placeholder: String { return self._s[945]! }
    public func Map_LiveLocationShortHour(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[946]!, self._r[946]!, [_0])
    }
    public var NetworkUsageSettings_Cellular: String { return self._s[947]! }
    public var Appearance_PreviewOutgoingText: String { return self._s[948]! }
    public var Notifications_PermissionsAllowInSettings: String { return self._s[949]! }
    public var AutoDownloadSettings_OnForAll: String { return self._s[951]! }
    public var Map_Directions: String { return self._s[952]! }
    public var Passport_FieldIdentityTranslationHelp: String { return self._s[954]! }
    public var Appearance_ThemeDay: String { return self._s[955]! }
    public var LogoutOptions_LogOut: String { return self._s[956]! }
    public var Group_PublicLink_Title: String { return self._s[958]! }
    public var Channel_AddBotErrorNoRights: String { return self._s[959]! }
    public var Passport_Identity_AddPassport: String { return self._s[960]! }
    public var LocalGroup_ButtonTitle: String { return self._s[961]! }
    public var Call_Message: String { return self._s[962]! }
    public var PhotoEditor_ExposureTool: String { return self._s[963]! }
    public var Wallet_Receive_CommentInfo: String { return self._s[965]! }
    public var Passport_FieldOneOf_Delimeter: String { return self._s[966]! }
    public var Channel_AdminLog_CanBanUsers: String { return self._s[968]! }
    public var Appearance_ThemePreview_ChatList_2_Name: String { return self._s[969]! }
    public var Appearance_Preview: String { return self._s[970]! }
    public var Compose_ChannelMembers: String { return self._s[971]! }
    public var Conversation_DeleteManyMessages: String { return self._s[972]! }
    public var ReportPeer_ReasonOther_Title: String { return self._s[973]! }
    public var Checkout_ErrorProviderAccountTimeout: String { return self._s[974]! }
    public var TwoStepAuth_ResetAccountConfirmation: String { return self._s[975]! }
    public var Channel_Stickers_CreateYourOwn: String { return self._s[978]! }
    public var Conversation_UpdateTelegram: String { return self._s[979]! }
    public var EditTheme_Create_TopInfo: String { return self._s[980]! }
    public func Notification_PinnedPhotoMessage(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[981]!, self._r[981]!, [_0])
    }
    public var Wallet_WordCheck_Continue: String { return self._s[982]! }
    public func PUSH_PINNED_GIF(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[983]!, self._r[983]!, [_1])
    }
    public var GroupInfo_Administrators_Title: String { return self._s[984]! }
    public var Privacy_Forwards_PreviewMessageText: String { return self._s[985]! }
    public func PrivacySettings_LastSeenNobodyPlus(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[986]!, self._r[986]!, [_0])
    }
    public var Tour_Title3: String { return self._s[987]! }
    public var Channel_EditAdmin_PermissionInviteSubscribers: String { return self._s[988]! }
    public var Clipboard_SendPhoto: String { return self._s[992]! }
    public var MediaPicker_Videos: String { return self._s[993]! }
    public var Passport_Email_Title: String { return self._s[994]! }
    public func PrivacySettings_LastSeenEverybodyMinus(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[995]!, self._r[995]!, [_0])
    }
    public var StickerPacksSettings_Title: String { return self._s[996]! }
    public var Conversation_MessageDialogDelete: String { return self._s[997]! }
    public var Privacy_Calls_CustomHelp: String { return self._s[999]! }
    public var Message_Wallpaper: String { return self._s[1000]! }
    public var MemberSearch_BotSection: String { return self._s[1001]! }
    public var GroupInfo_SetSound: String { return self._s[1002]! }
    public var Core_ServiceUserStatus: String { return self._s[1003]! }
    public var LiveLocationUpdated_JustNow: String { return self._s[1004]! }
    public var Call_StatusFailed: String { return self._s[1005]! }
    public var TwoStepAuth_SetupPasswordDescription: String { return self._s[1006]! }
    public var TwoStepAuth_SetPassword: String { return self._s[1007]! }
    public var Permissions_PeopleNearbyText_v0: String { return self._s[1008]! }
    public func SocksProxySetup_ProxyStatusPing(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1010]!, self._r[1010]!, [_0])
    }
    public var Calls_SubmitRating: String { return self._s[1011]! }
    public var Profile_Username: String { return self._s[1012]! }
    public var Bot_DescriptionTitle: String { return self._s[1013]! }
    public var MaskStickerSettings_Title: String { return self._s[1014]! }
    public var SharedMedia_CategoryOther: String { return self._s[1015]! }
    public var GroupInfo_SetGroupPhoto: String { return self._s[1016]! }
    public var Common_NotNow: String { return self._s[1017]! }
    public var CallFeedback_IncludeLogsInfo: String { return self._s[1018]! }
    public var Conversation_ShareMyPhoneNumber: String { return self._s[1019]! }
    public var Map_Location: String { return self._s[1020]! }
    public var Invitation_JoinGroup: String { return self._s[1021]! }
    public var AutoDownloadSettings_Title: String { return self._s[1023]! }
    public var Conversation_DiscardVoiceMessageDescription: String { return self._s[1024]! }
    public var Channel_ErrorAddBlocked: String { return self._s[1025]! }
    public var Conversation_UnblockUser: String { return self._s[1026]! }
    public var EditTheme_Edit_TopInfo: String { return self._s[1027]! }
    public var Watch_Bot_Restart: String { return self._s[1028]! }
    public var TwoStepAuth_Title: String { return self._s[1029]! }
    public var Channel_AdminLog_BanSendMessages: String { return self._s[1030]! }
    public var Checkout_ShippingMethod: String { return self._s[1031]! }
    public var Passport_Identity_OneOfTypeIdentityCard: String { return self._s[1032]! }
    public func PUSH_CHAT_MESSAGE_STICKER(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1033]!, self._r[1033]!, [_1, _2, _3])
    }
    public func Chat_UnsendMyMessagesAlertTitle(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1035]!, self._r[1035]!, [_0])
    }
    public func Channel_Username_LinkHint(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1036]!, self._r[1036]!, [_0])
    }
    public var Appearance_ThemePreview_ChatList_1_Name: String { return self._s[1037]! }
    public var SettingsSearch_Synonyms_Data_AutoplayGifs: String { return self._s[1038]! }
    public var AuthSessions_TerminateOtherSessions: String { return self._s[1039]! }
    public var Contacts_FailedToSendInvitesMessage: String { return self._s[1040]! }
    public var PrivacySettings_TwoStepAuth: String { return self._s[1041]! }
    public var Notification_Exceptions_PreviewAlwaysOn: String { return self._s[1042]! }
    public var SettingsSearch_Synonyms_Privacy_Passcode: String { return self._s[1043]! }
    public var Conversation_EditingMessagePanelMedia: String { return self._s[1044]! }
    public var Checkout_PaymentMethod_Title: String { return self._s[1045]! }
    public var SocksProxySetup_Connection: String { return self._s[1046]! }
    public var Group_MessagePhotoRemoved: String { return self._s[1047]! }
    public var Channel_Stickers_NotFound: String { return self._s[1050]! }
    public var Group_About_Help: String { return self._s[1051]! }
    public var Notification_PassportValueProofOfIdentity: String { return self._s[1052]! }
    public var PeopleNearby_Title: String { return self._s[1054]! }
    public func ApplyLanguage_ChangeLanguageOfficialText(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1055]!, self._r[1055]!, [_1])
    }
    public var CheckoutInfo_ShippingInfoStatePlaceholder: String { return self._s[1057]! }
    public var Notifications_GroupNotificationsExceptionsHelp: String { return self._s[1058]! }
    public var SocksProxySetup_Password: String { return self._s[1059]! }
    public var Notifications_PermissionsEnable: String { return self._s[1060]! }
    public var TwoStepAuth_ChangeEmail: String { return self._s[1062]! }
    public func Channel_AdminLog_MessageInvitedName(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1063]!, self._r[1063]!, [_1])
    }
    public func Time_MonthOfYear_m10(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1065]!, self._r[1065]!, [_0])
    }
    public var Passport_Identity_TypeDriversLicense: String { return self._s[1066]! }
    public var ArchivedPacksAlert_Title: String { return self._s[1067]! }
    public var Wallet_Receive_InvoiceUrlCopied: String { return self._s[1068]! }
    public func Time_PreciseDate_m7(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1069]!, self._r[1069]!, [_1, _2, _3])
    }
    public var PrivacyLastSeenSettings_GroupsAndChannelsHelp: String { return self._s[1070]! }
    public var Privacy_Calls_NeverAllow_Placeholder: String { return self._s[1072]! }
    public var Conversation_StatusTyping: String { return self._s[1073]! }
    public var Broadcast_AdminLog_EmptyText: String { return self._s[1074]! }
    public var Notification_PassportValueProofOfAddress: String { return self._s[1075]! }
    public var UserInfo_CreateNewContact: String { return self._s[1076]! }
    public var Passport_Identity_FrontSide: String { return self._s[1077]! }
    public var Login_PhoneNumberAlreadyAuthorizedSwitch: String { return self._s[1078]! }
    public var Calls_CallTabTitle: String { return self._s[1079]! }
    public var Channel_AdminLog_ChannelEmptyText: String { return self._s[1080]! }
    public func Login_BannedPhoneBody(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1082]!, self._r[1082]!, [_0])
    }
    public var Watch_UserInfo_MuteTitle: String { return self._s[1083]! }
    public var Group_EditAdmin_RankAdminPlaceholder: String { return self._s[1084]! }
    public var SharedMedia_EmptyMusicText: String { return self._s[1085]! }
    public var Wallet_Completed_Text: String { return self._s[1086]! }
    public var PasscodeSettings_AutoLock_IfAwayFor_1minute: String { return self._s[1087]! }
    public var Paint_Stickers: String { return self._s[1088]! }
    public var Privacy_GroupsAndChannels: String { return self._s[1089]! }
    public var ChatList_Context_Delete: String { return self._s[1091]! }
    public var UserInfo_AddContact: String { return self._s[1092]! }
    public func Conversation_MessageViaUser(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1093]!, self._r[1093]!, [_0])
    }
    public var PhoneNumberHelp_ChangeNumber: String { return self._s[1095]! }
    public func ChatList_ClearChatConfirmation(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1097]!, self._r[1097]!, [_0])
    }
    public var DialogList_NoMessagesTitle: String { return self._s[1098]! }
    public var EditProfile_NameAndPhotoHelp: String { return self._s[1099]! }
    public var BlockedUsers_BlockUser: String { return self._s[1100]! }
    public var Notifications_PermissionsOpenSettings: String { return self._s[1101]! }
    public var MediaPicker_UngroupDescription: String { return self._s[1102]! }
    public var Watch_NoConnection: String { return self._s[1103]! }
    public var Month_GenSeptember: String { return self._s[1104]! }
    public var Conversation_ViewGroup: String { return self._s[1106]! }
    public var Channel_AdminLogFilter_EventsLeavingSubscribers: String { return self._s[1109]! }
    public var Privacy_Forwards_AlwaysLink: String { return self._s[1110]! }
    public var Channel_OwnershipTransfer_ErrorAdminsTooMuch: String { return self._s[1111]! }
    public var Passport_FieldOneOf_FinalDelimeter: String { return self._s[1112]! }
    public var Wallet_WordCheck_IncorrectHeader: String { return self._s[1113]! }
    public var MediaPicker_CameraRoll: String { return self._s[1115]! }
    public var Month_GenAugust: String { return self._s[1116]! }
    public var AccessDenied_VideoMessageMicrophone: String { return self._s[1117]! }
    public var SharedMedia_EmptyText: String { return self._s[1118]! }
    public var Map_ShareLiveLocation: String { return self._s[1119]! }
    public var Calls_All: String { return self._s[1120]! }
    public var Appearance_ThemeNight: String { return self._s[1123]! }
    public var Conversation_HoldForAudio: String { return self._s[1124]! }
    public var SettingsSearch_Synonyms_Support: String { return self._s[1127]! }
    public var GroupInfo_GroupHistoryHidden: String { return self._s[1128]! }
    public var SocksProxySetup_Secret: String { return self._s[1129]! }
    public func Activity_RemindAboutChannel(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1130]!, self._r[1130]!, [_0])
    }
    public var Channel_BanList_RestrictedTitle: String { return self._s[1132]! }
    public var Conversation_Location: String { return self._s[1133]! }
    public func AutoDownloadSettings_UpToFor(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1134]!, self._r[1134]!, [_1, _2])
    }
    public var ChatSettings_AutoDownloadPhotos: String { return self._s[1136]! }
    public var SettingsSearch_Synonyms_Privacy_Title: String { return self._s[1137]! }
    public var Notifications_PermissionsText: String { return self._s[1138]! }
    public var SettingsSearch_Synonyms_Data_SaveIncomingPhotos: String { return self._s[1139]! }
    public var Call_Flip: String { return self._s[1140]! }
    public var Channel_AdminLog_CanDeleteMessagesOfOthers: String { return self._s[1142]! }
    public var SocksProxySetup_ProxyStatusConnecting: String { return self._s[1143]! }
    public var PrivacyPhoneNumberSettings_DiscoveryHeader: String { return self._s[1144]! }
    public var Channel_EditAdmin_PermissionPinMessages: String { return self._s[1146]! }
    public var TwoStepAuth_ReEnterPasswordDescription: String { return self._s[1148]! }
    public var Channel_TooMuchBots: String { return self._s[1150]! }
    public var Passport_DeletePassportConfirmation: String { return self._s[1151]! }
    public var Login_InvalidCodeError: String { return self._s[1152]! }
    public var StickerPacksSettings_FeaturedPacks: String { return self._s[1153]! }
    public func ChatList_DeleteSecretChatConfirmation(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1154]!, self._r[1154]!, [_0])
    }
    public func GroupInfo_InvitationLinkAcceptChannel(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1155]!, self._r[1155]!, [_0])
    }
    public var VoiceOver_Navigation_ProxySettings: String { return self._s[1156]! }
    public var Call_CallInProgressTitle: String { return self._s[1157]! }
    public var Month_ShortSeptember: String { return self._s[1158]! }
    public var Watch_ChannelInfo_Title: String { return self._s[1159]! }
    public var ChatList_DeleteSavedMessagesConfirmation: String { return self._s[1162]! }
    public var DialogList_PasscodeLockHelp: String { return self._s[1163]! }
    public var Chat_MultipleTextMessagesDisabled: String { return self._s[1164]! }
    public var Wallet_Receive_Title: String { return self._s[1165]! }
    public var Notifications_Badge_IncludePublicGroups: String { return self._s[1166]! }
    public var Channel_AdminLogFilter_EventsTitle: String { return self._s[1167]! }
    public var PhotoEditor_CropReset: String { return self._s[1168]! }
    public var Group_Username_CreatePrivateLinkHelp: String { return self._s[1170]! }
    public var Channel_Management_LabelEditor: String { return self._s[1171]! }
    public var Passport_Identity_LatinNameHelp: String { return self._s[1173]! }
    public var PhotoEditor_HighlightsTool: String { return self._s[1174]! }
    public var Wallet_Info_WalletCreated: String { return self._s[1175]! }
    public var UserInfo_Title: String { return self._s[1176]! }
    public var ChatList_HideAction: String { return self._s[1177]! }
    public var AccessDenied_Title: String { return self._s[1178]! }
    public var DialogList_SearchLabel: String { return self._s[1179]! }
    public var Group_Setup_HistoryHidden: String { return self._s[1180]! }
    public var TwoStepAuth_PasswordChangeSuccess: String { return self._s[1181]! }
    public var State_Updating: String { return self._s[1183]! }
    public var Contacts_TabTitle: String { return self._s[1184]! }
    public var Notifications_Badge_CountUnreadMessages: String { return self._s[1186]! }
    public var GroupInfo_GroupHistory: String { return self._s[1187]! }
    public var Conversation_UnsupportedMediaPlaceholder: String { return self._s[1188]! }
    public var Wallpaper_SetColor: String { return self._s[1189]! }
    public var CheckoutInfo_ShippingInfoCountry: String { return self._s[1190]! }
    public var SettingsSearch_Synonyms_SavedMessages: String { return self._s[1191]! }
    public var Chat_AttachmentLimitReached: String { return self._s[1192]! }
    public var Passport_Identity_OneOfTypeDriversLicense: String { return self._s[1193]! }
    public var Contacts_NotRegisteredSection: String { return self._s[1194]! }
    public func Time_PreciseDate_m4(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1195]!, self._r[1195]!, [_1, _2, _3])
    }
    public var Paint_Clear: String { return self._s[1196]! }
    public var StickerPacksSettings_ArchivedMasks: String { return self._s[1197]! }
    public var SocksProxySetup_Connecting: String { return self._s[1198]! }
    public var ExplicitContent_AlertChannel: String { return self._s[1199]! }
    public var CreatePoll_AllOptionsAdded: String { return self._s[1200]! }
    public var Conversation_Contact: String { return self._s[1201]! }
    public var Login_CodeExpired: String { return self._s[1202]! }
    public var Passport_DiscardMessageAction: String { return self._s[1203]! }
    public var ChatList_Context_Unpin: String { return self._s[1204]! }
    public var Channel_AdminLog_MessagePreviousDescription: String { return self._s[1205]! }
    public func VoiceOver_Chat_MusicFrom(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1206]!, self._r[1206]!, [_0])
    }
    public var Channel_AdminLog_EmptyMessageText: String { return self._s[1207]! }
    public var SettingsSearch_Synonyms_Data_NetworkUsage: String { return self._s[1208]! }
    public func Group_EditAdmin_RankInfo(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1209]!, self._r[1209]!, [_0])
    }
    public var Month_ShortApril: String { return self._s[1210]! }
    public var AuthSessions_CurrentSession: String { return self._s[1211]! }
    public var Chat_AttachmentMultipleFilesDisabled: String { return self._s[1214]! }
    public var Wallet_Navigation_Cancel: String { return self._s[1216]! }
    public var WallpaperPreview_CropTopText: String { return self._s[1217]! }
    public var PrivacySettings_DeleteAccountIfAwayFor: String { return self._s[1218]! }
    public var CheckoutInfo_ShippingInfoTitle: String { return self._s[1219]! }
    public func Conversation_ScheduleMessage_SendOn(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1220]!, self._r[1220]!, [_0, _1])
    }
    public var Appearance_ThemePreview_Chat_2_Text: String { return self._s[1221]! }
    public var Channel_Setup_TypePrivate: String { return self._s[1223]! }
    public var Forward_ChannelReadOnly: String { return self._s[1226]! }
    public var PhotoEditor_CurvesBlue: String { return self._s[1227]! }
    public var AddContact_SharedContactException: String { return self._s[1228]! }
    public var UserInfo_BotPrivacy: String { return self._s[1230]! }
    public var Wallet_CreateInvoice_Title: String { return self._s[1231]! }
    public var Notification_PassportValueEmail: String { return self._s[1232]! }
    public var EmptyGroupInfo_Subtitle: String { return self._s[1233]! }
    public var GroupPermission_NewTitle: String { return self._s[1234]! }
    public var CallFeedback_ReasonDropped: String { return self._s[1235]! }
    public var GroupInfo_Permissions_AddException: String { return self._s[1236]! }
    public var Channel_SignMessages_Help: String { return self._s[1238]! }
    public var Undo_ChatDeleted: String { return self._s[1240]! }
    public var Conversation_ChatBackground: String { return self._s[1241]! }
    public func Wallet_WordCheck_Text(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1242]!, self._r[1242]!, [_1, _2, _3])
    }
    public var ChannelMembers_WhoCanAddMembers_Admins: String { return self._s[1243]! }
    public var FastTwoStepSetup_EmailPlaceholder: String { return self._s[1244]! }
    public var Passport_Language_pt: String { return self._s[1245]! }
    public var VoiceOver_Chat_YourVoiceMessage: String { return self._s[1246]! }
    public var NotificationsSound_Popcorn: String { return self._s[1249]! }
    public var AutoNightTheme_Disabled: String { return self._s[1250]! }
    public var BlockedUsers_LeavePrefix: String { return self._s[1251]! }
    public var WallpaperPreview_CustomColorTopText: String { return self._s[1252]! }
    public var Contacts_PermissionsSuppressWarningText: String { return self._s[1253]! }
    public var WallpaperSearch_ColorBlue: String { return self._s[1254]! }
    public func CancelResetAccount_TextSMS(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1255]!, self._r[1255]!, [_0])
    }
    public var CheckoutInfo_ErrorNameInvalid: String { return self._s[1256]! }
    public var SocksProxySetup_UseForCalls: String { return self._s[1257]! }
    public var Passport_DeleteDocumentConfirmation: String { return self._s[1259]! }
    public func Conversation_Megabytes(_ _0: Float) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1260]!, self._r[1260]!, ["\(_0)"])
    }
    public var SocksProxySetup_Hostname: String { return self._s[1263]! }
    public var ChatSettings_AutoDownloadSettings_OffForAll: String { return self._s[1264]! }
    public var Compose_NewEncryptedChat: String { return self._s[1265]! }
    public var Login_CodeFloodError: String { return self._s[1266]! }
    public var Calls_TabTitle: String { return self._s[1267]! }
    public var Privacy_ProfilePhoto: String { return self._s[1268]! }
    public var Passport_Language_he: String { return self._s[1269]! }
    public func Conversation_SetReminder_RemindToday(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1270]!, self._r[1270]!, [_0])
    }
    public var GroupPermission_Title: String { return self._s[1271]! }
    public func Channel_AdminLog_MessageGroupPreHistoryHidden(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1272]!, self._r[1272]!, [_0])
    }
    public var Wallet_TransactionInfo_SenderHeader: String { return self._s[1273]! }
    public var GroupPermission_NoChangeInfo: String { return self._s[1274]! }
    public var ChatList_DeleteForCurrentUser: String { return self._s[1275]! }
    public var Tour_Text1: String { return self._s[1276]! }
    public var Channel_EditAdmin_TransferOwnership: String { return self._s[1277]! }
    public var Month_ShortFebruary: String { return self._s[1278]! }
    public var TwoStepAuth_EmailSkip: String { return self._s[1279]! }
    public func Wallet_Time_PreciseDate_m4(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1280]!, self._r[1280]!, [_1, _2, _3])
    }
    public var NotificationsSound_Glass: String { return self._s[1281]! }
    public var Appearance_ThemeNightBlue: String { return self._s[1282]! }
    public var CheckoutInfo_Pay: String { return self._s[1283]! }
    public var Invite_LargeRecipientsCountWarning: String { return self._s[1285]! }
    public var Call_CallAgain: String { return self._s[1287]! }
    public var AttachmentMenu_SendAsFile: String { return self._s[1288]! }
    public var AccessDenied_MicrophoneRestricted: String { return self._s[1289]! }
    public var Passport_InvalidPasswordError: String { return self._s[1290]! }
    public var Watch_Message_Game: String { return self._s[1291]! }
    public var Stickers_Install: String { return self._s[1292]! }
    public var VoiceOver_Chat_Message: String { return self._s[1293]! }
    public var PrivacyLastSeenSettings_NeverShareWith: String { return self._s[1294]! }
    public var Passport_Identity_ResidenceCountry: String { return self._s[1296]! }
    public var Notifications_GroupNotificationsHelp: String { return self._s[1297]! }
    public var AuthSessions_OtherSessions: String { return self._s[1298]! }
    public var Channel_Username_Help: String { return self._s[1299]! }
    public var Camera_Title: String { return self._s[1300]! }
    public var GroupInfo_SetGroupPhotoDelete: String { return self._s[1302]! }
    public var Privacy_ProfilePhoto_NeverShareWith_Title: String { return self._s[1303]! }
    public var Channel_AdminLog_SendPolls: String { return self._s[1304]! }
    public var Channel_AdminLog_TitleAllEvents: String { return self._s[1305]! }
    public var Channel_EditAdmin_PermissionInviteMembers: String { return self._s[1306]! }
    public var Contacts_MemberSearchSectionTitleGroup: String { return self._s[1307]! }
    public var ScheduledMessages_DeleteMany: String { return self._s[1308]! }
    public var Conversation_RestrictedStickers: String { return self._s[1309]! }
    public var Notifications_ExceptionsResetToDefaults: String { return self._s[1311]! }
    public var UserInfo_TelegramCall: String { return self._s[1313]! }
    public var TwoStepAuth_SetupResendEmailCode: String { return self._s[1314]! }
    public var CreatePoll_OptionsHeader: String { return self._s[1315]! }
    public var SettingsSearch_Synonyms_Data_CallsUseLessData: String { return self._s[1316]! }
    public var ArchivedChats_IntroTitle1: String { return self._s[1317]! }
    public var Privacy_GroupsAndChannels_AlwaysAllow_Title: String { return self._s[1318]! }
    public var Passport_Identity_EditPersonalDetails: String { return self._s[1319]! }
    public func Time_PreciseDate_m1(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1320]!, self._r[1320]!, [_1, _2, _3])
    }
    public var Wallet_Month_GenAugust: String { return self._s[1321]! }
    public var Settings_SaveEditedPhotos: String { return self._s[1322]! }
    public var TwoStepAuth_ConfirmationTitle: String { return self._s[1323]! }
    public var Privacy_GroupsAndChannels_NeverAllow_Title: String { return self._s[1324]! }
    public var Conversation_MessageDialogRetry: String { return self._s[1325]! }
    public var ChatList_Context_MarkAsUnread: String { return self._s[1326]! }
    public var Conversation_DiscardVoiceMessageAction: String { return self._s[1327]! }
    public var Permissions_PeopleNearbyTitle_v0: String { return self._s[1328]! }
    public var Group_Setup_TypeHeader: String { return self._s[1329]! }
    public var Paint_RecentStickers: String { return self._s[1330]! }
    public var PhotoEditor_GrainTool: String { return self._s[1331]! }
    public var CheckoutInfo_ShippingInfoState: String { return self._s[1332]! }
    public var EmptyGroupInfo_Line4: String { return self._s[1333]! }
    public var Watch_AuthRequired: String { return self._s[1335]! }
    public func Passport_Email_UseTelegramEmail(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1336]!, self._r[1336]!, [_0])
    }
    public var Conversation_EncryptedDescriptionTitle: String { return self._s[1337]! }
    public var ChannelIntro_Text: String { return self._s[1338]! }
    public var DialogList_DeleteBotConfirmation: String { return self._s[1339]! }
    public var GroupPermission_NoSendMedia: String { return self._s[1340]! }
    public var Calls_AddTab: String { return self._s[1341]! }
    public var Message_ReplyActionButtonShowReceipt: String { return self._s[1342]! }
    public var Channel_AdminLog_EmptyFilterText: String { return self._s[1343]! }
    public var Conversation_WalletRequiredSetup: String { return self._s[1344]! }
    public var Notification_MessageLifetime1d: String { return self._s[1345]! }
    public var Notifications_ChannelNotificationsExceptionsHelp: String { return self._s[1346]! }
    public var Channel_BanUser_PermissionsHeader: String { return self._s[1347]! }
    public var Passport_Identity_GenderFemale: String { return self._s[1348]! }
    public var BlockedUsers_BlockTitle: String { return self._s[1349]! }
    public func PUSH_CHANNEL_MESSAGE_GIF(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1350]!, self._r[1350]!, [_1])
    }
    public var Weekday_Yesterday: String { return self._s[1351]! }
    public var WallpaperSearch_ColorBlack: String { return self._s[1352]! }
    public var Settings_Context_Logout: String { return self._s[1353]! }
    public var Wallet_Info_UnknownTransaction: String { return self._s[1354]! }
    public var ChatList_ArchiveAction: String { return self._s[1355]! }
    public var AutoNightTheme_Scheduled: String { return self._s[1356]! }
    public func Login_PhoneGenericEmailBody(_ _1: String, _ _2: String, _ _3: String, _ _4: String, _ _5: String, _ _6: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1357]!, self._r[1357]!, [_1, _2, _3, _4, _5, _6])
    }
    public var EditTheme_ThemeTemplateAlertTitle: String { return self._s[1358]! }
    public var Wallet_Receive_CreateInvoice: String { return self._s[1359]! }
    public var PrivacyPolicy_DeclineDeleteNow: String { return self._s[1360]! }
    public func PUSH_CHAT_JOINED(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1361]!, self._r[1361]!, [_1, _2])
    }
    public var CreatePoll_Create: String { return self._s[1362]! }
    public var Channel_Members_AddBannedErrorAdmin: String { return self._s[1363]! }
    public func Notification_CallFormat(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1364]!, self._r[1364]!, [_1, _2])
    }
    public var ScheduledMessages_ClearAllConfirmation: String { return self._s[1365]! }
    public var Checkout_ErrorProviderAccountInvalid: String { return self._s[1366]! }
    public var Notifications_InAppNotificationsSounds: String { return self._s[1368]! }
    public func PUSH_PINNED_GAME_SCORE(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1369]!, self._r[1369]!, [_1])
    }
    public var Preview_OpenInInstagram: String { return self._s[1370]! }
    public var Notification_MessageLifetimeRemovedOutgoing: String { return self._s[1371]! }
    public func PUSH_CHAT_ADD_MEMBER(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1372]!, self._r[1372]!, [_1, _2, _3])
    }
    public func Passport_PrivacyPolicy(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1373]!, self._r[1373]!, [_1, _2])
    }
    public var Channel_AdminLog_InfoPanelAlertTitle: String { return self._s[1374]! }
    public var ArchivedChats_IntroText3: String { return self._s[1375]! }
    public var ChatList_UndoArchiveHiddenText: String { return self._s[1376]! }
    public var NetworkUsageSettings_TotalSection: String { return self._s[1377]! }
    public var Wallet_Month_GenSeptember: String { return self._s[1378]! }
    public var Channel_Setup_TypePrivateHelp: String { return self._s[1379]! }
    public func PUSH_CHAT_MESSAGE_POLL(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1380]!, self._r[1380]!, [_1, _2, _3])
    }
    public var Privacy_GroupsAndChannels_NeverAllow_Placeholder: String { return self._s[1382]! }
    public var FastTwoStepSetup_HintSection: String { return self._s[1383]! }
    public var Wallpaper_PhotoLibrary: String { return self._s[1384]! }
    public var TwoStepAuth_SetupResendEmailCodeAlert: String { return self._s[1385]! }
    public var Gif_NoGifsFound: String { return self._s[1386]! }
    public var Watch_LastSeen_WithinAMonth: String { return self._s[1387]! }
    public var VoiceOver_MessageContextDelete: String { return self._s[1388]! }
    public var EditTheme_Preview: String { return self._s[1389]! }
    public var GroupInfo_ActionPromote: String { return self._s[1390]! }
    public var PasscodeSettings_SimplePasscode: String { return self._s[1391]! }
    public var GroupInfo_Permissions_Title: String { return self._s[1392]! }
    public var Permissions_ContactsText_v0: String { return self._s[1393]! }
    public var PrivacyPhoneNumberSettings_CustomDisabledHelp: String { return self._s[1394]! }
    public var SettingsSearch_Synonyms_Notifications_BadgeIncludeMutedPublicGroups: String { return self._s[1395]! }
    public var PrivacySettings_DataSettingsHelp: String { return self._s[1398]! }
    public var Passport_FieldEmailHelp: String { return self._s[1399]! }
    public func Activity_RemindAboutUser(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1400]!, self._r[1400]!, [_0])
    }
    public var Passport_Identity_GenderPlaceholder: String { return self._s[1401]! }
    public var Weekday_ShortSaturday: String { return self._s[1402]! }
    public var ContactInfo_PhoneLabelMain: String { return self._s[1403]! }
    public var Watch_Conversation_UserInfo: String { return self._s[1404]! }
    public var CheckoutInfo_ShippingInfoCityPlaceholder: String { return self._s[1405]! }
    public var PrivacyLastSeenSettings_Title: String { return self._s[1406]! }
    public var Conversation_ShareBotLocationConfirmation: String { return self._s[1407]! }
    public var PhotoEditor_VignetteTool: String { return self._s[1408]! }
    public var Passport_Address_Street1Placeholder: String { return self._s[1409]! }
    public var Passport_Language_et: String { return self._s[1410]! }
    public var AppUpgrade_Running: String { return self._s[1411]! }
    public var Channel_DiscussionGroup_Info: String { return self._s[1413]! }
    public var EditTheme_Create_Preview_IncomingReplyName: String { return self._s[1414]! }
    public var Passport_Language_bg: String { return self._s[1415]! }
    public var Stickers_NoStickersFound: String { return self._s[1417]! }
    public func PUSH_CHANNEL_MESSAGE_TEXT(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1419]!, self._r[1419]!, [_1, _2])
    }
    public func VoiceOver_Chat_ContactFrom(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1420]!, self._r[1420]!, [_0])
    }
    public var Wallet_Month_GenJuly: String { return self._s[1421]! }
    public var Wallet_Receive_AddressHeader: String { return self._s[1422]! }
    public var Wallet_Send_AmountText: String { return self._s[1423]! }
    public var Settings_About: String { return self._s[1424]! }
    public func Channel_AdminLog_MessageRestricted(_ _0: String, _ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1425]!, self._r[1425]!, [_0, _1, _2])
    }
    public var ChatList_Context_MarkAsRead: String { return self._s[1427]! }
    public var KeyCommand_NewMessage: String { return self._s[1428]! }
    public var Group_ErrorAddBlocked: String { return self._s[1429]! }
    public func Message_PaymentSent(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1430]!, self._r[1430]!, [_0])
    }
    public var Map_LocationTitle: String { return self._s[1431]! }
    public var ReportGroupLocation_Title: String { return self._s[1432]! }
    public var CallSettings_UseLessDataLongDescription: String { return self._s[1433]! }
    public var Cache_ClearProgress: String { return self._s[1434]! }
    public func Channel_Management_ErrorNotMember(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1435]!, self._r[1435]!, [_0])
    }
    public var GroupRemoved_AddToGroup: String { return self._s[1436]! }
    public var Passport_UpdateRequiredError: String { return self._s[1437]! }
    public var Wallet_SecureStorageNotAvailable_Text: String { return self._s[1438]! }
    public func PUSH_MESSAGE_DOC(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1439]!, self._r[1439]!, [_1])
    }
    public var Notifications_PermissionsSuppressWarningText: String { return self._s[1441]! }
    public var Passport_Identity_MainPageHelp: String { return self._s[1442]! }
    public var Conversation_StatusKickedFromGroup: String { return self._s[1443]! }
    public var Passport_Language_ka: String { return self._s[1444]! }
    public func Wallet_Time_PreciseDate_m12(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1445]!, self._r[1445]!, [_1, _2, _3])
    }
    public var Call_Decline: String { return self._s[1446]! }
    public var SocksProxySetup_ProxyEnabled: String { return self._s[1447]! }
    public func AuthCode_Alert(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1450]!, self._r[1450]!, [_0])
    }
    public var CallFeedback_Send: String { return self._s[1451]! }
    public var EditTheme_EditTitle: String { return self._s[1452]! }
    public func Channel_AdminLog_MessagePromotedNameUsername(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1453]!, self._r[1453]!, [_1, _2])
    }
    public var Passport_Phone_UseTelegramNumberHelp: String { return self._s[1454]! }
    public func Wallet_Updated_TodayAt(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1456]!, self._r[1456]!, [_0])
    }
    public var SettingsSearch_Synonyms_Data_Title: String { return self._s[1457]! }
    public var Passport_DeletePassport: String { return self._s[1458]! }
    public var Appearance_AppIconFilled: String { return self._s[1459]! }
    public var Privacy_Calls_P2PAlways: String { return self._s[1460]! }
    public var Month_ShortDecember: String { return self._s[1461]! }
    public var Channel_AdminLog_CanEditMessages: String { return self._s[1463]! }
    public func Contacts_AccessDeniedHelpLandscape(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1464]!, self._r[1464]!, [_0])
    }
    public var Channel_Stickers_Searching: String { return self._s[1465]! }
    public var Conversation_EncryptedDescription1: String { return self._s[1466]! }
    public var Conversation_EncryptedDescription2: String { return self._s[1467]! }
    public var PasscodeSettings_PasscodeOptions: String { return self._s[1468]! }
    public var Conversation_EncryptedDescription3: String { return self._s[1470]! }
    public var PhotoEditor_SharpenTool: String { return self._s[1471]! }
    public func Conversation_AddNameToContacts(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1472]!, self._r[1472]!, [_0])
    }
    public var Conversation_EncryptedDescription4: String { return self._s[1474]! }
    public var Channel_Members_AddMembers: String { return self._s[1475]! }
    public var Wallpaper_Search: String { return self._s[1476]! }
    public var Weekday_Friday: String { return self._s[1477]! }
    public var Privacy_ContactsSync: String { return self._s[1478]! }
    public var SettingsSearch_Synonyms_Privacy_Data_ContactsReset: String { return self._s[1479]! }
    public var ApplyLanguage_ChangeLanguageAction: String { return self._s[1480]! }
    public func Channel_Management_RestrictedBy(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1481]!, self._r[1481]!, [_0])
    }
    public var GroupInfo_Permissions_Removed: String { return self._s[1482]! }
    public var Passport_Identity_GenderMale: String { return self._s[1483]! }
    public func Call_StatusBar(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1484]!, self._r[1484]!, [_0])
    }
    public var Notifications_PermissionsKeepDisabled: String { return self._s[1485]! }
    public var Conversation_JumpToDate: String { return self._s[1486]! }
    public var Contacts_GlobalSearch: String { return self._s[1487]! }
    public var AutoDownloadSettings_ResetHelp: String { return self._s[1488]! }
    public var SettingsSearch_Synonyms_FAQ: String { return self._s[1489]! }
    public var Profile_MessageLifetime1d: String { return self._s[1490]! }
    public func MESSAGE_INVOICE(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1491]!, self._r[1491]!, [_1, _2])
    }
    public var StickerPack_BuiltinPackName: String { return self._s[1494]! }
    public func PUSH_CHAT_MESSAGE_AUDIO(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1495]!, self._r[1495]!, [_1, _2])
    }
    public var VoiceOver_Chat_RecordModeVoiceMessageInfo: String { return self._s[1496]! }
    public var Passport_InfoTitle: String { return self._s[1498]! }
    public var Notifications_PermissionsUnreachableText: String { return self._s[1499]! }
    public func NetworkUsageSettings_CellularUsageSince(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1503]!, self._r[1503]!, [_0])
    }
    public func PUSH_CHAT_MESSAGE_GEO(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1504]!, self._r[1504]!, [_1, _2])
    }
    public var Passport_Address_TypePassportRegistrationUploadScan: String { return self._s[1505]! }
    public var Profile_BotInfo: String { return self._s[1506]! }
    public var Watch_Compose_CreateMessage: String { return self._s[1507]! }
    public var AutoDownloadSettings_VoiceMessagesInfo: String { return self._s[1508]! }
    public var Month_ShortNovember: String { return self._s[1509]! }
    public var Conversation_ScamWarning: String { return self._s[1510]! }
    public var Wallpaper_SetCustomBackground: String { return self._s[1511]! }
    public var Passport_Identity_TranslationsHelp: String { return self._s[1512]! }
    public var NotificationsSound_Chime: String { return self._s[1513]! }
    public var Passport_Language_ko: String { return self._s[1515]! }
    public var InviteText_URL: String { return self._s[1516]! }
    public var TextFormat_Monospace: String { return self._s[1517]! }
    public func Time_PreciseDate_m11(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1518]!, self._r[1518]!, [_1, _2, _3])
    }
    public var EditTheme_Edit_BottomInfo: String { return self._s[1519]! }
    public func Login_WillSendSms(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1520]!, self._r[1520]!, [_0])
    }
    public func Watch_Time_ShortWeekdayAt(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1521]!, self._r[1521]!, [_1, _2])
    }
    public var Wallet_Words_Title: String { return self._s[1522]! }
    public var Wallet_Month_ShortMay: String { return self._s[1523]! }
    public var EditTheme_CreateTitle: String { return self._s[1525]! }
    public var Passport_InfoLearnMore: String { return self._s[1526]! }
    public var TwoStepAuth_EmailPlaceholder: String { return self._s[1527]! }
    public var Passport_Identity_AddIdentityCard: String { return self._s[1528]! }
    public var Your_card_has_expired: String { return self._s[1529]! }
    public var StickerPacksSettings_StickerPacksSection: String { return self._s[1530]! }
    public var GroupInfo_InviteLink_Help: String { return self._s[1531]! }
    public var Conversation_Report: String { return self._s[1535]! }
    public var Notifications_MessageNotificationsSound: String { return self._s[1536]! }
    public var Notification_MessageLifetime1m: String { return self._s[1537]! }
    public var Privacy_ContactsTitle: String { return self._s[1538]! }
    public var Conversation_ShareMyContactInfo: String { return self._s[1539]! }
    public var Wallet_WordCheck_Title: String { return self._s[1540]! }
    public var ChannelMembers_WhoCanAddMembersAdminsHelp: String { return self._s[1541]! }
    public var Channel_Members_Title: String { return self._s[1542]! }
    public var Map_OpenInWaze: String { return self._s[1543]! }
    public var Login_PhoneBannedError: String { return self._s[1544]! }
    public func LiveLocationUpdated_YesterdayAt(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1545]!, self._r[1545]!, [_0])
    }
    public var Group_Management_AddModeratorHelp: String { return self._s[1546]! }
    public var AutoDownloadSettings_WifiTitle: String { return self._s[1547]! }
    public var Common_OK: String { return self._s[1548]! }
    public var Passport_Address_TypeBankStatementUploadScan: String { return self._s[1549]! }
    public var Wallet_Words_NotDoneResponse: String { return self._s[1550]! }
    public var Cache_Music: String { return self._s[1551]! }
    public var SettingsSearch_Synonyms_EditProfile_PhoneNumber: String { return self._s[1552]! }
    public var PasscodeSettings_UnlockWithTouchId: String { return self._s[1553]! }
    public var TwoStepAuth_HintPlaceholder: String { return self._s[1554]! }
    public func PUSH_PINNED_INVOICE(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1555]!, self._r[1555]!, [_1])
    }
    public func Passport_RequestHeader(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1556]!, self._r[1556]!, [_0])
    }
    public func VoiceOver_Chat_ContactOrganization(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1557]!, self._r[1557]!, [_0])
    }
    public var Wallet_Send_ErrorNotEnoughFundsText: String { return self._s[1558]! }
    public var Watch_MessageView_ViewOnPhone: String { return self._s[1560]! }
    public var Privacy_Calls_CustomShareHelp: String { return self._s[1561]! }
    public var Wallet_Receive_CreateInvoiceInfo: String { return self._s[1563]! }
    public var ChangePhoneNumberNumber_Title: String { return self._s[1564]! }
    public var State_ConnectingToProxyInfo: String { return self._s[1565]! }
    public var Message_VideoMessage: String { return self._s[1567]! }
    public var ChannelInfo_DeleteChannel: String { return self._s[1568]! }
    public var ContactInfo_PhoneLabelOther: String { return self._s[1569]! }
    public var Channel_EditAdmin_CannotEdit: String { return self._s[1570]! }
    public var Passport_DeleteAddressConfirmation: String { return self._s[1571]! }
    public func Wallet_Time_PreciseDate_m9(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1572]!, self._r[1572]!, [_1, _2, _3])
    }
    public var WallpaperPreview_SwipeBottomText: String { return self._s[1573]! }
    public var Activity_RecordingAudio: String { return self._s[1574]! }
    public var SettingsSearch_Synonyms_Watch: String { return self._s[1575]! }
    public var PasscodeSettings_TryAgainIn1Minute: String { return self._s[1576]! }
    public var Wallet_Info_Address: String { return self._s[1577]! }
    public func Notification_ChangedGroupName(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1579]!, self._r[1579]!, [_0, _1])
    }
    public func EmptyGroupInfo_Line1(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1583]!, self._r[1583]!, [_0])
    }
    public var Conversation_ApplyLocalization: String { return self._s[1584]! }
    public var UserInfo_AddPhone: String { return self._s[1585]! }
    public var Map_ShareLiveLocationHelp: String { return self._s[1586]! }
    public func Passport_Identity_NativeNameGenericHelp(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1587]!, self._r[1587]!, [_0])
    }
    public var Passport_Scans: String { return self._s[1589]! }
    public var BlockedUsers_Unblock: String { return self._s[1590]! }
    public func PUSH_ENCRYPTION_REQUEST(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1591]!, self._r[1591]!, [_1])
    }
    public var Channel_Management_LabelCreator: String { return self._s[1592]! }
    public var Conversation_ReportSpamAndLeave: String { return self._s[1593]! }
    public var SettingsSearch_Synonyms_EditProfile_Bio: String { return self._s[1594]! }
    public var ChatList_UndoArchiveMultipleTitle: String { return self._s[1595]! }
    public var Passport_Identity_NativeNameGenericTitle: String { return self._s[1596]! }
    public func Login_EmailPhoneBody(_ _0: String, _ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1597]!, self._r[1597]!, [_0, _1, _2])
    }
    public var Login_PhoneNumberHelp: String { return self._s[1598]! }
    public var LastSeen_ALongTimeAgo: String { return self._s[1599]! }
    public var Channel_AdminLog_CanPinMessages: String { return self._s[1600]! }
    public var ChannelIntro_CreateChannel: String { return self._s[1601]! }
    public var Conversation_UnreadMessages: String { return self._s[1602]! }
    public var SettingsSearch_Synonyms_Stickers_ArchivedPacks: String { return self._s[1603]! }
    public var Channel_AdminLog_EmptyText: String { return self._s[1604]! }
    public var Theme_Context_Apply: String { return self._s[1605]! }
    public var Notification_GroupActivated: String { return self._s[1606]! }
    public var NotificationSettings_ContactJoinedInfo: String { return self._s[1607]! }
    public var Wallet_Intro_CreateWallet: String { return self._s[1608]! }
    public func Notification_PinnedContactMessage(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1609]!, self._r[1609]!, [_0])
    }
    public func DownloadingStatus(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1610]!, self._r[1610]!, [_0, _1])
    }
    public var GroupInfo_ConvertToSupergroup: String { return self._s[1612]! }
    public func PrivacyPolicy_AgeVerificationMessage(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1613]!, self._r[1613]!, [_0])
    }
    public var Undo_DeletedChannel: String { return self._s[1614]! }
    public var CallFeedback_AddComment: String { return self._s[1615]! }
    public func Conversation_OpenBotLinkAllowMessages(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1616]!, self._r[1616]!, [_0])
    }
    public var Document_TargetConfirmationFormat: String { return self._s[1617]! }
    public func Call_StatusOngoing(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1618]!, self._r[1618]!, [_0])
    }
    public var LogoutOptions_SetPasscodeTitle: String { return self._s[1619]! }
    public func PUSH_CHAT_MESSAGE_GAME_SCORE(_ _1: String, _ _2: String, _ _3: String, _ _4: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1620]!, self._r[1620]!, [_1, _2, _3, _4])
    }
    public var Wallet_SecureStorageChanged_PasscodeText: String { return self._s[1621]! }
    public var Theme_ErrorNotFound: String { return self._s[1622]! }
    public var Contacts_SortByName: String { return self._s[1623]! }
    public var SettingsSearch_Synonyms_Privacy_Forwards: String { return self._s[1624]! }
    public func CHAT_MESSAGE_INVOICE(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1626]!, self._r[1626]!, [_1, _2, _3])
    }
    public var Notification_Exceptions_RemoveFromExceptions: String { return self._s[1627]! }
    public var ScheduledMessages_EditTime: String { return self._s[1628]! }
    public var Conversation_ClearSelfHistory: String { return self._s[1629]! }
    public var Checkout_NewCard_PostcodePlaceholder: String { return self._s[1630]! }
    public var PasscodeSettings_DoNotMatch: String { return self._s[1631]! }
    public var Stickers_SuggestNone: String { return self._s[1632]! }
    public var ChatSettings_Cache: String { return self._s[1633]! }
    public var Settings_SaveIncomingPhotos: String { return self._s[1634]! }
    public var Media_ShareThisPhoto: String { return self._s[1635]! }
    public var Chat_SlowmodeTooltipPending: String { return self._s[1636]! }
    public var InfoPlist_NSContactsUsageDescription: String { return self._s[1637]! }
    public var Conversation_ContextMenuCopyLink: String { return self._s[1638]! }
    public var PrivacyPolicy_AgeVerificationTitle: String { return self._s[1639]! }
    public var SettingsSearch_Synonyms_Stickers_Masks: String { return self._s[1640]! }
    public var TwoStepAuth_SetupPasswordEnterPasswordNew: String { return self._s[1641]! }
    public func Wallet_SecureStorageReset_BiometryText(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1642]!, self._r[1642]!, [_0])
    }
    public var Permissions_CellularDataTitle_v0: String { return self._s[1643]! }
    public var WallpaperSearch_ColorWhite: String { return self._s[1645]! }
    public var Channel_AdminLog_DefaultRestrictionsUpdated: String { return self._s[1646]! }
    public var Conversation_ErrorInaccessibleMessage: String { return self._s[1647]! }
    public var Map_OpenIn: String { return self._s[1648]! }
    public func PUSH_PHONE_CALL_MISSED(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1651]!, self._r[1651]!, [_1])
    }
    public func ChannelInfo_AddParticipantConfirmation(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1652]!, self._r[1652]!, [_0])
    }
    public var GroupInfo_Permissions_SlowmodeHeader: String { return self._s[1653]! }
    public var MessagePoll_LabelClosed: String { return self._s[1654]! }
    public var GroupPermission_PermissionGloballyDisabled: String { return self._s[1656]! }
    public var Wallet_Send_SendAnyway: String { return self._s[1657]! }
    public var Passport_Identity_MiddleNamePlaceholder: String { return self._s[1658]! }
    public var UserInfo_FirstNamePlaceholder: String { return self._s[1659]! }
    public var PrivacyLastSeenSettings_WhoCanSeeMyTimestamp: String { return self._s[1660]! }
    public var Login_SelectCountry_Title: String { return self._s[1661]! }
    public var Channel_EditAdmin_PermissionBanUsers: String { return self._s[1662]! }
    public func Conversation_OpenBotLinkLogin(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1663]!, self._r[1663]!, [_1, _2])
    }
    public var Channel_AdminLog_ChangeInfo: String { return self._s[1664]! }
    public var Watch_Suggestion_BRB: String { return self._s[1665]! }
    public var Passport_Identity_EditIdentityCard: String { return self._s[1666]! }
    public var Contacts_PermissionsTitle: String { return self._s[1667]! }
    public var Conversation_RestrictedInline: String { return self._s[1668]! }
    public var StickerPack_ViewPack: String { return self._s[1670]! }
    public var Wallet_UnknownError: String { return self._s[1671]! }
    public func Update_AppVersion(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1672]!, self._r[1672]!, [_0])
    }
    public var Compose_NewChannel: String { return self._s[1674]! }
    public var ChatSettings_AutoDownloadSettings_TypePhoto: String { return self._s[1677]! }
    public var Conversation_ReportSpamGroupConfirmation: String { return self._s[1679]! }
    public var Channel_Info_Stickers: String { return self._s[1680]! }
    public var AutoNightTheme_PreferredTheme: String { return self._s[1681]! }
    public var PrivacyPolicy_AgeVerificationAgree: String { return self._s[1682]! }
    public var Passport_DeletePersonalDetails: String { return self._s[1683]! }
    public var LogoutOptions_AddAccountTitle: String { return self._s[1684]! }
    public var Channel_DiscussionGroupInfo: String { return self._s[1685]! }
    public var Group_EditAdmin_RankOwnerPlaceholder: String { return self._s[1686]! }
    public var Conversation_SearchNoResults: String { return self._s[1688]! }
    public var MessagePoll_LabelAnonymous: String { return self._s[1689]! }
    public var Channel_Members_AddAdminErrorNotAMember: String { return self._s[1690]! }
    public var Login_Code: String { return self._s[1691]! }
    public var EditTheme_Create_BottomInfo: String { return self._s[1692]! }
    public var Watch_Suggestion_WhatsUp: String { return self._s[1693]! }
    public var Weekday_ShortThursday: String { return self._s[1694]! }
    public var Resolve_ErrorNotFound: String { return self._s[1696]! }
    public var LastSeen_Offline: String { return self._s[1697]! }
    public var PeopleNearby_NoMembers: String { return self._s[1698]! }
    public var GroupPermission_AddMembersNotAvailable: String { return self._s[1699]! }
    public var Privacy_Calls_AlwaysAllow_Title: String { return self._s[1700]! }
    public var GroupInfo_Title: String { return self._s[1702]! }
    public var NotificationsSound_Note: String { return self._s[1703]! }
    public var Conversation_EditingMessagePanelTitle: String { return self._s[1704]! }
    public var Watch_Message_Poll: String { return self._s[1705]! }
    public var Privacy_Calls: String { return self._s[1706]! }
    public func Channel_AdminLog_MessageRankUsername(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1707]!, self._r[1707]!, [_1, _2, _3])
    }
    public var Month_ShortAugust: String { return self._s[1708]! }
    public var TwoStepAuth_SetPasswordHelp: String { return self._s[1709]! }
    public var Notifications_Reset: String { return self._s[1710]! }
    public var Conversation_Pin: String { return self._s[1711]! }
    public var Passport_Language_lv: String { return self._s[1712]! }
    public var Permissions_PeopleNearbyAllowInSettings_v0: String { return self._s[1713]! }
    public var BlockedUsers_Info: String { return self._s[1714]! }
    public var SettingsSearch_Synonyms_Data_AutoplayVideos: String { return self._s[1716]! }
    public var Watch_Conversation_Unblock: String { return self._s[1718]! }
    public func Time_MonthOfYear_m9(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1719]!, self._r[1719]!, [_0])
    }
    public var CloudStorage_Title: String { return self._s[1720]! }
    public var GroupInfo_DeleteAndExitConfirmation: String { return self._s[1721]! }
    public func NetworkUsageSettings_WifiUsageSince(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1722]!, self._r[1722]!, [_0])
    }
    public var Channel_AdminLogFilter_AdminsTitle: String { return self._s[1723]! }
    public var Watch_Suggestion_OnMyWay: String { return self._s[1724]! }
    public var TwoStepAuth_RecoveryEmailTitle: String { return self._s[1725]! }
    public var Passport_Address_EditBankStatement: String { return self._s[1726]! }
    public func Channel_AdminLog_MessageChangedUnlinkedGroup(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1727]!, self._r[1727]!, [_1, _2])
    }
    public var ChatSettings_DownloadInBackgroundInfo: String { return self._s[1728]! }
    public var ShareMenu_Comment: String { return self._s[1729]! }
    public var Permissions_ContactsTitle_v0: String { return self._s[1730]! }
    public var Notifications_PermissionsTitle: String { return self._s[1731]! }
    public var GroupPermission_NoSendLinks: String { return self._s[1732]! }
    public var Privacy_Forwards_NeverAllow_Title: String { return self._s[1733]! }
    public var Wallet_SecureStorageChanged_ImportWallet: String { return self._s[1734]! }
    public var Settings_Support: String { return self._s[1735]! }
    public var Notifications_ChannelNotificationsSound: String { return self._s[1736]! }
    public var SettingsSearch_Synonyms_Data_AutoDownloadReset: String { return self._s[1737]! }
    public var Privacy_Forwards_Preview: String { return self._s[1738]! }
    public var GroupPermission_ApplyAlertAction: String { return self._s[1739]! }
    public var Watch_Stickers_StickerPacks: String { return self._s[1740]! }
    public var Common_Select: String { return self._s[1742]! }
    public var CheckoutInfo_ErrorEmailInvalid: String { return self._s[1743]! }
    public var WallpaperSearch_ColorGray: String { return self._s[1746]! }
    public var ChatAdmins_AllMembersAreAdminsOffHelp: String { return self._s[1747]! }
    public var PasscodeSettings_AutoLock_IfAwayFor_5hours: String { return self._s[1748]! }
    public var Appearance_PreviewReplyAuthor: String { return self._s[1749]! }
    public var TwoStepAuth_RecoveryTitle: String { return self._s[1750]! }
    public var Widget_AuthRequired: String { return self._s[1751]! }
    public var Camera_FlashOn: String { return self._s[1752]! }
    public var Conversation_ContextMenuLookUp: String { return self._s[1753]! }
    public var Channel_Stickers_NotFoundHelp: String { return self._s[1754]! }
    public var Watch_Suggestion_OK: String { return self._s[1755]! }
    public func Username_LinkHint(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1757]!, self._r[1757]!, [_0])
    }
    public func Notification_PinnedLiveLocationMessage(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1759]!, self._r[1759]!, [_0])
    }
    public var TextFormat_Strikethrough: String { return self._s[1760]! }
    public var DialogList_AdLabel: String { return self._s[1761]! }
    public var WatchRemote_NotificationText: String { return self._s[1762]! }
    public var SettingsSearch_Synonyms_Notifications_MessageNotificationsAlert: String { return self._s[1763]! }
    public var Conversation_ReportSpam: String { return self._s[1764]! }
    public var SettingsSearch_Synonyms_Privacy_Data_TopPeers: String { return self._s[1765]! }
    public var Settings_LogoutConfirmationTitle: String { return self._s[1767]! }
    public var PhoneLabel_Title: String { return self._s[1768]! }
    public var Passport_Address_EditRentalAgreement: String { return self._s[1769]! }
    public var Settings_ChangePhoneNumber: String { return self._s[1770]! }
    public var Notifications_ExceptionsTitle: String { return self._s[1771]! }
    public var Notifications_AlertTones: String { return self._s[1772]! }
    public var Call_ReportIncludeLogDescription: String { return self._s[1773]! }
    public var SettingsSearch_Synonyms_Notifications_ResetAllNotifications: String { return self._s[1774]! }
    public var AutoDownloadSettings_PrivateChats: String { return self._s[1775]! }
    public var VoiceOver_Chat_Photo: String { return self._s[1777]! }
    public var TwoStepAuth_AddHintTitle: String { return self._s[1778]! }
    public var ReportPeer_ReasonOther: String { return self._s[1779]! }
    public var ChatList_Context_JoinChannel: String { return self._s[1780]! }
    public var KeyCommand_ScrollDown: String { return self._s[1782]! }
    public var Conversation_ScheduleMessage_Title: String { return self._s[1783]! }
    public func Login_BannedPhoneSubject(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1784]!, self._r[1784]!, [_0])
    }
    public var NetworkUsageSettings_MediaVideoDataSection: String { return self._s[1785]! }
    public var ChannelInfo_DeleteGroupConfirmation: String { return self._s[1786]! }
    public var AuthSessions_LogOut: String { return self._s[1787]! }
    public var Passport_Identity_TypeInternalPassport: String { return self._s[1788]! }
    public var ChatSettings_AutoDownloadVoiceMessages: String { return self._s[1789]! }
    public var Passport_Phone_Title: String { return self._s[1790]! }
    public var ContactList_Context_StartSecretChat: String { return self._s[1791]! }
    public var Settings_PhoneNumber: String { return self._s[1792]! }
    public func Conversation_ScheduleMessage_SendToday(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1793]!, self._r[1793]!, [_0])
    }
    public var NotificationsSound_Alert: String { return self._s[1794]! }
    public var Wallet_SecureStorageChanged_CreateWallet: String { return self._s[1795]! }
    public var WebSearch_SearchNoResults: String { return self._s[1796]! }
    public var Privacy_ProfilePhoto_AlwaysShareWith_Title: String { return self._s[1798]! }
    public var LogoutOptions_AlternativeOptionsSection: String { return self._s[1799]! }
    public var SettingsSearch_Synonyms_Passport: String { return self._s[1800]! }
    public var PhotoEditor_CurvesTool: String { return self._s[1801]! }
    public var Checkout_PaymentMethod: String { return self._s[1803]! }
    public func PUSH_CHAT_ADD_YOU(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1804]!, self._r[1804]!, [_1, _2])
    }
    public var Contacts_AccessDeniedError: String { return self._s[1805]! }
    public var Camera_PhotoMode: String { return self._s[1808]! }
    public var EditTheme_Expand_Preview_IncomingText: String { return self._s[1809]! }
    public var Passport_Address_AddUtilityBill: String { return self._s[1811]! }
    public var CallSettings_OnMobile: String { return self._s[1812]! }
    public var Tour_Text2: String { return self._s[1813]! }
    public func PUSH_CHAT_MESSAGE_ROUND(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1814]!, self._r[1814]!, [_1, _2])
    }
    public var DialogList_EncryptionProcessing: String { return self._s[1816]! }
    public var Permissions_Skip: String { return self._s[1817]! }
    public var Wallet_Words_NotDoneOk: String { return self._s[1818]! }
    public var SecretImage_Title: String { return self._s[1819]! }
    public var Watch_MessageView_Title: String { return self._s[1820]! }
    public var Channel_DiscussionGroupAdd: String { return self._s[1821]! }
    public var AttachmentMenu_Poll: String { return self._s[1822]! }
    public func Notification_GroupInviter(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1823]!, self._r[1823]!, [_0])
    }
    public func Channel_DiscussionGroup_PrivateChannelLink(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1824]!, self._r[1824]!, [_1, _2])
    }
    public var Notification_CallCanceled: String { return self._s[1825]! }
    public var WallpaperPreview_Title: String { return self._s[1826]! }
    public var Privacy_PaymentsClear_PaymentInfo: String { return self._s[1827]! }
    public var Settings_ProxyConnecting: String { return self._s[1828]! }
    public var Settings_CheckPhoneNumberText: String { return self._s[1830]! }
    public var VoiceOver_Chat_YourVideo: String { return self._s[1831]! }
    public var Wallet_Intro_Title: String { return self._s[1832]! }
    public var Profile_MessageLifetime5s: String { return self._s[1833]! }
    public var Username_InvalidCharacters: String { return self._s[1834]! }
    public var VoiceOver_Media_PlaybackRateFast: String { return self._s[1835]! }
    public var ScheduledMessages_ClearAll: String { return self._s[1836]! }
    public var WallpaperPreview_CropBottomText: String { return self._s[1837]! }
    public var AutoDownloadSettings_LimitBySize: String { return self._s[1838]! }
    public var Settings_AddAccount: String { return self._s[1839]! }
    public var Notification_CreatedChannel: String { return self._s[1842]! }
    public func PUSH_CHAT_DELETE_MEMBER(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1843]!, self._r[1843]!, [_1, _2, _3])
    }
    public var Passcode_AppLockedAlert: String { return self._s[1845]! }
    public var StickerPacksSettings_AnimatedStickersInfo: String { return self._s[1846]! }
    public var VoiceOver_Media_PlaybackStop: String { return self._s[1847]! }
    public var Contacts_TopSection: String { return self._s[1848]! }
    public var ChatList_DeleteForEveryoneConfirmationAction: String { return self._s[1849]! }
    public func Conversation_SetReminder_RemindOn(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1850]!, self._r[1850]!, [_0, _1])
    }
    public var Wallet_Info_Receive: String { return self._s[1851]! }
    public var Wallet_Completed_ViewWallet: String { return self._s[1852]! }
    public func Time_MonthOfYear_m6(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1853]!, self._r[1853]!, [_0])
    }
    public var ReportPeer_ReasonSpam: String { return self._s[1854]! }
    public var UserInfo_TapToCall: String { return self._s[1855]! }
    public var Conversation_ForwardAuthorHiddenTooltip: String { return self._s[1857]! }
    public var AutoDownloadSettings_DataUsageCustom: String { return self._s[1858]! }
    public var Common_Search: String { return self._s[1859]! }
    public var ScheduledMessages_EmptyPlaceholder: String { return self._s[1860]! }
    public func Channel_AdminLog_MessageChangedGroupGeoLocation(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1861]!, self._r[1861]!, [_0])
    }
    public var Wallet_Month_ShortJuly: String { return self._s[1862]! }
    public var AuthSessions_IncompleteAttemptsInfo: String { return self._s[1863]! }
    public var Message_InvoiceLabel: String { return self._s[1864]! }
    public var Conversation_InputTextPlaceholder: String { return self._s[1865]! }
    public var NetworkUsageSettings_MediaImageDataSection: String { return self._s[1866]! }
    public func Passport_Address_UploadOneOfScan(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1867]!, self._r[1867]!, [_0])
    }
    public var Conversation_Info: String { return self._s[1868]! }
    public var Login_InfoDeletePhoto: String { return self._s[1869]! }
    public var Passport_Language_vi: String { return self._s[1871]! }
    public var UserInfo_ScamUserWarning: String { return self._s[1872]! }
    public var Conversation_Search: String { return self._s[1873]! }
    public var DialogList_DeleteBotConversationConfirmation: String { return self._s[1875]! }
    public var ReportPeer_ReasonPornography: String { return self._s[1876]! }
    public var AutoDownloadSettings_PhotosTitle: String { return self._s[1877]! }
    public var Conversation_SendMessageErrorGroupRestricted: String { return self._s[1878]! }
    public var Map_LiveLocationGroupDescription: String { return self._s[1879]! }
    public var Channel_Setup_TypeHeader: String { return self._s[1880]! }
    public var AuthSessions_LoggedIn: String { return self._s[1881]! }
    public var Privacy_Forwards_AlwaysAllow_Title: String { return self._s[1882]! }
    public var Login_SmsRequestState3: String { return self._s[1883]! }
    public var Passport_Address_EditUtilityBill: String { return self._s[1884]! }
    public var Appearance_ReduceMotionInfo: String { return self._s[1885]! }
    public var Join_ChannelsTooMuch: String { return self._s[1886]! }
    public var Channel_Edit_LinkItem: String { return self._s[1887]! }
    public var Privacy_Calls_P2PNever: String { return self._s[1888]! }
    public var Conversation_AddToReadingList: String { return self._s[1890]! }
    public var Share_MultipleMessagesDisabled: String { return self._s[1891]! }
    public var Message_Animation: String { return self._s[1892]! }
    public var Conversation_DefaultRestrictedMedia: String { return self._s[1893]! }
    public var Map_Unknown: String { return self._s[1894]! }
    public var AutoDownloadSettings_LastDelimeter: String { return self._s[1895]! }
    public func PUSH_PINNED_TEXT(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1896]!, self._r[1896]!, [_1, _2])
    }
    public func Passport_FieldOneOf_Or(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1897]!, self._r[1897]!, [_1, _2])
    }
    public var Call_StatusRequesting: String { return self._s[1898]! }
    public var Conversation_SecretChatContextBotAlert: String { return self._s[1899]! }
    public var SocksProxySetup_ProxyStatusChecking: String { return self._s[1900]! }
    public func PUSH_CHAT_MESSAGE_DOC(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1901]!, self._r[1901]!, [_1, _2])
    }
    public func Notification_PinnedLocationMessage(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1902]!, self._r[1902]!, [_0])
    }
    public var Update_Skip: String { return self._s[1903]! }
    public var Group_Username_RemoveExistingUsernamesInfo: String { return self._s[1904]! }
    public var Message_PinnedPollMessage: String { return self._s[1905]! }
    public var BlockedUsers_Title: String { return self._s[1906]! }
    public func PUSH_CHANNEL_MESSAGE_AUDIO(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1907]!, self._r[1907]!, [_1])
    }
    public var Username_CheckingUsername: String { return self._s[1908]! }
    public var NotificationsSound_Bell: String { return self._s[1909]! }
    public var Conversation_SendMessageErrorFlood: String { return self._s[1910]! }
    public var Weekday_Monday: String { return self._s[1911]! }
    public var SettingsSearch_Synonyms_Notifications_DisplayNamesOnLockScreen: String { return self._s[1912]! }
    public var ChannelMembers_ChannelAdminsTitle: String { return self._s[1913]! }
    public var ChatSettings_Groups: String { return self._s[1914]! }
    public func Conversation_SetReminder_RemindTomorrow(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1915]!, self._r[1915]!, [_0])
    }
    public var Your_card_was_declined: String { return self._s[1916]! }
    public var TwoStepAuth_EnterPasswordHelp: String { return self._s[1918]! }
    public var Wallet_Month_ShortApril: String { return self._s[1919]! }
    public var ChatList_Unmute: String { return self._s[1920]! }
    public var PhotoEditor_CurvesAll: String { return self._s[1921]! }
    public var Weekday_ShortTuesday: String { return self._s[1922]! }
    public var DialogList_Read: String { return self._s[1923]! }
    public var Appearance_AppIconClassic: String { return self._s[1924]! }
    public var ChannelMembers_WhoCanAddMembers_AllMembers: String { return self._s[1925]! }
    public var Passport_Identity_Gender: String { return self._s[1926]! }
    public func Target_ShareGameConfirmationPrivate(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1927]!, self._r[1927]!, [_0])
    }
    public var Target_SelectGroup: String { return self._s[1928]! }
    public func DialogList_EncryptedChatStartedIncoming(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1930]!, self._r[1930]!, [_0])
    }
    public var Passport_Language_en: String { return self._s[1931]! }
    public var AutoDownloadSettings_AutodownloadPhotos: String { return self._s[1932]! }
    public var Channel_Username_CreatePublicLinkHelp: String { return self._s[1933]! }
    public var Login_CancelPhoneVerificationContinue: String { return self._s[1934]! }
    public var ScheduledMessages_SendNow: String { return self._s[1935]! }
    public var Checkout_NewCard_PaymentCard: String { return self._s[1937]! }
    public var Login_InfoHelp: String { return self._s[1938]! }
    public var Contacts_PermissionsSuppressWarningTitle: String { return self._s[1939]! }
    public var SettingsSearch_Synonyms_Stickers_FeaturedPacks: String { return self._s[1940]! }
    public func Channel_AdminLog_MessageChangedLinkedChannel(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1941]!, self._r[1941]!, [_1, _2])
    }
    public var SocksProxySetup_AddProxy: String { return self._s[1944]! }
    public var CreatePoll_Title: String { return self._s[1945]! }
    public var Conversation_ViewTheme: String { return self._s[1946]! }
    public var SettingsSearch_Synonyms_Privacy_Data_SecretChatLinkPreview: String { return self._s[1947]! }
    public var PasscodeSettings_SimplePasscodeHelp: String { return self._s[1948]! }
    public var UserInfo_GroupsInCommon: String { return self._s[1949]! }
    public var Call_AudioRouteHide: String { return self._s[1950]! }
    public func Wallet_Info_TransactionDateHeader(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1952]!, self._r[1952]!, [_1, _2])
    }
    public var ContactInfo_PhoneLabelMobile: String { return self._s[1953]! }
    public func ChatList_LeaveGroupConfirmation(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1954]!, self._r[1954]!, [_0])
    }
    public var TextFormat_Bold: String { return self._s[1955]! }
    public var FastTwoStepSetup_EmailSection: String { return self._s[1956]! }
    public var Notifications_Title: String { return self._s[1957]! }
    public var Group_Username_InvalidTooShort: String { return self._s[1958]! }
    public var Channel_ErrorAddTooMuch: String { return self._s[1959]! }
    public func DialogList_MultipleTypingSuffix(_ _0: Int) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1960]!, self._r[1960]!, ["\(_0)"])
    }
    public var VoiceOver_DiscardPreparedContent: String { return self._s[1962]! }
    public var Stickers_SuggestAdded: String { return self._s[1963]! }
    public var Login_CountryCode: String { return self._s[1964]! }
    public var ChatSettings_AutoPlayVideos: String { return self._s[1965]! }
    public var Map_GetDirections: String { return self._s[1966]! }
    public var Wallet_Receive_ShareInvoiceUrl: String { return self._s[1967]! }
    public var Login_PhoneFloodError: String { return self._s[1968]! }
    public func Time_MonthOfYear_m3(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1969]!, self._r[1969]!, [_0])
    }
    public func Wallet_Time_PreciseDate_m10(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1970]!, self._r[1970]!, [_1, _2, _3])
    }
    public var Settings_SetUsername: String { return self._s[1972]! }
    public var Group_Location_ChangeLocation: String { return self._s[1973]! }
    public var Notification_GroupInviterSelf: String { return self._s[1974]! }
    public var InstantPage_TapToOpenLink: String { return self._s[1975]! }
    public func Notification_ChannelInviter(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1976]!, self._r[1976]!, [_0])
    }
    public var Watch_Suggestion_TalkLater: String { return self._s[1977]! }
    public var SecretChat_Title: String { return self._s[1978]! }
    public var Group_UpgradeNoticeText1: String { return self._s[1979]! }
    public var AuthSessions_Title: String { return self._s[1980]! }
    public func TextFormat_AddLinkText(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1981]!, self._r[1981]!, [_0])
    }
    public var PhotoEditor_CropAuto: String { return self._s[1982]! }
    public var Channel_About_Title: String { return self._s[1983]! }
    public var FastTwoStepSetup_EmailHelp: String { return self._s[1984]! }
    public func Conversation_Bytes(_ _0: Int) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1986]!, self._r[1986]!, ["\(_0)"])
    }
    public var VoiceOver_MessageContextReport: String { return self._s[1987]! }
    public var Conversation_PinMessageAlert_OnlyPin: String { return self._s[1989]! }
    public var Group_Setup_HistoryVisibleHelp: String { return self._s[1990]! }
    public func PUSH_MESSAGE_GIF(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1991]!, self._r[1991]!, [_1])
    }
    public func SharedMedia_SearchNoResultsDescription(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1993]!, self._r[1993]!, [_0])
    }
    public func TwoStepAuth_RecoveryEmailUnavailable(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1994]!, self._r[1994]!, [_0])
    }
    public var Privacy_PaymentsClearInfoHelp: String { return self._s[1995]! }
    public var Presence_online: String { return self._s[1998]! }
    public var PasscodeSettings_Title: String { return self._s[1999]! }
    public var Passport_Identity_ExpiryDatePlaceholder: String { return self._s[2000]! }
    public var Web_OpenExternal: String { return self._s[2001]! }
    public var AutoDownloadSettings_AutoDownload: String { return self._s[2003]! }
    public var Channel_OwnershipTransfer_EnterPasswordText: String { return self._s[2004]! }
    public var LocalGroup_Title: String { return self._s[2005]! }
    public func AutoNightTheme_AutomaticHelp(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2006]!, self._r[2006]!, [_0])
    }
    public var FastTwoStepSetup_PasswordConfirmationPlaceholder: String { return self._s[2007]! }
    public var Map_YouAreHere: String { return self._s[2008]! }
    public func AuthSessions_Message(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2009]!, self._r[2009]!, [_0])
    }
    public func ChatList_DeleteChatConfirmation(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2010]!, self._r[2010]!, [_0])
    }
    public var PrivacyLastSeenSettings_AlwaysShareWith: String { return self._s[2011]! }
    public var Target_InviteToGroupErrorAlreadyInvited: String { return self._s[2012]! }
    public func AuthSessions_AppUnofficial(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2013]!, self._r[2013]!, [_0])
    }
    public func DialogList_LiveLocationSharingTo(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2014]!, self._r[2014]!, [_0])
    }
    public var SocksProxySetup_Username: String { return self._s[2015]! }
    public var Bot_Start: String { return self._s[2016]! }
    public func Channel_AdminLog_EmptyFilterQueryText(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2017]!, self._r[2017]!, [_0])
    }
    public func Channel_AdminLog_MessagePinned(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2018]!, self._r[2018]!, [_0])
    }
    public var Contacts_SortByPresence: String { return self._s[2019]! }
    public var AccentColor_Title: String { return self._s[2021]! }
    public var Conversation_DiscardVoiceMessageTitle: String { return self._s[2022]! }
    public func PUSH_CHAT_CREATED(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2023]!, self._r[2023]!, [_1, _2])
    }
    public func PrivacySettings_LastSeenContactsMinus(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2024]!, self._r[2024]!, [_0])
    }
    public func Channel_AdminLog_MessageChangedLinkedGroup(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2025]!, self._r[2025]!, [_1, _2])
    }
    public var Passport_Email_EnterOtherEmail: String { return self._s[2026]! }
    public var Login_InfoAvatarPhoto: String { return self._s[2027]! }
    public var Privacy_PaymentsClear_ShippingInfo: String { return self._s[2028]! }
    public var Tour_Title4: String { return self._s[2029]! }
    public var Passport_Identity_Translation: String { return self._s[2030]! }
    public var SettingsSearch_Synonyms_Notifications_ContactJoined: String { return self._s[2031]! }
    public var Login_TermsOfServiceLabel: String { return self._s[2033]! }
    public var Passport_Language_it: String { return self._s[2034]! }
    public var KeyCommand_JumpToNextUnreadChat: String { return self._s[2035]! }
    public var Passport_Identity_SelfieHelp: String { return self._s[2036]! }
    public var Conversation_ClearAll: String { return self._s[2038]! }
    public var Wallet_Send_UninitializedText: String { return self._s[2040]! }
    public var Channel_OwnershipTransfer_Title: String { return self._s[2041]! }
    public var TwoStepAuth_FloodError: String { return self._s[2042]! }
    public func PUSH_CHANNEL_MESSAGE_GEO(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2043]!, self._r[2043]!, [_1])
    }
    public var Paint_Delete: String { return self._s[2044]! }
    public func Wallet_Sent_Text(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2045]!, self._r[2045]!, [_0])
    }
    public var Privacy_AddNewPeer: String { return self._s[2046]! }
    public func Channel_AdminLog_MessageRank(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2047]!, self._r[2047]!, [_1])
    }
    public var LogoutOptions_SetPasscodeText: String { return self._s[2048]! }
    public func Passport_AcceptHelp(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2049]!, self._r[2049]!, [_1, _2])
    }
    public var Message_PinnedAudioMessage: String { return self._s[2050]! }
    public func Watch_Time_ShortTodayAt(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2051]!, self._r[2051]!, [_0])
    }
    public var Notification_Mute1hMin: String { return self._s[2052]! }
    public var Notifications_GroupNotificationsSound: String { return self._s[2053]! }
    public var Wallet_Month_GenNovember: String { return self._s[2054]! }
    public var SocksProxySetup_ShareProxyList: String { return self._s[2055]! }
    public var Conversation_MessageEditedLabel: String { return self._s[2056]! }
    public var Notification_Exceptions_AlwaysOff: String { return self._s[2057]! }
    public var Notification_Exceptions_NewException_MessagePreviewHeader: String { return self._s[2058]! }
    public func Channel_AdminLog_MessageAdmin(_ _0: String, _ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2059]!, self._r[2059]!, [_0, _1, _2])
    }
    public var NetworkUsageSettings_ResetStats: String { return self._s[2060]! }
    public func PUSH_MESSAGE_GEOLIVE(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2061]!, self._r[2061]!, [_1])
    }
    public var AccessDenied_LocationTracking: String { return self._s[2062]! }
    public var Month_GenOctober: String { return self._s[2063]! }
    public var GroupInfo_InviteLink_RevokeAlert_Revoke: String { return self._s[2064]! }
    public var EnterPasscode_EnterPasscode: String { return self._s[2065]! }
    public var MediaPicker_TimerTooltip: String { return self._s[2067]! }
    public var SharedMedia_TitleAll: String { return self._s[2068]! }
    public var SettingsSearch_Synonyms_Notifications_ChannelNotificationsExceptions: String { return self._s[2071]! }
    public var Conversation_RestrictedMedia: String { return self._s[2072]! }
    public var AccessDenied_PhotosRestricted: String { return self._s[2073]! }
    public var Privacy_Forwards_WhoCanForward: String { return self._s[2075]! }
    public var ChangePhoneNumberCode_Called: String { return self._s[2076]! }
    public func Notification_PinnedDocumentMessage(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2077]!, self._r[2077]!, [_0])
    }
    public var Conversation_SavedMessages: String { return self._s[2080]! }
    public var Your_cards_expiration_month_is_invalid: String { return self._s[2082]! }
    public var FastTwoStepSetup_PasswordPlaceholder: String { return self._s[2083]! }
    public func Target_ShareGameConfirmationGroup(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2085]!, self._r[2085]!, [_0])
    }
    public var VoiceOver_Chat_YourMessage: String { return self._s[2086]! }
    public func VoiceOver_Chat_Title(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2087]!, self._r[2087]!, [_0])
    }
    public var ReportPeer_AlertSuccess: String { return self._s[2088]! }
    public var PhotoEditor_CropAspectRatioOriginal: String { return self._s[2089]! }
    public func InstantPage_RelatedArticleAuthorAndDateTitle(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2090]!, self._r[2090]!, [_1, _2])
    }
    public var Checkout_PasswordEntry_Title: String { return self._s[2091]! }
    public var PhotoEditor_FadeTool: String { return self._s[2092]! }
    public var Privacy_ContactsReset: String { return self._s[2093]! }
    public func Channel_AdminLog_MessageRestrictedUntil(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2095]!, self._r[2095]!, [_0])
    }
    public var Message_PinnedVideoMessage: String { return self._s[2096]! }
    public var ChatList_Mute: String { return self._s[2097]! }
    public func Wallet_Time_PreciseDate_m5(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2098]!, self._r[2098]!, [_1, _2, _3])
    }
    public var Permissions_CellularDataText_v0: String { return self._s[2099]! }
    public var ShareMenu_SelectChats: String { return self._s[2102]! }
    public var ChatList_Context_Unarchive: String { return self._s[2103]! }
    public var MusicPlayer_VoiceNote: String { return self._s[2104]! }
    public var Conversation_RestrictedText: String { return self._s[2105]! }
    public var SettingsSearch_Synonyms_Privacy_Data_DeleteDrafts: String { return self._s[2106]! }
    public var Wallet_Month_GenApril: String { return self._s[2107]! }
    public var Wallet_Month_ShortMarch: String { return self._s[2108]! }
    public var TwoStepAuth_DisableSuccess: String { return self._s[2109]! }
    public var Cache_Videos: String { return self._s[2110]! }
    public var PrivacySettings_PhoneNumber: String { return self._s[2111]! }
    public var Wallet_Month_GenFebruary: String { return self._s[2112]! }
    public var FeatureDisabled_Oops: String { return self._s[2114]! }
    public var Passport_Address_PostcodePlaceholder: String { return self._s[2115]! }
    public func AddContact_StatusSuccess(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2116]!, self._r[2116]!, [_0])
    }
    public var Stickers_GroupStickersHelp: String { return self._s[2117]! }
    public var GroupPermission_NoSendPolls: String { return self._s[2118]! }
    public var Wallet_Qr_ScanCode: String { return self._s[2119]! }
    public var Message_VideoExpired: String { return self._s[2121]! }
    public var Notifications_Badge: String { return self._s[2122]! }
    public var GroupInfo_GroupHistoryVisible: String { return self._s[2123]! }
    public var Wallet_Receive_AddressCopied: String { return self._s[2124]! }
    public var CreatePoll_OptionPlaceholder: String { return self._s[2125]! }
    public var Username_InvalidTooShort: String { return self._s[2126]! }
    public var EnterPasscode_EnterNewPasscodeChange: String { return self._s[2127]! }
    public var Channel_AdminLog_PinMessages: String { return self._s[2128]! }
    public var ArchivedChats_IntroTitle3: String { return self._s[2129]! }
    public func Notification_MessageLifetimeRemoved(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2130]!, self._r[2130]!, [_1])
    }
    public var Permissions_SiriAllowInSettings_v0: String { return self._s[2131]! }
    public var Conversation_DefaultRestrictedText: String { return self._s[2132]! }
    public var SharedMedia_CategoryDocs: String { return self._s[2135]! }
    public func PUSH_MESSAGE_CONTACT(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2136]!, self._r[2136]!, [_1])
    }
    public var Wallet_Send_UninitializedTitle: String { return self._s[2137]! }
    public var Privacy_Forwards_NeverLink: String { return self._s[2139]! }
    public func Notification_MessageLifetimeChangedOutgoing(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2140]!, self._r[2140]!, [_1])
    }
    public var CheckoutInfo_ErrorShippingNotAvailable: String { return self._s[2141]! }
    public func Time_MonthOfYear_m12(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2142]!, self._r[2142]!, [_0])
    }
    public var ChatSettings_PrivateChats: String { return self._s[2143]! }
    public var SettingsSearch_Synonyms_EditProfile_Logout: String { return self._s[2144]! }
    public var Conversation_PrivateMessageLinkCopied: String { return self._s[2145]! }
    public var Channel_UpdatePhotoItem: String { return self._s[2146]! }
    public var GroupInfo_LeftStatus: String { return self._s[2147]! }
    public var Watch_MessageView_Forward: String { return self._s[2149]! }
    public var ReportPeer_ReasonChildAbuse: String { return self._s[2150]! }
    public var Cache_ClearEmpty: String { return self._s[2152]! }
    public var Localization_LanguageName: String { return self._s[2153]! }
    public var WebSearch_GIFs: String { return self._s[2154]! }
    public var Notifications_DisplayNamesOnLockScreenInfoWithLink: String { return self._s[2155]! }
    public var Username_InvalidStartsWithNumber: String { return self._s[2156]! }
    public var Common_Back: String { return self._s[2157]! }
    public var Passport_Identity_DateOfBirthPlaceholder: String { return self._s[2158]! }
    public var Wallet_Send_Send: String { return self._s[2159]! }
    public func PUSH_CHANNEL_MESSAGE_STICKER(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2160]!, self._r[2160]!, [_1, _2])
    }
    public var Wallet_Info_RefreshErrorTitle: String { return self._s[2161]! }
    public var Wallet_Month_GenJune: String { return self._s[2162]! }
    public var Passport_Email_Help: String { return self._s[2163]! }
    public var Watch_Conversation_Reply: String { return self._s[2165]! }
    public var Conversation_EditingMessageMediaChange: String { return self._s[2167]! }
    public var Passport_Identity_IssueDatePlaceholder: String { return self._s[2168]! }
    public var Channel_BanUser_Unban: String { return self._s[2170]! }
    public var Channel_EditAdmin_PermissionPostMessages: String { return self._s[2171]! }
    public var Group_Username_CreatePublicLinkHelp: String { return self._s[2172]! }
    public var TwoStepAuth_ConfirmEmailCodePlaceholder: String { return self._s[2174]! }
    public var Wallet_Send_AddressHeader: String { return self._s[2175]! }
    public var Passport_Identity_Name: String { return self._s[2176]! }
    public func Channel_DiscussionGroup_HeaderGroupSet(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2177]!, self._r[2177]!, [_0])
    }
    public var GroupRemoved_ViewUserInfo: String { return self._s[2178]! }
    public var Conversation_BlockUser: String { return self._s[2179]! }
    public var Month_GenJanuary: String { return self._s[2180]! }
    public var ChatSettings_TextSize: String { return self._s[2181]! }
    public var Notification_PassportValuePhone: String { return self._s[2182]! }
    public var Passport_Language_ne: String { return self._s[2183]! }
    public var Notification_CallBack: String { return self._s[2184]! }
    public var Wallet_SecureStorageReset_BiometryTouchId: String { return self._s[2185]! }
    public var TwoStepAuth_EmailHelp: String { return self._s[2186]! }
    public func Time_YesterdayAt(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2187]!, self._r[2187]!, [_0])
    }
    public var Channel_Info_Management: String { return self._s[2188]! }
    public var Passport_FieldIdentityUploadHelp: String { return self._s[2189]! }
    public var Stickers_FrequentlyUsed: String { return self._s[2190]! }
    public var Channel_BanUser_PermissionSendMessages: String { return self._s[2191]! }
    public var Passport_Address_OneOfTypeUtilityBill: String { return self._s[2193]! }
    public func LOCAL_CHANNEL_MESSAGE_FWDS(_ _1: String, _ _2: Int) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2194]!, self._r[2194]!, [_1, "\(_2)"])
    }
    public var Passport_Address_EditResidentialAddress: String { return self._s[2195]! }
    public var PrivacyPolicy_DeclineTitle: String { return self._s[2196]! }
    public var CreatePoll_TextHeader: String { return self._s[2197]! }
    public func Checkout_SavePasswordTimeoutAndTouchId(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2198]!, self._r[2198]!, [_0])
    }
    public var PhotoEditor_QualityMedium: String { return self._s[2199]! }
    public var InfoPlist_NSMicrophoneUsageDescription: String { return self._s[2200]! }
    public var Conversation_StatusKickedFromChannel: String { return self._s[2202]! }
    public var CheckoutInfo_ReceiverInfoName: String { return self._s[2203]! }
    public var Group_ErrorSendRestrictedStickers: String { return self._s[2204]! }
    public func Conversation_RestrictedInlineTimed(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2205]!, self._r[2205]!, [_0])
    }
    public func Channel_AdminLog_MessageTransferedName(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2206]!, self._r[2206]!, [_1])
    }
    public var LogoutOptions_LogOutWalletInfo: String { return self._s[2207]! }
    public var Conversation_LinkDialogOpen: String { return self._s[2209]! }
    public var VoiceOver_Chat_PollNoVotes: String { return self._s[2210]! }
    public var Settings_Username: String { return self._s[2212]! }
    public var Conversation_Block: String { return self._s[2214]! }
    public var Wallpaper_Wallpaper: String { return self._s[2215]! }
    public var SocksProxySetup_UseProxy: String { return self._s[2217]! }
    public var Wallet_Send_Confirmation: String { return self._s[2218]! }
    public var EditTheme_UploadEditedTheme: String { return self._s[2219]! }
    public var UserInfo_ShareMyContactInfo: String { return self._s[2220]! }
    public var MessageTimer_Forever: String { return self._s[2221]! }
    public var Privacy_Calls_WhoCanCallMe: String { return self._s[2222]! }
    public var PhotoEditor_DiscardChanges: String { return self._s[2223]! }
    public var AuthSessions_TerminateOtherSessionsHelp: String { return self._s[2224]! }
    public var Passport_Language_da: String { return self._s[2225]! }
    public var SocksProxySetup_PortPlaceholder: String { return self._s[2226]! }
    public func SecretGIF_NotViewedYet(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2227]!, self._r[2227]!, [_0])
    }
    public var Passport_Address_EditPassportRegistration: String { return self._s[2228]! }
    public func Channel_AdminLog_MessageChangedGroupAbout(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2230]!, self._r[2230]!, [_0])
    }
    public var Passport_Identity_ResidenceCountryPlaceholder: String { return self._s[2232]! }
    public var Conversation_SearchByName_Prefix: String { return self._s[2233]! }
    public var Conversation_PinnedPoll: String { return self._s[2234]! }
    public var Conversation_EmptyGifPanelPlaceholder: String { return self._s[2235]! }
    public func PUSH_ENCRYPTION_ACCEPT(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2236]!, self._r[2236]!, [_1])
    }
    public var WallpaperSearch_ColorPurple: String { return self._s[2237]! }
    public var Cache_ByPeerHeader: String { return self._s[2238]! }
    public func Conversation_EncryptedPlaceholderTitleIncoming(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2239]!, self._r[2239]!, [_0])
    }
    public var ChatSettings_AutoDownloadDocuments: String { return self._s[2240]! }
    public var Appearance_ThemePreview_Chat_3_Text: String { return self._s[2243]! }
    public var Wallet_Completed_Title: String { return self._s[2244]! }
    public var Notification_PinnedMessage: String { return self._s[2245]! }
    public var VoiceOver_Chat_RecordModeVideoMessage: String { return self._s[2247]! }
    public var Contacts_SortBy: String { return self._s[2248]! }
    public func PUSH_CHANNEL_MESSAGE_NOTEXT(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2249]!, self._r[2249]!, [_1])
    }
    public func PUSH_MESSAGE_GAME(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2251]!, self._r[2251]!, [_1, _2])
    }
    public var Call_EncryptionKey_Title: String { return self._s[2252]! }
    public var Watch_UserInfo_Service: String { return self._s[2253]! }
    public var SettingsSearch_Synonyms_Data_SaveEditedPhotos: String { return self._s[2255]! }
    public var Conversation_Unpin: String { return self._s[2257]! }
    public var CancelResetAccount_Title: String { return self._s[2258]! }
    public var Map_LiveLocationFor15Minutes: String { return self._s[2259]! }
    public func Time_PreciseDate_m8(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2261]!, self._r[2261]!, [_1, _2, _3])
    }
    public var Group_Members_AddMemberBotErrorNotAllowed: String { return self._s[2262]! }
    public var CallSettings_Title: String { return self._s[2263]! }
    public var SettingsSearch_Synonyms_Appearance_ChatBackground: String { return self._s[2264]! }
    public var PasscodeSettings_EncryptDataHelp: String { return self._s[2266]! }
    public var AutoDownloadSettings_Contacts: String { return self._s[2267]! }
    public func Channel_AdminLog_MessageRankName(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2268]!, self._r[2268]!, [_1, _2])
    }
    public var Passport_Identity_DocumentDetails: String { return self._s[2269]! }
    public var LoginPassword_PasswordHelp: String { return self._s[2270]! }
    public var SettingsSearch_Synonyms_Data_AutoDownloadUsingWifi: String { return self._s[2271]! }
    public var PrivacyLastSeenSettings_CustomShareSettings_Delete: String { return self._s[2272]! }
    public var Checkout_TotalPaidAmount: String { return self._s[2273]! }
    public func FileSize_KB(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2274]!, self._r[2274]!, [_0])
    }
    public var PasscodeSettings_ChangePasscode: String { return self._s[2275]! }
    public var Conversation_SecretLinkPreviewAlert: String { return self._s[2277]! }
    public var Privacy_SecretChatsLinkPreviews: String { return self._s[2278]! }
    public func PUSH_CHANNEL_MESSAGE_DOC(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2279]!, self._r[2279]!, [_1])
    }
    public var VoiceOver_Chat_ReplyToYourMessage: String { return self._s[2280]! }
    public var Contacts_InviteFriends: String { return self._s[2282]! }
    public var Map_ChooseLocationTitle: String { return self._s[2283]! }
    public var Conversation_StopPoll: String { return self._s[2285]! }
    public func WebSearch_SearchNoResultsDescription(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2286]!, self._r[2286]!, [_0])
    }
    public var Call_Camera: String { return self._s[2287]! }
    public var LogoutOptions_ChangePhoneNumberTitle: String { return self._s[2288]! }
    public var Calls_RatingFeedback: String { return self._s[2289]! }
    public var GroupInfo_BroadcastListNamePlaceholder: String { return self._s[2290]! }
    public var Wallet_Alert_OK: String { return self._s[2291]! }
    public var NotificationsSound_Pulse: String { return self._s[2292]! }
    public var Watch_LastSeen_Lately: String { return self._s[2293]! }
    public var ReportGroupLocation_Report: String { return self._s[2296]! }
    public var Widget_NoUsers: String { return self._s[2297]! }
    public var Conversation_UnvotePoll: String { return self._s[2298]! }
    public var SettingsSearch_Synonyms_Privacy_ProfilePhoto: String { return self._s[2300]! }
    public var Privacy_ProfilePhoto_WhoCanSeeMyPhoto: String { return self._s[2301]! }
    public var NotificationsSound_Circles: String { return self._s[2302]! }
    public var PrivacyLastSeenSettings_AlwaysShareWith_Title: String { return self._s[2305]! }
    public var Wallet_Settings_DeleteWallet: String { return self._s[2306]! }
    public var TwoStepAuth_RecoveryCodeExpired: String { return self._s[2307]! }
    public var Proxy_TooltipUnavailable: String { return self._s[2308]! }
    public var Passport_Identity_CountryPlaceholder: String { return self._s[2310]! }
    public var GroupInfo_Permissions_SlowmodeInfo: String { return self._s[2312]! }
    public var Conversation_FileDropbox: String { return self._s[2313]! }
    public var Notifications_ExceptionsUnmuted: String { return self._s[2314]! }
    public var Tour_Text3: String { return self._s[2316]! }
    public var Login_ResetAccountProtected_Title: String { return self._s[2318]! }
    public var GroupPermission_NoSendMessages: String { return self._s[2319]! }
    public var WallpaperSearch_ColorTitle: String { return self._s[2320]! }
    public var ChatAdmins_AllMembersAreAdminsOnHelp: String { return self._s[2321]! }
    public func Conversation_LiveLocationYouAnd(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2323]!, self._r[2323]!, [_0])
    }
    public var GroupInfo_AddParticipantTitle: String { return self._s[2324]! }
    public var Checkout_ShippingOption_Title: String { return self._s[2325]! }
    public var ChatSettings_AutoDownloadTitle: String { return self._s[2326]! }
    public func DialogList_SingleTypingSuffix(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2327]!, self._r[2327]!, [_0])
    }
    public func ChatSettings_AutoDownloadSettings_TypeVideo(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2328]!, self._r[2328]!, [_0])
    }
    public var Channel_Management_LabelAdministrator: String { return self._s[2329]! }
    public var EditTheme_FileReadError: String { return self._s[2330]! }
    public var OwnershipTransfer_ComeBackLater: String { return self._s[2331]! }
    public var PrivacyLastSeenSettings_NeverShareWith_Placeholder: String { return self._s[2332]! }
    public var AutoDownloadSettings_Photos: String { return self._s[2334]! }
    public var Appearance_PreviewIncomingText: String { return self._s[2335]! }
    public var ChatList_Context_MarkAllAsRead: String { return self._s[2336]! }
    public var ChannelInfo_ConfirmLeave: String { return self._s[2337]! }
    public var MediaPicker_MomentsDateRangeSameMonthYearFormat: String { return self._s[2338]! }
    public var Passport_Identity_DocumentNumberPlaceholder: String { return self._s[2339]! }
    public var Channel_AdminLogFilter_EventsNewMembers: String { return self._s[2340]! }
    public var PasscodeSettings_AutoLock_IfAwayFor_5minutes: String { return self._s[2341]! }
    public var GroupInfo_SetGroupPhotoStop: String { return self._s[2342]! }
    public var Notification_SecretChatScreenshot: String { return self._s[2343]! }
    public var AccessDenied_Wallpapers: String { return self._s[2344]! }
    public var ChatList_Context_Mute: String { return self._s[2346]! }
    public var Passport_Address_City: String { return self._s[2347]! }
    public var InfoPlist_NSPhotoLibraryAddUsageDescription: String { return self._s[2348]! }
    public var Appearance_ThemeCarouselClassic: String { return self._s[2349]! }
    public var SocksProxySetup_SecretPlaceholder: String { return self._s[2350]! }
    public var AccessDenied_LocationDisabled: String { return self._s[2351]! }
    public var Group_Location_Title: String { return self._s[2352]! }
    public var SocksProxySetup_HostnamePlaceholder: String { return self._s[2354]! }
    public var GroupInfo_Sound: String { return self._s[2355]! }
    public var ChannelInfo_ScamChannelWarning: String { return self._s[2356]! }
    public var Stickers_RemoveFromFavorites: String { return self._s[2357]! }
    public var Contacts_Title: String { return self._s[2358]! }
    public var EditTheme_ThemeTemplateAlertText: String { return self._s[2359]! }
    public var Passport_Language_fr: String { return self._s[2360]! }
    public var Notifications_ResetAllNotifications: String { return self._s[2361]! }
    public var PrivacySettings_SecurityTitle: String { return self._s[2364]! }
    public var Checkout_NewCard_Title: String { return self._s[2365]! }
    public var Login_HaveNotReceivedCodeInternal: String { return self._s[2366]! }
    public var Conversation_ForwardChats: String { return self._s[2367]! }
    public var Wallet_SecureStorageReset_PasscodeText: String { return self._s[2369]! }
    public var PasscodeSettings_4DigitCode: String { return self._s[2370]! }
    public var Settings_FAQ: String { return self._s[2372]! }
    public var AutoDownloadSettings_DocumentsTitle: String { return self._s[2373]! }
    public var Conversation_ContextMenuForward: String { return self._s[2374]! }
    public var VoiceOver_Chat_YourPhoto: String { return self._s[2377]! }
    public var PrivacyPolicy_Title: String { return self._s[2380]! }
    public var Notifications_TextTone: String { return self._s[2381]! }
    public var Profile_CreateNewContact: String { return self._s[2382]! }
    public var PrivacyPhoneNumberSettings_WhoCanSeeMyPhoneNumber: String { return self._s[2383]! }
    public var Call_Speaker: String { return self._s[2385]! }
    public var AutoNightTheme_AutomaticSection: String { return self._s[2386]! }
    public var Channel_OwnershipTransfer_EnterPassword: String { return self._s[2388]! }
    public var Channel_Username_InvalidCharacters: String { return self._s[2389]! }
    public func Channel_AdminLog_MessageChangedChannelUsername(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2390]!, self._r[2390]!, [_0])
    }
    public var AutoDownloadSettings_AutodownloadFiles: String { return self._s[2391]! }
    public var PrivacySettings_LastSeenTitle: String { return self._s[2392]! }
    public var Channel_AdminLog_CanInviteUsers: String { return self._s[2393]! }
    public var SettingsSearch_Synonyms_Privacy_Data_ClearPaymentsInfo: String { return self._s[2394]! }
    public var OwnershipTransfer_SecurityCheck: String { return self._s[2395]! }
    public var Conversation_MessageDeliveryFailed: String { return self._s[2396]! }
    public var Watch_ChatList_NoConversationsText: String { return self._s[2397]! }
    public var Bot_Unblock: String { return self._s[2398]! }
    public var TextFormat_Italic: String { return self._s[2399]! }
    public var WallpaperSearch_ColorPink: String { return self._s[2400]! }
    public var Settings_About_Help: String { return self._s[2401]! }
    public var SearchImages_Title: String { return self._s[2402]! }
    public var Weekday_Wednesday: String { return self._s[2403]! }
    public var Conversation_ClousStorageInfo_Description1: String { return self._s[2404]! }
    public var ExplicitContent_AlertTitle: String { return self._s[2405]! }
    public func Time_PreciseDate_m5(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2406]!, self._r[2406]!, [_1, _2, _3])
    }
    public var Channel_DiscussionGroup_Create: String { return self._s[2407]! }
    public var Weekday_Thursday: String { return self._s[2408]! }
    public var Channel_BanUser_PermissionChangeGroupInfo: String { return self._s[2409]! }
    public var Channel_Members_AddMembersHelp: String { return self._s[2410]! }
    public func Checkout_SavePasswordTimeout(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2411]!, self._r[2411]!, [_0])
    }
    public var Channel_DiscussionGroup_LinkGroup: String { return self._s[2412]! }
    public var SettingsSearch_Synonyms_Notifications_InAppNotificationsVibrate: String { return self._s[2413]! }
    public var Passport_RequestedInformation: String { return self._s[2414]! }
    public var Login_PhoneAndCountryHelp: String { return self._s[2415]! }
    public var Conversation_EncryptionProcessing: String { return self._s[2417]! }
    public var Notifications_PermissionsSuppressWarningTitle: String { return self._s[2418]! }
    public var PhotoEditor_EnhanceTool: String { return self._s[2420]! }
    public var Channel_Setup_Title: String { return self._s[2421]! }
    public var Conversation_SearchPlaceholder: String { return self._s[2422]! }
    public var AccessDenied_LocationAlwaysDenied: String { return self._s[2423]! }
    public var Checkout_ErrorGeneric: String { return self._s[2424]! }
    public var Passport_Language_hu: String { return self._s[2425]! }
    public var Wallet_Month_ShortSeptember: String { return self._s[2426]! }
    public func Passport_Identity_UploadOneOfScan(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2428]!, self._r[2428]!, [_0])
    }
    public func PUSH_MESSAGE(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2431]!, self._r[2431]!, [_1])
    }
    public var ChatList_DeleteSavedMessagesConfirmationTitle: String { return self._s[2432]! }
    public func UserInfo_BlockConfirmationTitle(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2433]!, self._r[2433]!, [_0])
    }
    public var Conversation_CloudStorageInfo_Title: String { return self._s[2434]! }
    public var Group_Location_Info: String { return self._s[2435]! }
    public var PhotoEditor_CropAspectRatioSquare: String { return self._s[2436]! }
    public var Permissions_PeopleNearbyAllow_v0: String { return self._s[2437]! }
    public func Notification_Exceptions_MutedUntil(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2438]!, self._r[2438]!, [_0])
    }
    public var Conversation_ClearPrivateHistory: String { return self._s[2439]! }
    public var ContactInfo_PhoneLabelHome: String { return self._s[2440]! }
    public var Appearance_RemoveThemeConfirmation: String { return self._s[2441]! }
    public var PrivacySettings_LastSeenContacts: String { return self._s[2442]! }
    public func ChangePhone_ErrorOccupied(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2443]!, self._r[2443]!, [_0])
    }
    public var Passport_Language_cs: String { return self._s[2444]! }
    public var Message_PinnedAnimationMessage: String { return self._s[2446]! }
    public var Passport_Identity_ReverseSideHelp: String { return self._s[2448]! }
    public var SettingsSearch_Synonyms_Data_Storage_Title: String { return self._s[2449]! }
    public var Wallet_Info_TransactionTo: String { return self._s[2451]! }
    public var ChatList_DeleteForEveryoneConfirmationText: String { return self._s[2452]! }
    public var SettingsSearch_Synonyms_Privacy_PasscodeAndTouchId: String { return self._s[2453]! }
    public var Embed_PlayingInPIP: String { return self._s[2454]! }
    public var AutoNightTheme_ScheduleSection: String { return self._s[2455]! }
    public func Call_EmojiDescription(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2456]!, self._r[2456]!, [_0])
    }
    public var MediaPicker_LivePhotoDescription: String { return self._s[2457]! }
    public func Channel_AdminLog_MessageRestrictedName(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2458]!, self._r[2458]!, [_1])
    }
    public var Notification_PaymentSent: String { return self._s[2459]! }
    public var PhotoEditor_CurvesGreen: String { return self._s[2460]! }
    public var Notification_Exceptions_PreviewAlwaysOff: String { return self._s[2461]! }
    public var SaveIncomingPhotosSettings_Title: String { return self._s[2462]! }
    public var NotificationSettings_ShowNotificationsAllAccounts: String { return self._s[2463]! }
    public var VoiceOver_Chat_PagePreview: String { return self._s[2464]! }
    public func PUSH_MESSAGE_SCREENSHOT(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2467]!, self._r[2467]!, [_1])
    }
    public func PUSH_MESSAGE_PHOTO_SECRET(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2468]!, self._r[2468]!, [_1])
    }
    public func ApplyLanguage_UnsufficientDataText(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2469]!, self._r[2469]!, [_1])
    }
    public var NetworkUsageSettings_CallDataSection: String { return self._s[2471]! }
    public var PasscodeSettings_HelpTop: String { return self._s[2472]! }
    public var Conversation_WalletRequiredTitle: String { return self._s[2473]! }
    public var Group_OwnershipTransfer_ErrorAdminsTooMuch: String { return self._s[2474]! }
    public var Passport_Address_TypeRentalAgreement: String { return self._s[2475]! }
    public var EditTheme_ShortLink: String { return self._s[2476]! }
    public var ProxyServer_VoiceOver_Active: String { return self._s[2477]! }
    public var ReportPeer_ReasonOther_Placeholder: String { return self._s[2478]! }
    public var CheckoutInfo_ErrorPhoneInvalid: String { return self._s[2479]! }
    public var Call_Accept: String { return self._s[2481]! }
    public var GroupRemoved_RemoveInfo: String { return self._s[2482]! }
    public var Month_GenMarch: String { return self._s[2484]! }
    public var PhotoEditor_ShadowsTool: String { return self._s[2485]! }
    public var LoginPassword_Title: String { return self._s[2486]! }
    public var Call_End: String { return self._s[2487]! }
    public var Watch_Conversation_GroupInfo: String { return self._s[2488]! }
    public var VoiceOver_Chat_Contact: String { return self._s[2489]! }
    public var EditTheme_Create_Preview_IncomingText: String { return self._s[2490]! }
    public var CallSettings_Always: String { return self._s[2491]! }
    public var CallFeedback_Success: String { return self._s[2492]! }
    public var TwoStepAuth_SetupHint: String { return self._s[2493]! }
    public func AddContact_ContactWillBeSharedAfterMutual(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2494]!, self._r[2494]!, [_1])
    }
    public var ConversationProfile_UsersTooMuchError: String { return self._s[2495]! }
    public var Login_PhoneTitle: String { return self._s[2496]! }
    public var Passport_FieldPhoneHelp: String { return self._s[2497]! }
    public var Weekday_ShortSunday: String { return self._s[2498]! }
    public var Passport_InfoFAQ_URL: String { return self._s[2499]! }
    public var ContactInfo_Job: String { return self._s[2501]! }
    public var UserInfo_InviteBotToGroup: String { return self._s[2502]! }
    public var Appearance_ThemeCarouselNightBlue: String { return self._s[2503]! }
    public var TwoStepAuth_PasswordRemovePassportConfirmation: String { return self._s[2504]! }
    public var Invite_ChannelsTooMuch: String { return self._s[2505]! }
    public var Wallet_Send_ConfirmationConfirm: String { return self._s[2506]! }
    public var Wallet_TransactionInfo_OtherFeeInfo: String { return self._s[2507]! }
    public var SettingsSearch_Synonyms_Notifications_InAppNotificationsPreview: String { return self._s[2508]! }
    public var Wallet_Receive_AmountText: String { return self._s[2509]! }
    public var Passport_DeletePersonalDetailsConfirmation: String { return self._s[2510]! }
    public var CallFeedback_ReasonNoise: String { return self._s[2511]! }
    public var Appearance_AppIconDefault: String { return self._s[2513]! }
    public var Passport_Identity_AddInternalPassport: String { return self._s[2514]! }
    public var MediaPicker_AddCaption: String { return self._s[2515]! }
    public var CallSettings_TabIconDescription: String { return self._s[2516]! }
    public func VoiceOver_Chat_Caption(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2517]!, self._r[2517]!, [_0])
    }
    public var ChatList_UndoArchiveHiddenTitle: String { return self._s[2518]! }
    public var Privacy_GroupsAndChannels_AlwaysAllow: String { return self._s[2519]! }
    public var Passport_Identity_TypePersonalDetails: String { return self._s[2520]! }
    public var DialogList_SearchSectionRecent: String { return self._s[2521]! }
    public var PrivacyPolicy_DeclineMessage: String { return self._s[2522]! }
    public var LogoutOptions_ClearCacheText: String { return self._s[2525]! }
    public var LastSeen_WithinAWeek: String { return self._s[2526]! }
    public var ChannelMembers_GroupAdminsTitle: String { return self._s[2527]! }
    public var Conversation_CloudStorage_ChatStatus: String { return self._s[2529]! }
    public var VoiceOver_Media_PlaybackRateNormal: String { return self._s[2530]! }
    public func AddContact_SharedContactExceptionInfo(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2531]!, self._r[2531]!, [_0])
    }
    public var Passport_Address_TypeResidentialAddress: String { return self._s[2532]! }
    public var Conversation_StatusLeftGroup: String { return self._s[2533]! }
    public var SocksProxySetup_ProxyDetailsTitle: String { return self._s[2534]! }
    public var SettingsSearch_Synonyms_Calls_Title: String { return self._s[2536]! }
    public var GroupPermission_AddSuccess: String { return self._s[2537]! }
    public var PhotoEditor_BlurToolRadial: String { return self._s[2539]! }
    public var Conversation_ContextMenuCopy: String { return self._s[2540]! }
    public var AccessDenied_CallMicrophone: String { return self._s[2541]! }
    public func Time_PreciseDate_m2(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2542]!, self._r[2542]!, [_1, _2, _3])
    }
    public var Login_InvalidFirstNameError: String { return self._s[2543]! }
    public var Notifications_Badge_CountUnreadMessages_InfoOn: String { return self._s[2544]! }
    public var Checkout_PaymentMethod_New: String { return self._s[2545]! }
    public var ShareMenu_CopyShareLinkGame: String { return self._s[2546]! }
    public var PhotoEditor_QualityTool: String { return self._s[2547]! }
    public var Login_SendCodeViaSms: String { return self._s[2548]! }
    public var SettingsSearch_Synonyms_Privacy_DeleteAccountIfAwayFor: String { return self._s[2549]! }
    public var Chat_SlowmodeAttachmentLimitReached: String { return self._s[2550]! }
    public var Wallet_Receive_CopyAddress: String { return self._s[2551]! }
    public var Login_EmailNotConfiguredError: String { return self._s[2552]! }
    public var SocksProxySetup_Status: String { return self._s[2553]! }
    public var PrivacyPolicy_Accept: String { return self._s[2554]! }
    public var Notifications_ExceptionsMessagePlaceholder: String { return self._s[2555]! }
    public var Appearance_AppIconClassicX: String { return self._s[2556]! }
    public func PUSH_CHAT_MESSAGE_TEXT(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2557]!, self._r[2557]!, [_1, _2, _3])
    }
    public var OwnershipTransfer_SecurityRequirements: String { return self._s[2558]! }
    public var InfoPlist_NSLocationAlwaysUsageDescription: String { return self._s[2560]! }
    public var AutoNightTheme_Automatic: String { return self._s[2561]! }
    public var Channel_Username_InvalidStartsWithNumber: String { return self._s[2562]! }
    public var Privacy_ContactsSyncHelp: String { return self._s[2563]! }
    public var Cache_Help: String { return self._s[2564]! }
    public var Group_ErrorAccessDenied: String { return self._s[2565]! }
    public var Passport_Language_fa: String { return self._s[2566]! }
    public var Wallet_Intro_Text: String { return self._s[2567]! }
    public var Login_ResetAccountProtected_TimerTitle: String { return self._s[2568]! }
    public var VoiceOver_Chat_YourVideoMessage: String { return self._s[2569]! }
    public var PrivacySettings_LastSeen: String { return self._s[2570]! }
    public func DialogList_MultipleTyping(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2571]!, self._r[2571]!, [_0, _1])
    }
    public var Preview_SaveGif: String { return self._s[2575]! }
    public var SettingsSearch_Synonyms_Privacy_TwoStepAuth: String { return self._s[2576]! }
    public var Profile_About: String { return self._s[2577]! }
    public var Channel_About_Placeholder: String { return self._s[2578]! }
    public var Login_InfoTitle: String { return self._s[2579]! }
    public func TwoStepAuth_SetupPendingEmail(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2580]!, self._r[2580]!, [_0])
    }
    public var EditTheme_Expand_Preview_IncomingReplyText: String { return self._s[2581]! }
    public var Watch_Suggestion_CantTalk: String { return self._s[2583]! }
    public var ContactInfo_Title: String { return self._s[2584]! }
    public var Media_ShareThisVideo: String { return self._s[2585]! }
    public var Weekday_ShortFriday: String { return self._s[2586]! }
    public var AccessDenied_Contacts: String { return self._s[2588]! }
    public var Notification_CallIncomingShort: String { return self._s[2589]! }
    public var Group_Setup_TypePublic: String { return self._s[2590]! }
    public var Notifications_MessageNotificationsExceptions: String { return self._s[2591]! }
    public var Notifications_Badge_IncludeChannels: String { return self._s[2592]! }
    public var Notifications_MessageNotificationsPreview: String { return self._s[2595]! }
    public var ConversationProfile_ErrorCreatingConversation: String { return self._s[2596]! }
    public var Group_ErrorAddTooMuchBots: String { return self._s[2597]! }
    public var Privacy_GroupsAndChannels_CustomShareHelp: String { return self._s[2598]! }
    public var Permissions_CellularDataAllowInSettings_v0: String { return self._s[2599]! }
    public func Wallet_SecureStorageChanged_BiometryText(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2600]!, self._r[2600]!, [_0])
    }
    public var DialogList_Typing: String { return self._s[2601]! }
    public var CallFeedback_IncludeLogs: String { return self._s[2603]! }
    public var Checkout_Phone: String { return self._s[2605]! }
    public var Login_InfoFirstNamePlaceholder: String { return self._s[2608]! }
    public var Privacy_Calls_Integration: String { return self._s[2609]! }
    public var Notifications_PermissionsAllow: String { return self._s[2610]! }
    public var TwoStepAuth_AddHintDescription: String { return self._s[2614]! }
    public var Settings_ChatSettings: String { return self._s[2615]! }
    public func Channel_AdminLog_MessageInvitedNameUsername(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2616]!, self._r[2616]!, [_1, _2])
    }
    public var GroupRemoved_DeleteUser: String { return self._s[2618]! }
    public func Channel_AdminLog_PollStopped(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2619]!, self._r[2619]!, [_0])
    }
    public var Wallet_TransactionInfo_FeeInfoURL: String { return self._s[2620]! }
    public func PUSH_MESSAGE_PHOTO(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2621]!, self._r[2621]!, [_1])
    }
    public var Login_ContinueWithLocalization: String { return self._s[2622]! }
    public var Watch_Message_ForwardedFrom: String { return self._s[2623]! }
    public var TwoStepAuth_EnterEmailCode: String { return self._s[2625]! }
    public var Conversation_Unblock: String { return self._s[2626]! }
    public var PrivacySettings_DataSettings: String { return self._s[2627]! }
    public var Group_PublicLink_Info: String { return self._s[2628]! }
    public func Wallet_Time_PreciseDate_m1(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2629]!, self._r[2629]!, [_1, _2, _3])
    }
    public var Notifications_InAppNotificationsVibrate: String { return self._s[2630]! }
    public func Privacy_GroupsAndChannels_InviteToChannelError(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2631]!, self._r[2631]!, [_0, _1])
    }
    public var Wallet_RestoreFailed_CreateWallet: String { return self._s[2633]! }
    public var PrivacySettings_Passcode: String { return self._s[2635]! }
    public var Call_Mute: String { return self._s[2636]! }
    public var Wallet_Weekday_Yesterday: String { return self._s[2637]! }
    public var Passport_Language_dz: String { return self._s[2638]! }
    public var Wallet_Receive_AmountHeader: String { return self._s[2639]! }
    public var Passport_Language_tk: String { return self._s[2640]! }
    public func Login_EmailCodeSubject(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2641]!, self._r[2641]!, [_0])
    }
    public var Settings_Search: String { return self._s[2642]! }
    public var Wallet_Month_ShortFebruary: String { return self._s[2643]! }
    public var InfoPlist_NSPhotoLibraryUsageDescription: String { return self._s[2644]! }
    public var Conversation_ContextMenuReply: String { return self._s[2645]! }
    public var WallpaperSearch_ColorBrown: String { return self._s[2646]! }
    public var Chat_AttachmentMultipleForwardDisabled: String { return self._s[2647]! }
    public var Tour_Title1: String { return self._s[2648]! }
    public var Wallet_Alert_Cancel: String { return self._s[2649]! }
    public var Conversation_ClearGroupHistory: String { return self._s[2651]! }
    public var Wallet_TransactionInfo_RecipientHeader: String { return self._s[2652]! }
    public var WallpaperPreview_Motion: String { return self._s[2653]! }
    public func Checkout_PasswordEntry_Text(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2654]!, self._r[2654]!, [_0])
    }
    public var Call_RateCall: String { return self._s[2655]! }
    public var Channel_AdminLog_BanSendStickersAndGifs: String { return self._s[2656]! }
    public var Passport_PasswordCompleteSetup: String { return self._s[2657]! }
    public var Conversation_InputTextSilentBroadcastPlaceholder: String { return self._s[2658]! }
    public var UserInfo_LastNamePlaceholder: String { return self._s[2660]! }
    public func Login_WillCallYou(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2662]!, self._r[2662]!, [_0])
    }
    public var Compose_Create: String { return self._s[2663]! }
    public var Contacts_InviteToTelegram: String { return self._s[2664]! }
    public var GroupInfo_Notifications: String { return self._s[2665]! }
    public var ChatList_DeleteSavedMessagesConfirmationAction: String { return self._s[2667]! }
    public var Message_PinnedLiveLocationMessage: String { return self._s[2668]! }
    public var Month_GenApril: String { return self._s[2669]! }
    public var Appearance_AutoNightTheme: String { return self._s[2670]! }
    public var ChatSettings_AutomaticAudioDownload: String { return self._s[2672]! }
    public var Login_CodeSentSms: String { return self._s[2674]! }
    public func UserInfo_UnblockConfirmation(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2675]!, self._r[2675]!, [_0])
    }
    public var EmptyGroupInfo_Line3: String { return self._s[2676]! }
    public var LogoutOptions_ContactSupportText: String { return self._s[2677]! }
    public var Passport_Language_hr: String { return self._s[2678]! }
    public var Common_ActionNotAllowedError: String { return self._s[2679]! }
    public func Channel_AdminLog_MessageRestrictedNewSetting(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2680]!, self._r[2680]!, [_0])
    }
    public var GroupInfo_InviteLink_CopyLink: String { return self._s[2681]! }
    public var Wallet_Info_TransactionFrom: String { return self._s[2682]! }
    public var Wallet_Send_ErrorDecryptionFailed: String { return self._s[2683]! }
    public var Conversation_InputTextBroadcastPlaceholder: String { return self._s[2684]! }
    public var Privacy_SecretChatsTitle: String { return self._s[2685]! }
    public var Notification_SecretChatMessageScreenshotSelf: String { return self._s[2687]! }
    public var GroupInfo_AddUserLeftError: String { return self._s[2688]! }
    public var AutoDownloadSettings_TypePrivateChats: String { return self._s[2689]! }
    public var LogoutOptions_ContactSupportTitle: String { return self._s[2690]! }
    public var Channel_AddBotErrorHaveRights: String { return self._s[2691]! }
    public var Preview_DeleteGif: String { return self._s[2692]! }
    public var GroupInfo_Permissions_Exceptions: String { return self._s[2693]! }
    public var Group_ErrorNotMutualContact: String { return self._s[2694]! }
    public var Notification_MessageLifetime5s: String { return self._s[2695]! }
    public func Watch_LastSeen_AtDate(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2696]!, self._r[2696]!, [_0])
    }
    public var VoiceOver_Chat_Video: String { return self._s[2697]! }
    public var Channel_OwnershipTransfer_ErrorPublicChannelsTooMuch: String { return self._s[2699]! }
    public var ReportSpam_DeleteThisChat: String { return self._s[2700]! }
    public var Passport_Address_AddBankStatement: String { return self._s[2701]! }
    public var Notification_CallIncoming: String { return self._s[2702]! }
    public var Wallet_Words_NotDoneTitle: String { return self._s[2703]! }
    public var Compose_NewGroupTitle: String { return self._s[2704]! }
    public var TwoStepAuth_RecoveryCodeHelp: String { return self._s[2706]! }
    public var Passport_Address_Postcode: String { return self._s[2708]! }
    public func LastSeen_YesterdayAt(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2709]!, self._r[2709]!, [_0])
    }
    public var Checkout_NewCard_SaveInfoHelp: String { return self._s[2710]! }
    public var Wallet_Month_ShortOctober: String { return self._s[2711]! }
    public var VoiceOver_Chat_YourMusic: String { return self._s[2712]! }
    public var WallpaperColors_Title: String { return self._s[2713]! }
    public var SocksProxySetup_ShareQRCodeInfo: String { return self._s[2714]! }
    public var VoiceOver_MessageContextForward: String { return self._s[2715]! }
    public var GroupPermission_Duration: String { return self._s[2716]! }
    public func Cache_Clear(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2717]!, self._r[2717]!, [_0])
    }
    public var Bot_GroupStatusDoesNotReadHistory: String { return self._s[2718]! }
    public var Username_Placeholder: String { return self._s[2719]! }
    public var CallFeedback_WhatWentWrong: String { return self._s[2720]! }
    public var Passport_FieldAddressUploadHelp: String { return self._s[2721]! }
    public var Permissions_NotificationsAllowInSettings_v0: String { return self._s[2722]! }
    public func Channel_AdminLog_MessageChangedUnlinkedChannel(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2724]!, self._r[2724]!, [_1, _2])
    }
    public var Passport_PasswordDescription: String { return self._s[2725]! }
    public var Channel_MessagePhotoUpdated: String { return self._s[2726]! }
    public var MediaPicker_TapToUngroupDescription: String { return self._s[2727]! }
    public var SettingsSearch_Synonyms_Notifications_BadgeCountUnreadMessages: String { return self._s[2728]! }
    public var AttachmentMenu_PhotoOrVideo: String { return self._s[2729]! }
    public var Conversation_ContextMenuMore: String { return self._s[2730]! }
    public var Privacy_PaymentsClearInfo: String { return self._s[2731]! }
    public var CallSettings_TabIcon: String { return self._s[2732]! }
    public var KeyCommand_Find: String { return self._s[2733]! }
    public var Appearance_ThemePreview_ChatList_7_Text: String { return self._s[2734]! }
    public var EditTheme_Edit_Preview_IncomingText: String { return self._s[2735]! }
    public var Message_PinnedGame: String { return self._s[2736]! }
    public var VoiceOver_Chat_ForwardedFromYou: String { return self._s[2737]! }
    public var Notifications_Badge_CountUnreadMessages_InfoOff: String { return self._s[2739]! }
    public var Login_CallRequestState2: String { return self._s[2741]! }
    public var CheckoutInfo_ReceiverInfoNamePlaceholder: String { return self._s[2743]! }
    public func VoiceOver_Chat_PhotoFrom(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2744]!, self._r[2744]!, [_0])
    }
    public func Checkout_PayPrice(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2746]!, self._r[2746]!, [_0])
    }
    public var WallpaperPreview_Blurred: String { return self._s[2747]! }
    public var Conversation_InstantPagePreview: String { return self._s[2748]! }
    public func DialogList_SingleUploadingVideoSuffix(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2749]!, self._r[2749]!, [_0])
    }
    public var SecretTimer_VideoDescription: String { return self._s[2752]! }
    public var WallpaperSearch_ColorRed: String { return self._s[2753]! }
    public var GroupPermission_NoPinMessages: String { return self._s[2754]! }
    public var Passport_Language_es: String { return self._s[2755]! }
    public var Permissions_ContactsAllow_v0: String { return self._s[2757]! }
    public var Conversation_EditingMessageMediaEditCurrentVideo: String { return self._s[2758]! }
    public func PUSH_CHAT_MESSAGE_CONTACT(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2759]!, self._r[2759]!, [_1, _2])
    }
    public var Privacy_Forwards_CustomHelp: String { return self._s[2760]! }
    public var WebPreview_GettingLinkInfo: String { return self._s[2761]! }
    public var Watch_UserInfo_Unmute: String { return self._s[2762]! }
    public var GroupInfo_ChannelListNamePlaceholder: String { return self._s[2763]! }
    public var AccessDenied_CameraRestricted: String { return self._s[2765]! }
    public func Conversation_Kilobytes(_ _0: Int) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2766]!, self._r[2766]!, ["\(_0)"])
    }
    public var ChatList_ReadAll: String { return self._s[2768]! }
    public var Settings_CopyUsername: String { return self._s[2769]! }
    public var Contacts_SearchLabel: String { return self._s[2770]! }
    public var Map_OpenInYandexNavigator: String { return self._s[2772]! }
    public var PasscodeSettings_EncryptData: String { return self._s[2773]! }
    public var WallpaperSearch_ColorPrefix: String { return self._s[2774]! }
    public var Notifications_GroupNotificationsPreview: String { return self._s[2775]! }
    public var DialogList_AdNoticeAlert: String { return self._s[2776]! }
    public var Wallet_Month_GenMay: String { return self._s[2778]! }
    public var CheckoutInfo_ShippingInfoAddress1: String { return self._s[2779]! }
    public var CheckoutInfo_ShippingInfoAddress2: String { return self._s[2780]! }
    public var Localization_LanguageCustom: String { return self._s[2781]! }
    public var Passport_Identity_TypeDriversLicenseUploadScan: String { return self._s[2782]! }
    public var CallFeedback_Title: String { return self._s[2783]! }
    public var VoiceOver_Chat_RecordPreviewVoiceMessage: String { return self._s[2786]! }
    public var Passport_Address_OneOfTypePassportRegistration: String { return self._s[2787]! }
    public var Wallet_Intro_CreateErrorTitle: String { return self._s[2788]! }
    public var Conversation_InfoGroup: String { return self._s[2789]! }
    public var Compose_NewMessage: String { return self._s[2790]! }
    public var FastTwoStepSetup_HintPlaceholder: String { return self._s[2791]! }
    public var ChatSettings_AutoDownloadVideoMessages: String { return self._s[2792]! }
    public var Wallet_SecureStorageReset_BiometryFaceId: String { return self._s[2793]! }
    public var Channel_DiscussionGroup_UnlinkChannel: String { return self._s[2794]! }
    public func Passport_Scans_ScanIndex(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2795]!, self._r[2795]!, [_0])
    }
    public var Channel_AdminLog_CanDeleteMessages: String { return self._s[2796]! }
    public var Login_CancelSignUpConfirmation: String { return self._s[2797]! }
    public var ChangePhoneNumberCode_Help: String { return self._s[2798]! }
    public var PrivacySettings_DeleteAccountHelp: String { return self._s[2799]! }
    public var Channel_BlackList_Title: String { return self._s[2800]! }
    public var UserInfo_PhoneCall: String { return self._s[2801]! }
    public var Passport_Address_OneOfTypeBankStatement: String { return self._s[2803]! }
    public var Wallet_Month_ShortJanuary: String { return self._s[2804]! }
    public var State_connecting: String { return self._s[2805]! }
    public var Appearance_ThemePreview_ChatList_6_Text: String { return self._s[2806]! }
    public var Wallet_Month_GenMarch: String { return self._s[2807]! }
    public var EditTheme_Expand_BottomInfo: String { return self._s[2808]! }
    public func LastSeen_TodayAt(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2809]!, self._r[2809]!, [_0])
    }
    public func DialogList_SingleRecordingAudioSuffix(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2810]!, self._r[2810]!, [_0])
    }
    public var Notifications_GroupNotifications: String { return self._s[2811]! }
    public var Conversation_SendMessageErrorTooMuchScheduled: String { return self._s[2812]! }
    public var Passport_Identity_EditPassport: String { return self._s[2813]! }
    public var EnterPasscode_RepeatNewPasscode: String { return self._s[2815]! }
    public var Localization_EnglishLanguageName: String { return self._s[2816]! }
    public var Share_AuthDescription: String { return self._s[2817]! }
    public var SettingsSearch_Synonyms_Notifications_ChannelNotificationsAlert: String { return self._s[2818]! }
    public var Passport_Identity_Surname: String { return self._s[2819]! }
    public var Compose_TokenListPlaceholder: String { return self._s[2820]! }
    public var Passport_Identity_OneOfTypePassport: String { return self._s[2821]! }
    public var Settings_AboutEmpty: String { return self._s[2822]! }
    public var Conversation_Unmute: String { return self._s[2823]! }
    public var CreateGroup_ChannelsTooMuch: String { return self._s[2825]! }
    public var Wallet_Sending_Text: String { return self._s[2826]! }
    public func PUSH_CONTACT_JOINED(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2827]!, self._r[2827]!, [_1])
    }
    public var Login_CodeSentCall: String { return self._s[2828]! }
    public var ContactInfo_PhoneLabelHomeFax: String { return self._s[2830]! }
    public var ChatSettings_Appearance: String { return self._s[2831]! }
    public var Appearance_PickAccentColor: String { return self._s[2832]! }
    public func PUSH_CHAT_MESSAGE_NOTEXT(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2833]!, self._r[2833]!, [_1, _2])
    }
    public func PUSH_MESSAGE_GEO(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2834]!, self._r[2834]!, [_1])
    }
    public var Notification_CallMissed: String { return self._s[2835]! }
    public var SettingsSearch_Synonyms_Appearance_ChatBackground_Custom: String { return self._s[2836]! }
    public var Channel_AdminLogFilter_EventsInfo: String { return self._s[2837]! }
    public var Wallet_Month_GenOctober: String { return self._s[2839]! }
    public var ChatAdmins_AdminLabel: String { return self._s[2840]! }
    public var KeyCommand_JumpToNextChat: String { return self._s[2841]! }
    public var Conversation_StopPollConfirmationTitle: String { return self._s[2843]! }
    public var ChangePhoneNumberCode_CodePlaceholder: String { return self._s[2844]! }
    public var Month_GenJune: String { return self._s[2845]! }
    public var Watch_Location_Current: String { return self._s[2846]! }
    public var Wallet_Receive_CopyInvoiceUrl: String { return self._s[2847]! }
    public var Conversation_TitleMute: String { return self._s[2848]! }
    public func PUSH_CHANNEL_MESSAGE_ROUND(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2849]!, self._r[2849]!, [_1])
    }
    public var GroupInfo_DeleteAndExit: String { return self._s[2850]! }
    public func Conversation_Moderate_DeleteAllMessages(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2851]!, self._r[2851]!, [_0])
    }
    public var Call_ReportPlaceholder: String { return self._s[2852]! }
    public var Chat_SlowmodeSendError: String { return self._s[2853]! }
    public var MaskStickerSettings_Info: String { return self._s[2854]! }
    public var EditTheme_Expand_TopInfo: String { return self._s[2855]! }
    public func GroupInfo_AddParticipantConfirmation(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2856]!, self._r[2856]!, [_0])
    }
    public var Checkout_NewCard_PostcodeTitle: String { return self._s[2857]! }
    public var Passport_Address_RegionPlaceholder: String { return self._s[2859]! }
    public var Contacts_ShareTelegram: String { return self._s[2860]! }
    public var EnterPasscode_EnterNewPasscodeNew: String { return self._s[2861]! }
    public var Channel_ErrorAccessDenied: String { return self._s[2862]! }
    public var UserInfo_ScamBotWarning: String { return self._s[2864]! }
    public var Stickers_GroupChooseStickerPack: String { return self._s[2865]! }
    public var Call_ConnectionErrorTitle: String { return self._s[2866]! }
    public var UserInfo_NotificationsEnable: String { return self._s[2867]! }
    public var ArchivedChats_IntroText1: String { return self._s[2868]! }
    public var Tour_Text4: String { return self._s[2871]! }
    public var WallpaperSearch_Recent: String { return self._s[2872]! }
    public var GroupInfo_ScamGroupWarning: String { return self._s[2873]! }
    public var Profile_MessageLifetime2s: String { return self._s[2875]! }
    public var Appearance_ThemePreview_ChatList_5_Text: String { return self._s[2876]! }
    public var Notification_MessageLifetime2s: String { return self._s[2877]! }
    public func Time_PreciseDate_m10(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2878]!, self._r[2878]!, [_1, _2, _3])
    }
    public var Cache_ClearCache: String { return self._s[2879]! }
    public var AutoNightTheme_UpdateLocation: String { return self._s[2880]! }
    public var Permissions_NotificationsUnreachableText_v0: String { return self._s[2881]! }
    public func Channel_AdminLog_MessageChangedGroupUsername(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2885]!, self._r[2885]!, [_0])
    }
    public func Conversation_ShareMyPhoneNumber_StatusSuccess(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2887]!, self._r[2887]!, [_0])
    }
    public var LocalGroup_Text: String { return self._s[2888]! }
    public var Channel_AdminLog_EmptyFilterTitle: String { return self._s[2889]! }
    public var SocksProxySetup_TypeSocks: String { return self._s[2890]! }
    public var ChatList_UnarchiveAction: String { return self._s[2891]! }
    public var AutoNightTheme_Title: String { return self._s[2892]! }
    public var InstantPage_FeedbackButton: String { return self._s[2893]! }
    public var Passport_FieldAddress: String { return self._s[2894]! }
    public func Channel_AdminLog_SetSlowmode(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2895]!, self._r[2895]!, [_1, _2])
    }
    public var Month_ShortMarch: String { return self._s[2896]! }
    public func PUSH_MESSAGE_INVOICE(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2897]!, self._r[2897]!, [_1, _2])
    }
    public var SocksProxySetup_UsernamePlaceholder: String { return self._s[2898]! }
    public var Conversation_ShareInlineBotLocationConfirmation: String { return self._s[2899]! }
    public var Passport_FloodError: String { return self._s[2900]! }
    public var SecretGif_Title: String { return self._s[2901]! }
    public var NotificationSettings_ShowNotificationsAllAccountsInfoOn: String { return self._s[2902]! }
    public var ChatList_Context_UnhideArchive: String { return self._s[2903]! }
    public var Passport_Language_th: String { return self._s[2905]! }
    public var Passport_Address_Address: String { return self._s[2906]! }
    public var Login_InvalidLastNameError: String { return self._s[2907]! }
    public var Notifications_InAppNotificationsPreview: String { return self._s[2908]! }
    public var Notifications_PermissionsUnreachableTitle: String { return self._s[2909]! }
    public var ChatList_Context_Archive: String { return self._s[2910]! }
    public var SettingsSearch_FAQ: String { return self._s[2911]! }
    public var ShareMenu_Send: String { return self._s[2912]! }
    public var WallpaperSearch_ColorYellow: String { return self._s[2914]! }
    public var Month_GenNovember: String { return self._s[2916]! }
    public var SettingsSearch_Synonyms_Appearance_LargeEmoji: String { return self._s[2918]! }
    public func Conversation_ShareMyPhoneNumberConfirmation(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2919]!, self._r[2919]!, [_1, _2])
    }
    public var Checkout_Email: String { return self._s[2920]! }
    public var NotificationsSound_Tritone: String { return self._s[2921]! }
    public var StickerPacksSettings_ManagingHelp: String { return self._s[2923]! }
    public var Wallet_ContextMenuCopy: String { return self._s[2925]! }
    public func Wallet_Time_PreciseDate_m6(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2927]!, self._r[2927]!, [_1, _2, _3])
    }
    public func PUSH_PINNED_ROUND(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2928]!, self._r[2928]!, [_1])
    }
    public var ChangePhoneNumberNumber_Help: String { return self._s[2929]! }
    public func Checkout_LiabilityAlert(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2930]!, self._r[2930]!, [_1, _1, _1, _2])
    }
    public var ChatList_UndoArchiveTitle: String { return self._s[2931]! }
    public var Notification_Exceptions_Add: String { return self._s[2932]! }
    public var DialogList_You: String { return self._s[2933]! }
    public var MediaPicker_Send: String { return self._s[2936]! }
    public var SettingsSearch_Synonyms_Stickers_Title: String { return self._s[2937]! }
    public var Appearance_ThemePreview_ChatList_4_Text: String { return self._s[2938]! }
    public var Call_AudioRouteSpeaker: String { return self._s[2939]! }
    public var Watch_UserInfo_Title: String { return self._s[2940]! }
    public var VoiceOver_Chat_PollFinalResults: String { return self._s[2941]! }
    public var Appearance_AccentColor: String { return self._s[2943]! }
    public func Login_EmailPhoneSubject(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2944]!, self._r[2944]!, [_0])
    }
    public var Permissions_ContactsAllowInSettings_v0: String { return self._s[2945]! }
    public func PUSH_CHANNEL_MESSAGE_GAME(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2946]!, self._r[2946]!, [_1, _2])
    }
    public var Conversation_ClousStorageInfo_Description2: String { return self._s[2947]! }
    public var WebSearch_RecentClearConfirmation: String { return self._s[2948]! }
    public var Notification_CallOutgoing: String { return self._s[2949]! }
    public var PrivacySettings_PasscodeAndFaceId: String { return self._s[2950]! }
    public var Channel_DiscussionGroup_MakeHistoryPublic: String { return self._s[2951]! }
    public var Call_RecordingDisabledMessage: String { return self._s[2952]! }
    public var Message_Game: String { return self._s[2953]! }
    public var Conversation_PressVolumeButtonForSound: String { return self._s[2954]! }
    public var PrivacyLastSeenSettings_CustomHelp: String { return self._s[2955]! }
    public var Channel_DiscussionGroup_PrivateGroup: String { return self._s[2956]! }
    public var Channel_EditAdmin_PermissionAddAdmins: String { return self._s[2957]! }
    public var Date_DialogDateFormat: String { return self._s[2958]! }
    public var WallpaperColors_SetCustomColor: String { return self._s[2959]! }
    public var Notifications_InAppNotifications: String { return self._s[2960]! }
    public func Channel_Management_RemovedBy(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2961]!, self._r[2961]!, [_0])
    }
    public func Settings_ApplyProxyAlert(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2962]!, self._r[2962]!, [_1, _2])
    }
    public var NewContact_Title: String { return self._s[2963]! }
    public func AutoDownloadSettings_UpToForAll(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2964]!, self._r[2964]!, [_0])
    }
    public var Conversation_ViewContactDetails: String { return self._s[2965]! }
    public func PUSH_CHANNEL_MESSAGE_CONTACT(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2967]!, self._r[2967]!, [_1])
    }
    public var Checkout_NewCard_CardholderNameTitle: String { return self._s[2968]! }
    public var Passport_Identity_ExpiryDateNone: String { return self._s[2969]! }
    public var PrivacySettings_Title: String { return self._s[2970]! }
    public var Conversation_SilentBroadcastTooltipOff: String { return self._s[2973]! }
    public var GroupRemoved_UsersSectionTitle: String { return self._s[2974]! }
    public var VoiceOver_Chat_ContactEmail: String { return self._s[2975]! }
    public var Contacts_PhoneNumber: String { return self._s[2976]! }
    public var Map_ShowPlaces: String { return self._s[2978]! }
    public var ChatAdmins_Title: String { return self._s[2979]! }
    public var InstantPage_Reference: String { return self._s[2981]! }
    public var Wallet_Info_Updating: String { return self._s[2982]! }
    public var ReportGroupLocation_Text: String { return self._s[2983]! }
    public func PUSH_CHAT_MESSAGE_FWD(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2984]!, self._r[2984]!, [_1, _2])
    }
    public var Camera_FlashOff: String { return self._s[2985]! }
    public var Wallet_Intro_TermsUrl: String { return self._s[2986]! }
    public var Watch_UserInfo_Block: String { return self._s[2987]! }
    public var ChatSettings_Stickers: String { return self._s[2988]! }
    public var ChatSettings_DownloadInBackground: String { return self._s[2989]! }
    public var Appearance_ThemeCarouselTintedNight: String { return self._s[2990]! }
    public func UserInfo_BlockConfirmation(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2991]!, self._r[2991]!, [_0])
    }
    public var Settings_ViewPhoto: String { return self._s[2992]! }
    public var Login_CheckOtherSessionMessages: String { return self._s[2993]! }
    public var AutoDownloadSettings_Cellular: String { return self._s[2994]! }
    public var Wallet_Created_ExportErrorTitle: String { return self._s[2995]! }
    public var SettingsSearch_Synonyms_Notifications_GroupNotificationsExceptions: String { return self._s[2996]! }
    public var VoiceOver_MessageContextShare: String { return self._s[2997]! }
    public func Target_InviteToGroupConfirmation(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2999]!, self._r[2999]!, [_0])
    }
    public var Privacy_DeleteDrafts: String { return self._s[3000]! }
    public var Wallpaper_SetCustomBackgroundInfo: String { return self._s[3001]! }
    public func LastSeen_AtDate(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3002]!, self._r[3002]!, [_0])
    }
    public var DialogList_SavedMessagesHelp: String { return self._s[3003]! }
    public var Wallet_SecureStorageNotAvailable_Title: String { return self._s[3004]! }
    public var DialogList_SavedMessages: String { return self._s[3005]! }
    public var GroupInfo_UpgradeButton: String { return self._s[3006]! }
    public var Appearance_ThemePreview_ChatList_3_Text: String { return self._s[3008]! }
    public var DialogList_Pin: String { return self._s[3009]! }
    public func ForwardedAuthors2(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3010]!, self._r[3010]!, [_0, _1])
    }
    public func Login_PhoneGenericEmailSubject(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3011]!, self._r[3011]!, [_0])
    }
    public var Notification_Exceptions_AlwaysOn: String { return self._s[3012]! }
    public var UserInfo_NotificationsDisable: String { return self._s[3013]! }
    public var Paint_Outlined: String { return self._s[3014]! }
    public var Activity_PlayingGame: String { return self._s[3015]! }
    public var SearchImages_NoImagesFound: String { return self._s[3016]! }
    public var SocksProxySetup_ProxyType: String { return self._s[3017]! }
    public var AppleWatch_ReplyPresetsHelp: String { return self._s[3019]! }
    public var Conversation_ContextMenuCancelSending: String { return self._s[3020]! }
    public var Settings_AppLanguage: String { return self._s[3021]! }
    public var TwoStepAuth_ResetAccountHelp: String { return self._s[3022]! }
    public var Common_ChoosePhoto: String { return self._s[3023]! }
    public var CallFeedback_ReasonEcho: String { return self._s[3024]! }
    public func PUSH_PINNED_AUDIO(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3025]!, self._r[3025]!, [_1])
    }
    public var Privacy_Calls_AlwaysAllow: String { return self._s[3026]! }
    public var Activity_UploadingVideo: String { return self._s[3027]! }
    public var Conversation_WalletRequiredNotNow: String { return self._s[3028]! }
    public var ChannelInfo_DeleteChannelConfirmation: String { return self._s[3029]! }
    public var NetworkUsageSettings_Wifi: String { return self._s[3030]! }
    public var VoiceOver_Editing_ClearText: String { return self._s[3031]! }
    public var PUSH_SENDER_YOU: String { return self._s[3032]! }
    public var Channel_BanUser_PermissionReadMessages: String { return self._s[3033]! }
    public var Checkout_PayWithTouchId: String { return self._s[3034]! }
    public var Wallpaper_ResetWallpapersConfirmation: String { return self._s[3035]! }
    public func PUSH_LOCKED_MESSAGE(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3037]!, self._r[3037]!, [_1])
    }
    public var Notifications_ExceptionsNone: String { return self._s[3038]! }
    public func Message_ForwardedMessageShort(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3039]!, self._r[3039]!, [_0])
    }
    public func PUSH_PINNED_GEO(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3040]!, self._r[3040]!, [_1])
    }
    public var AuthSessions_IncompleteAttempts: String { return self._s[3042]! }
    public var Passport_Address_Region: String { return self._s[3045]! }
    public var ChatList_DeleteChat: String { return self._s[3046]! }
    public var LogoutOptions_ClearCacheTitle: String { return self._s[3047]! }
    public var PhotoEditor_TiltShift: String { return self._s[3048]! }
    public var Settings_FAQ_URL: String { return self._s[3049]! }
    public var Passport_Language_sl: String { return self._s[3050]! }
    public var Settings_PrivacySettings: String { return self._s[3052]! }
    public var SharedMedia_TitleLink: String { return self._s[3053]! }
    public var Passport_Identity_TypePassportUploadScan: String { return self._s[3054]! }
    public var Settings_SetProfilePhoto: String { return self._s[3055]! }
    public var Channel_About_Help: String { return self._s[3056]! }
    public var Contacts_PermissionsEnable: String { return self._s[3057]! }
    public var Wallet_Sending_Title: String { return self._s[3058]! }
    public var SettingsSearch_Synonyms_Notifications_GroupNotificationsAlert: String { return self._s[3059]! }
    public var AttachmentMenu_SendAsFiles: String { return self._s[3060]! }
    public var CallFeedback_ReasonInterruption: String { return self._s[3062]! }
    public var Passport_Address_AddTemporaryRegistration: String { return self._s[3063]! }
    public var AutoDownloadSettings_AutodownloadVideos: String { return self._s[3064]! }
    public var ChatSettings_AutoDownloadSettings_Delimeter: String { return self._s[3065]! }
    public var PrivacySettings_DeleteAccountTitle: String { return self._s[3066]! }
    public var AccessDenied_VideoMessageCamera: String { return self._s[3068]! }
    public var Map_OpenInYandexMaps: String { return self._s[3070]! }
    public var CreateGroup_ErrorLocatedGroupsTooMuch: String { return self._s[3071]! }
    public var VoiceOver_MessageContextReply: String { return self._s[3072]! }
    public var PhotoEditor_SaturationTool: String { return self._s[3073]! }
    public func PUSH_MESSAGE_STICKER(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3074]!, self._r[3074]!, [_1, _2])
    }
    public var PrivacyPhoneNumberSettings_CustomHelp: String { return self._s[3075]! }
    public var Notification_Exceptions_NewException_NotificationHeader: String { return self._s[3076]! }
    public var Group_OwnershipTransfer_ErrorLocatedGroupsTooMuch: String { return self._s[3077]! }
    public var Appearance_TextSize: String { return self._s[3078]! }
    public func LOCAL_MESSAGE_FWDS(_ _1: String, _ _2: Int) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3079]!, self._r[3079]!, [_1, "\(_2)"])
    }
    public var Appearance_ThemePreview_ChatList_2_Text: String { return self._s[3080]! }
    public var Channel_Username_InvalidTooShort: String { return self._s[3082]! }
    public func Group_OwnershipTransfer_DescriptionInfo(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3083]!, self._r[3083]!, [_1, _2])
    }
    public func PUSH_CHAT_MESSAGE_GAME(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3084]!, self._r[3084]!, [_1, _2, _3])
    }
    public var GroupInfo_PublicLinkAdd: String { return self._s[3085]! }
    public var Passport_PassportInformation: String { return self._s[3088]! }
    public var Theme_Unsupported: String { return self._s[3089]! }
    public var WatchRemote_AlertTitle: String { return self._s[3090]! }
    public var Privacy_GroupsAndChannels_NeverAllow: String { return self._s[3091]! }
    public var ConvertToSupergroup_HelpText: String { return self._s[3093]! }
    public func Time_MonthOfYear_m7(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3094]!, self._r[3094]!, [_0])
    }
    public func PUSH_PHONE_CALL_REQUEST(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3095]!, self._r[3095]!, [_1])
    }
    public var Privacy_GroupsAndChannels_CustomHelp: String { return self._s[3096]! }
    public var Wallet_Navigation_Done: String { return self._s[3098]! }
    public var TwoStepAuth_RecoveryCodeInvalid: String { return self._s[3099]! }
    public var AccessDenied_CameraDisabled: String { return self._s[3100]! }
    public func Channel_Username_UsernameIsAvailable(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3101]!, self._r[3101]!, [_0])
    }
    public var PhotoEditor_ContrastTool: String { return self._s[3104]! }
    public func PUSH_PINNED_DOC(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3105]!, self._r[3105]!, [_1])
    }
    public var DialogList_Draft: String { return self._s[3106]! }
    public var Privacy_TopPeersDelete: String { return self._s[3108]! }
    public var LoginPassword_PasswordPlaceholder: String { return self._s[3109]! }
    public var Passport_Identity_TypeIdentityCardUploadScan: String { return self._s[3110]! }
    public var WebSearch_RecentSectionClear: String { return self._s[3111]! }
    public var EditTheme_ErrorInvalidCharacters: String { return self._s[3112]! }
    public var Watch_ChatList_NoConversationsTitle: String { return self._s[3114]! }
    public var Common_Done: String { return self._s[3116]! }
    public var AuthSessions_EmptyText: String { return self._s[3117]! }
    public var Conversation_ShareBotContactConfirmation: String { return self._s[3118]! }
    public var Tour_Title5: String { return self._s[3119]! }
    public var Wallet_Settings_Title: String { return self._s[3120]! }
    public func Map_DirectionsDriveEta(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3121]!, self._r[3121]!, [_0])
    }
    public var ApplyLanguage_UnsufficientDataTitle: String { return self._s[3122]! }
    public var Conversation_LinkDialogSave: String { return self._s[3123]! }
    public var GroupInfo_ActionRestrict: String { return self._s[3124]! }
    public var Checkout_Title: String { return self._s[3125]! }
    public var Channel_DiscussionGroup_HeaderLabel: String { return self._s[3127]! }
    public var Channel_AdminLog_CanChangeInfo: String { return self._s[3129]! }
    public var Notification_RenamedGroup: String { return self._s[3130]! }
    public var PeopleNearby_Groups: String { return self._s[3131]! }
    public var Checkout_PayWithFaceId: String { return self._s[3132]! }
    public var Channel_BanList_BlockedTitle: String { return self._s[3133]! }
    public var SettingsSearch_Synonyms_Notifications_InAppNotificationsSound: String { return self._s[3135]! }
    public var Checkout_WebConfirmation_Title: String { return self._s[3136]! }
    public var Notifications_MessageNotificationsAlert: String { return self._s[3137]! }
    public func Activity_RemindAboutGroup(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3138]!, self._r[3138]!, [_0])
    }
    public var Profile_AddToExisting: String { return self._s[3140]! }
    public func Profile_CreateEncryptedChatOutdatedError(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3141]!, self._r[3141]!, [_0, _1])
    }
    public var Cache_Files: String { return self._s[3143]! }
    public var Permissions_PrivacyPolicy: String { return self._s[3144]! }
    public var SocksProxySetup_ConnectAndSave: String { return self._s[3145]! }
    public var UserInfo_NotificationsDefaultDisabled: String { return self._s[3146]! }
    public var AutoDownloadSettings_TypeContacts: String { return self._s[3148]! }
    public var Appearance_ThemePreview_ChatList_1_Text: String { return self._s[3150]! }
    public var Calls_NoCallsPlaceholder: String { return self._s[3151]! }
    public var Channel_Username_RevokeExistingUsernamesInfo: String { return self._s[3152]! }
    public var VoiceOver_AttachMedia: String { return self._s[3154]! }
    public var Notifications_ExceptionsGroupPlaceholder: String { return self._s[3155]! }
    public func PUSH_CHAT_MESSAGE_INVOICE(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3156]!, self._r[3156]!, [_1, _2, _3])
    }
    public var SettingsSearch_Synonyms_Notifications_GroupNotificationsSound: String { return self._s[3157]! }
    public var Conversation_SetReminder_Title: String { return self._s[3158]! }
    public var Passport_FieldAddressHelp: String { return self._s[3159]! }
    public var Privacy_GroupsAndChannels_InviteToChannelMultipleError: String { return self._s[3160]! }
    public var PUSH_REMINDER_TITLE: String { return self._s[3161]! }
    public func Login_TermsOfService_ProceedBot(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3162]!, self._r[3162]!, [_0])
    }
    public var Channel_AdminLog_EmptyTitle: String { return self._s[3163]! }
    public var Privacy_Calls_NeverAllow_Title: String { return self._s[3164]! }
    public var Login_UnknownError: String { return self._s[3165]! }
    public var Group_UpgradeNoticeText2: String { return self._s[3168]! }
    public var Watch_Compose_AddContact: String { return self._s[3169]! }
    public var Web_Error: String { return self._s[3170]! }
    public var Gif_Search: String { return self._s[3171]! }
    public var Profile_MessageLifetime1h: String { return self._s[3172]! }
    public var CheckoutInfo_ReceiverInfoEmailPlaceholder: String { return self._s[3173]! }
    public var Channel_Username_CheckingUsername: String { return self._s[3174]! }
    public var CallFeedback_ReasonSilentRemote: String { return self._s[3175]! }
    public var AutoDownloadSettings_TypeChannels: String { return self._s[3176]! }
    public var Channel_AboutItem: String { return self._s[3177]! }
    public var Privacy_GroupsAndChannels_AlwaysAllow_Placeholder: String { return self._s[3179]! }
    public var VoiceOver_Chat_VoiceMessage: String { return self._s[3180]! }
    public var GroupInfo_SharedMedia: String { return self._s[3181]! }
    public func Channel_AdminLog_MessagePromotedName(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3182]!, self._r[3182]!, [_1])
    }
    public var Call_PhoneCallInProgressMessage: String { return self._s[3183]! }
    public func PUSH_CHANNEL_ALBUM(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3184]!, self._r[3184]!, [_1])
    }
    public var ChatList_UndoArchiveRevealedText: String { return self._s[3185]! }
    public var GroupInfo_InviteLink_RevokeAlert_Text: String { return self._s[3186]! }
    public var Conversation_SearchByName_Placeholder: String { return self._s[3187]! }
    public var CreatePoll_AddOption: String { return self._s[3188]! }
    public var GroupInfo_Permissions_SearchPlaceholder: String { return self._s[3189]! }
    public var Group_UpgradeNoticeHeader: String { return self._s[3190]! }
    public var Channel_Management_AddModerator: String { return self._s[3191]! }
    public var AutoDownloadSettings_MaxFileSize: String { return self._s[3192]! }
    public var StickerPacksSettings_ShowStickersButton: String { return self._s[3193]! }
    public var Wallet_Info_RefreshErrorNetworkText: String { return self._s[3194]! }
    public var NotificationsSound_Hello: String { return self._s[3196]! }
    public var SocksProxySetup_SavedProxies: String { return self._s[3197]! }
    public var Channel_Stickers_Placeholder: String { return self._s[3199]! }
    public func Login_EmailCodeBody(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3200]!, self._r[3200]!, [_0])
    }
    public var PrivacyPolicy_DeclineDeclineAndDelete: String { return self._s[3201]! }
    public var Channel_Management_AddModeratorHelp: String { return self._s[3202]! }
    public var ContactInfo_BirthdayLabel: String { return self._s[3203]! }
    public var ChangePhoneNumberCode_RequestingACall: String { return self._s[3204]! }
    public var AutoDownloadSettings_Channels: String { return self._s[3205]! }
    public var Passport_Language_mn: String { return self._s[3206]! }
    public var Notifications_ResetAllNotificationsHelp: String { return self._s[3209]! }
    public var GroupInfo_Permissions_SlowmodeValue_Off: String { return self._s[3210]! }
    public var Passport_Language_ja: String { return self._s[3212]! }
    public var Settings_About_Title: String { return self._s[3213]! }
    public var Settings_NotificationsAndSounds: String { return self._s[3214]! }
    public var ChannelInfo_DeleteGroup: String { return self._s[3215]! }
    public var Settings_BlockedUsers: String { return self._s[3216]! }
    public func Time_MonthOfYear_m4(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3217]!, self._r[3217]!, [_0])
    }
    public var EditTheme_Create_Preview_OutgoingText: String { return self._s[3218]! }
    public var Wallet_Weekday_Today: String { return self._s[3219]! }
    public var AutoDownloadSettings_PreloadVideo: String { return self._s[3220]! }
    public var Passport_Address_AddResidentialAddress: String { return self._s[3221]! }
    public var Channel_Username_Title: String { return self._s[3222]! }
    public func Notification_RemovedGroupPhoto(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3223]!, self._r[3223]!, [_0])
    }
    public var AttachmentMenu_File: String { return self._s[3225]! }
    public var AppleWatch_Title: String { return self._s[3226]! }
    public var Activity_RecordingVideoMessage: String { return self._s[3227]! }
    public func Channel_DiscussionGroup_PublicChannelLink(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3228]!, self._r[3228]!, [_1, _2])
    }
    public var Weekday_Saturday: String { return self._s[3229]! }
    public var WallpaperPreview_SwipeColorsTopText: String { return self._s[3230]! }
    public var Profile_CreateEncryptedChatError: String { return self._s[3231]! }
    public var Common_Next: String { return self._s[3233]! }
    public var Channel_Stickers_YourStickers: String { return self._s[3235]! }
    public var Message_Theme: String { return self._s[3236]! }
    public var Call_AudioRouteHeadphones: String { return self._s[3237]! }
    public var TwoStepAuth_EnterPasswordForgot: String { return self._s[3239]! }
    public var Watch_Contacts_NoResults: String { return self._s[3241]! }
    public var PhotoEditor_TintTool: String { return self._s[3244]! }
    public var LoginPassword_ResetAccount: String { return self._s[3246]! }
    public var Settings_SavedMessages: String { return self._s[3247]! }
    public var SettingsSearch_Synonyms_Appearance_Animations: String { return self._s[3248]! }
    public var Bot_GenericSupportStatus: String { return self._s[3249]! }
    public var StickerPack_Add: String { return self._s[3250]! }
    public var Checkout_TotalAmount: String { return self._s[3251]! }
    public var Your_cards_number_is_invalid: String { return self._s[3252]! }
    public var SettingsSearch_Synonyms_Appearance_AutoNightTheme: String { return self._s[3253]! }
    public var VoiceOver_Chat_VideoMessage: String { return self._s[3254]! }
    public func ChangePhoneNumberCode_CallTimer(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3255]!, self._r[3255]!, [_0])
    }
    public func GroupPermission_AddedInfo(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3256]!, self._r[3256]!, [_1, _2])
    }
    public var ChatSettings_ConnectionType_UseSocks5: String { return self._s[3257]! }
    public func PUSH_CHAT_PHOTO_EDITED(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3259]!, self._r[3259]!, [_1, _2])
    }
    public func Conversation_RestrictedTextTimed(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3260]!, self._r[3260]!, [_0])
    }
    public var GroupInfo_InviteLink_ShareLink: String { return self._s[3261]! }
    public var StickerPack_Share: String { return self._s[3262]! }
    public var Passport_DeleteAddress: String { return self._s[3263]! }
    public var Settings_Passport: String { return self._s[3264]! }
    public var SharedMedia_EmptyFilesText: String { return self._s[3265]! }
    public var Conversation_DeleteMessagesForMe: String { return self._s[3266]! }
    public var PasscodeSettings_AutoLock_IfAwayFor_1hour: String { return self._s[3267]! }
    public var Contacts_PermissionsText: String { return self._s[3268]! }
    public var Group_Setup_HistoryVisible: String { return self._s[3269]! }
    public var Wallet_Month_ShortDecember: String { return self._s[3271]! }
    public var Passport_Address_AddRentalAgreement: String { return self._s[3272]! }
    public var SocksProxySetup_Title: String { return self._s[3273]! }
    public var Notification_Mute1h: String { return self._s[3274]! }
    public func Passport_Email_CodeHelp(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3275]!, self._r[3275]!, [_0])
    }
    public var NotificationSettings_ShowNotificationsAllAccountsInfoOff: String { return self._s[3276]! }
    public func PUSH_PINNED_GEOLIVE(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3277]!, self._r[3277]!, [_1])
    }
    public var FastTwoStepSetup_PasswordSection: String { return self._s[3278]! }
    public var NetworkUsageSettings_ResetStatsConfirmation: String { return self._s[3281]! }
    public var InfoPlist_NSFaceIDUsageDescription: String { return self._s[3283]! }
    public var DialogList_NoMessagesText: String { return self._s[3284]! }
    public var Privacy_ContactsResetConfirmation: String { return self._s[3285]! }
    public var Privacy_Calls_P2PHelp: String { return self._s[3286]! }
    public var Channel_DiscussionGroup_SearchPlaceholder: String { return self._s[3288]! }
    public var Your_cards_expiration_year_is_invalid: String { return self._s[3289]! }
    public var Common_TakePhotoOrVideo: String { return self._s[3290]! }
    public var Wallet_Words_Text: String { return self._s[3291]! }
    public var Call_StatusBusy: String { return self._s[3292]! }
    public var Conversation_PinnedMessage: String { return self._s[3293]! }
    public var AutoDownloadSettings_VoiceMessagesTitle: String { return self._s[3294]! }
    public var TwoStepAuth_SetupPasswordConfirmFailed: String { return self._s[3295]! }
    public var Undo_ChatCleared: String { return self._s[3296]! }
    public var AppleWatch_ReplyPresets: String { return self._s[3297]! }
    public var Passport_DiscardMessageDescription: String { return self._s[3299]! }
    public var Login_NetworkError: String { return self._s[3300]! }
    public func Notification_PinnedRoundMessage(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3301]!, self._r[3301]!, [_0])
    }
    public func Channel_AdminLog_MessageRemovedChannelUsername(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3302]!, self._r[3302]!, [_0])
    }
    public var SocksProxySetup_PasswordPlaceholder: String { return self._s[3303]! }
    public var Wallet_WordCheck_ViewWords: String { return self._s[3305]! }
    public var Login_ResetAccountProtected_LimitExceeded: String { return self._s[3306]! }
    public func Watch_LastSeen_YesterdayAt(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3308]!, self._r[3308]!, [_0])
    }
    public var Call_ConnectionErrorMessage: String { return self._s[3309]! }
    public var VoiceOver_Chat_Music: String { return self._s[3310]! }
    public var SettingsSearch_Synonyms_Notifications_MessageNotificationsSound: String { return self._s[3311]! }
    public var Compose_GroupTokenListPlaceholder: String { return self._s[3313]! }
    public var ConversationMedia_Title: String { return self._s[3314]! }
    public var EncryptionKey_Title: String { return self._s[3316]! }
    public var TwoStepAuth_EnterPasswordTitle: String { return self._s[3317]! }
    public var Notification_Exceptions_AddException: String { return self._s[3318]! }
    public var PrivacySettings_BlockedPeersEmpty: String { return self._s[3319]! }
    public var Profile_MessageLifetime1m: String { return self._s[3320]! }
    public func Channel_AdminLog_MessageUnkickedName(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3321]!, self._r[3321]!, [_1])
    }
    public var Month_GenMay: String { return self._s[3322]! }
    public func LiveLocationUpdated_TodayAt(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3323]!, self._r[3323]!, [_0])
    }
    public var PeopleNearby_Users: String { return self._s[3324]! }
    public var Wallet_Send_AddressInfo: String { return self._s[3325]! }
    public var ChannelMembers_WhoCanAddMembersAllHelp: String { return self._s[3326]! }
    public var AutoDownloadSettings_ResetSettings: String { return self._s[3327]! }
    public func Wallet_Updated_AtDate(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3329]!, self._r[3329]!, [_0])
    }
    public var Conversation_EmptyPlaceholder: String { return self._s[3330]! }
    public var Passport_Address_AddPassportRegistration: String { return self._s[3331]! }
    public var Notifications_ChannelNotificationsAlert: String { return self._s[3332]! }
    public var ChatSettings_AutoDownloadUsingCellular: String { return self._s[3333]! }
    public var Camera_TapAndHoldForVideo: String { return self._s[3334]! }
    public var Channel_JoinChannel: String { return self._s[3336]! }
    public var Appearance_Animations: String { return self._s[3339]! }
    public func Notification_MessageLifetimeChanged(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3340]!, self._r[3340]!, [_1, _2])
    }
    public var Stickers_GroupStickers: String { return self._s[3342]! }
    public var Appearance_ShareTheme: String { return self._s[3343]! }
    public var ConvertToSupergroup_HelpTitle: String { return self._s[3345]! }
    public var Passport_Address_Street: String { return self._s[3346]! }
    public var Conversation_AddContact: String { return self._s[3347]! }
    public var Login_PhonePlaceholder: String { return self._s[3348]! }
    public var Channel_Members_InviteLink: String { return self._s[3350]! }
    public var Bot_Stop: String { return self._s[3351]! }
    public var SettingsSearch_Synonyms_Proxy_UseForCalls: String { return self._s[3353]! }
    public var Notification_PassportValueAddress: String { return self._s[3354]! }
    public var Month_ShortJuly: String { return self._s[3355]! }
    public var Passport_Address_TypeTemporaryRegistrationUploadScan: String { return self._s[3356]! }
    public var Channel_AdminLog_BanSendMedia: String { return self._s[3357]! }
    public var Passport_Identity_ReverseSide: String { return self._s[3358]! }
    public var Watch_Stickers_Recents: String { return self._s[3361]! }
    public var PrivacyLastSeenSettings_EmpryUsersPlaceholder: String { return self._s[3363]! }
    public var Map_SendThisLocation: String { return self._s[3364]! }
    public func Time_MonthOfYear_m1(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3365]!, self._r[3365]!, [_0])
    }
    public func InviteText_SingleContact(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3366]!, self._r[3366]!, [_0])
    }
    public var ConvertToSupergroup_Note: String { return self._s[3367]! }
    public var Wallet_Intro_NotNow: String { return self._s[3368]! }
    public func FileSize_MB(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3369]!, self._r[3369]!, [_0])
    }
    public var NetworkUsageSettings_GeneralDataSection: String { return self._s[3370]! }
    public func Compatibility_SecretMediaVersionTooLow(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3371]!, self._r[3371]!, [_0, _1])
    }
    public var Login_CallRequestState3: String { return self._s[3373]! }
    public var Wallpaper_SearchShort: String { return self._s[3374]! }
    public var SettingsSearch_Synonyms_Appearance_ColorTheme: String { return self._s[3376]! }
    public var PasscodeSettings_UnlockWithFaceId: String { return self._s[3377]! }
    public var Channel_BotDoesntSupportGroups: String { return self._s[3378]! }
    public func PUSH_CHAT_MESSAGE_GEOLIVE(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3379]!, self._r[3379]!, [_1, _2])
    }
    public var Channel_AdminLogFilter_Title: String { return self._s[3380]! }
    public var Notifications_GroupNotificationsExceptions: String { return self._s[3384]! }
    public func FileSize_B(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3385]!, self._r[3385]!, [_0])
    }
    public var Passport_CorrectErrors: String { return self._s[3386]! }
    public var VoiceOver_Chat_YourAnonymousPoll: String { return self._s[3387]! }
    public func Channel_MessageTitleUpdated(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3388]!, self._r[3388]!, [_0])
    }
    public var Map_SendMyCurrentLocation: String { return self._s[3389]! }
    public var Channel_DiscussionGroup: String { return self._s[3390]! }
    public func PUSH_PINNED_CONTACT(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3391]!, self._r[3391]!, [_1, _2])
    }
    public var SharedMedia_SearchNoResults: String { return self._s[3392]! }
    public var Permissions_NotificationsText_v0: String { return self._s[3393]! }
    public var Channel_EditAdmin_PermissionDeleteMessagesOfOthers: String { return self._s[3394]! }
    public var Appearance_AppIcon: String { return self._s[3395]! }
    public var Appearance_ThemePreview_ChatList_3_AuthorName: String { return self._s[3396]! }
    public var LoginPassword_FloodError: String { return self._s[3397]! }
    public var Group_Setup_HistoryHiddenHelp: String { return self._s[3399]! }
    public func TwoStepAuth_PendingEmailHelp(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3400]!, self._r[3400]!, [_0])
    }
    public var Passport_Language_bn: String { return self._s[3401]! }
    public func DialogList_SingleUploadingPhotoSuffix(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3402]!, self._r[3402]!, [_0])
    }
    public var ChatList_Context_Pin: String { return self._s[3403]! }
    public func Notification_PinnedAudioMessage(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3404]!, self._r[3404]!, [_0])
    }
    public func Channel_AdminLog_MessageChangedGroupStickerPack(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3405]!, self._r[3405]!, [_0])
    }
    public var Wallet_Navigation_Close: String { return self._s[3406]! }
    public var GroupInfo_InvitationLinkGroupFull: String { return self._s[3410]! }
    public var Group_EditAdmin_PermissionChangeInfo: String { return self._s[3412]! }
    public var Wallet_Month_GenDecember: String { return self._s[3413]! }
    public var Contacts_PermissionsAllow: String { return self._s[3414]! }
    public var ReportPeer_ReasonCopyright: String { return self._s[3415]! }
    public var Channel_EditAdmin_PermissinAddAdminOn: String { return self._s[3416]! }
    public var WallpaperPreview_Pattern: String { return self._s[3417]! }
    public var Paint_Duplicate: String { return self._s[3418]! }
    public var Passport_Address_Country: String { return self._s[3419]! }
    public var Notification_RenamedChannel: String { return self._s[3421]! }
    public var ChatList_Context_Unmute: String { return self._s[3422]! }
    public var CheckoutInfo_ErrorPostcodeInvalid: String { return self._s[3423]! }
    public var Group_MessagePhotoUpdated: String { return self._s[3424]! }
    public var Channel_BanUser_PermissionSendMedia: String { return self._s[3425]! }
    public var Conversation_ContextMenuBan: String { return self._s[3426]! }
    public var TwoStepAuth_EmailSent: String { return self._s[3427]! }
    public var MessagePoll_NoVotes: String { return self._s[3428]! }
    public var Wallet_Send_ErrorNotEnoughFundsTitle: String { return self._s[3429]! }
    public var Passport_Language_is: String { return self._s[3430]! }
    public var PeopleNearby_UsersEmpty: String { return self._s[3432]! }
    public var Tour_Text5: String { return self._s[3433]! }
    public func Call_GroupFormat(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3435]!, self._r[3435]!, [_1, _2])
    }
    public var Undo_SecretChatDeleted: String { return self._s[3436]! }
    public var SocksProxySetup_ShareQRCode: String { return self._s[3437]! }
    public func VoiceOver_Chat_Size(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3438]!, self._r[3438]!, [_0])
    }
    public var LogoutOptions_ChangePhoneNumberText: String { return self._s[3439]! }
    public var Paint_Edit: String { return self._s[3441]! }
    public var ScheduledMessages_ReminderNotification: String { return self._s[3443]! }
    public var Undo_DeletedGroup: String { return self._s[3445]! }
    public var LoginPassword_ForgotPassword: String { return self._s[3446]! }
    public var Wallet_WordImport_IncorrectTitle: String { return self._s[3447]! }
    public var GroupInfo_GroupNamePlaceholder: String { return self._s[3448]! }
    public func Notification_Kicked(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3449]!, self._r[3449]!, [_0, _1])
    }
    public var Conversation_InputTextCaptionPlaceholder: String { return self._s[3450]! }
    public var AutoDownloadSettings_VideoMessagesTitle: String { return self._s[3451]! }
    public var Passport_Language_uz: String { return self._s[3452]! }
    public var Conversation_PinMessageAlertGroup: String { return self._s[3453]! }
    public var SettingsSearch_Synonyms_Privacy_GroupsAndChannels: String { return self._s[3454]! }
    public var Map_StopLiveLocation: String { return self._s[3456]! }
    public var VoiceOver_MessageContextSend: String { return self._s[3458]! }
    public var PasscodeSettings_Help: String { return self._s[3459]! }
    public var NotificationsSound_Input: String { return self._s[3460]! }
    public var Share_Title: String { return self._s[3463]! }
    public var LogoutOptions_Title: String { return self._s[3464]! }
    public var Wallet_Send_AddressText: String { return self._s[3465]! }
    public var Login_TermsOfServiceAgree: String { return self._s[3466]! }
    public var Compose_NewEncryptedChatTitle: String { return self._s[3467]! }
    public var Channel_AdminLog_TitleSelectedEvents: String { return self._s[3468]! }
    public var Channel_EditAdmin_PermissionEditMessages: String { return self._s[3469]! }
    public var EnterPasscode_EnterTitle: String { return self._s[3470]! }
    public func Call_PrivacyErrorMessage(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3471]!, self._r[3471]!, [_0])
    }
    public var Settings_CopyPhoneNumber: String { return self._s[3472]! }
    public var Conversation_AddToContacts: String { return self._s[3473]! }
    public func VoiceOver_Chat_ReplyFrom(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3474]!, self._r[3474]!, [_0])
    }
    public var NotificationsSound_Keys: String { return self._s[3475]! }
    public func Call_ParticipantVersionOutdatedError(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3476]!, self._r[3476]!, [_0])
    }
    public var Notification_MessageLifetime1w: String { return self._s[3477]! }
    public var Message_Video: String { return self._s[3478]! }
    public var AutoDownloadSettings_CellularTitle: String { return self._s[3479]! }
    public func PUSH_CHANNEL_MESSAGE_PHOTO(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3480]!, self._r[3480]!, [_1])
    }
    public var Wallet_Receive_AmountInfo: String { return self._s[3483]! }
    public func Notification_JoinedChat(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3484]!, self._r[3484]!, [_0])
    }
    public func PrivacySettings_LastSeenContactsPlus(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3485]!, self._r[3485]!, [_0])
    }
    public var Passport_Language_mk: String { return self._s[3486]! }
    public func Wallet_Time_PreciseDate_m2(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3487]!, self._r[3487]!, [_1, _2, _3])
    }
    public var CreatePoll_CancelConfirmation: String { return self._s[3488]! }
    public var Conversation_SilentBroadcastTooltipOn: String { return self._s[3490]! }
    public var PrivacyPolicy_Decline: String { return self._s[3491]! }
    public var Passport_Identity_DoesNotExpire: String { return self._s[3492]! }
    public var Channel_AdminLogFilter_EventsRestrictions: String { return self._s[3493]! }
    public var Permissions_SiriAllow_v0: String { return self._s[3495]! }
    public var Wallet_Month_ShortAugust: String { return self._s[3496]! }
    public var Appearance_ThemeCarouselNight: String { return self._s[3497]! }
    public func LOCAL_CHAT_MESSAGE_FWDS(_ _1: String, _ _2: Int) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3498]!, self._r[3498]!, [_1, "\(_2)"])
    }
    public func Notification_RenamedChat(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3499]!, self._r[3499]!, [_0])
    }
    public var Paint_Regular: String { return self._s[3500]! }
    public var ChatSettings_AutoDownloadReset: String { return self._s[3501]! }
    public var SocksProxySetup_ShareLink: String { return self._s[3502]! }
    public var Wallet_Qr_Title: String { return self._s[3503]! }
    public var BlockedUsers_SelectUserTitle: String { return self._s[3504]! }
    public var VoiceOver_Chat_RecordModeVoiceMessage: String { return self._s[3506]! }
    public var GroupInfo_InviteByLink: String { return self._s[3507]! }
    public var MessageTimer_Custom: String { return self._s[3508]! }
    public var UserInfo_NotificationsDefaultEnabled: String { return self._s[3509]! }
    public var Passport_Address_TypeTemporaryRegistration: String { return self._s[3511]! }
    public var Conversation_SendMessage_SetReminder: String { return self._s[3512]! }
    public var VoiceOver_Chat_Selected: String { return self._s[3513]! }
    public var ChatSettings_AutoDownloadUsingWiFi: String { return self._s[3514]! }
    public var Channel_Username_InvalidTaken: String { return self._s[3515]! }
    public var Conversation_ClousStorageInfo_Description3: String { return self._s[3516]! }
    public var Wallet_WordCheck_TryAgain: String { return self._s[3517]! }
    public var Wallet_Info_TransactionPendingHeader: String { return self._s[3518]! }
    public var Settings_ChatBackground: String { return self._s[3519]! }
    public var Channel_Subscribers_Title: String { return self._s[3520]! }
    public var Wallet_Receive_InvoiceUrlHeader: String { return self._s[3521]! }
    public var ApplyLanguage_ChangeLanguageTitle: String { return self._s[3522]! }
    public var Watch_ConnectionDescription: String { return self._s[3523]! }
    public var ChatList_ArchivedChatsTitle: String { return self._s[3527]! }
    public var Wallpaper_ResetWallpapers: String { return self._s[3528]! }
    public var EditProfile_Title: String { return self._s[3529]! }
    public var NotificationsSound_Bamboo: String { return self._s[3531]! }
    public var Channel_AdminLog_MessagePreviousMessage: String { return self._s[3533]! }
    public var Login_SmsRequestState2: String { return self._s[3534]! }
    public var Passport_Language_ar: String { return self._s[3535]! }
    public func Message_AuthorPinnedGame(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3536]!, self._r[3536]!, [_0])
    }
    public var SettingsSearch_Synonyms_EditProfile_Title: String { return self._s[3537]! }
    public var Wallet_Created_Text: String { return self._s[3538]! }
    public var Conversation_MessageDialogEdit: String { return self._s[3539]! }
    public var Wallet_Created_Proceed: String { return self._s[3540]! }
    public var Wallet_Words_Done: String { return self._s[3541]! }
    public var VoiceOver_Media_PlaybackPause: String { return self._s[3542]! }
    public func PUSH_AUTH_UNKNOWN(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3543]!, self._r[3543]!, [_1])
    }
    public var Common_Close: String { return self._s[3544]! }
    public var GroupInfo_PublicLink: String { return self._s[3545]! }
    public var Channel_OwnershipTransfer_ErrorPrivacyRestricted: String { return self._s[3546]! }
    public var SettingsSearch_Synonyms_Notifications_GroupNotificationsPreview: String { return self._s[3547]! }
    public func Channel_AdminLog_MessageToggleInvitesOff(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3551]!, self._r[3551]!, [_0])
    }
    public var UserInfo_About_Placeholder: String { return self._s[3552]! }
    public func Conversation_FileHowToText(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3553]!, self._r[3553]!, [_0])
    }
    public var GroupInfo_Permissions_SectionTitle: String { return self._s[3554]! }
    public var Channel_Info_Banned: String { return self._s[3556]! }
    public func Time_MonthOfYear_m11(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3557]!, self._r[3557]!, [_0])
    }
    public var Appearance_Other: String { return self._s[3558]! }
    public var Passport_Language_my: String { return self._s[3559]! }
    public var Group_Setup_BasicHistoryHiddenHelp: String { return self._s[3560]! }
    public func Time_PreciseDate_m9(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3561]!, self._r[3561]!, [_1, _2, _3])
    }
    public var SettingsSearch_Synonyms_Privacy_PasscodeAndFaceId: String { return self._s[3562]! }
    public var Preview_CopyAddress: String { return self._s[3563]! }
    public func DialogList_SinglePlayingGameSuffix(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3564]!, self._r[3564]!, [_0])
    }
    public var KeyCommand_JumpToPreviousChat: String { return self._s[3565]! }
    public var UserInfo_BotSettings: String { return self._s[3566]! }
    public var LiveLocation_MenuStopAll: String { return self._s[3568]! }
    public var Passport_PasswordCreate: String { return self._s[3569]! }
    public var StickerSettings_MaskContextInfo: String { return self._s[3570]! }
    public var Message_PinnedLocationMessage: String { return self._s[3571]! }
    public var Map_Satellite: String { return self._s[3572]! }
    public var Watch_Message_Unsupported: String { return self._s[3573]! }
    public var Username_TooManyPublicUsernamesError: String { return self._s[3574]! }
    public var TwoStepAuth_EnterPasswordInvalid: String { return self._s[3575]! }
    public func Notification_PinnedTextMessage(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3576]!, self._r[3576]!, [_0, _1])
    }
    public func Conversation_OpenBotLinkText(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3577]!, self._r[3577]!, [_0])
    }
    public var Wallet_WordImport_Continue: String { return self._s[3578]! }
    public var Notifications_ChannelNotificationsHelp: String { return self._s[3579]! }
    public var Privacy_Calls_P2PContacts: String { return self._s[3580]! }
    public var NotificationsSound_None: String { return self._s[3581]! }
    public var Wallet_TransactionInfo_StorageFeeHeader: String { return self._s[3582]! }
    public var Channel_DiscussionGroup_UnlinkGroup: String { return self._s[3584]! }
    public var AccessDenied_VoiceMicrophone: String { return self._s[3585]! }
    public func ApplyLanguage_ChangeLanguageAlreadyActive(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3586]!, self._r[3586]!, [_1])
    }
    public var Cache_Indexing: String { return self._s[3587]! }
    public var DialogList_RecentTitlePeople: String { return self._s[3589]! }
    public var DialogList_EncryptionRejected: String { return self._s[3590]! }
    public var GroupInfo_Administrators: String { return self._s[3591]! }
    public var Passport_ScanPassportHelp: String { return self._s[3592]! }
    public var Application_Name: String { return self._s[3593]! }
    public var Channel_AdminLogFilter_ChannelEventsInfo: String { return self._s[3594]! }
    public var Appearance_ThemeCarouselDay: String { return self._s[3596]! }
    public var Passport_Identity_TranslationHelp: String { return self._s[3597]! }
    public func VoiceOver_Chat_VideoMessageFrom(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3598]!, self._r[3598]!, [_0])
    }
    public func Notification_JoinedGroupByLink(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3599]!, self._r[3599]!, [_0])
    }
    public func DialogList_EncryptedChatStartedOutgoing(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3600]!, self._r[3600]!, [_0])
    }
    public var Channel_EditAdmin_PermissionDeleteMessages: String { return self._s[3601]! }
    public var Privacy_ChatsTitle: String { return self._s[3602]! }
    public var DialogList_ClearHistoryConfirmation: String { return self._s[3603]! }
    public var SettingsSearch_Synonyms_Data_Storage_ClearCache: String { return self._s[3604]! }
    public var Watch_Suggestion_HoldOn: String { return self._s[3605]! }
    public var Group_EditAdmin_TransferOwnership: String { return self._s[3606]! }
    public var Group_LinkedChannel: String { return self._s[3607]! }
    public var VoiceOver_Chat_SeenByRecipient: String { return self._s[3608]! }
    public var SocksProxySetup_RequiredCredentials: String { return self._s[3609]! }
    public var Passport_Address_TypeRentalAgreementUploadScan: String { return self._s[3610]! }
    public var TwoStepAuth_EmailSkipAlert: String { return self._s[3611]! }
    public var ScheduledMessages_RemindersTitle: String { return self._s[3613]! }
    public var Channel_Setup_TypePublic: String { return self._s[3615]! }
    public func Channel_AdminLog_MessageToggleInvitesOn(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3616]!, self._r[3616]!, [_0])
    }
    public var Channel_TypeSetup_Title: String { return self._s[3618]! }
    public var Map_OpenInMaps: String { return self._s[3620]! }
    public func PUSH_PINNED_NOTEXT(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3621]!, self._r[3621]!, [_1])
    }
    public var NotificationsSound_Tremolo: String { return self._s[3623]! }
    public func Date_ChatDateHeaderYear(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3624]!, self._r[3624]!, [_1, _2, _3])
    }
    public var ConversationProfile_UnknownAddMemberError: String { return self._s[3625]! }
    public var Channel_OwnershipTransfer_PasswordPlaceholder: String { return self._s[3626]! }
    public var Passport_PasswordHelp: String { return self._s[3627]! }
    public var Login_CodeExpiredError: String { return self._s[3628]! }
    public var Channel_EditAdmin_PermissionChangeInfo: String { return self._s[3629]! }
    public var Conversation_TitleUnmute: String { return self._s[3630]! }
    public var Passport_Identity_ScansHelp: String { return self._s[3631]! }
    public var Passport_Language_lo: String { return self._s[3632]! }
    public var Camera_FlashAuto: String { return self._s[3633]! }
    public var Conversation_OpenBotLinkOpen: String { return self._s[3634]! }
    public var Common_Cancel: String { return self._s[3635]! }
    public var DialogList_SavedMessagesTooltip: String { return self._s[3636]! }
    public var TwoStepAuth_SetupPasswordTitle: String { return self._s[3637]! }
    public var Appearance_TintAllColors: String { return self._s[3638]! }
    public func PUSH_MESSAGE_FWD(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3639]!, self._r[3639]!, [_1])
    }
    public var Conversation_ReportSpamConfirmation: String { return self._s[3640]! }
    public var ChatSettings_Title: String { return self._s[3642]! }
    public var Passport_PasswordReset: String { return self._s[3643]! }
    public var SocksProxySetup_TypeNone: String { return self._s[3644]! }
    public var EditTheme_Title: String { return self._s[3646]! }
    public var PhoneNumberHelp_Help: String { return self._s[3647]! }
    public var Checkout_EnterPassword: String { return self._s[3648]! }
    public var Share_AuthTitle: String { return self._s[3650]! }
    public var Activity_UploadingDocument: String { return self._s[3651]! }
    public var State_Connecting: String { return self._s[3652]! }
    public var Profile_MessageLifetime1w: String { return self._s[3653]! }
    public var Conversation_ContextMenuReport: String { return self._s[3654]! }
    public var CheckoutInfo_ReceiverInfoPhone: String { return self._s[3655]! }
    public var AutoNightTheme_ScheduledTo: String { return self._s[3656]! }
    public func VoiceOver_Chat_AnonymousPollFrom(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3657]!, self._r[3657]!, [_0])
    }
    public var AuthSessions_Terminate: String { return self._s[3658]! }
    public var Wallet_WordImport_CanNotRemember: String { return self._s[3659]! }
    public var Checkout_NewCard_CardholderNamePlaceholder: String { return self._s[3660]! }
    public var KeyCommand_JumpToPreviousUnreadChat: String { return self._s[3661]! }
    public var PhotoEditor_Set: String { return self._s[3662]! }
    public var EmptyGroupInfo_Title: String { return self._s[3663]! }
    public var Login_PadPhoneHelp: String { return self._s[3664]! }
    public var AutoDownloadSettings_TypeGroupChats: String { return self._s[3666]! }
    public var PrivacyPolicy_DeclineLastWarning: String { return self._s[3668]! }
    public var NotificationsSound_Complete: String { return self._s[3669]! }
    public var SettingsSearch_Synonyms_Privacy_Data_Title: String { return self._s[3670]! }
    public var Group_Info_AdminLog: String { return self._s[3671]! }
    public var GroupPermission_NotAvailableInPublicGroups: String { return self._s[3672]! }
    public func Wallet_Time_PreciseDate_m11(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3673]!, self._r[3673]!, [_1, _2, _3])
    }
    public var Channel_AdminLog_InfoPanelAlertText: String { return self._s[3674]! }
    public var Conversation_Admin: String { return self._s[3676]! }
    public var Conversation_GifTooltip: String { return self._s[3677]! }
    public var Passport_NotLoggedInMessage: String { return self._s[3678]! }
    public func AutoDownloadSettings_OnFor(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3680]!, self._r[3680]!, [_0])
    }
    public var Profile_MessageLifetimeForever: String { return self._s[3681]! }
    public var SharedMedia_EmptyTitle: String { return self._s[3683]! }
    public var Channel_Edit_PrivatePublicLinkAlert: String { return self._s[3685]! }
    public var Username_Help: String { return self._s[3686]! }
    public var DialogList_LanguageTooltip: String { return self._s[3688]! }
    public var Map_LoadError: String { return self._s[3689]! }
    public var Login_PhoneNumberAlreadyAuthorized: String { return self._s[3690]! }
    public var Channel_AdminLog_AddMembers: String { return self._s[3691]! }
    public var ArchivedChats_IntroTitle2: String { return self._s[3692]! }
    public var Notification_Exceptions_NewException: String { return self._s[3693]! }
    public var TwoStepAuth_EmailTitle: String { return self._s[3694]! }
    public var WatchRemote_AlertText: String { return self._s[3695]! }
    public func Wallet_Send_ConfirmationText(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3696]!, self._r[3696]!, [_1, _2])
    }
    public var ChatSettings_ConnectionType_Title: String { return self._s[3700]! }
    public func Settings_CheckPhoneNumberTitle(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3701]!, self._r[3701]!, [_0])
    }
    public var SettingsSearch_Synonyms_Calls_CallTab: String { return self._s[3702]! }
    public var Passport_Address_CountryPlaceholder: String { return self._s[3703]! }
    public func DialogList_AwaitingEncryption(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3704]!, self._r[3704]!, [_0])
    }
    public func Time_PreciseDate_m6(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3705]!, self._r[3705]!, [_1, _2, _3])
    }
    public var Group_AdminLog_EmptyText: String { return self._s[3706]! }
    public var SettingsSearch_Synonyms_Appearance_Title: String { return self._s[3707]! }
    public var Conversation_PrivateChannelTooltip: String { return self._s[3709]! }
    public var Wallet_Created_ExportErrorText: String { return self._s[3710]! }
    public var ChatList_UndoArchiveText1: String { return self._s[3711]! }
    public var AccessDenied_VideoMicrophone: String { return self._s[3712]! }
    public var Conversation_ContextMenuStickerPackAdd: String { return self._s[3713]! }
    public var Cache_ClearNone: String { return self._s[3714]! }
    public var SocksProxySetup_FailedToConnect: String { return self._s[3715]! }
    public var Permissions_NotificationsTitle_v0: String { return self._s[3716]! }
    public func Channel_AdminLog_MessageEdited(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3717]!, self._r[3717]!, [_0])
    }
    public var Passport_Identity_Country: String { return self._s[3718]! }
    public func ChatSettings_AutoDownloadSettings_TypeFile(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3719]!, self._r[3719]!, [_0])
    }
    public func Notification_CreatedChat(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3720]!, self._r[3720]!, [_0])
    }
    public var Exceptions_AddToExceptions: String { return self._s[3721]! }
    public var AccessDenied_Settings: String { return self._s[3722]! }
    public var Passport_Address_TypeUtilityBillUploadScan: String { return self._s[3723]! }
    public var Month_ShortMay: String { return self._s[3724]! }
    public var Compose_NewGroup: String { return self._s[3726]! }
    public var Group_Setup_TypePrivate: String { return self._s[3728]! }
    public var Login_PadPhoneHelpTitle: String { return self._s[3730]! }
    public var Appearance_ThemeDayClassic: String { return self._s[3731]! }
    public var Channel_AdminLog_MessagePreviousCaption: String { return self._s[3732]! }
    public var AutoDownloadSettings_OffForAll: String { return self._s[3733]! }
    public var Privacy_GroupsAndChannels_WhoCanAddMe: String { return self._s[3734]! }
    public var Conversation_typing: String { return self._s[3736]! }
    public var Undo_ScheduledMessagesCleared: String { return self._s[3737]! }
    public var Paint_Masks: String { return self._s[3738]! }
    public var Contacts_DeselectAll: String { return self._s[3739]! }
    public func Wallet_Updated_YesterdayAt(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3740]!, self._r[3740]!, [_0])
    }
    public var Username_InvalidTaken: String { return self._s[3741]! }
    public var Call_StatusNoAnswer: String { return self._s[3742]! }
    public var TwoStepAuth_EmailAddSuccess: String { return self._s[3743]! }
    public var SettingsSearch_Synonyms_Privacy_BlockedUsers: String { return self._s[3744]! }
    public var Passport_Identity_Selfie: String { return self._s[3745]! }
    public var Login_InfoLastNamePlaceholder: String { return self._s[3746]! }
    public var Privacy_SecretChatsLinkPreviewsHelp: String { return self._s[3747]! }
    public var Conversation_ClearSecretHistory: String { return self._s[3748]! }
    public var PeopleNearby_Description: String { return self._s[3750]! }
    public var NetworkUsageSettings_Title: String { return self._s[3751]! }
    public var Your_cards_security_code_is_invalid: String { return self._s[3753]! }
    public func Notification_LeftChannel(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3755]!, self._r[3755]!, [_0])
    }
    public func Call_CallInProgressMessage(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3756]!, self._r[3756]!, [_1, _2])
    }
    public var SaveIncomingPhotosSettings_From: String { return self._s[3758]! }
    public var VoiceOver_Navigation_Search: String { return self._s[3759]! }
    public var Map_LiveLocationTitle: String { return self._s[3760]! }
    public var Login_InfoAvatarAdd: String { return self._s[3761]! }
    public var Passport_Identity_FilesView: String { return self._s[3762]! }
    public var UserInfo_GenericPhoneLabel: String { return self._s[3763]! }
    public var Privacy_Calls_NeverAllow: String { return self._s[3764]! }
    public var VoiceOver_Chat_File: String { return self._s[3765]! }
    public var Wallet_Settings_DeleteWalletInfo: String { return self._s[3766]! }
    public func Contacts_AddPhoneNumber(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3767]!, self._r[3767]!, [_0])
    }
    public var ContactInfo_PhoneNumberHidden: String { return self._s[3768]! }
    public var TwoStepAuth_ConfirmationText: String { return self._s[3769]! }
    public var ChatSettings_AutomaticVideoMessageDownload: String { return self._s[3770]! }
    public func PUSH_CHAT_MESSAGE_VIDEOS(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3771]!, self._r[3771]!, [_1, _2, _3])
    }
    public var Channel_AdminLogFilter_AdminsAll: String { return self._s[3772]! }
    public var Wallet_Intro_CreateErrorText: String { return self._s[3773]! }
    public var Tour_Title2: String { return self._s[3774]! }
    public var Wallet_Sent_ViewWallet: String { return self._s[3775]! }
    public var Conversation_FileOpenIn: String { return self._s[3776]! }
    public var Checkout_ErrorPrecheckoutFailed: String { return self._s[3777]! }
    public var Wallet_Send_ErrorInvalidAddress: String { return self._s[3778]! }
    public var Wallpaper_Set: String { return self._s[3779]! }
    public var Passport_Identity_Translations: String { return self._s[3781]! }
    public func Channel_AdminLog_MessageChangedChannelAbout(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3782]!, self._r[3782]!, [_0])
    }
    public var Channel_LeaveChannel: String { return self._s[3783]! }
    public func PINNED_INVOICE(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3784]!, self._r[3784]!, [_1])
    }
    public var SettingsSearch_Synonyms_Proxy_AddProxy: String { return self._s[3786]! }
    public var PhotoEditor_HighlightsTint: String { return self._s[3787]! }
    public var Passport_Email_Delete: String { return self._s[3788]! }
    public var Conversation_Mute: String { return self._s[3790]! }
    public var Channel_AddBotAsAdmin: String { return self._s[3791]! }
    public var Channel_AdminLog_CanSendMessages: String { return self._s[3793]! }
    public var Channel_Management_LabelOwner: String { return self._s[3795]! }
    public func Notification_PassportValuesSentMessage(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3796]!, self._r[3796]!, [_1, _2])
    }
    public var Calls_CallTabDescription: String { return self._s[3797]! }
    public var Passport_Identity_NativeNameHelp: String { return self._s[3798]! }
    public var Common_No: String { return self._s[3799]! }
    public var Weekday_Sunday: String { return self._s[3800]! }
    public var Notification_Reply: String { return self._s[3801]! }
    public var Conversation_ViewMessage: String { return self._s[3802]! }
    public func Checkout_SavePasswordTimeoutAndFaceId(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3803]!, self._r[3803]!, [_0])
    }
    public func Map_LiveLocationPrivateDescription(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3804]!, self._r[3804]!, [_0])
    }
    public func Wallet_Time_PreciseDate_m7(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3805]!, self._r[3805]!, [_1, _2, _3])
    }
    public var SettingsSearch_Synonyms_EditProfile_AddAccount: String { return self._s[3806]! }
    public var Wallet_Send_Title: String { return self._s[3807]! }
    public var Message_PinnedDocumentMessage: String { return self._s[3808]! }
    public var Wallet_Info_RefreshErrorText: String { return self._s[3809]! }
    public var DialogList_TabTitle: String { return self._s[3811]! }
    public var ChatSettings_AutoPlayTitle: String { return self._s[3812]! }
    public var Passport_FieldEmail: String { return self._s[3813]! }
    public var Conversation_UnpinMessageAlert: String { return self._s[3814]! }
    public var Passport_Address_TypeBankStatement: String { return self._s[3815]! }
    public var Wallet_SecureStorageReset_Title: String { return self._s[3816]! }
    public var Passport_Identity_ExpiryDate: String { return self._s[3817]! }
    public var Privacy_Calls_P2P: String { return self._s[3818]! }
    public func CancelResetAccount_Success(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3820]!, self._r[3820]!, [_0])
    }
    public var SocksProxySetup_UseForCallsHelp: String { return self._s[3821]! }
    public func PUSH_CHAT_ALBUM(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3822]!, self._r[3822]!, [_1, _2])
    }
    public var Stickers_ClearRecent: String { return self._s[3823]! }
    public var EnterPasscode_ChangeTitle: String { return self._s[3824]! }
    public var Passport_InfoText: String { return self._s[3825]! }
    public var Checkout_NewCard_SaveInfoEnableHelp: String { return self._s[3826]! }
    public func Login_InvalidPhoneEmailSubject(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3827]!, self._r[3827]!, [_0])
    }
    public func Time_PreciseDate_m3(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3828]!, self._r[3828]!, [_1, _2, _3])
    }
    public var SettingsSearch_Synonyms_Notifications_BadgeIncludeMutedChannels: String { return self._s[3829]! }
    public var ScheduledMessages_PollUnavailable: String { return self._s[3830]! }
    public var VoiceOver_Navigation_Compose: String { return self._s[3831]! }
    public var Passport_Identity_EditDriversLicense: String { return self._s[3832]! }
    public var Conversation_TapAndHoldToRecord: String { return self._s[3834]! }
    public var SettingsSearch_Synonyms_Notifications_BadgeIncludeMutedChats: String { return self._s[3835]! }
    public func Notification_CallTimeFormat(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3836]!, self._r[3836]!, [_1, _2])
    }
    public var Channel_EditAdmin_PermissionInviteViaLink: String { return self._s[3838]! }
    public func Generic_OpenHiddenLinkAlert(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3840]!, self._r[3840]!, [_0])
    }
    public var DialogList_Unread: String { return self._s[3841]! }
    public func PUSH_CHAT_MESSAGE_GIF(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3842]!, self._r[3842]!, [_1, _2])
    }
    public var User_DeletedAccount: String { return self._s[3843]! }
    public var OwnershipTransfer_SetupTwoStepAuth: String { return self._s[3844]! }
    public func Watch_Time_ShortYesterdayAt(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3845]!, self._r[3845]!, [_0])
    }
    public var UserInfo_NotificationsDefault: String { return self._s[3846]! }
    public var SharedMedia_CategoryMedia: String { return self._s[3847]! }
    public var SocksProxySetup_ProxyStatusUnavailable: String { return self._s[3848]! }
    public var Channel_AdminLog_MessageRestrictedForever: String { return self._s[3849]! }
    public var Watch_ChatList_Compose: String { return self._s[3850]! }
    public var Notifications_MessageNotificationsExceptionsHelp: String { return self._s[3851]! }
    public var AutoDownloadSettings_Delimeter: String { return self._s[3852]! }
    public var Watch_Microphone_Access: String { return self._s[3853]! }
    public var Group_Setup_HistoryHeader: String { return self._s[3854]! }
    public var Map_SetThisLocation: String { return self._s[3855]! }
    public var Appearance_ThemePreview_Chat_2_ReplyName: String { return self._s[3856]! }
    public var Activity_UploadingPhoto: String { return self._s[3857]! }
    public var Conversation_Edit: String { return self._s[3859]! }
    public var Group_ErrorSendRestrictedMedia: String { return self._s[3860]! }
    public var Login_TermsOfServiceDecline: String { return self._s[3861]! }
    public var Message_PinnedContactMessage: String { return self._s[3862]! }
    public func Channel_AdminLog_MessageRestrictedNameUsername(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3863]!, self._r[3863]!, [_1, _2])
    }
    public func Login_PhoneBannedEmailBody(_ _1: String, _ _2: String, _ _3: String, _ _4: String, _ _5: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3864]!, self._r[3864]!, [_1, _2, _3, _4, _5])
    }
    public var Appearance_LargeEmoji: String { return self._s[3865]! }
    public var TwoStepAuth_AdditionalPassword: String { return self._s[3867]! }
    public var EditTheme_Edit_Preview_IncomingReplyText: String { return self._s[3868]! }
    public func PUSH_CHAT_DELETE_YOU(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3869]!, self._r[3869]!, [_1, _2])
    }
    public var Passport_Phone_EnterOtherNumber: String { return self._s[3870]! }
    public var Message_PinnedPhotoMessage: String { return self._s[3871]! }
    public var Passport_FieldPhone: String { return self._s[3872]! }
    public var TwoStepAuth_RecoveryEmailAddDescription: String { return self._s[3873]! }
    public var ChatSettings_AutoPlayGifs: String { return self._s[3874]! }
    public var InfoPlist_NSCameraUsageDescription: String { return self._s[3876]! }
    public var Conversation_Call: String { return self._s[3877]! }
    public var Common_TakePhoto: String { return self._s[3879]! }
    public var Group_EditAdmin_RankTitle: String { return self._s[3880]! }
    public var Wallet_Receive_CommentHeader: String { return self._s[3881]! }
    public var Channel_NotificationLoading: String { return self._s[3882]! }
    public func Notification_Exceptions_Sound(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3883]!, self._r[3883]!, [_0])
    }
    public func ScheduledMessages_ScheduledDate(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3884]!, self._r[3884]!, [_0])
    }
    public func PUSH_CHANNEL_MESSAGE_VIDEO(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3885]!, self._r[3885]!, [_1])
    }
    public var Permissions_SiriTitle_v0: String { return self._s[3886]! }
    public func VoiceOver_Chat_VoiceMessageFrom(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3887]!, self._r[3887]!, [_0])
    }
    public func Login_ResetAccountProtected_Text(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3888]!, self._r[3888]!, [_0])
    }
    public var Channel_MessagePhotoRemoved: String { return self._s[3889]! }
    public var Wallet_Info_ReceiveGrams: String { return self._s[3890]! }
    public var Common_edit: String { return self._s[3891]! }
    public var PrivacySettings_AuthSessions: String { return self._s[3892]! }
    public var Month_ShortJune: String { return self._s[3893]! }
    public var PrivacyLastSeenSettings_AlwaysShareWith_Placeholder: String { return self._s[3894]! }
    public var Call_ReportSend: String { return self._s[3895]! }
    public var Watch_LastSeen_JustNow: String { return self._s[3896]! }
    public var Notifications_MessageNotifications: String { return self._s[3897]! }
    public var WallpaperSearch_ColorGreen: String { return self._s[3898]! }
    public var BroadcastListInfo_AddRecipient: String { return self._s[3900]! }
    public var Group_Status: String { return self._s[3901]! }
    public func AutoNightTheme_LocationHelp(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3902]!, self._r[3902]!, [_0, _1])
    }
    public var TextFormat_AddLinkTitle: String { return self._s[3903]! }
    public var ShareMenu_ShareTo: String { return self._s[3904]! }
    public var Conversation_Moderate_Ban: String { return self._s[3905]! }
    public func Conversation_DeleteMessagesFor(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3906]!, self._r[3906]!, [_0])
    }
    public var SharedMedia_ViewInChat: String { return self._s[3907]! }
    public var Map_LiveLocationFor8Hours: String { return self._s[3908]! }
    public func PUSH_PINNED_PHOTO(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3909]!, self._r[3909]!, [_1])
    }
    public func PUSH_PINNED_POLL(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3910]!, self._r[3910]!, [_1, _2])
    }
    public func Map_AccurateTo(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3912]!, self._r[3912]!, [_0])
    }
    public var Map_OpenInHereMaps: String { return self._s[3913]! }
    public var Appearance_ReduceMotion: String { return self._s[3914]! }
    public func PUSH_MESSAGE_TEXT(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3915]!, self._r[3915]!, [_1, _2])
    }
    public var Channel_Setup_TypePublicHelp: String { return self._s[3916]! }
    public var Passport_Identity_EditInternalPassport: String { return self._s[3917]! }
    public var PhotoEditor_Skip: String { return self._s[3918]! }
    public func Contacts_ImportersCount(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[0 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func PUSH_CHAT_MESSAGE_FWDS(_ selector: Int32, _ _2: String, _ _1: String, _ _3: Int32) -> String {
        let form = getPluralizationForm(self.lc, selector)
        return String(format: self._ps[1 * 6 + Int(form.rawValue)]!, _2, _1, _3)
    }
    public func ServiceMessage_GameScoreSelfSimple(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[2 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Conversation_StatusOnline(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[3 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Media_ShareVideo(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[4 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func StickerPack_AddMaskCount(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[5 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func ForwardedPolls(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[6 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func LastSeen_HoursAgo(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[7 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func MessageTimer_Days(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[8 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func MessageTimer_Hours(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[9 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Notifications_ExceptionMuteExpires_Days(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[10 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func StickerPack_StickerCount(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[11 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func VoiceOver_Chat_PollOptionCount(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[12 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func SharedMedia_Generic(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[13 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func ChatList_DeleteConfirmation(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[14 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Media_SharePhoto(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[15 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Theme_UsersCount(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[16 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func GroupInfo_ParticipantCount(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[17 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func ForwardedAudios(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[18 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Notifications_ExceptionMuteExpires_Minutes(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[19 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func VoiceOver_Chat_ContactPhoneNumberCount(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[20 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Call_Seconds(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[21 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func AttachmentMenu_SendGif(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[22 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func SharedMedia_DeleteItemsConfirmation(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[23 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func MessageTimer_ShortMinutes(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[24 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func PasscodeSettings_FailedAttempts(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[25 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func MessageTimer_ShortDays(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[26 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Notifications_ExceptionMuteExpires_Hours(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[27 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func ForwardedGifs(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[28 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Chat_DeleteMessagesConfirmation(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[29 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func MessageTimer_Seconds(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[30 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func StickerPack_RemoveMaskCount(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[31 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func ForwardedPhotos(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[32 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func MessageTimer_ShortWeeks(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[33 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Conversation_LiveLocationMembersCount(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[34 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func PUSH_CHANNEL_MESSAGE_ROUNDS(_ selector: Int32, _ _1: String, _ _2: Int32) -> String {
        let form = getPluralizationForm(self.lc, selector)
        return String(format: self._ps[35 * 6 + Int(form.rawValue)]!, _1, _2)
    }
    public func Conversation_SelectedMessages(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[36 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func MessageTimer_Years(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[37 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func QuickSend_Photos(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[38 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Watch_UserInfo_Mute(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[39 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Call_ShortMinutes(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[40 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func MessagePoll_VotedCount(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[41 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Notification_GameScoreSimple(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[42 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func PUSH_CHAT_MESSAGE_VIDEOS(_ selector: Int32, _ _2: String, _ _1: String, _ _3: Int32) -> String {
        let form = getPluralizationForm(self.lc, selector)
        return String(format: self._ps[43 * 6 + Int(form.rawValue)]!, _2, _1, _3)
    }
    public func PUSH_CHAT_MESSAGES(_ selector: Int32, _ _2: String, _ _1: String, _ _3: Int32) -> String {
        let form = getPluralizationForm(self.lc, selector)
        return String(format: self._ps[44 * 6 + Int(form.rawValue)]!, _2, _1, _3)
    }
    public func AttachmentMenu_SendVideo(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[45 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func MessageTimer_Minutes(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[46 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func UserCount(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[47 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func PUSH_MESSAGE_FWDS(_ selector: Int32, _ _1: String, _ _2: Int32) -> String {
        let form = getPluralizationForm(self.lc, selector)
        return String(format: self._ps[48 * 6 + Int(form.rawValue)]!, _1, _2)
    }
    public func Map_ETAHours(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[49 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func ServiceMessage_GameScoreSimple(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[50 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Watch_LastSeen_MinutesAgo(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[51 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Notification_GameScoreExtended(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[52 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func AttachmentMenu_SendItem(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[53 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Notification_GameScoreSelfExtended(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[54 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func MuteFor_Hours(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[55 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Watch_LastSeen_HoursAgo(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[56 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func PUSH_CHANNEL_MESSAGE_VIDEOS(_ selector: Int32, _ _1: String, _ _2: Int32) -> String {
        let form = getPluralizationForm(self.lc, selector)
        return String(format: self._ps[57 * 6 + Int(form.rawValue)]!, _1, _2)
    }
    public func MessageTimer_ShortSeconds(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[58 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func LiveLocationUpdated_MinutesAgo(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[59 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Conversation_StatusMembers(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[60 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func SharedMedia_Video(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[61 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func MuteExpires_Minutes(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[62 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func MessageTimer_Weeks(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[63 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func LastSeen_MinutesAgo(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[64 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func ForwardedVideos(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[65 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func VoiceOver_Chat_ContactEmailCount(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[66 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Wallpaper_DeleteConfirmation(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[67 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func PUSH_CHAT_MESSAGE_PHOTOS(_ selector: Int32, _ _2: String, _ _1: String, _ _3: Int32) -> String {
        let form = getPluralizationForm(self.lc, selector)
        return String(format: self._ps[68 * 6 + Int(form.rawValue)]!, _2, _1, _3)
    }
    public func Wallet_Updated_MinutesAgo(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[69 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func PUSH_MESSAGE_ROUNDS(_ selector: Int32, _ _1: String, _ _2: Int32) -> String {
        let form = getPluralizationForm(self.lc, selector)
        return String(format: self._ps[70 * 6 + Int(form.rawValue)]!, _1, _2)
    }
    public func PUSH_CHANNEL_MESSAGES(_ selector: Int32, _ _1: String, _ _2: Int32) -> String {
        let form = getPluralizationForm(self.lc, selector)
        return String(format: self._ps[71 * 6 + Int(form.rawValue)]!, _1, _2)
    }
    public func Call_ShortSeconds(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[72 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func LiveLocation_MenuChatsCount(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[73 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func ForwardedLocations(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[74 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func MuteExpires_Days(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[75 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func ForwardedAuthorsOthers(_ selector: Int32, _ _0: String, _ _1: String) -> String {
        let form = getPluralizationForm(self.lc, selector)
        return String(format: self._ps[76 * 6 + Int(form.rawValue)]!, _0, _1)
    }
    public func Media_ShareItem(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[77 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Invitation_Members(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[78 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func ForwardedMessages(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[79 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func ForwardedFiles(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[80 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func InviteText_ContactsCountText(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[81 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Forward_ConfirmMultipleFiles(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[82 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Passport_Scans(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[83 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Notifications_Exceptions(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[84 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Wallet_Updated_HoursAgo(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[85 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func SharedMedia_File(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[86 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func ServiceMessage_GameScoreExtended(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[87 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func DialogList_LiveLocationChatsCount(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[88 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func ForwardedContacts(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[89 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func PrivacyLastSeenSettings_AddUsers(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[90 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Call_Minutes(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[91 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func VoiceOver_Chat_PollVotes(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[92 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func ServiceMessage_GameScoreSelfExtended(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[93 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func AttachmentMenu_SendPhoto(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[94 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func ChatList_SelectedChats(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[95 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func ForwardedVideoMessages(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[96 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func MessageTimer_ShortHours(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[97 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func MessageTimer_Months(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[98 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Map_ETAMinutes(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[99 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func StickerPack_AddStickerCount(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[100 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func PUSH_CHANNEL_MESSAGE_PHOTOS(_ selector: Int32, _ _1: String, _ _2: Int32) -> String {
        let form = getPluralizationForm(self.lc, selector)
        return String(format: self._ps[101 * 6 + Int(form.rawValue)]!, _1, _2)
    }
    public func StickerPack_RemoveStickerCount(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[102 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func CreatePoll_AddMoreOptions(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[103 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func PUSH_CHANNEL_MESSAGE_FWDS(_ selector: Int32, _ _1: String, _ _2: Int32) -> String {
        let form = getPluralizationForm(self.lc, selector)
        return String(format: self._ps[104 * 6 + Int(form.rawValue)]!, _1, _2)
    }
    public func SharedMedia_Photo(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[105 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func ForwardedStickers(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[106 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func SharedMedia_Link(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[107 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func PUSH_MESSAGE_PHOTOS(_ selector: Int32, _ _1: String, _ _2: Int32) -> String {
        let form = getPluralizationForm(self.lc, selector)
        return String(format: self._ps[108 * 6 + Int(form.rawValue)]!, _1, _2)
    }
    public func MuteFor_Days(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[109 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Notification_GameScoreSelfSimple(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[110 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func PUSH_MESSAGE_VIDEOS(_ selector: Int32, _ _1: String, _ _2: Int32) -> String {
        let form = getPluralizationForm(self.lc, selector)
        return String(format: self._ps[111 * 6 + Int(form.rawValue)]!, _1, _2)
    }
    public func MuteExpires_Hours(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[112 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func PUSH_MESSAGES(_ selector: Int32, _ _1: String, _ _2: Int32) -> String {
        let form = getPluralizationForm(self.lc, selector)
        return String(format: self._ps[113 * 6 + Int(form.rawValue)]!, _1, _2)
    }
    public func PUSH_CHAT_MESSAGE_ROUNDS(_ selector: Int32, _ _2: String, _ _1: String, _ _3: Int32) -> String {
        let form = getPluralizationForm(self.lc, selector)
        return String(format: self._ps[114 * 6 + Int(form.rawValue)]!, _2, _1, _3)
    }
    public func Conversation_StatusSubscribers(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[115 * 6 + Int(form.rawValue)]!, stringValue)
    }
        
    public init(primaryComponent: PresentationStringsComponent, secondaryComponent: PresentationStringsComponent?, groupingSeparator: String) {
        self.primaryComponent = primaryComponent
        self.secondaryComponent = secondaryComponent
        self.groupingSeparator = groupingSeparator
        
        self.baseLanguageCode = secondaryComponent?.languageCode ?? primaryComponent.languageCode
        
        let languageCode = primaryComponent.pluralizationRulesCode ?? primaryComponent.languageCode
        var rawCode = languageCode as NSString
        var range = rawCode.range(of: "_")
        if range.location != NSNotFound {
            rawCode = rawCode.substring(to: range.location) as NSString
        }
        range = rawCode.range(of: "-")
        if range.location != NSNotFound {
            rawCode = rawCode.substring(to: range.location) as NSString
        }
        rawCode = rawCode.lowercased as NSString
        var lc: UInt32 = 0
        for i in 0 ..< rawCode.length {
            lc = (lc << 8) + UInt32(rawCode.character(at: i))
        }
        self.lc = lc

        var _s: [Int: String] = [:]
        var _r: [Int: [(Int, NSRange)]] = [:]
        
        let loadedKeyMapping = keyMapping
        
        let sIdList: [Int] = loadedKeyMapping.0
        let sKeyList: [String] = loadedKeyMapping.1
        let sArgIdList: [Int] = loadedKeyMapping.2
        for i in 0 ..< sIdList.count {
            _s[sIdList[i]] = getValue(primaryComponent, secondaryComponent, sKeyList[i])
        }
        for i in 0 ..< sArgIdList.count {
            _r[sArgIdList[i]] = extractArgumentRanges(_s[sArgIdList[i]]!)
        }
        self._s = _s
        self._r = _r

        var _ps: [Int: String] = [:]
        let pIdList: [Int] = loadedKeyMapping.3
        let pKeyList: [String] = loadedKeyMapping.4
        for i in 0 ..< pIdList.count {
            for form in 0 ..< 6 {
                _ps[pIdList[i] * 6 + form] = getValueWithForm(primaryComponent, secondaryComponent, pKeyList[i], PluralizationForm(rawValue: Int32(form))!)
            }
        }
        self._ps = _ps
    }
    
    public static func ==(lhs: PresentationStrings, rhs: PresentationStrings) -> Bool {
        return lhs === rhs
    }
}

