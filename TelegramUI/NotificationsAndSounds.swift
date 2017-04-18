import Foundation
import Display
import SwiftSignalKit
import Postbox
import TelegramCore

private final class NotificationsAndSoundsArguments {
    let account: Account
    let presentController: (ViewController, ViewControllerPresentationArguments) -> Void
    let soundSelectionDisposable: MetaDisposable
    
    let updateMessageAlerts: (Bool) -> Void
    let updateMessagePreviews: (Bool) -> Void
    let updateMessageSound: (PeerMessageSound) -> Void
    
    let updateGroupAlerts: (Bool) -> Void
    let updateGroupPreviews: (Bool) -> Void
    let updateGroupSound: (PeerMessageSound) -> Void
    
    let updateInAppSounds: (Bool) -> Void
    let updateInAppVibration: (Bool) -> Void
    let updateInAppPreviews: (Bool) -> Void
    
    let resetNotifications: () -> Void
    
    init(account: Account, presentController: @escaping (ViewController, ViewControllerPresentationArguments) -> Void, soundSelectionDisposable: MetaDisposable, updateMessageAlerts: @escaping (Bool) -> Void, updateMessagePreviews: @escaping (Bool) -> Void, updateMessageSound: @escaping (PeerMessageSound) -> Void, updateGroupAlerts: @escaping (Bool) -> Void, updateGroupPreviews: @escaping (Bool) -> Void, updateGroupSound: @escaping (PeerMessageSound) -> Void, updateInAppSounds: @escaping (Bool) -> Void, updateInAppVibration: @escaping (Bool) -> Void, updateInAppPreviews: @escaping (Bool) -> Void, resetNotifications: @escaping () -> Void) {
        self.account = account
        self.presentController = presentController
        self.soundSelectionDisposable = soundSelectionDisposable
        self.updateMessageAlerts = updateMessageAlerts
        self.updateMessagePreviews = updateMessagePreviews
        self.updateMessageSound = updateMessageSound
        self.updateGroupAlerts = updateGroupAlerts
        self.updateGroupPreviews = updateGroupPreviews
        self.updateGroupSound = updateGroupSound
        self.updateInAppSounds = updateInAppSounds
        self.updateInAppVibration = updateInAppVibration
        self.updateInAppPreviews = updateInAppPreviews
        self.resetNotifications = resetNotifications
    }
}

private enum NotificationsAndSoundsSection: Int32 {
    case messages
    case groups
    case inApp
    case reset
}

private enum NotificationsAndSoundsEntry: ItemListNodeEntry {
    case messageHeader
    case messageAlerts(Bool)
    case messagePreviews(Bool)
    case messageSound(PeerMessageSound)
    case messageNotice
    
    case groupHeader
    case groupAlerts(Bool)
    case groupPreviews(Bool)
    case groupSound(PeerMessageSound)
    case groupNotice
    
    case inAppHeader
    case inAppSounds(Bool)
    case inAppVibrate(Bool)
    case inAppPreviews(Bool)
    
    case reset
    case resetNotice
    
    var section: ItemListSectionId {
        switch self {
            case .messageHeader, .messageAlerts, .messagePreviews, .messageSound, .messageNotice:
                return NotificationsAndSoundsSection.messages.rawValue
            case .groupHeader, .groupAlerts, .groupPreviews, .groupSound, .groupNotice:
                return NotificationsAndSoundsSection.groups.rawValue
            case .inAppHeader, .inAppSounds, .inAppVibrate, .inAppPreviews:
                return NotificationsAndSoundsSection.inApp.rawValue
            case .reset, .resetNotice:
                return NotificationsAndSoundsSection.reset.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
            case .messageHeader:
                return 0
            case .messageAlerts:
                return 1
            case .messagePreviews:
                return 2
            case .messageSound:
                return 3
            case .messageNotice:
                return 4
            case .groupHeader:
                return 5
            case .groupAlerts:
                return 6
            case .groupPreviews:
                return 7
            case .groupSound:
                return 8
            case .groupNotice:
                return 9
            case .inAppHeader:
                return 10
            case .inAppSounds:
                return 11
            case .inAppVibrate:
                return 12
            case .inAppPreviews:
                return 13
            case .reset:
                return 14
            case .resetNotice:
                return 15
        }
    }
    
    static func ==(lhs: NotificationsAndSoundsEntry, rhs: NotificationsAndSoundsEntry) -> Bool {
        switch lhs {
            case .messageHeader:
                if case .messageHeader = rhs {
                    return true
                } else {
                    return false
                }
            case let .messageAlerts(value):
                if case .messageAlerts(value) = rhs {
                    return true
                } else {
                    return false
                }
            case let .messagePreviews(value):
                if case .messagePreviews(value) = rhs {
                    return true
                } else {
                    return false
                }
            case let .messageSound(value):
                if case .messageSound(value) = rhs {
                    return true
                } else {
                    return false
                }
            case .messageNotice:
                if case .messageNotice = rhs {
                    return true
                } else {
                    return false
                }
            case .groupHeader:
                if case .groupHeader = rhs {
                    return true
                } else {
                    return false
                }
            case let .groupAlerts(value):
                if case .groupAlerts(value) = rhs {
                    return true
                } else {
                    return false
                }
            case let .groupPreviews(value):
                if case .groupPreviews(value) = rhs {
                    return true
                } else {
                    return false
                }
            case let .groupSound(value):
                if case .groupSound(value) = rhs {
                    return true
                } else {
                    return false
                }
            case .groupNotice:
                if case .groupNotice = rhs {
                    return true
                } else {
                    return false
                }
            case .inAppHeader:
                if case .inAppHeader = rhs {
                    return true
                } else {
                    return false
                }
            case let .inAppSounds(value):
                if case .inAppSounds(value) = rhs {
                    return true
                } else {
                    return false
                }
            case let .inAppVibrate(value):
                if case .inAppVibrate(value) = rhs {
                    return true
                } else {
                    return false
                }
            case let .inAppPreviews(value):
                if case .inAppPreviews(value) = rhs {
                    return true
                } else {
                    return false
                }
            case .reset:
                if case .reset = rhs {
                    return true
                } else {
                    return false
                }
            case .resetNotice:
                if case .resetNotice = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: NotificationsAndSoundsEntry, rhs: NotificationsAndSoundsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(_ arguments: NotificationsAndSoundsArguments) -> ListViewItem {
        switch self {
            case .messageHeader:
                return ItemListSectionHeaderItem(text: "MESSAGE NOTIFICATIONS", sectionId: self.section)
            case let .messageAlerts(value):
                return ItemListSwitchItem(title: "Alert", value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                    arguments.updateMessageAlerts(updatedValue)
                })
            case let .messagePreviews(value):
                return ItemListSwitchItem(title: "Message Preview", value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                    arguments.updateMessagePreviews(updatedValue)
                })
            case let .messageSound(value):
                return ItemListDisclosureItem(title: "Sound", label: localizedPeerNotificationSoundString(value), sectionId: self.section, style: .blocks, action: {
                    let (controller, result) = notificationSoundSelectionController(account: arguments.account, isModal: true, currentSound: value)
                    arguments.presentController(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                    arguments.soundSelectionDisposable.set(result.start(next: { [weak arguments] value in
                        if let value = value {
                            arguments?.updateMessageSound(value)
                        }
                    }))
                })
            case .messageNotice:
                return ItemListTextItem(text: .plain("You can set custom notifications for specific users on their info page."), sectionId: self.section)
            case .groupHeader:
                return ItemListSectionHeaderItem(text: "GROUP NOTIFICATIONS", sectionId: self.section)
            case let .groupAlerts(value):
                return ItemListSwitchItem(title: "Alert", value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                    arguments.updateGroupAlerts(updatedValue)
                })
            case let .groupPreviews(value):
                return ItemListSwitchItem(title: "Message Preview", value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                    arguments.updateGroupPreviews(updatedValue)
                })
            case let .groupSound(value):
                return ItemListDisclosureItem(title: "Sound", label: localizedPeerNotificationSoundString(value), sectionId: self.section, style: .blocks, action: {
                    let (controller, result) = notificationSoundSelectionController(account: arguments.account, isModal: true, currentSound: value)
                    arguments.presentController(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                    arguments.soundSelectionDisposable.set(result.start(next: { [weak arguments] value in
                        if let value = value {
                            arguments?.updateGroupSound(value)
                        }
                    }))
                })
            case .groupNotice:
                return ItemListTextItem(text: .plain("You can set custom notifications for specific groups on their info page."), sectionId: self.section)
            case .inAppHeader:
                return ItemListSectionHeaderItem(text: "IN-APP NOTIFICATIONS", sectionId: self.section)
            case let .inAppSounds(value):
                return ItemListSwitchItem(title: "In-App Sounds", value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                    arguments.updateInAppSounds(updatedValue)
                })
            case let .inAppVibrate(value):
                return ItemListSwitchItem(title: "In-App Vibrate", value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                    arguments.updateInAppVibration(updatedValue)
                })
            case let .inAppPreviews(value):
                return ItemListSwitchItem(title: "In-App Preview", value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                    arguments.updateInAppPreviews(updatedValue)
                })
            case .reset:
                return ItemListActionItem(title: "Reset All Notifications", kind: .destructive, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                    arguments.resetNotifications()
                })
            case .resetNotice:
                return ItemListTextItem(text: .plain("Undo all custom notification settings for all your contacts and groups."), sectionId: self.section)
        }
    }
}

private func notificationsAndSoundsEntries(globalSettings: GlobalNotificationSettingsSet, inAppSettings: InAppNotificationSettings) -> [NotificationsAndSoundsEntry] {
    var entries: [NotificationsAndSoundsEntry] = []
    
    entries.append(.messageHeader)
    entries.append(.messageAlerts(globalSettings.privateChats.enabled))
    entries.append(.messagePreviews(globalSettings.privateChats.displayPreviews))
    entries.append(.messageSound(globalSettings.privateChats.sound))
    entries.append(.messageNotice)
    
    entries.append(.groupHeader)
    entries.append(.groupAlerts(globalSettings.groupChats.enabled))
    entries.append(.groupPreviews(globalSettings.groupChats.displayPreviews))
    entries.append(.groupSound(globalSettings.groupChats.sound))
    entries.append(.groupNotice)
    
    entries.append(.inAppHeader)
    entries.append(.inAppSounds(inAppSettings.playSounds))
    entries.append(.inAppVibrate(inAppSettings.vibrate))
    entries.append(.inAppPreviews(inAppSettings.displayPreviews))
    
    entries.append(.reset)
    entries.append(.resetNotice)
    
    return entries
}

public func notificationsAndSoundsController(account: Account) -> ViewController {
    var presentControllerImpl: ((ViewController, ViewControllerPresentationArguments?) -> Void)?
    
    let arguments = NotificationsAndSoundsArguments(account: account, presentController: { controller, arguments in
        presentControllerImpl?(controller, arguments)
    }, soundSelectionDisposable: MetaDisposable(), updateMessageAlerts: { value in
        let _ = updateGlobalNotificationSettingsInteractively(postbox: account.postbox, { settings in
            return settings.withUpdatedPrivateChats {
                return $0.withUpdatedEnabled(value)
            }
        }).start()
    }, updateMessagePreviews: { value in
        let _ = updateGlobalNotificationSettingsInteractively(postbox: account.postbox, { settings in
            return settings.withUpdatedPrivateChats {
                return $0.withUpdatedDisplayPreviews(value)
            }
        }).start()
    }, updateMessageSound: { value in
        let _ = updateGlobalNotificationSettingsInteractively(postbox: account.postbox, { settings in
            return settings.withUpdatedPrivateChats {
                return $0.withUpdatedSound(value)
            }
        }).start()
    }, updateGroupAlerts: { value in
        let _ = updateGlobalNotificationSettingsInteractively(postbox: account.postbox, { settings in
            return settings.withUpdatedGroupChats {
                return $0.withUpdatedEnabled(value)
            }
        }).start()
    }, updateGroupPreviews: { value in
        let _ = updateGlobalNotificationSettingsInteractively(postbox: account.postbox, { settings in
            return settings.withUpdatedGroupChats {
                return $0.withUpdatedDisplayPreviews(value)
            }
        }).start()
    }, updateGroupSound: {value in
        let _ = updateGlobalNotificationSettingsInteractively(postbox: account.postbox, { settings in
            return settings.withUpdatedGroupChats {
                return $0.withUpdatedSound(value)
            }
        }).start()
    }, updateInAppSounds: { value in
        let _ = updateInAppNotificationSettingsInteractively(postbox: account.postbox, { settings in
            return settings.withUpdatedPlaySounds(value)
        }).start()
    }, updateInAppVibration: { value in
        let _ = updateInAppNotificationSettingsInteractively(postbox: account.postbox, { settings in
            return settings.withUpdatedVibrate(value)
        }).start()
    }, updateInAppPreviews: { value in
        let _ = updateInAppNotificationSettingsInteractively(postbox: account.postbox, { settings in
            return settings.withUpdatedDisplayPreviews(value)
        }).start()
    }, resetNotifications: {
        let actionSheet = ActionSheetController()
        actionSheet.setItemGroups([ActionSheetItemGroup(items: [
            ActionSheetButtonItem(title: "Reset", color: .destructive, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
                
                let modifyPeers = account.postbox.modify { modifier -> Void in
                    modifier.resetAllPeerNotificationSettings(TelegramPeerNotificationSettings.defaultSettings)
                }
                let updateGlobal = updateGlobalNotificationSettingsInteractively(postbox: account.postbox, { _ in
                    return GlobalNotificationSettingsSet.defaultSettings
                })
                let reset = resetPeerNotificationSettings(network: account.network)
                let signal = combineLatest(modifyPeers, updateGlobal, reset)
                let _ = signal.start()
            })
        ]), ActionSheetItemGroup(items: [
            ActionSheetButtonItem(title: "Cancel", color: .accent, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
            })
        ])])
        presentControllerImpl?(actionSheet, nil)
    })
    
    let preferences = account.postbox.preferencesView(keys: [PreferencesKeys.globalNotifications, ApplicationSpecificPreferencesKeys.inAppNotificationSettings])
    
    let signal = preferences
        |> map { view -> (ItemListControllerState, (ItemListNodeState<NotificationsAndSoundsEntry>, NotificationsAndSoundsEntry.ItemGenerationArguments)) in
            
            let viewSettings: GlobalNotificationSettingsSet
            if let settings = view.values[PreferencesKeys.globalNotifications] as? GlobalNotificationSettings {
                viewSettings = settings.effective
            } else {
                viewSettings = GlobalNotificationSettingsSet.defaultSettings
            }
            
            let inAppSettings: InAppNotificationSettings
            if let settings = view.values[ApplicationSpecificPreferencesKeys.inAppNotificationSettings] as? InAppNotificationSettings {
                inAppSettings = settings
            } else {
                inAppSettings = InAppNotificationSettings.defaultSettings
            }
            
            let controllerState = ItemListControllerState(title: .text("Notifications"), leftNavigationButton: nil, rightNavigationButton: nil)
            let listState = ItemListNodeState(entries: notificationsAndSoundsEntries(globalSettings: viewSettings, inAppSettings: inAppSettings), style: .blocks)
            
            return (controllerState, (listState, arguments))
    }
    
    let controller = ItemListController(signal)
    presentControllerImpl = { [weak controller] c, a in
        controller?.present(c, in: .window, with: a)
    }
    return controller
}
