import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import PresentationDataUtils
import AccountContext
import AlertUI
import PresentationDataUtils
import NotificationSoundSelectionUI
import TelegramStringFormatting
import ItemListPeerItem
import ItemListPeerActionItem
import SettingsUI
import NotificationPeerExceptionController

private extension EnginePeer.NotificationSettings.MuteState {
    var timeInterval: Int32? {
        switch self {
        case .default:
            return nil
        case .unmuted:
            return 0
        case let .muted(until):
            return until
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

private final class NotificationsPeerCategoryControllerArguments {
    let context: AccountContext
    let soundSelectionDisposable: MetaDisposable
    
    let updateEnabled: (Bool) -> Void
    let updatePreviews: (Bool) -> Void
    
    let openSound: (PeerMessageSound) -> Void
    
    let addException: () -> Void
    let openException: (Int64) -> Void
    let removeAllExceptions: () -> Void
    let updateRevealedThreadId: (Int64?) -> Void
    let removeThread: (Int64) -> Void
        
    init(context: AccountContext, soundSelectionDisposable: MetaDisposable, updateEnabled: @escaping (Bool) -> Void, updatePreviews: @escaping (Bool) -> Void, openSound: @escaping (PeerMessageSound) -> Void, addException: @escaping () -> Void, openException: @escaping (Int64) -> Void, removeAllExceptions: @escaping () -> Void, updateRevealedThreadId: @escaping (Int64?) -> Void, removeThread: @escaping (Int64) -> Void) {
        self.context = context
        self.soundSelectionDisposable = soundSelectionDisposable
        
        self.updateEnabled = updateEnabled
        self.updatePreviews = updatePreviews
        self.openSound = openSound
        
        self.addException = addException
        self.openException = openException
        self.removeAllExceptions = removeAllExceptions
        
        self.updateRevealedThreadId = updateRevealedThreadId
        self.removeThread = removeThread
    }
}

private enum NotificationsPeerCategorySection: Int32 {
    case enable
    case options
    case exceptions
}

private enum NotificationsPeerCategoryEntryTag: ItemListItemTag {
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
    case enable(String, Bool)
    case optionsHeader(String)
    case previews(String, Bool)
    case sound(String, String, PeerMessageSound)
  
    case exceptionsHeader(String)
    case addException(String)
    case exception(Int32, PresentationDateTimeFormat, PresentationPersonNameOrder, EnginePeer, Int64, EngineMessageHistoryThread.Info, String, TelegramPeerNotificationSettings, Bool, Bool)
    case removeAllExceptions(String)
    
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
        case let .exception(index, _, _, _, _, _, _, _, _, _):
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
        case let .enable(lhsText, lhsValue):
            if case let .enable(rhsText, rhsValue) = rhs, lhsText == rhsText, lhsValue == rhsValue {
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
        case let .exceptionsHeader(lhsText):
            if case let .exceptionsHeader(rhsText) = rhs, lhsText == rhsText {
                return true
            } else {
                return false
            }
        case let .addException(lhsText):
            if case let .addException(rhsText) = rhs, lhsText == rhsText {
                return true
            } else {
                return false
            }
        case let .exception(lhsIndex, lhsDateTimeFormat, lhsDisplayNameOrder, lhsPeer, lhsThreadId, lhsInfo, lhsDescription, lhsSettings, lhsEditing, lhsRevealed):
            if case let .exception(rhsIndex, rhsDateTimeFormat, rhsDisplayNameOrder, rhsPeer, rhsThreadId, rhsInfo, rhsDescription, rhsSettings, rhsEditing, rhsRevealed) = rhs, lhsIndex == rhsIndex, lhsDateTimeFormat == rhsDateTimeFormat, lhsDisplayNameOrder == rhsDisplayNameOrder, lhsPeer == rhsPeer, lhsThreadId == rhsThreadId, lhsInfo == rhsInfo, lhsDescription == rhsDescription, lhsSettings == rhsSettings, lhsEditing == rhsEditing, lhsRevealed == rhsRevealed {
                return true
            } else {
                return false
            }
        case let .removeAllExceptions(lhsText):
            if case let .removeAllExceptions(rhsText) = rhs, lhsText == rhsText {
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
        case let .enable(text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                arguments.updateEnabled(updatedValue)
            }, tag: self.tag)
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
        case let .exceptionsHeader(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .addException(text):
            return ItemListPeerActionItem(presentationData: presentationData, icon: PresentationResourcesItemList.plusIconImage(presentationData.theme), title: text, sectionId: self.section, height: .peerList, color: .accent, editing: false, action: {
                arguments.addException()
            })
        case let .exception(_, dateTimeFormat, nameDisplayOrder, peer, threadId, info, description, _, editing, revealed):
            return ItemListPeerItem(presentationData: presentationData, dateTimeFormat: dateTimeFormat, nameDisplayOrder: nameDisplayOrder, context: arguments.context, peer: peer, threadInfo: info, presence: nil, text: .text(description, .secondary), label: .none, editing: ItemListPeerItemEditing(editable: true, editing: editing, revealed: revealed), switchValue: nil, enabled: true, selectable: true, sectionId: self.section, action: {
                arguments.openException(threadId)
            }, setPeerIdWithRevealedOptions: { peerId, fromPeerId in
                if let _ = peerId {
                    arguments.updateRevealedThreadId(threadId)
                } else {
                    arguments.updateRevealedThreadId(nil)
                }
            }, removePeer: { _ in
                arguments.removeThread(threadId)
            }, hasTopStripe: false, hasTopGroupInset: false, noInsets: false)
        case let .removeAllExceptions(text):
            return ItemListPeerActionItem(presentationData: presentationData, icon: PresentationResourcesItemList.deleteIconImage(presentationData.theme), title: text, sectionId: self.section, height: .generic, color: .destructive, editing: false, action: {
                arguments.removeAllExceptions()
            })
        }
    }
}

private func notificationsPeerCategoryEntries(peerId: EnginePeer.Id, notificationSettings: EnginePeer.NotificationSettings, state: NotificationExceptionState, presentationData: PresentationData, notificationSoundList: NotificationSoundList?) -> [NotificationsPeerCategoryEntry] {
    var entries: [NotificationsPeerCategoryEntry] = []

    var notificationsEnabled = true
    if case .muted = notificationSettings.muteState {
        notificationsEnabled = false
    }
    var displayPreviews = true
    switch notificationSettings.displayPreviews {
    case .hide:
        displayPreviews = false
    default:
        break
    }
    entries.append(.enable(presentationData.strings.Notifications_MessageNotificationsAlert, notificationsEnabled))
        
    if notificationsEnabled || !state.notificationExceptions.isEmpty {
        entries.append(.optionsHeader(presentationData.strings.Notifications_Options.uppercased()))
        entries.append(.previews(presentationData.strings.Notifications_MessageNotificationsPreview, displayPreviews))
        entries.append(.sound(presentationData.strings.Notifications_MessageNotificationsSound, localizedPeerNotificationSoundString(strings: presentationData.strings, notificationSoundList: notificationSoundList, sound: filteredGlobalSound(notificationSettings.messageSound._asMessageSound())), filteredGlobalSound(notificationSettings.messageSound._asMessageSound())))
    }
    
    entries.append(.exceptionsHeader(presentationData.strings.Notifications_MessageNotificationsExceptions.uppercased()))
    entries.append(.addException(presentationData.strings.Notification_Exceptions_AddException))
    
    var existingThreadIds = Set<Int64>()
    var index: Int = 0
    
    for value in state.notificationExceptions {
        var title: String
        var muted = false
        switch value.notificationSettings.muteState {
        case let .muted(until):
            if until >= Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970) {
                if until < Int32.max - 1 {
                    let formatter = DateFormatter()
                    formatter.locale = Locale(identifier: presentationData.strings.baseLanguageCode)
                    
                    if Calendar.current.isDateInToday(Date(timeIntervalSince1970: Double(until))) {
                        formatter.dateFormat = "HH:mm"
                    } else {
                        formatter.dateFormat = "E, d MMM HH:mm"
                    }
                    
                    let dateString = formatter.string(from: Date(timeIntervalSince1970: Double(until)))
                    
                    title = presentationData.strings.Notification_Exceptions_MutedUntil(dateString).string
                } else {
                    muted = true
                    title = presentationData.strings.Notification_Exceptions_AlwaysOff
                }
            } else {
                title = presentationData.strings.Notification_Exceptions_AlwaysOn
            }
        case .unmuted:
            title = presentationData.strings.Notification_Exceptions_AlwaysOn
        default:
            title = ""
        }
        if !muted {
            switch value.notificationSettings.messageSound {
            case .default:
                break
            default:
                if !title.isEmpty {
                    title.append(", ")
                }
                title.append(presentationData.strings.Notification_Exceptions_SoundCustom)
            }
            switch value.notificationSettings.displayPreviews {
            case .default:
                break
            default:
                if !title.isEmpty {
                    title += ", "
                }
                if case .show = value.notificationSettings.displayPreviews {
                    title += presentationData.strings.Notification_Exceptions_PreviewAlwaysOn
                } else {
                    title += presentationData.strings.Notification_Exceptions_PreviewAlwaysOff
                }
            }
        }
        existingThreadIds.insert(value.threadId)
        entries.append(.exception(Int32(index), presentationData.dateTimeFormat, presentationData.nameDisplayOrder, .channel(TelegramChannel(id: peerId, accessHash: nil, title: "", username: nil, photo: [], creationDate: 0, version: 0, participationStatus: .member, info: .group(TelegramChannelGroupInfo(flags: [])), flags: [.isForum], restrictionInfo: nil, adminRights: nil, bannedRights: nil, defaultBannedRights: nil, usernames: [])), value.threadId, value.info, title, value.notificationSettings._asNotificationSettings(), state.editing, state.revealedThreadId == value.threadId))
        index += 1
    }
    
    if state.notificationExceptions.count > 0 {
        entries.append(.removeAllExceptions(presentationData.strings.Notifications_DeleteAllExceptions))
    }

    return entries
}

private extension EnginePeer.NotificationSettings {
    var isDefault: Bool {
        switch self.muteState {
        case .default:
            break
        case .muted, .unmuted:
            return false
        }
        
        switch self.messageSound {
        case .default:
            break
        case .none, .bundledClassic, .bundledModern, .cloud:
            return false
        }
        
        switch self.displayPreviews {
        case .default:
            break
        case .hide, .show:
            return false
        }
        
        return true
    }
}

private struct NotificationExceptionState: Equatable {
    var revealedThreadId: Int64? = nil
    var editing: Bool = false
    var notificationExceptions: [EngineMessageHistoryThread.NotificationException] = []
    
    mutating func updateSound(threadId: Int64, info: EngineMessageHistoryThread.Info, sound: PeerMessageSound) {
        if let index = self.notificationExceptions.firstIndex(where: { $0.threadId == threadId }) {
            self.notificationExceptions[index].notificationSettings.messageSound = EnginePeer.NotificationSettings.MessageSound(sound)
            if self.notificationExceptions[index].notificationSettings.isDefault {
                self.notificationExceptions.remove(at: index)
            }
        } else {
            var settings = EnginePeer.NotificationSettings(.defaultSettings)
            settings.messageSound = EnginePeer.NotificationSettings.MessageSound(sound)
            if !settings.isDefault {
                notificationExceptions.insert(EngineMessageHistoryThread.NotificationException(threadId: threadId, info: info, notificationSettings: settings), at: 0)
            }
        }
    }
    
    mutating func updateMuteInterval(threadId: Int64, info: EngineMessageHistoryThread.Info, muteInterval: Int32?) {
        if let index = self.notificationExceptions.firstIndex(where: { $0.threadId == threadId }) {
            self.notificationExceptions[index].notificationSettings.muteState = muteInterval.flatMap { .muted(until: $0) } ?? .unmuted
            if self.notificationExceptions[index].notificationSettings.isDefault {
                self.notificationExceptions.remove(at: index)
            }
        } else {
            var settings = EnginePeer.NotificationSettings(.defaultSettings)
            settings.muteState = muteInterval.flatMap { .muted(until: $0) } ?? .unmuted
            if !settings.isDefault {
                notificationExceptions.insert(EngineMessageHistoryThread.NotificationException(threadId: threadId, info: info, notificationSettings: settings), at: 0)
            }
        }
    }
    
    mutating func updateDisplayPreviews(threadId: Int64, info: EngineMessageHistoryThread.Info, displayPreviews: PeerNotificationDisplayPreviews) {
        if let index = self.notificationExceptions.firstIndex(where: { $0.threadId == threadId }) {
            self.notificationExceptions[index].notificationSettings.displayPreviews = EnginePeer.NotificationSettings.DisplayPreviews(displayPreviews)
            if self.notificationExceptions[index].notificationSettings.isDefault {
                self.notificationExceptions.remove(at: index)
            }
        } else {
            var settings = EnginePeer.NotificationSettings(.defaultSettings)
            settings.displayPreviews = EnginePeer.NotificationSettings.DisplayPreviews(displayPreviews)
            if !settings.isDefault {
                notificationExceptions.insert(EngineMessageHistoryThread.NotificationException(threadId: threadId, info: info, notificationSettings: settings), at: 0)
            }
        }
    }
}

public func threadNotificationExceptionsScreen(context: AccountContext, peerId: EnginePeer.Id, notificationExceptions: [EngineMessageHistoryThread.NotificationException], updated: @escaping ([EngineMessageHistoryThread.NotificationException]) -> Void) -> ViewController {
    var presentControllerImpl: ((ViewController, Any?) -> Void)?
    var pushControllerImpl: ((ViewController) -> Void)?
    
    let initialState = NotificationExceptionState(notificationExceptions: notificationExceptions)
    let stateValue = Atomic<NotificationExceptionState>(value: initialState)
    let statePromise: ValuePromise<NotificationExceptionState> = ValuePromise(ignoreRepeated: true)
    
    statePromise.set(initialState)
    
    let updateState: ((NotificationExceptionState) -> NotificationExceptionState) -> Void = { f in
        let result = stateValue.modify { f($0) }
        statePromise.set(result)
    }
    
    let updateThreadSound: (Int64, PeerMessageSound) -> Signal<Void, NoError> = { threadId, sound in
        return context.engine.peers.updatePeerNotificationSoundInteractive(peerId: peerId, threadId: threadId, sound: sound)
        |> deliverOnMainQueue
    }

    let updateThreadNotificationInterval: (Int64, Int32?) -> Signal<Void, NoError> = { threadId, muteInterval in
        return context.engine.peers.updatePeerMuteSetting(peerId: peerId, threadId: threadId, muteInterval: muteInterval)
        |> deliverOnMainQueue
    }

    let updateThreadDisplayPreviews: (Int64, PeerNotificationDisplayPreviews) -> Signal<Void, NoError> = {
        threadId, displayPreviews in
        return context.engine.peers.updatePeerDisplayPreviewsSetting(peerId: peerId, threadId: threadId, displayPreviews: displayPreviews) |> deliverOnMainQueue
    }
    
    let presentThreadSettings: (EngineMessageHistoryThread.NotificationException, @escaping () -> Void) -> Void = { item, completion in
        let _ = (context.engine.data.get(
            TelegramEngine.EngineData.Item.Peer.Peer(id: peerId),
            TelegramEngine.EngineData.Item.NotificationSettings.Global()
        )
        |> deliverOnMainQueue).start(next: { peer, globalSettings in
            completion()
            
            guard let peer = peer else {
                return
            }
            
            let canRemove = true
            let defaultSound: PeerMessageSound = globalSettings.groupChats.sound._asMessageSound()
            
            pushControllerImpl?(notificationPeerExceptionController(context: context, peer: peer._asPeer(), customTitle: item.info.title, threadId: item.threadId, canRemove: canRemove, defaultSound: defaultSound, updatePeerSound: { _, sound in
                let _ = (updateThreadSound(item.threadId, sound)
                |> deliverOnMainQueue).start(next: { _ in
                    updateState { value in
                        var value = value
                        value.updateSound(threadId: item.threadId, info: item.info, sound: sound)
                        return value
                    }
                    updated(stateValue.with({ $0 }).notificationExceptions)
                })
            }, updatePeerNotificationInterval: { _, muteInterval in
                let _ = (updateThreadNotificationInterval(item.threadId, muteInterval)
                |> deliverOnMainQueue).start(next: { _ in
                    updateState { value in
                        var value = value
                        value.updateMuteInterval(threadId: item.threadId, info: item.info, muteInterval: muteInterval)
                        return value
                    }
                    updated(stateValue.with({ $0 }).notificationExceptions)
                })
            }, updatePeerDisplayPreviews: { _, displayPreviews in
                let _ = (updateThreadDisplayPreviews(item.threadId, displayPreviews)
                |> deliverOnMainQueue).start(next: { _ in
                    updateState { value in
                        var value = value
                        value.updateDisplayPreviews(threadId: item.threadId, info: item.info, displayPreviews: displayPreviews)
                        return value
                    }
                    updated(stateValue.with({ $0 }).notificationExceptions)
                })
            }, removePeerFromExceptions: {
                let _ = context.engine.peers.removeCustomThreadNotificationSettings(peerId: peerId, threadIds: [item.threadId]).start()
                updateState { current in
                    var current = current
                    current.notificationExceptions.removeAll(where: { $0.threadId == item.threadId })
                    return current
                }
                updated(stateValue.with({ $0 }).notificationExceptions)
            }, modifiedPeer: {
            }))
        })
    }
    
    let _ = presentControllerImpl
    
    let arguments = NotificationsPeerCategoryControllerArguments(context: context, soundSelectionDisposable: MetaDisposable(), updateEnabled: { _ in
        let _ = context.engine.peers.togglePeerMuted(peerId: peerId, threadId: nil).start()
    }, updatePreviews: { value in
        let _ = context.engine.peers.updatePeerDisplayPreviewsSetting(peerId: peerId, threadId: nil, displayPreviews: value ? .show : .hide).start()
    }, openSound: { sound in
        let controller = notificationSoundSelectionController(context: context, isModal: true, currentSound: sound, defaultSound: nil, completion: { value in
            let _ = context.engine.peers.updatePeerNotificationSoundInteractive(peerId: peerId, threadId: nil, sound: value).start()
        })
        pushControllerImpl?(controller)
    }, addException: {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let filter: ChatListNodePeersFilter = [.excludeRecent, .doNotSearchMessages, .removeSearchHeader]
        let controller = context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(context: context, filter: filter, forumPeerId: peerId, hasContactSelector: false, title: presentationData.strings.Notifications_AddExceptionTitle))
        controller.peerSelected = { [weak controller] _, threadId in
            guard let threadId = threadId else {
                return
            }
            let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.ThreadData(id: peerId, threadId: threadId))
            |> deliverOnMainQueue).start(next: { threadData in
                guard let threadData = threadData else {
                    return
                }
                
                presentThreadSettings(EngineMessageHistoryThread.NotificationException(threadId: threadId, info: threadData.info, notificationSettings: EnginePeer.NotificationSettings(.defaultSettings)), {
                    controller?.dismiss()
                })
            })
        }
        pushControllerImpl?(controller)
    }, openException: { threadId in
        if let item = stateValue.with({ $0 }).notificationExceptions.first(where: { $0.threadId == threadId }) {
            presentThreadSettings(item, {})
        }
    }, removeAllExceptions: {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let actionSheet = ActionSheetController(presentationData: presentationData)
        actionSheet.setItemGroups([ActionSheetItemGroup(items: [
            ActionSheetTextItem(title: presentationData.strings.Notification_Exceptions_DeleteAllConfirmation),
            ActionSheetButtonItem(title: presentationData.strings.Notification_Exceptions_DeleteAll, color: .destructive, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
                
                var threadIds: [Int64] = []
                updateState { current in
                    var current = current
                    threadIds = current.notificationExceptions.map(\.threadId)
                    current.notificationExceptions.removeAll()
                    return current
                }
                updated(stateValue.with({ $0 }).notificationExceptions)
                let _ = context.engine.peers.removeCustomThreadNotificationSettings(peerId: peerId, threadIds: threadIds).start()
            })
        ]), ActionSheetItemGroup(items: [
            ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
            })
        ])])
        presentControllerImpl?(actionSheet, nil)
    }, updateRevealedThreadId: { threadId in
        updateState { current in
            var current = current
            current.revealedThreadId = threadId
            return current
        }
    }, removeThread: { threadId in
        let _ = context.engine.peers.removeCustomThreadNotificationSettings(peerId: peerId, threadIds: [threadId]).start()
        updateState { current in
            var current = current
            current.notificationExceptions.removeAll(where: { $0.threadId == threadId })
            return current
        }
        updated(stateValue.with({ $0 }).notificationExceptions)
    })
    
    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        context.engine.peers.notificationSoundList(),
        context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)),
        context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.NotificationSettings(id: peerId)),
        statePromise.get()
    )
    |> map { presentationData, notificationSoundList, peer, notificationSettings, state -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let entries = notificationsPeerCategoryEntries(peerId: peerId, notificationSettings: notificationSettings, state: state, presentationData: presentationData, notificationSoundList: notificationSoundList)
        
        var scrollToItem: ListViewScrollToItem?
        scrollToItem = nil
        /*var index = 0
        if let focusOnItemTag = focusOnItemTag {
            for entry in entries {
                if entry.tag?.isEqual(to: focusOnItemTag) ?? false {
                    scrollToItem = ListViewScrollToItem(index: index, position: .top(0.0), animated: false, curve: .Default(duration: 0.0), directionHint: .Up)
                }
                index += 1
            }
        }*/
        
        let leftNavigationButton: ItemListNavigationButton?
        let rightNavigationButton: ItemListNavigationButton?
        if !state.notificationExceptions.isEmpty {
            if state.editing {
                leftNavigationButton = ItemListNavigationButton(content: .none, style: .regular, enabled: false, action: {})
                rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Done), style: .bold, enabled: true, action: {
                    updateState { value in
                        var value = value
                        value.editing = false
                        return value
                    }
                })
            } else {
                leftNavigationButton = nil
                rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Edit), style: .regular, enabled: true, action: {
                    updateState { value in
                        var value = value
                        value.editing = true
                        return value
                    }
                })
            }
        } else {
            leftNavigationButton = nil
            rightNavigationButton = nil
        }
        
        let title: String
        if let peer = peer {
            title = peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
        } else {
            title = ""
        }
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(title), leftNavigationButton: leftNavigationButton, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: true)
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, ensureVisibleItemTag: nil, initialScrollToItem: scrollToItem)
        
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
