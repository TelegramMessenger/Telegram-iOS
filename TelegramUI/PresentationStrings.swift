import Foundation

private let fallbackDict: [String: String] = {
    if let mainPath = Bundle.main.path(forResource: "en", ofType: "lproj"), let bundle = Bundle(path: mainPath) {
        if let path = bundle.path(forResource: "Localizable", ofType: "strings") {
            if let dict = NSDictionary(contentsOf: URL(fileURLWithPath: path)) as? [String: String] {
                return dict
            } else {
                return [:]
            }
        } else {
            return [:]
        }
    } else {
        return [:]
    }
}()

private func getValue(_ dict: [String: String], _ secondaryDict: [String: String]?, _ key: String) -> String {
    if let value = dict[key] {
        return value
    } else if let value = secondaryDict?[key] {
        return value
    } else if let value = fallbackDict[key] {
        return value
    } else {
        return key
    }
}

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
private func getValueWithForm(_ dict: [String: String], _ secondaryDict: [String: String]?, _ key: String, _ form: PluralizationForm) -> String {
    if let value = dict[key + form.canonicalSuffix] {
        return value
    } else if let value = secondaryDict?[key + form.canonicalSuffix] {
        return value
    } else if let value = fallbackDict[key + form.canonicalSuffix] {
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

func formatWithArgumentRanges(_ value: String, _ ranges: [(Int, NSRange)], _ arguments: [String]) -> (String, [(Int, NSRange)]) {
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

public final class PresentationStringsComponent {
    public let languageCode: String
    public let pluralizationRulesCode: String?
    public let dict: [String: String]
    
    public init(languageCode: String, pluralizationRulesCode: String?, dict: [String: String]) {
        self.languageCode = languageCode
        self.pluralizationRulesCode = pluralizationRulesCode
        self.dict = dict
    }
}
        
public final class PresentationStrings {
    public let lc: UInt32
    
    public let primaryComponent: PresentationStringsComponent
    public let secondaryComponent: PresentationStringsComponent?
    public let baseLanguageCode: String
        public let Channel_BanUser_Title: String
    public let Notification_SecretChatMessageScreenshotSelf: String
    public let Preview_SaveGif: String
    public let Passport_ScanPassportHelp: String
    public let EnterPasscode_EnterNewPasscodeNew: String
    public let Passport_Identity_TypeInternalPassport: String
    public let Privacy_Calls_WhoCanCallMe: String
    public let Passport_DeletePassport: String
    public let Watch_NoConnection: String
    public let Activity_UploadingPhoto: String
    public let PrivacySettings_PrivacyTitle: String
    private let _DialogList_PinLimitError: String
    private let _DialogList_PinLimitError_r: [(Int, NSRange)]
    public func DialogList_PinLimitError(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_DialogList_PinLimitError, self._DialogList_PinLimitError_r, [_0])
    }
    public let FastTwoStepSetup_PasswordSection: String
    public let FastTwoStepSetup_EmailSection: String
    public let Notifications_Badge_IncludeChannels: String
    public let Cache_ClearCache: String
    public let Common_Close: String
    public let Passport_PasswordDescription: String
    public let ChangePhoneNumberCode_Called: String
    public let Login_PhoneTitle: String
    private let _Cache_Clear: String
    private let _Cache_Clear_r: [(Int, NSRange)]
    public func Cache_Clear(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Cache_Clear, self._Cache_Clear_r, [_0])
    }
    public let EnterPasscode_EnterNewPasscodeChange: String
    public let Watch_ChatList_Compose: String
    public let DialogList_SearchSectionDialogs: String
    public let Contacts_TabTitle: String
    public let NotificationsSound_Pulse: String
    public let Passport_Language_el: String
    public let Passport_Identity_DateOfBirth: String
    public let TwoStepAuth_SetupPasswordConfirmPassword: String
    public let SocksProxySetup_PasteFromClipboard: String
    public let ChannelIntro_Text: String
    public let PrivacySettings_SecurityTitle: String
    public let DialogList_SavedMessages: String
    public let Update_Skip: String
    private let _Call_StatusOngoing: String
    private let _Call_StatusOngoing_r: [(Int, NSRange)]
    public func Call_StatusOngoing(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Call_StatusOngoing, self._Call_StatusOngoing_r, [_0])
    }
    public let Settings_LogoutConfirmationText: String
    public let Passport_Identity_ResidenceCountry: String
    public let AutoNightTheme_ScheduledTo: String
    public let SocksProxySetup_RequiredCredentials: String
    public let BlockedUsers_Info: String
    public let ChatSettings_AutomaticAudioDownload: String
    public let Settings_SetUsername: String
    public let Privacy_Calls_CustomShareHelp: String
    public let Group_MessagePhotoUpdated: String
    public let Message_PinnedInvoice: String
    public let Login_InfoAvatarAdd: String
    public let Conversation_RestrictedMedia: String
    public let AutoDownloadSettings_LimitBySize: String
    public let WebSearch_RecentSectionTitle: String
    private let _CHAT_MESSAGE_TEXT: String
    private let _CHAT_MESSAGE_TEXT_r: [(Int, NSRange)]
    public func CHAT_MESSAGE_TEXT(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_CHAT_MESSAGE_TEXT, self._CHAT_MESSAGE_TEXT_r, [_1, _2, _3])
    }
    public let Message_Sticker: String
    public let Paint_Regular: String
    public let Channel_Username_Help: String
    private let _Profile_CreateEncryptedChatOutdatedError: String
    private let _Profile_CreateEncryptedChatOutdatedError_r: [(Int, NSRange)]
    public func Profile_CreateEncryptedChatOutdatedError(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Profile_CreateEncryptedChatOutdatedError, self._Profile_CreateEncryptedChatOutdatedError_r, [_0, _1])
    }
    public let PrivacyPolicy_DeclineLastWarning: String
    public let Passport_FieldEmail: String
    public let ContactInfo_PhoneLabelPager: String
    private let _PINNED_STICKER: String
    private let _PINNED_STICKER_r: [(Int, NSRange)]
    public func PINNED_STICKER(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_PINNED_STICKER, self._PINNED_STICKER_r, [_1, _2])
    }
    public let AutoDownloadSettings_Title: String
    public let Conversation_ShareInlineBotLocationConfirmation: String
    private let _Channel_AdminLog_MessageEdited: String
    private let _Channel_AdminLog_MessageEdited_r: [(Int, NSRange)]
    public func Channel_AdminLog_MessageEdited(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Channel_AdminLog_MessageEdited, self._Channel_AdminLog_MessageEdited_r, [_0])
    }
    public let Group_Setup_HistoryHidden: String
    public let Watch_Message_Game: String
    private let _PHONE_CALL_REQUEST: String
    private let _PHONE_CALL_REQUEST_r: [(Int, NSRange)]
    public func PHONE_CALL_REQUEST(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_PHONE_CALL_REQUEST, self._PHONE_CALL_REQUEST_r, [_1])
    }
    public let AccessDenied_MicrophoneRestricted: String
    public let Your_cards_expiration_year_is_invalid: String
    public let GroupInfo_InviteByLink: String
    private let _Notification_LeftChat: String
    private let _Notification_LeftChat_r: [(Int, NSRange)]
    public func Notification_LeftChat(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Notification_LeftChat, self._Notification_LeftChat_r, [_0])
    }
    public let Appearance_AutoNightThemeDisabled: String
    private let _Channel_AdminLog_MessageAdmin: String
    private let _Channel_AdminLog_MessageAdmin_r: [(Int, NSRange)]
    public func Channel_AdminLog_MessageAdmin(_ _0: String, _ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Channel_AdminLog_MessageAdmin, self._Channel_AdminLog_MessageAdmin_r, [_0, _1, _2])
    }
    public let PrivacyLastSeenSettings_NeverShareWith_Placeholder: String
    public let Notifications_ExceptionsMessagePlaceholder: String
    public let NotificationsSound_Alert: String
    public let TwoStepAuth_SetupEmail: String
    public let Checkout_PayWithFaceId: String
    public let Login_ResetAccountProtected_Reset: String
    public let SocksProxySetup_Hostname: String
    private let _PrivacyPolicy_AgeVerificationMessage: String
    private let _PrivacyPolicy_AgeVerificationMessage_r: [(Int, NSRange)]
    public func PrivacyPolicy_AgeVerificationMessage(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_PrivacyPolicy_AgeVerificationMessage, self._PrivacyPolicy_AgeVerificationMessage_r, [_0])
    }
    public let NotificationsSound_None: String
    public let Channel_AdminLog_CanEditMessages: String
    private let _MESSAGE_CONTACT: String
    private let _MESSAGE_CONTACT_r: [(Int, NSRange)]
    public func MESSAGE_CONTACT(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_MESSAGE_CONTACT, self._MESSAGE_CONTACT_r, [_1])
    }
    public let MediaPicker_MomentsDateRangeSameMonthYearFormat: String
    public let Notification_MessageLifetime1w: String
    public let PasscodeSettings_AutoLock_IfAwayFor_5minutes: String
    public let ChatSettings_Groups: String
    public let State_Connecting: String
    private let _Message_ForwardedMessageShort: String
    private let _Message_ForwardedMessageShort_r: [(Int, NSRange)]
    public func Message_ForwardedMessageShort(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Message_ForwardedMessageShort, self._Message_ForwardedMessageShort_r, [_0])
    }
    public let Watch_ConnectionDescription: String
    private let _Notification_CallTimeFormat: String
    private let _Notification_CallTimeFormat_r: [(Int, NSRange)]
    public func Notification_CallTimeFormat(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Notification_CallTimeFormat, self._Notification_CallTimeFormat_r, [_1, _2])
    }
    public let Passport_Identity_Selfie: String
    public let Passport_Identity_GenderMale: String
    public let Paint_Delete: String
    public let Passport_Identity_AddDriversLicense: String
    public let Passport_Language_ne: String
    public let Channel_MessagePhotoUpdated: String
    public let Passport_Address_OneOfTypePassportRegistration: String
    public let Cache_Help: String
    public let SocksProxySetup_ProxyStatusConnected: String
    private let _Login_EmailPhoneBody: String
    private let _Login_EmailPhoneBody_r: [(Int, NSRange)]
    public func Login_EmailPhoneBody(_ _0: String, _ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Login_EmailPhoneBody, self._Login_EmailPhoneBody_r, [_0, _1, _2])
    }
    public let Checkout_ShippingAddress: String
    public let Channel_BanList_RestrictedTitle: String
    public let Checkout_TotalAmount: String
    public let Appearance_TextSize: String
    public let Passport_Address_TypeResidentialAddress: String
    public let Conversation_MessageEditedLabel: String
    public let SharedMedia_EmptyLinksText: String
    private let _Conversation_RestrictedTextTimed: String
    private let _Conversation_RestrictedTextTimed_r: [(Int, NSRange)]
    public func Conversation_RestrictedTextTimed(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Conversation_RestrictedTextTimed, self._Conversation_RestrictedTextTimed_r, [_0])
    }
    public let Passport_Address_AddResidentialAddress: String
    public let Calls_NoCallsPlaceholder: String
    public let Passport_Address_AddPassportRegistration: String
    public let Conversation_PinMessageAlert_OnlyPin: String
    public let PasscodeSettings_UnlockWithFaceId: String
    public let ContactInfo_Title: String
    public let ReportPeer_ReasonOther_Send: String
    public let Notifications_Badge: String
    public let Conversation_InstantPagePreview: String
    public let PasscodeSettings_SimplePasscodeHelp: String
    private let _Time_PreciseDate_m9: String
    private let _Time_PreciseDate_m9_r: [(Int, NSRange)]
    public func Time_PreciseDate_m9(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Time_PreciseDate_m9, self._Time_PreciseDate_m9_r, [_1, _2, _3])
    }
    public let GroupInfo_Title: String
    public let State_Updating: String
    public let PrivacyPolicy_AgeVerificationAgree: String
    public let Map_GetDirections: String
    private let _TwoStepAuth_PendingEmailHelp: String
    private let _TwoStepAuth_PendingEmailHelp_r: [(Int, NSRange)]
    public func TwoStepAuth_PendingEmailHelp(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_TwoStepAuth_PendingEmailHelp, self._TwoStepAuth_PendingEmailHelp_r, [_0])
    }
    public let UserInfo_PhoneCall: String
    public let Passport_Language_bn: String
    public let MusicPlayer_VoiceNote: String
    public let Paint_Duplicate: String
    public let Channel_Username_InvalidTaken: String
    public let Conversation_ClearGroupHistory: String
    public let Passport_Address_OneOfTypeRentalAgreement: String
    public let Stickers_GroupStickersHelp: String
    public let SecretChat_Title: String
    public let Group_UpgradeConfirmation: String
    public let Checkout_LiabilityAlertTitle: String
    public let GroupInfo_GroupNamePlaceholder: String
    private let _Time_PreciseDate_m11: String
    private let _Time_PreciseDate_m11_r: [(Int, NSRange)]
    public func Time_PreciseDate_m11(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Time_PreciseDate_m11, self._Time_PreciseDate_m11_r, [_1, _2, _3])
    }
    public let Passport_DeletePersonalDetailsConfirmation: String
    private let _UserInfo_NotificationsDefaultSound: String
    private let _UserInfo_NotificationsDefaultSound_r: [(Int, NSRange)]
    public func UserInfo_NotificationsDefaultSound(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_UserInfo_NotificationsDefaultSound, self._UserInfo_NotificationsDefaultSound_r, [_0])
    }
    public let Passport_Email_Help: String
    private let _MESSAGE_GEOLIVE: String
    private let _MESSAGE_GEOLIVE_r: [(Int, NSRange)]
    public func MESSAGE_GEOLIVE(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_MESSAGE_GEOLIVE, self._MESSAGE_GEOLIVE_r, [_1])
    }
    private let _Notification_JoinedGroupByLink: String
    private let _Notification_JoinedGroupByLink_r: [(Int, NSRange)]
    public func Notification_JoinedGroupByLink(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Notification_JoinedGroupByLink, self._Notification_JoinedGroupByLink_r, [_0])
    }
    public let LoginPassword_Title: String
    public let Login_HaveNotReceivedCodeInternal: String
    public let PasscodeSettings_SimplePasscode: String
    public let NewContact_Title: String
    public let Username_CheckingUsername: String
    public let Login_ResetAccountProtected_TimerTitle: String
    public let Checkout_Email: String
    public let CheckoutInfo_SaveInfo: String
    public let UserInfo_InviteBotToGroup: String
    private let _ChangePhoneNumberCode_CallTimer: String
    private let _ChangePhoneNumberCode_CallTimer_r: [(Int, NSRange)]
    public func ChangePhoneNumberCode_CallTimer(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_ChangePhoneNumberCode_CallTimer, self._ChangePhoneNumberCode_CallTimer_r, [_0])
    }
    public let TwoStepAuth_SetupPasswordEnterPasswordNew: String
    public let Weekday_Wednesday: String
    private let _Channel_AdminLog_MessageToggleSignaturesOff: String
    private let _Channel_AdminLog_MessageToggleSignaturesOff_r: [(Int, NSRange)]
    public func Channel_AdminLog_MessageToggleSignaturesOff(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Channel_AdminLog_MessageToggleSignaturesOff, self._Channel_AdminLog_MessageToggleSignaturesOff_r, [_0])
    }
    public let Month_ShortDecember: String
    public let Channel_SignMessages: String
    public let Appearance_Title: String
    public let ReportPeer_ReasonCopyright: String
    public let Conversation_Moderate_Delete: String
    public let Conversation_CloudStorage_ChatStatus: String
    public let Login_InfoTitle: String
    public let Privacy_GroupsAndChannels_NeverAllow_Placeholder: String
    public let Message_Video: String
    public let Notification_ChannelInviterSelf: String
    public let Channel_AdminLog_BanEmbedLinks: String
    public let Conversation_SecretLinkPreviewAlert: String
    private let _CHANNEL_MESSAGE_GEOLIVE: String
    private let _CHANNEL_MESSAGE_GEOLIVE_r: [(Int, NSRange)]
    public func CHANNEL_MESSAGE_GEOLIVE(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_CHANNEL_MESSAGE_GEOLIVE, self._CHANNEL_MESSAGE_GEOLIVE_r, [_1])
    }
    public let Cache_Videos: String
    public let Call_ReportSkip: String
    public let NetworkUsageSettings_MediaImageDataSection: String
    public let Group_Setup_HistoryTitle: String
    public let TwoStepAuth_GenericHelp: String
    private let _DialogList_SingleRecordingAudioSuffix: String
    private let _DialogList_SingleRecordingAudioSuffix_r: [(Int, NSRange)]
    public func DialogList_SingleRecordingAudioSuffix(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_DialogList_SingleRecordingAudioSuffix, self._DialogList_SingleRecordingAudioSuffix_r, [_0])
    }
    public let Privacy_TopPeersDelete: String
    public let Checkout_NewCard_CardholderNameTitle: String
    public let Settings_FAQ_Button: String
    private let _GroupInfo_AddParticipantConfirmation: String
    private let _GroupInfo_AddParticipantConfirmation_r: [(Int, NSRange)]
    public func GroupInfo_AddParticipantConfirmation(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_GroupInfo_AddParticipantConfirmation, self._GroupInfo_AddParticipantConfirmation_r, [_0])
    }
    private let _Notification_PinnedLiveLocationMessage: String
    private let _Notification_PinnedLiveLocationMessage_r: [(Int, NSRange)]
    public func Notification_PinnedLiveLocationMessage(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Notification_PinnedLiveLocationMessage, self._Notification_PinnedLiveLocationMessage_r, [_0])
    }
    public let AccessDenied_PhotosRestricted: String
    public let Map_Locating: String
    public let AutoDownloadSettings_Unlimited: String
    public let Passport_Language_km: String
    public let MediaPicker_LivePhotoDescription: String
    public let Passport_DiscardMessageDescription: String
    public let SocksProxySetup_Title: String
    public let SharedMedia_EmptyMusicText: String
    public let Cache_ByPeerHeader: String
    public let Bot_GroupStatusReadsHistory: String
    public let TwoStepAuth_ResetAccountConfirmation: String
    public let CallSettings_Always: String
    public let Message_ImageExpired: String
    public let Channel_BanUser_Unban: String
    public let Stickers_GroupChooseStickerPack: String
    public let Group_Setup_TypePrivate: String
    public let Passport_Language_cs: String
    public let Settings_LogoutConfirmationTitle: String
    public let UserInfo_FirstNamePlaceholder: String
    public let Passport_Identity_SurnamePlaceholder: String
    public let Passport_Identity_FilesView: String
    public let LoginPassword_ResetAccount: String
    public let Privacy_GroupsAndChannels_AlwaysAllow: String
    private let _Notification_JoinedChat: String
    private let _Notification_JoinedChat_r: [(Int, NSRange)]
    public func Notification_JoinedChat(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Notification_JoinedChat, self._Notification_JoinedChat_r, [_0])
    }
    public let Notifications_ExceptionsUnmuted: String
    public let ChannelInfo_DeleteChannel: String
    public let Passport_Title: String
    public let NetworkUsageSettings_BytesReceived: String
    public let BlockedUsers_BlockTitle: String
    public let Update_Title: String
    public let AccessDenied_PhotosAndVideos: String
    public let Channel_Username_Title: String
    private let _Channel_AdminLog_MessageToggleSignaturesOn: String
    private let _Channel_AdminLog_MessageToggleSignaturesOn_r: [(Int, NSRange)]
    public func Channel_AdminLog_MessageToggleSignaturesOn(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Channel_AdminLog_MessageToggleSignaturesOn, self._Channel_AdminLog_MessageToggleSignaturesOn_r, [_0])
    }
    public let Map_PullUpForPlaces: String
    private let _Conversation_EncryptionWaiting: String
    private let _Conversation_EncryptionWaiting_r: [(Int, NSRange)]
    public func Conversation_EncryptionWaiting(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Conversation_EncryptionWaiting, self._Conversation_EncryptionWaiting_r, [_0])
    }
    public let Passport_Language_ka: String
    public let InfoPlist_NSSiriUsageDescription: String
    public let Calls_NotNow: String
    public let Conversation_Report: String
    private let _CHANNEL_MESSAGE_DOC: String
    private let _CHANNEL_MESSAGE_DOC_r: [(Int, NSRange)]
    public func CHANNEL_MESSAGE_DOC(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_CHANNEL_MESSAGE_DOC, self._CHANNEL_MESSAGE_DOC_r, [_1])
    }
    public let Channel_AdminLogFilter_EventsAll: String
    public let InfoPlist_NSLocationWhenInUseUsageDescription: String
    public let Passport_Address_TypeTemporaryRegistration: String
    public let Call_ConnectionErrorTitle: String
    public let Passport_Language_tr: String
    public let Settings_ApplyProxyAlertEnable: String
    public let Settings_ChatSettings: String
    public let Group_About_Help: String
    private let _CHANNEL_MESSAGE_NOTEXT: String
    private let _CHANNEL_MESSAGE_NOTEXT_r: [(Int, NSRange)]
    public func CHANNEL_MESSAGE_NOTEXT(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_CHANNEL_MESSAGE_NOTEXT, self._CHANNEL_MESSAGE_NOTEXT_r, [_1])
    }
    public let Month_GenSeptember: String
    public let PrivacySettings_LastSeenEverybody: String
    public let Contacts_NotRegisteredSection: String
    public let PhotoEditor_BlurToolRadial: String
    public let TwoStepAuth_PasswordRemoveConfirmation: String
    public let Channel_EditAdmin_PermissionEditMessages: String
    public let TwoStepAuth_ChangePassword: String
    public let Watch_MessageView_Title: String
    private let _Notification_PinnedRoundMessage: String
    private let _Notification_PinnedRoundMessage_r: [(Int, NSRange)]
    public func Notification_PinnedRoundMessage(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Notification_PinnedRoundMessage, self._Notification_PinnedRoundMessage_r, [_0])
    }
    public let Conversation_ViewMessage: String
    public let Passport_FieldEmailHelp: String
    public let Settings_SaveEditedPhotos: String
    public let Channel_Management_LabelCreator: String
    private let _Notification_PinnedStickerMessage: String
    private let _Notification_PinnedStickerMessage_r: [(Int, NSRange)]
    public func Notification_PinnedStickerMessage(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Notification_PinnedStickerMessage, self._Notification_PinnedStickerMessage_r, [_0])
    }
    private let _AutoNightTheme_AutomaticHelp: String
    private let _AutoNightTheme_AutomaticHelp_r: [(Int, NSRange)]
    public func AutoNightTheme_AutomaticHelp(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_AutoNightTheme_AutomaticHelp, self._AutoNightTheme_AutomaticHelp_r, [_0])
    }
    public let Passport_Address_EditPassportRegistration: String
    public let PhotoEditor_QualityTool: String
    public let Login_NetworkError: String
    public let TwoStepAuth_EnterPasswordForgot: String
    public let Compose_ChannelMembers: String
    private let _Channel_AdminLog_CaptionEdited: String
    private let _Channel_AdminLog_CaptionEdited_r: [(Int, NSRange)]
    public func Channel_AdminLog_CaptionEdited(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Channel_AdminLog_CaptionEdited, self._Channel_AdminLog_CaptionEdited_r, [_0])
    }
    public let Common_Yes: String
    public let KeyCommand_JumpToPreviousUnreadChat: String
    public let CheckoutInfo_ReceiverInfoPhone: String
    public let SocksProxySetup_TypeNone: String
    public let GroupInfo_AddParticipantTitle: String
    public let Map_LiveLocationShowAll: String
    public let Settings_SavedMessages: String
    public let Passport_FieldIdentitySelfieHelp: String
    private let _CHANNEL_MESSAGE_TEXT: String
    private let _CHANNEL_MESSAGE_TEXT_r: [(Int, NSRange)]
    public func CHANNEL_MESSAGE_TEXT(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_CHANNEL_MESSAGE_TEXT, self._CHANNEL_MESSAGE_TEXT_r, [_1, _2])
    }
    public let Checkout_PayNone: String
    public let CheckoutInfo_ErrorNameInvalid: String
    public let Notification_PaymentSent: String
    public let Settings_Username: String
    public let Notification_CallMissedShort: String
    public let Call_CallInProgressTitle: String
    public let Passport_Scans: String
    public let PhotoEditor_Skip: String
    public let AuthSessions_TerminateOtherSessionsHelp: String
    public let Call_AudioRouteHeadphones: String
    public let SocksProxySetup_UseForCalls: String
    public let Contacts_InviteFriends: String
    public let Channel_BanUser_PermissionSendMessages: String
    public let Notifications_InAppNotificationsVibrate: String
    public let StickerPack_Share: String
    public let Watch_MessageView_Reply: String
    public let Call_AudioRouteSpeaker: String
    public let Checkout_Title: String
    private let _MESSAGE_GEO: String
    private let _MESSAGE_GEO_r: [(Int, NSRange)]
    public func MESSAGE_GEO(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_MESSAGE_GEO, self._MESSAGE_GEO_r, [_1])
    }
    public let Privacy_Calls: String
    public let DialogList_AdLabel: String
    public let Passport_Identity_ScansHelp: String
    public let Channel_AdminLogFilter_EventsInfo: String
    public let Passport_Language_hu: String
    private let _Channel_AdminLog_MessagePinned: String
    private let _Channel_AdminLog_MessagePinned_r: [(Int, NSRange)]
    public func Channel_AdminLog_MessagePinned(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Channel_AdminLog_MessagePinned, self._Channel_AdminLog_MessagePinned_r, [_0])
    }
    private let _Channel_AdminLog_MessageToggleInvitesOn: String
    private let _Channel_AdminLog_MessageToggleInvitesOn_r: [(Int, NSRange)]
    public func Channel_AdminLog_MessageToggleInvitesOn(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Channel_AdminLog_MessageToggleInvitesOn, self._Channel_AdminLog_MessageToggleInvitesOn_r, [_0])
    }
    public let KeyCommand_ScrollDown: String
    public let Conversation_LinkDialogSave: String
    public let CheckoutInfo_ErrorShippingNotAvailable: String
    public let Conversation_SendMessageErrorFlood: String
    private let _Checkout_SavePasswordTimeoutAndTouchId: String
    private let _Checkout_SavePasswordTimeoutAndTouchId_r: [(Int, NSRange)]
    public func Checkout_SavePasswordTimeoutAndTouchId(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Checkout_SavePasswordTimeoutAndTouchId, self._Checkout_SavePasswordTimeoutAndTouchId_r, [_0])
    }
    public let HashtagSearch_AllChats: String
    public let InfoPlist_NSPhotoLibraryAddUsageDescription: String
    private let _Date_ChatDateHeaderYear: String
    private let _Date_ChatDateHeaderYear_r: [(Int, NSRange)]
    public func Date_ChatDateHeaderYear(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Date_ChatDateHeaderYear, self._Date_ChatDateHeaderYear_r, [_1, _2, _3])
    }
    public let Privacy_Calls_P2PContacts: String
    public let Passport_Email_Delete: String
    public let CheckoutInfo_ShippingInfoCountry: String
    public let Map_ShowPlaces: String
    public let Passport_Identity_GenderFemale: String
    public let Camera_VideoMode: String
    private let _Watch_Time_ShortFullAt: String
    private let _Watch_Time_ShortFullAt_r: [(Int, NSRange)]
    public func Watch_Time_ShortFullAt(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Watch_Time_ShortFullAt, self._Watch_Time_ShortFullAt_r, [_1, _2])
    }
    public let UserInfo_TelegramCall: String
    public let PrivacyLastSeenSettings_CustomShareSettingsHelp: String
    public let Passport_UpdateRequiredError: String
    public let Channel_AdminLog_InfoPanelAlertText: String
    private let _Channel_AdminLog_MessageUnpinned: String
    private let _Channel_AdminLog_MessageUnpinned_r: [(Int, NSRange)]
    public func Channel_AdminLog_MessageUnpinned(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Channel_AdminLog_MessageUnpinned, self._Channel_AdminLog_MessageUnpinned_r, [_0])
    }
    public let Cache_Photos: String
    public let Message_PinnedStickerMessage: String
    public let PhotoEditor_QualityMedium: String
    public let Privacy_PaymentsClearInfo: String
    public let PhotoEditor_CurvesRed: String
    public let Passport_Identity_AddPersonalDetails: String
    private let _Login_WillCallYou: String
    private let _Login_WillCallYou_r: [(Int, NSRange)]
    public func Login_WillCallYou(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Login_WillCallYou, self._Login_WillCallYou_r, [_0])
    }
    public let Privacy_PaymentsTitle: String
    public let SocksProxySetup_ProxyType: String
    private let _Time_PreciseDate_m8: String
    private let _Time_PreciseDate_m8_r: [(Int, NSRange)]
    public func Time_PreciseDate_m8(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Time_PreciseDate_m8, self._Time_PreciseDate_m8_r, [_1, _2, _3])
    }
    public let Login_PhoneNumberHelp: String
    public let User_DeletedAccount: String
    public let Call_StatusFailed: String
    private let _Notification_GroupInviter: String
    private let _Notification_GroupInviter_r: [(Int, NSRange)]
    public func Notification_GroupInviter(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Notification_GroupInviter, self._Notification_GroupInviter_r, [_0])
    }
    public let Localization_ChooseLanguage: String
    public let CheckoutInfo_ShippingInfoAddress2Placeholder: String
    private let _Notification_SecretChatMessageScreenshot: String
    private let _Notification_SecretChatMessageScreenshot_r: [(Int, NSRange)]
    public func Notification_SecretChatMessageScreenshot(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Notification_SecretChatMessageScreenshot, self._Notification_SecretChatMessageScreenshot_r, [_0])
    }
    private let _DialogList_SingleUploadingPhotoSuffix: String
    private let _DialogList_SingleUploadingPhotoSuffix_r: [(Int, NSRange)]
    public func DialogList_SingleUploadingPhotoSuffix(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_DialogList_SingleUploadingPhotoSuffix, self._DialogList_SingleUploadingPhotoSuffix_r, [_0])
    }
    public let Channel_LeaveChannel: String
    public let Compose_NewGroup: String
    public let TwoStepAuth_EmailPlaceholder: String
    public let PhotoEditor_ExposureTool: String
    public let Conversation_ViewChannel: String
    public let ChatAdmins_AdminLabel: String
    public let Contacts_FailedToSendInvitesMessage: String
    public let Login_Code: String
    public let Passport_Identity_ExpiryDateNone: String
    public let ContactInfo_PhoneLabelWorkFax: String
    public let Channel_Username_InvalidCharacters: String
    public let FeatureDisabled_Oops: String
    public let Calls_CallTabTitle: String
    public let ShareMenu_Send: String
    public let WatchRemote_AlertTitle: String
    public let Channel_Members_AddBannedErrorAdmin: String
    public let Conversation_InfoGroup: String
    public let Passport_Identity_TypePersonalDetails: String
    public let Passport_Identity_OneOfTypePassport: String
    public let Checkout_Phone: String
    public let Channel_SignMessages_Help: String
    public let Passport_PasswordNext: String
    public let Calls_SubmitRating: String
    public let Camera_FlashOn: String
    public let Watch_MessageView_Forward: String
    public let Passport_DiscardMessageTitle: String
    public let Passport_Language_uk: String
    public let GroupInfo_ActionPromote: String
    public let DialogList_You: String
    public let Weekday_Monday: String
    public let Passport_Identity_SelfieHelp: String
    public let Passport_Identity_MiddleName: String
    public let AccessDenied_Camera: String
    public let WatchRemote_NotificationText: String
    public let SharedMedia_ViewInChat: String
    public let Activity_RecordingAudio: String
    public let Watch_Stickers_StickerPacks: String
    private let _Target_ShareGameConfirmationPrivate: String
    private let _Target_ShareGameConfirmationPrivate_r: [(Int, NSRange)]
    public func Target_ShareGameConfirmationPrivate(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Target_ShareGameConfirmationPrivate, self._Target_ShareGameConfirmationPrivate_r, [_0])
    }
    public let Checkout_NewCard_PostcodePlaceholder: String
    public let Passport_Identity_OneOfTypeInternalPassport: String
    public let DialogList_DeleteConversationConfirmation: String
    public let AttachmentMenu_SendAsFile: String
    public let Watch_Conversation_Unblock: String
    public let Channel_AdminLog_MessagePreviousLink: String
    public let Conversation_ContextMenuCopy: String
    public let GroupInfo_UpgradeButton: String
    public let PrivacyLastSeenSettings_NeverShareWith: String
    public let ConvertToSupergroup_HelpText: String
    public let MediaPicker_VideoMuteDescription: String
    public let Passport_Address_TypeRentalAgreement: String
    public let Passport_Language_it: String
    public let UserInfo_ShareMyContactInfo: String
    public let Channel_Info_Stickers: String
    public let Appearance_ColorTheme: String
    private let _FileSize_GB: String
    private let _FileSize_GB_r: [(Int, NSRange)]
    public func FileSize_GB(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_FileSize_GB, self._FileSize_GB_r, [_0])
    }
    private let _Passport_FieldOneOf_Or: String
    private let _Passport_FieldOneOf_Or_r: [(Int, NSRange)]
    public func Passport_FieldOneOf_Or(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Passport_FieldOneOf_Or, self._Passport_FieldOneOf_Or_r, [_1, _2])
    }
    public let Month_ShortJanuary: String
    public let Channel_BanUser_PermissionsHeader: String
    public let PhotoEditor_QualityVeryHigh: String
    public let Passport_Language_mk: String
    public let Login_TermsOfServiceLabel: String
    private let _MESSAGE_TEXT: String
    private let _MESSAGE_TEXT_r: [(Int, NSRange)]
    public func MESSAGE_TEXT(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_MESSAGE_TEXT, self._MESSAGE_TEXT_r, [_1, _2])
    }
    public let DialogList_NoMessagesTitle: String
    public let Passport_DeletePassportConfirmation: String
    public let Passport_Language_az: String
    public let AccessDenied_Contacts: String
    public let Your_cards_security_code_is_invalid: String
    public let Contacts_InviteSearchLabel: String
    public let Tour_StartButton: String
    public let CheckoutInfo_Title: String
    public let Conversation_Admin: String
    private let _Channel_AdminLog_MessageRestrictedNameUsername: String
    private let _Channel_AdminLog_MessageRestrictedNameUsername_r: [(Int, NSRange)]
    public func Channel_AdminLog_MessageRestrictedNameUsername(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Channel_AdminLog_MessageRestrictedNameUsername, self._Channel_AdminLog_MessageRestrictedNameUsername_r, [_1, _2])
    }
    public let ChangePhoneNumberCode_Help: String
    public let Web_Error: String
    public let ShareFileTip_Title: String
    public let Privacy_SecretChatsLinkPreviews: String
    public let Username_InvalidStartsWithNumber: String
    private let _DialogList_EncryptedChatStartedIncoming: String
    private let _DialogList_EncryptedChatStartedIncoming_r: [(Int, NSRange)]
    public func DialogList_EncryptedChatStartedIncoming(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_DialogList_EncryptedChatStartedIncoming, self._DialogList_EncryptedChatStartedIncoming_r, [_0])
    }
    public let Calls_AddTab: String
    public let DialogList_AdNoticeAlert: String
    public let PhotoEditor_TiltShift: String
    public let Passport_Identity_TypeDriversLicenseUploadScan: String
    public let ChannelMembers_WhoCanAddMembers_Admins: String
    public let Tour_Text5: String
    public let Notifications_ExceptionsGroupPlaceholder: String
    public let Watch_Stickers_RecentPlaceholder: String
    public let Common_Select: String
    private let _Notification_MessageLifetimeRemoved: String
    private let _Notification_MessageLifetimeRemoved_r: [(Int, NSRange)]
    public func Notification_MessageLifetimeRemoved(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Notification_MessageLifetimeRemoved, self._Notification_MessageLifetimeRemoved_r, [_1])
    }
    private let _PINNED_INVOICE: String
    private let _PINNED_INVOICE_r: [(Int, NSRange)]
    public func PINNED_INVOICE(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_PINNED_INVOICE, self._PINNED_INVOICE_r, [_1])
    }
    public let Month_GenFebruary: String
    public let Contacts_SelectAll: String
    public let FastTwoStepSetup_EmailHelp: String
    public let Month_GenOctober: String
    public let CheckoutInfo_ErrorPhoneInvalid: String
    public let Passport_Identity_DocumentNumberPlaceholder: String
    public let AutoNightTheme_UpdateLocation: String
    public let Group_Setup_TypePublic: String
    public let Checkout_PaymentMethod_New: String
    public let ShareMenu_Comment: String
    public let Passport_FloodError: String
    public let Channel_Management_LabelEditor: String
    public let TwoStepAuth_SetPasswordHelp: String
    public let Channel_AdminLogFilter_EventsTitle: String
    public let NotificationSettings_ContactJoined: String
    public let ChatSettings_AutoDownloadVideos: String
    public let Passport_Identity_TypeIdentityCard: String
    public let Username_LinkCopied: String
    private let _Time_MonthOfYear_m9: String
    private let _Time_MonthOfYear_m9_r: [(Int, NSRange)]
    public func Time_MonthOfYear_m9(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Time_MonthOfYear_m9, self._Time_MonthOfYear_m9_r, [_0])
    }
    public let Channel_EditAdmin_PermissionAddAdmins: String
    public let Passport_FieldPhoneHelp: String
    public let Conversation_SendMessage: String
    public let Notification_CallIncoming: String
    private let _MESSAGE_FWDS: String
    private let _MESSAGE_FWDS_r: [(Int, NSRange)]
    public func MESSAGE_FWDS(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_MESSAGE_FWDS, self._MESSAGE_FWDS_r, [_1, _2])
    }
    public let Map_OpenInYandexMaps: String
    public let FastTwoStepSetup_PasswordHelp: String
    public let GroupInfo_GroupHistoryHidden: String
    public let AutoNightTheme_UseSunsetSunrise: String
    public let Month_ShortNovember: String
    public let AccessDenied_Settings: String
    public let EncryptionKey_Title: String
    public let Profile_MessageLifetime1h: String
    private let _Map_DistanceAway: String
    private let _Map_DistanceAway_r: [(Int, NSRange)]
    public func Map_DistanceAway(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Map_DistanceAway, self._Map_DistanceAway_r, [_0])
    }
    public let Checkout_ErrorPaymentFailed: String
    public let Compose_NewMessage: String
    public let Conversation_LiveLocationYou: String
    public let Privacy_TopPeersHelp: String
    public let Map_OpenInWaze: String
    public let Checkout_ShippingMethod: String
    public let Login_InfoFirstNamePlaceholder: String
    public let Checkout_ErrorProviderAccountInvalid: String
    public let CallSettings_TabIconDescription: String
    public let ChatSettings_AutoDownloadReset: String
    public let Checkout_WebConfirmation_Title: String
    public let PasscodeSettings_AutoLock: String
    public let Notifications_MessageNotificationsPreview: String
    public let Conversation_BlockUser: String
    public let Passport_Identity_EditPassport: String
    public let MessageTimer_Custom: String
    public let Conversation_SilentBroadcastTooltipOff: String
    public let Conversation_Mute: String
    public let CreateGroup_SoftUserLimitAlert: String
    public let AccessDenied_LocationDenied: String
    public let Tour_Title6: String
    public let Settings_UsernameEmpty: String
    public let PrivacySettings_TwoStepAuth: String
    public let Conversation_FileICloudDrive: String
    public let KeyCommand_SendMessage: String
    private let _Channel_AdminLog_MessageDeleted: String
    private let _Channel_AdminLog_MessageDeleted_r: [(Int, NSRange)]
    public func Channel_AdminLog_MessageDeleted(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Channel_AdminLog_MessageDeleted, self._Channel_AdminLog_MessageDeleted_r, [_0])
    }
    public let DialogList_DeleteBotConfirmation: String
    public let EditProfile_Title: String
    public let PasscodeSettings_HelpTop: String
    public let SocksProxySetup_ProxySocks5: String
    public let Common_TakePhotoOrVideo: String
    public let Notification_MessageLifetime2s: String
    public let Checkout_ErrorGeneric: String
    public let DialogList_Unread: String
    public let AutoNightTheme_Automatic: String
    public let Passport_Identity_Name: String
    public let Channel_AdminLog_CanBanUsers: String
    public let Cache_Indexing: String
    private let _ENCRYPTION_REQUEST: String
    private let _ENCRYPTION_REQUEST_r: [(Int, NSRange)]
    public func ENCRYPTION_REQUEST(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_ENCRYPTION_REQUEST, self._ENCRYPTION_REQUEST_r, [_1])
    }
    public let StickerSettings_ContextInfo: String
    public let Channel_BanUser_PermissionEmbedLinks: String
    public let Map_Location: String
    public let GroupInfo_InviteLink_LinkSection: String
    private let _Passport_Identity_UploadOneOfScan: String
    private let _Passport_Identity_UploadOneOfScan_r: [(Int, NSRange)]
    public func Passport_Identity_UploadOneOfScan(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Passport_Identity_UploadOneOfScan, self._Passport_Identity_UploadOneOfScan_r, [_0])
    }
    public let Notification_PassportValuePhone: String
    public let Privacy_Calls_AlwaysAllow_Placeholder: String
    public let CheckoutInfo_ShippingInfoPostcode: String
    public let Group_Setup_HistoryVisibleHelp: String
    private let _Time_PreciseDate_m7: String
    private let _Time_PreciseDate_m7_r: [(Int, NSRange)]
    public func Time_PreciseDate_m7(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Time_PreciseDate_m7, self._Time_PreciseDate_m7_r, [_1, _2, _3])
    }
    public let PasscodeSettings_EncryptDataHelp: String
    public let Passport_Language_ja: String
    public let KeyCommand_FocusOnInputField: String
    public let Channel_Members_AddAdminErrorBlacklisted: String
    public let Cache_KeepMedia: String
    public let SocksProxySetup_ProxyTelegram: String
    public let WebPreview_GettingLinkInfo: String
    public let Group_Setup_TypePublicHelp: String
    public let Map_Satellite: String
    public let Username_InvalidTaken: String
    private let _Notification_PinnedAudioMessage: String
    private let _Notification_PinnedAudioMessage_r: [(Int, NSRange)]
    public func Notification_PinnedAudioMessage(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Notification_PinnedAudioMessage, self._Notification_PinnedAudioMessage_r, [_0])
    }
    public let Notification_MessageLifetime1d: String
    public let Profile_MessageLifetime2s: String
    private let _TwoStepAuth_RecoveryEmailUnavailable: String
    private let _TwoStepAuth_RecoveryEmailUnavailable_r: [(Int, NSRange)]
    public func TwoStepAuth_RecoveryEmailUnavailable(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_TwoStepAuth_RecoveryEmailUnavailable, self._TwoStepAuth_RecoveryEmailUnavailable_r, [_0])
    }
    public let Calls_RatingFeedback: String
    public let Profile_EncryptionKey: String
    public let Watch_Suggestion_WhatsUp: String
    public let LoginPassword_PasswordPlaceholder: String
    public let TwoStepAuth_EnterPasswordPassword: String
    private let _Time_PreciseDate_m10: String
    private let _Time_PreciseDate_m10_r: [(Int, NSRange)]
    public func Time_PreciseDate_m10(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Time_PreciseDate_m10, self._Time_PreciseDate_m10_r, [_1, _2, _3])
    }
    private let _CHANNEL_MESSAGE_CONTACT: String
    private let _CHANNEL_MESSAGE_CONTACT_r: [(Int, NSRange)]
    public func CHANNEL_MESSAGE_CONTACT(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_CHANNEL_MESSAGE_CONTACT, self._CHANNEL_MESSAGE_CONTACT_r, [_1])
    }
    public let Passport_Language_bg: String
    public let PrivacySettings_DeleteAccountHelp: String
    public let Channel_Info_Banned: String
    public let Conversation_ShareBotContactConfirmationTitle: String
    public let ConversationProfile_UsersTooMuchError: String
    public let ChatAdmins_AllMembersAreAdminsOffHelp: String
    public let Privacy_GroupsAndChannels_WhoCanAddMe: String
    public let Login_CodeExpiredError: String
    public let Settings_PhoneNumber: String
    public let FastTwoStepSetup_EmailPlaceholder: String
    private let _DialogList_MultipleTypingSuffix: String
    private let _DialogList_MultipleTypingSuffix_r: [(Int, NSRange)]
    public func DialogList_MultipleTypingSuffix(_ _0: Int) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_DialogList_MultipleTypingSuffix, self._DialogList_MultipleTypingSuffix_r, ["\(_0)"])
    }
    public let Passport_Phone_Help: String
    public let Passport_Language_sl: String
    public let Bot_GenericBotStatus: String
    public let PrivacySettings_PasscodeAndTouchId: String
    public let Common_edit: String
    public let Settings_AppLanguage: String
    public let PrivacyLastSeenSettings_WhoCanSeeMyTimestamp: String
    private let _Notification_Kicked: String
    private let _Notification_Kicked_r: [(Int, NSRange)]
    public func Notification_Kicked(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Notification_Kicked, self._Notification_Kicked_r, [_0, _1])
    }
    public let Channel_AdminLog_MessageRestrictedForever: String
    public let Passport_DeleteDocument: String
    public let Notifications_ExceptionsResetToDefaults: String
    public let ChannelInfo_DeleteChannelConfirmation: String
    public let Passport_Address_OneOfTypeBankStatement: String
    public let Weekday_ShortSaturday: String
    public let Settings_Passport: String
    public let Share_AuthTitle: String
    public let Map_SendThisLocation: String
    private let _Notification_PinnedDocumentMessage: String
    private let _Notification_PinnedDocumentMessage_r: [(Int, NSRange)]
    public func Notification_PinnedDocumentMessage(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Notification_PinnedDocumentMessage, self._Notification_PinnedDocumentMessage_r, [_0])
    }
    public let Passport_Identity_Surname: String
    public let Conversation_ContextMenuReply: String
    public let Channel_BanUser_PermissionSendMedia: String
    public let NetworkUsageSettings_Wifi: String
    public let Call_Accept: String
    public let GroupInfo_SetGroupPhotoDelete: String
    public let Login_PhoneBannedError: String
    public let Passport_Identity_DocumentDetails: String
    public let PhotoEditor_CropAuto: String
    public let PhotoEditor_ContrastTool: String
    public let CheckoutInfo_ReceiverInfoNamePlaceholder: String
    public let Passport_InfoLearnMore: String
    public let Channel_AdminLog_MessagePreviousCaption: String
    private let _Passport_Email_UseTelegramEmail: String
    private let _Passport_Email_UseTelegramEmail_r: [(Int, NSRange)]
    public func Passport_Email_UseTelegramEmail(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Passport_Email_UseTelegramEmail, self._Passport_Email_UseTelegramEmail_r, [_0])
    }
    public let Privacy_PaymentsClear_ShippingInfo: String
    public let Passport_Email_UseTelegramEmailHelp: String
    public let UserInfo_NotificationsDefaultDisabled: String
    public let Date_DialogDateFormat: String
    public let Passport_Address_EditTemporaryRegistration: String
    public let ReportPeer_ReasonSpam: String
    public let Privacy_Calls_P2P: String
    public let Compose_TokenListPlaceholder: String
    private let _PINNED_VIDEO: String
    private let _PINNED_VIDEO_r: [(Int, NSRange)]
    public func PINNED_VIDEO(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_PINNED_VIDEO, self._PINNED_VIDEO_r, [_1])
    }
    public let StickerPacksSettings_Title: String
    public let Privacy_PaymentsClearInfoDoneHelp: String
    public let Privacy_Calls_NeverAllow_Placeholder: String
    public let Passport_PassportInformation: String
    public let Passport_Identity_OneOfTypeDriversLicense: String
    public let Settings_Support: String
    public let Notification_GroupInviterSelf: String
    private let _SecretImage_NotViewedYet: String
    private let _SecretImage_NotViewedYet_r: [(Int, NSRange)]
    public func SecretImage_NotViewedYet(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_SecretImage_NotViewedYet, self._SecretImage_NotViewedYet_r, [_0])
    }
    public let MaskStickerSettings_Title: String
    public let TwoStepAuth_SetPassword: String
    private let _Passport_AcceptHelp: String
    private let _Passport_AcceptHelp_r: [(Int, NSRange)]
    public func Passport_AcceptHelp(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Passport_AcceptHelp, self._Passport_AcceptHelp_r, [_1, _2])
    }
    public let SocksProxySetup_SavedProxies: String
    public let GroupInfo_InviteLink_ShareLink: String
    public let Common_Cancel: String
    public let UserInfo_About_Placeholder: String
    public let Passport_Identity_NativeNameGenericTitle: String
    public let Notifications_ChannelNotificationsPreview: String
    public let Camera_Discard: String
    public let ChangePhoneNumberCode_RequestingACall: String
    public let PrivacyLastSeenSettings_NeverShareWith_Title: String
    public let KeyCommand_JumpToNextChat: String
    private let _Time_MonthOfYear_m8: String
    private let _Time_MonthOfYear_m8_r: [(Int, NSRange)]
    public func Time_MonthOfYear_m8(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Time_MonthOfYear_m8, self._Time_MonthOfYear_m8_r, [_0])
    }
    public let Tour_Text1: String
    public let Privacy_SecretChatsTitle: String
    public let Conversation_HoldForVideo: String
    public let Passport_Language_pt: String
    public let Checkout_NewCard_Title: String
    public let Channel_TitleInfo: String
    public let State_ConnectingToProxy: String
    public let Settings_About_Help: String
    public let AutoNightTheme_ScheduledFrom: String
    public let Passport_Language_tk: String
    public let Watch_Conversation_Reply: String
    public let ShareMenu_CopyShareLink: String
    public let Stickers_Search: String
    public let Notifications_GroupNotificationsExceptions: String
    public let Channel_Setup_TypePrivateHelp: String
    public let PhotoEditor_GrainTool: String
    public let Conversation_SearchByName_Placeholder: String
    public let Watch_Suggestion_TalkLater: String
    public let TwoStepAuth_ChangeEmail: String
    public let Passport_Identity_EditPersonalDetails: String
    public let Passport_FieldPhone: String
    private let _ENCRYPTION_ACCEPT: String
    private let _ENCRYPTION_ACCEPT_r: [(Int, NSRange)]
    public func ENCRYPTION_ACCEPT(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_ENCRYPTION_ACCEPT, self._ENCRYPTION_ACCEPT_r, [_1])
    }
    public let NetworkUsageSettings_BytesSent: String
    public let Conversation_ShareBotLocationConfirmationTitle: String
    public let Conversation_ForwardContacts: String
    private let _Notification_ChangedGroupName: String
    private let _Notification_ChangedGroupName_r: [(Int, NSRange)]
    public func Notification_ChangedGroupName(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Notification_ChangedGroupName, self._Notification_ChangedGroupName_r, [_0, _1])
    }
    private let _MESSAGE_VIDEO: String
    private let _MESSAGE_VIDEO_r: [(Int, NSRange)]
    public func MESSAGE_VIDEO(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_MESSAGE_VIDEO, self._MESSAGE_VIDEO_r, [_1])
    }
    private let _Checkout_PayPrice: String
    private let _Checkout_PayPrice_r: [(Int, NSRange)]
    public func Checkout_PayPrice(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Checkout_PayPrice, self._Checkout_PayPrice_r, [_0])
    }
    private let _Notification_PinnedTextMessage: String
    private let _Notification_PinnedTextMessage_r: [(Int, NSRange)]
    public func Notification_PinnedTextMessage(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Notification_PinnedTextMessage, self._Notification_PinnedTextMessage_r, [_0, _1])
    }
    public let GroupInfo_InvitationLinkDoesNotExist: String
    public let ReportPeer_ReasonOther_Placeholder: String
    public let Wallpaper_Title: String
    public let PasscodeSettings_AutoLock_Disabled: String
    public let Watch_Compose_CreateMessage: String
    public let ChatSettings_ConnectionType_UseProxy: String
    public let Message_Audio: String
    public let Conversation_SearchNoResults: String
    public let PrivacyPolicy_Accept: String
    public let ReportPeer_ReasonViolence: String
    public let Group_Username_RemoveExistingUsernamesInfo: String
    public let Message_InvoiceLabel: String
    public let Channel_AdminLogFilter_Title: String
    public let Contacts_SearchLabel: String
    public let Group_Username_InvalidStartsWithNumber: String
    public let ChatAdmins_AllMembersAreAdminsOnHelp: String
    public let Month_ShortSeptember: String
    public let Group_Username_CreatePublicLinkHelp: String
    public let Login_CallRequestState2: String
    public let TwoStepAuth_RecoveryUnavailable: String
    public let Bot_Unblock: String
    public let SharedMedia_CategoryMedia: String
    public let Conversation_HoldForAudio: String
    public let Conversation_ClousStorageInfo_Description1: String
    public let Channel_Members_InviteLink: String
    public let Core_ServiceUserStatus: String
    public let WebSearch_RecentClearConfirmation: String
    public let Notification_ChannelMigratedFrom: String
    public let Settings_Title: String
    public let Call_StatusBusy: String
    public let ArchivedPacksAlert_Title: String
    public let ConversationMedia_Title: String
    private let _Conversation_MessageViaUser: String
    private let _Conversation_MessageViaUser_r: [(Int, NSRange)]
    public func Conversation_MessageViaUser(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Conversation_MessageViaUser, self._Conversation_MessageViaUser_r, [_0])
    }
    public let Notification_PassportValueAddress: String
    public let Tour_Title4: String
    public let Call_StatusEnded: String
    public let Notifications_ChannelNotificationsAlert: String
    public let LiveLocationUpdated_JustNow: String
    private let _Login_BannedPhoneSubject: String
    private let _Login_BannedPhoneSubject_r: [(Int, NSRange)]
    public func Login_BannedPhoneSubject(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Login_BannedPhoneSubject, self._Login_BannedPhoneSubject_r, [_0])
    }
    public let Passport_Address_EditResidentialAddress: String
    private let _Channel_Management_RestrictedBy: String
    private let _Channel_Management_RestrictedBy_r: [(Int, NSRange)]
    public func Channel_Management_RestrictedBy(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Channel_Management_RestrictedBy, self._Channel_Management_RestrictedBy_r, [_0])
    }
    public let Conversation_UnpinMessageAlert: String
    public let NotificationsSound_Glass: String
    public let Passport_Address_Street1Placeholder: String
    private let _Conversation_MessageDialogRetryAll: String
    private let _Conversation_MessageDialogRetryAll_r: [(Int, NSRange)]
    public func Conversation_MessageDialogRetryAll(_ _1: Int) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Conversation_MessageDialogRetryAll, self._Conversation_MessageDialogRetryAll_r, ["\(_1)"])
    }
    private let _Checkout_PasswordEntry_Text: String
    private let _Checkout_PasswordEntry_Text_r: [(Int, NSRange)]
    public func Checkout_PasswordEntry_Text(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Checkout_PasswordEntry_Text, self._Checkout_PasswordEntry_Text_r, [_0])
    }
    public let Call_Message: String
    public let Contacts_MemberSearchSectionTitleGroup: String
    private let _Conversation_BotInteractiveUrlAlert: String
    private let _Conversation_BotInteractiveUrlAlert_r: [(Int, NSRange)]
    public func Conversation_BotInteractiveUrlAlert(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Conversation_BotInteractiveUrlAlert, self._Conversation_BotInteractiveUrlAlert_r, [_0])
    }
    public let GroupInfo_SharedMedia: String
    private let _Time_PreciseDate_m6: String
    private let _Time_PreciseDate_m6_r: [(Int, NSRange)]
    public func Time_PreciseDate_m6(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Time_PreciseDate_m6, self._Time_PreciseDate_m6_r, [_1, _2, _3])
    }
    public let Channel_Username_InvalidStartsWithNumber: String
    public let KeyCommand_JumpToPreviousChat: String
    public let Conversation_Call: String
    public let KeyCommand_ScrollUp: String
    private let _Privacy_GroupsAndChannels_InviteToChannelError: String
    private let _Privacy_GroupsAndChannels_InviteToChannelError_r: [(Int, NSRange)]
    public func Privacy_GroupsAndChannels_InviteToChannelError(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Privacy_GroupsAndChannels_InviteToChannelError, self._Privacy_GroupsAndChannels_InviteToChannelError_r, [_0, _1])
    }
    public let AuthSessions_Sessions: String
    public let Document_TargetConfirmationFormat: String
    public let Group_Setup_TypeHeader: String
    private let _DialogList_SinglePlayingGameSuffix: String
    private let _DialogList_SinglePlayingGameSuffix_r: [(Int, NSRange)]
    public func DialogList_SinglePlayingGameSuffix(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_DialogList_SinglePlayingGameSuffix, self._DialogList_SinglePlayingGameSuffix_r, [_0])
    }
    public let AttachmentMenu_SendAsFiles: String
    public let Profile_MessageLifetime1m: String
    public let Passport_PasswordReset: String
    public let Settings_AppleWatch: String
    public let Notifications_ExceptionsTitle: String
    public let Passport_Language_de: String
    public let Channel_AdminLog_MessagePreviousDescription: String
    public let Your_card_was_declined: String
    public let Notifications_DisplayNamesOnLockScreen: String
    public let PhoneNumberHelp_ChangeNumber: String
    public let ReportPeer_ReasonPornography: String
    public let Notification_CreatedChannel: String
    public let PhotoEditor_Original: String
    public let NotificationsSound_Chord: String
    public let Target_SelectGroup: String
    public let Stickers_SuggestAdded: String
    public let Channel_AdminLog_InfoPanelAlertTitle: String
    public let Notifications_GroupNotificationsPreview: String
    public let ChatSettings_AutoDownloadPhotos: String
    public let Message_PinnedLocationMessage: String
    public let Appearance_PreviewReplyText: String
    public let Passport_Address_Street2Placeholder: String
    public let Settings_Logout: String
    private let _UserInfo_BlockConfirmation: String
    private let _UserInfo_BlockConfirmation_r: [(Int, NSRange)]
    public func UserInfo_BlockConfirmation(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_UserInfo_BlockConfirmation, self._UserInfo_BlockConfirmation_r, [_0])
    }
    public let Profile_Username: String
    public let Group_Username_InvalidTooShort: String
    public let Appearance_AutoNightTheme: String
    public let AuthSessions_TerminateOtherSessions: String
    public let PasscodeSettings_TryAgainIn1Minute: String
    public let Privacy_TopPeers: String
    public let Passport_Phone_EnterOtherNumber: String
    public let NotificationsSound_Hello: String
    public let Notifications_InAppNotifications: String
    private let _Notification_PassportValuesSentMessage: String
    private let _Notification_PassportValuesSentMessage_r: [(Int, NSRange)]
    public func Notification_PassportValuesSentMessage(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Notification_PassportValuesSentMessage, self._Notification_PassportValuesSentMessage_r, [_1, _2])
    }
    public let Passport_Language_is: String
    public let StickerPack_ViewPack: String
    public let EnterPasscode_ChangeTitle: String
    public let Call_Decline: String
    public let UserInfo_AddPhone: String
    public let AutoNightTheme_Title: String
    public let Activity_PlayingGame: String
    public let CheckoutInfo_ShippingInfoStatePlaceholder: String
    public let SaveIncomingPhotosSettings_From: String
    public let Passport_Address_TypeBankStatementUploadScan: String
    public let Notifications_MessageNotificationsSound: String
    public let Call_StatusWaiting: String
    public let Passport_Identity_MainPageHelp: String
    public let Weekday_ShortWednesday: String
    public let Notifications_Title: String
    public let PasscodeSettings_AutoLock_IfAwayFor_5hours: String
    public let Conversation_PinnedMessage: String
    public let Notifications_ChannelNotificationsHelp: String
    private let _Time_MonthOfYear_m12: String
    private let _Time_MonthOfYear_m12_r: [(Int, NSRange)]
    public func Time_MonthOfYear_m12(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Time_MonthOfYear_m12, self._Time_MonthOfYear_m12_r, [_0])
    }
    public let ConversationProfile_LeaveDeleteAndExit: String
    public let State_connecting: String
    public let Channel_AdminLog_MessagePreviousMessage: String
    public let Passport_Scans_Upload: String
    public let AutoDownloadSettings_PhotosTitle: String
    public let Map_OpenInHereMaps: String
    public let Stickers_FavoriteStickers: String
    public let CheckoutInfo_Pay: String
    public let Passport_Identity_FrontSideHelp: String
    public let Update_UpdateApp: String
    public let Login_CountryCode: String
    public let PasscodeSettings_AutoLock_IfAwayFor_1hour: String
    public let CheckoutInfo_ShippingInfoState: String
    private let _CHAT_MESSAGE_AUDIO: String
    private let _CHAT_MESSAGE_AUDIO_r: [(Int, NSRange)]
    public func CHAT_MESSAGE_AUDIO(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_CHAT_MESSAGE_AUDIO, self._CHAT_MESSAGE_AUDIO_r, [_1, _2])
    }
    public let Login_SmsRequestState2: String
    public let Preview_SaveToCameraRoll: String
    public let SocksProxySetup_ProxyStatusConnecting: String
    public let Broadcast_AdminLog_EmptyText: String
    public let PasscodeSettings_ChangePasscode: String
    public let TwoStepAuth_RecoveryCodeInvalid: String
    private let _Message_PaymentSent: String
    private let _Message_PaymentSent_r: [(Int, NSRange)]
    public func Message_PaymentSent(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Message_PaymentSent, self._Message_PaymentSent_r, [_0])
    }
    public let Message_PinnedAudioMessage: String
    public let ChatSettings_ConnectionType_Title: String
    private let _Conversation_RestrictedMediaTimed: String
    private let _Conversation_RestrictedMediaTimed_r: [(Int, NSRange)]
    public func Conversation_RestrictedMediaTimed(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Conversation_RestrictedMediaTimed, self._Conversation_RestrictedMediaTimed_r, [_0])
    }
    public let NotificationsSound_Complete: String
    public let NotificationsSound_Chime: String
    public let Login_InfoDeletePhoto: String
    public let ContactInfo_BirthdayLabel: String
    public let TwoStepAuth_RecoveryCodeExpired: String
    public let AutoDownloadSettings_Channels: String
    public let AutoDownloadSettings_Contacts: String
    public let TwoStepAuth_EmailTitle: String
    public let Passport_Email_EmailPlaceholder: String
    public let Channel_AdminLog_ChannelEmptyText: String
    public let Passport_Address_EditUtilityBill: String
    public let Privacy_GroupsAndChannels_NeverAllow: String
    public let Conversation_RestrictedStickers: String
    public let Conversation_AddContact: String
    private let _Time_MonthOfYear_m7: String
    private let _Time_MonthOfYear_m7_r: [(Int, NSRange)]
    public func Time_MonthOfYear_m7(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Time_MonthOfYear_m7, self._Time_MonthOfYear_m7_r, [_0])
    }
    public let PhotoEditor_QualityLow: String
    public let Paint_Outlined: String
    public let State_ConnectingToProxyInfo: String
    public let Checkout_PasswordEntry_Title: String
    public let Conversation_InputTextCaptionPlaceholder: String
    public let Common_Done: String
    public let Passport_Identity_FilesUploadNew: String
    public let PrivacySettings_LastSeenContacts: String
    public let Passport_Language_vi: String
    public let CheckoutInfo_ShippingInfoAddress1: String
    public let UserInfo_LastNamePlaceholder: String
    public let Conversation_StatusKickedFromChannel: String
    public let CheckoutInfo_ShippingInfoAddress2: String
    private let _DialogList_SingleTypingSuffix: String
    private let _DialogList_SingleTypingSuffix_r: [(Int, NSRange)]
    public func DialogList_SingleTypingSuffix(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_DialogList_SingleTypingSuffix, self._DialogList_SingleTypingSuffix_r, [_0])
    }
    public let LastSeen_JustNow: String
    public let GroupInfo_InviteLink_RevokeAlert_Text: String
    public let BroadcastListInfo_AddRecipient: String
    private let _Channel_Management_ErrorNotMember: String
    private let _Channel_Management_ErrorNotMember_r: [(Int, NSRange)]
    public func Channel_Management_ErrorNotMember(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Channel_Management_ErrorNotMember, self._Channel_Management_ErrorNotMember_r, [_0])
    }
    public let Privacy_Calls_NeverAllow: String
    public let Settings_About_Title: String
    public let PhoneNumberHelp_Help: String
    public let Channel_LinkItem: String
    public let Camera_Retake: String
    public let StickerPack_ShowStickers: String
    public let Conversation_RestrictedText: String
    public let Channel_Stickers_YourStickers: String
    private let _CHAT_CREATED: String
    private let _CHAT_CREATED_r: [(Int, NSRange)]
    public func CHAT_CREATED(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_CHAT_CREATED, self._CHAT_CREATED_r, [_1, _2])
    }
    public let LastSeen_WithinAMonth: String
    private let _PrivacySettings_LastSeenContactsPlus: String
    private let _PrivacySettings_LastSeenContactsPlus_r: [(Int, NSRange)]
    public func PrivacySettings_LastSeenContactsPlus(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_PrivacySettings_LastSeenContactsPlus, self._PrivacySettings_LastSeenContactsPlus_r, [_0])
    }
    public let ChangePhoneNumberNumber_NewNumber: String
    public let Compose_NewChannel: String
    public let NotificationsSound_Circles: String
    public let Login_TermsOfServiceAgree: String
    public let Channel_AdminLog_CanChangeInviteLink: String
    private let _Passport_RequestHeader: String
    private let _Passport_RequestHeader_r: [(Int, NSRange)]
    public func Passport_RequestHeader(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Passport_RequestHeader, self._Passport_RequestHeader_r, [_0])
    }
    private let _Call_CallInProgressMessage: String
    private let _Call_CallInProgressMessage_r: [(Int, NSRange)]
    public func Call_CallInProgressMessage(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Call_CallInProgressMessage, self._Call_CallInProgressMessage_r, [_1, _2])
    }
    public let Conversation_InputTextBroadcastPlaceholder: String
    private let _ShareFileTip_Text: String
    private let _ShareFileTip_Text_r: [(Int, NSRange)]
    public func ShareFileTip_Text(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_ShareFileTip_Text, self._ShareFileTip_Text_r, [_0])
    }
    private let _CancelResetAccount_TextSMS: String
    private let _CancelResetAccount_TextSMS_r: [(Int, NSRange)]
    public func CancelResetAccount_TextSMS(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_CancelResetAccount_TextSMS, self._CancelResetAccount_TextSMS_r, [_0])
    }
    public let Channel_EditAdmin_PermissionInviteUsers: String
    public let Privacy_Calls_P2PNever: String
    public let GroupInfo_DeleteAndExit: String
    public let GroupInfo_InviteLink_CopyLink: String
    public let Weekday_Friday: String
    public let Login_ResetAccountProtected_Title: String
    public let Settings_SetProfilePhoto: String
    public let Compose_ChannelTokenListPlaceholder: String
    public let Channel_EditAdmin_PermissionPinMessages: String
    public let Your_card_has_expired: String
    private let _CHAT_MESSAGE_INVOICE: String
    private let _CHAT_MESSAGE_INVOICE_r: [(Int, NSRange)]
    public func CHAT_MESSAGE_INVOICE(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_CHAT_MESSAGE_INVOICE, self._CHAT_MESSAGE_INVOICE_r, [_1, _2, _3])
    }
    public let ChannelInfo_ConfirmLeave: String
    public let ShareMenu_CopyShareLinkGame: String
    public let ReportPeer_ReasonOther: String
    private let _Username_UsernameIsAvailable: String
    private let _Username_UsernameIsAvailable_r: [(Int, NSRange)]
    public func Username_UsernameIsAvailable(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Username_UsernameIsAvailable, self._Username_UsernameIsAvailable_r, [_0])
    }
    public let KeyCommand_JumpToNextUnreadChat: String
    public let InfoPlist_NSContactsUsageDescription: String
    private let _SocksProxySetup_ProxyStatusPing: String
    private let _SocksProxySetup_ProxyStatusPing_r: [(Int, NSRange)]
    public func SocksProxySetup_ProxyStatusPing(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_SocksProxySetup_ProxyStatusPing, self._SocksProxySetup_ProxyStatusPing_r, [_0])
    }
    private let _Date_ChatDateHeader: String
    private let _Date_ChatDateHeader_r: [(Int, NSRange)]
    public func Date_ChatDateHeader(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Date_ChatDateHeader, self._Date_ChatDateHeader_r, [_1, _2])
    }
    public let Conversation_EncryptedDescriptionTitle: String
    public let DialogList_Pin: String
    private let _Notification_RemovedGroupPhoto: String
    private let _Notification_RemovedGroupPhoto_r: [(Int, NSRange)]
    public func Notification_RemovedGroupPhoto(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Notification_RemovedGroupPhoto, self._Notification_RemovedGroupPhoto_r, [_0])
    }
    public let Channel_ErrorAddTooMuch: String
    public let GroupInfo_SharedMediaNone: String
    public let ChatSettings_TextSizeUnits: String
    public let ChatSettings_AutoPlayAnimations: String
    public let Conversation_FileOpenIn: String
    public let Channel_Setup_TypePublic: String
    private let _ChangePhone_ErrorOccupied: String
    private let _ChangePhone_ErrorOccupied_r: [(Int, NSRange)]
    public func ChangePhone_ErrorOccupied(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_ChangePhone_ErrorOccupied, self._ChangePhone_ErrorOccupied_r, [_0])
    }
    public let ContactInfo_PhoneLabelMain: String
    public let Clipboard_SendPhoto: String
    public let Privacy_GroupsAndChannels_CustomShareHelp: String
    public let KeyCommand_ChatInfo: String
    public let Channel_AdminLog_EmptyFilterTitle: String
    public let PhotoEditor_HighlightsTint: String
    public let Passport_Address_Region: String
    public let Watch_Compose_AddContact: String
    private let _Time_PreciseDate_m5: String
    private let _Time_PreciseDate_m5_r: [(Int, NSRange)]
    public func Time_PreciseDate_m5(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Time_PreciseDate_m5, self._Time_PreciseDate_m5_r, [_1, _2, _3])
    }
    private let _Channel_AdminLog_MessageKickedNameUsername: String
    private let _Channel_AdminLog_MessageKickedNameUsername_r: [(Int, NSRange)]
    public func Channel_AdminLog_MessageKickedNameUsername(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Channel_AdminLog_MessageKickedNameUsername, self._Channel_AdminLog_MessageKickedNameUsername_r, [_1, _2])
    }
    private let _Login_WillSendSms: String
    private let _Login_WillSendSms_r: [(Int, NSRange)]
    public func Login_WillSendSms(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Login_WillSendSms, self._Login_WillSendSms_r, [_0])
    }
    public let Coub_TapForSound: String
    public let Compose_NewEncryptedChat: String
    public let PhotoEditor_CropReset: String
    public let Privacy_Calls_P2PAlways: String
    public let Passport_Address_TypeTemporaryRegistrationUploadScan: String
    public let Login_InvalidLastNameError: String
    public let Channel_Members_AddMembers: String
    public let Tour_Title2: String
    public let Login_TermsOfServiceHeader: String
    public let Channel_AdminLog_BanSendGifs: String
    public let Login_TermsOfServiceSignupDecline: String
    public let InfoPlist_NSMicrophoneUsageDescription: String
    public let AuthSessions_OtherSessions: String
    public let Watch_UserInfo_Title: String
    public let InstantPage_FeedbackButton: String
    private let _Generic_OpenHiddenLinkAlert: String
    private let _Generic_OpenHiddenLinkAlert_r: [(Int, NSRange)]
    public func Generic_OpenHiddenLinkAlert(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Generic_OpenHiddenLinkAlert, self._Generic_OpenHiddenLinkAlert_r, [_0])
    }
    public let Conversation_Contact: String
    public let NetworkUsageSettings_GeneralDataSection: String
    public let EnterPasscode_RepeatNewPasscode: String
    public let Conversation_ContextMenuCopyLink: String
    public let Passport_Language_sk: String
    public let InstantPage_AutoNightTheme: String
    public let CloudStorage_Title: String
    public let Month_ShortOctober: String
    public let Settings_FAQ: String
    public let PrivacySettings_LastSeen: String
    public let DialogList_SearchSectionRecent: String
    public let ChatSettings_AutomaticVideoMessageDownload: String
    public let Conversation_ContextMenuDelete: String
    public let Tour_Text6: String
    public let PhotoEditor_WarmthTool: String
    public let Passport_Address_TypePassportRegistrationUploadScan: String
    public let Common_TakePhoto: String
    public let SocksProxySetup_AdNoticeHelp: String
    public let UserInfo_CreateNewContact: String
    public let NetworkUsageSettings_MediaDocumentDataSection: String
    public let Login_CodeSentCall: String
    public let Watch_PhotoView_Title: String
    private let _PrivacySettings_LastSeenContactsMinus: String
    private let _PrivacySettings_LastSeenContactsMinus_r: [(Int, NSRange)]
    public func PrivacySettings_LastSeenContactsMinus(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_PrivacySettings_LastSeenContactsMinus, self._PrivacySettings_LastSeenContactsMinus_r, [_0])
    }
    public let ShareMenu_SelectChats: String
    public let Group_ErrorSendRestrictedMedia: String
    public let Group_Setup_HistoryVisible: String
    public let Channel_EditAdmin_PermissinAddAdminOff: String
    public let DialogList_ProxyConnectionIssuesTooltip: String
    public let Cache_Files: String
    public let PhotoEditor_EnhanceTool: String
    public let Conversation_SearchPlaceholder: String
    public let Channel_Stickers_NotFound: String
    public let UserInfo_NotificationsDefaultEnabled: String
    public let WatchRemote_AlertText: String
    public let Channel_AdminLog_CanInviteUsers: String
    public let Channel_BanUser_PermissionReadMessages: String
    public let AttachmentMenu_PhotoOrVideo: String
    public let Passport_Identity_GenderPlaceholder: String
    public let Month_ShortMarch: String
    public let GroupInfo_InviteLink_Title: String
    public let Watch_LastSeen_JustNow: String
    public let PhoneLabel_Title: String
    public let PrivacySettings_Passcode: String
    public let Paint_ClearConfirm: String
    public let SocksProxySetup_Secret: String
    private let _Checkout_SavePasswordTimeout: String
    private let _Checkout_SavePasswordTimeout_r: [(Int, NSRange)]
    public func Checkout_SavePasswordTimeout(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Checkout_SavePasswordTimeout, self._Checkout_SavePasswordTimeout_r, [_0])
    }
    public let PhotoEditor_BlurToolOff: String
    public let AccessDenied_VideoMicrophone: String
    public let Weekday_ShortThursday: String
    public let UserInfo_ShareContact: String
    public let LoginPassword_InvalidPasswordError: String
    public let NotificationsSound_Calypso: String
    private let _MESSAGE_PHOTO_SECRET: String
    private let _MESSAGE_PHOTO_SECRET_r: [(Int, NSRange)]
    public func MESSAGE_PHOTO_SECRET(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_MESSAGE_PHOTO_SECRET, self._MESSAGE_PHOTO_SECRET_r, [_1])
    }
    public let Login_PhoneAndCountryHelp: String
    public let CheckoutInfo_ReceiverInfoName: String
    public let NotificationsSound_Popcorn: String
    private let _Time_YesterdayAt: String
    private let _Time_YesterdayAt_r: [(Int, NSRange)]
    public func Time_YesterdayAt(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Time_YesterdayAt, self._Time_YesterdayAt_r, [_0])
    }
    public let Weekday_Yesterday: String
    public let Conversation_InputTextSilentBroadcastPlaceholder: String
    public let Embed_PlayingInPIP: String
    public let Localization_EnglishLanguageName: String
    public let Call_StatusIncoming: String
    public let Settings_Appearance: String
    public let Settings_PrivacySettings: String
    public let Conversation_SilentBroadcastTooltipOn: String
    private let _SecretVideo_NotViewedYet: String
    private let _SecretVideo_NotViewedYet_r: [(Int, NSRange)]
    public func SecretVideo_NotViewedYet(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_SecretVideo_NotViewedYet, self._SecretVideo_NotViewedYet_r, [_0])
    }
    private let _CHAT_MESSAGE_GEO: String
    private let _CHAT_MESSAGE_GEO_r: [(Int, NSRange)]
    public func CHAT_MESSAGE_GEO(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_CHAT_MESSAGE_GEO, self._CHAT_MESSAGE_GEO_r, [_1, _2])
    }
    public let DialogList_SearchLabel: String
    public let InfoPlist_NSLocationAlwaysAndWhenInUseUsageDescription: String
    public let Login_CodeSentInternal: String
    public let Channel_AdminLog_BanSendMessages: String
    public let Channel_MessagePhotoRemoved: String
    public let Conversation_StatusKickedFromGroup: String
    public let GroupInfo_ChatAdmins: String
    public let PhotoEditor_CurvesAll: String
    private let _Notification_LeftChannel: String
    private let _Notification_LeftChannel_r: [(Int, NSRange)]
    public func Notification_LeftChannel(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Notification_LeftChannel, self._Notification_LeftChannel_r, [_0])
    }
    public let Compose_Create: String
    private let _Passport_Identity_NativeNameGenericHelp: String
    private let _Passport_Identity_NativeNameGenericHelp_r: [(Int, NSRange)]
    public func Passport_Identity_NativeNameGenericHelp(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Passport_Identity_NativeNameGenericHelp, self._Passport_Identity_NativeNameGenericHelp_r, [_0])
    }
    private let _LOCKED_MESSAGE: String
    private let _LOCKED_MESSAGE_r: [(Int, NSRange)]
    public func LOCKED_MESSAGE(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_LOCKED_MESSAGE, self._LOCKED_MESSAGE_r, [_1])
    }
    public let Conversation_ClearPrivateHistory: String
    public let Conversation_ContextMenuShare: String
    public let Notifications_ExceptionsNone: String
    private let _Time_MonthOfYear_m6: String
    private let _Time_MonthOfYear_m6_r: [(Int, NSRange)]
    public func Time_MonthOfYear_m6(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Time_MonthOfYear_m6, self._Time_MonthOfYear_m6_r, [_0])
    }
    public let Conversation_ContextMenuReport: String
    private let _Call_GroupFormat: String
    private let _Call_GroupFormat_r: [(Int, NSRange)]
    public func Call_GroupFormat(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Call_GroupFormat, self._Call_GroupFormat_r, [_1, _2])
    }
    public let Forward_ChannelReadOnly: String
    public let Passport_InfoText: String
    public let Privacy_GroupsAndChannels_NeverAllow_Title: String
    private let _Passport_Address_UploadOneOfScan: String
    private let _Passport_Address_UploadOneOfScan_r: [(Int, NSRange)]
    public func Passport_Address_UploadOneOfScan(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Passport_Address_UploadOneOfScan, self._Passport_Address_UploadOneOfScan_r, [_0])
    }
    public let AutoDownloadSettings_Reset: String
    public let NotificationsSound_Synth: String
    private let _Channel_AdminLog_MessageInvitedName: String
    private let _Channel_AdminLog_MessageInvitedName_r: [(Int, NSRange)]
    public func Channel_AdminLog_MessageInvitedName(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Channel_AdminLog_MessageInvitedName, self._Channel_AdminLog_MessageInvitedName_r, [_1])
    }
    public let Conversation_Moderate_Ban: String
    public let Group_Status: String
    public let SocksProxySetup_ShareProxyList: String
    public let Passport_Phone_Delete: String
    public let Conversation_InputTextPlaceholder: String
    public let ContactInfo_PhoneLabelOther: String
    public let Passport_Language_lv: String
    public let TwoStepAuth_RecoveryCode: String
    public let Conversation_EditingMessageMediaEditCurrentPhoto: String
    public let Passport_DeleteDocumentConfirmation: String
    public let Passport_Language_hy: String
    public let SharedMedia_CategoryDocs: String
    public let Channel_AdminLog_CanChangeInfo: String
    public let Channel_AdminLogFilter_EventsAdmins: String
    public let Group_Setup_HistoryHiddenHelp: String
    private let _AuthSessions_AppUnofficial: String
    private let _AuthSessions_AppUnofficial_r: [(Int, NSRange)]
    public func AuthSessions_AppUnofficial(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_AuthSessions_AppUnofficial, self._AuthSessions_AppUnofficial_r, [_0])
    }
    public let NotificationsSound_Telegraph: String
    public let AutoNightTheme_Disabled: String
    public let Conversation_ContextMenuBan: String
    public let Channel_EditAdmin_PermissionsHeader: String
    public let SocksProxySetup_PortPlaceholder: String
    private let _DialogList_SingleUploadingVideoSuffix: String
    private let _DialogList_SingleUploadingVideoSuffix_r: [(Int, NSRange)]
    public func DialogList_SingleUploadingVideoSuffix(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_DialogList_SingleUploadingVideoSuffix, self._DialogList_SingleUploadingVideoSuffix_r, [_0])
    }
    public let Group_UpgradeNoticeHeader: String
    private let _CHAT_DELETE_YOU: String
    private let _CHAT_DELETE_YOU_r: [(Int, NSRange)]
    public func CHAT_DELETE_YOU(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_CHAT_DELETE_YOU, self._CHAT_DELETE_YOU_r, [_1, _2])
    }
    private let _MESSAGE_NOTEXT: String
    private let _MESSAGE_NOTEXT_r: [(Int, NSRange)]
    public func MESSAGE_NOTEXT(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_MESSAGE_NOTEXT, self._MESSAGE_NOTEXT_r, [_1])
    }
    private let _CHAT_MESSAGE_GIF: String
    private let _CHAT_MESSAGE_GIF_r: [(Int, NSRange)]
    public func CHAT_MESSAGE_GIF(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_CHAT_MESSAGE_GIF, self._CHAT_MESSAGE_GIF_r, [_1, _2])
    }
    public let GroupInfo_InviteLink_CopyAlert_Success: String
    public let Channel_Info_Members: String
    public let ShareFileTip_CloseTip: String
    public let KeyCommand_Find: String
    public let SecretVideo_Title: String
    public let Passport_DeleteAddressConfirmation: String
    public let Passport_DiscardMessageAction: String
    public let Passport_Language_dv: String
    public let Checkout_NewCard_PostcodeTitle: String
    public let Notifications_Badge_CountUnreadMessages_InfoOn: String
    private let _Channel_AdminLog_MessageRestricted: String
    private let _Channel_AdminLog_MessageRestricted_r: [(Int, NSRange)]
    public func Channel_AdminLog_MessageRestricted(_ _0: String, _ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Channel_AdminLog_MessageRestricted, self._Channel_AdminLog_MessageRestricted_r, [_0, _1, _2])
    }
    public let SocksProxySetup_SecretPlaceholder: String
    public let Channel_EditAdmin_PermissinAddAdminOn: String
    public let WebSearch_GIFs: String
    public let Privacy_ChatsTitle: String
    public let Conversation_SavedMessages: String
    public let TwoStepAuth_EnterPasswordTitle: String
    private let _CHANNEL_MESSAGE_GAME: String
    private let _CHANNEL_MESSAGE_GAME_r: [(Int, NSRange)]
    public func CHANNEL_MESSAGE_GAME(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_CHANNEL_MESSAGE_GAME, self._CHANNEL_MESSAGE_GAME_r, [_1, _2])
    }
    public let Channel_Subscribers_Title: String
    public let AccessDenied_CallMicrophone: String
    public let Conversation_DeleteMessagesForEveryone: String
    public let UserInfo_TapToCall: String
    public let Common_Edit: String
    public let Conversation_OpenFile: String
    public let PrivacyPolicy_Decline: String
    public let Passport_Identity_ResidenceCountryPlaceholder: String
    public let Message_PinnedDocumentMessage: String
    public let AuthSessions_LogOut: String
    public let AutoDownloadSettings_PrivateChats: String
    public let Checkout_TotalPaidAmount: String
    public let Conversation_UnsupportedMedia: String
    public let Passport_InvalidPasswordError: String
    private let _Message_ForwardedMessage: String
    private let _Message_ForwardedMessage_r: [(Int, NSRange)]
    public func Message_ForwardedMessage(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Message_ForwardedMessage, self._Message_ForwardedMessage_r, [_0])
    }
    private let _Time_PreciseDate_m4: String
    private let _Time_PreciseDate_m4_r: [(Int, NSRange)]
    public func Time_PreciseDate_m4(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Time_PreciseDate_m4, self._Time_PreciseDate_m4_r, [_1, _2, _3])
    }
    public let Checkout_NewCard_SaveInfoEnableHelp: String
    public let Call_AudioRouteHide: String
    public let CallSettings_OnMobile: String
    public let Conversation_GifTooltip: String
    public let Passport_Address_EditBankStatement: String
    public let CheckoutInfo_ErrorCityInvalid: String
    private let _CHANNEL_MESSAGE_PHOTOS: String
    private let _CHANNEL_MESSAGE_PHOTOS_r: [(Int, NSRange)]
    public func CHANNEL_MESSAGE_PHOTOS(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_CHANNEL_MESSAGE_PHOTOS, self._CHANNEL_MESSAGE_PHOTOS_r, [_1, _2])
    }
    public let Profile_CreateEncryptedChatError: String
    public let Map_LocationTitle: String
    public let Call_RateCall: String
    public let Passport_Address_City: String
    public let SocksProxySetup_PasswordPlaceholder: String
    public let Message_ReplyActionButtonShowReceipt: String
    public let PhotoEditor_ShadowsTool: String
    public let Checkout_NewCard_CardholderNamePlaceholder: String
    public let Cache_Title: String
    public let Passport_Email_Title: String
    public let Month_GenMay: String
    public let PasscodeSettings_HelpBottom: String
    private let _Notification_CreatedChat: String
    private let _Notification_CreatedChat_r: [(Int, NSRange)]
    public func Notification_CreatedChat(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Notification_CreatedChat, self._Notification_CreatedChat_r, [_0])
    }
    public let Calls_NoMissedCallsPlacehoder: String
    public let Passport_Address_RegionPlaceholder: String
    public let Channel_Stickers_NotFoundHelp: String
    public let Watch_UserInfo_Block: String
    public let Watch_LastSeen_ALongTimeAgo: String
    public let StickerPacksSettings_ManagingHelp: String
    public let Privacy_GroupsAndChannels_InviteToChannelMultipleError: String
    public let SearchImages_Title: String
    public let Channel_BlackList_Title: String
    private let _Conversation_LiveLocationYouAnd: String
    private let _Conversation_LiveLocationYouAnd_r: [(Int, NSRange)]
    public func Conversation_LiveLocationYouAnd(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Conversation_LiveLocationYouAnd, self._Conversation_LiveLocationYouAnd_r, [_0])
    }
    public let TwoStepAuth_PasswordRemovePassportConfirmation: String
    public let Checkout_NewCard_SaveInfo: String
    public let Notification_CallMissed: String
    public let Profile_ShareContactButton: String
    public let Group_ErrorSendRestrictedStickers: String
    public let Bot_GroupStatusDoesNotReadHistory: String
    public let Notification_Mute1h: String
    private let _Channel_AdminLog_MessageUnkickedName: String
    private let _Channel_AdminLog_MessageUnkickedName_r: [(Int, NSRange)]
    public func Channel_AdminLog_MessageUnkickedName(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Channel_AdminLog_MessageUnkickedName, self._Channel_AdminLog_MessageUnkickedName_r, [_1])
    }
    public let Settings_TabTitle: String
    public let Passport_Identity_ExpiryDatePlaceholder: String
    public let NetworkUsageSettings_MediaAudioDataSection: String
    public let GroupInfo_DeactivatedStatus: String
    private let _CHAT_PHOTO_EDITED: String
    private let _CHAT_PHOTO_EDITED_r: [(Int, NSRange)]
    public func CHAT_PHOTO_EDITED(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_CHAT_PHOTO_EDITED, self._CHAT_PHOTO_EDITED_r, [_1, _2])
    }
    public let Conversation_ContextMenuMore: String
    private let _PrivacySettings_LastSeenEverybodyMinus: String
    private let _PrivacySettings_LastSeenEverybodyMinus_r: [(Int, NSRange)]
    public func PrivacySettings_LastSeenEverybodyMinus(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_PrivacySettings_LastSeenEverybodyMinus, self._PrivacySettings_LastSeenEverybodyMinus_r, [_0])
    }
    public let Map_ShareLiveLocation: String
    public let Weekday_Today: String
    private let _PINNED_GEOLIVE: String
    private let _PINNED_GEOLIVE_r: [(Int, NSRange)]
    public func PINNED_GEOLIVE(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_PINNED_GEOLIVE, self._PINNED_GEOLIVE_r, [_1])
    }
    private let _Conversation_RestrictedStickersTimed: String
    private let _Conversation_RestrictedStickersTimed_r: [(Int, NSRange)]
    public func Conversation_RestrictedStickersTimed(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Conversation_RestrictedStickersTimed, self._Conversation_RestrictedStickersTimed_r, [_0])
    }
    public let Login_InvalidFirstNameError: String
    private let _Channel_AdminLog_MessageUnkickedNameUsername: String
    private let _Channel_AdminLog_MessageUnkickedNameUsername_r: [(Int, NSRange)]
    public func Channel_AdminLog_MessageUnkickedNameUsername(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Channel_AdminLog_MessageUnkickedNameUsername, self._Channel_AdminLog_MessageUnkickedNameUsername_r, [_1, _2])
    }
    private let _Notification_Joined: String
    private let _Notification_Joined_r: [(Int, NSRange)]
    public func Notification_Joined(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Notification_Joined, self._Notification_Joined_r, [_0])
    }
    public let Paint_Clear: String
    public let TwoStepAuth_RecoveryFailed: String
    private let _MESSAGE_AUDIO: String
    private let _MESSAGE_AUDIO_r: [(Int, NSRange)]
    public func MESSAGE_AUDIO(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_MESSAGE_AUDIO, self._MESSAGE_AUDIO_r, [_1])
    }
    public let Checkout_PasswordEntry_Pay: String
    public let Conversation_EditingMessagePanelMedia: String
    public let Notifications_MessageNotificationsHelp: String
    public let EnterPasscode_EnterCurrentPasscode: String
    public let Conversation_EditingMessageMediaEditCurrentVideo: String
    private let _MESSAGE_GAME: String
    private let _MESSAGE_GAME_r: [(Int, NSRange)]
    public func MESSAGE_GAME(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_MESSAGE_GAME, self._MESSAGE_GAME_r, [_1, _2])
    }
    public let Conversation_Moderate_Report: String
    public let MessageTimer_Forever: String
    public let DialogList_SavedMessagesHelp: String
    private let _Conversation_EncryptedPlaceholderTitleIncoming: String
    private let _Conversation_EncryptedPlaceholderTitleIncoming_r: [(Int, NSRange)]
    public func Conversation_EncryptedPlaceholderTitleIncoming(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Conversation_EncryptedPlaceholderTitleIncoming, self._Conversation_EncryptedPlaceholderTitleIncoming_r, [_0])
    }
    private let _Map_AccurateTo: String
    private let _Map_AccurateTo_r: [(Int, NSRange)]
    public func Map_AccurateTo(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Map_AccurateTo, self._Map_AccurateTo_r, [_0])
    }
    private let _Call_ParticipantVersionOutdatedError: String
    private let _Call_ParticipantVersionOutdatedError_r: [(Int, NSRange)]
    public func Call_ParticipantVersionOutdatedError(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Call_ParticipantVersionOutdatedError, self._Call_ParticipantVersionOutdatedError_r, [_0])
    }
    public let Passport_Identity_ReverseSideHelp: String
    public let Tour_Text2: String
    public let Call_StatusNoAnswer: String
    private let _Passport_Phone_UseTelegramNumber: String
    private let _Passport_Phone_UseTelegramNumber_r: [(Int, NSRange)]
    public func Passport_Phone_UseTelegramNumber(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Passport_Phone_UseTelegramNumber, self._Passport_Phone_UseTelegramNumber_r, [_0])
    }
    public let Channel_AdminLogFilter_EventsLeavingSubscribers: String
    public let Conversation_MessageDialogDelete: String
    public let Appearance_PreviewOutgoingText: String
    public let Username_Placeholder: String
    private let _Notification_PinnedDeletedMessage: String
    private let _Notification_PinnedDeletedMessage_r: [(Int, NSRange)]
    public func Notification_PinnedDeletedMessage(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Notification_PinnedDeletedMessage, self._Notification_PinnedDeletedMessage_r, [_0])
    }
    private let _Time_MonthOfYear_m11: String
    private let _Time_MonthOfYear_m11_r: [(Int, NSRange)]
    public func Time_MonthOfYear_m11(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Time_MonthOfYear_m11, self._Time_MonthOfYear_m11_r, [_0])
    }
    public let UserInfo_BotHelp: String
    public let TwoStepAuth_PasswordSet: String
    private let _CHANNEL_MESSAGE_VIDEO: String
    private let _CHANNEL_MESSAGE_VIDEO_r: [(Int, NSRange)]
    public func CHANNEL_MESSAGE_VIDEO(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_CHANNEL_MESSAGE_VIDEO, self._CHANNEL_MESSAGE_VIDEO_r, [_1])
    }
    public let EnterPasscode_TouchId: String
    public let AuthSessions_LoggedInWithTelegram: String
    public let Checkout_ErrorInvoiceAlreadyPaid: String
    public let ChatAdmins_Title: String
    public let ChannelMembers_WhoCanAddMembers: String
    public let Passport_Language_ar: String
    public let PasscodeSettings_Help: String
    public let Conversation_EditingMessagePanelTitle: String
    public let Settings_AboutEmpty: String
    private let _NetworkUsageSettings_CellularUsageSince: String
    private let _NetworkUsageSettings_CellularUsageSince_r: [(Int, NSRange)]
    public func NetworkUsageSettings_CellularUsageSince(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_NetworkUsageSettings_CellularUsageSince, self._NetworkUsageSettings_CellularUsageSince_r, [_0])
    }
    public let GroupInfo_ConvertToSupergroup: String
    private let _Notification_PinnedContactMessage: String
    private let _Notification_PinnedContactMessage_r: [(Int, NSRange)]
    public func Notification_PinnedContactMessage(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Notification_PinnedContactMessage, self._Notification_PinnedContactMessage_r, [_0])
    }
    public let CallSettings_UseLessDataLongDescription: String
    public let FastTwoStepSetup_PasswordPlaceholder: String
    public let Conversation_SecretChatContextBotAlert: String
    public let Channel_Moderator_AccessLevelRevoke: String
    public let CheckoutInfo_ReceiverInfoTitle: String
    public let Channel_AdminLogFilter_EventsRestrictions: String
    public let GroupInfo_InviteLink_RevokeLink: String
    public let Checkout_PaymentMethod_Title: String
    public let Conversation_Unmute: String
    public let AutoDownloadSettings_DocumentsTitle: String
    public let Passport_FieldOneOf_FinalDelimeter: String
    public let Notifications_MessageNotifications: String
    public let Passport_ForgottenPassword: String
    public let ChannelMembers_WhoCanAddMembersAdminsHelp: String
    public let DialogList_DeleteBotConversationConfirmation: String
    public let Passport_Identity_TranslationHelp: String
    private let _Update_AppVersion: String
    private let _Update_AppVersion_r: [(Int, NSRange)]
    public func Update_AppVersion(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Update_AppVersion, self._Update_AppVersion_r, [_0])
    }
    private let _DialogList_MultipleTyping: String
    private let _DialogList_MultipleTyping_r: [(Int, NSRange)]
    public func DialogList_MultipleTyping(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_DialogList_MultipleTyping, self._DialogList_MultipleTyping_r, [_0, _1])
    }
    public let Passport_Identity_OneOfTypeIdentityCard: String
    public let Conversation_ClousStorageInfo_Description2: String
    private let _Time_MonthOfYear_m5: String
    private let _Time_MonthOfYear_m5_r: [(Int, NSRange)]
    public func Time_MonthOfYear_m5(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Time_MonthOfYear_m5, self._Time_MonthOfYear_m5_r, [_0])
    }
    public let Map_Hybrid: String
    public let Channel_Setup_Title: String
    public let MediaPicker_TimerTooltip: String
    public let Activity_UploadingVideo: String
    public let Channel_Info_Management: String
    private let _Login_TermsOfService_ProceedBot: String
    private let _Login_TermsOfService_ProceedBot_r: [(Int, NSRange)]
    public func Login_TermsOfService_ProceedBot(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Login_TermsOfService_ProceedBot, self._Login_TermsOfService_ProceedBot_r, [_0])
    }
    private let _Notification_MessageLifetimeChangedOutgoing: String
    private let _Notification_MessageLifetimeChangedOutgoing_r: [(Int, NSRange)]
    public func Notification_MessageLifetimeChangedOutgoing(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Notification_MessageLifetimeChangedOutgoing, self._Notification_MessageLifetimeChangedOutgoing_r, [_1])
    }
    public let PhotoEditor_QualityVeryLow: String
    public let Stickers_AddToFavorites: String
    public let Month_ShortFebruary: String
    public let Notifications_AddExceptionTitle: String
    public let Conversation_ForwardTitle: String
    public let Settings_FAQ_URL: String
    public let Activity_RecordingVideoMessage: String
    public let SharedMedia_EmptyFilesText: String
    private let _Contacts_AccessDeniedHelpLandscape: String
    private let _Contacts_AccessDeniedHelpLandscape_r: [(Int, NSRange)]
    public func Contacts_AccessDeniedHelpLandscape(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Contacts_AccessDeniedHelpLandscape, self._Contacts_AccessDeniedHelpLandscape_r, [_0])
    }
    public let PasscodeSettings_UnlockWithTouchId: String
    public let Contacts_AccessDeniedHelpON: String
    public let Passport_Identity_AddInternalPassport: String
    public let NetworkUsageSettings_ResetStats: String
    public let Share_AuthDescription: String
    private let _CHAT_MESSAGE_PHOTOS: String
    private let _CHAT_MESSAGE_PHOTOS_r: [(Int, NSRange)]
    public func CHAT_MESSAGE_PHOTOS(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_CHAT_MESSAGE_PHOTOS, self._CHAT_MESSAGE_PHOTOS_r, [_1, _2, _3])
    }
    private let _PrivacySettings_LastSeenContactsMinusPlus: String
    private let _PrivacySettings_LastSeenContactsMinusPlus_r: [(Int, NSRange)]
    public func PrivacySettings_LastSeenContactsMinusPlus(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_PrivacySettings_LastSeenContactsMinusPlus, self._PrivacySettings_LastSeenContactsMinusPlus_r, [_0, _1])
    }
    public let Channel_AdminLog_EmptyMessageText: String
    private let _Notification_ChannelInviter: String
    private let _Notification_ChannelInviter_r: [(Int, NSRange)]
    public func Notification_ChannelInviter(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Notification_ChannelInviter, self._Notification_ChannelInviter_r, [_0])
    }
    public let SocksProxySetup_TypeSocks: String
    public let Profile_MessageLifetimeForever: String
    public let MediaPicker_UngroupDescription: String
    private let _Checkout_SavePasswordTimeoutAndFaceId: String
    private let _Checkout_SavePasswordTimeoutAndFaceId_r: [(Int, NSRange)]
    public func Checkout_SavePasswordTimeoutAndFaceId(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Checkout_SavePasswordTimeoutAndFaceId, self._Checkout_SavePasswordTimeoutAndFaceId_r, [_0])
    }
    public let SocksProxySetup_Username: String
    public let Conversation_Edit: String
    public let TwoStepAuth_ResetAccountHelp: String
    public let Month_GenDecember: String
    private let _Watch_LastSeen_YesterdayAt: String
    private let _Watch_LastSeen_YesterdayAt_r: [(Int, NSRange)]
    public func Watch_LastSeen_YesterdayAt(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Watch_LastSeen_YesterdayAt, self._Watch_LastSeen_YesterdayAt_r, [_0])
    }
    public let Channel_ErrorAddBlocked: String
    public let Conversation_Unpin: String
    public let Call_RecordingDisabledMessage: String
    public let Passport_Address_TypeUtilityBill: String
    public let Conversation_UnblockUser: String
    public let Conversation_Unblock: String
    private let _CHANNEL_MESSAGE_GIF: String
    private let _CHANNEL_MESSAGE_GIF_r: [(Int, NSRange)]
    public func CHANNEL_MESSAGE_GIF(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_CHANNEL_MESSAGE_GIF, self._CHANNEL_MESSAGE_GIF_r, [_1])
    }
    public let Channel_AdminLogFilter_EventsEditedMessages: String
    public let AutoNightTheme_ScheduleSection: String
    public let Appearance_ThemeNightBlue: String
    private let _Passport_Scans_ScanIndex: String
    private let _Passport_Scans_ScanIndex_r: [(Int, NSRange)]
    public func Passport_Scans_ScanIndex(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Passport_Scans_ScanIndex, self._Passport_Scans_ScanIndex_r, [_0])
    }
    public let Channel_Username_InvalidTooShort: String
    public let Conversation_ViewGroup: String
    public let Watch_LastSeen_WithinAWeek: String
    public let BlockedUsers_SelectUserTitle: String
    public let Profile_MessageLifetime1w: String
    public let Passport_Address_TypeRentalAgreementUploadScan: String
    public let DialogList_TabTitle: String
    public let UserInfo_GenericPhoneLabel: String
    private let _Channel_AdminLog_MessagePromotedName: String
    private let _Channel_AdminLog_MessagePromotedName_r: [(Int, NSRange)]
    public func Channel_AdminLog_MessagePromotedName(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Channel_AdminLog_MessagePromotedName, self._Channel_AdminLog_MessagePromotedName_r, [_1])
    }
    public let Group_Members_AddMemberBotErrorNotAllowed: String
    private let _Username_LinkHint: String
    private let _Username_LinkHint_r: [(Int, NSRange)]
    public func Username_LinkHint(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Username_LinkHint, self._Username_LinkHint_r, [_0])
    }
    public let Map_StopLiveLocation: String
    public let Message_LiveLocation: String
    public let NetworkUsageSettings_Title: String
    public let CheckoutInfo_ShippingInfoPostcodePlaceholder: String
    public let InfoPlist_NSPhotoLibraryUsageDescription: String
    public let Wallpaper_Wallpaper: String
    public let GroupInfo_InviteLink_RevokeAlert_Revoke: String
    public let SharedMedia_TitleLink: String
    private let _Channel_AdminLog_MessageRestrictedName: String
    private let _Channel_AdminLog_MessageRestrictedName_r: [(Int, NSRange)]
    public func Channel_AdminLog_MessageRestrictedName(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Channel_AdminLog_MessageRestrictedName, self._Channel_AdminLog_MessageRestrictedName_r, [_1])
    }
    private let _Channel_AdminLog_MessageGroupPreHistoryHidden: String
    private let _Channel_AdminLog_MessageGroupPreHistoryHidden_r: [(Int, NSRange)]
    public func Channel_AdminLog_MessageGroupPreHistoryHidden(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Channel_AdminLog_MessageGroupPreHistoryHidden, self._Channel_AdminLog_MessageGroupPreHistoryHidden_r, [_0])
    }
    public let Channel_JoinChannel: String
    public let StickerPack_Add: String
    public let Group_ErrorNotMutualContact: String
    public let AccessDenied_LocationDisabled: String
    public let Login_UnknownError: String
    public let Presence_online: String
    public let DialogList_Title: String
    public let Stickers_Install: String
    public let SearchImages_NoImagesFound: String
    private let _Watch_Time_ShortTodayAt: String
    private let _Watch_Time_ShortTodayAt_r: [(Int, NSRange)]
    public func Watch_Time_ShortTodayAt(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Watch_Time_ShortTodayAt, self._Watch_Time_ShortTodayAt_r, [_0])
    }
    public let Channel_AdminLogFilter_EventsNewSubscribers: String
    public let Passport_Identity_ExpiryDate: String
    public let UserInfo_GroupsInCommon: String
    public let Message_PinnedContactMessage: String
    public let AccessDenied_CameraDisabled: String
    private let _Time_PreciseDate_m3: String
    private let _Time_PreciseDate_m3_r: [(Int, NSRange)]
    public func Time_PreciseDate_m3(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Time_PreciseDate_m3, self._Time_PreciseDate_m3_r, [_1, _2, _3])
    }
    public let Passport_Email_EnterOtherEmail: String
    private let _LiveLocationUpdated_YesterdayAt: String
    private let _LiveLocationUpdated_YesterdayAt_r: [(Int, NSRange)]
    public func LiveLocationUpdated_YesterdayAt(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_LiveLocationUpdated_YesterdayAt, self._LiveLocationUpdated_YesterdayAt_r, [_0])
    }
    public let NotificationsSound_Note: String
    public let Passport_Identity_MiddleNamePlaceholder: String
    public let PrivacyPolicy_Title: String
    public let Month_GenMarch: String
    public let Watch_UserInfo_Unmute: String
    public let CheckoutInfo_ErrorPostcodeInvalid: String
    public let Common_Delete: String
    public let Username_Title: String
    public let Login_PhoneFloodError: String
    public let Channel_AdminLog_InfoPanelTitle: String
    private let _CHANNEL_MESSAGE_PHOTO: String
    private let _CHANNEL_MESSAGE_PHOTO_r: [(Int, NSRange)]
    public func CHANNEL_MESSAGE_PHOTO(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_CHANNEL_MESSAGE_PHOTO, self._CHANNEL_MESSAGE_PHOTO_r, [_1])
    }
    private let _Channel_AdminLog_MessageToggleInvitesOff: String
    private let _Channel_AdminLog_MessageToggleInvitesOff_r: [(Int, NSRange)]
    public func Channel_AdminLog_MessageToggleInvitesOff(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Channel_AdminLog_MessageToggleInvitesOff, self._Channel_AdminLog_MessageToggleInvitesOff_r, [_0])
    }
    public let Group_ErrorAddTooMuchBots: String
    private let _Notification_CallFormat: String
    private let _Notification_CallFormat_r: [(Int, NSRange)]
    public func Notification_CallFormat(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Notification_CallFormat, self._Notification_CallFormat_r, [_1, _2])
    }
    private let _CHAT_MESSAGE_PHOTO: String
    private let _CHAT_MESSAGE_PHOTO_r: [(Int, NSRange)]
    public func CHAT_MESSAGE_PHOTO(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_CHAT_MESSAGE_PHOTO, self._CHAT_MESSAGE_PHOTO_r, [_1, _2])
    }
    private let _UserInfo_UnblockConfirmation: String
    private let _UserInfo_UnblockConfirmation_r: [(Int, NSRange)]
    public func UserInfo_UnblockConfirmation(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_UserInfo_UnblockConfirmation, self._UserInfo_UnblockConfirmation_r, [_0])
    }
    public let Appearance_PickAccentColor: String
    public let Passport_Identity_EditDriversLicense: String
    public let Passport_Identity_AddPassport: String
    public let UserInfo_ShareBot: String
    public let Settings_ProxyConnected: String
    public let ChatSettings_AutoDownloadVoiceMessages: String
    public let TwoStepAuth_EmailSkip: String
    public let Conversation_ViewContactDetails: String
    public let Notifications_Badge_CountUnreadMessages_InfoOff: String
    public let Conversation_JumpToDate: String
    public let AutoDownloadSettings_VideoMessagesTitle: String
    public let Passport_Address_OneOfTypeUtilityBill: String
    public let CheckoutInfo_ReceiverInfoEmailPlaceholder: String
    public let Message_Photo: String
    public let Conversation_ReportSpam: String
    public let Camera_FlashAuto: String
    public let Passport_Identity_TypePassportUploadScan: String
    public let Call_ConnectionErrorMessage: String
    public let Stickers_FrequentlyUsed: String
    public let LastSeen_ALongTimeAgo: String
    public let Passport_Identity_ReverseSide: String
    public let DialogList_SearchSectionGlobal: String
    public let ChangePhoneNumberNumber_NumberPlaceholder: String
    public let GroupInfo_AddUserLeftError: String
    public let Appearance_ThemeDay: String
    public let GroupInfo_GroupType: String
    public let Watch_Suggestion_OnMyWay: String
    public let Checkout_NewCard_PaymentCard: String
    private let _DialogList_SearchSubtitleFormat: String
    private let _DialogList_SearchSubtitleFormat_r: [(Int, NSRange)]
    public func DialogList_SearchSubtitleFormat(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_DialogList_SearchSubtitleFormat, self._DialogList_SearchSubtitleFormat_r, [_1, _2])
    }
    public let PhotoEditor_CropAspectRatioOriginal: String
    private let _Conversation_RestrictedInlineTimed: String
    private let _Conversation_RestrictedInlineTimed_r: [(Int, NSRange)]
    public func Conversation_RestrictedInlineTimed(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Conversation_RestrictedInlineTimed, self._Conversation_RestrictedInlineTimed_r, [_0])
    }
    public let UserInfo_NotificationsDisabled: String
    private let _CONTACT_JOINED: String
    private let _CONTACT_JOINED_r: [(Int, NSRange)]
    public func CONTACT_JOINED(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_CONTACT_JOINED, self._CONTACT_JOINED_r, [_1])
    }
    public let NotificationsSound_Bamboo: String
    public let PrivacyLastSeenSettings_AlwaysShareWith_Title: String
    private let _Channel_AdminLog_MessageGroupPreHistoryVisible: String
    private let _Channel_AdminLog_MessageGroupPreHistoryVisible_r: [(Int, NSRange)]
    public func Channel_AdminLog_MessageGroupPreHistoryVisible(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Channel_AdminLog_MessageGroupPreHistoryVisible, self._Channel_AdminLog_MessageGroupPreHistoryVisible_r, [_0])
    }
    public let BlockedUsers_LeavePrefix: String
    public let NetworkUsageSettings_ResetStatsConfirmation: String
    public let Group_Setup_HistoryHeader: String
    public let Channel_EditAdmin_PermissionPostMessages: String
    private let _Contacts_AddPhoneNumber: String
    private let _Contacts_AddPhoneNumber_r: [(Int, NSRange)]
    public func Contacts_AddPhoneNumber(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Contacts_AddPhoneNumber, self._Contacts_AddPhoneNumber_r, [_0])
    }
    private let _MESSAGE_SCREENSHOT: String
    private let _MESSAGE_SCREENSHOT_r: [(Int, NSRange)]
    public func MESSAGE_SCREENSHOT(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_MESSAGE_SCREENSHOT, self._MESSAGE_SCREENSHOT_r, [_1])
    }
    public let DialogList_EncryptionProcessing: String
    public let GroupInfo_GroupHistory: String
    public let Conversation_ApplyLocalization: String
    public let FastTwoStepSetup_Title: String
    public let SocksProxySetup_ProxyStatusUnavailable: String
    public let Passport_Address_EditRentalAgreement: String
    public let Conversation_DeleteManyMessages: String
    public let CancelResetAccount_Title: String
    public let Notification_CallOutgoingShort: String
    public let SharedMedia_TitleAll: String
    public let Conversation_SlideToCancel: String
    public let AuthSessions_TerminateSession: String
    public let Channel_AdminLogFilter_EventsDeletedMessages: String
    public let PrivacyLastSeenSettings_AlwaysShareWith_Placeholder: String
    public let Channel_Members_Title: String
    public let Channel_AdminLog_CanDeleteMessages: String
    public let Privacy_DeleteDrafts: String
    public let Group_Setup_TypePrivateHelp: String
    private let _Notification_PinnedVideoMessage: String
    private let _Notification_PinnedVideoMessage_r: [(Int, NSRange)]
    public func Notification_PinnedVideoMessage(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Notification_PinnedVideoMessage, self._Notification_PinnedVideoMessage_r, [_0])
    }
    public let Conversation_ContextMenuStickerPackAdd: String
    public let Channel_AdminLogFilter_EventsNewMembers: String
    public let Channel_AdminLogFilter_EventsPinned: String
    private let _Conversation_Moderate_DeleteAllMessages: String
    private let _Conversation_Moderate_DeleteAllMessages_r: [(Int, NSRange)]
    public func Conversation_Moderate_DeleteAllMessages(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Conversation_Moderate_DeleteAllMessages, self._Conversation_Moderate_DeleteAllMessages_r, [_0])
    }
    public let SharedMedia_CategoryOther: String
    public let Passport_Address_Address: String
    public let DialogList_SavedMessagesTooltip: String
    public let Preview_DeletePhoto: String
    public let GroupInfo_ChannelListNamePlaceholder: String
    public let PasscodeSettings_TurnPasscodeOn: String
    public let AuthSessions_LogOutApplicationsHelp: String
    public let Passport_FieldOneOf_Delimeter: String
    private let _Channel_AdminLog_MessageChangedGroupStickerPack: String
    private let _Channel_AdminLog_MessageChangedGroupStickerPack_r: [(Int, NSRange)]
    public func Channel_AdminLog_MessageChangedGroupStickerPack(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Channel_AdminLog_MessageChangedGroupStickerPack, self._Channel_AdminLog_MessageChangedGroupStickerPack_r, [_0])
    }
    public let DialogList_Unpin: String
    public let GroupInfo_SetGroupPhoto: String
    public let StickerPacksSettings_ArchivedPacks_Info: String
    public let ConvertToSupergroup_Title: String
    private let _CHAT_MESSAGE_NOTEXT: String
    private let _CHAT_MESSAGE_NOTEXT_r: [(Int, NSRange)]
    public func CHAT_MESSAGE_NOTEXT(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_CHAT_MESSAGE_NOTEXT, self._CHAT_MESSAGE_NOTEXT_r, [_1, _2])
    }
    public let Notification_CallCanceledShort: String
    public let Channel_Setup_TypeHeader: String
    private let _Notification_NewAuthDetected: String
    private let _Notification_NewAuthDetected_r: [(Int, NSRange)]
    public func Notification_NewAuthDetected(_ _1: String, _ _2: String, _ _3: String, _ _4: String, _ _5: String, _ _6: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Notification_NewAuthDetected, self._Notification_NewAuthDetected_r, [_1, _2, _3, _4, _5, _6])
    }
    private let _Channel_AdminLog_MessageRemovedGroupStickerPack: String
    private let _Channel_AdminLog_MessageRemovedGroupStickerPack_r: [(Int, NSRange)]
    public func Channel_AdminLog_MessageRemovedGroupStickerPack(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Channel_AdminLog_MessageRemovedGroupStickerPack, self._Channel_AdminLog_MessageRemovedGroupStickerPack_r, [_0])
    }
    public let PrivacyPolicy_DeclineTitle: String
    public let AuthSessions_PasswordPending: String
    public let AccessDenied_VideoMessageCamera: String
    public let Privacy_ContactsSyncHelp: String
    public let Conversation_Search: String
    private let _Channel_Management_PromotedBy: String
    private let _Channel_Management_PromotedBy_r: [(Int, NSRange)]
    public func Channel_Management_PromotedBy(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Channel_Management_PromotedBy, self._Channel_Management_PromotedBy_r, [_0])
    }
    private let _PrivacySettings_LastSeenNobodyPlus: String
    private let _PrivacySettings_LastSeenNobodyPlus_r: [(Int, NSRange)]
    public func PrivacySettings_LastSeenNobodyPlus(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_PrivacySettings_LastSeenNobodyPlus, self._PrivacySettings_LastSeenNobodyPlus_r, [_0])
    }
    private let _Time_MonthOfYear_m4: String
    private let _Time_MonthOfYear_m4_r: [(Int, NSRange)]
    public func Time_MonthOfYear_m4(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Time_MonthOfYear_m4, self._Time_MonthOfYear_m4_r, [_0])
    }
    public let SecretImage_Title: String
    public let Notifications_InAppNotificationsSounds: String
    public let Call_StatusRequesting: String
    private let _Channel_AdminLog_MessageRestrictedUntil: String
    private let _Channel_AdminLog_MessageRestrictedUntil_r: [(Int, NSRange)]
    public func Channel_AdminLog_MessageRestrictedUntil(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Channel_AdminLog_MessageRestrictedUntil, self._Channel_AdminLog_MessageRestrictedUntil_r, [_0])
    }
    private let _CHAT_MESSAGE_CONTACT: String
    private let _CHAT_MESSAGE_CONTACT_r: [(Int, NSRange)]
    public func CHAT_MESSAGE_CONTACT(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_CHAT_MESSAGE_CONTACT, self._CHAT_MESSAGE_CONTACT_r, [_1, _2])
    }
    public let SocksProxySetup_UseProxy: String
    public let Group_UpgradeNoticeText1: String
    public let ChatSettings_Other: String
    private let _Channel_AdminLog_MessageChangedChannelAbout: String
    private let _Channel_AdminLog_MessageChangedChannelAbout_r: [(Int, NSRange)]
    public func Channel_AdminLog_MessageChangedChannelAbout(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Channel_AdminLog_MessageChangedChannelAbout, self._Channel_AdminLog_MessageChangedChannelAbout_r, [_0])
    }
    public let Channel_Stickers_CreateYourOwn: String
    private let _Call_EmojiDescription: String
    private let _Call_EmojiDescription_r: [(Int, NSRange)]
    public func Call_EmojiDescription(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Call_EmojiDescription, self._Call_EmojiDescription_r, [_0])
    }
    public let Settings_SaveIncomingPhotos: String
    private let _Conversation_Bytes: String
    private let _Conversation_Bytes_r: [(Int, NSRange)]
    public func Conversation_Bytes(_ _0: Int) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Conversation_Bytes, self._Conversation_Bytes_r, ["\(_0)"])
    }
    public let GroupInfo_InviteLink_Help: String
    public let Calls_Missed: String
    public let Conversation_ContextMenuForward: String
    public let AutoDownloadSettings_ResetHelp: String
    public let Passport_Identity_NativeNameHelp: String
    public let Call_StatusRinging: String
    public let Passport_Language_pl: String
    public let Invitation_JoinGroup: String
    public let Notification_PinnedMessage: String
    public let AutoDownloadSettings_WiFi: String
    public let Conversation_ClearSelfHistory: String
    public let Message_Location: String
    private let _Notification_MessageLifetimeChanged: String
    private let _Notification_MessageLifetimeChanged_r: [(Int, NSRange)]
    public func Notification_MessageLifetimeChanged(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Notification_MessageLifetimeChanged, self._Notification_MessageLifetimeChanged_r, [_1, _2])
    }
    public let Message_Contact: String
    public let Passport_Language_lo: String
    public let UserInfo_BotPrivacy: String
    public let PasscodeSettings_AutoLock_IfAwayFor_1minute: String
    public let Common_More: String
    public let Preview_OpenInInstagram: String
    public let PhotoEditor_HighlightsTool: String
    private let _Channel_Username_UsernameIsAvailable: String
    private let _Channel_Username_UsernameIsAvailable_r: [(Int, NSRange)]
    public func Channel_Username_UsernameIsAvailable(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Channel_Username_UsernameIsAvailable, self._Channel_Username_UsernameIsAvailable_r, [_0])
    }
    private let _PINNED_GAME: String
    private let _PINNED_GAME_r: [(Int, NSRange)]
    public func PINNED_GAME(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_PINNED_GAME, self._PINNED_GAME_r, [_1])
    }
    public let Invite_LargeRecipientsCountWarning: String
    public let Passport_Language_hr: String
    public let GroupInfo_BroadcastListNamePlaceholder: String
    public let Activity_UploadingVideoMessage: String
    public let Conversation_ShareBotContactConfirmation: String
    public let Login_CodeSentSms: String
    private let _CHANNEL_MESSAGES: String
    private let _CHANNEL_MESSAGES_r: [(Int, NSRange)]
    public func CHANNEL_MESSAGES(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_CHANNEL_MESSAGES, self._CHANNEL_MESSAGES_r, [_1, _2])
    }
    public let Conversation_ReportSpamConfirmation: String
    public let ChannelMembers_ChannelAdminsTitle: String
    public let SocksProxySetup_Credentials: String
    public let CallSettings_UseLessData: String
    public let MediaPicker_GroupDescription: String
    private let _TwoStepAuth_EnterPasswordHint: String
    private let _TwoStepAuth_EnterPasswordHint_r: [(Int, NSRange)]
    public func TwoStepAuth_EnterPasswordHint(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_TwoStepAuth_EnterPasswordHint, self._TwoStepAuth_EnterPasswordHint_r, [_0])
    }
    public let CallSettings_TabIcon: String
    public let ConversationProfile_UnknownAddMemberError: String
    private let _Conversation_FileHowToText: String
    private let _Conversation_FileHowToText_r: [(Int, NSRange)]
    public func Conversation_FileHowToText(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Conversation_FileHowToText, self._Conversation_FileHowToText_r, [_0])
    }
    public let Channel_AdminLog_BanSendMedia: String
    public let Passport_Language_uz: String
    public let Watch_UserInfo_Unblock: String
    public let ChatSettings_AutoDownloadVideoMessages: String
    public let PrivacyPolicy_AgeVerificationTitle: String
    public let StickerPacksSettings_ArchivedMasks: String
    public let Message_Animation: String
    public let Checkout_PaymentMethod: String
    public let Channel_AdminLog_TitleSelectedEvents: String
    public let PrivacyPolicy_DeclineDeleteNow: String
    public let Privacy_Calls_NeverAllow_Title: String
    public let Cache_Music: String
    public let Settings_ProxyDisabled: String
    public let SocksProxySetup_Connecting: String
    public let Channel_Username_CreatePrivateLinkHelp: String
    private let _Time_PreciseDate_m2: String
    private let _Time_PreciseDate_m2_r: [(Int, NSRange)]
    public func Time_PreciseDate_m2(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Time_PreciseDate_m2, self._Time_PreciseDate_m2_r, [_1, _2, _3])
    }
    private let _FileSize_B: String
    private let _FileSize_B_r: [(Int, NSRange)]
    public func FileSize_B(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_FileSize_B, self._FileSize_B_r, [_0])
    }
    private let _Target_ShareGameConfirmationGroup: String
    private let _Target_ShareGameConfirmationGroup_r: [(Int, NSRange)]
    public func Target_ShareGameConfirmationGroup(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Target_ShareGameConfirmationGroup, self._Target_ShareGameConfirmationGroup_r, [_0])
    }
    public let PhotoEditor_SaturationTool: String
    public let Channel_BanUser_BlockFor: String
    public let Call_StatusConnecting: String
    public let AutoNightTheme_NotAvailable: String
    public let PrivateDataSettings_Title: String
    public let Bot_Start: String
    private let _Channel_AdminLog_MessageChangedGroupAbout: String
    private let _Channel_AdminLog_MessageChangedGroupAbout_r: [(Int, NSRange)]
    public func Channel_AdminLog_MessageChangedGroupAbout(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Channel_AdminLog_MessageChangedGroupAbout, self._Channel_AdminLog_MessageChangedGroupAbout_r, [_0])
    }
    public let Appearance_PreviewReplyAuthor: String
    public let Notifications_TextTone: String
    public let Settings_CallSettings: String
    private let _Watch_Time_ShortYesterdayAt: String
    private let _Watch_Time_ShortYesterdayAt_r: [(Int, NSRange)]
    public func Watch_Time_ShortYesterdayAt(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Watch_Time_ShortYesterdayAt, self._Watch_Time_ShortYesterdayAt_r, [_0])
    }
    public let Contacts_InviteToTelegram: String
    private let _PINNED_DOC: String
    private let _PINNED_DOC_r: [(Int, NSRange)]
    public func PINNED_DOC(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_PINNED_DOC, self._PINNED_DOC_r, [_1])
    }
    public let ChatSettings_PrivateChats: String
    public let DialogList_Draft: String
    public let Channel_EditAdmin_PermissionDeleteMessages: String
    public let Channel_BanUser_PermissionSendStickersAndGifs: String
    public let Conversation_CloudStorageInfo_Title: String
    public let Conversation_ClearSecretHistory: String
    public let Passport_Identity_EditIdentityCard: String
    public let Notification_RenamedChannel: String
    public let BlockedUsers_BlockUser: String
    public let ChatSettings_TextSize: String
    public let ChannelInfo_DeleteGroup: String
    public let PhoneNumberHelp_Alert: String
    private let _PINNED_TEXT: String
    private let _PINNED_TEXT_r: [(Int, NSRange)]
    public func PINNED_TEXT(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_PINNED_TEXT, self._PINNED_TEXT_r, [_1, _2])
    }
    public let Watch_ChannelInfo_Title: String
    public let WebSearch_RecentSectionClear: String
    public let Channel_AdminLogFilter_AdminsAll: String
    public let Channel_Setup_TypePrivate: String
    public let PhotoEditor_TintTool: String
    public let Watch_Suggestion_CantTalk: String
    public let PhotoEditor_QualityHigh: String
    public let SocksProxySetup_AddProxyTitle: String
    private let _CHAT_MESSAGE_STICKER: String
    private let _CHAT_MESSAGE_STICKER_r: [(Int, NSRange)]
    public func CHAT_MESSAGE_STICKER(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_CHAT_MESSAGE_STICKER, self._CHAT_MESSAGE_STICKER_r, [_1, _2, _3])
    }
    public let Map_ChooseAPlace: String
    public let Passport_Identity_NamePlaceholder: String
    public let Passport_ScanPassport: String
    public let Map_ShareLiveLocationHelp: String
    public let Watch_Bot_Restart: String
    public let Passport_RequestedInformation: String
    public let Channel_About_Help: String
    public let Web_OpenExternal: String
    public let Passport_Language_mn: String
    public let UserInfo_AddContact: String
    public let Privacy_ContactsSync: String
    public let SocksProxySetup_Connection: String
    public let Passport_NotLoggedInMessage: String
    public let Passport_PasswordPlaceholder: String
    public let Passport_PasswordCreate: String
    public let SocksProxySetup_ProxyStatusChecking: String
    public let Call_EncryptionKey_Title: String
    public let PhotoEditor_BlurToolLinear: String
    public let AuthSessions_EmptyText: String
    public let Notification_MessageLifetime1m: String
    private let _Call_StatusBar: String
    private let _Call_StatusBar_r: [(Int, NSRange)]
    public func Call_StatusBar(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Call_StatusBar, self._Call_StatusBar_r, [_0])
    }
    public let EditProfile_NameAndPhotoHelp: String
    public let NotificationsSound_Tritone: String
    public let Passport_FieldAddressUploadHelp: String
    public let Month_ShortJuly: String
    public let CheckoutInfo_ShippingInfoAddress1Placeholder: String
    public let Watch_MessageView_ViewOnPhone: String
    public let CallSettings_Never: String
    public let Passport_Identity_TypeInternalPassportUploadScan: String
    public let TwoStepAuth_EmailSent: String
    private let _Notification_PinnedAnimationMessage: String
    private let _Notification_PinnedAnimationMessage_r: [(Int, NSRange)]
    public func Notification_PinnedAnimationMessage(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Notification_PinnedAnimationMessage, self._Notification_PinnedAnimationMessage_r, [_0])
    }
    public let TwoStepAuth_RecoveryTitle: String
    public let Notifications_MessageNotificationsExceptions: String
    public let WatchRemote_AlertOpen: String
    public let ExplicitContent_AlertChannel: String
    public let Notification_PassportValueEmail: String
    public let ContactInfo_PhoneLabelMobile: String
    public let Widget_AuthRequired: String
    private let _ForwardedAuthors2: String
    private let _ForwardedAuthors2_r: [(Int, NSRange)]
    public func ForwardedAuthors2(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_ForwardedAuthors2, self._ForwardedAuthors2_r, [_0, _1])
    }
    public let ChannelInfo_DeleteGroupConfirmation: String
    public let TwoStepAuth_ConfirmationText: String
    public let Login_SmsRequestState3: String
    public let Notifications_AlertTones: String
    private let _Time_MonthOfYear_m10: String
    private let _Time_MonthOfYear_m10_r: [(Int, NSRange)]
    public func Time_MonthOfYear_m10(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Time_MonthOfYear_m10, self._Time_MonthOfYear_m10_r, [_0])
    }
    public let Login_InfoAvatarPhoto: String
    public let Calls_TabTitle: String
    public let Map_YouAreHere: String
    public let PhotoEditor_CurvesTool: String
    public let Map_LiveLocationFor1Hour: String
    public let AutoNightTheme_AutomaticSection: String
    public let Stickers_NoStickersFound: String
    public let Passport_Identity_AddIdentityCard: String
    private let _Notification_JoinedChannel: String
    private let _Notification_JoinedChannel_r: [(Int, NSRange)]
    public func Notification_JoinedChannel(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Notification_JoinedChannel, self._Notification_JoinedChannel_r, [_0])
    }
    public let Passport_Language_et: String
    public let Passport_Language_en: String
    public let GroupInfo_ActionRestrict: String
    public let Checkout_ShippingOption_Title: String
    public let Stickers_SuggestStickers: String
    private let _Channel_AdminLog_MessageKickedName: String
    private let _Channel_AdminLog_MessageKickedName_r: [(Int, NSRange)]
    public func Channel_AdminLog_MessageKickedName(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Channel_AdminLog_MessageKickedName, self._Channel_AdminLog_MessageKickedName_r, [_1])
    }
    public let Conversation_EncryptionProcessing: String
    public let TwoStepAuth_EmailCodeExpired: String
    private let _CHAT_ADD_MEMBER: String
    private let _CHAT_ADD_MEMBER_r: [(Int, NSRange)]
    public func CHAT_ADD_MEMBER(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_CHAT_ADD_MEMBER, self._CHAT_ADD_MEMBER_r, [_1, _2, _3])
    }
    public let Weekday_ShortSunday: String
    public let Privacy_ContactsResetConfirmation: String
    public let Month_ShortJune: String
    public let Privacy_Calls_Integration: String
    public let Channel_TypeSetup_Title: String
    public let Month_GenApril: String
    public let StickerPacksSettings_ShowStickersButton: String
    public let CheckoutInfo_ShippingInfoTitle: String
    public let Notification_PassportValueProofOfAddress: String
    public let Weekday_Tuesday: String
    public let StickerPacksSettings_ShowStickersButtonHelp: String
    private let _Compatibility_SecretMediaVersionTooLow: String
    private let _Compatibility_SecretMediaVersionTooLow_r: [(Int, NSRange)]
    public func Compatibility_SecretMediaVersionTooLow(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Compatibility_SecretMediaVersionTooLow, self._Compatibility_SecretMediaVersionTooLow_r, [_0, _1])
    }
    public let CallSettings_RecentCalls: String
    private let _Conversation_Megabytes: String
    private let _Conversation_Megabytes_r: [(Int, NSRange)]
    public func Conversation_Megabytes(_ _0: Float) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Conversation_Megabytes, self._Conversation_Megabytes_r, ["\(_0)"])
    }
    public let Conversation_SearchByName_Prefix: String
    public let TwoStepAuth_FloodError: String
    public let Paint_Stickers: String
    public let Login_InvalidCountryCode: String
    public let Privacy_Calls_AlwaysAllow_Title: String
    public let Username_InvalidTooShort: String
    private let _Settings_ApplyProxyAlert: String
    private let _Settings_ApplyProxyAlert_r: [(Int, NSRange)]
    public func Settings_ApplyProxyAlert(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Settings_ApplyProxyAlert, self._Settings_ApplyProxyAlert_r, [_1, _2])
    }
    public let Weekday_ShortFriday: String
    private let _Login_BannedPhoneBody: String
    private let _Login_BannedPhoneBody_r: [(Int, NSRange)]
    public func Login_BannedPhoneBody(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Login_BannedPhoneBody, self._Login_BannedPhoneBody_r, [_0])
    }
    public let Conversation_ClearAll: String
    public let Conversation_EditingMessageMediaChange: String
    public let Passport_FieldIdentityTranslationHelp: String
    public let Call_ReportIncludeLog: String
    private let _Time_MonthOfYear_m3: String
    private let _Time_MonthOfYear_m3_r: [(Int, NSRange)]
    public func Time_MonthOfYear_m3(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Time_MonthOfYear_m3, self._Time_MonthOfYear_m3_r, [_0])
    }
    public let SharedMedia_EmptyTitle: String
    public let Call_PhoneCallInProgressMessage: String
    public let Notification_GroupActivated: String
    public let Checkout_Name: String
    public let Passport_Address_PostcodePlaceholder: String
    private let _AUTH_REGION: String
    private let _AUTH_REGION_r: [(Int, NSRange)]
    public func AUTH_REGION(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_AUTH_REGION, self._AUTH_REGION_r, [_1, _2])
    }
    public let Settings_NotificationsAndSounds: String
    public let Conversation_EncryptionCanceled: String
    private let _GroupInfo_InvitationLinkAcceptChannel: String
    private let _GroupInfo_InvitationLinkAcceptChannel_r: [(Int, NSRange)]
    public func GroupInfo_InvitationLinkAcceptChannel(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_GroupInfo_InvitationLinkAcceptChannel, self._GroupInfo_InvitationLinkAcceptChannel_r, [_0])
    }
    public let AccessDenied_SaveMedia: String
    public let InviteText_URL: String
    public let Passport_CorrectErrors: String
    private let _Channel_AdminLog_MessageInvitedNameUsername: String
    private let _Channel_AdminLog_MessageInvitedNameUsername_r: [(Int, NSRange)]
    public func Channel_AdminLog_MessageInvitedNameUsername(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Channel_AdminLog_MessageInvitedNameUsername, self._Channel_AdminLog_MessageInvitedNameUsername_r, [_1, _2])
    }
    public let Notifications_Badge_CountUnreadMessages: String
    public let Appearance_ReduceMotion: String
    public let Compose_GroupTokenListPlaceholder: String
    public let Passport_Address_CityPlaceholder: String
    public let Passport_InfoFAQ_URL: String
    public let Conversation_MessageDeliveryFailed: String
    public let Privacy_PaymentsClear_PaymentInfo: String
    public let Notifications_GroupNotifications: String
    public let CheckoutInfo_SaveInfoHelp: String
    public let Notification_Mute1hMin: String
    public let Privacy_TopPeersWarning: String
    public let StickerPacksSettings_ArchivedMasks_Info: String
    public let ChannelMembers_WhoCanAddMembers_AllMembers: String
    public let Channel_Edit_PrivatePublicLinkAlert: String
    public let Watch_Conversation_UserInfo: String
    public let Application_Name: String
    public let Conversation_AddToReadingList: String
    public let Conversation_FileDropbox: String
    public let Login_PhonePlaceholder: String
    public let SocksProxySetup_ProxyEnabled: String
    public let Profile_MessageLifetime1d: String
    public let CheckoutInfo_ShippingInfoCityPlaceholder: String
    public let Notifications_ChannelNotificationsSound: String
    public let Calls_CallTabDescription: String
    public let Passport_DeletePersonalDetails: String
    public let Passport_Address_AddBankStatement: String
    public let Resolve_ErrorNotFound: String
    public let Watch_Message_Call: String
    public let PhotoEditor_FadeTool: String
    public let Channel_Setup_TypePublicHelp: String
    public let GroupInfo_InviteLink_RevokeAlert_Success: String
    public let Channel_Setup_PublicNoLink: String
    public let Privacy_Calls_P2PHelp: String
    public let Conversation_Info: String
    private let _Time_TodayAt: String
    private let _Time_TodayAt_r: [(Int, NSRange)]
    public func Time_TodayAt(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Time_TodayAt, self._Time_TodayAt_r, [_0])
    }
    public let AutoDownloadSettings_VideosTitle: String
    public let Conversation_Processing: String
    public let Conversation_RestrictedInline: String
    private let _InstantPage_AuthorAndDateTitle: String
    private let _InstantPage_AuthorAndDateTitle_r: [(Int, NSRange)]
    public func InstantPage_AuthorAndDateTitle(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_InstantPage_AuthorAndDateTitle, self._InstantPage_AuthorAndDateTitle_r, [_1, _2])
    }
    private let _Watch_LastSeen_AtDate: String
    private let _Watch_LastSeen_AtDate_r: [(Int, NSRange)]
    public func Watch_LastSeen_AtDate(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Watch_LastSeen_AtDate, self._Watch_LastSeen_AtDate_r, [_0])
    }
    public let Conversation_Location: String
    public let DialogList_PasscodeLockHelp: String
    public let Channel_Management_Title: String
    public let Notifications_InAppNotificationsPreview: String
    public let EnterPasscode_EnterTitle: String
    public let ReportPeer_ReasonOther_Title: String
    public let Month_GenJanuary: String
    public let Conversation_ForwardChats: String
    public let Channel_UpdatePhotoItem: String
    public let UserInfo_StartSecretChat: String
    public let PrivacySettings_LastSeenNobody: String
    private let _FileSize_MB: String
    private let _FileSize_MB_r: [(Int, NSRange)]
    public func FileSize_MB(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_FileSize_MB, self._FileSize_MB_r, [_0])
    }
    public let ChatSearch_SearchPlaceholder: String
    public let TwoStepAuth_ConfirmationAbort: String
    public let FastTwoStepSetup_HintSection: String
    public let TwoStepAuth_SetupPasswordConfirmFailed: String
    private let _LastSeen_YesterdayAt: String
    private let _LastSeen_YesterdayAt_r: [(Int, NSRange)]
    public func LastSeen_YesterdayAt(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_LastSeen_YesterdayAt, self._LastSeen_YesterdayAt_r, [_0])
    }
    public let GroupInfo_GroupHistoryVisible: String
    public let AppleWatch_ReplyPresetsHelp: String
    public let Localization_LanguageName: String
    public let Map_OpenIn: String
    public let Message_File: String
    public let Call_ReportSend: String
    private let _Channel_AdminLog_MessageChangedGroupUsername: String
    private let _Channel_AdminLog_MessageChangedGroupUsername_r: [(Int, NSRange)]
    public func Channel_AdminLog_MessageChangedGroupUsername(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Channel_AdminLog_MessageChangedGroupUsername, self._Channel_AdminLog_MessageChangedGroupUsername_r, [_0])
    }
    private let _CHAT_MESSAGE_GAME: String
    private let _CHAT_MESSAGE_GAME_r: [(Int, NSRange)]
    public func CHAT_MESSAGE_GAME(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_CHAT_MESSAGE_GAME, self._CHAT_MESSAGE_GAME_r, [_1, _2, _3])
    }
    private let _Time_PreciseDate_m1: String
    private let _Time_PreciseDate_m1_r: [(Int, NSRange)]
    public func Time_PreciseDate_m1(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Time_PreciseDate_m1, self._Time_PreciseDate_m1_r, [_1, _2, _3])
    }
    public let Month_ShortMay: String
    public let Tour_Text3: String
    public let Contacts_GlobalSearch: String
    public let DialogList_LanguageTooltip: String
    public let AuthSessions_LogOutApplications: String
    public let Map_LoadError: String
    public let Settings_ProxyConnecting: String
    public let Passport_Language_fa: String
    public let AccessDenied_VoiceMicrophone: String
    private let _CHANNEL_MESSAGE_STICKER: String
    private let _CHANNEL_MESSAGE_STICKER_r: [(Int, NSRange)]
    public func CHANNEL_MESSAGE_STICKER(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_CHANNEL_MESSAGE_STICKER, self._CHANNEL_MESSAGE_STICKER_r, [_1, _2])
    }
    public let Passport_Address_TypeUtilityBillUploadScan: String
    public let PrivacySettings_Title: String
    public let PasscodeSettings_TurnPasscodeOff: String
    public let MediaPicker_AddCaption: String
    public let Channel_AdminLog_BanReadMessages: String
    public let Channel_Status: String
    public let Map_ChooseLocationTitle: String
    public let Notifications_ChannelNotifications: String
    public let Map_OpenInYandexNavigator: String
    public let AutoNightTheme_PreferredTheme: String
    public let State_WaitingForNetwork: String
    public let TwoStepAuth_EmailHelp: String
    public let Conversation_StopLiveLocation: String
    public let Privacy_SecretChatsLinkPreviewsHelp: String
    public let PhotoEditor_SharpenTool: String
    public let Common_of: String
    public let AuthSessions_Title: String
    public let Passport_Scans_UploadNew: String
    public let Message_PinnedLiveLocationMessage: String
    public let Passport_FieldIdentityDetailsHelp: String
    public let PrivacyLastSeenSettings_AlwaysShareWith: String
    public let EnterPasscode_EnterPasscode: String
    public let Notifications_Reset: String
    private let _Map_LiveLocationPrivateDescription: String
    private let _Map_LiveLocationPrivateDescription_r: [(Int, NSRange)]
    public func Map_LiveLocationPrivateDescription(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Map_LiveLocationPrivateDescription, self._Map_LiveLocationPrivateDescription_r, [_0])
    }
    public let GroupInfo_InvitationLinkGroupFull: String
    private let _Channel_AdminLog_MessageChangedChannelUsername: String
    private let _Channel_AdminLog_MessageChangedChannelUsername_r: [(Int, NSRange)]
    public func Channel_AdminLog_MessageChangedChannelUsername(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Channel_AdminLog_MessageChangedChannelUsername, self._Channel_AdminLog_MessageChangedChannelUsername_r, [_0])
    }
    private let _CHAT_MESSAGE_DOC: String
    private let _CHAT_MESSAGE_DOC_r: [(Int, NSRange)]
    public func CHAT_MESSAGE_DOC(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_CHAT_MESSAGE_DOC, self._CHAT_MESSAGE_DOC_r, [_1, _2])
    }
    public let Watch_AppName: String
    public let ConvertToSupergroup_HelpTitle: String
    public let Conversation_TapAndHoldToRecord: String
    private let _MESSAGE_GIF: String
    private let _MESSAGE_GIF_r: [(Int, NSRange)]
    public func MESSAGE_GIF(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_MESSAGE_GIF, self._MESSAGE_GIF_r, [_1])
    }
    private let _DialogList_EncryptedChatStartedOutgoing: String
    private let _DialogList_EncryptedChatStartedOutgoing_r: [(Int, NSRange)]
    public func DialogList_EncryptedChatStartedOutgoing(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_DialogList_EncryptedChatStartedOutgoing, self._DialogList_EncryptedChatStartedOutgoing_r, [_0])
    }
    public let Checkout_PayWithTouchId: String
    public let Passport_Language_ko: String
    public let Conversation_DiscardVoiceMessageTitle: String
    private let _CHAT_ADD_YOU: String
    private let _CHAT_ADD_YOU_r: [(Int, NSRange)]
    public func CHAT_ADD_YOU(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_CHAT_ADD_YOU, self._CHAT_ADD_YOU_r, [_1, _2])
    }
    public let CheckoutInfo_ShippingInfoCity: String
    public let Group_AdminLog_EmptyText: String
    public let AutoDownloadSettings_GroupChats: String
    public let Conversation_ClousStorageInfo_Description3: String
    public let Notifications_ExceptionsMuted: String
    public let Conversation_PinMessageAlertGroup: String
    public let Settings_FAQ_Intro: String
    public let PrivacySettings_AuthSessions: String
    private let _CHAT_MESSAGE_GEOLIVE: String
    private let _CHAT_MESSAGE_GEOLIVE_r: [(Int, NSRange)]
    public func CHAT_MESSAGE_GEOLIVE(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_CHAT_MESSAGE_GEOLIVE, self._CHAT_MESSAGE_GEOLIVE_r, [_1, _2])
    }
    public let Passport_Address_Postcode: String
    public let Tour_Title5: String
    public let ChatAdmins_AllMembersAreAdmins: String
    public let Group_Management_AddModeratorHelp: String
    public let Channel_Username_CheckingUsername: String
    private let _DialogList_SingleRecordingVideoMessageSuffix: String
    private let _DialogList_SingleRecordingVideoMessageSuffix_r: [(Int, NSRange)]
    public func DialogList_SingleRecordingVideoMessageSuffix(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_DialogList_SingleRecordingVideoMessageSuffix, self._DialogList_SingleRecordingVideoMessageSuffix_r, [_0])
    }
    private let _Contacts_AccessDeniedHelpPortrait: String
    private let _Contacts_AccessDeniedHelpPortrait_r: [(Int, NSRange)]
    public func Contacts_AccessDeniedHelpPortrait(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Contacts_AccessDeniedHelpPortrait, self._Contacts_AccessDeniedHelpPortrait_r, [_0])
    }
    private let _Checkout_LiabilityAlert: String
    private let _Checkout_LiabilityAlert_r: [(Int, NSRange)]
    public func Checkout_LiabilityAlert(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Checkout_LiabilityAlert, self._Checkout_LiabilityAlert_r, [_1, _1, _1, _2])
    }
    public let Channel_Info_BlackList: String
    public let Profile_BotInfo: String
    public let Stickers_SuggestAll: String
    public let Compose_NewChannel_Members: String
    public let Notification_Reply: String
    public let Watch_Stickers_Recents: String
    public let GroupInfo_SetGroupPhotoStop: String
    public let Channel_Stickers_Placeholder: String
    public let AttachmentMenu_File: String
    private let _MESSAGE_STICKER: String
    private let _MESSAGE_STICKER_r: [(Int, NSRange)]
    public func MESSAGE_STICKER(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_MESSAGE_STICKER, self._MESSAGE_STICKER_r, [_1, _2])
    }
    public let Profile_MessageLifetime5s: String
    public let Privacy_ContactsReset: String
    private let _PINNED_PHOTO: String
    private let _PINNED_PHOTO_r: [(Int, NSRange)]
    public func PINNED_PHOTO(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_PINNED_PHOTO, self._PINNED_PHOTO_r, [_1])
    }
    public let Channel_AdminLog_CanAddAdmins: String
    public let TwoStepAuth_SetupHint: String
    public let Conversation_StatusLeftGroup: String
    public let Settings_CopyUsername: String
    public let Passport_Identity_CountryPlaceholder: String
    public let ChatSettings_AutoDownloadDocuments: String
    public let MediaPicker_TapToUngroupDescription: String
    public let Conversation_ShareBotLocationConfirmation: String
    public let Conversation_DeleteMessagesForMe: String
    public let Notification_PassportValuePersonalDetails: String
    public let Message_PinnedAnimationMessage: String
    public let Passport_FieldIdentityUploadHelp: String
    public let SocksProxySetup_ConnectAndSave: String
    public let SocksProxySetup_FailedToConnect: String
    public let Checkout_ErrorPrecheckoutFailed: String
    public let Camera_PhotoMode: String
    private let _Time_MonthOfYear_m2: String
    private let _Time_MonthOfYear_m2_r: [(Int, NSRange)]
    public func Time_MonthOfYear_m2(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Time_MonthOfYear_m2, self._Time_MonthOfYear_m2_r, [_0])
    }
    public let Channel_About_Placeholder: String
    public let Map_Directions: String
    public let Channel_About_Title: String
    private let _MESSAGE_PHOTO: String
    private let _MESSAGE_PHOTO_r: [(Int, NSRange)]
    public func MESSAGE_PHOTO(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_MESSAGE_PHOTO, self._MESSAGE_PHOTO_r, [_1])
    }
    public let Calls_RatingTitle: String
    public let SharedMedia_EmptyText: String
    public let Channel_Stickers_Searching: String
    public let Passport_Address_AddUtilityBill: String
    public let Login_PadPhoneHelp: String
    public let StickerPacksSettings_ArchivedPacks: String
    public let Passport_Language_th: String
    public let Channel_ErrorAccessDenied: String
    public let Generic_ErrorMoreInfo: String
    public let Channel_AdminLog_TitleAllEvents: String
    public let Settings_Proxy: String
    public let Passport_Language_lt: String
    public let ChannelMembers_WhoCanAddMembersAllHelp: String
    public let Passport_Address_CountryPlaceholder: String
    public let ChangePhoneNumberCode_CodePlaceholder: String
    public let Camera_SquareMode: String
    private let _Conversation_EncryptedPlaceholderTitleOutgoing: String
    private let _Conversation_EncryptedPlaceholderTitleOutgoing_r: [(Int, NSRange)]
    public func Conversation_EncryptedPlaceholderTitleOutgoing(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Conversation_EncryptedPlaceholderTitleOutgoing, self._Conversation_EncryptedPlaceholderTitleOutgoing_r, [_0])
    }
    public let NetworkUsageSettings_CallDataSection: String
    public let Login_PadPhoneHelpTitle: String
    public let Profile_CreateNewContact: String
    public let AccessDenied_VideoMessageMicrophone: String
    public let AutoDownloadSettings_VoiceMessagesTitle: String
    public let PhotoEditor_VignetteTool: String
    public let LastSeen_WithinAWeek: String
    public let Widget_NoUsers: String
    public let Passport_Identity_DocumentNumber: String
    public let Application_Update: String
    public let Calls_NewCall: String
    private let _CHANNEL_MESSAGE_AUDIO: String
    private let _CHANNEL_MESSAGE_AUDIO_r: [(Int, NSRange)]
    public func CHANNEL_MESSAGE_AUDIO(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_CHANNEL_MESSAGE_AUDIO, self._CHANNEL_MESSAGE_AUDIO_r, [_1])
    }
    public let DialogList_NoMessagesText: String
    public let MaskStickerSettings_Info: String
    public let ChatSettings_AutoDownloadTitle: String
    public let Passport_FieldAddressHelp: String
    public let Passport_Language_dz: String
    public let Conversation_FilePhotoOrVideo: String
    public let Channel_AdminLog_BanSendStickers: String
    public let Common_Next: String
    public let Stickers_RemoveFromFavorites: String
    public let Watch_Notification_Joined: String
    private let _Channel_AdminLog_MessageRestrictedNewSetting: String
    private let _Channel_AdminLog_MessageRestrictedNewSetting_r: [(Int, NSRange)]
    public func Channel_AdminLog_MessageRestrictedNewSetting(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Channel_AdminLog_MessageRestrictedNewSetting, self._Channel_AdminLog_MessageRestrictedNewSetting_r, [_0])
    }
    public let Passport_DeleteAddress: String
    public let ContactInfo_PhoneLabelHome: String
    public let GroupInfo_DeleteAndExitConfirmation: String
    public let NotificationsSound_Tremolo: String
    public let TwoStepAuth_EmailInvalid: String
    public let Privacy_ContactsTitle: String
    public let Passport_Address_TypeBankStatement: String
    private let _CHAT_MESSAGE_VIDEO: String
    private let _CHAT_MESSAGE_VIDEO_r: [(Int, NSRange)]
    public func CHAT_MESSAGE_VIDEO(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_CHAT_MESSAGE_VIDEO, self._CHAT_MESSAGE_VIDEO_r, [_1, _2])
    }
    public let Month_GenJune: String
    public let Map_LiveLocationFor15Minutes: String
    private let _Login_EmailCodeSubject: String
    private let _Login_EmailCodeSubject_r: [(Int, NSRange)]
    public func Login_EmailCodeSubject(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Login_EmailCodeSubject, self._Login_EmailCodeSubject_r, [_0])
    }
    private let _CHAT_TITLE_EDITED: String
    private let _CHAT_TITLE_EDITED_r: [(Int, NSRange)]
    public func CHAT_TITLE_EDITED(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_CHAT_TITLE_EDITED, self._CHAT_TITLE_EDITED_r, [_1, _2])
    }
    public let ContactInfo_PhoneLabelHomeFax: String
    private let _NetworkUsageSettings_WifiUsageSince: String
    private let _NetworkUsageSettings_WifiUsageSince_r: [(Int, NSRange)]
    public func NetworkUsageSettings_WifiUsageSince(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_NetworkUsageSettings_WifiUsageSince, self._NetworkUsageSettings_WifiUsageSince_r, [_0])
    }
    public let Watch_LastSeen_Lately: String
    public let Watch_Compose_CurrentLocation: String
    public let DialogList_RecentTitlePeople: String
    public let GroupInfo_Notifications: String
    public let Call_ReportPlaceholder: String
    private let _AuthSessions_Message: String
    private let _AuthSessions_Message_r: [(Int, NSRange)]
    public func AuthSessions_Message(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_AuthSessions_Message, self._AuthSessions_Message_r, [_0])
    }
    private let _MESSAGE_DOC: String
    private let _MESSAGE_DOC_r: [(Int, NSRange)]
    public func MESSAGE_DOC(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_MESSAGE_DOC, self._MESSAGE_DOC_r, [_1])
    }
    public let Group_Username_CreatePrivateLinkHelp: String
    public let Notifications_GroupNotificationsSound: String
    public let AuthSessions_EmptyTitle: String
    public let Privacy_GroupsAndChannels_AlwaysAllow_Title: String
    public let Passport_Language_he: String
    private let _MediaPicker_Nof: String
    private let _MediaPicker_Nof_r: [(Int, NSRange)]
    public func MediaPicker_Nof(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_MediaPicker_Nof, self._MediaPicker_Nof_r, [_0])
    }
    public let Common_Create: String
    public let Contacts_TopSection: String
    private let _Map_DirectionsDriveEta: String
    private let _Map_DirectionsDriveEta_r: [(Int, NSRange)]
    public func Map_DirectionsDriveEta(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Map_DirectionsDriveEta, self._Map_DirectionsDriveEta_r, [_0])
    }
    public let PrivacyPolicy_DeclineMessage: String
    public let Your_cards_number_is_invalid: String
    private let _MESSAGE_INVOICE: String
    private let _MESSAGE_INVOICE_r: [(Int, NSRange)]
    public func MESSAGE_INVOICE(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_MESSAGE_INVOICE, self._MESSAGE_INVOICE_r, [_1, _2])
    }
    public let Localization_LanguageCustom: String
    private let _Channel_AdminLog_MessageRemovedChannelUsername: String
    private let _Channel_AdminLog_MessageRemovedChannelUsername_r: [(Int, NSRange)]
    public func Channel_AdminLog_MessageRemovedChannelUsername(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Channel_AdminLog_MessageRemovedChannelUsername, self._Channel_AdminLog_MessageRemovedChannelUsername_r, [_0])
    }
    public let Group_MessagePhotoRemoved: String
    public let Appearance_Animations: String
    public let UserInfo_AddToExisting: String
    public let NotificationsSound_Aurora: String
    private let _LastSeen_AtDate: String
    private let _LastSeen_AtDate_r: [(Int, NSRange)]
    public func LastSeen_AtDate(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_LastSeen_AtDate, self._LastSeen_AtDate_r, [_0])
    }
    public let Conversation_MessageDialogRetry: String
    public let Watch_ChatList_NoConversationsTitle: String
    public let Passport_Language_my: String
    public let Stickers_GroupStickers: String
    public let BlockedUsers_Title: String
    private let _LiveLocationUpdated_TodayAt: String
    private let _LiveLocationUpdated_TodayAt_r: [(Int, NSRange)]
    public func LiveLocationUpdated_TodayAt(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_LiveLocationUpdated_TodayAt, self._LiveLocationUpdated_TodayAt_r, [_0])
    }
    public let ContactInfo_PhoneLabelWork: String
    public let ChatSettings_ConnectionType_UseSocks5: String
    public let Passport_FieldAddressTranslationHelp: String
    public let Cache_ClearNone: String
    public let SecretTimer_VideoDescription: String
    public let Login_InvalidCodeError: String
    public let Channel_BanList_BlockedTitle: String
    public let Passport_PasswordHelp: String
    public let NetworkUsageSettings_Cellular: String
    public let Watch_Location_Access: String
    public let PrivacySettings_DeleteAccountIfAwayFor: String
    public let Channel_AdminLog_EmptyFilterText: String
    public let Channel_AdminLog_EmptyText: String
    public let PrivacySettings_DeleteAccountTitle: String
    public let Passport_Language_ms: String
    public let PrivacyLastSeenSettings_CustomShareSettings_Delete: String
    private let _ENCRYPTED_MESSAGE: String
    private let _ENCRYPTED_MESSAGE_r: [(Int, NSRange)]
    public func ENCRYPTED_MESSAGE(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_ENCRYPTED_MESSAGE, self._ENCRYPTED_MESSAGE_r, [_1])
    }
    public let Watch_LastSeen_WithinAMonth: String
    public let PrivacyLastSeenSettings_CustomHelp: String
    public let TwoStepAuth_EnterPasswordHelp: String
    public let Bot_Stop: String
    public let Privacy_GroupsAndChannels_AlwaysAllow_Placeholder: String
    public let UserInfo_BotSettings: String
    public let Your_cards_expiration_month_is_invalid: String
    public let Passport_FieldIdentity: String
    public let PrivacyLastSeenSettings_EmpryUsersPlaceholder: String
    public let Passport_Identity_EditInternalPassport: String
    private let _CHANNEL_MESSAGE_ROUND: String
    private let _CHANNEL_MESSAGE_ROUND_r: [(Int, NSRange)]
    public func CHANNEL_MESSAGE_ROUND(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_CHANNEL_MESSAGE_ROUND, self._CHANNEL_MESSAGE_ROUND_r, [_1])
    }
    public let Passport_Identity_LatinNameHelp: String
    public let SocksProxySetup_Port: String
    public let Message_VideoMessage: String
    public let Conversation_ContextMenuStickerPackInfo: String
    public let Login_ResetAccountProtected_LimitExceeded: String
    private let _CHAT_DELETE_MEMBER: String
    private let _CHAT_DELETE_MEMBER_r: [(Int, NSRange)]
    public func CHAT_DELETE_MEMBER(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_CHAT_DELETE_MEMBER, self._CHAT_DELETE_MEMBER_r, [_1, _2, _3])
    }
    public let Conversation_DiscardVoiceMessageAction: String
    public let Camera_Title: String
    public let Passport_Identity_IssueDate: String
    public let PhotoEditor_CurvesBlue: String
    public let Message_PinnedVideoMessage: String
    private let _Login_EmailPhoneSubject: String
    private let _Login_EmailPhoneSubject_r: [(Int, NSRange)]
    public func Login_EmailPhoneSubject(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Login_EmailPhoneSubject, self._Login_EmailPhoneSubject_r, [_0])
    }
    public let Passport_Phone_UseTelegramNumberHelp: String
    public let Group_EditAdmin_PermissionChangeInfo: String
    public let TwoStepAuth_Email: String
    public let Stickers_SuggestNone: String
    public let Map_SendMyCurrentLocation: String
    private let _MESSAGE_ROUND: String
    private let _MESSAGE_ROUND_r: [(Int, NSRange)]
    public func MESSAGE_ROUND(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_MESSAGE_ROUND, self._MESSAGE_ROUND_r, [_1])
    }
    public let Passport_Identity_IssueDatePlaceholder: String
    public let Watch_Message_Invoice: String
    public let Map_Unknown: String
    public let Wallpaper_Set: String
    public let AccessDenied_Title: String
    public let SharedMedia_CategoryLinks: String
    public let Localization_LanguageOther: String
    private let _CHAT_MESSAGES: String
    private let _CHAT_MESSAGES_r: [(Int, NSRange)]
    public func CHAT_MESSAGES(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_CHAT_MESSAGES, self._CHAT_MESSAGES_r, [_1, _2, _3])
    }
    public let SaveIncomingPhotosSettings_Title: String
    public let Passport_Identity_TypeDriversLicense: String
    public let FastTwoStepSetup_HintHelp: String
    public let Notifications_ExceptionsDefaultSound: String
    public let TwoStepAuth_EmailSkipAlert: String
    public let ChatSettings_Stickers: String
    public let Camera_FlashOff: String
    public let TwoStepAuth_Title: String
    public let Passport_Identity_Translation: String
    public let Checkout_ErrorProviderAccountTimeout: String
    public let TwoStepAuth_SetupPasswordEnterPasswordChange: String
    public let WebSearch_Images: String
    public let Conversation_typing: String
    public let Common_Back: String
    public let PrivacySettings_DataSettingsHelp: String
    public let Passport_Language_es: String
    public let Common_Search: String
    private let _CancelResetAccount_Success: String
    private let _CancelResetAccount_Success_r: [(Int, NSRange)]
    public func CancelResetAccount_Success(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_CancelResetAccount_Success, self._CancelResetAccount_Success_r, [_0])
    }
    public let Common_No: String
    public let Login_EmailNotConfiguredError: String
    public let Watch_Suggestion_OK: String
    public let Profile_AddToExisting: String
    private let _Passport_Identity_NativeNameTitle: String
    private let _Passport_Identity_NativeNameTitle_r: [(Int, NSRange)]
    public func Passport_Identity_NativeNameTitle(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Passport_Identity_NativeNameTitle, self._Passport_Identity_NativeNameTitle_r, [_0])
    }
    private let _PINNED_NOTEXT: String
    private let _PINNED_NOTEXT_r: [(Int, NSRange)]
    public func PINNED_NOTEXT(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_PINNED_NOTEXT, self._PINNED_NOTEXT_r, [_1])
    }
    private let _Login_EmailCodeBody: String
    private let _Login_EmailCodeBody_r: [(Int, NSRange)]
    public func Login_EmailCodeBody(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Login_EmailCodeBody, self._Login_EmailCodeBody_r, [_0])
    }
    public let NotificationsSound_Keys: String
    public let Passport_Phone_Title: String
    public let Profile_About: String
    private let _EncryptionKey_Description: String
    private let _EncryptionKey_Description_r: [(Int, NSRange)]
    public func EncryptionKey_Description(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_EncryptionKey_Description, self._EncryptionKey_Description_r, [_1, _2])
    }
    public let Conversation_UnreadMessages: String
    private let _DialogList_LiveLocationSharingTo: String
    private let _DialogList_LiveLocationSharingTo_r: [(Int, NSRange)]
    public func DialogList_LiveLocationSharingTo(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_DialogList_LiveLocationSharingTo, self._DialogList_LiveLocationSharingTo_r, [_0])
    }
    public let Tour_Title3: String
    public let Passport_Identity_FrontSide: String
    public let PrivacyLastSeenSettings_GroupsAndChannelsHelp: String
    public let Watch_Contacts_NoResults: String
    public let Passport_Language_id: String
    public let Passport_Identity_TypeIdentityCardUploadScan: String
    public let Watch_UserInfo_MuteTitle: String
    private let _Privacy_GroupsAndChannels_InviteToGroupError: String
    private let _Privacy_GroupsAndChannels_InviteToGroupError_r: [(Int, NSRange)]
    public func Privacy_GroupsAndChannels_InviteToGroupError(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Privacy_GroupsAndChannels_InviteToGroupError, self._Privacy_GroupsAndChannels_InviteToGroupError_r, [_0, _1])
    }
    private let _Message_PinnedTextMessage: String
    private let _Message_PinnedTextMessage_r: [(Int, NSRange)]
    public func Message_PinnedTextMessage(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Message_PinnedTextMessage, self._Message_PinnedTextMessage_r, [_0])
    }
    private let _Watch_Time_ShortWeekdayAt: String
    private let _Watch_Time_ShortWeekdayAt_r: [(Int, NSRange)]
    public func Watch_Time_ShortWeekdayAt(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Watch_Time_ShortWeekdayAt, self._Watch_Time_ShortWeekdayAt_r, [_1, _2])
    }
    public let Conversation_EmptyGifPanelPlaceholder: String
    public let DialogList_Typing: String
    public let Notification_CallBack: String
    public let Passport_Language_ru: String
    public let Map_LocatingError: String
    public let InfoPlist_NSFaceIDUsageDescription: String
    public let MediaPicker_Send: String
    public let ChannelIntro_Title: String
    public let AccessDenied_LocationAlwaysDenied: String
    private let _PINNED_GIF: String
    private let _PINNED_GIF_r: [(Int, NSRange)]
    public func PINNED_GIF(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_PINNED_GIF, self._PINNED_GIF_r, [_1])
    }
    private let _InviteText_SingleContact: String
    private let _InviteText_SingleContact_r: [(Int, NSRange)]
    public func InviteText_SingleContact(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_InviteText_SingleContact, self._InviteText_SingleContact_r, [_0])
    }
    public let Passport_Address_TypePassportRegistration: String
    public let Channel_EditAdmin_CannotEdit: String
    public let LoginPassword_PasswordHelp: String
    public let BlockedUsers_Unblock: String
    public let AutoDownloadSettings_Cellular: String
    public let Passport_Language_ro: String
    private let _Time_MonthOfYear_m1: String
    private let _Time_MonthOfYear_m1_r: [(Int, NSRange)]
    public func Time_MonthOfYear_m1(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Time_MonthOfYear_m1, self._Time_MonthOfYear_m1_r, [_0])
    }
    public let Appearance_PreviewIncomingText: String
    public let Passport_Identity_DateOfBirthPlaceholder: String
    public let Notifications_GroupNotificationsAlert: String
    public let Paint_Masks: String
    public let Appearance_ThemeDayClassic: String
    public let StickerPack_ErrorNotFound: String
    public let Appearance_ThemeNight: String
    public let SecretTimer_ImageDescription: String
    private let _PINNED_CONTACT: String
    private let _PINNED_CONTACT_r: [(Int, NSRange)]
    public func PINNED_CONTACT(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_PINNED_CONTACT, self._PINNED_CONTACT_r, [_1])
    }
    private let _FileSize_KB: String
    private let _FileSize_KB_r: [(Int, NSRange)]
    public func FileSize_KB(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_FileSize_KB, self._FileSize_KB_r, [_0])
    }
    public let Map_LiveLocationTitle: String
    public let Watch_GroupInfo_Title: String
    public let Channel_AdminLog_EmptyTitle: String
    public let PhotoEditor_Set: String
    public let LiveLocation_MenuStopAll: String
    public let SocksProxySetup_AddProxy: String
    private let _Notification_Invited: String
    private let _Notification_Invited_r: [(Int, NSRange)]
    public func Notification_Invited(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Notification_Invited, self._Notification_Invited_r, [_0, _1])
    }
    public let Watch_AuthRequired: String
    public let Conversation_EncryptedDescription1: String
    public let AppleWatch_ReplyPresets: String
    public let Channel_Members_AddAdminErrorNotAMember: String
    public let Conversation_EncryptedDescription2: String
    public let SocksProxySetup_HostnamePlaceholder: String
    public let NetworkUsageSettings_MediaVideoDataSection: String
    public let Paint_Edit: String
    public let Passport_Language_nl: String
    public let LastSeen_Offline: String
    public let Login_CodeFloodError: String
    public let Conversation_EncryptedDescription3: String
    public let Notifications_Badge_IncludePublicGroups: String
    public let Conversation_EncryptedDescription4: String
    public let AppleWatch_Title: String
    public let Contacts_AccessDeniedError: String
    public let Conversation_StatusTyping: String
    public let Share_Title: String
    public let TwoStepAuth_ConfirmationTitle: String
    public let Passport_Identity_FilesTitle: String
    public let ChatSettings_Title: String
    public let AuthSessions_CurrentSession: String
    public let Watch_Microphone_Access: String
    private let _Notification_RenamedChat: String
    private let _Notification_RenamedChat_r: [(Int, NSRange)]
    public func Notification_RenamedChat(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Notification_RenamedChat, self._Notification_RenamedChat_r, [_0])
    }
    public let Conversation_LiveLocation: String
    public let Watch_Conversation_GroupInfo: String
    public let Passport_Language_fr: String
    public let UserInfo_Title: String
    public let Passport_Identity_DoesNotExpire: String
    public let Map_LiveLocationGroupDescription: String
    public let Login_InfoHelp: String
    public let ShareMenu_ShareTo: String
    public let Message_PinnedGame: String
    public let Channel_AdminLog_CanSendMessages: String
    private let _AutoNightTheme_LocationHelp: String
    private let _AutoNightTheme_LocationHelp_r: [(Int, NSRange)]
    public func AutoNightTheme_LocationHelp(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_AutoNightTheme_LocationHelp, self._AutoNightTheme_LocationHelp_r, [_0, _1])
    }
    public let Notification_RenamedGroup: String
    private let _Call_PrivacyErrorMessage: String
    private let _Call_PrivacyErrorMessage_r: [(Int, NSRange)]
    public func Call_PrivacyErrorMessage(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Call_PrivacyErrorMessage, self._Call_PrivacyErrorMessage_r, [_0])
    }
    public let Passport_Address_Street: String
    public let Weekday_Thursday: String
    public let FastTwoStepSetup_HintPlaceholder: String
    public let PrivacySettings_DataSettings: String
    public let ChangePhoneNumberNumber_Title: String
    public let NotificationsSound_Bell: String
    public let Notifications_Badge_IncludeMutedChats: String
    public let TwoStepAuth_EnterPasswordInvalid: String
    public let DialogList_SearchSectionMessages: String
    public let Media_ShareThisVideo: String
    public let Call_ReportIncludeLogDescription: String
    public let Preview_DeleteGif: String
    public let Passport_Address_OneOfTypeTemporaryRegistration: String
    public let Weekday_Saturday: String
    public let UserInfo_DeleteContact: String
    public let Notifications_ResetAllNotifications: String
    public let SocksProxySetup_SaveProxy: String
    public let Passport_Identity_Country: String
    public let Notification_MessageLifetimeRemovedOutgoing: String
    public let Login_ContinueWithLocalization: String
    public let GroupInfo_AddParticipant: String
    public let Watch_Location_Current: String
    public let Checkout_NewCard_SaveInfoHelp: String
    private let _Settings_ApplyProxyAlertCredentials: String
    private let _Settings_ApplyProxyAlertCredentials_r: [(Int, NSRange)]
    public func Settings_ApplyProxyAlertCredentials(_ _1: String, _ _2: String, _ _3: String, _ _4: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Settings_ApplyProxyAlertCredentials, self._Settings_ApplyProxyAlertCredentials_r, [_1, _2, _3, _4])
    }
    public let MediaPicker_CameraRoll: String
    public let Channel_AdminLog_CanPinMessages: String
    public let KeyCommand_NewMessage: String
    private let _ChannelInfo_AddParticipantConfirmation: String
    private let _ChannelInfo_AddParticipantConfirmation_r: [(Int, NSRange)]
    public func ChannelInfo_AddParticipantConfirmation(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_ChannelInfo_AddParticipantConfirmation, self._ChannelInfo_AddParticipantConfirmation_r, [_0])
    }
    public let NetworkUsageSettings_TotalSection: String
    private let _PINNED_AUDIO: String
    private let _PINNED_AUDIO_r: [(Int, NSRange)]
    public func PINNED_AUDIO(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_PINNED_AUDIO, self._PINNED_AUDIO_r, [_1])
    }
    public let Privacy_GroupsAndChannels: String
    private let _Time_PreciseDate_m12: String
    private let _Time_PreciseDate_m12_r: [(Int, NSRange)]
    public func Time_PreciseDate_m12(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Time_PreciseDate_m12, self._Time_PreciseDate_m12_r, [_1, _2, _3])
    }
    public let Conversation_DiscardVoiceMessageDescription: String
    public let Passport_Address_ScansHelp: String
    private let _Notification_ChangedGroupPhoto: String
    private let _Notification_ChangedGroupPhoto_r: [(Int, NSRange)]
    public func Notification_ChangedGroupPhoto(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Notification_ChangedGroupPhoto, self._Notification_ChangedGroupPhoto_r, [_0])
    }
    public let TwoStepAuth_RemovePassword: String
    public let Privacy_GroupsAndChannels_CustomHelp: String
    public let Passport_Identity_Gender: String
    public let UserInfo_NotificationsDisable: String
    public let Watch_UserInfo_Service: String
    public let Privacy_Calls_CustomHelp: String
    public let ChangePhoneNumberCode_Code: String
    public let UserInfo_Invite: String
    public let CheckoutInfo_ErrorStateInvalid: String
    public let DialogList_ClearHistoryConfirmation: String
    public let CheckoutInfo_ErrorEmailInvalid: String
    public let Month_GenNovember: String
    public let UserInfo_NotificationsEnable: String
    private let _Target_InviteToGroupConfirmation: String
    private let _Target_InviteToGroupConfirmation_r: [(Int, NSRange)]
    public func Target_InviteToGroupConfirmation(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Target_InviteToGroupConfirmation, self._Target_InviteToGroupConfirmation_r, [_0])
    }
    public let Map_Map: String
    public let Map_OpenInMaps: String
    public let Common_OK: String
    public let TwoStepAuth_SetupHintTitle: String
    public let GroupInfo_LeftStatus: String
    public let Cache_ClearProgress: String
    public let Login_InvalidPhoneError: String
    public let Passport_Authorize: String
    public let Cache_ClearEmpty: String
    public let Map_Search: String
    public let Passport_Identity_Translations: String
    public let ChannelMembers_GroupAdminsTitle: String
    private let _Channel_AdminLog_MessageRemovedGroupUsername: String
    private let _Channel_AdminLog_MessageRemovedGroupUsername_r: [(Int, NSRange)]
    public func Channel_AdminLog_MessageRemovedGroupUsername(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Channel_AdminLog_MessageRemovedGroupUsername, self._Channel_AdminLog_MessageRemovedGroupUsername_r, [_0])
    }
    public let ChatSettings_AutomaticPhotoDownload: String
    public let Group_ErrorAddTooMuchAdmins: String
    public let SocksProxySetup_Password: String
    public let Login_SelectCountry_Title: String
    private let _MESSAGE_PHOTOS: String
    private let _MESSAGE_PHOTOS_r: [(Int, NSRange)]
    public func MESSAGE_PHOTOS(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_MESSAGE_PHOTOS, self._MESSAGE_PHOTOS_r, [_1, _2])
    }
    public let Notifications_GroupNotificationsHelp: String
    public let PhotoEditor_CropAspectRatioSquare: String
    public let Notification_CallOutgoing: String
    public let UserInfo_NotificationsDefault: String
    public let Weekday_ShortMonday: String
    public let Checkout_Receipt_Title: String
    public let Channel_Edit_AboutItem: String
    public let Login_InfoLastNamePlaceholder: String
    public let Channel_Members_AddMembersHelp: String
    private let _MESSAGE_VIDEO_SECRET: String
    private let _MESSAGE_VIDEO_SECRET_r: [(Int, NSRange)]
    public func MESSAGE_VIDEO_SECRET(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_MESSAGE_VIDEO_SECRET, self._MESSAGE_VIDEO_SECRET_r, [_1])
    }
    public let Settings_CopyPhoneNumber: String
    public let ReportPeer_Report: String
    public let Channel_EditMessageErrorGeneric: String
    public let Passport_Identity_TranslationsHelp: String
    public let LoginPassword_FloodError: String
    public let TwoStepAuth_SetupPasswordTitle: String
    public let PhotoEditor_DiscardChanges: String
    public let Group_UpgradeNoticeText2: String
    private let _PINNED_ROUND: String
    private let _PINNED_ROUND_r: [(Int, NSRange)]
    public func PINNED_ROUND(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_PINNED_ROUND, self._PINNED_ROUND_r, [_1])
    }
    private let _ChannelInfo_ChannelForbidden: String
    private let _ChannelInfo_ChannelForbidden_r: [(Int, NSRange)]
    public func ChannelInfo_ChannelForbidden(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_ChannelInfo_ChannelForbidden, self._ChannelInfo_ChannelForbidden_r, [_0])
    }
    public let Conversation_ShareMyContactInfo: String
    public let SocksProxySetup_UsernamePlaceholder: String
    private let _CHANNEL_MESSAGE_GEO: String
    private let _CHANNEL_MESSAGE_GEO_r: [(Int, NSRange)]
    public func CHANNEL_MESSAGE_GEO(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_CHANNEL_MESSAGE_GEO, self._CHANNEL_MESSAGE_GEO_r, [_1])
    }
    public let Contacts_PhoneNumber: String
    public let Group_Info_AdminLog: String
    public let Channel_AdminLogFilter_ChannelEventsInfo: String
    public let ChatSettings_AutoDownloadEnabled: String
    public let StickerPacksSettings_FeaturedPacks: String
    public let AuthSessions_LoggedIn: String
    public let Month_GenAugust: String
    public let Notification_CallCanceled: String
    public let Channel_Username_CreatePublicLinkHelp: String
    public let StickerPack_Send: String
    public let StickerSettings_MaskContextInfo: String
    public let Watch_Suggestion_HoldOn: String
    private let _PINNED_GEO: String
    private let _PINNED_GEO_r: [(Int, NSRange)]
    public func PINNED_GEO(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_PINNED_GEO, self._PINNED_GEO_r, [_1])
    }
    public let PasscodeSettings_EncryptData: String
    public let Common_NotNow: String
    public let FastTwoStepSetup_PasswordConfirmationPlaceholder: String
    public let PasscodeSettings_Title: String
    public let StickerPack_BuiltinPackName: String
    public let Appearance_AccentColor: String
    public let Watch_Suggestion_BRB: String
    private let _CHAT_MESSAGE_ROUND: String
    private let _CHAT_MESSAGE_ROUND_r: [(Int, NSRange)]
    public func CHAT_MESSAGE_ROUND(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_CHAT_MESSAGE_ROUND, self._CHAT_MESSAGE_ROUND_r, [_1, _2])
    }
    public let Notifications_MessageNotificationsAlert: String
    public let Username_InvalidCharacters: String
    public let GroupInfo_LabelAdmin: String
    public let GroupInfo_Sound: String
    public let Channel_EditAdmin_PermissionBanUsers: String
    public let InfoPlist_NSCameraUsageDescription: String
    public let Passport_Address_AddRentalAgreement: String
    public let Wallpaper_PhotoLibrary: String
    public let Settings_About: String
    public let Privacy_Calls_IntegrationHelp: String
    public let ContactInfo_Job: String
    private let _CHAT_LEFT: String
    private let _CHAT_LEFT_r: [(Int, NSRange)]
    public func CHAT_LEFT(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_CHAT_LEFT, self._CHAT_LEFT_r, [_1, _2])
    }
    public let LoginPassword_ForgotPassword: String
    public let Passport_Address_AddTemporaryRegistration: String
    private let _Map_LiveLocationShortHour: String
    private let _Map_LiveLocationShortHour_r: [(Int, NSRange)]
    public func Map_LiveLocationShortHour(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Map_LiveLocationShortHour, self._Map_LiveLocationShortHour_r, [_0])
    }
    public let Appearance_Preview: String
    private let _DialogList_AwaitingEncryption: String
    private let _DialogList_AwaitingEncryption_r: [(Int, NSRange)]
    public func DialogList_AwaitingEncryption(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_DialogList_AwaitingEncryption, self._DialogList_AwaitingEncryption_r, [_0])
    }
    public let Passport_Identity_TypePassport: String
    public let ChatSettings_Appearance: String
    public let Tour_Title1: String
    public let Conversation_EditingCaptionPanelTitle: String
    private let _Notifications_ExceptionsChangeSound: String
    private let _Notifications_ExceptionsChangeSound_r: [(Int, NSRange)]
    public func Notifications_ExceptionsChangeSound(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Notifications_ExceptionsChangeSound, self._Notifications_ExceptionsChangeSound_r, [_0])
    }
    public let Conversation_LinkDialogCopy: String
    private let _Notification_PinnedLocationMessage: String
    private let _Notification_PinnedLocationMessage_r: [(Int, NSRange)]
    public func Notification_PinnedLocationMessage(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Notification_PinnedLocationMessage, self._Notification_PinnedLocationMessage_r, [_0])
    }
    private let _Notification_PinnedPhotoMessage: String
    private let _Notification_PinnedPhotoMessage_r: [(Int, NSRange)]
    public func Notification_PinnedPhotoMessage(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Notification_PinnedPhotoMessage, self._Notification_PinnedPhotoMessage_r, [_0])
    }
    private let _DownloadingStatus: String
    private let _DownloadingStatus_r: [(Int, NSRange)]
    public func DownloadingStatus(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_DownloadingStatus, self._DownloadingStatus_r, [_0, _1])
    }
    public let Calls_All: String
    private let _Channel_MessageTitleUpdated: String
    private let _Channel_MessageTitleUpdated_r: [(Int, NSRange)]
    public func Channel_MessageTitleUpdated(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Channel_MessageTitleUpdated, self._Channel_MessageTitleUpdated_r, [_0])
    }
    public let Call_CallAgain: String
    public let Message_VideoExpired: String
    public let TwoStepAuth_RecoveryCodeHelp: String
    private let _Channel_AdminLog_MessagePromotedNameUsername: String
    private let _Channel_AdminLog_MessagePromotedNameUsername_r: [(Int, NSRange)]
    public func Channel_AdminLog_MessagePromotedNameUsername(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Channel_AdminLog_MessagePromotedNameUsername, self._Channel_AdminLog_MessagePromotedNameUsername_r, [_1, _2])
    }
    public let UserInfo_SendMessage: String
    private let _Channel_Username_LinkHint: String
    private let _Channel_Username_LinkHint_r: [(Int, NSRange)]
    public func Channel_Username_LinkHint(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Channel_Username_LinkHint, self._Channel_Username_LinkHint_r, [_0])
    }
    private let _AutoDownloadSettings_UpTo: String
    private let _AutoDownloadSettings_UpTo_r: [(Int, NSRange)]
    public func AutoDownloadSettings_UpTo(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_AutoDownloadSettings_UpTo, self._AutoDownloadSettings_UpTo_r, [_0])
    }
    public let Settings_ViewPhoto: String
    public let Paint_RecentStickers: String
    private let _Passport_PrivacyPolicy: String
    private let _Passport_PrivacyPolicy_r: [(Int, NSRange)]
    public func Passport_PrivacyPolicy(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Passport_PrivacyPolicy, self._Passport_PrivacyPolicy_r, [_1, _2])
    }
    public let Login_CallRequestState3: String
    public let Channel_Edit_LinkItem: String
    public let CallSettings_Title: String
    public let ChangePhoneNumberNumber_Help: String
    public let Passport_InfoTitle: String
    public let Watch_Suggestion_Thanks: String
    public let Channel_Moderator_Title: String
    public let Message_PinnedPhotoMessage: String
    public let Notification_SecretChatScreenshot: String
    private let _Conversation_DeleteMessagesFor: String
    private let _Conversation_DeleteMessagesFor_r: [(Int, NSRange)]
    public func Conversation_DeleteMessagesFor(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Conversation_DeleteMessagesFor, self._Conversation_DeleteMessagesFor_r, [_0])
    }
    public let Activity_UploadingDocument: String
    public let Watch_ChatList_NoConversationsText: String
    public let ReportPeer_AlertSuccess: String
    public let Tour_Text4: String
    public let Channel_Info_Description: String
    public let AccessDenied_LocationTracking: String
    public let Watch_Compose_Send: String
    public let SocksProxySetup_UseForCallsHelp: String
    public let Preview_CopyAddress: String
    public let Settings_BlockedUsers: String
    public let Month_ShortAugust: String
    public let Passport_Identity_MainPage: String
    public let Passport_FieldAddress: String
    public let Channel_AdminLogFilter_AdminsTitle: String
    public let Channel_EditAdmin_PermissionChangeInfo: String
    public let Notifications_ResetAllNotificationsHelp: String
    public let DialogList_EncryptionRejected: String
    public let Target_InviteToGroupErrorAlreadyInvited: String
    public let AccessDenied_CameraRestricted: String
    public let Watch_Message_ForwardedFrom: String
    public let CheckoutInfo_ShippingInfoCountryPlaceholder: String
    public let Channel_AboutItem: String
    public let PhotoEditor_CurvesGreen: String
    public let Month_GenJuly: String
    public let ContactInfo_URLLabelHomepage: String
    public let PrivacyPolicy_DeclineDeclineAndDelete: String
    private let _DialogList_SingleUploadingFileSuffix: String
    private let _DialogList_SingleUploadingFileSuffix_r: [(Int, NSRange)]
    public func DialogList_SingleUploadingFileSuffix(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_DialogList_SingleUploadingFileSuffix, self._DialogList_SingleUploadingFileSuffix_r, [_0])
    }
    public let ChannelIntro_CreateChannel: String
    public let Channel_Management_AddModerator: String
    public let Common_ChoosePhoto: String
    public let Conversation_Pin: String
    private let _Login_ResetAccountProtected_Text: String
    private let _Login_ResetAccountProtected_Text_r: [(Int, NSRange)]
    public func Login_ResetAccountProtected_Text(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Login_ResetAccountProtected_Text, self._Login_ResetAccountProtected_Text_r, [_0])
    }
    private let _Channel_AdminLog_EmptyFilterQueryText: String
    private let _Channel_AdminLog_EmptyFilterQueryText_r: [(Int, NSRange)]
    public func Channel_AdminLog_EmptyFilterQueryText(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Channel_AdminLog_EmptyFilterQueryText, self._Channel_AdminLog_EmptyFilterQueryText_r, [_0])
    }
    public let Camera_TapAndHoldForVideo: String
    public let Bot_DescriptionTitle: String
    public let FeaturedStickerPacks_Title: String
    public let Map_OpenInGoogleMaps: String
    public let Notification_MessageLifetime5s: String
    public let Contacts_Title: String
    private let _MESSAGES: String
    private let _MESSAGES_r: [(Int, NSRange)]
    public func MESSAGES(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_MESSAGES, self._MESSAGES_r, [_1, _2])
    }
    public let Channel_Management_AddModeratorHelp: String
    private let _CHAT_MESSAGE_FWDS: String
    private let _CHAT_MESSAGE_FWDS_r: [(Int, NSRange)]
    public func CHAT_MESSAGE_FWDS(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_CHAT_MESSAGE_FWDS, self._CHAT_MESSAGE_FWDS_r, [_1, _2, _3])
    }
    public let Conversation_MessageDialogEdit: String
    public let PrivacyLastSeenSettings_Title: String
    public let Notifications_ClassicTones: String
    public let Conversation_LinkDialogOpen: String
    public let Channel_Info_Subscribers: String
    public let NotificationsSound_Input: String
    public let Conversation_ClousStorageInfo_Description4: String
    public let Privacy_Calls_AlwaysAllow: String
    public let Privacy_PaymentsClearInfoHelp: String
    public let Notification_MessageLifetime1h: String
    private let _Notification_CreatedChatWithTitle: String
    private let _Notification_CreatedChatWithTitle_r: [(Int, NSRange)]
    public func Notification_CreatedChatWithTitle(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Notification_CreatedChatWithTitle, self._Notification_CreatedChatWithTitle_r, [_0, _1])
    }
    public let CheckoutInfo_ReceiverInfoEmail: String
    public let LastSeen_Lately: String
    public let Month_ShortApril: String
    public let ConversationProfile_ErrorCreatingConversation: String
    private let _PHONE_CALL_MISSED: String
    private let _PHONE_CALL_MISSED_r: [(Int, NSRange)]
    public func PHONE_CALL_MISSED(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_PHONE_CALL_MISSED, self._PHONE_CALL_MISSED_r, [_1])
    }
    private let _Conversation_Kilobytes: String
    private let _Conversation_Kilobytes_r: [(Int, NSRange)]
    public func Conversation_Kilobytes(_ _0: Int) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Conversation_Kilobytes, self._Conversation_Kilobytes_r, ["\(_0)"])
    }
    public let Group_ErrorAddBlocked: String
    public let TwoStepAuth_AdditionalPassword: String
    public let MediaPicker_Videos: String
    public let Notification_PassportValueProofOfIdentity: String
    public let BlockedUsers_AddNew: String
    public let Notifications_DisplayNamesOnLockScreenInfo: String
    public let StickerPacksSettings_StickerPacksSection: String
    public let Channel_NotificationLoading: String
    public let Passport_Language_da: String
    public let Passport_Address_Country: String
    private let _CHAT_RETURNED: String
    private let _CHAT_RETURNED_r: [(Int, NSRange)]
    public func CHAT_RETURNED(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_CHAT_RETURNED, self._CHAT_RETURNED_r, [_1, _2])
    }
    public let PhotoEditor_ShadowsTint: String
    public let ExplicitContent_AlertTitle: String
    public let Channel_AdminLogFilter_EventsLeaving: String
    public let Map_LiveLocationFor8Hours: String
    public let StickerPack_HideStickers: String
    public let Checkout_EnterPassword: String
    public let UserInfo_NotificationsEnabled: String
    public let InfoPlist_NSLocationAlwaysUsageDescription: String
    public let SocksProxySetup_ProxyDetailsTitle: String
    public let Appearance_ReduceMotionInfo: String
    public let Weekday_ShortTuesday: String
    public let Notification_CallIncomingShort: String
    public let ConvertToSupergroup_Note: String
    public let DialogList_Read: String
    public let Conversation_EmptyPlaceholder: String
    private let _Passport_Email_CodeHelp: String
    private let _Passport_Email_CodeHelp_r: [(Int, NSRange)]
    public func Passport_Email_CodeHelp(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Passport_Email_CodeHelp, self._Passport_Email_CodeHelp_r, [_0])
    }
    public let Username_Help: String
    public let StickerSettings_ContextHide: String
    public let Media_ShareThisPhoto: String
    public let Contacts_ShareTelegram: String
    public let AutoNightTheme_Scheduled: String
    public let Weekday_Sunday: String
    public let PrivacySettings_PasscodeAndFaceId: String
    public let Settings_ChatBackground: String
    public let Login_TermsOfServiceDecline: String
    private let _ForwardedAudios_zero: String
    private let _ForwardedAudios_one: String
    private let _ForwardedAudios_two: String
    private let _ForwardedAudios_few: String
    private let _ForwardedAudios_many: String
    private let _ForwardedAudios_other: String
    public func ForwardedAudios(_ value: Int32) -> String {
        switch presentationStringsPluralizationForm(self.lc, value) {
            case .zero:
                return String(format: self._ForwardedAudios_zero, "\(value)")
            case .one:
                return String(format: self._ForwardedAudios_one, "\(value)")
            case .two:
                return String(format: self._ForwardedAudios_two, "\(value)")
            case .few:
                return String(format: self._ForwardedAudios_few, "\(value)")
            case .many:
                return String(format: self._ForwardedAudios_many, "\(value)")
            case .other:
                return String(format: self._ForwardedAudios_other, "\(value)")
        }
    }
    private let _Conversation_StatusMembers_zero: String
    private let _Conversation_StatusMembers_one: String
    private let _Conversation_StatusMembers_two: String
    private let _Conversation_StatusMembers_few: String
    private let _Conversation_StatusMembers_many: String
    private let _Conversation_StatusMembers_other: String
    public func Conversation_StatusMembers(_ value: Int32) -> String {
        switch presentationStringsPluralizationForm(self.lc, value) {
            case .zero:
                return String(format: self._Conversation_StatusMembers_zero, "\(value)")
            case .one:
                return String(format: self._Conversation_StatusMembers_one, "\(value)")
            case .two:
                return String(format: self._Conversation_StatusMembers_two, "\(value)")
            case .few:
                return String(format: self._Conversation_StatusMembers_few, "\(value)")
            case .many:
                return String(format: self._Conversation_StatusMembers_many, "\(value)")
            case .other:
                return String(format: self._Conversation_StatusMembers_other, "\(value)")
        }
    }
    private let _AttachmentMenu_SendPhoto_zero: String
    private let _AttachmentMenu_SendPhoto_one: String
    private let _AttachmentMenu_SendPhoto_two: String
    private let _AttachmentMenu_SendPhoto_few: String
    private let _AttachmentMenu_SendPhoto_many: String
    private let _AttachmentMenu_SendPhoto_other: String
    public func AttachmentMenu_SendPhoto(_ value: Int32) -> String {
        switch presentationStringsPluralizationForm(self.lc, value) {
            case .zero:
                return String(format: self._AttachmentMenu_SendPhoto_zero, "\(value)")
            case .one:
                return String(format: self._AttachmentMenu_SendPhoto_one, "\(value)")
            case .two:
                return String(format: self._AttachmentMenu_SendPhoto_two, "\(value)")
            case .few:
                return String(format: self._AttachmentMenu_SendPhoto_few, "\(value)")
            case .many:
                return String(format: self._AttachmentMenu_SendPhoto_many, "\(value)")
            case .other:
                return String(format: self._AttachmentMenu_SendPhoto_other, "\(value)")
        }
    }
    private let _ForwardedMessages_zero: String
    private let _ForwardedMessages_one: String
    private let _ForwardedMessages_two: String
    private let _ForwardedMessages_few: String
    private let _ForwardedMessages_many: String
    private let _ForwardedMessages_other: String
    public func ForwardedMessages(_ value: Int32) -> String {
        switch presentationStringsPluralizationForm(self.lc, value) {
            case .zero:
                return String(format: self._ForwardedMessages_zero, "\(value)")
            case .one:
                return String(format: self._ForwardedMessages_one, "\(value)")
            case .two:
                return String(format: self._ForwardedMessages_two, "\(value)")
            case .few:
                return String(format: self._ForwardedMessages_few, "\(value)")
            case .many:
                return String(format: self._ForwardedMessages_many, "\(value)")
            case .other:
                return String(format: self._ForwardedMessages_other, "\(value)")
        }
    }
    private let _MessageTimer_ShortSeconds_zero: String
    private let _MessageTimer_ShortSeconds_one: String
    private let _MessageTimer_ShortSeconds_two: String
    private let _MessageTimer_ShortSeconds_few: String
    private let _MessageTimer_ShortSeconds_many: String
    private let _MessageTimer_ShortSeconds_other: String
    public func MessageTimer_ShortSeconds(_ value: Int32) -> String {
        switch presentationStringsPluralizationForm(self.lc, value) {
            case .zero:
                return String(format: self._MessageTimer_ShortSeconds_zero, "\(value)")
            case .one:
                return String(format: self._MessageTimer_ShortSeconds_one, "\(value)")
            case .two:
                return String(format: self._MessageTimer_ShortSeconds_two, "\(value)")
            case .few:
                return String(format: self._MessageTimer_ShortSeconds_few, "\(value)")
            case .many:
                return String(format: self._MessageTimer_ShortSeconds_many, "\(value)")
            case .other:
                return String(format: self._MessageTimer_ShortSeconds_other, "\(value)")
        }
    }
    private let _ForwardedPhotos_zero: String
    private let _ForwardedPhotos_one: String
    private let _ForwardedPhotos_two: String
    private let _ForwardedPhotos_few: String
    private let _ForwardedPhotos_many: String
    private let _ForwardedPhotos_other: String
    public func ForwardedPhotos(_ value: Int32) -> String {
        switch presentationStringsPluralizationForm(self.lc, value) {
            case .zero:
                return String(format: self._ForwardedPhotos_zero, "\(value)")
            case .one:
                return String(format: self._ForwardedPhotos_one, "\(value)")
            case .two:
                return String(format: self._ForwardedPhotos_two, "\(value)")
            case .few:
                return String(format: self._ForwardedPhotos_few, "\(value)")
            case .many:
                return String(format: self._ForwardedPhotos_many, "\(value)")
            case .other:
                return String(format: self._ForwardedPhotos_other, "\(value)")
        }
    }
    private let _Notifications_ExceptionMuteExpires_Hours_zero: String
    private let _Notifications_ExceptionMuteExpires_Hours_one: String
    private let _Notifications_ExceptionMuteExpires_Hours_two: String
    private let _Notifications_ExceptionMuteExpires_Hours_few: String
    private let _Notifications_ExceptionMuteExpires_Hours_many: String
    private let _Notifications_ExceptionMuteExpires_Hours_other: String
    public func Notifications_ExceptionMuteExpires_Hours(_ value: Int32) -> String {
        switch presentationStringsPluralizationForm(self.lc, value) {
            case .zero:
                return String(format: self._Notifications_ExceptionMuteExpires_Hours_zero, "\(value)")
            case .one:
                return String(format: self._Notifications_ExceptionMuteExpires_Hours_one, "\(value)")
            case .two:
                return String(format: self._Notifications_ExceptionMuteExpires_Hours_two, "\(value)")
            case .few:
                return String(format: self._Notifications_ExceptionMuteExpires_Hours_few, "\(value)")
            case .many:
                return String(format: self._Notifications_ExceptionMuteExpires_Hours_many, "\(value)")
            case .other:
                return String(format: self._Notifications_ExceptionMuteExpires_Hours_other, "\(value)")
        }
    }
    private let _Call_Minutes_zero: String
    private let _Call_Minutes_one: String
    private let _Call_Minutes_two: String
    private let _Call_Minutes_few: String
    private let _Call_Minutes_many: String
    private let _Call_Minutes_other: String
    public func Call_Minutes(_ value: Int32) -> String {
        switch presentationStringsPluralizationForm(self.lc, value) {
            case .zero:
                return String(format: self._Call_Minutes_zero, "\(value)")
            case .one:
                return String(format: self._Call_Minutes_one, "\(value)")
            case .two:
                return String(format: self._Call_Minutes_two, "\(value)")
            case .few:
                return String(format: self._Call_Minutes_few, "\(value)")
            case .many:
                return String(format: self._Call_Minutes_many, "\(value)")
            case .other:
                return String(format: self._Call_Minutes_other, "\(value)")
        }
    }
    private let _SharedMedia_Video_zero: String
    private let _SharedMedia_Video_one: String
    private let _SharedMedia_Video_two: String
    private let _SharedMedia_Video_few: String
    private let _SharedMedia_Video_many: String
    private let _SharedMedia_Video_other: String
    public func SharedMedia_Video(_ value: Int32) -> String {
        switch presentationStringsPluralizationForm(self.lc, value) {
            case .zero:
                return String(format: self._SharedMedia_Video_zero, "\(value)")
            case .one:
                return String(format: self._SharedMedia_Video_one, "\(value)")
            case .two:
                return String(format: self._SharedMedia_Video_two, "\(value)")
            case .few:
                return String(format: self._SharedMedia_Video_few, "\(value)")
            case .many:
                return String(format: self._SharedMedia_Video_many, "\(value)")
            case .other:
                return String(format: self._SharedMedia_Video_other, "\(value)")
        }
    }
    private let _MessageTimer_Minutes_zero: String
    private let _MessageTimer_Minutes_one: String
    private let _MessageTimer_Minutes_two: String
    private let _MessageTimer_Minutes_few: String
    private let _MessageTimer_Minutes_many: String
    private let _MessageTimer_Minutes_other: String
    public func MessageTimer_Minutes(_ value: Int32) -> String {
        switch presentationStringsPluralizationForm(self.lc, value) {
            case .zero:
                return String(format: self._MessageTimer_Minutes_zero, "\(value)")
            case .one:
                return String(format: self._MessageTimer_Minutes_one, "\(value)")
            case .two:
                return String(format: self._MessageTimer_Minutes_two, "\(value)")
            case .few:
                return String(format: self._MessageTimer_Minutes_few, "\(value)")
            case .many:
                return String(format: self._MessageTimer_Minutes_many, "\(value)")
            case .other:
                return String(format: self._MessageTimer_Minutes_other, "\(value)")
        }
    }
    private let _MessageTimer_Days_zero: String
    private let _MessageTimer_Days_one: String
    private let _MessageTimer_Days_two: String
    private let _MessageTimer_Days_few: String
    private let _MessageTimer_Days_many: String
    private let _MessageTimer_Days_other: String
    public func MessageTimer_Days(_ value: Int32) -> String {
        switch presentationStringsPluralizationForm(self.lc, value) {
            case .zero:
                return String(format: self._MessageTimer_Days_zero, "\(value)")
            case .one:
                return String(format: self._MessageTimer_Days_one, "\(value)")
            case .two:
                return String(format: self._MessageTimer_Days_two, "\(value)")
            case .few:
                return String(format: self._MessageTimer_Days_few, "\(value)")
            case .many:
                return String(format: self._MessageTimer_Days_many, "\(value)")
            case .other:
                return String(format: self._MessageTimer_Days_other, "\(value)")
        }
    }
    private let _Media_ShareItem_zero: String
    private let _Media_ShareItem_one: String
    private let _Media_ShareItem_two: String
    private let _Media_ShareItem_few: String
    private let _Media_ShareItem_many: String
    private let _Media_ShareItem_other: String
    public func Media_ShareItem(_ value: Int32) -> String {
        switch presentationStringsPluralizationForm(self.lc, value) {
            case .zero:
                return String(format: self._Media_ShareItem_zero, "\(value)")
            case .one:
                return String(format: self._Media_ShareItem_one, "\(value)")
            case .two:
                return String(format: self._Media_ShareItem_two, "\(value)")
            case .few:
                return String(format: self._Media_ShareItem_few, "\(value)")
            case .many:
                return String(format: self._Media_ShareItem_many, "\(value)")
            case .other:
                return String(format: self._Media_ShareItem_other, "\(value)")
        }
    }
    private let _Call_Seconds_zero: String
    private let _Call_Seconds_one: String
    private let _Call_Seconds_two: String
    private let _Call_Seconds_few: String
    private let _Call_Seconds_many: String
    private let _Call_Seconds_other: String
    public func Call_Seconds(_ value: Int32) -> String {
        switch presentationStringsPluralizationForm(self.lc, value) {
            case .zero:
                return String(format: self._Call_Seconds_zero, "\(value)")
            case .one:
                return String(format: self._Call_Seconds_one, "\(value)")
            case .two:
                return String(format: self._Call_Seconds_two, "\(value)")
            case .few:
                return String(format: self._Call_Seconds_few, "\(value)")
            case .many:
                return String(format: self._Call_Seconds_many, "\(value)")
            case .other:
                return String(format: self._Call_Seconds_other, "\(value)")
        }
    }
    private let _StickerPack_AddStickerCount_zero: String
    private let _StickerPack_AddStickerCount_one: String
    private let _StickerPack_AddStickerCount_two: String
    private let _StickerPack_AddStickerCount_few: String
    private let _StickerPack_AddStickerCount_many: String
    private let _StickerPack_AddStickerCount_other: String
    public func StickerPack_AddStickerCount(_ value: Int32) -> String {
        switch presentationStringsPluralizationForm(self.lc, value) {
            case .zero:
                return String(format: self._StickerPack_AddStickerCount_zero, "\(value)")
            case .one:
                return String(format: self._StickerPack_AddStickerCount_one, "\(value)")
            case .two:
                return String(format: self._StickerPack_AddStickerCount_two, "\(value)")
            case .few:
                return String(format: self._StickerPack_AddStickerCount_few, "\(value)")
            case .many:
                return String(format: self._StickerPack_AddStickerCount_many, "\(value)")
            case .other:
                return String(format: self._StickerPack_AddStickerCount_other, "\(value)")
        }
    }
    private let _StickerPack_AddMaskCount_zero: String
    private let _StickerPack_AddMaskCount_one: String
    private let _StickerPack_AddMaskCount_two: String
    private let _StickerPack_AddMaskCount_few: String
    private let _StickerPack_AddMaskCount_many: String
    private let _StickerPack_AddMaskCount_other: String
    public func StickerPack_AddMaskCount(_ value: Int32) -> String {
        switch presentationStringsPluralizationForm(self.lc, value) {
            case .zero:
                return String(format: self._StickerPack_AddMaskCount_zero, "\(value)")
            case .one:
                return String(format: self._StickerPack_AddMaskCount_one, "\(value)")
            case .two:
                return String(format: self._StickerPack_AddMaskCount_two, "\(value)")
            case .few:
                return String(format: self._StickerPack_AddMaskCount_few, "\(value)")
            case .many:
                return String(format: self._StickerPack_AddMaskCount_many, "\(value)")
            case .other:
                return String(format: self._StickerPack_AddMaskCount_other, "\(value)")
        }
    }
    private let _LastSeen_MinutesAgo_zero: String
    private let _LastSeen_MinutesAgo_one: String
    private let _LastSeen_MinutesAgo_two: String
    private let _LastSeen_MinutesAgo_few: String
    private let _LastSeen_MinutesAgo_many: String
    private let _LastSeen_MinutesAgo_other: String
    public func LastSeen_MinutesAgo(_ value: Int32) -> String {
        switch presentationStringsPluralizationForm(self.lc, value) {
            case .zero:
                return String(format: self._LastSeen_MinutesAgo_zero, "\(value)")
            case .one:
                return String(format: self._LastSeen_MinutesAgo_one, "\(value)")
            case .two:
                return String(format: self._LastSeen_MinutesAgo_two, "\(value)")
            case .few:
                return String(format: self._LastSeen_MinutesAgo_few, "\(value)")
            case .many:
                return String(format: self._LastSeen_MinutesAgo_many, "\(value)")
            case .other:
                return String(format: self._LastSeen_MinutesAgo_other, "\(value)")
        }
    }
    private let _Contacts_ImportersCount_zero: String
    private let _Contacts_ImportersCount_one: String
    private let _Contacts_ImportersCount_two: String
    private let _Contacts_ImportersCount_few: String
    private let _Contacts_ImportersCount_many: String
    private let _Contacts_ImportersCount_other: String
    public func Contacts_ImportersCount(_ value: Int32) -> String {
        switch presentationStringsPluralizationForm(self.lc, value) {
            case .zero:
                return String(format: self._Contacts_ImportersCount_zero, "\(value)")
            case .one:
                return String(format: self._Contacts_ImportersCount_one, "\(value)")
            case .two:
                return String(format: self._Contacts_ImportersCount_two, "\(value)")
            case .few:
                return String(format: self._Contacts_ImportersCount_few, "\(value)")
            case .many:
                return String(format: self._Contacts_ImportersCount_many, "\(value)")
            case .other:
                return String(format: self._Contacts_ImportersCount_other, "\(value)")
        }
    }
    private let _ServiceMessage_GameScoreSelfExtended_zero: String
    private let _ServiceMessage_GameScoreSelfExtended_one: String
    private let _ServiceMessage_GameScoreSelfExtended_two: String
    private let _ServiceMessage_GameScoreSelfExtended_few: String
    private let _ServiceMessage_GameScoreSelfExtended_many: String
    private let _ServiceMessage_GameScoreSelfExtended_other: String
    public func ServiceMessage_GameScoreSelfExtended(_ value: Int32) -> String {
        switch presentationStringsPluralizationForm(self.lc, value) {
            case .zero:
                return String(format: self._ServiceMessage_GameScoreSelfExtended_zero, "\(value)")
            case .one:
                return String(format: self._ServiceMessage_GameScoreSelfExtended_one, "\(value)")
            case .two:
                return String(format: self._ServiceMessage_GameScoreSelfExtended_two, "\(value)")
            case .few:
                return String(format: self._ServiceMessage_GameScoreSelfExtended_few, "\(value)")
            case .many:
                return String(format: self._ServiceMessage_GameScoreSelfExtended_many, "\(value)")
            case .other:
                return String(format: self._ServiceMessage_GameScoreSelfExtended_other, "\(value)")
        }
    }
    private let _AttachmentMenu_SendGif_zero: String
    private let _AttachmentMenu_SendGif_one: String
    private let _AttachmentMenu_SendGif_two: String
    private let _AttachmentMenu_SendGif_few: String
    private let _AttachmentMenu_SendGif_many: String
    private let _AttachmentMenu_SendGif_other: String
    public func AttachmentMenu_SendGif(_ value: Int32) -> String {
        switch presentationStringsPluralizationForm(self.lc, value) {
            case .zero:
                return String(format: self._AttachmentMenu_SendGif_zero, "\(value)")
            case .one:
                return String(format: self._AttachmentMenu_SendGif_one, "\(value)")
            case .two:
                return String(format: self._AttachmentMenu_SendGif_two, "\(value)")
            case .few:
                return String(format: self._AttachmentMenu_SendGif_few, "\(value)")
            case .many:
                return String(format: self._AttachmentMenu_SendGif_many, "\(value)")
            case .other:
                return String(format: self._AttachmentMenu_SendGif_other, "\(value)")
        }
    }
    private let _MessageTimer_ShortWeeks_zero: String
    private let _MessageTimer_ShortWeeks_one: String
    private let _MessageTimer_ShortWeeks_two: String
    private let _MessageTimer_ShortWeeks_few: String
    private let _MessageTimer_ShortWeeks_many: String
    private let _MessageTimer_ShortWeeks_other: String
    public func MessageTimer_ShortWeeks(_ value: Int32) -> String {
        switch presentationStringsPluralizationForm(self.lc, value) {
            case .zero:
                return String(format: self._MessageTimer_ShortWeeks_zero, "\(value)")
            case .one:
                return String(format: self._MessageTimer_ShortWeeks_one, "\(value)")
            case .two:
                return String(format: self._MessageTimer_ShortWeeks_two, "\(value)")
            case .few:
                return String(format: self._MessageTimer_ShortWeeks_few, "\(value)")
            case .many:
                return String(format: self._MessageTimer_ShortWeeks_many, "\(value)")
            case .other:
                return String(format: self._MessageTimer_ShortWeeks_other, "\(value)")
        }
    }
    private let _LiveLocationUpdated_MinutesAgo_zero: String
    private let _LiveLocationUpdated_MinutesAgo_one: String
    private let _LiveLocationUpdated_MinutesAgo_two: String
    private let _LiveLocationUpdated_MinutesAgo_few: String
    private let _LiveLocationUpdated_MinutesAgo_many: String
    private let _LiveLocationUpdated_MinutesAgo_other: String
    public func LiveLocationUpdated_MinutesAgo(_ value: Int32) -> String {
        switch presentationStringsPluralizationForm(self.lc, value) {
            case .zero:
                return String(format: self._LiveLocationUpdated_MinutesAgo_zero, "\(value)")
            case .one:
                return String(format: self._LiveLocationUpdated_MinutesAgo_one, "\(value)")
            case .two:
                return String(format: self._LiveLocationUpdated_MinutesAgo_two, "\(value)")
            case .few:
                return String(format: self._LiveLocationUpdated_MinutesAgo_few, "\(value)")
            case .many:
                return String(format: self._LiveLocationUpdated_MinutesAgo_many, "\(value)")
            case .other:
                return String(format: self._LiveLocationUpdated_MinutesAgo_other, "\(value)")
        }
    }
    private let _Media_SharePhoto_zero: String
    private let _Media_SharePhoto_one: String
    private let _Media_SharePhoto_two: String
    private let _Media_SharePhoto_few: String
    private let _Media_SharePhoto_many: String
    private let _Media_SharePhoto_other: String
    public func Media_SharePhoto(_ value: Int32) -> String {
        switch presentationStringsPluralizationForm(self.lc, value) {
            case .zero:
                return String(format: self._Media_SharePhoto_zero, "\(value)")
            case .one:
                return String(format: self._Media_SharePhoto_one, "\(value)")
            case .two:
                return String(format: self._Media_SharePhoto_two, "\(value)")
            case .few:
                return String(format: self._Media_SharePhoto_few, "\(value)")
            case .many:
                return String(format: self._Media_SharePhoto_many, "\(value)")
            case .other:
                return String(format: self._Media_SharePhoto_other, "\(value)")
        }
    }
    private let _Invitation_Members_zero: String
    private let _Invitation_Members_one: String
    private let _Invitation_Members_two: String
    private let _Invitation_Members_few: String
    private let _Invitation_Members_many: String
    private let _Invitation_Members_other: String
    public func Invitation_Members(_ value: Int32) -> String {
        switch presentationStringsPluralizationForm(self.lc, value) {
            case .zero:
                return String(format: self._Invitation_Members_zero, "\(value)")
            case .one:
                return String(format: self._Invitation_Members_one, "\(value)")
            case .two:
                return String(format: self._Invitation_Members_two, "\(value)")
            case .few:
                return String(format: self._Invitation_Members_few, "\(value)")
            case .many:
                return String(format: self._Invitation_Members_many, "\(value)")
            case .other:
                return String(format: self._Invitation_Members_other, "\(value)")
        }
    }
    private let _Notification_GameScoreSelfExtended_zero: String
    private let _Notification_GameScoreSelfExtended_one: String
    private let _Notification_GameScoreSelfExtended_two: String
    private let _Notification_GameScoreSelfExtended_few: String
    private let _Notification_GameScoreSelfExtended_many: String
    private let _Notification_GameScoreSelfExtended_other: String
    public func Notification_GameScoreSelfExtended(_ value: Int32) -> String {
        switch presentationStringsPluralizationForm(self.lc, value) {
            case .zero:
                return String(format: self._Notification_GameScoreSelfExtended_zero, "\(value)")
            case .one:
                return String(format: self._Notification_GameScoreSelfExtended_one, "\(value)")
            case .two:
                return String(format: self._Notification_GameScoreSelfExtended_two, "\(value)")
            case .few:
                return String(format: self._Notification_GameScoreSelfExtended_few, "\(value)")
            case .many:
                return String(format: self._Notification_GameScoreSelfExtended_many, "\(value)")
            case .other:
                return String(format: self._Notification_GameScoreSelfExtended_other, "\(value)")
        }
    }
    private let _MessageTimer_Seconds_zero: String
    private let _MessageTimer_Seconds_one: String
    private let _MessageTimer_Seconds_two: String
    private let _MessageTimer_Seconds_few: String
    private let _MessageTimer_Seconds_many: String
    private let _MessageTimer_Seconds_other: String
    public func MessageTimer_Seconds(_ value: Int32) -> String {
        switch presentationStringsPluralizationForm(self.lc, value) {
            case .zero:
                return String(format: self._MessageTimer_Seconds_zero, "\(value)")
            case .one:
                return String(format: self._MessageTimer_Seconds_one, "\(value)")
            case .two:
                return String(format: self._MessageTimer_Seconds_two, "\(value)")
            case .few:
                return String(format: self._MessageTimer_Seconds_few, "\(value)")
            case .many:
                return String(format: self._MessageTimer_Seconds_many, "\(value)")
            case .other:
                return String(format: self._MessageTimer_Seconds_other, "\(value)")
        }
    }
    private let _MuteExpires_Hours_zero: String
    private let _MuteExpires_Hours_one: String
    private let _MuteExpires_Hours_two: String
    private let _MuteExpires_Hours_few: String
    private let _MuteExpires_Hours_many: String
    private let _MuteExpires_Hours_other: String
    public func MuteExpires_Hours(_ value: Int32) -> String {
        switch presentationStringsPluralizationForm(self.lc, value) {
            case .zero:
                return String(format: self._MuteExpires_Hours_zero, "\(value)")
            case .one:
                return String(format: self._MuteExpires_Hours_one, "\(value)")
            case .two:
                return String(format: self._MuteExpires_Hours_two, "\(value)")
            case .few:
                return String(format: self._MuteExpires_Hours_few, "\(value)")
            case .many:
                return String(format: self._MuteExpires_Hours_many, "\(value)")
            case .other:
                return String(format: self._MuteExpires_Hours_other, "\(value)")
        }
    }
    private let _AttachmentMenu_SendVideo_zero: String
    private let _AttachmentMenu_SendVideo_one: String
    private let _AttachmentMenu_SendVideo_two: String
    private let _AttachmentMenu_SendVideo_few: String
    private let _AttachmentMenu_SendVideo_many: String
    private let _AttachmentMenu_SendVideo_other: String
    public func AttachmentMenu_SendVideo(_ value: Int32) -> String {
        switch presentationStringsPluralizationForm(self.lc, value) {
            case .zero:
                return String(format: self._AttachmentMenu_SendVideo_zero, "\(value)")
            case .one:
                return String(format: self._AttachmentMenu_SendVideo_one, "\(value)")
            case .two:
                return String(format: self._AttachmentMenu_SendVideo_two, "\(value)")
            case .few:
                return String(format: self._AttachmentMenu_SendVideo_few, "\(value)")
            case .many:
                return String(format: self._AttachmentMenu_SendVideo_many, "\(value)")
            case .other:
                return String(format: self._AttachmentMenu_SendVideo_other, "\(value)")
        }
    }
    private let _MessageTimer_Hours_zero: String
    private let _MessageTimer_Hours_one: String
    private let _MessageTimer_Hours_two: String
    private let _MessageTimer_Hours_few: String
    private let _MessageTimer_Hours_many: String
    private let _MessageTimer_Hours_other: String
    public func MessageTimer_Hours(_ value: Int32) -> String {
        switch presentationStringsPluralizationForm(self.lc, value) {
            case .zero:
                return String(format: self._MessageTimer_Hours_zero, "\(value)")
            case .one:
                return String(format: self._MessageTimer_Hours_one, "\(value)")
            case .two:
                return String(format: self._MessageTimer_Hours_two, "\(value)")
            case .few:
                return String(format: self._MessageTimer_Hours_few, "\(value)")
            case .many:
                return String(format: self._MessageTimer_Hours_many, "\(value)")
            case .other:
                return String(format: self._MessageTimer_Hours_other, "\(value)")
        }
    }
    private let _Watch_UserInfo_Mute_zero: String
    private let _Watch_UserInfo_Mute_one: String
    private let _Watch_UserInfo_Mute_two: String
    private let _Watch_UserInfo_Mute_few: String
    private let _Watch_UserInfo_Mute_many: String
    private let _Watch_UserInfo_Mute_other: String
    public func Watch_UserInfo_Mute(_ value: Int32) -> String {
        switch presentationStringsPluralizationForm(self.lc, value) {
            case .zero:
                return String(format: self._Watch_UserInfo_Mute_zero, "\(value)")
            case .one:
                return String(format: self._Watch_UserInfo_Mute_one, "\(value)")
            case .two:
                return String(format: self._Watch_UserInfo_Mute_two, "\(value)")
            case .few:
                return String(format: self._Watch_UserInfo_Mute_few, "\(value)")
            case .many:
                return String(format: self._Watch_UserInfo_Mute_many, "\(value)")
            case .other:
                return String(format: self._Watch_UserInfo_Mute_other, "\(value)")
        }
    }
    private let _ServiceMessage_GameScoreSelfSimple_zero: String
    private let _ServiceMessage_GameScoreSelfSimple_one: String
    private let _ServiceMessage_GameScoreSelfSimple_two: String
    private let _ServiceMessage_GameScoreSelfSimple_few: String
    private let _ServiceMessage_GameScoreSelfSimple_many: String
    private let _ServiceMessage_GameScoreSelfSimple_other: String
    public func ServiceMessage_GameScoreSelfSimple(_ value: Int32) -> String {
        switch presentationStringsPluralizationForm(self.lc, value) {
            case .zero:
                return String(format: self._ServiceMessage_GameScoreSelfSimple_zero, "\(value)")
            case .one:
                return String(format: self._ServiceMessage_GameScoreSelfSimple_one, "\(value)")
            case .two:
                return String(format: self._ServiceMessage_GameScoreSelfSimple_two, "\(value)")
            case .few:
                return String(format: self._ServiceMessage_GameScoreSelfSimple_few, "\(value)")
            case .many:
                return String(format: self._ServiceMessage_GameScoreSelfSimple_many, "\(value)")
            case .other:
                return String(format: self._ServiceMessage_GameScoreSelfSimple_other, "\(value)")
        }
    }
    private let _ForwardedGifs_zero: String
    private let _ForwardedGifs_one: String
    private let _ForwardedGifs_two: String
    private let _ForwardedGifs_few: String
    private let _ForwardedGifs_many: String
    private let _ForwardedGifs_other: String
    public func ForwardedGifs(_ value: Int32) -> String {
        switch presentationStringsPluralizationForm(self.lc, value) {
            case .zero:
                return String(format: self._ForwardedGifs_zero, "\(value)")
            case .one:
                return String(format: self._ForwardedGifs_one, "\(value)")
            case .two:
                return String(format: self._ForwardedGifs_two, "\(value)")
            case .few:
                return String(format: self._ForwardedGifs_few, "\(value)")
            case .many:
                return String(format: self._ForwardedGifs_many, "\(value)")
            case .other:
                return String(format: self._ForwardedGifs_other, "\(value)")
        }
    }
    private let _MessageTimer_ShortDays_zero: String
    private let _MessageTimer_ShortDays_one: String
    private let _MessageTimer_ShortDays_two: String
    private let _MessageTimer_ShortDays_few: String
    private let _MessageTimer_ShortDays_many: String
    private let _MessageTimer_ShortDays_other: String
    public func MessageTimer_ShortDays(_ value: Int32) -> String {
        switch presentationStringsPluralizationForm(self.lc, value) {
            case .zero:
                return String(format: self._MessageTimer_ShortDays_zero, "\(value)")
            case .one:
                return String(format: self._MessageTimer_ShortDays_one, "\(value)")
            case .two:
                return String(format: self._MessageTimer_ShortDays_two, "\(value)")
            case .few:
                return String(format: self._MessageTimer_ShortDays_few, "\(value)")
            case .many:
                return String(format: self._MessageTimer_ShortDays_many, "\(value)")
            case .other:
                return String(format: self._MessageTimer_ShortDays_other, "\(value)")
        }
    }
    private let _ForwardedStickers_zero: String
    private let _ForwardedStickers_one: String
    private let _ForwardedStickers_two: String
    private let _ForwardedStickers_few: String
    private let _ForwardedStickers_many: String
    private let _ForwardedStickers_other: String
    public func ForwardedStickers(_ value: Int32) -> String {
        switch presentationStringsPluralizationForm(self.lc, value) {
            case .zero:
                return String(format: self._ForwardedStickers_zero, "\(value)")
            case .one:
                return String(format: self._ForwardedStickers_one, "\(value)")
            case .two:
                return String(format: self._ForwardedStickers_two, "\(value)")
            case .few:
                return String(format: self._ForwardedStickers_few, "\(value)")
            case .many:
                return String(format: self._ForwardedStickers_many, "\(value)")
            case .other:
                return String(format: self._ForwardedStickers_other, "\(value)")
        }
    }
    private let _StickerPack_RemoveStickerCount_zero: String
    private let _StickerPack_RemoveStickerCount_one: String
    private let _StickerPack_RemoveStickerCount_two: String
    private let _StickerPack_RemoveStickerCount_few: String
    private let _StickerPack_RemoveStickerCount_many: String
    private let _StickerPack_RemoveStickerCount_other: String
    public func StickerPack_RemoveStickerCount(_ value: Int32) -> String {
        switch presentationStringsPluralizationForm(self.lc, value) {
            case .zero:
                return String(format: self._StickerPack_RemoveStickerCount_zero, "\(value)")
            case .one:
                return String(format: self._StickerPack_RemoveStickerCount_one, "\(value)")
            case .two:
                return String(format: self._StickerPack_RemoveStickerCount_two, "\(value)")
            case .few:
                return String(format: self._StickerPack_RemoveStickerCount_few, "\(value)")
            case .many:
                return String(format: self._StickerPack_RemoveStickerCount_many, "\(value)")
            case .other:
                return String(format: self._StickerPack_RemoveStickerCount_other, "\(value)")
        }
    }
    private let _MuteExpires_Minutes_zero: String
    private let _MuteExpires_Minutes_one: String
    private let _MuteExpires_Minutes_two: String
    private let _MuteExpires_Minutes_few: String
    private let _MuteExpires_Minutes_many: String
    private let _MuteExpires_Minutes_other: String
    public func MuteExpires_Minutes(_ value: Int32) -> String {
        switch presentationStringsPluralizationForm(self.lc, value) {
            case .zero:
                return String(format: self._MuteExpires_Minutes_zero, "\(value)")
            case .one:
                return String(format: self._MuteExpires_Minutes_one, "\(value)")
            case .two:
                return String(format: self._MuteExpires_Minutes_two, "\(value)")
            case .few:
                return String(format: self._MuteExpires_Minutes_few, "\(value)")
            case .many:
                return String(format: self._MuteExpires_Minutes_many, "\(value)")
            case .other:
                return String(format: self._MuteExpires_Minutes_other, "\(value)")
        }
    }
    private let _AttachmentMenu_SendItem_zero: String
    private let _AttachmentMenu_SendItem_one: String
    private let _AttachmentMenu_SendItem_two: String
    private let _AttachmentMenu_SendItem_few: String
    private let _AttachmentMenu_SendItem_many: String
    private let _AttachmentMenu_SendItem_other: String
    public func AttachmentMenu_SendItem(_ value: Int32) -> String {
        switch presentationStringsPluralizationForm(self.lc, value) {
            case .zero:
                return String(format: self._AttachmentMenu_SendItem_zero, "\(value)")
            case .one:
                return String(format: self._AttachmentMenu_SendItem_one, "\(value)")
            case .two:
                return String(format: self._AttachmentMenu_SendItem_two, "\(value)")
            case .few:
                return String(format: self._AttachmentMenu_SendItem_few, "\(value)")
            case .many:
                return String(format: self._AttachmentMenu_SendItem_many, "\(value)")
            case .other:
                return String(format: self._AttachmentMenu_SendItem_other, "\(value)")
        }
    }
    private let _MuteExpires_Days_zero: String
    private let _MuteExpires_Days_one: String
    private let _MuteExpires_Days_two: String
    private let _MuteExpires_Days_few: String
    private let _MuteExpires_Days_many: String
    private let _MuteExpires_Days_other: String
    public func MuteExpires_Days(_ value: Int32) -> String {
        switch presentationStringsPluralizationForm(self.lc, value) {
            case .zero:
                return String(format: self._MuteExpires_Days_zero, "\(value)")
            case .one:
                return String(format: self._MuteExpires_Days_one, "\(value)")
            case .two:
                return String(format: self._MuteExpires_Days_two, "\(value)")
            case .few:
                return String(format: self._MuteExpires_Days_few, "\(value)")
            case .many:
                return String(format: self._MuteExpires_Days_many, "\(value)")
            case .other:
                return String(format: self._MuteExpires_Days_other, "\(value)")
        }
    }
    private let _StickerPack_RemoveMaskCount_zero: String
    private let _StickerPack_RemoveMaskCount_one: String
    private let _StickerPack_RemoveMaskCount_two: String
    private let _StickerPack_RemoveMaskCount_few: String
    private let _StickerPack_RemoveMaskCount_many: String
    private let _StickerPack_RemoveMaskCount_other: String
    public func StickerPack_RemoveMaskCount(_ value: Int32) -> String {
        switch presentationStringsPluralizationForm(self.lc, value) {
            case .zero:
                return String(format: self._StickerPack_RemoveMaskCount_zero, "\(value)")
            case .one:
                return String(format: self._StickerPack_RemoveMaskCount_one, "\(value)")
            case .two:
                return String(format: self._StickerPack_RemoveMaskCount_two, "\(value)")
            case .few:
                return String(format: self._StickerPack_RemoveMaskCount_few, "\(value)")
            case .many:
                return String(format: self._StickerPack_RemoveMaskCount_many, "\(value)")
            case .other:
                return String(format: self._StickerPack_RemoveMaskCount_other, "\(value)")
        }
    }
    private let _Watch_LastSeen_MinutesAgo_zero: String
    private let _Watch_LastSeen_MinutesAgo_one: String
    private let _Watch_LastSeen_MinutesAgo_two: String
    private let _Watch_LastSeen_MinutesAgo_few: String
    private let _Watch_LastSeen_MinutesAgo_many: String
    private let _Watch_LastSeen_MinutesAgo_other: String
    public func Watch_LastSeen_MinutesAgo(_ value: Int32) -> String {
        switch presentationStringsPluralizationForm(self.lc, value) {
            case .zero:
                return String(format: self._Watch_LastSeen_MinutesAgo_zero, "\(value)")
            case .one:
                return String(format: self._Watch_LastSeen_MinutesAgo_one, "\(value)")
            case .two:
                return String(format: self._Watch_LastSeen_MinutesAgo_two, "\(value)")
            case .few:
                return String(format: self._Watch_LastSeen_MinutesAgo_few, "\(value)")
            case .many:
                return String(format: self._Watch_LastSeen_MinutesAgo_many, "\(value)")
            case .other:
                return String(format: self._Watch_LastSeen_MinutesAgo_other, "\(value)")
        }
    }
    private let _Notification_GameScoreSelfSimple_zero: String
    private let _Notification_GameScoreSelfSimple_one: String
    private let _Notification_GameScoreSelfSimple_two: String
    private let _Notification_GameScoreSelfSimple_few: String
    private let _Notification_GameScoreSelfSimple_many: String
    private let _Notification_GameScoreSelfSimple_other: String
    public func Notification_GameScoreSelfSimple(_ value: Int32) -> String {
        switch presentationStringsPluralizationForm(self.lc, value) {
            case .zero:
                return String(format: self._Notification_GameScoreSelfSimple_zero, "\(value)")
            case .one:
                return String(format: self._Notification_GameScoreSelfSimple_one, "\(value)")
            case .two:
                return String(format: self._Notification_GameScoreSelfSimple_two, "\(value)")
            case .few:
                return String(format: self._Notification_GameScoreSelfSimple_few, "\(value)")
            case .many:
                return String(format: self._Notification_GameScoreSelfSimple_many, "\(value)")
            case .other:
                return String(format: self._Notification_GameScoreSelfSimple_other, "\(value)")
        }
    }
    private let _SharedMedia_File_zero: String
    private let _SharedMedia_File_one: String
    private let _SharedMedia_File_two: String
    private let _SharedMedia_File_few: String
    private let _SharedMedia_File_many: String
    private let _SharedMedia_File_other: String
    public func SharedMedia_File(_ value: Int32) -> String {
        switch presentationStringsPluralizationForm(self.lc, value) {
            case .zero:
                return String(format: self._SharedMedia_File_zero, "\(value)")
            case .one:
                return String(format: self._SharedMedia_File_one, "\(value)")
            case .two:
                return String(format: self._SharedMedia_File_two, "\(value)")
            case .few:
                return String(format: self._SharedMedia_File_few, "\(value)")
            case .many:
                return String(format: self._SharedMedia_File_many, "\(value)")
            case .other:
                return String(format: self._SharedMedia_File_other, "\(value)")
        }
    }
    private let _Conversation_StatusOnline_zero: String
    private let _Conversation_StatusOnline_one: String
    private let _Conversation_StatusOnline_two: String
    private let _Conversation_StatusOnline_few: String
    private let _Conversation_StatusOnline_many: String
    private let _Conversation_StatusOnline_other: String
    public func Conversation_StatusOnline(_ value: Int32) -> String {
        switch presentationStringsPluralizationForm(self.lc, value) {
            case .zero:
                return String(format: self._Conversation_StatusOnline_zero, "\(value)")
            case .one:
                return String(format: self._Conversation_StatusOnline_one, "\(value)")
            case .two:
                return String(format: self._Conversation_StatusOnline_two, "\(value)")
            case .few:
                return String(format: self._Conversation_StatusOnline_few, "\(value)")
            case .many:
                return String(format: self._Conversation_StatusOnline_many, "\(value)")
            case .other:
                return String(format: self._Conversation_StatusOnline_other, "\(value)")
        }
    }
    private let _ForwardedVideoMessages_zero: String
    private let _ForwardedVideoMessages_one: String
    private let _ForwardedVideoMessages_two: String
    private let _ForwardedVideoMessages_few: String
    private let _ForwardedVideoMessages_many: String
    private let _ForwardedVideoMessages_other: String
    public func ForwardedVideoMessages(_ value: Int32) -> String {
        switch presentationStringsPluralizationForm(self.lc, value) {
            case .zero:
                return String(format: self._ForwardedVideoMessages_zero, "\(value)")
            case .one:
                return String(format: self._ForwardedVideoMessages_one, "\(value)")
            case .two:
                return String(format: self._ForwardedVideoMessages_two, "\(value)")
            case .few:
                return String(format: self._ForwardedVideoMessages_few, "\(value)")
            case .many:
                return String(format: self._ForwardedVideoMessages_many, "\(value)")
            case .other:
                return String(format: self._ForwardedVideoMessages_other, "\(value)")
        }
    }
    private let _MuteFor_Hours_zero: String
    private let _MuteFor_Hours_one: String
    private let _MuteFor_Hours_two: String
    private let _MuteFor_Hours_few: String
    private let _MuteFor_Hours_many: String
    private let _MuteFor_Hours_other: String
    public func MuteFor_Hours(_ value: Int32) -> String {
        switch presentationStringsPluralizationForm(self.lc, value) {
            case .zero:
                return String(format: self._MuteFor_Hours_zero, "\(value)")
            case .one:
                return String(format: self._MuteFor_Hours_one, "\(value)")
            case .two:
                return String(format: self._MuteFor_Hours_two, "\(value)")
            case .few:
                return String(format: self._MuteFor_Hours_few, "\(value)")
            case .many:
                return String(format: self._MuteFor_Hours_many, "\(value)")
            case .other:
                return String(format: self._MuteFor_Hours_other, "\(value)")
        }
    }
    private let _ForwardedContacts_zero: String
    private let _ForwardedContacts_one: String
    private let _ForwardedContacts_two: String
    private let _ForwardedContacts_few: String
    private let _ForwardedContacts_many: String
    private let _ForwardedContacts_other: String
    public func ForwardedContacts(_ value: Int32) -> String {
        switch presentationStringsPluralizationForm(self.lc, value) {
            case .zero:
                return String(format: self._ForwardedContacts_zero, "\(value)")
            case .one:
                return String(format: self._ForwardedContacts_one, "\(value)")
            case .two:
                return String(format: self._ForwardedContacts_two, "\(value)")
            case .few:
                return String(format: self._ForwardedContacts_few, "\(value)")
            case .many:
                return String(format: self._ForwardedContacts_many, "\(value)")
            case .other:
                return String(format: self._ForwardedContacts_other, "\(value)")
        }
    }
    private let _GroupInfo_ParticipantCount_zero: String
    private let _GroupInfo_ParticipantCount_one: String
    private let _GroupInfo_ParticipantCount_two: String
    private let _GroupInfo_ParticipantCount_few: String
    private let _GroupInfo_ParticipantCount_many: String
    private let _GroupInfo_ParticipantCount_other: String
    public func GroupInfo_ParticipantCount(_ value: Int32) -> String {
        switch presentationStringsPluralizationForm(self.lc, value) {
            case .zero:
                return String(format: self._GroupInfo_ParticipantCount_zero, "\(value)")
            case .one:
                return String(format: self._GroupInfo_ParticipantCount_one, "\(value)")
            case .two:
                return String(format: self._GroupInfo_ParticipantCount_two, "\(value)")
            case .few:
                return String(format: self._GroupInfo_ParticipantCount_few, "\(value)")
            case .many:
                return String(format: self._GroupInfo_ParticipantCount_many, "\(value)")
            case .other:
                return String(format: self._GroupInfo_ParticipantCount_other, "\(value)")
        }
    }
    private let _LastSeen_HoursAgo_zero: String
    private let _LastSeen_HoursAgo_one: String
    private let _LastSeen_HoursAgo_two: String
    private let _LastSeen_HoursAgo_few: String
    private let _LastSeen_HoursAgo_many: String
    private let _LastSeen_HoursAgo_other: String
    public func LastSeen_HoursAgo(_ value: Int32) -> String {
        switch presentationStringsPluralizationForm(self.lc, value) {
            case .zero:
                return String(format: self._LastSeen_HoursAgo_zero, "\(value)")
            case .one:
                return String(format: self._LastSeen_HoursAgo_one, "\(value)")
            case .two:
                return String(format: self._LastSeen_HoursAgo_two, "\(value)")
            case .few:
                return String(format: self._LastSeen_HoursAgo_few, "\(value)")
            case .many:
                return String(format: self._LastSeen_HoursAgo_many, "\(value)")
            case .other:
                return String(format: self._LastSeen_HoursAgo_other, "\(value)")
        }
    }
    private let _SharedMedia_Link_zero: String
    private let _SharedMedia_Link_one: String
    private let _SharedMedia_Link_two: String
    private let _SharedMedia_Link_few: String
    private let _SharedMedia_Link_many: String
    private let _SharedMedia_Link_other: String
    public func SharedMedia_Link(_ value: Int32) -> String {
        switch presentationStringsPluralizationForm(self.lc, value) {
            case .zero:
                return String(format: self._SharedMedia_Link_zero, "\(value)")
            case .one:
                return String(format: self._SharedMedia_Link_one, "\(value)")
            case .two:
                return String(format: self._SharedMedia_Link_two, "\(value)")
            case .few:
                return String(format: self._SharedMedia_Link_few, "\(value)")
            case .many:
                return String(format: self._SharedMedia_Link_many, "\(value)")
            case .other:
                return String(format: self._SharedMedia_Link_other, "\(value)")
        }
    }
    private let _ServiceMessage_GameScoreExtended_zero: String
    private let _ServiceMessage_GameScoreExtended_one: String
    private let _ServiceMessage_GameScoreExtended_two: String
    private let _ServiceMessage_GameScoreExtended_few: String
    private let _ServiceMessage_GameScoreExtended_many: String
    private let _ServiceMessage_GameScoreExtended_other: String
    public func ServiceMessage_GameScoreExtended(_ value: Int32) -> String {
        switch presentationStringsPluralizationForm(self.lc, value) {
            case .zero:
                return String(format: self._ServiceMessage_GameScoreExtended_zero, "\(value)")
            case .one:
                return String(format: self._ServiceMessage_GameScoreExtended_one, "\(value)")
            case .two:
                return String(format: self._ServiceMessage_GameScoreExtended_two, "\(value)")
            case .few:
                return String(format: self._ServiceMessage_GameScoreExtended_few, "\(value)")
            case .many:
                return String(format: self._ServiceMessage_GameScoreExtended_many, "\(value)")
            case .other:
                return String(format: self._ServiceMessage_GameScoreExtended_other, "\(value)")
        }
    }
    private let _Map_ETAMinutes_zero: String
    private let _Map_ETAMinutes_one: String
    private let _Map_ETAMinutes_two: String
    private let _Map_ETAMinutes_few: String
    private let _Map_ETAMinutes_many: String
    private let _Map_ETAMinutes_other: String
    public func Map_ETAMinutes(_ value: Int32) -> String {
        switch presentationStringsPluralizationForm(self.lc, value) {
            case .zero:
                return String(format: self._Map_ETAMinutes_zero, "\(value)")
            case .one:
                return String(format: self._Map_ETAMinutes_one, "\(value)")
            case .two:
                return String(format: self._Map_ETAMinutes_two, "\(value)")
            case .few:
                return String(format: self._Map_ETAMinutes_few, "\(value)")
            case .many:
                return String(format: self._Map_ETAMinutes_many, "\(value)")
            case .other:
                return String(format: self._Map_ETAMinutes_other, "\(value)")
        }
    }
    private let _MessageTimer_Months_zero: String
    private let _MessageTimer_Months_one: String
    private let _MessageTimer_Months_two: String
    private let _MessageTimer_Months_few: String
    private let _MessageTimer_Months_many: String
    private let _MessageTimer_Months_other: String
    public func MessageTimer_Months(_ value: Int32) -> String {
        switch presentationStringsPluralizationForm(self.lc, value) {
            case .zero:
                return String(format: self._MessageTimer_Months_zero, "\(value)")
            case .one:
                return String(format: self._MessageTimer_Months_one, "\(value)")
            case .two:
                return String(format: self._MessageTimer_Months_two, "\(value)")
            case .few:
                return String(format: self._MessageTimer_Months_few, "\(value)")
            case .many:
                return String(format: self._MessageTimer_Months_many, "\(value)")
            case .other:
                return String(format: self._MessageTimer_Months_other, "\(value)")
        }
    }
    private let _UserCount_zero: String
    private let _UserCount_one: String
    private let _UserCount_two: String
    private let _UserCount_few: String
    private let _UserCount_many: String
    private let _UserCount_other: String
    public func UserCount(_ value: Int32) -> String {
        switch presentationStringsPluralizationForm(self.lc, value) {
            case .zero:
                return String(format: self._UserCount_zero, "\(value)")
            case .one:
                return String(format: self._UserCount_one, "\(value)")
            case .two:
                return String(format: self._UserCount_two, "\(value)")
            case .few:
                return String(format: self._UserCount_few, "\(value)")
            case .many:
                return String(format: self._UserCount_many, "\(value)")
            case .other:
                return String(format: self._UserCount_other, "\(value)")
        }
    }
    private let _Watch_LastSeen_HoursAgo_zero: String
    private let _Watch_LastSeen_HoursAgo_one: String
    private let _Watch_LastSeen_HoursAgo_two: String
    private let _Watch_LastSeen_HoursAgo_few: String
    private let _Watch_LastSeen_HoursAgo_many: String
    private let _Watch_LastSeen_HoursAgo_other: String
    public func Watch_LastSeen_HoursAgo(_ value: Int32) -> String {
        switch presentationStringsPluralizationForm(self.lc, value) {
            case .zero:
                return String(format: self._Watch_LastSeen_HoursAgo_zero, "\(value)")
            case .one:
                return String(format: self._Watch_LastSeen_HoursAgo_one, "\(value)")
            case .two:
                return String(format: self._Watch_LastSeen_HoursAgo_two, "\(value)")
            case .few:
                return String(format: self._Watch_LastSeen_HoursAgo_few, "\(value)")
            case .many:
                return String(format: self._Watch_LastSeen_HoursAgo_many, "\(value)")
            case .other:
                return String(format: self._Watch_LastSeen_HoursAgo_other, "\(value)")
        }
    }
    private let _StickerPack_StickerCount_zero: String
    private let _StickerPack_StickerCount_one: String
    private let _StickerPack_StickerCount_two: String
    private let _StickerPack_StickerCount_few: String
    private let _StickerPack_StickerCount_many: String
    private let _StickerPack_StickerCount_other: String
    public func StickerPack_StickerCount(_ value: Int32) -> String {
        switch presentationStringsPluralizationForm(self.lc, value) {
            case .zero:
                return String(format: self._StickerPack_StickerCount_zero, "\(value)")
            case .one:
                return String(format: self._StickerPack_StickerCount_one, "\(value)")
            case .two:
                return String(format: self._StickerPack_StickerCount_two, "\(value)")
            case .few:
                return String(format: self._StickerPack_StickerCount_few, "\(value)")
            case .many:
                return String(format: self._StickerPack_StickerCount_many, "\(value)")
            case .other:
                return String(format: self._StickerPack_StickerCount_other, "\(value)")
        }
    }
    private let _Conversation_StatusSubscribers_zero: String
    private let _Conversation_StatusSubscribers_one: String
    private let _Conversation_StatusSubscribers_two: String
    private let _Conversation_StatusSubscribers_few: String
    private let _Conversation_StatusSubscribers_many: String
    private let _Conversation_StatusSubscribers_other: String
    public func Conversation_StatusSubscribers(_ value: Int32) -> String {
        switch presentationStringsPluralizationForm(self.lc, value) {
            case .zero:
                return String(format: self._Conversation_StatusSubscribers_zero, "\(value)")
            case .one:
                return String(format: self._Conversation_StatusSubscribers_one, "\(value)")
            case .two:
                return String(format: self._Conversation_StatusSubscribers_two, "\(value)")
            case .few:
                return String(format: self._Conversation_StatusSubscribers_few, "\(value)")
            case .many:
                return String(format: self._Conversation_StatusSubscribers_many, "\(value)")
            case .other:
                return String(format: self._Conversation_StatusSubscribers_other, "\(value)")
        }
    }
    private let _PrivacyLastSeenSettings_AddUsers_zero: String
    private let _PrivacyLastSeenSettings_AddUsers_one: String
    private let _PrivacyLastSeenSettings_AddUsers_two: String
    private let _PrivacyLastSeenSettings_AddUsers_few: String
    private let _PrivacyLastSeenSettings_AddUsers_many: String
    private let _PrivacyLastSeenSettings_AddUsers_other: String
    public func PrivacyLastSeenSettings_AddUsers(_ value: Int32) -> String {
        switch presentationStringsPluralizationForm(self.lc, value) {
            case .zero:
                return String(format: self._PrivacyLastSeenSettings_AddUsers_zero, "\(value)")
            case .one:
                return String(format: self._PrivacyLastSeenSettings_AddUsers_one, "\(value)")
            case .two:
                return String(format: self._PrivacyLastSeenSettings_AddUsers_two, "\(value)")
            case .few:
                return String(format: self._PrivacyLastSeenSettings_AddUsers_few, "\(value)")
            case .many:
                return String(format: self._PrivacyLastSeenSettings_AddUsers_many, "\(value)")
            case .other:
                return String(format: self._PrivacyLastSeenSettings_AddUsers_other, "\(value)")
        }
    }
    private let _Notification_GameScoreExtended_zero: String
    private let _Notification_GameScoreExtended_one: String
    private let _Notification_GameScoreExtended_two: String
    private let _Notification_GameScoreExtended_few: String
    private let _Notification_GameScoreExtended_many: String
    private let _Notification_GameScoreExtended_other: String
    public func Notification_GameScoreExtended(_ value: Int32) -> String {
        switch presentationStringsPluralizationForm(self.lc, value) {
            case .zero:
                return String(format: self._Notification_GameScoreExtended_zero, "\(value)")
            case .one:
                return String(format: self._Notification_GameScoreExtended_one, "\(value)")
            case .two:
                return String(format: self._Notification_GameScoreExtended_two, "\(value)")
            case .few:
                return String(format: self._Notification_GameScoreExtended_few, "\(value)")
            case .many:
                return String(format: self._Notification_GameScoreExtended_many, "\(value)")
            case .other:
                return String(format: self._Notification_GameScoreExtended_other, "\(value)")
        }
    }
    private let _Map_ETAHours_zero: String
    private let _Map_ETAHours_one: String
    private let _Map_ETAHours_two: String
    private let _Map_ETAHours_few: String
    private let _Map_ETAHours_many: String
    private let _Map_ETAHours_other: String
    public func Map_ETAHours(_ value: Int32) -> String {
        switch presentationStringsPluralizationForm(self.lc, value) {
            case .zero:
                return String(format: self._Map_ETAHours_zero, "\(value)")
            case .one:
                return String(format: self._Map_ETAHours_one, "\(value)")
            case .two:
                return String(format: self._Map_ETAHours_two, "\(value)")
            case .few:
                return String(format: self._Map_ETAHours_few, "\(value)")
            case .many:
                return String(format: self._Map_ETAHours_many, "\(value)")
            case .other:
                return String(format: self._Map_ETAHours_other, "\(value)")
        }
    }
    private let _Notifications_ExceptionMuteExpires_Minutes_zero: String
    private let _Notifications_ExceptionMuteExpires_Minutes_one: String
    private let _Notifications_ExceptionMuteExpires_Minutes_two: String
    private let _Notifications_ExceptionMuteExpires_Minutes_few: String
    private let _Notifications_ExceptionMuteExpires_Minutes_many: String
    private let _Notifications_ExceptionMuteExpires_Minutes_other: String
    public func Notifications_ExceptionMuteExpires_Minutes(_ value: Int32) -> String {
        switch presentationStringsPluralizationForm(self.lc, value) {
            case .zero:
                return String(format: self._Notifications_ExceptionMuteExpires_Minutes_zero, "\(value)")
            case .one:
                return String(format: self._Notifications_ExceptionMuteExpires_Minutes_one, "\(value)")
            case .two:
                return String(format: self._Notifications_ExceptionMuteExpires_Minutes_two, "\(value)")
            case .few:
                return String(format: self._Notifications_ExceptionMuteExpires_Minutes_few, "\(value)")
            case .many:
                return String(format: self._Notifications_ExceptionMuteExpires_Minutes_many, "\(value)")
            case .other:
                return String(format: self._Notifications_ExceptionMuteExpires_Minutes_other, "\(value)")
        }
    }
    private let _SharedMedia_Photo_zero: String
    private let _SharedMedia_Photo_one: String
    private let _SharedMedia_Photo_two: String
    private let _SharedMedia_Photo_few: String
    private let _SharedMedia_Photo_many: String
    private let _SharedMedia_Photo_other: String
    public func SharedMedia_Photo(_ value: Int32) -> String {
        switch presentationStringsPluralizationForm(self.lc, value) {
            case .zero:
                return String(format: self._SharedMedia_Photo_zero, "\(value)")
            case .one:
                return String(format: self._SharedMedia_Photo_one, "\(value)")
            case .two:
                return String(format: self._SharedMedia_Photo_two, "\(value)")
            case .few:
                return String(format: self._SharedMedia_Photo_few, "\(value)")
            case .many:
                return String(format: self._SharedMedia_Photo_many, "\(value)")
            case .other:
                return String(format: self._SharedMedia_Photo_other, "\(value)")
        }
    }
    private let _ForwardedVideos_zero: String
    private let _ForwardedVideos_one: String
    private let _ForwardedVideos_two: String
    private let _ForwardedVideos_few: String
    private let _ForwardedVideos_many: String
    private let _ForwardedVideos_other: String
    public func ForwardedVideos(_ value: Int32) -> String {
        switch presentationStringsPluralizationForm(self.lc, value) {
            case .zero:
                return String(format: self._ForwardedVideos_zero, "\(value)")
            case .one:
                return String(format: self._ForwardedVideos_one, "\(value)")
            case .two:
                return String(format: self._ForwardedVideos_two, "\(value)")
            case .few:
                return String(format: self._ForwardedVideos_few, "\(value)")
            case .many:
                return String(format: self._ForwardedVideos_many, "\(value)")
            case .other:
                return String(format: self._ForwardedVideos_other, "\(value)")
        }
    }
    private let _LiveLocation_MenuChatsCount_zero: String
    private let _LiveLocation_MenuChatsCount_one: String
    private let _LiveLocation_MenuChatsCount_two: String
    private let _LiveLocation_MenuChatsCount_few: String
    private let _LiveLocation_MenuChatsCount_many: String
    private let _LiveLocation_MenuChatsCount_other: String
    public func LiveLocation_MenuChatsCount(_ value: Int32) -> String {
        switch presentationStringsPluralizationForm(self.lc, value) {
            case .zero:
                return String(format: self._LiveLocation_MenuChatsCount_zero, "\(value)")
            case .one:
                return String(format: self._LiveLocation_MenuChatsCount_one, "\(value)")
            case .two:
                return String(format: self._LiveLocation_MenuChatsCount_two, "\(value)")
            case .few:
                return String(format: self._LiveLocation_MenuChatsCount_few, "\(value)")
            case .many:
                return String(format: self._LiveLocation_MenuChatsCount_many, "\(value)")
            case .other:
                return String(format: self._LiveLocation_MenuChatsCount_other, "\(value)")
        }
    }
    private let _PasscodeSettings_FailedAttempts_zero: String
    private let _PasscodeSettings_FailedAttempts_one: String
    private let _PasscodeSettings_FailedAttempts_two: String
    private let _PasscodeSettings_FailedAttempts_few: String
    private let _PasscodeSettings_FailedAttempts_many: String
    private let _PasscodeSettings_FailedAttempts_other: String
    public func PasscodeSettings_FailedAttempts(_ value: Int32) -> String {
        switch presentationStringsPluralizationForm(self.lc, value) {
            case .zero:
                return String(format: self._PasscodeSettings_FailedAttempts_zero, "\(value)")
            case .one:
                return String(format: self._PasscodeSettings_FailedAttempts_one, "\(value)")
            case .two:
                return String(format: self._PasscodeSettings_FailedAttempts_two, "\(value)")
            case .few:
                return String(format: self._PasscodeSettings_FailedAttempts_few, "\(value)")
            case .many:
                return String(format: self._PasscodeSettings_FailedAttempts_many, "\(value)")
            case .other:
                return String(format: self._PasscodeSettings_FailedAttempts_other, "\(value)")
        }
    }
    private let _QuickSend_Photos_zero: String
    private let _QuickSend_Photos_one: String
    private let _QuickSend_Photos_two: String
    private let _QuickSend_Photos_few: String
    private let _QuickSend_Photos_many: String
    private let _QuickSend_Photos_other: String
    public func QuickSend_Photos(_ value: Int32) -> String {
        switch presentationStringsPluralizationForm(self.lc, value) {
            case .zero:
                return String(format: self._QuickSend_Photos_zero, "\(value)")
            case .one:
                return String(format: self._QuickSend_Photos_one, "\(value)")
            case .two:
                return String(format: self._QuickSend_Photos_two, "\(value)")
            case .few:
                return String(format: self._QuickSend_Photos_few, "\(value)")
            case .many:
                return String(format: self._QuickSend_Photos_many, "\(value)")
            case .other:
                return String(format: self._QuickSend_Photos_other, "\(value)")
        }
    }
    private let _ServiceMessage_GameScoreSimple_zero: String
    private let _ServiceMessage_GameScoreSimple_one: String
    private let _ServiceMessage_GameScoreSimple_two: String
    private let _ServiceMessage_GameScoreSimple_few: String
    private let _ServiceMessage_GameScoreSimple_many: String
    private let _ServiceMessage_GameScoreSimple_other: String
    public func ServiceMessage_GameScoreSimple(_ value: Int32) -> String {
        switch presentationStringsPluralizationForm(self.lc, value) {
            case .zero:
                return String(format: self._ServiceMessage_GameScoreSimple_zero, "\(value)")
            case .one:
                return String(format: self._ServiceMessage_GameScoreSimple_one, "\(value)")
            case .two:
                return String(format: self._ServiceMessage_GameScoreSimple_two, "\(value)")
            case .few:
                return String(format: self._ServiceMessage_GameScoreSimple_few, "\(value)")
            case .many:
                return String(format: self._ServiceMessage_GameScoreSimple_many, "\(value)")
            case .other:
                return String(format: self._ServiceMessage_GameScoreSimple_other, "\(value)")
        }
    }
    private let _Notifications_ExceptionMuteExpires_Days_zero: String
    private let _Notifications_ExceptionMuteExpires_Days_one: String
    private let _Notifications_ExceptionMuteExpires_Days_two: String
    private let _Notifications_ExceptionMuteExpires_Days_few: String
    private let _Notifications_ExceptionMuteExpires_Days_many: String
    private let _Notifications_ExceptionMuteExpires_Days_other: String
    public func Notifications_ExceptionMuteExpires_Days(_ value: Int32) -> String {
        switch presentationStringsPluralizationForm(self.lc, value) {
            case .zero:
                return String(format: self._Notifications_ExceptionMuteExpires_Days_zero, "\(value)")
            case .one:
                return String(format: self._Notifications_ExceptionMuteExpires_Days_one, "\(value)")
            case .two:
                return String(format: self._Notifications_ExceptionMuteExpires_Days_two, "\(value)")
            case .few:
                return String(format: self._Notifications_ExceptionMuteExpires_Days_few, "\(value)")
            case .many:
                return String(format: self._Notifications_ExceptionMuteExpires_Days_many, "\(value)")
            case .other:
                return String(format: self._Notifications_ExceptionMuteExpires_Days_other, "\(value)")
        }
    }
    private let _Notifications_Exceptions_zero: String
    private let _Notifications_Exceptions_one: String
    private let _Notifications_Exceptions_two: String
    private let _Notifications_Exceptions_few: String
    private let _Notifications_Exceptions_many: String
    private let _Notifications_Exceptions_other: String
    public func Notifications_Exceptions(_ value: Int32) -> String {
        switch presentationStringsPluralizationForm(self.lc, value) {
            case .zero:
                return String(format: self._Notifications_Exceptions_zero, "\(value)")
            case .one:
                return String(format: self._Notifications_Exceptions_one, "\(value)")
            case .two:
                return String(format: self._Notifications_Exceptions_two, "\(value)")
            case .few:
                return String(format: self._Notifications_Exceptions_few, "\(value)")
            case .many:
                return String(format: self._Notifications_Exceptions_many, "\(value)")
            case .other:
                return String(format: self._Notifications_Exceptions_other, "\(value)")
        }
    }
    private let _MessageTimer_Weeks_zero: String
    private let _MessageTimer_Weeks_one: String
    private let _MessageTimer_Weeks_two: String
    private let _MessageTimer_Weeks_few: String
    private let _MessageTimer_Weeks_many: String
    private let _MessageTimer_Weeks_other: String
    public func MessageTimer_Weeks(_ value: Int32) -> String {
        switch presentationStringsPluralizationForm(self.lc, value) {
            case .zero:
                return String(format: self._MessageTimer_Weeks_zero, "\(value)")
            case .one:
                return String(format: self._MessageTimer_Weeks_one, "\(value)")
            case .two:
                return String(format: self._MessageTimer_Weeks_two, "\(value)")
            case .few:
                return String(format: self._MessageTimer_Weeks_few, "\(value)")
            case .many:
                return String(format: self._MessageTimer_Weeks_many, "\(value)")
            case .other:
                return String(format: self._MessageTimer_Weeks_other, "\(value)")
        }
    }
    private let _ForwardedFiles_zero: String
    private let _ForwardedFiles_one: String
    private let _ForwardedFiles_two: String
    private let _ForwardedFiles_few: String
    private let _ForwardedFiles_many: String
    private let _ForwardedFiles_other: String
    public func ForwardedFiles(_ value: Int32) -> String {
        switch presentationStringsPluralizationForm(self.lc, value) {
            case .zero:
                return String(format: self._ForwardedFiles_zero, "\(value)")
            case .one:
                return String(format: self._ForwardedFiles_one, "\(value)")
            case .two:
                return String(format: self._ForwardedFiles_two, "\(value)")
            case .few:
                return String(format: self._ForwardedFiles_few, "\(value)")
            case .many:
                return String(format: self._ForwardedFiles_many, "\(value)")
            case .other:
                return String(format: self._ForwardedFiles_other, "\(value)")
        }
    }
    private let _MessageTimer_ShortHours_zero: String
    private let _MessageTimer_ShortHours_one: String
    private let _MessageTimer_ShortHours_two: String
    private let _MessageTimer_ShortHours_few: String
    private let _MessageTimer_ShortHours_many: String
    private let _MessageTimer_ShortHours_other: String
    public func MessageTimer_ShortHours(_ value: Int32) -> String {
        switch presentationStringsPluralizationForm(self.lc, value) {
            case .zero:
                return String(format: self._MessageTimer_ShortHours_zero, "\(value)")
            case .one:
                return String(format: self._MessageTimer_ShortHours_one, "\(value)")
            case .two:
                return String(format: self._MessageTimer_ShortHours_two, "\(value)")
            case .few:
                return String(format: self._MessageTimer_ShortHours_few, "\(value)")
            case .many:
                return String(format: self._MessageTimer_ShortHours_many, "\(value)")
            case .other:
                return String(format: self._MessageTimer_ShortHours_other, "\(value)")
        }
    }
    private let _MessageTimer_Years_zero: String
    private let _MessageTimer_Years_one: String
    private let _MessageTimer_Years_two: String
    private let _MessageTimer_Years_few: String
    private let _MessageTimer_Years_many: String
    private let _MessageTimer_Years_other: String
    public func MessageTimer_Years(_ value: Int32) -> String {
        switch presentationStringsPluralizationForm(self.lc, value) {
            case .zero:
                return String(format: self._MessageTimer_Years_zero, "\(value)")
            case .one:
                return String(format: self._MessageTimer_Years_one, "\(value)")
            case .two:
                return String(format: self._MessageTimer_Years_two, "\(value)")
            case .few:
                return String(format: self._MessageTimer_Years_few, "\(value)")
            case .many:
                return String(format: self._MessageTimer_Years_many, "\(value)")
            case .other:
                return String(format: self._MessageTimer_Years_other, "\(value)")
        }
    }
    private let _MessageTimer_ShortMinutes_zero: String
    private let _MessageTimer_ShortMinutes_one: String
    private let _MessageTimer_ShortMinutes_two: String
    private let _MessageTimer_ShortMinutes_few: String
    private let _MessageTimer_ShortMinutes_many: String
    private let _MessageTimer_ShortMinutes_other: String
    public func MessageTimer_ShortMinutes(_ value: Int32) -> String {
        switch presentationStringsPluralizationForm(self.lc, value) {
            case .zero:
                return String(format: self._MessageTimer_ShortMinutes_zero, "\(value)")
            case .one:
                return String(format: self._MessageTimer_ShortMinutes_one, "\(value)")
            case .two:
                return String(format: self._MessageTimer_ShortMinutes_two, "\(value)")
            case .few:
                return String(format: self._MessageTimer_ShortMinutes_few, "\(value)")
            case .many:
                return String(format: self._MessageTimer_ShortMinutes_many, "\(value)")
            case .other:
                return String(format: self._MessageTimer_ShortMinutes_other, "\(value)")
        }
    }
    private let _Forward_ConfirmMultipleFiles_zero: String
    private let _Forward_ConfirmMultipleFiles_one: String
    private let _Forward_ConfirmMultipleFiles_two: String
    private let _Forward_ConfirmMultipleFiles_few: String
    private let _Forward_ConfirmMultipleFiles_many: String
    private let _Forward_ConfirmMultipleFiles_other: String
    public func Forward_ConfirmMultipleFiles(_ value: Int32) -> String {
        switch presentationStringsPluralizationForm(self.lc, value) {
            case .zero:
                return String(format: self._Forward_ConfirmMultipleFiles_zero, "\(value)")
            case .one:
                return String(format: self._Forward_ConfirmMultipleFiles_one, "\(value)")
            case .two:
                return String(format: self._Forward_ConfirmMultipleFiles_two, "\(value)")
            case .few:
                return String(format: self._Forward_ConfirmMultipleFiles_few, "\(value)")
            case .many:
                return String(format: self._Forward_ConfirmMultipleFiles_many, "\(value)")
            case .other:
                return String(format: self._Forward_ConfirmMultipleFiles_other, "\(value)")
        }
    }
    private let _Notification_GameScoreSimple_zero: String
    private let _Notification_GameScoreSimple_one: String
    private let _Notification_GameScoreSimple_two: String
    private let _Notification_GameScoreSimple_few: String
    private let _Notification_GameScoreSimple_many: String
    private let _Notification_GameScoreSimple_other: String
    public func Notification_GameScoreSimple(_ value: Int32) -> String {
        switch presentationStringsPluralizationForm(self.lc, value) {
            case .zero:
                return String(format: self._Notification_GameScoreSimple_zero, "\(value)")
            case .one:
                return String(format: self._Notification_GameScoreSimple_one, "\(value)")
            case .two:
                return String(format: self._Notification_GameScoreSimple_two, "\(value)")
            case .few:
                return String(format: self._Notification_GameScoreSimple_few, "\(value)")
            case .many:
                return String(format: self._Notification_GameScoreSimple_many, "\(value)")
            case .other:
                return String(format: self._Notification_GameScoreSimple_other, "\(value)")
        }
    }
    private let _SharedMedia_Generic_zero: String
    private let _SharedMedia_Generic_one: String
    private let _SharedMedia_Generic_two: String
    private let _SharedMedia_Generic_few: String
    private let _SharedMedia_Generic_many: String
    private let _SharedMedia_Generic_other: String
    public func SharedMedia_Generic(_ value: Int32) -> String {
        switch presentationStringsPluralizationForm(self.lc, value) {
            case .zero:
                return String(format: self._SharedMedia_Generic_zero, "\(value)")
            case .one:
                return String(format: self._SharedMedia_Generic_one, "\(value)")
            case .two:
                return String(format: self._SharedMedia_Generic_two, "\(value)")
            case .few:
                return String(format: self._SharedMedia_Generic_few, "\(value)")
            case .many:
                return String(format: self._SharedMedia_Generic_many, "\(value)")
            case .other:
                return String(format: self._SharedMedia_Generic_other, "\(value)")
        }
    }
    private let _DialogList_LiveLocationChatsCount_zero: String
    private let _DialogList_LiveLocationChatsCount_one: String
    private let _DialogList_LiveLocationChatsCount_two: String
    private let _DialogList_LiveLocationChatsCount_few: String
    private let _DialogList_LiveLocationChatsCount_many: String
    private let _DialogList_LiveLocationChatsCount_other: String
    public func DialogList_LiveLocationChatsCount(_ value: Int32) -> String {
        switch presentationStringsPluralizationForm(self.lc, value) {
            case .zero:
                return String(format: self._DialogList_LiveLocationChatsCount_zero, "\(value)")
            case .one:
                return String(format: self._DialogList_LiveLocationChatsCount_one, "\(value)")
            case .two:
                return String(format: self._DialogList_LiveLocationChatsCount_two, "\(value)")
            case .few:
                return String(format: self._DialogList_LiveLocationChatsCount_few, "\(value)")
            case .many:
                return String(format: self._DialogList_LiveLocationChatsCount_many, "\(value)")
            case .other:
                return String(format: self._DialogList_LiveLocationChatsCount_other, "\(value)")
        }
    }
    private let _Passport_Scans_zero: String
    private let _Passport_Scans_one: String
    private let _Passport_Scans_two: String
    private let _Passport_Scans_few: String
    private let _Passport_Scans_many: String
    private let _Passport_Scans_other: String
    public func Passport_Scans(_ value: Int32) -> String {
        switch presentationStringsPluralizationForm(self.lc, value) {
            case .zero:
                return String(format: self._Passport_Scans_zero, "\(value)")
            case .one:
                return String(format: self._Passport_Scans_one, "\(value)")
            case .two:
                return String(format: self._Passport_Scans_two, "\(value)")
            case .few:
                return String(format: self._Passport_Scans_few, "\(value)")
            case .many:
                return String(format: self._Passport_Scans_many, "\(value)")
            case .other:
                return String(format: self._Passport_Scans_other, "\(value)")
        }
    }
    private let _MuteFor_Days_zero: String
    private let _MuteFor_Days_one: String
    private let _MuteFor_Days_two: String
    private let _MuteFor_Days_few: String
    private let _MuteFor_Days_many: String
    private let _MuteFor_Days_other: String
    public func MuteFor_Days(_ value: Int32) -> String {
        switch presentationStringsPluralizationForm(self.lc, value) {
            case .zero:
                return String(format: self._MuteFor_Days_zero, "\(value)")
            case .one:
                return String(format: self._MuteFor_Days_one, "\(value)")
            case .two:
                return String(format: self._MuteFor_Days_two, "\(value)")
            case .few:
                return String(format: self._MuteFor_Days_few, "\(value)")
            case .many:
                return String(format: self._MuteFor_Days_many, "\(value)")
            case .other:
                return String(format: self._MuteFor_Days_other, "\(value)")
        }
    }
    private let _Call_ShortSeconds_zero: String
    private let _Call_ShortSeconds_one: String
    private let _Call_ShortSeconds_two: String
    private let _Call_ShortSeconds_few: String
    private let _Call_ShortSeconds_many: String
    private let _Call_ShortSeconds_other: String
    public func Call_ShortSeconds(_ value: Int32) -> String {
        switch presentationStringsPluralizationForm(self.lc, value) {
            case .zero:
                return String(format: self._Call_ShortSeconds_zero, "\(value)")
            case .one:
                return String(format: self._Call_ShortSeconds_one, "\(value)")
            case .two:
                return String(format: self._Call_ShortSeconds_two, "\(value)")
            case .few:
                return String(format: self._Call_ShortSeconds_few, "\(value)")
            case .many:
                return String(format: self._Call_ShortSeconds_many, "\(value)")
            case .other:
                return String(format: self._Call_ShortSeconds_other, "\(value)")
        }
    }
    private let _Media_ShareVideo_zero: String
    private let _Media_ShareVideo_one: String
    private let _Media_ShareVideo_two: String
    private let _Media_ShareVideo_few: String
    private let _Media_ShareVideo_many: String
    private let _Media_ShareVideo_other: String
    public func Media_ShareVideo(_ value: Int32) -> String {
        switch presentationStringsPluralizationForm(self.lc, value) {
            case .zero:
                return String(format: self._Media_ShareVideo_zero, "\(value)")
            case .one:
                return String(format: self._Media_ShareVideo_one, "\(value)")
            case .two:
                return String(format: self._Media_ShareVideo_two, "\(value)")
            case .few:
                return String(format: self._Media_ShareVideo_few, "\(value)")
            case .many:
                return String(format: self._Media_ShareVideo_many, "\(value)")
            case .other:
                return String(format: self._Media_ShareVideo_other, "\(value)")
        }
    }
    private let _ForwardedAuthorsOthers_zero: String
    private let _ForwardedAuthorsOthers_one: String
    private let _ForwardedAuthorsOthers_two: String
    private let _ForwardedAuthorsOthers_few: String
    private let _ForwardedAuthorsOthers_many: String
    private let _ForwardedAuthorsOthers_other: String
    public func ForwardedAuthorsOthers(_ value: Int32) -> String {
        switch presentationStringsPluralizationForm(self.lc, value) {
            case .zero:
                return String(format: self._ForwardedAuthorsOthers_zero, "\(value)")
            case .one:
                return String(format: self._ForwardedAuthorsOthers_one, "\(value)")
            case .two:
                return String(format: self._ForwardedAuthorsOthers_two, "\(value)")
            case .few:
                return String(format: self._ForwardedAuthorsOthers_few, "\(value)")
            case .many:
                return String(format: self._ForwardedAuthorsOthers_many, "\(value)")
            case .other:
                return String(format: self._ForwardedAuthorsOthers_other, "\(value)")
        }
    }
    private let _Call_ShortMinutes_zero: String
    private let _Call_ShortMinutes_one: String
    private let _Call_ShortMinutes_two: String
    private let _Call_ShortMinutes_few: String
    private let _Call_ShortMinutes_many: String
    private let _Call_ShortMinutes_other: String
    public func Call_ShortMinutes(_ value: Int32) -> String {
        switch presentationStringsPluralizationForm(self.lc, value) {
            case .zero:
                return String(format: self._Call_ShortMinutes_zero, "\(value)")
            case .one:
                return String(format: self._Call_ShortMinutes_one, "\(value)")
            case .two:
                return String(format: self._Call_ShortMinutes_two, "\(value)")
            case .few:
                return String(format: self._Call_ShortMinutes_few, "\(value)")
            case .many:
                return String(format: self._Call_ShortMinutes_many, "\(value)")
            case .other:
                return String(format: self._Call_ShortMinutes_other, "\(value)")
        }
    }
    private let _SharedMedia_DeleteItemsConfirmation_zero: String
    private let _SharedMedia_DeleteItemsConfirmation_one: String
    private let _SharedMedia_DeleteItemsConfirmation_two: String
    private let _SharedMedia_DeleteItemsConfirmation_few: String
    private let _SharedMedia_DeleteItemsConfirmation_many: String
    private let _SharedMedia_DeleteItemsConfirmation_other: String
    public func SharedMedia_DeleteItemsConfirmation(_ value: Int32) -> String {
        switch presentationStringsPluralizationForm(self.lc, value) {
            case .zero:
                return String(format: self._SharedMedia_DeleteItemsConfirmation_zero, "\(value)")
            case .one:
                return String(format: self._SharedMedia_DeleteItemsConfirmation_one, "\(value)")
            case .two:
                return String(format: self._SharedMedia_DeleteItemsConfirmation_two, "\(value)")
            case .few:
                return String(format: self._SharedMedia_DeleteItemsConfirmation_few, "\(value)")
            case .many:
                return String(format: self._SharedMedia_DeleteItemsConfirmation_many, "\(value)")
            case .other:
                return String(format: self._SharedMedia_DeleteItemsConfirmation_other, "\(value)")
        }
    }
    private let _ForwardedLocations_zero: String
    private let _ForwardedLocations_one: String
    private let _ForwardedLocations_two: String
    private let _ForwardedLocations_few: String
    private let _ForwardedLocations_many: String
    private let _ForwardedLocations_other: String
    public func ForwardedLocations(_ value: Int32) -> String {
        switch presentationStringsPluralizationForm(self.lc, value) {
            case .zero:
                return String(format: self._ForwardedLocations_zero, "\(value)")
            case .one:
                return String(format: self._ForwardedLocations_one, "\(value)")
            case .two:
                return String(format: self._ForwardedLocations_two, "\(value)")
            case .few:
                return String(format: self._ForwardedLocations_few, "\(value)")
            case .many:
                return String(format: self._ForwardedLocations_many, "\(value)")
            case .other:
                return String(format: self._ForwardedLocations_other, "\(value)")
        }
    }
    private let _Conversation_LiveLocationMembersCount_zero: String
    private let _Conversation_LiveLocationMembersCount_one: String
    private let _Conversation_LiveLocationMembersCount_two: String
    private let _Conversation_LiveLocationMembersCount_few: String
    private let _Conversation_LiveLocationMembersCount_many: String
    private let _Conversation_LiveLocationMembersCount_other: String
    public func Conversation_LiveLocationMembersCount(_ value: Int32) -> String {
        switch presentationStringsPluralizationForm(self.lc, value) {
            case .zero:
                return String(format: self._Conversation_LiveLocationMembersCount_zero, "\(value)")
            case .one:
                return String(format: self._Conversation_LiveLocationMembersCount_one, "\(value)")
            case .two:
                return String(format: self._Conversation_LiveLocationMembersCount_two, "\(value)")
            case .few:
                return String(format: self._Conversation_LiveLocationMembersCount_few, "\(value)")
            case .many:
                return String(format: self._Conversation_LiveLocationMembersCount_many, "\(value)")
            case .other:
                return String(format: self._Conversation_LiveLocationMembersCount_other, "\(value)")
        }
    }
    private let _InviteText_ContactsCountText_zero: String
    private let _InviteText_ContactsCountText_one: String
    private let _InviteText_ContactsCountText_two: String
    private let _InviteText_ContactsCountText_few: String
    private let _InviteText_ContactsCountText_many: String
    private let _InviteText_ContactsCountText_other: String
    public func InviteText_ContactsCountText(_ value: Int32) -> String {
        switch presentationStringsPluralizationForm(self.lc, value) {
            case .zero:
                return String(format: self._InviteText_ContactsCountText_zero, "\(value)")
            case .one:
                return String(format: self._InviteText_ContactsCountText_one, "\(value)")
            case .two:
                return String(format: self._InviteText_ContactsCountText_two, "\(value)")
            case .few:
                return String(format: self._InviteText_ContactsCountText_few, "\(value)")
            case .many:
                return String(format: self._InviteText_ContactsCountText_many, "\(value)")
            case .other:
                return String(format: self._InviteText_ContactsCountText_other, "\(value)")
        }
    }

    init(primaryComponent: PresentationStringsComponent, secondaryComponent: PresentationStringsComponent?) {
        self.primaryComponent = primaryComponent
        self.secondaryComponent = secondaryComponent
        
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
        self.Channel_BanUser_Title = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.BanUser.Title")
        self.Notification_SecretChatMessageScreenshotSelf = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notification.SecretChatMessageScreenshotSelf")
        self.Preview_SaveGif = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Preview.SaveGif")
        self.Passport_ScanPassportHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.ScanPassportHelp")
        self.EnterPasscode_EnterNewPasscodeNew = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "EnterPasscode.EnterNewPasscodeNew")
        self.Passport_Identity_TypeInternalPassport = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Identity.TypeInternalPassport")
        self.Privacy_Calls_WhoCanCallMe = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Privacy.Calls.WhoCanCallMe")
        self.Passport_DeletePassport = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.DeletePassport")
        self.Watch_NoConnection = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Watch.NoConnection")
        self.Activity_UploadingPhoto = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Activity.UploadingPhoto")
        self.PrivacySettings_PrivacyTitle = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PrivacySettings.PrivacyTitle")
        self._DialogList_PinLimitError = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "DialogList.PinLimitError")
        self._DialogList_PinLimitError_r = extractArgumentRanges(self._DialogList_PinLimitError)
        self.FastTwoStepSetup_PasswordSection = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "FastTwoStepSetup.PasswordSection")
        self.FastTwoStepSetup_EmailSection = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "FastTwoStepSetup.EmailSection")
        self.Notifications_Badge_IncludeChannels = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notifications.Badge.IncludeChannels")
        self.Cache_ClearCache = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Cache.ClearCache")
        self.Common_Close = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Common.Close")
        self.Passport_PasswordDescription = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.PasswordDescription")
        self.ChangePhoneNumberCode_Called = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ChangePhoneNumberCode.Called")
        self.Login_PhoneTitle = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Login.PhoneTitle")
        self._Cache_Clear = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Cache.Clear")
        self._Cache_Clear_r = extractArgumentRanges(self._Cache_Clear)
        self.EnterPasscode_EnterNewPasscodeChange = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "EnterPasscode.EnterNewPasscodeChange")
        self.Watch_ChatList_Compose = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Watch.ChatList.Compose")
        self.DialogList_SearchSectionDialogs = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "DialogList.SearchSectionDialogs")
        self.Contacts_TabTitle = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Contacts.TabTitle")
        self.NotificationsSound_Pulse = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "NotificationsSound.Pulse")
        self.Passport_Language_el = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Language.el")
        self.Passport_Identity_DateOfBirth = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Identity.DateOfBirth")
        self.TwoStepAuth_SetupPasswordConfirmPassword = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "TwoStepAuth.SetupPasswordConfirmPassword")
        self.SocksProxySetup_PasteFromClipboard = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "SocksProxySetup.PasteFromClipboard")
        self.ChannelIntro_Text = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ChannelIntro.Text")
        self.PrivacySettings_SecurityTitle = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PrivacySettings.SecurityTitle")
        self.DialogList_SavedMessages = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "DialogList.SavedMessages")
        self.Update_Skip = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Update.Skip")
        self._Call_StatusOngoing = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Call.StatusOngoing")
        self._Call_StatusOngoing_r = extractArgumentRanges(self._Call_StatusOngoing)
        self.Settings_LogoutConfirmationText = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Settings.LogoutConfirmationText")
        self.Passport_Identity_ResidenceCountry = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Identity.ResidenceCountry")
        self.AutoNightTheme_ScheduledTo = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "AutoNightTheme.ScheduledTo")
        self.SocksProxySetup_RequiredCredentials = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "SocksProxySetup.RequiredCredentials")
        self.BlockedUsers_Info = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "BlockedUsers.Info")
        self.ChatSettings_AutomaticAudioDownload = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ChatSettings.AutomaticAudioDownload")
        self.Settings_SetUsername = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Settings.SetUsername")
        self.Privacy_Calls_CustomShareHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Privacy.Calls.CustomShareHelp")
        self.Group_MessagePhotoUpdated = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Group.MessagePhotoUpdated")
        self.Message_PinnedInvoice = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Message.PinnedInvoice")
        self.Login_InfoAvatarAdd = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Login.InfoAvatarAdd")
        self.Conversation_RestrictedMedia = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.RestrictedMedia")
        self.AutoDownloadSettings_LimitBySize = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "AutoDownloadSettings.LimitBySize")
        self.WebSearch_RecentSectionTitle = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "WebSearch.RecentSectionTitle")
        self._CHAT_MESSAGE_TEXT = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "CHAT_MESSAGE_TEXT")
        self._CHAT_MESSAGE_TEXT_r = extractArgumentRanges(self._CHAT_MESSAGE_TEXT)
        self.Message_Sticker = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Message.Sticker")
        self.Paint_Regular = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Paint.Regular")
        self.Channel_Username_Help = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.Username.Help")
        self._Profile_CreateEncryptedChatOutdatedError = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Profile.CreateEncryptedChatOutdatedError")
        self._Profile_CreateEncryptedChatOutdatedError_r = extractArgumentRanges(self._Profile_CreateEncryptedChatOutdatedError)
        self.PrivacyPolicy_DeclineLastWarning = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PrivacyPolicy.DeclineLastWarning")
        self.Passport_FieldEmail = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.FieldEmail")
        self.ContactInfo_PhoneLabelPager = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ContactInfo.PhoneLabelPager")
        self._PINNED_STICKER = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PINNED_STICKER")
        self._PINNED_STICKER_r = extractArgumentRanges(self._PINNED_STICKER)
        self.AutoDownloadSettings_Title = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "AutoDownloadSettings.Title")
        self.Conversation_ShareInlineBotLocationConfirmation = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.ShareInlineBotLocationConfirmation")
        self._Channel_AdminLog_MessageEdited = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.AdminLog.MessageEdited")
        self._Channel_AdminLog_MessageEdited_r = extractArgumentRanges(self._Channel_AdminLog_MessageEdited)
        self.Group_Setup_HistoryHidden = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Group.Setup.HistoryHidden")
        self.Watch_Message_Game = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Watch.Message.Game")
        self._PHONE_CALL_REQUEST = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PHONE_CALL_REQUEST")
        self._PHONE_CALL_REQUEST_r = extractArgumentRanges(self._PHONE_CALL_REQUEST)
        self.AccessDenied_MicrophoneRestricted = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "AccessDenied.MicrophoneRestricted")
        self.Your_cards_expiration_year_is_invalid = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Your_cards_expiration_year_is_invalid")
        self.GroupInfo_InviteByLink = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "GroupInfo.InviteByLink")
        self._Notification_LeftChat = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notification.LeftChat")
        self._Notification_LeftChat_r = extractArgumentRanges(self._Notification_LeftChat)
        self.Appearance_AutoNightThemeDisabled = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Appearance.AutoNightThemeDisabled")
        self._Channel_AdminLog_MessageAdmin = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.AdminLog.MessageAdmin")
        self._Channel_AdminLog_MessageAdmin_r = extractArgumentRanges(self._Channel_AdminLog_MessageAdmin)
        self.PrivacyLastSeenSettings_NeverShareWith_Placeholder = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PrivacyLastSeenSettings.NeverShareWith.Placeholder")
        self.Notifications_ExceptionsMessagePlaceholder = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notifications.ExceptionsMessagePlaceholder")
        self.NotificationsSound_Alert = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "NotificationsSound.Alert")
        self.TwoStepAuth_SetupEmail = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "TwoStepAuth.SetupEmail")
        self.Checkout_PayWithFaceId = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Checkout.PayWithFaceId")
        self.Login_ResetAccountProtected_Reset = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Login.ResetAccountProtected.Reset")
        self.SocksProxySetup_Hostname = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "SocksProxySetup.Hostname")
        self._PrivacyPolicy_AgeVerificationMessage = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PrivacyPolicy.AgeVerificationMessage")
        self._PrivacyPolicy_AgeVerificationMessage_r = extractArgumentRanges(self._PrivacyPolicy_AgeVerificationMessage)
        self.NotificationsSound_None = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "NotificationsSound.None")
        self.Channel_AdminLog_CanEditMessages = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.AdminLog.CanEditMessages")
        self._MESSAGE_CONTACT = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "MESSAGE_CONTACT")
        self._MESSAGE_CONTACT_r = extractArgumentRanges(self._MESSAGE_CONTACT)
        self.MediaPicker_MomentsDateRangeSameMonthYearFormat = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "MediaPicker.MomentsDateRangeSameMonthYearFormat")
        self.Notification_MessageLifetime1w = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notification.MessageLifetime1w")
        self.PasscodeSettings_AutoLock_IfAwayFor_5minutes = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PasscodeSettings.AutoLock.IfAwayFor_5minutes")
        self.ChatSettings_Groups = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ChatSettings.Groups")
        self.State_Connecting = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "State.Connecting")
        self._Message_ForwardedMessageShort = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Message.ForwardedMessageShort")
        self._Message_ForwardedMessageShort_r = extractArgumentRanges(self._Message_ForwardedMessageShort)
        self.Watch_ConnectionDescription = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Watch.ConnectionDescription")
        self._Notification_CallTimeFormat = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notification.CallTimeFormat")
        self._Notification_CallTimeFormat_r = extractArgumentRanges(self._Notification_CallTimeFormat)
        self.Passport_Identity_Selfie = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Identity.Selfie")
        self.Passport_Identity_GenderMale = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Identity.GenderMale")
        self.Paint_Delete = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Paint.Delete")
        self.Passport_Identity_AddDriversLicense = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Identity.AddDriversLicense")
        self.Passport_Language_ne = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Language.ne")
        self.Channel_MessagePhotoUpdated = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.MessagePhotoUpdated")
        self.Passport_Address_OneOfTypePassportRegistration = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Address.OneOfTypePassportRegistration")
        self.Cache_Help = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Cache.Help")
        self.SocksProxySetup_ProxyStatusConnected = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "SocksProxySetup.ProxyStatusConnected")
        self._Login_EmailPhoneBody = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Login.EmailPhoneBody")
        self._Login_EmailPhoneBody_r = extractArgumentRanges(self._Login_EmailPhoneBody)
        self.Checkout_ShippingAddress = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Checkout.ShippingAddress")
        self.Channel_BanList_RestrictedTitle = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.BanList.RestrictedTitle")
        self.Checkout_TotalAmount = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Checkout.TotalAmount")
        self.Appearance_TextSize = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Appearance.TextSize")
        self.Passport_Address_TypeResidentialAddress = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Address.TypeResidentialAddress")
        self.Conversation_MessageEditedLabel = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.MessageEditedLabel")
        self.SharedMedia_EmptyLinksText = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "SharedMedia.EmptyLinksText")
        self._Conversation_RestrictedTextTimed = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.RestrictedTextTimed")
        self._Conversation_RestrictedTextTimed_r = extractArgumentRanges(self._Conversation_RestrictedTextTimed)
        self.Passport_Address_AddResidentialAddress = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Address.AddResidentialAddress")
        self.Calls_NoCallsPlaceholder = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Calls.NoCallsPlaceholder")
        self.Passport_Address_AddPassportRegistration = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Address.AddPassportRegistration")
        self.Conversation_PinMessageAlert_OnlyPin = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.PinMessageAlert.OnlyPin")
        self.PasscodeSettings_UnlockWithFaceId = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PasscodeSettings.UnlockWithFaceId")
        self.ContactInfo_Title = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ContactInfo.Title")
        self.ReportPeer_ReasonOther_Send = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ReportPeer.ReasonOther.Send")
        self.Notifications_Badge = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notifications.Badge")
        self.Conversation_InstantPagePreview = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.InstantPagePreview")
        self.PasscodeSettings_SimplePasscodeHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PasscodeSettings.SimplePasscodeHelp")
        self._Time_PreciseDate_m9 = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Time.PreciseDate_m9")
        self._Time_PreciseDate_m9_r = extractArgumentRanges(self._Time_PreciseDate_m9)
        self.GroupInfo_Title = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "GroupInfo.Title")
        self.State_Updating = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "State.Updating")
        self.PrivacyPolicy_AgeVerificationAgree = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PrivacyPolicy.AgeVerificationAgree")
        self.Map_GetDirections = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Map.GetDirections")
        self._TwoStepAuth_PendingEmailHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "TwoStepAuth.PendingEmailHelp")
        self._TwoStepAuth_PendingEmailHelp_r = extractArgumentRanges(self._TwoStepAuth_PendingEmailHelp)
        self.UserInfo_PhoneCall = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "UserInfo.PhoneCall")
        self.Passport_Language_bn = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Language.bn")
        self.MusicPlayer_VoiceNote = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "MusicPlayer.VoiceNote")
        self.Paint_Duplicate = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Paint.Duplicate")
        self.Channel_Username_InvalidTaken = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.Username.InvalidTaken")
        self.Conversation_ClearGroupHistory = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.ClearGroupHistory")
        self.Passport_Address_OneOfTypeRentalAgreement = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Address.OneOfTypeRentalAgreement")
        self.Stickers_GroupStickersHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Stickers.GroupStickersHelp")
        self.SecretChat_Title = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "SecretChat.Title")
        self.Group_UpgradeConfirmation = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Group.UpgradeConfirmation")
        self.Checkout_LiabilityAlertTitle = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Checkout.LiabilityAlertTitle")
        self.GroupInfo_GroupNamePlaceholder = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "GroupInfo.GroupNamePlaceholder")
        self._Time_PreciseDate_m11 = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Time.PreciseDate_m11")
        self._Time_PreciseDate_m11_r = extractArgumentRanges(self._Time_PreciseDate_m11)
        self.Passport_DeletePersonalDetailsConfirmation = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.DeletePersonalDetailsConfirmation")
        self._UserInfo_NotificationsDefaultSound = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "UserInfo.NotificationsDefaultSound")
        self._UserInfo_NotificationsDefaultSound_r = extractArgumentRanges(self._UserInfo_NotificationsDefaultSound)
        self.Passport_Email_Help = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Email.Help")
        self._MESSAGE_GEOLIVE = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "MESSAGE_GEOLIVE")
        self._MESSAGE_GEOLIVE_r = extractArgumentRanges(self._MESSAGE_GEOLIVE)
        self._Notification_JoinedGroupByLink = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notification.JoinedGroupByLink")
        self._Notification_JoinedGroupByLink_r = extractArgumentRanges(self._Notification_JoinedGroupByLink)
        self.LoginPassword_Title = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "LoginPassword.Title")
        self.Login_HaveNotReceivedCodeInternal = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Login.HaveNotReceivedCodeInternal")
        self.PasscodeSettings_SimplePasscode = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PasscodeSettings.SimplePasscode")
        self.NewContact_Title = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "NewContact.Title")
        self.Username_CheckingUsername = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Username.CheckingUsername")
        self.Login_ResetAccountProtected_TimerTitle = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Login.ResetAccountProtected.TimerTitle")
        self.Checkout_Email = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Checkout.Email")
        self.CheckoutInfo_SaveInfo = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "CheckoutInfo.SaveInfo")
        self.UserInfo_InviteBotToGroup = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "UserInfo.InviteBotToGroup")
        self._ChangePhoneNumberCode_CallTimer = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ChangePhoneNumberCode.CallTimer")
        self._ChangePhoneNumberCode_CallTimer_r = extractArgumentRanges(self._ChangePhoneNumberCode_CallTimer)
        self.TwoStepAuth_SetupPasswordEnterPasswordNew = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "TwoStepAuth.SetupPasswordEnterPasswordNew")
        self.Weekday_Wednesday = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Weekday.Wednesday")
        self._Channel_AdminLog_MessageToggleSignaturesOff = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.AdminLog.MessageToggleSignaturesOff")
        self._Channel_AdminLog_MessageToggleSignaturesOff_r = extractArgumentRanges(self._Channel_AdminLog_MessageToggleSignaturesOff)
        self.Month_ShortDecember = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Month.ShortDecember")
        self.Channel_SignMessages = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.SignMessages")
        self.Appearance_Title = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Appearance.Title")
        self.ReportPeer_ReasonCopyright = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ReportPeer.ReasonCopyright")
        self.Conversation_Moderate_Delete = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.Moderate.Delete")
        self.Conversation_CloudStorage_ChatStatus = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.CloudStorage.ChatStatus")
        self.Login_InfoTitle = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Login.InfoTitle")
        self.Privacy_GroupsAndChannels_NeverAllow_Placeholder = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Privacy.GroupsAndChannels.NeverAllow.Placeholder")
        self.Message_Video = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Message.Video")
        self.Notification_ChannelInviterSelf = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notification.ChannelInviterSelf")
        self.Channel_AdminLog_BanEmbedLinks = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.AdminLog.BanEmbedLinks")
        self.Conversation_SecretLinkPreviewAlert = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.SecretLinkPreviewAlert")
        self._CHANNEL_MESSAGE_GEOLIVE = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "CHANNEL_MESSAGE_GEOLIVE")
        self._CHANNEL_MESSAGE_GEOLIVE_r = extractArgumentRanges(self._CHANNEL_MESSAGE_GEOLIVE)
        self.Cache_Videos = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Cache.Videos")
        self.Call_ReportSkip = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Call.ReportSkip")
        self.NetworkUsageSettings_MediaImageDataSection = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "NetworkUsageSettings.MediaImageDataSection")
        self.Group_Setup_HistoryTitle = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Group.Setup.HistoryTitle")
        self.TwoStepAuth_GenericHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "TwoStepAuth.GenericHelp")
        self._DialogList_SingleRecordingAudioSuffix = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "DialogList.SingleRecordingAudioSuffix")
        self._DialogList_SingleRecordingAudioSuffix_r = extractArgumentRanges(self._DialogList_SingleRecordingAudioSuffix)
        self.Privacy_TopPeersDelete = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Privacy.TopPeersDelete")
        self.Checkout_NewCard_CardholderNameTitle = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Checkout.NewCard.CardholderNameTitle")
        self.Settings_FAQ_Button = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Settings.FAQ_Button")
        self._GroupInfo_AddParticipantConfirmation = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "GroupInfo.AddParticipantConfirmation")
        self._GroupInfo_AddParticipantConfirmation_r = extractArgumentRanges(self._GroupInfo_AddParticipantConfirmation)
        self._Notification_PinnedLiveLocationMessage = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notification.PinnedLiveLocationMessage")
        self._Notification_PinnedLiveLocationMessage_r = extractArgumentRanges(self._Notification_PinnedLiveLocationMessage)
        self.AccessDenied_PhotosRestricted = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "AccessDenied.PhotosRestricted")
        self.Map_Locating = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Map.Locating")
        self.AutoDownloadSettings_Unlimited = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "AutoDownloadSettings.Unlimited")
        self.Passport_Language_km = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Language.km")
        self.MediaPicker_LivePhotoDescription = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "MediaPicker.LivePhotoDescription")
        self.Passport_DiscardMessageDescription = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.DiscardMessageDescription")
        self.SocksProxySetup_Title = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "SocksProxySetup.Title")
        self.SharedMedia_EmptyMusicText = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "SharedMedia.EmptyMusicText")
        self.Cache_ByPeerHeader = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Cache.ByPeerHeader")
        self.Bot_GroupStatusReadsHistory = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Bot.GroupStatusReadsHistory")
        self.TwoStepAuth_ResetAccountConfirmation = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "TwoStepAuth.ResetAccountConfirmation")
        self.CallSettings_Always = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "CallSettings.Always")
        self.Message_ImageExpired = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Message.ImageExpired")
        self.Channel_BanUser_Unban = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.BanUser.Unban")
        self.Stickers_GroupChooseStickerPack = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Stickers.GroupChooseStickerPack")
        self.Group_Setup_TypePrivate = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Group.Setup.TypePrivate")
        self.Passport_Language_cs = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Language.cs")
        self.Settings_LogoutConfirmationTitle = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Settings.LogoutConfirmationTitle")
        self.UserInfo_FirstNamePlaceholder = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "UserInfo.FirstNamePlaceholder")
        self.Passport_Identity_SurnamePlaceholder = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Identity.SurnamePlaceholder")
        self.Passport_Identity_FilesView = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Identity.FilesView")
        self.LoginPassword_ResetAccount = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "LoginPassword.ResetAccount")
        self.Privacy_GroupsAndChannels_AlwaysAllow = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Privacy.GroupsAndChannels.AlwaysAllow")
        self._Notification_JoinedChat = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notification.JoinedChat")
        self._Notification_JoinedChat_r = extractArgumentRanges(self._Notification_JoinedChat)
        self.Notifications_ExceptionsUnmuted = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notifications.ExceptionsUnmuted")
        self.ChannelInfo_DeleteChannel = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ChannelInfo.DeleteChannel")
        self.Passport_Title = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Title")
        self.NetworkUsageSettings_BytesReceived = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "NetworkUsageSettings.BytesReceived")
        self.BlockedUsers_BlockTitle = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "BlockedUsers.BlockTitle")
        self.Update_Title = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Update.Title")
        self.AccessDenied_PhotosAndVideos = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "AccessDenied.PhotosAndVideos")
        self.Channel_Username_Title = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.Username.Title")
        self._Channel_AdminLog_MessageToggleSignaturesOn = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.AdminLog.MessageToggleSignaturesOn")
        self._Channel_AdminLog_MessageToggleSignaturesOn_r = extractArgumentRanges(self._Channel_AdminLog_MessageToggleSignaturesOn)
        self.Map_PullUpForPlaces = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Map.PullUpForPlaces")
        self._Conversation_EncryptionWaiting = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.EncryptionWaiting")
        self._Conversation_EncryptionWaiting_r = extractArgumentRanges(self._Conversation_EncryptionWaiting)
        self.Passport_Language_ka = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Language.ka")
        self.InfoPlist_NSSiriUsageDescription = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "InfoPlist.NSSiriUsageDescription")
        self.Calls_NotNow = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Calls.NotNow")
        self.Conversation_Report = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.Report")
        self._CHANNEL_MESSAGE_DOC = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "CHANNEL_MESSAGE_DOC")
        self._CHANNEL_MESSAGE_DOC_r = extractArgumentRanges(self._CHANNEL_MESSAGE_DOC)
        self.Channel_AdminLogFilter_EventsAll = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.AdminLogFilter.EventsAll")
        self.InfoPlist_NSLocationWhenInUseUsageDescription = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "InfoPlist.NSLocationWhenInUseUsageDescription")
        self.Passport_Address_TypeTemporaryRegistration = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Address.TypeTemporaryRegistration")
        self.Call_ConnectionErrorTitle = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Call.ConnectionErrorTitle")
        self.Passport_Language_tr = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Language.tr")
        self.Settings_ApplyProxyAlertEnable = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Settings.ApplyProxyAlertEnable")
        self.Settings_ChatSettings = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Settings.ChatSettings")
        self.Group_About_Help = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Group.About.Help")
        self._CHANNEL_MESSAGE_NOTEXT = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "CHANNEL_MESSAGE_NOTEXT")
        self._CHANNEL_MESSAGE_NOTEXT_r = extractArgumentRanges(self._CHANNEL_MESSAGE_NOTEXT)
        self.Month_GenSeptember = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Month.GenSeptember")
        self.PrivacySettings_LastSeenEverybody = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PrivacySettings.LastSeenEverybody")
        self.Contacts_NotRegisteredSection = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Contacts.NotRegisteredSection")
        self.PhotoEditor_BlurToolRadial = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PhotoEditor.BlurToolRadial")
        self.TwoStepAuth_PasswordRemoveConfirmation = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "TwoStepAuth.PasswordRemoveConfirmation")
        self.Channel_EditAdmin_PermissionEditMessages = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.EditAdmin.PermissionEditMessages")
        self.TwoStepAuth_ChangePassword = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "TwoStepAuth.ChangePassword")
        self.Watch_MessageView_Title = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Watch.MessageView.Title")
        self._Notification_PinnedRoundMessage = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notification.PinnedRoundMessage")
        self._Notification_PinnedRoundMessage_r = extractArgumentRanges(self._Notification_PinnedRoundMessage)
        self.Conversation_ViewMessage = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.ViewMessage")
        self.Passport_FieldEmailHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.FieldEmailHelp")
        self.Settings_SaveEditedPhotos = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Settings.SaveEditedPhotos")
        self.Channel_Management_LabelCreator = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.Management.LabelCreator")
        self._Notification_PinnedStickerMessage = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notification.PinnedStickerMessage")
        self._Notification_PinnedStickerMessage_r = extractArgumentRanges(self._Notification_PinnedStickerMessage)
        self._AutoNightTheme_AutomaticHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "AutoNightTheme.AutomaticHelp")
        self._AutoNightTheme_AutomaticHelp_r = extractArgumentRanges(self._AutoNightTheme_AutomaticHelp)
        self.Passport_Address_EditPassportRegistration = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Address.EditPassportRegistration")
        self.PhotoEditor_QualityTool = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PhotoEditor.QualityTool")
        self.Login_NetworkError = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Login.NetworkError")
        self.TwoStepAuth_EnterPasswordForgot = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "TwoStepAuth.EnterPasswordForgot")
        self.Compose_ChannelMembers = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Compose.ChannelMembers")
        self._Channel_AdminLog_CaptionEdited = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.AdminLog.CaptionEdited")
        self._Channel_AdminLog_CaptionEdited_r = extractArgumentRanges(self._Channel_AdminLog_CaptionEdited)
        self.Common_Yes = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Common.Yes")
        self.KeyCommand_JumpToPreviousUnreadChat = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "KeyCommand.JumpToPreviousUnreadChat")
        self.CheckoutInfo_ReceiverInfoPhone = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "CheckoutInfo.ReceiverInfoPhone")
        self.SocksProxySetup_TypeNone = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "SocksProxySetup.TypeNone")
        self.GroupInfo_AddParticipantTitle = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "GroupInfo.AddParticipantTitle")
        self.Map_LiveLocationShowAll = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Map.LiveLocationShowAll")
        self.Settings_SavedMessages = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Settings.SavedMessages")
        self.Passport_FieldIdentitySelfieHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.FieldIdentitySelfieHelp")
        self._CHANNEL_MESSAGE_TEXT = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "CHANNEL_MESSAGE_TEXT")
        self._CHANNEL_MESSAGE_TEXT_r = extractArgumentRanges(self._CHANNEL_MESSAGE_TEXT)
        self.Checkout_PayNone = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Checkout.PayNone")
        self.CheckoutInfo_ErrorNameInvalid = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "CheckoutInfo.ErrorNameInvalid")
        self.Notification_PaymentSent = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notification.PaymentSent")
        self.Settings_Username = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Settings.Username")
        self.Notification_CallMissedShort = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notification.CallMissedShort")
        self.Call_CallInProgressTitle = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Call.CallInProgressTitle")
        self.Passport_Scans = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Scans")
        self.PhotoEditor_Skip = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PhotoEditor.Skip")
        self.AuthSessions_TerminateOtherSessionsHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "AuthSessions.TerminateOtherSessionsHelp")
        self.Call_AudioRouteHeadphones = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Call.AudioRouteHeadphones")
        self.SocksProxySetup_UseForCalls = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "SocksProxySetup.UseForCalls")
        self.Contacts_InviteFriends = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Contacts.InviteFriends")
        self.Channel_BanUser_PermissionSendMessages = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.BanUser.PermissionSendMessages")
        self.Notifications_InAppNotificationsVibrate = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notifications.InAppNotificationsVibrate")
        self.StickerPack_Share = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "StickerPack.Share")
        self.Watch_MessageView_Reply = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Watch.MessageView.Reply")
        self.Call_AudioRouteSpeaker = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Call.AudioRouteSpeaker")
        self.Checkout_Title = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Checkout.Title")
        self._MESSAGE_GEO = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "MESSAGE_GEO")
        self._MESSAGE_GEO_r = extractArgumentRanges(self._MESSAGE_GEO)
        self.Privacy_Calls = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Privacy.Calls")
        self.DialogList_AdLabel = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "DialogList.AdLabel")
        self.Passport_Identity_ScansHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Identity.ScansHelp")
        self.Channel_AdminLogFilter_EventsInfo = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.AdminLogFilter.EventsInfo")
        self.Passport_Language_hu = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Language.hu")
        self._Channel_AdminLog_MessagePinned = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.AdminLog.MessagePinned")
        self._Channel_AdminLog_MessagePinned_r = extractArgumentRanges(self._Channel_AdminLog_MessagePinned)
        self._Channel_AdminLog_MessageToggleInvitesOn = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.AdminLog.MessageToggleInvitesOn")
        self._Channel_AdminLog_MessageToggleInvitesOn_r = extractArgumentRanges(self._Channel_AdminLog_MessageToggleInvitesOn)
        self.KeyCommand_ScrollDown = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "KeyCommand.ScrollDown")
        self.Conversation_LinkDialogSave = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.LinkDialogSave")
        self.CheckoutInfo_ErrorShippingNotAvailable = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "CheckoutInfo.ErrorShippingNotAvailable")
        self.Conversation_SendMessageErrorFlood = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.SendMessageErrorFlood")
        self._Checkout_SavePasswordTimeoutAndTouchId = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Checkout.SavePasswordTimeoutAndTouchId")
        self._Checkout_SavePasswordTimeoutAndTouchId_r = extractArgumentRanges(self._Checkout_SavePasswordTimeoutAndTouchId)
        self.HashtagSearch_AllChats = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "HashtagSearch.AllChats")
        self.InfoPlist_NSPhotoLibraryAddUsageDescription = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "InfoPlist.NSPhotoLibraryAddUsageDescription")
        self._Date_ChatDateHeaderYear = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Date.ChatDateHeaderYear")
        self._Date_ChatDateHeaderYear_r = extractArgumentRanges(self._Date_ChatDateHeaderYear)
        self.Privacy_Calls_P2PContacts = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Privacy.Calls.P2PContacts")
        self.Passport_Email_Delete = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Email.Delete")
        self.CheckoutInfo_ShippingInfoCountry = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "CheckoutInfo.ShippingInfoCountry")
        self.Map_ShowPlaces = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Map.ShowPlaces")
        self.Passport_Identity_GenderFemale = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Identity.GenderFemale")
        self.Camera_VideoMode = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Camera.VideoMode")
        self._Watch_Time_ShortFullAt = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Watch.Time.ShortFullAt")
        self._Watch_Time_ShortFullAt_r = extractArgumentRanges(self._Watch_Time_ShortFullAt)
        self.UserInfo_TelegramCall = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "UserInfo.TelegramCall")
        self.PrivacyLastSeenSettings_CustomShareSettingsHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PrivacyLastSeenSettings.CustomShareSettingsHelp")
        self.Passport_UpdateRequiredError = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.UpdateRequiredError")
        self.Channel_AdminLog_InfoPanelAlertText = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.AdminLog.InfoPanelAlertText")
        self._Channel_AdminLog_MessageUnpinned = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.AdminLog.MessageUnpinned")
        self._Channel_AdminLog_MessageUnpinned_r = extractArgumentRanges(self._Channel_AdminLog_MessageUnpinned)
        self.Cache_Photos = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Cache.Photos")
        self.Message_PinnedStickerMessage = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Message.PinnedStickerMessage")
        self.PhotoEditor_QualityMedium = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PhotoEditor.QualityMedium")
        self.Privacy_PaymentsClearInfo = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Privacy.PaymentsClearInfo")
        self.PhotoEditor_CurvesRed = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PhotoEditor.CurvesRed")
        self.Passport_Identity_AddPersonalDetails = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Identity.AddPersonalDetails")
        self._Login_WillCallYou = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Login.WillCallYou")
        self._Login_WillCallYou_r = extractArgumentRanges(self._Login_WillCallYou)
        self.Privacy_PaymentsTitle = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Privacy.PaymentsTitle")
        self.SocksProxySetup_ProxyType = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "SocksProxySetup.ProxyType")
        self._Time_PreciseDate_m8 = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Time.PreciseDate_m8")
        self._Time_PreciseDate_m8_r = extractArgumentRanges(self._Time_PreciseDate_m8)
        self.Login_PhoneNumberHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Login.PhoneNumberHelp")
        self.User_DeletedAccount = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "User.DeletedAccount")
        self.Call_StatusFailed = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Call.StatusFailed")
        self._Notification_GroupInviter = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notification.GroupInviter")
        self._Notification_GroupInviter_r = extractArgumentRanges(self._Notification_GroupInviter)
        self.Localization_ChooseLanguage = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Localization.ChooseLanguage")
        self.CheckoutInfo_ShippingInfoAddress2Placeholder = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "CheckoutInfo.ShippingInfoAddress2Placeholder")
        self._Notification_SecretChatMessageScreenshot = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notification.SecretChatMessageScreenshot")
        self._Notification_SecretChatMessageScreenshot_r = extractArgumentRanges(self._Notification_SecretChatMessageScreenshot)
        self._DialogList_SingleUploadingPhotoSuffix = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "DialogList.SingleUploadingPhotoSuffix")
        self._DialogList_SingleUploadingPhotoSuffix_r = extractArgumentRanges(self._DialogList_SingleUploadingPhotoSuffix)
        self.Channel_LeaveChannel = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.LeaveChannel")
        self.Compose_NewGroup = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Compose.NewGroup")
        self.TwoStepAuth_EmailPlaceholder = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "TwoStepAuth.EmailPlaceholder")
        self.PhotoEditor_ExposureTool = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PhotoEditor.ExposureTool")
        self.Conversation_ViewChannel = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.ViewChannel")
        self.ChatAdmins_AdminLabel = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ChatAdmins.AdminLabel")
        self.Contacts_FailedToSendInvitesMessage = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Contacts.FailedToSendInvitesMessage")
        self.Login_Code = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Login.Code")
        self.Passport_Identity_ExpiryDateNone = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Identity.ExpiryDateNone")
        self.ContactInfo_PhoneLabelWorkFax = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ContactInfo.PhoneLabelWorkFax")
        self.Channel_Username_InvalidCharacters = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.Username.InvalidCharacters")
        self.FeatureDisabled_Oops = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "FeatureDisabled.Oops")
        self.Calls_CallTabTitle = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Calls.CallTabTitle")
        self.ShareMenu_Send = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ShareMenu.Send")
        self.WatchRemote_AlertTitle = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "WatchRemote.AlertTitle")
        self.Channel_Members_AddBannedErrorAdmin = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.Members.AddBannedErrorAdmin")
        self.Conversation_InfoGroup = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.InfoGroup")
        self.Passport_Identity_TypePersonalDetails = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Identity.TypePersonalDetails")
        self.Passport_Identity_OneOfTypePassport = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Identity.OneOfTypePassport")
        self.Checkout_Phone = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Checkout.Phone")
        self.Channel_SignMessages_Help = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.SignMessages.Help")
        self.Passport_PasswordNext = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.PasswordNext")
        self.Calls_SubmitRating = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Calls.SubmitRating")
        self.Camera_FlashOn = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Camera.FlashOn")
        self.Watch_MessageView_Forward = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Watch.MessageView.Forward")
        self.Passport_DiscardMessageTitle = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.DiscardMessageTitle")
        self.Passport_Language_uk = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Language.uk")
        self.GroupInfo_ActionPromote = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "GroupInfo.ActionPromote")
        self.DialogList_You = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "DialogList.You")
        self.Weekday_Monday = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Weekday.Monday")
        self.Passport_Identity_SelfieHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Identity.SelfieHelp")
        self.Passport_Identity_MiddleName = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Identity.MiddleName")
        self.AccessDenied_Camera = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "AccessDenied.Camera")
        self.WatchRemote_NotificationText = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "WatchRemote.NotificationText")
        self.SharedMedia_ViewInChat = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "SharedMedia.ViewInChat")
        self.Activity_RecordingAudio = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Activity.RecordingAudio")
        self.Watch_Stickers_StickerPacks = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Watch.Stickers.StickerPacks")
        self._Target_ShareGameConfirmationPrivate = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Target.ShareGameConfirmationPrivate")
        self._Target_ShareGameConfirmationPrivate_r = extractArgumentRanges(self._Target_ShareGameConfirmationPrivate)
        self.Checkout_NewCard_PostcodePlaceholder = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Checkout.NewCard.PostcodePlaceholder")
        self.Passport_Identity_OneOfTypeInternalPassport = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Identity.OneOfTypeInternalPassport")
        self.DialogList_DeleteConversationConfirmation = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "DialogList.DeleteConversationConfirmation")
        self.AttachmentMenu_SendAsFile = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "AttachmentMenu.SendAsFile")
        self.Watch_Conversation_Unblock = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Watch.Conversation.Unblock")
        self.Channel_AdminLog_MessagePreviousLink = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.AdminLog.MessagePreviousLink")
        self.Conversation_ContextMenuCopy = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.ContextMenuCopy")
        self.GroupInfo_UpgradeButton = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "GroupInfo.UpgradeButton")
        self.PrivacyLastSeenSettings_NeverShareWith = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PrivacyLastSeenSettings.NeverShareWith")
        self.ConvertToSupergroup_HelpText = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ConvertToSupergroup.HelpText")
        self.MediaPicker_VideoMuteDescription = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "MediaPicker.VideoMuteDescription")
        self.Passport_Address_TypeRentalAgreement = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Address.TypeRentalAgreement")
        self.Passport_Language_it = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Language.it")
        self.UserInfo_ShareMyContactInfo = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "UserInfo.ShareMyContactInfo")
        self.Channel_Info_Stickers = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.Info.Stickers")
        self.Appearance_ColorTheme = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Appearance.ColorTheme")
        self._FileSize_GB = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "FileSize.GB")
        self._FileSize_GB_r = extractArgumentRanges(self._FileSize_GB)
        self._Passport_FieldOneOf_Or = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.FieldOneOf.Or")
        self._Passport_FieldOneOf_Or_r = extractArgumentRanges(self._Passport_FieldOneOf_Or)
        self.Month_ShortJanuary = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Month.ShortJanuary")
        self.Channel_BanUser_PermissionsHeader = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.BanUser.PermissionsHeader")
        self.PhotoEditor_QualityVeryHigh = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PhotoEditor.QualityVeryHigh")
        self.Passport_Language_mk = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Language.mk")
        self.Login_TermsOfServiceLabel = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Login.TermsOfServiceLabel")
        self._MESSAGE_TEXT = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "MESSAGE_TEXT")
        self._MESSAGE_TEXT_r = extractArgumentRanges(self._MESSAGE_TEXT)
        self.DialogList_NoMessagesTitle = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "DialogList.NoMessagesTitle")
        self.Passport_DeletePassportConfirmation = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.DeletePassportConfirmation")
        self.Passport_Language_az = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Language.az")
        self.AccessDenied_Contacts = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "AccessDenied.Contacts")
        self.Your_cards_security_code_is_invalid = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Your_cards_security_code_is_invalid")
        self.Contacts_InviteSearchLabel = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Contacts.InviteSearchLabel")
        self.Tour_StartButton = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Tour.StartButton")
        self.CheckoutInfo_Title = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "CheckoutInfo.Title")
        self.Conversation_Admin = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.Admin")
        self._Channel_AdminLog_MessageRestrictedNameUsername = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.AdminLog.MessageRestrictedNameUsername")
        self._Channel_AdminLog_MessageRestrictedNameUsername_r = extractArgumentRanges(self._Channel_AdminLog_MessageRestrictedNameUsername)
        self.ChangePhoneNumberCode_Help = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ChangePhoneNumberCode.Help")
        self.Web_Error = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Web.Error")
        self.ShareFileTip_Title = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ShareFileTip.Title")
        self.Privacy_SecretChatsLinkPreviews = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Privacy.SecretChatsLinkPreviews")
        self.Username_InvalidStartsWithNumber = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Username.InvalidStartsWithNumber")
        self._DialogList_EncryptedChatStartedIncoming = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "DialogList.EncryptedChatStartedIncoming")
        self._DialogList_EncryptedChatStartedIncoming_r = extractArgumentRanges(self._DialogList_EncryptedChatStartedIncoming)
        self.Calls_AddTab = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Calls.AddTab")
        self.DialogList_AdNoticeAlert = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "DialogList.AdNoticeAlert")
        self.PhotoEditor_TiltShift = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PhotoEditor.TiltShift")
        self.Passport_Identity_TypeDriversLicenseUploadScan = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Identity.TypeDriversLicenseUploadScan")
        self.ChannelMembers_WhoCanAddMembers_Admins = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ChannelMembers.WhoCanAddMembers.Admins")
        self.Tour_Text5 = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Tour.Text5")
        self.Notifications_ExceptionsGroupPlaceholder = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notifications.ExceptionsGroupPlaceholder")
        self.Watch_Stickers_RecentPlaceholder = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Watch.Stickers.RecentPlaceholder")
        self.Common_Select = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Common.Select")
        self._Notification_MessageLifetimeRemoved = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notification.MessageLifetimeRemoved")
        self._Notification_MessageLifetimeRemoved_r = extractArgumentRanges(self._Notification_MessageLifetimeRemoved)
        self._PINNED_INVOICE = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PINNED_INVOICE")
        self._PINNED_INVOICE_r = extractArgumentRanges(self._PINNED_INVOICE)
        self.Month_GenFebruary = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Month.GenFebruary")
        self.Contacts_SelectAll = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Contacts.SelectAll")
        self.FastTwoStepSetup_EmailHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "FastTwoStepSetup.EmailHelp")
        self.Month_GenOctober = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Month.GenOctober")
        self.CheckoutInfo_ErrorPhoneInvalid = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "CheckoutInfo.ErrorPhoneInvalid")
        self.Passport_Identity_DocumentNumberPlaceholder = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Identity.DocumentNumberPlaceholder")
        self.AutoNightTheme_UpdateLocation = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "AutoNightTheme.UpdateLocation")
        self.Group_Setup_TypePublic = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Group.Setup.TypePublic")
        self.Checkout_PaymentMethod_New = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Checkout.PaymentMethod.New")
        self.ShareMenu_Comment = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ShareMenu.Comment")
        self.Passport_FloodError = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.FloodError")
        self.Channel_Management_LabelEditor = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.Management.LabelEditor")
        self.TwoStepAuth_SetPasswordHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "TwoStepAuth.SetPasswordHelp")
        self.Channel_AdminLogFilter_EventsTitle = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.AdminLogFilter.EventsTitle")
        self.NotificationSettings_ContactJoined = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "NotificationSettings.ContactJoined")
        self.ChatSettings_AutoDownloadVideos = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ChatSettings.AutoDownloadVideos")
        self.Passport_Identity_TypeIdentityCard = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Identity.TypeIdentityCard")
        self.Username_LinkCopied = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Username.LinkCopied")
        self._Time_MonthOfYear_m9 = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Time.MonthOfYear_m9")
        self._Time_MonthOfYear_m9_r = extractArgumentRanges(self._Time_MonthOfYear_m9)
        self.Channel_EditAdmin_PermissionAddAdmins = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.EditAdmin.PermissionAddAdmins")
        self.Passport_FieldPhoneHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.FieldPhoneHelp")
        self.Conversation_SendMessage = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.SendMessage")
        self.Notification_CallIncoming = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notification.CallIncoming")
        self._MESSAGE_FWDS = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "MESSAGE_FWDS")
        self._MESSAGE_FWDS_r = extractArgumentRanges(self._MESSAGE_FWDS)
        self.Map_OpenInYandexMaps = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Map.OpenInYandexMaps")
        self.FastTwoStepSetup_PasswordHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "FastTwoStepSetup.PasswordHelp")
        self.GroupInfo_GroupHistoryHidden = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "GroupInfo.GroupHistoryHidden")
        self.AutoNightTheme_UseSunsetSunrise = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "AutoNightTheme.UseSunsetSunrise")
        self.Month_ShortNovember = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Month.ShortNovember")
        self.AccessDenied_Settings = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "AccessDenied.Settings")
        self.EncryptionKey_Title = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "EncryptionKey.Title")
        self.Profile_MessageLifetime1h = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Profile.MessageLifetime1h")
        self._Map_DistanceAway = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Map.DistanceAway")
        self._Map_DistanceAway_r = extractArgumentRanges(self._Map_DistanceAway)
        self.Checkout_ErrorPaymentFailed = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Checkout.ErrorPaymentFailed")
        self.Compose_NewMessage = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Compose.NewMessage")
        self.Conversation_LiveLocationYou = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.LiveLocationYou")
        self.Privacy_TopPeersHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Privacy.TopPeersHelp")
        self.Map_OpenInWaze = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Map.OpenInWaze")
        self.Checkout_ShippingMethod = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Checkout.ShippingMethod")
        self.Login_InfoFirstNamePlaceholder = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Login.InfoFirstNamePlaceholder")
        self.Checkout_ErrorProviderAccountInvalid = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Checkout.ErrorProviderAccountInvalid")
        self.CallSettings_TabIconDescription = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "CallSettings.TabIconDescription")
        self.ChatSettings_AutoDownloadReset = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ChatSettings.AutoDownloadReset")
        self.Checkout_WebConfirmation_Title = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Checkout.WebConfirmation.Title")
        self.PasscodeSettings_AutoLock = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PasscodeSettings.AutoLock")
        self.Notifications_MessageNotificationsPreview = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notifications.MessageNotificationsPreview")
        self.Conversation_BlockUser = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.BlockUser")
        self.Passport_Identity_EditPassport = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Identity.EditPassport")
        self.MessageTimer_Custom = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "MessageTimer.Custom")
        self.Conversation_SilentBroadcastTooltipOff = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.SilentBroadcastTooltipOff")
        self.Conversation_Mute = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.Mute")
        self.CreateGroup_SoftUserLimitAlert = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "CreateGroup.SoftUserLimitAlert")
        self.AccessDenied_LocationDenied = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "AccessDenied.LocationDenied")
        self.Tour_Title6 = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Tour.Title6")
        self.Settings_UsernameEmpty = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Settings.UsernameEmpty")
        self.PrivacySettings_TwoStepAuth = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PrivacySettings.TwoStepAuth")
        self.Conversation_FileICloudDrive = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.FileICloudDrive")
        self.KeyCommand_SendMessage = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "KeyCommand.SendMessage")
        self._Channel_AdminLog_MessageDeleted = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.AdminLog.MessageDeleted")
        self._Channel_AdminLog_MessageDeleted_r = extractArgumentRanges(self._Channel_AdminLog_MessageDeleted)
        self.DialogList_DeleteBotConfirmation = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "DialogList.DeleteBotConfirmation")
        self.EditProfile_Title = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "EditProfile.Title")
        self.PasscodeSettings_HelpTop = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PasscodeSettings.HelpTop")
        self.SocksProxySetup_ProxySocks5 = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "SocksProxySetup.ProxySocks5")
        self.Common_TakePhotoOrVideo = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Common.TakePhotoOrVideo")
        self.Notification_MessageLifetime2s = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notification.MessageLifetime2s")
        self.Checkout_ErrorGeneric = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Checkout.ErrorGeneric")
        self.DialogList_Unread = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "DialogList.Unread")
        self.AutoNightTheme_Automatic = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "AutoNightTheme.Automatic")
        self.Passport_Identity_Name = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Identity.Name")
        self.Channel_AdminLog_CanBanUsers = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.AdminLog.CanBanUsers")
        self.Cache_Indexing = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Cache.Indexing")
        self._ENCRYPTION_REQUEST = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ENCRYPTION_REQUEST")
        self._ENCRYPTION_REQUEST_r = extractArgumentRanges(self._ENCRYPTION_REQUEST)
        self.StickerSettings_ContextInfo = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "StickerSettings.ContextInfo")
        self.Channel_BanUser_PermissionEmbedLinks = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.BanUser.PermissionEmbedLinks")
        self.Map_Location = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Map.Location")
        self.GroupInfo_InviteLink_LinkSection = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "GroupInfo.InviteLink.LinkSection")
        self._Passport_Identity_UploadOneOfScan = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Identity.UploadOneOfScan")
        self._Passport_Identity_UploadOneOfScan_r = extractArgumentRanges(self._Passport_Identity_UploadOneOfScan)
        self.Notification_PassportValuePhone = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notification.PassportValuePhone")
        self.Privacy_Calls_AlwaysAllow_Placeholder = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Privacy.Calls.AlwaysAllow.Placeholder")
        self.CheckoutInfo_ShippingInfoPostcode = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "CheckoutInfo.ShippingInfoPostcode")
        self.Group_Setup_HistoryVisibleHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Group.Setup.HistoryVisibleHelp")
        self._Time_PreciseDate_m7 = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Time.PreciseDate_m7")
        self._Time_PreciseDate_m7_r = extractArgumentRanges(self._Time_PreciseDate_m7)
        self.PasscodeSettings_EncryptDataHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PasscodeSettings.EncryptDataHelp")
        self.Passport_Language_ja = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Language.ja")
        self.KeyCommand_FocusOnInputField = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "KeyCommand.FocusOnInputField")
        self.Channel_Members_AddAdminErrorBlacklisted = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.Members.AddAdminErrorBlacklisted")
        self.Cache_KeepMedia = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Cache.KeepMedia")
        self.SocksProxySetup_ProxyTelegram = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "SocksProxySetup.ProxyTelegram")
        self.WebPreview_GettingLinkInfo = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "WebPreview.GettingLinkInfo")
        self.Group_Setup_TypePublicHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Group.Setup.TypePublicHelp")
        self.Map_Satellite = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Map.Satellite")
        self.Username_InvalidTaken = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Username.InvalidTaken")
        self._Notification_PinnedAudioMessage = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notification.PinnedAudioMessage")
        self._Notification_PinnedAudioMessage_r = extractArgumentRanges(self._Notification_PinnedAudioMessage)
        self.Notification_MessageLifetime1d = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notification.MessageLifetime1d")
        self.Profile_MessageLifetime2s = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Profile.MessageLifetime2s")
        self._TwoStepAuth_RecoveryEmailUnavailable = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "TwoStepAuth.RecoveryEmailUnavailable")
        self._TwoStepAuth_RecoveryEmailUnavailable_r = extractArgumentRanges(self._TwoStepAuth_RecoveryEmailUnavailable)
        self.Calls_RatingFeedback = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Calls.RatingFeedback")
        self.Profile_EncryptionKey = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Profile.EncryptionKey")
        self.Watch_Suggestion_WhatsUp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Watch.Suggestion.WhatsUp")
        self.LoginPassword_PasswordPlaceholder = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "LoginPassword.PasswordPlaceholder")
        self.TwoStepAuth_EnterPasswordPassword = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "TwoStepAuth.EnterPasswordPassword")
        self._Time_PreciseDate_m10 = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Time.PreciseDate_m10")
        self._Time_PreciseDate_m10_r = extractArgumentRanges(self._Time_PreciseDate_m10)
        self._CHANNEL_MESSAGE_CONTACT = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "CHANNEL_MESSAGE_CONTACT")
        self._CHANNEL_MESSAGE_CONTACT_r = extractArgumentRanges(self._CHANNEL_MESSAGE_CONTACT)
        self.Passport_Language_bg = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Language.bg")
        self.PrivacySettings_DeleteAccountHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PrivacySettings.DeleteAccountHelp")
        self.Channel_Info_Banned = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.Info.Banned")
        self.Conversation_ShareBotContactConfirmationTitle = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.ShareBotContactConfirmationTitle")
        self.ConversationProfile_UsersTooMuchError = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ConversationProfile.UsersTooMuchError")
        self.ChatAdmins_AllMembersAreAdminsOffHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ChatAdmins.AllMembersAreAdminsOffHelp")
        self.Privacy_GroupsAndChannels_WhoCanAddMe = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Privacy.GroupsAndChannels.WhoCanAddMe")
        self.Login_CodeExpiredError = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Login.CodeExpiredError")
        self.Settings_PhoneNumber = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Settings.PhoneNumber")
        self.FastTwoStepSetup_EmailPlaceholder = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "FastTwoStepSetup.EmailPlaceholder")
        self._DialogList_MultipleTypingSuffix = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "DialogList.MultipleTypingSuffix")
        self._DialogList_MultipleTypingSuffix_r = extractArgumentRanges(self._DialogList_MultipleTypingSuffix)
        self.Passport_Phone_Help = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Phone.Help")
        self.Passport_Language_sl = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Language.sl")
        self.Bot_GenericBotStatus = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Bot.GenericBotStatus")
        self.PrivacySettings_PasscodeAndTouchId = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PrivacySettings.PasscodeAndTouchId")
        self.Common_edit = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Common.edit")
        self.Settings_AppLanguage = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Settings.AppLanguage")
        self.PrivacyLastSeenSettings_WhoCanSeeMyTimestamp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PrivacyLastSeenSettings.WhoCanSeeMyTimestamp")
        self._Notification_Kicked = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notification.Kicked")
        self._Notification_Kicked_r = extractArgumentRanges(self._Notification_Kicked)
        self.Channel_AdminLog_MessageRestrictedForever = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.AdminLog.MessageRestrictedForever")
        self.Passport_DeleteDocument = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.DeleteDocument")
        self.Notifications_ExceptionsResetToDefaults = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notifications.ExceptionsResetToDefaults")
        self.ChannelInfo_DeleteChannelConfirmation = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ChannelInfo.DeleteChannelConfirmation")
        self.Passport_Address_OneOfTypeBankStatement = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Address.OneOfTypeBankStatement")
        self.Weekday_ShortSaturday = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Weekday.ShortSaturday")
        self.Settings_Passport = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Settings.Passport")
        self.Share_AuthTitle = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Share.AuthTitle")
        self.Map_SendThisLocation = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Map.SendThisLocation")
        self._Notification_PinnedDocumentMessage = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notification.PinnedDocumentMessage")
        self._Notification_PinnedDocumentMessage_r = extractArgumentRanges(self._Notification_PinnedDocumentMessage)
        self.Passport_Identity_Surname = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Identity.Surname")
        self.Conversation_ContextMenuReply = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.ContextMenuReply")
        self.Channel_BanUser_PermissionSendMedia = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.BanUser.PermissionSendMedia")
        self.NetworkUsageSettings_Wifi = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "NetworkUsageSettings.Wifi")
        self.Call_Accept = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Call.Accept")
        self.GroupInfo_SetGroupPhotoDelete = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "GroupInfo.SetGroupPhotoDelete")
        self.Login_PhoneBannedError = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Login.PhoneBannedError")
        self.Passport_Identity_DocumentDetails = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Identity.DocumentDetails")
        self.PhotoEditor_CropAuto = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PhotoEditor.CropAuto")
        self.PhotoEditor_ContrastTool = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PhotoEditor.ContrastTool")
        self.CheckoutInfo_ReceiverInfoNamePlaceholder = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "CheckoutInfo.ReceiverInfoNamePlaceholder")
        self.Passport_InfoLearnMore = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.InfoLearnMore")
        self.Channel_AdminLog_MessagePreviousCaption = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.AdminLog.MessagePreviousCaption")
        self._Passport_Email_UseTelegramEmail = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Email.UseTelegramEmail")
        self._Passport_Email_UseTelegramEmail_r = extractArgumentRanges(self._Passport_Email_UseTelegramEmail)
        self.Privacy_PaymentsClear_ShippingInfo = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Privacy.PaymentsClear.ShippingInfo")
        self.Passport_Email_UseTelegramEmailHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Email.UseTelegramEmailHelp")
        self.UserInfo_NotificationsDefaultDisabled = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "UserInfo.NotificationsDefaultDisabled")
        self.Date_DialogDateFormat = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Date.DialogDateFormat")
        self.Passport_Address_EditTemporaryRegistration = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Address.EditTemporaryRegistration")
        self.ReportPeer_ReasonSpam = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ReportPeer.ReasonSpam")
        self.Privacy_Calls_P2P = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Privacy.Calls.P2P")
        self.Compose_TokenListPlaceholder = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Compose.TokenListPlaceholder")
        self._PINNED_VIDEO = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PINNED_VIDEO")
        self._PINNED_VIDEO_r = extractArgumentRanges(self._PINNED_VIDEO)
        self.StickerPacksSettings_Title = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "StickerPacksSettings.Title")
        self.Privacy_PaymentsClearInfoDoneHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Privacy.PaymentsClearInfoDoneHelp")
        self.Privacy_Calls_NeverAllow_Placeholder = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Privacy.Calls.NeverAllow.Placeholder")
        self.Passport_PassportInformation = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.PassportInformation")
        self.Passport_Identity_OneOfTypeDriversLicense = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Identity.OneOfTypeDriversLicense")
        self.Settings_Support = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Settings.Support")
        self.Notification_GroupInviterSelf = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notification.GroupInviterSelf")
        self._SecretImage_NotViewedYet = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "SecretImage.NotViewedYet")
        self._SecretImage_NotViewedYet_r = extractArgumentRanges(self._SecretImage_NotViewedYet)
        self.MaskStickerSettings_Title = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "MaskStickerSettings.Title")
        self.TwoStepAuth_SetPassword = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "TwoStepAuth.SetPassword")
        self._Passport_AcceptHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.AcceptHelp")
        self._Passport_AcceptHelp_r = extractArgumentRanges(self._Passport_AcceptHelp)
        self.SocksProxySetup_SavedProxies = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "SocksProxySetup.SavedProxies")
        self.GroupInfo_InviteLink_ShareLink = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "GroupInfo.InviteLink.ShareLink")
        self.Common_Cancel = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Common.Cancel")
        self.UserInfo_About_Placeholder = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "UserInfo.About.Placeholder")
        self.Passport_Identity_NativeNameGenericTitle = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Identity.NativeNameGenericTitle")
        self.Notifications_ChannelNotificationsPreview = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notifications.ChannelNotificationsPreview")
        self.Camera_Discard = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Camera.Discard")
        self.ChangePhoneNumberCode_RequestingACall = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ChangePhoneNumberCode.RequestingACall")
        self.PrivacyLastSeenSettings_NeverShareWith_Title = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PrivacyLastSeenSettings.NeverShareWith.Title")
        self.KeyCommand_JumpToNextChat = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "KeyCommand.JumpToNextChat")
        self._Time_MonthOfYear_m8 = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Time.MonthOfYear_m8")
        self._Time_MonthOfYear_m8_r = extractArgumentRanges(self._Time_MonthOfYear_m8)
        self.Tour_Text1 = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Tour.Text1")
        self.Privacy_SecretChatsTitle = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Privacy.SecretChatsTitle")
        self.Conversation_HoldForVideo = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.HoldForVideo")
        self.Passport_Language_pt = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Language.pt")
        self.Checkout_NewCard_Title = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Checkout.NewCard.Title")
        self.Channel_TitleInfo = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.TitleInfo")
        self.State_ConnectingToProxy = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "State.ConnectingToProxy")
        self.Settings_About_Help = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Settings.About.Help")
        self.AutoNightTheme_ScheduledFrom = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "AutoNightTheme.ScheduledFrom")
        self.Passport_Language_tk = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Language.tk")
        self.Watch_Conversation_Reply = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Watch.Conversation.Reply")
        self.ShareMenu_CopyShareLink = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ShareMenu.CopyShareLink")
        self.Stickers_Search = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Stickers.Search")
        self.Notifications_GroupNotificationsExceptions = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notifications.GroupNotificationsExceptions")
        self.Channel_Setup_TypePrivateHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.Setup.TypePrivateHelp")
        self.PhotoEditor_GrainTool = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PhotoEditor.GrainTool")
        self.Conversation_SearchByName_Placeholder = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.SearchByName.Placeholder")
        self.Watch_Suggestion_TalkLater = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Watch.Suggestion.TalkLater")
        self.TwoStepAuth_ChangeEmail = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "TwoStepAuth.ChangeEmail")
        self.Passport_Identity_EditPersonalDetails = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Identity.EditPersonalDetails")
        self.Passport_FieldPhone = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.FieldPhone")
        self._ENCRYPTION_ACCEPT = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ENCRYPTION_ACCEPT")
        self._ENCRYPTION_ACCEPT_r = extractArgumentRanges(self._ENCRYPTION_ACCEPT)
        self.NetworkUsageSettings_BytesSent = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "NetworkUsageSettings.BytesSent")
        self.Conversation_ShareBotLocationConfirmationTitle = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.ShareBotLocationConfirmationTitle")
        self.Conversation_ForwardContacts = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.ForwardContacts")
        self._Notification_ChangedGroupName = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notification.ChangedGroupName")
        self._Notification_ChangedGroupName_r = extractArgumentRanges(self._Notification_ChangedGroupName)
        self._MESSAGE_VIDEO = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "MESSAGE_VIDEO")
        self._MESSAGE_VIDEO_r = extractArgumentRanges(self._MESSAGE_VIDEO)
        self._Checkout_PayPrice = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Checkout.PayPrice")
        self._Checkout_PayPrice_r = extractArgumentRanges(self._Checkout_PayPrice)
        self._Notification_PinnedTextMessage = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notification.PinnedTextMessage")
        self._Notification_PinnedTextMessage_r = extractArgumentRanges(self._Notification_PinnedTextMessage)
        self.GroupInfo_InvitationLinkDoesNotExist = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "GroupInfo.InvitationLinkDoesNotExist")
        self.ReportPeer_ReasonOther_Placeholder = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ReportPeer.ReasonOther.Placeholder")
        self.Wallpaper_Title = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Wallpaper.Title")
        self.PasscodeSettings_AutoLock_Disabled = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PasscodeSettings.AutoLock.Disabled")
        self.Watch_Compose_CreateMessage = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Watch.Compose.CreateMessage")
        self.ChatSettings_ConnectionType_UseProxy = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ChatSettings.ConnectionType.UseProxy")
        self.Message_Audio = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Message.Audio")
        self.Conversation_SearchNoResults = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.SearchNoResults")
        self.PrivacyPolicy_Accept = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PrivacyPolicy.Accept")
        self.ReportPeer_ReasonViolence = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ReportPeer.ReasonViolence")
        self.Group_Username_RemoveExistingUsernamesInfo = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Group.Username.RemoveExistingUsernamesInfo")
        self.Message_InvoiceLabel = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Message.InvoiceLabel")
        self.Channel_AdminLogFilter_Title = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.AdminLogFilter.Title")
        self.Contacts_SearchLabel = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Contacts.SearchLabel")
        self.Group_Username_InvalidStartsWithNumber = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Group.Username.InvalidStartsWithNumber")
        self.ChatAdmins_AllMembersAreAdminsOnHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ChatAdmins.AllMembersAreAdminsOnHelp")
        self.Month_ShortSeptember = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Month.ShortSeptember")
        self.Group_Username_CreatePublicLinkHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Group.Username.CreatePublicLinkHelp")
        self.Login_CallRequestState2 = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Login.CallRequestState2")
        self.TwoStepAuth_RecoveryUnavailable = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "TwoStepAuth.RecoveryUnavailable")
        self.Bot_Unblock = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Bot.Unblock")
        self.SharedMedia_CategoryMedia = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "SharedMedia.CategoryMedia")
        self.Conversation_HoldForAudio = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.HoldForAudio")
        self.Conversation_ClousStorageInfo_Description1 = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.ClousStorageInfo.Description1")
        self.Channel_Members_InviteLink = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.Members.InviteLink")
        self.Core_ServiceUserStatus = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Core.ServiceUserStatus")
        self.WebSearch_RecentClearConfirmation = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "WebSearch.RecentClearConfirmation")
        self.Notification_ChannelMigratedFrom = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notification.ChannelMigratedFrom")
        self.Settings_Title = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Settings.Title")
        self.Call_StatusBusy = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Call.StatusBusy")
        self.ArchivedPacksAlert_Title = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ArchivedPacksAlert.Title")
        self.ConversationMedia_Title = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ConversationMedia.Title")
        self._Conversation_MessageViaUser = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.MessageViaUser")
        self._Conversation_MessageViaUser_r = extractArgumentRanges(self._Conversation_MessageViaUser)
        self.Notification_PassportValueAddress = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notification.PassportValueAddress")
        self.Tour_Title4 = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Tour.Title4")
        self.Call_StatusEnded = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Call.StatusEnded")
        self.Notifications_ChannelNotificationsAlert = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notifications.ChannelNotificationsAlert")
        self.LiveLocationUpdated_JustNow = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "LiveLocationUpdated.JustNow")
        self._Login_BannedPhoneSubject = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Login.BannedPhoneSubject")
        self._Login_BannedPhoneSubject_r = extractArgumentRanges(self._Login_BannedPhoneSubject)
        self.Passport_Address_EditResidentialAddress = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Address.EditResidentialAddress")
        self._Channel_Management_RestrictedBy = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.Management.RestrictedBy")
        self._Channel_Management_RestrictedBy_r = extractArgumentRanges(self._Channel_Management_RestrictedBy)
        self.Conversation_UnpinMessageAlert = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.UnpinMessageAlert")
        self.NotificationsSound_Glass = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "NotificationsSound.Glass")
        self.Passport_Address_Street1Placeholder = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Address.Street1Placeholder")
        self._Conversation_MessageDialogRetryAll = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.MessageDialogRetryAll")
        self._Conversation_MessageDialogRetryAll_r = extractArgumentRanges(self._Conversation_MessageDialogRetryAll)
        self._Checkout_PasswordEntry_Text = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Checkout.PasswordEntry.Text")
        self._Checkout_PasswordEntry_Text_r = extractArgumentRanges(self._Checkout_PasswordEntry_Text)
        self.Call_Message = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Call.Message")
        self.Contacts_MemberSearchSectionTitleGroup = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Contacts.MemberSearchSectionTitleGroup")
        self._Conversation_BotInteractiveUrlAlert = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.BotInteractiveUrlAlert")
        self._Conversation_BotInteractiveUrlAlert_r = extractArgumentRanges(self._Conversation_BotInteractiveUrlAlert)
        self.GroupInfo_SharedMedia = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "GroupInfo.SharedMedia")
        self._Time_PreciseDate_m6 = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Time.PreciseDate_m6")
        self._Time_PreciseDate_m6_r = extractArgumentRanges(self._Time_PreciseDate_m6)
        self.Channel_Username_InvalidStartsWithNumber = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.Username.InvalidStartsWithNumber")
        self.KeyCommand_JumpToPreviousChat = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "KeyCommand.JumpToPreviousChat")
        self.Conversation_Call = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.Call")
        self.KeyCommand_ScrollUp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "KeyCommand.ScrollUp")
        self._Privacy_GroupsAndChannels_InviteToChannelError = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Privacy.GroupsAndChannels.InviteToChannelError")
        self._Privacy_GroupsAndChannels_InviteToChannelError_r = extractArgumentRanges(self._Privacy_GroupsAndChannels_InviteToChannelError)
        self.AuthSessions_Sessions = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "AuthSessions.Sessions")
        self.Document_TargetConfirmationFormat = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Document.TargetConfirmationFormat")
        self.Group_Setup_TypeHeader = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Group.Setup.TypeHeader")
        self._DialogList_SinglePlayingGameSuffix = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "DialogList.SinglePlayingGameSuffix")
        self._DialogList_SinglePlayingGameSuffix_r = extractArgumentRanges(self._DialogList_SinglePlayingGameSuffix)
        self.AttachmentMenu_SendAsFiles = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "AttachmentMenu.SendAsFiles")
        self.Profile_MessageLifetime1m = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Profile.MessageLifetime1m")
        self.Passport_PasswordReset = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.PasswordReset")
        self.Settings_AppleWatch = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Settings.AppleWatch")
        self.Notifications_ExceptionsTitle = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notifications.ExceptionsTitle")
        self.Passport_Language_de = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Language.de")
        self.Channel_AdminLog_MessagePreviousDescription = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.AdminLog.MessagePreviousDescription")
        self.Your_card_was_declined = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Your_card_was_declined")
        self.Notifications_DisplayNamesOnLockScreen = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notifications.DisplayNamesOnLockScreen")
        self.PhoneNumberHelp_ChangeNumber = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PhoneNumberHelp.ChangeNumber")
        self.ReportPeer_ReasonPornography = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ReportPeer.ReasonPornography")
        self.Notification_CreatedChannel = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notification.CreatedChannel")
        self.PhotoEditor_Original = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PhotoEditor.Original")
        self.NotificationsSound_Chord = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "NotificationsSound.Chord")
        self.Target_SelectGroup = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Target.SelectGroup")
        self.Stickers_SuggestAdded = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Stickers.SuggestAdded")
        self.Channel_AdminLog_InfoPanelAlertTitle = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.AdminLog.InfoPanelAlertTitle")
        self.Notifications_GroupNotificationsPreview = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notifications.GroupNotificationsPreview")
        self.ChatSettings_AutoDownloadPhotos = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ChatSettings.AutoDownloadPhotos")
        self.Message_PinnedLocationMessage = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Message.PinnedLocationMessage")
        self.Appearance_PreviewReplyText = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Appearance.PreviewReplyText")
        self.Passport_Address_Street2Placeholder = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Address.Street2Placeholder")
        self.Settings_Logout = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Settings.Logout")
        self._UserInfo_BlockConfirmation = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "UserInfo.BlockConfirmation")
        self._UserInfo_BlockConfirmation_r = extractArgumentRanges(self._UserInfo_BlockConfirmation)
        self.Profile_Username = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Profile.Username")
        self.Group_Username_InvalidTooShort = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Group.Username.InvalidTooShort")
        self.Appearance_AutoNightTheme = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Appearance.AutoNightTheme")
        self.AuthSessions_TerminateOtherSessions = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "AuthSessions.TerminateOtherSessions")
        self.PasscodeSettings_TryAgainIn1Minute = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PasscodeSettings.TryAgainIn1Minute")
        self.Privacy_TopPeers = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Privacy.TopPeers")
        self.Passport_Phone_EnterOtherNumber = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Phone.EnterOtherNumber")
        self.NotificationsSound_Hello = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "NotificationsSound.Hello")
        self.Notifications_InAppNotifications = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notifications.InAppNotifications")
        self._Notification_PassportValuesSentMessage = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notification.PassportValuesSentMessage")
        self._Notification_PassportValuesSentMessage_r = extractArgumentRanges(self._Notification_PassportValuesSentMessage)
        self.Passport_Language_is = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Language.is")
        self.StickerPack_ViewPack = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "StickerPack.ViewPack")
        self.EnterPasscode_ChangeTitle = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "EnterPasscode.ChangeTitle")
        self.Call_Decline = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Call.Decline")
        self.UserInfo_AddPhone = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "UserInfo.AddPhone")
        self.AutoNightTheme_Title = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "AutoNightTheme.Title")
        self.Activity_PlayingGame = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Activity.PlayingGame")
        self.CheckoutInfo_ShippingInfoStatePlaceholder = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "CheckoutInfo.ShippingInfoStatePlaceholder")
        self.SaveIncomingPhotosSettings_From = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "SaveIncomingPhotosSettings.From")
        self.Passport_Address_TypeBankStatementUploadScan = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Address.TypeBankStatementUploadScan")
        self.Notifications_MessageNotificationsSound = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notifications.MessageNotificationsSound")
        self.Call_StatusWaiting = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Call.StatusWaiting")
        self.Passport_Identity_MainPageHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Identity.MainPageHelp")
        self.Weekday_ShortWednesday = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Weekday.ShortWednesday")
        self.Notifications_Title = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notifications.Title")
        self.PasscodeSettings_AutoLock_IfAwayFor_5hours = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PasscodeSettings.AutoLock.IfAwayFor_5hours")
        self.Conversation_PinnedMessage = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.PinnedMessage")
        self.Notifications_ChannelNotificationsHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notifications.ChannelNotificationsHelp")
        self._Time_MonthOfYear_m12 = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Time.MonthOfYear_m12")
        self._Time_MonthOfYear_m12_r = extractArgumentRanges(self._Time_MonthOfYear_m12)
        self.ConversationProfile_LeaveDeleteAndExit = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ConversationProfile.LeaveDeleteAndExit")
        self.State_connecting = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "State.connecting")
        self.Channel_AdminLog_MessagePreviousMessage = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.AdminLog.MessagePreviousMessage")
        self.Passport_Scans_Upload = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Scans.Upload")
        self.AutoDownloadSettings_PhotosTitle = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "AutoDownloadSettings.PhotosTitle")
        self.Map_OpenInHereMaps = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Map.OpenInHereMaps")
        self.Stickers_FavoriteStickers = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Stickers.FavoriteStickers")
        self.CheckoutInfo_Pay = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "CheckoutInfo.Pay")
        self.Passport_Identity_FrontSideHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Identity.FrontSideHelp")
        self.Update_UpdateApp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Update.UpdateApp")
        self.Login_CountryCode = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Login.CountryCode")
        self.PasscodeSettings_AutoLock_IfAwayFor_1hour = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PasscodeSettings.AutoLock.IfAwayFor_1hour")
        self.CheckoutInfo_ShippingInfoState = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "CheckoutInfo.ShippingInfoState")
        self._CHAT_MESSAGE_AUDIO = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "CHAT_MESSAGE_AUDIO")
        self._CHAT_MESSAGE_AUDIO_r = extractArgumentRanges(self._CHAT_MESSAGE_AUDIO)
        self.Login_SmsRequestState2 = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Login.SmsRequestState2")
        self.Preview_SaveToCameraRoll = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Preview.SaveToCameraRoll")
        self.SocksProxySetup_ProxyStatusConnecting = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "SocksProxySetup.ProxyStatusConnecting")
        self.Broadcast_AdminLog_EmptyText = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Broadcast.AdminLog.EmptyText")
        self.PasscodeSettings_ChangePasscode = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PasscodeSettings.ChangePasscode")
        self.TwoStepAuth_RecoveryCodeInvalid = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "TwoStepAuth.RecoveryCodeInvalid")
        self._Message_PaymentSent = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Message.PaymentSent")
        self._Message_PaymentSent_r = extractArgumentRanges(self._Message_PaymentSent)
        self.Message_PinnedAudioMessage = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Message.PinnedAudioMessage")
        self.ChatSettings_ConnectionType_Title = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ChatSettings.ConnectionType.Title")
        self._Conversation_RestrictedMediaTimed = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.RestrictedMediaTimed")
        self._Conversation_RestrictedMediaTimed_r = extractArgumentRanges(self._Conversation_RestrictedMediaTimed)
        self.NotificationsSound_Complete = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "NotificationsSound.Complete")
        self.NotificationsSound_Chime = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "NotificationsSound.Chime")
        self.Login_InfoDeletePhoto = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Login.InfoDeletePhoto")
        self.ContactInfo_BirthdayLabel = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ContactInfo.BirthdayLabel")
        self.TwoStepAuth_RecoveryCodeExpired = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "TwoStepAuth.RecoveryCodeExpired")
        self.AutoDownloadSettings_Channels = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "AutoDownloadSettings.Channels")
        self.AutoDownloadSettings_Contacts = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "AutoDownloadSettings.Contacts")
        self.TwoStepAuth_EmailTitle = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "TwoStepAuth.EmailTitle")
        self.Passport_Email_EmailPlaceholder = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Email.EmailPlaceholder")
        self.Channel_AdminLog_ChannelEmptyText = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.AdminLog.ChannelEmptyText")
        self.Passport_Address_EditUtilityBill = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Address.EditUtilityBill")
        self.Privacy_GroupsAndChannels_NeverAllow = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Privacy.GroupsAndChannels.NeverAllow")
        self.Conversation_RestrictedStickers = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.RestrictedStickers")
        self.Conversation_AddContact = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.AddContact")
        self._Time_MonthOfYear_m7 = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Time.MonthOfYear_m7")
        self._Time_MonthOfYear_m7_r = extractArgumentRanges(self._Time_MonthOfYear_m7)
        self.PhotoEditor_QualityLow = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PhotoEditor.QualityLow")
        self.Paint_Outlined = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Paint.Outlined")
        self.State_ConnectingToProxyInfo = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "State.ConnectingToProxyInfo")
        self.Checkout_PasswordEntry_Title = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Checkout.PasswordEntry.Title")
        self.Conversation_InputTextCaptionPlaceholder = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.InputTextCaptionPlaceholder")
        self.Common_Done = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Common.Done")
        self.Passport_Identity_FilesUploadNew = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Identity.FilesUploadNew")
        self.PrivacySettings_LastSeenContacts = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PrivacySettings.LastSeenContacts")
        self.Passport_Language_vi = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Language.vi")
        self.CheckoutInfo_ShippingInfoAddress1 = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "CheckoutInfo.ShippingInfoAddress1")
        self.UserInfo_LastNamePlaceholder = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "UserInfo.LastNamePlaceholder")
        self.Conversation_StatusKickedFromChannel = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.StatusKickedFromChannel")
        self.CheckoutInfo_ShippingInfoAddress2 = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "CheckoutInfo.ShippingInfoAddress2")
        self._DialogList_SingleTypingSuffix = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "DialogList.SingleTypingSuffix")
        self._DialogList_SingleTypingSuffix_r = extractArgumentRanges(self._DialogList_SingleTypingSuffix)
        self.LastSeen_JustNow = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "LastSeen.JustNow")
        self.GroupInfo_InviteLink_RevokeAlert_Text = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "GroupInfo.InviteLink.RevokeAlert.Text")
        self.BroadcastListInfo_AddRecipient = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "BroadcastListInfo.AddRecipient")
        self._Channel_Management_ErrorNotMember = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.Management.ErrorNotMember")
        self._Channel_Management_ErrorNotMember_r = extractArgumentRanges(self._Channel_Management_ErrorNotMember)
        self.Privacy_Calls_NeverAllow = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Privacy.Calls.NeverAllow")
        self.Settings_About_Title = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Settings.About.Title")
        self.PhoneNumberHelp_Help = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PhoneNumberHelp.Help")
        self.Channel_LinkItem = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.LinkItem")
        self.Camera_Retake = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Camera.Retake")
        self.StickerPack_ShowStickers = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "StickerPack.ShowStickers")
        self.Conversation_RestrictedText = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.RestrictedText")
        self.Channel_Stickers_YourStickers = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.Stickers.YourStickers")
        self._CHAT_CREATED = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "CHAT_CREATED")
        self._CHAT_CREATED_r = extractArgumentRanges(self._CHAT_CREATED)
        self.LastSeen_WithinAMonth = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "LastSeen.WithinAMonth")
        self._PrivacySettings_LastSeenContactsPlus = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PrivacySettings.LastSeenContactsPlus")
        self._PrivacySettings_LastSeenContactsPlus_r = extractArgumentRanges(self._PrivacySettings_LastSeenContactsPlus)
        self.ChangePhoneNumberNumber_NewNumber = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ChangePhoneNumberNumber.NewNumber")
        self.Compose_NewChannel = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Compose.NewChannel")
        self.NotificationsSound_Circles = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "NotificationsSound.Circles")
        self.Login_TermsOfServiceAgree = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Login.TermsOfServiceAgree")
        self.Channel_AdminLog_CanChangeInviteLink = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.AdminLog.CanChangeInviteLink")
        self._Passport_RequestHeader = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.RequestHeader")
        self._Passport_RequestHeader_r = extractArgumentRanges(self._Passport_RequestHeader)
        self._Call_CallInProgressMessage = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Call.CallInProgressMessage")
        self._Call_CallInProgressMessage_r = extractArgumentRanges(self._Call_CallInProgressMessage)
        self.Conversation_InputTextBroadcastPlaceholder = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.InputTextBroadcastPlaceholder")
        self._ShareFileTip_Text = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ShareFileTip.Text")
        self._ShareFileTip_Text_r = extractArgumentRanges(self._ShareFileTip_Text)
        self._CancelResetAccount_TextSMS = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "CancelResetAccount.TextSMS")
        self._CancelResetAccount_TextSMS_r = extractArgumentRanges(self._CancelResetAccount_TextSMS)
        self.Channel_EditAdmin_PermissionInviteUsers = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.EditAdmin.PermissionInviteUsers")
        self.Privacy_Calls_P2PNever = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Privacy.Calls.P2PNever")
        self.GroupInfo_DeleteAndExit = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "GroupInfo.DeleteAndExit")
        self.GroupInfo_InviteLink_CopyLink = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "GroupInfo.InviteLink.CopyLink")
        self.Weekday_Friday = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Weekday.Friday")
        self.Login_ResetAccountProtected_Title = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Login.ResetAccountProtected.Title")
        self.Settings_SetProfilePhoto = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Settings.SetProfilePhoto")
        self.Compose_ChannelTokenListPlaceholder = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Compose.ChannelTokenListPlaceholder")
        self.Channel_EditAdmin_PermissionPinMessages = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.EditAdmin.PermissionPinMessages")
        self.Your_card_has_expired = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Your_card_has_expired")
        self._CHAT_MESSAGE_INVOICE = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "CHAT_MESSAGE_INVOICE")
        self._CHAT_MESSAGE_INVOICE_r = extractArgumentRanges(self._CHAT_MESSAGE_INVOICE)
        self.ChannelInfo_ConfirmLeave = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ChannelInfo.ConfirmLeave")
        self.ShareMenu_CopyShareLinkGame = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ShareMenu.CopyShareLinkGame")
        self.ReportPeer_ReasonOther = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ReportPeer.ReasonOther")
        self._Username_UsernameIsAvailable = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Username.UsernameIsAvailable")
        self._Username_UsernameIsAvailable_r = extractArgumentRanges(self._Username_UsernameIsAvailable)
        self.KeyCommand_JumpToNextUnreadChat = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "KeyCommand.JumpToNextUnreadChat")
        self.InfoPlist_NSContactsUsageDescription = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "InfoPlist.NSContactsUsageDescription")
        self._SocksProxySetup_ProxyStatusPing = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "SocksProxySetup.ProxyStatusPing")
        self._SocksProxySetup_ProxyStatusPing_r = extractArgumentRanges(self._SocksProxySetup_ProxyStatusPing)
        self._Date_ChatDateHeader = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Date.ChatDateHeader")
        self._Date_ChatDateHeader_r = extractArgumentRanges(self._Date_ChatDateHeader)
        self.Conversation_EncryptedDescriptionTitle = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.EncryptedDescriptionTitle")
        self.DialogList_Pin = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "DialogList.Pin")
        self._Notification_RemovedGroupPhoto = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notification.RemovedGroupPhoto")
        self._Notification_RemovedGroupPhoto_r = extractArgumentRanges(self._Notification_RemovedGroupPhoto)
        self.Channel_ErrorAddTooMuch = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.ErrorAddTooMuch")
        self.GroupInfo_SharedMediaNone = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "GroupInfo.SharedMediaNone")
        self.ChatSettings_TextSizeUnits = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ChatSettings.TextSizeUnits")
        self.ChatSettings_AutoPlayAnimations = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ChatSettings.AutoPlayAnimations")
        self.Conversation_FileOpenIn = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.FileOpenIn")
        self.Channel_Setup_TypePublic = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.Setup.TypePublic")
        self._ChangePhone_ErrorOccupied = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ChangePhone.ErrorOccupied")
        self._ChangePhone_ErrorOccupied_r = extractArgumentRanges(self._ChangePhone_ErrorOccupied)
        self.ContactInfo_PhoneLabelMain = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ContactInfo.PhoneLabelMain")
        self.Clipboard_SendPhoto = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Clipboard.SendPhoto")
        self.Privacy_GroupsAndChannels_CustomShareHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Privacy.GroupsAndChannels.CustomShareHelp")
        self.KeyCommand_ChatInfo = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "KeyCommand.ChatInfo")
        self.Channel_AdminLog_EmptyFilterTitle = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.AdminLog.EmptyFilterTitle")
        self.PhotoEditor_HighlightsTint = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PhotoEditor.HighlightsTint")
        self.Passport_Address_Region = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Address.Region")
        self.Watch_Compose_AddContact = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Watch.Compose.AddContact")
        self._Time_PreciseDate_m5 = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Time.PreciseDate_m5")
        self._Time_PreciseDate_m5_r = extractArgumentRanges(self._Time_PreciseDate_m5)
        self._Channel_AdminLog_MessageKickedNameUsername = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.AdminLog.MessageKickedNameUsername")
        self._Channel_AdminLog_MessageKickedNameUsername_r = extractArgumentRanges(self._Channel_AdminLog_MessageKickedNameUsername)
        self._Login_WillSendSms = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Login.WillSendSms")
        self._Login_WillSendSms_r = extractArgumentRanges(self._Login_WillSendSms)
        self.Coub_TapForSound = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Coub.TapForSound")
        self.Compose_NewEncryptedChat = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Compose.NewEncryptedChat")
        self.PhotoEditor_CropReset = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PhotoEditor.CropReset")
        self.Privacy_Calls_P2PAlways = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Privacy.Calls.P2PAlways")
        self.Passport_Address_TypeTemporaryRegistrationUploadScan = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Address.TypeTemporaryRegistrationUploadScan")
        self.Login_InvalidLastNameError = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Login.InvalidLastNameError")
        self.Channel_Members_AddMembers = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.Members.AddMembers")
        self.Tour_Title2 = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Tour.Title2")
        self.Login_TermsOfServiceHeader = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Login.TermsOfServiceHeader")
        self.Channel_AdminLog_BanSendGifs = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.AdminLog.BanSendGifs")
        self.Login_TermsOfServiceSignupDecline = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Login.TermsOfServiceSignupDecline")
        self.InfoPlist_NSMicrophoneUsageDescription = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "InfoPlist.NSMicrophoneUsageDescription")
        self.AuthSessions_OtherSessions = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "AuthSessions.OtherSessions")
        self.Watch_UserInfo_Title = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Watch.UserInfo.Title")
        self.InstantPage_FeedbackButton = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "InstantPage.FeedbackButton")
        self._Generic_OpenHiddenLinkAlert = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Generic.OpenHiddenLinkAlert")
        self._Generic_OpenHiddenLinkAlert_r = extractArgumentRanges(self._Generic_OpenHiddenLinkAlert)
        self.Conversation_Contact = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.Contact")
        self.NetworkUsageSettings_GeneralDataSection = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "NetworkUsageSettings.GeneralDataSection")
        self.EnterPasscode_RepeatNewPasscode = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "EnterPasscode.RepeatNewPasscode")
        self.Conversation_ContextMenuCopyLink = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.ContextMenuCopyLink")
        self.Passport_Language_sk = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Language.sk")
        self.InstantPage_AutoNightTheme = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "InstantPage.AutoNightTheme")
        self.CloudStorage_Title = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "CloudStorage.Title")
        self.Month_ShortOctober = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Month.ShortOctober")
        self.Settings_FAQ = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Settings.FAQ")
        self.PrivacySettings_LastSeen = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PrivacySettings.LastSeen")
        self.DialogList_SearchSectionRecent = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "DialogList.SearchSectionRecent")
        self.ChatSettings_AutomaticVideoMessageDownload = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ChatSettings.AutomaticVideoMessageDownload")
        self.Conversation_ContextMenuDelete = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.ContextMenuDelete")
        self.Tour_Text6 = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Tour.Text6")
        self.PhotoEditor_WarmthTool = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PhotoEditor.WarmthTool")
        self.Passport_Address_TypePassportRegistrationUploadScan = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Address.TypePassportRegistrationUploadScan")
        self.Common_TakePhoto = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Common.TakePhoto")
        self.SocksProxySetup_AdNoticeHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "SocksProxySetup.AdNoticeHelp")
        self.UserInfo_CreateNewContact = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "UserInfo.CreateNewContact")
        self.NetworkUsageSettings_MediaDocumentDataSection = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "NetworkUsageSettings.MediaDocumentDataSection")
        self.Login_CodeSentCall = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Login.CodeSentCall")
        self.Watch_PhotoView_Title = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Watch.PhotoView.Title")
        self._PrivacySettings_LastSeenContactsMinus = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PrivacySettings.LastSeenContactsMinus")
        self._PrivacySettings_LastSeenContactsMinus_r = extractArgumentRanges(self._PrivacySettings_LastSeenContactsMinus)
        self.ShareMenu_SelectChats = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ShareMenu.SelectChats")
        self.Group_ErrorSendRestrictedMedia = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Group.ErrorSendRestrictedMedia")
        self.Group_Setup_HistoryVisible = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Group.Setup.HistoryVisible")
        self.Channel_EditAdmin_PermissinAddAdminOff = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.EditAdmin.PermissinAddAdminOff")
        self.DialogList_ProxyConnectionIssuesTooltip = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "DialogList.ProxyConnectionIssuesTooltip")
        self.Cache_Files = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Cache.Files")
        self.PhotoEditor_EnhanceTool = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PhotoEditor.EnhanceTool")
        self.Conversation_SearchPlaceholder = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.SearchPlaceholder")
        self.Channel_Stickers_NotFound = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.Stickers.NotFound")
        self.UserInfo_NotificationsDefaultEnabled = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "UserInfo.NotificationsDefaultEnabled")
        self.WatchRemote_AlertText = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "WatchRemote.AlertText")
        self.Channel_AdminLog_CanInviteUsers = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.AdminLog.CanInviteUsers")
        self.Channel_BanUser_PermissionReadMessages = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.BanUser.PermissionReadMessages")
        self.AttachmentMenu_PhotoOrVideo = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "AttachmentMenu.PhotoOrVideo")
        self.Passport_Identity_GenderPlaceholder = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Identity.GenderPlaceholder")
        self.Month_ShortMarch = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Month.ShortMarch")
        self.GroupInfo_InviteLink_Title = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "GroupInfo.InviteLink.Title")
        self.Watch_LastSeen_JustNow = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Watch.LastSeen.JustNow")
        self.PhoneLabel_Title = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PhoneLabel.Title")
        self.PrivacySettings_Passcode = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PrivacySettings.Passcode")
        self.Paint_ClearConfirm = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Paint.ClearConfirm")
        self.SocksProxySetup_Secret = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "SocksProxySetup.Secret")
        self._Checkout_SavePasswordTimeout = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Checkout.SavePasswordTimeout")
        self._Checkout_SavePasswordTimeout_r = extractArgumentRanges(self._Checkout_SavePasswordTimeout)
        self.PhotoEditor_BlurToolOff = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PhotoEditor.BlurToolOff")
        self.AccessDenied_VideoMicrophone = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "AccessDenied.VideoMicrophone")
        self.Weekday_ShortThursday = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Weekday.ShortThursday")
        self.UserInfo_ShareContact = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "UserInfo.ShareContact")
        self.LoginPassword_InvalidPasswordError = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "LoginPassword.InvalidPasswordError")
        self.NotificationsSound_Calypso = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "NotificationsSound.Calypso")
        self._MESSAGE_PHOTO_SECRET = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "MESSAGE_PHOTO_SECRET")
        self._MESSAGE_PHOTO_SECRET_r = extractArgumentRanges(self._MESSAGE_PHOTO_SECRET)
        self.Login_PhoneAndCountryHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Login.PhoneAndCountryHelp")
        self.CheckoutInfo_ReceiverInfoName = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "CheckoutInfo.ReceiverInfoName")
        self.NotificationsSound_Popcorn = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "NotificationsSound.Popcorn")
        self._Time_YesterdayAt = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Time.YesterdayAt")
        self._Time_YesterdayAt_r = extractArgumentRanges(self._Time_YesterdayAt)
        self.Weekday_Yesterday = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Weekday.Yesterday")
        self.Conversation_InputTextSilentBroadcastPlaceholder = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.InputTextSilentBroadcastPlaceholder")
        self.Embed_PlayingInPIP = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Embed.PlayingInPIP")
        self.Localization_EnglishLanguageName = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Localization.EnglishLanguageName")
        self.Call_StatusIncoming = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Call.StatusIncoming")
        self.Settings_Appearance = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Settings.Appearance")
        self.Settings_PrivacySettings = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Settings.PrivacySettings")
        self.Conversation_SilentBroadcastTooltipOn = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.SilentBroadcastTooltipOn")
        self._SecretVideo_NotViewedYet = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "SecretVideo.NotViewedYet")
        self._SecretVideo_NotViewedYet_r = extractArgumentRanges(self._SecretVideo_NotViewedYet)
        self._CHAT_MESSAGE_GEO = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "CHAT_MESSAGE_GEO")
        self._CHAT_MESSAGE_GEO_r = extractArgumentRanges(self._CHAT_MESSAGE_GEO)
        self.DialogList_SearchLabel = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "DialogList.SearchLabel")
        self.InfoPlist_NSLocationAlwaysAndWhenInUseUsageDescription = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "InfoPlist.NSLocationAlwaysAndWhenInUseUsageDescription")
        self.Login_CodeSentInternal = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Login.CodeSentInternal")
        self.Channel_AdminLog_BanSendMessages = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.AdminLog.BanSendMessages")
        self.Channel_MessagePhotoRemoved = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.MessagePhotoRemoved")
        self.Conversation_StatusKickedFromGroup = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.StatusKickedFromGroup")
        self.GroupInfo_ChatAdmins = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "GroupInfo.ChatAdmins")
        self.PhotoEditor_CurvesAll = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PhotoEditor.CurvesAll")
        self._Notification_LeftChannel = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notification.LeftChannel")
        self._Notification_LeftChannel_r = extractArgumentRanges(self._Notification_LeftChannel)
        self.Compose_Create = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Compose.Create")
        self._Passport_Identity_NativeNameGenericHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Identity.NativeNameGenericHelp")
        self._Passport_Identity_NativeNameGenericHelp_r = extractArgumentRanges(self._Passport_Identity_NativeNameGenericHelp)
        self._LOCKED_MESSAGE = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "LOCKED_MESSAGE")
        self._LOCKED_MESSAGE_r = extractArgumentRanges(self._LOCKED_MESSAGE)
        self.Conversation_ClearPrivateHistory = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.ClearPrivateHistory")
        self.Conversation_ContextMenuShare = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.ContextMenuShare")
        self.Notifications_ExceptionsNone = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notifications.ExceptionsNone")
        self._Time_MonthOfYear_m6 = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Time.MonthOfYear_m6")
        self._Time_MonthOfYear_m6_r = extractArgumentRanges(self._Time_MonthOfYear_m6)
        self.Conversation_ContextMenuReport = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.ContextMenuReport")
        self._Call_GroupFormat = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Call.GroupFormat")
        self._Call_GroupFormat_r = extractArgumentRanges(self._Call_GroupFormat)
        self.Forward_ChannelReadOnly = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Forward.ChannelReadOnly")
        self.Passport_InfoText = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.InfoText")
        self.Privacy_GroupsAndChannels_NeverAllow_Title = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Privacy.GroupsAndChannels.NeverAllow.Title")
        self._Passport_Address_UploadOneOfScan = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Address.UploadOneOfScan")
        self._Passport_Address_UploadOneOfScan_r = extractArgumentRanges(self._Passport_Address_UploadOneOfScan)
        self.AutoDownloadSettings_Reset = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "AutoDownloadSettings.Reset")
        self.NotificationsSound_Synth = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "NotificationsSound.Synth")
        self._Channel_AdminLog_MessageInvitedName = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.AdminLog.MessageInvitedName")
        self._Channel_AdminLog_MessageInvitedName_r = extractArgumentRanges(self._Channel_AdminLog_MessageInvitedName)
        self.Conversation_Moderate_Ban = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.Moderate.Ban")
        self.Group_Status = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Group.Status")
        self.SocksProxySetup_ShareProxyList = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "SocksProxySetup.ShareProxyList")
        self.Passport_Phone_Delete = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Phone.Delete")
        self.Conversation_InputTextPlaceholder = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.InputTextPlaceholder")
        self.ContactInfo_PhoneLabelOther = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ContactInfo.PhoneLabelOther")
        self.Passport_Language_lv = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Language.lv")
        self.TwoStepAuth_RecoveryCode = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "TwoStepAuth.RecoveryCode")
        self.Conversation_EditingMessageMediaEditCurrentPhoto = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.EditingMessageMediaEditCurrentPhoto")
        self.Passport_DeleteDocumentConfirmation = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.DeleteDocumentConfirmation")
        self.Passport_Language_hy = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Language.hy")
        self.SharedMedia_CategoryDocs = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "SharedMedia.CategoryDocs")
        self.Channel_AdminLog_CanChangeInfo = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.AdminLog.CanChangeInfo")
        self.Channel_AdminLogFilter_EventsAdmins = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.AdminLogFilter.EventsAdmins")
        self.Group_Setup_HistoryHiddenHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Group.Setup.HistoryHiddenHelp")
        self._AuthSessions_AppUnofficial = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "AuthSessions.AppUnofficial")
        self._AuthSessions_AppUnofficial_r = extractArgumentRanges(self._AuthSessions_AppUnofficial)
        self.NotificationsSound_Telegraph = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "NotificationsSound.Telegraph")
        self.AutoNightTheme_Disabled = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "AutoNightTheme.Disabled")
        self.Conversation_ContextMenuBan = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.ContextMenuBan")
        self.Channel_EditAdmin_PermissionsHeader = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.EditAdmin.PermissionsHeader")
        self.SocksProxySetup_PortPlaceholder = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "SocksProxySetup.PortPlaceholder")
        self._DialogList_SingleUploadingVideoSuffix = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "DialogList.SingleUploadingVideoSuffix")
        self._DialogList_SingleUploadingVideoSuffix_r = extractArgumentRanges(self._DialogList_SingleUploadingVideoSuffix)
        self.Group_UpgradeNoticeHeader = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Group.UpgradeNoticeHeader")
        self._CHAT_DELETE_YOU = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "CHAT_DELETE_YOU")
        self._CHAT_DELETE_YOU_r = extractArgumentRanges(self._CHAT_DELETE_YOU)
        self._MESSAGE_NOTEXT = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "MESSAGE_NOTEXT")
        self._MESSAGE_NOTEXT_r = extractArgumentRanges(self._MESSAGE_NOTEXT)
        self._CHAT_MESSAGE_GIF = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "CHAT_MESSAGE_GIF")
        self._CHAT_MESSAGE_GIF_r = extractArgumentRanges(self._CHAT_MESSAGE_GIF)
        self.GroupInfo_InviteLink_CopyAlert_Success = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "GroupInfo.InviteLink.CopyAlert.Success")
        self.Channel_Info_Members = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.Info.Members")
        self.ShareFileTip_CloseTip = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ShareFileTip.CloseTip")
        self.KeyCommand_Find = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "KeyCommand.Find")
        self.SecretVideo_Title = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "SecretVideo.Title")
        self.Passport_DeleteAddressConfirmation = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.DeleteAddressConfirmation")
        self.Passport_DiscardMessageAction = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.DiscardMessageAction")
        self.Passport_Language_dv = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Language.dv")
        self.Checkout_NewCard_PostcodeTitle = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Checkout.NewCard.PostcodeTitle")
        self.Notifications_Badge_CountUnreadMessages_InfoOn = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notifications.Badge.CountUnreadMessages.InfoOn")
        self._Channel_AdminLog_MessageRestricted = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.AdminLog.MessageRestricted")
        self._Channel_AdminLog_MessageRestricted_r = extractArgumentRanges(self._Channel_AdminLog_MessageRestricted)
        self.SocksProxySetup_SecretPlaceholder = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "SocksProxySetup.SecretPlaceholder")
        self.Channel_EditAdmin_PermissinAddAdminOn = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.EditAdmin.PermissinAddAdminOn")
        self.WebSearch_GIFs = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "WebSearch.GIFs")
        self.Privacy_ChatsTitle = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Privacy.ChatsTitle")
        self.Conversation_SavedMessages = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.SavedMessages")
        self.TwoStepAuth_EnterPasswordTitle = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "TwoStepAuth.EnterPasswordTitle")
        self._CHANNEL_MESSAGE_GAME = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "CHANNEL_MESSAGE_GAME")
        self._CHANNEL_MESSAGE_GAME_r = extractArgumentRanges(self._CHANNEL_MESSAGE_GAME)
        self.Channel_Subscribers_Title = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.Subscribers.Title")
        self.AccessDenied_CallMicrophone = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "AccessDenied.CallMicrophone")
        self.Conversation_DeleteMessagesForEveryone = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.DeleteMessagesForEveryone")
        self.UserInfo_TapToCall = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "UserInfo.TapToCall")
        self.Common_Edit = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Common.Edit")
        self.Conversation_OpenFile = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.OpenFile")
        self.PrivacyPolicy_Decline = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PrivacyPolicy.Decline")
        self.Passport_Identity_ResidenceCountryPlaceholder = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Identity.ResidenceCountryPlaceholder")
        self.Message_PinnedDocumentMessage = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Message.PinnedDocumentMessage")
        self.AuthSessions_LogOut = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "AuthSessions.LogOut")
        self.AutoDownloadSettings_PrivateChats = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "AutoDownloadSettings.PrivateChats")
        self.Checkout_TotalPaidAmount = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Checkout.TotalPaidAmount")
        self.Conversation_UnsupportedMedia = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.UnsupportedMedia")
        self.Passport_InvalidPasswordError = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.InvalidPasswordError")
        self._Message_ForwardedMessage = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Message.ForwardedMessage")
        self._Message_ForwardedMessage_r = extractArgumentRanges(self._Message_ForwardedMessage)
        self._Time_PreciseDate_m4 = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Time.PreciseDate_m4")
        self._Time_PreciseDate_m4_r = extractArgumentRanges(self._Time_PreciseDate_m4)
        self.Checkout_NewCard_SaveInfoEnableHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Checkout.NewCard.SaveInfoEnableHelp")
        self.Call_AudioRouteHide = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Call.AudioRouteHide")
        self.CallSettings_OnMobile = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "CallSettings.OnMobile")
        self.Conversation_GifTooltip = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.GifTooltip")
        self.Passport_Address_EditBankStatement = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Address.EditBankStatement")
        self.CheckoutInfo_ErrorCityInvalid = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "CheckoutInfo.ErrorCityInvalid")
        self._CHANNEL_MESSAGE_PHOTOS = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "CHANNEL_MESSAGE_PHOTOS")
        self._CHANNEL_MESSAGE_PHOTOS_r = extractArgumentRanges(self._CHANNEL_MESSAGE_PHOTOS)
        self.Profile_CreateEncryptedChatError = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Profile.CreateEncryptedChatError")
        self.Map_LocationTitle = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Map.LocationTitle")
        self.Call_RateCall = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Call.RateCall")
        self.Passport_Address_City = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Address.City")
        self.SocksProxySetup_PasswordPlaceholder = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "SocksProxySetup.PasswordPlaceholder")
        self.Message_ReplyActionButtonShowReceipt = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Message.ReplyActionButtonShowReceipt")
        self.PhotoEditor_ShadowsTool = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PhotoEditor.ShadowsTool")
        self.Checkout_NewCard_CardholderNamePlaceholder = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Checkout.NewCard.CardholderNamePlaceholder")
        self.Cache_Title = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Cache.Title")
        self.Passport_Email_Title = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Email.Title")
        self.Month_GenMay = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Month.GenMay")
        self.PasscodeSettings_HelpBottom = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PasscodeSettings.HelpBottom")
        self._Notification_CreatedChat = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notification.CreatedChat")
        self._Notification_CreatedChat_r = extractArgumentRanges(self._Notification_CreatedChat)
        self.Calls_NoMissedCallsPlacehoder = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Calls.NoMissedCallsPlacehoder")
        self.Passport_Address_RegionPlaceholder = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Address.RegionPlaceholder")
        self.Channel_Stickers_NotFoundHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.Stickers.NotFoundHelp")
        self.Watch_UserInfo_Block = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Watch.UserInfo.Block")
        self.Watch_LastSeen_ALongTimeAgo = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Watch.LastSeen.ALongTimeAgo")
        self.StickerPacksSettings_ManagingHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "StickerPacksSettings.ManagingHelp")
        self.Privacy_GroupsAndChannels_InviteToChannelMultipleError = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Privacy.GroupsAndChannels.InviteToChannelMultipleError")
        self.SearchImages_Title = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "SearchImages.Title")
        self.Channel_BlackList_Title = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.BlackList.Title")
        self._Conversation_LiveLocationYouAnd = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.LiveLocationYouAnd")
        self._Conversation_LiveLocationYouAnd_r = extractArgumentRanges(self._Conversation_LiveLocationYouAnd)
        self.TwoStepAuth_PasswordRemovePassportConfirmation = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "TwoStepAuth.PasswordRemovePassportConfirmation")
        self.Checkout_NewCard_SaveInfo = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Checkout.NewCard.SaveInfo")
        self.Notification_CallMissed = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notification.CallMissed")
        self.Profile_ShareContactButton = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Profile.ShareContactButton")
        self.Group_ErrorSendRestrictedStickers = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Group.ErrorSendRestrictedStickers")
        self.Bot_GroupStatusDoesNotReadHistory = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Bot.GroupStatusDoesNotReadHistory")
        self.Notification_Mute1h = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notification.Mute1h")
        self._Channel_AdminLog_MessageUnkickedName = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.AdminLog.MessageUnkickedName")
        self._Channel_AdminLog_MessageUnkickedName_r = extractArgumentRanges(self._Channel_AdminLog_MessageUnkickedName)
        self.Settings_TabTitle = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Settings.TabTitle")
        self.Passport_Identity_ExpiryDatePlaceholder = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Identity.ExpiryDatePlaceholder")
        self.NetworkUsageSettings_MediaAudioDataSection = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "NetworkUsageSettings.MediaAudioDataSection")
        self.GroupInfo_DeactivatedStatus = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "GroupInfo.DeactivatedStatus")
        self._CHAT_PHOTO_EDITED = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "CHAT_PHOTO_EDITED")
        self._CHAT_PHOTO_EDITED_r = extractArgumentRanges(self._CHAT_PHOTO_EDITED)
        self.Conversation_ContextMenuMore = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.ContextMenuMore")
        self._PrivacySettings_LastSeenEverybodyMinus = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PrivacySettings.LastSeenEverybodyMinus")
        self._PrivacySettings_LastSeenEverybodyMinus_r = extractArgumentRanges(self._PrivacySettings_LastSeenEverybodyMinus)
        self.Map_ShareLiveLocation = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Map.ShareLiveLocation")
        self.Weekday_Today = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Weekday.Today")
        self._PINNED_GEOLIVE = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PINNED_GEOLIVE")
        self._PINNED_GEOLIVE_r = extractArgumentRanges(self._PINNED_GEOLIVE)
        self._Conversation_RestrictedStickersTimed = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.RestrictedStickersTimed")
        self._Conversation_RestrictedStickersTimed_r = extractArgumentRanges(self._Conversation_RestrictedStickersTimed)
        self.Login_InvalidFirstNameError = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Login.InvalidFirstNameError")
        self._Channel_AdminLog_MessageUnkickedNameUsername = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.AdminLog.MessageUnkickedNameUsername")
        self._Channel_AdminLog_MessageUnkickedNameUsername_r = extractArgumentRanges(self._Channel_AdminLog_MessageUnkickedNameUsername)
        self._Notification_Joined = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notification.Joined")
        self._Notification_Joined_r = extractArgumentRanges(self._Notification_Joined)
        self.Paint_Clear = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Paint.Clear")
        self.TwoStepAuth_RecoveryFailed = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "TwoStepAuth.RecoveryFailed")
        self._MESSAGE_AUDIO = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "MESSAGE_AUDIO")
        self._MESSAGE_AUDIO_r = extractArgumentRanges(self._MESSAGE_AUDIO)
        self.Checkout_PasswordEntry_Pay = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Checkout.PasswordEntry.Pay")
        self.Conversation_EditingMessagePanelMedia = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.EditingMessagePanelMedia")
        self.Notifications_MessageNotificationsHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notifications.MessageNotificationsHelp")
        self.EnterPasscode_EnterCurrentPasscode = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "EnterPasscode.EnterCurrentPasscode")
        self.Conversation_EditingMessageMediaEditCurrentVideo = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.EditingMessageMediaEditCurrentVideo")
        self._MESSAGE_GAME = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "MESSAGE_GAME")
        self._MESSAGE_GAME_r = extractArgumentRanges(self._MESSAGE_GAME)
        self.Conversation_Moderate_Report = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.Moderate.Report")
        self.MessageTimer_Forever = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "MessageTimer.Forever")
        self.DialogList_SavedMessagesHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "DialogList.SavedMessagesHelp")
        self._Conversation_EncryptedPlaceholderTitleIncoming = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.EncryptedPlaceholderTitleIncoming")
        self._Conversation_EncryptedPlaceholderTitleIncoming_r = extractArgumentRanges(self._Conversation_EncryptedPlaceholderTitleIncoming)
        self._Map_AccurateTo = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Map.AccurateTo")
        self._Map_AccurateTo_r = extractArgumentRanges(self._Map_AccurateTo)
        self._Call_ParticipantVersionOutdatedError = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Call.ParticipantVersionOutdatedError")
        self._Call_ParticipantVersionOutdatedError_r = extractArgumentRanges(self._Call_ParticipantVersionOutdatedError)
        self.Passport_Identity_ReverseSideHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Identity.ReverseSideHelp")
        self.Tour_Text2 = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Tour.Text2")
        self.Call_StatusNoAnswer = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Call.StatusNoAnswer")
        self._Passport_Phone_UseTelegramNumber = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Phone.UseTelegramNumber")
        self._Passport_Phone_UseTelegramNumber_r = extractArgumentRanges(self._Passport_Phone_UseTelegramNumber)
        self.Channel_AdminLogFilter_EventsLeavingSubscribers = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.AdminLogFilter.EventsLeavingSubscribers")
        self.Conversation_MessageDialogDelete = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.MessageDialogDelete")
        self.Appearance_PreviewOutgoingText = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Appearance.PreviewOutgoingText")
        self.Username_Placeholder = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Username.Placeholder")
        self._Notification_PinnedDeletedMessage = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notification.PinnedDeletedMessage")
        self._Notification_PinnedDeletedMessage_r = extractArgumentRanges(self._Notification_PinnedDeletedMessage)
        self._Time_MonthOfYear_m11 = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Time.MonthOfYear_m11")
        self._Time_MonthOfYear_m11_r = extractArgumentRanges(self._Time_MonthOfYear_m11)
        self.UserInfo_BotHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "UserInfo.BotHelp")
        self.TwoStepAuth_PasswordSet = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "TwoStepAuth.PasswordSet")
        self._CHANNEL_MESSAGE_VIDEO = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "CHANNEL_MESSAGE_VIDEO")
        self._CHANNEL_MESSAGE_VIDEO_r = extractArgumentRanges(self._CHANNEL_MESSAGE_VIDEO)
        self.EnterPasscode_TouchId = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "EnterPasscode.TouchId")
        self.AuthSessions_LoggedInWithTelegram = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "AuthSessions.LoggedInWithTelegram")
        self.Checkout_ErrorInvoiceAlreadyPaid = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Checkout.ErrorInvoiceAlreadyPaid")
        self.ChatAdmins_Title = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ChatAdmins.Title")
        self.ChannelMembers_WhoCanAddMembers = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ChannelMembers.WhoCanAddMembers")
        self.Passport_Language_ar = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Language.ar")
        self.PasscodeSettings_Help = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PasscodeSettings.Help")
        self.Conversation_EditingMessagePanelTitle = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.EditingMessagePanelTitle")
        self.Settings_AboutEmpty = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Settings.AboutEmpty")
        self._NetworkUsageSettings_CellularUsageSince = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "NetworkUsageSettings.CellularUsageSince")
        self._NetworkUsageSettings_CellularUsageSince_r = extractArgumentRanges(self._NetworkUsageSettings_CellularUsageSince)
        self.GroupInfo_ConvertToSupergroup = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "GroupInfo.ConvertToSupergroup")
        self._Notification_PinnedContactMessage = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notification.PinnedContactMessage")
        self._Notification_PinnedContactMessage_r = extractArgumentRanges(self._Notification_PinnedContactMessage)
        self.CallSettings_UseLessDataLongDescription = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "CallSettings.UseLessDataLongDescription")
        self.FastTwoStepSetup_PasswordPlaceholder = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "FastTwoStepSetup.PasswordPlaceholder")
        self.Conversation_SecretChatContextBotAlert = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.SecretChatContextBotAlert")
        self.Channel_Moderator_AccessLevelRevoke = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.Moderator.AccessLevelRevoke")
        self.CheckoutInfo_ReceiverInfoTitle = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "CheckoutInfo.ReceiverInfoTitle")
        self.Channel_AdminLogFilter_EventsRestrictions = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.AdminLogFilter.EventsRestrictions")
        self.GroupInfo_InviteLink_RevokeLink = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "GroupInfo.InviteLink.RevokeLink")
        self.Checkout_PaymentMethod_Title = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Checkout.PaymentMethod.Title")
        self.Conversation_Unmute = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.Unmute")
        self.AutoDownloadSettings_DocumentsTitle = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "AutoDownloadSettings.DocumentsTitle")
        self.Passport_FieldOneOf_FinalDelimeter = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.FieldOneOf.FinalDelimeter")
        self.Notifications_MessageNotifications = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notifications.MessageNotifications")
        self.Passport_ForgottenPassword = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.ForgottenPassword")
        self.ChannelMembers_WhoCanAddMembersAdminsHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ChannelMembers.WhoCanAddMembersAdminsHelp")
        self.DialogList_DeleteBotConversationConfirmation = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "DialogList.DeleteBotConversationConfirmation")
        self.Passport_Identity_TranslationHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Identity.TranslationHelp")
        self._Update_AppVersion = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Update.AppVersion")
        self._Update_AppVersion_r = extractArgumentRanges(self._Update_AppVersion)
        self._DialogList_MultipleTyping = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "DialogList.MultipleTyping")
        self._DialogList_MultipleTyping_r = extractArgumentRanges(self._DialogList_MultipleTyping)
        self.Passport_Identity_OneOfTypeIdentityCard = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Identity.OneOfTypeIdentityCard")
        self.Conversation_ClousStorageInfo_Description2 = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.ClousStorageInfo.Description2")
        self._Time_MonthOfYear_m5 = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Time.MonthOfYear_m5")
        self._Time_MonthOfYear_m5_r = extractArgumentRanges(self._Time_MonthOfYear_m5)
        self.Map_Hybrid = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Map.Hybrid")
        self.Channel_Setup_Title = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.Setup.Title")
        self.MediaPicker_TimerTooltip = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "MediaPicker.TimerTooltip")
        self.Activity_UploadingVideo = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Activity.UploadingVideo")
        self.Channel_Info_Management = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.Info.Management")
        self._Login_TermsOfService_ProceedBot = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Login.TermsOfService.ProceedBot")
        self._Login_TermsOfService_ProceedBot_r = extractArgumentRanges(self._Login_TermsOfService_ProceedBot)
        self._Notification_MessageLifetimeChangedOutgoing = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notification.MessageLifetimeChangedOutgoing")
        self._Notification_MessageLifetimeChangedOutgoing_r = extractArgumentRanges(self._Notification_MessageLifetimeChangedOutgoing)
        self.PhotoEditor_QualityVeryLow = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PhotoEditor.QualityVeryLow")
        self.Stickers_AddToFavorites = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Stickers.AddToFavorites")
        self.Month_ShortFebruary = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Month.ShortFebruary")
        self.Notifications_AddExceptionTitle = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notifications.AddExceptionTitle")
        self.Conversation_ForwardTitle = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.ForwardTitle")
        self.Settings_FAQ_URL = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Settings.FAQ_URL")
        self.Activity_RecordingVideoMessage = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Activity.RecordingVideoMessage")
        self.SharedMedia_EmptyFilesText = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "SharedMedia.EmptyFilesText")
        self._Contacts_AccessDeniedHelpLandscape = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Contacts.AccessDeniedHelpLandscape")
        self._Contacts_AccessDeniedHelpLandscape_r = extractArgumentRanges(self._Contacts_AccessDeniedHelpLandscape)
        self.PasscodeSettings_UnlockWithTouchId = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PasscodeSettings.UnlockWithTouchId")
        self.Contacts_AccessDeniedHelpON = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Contacts.AccessDeniedHelpON")
        self.Passport_Identity_AddInternalPassport = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Identity.AddInternalPassport")
        self.NetworkUsageSettings_ResetStats = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "NetworkUsageSettings.ResetStats")
        self.Share_AuthDescription = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Share.AuthDescription")
        self._CHAT_MESSAGE_PHOTOS = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "CHAT_MESSAGE_PHOTOS")
        self._CHAT_MESSAGE_PHOTOS_r = extractArgumentRanges(self._CHAT_MESSAGE_PHOTOS)
        self._PrivacySettings_LastSeenContactsMinusPlus = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PrivacySettings.LastSeenContactsMinusPlus")
        self._PrivacySettings_LastSeenContactsMinusPlus_r = extractArgumentRanges(self._PrivacySettings_LastSeenContactsMinusPlus)
        self.Channel_AdminLog_EmptyMessageText = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.AdminLog.EmptyMessageText")
        self._Notification_ChannelInviter = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notification.ChannelInviter")
        self._Notification_ChannelInviter_r = extractArgumentRanges(self._Notification_ChannelInviter)
        self.SocksProxySetup_TypeSocks = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "SocksProxySetup.TypeSocks")
        self.Profile_MessageLifetimeForever = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Profile.MessageLifetimeForever")
        self.MediaPicker_UngroupDescription = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "MediaPicker.UngroupDescription")
        self._Checkout_SavePasswordTimeoutAndFaceId = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Checkout.SavePasswordTimeoutAndFaceId")
        self._Checkout_SavePasswordTimeoutAndFaceId_r = extractArgumentRanges(self._Checkout_SavePasswordTimeoutAndFaceId)
        self.SocksProxySetup_Username = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "SocksProxySetup.Username")
        self.Conversation_Edit = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.Edit")
        self.TwoStepAuth_ResetAccountHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "TwoStepAuth.ResetAccountHelp")
        self.Month_GenDecember = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Month.GenDecember")
        self._Watch_LastSeen_YesterdayAt = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Watch.LastSeen.YesterdayAt")
        self._Watch_LastSeen_YesterdayAt_r = extractArgumentRanges(self._Watch_LastSeen_YesterdayAt)
        self.Channel_ErrorAddBlocked = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.ErrorAddBlocked")
        self.Conversation_Unpin = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.Unpin")
        self.Call_RecordingDisabledMessage = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Call.RecordingDisabledMessage")
        self.Passport_Address_TypeUtilityBill = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Address.TypeUtilityBill")
        self.Conversation_UnblockUser = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.UnblockUser")
        self.Conversation_Unblock = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.Unblock")
        self._CHANNEL_MESSAGE_GIF = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "CHANNEL_MESSAGE_GIF")
        self._CHANNEL_MESSAGE_GIF_r = extractArgumentRanges(self._CHANNEL_MESSAGE_GIF)
        self.Channel_AdminLogFilter_EventsEditedMessages = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.AdminLogFilter.EventsEditedMessages")
        self.AutoNightTheme_ScheduleSection = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "AutoNightTheme.ScheduleSection")
        self.Appearance_ThemeNightBlue = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Appearance.ThemeNightBlue")
        self._Passport_Scans_ScanIndex = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Scans.ScanIndex")
        self._Passport_Scans_ScanIndex_r = extractArgumentRanges(self._Passport_Scans_ScanIndex)
        self.Channel_Username_InvalidTooShort = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.Username.InvalidTooShort")
        self.Conversation_ViewGroup = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.ViewGroup")
        self.Watch_LastSeen_WithinAWeek = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Watch.LastSeen.WithinAWeek")
        self.BlockedUsers_SelectUserTitle = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "BlockedUsers.SelectUserTitle")
        self.Profile_MessageLifetime1w = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Profile.MessageLifetime1w")
        self.Passport_Address_TypeRentalAgreementUploadScan = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Address.TypeRentalAgreementUploadScan")
        self.DialogList_TabTitle = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "DialogList.TabTitle")
        self.UserInfo_GenericPhoneLabel = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "UserInfo.GenericPhoneLabel")
        self._Channel_AdminLog_MessagePromotedName = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.AdminLog.MessagePromotedName")
        self._Channel_AdminLog_MessagePromotedName_r = extractArgumentRanges(self._Channel_AdminLog_MessagePromotedName)
        self.Group_Members_AddMemberBotErrorNotAllowed = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Group.Members.AddMemberBotErrorNotAllowed")
        self._Username_LinkHint = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Username.LinkHint")
        self._Username_LinkHint_r = extractArgumentRanges(self._Username_LinkHint)
        self.Map_StopLiveLocation = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Map.StopLiveLocation")
        self.Message_LiveLocation = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Message.LiveLocation")
        self.NetworkUsageSettings_Title = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "NetworkUsageSettings.Title")
        self.CheckoutInfo_ShippingInfoPostcodePlaceholder = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "CheckoutInfo.ShippingInfoPostcodePlaceholder")
        self.InfoPlist_NSPhotoLibraryUsageDescription = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "InfoPlist.NSPhotoLibraryUsageDescription")
        self.Wallpaper_Wallpaper = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Wallpaper.Wallpaper")
        self.GroupInfo_InviteLink_RevokeAlert_Revoke = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "GroupInfo.InviteLink.RevokeAlert.Revoke")
        self.SharedMedia_TitleLink = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "SharedMedia.TitleLink")
        self._Channel_AdminLog_MessageRestrictedName = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.AdminLog.MessageRestrictedName")
        self._Channel_AdminLog_MessageRestrictedName_r = extractArgumentRanges(self._Channel_AdminLog_MessageRestrictedName)
        self._Channel_AdminLog_MessageGroupPreHistoryHidden = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.AdminLog.MessageGroupPreHistoryHidden")
        self._Channel_AdminLog_MessageGroupPreHistoryHidden_r = extractArgumentRanges(self._Channel_AdminLog_MessageGroupPreHistoryHidden)
        self.Channel_JoinChannel = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.JoinChannel")
        self.StickerPack_Add = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "StickerPack.Add")
        self.Group_ErrorNotMutualContact = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Group.ErrorNotMutualContact")
        self.AccessDenied_LocationDisabled = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "AccessDenied.LocationDisabled")
        self.Login_UnknownError = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Login.UnknownError")
        self.Presence_online = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Presence.online")
        self.DialogList_Title = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "DialogList.Title")
        self.Stickers_Install = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Stickers.Install")
        self.SearchImages_NoImagesFound = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "SearchImages.NoImagesFound")
        self._Watch_Time_ShortTodayAt = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Watch.Time.ShortTodayAt")
        self._Watch_Time_ShortTodayAt_r = extractArgumentRanges(self._Watch_Time_ShortTodayAt)
        self.Channel_AdminLogFilter_EventsNewSubscribers = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.AdminLogFilter.EventsNewSubscribers")
        self.Passport_Identity_ExpiryDate = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Identity.ExpiryDate")
        self.UserInfo_GroupsInCommon = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "UserInfo.GroupsInCommon")
        self.Message_PinnedContactMessage = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Message.PinnedContactMessage")
        self.AccessDenied_CameraDisabled = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "AccessDenied.CameraDisabled")
        self._Time_PreciseDate_m3 = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Time.PreciseDate_m3")
        self._Time_PreciseDate_m3_r = extractArgumentRanges(self._Time_PreciseDate_m3)
        self.Passport_Email_EnterOtherEmail = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Email.EnterOtherEmail")
        self._LiveLocationUpdated_YesterdayAt = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "LiveLocationUpdated.YesterdayAt")
        self._LiveLocationUpdated_YesterdayAt_r = extractArgumentRanges(self._LiveLocationUpdated_YesterdayAt)
        self.NotificationsSound_Note = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "NotificationsSound.Note")
        self.Passport_Identity_MiddleNamePlaceholder = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Identity.MiddleNamePlaceholder")
        self.PrivacyPolicy_Title = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PrivacyPolicy.Title")
        self.Month_GenMarch = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Month.GenMarch")
        self.Watch_UserInfo_Unmute = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Watch.UserInfo.Unmute")
        self.CheckoutInfo_ErrorPostcodeInvalid = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "CheckoutInfo.ErrorPostcodeInvalid")
        self.Common_Delete = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Common.Delete")
        self.Username_Title = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Username.Title")
        self.Login_PhoneFloodError = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Login.PhoneFloodError")
        self.Channel_AdminLog_InfoPanelTitle = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.AdminLog.InfoPanelTitle")
        self._CHANNEL_MESSAGE_PHOTO = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "CHANNEL_MESSAGE_PHOTO")
        self._CHANNEL_MESSAGE_PHOTO_r = extractArgumentRanges(self._CHANNEL_MESSAGE_PHOTO)
        self._Channel_AdminLog_MessageToggleInvitesOff = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.AdminLog.MessageToggleInvitesOff")
        self._Channel_AdminLog_MessageToggleInvitesOff_r = extractArgumentRanges(self._Channel_AdminLog_MessageToggleInvitesOff)
        self.Group_ErrorAddTooMuchBots = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Group.ErrorAddTooMuchBots")
        self._Notification_CallFormat = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notification.CallFormat")
        self._Notification_CallFormat_r = extractArgumentRanges(self._Notification_CallFormat)
        self._CHAT_MESSAGE_PHOTO = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "CHAT_MESSAGE_PHOTO")
        self._CHAT_MESSAGE_PHOTO_r = extractArgumentRanges(self._CHAT_MESSAGE_PHOTO)
        self._UserInfo_UnblockConfirmation = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "UserInfo.UnblockConfirmation")
        self._UserInfo_UnblockConfirmation_r = extractArgumentRanges(self._UserInfo_UnblockConfirmation)
        self.Appearance_PickAccentColor = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Appearance.PickAccentColor")
        self.Passport_Identity_EditDriversLicense = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Identity.EditDriversLicense")
        self.Passport_Identity_AddPassport = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Identity.AddPassport")
        self.UserInfo_ShareBot = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "UserInfo.ShareBot")
        self.Settings_ProxyConnected = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Settings.ProxyConnected")
        self.ChatSettings_AutoDownloadVoiceMessages = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ChatSettings.AutoDownloadVoiceMessages")
        self.TwoStepAuth_EmailSkip = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "TwoStepAuth.EmailSkip")
        self.Conversation_ViewContactDetails = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.ViewContactDetails")
        self.Notifications_Badge_CountUnreadMessages_InfoOff = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notifications.Badge.CountUnreadMessages.InfoOff")
        self.Conversation_JumpToDate = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.JumpToDate")
        self.AutoDownloadSettings_VideoMessagesTitle = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "AutoDownloadSettings.VideoMessagesTitle")
        self.Passport_Address_OneOfTypeUtilityBill = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Address.OneOfTypeUtilityBill")
        self.CheckoutInfo_ReceiverInfoEmailPlaceholder = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "CheckoutInfo.ReceiverInfoEmailPlaceholder")
        self.Message_Photo = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Message.Photo")
        self.Conversation_ReportSpam = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.ReportSpam")
        self.Camera_FlashAuto = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Camera.FlashAuto")
        self.Passport_Identity_TypePassportUploadScan = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Identity.TypePassportUploadScan")
        self.Call_ConnectionErrorMessage = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Call.ConnectionErrorMessage")
        self.Stickers_FrequentlyUsed = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Stickers.FrequentlyUsed")
        self.LastSeen_ALongTimeAgo = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "LastSeen.ALongTimeAgo")
        self.Passport_Identity_ReverseSide = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Identity.ReverseSide")
        self.DialogList_SearchSectionGlobal = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "DialogList.SearchSectionGlobal")
        self.ChangePhoneNumberNumber_NumberPlaceholder = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ChangePhoneNumberNumber.NumberPlaceholder")
        self.GroupInfo_AddUserLeftError = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "GroupInfo.AddUserLeftError")
        self.Appearance_ThemeDay = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Appearance.ThemeDay")
        self.GroupInfo_GroupType = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "GroupInfo.GroupType")
        self.Watch_Suggestion_OnMyWay = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Watch.Suggestion.OnMyWay")
        self.Checkout_NewCard_PaymentCard = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Checkout.NewCard.PaymentCard")
        self._DialogList_SearchSubtitleFormat = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "DialogList.SearchSubtitleFormat")
        self._DialogList_SearchSubtitleFormat_r = extractArgumentRanges(self._DialogList_SearchSubtitleFormat)
        self.PhotoEditor_CropAspectRatioOriginal = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PhotoEditor.CropAspectRatioOriginal")
        self._Conversation_RestrictedInlineTimed = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.RestrictedInlineTimed")
        self._Conversation_RestrictedInlineTimed_r = extractArgumentRanges(self._Conversation_RestrictedInlineTimed)
        self.UserInfo_NotificationsDisabled = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "UserInfo.NotificationsDisabled")
        self._CONTACT_JOINED = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "CONTACT_JOINED")
        self._CONTACT_JOINED_r = extractArgumentRanges(self._CONTACT_JOINED)
        self.NotificationsSound_Bamboo = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "NotificationsSound.Bamboo")
        self.PrivacyLastSeenSettings_AlwaysShareWith_Title = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PrivacyLastSeenSettings.AlwaysShareWith.Title")
        self._Channel_AdminLog_MessageGroupPreHistoryVisible = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.AdminLog.MessageGroupPreHistoryVisible")
        self._Channel_AdminLog_MessageGroupPreHistoryVisible_r = extractArgumentRanges(self._Channel_AdminLog_MessageGroupPreHistoryVisible)
        self.BlockedUsers_LeavePrefix = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "BlockedUsers.LeavePrefix")
        self.NetworkUsageSettings_ResetStatsConfirmation = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "NetworkUsageSettings.ResetStatsConfirmation")
        self.Group_Setup_HistoryHeader = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Group.Setup.HistoryHeader")
        self.Channel_EditAdmin_PermissionPostMessages = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.EditAdmin.PermissionPostMessages")
        self._Contacts_AddPhoneNumber = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Contacts.AddPhoneNumber")
        self._Contacts_AddPhoneNumber_r = extractArgumentRanges(self._Contacts_AddPhoneNumber)
        self._MESSAGE_SCREENSHOT = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "MESSAGE_SCREENSHOT")
        self._MESSAGE_SCREENSHOT_r = extractArgumentRanges(self._MESSAGE_SCREENSHOT)
        self.DialogList_EncryptionProcessing = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "DialogList.EncryptionProcessing")
        self.GroupInfo_GroupHistory = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "GroupInfo.GroupHistory")
        self.Conversation_ApplyLocalization = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.ApplyLocalization")
        self.FastTwoStepSetup_Title = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "FastTwoStepSetup.Title")
        self.SocksProxySetup_ProxyStatusUnavailable = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "SocksProxySetup.ProxyStatusUnavailable")
        self.Passport_Address_EditRentalAgreement = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Address.EditRentalAgreement")
        self.Conversation_DeleteManyMessages = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.DeleteManyMessages")
        self.CancelResetAccount_Title = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "CancelResetAccount.Title")
        self.Notification_CallOutgoingShort = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notification.CallOutgoingShort")
        self.SharedMedia_TitleAll = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "SharedMedia.TitleAll")
        self.Conversation_SlideToCancel = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.SlideToCancel")
        self.AuthSessions_TerminateSession = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "AuthSessions.TerminateSession")
        self.Channel_AdminLogFilter_EventsDeletedMessages = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.AdminLogFilter.EventsDeletedMessages")
        self.PrivacyLastSeenSettings_AlwaysShareWith_Placeholder = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PrivacyLastSeenSettings.AlwaysShareWith.Placeholder")
        self.Channel_Members_Title = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.Members.Title")
        self.Channel_AdminLog_CanDeleteMessages = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.AdminLog.CanDeleteMessages")
        self.Privacy_DeleteDrafts = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Privacy.DeleteDrafts")
        self.Group_Setup_TypePrivateHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Group.Setup.TypePrivateHelp")
        self._Notification_PinnedVideoMessage = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notification.PinnedVideoMessage")
        self._Notification_PinnedVideoMessage_r = extractArgumentRanges(self._Notification_PinnedVideoMessage)
        self.Conversation_ContextMenuStickerPackAdd = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.ContextMenuStickerPackAdd")
        self.Channel_AdminLogFilter_EventsNewMembers = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.AdminLogFilter.EventsNewMembers")
        self.Channel_AdminLogFilter_EventsPinned = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.AdminLogFilter.EventsPinned")
        self._Conversation_Moderate_DeleteAllMessages = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.Moderate.DeleteAllMessages")
        self._Conversation_Moderate_DeleteAllMessages_r = extractArgumentRanges(self._Conversation_Moderate_DeleteAllMessages)
        self.SharedMedia_CategoryOther = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "SharedMedia.CategoryOther")
        self.Passport_Address_Address = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Address.Address")
        self.DialogList_SavedMessagesTooltip = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "DialogList.SavedMessagesTooltip")
        self.Preview_DeletePhoto = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Preview.DeletePhoto")
        self.GroupInfo_ChannelListNamePlaceholder = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "GroupInfo.ChannelListNamePlaceholder")
        self.PasscodeSettings_TurnPasscodeOn = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PasscodeSettings.TurnPasscodeOn")
        self.AuthSessions_LogOutApplicationsHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "AuthSessions.LogOutApplicationsHelp")
        self.Passport_FieldOneOf_Delimeter = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.FieldOneOf.Delimeter")
        self._Channel_AdminLog_MessageChangedGroupStickerPack = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.AdminLog.MessageChangedGroupStickerPack")
        self._Channel_AdminLog_MessageChangedGroupStickerPack_r = extractArgumentRanges(self._Channel_AdminLog_MessageChangedGroupStickerPack)
        self.DialogList_Unpin = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "DialogList.Unpin")
        self.GroupInfo_SetGroupPhoto = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "GroupInfo.SetGroupPhoto")
        self.StickerPacksSettings_ArchivedPacks_Info = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "StickerPacksSettings.ArchivedPacks.Info")
        self.ConvertToSupergroup_Title = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ConvertToSupergroup.Title")
        self._CHAT_MESSAGE_NOTEXT = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "CHAT_MESSAGE_NOTEXT")
        self._CHAT_MESSAGE_NOTEXT_r = extractArgumentRanges(self._CHAT_MESSAGE_NOTEXT)
        self.Notification_CallCanceledShort = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notification.CallCanceledShort")
        self.Channel_Setup_TypeHeader = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.Setup.TypeHeader")
        self._Notification_NewAuthDetected = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notification.NewAuthDetected")
        self._Notification_NewAuthDetected_r = extractArgumentRanges(self._Notification_NewAuthDetected)
        self._Channel_AdminLog_MessageRemovedGroupStickerPack = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.AdminLog.MessageRemovedGroupStickerPack")
        self._Channel_AdminLog_MessageRemovedGroupStickerPack_r = extractArgumentRanges(self._Channel_AdminLog_MessageRemovedGroupStickerPack)
        self.PrivacyPolicy_DeclineTitle = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PrivacyPolicy.DeclineTitle")
        self.AuthSessions_PasswordPending = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "AuthSessions.PasswordPending")
        self.AccessDenied_VideoMessageCamera = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "AccessDenied.VideoMessageCamera")
        self.Privacy_ContactsSyncHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Privacy.ContactsSyncHelp")
        self.Conversation_Search = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.Search")
        self._Channel_Management_PromotedBy = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.Management.PromotedBy")
        self._Channel_Management_PromotedBy_r = extractArgumentRanges(self._Channel_Management_PromotedBy)
        self._PrivacySettings_LastSeenNobodyPlus = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PrivacySettings.LastSeenNobodyPlus")
        self._PrivacySettings_LastSeenNobodyPlus_r = extractArgumentRanges(self._PrivacySettings_LastSeenNobodyPlus)
        self._Time_MonthOfYear_m4 = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Time.MonthOfYear_m4")
        self._Time_MonthOfYear_m4_r = extractArgumentRanges(self._Time_MonthOfYear_m4)
        self.SecretImage_Title = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "SecretImage.Title")
        self.Notifications_InAppNotificationsSounds = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notifications.InAppNotificationsSounds")
        self.Call_StatusRequesting = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Call.StatusRequesting")
        self._Channel_AdminLog_MessageRestrictedUntil = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.AdminLog.MessageRestrictedUntil")
        self._Channel_AdminLog_MessageRestrictedUntil_r = extractArgumentRanges(self._Channel_AdminLog_MessageRestrictedUntil)
        self._CHAT_MESSAGE_CONTACT = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "CHAT_MESSAGE_CONTACT")
        self._CHAT_MESSAGE_CONTACT_r = extractArgumentRanges(self._CHAT_MESSAGE_CONTACT)
        self.SocksProxySetup_UseProxy = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "SocksProxySetup.UseProxy")
        self.Group_UpgradeNoticeText1 = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Group.UpgradeNoticeText1")
        self.ChatSettings_Other = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ChatSettings.Other")
        self._Channel_AdminLog_MessageChangedChannelAbout = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.AdminLog.MessageChangedChannelAbout")
        self._Channel_AdminLog_MessageChangedChannelAbout_r = extractArgumentRanges(self._Channel_AdminLog_MessageChangedChannelAbout)
        self.Channel_Stickers_CreateYourOwn = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.Stickers.CreateYourOwn")
        self._Call_EmojiDescription = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Call.EmojiDescription")
        self._Call_EmojiDescription_r = extractArgumentRanges(self._Call_EmojiDescription)
        self.Settings_SaveIncomingPhotos = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Settings.SaveIncomingPhotos")
        self._Conversation_Bytes = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.Bytes")
        self._Conversation_Bytes_r = extractArgumentRanges(self._Conversation_Bytes)
        self.GroupInfo_InviteLink_Help = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "GroupInfo.InviteLink.Help")
        self.Calls_Missed = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Calls.Missed")
        self.Conversation_ContextMenuForward = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.ContextMenuForward")
        self.AutoDownloadSettings_ResetHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "AutoDownloadSettings.ResetHelp")
        self.Passport_Identity_NativeNameHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Identity.NativeNameHelp")
        self.Call_StatusRinging = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Call.StatusRinging")
        self.Passport_Language_pl = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Language.pl")
        self.Invitation_JoinGroup = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Invitation.JoinGroup")
        self.Notification_PinnedMessage = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notification.PinnedMessage")
        self.AutoDownloadSettings_WiFi = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "AutoDownloadSettings.WiFi")
        self.Conversation_ClearSelfHistory = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.ClearSelfHistory")
        self.Message_Location = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Message.Location")
        self._Notification_MessageLifetimeChanged = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notification.MessageLifetimeChanged")
        self._Notification_MessageLifetimeChanged_r = extractArgumentRanges(self._Notification_MessageLifetimeChanged)
        self.Message_Contact = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Message.Contact")
        self.Passport_Language_lo = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Language.lo")
        self.UserInfo_BotPrivacy = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "UserInfo.BotPrivacy")
        self.PasscodeSettings_AutoLock_IfAwayFor_1minute = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PasscodeSettings.AutoLock.IfAwayFor_1minute")
        self.Common_More = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Common.More")
        self.Preview_OpenInInstagram = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Preview.OpenInInstagram")
        self.PhotoEditor_HighlightsTool = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PhotoEditor.HighlightsTool")
        self._Channel_Username_UsernameIsAvailable = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.Username.UsernameIsAvailable")
        self._Channel_Username_UsernameIsAvailable_r = extractArgumentRanges(self._Channel_Username_UsernameIsAvailable)
        self._PINNED_GAME = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PINNED_GAME")
        self._PINNED_GAME_r = extractArgumentRanges(self._PINNED_GAME)
        self.Invite_LargeRecipientsCountWarning = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Invite.LargeRecipientsCountWarning")
        self.Passport_Language_hr = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Language.hr")
        self.GroupInfo_BroadcastListNamePlaceholder = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "GroupInfo.BroadcastListNamePlaceholder")
        self.Activity_UploadingVideoMessage = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Activity.UploadingVideoMessage")
        self.Conversation_ShareBotContactConfirmation = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.ShareBotContactConfirmation")
        self.Login_CodeSentSms = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Login.CodeSentSms")
        self._CHANNEL_MESSAGES = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "CHANNEL_MESSAGES")
        self._CHANNEL_MESSAGES_r = extractArgumentRanges(self._CHANNEL_MESSAGES)
        self.Conversation_ReportSpamConfirmation = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.ReportSpamConfirmation")
        self.ChannelMembers_ChannelAdminsTitle = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ChannelMembers.ChannelAdminsTitle")
        self.SocksProxySetup_Credentials = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "SocksProxySetup.Credentials")
        self.CallSettings_UseLessData = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "CallSettings.UseLessData")
        self.MediaPicker_GroupDescription = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "MediaPicker.GroupDescription")
        self._TwoStepAuth_EnterPasswordHint = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "TwoStepAuth.EnterPasswordHint")
        self._TwoStepAuth_EnterPasswordHint_r = extractArgumentRanges(self._TwoStepAuth_EnterPasswordHint)
        self.CallSettings_TabIcon = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "CallSettings.TabIcon")
        self.ConversationProfile_UnknownAddMemberError = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ConversationProfile.UnknownAddMemberError")
        self._Conversation_FileHowToText = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.FileHowToText")
        self._Conversation_FileHowToText_r = extractArgumentRanges(self._Conversation_FileHowToText)
        self.Channel_AdminLog_BanSendMedia = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.AdminLog.BanSendMedia")
        self.Passport_Language_uz = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Language.uz")
        self.Watch_UserInfo_Unblock = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Watch.UserInfo.Unblock")
        self.ChatSettings_AutoDownloadVideoMessages = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ChatSettings.AutoDownloadVideoMessages")
        self.PrivacyPolicy_AgeVerificationTitle = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PrivacyPolicy.AgeVerificationTitle")
        self.StickerPacksSettings_ArchivedMasks = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "StickerPacksSettings.ArchivedMasks")
        self.Message_Animation = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Message.Animation")
        self.Checkout_PaymentMethod = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Checkout.PaymentMethod")
        self.Channel_AdminLog_TitleSelectedEvents = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.AdminLog.TitleSelectedEvents")
        self.PrivacyPolicy_DeclineDeleteNow = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PrivacyPolicy.DeclineDeleteNow")
        self.Privacy_Calls_NeverAllow_Title = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Privacy.Calls.NeverAllow.Title")
        self.Cache_Music = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Cache.Music")
        self.Settings_ProxyDisabled = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Settings.ProxyDisabled")
        self.SocksProxySetup_Connecting = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "SocksProxySetup.Connecting")
        self.Channel_Username_CreatePrivateLinkHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.Username.CreatePrivateLinkHelp")
        self._Time_PreciseDate_m2 = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Time.PreciseDate_m2")
        self._Time_PreciseDate_m2_r = extractArgumentRanges(self._Time_PreciseDate_m2)
        self._FileSize_B = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "FileSize.B")
        self._FileSize_B_r = extractArgumentRanges(self._FileSize_B)
        self._Target_ShareGameConfirmationGroup = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Target.ShareGameConfirmationGroup")
        self._Target_ShareGameConfirmationGroup_r = extractArgumentRanges(self._Target_ShareGameConfirmationGroup)
        self.PhotoEditor_SaturationTool = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PhotoEditor.SaturationTool")
        self.Channel_BanUser_BlockFor = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.BanUser.BlockFor")
        self.Call_StatusConnecting = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Call.StatusConnecting")
        self.AutoNightTheme_NotAvailable = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "AutoNightTheme.NotAvailable")
        self.PrivateDataSettings_Title = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PrivateDataSettings.Title")
        self.Bot_Start = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Bot.Start")
        self._Channel_AdminLog_MessageChangedGroupAbout = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.AdminLog.MessageChangedGroupAbout")
        self._Channel_AdminLog_MessageChangedGroupAbout_r = extractArgumentRanges(self._Channel_AdminLog_MessageChangedGroupAbout)
        self.Appearance_PreviewReplyAuthor = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Appearance.PreviewReplyAuthor")
        self.Notifications_TextTone = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notifications.TextTone")
        self.Settings_CallSettings = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Settings.CallSettings")
        self._Watch_Time_ShortYesterdayAt = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Watch.Time.ShortYesterdayAt")
        self._Watch_Time_ShortYesterdayAt_r = extractArgumentRanges(self._Watch_Time_ShortYesterdayAt)
        self.Contacts_InviteToTelegram = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Contacts.InviteToTelegram")
        self._PINNED_DOC = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PINNED_DOC")
        self._PINNED_DOC_r = extractArgumentRanges(self._PINNED_DOC)
        self.ChatSettings_PrivateChats = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ChatSettings.PrivateChats")
        self.DialogList_Draft = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "DialogList.Draft")
        self.Channel_EditAdmin_PermissionDeleteMessages = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.EditAdmin.PermissionDeleteMessages")
        self.Channel_BanUser_PermissionSendStickersAndGifs = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.BanUser.PermissionSendStickersAndGifs")
        self.Conversation_CloudStorageInfo_Title = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.CloudStorageInfo.Title")
        self.Conversation_ClearSecretHistory = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.ClearSecretHistory")
        self.Passport_Identity_EditIdentityCard = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Identity.EditIdentityCard")
        self.Notification_RenamedChannel = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notification.RenamedChannel")
        self.BlockedUsers_BlockUser = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "BlockedUsers.BlockUser")
        self.ChatSettings_TextSize = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ChatSettings.TextSize")
        self.ChannelInfo_DeleteGroup = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ChannelInfo.DeleteGroup")
        self.PhoneNumberHelp_Alert = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PhoneNumberHelp.Alert")
        self._PINNED_TEXT = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PINNED_TEXT")
        self._PINNED_TEXT_r = extractArgumentRanges(self._PINNED_TEXT)
        self.Watch_ChannelInfo_Title = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Watch.ChannelInfo.Title")
        self.WebSearch_RecentSectionClear = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "WebSearch.RecentSectionClear")
        self.Channel_AdminLogFilter_AdminsAll = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.AdminLogFilter.AdminsAll")
        self.Channel_Setup_TypePrivate = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.Setup.TypePrivate")
        self.PhotoEditor_TintTool = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PhotoEditor.TintTool")
        self.Watch_Suggestion_CantTalk = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Watch.Suggestion.CantTalk")
        self.PhotoEditor_QualityHigh = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PhotoEditor.QualityHigh")
        self.SocksProxySetup_AddProxyTitle = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "SocksProxySetup.AddProxyTitle")
        self._CHAT_MESSAGE_STICKER = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "CHAT_MESSAGE_STICKER")
        self._CHAT_MESSAGE_STICKER_r = extractArgumentRanges(self._CHAT_MESSAGE_STICKER)
        self.Map_ChooseAPlace = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Map.ChooseAPlace")
        self.Passport_Identity_NamePlaceholder = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Identity.NamePlaceholder")
        self.Passport_ScanPassport = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.ScanPassport")
        self.Map_ShareLiveLocationHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Map.ShareLiveLocationHelp")
        self.Watch_Bot_Restart = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Watch.Bot.Restart")
        self.Passport_RequestedInformation = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.RequestedInformation")
        self.Channel_About_Help = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.About.Help")
        self.Web_OpenExternal = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Web.OpenExternal")
        self.Passport_Language_mn = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Language.mn")
        self.UserInfo_AddContact = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "UserInfo.AddContact")
        self.Privacy_ContactsSync = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Privacy.ContactsSync")
        self.SocksProxySetup_Connection = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "SocksProxySetup.Connection")
        self.Passport_NotLoggedInMessage = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.NotLoggedInMessage")
        self.Passport_PasswordPlaceholder = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.PasswordPlaceholder")
        self.Passport_PasswordCreate = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.PasswordCreate")
        self.SocksProxySetup_ProxyStatusChecking = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "SocksProxySetup.ProxyStatusChecking")
        self.Call_EncryptionKey_Title = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Call.EncryptionKey.Title")
        self.PhotoEditor_BlurToolLinear = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PhotoEditor.BlurToolLinear")
        self.AuthSessions_EmptyText = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "AuthSessions.EmptyText")
        self.Notification_MessageLifetime1m = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notification.MessageLifetime1m")
        self._Call_StatusBar = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Call.StatusBar")
        self._Call_StatusBar_r = extractArgumentRanges(self._Call_StatusBar)
        self.EditProfile_NameAndPhotoHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "EditProfile.NameAndPhotoHelp")
        self.NotificationsSound_Tritone = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "NotificationsSound.Tritone")
        self.Passport_FieldAddressUploadHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.FieldAddressUploadHelp")
        self.Month_ShortJuly = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Month.ShortJuly")
        self.CheckoutInfo_ShippingInfoAddress1Placeholder = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "CheckoutInfo.ShippingInfoAddress1Placeholder")
        self.Watch_MessageView_ViewOnPhone = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Watch.MessageView.ViewOnPhone")
        self.CallSettings_Never = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "CallSettings.Never")
        self.Passport_Identity_TypeInternalPassportUploadScan = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Identity.TypeInternalPassportUploadScan")
        self.TwoStepAuth_EmailSent = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "TwoStepAuth.EmailSent")
        self._Notification_PinnedAnimationMessage = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notification.PinnedAnimationMessage")
        self._Notification_PinnedAnimationMessage_r = extractArgumentRanges(self._Notification_PinnedAnimationMessage)
        self.TwoStepAuth_RecoveryTitle = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "TwoStepAuth.RecoveryTitle")
        self.Notifications_MessageNotificationsExceptions = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notifications.MessageNotificationsExceptions")
        self.WatchRemote_AlertOpen = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "WatchRemote.AlertOpen")
        self.ExplicitContent_AlertChannel = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ExplicitContent.AlertChannel")
        self.Notification_PassportValueEmail = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notification.PassportValueEmail")
        self.ContactInfo_PhoneLabelMobile = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ContactInfo.PhoneLabelMobile")
        self.Widget_AuthRequired = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Widget.AuthRequired")
        self._ForwardedAuthors2 = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ForwardedAuthors2")
        self._ForwardedAuthors2_r = extractArgumentRanges(self._ForwardedAuthors2)
        self.ChannelInfo_DeleteGroupConfirmation = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ChannelInfo.DeleteGroupConfirmation")
        self.TwoStepAuth_ConfirmationText = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "TwoStepAuth.ConfirmationText")
        self.Login_SmsRequestState3 = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Login.SmsRequestState3")
        self.Notifications_AlertTones = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notifications.AlertTones")
        self._Time_MonthOfYear_m10 = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Time.MonthOfYear_m10")
        self._Time_MonthOfYear_m10_r = extractArgumentRanges(self._Time_MonthOfYear_m10)
        self.Login_InfoAvatarPhoto = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Login.InfoAvatarPhoto")
        self.Calls_TabTitle = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Calls.TabTitle")
        self.Map_YouAreHere = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Map.YouAreHere")
        self.PhotoEditor_CurvesTool = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PhotoEditor.CurvesTool")
        self.Map_LiveLocationFor1Hour = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Map.LiveLocationFor1Hour")
        self.AutoNightTheme_AutomaticSection = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "AutoNightTheme.AutomaticSection")
        self.Stickers_NoStickersFound = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Stickers.NoStickersFound")
        self.Passport_Identity_AddIdentityCard = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Identity.AddIdentityCard")
        self._Notification_JoinedChannel = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notification.JoinedChannel")
        self._Notification_JoinedChannel_r = extractArgumentRanges(self._Notification_JoinedChannel)
        self.Passport_Language_et = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Language.et")
        self.Passport_Language_en = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Language.en")
        self.GroupInfo_ActionRestrict = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "GroupInfo.ActionRestrict")
        self.Checkout_ShippingOption_Title = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Checkout.ShippingOption.Title")
        self.Stickers_SuggestStickers = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Stickers.SuggestStickers")
        self._Channel_AdminLog_MessageKickedName = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.AdminLog.MessageKickedName")
        self._Channel_AdminLog_MessageKickedName_r = extractArgumentRanges(self._Channel_AdminLog_MessageKickedName)
        self.Conversation_EncryptionProcessing = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.EncryptionProcessing")
        self.TwoStepAuth_EmailCodeExpired = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "TwoStepAuth.EmailCodeExpired")
        self._CHAT_ADD_MEMBER = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "CHAT_ADD_MEMBER")
        self._CHAT_ADD_MEMBER_r = extractArgumentRanges(self._CHAT_ADD_MEMBER)
        self.Weekday_ShortSunday = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Weekday.ShortSunday")
        self.Privacy_ContactsResetConfirmation = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Privacy.ContactsResetConfirmation")
        self.Month_ShortJune = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Month.ShortJune")
        self.Privacy_Calls_Integration = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Privacy.Calls.Integration")
        self.Channel_TypeSetup_Title = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.TypeSetup.Title")
        self.Month_GenApril = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Month.GenApril")
        self.StickerPacksSettings_ShowStickersButton = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "StickerPacksSettings.ShowStickersButton")
        self.CheckoutInfo_ShippingInfoTitle = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "CheckoutInfo.ShippingInfoTitle")
        self.Notification_PassportValueProofOfAddress = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notification.PassportValueProofOfAddress")
        self.Weekday_Tuesday = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Weekday.Tuesday")
        self.StickerPacksSettings_ShowStickersButtonHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "StickerPacksSettings.ShowStickersButtonHelp")
        self._Compatibility_SecretMediaVersionTooLow = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Compatibility.SecretMediaVersionTooLow")
        self._Compatibility_SecretMediaVersionTooLow_r = extractArgumentRanges(self._Compatibility_SecretMediaVersionTooLow)
        self.CallSettings_RecentCalls = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "CallSettings.RecentCalls")
        self._Conversation_Megabytes = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.Megabytes")
        self._Conversation_Megabytes_r = extractArgumentRanges(self._Conversation_Megabytes)
        self.Conversation_SearchByName_Prefix = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.SearchByName.Prefix")
        self.TwoStepAuth_FloodError = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "TwoStepAuth.FloodError")
        self.Paint_Stickers = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Paint.Stickers")
        self.Login_InvalidCountryCode = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Login.InvalidCountryCode")
        self.Privacy_Calls_AlwaysAllow_Title = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Privacy.Calls.AlwaysAllow.Title")
        self.Username_InvalidTooShort = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Username.InvalidTooShort")
        self._Settings_ApplyProxyAlert = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Settings.ApplyProxyAlert")
        self._Settings_ApplyProxyAlert_r = extractArgumentRanges(self._Settings_ApplyProxyAlert)
        self.Weekday_ShortFriday = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Weekday.ShortFriday")
        self._Login_BannedPhoneBody = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Login.BannedPhoneBody")
        self._Login_BannedPhoneBody_r = extractArgumentRanges(self._Login_BannedPhoneBody)
        self.Conversation_ClearAll = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.ClearAll")
        self.Conversation_EditingMessageMediaChange = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.EditingMessageMediaChange")
        self.Passport_FieldIdentityTranslationHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.FieldIdentityTranslationHelp")
        self.Call_ReportIncludeLog = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Call.ReportIncludeLog")
        self._Time_MonthOfYear_m3 = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Time.MonthOfYear_m3")
        self._Time_MonthOfYear_m3_r = extractArgumentRanges(self._Time_MonthOfYear_m3)
        self.SharedMedia_EmptyTitle = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "SharedMedia.EmptyTitle")
        self.Call_PhoneCallInProgressMessage = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Call.PhoneCallInProgressMessage")
        self.Notification_GroupActivated = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notification.GroupActivated")
        self.Checkout_Name = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Checkout.Name")
        self.Passport_Address_PostcodePlaceholder = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Address.PostcodePlaceholder")
        self._AUTH_REGION = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "AUTH_REGION")
        self._AUTH_REGION_r = extractArgumentRanges(self._AUTH_REGION)
        self.Settings_NotificationsAndSounds = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Settings.NotificationsAndSounds")
        self.Conversation_EncryptionCanceled = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.EncryptionCanceled")
        self._GroupInfo_InvitationLinkAcceptChannel = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "GroupInfo.InvitationLinkAcceptChannel")
        self._GroupInfo_InvitationLinkAcceptChannel_r = extractArgumentRanges(self._GroupInfo_InvitationLinkAcceptChannel)
        self.AccessDenied_SaveMedia = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "AccessDenied.SaveMedia")
        self.InviteText_URL = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "InviteText.URL")
        self.Passport_CorrectErrors = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.CorrectErrors")
        self._Channel_AdminLog_MessageInvitedNameUsername = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.AdminLog.MessageInvitedNameUsername")
        self._Channel_AdminLog_MessageInvitedNameUsername_r = extractArgumentRanges(self._Channel_AdminLog_MessageInvitedNameUsername)
        self.Notifications_Badge_CountUnreadMessages = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notifications.Badge.CountUnreadMessages")
        self.Appearance_ReduceMotion = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Appearance.ReduceMotion")
        self.Compose_GroupTokenListPlaceholder = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Compose.GroupTokenListPlaceholder")
        self.Passport_Address_CityPlaceholder = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Address.CityPlaceholder")
        self.Passport_InfoFAQ_URL = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.InfoFAQ_URL")
        self.Conversation_MessageDeliveryFailed = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.MessageDeliveryFailed")
        self.Privacy_PaymentsClear_PaymentInfo = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Privacy.PaymentsClear.PaymentInfo")
        self.Notifications_GroupNotifications = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notifications.GroupNotifications")
        self.CheckoutInfo_SaveInfoHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "CheckoutInfo.SaveInfoHelp")
        self.Notification_Mute1hMin = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notification.Mute1hMin")
        self.Privacy_TopPeersWarning = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Privacy.TopPeersWarning")
        self.StickerPacksSettings_ArchivedMasks_Info = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "StickerPacksSettings.ArchivedMasks.Info")
        self.ChannelMembers_WhoCanAddMembers_AllMembers = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ChannelMembers.WhoCanAddMembers.AllMembers")
        self.Channel_Edit_PrivatePublicLinkAlert = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.Edit.PrivatePublicLinkAlert")
        self.Watch_Conversation_UserInfo = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Watch.Conversation.UserInfo")
        self.Application_Name = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Application.Name")
        self.Conversation_AddToReadingList = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.AddToReadingList")
        self.Conversation_FileDropbox = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.FileDropbox")
        self.Login_PhonePlaceholder = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Login.PhonePlaceholder")
        self.SocksProxySetup_ProxyEnabled = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "SocksProxySetup.ProxyEnabled")
        self.Profile_MessageLifetime1d = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Profile.MessageLifetime1d")
        self.CheckoutInfo_ShippingInfoCityPlaceholder = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "CheckoutInfo.ShippingInfoCityPlaceholder")
        self.Notifications_ChannelNotificationsSound = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notifications.ChannelNotificationsSound")
        self.Calls_CallTabDescription = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Calls.CallTabDescription")
        self.Passport_DeletePersonalDetails = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.DeletePersonalDetails")
        self.Passport_Address_AddBankStatement = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Address.AddBankStatement")
        self.Resolve_ErrorNotFound = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Resolve.ErrorNotFound")
        self.Watch_Message_Call = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Watch.Message.Call")
        self.PhotoEditor_FadeTool = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PhotoEditor.FadeTool")
        self.Channel_Setup_TypePublicHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.Setup.TypePublicHelp")
        self.GroupInfo_InviteLink_RevokeAlert_Success = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "GroupInfo.InviteLink.RevokeAlert.Success")
        self.Channel_Setup_PublicNoLink = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.Setup.PublicNoLink")
        self.Privacy_Calls_P2PHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Privacy.Calls.P2PHelp")
        self.Conversation_Info = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.Info")
        self._Time_TodayAt = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Time.TodayAt")
        self._Time_TodayAt_r = extractArgumentRanges(self._Time_TodayAt)
        self.AutoDownloadSettings_VideosTitle = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "AutoDownloadSettings.VideosTitle")
        self.Conversation_Processing = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.Processing")
        self.Conversation_RestrictedInline = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.RestrictedInline")
        self._InstantPage_AuthorAndDateTitle = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "InstantPage.AuthorAndDateTitle")
        self._InstantPage_AuthorAndDateTitle_r = extractArgumentRanges(self._InstantPage_AuthorAndDateTitle)
        self._Watch_LastSeen_AtDate = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Watch.LastSeen.AtDate")
        self._Watch_LastSeen_AtDate_r = extractArgumentRanges(self._Watch_LastSeen_AtDate)
        self.Conversation_Location = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.Location")
        self.DialogList_PasscodeLockHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "DialogList.PasscodeLockHelp")
        self.Channel_Management_Title = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.Management.Title")
        self.Notifications_InAppNotificationsPreview = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notifications.InAppNotificationsPreview")
        self.EnterPasscode_EnterTitle = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "EnterPasscode.EnterTitle")
        self.ReportPeer_ReasonOther_Title = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ReportPeer.ReasonOther.Title")
        self.Month_GenJanuary = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Month.GenJanuary")
        self.Conversation_ForwardChats = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.ForwardChats")
        self.Channel_UpdatePhotoItem = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.UpdatePhotoItem")
        self.UserInfo_StartSecretChat = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "UserInfo.StartSecretChat")
        self.PrivacySettings_LastSeenNobody = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PrivacySettings.LastSeenNobody")
        self._FileSize_MB = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "FileSize.MB")
        self._FileSize_MB_r = extractArgumentRanges(self._FileSize_MB)
        self.ChatSearch_SearchPlaceholder = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ChatSearch.SearchPlaceholder")
        self.TwoStepAuth_ConfirmationAbort = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "TwoStepAuth.ConfirmationAbort")
        self.FastTwoStepSetup_HintSection = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "FastTwoStepSetup.HintSection")
        self.TwoStepAuth_SetupPasswordConfirmFailed = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "TwoStepAuth.SetupPasswordConfirmFailed")
        self._LastSeen_YesterdayAt = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "LastSeen.YesterdayAt")
        self._LastSeen_YesterdayAt_r = extractArgumentRanges(self._LastSeen_YesterdayAt)
        self.GroupInfo_GroupHistoryVisible = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "GroupInfo.GroupHistoryVisible")
        self.AppleWatch_ReplyPresetsHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "AppleWatch.ReplyPresetsHelp")
        self.Localization_LanguageName = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Localization.LanguageName")
        self.Map_OpenIn = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Map.OpenIn")
        self.Message_File = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Message.File")
        self.Call_ReportSend = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Call.ReportSend")
        self._Channel_AdminLog_MessageChangedGroupUsername = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.AdminLog.MessageChangedGroupUsername")
        self._Channel_AdminLog_MessageChangedGroupUsername_r = extractArgumentRanges(self._Channel_AdminLog_MessageChangedGroupUsername)
        self._CHAT_MESSAGE_GAME = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "CHAT_MESSAGE_GAME")
        self._CHAT_MESSAGE_GAME_r = extractArgumentRanges(self._CHAT_MESSAGE_GAME)
        self._Time_PreciseDate_m1 = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Time.PreciseDate_m1")
        self._Time_PreciseDate_m1_r = extractArgumentRanges(self._Time_PreciseDate_m1)
        self.Month_ShortMay = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Month.ShortMay")
        self.Tour_Text3 = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Tour.Text3")
        self.Contacts_GlobalSearch = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Contacts.GlobalSearch")
        self.DialogList_LanguageTooltip = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "DialogList.LanguageTooltip")
        self.AuthSessions_LogOutApplications = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "AuthSessions.LogOutApplications")
        self.Map_LoadError = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Map.LoadError")
        self.Settings_ProxyConnecting = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Settings.ProxyConnecting")
        self.Passport_Language_fa = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Language.fa")
        self.AccessDenied_VoiceMicrophone = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "AccessDenied.VoiceMicrophone")
        self._CHANNEL_MESSAGE_STICKER = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "CHANNEL_MESSAGE_STICKER")
        self._CHANNEL_MESSAGE_STICKER_r = extractArgumentRanges(self._CHANNEL_MESSAGE_STICKER)
        self.Passport_Address_TypeUtilityBillUploadScan = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Address.TypeUtilityBillUploadScan")
        self.PrivacySettings_Title = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PrivacySettings.Title")
        self.PasscodeSettings_TurnPasscodeOff = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PasscodeSettings.TurnPasscodeOff")
        self.MediaPicker_AddCaption = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "MediaPicker.AddCaption")
        self.Channel_AdminLog_BanReadMessages = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.AdminLog.BanReadMessages")
        self.Channel_Status = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.Status")
        self.Map_ChooseLocationTitle = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Map.ChooseLocationTitle")
        self.Notifications_ChannelNotifications = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notifications.ChannelNotifications")
        self.Map_OpenInYandexNavigator = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Map.OpenInYandexNavigator")
        self.AutoNightTheme_PreferredTheme = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "AutoNightTheme.PreferredTheme")
        self.State_WaitingForNetwork = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "State.WaitingForNetwork")
        self.TwoStepAuth_EmailHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "TwoStepAuth.EmailHelp")
        self.Conversation_StopLiveLocation = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.StopLiveLocation")
        self.Privacy_SecretChatsLinkPreviewsHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Privacy.SecretChatsLinkPreviewsHelp")
        self.PhotoEditor_SharpenTool = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PhotoEditor.SharpenTool")
        self.Common_of = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Common.of")
        self.AuthSessions_Title = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "AuthSessions.Title")
        self.Passport_Scans_UploadNew = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Scans.UploadNew")
        self.Message_PinnedLiveLocationMessage = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Message.PinnedLiveLocationMessage")
        self.Passport_FieldIdentityDetailsHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.FieldIdentityDetailsHelp")
        self.PrivacyLastSeenSettings_AlwaysShareWith = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PrivacyLastSeenSettings.AlwaysShareWith")
        self.EnterPasscode_EnterPasscode = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "EnterPasscode.EnterPasscode")
        self.Notifications_Reset = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notifications.Reset")
        self._Map_LiveLocationPrivateDescription = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Map.LiveLocationPrivateDescription")
        self._Map_LiveLocationPrivateDescription_r = extractArgumentRanges(self._Map_LiveLocationPrivateDescription)
        self.GroupInfo_InvitationLinkGroupFull = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "GroupInfo.InvitationLinkGroupFull")
        self._Channel_AdminLog_MessageChangedChannelUsername = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.AdminLog.MessageChangedChannelUsername")
        self._Channel_AdminLog_MessageChangedChannelUsername_r = extractArgumentRanges(self._Channel_AdminLog_MessageChangedChannelUsername)
        self._CHAT_MESSAGE_DOC = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "CHAT_MESSAGE_DOC")
        self._CHAT_MESSAGE_DOC_r = extractArgumentRanges(self._CHAT_MESSAGE_DOC)
        self.Watch_AppName = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Watch.AppName")
        self.ConvertToSupergroup_HelpTitle = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ConvertToSupergroup.HelpTitle")
        self.Conversation_TapAndHoldToRecord = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.TapAndHoldToRecord")
        self._MESSAGE_GIF = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "MESSAGE_GIF")
        self._MESSAGE_GIF_r = extractArgumentRanges(self._MESSAGE_GIF)
        self._DialogList_EncryptedChatStartedOutgoing = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "DialogList.EncryptedChatStartedOutgoing")
        self._DialogList_EncryptedChatStartedOutgoing_r = extractArgumentRanges(self._DialogList_EncryptedChatStartedOutgoing)
        self.Checkout_PayWithTouchId = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Checkout.PayWithTouchId")
        self.Passport_Language_ko = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Language.ko")
        self.Conversation_DiscardVoiceMessageTitle = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.DiscardVoiceMessageTitle")
        self._CHAT_ADD_YOU = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "CHAT_ADD_YOU")
        self._CHAT_ADD_YOU_r = extractArgumentRanges(self._CHAT_ADD_YOU)
        self.CheckoutInfo_ShippingInfoCity = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "CheckoutInfo.ShippingInfoCity")
        self.Group_AdminLog_EmptyText = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Group.AdminLog.EmptyText")
        self.AutoDownloadSettings_GroupChats = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "AutoDownloadSettings.GroupChats")
        self.Conversation_ClousStorageInfo_Description3 = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.ClousStorageInfo.Description3")
        self.Notifications_ExceptionsMuted = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notifications.ExceptionsMuted")
        self.Conversation_PinMessageAlertGroup = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.PinMessageAlertGroup")
        self.Settings_FAQ_Intro = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Settings.FAQ_Intro")
        self.PrivacySettings_AuthSessions = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PrivacySettings.AuthSessions")
        self._CHAT_MESSAGE_GEOLIVE = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "CHAT_MESSAGE_GEOLIVE")
        self._CHAT_MESSAGE_GEOLIVE_r = extractArgumentRanges(self._CHAT_MESSAGE_GEOLIVE)
        self.Passport_Address_Postcode = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Address.Postcode")
        self.Tour_Title5 = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Tour.Title5")
        self.ChatAdmins_AllMembersAreAdmins = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ChatAdmins.AllMembersAreAdmins")
        self.Group_Management_AddModeratorHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Group.Management.AddModeratorHelp")
        self.Channel_Username_CheckingUsername = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.Username.CheckingUsername")
        self._DialogList_SingleRecordingVideoMessageSuffix = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "DialogList.SingleRecordingVideoMessageSuffix")
        self._DialogList_SingleRecordingVideoMessageSuffix_r = extractArgumentRanges(self._DialogList_SingleRecordingVideoMessageSuffix)
        self._Contacts_AccessDeniedHelpPortrait = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Contacts.AccessDeniedHelpPortrait")
        self._Contacts_AccessDeniedHelpPortrait_r = extractArgumentRanges(self._Contacts_AccessDeniedHelpPortrait)
        self._Checkout_LiabilityAlert = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Checkout.LiabilityAlert")
        self._Checkout_LiabilityAlert_r = extractArgumentRanges(self._Checkout_LiabilityAlert)
        self.Channel_Info_BlackList = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.Info.BlackList")
        self.Profile_BotInfo = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Profile.BotInfo")
        self.Stickers_SuggestAll = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Stickers.SuggestAll")
        self.Compose_NewChannel_Members = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Compose.NewChannel.Members")
        self.Notification_Reply = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notification.Reply")
        self.Watch_Stickers_Recents = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Watch.Stickers.Recents")
        self.GroupInfo_SetGroupPhotoStop = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "GroupInfo.SetGroupPhotoStop")
        self.Channel_Stickers_Placeholder = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.Stickers.Placeholder")
        self.AttachmentMenu_File = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "AttachmentMenu.File")
        self._MESSAGE_STICKER = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "MESSAGE_STICKER")
        self._MESSAGE_STICKER_r = extractArgumentRanges(self._MESSAGE_STICKER)
        self.Profile_MessageLifetime5s = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Profile.MessageLifetime5s")
        self.Privacy_ContactsReset = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Privacy.ContactsReset")
        self._PINNED_PHOTO = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PINNED_PHOTO")
        self._PINNED_PHOTO_r = extractArgumentRanges(self._PINNED_PHOTO)
        self.Channel_AdminLog_CanAddAdmins = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.AdminLog.CanAddAdmins")
        self.TwoStepAuth_SetupHint = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "TwoStepAuth.SetupHint")
        self.Conversation_StatusLeftGroup = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.StatusLeftGroup")
        self.Settings_CopyUsername = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Settings.CopyUsername")
        self.Passport_Identity_CountryPlaceholder = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Identity.CountryPlaceholder")
        self.ChatSettings_AutoDownloadDocuments = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ChatSettings.AutoDownloadDocuments")
        self.MediaPicker_TapToUngroupDescription = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "MediaPicker.TapToUngroupDescription")
        self.Conversation_ShareBotLocationConfirmation = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.ShareBotLocationConfirmation")
        self.Conversation_DeleteMessagesForMe = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.DeleteMessagesForMe")
        self.Notification_PassportValuePersonalDetails = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notification.PassportValuePersonalDetails")
        self.Message_PinnedAnimationMessage = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Message.PinnedAnimationMessage")
        self.Passport_FieldIdentityUploadHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.FieldIdentityUploadHelp")
        self.SocksProxySetup_ConnectAndSave = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "SocksProxySetup.ConnectAndSave")
        self.SocksProxySetup_FailedToConnect = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "SocksProxySetup.FailedToConnect")
        self.Checkout_ErrorPrecheckoutFailed = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Checkout.ErrorPrecheckoutFailed")
        self.Camera_PhotoMode = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Camera.PhotoMode")
        self._Time_MonthOfYear_m2 = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Time.MonthOfYear_m2")
        self._Time_MonthOfYear_m2_r = extractArgumentRanges(self._Time_MonthOfYear_m2)
        self.Channel_About_Placeholder = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.About.Placeholder")
        self.Map_Directions = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Map.Directions")
        self.Channel_About_Title = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.About.Title")
        self._MESSAGE_PHOTO = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "MESSAGE_PHOTO")
        self._MESSAGE_PHOTO_r = extractArgumentRanges(self._MESSAGE_PHOTO)
        self.Calls_RatingTitle = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Calls.RatingTitle")
        self.SharedMedia_EmptyText = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "SharedMedia.EmptyText")
        self.Channel_Stickers_Searching = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.Stickers.Searching")
        self.Passport_Address_AddUtilityBill = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Address.AddUtilityBill")
        self.Login_PadPhoneHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Login.PadPhoneHelp")
        self.StickerPacksSettings_ArchivedPacks = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "StickerPacksSettings.ArchivedPacks")
        self.Passport_Language_th = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Language.th")
        self.Channel_ErrorAccessDenied = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.ErrorAccessDenied")
        self.Generic_ErrorMoreInfo = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Generic.ErrorMoreInfo")
        self.Channel_AdminLog_TitleAllEvents = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.AdminLog.TitleAllEvents")
        self.Settings_Proxy = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Settings.Proxy")
        self.Passport_Language_lt = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Language.lt")
        self.ChannelMembers_WhoCanAddMembersAllHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ChannelMembers.WhoCanAddMembersAllHelp")
        self.Passport_Address_CountryPlaceholder = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Address.CountryPlaceholder")
        self.ChangePhoneNumberCode_CodePlaceholder = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ChangePhoneNumberCode.CodePlaceholder")
        self.Camera_SquareMode = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Camera.SquareMode")
        self._Conversation_EncryptedPlaceholderTitleOutgoing = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.EncryptedPlaceholderTitleOutgoing")
        self._Conversation_EncryptedPlaceholderTitleOutgoing_r = extractArgumentRanges(self._Conversation_EncryptedPlaceholderTitleOutgoing)
        self.NetworkUsageSettings_CallDataSection = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "NetworkUsageSettings.CallDataSection")
        self.Login_PadPhoneHelpTitle = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Login.PadPhoneHelpTitle")
        self.Profile_CreateNewContact = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Profile.CreateNewContact")
        self.AccessDenied_VideoMessageMicrophone = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "AccessDenied.VideoMessageMicrophone")
        self.AutoDownloadSettings_VoiceMessagesTitle = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "AutoDownloadSettings.VoiceMessagesTitle")
        self.PhotoEditor_VignetteTool = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PhotoEditor.VignetteTool")
        self.LastSeen_WithinAWeek = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "LastSeen.WithinAWeek")
        self.Widget_NoUsers = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Widget.NoUsers")
        self.Passport_Identity_DocumentNumber = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Identity.DocumentNumber")
        self.Application_Update = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Application.Update")
        self.Calls_NewCall = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Calls.NewCall")
        self._CHANNEL_MESSAGE_AUDIO = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "CHANNEL_MESSAGE_AUDIO")
        self._CHANNEL_MESSAGE_AUDIO_r = extractArgumentRanges(self._CHANNEL_MESSAGE_AUDIO)
        self.DialogList_NoMessagesText = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "DialogList.NoMessagesText")
        self.MaskStickerSettings_Info = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "MaskStickerSettings.Info")
        self.ChatSettings_AutoDownloadTitle = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ChatSettings.AutoDownloadTitle")
        self.Passport_FieldAddressHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.FieldAddressHelp")
        self.Passport_Language_dz = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Language.dz")
        self.Conversation_FilePhotoOrVideo = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.FilePhotoOrVideo")
        self.Channel_AdminLog_BanSendStickers = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.AdminLog.BanSendStickers")
        self.Common_Next = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Common.Next")
        self.Stickers_RemoveFromFavorites = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Stickers.RemoveFromFavorites")
        self.Watch_Notification_Joined = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Watch.Notification.Joined")
        self._Channel_AdminLog_MessageRestrictedNewSetting = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.AdminLog.MessageRestrictedNewSetting")
        self._Channel_AdminLog_MessageRestrictedNewSetting_r = extractArgumentRanges(self._Channel_AdminLog_MessageRestrictedNewSetting)
        self.Passport_DeleteAddress = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.DeleteAddress")
        self.ContactInfo_PhoneLabelHome = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ContactInfo.PhoneLabelHome")
        self.GroupInfo_DeleteAndExitConfirmation = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "GroupInfo.DeleteAndExitConfirmation")
        self.NotificationsSound_Tremolo = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "NotificationsSound.Tremolo")
        self.TwoStepAuth_EmailInvalid = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "TwoStepAuth.EmailInvalid")
        self.Privacy_ContactsTitle = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Privacy.ContactsTitle")
        self.Passport_Address_TypeBankStatement = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Address.TypeBankStatement")
        self._CHAT_MESSAGE_VIDEO = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "CHAT_MESSAGE_VIDEO")
        self._CHAT_MESSAGE_VIDEO_r = extractArgumentRanges(self._CHAT_MESSAGE_VIDEO)
        self.Month_GenJune = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Month.GenJune")
        self.Map_LiveLocationFor15Minutes = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Map.LiveLocationFor15Minutes")
        self._Login_EmailCodeSubject = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Login.EmailCodeSubject")
        self._Login_EmailCodeSubject_r = extractArgumentRanges(self._Login_EmailCodeSubject)
        self._CHAT_TITLE_EDITED = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "CHAT_TITLE_EDITED")
        self._CHAT_TITLE_EDITED_r = extractArgumentRanges(self._CHAT_TITLE_EDITED)
        self.ContactInfo_PhoneLabelHomeFax = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ContactInfo.PhoneLabelHomeFax")
        self._NetworkUsageSettings_WifiUsageSince = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "NetworkUsageSettings.WifiUsageSince")
        self._NetworkUsageSettings_WifiUsageSince_r = extractArgumentRanges(self._NetworkUsageSettings_WifiUsageSince)
        self.Watch_LastSeen_Lately = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Watch.LastSeen.Lately")
        self.Watch_Compose_CurrentLocation = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Watch.Compose.CurrentLocation")
        self.DialogList_RecentTitlePeople = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "DialogList.RecentTitlePeople")
        self.GroupInfo_Notifications = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "GroupInfo.Notifications")
        self.Call_ReportPlaceholder = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Call.ReportPlaceholder")
        self._AuthSessions_Message = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "AuthSessions.Message")
        self._AuthSessions_Message_r = extractArgumentRanges(self._AuthSessions_Message)
        self._MESSAGE_DOC = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "MESSAGE_DOC")
        self._MESSAGE_DOC_r = extractArgumentRanges(self._MESSAGE_DOC)
        self.Group_Username_CreatePrivateLinkHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Group.Username.CreatePrivateLinkHelp")
        self.Notifications_GroupNotificationsSound = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notifications.GroupNotificationsSound")
        self.AuthSessions_EmptyTitle = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "AuthSessions.EmptyTitle")
        self.Privacy_GroupsAndChannels_AlwaysAllow_Title = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Privacy.GroupsAndChannels.AlwaysAllow.Title")
        self.Passport_Language_he = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Language.he")
        self._MediaPicker_Nof = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "MediaPicker.Nof")
        self._MediaPicker_Nof_r = extractArgumentRanges(self._MediaPicker_Nof)
        self.Common_Create = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Common.Create")
        self.Contacts_TopSection = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Contacts.TopSection")
        self._Map_DirectionsDriveEta = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Map.DirectionsDriveEta")
        self._Map_DirectionsDriveEta_r = extractArgumentRanges(self._Map_DirectionsDriveEta)
        self.PrivacyPolicy_DeclineMessage = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PrivacyPolicy.DeclineMessage")
        self.Your_cards_number_is_invalid = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Your_cards_number_is_invalid")
        self._MESSAGE_INVOICE = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "MESSAGE_INVOICE")
        self._MESSAGE_INVOICE_r = extractArgumentRanges(self._MESSAGE_INVOICE)
        self.Localization_LanguageCustom = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Localization.LanguageCustom")
        self._Channel_AdminLog_MessageRemovedChannelUsername = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.AdminLog.MessageRemovedChannelUsername")
        self._Channel_AdminLog_MessageRemovedChannelUsername_r = extractArgumentRanges(self._Channel_AdminLog_MessageRemovedChannelUsername)
        self.Group_MessagePhotoRemoved = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Group.MessagePhotoRemoved")
        self.Appearance_Animations = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Appearance.Animations")
        self.UserInfo_AddToExisting = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "UserInfo.AddToExisting")
        self.NotificationsSound_Aurora = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "NotificationsSound.Aurora")
        self._LastSeen_AtDate = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "LastSeen.AtDate")
        self._LastSeen_AtDate_r = extractArgumentRanges(self._LastSeen_AtDate)
        self.Conversation_MessageDialogRetry = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.MessageDialogRetry")
        self.Watch_ChatList_NoConversationsTitle = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Watch.ChatList.NoConversationsTitle")
        self.Passport_Language_my = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Language.my")
        self.Stickers_GroupStickers = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Stickers.GroupStickers")
        self.BlockedUsers_Title = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "BlockedUsers.Title")
        self._LiveLocationUpdated_TodayAt = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "LiveLocationUpdated.TodayAt")
        self._LiveLocationUpdated_TodayAt_r = extractArgumentRanges(self._LiveLocationUpdated_TodayAt)
        self.ContactInfo_PhoneLabelWork = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ContactInfo.PhoneLabelWork")
        self.ChatSettings_ConnectionType_UseSocks5 = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ChatSettings.ConnectionType.UseSocks5")
        self.Passport_FieldAddressTranslationHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.FieldAddressTranslationHelp")
        self.Cache_ClearNone = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Cache.ClearNone")
        self.SecretTimer_VideoDescription = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "SecretTimer.VideoDescription")
        self.Login_InvalidCodeError = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Login.InvalidCodeError")
        self.Channel_BanList_BlockedTitle = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.BanList.BlockedTitle")
        self.Passport_PasswordHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.PasswordHelp")
        self.NetworkUsageSettings_Cellular = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "NetworkUsageSettings.Cellular")
        self.Watch_Location_Access = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Watch.Location.Access")
        self.PrivacySettings_DeleteAccountIfAwayFor = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PrivacySettings.DeleteAccountIfAwayFor")
        self.Channel_AdminLog_EmptyFilterText = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.AdminLog.EmptyFilterText")
        self.Channel_AdminLog_EmptyText = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.AdminLog.EmptyText")
        self.PrivacySettings_DeleteAccountTitle = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PrivacySettings.DeleteAccountTitle")
        self.Passport_Language_ms = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Language.ms")
        self.PrivacyLastSeenSettings_CustomShareSettings_Delete = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PrivacyLastSeenSettings.CustomShareSettings.Delete")
        self._ENCRYPTED_MESSAGE = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ENCRYPTED_MESSAGE")
        self._ENCRYPTED_MESSAGE_r = extractArgumentRanges(self._ENCRYPTED_MESSAGE)
        self.Watch_LastSeen_WithinAMonth = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Watch.LastSeen.WithinAMonth")
        self.PrivacyLastSeenSettings_CustomHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PrivacyLastSeenSettings.CustomHelp")
        self.TwoStepAuth_EnterPasswordHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "TwoStepAuth.EnterPasswordHelp")
        self.Bot_Stop = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Bot.Stop")
        self.Privacy_GroupsAndChannels_AlwaysAllow_Placeholder = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Privacy.GroupsAndChannels.AlwaysAllow.Placeholder")
        self.UserInfo_BotSettings = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "UserInfo.BotSettings")
        self.Your_cards_expiration_month_is_invalid = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Your_cards_expiration_month_is_invalid")
        self.Passport_FieldIdentity = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.FieldIdentity")
        self.PrivacyLastSeenSettings_EmpryUsersPlaceholder = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PrivacyLastSeenSettings.EmpryUsersPlaceholder")
        self.Passport_Identity_EditInternalPassport = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Identity.EditInternalPassport")
        self._CHANNEL_MESSAGE_ROUND = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "CHANNEL_MESSAGE_ROUND")
        self._CHANNEL_MESSAGE_ROUND_r = extractArgumentRanges(self._CHANNEL_MESSAGE_ROUND)
        self.Passport_Identity_LatinNameHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Identity.LatinNameHelp")
        self.SocksProxySetup_Port = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "SocksProxySetup.Port")
        self.Message_VideoMessage = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Message.VideoMessage")
        self.Conversation_ContextMenuStickerPackInfo = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.ContextMenuStickerPackInfo")
        self.Login_ResetAccountProtected_LimitExceeded = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Login.ResetAccountProtected.LimitExceeded")
        self._CHAT_DELETE_MEMBER = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "CHAT_DELETE_MEMBER")
        self._CHAT_DELETE_MEMBER_r = extractArgumentRanges(self._CHAT_DELETE_MEMBER)
        self.Conversation_DiscardVoiceMessageAction = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.DiscardVoiceMessageAction")
        self.Camera_Title = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Camera.Title")
        self.Passport_Identity_IssueDate = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Identity.IssueDate")
        self.PhotoEditor_CurvesBlue = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PhotoEditor.CurvesBlue")
        self.Message_PinnedVideoMessage = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Message.PinnedVideoMessage")
        self._Login_EmailPhoneSubject = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Login.EmailPhoneSubject")
        self._Login_EmailPhoneSubject_r = extractArgumentRanges(self._Login_EmailPhoneSubject)
        self.Passport_Phone_UseTelegramNumberHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Phone.UseTelegramNumberHelp")
        self.Group_EditAdmin_PermissionChangeInfo = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Group.EditAdmin.PermissionChangeInfo")
        self.TwoStepAuth_Email = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "TwoStepAuth.Email")
        self.Stickers_SuggestNone = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Stickers.SuggestNone")
        self.Map_SendMyCurrentLocation = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Map.SendMyCurrentLocation")
        self._MESSAGE_ROUND = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "MESSAGE_ROUND")
        self._MESSAGE_ROUND_r = extractArgumentRanges(self._MESSAGE_ROUND)
        self.Passport_Identity_IssueDatePlaceholder = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Identity.IssueDatePlaceholder")
        self.Watch_Message_Invoice = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Watch.Message.Invoice")
        self.Map_Unknown = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Map.Unknown")
        self.Wallpaper_Set = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Wallpaper.Set")
        self.AccessDenied_Title = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "AccessDenied.Title")
        self.SharedMedia_CategoryLinks = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "SharedMedia.CategoryLinks")
        self.Localization_LanguageOther = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Localization.LanguageOther")
        self._CHAT_MESSAGES = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "CHAT_MESSAGES")
        self._CHAT_MESSAGES_r = extractArgumentRanges(self._CHAT_MESSAGES)
        self.SaveIncomingPhotosSettings_Title = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "SaveIncomingPhotosSettings.Title")
        self.Passport_Identity_TypeDriversLicense = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Identity.TypeDriversLicense")
        self.FastTwoStepSetup_HintHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "FastTwoStepSetup.HintHelp")
        self.Notifications_ExceptionsDefaultSound = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notifications.ExceptionsDefaultSound")
        self.TwoStepAuth_EmailSkipAlert = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "TwoStepAuth.EmailSkipAlert")
        self.ChatSettings_Stickers = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ChatSettings.Stickers")
        self.Camera_FlashOff = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Camera.FlashOff")
        self.TwoStepAuth_Title = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "TwoStepAuth.Title")
        self.Passport_Identity_Translation = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Identity.Translation")
        self.Checkout_ErrorProviderAccountTimeout = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Checkout.ErrorProviderAccountTimeout")
        self.TwoStepAuth_SetupPasswordEnterPasswordChange = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "TwoStepAuth.SetupPasswordEnterPasswordChange")
        self.WebSearch_Images = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "WebSearch.Images")
        self.Conversation_typing = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.typing")
        self.Common_Back = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Common.Back")
        self.PrivacySettings_DataSettingsHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PrivacySettings.DataSettingsHelp")
        self.Passport_Language_es = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Language.es")
        self.Common_Search = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Common.Search")
        self._CancelResetAccount_Success = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "CancelResetAccount.Success")
        self._CancelResetAccount_Success_r = extractArgumentRanges(self._CancelResetAccount_Success)
        self.Common_No = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Common.No")
        self.Login_EmailNotConfiguredError = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Login.EmailNotConfiguredError")
        self.Watch_Suggestion_OK = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Watch.Suggestion.OK")
        self.Profile_AddToExisting = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Profile.AddToExisting")
        self._Passport_Identity_NativeNameTitle = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Identity.NativeNameTitle")
        self._Passport_Identity_NativeNameTitle_r = extractArgumentRanges(self._Passport_Identity_NativeNameTitle)
        self._PINNED_NOTEXT = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PINNED_NOTEXT")
        self._PINNED_NOTEXT_r = extractArgumentRanges(self._PINNED_NOTEXT)
        self._Login_EmailCodeBody = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Login.EmailCodeBody")
        self._Login_EmailCodeBody_r = extractArgumentRanges(self._Login_EmailCodeBody)
        self.NotificationsSound_Keys = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "NotificationsSound.Keys")
        self.Passport_Phone_Title = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Phone.Title")
        self.Profile_About = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Profile.About")
        self._EncryptionKey_Description = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "EncryptionKey.Description")
        self._EncryptionKey_Description_r = extractArgumentRanges(self._EncryptionKey_Description)
        self.Conversation_UnreadMessages = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.UnreadMessages")
        self._DialogList_LiveLocationSharingTo = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "DialogList.LiveLocationSharingTo")
        self._DialogList_LiveLocationSharingTo_r = extractArgumentRanges(self._DialogList_LiveLocationSharingTo)
        self.Tour_Title3 = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Tour.Title3")
        self.Passport_Identity_FrontSide = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Identity.FrontSide")
        self.PrivacyLastSeenSettings_GroupsAndChannelsHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PrivacyLastSeenSettings.GroupsAndChannelsHelp")
        self.Watch_Contacts_NoResults = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Watch.Contacts.NoResults")
        self.Passport_Language_id = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Language.id")
        self.Passport_Identity_TypeIdentityCardUploadScan = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Identity.TypeIdentityCardUploadScan")
        self.Watch_UserInfo_MuteTitle = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Watch.UserInfo.MuteTitle")
        self._Privacy_GroupsAndChannels_InviteToGroupError = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Privacy.GroupsAndChannels.InviteToGroupError")
        self._Privacy_GroupsAndChannels_InviteToGroupError_r = extractArgumentRanges(self._Privacy_GroupsAndChannels_InviteToGroupError)
        self._Message_PinnedTextMessage = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Message.PinnedTextMessage")
        self._Message_PinnedTextMessage_r = extractArgumentRanges(self._Message_PinnedTextMessage)
        self._Watch_Time_ShortWeekdayAt = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Watch.Time.ShortWeekdayAt")
        self._Watch_Time_ShortWeekdayAt_r = extractArgumentRanges(self._Watch_Time_ShortWeekdayAt)
        self.Conversation_EmptyGifPanelPlaceholder = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.EmptyGifPanelPlaceholder")
        self.DialogList_Typing = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "DialogList.Typing")
        self.Notification_CallBack = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notification.CallBack")
        self.Passport_Language_ru = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Language.ru")
        self.Map_LocatingError = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Map.LocatingError")
        self.InfoPlist_NSFaceIDUsageDescription = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "InfoPlist.NSFaceIDUsageDescription")
        self.MediaPicker_Send = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "MediaPicker.Send")
        self.ChannelIntro_Title = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ChannelIntro.Title")
        self.AccessDenied_LocationAlwaysDenied = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "AccessDenied.LocationAlwaysDenied")
        self._PINNED_GIF = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PINNED_GIF")
        self._PINNED_GIF_r = extractArgumentRanges(self._PINNED_GIF)
        self._InviteText_SingleContact = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "InviteText.SingleContact")
        self._InviteText_SingleContact_r = extractArgumentRanges(self._InviteText_SingleContact)
        self.Passport_Address_TypePassportRegistration = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Address.TypePassportRegistration")
        self.Channel_EditAdmin_CannotEdit = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.EditAdmin.CannotEdit")
        self.LoginPassword_PasswordHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "LoginPassword.PasswordHelp")
        self.BlockedUsers_Unblock = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "BlockedUsers.Unblock")
        self.AutoDownloadSettings_Cellular = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "AutoDownloadSettings.Cellular")
        self.Passport_Language_ro = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Language.ro")
        self._Time_MonthOfYear_m1 = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Time.MonthOfYear_m1")
        self._Time_MonthOfYear_m1_r = extractArgumentRanges(self._Time_MonthOfYear_m1)
        self.Appearance_PreviewIncomingText = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Appearance.PreviewIncomingText")
        self.Passport_Identity_DateOfBirthPlaceholder = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Identity.DateOfBirthPlaceholder")
        self.Notifications_GroupNotificationsAlert = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notifications.GroupNotificationsAlert")
        self.Paint_Masks = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Paint.Masks")
        self.Appearance_ThemeDayClassic = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Appearance.ThemeDayClassic")
        self.StickerPack_ErrorNotFound = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "StickerPack.ErrorNotFound")
        self.Appearance_ThemeNight = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Appearance.ThemeNight")
        self.SecretTimer_ImageDescription = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "SecretTimer.ImageDescription")
        self._PINNED_CONTACT = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PINNED_CONTACT")
        self._PINNED_CONTACT_r = extractArgumentRanges(self._PINNED_CONTACT)
        self._FileSize_KB = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "FileSize.KB")
        self._FileSize_KB_r = extractArgumentRanges(self._FileSize_KB)
        self.Map_LiveLocationTitle = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Map.LiveLocationTitle")
        self.Watch_GroupInfo_Title = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Watch.GroupInfo.Title")
        self.Channel_AdminLog_EmptyTitle = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.AdminLog.EmptyTitle")
        self.PhotoEditor_Set = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PhotoEditor.Set")
        self.LiveLocation_MenuStopAll = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "LiveLocation.MenuStopAll")
        self.SocksProxySetup_AddProxy = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "SocksProxySetup.AddProxy")
        self._Notification_Invited = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notification.Invited")
        self._Notification_Invited_r = extractArgumentRanges(self._Notification_Invited)
        self.Watch_AuthRequired = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Watch.AuthRequired")
        self.Conversation_EncryptedDescription1 = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.EncryptedDescription1")
        self.AppleWatch_ReplyPresets = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "AppleWatch.ReplyPresets")
        self.Channel_Members_AddAdminErrorNotAMember = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.Members.AddAdminErrorNotAMember")
        self.Conversation_EncryptedDescription2 = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.EncryptedDescription2")
        self.SocksProxySetup_HostnamePlaceholder = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "SocksProxySetup.HostnamePlaceholder")
        self.NetworkUsageSettings_MediaVideoDataSection = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "NetworkUsageSettings.MediaVideoDataSection")
        self.Paint_Edit = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Paint.Edit")
        self.Passport_Language_nl = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Language.nl")
        self.LastSeen_Offline = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "LastSeen.Offline")
        self.Login_CodeFloodError = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Login.CodeFloodError")
        self.Conversation_EncryptedDescription3 = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.EncryptedDescription3")
        self.Notifications_Badge_IncludePublicGroups = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notifications.Badge.IncludePublicGroups")
        self.Conversation_EncryptedDescription4 = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.EncryptedDescription4")
        self.AppleWatch_Title = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "AppleWatch.Title")
        self.Contacts_AccessDeniedError = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Contacts.AccessDeniedError")
        self.Conversation_StatusTyping = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.StatusTyping")
        self.Share_Title = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Share.Title")
        self.TwoStepAuth_ConfirmationTitle = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "TwoStepAuth.ConfirmationTitle")
        self.Passport_Identity_FilesTitle = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Identity.FilesTitle")
        self.ChatSettings_Title = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ChatSettings.Title")
        self.AuthSessions_CurrentSession = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "AuthSessions.CurrentSession")
        self.Watch_Microphone_Access = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Watch.Microphone.Access")
        self._Notification_RenamedChat = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notification.RenamedChat")
        self._Notification_RenamedChat_r = extractArgumentRanges(self._Notification_RenamedChat)
        self.Conversation_LiveLocation = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.LiveLocation")
        self.Watch_Conversation_GroupInfo = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Watch.Conversation.GroupInfo")
        self.Passport_Language_fr = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Language.fr")
        self.UserInfo_Title = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "UserInfo.Title")
        self.Passport_Identity_DoesNotExpire = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Identity.DoesNotExpire")
        self.Map_LiveLocationGroupDescription = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Map.LiveLocationGroupDescription")
        self.Login_InfoHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Login.InfoHelp")
        self.ShareMenu_ShareTo = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ShareMenu.ShareTo")
        self.Message_PinnedGame = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Message.PinnedGame")
        self.Channel_AdminLog_CanSendMessages = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.AdminLog.CanSendMessages")
        self._AutoNightTheme_LocationHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "AutoNightTheme.LocationHelp")
        self._AutoNightTheme_LocationHelp_r = extractArgumentRanges(self._AutoNightTheme_LocationHelp)
        self.Notification_RenamedGroup = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notification.RenamedGroup")
        self._Call_PrivacyErrorMessage = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Call.PrivacyErrorMessage")
        self._Call_PrivacyErrorMessage_r = extractArgumentRanges(self._Call_PrivacyErrorMessage)
        self.Passport_Address_Street = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Address.Street")
        self.Weekday_Thursday = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Weekday.Thursday")
        self.FastTwoStepSetup_HintPlaceholder = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "FastTwoStepSetup.HintPlaceholder")
        self.PrivacySettings_DataSettings = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PrivacySettings.DataSettings")
        self.ChangePhoneNumberNumber_Title = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ChangePhoneNumberNumber.Title")
        self.NotificationsSound_Bell = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "NotificationsSound.Bell")
        self.Notifications_Badge_IncludeMutedChats = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notifications.Badge.IncludeMutedChats")
        self.TwoStepAuth_EnterPasswordInvalid = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "TwoStepAuth.EnterPasswordInvalid")
        self.DialogList_SearchSectionMessages = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "DialogList.SearchSectionMessages")
        self.Media_ShareThisVideo = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Media.ShareThisVideo")
        self.Call_ReportIncludeLogDescription = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Call.ReportIncludeLogDescription")
        self.Preview_DeleteGif = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Preview.DeleteGif")
        self.Passport_Address_OneOfTypeTemporaryRegistration = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Address.OneOfTypeTemporaryRegistration")
        self.Weekday_Saturday = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Weekday.Saturday")
        self.UserInfo_DeleteContact = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "UserInfo.DeleteContact")
        self.Notifications_ResetAllNotifications = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notifications.ResetAllNotifications")
        self.SocksProxySetup_SaveProxy = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "SocksProxySetup.SaveProxy")
        self.Passport_Identity_Country = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Identity.Country")
        self.Notification_MessageLifetimeRemovedOutgoing = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notification.MessageLifetimeRemovedOutgoing")
        self.Login_ContinueWithLocalization = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Login.ContinueWithLocalization")
        self.GroupInfo_AddParticipant = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "GroupInfo.AddParticipant")
        self.Watch_Location_Current = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Watch.Location.Current")
        self.Checkout_NewCard_SaveInfoHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Checkout.NewCard.SaveInfoHelp")
        self._Settings_ApplyProxyAlertCredentials = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Settings.ApplyProxyAlertCredentials")
        self._Settings_ApplyProxyAlertCredentials_r = extractArgumentRanges(self._Settings_ApplyProxyAlertCredentials)
        self.MediaPicker_CameraRoll = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "MediaPicker.CameraRoll")
        self.Channel_AdminLog_CanPinMessages = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.AdminLog.CanPinMessages")
        self.KeyCommand_NewMessage = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "KeyCommand.NewMessage")
        self._ChannelInfo_AddParticipantConfirmation = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ChannelInfo.AddParticipantConfirmation")
        self._ChannelInfo_AddParticipantConfirmation_r = extractArgumentRanges(self._ChannelInfo_AddParticipantConfirmation)
        self.NetworkUsageSettings_TotalSection = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "NetworkUsageSettings.TotalSection")
        self._PINNED_AUDIO = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PINNED_AUDIO")
        self._PINNED_AUDIO_r = extractArgumentRanges(self._PINNED_AUDIO)
        self.Privacy_GroupsAndChannels = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Privacy.GroupsAndChannels")
        self._Time_PreciseDate_m12 = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Time.PreciseDate_m12")
        self._Time_PreciseDate_m12_r = extractArgumentRanges(self._Time_PreciseDate_m12)
        self.Conversation_DiscardVoiceMessageDescription = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.DiscardVoiceMessageDescription")
        self.Passport_Address_ScansHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Address.ScansHelp")
        self._Notification_ChangedGroupPhoto = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notification.ChangedGroupPhoto")
        self._Notification_ChangedGroupPhoto_r = extractArgumentRanges(self._Notification_ChangedGroupPhoto)
        self.TwoStepAuth_RemovePassword = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "TwoStepAuth.RemovePassword")
        self.Privacy_GroupsAndChannels_CustomHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Privacy.GroupsAndChannels.CustomHelp")
        self.Passport_Identity_Gender = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Identity.Gender")
        self.UserInfo_NotificationsDisable = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "UserInfo.NotificationsDisable")
        self.Watch_UserInfo_Service = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Watch.UserInfo.Service")
        self.Privacy_Calls_CustomHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Privacy.Calls.CustomHelp")
        self.ChangePhoneNumberCode_Code = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ChangePhoneNumberCode.Code")
        self.UserInfo_Invite = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "UserInfo.Invite")
        self.CheckoutInfo_ErrorStateInvalid = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "CheckoutInfo.ErrorStateInvalid")
        self.DialogList_ClearHistoryConfirmation = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "DialogList.ClearHistoryConfirmation")
        self.CheckoutInfo_ErrorEmailInvalid = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "CheckoutInfo.ErrorEmailInvalid")
        self.Month_GenNovember = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Month.GenNovember")
        self.UserInfo_NotificationsEnable = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "UserInfo.NotificationsEnable")
        self._Target_InviteToGroupConfirmation = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Target.InviteToGroupConfirmation")
        self._Target_InviteToGroupConfirmation_r = extractArgumentRanges(self._Target_InviteToGroupConfirmation)
        self.Map_Map = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Map.Map")
        self.Map_OpenInMaps = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Map.OpenInMaps")
        self.Common_OK = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Common.OK")
        self.TwoStepAuth_SetupHintTitle = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "TwoStepAuth.SetupHintTitle")
        self.GroupInfo_LeftStatus = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "GroupInfo.LeftStatus")
        self.Cache_ClearProgress = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Cache.ClearProgress")
        self.Login_InvalidPhoneError = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Login.InvalidPhoneError")
        self.Passport_Authorize = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Authorize")
        self.Cache_ClearEmpty = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Cache.ClearEmpty")
        self.Map_Search = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Map.Search")
        self.Passport_Identity_Translations = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Identity.Translations")
        self.ChannelMembers_GroupAdminsTitle = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ChannelMembers.GroupAdminsTitle")
        self._Channel_AdminLog_MessageRemovedGroupUsername = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.AdminLog.MessageRemovedGroupUsername")
        self._Channel_AdminLog_MessageRemovedGroupUsername_r = extractArgumentRanges(self._Channel_AdminLog_MessageRemovedGroupUsername)
        self.ChatSettings_AutomaticPhotoDownload = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ChatSettings.AutomaticPhotoDownload")
        self.Group_ErrorAddTooMuchAdmins = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Group.ErrorAddTooMuchAdmins")
        self.SocksProxySetup_Password = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "SocksProxySetup.Password")
        self.Login_SelectCountry_Title = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Login.SelectCountry.Title")
        self._MESSAGE_PHOTOS = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "MESSAGE_PHOTOS")
        self._MESSAGE_PHOTOS_r = extractArgumentRanges(self._MESSAGE_PHOTOS)
        self.Notifications_GroupNotificationsHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notifications.GroupNotificationsHelp")
        self.PhotoEditor_CropAspectRatioSquare = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PhotoEditor.CropAspectRatioSquare")
        self.Notification_CallOutgoing = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notification.CallOutgoing")
        self.UserInfo_NotificationsDefault = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "UserInfo.NotificationsDefault")
        self.Weekday_ShortMonday = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Weekday.ShortMonday")
        self.Checkout_Receipt_Title = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Checkout.Receipt.Title")
        self.Channel_Edit_AboutItem = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.Edit.AboutItem")
        self.Login_InfoLastNamePlaceholder = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Login.InfoLastNamePlaceholder")
        self.Channel_Members_AddMembersHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.Members.AddMembersHelp")
        self._MESSAGE_VIDEO_SECRET = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "MESSAGE_VIDEO_SECRET")
        self._MESSAGE_VIDEO_SECRET_r = extractArgumentRanges(self._MESSAGE_VIDEO_SECRET)
        self.Settings_CopyPhoneNumber = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Settings.CopyPhoneNumber")
        self.ReportPeer_Report = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ReportPeer.Report")
        self.Channel_EditMessageErrorGeneric = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.EditMessageErrorGeneric")
        self.Passport_Identity_TranslationsHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Identity.TranslationsHelp")
        self.LoginPassword_FloodError = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "LoginPassword.FloodError")
        self.TwoStepAuth_SetupPasswordTitle = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "TwoStepAuth.SetupPasswordTitle")
        self.PhotoEditor_DiscardChanges = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PhotoEditor.DiscardChanges")
        self.Group_UpgradeNoticeText2 = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Group.UpgradeNoticeText2")
        self._PINNED_ROUND = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PINNED_ROUND")
        self._PINNED_ROUND_r = extractArgumentRanges(self._PINNED_ROUND)
        self._ChannelInfo_ChannelForbidden = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ChannelInfo.ChannelForbidden")
        self._ChannelInfo_ChannelForbidden_r = extractArgumentRanges(self._ChannelInfo_ChannelForbidden)
        self.Conversation_ShareMyContactInfo = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.ShareMyContactInfo")
        self.SocksProxySetup_UsernamePlaceholder = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "SocksProxySetup.UsernamePlaceholder")
        self._CHANNEL_MESSAGE_GEO = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "CHANNEL_MESSAGE_GEO")
        self._CHANNEL_MESSAGE_GEO_r = extractArgumentRanges(self._CHANNEL_MESSAGE_GEO)
        self.Contacts_PhoneNumber = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Contacts.PhoneNumber")
        self.Group_Info_AdminLog = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Group.Info.AdminLog")
        self.Channel_AdminLogFilter_ChannelEventsInfo = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.AdminLogFilter.ChannelEventsInfo")
        self.ChatSettings_AutoDownloadEnabled = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ChatSettings.AutoDownloadEnabled")
        self.StickerPacksSettings_FeaturedPacks = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "StickerPacksSettings.FeaturedPacks")
        self.AuthSessions_LoggedIn = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "AuthSessions.LoggedIn")
        self.Month_GenAugust = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Month.GenAugust")
        self.Notification_CallCanceled = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notification.CallCanceled")
        self.Channel_Username_CreatePublicLinkHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.Username.CreatePublicLinkHelp")
        self.StickerPack_Send = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "StickerPack.Send")
        self.StickerSettings_MaskContextInfo = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "StickerSettings.MaskContextInfo")
        self.Watch_Suggestion_HoldOn = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Watch.Suggestion.HoldOn")
        self._PINNED_GEO = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PINNED_GEO")
        self._PINNED_GEO_r = extractArgumentRanges(self._PINNED_GEO)
        self.PasscodeSettings_EncryptData = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PasscodeSettings.EncryptData")
        self.Common_NotNow = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Common.NotNow")
        self.FastTwoStepSetup_PasswordConfirmationPlaceholder = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "FastTwoStepSetup.PasswordConfirmationPlaceholder")
        self.PasscodeSettings_Title = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PasscodeSettings.Title")
        self.StickerPack_BuiltinPackName = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "StickerPack.BuiltinPackName")
        self.Appearance_AccentColor = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Appearance.AccentColor")
        self.Watch_Suggestion_BRB = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Watch.Suggestion.BRB")
        self._CHAT_MESSAGE_ROUND = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "CHAT_MESSAGE_ROUND")
        self._CHAT_MESSAGE_ROUND_r = extractArgumentRanges(self._CHAT_MESSAGE_ROUND)
        self.Notifications_MessageNotificationsAlert = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notifications.MessageNotificationsAlert")
        self.Username_InvalidCharacters = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Username.InvalidCharacters")
        self.GroupInfo_LabelAdmin = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "GroupInfo.LabelAdmin")
        self.GroupInfo_Sound = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "GroupInfo.Sound")
        self.Channel_EditAdmin_PermissionBanUsers = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.EditAdmin.PermissionBanUsers")
        self.InfoPlist_NSCameraUsageDescription = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "InfoPlist.NSCameraUsageDescription")
        self.Passport_Address_AddRentalAgreement = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Address.AddRentalAgreement")
        self.Wallpaper_PhotoLibrary = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Wallpaper.PhotoLibrary")
        self.Settings_About = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Settings.About")
        self.Privacy_Calls_IntegrationHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Privacy.Calls.IntegrationHelp")
        self.ContactInfo_Job = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ContactInfo.Job")
        self._CHAT_LEFT = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "CHAT_LEFT")
        self._CHAT_LEFT_r = extractArgumentRanges(self._CHAT_LEFT)
        self.LoginPassword_ForgotPassword = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "LoginPassword.ForgotPassword")
        self.Passport_Address_AddTemporaryRegistration = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Address.AddTemporaryRegistration")
        self._Map_LiveLocationShortHour = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Map.LiveLocationShortHour")
        self._Map_LiveLocationShortHour_r = extractArgumentRanges(self._Map_LiveLocationShortHour)
        self.Appearance_Preview = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Appearance.Preview")
        self._DialogList_AwaitingEncryption = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "DialogList.AwaitingEncryption")
        self._DialogList_AwaitingEncryption_r = extractArgumentRanges(self._DialogList_AwaitingEncryption)
        self.Passport_Identity_TypePassport = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Identity.TypePassport")
        self.ChatSettings_Appearance = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ChatSettings.Appearance")
        self.Tour_Title1 = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Tour.Title1")
        self.Conversation_EditingCaptionPanelTitle = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.EditingCaptionPanelTitle")
        self._Notifications_ExceptionsChangeSound = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notifications.ExceptionsChangeSound")
        self._Notifications_ExceptionsChangeSound_r = extractArgumentRanges(self._Notifications_ExceptionsChangeSound)
        self.Conversation_LinkDialogCopy = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.LinkDialogCopy")
        self._Notification_PinnedLocationMessage = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notification.PinnedLocationMessage")
        self._Notification_PinnedLocationMessage_r = extractArgumentRanges(self._Notification_PinnedLocationMessage)
        self._Notification_PinnedPhotoMessage = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notification.PinnedPhotoMessage")
        self._Notification_PinnedPhotoMessage_r = extractArgumentRanges(self._Notification_PinnedPhotoMessage)
        self._DownloadingStatus = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "DownloadingStatus")
        self._DownloadingStatus_r = extractArgumentRanges(self._DownloadingStatus)
        self.Calls_All = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Calls.All")
        self._Channel_MessageTitleUpdated = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.MessageTitleUpdated")
        self._Channel_MessageTitleUpdated_r = extractArgumentRanges(self._Channel_MessageTitleUpdated)
        self.Call_CallAgain = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Call.CallAgain")
        self.Message_VideoExpired = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Message.VideoExpired")
        self.TwoStepAuth_RecoveryCodeHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "TwoStepAuth.RecoveryCodeHelp")
        self._Channel_AdminLog_MessagePromotedNameUsername = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.AdminLog.MessagePromotedNameUsername")
        self._Channel_AdminLog_MessagePromotedNameUsername_r = extractArgumentRanges(self._Channel_AdminLog_MessagePromotedNameUsername)
        self.UserInfo_SendMessage = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "UserInfo.SendMessage")
        self._Channel_Username_LinkHint = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.Username.LinkHint")
        self._Channel_Username_LinkHint_r = extractArgumentRanges(self._Channel_Username_LinkHint)
        self._AutoDownloadSettings_UpTo = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "AutoDownloadSettings.UpTo")
        self._AutoDownloadSettings_UpTo_r = extractArgumentRanges(self._AutoDownloadSettings_UpTo)
        self.Settings_ViewPhoto = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Settings.ViewPhoto")
        self.Paint_RecentStickers = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Paint.RecentStickers")
        self._Passport_PrivacyPolicy = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.PrivacyPolicy")
        self._Passport_PrivacyPolicy_r = extractArgumentRanges(self._Passport_PrivacyPolicy)
        self.Login_CallRequestState3 = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Login.CallRequestState3")
        self.Channel_Edit_LinkItem = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.Edit.LinkItem")
        self.CallSettings_Title = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "CallSettings.Title")
        self.ChangePhoneNumberNumber_Help = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ChangePhoneNumberNumber.Help")
        self.Passport_InfoTitle = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.InfoTitle")
        self.Watch_Suggestion_Thanks = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Watch.Suggestion.Thanks")
        self.Channel_Moderator_Title = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.Moderator.Title")
        self.Message_PinnedPhotoMessage = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Message.PinnedPhotoMessage")
        self.Notification_SecretChatScreenshot = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notification.SecretChatScreenshot")
        self._Conversation_DeleteMessagesFor = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.DeleteMessagesFor")
        self._Conversation_DeleteMessagesFor_r = extractArgumentRanges(self._Conversation_DeleteMessagesFor)
        self.Activity_UploadingDocument = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Activity.UploadingDocument")
        self.Watch_ChatList_NoConversationsText = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Watch.ChatList.NoConversationsText")
        self.ReportPeer_AlertSuccess = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ReportPeer.AlertSuccess")
        self.Tour_Text4 = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Tour.Text4")
        self.Channel_Info_Description = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.Info.Description")
        self.AccessDenied_LocationTracking = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "AccessDenied.LocationTracking")
        self.Watch_Compose_Send = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Watch.Compose.Send")
        self.SocksProxySetup_UseForCallsHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "SocksProxySetup.UseForCallsHelp")
        self.Preview_CopyAddress = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Preview.CopyAddress")
        self.Settings_BlockedUsers = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Settings.BlockedUsers")
        self.Month_ShortAugust = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Month.ShortAugust")
        self.Passport_Identity_MainPage = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Identity.MainPage")
        self.Passport_FieldAddress = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.FieldAddress")
        self.Channel_AdminLogFilter_AdminsTitle = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.AdminLogFilter.AdminsTitle")
        self.Channel_EditAdmin_PermissionChangeInfo = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.EditAdmin.PermissionChangeInfo")
        self.Notifications_ResetAllNotificationsHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notifications.ResetAllNotificationsHelp")
        self.DialogList_EncryptionRejected = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "DialogList.EncryptionRejected")
        self.Target_InviteToGroupErrorAlreadyInvited = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Target.InviteToGroupErrorAlreadyInvited")
        self.AccessDenied_CameraRestricted = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "AccessDenied.CameraRestricted")
        self.Watch_Message_ForwardedFrom = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Watch.Message.ForwardedFrom")
        self.CheckoutInfo_ShippingInfoCountryPlaceholder = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "CheckoutInfo.ShippingInfoCountryPlaceholder")
        self.Channel_AboutItem = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.AboutItem")
        self.PhotoEditor_CurvesGreen = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PhotoEditor.CurvesGreen")
        self.Month_GenJuly = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Month.GenJuly")
        self.ContactInfo_URLLabelHomepage = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ContactInfo.URLLabelHomepage")
        self.PrivacyPolicy_DeclineDeclineAndDelete = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PrivacyPolicy.DeclineDeclineAndDelete")
        self._DialogList_SingleUploadingFileSuffix = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "DialogList.SingleUploadingFileSuffix")
        self._DialogList_SingleUploadingFileSuffix_r = extractArgumentRanges(self._DialogList_SingleUploadingFileSuffix)
        self.ChannelIntro_CreateChannel = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ChannelIntro.CreateChannel")
        self.Channel_Management_AddModerator = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.Management.AddModerator")
        self.Common_ChoosePhoto = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Common.ChoosePhoto")
        self.Conversation_Pin = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.Pin")
        self._Login_ResetAccountProtected_Text = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Login.ResetAccountProtected.Text")
        self._Login_ResetAccountProtected_Text_r = extractArgumentRanges(self._Login_ResetAccountProtected_Text)
        self._Channel_AdminLog_EmptyFilterQueryText = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.AdminLog.EmptyFilterQueryText")
        self._Channel_AdminLog_EmptyFilterQueryText_r = extractArgumentRanges(self._Channel_AdminLog_EmptyFilterQueryText)
        self.Camera_TapAndHoldForVideo = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Camera.TapAndHoldForVideo")
        self.Bot_DescriptionTitle = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Bot.DescriptionTitle")
        self.FeaturedStickerPacks_Title = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "FeaturedStickerPacks.Title")
        self.Map_OpenInGoogleMaps = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Map.OpenInGoogleMaps")
        self.Notification_MessageLifetime5s = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notification.MessageLifetime5s")
        self.Contacts_Title = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Contacts.Title")
        self._MESSAGES = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "MESSAGES")
        self._MESSAGES_r = extractArgumentRanges(self._MESSAGES)
        self.Channel_Management_AddModeratorHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.Management.AddModeratorHelp")
        self._CHAT_MESSAGE_FWDS = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "CHAT_MESSAGE_FWDS")
        self._CHAT_MESSAGE_FWDS_r = extractArgumentRanges(self._CHAT_MESSAGE_FWDS)
        self.Conversation_MessageDialogEdit = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.MessageDialogEdit")
        self.PrivacyLastSeenSettings_Title = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PrivacyLastSeenSettings.Title")
        self.Notifications_ClassicTones = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notifications.ClassicTones")
        self.Conversation_LinkDialogOpen = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.LinkDialogOpen")
        self.Channel_Info_Subscribers = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.Info.Subscribers")
        self.NotificationsSound_Input = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "NotificationsSound.Input")
        self.Conversation_ClousStorageInfo_Description4 = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.ClousStorageInfo.Description4")
        self.Privacy_Calls_AlwaysAllow = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Privacy.Calls.AlwaysAllow")
        self.Privacy_PaymentsClearInfoHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Privacy.PaymentsClearInfoHelp")
        self.Notification_MessageLifetime1h = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notification.MessageLifetime1h")
        self._Notification_CreatedChatWithTitle = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notification.CreatedChatWithTitle")
        self._Notification_CreatedChatWithTitle_r = extractArgumentRanges(self._Notification_CreatedChatWithTitle)
        self.CheckoutInfo_ReceiverInfoEmail = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "CheckoutInfo.ReceiverInfoEmail")
        self.LastSeen_Lately = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "LastSeen.Lately")
        self.Month_ShortApril = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Month.ShortApril")
        self.ConversationProfile_ErrorCreatingConversation = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ConversationProfile.ErrorCreatingConversation")
        self._PHONE_CALL_MISSED = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PHONE_CALL_MISSED")
        self._PHONE_CALL_MISSED_r = extractArgumentRanges(self._PHONE_CALL_MISSED)
        self._Conversation_Kilobytes = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.Kilobytes")
        self._Conversation_Kilobytes_r = extractArgumentRanges(self._Conversation_Kilobytes)
        self.Group_ErrorAddBlocked = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Group.ErrorAddBlocked")
        self.TwoStepAuth_AdditionalPassword = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "TwoStepAuth.AdditionalPassword")
        self.MediaPicker_Videos = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "MediaPicker.Videos")
        self.Notification_PassportValueProofOfIdentity = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notification.PassportValueProofOfIdentity")
        self.BlockedUsers_AddNew = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "BlockedUsers.AddNew")
        self.Notifications_DisplayNamesOnLockScreenInfo = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notifications.DisplayNamesOnLockScreenInfo")
        self.StickerPacksSettings_StickerPacksSection = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "StickerPacksSettings.StickerPacksSection")
        self.Channel_NotificationLoading = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.NotificationLoading")
        self.Passport_Language_da = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Language.da")
        self.Passport_Address_Country = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Address.Country")
        self._CHAT_RETURNED = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "CHAT_RETURNED")
        self._CHAT_RETURNED_r = extractArgumentRanges(self._CHAT_RETURNED)
        self.PhotoEditor_ShadowsTint = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PhotoEditor.ShadowsTint")
        self.ExplicitContent_AlertTitle = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ExplicitContent.AlertTitle")
        self.Channel_AdminLogFilter_EventsLeaving = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Channel.AdminLogFilter.EventsLeaving")
        self.Map_LiveLocationFor8Hours = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Map.LiveLocationFor8Hours")
        self.StickerPack_HideStickers = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "StickerPack.HideStickers")
        self.Checkout_EnterPassword = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Checkout.EnterPassword")
        self.UserInfo_NotificationsEnabled = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "UserInfo.NotificationsEnabled")
        self.InfoPlist_NSLocationAlwaysUsageDescription = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "InfoPlist.NSLocationAlwaysUsageDescription")
        self.SocksProxySetup_ProxyDetailsTitle = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "SocksProxySetup.ProxyDetailsTitle")
        self.Appearance_ReduceMotionInfo = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Appearance.ReduceMotionInfo")
        self.Weekday_ShortTuesday = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Weekday.ShortTuesday")
        self.Notification_CallIncomingShort = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notification.CallIncomingShort")
        self.ConvertToSupergroup_Note = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "ConvertToSupergroup.Note")
        self.DialogList_Read = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "DialogList.Read")
        self.Conversation_EmptyPlaceholder = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.EmptyPlaceholder")
        self._Passport_Email_CodeHelp = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Email.CodeHelp")
        self._Passport_Email_CodeHelp_r = extractArgumentRanges(self._Passport_Email_CodeHelp)
        self.Username_Help = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Username.Help")
        self.StickerSettings_ContextHide = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "StickerSettings.ContextHide")
        self.Media_ShareThisPhoto = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Media.ShareThisPhoto")
        self.Contacts_ShareTelegram = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Contacts.ShareTelegram")
        self.AutoNightTheme_Scheduled = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "AutoNightTheme.Scheduled")
        self.Weekday_Sunday = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Weekday.Sunday")
        self.PrivacySettings_PasscodeAndFaceId = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "PrivacySettings.PasscodeAndFaceId")
        self.Settings_ChatBackground = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Settings.ChatBackground")
        self.Login_TermsOfServiceDecline = getValue(self.primaryComponent.dict, self.secondaryComponent?.dict, "Login.TermsOfServiceDecline")
    self._ForwardedAudios_zero = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "ForwardedAudios", .zero)
    self._ForwardedAudios_one = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "ForwardedAudios", .one)
    self._ForwardedAudios_two = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "ForwardedAudios", .two)
    self._ForwardedAudios_few = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "ForwardedAudios", .few)
    self._ForwardedAudios_many = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "ForwardedAudios", .many)
    self._ForwardedAudios_other = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "ForwardedAudios", .other)
    self._Conversation_StatusMembers_zero = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.StatusMembers", .zero)
    self._Conversation_StatusMembers_one = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.StatusMembers", .one)
    self._Conversation_StatusMembers_two = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.StatusMembers", .two)
    self._Conversation_StatusMembers_few = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.StatusMembers", .few)
    self._Conversation_StatusMembers_many = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.StatusMembers", .many)
    self._Conversation_StatusMembers_other = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.StatusMembers", .other)
    self._AttachmentMenu_SendPhoto_zero = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "AttachmentMenu.SendPhoto", .zero)
    self._AttachmentMenu_SendPhoto_one = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "AttachmentMenu.SendPhoto", .one)
    self._AttachmentMenu_SendPhoto_two = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "AttachmentMenu.SendPhoto", .two)
    self._AttachmentMenu_SendPhoto_few = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "AttachmentMenu.SendPhoto", .few)
    self._AttachmentMenu_SendPhoto_many = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "AttachmentMenu.SendPhoto", .many)
    self._AttachmentMenu_SendPhoto_other = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "AttachmentMenu.SendPhoto", .other)
    self._ForwardedMessages_zero = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "ForwardedMessages", .zero)
    self._ForwardedMessages_one = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "ForwardedMessages", .one)
    self._ForwardedMessages_two = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "ForwardedMessages", .two)
    self._ForwardedMessages_few = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "ForwardedMessages", .few)
    self._ForwardedMessages_many = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "ForwardedMessages", .many)
    self._ForwardedMessages_other = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "ForwardedMessages", .other)
    self._MessageTimer_ShortSeconds_zero = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MessageTimer.ShortSeconds", .zero)
    self._MessageTimer_ShortSeconds_one = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MessageTimer.ShortSeconds", .one)
    self._MessageTimer_ShortSeconds_two = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MessageTimer.ShortSeconds", .two)
    self._MessageTimer_ShortSeconds_few = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MessageTimer.ShortSeconds", .few)
    self._MessageTimer_ShortSeconds_many = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MessageTimer.ShortSeconds", .many)
    self._MessageTimer_ShortSeconds_other = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MessageTimer.ShortSeconds", .other)
    self._ForwardedPhotos_zero = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "ForwardedPhotos", .zero)
    self._ForwardedPhotos_one = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "ForwardedPhotos", .one)
    self._ForwardedPhotos_two = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "ForwardedPhotos", .two)
    self._ForwardedPhotos_few = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "ForwardedPhotos", .few)
    self._ForwardedPhotos_many = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "ForwardedPhotos", .many)
    self._ForwardedPhotos_other = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "ForwardedPhotos", .other)
    self._Notifications_ExceptionMuteExpires_Hours_zero = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notifications.ExceptionMuteExpires.Hours", .zero)
    self._Notifications_ExceptionMuteExpires_Hours_one = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notifications.ExceptionMuteExpires.Hours", .one)
    self._Notifications_ExceptionMuteExpires_Hours_two = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notifications.ExceptionMuteExpires.Hours", .two)
    self._Notifications_ExceptionMuteExpires_Hours_few = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notifications.ExceptionMuteExpires.Hours", .few)
    self._Notifications_ExceptionMuteExpires_Hours_many = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notifications.ExceptionMuteExpires.Hours", .many)
    self._Notifications_ExceptionMuteExpires_Hours_other = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notifications.ExceptionMuteExpires.Hours", .other)
    self._Call_Minutes_zero = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Call.Minutes", .zero)
    self._Call_Minutes_one = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Call.Minutes", .one)
    self._Call_Minutes_two = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Call.Minutes", .two)
    self._Call_Minutes_few = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Call.Minutes", .few)
    self._Call_Minutes_many = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Call.Minutes", .many)
    self._Call_Minutes_other = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Call.Minutes", .other)
    self._SharedMedia_Video_zero = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "SharedMedia.Video", .zero)
    self._SharedMedia_Video_one = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "SharedMedia.Video", .one)
    self._SharedMedia_Video_two = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "SharedMedia.Video", .two)
    self._SharedMedia_Video_few = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "SharedMedia.Video", .few)
    self._SharedMedia_Video_many = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "SharedMedia.Video", .many)
    self._SharedMedia_Video_other = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "SharedMedia.Video", .other)
    self._MessageTimer_Minutes_zero = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MessageTimer.Minutes", .zero)
    self._MessageTimer_Minutes_one = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MessageTimer.Minutes", .one)
    self._MessageTimer_Minutes_two = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MessageTimer.Minutes", .two)
    self._MessageTimer_Minutes_few = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MessageTimer.Minutes", .few)
    self._MessageTimer_Minutes_many = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MessageTimer.Minutes", .many)
    self._MessageTimer_Minutes_other = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MessageTimer.Minutes", .other)
    self._MessageTimer_Days_zero = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MessageTimer.Days", .zero)
    self._MessageTimer_Days_one = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MessageTimer.Days", .one)
    self._MessageTimer_Days_two = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MessageTimer.Days", .two)
    self._MessageTimer_Days_few = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MessageTimer.Days", .few)
    self._MessageTimer_Days_many = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MessageTimer.Days", .many)
    self._MessageTimer_Days_other = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MessageTimer.Days", .other)
    self._Media_ShareItem_zero = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Media.ShareItem", .zero)
    self._Media_ShareItem_one = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Media.ShareItem", .one)
    self._Media_ShareItem_two = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Media.ShareItem", .two)
    self._Media_ShareItem_few = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Media.ShareItem", .few)
    self._Media_ShareItem_many = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Media.ShareItem", .many)
    self._Media_ShareItem_other = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Media.ShareItem", .other)
    self._Call_Seconds_zero = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Call.Seconds", .zero)
    self._Call_Seconds_one = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Call.Seconds", .one)
    self._Call_Seconds_two = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Call.Seconds", .two)
    self._Call_Seconds_few = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Call.Seconds", .few)
    self._Call_Seconds_many = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Call.Seconds", .many)
    self._Call_Seconds_other = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Call.Seconds", .other)
    self._StickerPack_AddStickerCount_zero = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "StickerPack.AddStickerCount", .zero)
    self._StickerPack_AddStickerCount_one = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "StickerPack.AddStickerCount", .one)
    self._StickerPack_AddStickerCount_two = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "StickerPack.AddStickerCount", .two)
    self._StickerPack_AddStickerCount_few = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "StickerPack.AddStickerCount", .few)
    self._StickerPack_AddStickerCount_many = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "StickerPack.AddStickerCount", .many)
    self._StickerPack_AddStickerCount_other = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "StickerPack.AddStickerCount", .other)
    self._StickerPack_AddMaskCount_zero = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "StickerPack.AddMaskCount", .zero)
    self._StickerPack_AddMaskCount_one = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "StickerPack.AddMaskCount", .one)
    self._StickerPack_AddMaskCount_two = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "StickerPack.AddMaskCount", .two)
    self._StickerPack_AddMaskCount_few = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "StickerPack.AddMaskCount", .few)
    self._StickerPack_AddMaskCount_many = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "StickerPack.AddMaskCount", .many)
    self._StickerPack_AddMaskCount_other = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "StickerPack.AddMaskCount", .other)
    self._LastSeen_MinutesAgo_zero = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "LastSeen.MinutesAgo", .zero)
    self._LastSeen_MinutesAgo_one = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "LastSeen.MinutesAgo", .one)
    self._LastSeen_MinutesAgo_two = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "LastSeen.MinutesAgo", .two)
    self._LastSeen_MinutesAgo_few = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "LastSeen.MinutesAgo", .few)
    self._LastSeen_MinutesAgo_many = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "LastSeen.MinutesAgo", .many)
    self._LastSeen_MinutesAgo_other = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "LastSeen.MinutesAgo", .other)
    self._Contacts_ImportersCount_zero = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Contacts.ImportersCount", .zero)
    self._Contacts_ImportersCount_one = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Contacts.ImportersCount", .one)
    self._Contacts_ImportersCount_two = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Contacts.ImportersCount", .two)
    self._Contacts_ImportersCount_few = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Contacts.ImportersCount", .few)
    self._Contacts_ImportersCount_many = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Contacts.ImportersCount", .many)
    self._Contacts_ImportersCount_other = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Contacts.ImportersCount", .other)
    self._ServiceMessage_GameScoreSelfExtended_zero = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "ServiceMessage.GameScoreSelfExtended", .zero)
    self._ServiceMessage_GameScoreSelfExtended_one = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "ServiceMessage.GameScoreSelfExtended", .one)
    self._ServiceMessage_GameScoreSelfExtended_two = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "ServiceMessage.GameScoreSelfExtended", .two)
    self._ServiceMessage_GameScoreSelfExtended_few = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "ServiceMessage.GameScoreSelfExtended", .few)
    self._ServiceMessage_GameScoreSelfExtended_many = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "ServiceMessage.GameScoreSelfExtended", .many)
    self._ServiceMessage_GameScoreSelfExtended_other = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "ServiceMessage.GameScoreSelfExtended", .other)
    self._AttachmentMenu_SendGif_zero = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "AttachmentMenu.SendGif", .zero)
    self._AttachmentMenu_SendGif_one = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "AttachmentMenu.SendGif", .one)
    self._AttachmentMenu_SendGif_two = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "AttachmentMenu.SendGif", .two)
    self._AttachmentMenu_SendGif_few = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "AttachmentMenu.SendGif", .few)
    self._AttachmentMenu_SendGif_many = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "AttachmentMenu.SendGif", .many)
    self._AttachmentMenu_SendGif_other = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "AttachmentMenu.SendGif", .other)
    self._MessageTimer_ShortWeeks_zero = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MessageTimer.ShortWeeks", .zero)
    self._MessageTimer_ShortWeeks_one = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MessageTimer.ShortWeeks", .one)
    self._MessageTimer_ShortWeeks_two = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MessageTimer.ShortWeeks", .two)
    self._MessageTimer_ShortWeeks_few = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MessageTimer.ShortWeeks", .few)
    self._MessageTimer_ShortWeeks_many = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MessageTimer.ShortWeeks", .many)
    self._MessageTimer_ShortWeeks_other = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MessageTimer.ShortWeeks", .other)
    self._LiveLocationUpdated_MinutesAgo_zero = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "LiveLocationUpdated.MinutesAgo", .zero)
    self._LiveLocationUpdated_MinutesAgo_one = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "LiveLocationUpdated.MinutesAgo", .one)
    self._LiveLocationUpdated_MinutesAgo_two = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "LiveLocationUpdated.MinutesAgo", .two)
    self._LiveLocationUpdated_MinutesAgo_few = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "LiveLocationUpdated.MinutesAgo", .few)
    self._LiveLocationUpdated_MinutesAgo_many = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "LiveLocationUpdated.MinutesAgo", .many)
    self._LiveLocationUpdated_MinutesAgo_other = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "LiveLocationUpdated.MinutesAgo", .other)
    self._Media_SharePhoto_zero = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Media.SharePhoto", .zero)
    self._Media_SharePhoto_one = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Media.SharePhoto", .one)
    self._Media_SharePhoto_two = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Media.SharePhoto", .two)
    self._Media_SharePhoto_few = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Media.SharePhoto", .few)
    self._Media_SharePhoto_many = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Media.SharePhoto", .many)
    self._Media_SharePhoto_other = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Media.SharePhoto", .other)
    self._Invitation_Members_zero = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Invitation.Members", .zero)
    self._Invitation_Members_one = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Invitation.Members", .one)
    self._Invitation_Members_two = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Invitation.Members", .two)
    self._Invitation_Members_few = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Invitation.Members", .few)
    self._Invitation_Members_many = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Invitation.Members", .many)
    self._Invitation_Members_other = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Invitation.Members", .other)
    self._Notification_GameScoreSelfExtended_zero = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notification.GameScoreSelfExtended", .zero)
    self._Notification_GameScoreSelfExtended_one = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notification.GameScoreSelfExtended", .one)
    self._Notification_GameScoreSelfExtended_two = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notification.GameScoreSelfExtended", .two)
    self._Notification_GameScoreSelfExtended_few = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notification.GameScoreSelfExtended", .few)
    self._Notification_GameScoreSelfExtended_many = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notification.GameScoreSelfExtended", .many)
    self._Notification_GameScoreSelfExtended_other = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notification.GameScoreSelfExtended", .other)
    self._MessageTimer_Seconds_zero = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MessageTimer.Seconds", .zero)
    self._MessageTimer_Seconds_one = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MessageTimer.Seconds", .one)
    self._MessageTimer_Seconds_two = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MessageTimer.Seconds", .two)
    self._MessageTimer_Seconds_few = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MessageTimer.Seconds", .few)
    self._MessageTimer_Seconds_many = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MessageTimer.Seconds", .many)
    self._MessageTimer_Seconds_other = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MessageTimer.Seconds", .other)
    self._MuteExpires_Hours_zero = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MuteExpires.Hours", .zero)
    self._MuteExpires_Hours_one = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MuteExpires.Hours", .one)
    self._MuteExpires_Hours_two = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MuteExpires.Hours", .two)
    self._MuteExpires_Hours_few = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MuteExpires.Hours", .few)
    self._MuteExpires_Hours_many = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MuteExpires.Hours", .many)
    self._MuteExpires_Hours_other = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MuteExpires.Hours", .other)
    self._AttachmentMenu_SendVideo_zero = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "AttachmentMenu.SendVideo", .zero)
    self._AttachmentMenu_SendVideo_one = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "AttachmentMenu.SendVideo", .one)
    self._AttachmentMenu_SendVideo_two = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "AttachmentMenu.SendVideo", .two)
    self._AttachmentMenu_SendVideo_few = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "AttachmentMenu.SendVideo", .few)
    self._AttachmentMenu_SendVideo_many = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "AttachmentMenu.SendVideo", .many)
    self._AttachmentMenu_SendVideo_other = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "AttachmentMenu.SendVideo", .other)
    self._MessageTimer_Hours_zero = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MessageTimer.Hours", .zero)
    self._MessageTimer_Hours_one = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MessageTimer.Hours", .one)
    self._MessageTimer_Hours_two = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MessageTimer.Hours", .two)
    self._MessageTimer_Hours_few = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MessageTimer.Hours", .few)
    self._MessageTimer_Hours_many = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MessageTimer.Hours", .many)
    self._MessageTimer_Hours_other = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MessageTimer.Hours", .other)
    self._Watch_UserInfo_Mute_zero = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Watch.UserInfo.Mute", .zero)
    self._Watch_UserInfo_Mute_one = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Watch.UserInfo.Mute", .one)
    self._Watch_UserInfo_Mute_two = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Watch.UserInfo.Mute", .two)
    self._Watch_UserInfo_Mute_few = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Watch.UserInfo.Mute", .few)
    self._Watch_UserInfo_Mute_many = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Watch.UserInfo.Mute", .many)
    self._Watch_UserInfo_Mute_other = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Watch.UserInfo.Mute", .other)
    self._ServiceMessage_GameScoreSelfSimple_zero = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "ServiceMessage.GameScoreSelfSimple", .zero)
    self._ServiceMessage_GameScoreSelfSimple_one = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "ServiceMessage.GameScoreSelfSimple", .one)
    self._ServiceMessage_GameScoreSelfSimple_two = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "ServiceMessage.GameScoreSelfSimple", .two)
    self._ServiceMessage_GameScoreSelfSimple_few = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "ServiceMessage.GameScoreSelfSimple", .few)
    self._ServiceMessage_GameScoreSelfSimple_many = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "ServiceMessage.GameScoreSelfSimple", .many)
    self._ServiceMessage_GameScoreSelfSimple_other = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "ServiceMessage.GameScoreSelfSimple", .other)
    self._ForwardedGifs_zero = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "ForwardedGifs", .zero)
    self._ForwardedGifs_one = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "ForwardedGifs", .one)
    self._ForwardedGifs_two = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "ForwardedGifs", .two)
    self._ForwardedGifs_few = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "ForwardedGifs", .few)
    self._ForwardedGifs_many = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "ForwardedGifs", .many)
    self._ForwardedGifs_other = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "ForwardedGifs", .other)
    self._MessageTimer_ShortDays_zero = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MessageTimer.ShortDays", .zero)
    self._MessageTimer_ShortDays_one = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MessageTimer.ShortDays", .one)
    self._MessageTimer_ShortDays_two = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MessageTimer.ShortDays", .two)
    self._MessageTimer_ShortDays_few = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MessageTimer.ShortDays", .few)
    self._MessageTimer_ShortDays_many = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MessageTimer.ShortDays", .many)
    self._MessageTimer_ShortDays_other = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MessageTimer.ShortDays", .other)
    self._ForwardedStickers_zero = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "ForwardedStickers", .zero)
    self._ForwardedStickers_one = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "ForwardedStickers", .one)
    self._ForwardedStickers_two = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "ForwardedStickers", .two)
    self._ForwardedStickers_few = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "ForwardedStickers", .few)
    self._ForwardedStickers_many = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "ForwardedStickers", .many)
    self._ForwardedStickers_other = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "ForwardedStickers", .other)
    self._StickerPack_RemoveStickerCount_zero = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "StickerPack.RemoveStickerCount", .zero)
    self._StickerPack_RemoveStickerCount_one = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "StickerPack.RemoveStickerCount", .one)
    self._StickerPack_RemoveStickerCount_two = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "StickerPack.RemoveStickerCount", .two)
    self._StickerPack_RemoveStickerCount_few = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "StickerPack.RemoveStickerCount", .few)
    self._StickerPack_RemoveStickerCount_many = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "StickerPack.RemoveStickerCount", .many)
    self._StickerPack_RemoveStickerCount_other = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "StickerPack.RemoveStickerCount", .other)
    self._MuteExpires_Minutes_zero = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MuteExpires.Minutes", .zero)
    self._MuteExpires_Minutes_one = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MuteExpires.Minutes", .one)
    self._MuteExpires_Minutes_two = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MuteExpires.Minutes", .two)
    self._MuteExpires_Minutes_few = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MuteExpires.Minutes", .few)
    self._MuteExpires_Minutes_many = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MuteExpires.Minutes", .many)
    self._MuteExpires_Minutes_other = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MuteExpires.Minutes", .other)
    self._AttachmentMenu_SendItem_zero = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "AttachmentMenu.SendItem", .zero)
    self._AttachmentMenu_SendItem_one = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "AttachmentMenu.SendItem", .one)
    self._AttachmentMenu_SendItem_two = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "AttachmentMenu.SendItem", .two)
    self._AttachmentMenu_SendItem_few = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "AttachmentMenu.SendItem", .few)
    self._AttachmentMenu_SendItem_many = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "AttachmentMenu.SendItem", .many)
    self._AttachmentMenu_SendItem_other = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "AttachmentMenu.SendItem", .other)
    self._MuteExpires_Days_zero = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MuteExpires.Days", .zero)
    self._MuteExpires_Days_one = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MuteExpires.Days", .one)
    self._MuteExpires_Days_two = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MuteExpires.Days", .two)
    self._MuteExpires_Days_few = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MuteExpires.Days", .few)
    self._MuteExpires_Days_many = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MuteExpires.Days", .many)
    self._MuteExpires_Days_other = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MuteExpires.Days", .other)
    self._StickerPack_RemoveMaskCount_zero = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "StickerPack.RemoveMaskCount", .zero)
    self._StickerPack_RemoveMaskCount_one = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "StickerPack.RemoveMaskCount", .one)
    self._StickerPack_RemoveMaskCount_two = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "StickerPack.RemoveMaskCount", .two)
    self._StickerPack_RemoveMaskCount_few = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "StickerPack.RemoveMaskCount", .few)
    self._StickerPack_RemoveMaskCount_many = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "StickerPack.RemoveMaskCount", .many)
    self._StickerPack_RemoveMaskCount_other = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "StickerPack.RemoveMaskCount", .other)
    self._Watch_LastSeen_MinutesAgo_zero = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Watch.LastSeen.MinutesAgo", .zero)
    self._Watch_LastSeen_MinutesAgo_one = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Watch.LastSeen.MinutesAgo", .one)
    self._Watch_LastSeen_MinutesAgo_two = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Watch.LastSeen.MinutesAgo", .two)
    self._Watch_LastSeen_MinutesAgo_few = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Watch.LastSeen.MinutesAgo", .few)
    self._Watch_LastSeen_MinutesAgo_many = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Watch.LastSeen.MinutesAgo", .many)
    self._Watch_LastSeen_MinutesAgo_other = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Watch.LastSeen.MinutesAgo", .other)
    self._Notification_GameScoreSelfSimple_zero = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notification.GameScoreSelfSimple", .zero)
    self._Notification_GameScoreSelfSimple_one = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notification.GameScoreSelfSimple", .one)
    self._Notification_GameScoreSelfSimple_two = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notification.GameScoreSelfSimple", .two)
    self._Notification_GameScoreSelfSimple_few = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notification.GameScoreSelfSimple", .few)
    self._Notification_GameScoreSelfSimple_many = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notification.GameScoreSelfSimple", .many)
    self._Notification_GameScoreSelfSimple_other = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notification.GameScoreSelfSimple", .other)
    self._SharedMedia_File_zero = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "SharedMedia.File", .zero)
    self._SharedMedia_File_one = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "SharedMedia.File", .one)
    self._SharedMedia_File_two = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "SharedMedia.File", .two)
    self._SharedMedia_File_few = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "SharedMedia.File", .few)
    self._SharedMedia_File_many = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "SharedMedia.File", .many)
    self._SharedMedia_File_other = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "SharedMedia.File", .other)
    self._Conversation_StatusOnline_zero = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.StatusOnline", .zero)
    self._Conversation_StatusOnline_one = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.StatusOnline", .one)
    self._Conversation_StatusOnline_two = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.StatusOnline", .two)
    self._Conversation_StatusOnline_few = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.StatusOnline", .few)
    self._Conversation_StatusOnline_many = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.StatusOnline", .many)
    self._Conversation_StatusOnline_other = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.StatusOnline", .other)
    self._ForwardedVideoMessages_zero = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "ForwardedVideoMessages", .zero)
    self._ForwardedVideoMessages_one = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "ForwardedVideoMessages", .one)
    self._ForwardedVideoMessages_two = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "ForwardedVideoMessages", .two)
    self._ForwardedVideoMessages_few = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "ForwardedVideoMessages", .few)
    self._ForwardedVideoMessages_many = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "ForwardedVideoMessages", .many)
    self._ForwardedVideoMessages_other = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "ForwardedVideoMessages", .other)
    self._MuteFor_Hours_zero = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MuteFor.Hours", .zero)
    self._MuteFor_Hours_one = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MuteFor.Hours", .one)
    self._MuteFor_Hours_two = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MuteFor.Hours", .two)
    self._MuteFor_Hours_few = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MuteFor.Hours", .few)
    self._MuteFor_Hours_many = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MuteFor.Hours", .many)
    self._MuteFor_Hours_other = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MuteFor.Hours", .other)
    self._ForwardedContacts_zero = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "ForwardedContacts", .zero)
    self._ForwardedContacts_one = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "ForwardedContacts", .one)
    self._ForwardedContacts_two = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "ForwardedContacts", .two)
    self._ForwardedContacts_few = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "ForwardedContacts", .few)
    self._ForwardedContacts_many = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "ForwardedContacts", .many)
    self._ForwardedContacts_other = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "ForwardedContacts", .other)
    self._GroupInfo_ParticipantCount_zero = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "GroupInfo.ParticipantCount", .zero)
    self._GroupInfo_ParticipantCount_one = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "GroupInfo.ParticipantCount", .one)
    self._GroupInfo_ParticipantCount_two = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "GroupInfo.ParticipantCount", .two)
    self._GroupInfo_ParticipantCount_few = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "GroupInfo.ParticipantCount", .few)
    self._GroupInfo_ParticipantCount_many = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "GroupInfo.ParticipantCount", .many)
    self._GroupInfo_ParticipantCount_other = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "GroupInfo.ParticipantCount", .other)
    self._LastSeen_HoursAgo_zero = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "LastSeen.HoursAgo", .zero)
    self._LastSeen_HoursAgo_one = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "LastSeen.HoursAgo", .one)
    self._LastSeen_HoursAgo_two = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "LastSeen.HoursAgo", .two)
    self._LastSeen_HoursAgo_few = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "LastSeen.HoursAgo", .few)
    self._LastSeen_HoursAgo_many = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "LastSeen.HoursAgo", .many)
    self._LastSeen_HoursAgo_other = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "LastSeen.HoursAgo", .other)
    self._SharedMedia_Link_zero = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "SharedMedia.Link", .zero)
    self._SharedMedia_Link_one = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "SharedMedia.Link", .one)
    self._SharedMedia_Link_two = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "SharedMedia.Link", .two)
    self._SharedMedia_Link_few = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "SharedMedia.Link", .few)
    self._SharedMedia_Link_many = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "SharedMedia.Link", .many)
    self._SharedMedia_Link_other = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "SharedMedia.Link", .other)
    self._ServiceMessage_GameScoreExtended_zero = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "ServiceMessage.GameScoreExtended", .zero)
    self._ServiceMessage_GameScoreExtended_one = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "ServiceMessage.GameScoreExtended", .one)
    self._ServiceMessage_GameScoreExtended_two = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "ServiceMessage.GameScoreExtended", .two)
    self._ServiceMessage_GameScoreExtended_few = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "ServiceMessage.GameScoreExtended", .few)
    self._ServiceMessage_GameScoreExtended_many = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "ServiceMessage.GameScoreExtended", .many)
    self._ServiceMessage_GameScoreExtended_other = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "ServiceMessage.GameScoreExtended", .other)
    self._Map_ETAMinutes_zero = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Map.ETAMinutes", .zero)
    self._Map_ETAMinutes_one = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Map.ETAMinutes", .one)
    self._Map_ETAMinutes_two = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Map.ETAMinutes", .two)
    self._Map_ETAMinutes_few = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Map.ETAMinutes", .few)
    self._Map_ETAMinutes_many = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Map.ETAMinutes", .many)
    self._Map_ETAMinutes_other = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Map.ETAMinutes", .other)
    self._MessageTimer_Months_zero = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MessageTimer.Months", .zero)
    self._MessageTimer_Months_one = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MessageTimer.Months", .one)
    self._MessageTimer_Months_two = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MessageTimer.Months", .two)
    self._MessageTimer_Months_few = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MessageTimer.Months", .few)
    self._MessageTimer_Months_many = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MessageTimer.Months", .many)
    self._MessageTimer_Months_other = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MessageTimer.Months", .other)
    self._UserCount_zero = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "UserCount", .zero)
    self._UserCount_one = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "UserCount", .one)
    self._UserCount_two = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "UserCount", .two)
    self._UserCount_few = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "UserCount", .few)
    self._UserCount_many = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "UserCount", .many)
    self._UserCount_other = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "UserCount", .other)
    self._Watch_LastSeen_HoursAgo_zero = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Watch.LastSeen.HoursAgo", .zero)
    self._Watch_LastSeen_HoursAgo_one = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Watch.LastSeen.HoursAgo", .one)
    self._Watch_LastSeen_HoursAgo_two = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Watch.LastSeen.HoursAgo", .two)
    self._Watch_LastSeen_HoursAgo_few = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Watch.LastSeen.HoursAgo", .few)
    self._Watch_LastSeen_HoursAgo_many = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Watch.LastSeen.HoursAgo", .many)
    self._Watch_LastSeen_HoursAgo_other = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Watch.LastSeen.HoursAgo", .other)
    self._StickerPack_StickerCount_zero = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "StickerPack.StickerCount", .zero)
    self._StickerPack_StickerCount_one = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "StickerPack.StickerCount", .one)
    self._StickerPack_StickerCount_two = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "StickerPack.StickerCount", .two)
    self._StickerPack_StickerCount_few = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "StickerPack.StickerCount", .few)
    self._StickerPack_StickerCount_many = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "StickerPack.StickerCount", .many)
    self._StickerPack_StickerCount_other = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "StickerPack.StickerCount", .other)
    self._Conversation_StatusSubscribers_zero = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.StatusSubscribers", .zero)
    self._Conversation_StatusSubscribers_one = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.StatusSubscribers", .one)
    self._Conversation_StatusSubscribers_two = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.StatusSubscribers", .two)
    self._Conversation_StatusSubscribers_few = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.StatusSubscribers", .few)
    self._Conversation_StatusSubscribers_many = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.StatusSubscribers", .many)
    self._Conversation_StatusSubscribers_other = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.StatusSubscribers", .other)
    self._PrivacyLastSeenSettings_AddUsers_zero = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "PrivacyLastSeenSettings.AddUsers", .zero)
    self._PrivacyLastSeenSettings_AddUsers_one = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "PrivacyLastSeenSettings.AddUsers", .one)
    self._PrivacyLastSeenSettings_AddUsers_two = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "PrivacyLastSeenSettings.AddUsers", .two)
    self._PrivacyLastSeenSettings_AddUsers_few = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "PrivacyLastSeenSettings.AddUsers", .few)
    self._PrivacyLastSeenSettings_AddUsers_many = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "PrivacyLastSeenSettings.AddUsers", .many)
    self._PrivacyLastSeenSettings_AddUsers_other = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "PrivacyLastSeenSettings.AddUsers", .other)
    self._Notification_GameScoreExtended_zero = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notification.GameScoreExtended", .zero)
    self._Notification_GameScoreExtended_one = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notification.GameScoreExtended", .one)
    self._Notification_GameScoreExtended_two = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notification.GameScoreExtended", .two)
    self._Notification_GameScoreExtended_few = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notification.GameScoreExtended", .few)
    self._Notification_GameScoreExtended_many = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notification.GameScoreExtended", .many)
    self._Notification_GameScoreExtended_other = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notification.GameScoreExtended", .other)
    self._Map_ETAHours_zero = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Map.ETAHours", .zero)
    self._Map_ETAHours_one = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Map.ETAHours", .one)
    self._Map_ETAHours_two = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Map.ETAHours", .two)
    self._Map_ETAHours_few = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Map.ETAHours", .few)
    self._Map_ETAHours_many = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Map.ETAHours", .many)
    self._Map_ETAHours_other = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Map.ETAHours", .other)
    self._Notifications_ExceptionMuteExpires_Minutes_zero = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notifications.ExceptionMuteExpires.Minutes", .zero)
    self._Notifications_ExceptionMuteExpires_Minutes_one = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notifications.ExceptionMuteExpires.Minutes", .one)
    self._Notifications_ExceptionMuteExpires_Minutes_two = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notifications.ExceptionMuteExpires.Minutes", .two)
    self._Notifications_ExceptionMuteExpires_Minutes_few = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notifications.ExceptionMuteExpires.Minutes", .few)
    self._Notifications_ExceptionMuteExpires_Minutes_many = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notifications.ExceptionMuteExpires.Minutes", .many)
    self._Notifications_ExceptionMuteExpires_Minutes_other = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notifications.ExceptionMuteExpires.Minutes", .other)
    self._SharedMedia_Photo_zero = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "SharedMedia.Photo", .zero)
    self._SharedMedia_Photo_one = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "SharedMedia.Photo", .one)
    self._SharedMedia_Photo_two = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "SharedMedia.Photo", .two)
    self._SharedMedia_Photo_few = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "SharedMedia.Photo", .few)
    self._SharedMedia_Photo_many = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "SharedMedia.Photo", .many)
    self._SharedMedia_Photo_other = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "SharedMedia.Photo", .other)
    self._ForwardedVideos_zero = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "ForwardedVideos", .zero)
    self._ForwardedVideos_one = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "ForwardedVideos", .one)
    self._ForwardedVideos_two = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "ForwardedVideos", .two)
    self._ForwardedVideos_few = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "ForwardedVideos", .few)
    self._ForwardedVideos_many = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "ForwardedVideos", .many)
    self._ForwardedVideos_other = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "ForwardedVideos", .other)
    self._LiveLocation_MenuChatsCount_zero = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "LiveLocation.MenuChatsCount", .zero)
    self._LiveLocation_MenuChatsCount_one = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "LiveLocation.MenuChatsCount", .one)
    self._LiveLocation_MenuChatsCount_two = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "LiveLocation.MenuChatsCount", .two)
    self._LiveLocation_MenuChatsCount_few = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "LiveLocation.MenuChatsCount", .few)
    self._LiveLocation_MenuChatsCount_many = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "LiveLocation.MenuChatsCount", .many)
    self._LiveLocation_MenuChatsCount_other = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "LiveLocation.MenuChatsCount", .other)
    self._PasscodeSettings_FailedAttempts_zero = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "PasscodeSettings.FailedAttempts", .zero)
    self._PasscodeSettings_FailedAttempts_one = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "PasscodeSettings.FailedAttempts", .one)
    self._PasscodeSettings_FailedAttempts_two = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "PasscodeSettings.FailedAttempts", .two)
    self._PasscodeSettings_FailedAttempts_few = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "PasscodeSettings.FailedAttempts", .few)
    self._PasscodeSettings_FailedAttempts_many = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "PasscodeSettings.FailedAttempts", .many)
    self._PasscodeSettings_FailedAttempts_other = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "PasscodeSettings.FailedAttempts", .other)
    self._QuickSend_Photos_zero = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "QuickSend.Photos", .zero)
    self._QuickSend_Photos_one = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "QuickSend.Photos", .one)
    self._QuickSend_Photos_two = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "QuickSend.Photos", .two)
    self._QuickSend_Photos_few = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "QuickSend.Photos", .few)
    self._QuickSend_Photos_many = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "QuickSend.Photos", .many)
    self._QuickSend_Photos_other = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "QuickSend.Photos", .other)
    self._ServiceMessage_GameScoreSimple_zero = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "ServiceMessage.GameScoreSimple", .zero)
    self._ServiceMessage_GameScoreSimple_one = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "ServiceMessage.GameScoreSimple", .one)
    self._ServiceMessage_GameScoreSimple_two = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "ServiceMessage.GameScoreSimple", .two)
    self._ServiceMessage_GameScoreSimple_few = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "ServiceMessage.GameScoreSimple", .few)
    self._ServiceMessage_GameScoreSimple_many = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "ServiceMessage.GameScoreSimple", .many)
    self._ServiceMessage_GameScoreSimple_other = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "ServiceMessage.GameScoreSimple", .other)
    self._Notifications_ExceptionMuteExpires_Days_zero = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notifications.ExceptionMuteExpires.Days", .zero)
    self._Notifications_ExceptionMuteExpires_Days_one = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notifications.ExceptionMuteExpires.Days", .one)
    self._Notifications_ExceptionMuteExpires_Days_two = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notifications.ExceptionMuteExpires.Days", .two)
    self._Notifications_ExceptionMuteExpires_Days_few = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notifications.ExceptionMuteExpires.Days", .few)
    self._Notifications_ExceptionMuteExpires_Days_many = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notifications.ExceptionMuteExpires.Days", .many)
    self._Notifications_ExceptionMuteExpires_Days_other = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notifications.ExceptionMuteExpires.Days", .other)
    self._Notifications_Exceptions_zero = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notifications.Exceptions", .zero)
    self._Notifications_Exceptions_one = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notifications.Exceptions", .one)
    self._Notifications_Exceptions_two = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notifications.Exceptions", .two)
    self._Notifications_Exceptions_few = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notifications.Exceptions", .few)
    self._Notifications_Exceptions_many = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notifications.Exceptions", .many)
    self._Notifications_Exceptions_other = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notifications.Exceptions", .other)
    self._MessageTimer_Weeks_zero = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MessageTimer.Weeks", .zero)
    self._MessageTimer_Weeks_one = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MessageTimer.Weeks", .one)
    self._MessageTimer_Weeks_two = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MessageTimer.Weeks", .two)
    self._MessageTimer_Weeks_few = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MessageTimer.Weeks", .few)
    self._MessageTimer_Weeks_many = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MessageTimer.Weeks", .many)
    self._MessageTimer_Weeks_other = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MessageTimer.Weeks", .other)
    self._ForwardedFiles_zero = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "ForwardedFiles", .zero)
    self._ForwardedFiles_one = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "ForwardedFiles", .one)
    self._ForwardedFiles_two = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "ForwardedFiles", .two)
    self._ForwardedFiles_few = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "ForwardedFiles", .few)
    self._ForwardedFiles_many = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "ForwardedFiles", .many)
    self._ForwardedFiles_other = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "ForwardedFiles", .other)
    self._MessageTimer_ShortHours_zero = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MessageTimer.ShortHours", .zero)
    self._MessageTimer_ShortHours_one = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MessageTimer.ShortHours", .one)
    self._MessageTimer_ShortHours_two = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MessageTimer.ShortHours", .two)
    self._MessageTimer_ShortHours_few = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MessageTimer.ShortHours", .few)
    self._MessageTimer_ShortHours_many = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MessageTimer.ShortHours", .many)
    self._MessageTimer_ShortHours_other = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MessageTimer.ShortHours", .other)
    self._MessageTimer_Years_zero = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MessageTimer.Years", .zero)
    self._MessageTimer_Years_one = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MessageTimer.Years", .one)
    self._MessageTimer_Years_two = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MessageTimer.Years", .two)
    self._MessageTimer_Years_few = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MessageTimer.Years", .few)
    self._MessageTimer_Years_many = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MessageTimer.Years", .many)
    self._MessageTimer_Years_other = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MessageTimer.Years", .other)
    self._MessageTimer_ShortMinutes_zero = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MessageTimer.ShortMinutes", .zero)
    self._MessageTimer_ShortMinutes_one = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MessageTimer.ShortMinutes", .one)
    self._MessageTimer_ShortMinutes_two = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MessageTimer.ShortMinutes", .two)
    self._MessageTimer_ShortMinutes_few = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MessageTimer.ShortMinutes", .few)
    self._MessageTimer_ShortMinutes_many = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MessageTimer.ShortMinutes", .many)
    self._MessageTimer_ShortMinutes_other = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MessageTimer.ShortMinutes", .other)
    self._Forward_ConfirmMultipleFiles_zero = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Forward.ConfirmMultipleFiles", .zero)
    self._Forward_ConfirmMultipleFiles_one = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Forward.ConfirmMultipleFiles", .one)
    self._Forward_ConfirmMultipleFiles_two = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Forward.ConfirmMultipleFiles", .two)
    self._Forward_ConfirmMultipleFiles_few = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Forward.ConfirmMultipleFiles", .few)
    self._Forward_ConfirmMultipleFiles_many = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Forward.ConfirmMultipleFiles", .many)
    self._Forward_ConfirmMultipleFiles_other = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Forward.ConfirmMultipleFiles", .other)
    self._Notification_GameScoreSimple_zero = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notification.GameScoreSimple", .zero)
    self._Notification_GameScoreSimple_one = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notification.GameScoreSimple", .one)
    self._Notification_GameScoreSimple_two = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notification.GameScoreSimple", .two)
    self._Notification_GameScoreSimple_few = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notification.GameScoreSimple", .few)
    self._Notification_GameScoreSimple_many = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notification.GameScoreSimple", .many)
    self._Notification_GameScoreSimple_other = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Notification.GameScoreSimple", .other)
    self._SharedMedia_Generic_zero = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "SharedMedia.Generic", .zero)
    self._SharedMedia_Generic_one = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "SharedMedia.Generic", .one)
    self._SharedMedia_Generic_two = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "SharedMedia.Generic", .two)
    self._SharedMedia_Generic_few = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "SharedMedia.Generic", .few)
    self._SharedMedia_Generic_many = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "SharedMedia.Generic", .many)
    self._SharedMedia_Generic_other = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "SharedMedia.Generic", .other)
    self._DialogList_LiveLocationChatsCount_zero = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "DialogList.LiveLocationChatsCount", .zero)
    self._DialogList_LiveLocationChatsCount_one = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "DialogList.LiveLocationChatsCount", .one)
    self._DialogList_LiveLocationChatsCount_two = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "DialogList.LiveLocationChatsCount", .two)
    self._DialogList_LiveLocationChatsCount_few = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "DialogList.LiveLocationChatsCount", .few)
    self._DialogList_LiveLocationChatsCount_many = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "DialogList.LiveLocationChatsCount", .many)
    self._DialogList_LiveLocationChatsCount_other = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "DialogList.LiveLocationChatsCount", .other)
    self._Passport_Scans_zero = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Scans", .zero)
    self._Passport_Scans_one = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Scans", .one)
    self._Passport_Scans_two = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Scans", .two)
    self._Passport_Scans_few = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Scans", .few)
    self._Passport_Scans_many = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Scans", .many)
    self._Passport_Scans_other = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Passport.Scans", .other)
    self._MuteFor_Days_zero = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MuteFor.Days", .zero)
    self._MuteFor_Days_one = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MuteFor.Days", .one)
    self._MuteFor_Days_two = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MuteFor.Days", .two)
    self._MuteFor_Days_few = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MuteFor.Days", .few)
    self._MuteFor_Days_many = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MuteFor.Days", .many)
    self._MuteFor_Days_other = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "MuteFor.Days", .other)
    self._Call_ShortSeconds_zero = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Call.ShortSeconds", .zero)
    self._Call_ShortSeconds_one = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Call.ShortSeconds", .one)
    self._Call_ShortSeconds_two = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Call.ShortSeconds", .two)
    self._Call_ShortSeconds_few = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Call.ShortSeconds", .few)
    self._Call_ShortSeconds_many = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Call.ShortSeconds", .many)
    self._Call_ShortSeconds_other = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Call.ShortSeconds", .other)
    self._Media_ShareVideo_zero = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Media.ShareVideo", .zero)
    self._Media_ShareVideo_one = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Media.ShareVideo", .one)
    self._Media_ShareVideo_two = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Media.ShareVideo", .two)
    self._Media_ShareVideo_few = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Media.ShareVideo", .few)
    self._Media_ShareVideo_many = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Media.ShareVideo", .many)
    self._Media_ShareVideo_other = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Media.ShareVideo", .other)
    self._ForwardedAuthorsOthers_zero = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "ForwardedAuthorsOthers", .zero)
    self._ForwardedAuthorsOthers_one = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "ForwardedAuthorsOthers", .one)
    self._ForwardedAuthorsOthers_two = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "ForwardedAuthorsOthers", .two)
    self._ForwardedAuthorsOthers_few = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "ForwardedAuthorsOthers", .few)
    self._ForwardedAuthorsOthers_many = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "ForwardedAuthorsOthers", .many)
    self._ForwardedAuthorsOthers_other = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "ForwardedAuthorsOthers", .other)
    self._Call_ShortMinutes_zero = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Call.ShortMinutes", .zero)
    self._Call_ShortMinutes_one = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Call.ShortMinutes", .one)
    self._Call_ShortMinutes_two = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Call.ShortMinutes", .two)
    self._Call_ShortMinutes_few = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Call.ShortMinutes", .few)
    self._Call_ShortMinutes_many = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Call.ShortMinutes", .many)
    self._Call_ShortMinutes_other = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Call.ShortMinutes", .other)
    self._SharedMedia_DeleteItemsConfirmation_zero = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "SharedMedia.DeleteItemsConfirmation", .zero)
    self._SharedMedia_DeleteItemsConfirmation_one = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "SharedMedia.DeleteItemsConfirmation", .one)
    self._SharedMedia_DeleteItemsConfirmation_two = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "SharedMedia.DeleteItemsConfirmation", .two)
    self._SharedMedia_DeleteItemsConfirmation_few = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "SharedMedia.DeleteItemsConfirmation", .few)
    self._SharedMedia_DeleteItemsConfirmation_many = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "SharedMedia.DeleteItemsConfirmation", .many)
    self._SharedMedia_DeleteItemsConfirmation_other = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "SharedMedia.DeleteItemsConfirmation", .other)
    self._ForwardedLocations_zero = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "ForwardedLocations", .zero)
    self._ForwardedLocations_one = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "ForwardedLocations", .one)
    self._ForwardedLocations_two = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "ForwardedLocations", .two)
    self._ForwardedLocations_few = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "ForwardedLocations", .few)
    self._ForwardedLocations_many = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "ForwardedLocations", .many)
    self._ForwardedLocations_other = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "ForwardedLocations", .other)
    self._Conversation_LiveLocationMembersCount_zero = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.LiveLocationMembersCount", .zero)
    self._Conversation_LiveLocationMembersCount_one = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.LiveLocationMembersCount", .one)
    self._Conversation_LiveLocationMembersCount_two = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.LiveLocationMembersCount", .two)
    self._Conversation_LiveLocationMembersCount_few = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.LiveLocationMembersCount", .few)
    self._Conversation_LiveLocationMembersCount_many = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.LiveLocationMembersCount", .many)
    self._Conversation_LiveLocationMembersCount_other = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "Conversation.LiveLocationMembersCount", .other)
    self._InviteText_ContactsCountText_zero = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "InviteText.ContactsCountText", .zero)
    self._InviteText_ContactsCountText_one = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "InviteText.ContactsCountText", .one)
    self._InviteText_ContactsCountText_two = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "InviteText.ContactsCountText", .two)
    self._InviteText_ContactsCountText_few = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "InviteText.ContactsCountText", .few)
    self._InviteText_ContactsCountText_many = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "InviteText.ContactsCountText", .many)
    self._InviteText_ContactsCountText_other = getValueWithForm(self.primaryComponent.dict, self.secondaryComponent?.dict, "InviteText.ContactsCountText", .other)
        
    }
}

