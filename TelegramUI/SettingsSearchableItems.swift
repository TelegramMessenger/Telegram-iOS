import Foundation
import Display
import SwiftSignalKit
import Postbox
import TelegramCore

enum SettingsSearchableItemIcon {
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
    let present: (AccountContext, @escaping (SettingsSearchableItemPresentation, ViewController) -> Void) -> Void
}

private func callSearchableItems(context: AccountContext) -> [SettingsSearchableItem] {
    let icon: SettingsSearchableItemIcon = .calls
    let strings = context.sharedContext.currentPresentationData.with { $0 }.strings
    
    let presentCallSettings: (AccountContext, (SettingsSearchableItemPresentation, ViewController) -> Void) -> Void = { context, present in
        present(.push, CallListController(context: context, mode: .navigation))
    }
    
    return [
        SettingsSearchableItem(id: .calls(0), title: strings.CallSettings_RecentCalls, alternate: [], icon: icon, breadcrumbs: [], present: { context, present in
            presentCallSettings(context, present)
        }),
        SettingsSearchableItem(id: .calls(1), title: strings.CallSettings_TabIcon, alternate: [], icon: icon, breadcrumbs: [strings.CallSettings_RecentCalls], present: { context, present in
            presentCallSettings(context, present)
        })
    ]
}

private func stickerSearchableItems(context: AccountContext) -> [SettingsSearchableItem] {
    let icon: SettingsSearchableItemIcon = .stickers
    let strings = context.sharedContext.currentPresentationData.with { $0 }.strings
    
    let presentStickerSettings: (AccountContext, (SettingsSearchableItemPresentation, ViewController) -> Void) -> Void = { context, present in
        present(.push, installedStickerPacksController(context: context, mode: .general, archivedPacks: nil, updatedPacks: { _ in
        }))
    }
    
    return [
        SettingsSearchableItem(id: .stickers(0), title: strings.ChatSettings_Stickers, alternate: [], icon: icon, breadcrumbs: [], present: { context, present in
            presentStickerSettings(context, present)
        }),
        SettingsSearchableItem(id: .stickers(1), title: strings.Stickers_SuggestStickers, alternate: [], icon: icon, breadcrumbs: [strings.ChatSettings_Stickers], present: { context, present in
            presentStickerSettings(context, present)
        }),
        SettingsSearchableItem(id: .stickers(2), title: strings.StickerPacksSettings_FeaturedPacks, alternate: [], icon: icon, breadcrumbs: [strings.ChatSettings_Stickers], present: { context, present in
            present(.push, featuredStickerPacksController(context: context))
        }),
        SettingsSearchableItem(id: .stickers(3), title: strings.StickerPacksSettings_ArchivedPacks, alternate: [], icon: icon, breadcrumbs: [strings.ChatSettings_Stickers], present: { context, present in
            present(.push, archivedStickerPacksController(context: context, mode: .stickers, archived: nil, updatedPacks: { _ in
            }))
        }),
        SettingsSearchableItem(id: .stickers(4), title: strings.MaskStickerSettings_Title, alternate: [], icon: icon, breadcrumbs: [strings.ChatSettings_Stickers], present: { context, present in
            present(.push, installedStickerPacksController(context: context, mode: .masks, archivedPacks: nil, updatedPacks: { _ in}))
        }),
        SettingsSearchableItem(id: .stickers(5), title: strings.StickerPacksSettings_ArchivedMasks, alternate: [], icon: icon, breadcrumbs: [strings.ChatSettings_Stickers, strings.MaskStickerSettings_Title], present: { context, present in
            present(.push, archivedStickerPacksController(context: context, mode: .masks, archived: nil, updatedPacks: { _ in
            }))
        })
    ]
}

private func notificationSearchableItems(context: AccountContext, notifyExceptions: Signal<NotificationExceptionsList?, NoError>) -> [SettingsSearchableItem] {
    let icon: SettingsSearchableItemIcon = .notifications
    let strings = context.sharedContext.currentPresentationData.with { $0 }.strings
    
    let presentNotificationSettings: (AccountContext, (SettingsSearchableItemPresentation, ViewController) -> Void) -> Void = { context, present in
        present(.push, notificationsAndSoundsController(context: context, exceptionsList: nil))
    }
    
    return [
        SettingsSearchableItem(id: .notifications(0), title: strings.Settings_NotificationsAndSounds, alternate: [], icon: icon, breadcrumbs: [], present: { context, present in
            presentNotificationSettings(context, present)
        }),
        SettingsSearchableItem(id: .notifications(1), title: strings.Notifications_MessageNotificationsAlert, alternate: [], icon: icon, breadcrumbs: [strings.Settings_NotificationsAndSounds, strings.Notifications_MessageNotifications.capitalized], present: { context, present in
            presentNotificationSettings(context, present)
        }),
        SettingsSearchableItem(id: .notifications(2), title: strings.Notifications_MessageNotificationsPreview, alternate: [], icon: icon, breadcrumbs: [strings.Settings_NotificationsAndSounds, strings.Notifications_MessageNotifications.capitalized], present: { context, present in
            presentNotificationSettings(context, present)
        }),
        SettingsSearchableItem(id: .notifications(3), title: strings.Notifications_MessageNotificationsSound, alternate: [], icon: icon, breadcrumbs: [strings.Settings_NotificationsAndSounds, strings.Notifications_MessageNotifications.capitalized], present: { context, present in
            presentNotificationSettings(context, present)
        }),
        SettingsSearchableItem(id: .notifications(4), title: strings.Notifications_GroupNotificationsAlert, alternate: [], icon: icon, breadcrumbs: [strings.Settings_NotificationsAndSounds, strings.Notifications_GroupNotifications.capitalized], present: { context, present in
            presentNotificationSettings(context, present)
        }),
        SettingsSearchableItem(id: .notifications(5), title: strings.Notifications_GroupNotificationsPreview, alternate: [], icon: icon, breadcrumbs: [strings.Settings_NotificationsAndSounds, strings.Notifications_GroupNotifications.capitalized], present: { context, present in
            presentNotificationSettings(context, present)
        }),
        SettingsSearchableItem(id: .notifications(6), title: strings.Notifications_GroupNotificationsSound, alternate: [], icon: icon, breadcrumbs: [strings.Settings_NotificationsAndSounds, strings.Notifications_GroupNotifications.capitalized], present: { context, present in
            presentNotificationSettings(context, present)
        }),
        SettingsSearchableItem(id: .notifications(7), title: strings.Notifications_ChannelNotificationsAlert, alternate: [], icon: icon, breadcrumbs: [strings.Settings_NotificationsAndSounds, strings.Notifications_ChannelNotifications.capitalized], present: { context, present in
            presentNotificationSettings(context, present)
        }),
        SettingsSearchableItem(id: .notifications(8), title: strings.Notifications_ChannelNotificationsPreview, alternate: [], icon: icon, breadcrumbs: [strings.Settings_NotificationsAndSounds, strings.Notifications_ChannelNotifications.capitalized], present: { context, present in
            presentNotificationSettings(context, present)
        }),
        SettingsSearchableItem(id: .notifications(9), title: strings.Notifications_ChannelNotificationsSound, alternate: [], icon: icon, breadcrumbs: [strings.Settings_NotificationsAndSounds, strings.Notifications_ChannelNotifications.capitalized], present: { context, present in
            presentNotificationSettings(context, present)
        }),
        SettingsSearchableItem(id: .notifications(10), title: strings.Notifications_InAppNotificationsSounds, alternate: [], icon: icon, breadcrumbs: [strings.Settings_NotificationsAndSounds, strings.Notifications_InAppNotifications.capitalized], present: { context, present in
            presentNotificationSettings(context, present)
        }),
        SettingsSearchableItem(id: .notifications(11), title: strings.Notifications_InAppNotificationsVibrate, alternate: [], icon: icon, breadcrumbs: [strings.Settings_NotificationsAndSounds, strings.Notifications_InAppNotifications.capitalized], present: { context, present in
            presentNotificationSettings(context, present)
        }),
        SettingsSearchableItem(id: .notifications(12), title: strings.Notifications_InAppNotificationsPreview, alternate: [], icon: icon, breadcrumbs: [strings.Settings_NotificationsAndSounds, strings.Notifications_InAppNotifications.capitalized], present: { context, present in
            presentNotificationSettings(context, present)
        }),
        SettingsSearchableItem(id: .notifications(13), title: strings.Notifications_DisplayNamesOnLockScreen, alternate: [], icon: icon, breadcrumbs: [strings.Settings_NotificationsAndSounds], present: { context, present in
            presentNotificationSettings(context, present)
        }),
        SettingsSearchableItem(id: .notifications(14), title: strings.Notifications_Badge_IncludeMutedChats, alternate: [], icon: icon, breadcrumbs: [strings.Settings_NotificationsAndSounds, strings.Notifications_Badge.capitalized], present: { context, present in
            presentNotificationSettings(context, present)
        }),
        SettingsSearchableItem(id: .notifications(15), title: strings.Notifications_Badge_IncludePublicGroups, alternate: [], icon: icon, breadcrumbs: [strings.Settings_NotificationsAndSounds, strings.Notifications_Badge.capitalized], present: { context, present in
            presentNotificationSettings(context, present)
        }),
        SettingsSearchableItem(id: .notifications(16), title: strings.Notifications_Badge_IncludeChannels, alternate: [], icon: icon, breadcrumbs: [strings.Settings_NotificationsAndSounds, strings.Notifications_Badge.capitalized], present: { context, present in
            presentNotificationSettings(context, present)
        }),
        SettingsSearchableItem(id: .notifications(17), title: strings.Notifications_Badge_CountUnreadMessages, alternate: [], icon: icon, breadcrumbs: [strings.Settings_NotificationsAndSounds, strings.Notifications_Badge.capitalized], present: { context, present in
            presentNotificationSettings(context, present)
        }),
        SettingsSearchableItem(id: .notifications(18), title: strings.NotificationSettings_ContactJoined, alternate: [], icon: icon, breadcrumbs: [strings.Settings_NotificationsAndSounds], present: { context, present in
            presentNotificationSettings(context, present)
        }),
        SettingsSearchableItem(id: .notifications(19), title: strings.Notifications_ResetAllNotifications, alternate: [], icon: icon, breadcrumbs: [strings.Settings_NotificationsAndSounds], present: { context, present in
            presentNotificationSettings(context, present)
        })
    ]
}

private func privacySearchableItems(context: AccountContext) -> [SettingsSearchableItem] {
    let icon: SettingsSearchableItemIcon = .privacy
    let strings = context.sharedContext.currentPresentationData.with { $0 }.strings
    
    let presentPrivacySettings: (AccountContext, (SettingsSearchableItemPresentation, ViewController) -> Void) -> Void = { context, present in
        present(.push, privacyAndSecurityController(context: context, initialSettings: .single(nil) |> then(requestAccountPrivacySettings(account: context.account) |> map(Optional.init))))
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
//            if let info = info {
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
                    if let (updatedCallsPrivacy, updatedCallSettings) = updatedCallSettings  {
                        let _ = updateVoiceCallSettingsSettingsInteractively(accountManager: context.sharedContext.accountManager, { _ in
                            return updatedCallSettings
                        }).start()
                        
//                        let applySettings: Signal<Void, NoError> = privacySettingsPromise.get()
//                        |> filter { $0 != nil }
//                        |> take(1)
//                        |> deliverOnMainQueue
//                        |> mapToSignal { value -> Signal<Void, NoError> in
//                            if let value = value {
//                                privacySettingsPromise.set(.single(AccountPrivacySettings(presence: value.presence, groupInvitations: value.groupInvitations, voiceCalls: updated, voiceCallsP2P: updatedCallsPrivacy, accountRemovalTimeout: value.accountRemovalTimeout)))
//                            }
//                            return .complete()
//                        }
//                        let _ = applySettings.start()
                    }
                }))
//            }
        })
    }
    
    let passcodeTitle: String
    if let biometricAuthentication = LocalAuth.biometricAuthentication {
        switch biometricAuthentication {
            case .touchId:
                passcodeTitle = strings.PrivacySettings_PasscodeAndTouchId
            case .faceId:
                passcodeTitle = strings.PrivacySettings_PasscodeAndFaceId
        }
    } else {
        passcodeTitle = strings.PrivacySettings_Passcode
    }
    
    return [
        SettingsSearchableItem(id: .privacy(0), title: strings.Settings_PrivacySettings, alternate: [], icon: icon, breadcrumbs: [], present: { context, present in
            presentPrivacySettings(context, present)
        }),
        SettingsSearchableItem(id: .privacy(1), title: strings.Settings_BlockedUsers, alternate: [], icon: icon, breadcrumbs: [strings.Settings_PrivacySettings], present: { context, present in
            present(.push, blockedPeersController(context: context))
        }),
        SettingsSearchableItem(id: .privacy(2), title: strings.PrivacySettings_LastSeen, alternate: [], icon: icon, breadcrumbs: [strings.Settings_PrivacySettings], present: { context, present in
            presentSelectivePrivacySettings(context, .presence, present)
        }),
        SettingsSearchableItem(id: .privacy(3), title: strings.Privacy_ProfilePhoto, alternate: [], icon: icon, breadcrumbs: [strings.Settings_PrivacySettings], present: { context, present in
            presentSelectivePrivacySettings(context, .profilePhoto, present)
        }),
        SettingsSearchableItem(id: .privacy(4), title: strings.Privacy_Forwards, alternate: [], icon: icon, breadcrumbs: [strings.Settings_PrivacySettings], present: { context, present in
            presentSelectivePrivacySettings(context, .forwards, present)
        }),
        SettingsSearchableItem(id: .privacy(5), title: strings.Privacy_Calls, alternate: [], icon: icon, breadcrumbs: [strings.Settings_PrivacySettings], present: { context, present in
            presentSelectivePrivacySettings(context, .voiceCalls, present)
        }),
        SettingsSearchableItem(id: .privacy(6), title: strings.Privacy_GroupsAndChannels, alternate: [], icon: icon, breadcrumbs: [strings.Settings_PrivacySettings], present: { context, present in
            presentSelectivePrivacySettings(context, .groupInvitations, present)
        }),
        SettingsSearchableItem(id: .privacy(7), title: passcodeTitle, alternate: [], icon: icon, breadcrumbs: [strings.Settings_PrivacySettings], present: { context, present in
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
        SettingsSearchableItem(id: .privacy(8), title: strings.PrivacySettings_TwoStepAuth, alternate: [], icon: icon, breadcrumbs: [strings.Settings_PrivacySettings], present: { context, present in
            present(.modal, twoStepVerificationUnlockSettingsController(context: context, mode: .access))
        }),
        SettingsSearchableItem(id: .privacy(9), title: strings.PrivacySettings_AuthSessions, alternate: [], icon: icon, breadcrumbs: [strings.Settings_PrivacySettings], present: { context, present in
            present(.push, recentSessionsController(context: context))
        }),
        SettingsSearchableItem(id: .privacy(10), title: strings.PrivacySettings_DeleteAccountTitle.capitalized, alternate: [], icon: icon, breadcrumbs: [strings.Settings_PrivacySettings], present: { context, present in
            presentPrivacySettings(context, present)
        }),
        SettingsSearchableItem(id: .privacy(11), title: strings.PrivacySettings_DataSettings, alternate: [], icon: icon, breadcrumbs: [strings.Settings_PrivacySettings], present: { context, present in
            present(.push, dataPrivacyController(context: context))
        })
    ]
}

private func dataSearchableItems(context: AccountContext) -> [SettingsSearchableItem] {
    let icon: SettingsSearchableItemIcon = .data
    let strings = context.sharedContext.currentPresentationData.with { $0 }.strings
    
    let presentDataSettings: (AccountContext, (SettingsSearchableItemPresentation, ViewController) -> Void) -> Void = { context, present in
        present(.push, dataAndStorageController(context: context))
    }
    
    return [
        SettingsSearchableItem(id: .data(0), title: strings.Settings_ChatSettings, alternate: [], icon: icon, breadcrumbs: [], present: { context, present in
            presentDataSettings(context, present)
        }),
        SettingsSearchableItem(id: .data(1), title: strings.ChatSettings_Cache, alternate: [], icon: icon, breadcrumbs: [strings.Settings_ChatSettings], present: { context, present in
            present(.push, storageUsageController(context: context))
        }),
        SettingsSearchableItem(id: .data(2), title: strings.Cache_KeepMedia, alternate: [], icon: icon, breadcrumbs: [strings.Settings_ChatSettings, strings.ChatSettings_Cache], present: { context, present in
            present(.push, storageUsageController(context: context))
        }),
        SettingsSearchableItem(id: .data(3), title: strings.Cache_ClearCache, alternate: [], icon: icon, breadcrumbs: [strings.Settings_ChatSettings, strings.ChatSettings_Cache], present: { context, present in
            present(.push, storageUsageController(context: context))
        }),
        SettingsSearchableItem(id: .data(4), title: strings.NetworkUsageSettings_Title, alternate: [], icon: icon, breadcrumbs: [strings.Settings_ChatSettings], present: { context, present in
            present(.push, networkUsageStatsController(context: context))
        }),
        SettingsSearchableItem(id: .data(5), title: strings.ChatSettings_AutoDownloadUsingCellular, alternate: [], icon: icon, breadcrumbs: [strings.Settings_ChatSettings, strings.ChatSettings_AutoDownloadTitle.capitalized], present: { context, present in
            present(.push, autodownloadMediaConnectionTypeController(context: context, connectionType: .cellular))
        }),
        SettingsSearchableItem(id: .data(6), title: strings.ChatSettings_AutoDownloadUsingWiFi, alternate: [], icon: icon, breadcrumbs: [strings.Settings_ChatSettings, strings.ChatSettings_AutoDownloadTitle.capitalized], present: { context, present in
            present(.push, autodownloadMediaConnectionTypeController(context: context, connectionType: .wifi))
        }),
        SettingsSearchableItem(id: .data(7), title: strings.ChatSettings_AutoDownloadReset, alternate: [], icon: icon, breadcrumbs: [strings.Settings_ChatSettings], present: { context, present in
            presentDataSettings(context, present)
        }),
        SettingsSearchableItem(id: .data(8), title: strings.ChatSettings_AutoPlayGifs, alternate: [], icon: icon, breadcrumbs: [strings.Settings_ChatSettings], present: { context, present in
            presentDataSettings(context, present)
        }),
        SettingsSearchableItem(id: .data(9), title: strings.ChatSettings_AutoPlayVideos, alternate: [], icon: icon, breadcrumbs: [strings.Settings_ChatSettings], present: { context, present in
            presentDataSettings(context, present)
        }),
        SettingsSearchableItem(id: .data(10), title: strings.CallSettings_UseLessData, alternate: [], icon: icon, breadcrumbs: [strings.Settings_ChatSettings, strings.Settings_CallSettings], present: { context, present in
            present(.push, voiceCallDataSavingController(context: context))
        }),
        SettingsSearchableItem(id: .data(11), title: strings.Settings_SaveIncomingPhotos, alternate: [], icon: icon, breadcrumbs: [strings.Settings_ChatSettings], present: { context, present in
            present(.push, saveIncomingMediaController(context: context))
        }),
        SettingsSearchableItem(id: .data(12), title: strings.Settings_SaveEditedPhotos, alternate: [], icon: icon, breadcrumbs: [strings.Settings_ChatSettings], present: { context, present in
            presentDataSettings(context, present)
        }),
        SettingsSearchableItem(id: .data(13), title: strings.ChatSettings_DownloadInBackground, alternate: [], icon: icon, breadcrumbs: [strings.Settings_ChatSettings], present: { context, present in
            presentDataSettings(context, present)
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
        SettingsSearchableItem(id: .proxy(0), title: strings.Settings_Proxy, alternate: [], icon: icon, breadcrumbs: [], present: { context, present in
            presentProxySettings(context, present)
        }),
        SettingsSearchableItem(id: .proxy(1), title: strings.SocksProxySetup_AddProxy, alternate: [], icon: icon, breadcrumbs: [strings.Settings_Proxy], present: { context, present in
            present(.modal, proxyServerSettingsController(context: context))
        }),
        SettingsSearchableItem(id: .proxy(2), title: strings.SocksProxySetup_UseForCalls, alternate: [], icon: icon, breadcrumbs: [strings.Settings_Proxy], present: { context, present in
            presentProxySettings(context, present)
        })
    ]
}

private func appearanceSearchableItems(context: AccountContext) -> [SettingsSearchableItem] {
    let icon: SettingsSearchableItemIcon = .appearance
    let strings = context.sharedContext.currentPresentationData.with { $0 }.strings
    
    let presentAppearanceSettings: (AccountContext, (SettingsSearchableItemPresentation, ViewController) -> Void) -> Void = { context, present in
        present(.push, themeSettingsController(context: context))
    }
    
    return [
        SettingsSearchableItem(id: .appearance(0), title: strings.Settings_Appearance, alternate: [], icon: icon, breadcrumbs: [], present: { context, present in
            presentAppearanceSettings(context, present)
        }),
        SettingsSearchableItem(id: .appearance(1), title: strings.Appearance_TextSize.capitalized, alternate: [], icon: icon, breadcrumbs: [strings.Settings_Appearance], present: { context, present in
            presentAppearanceSettings(context, present)
        }),
        SettingsSearchableItem(id: .appearance(2), title: strings.Settings_ChatBackground, alternate: ["Wallpaper"], icon: icon, breadcrumbs: [strings.Settings_Appearance], present: { context, present in
            present(.push, ThemeGridController(context: context))
        }),
        SettingsSearchableItem(id: .appearance(3), title: strings.Wallpaper_SetColor, alternate: [], icon: icon, breadcrumbs: [strings.Settings_Appearance, strings.Settings_ChatBackground], present: { context, present in
            present(.push, ThemeColorsGridController(context: context))
        }),
        SettingsSearchableItem(id: .appearance(4), title: strings.Wallpaper_SetCustomBackground, alternate: [], icon: icon, breadcrumbs: [strings.Settings_Appearance, strings.Settings_ChatBackground], present: { context, present in
            presentCustomWallpaperPicker(context: context, present: { controller in
                present(.immediate, controller)
            })
        }),
        SettingsSearchableItem(id: .appearance(5), title: strings.Appearance_AutoNightTheme, alternate: [], icon: icon, breadcrumbs: [strings.Settings_Appearance], present: { context, present in
            present(.push, themeAutoNightSettingsController(context: context))
        }),
        SettingsSearchableItem(id: .appearance(6), title: strings.Appearance_ColorTheme.capitalized, alternate: [], icon: icon, breadcrumbs: [strings.Settings_Appearance], present: { context, present in
            presentAppearanceSettings(context, present)
        }),
        SettingsSearchableItem(id: .appearance(7), title: strings.Appearance_ReduceMotion, alternate: ["Animations"], icon: icon, breadcrumbs: [strings.Settings_Appearance, strings.Appearance_Animations.capitalized], present: { context, present in
            presentAppearanceSettings(context, present)
        }),
    ]
}

func settingsSearchableItems(context: AccountContext) -> Signal<[SettingsSearchableItem], NoError> {
    let watchAppInstalled = context.watchManager?.watchAppInstalled ?? .single(false)
    return watchAppInstalled
    |> take(1)
    |> map { watchAppInstalled in
        let strings = context.sharedContext.currentPresentationData.with { $0 }.strings
        
        var allItems: [SettingsSearchableItem] = []
        
        let savedMessages = SettingsSearchableItem(id: .savedMessages(0), title: strings.Settings_SavedMessages, alternate: [], icon: .savedMessages, breadcrumbs: [], present: { context, present in
            present(.push, ChatController(context: context, chatLocation: .peer(context.account.peerId)))
        })
        allItems.append(savedMessages)
        
        let callItems = callSearchableItems(context: context)
        allItems.append(contentsOf: callItems)
        
        let stickerItems = stickerSearchableItems(context: context)
        allItems.append(contentsOf: stickerItems)

        let notificationItems = notificationSearchableItems(context: context, notifyExceptions: .complete())
        allItems.append(contentsOf: notificationItems)
        
        let privacyItems = privacySearchableItems(context: context)
        allItems.append(contentsOf: privacyItems)
        
        let dataItems = dataSearchableItems(context: context)
        allItems.append(contentsOf: dataItems)
        
        let proxyItems = proxySearchableItems(context: context)
        allItems.append(contentsOf: proxyItems)
        
        let appearanceItems = appearanceSearchableItems(context: context)
        allItems.append(contentsOf: appearanceItems)
        
        let language = SettingsSearchableItem(id: .language(0), title: strings.Settings_AppLanguage, alternate: [], icon: .language, breadcrumbs: [], present: { context, present in
            present(.push, LocalizationListController(context: context))
        })
        allItems.append(language)
        
        let passport = SettingsSearchableItem(id: .passport(0), title: strings.Settings_Passport, alternate: [], icon: .passport, breadcrumbs: [], present: { context, present in
            present(.modal, SecureIdAuthController(context: context, mode: .list))
        })
        allItems.append(passport)
        
        let support = SettingsSearchableItem(id: .support(0), title: strings.Settings_Support, alternate: ["Support"], icon: .support, breadcrumbs: [], present: { context, present in
            //return .push(ChatController(context: context, chatLocation: .peer(context.account.peerId)))
        })
        allItems.append(support)
        
        let faq = SettingsSearchableItem(id: .faq(0), title: strings.Settings_FAQ, alternate: [], icon: .faq, breadcrumbs: [], present: { context, present in
            //return .push(ChatController(context: context, chatLocation: .peer(context.account.peerId)))
        })
        allItems.append(faq)
    
        return allItems
    }
}

private func stringTokens(_ string: String) -> [ValueBoxKey] {
    let nsString = string.lowercased() as NSString
    
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
        
        let tokens = stringTokens(string)
        if matchStringTokens(tokens, with: queryTokens) {
            result.append(item)
        }
    }
    
    return result
}
