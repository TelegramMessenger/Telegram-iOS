import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
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
import ItemListPeerItem
import ItemListPeerActionItem

private final class NotificationsPeerCategoryControllerArguments {
    let context: AccountContext
    let presentController: (ViewController, ViewControllerPresentationArguments?) -> Void
    let pushController: (ViewController) -> Void
    let soundSelectionDisposable: MetaDisposable
    
    let updateEnabled: (Bool) -> Void
    let updatePreviews: (Bool) -> Void
    let updateSound: (PeerMessageSound) -> Void
    
    let addException: () -> Void
    let openException: (Peer) -> Void
    let removeAllExceptions: () -> Void
    let updateRevealedPeerId: (PeerId?) -> Void
    let removePeer: (Peer) -> Void
        
    let updatedExceptionMode: (NotificationExceptionMode) -> Void
        
    init(context: AccountContext, presentController: @escaping (ViewController, ViewControllerPresentationArguments?) -> Void, pushController: @escaping (ViewController) -> Void, soundSelectionDisposable: MetaDisposable, updateEnabled: @escaping (Bool) -> Void, updatePreviews: @escaping (Bool) -> Void, updateSound: @escaping (PeerMessageSound) -> Void, addException: @escaping () -> Void, openException: @escaping (Peer) -> Void, removeAllExceptions: @escaping () -> Void, updateRevealedPeerId: @escaping (PeerId?) -> Void, removePeer: @escaping (Peer) -> Void, updatedExceptionMode: @escaping (NotificationExceptionMode) -> Void) {
        self.context = context
        self.presentController = presentController
        self.pushController = pushController
        self.soundSelectionDisposable = soundSelectionDisposable
        
        self.updateEnabled = updateEnabled
        self.updatePreviews = updatePreviews
        self.updateSound = updateSound
        
        self.addException = addException
        self.openException = openException
        self.removeAllExceptions = removeAllExceptions
        
        self.updateRevealedPeerId = updateRevealedPeerId
        self.removePeer = removePeer
        
        self.updatedExceptionMode = updatedExceptionMode
    }
}

private enum NotificationsPeerCategorySection: Int32 {
    case enable
    case options
    case exceptions
}

public enum NotificationsPeerCategoryEntryTag: ItemListItemTag {
    case enable
    case previews
    case sound
    
    public func isEqual(to other: ItemListItemTag) -> Bool {
        if let other = other as? NotificationsPeerCategoryEntryTag, self == other {
            return true
        } else {
            return false
        }
    }
}

private enum NotificationsPeerCategoryEntry: ItemListNodeEntry {
    case enable(PresentationTheme, String, Bool)
    case optionsHeader(PresentationTheme, String)
    case previews(PresentationTheme, String, Bool)
    case sound(PresentationTheme, String, String, PeerMessageSound)
  
    case exceptionsHeader(PresentationTheme, String)
    case addException(PresentationTheme, String)
    case exception(Int32, PresentationTheme, PresentationStrings, PresentationDateTimeFormat, PresentationPersonNameOrder, Peer, TelegramPeerNotificationSettings, Bool, Bool)
    case removeAllExceptions(PresentationTheme, String)
    
    var section: ItemListSectionId {
        switch self {
            case .enable:
                return NotificationsPeerCategorySection.enable.rawValue
            case .optionsHeader, .previews, .sound:
                return NotificationsPeerCategorySection.options.rawValue
            case .exceptionsHeader, .addException, .exception, .removeAllExceptions:
                return NotificationsPeerCategorySection.exceptions.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
            case .enable:
                return 0
            case .optionsHeader:
                return 1
            case .previews:
                return 2
            case .sound:
                return 3
            case .exceptionsHeader:
                return 4
            case .addException:
                return 5
            case let .exception(index, _, _, _, _, _, _, _, _):
                return 6 + index
            case .removeAllExceptions:
                return 100000
        }
    }
    
    var tag: ItemListItemTag? {
        switch self {
            case .enable:
                return NotificationsPeerCategoryEntryTag.enable
            case .previews:
                return NotificationsPeerCategoryEntryTag.previews
            case .sound:
                return NotificationsPeerCategoryEntryTag.sound
            default:
                return nil
        }
    }
    
    static func ==(lhs: NotificationsPeerCategoryEntry, rhs: NotificationsPeerCategoryEntry) -> Bool {
        switch lhs {
            case let .enable(lhsTheme, lhsText, lhsValue):
                if case let .enable(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .optionsHeader(lhsTheme, lhsText):
                if case let .optionsHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .previews(lhsTheme, lhsText, lhsValue):
                if case let .previews(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .sound(lhsTheme, lhsText, lhsValue, lhsSound):
                if case let .sound(rhsTheme, rhsText, rhsValue, rhsSound) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue, lhsSound == rhsSound {
                    return true
                } else {
                    return false
            }
            case let .exceptionsHeader(lhsTheme, lhsText):
                if case let .exceptionsHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .addException(lhsTheme, lhsText):
                if case let .addException(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .exception(lhsIndex, lhsTheme, lhsStrings, lhsDateTimeFormat, lhsDisplayNameOrder, lhsPeer, lhsSettings, lhsEditing, lhsRevealed):
                if case let .exception(rhsIndex, rhsTheme, rhsStrings, rhsDateTimeFormat, rhsDisplayNameOrder, rhsPeer, rhsSettings, rhsEditing, rhsRevealed) = rhs, lhsIndex == rhsIndex, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsDateTimeFormat == rhsDateTimeFormat, lhsDisplayNameOrder == rhsDisplayNameOrder, arePeersEqual(lhsPeer, rhsPeer), lhsSettings == rhsSettings, lhsEditing == rhsEditing, lhsRevealed == rhsRevealed {
                    return true
                } else {
                    return false
                }
            case let .removeAllExceptions(lhsTheme, lhsText):
                if case let .removeAllExceptions(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            
        }
    }
    
    static func <(lhs: NotificationsPeerCategoryEntry, rhs: NotificationsPeerCategoryEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! NotificationsPeerCategoryControllerArguments
        switch self {
            case let .enable(_, text, value):
                return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                    arguments.updateEnabled(updatedValue)
                }, tag: self.tag)
            case let .optionsHeader(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .previews(_, text, value):
                return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.updatePreviews(value)
                })
            case let .sound(_, text, value, _):
                return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, labelStyle: .text, sectionId: self.section, style: .blocks, disclosureStyle: .arrow, action: {
                    
                }, tag: self.tag)
            case let .exceptionsHeader(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .addException(theme, text):
                return ItemListPeerActionItem(presentationData: presentationData, icon: PresentationResourcesItemList.addPersonIcon(theme), title: text, sectionId: self.section, height: .generic, color: .accent, editing: false, action: {
                    arguments.addException()
                })
            case let .removeAllExceptions(theme, text):
                return ItemListPeerActionItem(presentationData: presentationData, icon: PresentationResourcesItemList.addPersonIcon(theme), title: text, sectionId: self.section, height: .generic, color: .destructive, editing: false, action: {
                    arguments.removeAllExceptions()
                })
            case let .exception(_, _, _, dateTimeFormat, nameDisplayOrder, peer, _, editing, revealed):
                return ItemListPeerItem(presentationData: presentationData, dateTimeFormat: dateTimeFormat, nameDisplayOrder: nameDisplayOrder, context: arguments.context, peer: EnginePeer(peer), presence: nil, text: .text("", .secondary), label: .none, editing: ItemListPeerItemEditing(editable: true, editing: editing, revealed: revealed), switchValue: nil, enabled: true, selectable: true, sectionId: self.section, action: {
                    arguments.openException(peer)
                }, setPeerIdWithRevealedOptions: { peerId, fromPeerId in
                    arguments.updateRevealedPeerId(peerId)
                }, removePeer: { peerId in
                    arguments.removePeer(peer)
                }, hasTopStripe: false, hasTopGroupInset: false, noInsets: false)
        }
    }
}

private func filteredGlobalSound(_ sound: PeerMessageSound) -> PeerMessageSound {
    if case .default = sound {
        return .bundledModern(id: 0)
    } else {
        return sound
    }
}

private func notificationsPeerCategoryEntries(category: NotificationsPeerCategory, globalSettings: GlobalNotificationSettingsSet, exceptions: (users: NotificationExceptionMode, groups: NotificationExceptionMode, channels: NotificationExceptionMode), presentationData: PresentationData) -> [NotificationsPeerCategoryEntry] {
    var entries: [NotificationsPeerCategoryEntry] = []
    
    let notificationSettings: MessageNotificationSettings
    switch category {
        case .privateChat:
            notificationSettings = globalSettings.privateChats
        case .group:
            notificationSettings = globalSettings.groupChats
        case .channel:
            notificationSettings = globalSettings.channels
    }

    entries.append(.enable(presentationData.theme, presentationData.strings.Notifications_MessageNotificationsAlert, notificationSettings.enabled))
        
    if notificationSettings.enabled || !exceptions.users.isEmpty {
        entries.append(.optionsHeader(presentationData.theme, presentationData.strings.Notifications_MessageNotifications.uppercased()))
        entries.append(.previews(presentationData.theme, presentationData.strings.Notifications_MessageNotificationsPreview, notificationSettings.displayPreviews))
        entries.append(.sound(presentationData.theme, presentationData.strings.Notifications_MessageNotificationsSound, localizedPeerNotificationSoundString(strings: presentationData.strings, sound: filteredGlobalSound(notificationSettings.sound)), filteredGlobalSound(notificationSettings.sound)))
    }
        
    entries.append(.exceptionsHeader(presentationData.theme, presentationData.strings.Notifications_MessageNotifications.uppercased()))
   
    return entries
}

public enum NotificationsPeerCategory {
    case privateChat
    case group
    case channel
}

public func notificationsPeerCategoryController(context: AccountContext, category: NotificationsPeerCategory, exceptionsList: NotificationExceptionsList?, focusOnItemTag: NotificationsPeerCategoryEntryTag? = nil) -> ViewController {
    var presentControllerImpl: ((ViewController, ViewControllerPresentationArguments?) -> Void)?
    var pushControllerImpl: ((ViewController) -> Void)?
    
    let notificationExceptions: Promise<(users: NotificationExceptionMode, groups: NotificationExceptionMode, channels: NotificationExceptionMode)> = Promise()
    
    let updateNotificationExceptions:((users: NotificationExceptionMode, groups: NotificationExceptionMode, channels: NotificationExceptionMode)) -> Void = { value in
        notificationExceptions.set(.single(value))
    }
    
    let arguments = NotificationsPeerCategoryControllerArguments(context: context, presentController: { controller, arguments in
        presentControllerImpl?(controller, arguments)
    }, pushController: { controller in
        pushControllerImpl?(controller)
    }, soundSelectionDisposable: MetaDisposable(), updateEnabled: { value in
        let _ = updateGlobalNotificationSettingsInteractively(postbox: context.account.postbox, { settings in
            var settings = settings
            switch category {
                case .privateChat:
                    settings.privateChats.enabled = value
                case .group:
                    settings.groupChats.enabled = value
                case .channel:
                    settings.channels.enabled = value
            }
            return settings
        }).start()
    }, updatePreviews: { value in
        let _ = updateGlobalNotificationSettingsInteractively(postbox: context.account.postbox, { settings in
            var settings = settings
            switch category {
                case .privateChat:
                    settings.privateChats.displayPreviews = value
                case .group:
                    settings.groupChats.displayPreviews = value
                case .channel:
                    settings.channels.displayPreviews = value
            }
            return settings
        }).start()
    }, updateSound: { value in
        let _ = updateGlobalNotificationSettingsInteractively(postbox: context.account.postbox, { settings in
            var settings = settings
            switch category {
                case .privateChat:
                    settings.privateChats.sound = value
                case .group:
                    settings.groupChats.sound = value
                case .channel:
                    settings.channels.sound = value
            }
            return settings
        }).start()
    }, addException: {
        
    }, openException: { peer in
        
    }, removeAllExceptions: {
        
    }, updateRevealedPeerId: { peerId in
        
    }, removePeer: { peer in
        
    }, updatedExceptionMode: { mode in
        _ = (notificationExceptions.get() |> take(1) |> deliverOnMainQueue).start(next: { (users, groups, channels) in
            switch mode {
                case .users:
                    updateNotificationExceptions((mode, groups, channels))
                case .groups:
                    updateNotificationExceptions((users, mode, channels))
                case .channels:
                    updateNotificationExceptions((users, groups, mode))
            }
        })
    })
    
    let sharedData = context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.inAppNotificationSettings])
    let preferences = context.account.postbox.preferencesView(keys: [PreferencesKeys.globalNotifications])
    
    let exceptionsSignal = Signal<NotificationExceptionsList?, NoError>.single(exceptionsList) |> then(context.engine.peers.notificationExceptionsList() |> map(Optional.init))
    
    notificationExceptions.set(exceptionsSignal |> map { list -> (NotificationExceptionMode, NotificationExceptionMode, NotificationExceptionMode) in
        var users:[PeerId : NotificationExceptionWrapper] = [:]
        var groups: [PeerId : NotificationExceptionWrapper] = [:]
        var channels:[PeerId : NotificationExceptionWrapper] = [:]
        if let list = list {
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
    })
            
    let signal = combineLatest(context.sharedContext.presentationData, sharedData, preferences, notificationExceptions.get())
    |> map { presentationData, sharedData, view, exceptions -> (ItemListControllerState, (ItemListNodeState, Any)) in
            let viewSettings: GlobalNotificationSettingsSet
            if let settings = view.values[PreferencesKeys.globalNotifications]?.get(GlobalNotificationSettings.self) {
                viewSettings = settings.effective
            } else {
                viewSettings = GlobalNotificationSettingsSet.defaultSettings
            }
            
            let entries = notificationsPeerCategoryEntries(category: category, globalSettings: viewSettings, exceptions: exceptions, presentationData: presentationData)
            
            var index = 0
            var scrollToItem: ListViewScrollToItem?
            if let focusOnItemTag = focusOnItemTag {
                for entry in entries {
                    if entry.tag?.isEqual(to: focusOnItemTag) ?? false {
                        scrollToItem = ListViewScrollToItem(index: index, position: .top(0.0), animated: false, curve: .Default(duration: 0.0), directionHint: .Up)
                    }
                    index += 1
                }
            }
            
            let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(presentationData.strings.Notifications_Title), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
            let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, ensureVisibleItemTag: focusOnItemTag, initialScrollToItem: scrollToItem)
            
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
