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

private func getValue(_ dict: [String: String], _ key: String) -> String {
    if let value = dict[key] {
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
private func getValueWithForm(_ dict: [String: String], _ key: String, _ form: PluralizationForm) -> String {
    if let value = dict[key + form.canonicalSuffix] {
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
public final class PresentationStrings {
    public let lc: UInt32

    public let languageCode: String
    public let dict: [String: String]

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
    private let _Login_SmsRequestState1: String
    private let _Login_SmsRequestState1_r: [(Int, NSRange)]
    public func Login_SmsRequestState1(_ _0: Int, _ _1: Int) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Login_SmsRequestState1, self._Login_SmsRequestState1_r, ["\(_0)", String(format: "%.2d", _1)])
    }
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
    public let ContactInfo_PhoneLabelWorkFax: String
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
    public let ChannelInfo_DeleteChannelConfirmation: String
    public let Passport_Address_OneOfTypeBankStatement: String
    public let Weekday_ShortSaturday: String
    public let Settings_Passport: String
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
    public let Channel_AdminLog_MessagePreviousMessage: String
    private let _Time_MonthOfYear_m12: String
    private let _Time_MonthOfYear_m12_r: [(Int, NSRange)]
    public func Time_MonthOfYear_m12(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Time_MonthOfYear_m12, self._Time_MonthOfYear_m12_r, [_0])
    }
    public let ConversationProfile_LeaveDeleteAndExit: String
    public let State_connecting: String
    public let Passport_Scans_Upload: String
    public let Passport_Identity_FrontSideHelp: String
    public let AutoDownloadSettings_PhotosTitle: String
    public let Map_OpenInHereMaps: String
    public let Stickers_FavoriteStickers: String
    public let CheckoutInfo_Pay: String
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
    private let _Login_CallRequestState1: String
    private let _Login_CallRequestState1_r: [(Int, NSRange)]
    public func Login_CallRequestState1(_ _0: Int, _ _1: Int) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(_Login_CallRequestState1, self._Login_CallRequestState1_r, ["\(_0)", String(format: "%.2d", _1)])
    }
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
    public let Calls_CallTabDescription: String
    public let Passport_DeletePersonalDetails: String
    public let Passport_Address_AddBankStatement: String
    public let Resolve_ErrorNotFound: String
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
    public let Conversation_EncryptedDescription3: String
    public let Login_CodeFloodError: String
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
    public let FastTwoStepSetup_HintPlaceholder: String
    public let PrivacySettings_DataSettings: String
    public let ChangePhoneNumberNumber_Title: String
    public let NotificationsSound_Bell: String
    public let TwoStepAuth_EnterPasswordInvalid: String
    public let DialogList_SearchSectionMessages: String
    public let Media_ShareThisVideo: String
    public let Call_ReportIncludeLogDescription: String
    public let Preview_DeleteGif: String
    public let Passport_Address_OneOfTypeTemporaryRegistration: String
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
    public let PrivacySettings_PasscodeAndFaceId: String
    public let Settings_ChatBackground: String
    public let Login_TermsOfServiceDecline: String
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


    init(languageCode: String, dict: [String: String]) {
        self.languageCode = languageCode
        self.dict = dict
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
        self.Channel_BanUser_Title = getValue(dict, "Channel.BanUser.Title")
        self.Notification_SecretChatMessageScreenshotSelf = getValue(dict, "Notification.SecretChatMessageScreenshotSelf")
        self.Preview_SaveGif = getValue(dict, "Preview.SaveGif")
        self.Passport_ScanPassportHelp = getValue(dict, "Passport.ScanPassportHelp")
        self.EnterPasscode_EnterNewPasscodeNew = getValue(dict, "EnterPasscode.EnterNewPasscodeNew")
        self.Passport_Identity_TypeInternalPassport = getValue(dict, "Passport.Identity.TypeInternalPassport")
        self.Privacy_Calls_WhoCanCallMe = getValue(dict, "Privacy.Calls.WhoCanCallMe")
        self.Passport_DeletePassport = getValue(dict, "Passport.DeletePassport")
        self.Watch_NoConnection = getValue(dict, "Watch.NoConnection")
        self.Activity_UploadingPhoto = getValue(dict, "Activity.UploadingPhoto")
        self.PrivacySettings_PrivacyTitle = getValue(dict, "PrivacySettings.PrivacyTitle")
        self._DialogList_PinLimitError = getValue(dict, "DialogList.PinLimitError")
        self._DialogList_PinLimitError_r = extractArgumentRanges(self._DialogList_PinLimitError)
        self.FastTwoStepSetup_PasswordSection = getValue(dict, "FastTwoStepSetup.PasswordSection")
        self.FastTwoStepSetup_EmailSection = getValue(dict, "FastTwoStepSetup.EmailSection")
        self.Cache_ClearCache = getValue(dict, "Cache.ClearCache")
        self.Common_Close = getValue(dict, "Common.Close")
        self.Passport_PasswordDescription = getValue(dict, "Passport.PasswordDescription")
        self.ChangePhoneNumberCode_Called = getValue(dict, "ChangePhoneNumberCode.Called")
        self.Login_PhoneTitle = getValue(dict, "Login.PhoneTitle")
        self._Cache_Clear = getValue(dict, "Cache.Clear")
        self._Cache_Clear_r = extractArgumentRanges(self._Cache_Clear)
        self.EnterPasscode_EnterNewPasscodeChange = getValue(dict, "EnterPasscode.EnterNewPasscodeChange")
        self.Watch_ChatList_Compose = getValue(dict, "Watch.ChatList.Compose")
        self.DialogList_SearchSectionDialogs = getValue(dict, "DialogList.SearchSectionDialogs")
        self.Contacts_TabTitle = getValue(dict, "Contacts.TabTitle")
        self.NotificationsSound_Pulse = getValue(dict, "NotificationsSound.Pulse")
        self.Passport_Language_el = getValue(dict, "Passport.Language.el")
        self.Passport_Identity_DateOfBirth = getValue(dict, "Passport.Identity.DateOfBirth")
        self.TwoStepAuth_SetupPasswordConfirmPassword = getValue(dict, "TwoStepAuth.SetupPasswordConfirmPassword")
        self.SocksProxySetup_PasteFromClipboard = getValue(dict, "SocksProxySetup.PasteFromClipboard")
        self.ChannelIntro_Text = getValue(dict, "ChannelIntro.Text")
        self.PrivacySettings_SecurityTitle = getValue(dict, "PrivacySettings.SecurityTitle")
        self.DialogList_SavedMessages = getValue(dict, "DialogList.SavedMessages")
        self._Login_SmsRequestState1 = getValue(dict, "Login.SmsRequestState1")
        self._Login_SmsRequestState1_r = extractArgumentRanges(self._Login_SmsRequestState1)
        self.Update_Skip = getValue(dict, "Update.Skip")
        self._Call_StatusOngoing = getValue(dict, "Call.StatusOngoing")
        self._Call_StatusOngoing_r = extractArgumentRanges(self._Call_StatusOngoing)
        self.Settings_LogoutConfirmationText = getValue(dict, "Settings.LogoutConfirmationText")
        self.Passport_Identity_ResidenceCountry = getValue(dict, "Passport.Identity.ResidenceCountry")
        self.AutoNightTheme_ScheduledTo = getValue(dict, "AutoNightTheme.ScheduledTo")
        self.SocksProxySetup_RequiredCredentials = getValue(dict, "SocksProxySetup.RequiredCredentials")
        self.BlockedUsers_Info = getValue(dict, "BlockedUsers.Info")
        self.ChatSettings_AutomaticAudioDownload = getValue(dict, "ChatSettings.AutomaticAudioDownload")
        self.Settings_SetUsername = getValue(dict, "Settings.SetUsername")
        self.Privacy_Calls_CustomShareHelp = getValue(dict, "Privacy.Calls.CustomShareHelp")
        self.Group_MessagePhotoUpdated = getValue(dict, "Group.MessagePhotoUpdated")
        self.Message_PinnedInvoice = getValue(dict, "Message.PinnedInvoice")
        self.Login_InfoAvatarAdd = getValue(dict, "Login.InfoAvatarAdd")
        self.Conversation_RestrictedMedia = getValue(dict, "Conversation.RestrictedMedia")
        self.AutoDownloadSettings_LimitBySize = getValue(dict, "AutoDownloadSettings.LimitBySize")
        self.WebSearch_RecentSectionTitle = getValue(dict, "WebSearch.RecentSectionTitle")
        self._CHAT_MESSAGE_TEXT = getValue(dict, "CHAT_MESSAGE_TEXT")
        self._CHAT_MESSAGE_TEXT_r = extractArgumentRanges(self._CHAT_MESSAGE_TEXT)
        self.Message_Sticker = getValue(dict, "Message.Sticker")
        self.Paint_Regular = getValue(dict, "Paint.Regular")
        self.Channel_Username_Help = getValue(dict, "Channel.Username.Help")
        self._Profile_CreateEncryptedChatOutdatedError = getValue(dict, "Profile.CreateEncryptedChatOutdatedError")
        self._Profile_CreateEncryptedChatOutdatedError_r = extractArgumentRanges(self._Profile_CreateEncryptedChatOutdatedError)
        self.PrivacyPolicy_DeclineLastWarning = getValue(dict, "PrivacyPolicy.DeclineLastWarning")
        self.Passport_FieldEmail = getValue(dict, "Passport.FieldEmail")
        self.ContactInfo_PhoneLabelPager = getValue(dict, "ContactInfo.PhoneLabelPager")
        self._PINNED_STICKER = getValue(dict, "PINNED_STICKER")
        self._PINNED_STICKER_r = extractArgumentRanges(self._PINNED_STICKER)
        self.AutoDownloadSettings_Title = getValue(dict, "AutoDownloadSettings.Title")
        self.Conversation_ShareInlineBotLocationConfirmation = getValue(dict, "Conversation.ShareInlineBotLocationConfirmation")
        self._Channel_AdminLog_MessageEdited = getValue(dict, "Channel.AdminLog.MessageEdited")
        self._Channel_AdminLog_MessageEdited_r = extractArgumentRanges(self._Channel_AdminLog_MessageEdited)
        self.Group_Setup_HistoryHidden = getValue(dict, "Group.Setup.HistoryHidden")
        self._PHONE_CALL_REQUEST = getValue(dict, "PHONE_CALL_REQUEST")
        self._PHONE_CALL_REQUEST_r = extractArgumentRanges(self._PHONE_CALL_REQUEST)
        self.AccessDenied_MicrophoneRestricted = getValue(dict, "AccessDenied.MicrophoneRestricted")
        self.Your_cards_expiration_year_is_invalid = getValue(dict, "Your_cards_expiration_year_is_invalid")
        self.GroupInfo_InviteByLink = getValue(dict, "GroupInfo.InviteByLink")
        self._Notification_LeftChat = getValue(dict, "Notification.LeftChat")
        self._Notification_LeftChat_r = extractArgumentRanges(self._Notification_LeftChat)
        self.Appearance_AutoNightThemeDisabled = getValue(dict, "Appearance.AutoNightThemeDisabled")
        self._Channel_AdminLog_MessageAdmin = getValue(dict, "Channel.AdminLog.MessageAdmin")
        self._Channel_AdminLog_MessageAdmin_r = extractArgumentRanges(self._Channel_AdminLog_MessageAdmin)
        self.PrivacyLastSeenSettings_NeverShareWith_Placeholder = getValue(dict, "PrivacyLastSeenSettings.NeverShareWith.Placeholder")
        self.Notifications_ExceptionsMessagePlaceholder = getValue(dict, "Notifications.ExceptionsMessagePlaceholder")
        self.NotificationsSound_Alert = getValue(dict, "NotificationsSound.Alert")
        self.TwoStepAuth_SetupEmail = getValue(dict, "TwoStepAuth.SetupEmail")
        self.Checkout_PayWithFaceId = getValue(dict, "Checkout.PayWithFaceId")
        self.Login_ResetAccountProtected_Reset = getValue(dict, "Login.ResetAccountProtected.Reset")
        self.SocksProxySetup_Hostname = getValue(dict, "SocksProxySetup.Hostname")
        self._PrivacyPolicy_AgeVerificationMessage = getValue(dict, "PrivacyPolicy.AgeVerificationMessage")
        self._PrivacyPolicy_AgeVerificationMessage_r = extractArgumentRanges(self._PrivacyPolicy_AgeVerificationMessage)
        self.NotificationsSound_None = getValue(dict, "NotificationsSound.None")
        self.Channel_AdminLog_CanEditMessages = getValue(dict, "Channel.AdminLog.CanEditMessages")
        self._MESSAGE_CONTACT = getValue(dict, "MESSAGE_CONTACT")
        self._MESSAGE_CONTACT_r = extractArgumentRanges(self._MESSAGE_CONTACT)
        self.MediaPicker_MomentsDateRangeSameMonthYearFormat = getValue(dict, "MediaPicker.MomentsDateRangeSameMonthYearFormat")
        self.Notification_MessageLifetime1w = getValue(dict, "Notification.MessageLifetime1w")
        self.PasscodeSettings_AutoLock_IfAwayFor_5minutes = getValue(dict, "PasscodeSettings.AutoLock.IfAwayFor_5minutes")
        self.ChatSettings_Groups = getValue(dict, "ChatSettings.Groups")
        self.State_Connecting = getValue(dict, "State.Connecting")
        self._Message_ForwardedMessageShort = getValue(dict, "Message.ForwardedMessageShort")
        self._Message_ForwardedMessageShort_r = extractArgumentRanges(self._Message_ForwardedMessageShort)
        self.Watch_ConnectionDescription = getValue(dict, "Watch.ConnectionDescription")
        self._Notification_CallTimeFormat = getValue(dict, "Notification.CallTimeFormat")
        self._Notification_CallTimeFormat_r = extractArgumentRanges(self._Notification_CallTimeFormat)
        self.Passport_Identity_Selfie = getValue(dict, "Passport.Identity.Selfie")
        self.Passport_Identity_GenderMale = getValue(dict, "Passport.Identity.GenderMale")
        self.Paint_Delete = getValue(dict, "Paint.Delete")
        self.Passport_Identity_AddDriversLicense = getValue(dict, "Passport.Identity.AddDriversLicense")
        self.Passport_Language_ne = getValue(dict, "Passport.Language.ne")
        self.Channel_MessagePhotoUpdated = getValue(dict, "Channel.MessagePhotoUpdated")
        self.Passport_Address_OneOfTypePassportRegistration = getValue(dict, "Passport.Address.OneOfTypePassportRegistration")
        self.Cache_Help = getValue(dict, "Cache.Help")
        self.SocksProxySetup_ProxyStatusConnected = getValue(dict, "SocksProxySetup.ProxyStatusConnected")
        self._Login_EmailPhoneBody = getValue(dict, "Login.EmailPhoneBody")
        self._Login_EmailPhoneBody_r = extractArgumentRanges(self._Login_EmailPhoneBody)
        self.Checkout_ShippingAddress = getValue(dict, "Checkout.ShippingAddress")
        self.Channel_BanList_RestrictedTitle = getValue(dict, "Channel.BanList.RestrictedTitle")
        self.Checkout_TotalAmount = getValue(dict, "Checkout.TotalAmount")
        self.Appearance_TextSize = getValue(dict, "Appearance.TextSize")
        self.Passport_Address_TypeResidentialAddress = getValue(dict, "Passport.Address.TypeResidentialAddress")
        self.Conversation_MessageEditedLabel = getValue(dict, "Conversation.MessageEditedLabel")
        self.SharedMedia_EmptyLinksText = getValue(dict, "SharedMedia.EmptyLinksText")
        self._Conversation_RestrictedTextTimed = getValue(dict, "Conversation.RestrictedTextTimed")
        self._Conversation_RestrictedTextTimed_r = extractArgumentRanges(self._Conversation_RestrictedTextTimed)
        self.Passport_Address_AddResidentialAddress = getValue(dict, "Passport.Address.AddResidentialAddress")
        self.Calls_NoCallsPlaceholder = getValue(dict, "Calls.NoCallsPlaceholder")
        self.Passport_Address_AddPassportRegistration = getValue(dict, "Passport.Address.AddPassportRegistration")
        self.Conversation_PinMessageAlert_OnlyPin = getValue(dict, "Conversation.PinMessageAlert.OnlyPin")
        self.PasscodeSettings_UnlockWithFaceId = getValue(dict, "PasscodeSettings.UnlockWithFaceId")
        self.ContactInfo_Title = getValue(dict, "ContactInfo.Title")
        self.ReportPeer_ReasonOther_Send = getValue(dict, "ReportPeer.ReasonOther.Send")
        self.Conversation_InstantPagePreview = getValue(dict, "Conversation.InstantPagePreview")
        self.PasscodeSettings_SimplePasscodeHelp = getValue(dict, "PasscodeSettings.SimplePasscodeHelp")
        self._Time_PreciseDate_m9 = getValue(dict, "Time.PreciseDate_m9")
        self._Time_PreciseDate_m9_r = extractArgumentRanges(self._Time_PreciseDate_m9)
        self.GroupInfo_Title = getValue(dict, "GroupInfo.Title")
        self.State_Updating = getValue(dict, "State.Updating")
        self.PrivacyPolicy_AgeVerificationAgree = getValue(dict, "PrivacyPolicy.AgeVerificationAgree")
        self.Map_GetDirections = getValue(dict, "Map.GetDirections")
        self._TwoStepAuth_PendingEmailHelp = getValue(dict, "TwoStepAuth.PendingEmailHelp")
        self._TwoStepAuth_PendingEmailHelp_r = extractArgumentRanges(self._TwoStepAuth_PendingEmailHelp)
        self.UserInfo_PhoneCall = getValue(dict, "UserInfo.PhoneCall")
        self.Passport_Language_bn = getValue(dict, "Passport.Language.bn")
        self.MusicPlayer_VoiceNote = getValue(dict, "MusicPlayer.VoiceNote")
        self.Paint_Duplicate = getValue(dict, "Paint.Duplicate")
        self.Channel_Username_InvalidTaken = getValue(dict, "Channel.Username.InvalidTaken")
        self.Conversation_ClearGroupHistory = getValue(dict, "Conversation.ClearGroupHistory")
        self.Passport_Address_OneOfTypeRentalAgreement = getValue(dict, "Passport.Address.OneOfTypeRentalAgreement")
        self.Stickers_GroupStickersHelp = getValue(dict, "Stickers.GroupStickersHelp")
        self.SecretChat_Title = getValue(dict, "SecretChat.Title")
        self.Group_UpgradeConfirmation = getValue(dict, "Group.UpgradeConfirmation")
        self.Checkout_LiabilityAlertTitle = getValue(dict, "Checkout.LiabilityAlertTitle")
        self.GroupInfo_GroupNamePlaceholder = getValue(dict, "GroupInfo.GroupNamePlaceholder")
        self._Time_PreciseDate_m11 = getValue(dict, "Time.PreciseDate_m11")
        self._Time_PreciseDate_m11_r = extractArgumentRanges(self._Time_PreciseDate_m11)
        self.Passport_DeletePersonalDetailsConfirmation = getValue(dict, "Passport.DeletePersonalDetailsConfirmation")
        self._UserInfo_NotificationsDefaultSound = getValue(dict, "UserInfo.NotificationsDefaultSound")
        self._UserInfo_NotificationsDefaultSound_r = extractArgumentRanges(self._UserInfo_NotificationsDefaultSound)
        self.Passport_Email_Help = getValue(dict, "Passport.Email.Help")
        self._MESSAGE_GEOLIVE = getValue(dict, "MESSAGE_GEOLIVE")
        self._MESSAGE_GEOLIVE_r = extractArgumentRanges(self._MESSAGE_GEOLIVE)
        self._Notification_JoinedGroupByLink = getValue(dict, "Notification.JoinedGroupByLink")
        self._Notification_JoinedGroupByLink_r = extractArgumentRanges(self._Notification_JoinedGroupByLink)
        self.LoginPassword_Title = getValue(dict, "LoginPassword.Title")
        self.Login_HaveNotReceivedCodeInternal = getValue(dict, "Login.HaveNotReceivedCodeInternal")
        self.PasscodeSettings_SimplePasscode = getValue(dict, "PasscodeSettings.SimplePasscode")
        self.NewContact_Title = getValue(dict, "NewContact.Title")
        self.Username_CheckingUsername = getValue(dict, "Username.CheckingUsername")
        self.Login_ResetAccountProtected_TimerTitle = getValue(dict, "Login.ResetAccountProtected.TimerTitle")
        self.Checkout_Email = getValue(dict, "Checkout.Email")
        self.CheckoutInfo_SaveInfo = getValue(dict, "CheckoutInfo.SaveInfo")
        self.UserInfo_InviteBotToGroup = getValue(dict, "UserInfo.InviteBotToGroup")
        self._ChangePhoneNumberCode_CallTimer = getValue(dict, "ChangePhoneNumberCode.CallTimer")
        self._ChangePhoneNumberCode_CallTimer_r = extractArgumentRanges(self._ChangePhoneNumberCode_CallTimer)
        self.TwoStepAuth_SetupPasswordEnterPasswordNew = getValue(dict, "TwoStepAuth.SetupPasswordEnterPasswordNew")
        self._Channel_AdminLog_MessageToggleSignaturesOff = getValue(dict, "Channel.AdminLog.MessageToggleSignaturesOff")
        self._Channel_AdminLog_MessageToggleSignaturesOff_r = extractArgumentRanges(self._Channel_AdminLog_MessageToggleSignaturesOff)
        self.Month_ShortDecember = getValue(dict, "Month.ShortDecember")
        self.Channel_SignMessages = getValue(dict, "Channel.SignMessages")
        self.Appearance_Title = getValue(dict, "Appearance.Title")
        self.ReportPeer_ReasonCopyright = getValue(dict, "ReportPeer.ReasonCopyright")
        self.Conversation_Moderate_Delete = getValue(dict, "Conversation.Moderate.Delete")
        self.Conversation_CloudStorage_ChatStatus = getValue(dict, "Conversation.CloudStorage.ChatStatus")
        self.Login_InfoTitle = getValue(dict, "Login.InfoTitle")
        self.Privacy_GroupsAndChannels_NeverAllow_Placeholder = getValue(dict, "Privacy.GroupsAndChannels.NeverAllow.Placeholder")
        self.Message_Video = getValue(dict, "Message.Video")
        self.Notification_ChannelInviterSelf = getValue(dict, "Notification.ChannelInviterSelf")
        self.Channel_AdminLog_BanEmbedLinks = getValue(dict, "Channel.AdminLog.BanEmbedLinks")
        self.Conversation_SecretLinkPreviewAlert = getValue(dict, "Conversation.SecretLinkPreviewAlert")
        self._CHANNEL_MESSAGE_GEOLIVE = getValue(dict, "CHANNEL_MESSAGE_GEOLIVE")
        self._CHANNEL_MESSAGE_GEOLIVE_r = extractArgumentRanges(self._CHANNEL_MESSAGE_GEOLIVE)
        self.Cache_Videos = getValue(dict, "Cache.Videos")
        self.Call_ReportSkip = getValue(dict, "Call.ReportSkip")
        self.NetworkUsageSettings_MediaImageDataSection = getValue(dict, "NetworkUsageSettings.MediaImageDataSection")
        self.Group_Setup_HistoryTitle = getValue(dict, "Group.Setup.HistoryTitle")
        self.TwoStepAuth_GenericHelp = getValue(dict, "TwoStepAuth.GenericHelp")
        self._DialogList_SingleRecordingAudioSuffix = getValue(dict, "DialogList.SingleRecordingAudioSuffix")
        self._DialogList_SingleRecordingAudioSuffix_r = extractArgumentRanges(self._DialogList_SingleRecordingAudioSuffix)
        self.Privacy_TopPeersDelete = getValue(dict, "Privacy.TopPeersDelete")
        self.Checkout_NewCard_CardholderNameTitle = getValue(dict, "Checkout.NewCard.CardholderNameTitle")
        self.Settings_FAQ_Button = getValue(dict, "Settings.FAQ_Button")
        self._GroupInfo_AddParticipantConfirmation = getValue(dict, "GroupInfo.AddParticipantConfirmation")
        self._GroupInfo_AddParticipantConfirmation_r = extractArgumentRanges(self._GroupInfo_AddParticipantConfirmation)
        self._Notification_PinnedLiveLocationMessage = getValue(dict, "Notification.PinnedLiveLocationMessage")
        self._Notification_PinnedLiveLocationMessage_r = extractArgumentRanges(self._Notification_PinnedLiveLocationMessage)
        self.AccessDenied_PhotosRestricted = getValue(dict, "AccessDenied.PhotosRestricted")
        self.Map_Locating = getValue(dict, "Map.Locating")
        self.AutoDownloadSettings_Unlimited = getValue(dict, "AutoDownloadSettings.Unlimited")
        self.Passport_Language_km = getValue(dict, "Passport.Language.km")
        self.MediaPicker_LivePhotoDescription = getValue(dict, "MediaPicker.LivePhotoDescription")
        self.Passport_DiscardMessageDescription = getValue(dict, "Passport.DiscardMessageDescription")
        self.SocksProxySetup_Title = getValue(dict, "SocksProxySetup.Title")
        self.SharedMedia_EmptyMusicText = getValue(dict, "SharedMedia.EmptyMusicText")
        self.Cache_ByPeerHeader = getValue(dict, "Cache.ByPeerHeader")
        self.Bot_GroupStatusReadsHistory = getValue(dict, "Bot.GroupStatusReadsHistory")
        self.TwoStepAuth_ResetAccountConfirmation = getValue(dict, "TwoStepAuth.ResetAccountConfirmation")
        self.CallSettings_Always = getValue(dict, "CallSettings.Always")
        self.Message_ImageExpired = getValue(dict, "Message.ImageExpired")
        self.Channel_BanUser_Unban = getValue(dict, "Channel.BanUser.Unban")
        self.Stickers_GroupChooseStickerPack = getValue(dict, "Stickers.GroupChooseStickerPack")
        self.Group_Setup_TypePrivate = getValue(dict, "Group.Setup.TypePrivate")
        self.Passport_Language_cs = getValue(dict, "Passport.Language.cs")
        self.Settings_LogoutConfirmationTitle = getValue(dict, "Settings.LogoutConfirmationTitle")
        self.UserInfo_FirstNamePlaceholder = getValue(dict, "UserInfo.FirstNamePlaceholder")
        self.Passport_Identity_SurnamePlaceholder = getValue(dict, "Passport.Identity.SurnamePlaceholder")
        self.Passport_Identity_FilesView = getValue(dict, "Passport.Identity.FilesView")
        self.LoginPassword_ResetAccount = getValue(dict, "LoginPassword.ResetAccount")
        self.Privacy_GroupsAndChannels_AlwaysAllow = getValue(dict, "Privacy.GroupsAndChannels.AlwaysAllow")
        self._Notification_JoinedChat = getValue(dict, "Notification.JoinedChat")
        self._Notification_JoinedChat_r = extractArgumentRanges(self._Notification_JoinedChat)
        self.Notifications_ExceptionsUnmuted = getValue(dict, "Notifications.ExceptionsUnmuted")
        self.ChannelInfo_DeleteChannel = getValue(dict, "ChannelInfo.DeleteChannel")
        self.Passport_Title = getValue(dict, "Passport.Title")
        self.NetworkUsageSettings_BytesReceived = getValue(dict, "NetworkUsageSettings.BytesReceived")
        self.BlockedUsers_BlockTitle = getValue(dict, "BlockedUsers.BlockTitle")
        self.Update_Title = getValue(dict, "Update.Title")
        self.AccessDenied_PhotosAndVideos = getValue(dict, "AccessDenied.PhotosAndVideos")
        self.Channel_Username_Title = getValue(dict, "Channel.Username.Title")
        self._Channel_AdminLog_MessageToggleSignaturesOn = getValue(dict, "Channel.AdminLog.MessageToggleSignaturesOn")
        self._Channel_AdminLog_MessageToggleSignaturesOn_r = extractArgumentRanges(self._Channel_AdminLog_MessageToggleSignaturesOn)
        self.Map_PullUpForPlaces = getValue(dict, "Map.PullUpForPlaces")
        self._Conversation_EncryptionWaiting = getValue(dict, "Conversation.EncryptionWaiting")
        self._Conversation_EncryptionWaiting_r = extractArgumentRanges(self._Conversation_EncryptionWaiting)
        self.Passport_Language_ka = getValue(dict, "Passport.Language.ka")
        self.InfoPlist_NSSiriUsageDescription = getValue(dict, "InfoPlist.NSSiriUsageDescription")
        self.Calls_NotNow = getValue(dict, "Calls.NotNow")
        self.Conversation_Report = getValue(dict, "Conversation.Report")
        self._CHANNEL_MESSAGE_DOC = getValue(dict, "CHANNEL_MESSAGE_DOC")
        self._CHANNEL_MESSAGE_DOC_r = extractArgumentRanges(self._CHANNEL_MESSAGE_DOC)
        self.Channel_AdminLogFilter_EventsAll = getValue(dict, "Channel.AdminLogFilter.EventsAll")
        self.InfoPlist_NSLocationWhenInUseUsageDescription = getValue(dict, "InfoPlist.NSLocationWhenInUseUsageDescription")
        self.Passport_Address_TypeTemporaryRegistration = getValue(dict, "Passport.Address.TypeTemporaryRegistration")
        self.Call_ConnectionErrorTitle = getValue(dict, "Call.ConnectionErrorTitle")
        self.Passport_Language_tr = getValue(dict, "Passport.Language.tr")
        self.Settings_ApplyProxyAlertEnable = getValue(dict, "Settings.ApplyProxyAlertEnable")
        self.Settings_ChatSettings = getValue(dict, "Settings.ChatSettings")
        self.Group_About_Help = getValue(dict, "Group.About.Help")
        self._CHANNEL_MESSAGE_NOTEXT = getValue(dict, "CHANNEL_MESSAGE_NOTEXT")
        self._CHANNEL_MESSAGE_NOTEXT_r = extractArgumentRanges(self._CHANNEL_MESSAGE_NOTEXT)
        self.Month_GenSeptember = getValue(dict, "Month.GenSeptember")
        self.PrivacySettings_LastSeenEverybody = getValue(dict, "PrivacySettings.LastSeenEverybody")
        self.Contacts_NotRegisteredSection = getValue(dict, "Contacts.NotRegisteredSection")
        self.PhotoEditor_BlurToolRadial = getValue(dict, "PhotoEditor.BlurToolRadial")
        self.TwoStepAuth_PasswordRemoveConfirmation = getValue(dict, "TwoStepAuth.PasswordRemoveConfirmation")
        self.Channel_EditAdmin_PermissionEditMessages = getValue(dict, "Channel.EditAdmin.PermissionEditMessages")
        self.TwoStepAuth_ChangePassword = getValue(dict, "TwoStepAuth.ChangePassword")
        self.Watch_MessageView_Title = getValue(dict, "Watch.MessageView.Title")
        self._Notification_PinnedRoundMessage = getValue(dict, "Notification.PinnedRoundMessage")
        self._Notification_PinnedRoundMessage_r = extractArgumentRanges(self._Notification_PinnedRoundMessage)
        self.Conversation_ViewMessage = getValue(dict, "Conversation.ViewMessage")
        self.Passport_FieldEmailHelp = getValue(dict, "Passport.FieldEmailHelp")
        self.Settings_SaveEditedPhotos = getValue(dict, "Settings.SaveEditedPhotos")
        self.Channel_Management_LabelCreator = getValue(dict, "Channel.Management.LabelCreator")
        self._Notification_PinnedStickerMessage = getValue(dict, "Notification.PinnedStickerMessage")
        self._Notification_PinnedStickerMessage_r = extractArgumentRanges(self._Notification_PinnedStickerMessage)
        self._AutoNightTheme_AutomaticHelp = getValue(dict, "AutoNightTheme.AutomaticHelp")
        self._AutoNightTheme_AutomaticHelp_r = extractArgumentRanges(self._AutoNightTheme_AutomaticHelp)
        self.Passport_Address_EditPassportRegistration = getValue(dict, "Passport.Address.EditPassportRegistration")
        self.PhotoEditor_QualityTool = getValue(dict, "PhotoEditor.QualityTool")
        self.Login_NetworkError = getValue(dict, "Login.NetworkError")
        self.TwoStepAuth_EnterPasswordForgot = getValue(dict, "TwoStepAuth.EnterPasswordForgot")
        self.Compose_ChannelMembers = getValue(dict, "Compose.ChannelMembers")
        self._Channel_AdminLog_CaptionEdited = getValue(dict, "Channel.AdminLog.CaptionEdited")
        self._Channel_AdminLog_CaptionEdited_r = extractArgumentRanges(self._Channel_AdminLog_CaptionEdited)
        self.Common_Yes = getValue(dict, "Common.Yes")
        self.KeyCommand_JumpToPreviousUnreadChat = getValue(dict, "KeyCommand.JumpToPreviousUnreadChat")
        self.CheckoutInfo_ReceiverInfoPhone = getValue(dict, "CheckoutInfo.ReceiverInfoPhone")
        self.SocksProxySetup_TypeNone = getValue(dict, "SocksProxySetup.TypeNone")
        self.GroupInfo_AddParticipantTitle = getValue(dict, "GroupInfo.AddParticipantTitle")
        self.Map_LiveLocationShowAll = getValue(dict, "Map.LiveLocationShowAll")
        self.Settings_SavedMessages = getValue(dict, "Settings.SavedMessages")
        self.Passport_FieldIdentitySelfieHelp = getValue(dict, "Passport.FieldIdentitySelfieHelp")
        self._CHANNEL_MESSAGE_TEXT = getValue(dict, "CHANNEL_MESSAGE_TEXT")
        self._CHANNEL_MESSAGE_TEXT_r = extractArgumentRanges(self._CHANNEL_MESSAGE_TEXT)
        self.Checkout_PayNone = getValue(dict, "Checkout.PayNone")
        self.CheckoutInfo_ErrorNameInvalid = getValue(dict, "CheckoutInfo.ErrorNameInvalid")
        self.Notification_PaymentSent = getValue(dict, "Notification.PaymentSent")
        self.Settings_Username = getValue(dict, "Settings.Username")
        self.Notification_CallMissedShort = getValue(dict, "Notification.CallMissedShort")
        self.Call_CallInProgressTitle = getValue(dict, "Call.CallInProgressTitle")
        self.Passport_Scans = getValue(dict, "Passport.Scans")
        self.PhotoEditor_Skip = getValue(dict, "PhotoEditor.Skip")
        self.AuthSessions_TerminateOtherSessionsHelp = getValue(dict, "AuthSessions.TerminateOtherSessionsHelp")
        self.Call_AudioRouteHeadphones = getValue(dict, "Call.AudioRouteHeadphones")
        self.SocksProxySetup_UseForCalls = getValue(dict, "SocksProxySetup.UseForCalls")
        self.Contacts_InviteFriends = getValue(dict, "Contacts.InviteFriends")
        self.Channel_BanUser_PermissionSendMessages = getValue(dict, "Channel.BanUser.PermissionSendMessages")
        self.Notifications_InAppNotificationsVibrate = getValue(dict, "Notifications.InAppNotificationsVibrate")
        self.StickerPack_Share = getValue(dict, "StickerPack.Share")
        self.Watch_MessageView_Reply = getValue(dict, "Watch.MessageView.Reply")
        self.Call_AudioRouteSpeaker = getValue(dict, "Call.AudioRouteSpeaker")
        self.Checkout_Title = getValue(dict, "Checkout.Title")
        self._MESSAGE_GEO = getValue(dict, "MESSAGE_GEO")
        self._MESSAGE_GEO_r = extractArgumentRanges(self._MESSAGE_GEO)
        self.Privacy_Calls = getValue(dict, "Privacy.Calls")
        self.DialogList_AdLabel = getValue(dict, "DialogList.AdLabel")
        self.Passport_Identity_ScansHelp = getValue(dict, "Passport.Identity.ScansHelp")
        self.Channel_AdminLogFilter_EventsInfo = getValue(dict, "Channel.AdminLogFilter.EventsInfo")
        self.Passport_Language_hu = getValue(dict, "Passport.Language.hu")
        self._Channel_AdminLog_MessagePinned = getValue(dict, "Channel.AdminLog.MessagePinned")
        self._Channel_AdminLog_MessagePinned_r = extractArgumentRanges(self._Channel_AdminLog_MessagePinned)
        self._Channel_AdminLog_MessageToggleInvitesOn = getValue(dict, "Channel.AdminLog.MessageToggleInvitesOn")
        self._Channel_AdminLog_MessageToggleInvitesOn_r = extractArgumentRanges(self._Channel_AdminLog_MessageToggleInvitesOn)
        self.KeyCommand_ScrollDown = getValue(dict, "KeyCommand.ScrollDown")
        self.Conversation_LinkDialogSave = getValue(dict, "Conversation.LinkDialogSave")
        self.CheckoutInfo_ErrorShippingNotAvailable = getValue(dict, "CheckoutInfo.ErrorShippingNotAvailable")
        self.Conversation_SendMessageErrorFlood = getValue(dict, "Conversation.SendMessageErrorFlood")
        self._Checkout_SavePasswordTimeoutAndTouchId = getValue(dict, "Checkout.SavePasswordTimeoutAndTouchId")
        self._Checkout_SavePasswordTimeoutAndTouchId_r = extractArgumentRanges(self._Checkout_SavePasswordTimeoutAndTouchId)
        self.HashtagSearch_AllChats = getValue(dict, "HashtagSearch.AllChats")
        self.InfoPlist_NSPhotoLibraryAddUsageDescription = getValue(dict, "InfoPlist.NSPhotoLibraryAddUsageDescription")
        self._Date_ChatDateHeaderYear = getValue(dict, "Date.ChatDateHeaderYear")
        self._Date_ChatDateHeaderYear_r = extractArgumentRanges(self._Date_ChatDateHeaderYear)
        self.Privacy_Calls_P2PContacts = getValue(dict, "Privacy.Calls.P2PContacts")
        self.Passport_Email_Delete = getValue(dict, "Passport.Email.Delete")
        self.CheckoutInfo_ShippingInfoCountry = getValue(dict, "CheckoutInfo.ShippingInfoCountry")
        self.Map_ShowPlaces = getValue(dict, "Map.ShowPlaces")
        self.Passport_Identity_GenderFemale = getValue(dict, "Passport.Identity.GenderFemale")
        self.Camera_VideoMode = getValue(dict, "Camera.VideoMode")
        self._Watch_Time_ShortFullAt = getValue(dict, "Watch.Time.ShortFullAt")
        self._Watch_Time_ShortFullAt_r = extractArgumentRanges(self._Watch_Time_ShortFullAt)
        self.UserInfo_TelegramCall = getValue(dict, "UserInfo.TelegramCall")
        self.PrivacyLastSeenSettings_CustomShareSettingsHelp = getValue(dict, "PrivacyLastSeenSettings.CustomShareSettingsHelp")
        self.Passport_UpdateRequiredError = getValue(dict, "Passport.UpdateRequiredError")
        self.Channel_AdminLog_InfoPanelAlertText = getValue(dict, "Channel.AdminLog.InfoPanelAlertText")
        self._Channel_AdminLog_MessageUnpinned = getValue(dict, "Channel.AdminLog.MessageUnpinned")
        self._Channel_AdminLog_MessageUnpinned_r = extractArgumentRanges(self._Channel_AdminLog_MessageUnpinned)
        self.Cache_Photos = getValue(dict, "Cache.Photos")
        self.Message_PinnedStickerMessage = getValue(dict, "Message.PinnedStickerMessage")
        self.PhotoEditor_QualityMedium = getValue(dict, "PhotoEditor.QualityMedium")
        self.Privacy_PaymentsClearInfo = getValue(dict, "Privacy.PaymentsClearInfo")
        self.PhotoEditor_CurvesRed = getValue(dict, "PhotoEditor.CurvesRed")
        self.Passport_Identity_AddPersonalDetails = getValue(dict, "Passport.Identity.AddPersonalDetails")
        self.ContactInfo_PhoneLabelWorkFax = getValue(dict, "ContactInfo.PhoneLabelWorkFax")
        self.Privacy_PaymentsTitle = getValue(dict, "Privacy.PaymentsTitle")
        self.SocksProxySetup_ProxyType = getValue(dict, "SocksProxySetup.ProxyType")
        self._Time_PreciseDate_m8 = getValue(dict, "Time.PreciseDate_m8")
        self._Time_PreciseDate_m8_r = extractArgumentRanges(self._Time_PreciseDate_m8)
        self.Login_PhoneNumberHelp = getValue(dict, "Login.PhoneNumberHelp")
        self.User_DeletedAccount = getValue(dict, "User.DeletedAccount")
        self.Call_StatusFailed = getValue(dict, "Call.StatusFailed")
        self._Notification_GroupInviter = getValue(dict, "Notification.GroupInviter")
        self._Notification_GroupInviter_r = extractArgumentRanges(self._Notification_GroupInviter)
        self.Localization_ChooseLanguage = getValue(dict, "Localization.ChooseLanguage")
        self.CheckoutInfo_ShippingInfoAddress2Placeholder = getValue(dict, "CheckoutInfo.ShippingInfoAddress2Placeholder")
        self._Notification_SecretChatMessageScreenshot = getValue(dict, "Notification.SecretChatMessageScreenshot")
        self._Notification_SecretChatMessageScreenshot_r = extractArgumentRanges(self._Notification_SecretChatMessageScreenshot)
        self._DialogList_SingleUploadingPhotoSuffix = getValue(dict, "DialogList.SingleUploadingPhotoSuffix")
        self._DialogList_SingleUploadingPhotoSuffix_r = extractArgumentRanges(self._DialogList_SingleUploadingPhotoSuffix)
        self.Channel_LeaveChannel = getValue(dict, "Channel.LeaveChannel")
        self.Compose_NewGroup = getValue(dict, "Compose.NewGroup")
        self.TwoStepAuth_EmailPlaceholder = getValue(dict, "TwoStepAuth.EmailPlaceholder")
        self.PhotoEditor_ExposureTool = getValue(dict, "PhotoEditor.ExposureTool")
        self.Conversation_ViewChannel = getValue(dict, "Conversation.ViewChannel")
        self.ChatAdmins_AdminLabel = getValue(dict, "ChatAdmins.AdminLabel")
        self.Contacts_FailedToSendInvitesMessage = getValue(dict, "Contacts.FailedToSendInvitesMessage")
        self.Login_Code = getValue(dict, "Login.Code")
        self.Passport_Identity_ExpiryDateNone = getValue(dict, "Passport.Identity.ExpiryDateNone")
        self.Channel_Username_InvalidCharacters = getValue(dict, "Channel.Username.InvalidCharacters")
        self.FeatureDisabled_Oops = getValue(dict, "FeatureDisabled.Oops")
        self.Calls_CallTabTitle = getValue(dict, "Calls.CallTabTitle")
        self.ShareMenu_Send = getValue(dict, "ShareMenu.Send")
        self.WatchRemote_AlertTitle = getValue(dict, "WatchRemote.AlertTitle")
        self.Channel_Members_AddBannedErrorAdmin = getValue(dict, "Channel.Members.AddBannedErrorAdmin")
        self.Conversation_InfoGroup = getValue(dict, "Conversation.InfoGroup")
        self.Passport_Identity_TypePersonalDetails = getValue(dict, "Passport.Identity.TypePersonalDetails")
        self.Passport_Identity_OneOfTypePassport = getValue(dict, "Passport.Identity.OneOfTypePassport")
        self.Checkout_Phone = getValue(dict, "Checkout.Phone")
        self.Channel_SignMessages_Help = getValue(dict, "Channel.SignMessages.Help")
        self.Passport_PasswordNext = getValue(dict, "Passport.PasswordNext")
        self.Calls_SubmitRating = getValue(dict, "Calls.SubmitRating")
        self.Camera_FlashOn = getValue(dict, "Camera.FlashOn")
        self.Watch_MessageView_Forward = getValue(dict, "Watch.MessageView.Forward")
        self.Passport_DiscardMessageTitle = getValue(dict, "Passport.DiscardMessageTitle")
        self.Passport_Language_uk = getValue(dict, "Passport.Language.uk")
        self.GroupInfo_ActionPromote = getValue(dict, "GroupInfo.ActionPromote")
        self.DialogList_You = getValue(dict, "DialogList.You")
        self.Passport_Identity_SelfieHelp = getValue(dict, "Passport.Identity.SelfieHelp")
        self.Passport_Identity_MiddleName = getValue(dict, "Passport.Identity.MiddleName")
        self.AccessDenied_Camera = getValue(dict, "AccessDenied.Camera")
        self.WatchRemote_NotificationText = getValue(dict, "WatchRemote.NotificationText")
        self.SharedMedia_ViewInChat = getValue(dict, "SharedMedia.ViewInChat")
        self.Activity_RecordingAudio = getValue(dict, "Activity.RecordingAudio")
        self.Watch_Stickers_StickerPacks = getValue(dict, "Watch.Stickers.StickerPacks")
        self._Target_ShareGameConfirmationPrivate = getValue(dict, "Target.ShareGameConfirmationPrivate")
        self._Target_ShareGameConfirmationPrivate_r = extractArgumentRanges(self._Target_ShareGameConfirmationPrivate)
        self.Checkout_NewCard_PostcodePlaceholder = getValue(dict, "Checkout.NewCard.PostcodePlaceholder")
        self.Passport_Identity_OneOfTypeInternalPassport = getValue(dict, "Passport.Identity.OneOfTypeInternalPassport")
        self.DialogList_DeleteConversationConfirmation = getValue(dict, "DialogList.DeleteConversationConfirmation")
        self.AttachmentMenu_SendAsFile = getValue(dict, "AttachmentMenu.SendAsFile")
        self.Watch_Conversation_Unblock = getValue(dict, "Watch.Conversation.Unblock")
        self.Channel_AdminLog_MessagePreviousLink = getValue(dict, "Channel.AdminLog.MessagePreviousLink")
        self.Conversation_ContextMenuCopy = getValue(dict, "Conversation.ContextMenuCopy")
        self.GroupInfo_UpgradeButton = getValue(dict, "GroupInfo.UpgradeButton")
        self.PrivacyLastSeenSettings_NeverShareWith = getValue(dict, "PrivacyLastSeenSettings.NeverShareWith")
        self.ConvertToSupergroup_HelpText = getValue(dict, "ConvertToSupergroup.HelpText")
        self.MediaPicker_VideoMuteDescription = getValue(dict, "MediaPicker.VideoMuteDescription")
        self.Passport_Address_TypeRentalAgreement = getValue(dict, "Passport.Address.TypeRentalAgreement")
        self.Passport_Language_it = getValue(dict, "Passport.Language.it")
        self.UserInfo_ShareMyContactInfo = getValue(dict, "UserInfo.ShareMyContactInfo")
        self.Channel_Info_Stickers = getValue(dict, "Channel.Info.Stickers")
        self.Appearance_ColorTheme = getValue(dict, "Appearance.ColorTheme")
        self._FileSize_GB = getValue(dict, "FileSize.GB")
        self._FileSize_GB_r = extractArgumentRanges(self._FileSize_GB)
        self._Passport_FieldOneOf_Or = getValue(dict, "Passport.FieldOneOf.Or")
        self._Passport_FieldOneOf_Or_r = extractArgumentRanges(self._Passport_FieldOneOf_Or)
        self.Month_ShortJanuary = getValue(dict, "Month.ShortJanuary")
        self.Channel_BanUser_PermissionsHeader = getValue(dict, "Channel.BanUser.PermissionsHeader")
        self.PhotoEditor_QualityVeryHigh = getValue(dict, "PhotoEditor.QualityVeryHigh")
        self.Passport_Language_mk = getValue(dict, "Passport.Language.mk")
        self.Login_TermsOfServiceLabel = getValue(dict, "Login.TermsOfServiceLabel")
        self._MESSAGE_TEXT = getValue(dict, "MESSAGE_TEXT")
        self._MESSAGE_TEXT_r = extractArgumentRanges(self._MESSAGE_TEXT)
        self.DialogList_NoMessagesTitle = getValue(dict, "DialogList.NoMessagesTitle")
        self.Passport_DeletePassportConfirmation = getValue(dict, "Passport.DeletePassportConfirmation")
        self.Passport_Language_az = getValue(dict, "Passport.Language.az")
        self.AccessDenied_Contacts = getValue(dict, "AccessDenied.Contacts")
        self.Your_cards_security_code_is_invalid = getValue(dict, "Your_cards_security_code_is_invalid")
        self.Contacts_InviteSearchLabel = getValue(dict, "Contacts.InviteSearchLabel")
        self.Tour_StartButton = getValue(dict, "Tour.StartButton")
        self.CheckoutInfo_Title = getValue(dict, "CheckoutInfo.Title")
        self.Conversation_Admin = getValue(dict, "Conversation.Admin")
        self._Channel_AdminLog_MessageRestrictedNameUsername = getValue(dict, "Channel.AdminLog.MessageRestrictedNameUsername")
        self._Channel_AdminLog_MessageRestrictedNameUsername_r = extractArgumentRanges(self._Channel_AdminLog_MessageRestrictedNameUsername)
        self.ChangePhoneNumberCode_Help = getValue(dict, "ChangePhoneNumberCode.Help")
        self.Web_Error = getValue(dict, "Web.Error")
        self.ShareFileTip_Title = getValue(dict, "ShareFileTip.Title")
        self.Privacy_SecretChatsLinkPreviews = getValue(dict, "Privacy.SecretChatsLinkPreviews")
        self.Username_InvalidStartsWithNumber = getValue(dict, "Username.InvalidStartsWithNumber")
        self._DialogList_EncryptedChatStartedIncoming = getValue(dict, "DialogList.EncryptedChatStartedIncoming")
        self._DialogList_EncryptedChatStartedIncoming_r = extractArgumentRanges(self._DialogList_EncryptedChatStartedIncoming)
        self.Calls_AddTab = getValue(dict, "Calls.AddTab")
        self.DialogList_AdNoticeAlert = getValue(dict, "DialogList.AdNoticeAlert")
        self.PhotoEditor_TiltShift = getValue(dict, "PhotoEditor.TiltShift")
        self.Passport_Identity_TypeDriversLicenseUploadScan = getValue(dict, "Passport.Identity.TypeDriversLicenseUploadScan")
        self.ChannelMembers_WhoCanAddMembers_Admins = getValue(dict, "ChannelMembers.WhoCanAddMembers.Admins")
        self.Tour_Text5 = getValue(dict, "Tour.Text5")
        self.Notifications_ExceptionsGroupPlaceholder = getValue(dict, "Notifications.ExceptionsGroupPlaceholder")
        self.Watch_Stickers_RecentPlaceholder = getValue(dict, "Watch.Stickers.RecentPlaceholder")
        self.Common_Select = getValue(dict, "Common.Select")
        self._Notification_MessageLifetimeRemoved = getValue(dict, "Notification.MessageLifetimeRemoved")
        self._Notification_MessageLifetimeRemoved_r = extractArgumentRanges(self._Notification_MessageLifetimeRemoved)
        self._PINNED_INVOICE = getValue(dict, "PINNED_INVOICE")
        self._PINNED_INVOICE_r = extractArgumentRanges(self._PINNED_INVOICE)
        self.Month_GenFebruary = getValue(dict, "Month.GenFebruary")
        self.Contacts_SelectAll = getValue(dict, "Contacts.SelectAll")
        self.FastTwoStepSetup_EmailHelp = getValue(dict, "FastTwoStepSetup.EmailHelp")
        self.Month_GenOctober = getValue(dict, "Month.GenOctober")
        self.CheckoutInfo_ErrorPhoneInvalid = getValue(dict, "CheckoutInfo.ErrorPhoneInvalid")
        self.Passport_Identity_DocumentNumberPlaceholder = getValue(dict, "Passport.Identity.DocumentNumberPlaceholder")
        self.AutoNightTheme_UpdateLocation = getValue(dict, "AutoNightTheme.UpdateLocation")
        self.Group_Setup_TypePublic = getValue(dict, "Group.Setup.TypePublic")
        self.Checkout_PaymentMethod_New = getValue(dict, "Checkout.PaymentMethod.New")
        self.ShareMenu_Comment = getValue(dict, "ShareMenu.Comment")
        self.Passport_FloodError = getValue(dict, "Passport.FloodError")
        self.Channel_Management_LabelEditor = getValue(dict, "Channel.Management.LabelEditor")
        self.TwoStepAuth_SetPasswordHelp = getValue(dict, "TwoStepAuth.SetPasswordHelp")
        self.Channel_AdminLogFilter_EventsTitle = getValue(dict, "Channel.AdminLogFilter.EventsTitle")
        self.NotificationSettings_ContactJoined = getValue(dict, "NotificationSettings.ContactJoined")
        self.ChatSettings_AutoDownloadVideos = getValue(dict, "ChatSettings.AutoDownloadVideos")
        self.Passport_Identity_TypeIdentityCard = getValue(dict, "Passport.Identity.TypeIdentityCard")
        self.Username_LinkCopied = getValue(dict, "Username.LinkCopied")
        self._Time_MonthOfYear_m9 = getValue(dict, "Time.MonthOfYear_m9")
        self._Time_MonthOfYear_m9_r = extractArgumentRanges(self._Time_MonthOfYear_m9)
        self.Channel_EditAdmin_PermissionAddAdmins = getValue(dict, "Channel.EditAdmin.PermissionAddAdmins")
        self.Passport_FieldPhoneHelp = getValue(dict, "Passport.FieldPhoneHelp")
        self.Conversation_SendMessage = getValue(dict, "Conversation.SendMessage")
        self.Notification_CallIncoming = getValue(dict, "Notification.CallIncoming")
        self._MESSAGE_FWDS = getValue(dict, "MESSAGE_FWDS")
        self._MESSAGE_FWDS_r = extractArgumentRanges(self._MESSAGE_FWDS)
        self.Map_OpenInYandexMaps = getValue(dict, "Map.OpenInYandexMaps")
        self.FastTwoStepSetup_PasswordHelp = getValue(dict, "FastTwoStepSetup.PasswordHelp")
        self.GroupInfo_GroupHistoryHidden = getValue(dict, "GroupInfo.GroupHistoryHidden")
        self.AutoNightTheme_UseSunsetSunrise = getValue(dict, "AutoNightTheme.UseSunsetSunrise")
        self.Month_ShortNovember = getValue(dict, "Month.ShortNovember")
        self.AccessDenied_Settings = getValue(dict, "AccessDenied.Settings")
        self.EncryptionKey_Title = getValue(dict, "EncryptionKey.Title")
        self.Profile_MessageLifetime1h = getValue(dict, "Profile.MessageLifetime1h")
        self._Map_DistanceAway = getValue(dict, "Map.DistanceAway")
        self._Map_DistanceAway_r = extractArgumentRanges(self._Map_DistanceAway)
        self.Checkout_ErrorPaymentFailed = getValue(dict, "Checkout.ErrorPaymentFailed")
        self.Compose_NewMessage = getValue(dict, "Compose.NewMessage")
        self.Conversation_LiveLocationYou = getValue(dict, "Conversation.LiveLocationYou")
        self.Privacy_TopPeersHelp = getValue(dict, "Privacy.TopPeersHelp")
        self.Map_OpenInWaze = getValue(dict, "Map.OpenInWaze")
        self.Checkout_ShippingMethod = getValue(dict, "Checkout.ShippingMethod")
        self.Login_InfoFirstNamePlaceholder = getValue(dict, "Login.InfoFirstNamePlaceholder")
        self.Checkout_ErrorProviderAccountInvalid = getValue(dict, "Checkout.ErrorProviderAccountInvalid")
        self.CallSettings_TabIconDescription = getValue(dict, "CallSettings.TabIconDescription")
        self.ChatSettings_AutoDownloadReset = getValue(dict, "ChatSettings.AutoDownloadReset")
        self.Checkout_WebConfirmation_Title = getValue(dict, "Checkout.WebConfirmation.Title")
        self.PasscodeSettings_AutoLock = getValue(dict, "PasscodeSettings.AutoLock")
        self.Notifications_MessageNotificationsPreview = getValue(dict, "Notifications.MessageNotificationsPreview")
        self.Conversation_BlockUser = getValue(dict, "Conversation.BlockUser")
        self.Passport_Identity_EditPassport = getValue(dict, "Passport.Identity.EditPassport")
        self.MessageTimer_Custom = getValue(dict, "MessageTimer.Custom")
        self.Conversation_SilentBroadcastTooltipOff = getValue(dict, "Conversation.SilentBroadcastTooltipOff")
        self.Conversation_Mute = getValue(dict, "Conversation.Mute")
        self.CreateGroup_SoftUserLimitAlert = getValue(dict, "CreateGroup.SoftUserLimitAlert")
        self.AccessDenied_LocationDenied = getValue(dict, "AccessDenied.LocationDenied")
        self.Tour_Title6 = getValue(dict, "Tour.Title6")
        self.Settings_UsernameEmpty = getValue(dict, "Settings.UsernameEmpty")
        self.PrivacySettings_TwoStepAuth = getValue(dict, "PrivacySettings.TwoStepAuth")
        self.Conversation_FileICloudDrive = getValue(dict, "Conversation.FileICloudDrive")
        self.KeyCommand_SendMessage = getValue(dict, "KeyCommand.SendMessage")
        self._Channel_AdminLog_MessageDeleted = getValue(dict, "Channel.AdminLog.MessageDeleted")
        self._Channel_AdminLog_MessageDeleted_r = extractArgumentRanges(self._Channel_AdminLog_MessageDeleted)
        self.DialogList_DeleteBotConfirmation = getValue(dict, "DialogList.DeleteBotConfirmation")
        self.EditProfile_Title = getValue(dict, "EditProfile.Title")
        self.PasscodeSettings_HelpTop = getValue(dict, "PasscodeSettings.HelpTop")
        self.SocksProxySetup_ProxySocks5 = getValue(dict, "SocksProxySetup.ProxySocks5")
        self.Common_TakePhotoOrVideo = getValue(dict, "Common.TakePhotoOrVideo")
        self.Notification_MessageLifetime2s = getValue(dict, "Notification.MessageLifetime2s")
        self.Checkout_ErrorGeneric = getValue(dict, "Checkout.ErrorGeneric")
        self.DialogList_Unread = getValue(dict, "DialogList.Unread")
        self.AutoNightTheme_Automatic = getValue(dict, "AutoNightTheme.Automatic")
        self.Passport_Identity_Name = getValue(dict, "Passport.Identity.Name")
        self.Channel_AdminLog_CanBanUsers = getValue(dict, "Channel.AdminLog.CanBanUsers")
        self.Cache_Indexing = getValue(dict, "Cache.Indexing")
        self._ENCRYPTION_REQUEST = getValue(dict, "ENCRYPTION_REQUEST")
        self._ENCRYPTION_REQUEST_r = extractArgumentRanges(self._ENCRYPTION_REQUEST)
        self.StickerSettings_ContextInfo = getValue(dict, "StickerSettings.ContextInfo")
        self.Channel_BanUser_PermissionEmbedLinks = getValue(dict, "Channel.BanUser.PermissionEmbedLinks")
        self.Map_Location = getValue(dict, "Map.Location")
        self.GroupInfo_InviteLink_LinkSection = getValue(dict, "GroupInfo.InviteLink.LinkSection")
        self._Passport_Identity_UploadOneOfScan = getValue(dict, "Passport.Identity.UploadOneOfScan")
        self._Passport_Identity_UploadOneOfScan_r = extractArgumentRanges(self._Passport_Identity_UploadOneOfScan)
        self.Notification_PassportValuePhone = getValue(dict, "Notification.PassportValuePhone")
        self.Privacy_Calls_AlwaysAllow_Placeholder = getValue(dict, "Privacy.Calls.AlwaysAllow.Placeholder")
        self.CheckoutInfo_ShippingInfoPostcode = getValue(dict, "CheckoutInfo.ShippingInfoPostcode")
        self.Group_Setup_HistoryVisibleHelp = getValue(dict, "Group.Setup.HistoryVisibleHelp")
        self._Time_PreciseDate_m7 = getValue(dict, "Time.PreciseDate_m7")
        self._Time_PreciseDate_m7_r = extractArgumentRanges(self._Time_PreciseDate_m7)
        self.PasscodeSettings_EncryptDataHelp = getValue(dict, "PasscodeSettings.EncryptDataHelp")
        self.Passport_Language_ja = getValue(dict, "Passport.Language.ja")
        self.KeyCommand_FocusOnInputField = getValue(dict, "KeyCommand.FocusOnInputField")
        self.Channel_Members_AddAdminErrorBlacklisted = getValue(dict, "Channel.Members.AddAdminErrorBlacklisted")
        self.Cache_KeepMedia = getValue(dict, "Cache.KeepMedia")
        self.SocksProxySetup_ProxyTelegram = getValue(dict, "SocksProxySetup.ProxyTelegram")
        self.WebPreview_GettingLinkInfo = getValue(dict, "WebPreview.GettingLinkInfo")
        self.Group_Setup_TypePublicHelp = getValue(dict, "Group.Setup.TypePublicHelp")
        self.Map_Satellite = getValue(dict, "Map.Satellite")
        self.Username_InvalidTaken = getValue(dict, "Username.InvalidTaken")
        self._Notification_PinnedAudioMessage = getValue(dict, "Notification.PinnedAudioMessage")
        self._Notification_PinnedAudioMessage_r = extractArgumentRanges(self._Notification_PinnedAudioMessage)
        self.Notification_MessageLifetime1d = getValue(dict, "Notification.MessageLifetime1d")
        self.Profile_MessageLifetime2s = getValue(dict, "Profile.MessageLifetime2s")
        self._TwoStepAuth_RecoveryEmailUnavailable = getValue(dict, "TwoStepAuth.RecoveryEmailUnavailable")
        self._TwoStepAuth_RecoveryEmailUnavailable_r = extractArgumentRanges(self._TwoStepAuth_RecoveryEmailUnavailable)
        self.Calls_RatingFeedback = getValue(dict, "Calls.RatingFeedback")
        self.Profile_EncryptionKey = getValue(dict, "Profile.EncryptionKey")
        self.Watch_Suggestion_WhatsUp = getValue(dict, "Watch.Suggestion.WhatsUp")
        self.LoginPassword_PasswordPlaceholder = getValue(dict, "LoginPassword.PasswordPlaceholder")
        self.TwoStepAuth_EnterPasswordPassword = getValue(dict, "TwoStepAuth.EnterPasswordPassword")
        self._Time_PreciseDate_m10 = getValue(dict, "Time.PreciseDate_m10")
        self._Time_PreciseDate_m10_r = extractArgumentRanges(self._Time_PreciseDate_m10)
        self._CHANNEL_MESSAGE_CONTACT = getValue(dict, "CHANNEL_MESSAGE_CONTACT")
        self._CHANNEL_MESSAGE_CONTACT_r = extractArgumentRanges(self._CHANNEL_MESSAGE_CONTACT)
        self.Passport_Language_bg = getValue(dict, "Passport.Language.bg")
        self.PrivacySettings_DeleteAccountHelp = getValue(dict, "PrivacySettings.DeleteAccountHelp")
        self.Channel_Info_Banned = getValue(dict, "Channel.Info.Banned")
        self.Conversation_ShareBotContactConfirmationTitle = getValue(dict, "Conversation.ShareBotContactConfirmationTitle")
        self.ConversationProfile_UsersTooMuchError = getValue(dict, "ConversationProfile.UsersTooMuchError")
        self.ChatAdmins_AllMembersAreAdminsOffHelp = getValue(dict, "ChatAdmins.AllMembersAreAdminsOffHelp")
        self.Privacy_GroupsAndChannels_WhoCanAddMe = getValue(dict, "Privacy.GroupsAndChannels.WhoCanAddMe")
        self.Login_CodeExpiredError = getValue(dict, "Login.CodeExpiredError")
        self.Settings_PhoneNumber = getValue(dict, "Settings.PhoneNumber")
        self.FastTwoStepSetup_EmailPlaceholder = getValue(dict, "FastTwoStepSetup.EmailPlaceholder")
        self._DialogList_MultipleTypingSuffix = getValue(dict, "DialogList.MultipleTypingSuffix")
        self._DialogList_MultipleTypingSuffix_r = extractArgumentRanges(self._DialogList_MultipleTypingSuffix)
        self.Passport_Phone_Help = getValue(dict, "Passport.Phone.Help")
        self.Passport_Language_sl = getValue(dict, "Passport.Language.sl")
        self.Bot_GenericBotStatus = getValue(dict, "Bot.GenericBotStatus")
        self.PrivacySettings_PasscodeAndTouchId = getValue(dict, "PrivacySettings.PasscodeAndTouchId")
        self.Common_edit = getValue(dict, "Common.edit")
        self.Settings_AppLanguage = getValue(dict, "Settings.AppLanguage")
        self.PrivacyLastSeenSettings_WhoCanSeeMyTimestamp = getValue(dict, "PrivacyLastSeenSettings.WhoCanSeeMyTimestamp")
        self._Notification_Kicked = getValue(dict, "Notification.Kicked")
        self._Notification_Kicked_r = extractArgumentRanges(self._Notification_Kicked)
        self.Channel_AdminLog_MessageRestrictedForever = getValue(dict, "Channel.AdminLog.MessageRestrictedForever")
        self.Passport_DeleteDocument = getValue(dict, "Passport.DeleteDocument")
        self.ChannelInfo_DeleteChannelConfirmation = getValue(dict, "ChannelInfo.DeleteChannelConfirmation")
        self.Passport_Address_OneOfTypeBankStatement = getValue(dict, "Passport.Address.OneOfTypeBankStatement")
        self.Weekday_ShortSaturday = getValue(dict, "Weekday.ShortSaturday")
        self.Settings_Passport = getValue(dict, "Settings.Passport")
        self.Map_SendThisLocation = getValue(dict, "Map.SendThisLocation")
        self._Notification_PinnedDocumentMessage = getValue(dict, "Notification.PinnedDocumentMessage")
        self._Notification_PinnedDocumentMessage_r = extractArgumentRanges(self._Notification_PinnedDocumentMessage)
        self.Passport_Identity_Surname = getValue(dict, "Passport.Identity.Surname")
        self.Conversation_ContextMenuReply = getValue(dict, "Conversation.ContextMenuReply")
        self.Channel_BanUser_PermissionSendMedia = getValue(dict, "Channel.BanUser.PermissionSendMedia")
        self.NetworkUsageSettings_Wifi = getValue(dict, "NetworkUsageSettings.Wifi")
        self.Call_Accept = getValue(dict, "Call.Accept")
        self.GroupInfo_SetGroupPhotoDelete = getValue(dict, "GroupInfo.SetGroupPhotoDelete")
        self.Login_PhoneBannedError = getValue(dict, "Login.PhoneBannedError")
        self.Passport_Identity_DocumentDetails = getValue(dict, "Passport.Identity.DocumentDetails")
        self.PhotoEditor_CropAuto = getValue(dict, "PhotoEditor.CropAuto")
        self.PhotoEditor_ContrastTool = getValue(dict, "PhotoEditor.ContrastTool")
        self.CheckoutInfo_ReceiverInfoNamePlaceholder = getValue(dict, "CheckoutInfo.ReceiverInfoNamePlaceholder")
        self.Passport_InfoLearnMore = getValue(dict, "Passport.InfoLearnMore")
        self.Channel_AdminLog_MessagePreviousCaption = getValue(dict, "Channel.AdminLog.MessagePreviousCaption")
        self._Passport_Email_UseTelegramEmail = getValue(dict, "Passport.Email.UseTelegramEmail")
        self._Passport_Email_UseTelegramEmail_r = extractArgumentRanges(self._Passport_Email_UseTelegramEmail)
        self.Privacy_PaymentsClear_ShippingInfo = getValue(dict, "Privacy.PaymentsClear.ShippingInfo")
        self.Passport_Email_UseTelegramEmailHelp = getValue(dict, "Passport.Email.UseTelegramEmailHelp")
        self.UserInfo_NotificationsDefaultDisabled = getValue(dict, "UserInfo.NotificationsDefaultDisabled")
        self.Date_DialogDateFormat = getValue(dict, "Date.DialogDateFormat")
        self.Passport_Address_EditTemporaryRegistration = getValue(dict, "Passport.Address.EditTemporaryRegistration")
        self.ReportPeer_ReasonSpam = getValue(dict, "ReportPeer.ReasonSpam")
        self.Privacy_Calls_P2P = getValue(dict, "Privacy.Calls.P2P")
        self.Compose_TokenListPlaceholder = getValue(dict, "Compose.TokenListPlaceholder")
        self._PINNED_VIDEO = getValue(dict, "PINNED_VIDEO")
        self._PINNED_VIDEO_r = extractArgumentRanges(self._PINNED_VIDEO)
        self.StickerPacksSettings_Title = getValue(dict, "StickerPacksSettings.Title")
        self.Privacy_PaymentsClearInfoDoneHelp = getValue(dict, "Privacy.PaymentsClearInfoDoneHelp")
        self.Privacy_Calls_NeverAllow_Placeholder = getValue(dict, "Privacy.Calls.NeverAllow.Placeholder")
        self.Passport_PassportInformation = getValue(dict, "Passport.PassportInformation")
        self.Passport_Identity_OneOfTypeDriversLicense = getValue(dict, "Passport.Identity.OneOfTypeDriversLicense")
        self.Settings_Support = getValue(dict, "Settings.Support")
        self.Notification_GroupInviterSelf = getValue(dict, "Notification.GroupInviterSelf")
        self._SecretImage_NotViewedYet = getValue(dict, "SecretImage.NotViewedYet")
        self._SecretImage_NotViewedYet_r = extractArgumentRanges(self._SecretImage_NotViewedYet)
        self.MaskStickerSettings_Title = getValue(dict, "MaskStickerSettings.Title")
        self.TwoStepAuth_SetPassword = getValue(dict, "TwoStepAuth.SetPassword")
        self._Passport_AcceptHelp = getValue(dict, "Passport.AcceptHelp")
        self._Passport_AcceptHelp_r = extractArgumentRanges(self._Passport_AcceptHelp)
        self.SocksProxySetup_SavedProxies = getValue(dict, "SocksProxySetup.SavedProxies")
        self.GroupInfo_InviteLink_ShareLink = getValue(dict, "GroupInfo.InviteLink.ShareLink")
        self.Common_Cancel = getValue(dict, "Common.Cancel")
        self.UserInfo_About_Placeholder = getValue(dict, "UserInfo.About.Placeholder")
        self.Passport_Identity_NativeNameGenericTitle = getValue(dict, "Passport.Identity.NativeNameGenericTitle")
        self.Camera_Discard = getValue(dict, "Camera.Discard")
        self.ChangePhoneNumberCode_RequestingACall = getValue(dict, "ChangePhoneNumberCode.RequestingACall")
        self.PrivacyLastSeenSettings_NeverShareWith_Title = getValue(dict, "PrivacyLastSeenSettings.NeverShareWith.Title")
        self.KeyCommand_JumpToNextChat = getValue(dict, "KeyCommand.JumpToNextChat")
        self._Time_MonthOfYear_m8 = getValue(dict, "Time.MonthOfYear_m8")
        self._Time_MonthOfYear_m8_r = extractArgumentRanges(self._Time_MonthOfYear_m8)
        self.Tour_Text1 = getValue(dict, "Tour.Text1")
        self.Privacy_SecretChatsTitle = getValue(dict, "Privacy.SecretChatsTitle")
        self.Conversation_HoldForVideo = getValue(dict, "Conversation.HoldForVideo")
        self.Passport_Language_pt = getValue(dict, "Passport.Language.pt")
        self.Checkout_NewCard_Title = getValue(dict, "Checkout.NewCard.Title")
        self.Channel_TitleInfo = getValue(dict, "Channel.TitleInfo")
        self.State_ConnectingToProxy = getValue(dict, "State.ConnectingToProxy")
        self.Settings_About_Help = getValue(dict, "Settings.About.Help")
        self.AutoNightTheme_ScheduledFrom = getValue(dict, "AutoNightTheme.ScheduledFrom")
        self.Passport_Language_tk = getValue(dict, "Passport.Language.tk")
        self.Watch_Conversation_Reply = getValue(dict, "Watch.Conversation.Reply")
        self.ShareMenu_CopyShareLink = getValue(dict, "ShareMenu.CopyShareLink")
        self.Stickers_Search = getValue(dict, "Stickers.Search")
        self.Notifications_GroupNotificationsExceptions = getValue(dict, "Notifications.GroupNotificationsExceptions")
        self.Channel_Setup_TypePrivateHelp = getValue(dict, "Channel.Setup.TypePrivateHelp")
        self.PhotoEditor_GrainTool = getValue(dict, "PhotoEditor.GrainTool")
        self.Conversation_SearchByName_Placeholder = getValue(dict, "Conversation.SearchByName.Placeholder")
        self.Watch_Suggestion_TalkLater = getValue(dict, "Watch.Suggestion.TalkLater")
        self.TwoStepAuth_ChangeEmail = getValue(dict, "TwoStepAuth.ChangeEmail")
        self.Passport_Identity_EditPersonalDetails = getValue(dict, "Passport.Identity.EditPersonalDetails")
        self.Passport_FieldPhone = getValue(dict, "Passport.FieldPhone")
        self._ENCRYPTION_ACCEPT = getValue(dict, "ENCRYPTION_ACCEPT")
        self._ENCRYPTION_ACCEPT_r = extractArgumentRanges(self._ENCRYPTION_ACCEPT)
        self.NetworkUsageSettings_BytesSent = getValue(dict, "NetworkUsageSettings.BytesSent")
        self.Conversation_ShareBotLocationConfirmationTitle = getValue(dict, "Conversation.ShareBotLocationConfirmationTitle")
        self.Conversation_ForwardContacts = getValue(dict, "Conversation.ForwardContacts")
        self._Notification_ChangedGroupName = getValue(dict, "Notification.ChangedGroupName")
        self._Notification_ChangedGroupName_r = extractArgumentRanges(self._Notification_ChangedGroupName)
        self._MESSAGE_VIDEO = getValue(dict, "MESSAGE_VIDEO")
        self._MESSAGE_VIDEO_r = extractArgumentRanges(self._MESSAGE_VIDEO)
        self._Checkout_PayPrice = getValue(dict, "Checkout.PayPrice")
        self._Checkout_PayPrice_r = extractArgumentRanges(self._Checkout_PayPrice)
        self._Notification_PinnedTextMessage = getValue(dict, "Notification.PinnedTextMessage")
        self._Notification_PinnedTextMessage_r = extractArgumentRanges(self._Notification_PinnedTextMessage)
        self.GroupInfo_InvitationLinkDoesNotExist = getValue(dict, "GroupInfo.InvitationLinkDoesNotExist")
        self.ReportPeer_ReasonOther_Placeholder = getValue(dict, "ReportPeer.ReasonOther.Placeholder")
        self.Wallpaper_Title = getValue(dict, "Wallpaper.Title")
        self.PasscodeSettings_AutoLock_Disabled = getValue(dict, "PasscodeSettings.AutoLock.Disabled")
        self.Watch_Compose_CreateMessage = getValue(dict, "Watch.Compose.CreateMessage")
        self.ChatSettings_ConnectionType_UseProxy = getValue(dict, "ChatSettings.ConnectionType.UseProxy")
        self.Message_Audio = getValue(dict, "Message.Audio")
        self.Conversation_SearchNoResults = getValue(dict, "Conversation.SearchNoResults")
        self.PrivacyPolicy_Accept = getValue(dict, "PrivacyPolicy.Accept")
        self.ReportPeer_ReasonViolence = getValue(dict, "ReportPeer.ReasonViolence")
        self.Group_Username_RemoveExistingUsernamesInfo = getValue(dict, "Group.Username.RemoveExistingUsernamesInfo")
        self.Message_InvoiceLabel = getValue(dict, "Message.InvoiceLabel")
        self.Channel_AdminLogFilter_Title = getValue(dict, "Channel.AdminLogFilter.Title")
        self.Contacts_SearchLabel = getValue(dict, "Contacts.SearchLabel")
        self.Group_Username_InvalidStartsWithNumber = getValue(dict, "Group.Username.InvalidStartsWithNumber")
        self.ChatAdmins_AllMembersAreAdminsOnHelp = getValue(dict, "ChatAdmins.AllMembersAreAdminsOnHelp")
        self.Month_ShortSeptember = getValue(dict, "Month.ShortSeptember")
        self.Group_Username_CreatePublicLinkHelp = getValue(dict, "Group.Username.CreatePublicLinkHelp")
        self.Login_CallRequestState2 = getValue(dict, "Login.CallRequestState2")
        self.TwoStepAuth_RecoveryUnavailable = getValue(dict, "TwoStepAuth.RecoveryUnavailable")
        self.Bot_Unblock = getValue(dict, "Bot.Unblock")
        self.SharedMedia_CategoryMedia = getValue(dict, "SharedMedia.CategoryMedia")
        self.Conversation_HoldForAudio = getValue(dict, "Conversation.HoldForAudio")
        self.Conversation_ClousStorageInfo_Description1 = getValue(dict, "Conversation.ClousStorageInfo.Description1")
        self.Channel_Members_InviteLink = getValue(dict, "Channel.Members.InviteLink")
        self.Core_ServiceUserStatus = getValue(dict, "Core.ServiceUserStatus")
        self.WebSearch_RecentClearConfirmation = getValue(dict, "WebSearch.RecentClearConfirmation")
        self.Notification_ChannelMigratedFrom = getValue(dict, "Notification.ChannelMigratedFrom")
        self.Settings_Title = getValue(dict, "Settings.Title")
        self.Call_StatusBusy = getValue(dict, "Call.StatusBusy")
        self.ArchivedPacksAlert_Title = getValue(dict, "ArchivedPacksAlert.Title")
        self.ConversationMedia_Title = getValue(dict, "ConversationMedia.Title")
        self._Conversation_MessageViaUser = getValue(dict, "Conversation.MessageViaUser")
        self._Conversation_MessageViaUser_r = extractArgumentRanges(self._Conversation_MessageViaUser)
        self.Notification_PassportValueAddress = getValue(dict, "Notification.PassportValueAddress")
        self.Tour_Title4 = getValue(dict, "Tour.Title4")
        self.Call_StatusEnded = getValue(dict, "Call.StatusEnded")
        self.LiveLocationUpdated_JustNow = getValue(dict, "LiveLocationUpdated.JustNow")
        self._Login_BannedPhoneSubject = getValue(dict, "Login.BannedPhoneSubject")
        self._Login_BannedPhoneSubject_r = extractArgumentRanges(self._Login_BannedPhoneSubject)
        self.Passport_Address_EditResidentialAddress = getValue(dict, "Passport.Address.EditResidentialAddress")
        self._Channel_Management_RestrictedBy = getValue(dict, "Channel.Management.RestrictedBy")
        self._Channel_Management_RestrictedBy_r = extractArgumentRanges(self._Channel_Management_RestrictedBy)
        self.Conversation_UnpinMessageAlert = getValue(dict, "Conversation.UnpinMessageAlert")
        self.NotificationsSound_Glass = getValue(dict, "NotificationsSound.Glass")
        self.Passport_Address_Street1Placeholder = getValue(dict, "Passport.Address.Street1Placeholder")
        self._Conversation_MessageDialogRetryAll = getValue(dict, "Conversation.MessageDialogRetryAll")
        self._Conversation_MessageDialogRetryAll_r = extractArgumentRanges(self._Conversation_MessageDialogRetryAll)
        self._Checkout_PasswordEntry_Text = getValue(dict, "Checkout.PasswordEntry.Text")
        self._Checkout_PasswordEntry_Text_r = extractArgumentRanges(self._Checkout_PasswordEntry_Text)
        self.Call_Message = getValue(dict, "Call.Message")
        self.Contacts_MemberSearchSectionTitleGroup = getValue(dict, "Contacts.MemberSearchSectionTitleGroup")
        self._Conversation_BotInteractiveUrlAlert = getValue(dict, "Conversation.BotInteractiveUrlAlert")
        self._Conversation_BotInteractiveUrlAlert_r = extractArgumentRanges(self._Conversation_BotInteractiveUrlAlert)
        self.GroupInfo_SharedMedia = getValue(dict, "GroupInfo.SharedMedia")
        self._Time_PreciseDate_m6 = getValue(dict, "Time.PreciseDate_m6")
        self._Time_PreciseDate_m6_r = extractArgumentRanges(self._Time_PreciseDate_m6)
        self.Channel_Username_InvalidStartsWithNumber = getValue(dict, "Channel.Username.InvalidStartsWithNumber")
        self.KeyCommand_JumpToPreviousChat = getValue(dict, "KeyCommand.JumpToPreviousChat")
        self.Conversation_Call = getValue(dict, "Conversation.Call")
        self.KeyCommand_ScrollUp = getValue(dict, "KeyCommand.ScrollUp")
        self._Privacy_GroupsAndChannels_InviteToChannelError = getValue(dict, "Privacy.GroupsAndChannels.InviteToChannelError")
        self._Privacy_GroupsAndChannels_InviteToChannelError_r = extractArgumentRanges(self._Privacy_GroupsAndChannels_InviteToChannelError)
        self.AuthSessions_Sessions = getValue(dict, "AuthSessions.Sessions")
        self.Document_TargetConfirmationFormat = getValue(dict, "Document.TargetConfirmationFormat")
        self.Group_Setup_TypeHeader = getValue(dict, "Group.Setup.TypeHeader")
        self._DialogList_SinglePlayingGameSuffix = getValue(dict, "DialogList.SinglePlayingGameSuffix")
        self._DialogList_SinglePlayingGameSuffix_r = extractArgumentRanges(self._DialogList_SinglePlayingGameSuffix)
        self.AttachmentMenu_SendAsFiles = getValue(dict, "AttachmentMenu.SendAsFiles")
        self.Profile_MessageLifetime1m = getValue(dict, "Profile.MessageLifetime1m")
        self.Passport_PasswordReset = getValue(dict, "Passport.PasswordReset")
        self.Settings_AppleWatch = getValue(dict, "Settings.AppleWatch")
        self.Notifications_ExceptionsTitle = getValue(dict, "Notifications.ExceptionsTitle")
        self.Passport_Language_de = getValue(dict, "Passport.Language.de")
        self.Channel_AdminLog_MessagePreviousDescription = getValue(dict, "Channel.AdminLog.MessagePreviousDescription")
        self.Your_card_was_declined = getValue(dict, "Your_card_was_declined")
        self.PhoneNumberHelp_ChangeNumber = getValue(dict, "PhoneNumberHelp.ChangeNumber")
        self.ReportPeer_ReasonPornography = getValue(dict, "ReportPeer.ReasonPornography")
        self.Notification_CreatedChannel = getValue(dict, "Notification.CreatedChannel")
        self.PhotoEditor_Original = getValue(dict, "PhotoEditor.Original")
        self.NotificationsSound_Chord = getValue(dict, "NotificationsSound.Chord")
        self.Target_SelectGroup = getValue(dict, "Target.SelectGroup")
        self.Stickers_SuggestAdded = getValue(dict, "Stickers.SuggestAdded")
        self.Channel_AdminLog_InfoPanelAlertTitle = getValue(dict, "Channel.AdminLog.InfoPanelAlertTitle")
        self.Notifications_GroupNotificationsPreview = getValue(dict, "Notifications.GroupNotificationsPreview")
        self.ChatSettings_AutoDownloadPhotos = getValue(dict, "ChatSettings.AutoDownloadPhotos")
        self.Message_PinnedLocationMessage = getValue(dict, "Message.PinnedLocationMessage")
        self.Appearance_PreviewReplyText = getValue(dict, "Appearance.PreviewReplyText")
        self.Passport_Address_Street2Placeholder = getValue(dict, "Passport.Address.Street2Placeholder")
        self.Settings_Logout = getValue(dict, "Settings.Logout")
        self._UserInfo_BlockConfirmation = getValue(dict, "UserInfo.BlockConfirmation")
        self._UserInfo_BlockConfirmation_r = extractArgumentRanges(self._UserInfo_BlockConfirmation)
        self.Profile_Username = getValue(dict, "Profile.Username")
        self.Group_Username_InvalidTooShort = getValue(dict, "Group.Username.InvalidTooShort")
        self.Appearance_AutoNightTheme = getValue(dict, "Appearance.AutoNightTheme")
        self.AuthSessions_TerminateOtherSessions = getValue(dict, "AuthSessions.TerminateOtherSessions")
        self.PasscodeSettings_TryAgainIn1Minute = getValue(dict, "PasscodeSettings.TryAgainIn1Minute")
        self.Privacy_TopPeers = getValue(dict, "Privacy.TopPeers")
        self.Passport_Phone_EnterOtherNumber = getValue(dict, "Passport.Phone.EnterOtherNumber")
        self.NotificationsSound_Hello = getValue(dict, "NotificationsSound.Hello")
        self.Notifications_InAppNotifications = getValue(dict, "Notifications.InAppNotifications")
        self._Notification_PassportValuesSentMessage = getValue(dict, "Notification.PassportValuesSentMessage")
        self._Notification_PassportValuesSentMessage_r = extractArgumentRanges(self._Notification_PassportValuesSentMessage)
        self.Passport_Language_is = getValue(dict, "Passport.Language.is")
        self.StickerPack_ViewPack = getValue(dict, "StickerPack.ViewPack")
        self.EnterPasscode_ChangeTitle = getValue(dict, "EnterPasscode.ChangeTitle")
        self.Call_Decline = getValue(dict, "Call.Decline")
        self.UserInfo_AddPhone = getValue(dict, "UserInfo.AddPhone")
        self.AutoNightTheme_Title = getValue(dict, "AutoNightTheme.Title")
        self.Activity_PlayingGame = getValue(dict, "Activity.PlayingGame")
        self.CheckoutInfo_ShippingInfoStatePlaceholder = getValue(dict, "CheckoutInfo.ShippingInfoStatePlaceholder")
        self.SaveIncomingPhotosSettings_From = getValue(dict, "SaveIncomingPhotosSettings.From")
        self.Passport_Address_TypeBankStatementUploadScan = getValue(dict, "Passport.Address.TypeBankStatementUploadScan")
        self.Notifications_MessageNotificationsSound = getValue(dict, "Notifications.MessageNotificationsSound")
        self.Call_StatusWaiting = getValue(dict, "Call.StatusWaiting")
        self.Passport_Identity_MainPageHelp = getValue(dict, "Passport.Identity.MainPageHelp")
        self.Weekday_ShortWednesday = getValue(dict, "Weekday.ShortWednesday")
        self.Notifications_Title = getValue(dict, "Notifications.Title")
        self.PasscodeSettings_AutoLock_IfAwayFor_5hours = getValue(dict, "PasscodeSettings.AutoLock.IfAwayFor_5hours")
        self.Conversation_PinnedMessage = getValue(dict, "Conversation.PinnedMessage")
        self.Channel_AdminLog_MessagePreviousMessage = getValue(dict, "Channel.AdminLog.MessagePreviousMessage")
        self._Time_MonthOfYear_m12 = getValue(dict, "Time.MonthOfYear_m12")
        self._Time_MonthOfYear_m12_r = extractArgumentRanges(self._Time_MonthOfYear_m12)
        self.ConversationProfile_LeaveDeleteAndExit = getValue(dict, "ConversationProfile.LeaveDeleteAndExit")
        self.State_connecting = getValue(dict, "State.connecting")
        self.Passport_Scans_Upload = getValue(dict, "Passport.Scans.Upload")
        self.Passport_Identity_FrontSideHelp = getValue(dict, "Passport.Identity.FrontSideHelp")
        self.AutoDownloadSettings_PhotosTitle = getValue(dict, "AutoDownloadSettings.PhotosTitle")
        self.Map_OpenInHereMaps = getValue(dict, "Map.OpenInHereMaps")
        self.Stickers_FavoriteStickers = getValue(dict, "Stickers.FavoriteStickers")
        self.CheckoutInfo_Pay = getValue(dict, "CheckoutInfo.Pay")
        self.Update_UpdateApp = getValue(dict, "Update.UpdateApp")
        self.Login_CountryCode = getValue(dict, "Login.CountryCode")
        self.PasscodeSettings_AutoLock_IfAwayFor_1hour = getValue(dict, "PasscodeSettings.AutoLock.IfAwayFor_1hour")
        self.CheckoutInfo_ShippingInfoState = getValue(dict, "CheckoutInfo.ShippingInfoState")
        self._CHAT_MESSAGE_AUDIO = getValue(dict, "CHAT_MESSAGE_AUDIO")
        self._CHAT_MESSAGE_AUDIO_r = extractArgumentRanges(self._CHAT_MESSAGE_AUDIO)
        self.Login_SmsRequestState2 = getValue(dict, "Login.SmsRequestState2")
        self.Preview_SaveToCameraRoll = getValue(dict, "Preview.SaveToCameraRoll")
        self.SocksProxySetup_ProxyStatusConnecting = getValue(dict, "SocksProxySetup.ProxyStatusConnecting")
        self.Broadcast_AdminLog_EmptyText = getValue(dict, "Broadcast.AdminLog.EmptyText")
        self.PasscodeSettings_ChangePasscode = getValue(dict, "PasscodeSettings.ChangePasscode")
        self.TwoStepAuth_RecoveryCodeInvalid = getValue(dict, "TwoStepAuth.RecoveryCodeInvalid")
        self._Message_PaymentSent = getValue(dict, "Message.PaymentSent")
        self._Message_PaymentSent_r = extractArgumentRanges(self._Message_PaymentSent)
        self.Message_PinnedAudioMessage = getValue(dict, "Message.PinnedAudioMessage")
        self.ChatSettings_ConnectionType_Title = getValue(dict, "ChatSettings.ConnectionType.Title")
        self._Conversation_RestrictedMediaTimed = getValue(dict, "Conversation.RestrictedMediaTimed")
        self._Conversation_RestrictedMediaTimed_r = extractArgumentRanges(self._Conversation_RestrictedMediaTimed)
        self.NotificationsSound_Complete = getValue(dict, "NotificationsSound.Complete")
        self.NotificationsSound_Chime = getValue(dict, "NotificationsSound.Chime")
        self.Login_InfoDeletePhoto = getValue(dict, "Login.InfoDeletePhoto")
        self.ContactInfo_BirthdayLabel = getValue(dict, "ContactInfo.BirthdayLabel")
        self.TwoStepAuth_RecoveryCodeExpired = getValue(dict, "TwoStepAuth.RecoveryCodeExpired")
        self.AutoDownloadSettings_Channels = getValue(dict, "AutoDownloadSettings.Channels")
        self.AutoDownloadSettings_Contacts = getValue(dict, "AutoDownloadSettings.Contacts")
        self.TwoStepAuth_EmailTitle = getValue(dict, "TwoStepAuth.EmailTitle")
        self.Passport_Email_EmailPlaceholder = getValue(dict, "Passport.Email.EmailPlaceholder")
        self.Channel_AdminLog_ChannelEmptyText = getValue(dict, "Channel.AdminLog.ChannelEmptyText")
        self.Passport_Address_EditUtilityBill = getValue(dict, "Passport.Address.EditUtilityBill")
        self.Privacy_GroupsAndChannels_NeverAllow = getValue(dict, "Privacy.GroupsAndChannels.NeverAllow")
        self.Conversation_RestrictedStickers = getValue(dict, "Conversation.RestrictedStickers")
        self.Conversation_AddContact = getValue(dict, "Conversation.AddContact")
        self._Time_MonthOfYear_m7 = getValue(dict, "Time.MonthOfYear_m7")
        self._Time_MonthOfYear_m7_r = extractArgumentRanges(self._Time_MonthOfYear_m7)
        self.PhotoEditor_QualityLow = getValue(dict, "PhotoEditor.QualityLow")
        self.Paint_Outlined = getValue(dict, "Paint.Outlined")
        self.State_ConnectingToProxyInfo = getValue(dict, "State.ConnectingToProxyInfo")
        self.Checkout_PasswordEntry_Title = getValue(dict, "Checkout.PasswordEntry.Title")
        self.Conversation_InputTextCaptionPlaceholder = getValue(dict, "Conversation.InputTextCaptionPlaceholder")
        self.Common_Done = getValue(dict, "Common.Done")
        self.Passport_Identity_FilesUploadNew = getValue(dict, "Passport.Identity.FilesUploadNew")
        self.PrivacySettings_LastSeenContacts = getValue(dict, "PrivacySettings.LastSeenContacts")
        self.Passport_Language_vi = getValue(dict, "Passport.Language.vi")
        self.CheckoutInfo_ShippingInfoAddress1 = getValue(dict, "CheckoutInfo.ShippingInfoAddress1")
        self.UserInfo_LastNamePlaceholder = getValue(dict, "UserInfo.LastNamePlaceholder")
        self.Conversation_StatusKickedFromChannel = getValue(dict, "Conversation.StatusKickedFromChannel")
        self.CheckoutInfo_ShippingInfoAddress2 = getValue(dict, "CheckoutInfo.ShippingInfoAddress2")
        self._DialogList_SingleTypingSuffix = getValue(dict, "DialogList.SingleTypingSuffix")
        self._DialogList_SingleTypingSuffix_r = extractArgumentRanges(self._DialogList_SingleTypingSuffix)
        self.LastSeen_JustNow = getValue(dict, "LastSeen.JustNow")
        self.GroupInfo_InviteLink_RevokeAlert_Text = getValue(dict, "GroupInfo.InviteLink.RevokeAlert.Text")
        self.BroadcastListInfo_AddRecipient = getValue(dict, "BroadcastListInfo.AddRecipient")
        self._Channel_Management_ErrorNotMember = getValue(dict, "Channel.Management.ErrorNotMember")
        self._Channel_Management_ErrorNotMember_r = extractArgumentRanges(self._Channel_Management_ErrorNotMember)
        self.Privacy_Calls_NeverAllow = getValue(dict, "Privacy.Calls.NeverAllow")
        self.Settings_About_Title = getValue(dict, "Settings.About.Title")
        self.PhoneNumberHelp_Help = getValue(dict, "PhoneNumberHelp.Help")
        self.Channel_LinkItem = getValue(dict, "Channel.LinkItem")
        self.Camera_Retake = getValue(dict, "Camera.Retake")
        self.StickerPack_ShowStickers = getValue(dict, "StickerPack.ShowStickers")
        self.Conversation_RestrictedText = getValue(dict, "Conversation.RestrictedText")
        self.Channel_Stickers_YourStickers = getValue(dict, "Channel.Stickers.YourStickers")
        self._CHAT_CREATED = getValue(dict, "CHAT_CREATED")
        self._CHAT_CREATED_r = extractArgumentRanges(self._CHAT_CREATED)
        self.LastSeen_WithinAMonth = getValue(dict, "LastSeen.WithinAMonth")
        self._PrivacySettings_LastSeenContactsPlus = getValue(dict, "PrivacySettings.LastSeenContactsPlus")
        self._PrivacySettings_LastSeenContactsPlus_r = extractArgumentRanges(self._PrivacySettings_LastSeenContactsPlus)
        self.ChangePhoneNumberNumber_NewNumber = getValue(dict, "ChangePhoneNumberNumber.NewNumber")
        self.Compose_NewChannel = getValue(dict, "Compose.NewChannel")
        self.NotificationsSound_Circles = getValue(dict, "NotificationsSound.Circles")
        self.Login_TermsOfServiceAgree = getValue(dict, "Login.TermsOfServiceAgree")
        self.Channel_AdminLog_CanChangeInviteLink = getValue(dict, "Channel.AdminLog.CanChangeInviteLink")
        self._Passport_RequestHeader = getValue(dict, "Passport.RequestHeader")
        self._Passport_RequestHeader_r = extractArgumentRanges(self._Passport_RequestHeader)
        self._Call_CallInProgressMessage = getValue(dict, "Call.CallInProgressMessage")
        self._Call_CallInProgressMessage_r = extractArgumentRanges(self._Call_CallInProgressMessage)
        self.Conversation_InputTextBroadcastPlaceholder = getValue(dict, "Conversation.InputTextBroadcastPlaceholder")
        self._ShareFileTip_Text = getValue(dict, "ShareFileTip.Text")
        self._ShareFileTip_Text_r = extractArgumentRanges(self._ShareFileTip_Text)
        self._CancelResetAccount_TextSMS = getValue(dict, "CancelResetAccount.TextSMS")
        self._CancelResetAccount_TextSMS_r = extractArgumentRanges(self._CancelResetAccount_TextSMS)
        self.Channel_EditAdmin_PermissionInviteUsers = getValue(dict, "Channel.EditAdmin.PermissionInviteUsers")
        self.Privacy_Calls_P2PNever = getValue(dict, "Privacy.Calls.P2PNever")
        self.GroupInfo_DeleteAndExit = getValue(dict, "GroupInfo.DeleteAndExit")
        self.GroupInfo_InviteLink_CopyLink = getValue(dict, "GroupInfo.InviteLink.CopyLink")
        self.Login_ResetAccountProtected_Title = getValue(dict, "Login.ResetAccountProtected.Title")
        self.Settings_SetProfilePhoto = getValue(dict, "Settings.SetProfilePhoto")
        self.Compose_ChannelTokenListPlaceholder = getValue(dict, "Compose.ChannelTokenListPlaceholder")
        self.Channel_EditAdmin_PermissionPinMessages = getValue(dict, "Channel.EditAdmin.PermissionPinMessages")
        self.Your_card_has_expired = getValue(dict, "Your_card_has_expired")
        self._CHAT_MESSAGE_INVOICE = getValue(dict, "CHAT_MESSAGE_INVOICE")
        self._CHAT_MESSAGE_INVOICE_r = extractArgumentRanges(self._CHAT_MESSAGE_INVOICE)
        self.ChannelInfo_ConfirmLeave = getValue(dict, "ChannelInfo.ConfirmLeave")
        self.ShareMenu_CopyShareLinkGame = getValue(dict, "ShareMenu.CopyShareLinkGame")
        self.ReportPeer_ReasonOther = getValue(dict, "ReportPeer.ReasonOther")
        self._Username_UsernameIsAvailable = getValue(dict, "Username.UsernameIsAvailable")
        self._Username_UsernameIsAvailable_r = extractArgumentRanges(self._Username_UsernameIsAvailable)
        self.KeyCommand_JumpToNextUnreadChat = getValue(dict, "KeyCommand.JumpToNextUnreadChat")
        self.InfoPlist_NSContactsUsageDescription = getValue(dict, "InfoPlist.NSContactsUsageDescription")
        self._SocksProxySetup_ProxyStatusPing = getValue(dict, "SocksProxySetup.ProxyStatusPing")
        self._SocksProxySetup_ProxyStatusPing_r = extractArgumentRanges(self._SocksProxySetup_ProxyStatusPing)
        self._Date_ChatDateHeader = getValue(dict, "Date.ChatDateHeader")
        self._Date_ChatDateHeader_r = extractArgumentRanges(self._Date_ChatDateHeader)
        self.Conversation_EncryptedDescriptionTitle = getValue(dict, "Conversation.EncryptedDescriptionTitle")
        self.DialogList_Pin = getValue(dict, "DialogList.Pin")
        self._Notification_RemovedGroupPhoto = getValue(dict, "Notification.RemovedGroupPhoto")
        self._Notification_RemovedGroupPhoto_r = extractArgumentRanges(self._Notification_RemovedGroupPhoto)
        self.Channel_ErrorAddTooMuch = getValue(dict, "Channel.ErrorAddTooMuch")
        self.GroupInfo_SharedMediaNone = getValue(dict, "GroupInfo.SharedMediaNone")
        self.ChatSettings_TextSizeUnits = getValue(dict, "ChatSettings.TextSizeUnits")
        self.ChatSettings_AutoPlayAnimations = getValue(dict, "ChatSettings.AutoPlayAnimations")
        self.Conversation_FileOpenIn = getValue(dict, "Conversation.FileOpenIn")
        self.Channel_Setup_TypePublic = getValue(dict, "Channel.Setup.TypePublic")
        self._ChangePhone_ErrorOccupied = getValue(dict, "ChangePhone.ErrorOccupied")
        self._ChangePhone_ErrorOccupied_r = extractArgumentRanges(self._ChangePhone_ErrorOccupied)
        self.ContactInfo_PhoneLabelMain = getValue(dict, "ContactInfo.PhoneLabelMain")
        self.Clipboard_SendPhoto = getValue(dict, "Clipboard.SendPhoto")
        self.Privacy_GroupsAndChannels_CustomShareHelp = getValue(dict, "Privacy.GroupsAndChannels.CustomShareHelp")
        self.KeyCommand_ChatInfo = getValue(dict, "KeyCommand.ChatInfo")
        self.Channel_AdminLog_EmptyFilterTitle = getValue(dict, "Channel.AdminLog.EmptyFilterTitle")
        self.PhotoEditor_HighlightsTint = getValue(dict, "PhotoEditor.HighlightsTint")
        self.Passport_Address_Region = getValue(dict, "Passport.Address.Region")
        self.Watch_Compose_AddContact = getValue(dict, "Watch.Compose.AddContact")
        self._Time_PreciseDate_m5 = getValue(dict, "Time.PreciseDate_m5")
        self._Time_PreciseDate_m5_r = extractArgumentRanges(self._Time_PreciseDate_m5)
        self._Channel_AdminLog_MessageKickedNameUsername = getValue(dict, "Channel.AdminLog.MessageKickedNameUsername")
        self._Channel_AdminLog_MessageKickedNameUsername_r = extractArgumentRanges(self._Channel_AdminLog_MessageKickedNameUsername)
        self.Coub_TapForSound = getValue(dict, "Coub.TapForSound")
        self.Compose_NewEncryptedChat = getValue(dict, "Compose.NewEncryptedChat")
        self.PhotoEditor_CropReset = getValue(dict, "PhotoEditor.CropReset")
        self.Privacy_Calls_P2PAlways = getValue(dict, "Privacy.Calls.P2PAlways")
        self.Passport_Address_TypeTemporaryRegistrationUploadScan = getValue(dict, "Passport.Address.TypeTemporaryRegistrationUploadScan")
        self.Login_InvalidLastNameError = getValue(dict, "Login.InvalidLastNameError")
        self.Channel_Members_AddMembers = getValue(dict, "Channel.Members.AddMembers")
        self.Tour_Title2 = getValue(dict, "Tour.Title2")
        self.Login_TermsOfServiceHeader = getValue(dict, "Login.TermsOfServiceHeader")
        self.Channel_AdminLog_BanSendGifs = getValue(dict, "Channel.AdminLog.BanSendGifs")
        self.Login_TermsOfServiceSignupDecline = getValue(dict, "Login.TermsOfServiceSignupDecline")
        self.InfoPlist_NSMicrophoneUsageDescription = getValue(dict, "InfoPlist.NSMicrophoneUsageDescription")
        self.AuthSessions_OtherSessions = getValue(dict, "AuthSessions.OtherSessions")
        self.Watch_UserInfo_Title = getValue(dict, "Watch.UserInfo.Title")
        self.InstantPage_FeedbackButton = getValue(dict, "InstantPage.FeedbackButton")
        self._Generic_OpenHiddenLinkAlert = getValue(dict, "Generic.OpenHiddenLinkAlert")
        self._Generic_OpenHiddenLinkAlert_r = extractArgumentRanges(self._Generic_OpenHiddenLinkAlert)
        self.Conversation_Contact = getValue(dict, "Conversation.Contact")
        self.NetworkUsageSettings_GeneralDataSection = getValue(dict, "NetworkUsageSettings.GeneralDataSection")
        self.EnterPasscode_RepeatNewPasscode = getValue(dict, "EnterPasscode.RepeatNewPasscode")
        self.Conversation_ContextMenuCopyLink = getValue(dict, "Conversation.ContextMenuCopyLink")
        self.Passport_Language_sk = getValue(dict, "Passport.Language.sk")
        self.InstantPage_AutoNightTheme = getValue(dict, "InstantPage.AutoNightTheme")
        self.CloudStorage_Title = getValue(dict, "CloudStorage.Title")
        self.Month_ShortOctober = getValue(dict, "Month.ShortOctober")
        self.Settings_FAQ = getValue(dict, "Settings.FAQ")
        self.PrivacySettings_LastSeen = getValue(dict, "PrivacySettings.LastSeen")
        self.DialogList_SearchSectionRecent = getValue(dict, "DialogList.SearchSectionRecent")
        self.ChatSettings_AutomaticVideoMessageDownload = getValue(dict, "ChatSettings.AutomaticVideoMessageDownload")
        self.Conversation_ContextMenuDelete = getValue(dict, "Conversation.ContextMenuDelete")
        self.Tour_Text6 = getValue(dict, "Tour.Text6")
        self.PhotoEditor_WarmthTool = getValue(dict, "PhotoEditor.WarmthTool")
        self.Passport_Address_TypePassportRegistrationUploadScan = getValue(dict, "Passport.Address.TypePassportRegistrationUploadScan")
        self.Common_TakePhoto = getValue(dict, "Common.TakePhoto")
        self.SocksProxySetup_AdNoticeHelp = getValue(dict, "SocksProxySetup.AdNoticeHelp")
        self.UserInfo_CreateNewContact = getValue(dict, "UserInfo.CreateNewContact")
        self.NetworkUsageSettings_MediaDocumentDataSection = getValue(dict, "NetworkUsageSettings.MediaDocumentDataSection")
        self.Login_CodeSentCall = getValue(dict, "Login.CodeSentCall")
        self.Watch_PhotoView_Title = getValue(dict, "Watch.PhotoView.Title")
        self._PrivacySettings_LastSeenContactsMinus = getValue(dict, "PrivacySettings.LastSeenContactsMinus")
        self._PrivacySettings_LastSeenContactsMinus_r = extractArgumentRanges(self._PrivacySettings_LastSeenContactsMinus)
        self.ShareMenu_SelectChats = getValue(dict, "ShareMenu.SelectChats")
        self.Group_ErrorSendRestrictedMedia = getValue(dict, "Group.ErrorSendRestrictedMedia")
        self.Group_Setup_HistoryVisible = getValue(dict, "Group.Setup.HistoryVisible")
        self.Channel_EditAdmin_PermissinAddAdminOff = getValue(dict, "Channel.EditAdmin.PermissinAddAdminOff")
        self.DialogList_ProxyConnectionIssuesTooltip = getValue(dict, "DialogList.ProxyConnectionIssuesTooltip")
        self.Cache_Files = getValue(dict, "Cache.Files")
        self.PhotoEditor_EnhanceTool = getValue(dict, "PhotoEditor.EnhanceTool")
        self.Conversation_SearchPlaceholder = getValue(dict, "Conversation.SearchPlaceholder")
        self.Channel_Stickers_NotFound = getValue(dict, "Channel.Stickers.NotFound")
        self.UserInfo_NotificationsDefaultEnabled = getValue(dict, "UserInfo.NotificationsDefaultEnabled")
        self.WatchRemote_AlertText = getValue(dict, "WatchRemote.AlertText")
        self.Channel_AdminLog_CanInviteUsers = getValue(dict, "Channel.AdminLog.CanInviteUsers")
        self.Channel_BanUser_PermissionReadMessages = getValue(dict, "Channel.BanUser.PermissionReadMessages")
        self.AttachmentMenu_PhotoOrVideo = getValue(dict, "AttachmentMenu.PhotoOrVideo")
        self.Passport_Identity_GenderPlaceholder = getValue(dict, "Passport.Identity.GenderPlaceholder")
        self.Month_ShortMarch = getValue(dict, "Month.ShortMarch")
        self.GroupInfo_InviteLink_Title = getValue(dict, "GroupInfo.InviteLink.Title")
        self.Watch_LastSeen_JustNow = getValue(dict, "Watch.LastSeen.JustNow")
        self.PhoneLabel_Title = getValue(dict, "PhoneLabel.Title")
        self.PrivacySettings_Passcode = getValue(dict, "PrivacySettings.Passcode")
        self.Paint_ClearConfirm = getValue(dict, "Paint.ClearConfirm")
        self.SocksProxySetup_Secret = getValue(dict, "SocksProxySetup.Secret")
        self._Checkout_SavePasswordTimeout = getValue(dict, "Checkout.SavePasswordTimeout")
        self._Checkout_SavePasswordTimeout_r = extractArgumentRanges(self._Checkout_SavePasswordTimeout)
        self.PhotoEditor_BlurToolOff = getValue(dict, "PhotoEditor.BlurToolOff")
        self.AccessDenied_VideoMicrophone = getValue(dict, "AccessDenied.VideoMicrophone")
        self.Weekday_ShortThursday = getValue(dict, "Weekday.ShortThursday")
        self.UserInfo_ShareContact = getValue(dict, "UserInfo.ShareContact")
        self.LoginPassword_InvalidPasswordError = getValue(dict, "LoginPassword.InvalidPasswordError")
        self.NotificationsSound_Calypso = getValue(dict, "NotificationsSound.Calypso")
        self._MESSAGE_PHOTO_SECRET = getValue(dict, "MESSAGE_PHOTO_SECRET")
        self._MESSAGE_PHOTO_SECRET_r = extractArgumentRanges(self._MESSAGE_PHOTO_SECRET)
        self.Login_PhoneAndCountryHelp = getValue(dict, "Login.PhoneAndCountryHelp")
        self.CheckoutInfo_ReceiverInfoName = getValue(dict, "CheckoutInfo.ReceiverInfoName")
        self.NotificationsSound_Popcorn = getValue(dict, "NotificationsSound.Popcorn")
        self._Time_YesterdayAt = getValue(dict, "Time.YesterdayAt")
        self._Time_YesterdayAt_r = extractArgumentRanges(self._Time_YesterdayAt)
        self.Weekday_Yesterday = getValue(dict, "Weekday.Yesterday")
        self.Conversation_InputTextSilentBroadcastPlaceholder = getValue(dict, "Conversation.InputTextSilentBroadcastPlaceholder")
        self.Embed_PlayingInPIP = getValue(dict, "Embed.PlayingInPIP")
        self.Localization_EnglishLanguageName = getValue(dict, "Localization.EnglishLanguageName")
        self.Call_StatusIncoming = getValue(dict, "Call.StatusIncoming")
        self.Settings_Appearance = getValue(dict, "Settings.Appearance")
        self.Settings_PrivacySettings = getValue(dict, "Settings.PrivacySettings")
        self.Conversation_SilentBroadcastTooltipOn = getValue(dict, "Conversation.SilentBroadcastTooltipOn")
        self._SecretVideo_NotViewedYet = getValue(dict, "SecretVideo.NotViewedYet")
        self._SecretVideo_NotViewedYet_r = extractArgumentRanges(self._SecretVideo_NotViewedYet)
        self._CHAT_MESSAGE_GEO = getValue(dict, "CHAT_MESSAGE_GEO")
        self._CHAT_MESSAGE_GEO_r = extractArgumentRanges(self._CHAT_MESSAGE_GEO)
        self.DialogList_SearchLabel = getValue(dict, "DialogList.SearchLabel")
        self.InfoPlist_NSLocationAlwaysAndWhenInUseUsageDescription = getValue(dict, "InfoPlist.NSLocationAlwaysAndWhenInUseUsageDescription")
        self.Login_CodeSentInternal = getValue(dict, "Login.CodeSentInternal")
        self.Channel_AdminLog_BanSendMessages = getValue(dict, "Channel.AdminLog.BanSendMessages")
        self.Channel_MessagePhotoRemoved = getValue(dict, "Channel.MessagePhotoRemoved")
        self.Conversation_StatusKickedFromGroup = getValue(dict, "Conversation.StatusKickedFromGroup")
        self.GroupInfo_ChatAdmins = getValue(dict, "GroupInfo.ChatAdmins")
        self.PhotoEditor_CurvesAll = getValue(dict, "PhotoEditor.CurvesAll")
        self._Notification_LeftChannel = getValue(dict, "Notification.LeftChannel")
        self._Notification_LeftChannel_r = extractArgumentRanges(self._Notification_LeftChannel)
        self.Compose_Create = getValue(dict, "Compose.Create")
        self._Passport_Identity_NativeNameGenericHelp = getValue(dict, "Passport.Identity.NativeNameGenericHelp")
        self._Passport_Identity_NativeNameGenericHelp_r = extractArgumentRanges(self._Passport_Identity_NativeNameGenericHelp)
        self._LOCKED_MESSAGE = getValue(dict, "LOCKED_MESSAGE")
        self._LOCKED_MESSAGE_r = extractArgumentRanges(self._LOCKED_MESSAGE)
        self.Conversation_ClearPrivateHistory = getValue(dict, "Conversation.ClearPrivateHistory")
        self.Conversation_ContextMenuShare = getValue(dict, "Conversation.ContextMenuShare")
        self.Notifications_ExceptionsNone = getValue(dict, "Notifications.ExceptionsNone")
        self._Time_MonthOfYear_m6 = getValue(dict, "Time.MonthOfYear_m6")
        self._Time_MonthOfYear_m6_r = extractArgumentRanges(self._Time_MonthOfYear_m6)
        self.Conversation_ContextMenuReport = getValue(dict, "Conversation.ContextMenuReport")
        self._Call_GroupFormat = getValue(dict, "Call.GroupFormat")
        self._Call_GroupFormat_r = extractArgumentRanges(self._Call_GroupFormat)
        self.Forward_ChannelReadOnly = getValue(dict, "Forward.ChannelReadOnly")
        self.Passport_InfoText = getValue(dict, "Passport.InfoText")
        self.Privacy_GroupsAndChannels_NeverAllow_Title = getValue(dict, "Privacy.GroupsAndChannels.NeverAllow.Title")
        self._Passport_Address_UploadOneOfScan = getValue(dict, "Passport.Address.UploadOneOfScan")
        self._Passport_Address_UploadOneOfScan_r = extractArgumentRanges(self._Passport_Address_UploadOneOfScan)
        self.AutoDownloadSettings_Reset = getValue(dict, "AutoDownloadSettings.Reset")
        self.NotificationsSound_Synth = getValue(dict, "NotificationsSound.Synth")
        self._Channel_AdminLog_MessageInvitedName = getValue(dict, "Channel.AdminLog.MessageInvitedName")
        self._Channel_AdminLog_MessageInvitedName_r = extractArgumentRanges(self._Channel_AdminLog_MessageInvitedName)
        self.Conversation_Moderate_Ban = getValue(dict, "Conversation.Moderate.Ban")
        self.Group_Status = getValue(dict, "Group.Status")
        self.SocksProxySetup_ShareProxyList = getValue(dict, "SocksProxySetup.ShareProxyList")
        self.Passport_Phone_Delete = getValue(dict, "Passport.Phone.Delete")
        self.Conversation_InputTextPlaceholder = getValue(dict, "Conversation.InputTextPlaceholder")
        self.ContactInfo_PhoneLabelOther = getValue(dict, "ContactInfo.PhoneLabelOther")
        self.Passport_Language_lv = getValue(dict, "Passport.Language.lv")
        self.TwoStepAuth_RecoveryCode = getValue(dict, "TwoStepAuth.RecoveryCode")
        self.Conversation_EditingMessageMediaEditCurrentPhoto = getValue(dict, "Conversation.EditingMessageMediaEditCurrentPhoto")
        self.Passport_DeleteDocumentConfirmation = getValue(dict, "Passport.DeleteDocumentConfirmation")
        self.Passport_Language_hy = getValue(dict, "Passport.Language.hy")
        self.SharedMedia_CategoryDocs = getValue(dict, "SharedMedia.CategoryDocs")
        self.Channel_AdminLog_CanChangeInfo = getValue(dict, "Channel.AdminLog.CanChangeInfo")
        self.Channel_AdminLogFilter_EventsAdmins = getValue(dict, "Channel.AdminLogFilter.EventsAdmins")
        self.Group_Setup_HistoryHiddenHelp = getValue(dict, "Group.Setup.HistoryHiddenHelp")
        self._AuthSessions_AppUnofficial = getValue(dict, "AuthSessions.AppUnofficial")
        self._AuthSessions_AppUnofficial_r = extractArgumentRanges(self._AuthSessions_AppUnofficial)
        self.NotificationsSound_Telegraph = getValue(dict, "NotificationsSound.Telegraph")
        self.AutoNightTheme_Disabled = getValue(dict, "AutoNightTheme.Disabled")
        self.Conversation_ContextMenuBan = getValue(dict, "Conversation.ContextMenuBan")
        self.Channel_EditAdmin_PermissionsHeader = getValue(dict, "Channel.EditAdmin.PermissionsHeader")
        self.SocksProxySetup_PortPlaceholder = getValue(dict, "SocksProxySetup.PortPlaceholder")
        self._DialogList_SingleUploadingVideoSuffix = getValue(dict, "DialogList.SingleUploadingVideoSuffix")
        self._DialogList_SingleUploadingVideoSuffix_r = extractArgumentRanges(self._DialogList_SingleUploadingVideoSuffix)
        self.Group_UpgradeNoticeHeader = getValue(dict, "Group.UpgradeNoticeHeader")
        self._CHAT_DELETE_YOU = getValue(dict, "CHAT_DELETE_YOU")
        self._CHAT_DELETE_YOU_r = extractArgumentRanges(self._CHAT_DELETE_YOU)
        self._MESSAGE_NOTEXT = getValue(dict, "MESSAGE_NOTEXT")
        self._MESSAGE_NOTEXT_r = extractArgumentRanges(self._MESSAGE_NOTEXT)
        self._CHAT_MESSAGE_GIF = getValue(dict, "CHAT_MESSAGE_GIF")
        self._CHAT_MESSAGE_GIF_r = extractArgumentRanges(self._CHAT_MESSAGE_GIF)
        self.GroupInfo_InviteLink_CopyAlert_Success = getValue(dict, "GroupInfo.InviteLink.CopyAlert.Success")
        self.Channel_Info_Members = getValue(dict, "Channel.Info.Members")
        self.ShareFileTip_CloseTip = getValue(dict, "ShareFileTip.CloseTip")
        self.KeyCommand_Find = getValue(dict, "KeyCommand.Find")
        self.SecretVideo_Title = getValue(dict, "SecretVideo.Title")
        self.Passport_DeleteAddressConfirmation = getValue(dict, "Passport.DeleteAddressConfirmation")
        self.Passport_DiscardMessageAction = getValue(dict, "Passport.DiscardMessageAction")
        self.Passport_Language_dv = getValue(dict, "Passport.Language.dv")
        self.Checkout_NewCard_PostcodeTitle = getValue(dict, "Checkout.NewCard.PostcodeTitle")
        self._Channel_AdminLog_MessageRestricted = getValue(dict, "Channel.AdminLog.MessageRestricted")
        self._Channel_AdminLog_MessageRestricted_r = extractArgumentRanges(self._Channel_AdminLog_MessageRestricted)
        self.SocksProxySetup_SecretPlaceholder = getValue(dict, "SocksProxySetup.SecretPlaceholder")
        self.Channel_EditAdmin_PermissinAddAdminOn = getValue(dict, "Channel.EditAdmin.PermissinAddAdminOn")
        self.WebSearch_GIFs = getValue(dict, "WebSearch.GIFs")
        self.Privacy_ChatsTitle = getValue(dict, "Privacy.ChatsTitle")
        self.Conversation_SavedMessages = getValue(dict, "Conversation.SavedMessages")
        self.TwoStepAuth_EnterPasswordTitle = getValue(dict, "TwoStepAuth.EnterPasswordTitle")
        self._CHANNEL_MESSAGE_GAME = getValue(dict, "CHANNEL_MESSAGE_GAME")
        self._CHANNEL_MESSAGE_GAME_r = extractArgumentRanges(self._CHANNEL_MESSAGE_GAME)
        self.Channel_Subscribers_Title = getValue(dict, "Channel.Subscribers.Title")
        self.AccessDenied_CallMicrophone = getValue(dict, "AccessDenied.CallMicrophone")
        self.Conversation_DeleteMessagesForEveryone = getValue(dict, "Conversation.DeleteMessagesForEveryone")
        self.UserInfo_TapToCall = getValue(dict, "UserInfo.TapToCall")
        self.Common_Edit = getValue(dict, "Common.Edit")
        self.Conversation_OpenFile = getValue(dict, "Conversation.OpenFile")
        self.PrivacyPolicy_Decline = getValue(dict, "PrivacyPolicy.Decline")
        self.Passport_Identity_ResidenceCountryPlaceholder = getValue(dict, "Passport.Identity.ResidenceCountryPlaceholder")
        self.Message_PinnedDocumentMessage = getValue(dict, "Message.PinnedDocumentMessage")
        self.AuthSessions_LogOut = getValue(dict, "AuthSessions.LogOut")
        self.AutoDownloadSettings_PrivateChats = getValue(dict, "AutoDownloadSettings.PrivateChats")
        self.Checkout_TotalPaidAmount = getValue(dict, "Checkout.TotalPaidAmount")
        self.Conversation_UnsupportedMedia = getValue(dict, "Conversation.UnsupportedMedia")
        self.Passport_InvalidPasswordError = getValue(dict, "Passport.InvalidPasswordError")
        self._Message_ForwardedMessage = getValue(dict, "Message.ForwardedMessage")
        self._Message_ForwardedMessage_r = extractArgumentRanges(self._Message_ForwardedMessage)
        self._Time_PreciseDate_m4 = getValue(dict, "Time.PreciseDate_m4")
        self._Time_PreciseDate_m4_r = extractArgumentRanges(self._Time_PreciseDate_m4)
        self.Checkout_NewCard_SaveInfoEnableHelp = getValue(dict, "Checkout.NewCard.SaveInfoEnableHelp")
        self.Call_AudioRouteHide = getValue(dict, "Call.AudioRouteHide")
        self.CallSettings_OnMobile = getValue(dict, "CallSettings.OnMobile")
        self.Conversation_GifTooltip = getValue(dict, "Conversation.GifTooltip")
        self.Passport_Address_EditBankStatement = getValue(dict, "Passport.Address.EditBankStatement")
        self.CheckoutInfo_ErrorCityInvalid = getValue(dict, "CheckoutInfo.ErrorCityInvalid")
        self._CHANNEL_MESSAGE_PHOTOS = getValue(dict, "CHANNEL_MESSAGE_PHOTOS")
        self._CHANNEL_MESSAGE_PHOTOS_r = extractArgumentRanges(self._CHANNEL_MESSAGE_PHOTOS)
        self.Profile_CreateEncryptedChatError = getValue(dict, "Profile.CreateEncryptedChatError")
        self.Map_LocationTitle = getValue(dict, "Map.LocationTitle")
        self.Call_RateCall = getValue(dict, "Call.RateCall")
        self.Passport_Address_City = getValue(dict, "Passport.Address.City")
        self.SocksProxySetup_PasswordPlaceholder = getValue(dict, "SocksProxySetup.PasswordPlaceholder")
        self.Message_ReplyActionButtonShowReceipt = getValue(dict, "Message.ReplyActionButtonShowReceipt")
        self.PhotoEditor_ShadowsTool = getValue(dict, "PhotoEditor.ShadowsTool")
        self.Checkout_NewCard_CardholderNamePlaceholder = getValue(dict, "Checkout.NewCard.CardholderNamePlaceholder")
        self.Cache_Title = getValue(dict, "Cache.Title")
        self.Passport_Email_Title = getValue(dict, "Passport.Email.Title")
        self.Month_GenMay = getValue(dict, "Month.GenMay")
        self.PasscodeSettings_HelpBottom = getValue(dict, "PasscodeSettings.HelpBottom")
        self._Notification_CreatedChat = getValue(dict, "Notification.CreatedChat")
        self._Notification_CreatedChat_r = extractArgumentRanges(self._Notification_CreatedChat)
        self.Calls_NoMissedCallsPlacehoder = getValue(dict, "Calls.NoMissedCallsPlacehoder")
        self.Passport_Address_RegionPlaceholder = getValue(dict, "Passport.Address.RegionPlaceholder")
        self.Channel_Stickers_NotFoundHelp = getValue(dict, "Channel.Stickers.NotFoundHelp")
        self.Watch_UserInfo_Block = getValue(dict, "Watch.UserInfo.Block")
        self.Watch_LastSeen_ALongTimeAgo = getValue(dict, "Watch.LastSeen.ALongTimeAgo")
        self.StickerPacksSettings_ManagingHelp = getValue(dict, "StickerPacksSettings.ManagingHelp")
        self.Privacy_GroupsAndChannels_InviteToChannelMultipleError = getValue(dict, "Privacy.GroupsAndChannels.InviteToChannelMultipleError")
        self.SearchImages_Title = getValue(dict, "SearchImages.Title")
        self.Channel_BlackList_Title = getValue(dict, "Channel.BlackList.Title")
        self._Conversation_LiveLocationYouAnd = getValue(dict, "Conversation.LiveLocationYouAnd")
        self._Conversation_LiveLocationYouAnd_r = extractArgumentRanges(self._Conversation_LiveLocationYouAnd)
        self.TwoStepAuth_PasswordRemovePassportConfirmation = getValue(dict, "TwoStepAuth.PasswordRemovePassportConfirmation")
        self.Checkout_NewCard_SaveInfo = getValue(dict, "Checkout.NewCard.SaveInfo")
        self.Notification_CallMissed = getValue(dict, "Notification.CallMissed")
        self.Profile_ShareContactButton = getValue(dict, "Profile.ShareContactButton")
        self.Group_ErrorSendRestrictedStickers = getValue(dict, "Group.ErrorSendRestrictedStickers")
        self.Bot_GroupStatusDoesNotReadHistory = getValue(dict, "Bot.GroupStatusDoesNotReadHistory")
        self.Notification_Mute1h = getValue(dict, "Notification.Mute1h")
        self._Channel_AdminLog_MessageUnkickedName = getValue(dict, "Channel.AdminLog.MessageUnkickedName")
        self._Channel_AdminLog_MessageUnkickedName_r = extractArgumentRanges(self._Channel_AdminLog_MessageUnkickedName)
        self.Settings_TabTitle = getValue(dict, "Settings.TabTitle")
        self.Passport_Identity_ExpiryDatePlaceholder = getValue(dict, "Passport.Identity.ExpiryDatePlaceholder")
        self.NetworkUsageSettings_MediaAudioDataSection = getValue(dict, "NetworkUsageSettings.MediaAudioDataSection")
        self.GroupInfo_DeactivatedStatus = getValue(dict, "GroupInfo.DeactivatedStatus")
        self._CHAT_PHOTO_EDITED = getValue(dict, "CHAT_PHOTO_EDITED")
        self._CHAT_PHOTO_EDITED_r = extractArgumentRanges(self._CHAT_PHOTO_EDITED)
        self.Conversation_ContextMenuMore = getValue(dict, "Conversation.ContextMenuMore")
        self._PrivacySettings_LastSeenEverybodyMinus = getValue(dict, "PrivacySettings.LastSeenEverybodyMinus")
        self._PrivacySettings_LastSeenEverybodyMinus_r = extractArgumentRanges(self._PrivacySettings_LastSeenEverybodyMinus)
        self.Map_ShareLiveLocation = getValue(dict, "Map.ShareLiveLocation")
        self.Weekday_Today = getValue(dict, "Weekday.Today")
        self._PINNED_GEOLIVE = getValue(dict, "PINNED_GEOLIVE")
        self._PINNED_GEOLIVE_r = extractArgumentRanges(self._PINNED_GEOLIVE)
        self._Conversation_RestrictedStickersTimed = getValue(dict, "Conversation.RestrictedStickersTimed")
        self._Conversation_RestrictedStickersTimed_r = extractArgumentRanges(self._Conversation_RestrictedStickersTimed)
        self.Login_InvalidFirstNameError = getValue(dict, "Login.InvalidFirstNameError")
        self._Channel_AdminLog_MessageUnkickedNameUsername = getValue(dict, "Channel.AdminLog.MessageUnkickedNameUsername")
        self._Channel_AdminLog_MessageUnkickedNameUsername_r = extractArgumentRanges(self._Channel_AdminLog_MessageUnkickedNameUsername)
        self._Notification_Joined = getValue(dict, "Notification.Joined")
        self._Notification_Joined_r = extractArgumentRanges(self._Notification_Joined)
        self.Paint_Clear = getValue(dict, "Paint.Clear")
        self.TwoStepAuth_RecoveryFailed = getValue(dict, "TwoStepAuth.RecoveryFailed")
        self._MESSAGE_AUDIO = getValue(dict, "MESSAGE_AUDIO")
        self._MESSAGE_AUDIO_r = extractArgumentRanges(self._MESSAGE_AUDIO)
        self.Checkout_PasswordEntry_Pay = getValue(dict, "Checkout.PasswordEntry.Pay")
        self.Conversation_EditingMessagePanelMedia = getValue(dict, "Conversation.EditingMessagePanelMedia")
        self.Notifications_MessageNotificationsHelp = getValue(dict, "Notifications.MessageNotificationsHelp")
        self.EnterPasscode_EnterCurrentPasscode = getValue(dict, "EnterPasscode.EnterCurrentPasscode")
        self.Conversation_EditingMessageMediaEditCurrentVideo = getValue(dict, "Conversation.EditingMessageMediaEditCurrentVideo")
        self._MESSAGE_GAME = getValue(dict, "MESSAGE_GAME")
        self._MESSAGE_GAME_r = extractArgumentRanges(self._MESSAGE_GAME)
        self.Conversation_Moderate_Report = getValue(dict, "Conversation.Moderate.Report")
        self.MessageTimer_Forever = getValue(dict, "MessageTimer.Forever")
        self.DialogList_SavedMessagesHelp = getValue(dict, "DialogList.SavedMessagesHelp")
        self._Conversation_EncryptedPlaceholderTitleIncoming = getValue(dict, "Conversation.EncryptedPlaceholderTitleIncoming")
        self._Conversation_EncryptedPlaceholderTitleIncoming_r = extractArgumentRanges(self._Conversation_EncryptedPlaceholderTitleIncoming)
        self._Map_AccurateTo = getValue(dict, "Map.AccurateTo")
        self._Map_AccurateTo_r = extractArgumentRanges(self._Map_AccurateTo)
        self._Call_ParticipantVersionOutdatedError = getValue(dict, "Call.ParticipantVersionOutdatedError")
        self._Call_ParticipantVersionOutdatedError_r = extractArgumentRanges(self._Call_ParticipantVersionOutdatedError)
        self.Passport_Identity_ReverseSideHelp = getValue(dict, "Passport.Identity.ReverseSideHelp")
        self.Tour_Text2 = getValue(dict, "Tour.Text2")
        self.Call_StatusNoAnswer = getValue(dict, "Call.StatusNoAnswer")
        self._Passport_Phone_UseTelegramNumber = getValue(dict, "Passport.Phone.UseTelegramNumber")
        self._Passport_Phone_UseTelegramNumber_r = extractArgumentRanges(self._Passport_Phone_UseTelegramNumber)
        self.Channel_AdminLogFilter_EventsLeavingSubscribers = getValue(dict, "Channel.AdminLogFilter.EventsLeavingSubscribers")
        self.Conversation_MessageDialogDelete = getValue(dict, "Conversation.MessageDialogDelete")
        self.Appearance_PreviewOutgoingText = getValue(dict, "Appearance.PreviewOutgoingText")
        self.Username_Placeholder = getValue(dict, "Username.Placeholder")
        self._Notification_PinnedDeletedMessage = getValue(dict, "Notification.PinnedDeletedMessage")
        self._Notification_PinnedDeletedMessage_r = extractArgumentRanges(self._Notification_PinnedDeletedMessage)
        self._Time_MonthOfYear_m11 = getValue(dict, "Time.MonthOfYear_m11")
        self._Time_MonthOfYear_m11_r = extractArgumentRanges(self._Time_MonthOfYear_m11)
        self.UserInfo_BotHelp = getValue(dict, "UserInfo.BotHelp")
        self.TwoStepAuth_PasswordSet = getValue(dict, "TwoStepAuth.PasswordSet")
        self._CHANNEL_MESSAGE_VIDEO = getValue(dict, "CHANNEL_MESSAGE_VIDEO")
        self._CHANNEL_MESSAGE_VIDEO_r = extractArgumentRanges(self._CHANNEL_MESSAGE_VIDEO)
        self.EnterPasscode_TouchId = getValue(dict, "EnterPasscode.TouchId")
        self.AuthSessions_LoggedInWithTelegram = getValue(dict, "AuthSessions.LoggedInWithTelegram")
        self.Checkout_ErrorInvoiceAlreadyPaid = getValue(dict, "Checkout.ErrorInvoiceAlreadyPaid")
        self.ChatAdmins_Title = getValue(dict, "ChatAdmins.Title")
        self.ChannelMembers_WhoCanAddMembers = getValue(dict, "ChannelMembers.WhoCanAddMembers")
        self.Passport_Language_ar = getValue(dict, "Passport.Language.ar")
        self.PasscodeSettings_Help = getValue(dict, "PasscodeSettings.Help")
        self.Conversation_EditingMessagePanelTitle = getValue(dict, "Conversation.EditingMessagePanelTitle")
        self.Settings_AboutEmpty = getValue(dict, "Settings.AboutEmpty")
        self._NetworkUsageSettings_CellularUsageSince = getValue(dict, "NetworkUsageSettings.CellularUsageSince")
        self._NetworkUsageSettings_CellularUsageSince_r = extractArgumentRanges(self._NetworkUsageSettings_CellularUsageSince)
        self.GroupInfo_ConvertToSupergroup = getValue(dict, "GroupInfo.ConvertToSupergroup")
        self._Notification_PinnedContactMessage = getValue(dict, "Notification.PinnedContactMessage")
        self._Notification_PinnedContactMessage_r = extractArgumentRanges(self._Notification_PinnedContactMessage)
        self.CallSettings_UseLessDataLongDescription = getValue(dict, "CallSettings.UseLessDataLongDescription")
        self.FastTwoStepSetup_PasswordPlaceholder = getValue(dict, "FastTwoStepSetup.PasswordPlaceholder")
        self.Conversation_SecretChatContextBotAlert = getValue(dict, "Conversation.SecretChatContextBotAlert")
        self.Channel_Moderator_AccessLevelRevoke = getValue(dict, "Channel.Moderator.AccessLevelRevoke")
        self.CheckoutInfo_ReceiverInfoTitle = getValue(dict, "CheckoutInfo.ReceiverInfoTitle")
        self.Channel_AdminLogFilter_EventsRestrictions = getValue(dict, "Channel.AdminLogFilter.EventsRestrictions")
        self.GroupInfo_InviteLink_RevokeLink = getValue(dict, "GroupInfo.InviteLink.RevokeLink")
        self.Checkout_PaymentMethod_Title = getValue(dict, "Checkout.PaymentMethod.Title")
        self.Conversation_Unmute = getValue(dict, "Conversation.Unmute")
        self.AutoDownloadSettings_DocumentsTitle = getValue(dict, "AutoDownloadSettings.DocumentsTitle")
        self.Passport_FieldOneOf_FinalDelimeter = getValue(dict, "Passport.FieldOneOf.FinalDelimeter")
        self.Notifications_MessageNotifications = getValue(dict, "Notifications.MessageNotifications")
        self.Passport_ForgottenPassword = getValue(dict, "Passport.ForgottenPassword")
        self.ChannelMembers_WhoCanAddMembersAdminsHelp = getValue(dict, "ChannelMembers.WhoCanAddMembersAdminsHelp")
        self.DialogList_DeleteBotConversationConfirmation = getValue(dict, "DialogList.DeleteBotConversationConfirmation")
        self.Passport_Identity_TranslationHelp = getValue(dict, "Passport.Identity.TranslationHelp")
        self._Update_AppVersion = getValue(dict, "Update.AppVersion")
        self._Update_AppVersion_r = extractArgumentRanges(self._Update_AppVersion)
        self._DialogList_MultipleTyping = getValue(dict, "DialogList.MultipleTyping")
        self._DialogList_MultipleTyping_r = extractArgumentRanges(self._DialogList_MultipleTyping)
        self.Passport_Identity_OneOfTypeIdentityCard = getValue(dict, "Passport.Identity.OneOfTypeIdentityCard")
        self.Conversation_ClousStorageInfo_Description2 = getValue(dict, "Conversation.ClousStorageInfo.Description2")
        self._Time_MonthOfYear_m5 = getValue(dict, "Time.MonthOfYear_m5")
        self._Time_MonthOfYear_m5_r = extractArgumentRanges(self._Time_MonthOfYear_m5)
        self.Map_Hybrid = getValue(dict, "Map.Hybrid")
        self.Channel_Setup_Title = getValue(dict, "Channel.Setup.Title")
        self.MediaPicker_TimerTooltip = getValue(dict, "MediaPicker.TimerTooltip")
        self.Activity_UploadingVideo = getValue(dict, "Activity.UploadingVideo")
        self.Channel_Info_Management = getValue(dict, "Channel.Info.Management")
        self._Login_TermsOfService_ProceedBot = getValue(dict, "Login.TermsOfService.ProceedBot")
        self._Login_TermsOfService_ProceedBot_r = extractArgumentRanges(self._Login_TermsOfService_ProceedBot)
        self._Notification_MessageLifetimeChangedOutgoing = getValue(dict, "Notification.MessageLifetimeChangedOutgoing")
        self._Notification_MessageLifetimeChangedOutgoing_r = extractArgumentRanges(self._Notification_MessageLifetimeChangedOutgoing)
        self.PhotoEditor_QualityVeryLow = getValue(dict, "PhotoEditor.QualityVeryLow")
        self.Stickers_AddToFavorites = getValue(dict, "Stickers.AddToFavorites")
        self.Month_ShortFebruary = getValue(dict, "Month.ShortFebruary")
        self.Notifications_AddExceptionTitle = getValue(dict, "Notifications.AddExceptionTitle")
        self.Conversation_ForwardTitle = getValue(dict, "Conversation.ForwardTitle")
        self.Settings_FAQ_URL = getValue(dict, "Settings.FAQ_URL")
        self.Activity_RecordingVideoMessage = getValue(dict, "Activity.RecordingVideoMessage")
        self.SharedMedia_EmptyFilesText = getValue(dict, "SharedMedia.EmptyFilesText")
        self._Contacts_AccessDeniedHelpLandscape = getValue(dict, "Contacts.AccessDeniedHelpLandscape")
        self._Contacts_AccessDeniedHelpLandscape_r = extractArgumentRanges(self._Contacts_AccessDeniedHelpLandscape)
        self.PasscodeSettings_UnlockWithTouchId = getValue(dict, "PasscodeSettings.UnlockWithTouchId")
        self.Contacts_AccessDeniedHelpON = getValue(dict, "Contacts.AccessDeniedHelpON")
        self.Passport_Identity_AddInternalPassport = getValue(dict, "Passport.Identity.AddInternalPassport")
        self.NetworkUsageSettings_ResetStats = getValue(dict, "NetworkUsageSettings.ResetStats")
        self._CHAT_MESSAGE_PHOTOS = getValue(dict, "CHAT_MESSAGE_PHOTOS")
        self._CHAT_MESSAGE_PHOTOS_r = extractArgumentRanges(self._CHAT_MESSAGE_PHOTOS)
        self._PrivacySettings_LastSeenContactsMinusPlus = getValue(dict, "PrivacySettings.LastSeenContactsMinusPlus")
        self._PrivacySettings_LastSeenContactsMinusPlus_r = extractArgumentRanges(self._PrivacySettings_LastSeenContactsMinusPlus)
        self.Channel_AdminLog_EmptyMessageText = getValue(dict, "Channel.AdminLog.EmptyMessageText")
        self._Notification_ChannelInviter = getValue(dict, "Notification.ChannelInviter")
        self._Notification_ChannelInviter_r = extractArgumentRanges(self._Notification_ChannelInviter)
        self.SocksProxySetup_TypeSocks = getValue(dict, "SocksProxySetup.TypeSocks")
        self.Profile_MessageLifetimeForever = getValue(dict, "Profile.MessageLifetimeForever")
        self.MediaPicker_UngroupDescription = getValue(dict, "MediaPicker.UngroupDescription")
        self._Checkout_SavePasswordTimeoutAndFaceId = getValue(dict, "Checkout.SavePasswordTimeoutAndFaceId")
        self._Checkout_SavePasswordTimeoutAndFaceId_r = extractArgumentRanges(self._Checkout_SavePasswordTimeoutAndFaceId)
        self.SocksProxySetup_Username = getValue(dict, "SocksProxySetup.Username")
        self.Conversation_Edit = getValue(dict, "Conversation.Edit")
        self.TwoStepAuth_ResetAccountHelp = getValue(dict, "TwoStepAuth.ResetAccountHelp")
        self.Month_GenDecember = getValue(dict, "Month.GenDecember")
        self._Watch_LastSeen_YesterdayAt = getValue(dict, "Watch.LastSeen.YesterdayAt")
        self._Watch_LastSeen_YesterdayAt_r = extractArgumentRanges(self._Watch_LastSeen_YesterdayAt)
        self.Channel_ErrorAddBlocked = getValue(dict, "Channel.ErrorAddBlocked")
        self.Conversation_Unpin = getValue(dict, "Conversation.Unpin")
        self.Call_RecordingDisabledMessage = getValue(dict, "Call.RecordingDisabledMessage")
        self.Passport_Address_TypeUtilityBill = getValue(dict, "Passport.Address.TypeUtilityBill")
        self.Conversation_UnblockUser = getValue(dict, "Conversation.UnblockUser")
        self.Conversation_Unblock = getValue(dict, "Conversation.Unblock")
        self._CHANNEL_MESSAGE_GIF = getValue(dict, "CHANNEL_MESSAGE_GIF")
        self._CHANNEL_MESSAGE_GIF_r = extractArgumentRanges(self._CHANNEL_MESSAGE_GIF)
        self.Channel_AdminLogFilter_EventsEditedMessages = getValue(dict, "Channel.AdminLogFilter.EventsEditedMessages")
        self.AutoNightTheme_ScheduleSection = getValue(dict, "AutoNightTheme.ScheduleSection")
        self.Appearance_ThemeNightBlue = getValue(dict, "Appearance.ThemeNightBlue")
        self._Passport_Scans_ScanIndex = getValue(dict, "Passport.Scans.ScanIndex")
        self._Passport_Scans_ScanIndex_r = extractArgumentRanges(self._Passport_Scans_ScanIndex)
        self.Channel_Username_InvalidTooShort = getValue(dict, "Channel.Username.InvalidTooShort")
        self.Conversation_ViewGroup = getValue(dict, "Conversation.ViewGroup")
        self.Watch_LastSeen_WithinAWeek = getValue(dict, "Watch.LastSeen.WithinAWeek")
        self.BlockedUsers_SelectUserTitle = getValue(dict, "BlockedUsers.SelectUserTitle")
        self.Profile_MessageLifetime1w = getValue(dict, "Profile.MessageLifetime1w")
        self.Passport_Address_TypeRentalAgreementUploadScan = getValue(dict, "Passport.Address.TypeRentalAgreementUploadScan")
        self.DialogList_TabTitle = getValue(dict, "DialogList.TabTitle")
        self.UserInfo_GenericPhoneLabel = getValue(dict, "UserInfo.GenericPhoneLabel")
        self._Channel_AdminLog_MessagePromotedName = getValue(dict, "Channel.AdminLog.MessagePromotedName")
        self._Channel_AdminLog_MessagePromotedName_r = extractArgumentRanges(self._Channel_AdminLog_MessagePromotedName)
        self.Group_Members_AddMemberBotErrorNotAllowed = getValue(dict, "Group.Members.AddMemberBotErrorNotAllowed")
        self._Username_LinkHint = getValue(dict, "Username.LinkHint")
        self._Username_LinkHint_r = extractArgumentRanges(self._Username_LinkHint)
        self.Map_StopLiveLocation = getValue(dict, "Map.StopLiveLocation")
        self.Message_LiveLocation = getValue(dict, "Message.LiveLocation")
        self.NetworkUsageSettings_Title = getValue(dict, "NetworkUsageSettings.Title")
        self.CheckoutInfo_ShippingInfoPostcodePlaceholder = getValue(dict, "CheckoutInfo.ShippingInfoPostcodePlaceholder")
        self.InfoPlist_NSPhotoLibraryUsageDescription = getValue(dict, "InfoPlist.NSPhotoLibraryUsageDescription")
        self.Wallpaper_Wallpaper = getValue(dict, "Wallpaper.Wallpaper")
        self.GroupInfo_InviteLink_RevokeAlert_Revoke = getValue(dict, "GroupInfo.InviteLink.RevokeAlert.Revoke")
        self.SharedMedia_TitleLink = getValue(dict, "SharedMedia.TitleLink")
        self._Channel_AdminLog_MessageRestrictedName = getValue(dict, "Channel.AdminLog.MessageRestrictedName")
        self._Channel_AdminLog_MessageRestrictedName_r = extractArgumentRanges(self._Channel_AdminLog_MessageRestrictedName)
        self._Channel_AdminLog_MessageGroupPreHistoryHidden = getValue(dict, "Channel.AdminLog.MessageGroupPreHistoryHidden")
        self._Channel_AdminLog_MessageGroupPreHistoryHidden_r = extractArgumentRanges(self._Channel_AdminLog_MessageGroupPreHistoryHidden)
        self.Channel_JoinChannel = getValue(dict, "Channel.JoinChannel")
        self.StickerPack_Add = getValue(dict, "StickerPack.Add")
        self.Group_ErrorNotMutualContact = getValue(dict, "Group.ErrorNotMutualContact")
        self.AccessDenied_LocationDisabled = getValue(dict, "AccessDenied.LocationDisabled")
        self.Login_UnknownError = getValue(dict, "Login.UnknownError")
        self.Presence_online = getValue(dict, "Presence.online")
        self.DialogList_Title = getValue(dict, "DialogList.Title")
        self.Stickers_Install = getValue(dict, "Stickers.Install")
        self.SearchImages_NoImagesFound = getValue(dict, "SearchImages.NoImagesFound")
        self._Watch_Time_ShortTodayAt = getValue(dict, "Watch.Time.ShortTodayAt")
        self._Watch_Time_ShortTodayAt_r = extractArgumentRanges(self._Watch_Time_ShortTodayAt)
        self.Channel_AdminLogFilter_EventsNewSubscribers = getValue(dict, "Channel.AdminLogFilter.EventsNewSubscribers")
        self.Passport_Identity_ExpiryDate = getValue(dict, "Passport.Identity.ExpiryDate")
        self.UserInfo_GroupsInCommon = getValue(dict, "UserInfo.GroupsInCommon")
        self.Message_PinnedContactMessage = getValue(dict, "Message.PinnedContactMessage")
        self.AccessDenied_CameraDisabled = getValue(dict, "AccessDenied.CameraDisabled")
        self._Time_PreciseDate_m3 = getValue(dict, "Time.PreciseDate_m3")
        self._Time_PreciseDate_m3_r = extractArgumentRanges(self._Time_PreciseDate_m3)
        self.Passport_Email_EnterOtherEmail = getValue(dict, "Passport.Email.EnterOtherEmail")
        self._LiveLocationUpdated_YesterdayAt = getValue(dict, "LiveLocationUpdated.YesterdayAt")
        self._LiveLocationUpdated_YesterdayAt_r = extractArgumentRanges(self._LiveLocationUpdated_YesterdayAt)
        self.NotificationsSound_Note = getValue(dict, "NotificationsSound.Note")
        self.Passport_Identity_MiddleNamePlaceholder = getValue(dict, "Passport.Identity.MiddleNamePlaceholder")
        self.PrivacyPolicy_Title = getValue(dict, "PrivacyPolicy.Title")
        self.Month_GenMarch = getValue(dict, "Month.GenMarch")
        self.Watch_UserInfo_Unmute = getValue(dict, "Watch.UserInfo.Unmute")
        self.CheckoutInfo_ErrorPostcodeInvalid = getValue(dict, "CheckoutInfo.ErrorPostcodeInvalid")
        self.Common_Delete = getValue(dict, "Common.Delete")
        self.Username_Title = getValue(dict, "Username.Title")
        self.Login_PhoneFloodError = getValue(dict, "Login.PhoneFloodError")
        self.Channel_AdminLog_InfoPanelTitle = getValue(dict, "Channel.AdminLog.InfoPanelTitle")
        self._CHANNEL_MESSAGE_PHOTO = getValue(dict, "CHANNEL_MESSAGE_PHOTO")
        self._CHANNEL_MESSAGE_PHOTO_r = extractArgumentRanges(self._CHANNEL_MESSAGE_PHOTO)
        self._Channel_AdminLog_MessageToggleInvitesOff = getValue(dict, "Channel.AdminLog.MessageToggleInvitesOff")
        self._Channel_AdminLog_MessageToggleInvitesOff_r = extractArgumentRanges(self._Channel_AdminLog_MessageToggleInvitesOff)
        self.Group_ErrorAddTooMuchBots = getValue(dict, "Group.ErrorAddTooMuchBots")
        self._Notification_CallFormat = getValue(dict, "Notification.CallFormat")
        self._Notification_CallFormat_r = extractArgumentRanges(self._Notification_CallFormat)
        self._CHAT_MESSAGE_PHOTO = getValue(dict, "CHAT_MESSAGE_PHOTO")
        self._CHAT_MESSAGE_PHOTO_r = extractArgumentRanges(self._CHAT_MESSAGE_PHOTO)
        self._UserInfo_UnblockConfirmation = getValue(dict, "UserInfo.UnblockConfirmation")
        self._UserInfo_UnblockConfirmation_r = extractArgumentRanges(self._UserInfo_UnblockConfirmation)
        self.Appearance_PickAccentColor = getValue(dict, "Appearance.PickAccentColor")
        self.Passport_Identity_EditDriversLicense = getValue(dict, "Passport.Identity.EditDriversLicense")
        self.Passport_Identity_AddPassport = getValue(dict, "Passport.Identity.AddPassport")
        self.UserInfo_ShareBot = getValue(dict, "UserInfo.ShareBot")
        self.Settings_ProxyConnected = getValue(dict, "Settings.ProxyConnected")
        self.ChatSettings_AutoDownloadVoiceMessages = getValue(dict, "ChatSettings.AutoDownloadVoiceMessages")
        self.TwoStepAuth_EmailSkip = getValue(dict, "TwoStepAuth.EmailSkip")
        self.Conversation_ViewContactDetails = getValue(dict, "Conversation.ViewContactDetails")
        self.Conversation_JumpToDate = getValue(dict, "Conversation.JumpToDate")
        self.AutoDownloadSettings_VideoMessagesTitle = getValue(dict, "AutoDownloadSettings.VideoMessagesTitle")
        self.Passport_Address_OneOfTypeUtilityBill = getValue(dict, "Passport.Address.OneOfTypeUtilityBill")
        self.CheckoutInfo_ReceiverInfoEmailPlaceholder = getValue(dict, "CheckoutInfo.ReceiverInfoEmailPlaceholder")
        self.Message_Photo = getValue(dict, "Message.Photo")
        self.Conversation_ReportSpam = getValue(dict, "Conversation.ReportSpam")
        self.Camera_FlashAuto = getValue(dict, "Camera.FlashAuto")
        self.Passport_Identity_TypePassportUploadScan = getValue(dict, "Passport.Identity.TypePassportUploadScan")
        self.Call_ConnectionErrorMessage = getValue(dict, "Call.ConnectionErrorMessage")
        self.Stickers_FrequentlyUsed = getValue(dict, "Stickers.FrequentlyUsed")
        self.LastSeen_ALongTimeAgo = getValue(dict, "LastSeen.ALongTimeAgo")
        self.Passport_Identity_ReverseSide = getValue(dict, "Passport.Identity.ReverseSide")
        self.DialogList_SearchSectionGlobal = getValue(dict, "DialogList.SearchSectionGlobal")
        self.ChangePhoneNumberNumber_NumberPlaceholder = getValue(dict, "ChangePhoneNumberNumber.NumberPlaceholder")
        self.GroupInfo_AddUserLeftError = getValue(dict, "GroupInfo.AddUserLeftError")
        self.Appearance_ThemeDay = getValue(dict, "Appearance.ThemeDay")
        self.GroupInfo_GroupType = getValue(dict, "GroupInfo.GroupType")
        self.Watch_Suggestion_OnMyWay = getValue(dict, "Watch.Suggestion.OnMyWay")
        self.Checkout_NewCard_PaymentCard = getValue(dict, "Checkout.NewCard.PaymentCard")
        self._DialogList_SearchSubtitleFormat = getValue(dict, "DialogList.SearchSubtitleFormat")
        self._DialogList_SearchSubtitleFormat_r = extractArgumentRanges(self._DialogList_SearchSubtitleFormat)
        self.PhotoEditor_CropAspectRatioOriginal = getValue(dict, "PhotoEditor.CropAspectRatioOriginal")
        self._Conversation_RestrictedInlineTimed = getValue(dict, "Conversation.RestrictedInlineTimed")
        self._Conversation_RestrictedInlineTimed_r = extractArgumentRanges(self._Conversation_RestrictedInlineTimed)
        self.UserInfo_NotificationsDisabled = getValue(dict, "UserInfo.NotificationsDisabled")
        self._CONTACT_JOINED = getValue(dict, "CONTACT_JOINED")
        self._CONTACT_JOINED_r = extractArgumentRanges(self._CONTACT_JOINED)
        self.NotificationsSound_Bamboo = getValue(dict, "NotificationsSound.Bamboo")
        self.PrivacyLastSeenSettings_AlwaysShareWith_Title = getValue(dict, "PrivacyLastSeenSettings.AlwaysShareWith.Title")
        self._Channel_AdminLog_MessageGroupPreHistoryVisible = getValue(dict, "Channel.AdminLog.MessageGroupPreHistoryVisible")
        self._Channel_AdminLog_MessageGroupPreHistoryVisible_r = extractArgumentRanges(self._Channel_AdminLog_MessageGroupPreHistoryVisible)
        self.BlockedUsers_LeavePrefix = getValue(dict, "BlockedUsers.LeavePrefix")
        self.NetworkUsageSettings_ResetStatsConfirmation = getValue(dict, "NetworkUsageSettings.ResetStatsConfirmation")
        self.Group_Setup_HistoryHeader = getValue(dict, "Group.Setup.HistoryHeader")
        self.Channel_EditAdmin_PermissionPostMessages = getValue(dict, "Channel.EditAdmin.PermissionPostMessages")
        self._Contacts_AddPhoneNumber = getValue(dict, "Contacts.AddPhoneNumber")
        self._Contacts_AddPhoneNumber_r = extractArgumentRanges(self._Contacts_AddPhoneNumber)
        self._MESSAGE_SCREENSHOT = getValue(dict, "MESSAGE_SCREENSHOT")
        self._MESSAGE_SCREENSHOT_r = extractArgumentRanges(self._MESSAGE_SCREENSHOT)
        self.DialogList_EncryptionProcessing = getValue(dict, "DialogList.EncryptionProcessing")
        self.GroupInfo_GroupHistory = getValue(dict, "GroupInfo.GroupHistory")
        self.Conversation_ApplyLocalization = getValue(dict, "Conversation.ApplyLocalization")
        self.FastTwoStepSetup_Title = getValue(dict, "FastTwoStepSetup.Title")
        self.SocksProxySetup_ProxyStatusUnavailable = getValue(dict, "SocksProxySetup.ProxyStatusUnavailable")
        self.Passport_Address_EditRentalAgreement = getValue(dict, "Passport.Address.EditRentalAgreement")
        self.Conversation_DeleteManyMessages = getValue(dict, "Conversation.DeleteManyMessages")
        self.CancelResetAccount_Title = getValue(dict, "CancelResetAccount.Title")
        self.Notification_CallOutgoingShort = getValue(dict, "Notification.CallOutgoingShort")
        self.SharedMedia_TitleAll = getValue(dict, "SharedMedia.TitleAll")
        self.Conversation_SlideToCancel = getValue(dict, "Conversation.SlideToCancel")
        self.AuthSessions_TerminateSession = getValue(dict, "AuthSessions.TerminateSession")
        self.Channel_AdminLogFilter_EventsDeletedMessages = getValue(dict, "Channel.AdminLogFilter.EventsDeletedMessages")
        self.PrivacyLastSeenSettings_AlwaysShareWith_Placeholder = getValue(dict, "PrivacyLastSeenSettings.AlwaysShareWith.Placeholder")
        self.Channel_Members_Title = getValue(dict, "Channel.Members.Title")
        self.Channel_AdminLog_CanDeleteMessages = getValue(dict, "Channel.AdminLog.CanDeleteMessages")
        self.Privacy_DeleteDrafts = getValue(dict, "Privacy.DeleteDrafts")
        self.Group_Setup_TypePrivateHelp = getValue(dict, "Group.Setup.TypePrivateHelp")
        self._Notification_PinnedVideoMessage = getValue(dict, "Notification.PinnedVideoMessage")
        self._Notification_PinnedVideoMessage_r = extractArgumentRanges(self._Notification_PinnedVideoMessage)
        self.Conversation_ContextMenuStickerPackAdd = getValue(dict, "Conversation.ContextMenuStickerPackAdd")
        self.Channel_AdminLogFilter_EventsNewMembers = getValue(dict, "Channel.AdminLogFilter.EventsNewMembers")
        self.Channel_AdminLogFilter_EventsPinned = getValue(dict, "Channel.AdminLogFilter.EventsPinned")
        self._Conversation_Moderate_DeleteAllMessages = getValue(dict, "Conversation.Moderate.DeleteAllMessages")
        self._Conversation_Moderate_DeleteAllMessages_r = extractArgumentRanges(self._Conversation_Moderate_DeleteAllMessages)
        self.SharedMedia_CategoryOther = getValue(dict, "SharedMedia.CategoryOther")
        self.Passport_Address_Address = getValue(dict, "Passport.Address.Address")
        self.DialogList_SavedMessagesTooltip = getValue(dict, "DialogList.SavedMessagesTooltip")
        self.Preview_DeletePhoto = getValue(dict, "Preview.DeletePhoto")
        self.GroupInfo_ChannelListNamePlaceholder = getValue(dict, "GroupInfo.ChannelListNamePlaceholder")
        self.PasscodeSettings_TurnPasscodeOn = getValue(dict, "PasscodeSettings.TurnPasscodeOn")
        self.AuthSessions_LogOutApplicationsHelp = getValue(dict, "AuthSessions.LogOutApplicationsHelp")
        self.Passport_FieldOneOf_Delimeter = getValue(dict, "Passport.FieldOneOf.Delimeter")
        self._Channel_AdminLog_MessageChangedGroupStickerPack = getValue(dict, "Channel.AdminLog.MessageChangedGroupStickerPack")
        self._Channel_AdminLog_MessageChangedGroupStickerPack_r = extractArgumentRanges(self._Channel_AdminLog_MessageChangedGroupStickerPack)
        self.DialogList_Unpin = getValue(dict, "DialogList.Unpin")
        self.GroupInfo_SetGroupPhoto = getValue(dict, "GroupInfo.SetGroupPhoto")
        self.StickerPacksSettings_ArchivedPacks_Info = getValue(dict, "StickerPacksSettings.ArchivedPacks.Info")
        self.ConvertToSupergroup_Title = getValue(dict, "ConvertToSupergroup.Title")
        self._CHAT_MESSAGE_NOTEXT = getValue(dict, "CHAT_MESSAGE_NOTEXT")
        self._CHAT_MESSAGE_NOTEXT_r = extractArgumentRanges(self._CHAT_MESSAGE_NOTEXT)
        self.Notification_CallCanceledShort = getValue(dict, "Notification.CallCanceledShort")
        self.Channel_Setup_TypeHeader = getValue(dict, "Channel.Setup.TypeHeader")
        self._Notification_NewAuthDetected = getValue(dict, "Notification.NewAuthDetected")
        self._Notification_NewAuthDetected_r = extractArgumentRanges(self._Notification_NewAuthDetected)
        self._Channel_AdminLog_MessageRemovedGroupStickerPack = getValue(dict, "Channel.AdminLog.MessageRemovedGroupStickerPack")
        self._Channel_AdminLog_MessageRemovedGroupStickerPack_r = extractArgumentRanges(self._Channel_AdminLog_MessageRemovedGroupStickerPack)
        self.PrivacyPolicy_DeclineTitle = getValue(dict, "PrivacyPolicy.DeclineTitle")
        self.AccessDenied_VideoMessageCamera = getValue(dict, "AccessDenied.VideoMessageCamera")
        self.Privacy_ContactsSyncHelp = getValue(dict, "Privacy.ContactsSyncHelp")
        self.Conversation_Search = getValue(dict, "Conversation.Search")
        self._Channel_Management_PromotedBy = getValue(dict, "Channel.Management.PromotedBy")
        self._Channel_Management_PromotedBy_r = extractArgumentRanges(self._Channel_Management_PromotedBy)
        self._PrivacySettings_LastSeenNobodyPlus = getValue(dict, "PrivacySettings.LastSeenNobodyPlus")
        self._PrivacySettings_LastSeenNobodyPlus_r = extractArgumentRanges(self._PrivacySettings_LastSeenNobodyPlus)
        self._Time_MonthOfYear_m4 = getValue(dict, "Time.MonthOfYear_m4")
        self._Time_MonthOfYear_m4_r = extractArgumentRanges(self._Time_MonthOfYear_m4)
        self.SecretImage_Title = getValue(dict, "SecretImage.Title")
        self.Notifications_InAppNotificationsSounds = getValue(dict, "Notifications.InAppNotificationsSounds")
        self.Call_StatusRequesting = getValue(dict, "Call.StatusRequesting")
        self._Channel_AdminLog_MessageRestrictedUntil = getValue(dict, "Channel.AdminLog.MessageRestrictedUntil")
        self._Channel_AdminLog_MessageRestrictedUntil_r = extractArgumentRanges(self._Channel_AdminLog_MessageRestrictedUntil)
        self._CHAT_MESSAGE_CONTACT = getValue(dict, "CHAT_MESSAGE_CONTACT")
        self._CHAT_MESSAGE_CONTACT_r = extractArgumentRanges(self._CHAT_MESSAGE_CONTACT)
        self.SocksProxySetup_UseProxy = getValue(dict, "SocksProxySetup.UseProxy")
        self.Group_UpgradeNoticeText1 = getValue(dict, "Group.UpgradeNoticeText1")
        self.ChatSettings_Other = getValue(dict, "ChatSettings.Other")
        self._Channel_AdminLog_MessageChangedChannelAbout = getValue(dict, "Channel.AdminLog.MessageChangedChannelAbout")
        self._Channel_AdminLog_MessageChangedChannelAbout_r = extractArgumentRanges(self._Channel_AdminLog_MessageChangedChannelAbout)
        self.Channel_Stickers_CreateYourOwn = getValue(dict, "Channel.Stickers.CreateYourOwn")
        self._Call_EmojiDescription = getValue(dict, "Call.EmojiDescription")
        self._Call_EmojiDescription_r = extractArgumentRanges(self._Call_EmojiDescription)
        self.Settings_SaveIncomingPhotos = getValue(dict, "Settings.SaveIncomingPhotos")
        self._Conversation_Bytes = getValue(dict, "Conversation.Bytes")
        self._Conversation_Bytes_r = extractArgumentRanges(self._Conversation_Bytes)
        self.GroupInfo_InviteLink_Help = getValue(dict, "GroupInfo.InviteLink.Help")
        self.Calls_Missed = getValue(dict, "Calls.Missed")
        self.Conversation_ContextMenuForward = getValue(dict, "Conversation.ContextMenuForward")
        self.AutoDownloadSettings_ResetHelp = getValue(dict, "AutoDownloadSettings.ResetHelp")
        self.Passport_Identity_NativeNameHelp = getValue(dict, "Passport.Identity.NativeNameHelp")
        self.Call_StatusRinging = getValue(dict, "Call.StatusRinging")
        self.Passport_Language_pl = getValue(dict, "Passport.Language.pl")
        self.Invitation_JoinGroup = getValue(dict, "Invitation.JoinGroup")
        self.Notification_PinnedMessage = getValue(dict, "Notification.PinnedMessage")
        self.AutoDownloadSettings_WiFi = getValue(dict, "AutoDownloadSettings.WiFi")
        self.Conversation_ClearSelfHistory = getValue(dict, "Conversation.ClearSelfHistory")
        self.Message_Location = getValue(dict, "Message.Location")
        self._Notification_MessageLifetimeChanged = getValue(dict, "Notification.MessageLifetimeChanged")
        self._Notification_MessageLifetimeChanged_r = extractArgumentRanges(self._Notification_MessageLifetimeChanged)
        self.Message_Contact = getValue(dict, "Message.Contact")
        self.Passport_Language_lo = getValue(dict, "Passport.Language.lo")
        self.UserInfo_BotPrivacy = getValue(dict, "UserInfo.BotPrivacy")
        self.PasscodeSettings_AutoLock_IfAwayFor_1minute = getValue(dict, "PasscodeSettings.AutoLock.IfAwayFor_1minute")
        self.Common_More = getValue(dict, "Common.More")
        self.Preview_OpenInInstagram = getValue(dict, "Preview.OpenInInstagram")
        self.PhotoEditor_HighlightsTool = getValue(dict, "PhotoEditor.HighlightsTool")
        self._Channel_Username_UsernameIsAvailable = getValue(dict, "Channel.Username.UsernameIsAvailable")
        self._Channel_Username_UsernameIsAvailable_r = extractArgumentRanges(self._Channel_Username_UsernameIsAvailable)
        self._PINNED_GAME = getValue(dict, "PINNED_GAME")
        self._PINNED_GAME_r = extractArgumentRanges(self._PINNED_GAME)
        self.Invite_LargeRecipientsCountWarning = getValue(dict, "Invite.LargeRecipientsCountWarning")
        self.Passport_Language_hr = getValue(dict, "Passport.Language.hr")
        self.GroupInfo_BroadcastListNamePlaceholder = getValue(dict, "GroupInfo.BroadcastListNamePlaceholder")
        self.Activity_UploadingVideoMessage = getValue(dict, "Activity.UploadingVideoMessage")
        self.Conversation_ShareBotContactConfirmation = getValue(dict, "Conversation.ShareBotContactConfirmation")
        self.Login_CodeSentSms = getValue(dict, "Login.CodeSentSms")
        self._CHANNEL_MESSAGES = getValue(dict, "CHANNEL_MESSAGES")
        self._CHANNEL_MESSAGES_r = extractArgumentRanges(self._CHANNEL_MESSAGES)
        self.Conversation_ReportSpamConfirmation = getValue(dict, "Conversation.ReportSpamConfirmation")
        self.ChannelMembers_ChannelAdminsTitle = getValue(dict, "ChannelMembers.ChannelAdminsTitle")
        self.SocksProxySetup_Credentials = getValue(dict, "SocksProxySetup.Credentials")
        self.CallSettings_UseLessData = getValue(dict, "CallSettings.UseLessData")
        self.MediaPicker_GroupDescription = getValue(dict, "MediaPicker.GroupDescription")
        self._TwoStepAuth_EnterPasswordHint = getValue(dict, "TwoStepAuth.EnterPasswordHint")
        self._TwoStepAuth_EnterPasswordHint_r = extractArgumentRanges(self._TwoStepAuth_EnterPasswordHint)
        self.CallSettings_TabIcon = getValue(dict, "CallSettings.TabIcon")
        self.ConversationProfile_UnknownAddMemberError = getValue(dict, "ConversationProfile.UnknownAddMemberError")
        self._Conversation_FileHowToText = getValue(dict, "Conversation.FileHowToText")
        self._Conversation_FileHowToText_r = extractArgumentRanges(self._Conversation_FileHowToText)
        self.Channel_AdminLog_BanSendMedia = getValue(dict, "Channel.AdminLog.BanSendMedia")
        self.Passport_Language_uz = getValue(dict, "Passport.Language.uz")
        self.Watch_UserInfo_Unblock = getValue(dict, "Watch.UserInfo.Unblock")
        self.ChatSettings_AutoDownloadVideoMessages = getValue(dict, "ChatSettings.AutoDownloadVideoMessages")
        self.PrivacyPolicy_AgeVerificationTitle = getValue(dict, "PrivacyPolicy.AgeVerificationTitle")
        self.StickerPacksSettings_ArchivedMasks = getValue(dict, "StickerPacksSettings.ArchivedMasks")
        self.Message_Animation = getValue(dict, "Message.Animation")
        self.Checkout_PaymentMethod = getValue(dict, "Checkout.PaymentMethod")
        self.Channel_AdminLog_TitleSelectedEvents = getValue(dict, "Channel.AdminLog.TitleSelectedEvents")
        self.PrivacyPolicy_DeclineDeleteNow = getValue(dict, "PrivacyPolicy.DeclineDeleteNow")
        self.Privacy_Calls_NeverAllow_Title = getValue(dict, "Privacy.Calls.NeverAllow.Title")
        self.Cache_Music = getValue(dict, "Cache.Music")
        self._Login_CallRequestState1 = getValue(dict, "Login.CallRequestState1")
        self._Login_CallRequestState1_r = extractArgumentRanges(self._Login_CallRequestState1)
        self.Settings_ProxyDisabled = getValue(dict, "Settings.ProxyDisabled")
        self.SocksProxySetup_Connecting = getValue(dict, "SocksProxySetup.Connecting")
        self.Channel_Username_CreatePrivateLinkHelp = getValue(dict, "Channel.Username.CreatePrivateLinkHelp")
        self._Time_PreciseDate_m2 = getValue(dict, "Time.PreciseDate_m2")
        self._Time_PreciseDate_m2_r = extractArgumentRanges(self._Time_PreciseDate_m2)
        self._FileSize_B = getValue(dict, "FileSize.B")
        self._FileSize_B_r = extractArgumentRanges(self._FileSize_B)
        self._Target_ShareGameConfirmationGroup = getValue(dict, "Target.ShareGameConfirmationGroup")
        self._Target_ShareGameConfirmationGroup_r = extractArgumentRanges(self._Target_ShareGameConfirmationGroup)
        self.PhotoEditor_SaturationTool = getValue(dict, "PhotoEditor.SaturationTool")
        self.Channel_BanUser_BlockFor = getValue(dict, "Channel.BanUser.BlockFor")
        self.Call_StatusConnecting = getValue(dict, "Call.StatusConnecting")
        self.AutoNightTheme_NotAvailable = getValue(dict, "AutoNightTheme.NotAvailable")
        self.PrivateDataSettings_Title = getValue(dict, "PrivateDataSettings.Title")
        self.Bot_Start = getValue(dict, "Bot.Start")
        self._Channel_AdminLog_MessageChangedGroupAbout = getValue(dict, "Channel.AdminLog.MessageChangedGroupAbout")
        self._Channel_AdminLog_MessageChangedGroupAbout_r = extractArgumentRanges(self._Channel_AdminLog_MessageChangedGroupAbout)
        self.Appearance_PreviewReplyAuthor = getValue(dict, "Appearance.PreviewReplyAuthor")
        self.Notifications_TextTone = getValue(dict, "Notifications.TextTone")
        self.Settings_CallSettings = getValue(dict, "Settings.CallSettings")
        self._Watch_Time_ShortYesterdayAt = getValue(dict, "Watch.Time.ShortYesterdayAt")
        self._Watch_Time_ShortYesterdayAt_r = extractArgumentRanges(self._Watch_Time_ShortYesterdayAt)
        self.Contacts_InviteToTelegram = getValue(dict, "Contacts.InviteToTelegram")
        self._PINNED_DOC = getValue(dict, "PINNED_DOC")
        self._PINNED_DOC_r = extractArgumentRanges(self._PINNED_DOC)
        self.ChatSettings_PrivateChats = getValue(dict, "ChatSettings.PrivateChats")
        self.DialogList_Draft = getValue(dict, "DialogList.Draft")
        self.Channel_EditAdmin_PermissionDeleteMessages = getValue(dict, "Channel.EditAdmin.PermissionDeleteMessages")
        self.Channel_BanUser_PermissionSendStickersAndGifs = getValue(dict, "Channel.BanUser.PermissionSendStickersAndGifs")
        self.Conversation_CloudStorageInfo_Title = getValue(dict, "Conversation.CloudStorageInfo.Title")
        self.Conversation_ClearSecretHistory = getValue(dict, "Conversation.ClearSecretHistory")
        self.Passport_Identity_EditIdentityCard = getValue(dict, "Passport.Identity.EditIdentityCard")
        self.Notification_RenamedChannel = getValue(dict, "Notification.RenamedChannel")
        self.BlockedUsers_BlockUser = getValue(dict, "BlockedUsers.BlockUser")
        self.ChatSettings_TextSize = getValue(dict, "ChatSettings.TextSize")
        self.ChannelInfo_DeleteGroup = getValue(dict, "ChannelInfo.DeleteGroup")
        self.PhoneNumberHelp_Alert = getValue(dict, "PhoneNumberHelp.Alert")
        self._PINNED_TEXT = getValue(dict, "PINNED_TEXT")
        self._PINNED_TEXT_r = extractArgumentRanges(self._PINNED_TEXT)
        self.Watch_ChannelInfo_Title = getValue(dict, "Watch.ChannelInfo.Title")
        self.WebSearch_RecentSectionClear = getValue(dict, "WebSearch.RecentSectionClear")
        self.Channel_AdminLogFilter_AdminsAll = getValue(dict, "Channel.AdminLogFilter.AdminsAll")
        self.Channel_Setup_TypePrivate = getValue(dict, "Channel.Setup.TypePrivate")
        self.PhotoEditor_TintTool = getValue(dict, "PhotoEditor.TintTool")
        self.Watch_Suggestion_CantTalk = getValue(dict, "Watch.Suggestion.CantTalk")
        self.PhotoEditor_QualityHigh = getValue(dict, "PhotoEditor.QualityHigh")
        self.SocksProxySetup_AddProxyTitle = getValue(dict, "SocksProxySetup.AddProxyTitle")
        self._CHAT_MESSAGE_STICKER = getValue(dict, "CHAT_MESSAGE_STICKER")
        self._CHAT_MESSAGE_STICKER_r = extractArgumentRanges(self._CHAT_MESSAGE_STICKER)
        self.Map_ChooseAPlace = getValue(dict, "Map.ChooseAPlace")
        self.Passport_Identity_NamePlaceholder = getValue(dict, "Passport.Identity.NamePlaceholder")
        self.Passport_ScanPassport = getValue(dict, "Passport.ScanPassport")
        self.Map_ShareLiveLocationHelp = getValue(dict, "Map.ShareLiveLocationHelp")
        self.Watch_Bot_Restart = getValue(dict, "Watch.Bot.Restart")
        self.Passport_RequestedInformation = getValue(dict, "Passport.RequestedInformation")
        self.Channel_About_Help = getValue(dict, "Channel.About.Help")
        self.Web_OpenExternal = getValue(dict, "Web.OpenExternal")
        self.Passport_Language_mn = getValue(dict, "Passport.Language.mn")
        self.UserInfo_AddContact = getValue(dict, "UserInfo.AddContact")
        self.Privacy_ContactsSync = getValue(dict, "Privacy.ContactsSync")
        self.SocksProxySetup_Connection = getValue(dict, "SocksProxySetup.Connection")
        self.Passport_NotLoggedInMessage = getValue(dict, "Passport.NotLoggedInMessage")
        self.Passport_PasswordPlaceholder = getValue(dict, "Passport.PasswordPlaceholder")
        self.Passport_PasswordCreate = getValue(dict, "Passport.PasswordCreate")
        self.SocksProxySetup_ProxyStatusChecking = getValue(dict, "SocksProxySetup.ProxyStatusChecking")
        self.Call_EncryptionKey_Title = getValue(dict, "Call.EncryptionKey.Title")
        self.PhotoEditor_BlurToolLinear = getValue(dict, "PhotoEditor.BlurToolLinear")
        self.AuthSessions_EmptyText = getValue(dict, "AuthSessions.EmptyText")
        self.Notification_MessageLifetime1m = getValue(dict, "Notification.MessageLifetime1m")
        self._Call_StatusBar = getValue(dict, "Call.StatusBar")
        self._Call_StatusBar_r = extractArgumentRanges(self._Call_StatusBar)
        self.EditProfile_NameAndPhotoHelp = getValue(dict, "EditProfile.NameAndPhotoHelp")
        self.NotificationsSound_Tritone = getValue(dict, "NotificationsSound.Tritone")
        self.Passport_FieldAddressUploadHelp = getValue(dict, "Passport.FieldAddressUploadHelp")
        self.Month_ShortJuly = getValue(dict, "Month.ShortJuly")
        self.CheckoutInfo_ShippingInfoAddress1Placeholder = getValue(dict, "CheckoutInfo.ShippingInfoAddress1Placeholder")
        self.Watch_MessageView_ViewOnPhone = getValue(dict, "Watch.MessageView.ViewOnPhone")
        self.CallSettings_Never = getValue(dict, "CallSettings.Never")
        self.Passport_Identity_TypeInternalPassportUploadScan = getValue(dict, "Passport.Identity.TypeInternalPassportUploadScan")
        self.TwoStepAuth_EmailSent = getValue(dict, "TwoStepAuth.EmailSent")
        self._Notification_PinnedAnimationMessage = getValue(dict, "Notification.PinnedAnimationMessage")
        self._Notification_PinnedAnimationMessage_r = extractArgumentRanges(self._Notification_PinnedAnimationMessage)
        self.TwoStepAuth_RecoveryTitle = getValue(dict, "TwoStepAuth.RecoveryTitle")
        self.Notifications_MessageNotificationsExceptions = getValue(dict, "Notifications.MessageNotificationsExceptions")
        self.WatchRemote_AlertOpen = getValue(dict, "WatchRemote.AlertOpen")
        self.ExplicitContent_AlertChannel = getValue(dict, "ExplicitContent.AlertChannel")
        self.Notification_PassportValueEmail = getValue(dict, "Notification.PassportValueEmail")
        self.ContactInfo_PhoneLabelMobile = getValue(dict, "ContactInfo.PhoneLabelMobile")
        self.Widget_AuthRequired = getValue(dict, "Widget.AuthRequired")
        self._ForwardedAuthors2 = getValue(dict, "ForwardedAuthors2")
        self._ForwardedAuthors2_r = extractArgumentRanges(self._ForwardedAuthors2)
        self.ChannelInfo_DeleteGroupConfirmation = getValue(dict, "ChannelInfo.DeleteGroupConfirmation")
        self.TwoStepAuth_ConfirmationText = getValue(dict, "TwoStepAuth.ConfirmationText")
        self.Login_SmsRequestState3 = getValue(dict, "Login.SmsRequestState3")
        self.Notifications_AlertTones = getValue(dict, "Notifications.AlertTones")
        self._Time_MonthOfYear_m10 = getValue(dict, "Time.MonthOfYear_m10")
        self._Time_MonthOfYear_m10_r = extractArgumentRanges(self._Time_MonthOfYear_m10)
        self.Login_InfoAvatarPhoto = getValue(dict, "Login.InfoAvatarPhoto")
        self.Calls_TabTitle = getValue(dict, "Calls.TabTitle")
        self.Map_YouAreHere = getValue(dict, "Map.YouAreHere")
        self.PhotoEditor_CurvesTool = getValue(dict, "PhotoEditor.CurvesTool")
        self.Map_LiveLocationFor1Hour = getValue(dict, "Map.LiveLocationFor1Hour")
        self.AutoNightTheme_AutomaticSection = getValue(dict, "AutoNightTheme.AutomaticSection")
        self.Stickers_NoStickersFound = getValue(dict, "Stickers.NoStickersFound")
        self.Passport_Identity_AddIdentityCard = getValue(dict, "Passport.Identity.AddIdentityCard")
        self._Notification_JoinedChannel = getValue(dict, "Notification.JoinedChannel")
        self._Notification_JoinedChannel_r = extractArgumentRanges(self._Notification_JoinedChannel)
        self.Passport_Language_et = getValue(dict, "Passport.Language.et")
        self.Passport_Language_en = getValue(dict, "Passport.Language.en")
        self.GroupInfo_ActionRestrict = getValue(dict, "GroupInfo.ActionRestrict")
        self.Checkout_ShippingOption_Title = getValue(dict, "Checkout.ShippingOption.Title")
        self.Stickers_SuggestStickers = getValue(dict, "Stickers.SuggestStickers")
        self._Channel_AdminLog_MessageKickedName = getValue(dict, "Channel.AdminLog.MessageKickedName")
        self._Channel_AdminLog_MessageKickedName_r = extractArgumentRanges(self._Channel_AdminLog_MessageKickedName)
        self.Conversation_EncryptionProcessing = getValue(dict, "Conversation.EncryptionProcessing")
        self._CHAT_ADD_MEMBER = getValue(dict, "CHAT_ADD_MEMBER")
        self._CHAT_ADD_MEMBER_r = extractArgumentRanges(self._CHAT_ADD_MEMBER)
        self.Weekday_ShortSunday = getValue(dict, "Weekday.ShortSunday")
        self.Privacy_ContactsResetConfirmation = getValue(dict, "Privacy.ContactsResetConfirmation")
        self.Month_ShortJune = getValue(dict, "Month.ShortJune")
        self.Privacy_Calls_Integration = getValue(dict, "Privacy.Calls.Integration")
        self.Channel_TypeSetup_Title = getValue(dict, "Channel.TypeSetup.Title")
        self.Month_GenApril = getValue(dict, "Month.GenApril")
        self.StickerPacksSettings_ShowStickersButton = getValue(dict, "StickerPacksSettings.ShowStickersButton")
        self.CheckoutInfo_ShippingInfoTitle = getValue(dict, "CheckoutInfo.ShippingInfoTitle")
        self.Notification_PassportValueProofOfAddress = getValue(dict, "Notification.PassportValueProofOfAddress")
        self.StickerPacksSettings_ShowStickersButtonHelp = getValue(dict, "StickerPacksSettings.ShowStickersButtonHelp")
        self._Compatibility_SecretMediaVersionTooLow = getValue(dict, "Compatibility.SecretMediaVersionTooLow")
        self._Compatibility_SecretMediaVersionTooLow_r = extractArgumentRanges(self._Compatibility_SecretMediaVersionTooLow)
        self.CallSettings_RecentCalls = getValue(dict, "CallSettings.RecentCalls")
        self._Conversation_Megabytes = getValue(dict, "Conversation.Megabytes")
        self._Conversation_Megabytes_r = extractArgumentRanges(self._Conversation_Megabytes)
        self.Conversation_SearchByName_Prefix = getValue(dict, "Conversation.SearchByName.Prefix")
        self.TwoStepAuth_FloodError = getValue(dict, "TwoStepAuth.FloodError")
        self.Paint_Stickers = getValue(dict, "Paint.Stickers")
        self.Login_InvalidCountryCode = getValue(dict, "Login.InvalidCountryCode")
        self.Privacy_Calls_AlwaysAllow_Title = getValue(dict, "Privacy.Calls.AlwaysAllow.Title")
        self.Username_InvalidTooShort = getValue(dict, "Username.InvalidTooShort")
        self._Settings_ApplyProxyAlert = getValue(dict, "Settings.ApplyProxyAlert")
        self._Settings_ApplyProxyAlert_r = extractArgumentRanges(self._Settings_ApplyProxyAlert)
        self.Weekday_ShortFriday = getValue(dict, "Weekday.ShortFriday")
        self._Login_BannedPhoneBody = getValue(dict, "Login.BannedPhoneBody")
        self._Login_BannedPhoneBody_r = extractArgumentRanges(self._Login_BannedPhoneBody)
        self.Conversation_ClearAll = getValue(dict, "Conversation.ClearAll")
        self.Conversation_EditingMessageMediaChange = getValue(dict, "Conversation.EditingMessageMediaChange")
        self.Passport_FieldIdentityTranslationHelp = getValue(dict, "Passport.FieldIdentityTranslationHelp")
        self.Call_ReportIncludeLog = getValue(dict, "Call.ReportIncludeLog")
        self._Time_MonthOfYear_m3 = getValue(dict, "Time.MonthOfYear_m3")
        self._Time_MonthOfYear_m3_r = extractArgumentRanges(self._Time_MonthOfYear_m3)
        self.SharedMedia_EmptyTitle = getValue(dict, "SharedMedia.EmptyTitle")
        self.Call_PhoneCallInProgressMessage = getValue(dict, "Call.PhoneCallInProgressMessage")
        self.Notification_GroupActivated = getValue(dict, "Notification.GroupActivated")
        self.Checkout_Name = getValue(dict, "Checkout.Name")
        self.Passport_Address_PostcodePlaceholder = getValue(dict, "Passport.Address.PostcodePlaceholder")
        self._AUTH_REGION = getValue(dict, "AUTH_REGION")
        self._AUTH_REGION_r = extractArgumentRanges(self._AUTH_REGION)
        self.Settings_NotificationsAndSounds = getValue(dict, "Settings.NotificationsAndSounds")
        self.Conversation_EncryptionCanceled = getValue(dict, "Conversation.EncryptionCanceled")
        self._GroupInfo_InvitationLinkAcceptChannel = getValue(dict, "GroupInfo.InvitationLinkAcceptChannel")
        self._GroupInfo_InvitationLinkAcceptChannel_r = extractArgumentRanges(self._GroupInfo_InvitationLinkAcceptChannel)
        self.AccessDenied_SaveMedia = getValue(dict, "AccessDenied.SaveMedia")
        self.InviteText_URL = getValue(dict, "InviteText.URL")
        self.Passport_CorrectErrors = getValue(dict, "Passport.CorrectErrors")
        self._Channel_AdminLog_MessageInvitedNameUsername = getValue(dict, "Channel.AdminLog.MessageInvitedNameUsername")
        self._Channel_AdminLog_MessageInvitedNameUsername_r = extractArgumentRanges(self._Channel_AdminLog_MessageInvitedNameUsername)
        self.Compose_GroupTokenListPlaceholder = getValue(dict, "Compose.GroupTokenListPlaceholder")
        self.Passport_Address_CityPlaceholder = getValue(dict, "Passport.Address.CityPlaceholder")
        self.Passport_InfoFAQ_URL = getValue(dict, "Passport.InfoFAQ_URL")
        self.Conversation_MessageDeliveryFailed = getValue(dict, "Conversation.MessageDeliveryFailed")
        self.Privacy_PaymentsClear_PaymentInfo = getValue(dict, "Privacy.PaymentsClear.PaymentInfo")
        self.Notifications_GroupNotifications = getValue(dict, "Notifications.GroupNotifications")
        self.CheckoutInfo_SaveInfoHelp = getValue(dict, "CheckoutInfo.SaveInfoHelp")
        self.Notification_Mute1hMin = getValue(dict, "Notification.Mute1hMin")
        self.Privacy_TopPeersWarning = getValue(dict, "Privacy.TopPeersWarning")
        self.StickerPacksSettings_ArchivedMasks_Info = getValue(dict, "StickerPacksSettings.ArchivedMasks.Info")
        self.ChannelMembers_WhoCanAddMembers_AllMembers = getValue(dict, "ChannelMembers.WhoCanAddMembers.AllMembers")
        self.Channel_Edit_PrivatePublicLinkAlert = getValue(dict, "Channel.Edit.PrivatePublicLinkAlert")
        self.Watch_Conversation_UserInfo = getValue(dict, "Watch.Conversation.UserInfo")
        self.Application_Name = getValue(dict, "Application.Name")
        self.Conversation_AddToReadingList = getValue(dict, "Conversation.AddToReadingList")
        self.Conversation_FileDropbox = getValue(dict, "Conversation.FileDropbox")
        self.Login_PhonePlaceholder = getValue(dict, "Login.PhonePlaceholder")
        self.SocksProxySetup_ProxyEnabled = getValue(dict, "SocksProxySetup.ProxyEnabled")
        self.Profile_MessageLifetime1d = getValue(dict, "Profile.MessageLifetime1d")
        self.CheckoutInfo_ShippingInfoCityPlaceholder = getValue(dict, "CheckoutInfo.ShippingInfoCityPlaceholder")
        self.Calls_CallTabDescription = getValue(dict, "Calls.CallTabDescription")
        self.Passport_DeletePersonalDetails = getValue(dict, "Passport.DeletePersonalDetails")
        self.Passport_Address_AddBankStatement = getValue(dict, "Passport.Address.AddBankStatement")
        self.Resolve_ErrorNotFound = getValue(dict, "Resolve.ErrorNotFound")
        self.PhotoEditor_FadeTool = getValue(dict, "PhotoEditor.FadeTool")
        self.Channel_Setup_TypePublicHelp = getValue(dict, "Channel.Setup.TypePublicHelp")
        self.GroupInfo_InviteLink_RevokeAlert_Success = getValue(dict, "GroupInfo.InviteLink.RevokeAlert.Success")
        self.Channel_Setup_PublicNoLink = getValue(dict, "Channel.Setup.PublicNoLink")
        self.Privacy_Calls_P2PHelp = getValue(dict, "Privacy.Calls.P2PHelp")
        self.Conversation_Info = getValue(dict, "Conversation.Info")
        self._Time_TodayAt = getValue(dict, "Time.TodayAt")
        self._Time_TodayAt_r = extractArgumentRanges(self._Time_TodayAt)
        self.AutoDownloadSettings_VideosTitle = getValue(dict, "AutoDownloadSettings.VideosTitle")
        self.Conversation_Processing = getValue(dict, "Conversation.Processing")
        self.Conversation_RestrictedInline = getValue(dict, "Conversation.RestrictedInline")
        self._InstantPage_AuthorAndDateTitle = getValue(dict, "InstantPage.AuthorAndDateTitle")
        self._InstantPage_AuthorAndDateTitle_r = extractArgumentRanges(self._InstantPage_AuthorAndDateTitle)
        self._Watch_LastSeen_AtDate = getValue(dict, "Watch.LastSeen.AtDate")
        self._Watch_LastSeen_AtDate_r = extractArgumentRanges(self._Watch_LastSeen_AtDate)
        self.Conversation_Location = getValue(dict, "Conversation.Location")
        self.DialogList_PasscodeLockHelp = getValue(dict, "DialogList.PasscodeLockHelp")
        self.Channel_Management_Title = getValue(dict, "Channel.Management.Title")
        self.Notifications_InAppNotificationsPreview = getValue(dict, "Notifications.InAppNotificationsPreview")
        self.EnterPasscode_EnterTitle = getValue(dict, "EnterPasscode.EnterTitle")
        self.ReportPeer_ReasonOther_Title = getValue(dict, "ReportPeer.ReasonOther.Title")
        self.Month_GenJanuary = getValue(dict, "Month.GenJanuary")
        self.Conversation_ForwardChats = getValue(dict, "Conversation.ForwardChats")
        self.Channel_UpdatePhotoItem = getValue(dict, "Channel.UpdatePhotoItem")
        self.UserInfo_StartSecretChat = getValue(dict, "UserInfo.StartSecretChat")
        self.PrivacySettings_LastSeenNobody = getValue(dict, "PrivacySettings.LastSeenNobody")
        self._FileSize_MB = getValue(dict, "FileSize.MB")
        self._FileSize_MB_r = extractArgumentRanges(self._FileSize_MB)
        self.ChatSearch_SearchPlaceholder = getValue(dict, "ChatSearch.SearchPlaceholder")
        self.TwoStepAuth_ConfirmationAbort = getValue(dict, "TwoStepAuth.ConfirmationAbort")
        self.FastTwoStepSetup_HintSection = getValue(dict, "FastTwoStepSetup.HintSection")
        self.TwoStepAuth_SetupPasswordConfirmFailed = getValue(dict, "TwoStepAuth.SetupPasswordConfirmFailed")
        self._LastSeen_YesterdayAt = getValue(dict, "LastSeen.YesterdayAt")
        self._LastSeen_YesterdayAt_r = extractArgumentRanges(self._LastSeen_YesterdayAt)
        self.GroupInfo_GroupHistoryVisible = getValue(dict, "GroupInfo.GroupHistoryVisible")
        self.AppleWatch_ReplyPresetsHelp = getValue(dict, "AppleWatch.ReplyPresetsHelp")
        self.Localization_LanguageName = getValue(dict, "Localization.LanguageName")
        self.Map_OpenIn = getValue(dict, "Map.OpenIn")
        self.Message_File = getValue(dict, "Message.File")
        self.Call_ReportSend = getValue(dict, "Call.ReportSend")
        self._Channel_AdminLog_MessageChangedGroupUsername = getValue(dict, "Channel.AdminLog.MessageChangedGroupUsername")
        self._Channel_AdminLog_MessageChangedGroupUsername_r = extractArgumentRanges(self._Channel_AdminLog_MessageChangedGroupUsername)
        self._CHAT_MESSAGE_GAME = getValue(dict, "CHAT_MESSAGE_GAME")
        self._CHAT_MESSAGE_GAME_r = extractArgumentRanges(self._CHAT_MESSAGE_GAME)
        self._Time_PreciseDate_m1 = getValue(dict, "Time.PreciseDate_m1")
        self._Time_PreciseDate_m1_r = extractArgumentRanges(self._Time_PreciseDate_m1)
        self.Month_ShortMay = getValue(dict, "Month.ShortMay")
        self.Tour_Text3 = getValue(dict, "Tour.Text3")
        self.Contacts_GlobalSearch = getValue(dict, "Contacts.GlobalSearch")
        self.DialogList_LanguageTooltip = getValue(dict, "DialogList.LanguageTooltip")
        self.AuthSessions_LogOutApplications = getValue(dict, "AuthSessions.LogOutApplications")
        self.Map_LoadError = getValue(dict, "Map.LoadError")
        self.Settings_ProxyConnecting = getValue(dict, "Settings.ProxyConnecting")
        self.Passport_Language_fa = getValue(dict, "Passport.Language.fa")
        self.AccessDenied_VoiceMicrophone = getValue(dict, "AccessDenied.VoiceMicrophone")
        self._CHANNEL_MESSAGE_STICKER = getValue(dict, "CHANNEL_MESSAGE_STICKER")
        self._CHANNEL_MESSAGE_STICKER_r = extractArgumentRanges(self._CHANNEL_MESSAGE_STICKER)
        self.Passport_Address_TypeUtilityBillUploadScan = getValue(dict, "Passport.Address.TypeUtilityBillUploadScan")
        self.PrivacySettings_Title = getValue(dict, "PrivacySettings.Title")
        self.PasscodeSettings_TurnPasscodeOff = getValue(dict, "PasscodeSettings.TurnPasscodeOff")
        self.MediaPicker_AddCaption = getValue(dict, "MediaPicker.AddCaption")
        self.Channel_AdminLog_BanReadMessages = getValue(dict, "Channel.AdminLog.BanReadMessages")
        self.Channel_Status = getValue(dict, "Channel.Status")
        self.Map_ChooseLocationTitle = getValue(dict, "Map.ChooseLocationTitle")
        self.Map_OpenInYandexNavigator = getValue(dict, "Map.OpenInYandexNavigator")
        self.AutoNightTheme_PreferredTheme = getValue(dict, "AutoNightTheme.PreferredTheme")
        self.State_WaitingForNetwork = getValue(dict, "State.WaitingForNetwork")
        self.TwoStepAuth_EmailHelp = getValue(dict, "TwoStepAuth.EmailHelp")
        self.Conversation_StopLiveLocation = getValue(dict, "Conversation.StopLiveLocation")
        self.Privacy_SecretChatsLinkPreviewsHelp = getValue(dict, "Privacy.SecretChatsLinkPreviewsHelp")
        self.PhotoEditor_SharpenTool = getValue(dict, "PhotoEditor.SharpenTool")
        self.Common_of = getValue(dict, "Common.of")
        self.AuthSessions_Title = getValue(dict, "AuthSessions.Title")
        self.Passport_Scans_UploadNew = getValue(dict, "Passport.Scans.UploadNew")
        self.Message_PinnedLiveLocationMessage = getValue(dict, "Message.PinnedLiveLocationMessage")
        self.Passport_FieldIdentityDetailsHelp = getValue(dict, "Passport.FieldIdentityDetailsHelp")
        self.PrivacyLastSeenSettings_AlwaysShareWith = getValue(dict, "PrivacyLastSeenSettings.AlwaysShareWith")
        self.EnterPasscode_EnterPasscode = getValue(dict, "EnterPasscode.EnterPasscode")
        self.Notifications_Reset = getValue(dict, "Notifications.Reset")
        self._Map_LiveLocationPrivateDescription = getValue(dict, "Map.LiveLocationPrivateDescription")
        self._Map_LiveLocationPrivateDescription_r = extractArgumentRanges(self._Map_LiveLocationPrivateDescription)
        self.GroupInfo_InvitationLinkGroupFull = getValue(dict, "GroupInfo.InvitationLinkGroupFull")
        self._Channel_AdminLog_MessageChangedChannelUsername = getValue(dict, "Channel.AdminLog.MessageChangedChannelUsername")
        self._Channel_AdminLog_MessageChangedChannelUsername_r = extractArgumentRanges(self._Channel_AdminLog_MessageChangedChannelUsername)
        self._CHAT_MESSAGE_DOC = getValue(dict, "CHAT_MESSAGE_DOC")
        self._CHAT_MESSAGE_DOC_r = extractArgumentRanges(self._CHAT_MESSAGE_DOC)
        self.Watch_AppName = getValue(dict, "Watch.AppName")
        self.ConvertToSupergroup_HelpTitle = getValue(dict, "ConvertToSupergroup.HelpTitle")
        self.Conversation_TapAndHoldToRecord = getValue(dict, "Conversation.TapAndHoldToRecord")
        self._MESSAGE_GIF = getValue(dict, "MESSAGE_GIF")
        self._MESSAGE_GIF_r = extractArgumentRanges(self._MESSAGE_GIF)
        self._DialogList_EncryptedChatStartedOutgoing = getValue(dict, "DialogList.EncryptedChatStartedOutgoing")
        self._DialogList_EncryptedChatStartedOutgoing_r = extractArgumentRanges(self._DialogList_EncryptedChatStartedOutgoing)
        self.Checkout_PayWithTouchId = getValue(dict, "Checkout.PayWithTouchId")
        self.Passport_Language_ko = getValue(dict, "Passport.Language.ko")
        self.Conversation_DiscardVoiceMessageTitle = getValue(dict, "Conversation.DiscardVoiceMessageTitle")
        self._CHAT_ADD_YOU = getValue(dict, "CHAT_ADD_YOU")
        self._CHAT_ADD_YOU_r = extractArgumentRanges(self._CHAT_ADD_YOU)
        self.CheckoutInfo_ShippingInfoCity = getValue(dict, "CheckoutInfo.ShippingInfoCity")
        self.Group_AdminLog_EmptyText = getValue(dict, "Group.AdminLog.EmptyText")
        self.AutoDownloadSettings_GroupChats = getValue(dict, "AutoDownloadSettings.GroupChats")
        self.Conversation_ClousStorageInfo_Description3 = getValue(dict, "Conversation.ClousStorageInfo.Description3")
        self.Notifications_ExceptionsMuted = getValue(dict, "Notifications.ExceptionsMuted")
        self.Conversation_PinMessageAlertGroup = getValue(dict, "Conversation.PinMessageAlertGroup")
        self.Settings_FAQ_Intro = getValue(dict, "Settings.FAQ_Intro")
        self.PrivacySettings_AuthSessions = getValue(dict, "PrivacySettings.AuthSessions")
        self._CHAT_MESSAGE_GEOLIVE = getValue(dict, "CHAT_MESSAGE_GEOLIVE")
        self._CHAT_MESSAGE_GEOLIVE_r = extractArgumentRanges(self._CHAT_MESSAGE_GEOLIVE)
        self.Passport_Address_Postcode = getValue(dict, "Passport.Address.Postcode")
        self.Tour_Title5 = getValue(dict, "Tour.Title5")
        self.ChatAdmins_AllMembersAreAdmins = getValue(dict, "ChatAdmins.AllMembersAreAdmins")
        self.Group_Management_AddModeratorHelp = getValue(dict, "Group.Management.AddModeratorHelp")
        self.Channel_Username_CheckingUsername = getValue(dict, "Channel.Username.CheckingUsername")
        self._DialogList_SingleRecordingVideoMessageSuffix = getValue(dict, "DialogList.SingleRecordingVideoMessageSuffix")
        self._DialogList_SingleRecordingVideoMessageSuffix_r = extractArgumentRanges(self._DialogList_SingleRecordingVideoMessageSuffix)
        self._Contacts_AccessDeniedHelpPortrait = getValue(dict, "Contacts.AccessDeniedHelpPortrait")
        self._Contacts_AccessDeniedHelpPortrait_r = extractArgumentRanges(self._Contacts_AccessDeniedHelpPortrait)
        self._Checkout_LiabilityAlert = getValue(dict, "Checkout.LiabilityAlert")
        self._Checkout_LiabilityAlert_r = extractArgumentRanges(self._Checkout_LiabilityAlert)
        self.Channel_Info_BlackList = getValue(dict, "Channel.Info.BlackList")
        self.Profile_BotInfo = getValue(dict, "Profile.BotInfo")
        self.Stickers_SuggestAll = getValue(dict, "Stickers.SuggestAll")
        self.Compose_NewChannel_Members = getValue(dict, "Compose.NewChannel.Members")
        self.Notification_Reply = getValue(dict, "Notification.Reply")
        self.Watch_Stickers_Recents = getValue(dict, "Watch.Stickers.Recents")
        self.GroupInfo_SetGroupPhotoStop = getValue(dict, "GroupInfo.SetGroupPhotoStop")
        self.Channel_Stickers_Placeholder = getValue(dict, "Channel.Stickers.Placeholder")
        self.AttachmentMenu_File = getValue(dict, "AttachmentMenu.File")
        self._MESSAGE_STICKER = getValue(dict, "MESSAGE_STICKER")
        self._MESSAGE_STICKER_r = extractArgumentRanges(self._MESSAGE_STICKER)
        self.Profile_MessageLifetime5s = getValue(dict, "Profile.MessageLifetime5s")
        self.Privacy_ContactsReset = getValue(dict, "Privacy.ContactsReset")
        self._PINNED_PHOTO = getValue(dict, "PINNED_PHOTO")
        self._PINNED_PHOTO_r = extractArgumentRanges(self._PINNED_PHOTO)
        self.Channel_AdminLog_CanAddAdmins = getValue(dict, "Channel.AdminLog.CanAddAdmins")
        self.TwoStepAuth_SetupHint = getValue(dict, "TwoStepAuth.SetupHint")
        self.Conversation_StatusLeftGroup = getValue(dict, "Conversation.StatusLeftGroup")
        self.Settings_CopyUsername = getValue(dict, "Settings.CopyUsername")
        self.Passport_Identity_CountryPlaceholder = getValue(dict, "Passport.Identity.CountryPlaceholder")
        self.ChatSettings_AutoDownloadDocuments = getValue(dict, "ChatSettings.AutoDownloadDocuments")
        self.MediaPicker_TapToUngroupDescription = getValue(dict, "MediaPicker.TapToUngroupDescription")
        self.Conversation_ShareBotLocationConfirmation = getValue(dict, "Conversation.ShareBotLocationConfirmation")
        self.Conversation_DeleteMessagesForMe = getValue(dict, "Conversation.DeleteMessagesForMe")
        self.Notification_PassportValuePersonalDetails = getValue(dict, "Notification.PassportValuePersonalDetails")
        self.Message_PinnedAnimationMessage = getValue(dict, "Message.PinnedAnimationMessage")
        self.Passport_FieldIdentityUploadHelp = getValue(dict, "Passport.FieldIdentityUploadHelp")
        self.SocksProxySetup_ConnectAndSave = getValue(dict, "SocksProxySetup.ConnectAndSave")
        self.SocksProxySetup_FailedToConnect = getValue(dict, "SocksProxySetup.FailedToConnect")
        self.Checkout_ErrorPrecheckoutFailed = getValue(dict, "Checkout.ErrorPrecheckoutFailed")
        self.Camera_PhotoMode = getValue(dict, "Camera.PhotoMode")
        self._Time_MonthOfYear_m2 = getValue(dict, "Time.MonthOfYear_m2")
        self._Time_MonthOfYear_m2_r = extractArgumentRanges(self._Time_MonthOfYear_m2)
        self.Channel_About_Placeholder = getValue(dict, "Channel.About.Placeholder")
        self.Map_Directions = getValue(dict, "Map.Directions")
        self.Channel_About_Title = getValue(dict, "Channel.About.Title")
        self._MESSAGE_PHOTO = getValue(dict, "MESSAGE_PHOTO")
        self._MESSAGE_PHOTO_r = extractArgumentRanges(self._MESSAGE_PHOTO)
        self.Calls_RatingTitle = getValue(dict, "Calls.RatingTitle")
        self.SharedMedia_EmptyText = getValue(dict, "SharedMedia.EmptyText")
        self.Channel_Stickers_Searching = getValue(dict, "Channel.Stickers.Searching")
        self.Passport_Address_AddUtilityBill = getValue(dict, "Passport.Address.AddUtilityBill")
        self.Login_PadPhoneHelp = getValue(dict, "Login.PadPhoneHelp")
        self.StickerPacksSettings_ArchivedPacks = getValue(dict, "StickerPacksSettings.ArchivedPacks")
        self.Passport_Language_th = getValue(dict, "Passport.Language.th")
        self.Channel_ErrorAccessDenied = getValue(dict, "Channel.ErrorAccessDenied")
        self.Generic_ErrorMoreInfo = getValue(dict, "Generic.ErrorMoreInfo")
        self.Channel_AdminLog_TitleAllEvents = getValue(dict, "Channel.AdminLog.TitleAllEvents")
        self.Settings_Proxy = getValue(dict, "Settings.Proxy")
        self.Passport_Language_lt = getValue(dict, "Passport.Language.lt")
        self.ChannelMembers_WhoCanAddMembersAllHelp = getValue(dict, "ChannelMembers.WhoCanAddMembersAllHelp")
        self.Passport_Address_CountryPlaceholder = getValue(dict, "Passport.Address.CountryPlaceholder")
        self.ChangePhoneNumberCode_CodePlaceholder = getValue(dict, "ChangePhoneNumberCode.CodePlaceholder")
        self.Camera_SquareMode = getValue(dict, "Camera.SquareMode")
        self._Conversation_EncryptedPlaceholderTitleOutgoing = getValue(dict, "Conversation.EncryptedPlaceholderTitleOutgoing")
        self._Conversation_EncryptedPlaceholderTitleOutgoing_r = extractArgumentRanges(self._Conversation_EncryptedPlaceholderTitleOutgoing)
        self.NetworkUsageSettings_CallDataSection = getValue(dict, "NetworkUsageSettings.CallDataSection")
        self.Login_PadPhoneHelpTitle = getValue(dict, "Login.PadPhoneHelpTitle")
        self.Profile_CreateNewContact = getValue(dict, "Profile.CreateNewContact")
        self.AccessDenied_VideoMessageMicrophone = getValue(dict, "AccessDenied.VideoMessageMicrophone")
        self.AutoDownloadSettings_VoiceMessagesTitle = getValue(dict, "AutoDownloadSettings.VoiceMessagesTitle")
        self.PhotoEditor_VignetteTool = getValue(dict, "PhotoEditor.VignetteTool")
        self.LastSeen_WithinAWeek = getValue(dict, "LastSeen.WithinAWeek")
        self.Widget_NoUsers = getValue(dict, "Widget.NoUsers")
        self.Passport_Identity_DocumentNumber = getValue(dict, "Passport.Identity.DocumentNumber")
        self.Application_Update = getValue(dict, "Application.Update")
        self.Calls_NewCall = getValue(dict, "Calls.NewCall")
        self._CHANNEL_MESSAGE_AUDIO = getValue(dict, "CHANNEL_MESSAGE_AUDIO")
        self._CHANNEL_MESSAGE_AUDIO_r = extractArgumentRanges(self._CHANNEL_MESSAGE_AUDIO)
        self.DialogList_NoMessagesText = getValue(dict, "DialogList.NoMessagesText")
        self.MaskStickerSettings_Info = getValue(dict, "MaskStickerSettings.Info")
        self.ChatSettings_AutoDownloadTitle = getValue(dict, "ChatSettings.AutoDownloadTitle")
        self.Passport_FieldAddressHelp = getValue(dict, "Passport.FieldAddressHelp")
        self.Passport_Language_dz = getValue(dict, "Passport.Language.dz")
        self.Conversation_FilePhotoOrVideo = getValue(dict, "Conversation.FilePhotoOrVideo")
        self.Channel_AdminLog_BanSendStickers = getValue(dict, "Channel.AdminLog.BanSendStickers")
        self.Common_Next = getValue(dict, "Common.Next")
        self.Stickers_RemoveFromFavorites = getValue(dict, "Stickers.RemoveFromFavorites")
        self.Watch_Notification_Joined = getValue(dict, "Watch.Notification.Joined")
        self._Channel_AdminLog_MessageRestrictedNewSetting = getValue(dict, "Channel.AdminLog.MessageRestrictedNewSetting")
        self._Channel_AdminLog_MessageRestrictedNewSetting_r = extractArgumentRanges(self._Channel_AdminLog_MessageRestrictedNewSetting)
        self.Passport_DeleteAddress = getValue(dict, "Passport.DeleteAddress")
        self.ContactInfo_PhoneLabelHome = getValue(dict, "ContactInfo.PhoneLabelHome")
        self.GroupInfo_DeleteAndExitConfirmation = getValue(dict, "GroupInfo.DeleteAndExitConfirmation")
        self.NotificationsSound_Tremolo = getValue(dict, "NotificationsSound.Tremolo")
        self.TwoStepAuth_EmailInvalid = getValue(dict, "TwoStepAuth.EmailInvalid")
        self.Privacy_ContactsTitle = getValue(dict, "Privacy.ContactsTitle")
        self.Passport_Address_TypeBankStatement = getValue(dict, "Passport.Address.TypeBankStatement")
        self._CHAT_MESSAGE_VIDEO = getValue(dict, "CHAT_MESSAGE_VIDEO")
        self._CHAT_MESSAGE_VIDEO_r = extractArgumentRanges(self._CHAT_MESSAGE_VIDEO)
        self.Month_GenJune = getValue(dict, "Month.GenJune")
        self.Map_LiveLocationFor15Minutes = getValue(dict, "Map.LiveLocationFor15Minutes")
        self._Login_EmailCodeSubject = getValue(dict, "Login.EmailCodeSubject")
        self._Login_EmailCodeSubject_r = extractArgumentRanges(self._Login_EmailCodeSubject)
        self._CHAT_TITLE_EDITED = getValue(dict, "CHAT_TITLE_EDITED")
        self._CHAT_TITLE_EDITED_r = extractArgumentRanges(self._CHAT_TITLE_EDITED)
        self.ContactInfo_PhoneLabelHomeFax = getValue(dict, "ContactInfo.PhoneLabelHomeFax")
        self._NetworkUsageSettings_WifiUsageSince = getValue(dict, "NetworkUsageSettings.WifiUsageSince")
        self._NetworkUsageSettings_WifiUsageSince_r = extractArgumentRanges(self._NetworkUsageSettings_WifiUsageSince)
        self.Watch_LastSeen_Lately = getValue(dict, "Watch.LastSeen.Lately")
        self.Watch_Compose_CurrentLocation = getValue(dict, "Watch.Compose.CurrentLocation")
        self.DialogList_RecentTitlePeople = getValue(dict, "DialogList.RecentTitlePeople")
        self.GroupInfo_Notifications = getValue(dict, "GroupInfo.Notifications")
        self.Call_ReportPlaceholder = getValue(dict, "Call.ReportPlaceholder")
        self._AuthSessions_Message = getValue(dict, "AuthSessions.Message")
        self._AuthSessions_Message_r = extractArgumentRanges(self._AuthSessions_Message)
        self._MESSAGE_DOC = getValue(dict, "MESSAGE_DOC")
        self._MESSAGE_DOC_r = extractArgumentRanges(self._MESSAGE_DOC)
        self.Group_Username_CreatePrivateLinkHelp = getValue(dict, "Group.Username.CreatePrivateLinkHelp")
        self.Notifications_GroupNotificationsSound = getValue(dict, "Notifications.GroupNotificationsSound")
        self.AuthSessions_EmptyTitle = getValue(dict, "AuthSessions.EmptyTitle")
        self.Privacy_GroupsAndChannels_AlwaysAllow_Title = getValue(dict, "Privacy.GroupsAndChannels.AlwaysAllow.Title")
        self.Passport_Language_he = getValue(dict, "Passport.Language.he")
        self._MediaPicker_Nof = getValue(dict, "MediaPicker.Nof")
        self._MediaPicker_Nof_r = extractArgumentRanges(self._MediaPicker_Nof)
        self.Common_Create = getValue(dict, "Common.Create")
        self.Contacts_TopSection = getValue(dict, "Contacts.TopSection")
        self._Map_DirectionsDriveEta = getValue(dict, "Map.DirectionsDriveEta")
        self._Map_DirectionsDriveEta_r = extractArgumentRanges(self._Map_DirectionsDriveEta)
        self.PrivacyPolicy_DeclineMessage = getValue(dict, "PrivacyPolicy.DeclineMessage")
        self.Your_cards_number_is_invalid = getValue(dict, "Your_cards_number_is_invalid")
        self._MESSAGE_INVOICE = getValue(dict, "MESSAGE_INVOICE")
        self._MESSAGE_INVOICE_r = extractArgumentRanges(self._MESSAGE_INVOICE)
        self.Localization_LanguageCustom = getValue(dict, "Localization.LanguageCustom")
        self._Channel_AdminLog_MessageRemovedChannelUsername = getValue(dict, "Channel.AdminLog.MessageRemovedChannelUsername")
        self._Channel_AdminLog_MessageRemovedChannelUsername_r = extractArgumentRanges(self._Channel_AdminLog_MessageRemovedChannelUsername)
        self.Group_MessagePhotoRemoved = getValue(dict, "Group.MessagePhotoRemoved")
        self.UserInfo_AddToExisting = getValue(dict, "UserInfo.AddToExisting")
        self.NotificationsSound_Aurora = getValue(dict, "NotificationsSound.Aurora")
        self._LastSeen_AtDate = getValue(dict, "LastSeen.AtDate")
        self._LastSeen_AtDate_r = extractArgumentRanges(self._LastSeen_AtDate)
        self.Conversation_MessageDialogRetry = getValue(dict, "Conversation.MessageDialogRetry")
        self.Watch_ChatList_NoConversationsTitle = getValue(dict, "Watch.ChatList.NoConversationsTitle")
        self.Passport_Language_my = getValue(dict, "Passport.Language.my")
        self.Stickers_GroupStickers = getValue(dict, "Stickers.GroupStickers")
        self.BlockedUsers_Title = getValue(dict, "BlockedUsers.Title")
        self._LiveLocationUpdated_TodayAt = getValue(dict, "LiveLocationUpdated.TodayAt")
        self._LiveLocationUpdated_TodayAt_r = extractArgumentRanges(self._LiveLocationUpdated_TodayAt)
        self.ContactInfo_PhoneLabelWork = getValue(dict, "ContactInfo.PhoneLabelWork")
        self.ChatSettings_ConnectionType_UseSocks5 = getValue(dict, "ChatSettings.ConnectionType.UseSocks5")
        self.Passport_FieldAddressTranslationHelp = getValue(dict, "Passport.FieldAddressTranslationHelp")
        self.Cache_ClearNone = getValue(dict, "Cache.ClearNone")
        self.SecretTimer_VideoDescription = getValue(dict, "SecretTimer.VideoDescription")
        self.Login_InvalidCodeError = getValue(dict, "Login.InvalidCodeError")
        self.Channel_BanList_BlockedTitle = getValue(dict, "Channel.BanList.BlockedTitle")
        self.Passport_PasswordHelp = getValue(dict, "Passport.PasswordHelp")
        self.NetworkUsageSettings_Cellular = getValue(dict, "NetworkUsageSettings.Cellular")
        self.Watch_Location_Access = getValue(dict, "Watch.Location.Access")
        self.PrivacySettings_DeleteAccountIfAwayFor = getValue(dict, "PrivacySettings.DeleteAccountIfAwayFor")
        self.Channel_AdminLog_EmptyFilterText = getValue(dict, "Channel.AdminLog.EmptyFilterText")
        self.Channel_AdminLog_EmptyText = getValue(dict, "Channel.AdminLog.EmptyText")
        self.PrivacySettings_DeleteAccountTitle = getValue(dict, "PrivacySettings.DeleteAccountTitle")
        self.Passport_Language_ms = getValue(dict, "Passport.Language.ms")
        self.PrivacyLastSeenSettings_CustomShareSettings_Delete = getValue(dict, "PrivacyLastSeenSettings.CustomShareSettings.Delete")
        self._ENCRYPTED_MESSAGE = getValue(dict, "ENCRYPTED_MESSAGE")
        self._ENCRYPTED_MESSAGE_r = extractArgumentRanges(self._ENCRYPTED_MESSAGE)
        self.Watch_LastSeen_WithinAMonth = getValue(dict, "Watch.LastSeen.WithinAMonth")
        self.PrivacyLastSeenSettings_CustomHelp = getValue(dict, "PrivacyLastSeenSettings.CustomHelp")
        self.TwoStepAuth_EnterPasswordHelp = getValue(dict, "TwoStepAuth.EnterPasswordHelp")
        self.Bot_Stop = getValue(dict, "Bot.Stop")
        self.Privacy_GroupsAndChannels_AlwaysAllow_Placeholder = getValue(dict, "Privacy.GroupsAndChannels.AlwaysAllow.Placeholder")
        self.UserInfo_BotSettings = getValue(dict, "UserInfo.BotSettings")
        self.Your_cards_expiration_month_is_invalid = getValue(dict, "Your_cards_expiration_month_is_invalid")
        self.Passport_FieldIdentity = getValue(dict, "Passport.FieldIdentity")
        self.PrivacyLastSeenSettings_EmpryUsersPlaceholder = getValue(dict, "PrivacyLastSeenSettings.EmpryUsersPlaceholder")
        self.Passport_Identity_EditInternalPassport = getValue(dict, "Passport.Identity.EditInternalPassport")
        self._CHANNEL_MESSAGE_ROUND = getValue(dict, "CHANNEL_MESSAGE_ROUND")
        self._CHANNEL_MESSAGE_ROUND_r = extractArgumentRanges(self._CHANNEL_MESSAGE_ROUND)
        self.Passport_Identity_LatinNameHelp = getValue(dict, "Passport.Identity.LatinNameHelp")
        self.SocksProxySetup_Port = getValue(dict, "SocksProxySetup.Port")
        self.Message_VideoMessage = getValue(dict, "Message.VideoMessage")
        self.Conversation_ContextMenuStickerPackInfo = getValue(dict, "Conversation.ContextMenuStickerPackInfo")
        self.Login_ResetAccountProtected_LimitExceeded = getValue(dict, "Login.ResetAccountProtected.LimitExceeded")
        self._CHAT_DELETE_MEMBER = getValue(dict, "CHAT_DELETE_MEMBER")
        self._CHAT_DELETE_MEMBER_r = extractArgumentRanges(self._CHAT_DELETE_MEMBER)
        self.Conversation_DiscardVoiceMessageAction = getValue(dict, "Conversation.DiscardVoiceMessageAction")
        self.Camera_Title = getValue(dict, "Camera.Title")
        self.Passport_Identity_IssueDate = getValue(dict, "Passport.Identity.IssueDate")
        self.PhotoEditor_CurvesBlue = getValue(dict, "PhotoEditor.CurvesBlue")
        self.Message_PinnedVideoMessage = getValue(dict, "Message.PinnedVideoMessage")
        self._Login_EmailPhoneSubject = getValue(dict, "Login.EmailPhoneSubject")
        self._Login_EmailPhoneSubject_r = extractArgumentRanges(self._Login_EmailPhoneSubject)
        self.Passport_Phone_UseTelegramNumberHelp = getValue(dict, "Passport.Phone.UseTelegramNumberHelp")
        self.Group_EditAdmin_PermissionChangeInfo = getValue(dict, "Group.EditAdmin.PermissionChangeInfo")
        self.TwoStepAuth_Email = getValue(dict, "TwoStepAuth.Email")
        self.Stickers_SuggestNone = getValue(dict, "Stickers.SuggestNone")
        self.Map_SendMyCurrentLocation = getValue(dict, "Map.SendMyCurrentLocation")
        self._MESSAGE_ROUND = getValue(dict, "MESSAGE_ROUND")
        self._MESSAGE_ROUND_r = extractArgumentRanges(self._MESSAGE_ROUND)
        self.Passport_Identity_IssueDatePlaceholder = getValue(dict, "Passport.Identity.IssueDatePlaceholder")
        self.Map_Unknown = getValue(dict, "Map.Unknown")
        self.Wallpaper_Set = getValue(dict, "Wallpaper.Set")
        self.AccessDenied_Title = getValue(dict, "AccessDenied.Title")
        self.SharedMedia_CategoryLinks = getValue(dict, "SharedMedia.CategoryLinks")
        self.Localization_LanguageOther = getValue(dict, "Localization.LanguageOther")
        self._CHAT_MESSAGES = getValue(dict, "CHAT_MESSAGES")
        self._CHAT_MESSAGES_r = extractArgumentRanges(self._CHAT_MESSAGES)
        self.SaveIncomingPhotosSettings_Title = getValue(dict, "SaveIncomingPhotosSettings.Title")
        self.Passport_Identity_TypeDriversLicense = getValue(dict, "Passport.Identity.TypeDriversLicense")
        self.FastTwoStepSetup_HintHelp = getValue(dict, "FastTwoStepSetup.HintHelp")
        self.Notifications_ExceptionsDefaultSound = getValue(dict, "Notifications.ExceptionsDefaultSound")
        self.TwoStepAuth_EmailSkipAlert = getValue(dict, "TwoStepAuth.EmailSkipAlert")
        self.ChatSettings_Stickers = getValue(dict, "ChatSettings.Stickers")
        self.Camera_FlashOff = getValue(dict, "Camera.FlashOff")
        self.TwoStepAuth_Title = getValue(dict, "TwoStepAuth.Title")
        self.Passport_Identity_Translation = getValue(dict, "Passport.Identity.Translation")
        self.Checkout_ErrorProviderAccountTimeout = getValue(dict, "Checkout.ErrorProviderAccountTimeout")
        self.TwoStepAuth_SetupPasswordEnterPasswordChange = getValue(dict, "TwoStepAuth.SetupPasswordEnterPasswordChange")
        self.WebSearch_Images = getValue(dict, "WebSearch.Images")
        self.Conversation_typing = getValue(dict, "Conversation.typing")
        self.Common_Back = getValue(dict, "Common.Back")
        self.PrivacySettings_DataSettingsHelp = getValue(dict, "PrivacySettings.DataSettingsHelp")
        self.Passport_Language_es = getValue(dict, "Passport.Language.es")
        self.Common_Search = getValue(dict, "Common.Search")
        self._CancelResetAccount_Success = getValue(dict, "CancelResetAccount.Success")
        self._CancelResetAccount_Success_r = extractArgumentRanges(self._CancelResetAccount_Success)
        self.Common_No = getValue(dict, "Common.No")
        self.Login_EmailNotConfiguredError = getValue(dict, "Login.EmailNotConfiguredError")
        self.Watch_Suggestion_OK = getValue(dict, "Watch.Suggestion.OK")
        self.Profile_AddToExisting = getValue(dict, "Profile.AddToExisting")
        self._Passport_Identity_NativeNameTitle = getValue(dict, "Passport.Identity.NativeNameTitle")
        self._Passport_Identity_NativeNameTitle_r = extractArgumentRanges(self._Passport_Identity_NativeNameTitle)
        self._PINNED_NOTEXT = getValue(dict, "PINNED_NOTEXT")
        self._PINNED_NOTEXT_r = extractArgumentRanges(self._PINNED_NOTEXT)
        self._Login_EmailCodeBody = getValue(dict, "Login.EmailCodeBody")
        self._Login_EmailCodeBody_r = extractArgumentRanges(self._Login_EmailCodeBody)
        self.NotificationsSound_Keys = getValue(dict, "NotificationsSound.Keys")
        self.Passport_Phone_Title = getValue(dict, "Passport.Phone.Title")
        self.Profile_About = getValue(dict, "Profile.About")
        self._EncryptionKey_Description = getValue(dict, "EncryptionKey.Description")
        self._EncryptionKey_Description_r = extractArgumentRanges(self._EncryptionKey_Description)
        self.Conversation_UnreadMessages = getValue(dict, "Conversation.UnreadMessages")
        self._DialogList_LiveLocationSharingTo = getValue(dict, "DialogList.LiveLocationSharingTo")
        self._DialogList_LiveLocationSharingTo_r = extractArgumentRanges(self._DialogList_LiveLocationSharingTo)
        self.Tour_Title3 = getValue(dict, "Tour.Title3")
        self.Passport_Identity_FrontSide = getValue(dict, "Passport.Identity.FrontSide")
        self.PrivacyLastSeenSettings_GroupsAndChannelsHelp = getValue(dict, "PrivacyLastSeenSettings.GroupsAndChannelsHelp")
        self.Watch_Contacts_NoResults = getValue(dict, "Watch.Contacts.NoResults")
        self.Passport_Language_id = getValue(dict, "Passport.Language.id")
        self.Passport_Identity_TypeIdentityCardUploadScan = getValue(dict, "Passport.Identity.TypeIdentityCardUploadScan")
        self.Watch_UserInfo_MuteTitle = getValue(dict, "Watch.UserInfo.MuteTitle")
        self._Privacy_GroupsAndChannels_InviteToGroupError = getValue(dict, "Privacy.GroupsAndChannels.InviteToGroupError")
        self._Privacy_GroupsAndChannels_InviteToGroupError_r = extractArgumentRanges(self._Privacy_GroupsAndChannels_InviteToGroupError)
        self._Message_PinnedTextMessage = getValue(dict, "Message.PinnedTextMessage")
        self._Message_PinnedTextMessage_r = extractArgumentRanges(self._Message_PinnedTextMessage)
        self._Watch_Time_ShortWeekdayAt = getValue(dict, "Watch.Time.ShortWeekdayAt")
        self._Watch_Time_ShortWeekdayAt_r = extractArgumentRanges(self._Watch_Time_ShortWeekdayAt)
        self.Conversation_EmptyGifPanelPlaceholder = getValue(dict, "Conversation.EmptyGifPanelPlaceholder")
        self.DialogList_Typing = getValue(dict, "DialogList.Typing")
        self.Notification_CallBack = getValue(dict, "Notification.CallBack")
        self.Passport_Language_ru = getValue(dict, "Passport.Language.ru")
        self.Map_LocatingError = getValue(dict, "Map.LocatingError")
        self.InfoPlist_NSFaceIDUsageDescription = getValue(dict, "InfoPlist.NSFaceIDUsageDescription")
        self.MediaPicker_Send = getValue(dict, "MediaPicker.Send")
        self.ChannelIntro_Title = getValue(dict, "ChannelIntro.Title")
        self.AccessDenied_LocationAlwaysDenied = getValue(dict, "AccessDenied.LocationAlwaysDenied")
        self._PINNED_GIF = getValue(dict, "PINNED_GIF")
        self._PINNED_GIF_r = extractArgumentRanges(self._PINNED_GIF)
        self._InviteText_SingleContact = getValue(dict, "InviteText.SingleContact")
        self._InviteText_SingleContact_r = extractArgumentRanges(self._InviteText_SingleContact)
        self.Passport_Address_TypePassportRegistration = getValue(dict, "Passport.Address.TypePassportRegistration")
        self.Channel_EditAdmin_CannotEdit = getValue(dict, "Channel.EditAdmin.CannotEdit")
        self.LoginPassword_PasswordHelp = getValue(dict, "LoginPassword.PasswordHelp")
        self.BlockedUsers_Unblock = getValue(dict, "BlockedUsers.Unblock")
        self.AutoDownloadSettings_Cellular = getValue(dict, "AutoDownloadSettings.Cellular")
        self.Passport_Language_ro = getValue(dict, "Passport.Language.ro")
        self._Time_MonthOfYear_m1 = getValue(dict, "Time.MonthOfYear_m1")
        self._Time_MonthOfYear_m1_r = extractArgumentRanges(self._Time_MonthOfYear_m1)
        self.Appearance_PreviewIncomingText = getValue(dict, "Appearance.PreviewIncomingText")
        self.Passport_Identity_DateOfBirthPlaceholder = getValue(dict, "Passport.Identity.DateOfBirthPlaceholder")
        self.Notifications_GroupNotificationsAlert = getValue(dict, "Notifications.GroupNotificationsAlert")
        self.Paint_Masks = getValue(dict, "Paint.Masks")
        self.Appearance_ThemeDayClassic = getValue(dict, "Appearance.ThemeDayClassic")
        self.StickerPack_ErrorNotFound = getValue(dict, "StickerPack.ErrorNotFound")
        self.Appearance_ThemeNight = getValue(dict, "Appearance.ThemeNight")
        self.SecretTimer_ImageDescription = getValue(dict, "SecretTimer.ImageDescription")
        self._PINNED_CONTACT = getValue(dict, "PINNED_CONTACT")
        self._PINNED_CONTACT_r = extractArgumentRanges(self._PINNED_CONTACT)
        self._FileSize_KB = getValue(dict, "FileSize.KB")
        self._FileSize_KB_r = extractArgumentRanges(self._FileSize_KB)
        self.Map_LiveLocationTitle = getValue(dict, "Map.LiveLocationTitle")
        self.Watch_GroupInfo_Title = getValue(dict, "Watch.GroupInfo.Title")
        self.Channel_AdminLog_EmptyTitle = getValue(dict, "Channel.AdminLog.EmptyTitle")
        self.PhotoEditor_Set = getValue(dict, "PhotoEditor.Set")
        self.LiveLocation_MenuStopAll = getValue(dict, "LiveLocation.MenuStopAll")
        self.SocksProxySetup_AddProxy = getValue(dict, "SocksProxySetup.AddProxy")
        self._Notification_Invited = getValue(dict, "Notification.Invited")
        self._Notification_Invited_r = extractArgumentRanges(self._Notification_Invited)
        self.Watch_AuthRequired = getValue(dict, "Watch.AuthRequired")
        self.Conversation_EncryptedDescription1 = getValue(dict, "Conversation.EncryptedDescription1")
        self.AppleWatch_ReplyPresets = getValue(dict, "AppleWatch.ReplyPresets")
        self.Channel_Members_AddAdminErrorNotAMember = getValue(dict, "Channel.Members.AddAdminErrorNotAMember")
        self.Conversation_EncryptedDescription2 = getValue(dict, "Conversation.EncryptedDescription2")
        self.SocksProxySetup_HostnamePlaceholder = getValue(dict, "SocksProxySetup.HostnamePlaceholder")
        self.NetworkUsageSettings_MediaVideoDataSection = getValue(dict, "NetworkUsageSettings.MediaVideoDataSection")
        self.Paint_Edit = getValue(dict, "Paint.Edit")
        self.Passport_Language_nl = getValue(dict, "Passport.Language.nl")
        self.Conversation_EncryptedDescription3 = getValue(dict, "Conversation.EncryptedDescription3")
        self.Login_CodeFloodError = getValue(dict, "Login.CodeFloodError")
        self.Conversation_EncryptedDescription4 = getValue(dict, "Conversation.EncryptedDescription4")
        self.AppleWatch_Title = getValue(dict, "AppleWatch.Title")
        self.Contacts_AccessDeniedError = getValue(dict, "Contacts.AccessDeniedError")
        self.Conversation_StatusTyping = getValue(dict, "Conversation.StatusTyping")
        self.Share_Title = getValue(dict, "Share.Title")
        self.TwoStepAuth_ConfirmationTitle = getValue(dict, "TwoStepAuth.ConfirmationTitle")
        self.Passport_Identity_FilesTitle = getValue(dict, "Passport.Identity.FilesTitle")
        self.ChatSettings_Title = getValue(dict, "ChatSettings.Title")
        self.AuthSessions_CurrentSession = getValue(dict, "AuthSessions.CurrentSession")
        self.Watch_Microphone_Access = getValue(dict, "Watch.Microphone.Access")
        self._Notification_RenamedChat = getValue(dict, "Notification.RenamedChat")
        self._Notification_RenamedChat_r = extractArgumentRanges(self._Notification_RenamedChat)
        self.Conversation_LiveLocation = getValue(dict, "Conversation.LiveLocation")
        self.Watch_Conversation_GroupInfo = getValue(dict, "Watch.Conversation.GroupInfo")
        self.Passport_Language_fr = getValue(dict, "Passport.Language.fr")
        self.UserInfo_Title = getValue(dict, "UserInfo.Title")
        self.Passport_Identity_DoesNotExpire = getValue(dict, "Passport.Identity.DoesNotExpire")
        self.Map_LiveLocationGroupDescription = getValue(dict, "Map.LiveLocationGroupDescription")
        self.Login_InfoHelp = getValue(dict, "Login.InfoHelp")
        self.ShareMenu_ShareTo = getValue(dict, "ShareMenu.ShareTo")
        self.Message_PinnedGame = getValue(dict, "Message.PinnedGame")
        self.Channel_AdminLog_CanSendMessages = getValue(dict, "Channel.AdminLog.CanSendMessages")
        self._AutoNightTheme_LocationHelp = getValue(dict, "AutoNightTheme.LocationHelp")
        self._AutoNightTheme_LocationHelp_r = extractArgumentRanges(self._AutoNightTheme_LocationHelp)
        self.Notification_RenamedGroup = getValue(dict, "Notification.RenamedGroup")
        self._Call_PrivacyErrorMessage = getValue(dict, "Call.PrivacyErrorMessage")
        self._Call_PrivacyErrorMessage_r = extractArgumentRanges(self._Call_PrivacyErrorMessage)
        self.Passport_Address_Street = getValue(dict, "Passport.Address.Street")
        self.FastTwoStepSetup_HintPlaceholder = getValue(dict, "FastTwoStepSetup.HintPlaceholder")
        self.PrivacySettings_DataSettings = getValue(dict, "PrivacySettings.DataSettings")
        self.ChangePhoneNumberNumber_Title = getValue(dict, "ChangePhoneNumberNumber.Title")
        self.NotificationsSound_Bell = getValue(dict, "NotificationsSound.Bell")
        self.TwoStepAuth_EnterPasswordInvalid = getValue(dict, "TwoStepAuth.EnterPasswordInvalid")
        self.DialogList_SearchSectionMessages = getValue(dict, "DialogList.SearchSectionMessages")
        self.Media_ShareThisVideo = getValue(dict, "Media.ShareThisVideo")
        self.Call_ReportIncludeLogDescription = getValue(dict, "Call.ReportIncludeLogDescription")
        self.Preview_DeleteGif = getValue(dict, "Preview.DeleteGif")
        self.Passport_Address_OneOfTypeTemporaryRegistration = getValue(dict, "Passport.Address.OneOfTypeTemporaryRegistration")
        self.UserInfo_DeleteContact = getValue(dict, "UserInfo.DeleteContact")
        self.Notifications_ResetAllNotifications = getValue(dict, "Notifications.ResetAllNotifications")
        self.SocksProxySetup_SaveProxy = getValue(dict, "SocksProxySetup.SaveProxy")
        self.Passport_Identity_Country = getValue(dict, "Passport.Identity.Country")
        self.Notification_MessageLifetimeRemovedOutgoing = getValue(dict, "Notification.MessageLifetimeRemovedOutgoing")
        self.Login_ContinueWithLocalization = getValue(dict, "Login.ContinueWithLocalization")
        self.GroupInfo_AddParticipant = getValue(dict, "GroupInfo.AddParticipant")
        self.Watch_Location_Current = getValue(dict, "Watch.Location.Current")
        self.Checkout_NewCard_SaveInfoHelp = getValue(dict, "Checkout.NewCard.SaveInfoHelp")
        self._Settings_ApplyProxyAlertCredentials = getValue(dict, "Settings.ApplyProxyAlertCredentials")
        self._Settings_ApplyProxyAlertCredentials_r = extractArgumentRanges(self._Settings_ApplyProxyAlertCredentials)
        self.MediaPicker_CameraRoll = getValue(dict, "MediaPicker.CameraRoll")
        self.Channel_AdminLog_CanPinMessages = getValue(dict, "Channel.AdminLog.CanPinMessages")
        self.KeyCommand_NewMessage = getValue(dict, "KeyCommand.NewMessage")
        self._ChannelInfo_AddParticipantConfirmation = getValue(dict, "ChannelInfo.AddParticipantConfirmation")
        self._ChannelInfo_AddParticipantConfirmation_r = extractArgumentRanges(self._ChannelInfo_AddParticipantConfirmation)
        self.NetworkUsageSettings_TotalSection = getValue(dict, "NetworkUsageSettings.TotalSection")
        self._PINNED_AUDIO = getValue(dict, "PINNED_AUDIO")
        self._PINNED_AUDIO_r = extractArgumentRanges(self._PINNED_AUDIO)
        self.Privacy_GroupsAndChannels = getValue(dict, "Privacy.GroupsAndChannels")
        self._Time_PreciseDate_m12 = getValue(dict, "Time.PreciseDate_m12")
        self._Time_PreciseDate_m12_r = extractArgumentRanges(self._Time_PreciseDate_m12)
        self.Conversation_DiscardVoiceMessageDescription = getValue(dict, "Conversation.DiscardVoiceMessageDescription")
        self.Passport_Address_ScansHelp = getValue(dict, "Passport.Address.ScansHelp")
        self._Notification_ChangedGroupPhoto = getValue(dict, "Notification.ChangedGroupPhoto")
        self._Notification_ChangedGroupPhoto_r = extractArgumentRanges(self._Notification_ChangedGroupPhoto)
        self.TwoStepAuth_RemovePassword = getValue(dict, "TwoStepAuth.RemovePassword")
        self.Privacy_GroupsAndChannels_CustomHelp = getValue(dict, "Privacy.GroupsAndChannels.CustomHelp")
        self.Passport_Identity_Gender = getValue(dict, "Passport.Identity.Gender")
        self.UserInfo_NotificationsDisable = getValue(dict, "UserInfo.NotificationsDisable")
        self.Watch_UserInfo_Service = getValue(dict, "Watch.UserInfo.Service")
        self.Privacy_Calls_CustomHelp = getValue(dict, "Privacy.Calls.CustomHelp")
        self.ChangePhoneNumberCode_Code = getValue(dict, "ChangePhoneNumberCode.Code")
        self.UserInfo_Invite = getValue(dict, "UserInfo.Invite")
        self.CheckoutInfo_ErrorStateInvalid = getValue(dict, "CheckoutInfo.ErrorStateInvalid")
        self.DialogList_ClearHistoryConfirmation = getValue(dict, "DialogList.ClearHistoryConfirmation")
        self.CheckoutInfo_ErrorEmailInvalid = getValue(dict, "CheckoutInfo.ErrorEmailInvalid")
        self.Month_GenNovember = getValue(dict, "Month.GenNovember")
        self.UserInfo_NotificationsEnable = getValue(dict, "UserInfo.NotificationsEnable")
        self._Target_InviteToGroupConfirmation = getValue(dict, "Target.InviteToGroupConfirmation")
        self._Target_InviteToGroupConfirmation_r = extractArgumentRanges(self._Target_InviteToGroupConfirmation)
        self.Map_Map = getValue(dict, "Map.Map")
        self.Map_OpenInMaps = getValue(dict, "Map.OpenInMaps")
        self.Common_OK = getValue(dict, "Common.OK")
        self.TwoStepAuth_SetupHintTitle = getValue(dict, "TwoStepAuth.SetupHintTitle")
        self.GroupInfo_LeftStatus = getValue(dict, "GroupInfo.LeftStatus")
        self.Cache_ClearProgress = getValue(dict, "Cache.ClearProgress")
        self.Login_InvalidPhoneError = getValue(dict, "Login.InvalidPhoneError")
        self.Passport_Authorize = getValue(dict, "Passport.Authorize")
        self.Cache_ClearEmpty = getValue(dict, "Cache.ClearEmpty")
        self.Map_Search = getValue(dict, "Map.Search")
        self.Passport_Identity_Translations = getValue(dict, "Passport.Identity.Translations")
        self.ChannelMembers_GroupAdminsTitle = getValue(dict, "ChannelMembers.GroupAdminsTitle")
        self._Channel_AdminLog_MessageRemovedGroupUsername = getValue(dict, "Channel.AdminLog.MessageRemovedGroupUsername")
        self._Channel_AdminLog_MessageRemovedGroupUsername_r = extractArgumentRanges(self._Channel_AdminLog_MessageRemovedGroupUsername)
        self.ChatSettings_AutomaticPhotoDownload = getValue(dict, "ChatSettings.AutomaticPhotoDownload")
        self.Group_ErrorAddTooMuchAdmins = getValue(dict, "Group.ErrorAddTooMuchAdmins")
        self.SocksProxySetup_Password = getValue(dict, "SocksProxySetup.Password")
        self.Login_SelectCountry_Title = getValue(dict, "Login.SelectCountry.Title")
        self._MESSAGE_PHOTOS = getValue(dict, "MESSAGE_PHOTOS")
        self._MESSAGE_PHOTOS_r = extractArgumentRanges(self._MESSAGE_PHOTOS)
        self.Notifications_GroupNotificationsHelp = getValue(dict, "Notifications.GroupNotificationsHelp")
        self.PhotoEditor_CropAspectRatioSquare = getValue(dict, "PhotoEditor.CropAspectRatioSquare")
        self.Notification_CallOutgoing = getValue(dict, "Notification.CallOutgoing")
        self.UserInfo_NotificationsDefault = getValue(dict, "UserInfo.NotificationsDefault")
        self.Weekday_ShortMonday = getValue(dict, "Weekday.ShortMonday")
        self.Checkout_Receipt_Title = getValue(dict, "Checkout.Receipt.Title")
        self.Channel_Edit_AboutItem = getValue(dict, "Channel.Edit.AboutItem")
        self.Login_InfoLastNamePlaceholder = getValue(dict, "Login.InfoLastNamePlaceholder")
        self.Channel_Members_AddMembersHelp = getValue(dict, "Channel.Members.AddMembersHelp")
        self._MESSAGE_VIDEO_SECRET = getValue(dict, "MESSAGE_VIDEO_SECRET")
        self._MESSAGE_VIDEO_SECRET_r = extractArgumentRanges(self._MESSAGE_VIDEO_SECRET)
        self.Settings_CopyPhoneNumber = getValue(dict, "Settings.CopyPhoneNumber")
        self.ReportPeer_Report = getValue(dict, "ReportPeer.Report")
        self.Channel_EditMessageErrorGeneric = getValue(dict, "Channel.EditMessageErrorGeneric")
        self.Passport_Identity_TranslationsHelp = getValue(dict, "Passport.Identity.TranslationsHelp")
        self.LoginPassword_FloodError = getValue(dict, "LoginPassword.FloodError")
        self.TwoStepAuth_SetupPasswordTitle = getValue(dict, "TwoStepAuth.SetupPasswordTitle")
        self.PhotoEditor_DiscardChanges = getValue(dict, "PhotoEditor.DiscardChanges")
        self.Group_UpgradeNoticeText2 = getValue(dict, "Group.UpgradeNoticeText2")
        self._PINNED_ROUND = getValue(dict, "PINNED_ROUND")
        self._PINNED_ROUND_r = extractArgumentRanges(self._PINNED_ROUND)
        self._ChannelInfo_ChannelForbidden = getValue(dict, "ChannelInfo.ChannelForbidden")
        self._ChannelInfo_ChannelForbidden_r = extractArgumentRanges(self._ChannelInfo_ChannelForbidden)
        self.Conversation_ShareMyContactInfo = getValue(dict, "Conversation.ShareMyContactInfo")
        self.SocksProxySetup_UsernamePlaceholder = getValue(dict, "SocksProxySetup.UsernamePlaceholder")
        self._CHANNEL_MESSAGE_GEO = getValue(dict, "CHANNEL_MESSAGE_GEO")
        self._CHANNEL_MESSAGE_GEO_r = extractArgumentRanges(self._CHANNEL_MESSAGE_GEO)
        self.Contacts_PhoneNumber = getValue(dict, "Contacts.PhoneNumber")
        self.Group_Info_AdminLog = getValue(dict, "Group.Info.AdminLog")
        self.Channel_AdminLogFilter_ChannelEventsInfo = getValue(dict, "Channel.AdminLogFilter.ChannelEventsInfo")
        self.ChatSettings_AutoDownloadEnabled = getValue(dict, "ChatSettings.AutoDownloadEnabled")
        self.StickerPacksSettings_FeaturedPacks = getValue(dict, "StickerPacksSettings.FeaturedPacks")
        self.AuthSessions_LoggedIn = getValue(dict, "AuthSessions.LoggedIn")
        self.Month_GenAugust = getValue(dict, "Month.GenAugust")
        self.Notification_CallCanceled = getValue(dict, "Notification.CallCanceled")
        self.Channel_Username_CreatePublicLinkHelp = getValue(dict, "Channel.Username.CreatePublicLinkHelp")
        self.StickerPack_Send = getValue(dict, "StickerPack.Send")
        self.StickerSettings_MaskContextInfo = getValue(dict, "StickerSettings.MaskContextInfo")
        self.Watch_Suggestion_HoldOn = getValue(dict, "Watch.Suggestion.HoldOn")
        self._PINNED_GEO = getValue(dict, "PINNED_GEO")
        self._PINNED_GEO_r = extractArgumentRanges(self._PINNED_GEO)
        self.PasscodeSettings_EncryptData = getValue(dict, "PasscodeSettings.EncryptData")
        self.Common_NotNow = getValue(dict, "Common.NotNow")
        self.FastTwoStepSetup_PasswordConfirmationPlaceholder = getValue(dict, "FastTwoStepSetup.PasswordConfirmationPlaceholder")
        self.PasscodeSettings_Title = getValue(dict, "PasscodeSettings.Title")
        self.StickerPack_BuiltinPackName = getValue(dict, "StickerPack.BuiltinPackName")
        self.Appearance_AccentColor = getValue(dict, "Appearance.AccentColor")
        self.Watch_Suggestion_BRB = getValue(dict, "Watch.Suggestion.BRB")
        self._CHAT_MESSAGE_ROUND = getValue(dict, "CHAT_MESSAGE_ROUND")
        self._CHAT_MESSAGE_ROUND_r = extractArgumentRanges(self._CHAT_MESSAGE_ROUND)
        self.Notifications_MessageNotificationsAlert = getValue(dict, "Notifications.MessageNotificationsAlert")
        self.Username_InvalidCharacters = getValue(dict, "Username.InvalidCharacters")
        self.GroupInfo_LabelAdmin = getValue(dict, "GroupInfo.LabelAdmin")
        self.GroupInfo_Sound = getValue(dict, "GroupInfo.Sound")
        self.Channel_EditAdmin_PermissionBanUsers = getValue(dict, "Channel.EditAdmin.PermissionBanUsers")
        self.InfoPlist_NSCameraUsageDescription = getValue(dict, "InfoPlist.NSCameraUsageDescription")
        self.Passport_Address_AddRentalAgreement = getValue(dict, "Passport.Address.AddRentalAgreement")
        self.Wallpaper_PhotoLibrary = getValue(dict, "Wallpaper.PhotoLibrary")
        self.Settings_About = getValue(dict, "Settings.About")
        self.Privacy_Calls_IntegrationHelp = getValue(dict, "Privacy.Calls.IntegrationHelp")
        self.ContactInfo_Job = getValue(dict, "ContactInfo.Job")
        self._CHAT_LEFT = getValue(dict, "CHAT_LEFT")
        self._CHAT_LEFT_r = extractArgumentRanges(self._CHAT_LEFT)
        self.LoginPassword_ForgotPassword = getValue(dict, "LoginPassword.ForgotPassword")
        self.Passport_Address_AddTemporaryRegistration = getValue(dict, "Passport.Address.AddTemporaryRegistration")
        self._Map_LiveLocationShortHour = getValue(dict, "Map.LiveLocationShortHour")
        self._Map_LiveLocationShortHour_r = extractArgumentRanges(self._Map_LiveLocationShortHour)
        self.Appearance_Preview = getValue(dict, "Appearance.Preview")
        self._DialogList_AwaitingEncryption = getValue(dict, "DialogList.AwaitingEncryption")
        self._DialogList_AwaitingEncryption_r = extractArgumentRanges(self._DialogList_AwaitingEncryption)
        self.Passport_Identity_TypePassport = getValue(dict, "Passport.Identity.TypePassport")
        self.ChatSettings_Appearance = getValue(dict, "ChatSettings.Appearance")
        self.Tour_Title1 = getValue(dict, "Tour.Title1")
        self.Conversation_EditingCaptionPanelTitle = getValue(dict, "Conversation.EditingCaptionPanelTitle")
        self._Notifications_ExceptionsChangeSound = getValue(dict, "Notifications.ExceptionsChangeSound")
        self._Notifications_ExceptionsChangeSound_r = extractArgumentRanges(self._Notifications_ExceptionsChangeSound)
        self.Conversation_LinkDialogCopy = getValue(dict, "Conversation.LinkDialogCopy")
        self._Notification_PinnedLocationMessage = getValue(dict, "Notification.PinnedLocationMessage")
        self._Notification_PinnedLocationMessage_r = extractArgumentRanges(self._Notification_PinnedLocationMessage)
        self._Notification_PinnedPhotoMessage = getValue(dict, "Notification.PinnedPhotoMessage")
        self._Notification_PinnedPhotoMessage_r = extractArgumentRanges(self._Notification_PinnedPhotoMessage)
        self._DownloadingStatus = getValue(dict, "DownloadingStatus")
        self._DownloadingStatus_r = extractArgumentRanges(self._DownloadingStatus)
        self.Calls_All = getValue(dict, "Calls.All")
        self._Channel_MessageTitleUpdated = getValue(dict, "Channel.MessageTitleUpdated")
        self._Channel_MessageTitleUpdated_r = extractArgumentRanges(self._Channel_MessageTitleUpdated)
        self.Call_CallAgain = getValue(dict, "Call.CallAgain")
        self.Message_VideoExpired = getValue(dict, "Message.VideoExpired")
        self.TwoStepAuth_RecoveryCodeHelp = getValue(dict, "TwoStepAuth.RecoveryCodeHelp")
        self._Channel_AdminLog_MessagePromotedNameUsername = getValue(dict, "Channel.AdminLog.MessagePromotedNameUsername")
        self._Channel_AdminLog_MessagePromotedNameUsername_r = extractArgumentRanges(self._Channel_AdminLog_MessagePromotedNameUsername)
        self.UserInfo_SendMessage = getValue(dict, "UserInfo.SendMessage")
        self._Channel_Username_LinkHint = getValue(dict, "Channel.Username.LinkHint")
        self._Channel_Username_LinkHint_r = extractArgumentRanges(self._Channel_Username_LinkHint)
        self._AutoDownloadSettings_UpTo = getValue(dict, "AutoDownloadSettings.UpTo")
        self._AutoDownloadSettings_UpTo_r = extractArgumentRanges(self._AutoDownloadSettings_UpTo)
        self.Settings_ViewPhoto = getValue(dict, "Settings.ViewPhoto")
        self.Paint_RecentStickers = getValue(dict, "Paint.RecentStickers")
        self._Passport_PrivacyPolicy = getValue(dict, "Passport.PrivacyPolicy")
        self._Passport_PrivacyPolicy_r = extractArgumentRanges(self._Passport_PrivacyPolicy)
        self.Login_CallRequestState3 = getValue(dict, "Login.CallRequestState3")
        self.Channel_Edit_LinkItem = getValue(dict, "Channel.Edit.LinkItem")
        self.CallSettings_Title = getValue(dict, "CallSettings.Title")
        self.ChangePhoneNumberNumber_Help = getValue(dict, "ChangePhoneNumberNumber.Help")
        self.Passport_InfoTitle = getValue(dict, "Passport.InfoTitle")
        self.Watch_Suggestion_Thanks = getValue(dict, "Watch.Suggestion.Thanks")
        self.Channel_Moderator_Title = getValue(dict, "Channel.Moderator.Title")
        self.Message_PinnedPhotoMessage = getValue(dict, "Message.PinnedPhotoMessage")
        self.Notification_SecretChatScreenshot = getValue(dict, "Notification.SecretChatScreenshot")
        self._Conversation_DeleteMessagesFor = getValue(dict, "Conversation.DeleteMessagesFor")
        self._Conversation_DeleteMessagesFor_r = extractArgumentRanges(self._Conversation_DeleteMessagesFor)
        self.Activity_UploadingDocument = getValue(dict, "Activity.UploadingDocument")
        self.Watch_ChatList_NoConversationsText = getValue(dict, "Watch.ChatList.NoConversationsText")
        self.ReportPeer_AlertSuccess = getValue(dict, "ReportPeer.AlertSuccess")
        self.Tour_Text4 = getValue(dict, "Tour.Text4")
        self.Channel_Info_Description = getValue(dict, "Channel.Info.Description")
        self.AccessDenied_LocationTracking = getValue(dict, "AccessDenied.LocationTracking")
        self.Watch_Compose_Send = getValue(dict, "Watch.Compose.Send")
        self.SocksProxySetup_UseForCallsHelp = getValue(dict, "SocksProxySetup.UseForCallsHelp")
        self.Preview_CopyAddress = getValue(dict, "Preview.CopyAddress")
        self.Settings_BlockedUsers = getValue(dict, "Settings.BlockedUsers")
        self.Month_ShortAugust = getValue(dict, "Month.ShortAugust")
        self.Passport_Identity_MainPage = getValue(dict, "Passport.Identity.MainPage")
        self.Passport_FieldAddress = getValue(dict, "Passport.FieldAddress")
        self.Channel_AdminLogFilter_AdminsTitle = getValue(dict, "Channel.AdminLogFilter.AdminsTitle")
        self.Channel_EditAdmin_PermissionChangeInfo = getValue(dict, "Channel.EditAdmin.PermissionChangeInfo")
        self.Notifications_ResetAllNotificationsHelp = getValue(dict, "Notifications.ResetAllNotificationsHelp")
        self.DialogList_EncryptionRejected = getValue(dict, "DialogList.EncryptionRejected")
        self.Target_InviteToGroupErrorAlreadyInvited = getValue(dict, "Target.InviteToGroupErrorAlreadyInvited")
        self.AccessDenied_CameraRestricted = getValue(dict, "AccessDenied.CameraRestricted")
        self.Watch_Message_ForwardedFrom = getValue(dict, "Watch.Message.ForwardedFrom")
        self.CheckoutInfo_ShippingInfoCountryPlaceholder = getValue(dict, "CheckoutInfo.ShippingInfoCountryPlaceholder")
        self.Channel_AboutItem = getValue(dict, "Channel.AboutItem")
        self.PhotoEditor_CurvesGreen = getValue(dict, "PhotoEditor.CurvesGreen")
        self.Month_GenJuly = getValue(dict, "Month.GenJuly")
        self.ContactInfo_URLLabelHomepage = getValue(dict, "ContactInfo.URLLabelHomepage")
        self.PrivacyPolicy_DeclineDeclineAndDelete = getValue(dict, "PrivacyPolicy.DeclineDeclineAndDelete")
        self._DialogList_SingleUploadingFileSuffix = getValue(dict, "DialogList.SingleUploadingFileSuffix")
        self._DialogList_SingleUploadingFileSuffix_r = extractArgumentRanges(self._DialogList_SingleUploadingFileSuffix)
        self.ChannelIntro_CreateChannel = getValue(dict, "ChannelIntro.CreateChannel")
        self.Channel_Management_AddModerator = getValue(dict, "Channel.Management.AddModerator")
        self.Common_ChoosePhoto = getValue(dict, "Common.ChoosePhoto")
        self.Conversation_Pin = getValue(dict, "Conversation.Pin")
        self._Login_ResetAccountProtected_Text = getValue(dict, "Login.ResetAccountProtected.Text")
        self._Login_ResetAccountProtected_Text_r = extractArgumentRanges(self._Login_ResetAccountProtected_Text)
        self._Channel_AdminLog_EmptyFilterQueryText = getValue(dict, "Channel.AdminLog.EmptyFilterQueryText")
        self._Channel_AdminLog_EmptyFilterQueryText_r = extractArgumentRanges(self._Channel_AdminLog_EmptyFilterQueryText)
        self.Camera_TapAndHoldForVideo = getValue(dict, "Camera.TapAndHoldForVideo")
        self.Bot_DescriptionTitle = getValue(dict, "Bot.DescriptionTitle")
        self.FeaturedStickerPacks_Title = getValue(dict, "FeaturedStickerPacks.Title")
        self.Map_OpenInGoogleMaps = getValue(dict, "Map.OpenInGoogleMaps")
        self.Notification_MessageLifetime5s = getValue(dict, "Notification.MessageLifetime5s")
        self.Contacts_Title = getValue(dict, "Contacts.Title")
        self._MESSAGES = getValue(dict, "MESSAGES")
        self._MESSAGES_r = extractArgumentRanges(self._MESSAGES)
        self.Channel_Management_AddModeratorHelp = getValue(dict, "Channel.Management.AddModeratorHelp")
        self._CHAT_MESSAGE_FWDS = getValue(dict, "CHAT_MESSAGE_FWDS")
        self._CHAT_MESSAGE_FWDS_r = extractArgumentRanges(self._CHAT_MESSAGE_FWDS)
        self.Conversation_MessageDialogEdit = getValue(dict, "Conversation.MessageDialogEdit")
        self.PrivacyLastSeenSettings_Title = getValue(dict, "PrivacyLastSeenSettings.Title")
        self.Notifications_ClassicTones = getValue(dict, "Notifications.ClassicTones")
        self.Conversation_LinkDialogOpen = getValue(dict, "Conversation.LinkDialogOpen")
        self.Channel_Info_Subscribers = getValue(dict, "Channel.Info.Subscribers")
        self.NotificationsSound_Input = getValue(dict, "NotificationsSound.Input")
        self.Conversation_ClousStorageInfo_Description4 = getValue(dict, "Conversation.ClousStorageInfo.Description4")
        self.Privacy_Calls_AlwaysAllow = getValue(dict, "Privacy.Calls.AlwaysAllow")
        self.Privacy_PaymentsClearInfoHelp = getValue(dict, "Privacy.PaymentsClearInfoHelp")
        self.Notification_MessageLifetime1h = getValue(dict, "Notification.MessageLifetime1h")
        self._Notification_CreatedChatWithTitle = getValue(dict, "Notification.CreatedChatWithTitle")
        self._Notification_CreatedChatWithTitle_r = extractArgumentRanges(self._Notification_CreatedChatWithTitle)
        self.CheckoutInfo_ReceiverInfoEmail = getValue(dict, "CheckoutInfo.ReceiverInfoEmail")
        self.LastSeen_Lately = getValue(dict, "LastSeen.Lately")
        self.Month_ShortApril = getValue(dict, "Month.ShortApril")
        self.ConversationProfile_ErrorCreatingConversation = getValue(dict, "ConversationProfile.ErrorCreatingConversation")
        self._PHONE_CALL_MISSED = getValue(dict, "PHONE_CALL_MISSED")
        self._PHONE_CALL_MISSED_r = extractArgumentRanges(self._PHONE_CALL_MISSED)
        self._Conversation_Kilobytes = getValue(dict, "Conversation.Kilobytes")
        self._Conversation_Kilobytes_r = extractArgumentRanges(self._Conversation_Kilobytes)
        self.Group_ErrorAddBlocked = getValue(dict, "Group.ErrorAddBlocked")
        self.TwoStepAuth_AdditionalPassword = getValue(dict, "TwoStepAuth.AdditionalPassword")
        self.MediaPicker_Videos = getValue(dict, "MediaPicker.Videos")
        self.Notification_PassportValueProofOfIdentity = getValue(dict, "Notification.PassportValueProofOfIdentity")
        self.BlockedUsers_AddNew = getValue(dict, "BlockedUsers.AddNew")
        self.StickerPacksSettings_StickerPacksSection = getValue(dict, "StickerPacksSettings.StickerPacksSection")
        self.Channel_NotificationLoading = getValue(dict, "Channel.NotificationLoading")
        self.Passport_Language_da = getValue(dict, "Passport.Language.da")
        self.Passport_Address_Country = getValue(dict, "Passport.Address.Country")
        self._CHAT_RETURNED = getValue(dict, "CHAT_RETURNED")
        self._CHAT_RETURNED_r = extractArgumentRanges(self._CHAT_RETURNED)
        self.PhotoEditor_ShadowsTint = getValue(dict, "PhotoEditor.ShadowsTint")
        self.ExplicitContent_AlertTitle = getValue(dict, "ExplicitContent.AlertTitle")
        self.Channel_AdminLogFilter_EventsLeaving = getValue(dict, "Channel.AdminLogFilter.EventsLeaving")
        self.Map_LiveLocationFor8Hours = getValue(dict, "Map.LiveLocationFor8Hours")
        self.StickerPack_HideStickers = getValue(dict, "StickerPack.HideStickers")
        self.Checkout_EnterPassword = getValue(dict, "Checkout.EnterPassword")
        self.UserInfo_NotificationsEnabled = getValue(dict, "UserInfo.NotificationsEnabled")
        self.InfoPlist_NSLocationAlwaysUsageDescription = getValue(dict, "InfoPlist.NSLocationAlwaysUsageDescription")
        self.SocksProxySetup_ProxyDetailsTitle = getValue(dict, "SocksProxySetup.ProxyDetailsTitle")
        self.Weekday_ShortTuesday = getValue(dict, "Weekday.ShortTuesday")
        self.Notification_CallIncomingShort = getValue(dict, "Notification.CallIncomingShort")
        self.ConvertToSupergroup_Note = getValue(dict, "ConvertToSupergroup.Note")
        self.DialogList_Read = getValue(dict, "DialogList.Read")
        self.Conversation_EmptyPlaceholder = getValue(dict, "Conversation.EmptyPlaceholder")
        self._Passport_Email_CodeHelp = getValue(dict, "Passport.Email.CodeHelp")
        self._Passport_Email_CodeHelp_r = extractArgumentRanges(self._Passport_Email_CodeHelp)
        self.Username_Help = getValue(dict, "Username.Help")
        self.StickerSettings_ContextHide = getValue(dict, "StickerSettings.ContextHide")
        self.Media_ShareThisPhoto = getValue(dict, "Media.ShareThisPhoto")
        self.Contacts_ShareTelegram = getValue(dict, "Contacts.ShareTelegram")
        self.AutoNightTheme_Scheduled = getValue(dict, "AutoNightTheme.Scheduled")
        self.PrivacySettings_PasscodeAndFaceId = getValue(dict, "PrivacySettings.PasscodeAndFaceId")
        self.Settings_ChatBackground = getValue(dict, "Settings.ChatBackground")
        self.Login_TermsOfServiceDecline = getValue(dict, "Login.TermsOfServiceDecline")
    self._Conversation_StatusOnline_zero = getValueWithForm(dict, "Conversation.StatusOnline", .zero)
    self._Conversation_StatusOnline_one = getValueWithForm(dict, "Conversation.StatusOnline", .one)
    self._Conversation_StatusOnline_two = getValueWithForm(dict, "Conversation.StatusOnline", .two)
    self._Conversation_StatusOnline_few = getValueWithForm(dict, "Conversation.StatusOnline", .few)
    self._Conversation_StatusOnline_many = getValueWithForm(dict, "Conversation.StatusOnline", .many)
    self._Conversation_StatusOnline_other = getValueWithForm(dict, "Conversation.StatusOnline", .other)
    self._Conversation_StatusMembers_zero = getValueWithForm(dict, "Conversation.StatusMembers", .zero)
    self._Conversation_StatusMembers_one = getValueWithForm(dict, "Conversation.StatusMembers", .one)
    self._Conversation_StatusMembers_two = getValueWithForm(dict, "Conversation.StatusMembers", .two)
    self._Conversation_StatusMembers_few = getValueWithForm(dict, "Conversation.StatusMembers", .few)
    self._Conversation_StatusMembers_many = getValueWithForm(dict, "Conversation.StatusMembers", .many)
    self._Conversation_StatusMembers_other = getValueWithForm(dict, "Conversation.StatusMembers", .other)
    self._ServiceMessage_GameScoreSelfSimple_zero = getValueWithForm(dict, "ServiceMessage.GameScoreSelfSimple", .zero)
    self._ServiceMessage_GameScoreSelfSimple_one = getValueWithForm(dict, "ServiceMessage.GameScoreSelfSimple", .one)
    self._ServiceMessage_GameScoreSelfSimple_two = getValueWithForm(dict, "ServiceMessage.GameScoreSelfSimple", .two)
    self._ServiceMessage_GameScoreSelfSimple_few = getValueWithForm(dict, "ServiceMessage.GameScoreSelfSimple", .few)
    self._ServiceMessage_GameScoreSelfSimple_many = getValueWithForm(dict, "ServiceMessage.GameScoreSelfSimple", .many)
    self._ServiceMessage_GameScoreSelfSimple_other = getValueWithForm(dict, "ServiceMessage.GameScoreSelfSimple", .other)
    self._ForwardedVideos_zero = getValueWithForm(dict, "ForwardedVideos", .zero)
    self._ForwardedVideos_one = getValueWithForm(dict, "ForwardedVideos", .one)
    self._ForwardedVideos_two = getValueWithForm(dict, "ForwardedVideos", .two)
    self._ForwardedVideos_few = getValueWithForm(dict, "ForwardedVideos", .few)
    self._ForwardedVideos_many = getValueWithForm(dict, "ForwardedVideos", .many)
    self._ForwardedVideos_other = getValueWithForm(dict, "ForwardedVideos", .other)
    self._ForwardedPhotos_zero = getValueWithForm(dict, "ForwardedPhotos", .zero)
    self._ForwardedPhotos_one = getValueWithForm(dict, "ForwardedPhotos", .one)
    self._ForwardedPhotos_two = getValueWithForm(dict, "ForwardedPhotos", .two)
    self._ForwardedPhotos_few = getValueWithForm(dict, "ForwardedPhotos", .few)
    self._ForwardedPhotos_many = getValueWithForm(dict, "ForwardedPhotos", .many)
    self._ForwardedPhotos_other = getValueWithForm(dict, "ForwardedPhotos", .other)
    self._StickerPack_StickerCount_zero = getValueWithForm(dict, "StickerPack.StickerCount", .zero)
    self._StickerPack_StickerCount_one = getValueWithForm(dict, "StickerPack.StickerCount", .one)
    self._StickerPack_StickerCount_two = getValueWithForm(dict, "StickerPack.StickerCount", .two)
    self._StickerPack_StickerCount_few = getValueWithForm(dict, "StickerPack.StickerCount", .few)
    self._StickerPack_StickerCount_many = getValueWithForm(dict, "StickerPack.StickerCount", .many)
    self._StickerPack_StickerCount_other = getValueWithForm(dict, "StickerPack.StickerCount", .other)
    self._MessageTimer_Years_zero = getValueWithForm(dict, "MessageTimer.Years", .zero)
    self._MessageTimer_Years_one = getValueWithForm(dict, "MessageTimer.Years", .one)
    self._MessageTimer_Years_two = getValueWithForm(dict, "MessageTimer.Years", .two)
    self._MessageTimer_Years_few = getValueWithForm(dict, "MessageTimer.Years", .few)
    self._MessageTimer_Years_many = getValueWithForm(dict, "MessageTimer.Years", .many)
    self._MessageTimer_Years_other = getValueWithForm(dict, "MessageTimer.Years", .other)
    self._MuteExpires_Days_zero = getValueWithForm(dict, "MuteExpires.Days", .zero)
    self._MuteExpires_Days_one = getValueWithForm(dict, "MuteExpires.Days", .one)
    self._MuteExpires_Days_two = getValueWithForm(dict, "MuteExpires.Days", .two)
    self._MuteExpires_Days_few = getValueWithForm(dict, "MuteExpires.Days", .few)
    self._MuteExpires_Days_many = getValueWithForm(dict, "MuteExpires.Days", .many)
    self._MuteExpires_Days_other = getValueWithForm(dict, "MuteExpires.Days", .other)
    self._InviteText_ContactsCountText_zero = getValueWithForm(dict, "InviteText.ContactsCountText", .zero)
    self._InviteText_ContactsCountText_one = getValueWithForm(dict, "InviteText.ContactsCountText", .one)
    self._InviteText_ContactsCountText_two = getValueWithForm(dict, "InviteText.ContactsCountText", .two)
    self._InviteText_ContactsCountText_few = getValueWithForm(dict, "InviteText.ContactsCountText", .few)
    self._InviteText_ContactsCountText_many = getValueWithForm(dict, "InviteText.ContactsCountText", .many)
    self._InviteText_ContactsCountText_other = getValueWithForm(dict, "InviteText.ContactsCountText", .other)
    self._LiveLocation_MenuChatsCount_zero = getValueWithForm(dict, "LiveLocation.MenuChatsCount", .zero)
    self._LiveLocation_MenuChatsCount_one = getValueWithForm(dict, "LiveLocation.MenuChatsCount", .one)
    self._LiveLocation_MenuChatsCount_two = getValueWithForm(dict, "LiveLocation.MenuChatsCount", .two)
    self._LiveLocation_MenuChatsCount_few = getValueWithForm(dict, "LiveLocation.MenuChatsCount", .few)
    self._LiveLocation_MenuChatsCount_many = getValueWithForm(dict, "LiveLocation.MenuChatsCount", .many)
    self._LiveLocation_MenuChatsCount_other = getValueWithForm(dict, "LiveLocation.MenuChatsCount", .other)
    self._Conversation_LiveLocationMembersCount_zero = getValueWithForm(dict, "Conversation.LiveLocationMembersCount", .zero)
    self._Conversation_LiveLocationMembersCount_one = getValueWithForm(dict, "Conversation.LiveLocationMembersCount", .one)
    self._Conversation_LiveLocationMembersCount_two = getValueWithForm(dict, "Conversation.LiveLocationMembersCount", .two)
    self._Conversation_LiveLocationMembersCount_few = getValueWithForm(dict, "Conversation.LiveLocationMembersCount", .few)
    self._Conversation_LiveLocationMembersCount_many = getValueWithForm(dict, "Conversation.LiveLocationMembersCount", .many)
    self._Conversation_LiveLocationMembersCount_other = getValueWithForm(dict, "Conversation.LiveLocationMembersCount", .other)
    self._MuteExpires_Hours_zero = getValueWithForm(dict, "MuteExpires.Hours", .zero)
    self._MuteExpires_Hours_one = getValueWithForm(dict, "MuteExpires.Hours", .one)
    self._MuteExpires_Hours_two = getValueWithForm(dict, "MuteExpires.Hours", .two)
    self._MuteExpires_Hours_few = getValueWithForm(dict, "MuteExpires.Hours", .few)
    self._MuteExpires_Hours_many = getValueWithForm(dict, "MuteExpires.Hours", .many)
    self._MuteExpires_Hours_other = getValueWithForm(dict, "MuteExpires.Hours", .other)
    self._PrivacyLastSeenSettings_AddUsers_zero = getValueWithForm(dict, "PrivacyLastSeenSettings.AddUsers", .zero)
    self._PrivacyLastSeenSettings_AddUsers_one = getValueWithForm(dict, "PrivacyLastSeenSettings.AddUsers", .one)
    self._PrivacyLastSeenSettings_AddUsers_two = getValueWithForm(dict, "PrivacyLastSeenSettings.AddUsers", .two)
    self._PrivacyLastSeenSettings_AddUsers_few = getValueWithForm(dict, "PrivacyLastSeenSettings.AddUsers", .few)
    self._PrivacyLastSeenSettings_AddUsers_many = getValueWithForm(dict, "PrivacyLastSeenSettings.AddUsers", .many)
    self._PrivacyLastSeenSettings_AddUsers_other = getValueWithForm(dict, "PrivacyLastSeenSettings.AddUsers", .other)
    self._UserCount_zero = getValueWithForm(dict, "UserCount", .zero)
    self._UserCount_one = getValueWithForm(dict, "UserCount", .one)
    self._UserCount_two = getValueWithForm(dict, "UserCount", .two)
    self._UserCount_few = getValueWithForm(dict, "UserCount", .few)
    self._UserCount_many = getValueWithForm(dict, "UserCount", .many)
    self._UserCount_other = getValueWithForm(dict, "UserCount", .other)
    self._Notification_GameScoreSelfSimple_zero = getValueWithForm(dict, "Notification.GameScoreSelfSimple", .zero)
    self._Notification_GameScoreSelfSimple_one = getValueWithForm(dict, "Notification.GameScoreSelfSimple", .one)
    self._Notification_GameScoreSelfSimple_two = getValueWithForm(dict, "Notification.GameScoreSelfSimple", .two)
    self._Notification_GameScoreSelfSimple_few = getValueWithForm(dict, "Notification.GameScoreSelfSimple", .few)
    self._Notification_GameScoreSelfSimple_many = getValueWithForm(dict, "Notification.GameScoreSelfSimple", .many)
    self._Notification_GameScoreSelfSimple_other = getValueWithForm(dict, "Notification.GameScoreSelfSimple", .other)
    self._ServiceMessage_GameScoreExtended_zero = getValueWithForm(dict, "ServiceMessage.GameScoreExtended", .zero)
    self._ServiceMessage_GameScoreExtended_one = getValueWithForm(dict, "ServiceMessage.GameScoreExtended", .one)
    self._ServiceMessage_GameScoreExtended_two = getValueWithForm(dict, "ServiceMessage.GameScoreExtended", .two)
    self._ServiceMessage_GameScoreExtended_few = getValueWithForm(dict, "ServiceMessage.GameScoreExtended", .few)
    self._ServiceMessage_GameScoreExtended_many = getValueWithForm(dict, "ServiceMessage.GameScoreExtended", .many)
    self._ServiceMessage_GameScoreExtended_other = getValueWithForm(dict, "ServiceMessage.GameScoreExtended", .other)
    self._Call_Minutes_zero = getValueWithForm(dict, "Call.Minutes", .zero)
    self._Call_Minutes_one = getValueWithForm(dict, "Call.Minutes", .one)
    self._Call_Minutes_two = getValueWithForm(dict, "Call.Minutes", .two)
    self._Call_Minutes_few = getValueWithForm(dict, "Call.Minutes", .few)
    self._Call_Minutes_many = getValueWithForm(dict, "Call.Minutes", .many)
    self._Call_Minutes_other = getValueWithForm(dict, "Call.Minutes", .other)
    self._StickerPack_AddMaskCount_zero = getValueWithForm(dict, "StickerPack.AddMaskCount", .zero)
    self._StickerPack_AddMaskCount_one = getValueWithForm(dict, "StickerPack.AddMaskCount", .one)
    self._StickerPack_AddMaskCount_two = getValueWithForm(dict, "StickerPack.AddMaskCount", .two)
    self._StickerPack_AddMaskCount_few = getValueWithForm(dict, "StickerPack.AddMaskCount", .few)
    self._StickerPack_AddMaskCount_many = getValueWithForm(dict, "StickerPack.AddMaskCount", .many)
    self._StickerPack_AddMaskCount_other = getValueWithForm(dict, "StickerPack.AddMaskCount", .other)
    self._StickerPack_RemoveMaskCount_zero = getValueWithForm(dict, "StickerPack.RemoveMaskCount", .zero)
    self._StickerPack_RemoveMaskCount_one = getValueWithForm(dict, "StickerPack.RemoveMaskCount", .one)
    self._StickerPack_RemoveMaskCount_two = getValueWithForm(dict, "StickerPack.RemoveMaskCount", .two)
    self._StickerPack_RemoveMaskCount_few = getValueWithForm(dict, "StickerPack.RemoveMaskCount", .few)
    self._StickerPack_RemoveMaskCount_many = getValueWithForm(dict, "StickerPack.RemoveMaskCount", .many)
    self._StickerPack_RemoveMaskCount_other = getValueWithForm(dict, "StickerPack.RemoveMaskCount", .other)
    self._ForwardedFiles_zero = getValueWithForm(dict, "ForwardedFiles", .zero)
    self._ForwardedFiles_one = getValueWithForm(dict, "ForwardedFiles", .one)
    self._ForwardedFiles_two = getValueWithForm(dict, "ForwardedFiles", .two)
    self._ForwardedFiles_few = getValueWithForm(dict, "ForwardedFiles", .few)
    self._ForwardedFiles_many = getValueWithForm(dict, "ForwardedFiles", .many)
    self._ForwardedFiles_other = getValueWithForm(dict, "ForwardedFiles", .other)
    self._MessageTimer_ShortMinutes_zero = getValueWithForm(dict, "MessageTimer.ShortMinutes", .zero)
    self._MessageTimer_ShortMinutes_one = getValueWithForm(dict, "MessageTimer.ShortMinutes", .one)
    self._MessageTimer_ShortMinutes_two = getValueWithForm(dict, "MessageTimer.ShortMinutes", .two)
    self._MessageTimer_ShortMinutes_few = getValueWithForm(dict, "MessageTimer.ShortMinutes", .few)
    self._MessageTimer_ShortMinutes_many = getValueWithForm(dict, "MessageTimer.ShortMinutes", .many)
    self._MessageTimer_ShortMinutes_other = getValueWithForm(dict, "MessageTimer.ShortMinutes", .other)
    self._Media_SharePhoto_zero = getValueWithForm(dict, "Media.SharePhoto", .zero)
    self._Media_SharePhoto_one = getValueWithForm(dict, "Media.SharePhoto", .one)
    self._Media_SharePhoto_two = getValueWithForm(dict, "Media.SharePhoto", .two)
    self._Media_SharePhoto_few = getValueWithForm(dict, "Media.SharePhoto", .few)
    self._Media_SharePhoto_many = getValueWithForm(dict, "Media.SharePhoto", .many)
    self._Media_SharePhoto_other = getValueWithForm(dict, "Media.SharePhoto", .other)
    self._SharedMedia_DeleteItemsConfirmation_zero = getValueWithForm(dict, "SharedMedia.DeleteItemsConfirmation", .zero)
    self._SharedMedia_DeleteItemsConfirmation_one = getValueWithForm(dict, "SharedMedia.DeleteItemsConfirmation", .one)
    self._SharedMedia_DeleteItemsConfirmation_two = getValueWithForm(dict, "SharedMedia.DeleteItemsConfirmation", .two)
    self._SharedMedia_DeleteItemsConfirmation_few = getValueWithForm(dict, "SharedMedia.DeleteItemsConfirmation", .few)
    self._SharedMedia_DeleteItemsConfirmation_many = getValueWithForm(dict, "SharedMedia.DeleteItemsConfirmation", .many)
    self._SharedMedia_DeleteItemsConfirmation_other = getValueWithForm(dict, "SharedMedia.DeleteItemsConfirmation", .other)
    self._DialogList_LiveLocationChatsCount_zero = getValueWithForm(dict, "DialogList.LiveLocationChatsCount", .zero)
    self._DialogList_LiveLocationChatsCount_one = getValueWithForm(dict, "DialogList.LiveLocationChatsCount", .one)
    self._DialogList_LiveLocationChatsCount_two = getValueWithForm(dict, "DialogList.LiveLocationChatsCount", .two)
    self._DialogList_LiveLocationChatsCount_few = getValueWithForm(dict, "DialogList.LiveLocationChatsCount", .few)
    self._DialogList_LiveLocationChatsCount_many = getValueWithForm(dict, "DialogList.LiveLocationChatsCount", .many)
    self._DialogList_LiveLocationChatsCount_other = getValueWithForm(dict, "DialogList.LiveLocationChatsCount", .other)
    self._ServiceMessage_GameScoreSimple_zero = getValueWithForm(dict, "ServiceMessage.GameScoreSimple", .zero)
    self._ServiceMessage_GameScoreSimple_one = getValueWithForm(dict, "ServiceMessage.GameScoreSimple", .one)
    self._ServiceMessage_GameScoreSimple_two = getValueWithForm(dict, "ServiceMessage.GameScoreSimple", .two)
    self._ServiceMessage_GameScoreSimple_few = getValueWithForm(dict, "ServiceMessage.GameScoreSimple", .few)
    self._ServiceMessage_GameScoreSimple_many = getValueWithForm(dict, "ServiceMessage.GameScoreSimple", .many)
    self._ServiceMessage_GameScoreSimple_other = getValueWithForm(dict, "ServiceMessage.GameScoreSimple", .other)
    self._Notification_GameScoreSelfExtended_zero = getValueWithForm(dict, "Notification.GameScoreSelfExtended", .zero)
    self._Notification_GameScoreSelfExtended_one = getValueWithForm(dict, "Notification.GameScoreSelfExtended", .one)
    self._Notification_GameScoreSelfExtended_two = getValueWithForm(dict, "Notification.GameScoreSelfExtended", .two)
    self._Notification_GameScoreSelfExtended_few = getValueWithForm(dict, "Notification.GameScoreSelfExtended", .few)
    self._Notification_GameScoreSelfExtended_many = getValueWithForm(dict, "Notification.GameScoreSelfExtended", .many)
    self._Notification_GameScoreSelfExtended_other = getValueWithForm(dict, "Notification.GameScoreSelfExtended", .other)
    self._Watch_LastSeen_HoursAgo_zero = getValueWithForm(dict, "Watch.LastSeen.HoursAgo", .zero)
    self._Watch_LastSeen_HoursAgo_one = getValueWithForm(dict, "Watch.LastSeen.HoursAgo", .one)
    self._Watch_LastSeen_HoursAgo_two = getValueWithForm(dict, "Watch.LastSeen.HoursAgo", .two)
    self._Watch_LastSeen_HoursAgo_few = getValueWithForm(dict, "Watch.LastSeen.HoursAgo", .few)
    self._Watch_LastSeen_HoursAgo_many = getValueWithForm(dict, "Watch.LastSeen.HoursAgo", .many)
    self._Watch_LastSeen_HoursAgo_other = getValueWithForm(dict, "Watch.LastSeen.HoursAgo", .other)
    self._SharedMedia_Link_zero = getValueWithForm(dict, "SharedMedia.Link", .zero)
    self._SharedMedia_Link_one = getValueWithForm(dict, "SharedMedia.Link", .one)
    self._SharedMedia_Link_two = getValueWithForm(dict, "SharedMedia.Link", .two)
    self._SharedMedia_Link_few = getValueWithForm(dict, "SharedMedia.Link", .few)
    self._SharedMedia_Link_many = getValueWithForm(dict, "SharedMedia.Link", .many)
    self._SharedMedia_Link_other = getValueWithForm(dict, "SharedMedia.Link", .other)
    self._Notification_GameScoreSimple_zero = getValueWithForm(dict, "Notification.GameScoreSimple", .zero)
    self._Notification_GameScoreSimple_one = getValueWithForm(dict, "Notification.GameScoreSimple", .one)
    self._Notification_GameScoreSimple_two = getValueWithForm(dict, "Notification.GameScoreSimple", .two)
    self._Notification_GameScoreSimple_few = getValueWithForm(dict, "Notification.GameScoreSimple", .few)
    self._Notification_GameScoreSimple_many = getValueWithForm(dict, "Notification.GameScoreSimple", .many)
    self._Notification_GameScoreSimple_other = getValueWithForm(dict, "Notification.GameScoreSimple", .other)
    self._MessageTimer_ShortWeeks_zero = getValueWithForm(dict, "MessageTimer.ShortWeeks", .zero)
    self._MessageTimer_ShortWeeks_one = getValueWithForm(dict, "MessageTimer.ShortWeeks", .one)
    self._MessageTimer_ShortWeeks_two = getValueWithForm(dict, "MessageTimer.ShortWeeks", .two)
    self._MessageTimer_ShortWeeks_few = getValueWithForm(dict, "MessageTimer.ShortWeeks", .few)
    self._MessageTimer_ShortWeeks_many = getValueWithForm(dict, "MessageTimer.ShortWeeks", .many)
    self._MessageTimer_ShortWeeks_other = getValueWithForm(dict, "MessageTimer.ShortWeeks", .other)
    self._ForwardedMessages_zero = getValueWithForm(dict, "ForwardedMessages", .zero)
    self._ForwardedMessages_one = getValueWithForm(dict, "ForwardedMessages", .one)
    self._ForwardedMessages_two = getValueWithForm(dict, "ForwardedMessages", .two)
    self._ForwardedMessages_few = getValueWithForm(dict, "ForwardedMessages", .few)
    self._ForwardedMessages_many = getValueWithForm(dict, "ForwardedMessages", .many)
    self._ForwardedMessages_other = getValueWithForm(dict, "ForwardedMessages", .other)
    self._Watch_LastSeen_MinutesAgo_zero = getValueWithForm(dict, "Watch.LastSeen.MinutesAgo", .zero)
    self._Watch_LastSeen_MinutesAgo_one = getValueWithForm(dict, "Watch.LastSeen.MinutesAgo", .one)
    self._Watch_LastSeen_MinutesAgo_two = getValueWithForm(dict, "Watch.LastSeen.MinutesAgo", .two)
    self._Watch_LastSeen_MinutesAgo_few = getValueWithForm(dict, "Watch.LastSeen.MinutesAgo", .few)
    self._Watch_LastSeen_MinutesAgo_many = getValueWithForm(dict, "Watch.LastSeen.MinutesAgo", .many)
    self._Watch_LastSeen_MinutesAgo_other = getValueWithForm(dict, "Watch.LastSeen.MinutesAgo", .other)
    self._Media_ShareItem_zero = getValueWithForm(dict, "Media.ShareItem", .zero)
    self._Media_ShareItem_one = getValueWithForm(dict, "Media.ShareItem", .one)
    self._Media_ShareItem_two = getValueWithForm(dict, "Media.ShareItem", .two)
    self._Media_ShareItem_few = getValueWithForm(dict, "Media.ShareItem", .few)
    self._Media_ShareItem_many = getValueWithForm(dict, "Media.ShareItem", .many)
    self._Media_ShareItem_other = getValueWithForm(dict, "Media.ShareItem", .other)
    self._MuteExpires_Minutes_zero = getValueWithForm(dict, "MuteExpires.Minutes", .zero)
    self._MuteExpires_Minutes_one = getValueWithForm(dict, "MuteExpires.Minutes", .one)
    self._MuteExpires_Minutes_two = getValueWithForm(dict, "MuteExpires.Minutes", .two)
    self._MuteExpires_Minutes_few = getValueWithForm(dict, "MuteExpires.Minutes", .few)
    self._MuteExpires_Minutes_many = getValueWithForm(dict, "MuteExpires.Minutes", .many)
    self._MuteExpires_Minutes_other = getValueWithForm(dict, "MuteExpires.Minutes", .other)
    self._StickerPack_RemoveStickerCount_zero = getValueWithForm(dict, "StickerPack.RemoveStickerCount", .zero)
    self._StickerPack_RemoveStickerCount_one = getValueWithForm(dict, "StickerPack.RemoveStickerCount", .one)
    self._StickerPack_RemoveStickerCount_two = getValueWithForm(dict, "StickerPack.RemoveStickerCount", .two)
    self._StickerPack_RemoveStickerCount_few = getValueWithForm(dict, "StickerPack.RemoveStickerCount", .few)
    self._StickerPack_RemoveStickerCount_many = getValueWithForm(dict, "StickerPack.RemoveStickerCount", .many)
    self._StickerPack_RemoveStickerCount_other = getValueWithForm(dict, "StickerPack.RemoveStickerCount", .other)
    self._AttachmentMenu_SendPhoto_zero = getValueWithForm(dict, "AttachmentMenu.SendPhoto", .zero)
    self._AttachmentMenu_SendPhoto_one = getValueWithForm(dict, "AttachmentMenu.SendPhoto", .one)
    self._AttachmentMenu_SendPhoto_two = getValueWithForm(dict, "AttachmentMenu.SendPhoto", .two)
    self._AttachmentMenu_SendPhoto_few = getValueWithForm(dict, "AttachmentMenu.SendPhoto", .few)
    self._AttachmentMenu_SendPhoto_many = getValueWithForm(dict, "AttachmentMenu.SendPhoto", .many)
    self._AttachmentMenu_SendPhoto_other = getValueWithForm(dict, "AttachmentMenu.SendPhoto", .other)
    self._ForwardedAudios_zero = getValueWithForm(dict, "ForwardedAudios", .zero)
    self._ForwardedAudios_one = getValueWithForm(dict, "ForwardedAudios", .one)
    self._ForwardedAudios_two = getValueWithForm(dict, "ForwardedAudios", .two)
    self._ForwardedAudios_few = getValueWithForm(dict, "ForwardedAudios", .few)
    self._ForwardedAudios_many = getValueWithForm(dict, "ForwardedAudios", .many)
    self._ForwardedAudios_other = getValueWithForm(dict, "ForwardedAudios", .other)
    self._MessageTimer_ShortDays_zero = getValueWithForm(dict, "MessageTimer.ShortDays", .zero)
    self._MessageTimer_ShortDays_one = getValueWithForm(dict, "MessageTimer.ShortDays", .one)
    self._MessageTimer_ShortDays_two = getValueWithForm(dict, "MessageTimer.ShortDays", .two)
    self._MessageTimer_ShortDays_few = getValueWithForm(dict, "MessageTimer.ShortDays", .few)
    self._MessageTimer_ShortDays_many = getValueWithForm(dict, "MessageTimer.ShortDays", .many)
    self._MessageTimer_ShortDays_other = getValueWithForm(dict, "MessageTimer.ShortDays", .other)
    self._Notifications_ExceptionMuteExpires_Minutes_zero = getValueWithForm(dict, "Notifications.ExceptionMuteExpires.Minutes", .zero)
    self._Notifications_ExceptionMuteExpires_Minutes_one = getValueWithForm(dict, "Notifications.ExceptionMuteExpires.Minutes", .one)
    self._Notifications_ExceptionMuteExpires_Minutes_two = getValueWithForm(dict, "Notifications.ExceptionMuteExpires.Minutes", .two)
    self._Notifications_ExceptionMuteExpires_Minutes_few = getValueWithForm(dict, "Notifications.ExceptionMuteExpires.Minutes", .few)
    self._Notifications_ExceptionMuteExpires_Minutes_many = getValueWithForm(dict, "Notifications.ExceptionMuteExpires.Minutes", .many)
    self._Notifications_ExceptionMuteExpires_Minutes_other = getValueWithForm(dict, "Notifications.ExceptionMuteExpires.Minutes", .other)
    self._MessageTimer_Seconds_zero = getValueWithForm(dict, "MessageTimer.Seconds", .zero)
    self._MessageTimer_Seconds_one = getValueWithForm(dict, "MessageTimer.Seconds", .one)
    self._MessageTimer_Seconds_two = getValueWithForm(dict, "MessageTimer.Seconds", .two)
    self._MessageTimer_Seconds_few = getValueWithForm(dict, "MessageTimer.Seconds", .few)
    self._MessageTimer_Seconds_many = getValueWithForm(dict, "MessageTimer.Seconds", .many)
    self._MessageTimer_Seconds_other = getValueWithForm(dict, "MessageTimer.Seconds", .other)
    self._Notifications_ExceptionMuteExpires_Days_zero = getValueWithForm(dict, "Notifications.ExceptionMuteExpires.Days", .zero)
    self._Notifications_ExceptionMuteExpires_Days_one = getValueWithForm(dict, "Notifications.ExceptionMuteExpires.Days", .one)
    self._Notifications_ExceptionMuteExpires_Days_two = getValueWithForm(dict, "Notifications.ExceptionMuteExpires.Days", .two)
    self._Notifications_ExceptionMuteExpires_Days_few = getValueWithForm(dict, "Notifications.ExceptionMuteExpires.Days", .few)
    self._Notifications_ExceptionMuteExpires_Days_many = getValueWithForm(dict, "Notifications.ExceptionMuteExpires.Days", .many)
    self._Notifications_ExceptionMuteExpires_Days_other = getValueWithForm(dict, "Notifications.ExceptionMuteExpires.Days", .other)
    self._MessageTimer_ShortSeconds_zero = getValueWithForm(dict, "MessageTimer.ShortSeconds", .zero)
    self._MessageTimer_ShortSeconds_one = getValueWithForm(dict, "MessageTimer.ShortSeconds", .one)
    self._MessageTimer_ShortSeconds_two = getValueWithForm(dict, "MessageTimer.ShortSeconds", .two)
    self._MessageTimer_ShortSeconds_few = getValueWithForm(dict, "MessageTimer.ShortSeconds", .few)
    self._MessageTimer_ShortSeconds_many = getValueWithForm(dict, "MessageTimer.ShortSeconds", .many)
    self._MessageTimer_ShortSeconds_other = getValueWithForm(dict, "MessageTimer.ShortSeconds", .other)
    self._Forward_ConfirmMultipleFiles_zero = getValueWithForm(dict, "Forward.ConfirmMultipleFiles", .zero)
    self._Forward_ConfirmMultipleFiles_one = getValueWithForm(dict, "Forward.ConfirmMultipleFiles", .one)
    self._Forward_ConfirmMultipleFiles_two = getValueWithForm(dict, "Forward.ConfirmMultipleFiles", .two)
    self._Forward_ConfirmMultipleFiles_few = getValueWithForm(dict, "Forward.ConfirmMultipleFiles", .few)
    self._Forward_ConfirmMultipleFiles_many = getValueWithForm(dict, "Forward.ConfirmMultipleFiles", .many)
    self._Forward_ConfirmMultipleFiles_other = getValueWithForm(dict, "Forward.ConfirmMultipleFiles", .other)
    self._MuteFor_Days_zero = getValueWithForm(dict, "MuteFor.Days", .zero)
    self._MuteFor_Days_one = getValueWithForm(dict, "MuteFor.Days", .one)
    self._MuteFor_Days_two = getValueWithForm(dict, "MuteFor.Days", .two)
    self._MuteFor_Days_few = getValueWithForm(dict, "MuteFor.Days", .few)
    self._MuteFor_Days_many = getValueWithForm(dict, "MuteFor.Days", .many)
    self._MuteFor_Days_other = getValueWithForm(dict, "MuteFor.Days", .other)
    self._MuteFor_Hours_zero = getValueWithForm(dict, "MuteFor.Hours", .zero)
    self._MuteFor_Hours_one = getValueWithForm(dict, "MuteFor.Hours", .one)
    self._MuteFor_Hours_two = getValueWithForm(dict, "MuteFor.Hours", .two)
    self._MuteFor_Hours_few = getValueWithForm(dict, "MuteFor.Hours", .few)
    self._MuteFor_Hours_many = getValueWithForm(dict, "MuteFor.Hours", .many)
    self._MuteFor_Hours_other = getValueWithForm(dict, "MuteFor.Hours", .other)
    self._LastSeen_HoursAgo_zero = getValueWithForm(dict, "LastSeen.HoursAgo", .zero)
    self._LastSeen_HoursAgo_one = getValueWithForm(dict, "LastSeen.HoursAgo", .one)
    self._LastSeen_HoursAgo_two = getValueWithForm(dict, "LastSeen.HoursAgo", .two)
    self._LastSeen_HoursAgo_few = getValueWithForm(dict, "LastSeen.HoursAgo", .few)
    self._LastSeen_HoursAgo_many = getValueWithForm(dict, "LastSeen.HoursAgo", .many)
    self._LastSeen_HoursAgo_other = getValueWithForm(dict, "LastSeen.HoursAgo", .other)
    self._PasscodeSettings_FailedAttempts_zero = getValueWithForm(dict, "PasscodeSettings.FailedAttempts", .zero)
    self._PasscodeSettings_FailedAttempts_one = getValueWithForm(dict, "PasscodeSettings.FailedAttempts", .one)
    self._PasscodeSettings_FailedAttempts_two = getValueWithForm(dict, "PasscodeSettings.FailedAttempts", .two)
    self._PasscodeSettings_FailedAttempts_few = getValueWithForm(dict, "PasscodeSettings.FailedAttempts", .few)
    self._PasscodeSettings_FailedAttempts_many = getValueWithForm(dict, "PasscodeSettings.FailedAttempts", .many)
    self._PasscodeSettings_FailedAttempts_other = getValueWithForm(dict, "PasscodeSettings.FailedAttempts", .other)
    self._AttachmentMenu_SendGif_zero = getValueWithForm(dict, "AttachmentMenu.SendGif", .zero)
    self._AttachmentMenu_SendGif_one = getValueWithForm(dict, "AttachmentMenu.SendGif", .one)
    self._AttachmentMenu_SendGif_two = getValueWithForm(dict, "AttachmentMenu.SendGif", .two)
    self._AttachmentMenu_SendGif_few = getValueWithForm(dict, "AttachmentMenu.SendGif", .few)
    self._AttachmentMenu_SendGif_many = getValueWithForm(dict, "AttachmentMenu.SendGif", .many)
    self._AttachmentMenu_SendGif_other = getValueWithForm(dict, "AttachmentMenu.SendGif", .other)
    self._Map_ETAMinutes_zero = getValueWithForm(dict, "Map.ETAMinutes", .zero)
    self._Map_ETAMinutes_one = getValueWithForm(dict, "Map.ETAMinutes", .one)
    self._Map_ETAMinutes_two = getValueWithForm(dict, "Map.ETAMinutes", .two)
    self._Map_ETAMinutes_few = getValueWithForm(dict, "Map.ETAMinutes", .few)
    self._Map_ETAMinutes_many = getValueWithForm(dict, "Map.ETAMinutes", .many)
    self._Map_ETAMinutes_other = getValueWithForm(dict, "Map.ETAMinutes", .other)
    self._Passport_Scans_zero = getValueWithForm(dict, "Passport.Scans", .zero)
    self._Passport_Scans_one = getValueWithForm(dict, "Passport.Scans", .one)
    self._Passport_Scans_two = getValueWithForm(dict, "Passport.Scans", .two)
    self._Passport_Scans_few = getValueWithForm(dict, "Passport.Scans", .few)
    self._Passport_Scans_many = getValueWithForm(dict, "Passport.Scans", .many)
    self._Passport_Scans_other = getValueWithForm(dict, "Passport.Scans", .other)
    self._Map_ETAHours_zero = getValueWithForm(dict, "Map.ETAHours", .zero)
    self._Map_ETAHours_one = getValueWithForm(dict, "Map.ETAHours", .one)
    self._Map_ETAHours_two = getValueWithForm(dict, "Map.ETAHours", .two)
    self._Map_ETAHours_few = getValueWithForm(dict, "Map.ETAHours", .few)
    self._Map_ETAHours_many = getValueWithForm(dict, "Map.ETAHours", .many)
    self._Map_ETAHours_other = getValueWithForm(dict, "Map.ETAHours", .other)
    self._ForwardedVideoMessages_zero = getValueWithForm(dict, "ForwardedVideoMessages", .zero)
    self._ForwardedVideoMessages_one = getValueWithForm(dict, "ForwardedVideoMessages", .one)
    self._ForwardedVideoMessages_two = getValueWithForm(dict, "ForwardedVideoMessages", .two)
    self._ForwardedVideoMessages_few = getValueWithForm(dict, "ForwardedVideoMessages", .few)
    self._ForwardedVideoMessages_many = getValueWithForm(dict, "ForwardedVideoMessages", .many)
    self._ForwardedVideoMessages_other = getValueWithForm(dict, "ForwardedVideoMessages", .other)
    self._SharedMedia_File_zero = getValueWithForm(dict, "SharedMedia.File", .zero)
    self._SharedMedia_File_one = getValueWithForm(dict, "SharedMedia.File", .one)
    self._SharedMedia_File_two = getValueWithForm(dict, "SharedMedia.File", .two)
    self._SharedMedia_File_few = getValueWithForm(dict, "SharedMedia.File", .few)
    self._SharedMedia_File_many = getValueWithForm(dict, "SharedMedia.File", .many)
    self._SharedMedia_File_other = getValueWithForm(dict, "SharedMedia.File", .other)
    self._GroupInfo_ParticipantCount_zero = getValueWithForm(dict, "GroupInfo.ParticipantCount", .zero)
    self._GroupInfo_ParticipantCount_one = getValueWithForm(dict, "GroupInfo.ParticipantCount", .one)
    self._GroupInfo_ParticipantCount_two = getValueWithForm(dict, "GroupInfo.ParticipantCount", .two)
    self._GroupInfo_ParticipantCount_few = getValueWithForm(dict, "GroupInfo.ParticipantCount", .few)
    self._GroupInfo_ParticipantCount_many = getValueWithForm(dict, "GroupInfo.ParticipantCount", .many)
    self._GroupInfo_ParticipantCount_other = getValueWithForm(dict, "GroupInfo.ParticipantCount", .other)
    self._SharedMedia_Video_zero = getValueWithForm(dict, "SharedMedia.Video", .zero)
    self._SharedMedia_Video_one = getValueWithForm(dict, "SharedMedia.Video", .one)
    self._SharedMedia_Video_two = getValueWithForm(dict, "SharedMedia.Video", .two)
    self._SharedMedia_Video_few = getValueWithForm(dict, "SharedMedia.Video", .few)
    self._SharedMedia_Video_many = getValueWithForm(dict, "SharedMedia.Video", .many)
    self._SharedMedia_Video_other = getValueWithForm(dict, "SharedMedia.Video", .other)
    self._Conversation_StatusSubscribers_zero = getValueWithForm(dict, "Conversation.StatusSubscribers", .zero)
    self._Conversation_StatusSubscribers_one = getValueWithForm(dict, "Conversation.StatusSubscribers", .one)
    self._Conversation_StatusSubscribers_two = getValueWithForm(dict, "Conversation.StatusSubscribers", .two)
    self._Conversation_StatusSubscribers_few = getValueWithForm(dict, "Conversation.StatusSubscribers", .few)
    self._Conversation_StatusSubscribers_many = getValueWithForm(dict, "Conversation.StatusSubscribers", .many)
    self._Conversation_StatusSubscribers_other = getValueWithForm(dict, "Conversation.StatusSubscribers", .other)
    self._StickerPack_AddStickerCount_zero = getValueWithForm(dict, "StickerPack.AddStickerCount", .zero)
    self._StickerPack_AddStickerCount_one = getValueWithForm(dict, "StickerPack.AddStickerCount", .one)
    self._StickerPack_AddStickerCount_two = getValueWithForm(dict, "StickerPack.AddStickerCount", .two)
    self._StickerPack_AddStickerCount_few = getValueWithForm(dict, "StickerPack.AddStickerCount", .few)
    self._StickerPack_AddStickerCount_many = getValueWithForm(dict, "StickerPack.AddStickerCount", .many)
    self._StickerPack_AddStickerCount_other = getValueWithForm(dict, "StickerPack.AddStickerCount", .other)
    self._ServiceMessage_GameScoreSelfExtended_zero = getValueWithForm(dict, "ServiceMessage.GameScoreSelfExtended", .zero)
    self._ServiceMessage_GameScoreSelfExtended_one = getValueWithForm(dict, "ServiceMessage.GameScoreSelfExtended", .one)
    self._ServiceMessage_GameScoreSelfExtended_two = getValueWithForm(dict, "ServiceMessage.GameScoreSelfExtended", .two)
    self._ServiceMessage_GameScoreSelfExtended_few = getValueWithForm(dict, "ServiceMessage.GameScoreSelfExtended", .few)
    self._ServiceMessage_GameScoreSelfExtended_many = getValueWithForm(dict, "ServiceMessage.GameScoreSelfExtended", .many)
    self._ServiceMessage_GameScoreSelfExtended_other = getValueWithForm(dict, "ServiceMessage.GameScoreSelfExtended", .other)
    self._ForwardedStickers_zero = getValueWithForm(dict, "ForwardedStickers", .zero)
    self._ForwardedStickers_one = getValueWithForm(dict, "ForwardedStickers", .one)
    self._ForwardedStickers_two = getValueWithForm(dict, "ForwardedStickers", .two)
    self._ForwardedStickers_few = getValueWithForm(dict, "ForwardedStickers", .few)
    self._ForwardedStickers_many = getValueWithForm(dict, "ForwardedStickers", .many)
    self._ForwardedStickers_other = getValueWithForm(dict, "ForwardedStickers", .other)
    self._AttachmentMenu_SendVideo_zero = getValueWithForm(dict, "AttachmentMenu.SendVideo", .zero)
    self._AttachmentMenu_SendVideo_one = getValueWithForm(dict, "AttachmentMenu.SendVideo", .one)
    self._AttachmentMenu_SendVideo_two = getValueWithForm(dict, "AttachmentMenu.SendVideo", .two)
    self._AttachmentMenu_SendVideo_few = getValueWithForm(dict, "AttachmentMenu.SendVideo", .few)
    self._AttachmentMenu_SendVideo_many = getValueWithForm(dict, "AttachmentMenu.SendVideo", .many)
    self._AttachmentMenu_SendVideo_other = getValueWithForm(dict, "AttachmentMenu.SendVideo", .other)
    self._AttachmentMenu_SendItem_zero = getValueWithForm(dict, "AttachmentMenu.SendItem", .zero)
    self._AttachmentMenu_SendItem_one = getValueWithForm(dict, "AttachmentMenu.SendItem", .one)
    self._AttachmentMenu_SendItem_two = getValueWithForm(dict, "AttachmentMenu.SendItem", .two)
    self._AttachmentMenu_SendItem_few = getValueWithForm(dict, "AttachmentMenu.SendItem", .few)
    self._AttachmentMenu_SendItem_many = getValueWithForm(dict, "AttachmentMenu.SendItem", .many)
    self._AttachmentMenu_SendItem_other = getValueWithForm(dict, "AttachmentMenu.SendItem", .other)
    self._MessageTimer_Hours_zero = getValueWithForm(dict, "MessageTimer.Hours", .zero)
    self._MessageTimer_Hours_one = getValueWithForm(dict, "MessageTimer.Hours", .one)
    self._MessageTimer_Hours_two = getValueWithForm(dict, "MessageTimer.Hours", .two)
    self._MessageTimer_Hours_few = getValueWithForm(dict, "MessageTimer.Hours", .few)
    self._MessageTimer_Hours_many = getValueWithForm(dict, "MessageTimer.Hours", .many)
    self._MessageTimer_Hours_other = getValueWithForm(dict, "MessageTimer.Hours", .other)
    self._Invitation_Members_zero = getValueWithForm(dict, "Invitation.Members", .zero)
    self._Invitation_Members_one = getValueWithForm(dict, "Invitation.Members", .one)
    self._Invitation_Members_two = getValueWithForm(dict, "Invitation.Members", .two)
    self._Invitation_Members_few = getValueWithForm(dict, "Invitation.Members", .few)
    self._Invitation_Members_many = getValueWithForm(dict, "Invitation.Members", .many)
    self._Invitation_Members_other = getValueWithForm(dict, "Invitation.Members", .other)
    self._MessageTimer_Minutes_zero = getValueWithForm(dict, "MessageTimer.Minutes", .zero)
    self._MessageTimer_Minutes_one = getValueWithForm(dict, "MessageTimer.Minutes", .one)
    self._MessageTimer_Minutes_two = getValueWithForm(dict, "MessageTimer.Minutes", .two)
    self._MessageTimer_Minutes_few = getValueWithForm(dict, "MessageTimer.Minutes", .few)
    self._MessageTimer_Minutes_many = getValueWithForm(dict, "MessageTimer.Minutes", .many)
    self._MessageTimer_Minutes_other = getValueWithForm(dict, "MessageTimer.Minutes", .other)
    self._ForwardedLocations_zero = getValueWithForm(dict, "ForwardedLocations", .zero)
    self._ForwardedLocations_one = getValueWithForm(dict, "ForwardedLocations", .one)
    self._ForwardedLocations_two = getValueWithForm(dict, "ForwardedLocations", .two)
    self._ForwardedLocations_few = getValueWithForm(dict, "ForwardedLocations", .few)
    self._ForwardedLocations_many = getValueWithForm(dict, "ForwardedLocations", .many)
    self._ForwardedLocations_other = getValueWithForm(dict, "ForwardedLocations", .other)
    self._MessageTimer_ShortHours_zero = getValueWithForm(dict, "MessageTimer.ShortHours", .zero)
    self._MessageTimer_ShortHours_one = getValueWithForm(dict, "MessageTimer.ShortHours", .one)
    self._MessageTimer_ShortHours_two = getValueWithForm(dict, "MessageTimer.ShortHours", .two)
    self._MessageTimer_ShortHours_few = getValueWithForm(dict, "MessageTimer.ShortHours", .few)
    self._MessageTimer_ShortHours_many = getValueWithForm(dict, "MessageTimer.ShortHours", .many)
    self._MessageTimer_ShortHours_other = getValueWithForm(dict, "MessageTimer.ShortHours", .other)
    self._LastSeen_MinutesAgo_zero = getValueWithForm(dict, "LastSeen.MinutesAgo", .zero)
    self._LastSeen_MinutesAgo_one = getValueWithForm(dict, "LastSeen.MinutesAgo", .one)
    self._LastSeen_MinutesAgo_two = getValueWithForm(dict, "LastSeen.MinutesAgo", .two)
    self._LastSeen_MinutesAgo_few = getValueWithForm(dict, "LastSeen.MinutesAgo", .few)
    self._LastSeen_MinutesAgo_many = getValueWithForm(dict, "LastSeen.MinutesAgo", .many)
    self._LastSeen_MinutesAgo_other = getValueWithForm(dict, "LastSeen.MinutesAgo", .other)
    self._ForwardedContacts_zero = getValueWithForm(dict, "ForwardedContacts", .zero)
    self._ForwardedContacts_one = getValueWithForm(dict, "ForwardedContacts", .one)
    self._ForwardedContacts_two = getValueWithForm(dict, "ForwardedContacts", .two)
    self._ForwardedContacts_few = getValueWithForm(dict, "ForwardedContacts", .few)
    self._ForwardedContacts_many = getValueWithForm(dict, "ForwardedContacts", .many)
    self._ForwardedContacts_other = getValueWithForm(dict, "ForwardedContacts", .other)
    self._Notification_GameScoreExtended_zero = getValueWithForm(dict, "Notification.GameScoreExtended", .zero)
    self._Notification_GameScoreExtended_one = getValueWithForm(dict, "Notification.GameScoreExtended", .one)
    self._Notification_GameScoreExtended_two = getValueWithForm(dict, "Notification.GameScoreExtended", .two)
    self._Notification_GameScoreExtended_few = getValueWithForm(dict, "Notification.GameScoreExtended", .few)
    self._Notification_GameScoreExtended_many = getValueWithForm(dict, "Notification.GameScoreExtended", .many)
    self._Notification_GameScoreExtended_other = getValueWithForm(dict, "Notification.GameScoreExtended", .other)
    self._Call_Seconds_zero = getValueWithForm(dict, "Call.Seconds", .zero)
    self._Call_Seconds_one = getValueWithForm(dict, "Call.Seconds", .one)
    self._Call_Seconds_two = getValueWithForm(dict, "Call.Seconds", .two)
    self._Call_Seconds_few = getValueWithForm(dict, "Call.Seconds", .few)
    self._Call_Seconds_many = getValueWithForm(dict, "Call.Seconds", .many)
    self._Call_Seconds_other = getValueWithForm(dict, "Call.Seconds", .other)
    self._ForwardedAuthorsOthers_zero = getValueWithForm(dict, "ForwardedAuthorsOthers", .zero)
    self._ForwardedAuthorsOthers_one = getValueWithForm(dict, "ForwardedAuthorsOthers", .one)
    self._ForwardedAuthorsOthers_two = getValueWithForm(dict, "ForwardedAuthorsOthers", .two)
    self._ForwardedAuthorsOthers_few = getValueWithForm(dict, "ForwardedAuthorsOthers", .few)
    self._ForwardedAuthorsOthers_many = getValueWithForm(dict, "ForwardedAuthorsOthers", .many)
    self._ForwardedAuthorsOthers_other = getValueWithForm(dict, "ForwardedAuthorsOthers", .other)
    self._Call_ShortSeconds_zero = getValueWithForm(dict, "Call.ShortSeconds", .zero)
    self._Call_ShortSeconds_one = getValueWithForm(dict, "Call.ShortSeconds", .one)
    self._Call_ShortSeconds_two = getValueWithForm(dict, "Call.ShortSeconds", .two)
    self._Call_ShortSeconds_few = getValueWithForm(dict, "Call.ShortSeconds", .few)
    self._Call_ShortSeconds_many = getValueWithForm(dict, "Call.ShortSeconds", .many)
    self._Call_ShortSeconds_other = getValueWithForm(dict, "Call.ShortSeconds", .other)
    self._Media_ShareVideo_zero = getValueWithForm(dict, "Media.ShareVideo", .zero)
    self._Media_ShareVideo_one = getValueWithForm(dict, "Media.ShareVideo", .one)
    self._Media_ShareVideo_two = getValueWithForm(dict, "Media.ShareVideo", .two)
    self._Media_ShareVideo_few = getValueWithForm(dict, "Media.ShareVideo", .few)
    self._Media_ShareVideo_many = getValueWithForm(dict, "Media.ShareVideo", .many)
    self._Media_ShareVideo_other = getValueWithForm(dict, "Media.ShareVideo", .other)
    self._QuickSend_Photos_zero = getValueWithForm(dict, "QuickSend.Photos", .zero)
    self._QuickSend_Photos_one = getValueWithForm(dict, "QuickSend.Photos", .one)
    self._QuickSend_Photos_two = getValueWithForm(dict, "QuickSend.Photos", .two)
    self._QuickSend_Photos_few = getValueWithForm(dict, "QuickSend.Photos", .few)
    self._QuickSend_Photos_many = getValueWithForm(dict, "QuickSend.Photos", .many)
    self._QuickSend_Photos_other = getValueWithForm(dict, "QuickSend.Photos", .other)
    self._ForwardedGifs_zero = getValueWithForm(dict, "ForwardedGifs", .zero)
    self._ForwardedGifs_one = getValueWithForm(dict, "ForwardedGifs", .one)
    self._ForwardedGifs_two = getValueWithForm(dict, "ForwardedGifs", .two)
    self._ForwardedGifs_few = getValueWithForm(dict, "ForwardedGifs", .few)
    self._ForwardedGifs_many = getValueWithForm(dict, "ForwardedGifs", .many)
    self._ForwardedGifs_other = getValueWithForm(dict, "ForwardedGifs", .other)
    self._Notifications_ExceptionMuteExpires_Hours_zero = getValueWithForm(dict, "Notifications.ExceptionMuteExpires.Hours", .zero)
    self._Notifications_ExceptionMuteExpires_Hours_one = getValueWithForm(dict, "Notifications.ExceptionMuteExpires.Hours", .one)
    self._Notifications_ExceptionMuteExpires_Hours_two = getValueWithForm(dict, "Notifications.ExceptionMuteExpires.Hours", .two)
    self._Notifications_ExceptionMuteExpires_Hours_few = getValueWithForm(dict, "Notifications.ExceptionMuteExpires.Hours", .few)
    self._Notifications_ExceptionMuteExpires_Hours_many = getValueWithForm(dict, "Notifications.ExceptionMuteExpires.Hours", .many)
    self._Notifications_ExceptionMuteExpires_Hours_other = getValueWithForm(dict, "Notifications.ExceptionMuteExpires.Hours", .other)
    self._Call_ShortMinutes_zero = getValueWithForm(dict, "Call.ShortMinutes", .zero)
    self._Call_ShortMinutes_one = getValueWithForm(dict, "Call.ShortMinutes", .one)
    self._Call_ShortMinutes_two = getValueWithForm(dict, "Call.ShortMinutes", .two)
    self._Call_ShortMinutes_few = getValueWithForm(dict, "Call.ShortMinutes", .few)
    self._Call_ShortMinutes_many = getValueWithForm(dict, "Call.ShortMinutes", .many)
    self._Call_ShortMinutes_other = getValueWithForm(dict, "Call.ShortMinutes", .other)
    self._Notifications_Exceptions_zero = getValueWithForm(dict, "Notifications.Exceptions", .zero)
    self._Notifications_Exceptions_one = getValueWithForm(dict, "Notifications.Exceptions", .one)
    self._Notifications_Exceptions_two = getValueWithForm(dict, "Notifications.Exceptions", .two)
    self._Notifications_Exceptions_few = getValueWithForm(dict, "Notifications.Exceptions", .few)
    self._Notifications_Exceptions_many = getValueWithForm(dict, "Notifications.Exceptions", .many)
    self._Notifications_Exceptions_other = getValueWithForm(dict, "Notifications.Exceptions", .other)
    self._Contacts_ImportersCount_zero = getValueWithForm(dict, "Contacts.ImportersCount", .zero)
    self._Contacts_ImportersCount_one = getValueWithForm(dict, "Contacts.ImportersCount", .one)
    self._Contacts_ImportersCount_two = getValueWithForm(dict, "Contacts.ImportersCount", .two)
    self._Contacts_ImportersCount_few = getValueWithForm(dict, "Contacts.ImportersCount", .few)
    self._Contacts_ImportersCount_many = getValueWithForm(dict, "Contacts.ImportersCount", .many)
    self._Contacts_ImportersCount_other = getValueWithForm(dict, "Contacts.ImportersCount", .other)
    self._SharedMedia_Photo_zero = getValueWithForm(dict, "SharedMedia.Photo", .zero)
    self._SharedMedia_Photo_one = getValueWithForm(dict, "SharedMedia.Photo", .one)
    self._SharedMedia_Photo_two = getValueWithForm(dict, "SharedMedia.Photo", .two)
    self._SharedMedia_Photo_few = getValueWithForm(dict, "SharedMedia.Photo", .few)
    self._SharedMedia_Photo_many = getValueWithForm(dict, "SharedMedia.Photo", .many)
    self._SharedMedia_Photo_other = getValueWithForm(dict, "SharedMedia.Photo", .other)
    self._MessageTimer_Months_zero = getValueWithForm(dict, "MessageTimer.Months", .zero)
    self._MessageTimer_Months_one = getValueWithForm(dict, "MessageTimer.Months", .one)
    self._MessageTimer_Months_two = getValueWithForm(dict, "MessageTimer.Months", .two)
    self._MessageTimer_Months_few = getValueWithForm(dict, "MessageTimer.Months", .few)
    self._MessageTimer_Months_many = getValueWithForm(dict, "MessageTimer.Months", .many)
    self._MessageTimer_Months_other = getValueWithForm(dict, "MessageTimer.Months", .other)
    self._Watch_UserInfo_Mute_zero = getValueWithForm(dict, "Watch.UserInfo.Mute", .zero)
    self._Watch_UserInfo_Mute_one = getValueWithForm(dict, "Watch.UserInfo.Mute", .one)
    self._Watch_UserInfo_Mute_two = getValueWithForm(dict, "Watch.UserInfo.Mute", .two)
    self._Watch_UserInfo_Mute_few = getValueWithForm(dict, "Watch.UserInfo.Mute", .few)
    self._Watch_UserInfo_Mute_many = getValueWithForm(dict, "Watch.UserInfo.Mute", .many)
    self._Watch_UserInfo_Mute_other = getValueWithForm(dict, "Watch.UserInfo.Mute", .other)
    self._MessageTimer_Days_zero = getValueWithForm(dict, "MessageTimer.Days", .zero)
    self._MessageTimer_Days_one = getValueWithForm(dict, "MessageTimer.Days", .one)
    self._MessageTimer_Days_two = getValueWithForm(dict, "MessageTimer.Days", .two)
    self._MessageTimer_Days_few = getValueWithForm(dict, "MessageTimer.Days", .few)
    self._MessageTimer_Days_many = getValueWithForm(dict, "MessageTimer.Days", .many)
    self._MessageTimer_Days_other = getValueWithForm(dict, "MessageTimer.Days", .other)
    self._SharedMedia_Generic_zero = getValueWithForm(dict, "SharedMedia.Generic", .zero)
    self._SharedMedia_Generic_one = getValueWithForm(dict, "SharedMedia.Generic", .one)
    self._SharedMedia_Generic_two = getValueWithForm(dict, "SharedMedia.Generic", .two)
    self._SharedMedia_Generic_few = getValueWithForm(dict, "SharedMedia.Generic", .few)
    self._SharedMedia_Generic_many = getValueWithForm(dict, "SharedMedia.Generic", .many)
    self._SharedMedia_Generic_other = getValueWithForm(dict, "SharedMedia.Generic", .other)
    self._MessageTimer_Weeks_zero = getValueWithForm(dict, "MessageTimer.Weeks", .zero)
    self._MessageTimer_Weeks_one = getValueWithForm(dict, "MessageTimer.Weeks", .one)
    self._MessageTimer_Weeks_two = getValueWithForm(dict, "MessageTimer.Weeks", .two)
    self._MessageTimer_Weeks_few = getValueWithForm(dict, "MessageTimer.Weeks", .few)
    self._MessageTimer_Weeks_many = getValueWithForm(dict, "MessageTimer.Weeks", .many)
    self._MessageTimer_Weeks_other = getValueWithForm(dict, "MessageTimer.Weeks", .other)
    self._LiveLocationUpdated_MinutesAgo_zero = getValueWithForm(dict, "LiveLocationUpdated.MinutesAgo", .zero)
    self._LiveLocationUpdated_MinutesAgo_one = getValueWithForm(dict, "LiveLocationUpdated.MinutesAgo", .one)
    self._LiveLocationUpdated_MinutesAgo_two = getValueWithForm(dict, "LiveLocationUpdated.MinutesAgo", .two)
    self._LiveLocationUpdated_MinutesAgo_few = getValueWithForm(dict, "LiveLocationUpdated.MinutesAgo", .few)
    self._LiveLocationUpdated_MinutesAgo_many = getValueWithForm(dict, "LiveLocationUpdated.MinutesAgo", .many)
    self._LiveLocationUpdated_MinutesAgo_other = getValueWithForm(dict, "LiveLocationUpdated.MinutesAgo", .other)
        
    }
}

