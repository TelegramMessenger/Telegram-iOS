import Foundation
import Display
import SwiftSignalKit
import Postbox
import TelegramCore

private let maximumNumberOfAccounts = 3

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
    case passport
    case support
    case faq
}

enum SettingsSearchableItemId: Hashable {
    case profile(Int)
    case proxy(Int)
    case savedMessages(Int)
    case calls(Int)
    case stickers(Int)
    case notifications(Int)
    case privacy(Int)
    case data(Int)
    case appearance(Int)
    case language(Int)
    case watch(Int)
    case passport(Int)
    case support(Int)
    case faq(Int)
}

enum SettingsSearchableItemPresentation {
    case push
    case modal
    case immediate
}

struct SettingsSearchableItem {
    let id: SettingsSearchableItemId
    let title: String
    let alternate: [String]
    let icon: SettingsSearchableItemIcon
    let breadcrumbs: [String]
    let present: (AccountContext, NavigationController?, @escaping (SettingsSearchableItemPresentation, ViewController) -> Void) -> Void
}

private func synonyms(_ string: String?) -> [String] {
    if let string = string {
        return string.components(separatedBy: "|")
    } else {
        return []
    }
}

private func profileSearchableItems(context: AccountContext, canAddAccount: Bool) -> [SettingsSearchableItem] {
    let icon: SettingsSearchableItemIcon = .profile
    let strings = context.sharedContext.currentPresentationData.with { $0 }.strings
    
    let presentProfileSettings: (AccountContext, @escaping  (SettingsSearchableItemPresentation, ViewController) -> Void, EditSettingsEntryTag?) -> Void = { context, present, itemTag in
        let _ = openEditSettings(context: context, accountsAndPeers: activeAccountsAndPeers(context: context), focusOnItemTag: itemTag, presentController: { controller, _ in
            present(.immediate, controller)
        }, pushController: { controller in
            present(.push, controller)
        })
    }
    
    var items: [SettingsSearchableItem] = []
    items.append(SettingsSearchableItem(id: .profile(0), title: strings.EditProfile_Title, alternate: synonyms(strings.SettingsSearch_Synonyms_EditProfile_Title), icon: icon, breadcrumbs: [], present: { context, _, present in
        presentProfileSettings(context, present, nil)
    }))
    
    items.append(SettingsSearchableItem(id: .profile(1), title: strings.UserInfo_About_Placeholder, alternate: synonyms(strings.SettingsSearch_Synonyms_EditProfile_Title), icon: icon, breadcrumbs: [strings.EditProfile_Title], present: { context, _, present in
        presentProfileSettings(context, present, .bio)
    }))
    items.append(SettingsSearchableItem(id: .profile(2), title: strings.Settings_PhoneNumber, alternate: synonyms(strings.SettingsSearch_Synonyms_EditProfile_PhoneNumber), icon: icon, breadcrumbs: [strings.EditProfile_Title], present: { context, _, present in
        let _ = (context.account.postbox.transaction { transaction -> String in
            return (transaction.getPeer(context.account.peerId) as? TelegramUser)?.phone ?? ""
        }
        |> deliverOnMainQueue).start(next: { phoneNumber in
            present(.push, ChangePhoneNumberIntroController(context: context, phoneNumber: formatPhoneNumber(phoneNumber)))
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
    
    let presentCallSettings: (AccountContext, (SettingsSearchableItemPresentation, ViewController) -> Void) -> Void = { context, present in
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

private func stickerSearchableItems(context: AccountContext) -> [SettingsSearchableItem] {
    let icon: SettingsSearchableItemIcon = .stickers
    let strings = context.sharedContext.currentPresentationData.with { $0 }.strings
    
    let presentStickerSettings: (AccountContext, (SettingsSearchableItemPresentation, ViewController) -> Void, InstalledStickerPacksEntryTag?) -> Void = { context, present, itemTag in
        present(.push, installedStickerPacksController(context: context, mode: .general, archivedPacks: nil, updatedPacks: { _ in
        }, focusOnItemTag: itemTag))
    }
    
    return [
        SettingsSearchableItem(id: .stickers(0), title: strings.ChatSettings_Stickers, alternate: synonyms(strings.SettingsSearch_Synonyms_Stickers_Title), icon: icon, breadcrumbs: [], present: { context, _, present in
            presentStickerSettings(context, present, nil)
        }),
        SettingsSearchableItem(id: .stickers(1), title: strings.Stickers_SuggestStickers, alternate: synonyms(strings.SettingsSearch_Synonyms_Stickers_SuggestStickers), icon: icon, breadcrumbs: [strings.ChatSettings_Stickers], present: { context, _, present in
            presentStickerSettings(context, present, .suggestOptions)
        }),
        SettingsSearchableItem(id: .stickers(2), title: strings.StickerPacksSettings_FeaturedPacks, alternate: synonyms(strings.SettingsSearch_Synonyms_Stickers_FeaturedPacks), icon: icon, breadcrumbs: [strings.ChatSettings_Stickers], present: { context, _, present in
            present(.push, featuredStickerPacksController(context: context))
        }),
        SettingsSearchableItem(id: .stickers(3), title: strings.StickerPacksSettings_ArchivedPacks, alternate: synonyms(strings.SettingsSearch_Synonyms_Stickers_ArchivedPacks), icon: icon, breadcrumbs: [strings.ChatSettings_Stickers], present: { context, _, present in
            present(.push, archivedStickerPacksController(context: context, mode: .stickers, archived: nil, updatedPacks: { _ in
            }))
        }),
        SettingsSearchableItem(id: .stickers(4), title: strings.MaskStickerSettings_Title, alternate: synonyms(strings.SettingsSearch_Synonyms_Stickers_Masks), icon: icon, breadcrumbs: [strings.ChatSettings_Stickers], present: { context, _, present in
            present(.push, installedStickerPacksController(context: context, mode: .masks, archivedPacks: nil, updatedPacks: { _ in}))
        }),
        SettingsSearchableItem(id: .stickers(5), title: strings.StickerPacksSettings_ArchivedMasks, alternate: synonyms(strings.SettingsSearch_Synonyms_Stickers_ArchivedMasks), icon: icon, breadcrumbs: [strings.ChatSettings_Stickers, strings.MaskStickerSettings_Title], present: { context, _, present in
            present(.push, archivedStickerPacksController(context: context, mode: .masks, archived: nil, updatedPacks: { _ in
            }))
        })
    ]
}

private func notificationSearchableItems(context: AccountContext, exceptionsList: NotificationExceptionsList?) -> [SettingsSearchableItem] {
    let icon: SettingsSearchableItemIcon = .notifications
    let strings = context.sharedContext.currentPresentationData.with { $0 }.strings
    
    let presentNotificationSettings: (AccountContext, (SettingsSearchableItemPresentation, ViewController) -> Void, NotificationsAndSoundsEntryTag?) -> Void = { context, present, itemTag in
        present(.push, notificationsAndSoundsController(context: context, exceptionsList: exceptionsList, focusOnItemTag: itemTag))
    }
    
    let exceptions = { () -> (NotificationExceptionMode, NotificationExceptionMode, NotificationExceptionMode) in
        var users:[PeerId : NotificationExceptionWrapper] = [:]
        var groups: [PeerId : NotificationExceptionWrapper] = [:]
        var channels:[PeerId : NotificationExceptionWrapper] = [:]
        if let list = exceptionsList {
            for (key, value) in list.settings {
                if  let peer = list.peers[key], !peer.debugDisplayTitle.isEmpty, peer.id != context.account.peerId {
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
    
    return [
        SettingsSearchableItem(id: .notifications(0), title: strings.Settings_NotificationsAndSounds, alternate: synonyms(strings.SettingsSearch_Synonyms_Notifications_Title), icon: icon, breadcrumbs: [], present: { context, _, present in
            presentNotificationSettings(context, present, nil)
        }),
        SettingsSearchableItem(id: .notifications(1), title: strings.Notifications_MessageNotificationsAlert, alternate: synonyms(strings.SettingsSearch_Synonyms_Notifications_MessageNotificationsAlert), icon: icon, breadcrumbs: [strings.Settings_NotificationsAndSounds, strings.Notifications_MessageNotifications.capitalized], present: { context, _, present in
            presentNotificationSettings(context, present, .messageAlerts)
        }),
        SettingsSearchableItem(id: .notifications(2), title: strings.Notifications_MessageNotificationsPreview, alternate: synonyms(strings.SettingsSearch_Synonyms_Notifications_MessageNotificationsPreview), icon: icon, breadcrumbs: [strings.Settings_NotificationsAndSounds, strings.Notifications_MessageNotifications.capitalized], present: { context, _, present in
            presentNotificationSettings(context, present, .messagePreviews)
        }),
        SettingsSearchableItem(id: .notifications(3), title: strings.Notifications_MessageNotificationsSound, alternate: synonyms(strings.SettingsSearch_Synonyms_Notifications_MessageNotificationsSound), icon: icon, breadcrumbs: [strings.Settings_NotificationsAndSounds, strings.Notifications_MessageNotifications.capitalized], present: { context, _, present in
            presentNotificationSettings(context, present, nil)
        }),
        SettingsSearchableItem(id: .notifications(4), title: strings.Notifications_MessageNotificationsExceptions, alternate: synonyms(strings.SettingsSearch_Synonyms_Notifications_MessageNotificationsExceptions), icon: icon, breadcrumbs: [strings.Settings_NotificationsAndSounds, strings.Notifications_MessageNotifications.capitalized], present: { context, _, present in
            present(.push, NotificationExceptionsController(context: context, mode: exceptions().0, updatedMode: { _ in}))
        }),
        SettingsSearchableItem(id: .notifications(5), title: strings.Notifications_GroupNotificationsAlert, alternate: synonyms(strings.SettingsSearch_Synonyms_Notifications_GroupNotificationsAlert), icon: icon, breadcrumbs: [strings.Settings_NotificationsAndSounds, strings.Notifications_GroupNotifications.capitalized], present: { context, _, present in
            presentNotificationSettings(context, present, .groupAlerts)
        }),
        SettingsSearchableItem(id: .notifications(6), title: strings.Notifications_GroupNotificationsPreview, alternate: synonyms(strings.SettingsSearch_Synonyms_Notifications_GroupNotificationsPreview), icon: icon, breadcrumbs: [strings.Settings_NotificationsAndSounds, strings.Notifications_GroupNotifications.capitalized], present: { context, _, present in
            presentNotificationSettings(context, present, .groupPreviews)
        }),
        SettingsSearchableItem(id: .notifications(7), title: strings.Notifications_GroupNotificationsSound, alternate: synonyms(strings.SettingsSearch_Synonyms_Notifications_GroupNotificationsSound), icon: icon, breadcrumbs: [strings.Settings_NotificationsAndSounds, strings.Notifications_GroupNotifications.capitalized], present: { context, _, present in
            presentNotificationSettings(context, present, nil)
        }),
        SettingsSearchableItem(id: .notifications(8), title: strings.Notifications_GroupNotificationsExceptions, alternate: synonyms(strings.SettingsSearch_Synonyms_Notifications_GroupNotificationsExceptions), icon: icon, breadcrumbs: [strings.Settings_NotificationsAndSounds, strings.Notifications_GroupNotifications.capitalized], present: { context, _, present in
            present(.push, NotificationExceptionsController(context: context, mode: exceptions().1, updatedMode: { _ in}))
        }),
        SettingsSearchableItem(id: .notifications(9), title: strings.Notifications_ChannelNotificationsAlert, alternate: synonyms(strings.SettingsSearch_Synonyms_Notifications_ChannelNotificationsAlert), icon: icon, breadcrumbs: [strings.Settings_NotificationsAndSounds, strings.Notifications_ChannelNotifications.capitalized], present: { context, _, present in
            presentNotificationSettings(context, present, .channelAlerts)
        }),
        SettingsSearchableItem(id: .notifications(10), title: strings.Notifications_ChannelNotificationsPreview, alternate: synonyms(strings.SettingsSearch_Synonyms_Notifications_ChannelNotificationsPreview), icon: icon, breadcrumbs: [strings.Settings_NotificationsAndSounds, strings.Notifications_ChannelNotifications.capitalized], present: { context, _, present in
            presentNotificationSettings(context, present, .channelPreviews)
        }),
        SettingsSearchableItem(id: .notifications(11), title: strings.Notifications_ChannelNotificationsSound, alternate: synonyms(strings.SettingsSearch_Synonyms_Notifications_ChannelNotificationsSound), icon: icon, breadcrumbs: [strings.Settings_NotificationsAndSounds, strings.Notifications_ChannelNotifications.capitalized], present: { context, _, present in
            presentNotificationSettings(context, present, nil)
        }),
        SettingsSearchableItem(id: .notifications(12), title: strings.Notifications_MessageNotificationsExceptions, alternate: synonyms(strings.SettingsSearch_Synonyms_Notifications_ChannelNotificationsExceptions), icon: icon, breadcrumbs: [strings.Settings_NotificationsAndSounds, strings.Notifications_ChannelNotifications.capitalized], present: { context, _, present in
            present(.push, NotificationExceptionsController(context: context, mode: exceptions().2, updatedMode: { _ in}))
        }),
        SettingsSearchableItem(id: .notifications(13), title: strings.Notifications_InAppNotificationsSounds, alternate: synonyms(strings.SettingsSearch_Synonyms_Notifications_InAppNotificationsSound), icon: icon, breadcrumbs: [strings.Settings_NotificationsAndSounds, strings.Notifications_InAppNotifications.capitalized], present: { context, _, present in
            presentNotificationSettings(context, present, .inAppSounds)
        }),
        SettingsSearchableItem(id: .notifications(14), title: strings.Notifications_InAppNotificationsVibrate, alternate: synonyms(strings.SettingsSearch_Synonyms_Notifications_InAppNotificationsVibrate), icon: icon, breadcrumbs: [strings.Settings_NotificationsAndSounds, strings.Notifications_InAppNotifications.capitalized], present: { context, _, present in
            presentNotificationSettings(context, present, .inAppVibrate)
        }),
        SettingsSearchableItem(id: .notifications(15), title: strings.Notifications_InAppNotificationsPreview, alternate: synonyms(strings.SettingsSearch_Synonyms_Notifications_InAppNotificationsPreview), icon: icon, breadcrumbs: [strings.Settings_NotificationsAndSounds, strings.Notifications_InAppNotifications.capitalized], present: { context, _, present in
            presentNotificationSettings(context, present, .inAppPreviews)
        }),
        SettingsSearchableItem(id: .notifications(16), title: strings.Notifications_DisplayNamesOnLockScreen, alternate: synonyms(strings.SettingsSearch_Synonyms_Notifications_DisplayNamesOnLockScreen), icon: icon, breadcrumbs: [strings.Settings_NotificationsAndSounds], present: { context, _, present in
            presentNotificationSettings(context, present, .displayNamesOnLockscreen)
        }),
        SettingsSearchableItem(id: .notifications(17), title: strings.Notifications_Badge_IncludeMutedChats, alternate: synonyms(strings.SettingsSearch_Synonyms_Notifications_BadgeIncludeMutedChats), icon: icon, breadcrumbs: [strings.Settings_NotificationsAndSounds, strings.Notifications_Badge.capitalized], present: { context, _, present in
            presentNotificationSettings(context, present, .unreadCountStyle)
        }),
        SettingsSearchableItem(id: .notifications(18), title: strings.Notifications_Badge_IncludePublicGroups, alternate: synonyms(strings.SettingsSearch_Synonyms_Notifications_BadgeIncludeMutedPublicGroups), icon: icon, breadcrumbs: [strings.Settings_NotificationsAndSounds, strings.Notifications_Badge.capitalized], present: { context, _, present in
            presentNotificationSettings(context, present, .includePublicGroups)
        }),
        SettingsSearchableItem(id: .notifications(19), title: strings.Notifications_Badge_IncludeChannels, alternate: synonyms(strings.SettingsSearch_Synonyms_Notifications_BadgeIncludeMutedChannels), icon: icon, breadcrumbs: [strings.Settings_NotificationsAndSounds, strings.Notifications_Badge.capitalized], present: { context, _, present in
            presentNotificationSettings(context, present, .includeChannels)
        }),
        SettingsSearchableItem(id: .notifications(20), title: strings.Notifications_Badge_CountUnreadMessages, alternate: synonyms(strings.SettingsSearch_Synonyms_Notifications_BadgeCountUnreadMessages), icon: icon, breadcrumbs: [strings.Settings_NotificationsAndSounds, strings.Notifications_Badge.capitalized], present: { context, _, present in
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

private func privacySearchableItems(context: AccountContext) -> [SettingsSearchableItem] {
    let icon: SettingsSearchableItemIcon = .privacy
    let strings = context.sharedContext.currentPresentationData.with { $0 }.strings
    
    let presentPrivacySettings: (AccountContext, (SettingsSearchableItemPresentation, ViewController) -> Void) -> Void = { context, present in
        present(.push, privacyAndSecurityController(context: context))
    }
    
    let presentSelectivePrivacySettings: (AccountContext, SelectivePrivacySettingsKind, @escaping (SettingsSearchableItemPresentation, ViewController) -> Void) -> Void = { context, kind, present in
        let privacySignal = requestAccountPrivacySettings(account: context.account)
        let callsSignal: Signal<(VoiceCallSettings, VoipConfiguration)?, NoError>
        if case .voiceCalls = kind {
            callsSignal = combineLatest(context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.voiceCallSettings]), context.account.postbox.preferencesView(keys: [PreferencesKeys.voipConfiguration]))
            |> take(1)
            |> map { sharedData, view -> (VoiceCallSettings, VoipConfiguration)? in
                let voiceCallSettings: VoiceCallSettings = sharedData.entries[ApplicationSpecificSharedDataKeys.voiceCallSettings] as? VoiceCallSettings ?? .defaultSettings
                let voipConfiguration = view.values[PreferencesKeys.voipConfiguration] as? VoipConfiguration ?? .defaultValue
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
                    current = info.voiceCalls
                case .forwards:
                    current = info.voiceCalls
            }

            present(.push, selectivePrivacySettingsController(context: context, kind: kind, current: current, callSettings: callSettings != nil ? (info.voiceCallsP2P, callSettings!.0) : nil, voipConfiguration: callSettings?.1, callIntegrationAvailable: CallKitIntegration.isAvailable, updated: { updated, updatedCallSettings in
                    if let (_, updatedCallSettings) = updatedCallSettings  {
                        let _ = updateVoiceCallSettingsSettingsInteractively(accountManager: context.sharedContext.accountManager, { _ in
                            return updatedCallSettings
                        }).start()
                    }
                }))
        })
    }
    
    let presentDataPrivacySettings: (AccountContext, (SettingsSearchableItemPresentation, ViewController) -> Void) -> Void = { context, present in
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
    
    return [
        SettingsSearchableItem(id: .privacy(0), title: strings.Settings_PrivacySettings, alternate: synonyms(strings.SettingsSearch_Synonyms_Privacy_Title), icon: icon, breadcrumbs: [], present: { context, _, present in
            presentPrivacySettings(context, present)
        }),
        SettingsSearchableItem(id: .privacy(1), title: strings.Settings_BlockedUsers, alternate: synonyms(strings.SettingsSearch_Synonyms_Privacy_BlockedUsers), icon: icon, breadcrumbs: [strings.Settings_PrivacySettings], present: { context, _, present in
            present(.push, blockedPeersController(context: context))
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
            let _ = passcodeOptionsAccessController(context: context, completion: { animated in
                let controller = passcodeOptionsController(context: context)
                if animated {
                    present(.push, controller)
                } else {
                    present(.push, controller)
                }
            }).start(next: { controller in
                if let controller = controller {
                    present(.modal, controller)
                }
            })
        }),
        SettingsSearchableItem(id: .privacy(8), title: strings.PrivacySettings_TwoStepAuth, alternate: synonyms(strings.SettingsSearch_Synonyms_Privacy_TwoStepAuth), icon: icon, breadcrumbs: [strings.Settings_PrivacySettings], present: { context, _, present in
            present(.modal, twoStepVerificationUnlockSettingsController(context: context, mode: .access))
        }),
        SettingsSearchableItem(id: .privacy(9), title: strings.PrivacySettings_AuthSessions, alternate: synonyms(strings.SettingsSearch_Synonyms_Privacy_AuthSessions), icon: icon, breadcrumbs: [strings.Settings_PrivacySettings], present: { context, _, present in
            present(.push, recentSessionsController(context: context))
        }),
        SettingsSearchableItem(id: .privacy(10), title: strings.PrivacySettings_DeleteAccountTitle.capitalized, alternate: synonyms(strings.SettingsSearch_Synonyms_Privacy_DeleteAccountIfAwayFor), icon: icon, breadcrumbs: [strings.Settings_PrivacySettings], present: { context, _, present in
            presentPrivacySettings(context, present)
        }),
        SettingsSearchableItem(id: .privacy(11), title: strings.PrivacySettings_DataSettings, alternate: synonyms(strings.SettingsSearch_Synonyms_Privacy_Data_Title), icon: icon, breadcrumbs: [strings.Settings_PrivacySettings], present: { context, _, present in
            presentDataPrivacySettings(context, present)
        }),
        
        SettingsSearchableItem(id: .privacy(12), title: strings.Privacy_ContactsReset, alternate: synonyms(strings.SettingsSearch_Synonyms_Privacy_Data_ContactsReset), icon: icon, breadcrumbs: [strings.Settings_PrivacySettings, strings.PrivacySettings_DataSettings], present: { context, _, present in
            presentDataPrivacySettings(context, present)
        }),
        SettingsSearchableItem(id: .privacy(13), title: strings.Privacy_ContactsSync, alternate: synonyms(strings.SettingsSearch_Synonyms_Privacy_Data_ContactsSync), icon: icon, breadcrumbs: [strings.Settings_PrivacySettings, strings.PrivacySettings_DataSettings], present: { context, _, present in
            presentDataPrivacySettings(context, present)
        }),
        SettingsSearchableItem(id: .privacy(14), title: strings.Privacy_TopPeers, alternate: synonyms(strings.SettingsSearch_Synonyms_Privacy_Data_TopPeers), icon: icon, breadcrumbs: [strings.Settings_PrivacySettings, strings.PrivacySettings_DataSettings], present: { context, _, present in
            presentDataPrivacySettings(context, present)
        }),
        SettingsSearchableItem(id: .privacy(15), title: strings.Privacy_DeleteDrafts, alternate: synonyms(strings.SettingsSearch_Synonyms_Privacy_Data_DeleteDrafts), icon: icon, breadcrumbs: [strings.Settings_PrivacySettings, strings.PrivacySettings_DataSettings], present: { context, _, present in
            presentDataPrivacySettings(context, present)
        }),
        SettingsSearchableItem(id: .privacy(16), title: strings.Privacy_PaymentsClearInfo, alternate: synonyms(strings.SettingsSearch_Synonyms_Privacy_Data_ClearPaymentsInfo), icon: icon, breadcrumbs: [strings.Settings_PrivacySettings, strings.PrivacySettings_DataSettings], present: { context, _, present in
            presentDataPrivacySettings(context, present)
        }),
        SettingsSearchableItem(id: .privacy(17), title: strings.Privacy_SecretChatsLinkPreviews, alternate: synonyms(strings.SettingsSearch_Synonyms_Privacy_Data_SecretChatLinkPreview), icon: icon, breadcrumbs: [strings.Settings_PrivacySettings, strings.PrivacySettings_DataSettings, strings.Privacy_SecretChatsTitle], present: { context, _, present in
            presentDataPrivacySettings(context, present)
        })
    ]
}

private func dataSearchableItems(context: AccountContext) -> [SettingsSearchableItem] {
    let icon: SettingsSearchableItemIcon = .data
    let strings = context.sharedContext.currentPresentationData.with { $0 }.strings
    
    let presentDataSettings: (AccountContext, (SettingsSearchableItemPresentation, ViewController) -> Void, DataAndStorageEntryTag?) -> Void = { context, present, itemTag in
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
        SettingsSearchableItem(id: .data(5), title: strings.ChatSettings_AutoDownloadUsingCellular, alternate: synonyms(strings.SettingsSearch_Synonyms_Data_AutoDownloadUsingCellular), icon: icon, breadcrumbs: [strings.Settings_ChatSettings, strings.ChatSettings_AutoDownloadTitle.capitalized], present: { context, _, present in
            present(.push, autodownloadMediaConnectionTypeController(context: context, connectionType: .cellular))
        }),
        SettingsSearchableItem(id: .data(6), title: strings.ChatSettings_AutoDownloadUsingWiFi, alternate: synonyms(strings.SettingsSearch_Synonyms_Data_AutoDownloadUsingWifi), icon: icon, breadcrumbs: [strings.Settings_ChatSettings, strings.ChatSettings_AutoDownloadTitle.capitalized], present: { context, _, present in
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
        })
    ]
}

private func proxySearchableItems(context: AccountContext) -> [SettingsSearchableItem] {
    let icon: SettingsSearchableItemIcon = .proxy
    let strings = context.sharedContext.currentPresentationData.with { $0 }.strings
    
    let presentProxySettings: (AccountContext, (SettingsSearchableItemPresentation, ViewController) -> Void) -> Void = { context, present in
        present(.push, proxySettingsController(context: context))
    }
    
    return [
        SettingsSearchableItem(id: .proxy(0), title: strings.Settings_Proxy, alternate: synonyms(strings.SettingsSearch_Synonyms_Proxy_Title), icon: icon, breadcrumbs: [], present: { context, _, present in
            presentProxySettings(context, present)
        }),
        SettingsSearchableItem(id: .proxy(1), title: strings.SocksProxySetup_AddProxy, alternate: synonyms(strings.SettingsSearch_Synonyms_Proxy_AddProxy), icon: icon, breadcrumbs: [strings.Settings_Proxy], present: { context, _, present in
            present(.modal, proxyServerSettingsController(context: context))
        }),
        SettingsSearchableItem(id: .proxy(2), title: strings.SocksProxySetup_UseForCalls, alternate: synonyms(strings.SettingsSearch_Synonyms_Proxy_UseForCalls), icon: icon, breadcrumbs: [strings.Settings_Proxy], present: { context, _, present in
            presentProxySettings(context, present)
        })
    ]
}

private func appearanceSearchableItems(context: AccountContext) -> [SettingsSearchableItem] {
    let icon: SettingsSearchableItemIcon = .appearance
    let strings = context.sharedContext.currentPresentationData.with { $0 }.strings
    
    let presentAppearanceSettings: (AccountContext, (SettingsSearchableItemPresentation, ViewController) -> Void, ThemeSettingsEntryTag?) -> Void = { context, present, itemTag in
        present(.push, themeSettingsController(context: context, focusOnItemTag: itemTag))
    }
    
    return [
        SettingsSearchableItem(id: .appearance(0), title: strings.Settings_Appearance, alternate: synonyms(strings.SettingsSearch_Synonyms_Appearance_Title), icon: icon, breadcrumbs: [], present: { context, _, present in
            presentAppearanceSettings(context, present, nil)
        }),
        SettingsSearchableItem(id: .appearance(1), title: strings.Appearance_TextSize.capitalized, alternate: synonyms(strings.SettingsSearch_Synonyms_Appearance_TextSize), icon: icon, breadcrumbs: [strings.Settings_Appearance], present: { context, _, present in
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
        SettingsSearchableItem(id: .appearance(6), title: strings.Appearance_ColorTheme.capitalized, alternate: synonyms(strings.SettingsSearch_Synonyms_Appearance_ColorTheme), icon: icon, breadcrumbs: [strings.Settings_Appearance], present: { context, _, present in
            presentAppearanceSettings(context, present, .accentColor)
        }),
        SettingsSearchableItem(id: .appearance(7), title: strings.Appearance_ReduceMotion, alternate: synonyms(strings.SettingsSearch_Synonyms_Appearance_Animations), icon: icon, breadcrumbs: [strings.Settings_Appearance, strings.Appearance_Animations.capitalized], present: { context, _, present in
            presentAppearanceSettings(context, present, .animations)
        }),
    ]
}

func settingsSearchableItems(context: AccountContext, exceptionsList: Signal<NotificationExceptionsList?, NoError>) -> Signal<[SettingsSearchableItem], NoError> {
    let watchAppInstalled = (context.watchManager?.watchAppInstalled ?? .single(false))
    |> take(1)
    let canAddAccount = activeAccountsAndPeers(context: context)
    |> take(1)
    |> map { accountsAndPeers -> Bool in
        return accountsAndPeers.1.count + 1 < maximumNumberOfAccounts
    }
    return combineLatest(watchAppInstalled, canAddAccount, exceptionsList)
    |> map { watchAppInstalled, canAddAccount, exceptionsList in
        let strings = context.sharedContext.currentPresentationData.with { $0 }.strings
        
        var allItems: [SettingsSearchableItem] = []
        
        let profileItems = profileSearchableItems(context: context, canAddAccount: canAddAccount)
        allItems.append(contentsOf: profileItems)
        
        let savedMessages = SettingsSearchableItem(id: .savedMessages(0), title: strings.Settings_SavedMessages, alternate: synonyms(strings.SettingsSearch_Synonyms_SavedMessages), icon: .savedMessages, breadcrumbs: [], present: { context, _, present in
            present(.push, ChatController(context: context, chatLocation: .peer(context.account.peerId)))
        })
        allItems.append(savedMessages)
        
        let callItems = callSearchableItems(context: context)
        allItems.append(contentsOf: callItems)
        
        let stickerItems = stickerSearchableItems(context: context)
        allItems.append(contentsOf: stickerItems)

        let notificationItems = notificationSearchableItems(context: context, exceptionsList: exceptionsList)
        allItems.append(contentsOf: notificationItems)
        
        let privacyItems = privacySearchableItems(context: context)
        allItems.append(contentsOf: privacyItems)
        
        let dataItems = dataSearchableItems(context: context)
        allItems.append(contentsOf: dataItems)
        
        let proxyItems = proxySearchableItems(context: context)
        allItems.append(contentsOf: proxyItems)
        
        let appearanceItems = appearanceSearchableItems(context: context)
        allItems.append(contentsOf: appearanceItems)
        
        let language = SettingsSearchableItem(id: .language(0), title: strings.Settings_AppLanguage, alternate: synonyms(strings.SettingsSearch_Synonyms_AppLanguage), icon: .language, breadcrumbs: [], present: { context, _, present in
            present(.push, LocalizationListController(context: context))
        })
        allItems.append(language)
        
        if watchAppInstalled {
            let watch = SettingsSearchableItem(id: .watch(0), title: strings.Settings_AppleWatch, alternate: synonyms(strings.SettingsSearch_Synonyms_Watch), icon: .watch, breadcrumbs: [], present: { context, _, present in
                present(.push, watchSettingsController(context: context))
            })
            allItems.append(watch)
        }
        
        let passport = SettingsSearchableItem(id: .passport(0), title: strings.Settings_Passport, alternate: synonyms(strings.SettingsSearch_Synonyms_Passport), icon: .passport, breadcrumbs: [], present: { context, _, present in
            present(.modal, SecureIdAuthController(context: context, mode: .list))
        })
        allItems.append(passport)
        
        let support = SettingsSearchableItem(id: .support(0), title: strings.Settings_Support, alternate: synonyms(strings.SettingsSearch_Synonyms_Support), icon: .support, breadcrumbs: [], present: { context, _, present in
            let _ = (supportPeerId(account: context.account)
            |> deliverOnMainQueue).start(next: { peerId in
                if let peerId = peerId {
                    present(.push, ChatController(context: context, chatLocation: .peer(peerId)))
                }
            })
        })
        allItems.append(support)
        
        let faq = SettingsSearchableItem(id: .faq(0), title: strings.Settings_FAQ, alternate: synonyms(strings.SettingsSearch_Synonyms_FAQ), icon: .faq, breadcrumbs: [], present: { context, navigationController, present in
            
            let _ = (cachedFaqInstantPage(context: context)
            |> deliverOnMainQueue).start(next: { resolvedUrl in
                openResolvedUrl(resolvedUrl, context: context, navigationController: navigationController, openPeer: { peer, navigation in
                }, present: { controller, arguments in
                    present(.push, controller)
                }, dismissInput: {})
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
            string += " \(item.alternate.joined(separator: " "))"
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
