import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import DeviceAccess
import ItemListUI
import PresentationDataUtils
import AccountContext
import AlertUI
import PresentationDataUtils
import TelegramNotices
import NotificationSoundSelectionUI
import TelegramStringFormatting

private final class ReactionNotificationSettingsControllerArguments {
    let context: AccountContext
    let soundSelectionDisposable: MetaDisposable
    
    let openMessages: () -> Void
    let openStories: () -> Void
    let toggleMessages: (Bool) -> Void
    let toggleStories: (Bool) -> Void
    let updatePreviews: (Bool) -> Void
    let openSound: (PeerMessageSound) -> Void
        
    init(
        context: AccountContext,
        soundSelectionDisposable: MetaDisposable,
        openMessages: @escaping () -> Void,
        openStories: @escaping () -> Void,
        toggleMessages: @escaping (Bool) -> Void,
        toggleStories: @escaping (Bool) -> Void,
        updatePreviews: @escaping (Bool) -> Void,
        openSound: @escaping (PeerMessageSound) -> Void
    ) {
        self.context = context
        self.soundSelectionDisposable = soundSelectionDisposable
        self.openMessages = openMessages
        self.openStories = openStories
        self.toggleMessages = toggleMessages
        self.toggleStories = toggleStories
        self.updatePreviews = updatePreviews
        self.openSound = openSound
    }
}

private enum ReactionNotificationSettingsSection: Int32 {
    case categories
    case options
}

private enum ReactionNotificationSettingsEntry: ItemListNodeEntry {
    enum StableId: Hashable {
        case categoriesHeader
        case messages
        case stories
        case optionsHeader
        case previews
        case sound
    }
    
    case categoriesHeader(String)
    case messages(title: String, text: String?, value: Bool)
    case stories(title: String, text: String?, value: Bool)
    
    case optionsHeader(String)
    case previews(String, Bool)
    case sound(String, String, PeerMessageSound)
    
    var section: ItemListSectionId {
        switch self {
        case .categoriesHeader, .messages, .stories:
            return ReactionNotificationSettingsSection.categories.rawValue
        case .optionsHeader, .previews, .sound:
            return ReactionNotificationSettingsSection.options.rawValue
        }
    }
    
    var stableId: StableId {
        switch self {
        case .categoriesHeader:
            return .categoriesHeader
        case .messages:
            return .messages
        case .stories:
            return .stories
        case .optionsHeader:
            return .optionsHeader
        case .previews:
            return .previews
        case .sound:
            return .sound
        }
    }
    
    var sortIndex: Int32 {
        switch self {
        case .categoriesHeader:
            return 0
        case .messages:
            return 1
        case .stories:
            return 2
        case .optionsHeader:
            return 3
        case .previews:
            return 4
        case .sound:
            return 5
        }
    }
    
    static func ==(lhs: ReactionNotificationSettingsEntry, rhs: ReactionNotificationSettingsEntry) -> Bool {
        switch lhs {
        case let .categoriesHeader(lhsText):
            if case let .categoriesHeader(rhsText) = rhs, lhsText == rhsText {
                return true
            } else {
                return false
            }
        case let .messages(title, text, value):
            if case .messages(title, text, value) = rhs {
                return true
            } else {
                return false
            }
        case let .stories(title, text, value):
            if case .stories(title, text, value) = rhs {
                return true
            } else {
                return false
            }
        case let .optionsHeader(lhsText):
            if case let .optionsHeader(rhsText) = rhs, lhsText == rhsText {
                return true
            } else {
                return false
            }
        case let .previews(lhsText, lhsValue):
            if case let .previews(rhsText, rhsValue) = rhs, lhsText == rhsText, lhsValue == rhsValue {
                return true
            } else {
                return false
            }
        case let .sound(lhsText, lhsValue, lhsSound):
            if case let .sound(rhsText, rhsValue, rhsSound) = rhs, lhsText == rhsText, lhsValue == rhsValue, lhsSound == rhsSound {
                return true
            } else {
                return false
            }
        }
    }
    
    static func <(lhs: ReactionNotificationSettingsEntry, rhs: ReactionNotificationSettingsEntry) -> Bool {
        return lhs.sortIndex < rhs.sortIndex
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! ReactionNotificationSettingsControllerArguments
        switch self {
        case let .categoriesHeader(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .messages(title, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: title, text: text, textColor: .accent, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggleMessages(value)
            }, action: {
                arguments.openMessages()
            })
        case let .stories(title, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: title, text: text, textColor: .accent, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggleStories(value)
            }, action: {
                arguments.openStories()
            })
        case let .optionsHeader(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .previews(text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updatePreviews(value)
            })
        case let .sound(text, value, sound):
            return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, labelStyle: .text, sectionId: self.section, style: .blocks, disclosureStyle: .arrow, action: {
                arguments.openSound(sound)
            }, tag: self.tag)
        }
    }
}

private func filteredGlobalSound(_ sound: PeerMessageSound) -> PeerMessageSound {
    if case .default = sound {
        return defaultCloudPeerNotificationSound
    } else {
        return sound
    }
}

private func reactionNotificationSettingsEntries(
    globalSettings: GlobalNotificationSettingsSet,
    state: ReactionNotificationSettingsState,
    presentationData: PresentationData,
    notificationSoundList: NotificationSoundList?
) -> [ReactionNotificationSettingsEntry] {
    var entries: [ReactionNotificationSettingsEntry] = []
    
    entries.append(.categoriesHeader(presentationData.strings.Notifications_Reactions_SettingsHeader))
    
    let messagesText: String?
    let messagesValue: Bool
    switch globalSettings.reactionSettings.messages {
    case .nobody:
        messagesText = nil
        messagesValue = false
    case .contacts:
        messagesText = presentationData.strings.Notifications_Reactions_SubtitleContacts
        messagesValue = true
    case .everyone:
        messagesText = presentationData.strings.Notifications_Reactions_SubtitleEveryone
        messagesValue = true
    }
    
    let storiesText: String?
    let storiesValue: Bool
    switch globalSettings.reactionSettings.stories {
    case .nobody:
        storiesText = nil
        storiesValue = false
    case .contacts:
        storiesText = presentationData.strings.Notifications_Reactions_SubtitleContacts
        storiesValue = true
    case .everyone:
        storiesText = presentationData.strings.Notifications_Reactions_SubtitleEveryone
        storiesValue = true
    }
    
    entries.append(.messages(title: presentationData.strings.Notifications_Reactions_ItemMessages, text: messagesText, value: messagesValue))
    entries.append(.stories(title: presentationData.strings.Notifications_Reactions_ItemStories, text: storiesText, value: storiesValue))
    
    if messagesValue || storiesValue {
        entries.append(.optionsHeader(presentationData.strings.Notifications_Options.uppercased()))
        
        entries.append(.previews(presentationData.strings.Notifications_Stories_DisplayName, globalSettings.reactionSettings.hideSender != .hide))
        entries.append(.sound(presentationData.strings.Notifications_MessageNotificationsSound, localizedPeerNotificationSoundString(strings: presentationData.strings, notificationSoundList: notificationSoundList, sound: filteredGlobalSound(globalSettings.reactionSettings.sound)), filteredGlobalSound(globalSettings.reactionSettings.sound)))
    }

    return entries
}

private struct ReactionNotificationSettingsState: Equatable {
    init() {
    }
}

public func reactionNotificationSettingsController(
    context: AccountContext
) -> ViewController {
    var presentControllerImpl: ((ViewController, Any?) -> Void)?
    var pushControllerImpl: ((ViewController) -> Void)?
    
    let stateValue = Atomic<ReactionNotificationSettingsState>(value: ReactionNotificationSettingsState())
    let statePromise: ValuePromise<ReactionNotificationSettingsState> = ValuePromise(ignoreRepeated: true)
    
    statePromise.set(stateValue.with { $0 })
    
    let updateState: ((ReactionNotificationSettingsState) -> ReactionNotificationSettingsState) -> Void = { f in
        let result = stateValue.modify { f($0) }
        statePromise.set(result)
    }
    let _ = updateState
    
    let openCategory: (Bool) -> Void = { isMessages in
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        let text: String
        if isMessages {
            text = presentationData.strings.Notifications_Reactions_SheetTitleMessages
        } else {
            text = presentationData.strings.Notifications_Reactions_SheetTitleStories
        }
        
        let actionSheet = ActionSheetController(presentationData: presentationData)
        actionSheet.setItemGroups([ActionSheetItemGroup(items: [
            ActionSheetTextItem(title: text),
            ActionSheetButtonItem(title: presentationData.strings.Notifications_Reactions_SheetValueEveryone, color: .accent, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
                
                let _ = updateGlobalNotificationSettingsInteractively(postbox: context.account.postbox, { settings in
                    var settings = settings
                    if isMessages {
                        settings.reactionSettings.messages = .everyone
                    } else {
                        settings.reactionSettings.stories = .everyone
                    }
                    return settings
                }).start()
            }),
            ActionSheetButtonItem(title: presentationData.strings.Notifications_Reactions_SheetValueContacts, color: .accent, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
                
                let _ = updateGlobalNotificationSettingsInteractively(postbox: context.account.postbox, { settings in
                    var settings = settings
                    if isMessages {
                        settings.reactionSettings.messages = .contacts
                    } else {
                        settings.reactionSettings.stories = .contacts
                    }
                    return settings
                }).start()
            })
        ]), ActionSheetItemGroup(items: [
            ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
            })
        ])])
        presentControllerImpl?(actionSheet, nil)
    }
    
    let arguments = ReactionNotificationSettingsControllerArguments(
        context: context,
        soundSelectionDisposable: MetaDisposable(),
        openMessages: {
            openCategory(true)
        },
        openStories: {
            openCategory(false)
        },
        toggleMessages: { value in
            let _ = updateGlobalNotificationSettingsInteractively(postbox: context.account.postbox, { settings in
                var settings = settings
                if value {
                    settings.reactionSettings.messages = .contacts
                } else {
                    settings.reactionSettings.messages = .nobody
                }
                return settings
            }).start()
        },
        toggleStories: { value in
            let _ = updateGlobalNotificationSettingsInteractively(postbox: context.account.postbox, { settings in
                var settings = settings
                if value {
                    settings.reactionSettings.stories = .contacts
                } else {
                    settings.reactionSettings.stories = .nobody
                }
                return settings
            }).start()
        },
        updatePreviews: { value in
            let _ = updateGlobalNotificationSettingsInteractively(postbox: context.account.postbox, { settings in
                var settings = settings
                settings.reactionSettings.hideSender = value ? .show : .hide
                return settings
            }).start()
        }, openSound: { sound in
            let controller = notificationSoundSelectionController(context: context, isModal: true, currentSound: sound, defaultSound: nil, completion: { value in
                let _ = updateGlobalNotificationSettingsInteractively(postbox: context.account.postbox, { settings in
                    var settings = settings
                    settings.reactionSettings.sound = value
                    return settings
                }).start()
            })
            pushControllerImpl?(controller)
        }
    )
    
    let preferences = context.account.postbox.preferencesView(keys: [PreferencesKeys.globalNotifications])
    
    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        context.engine.peers.notificationSoundList(),
        preferences,
        statePromise.get()
    )
    |> map { presentationData, notificationSoundList, preferencesView, state -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let viewSettings: GlobalNotificationSettingsSet
        if let settings = preferencesView.values[PreferencesKeys.globalNotifications]?.get(GlobalNotificationSettings.self) {
            viewSettings = settings.effective
        } else {
            viewSettings = GlobalNotificationSettingsSet.defaultSettings
        }
        
        let entries = reactionNotificationSettingsEntries(
            globalSettings: viewSettings,
            state: state,
            presentationData: presentationData,
            notificationSoundList: notificationSoundList
        )
        
        let leftNavigationButton: ItemListNavigationButton?
        let rightNavigationButton: ItemListNavigationButton?
        
        leftNavigationButton = nil
        rightNavigationButton = nil
        
        let title: String = presentationData.strings.Notifications_Reactions_Title
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(title), leftNavigationButton: leftNavigationButton, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: true)
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks)
        
        return (controllerState, (listState, arguments))
    }
    
    let controller = ItemListController(context: context, state: signal)
    presentControllerImpl = { [weak controller] c, a in
        controller?.present(c, in: .window(.root), with: a)
    }
    pushControllerImpl = { [weak controller] c in
        (controller?.navigationController as? NavigationController)?.pushViewController(c)
    }
    return controller
}
