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
    public var SocksProxySetup_Secret: String { return self._s[0]! }
    public var Channel_AdminLog_EmptyTitle: String { return self._s[2]! }
    public var Contacts_PermissionsText: String { return self._s[3]! }
    public var SettingsSearch_Synonyms_Notifications_MessageNotificationsSound: String { return self._s[4]! }
    public var Map_Work: String { return self._s[5]! }
    public var Channel_AddBotAsAdmin: String { return self._s[6]! }
    public var TwoFactorSetup_Done_Action: String { return self._s[7]! }
    public var Call_CallInProgressTitle: String { return self._s[8]! }
    public var Compose_NewChannel_Members: String { return self._s[9]! }
    public var FastTwoStepSetup_PasswordPlaceholder: String { return self._s[10]! }
    public func Channel_AdminLog_MessageInvitedName(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[11]!, self._r[11]!, [_1])
    }
    public var VoiceChat_MutePeer: String { return self._s[14]! }
    public func Notification_MessageLifetimeRemoved(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[15]!, self._r[15]!, [_1])
    }
    public var Undo_DeletedGroup: String { return self._s[17]! }
    public var ChatListFolder_CategoryNonContacts: String { return self._s[18]! }
    public var Gif_NoGifsPlaceholder: String { return self._s[19]! }
    public var Conversation_ShareInlineBotLocationConfirmation: String { return self._s[20]! }
    public func VoiceChat_StatusLateBy(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[21]!, self._r[21]!, [_0])
    }
    public var AutoNightTheme_ScheduleSection: String { return self._s[22]! }
    public var Map_LiveLocationTitle: String { return self._s[23]! }
    public var Passport_PasswordCreate: String { return self._s[24]! }
    public var Settings_ProxyConnected: String { return self._s[25]! }
    public func PUSH_PINNED_TEXT(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[26]!, self._r[26]!, [_1, _2])
    }
    public var Channel_Management_LabelOwner: String { return self._s[27]! }
    public var ApplyLanguage_ApplySuccess: String { return self._s[28]! }
    public var Group_Setup_HistoryHidden: String { return self._s[29]! }
    public var Month_ShortNovember: String { return self._s[30]! }
    public var Call_ReportIncludeLog: String { return self._s[31]! }
    public var ChatList_RemoveFolder: String { return self._s[32]! }
    public var PrivacyPhoneNumberSettings_CustomHelp: String { return self._s[33]! }
    public var Appearance_ThemePreview_ChatList_5_Text: String { return self._s[34]! }
    public var Checkout_Receipt_Title: String { return self._s[35]! }
    public func Conversation_ClearChatConfirmation(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[36]!, self._r[36]!, [_0])
    }
    public var AuthSessions_LogOutApplicationsHelp: String { return self._s[37]! }
    public var SearchImages_Title: String { return self._s[38]! }
    public var Notification_PaymentSent: String { return self._s[39]! }
    public var Appearance_TintAllColors: String { return self._s[40]! }
    public var Group_Setup_TypePublicHelp: String { return self._s[41]! }
    public var ChatSettings_Cache: String { return self._s[42]! }
    public var InviteLink_RevokedLinks: String { return self._s[43]! }
    public var Login_InvalidLastNameError: String { return self._s[44]! }
    public var PeerInfo_PaneMedia: String { return self._s[45]! }
    public var InviteLink_Revoked: String { return self._s[46]! }
    public var StickerPacks_ActionShare: String { return self._s[47]! }
    public var GroupPermission_PermissionGloballyDisabled: String { return self._s[48]! }
    public var LiveLocationUpdated_JustNow: String { return self._s[49]! }
    public func Map_LiveLocationPrivateDescription(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[50]!, self._r[50]!, [_0])
    }
    public var Channel_Info_Members: String { return self._s[51]! }
    public func Channel_CommentsGroup_HeaderSet(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[52]!, self._r[52]!, [_0])
    }
    public var Common_edit: String { return self._s[53]! }
    public var ChatList_DeleteSavedMessagesConfirmationText: String { return self._s[55]! }
    public var OldChannels_GroupEmptyFormat: String { return self._s[56]! }
    public func PUSH_PINNED_AUDIO(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[57]!, self._r[57]!, [_1])
    }
    public var Passport_DiscardMessageAction: String { return self._s[58]! }
    public var VoiceChat_StopRecordingTitle: String { return self._s[59]! }
    public var Passport_FieldOneOf_FinalDelimeter: String { return self._s[60]! }
    public var Stickers_SuggestNone: String { return self._s[61]! }
    public func Channel_AdminLog_JoinedViaInviteLink(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[62]!, self._r[62]!, [_1, _2])
    }
    public var Channel_AdminLog_CanPinMessages: String { return self._s[63]! }
    public var Stickers_Search: String { return self._s[65]! }
    public var Passport_Identity_EditPersonalDetails: String { return self._s[66]! }
    public var NotificationSettings_ShowNotificationsAllAccounts: String { return self._s[67]! }
    public var Login_ContinueWithLocalization: String { return self._s[68]! }
    public var Privacy_ProfilePhoto_NeverShareWith_Title: String { return self._s[69]! }
    public var TextFormat_Italic: String { return self._s[71]! }
    public var ChatList_Search_NoResultsFitlerLinks: String { return self._s[73]! }
    public var Stickers_GroupChooseStickerPack: String { return self._s[74]! }
    public var Notification_MessageLifetime1w: String { return self._s[75]! }
    public var Channel_Management_AddModerator: String { return self._s[76]! }
    public var Conversation_UnsupportedMediaPlaceholder: String { return self._s[77]! }
    public var Gif_Search: String { return self._s[78]! }
    public var Checkout_ErrorGeneric: String { return self._s[79]! }
    public var Conversation_ContextMenuSendMessage: String { return self._s[80]! }
    public var Map_SetThisLocation: String { return self._s[81]! }
    public var Notifications_ExceptionsDefaultSound: String { return self._s[82]! }
    public var PrivacySettings_AutoArchiveInfo: String { return self._s[83]! }
    public var Stats_NotificationsTitle: String { return self._s[84]! }
    public var Conversation_ClearSecretHistory: String { return self._s[86]! }
    public func Conversation_DeleteAllMessagesInChat(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[87]!, self._r[87]!, [_0])
    }
    public func Notification_CallFormat(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[88]!, self._r[88]!, [_1, _2])
    }
    public var ChatListFolder_DiscardDiscard: String { return self._s[89]! }
    public var PrivacyLastSeenSettings_AlwaysShareWith: String { return self._s[90]! }
    public var Contacts_InviteFriends: String { return self._s[91]! }
    public var Group_LinkedChannel: String { return self._s[92]! }
    public var ChatList_DeleteForAllMembers: String { return self._s[93]! }
    public var Notification_PassportValuePhone: String { return self._s[95]! }
    public func InviteText_SingleContact(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[96]!, self._r[96]!, [_0])
    }
    public var UserInfo_BotHelp: String { return self._s[98]! }
    public var Passport_Identity_MainPage: String { return self._s[100]! }
    public var LogoutOptions_ContactSupportText: String { return self._s[101]! }
    public func VoiceOver_Chat_Title(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[102]!, self._r[102]!, [_0])
    }
    public var StickerPack_ShowStickers: String { return self._s[104]! }
    public var AttachmentMenu_PhotoOrVideo: String { return self._s[105]! }
    public var Map_Satellite: String { return self._s[106]! }
    public var Passport_Identity_MainPageHelp: String { return self._s[107]! }
    public var Profile_About: String { return self._s[109]! }
    public var Group_Setup_TypePrivate: String { return self._s[110]! }
    public func ScheduleVoiceChat_ChannelText(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[111]!, self._r[111]!, [_0])
    }
    public var Notifications_ChannelNotifications: String { return self._s[112]! }
    public var Call_VoiceOver_VoiceCallIncoming: String { return self._s[113]! }
    public func Login_WillCallYou(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[114]!, self._r[114]!, [_0])
    }
    public var WallpaperPreview_Motion: String { return self._s[115]! }
    public var Message_VideoMessage: String { return self._s[116]! }
    public var SharedMedia_CategoryOther: String { return self._s[118]! }
    public var Passport_FieldIdentityUploadHelp: String { return self._s[119]! }
    public var PUSH_REMINDER_TITLE: String { return self._s[120]! }
    public var Appearance_ThemePreview_Chat_3_Text: String { return self._s[122]! }
    public var Login_ResetAccountProtected_Reset: String { return self._s[124]! }
    public var Passport_Identity_TypeInternalPassportUploadScan: String { return self._s[125]! }
    public func Location_ProximityNotification_Notify(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[126]!, self._r[126]!, [_0])
    }
    public var ChatList_PeerTypeContact: String { return self._s[127]! }
    public var Stickers_SuggestAll: String { return self._s[129]! }
    public var EmptyGroupInfo_Line3: String { return self._s[130]! }
    public var Login_InvalidPhoneError: String { return self._s[131]! }
    public var MediaPicker_GroupDescription: String { return self._s[132]! }
    public func UserInfo_LinkForwardTooltip_Chat_One(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[133]!, self._r[133]!, [_0])
    }
    public var NetworkUsageSettings_MediaDocumentDataSection: String { return self._s[134]! }
    public var Conversation_PrivateChannelTimeLimitedAlertText: String { return self._s[135]! }
    public var PrivateDataSettings_Title: String { return self._s[136]! }
    public var SecretChat_Title: String { return self._s[137]! }
    public var Privacy_ChatsTitle: String { return self._s[138]! }
    public var EditProfile_NameAndPhotoHelp: String { return self._s[139]! }
    public var Watch_MessageView_Forward: String { return self._s[141]! }
    public var ChannelMembers_WhoCanAddMembers_AllMembers: String { return self._s[142]! }
    public func PUSH_PINNED_QUIZ(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[143]!, self._r[143]!, [_1, _2])
    }
    public func Channel_AdminLog_EndedVoiceChat(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[144]!, self._r[144]!, [_1])
    }
    public var InviteLink_ExpiredLink: String { return self._s[145]! }
    public var PhotoEditor_DiscardChanges: String { return self._s[146]! }
    public var SocksProxySetup_AdNoticeHelp: String { return self._s[147]! }
    public var Date_DialogDateFormat: String { return self._s[148]! }
    public var SettingsSearch_Synonyms_Proxy_Title: String { return self._s[149]! }
    public var Notifications_AlertTones: String { return self._s[150]! }
    public var Permissions_SiriAllow_v0: String { return self._s[151]! }
    public var Tour_StartButton: String { return self._s[152]! }
    public var Stats_InstantViewInteractionsTitle: String { return self._s[153]! }
    public var UserInfo_ScamUserWarning: String { return self._s[156]! }
    public var NotificationsSound_Chime: String { return self._s[157]! }
    public var Update_Skip: String { return self._s[158]! }
    public func ChannelInfo_ChannelForbidden(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[159]!, self._r[159]!, [_0])
    }
    public var SettingsSearch_Synonyms_EditProfile_PhoneNumber: String { return self._s[160]! }
    public var Notifications_PermissionsTitle: String { return self._s[161]! }
    public var Channel_AdminLog_BanSendMedia: String { return self._s[162]! }
    public var Notifications_Badge_CountUnreadMessages: String { return self._s[163]! }
    public var Appearance_AppIcon: String { return self._s[164]! }
    public var Passport_Identity_FilesUploadNew: String { return self._s[165]! }
    public func Passport_Email_UseTelegramEmail(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[166]!, self._r[166]!, [_0])
    }
    public var CreatePoll_QuizTitle: String { return self._s[167]! }
    public var DialogList_DeleteConversationConfirmation: String { return self._s[168]! }
    public var NotificationsSound_Calypso: String { return self._s[169]! }
    public var ChannelMembers_GroupAdminsTitle: String { return self._s[171]! }
    public var Checkout_NewCard_PaymentCard: String { return self._s[172]! }
    public var Wallpaper_SetCustomBackground: String { return self._s[174]! }
    public var Conversation_ContextMenuOpenProfile: String { return self._s[175]! }
    public func PUSH_MESSAGE_VIDEO_SECRET(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[177]!, self._r[177]!, [_1])
    }
    public var AuthSessions_Terminate: String { return self._s[178]! }
    public var ShareFileTip_CloseTip: String { return self._s[179]! }
    public var ChatSettings_DownloadInBackgroundInfo: String { return self._s[180]! }
    public var Channel_Moderator_AccessLevelRevoke: String { return self._s[181]! }
    public var Channel_AdminLogFilter_EventsDeletedMessages: String { return self._s[182]! }
    public var Passport_Language_fr: String { return self._s[183]! }
    public func Watch_Time_ShortTodayAt(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[185]!, self._r[185]!, [_0])
    }
    public var Passport_Identity_TypeIdentityCard: String { return self._s[186]! }
    public var VoiceChat_MuteForMe: String { return self._s[187]! }
    public func Conversation_OpenBotLinkAllowMessages(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[188]!, self._r[188]!, [_0])
    }
    public var ReportPeer_ReasonCopyright: String { return self._s[189]! }
    public var Permissions_PeopleNearbyText_v0: String { return self._s[191]! }
    public var Channel_Stickers_NotFoundHelp: String { return self._s[192]! }
    public var Passport_Identity_AddDriversLicense: String { return self._s[193]! }
    public var AutoDownloadSettings_AutodownloadFiles: String { return self._s[194]! }
    public var Permissions_SiriAllowInSettings_v0: String { return self._s[195]! }
    public func Conversation_ForwardTooltip_ManyChats_Many(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[196]!, self._r[196]!, [_0, _1])
    }
    public var ApplyLanguage_ChangeLanguageTitle: String { return self._s[197]! }
    public var Map_LocatingError: String { return self._s[199]! }
    public var ChatSettings_AutoDownloadSettings_TypePhoto: String { return self._s[200]! }
    public func VoiceOver_Chat_MusicFrom(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[202]!, self._r[202]!, [_0])
    }
    public func Contacts_AccessDeniedHelpLandscape(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[203]!, self._r[203]!, [_0])
    }
    public var Channel_AdminLog_EmptyFilterText: String { return self._s[204]! }
    public var Login_SmsRequestState2: String { return self._s[205]! }
    public var Conversation_Unmute: String { return self._s[207]! }
    public var TwoFactorSetup_Intro_Text: String { return self._s[208]! }
    public var Channel_AdminLog_BanSendMessages: String { return self._s[209]! }
    public func Channel_Management_RemovedBy(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[210]!, self._r[210]!, [_0])
    }
    public var AccessDenied_LocationDenied: String { return self._s[211]! }
    public var Share_AuthTitle: String { return self._s[212]! }
    public var Month_ShortAugust: String { return self._s[213]! }
    public func Notification_PinnedDeletedMessage(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[214]!, self._r[214]!, [_0])
    }
    public var Channel_BanUser_PermissionSendMedia: String { return self._s[215]! }
    public var SettingsSearch_Synonyms_Data_DownloadInBackground: String { return self._s[216]! }
    public func PUSH_CONTACT_JOINED(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[217]!, self._r[217]!, [_1])
    }
    public var WallpaperSearch_ColorTitle: String { return self._s[219]! }
    public var Wallpaper_Search: String { return self._s[220]! }
    public var ClearCache_StorageUsage: String { return self._s[221]! }
    public var CreatePoll_TextPlaceholder: String { return self._s[222]! }
    public var Conversation_EditingMessagePanelTitle: String { return self._s[223]! }
    public var Channel_EditAdmin_PermissionBanUsers: String { return self._s[224]! }
    public var OldChannels_NoticeCreateText: String { return self._s[225]! }
    public var ProfilePhoto_MainVideo: String { return self._s[226]! }
    public var VoiceChat_StatusListening: String { return self._s[227]! }
    public var InviteLink_DeleteLinkAlert_Text: String { return self._s[228]! }
    public var UserInfo_NotificationsDisabled: String { return self._s[229]! }
    public var Map_Unknown: String { return self._s[230]! }
    public var Notifications_MessageNotificationsAlert: String { return self._s[231]! }
    public var Conversation_StopQuiz: String { return self._s[232]! }
    public var Checkout_LiabilityAlertTitle: String { return self._s[233]! }
    public func Username_UsernameIsAvailable(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[234]!, self._r[234]!, [_0])
    }
    public var CreatePoll_OptionPlaceholder: String { return self._s[235]! }
    public var Conversation_RestrictedStickers: String { return self._s[236]! }
    public var MemberSearch_BotSection: String { return self._s[238]! }
    public var Channel_Management_AddModeratorHelp: String { return self._s[240]! }
    public var Widget_ShortcutsGalleryDescription: String { return self._s[241]! }
    public var MaskStickerSettings_Title: String { return self._s[242]! }
    public var ShareMenu_Comment: String { return self._s[243]! }
    public var GroupInfo_Notifications: String { return self._s[244]! }
    public var CheckoutInfo_ReceiverInfoTitle: String { return self._s[245]! }
    public func DialogList_EncryptedChatStartedOutgoing(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[246]!, self._r[246]!, [_0])
    }
    public var Conversation_ContextMenuCopyLink: String { return self._s[247]! }
    public var VoiceChat_MutedHelp: String { return self._s[250]! }
    public var ChatListFolder_CategoryMuted: String { return self._s[251]! }
    public var TwoStepAuth_AddHintDescription: String { return self._s[252]! }
    public func VoiceOver_Chat_Duration(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[253]!, self._r[253]!, [_0])
    }
    public var Conversation_ClousStorageInfo_Description3: String { return self._s[254]! }
    public var BroadcastGroups_LimitAlert_SettingsTip: String { return self._s[255]! }
    public var Contacts_SortByPresence: String { return self._s[256]! }
    public var Watch_Location_Access: String { return self._s[257]! }
    public var WallpaperPreview_CustomColorTopText: String { return self._s[258]! }
    public var Passport_Address_TypeBankStatement: String { return self._s[259]! }
    public var Group_Username_RevokeExistingUsernamesInfo: String { return self._s[260]! }
    public var Conversation_ClearPrivateHistory: String { return self._s[261]! }
    public var ChatList_Mute: String { return self._s[264]! }
    public var Channel_AdminLog_CanDeleteMessagesOfOthers: String { return self._s[265]! }
    public var Stats_PostsTitle: String { return self._s[266]! }
    public func Conversation_AutoremoveTimerSetGroup(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[267]!, self._r[267]!, [_1])
    }
    public var Paint_Masks: String { return self._s[269]! }
    public var PasscodeSettings_TryAgainIn1Minute: String { return self._s[272]! }
    public var Chat_AttachmentLimitReached: String { return self._s[273]! }
    public var StickerPackActionInfo_ArchivedTitle: String { return self._s[274]! }
    public var Watch_Stickers_StickerPacks: String { return self._s[276]! }
    public var Channel_Setup_Title: String { return self._s[277]! }
    public var GroupInfo_Administrators: String { return self._s[278]! }
    public var InviteLink_PublicLink: String { return self._s[279]! }
    public var InviteLink_DeleteLinkAlert_Action: String { return self._s[281]! }
    public var NotificationSettings_ShowNotificationsAllAccountsInfoOff: String { return self._s[282]! }
    public var Conversation_ContextMenuDiscuss: String { return self._s[283]! }
    public var StickerPack_BuiltinPackName: String { return self._s[284]! }
    public var Conversation_GreetingText: String { return self._s[286]! }
    public var TwoStepAuth_RecoveryEmailChangeDescription: String { return self._s[288]! }
    public var Checkout_ShippingMethod: String { return self._s[290]! }
    public var ClearCache_FreeSpace: String { return self._s[291]! }
    public var EditTheme_Expand_Preview_IncomingReplyText: String { return self._s[292]! }
    public var SettingsSearch_Synonyms_Notifications_ChannelNotificationsSound: String { return self._s[295]! }
    public func TwoStepAuth_ConfirmEmailDescription(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[296]!, self._r[296]!, [_1])
    }
    public var Conversation_typing: String { return self._s[297]! }
    public func PrivacySettings_LastSeenContactsMinus(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[299]!, self._r[299]!, [_0])
    }
    public var WebSearch_RecentSectionTitle: String { return self._s[300]! }
    public var VoiceChat_EndConfirmationTitle: String { return self._s[301]! }
    public var VoiceChat_TapToAddPhoto: String { return self._s[302]! }
    public var ChatList_UnhideAction: String { return self._s[304]! }
    public var PasscodeSettings_6DigitCode: String { return self._s[305]! }
    public var CallFeedback_AddComment: String { return self._s[306]! }
    public var LoginPassword_PasswordHelp: String { return self._s[307]! }
    public var Call_Flip: String { return self._s[308]! }
    public var Weekday_ShortWednesday: String { return self._s[310]! }
    public var VoiceOver_Chat_PollFinalResults: String { return self._s[311]! }
    public var ScheduleVoiceChat_Title: String { return self._s[312]! }
    public var PeerInfo_ButtonAddMember: String { return self._s[313]! }
    public var Call_Decline: String { return self._s[315]! }
    public var VoiceChat_InviteMemberToGroupFirstAdd: String { return self._s[316]! }
    public var Join_ChannelsTooMuch: String { return self._s[318]! }
    public func PUSH_CHANNEL_MESSAGE_NOTEXT(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[319]!, self._r[319]!, [_1])
    }
    public var Passport_Identity_Selfie: String { return self._s[320]! }
    public var Privacy_ContactsTitle: String { return self._s[321]! }
    public var GroupInfo_InviteLink_Title: String { return self._s[323]! }
    public var TwoFactorSetup_Password_PlaceholderPassword: String { return self._s[324]! }
    public func Channel_AdminLog_UpdatedParticipantVolume(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[325]!, self._r[325]!, [_1, _2, _3])
    }
    public var Conversation_OpenFile: String { return self._s[327]! }
    public var Map_SetThisPlace: String { return self._s[328]! }
    public var Channel_Info_Management: String { return self._s[329]! }
    public var Passport_Language_hr: String { return self._s[330]! }
    public var VoiceChat_Title: String { return self._s[331]! }
    public var EditTheme_Edit_Preview_IncomingText: String { return self._s[335]! }
    public var VoiceChat_EditBioSave: String { return self._s[336]! }
    public var OpenFile_Proceed: String { return self._s[337]! }
    public var Conversation_SecretChatContextBotAlert: String { return self._s[339]! }
    public var GroupInfo_Permissions_SlowmodeValue_Off: String { return self._s[340]! }
    public var Privacy_Calls_P2PContacts: String { return self._s[341]! }
    public var Appearance_PickAccentColor: String { return self._s[342]! }
    public var MediaPicker_TapToUngroupDescription: String { return self._s[343]! }
    public var Localization_EnglishLanguageName: String { return self._s[344]! }
    public var Stickers_SuggestStickers: String { return self._s[345]! }
    public var Passport_Language_ko: String { return self._s[346]! }
    public var Settings_ProxyDisabled: String { return self._s[347]! }
    public var PrivacySettings_PasscodeOff: String { return self._s[348]! }
    public var Undo_LeftChannel: String { return self._s[349]! }
    public var Appearance_AutoNightThemeDisabled: String { return self._s[350]! }
    public var TextFormat_Bold: String { return self._s[351]! }
    public var Login_InfoTitle: String { return self._s[352]! }
    public var Channel_BanUser_PermissionSendPolls: String { return self._s[353]! }
    public var Settings_AddAnotherAccount: String { return self._s[354]! }
    public var GroupPermission_NewTitle: String { return self._s[355]! }
    public var Login_SelectCountry_Title: String { return self._s[356]! }
    public var Cache_ServiceFiles: String { return self._s[357]! }
    public func AutoremoveSetup_TimerValueAfter(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[358]!, self._r[358]!, [_0])
    }
    public var Passport_Language_nl: String { return self._s[359]! }
    public var Contacts_TopSection: String { return self._s[360]! }
    public var Passport_Identity_DateOfBirthPlaceholder: String { return self._s[361]! }
    public var VoiceChat_StatusInvited: String { return self._s[363]! }
    public var Conversation_ContextMenuReport: String { return self._s[364]! }
    public func Login_BannedPhoneBody(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[365]!, self._r[365]!, [_0])
    }
    public var Conversation_Search: String { return self._s[366]! }
    public var Group_Setup_HistoryVisibleHelp: String { return self._s[368]! }
    public var ReportPeer_AlertSuccess: String { return self._s[370]! }
    public var AutoNightTheme_Title: String { return self._s[372]! }
    public func Notification_PinnedTextMessage(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[374]!, self._r[374]!, [_0, _1])
    }
    public func Conversation_OpenBotLinkText(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[375]!, self._r[375]!, [_0])
    }
    public var Conversation_ShareBotContactConfirmation: String { return self._s[376]! }
    public var TwoStepAuth_RecoveryCode: String { return self._s[377]! }
    public var GroupInfo_Permissions_BroadcastTitle: String { return self._s[378]! }
    public var SocksProxySetup_ConnectAndSave: String { return self._s[379]! }
    public func MESSAGE_INVOICE(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[380]!, self._r[380]!, [_1, _2])
    }
    public func Channel_AdminLog_MessageChangedGroupUsername(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[381]!, self._r[381]!, [_0])
    }
    public func BroadcastGroups_LimitAlert_Text(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[382]!, self._r[382]!, [_0])
    }
    public var Replies_BlockAndDeleteRepliesActionTitle: String { return self._s[384]! }
    public func Notification_GroupInviter(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[385]!, self._r[385]!, [_0])
    }
    public var VoiceChat_CopyInviteLink: String { return self._s[386]! }
    public var Conversation_InfoGroup: String { return self._s[387]! }
    public func Map_AccurateTo(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[389]!, self._r[389]!, [_0])
    }
    public var Conversation_ChatBackground: String { return self._s[390]! }
    public var PhotoEditor_Set: String { return self._s[391]! }
    public func Channel_Management_PromotedBy(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[393]!, self._r[393]!, [_0])
    }
    public var IntentsSettings_SuggestedChatsContacts: String { return self._s[394]! }
    public var Passport_Phone_Title: String { return self._s[396]! }
    public var Conversation_EditingMessageMediaChange: String { return self._s[397]! }
    public var Channel_LinkItem: String { return self._s[398]! }
    public var VoiceChat_EndConfirmationText: String { return self._s[399]! }
    public func PUSH_CHAT_DELETE_MEMBER(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[400]!, self._r[400]!, [_1, _2, _3])
    }
    public var Conversation_DeleteManyMessages: String { return self._s[402]! }
    public var Notifications_Badge_IncludeMutedChats: String { return self._s[403]! }
    public var Channel_AddUserLeftError: String { return self._s[405]! }
    public var AuthSessions_AddedDeviceTitle: String { return self._s[407]! }
    public var Privacy_Calls_NeverAllow_Placeholder: String { return self._s[408]! }
    public var Settings_ProxyConnecting: String { return self._s[409]! }
    public var Theme_Colors_Accent: String { return self._s[411]! }
    public var Theme_Colors_ColorWallpaperWarning: String { return self._s[412]! }
    public func PUSH_PHONE_CALL_MISSED(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[414]!, self._r[414]!, [_1])
    }
    public var Passport_Language_lo: String { return self._s[415]! }
    public func Watch_Time_ShortWeekdayAt(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[417]!, self._r[417]!, [_1, _2])
    }
    public var Permissions_NotificationsText_v0: String { return self._s[418]! }
    public var BroadcastGroups_LimitAlert_Title: String { return self._s[419]! }
    public var ChatList_Context_RemoveFromRecents: String { return self._s[420]! }
    public var Watch_GroupInfo_Title: String { return self._s[421]! }
    public var Settings_AddDevice: String { return self._s[423]! }
    public var WallpaperPreview_SwipeColorsTopText: String { return self._s[424]! }
    public func PUSH_CHANNEL_ALBUM(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[425]!, self._r[425]!, [_1])
    }
    public var Conversation_AutoremoveActionEdit: String { return self._s[426]! }
    public var TwoStepAuth_Disable: String { return self._s[428]! }
    public func Conversation_AddNameToContacts(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[429]!, self._r[429]!, [_0])
    }
    public func Time_PreciseDate_m10(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[430]!, self._r[430]!, [_1, _2, _3])
    }
    public func Login_WillSendSms(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[431]!, self._r[431]!, [_0])
    }
    public var Channel_AdminLog_BanReadMessages: String { return self._s[432]! }
    public var Undo_ChatDeleted: String { return self._s[433]! }
    public var ContactInfo_URLLabelHomepage: String { return self._s[434]! }
    public func PUSH_CHAT_MESSAGE_STICKER(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[435]!, self._r[435]!, [_1, _2, _3])
    }
    public var FastTwoStepSetup_EmailHelp: String { return self._s[436]! }
    public var Contacts_SelectAll: String { return self._s[437]! }
    public var Privacy_ContactsReset: String { return self._s[438]! }
    public var AttachmentMenu_File: String { return self._s[440]! }
    public var PasscodeSettings_EncryptData: String { return self._s[441]! }
    public var EditTheme_ThemeTemplateAlertText: String { return self._s[442]! }
    public func Privacy_GroupsAndChannels_InviteToChannelError(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[444]!, self._r[444]!, [_0, _1])
    }
    public func Profile_CreateEncryptedChatOutdatedError(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[445]!, self._r[445]!, [_0, _1])
    }
    public var PhotoEditor_ShadowsTint: String { return self._s[447]! }
    public var GroupInfo_ChatAdmins: String { return self._s[448]! }
    public var ArchivedChats_IntroTitle2: String { return self._s[449]! }
    public var Cache_LowDiskSpaceText: String { return self._s[450]! }
    public var CreatePoll_Anonymous: String { return self._s[451]! }
    public var Report_AdditionalDetailsText: String { return self._s[452]! }
    public var Checkout_PaymentMethod_New: String { return self._s[453]! }
    public var Invitation_JoinGroup: String { return self._s[454]! }
    public func Time_MonthOfYear_m4(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[457]!, self._r[457]!, [_0])
    }
    public var CheckoutInfo_SaveInfoHelp: String { return self._s[458]! }
    public var Notification_Reply: String { return self._s[460]! }
    public func Login_PhoneBannedEmailSubject(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[461]!, self._r[461]!, [_0])
    }
    public var Login_PhoneTitle: String { return self._s[462]! }
    public var VoiceChat_UnmuteHelp: String { return self._s[463]! }
    public var VoiceOver_Media_PlaybackRateNormal: String { return self._s[464]! }
    public func PUSH_CHAT_MESSAGE_INVOICE(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[465]!, self._r[465]!, [_1, _2, _3])
    }
    public var Appearance_TextSize_Title: String { return self._s[466]! }
    public var NetworkUsageSettings_MediaImageDataSection: String { return self._s[468]! }
    public var VoiceOver_Navigation_Compose: String { return self._s[469]! }
    public func Channel_AdminLog_MessageChangedAutoremoveTimeoutRemove(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[470]!, self._r[470]!, [_1])
    }
    public var Passport_InfoText: String { return self._s[471]! }
    public var ApplyLanguage_ApplyLanguageAction: String { return self._s[472]! }
    public var MessagePoll_LabelClosed: String { return self._s[474]! }
    public var AttachmentMenu_SendAsFiles: String { return self._s[475]! }
    public var KeyCommand_FocusOnInputField: String { return self._s[476]! }
    public var Conversation_ContextViewThread: String { return self._s[477]! }
    public var ChatImport_SelectionErrorGroupGeneric: String { return self._s[478]! }
    public var Privacy_SecretChatsLinkPreviews: String { return self._s[480]! }
    public var Permissions_PeopleNearbyAllow_v0: String { return self._s[481]! }
    public var Conversation_ContextMenuMention: String { return self._s[483]! }
    public var CreatePoll_QuizInfo: String { return self._s[484]! }
    public var Appearance_ThemePreview_ChatList_2_Name: String { return self._s[485]! }
    public var Username_LinkCopied: String { return self._s[486]! }
    public var IntentsSettings_SuggestedAndSpotlightChatsInfo: String { return self._s[487]! }
    public var TwoStepAuth_ChangePassword: String { return self._s[488]! }
    public var Watch_Suggestion_Thanks: String { return self._s[489]! }
    public var Channel_TitleInfo: String { return self._s[490]! }
    public var ChatList_ChatTypesSection: String { return self._s[491]! }
    public func Watch_LastSeen_AtDate(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[492]!, self._r[492]!, [_0])
    }
    public func Channel_AdminLog_PollStopped(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[493]!, self._r[493]!, [_0])
    }
    public func Channel_AdminLog_MessageRemovedAdminNameUsername(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[494]!, self._r[494]!, [_1, _2])
    }
    public var AuthSessions_AddDevice_InvalidQRCode: String { return self._s[495]! }
    public func Call_MicrophoneOff(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[496]!, self._r[496]!, [_0])
    }
    public var Channel_AdminLogFilter_ChannelEventsInfo: String { return self._s[497]! }
    public var Profile_MessageLifetimeForever: String { return self._s[498]! }
    public var ArchivedChats_IntroText1: String { return self._s[499]! }
    public var Notifications_ChannelNotificationsPreview: String { return self._s[500]! }
    public var Map_PullUpForPlaces: String { return self._s[502]! }
    public var UserInfo_TelegramCall: String { return self._s[503]! }
    public var Conversation_ShareMyContactInfo: String { return self._s[504]! }
    public var ChatList_Tabs_All: String { return self._s[505]! }
    public var Notification_PassportValueEmail: String { return self._s[506]! }
    public var Notification_VideoCallIncoming: String { return self._s[507]! }
    public var SettingsSearch_Synonyms_Appearance_AutoNightTheme: String { return self._s[508]! }
    public var Channel_Username_InvalidTaken: String { return self._s[509]! }
    public var GroupPermission_EditingDisabled: String { return self._s[510]! }
    public var InviteLink_PeopleJoinedShortNone: String { return self._s[511]! }
    public var ChatContextMenu_TextSelectionTip: String { return self._s[512]! }
    public var Passport_Language_pl: String { return self._s[514]! }
    public var Call_Accept: String { return self._s[515]! }
    public var ChatListFolder_NameSectionHeader: String { return self._s[516]! }
    public var InviteLink_ExpiredLinkStatus: String { return self._s[517]! }
    public func Passport_Identity_NativeNameTitle(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[518]!, self._r[518]!, [_0])
    }
    public var ClearCache_Forever: String { return self._s[519]! }
    public var VoiceChat_TapToEditTitle: String { return self._s[521]! }
    public func ChannelInfo_AddParticipantConfirmation(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[522]!, self._r[522]!, [_0])
    }
    public var Group_EditAdmin_RankAdminPlaceholder: String { return self._s[523]! }
    public var Calls_SubmitRating: String { return self._s[524]! }
    public var Location_LiveLocationRequired_ShareLocation: String { return self._s[525]! }
    public func ChatList_AddedToFolderTooltip(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[526]!, self._r[526]!, [_1, _2])
    }
    public var IntentsSettings_MainAccountInfo: String { return self._s[527]! }
    public var Map_Hybrid: String { return self._s[529]! }
    public var ChatList_Context_Archive: String { return self._s[530]! }
    public var Message_PinnedDocumentMessage: String { return self._s[531]! }
    public var State_ConnectingToProxyInfo: String { return self._s[532]! }
    public var Passport_Identity_NativeNameGenericTitle: String { return self._s[534]! }
    public var Settings_AppLanguage: String { return self._s[535]! }
    public func Checkout_SavePasswordTimeoutAndFaceId(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[536]!, self._r[536]!, [_0])
    }
    public var Notifications_PermissionsEnable: String { return self._s[538]! }
    public var CheckoutInfo_ShippingInfoAddress1Placeholder: String { return self._s[539]! }
    public func UserInfo_BlockActionTitle(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[540]!, self._r[540]!, [_0])
    }
    public func AuthSessions_Message(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[541]!, self._r[541]!, [_0])
    }
    public var NotificationsSound_Aurora: String { return self._s[544]! }
    public var ScheduledMessages_ClearAll: String { return self._s[547]! }
    public func CancelResetAccount_TextSMS(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[548]!, self._r[548]!, [_0])
    }
    public var Settings_BlockedUsers: String { return self._s[550]! }
    public var Checkout_TipItem: String { return self._s[551]! }
    public var VoiceOver_Keyboard: String { return self._s[553]! }
    public func UserInfo_StartSecretChatConfirmation(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[554]!, self._r[554]!, [_0])
    }
    public var Passport_Language_hu: String { return self._s[555]! }
    public func Conversation_ScheduleMessage_SendTomorrow(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[556]!, self._r[556]!, [_0])
    }
    public var StickerPack_Share: String { return self._s[557]! }
    public var Checkout_NewCard_SaveInfoEnableHelp: String { return self._s[558]! }
    public func ForwardedAuthors2(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[559]!, self._r[559]!, [_0, _1])
    }
    public var Privacy_ContactsResetConfirmation: String { return self._s[560]! }
    public var VoiceChat_EditTitle: String { return self._s[561]! }
    public var AppleWatch_ReplyPresets: String { return self._s[562]! }
    public var Bot_GenericBotStatus: String { return self._s[563]! }
    public var Appearance_ShareThemeColor: String { return self._s[564]! }
    public var AuthSessions_AddDevice_UrlLoginHint: String { return self._s[566]! }
    public var ReportGroupLocation_Title: String { return self._s[567]! }
    public func Conversation_AutoremoveTimerSetUserYou(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[568]!, self._r[568]!, [_1])
    }
    public func Activity_RemindAboutUser(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[569]!, self._r[569]!, [_0])
    }
    public var Profile_CreateEncryptedChatError: String { return self._s[570]! }
    public var Channel_EditAdmin_TransferOwnership: String { return self._s[571]! }
    public var Wallpaper_ErrorNotFound: String { return self._s[572]! }
    public var Bot_GenericSupportStatus: String { return self._s[573]! }
    public var Activity_UploadingPhoto: String { return self._s[575]! }
    public var Intents_ErrorLockedTitle: String { return self._s[576]! }
    public var Watch_UserInfo_Title: String { return self._s[578]! }
    public var SocksProxySetup_ProxyTelegram: String { return self._s[579]! }
    public var Appearance_ThemeDay: String { return self._s[580]! }
    public func ApplyLanguage_ChangeLanguageOfficialText(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[581]!, self._r[581]!, [_1])
    }
    public func FileSize_B(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[582]!, self._r[582]!, [_0])
    }
    public var InviteLink_AdditionalLinks: String { return self._s[583]! }
    public var Passport_Title: String { return self._s[587]! }
    public func Time_PreciseDate_m3(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[589]!, self._r[589]!, [_1, _2, _3])
    }
    public var CheckoutInfo_ShippingInfoCountryPlaceholder: String { return self._s[590]! }
    public var SocksProxySetup_ShareLink: String { return self._s[593]! }
    public var AuthSessions_OtherDevices: String { return self._s[594]! }
    public var IntentsSettings_SuggestedChatsGroups: String { return self._s[595]! }
    public var Watch_MessageView_Reply: String { return self._s[596]! }
    public var Camera_FlashOn: String { return self._s[598]! }
    public func PUSH_MESSAGE_STICKER(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[599]!, self._r[599]!, [_1, _2])
    }
    public var Conversation_ContextMenuBlock: String { return self._s[600]! }
    public var Channel_EditAdmin_PermissionEditMessages: String { return self._s[602]! }
    public var Privacy_Calls_NeverAllow: String { return self._s[603]! }
    public var BroadcastGroups_Cancel: String { return self._s[604]! }
    public var SharedMedia_CategoryLinks: String { return self._s[605]! }
    public var Conversation_PinMessageAlertGroup: String { return self._s[608]! }
    public var Passport_Identity_ScansHelp: String { return self._s[610]! }
    public var ShareMenu_CopyShareLink: String { return self._s[611]! }
    public var StickerSettings_MaskContextInfo: String { return self._s[612]! }
    public var InviteLink_Create_EditTitle: String { return self._s[613]! }
    public var SocksProxySetup_ProxyStatusChecking: String { return self._s[614]! }
    public var AutoDownloadSettings_AutodownloadPhotos: String { return self._s[617]! }
    public var ChatImportActivity_Success: String { return self._s[619]! }
    public var Checkout_ErrorPrecheckoutFailed: String { return self._s[620]! }
    public var NotificationsSound_Popcorn: String { return self._s[621]! }
    public var FeatureDisabled_Oops: String { return self._s[622]! }
    public func Channel_AdminLog_MessageChangedChannelAbout(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[623]!, self._r[623]!, [_0])
    }
    public var Notification_PinnedMessage: String { return self._s[624]! }
    public var Tour_Title4: String { return self._s[625]! }
    public func Notification_VoiceChatInvitationForYou(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[626]!, self._r[626]!, [_1])
    }
    public var Watch_Suggestion_OK: String { return self._s[627]! }
    public var Compose_TokenListPlaceholder: String { return self._s[628]! }
    public var InviteLink_PermanentLink: String { return self._s[629]! }
    public var EditTheme_Edit_TopInfo: String { return self._s[630]! }
    public var Gif_NoGifsFound: String { return self._s[631]! }
    public var Login_InvalidCountryCode: String { return self._s[632]! }
    public var SettingsSearch_Synonyms_Notifications_ChannelNotificationsExceptions: String { return self._s[633]! }
    public var Call_VoiceOver_VideoCallMissed: String { return self._s[634]! }
    public var VoiceChat_ChangeNameTitle: String { return self._s[636]! }
    public func PUSH_LOCKED_MESSAGE(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[637]!, self._r[637]!, [_1])
    }
    public var Profile_CreateNewContact: String { return self._s[638]! }
    public var AutoDownloadSettings_DataUsageLow: String { return self._s[639]! }
    public var SettingsSearch_Synonyms_Notifications_InAppNotificationsPreview: String { return self._s[640]! }
    public var Group_Setup_TypePublic: String { return self._s[641]! }
    public var Weekday_ShortSaturday: String { return self._s[642]! }
    public func Time_MonthOfYear_m12(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[643]!, self._r[643]!, [_0])
    }
    public var LiveLocation_MenuStopAll: String { return self._s[644]! }
    public func DialogList_EncryptedChatStartedIncoming(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[645]!, self._r[645]!, [_0])
    }
    public var ChatListFolder_NamePlaceholder: String { return self._s[646]! }
    public var Channel_OwnershipTransfer_ErrorPublicChannelsTooMuch: String { return self._s[647]! }
    public func PUSH_CHAT_MESSAGE_GAME(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[648]!, self._r[648]!, [_1, _2, _3])
    }
    public var VoiceChat_ChatFullAlertText: String { return self._s[649]! }
    public var Chat_GenericPsaTooltip: String { return self._s[651]! }
    public var ChannelInfo_CreateVoiceChat: String { return self._s[652]! }
    public func Message_ForwardedMessageShort(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[653]!, self._r[653]!, [_0])
    }
    public var PrivacyLastSeenSettings_AlwaysShareWith_Placeholder: String { return self._s[654]! }
    public var Login_PhoneAndCountryHelp: String { return self._s[655]! }
    public var SaveIncomingPhotosSettings_From: String { return self._s[657]! }
    public var Conversation_JumpToDate: String { return self._s[658]! }
    public var AuthSessions_AddDevice: String { return self._s[659]! }
    public var Settings_FAQ: String { return self._s[661]! }
    public func ChatImport_CreateGroupAlertText(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[662]!, self._r[662]!, [_0])
    }
    public var Username_Title: String { return self._s[663]! }
    public var DialogList_Read: String { return self._s[664]! }
    public var Conversation_InstantPagePreview: String { return self._s[665]! }
    public var Report_Succeed: String { return self._s[667]! }
    public var Login_ResetAccountProtected_Title: String { return self._s[668]! }
    public var CallFeedback_ReasonDistortedSpeech: String { return self._s[669]! }
    public var Channel_EditAdmin_PermissionChangeInfo: String { return self._s[670]! }
    public func Channel_AdminLog_MessageRankUsername(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[671]!, self._r[671]!, [_1, _2, _3])
    }
    public var WallpaperPreview_PreviewBottomText: String { return self._s[673]! }
    public var Privacy_SecretChatsTitle: String { return self._s[676]! }
    public func Notification_PassportValuesSentMessage(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[677]!, self._r[677]!, [_1, _2])
    }
    public var Checkout_NewCard_SaveInfoHelp: String { return self._s[678]! }
    public var Conversation_ClousStorageInfo_Description4: String { return self._s[679]! }
    public var PasscodeSettings_TurnPasscodeOn: String { return self._s[680]! }
    public var Message_ReplyActionButtonShowReceipt: String { return self._s[681]! }
    public func PrivacyPolicy_AgeVerificationMessage(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[682]!, self._r[682]!, [_0])
    }
    public var GroupInfo_DeleteAndExitConfirmation: String { return self._s[684]! }
    public var TwoStepAuth_ConfirmationAbort: String { return self._s[685]! }
    public var PrivacySettings_LastSeenEverybody: String { return self._s[686]! }
    public var CallFeedback_ReasonDropped: String { return self._s[687]! }
    public func ScheduledMessages_ScheduledDate(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[688]!, self._r[688]!, [_0])
    }
    public var WebSearch_Images: String { return self._s[689]! }
    public var Passport_Identity_Surname: String { return self._s[690]! }
    public var Channel_Stickers_CreateYourOwn: String { return self._s[691]! }
    public var TwoFactorSetup_Email_Title: String { return self._s[692]! }
    public var Cache_ClearEmpty: String { return self._s[693]! }
    public var AuthSessions_AddDeviceIntro_Action: String { return self._s[694]! }
    public var Theme_Context_Apply: String { return self._s[695]! }
    public var GroupInfo_Permissions_SearchPlaceholder: String { return self._s[696]! }
    public var CallList_DeleteAllForEveryone: String { return self._s[697]! }
    public func BroadcastGroups_Success(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[698]!, self._r[698]!, [_0])
    }
    public var AutoDownloadSettings_DocumentsTitle: String { return self._s[699]! }
    public func NetworkUsageSettings_CellularUsageSince(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[700]!, self._r[700]!, [_0])
    }
    public var Call_StatusRinging: String { return self._s[701]! }
    public func Map_DistanceAway(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[702]!, self._r[702]!, [_0])
    }
    public func DialogList_SingleTypingSuffix(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[703]!, self._r[703]!, [_0])
    }
    public var Cache_ClearNone: String { return self._s[704]! }
    public var PrivacyPolicy_Accept: String { return self._s[705]! }
    public var Contacts_PhoneNumber: String { return self._s[706]! }
    public var Passport_Identity_OneOfTypePassport: String { return self._s[707]! }
    public var PhotoEditor_HighlightsTint: String { return self._s[709]! }
    public var AutoDownloadSettings_AutodownloadVideos: String { return self._s[710]! }
    public var Checkout_PaymentMethod_Title: String { return self._s[713]! }
    public var Month_GenAugust: String { return self._s[715]! }
    public var DialogList_Draft: String { return self._s[716]! }
    public var ChatList_EmptyChatListFilterText: String { return self._s[717]! }
    public var PeopleNearby_Description: String { return self._s[718]! }
    public var WallpaperPreview_SwipeColorsBottomText: String { return self._s[719]! }
    public var VoiceChat_InviteLink_CopyListenerLink: String { return self._s[720]! }
    public var VoiceChat_EditTitleRemoveSuccess: String { return self._s[721]! }
    public var SettingsSearch_Synonyms_Privacy_Data_TopPeers: String { return self._s[723]! }
    public var Watch_Message_ForwardedFrom: String { return self._s[724]! }
    public var Notification_Mute1h: String { return self._s[725]! }
    public var Appearance_ThemePreview_Chat_3_TextWithLink: String { return self._s[726]! }
    public var SettingsSearch_Synonyms_Privacy_AuthSessions: String { return self._s[728]! }
    public var Channel_Edit_LinkItem: String { return self._s[729]! }
    public var Presence_online: String { return self._s[730]! }
    public var AutoDownloadSettings_Title: String { return self._s[731]! }
    public var Conversation_MessageDialogRetry: String { return self._s[732]! }
    public var SettingsSearch_Synonyms_ChatSettings_OpenLinksIn: String { return self._s[734]! }
    public var Channel_About_Placeholder: String { return self._s[736]! }
    public var Passport_Language_sl: String { return self._s[737]! }
    public var AppleWatch_Title: String { return self._s[739]! }
    public var RepliesChat_DescriptionText: String { return self._s[741]! }
    public var Stats_Message_PrivateShares: String { return self._s[742]! }
    public var Settings_ViewPhoto: String { return self._s[743]! }
    public var Conversation_ForwardTooltip_SavedMessages_One: String { return self._s[744]! }
    public var ChatList_DeleteSavedMessagesConfirmation: String { return self._s[745]! }
    public var Cache_ClearProgress: String { return self._s[746]! }
    public var Cache_Music: String { return self._s[747]! }
    public var Conversation_ContextMenuShare: String { return self._s[749]! }
    public var AutoDownloadSettings_Unlimited: String { return self._s[750]! }
    public var Channel_OwnershipTransfer_ErrorPrivacyRestricted: String { return self._s[751]! }
    public var Contacts_PermissionsAllow: String { return self._s[752]! }
    public var Passport_Language_vi: String { return self._s[754]! }
    public func PUSH_MESSAGE_TEXT(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[757]!, self._r[757]!, [_1, _2])
    }
    public var Passport_Language_de: String { return self._s[758]! }
    public var Notifications_PermissionsText: String { return self._s[760]! }
    public var GroupRemoved_AddToGroup: String { return self._s[761]! }
    public var Appearance_ThemePreview_ChatList_4_Text: String { return self._s[762]! }
    public var ChangePhoneNumberCode_RequestingACall: String { return self._s[763]! }
    public var Login_TermsOfServiceAgree: String { return self._s[764]! }
    public var VoiceOver_Navigation_ProxySettings: String { return self._s[765]! }
    public func PUSH_CHAT_JOINED(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[766]!, self._r[766]!, [_1, _2])
    }
    public var SettingsSearch_Synonyms_Data_CallsUseLessData: String { return self._s[768]! }
    public func PUSH_CHAT_VOICECHAT_START(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[769]!, self._r[769]!, [_1, _2])
    }
    public var ChatListFolder_NameGroups: String { return self._s[770]! }
    public var SocksProxySetup_ProxyDetailsTitle: String { return self._s[771]! }
    public var VoiceChat_EditDescriptionSave: String { return self._s[772]! }
    public func Channel_AdminLog_MessageChangedLinkedGroup(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[773]!, self._r[773]!, [_1, _2])
    }
    public var Watch_Suggestion_TalkLater: String { return self._s[774]! }
    public var Checkout_ShippingOption_Title: String { return self._s[775]! }
    public var Conversation_TitleRepliesEmpty: String { return self._s[776]! }
    public var CreatePoll_TextHeader: String { return self._s[777]! }
    public var VoiceOver_Chat_Message: String { return self._s[779]! }
    public var InfoPlist_NSLocationWhenInUseUsageDescription: String { return self._s[780]! }
    public var ContactInfo_Note: String { return self._s[782]! }
    public var Channel_AdminLog_InfoPanelAlertText: String { return self._s[783]! }
    public var Checkout_NewCard_CardholderNameTitle: String { return self._s[784]! }
    public var AutoDownloadSettings_Photos: String { return self._s[785]! }
    public var UserInfo_NotificationsDefaultDisabled: String { return self._s[786]! }
    public func Conversation_ForwardTooltip_Chat_One(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[787]!, self._r[787]!, [_0])
    }
    public var Channel_Info_Subscribers: String { return self._s[788]! }
    public var ChatList_DeleteForCurrentUser: String { return self._s[789]! }
    public var ChatListFolderSettings_FoldersSection: String { return self._s[790]! }
    public var ChannelInfo_ScheduleVoiceChat: String { return self._s[791]! }
    public var VoiceOver_ChatList_OutgoingMessage: String { return self._s[792]! }
    public func Time_PreciseDate_m9(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[796]!, self._r[796]!, [_1, _2, _3])
    }
    public var AutoNightTheme_System: String { return self._s[797]! }
    public var Call_StatusWaiting: String { return self._s[798]! }
    public var GroupInfo_GroupHistoryHidden: String { return self._s[799]! }
    public func CHAT_MESSAGE_INVOICE(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[800]!, self._r[800]!, [_1, _2, _3])
    }
    public var Conversation_ContextMenuCopy: String { return self._s[802]! }
    public var Notifications_MessageNotificationsPreview: String { return self._s[803]! }
    public var Notifications_InAppNotificationsVibrate: String { return self._s[804]! }
    public func Conversation_RestrictedTextTimed(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[805]!, self._r[805]!, [_0])
    }
    public var Group_Status: String { return self._s[807]! }
    public var Group_Setup_HistoryVisible: String { return self._s[808]! }
    public var Conversation_UploadFileTooLarge: String { return self._s[809]! }
    public var Conversation_DiscardVoiceMessageAction: String { return self._s[810]! }
    public var Paint_Edit: String { return self._s[811]! }
    public var PeerInfo_AutoremoveMessages: String { return self._s[812]! }
    public func ChatImport_SelectionConfirmationGroupWithoutTitle(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[814]!, self._r[814]!, [_0])
    }
    public var Channel_EditAdmin_CannotEdit: String { return self._s[815]! }
    public var Username_InvalidTooShort: String { return self._s[816]! }
    public var ClearCache_StorageOtherApps: String { return self._s[818]! }
    public var Conversation_ViewMessage: String { return self._s[819]! }
    public var GroupInfo_PublicLinkAdd: String { return self._s[821]! }
    public func Notification_RemovedGroupPhoto(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[822]!, self._r[822]!, [_0])
    }
    public var CallSettings_Title: String { return self._s[823]! }
    public func Conversation_BotInteractiveUrlAlert(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[824]!, self._r[824]!, [_0])
    }
    public func VoiceOver_Chat_ContactFrom(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[827]!, self._r[827]!, [_0])
    }
    public var PUSH_SENDER_YOU: String { return self._s[830]! }
    public func Conversation_DeletedFromContacts(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[831]!, self._r[831]!, [_0])
    }
    public var Profile_ShareContactButton: String { return self._s[832]! }
    public var GroupInfo_Permissions_SectionTitle: String { return self._s[833]! }
    public func VoiceOver_Chat_StickerFrom(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[834]!, self._r[834]!, [_0])
    }
    public var Map_ShareLiveLocation: String { return self._s[835]! }
    public var ChatListFolder_TitleEdit: String { return self._s[836]! }
    public func VoiceOver_Chat_AnimatedStickerFrom(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[837]!, self._r[837]!, [_0])
    }
    public var Passport_Address_Address: String { return self._s[839]! }
    public var LastSeen_JustNow: String { return self._s[841]! }
    public func SecretImage_NotViewedYet(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[842]!, self._r[842]!, [_0])
    }
    public var ContactInfo_PhoneLabelOther: String { return self._s[843]! }
    public var PasscodeSettings_DoNotMatch: String { return self._s[844]! }
    public var Weekday_Today: String { return self._s[847]! }
    public var DialogList_Title: String { return self._s[848]! }
    public var SettingsSearch_Synonyms_Notifications_MessageNotificationsPreview: String { return self._s[849]! }
    public var Cache_ClearCache: String { return self._s[850]! }
    public var CreatePoll_ExplanationInfo: String { return self._s[851]! }
    public var Notifications_ResetAllNotificationsHelp: String { return self._s[853]! }
    public var Stats_MessageTitle: String { return self._s[854]! }
    public var Passport_Address_Street: String { return self._s[856]! }
    public func Channel_AdminLog_MessageRemovedGroupUsername(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[857]!, self._r[857]!, [_0])
    }
    public var Channel_AdminLog_ChannelEmptyText: String { return self._s[858]! }
    public func Login_PhoneGenericEmailSubject(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[859]!, self._r[859]!, [_0])
    }
    public var TwoStepAuth_Email: String { return self._s[861]! }
    public var Conversation_SecretLinkPreviewAlert: String { return self._s[862]! }
    public var PrivacySettings_PasscodeOn: String { return self._s[863]! }
    public var Camera_SquareMode: String { return self._s[865]! }
    public var SocksProxySetup_Port: String { return self._s[866]! }
    public var Watch_LastSeen_JustNow: String { return self._s[868]! }
    public func Location_ProximityAlertSetText(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[869]!, self._r[869]!, [_1, _2])
    }
    public func PUSH_MESSAGE_GAME(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[870]!, self._r[870]!, [_1, _2])
    }
    public func Watch_LastSeen_YesterdayAt(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[871]!, self._r[871]!, [_0])
    }
    public var VoiceChat_CancelVoiceChat: String { return self._s[872]! }
    public var EditTheme_Expand_Preview_OutgoingText: String { return self._s[873]! }
    public var Channel_AdminLogFilter_EventsTitle: String { return self._s[874]! }
    public var Watch_Suggestion_HoldOn: String { return self._s[877]! }
    public func PUSH_CHANNEL_MESSAGE_GEOLIVE(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[878]!, self._r[878]!, [_1])
    }
    public var CallSettings_TabIcon: String { return self._s[879]! }
    public var ScheduledMessages_SendNow: String { return self._s[880]! }
    public var Stats_GroupTopWeekdaysTitle: String { return self._s[881]! }
    public var UserInfo_PhoneCall: String { return self._s[882]! }
    public var Month_GenMarch: String { return self._s[883]! }
    public var Camera_Discard: String { return self._s[884]! }
    public var InfoPlist_NSFaceIDUsageDescription: String { return self._s[885]! }
    public var Passport_RequestedInformation: String { return self._s[886]! }
    public var VoiceChat_RecordingTitlePlaceholder: String { return self._s[888]! }
    public func Notification_ProximityYouReached(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[889]!, self._r[889]!, [_1, _2])
    }
    public var Passport_Language_ro: String { return self._s[890]! }
    public func PUSH_CHAT_MESSAGE_DOC(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[891]!, self._r[891]!, [_1, _2])
    }
    public var AutoDownloadSettings_ResetHelp: String { return self._s[892]! }
    public var Passport_Identity_DocumentDetails: String { return self._s[894]! }
    public var Passport_Address_ScansHelp: String { return self._s[895]! }
    public var Location_LiveLocationRequired_Title: String { return self._s[896]! }
    public var ClearCache_StorageCache: String { return self._s[897]! }
    public var Theme_Colors_ColorWallpaperWarningProceed: String { return self._s[898]! }
    public var Conversation_RestrictedText: String { return self._s[899]! }
    public var Notifications_MessageNotifications: String { return self._s[901]! }
    public var Passport_Scans: String { return self._s[902]! }
    public func VoiceChat_StatusStartsIn(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[904]!, self._r[904]!, [_0])
    }
    public var TwoStepAuth_SetupHintTitle: String { return self._s[905]! }
    public var LogoutOptions_ContactSupportTitle: String { return self._s[906]! }
    public var Passport_Identity_SelfieHelp: String { return self._s[907]! }
    public var Permissions_NotificationsUnreachableText_v0: String { return self._s[908]! }
    public var Privacy_PaymentsClear_PaymentInfo: String { return self._s[909]! }
    public var ShareMenu_CopyShareLinkGame: String { return self._s[910]! }
    public var PeerInfo_ButtonSearch: String { return self._s[911]! }
    public func Notification_ProximityReachedYou(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[914]!, self._r[914]!, [_1, _2])
    }
    public var SettingsSearch_Synonyms_Privacy_Data_ClearPaymentsInfo: String { return self._s[915]! }
    public var Passport_FieldIdentityTranslationHelp: String { return self._s[917]! }
    public var Conversation_InputTextSilentBroadcastPlaceholder: String { return self._s[918]! }
    public var Month_GenSeptember: String { return self._s[919]! }
    public func Call_GroupFormat(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[921]!, self._r[921]!, [_1, _2])
    }
    public var StickerPacksSettings_ArchivedPacks: String { return self._s[922]! }
    public func Notification_VoiceChatInvitation(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[924]!, self._r[924]!, [_1, _2])
    }
    public func Channel_Username_LinkHint(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[925]!, self._r[925]!, [_0])
    }
    public func PUSH_PINNED_CONTACT(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[927]!, self._r[927]!, [_1, _2])
    }
    public func PUSH_MESSAGE_VIDEOS(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[928]!, self._r[928]!, [_1, _2])
    }
    public var Calls_NotNow: String { return self._s[930]! }
    public var Settings_ChatFolders: String { return self._s[935]! }
    public var Login_PadPhoneHelpTitle: String { return self._s[936]! }
    public var TwoStepAuth_EnterPasswordInvalid: String { return self._s[937]! }
    public var Widget_MessageAutoremoveTimerRemoved: String { return self._s[938]! }
    public var VoiceChat_RecordingSaved: String { return self._s[939]! }
    public var Settings_ChatBackground: String { return self._s[940]! }
    public func PUSH_CHAT_MESSAGE_CONTACT(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[942]!, self._r[942]!, [_1, _2])
    }
    public var ProxyServer_VoiceOver_Active: String { return self._s[943]! }
    public var Call_StatusBusy: String { return self._s[944]! }
    public var Conversation_MessageDeliveryFailed: String { return self._s[945]! }
    public var Login_NetworkError: String { return self._s[947]! }
    public var TwoStepAuth_SetupPasswordDescription: String { return self._s[948]! }
    public var Privacy_Calls_Integration: String { return self._s[949]! }
    public var DialogList_SearchSectionMessages: String { return self._s[950]! }
    public var AutoDownloadSettings_VideosTitle: String { return self._s[951]! }
    public var Preview_DeletePhoto: String { return self._s[952]! }
    public var VoiceChat_Video: String { return self._s[953]! }
    public var PrivacySettings_PhoneNumber: String { return self._s[955]! }
    public var Forward_ErrorDisabledForChat: String { return self._s[956]! }
    public var Watch_Compose_CurrentLocation: String { return self._s[957]! }
    public var Settings_CallSettings: String { return self._s[958]! }
    public var AutoDownloadSettings_TypePrivateChats: String { return self._s[959]! }
    public var Conversation_StickerRemovedFromFavorites: String { return self._s[960]! }
    public var ChatList_Context_MarkAllAsRead: String { return self._s[961]! }
    public var ChatSettings_AutoPlayAnimations: String { return self._s[962]! }
    public var SaveIncomingPhotosSettings_Title: String { return self._s[963]! }
    public var OwnershipTransfer_SecurityRequirements: String { return self._s[964]! }
    public var Map_LiveLocationFor1Hour: String { return self._s[965]! }
    public func Privacy_GroupsAndChannels_InviteToGroupError(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[966]!, self._r[966]!, [_0, _1])
    }
    public var VoiceChat_MutedByAdmin: String { return self._s[967]! }
    public func Notification_PinnedLiveLocationMessage(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[968]!, self._r[968]!, [_0])
    }
    public var Conversation_UnvotePoll: String { return self._s[969]! }
    public var TwoStepAuth_EnterEmailCode: String { return self._s[970]! }
    public func LOCAL_MESSAGE_FWDS(_ _1: String, _ _2: Int) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[971]!, self._r[971]!, [_1, "\(_2)"])
    }
    public var Passport_InfoTitle: String { return self._s[972]! }
    public func Conversation_Bytes(_ _0: Int) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[973]!, self._r[973]!, ["\(_0)"])
    }
    public var AccentColor_Title: String { return self._s[974]! }
    public func PUSH_MESSAGE_INVOICE(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[975]!, self._r[975]!, [_1, _2])
    }
    public func Notification_JoinedChannel(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[978]!, self._r[978]!, [_0])
    }
    public var AutoDownloadSettings_DataUsageCustom: String { return self._s[979]! }
    public var Conversation_ShareBotLocationConfirmation: String { return self._s[980]! }
    public var PrivacyPhoneNumberSettings_WhoCanSeeMyPhoneNumber: String { return self._s[981]! }
    public var VoiceOver_Editing_ClearText: String { return self._s[982]! }
    public var Conversation_Unarchive: String { return self._s[983]! }
    public var Notification_CallOutgoing: String { return self._s[984]! }
    public var Channel_Setup_PublicNoLink: String { return self._s[985]! }
    public var Passport_Identity_GenderPlaceholder: String { return self._s[986]! }
    public var Message_Animation: String { return self._s[987]! }
    public var SettingsSearch_Synonyms_Appearance_Animations: String { return self._s[988]! }
    public var ChatSettings_ConnectionType_Title: String { return self._s[989]! }
    public func Watch_Time_ShortFullAt(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[990]!, self._r[990]!, [_1, _2])
    }
    public func VoiceChat_StatusSpeakingVolume(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[991]!, self._r[991]!, [_0])
    }
    public var Notification_CallBack: String { return self._s[992]! }
    public var Appearance_Title: String { return self._s[995]! }
    public var NotificationsSound_Glass: String { return self._s[997]! }
    public var AutoDownloadSettings_CellularTitle: String { return self._s[999]! }
    public var Notifications_PermissionsSuppressWarningTitle: String { return self._s[1001]! }
    public var ChatSearch_SearchPlaceholder: String { return self._s[1002]! }
    public var Passport_Identity_AddPassport: String { return self._s[1003]! }
    public var GroupPermission_NoAddMembers: String { return self._s[1005]! }
    public var ContactList_Context_SendMessage: String { return self._s[1006]! }
    public var PhotoEditor_GrainTool: String { return self._s[1007]! }
    public var Settings_CopyPhoneNumber: String { return self._s[1008]! }
    public var Passport_Address_City: String { return self._s[1009]! }
    public var VoiceChat_LeaveAndCancelVoiceChat: String { return self._s[1010]! }
    public var ChannelRemoved_RemoveInfo: String { return self._s[1011]! }
    public var SocksProxySetup_Password: String { return self._s[1013]! }
    public var Settings_Passport: String { return self._s[1014]! }
    public var Channel_MessagePhotoUpdated: String { return self._s[1016]! }
    public var Stats_LanguagesTitle: String { return self._s[1017]! }
    public var ChatList_PeerTypeGroup: String { return self._s[1018]! }
    public var Privacy_Calls_P2PHelp: String { return self._s[1019]! }
    public var VoiceOver_Chat_PollNoVotes: String { return self._s[1020]! }
    public var Embed_PlayingInPIP: String { return self._s[1021]! }
    public var BlockedUsers_BlockUser: String { return self._s[1024]! }
    public var Login_CancelPhoneVerificationContinue: String { return self._s[1025]! }
    public func PUSH_CHANNEL_MESSAGE(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1026]!, self._r[1026]!, [_1])
    }
    public var AuthSessions_LoggedIn: String { return self._s[1027]! }
    public var Channel_AdminLog_MessagePreviousCaption: String { return self._s[1028]! }
    public var Activity_UploadingDocument: String { return self._s[1029]! }
    public var PeopleNearby_NoMembers: String { return self._s[1030]! }
    public var SettingsSearch_Synonyms_Stickers_Masks: String { return self._s[1033]! }
    public var ChatSettings_AutoPlayVideos: String { return self._s[1034]! }
    public var VoiceOver_Chat_OpenLinkHint: String { return self._s[1035]! }
    public var InstantPage_VoiceOver_IncreaseFontSize: String { return self._s[1036]! }
    public var Settings_ViewVideo: String { return self._s[1037]! }
    public var Map_ShowPlaces: String { return self._s[1039]! }
    public var Passport_Phone_UseTelegramNumberHelp: String { return self._s[1040]! }
    public var InviteLink_Create_Title: String { return self._s[1041]! }
    public var Notification_CreatedGroup: String { return self._s[1042]! }
    public var SettingsSearch_Synonyms_Appearance_ChatBackground_Custom: String { return self._s[1043]! }
    public func PrivacySettings_LastSeenContactsPlus(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1044]!, self._r[1044]!, [_0])
    }
    public var Conversation_StatusLeftGroup: String { return self._s[1045]! }
    public var Theme_Colors_Messages: String { return self._s[1046]! }
    public var AuthSessions_EmptyText: String { return self._s[1047]! }
    public func PUSH_MESSAGE_CONTACT(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1048]!, self._r[1048]!, [_1])
    }
    public var UserInfo_StartSecretChat: String { return self._s[1049]! }
    public var ChatListFolderSettings_EditFoldersInfo: String { return self._s[1050]! }
    public var Channel_Edit_PrivatePublicLinkAlert: String { return self._s[1051]! }
    public var Conversation_ReportSpamGroupConfirmation: String { return self._s[1052]! }
    public var Conversation_PrivateMessageLinkCopied: String { return self._s[1054]! }
    public var PeerInfo_PaneFiles: String { return self._s[1055]! }
    public var VoiceChat_DisplayAs: String { return self._s[1056]! }
    public var PrivacySettings_AutoArchive: String { return self._s[1057]! }
    public var Camera_VideoMode: String { return self._s[1058]! }
    public var NotificationsSound_Alert: String { return self._s[1059]! }
    public var Privacy_Forwards_NeverAllow_Title: String { return self._s[1060]! }
    public var Appearance_AutoNightTheme: String { return self._s[1061]! }
    public var Passport_Language_he: String { return self._s[1062]! }
    public var Passport_InvalidPasswordError: String { return self._s[1063]! }
    public var Conversation_PinMessageAlert_OnlyPin: String { return self._s[1064]! }
    public var UserInfo_InviteBotToGroup: String { return self._s[1065]! }
    public var Conversation_SilentBroadcastTooltipOff: String { return self._s[1066]! }
    public var Common_TakePhoto: String { return self._s[1067]! }
    public func Channel_AdminLog_RevokedInviteLink(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1068]!, self._r[1068]!, [_1, _2])
    }
    public var Passport_Email_UseTelegramEmailHelp: String { return self._s[1069]! }
    public var ChatList_Context_JoinChannel: String { return self._s[1070]! }
    public var MediaPlayer_UnknownArtist: String { return self._s[1071]! }
    public var VoiceChat_EditDescriptionText: String { return self._s[1072]! }
    public var KeyCommand_JumpToPreviousUnreadChat: String { return self._s[1075]! }
    public var Channel_OwnershipTransfer_Title: String { return self._s[1076]! }
    public var EditTheme_UploadEditedTheme: String { return self._s[1077]! }
    public var Settings_SetProfilePhotoOrVideo: String { return self._s[1079]! }
    public var Passport_FieldOneOf_Delimeter: String { return self._s[1080]! }
    public var MessagePoll_ViewResults: String { return self._s[1081]! }
    public var Group_Setup_TypePrivateHelp: String { return self._s[1082]! }
    public func UserInfo_ContactForwardTooltip_Chat_One(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1083]!, self._r[1083]!, [_0])
    }
    public var Passport_Address_OneOfTypeUtilityBill: String { return self._s[1084]! }
    public var ChatList_Search_ShowLess: String { return self._s[1085]! }
    public var InviteLink_Create_UsersLimitNoLimit: String { return self._s[1086]! }
    public var UserInfo_ShareBot: String { return self._s[1087]! }
    public var Privacy_Calls_P2P: String { return self._s[1089]! }
    public var WebBrowser_InAppSafari: String { return self._s[1090]! }
    public var SharedMedia_EmptyFilesText: String { return self._s[1093]! }
    public var Channel_AdminLog_MessagePreviousMessage: String { return self._s[1094]! }
    public var GroupInfo_SetSound: String { return self._s[1095]! }
    public var Permissions_PeopleNearbyAllowInSettings_v0: String { return self._s[1096]! }
    public func Conversation_AutoremoveRemainingTime(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1097]!, self._r[1097]!, [_0])
    }
    public var Channel_AdminLog_MessagePreviousDescription: String { return self._s[1098]! }
    public var Channel_AdminLogFilter_EventsAll: String { return self._s[1099]! }
    public var CallSettings_UseLessData: String { return self._s[1100]! }
    public var InfoPlist_NSCameraUsageDescription: String { return self._s[1101]! }
    public var NotificationsSound_Chord: String { return self._s[1102]! }
    public var PhotoEditor_CurvesTool: String { return self._s[1103]! }
    public var Appearance_ThemePreview_Chat_2_Text: String { return self._s[1104]! }
    public var Resolve_ErrorNotFound: String { return self._s[1105]! }
    public var Activity_PlayingGame: String { return self._s[1106]! }
    public func VoiceChat_InvitedPeerText(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1110]!, self._r[1110]!, [_0])
    }
    public var StickerPacksSettings_AnimatedStickersInfo: String { return self._s[1111]! }
    public func PUSH_CHANNEL_MESSAGE_GEO(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1112]!, self._r[1112]!, [_1])
    }
    public var Conversation_ShareBotContactConfirmationTitle: String { return self._s[1113]! }
    public var Notification_CallIncoming: String { return self._s[1114]! }
    public var Stats_EnabledNotifications: String { return self._s[1115]! }
    public var Notification_VoiceChatStartedChannel: String { return self._s[1116]! }
    public var Notifications_PermissionsOpenSettings: String { return self._s[1117]! }
    public var Checkout_ErrorProviderAccountTimeout: String { return self._s[1118]! }
    public func Activity_RemindAboutChannel(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1119]!, self._r[1119]!, [_0])
    }
    public var VoiceChat_StatusMutedYou: String { return self._s[1120]! }
    public var VoiceOver_Chat_ReplyToYourMessage: String { return self._s[1121]! }
    public var Channel_DiscussionGroup_MakeHistoryPublic: String { return self._s[1122]! }
    public var StickerPacksSettings_Title: String { return self._s[1123]! }
    public func Channel_AdminLog_MessageGroupPreHistoryVisible(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1124]!, self._r[1124]!, [_0])
    }
    public var Watch_NoConnection: String { return self._s[1125]! }
    public var EncryptionKey_Title: String { return self._s[1126]! }
    public var Widget_AuthRequired: String { return self._s[1127]! }
    public func PUSH_MESSAGE_ROUND(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1128]!, self._r[1128]!, [_1])
    }
    public var Notifications_ExceptionsTitle: String { return self._s[1129]! }
    public var EditTheme_Expand_TopInfo: String { return self._s[1130]! }
    public func Contacts_AddPhoneNumber(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1131]!, self._r[1131]!, [_0])
    }
    public var Channel_AdminLogFilter_EventsRestrictions: String { return self._s[1133]! }
    public var Notifications_GroupNotificationsSound: String { return self._s[1134]! }
    public var VoiceChat_SpeakPermissionAdmin: String { return self._s[1135]! }
    public var Passport_Email_EnterOtherEmail: String { return self._s[1136]! }
    public func VoiceChat_RemovePeerConfirmation(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1139]!, self._r[1139]!, [_0])
    }
    public var Conversation_AddToContacts: String { return self._s[1140]! }
    public var AutoDownloadSettings_DataUsageMedium: String { return self._s[1141]! }
    public var AuthSessions_LogOutApplications: String { return self._s[1143]! }
    public var VoiceChat_LeaveVoiceChat: String { return self._s[1144]! }
    public var ChatList_Context_Unpin: String { return self._s[1145]! }
    public var PeopleNearby_DiscoverDescription: String { return self._s[1146]! }
    public var UserInfo_FakeBotWarning: String { return self._s[1147]! }
    public var Notification_MessageLifetime1d: String { return self._s[1148]! }
    public var PrivacyLastSeenSettings_NeverShareWith_Title: String { return self._s[1149]! }
    public var ChatListFolder_CategoryChannels: String { return self._s[1150]! }
    public var VoiceOver_Chat_SeenByRecipient: String { return self._s[1151]! }
    public var Notifications_PermissionsAllow: String { return self._s[1152]! }
    public var Undo_ScheduledMessagesCleared: String { return self._s[1153]! }
    public var AutoDownloadSettings_PrivateChats: String { return self._s[1155]! }
    public var VoiceChat_ImproveYourProfileText: String { return self._s[1156]! }
    public var ApplyLanguage_ChangeLanguageAction: String { return self._s[1157]! }
    public var ChatImportActivity_ErrorInvalidChatType: String { return self._s[1158]! }
    public func Conversation_ScheduledVoiceChatStartsToday(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1159]!, self._r[1159]!, [_0])
    }
    public func PrivacySettings_LastSeenNobodyPlus(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1160]!, self._r[1160]!, [_0])
    }
    public var Conversation_AutoremoveTimerRemovedChannel: String { return self._s[1162]! }
    public var Notifications_MessageNotificationsHelp: String { return self._s[1164]! }
    public var WallpaperSearch_ColorPink: String { return self._s[1165]! }
    public var ContactInfo_PhoneNumberHidden: String { return self._s[1166]! }
    public var Passport_Identity_IssueDate: String { return self._s[1168]! }
    public func PUSH_CHAT_MESSAGE_GIF(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1169]!, self._r[1169]!, [_1, _2])
    }
    public var ChatList_DeleteForAllSubscribersConfirmationText: String { return self._s[1170]! }
    public var Channel_Info_Description: String { return self._s[1171]! }
    public var PrivacySettings_DeleteAccountIfAwayFor: String { return self._s[1172]! }
    public var Weekday_ShortTuesday: String { return self._s[1173]! }
    public var Common_Back: String { return self._s[1174]! }
    public var Chat_PinnedMessagesHiddenTitle: String { return self._s[1176]! }
    public var ChatListFolder_AddChats: String { return self._s[1177]! }
    public var Common_Close: String { return self._s[1179]! }
    public var Map_OpenIn: String { return self._s[1180]! }
    public var Group_Setup_HistoryTitle: String { return self._s[1181]! }
    public var SettingsSearch_Synonyms_Data_AutoDownloadUsingWifi: String { return self._s[1182]! }
    public var Notification_MessageLifetime1h: String { return self._s[1183]! }
    public func CancelResetAccount_Success(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1184]!, self._r[1184]!, [_0])
    }
    public var Watch_Contacts_NoResults: String { return self._s[1186]! }
    public var TwoStepAuth_SetupResendEmailCode: String { return self._s[1187]! }
    public var Checkout_Phone: String { return self._s[1188]! }
    public var OwnershipTransfer_ComeBackLater: String { return self._s[1189]! }
    public func Channel_CommentsGroup_HeaderGroupSet(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1190]!, self._r[1190]!, [_0])
    }
    public func DialogList_MultipleTypingSuffix(_ _0: Int) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1191]!, self._r[1191]!, ["\(_0)"])
    }
    public var Conversation_AudioRateTooltipSpeedUp: String { return self._s[1192]! }
    public var ChatAdmins_Title: String { return self._s[1193]! }
    public var Appearance_ThemePreview_Chat_7_Text: String { return self._s[1194]! }
    public func PUSH_CHANNEL_MESSAGE_POLL(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1195]!, self._r[1195]!, [_1])
    }
    public var Common_Done: String { return self._s[1196]! }
    public var ChatList_HeaderImportIntoAnExistingGroup: String { return self._s[1197]! }
    public var Appearance_ThemeCarouselNight: String { return self._s[1200]! }
    public func PUSH_PINNED_VIDEO(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1202]!, self._r[1202]!, [_1])
    }
    public var InviteLink_Expired: String { return self._s[1204]! }
    public var Preview_OpenInInstagram: String { return self._s[1205]! }
    public var Wallpaper_SetColor: String { return self._s[1210]! }
    public var VoiceOver_Media_PlaybackRate: String { return self._s[1211]! }
    public var ChatSettings_Groups: String { return self._s[1212]! }
    public func VoiceOver_Chat_VoiceMessageFrom(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1213]!, self._r[1213]!, [_0])
    }
    public var Contacts_SortedByName: String { return self._s[1214]! }
    public var SettingsSearch_Synonyms_Notifications_ContactJoined: String { return self._s[1215]! }
    public var Channel_Management_LabelCreator: String { return self._s[1216]! }
    public var Contacts_PermissionsSuppressWarningTitle: String { return self._s[1217]! }
    public func PrivacySettings_LastSeenContactsMinusPlus(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1218]!, self._r[1218]!, [_0, _1])
    }
    public var Group_GroupMembersHeader: String { return self._s[1219]! }
    public var Group_PublicLink_Title: String { return self._s[1220]! }
    public var Channel_OwnershipTransfer_ErrorAdminsTooMuch: String { return self._s[1221]! }
    public var VoiceOver_Chat_Photo: String { return self._s[1222]! }
    public var TwoFactorSetup_EmailVerification_Placeholder: String { return self._s[1223]! }
    public var IntentsSettings_SuggestBy: String { return self._s[1224]! }
    public var Privacy_Calls_AlwaysAllow_Placeholder: String { return self._s[1225]! }
    public var Appearance_ThemePreview_ChatList_1_Name: String { return self._s[1226]! }
    public var PhoneNumberHelp_ChangeNumber: String { return self._s[1227]! }
    public var LogoutOptions_SetPasscodeText: String { return self._s[1228]! }
    public var Map_OpenInMaps: String { return self._s[1229]! }
    public var ContactInfo_PhoneLabelWorkFax: String { return self._s[1230]! }
    public var BlockedUsers_Unblock: String { return self._s[1231]! }
    public func Settings_ApplyProxyAlert(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1232]!, self._r[1232]!, [_1, _2])
    }
    public func Channel_AdminLog_MessageRestrictedNameUsername(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1233]!, self._r[1233]!, [_1, _2])
    }
    public var ChatImport_CreateGroupAlertTitle: String { return self._s[1235]! }
    public var Conversation_Block: String { return self._s[1236]! }
    public var VoiceChat_PersonalAccount: String { return self._s[1237]! }
    public var Passport_Scans_UploadNew: String { return self._s[1238]! }
    public var Share_Title: String { return self._s[1239]! }
    public var Conversation_ApplyLocalization: String { return self._s[1240]! }
    public var SharedMedia_EmptyLinksText: String { return self._s[1241]! }
    public var Settings_NotificationsAndSounds: String { return self._s[1242]! }
    public var Stats_ViewsByHoursTitle: String { return self._s[1243]! }
    public var PhotoEditor_QualityMedium: String { return self._s[1244]! }
    public var Conversation_ContextMenuCancelSending: String { return self._s[1245]! }
    public func PUSH_CHANNEL_MESSAGE_GAME(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1246]!, self._r[1246]!, [_1, _2])
    }
    public var Conversation_RestrictedInline: String { return self._s[1247]! }
    public var Passport_Language_tr: String { return self._s[1248]! }
    public var Call_Mute: String { return self._s[1249]! }
    public func Conversation_NoticeInvitedByInGroup(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1250]!, self._r[1250]!, [_0])
    }
    public var Passport_Language_bn: String { return self._s[1251]! }
    public var Common_Save: String { return self._s[1253]! }
    public var AccessDenied_LocationTracking: String { return self._s[1255]! }
    public var Month_ShortOctober: String { return self._s[1256]! }
    public var AutoDownloadSettings_WiFi: String { return self._s[1257]! }
    public var ProfilePhoto_SetMainPhoto: String { return self._s[1259]! }
    public var ChangePhoneNumberNumber_NewNumber: String { return self._s[1260]! }
    public func Time_MonthOfYear_m3(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1261]!, self._r[1261]!, [_0])
    }
    public var Watch_ChannelInfo_Title: String { return self._s[1262]! }
    public var State_Updating: String { return self._s[1263]! }
    public var Conversation_UnblockUser: String { return self._s[1264]! }
    public var Notifications_ChannelNotificationsSound: String { return self._s[1265]! }
    public var Map_GetDirections: String { return self._s[1266]! }
    public var Watch_Compose_AddContact: String { return self._s[1268]! }
    public var Conversation_Dice_u26BD: String { return self._s[1269]! }
    public var AccessDenied_PhotosRestricted: String { return self._s[1270]! }
    public func Channel_AdminLog_MessageRank(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1271]!, self._r[1271]!, [_1])
    }
    public var Map_LoadError: String { return self._s[1273]! }
    public var SettingsSearch_Synonyms_Privacy_Calls: String { return self._s[1274]! }
    public var PhotoEditor_CropAuto: String { return self._s[1275]! }
    public func Target_ShareGameConfirmationPrivate(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1278]!, self._r[1278]!, [_0])
    }
    public var Username_TooManyPublicUsernamesError: String { return self._s[1280]! }
    public func PUSH_PINNED_GAME(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1281]!, self._r[1281]!, [_1])
    }
    public var Settings_PhoneNumber: String { return self._s[1282]! }
    public func Channel_AdminLog_MessageTransferedName(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1283]!, self._r[1283]!, [_1])
    }
    public var Month_GenJune: String { return self._s[1285]! }
    public var Notifications_ExceptionsGroupPlaceholder: String { return self._s[1286]! }
    public var ChatListFolder_CategoryRead: String { return self._s[1287]! }
    public var LoginPassword_ResetAccount: String { return self._s[1288]! }
    public func DialogList_SingleUploadingFileSuffix(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1289]!, self._r[1289]!, [_0])
    }
    public var Call_CameraConfirmationConfirm: String { return self._s[1290]! }
    public var Notification_RenamedChannel: String { return self._s[1291]! }
    public func Channel_AdminLog_MessageUnpinned(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1292]!, self._r[1292]!, [_0])
    }
    public var Channel_AdminLogFilter_EventsAdmins: String { return self._s[1293]! }
    public var IntentsSettings_Title: String { return self._s[1295]! }
    public var CallList_DeleteAllForMe: String { return self._s[1296]! }
    public var Settings_AppleWatch: String { return self._s[1297]! }
    public var Conversation_LinkCopied: String { return self._s[1298]! }
    public var DialogList_NoMessagesText: String { return self._s[1299]! }
    public func VoiceChat_SendPublicLinkText(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1300]!, self._r[1300]!, [_1, _2])
    }
    public var GroupPermission_NoChangeInfo: String { return self._s[1301]! }
    public var Channel_ErrorAccessDenied: String { return self._s[1303]! }
    public var ScheduledMessages_EmptyPlaceholder: String { return self._s[1304]! }
    public func Message_StickerText(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1305]!, self._r[1305]!, [_0])
    }
    public var AuthSessions_TerminateOtherSessionsHelp: String { return self._s[1306]! }
    public var StickerPacksSettings_AnimatedStickers: String { return self._s[1307]! }
    public var Month_ShortJanuary: String { return self._s[1308]! }
    public var Conversation_UnreadMessages: String { return self._s[1309]! }
    public var Conversation_PrivateChannelTooltip: String { return self._s[1311]! }
    public var Call_VoiceOver_VideoCallCanceled: String { return self._s[1312]! }
    public var PrivacySettings_DeleteAccountTitle: String { return self._s[1314]! }
    public var Channel_Members_AddBannedErrorAdmin: String { return self._s[1315]! }
    public func Conversation_ShareMyPhoneNumberConfirmation(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1319]!, self._r[1319]!, [_1, _2])
    }
    public var Widget_ApplicationLocked: String { return self._s[1320]! }
    public func TextFormat_AddLinkText(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1321]!, self._r[1321]!, [_0])
    }
    public var Common_TakePhotoOrVideo: String { return self._s[1322]! }
    public var Passport_Language_ru: String { return self._s[1324]! }
    public var MediaPicker_VideoMuteDescription: String { return self._s[1325]! }
    public var EditTheme_ErrorLinkTaken: String { return self._s[1326]! }
    public func Group_EditAdmin_RankInfo(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1328]!, self._r[1328]!, [_0])
    }
    public var VoiceChat_ShareShort: String { return self._s[1329]! }
    public var Channel_Members_AddAdminErrorBlacklisted: String { return self._s[1330]! }
    public var Conversation_Owner: String { return self._s[1332]! }
    public var Settings_FAQ_Intro: String { return self._s[1333]! }
    public var PhotoEditor_QualityLow: String { return self._s[1335]! }
    public var Widget_GalleryTitle: String { return self._s[1336]! }
    public var Call_End: String { return self._s[1337]! }
    public var StickerPacksSettings_FeaturedPacks: String { return self._s[1339]! }
    public var Privacy_ContactsSyncHelp: String { return self._s[1340]! }
    public var OldChannels_NoticeUpgradeText: String { return self._s[1344]! }
    public var Conversation_Call: String { return self._s[1346]! }
    public var Watch_MessageView_Title: String { return self._s[1347]! }
    public func Notification_RenamedChat(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1348]!, self._r[1348]!, [_0])
    }
    public var Passport_PasswordCompleteSetup: String { return self._s[1349]! }
    public func Notification_ChangedGroupVideo(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1350]!, self._r[1350]!, [_0])
    }
    public func TwoFactorSetup_EmailVerification_Text(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1352]!, self._r[1352]!, [_0])
    }
    public var Map_Location: String { return self._s[1353]! }
    public var Watch_MessageView_ViewOnPhone: String { return self._s[1354]! }
    public var Login_CountryCode: String { return self._s[1355]! }
    public var Channel_DiscussionGroup_PrivateGroup: String { return self._s[1357]! }
    public var ChatState_ConnectingToProxy: String { return self._s[1358]! }
    public var Login_CallRequestState3: String { return self._s[1359]! }
    public var NetworkUsageSettings_MediaAudioDataSection: String { return self._s[1362]! }
    public var SocksProxySetup_ProxyStatusConnecting: String { return self._s[1363]! }
    public var Widget_ChatsGalleryDescription: String { return self._s[1365]! }
    public var PrivacyLastSeenSettings_NeverShareWith_Placeholder: String { return self._s[1367]! }
    public var InstantPage_FontSanFrancisco: String { return self._s[1368]! }
    public var Call_StatusEnded: String { return self._s[1369]! }
    public func Checkout_SuccessfulTooltip(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1372]!, self._r[1372]!, [_1, _2])
    }
    public var MusicPlayer_VoiceNote: String { return self._s[1373]! }
    public var ChatImportActivity_ErrorUserBlocked: String { return self._s[1374]! }
    public func PUSH_CHANNEL_MESSAGE_TEXT(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1375]!, self._r[1375]!, [_1, _2])
    }
    public var VoiceOver_MessageContextShare: String { return self._s[1376]! }
    public var ProfilePhoto_SearchWeb: String { return self._s[1377]! }
    public var EditProfile_Title: String { return self._s[1378]! }
    public func Notification_PinnedQuizMessage(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1379]!, self._r[1379]!, [_0])
    }
    public var VoiceChat_Unmute: String { return self._s[1380]! }
    public var ChangePhoneNumberCode_CodePlaceholder: String { return self._s[1381]! }
    public var NetworkUsageSettings_ResetStats: String { return self._s[1383]! }
    public var NetworkUsageSettings_GeneralDataSection: String { return self._s[1384]! }
    public var StickerPackActionInfo_AddedTitle: String { return self._s[1385]! }
    public var Channel_BanUser_PermissionSendStickersAndGifs: String { return self._s[1386]! }
    public func Call_ParticipantVideoVersionOutdatedError(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1387]!, self._r[1387]!, [_0])
    }
    public var Location_ProximityNotification_Title: String { return self._s[1388]! }
    public var AuthSessions_AddDeviceIntro_Text1: String { return self._s[1389]! }
    public var Passport_Identity_LatinNameHelp: String { return self._s[1392]! }
    public var AuthSessions_AddDeviceIntro_Text2: String { return self._s[1393]! }
    public var Stats_GroupMembersTitle: String { return self._s[1394]! }
    public var AuthSessions_AddDeviceIntro_Text3: String { return self._s[1395]! }
    public var InviteLink_InviteLinkRevoked: String { return self._s[1396]! }
    public var Contacts_PermissionsSuppressWarningText: String { return self._s[1397]! }
    public var OpenFile_PotentiallyDangerousContentAlert: String { return self._s[1398]! }
    public var Settings_SetUsername: String { return self._s[1399]! }
    public var GroupInfo_ActionRestrict: String { return self._s[1400]! }
    public var SettingsSearch_Synonyms_SavedMessages: String { return self._s[1401]! }
    public func Time_PreciseDate_m2(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1402]!, self._r[1402]!, [_1, _2, _3])
    }
    public var Notifications_DisplayNamesOnLockScreenInfoWithLink: String { return self._s[1404]! }
    public var Notification_Exceptions_AlwaysOff: String { return self._s[1405]! }
    public var Conversation_ContextMenuDelete: String { return self._s[1406]! }
    public var Privacy_Calls_WhoCanCallMe: String { return self._s[1407]! }
    public var ChatList_PsaAlert_covid: String { return self._s[1410]! }
    public var VoiceOver_SilentPostOn: String { return self._s[1411]! }
    public var DialogList_Pin: String { return self._s[1412]! }
    public var Channel_AdminLog_CanInviteUsersViaLink: String { return self._s[1413]! }
    public var PrivacySettings_SecurityTitle: String { return self._s[1414]! }
    public var GroupPermission_NotAvailableInPublicGroups: String { return self._s[1415]! }
    public var PeopleNearby_Groups: String { return self._s[1416]! }
    public var Message_File: String { return self._s[1417]! }
    public var Calls_NoCallsPlaceholder: String { return self._s[1418]! }
    public var ChatList_GenericPsaLabel: String { return self._s[1421]! }
    public var UserInfo_LastNamePlaceholder: String { return self._s[1422]! }
    public var IntentsSettings_Reset: String { return self._s[1424]! }
    public var Call_ConnectionErrorTitle: String { return self._s[1425]! }
    public var PhotoEditor_SaturationTool: String { return self._s[1426]! }
    public var ChatSettings_AutomaticVideoMessageDownload: String { return self._s[1427]! }
    public var SettingsSearch_Synonyms_Stickers_ArchivedPacks: String { return self._s[1428]! }
    public var Conversation_SearchNoResults: String { return self._s[1429]! }
    public var Channel_DiscussionGroup_PrivateChannel: String { return self._s[1430]! }
    public var Map_OpenInWaze: String { return self._s[1431]! }
    public var InviteLink_PeopleJoinedNone: String { return self._s[1432]! }
    public var WallpaperPreview_Title: String { return self._s[1433]! }
    public func Passport_AcceptHelp(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1435]!, self._r[1435]!, [_1, _2])
    }
    public var AuthSessions_AddDeviceIntro_Title: String { return self._s[1436]! }
    public var VoiceOver_Chat_RecordModeVideoMessageInfo: String { return self._s[1437]! }
    public var VoiceOver_Chat_ChannelInfo: String { return self._s[1438]! }
    public var Conversation_ImageCopied: String { return self._s[1439]! }
    public var Passport_Identity_OneOfTypeInternalPassport: String { return self._s[1440]! }
    public var Notifications_PermissionsUnreachableTitle: String { return self._s[1442]! }
    public var Stats_Total: String { return self._s[1445]! }
    public var Stats_GroupMessages: String { return self._s[1446]! }
    public var TwoFactorSetup_Email_SkipAction: String { return self._s[1447]! }
    public var CheckoutInfo_ErrorPhoneInvalid: String { return self._s[1448]! }
    public var VoiceChat_You: String { return self._s[1449]! }
    public var VoiceChat_DisplayAsInfoGroup: String { return self._s[1450]! }
    public var Passport_Identity_Translation: String { return self._s[1451]! }
    public var Notifications_TextTone: String { return self._s[1454]! }
    public var Settings_RemoveConfirmation: String { return self._s[1456]! }
    public var ScheduledMessages_Delete: String { return self._s[1457]! }
    public var Channel_AdminLog_BanEmbedLinks: String { return self._s[1458]! }
    public var Passport_PasswordNext: String { return self._s[1459]! }
    public func PUSH_ENCRYPTED_MESSAGE(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1460]!, self._r[1460]!, [_1])
    }
    public var Passport_Address_EditBankStatement: String { return self._s[1461]! }
    public var PhotoEditor_ShadowsTool: String { return self._s[1462]! }
    public var Notification_VideoCallMissed: String { return self._s[1463]! }
    public var AccessDenied_CameraDisabled: String { return self._s[1465]! }
    public var AuthSessions_AddDevice_ScanInfo: String { return self._s[1466]! }
    public var Notifications_ExceptionsMuted: String { return self._s[1467]! }
    public var Conversation_ScheduleMessage_SendWhenOnline: String { return self._s[1468]! }
    public var Channel_BlackList_Title: String { return self._s[1469]! }
    public var PasscodeSettings_4DigitCode: String { return self._s[1470]! }
    public var NotificationsSound_Bamboo: String { return self._s[1471]! }
    public var PrivacySettings_LastSeenContacts: String { return self._s[1472]! }
    public var Passport_Address_TypeUtilityBill: String { return self._s[1473]! }
    public var Passport_Address_CountryPlaceholder: String { return self._s[1474]! }
    public var GroupPermission_SectionTitle: String { return self._s[1475]! }
    public var InviteLink_ContextRevoke: String { return self._s[1476]! }
    public func Notification_InvitedMultiple(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1477]!, self._r[1477]!, [_0, _1])
    }
    public var CheckoutInfo_ShippingInfoStatePlaceholder: String { return self._s[1478]! }
    public var Channel_LeaveChannel: String { return self._s[1479]! }
    public var Watch_Notification_Joined: String { return self._s[1480]! }
    public var PeerInfo_ButtonMore: String { return self._s[1481]! }
    public var Passport_FieldEmailHelp: String { return self._s[1482]! }
    public var ChatList_Context_Pin: String { return self._s[1483]! }
    public func Time_MonthOfYear_m9(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1484]!, self._r[1484]!, [_0])
    }
    public var Group_Location_CreateInThisPlace: String { return self._s[1485]! }
    public var PhotoEditor_QualityVeryHigh: String { return self._s[1486]! }
    public var Tour_Title5: String { return self._s[1487]! }
    public func PUSH_CHAT_MESSAGE_FWD(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1488]!, self._r[1488]!, [_1, _2])
    }
    public var Passport_Language_en: String { return self._s[1489]! }
    public var Checkout_Name: String { return self._s[1490]! }
    public var ChatImport_Title: String { return self._s[1491]! }
    public func NetworkUsageSettings_WifiUsageSince(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1492]!, self._r[1492]!, [_0])
    }
    public var PhotoEditor_EnhanceTool: String { return self._s[1493]! }
    public func PUSH_CHAT_DELETE_YOU(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1494]!, self._r[1494]!, [_1, _2])
    }
    public func VoiceChat_UserCanNowSpeak(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1495]!, self._r[1495]!, [_0])
    }
    public var PeerInfo_CustomizeNotifications: String { return self._s[1496]! }
    public func Login_TermsOfService_ProceedBot(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1497]!, self._r[1497]!, [_0])
    }
    public var Group_ErrorSendRestrictedMedia: String { return self._s[1498]! }
    public func UserInfo_NotificationsDefaultSound(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1499]!, self._r[1499]!, [_0])
    }
    public var Login_UnknownError: String { return self._s[1500]! }
    public var Conversation_ImportedMessageHint: String { return self._s[1502]! }
    public func VoiceChat_ForwardTooltip_Chat(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1503]!, self._r[1503]!, [_0])
    }
    public var Passport_Identity_TypeDriversLicense: String { return self._s[1505]! }
    public var ChatList_AutoarchiveSuggestion_Title: String { return self._s[1506]! }
    public var Watch_PhotoView_Title: String { return self._s[1507]! }
    public var Appearance_ThemePreview_ChatList_3_Text: String { return self._s[1508]! }
    public var Checkout_TotalAmount: String { return self._s[1509]! }
    public var ChatList_RemoveFolderAction: String { return self._s[1510]! }
    public func GroupInfo_Permissions_BroadcastConvertInfo(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1511]!, self._r[1511]!, [_0])
    }
    public var GroupInfo_SetGroupPhoto: String { return self._s[1512]! }
    public var Watch_AppName: String { return self._s[1513]! }
    public func PUSH_PINNED_GAME_SCORE(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1514]!, self._r[1514]!, [_1])
    }
    public var Channel_Username_CheckingUsername: String { return self._s[1515]! }
    public var ContactList_Context_Call: String { return self._s[1516]! }
    public var ChatList_ReorderTabs: String { return self._s[1517]! }
    public var Watch_ChatList_Compose: String { return self._s[1518]! }
    public func Conversation_LiveLocationYouAnd(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1519]!, self._r[1519]!, [_0])
    }
    public var Channel_AdminLog_EmptyFilterTitle: String { return self._s[1520]! }
    public var ArchivedChats_IntroTitle1: String { return self._s[1521]! }
    public func PUSH_ENCRYPTION_ACCEPT(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1522]!, self._r[1522]!, [_1])
    }
    public var Call_StatusRequesting: String { return self._s[1524]! }
    public var Checkout_TotalPaidAmount: String { return self._s[1525]! }
    public var Weekday_Friday: String { return self._s[1527]! }
    public var CreateGroup_ChannelsTooMuch: String { return self._s[1528]! }
    public func ChatImport_SelectionConfirmationUserWithoutTitle(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1529]!, self._r[1529]!, [_0])
    }
    public var Watch_ChatList_NoConversationsText: String { return self._s[1530]! }
    public var Group_Members_AddMembersHelp: String { return self._s[1531]! }
    public func Channel_AdminLog_MessageChangedGroupStickerPack(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1532]!, self._r[1532]!, [_0])
    }
    public var SecretVideo_Title: String { return self._s[1533]! }
    public func Notification_PinnedStickerMessage(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1536]!, self._r[1536]!, [_0])
    }
    public var Undo_Undo: String { return self._s[1537]! }
    public var Watch_Microphone_Access: String { return self._s[1538]! }
    public func ChatImport_SelectionConfirmationGroupWithTitle(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1539]!, self._r[1539]!, [_1, _2])
    }
    public func PUSH_CHAT_MESSAGE_PHOTO(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1540]!, self._r[1540]!, [_1, _2])
    }
    public func ChatList_Search_NoResultsQueryDescription(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1541]!, self._r[1541]!, [_0])
    }
    public var Checkout_NewCard_PostcodeTitle: String { return self._s[1543]! }
    public var TwoFactorSetup_Intro_Action: String { return self._s[1544]! }
    public var Passport_Language_ne: String { return self._s[1545]! }
    public var TwoStepAuth_EmailHelp: String { return self._s[1547]! }
    public var Profile_MessageLifetime2s: String { return self._s[1548]! }
    public func Conversation_MessageDialogRetryAll(_ _1: Int) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1550]!, self._r[1550]!, ["\(_1)"])
    }
    public func Items_NOfM(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1551]!, self._r[1551]!, [_1, _2])
    }
    public var VoiceChat_SendPublicLinkSend: String { return self._s[1552]! }
    public var Media_LimitedAccessText: String { return self._s[1553]! }
    public func PUSH_CHAT_TITLE_EDITED(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1554]!, self._r[1554]!, [_1, _2])
    }
    public var GroupPermission_NoPinMessages: String { return self._s[1555]! }
    public func Notification_VoiceChatStarted(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1556]!, self._r[1556]!, [_1])
    }
    public func Notification_CreatedChat(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1557]!, self._r[1557]!, [_0])
    }
    public var FastTwoStepSetup_HintHelp: String { return self._s[1558]! }
    public var VoiceOver_SilentPostOff: String { return self._s[1559]! }
    public var WallpaperSearch_ColorRed: String { return self._s[1560]! }
    public var Watch_ConnectionDescription: String { return self._s[1561]! }
    public var Notification_Exceptions_AddException: String { return self._s[1562]! }
    public var LocalGroup_IrrelevantWarning: String { return self._s[1563]! }
    public var VoiceOver_MessageContextDelete: String { return self._s[1564]! }
    public var LogoutOptions_AlternativeOptionsSection: String { return self._s[1565]! }
    public var Passport_PasswordPlaceholder: String { return self._s[1566]! }
    public var TwoStepAuth_RecoveryEmailAddDescription: String { return self._s[1567]! }
    public var Stats_MessageInteractionsTitle: String { return self._s[1568]! }
    public var Appearance_ThemeCarouselClassic: String { return self._s[1569]! }
    public var TwoFactorSetup_Email_SkipConfirmationText: String { return self._s[1571]! }
    public var Channel_AdminLog_PinMessages: String { return self._s[1572]! }
    public var Passport_Address_AddRentalAgreement: String { return self._s[1574]! }
    public var Watch_Message_Game: String { return self._s[1575]! }
    public var PrivacyLastSeenSettings_NeverShareWith: String { return self._s[1576]! }
    public var PrivacyPolicy_DeclineLastWarning: String { return self._s[1577]! }
    public var EditTheme_FileReadError: String { return self._s[1578]! }
    public var Group_ErrorAddBlocked: String { return self._s[1579]! }
    public var CallSettings_UseLessDataLongDescription: String { return self._s[1580]! }
    public func PUSH_MESSAGE_PHOTO(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1582]!, self._r[1582]!, [_1])
    }
    public var GroupRemoved_ViewChannelInfo: String { return self._s[1583]! }
    public func UserInfo_BlockConfirmation(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1584]!, self._r[1584]!, [_0])
    }
    public var CheckoutInfo_ShippingInfoAddress2Placeholder: String { return self._s[1585]! }
    public var TwoFactorSetup_EmailVerification_Action: String { return self._s[1586]! }
    public func Username_LinkHint(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1587]!, self._r[1587]!, [_0])
    }
    public var ConversationProfile_ErrorCreatingConversation: String { return self._s[1588]! }
    public var Bot_GroupStatusReadsHistory: String { return self._s[1589]! }
    public var PhotoEditor_CurvesRed: String { return self._s[1590]! }
    public var InstantPage_TapToOpenLink: String { return self._s[1591]! }
    public var InviteLink_PeopleJoinedShortNoneExpired: String { return self._s[1592]! }
    public var FastTwoStepSetup_PasswordHelp: String { return self._s[1593]! }
    public var Conversation_DiscussionNotStarted: String { return self._s[1594]! }
    public var Notification_CallMissedShort: String { return self._s[1595]! }
    public func Notification_JoinedGroupByLink(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1596]!, self._r[1596]!, [_0])
    }
    public var Conversation_DeleteMessagesForEveryone: String { return self._s[1597]! }
    public var VoiceChat_UnpinVideo: String { return self._s[1598]! }
    public var Permissions_SiriTitle_v0: String { return self._s[1599]! }
    public var GroupInfo_AddUserLeftError: String { return self._s[1600]! }
    public var Conversation_SendMessage_SendSilently: String { return self._s[1601]! }
    public var Paint_Duplicate: String { return self._s[1602]! }
    public var AttachmentMenu_WebSearch: String { return self._s[1603]! }
    public var Bot_Stop: String { return self._s[1605]! }
    public var Conversation_PrivateChannelTimeLimitedAlertTitle: String { return self._s[1606]! }
    public var ReportGroupLocation_Report: String { return self._s[1607]! }
    public var Compose_Create: String { return self._s[1608]! }
    public var Stats_GroupViewers: String { return self._s[1609]! }
    public var AutoDownloadSettings_Channels: String { return self._s[1610]! }
    public var PhotoEditor_QualityHigh: String { return self._s[1611]! }
    public var VoiceChat_Leave: String { return self._s[1612]! }
    public var Call_Speaker: String { return self._s[1613]! }
    public func ChatList_LeaveGroupConfirmation(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1614]!, self._r[1614]!, [_0])
    }
    public var Conversation_CloudStorage_ChatStatus: String { return self._s[1615]! }
    public var Chat_AttachmentMultipleFilesDisabled: String { return self._s[1616]! }
    public var ChatList_Context_AddToFolder: String { return self._s[1617]! }
    public var InviteLink_QRCode_Info: String { return self._s[1618]! }
    public var AutoremoveSetup_Title: String { return self._s[1619]! }
    public var ChatList_DeleteForAllMembersConfirmationText: String { return self._s[1620]! }
    public var Conversation_Unblock: String { return self._s[1621]! }
    public var SettingsSearch_Synonyms_Proxy_UseForCalls: String { return self._s[1622]! }
    public func Time_PreciseDate_m8(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1623]!, self._r[1623]!, [_1, _2, _3])
    }
    public var Conversation_ContextMenuReply: String { return self._s[1624]! }
    public var Contacts_SearchLabel: String { return self._s[1625]! }
    public var Forward_ErrorPublicQuizDisabledInChannels: String { return self._s[1626]! }
    public var Stats_GroupMessagesTitle: String { return self._s[1628]! }
    public var Notification_CallCanceled: String { return self._s[1629]! }
    public var VoiceOver_Chat_Selected: String { return self._s[1630]! }
    public var NotificationsSound_Tremolo: String { return self._s[1632]! }
    public var VoiceOver_AuthSessions_CurrentSession: String { return self._s[1633]! }
    public var ChatList_Search_NoResultsDescription: String { return self._s[1634]! }
    public var AccessDenied_PhotosAndVideos: String { return self._s[1635]! }
    public var LogoutOptions_ClearCacheText: String { return self._s[1636]! }
    public func VoiceChat_DisplayAsSuccess(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1638]!, self._r[1638]!, [_0])
    }
    public var VoiceOver_Chat_Sticker: String { return self._s[1639]! }
    public var ChatListFolder_NameUnread: String { return self._s[1640]! }
    public var PeerInfo_ButtonMessage: String { return self._s[1642]! }
    public var InfoPlist_NSPhotoLibraryAddUsageDescription: String { return self._s[1643]! }
    public var BlockedUsers_SelectUserTitle: String { return self._s[1644]! }
    public var ChatSettings_Other: String { return self._s[1645]! }
    public var UserInfo_NotificationsEnabled: String { return self._s[1646]! }
    public var CreatePoll_OptionsHeader: String { return self._s[1647]! }
    public var Appearance_RemoveThemeColorConfirmation: String { return self._s[1650]! }
    public var Channel_Moderator_Title: String { return self._s[1651]! }
    public func Conversation_ForwardTooltip_Chat_Many(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1652]!, self._r[1652]!, [_0])
    }
    public func UserInfo_ContactForwardTooltip_ManyChats_One(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1653]!, self._r[1653]!, [_0, _1])
    }
    public var Channel_AdminLog_MessageRestrictedForever: String { return self._s[1654]! }
    public var WallpaperColors_Title: String { return self._s[1655]! }
    public var InviteLink_InviteLink: String { return self._s[1657]! }
    public var PrivacyPolicy_DeclineMessage: String { return self._s[1658]! }
    public var AutoDownloadSettings_VoiceMessagesTitle: String { return self._s[1659]! }
    public var Your_card_was_declined: String { return self._s[1660]! }
    public var SettingsSearch_FAQ: String { return self._s[1662]! }
    public var EditTheme_Expand_Preview_IncomingReplyName: String { return self._s[1663]! }
    public var Conversation_ReportSpamConfirmation: String { return self._s[1664]! }
    public var OwnershipTransfer_SecurityCheck: String { return self._s[1666]! }
    public var PrivacySettings_DataSettingsHelp: String { return self._s[1667]! }
    public var Settings_About_Help: String { return self._s[1668]! }
    public func Channel_DiscussionGroup_HeaderGroupSet(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1669]!, self._r[1669]!, [_0])
    }
    public var Settings_Proxy: String { return self._s[1670]! }
    public var TwoStepAuth_ResetAccountConfirmation: String { return self._s[1671]! }
    public var Passport_Identity_TypePassportUploadScan: String { return self._s[1673]! }
    public var NotificationsSound_Bell: String { return self._s[1674]! }
    public var PrivacySettings_Title: String { return self._s[1676]! }
    public var PrivacySettings_DataSettings: String { return self._s[1677]! }
    public var ConversationMedia_Title: String { return self._s[1678]! }
    public func Channel_AdminLog_MessageAddedAdminName(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1679]!, self._r[1679]!, [_1])
    }
    public func Conversation_EncryptedPlaceholderTitleIncoming(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1680]!, self._r[1680]!, [_0])
    }
    public var PrivacySettings_BlockedPeersEmpty: String { return self._s[1681]! }
    public var ReportPeer_ReasonPornography: String { return self._s[1683]! }
    public var Privacy_Calls: String { return self._s[1685]! }
    public var TwoFactorSetup_Email_Text: String { return self._s[1686]! }
    public var Conversation_EncryptedDescriptionTitle: String { return self._s[1687]! }
    public func VoiceOver_Chat_MusicTitle(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1688]!, self._r[1688]!, [_1, _2])
    }
    public var Passport_Identity_FrontSideHelp: String { return self._s[1689]! }
    public var InstantPage_VoiceOver_DecreaseFontSize: String { return self._s[1690]! }
    public var GroupInfo_Permissions_SlowmodeHeader: String { return self._s[1692]! }
    public var ContactList_Context_VideoCall: String { return self._s[1693]! }
    public var Settings_SaveIncomingPhotos: String { return self._s[1694]! }
    public var Passport_Identity_MiddleName: String { return self._s[1695]! }
    public var MessagePoll_QuizNoUsers: String { return self._s[1696]! }
    public func Channel_AdminLog_MutedParticipant(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1697]!, self._r[1697]!, [_1, _2])
    }
    public var OldChannels_ChannelFormat: String { return self._s[1698]! }
    public var Watch_Message_Call: String { return self._s[1699]! }
    public var VoiceChat_OpenChannel: String { return self._s[1700]! }
    public var Wallpaper_Title: String { return self._s[1701]! }
    public var PasscodeSettings_TurnPasscodeOff: String { return self._s[1702]! }
    public var IntentsSettings_SuggestedChatsSavedMessages: String { return self._s[1703]! }
    public var ReportGroupLocation_Text: String { return self._s[1704]! }
    public var InviteText_URL: String { return self._s[1705]! }
    public var ClearCache_StorageServiceFiles: String { return self._s[1706]! }
    public var MessageTimer_Custom: String { return self._s[1707]! }
    public var Message_PinnedLocationMessage: String { return self._s[1708]! }
    public func VoiceOver_Chat_ContactOrganization(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1709]!, self._r[1709]!, [_0])
    }
    public var EditTheme_UploadNewTheme: String { return self._s[1710]! }
    public var ChatImportActivity_ErrorLimitExceeded: String { return self._s[1713]! }
    public func AutoDownloadSettings_UpToForAll(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1714]!, self._r[1714]!, [_0])
    }
    public var Login_CodeSentCall: String { return self._s[1716]! }
    public func Conversation_AutoremoveTimerSetUser(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1717]!, self._r[1717]!, [_1, _2])
    }
    public var Conversation_Report: String { return self._s[1718]! }
    public var NotificationSettings_ContactJoined: String { return self._s[1719]! }
    public func PUSH_MESSAGE_SCREENSHOT(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1720]!, self._r[1720]!, [_1])
    }
    public var StickerPacksSettings_ShowStickersButtonHelp: String { return self._s[1721]! }
    public var BroadcastGroups_IntroText: String { return self._s[1722]! }
    public var IntentsSettings_SuggestByAll: String { return self._s[1724]! }
    public var StickerPacksSettings_ShowStickersButton: String { return self._s[1725]! }
    public var AuthSessions_Title: String { return self._s[1726]! }
    public func Notification_VoiceChatEnded(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1727]!, self._r[1727]!, [_0])
    }
    public var Channel_AdminLog_TitleAllEvents: String { return self._s[1728]! }
    public var KeyCommand_JumpToNextUnreadChat: String { return self._s[1729]! }
    public var VoiceChat_YouCanNowSpeak: String { return self._s[1732]! }
    public var Passport_Address_AddPassportRegistration: String { return self._s[1734]! }
    public func UserInfo_LinkForwardTooltip_ManyChats_One(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1735]!, self._r[1735]!, [_0, _1])
    }
    public var AutoDownloadSettings_MaxVideoSize: String { return self._s[1736]! }
    public var ExplicitContent_AlertTitle: String { return self._s[1737]! }
    public var Channel_UpdatePhotoItem: String { return self._s[1739]! }
    public var ChatList_AutoarchiveSuggestion_Text: String { return self._s[1741]! }
    public var Channel_DiscussionGroup_LinkGroup: String { return self._s[1742]! }
    public func Call_BatteryLow(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1743]!, self._r[1743]!, [_0])
    }
    public var Login_HaveNotReceivedCodeInternal: String { return self._s[1744]! }
    public var WallpaperPreview_PatternPaternApply: String { return self._s[1745]! }
    public var Notifications_MessageNotificationsSound: String { return self._s[1746]! }
    public var CommentsGroup_ErrorAccessDenied: String { return self._s[1747]! }
    public var Appearance_AccentColor: String { return self._s[1749]! }
    public var GroupInfo_SharedMedia: String { return self._s[1750]! }
    public var Login_PhonePlaceholder: String { return self._s[1751]! }
    public var Appearance_TextSize_Automatic: String { return self._s[1752]! }
    public var EmptyGroupInfo_Line2: String { return self._s[1753]! }
    public func PUSH_CHAT_CREATED(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1754]!, self._r[1754]!, [_1, _2])
    }
    public var VoiceChat_TapToAddPhotoOrBio: String { return self._s[1755]! }
    public var Conversation_ClearChannel: String { return self._s[1756]! }
    public var Appearance_AppIconDefaultX: String { return self._s[1758]! }
    public var EditProfile_NameAndPhotoOrVideoHelp: String { return self._s[1759]! }
    public var CheckoutInfo_ShippingInfoPostcodePlaceholder: String { return self._s[1760]! }
    public var Notifications_GroupNotificationsHelp: String { return self._s[1761]! }
    public func PUSH_CHAT_MESSAGE_NOTEXT(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1762]!, self._r[1762]!, [_1, _2])
    }
    public var ChatList_EmptyChatListEditFilter: String { return self._s[1763]! }
    public var ChatSettings_ConnectionType_UseProxy: String { return self._s[1766]! }
    public var Chat_PinnedMessagesHiddenText: String { return self._s[1767]! }
    public func Message_PinnedGenericMessage(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1768]!, self._r[1768]!, [_0])
    }
    public func Location_ProximityTip(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1769]!, self._r[1769]!, [_0])
    }
    public var UserInfo_NotificationsEnable: String { return self._s[1770]! }
    public var Checkout_PayWithTouchId: String { return self._s[1771]! }
    public var SharedMedia_ViewInChat: String { return self._s[1772]! }
    public func Notification_CreatedChatWithTitle(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1773]!, self._r[1773]!, [_0, _1])
    }
    public var ChatSettings_AutoDownloadSettings_OffForAll: String { return self._s[1774]! }
    public func Channel_DiscussionGroup_PublicChannelLink(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1775]!, self._r[1775]!, [_1, _2])
    }
    public func Cache_Clear(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1777]!, self._r[1777]!, [_0])
    }
    public var Conversation_PeerNearbyText: String { return self._s[1779]! }
    public var Conversation_StopPollConfirmationTitle: String { return self._s[1780]! }
    public var PhotoEditor_Skip: String { return self._s[1781]! }
    public var SettingsSearch_Synonyms_Appearance_ChatBackground_SetColor: String { return self._s[1782]! }
    public var ChatList_EmptyChatList: String { return self._s[1783]! }
    public var Channel_BanUser_Unban: String { return self._s[1784]! }
    public func Message_GenericForwardedPsa(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1785]!, self._r[1785]!, [_0])
    }
    public var Appearance_TextSize_Apply: String { return self._s[1786]! }
    public func Conversation_MessageViewCommentsFormat(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1787]!, self._r[1787]!, [_1, _2])
    }
    public var Login_InfoFirstNamePlaceholder: String { return self._s[1788]! }
    public var VoiceOver_Chat_YourSticker: String { return self._s[1789]! }
    public var TwoStepAuth_HintPlaceholder: String { return self._s[1790]! }
    public var TwoStepAuth_EmailSkip: String { return self._s[1792]! }
    public var ChatList_UndoArchiveMultipleTitle: String { return self._s[1793]! }
    public var TwoFactorSetup_Email_SkipConfirmationTitle: String { return self._s[1794]! }
    public func PUSH_MESSAGE_QUIZ(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1795]!, self._r[1795]!, [_1])
    }
    public var VoiceOver_Chat_GoToOriginalMessage: String { return self._s[1797]! }
    public var State_WaitingForNetwork: String { return self._s[1798]! }
    public var AccessDenied_CameraRestricted: String { return self._s[1799]! }
    public var ChatSettings_Appearance: String { return self._s[1800]! }
    public var ScheduledMessages_BotActionUnavailable: String { return self._s[1801]! }
    public var GroupInfo_InviteLink_CopyAlert_Success: String { return self._s[1802]! }
    public var Channel_DiscussionGroupAdd: String { return self._s[1803]! }
    public var Conversation_SelectMessages: String { return self._s[1805]! }
    public var Map_NoPlacesNearby: String { return self._s[1806]! }
    public var AuthSessions_IncompleteAttemptsInfo: String { return self._s[1807]! }
    public var GroupRemoved_Title: String { return self._s[1808]! }
    public var TwoStepAuth_EnterPasswordHelp: String { return self._s[1810]! }
    public var VoiceChat_Mute: String { return self._s[1811]! }
    public var Paint_Marker: String { return self._s[1812]! }
    public var Widget_ChatsGalleryTitle: String { return self._s[1813]! }
    public func AddContact_ContactWillBeSharedAfterMutual(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1814]!, self._r[1814]!, [_1])
    }
    public var SocksProxySetup_ShareProxyList: String { return self._s[1815]! }
    public var GroupInfo_InvitationLinkDoesNotExist: String { return self._s[1816]! }
    public func VoiceOver_Chat_Size(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1817]!, self._r[1817]!, [_0])
    }
    public var EditTheme_ErrorInvalidCharacters: String { return self._s[1818]! }
    public var Appearance_ThemePreview_ChatList_7_Name: String { return self._s[1819]! }
    public var Notifications_GroupNotificationsAlert: String { return self._s[1820]! }
    public var SocksProxySetup_ShareQRCode: String { return self._s[1821]! }
    public var Compose_NewGroup: String { return self._s[1822]! }
    public func Passport_Address_UploadOneOfScan(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1823]!, self._r[1823]!, [_0])
    }
    public var Location_LiveLocationRequired_Description: String { return self._s[1825]! }
    public var Conversation_ClearGroupHistory: String { return self._s[1826]! }
    public var GroupInfo_InviteLink_Help: String { return self._s[1829]! }
    public var VoiceOver_BotKeyboard: String { return self._s[1830]! }
    public var Channel_BanUser_BlockFor: String { return self._s[1831]! }
    public var Bot_Start: String { return self._s[1832]! }
    public var Your_card_has_expired: String { return self._s[1833]! }
    public var Channel_About_Title: String { return self._s[1834]! }
    public var VoiceChat_EditTitleTitle: String { return self._s[1835]! }
    public var Passport_Identity_ExpiryDatePlaceholder: String { return self._s[1836]! }
    public var SettingsSearch_Synonyms_Notifications_MessageNotificationsExceptions: String { return self._s[1838]! }
    public var Conversation_FileDropbox: String { return self._s[1839]! }
    public var ChatList_Search_NoResultsFitlerMusic: String { return self._s[1840]! }
    public var Month_GenNovember: String { return self._s[1841]! }
    public var IntentsSettings_SuggestByShare: String { return self._s[1842]! }
    public func Call_PrivacyErrorMessage(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1843]!, self._r[1843]!, [_0])
    }
    public var StickerPack_Add: String { return self._s[1844]! }
    public var Theme_ErrorNotFound: String { return self._s[1845]! }
    public var Wallpaper_SearchShort: String { return self._s[1847]! }
    public var Channel_BanUser_PermissionsHeader: String { return self._s[1848]! }
    public var ConversationProfile_UsersTooMuchError: String { return self._s[1849]! }
    public var ChatList_FolderAllChats: String { return self._s[1850]! }
    public var VoiceChat_EndConfirmationEnd: String { return self._s[1851]! }
    public var Passport_Authorize: String { return self._s[1852]! }
    public func Channel_AdminLog_MessageChangedLinkedChannel(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1853]!, self._r[1853]!, [_1, _2])
    }
    public var GroupInfo_GroupHistoryVisible: String { return self._s[1854]! }
    public func PUSH_MESSAGE_VIDEO(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1855]!, self._r[1855]!, [_1])
    }
    public var LocalGroup_ButtonTitle: String { return self._s[1856]! }
    public var VoiceOver_Stickers: String { return self._s[1858]! }
    public var UserInfo_GroupsInCommon: String { return self._s[1859]! }
    public var LoginPassword_Title: String { return self._s[1861]! }
    public var Wallpaper_Set: String { return self._s[1862]! }
    public var Stats_InteractionsTitle: String { return self._s[1863]! }
    public func SecretGIF_NotViewedYet(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1865]!, self._r[1865]!, [_0])
    }
    public var Conversation_MessageDialogEdit: String { return self._s[1866]! }
    public var Paint_Outlined: String { return self._s[1867]! }
    public func Login_ResetAccountProtected_Text(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1868]!, self._r[1868]!, [_0])
    }
    public func Conversation_SetReminder_RemindTomorrow(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1869]!, self._r[1869]!, [_0])
    }
    public var Invite_LargeRecipientsCountWarning: String { return self._s[1870]! }
    public var Passport_Address_Street1Placeholder: String { return self._s[1871]! }
    public var Appearance_ColorThemeNight: String { return self._s[1872]! }
    public var ChannelInfo_Stats: String { return self._s[1873]! }
    public var Widget_ShortcutsGalleryTitle: String { return self._s[1874]! }
    public var TwoStepAuth_RecoveryTitle: String { return self._s[1875]! }
    public var MediaPicker_TimerTooltip: String { return self._s[1876]! }
    public var ChatImportActivity_ErrorNotAdmin: String { return self._s[1877]! }
    public var Common_ChoosePhoto: String { return self._s[1878]! }
    public var Media_LimitedAccessTitle: String { return self._s[1879]! }
    public var ChatSettings_AutoDownloadVideos: String { return self._s[1880]! }
    public var PeerInfo_PaneGroups: String { return self._s[1881]! }
    public var SocksProxySetup_UsernamePlaceholder: String { return self._s[1883]! }
    public var ChangePhoneNumberNumber_Title: String { return self._s[1884]! }
    public var ContactInfo_PhoneLabelMobile: String { return self._s[1885]! }
    public var OldChannels_ChannelsHeader: String { return self._s[1886]! }
    public var MuteFor_Forever: String { return self._s[1887]! }
    public var Passport_Address_PostcodePlaceholder: String { return self._s[1888]! }
    public var SettingsSearch_Synonyms_Appearance_ChatBackground: String { return self._s[1890]! }
    public var MessagePoll_LabelAnonymous: String { return self._s[1891]! }
    public var ContactInfo_Job: String { return self._s[1892]! }
    public var Passport_Language_mk: String { return self._s[1893]! }
    public var EditTheme_ShortLink: String { return self._s[1894]! }
    public var AutoDownloadSettings_PhotosTitle: String { return self._s[1897]! }
    public var Month_GenApril: String { return self._s[1899]! }
    public var Channel_DiscussionGroup_HeaderLabel: String { return self._s[1901]! }
    public var NetworkUsageSettings_TotalSection: String { return self._s[1902]! }
    public var EditTheme_Create_Preview_OutgoingText: String { return self._s[1903]! }
    public var EditTheme_Title: String { return self._s[1904]! }
    public var Conversation_LinkDialogCopy: String { return self._s[1905]! }
    public func Channel_AdminLog_MessageInvitedNameUsername(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1906]!, self._r[1906]!, [_1, _2])
    }
    public var Passport_ForgottenPassword: String { return self._s[1907]! }
    public var WallpaperSearch_Recent: String { return self._s[1908]! }
    public var ChatSettings_Title: String { return self._s[1913]! }
    public var Appearance_ReduceMotionInfo: String { return self._s[1914]! }
    public func StickerPackActionInfo_AddedText(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1915]!, self._r[1915]!, [_0])
    }
    public var SocksProxySetup_UseForCallsHelp: String { return self._s[1916]! }
    public var LastSeen_WithinAMonth: String { return self._s[1917]! }
    public var VoiceChat_Live: String { return self._s[1918]! }
    public var PeerInfo_ButtonCall: String { return self._s[1919]! }
    public var SettingsSearch_Synonyms_Appearance_Title: String { return self._s[1920]! }
    public var Group_Username_InvalidStartsWithNumber: String { return self._s[1921]! }
    public var Call_AudioRouteHide: String { return self._s[1922]! }
    public var DialogList_SavedMessages: String { return self._s[1923]! }
    public var ChatList_Context_Mute: String { return self._s[1924]! }
    public var Conversation_StatusKickedFromChannel: String { return self._s[1925]! }
    public func Notification_Exceptions_MutedUntil(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1926]!, self._r[1926]!, [_0])
    }
    public var VoiceChat_StatusMutedForYou: String { return self._s[1927]! }
    public var Passport_Language_et: String { return self._s[1928]! }
    public var Conversation_MessageLeaveCommentShort: String { return self._s[1929]! }
    public var PhotoEditor_CropReset: String { return self._s[1930]! }
    public var Privacy_GroupsAndChannels_AlwaysAllow: String { return self._s[1931]! }
    public var SocksProxySetup_HostnamePlaceholder: String { return self._s[1932]! }
    public var CreateGroup_ErrorLocatedGroupsTooMuch: String { return self._s[1933]! }
    public var WallpaperSearch_ColorWhite: String { return self._s[1936]! }
    public var Channel_AdminLog_CanEditMessages: String { return self._s[1938]! }
    public var Privacy_PaymentsClearInfoDoneHelp: String { return self._s[1939]! }
    public var Channel_Username_InvalidStartsWithNumber: String { return self._s[1941]! }
    public var CheckoutInfo_ReceiverInfoName: String { return self._s[1943]! }
    public var Map_YouAreHere: String { return self._s[1945]! }
    public var Core_ServiceUserStatus: String { return self._s[1946]! }
    public var Channel_Setup_TypePrivateHelp: String { return self._s[1949]! }
    public var VoiceChat_StartRecording: String { return self._s[1950]! }
    public var SettingsSearch_Synonyms_Notifications_BadgeCountUnreadMessages: String { return self._s[1951]! }
    public var MediaPicker_Videos: String { return self._s[1953]! }
    public var Map_LiveLocationFor15Minutes: String { return self._s[1955]! }
    public var Passport_Identity_TranslationsHelp: String { return self._s[1956]! }
    public var SharedMedia_CategoryMedia: String { return self._s[1957]! }
    public func MediaPicker_Nof(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1958]!, self._r[1958]!, [_0])
    }
    public var ChatSettings_AutoPlayGifs: String { return self._s[1959]! }
    public var Passport_Identity_CountryPlaceholder: String { return self._s[1960]! }
    public var Bot_GroupStatusDoesNotReadHistory: String { return self._s[1961]! }
    public var Conversation_JoinVoiceChatAsListener: String { return self._s[1962]! }
    public var Notification_Exceptions_RemoveFromExceptions: String { return self._s[1963]! }
    public func Chat_SlowmodeTooltip(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1964]!, self._r[1964]!, [_0])
    }
    public var Web_Error: String { return self._s[1965]! }
    public var PhotoEditor_SkinTool: String { return self._s[1966]! }
    public var ApplyLanguage_UnsufficientDataTitle: String { return self._s[1967]! }
    public var AutoremoveSetup_TimerInfoChat: String { return self._s[1968]! }
    public var ChatSettings_ConnectionType_UseSocks5: String { return self._s[1970]! }
    public var PasscodeSettings_Help: String { return self._s[1971]! }
    public var Appearance_ColorTheme: String { return self._s[1972]! }
    public func Channel_AdminLog_MessageRestrictedNewSetting(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1973]!, self._r[1973]!, [_0])
    }
    public var InviteLink_DeleteAllRevokedLinks: String { return self._s[1974]! }
    public func PUSH_PINNED_GEO(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1975]!, self._r[1975]!, [_1])
    }
    public var InviteLink_QRCode_Title: String { return self._s[1976]! }
    public var GroupInfo_LeftStatus: String { return self._s[1977]! }
    public var EditTheme_Preview: String { return self._s[1978]! }
    public var Watch_Suggestion_WhatsUp: String { return self._s[1979]! }
    public func AutoDownloadSettings_PreloadVideoInfo(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1980]!, self._r[1980]!, [_0])
    }
    public var NotificationsSound_Keys: String { return self._s[1981]! }
    public var VoiceChat_StatusWantsToSpeak: String { return self._s[1982]! }
    public var PasscodeSettings_UnlockWithTouchId: String { return self._s[1983]! }
    public var ChatList_Context_MarkAsUnread: String { return self._s[1984]! }
    public var DialogList_AdNoticeAlert: String { return self._s[1985]! }
    public var UserInfo_Invite: String { return self._s[1986]! }
    public var Checkout_Email: String { return self._s[1987]! }
    public var Stats_GroupActionsTitle: String { return self._s[1988]! }
    public var Coub_TapForSound: String { return self._s[1989]! }
    public var Conversation_AutoremoveTimerRemovedUserYou: String { return self._s[1990]! }
    public var Theme_ThemeChangedText: String { return self._s[1991]! }
    public var Call_ExternalCallInProgressMessage: String { return self._s[1992]! }
    public var AutoremoveSetup_TimerInfoChannel: String { return self._s[1993]! }
    public var Settings_ApplyProxyAlertEnable: String { return self._s[1994]! }
    public var ScheduledMessages_ScheduledToday: String { return self._s[1995]! }
    public var Channel_AdminLog_DefaultRestrictionsUpdated: String { return self._s[1996]! }
    public func VoiceChat_InviteMemberToChannelFirstText(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1997]!, self._r[1997]!, [_1, _2])
    }
    public var Call_ReportIncludeLogDescription: String { return self._s[1998]! }
    public var Settings_FrequentlyAskedQuestions: String { return self._s[2000]! }
    public var Call_VoiceOver_VoiceCallMissed: String { return self._s[2001]! }
    public var Channel_MessagePhotoRemoved: String { return self._s[2002]! }
    public var Passport_Email_Delete: String { return self._s[2003]! }
    public func PUSH_PINNED_PHOTO(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2004]!, self._r[2004]!, [_1])
    }
    public var NotificationSettings_ShowNotificationsAllAccountsInfoOn: String { return self._s[2005]! }
    public func Conversation_AutoremoveTimerRemovedUser(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2006]!, self._r[2006]!, [_1])
    }
    public var Channel_AdminLog_CanAddAdmins: String { return self._s[2007]! }
    public var SocksProxySetup_FailedToConnect: String { return self._s[2009]! }
    public var SettingsSearch_Synonyms_Data_NetworkUsage: String { return self._s[2010]! }
    public var Common_of: String { return self._s[2011]! }
    public var VoiceChat_CreateNewVoiceChatText: String { return self._s[2012]! }
    public var VoiceChat_StartRecordingStart: String { return self._s[2013]! }
    public var PeerInfo_ButtonUnmute: String { return self._s[2016]! }
    public func ChatSettings_AutoDownloadSettings_TypeFile(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2017]!, self._r[2017]!, [_0])
    }
    public var ChatList_AddChatsToFolder: String { return self._s[2018]! }
    public var Login_ResetAccountProtected_LimitExceeded: String { return self._s[2019]! }
    public var Settings_Title: String { return self._s[2021]! }
    public var AutoDownloadSettings_Contacts: String { return self._s[2023]! }
    public var Appearance_BubbleCornersSetting: String { return self._s[2024]! }
    public var InviteLink_OtherAdminsLinks: String { return self._s[2025]! }
    public var Privacy_Calls_AlwaysAllow: String { return self._s[2026]! }
    public var Privacy_Forwards_AlwaysAllow_Title: String { return self._s[2028]! }
    public var WallpaperPreview_CropBottomText: String { return self._s[2029]! }
    public var SecretTimer_VideoDescription: String { return self._s[2030]! }
    public var VoiceOver_Chat_AnimatedSticker: String { return self._s[2031]! }
    public var WallpaperPreview_Blurred: String { return self._s[2032]! }
    public var SettingsSearch_Synonyms_Notifications_GroupNotificationsExceptions: String { return self._s[2033]! }
    public var ChatListFolder_ExcludedSectionHeader: String { return self._s[2035]! }
    public var Conversation_CancelForwardSelectChat: String { return self._s[2036]! }
    public var DialogList_PasscodeLockHelp: String { return self._s[2037]! }
    public var SocksProxySetup_SecretPlaceholder: String { return self._s[2038]! }
    public var NetworkUsageSettings_CallDataSection: String { return self._s[2039]! }
    public var TwoStepAuth_PasswordRemovePassportConfirmation: String { return self._s[2040]! }
    public var Passport_FieldAddressTranslationHelp: String { return self._s[2041]! }
    public var SocksProxySetup_Connection: String { return self._s[2042]! }
    public var Passport_Address_TypePassportRegistration: String { return self._s[2043]! }
    public var Contacts_PermissionsAllowInSettings: String { return self._s[2044]! }
    public var Conversation_Unpin: String { return self._s[2045]! }
    public var Notifications_MessageNotificationsExceptionsHelp: String { return self._s[2046]! }
    public var TwoFactorSetup_Hint_Placeholder: String { return self._s[2047]! }
    public var Call_ReportSkip: String { return self._s[2048]! }
    public func VoiceOver_Chat_PhotoFrom(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2049]!, self._r[2049]!, [_0])
    }
    public func VoiceOver_Chat_Caption(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2051]!, self._r[2051]!, [_0])
    }
    public var AutoNightTheme_Automatic: String { return self._s[2052]! }
    public var Passport_Language_az: String { return self._s[2054]! }
    public func Conversation_AutoremoveChanged(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2055]!, self._r[2055]!, [_0])
    }
    public var SettingsSearch_Synonyms_Data_Storage_ClearCache: String { return self._s[2056]! }
    public var Watch_UserInfo_Unmute: String { return self._s[2057]! }
    public var Channel_Stickers_YourStickers: String { return self._s[2058]! }
    public var Channel_DiscussionGroup_UnlinkChannel: String { return self._s[2059]! }
    public var PeerInfo_AutoremoveMessagesDisabled: String { return self._s[2060]! }
    public var Tour_Text1: String { return self._s[2061]! }
    public var Common_Delete: String { return self._s[2062]! }
    public var Settings_EditPhoto: String { return self._s[2063]! }
    public var Common_Edit: String { return self._s[2064]! }
    public var ShareMenu_ShareTo: String { return self._s[2066]! }
    public var Passport_Identity_ExpiryDate: String { return self._s[2067]! }
    public func Channel_AdminLog_MutedNewMembers(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2068]!, self._r[2068]!, [_1])
    }
    public var Preview_DeleteGif: String { return self._s[2069]! }
    public var WallpaperPreview_PatternPaternDiscard: String { return self._s[2070]! }
    public var ChatSettings_AutoDownloadUsingCellular: String { return self._s[2071]! }
    public var Conversation_ViewReply: String { return self._s[2072]! }
    public var Stats_LoadingText: String { return self._s[2073]! }
    public var Channel_EditAdmin_PermissinAddAdminOn: String { return self._s[2074]! }
    public var CheckoutInfo_ReceiverInfoEmailPlaceholder: String { return self._s[2075]! }
    public var Channel_AdminLog_CanChangeInfo: String { return self._s[2076]! }
    public func Passport_Phone_UseTelegramNumber(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2077]!, self._r[2077]!, [_0])
    }
    public func Time_MonthOfYear_m2(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2078]!, self._r[2078]!, [_0])
    }
    public func VoiceOver_Chat_VideoMessageFrom(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2080]!, self._r[2080]!, [_0])
    }
    public var Passport_Address_OneOfTypeRentalAgreement: String { return self._s[2081]! }
    public var InviteLink_Share: String { return self._s[2083]! }
    public func Conversation_ImportProgress(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2085]!, self._r[2085]!, [_0])
    }
    public var IntentsSettings_MainAccount: String { return self._s[2086]! }
    public var Group_MessagePhotoRemoved: String { return self._s[2089]! }
    public var Conversation_ContextMenuSelect: String { return self._s[2090]! }
    public var GroupInfo_Permissions_Exceptions: String { return self._s[2092]! }
    public var GroupRemoved_UsersSectionTitle: String { return self._s[2093]! }
    public var Contacts_PermissionsEnable: String { return self._s[2094]! }
    public var Channel_EditAdmin_PermissionDeleteMessagesOfOthers: String { return self._s[2095]! }
    public var Common_NotNow: String { return self._s[2096]! }
    public var Notification_CreatedChannel: String { return self._s[2097]! }
    public var Stats_ViewsBySourceTitle: String { return self._s[2099]! }
    public var InviteLink_ContextShare: String { return self._s[2100]! }
    public var Appearance_AppIconClassic: String { return self._s[2101]! }
    public var PhotoEditor_QualityTool: String { return self._s[2102]! }
    public var ClearCache_ClearCache: String { return self._s[2103]! }
    public var TwoFactorSetup_Password_PlaceholderConfirmPassword: String { return self._s[2104]! }
    public var AutoDownloadSettings_Videos: String { return self._s[2105]! }
    public var GroupPermission_Duration: String { return self._s[2106]! }
    public var ChatList_Read: String { return self._s[2107]! }
    public func Group_OwnershipTransfer_DescriptionInfo(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2108]!, self._r[2108]!, [_1, _2])
    }
    public func ScheduleVoiceChat_ScheduleTomorrow(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2109]!, self._r[2109]!, [_0])
    }
    public var CallFeedback_Send: String { return self._s[2110]! }
    public var Channel_Stickers_Searching: String { return self._s[2111]! }
    public var ScheduledMessages_ReminderNotification: String { return self._s[2112]! }
    public var FastTwoStepSetup_HintSection: String { return self._s[2113]! }
    public var ChatSettings_AutoDownloadVideoMessages: String { return self._s[2114]! }
    public var EditTheme_CreateTitle: String { return self._s[2116]! }
    public var Application_Name: String { return self._s[2117]! }
    public var Paint_Stickers: String { return self._s[2118]! }
    public var Appearance_ThemePreview_Chat_1_Text: String { return self._s[2119]! }
    public var Call_StatusFailed: String { return self._s[2120]! }
    public var Stickers_FavoriteStickers: String { return self._s[2121]! }
    public var ClearCache_Clear: String { return self._s[2122]! }
    public var Passport_Language_mn: String { return self._s[2123]! }
    public var WallpaperPreview_PreviewTopText: String { return self._s[2124]! }
    public var LogoutOptions_ClearCacheTitle: String { return self._s[2125]! }
    public var Call_VoiceOver_VideoCallOutgoing: String { return self._s[2127]! }
    public var TwoFactorSetup_Hint_Text: String { return self._s[2129]! }
    public var WallpaperPreview_PatternIntensity: String { return self._s[2130]! }
    public var CheckoutInfo_ErrorShippingNotAvailable: String { return self._s[2131]! }
    public var Passport_Address_AddBankStatement: String { return self._s[2132]! }
    public func Conversation_TitleRepliesFormat(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2135]!, self._r[2135]!, [_1, _2])
    }
    public var ChatListFolderSettings_RecommendedNewFolder: String { return self._s[2136]! }
    public var UserInfo_ShareContact: String { return self._s[2137]! }
    public var Passport_Identity_NamePlaceholder: String { return self._s[2138]! }
    public var Channel_ErrorAdminsTooMuch: String { return self._s[2140]! }
    public var Call_RateCall: String { return self._s[2141]! }
    public var Contacts_AccessDeniedError: String { return self._s[2142]! }
    public var Invite_ChannelsTooMuch: String { return self._s[2143]! }
    public var CheckoutInfo_ShippingInfoPostcode: String { return self._s[2144]! }
    public var Channel_BanUser_PermissionReadMessages: String { return self._s[2145]! }
    public var InviteLink_Create_TimeLimitInfo: String { return self._s[2146]! }
    public var Cache_NoLimit: String { return self._s[2149]! }
    public var Conversation_EmptyPlaceholder: String { return self._s[2150]! }
    public var Privacy_GroupsAndChannels_AlwaysAllow_Placeholder: String { return self._s[2154]! }
    public var Notification_Exceptions_MessagePreviewAlwaysOff: String { return self._s[2155]! }
    public var GroupRemoved_RemoveInfo: String { return self._s[2156]! }
    public var Privacy_Calls_IntegrationHelp: String { return self._s[2157]! }
    public func PUSH_VIDEO_CALL_MISSED(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2158]!, self._r[2158]!, [_1])
    }
    public var VoiceOver_Media_PlaybackRateFast: String { return self._s[2159]! }
    public var Theme_ThemeChanged: String { return self._s[2160]! }
    public var Privacy_GroupsAndChannels_NeverAllow: String { return self._s[2162]! }
    public var AutoDownloadSettings_MediaTypes: String { return self._s[2163]! }
    public func Notification_PinnedDocumentMessage(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2164]!, self._r[2164]!, [_0])
    }
    public var Channel_AdminLog_InfoPanelTitle: String { return self._s[2165]! }
    public var Passport_Language_da: String { return self._s[2167]! }
    public var Chat_SlowmodeSendError: String { return self._s[2168]! }
    public var Application_Update: String { return self._s[2170]! }
    public var SocksProxySetup_SaveProxy: String { return self._s[2171]! }
    public func PUSH_AUTH_REGION(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2172]!, self._r[2172]!, [_1, _2])
    }
    public var Privacy_AddNewPeer: String { return self._s[2174]! }
    public var Channel_DiscussionGroup_MakeHistoryPublicProceed: String { return self._s[2176]! }
    public var Channel_Members_Title: String { return self._s[2177]! }
    public var StickerPacks_ActionDelete: String { return self._s[2178]! }
    public var Conversation_ScheduledVoiceChat: String { return self._s[2179]! }
    public var Settings_LogoutConfirmationText: String { return self._s[2181]! }
    public var Chat_UnsendMyMessages: String { return self._s[2182]! }
    public var PeerInfo_ReportProfilePhoto: String { return self._s[2183]! }
    public var Conversation_EditingMessageMediaEditCurrentVideo: String { return self._s[2185]! }
    public var ChatListFilter_AddChatsTitle: String { return self._s[2186]! }
    public var Passport_FloodError: String { return self._s[2187]! }
    public var NotificationSettings_ContactJoinedInfo: String { return self._s[2188]! }
    public var SettingsSearch_Synonyms_Privacy_Data_SecretChatLinkPreview: String { return self._s[2189]! }
    public var CallSettings_TabIconDescription: String { return self._s[2190]! }
    public var Group_Setup_HistoryHeader: String { return self._s[2192]! }
    public func Channel_AdminLog_AllowedNewMembersToSpeak(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2193]!, self._r[2193]!, [_1])
    }
    public var TwoStepAuth_EmailTitle: String { return self._s[2194]! }
    public var GroupInfo_Permissions_Removed: String { return self._s[2195]! }
    public var DialogList_ClearHistoryConfirmation: String { return self._s[2196]! }
    public var Contacts_Title: String { return self._s[2198]! }
    public func Notification_Invited(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2199]!, self._r[2199]!, [_0, _1])
    }
    public var ChatList_PeerTypeBot: String { return self._s[2202]! }
    public func Channel_AdminLog_SetSlowmode(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2203]!, self._r[2203]!, [_1, _2])
    }
    public var Appearance_ThemePreview_Chat_6_Text: String { return self._s[2204]! }
    public func Time_PreciseDate_m1(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2205]!, self._r[2205]!, [_1, _2, _3])
    }
    public var Camera_PhotoMode: String { return self._s[2207]! }
    public func PUSH_MESSAGE_GAME_SCORE(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2208]!, self._r[2208]!, [_1, _2, _3])
    }
    public var ContactInfo_PhoneLabelPager: String { return self._s[2209]! }
    public var SettingsSearch_Synonyms_FAQ: String { return self._s[2210]! }
    public var Call_CallAgain: String { return self._s[2211]! }
    public var TwoStepAuth_PasswordSet: String { return self._s[2212]! }
    public var VoiceChat_EditDescriptionPlaceholder: String { return self._s[2213]! }
    public func Channel_Management_RestrictedBy(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2214]!, self._r[2214]!, [_0])
    }
    public var GroupInfo_InviteLink_RevokeAlert_Success: String { return self._s[2215]! }
    public var ClearCache_FreeSpaceDescription: String { return self._s[2216]! }
    public var Permissions_ContactsAllowInSettings_v0: String { return self._s[2217]! }
    public var Group_LeaveGroup: String { return self._s[2218]! }
    public var Channel_Setup_LinkTypePrivate: String { return self._s[2220]! }
    public var GroupInfo_LabelAdmin: String { return self._s[2222]! }
    public var CheckoutInfo_ErrorStateInvalid: String { return self._s[2224]! }
    public var Notification_PassportValuePersonalDetails: String { return self._s[2225]! }
    public func WebSearch_SearchNoResultsDescription(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2226]!, self._r[2226]!, [_0])
    }
    public var Stats_GroupNewMembersBySourceTitle: String { return self._s[2227]! }
    public var Appearance_Preview: String { return self._s[2228]! }
    public var VoiceOver_Chat_Contact: String { return self._s[2229]! }
    public var Passport_Language_th: String { return self._s[2230]! }
    public var PhotoEditor_CropAspectRatioOriginal: String { return self._s[2232]! }
    public var LastSeen_Offline: String { return self._s[2235]! }
    public var Map_OpenInHereMaps: String { return self._s[2236]! }
    public var SettingsSearch_Synonyms_Data_AutoplayVideos: String { return self._s[2237]! }
    public var InviteLink_ContextEdit: String { return self._s[2239]! }
    public var AutoDownloadSettings_Reset: String { return self._s[2240]! }
    public var Conversation_SendMessage_SetReminder: String { return self._s[2241]! }
    public var Channel_AdminLog_EmptyMessageText: String { return self._s[2242]! }
    public func AddContact_StatusSuccess(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2243]!, self._r[2243]!, [_0])
    }
    public func AuthCode_Alert(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2244]!, self._r[2244]!, [_0])
    }
    public var Passport_Identity_EditDriversLicense: String { return self._s[2245]! }
    public var ChatListFolder_NameNonMuted: String { return self._s[2246]! }
    public var Username_Placeholder: String { return self._s[2247]! }
    public func PUSH_ALBUM(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2248]!, self._r[2248]!, [_1])
    }
    public var Passport_Language_it: String { return self._s[2249]! }
    public var Checkout_NewCard_SaveInfo: String { return self._s[2250]! }
    public func Channel_OwnershipTransfer_DescriptionInfo(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2251]!, self._r[2251]!, [_1, _2])
    }
    public var NotificationsSound_Pulse: String { return self._s[2252]! }
    public var VoiceOver_DismissContextMenu: String { return self._s[2254]! }
    public var MessagePoll_NoVotes: String { return self._s[2257]! }
    public var Message_Wallpaper: String { return self._s[2258]! }
    public var Conversation_JoinVoiceChat: String { return self._s[2259]! }
    public var Appearance_Other: String { return self._s[2260]! }
    public var Passport_Identity_NativeNameHelp: String { return self._s[2262]! }
    public var Group_PublicLink_Placeholder: String { return self._s[2266]! }
    public var Appearance_ThemePreview_ChatList_2_Text: String { return self._s[2267]! }
    public var VoiceOver_Recording_StopAndPreview: String { return self._s[2268]! }
    public var ChatListFolder_NameBots: String { return self._s[2269]! }
    public var Conversation_StopPollConfirmation: String { return self._s[2270]! }
    public var UserInfo_DeleteContact: String { return self._s[2271]! }
    public func Time_MonthOfYear_m11(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2272]!, self._r[2272]!, [_0])
    }
    public var Wallpaper_Wallpaper: String { return self._s[2274]! }
    public func PUSH_MESSAGE_NOTEXT(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2275]!, self._r[2275]!, [_1])
    }
    public var LoginPassword_ForgotPassword: String { return self._s[2276]! }
    public var FeaturedStickerPacks_Title: String { return self._s[2277]! }
    public var Paint_Pen: String { return self._s[2278]! }
    public var Channel_AdminLogFilter_EventsInfo: String { return self._s[2279]! }
    public var ChatListFolderSettings_Info: String { return self._s[2280]! }
    public var FastTwoStepSetup_HintPlaceholder: String { return self._s[2281]! }
    public var PhotoEditor_CurvesAll: String { return self._s[2283]! }
    public func Time_PreciseDate_m12(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2285]!, self._r[2285]!, [_1, _2, _3])
    }
    public var Passport_Address_TypeRentalAgreement: String { return self._s[2287]! }
    public var Message_ImageExpired: String { return self._s[2288]! }
    public var Call_ConnectionErrorMessage: String { return self._s[2289]! }
    public var SearchImages_NoImagesFound: String { return self._s[2291]! }
    public var PeerInfo_PaneGifs: String { return self._s[2292]! }
    public var Passport_DeletePersonalDetailsConfirmation: String { return self._s[2293]! }
    public var EnterPasscode_RepeatNewPasscode: String { return self._s[2294]! }
    public var PhotoEditor_VignetteTool: String { return self._s[2295]! }
    public var Passport_Language_dz: String { return self._s[2296]! }
    public var Notifications_ChannelNotificationsHelp: String { return self._s[2297]! }
    public var Conversation_BlockUser: String { return self._s[2298]! }
    public var GroupPermission_PermissionDisabledByDefault: String { return self._s[2301]! }
    public var Group_OwnershipTransfer_ErrorAdminsTooMuch: String { return self._s[2303]! }
    public func Time_MonthOfYear_m8(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2304]!, self._r[2304]!, [_0])
    }
    public var KeyCommand_NewMessage: String { return self._s[2305]! }
    public var EditTheme_Edit_Preview_IncomingReplyText: String { return self._s[2308]! }
    public func PUSH_CHAT_MESSAGE_GEO(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2310]!, self._r[2310]!, [_1, _2])
    }
    public var ContactList_Context_StartSecretChat: String { return self._s[2311]! }
    public var VoiceOver_Chat_File: String { return self._s[2312]! }
    public var ChatList_EditFolder: String { return self._s[2314]! }
    public var Appearance_BubbleCorners_Title: String { return self._s[2315]! }
    public var PeerInfo_PaneAudio: String { return self._s[2316]! }
    public var ChatListFolder_CategoryContacts: String { return self._s[2318]! }
    public var VoiceOver_ScheduledMessages: String { return self._s[2319]! }
    public func Login_InvalidPhoneEmailBody(_ _1: String, _ _2: String, _ _3: String, _ _4: String, _ _5: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2320]!, self._r[2320]!, [_1, _2, _3, _4, _5])
    }
    public var ChatList_PeerTypeChannel: String { return self._s[2321]! }
    public var VoiceOver_Navigation_Search: String { return self._s[2322]! }
    public var Settings_Search: String { return self._s[2323]! }
    public var WallpaperSearch_ColorYellow: String { return self._s[2324]! }
    public var Login_PhoneBannedError: String { return self._s[2325]! }
    public var KeyCommand_JumpToNextChat: String { return self._s[2326]! }
    public var Passport_Language_fa: String { return self._s[2327]! }
    public var Settings_About: String { return self._s[2328]! }
    public var AutoDownloadSettings_MaxFileSize: String { return self._s[2329]! }
    public var Channel_AdminLog_InfoPanelChannelAlertText: String { return self._s[2330]! }
    public var AutoDownloadSettings_DataUsageHigh: String { return self._s[2331]! }
    public func PUSH_CHAT_MESSAGE_TEXT(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2332]!, self._r[2332]!, [_1, _2, _3])
    }
    public var Common_OK: String { return self._s[2333]! }
    public var Contacts_SortBy: String { return self._s[2334]! }
    public var AutoNightTheme_PreferredTheme: String { return self._s[2335]! }
    public func AutoDownloadSettings_OnFor(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2337]!, self._r[2337]!, [_0])
    }
    public var CallFeedback_IncludeLogs: String { return self._s[2340]! }
    public func External_OpenIn(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2341]!, self._r[2341]!, [_0])
    }
    public var Passcode_AppLockedAlert: String { return self._s[2343]! }
    public var TwoStepAuth_SetupPasswordTitle: String { return self._s[2344]! }
    public var Channel_NotificationLoading: String { return self._s[2346]! }
    public var Passport_Identity_DocumentNumber: String { return self._s[2347]! }
    public var VoiceOver_Chat_PagePreview: String { return self._s[2348]! }
    public var VoiceOver_Chat_OpenHint: String { return self._s[2349]! }
    public var Weekday_ShortFriday: String { return self._s[2350]! }
    public var Conversation_TitleMute: String { return self._s[2351]! }
    public var SettingsSearch_Synonyms_Notifications_GroupNotificationsSound: String { return self._s[2352]! }
    public var ScheduledMessages_PollUnavailable: String { return self._s[2353]! }
    public var DialogList_LanguageTooltip: String { return self._s[2355]! }
    public var BroadcastGroups_IntroTitle: String { return self._s[2356]! }
    public var Channel_AdminLogFilter_EventsPinned: String { return self._s[2357]! }
    public func DialogList_SingleUploadingVideoSuffix(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2358]!, self._r[2358]!, [_0])
    }
    public var TwoStepAuth_SetupResendEmailCodeAlert: String { return self._s[2360]! }
    public var Privacy_Calls_AlwaysAllow_Title: String { return self._s[2361]! }
    public var Settings_EditVideo: String { return self._s[2362]! }
    public var VoiceOver_Common_Off: String { return self._s[2363]! }
    public var Stickers_FrequentlyUsed: String { return self._s[2364]! }
    public var GroupPermission_Title: String { return self._s[2365]! }
    public var AccessDenied_VideoMessageCamera: String { return self._s[2366]! }
    public var Appearance_ThemeCarouselDay: String { return self._s[2367]! }
    public func PUSH_CHAT_MESSAGE_AUDIO(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2368]!, self._r[2368]!, [_1, _2])
    }
    public var Passport_Identity_DocumentNumberPlaceholder: String { return self._s[2369]! }
    public var Tour_Title6: String { return self._s[2370]! }
    public var EmptyGroupInfo_Title: String { return self._s[2371]! }
    public func Channel_AdminLog_MessageToggleSignaturesOn(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2372]!, self._r[2372]!, [_0])
    }
    public var Passport_Language_sk: String { return self._s[2373]! }
    public var VoiceOver_Chat_YourAnonymousPoll: String { return self._s[2374]! }
    public var Preview_SaveToCameraRoll: String { return self._s[2375]! }
    public func VoiceChat_YouCanNowSpeakIn(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2376]!, self._r[2376]!, [_0])
    }
    public var LogoutOptions_SetPasscodeTitle: String { return self._s[2377]! }
    public var Passport_Address_TypeUtilityBillUploadScan: String { return self._s[2378]! }
    public var Conversation_ContextMenuMore: String { return self._s[2379]! }
    public var Conversation_ForwardAuthorHiddenTooltip: String { return self._s[2380]! }
    public var Channel_AdminLog_CanBeAnonymous: String { return self._s[2381]! }
    public var CallFeedback_ReasonSilentLocal: String { return self._s[2383]! }
    public func Channel_AdminLog_UnmutedMutedParticipant(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2384]!, self._r[2384]!, [_1, _2])
    }
    public var UserInfo_NotificationsDisable: String { return self._s[2385]! }
    public func Channel_AdminLog_EmptyFilterQueryText(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2387]!, self._r[2387]!, [_0])
    }
    public var SettingsSearch_Synonyms_EditProfile_Bio: String { return self._s[2388]! }
    public func Date_ChatDateHeader(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2390]!, self._r[2390]!, [_1, _2])
    }
    public var WallpaperSearch_ColorPrefix: String { return self._s[2391]! }
    public func Message_ForwardedPsa_covid(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2392]!, self._r[2392]!, [_0])
    }
    public var Conversation_RestrictedMedia: String { return self._s[2394]! }
    public var Group_MessageVideoUpdated: String { return self._s[2395]! }
    public var NetworkUsageSettings_ResetStatsConfirmation: String { return self._s[2396]! }
    public var GroupInfo_DeleteAndExit: String { return self._s[2397]! }
    public var TwoFactorSetup_Email_Action: String { return self._s[2398]! }
    public var Media_ShareThisVideo: String { return self._s[2400]! }
    public var DialogList_Replies: String { return self._s[2402]! }
    public func Conversation_Moderate_DeleteAllMessages(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2403]!, self._r[2403]!, [_0])
    }
    public var CheckoutInfo_ShippingInfoAddress1: String { return self._s[2404]! }
    public var Watch_Suggestion_OnMyWay: String { return self._s[2405]! }
    public var CheckoutInfo_ShippingInfoAddress2: String { return self._s[2406]! }
    public func PUSH_PINNED_POLL(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2407]!, self._r[2407]!, [_1, _2])
    }
    public func GroupInfo_InvitationLinkAcceptChannel(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2408]!, self._r[2408]!, [_0])
    }
    public var Channel_EditAdmin_PermissinAddAdminOff: String { return self._s[2409]! }
    public var ChatAdmins_AllMembersAreAdminsOnHelp: String { return self._s[2410]! }
    public var ChatList_Search_NoResultsFitlerMedia: String { return self._s[2411]! }
    public var Channel_Members_InviteLink: String { return self._s[2412]! }
    public var Conversation_TapAndHoldToRecord: String { return self._s[2413]! }
    public var WatchRemote_AlertText: String { return self._s[2414]! }
    public func Channel_DiscussionGroup_PrivateChannelLink(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2415]!, self._r[2415]!, [_1, _2])
    }
    public var Conversation_Pin: String { return self._s[2416]! }
    public var InfoPlist_NSMicrophoneUsageDescription: String { return self._s[2417]! }
    public var Stickers_RemoveFromFavorites: String { return self._s[2418]! }
    public var Conversation_CancelForwardTitle: String { return self._s[2419]! }
    public func Notification_PinnedPollMessage(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2420]!, self._r[2420]!, [_0])
    }
    public var Appearance_AppIconFilled: String { return self._s[2421]! }
    public var StickerPack_ErrorNotFound: String { return self._s[2422]! }
    public func Channel_AdminLog_MessageRestrictedName(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2423]!, self._r[2423]!, [_1])
    }
    public var Passport_Identity_AddIdentityCard: String { return self._s[2424]! }
    public func PUSH_CHANNEL_MESSAGE_DOC(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2426]!, self._r[2426]!, [_1])
    }
    public var Call_Camera: String { return self._s[2427]! }
    public var GroupInfo_InviteLink_RevokeAlert_Text: String { return self._s[2428]! }
    public var Group_Location_Info: String { return self._s[2429]! }
    public var Watch_LastSeen_WithinAMonth: String { return self._s[2430]! }
    public var UserInfo_NotificationsDefaultEnabled: String { return self._s[2431]! }
    public func DialogList_PinLimitError(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2432]!, self._r[2432]!, [_0])
    }
    public var Weekday_Yesterday: String { return self._s[2433]! }
    public var TwoStepAuth_SetupPasswordEnterPasswordNew: String { return self._s[2434]! }
    public var InviteLink_Create_UsersLimit: String { return self._s[2435]! }
    public func Notification_VoiceChatScheduledTodayChannel(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2436]!, self._r[2436]!, [_0])
    }
    public var ArchivedPacksAlert_Title: String { return self._s[2437]! }
    public var PeerInfo_PaneMembers: String { return self._s[2438]! }
    public var PhotoEditor_SelectCoverFrame: String { return self._s[2439]! }
    public func Location_ProximityAlertSetTextGroup(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2440]!, self._r[2440]!, [_0])
    }
    public var ContactInfo_PhoneLabelMain: String { return self._s[2441]! }
    public func Time_PreciseDate_m7(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2442]!, self._r[2442]!, [_1, _2, _3])
    }
    public var TwoFactorSetup_EmailVerification_ChangeAction: String { return self._s[2443]! }
    public var Channel_DiscussionGroup: String { return self._s[2444]! }
    public var EditTheme_Edit_Preview_IncomingReplyName: String { return self._s[2445]! }
    public var InviteLink_Create_TimeLimit: String { return self._s[2447]! }
    public var Channel_EditAdmin_PermissionsHeader: String { return self._s[2448]! }
    public var VoiceOver_MessageContextForward: String { return self._s[2449]! }
    public var SocksProxySetup_TypeNone: String { return self._s[2450]! }
    public var CreatePoll_MultipleChoiceQuizAlert: String { return self._s[2452]! }
    public var ProfilePhoto_OpenInEditor: String { return self._s[2454]! }
    public var WallpaperSearch_ColorPurple: String { return self._s[2455]! }
    public var ChatListFolder_IncludeChatsTitle: String { return self._s[2456]! }
    public var Group_Username_InvalidTooShort: String { return self._s[2457]! }
    public var Location_ProximityNotification_DistanceM: String { return self._s[2458]! }
    public var VoiceChat_EditTitleText: String { return self._s[2459]! }
    public func Login_EmailPhoneBody(_ _0: String, _ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2460]!, self._r[2460]!, [_0, _1, _2])
    }
    public var Passport_Language_tk: String { return self._s[2461]! }
    public var ConvertToSupergroup_Title: String { return self._s[2462]! }
    public var Channel_BanUser_PermissionEmbedLinks: String { return self._s[2463]! }
    public var Cache_KeepMediaHelp: String { return self._s[2464]! }
    public var Channel_Management_Title: String { return self._s[2465]! }
    public func PUSH_MESSAGE_PHOTO_SECRET(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2466]!, self._r[2466]!, [_1])
    }
    public var Conversation_ForwardChats: String { return self._s[2467]! }
    public var Passport_Language_bg: String { return self._s[2468]! }
    public var SocksProxySetup_TypeSocks: String { return self._s[2469]! }
    public var Permissions_PrivacyPolicy: String { return self._s[2470]! }
    public var VoiceOver_Chat_YourMusic: String { return self._s[2471]! }
    public var SettingsSearch_Synonyms_Notifications_ResetAllNotifications: String { return self._s[2472]! }
    public var Conversation_EmptyGifPanelPlaceholder: String { return self._s[2473]! }
    public var Conversation_ContextMenuOpenChannel: String { return self._s[2474]! }
    public var Report_AdditionalDetailsPlaceholder: String { return self._s[2475]! }
    public var Activity_UploadingVideo: String { return self._s[2476]! }
    public var PrivacyPolicy_AgeVerificationAgree: String { return self._s[2478]! }
    public var Widget_LongTapToEdit: String { return self._s[2479]! }
    public var VoiceChat_InviteLink_Listener: String { return self._s[2481]! }
    public var SocksProxySetup_Credentials: String { return self._s[2482]! }
    public var Preview_SaveGif: String { return self._s[2483]! }
    public var Cache_Photos: String { return self._s[2484]! }
    public var Channel_AdminLogFilter_EventsCalls: String { return self._s[2485]! }
    public var Conversation_ContextMenuCancelEditing: String { return self._s[2486]! }
    public var Contacts_FailedToSendInvitesMessage: String { return self._s[2487]! }
    public func VoiceChat_RemoveAndBanPeerConfirmation(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2488]!, self._r[2488]!, [_1, _2])
    }
    public var Passport_Language_lt: String { return self._s[2489]! }
    public var Passport_DeleteDocument: String { return self._s[2491]! }
    public var GroupInfo_SetGroupPhotoStop: String { return self._s[2492]! }
    public func Location_ProximityNotification_NotifyLong(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2493]!, self._r[2493]!, [_1, _2])
    }
    public var AccessDenied_VideoMessageMicrophone: String { return self._s[2494]! }
    public func PeopleNearby_VisibleUntil(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2495]!, self._r[2495]!, [_0])
    }
    public var AccessDenied_VideoCallCamera: String { return self._s[2496]! }
    public func Channel_AdminLog_MessageDeleted(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2497]!, self._r[2497]!, [_0])
    }
    public var PhotoEditor_SharpenTool: String { return self._s[2498]! }
    public func PUSH_CHANNEL_MESSAGE_AUDIO(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2499]!, self._r[2499]!, [_1])
    }
    public var DialogList_Unpin: String { return self._s[2500]! }
    public var Stickers_NoStickersFound: String { return self._s[2501]! }
    public var UserInfo_AddContact: String { return self._s[2503]! }
    public func AddContact_SharedContactExceptionInfo(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2505]!, self._r[2505]!, [_0])
    }
    public func Notification_PinnedLocationMessage(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2506]!, self._r[2506]!, [_0])
    }
    public var CallFeedback_VideoReasonDistorted: String { return self._s[2507]! }
    public var Tour_Text2: String { return self._s[2508]! }
    public func Conversation_TitleCommentsFormat(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2510]!, self._r[2510]!, [_1, _2])
    }
    public var InviteLink_DeleteAllRevokedLinksAlert_Text: String { return self._s[2512]! }
    public var Paint_Delete: String { return self._s[2513]! }
    public func Call_VoiceChatInProgressMessage(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2514]!, self._r[2514]!, [_1, _2])
    }
    public var SettingsSearch_Synonyms_Notifications_InAppNotificationsVibrate: String { return self._s[2515]! }
    public func PrivacySettings_LastSeenEverybodyMinus(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2517]!, self._r[2517]!, [_0])
    }
    public var Privacy_Calls_NeverAllow_Title: String { return self._s[2518]! }
    public var Notification_CallOutgoingShort: String { return self._s[2519]! }
    public var Checkout_PasswordEntry_Title: String { return self._s[2520]! }
    public var Channel_AdminLogFilter_AdminsAll: String { return self._s[2521]! }
    public var Notification_MessageLifetime1m: String { return self._s[2522]! }
    public var BlockedUsers_AddNew: String { return self._s[2524]! }
    public var FastTwoStepSetup_EmailSection: String { return self._s[2525]! }
    public var Settings_SaveEditedPhotos: String { return self._s[2526]! }
    public var GroupInfo_GroupNamePlaceholder: String { return self._s[2527]! }
    public var Channel_AboutItem: String { return self._s[2528]! }
    public var GroupInfo_InviteLink_RevokeLink: String { return self._s[2529]! }
    public var Privacy_Calls_P2PNever: String { return self._s[2531]! }
    public var Passport_Language_uk: String { return self._s[2532]! }
    public var NetworkUsageSettings_Wifi: String { return self._s[2533]! }
    public var Conversation_Moderate_Report: String { return self._s[2534]! }
    public var Wallpaper_ResetWallpapersConfirmation: String { return self._s[2535]! }
    public var VoiceOver_Chat_SeenByRecipients: String { return self._s[2536]! }
    public var Permissions_SiriText_v0: String { return self._s[2537]! }
    public var Theme_Colors_Background: String { return self._s[2538]! }
    public var Notification_CallMissed: String { return self._s[2539]! }
    public var Stats_ZoomOut: String { return self._s[2540]! }
    public var Profile_AddToExisting: String { return self._s[2541]! }
    public var Passport_FieldAddressUploadHelp: String { return self._s[2544]! }
    public var VoiceChat_RemovePeerRemove: String { return self._s[2545]! }
    public var Undo_DeletedChannel: String { return self._s[2546]! }
    public func Channel_AdminLog_MessagePinned(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2547]!, self._r[2547]!, [_0])
    }
    public var Login_ResetAccountProtected_TimerTitle: String { return self._s[2548]! }
    public var Map_LiveLocationGroupDescription: String { return self._s[2549]! }
    public var Passport_InfoFAQ_URL: String { return self._s[2550]! }
    public var IntentsSettings_SuggestedChats: String { return self._s[2553]! }
    public func PUSH_MESSAGE_DOC(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2554]!, self._r[2554]!, [_1])
    }
    public var State_connecting: String { return self._s[2555]! }
    public var Passport_Identity_Country: String { return self._s[2556]! }
    public var Passport_PasswordDescription: String { return self._s[2557]! }
    public var ChatList_PsaLabel_covid: String { return self._s[2558]! }
    public func PUSH_MESSAGE(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2559]!, self._r[2559]!, [_1])
    }
    public var Contacts_AddPeopleNearby: String { return self._s[2560]! }
    public var OwnershipTransfer_SetupTwoStepAuth: String { return self._s[2561]! }
    public var ClearCache_Description: String { return self._s[2562]! }
    public var Localization_LanguageName: String { return self._s[2563]! }
    public func UserInfo_UnblockConfirmation(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2564]!, self._r[2564]!, [_0])
    }
    public var Conversation_AddMembers: String { return self._s[2565]! }
    public var ChatList_TabIconFoldersTooltipEmptyFolders: String { return self._s[2566]! }
    public var UserInfo_CreateNewContact: String { return self._s[2567]! }
    public var Channel_Stickers_NotFound: String { return self._s[2569]! }
    public var Message_FakeAccount: String { return self._s[2570]! }
    public var Watch_Message_Poll: String { return self._s[2571]! }
    public var Group_Members_Title: String { return self._s[2572]! }
    public var Privacy_Forwards_WhoCanForward: String { return self._s[2573]! }
    public func Notification_Kicked(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2574]!, self._r[2574]!, [_0, _1])
    }
    public var VoiceChat_CancelConfirmationText: String { return self._s[2575]! }
    public var BroadcastGroups_Convert: String { return self._s[2576]! }
    public var Login_InfoDeletePhoto: String { return self._s[2577]! }
    public var Appearance_ThemePreview_ChatList_6_Name: String { return self._s[2578]! }
    public var InstantPage_FeedbackButton: String { return self._s[2579]! }
    public var Appearance_PreviewReplyText: String { return self._s[2580]! }
    public var Passport_FieldPhoneHelp: String { return self._s[2581]! }
    public var Group_ErrorAddTooMuchBots: String { return self._s[2582]! }
    public var Media_SendingOptionsTooltip: String { return self._s[2583]! }
    public var ScheduledMessages_ScheduledOnline: String { return self._s[2584]! }
    public var Notifications_Badge: String { return self._s[2585]! }
    public var VoiceOver_Chat_VideoMessage: String { return self._s[2586]! }
    public var TwoStepAuth_RecoveryCodeExpired: String { return self._s[2587]! }
    public func Notification_PinnedPhotoMessage(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2589]!, self._r[2589]!, [_0])
    }
    public var Passport_InfoLearnMore: String { return self._s[2590]! }
    public var EnterPasscode_EnterTitle: String { return self._s[2591]! }
    public var Appearance_EditTheme: String { return self._s[2592]! }
    public var EditTheme_Expand_BottomInfo: String { return self._s[2593]! }
    public var Stats_FollowersTitle: String { return self._s[2594]! }
    public var Passport_Identity_SurnamePlaceholder: String { return self._s[2595]! }
    public var Channel_Subscribers_Title: String { return self._s[2596]! }
    public var Group_ErrorSupergroupConversionNotPossible: String { return self._s[2597]! }
    public var ChatImportActivity_ErrorGeneric: String { return self._s[2598]! }
    public var EditTheme_ThemeTemplateAlertTitle: String { return self._s[2599]! }
    public var EditTheme_Create_Preview_IncomingText: String { return self._s[2600]! }
    public var Conversation_AddToReadingList: String { return self._s[2601]! }
    public var VoiceChat_EditBioPlaceholder: String { return self._s[2602]! }
    public func Notifications_ExceptionsChangeSound(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2603]!, self._r[2603]!, [_0])
    }
    public var Group_AdminLog_EmptyText: String { return self._s[2604]! }
    public var Passport_Identity_EditInternalPassport: String { return self._s[2605]! }
    public var Watch_Location_Current: String { return self._s[2606]! }
    public var PrivacyPolicy_Title: String { return self._s[2607]! }
    public var Privacy_GroupsAndChannels_CustomHelp: String { return self._s[2614]! }
    public var Channel_TypeSetup_Title: String { return self._s[2618]! }
    public var Appearance_PreviewReplyAuthor: String { return self._s[2619]! }
    public var Passport_Language_ja: String { return self._s[2620]! }
    public var ReportPeer_ReasonSpam: String { return self._s[2621]! }
    public var Widget_GalleryDescription: String { return self._s[2622]! }
    public var Privacy_PaymentsClearInfoHelp: String { return self._s[2623]! }
    public var VoiceChat_ChangePhoto: String { return self._s[2625]! }
    public var Conversation_EditingMessageMediaEditCurrentPhoto: String { return self._s[2626]! }
    public var Channel_AdminLog_ChangeInfo: String { return self._s[2627]! }
    public var ChatListFolder_NameNonContacts: String { return self._s[2628]! }
    public func InviteLink_ExpiresIn(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2629]!, self._r[2629]!, [_0])
    }
    public var Call_Audio: String { return self._s[2630]! }
    public var PhotoEditor_CurvesGreen: String { return self._s[2631]! }
    public var ChatList_Search_NoResultsFitlerFiles: String { return self._s[2632]! }
    public var Settings_PrivacySettings: String { return self._s[2633]! }
    public var InviteLink_UsageLimitReached: String { return self._s[2634]! }
    public var Stats_Followers: String { return self._s[2635]! }
    public var Notifications_AddExceptionTitle: String { return self._s[2636]! }
    public var TwoFactorSetup_Password_Title: String { return self._s[2637]! }
    public var ChannelMembers_WhoCanAddMembersAllHelp: String { return self._s[2638]! }
    public var OldChannels_NoticeText: String { return self._s[2639]! }
    public var Conversation_SavedMessages: String { return self._s[2640]! }
    public var Intents_ErrorLockedText: String { return self._s[2641]! }
    public func Conversation_PeerNearbyTitle(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2643]!, self._r[2643]!, [_1, _2])
    }
    public var Passport_Address_TypeResidentialAddress: String { return self._s[2644]! }
    public var Appearance_ThemeNightBlue: String { return self._s[2645]! }
    public var Notification_ChannelInviterSelf: String { return self._s[2646]! }
    public var Conversation_ForwardTooltip_SavedMessages_Many: String { return self._s[2647]! }
    public var InviteLink_Create_TimeLimitExpiryDateNever: String { return self._s[2649]! }
    public var Watch_UserInfo_Service: String { return self._s[2650]! }
    public var ChatList_Context_Back: String { return self._s[2651]! }
    public var Passport_Email_Title: String { return self._s[2652]! }
    public var Stats_GroupTopAdmin_Promote: String { return self._s[2653]! }
    public func PUSH_PINNED_INVOICE(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2654]!, self._r[2654]!, [_1])
    }
    public var Conversation_UnsupportedMedia: String { return self._s[2655]! }
    public var Passport_Address_OneOfTypePassportRegistration: String { return self._s[2656]! }
    public var Privacy_TopPeersHelp: String { return self._s[2658]! }
    public var Privacy_Forwards_AlwaysLink: String { return self._s[2659]! }
    public var Notifications_Badge_CountUnreadMessages_InfoOn: String { return self._s[2660]! }
    public var Permissions_NotificationsTitle_v0: String { return self._s[2661]! }
    public func Location_ProximityNotification_AlreadyClose(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2662]!, self._r[2662]!, [_0])
    }
    public var Notification_PassportValueProofOfAddress: String { return self._s[2663]! }
    public var Map_Map: String { return self._s[2664]! }
    public var WallpaperSearch_ColorBlue: String { return self._s[2665]! }
    public var Privacy_Calls_CustomShareHelp: String { return self._s[2666]! }
    public var PhotoEditor_BlurToolRadial: String { return self._s[2667]! }
    public var ChatList_Search_FilterMusic: String { return self._s[2668]! }
    public var SettingsSearch_Synonyms_Data_AutoplayGifs: String { return self._s[2669]! }
    public var Privacy_PaymentsClear_ShippingInfo: String { return self._s[2670]! }
    public var Settings_LogoutConfirmationTitle: String { return self._s[2672]! }
    public func PUSH_CHANNEL_MESSAGE_VIDEOS(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2673]!, self._r[2673]!, [_1, _2])
    }
    public func Notification_ChangedGroupPhoto(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2674]!, self._r[2674]!, [_0])
    }
    public var Channel_Username_RevokeExistingUsernamesInfo: String { return self._s[2675]! }
    public var Group_Username_CreatePublicLinkHelp: String { return self._s[2676]! }
    public var VoiceOver_ChatList_MessageEmpty: String { return self._s[2678]! }
    public var GroupInfo_Location: String { return self._s[2679]! }
    public var Passport_Language_ka: String { return self._s[2680]! }
    public func TwoStepAuth_SetupPendingEmail(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2681]!, self._r[2681]!, [_0])
    }
    public var Conversation_ContextMenuOpenChannelProfile: String { return self._s[2682]! }
    public var ChatImport_SelectionConfirmationAlertTitle: String { return self._s[2684]! }
    public var ScheduledMessages_ClearAllConfirmation: String { return self._s[2686]! }
    public var DialogList_SearchSectionRecent: String { return self._s[2687]! }
    public var Passport_Address_OneOfTypeTemporaryRegistration: String { return self._s[2688]! }
    public var Conversation_Timer_Send: String { return self._s[2689]! }
    public func VoiceOver_ScrollStatus(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2691]!, self._r[2691]!, [_1, _2])
    }
    public var ChatState_Updating: String { return self._s[2692]! }
    public var ChannelMembers_WhoCanAddMembers: String { return self._s[2693]! }
    public var ChannelInfo_DeleteGroup: String { return self._s[2694]! }
    public var TwoStepAuth_RecoveryFailed: String { return self._s[2695]! }
    public var Channel_OwnershipTransfer_EnterPassword: String { return self._s[2696]! }
    public var InviteLink_Create_TimeLimitExpiryTime: String { return self._s[2697]! }
    public var ChannelInfo_InviteLink_RevokeAlert_Text: String { return self._s[2698]! }
    public var ChatList_Search_NoResults: String { return self._s[2699]! }
    public var ChatListFolderSettings_AddRecommended: String { return self._s[2701]! }
    public var ChangePhoneNumberCode_Called: String { return self._s[2702]! }
    public var PeerInfo_GroupAboutItem: String { return self._s[2703]! }
    public var VoiceOver_SelfDestructTimerOff: String { return self._s[2705]! }
    public func Channel_AdminLog_DeletedInviteLink(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2706]!, self._r[2706]!, [_1, _2])
    }
    public func LiveLocationUpdated_YesterdayAt(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2707]!, self._r[2707]!, [_0])
    }
    public var PrivacySettings_AuthSessions: String { return self._s[2708]! }
    public var Passport_Address_Postcode: String { return self._s[2709]! }
    public var VoiceOver_Chat_YourVideoMessage: String { return self._s[2710]! }
    public func VoiceChat_ForwardTooltip_ManyChats(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2711]!, self._r[2711]!, [_0, _1])
    }
    public var Passport_Address_Street2Placeholder: String { return self._s[2712]! }
    public var Group_Location_Title: String { return self._s[2713]! }
    public var SettingsSearch_Synonyms_Data_AutoDownloadReset: String { return self._s[2714]! }
    public var PeopleNearby_UsersEmpty: String { return self._s[2715]! }
    public var Conversation_ContextMenuSpeak: String { return self._s[2717]! }
    public var SettingsSearch_Synonyms_Data_Title: String { return self._s[2718]! }
    public func Checkout_PasswordEntry_Text(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2720]!, self._r[2720]!, [_0])
    }
    public var Proxy_TooltipUnavailable: String { return self._s[2721]! }
    public var Map_Search: String { return self._s[2722]! }
    public var VoiceChat_CancelConfirmationTitle: String { return self._s[2723]! }
    public var AutoDownloadSettings_TypeContacts: String { return self._s[2724]! }
    public var Conversation_SearchByName_Prefix: String { return self._s[2725]! }
    public func Channel_AdminLog_MessageToggleSignaturesOff(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2726]!, self._r[2726]!, [_0])
    }
    public var TwoStepAuth_EmailAddSuccess: String { return self._s[2727]! }
    public var ProfilePhoto_MainPhoto: String { return self._s[2728]! }
    public var SettingsSearch_Synonyms_Notifications_InAppNotificationsSound: String { return self._s[2729]! }
    public var SharedMedia_EmptyMusicText: String { return self._s[2730]! }
    public var ChatSettings_AutoDownloadPhotos: String { return self._s[2731]! }
    public var NetworkUsageSettings_BytesReceived: String { return self._s[2732]! }
    public var Channel_AdminLog_EmptyText: String { return self._s[2733]! }
    public var Channel_BanUser_PermissionSendMessages: String { return self._s[2734]! }
    public var Undo_ChatDeletedForBothSides: String { return self._s[2735]! }
    public var Notifications_GroupNotifications: String { return self._s[2736]! }
    public var AccessDenied_SaveMedia: String { return self._s[2737]! }
    public var InviteLink_Create_Revoke: String { return self._s[2738]! }
    public var GroupInfo_LabelOwner: String { return self._s[2739]! }
    public var Passport_Language_id: String { return self._s[2741]! }
    public var ChatSettings_AutoDownloadTitle: String { return self._s[2742]! }
    public var Conversation_UnpinMessageAlert: String { return self._s[2743]! }
    public func LiveLocationUpdated_TodayAt(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2744]!, self._r[2744]!, [_0])
    }
    public func Call_RemoteVideoPaused(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2745]!, self._r[2745]!, [_0])
    }
    public var TwoFactorSetup_Done_Text: String { return self._s[2746]! }
    public func LastSeen_AtDate(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2747]!, self._r[2747]!, [_0])
    }
    public var NetworkUsageSettings_BytesSent: String { return self._s[2748]! }
    public var Conversation_AudioRateTooltipNormal: String { return self._s[2749]! }
    public var VoiceChat_EditDescriptionSuccess: String { return self._s[2750]! }
    public var OwnershipTransfer_Transfer: String { return self._s[2751]! }
    public func Notification_Exceptions_Sound(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2752]!, self._r[2752]!, [_0])
    }
    public var Passport_Language_pt: String { return self._s[2753]! }
    public var PrivacySettings_WebSessions: String { return self._s[2754]! }
    public var PrivacyPolicy_DeclineDeleteNow: String { return self._s[2756]! }
    public var TwoFactorSetup_Hint_Title: String { return self._s[2757]! }
    public func Notification_Joined(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2758]!, self._r[2758]!, [_0])
    }
    public var Group_Username_RemoveExistingUsernamesInfo: String { return self._s[2759]! }
    public var PrivacyLastSeenSettings_CustomShareSettings_Delete: String { return self._s[2760]! }
    public var AutoNightTheme_Scheduled: String { return self._s[2761]! }
    public var CreatePoll_ExplanationHeader: String { return self._s[2762]! }
    public var Calls_TabTitle: String { return self._s[2763]! }
    public var VoiceChat_RecordingInProgress: String { return self._s[2764]! }
    public var ChatList_UndoArchiveHiddenText: String { return self._s[2765]! }
    public var Notification_VideoCallCanceled: String { return self._s[2766]! }
    public var Login_CodeSentInternal: String { return self._s[2767]! }
    public var SettingsSearch_Synonyms_Proxy_AddProxy: String { return self._s[2768]! }
    public var Call_RecordingDisabledMessage: String { return self._s[2770]! }
    public func VoiceChat_RemovedPeerText(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2771]!, self._r[2771]!, [_0])
    }
    public var Conversation_UsersTooMuchError: String { return self._s[2773]! }
    public var AutoDownloadSettings_TypeChannels: String { return self._s[2774]! }
    public var Channel_Info_Stickers: String { return self._s[2775]! }
    public var Passport_DeleteAddressConfirmation: String { return self._s[2776]! }
    public func Conversation_PeerNearbyDistance(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2777]!, self._r[2777]!, [_1, _2])
    }
    public var ChannelMembers_WhoCanAddMembers_Admins: String { return self._s[2778]! }
    public func Call_StatusOngoing(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2779]!, self._r[2779]!, [_0])
    }
    public var Passport_DiscardMessageTitle: String { return self._s[2780]! }
    public var Call_VoiceOver_VideoCallIncoming: String { return self._s[2781]! }
    public var Localization_LanguageOther: String { return self._s[2782]! }
    public var Conversation_EncryptionCanceled: String { return self._s[2783]! }
    public var ChatSettings_AutomaticPhotoDownload: String { return self._s[2784]! }
    public var ReportPeer_ReasonFake: String { return self._s[2786]! }
    public func Notification_SecretChatMessageScreenshot(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2787]!, self._r[2787]!, [_0])
    }
    public var Target_InviteToGroupErrorAlreadyInvited: String { return self._s[2789]! }
    public var SocksProxySetup_SavedProxies: String { return self._s[2790]! }
    public var InviteLink_Create_UsersLimitNumberOfUsers: String { return self._s[2791]! }
    public func ApplyLanguage_ChangeLanguageAlreadyActive(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2792]!, self._r[2792]!, [_1])
    }
    public var Conversation_ScamWarning: String { return self._s[2794]! }
    public var Channel_AdminLog_InfoPanelAlertTitle: String { return self._s[2795]! }
    public var LocalGroup_Title: String { return self._s[2796]! }
    public var SettingsSearch_Synonyms_Notifications_MessageNotificationsAlert: String { return self._s[2798]! }
    public var SettingsSearch_Synonyms_Privacy_PasscodeAndFaceId: String { return self._s[2799]! }
    public var VoiceChat_SelectAccount: String { return self._s[2800]! }
    public var Login_PhoneFloodError: String { return self._s[2801]! }
    public var Conversation_PinMessageAlert_PinAndNotifyMembers: String { return self._s[2802]! }
    public var Username_InvalidTaken: String { return self._s[2804]! }
    public var SocksProxySetup_AddProxy: String { return self._s[2806]! }
    public var PrivacyLastSeenSettings_WhoCanSeeMyTimestamp: String { return self._s[2807]! }
    public var MediaPicker_UngroupDescription: String { return self._s[2808]! }
    public var Login_CodeExpired: String { return self._s[2809]! }
    public var Localization_ChooseLanguage: String { return self._s[2810]! }
    public var Checkout_NewCard_PostcodePlaceholder: String { return self._s[2811]! }
    public func ChangePhone_ErrorOccupied(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2812]!, self._r[2812]!, [_0])
    }
    public func Channel_DiscussionGroup_HeaderSet(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2813]!, self._r[2813]!, [_0])
    }
    public var ReportPeer_ReasonOther_Title: String { return self._s[2815]! }
    public var Conversation_ScheduleMessage_Title: String { return self._s[2816]! }
    public func VoiceChat_UserInvited(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2817]!, self._r[2817]!, [_0])
    }
    public var PeerInfo_ButtonDiscuss: String { return self._s[2818]! }
    public var SettingsSearch_Synonyms_Notifications_BadgeIncludeMutedPublicGroups: String { return self._s[2819]! }
    public var Call_StatusNoAnswer: String { return self._s[2820]! }
    public var ScheduledMessages_DeleteMany: String { return self._s[2822]! }
    public var Channel_DiscussionGroupInfo: String { return self._s[2823]! }
    public var Conversation_UnarchiveDone: String { return self._s[2824]! }
    public var LogoutOptions_AddAccountText: String { return self._s[2825]! }
    public var Message_PinnedContactMessage: String { return self._s[2826]! }
    public func ChatList_DeleteAndLeaveGroupConfirmation(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2827]!, self._r[2827]!, [_0])
    }
    public var VoiceChat_EditBioTitle: String { return self._s[2829]! }
    public func FileSize_GB(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2830]!, self._r[2830]!, [_0])
    }
    public var Stats_GroupLanguagesTitle: String { return self._s[2831]! }
    public var Passport_FieldAddressHelp: String { return self._s[2832]! }
    public func Passport_FieldOneOf_Or(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2833]!, self._r[2833]!, [_1, _2])
    }
    public var ChatSettings_OpenLinksIn: String { return self._s[2835]! }
    public var TwoFactorSetup_Hint_SkipAction: String { return self._s[2836]! }
    public var Message_Photo: String { return self._s[2837]! }
    public var Media_LimitedAccessManage: String { return self._s[2839]! }
    public var MediaPicker_AddCaption: String { return self._s[2840]! }
    public var LogoutOptions_Title: String { return self._s[2841]! }
    public func PUSH_PINNED_GIF(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2842]!, self._r[2842]!, [_1])
    }
    public var Conversation_StatusKickedFromGroup: String { return self._s[2843]! }
    public var Channel_AdminLogFilter_AdminsTitle: String { return self._s[2844]! }
    public var ChatList_DeleteSavedMessagesConfirmationTitle: String { return self._s[2845]! }
    public var Channel_AdminLogFilter_Title: String { return self._s[2846]! }
    public var Passport_Address_TypeRentalAgreementUploadScan: String { return self._s[2847]! }
    public var Compose_GroupTokenListPlaceholder: String { return self._s[2848]! }
    public var Notifications_MessageNotificationsExceptions: String { return self._s[2849]! }
    public var ChannelIntro_Title: String { return self._s[2850]! }
    public var Stats_Message_Views: String { return self._s[2851]! }
    public var Stickers_Install: String { return self._s[2852]! }
    public func VoiceOver_Chat_FileFrom(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2853]!, self._r[2853]!, [_0])
    }
    public var EditTheme_Create_Preview_IncomingReplyText: String { return self._s[2854]! }
    public var Conversation_SwipeToReplyHintTitle: String { return self._s[2856]! }
    public var Settings_Username: String { return self._s[2859]! }
    public var FastTwoStepSetup_Title: String { return self._s[2860]! }
    public var Notifications_Badge_CountUnreadMessages_InfoOff: String { return self._s[2861]! }
    public var SettingsSearch_Synonyms_Privacy_Title: String { return self._s[2862]! }
    public var Passport_Identity_IssueDatePlaceholder: String { return self._s[2864]! }
    public var CallFeedback_ReasonEcho: String { return self._s[2865]! }
    public func Time_MonthOfYear_m1(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2866]!, self._r[2866]!, [_0])
    }
    public var Conversation_OpenBotLinkTitle: String { return self._s[2867]! }
    public var SocksProxySetup_Title: String { return self._s[2868]! }
    public var CallFeedback_Success: String { return self._s[2869]! }
    public var WallpaperPreview_SwipeTopText: String { return self._s[2871]! }
    public var InstantPage_AutoNightTheme: String { return self._s[2873]! }
    public var Watch_Conversation_Reply: String { return self._s[2874]! }
    public var VoiceChat_Share: String { return self._s[2876]! }
    public var VoiceChat_AddPhoto: String { return self._s[2877]! }
    public var Chat_PanelUnpinAllMessages: String { return self._s[2878]! }
    public var WallpaperPreview_Pattern: String { return self._s[2879]! }
    public var CheckoutInfo_ReceiverInfoEmail: String { return self._s[2880]! }
    public func Conversation_DeleteMessagesFor(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2881]!, self._r[2881]!, [_0])
    }
    public var AutoDownloadSettings_TypeGroupChats: String { return self._s[2882]! }
    public var VoiceOver_Chat_GroupInfo: String { return self._s[2883]! }
    public var DialogList_SavedMessagesTooltip: String { return self._s[2885]! }
    public var Update_Title: String { return self._s[2886]! }
    public var Conversation_ShareMyPhoneNumber: String { return self._s[2887]! }
    public var WallpaperPreview_CropTopText: String { return self._s[2890]! }
    public var Channel_EditMessageErrorGeneric: String { return self._s[2891]! }
    public var AccessDenied_LocationAlwaysDenied: String { return self._s[2892]! }
    public var ChatListFolder_DiscardCancel: String { return self._s[2893]! }
    public var Message_PinnedPhotoMessage: String { return self._s[2894]! }
    public var Appearance_ThemeDayClassic: String { return self._s[2895]! }
    public var VoiceChat_ChangeName: String { return self._s[2896]! }
    public var SocksProxySetup_ProxySocks5: String { return self._s[2898]! }
    public var VoiceChat_DisplayAsInfo: String { return self._s[2900]! }
    public var AccessDenied_Wallpapers: String { return self._s[2905]! }
    public func Channel_AdminLog_MessageChangedGroupAbout(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2906]!, self._r[2906]!, [_0])
    }
    public var Weekday_Sunday: String { return self._s[2907]! }
    public var SettingsSearch_Synonyms_Privacy_GroupsAndChannels: String { return self._s[2909]! }
    public var PeopleNearby_MakeVisibleDescription: String { return self._s[2910]! }
    public var AccessDenied_LocationDisabled: String { return self._s[2911]! }
    public var Tour_Text3: String { return self._s[2912]! }
    public var AuthSessions_AddDevice_ScanTitle: String { return self._s[2913]! }
    public func Time_TodayAt(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2914]!, self._r[2914]!, [_0])
    }
    public var Privacy_SecretChatsLinkPreviewsHelp: String { return self._s[2915]! }
    public var Conversation_ClearCache: String { return self._s[2916]! }
    public var StickerPacksSettings_ArchivedMasks_Info: String { return self._s[2917]! }
    public var ChatList_Tabs_AllChats: String { return self._s[2918]! }
    public var DialogList_RecentTitlePeople: String { return self._s[2919]! }
    public var Stickers_AddToFavorites: String { return self._s[2920]! }
    public var ChatList_Context_RemoveFromFolder: String { return self._s[2921]! }
    public var VoiceChat_CancelSpeakRequest: String { return self._s[2922]! }
    public var Settings_RemoveVideo: String { return self._s[2923]! }
    public var PhotoEditor_CropAspectRatioSquare: String { return self._s[2924]! }
    public var ConversationProfile_LeaveDeleteAndExit: String { return self._s[2925]! }
    public var VoiceOver_Chat_YourFile: String { return self._s[2926]! }
    public var SettingsSearch_Synonyms_Privacy_Forwards: String { return self._s[2928]! }
    public var Group_OwnershipTransfer_ErrorPrivacyRestricted: String { return self._s[2929]! }
    public var VoiceChat_TapToAddBio: String { return self._s[2930]! }
    public var Channel_AdminLog_AddMembers: String { return self._s[2931]! }
    public var Map_SendThisLocation: String { return self._s[2933]! }
    public var TwoStepAuth_EmailSkipAlert: String { return self._s[2935]! }
    public var IntentsSettings_SuggestedChatsPrivateChats: String { return self._s[2936]! }
    public var CloudStorage_Title: String { return self._s[2937]! }
    public var TwoFactorSetup_Password_Action: String { return self._s[2938]! }
    public var TwoStepAuth_ConfirmationText: String { return self._s[2939]! }
    public var Passport_Address_EditTemporaryRegistration: String { return self._s[2941]! }
    public var Undo_LeftGroup: String { return self._s[2942]! }
    public var Conversation_StopLiveLocation: String { return self._s[2943]! }
    public var NotificationSettings_ShowNotificationsFromAccountsSection: String { return self._s[2944]! }
    public var Message_PinnedInvoice: String { return self._s[2945]! }
    public var ApplyLanguage_LanguageNotSupportedError: String { return self._s[2946]! }
    public func PUSH_CHAT_MESSAGE(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2948]!, self._r[2948]!, [_1, _2])
    }
    public func Notification_PinnedAudioMessage(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2949]!, self._r[2949]!, [_0])
    }
    public var Weekday_Tuesday: String { return self._s[2950]! }
    public var ChangePhoneNumberCode_Code: String { return self._s[2951]! }
    public var VoiceOver_Chat_YourMessage: String { return self._s[2952]! }
    public var Calls_CallTabDescription: String { return self._s[2953]! }
    public var ChatImport_SelectionErrorNotAdmin: String { return self._s[2954]! }
    public var SocksProxySetup_UseProxy: String { return self._s[2956]! }
    public var SettingsSearch_Synonyms_Stickers_Title: String { return self._s[2957]! }
    public var PasscodeSettings_AlphanumericCode: String { return self._s[2958]! }
    public var VoiceOver_Chat_YourVideo: String { return self._s[2959]! }
    public var ChannelMembers_WhoCanAddMembersAdminsHelp: String { return self._s[2961]! }
    public var SettingsSearch_Synonyms_Privacy_DeleteAccountIfAwayFor: String { return self._s[2962]! }
    public var Exceptions_AddToExceptions: String { return self._s[2963]! }
    public var UserInfo_Title: String { return self._s[2964]! }
    public var Passport_DeleteDocumentConfirmation: String { return self._s[2966]! }
    public var VoiceChat_EditDescription: String { return self._s[2968]! }
    public var ChatList_Unmute: String { return self._s[2969]! }
    public var SettingsSearch_Synonyms_Privacy_Data_ContactsSync: String { return self._s[2970]! }
    public func Channel_AdminLog_MessageChangedAutoremoveTimeoutSet(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2971]!, self._r[2971]!, [_1, _2])
    }
    public var Stats_GroupTopPostersTitle: String { return self._s[2972]! }
    public var Username_CheckingUsername: String { return self._s[2974]! }
    public var WallpaperColors_SetCustomColor: String { return self._s[2975]! }
    public var PeerSelection_ImportIntoNewGroup: String { return self._s[2979]! }
    public var Location_ProximityAlertSetTitle: String { return self._s[2980]! }
    public var AuthSessions_AddedDeviceTerminate: String { return self._s[2981]! }
    public var Conversation_JoinVoiceChatAsSpeaker: String { return self._s[2982]! }
    public var Privacy_ProfilePhoto_CustomHelp: String { return self._s[2983]! }
    public var Settings_ChangePhoneNumber: String { return self._s[2984]! }
    public var PeerInfo_PaneLinks: String { return self._s[2985]! }
    public var Appearance_ThemePreview_ChatList_1_Text: String { return self._s[2988]! }
    public var Channel_EditAdmin_PermissionInviteSubscribers: String { return self._s[2990]! }
    public func PUSH_CHAT_VOICECHAT_INVITE_YOU(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2991]!, self._r[2991]!, [_1, _2])
    }
    public var LogoutOptions_ChangePhoneNumberText: String { return self._s[2992]! }
    public var VoiceOver_Media_PlaybackPause: String { return self._s[2993]! }
    public var VoiceChat_CancelConfirmationEnd: String { return self._s[2994]! }
    public var BroadcastGroups_ConfirmationAlert_Title: String { return self._s[2995]! }
    public var Stats_FollowersBySourceTitle: String { return self._s[2997]! }
    public func Conversation_ScheduleMessage_SendOn(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2998]!, self._r[2998]!, [_0, _1])
    }
    public var Compose_NewEncryptedChatTitle: String { return self._s[2999]! }
    public var Channel_CommentsGroup_Header: String { return self._s[3001]! }
    public func ShareFileTip_Text(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3005]!, self._r[3005]!, [_0])
    }
    public func PUSH_MESSAGE_AUDIO(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3006]!, self._r[3006]!, [_1])
    }
    public var Group_Setup_BasicHistoryHiddenHelp: String { return self._s[3008]! }
    public func TwoStepAuth_RecoveryEmailUnavailable(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3009]!, self._r[3009]!, [_0])
    }
    public var Conversation_ReportMessages: String { return self._s[3010]! }
    public var Conversation_OpenBotLinkOpen: String { return self._s[3011]! }
    public var VoiceOver_Chat_RecordModeVoiceMessage: String { return self._s[3012]! }
    public var PrivacySettings_LastSeen: String { return self._s[3014]! }
    public var SettingsSearch_Synonyms_Privacy_Passcode: String { return self._s[3015]! }
    public var Theme_Colors_Proceed: String { return self._s[3016]! }
    public var UserInfo_ScamBotWarning: String { return self._s[3017]! }
    public var LogoutOptions_LogOut: String { return self._s[3019]! }
    public var Conversation_SendMessage: String { return self._s[3020]! }
    public var Conversation_CancelForwardCancelForward: String { return self._s[3021]! }
    public var VoiceChat_Scheduled: String { return self._s[3023]! }
    public var Passport_Address_Region: String { return self._s[3024]! }
    public var MediaPicker_CameraRoll: String { return self._s[3026]! }
    public func VoiceOver_Chat_ForwardedFrom(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3028]!, self._r[3028]!, [_0])
    }
    public var Call_ReportSend: String { return self._s[3030]! }
    public var VoiceOver_ChatList_Message: String { return self._s[3031]! }
    public var Month_ShortJune: String { return self._s[3032]! }
    public var AutoDownloadSettings_GroupChats: String { return self._s[3033]! }
    public func Channel_AdminLog_CaptionEdited(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3036]!, self._r[3036]!, [_0])
    }
    public var TwoStepAuth_DisableSuccess: String { return self._s[3037]! }
    public var Cache_KeepMedia: String { return self._s[3038]! }
    public func Date_ChatDateHeaderYear(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3039]!, self._r[3039]!, [_1, _2, _3])
    }
    public var Appearance_LargeEmoji: String { return self._s[3040]! }
    public func Notification_NewAuthDetected(_ _1: String, _ _2: String, _ _3: String, _ _4: String, _ _5: String, _ _6: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3041]!, self._r[3041]!, [_1, _2, _3, _4, _5, _6])
    }
    public var Chat_AttachmentMultipleForwardDisabled: String { return self._s[3042]! }
    public var Call_CameraConfirmationText: String { return self._s[3043]! }
    public func AuthSessions_AppUnofficial(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3045]!, self._r[3045]!, [_0])
    }
    public var DialogList_SearchSectionChats: String { return self._s[3046]! }
    public var VoiceOver_MessageContextReport: String { return self._s[3048]! }
    public var VoiceChat_RemovePeer: String { return self._s[3049]! }
    public var ChatListFolder_ExcludeChatsTitle: String { return self._s[3050]! }
    public var InviteLink_ContextCopy: String { return self._s[3051]! }
    public var NotificationsSound_Tritone: String { return self._s[3053]! }
    public var Notifications_InAppNotificationsPreview: String { return self._s[3056]! }
    public var Stats_GroupTopAdmin_Actions: String { return self._s[3057]! }
    public var PeerInfo_AddToContacts: String { return self._s[3058]! }
    public var VoiceChat_OpenChat: String { return self._s[3059]! }
    public var AccessDenied_Title: String { return self._s[3060]! }
    public var InviteLink_QRCode_InfoChannel: String { return self._s[3061]! }
    public var Tour_Title1: String { return self._s[3062]! }
    public var VoiceOver_AttachMedia: String { return self._s[3063]! }
    public func SharedMedia_SearchNoResultsDescription(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3065]!, self._r[3065]!, [_0])
    }
    public var Chat_Gifs_SavedSectionHeader: String { return self._s[3066]! }
    public var LogoutOptions_ChangePhoneNumberTitle: String { return self._s[3067]! }
    public func Passport_Scans_ScanIndex(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3068]!, self._r[3068]!, [_0])
    }
    public var Channel_AdminLog_MessagePreviousLink: String { return self._s[3069]! }
    public var OldChannels_Title: String { return self._s[3070]! }
    public var LoginPassword_FloodError: String { return self._s[3071]! }
    public var ChatImportActivity_InProgress: String { return self._s[3073]! }
    public var Checkout_ErrorPaymentFailed: String { return self._s[3074]! }
    public func Time_MonthOfYear_m7(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3075]!, self._r[3075]!, [_0])
    }
    public var VoiceOver_Media_PlaybackPlay: String { return self._s[3078]! }
    public var Passport_CorrectErrors: String { return self._s[3080]! }
    public func PUSH_CHAT_PHOTO_EDITED(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3081]!, self._r[3081]!, [_1, _2])
    }
    public var ChatListFolderSettings_Title: String { return self._s[3082]! }
    public func AutoDownloadSettings_UpToFor(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3083]!, self._r[3083]!, [_1, _2])
    }
    public var PhotoEditor_HighlightsTool: String { return self._s[3084]! }
    public var Contacts_NotRegisteredSection: String { return self._s[3087]! }
    public func Call_VoiceChatInProgressCallMessage(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3088]!, self._r[3088]!, [_1, _2])
    }
    public func PUSH_PINNED_DOC(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3089]!, self._r[3089]!, [_1])
    }
    public var InviteLink_Create_UsersLimitInfo: String { return self._s[3090]! }
    public var User_DeletedAccount: String { return self._s[3091]! }
    public var Conversation_ViewContactDetails: String { return self._s[3092]! }
    public var Conversation_Dice_u1F3B3: String { return self._s[3093]! }
    public var WebSearch_GIFs: String { return self._s[3094]! }
    public var ChatList_DeleteSavedMessagesConfirmationAction: String { return self._s[3095]! }
    public var Appearance_PreviewOutgoingText: String { return self._s[3096]! }
    public var Calls_CallTabTitle: String { return self._s[3097]! }
    public var Call_VoiceChatInProgressTitle: String { return self._s[3098]! }
    public var Checkout_OptionalTipItem: String { return self._s[3099]! }
    public func LastSeen_YesterdayAt(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3100]!, self._r[3100]!, [_0])
    }
    public var Channel_Status: String { return self._s[3101]! }
    public var Conversation_SendMessageErrorGroupRestricted: String { return self._s[3103]! }
    public var VoiceOver_Chat_OptionSelected: String { return self._s[3104]! }
    public var SettingsSearch_Synonyms_Notifications_ChannelNotificationsAlert: String { return self._s[3105]! }
    public func ClearCache_Success(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3106]!, self._r[3106]!, [_0, _1])
    }
    public var Passport_Identity_ExpiryDateNone: String { return self._s[3108]! }
    public var Your_cards_expiration_month_is_invalid: String { return self._s[3110]! }
    public var Month_ShortDecember: String { return self._s[3111]! }
    public var Username_Help: String { return self._s[3112]! }
    public var Login_InfoAvatarAdd: String { return self._s[3113]! }
    public var Month_ShortMay: String { return self._s[3114]! }
    public var DialogList_UnknownPinLimitError: String { return self._s[3115]! }
    public var PasscodeSettings_AutoLock_IfAwayFor_5hours: String { return self._s[3116]! }
    public var TwoStepAuth_EnabledSuccess: String { return self._s[3117]! }
    public var VoiceChat_AskedToSpeak: String { return self._s[3118]! }
    public var Weekday_ShortSunday: String { return self._s[3119]! }
    public var Channel_Username_InvalidTooShort: String { return self._s[3120]! }
    public var AuthSessions_TerminateSession: String { return self._s[3121]! }
    public var Passport_Identity_FilesTitle: String { return self._s[3122]! }
    public func Notification_PinnedRoundMessage(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3123]!, self._r[3123]!, [_0])
    }
    public var PeopleNearby_MakeVisible: String { return self._s[3125]! }
    public func Conversation_RestrictedMediaTimed(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3126]!, self._r[3126]!, [_0])
    }
    public var Widget_UpdatedAt: String { return self._s[3127]! }
    public func Notification_MessageLifetimeChanged(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3128]!, self._r[3128]!, [_1, _2])
    }
    public func GroupInfo_AddParticipantConfirmation(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3129]!, self._r[3129]!, [_0])
    }
    public var PrivacyPolicy_DeclineDeclineAndDelete: String { return self._s[3130]! }
    public var Conversation_ContextMenuForward: String { return self._s[3132]! }
    public var Channel_AdminLog_CanManageCalls: String { return self._s[3133]! }
    public func PUSH_CHAT_MESSAGE_QUIZ(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3135]!, self._r[3135]!, [_1, _2, _3])
    }
    public var Notification_GroupInviterSelf: String { return self._s[3137]! }
    public var Privacy_Forwards_NeverLink: String { return self._s[3138]! }
    public var AuthSessions_CurrentSession: String { return self._s[3139]! }
    public var Passport_Address_EditPassportRegistration: String { return self._s[3140]! }
    public var ChannelInfo_DeleteChannelConfirmation: String { return self._s[3141]! }
    public var ChatSearch_ResultsTooltip: String { return self._s[3143]! }
    public var CheckoutInfo_Pay: String { return self._s[3144]! }
    public func Conversation_PinMessagesFor(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3146]!, self._r[3146]!, [_0])
    }
    public var GroupInfo_AddParticipant: String { return self._s[3147]! }
    public var GroupPermission_ApplyAlertAction: String { return self._s[3148]! }
    public func Channel_AdminLog_MessageChangedChannelUsername(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3149]!, self._r[3149]!, [_0])
    }
    public var Localization_LanguageCustom: String { return self._s[3150]! }
    public var SettingsSearch_Synonyms_Passport: String { return self._s[3151]! }
    public var Settings_UsernameEmpty: String { return self._s[3152]! }
    public var Settings_FAQ_URL: String { return self._s[3153]! }
    public var ChatList_UndoArchiveText1: String { return self._s[3154]! }
    public var Common_Select: String { return self._s[3156]! }
    public var Notification_MessageLifetimeRemovedOutgoing: String { return self._s[3157]! }
    public var Notification_PassportValueAddress: String { return self._s[3158]! }
    public var Conversation_MessageDialogDelete: String { return self._s[3159]! }
    public var Map_OpenInYandexNavigator: String { return self._s[3161]! }
    public var DialogList_SearchSectionDialogs: String { return self._s[3162]! }
    public var AccessDenied_Contacts: String { return self._s[3163]! }
    public var SettingsSearch_Synonyms_Privacy_Data_DeleteDrafts: String { return self._s[3165]! }
    public var Passport_ScanPassportHelp: String { return self._s[3166]! }
    public var Chat_PinnedListPreview_HidePinnedMessages: String { return self._s[3167]! }
    public var ChatListFolder_NameChannels: String { return self._s[3168]! }
    public var Appearance_ThemePreview_Chat_5_Text: String { return self._s[3169]! }
    public func Channel_OwnershipTransfer_TransferCompleted(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3170]!, self._r[3170]!, [_1, _2])
    }
    public var Checkout_ErrorInvoiceAlreadyPaid: String { return self._s[3171]! }
    public func VoiceChat_InviteMemberToGroupFirstText(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3172]!, self._r[3172]!, [_1, _2])
    }
    public var Conversation_GifTooltip: String { return self._s[3173]! }
    public var Widget_MessageAutoremoveTimerUpdated: String { return self._s[3174]! }
    public var Passport_Identity_TypeDriversLicenseUploadScan: String { return self._s[3176]! }
    public var VoiceChat_Connecting: String { return self._s[3177]! }
    public var AutoDownloadSettings_OffForAll: String { return self._s[3178]! }
    public func Channel_AdminLog_CreatedInviteLink(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3179]!, self._r[3179]!, [_1, _2])
    }
    public var Privacy_GroupsAndChannels_InviteToChannelMultipleError: String { return self._s[3180]! }
    public var AutoDownloadSettings_PreloadVideo: String { return self._s[3181]! }
    public var CreatePoll_Quiz: String { return self._s[3182]! }
    public var TwoFactorSetup_Email_Placeholder: String { return self._s[3184]! }
    public var Watch_Message_Invoice: String { return self._s[3185]! }
    public var Settings_AddAnotherAccount_Help: String { return self._s[3186]! }
    public var Watch_Message_Unsupported: String { return self._s[3187]! }
    public func Call_CameraOff(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3189]!, self._r[3189]!, [_0])
    }
    public var AuthSessions_TerminateOtherSessions: String { return self._s[3190]! }
    public var CreatePoll_AllOptionsAdded: String { return self._s[3192]! }
    public var TwoStepAuth_RecoveryEmailTitle: String { return self._s[3193]! }
    public var Call_IncomingVoiceCall: String { return self._s[3194]! }
    public func Channel_AdminLog_MessageTransferedNameUsername(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3195]!, self._r[3195]!, [_1, _2])
    }
    public var PrivacySettings_DeleteAccountHelp: String { return self._s[3196]! }
    public var Passport_Address_TypePassportRegistrationUploadScan: String { return self._s[3197]! }
    public var Group_EditAdmin_RankOwnerPlaceholder: String { return self._s[3198]! }
    public var Group_ErrorAccessDenied: String { return self._s[3199]! }
    public var PasscodeSettings_HelpTop: String { return self._s[3200]! }
    public var Watch_ChatList_NoConversationsTitle: String { return self._s[3201]! }
    public var AddContact_SharedContactException: String { return self._s[3202]! }
    public var AccessDenied_MicrophoneRestricted: String { return self._s[3203]! }
    public var Privacy_TopPeers: String { return self._s[3204]! }
    public var Web_OpenExternal: String { return self._s[3205]! }
    public var Group_ErrorSendRestrictedStickers: String { return self._s[3206]! }
    public var Channel_Management_LabelAdministrator: String { return self._s[3207]! }
    public func ChangePhoneNumberCode_CallTimer(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3208]!, self._r[3208]!, [_0])
    }
    public var Conversation_PhoneCopied: String { return self._s[3209]! }
    public var Permissions_Skip: String { return self._s[3210]! }
    public var Notifications_GroupNotificationsExceptions: String { return self._s[3211]! }
    public func VoiceChat_ForwardTooltip_TwoChats(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3212]!, self._r[3212]!, [_0, _1])
    }
    public var PeopleNearby_Title: String { return self._s[3213]! }
    public var GroupInfo_SharedMediaNone: String { return self._s[3214]! }
    public func PUSH_MESSAGE_GEOLIVE(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3216]!, self._r[3216]!, [_1])
    }
    public var Profile_MessageLifetime1w: String { return self._s[3217]! }
    public func Time_PreciseDate_m6(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3218]!, self._r[3218]!, [_1, _2, _3])
    }
    public var WebBrowser_DefaultBrowser: String { return self._s[3219]! }
    public var Conversation_PinOlderMessageAlertTitle: String { return self._s[3221]! }
    public var EditTheme_Edit_BottomInfo: String { return self._s[3222]! }
    public var Privacy_Forwards_Preview: String { return self._s[3223]! }
    public var Settings_EditAccount: String { return self._s[3224]! }
    public func Conversation_RestrictedInlineTimed(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3225]!, self._r[3225]!, [_0])
    }
    public var TwoFactorSetup_Intro_Title: String { return self._s[3226]! }
    public func Channel_AdminLog_MessagePromotedName(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3228]!, self._r[3228]!, [_1])
    }
    public var PeerInfo_ButtonVideoCall: String { return self._s[3229]! }
    public func DialogList_SingleUploadingPhotoSuffix(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3230]!, self._r[3230]!, [_0])
    }
    public var Login_InfoHelp: String { return self._s[3231]! }
    public var Notification_SecretChatMessageScreenshotSelf: String { return self._s[3232]! }
    public var VoiceChat_SpeakPermissionEveryone: String { return self._s[3233]! }
    public var Profile_MessageLifetime1d: String { return self._s[3234]! }
    public var Group_UpgradeConfirmation: String { return self._s[3235]! }
    public func PUSH_PINNED_STICKER(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3236]!, self._r[3236]!, [_1, _2])
    }
    public var Appearance_RemoveThemeColor: String { return self._s[3237]! }
    public var Channel_AdminLog_TitleSelectedEvents: String { return self._s[3238]! }
    public func Call_AnsweringWithAccount(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3239]!, self._r[3239]!, [_0])
    }
    public var UserInfo_BotSettings: String { return self._s[3240]! }
    public func Notification_ChannelInviter(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3242]!, self._r[3242]!, [_0])
    }
    public var Permissions_ContactsText_v0: String { return self._s[3243]! }
    public var Conversation_PinMessagesForMe: String { return self._s[3244]! }
    public var VoiceChat_PanelJoin: String { return self._s[3245]! }
    public var Conversation_DiscussionStarted: String { return self._s[3247]! }
    public var SettingsSearch_Synonyms_Privacy_TwoStepAuth: String { return self._s[3248]! }
    public var SharedMedia_SearchNoResults: String { return self._s[3250]! }
    public func Login_EmailPhoneSubject(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3252]!, self._r[3252]!, [_0])
    }
    public func Conversation_ShareMyPhoneNumber_StatusSuccess(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3254]!, self._r[3254]!, [_0])
    }
    public var ReportPeer_ReasonOther_Placeholder: String { return self._s[3255]! }
    public var ContactInfo_PhoneLabelHomeFax: String { return self._s[3256]! }
    public var Call_AudioRouteHeadphones: String { return self._s[3257]! }
    public func Notification_VoiceChatScheduledTomorrowChannel(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3259]!, self._r[3259]!, [_0])
    }
    public func PUSH_AUTH_UNKNOWN(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3260]!, self._r[3260]!, [_1])
    }
    public var Passport_Identity_FilesView: String { return self._s[3261]! }
    public var TwoStepAuth_SetupEmail: String { return self._s[3262]! }
    public var Widget_ApplicationStartRequired: String { return self._s[3263]! }
    public var PhotoEditor_Original: String { return self._s[3264]! }
    public var Call_YourMicrophoneOff: String { return self._s[3265]! }
    public var Permissions_ContactsAllow_v0: String { return self._s[3266]! }
    public var Conversation_CardNumberCopied: String { return self._s[3267]! }
    public var Notification_Exceptions_PreviewAlwaysOn: String { return self._s[3268]! }
    public var PrivacyPolicy_Decline: String { return self._s[3269]! }
    public var SettingsSearch_Synonyms_ChatFolders: String { return self._s[3270]! }
    public var TwoStepAuth_PasswordRemoveConfirmation: String { return self._s[3271]! }
    public var ChatListFolder_IncludeSectionInfo: String { return self._s[3272]! }
    public func Map_DirectionsDriveEta(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3273]!, self._r[3273]!, [_0])
    }
    public var Passport_Identity_Name: String { return self._s[3274]! }
    public var WallpaperPreview_PatternTitle: String { return self._s[3276]! }
    public var VoiceOver_Chat_RecordModeVideoMessage: String { return self._s[3277]! }
    public var WallpaperSearch_ColorOrange: String { return self._s[3279]! }
    public var Appearance_ThemePreview_ChatList_5_Name: String { return self._s[3280]! }
    public var GroupInfo_Permissions_SlowmodeInfo: String { return self._s[3281]! }
    public var Your_cards_security_code_is_invalid: String { return self._s[3282]! }
    public var IntentsSettings_ResetAll: String { return self._s[3283]! }
    public var SettingsSearch_Synonyms_Calls_CallTab: String { return self._s[3285]! }
    public var Group_EditAdmin_TransferOwnership: String { return self._s[3286]! }
    public var ChatList_DeleteForAllSubscribers: String { return self._s[3287]! }
    public var Notification_Exceptions_Add: String { return self._s[3288]! }
    public var Group_DeleteGroup: String { return self._s[3289]! }
    public var Cache_Help: String { return self._s[3290]! }
    public var Call_AudioRouteMute: String { return self._s[3291]! }
    public var VoiceOver_Chat_YourVoiceMessage: String { return self._s[3292]! }
    public var SocksProxySetup_ProxyEnabled: String { return self._s[3293]! }
    public func VoiceChat_Status_MembersFormat(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3294]!, self._r[3294]!, [_1, _2])
    }
    public func ApplyLanguage_UnsufficientDataText(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3295]!, self._r[3295]!, [_1])
    }
    public func Call_CallInProgressMessage(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3296]!, self._r[3296]!, [_1, _2])
    }
    public var AutoDownloadSettings_VideoMessagesTitle: String { return self._s[3297]! }
    public var Channel_BanUser_PermissionAddMembers: String { return self._s[3298]! }
    public func PUSH_CHAT_VOICECHAT_INVITE(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3299]!, self._r[3299]!, [_1, _2, _3])
    }
    public var Contacts_MemberSearchSectionTitleGroup: String { return self._s[3300]! }
    public var TwoStepAuth_RecoveryCodeHelp: String { return self._s[3301]! }
    public var ClearCache_StorageFree: String { return self._s[3302]! }
    public func DialogList_SingleRecordingVideoMessageSuffix(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3303]!, self._r[3303]!, [_0])
    }
    public var Privacy_Forwards_CustomHelp: String { return self._s[3304]! }
    public func Channel_AdminLog_EditedInviteLink(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3306]!, self._r[3306]!, [_1, _2])
    }
    public var Group_ErrorAddTooMuchAdmins: String { return self._s[3307]! }
    public var DialogList_Typing: String { return self._s[3308]! }
    public func Login_EmailCodeSubject(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3309]!, self._r[3309]!, [_0])
    }
    public var Target_SelectGroup: String { return self._s[3310]! }
    public var AuthSessions_IncompleteAttempts: String { return self._s[3311]! }
    public func Notification_ProximityReached(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3312]!, self._r[3312]!, [_1, _2, _3])
    }
    public var Chat_PinnedListPreview_ShowAllMessages: String { return self._s[3313]! }
    public var TwoStepAuth_EmailChangeSuccess: String { return self._s[3314]! }
    public func Settings_CheckPhoneNumberTitle(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3315]!, self._r[3315]!, [_0])
    }
    public var Channel_AdminLog_CanSendMessages: String { return self._s[3316]! }
    public var TwoFactorSetup_EmailVerification_Title: String { return self._s[3317]! }
    public var ChatSettings_TextSize: String { return self._s[3318]! }
    public var Channel_AdminLogFilter_EventsEditedMessages: String { return self._s[3320]! }
    public var Map_SendThisPlace: String { return self._s[3321]! }
    public var Conversation_TextCopied: String { return self._s[3322]! }
    public var Login_PhoneNumberAlreadyAuthorized: String { return self._s[3323]! }
    public var ContactInfo_BirthdayLabel: String { return self._s[3324]! }
    public var Call_ShareStats: String { return self._s[3325]! }
    public func PUSH_CHAT_VOICECHAT_END(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3327]!, self._r[3327]!, [_1, _2])
    }
    public var ChatList_UndoArchiveRevealedText: String { return self._s[3328]! }
    public var Notifications_GroupNotificationsPreview: String { return self._s[3329]! }
    public var Settings_Support: String { return self._s[3330]! }
    public var GroupInfo_ChannelListNamePlaceholder: String { return self._s[3331]! }
    public func EmptyGroupInfo_Line1(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3333]!, self._r[3333]!, [_0])
    }
    public var Watch_Conversation_GroupInfo: String { return self._s[3334]! }
    public var Tour_Text4: String { return self._s[3335]! }
    public var VoiceChat_CancelReminder: String { return self._s[3336]! }
    public var UserInfo_FakeUserWarning: String { return self._s[3338]! }
    public var PasscodeSettings_AutoLock: String { return self._s[3339]! }
    public var Channel_BanList_BlockedTitle: String { return self._s[3340]! }
    public var Bot_DescriptionTitle: String { return self._s[3342]! }
    public var Map_LocationTitle: String { return self._s[3343]! }
    public var ChatListFolder_ExcludeSectionInfo: String { return self._s[3344]! }
    public var Conversation_HashtagCopied: String { return self._s[3345]! }
    public func Notification_MessageLifetimeChangedOutgoing(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3346]!, self._r[3346]!, [_1])
    }
    public var VoiceChat_ReminderNotify: String { return self._s[3347]! }
    public var Login_EmailNotConfiguredError: String { return self._s[3348]! }
    public var AutoDownloadSettings_LimitBySize: String { return self._s[3349]! }
    public var PrivacySettings_LastSeenNobody: String { return self._s[3350]! }
    public var Permissions_CellularDataText_v0: String { return self._s[3351]! }
    public var Conversation_EncryptionProcessing: String { return self._s[3352]! }
    public var GroupPermission_Delete: String { return self._s[3354]! }
    public var Contacts_SortByName: String { return self._s[3355]! }
    public var TwoStepAuth_RecoveryUnavailable: String { return self._s[3356]! }
    public var Compose_ChannelTokenListPlaceholder: String { return self._s[3357]! }
    public var Group_Management_AddModeratorHelp: String { return self._s[3359]! }
    public var SettingsSearch_Synonyms_EditProfile_Logout: String { return self._s[3360]! }
    public var Forward_ErrorPublicPollDisabledInChannels: String { return self._s[3361]! }
    public var CallFeedback_IncludeLogsInfo: String { return self._s[3363]! }
    public func PUSH_CHANNEL_MESSAGE_QUIZ(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3364]!, self._r[3364]!, [_1])
    }
    public func SecretVideo_NotViewedYet(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3365]!, self._r[3365]!, [_0])
    }
    public var ChatList_Context_Delete: String { return self._s[3366]! }
    public var VoiceChat_InviteMember: String { return self._s[3367]! }
    public var PrivacyPhoneNumberSettings_CustomDisabledHelp: String { return self._s[3368]! }
    public var Conversation_Processing: String { return self._s[3369]! }
    public var TwoStepAuth_EmailCodeExpired: String { return self._s[3370]! }
    public var ChatSettings_Stickers: String { return self._s[3371]! }
    public var AppleWatch_ReplyPresetsHelp: String { return self._s[3372]! }
    public var Passport_Language_cs: String { return self._s[3373]! }
    public var GroupInfo_InvitationLinkGroupFull: String { return self._s[3375]! }
    public var Conversation_Contact: String { return self._s[3376]! }
    public var Passport_Identity_ReverseSideHelp: String { return self._s[3377]! }
    public var SocksProxySetup_PasteFromClipboard: String { return self._s[3378]! }
    public var Theme_Unsupported: String { return self._s[3379]! }
    public var Privacy_TopPeersWarning: String { return self._s[3380]! }
    public func Conversation_ScheduledVoiceChatStartsTodayShort(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3381]!, self._r[3381]!, [_0])
    }
    public var InviteLink_Title: String { return self._s[3383]! }
    public func UserInfo_BlockConfirmationTitle(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3384]!, self._r[3384]!, [_0])
    }
    public var Conversation_SilentBroadcastTooltipOn: String { return self._s[3385]! }
    public var TwoStepAuth_RemovePassword: String { return self._s[3386]! }
    public var Settings_CheckPhoneNumberText: String { return self._s[3387]! }
    public var PeopleNearby_Users: String { return self._s[3388]! }
    public var Appearance_TextSize_UseSystem: String { return self._s[3389]! }
    public var Settings_SetProfilePhoto: String { return self._s[3390]! }
    public var Conversation_ContextMenuBan: String { return self._s[3391]! }
    public var KeyCommand_ScrollUp: String { return self._s[3392]! }
    public var Settings_ChatSettings: String { return self._s[3394]! }
    public var CallList_RecentCallsHeader: String { return self._s[3395]! }
    public func PUSH_CHAT_MESSAGE_VIDEO(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3396]!, self._r[3396]!, [_1, _2])
    }
    public var Stats_GroupTopInvitersTitle: String { return self._s[3397]! }
    public var Passport_Phone_EnterOtherNumber: String { return self._s[3398]! }
    public var VoiceChat_StartRecordingTitle: String { return self._s[3399]! }
    public func Notification_VoiceChatScheduledToday(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3400]!, self._r[3400]!, [_1, _2])
    }
    public var Passport_Identity_MiddleNamePlaceholder: String { return self._s[3402]! }
    public var Passport_Address_OneOfTypeBankStatement: String { return self._s[3403]! }
    public var VoiceOver_ChatList_MessageRead: String { return self._s[3404]! }
    public var Stats_GroupTopPoster_Promote: String { return self._s[3405]! }
    public var Cache_Title: String { return self._s[3406]! }
    public func Conversation_AutoremoveTimerSetToastText(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3407]!, self._r[3407]!, [_0])
    }
    public var Clipboard_SendPhoto: String { return self._s[3408]! }
    public var Notifications_ExceptionsMessagePlaceholder: String { return self._s[3410]! }
    public var TwoStepAuth_EnterPasswordForgot: String { return self._s[3411]! }
    public var WatchRemote_AlertTitle: String { return self._s[3414]! }
    public var Appearance_ReduceMotion: String { return self._s[3415]! }
    public func PUSH_CHAT_MESSAGE_ROUND(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3418]!, self._r[3418]!, [_1, _2])
    }
    public var Notifications_PermissionsSuppressWarningText: String { return self._s[3419]! }
    public var ChatList_UndoArchiveHiddenTitle: String { return self._s[3420]! }
    public var Passport_Identity_TypePersonalDetails: String { return self._s[3421]! }
    public func Call_CallInProgressVoiceChatMessage(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3422]!, self._r[3422]!, [_1, _2])
    }
    public func Passport_Identity_UploadOneOfScan(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3424]!, self._r[3424]!, [_0])
    }
    public var ChatListFolder_DiscardConfirmation: String { return self._s[3425]! }
    public func Conversation_RestrictedStickersTimed(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3427]!, self._r[3427]!, [_0])
    }
    public var InstantPage_Search: String { return self._s[3428]! }
    public var ChatState_WaitingForNetwork: String { return self._s[3429]! }
    public var GroupInfo_Sound: String { return self._s[3430]! }
    public var NotificationsSound_Telegraph: String { return self._s[3431]! }
    public var NotificationsSound_Hello: String { return self._s[3432]! }
    public var VoiceChat_LeaveConfirmation: String { return self._s[3433]! }
    public var UserInfo_LinkForwardTooltip_SavedMessages_One: String { return self._s[3434]! }
    public var Passport_FieldIdentityDetailsHelp: String { return self._s[3435]! }
    public var Group_Members_AddMemberBotErrorNotAllowed: String { return self._s[3436]! }
    public var Conversation_HoldForVideo: String { return self._s[3437]! }
    public var Conversation_PinOlderMessageAlertText: String { return self._s[3438]! }
    public var Appearance_ShareTheme: String { return self._s[3439]! }
    public var TwoStepAuth_SetupHint: String { return self._s[3440]! }
    public var Stats_GrowthTitle: String { return self._s[3443]! }
    public var GroupInfo_InviteLink_ShareLink: String { return self._s[3444]! }
    public var Conversation_DefaultRestrictedMedia: String { return self._s[3445]! }
    public var Channel_EditAdmin_PermissionPostMessages: String { return self._s[3446]! }
    public var GroupPermission_NoSendMessages: String { return self._s[3449]! }
    public var Conversation_SetReminder_Title: String { return self._s[3450]! }
    public var Privacy_Calls_CustomHelp: String { return self._s[3451]! }
    public var CheckoutInfo_ErrorPostcodeInvalid: String { return self._s[3452]! }
    public func ClearCache_StorageTitle(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3453]!, self._r[3453]!, [_0])
    }
    public var InviteLinks_InviteLinkExpired: String { return self._s[3455]! }
    public var Undo_SecretChatDeleted: String { return self._s[3456]! }
    public var PhotoEditor_ContrastTool: String { return self._s[3457]! }
    public var Privacy_Forwards: String { return self._s[3458]! }
    public var AuthSessions_LoggedInWithTelegram: String { return self._s[3459]! }
    public var KeyCommand_SendMessage: String { return self._s[3461]! }
    public var Conversation_PrivateMessageLinkCopiedLong: String { return self._s[3462]! }
    public func InstantPage_RelatedArticleAuthorAndDateTitle(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3463]!, self._r[3463]!, [_1, _2])
    }
    public var GroupPermission_NoSendGifs: String { return self._s[3464]! }
    public var Notification_MessageLifetime2s: String { return self._s[3465]! }
    public var Message_Theme: String { return self._s[3466]! }
    public var Conversation_Dice_u1F3AF: String { return self._s[3469]! }
    public func DialogList_SinglePlayingGameSuffix(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3470]!, self._r[3470]!, [_0])
    }
    public var Group_UpgradeNoticeHeader: String { return self._s[3472]! }
    public var PeerInfo_BioExpand: String { return self._s[3473]! }
    public var Passport_DeletePersonalDetails: String { return self._s[3474]! }
    public var Widget_NoUsers: String { return self._s[3475]! }
    public var TwoStepAuth_AddHintTitle: String { return self._s[3476]! }
    public var Login_TermsOfServiceDecline: String { return self._s[3477]! }
    public var CreatePoll_QuizTip: String { return self._s[3479]! }
    public var Watch_LastSeen_WithinAWeek: String { return self._s[3480]! }
    public var MessagePoll_SubmitVote: String { return self._s[3482]! }
    public var ChatSettings_AutoDownloadEnabled: String { return self._s[3483]! }
    public var Passport_Address_EditRentalAgreement: String { return self._s[3484]! }
    public var Conversation_SearchByName_Placeholder: String { return self._s[3485]! }
    public var Conversation_UpdateTelegram: String { return self._s[3486]! }
    public func FileSize_KB(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3487]!, self._r[3487]!, [_0])
    }
    public var UserInfo_About_Placeholder: String { return self._s[3488]! }
    public var CallSettings_Always: String { return self._s[3489]! }
    public var ChannelInfo_ScamChannelWarning: String { return self._s[3490]! }
    public var VoiceChat_MutedByAdminHelp: String { return self._s[3491]! }
    public var Login_TermsOfServiceHeader: String { return self._s[3492]! }
    public var KeyCommand_ChatInfo: String { return self._s[3493]! }
    public var MessagePoll_LabelPoll: String { return self._s[3494]! }
    public var Paint_Clear: String { return self._s[3495]! }
    public var PeerInfo_ButtonMute: String { return self._s[3496]! }
    public var LastSeen_WithinAWeek: String { return self._s[3497]! }
    public var Invitation_JoinVoiceChatAsSpeaker: String { return self._s[3498]! }
    public var Passport_Identity_FrontSide: String { return self._s[3499]! }
    public var Stickers_GroupStickers: String { return self._s[3500]! }
    public var ChangePhoneNumberNumber_NumberPlaceholder: String { return self._s[3501]! }
    public func Map_SearchNoResultsDescription(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3502]!, self._r[3502]!, [_0])
    }
    public var VoiceOver_BotCommands: String { return self._s[3503]! }
    public func PUSH_MESSAGE_GEO(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3506]!, self._r[3506]!, [_1])
    }
    public var SocksProxySetup_ProxyStatusConnected: String { return self._s[3507]! }
    public var Chat_MultipleTextMessagesDisabled: String { return self._s[3508]! }
    public var InviteLink_ContextDelete: String { return self._s[3509]! }
    public func Notification_LeftChat(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3510]!, self._r[3510]!, [_0])
    }
    public var WebSearch_SearchNoResults: String { return self._s[3512]! }
    public var Channel_DiscussionGroup_Create: String { return self._s[3513]! }
    public var Passport_Language_es: String { return self._s[3514]! }
    public var EnterPasscode_EnterCurrentPasscode: String { return self._s[3515]! }
    public var Map_LiveLocationShowAll: String { return self._s[3516]! }
    public var Cache_MaximumCacheSizeHelp: String { return self._s[3518]! }
    public var Map_OpenInGoogleMaps: String { return self._s[3519]! }
    public var CheckoutInfo_ErrorNameInvalid: String { return self._s[3521]! }
    public var EditTheme_Create_BottomInfo: String { return self._s[3522]! }
    public var PhotoEditor_BlurToolLinear: String { return self._s[3523]! }
    public func Channel_AdminLog_MessageEdited(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3524]!, self._r[3524]!, [_0])
    }
    public var Passport_Phone_Delete: String { return self._s[3525]! }
    public var Channel_Username_CreatePrivateLinkHelp: String { return self._s[3526]! }
    public var PrivacySettings_PrivacyTitle: String { return self._s[3527]! }
    public var CheckoutInfo_ReceiverInfoNamePlaceholder: String { return self._s[3528]! }
    public func EncryptionKey_Description(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3529]!, self._r[3529]!, [_1, _2])
    }
    public var LogoutOptions_LogOutInfo: String { return self._s[3530]! }
    public var Cache_ByPeerHeader: String { return self._s[3532]! }
    public var Username_InvalidCharacters: String { return self._s[3533]! }
    public var Checkout_ShippingAddress: String { return self._s[3535]! }
    public func PUSH_CHAT_MESSAGE_GAME_SCORE(_ _1: String, _ _2: String, _ _3: String, _ _4: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3536]!, self._r[3536]!, [_1, _2, _3, _4])
    }
    public var VoiceChat_LeaveAndEndVoiceChat: String { return self._s[3538]! }
    public var Conversation_AddContact: String { return self._s[3539]! }
    public var Passport_Address_EditUtilityBill: String { return self._s[3540]! }
    public var InviteLink_ContextGetQRCode: String { return self._s[3541]! }
    public var Conversation_ChecksTooltip_Delivered: String { return self._s[3543]! }
    public func Channel_AdminLog_MessageAddedAdminNameUsername(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3544]!, self._r[3544]!, [_1, _2])
    }
    public var Message_Video: String { return self._s[3545]! }
    public func Watch_Time_ShortYesterdayAt(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3546]!, self._r[3546]!, [_0])
    }
    public func Conversation_Megabytes(_ _0: Float) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3547]!, self._r[3547]!, ["\(_0)"])
    }
    public var InviteLink_ReactivateLink: String { return self._s[3548]! }
    public var Passport_Language_km: String { return self._s[3550]! }
    public func PUSH_MESSAGE_CHANNEL_MESSAGE_GAME_SCORE(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3551]!, self._r[3551]!, [_1, _2, _3])
    }
    public var EmptyGroupInfo_Line4: String { return self._s[3552]! }
    public var Conversation_SendMessageErrorTooMuchScheduled: String { return self._s[3554]! }
    public var Notification_CallCanceledShort: String { return self._s[3555]! }
    public var PhotoEditor_FadeTool: String { return self._s[3556]! }
    public var Group_PublicLink_Info: String { return self._s[3557]! }
    public var Contacts_DeselectAll: String { return self._s[3558]! }
    public var Conversation_Moderate_Delete: String { return self._s[3560]! }
    public var TwoStepAuth_RecoveryCodeInvalid: String { return self._s[3561]! }
    public var NotificationsSound_Note: String { return self._s[3564]! }
    public func Message_PaymentSent(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3565]!, self._r[3565]!, [_0])
    }
    public var Appearance_ThemePreview_ChatList_7_Text: String { return self._s[3566]! }
    public var Channel_EditAdmin_PermissionInviteViaLink: String { return self._s[3568]! }
    public var DialogList_SearchSectionGlobal: String { return self._s[3569]! }
    public var AccessDenied_Settings: String { return self._s[3570]! }
    public var Passport_Identity_TypeIdentityCardUploadScan: String { return self._s[3571]! }
    public var AuthSessions_EmptyTitle: String { return self._s[3572]! }
    public var TwoStepAuth_PasswordChangeSuccess: String { return self._s[3573]! }
    public var GroupInfo_GroupType: String { return self._s[3574]! }
    public var Calls_Missed: String { return self._s[3575]! }
    public var Contacts_VoiceOver_AddContact: String { return self._s[3576]! }
    public var UserInfo_GenericPhoneLabel: String { return self._s[3578]! }
    public var Passport_Language_uz: String { return self._s[3579]! }
    public var Conversation_StopQuizConfirmationTitle: String { return self._s[3580]! }
    public var PhotoEditor_BlurToolPortrait: String { return self._s[3581]! }
    public var VoiceChat_CreateNewVoiceChatStartNow: String { return self._s[3582]! }
    public var Map_ChooseLocationTitle: String { return self._s[3583]! }
    public var Checkout_EnterPassword: String { return self._s[3584]! }
    public var GroupInfo_ConvertToSupergroup: String { return self._s[3585]! }
    public var AutoNightTheme_UpdateLocation: String { return self._s[3586]! }
    public var NetworkUsageSettings_Title: String { return self._s[3587]! }
    public var Location_ProximityAlertCancelled: String { return self._s[3588]! }
    public var SettingsSearch_Synonyms_ChatSettings_IntentsSettings: String { return self._s[3589]! }
    public var Message_PinnedLiveLocationMessage: String { return self._s[3590]! }
    public var Compose_NewChannel: String { return self._s[3591]! }
    public var Privacy_PaymentsClearInfo: String { return self._s[3593]! }
    public func PUSH_MESSAGE_POLL(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3594]!, self._r[3594]!, [_1])
    }
    public var Notification_Exceptions_AlwaysOn: String { return self._s[3595]! }
    public var Privacy_GroupsAndChannels_WhoCanAddMe: String { return self._s[3596]! }
    public var AutoNightTheme_AutomaticSection: String { return self._s[3599]! }
    public var WallpaperSearch_ColorBrown: String { return self._s[3600]! }
    public var Appearance_AppIconDefault: String { return self._s[3601]! }
    public var StickerSettings_ContextInfo: String { return self._s[3604]! }
    public var Channel_AddBotErrorNoRights: String { return self._s[3605]! }
    public var Passport_FieldPhone: String { return self._s[3607]! }
    public var Contacts_PermissionsTitle: String { return self._s[3608]! }
    public var TwoFactorSetup_Email_SkipConfirmationSkip: String { return self._s[3609]! }
    public func Notification_JoinedChat(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3610]!, self._r[3610]!, [_0])
    }
    public var Bot_Unblock: String { return self._s[3611]! }
    public var PasscodeSettings_SimplePasscode: String { return self._s[3612]! }
    public var InviteLink_InviteLinkCopiedText: String { return self._s[3613]! }
    public var Passport_PasswordHelp: String { return self._s[3614]! }
    public var Watch_Conversation_UserInfo: String { return self._s[3615]! }
    public func Channel_AdminLog_MessageChangedGroupGeoLocation(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3619]!, self._r[3619]!, [_0])
    }
    public var State_Connecting: String { return self._s[3621]! }
    public var Passport_Address_TypeTemporaryRegistration: String { return self._s[3622]! }
    public var TextFormat_AddLinkPlaceholder: String { return self._s[3623]! }
    public var Conversation_Dice_u1F3B2: String { return self._s[3624]! }
    public func Call_StatusBar(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3625]!, self._r[3625]!, [_0])
    }
    public var Conversation_SendingOptionsTooltip: String { return self._s[3626]! }
    public var ChatList_UndoArchiveTitle: String { return self._s[3627]! }
    public var ChatList_EmptyChatListNewMessage: String { return self._s[3628]! }
    public var WallpaperSearch_ColorGreen: String { return self._s[3630]! }
    public var PhotoEditor_BlurToolOff: String { return self._s[3631]! }
    public var Conversation_AutoremoveOff: String { return self._s[3632]! }
    public var SocksProxySetup_PortPlaceholder: String { return self._s[3633]! }
    public var Weekday_Saturday: String { return self._s[3634]! }
    public var DialogList_Unread: String { return self._s[3635]! }
    public var Watch_LastSeen_ALongTimeAgo: String { return self._s[3636]! }
    public var Stats_GroupPosters: String { return self._s[3637]! }
    public func PUSH_ENCRYPTION_REQUEST(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3638]!, self._r[3638]!, [_1])
    }
    public var Conversation_AlsoClearCacheTitle: String { return self._s[3639]! }
    public func Conversation_ForwardTooltip_TwoChats_One(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3640]!, self._r[3640]!, [_0, _1])
    }
    public func Target_ShareGameConfirmationGroup(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3643]!, self._r[3643]!, [_0])
    }
    public var ReportPeer_ReasonChildAbuse: String { return self._s[3644]! }
    public func Channel_AdminLog_MessageUnkickedNameUsername(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3645]!, self._r[3645]!, [_1, _2])
    }
    public var InfoPlist_NSContactsUsageDescription: String { return self._s[3646]! }
    public var Conversation_EmailCopied: String { return self._s[3648]! }
    public var AutoNightTheme_UseSunsetSunrise: String { return self._s[3649]! }
    public var Channel_OwnershipTransfer_ChangeOwner: String { return self._s[3650]! }
    public var Call_VoiceOver_VoiceCallCanceled: String { return self._s[3651]! }
    public var VoiceChat_LateBy: String { return self._s[3652]! }
    public var Passport_Language_dv: String { return self._s[3653]! }
    public var GroupPermission_AddSuccess: String { return self._s[3655]! }
    public var Passport_Email_Help: String { return self._s[3656]! }
    public var Call_ReportPlaceholder: String { return self._s[3657]! }
    public var CreatePoll_AddOption: String { return self._s[3658]! }
    public var MessagePoll_LabelAnonymousQuiz: String { return self._s[3660]! }
    public var PeerInfo_ButtonLeave: String { return self._s[3661]! }
    public var PhotoEditor_TiltShift: String { return self._s[3664]! }
    public var SecretGif_Title: String { return self._s[3666]! }
    public var GroupInfo_InviteLinks: String { return self._s[3667]! }
    public var PhotoEditor_QualityVeryLow: String { return self._s[3668]! }
    public var SocksProxySetup_Connecting: String { return self._s[3670]! }
    public var PrivacySettings_PasscodeAndFaceId: String { return self._s[3671]! }
    public var ContactInfo_PhoneLabelWork: String { return self._s[3672]! }
    public var Stats_GroupTopHoursTitle: String { return self._s[3673]! }
    public var Compose_NewMessage: String { return self._s[3674]! }
    public var VoiceOver_Common_SwitchHint: String { return self._s[3675]! }
    public var NotificationsSound_Synth: String { return self._s[3676]! }
    public var ChatImport_UserErrorNotMutual: String { return self._s[3677]! }
    public var Conversation_FileOpenIn: String { return self._s[3678]! }
    public var AutoDownloadSettings_WifiTitle: String { return self._s[3679]! }
    public var UserInfo_SendMessage: String { return self._s[3680]! }
    public var Checkout_PayWithFaceId: String { return self._s[3681]! }
    public func Map_LiveLocationShortHour(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3682]!, self._r[3682]!, [_0])
    }
    public var TextFormat_Strikethrough: String { return self._s[3683]! }
    public var SettingsSearch_Synonyms_Notifications_DisplayNamesOnLockScreen: String { return self._s[3684]! }
    public var Conversation_ViewChannel: String { return self._s[3685]! }
    public func Message_ForwardedMessage(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3686]!, self._r[3686]!, [_0])
    }
    public var Channel_Stickers_Placeholder: String { return self._s[3687]! }
    public var Channel_OwnershipTransfer_PasswordPlaceholder: String { return self._s[3688]! }
    public var Message_ScamAccount: String { return self._s[3689]! }
    public var Camera_FlashAuto: String { return self._s[3690]! }
    public var Conversation_EncryptedDescription1: String { return self._s[3691]! }
    public var LocalGroup_Text: String { return self._s[3692]! }
    public var SettingsSearch_Synonyms_Data_Storage_KeepMedia: String { return self._s[3693]! }
    public var UserInfo_FirstNamePlaceholder: String { return self._s[3694]! }
    public var Conversation_SendMessageErrorFlood: String { return self._s[3695]! }
    public var Conversation_EncryptedDescription2: String { return self._s[3696]! }
    public var Conversation_CancelForwardText: String { return self._s[3697]! }
    public var Notification_GroupActivated: String { return self._s[3698]! }
    public var LastSeen_Lately: String { return self._s[3699]! }
    public var Conversation_EncryptedDescription3: String { return self._s[3700]! }
    public var SettingsSearch_Synonyms_Privacy_ProfilePhoto: String { return self._s[3701]! }
    public var Conversation_SwipeToReplyHintText: String { return self._s[3702]! }
    public var Conversation_EncryptedDescription4: String { return self._s[3703]! }
    public var SharedMedia_EmptyTitle: String { return self._s[3704]! }
    public var Appearance_CreateTheme: String { return self._s[3706]! }
    public var Stats_SharesPerPost: String { return self._s[3707]! }
    public var Contacts_TabTitle: String { return self._s[3708]! }
    public var Weekday_ShortThursday: String { return self._s[3709]! }
    public var MessageTimer_Forever: String { return self._s[3710]! }
    public var ChatListFolder_CategoryArchived: String { return self._s[3711]! }
    public var Channel_EditAdmin_PermissionDeleteMessages: String { return self._s[3712]! }
    public var EditTheme_Create_TopInfo: String { return self._s[3714]! }
    public func VoiceOver_ChatList_MessageFrom(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3715]!, self._r[3715]!, [_0])
    }
    public var Month_GenDecember: String { return self._s[3716]! }
    public var EnterPasscode_EnterPasscode: String { return self._s[3717]! }
    public var SettingsSearch_Synonyms_Appearance_LargeEmoji: String { return self._s[3718]! }
    public var PeopleNearby_CreateGroup: String { return self._s[3720]! }
    public var Group_EditAdmin_PermissionChangeInfo: String { return self._s[3721]! }
    public var Paint_ClearConfirm: String { return self._s[3722]! }
    public var ChatList_ReadAll: String { return self._s[3723]! }
    public var ChatSettings_IntentsSettings: String { return self._s[3724]! }
    public var Passport_PassportInformation: String { return self._s[3726]! }
    public var Login_CheckOtherSessionMessages: String { return self._s[3728]! }
    public var Location_ProximityNotification_DistanceMI: String { return self._s[3731]! }
    public var PhotoEditor_ExposureTool: String { return self._s[3732]! }
    public var Group_Username_CreatePrivateLinkHelp: String { return self._s[3733]! }
    public var SettingsSearch_Synonyms_Watch: String { return self._s[3734]! }
    public var Stats_GroupTopPoster_History: String { return self._s[3735]! }
    public var UserInfo_AddPhone: String { return self._s[3736]! }
    public var Media_SendWithTimer: String { return self._s[3738]! }
    public var SettingsSearch_Synonyms_Notifications_Title: String { return self._s[3739]! }
    public var Channel_EditAdmin_PermissionEnabledByDefault: String { return self._s[3740]! }
    public var GroupInfo_GroupHistoryShort: String { return self._s[3741]! }
    public var PasscodeSettings_AutoLock_Disabled: String { return self._s[3742]! }
    public var ChatList_Context_Unarchive: String { return self._s[3744]! }
    public func DialogList_LiveLocationSharingTo(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3745]!, self._r[3745]!, [_0])
    }
    public var BlockedUsers_Title: String { return self._s[3747]! }
    public var TwoStepAuth_EmailPlaceholder: String { return self._s[3748]! }
    public var Media_ShareThisPhoto: String { return self._s[3749]! }
    public var Notifications_DisplayNamesOnLockScreen: String { return self._s[3750]! }
    public var Conversation_FilePhotoOrVideo: String { return self._s[3751]! }
    public var Appearance_ThemePreview_Chat_2_ReplyName: String { return self._s[3755]! }
    public var CallFeedback_ReasonNoise: String { return self._s[3757]! }
    public var WebBrowser_Title: String { return self._s[3758]! }
    public func Checkout_SavePasswordTimeoutAndTouchId(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3759]!, self._r[3759]!, [_0])
    }
    public var Notification_MessageLifetime5s: String { return self._s[3761]! }
    public var Passport_Address_AddResidentialAddress: String { return self._s[3762]! }
    public var Profile_MessageLifetime1m: String { return self._s[3764]! }
    public var Passport_ScanPassport: String { return self._s[3765]! }
    public var Stats_LoadingTitle: String { return self._s[3766]! }
    public var Passport_Address_AddTemporaryRegistration: String { return self._s[3768]! }
    public var Permissions_NotificationsAllow_v0: String { return self._s[3769]! }
    public var Login_InvalidFirstNameError: String { return self._s[3770]! }
    public var Undo_ChatCleared: String { return self._s[3772]! }
    public func ApplyLanguage_ChangeLanguageUnofficialText(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3774]!, self._r[3774]!, [_1, _2])
    }
    public var Conversation_PinMessageAlertPin: String { return self._s[3775]! }
    public func Login_PhoneBannedEmailBody(_ _1: String, _ _2: String, _ _3: String, _ _4: String, _ _5: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3776]!, self._r[3776]!, [_1, _2, _3, _4, _5])
    }
    public func PUSH_MESSAGE_FWD(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3777]!, self._r[3777]!, [_1])
    }
    public var Share_MultipleMessagesDisabled: String { return self._s[3778]! }
    public var TwoStepAuth_EmailInvalid: String { return self._s[3779]! }
    public var EnterPasscode_ChangeTitle: String { return self._s[3781]! }
    public var VoiceChat_InviteLink_Speaker: String { return self._s[3782]! }
    public var CallSettings_RecentCalls: String { return self._s[3783]! }
    public var GroupInfo_DeactivatedStatus: String { return self._s[3784]! }
    public var AuthSessions_OtherSessions: String { return self._s[3785]! }
    public var PrivacyLastSeenSettings_CustomHelp: String { return self._s[3786]! }
    public var Tour_Text5: String { return self._s[3787]! }
    public var Login_PadPhoneHelp: String { return self._s[3788]! }
    public var Wallpaper_PhotoLibrary: String { return self._s[3791]! }
    public var Conversation_ViewGroup: String { return self._s[3792]! }
    public var PeopleNearby_MakeVisibleTitle: String { return self._s[3794]! }
    public var VoiceOver_Chat_YourContact: String { return self._s[3795]! }
    public var Watch_AuthRequired: String { return self._s[3796]! }
    public var VoiceOver_Chat_ForwardedFromYou: String { return self._s[3798]! }
    public var Conversation_ForwardContacts: String { return self._s[3799]! }
    public var Conversation_InputTextPlaceholder: String { return self._s[3800]! }
    public func PUSH_CHANNEL_MESSAGE_PHOTO(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3801]!, self._r[3801]!, [_1])
    }
    public func Conversation_MessageViaUser(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3802]!, self._r[3802]!, [_0])
    }
    public var Channel_Setup_TypePrivate: String { return self._s[3803]! }
    public func Conversation_NoticeInvitedByInChannel(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3804]!, self._r[3804]!, [_0])
    }
    public var Checkout_OptionalTipItemPlaceholder: String { return self._s[3805]! }
    public var InviteLink_Create_TimeLimitExpiryDate: String { return self._s[3806]! }
    public var InfoPlist_NSSiriUsageDescription: String { return self._s[3807]! }
    public var AutoDownloadSettings_Delimeter: String { return self._s[3808]! }
    public var EmptyGroupInfo_Subtitle: String { return self._s[3809]! }
    public var UserInfo_StartSecretChatStart: String { return self._s[3810]! }
    public func GroupPermission_AddedInfo(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3811]!, self._r[3811]!, [_1, _2])
    }
    public func Channel_AdminLog_MessageRestricted(_ _0: String, _ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3812]!, self._r[3812]!, [_0, _1, _2])
    }
    public func Conversation_ForwardTooltip_TwoChats_Many(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3813]!, self._r[3813]!, [_0, _1])
    }
    public var PrivacySettings_AutoArchiveTitle: String { return self._s[3814]! }
    public var GroupInfo_InviteLink_LinkSection: String { return self._s[3815]! }
    public var FastTwoStepSetup_EmailPlaceholder: String { return self._s[3816]! }
    public var StickerPacksSettings_ArchivedMasks: String { return self._s[3818]! }
    public var NewContact_Title: String { return self._s[3821]! }
    public var Appearance_ThemeCarouselTintedNight: String { return self._s[3822]! }
    public var VoiceChat_StatusSpeaking: String { return self._s[3823]! }
    public var Notifications_PermissionsKeepDisabled: String { return self._s[3824]! }
    public func Time_YesterdayAt(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3825]!, self._r[3825]!, [_0])
    }
    public func AutoNightTheme_LocationHelp(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3826]!, self._r[3826]!, [_0, _1])
    }
    public var Chat_SlowmodeTooltipPending: String { return self._s[3827]! }
    public func Time_MediumDate(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3829]!, self._r[3829]!, [_1, _2])
    }
    public var ContactInfo_PhoneLabelHome: String { return self._s[3830]! }
    public var CallFeedback_ReasonInterruption: String { return self._s[3831]! }
    public var Passport_Identity_OneOfTypeDriversLicense: String { return self._s[3832]! }
    public var Conversation_MessageEditedLabel: String { return self._s[3835]! }
    public var CallList_ActiveVoiceChatsHeader: String { return self._s[3836]! }
    public var SocksProxySetup_PasswordPlaceholder: String { return self._s[3837]! }
    public var ChatList_Context_AddToContacts: String { return self._s[3838]! }
    public var Passport_Language_is: String { return self._s[3839]! }
    public var Notification_PassportValueProofOfIdentity: String { return self._s[3840]! }
    public var PhotoEditor_CurvesBlue: String { return self._s[3841]! }
    public func FileSize_MB(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3842]!, self._r[3842]!, [_0])
    }
    public var SocksProxySetup_Username: String { return self._s[3843]! }
    public var Login_SmsRequestState3: String { return self._s[3844]! }
    public var Message_PinnedVideoMessage: String { return self._s[3845]! }
    public var SharedMedia_TitleLink: String { return self._s[3846]! }
    public var Passport_FieldIdentity: String { return self._s[3847]! }
    public var GroupInfo_Permissions_BroadcastConvert: String { return self._s[3849]! }
    public func Conversation_EncryptedPlaceholderTitleOutgoing(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3852]!, self._r[3852]!, [_0])
    }
    public var DialogList_ProxyConnectionIssuesTooltip: String { return self._s[3855]! }
    public var ReportSpam_DeleteThisChat: String { return self._s[3856]! }
    public var Checkout_NewCard_CardholderNamePlaceholder: String { return self._s[3857]! }
    public var Passport_Identity_DateOfBirth: String { return self._s[3858]! }
    public var Call_StatusIncoming: String { return self._s[3859]! }
    public var ChatAdmins_AdminLabel: String { return self._s[3860]! }
    public func InstantPage_OpenInBrowser(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3861]!, self._r[3861]!, [_0])
    }
    public func Time_MonthOfYear_m10(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3863]!, self._r[3863]!, [_0])
    }
    public var Message_PinnedAnimationMessage: String { return self._s[3864]! }
    public var Conversation_ReportSpamAndLeave: String { return self._s[3865]! }
    public var Preview_CopyAddress: String { return self._s[3866]! }
    public var MediaPlayer_UnknownTrack: String { return self._s[3868]! }
    public var Login_CancelSignUpConfirmation: String { return self._s[3869]! }
    public var Map_OpenInYandexMaps: String { return self._s[3871]! }
    public func Time_PreciseDate_m11(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3874]!, self._r[3874]!, [_1, _2, _3])
    }
    public var GroupRemoved_Remove: String { return self._s[3875]! }
    public var ChatListFolder_TitleCreate: String { return self._s[3876]! }
    public func InstantPage_AuthorAndDateTitle(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3878]!, self._r[3878]!, [_1, _2])
    }
    public var Watch_UserInfo_MuteTitle: String { return self._s[3879]! }
    public func UserInfo_LinkForwardTooltip_TwoChats_One(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3881]!, self._r[3881]!, [_0, _1])
    }
    public var Group_UpgradeNoticeText2: String { return self._s[3882]! }
    public var Stats_GroupGrowthTitle: String { return self._s[3883]! }
    public var CreatePoll_CancelConfirmation: String { return self._s[3886]! }
    public var Month_GenOctober: String { return self._s[3887]! }
    public var Conversation_TitleCommentsEmpty: String { return self._s[3888]! }
    public var Settings_Appearance: String { return self._s[3889]! }
    public func Time_MonthOfYear_m6(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3890]!, self._r[3890]!, [_0])
    }
    public var UserInfo_AddToExisting: String { return self._s[3891]! }
    public var Call_PhoneCallInProgressMessage: String { return self._s[3893]! }
    public var Map_HomeAndWorkInfo: String { return self._s[3894]! }
    public var InstantPage_VoiceOver_ResetFontSize: String { return self._s[3895]! }
    public var Paint_Arrow: String { return self._s[3896]! }
    public var InviteLink_CreatePrivateLinkHelp: String { return self._s[3897]! }
    public func DialogList_MultipleTypingPair(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3898]!, self._r[3898]!, [_0, _1])
    }
    public var CancelResetAccount_Title: String { return self._s[3899]! }
    public var NotificationsSound_Circles: String { return self._s[3900]! }
    public var Notifications_GroupNotificationsExceptionsHelp: String { return self._s[3901]! }
    public var ChatState_Connecting: String { return self._s[3903]! }
    public var Profile_MessageLifetime5s: String { return self._s[3904]! }
    public func DialogList_AwaitingEncryption(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3905]!, self._r[3905]!, [_0])
    }
    public var PrivacyPolicy_AgeVerificationTitle: String { return self._s[3906]! }
    public var Channel_Username_CreatePublicLinkHelp: String { return self._s[3907]! }
    public var AutoNightTheme_ScheduledTo: String { return self._s[3908]! }
    public var Conversation_DefaultRestrictedStickers: String { return self._s[3910]! }
    public var TwoStepAuth_ConfirmationTitle: String { return self._s[3911]! }
    public func Chat_UnsendMyMessagesAlertTitle(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3912]!, self._r[3912]!, [_0])
    }
    public var Passport_Phone_Help: String { return self._s[3913]! }
    public var Privacy_ContactsSync: String { return self._s[3914]! }
    public var CheckoutInfo_ReceiverInfoPhone: String { return self._s[3915]! }
    public var Channel_AdminLogFilter_EventsLeavingSubscribers: String { return self._s[3917]! }
    public var Map_SendMyCurrentLocation: String { return self._s[3918]! }
    public var Map_AddressOnMap: String { return self._s[3919]! }
    public var BroadcastGroups_ConfirmationAlert_Convert: String { return self._s[3921]! }
    public var DialogList_SearchLabel: String { return self._s[3922]! }
    public var Notification_Exceptions_NewException_NotificationHeader: String { return self._s[3923]! }
    public var GroupInfo_FakeGroupWarning: String { return self._s[3924]! }
    public var Conversation_ChecksTooltip_Read: String { return self._s[3926]! }
    public var ConversationProfile_UnknownAddMemberError: String { return self._s[3928]! }
    public var ChatList_Search_ShowMore: String { return self._s[3929]! }
    public var DialogList_EncryptionRejected: String { return self._s[3930]! }
    public var VoiceChat_InviteLinkCopiedText: String { return self._s[3931]! }
    public var DialogList_DeleteBotConfirmation: String { return self._s[3932]! }
    public var VoiceChat_StartRecordingText: String { return self._s[3933]! }
    public var Privacy_TopPeersDelete: String { return self._s[3934]! }
    public var AttachmentMenu_SendAsFile: String { return self._s[3936]! }
    public var ChatList_GenericPsaAlert: String { return self._s[3938]! }
    public var SecretTimer_ImageDescription: String { return self._s[3940]! }
    public func Conversation_SetReminder_RemindOn(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3941]!, self._r[3941]!, [_0, _1])
    }
    public var VoiceChat_EditNameSuccess: String { return self._s[3942]! }
    public var ChatSettings_TextSizeUnits: String { return self._s[3943]! }
    public var Notification_RenamedGroup: String { return self._s[3945]! }
    public var Tour_Title2: String { return self._s[3946]! }
    public var Settings_CopyUsername: String { return self._s[3947]! }
    public var Compose_NewEncryptedChat: String { return self._s[3948]! }
    public var Conversation_CloudStorageInfo_Title: String { return self._s[3949]! }
    public var VoiceChat_SetReminder: String { return self._s[3950]! }
    public var Month_ShortSeptember: String { return self._s[3951]! }
    public var AutoDownloadSettings_OnForAll: String { return self._s[3952]! }
    public var ChatList_DeleteForEveryoneConfirmationText: String { return self._s[3953]! }
    public var VoiceChat_StartNow: String { return self._s[3954]! }
    public var Call_StatusConnecting: String { return self._s[3956]! }
    public var Privacy_GroupsAndChannels_NeverAllow_Placeholder: String { return self._s[3957]! }
    public var Map_ShareLiveLocationHelp: String { return self._s[3958]! }
    public var Cache_Files: String { return self._s[3959]! }
    public var Notifications_Reset: String { return self._s[3960]! }
    public func Settings_KeepPhoneNumber(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3961]!, self._r[3961]!, [_0])
    }
    public var Privacy_GroupsAndChannels_AlwaysAllow_Title: String { return self._s[3962]! }
    public func Conversation_OpenBotLinkLogin(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3963]!, self._r[3963]!, [_1, _2])
    }
    public var Notification_CallIncomingShort: String { return self._s[3964]! }
    public var UserInfo_BotPrivacy: String { return self._s[3967]! }
    public var Appearance_BubbleCorners_Apply: String { return self._s[3968]! }
    public var WebSearch_RecentClearConfirmation: String { return self._s[3969]! }
    public var Conversation_ContextMenuLookUp: String { return self._s[3971]! }
    public var Calls_RatingTitle: String { return self._s[3972]! }
    public var SecretImage_Title: String { return self._s[3973]! }
    public var Weekday_Monday: String { return self._s[3974]! }
    public func Passport_PrivacyPolicy(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3975]!, self._r[3975]!, [_1, _2])
    }
    public var KeyCommand_JumpToPreviousChat: String { return self._s[3976]! }
    public var VoiceChat_InviteLink_CopySpeakerLink: String { return self._s[3977]! }
    public var Invitation_JoinVoiceChatAsListener: String { return self._s[3978]! }
    public func DialogList_SearchSubtitleFormat(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3979]!, self._r[3979]!, [_1, _2])
    }
    public var Stats_GroupMembers: String { return self._s[3980]! }
    public var Camera_Retake: String { return self._s[3981]! }
    public var Conversation_SearchPlaceholder: String { return self._s[3983]! }
    public func Passport_Identity_NativeNameGenericHelp(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3984]!, self._r[3984]!, [_0])
    }
    public var Channel_DiscussionGroup_Info: String { return self._s[3985]! }
    public var SocksProxySetup_Hostname: String { return self._s[3986]! }
    public var PrivacyLastSeenSettings_EmpryUsersPlaceholder: String { return self._s[3987]! }
    public var Privacy_DeleteDrafts: String { return self._s[3989]! }
    public var Login_CancelPhoneVerification: String { return self._s[3991]! }
    public var TwoStepAuth_ResetAccountHelp: String { return self._s[3992]! }
    public var VoiceOver_Chat_Profile: String { return self._s[3993]! }
    public func SocksProxySetup_ProxyStatusPing(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3994]!, self._r[3994]!, [_0])
    }
    public var TwoStepAuth_EmailSent: String { return self._s[3995]! }
    public var Cache_Indexing: String { return self._s[3996]! }
    public var Notifications_ExceptionsNone: String { return self._s[3997]! }
    public var MessagePoll_LabelQuiz: String { return self._s[3998]! }
    public var Call_EncryptionKey_Title: String { return self._s[3999]! }
    public var Common_Yes: String { return self._s[4000]! }
    public var Channel_ErrorAddBlocked: String { return self._s[4001]! }
    public var Month_GenJanuary: String { return self._s[4002]! }
    public var Checkout_NewCard_Title: String { return self._s[4003]! }
    public func TwoStepAuth_EnterPasswordHint(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4004]!, self._r[4004]!, [_0])
    }
    public var Conversation_InputTextPlaceholderReply: String { return self._s[4006]! }
    public var PasscodeSettings_AutoLock_IfAwayFor_1hour: String { return self._s[4007]! }
    public var Conversation_SendDice: String { return self._s[4008]! }
    public func ChatSettings_AutoDownloadSettings_TypeVideo(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4009]!, self._r[4009]!, [_0])
    }
    public func VoiceOver_Chat_VideoFrom(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4010]!, self._r[4010]!, [_0])
    }
    public var Weekday_Wednesday: String { return self._s[4011]! }
    public var ReportPeer_ReasonOther_Send: String { return self._s[4012]! }
    public var PasscodeSettings_EncryptDataHelp: String { return self._s[4013]! }
    public var PrivacyLastSeenSettings_CustomShareSettingsHelp: String { return self._s[4014]! }
    public var OldChannels_NoticeTitle: String { return self._s[4015]! }
    public var TwoStepAuth_ChangeEmail: String { return self._s[4016]! }
    public var PasscodeSettings_PasscodeOptions: String { return self._s[4017]! }
    public var InfoPlist_NSPhotoLibraryUsageDescription: String { return self._s[4018]! }
    public var Passport_Address_AddUtilityBill: String { return self._s[4019]! }
    public func Time_PreciseDate_m5(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4021]!, self._r[4021]!, [_1, _2, _3])
    }
    public var TwoFactorSetup_EmailVerification_ResendAction: String { return self._s[4023]! }
    public var Stats_GroupTopAdminsTitle: String { return self._s[4024]! }
    public var Paint_Regular: String { return self._s[4026]! }
    public var Message_Contact: String { return self._s[4027]! }
    public var NetworkUsageSettings_MediaVideoDataSection: String { return self._s[4028]! }
    public var VoiceOver_Chat_YourPhoto: String { return self._s[4029]! }
    public var Notification_Mute1hMin: String { return self._s[4030]! }
    public func Login_BannedPhoneSubject(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4031]!, self._r[4031]!, [_0])
    }
    public var Profile_MessageLifetime1h: String { return self._s[4032]! }
    public var TwoStepAuth_GenericHelp: String { return self._s[4033]! }
    public var TextFormat_Monospace: String { return self._s[4034]! }
    public var VoiceOver_Media_PlaybackRateChange: String { return self._s[4036]! }
    public var Conversation_DeleteMessagesForMe: String { return self._s[4037]! }
    public var ChatList_DeleteChat: String { return self._s[4038]! }
    public var Channel_OwnershipTransfer_EnterPasswordText: String { return self._s[4041]! }
    public func Settings_ApplyProxyAlertCredentials(_ _1: String, _ _2: String, _ _3: String, _ _4: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4042]!, self._r[4042]!, [_1, _2, _3, _4])
    }
    public var Login_CancelPhoneVerificationStop: String { return self._s[4043]! }
    public var Appearance_ThemePreview_ChatList_4_Name: String { return self._s[4044]! }
    public var MediaPicker_MomentsDateRangeSameMonthYearFormat: String { return self._s[4045]! }
    public func Channel_AdminLog_MessageToggleInvitesOn(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4046]!, self._r[4046]!, [_0])
    }
    public var Notifications_Badge_IncludeChannels: String { return self._s[4047]! }
    public var InviteLink_CreatePrivateLinkHelpChannel: String { return self._s[4048]! }
    public var StickerPack_ViewPack: String { return self._s[4051]! }
    public var FastTwoStepSetup_PasswordConfirmationPlaceholder: String { return self._s[4053]! }
    public var EditTheme_Expand_Preview_IncomingText: String { return self._s[4054]! }
    public var Notifications_Title: String { return self._s[4055]! }
    public var Conversation_InputTextPlaceholderComment: String { return self._s[4056]! }
    public var GroupInfo_PublicLink: String { return self._s[4057]! }
    public func ScheduleVoiceChat_GroupText(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4058]!, self._r[4058]!, [_0])
    }
    public var VoiceOver_DiscardPreparedContent: String { return self._s[4059]! }
    public var Conversation_Moderate_Ban: String { return self._s[4063]! }
    public var InviteLink_Manage: String { return self._s[4064]! }
    public var InstantPage_FontNewYork: String { return self._s[4065]! }
    public func Activity_RemindAboutGroup(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4066]!, self._r[4066]!, [_0])
    }
    public var TextFormat_Underline: String { return self._s[4067]! }
    public func DownloadingStatus(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4068]!, self._r[4068]!, [_0, _1])
    }
    public func PUSH_PINNED_ROUND(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4069]!, self._r[4069]!, [_1])
    }
    public var PollResults_Collapse: String { return self._s[4071]! }
    public var Contacts_GlobalSearch: String { return self._s[4072]! }
    public func Conversation_EncryptionWaiting(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4074]!, self._r[4074]!, [_0])
    }
    public var Channel_Management_LabelEditor: String { return self._s[4075]! }
    public var SettingsSearch_Synonyms_Stickers_FeaturedPacks: String { return self._s[4077]! }
    public var Conversation_Theme: String { return self._s[4078]! }
    public func PUSH_CHANNEL_MESSAGE_DOCS(_ _1: String, _ _2: Int) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4079]!, self._r[4079]!, [_1, "\(_2)"])
    }
    public var Conversation_LinkDialogSave: String { return self._s[4080]! }
    public var EnterPasscode_TouchId: String { return self._s[4081]! }
    public var Conversation_VoiceChatMediaRecordingRestricted: String { return self._s[4082]! }
    public var Group_ErrorAdminsTooMuch: String { return self._s[4083]! }
    public var Stats_MessageOverview: String { return self._s[4084]! }
    public var Privacy_Calls_P2PAlways: String { return self._s[4086]! }
    public var Message_Sticker: String { return self._s[4087]! }
    public var Conversation_Mute: String { return self._s[4090]! }
    public var VoiceChat_AnonymousDisabledAlertText: String { return self._s[4091]! }
    public var ContactInfo_Title: String { return self._s[4092]! }
    public func PUSH_CHANNEL_MESSAGE_CONTACT(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4093]!, self._r[4093]!, [_1])
    }
    public var Channel_Setup_TypeHeader: String { return self._s[4094]! }
    public var AuthSessions_LogOut: String { return self._s[4095]! }
    public var ChatSettings_AutoDownloadReset: String { return self._s[4096]! }
    public var VoiceChat_PinVideo: String { return self._s[4097]! }
    public var Group_Info_Members: String { return self._s[4099]! }
    public var ChatListFolderSettings_NewFolder: String { return self._s[4100]! }
    public var Appearance_ThemePreview_ChatList_3_AuthorName: String { return self._s[4101]! }
    public var CreatePoll_Title: String { return self._s[4102]! }
    public var EditTheme_EditTitle: String { return self._s[4103]! }
    public var ChatListFolderSettings_RecommendedFoldersSection: String { return self._s[4104]! }
    public var TwoStepAuth_SetPassword: String { return self._s[4105]! }
    public func Login_InvalidPhoneEmailSubject(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4106]!, self._r[4106]!, [_0])
    }
    public var BlockedUsers_Info: String { return self._s[4107]! }
    public var AuthSessions_Sessions: String { return self._s[4108]! }
    public var Group_EditAdmin_RankTitle: String { return self._s[4109]! }
    public var Common_ActionNotAllowedError: String { return self._s[4110]! }
    public var WebPreview_GettingLinkInfo: String { return self._s[4111]! }
    public var Appearance_AppIconFilledX: String { return self._s[4112]! }
    public var Passport_Email_EmailPlaceholder: String { return self._s[4113]! }
    public var FeaturedStickers_OtherSection: String { return self._s[4114]! }
    public var VoiceChat_RecordingStarted: String { return self._s[4115]! }
    public var EditTheme_Edit_Preview_OutgoingText: String { return self._s[4116]! }
    public var Profile_Username: String { return self._s[4117]! }
    public var Appearance_RemoveTheme: String { return self._s[4118]! }
    public var TwoStepAuth_SetupPasswordConfirmPassword: String { return self._s[4119]! }
    public var Message_PinnedStickerMessage: String { return self._s[4120]! }
    public var AccessDenied_VideoMicrophone: String { return self._s[4121]! }
    public var WallpaperPreview_CustomColorBottomText: String { return self._s[4122]! }
    public var Passport_Address_RegionPlaceholder: String { return self._s[4123]! }
    public var Conversation_VoiceChat: String { return self._s[4124]! }
    public var VoiceChat_EditBioSuccess: String { return self._s[4125]! }
    public var SettingsSearch_Synonyms_Data_Storage_Title: String { return self._s[4126]! }
    public var TwoStepAuth_Title: String { return self._s[4127]! }
    public var VoiceOver_Chat_YourAnimatedSticker: String { return self._s[4128]! }
    public var Checkout_WebConfirmation_Title: String { return self._s[4129]! }
    public var AutoDownloadSettings_VoiceMessagesInfo: String { return self._s[4130]! }
    public var ChatListFolder_CategoryGroups: String { return self._s[4132]! }
    public var Stats_GroupTopInviter_Promote: String { return self._s[4133]! }
    public var Conversation_EditingPhotoPanelTitle: String { return self._s[4134]! }
    public var Month_GenJuly: String { return self._s[4135]! }
    public var Passport_Identity_Gender: String { return self._s[4136]! }
    public var Channel_DiscussionGroup_UnlinkGroup: String { return self._s[4137]! }
    public var Notification_Exceptions_DeleteAll: String { return self._s[4138]! }
    public var VoiceChat_StopRecording: String { return self._s[4139]! }
    public func Conversation_FileHowToText(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4140]!, self._r[4140]!, [_0])
    }
    public func Channel_AdminLog_MessageAdmin(_ _0: String, _ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4141]!, self._r[4141]!, [_0, _1, _2])
    }
    public var Login_CodeSentSms: String { return self._s[4142]! }
    public func VoiceOver_Chat_ReplyFrom(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4143]!, self._r[4143]!, [_0])
    }
    public var Login_CallRequestState2: String { return self._s[4144]! }
    public var Channel_DiscussionGroup_Header: String { return self._s[4145]! }
    public func Channel_AdminLog_MessageToggleInvitesOff(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4146]!, self._r[4146]!, [_0])
    }
    public var Passport_Language_ms: String { return self._s[4147]! }
    public var PeopleNearby_MakeInvisible: String { return self._s[4149]! }
    public var ChatList_Search_FilterVoice: String { return self._s[4151]! }
    public var Camera_TapAndHoldForVideo: String { return self._s[4153]! }
    public var Permissions_NotificationsAllowInSettings_v0: String { return self._s[4154]! }
    public func Notification_LeftChannel(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4155]!, self._r[4155]!, [_0])
    }
    public func Call_VoiceChatInProgressMessageCall(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4156]!, self._r[4156]!, [_1, _2])
    }
    public var Map_Locating: String { return self._s[4157]! }
    public func Checkout_SavePasswordTimeout(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4159]!, self._r[4159]!, [_0])
    }
    public var Passport_Identity_TypeInternalPassport: String { return self._s[4161]! }
    public var Appearance_ThemePreview_Chat_4_Text: String { return self._s[4162]! }
    public var SettingsSearch_Synonyms_EditProfile_Username: String { return self._s[4163]! }
    public var Stickers_Installed: String { return self._s[4164]! }
    public var Notifications_PermissionsAllowInSettings: String { return self._s[4165]! }
    public var StickerPackActionInfo_RemovedTitle: String { return self._s[4166]! }
    public var CallSettings_Never: String { return self._s[4168]! }
    public var Channel_Setup_TypePublicHelp: String { return self._s[4169]! }
    public func ChatList_DeleteForEveryone(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4171]!, self._r[4171]!, [_0])
    }
    public var Message_Game: String { return self._s[4172]! }
    public var Call_Message: String { return self._s[4173]! }
    public func PUSH_CHANNEL_MESSAGE_VIDEO(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4174]!, self._r[4174]!, [_1])
    }
    public var ChannelIntro_Text: String { return self._s[4175]! }
    public var StickerPack_Send: String { return self._s[4176]! }
    public var Share_AuthDescription: String { return self._s[4177]! }
    public var PasscodeSettings_AutoLock_IfAwayFor_5minutes: String { return self._s[4178]! }
    public var CallFeedback_WhatWentWrong: String { return self._s[4179]! }
    public var Common_Create: String { return self._s[4182]! }
    public var Passport_Language_hy: String { return self._s[4183]! }
    public var CreatePoll_Explanation: String { return self._s[4184]! }
    public var GroupPermission_AddMembersNotAvailable: String { return self._s[4185]! }
    public var ChatImport_CreateGroupAlertImportAction: String { return self._s[4186]! }
    public var PeerInfo_ButtonVoiceChat: String { return self._s[4187]! }
    public var Undo_ChatClearedForBothSides: String { return self._s[4188]! }
    public var DialogList_NoMessagesTitle: String { return self._s[4189]! }
    public var GroupInfo_Title: String { return self._s[4191]! }
    public func ScheduleVoiceChat_ScheduleToday(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4192]!, self._r[4192]!, [_0])
    }
    public var UserInfo_ContactForwardTooltip_SavedMessages_One: String { return self._s[4193]! }
    public var Channel_AdminLog_CanBanUsers: String { return self._s[4194]! }
    public var PhoneNumberHelp_Help: String { return self._s[4195]! }
    public var TwoStepAuth_AdditionalPassword: String { return self._s[4196]! }
    public var Settings_Logout: String { return self._s[4197]! }
    public var Privacy_PaymentsTitle: String { return self._s[4198]! }
    public var StickerPacksSettings_StickerPacksSection: String { return self._s[4199]! }
    public var Tour_Text6: String { return self._s[4200]! }
    public var ChatImportActivity_Title: String { return self._s[4202]! }
    public var Channel_Username_Help: String { return self._s[4203]! }
    public var VoiceOver_Chat_RecordModeVoiceMessageInfo: String { return self._s[4204]! }
    public var AttachmentMenu_Poll: String { return self._s[4205]! }
    public var EditTheme_Create_Preview_IncomingReplyName: String { return self._s[4206]! }
    public var Conversation_ReportSpamChannelConfirmation: String { return self._s[4207]! }
    public var Passport_DeletePassport: String { return self._s[4208]! }
    public var Login_Code: String { return self._s[4209]! }
    public var Notification_SecretChatScreenshot: String { return self._s[4210]! }
    public var VoiceChat_AddBio: String { return self._s[4211]! }
    public var Login_CodeFloodError: String { return self._s[4212]! }
    public func Notification_PinnedAnimationMessage(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4213]!, self._r[4213]!, [_0])
    }
    public func Channel_Username_UsernameIsAvailable(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4214]!, self._r[4214]!, [_0])
    }
    public var Watch_Stickers_Recents: String { return self._s[4215]! }
    public var Generic_ErrorMoreInfo: String { return self._s[4216]! }
    public func Call_AccountIsLoggedOnCurrentDevice(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4217]!, self._r[4217]!, [_0])
    }
    public var AutoDownloadSettings_DataUsage: String { return self._s[4218]! }
    public var Conversation_ViewTheme: String { return self._s[4219]! }
    public var Contacts_InviteSearchLabel: String { return self._s[4220]! }
    public var Settings_CancelUpload: String { return self._s[4222]! }
    public var Settings_AppLanguage_Unofficial: String { return self._s[4223]! }
    public func ChatList_ClearChatConfirmation(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4224]!, self._r[4224]!, [_0])
    }
    public var ChatList_AddFolder: String { return self._s[4225]! }
    public var Conversation_Location: String { return self._s[4227]! }
    public var Appearance_BubbleCorners_AdjustAdjacent: String { return self._s[4228]! }
    public var DialogList_AdLabel: String { return self._s[4229]! }
    public func Time_TomorrowAt(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4231]!, self._r[4231]!, [_0])
    }
    public var Message_InvoiceLabel: String { return self._s[4232]! }
    public var Channel_TooMuchBots: String { return self._s[4233]! }
    public func Channel_AdminLog_MessageRemovedChannelUsername(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4235]!, self._r[4235]!, [_0])
    }
    public var Call_IncomingVideoCall: String { return self._s[4236]! }
    public var Conversation_LiveLocation: String { return self._s[4237]! }
    public var VoiceChat_AskedToSpeakHelp: String { return self._s[4238]! }
    public var TwoStepAuth_SetupPasswordEnterPasswordChange: String { return self._s[4239]! }
    public var Passport_Identity_EditPassport: String { return self._s[4240]! }
    public var Permissions_CellularDataTitle_v0: String { return self._s[4242]! }
    public var ChatList_Search_NoResultsFitlerVoice: String { return self._s[4243]! }
    public var GroupInfo_Permissions_AddException: String { return self._s[4244]! }
    public func VoiceChat_RemovePeerConfirmationChannel(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4246]!, self._r[4246]!, [_0])
    }
    public var Channel_AdminLog_CanInviteUsers: String { return self._s[4247]! }
    public var Channel_MessageVideoUpdated: String { return self._s[4248]! }
    public var GroupInfo_Permissions_EditingDisabled: String { return self._s[4249]! }
    public var AutoremoveSetup_TimeSectionHeader: String { return self._s[4252]! }
    public var AccessDenied_Camera: String { return self._s[4253]! }
    public func Target_InviteToGroupConfirmation(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4254]!, self._r[4254]!, [_0])
    }
    public var Theme_Context_ChangeColors: String { return self._s[4255]! }
    public var PrivacySettings_TwoStepAuth: String { return self._s[4256]! }
    public var Privacy_Forwards_PreviewMessageText: String { return self._s[4257]! }
    public var Login_CodeExpiredError: String { return self._s[4258]! }
    public var State_ConnectingToProxy: String { return self._s[4259]! }
    public var TextFormat_Link: String { return self._s[4260]! }
    public var Passport_Language_lv: String { return self._s[4262]! }
    public var Conversation_AutoremoveTimerRemovedGroup: String { return self._s[4263]! }
    public var AccessDenied_VoiceMicrophone: String { return self._s[4264]! }
    public var WallpaperPreview_SwipeBottomText: String { return self._s[4265]! }
    public var ProfilePhoto_SetMainVideo: String { return self._s[4266]! }
    public var AutoDownloadSettings_Cellular: String { return self._s[4268]! }
    public var ChatSettings_AutoDownloadVoiceMessages: String { return self._s[4269]! }
    public func Channel_AdminLog_MessageKickedNameUsername(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4270]!, self._r[4270]!, [_1, _2])
    }
    public var ChatList_EmptyChatListFilterTitle: String { return self._s[4271]! }
    public var Checkout_PayNone: String { return self._s[4272]! }
    public var NotificationsSound_Complete: String { return self._s[4274]! }
    public var TwoStepAuth_ConfirmEmailCodePlaceholder: String { return self._s[4275]! }
    public var InviteLink_CreateInfo: String { return self._s[4276]! }
    public var AuthSessions_DevicesTitle: String { return self._s[4277]! }
    public func DialogList_MultipleTyping(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4278]!, self._r[4278]!, [_0, _1])
    }
    public var Message_LiveLocation: String { return self._s[4279]! }
    public var Watch_Suggestion_BRB: String { return self._s[4280]! }
    public var Channel_BanUser_Title: String { return self._s[4281]! }
    public var SettingsSearch_Synonyms_Privacy_Data_Title: String { return self._s[4282]! }
    public var Conversation_Dice_u1F3C0: String { return self._s[4283]! }
    public var Conversation_ClearSelfHistory: String { return self._s[4284]! }
    public var ProfilePhoto_OpenGallery: String { return self._s[4285]! }
    public var PrivacySettings_LastSeenTitle: String { return self._s[4286]! }
    public var Weekday_Thursday: String { return self._s[4287]! }
    public var BroadcastListInfo_AddRecipient: String { return self._s[4288]! }
    public var Privacy_ProfilePhoto: String { return self._s[4290]! }
    public var StickerPacksSettings_ArchivedPacks_Info: String { return self._s[4291]! }
    public func Channel_AdminLog_MessageChangedUnlinkedGroup(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4292]!, self._r[4292]!, [_1, _2])
    }
    public var Message_Audio: String { return self._s[4293]! }
    public var Conversation_Info: String { return self._s[4294]! }
    public var Cache_Videos: String { return self._s[4295]! }
    public var Appearance_ThemePreview_ChatList_6_Text: String { return self._s[4296]! }
    public var Channel_ErrorAddTooMuch: String { return self._s[4297]! }
    public func ChatList_DeleteSecretChatConfirmation(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4298]!, self._r[4298]!, [_0])
    }
    public var VoiceChat_EditBio: String { return self._s[4299]! }
    public var ChannelMembers_ChannelAdminsTitle: String { return self._s[4301]! }
    public var ScheduledMessages_Title: String { return self._s[4304]! }
    public var ShareFileTip_Title: String { return self._s[4307]! }
    public var Chat_Gifs_TrendingSectionHeader: String { return self._s[4308]! }
    public var ChatList_RemoveFolderConfirmation: String { return self._s[4309]! }
    public func PUSH_CHAT_MESSAGE_GEOLIVE(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4310]!, self._r[4310]!, [_1, _2])
    }
    public var Conversation_ContextViewStats: String { return self._s[4312]! }
    public var Channel_DiscussionGroup_SearchPlaceholder: String { return self._s[4313]! }
    public var PasscodeSettings_Title: String { return self._s[4314]! }
    public var Channel_AdminLog_SendPolls: String { return self._s[4315]! }
    public var LastSeen_ALongTimeAgo: String { return self._s[4316]! }
    public func PUSH_CHANNEL_MESSAGE_GIF(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4317]!, self._r[4317]!, [_1])
    }
    public var SettingsSearch_Synonyms_Notifications_BadgeIncludeMutedChannels: String { return self._s[4318]! }
    public var ChannelInfo_FakeChannelWarning: String { return self._s[4319]! }
    public var CallFeedback_VideoReasonLowQuality: String { return self._s[4320]! }
    public var Conversation_PinnedPreviousMessage: String { return self._s[4321]! }
    public var SocksProxySetup_AddProxyTitle: String { return self._s[4322]! }
    public var Passport_Identity_AddInternalPassport: String { return self._s[4323]! }
    public func ChatList_RemovedFromFolderTooltip(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4324]!, self._r[4324]!, [_1, _2])
    }
    public func Conversation_SetReminder_RemindToday(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4325]!, self._r[4325]!, [_0])
    }
    public var Passport_Identity_GenderFemale: String { return self._s[4326]! }
    public var Location_ProximityNotification_DistanceKM: String { return self._s[4329]! }
    public var ConvertToSupergroup_HelpTitle: String { return self._s[4330]! }
    public func Message_ImportedDateFormat(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4331]!, self._r[4331]!, [_1, _2, _3])
    }
    public var VoiceChat_Audio: String { return self._s[4332]! }
    public var SharedMedia_TitleAll: String { return self._s[4333]! }
    public var Settings_Context_Logout: String { return self._s[4334]! }
    public var GroupInfo_SetGroupPhotoDelete: String { return self._s[4337]! }
    public var Settings_About_Title: String { return self._s[4338]! }
    public var StickerSettings_ContextHide: String { return self._s[4339]! }
    public func AutoDownloadSettings_UpTo(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4340]!, self._r[4340]!, [_0])
    }
    public func Conversation_LiveLocationYouAndOther(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4341]!, self._r[4341]!, [_0])
    }
    public var ChatImport_SelectionConfirmationAlertImportAction: String { return self._s[4343]! }
    public var Common_Cancel: String { return self._s[4344]! }
    public var CallFeedback_Title: String { return self._s[4346]! }
    public func Notification_PinnedContactMessage(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4347]!, self._r[4347]!, [_0])
    }
    public var Conversation_StickerAddedToFavorites: String { return self._s[4348]! }
    public var Activity_UploadingVideoMessage: String { return self._s[4350]! }
    public var MediaPicker_Send: String { return self._s[4351]! }
    public var PasscodeSettings_AutoLock_IfAwayFor_1minute: String { return self._s[4352]! }
    public var Conversation_LiveLocationYou: String { return self._s[4353]! }
    public var Notifications_ExceptionsUnmuted: String { return self._s[4354]! }
    public func Channel_AdminLog_MessageGroupPreHistoryHidden(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4356]!, self._r[4356]!, [_0])
    }
    public func PUSH_CHAT_ADD_YOU(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4357]!, self._r[4357]!, [_1, _2])
    }
    public var Checkout_PaymentLiabilityAlert: String { return self._s[4358]! }
    public var Conversation_ViewBackground: String { return self._s[4359]! }
    public var ChatSettings_PrivateChats: String { return self._s[4362]! }
    public var Conversation_ErrorInaccessibleMessage: String { return self._s[4363]! }
    public var BroadcastGroups_LimitAlert_LearnMore: String { return self._s[4364]! }
    public var Appearance_ThemeNight: String { return self._s[4365]! }
    public var Common_Search: String { return self._s[4366]! }
    public var TwoStepAuth_ReEnterPasswordTitle: String { return self._s[4367]! }
    public var ChangePhoneNumberNumber_Help: String { return self._s[4369]! }
    public var InviteLink_QRCode_Share: String { return self._s[4370]! }
    public var Stickers_SuggestAdded: String { return self._s[4372]! }
    public var Conversation_DiscardVoiceMessageDescription: String { return self._s[4375]! }
    public var Widget_UpdatedTodayAt: String { return self._s[4376]! }
    public var NetworkUsageSettings_Cellular: String { return self._s[4377]! }
    public var CheckoutInfo_Title: String { return self._s[4378]! }
    public var Conversation_ShareBotLocationConfirmationTitle: String { return self._s[4379]! }
    public var Channel_BotDoesntSupportGroups: String { return self._s[4380]! }
    public func DialogList_SingleRecordingAudioSuffix(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4381]!, self._r[4381]!, [_0])
    }
    public var MaskStickerSettings_Info: String { return self._s[4383]! }
    public var GroupRemoved_DeleteUser: String { return self._s[4385]! }
    public var Contacts_ShareTelegram: String { return self._s[4386]! }
    public var Group_UpgradeNoticeText1: String { return self._s[4387]! }
    public func PUSH_PHONE_CALL_REQUEST(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4388]!, self._r[4388]!, [_1])
    }
    public var PrivacyLastSeenSettings_Title: String { return self._s[4389]! }
    public var SettingsSearch_Synonyms_Support: String { return self._s[4393]! }
    public var PhotoEditor_TintTool: String { return self._s[4394]! }
    public var ChatImportActivity_OpenApp: String { return self._s[4396]! }
    public var GroupPermission_NoSendPolls: String { return self._s[4397]! }
    public var NotificationsSound_None: String { return self._s[4398]! }
    public func LOCAL_CHANNEL_MESSAGE_FWDS(_ _1: String, _ _2: Int) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4399]!, self._r[4399]!, [_1, "\(_2)"])
    }
    public var CheckoutInfo_ShippingInfoCityPlaceholder: String { return self._s[4402]! }
    public func Conversation_AutoremoveTimerSetChannel(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4404]!, self._r[4404]!, [_1])
    }
    public var ExplicitContent_AlertChannel: String { return self._s[4405]! }
    public var Conversation_ClousStorageInfo_Description1: String { return self._s[4406]! }
    public var Contacts_SortedByPresence: String { return self._s[4407]! }
    public var WallpaperSearch_ColorGray: String { return self._s[4408]! }
    public var Channel_AdminLogFilter_EventsNewSubscribers: String { return self._s[4409]! }
    public var Conversation_ReportSpam: String { return self._s[4410]! }
    public var ChatList_Search_NoResultsFilter: String { return self._s[4413]! }
    public var WallpaperSearch_ColorBlack: String { return self._s[4414]! }
    public var ArchivedChats_IntroTitle3: String { return self._s[4415]! }
    public var InviteLink_DeleteAllRevokedLinksAlert_Action: String { return self._s[4416]! }
    public func VoiceChat_PeerJoinedText(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4417]!, self._r[4417]!, [_0])
    }
    public var Conversation_DefaultRestrictedText: String { return self._s[4418]! }
    public var Settings_Devices: String { return self._s[4419]! }
    public var Call_AudioRouteSpeaker: String { return self._s[4420]! }
    public var GroupInfo_InviteLink_CopyLink: String { return self._s[4421]! }
    public var VoiceChat_StartsIn: String { return self._s[4422]! }
    public var VoiceChat_CreateNewVoiceChatSchedule: String { return self._s[4423]! }
    public var VoiceChat_EditDescriptionTitle: String { return self._s[4425]! }
    public var Passport_Address_Country: String { return self._s[4426]! }
    public var Cache_MaximumCacheSize: String { return self._s[4427]! }
    public var Chat_PanelHidePinnedMessages: String { return self._s[4428]! }
    public var Notifications_Badge_IncludePublicGroups: String { return self._s[4429]! }
    public var ChatSettings_AutoDownloadUsingWiFi: String { return self._s[4431]! }
    public var Login_TermsOfServiceLabel: String { return self._s[4432]! }
    public var Calls_NoMissedCallsPlacehoder: String { return self._s[4433]! }
    public var SocksProxySetup_RequiredCredentials: String { return self._s[4434]! }
    public var VoiceOver_MessageContextOpenMessageMenu: String { return self._s[4435]! }
    public var AutoNightTheme_ScheduledFrom: String { return self._s[4436]! }
    public var ChatSettings_AutoDownloadDocuments: String { return self._s[4437]! }
    public var ConvertToSupergroup_Note: String { return self._s[4439]! }
    public var Settings_SetNewProfilePhotoOrVideo: String { return self._s[4440]! }
    public var PrivacySettings_PasscodeAndTouchId: String { return self._s[4441]! }
    public var Common_More: String { return self._s[4442]! }
    public var ShareMenu_SelectChats: String { return self._s[4444]! }
    public func Conversation_ScheduleMessage_SendToday(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4445]!, self._r[4445]!, [_0])
    }
    public func Channel_AdminLog_MessageRemovedGroupStickerPack(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4446]!, self._r[4446]!, [_0])
    }
    public var Contacts_PermissionsKeepDisabled: String { return self._s[4448]! }
    public var VoiceChat_EditBioText: String { return self._s[4449]! }
    public func Call_ParticipantVersionOutdatedError(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4450]!, self._r[4450]!, [_0])
    }
    public var WatchRemote_AlertOpen: String { return self._s[4451]! }
    public func PUSH_CHAT_ADD_MEMBER(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4452]!, self._r[4452]!, [_1, _2, _3])
    }
    public var Channel_Members_AddMembersHelp: String { return self._s[4453]! }
    public var Shortcut_SwitchAccount: String { return self._s[4454]! }
    public var Map_LiveLocationFor8Hours: String { return self._s[4455]! }
    public func AutoNightTheme_AutomaticHelp(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4456]!, self._r[4456]!, [_0])
    }
    public var Compose_NewGroupTitle: String { return self._s[4457]! }
    public var DialogList_You: String { return self._s[4458]! }
    public var Call_VoiceOver_VoiceCallOutgoing: String { return self._s[4459]! }
    public var ReportPeer_ReasonViolence: String { return self._s[4460]! }
    public func PUSH_CHANNEL_MESSAGE_STICKER(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4461]!, self._r[4461]!, [_1, _2])
    }
    public var VoiceChat_Reconnecting: String { return self._s[4463]! }
    public var KeyCommand_ScrollDown: String { return self._s[4466]! }
    public var ChatSettings_DownloadInBackground: String { return self._s[4467]! }
    public var Wallpaper_ResetWallpapers: String { return self._s[4468]! }
    public var Channel_BanList_RestrictedTitle: String { return self._s[4469]! }
    public var ArchivedChats_IntroText3: String { return self._s[4470]! }
    public var HashtagSearch_AllChats: String { return self._s[4472]! }
    public var VoiceChat_EndVoiceChat: String { return self._s[4473]! }
    public var Conversation_MessageCopied: String { return self._s[4475]! }
    public var Channel_Info_BlackList: String { return self._s[4476]! }
    public var Contacts_SearchUsersAndGroupsLabel: String { return self._s[4477]! }
    public var PrivacyPhoneNumberSettings_DiscoveryHeader: String { return self._s[4478]! }
    public var Paint_Neon: String { return self._s[4480]! }
    public var SettingsSearch_Synonyms_AppLanguage: String { return self._s[4481]! }
    public var AutoDownloadSettings_AutoDownload: String { return self._s[4482]! }
    public func Notification_PinnedVideoMessage(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4484]!, self._r[4484]!, [_0])
    }
    public var Map_StopLiveLocation: String { return self._s[4485]! }
    public var SettingsSearch_Synonyms_Data_SaveEditedPhotos: String { return self._s[4486]! }
    public var Channel_Username_InvalidCharacters: String { return self._s[4487]! }
    public var InstantPage_Reference: String { return self._s[4489]! }
    public var Group_Members_AddMembers: String { return self._s[4491]! }
    public func Conversation_ScheduledVoiceChatStartsOn(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4492]!, self._r[4492]!, [_0])
    }
    public var ChatList_HideAction: String { return self._s[4493]! }
    public var Conversation_FileICloudDrive: String { return self._s[4495]! }
    public func PUSH_PINNED_GEOLIVE(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4496]!, self._r[4496]!, [_1])
    }
    public var Passport_PasswordReset: String { return self._s[4498]! }
    public var ChatList_Context_UnhideArchive: String { return self._s[4500]! }
    public var ConvertToSupergroup_HelpText: String { return self._s[4501]! }
    public var Calls_AddTab: String { return self._s[4502]! }
    public var TwoStepAuth_ConfirmEmailResendCode: String { return self._s[4504]! }
    public var SettingsSearch_Synonyms_Stickers_SuggestStickers: String { return self._s[4505]! }
    public var Privacy_GroupsAndChannels: String { return self._s[4508]! }
    public var Conversation_UsernameCopied: String { return self._s[4509]! }
    public var AutoNightTheme_Disabled: String { return self._s[4510]! }
    public var CreatePoll_MultipleChoice: String { return self._s[4511]! }
    public func PINNED_INVOICE(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4512]!, self._r[4512]!, [_1])
    }
    public var Watch_Bot_Restart: String { return self._s[4514]! }
    public func Conversation_Kilobytes(_ _0: Int) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4515]!, self._r[4515]!, ["\(_0)"])
    }
    public var GroupInfo_ScamGroupWarning: String { return self._s[4517]! }
    public var Conversation_EditingMessagePanelMedia: String { return self._s[4518]! }
    public var Appearance_PreviewIncomingText: String { return self._s[4519]! }
    public var ChatSettings_WidgetSettings: String { return self._s[4520]! }
    public var Notifications_ChannelNotificationsExceptionsHelp: String { return self._s[4521]! }
    public var ChatList_UndoArchiveRevealedTitle: String { return self._s[4523]! }
    public var Stats_GroupOverview: String { return self._s[4525]! }
    public var ScheduledMessages_EditTime: String { return self._s[4528]! }
    public var Month_GenFebruary: String { return self._s[4529]! }
    public var ChatList_AutoarchiveSuggestion_OpenSettings: String { return self._s[4530]! }
    public var Stickers_ClearRecent: String { return self._s[4531]! }
    public var InviteLink_Create_UsersLimitNumberOfUsersUnlimited: String { return self._s[4532]! }
    public var TwoStepAuth_EnterPasswordPassword: String { return self._s[4533]! }
    public var Stats_Message_PublicShares: String { return self._s[4534]! }
    public func Checkout_PayPrice(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4535]!, self._r[4535]!, [_0])
    }
    public var Login_TermsOfServiceSignupDecline: String { return self._s[4536]! }
    public var CheckoutInfo_ErrorCityInvalid: String { return self._s[4537]! }
    public var VoiceOver_Chat_PlayHint: String { return self._s[4538]! }
    public var ChatAdmins_AllMembersAreAdminsOffHelp: String { return self._s[4539]! }
    public var CheckoutInfo_ShippingInfoTitle: String { return self._s[4541]! }
    public var CreatePoll_Create: String { return self._s[4542]! }
    public var ChatList_Search_FilterLinks: String { return self._s[4543]! }
    public var Your_cards_number_is_invalid: String { return self._s[4544]! }
    public var Month_ShortApril: String { return self._s[4545]! }
    public var SocksProxySetup_UseForCalls: String { return self._s[4546]! }
    public var Conversation_EditingCaptionPanelTitle: String { return self._s[4547]! }
    public var SocksProxySetup_Status: String { return self._s[4548]! }
    public var VoiceChat_UnmuteForMe: String { return self._s[4549]! }
    public var ChannelInfo_DeleteGroupConfirmation: String { return self._s[4550]! }
    public var ChatListFolder_CategoryBots: String { return self._s[4551]! }
    public var Passport_FieldIdentitySelfieHelp: String { return self._s[4553]! }
    public var GroupInfo_BroadcastListNamePlaceholder: String { return self._s[4554]! }
    public var Chat_PinnedListPreview_UnpinAllMessages: String { return self._s[4555]! }
    public var Wallpaper_ResetWallpapersInfo: String { return self._s[4556]! }
    public var Conversation_TitleUnmute: String { return self._s[4557]! }
    public var Group_Setup_TypeHeader: String { return self._s[4558]! }
    public func Conversation_ForwardTooltip_ManyChats_One(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4559]!, self._r[4559]!, [_0, _1])
    }
    public var Stats_ViewsPerPost: String { return self._s[4560]! }
    public var CheckoutInfo_ShippingInfoCountry: String { return self._s[4561]! }
    public var Passport_Identity_TranslationHelp: String { return self._s[4562]! }
    public func PUSH_CHANNEL_MESSAGE_FWD(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4563]!, self._r[4563]!, [_1])
    }
    public var GroupInfo_Administrators_Title: String { return self._s[4564]! }
    public func Channel_AdminLog_MessageRankName(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4565]!, self._r[4565]!, [_1, _2])
    }
    public func PUSH_CHAT_MESSAGE_POLL(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4566]!, self._r[4566]!, [_1, _2, _3])
    }
    public var CheckoutInfo_ShippingInfoState: String { return self._s[4567]! }
    public var Passport_Language_my: String { return self._s[4569]! }
    public var PrivacyLastSeenSettings_AlwaysShareWith_Title: String { return self._s[4570]! }
    public var Map_PlacesNearby: String { return self._s[4571]! }
    public var Channel_About_Help: String { return self._s[4572]! }
    public var LogoutOptions_AddAccountTitle: String { return self._s[4573]! }
    public var ChatSettings_AutomaticAudioDownload: String { return self._s[4574]! }
    public var Channel_Username_Title: String { return self._s[4575]! }
    public var Activity_RecordingVideoMessage: String { return self._s[4576]! }
    public func StickerPackActionInfo_RemovedText(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4577]!, self._r[4577]!, [_0])
    }
    public var CheckoutInfo_ShippingInfoCity: String { return self._s[4578]! }
    public var Passport_DiscardMessageDescription: String { return self._s[4579]! }
    public var Conversation_LinkDialogOpen: String { return self._s[4580]! }
    public var ChatList_Context_HideArchive: String { return self._s[4581]! }
    public func Message_AuthorPinnedGame(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4582]!, self._r[4582]!, [_0])
    }
    public var Privacy_GroupsAndChannels_CustomShareHelp: String { return self._s[4583]! }
    public var Conversation_Admin: String { return self._s[4584]! }
    public var DialogList_TabTitle: String { return self._s[4585]! }
    public func PUSH_CHAT_ALBUM(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4586]!, self._r[4586]!, [_1, _2])
    }
    public var Notifications_PermissionsUnreachableText: String { return self._s[4587]! }
    public var Passport_Identity_GenderMale: String { return self._s[4589]! }
    public func VoiceChat_EditTitleSuccess(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4591]!, self._r[4591]!, [_0])
    }
    public var SettingsSearch_Synonyms_Privacy_BlockedUsers: String { return self._s[4592]! }
    public var PhoneNumberHelp_Alert: String { return self._s[4593]! }
    public var EnterPasscode_EnterNewPasscodeChange: String { return self._s[4594]! }
    public var Notifications_InAppNotifications: String { return self._s[4595]! }
    public func Update_AppVersion(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4596]!, self._r[4596]!, [_0])
    }
    public var Notification_VideoCallOutgoing: String { return self._s[4597]! }
    public var Login_InvalidCodeError: String { return self._s[4598]! }
    public var Conversation_PrivateChannelTimeLimitedAlertJoin: String { return self._s[4599]! }
    public func LastSeen_TodayAt(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4601]!, self._r[4601]!, [_0])
    }
    public var Conversation_InputTextCaptionPlaceholder: String { return self._s[4602]! }
    public var ReportPeer_Report: String { return self._s[4603]! }
    public var Camera_FlashOff: String { return self._s[4606]! }
    public var Conversation_InputTextBroadcastPlaceholder: String { return self._s[4609]! }
    public func Notification_VoiceChatScheduledTomorrow(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4610]!, self._r[4610]!, [_1, _2])
    }
    public var PrivacyPolicy_DeclineTitle: String { return self._s[4613]! }
    public var SettingsSearch_Synonyms_Privacy_PasscodeAndTouchId: String { return self._s[4614]! }
    public var Passport_FieldEmail: String { return self._s[4615]! }
    public func Channel_AdminLog_MessageKickedName(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4616]!, self._r[4616]!, [_1])
    }
    public var Notifications_ExceptionsResetToDefaults: String { return self._s[4617]! }
    public var PeerInfo_PaneVoiceAndVideo: String { return self._s[4618]! }
    public var Group_OwnershipTransfer_Title: String { return self._s[4619]! }
    public var Conversation_DefaultRestrictedInline: String { return self._s[4620]! }
    public var Login_PhoneNumberHelp: String { return self._s[4622]! }
    public var Channel_AdminLogFilter_EventsNewMembers: String { return self._s[4623]! }
    public var Conversation_PinnedQuiz: String { return self._s[4624]! }
    public var CreateGroup_SoftUserLimitAlert: String { return self._s[4625]! }
    public var Login_PhoneNumberAlreadyAuthorizedSwitch: String { return self._s[4626]! }
    public var Group_MessagePhotoUpdated: String { return self._s[4627]! }
    public var LoginPassword_PasswordPlaceholder: String { return self._s[4628]! }
    public var BroadcastGroups_ConfirmationAlert_Text: String { return self._s[4629]! }
    public var Passport_Identity_Translations: String { return self._s[4631]! }
    public var ChatAdmins_AllMembersAreAdmins: String { return self._s[4632]! }
    public var ChannelInfo_DeleteChannel: String { return self._s[4634]! }
    public var PasscodeSettings_HelpBottom: String { return self._s[4635]! }
    public var Channel_Members_AddMembers: String { return self._s[4636]! }
    public var AutoDownloadSettings_LastDelimeter: String { return self._s[4637]! }
    public var Notification_Exceptions_DeleteAllConfirmation: String { return self._s[4639]! }
    public var Conversation_HoldForAudio: String { return self._s[4640]! }
    public var Media_LimitedAccessChangeSettings: String { return self._s[4642]! }
    public var Watch_LastSeen_Lately: String { return self._s[4643]! }
    public var ChatList_Context_MarkAsRead: String { return self._s[4644]! }
    public var Conversation_PinnedMessage: String { return self._s[4645]! }
    public var SettingsSearch_Synonyms_Appearance_ColorTheme: String { return self._s[4646]! }
    public var VoiceChat_StopRecordingStop: String { return self._s[4648]! }
    public var Passport_UpdateRequiredError: String { return self._s[4649]! }
    public var PrivacySettings_Passcode: String { return self._s[4650]! }
    public func Call_EmojiDescription(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4651]!, self._r[4651]!, [_0])
    }
    public var AutoNightTheme_NotAvailable: String { return self._s[4652]! }
    public var Conversation_PressVolumeButtonForSound: String { return self._s[4653]! }
    public var VoiceOver_Common_On: String { return self._s[4654]! }
    public var LoginPassword_InvalidPasswordError: String { return self._s[4655]! }
    public var ChatListFolder_IncludedSectionHeader: String { return self._s[4656]! }
    public var Channel_SignMessages_Help: String { return self._s[4657]! }
    public var ChatList_DeleteForEveryoneConfirmationTitle: String { return self._s[4658]! }
    public var Conversation_TitleNoComments: String { return self._s[4659]! }
    public var MediaPicker_LivePhotoDescription: String { return self._s[4660]! }
    public var GroupInfo_Permissions: String { return self._s[4661]! }
    public var GroupPermission_NoSendLinks: String { return self._s[4664]! }
    public func Conversation_ScheduledVoiceChatStartsTomorrow(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4665]!, self._r[4665]!, [_0])
    }
    public var Passport_Identity_ResidenceCountry: String { return self._s[4666]! }
    public var Appearance_ThemeCarouselNightBlue: String { return self._s[4668]! }
    public var ChatList_ArchiveAction: String { return self._s[4669]! }
    public func Channel_AdminLog_DisabledSlowmode(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4670]!, self._r[4670]!, [_0])
    }
    public var GroupInfo_GroupHistory: String { return self._s[4671]! }
    public func Channel_Management_ErrorNotMember(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4673]!, self._r[4673]!, [_0])
    }
    public var Privacy_Forwards_LinkIfAllowed: String { return self._s[4675]! }
    public var Channel_Info_Banned: String { return self._s[4676]! }
    public var Paint_RecentStickers: String { return self._s[4677]! }
    public var VoiceOver_MessageContextSend: String { return self._s[4678]! }
    public var Group_ErrorNotMutualContact: String { return self._s[4679]! }
    public var ReportPeer_ReasonOther: String { return self._s[4681]! }
    public var Channel_BanUser_PermissionChangeGroupInfo: String { return self._s[4682]! }
    public var SocksProxySetup_ShareQRCodeInfo: String { return self._s[4684]! }
    public var KeyCommand_Find: String { return self._s[4685]! }
    public func Channel_MessageTitleUpdated(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4686]!, self._r[4686]!, [_0])
    }
    public var ChatList_Context_Unmute: String { return self._s[4687]! }
    public var Chat_SlowmodeAttachmentLimitReached: String { return self._s[4688]! }
    public var Stickers_GroupStickersHelp: String { return self._s[4689]! }
    public var Checkout_Title: String { return self._s[4690]! }
    public var Activity_RecordingAudio: String { return self._s[4691]! }
    public var SettingsSearch_Synonyms_Notifications_GroupNotificationsPreview: String { return self._s[4692]! }
    public var BlockedUsers_BlockTitle: String { return self._s[4693]! }
    public var DialogList_SavedMessagesHelp: String { return self._s[4695]! }
    public var Calls_All: String { return self._s[4696]! }
    public var Settings_FAQ_Button: String { return self._s[4698]! }
    public var Conversation_Dice_u1F3B0: String { return self._s[4700]! }
    public func Time_MonthOfYear_m5(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4701]!, self._r[4701]!, [_0])
    }
    public var Conversation_ReportGroupLocation: String { return self._s[4702]! }
    public var Passport_Scans_Upload: String { return self._s[4703]! }
    public var Channel_EditAdmin_PermissionPinMessages: String { return self._s[4705]! }
    public var ChatList_UnarchiveAction: String { return self._s[4706]! }
    public var Stats_GroupTopInviter_History: String { return self._s[4707]! }
    public var GroupInfo_Permissions_Title: String { return self._s[4708]! }
    public var VoiceChat_CreateNewVoiceChatStart: String { return self._s[4709]! }
    public var Passport_Language_el: String { return self._s[4710]! }
    public var Channel_DiscussionMessageUnavailable: String { return self._s[4711]! }
    public func UserInfo_ContactForwardTooltip_TwoChats_One(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4712]!, self._r[4712]!, [_0, _1])
    }
    public var GroupInfo_ActionPromote: String { return self._s[4713]! }
    public var Group_OwnershipTransfer_ErrorLocatedGroupsTooMuch: String { return self._s[4714]! }
    public var Media_LimitedAccessSelectMore: String { return self._s[4715]! }
    public func TwoStepAuth_PendingEmailHelp(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4716]!, self._r[4716]!, [_0])
    }
    public var VoiceOver_Chat_Reply: String { return self._s[4717]! }
    public var Month_GenMay: String { return self._s[4718]! }
    public var DialogList_DeleteBotConversationConfirmation: String { return self._s[4719]! }
    public var Chat_PsaTooltip_covid: String { return self._s[4720]! }
    public var Watch_Suggestion_CantTalk: String { return self._s[4721]! }
    public var Privacy_GroupsAndChannels_NeverAllow_Title: String { return self._s[4722]! }
    public var AppUpgrade_Running: String { return self._s[4723]! }
    public var PasscodeSettings_UnlockWithFaceId: String { return self._s[4726]! }
    public var Notification_Exceptions_PreviewAlwaysOff: String { return self._s[4727]! }
    public var SharedMedia_EmptyText: String { return self._s[4728]! }
    public var Passport_Address_EditResidentialAddress: String { return self._s[4729]! }
    public var SettingsSearch_Synonyms_Notifications_GroupNotificationsAlert: String { return self._s[4730]! }
    public var Message_PinnedGame: String { return self._s[4731]! }
    public var KeyCommand_SearchInChat: String { return self._s[4732]! }
    public var Appearance_ThemeCarouselNewNight: String { return self._s[4733]! }
    public var ChatList_Search_FilterMedia: String { return self._s[4734]! }
    public var Message_PinnedAudioMessage: String { return self._s[4735]! }
    public var ChannelInfo_ConfirmLeave: String { return self._s[4737]! }
    public func Channel_AdminLog_MessagePromotedNameUsername(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4738]!, self._r[4738]!, [_1, _2])
    }
    public var SocksProxySetup_ProxyStatusUnavailable: String { return self._s[4739]! }
    public var InviteLink_Create: String { return self._s[4740]! }
    public func Passport_Email_CodeHelp(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4741]!, self._r[4741]!, [_0])
    }
    public func Message_PinnedTextMessage(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4742]!, self._r[4742]!, [_0])
    }
    public var Settings_AddAccount: String { return self._s[4743]! }
    public var Channel_AdminLog_CanDeleteMessages: String { return self._s[4744]! }
    public var Conversation_DiscardVoiceMessageTitle: String { return self._s[4745]! }
    public var Channel_JoinChannel: String { return self._s[4746]! }
    public var Watch_UserInfo_Unblock: String { return self._s[4747]! }
    public var PhoneLabel_Title: String { return self._s[4748]! }
    public var VoiceChat_EditPermissions: String { return self._s[4750]! }
    public var Group_Setup_HistoryHiddenHelp: String { return self._s[4751]! }
    public var Privacy_ProfilePhoto_AlwaysShareWith_Title: String { return self._s[4752]! }
    public func Login_PhoneGenericEmailBody(_ _1: String, _ _2: String, _ _3: String, _ _4: String, _ _5: String, _ _6: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4753]!, self._r[4753]!, [_1, _2, _3, _4, _5, _6])
    }
    public var Channel_AddBotErrorHaveRights: String { return self._s[4754]! }
    public var ChatList_TabIconFoldersTooltipNonEmptyFolders: String { return self._s[4755]! }
    public var DialogList_EncryptionProcessing: String { return self._s[4756]! }
    public var ChatList_Search_FilterChats: String { return self._s[4757]! }
    public var WatchRemote_NotificationText: String { return self._s[4758]! }
    public var EditTheme_ChangeColors: String { return self._s[4760]! }
    public var GroupRemoved_ViewUserInfo: String { return self._s[4761]! }
    public var CallSettings_OnMobile: String { return self._s[4763]! }
    public var Month_ShortFebruary: String { return self._s[4765]! }
    public var VoiceOver_MessageContextReply: String { return self._s[4766]! }
    public var AutoremoveSetup_TimerValueNever: String { return self._s[4767]! }
    public var Group_Location_ChangeLocation: String { return self._s[4769]! }
    public func PUSH_VIDEO_CALL_REQUEST(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4770]!, self._r[4770]!, [_1])
    }
    public var Passport_Address_TypeBankStatementUploadScan: String { return self._s[4771]! }
    public var VoiceOver_Media_PlaybackStop: String { return self._s[4772]! }
    public var SettingsSearch_Synonyms_Data_SaveIncomingPhotos: String { return self._s[4773]! }
    public func Channel_AdminLog_MessageRestrictedUntil(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4775]!, self._r[4775]!, [_0])
    }
    public var PhotoEditor_WarmthTool: String { return self._s[4776]! }
    public var Login_InfoAvatarPhoto: String { return self._s[4777]! }
    public var Notification_Exceptions_NewException_MessagePreviewHeader: String { return self._s[4778]! }
    public var Permissions_CellularDataAllowInSettings_v0: String { return self._s[4779]! }
    public var Map_PlacesInThisArea: String { return self._s[4780]! }
    public var VoiceOver_Chat_ContactEmail: String { return self._s[4781]! }
    public var Notifications_InAppNotificationsSounds: String { return self._s[4782]! }
    public func PUSH_PINNED_NOTEXT(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4783]!, self._r[4783]!, [_1])
    }
    public var PeerInfo_ReportProfileVideo: String { return self._s[4784]! }
    public var ShareMenu_Send: String { return self._s[4785]! }
    public var Username_InvalidStartsWithNumber: String { return self._s[4786]! }
    public func Channel_AdminLog_StartedVoiceChat(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4787]!, self._r[4787]!, [_1])
    }
    public var Appearance_AppIconClassicX: String { return self._s[4788]! }
    public var Report_Report: String { return self._s[4789]! }
    public func PUSH_CHANNEL_MESSAGE_ROUND(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4790]!, self._r[4790]!, [_1])
    }
    public var Conversation_StopPoll: String { return self._s[4791]! }
    public var InfoPlist_NSLocationAlwaysUsageDescription: String { return self._s[4793]! }
    public var Passport_Identity_EditIdentityCard: String { return self._s[4794]! }
    public var Appearance_ThemePreview_ChatList_3_Name: String { return self._s[4795]! }
    public var Conversation_Timer_Title: String { return self._s[4796]! }
    public var Common_Next: String { return self._s[4797]! }
    public var Notification_Exceptions_NewException: String { return self._s[4798]! }
    public func Generic_OpenHiddenLinkAlert(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4799]!, self._r[4799]!, [_0])
    }
    public var AccessDenied_CallMicrophone: String { return self._s[4800]! }
    public var VoiceChat_UnmutePeer: String { return self._s[4801]! }
    public var ChatImportActivity_Retry: String { return self._s[4802]! }
    public var SettingsSearch_Synonyms_Data_AutoDownloadUsingCellular: String { return self._s[4803]! }
    public var ChangePhoneNumberCode_Help: String { return self._s[4804]! }
    public var Passport_Identity_OneOfTypeIdentityCard: String { return self._s[4805]! }
    public var Channel_AdminLogFilter_EventsLeaving: String { return self._s[4806]! }
    public var BlockedUsers_LeavePrefix: String { return self._s[4807]! }
    public func Passport_RequestHeader(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4808]!, self._r[4808]!, [_0])
    }
    public var Group_About_Help: String { return self._s[4809]! }
    public var TwoStepAuth_ChangePasswordDescription: String { return self._s[4810]! }
    public var Tour_Title3: String { return self._s[4811]! }
    public var Watch_Conversation_Unblock: String { return self._s[4812]! }
    public var Watch_UserInfo_Block: String { return self._s[4813]! }
    public var Notifications_ChannelNotificationsAlert: String { return self._s[4814]! }
    public var TwoFactorSetup_Hint_Action: String { return self._s[4815]! }
    public var IntentsSettings_SuggestedChatsInfo: String { return self._s[4816]! }
    public var TextFormat_AddLinkTitle: String { return self._s[4817]! }
    public var GroupInfo_InviteLink_RevokeAlert_Revoke: String { return self._s[4818]! }
    public func Notification_VoiceChatScheduled(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4819]!, self._r[4819]!, [_1, _2])
    }
    public var TwoStepAuth_EnterPasswordTitle: String { return self._s[4820]! }
    public var FastTwoStepSetup_PasswordSection: String { return self._s[4822]! }
    public var Compose_ChannelMembers: String { return self._s[4823]! }
    public var Conversation_ForwardTitle: String { return self._s[4824]! }
    public var Conversation_PinnedPoll: String { return self._s[4827]! }
    public func VoiceOver_Chat_AnonymousPollFrom(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4828]!, self._r[4828]!, [_0])
    }
    public var SettingsSearch_Synonyms_EditProfile_AddAccount: String { return self._s[4829]! }
    public var Conversation_ContextMenuStickerPackAdd: String { return self._s[4831]! }
    public var Stats_Overview: String { return self._s[4832]! }
    public var Map_HomeAndWorkTitle: String { return self._s[4833]! }
    public func Time_PreciseDate_m4(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4834]!, self._r[4834]!, [_1, _2, _3])
    }
    public var Passport_Address_CityPlaceholder: String { return self._s[4835]! }
    public var InfoPlist_NSLocationAlwaysAndWhenInUseUsageDescription: String { return self._s[4836]! }
    public var Privacy_PhoneNumber: String { return self._s[4837]! }
    public var ChatList_Search_FilterFiles: String { return self._s[4838]! }
    public var ChatList_DeleteForEveryoneConfirmationAction: String { return self._s[4839]! }
    public var ChannelIntro_CreateChannel: String { return self._s[4840]! }
    public var Conversation_InputTextAnonymousPlaceholder: String { return self._s[4841]! }
    public func Login_EmailCodeBody(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4842]!, self._r[4842]!, [_0])
    }
    public var Weekday_ShortMonday: String { return self._s[4843]! }
    public var Passport_Language_ar: String { return self._s[4845]! }
    public var SettingsSearch_Synonyms_EditProfile_Title: String { return self._s[4846]! }
    public var TwoFactorSetup_Done_Title: String { return self._s[4847]! }
    public var Calls_RatingFeedback: String { return self._s[4848]! }
    public var SettingsSearch_Synonyms_Notifications_ChannelNotificationsPreview: String { return self._s[4849]! }
    public var AutoDownloadSettings_ResetSettings: String { return self._s[4852]! }
    public func VoiceOver_SelfDestructTimerOn(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4853]!, self._r[4853]!, [_0])
    }
    public var Watch_Compose_Send: String { return self._s[4854]! }
    public var PasscodeSettings_ChangePasscode: String { return self._s[4855]! }
    public var WebSearch_RecentSectionClear: String { return self._s[4856]! }
    public func Contacts_AccessDeniedHelpPortrait(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4857]!, self._r[4857]!, [_0])
    }
    public var WallpaperSearch_ColorTeal: String { return self._s[4858]! }
    public var Wallpaper_SetCustomBackgroundInfo: String { return self._s[4859]! }
    public var Permissions_ContactsTitle_v0: String { return self._s[4860]! }
    public var Checkout_PasswordEntry_Pay: String { return self._s[4862]! }
    public var Settings_SavedMessages: String { return self._s[4863]! }
    public var TwoStepAuth_ReEnterPasswordDescription: String { return self._s[4864]! }
    public var Month_ShortMarch: String { return self._s[4865]! }
    public var Message_Location: String { return self._s[4866]! }
    public func PUSH_MESSAGE_GIF(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4867]!, self._r[4867]!, [_1])
    }
    public func Channel_AdminLog_MessageRemovedAdminName(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4868]!, self._r[4868]!, [_1])
    }
    public func Notification_CallTimeFormat(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4869]!, self._r[4869]!, [_1, _2])
    }
    public var VoiceOver_Chat_VoiceMessage: String { return self._s[4871]! }
    public func Channel_AdminLog_MessageChangedUnlinkedChannel(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4872]!, self._r[4872]!, [_1, _2])
    }
    public var GroupPermission_NoSendMedia: String { return self._s[4873]! }
    public var Conversation_ClousStorageInfo_Description2: String { return self._s[4874]! }
    public var SharedMedia_CategoryDocs: String { return self._s[4875]! }
    public var Appearance_RemoveThemeConfirmation: String { return self._s[4876]! }
    public var Paint_Framed: String { return self._s[4877]! }
    public var Channel_Setup_LinkTypePublic: String { return self._s[4878]! }
    public var Channel_EditAdmin_PermissionAddAdmins: String { return self._s[4879]! }
    public var Passport_Identity_DoesNotExpire: String { return self._s[4880]! }
    public func ChatImport_SelectionConfirmationUserWithTitle(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4881]!, self._r[4881]!, [_1, _2])
    }
    public var Channel_SignMessages: String { return self._s[4882]! }
    public var Contacts_AccessDeniedHelpON: String { return self._s[4883]! }
    public var Conversation_ContextMenuStickerPackInfo: String { return self._s[4884]! }
    public func PUSH_CHAT_LEFT(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4885]!, self._r[4885]!, [_1, _2])
    }
    public var InviteLink_Create_TimeLimitNoLimit: String { return self._s[4886]! }
    public var GroupInfo_UpgradeButton: String { return self._s[4887]! }
    public var Channel_EditAdmin_PermissionInviteMembers: String { return self._s[4888]! }
    public func Conversation_ScheduledVoiceChatStartsTomorrowShort(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4889]!, self._r[4889]!, [_0])
    }
    public var AutoDownloadSettings_Files: String { return self._s[4890]! }
    public func Notification_ChangedGroupName(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4891]!, self._r[4891]!, [_0, _1])
    }
    public var Login_SendCodeViaSms: String { return self._s[4893]! }
    public var Update_UpdateApp: String { return self._s[4894]! }
    public var Channel_Setup_TypePublic: String { return self._s[4895]! }
    public var Watch_Compose_CreateMessage: String { return self._s[4896]! }
    public func PUSH_CHAT_MESSAGE_VIDEOS(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4897]!, self._r[4897]!, [_1, _2, _3])
    }
    public var StickerPacksSettings_ManagingHelp: String { return self._s[4898]! }
    public var VoiceOver_Chat_Video: String { return self._s[4899]! }
    public var Forward_ChannelReadOnly: String { return self._s[4900]! }
    public var StickerPack_HideStickers: String { return self._s[4901]! }
    public var ChatListFolder_NameContacts: String { return self._s[4902]! }
    public var Profile_BotInfo: String { return self._s[4903]! }
    public var Document_TargetConfirmationFormat: String { return self._s[4904]! }
    public var GroupInfo_InviteByLink: String { return self._s[4905]! }
    public var Channel_AdminLog_BanSendStickersAndGifs: String { return self._s[4906]! }
    public var Watch_Stickers_RecentPlaceholder: String { return self._s[4907]! }
    public var Broadcast_AdminLog_EmptyText: String { return self._s[4908]! }
    public var Passport_NotLoggedInMessage: String { return self._s[4909]! }
    public var Conversation_StopQuizConfirmation: String { return self._s[4910]! }
    public var Checkout_PaymentMethod: String { return self._s[4911]! }
    public var ChatList_ArchivedChatsTitle: String { return self._s[4916]! }
    public var TwoStepAuth_SetupPasswordConfirmFailed: String { return self._s[4917]! }
    public var VoiceOver_Chat_RecordPreviewVoiceMessage: String { return self._s[4918]! }
    public var PrivacyLastSeenSettings_GroupsAndChannelsHelp: String { return self._s[4919]! }
    public var SettingsSearch_Synonyms_Privacy_Data_ContactsReset: String { return self._s[4920]! }
    public var Conversation_GigagroupDescription: String { return self._s[4921]! }
    public var Camera_Title: String { return self._s[4922]! }
    public var Map_Directions: String { return self._s[4923]! }
    public var Stats_MessagePublicForwardsTitle: String { return self._s[4925]! }
    public var Privacy_ProfilePhoto_WhoCanSeeMyPhoto: String { return self._s[4926]! }
    public var Profile_EncryptionKey: String { return self._s[4927]! }
    public func LOCAL_CHAT_MESSAGE_FWDS(_ _1: String, _ _2: Int) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4928]!, self._r[4928]!, [_1, "\(_2)"])
    }
    public func Compatibility_SecretMediaVersionTooLow(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4929]!, self._r[4929]!, [_0, _1])
    }
    public var Passport_Identity_TypePassport: String { return self._s[4930]! }
    public var CreatePoll_QuizOptionsHeader: String { return self._s[4932]! }
    public var Common_No: String { return self._s[4933]! }
    public var Conversation_SendMessage_ScheduleMessage: String { return self._s[4934]! }
    public var SettingsSearch_Synonyms_Privacy_LastSeen: String { return self._s[4935]! }
    public var Settings_AboutEmpty: String { return self._s[4936]! }
    public var TwoStepAuth_FloodError: String { return self._s[4938]! }
    public var SettingsSearch_Synonyms_Appearance_TextSize: String { return self._s[4939]! }
    public func Notification_VoiceChatScheduledChannel(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4940]!, self._r[4940]!, [_0])
    }
    public func Channel_AdminLog_MessageUnkickedName(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4942]!, self._r[4942]!, [_1])
    }
    public var Notification_Exceptions_MessagePreviewAlwaysOn: String { return self._s[4945]! }
    public var Conversation_Edit: String { return self._s[4946]! }
    public var CheckoutInfo_SaveInfo: String { return self._s[4948]! }
    public var VoiceOver_Chat_AnonymousPoll: String { return self._s[4949]! }
    public var Call_CameraTooltip: String { return self._s[4951]! }
    public var InstantPage_FeedbackButtonShort: String { return self._s[4952]! }
    public var Contacts_InviteToTelegram: String { return self._s[4953]! }
    public var Notifications_ResetAllNotifications: String { return self._s[4954]! }
    public var Calls_NewCall: String { return self._s[4955]! }
    public var VoiceOver_Chat_Music: String { return self._s[4958]! }
    public var Channel_AdminLogFilter_EventsInviteLinks: String { return self._s[4959]! }
    public var Channel_Members_AddAdminErrorNotAMember: String { return self._s[4960]! }
    public var Channel_Edit_AboutItem: String { return self._s[4961]! }
    public var Message_VideoExpired: String { return self._s[4962]! }
    public var Passport_Address_TypeTemporaryRegistrationUploadScan: String { return self._s[4963]! }
    public func PUSH_CHAT_RETURNED(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4964]!, self._r[4964]!, [_1, _2])
    }
    public var NotificationsSound_Input: String { return self._s[4966]! }
    public var Notifications_ClassicTones: String { return self._s[4967]! }
    public var Conversation_StatusTyping: String { return self._s[4968]! }
    public var Checkout_ErrorProviderAccountInvalid: String { return self._s[4969]! }
    public var ChatSettings_AutoDownloadSettings_Delimeter: String { return self._s[4970]! }
    public var SettingsSearch_Synonyms_Notifications_BadgeIncludeMutedChats: String { return self._s[4971]! }
    public var Conversation_MessageLeaveComment: String { return self._s[4972]! }
    public var UserInfo_TapToCall: String { return self._s[4973]! }
    public var EnterPasscode_EnterNewPasscodeNew: String { return self._s[4974]! }
    public func ScheduleVoiceChat_ScheduleOn(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4975]!, self._r[4975]!, [_0, _1])
    }
    public var Conversation_ClearAll: String { return self._s[4977]! }
    public var UserInfo_NotificationsDefault: String { return self._s[4978]! }
    public var Location_ProximityGroupTip: String { return self._s[4979]! }
    public var Map_ChooseAPlace: String { return self._s[4980]! }
    public var GroupInfo_AddParticipantTitle: String { return self._s[4982]! }
    public var ChatList_PeerTypeNonContact: String { return self._s[4983]! }
    public var Conversation_SlideToCancel: String { return self._s[4984]! }
    public var Month_ShortJuly: String { return self._s[4985]! }
    public var SocksProxySetup_ProxyType: String { return self._s[4986]! }
    public func ChatList_DeleteChatConfirmation(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4987]!, self._r[4987]!, [_0])
    }
    public var StickerPacks_ActionArchive: String { return self._s[4988]! }
    public var ChatList_EditFolders: String { return self._s[4989]! }
    public var TwoStepAuth_SetPasswordHelp: String { return self._s[4990]! }
    public var ScheduledMessages_RemindersTitle: String { return self._s[4992]! }
    public func GroupPermission_ApplyAlertText(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4993]!, self._r[4993]!, [_0])
    }
    public var Permissions_PeopleNearbyTitle_v0: String { return self._s[4994]! }
    public var Your_cards_expiration_year_is_invalid: String { return self._s[4995]! }
    public var UserInfo_ShareMyContactInfo: String { return self._s[4997]! }
    public func Conversation_ScheduledVoiceChatStartsOnShort(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[4999]!, self._r[4999]!, [_0])
    }
    public var Passport_DeleteAddress: String { return self._s[5000]! }
    public var Passport_DeletePassportConfirmation: String { return self._s[5001]! }
    public var Passport_Identity_ReverseSide: String { return self._s[5002]! }
    public var CheckoutInfo_ErrorEmailInvalid: String { return self._s[5004]! }
    public var Login_InfoLastNamePlaceholder: String { return self._s[5005]! }
    public var InviteLink_CreatedBy: String { return self._s[5006]! }
    public var Passport_FieldAddress: String { return self._s[5007]! }
    public var SettingsSearch_Synonyms_Calls_Title: String { return self._s[5008]! }
    public var Passport_Identity_ResidenceCountryPlaceholder: String { return self._s[5011]! }
    public var VoiceChat_Panel_TapToJoin: String { return self._s[5012]! }
    public var Map_Home: String { return self._s[5013]! }
    public var PollResults_Title: String { return self._s[5016]! }
    public func InviteLink_OtherPermanentLinkInfo(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[5017]!, self._r[5017]!, [_1, _2])
    }
    public var ArchivedChats_IntroText2: String { return self._s[5019]! }
    public var PasscodeSettings_SimplePasscodeHelp: String { return self._s[5020]! }
    public var VoiceOver_Chat_ContactPhoneNumber: String { return self._s[5021]! }
    public var VoiceChat_Muted: String { return self._s[5023]! }
    public var CallFeedback_ReasonSilentRemote: String { return self._s[5024]! }
    public var Passport_Identity_AddPersonalDetails: String { return self._s[5025]! }
    public var Conversation_AutoremoveActionEnable: String { return self._s[5027]! }
    public var Group_Info_AdminLog: String { return self._s[5028]! }
    public var ChatSettings_AutoPlayTitle: String { return self._s[5029]! }
    public var Appearance_Animations: String { return self._s[5030]! }
    public var Appearance_TextSizeSetting: String { return self._s[5031]! }
    public func PUSH_CHAT_MESSAGES(_ selector: Int32, _ _2: String, _ _1: String, _ _3: Int32) -> String {
        let form = getPluralizationForm(self.lc, selector)
        return String(format: self._ps[0 * 6 + Int(form.rawValue)]!, _2, _1, _3)
    }
    public func VoiceChat_Panel_Members(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[1 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Conversation_AutoremoveRemainingDays(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[2 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Map_ETAMinutes(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[3 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func ForwardedVideos(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[4 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func ScheduledIn_Years(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[5 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func ScheduledIn_Minutes(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[6 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func PUSH_MESSAGE_PHOTOS(_ selector: Int32, _ _1: String, _ _2: Int32) -> String {
        let form = getPluralizationForm(self.lc, selector)
        return String(format: self._ps[7 * 6 + Int(form.rawValue)]!, _1, _2)
    }
    public func Conversation_StatusSubscribers(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[8 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func MessageTimer_Weeks(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[9 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func MessageTimer_Years(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[10 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func SharedMedia_DeleteItemsConfirmation(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[11 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func VoiceOver_Chat_MessagesSelected(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[12 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Media_SharePhoto(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[13 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func ForwardedContacts(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[14 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Notification_GameScoreExtended(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[15 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func ChatList_DeletedChats(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[16 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func ServiceMessage_GameScoreSelfExtended(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[17 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func ServiceMessage_GameScoreExtended(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[18 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Contacts_ImportersCount(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[19 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func SharedMedia_Link(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[20 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func PUSH_MESSAGE_ROUNDS(_ selector: Int32, _ _1: String, _ _2: Int32) -> String {
        let form = getPluralizationForm(self.lc, selector)
        return String(format: self._ps[21 * 6 + Int(form.rawValue)]!, _1, _2)
    }
    public func Theme_UsersCount(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[22 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func ChatList_MessagePhotos(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[23 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func PUSH_CHANNEL_MESSAGE_FWDS(_ selector: Int32, _ _1: String, _ _2: Int32) -> String {
        let form = getPluralizationForm(self.lc, selector)
        return String(format: self._ps[24 * 6 + Int(form.rawValue)]!, _1, _2)
    }
    public func CreatePoll_AddMoreOptions(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[25 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Call_ShortSeconds(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[26 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func OldChannels_GroupFormat(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[27 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Conversation_SelectedMessages(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[28 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Conversation_ContextMenuSelectAll(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[29 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Stats_MessageForwards(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[30 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func InviteText_ContactsCountText(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[31 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Stats_GroupTopPosterMessages(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[32 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func ForwardedAuthorsOthers(_ selector: Int32, _ _0: String, _ _1: String) -> String {
        let form = getPluralizationForm(self.lc, selector)
        return String(format: self._ps[33 * 6 + Int(form.rawValue)]!, _0, _1)
    }
    public func ChatList_SelectedChats(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[34 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func AttachmentMenu_SendPhoto(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[35 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Chat_TitlePinnedMessages(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[36 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func InstantPage_Views(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[37 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func ForwardedMessages(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[38 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Stats_GroupTopAdminBans(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[39 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Conversation_StatusOnline(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[40 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Watch_UserInfo_Mute(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[41 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Forward_ConfirmMultipleFiles(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[42 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Stats_GroupTopAdminDeletions(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[43 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Notifications_ExceptionMuteExpires_Hours(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[44 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func MuteExpires_Days(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[45 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func MessageTimer_ShortSeconds(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[46 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Call_Minutes(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[47 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func ScheduledIn_Weeks(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[48 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func PeopleNearby_ShowMorePeople(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[49 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func ForwardedStickers(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[50 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func PUSH_CHAT_MESSAGE_DOCS_FIX1(_ selector: Int32, _ _2: String, _ _1: String, _ _3: Int32) -> String {
        let form = getPluralizationForm(self.lc, selector)
        return String(format: self._ps[51 * 6 + Int(form.rawValue)]!, _2, _1, _3)
    }
    public func PUSH_CHAT_MESSAGE_ROUNDS(_ selector: Int32, _ _2: String, _ _1: String, _ _3: Int32) -> String {
        let form = getPluralizationForm(self.lc, selector)
        return String(format: self._ps[52 * 6 + Int(form.rawValue)]!, _2, _1, _3)
    }
    public func Conversation_ContextViewReplies(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[53 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func QuickSend_Photos(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[54 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func InviteLink_PeopleCanJoin(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[55 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func MessageTimer_Seconds(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[56 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Media_ShareItem(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[57 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func LastSeen_HoursAgo(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[58 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func InviteLink_PeopleJoinedShort(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[59 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Stats_MessageViews(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[60 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func PUSH_CHANNEL_MESSAGE_PHOTOS(_ selector: Int32, _ _1: String, _ _2: Int32) -> String {
        let form = getPluralizationForm(self.lc, selector)
        return String(format: self._ps[61 * 6 + Int(form.rawValue)]!, _1, _2)
    }
    public func AttachmentMenu_SendItem(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[62 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func UserCount(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[63 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Stats_GroupTopInviterInvites(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[64 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Conversation_LiveLocationMembersCount(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[65 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Conversation_TitleComments(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[66 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func ChatList_MessageFiles(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[67 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Call_Hours(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[68 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func PUSH_MESSAGE_FWDS(_ selector: Int32, _ _1: String, _ _2: Int32) -> String {
        let form = getPluralizationForm(self.lc, selector)
        return String(format: self._ps[69 * 6 + Int(form.rawValue)]!, _1, _2)
    }
    public func Notifications_ExceptionMuteExpires_Minutes(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[70 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func ScheduledIn_Months(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[71 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Stats_GroupShowMoreTopInviters(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[72 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func MessagePoll_VotedCount(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[73 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func MuteFor_Days(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[74 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Wallpaper_DeleteConfirmation(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[75 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func ForwardedPolls(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[76 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func ForwardedFiles(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[77 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func MessageTimer_Hours(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[78 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func LiveLocationUpdated_MinutesAgo(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[79 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func StickerPack_RemoveStickerCount(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[80 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func MessageTimer_Minutes(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[81 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func PUSH_MESSAGES(_ selector: Int32, _ _1: String, _ _2: Int32) -> String {
        let form = getPluralizationForm(self.lc, selector)
        return String(format: self._ps[82 * 6 + Int(form.rawValue)]!, _1, _2)
    }
    public func PUSH_MESSAGE_VIDEOS(_ selector: Int32, _ _1: String, _ _2: Int32) -> String {
        let form = getPluralizationForm(self.lc, selector)
        return String(format: self._ps[83 * 6 + Int(form.rawValue)]!, _1, _2)
    }
    public func VoiceOver_Chat_PollOptionCount(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[84 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func ForwardedVideoMessages(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[85 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func PUSH_CHAT_MESSAGE_VIDEOS(_ selector: Int32, _ _2: String, _ _1: String, _ _3: Int32) -> String {
        let form = getPluralizationForm(self.lc, selector)
        return String(format: self._ps[86 * 6 + Int(form.rawValue)]!, _2, _1, _3)
    }
    public func VoiceOver_Chat_UnreadMessages(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[87 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Map_ETAHours(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[88 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Stats_GroupTopPosterChars(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[89 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func MessageTimer_ShortWeeks(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[90 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func GroupInfo_ShowMoreMembers(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[91 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func LiveLocation_MenuChatsCount(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[92 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func DialogList_LiveLocationChatsCount(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[93 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Conversation_StatusMembers(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[94 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func InviteLink_PeopleRemaining(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[95 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func SharedMedia_Generic(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[96 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func PollResults_ShowMore(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[97 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func StickerPacks_DeleteStickerPacksConfirmation(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[98 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func AttachmentMenu_SendGif(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[99 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Stats_GroupTopAdminKicks(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[100 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func MuteExpires_Hours(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[101 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Call_Seconds(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[102 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func ServiceMessage_GameScoreSelfSimple(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[103 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func SharedMedia_Photo(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[104 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func ChatList_MessageVideos(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[105 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func VoiceChat_InviteLink_InviteListeners(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[106 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func OldChannels_Leave(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[107 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func MessageTimer_ShortHours(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[108 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func OldChannels_InactiveWeek(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[109 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func SharedMedia_Video(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[110 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func StickerPack_RemoveMaskCount(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[111 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func MessageTimer_Months(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[112 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Notification_GameScoreSelfSimple(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[113 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func ScheduledIn_Days(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[114 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func PUSH_CHANNEL_MESSAGE_VIDEOS(_ selector: Int32, _ _1: String, _ _2: Int32) -> String {
        let form = getPluralizationForm(self.lc, selector)
        return String(format: self._ps[115 * 6 + Int(form.rawValue)]!, _1, _2)
    }
    public func PUSH_CHANNEL_MESSAGE_ROUNDS(_ selector: Int32, _ _1: String, _ _2: Int32) -> String {
        let form = getPluralizationForm(self.lc, selector)
        return String(format: self._ps[116 * 6 + Int(form.rawValue)]!, _1, _2)
    }
    public func PUSH_CHAT_MESSAGE_PHOTOS(_ selector: Int32, _ _2: String, _ _1: String, _ _3: Int32) -> String {
        let form = getPluralizationForm(self.lc, selector)
        return String(format: self._ps[117 * 6 + Int(form.rawValue)]!, _2, _1, _3)
    }
    public func InviteLink_PeopleJoined(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[118 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func PUSH_CHAT_MESSAGE_FWDS(_ selector: Int32, _ _2: String, _ _1: String, _ _3: Int32) -> String {
        let form = getPluralizationForm(self.lc, selector)
        return String(format: self._ps[119 * 6 + Int(form.rawValue)]!, _2, _1, _3)
    }
    public func ForwardedAudios(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[120 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Call_ShortMinutes(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[121 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func ChatListFilter_ShowMoreChats(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[122 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func VoiceChat_Status_Members(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[123 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Conversation_TitleReplies(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[124 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Watch_LastSeen_MinutesAgo(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[125 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func ScheduledIn_Seconds(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[126 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func PrivacyLastSeenSettings_AddUsers(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[127 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func InviteLink_InviteLinks(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[128 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func MessagePoll_QuizCount(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[129 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func OldChannels_InactiveYear(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[130 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Watch_LastSeen_HoursAgo(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[131 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Notifications_ExceptionMuteExpires_Days(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[132 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Stats_GroupShowMoreTopAdmins(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[133 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Invitation_Members(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[134 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func ForwardedPhotos(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[135 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func PUSH_MESSAGE_FILES(_ selector: Int32, _ _1: String, _ _2: Int32) -> String {
        let form = getPluralizationForm(self.lc, selector)
        return String(format: self._ps[136 * 6 + Int(form.rawValue)]!, _1, _2)
    }
    public func MessageTimer_ShortMinutes(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[137 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Call_Days(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[138 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func GroupInfo_ParticipantCount(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[139 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func VoiceOver_Chat_ContactEmailCount(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[140 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func LastSeen_MinutesAgo(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[141 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Conversation_MessageViewComments(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[142 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func ChatList_Search_Messages(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[143 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Contacts_InviteContacts(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[144 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func VoiceOver_Chat_ContactPhoneNumberCount(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[145 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func PUSH_CHANNEL_MESSAGES(_ selector: Int32, _ _1: String, _ _2: Int32) -> String {
        let form = getPluralizationForm(self.lc, selector)
        return String(format: self._ps[146 * 6 + Int(form.rawValue)]!, _1, _2)
    }
    public func MuteFor_Hours(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[147 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func StickerPack_AddStickerCount(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[148 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func SharedMedia_File(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[149 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func StickerPacks_ArchiveStickerPacksConfirmation(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[150 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func StickerPack_StickerCount(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[151 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func ForwardedLocations(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[152 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func PasscodeSettings_FailedAttempts(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[153 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Notifications_Exceptions(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[154 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Stats_GroupShowMoreTopPosters(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[155 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Notification_GameScoreSelfExtended(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[156 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Passport_Scans(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[157 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func AttachmentMenu_SendVideo(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[158 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Notification_GameScoreSimple(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[159 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Media_ShareVideo(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[160 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Chat_DeleteMessagesConfirmation(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[161 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func ServiceMessage_GameScoreSimple(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[162 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func MessageTimer_ShortDays(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[163 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func ChatList_MessageMusic(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[164 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func StickerPack_AddMaskCount(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[165 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func OldChannels_InactiveMonth(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[166 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func VoiceChat_InviteLink_InviteSpeakers(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[167 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func PUSH_CHANNEL_MESSAGE_DOCS(_ selector: Int32, _ _1: String, _ _2: Int32) -> String {
        let form = getPluralizationForm(self.lc, selector)
        return String(format: self._ps[168 * 6 + Int(form.rawValue)]!, _1, _2)
    }
    public func Chat_MessagesUnpinned(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[169 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func ScheduledIn_Hours(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[170 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func MessageTimer_Days(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[171 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func VoiceOver_Chat_PollVotes(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[172 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func ForwardedGifs(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[173 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func MuteExpires_Minutes(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[174 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func ChatList_DeleteConfirmation(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[175 * 6 + Int(form.rawValue)]!, stringValue)
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

