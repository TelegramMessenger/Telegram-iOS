import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramUIPreferences
import TelegramCallsUI
import OverlayStatusController
import AccountContext
import PassportUI
import LocalAuth
import CallListUI
import ChatListUI
import NotificationSoundSelectionUI
import PresentationDataUtils
import PhoneNumberFormat
import AccountUtils

enum SettingsSearchableItemIcon {
    case profile
    case proxy
    case savedMessages
    case calls
    case stickers
    case notifications
    case privacy
    case data
    case appearance
    case language
    case watch
    case wallet
    case passport
    case support
    case faq
    case chatFolders
}

public enum SettingsSearchableItemId: Hashable {
    case profile(Int32)
    case proxy(Int32)
    case savedMessages(Int32)
    case calls(Int32)
    case stickers(Int32)
    case notifications(Int32)
    case privacy(Int32)
    case data(Int32)
    case appearance(Int32)
    case language(Int32)
    case watch(Int32)
    case passport(Int32)
    case wallet(Int32)
    case support(Int32)
    case faq(Int32)
    case chatFolders(Int32)
    
    private var namespace: Int32 {
        switch self {
            case .profile:
                return 1
            case .proxy:
                return 2
            case .savedMessages:
                return 3
            case .calls:
                return 4
            case .stickers:
                return 5
            case .notifications:
                return 6
            case .privacy:
                return 7
            case .data:
                return 8
            case .appearance:
                return 9
            case .language:
                return 10
            case .watch:
                return 11
            case .passport:
                return 12
            case .wallet:
                return 13
            case .support:
                return 14
            case .faq:
                return 15
            case .chatFolders:
                return 16
        }
    }
    
    private var id: Int32 {
        switch self {
            case let .profile(id),
                 let .proxy(id),
                 let .savedMessages(id),
                 let .calls(id),
                 let .stickers(id),
                 let .notifications(id),
                 let .privacy(id),
                 let .data(id),
                 let .appearance(id),
                 let .language(id),
                 let .watch(id),
                 let .passport(id),
                 let .wallet(id),
                 let .support(id),
                 let .faq(id),
                 let .chatFolders(id):
                return id
        }
    }
    
    var index: Int64 {
        return (Int64(self.namespace) << 32) | Int64(self.id)
    }
    
    init?(index: Int64) {
        let namespace = Int32((index >> 32) & 0x7fffffff)
        let id = Int32(bitPattern: UInt32(index & 0xffffffff))
        switch namespace {
            case 1:
                self = .profile(id)
            case 2:
                self = .proxy(id)
            case 3:
                self = .savedMessages(id)
            case 4:
                self = .calls(id)
            case 5:
                self = .stickers(id)
            case 6:
                self = .notifications(id)
            case 7:
                self = .privacy(id)
            case 8:
                self = .data(id)
            case 9:
                self = .appearance(id)
            case 10:
                self = .language(id)
            case 11:
                self = .watch(id)
            case 12:
                self = .passport(id)
            case 13:
                self = .wallet(id)
            case 14:
                self = .support(id)
            case 15:
                self = .faq(id)
            case 16:
                self = .chatFolders(id)
            default:
                return nil
        }
    }
}

public enum SettingsSearchableItemPresentation {
    case push
    case modal
    case immediate
    case dismiss
}

public struct SettingsSearchableItem {
    public let id: SettingsSearchableItemId
    let title: String
    let alternate: [String]
    let icon: SettingsSearchableItemIcon
    let breadcrumbs: [String]
    public let present: (AccountContext, NavigationController?, @escaping (SettingsSearchableItemPresentation, ViewController?) -> Void) -> Void
}

private func synonyms(_ string: String?) -> [String] {
    if let string = string, !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        return string.components(separatedBy: "\n")
    } else {
        return []
    }
}

private func profileSearchableItems(context: AccountContext, canAddAccount: Bool) -> [SettingsSearchableItem] {
    let icon: SettingsSearchableItemIcon = .profile
    let strings = context.sharedContext.currentPresentationData.with { $0 }.strings
    
    var items: [SettingsSearchableItem] = []
    items.append(SettingsSearchableItem(id: .profile(2), title: strings.Settings_PhoneNumber, alternate: synonyms(strings.SettingsSearch_Synonyms_EditProfile_PhoneNumber), icon: icon, breadcrumbs: [strings.EditProfile_Title], present: { context, _, present in
        let _ = (context.account.postbox.transaction { transaction -> String in
            return (transaction.getPeer(context.account.peerId) as? TelegramUser)?.phone ?? ""
        }
        |> deliverOnMainQueue).start(next: { phoneNumber in
            present(.push, PrivacyIntroController(context: context, mode: .changePhoneNumber(phoneNumber), proceedAction: {
                present(.push, ChangePhoneNumberController(context: context))
            }))
        })
    }))
    items.append(SettingsSearchableItem(id: .profile(3), title: strings.Settings_Username, alternate: synonyms(strings.SettingsSearch_Synonyms_EditProfile_Username), icon: icon, breadcrumbs: [strings.EditProfile_Title], present: { context, _, present in
        present(.modal, usernameSetupController(context: context))
    }))
    if canAddAccount {
        items.append(SettingsSearchableItem(id: .profile(4), title: strings.Settings_AddAccount, alternate: synonyms(strings.SettingsSearch_Synonyms_EditProfile_AddAccount), icon: icon, breadcrumbs: [strings.EditProfile_Title], present: { context, _, present in
            let isTestingEnvironment = context.account.testingEnvironment
            context.sharedContext.beginNewAuth(testingEnvironment: isTestingEnvironment)
        }))
    }
    items.append(SettingsSearchableItem(id: .profile(5), title: strings.Settings_Logout, alternate: synonyms(strings.SettingsSearch_Synonyms_EditProfile_Logout), icon: icon, breadcrumbs: [strings.EditProfile_Title], present: { context, navigationController, present in
        let _ = (context.account.postbox.transaction { transaction -> String in
            return (transaction.getPeer(context.account.peerId) as? TelegramUser)?.phone ?? ""
        }
        |> deliverOnMainQueue).start(next: { phoneNumber in
            if let navigationController = navigationController {
                present(.modal, logoutOptionsController(context: context, navigationController: navigationController, canAddAccounts: canAddAccount, phoneNumber: phoneNumber))
            }
        })
    }))
    return items
}

private func callSearchableItems(context: AccountContext) -> [SettingsSearchableItem] {
    let icon: SettingsSearchableItemIcon = .calls
    let strings = context.sharedContext.currentPresentationData.with { $0 }.strings
    
    let presentCallSettings: (AccountContext, (SettingsSearchableItemPresentation, ViewController?) -> Void) -> Void = { context, present in
        present(.push, CallListController(context: context, mode: .navigation))
    }
    
    return [
        SettingsSearchableItem(id: .calls(0), title: strings.CallSettings_RecentCalls, alternate: synonyms(strings.SettingsSearch_Synonyms_Calls_Title), icon: icon, breadcrumbs: [], present: { context, _, present in
            presentCallSettings(context, present)
        }),
        SettingsSearchableItem(id: .calls(1), title: strings.CallSettings_TabIcon, alternate: synonyms(strings.SettingsSearch_Synonyms_Calls_CallTab), icon: icon, breadcrumbs: [strings.CallSettings_RecentCalls], present: { context, _, present in
            presentCallSettings(context, present)
        })
    ]
}

private func stickerSearchableItems(context: AccountContext, archivedStickerPacks: [ArchivedStickerPackItem]?) -> [SettingsSearchableItem] {
    let icon: SettingsSearchableItemIcon = .stickers
    let strings = context.sharedContext.currentPresentationData.with { $0 }.strings
    
    let presentStickerSettings: (AccountContext, (SettingsSearchableItemPresentation, ViewController?) -> Void, InstalledStickerPacksEntryTag?) -> Void = { context, present, itemTag in
        present(.push, installedStickerPacksController(context: context, mode: .general, archivedPacks: archivedStickerPacks, updatedPacks: { _ in }, focusOnItemTag: itemTag))
    }
    
    var items: [SettingsSearchableItem] = []
    
    items.append(SettingsSearchableItem(id: .stickers(0), title: strings.ChatSettings_Stickers, alternate: synonyms(strings.SettingsSearch_Synonyms_Stickers_Title), icon: icon, breadcrumbs: [], present: { context, _, present in
        presentStickerSettings(context, present, nil)
    }))
    items.append(SettingsSearchableItem(id: .stickers(1), title: strings.Stickers_SuggestStickers, alternate: synonyms(strings.SettingsSearch_Synonyms_Stickers_SuggestStickers), icon: icon, breadcrumbs: [strings.ChatSettings_Stickers], present: { context, _, present in
        presentStickerSettings(context, present, .suggestOptions)
    }))
    items.append(SettingsSearchableItem(id: .stickers(2), title: strings.StickerPacksSettings_AnimatedStickers, alternate: synonyms(strings.StickerPacksSettings_AnimatedStickers), icon: icon, breadcrumbs: [strings.ChatSettings_Stickers], present: { context, _, present in
        presentStickerSettings(context, present, .loopAnimatedStickers)
    }))
    items.append(SettingsSearchableItem(id: .stickers(3), title: strings.StickerPacksSettings_FeaturedPacks, alternate: synonyms(strings.SettingsSearch_Synonyms_Stickers_FeaturedPacks), icon: icon, breadcrumbs: [strings.ChatSettings_Stickers], present: { context, _, present in
        present(.push, featuredStickerPacksController(context: context))
    }))
    if !(archivedStickerPacks?.isEmpty ?? true) {
        items.append(SettingsSearchableItem(id: .stickers(4), title: strings.StickerPacksSettings_ArchivedPacks, alternate: synonyms(strings.SettingsSearch_Synonyms_Stickers_ArchivedPacks), icon: icon, breadcrumbs: [strings.ChatSettings_Stickers], present: { context, _, present in
            present(.push, archivedStickerPacksController(context: context, mode: .stickers, archived: archivedStickerPacks, updatedPacks: { _ in }))
        }))
    }
    items.append(SettingsSearchableItem(id: .stickers(5), title: strings.MaskStickerSettings_Title, alternate: synonyms(strings.SettingsSearch_Synonyms_Stickers_Masks), icon: icon, breadcrumbs: [strings.ChatSettings_Stickers], present: { context, _, present in
        present(.push, installedStickerPacksController(context: context, mode: .masks, archivedPacks: nil, updatedPacks: { _ in }))
    }))
    return items
}

private func notificationSearchableItems(context: AccountContext, settings: GlobalNotificationSettingsSet, exceptionsList: NotificationExceptionsList?) -> [SettingsSearchableItem] {
    let icon: SettingsSearchableItemIcon = .notifications
    let strings = context.sharedContext.currentPresentationData.with { $0 }.strings
    
    let presentNotificationSettings: (AccountContext, (SettingsSearchableItemPresentation, ViewController?) -> Void, NotificationsAndSoundsEntryTag?) -> Void = { context, present, itemTag in
        present(.push, notificationsAndSoundsController(context: context, exceptionsList: exceptionsList, focusOnItemTag: itemTag))
    }
    
    let exceptions = { () -> (NotificationExceptionMode, NotificationExceptionMode, NotificationExceptionMode) in
        var users:[PeerId : NotificationExceptionWrapper] = [:]
        var groups: [PeerId : NotificationExceptionWrapper] = [:]
        var channels:[PeerId : NotificationExceptionWrapper] = [:]
        if let list = exceptionsList {
            for (key, value) in list.settings {
                if let peer = list.peers[key], !peer.debugDisplayTitle.isEmpty, peer.id != context.account.peerId {
                    switch value.muteState {
                        case .default:
                            switch value.messageSound {
                                case .default:
                                    break
                                default:
                                    switch key.namespace {
                                        case Namespaces.Peer.CloudUser:
                                            users[key] = NotificationExceptionWrapper(settings: value, peer: peer)
                                        default:
                                            if let peer = peer as? TelegramChannel, case .broadcast = peer.info {
                                                channels[key] = NotificationExceptionWrapper(settings: value, peer: peer)
                                            } else {
                                                groups[key] = NotificationExceptionWrapper(settings: value, peer: peer)
                                            }
                                    }
                            }
                        default:
                            switch key.namespace {
                                case Namespaces.Peer.CloudUser:
                                    users[key] = NotificationExceptionWrapper(settings: value, peer: peer)
                                default:
                                    if let peer = peer as? TelegramChannel, case .broadcast = peer.info {
                                        channels[key] = NotificationExceptionWrapper(settings: value, peer: peer)
                                    } else {
                                        groups[key] = NotificationExceptionWrapper(settings: value, peer: peer)
                                    }
                            }
                    }
                }
            }
        }
        return (.users(users), .groups(groups), .channels(channels))
    }
    
    func filteredGlobalSound(_ sound: PeerMessageSound) -> PeerMessageSound {
        if case .default = sound {
            return defaultCloudPeerNotificationSound
        } else {
            return sound
        }
    }
    
    return [
        SettingsSearchableItem(id: .notifications(0), title: strings.Settings_NotificationsAndSounds, alternate: synonyms(strings.SettingsSearch_Synonyms_Notifications_Title), icon: icon, breadcrumbs: [], present: { context, _, present in
            presentNotificationSettings(context, present, nil)
        }),
//        SettingsSearchableItem(id: .notifications(1), title: strings.Notifications_MessageNotificationsAlert, alternate: synonyms(strings.SettingsSearch_Synonyms_Notifications_MessageNotificationsAlert), icon: icon, breadcrumbs: [strings.Settings_NotificationsAndSounds, strings.Notifications_MessageNotifications], present: { context, _, present in
//            presentNotificationSettings(context, present, .messageAlerts)
//        }),
//        SettingsSearchableItem(id: .notifications(2), title: strings.Notifications_MessageNotificationsPreview, alternate: synonyms(strings.SettingsSearch_Synonyms_Notifications_MessageNotificationsPreview), icon: icon, breadcrumbs: [strings.Settings_NotificationsAndSounds, strings.Notifications_MessageNotifications], present: { context, _, present in
//            presentNotificationSettings(context, present, .messagePreviews)
//        }),
        SettingsSearchableItem(id: .notifications(3), title: strings.Notifications_MessageNotificationsSound, alternate: synonyms(strings.SettingsSearch_Synonyms_Notifications_MessageNotificationsSound), icon: icon, breadcrumbs: [strings.Settings_NotificationsAndSounds, strings.Notifications_MessageNotifications], present: { context, _, present in
            
            let controller = notificationSoundSelectionController(context: context, isModal: true, currentSound: filteredGlobalSound(settings.privateChats.sound), defaultSound: nil, completion: { value in
                let _ = updateGlobalNotificationSettingsInteractively(postbox: context.account.postbox, { settings in
                    var settings = settings
                    settings.privateChats.sound = value
                    return settings
                }).start()
            })
            present(.modal, controller)
        }),
        SettingsSearchableItem(id: .notifications(4), title: strings.Notifications_MessageNotificationsExceptions, alternate: synonyms(strings.SettingsSearch_Synonyms_Notifications_MessageNotificationsExceptions), icon: icon, breadcrumbs: [strings.Settings_NotificationsAndSounds, strings.Notifications_MessageNotifications], present: { context, _, present in
            present(.push, NotificationExceptionsController(context: context, mode: exceptions().0, updatedMode: { _ in}))
        }),
//        SettingsSearchableItem(id: .notifications(5), title: strings.Notifications_GroupNotificationsAlert, alternate: synonyms(strings.SettingsSearch_Synonyms_Notifications_GroupNotificationsAlert), icon: icon, breadcrumbs: [strings.Settings_NotificationsAndSounds, strings.Notifications_GroupNotifications], present: { context, _, present in
//            presentNotificationSettings(context, present, .groupAlerts)
//        }),
//        SettingsSearchableItem(id: .notifications(6), title: strings.Notifications_GroupNotificationsPreview, alternate: synonyms(strings.SettingsSearch_Synonyms_Notifications_GroupNotificationsPreview), icon: icon, breadcrumbs: [strings.Settings_NotificationsAndSounds, strings.Notifications_GroupNotifications], present: { context, _, present in
//            presentNotificationSettings(context, present, .groupPreviews)
//        }),
        SettingsSearchableItem(id: .notifications(7), title: strings.Notifications_GroupNotificationsSound, alternate: synonyms(strings.SettingsSearch_Synonyms_Notifications_GroupNotificationsSound), icon: icon, breadcrumbs: [strings.Settings_NotificationsAndSounds, strings.Notifications_GroupNotifications], present: { context, _, present in
            let controller = notificationSoundSelectionController(context: context, isModal: true, currentSound: filteredGlobalSound(settings.groupChats.sound), defaultSound: nil, completion: { value in
                let _ = updateGlobalNotificationSettingsInteractively(postbox: context.account.postbox, { settings in
                    var settings = settings
                    settings.groupChats.sound = value
                    return settings
                }).start()
            })
            present(.modal, controller)
        }),
        SettingsSearchableItem(id: .notifications(8), title: strings.Notifications_GroupNotificationsExceptions, alternate: synonyms(strings.SettingsSearch_Synonyms_Notifications_GroupNotificationsExceptions), icon: icon, breadcrumbs: [strings.Settings_NotificationsAndSounds, strings.Notifications_GroupNotifications], present: { context, _, present in
            present(.push, NotificationExceptionsController(context: context, mode: exceptions().1, updatedMode: { _ in}))
        }),
//        SettingsSearchableItem(id: .notifications(9), title: strings.Notifications_ChannelNotificationsAlert, alternate: synonyms(strings.SettingsSearch_Synonyms_Notifications_ChannelNotificationsAlert), icon: icon, breadcrumbs: [strings.Settings_NotificationsAndSounds, strings.Notifications_ChannelNotifications], present: { context, _, present in
//            presentNotificationSettings(context, present, .channelAlerts)
//        }),
//        SettingsSearchableItem(id: .notifications(10), title: strings.Notifications_ChannelNotificationsPreview, alternate: synonyms(strings.SettingsSearch_Synonyms_Notifications_ChannelNotificationsPreview), icon: icon, breadcrumbs: [strings.Settings_NotificationsAndSounds, strings.Notifications_ChannelNotifications], present: { context, _, present in
//            presentNotificationSettings(context, present, .channelPreviews)
//        }),
        SettingsSearchableItem(id: .notifications(11), title: strings.Notifications_ChannelNotificationsSound, alternate: synonyms(strings.SettingsSearch_Synonyms_Notifications_ChannelNotificationsSound), icon: icon, breadcrumbs: [strings.Settings_NotificationsAndSounds, strings.Notifications_ChannelNotifications], present: { context, _, present in
            let controller = notificationSoundSelectionController(context: context, isModal: true, currentSound: filteredGlobalSound(settings.channels.sound), defaultSound: nil, completion: { value in
                let _ = updateGlobalNotificationSettingsInteractively(postbox: context.account.postbox, { settings in
                    var settings = settings
                    settings.channels.sound = value
                    return settings
                }).start()
            })
            present(.modal, controller)
        }),
        SettingsSearchableItem(id: .notifications(12), title: strings.Notifications_MessageNotificationsExceptions, alternate: synonyms(strings.SettingsSearch_Synonyms_Notifications_ChannelNotificationsExceptions), icon: icon, breadcrumbs: [strings.Settings_NotificationsAndSounds, strings.Notifications_ChannelNotifications], present: { context, _, present in
            present(.push, NotificationExceptionsController(context: context, mode: exceptions().2, updatedMode: { _ in}))
        }),
        SettingsSearchableItem(id: .notifications(13), title: strings.Notifications_InAppNotificationsSounds, alternate: synonyms(strings.SettingsSearch_Synonyms_Notifications_InAppNotificationsSound), icon: icon, breadcrumbs: [strings.Settings_NotificationsAndSounds, strings.Notifications_InAppNotifications], present: { context, _, present in
            presentNotificationSettings(context, present, .inAppSounds)
        }),
        SettingsSearchableItem(id: .notifications(14), title: strings.Notifications_InAppNotificationsVibrate, alternate: synonyms(strings.SettingsSearch_Synonyms_Notifications_InAppNotificationsVibrate), icon: icon, breadcrumbs: [strings.Settings_NotificationsAndSounds, strings.Notifications_InAppNotifications], present: { context, _, present in
            presentNotificationSettings(context, present, .inAppVibrate)
        }),
        SettingsSearchableItem(id: .notifications(15), title: strings.Notifications_InAppNotificationsPreview, alternate: synonyms(strings.SettingsSearch_Synonyms_Notifications_InAppNotificationsPreview), icon: icon, breadcrumbs: [strings.Settings_NotificationsAndSounds, strings.Notifications_InAppNotifications], present: { context, _, present in
            presentNotificationSettings(context, present, .inAppPreviews)
        }),
        SettingsSearchableItem(id: .notifications(16), title: strings.Notifications_DisplayNamesOnLockScreen, alternate: synonyms(strings.SettingsSearch_Synonyms_Notifications_DisplayNamesOnLockScreen), icon: icon, breadcrumbs: [strings.Settings_NotificationsAndSounds], present: { context, _, present in
            presentNotificationSettings(context, present, .displayNamesOnLockscreen)
        }),
        SettingsSearchableItem(id: .notifications(19), title: strings.Notifications_Badge_IncludeChannels, alternate: synonyms(strings.SettingsSearch_Synonyms_Notifications_BadgeIncludeMutedChannels), icon: icon, breadcrumbs: [strings.Settings_NotificationsAndSounds, strings.Notifications_Badge], present: { context, _, present in
            presentNotificationSettings(context, present, .includeChannels)
        }),
        SettingsSearchableItem(id: .notifications(20), title: strings.Notifications_Badge_CountUnreadMessages, alternate: synonyms(strings.SettingsSearch_Synonyms_Notifications_BadgeCountUnreadMessages), icon: icon, breadcrumbs: [strings.Settings_NotificationsAndSounds, strings.Notifications_Badge], present: { context, _, present in
            presentNotificationSettings(context, present, .unreadCountCategory)
        }),
        SettingsSearchableItem(id: .notifications(21), title: strings.NotificationSettings_ContactJoined, alternate: synonyms(strings.SettingsSearch_Synonyms_Notifications_ContactJoined), icon: icon, breadcrumbs: [strings.Settings_NotificationsAndSounds], present: { context, _, present in
            presentNotificationSettings(context, present, .joinedNotifications)
        }),
        SettingsSearchableItem(id: .notifications(22), title: strings.Notifications_ResetAllNotifications, alternate: synonyms(strings.SettingsSearch_Synonyms_Notifications_ResetAllNotifications), icon: icon, breadcrumbs: [strings.Settings_NotificationsAndSounds], present: { context, _, present in
            presentNotificationSettings(context, present, .reset)
        })
    ]
}

private func privacySearchableItems(context: AccountContext, privacySettings: AccountPrivacySettings?, activeSessionsContext: ActiveSessionsContext?, webSessionsContext: WebSessionsContext?) -> [SettingsSearchableItem] {
    let icon: SettingsSearchableItemIcon = .privacy
    let strings = context.sharedContext.currentPresentationData.with { $0 }.strings
    
    let presentPrivacySettings: (AccountContext, (SettingsSearchableItemPresentation, ViewController?) -> Void, PrivacyAndSecurityEntryTag?) -> Void = { context, present, itemTag in
        present(.push, privacyAndSecurityController(context: context, focusOnItemTag: itemTag))
    }
    
    let presentSelectivePrivacySettings: (AccountContext, SelectivePrivacySettingsKind, @escaping (SettingsSearchableItemPresentation, ViewController?) -> Void) -> Void = { context, kind, present in
        let privacySignal: Signal<AccountPrivacySettings, NoError>
        if let privacySettings = privacySettings {
            privacySignal = .single(privacySettings)
        } else {
            privacySignal = context.engine.privacy.requestAccountPrivacySettings()
        }
        let callsSignal: Signal<(VoiceCallSettings, VoipConfiguration)?, NoError>
        if case .voiceCalls = kind {
            callsSignal = combineLatest(context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.voiceCallSettings]), context.account.postbox.preferencesView(keys: [PreferencesKeys.voipConfiguration]))
            |> take(1)
            |> map { sharedData, view -> (VoiceCallSettings, VoipConfiguration)? in
                let voiceCallSettings: VoiceCallSettings = sharedData.entries[ApplicationSpecificSharedDataKeys.voiceCallSettings]?.get(VoiceCallSettings.self) ?? .defaultSettings
                let voipConfiguration = view.values[PreferencesKeys.voipConfiguration]?.get(VoipConfiguration.self) ?? .defaultValue
                return (voiceCallSettings, voipConfiguration)
            }
        } else {
            callsSignal = .single(nil)
        }

        let _ = (combineLatest(privacySignal, callsSignal)
        |> deliverOnMainQueue).start(next: { info, callSettings in
            let current: SelectivePrivacySettings
            switch kind {
                case .presence:
                    current = info.presence
                case .groupInvitations:
                    current = info.groupInvitations
                case .voiceCalls:
                    current = info.voiceCalls
                case .profilePhoto:
                    current = info.profilePhoto
                case .forwards:
                    current = info.forwards
                case .phoneNumber:
                    current = info.phoneNumber
            }

            present(.push, selectivePrivacySettingsController(context: context, kind: kind, current: current, callSettings: callSettings != nil ? (info.voiceCallsP2P, callSettings!.0) : nil, voipConfiguration: callSettings?.1, callIntegrationAvailable: CallKitIntegration.isAvailable, updated: { updated, updatedCallSettings, _ in
                    if let (_, updatedCallSettings) = updatedCallSettings  {
                        let _ = updateVoiceCallSettingsSettingsInteractively(accountManager: context.sharedContext.accountManager, { _ in
                            return updatedCallSettings
                        }).start()
                    }
                }))
        })
    }
    
    let presentDataPrivacySettings: (AccountContext, (SettingsSearchableItemPresentation, ViewController?) -> Void) -> Void = { context, present in
        present(.push, dataPrivacyController(context: context))
    }
    
    let passcodeTitle: String
    let passcodeAlternate: [String]
    if let biometricAuthentication = LocalAuth.biometricAuthentication {
        switch biometricAuthentication {
            case .touchId:
                passcodeTitle = strings.PrivacySettings_PasscodeAndTouchId
                passcodeAlternate = synonyms(strings.SettingsSearch_Synonyms_Privacy_PasscodeAndTouchId)
            case .faceId:
                passcodeTitle = strings.PrivacySettings_PasscodeAndFaceId
                passcodeAlternate = synonyms(strings.SettingsSearch_Synonyms_Privacy_PasscodeAndFaceId)
        }
    } else {
        passcodeTitle = strings.PrivacySettings_Passcode
        passcodeAlternate = synonyms(strings.SettingsSearch_Synonyms_Privacy_Passcode)
    }
    
    return ([
        SettingsSearchableItem(id: .privacy(0), title: strings.Settings_PrivacySettings, alternate: synonyms(strings.SettingsSearch_Synonyms_Privacy_Title), icon: icon, breadcrumbs: [], present: { context, _, present in
            presentPrivacySettings(context, present, nil)
        }),
        SettingsSearchableItem(id: .privacy(1), title: strings.Settings_BlockedUsers, alternate: synonyms(strings.SettingsSearch_Synonyms_Privacy_BlockedUsers), icon: icon, breadcrumbs: [strings.Settings_PrivacySettings], present: { context, _, present in
            present(.push, blockedPeersController(context: context, blockedPeersContext: BlockedPeersContext(account: context.account)))
        }),
        SettingsSearchableItem(id: .privacy(2), title: strings.PrivacySettings_LastSeen, alternate: synonyms(strings.SettingsSearch_Synonyms_Privacy_LastSeen), icon: icon, breadcrumbs: [strings.Settings_PrivacySettings], present: { context, _, present in
            presentSelectivePrivacySettings(context, .presence, present)
        }),
        SettingsSearchableItem(id: .privacy(3), title: strings.Privacy_ProfilePhoto, alternate: synonyms(strings.SettingsSearch_Synonyms_Privacy_ProfilePhoto), icon: icon, breadcrumbs: [strings.Settings_PrivacySettings], present: { context, _, present in
            presentSelectivePrivacySettings(context, .profilePhoto, present)
        }),
        SettingsSearchableItem(id: .privacy(4), title: strings.Privacy_Forwards, alternate: synonyms(strings.SettingsSearch_Synonyms_Privacy_Forwards), icon: icon, breadcrumbs: [strings.Settings_PrivacySettings], present: { context, _, present in
            presentSelectivePrivacySettings(context, .forwards, present)
        }),
        SettingsSearchableItem(id: .privacy(5), title: strings.Privacy_Calls, alternate: synonyms(strings.SettingsSearch_Synonyms_Privacy_Calls), icon: icon, breadcrumbs: [strings.Settings_PrivacySettings], present: { context, _, present in
            presentSelectivePrivacySettings(context, .voiceCalls, present)
        }),
        SettingsSearchableItem(id: .privacy(6), title: strings.Privacy_GroupsAndChannels, alternate: synonyms(strings.SettingsSearch_Synonyms_Privacy_GroupsAndChannels), icon: icon, breadcrumbs: [strings.Settings_PrivacySettings], present: { context, _, present in
            presentSelectivePrivacySettings(context, .groupInvitations, present)
        }),
        SettingsSearchableItem(id: .privacy(7), title: passcodeTitle, alternate: passcodeAlternate, icon: icon, breadcrumbs: [strings.Settings_PrivacySettings], present: { context, _, present in
            let _ = passcodeOptionsAccessController(context: context, pushController: { c in 
                present(.push, c)
            }, completion: { animated in
                let controller = passcodeOptionsController(context: context)
                if animated {
                    present(.push, controller)
                } else {
                    present(.push, controller)
                }
            }).start(next: { controller in
                if let controller = controller {
                    present(.push, controller)
                }
            })
        }),
        SettingsSearchableItem(id: .privacy(8), title: strings.PrivacySettings_TwoStepAuth, alternate: synonyms(strings.SettingsSearch_Synonyms_Privacy_TwoStepAuth), icon: icon, breadcrumbs: [strings.Settings_PrivacySettings], present: { context, _, present in
            present(.push, twoStepVerificationUnlockSettingsController(context: context, mode: .access(intro: true, data: nil)))
        }),
        activeSessionsContext == nil ? nil : SettingsSearchableItem(id: .privacy(9), title: strings.Settings_Devices, alternate: synonyms(strings.SettingsSearch_Synonyms_Privacy_AuthSessions) + [strings.PrivacySettings_AuthSessions], icon: icon, breadcrumbs: [strings.Settings_PrivacySettings], present: { context, _, present in
            present(.push, recentSessionsController(context: context, activeSessionsContext: activeSessionsContext!, webSessionsContext: webSessionsContext ?? context.engine.privacy.webSessions(), websitesOnly: false))
        }),
        webSessionsContext == nil ? nil : SettingsSearchableItem(id: .privacy(10), title: strings.PrivacySettings_WebSessions, alternate: synonyms(strings.SettingsSearch_Synonyms_Privacy_AuthSessions), icon: icon, breadcrumbs: [strings.Settings_PrivacySettings], present: { context, _, present in
            present(.push, recentSessionsController(context: context, activeSessionsContext: activeSessionsContext ?? context.engine.privacy.activeSessions(), webSessionsContext: webSessionsContext ?? context.engine.privacy.webSessions(), websitesOnly: true))
        }),
        SettingsSearchableItem(id: .privacy(11), title: strings.PrivacySettings_DeleteAccountTitle, alternate: synonyms(strings.SettingsSearch_Synonyms_Privacy_DeleteAccountIfAwayFor), icon: icon, breadcrumbs: [strings.Settings_PrivacySettings], present: { context, _, present in
            presentPrivacySettings(context, present, .accountTimeout)
        }),
        SettingsSearchableItem(id: .privacy(12), title: strings.PrivacySettings_DataSettings, alternate: synonyms(strings.SettingsSearch_Synonyms_Privacy_Data_Title), icon: icon, breadcrumbs: [strings.Settings_PrivacySettings], present: { context, _, present in
            presentDataPrivacySettings(context, present)
        }),
        SettingsSearchableItem(id: .privacy(13), title: strings.Privacy_ContactsReset, alternate: synonyms(strings.SettingsSearch_Synonyms_Privacy_Data_ContactsReset), icon: icon, breadcrumbs: [strings.Settings_PrivacySettings, strings.PrivacySettings_DataSettings], present: { context, _, present in
            presentDataPrivacySettings(context, present)
        }),
        SettingsSearchableItem(id: .privacy(14), title: strings.Privacy_ContactsSync, alternate: synonyms(strings.SettingsSearch_Synonyms_Privacy_Data_ContactsSync), icon: icon, breadcrumbs: [strings.Settings_PrivacySettings, strings.PrivacySettings_DataSettings], present: { context, _, present in
            presentDataPrivacySettings(context, present)
        }),
        SettingsSearchableItem(id: .privacy(15), title: strings.Privacy_TopPeers, alternate: synonyms(strings.SettingsSearch_Synonyms_Privacy_Data_TopPeers), icon: icon, breadcrumbs: [strings.Settings_PrivacySettings, strings.PrivacySettings_DataSettings], present: { context, _, present in
            presentDataPrivacySettings(context, present)
        }),
        SettingsSearchableItem(id: .privacy(16), title: strings.Privacy_DeleteDrafts, alternate: synonyms(strings.SettingsSearch_Synonyms_Privacy_Data_DeleteDrafts), icon: icon, breadcrumbs: [strings.Settings_PrivacySettings, strings.PrivacySettings_DataSettings], present: { context, _, present in
            presentDataPrivacySettings(context, present)
        }),
        SettingsSearchableItem(id: .privacy(17), title: strings.Privacy_PaymentsClearInfo, alternate: synonyms(strings.SettingsSearch_Synonyms_Privacy_Data_ClearPaymentsInfo), icon: icon, breadcrumbs: [strings.Settings_PrivacySettings, strings.PrivacySettings_DataSettings], present: { context, _, present in
            presentDataPrivacySettings(context, present)
        }),
        SettingsSearchableItem(id: .privacy(18), title: strings.Privacy_SecretChatsLinkPreviews, alternate: synonyms(strings.SettingsSearch_Synonyms_Privacy_Data_SecretChatLinkPreview), icon: icon, breadcrumbs: [strings.Settings_PrivacySettings, strings.PrivacySettings_DataSettings, strings.Privacy_SecretChatsTitle], present: { context, _, present in
            presentDataPrivacySettings(context, present)
        })
    ] as [SettingsSearchableItem?]).compactMap { $0 }
}

private func dataSearchableItems(context: AccountContext) -> [SettingsSearchableItem] {
    let icon: SettingsSearchableItemIcon = .data
    let strings = context.sharedContext.currentPresentationData.with { $0 }.strings
    
    let presentDataSettings: (AccountContext, (SettingsSearchableItemPresentation, ViewController?) -> Void, DataAndStorageEntryTag?) -> Void = { context, present, itemTag in
        present(.push, dataAndStorageController(context: context, focusOnItemTag: itemTag))
    }
    
    return [
        SettingsSearchableItem(id: .data(0), title: strings.Settings_ChatSettings, alternate: synonyms(strings.SettingsSearch_Synonyms_Data_Title), icon: icon, breadcrumbs: [], present: { context, _, present in
            presentDataSettings(context, present, nil)
        }),
        SettingsSearchableItem(id: .data(1), title: strings.ChatSettings_Cache, alternate: synonyms(strings.SettingsSearch_Synonyms_Data_Storage_Title), icon: icon, breadcrumbs: [strings.Settings_ChatSettings], present: { context, _, present in
            present(.push, storageUsageController(context: context))
        }),
        SettingsSearchableItem(id: .data(2), title: strings.Cache_KeepMedia, alternate: synonyms(strings.SettingsSearch_Synonyms_Data_Storage_KeepMedia), icon: icon, breadcrumbs: [strings.Settings_ChatSettings, strings.ChatSettings_Cache], present: { context, _, present in
            present(.push, storageUsageController(context: context))
        }),
        SettingsSearchableItem(id: .data(3), title: strings.Cache_ClearCache, alternate: synonyms(strings.SettingsSearch_Synonyms_Data_Storage_ClearCache), icon: icon, breadcrumbs: [strings.Settings_ChatSettings, strings.ChatSettings_Cache], present: { context, _, present in
            present(.push, storageUsageController(context: context))
        }),
        SettingsSearchableItem(id: .data(4), title: strings.NetworkUsageSettings_Title, alternate: synonyms(strings.SettingsSearch_Synonyms_Data_NetworkUsage), icon: icon, breadcrumbs: [strings.Settings_ChatSettings], present: { context, _, present in
            present(.push, networkUsageStatsController(context: context))
        }),
        SettingsSearchableItem(id: .data(5), title: strings.ChatSettings_AutoDownloadUsingCellular, alternate: synonyms(strings.SettingsSearch_Synonyms_Data_AutoDownloadUsingCellular), icon: icon, breadcrumbs: [strings.Settings_ChatSettings, strings.ChatSettings_AutoDownloadTitle], present: { context, _, present in
            present(.push, autodownloadMediaConnectionTypeController(context: context, connectionType: .cellular))
        }),
        SettingsSearchableItem(id: .data(6), title: strings.ChatSettings_AutoDownloadUsingWiFi, alternate: synonyms(strings.SettingsSearch_Synonyms_Data_AutoDownloadUsingWifi), icon: icon, breadcrumbs: [strings.Settings_ChatSettings, strings.ChatSettings_AutoDownloadTitle], present: { context, _, present in
            present(.push, autodownloadMediaConnectionTypeController(context: context, connectionType: .wifi))
        }),
        SettingsSearchableItem(id: .data(7), title: strings.ChatSettings_AutoDownloadReset, alternate: synonyms(strings.SettingsSearch_Synonyms_Data_AutoDownloadReset), icon: icon, breadcrumbs: [strings.Settings_ChatSettings], present: { context, _, present in
            presentDataSettings(context, present, .automaticDownloadReset)
        }),
        SettingsSearchableItem(id: .data(8), title: strings.ChatSettings_AutoPlayGifs, alternate: synonyms(strings.SettingsSearch_Synonyms_Data_AutoplayGifs), icon: icon, breadcrumbs: [strings.Settings_ChatSettings, strings.ChatSettings_AutoPlayTitle], present: { context, _, present in
            presentDataSettings(context, present, .autoplayGifs)
        }),
        SettingsSearchableItem(id: .data(9), title: strings.ChatSettings_AutoPlayVideos, alternate: synonyms(strings.SettingsSearch_Synonyms_Data_AutoplayVideos), icon: icon, breadcrumbs: [strings.Settings_ChatSettings, strings.ChatSettings_AutoPlayTitle], present: { context, _, present in
            presentDataSettings(context, present, .autoplayVideos)
        }),
        SettingsSearchableItem(id: .data(10), title: strings.CallSettings_UseLessData, alternate: synonyms(strings.SettingsSearch_Synonyms_Data_CallsUseLessData), icon: icon, breadcrumbs: [strings.Settings_ChatSettings, strings.Settings_CallSettings], present: { context, _, present in
            present(.push, voiceCallDataSavingController(context: context))
        }),
        SettingsSearchableItem(id: .data(11), title: strings.Settings_SaveIncomingPhotos, alternate: synonyms(strings.SettingsSearch_Synonyms_Data_SaveIncomingPhotos), icon: icon, breadcrumbs: [strings.Settings_ChatSettings], present: { context, _, present in
            present(.push, saveIncomingMediaController(context: context))
        }),
        SettingsSearchableItem(id: .data(12), title: strings.Settings_SaveEditedPhotos, alternate: synonyms(strings.SettingsSearch_Synonyms_Data_SaveEditedPhotos), icon: icon, breadcrumbs: [strings.Settings_ChatSettings], present: { context, _, present in
            presentDataSettings(context, present, .saveEditedPhotos)
        }),
        SettingsSearchableItem(id: .data(13), title: strings.ChatSettings_DownloadInBackground, alternate: synonyms(strings.SettingsSearch_Synonyms_Data_DownloadInBackground), icon: icon, breadcrumbs: [strings.Settings_ChatSettings], present: { context, _, present in
            presentDataSettings(context, present, .downloadInBackground)
        }),
        SettingsSearchableItem(id: .data(14), title: strings.ChatSettings_OpenLinksIn, alternate: synonyms(strings.SettingsSearch_Synonyms_ChatSettings_OpenLinksIn), icon: icon, breadcrumbs: [strings.Settings_ChatSettings], present: { context, _, present in
            present(.push, webBrowserSettingsController(context: context))
        }),
        SettingsSearchableItem(id: .data(15), title: strings.ChatSettings_IntentsSettings, alternate: synonyms(strings.SettingsSearch_Synonyms_ChatSettings_IntentsSettings), icon: icon, breadcrumbs: [strings.Settings_ChatSettings], present: { context, _, present in
            present(.push, intentsSettingsController(context: context))
        }),
    ]
}

private func proxySearchableItems(context: AccountContext, servers: [ProxyServerSettings]) -> [SettingsSearchableItem] {
    let icon: SettingsSearchableItemIcon = .proxy
    let strings = context.sharedContext.currentPresentationData.with { $0 }.strings
    
    let presentProxySettings: (AccountContext, (SettingsSearchableItemPresentation, ViewController?) -> Void) -> Void = { context, present in
        present(.push, proxySettingsController(context: context))
    }
    
    var items: [SettingsSearchableItem] = []
    items.append(SettingsSearchableItem(id: .proxy(0), title: strings.Settings_Proxy, alternate: synonyms(strings.SettingsSearch_Synonyms_Proxy_Title), icon: icon, breadcrumbs: [], present: { context, _, present in
            presentProxySettings(context, present)
    }))
    items.append(SettingsSearchableItem(id: .proxy(1), title: strings.SocksProxySetup_AddProxy, alternate: synonyms(strings.SettingsSearch_Synonyms_Proxy_AddProxy), icon: icon, breadcrumbs: [strings.Settings_Proxy], present: { context, _, present in
            present(.modal, proxyServerSettingsController(context: context))
    }))
    
    var hasSocksServers = false
    for server in servers {
        if case .socks5 = server.connection {
            hasSocksServers = true
            break
        }
    }
    if hasSocksServers {
        items.append(SettingsSearchableItem(id: .proxy(2), title: strings.SocksProxySetup_UseForCalls, alternate: synonyms(strings.SettingsSearch_Synonyms_Proxy_UseForCalls), icon: icon, breadcrumbs: [strings.Settings_Proxy], present: { context, _, present in
                presentProxySettings(context, present)
        }))
    }
    return items
}

private func appearanceSearchableItems(context: AccountContext) -> [SettingsSearchableItem] {
    let icon: SettingsSearchableItemIcon = .appearance
    let strings = context.sharedContext.currentPresentationData.with { $0 }.strings
    
    let presentAppearanceSettings: (AccountContext, (SettingsSearchableItemPresentation, ViewController?) -> Void, ThemeSettingsEntryTag?) -> Void = { context, present, itemTag in
        present(.push, themeSettingsController(context: context, focusOnItemTag: itemTag))
    }
    
    return [
        SettingsSearchableItem(id: .appearance(0), title: strings.Settings_Appearance, alternate: synonyms(strings.SettingsSearch_Synonyms_Appearance_Title), icon: icon, breadcrumbs: [], present: { context, _, present in
            presentAppearanceSettings(context, present, nil)
        }),
        SettingsSearchableItem(id: .appearance(1), title: strings.Appearance_TextSizeSetting, alternate: synonyms(strings.SettingsSearch_Synonyms_Appearance_TextSize), icon: icon, breadcrumbs: [strings.Settings_Appearance], present: { context, _, present in
            presentAppearanceSettings(context, present, .fontSize)
        }),
        SettingsSearchableItem(id: .appearance(2), title: strings.Settings_ChatBackground, alternate: synonyms(strings.SettingsSearch_Synonyms_Appearance_ChatBackground), icon: icon, breadcrumbs: [strings.Settings_Appearance], present: { context, _, present in
            present(.push, ThemeGridController(context: context))
        }),
        SettingsSearchableItem(id: .appearance(3), title: strings.Wallpaper_SetColor, alternate: synonyms(strings.SettingsSearch_Synonyms_Appearance_ChatBackground_SetColor), icon: icon, breadcrumbs: [strings.Settings_Appearance, strings.Settings_ChatBackground], present: { context, _, present in
            present(.push, ThemeColorsGridController(context: context))
        }),
        SettingsSearchableItem(id: .appearance(4), title: strings.Wallpaper_SetCustomBackground, alternate: synonyms(strings.SettingsSearch_Synonyms_Appearance_ChatBackground_Custom), icon: icon, breadcrumbs: [strings.Settings_Appearance, strings.Settings_ChatBackground], present: { context, _, present in
            presentCustomWallpaperPicker(context: context, present: { controller in
                present(.immediate, controller)
            })
        }),
        SettingsSearchableItem(id: .appearance(5), title: strings.Appearance_AutoNightTheme, alternate: synonyms(strings.SettingsSearch_Synonyms_Appearance_AutoNightTheme), icon: icon, breadcrumbs: [strings.Settings_Appearance], present: { context, _, present in
            present(.push, themeAutoNightSettingsController(context: context))
        }),
        SettingsSearchableItem(id: .appearance(6), title: strings.Appearance_ColorTheme, alternate: synonyms(strings.SettingsSearch_Synonyms_Appearance_ColorTheme), icon: icon, breadcrumbs: [strings.Settings_Appearance], present: { context, _, present in
            presentAppearanceSettings(context, present, .accentColor)
        }),
        SettingsSearchableItem(id: .appearance(7), title: strings.Appearance_LargeEmoji, alternate: synonyms(strings.SettingsSearch_Synonyms_Appearance_LargeEmoji), icon: icon, breadcrumbs: [strings.Settings_Appearance, strings.Appearance_Other], present: { context, _, present in
            presentAppearanceSettings(context, present, .largeEmoji)
        }),
        SettingsSearchableItem(id: .appearance(8), title: strings.Appearance_ReduceMotion, alternate: synonyms(strings.SettingsSearch_Synonyms_Appearance_Animations), icon: icon, breadcrumbs: [strings.Settings_Appearance, strings.Appearance_Other], present: { context, _, present in
            presentAppearanceSettings(context, present, .animations)
        })
    ]
}

private func languageSearchableItems(context: AccountContext, localizations: [LocalizationInfo]) -> [SettingsSearchableItem] {
    let icon: SettingsSearchableItemIcon = .language
    let strings = context.sharedContext.currentPresentationData.with { $0 }.strings
    
    let applyLocalization: (AccountContext, @escaping (SettingsSearchableItemPresentation, ViewController?) -> Void, String) -> Void = { context, present, languageCode in
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let controller = OverlayStatusController(theme: presentationData.theme, type: .loading(cancelled: nil))
        present(.immediate, controller)
        
        let _ = (context.engine.localization.downloadAndApplyLocalization(accountManager: context.sharedContext.accountManager, languageCode: languageCode)
        |> deliverOnMainQueue).start(completed: { [weak controller] in
            controller?.dismiss()
            present(.dismiss, nil)
        })
    }
    
    var items: [SettingsSearchableItem] = []
    items.append(SettingsSearchableItem(id: .language(0), title: strings.Settings_AppLanguage, alternate: synonyms(strings.SettingsSearch_Synonyms_AppLanguage), icon: icon, breadcrumbs: [], present: { context, _, present in
        present(.push, LocalizationListController(context: context))
    }))
    var index: Int32 = 1
    for localization in localizations {
        items.append(SettingsSearchableItem(id: .language(index), title: localization.localizedTitle, alternate: [localization.title], icon: icon, breadcrumbs: [strings.Settings_AppLanguage], present: { context, _, present in
            applyLocalization(context, present, localization.languageCode)
        }))
        index += 1
    }
    return items
}

func settingsSearchableItems(context: AccountContext, notificationExceptionsList: Signal<NotificationExceptionsList?, NoError>, archivedStickerPacks: Signal<[ArchivedStickerPackItem]?, NoError>, privacySettings: Signal<AccountPrivacySettings?, NoError>, hasTwoStepAuth: Signal<Bool?, NoError>, activeSessionsContext: Signal<ActiveSessionsContext?, NoError>, webSessionsContext: Signal<WebSessionsContext?, NoError>) -> Signal<[SettingsSearchableItem], NoError> {
    let watchAppInstalled = (context.watchManager?.watchAppInstalled ?? .single(false))
    |> take(1)

    let canAddAccount = activeAccountsAndPeers(context: context)
    |> take(1)
    |> map { accountsAndPeers -> Bool in
        return accountsAndPeers.1.count + 1 < maximumNumberOfAccounts
    }
    
    let notificationSettings = context.account.postbox.preferencesView(keys: [PreferencesKeys.globalNotifications])
    |> take(1)
    |> map { view -> GlobalNotificationSettingsSet in
        let viewSettings: GlobalNotificationSettingsSet
        if let settings = view.values[PreferencesKeys.globalNotifications]?.get(GlobalNotificationSettings.self) {
            viewSettings = settings.effective
        } else {
            viewSettings = GlobalNotificationSettingsSet.defaultSettings
        }
        return viewSettings
    }
    
    let archivedStickerPacks = archivedStickerPacks
    |> take(1)
    
    let privacySettings = privacySettings
    |> take(1)
    
    let proxyServers = context.sharedContext.accountManager.sharedData(keys: [SharedDataKeys.proxySettings])
    |> map { sharedData -> ProxySettings in
        if let value = sharedData.entries[SharedDataKeys.proxySettings]?.get(ProxySettings.self) {
            return value
        } else {
            return ProxySettings.defaultSettings
        }
    }
    |> map { settings -> [ProxyServerSettings] in
        return settings.servers
    }
    
    let localizationPreferencesKey: PostboxViewKey = .preferences(keys: Set([PreferencesKeys.localizationListState]))
    let localizations = combineLatest(context.account.postbox.combinedView(keys: [localizationPreferencesKey]), context.sharedContext.accountManager.sharedData(keys: [SharedDataKeys.localizationSettings]))
    |> map { view, sharedData -> [LocalizationInfo] in
        if let localizationListState = (view.views[localizationPreferencesKey] as? PreferencesView)?.values[PreferencesKeys.localizationListState]?.get(LocalizationListState.self), !localizationListState.availableOfficialLocalizations.isEmpty {
            
            var existingIds = Set<String>()
            let availableSavedLocalizations = localizationListState.availableSavedLocalizations.filter({ info in !localizationListState.availableOfficialLocalizations.contains(where: { $0.languageCode == info.languageCode }) })
            
            var activeLanguageCode: String?
            if let localizationSettings = sharedData.entries[SharedDataKeys.localizationSettings]?.get(LocalizationSettings.self) {
                activeLanguageCode = localizationSettings.primaryComponent.languageCode
            }
            
            var localizationItems: [LocalizationInfo] = []
            if !availableSavedLocalizations.isEmpty {
                for info in availableSavedLocalizations {
                    if existingIds.contains(info.languageCode) || info.languageCode == activeLanguageCode {
                        continue
                    }
                    existingIds.insert(info.languageCode)
                    localizationItems.append(info)
                }
            }
            for info in localizationListState.availableOfficialLocalizations {
                if existingIds.contains(info.languageCode) || info.languageCode == activeLanguageCode {
                    continue
                }
                existingIds.insert(info.languageCode)
                localizationItems.append(info)
            }
            
            return localizationItems
        } else {
            return []
        }
    }
    
    let activeWebSessionsContext = webSessionsContext
    |> mapToSignal { webSessionsContext -> Signal<WebSessionsContext?, NoError> in
        if let webSessionsContext = webSessionsContext {
            return webSessionsContext.state
            |> map { state -> WebSessionsContext? in
                if !state.sessions.isEmpty {
                    return webSessionsContext
                } else {
                    return nil
                }
            }
            |> distinctUntilChanged(isEqual: { lhs, rhs in
                return lhs !== rhs
            })
        } else {
            return .single(nil)
        }
    }
    
    return combineLatest(watchAppInstalled, canAddAccount, localizations, notificationSettings, notificationExceptionsList, archivedStickerPacks, proxyServers, privacySettings, hasTwoStepAuth, activeSessionsContext, activeWebSessionsContext)
    |> map { watchAppInstalled, canAddAccount, localizations, notificationSettings, notificationExceptionsList, archivedStickerPacks, proxyServers, privacySettings, hasTwoStepAuth, activeSessionsContext, activeWebSessionsContext in
        let strings = context.sharedContext.currentPresentationData.with { $0 }.strings
        
        var allItems: [SettingsSearchableItem] = []
        
        let profileItems = profileSearchableItems(context: context, canAddAccount: canAddAccount)
        allItems.append(contentsOf: profileItems)
        
        let savedMessages = SettingsSearchableItem(id: .savedMessages(0), title: strings.Settings_SavedMessages, alternate: synonyms(strings.SettingsSearch_Synonyms_SavedMessages), icon: .savedMessages, breadcrumbs: [], present: { context, _, present in
            present(.push, context.sharedContext.makeChatController(context: context, chatLocation: .peer(id: context.account.peerId), subject: nil, botStart: nil, mode: .standard(previewing: false)))
        })
        allItems.append(savedMessages)
        
        let callItems = callSearchableItems(context: context)
        allItems.append(contentsOf: callItems)
        
        let chatFolders = SettingsSearchableItem(id: .chatFolders(0), title: strings.Settings_ChatFolders, alternate: synonyms(strings.SettingsSearch_Synonyms_ChatFolders), icon: .chatFolders, breadcrumbs: [], present: { context, _, present in
            present(.push, chatListFilterPresetListController(context: context, mode: .default))
        })
        allItems.append(chatFolders)
        
        let stickerItems = stickerSearchableItems(context: context, archivedStickerPacks: archivedStickerPacks)
        allItems.append(contentsOf: stickerItems)

        let notificationItems = notificationSearchableItems(context: context, settings: notificationSettings, exceptionsList: notificationExceptionsList)
        allItems.append(contentsOf: notificationItems)
        
        let privacyItems = privacySearchableItems(context: context, privacySettings: privacySettings, activeSessionsContext: activeSessionsContext, webSessionsContext: activeWebSessionsContext)
        allItems.append(contentsOf: privacyItems)
        
        let dataItems = dataSearchableItems(context: context)
        allItems.append(contentsOf: dataItems)
        
        let proxyItems = proxySearchableItems(context: context, servers: proxyServers)
        allItems.append(contentsOf: proxyItems)
        
        let appearanceItems = appearanceSearchableItems(context: context)
        allItems.append(contentsOf: appearanceItems)
        
        let languageItems = languageSearchableItems(context: context, localizations: localizations)
        allItems.append(contentsOf: languageItems)
        
        if watchAppInstalled {
            let watch = SettingsSearchableItem(id: .watch(0), title: strings.Settings_AppleWatch, alternate: synonyms(strings.SettingsSearch_Synonyms_Watch), icon: .watch, breadcrumbs: [], present: { context, _, present in
                present(.push, watchSettingsController(context: context))
            })
            allItems.append(watch)
        }
        
        if let hasTwoStepAuth = hasTwoStepAuth, hasTwoStepAuth {
            let passport = SettingsSearchableItem(id: .passport(0), title: strings.Settings_Passport, alternate: synonyms(strings.SettingsSearch_Synonyms_Passport), icon: .passport, breadcrumbs: [], present: { context, _, present in
                present(.modal, SecureIdAuthController(context: context, mode: .list))
            })
            allItems.append(passport)
        }
        
        let support = SettingsSearchableItem(id: .support(0), title: strings.Settings_Support, alternate: synonyms(strings.SettingsSearch_Synonyms_Support), icon: .support, breadcrumbs: [], present: { context, _, present in
            let _ = (context.engine.peers.supportPeerId()
            |> deliverOnMainQueue).start(next: { peerId in
                if let peerId = peerId {
                    present(.push, context.sharedContext.makeChatController(context: context, chatLocation: .peer(id: peerId), subject: nil, botStart: nil, mode: .standard(previewing: false)))
                }
            })
        })
        allItems.append(support)
        
        let faq = SettingsSearchableItem(id: .faq(0), title: strings.Settings_FAQ, alternate: synonyms(strings.SettingsSearch_Synonyms_FAQ), icon: .faq, breadcrumbs: [], present: { context, navigationController, present in
            
            let _ = (cachedFaqInstantPage(context: context)
            |> deliverOnMainQueue).start(next: { resolvedUrl in
                context.sharedContext.openResolvedUrl(resolvedUrl, context: context, urlContext: .generic, navigationController: navigationController, forceExternal: false, openPeer: { peer, navigation in
                }, sendFile: nil, sendSticker: nil, requestMessageActionUrlAuth: nil, joinVoiceChat: nil, present: { controller, arguments in
                    present(.push, controller)
                }, dismissInput: {}, contentContext: nil)
            })
        })
        allItems.append(faq)
    
        return allItems
    }
}

private func stringTokens(_ string: String) -> [ValueBoxKey] {
    let nsString = string.folding(options: .diacriticInsensitive, locale: .current).lowercased() as NSString
    
    let flag = UInt(kCFStringTokenizerUnitWord)
    let tokenizer = CFStringTokenizerCreate(kCFAllocatorDefault, nsString, CFRangeMake(0, nsString.length), flag, CFLocaleCopyCurrent())
    var tokenType = CFStringTokenizerAdvanceToNextToken(tokenizer)
    var tokens: [ValueBoxKey] = []
    
    var addedTokens = Set<ValueBoxKey>()
    while tokenType != [] {
        let currentTokenRange = CFStringTokenizerGetCurrentTokenRange(tokenizer)
        
        if currentTokenRange.location >= 0 && currentTokenRange.length != 0 {
            let token = ValueBoxKey(length: currentTokenRange.length * 2)
            nsString.getCharacters(token.memory.assumingMemoryBound(to: unichar.self), range: NSMakeRange(currentTokenRange.location, currentTokenRange.length))
            if !addedTokens.contains(token) {
                tokens.append(token)
                addedTokens.insert(token)
            }
        }
        tokenType = CFStringTokenizerAdvanceToNextToken(tokenizer)
    }
    
    return tokens
}

private func matchStringTokens(_ tokens: [ValueBoxKey], with other: [ValueBoxKey]) -> Bool {
    if other.isEmpty {
        return false
    } else if other.count == 1 {
        let otherToken = other[0]
        for token in tokens {
            if otherToken.isPrefix(to: token) {
                return true
            }
        }
    } else {
        for otherToken in other {
            var found = false
            for token in tokens {
                if otherToken.isPrefix(to: token) {
                    found = true
                    break
                }
            }
            if !found {
                return false
            }
        }
        return true
    }
    return false
}

func searchSettingsItems(items: [SettingsSearchableItem], query: String) -> [SettingsSearchableItem] {
    let queryTokens = stringTokens(query.lowercased())
    
    var result: [SettingsSearchableItem] = []
    for item in items {
        var string = item.title
        if !item.alternate.isEmpty {
            for alternate in item.alternate {
                let trimmed = alternate.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    string += " \(trimmed)"
                }
            }
        }
        if item.breadcrumbs.count > 1 {
            string += " \(item.breadcrumbs.suffix(from: 1).joined(separator: " "))"
        }
        
        let tokens = stringTokens(string)
        if matchStringTokens(tokens, with: queryTokens) {
            result.append(item)
        }
    }
    
    return result
}
