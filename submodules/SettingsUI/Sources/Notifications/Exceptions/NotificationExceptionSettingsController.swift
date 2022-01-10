import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext
import LocalizedPeerData
import TelegramStringFormatting
import NotificationSoundSelectionUI

private enum NotificationPeerExceptionSection: Int32 {
    case remove
    case switcher
    case displayPreviews
    case soundModern
    case soundClassic
}

private enum NotificationPeerExceptionSwitcher : Equatable {
    case alwaysOn
    case alwaysOff
}

private enum NotificationPeerExceptionEntryId : Hashable {
    case remove
    case switcher(NotificationPeerExceptionSwitcher)
    case sound(PeerMessageSound)
    case switcherHeader
    case displayPreviews(NotificationPeerExceptionSwitcher)
    case displayPreviewsHeader
    case soundModernHeader
    case soundClassicHeader
    case none
    case `default`

    func hash(into hasher: inout Hasher) {
        hasher.combine(0)
    }
}

private final class NotificationPeerExceptionArguments  {
    let account: Account
    
    let selectSound: (PeerMessageSound) -> Void
    let selectMode: (NotificationPeerExceptionSwitcher) -> Void
    let selectDisplayPreviews: (NotificationPeerExceptionSwitcher) -> Void
    let removeFromExceptions: () -> Void
    let complete: () -> Void
    let cancel: () -> Void
    
    init(account: Account, selectSound: @escaping(PeerMessageSound) -> Void, selectMode: @escaping(NotificationPeerExceptionSwitcher) -> Void, selectDisplayPreviews: @escaping (NotificationPeerExceptionSwitcher) -> Void, removeFromExceptions: @escaping () -> Void, complete: @escaping()->Void, cancel: @escaping() -> Void) {
        self.account = account
        self.selectSound = selectSound
        self.selectMode = selectMode
        self.selectDisplayPreviews = selectDisplayPreviews
        self.removeFromExceptions = removeFromExceptions
        self.complete = complete
        self.cancel = cancel
    }
}


private enum NotificationPeerExceptionEntry: ItemListNodeEntry {
    typealias ItemGenerationArguments = NotificationPeerExceptionArguments
    
    case remove(index:Int32, theme: PresentationTheme, strings: PresentationStrings)
    case switcher(index:Int32, theme: PresentationTheme, strings: PresentationStrings, mode: NotificationPeerExceptionSwitcher, selected: Bool)
    case switcherHeader(index:Int32, theme: PresentationTheme, title: String)
    case displayPreviews(index:Int32, theme: PresentationTheme, strings: PresentationStrings, value: NotificationPeerExceptionSwitcher, selected: Bool)
    case displayPreviewsHeader(index:Int32, theme: PresentationTheme, title: String)
    case soundModernHeader(index:Int32, theme: PresentationTheme, title: String)
    case soundClassicHeader(index:Int32, theme: PresentationTheme, title: String)
    case none(index:Int32, section: NotificationPeerExceptionSection, theme: PresentationTheme, text: String, selected: Bool)
    case `default`(index:Int32, section: NotificationPeerExceptionSection, theme: PresentationTheme, text: String, selected: Bool)
    case sound(index:Int32, section: NotificationPeerExceptionSection, theme: PresentationTheme, text: String, sound: PeerMessageSound, selected: Bool)
    
    
    var index: Int32 {
        switch self {
        case let .remove(index, _, _):
            return index
        case let .switcherHeader(index, _, _):
            return index
        case let .switcher(index, _, _, _, _):
            return index
        case let .displayPreviewsHeader(index, _, _):
            return index
        case let .displayPreviews(index, _, _, _, _):
            return index
        case let .soundModernHeader(index, _, _):
            return index
        case let .soundClassicHeader(index, _, _):
            return index
        case let .none(index, _, _, _, _):
            return index
        case let .default(index, _, _, _, _):
            return index
        case let .sound(index, _, _, _, _, _):
            return index
        }
    }
    
    var section: ItemListSectionId {
        switch self {
        case .remove:
            return NotificationPeerExceptionSection.remove.rawValue
        case .switcher, .switcherHeader:
            return NotificationPeerExceptionSection.switcher.rawValue
        case .displayPreviews, .displayPreviewsHeader:
            return NotificationPeerExceptionSection.displayPreviews.rawValue
        case .soundModernHeader:
            return NotificationPeerExceptionSection.soundModern.rawValue
        case .soundClassicHeader:
            return NotificationPeerExceptionSection.soundClassic.rawValue
        case let .none(_, section, _, _, _):
            return section.rawValue
        case let .default(_, section, _, _, _):
            return section.rawValue
        case let .sound(_, section, _, _, _, _):
            return section.rawValue
        }
    }
    
    var stableId: NotificationPeerExceptionEntryId {
        switch self {
        case .remove:
            return .remove
        case let .switcher(_, _, _, mode, _):
            return .switcher(mode)
        case .switcherHeader:
            return .switcherHeader
        case let .displayPreviews(_, _, _, mode, _):
            return .displayPreviews(mode)
        case .displayPreviewsHeader:
            return .displayPreviewsHeader
        case .soundModernHeader:
            return .soundModernHeader
        case .soundClassicHeader:
            return .soundClassicHeader
        case .none:
            return .none
        case .default:
            return .default
        case let .sound(_, _, _, _, sound, _):
            return .sound(sound)
        }
    }

    static func <(lhs: NotificationPeerExceptionEntry, rhs: NotificationPeerExceptionEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! NotificationPeerExceptionArguments
        switch self {
        case let .remove(_, _, strings):
            return ItemListActionItem(presentationData: presentationData, title: strings.Notification_Exceptions_RemoveFromExceptions, kind: .generic, alignment: .center, sectionId: self.section, style: .blocks, action: {
                arguments.removeFromExceptions()
            })
        case let .switcher(_, _, strings, mode, selected):
            let title: String
            switch mode {
            case .alwaysOn:
                title = strings.Notification_Exceptions_AlwaysOn
            case .alwaysOff:
                title = strings.Notification_Exceptions_AlwaysOff
            }
            return ItemListCheckboxItem(presentationData: presentationData, title: title, style: .left, checked: selected, zeroSeparatorInsets: false, sectionId: self.section, action: {
                 arguments.selectMode(mode)
            })
        case let .switcherHeader(_, _, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .displayPreviews(_, _, strings, value, selected):
            let title: String
            switch value {
            case .alwaysOn:
                title = strings.Notification_Exceptions_MessagePreviewAlwaysOn
            case .alwaysOff:
                title = strings.Notification_Exceptions_MessagePreviewAlwaysOff
            }
            return ItemListCheckboxItem(presentationData: presentationData, title: title, style: .left, checked: selected, zeroSeparatorInsets: false, sectionId: self.section, action: {
                arguments.selectDisplayPreviews(value)
            })
        case let .displayPreviewsHeader(_, _, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .soundModernHeader(_, _, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .soundClassicHeader(_, _, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .none(_, _, _, text, selected):
            return ItemListCheckboxItem(presentationData: presentationData, title: text, style: .left, checked: selected, zeroSeparatorInsets: true, sectionId: self.section, action: {
                arguments.selectSound(.none)
            })
        case let .default(_, _, _, text, selected):
            return ItemListCheckboxItem(presentationData: presentationData, title: text, style: .left, checked: selected, zeroSeparatorInsets: false, sectionId: self.section, action: {
                arguments.selectSound(.default)
            })
        case let .sound(_, _, _, text, sound, selected):
            return ItemListCheckboxItem(presentationData: presentationData, title: text, style: .left, checked: selected, zeroSeparatorInsets: false, sectionId: self.section, action: {
                arguments.selectSound(sound)
            })
        }
    }
}


private func notificationPeerExceptionEntries(presentationData: PresentationData, state: NotificationExceptionPeerState) -> [NotificationPeerExceptionEntry] {
    var entries:[NotificationPeerExceptionEntry] = []
    
    var index: Int32 = 0
    
    if state.canRemove {
        entries.append(.remove(index: index, theme: presentationData.theme, strings: presentationData.strings))
        index += 1
    }
    
    entries.append(.switcherHeader(index: index, theme: presentationData.theme, title: presentationData.strings.Notification_Exceptions_NewException_NotificationHeader))
    index += 1

    
    entries.append(.switcher(index: index, theme: presentationData.theme, strings: presentationData.strings, mode: .alwaysOn, selected: state.mode == .alwaysOn))
    index += 1
    entries.append(.switcher(index: index, theme: presentationData.theme, strings: presentationData.strings, mode: .alwaysOff, selected:  state.mode == .alwaysOff))
    index += 1

    if state.mode != .alwaysOff {
        entries.append(.displayPreviewsHeader(index: index, theme: presentationData.theme, title: presentationData.strings.Notification_Exceptions_NewException_MessagePreviewHeader))
        index += 1
        entries.append(.displayPreviews(index: index, theme: presentationData.theme, strings: presentationData.strings, value: .alwaysOn, selected: state.displayPreviews == .alwaysOn))
        index += 1
        entries.append(.displayPreviews(index: index, theme: presentationData.theme, strings: presentationData.strings, value: .alwaysOff, selected: state.displayPreviews == .alwaysOff))
        index += 1
        
        entries.append(.soundModernHeader(index: index, theme: presentationData.theme, title: presentationData.strings.Notifications_AlertTones))
        index += 1
        
        entries.append(.default(index: index, section: .soundModern, theme: presentationData.theme, text: localizedPeerNotificationSoundString(strings: presentationData.strings, sound: .default, default: state.defaultSound), selected: state.selectedSound == .default))
        index += 1

        entries.append(.none(index: index, section: .soundModern, theme: presentationData.theme, text: localizedPeerNotificationSoundString(strings: presentationData.strings, sound: .none), selected: state.selectedSound == .none))
        index += 1

        for i in 0 ..< 12 {
            let sound: PeerMessageSound = .bundledModern(id: Int32(i))
            entries.append(.sound(index: index, section: .soundModern, theme: presentationData.theme, text: localizedPeerNotificationSoundString(strings: presentationData.strings, sound: sound), sound: sound, selected: sound == state.selectedSound))
            index += 1
        }
        
        entries.append(.soundClassicHeader(index: index, theme: presentationData.theme, title: presentationData.strings.Notifications_ClassicTones))
        index += 1
        
        for i in 0 ..< 8 {
            let sound: PeerMessageSound = .bundledClassic(id: Int32(i))
            entries.append(.sound(index: index, section: .soundClassic, theme: presentationData.theme, text: localizedPeerNotificationSoundString(strings: presentationData.strings, sound: sound), sound: sound, selected: sound == state.selectedSound))
            index += 1
        }
    }
    
    return entries
}

private struct NotificationExceptionPeerState : Equatable {
    let canRemove: Bool
    let selectedSound: PeerMessageSound
    let mode: NotificationPeerExceptionSwitcher
    let defaultSound: PeerMessageSound
    let displayPreviews: NotificationPeerExceptionSwitcher
    
    init(canRemove: Bool, notifications: TelegramPeerNotificationSettings? = nil) {
        self.canRemove = canRemove
        
        if let notifications = notifications {
            self.selectedSound = notifications.messageSound
            switch notifications.muteState {
            case let .muted(until) where until >= Int32.max - 1:
                self.mode = .alwaysOff
            default:
                self.mode = .alwaysOn
            }
            self.displayPreviews = notifications.displayPreviews == .hide ? .alwaysOff : .alwaysOn
        } else {
            self.selectedSound = .default
            self.mode = .alwaysOn
            self.displayPreviews = .alwaysOn
        }
      
        self.defaultSound = .default
    }
    
    init(canRemove: Bool, selectedSound: PeerMessageSound, mode: NotificationPeerExceptionSwitcher, defaultSound: PeerMessageSound, displayPreviews: NotificationPeerExceptionSwitcher) {
        self.canRemove = canRemove
        self.selectedSound = selectedSound
        self.mode = mode
        self.defaultSound = defaultSound
        self.displayPreviews = displayPreviews
    }
    
    func withUpdatedDefaultSound(_ defaultSound: PeerMessageSound) -> NotificationExceptionPeerState {
        return NotificationExceptionPeerState(canRemove: self.canRemove, selectedSound: self.selectedSound, mode: self.mode, defaultSound: defaultSound, displayPreviews: self.displayPreviews)
    }
    func withUpdatedSound(_ selectedSound: PeerMessageSound) -> NotificationExceptionPeerState {
        return NotificationExceptionPeerState(canRemove: self.canRemove, selectedSound: selectedSound, mode: self.mode, defaultSound: self.defaultSound, displayPreviews: self.displayPreviews)
    }
    func withUpdatedMode(_ mode: NotificationPeerExceptionSwitcher) -> NotificationExceptionPeerState {
        return NotificationExceptionPeerState(canRemove: self.canRemove, selectedSound: self.selectedSound, mode: mode, defaultSound: self.defaultSound, displayPreviews: self.displayPreviews)
    }
    func withUpdatedDisplayPreviews(_ displayPreviews: NotificationPeerExceptionSwitcher) -> NotificationExceptionPeerState {
        return NotificationExceptionPeerState(canRemove: self.canRemove, selectedSound: self.selectedSound, mode: self.mode, defaultSound: self.defaultSound, displayPreviews: displayPreviews)
    }
}


public func notificationPeerExceptionController(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, peer: Peer, mode: NotificationExceptionMode, edit: Bool = false, updatePeerSound: @escaping(PeerId, PeerMessageSound) -> Void, updatePeerNotificationInterval: @escaping(PeerId, Int32?) -> Void, updatePeerDisplayPreviews: @escaping(PeerId, PeerNotificationDisplayPreviews) -> Void, removePeerFromExceptions: @escaping () -> Void, modifiedPeer: @escaping () -> Void) -> ViewController {
    let initialState = NotificationExceptionPeerState(canRemove: false)
    let statePromise = Promise(initialState)
    let stateValue = Atomic(value: initialState)
    let updateState: ((NotificationExceptionPeerState) -> NotificationExceptionPeerState) -> Void = { f in
        statePromise.set(.single(stateValue.modify { f($0) }))
    }
    
    var completeImpl: (() -> Void)?
    var removeFromExceptionsImpl: (() -> Void)?
    var cancelImpl: (() -> Void)?
    let playSoundDisposable = MetaDisposable()

    let arguments = NotificationPeerExceptionArguments(account: context.account, selectSound: { sound in
        updateState { state in
            playSoundDisposable.set(playSound(context: context, sound: sound, defaultSound: state.defaultSound).start())
            return state.withUpdatedSound(sound)
        }
    }, selectMode: { mode in
        updateState { state in
            return state.withUpdatedMode(mode)
        }
    }, selectDisplayPreviews: { value in
        updateState { state in
            return state.withUpdatedDisplayPreviews(value)
        }
    }, removeFromExceptions: {
        removeFromExceptionsImpl?()
    }, complete: {
        completeImpl?()
    }, cancel: {
        cancelImpl?()
    })
    
    statePromise.set(context.account.postbox.transaction { transaction -> NotificationExceptionPeerState in
        var state = NotificationExceptionPeerState(canRemove: mode.peerIds.contains(peer.id), notifications: transaction.getPeerNotificationSettings(peer.id) as? TelegramPeerNotificationSettings)
        let globalSettings: GlobalNotificationSettings = transaction.getPreferencesEntry(key: PreferencesKeys.globalNotifications)?.get(GlobalNotificationSettings.self) ?? GlobalNotificationSettings.defaultSettings
        switch mode {
            case .channels:
                state = state.withUpdatedDefaultSound(globalSettings.effective.channels.sound)
            case .groups:
                state = state.withUpdatedDefaultSound(globalSettings.effective.groupChats.sound)
            case .users:
                state = state.withUpdatedDefaultSound(globalSettings.effective.privateChats.sound)
        }
        _ = stateValue.swap(state)
        return state
    })
    
    
    let signal = combineLatest(queue: .mainQueue(), (updatedPresentationData?.signal ?? context.sharedContext.presentationData), statePromise.get() |> distinctUntilChanged)
    |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let leftNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Cancel), style: .regular, enabled: true, action: {
            arguments.cancel()
        })
        
        let rightNavigationButton = ItemListNavigationButton(content: .text(state.canRemove || edit ? presentationData.strings.Common_Done : presentationData.strings.Notification_Exceptions_Add), style: .bold, enabled: true, action: {
            arguments.complete()
        })
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(EnginePeer(peer).displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)), leftNavigationButton: leftNavigationButton, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: notificationPeerExceptionEntries(presentationData: presentationData, state: state), style: .blocks, animateChanges: false)
        
        return (controllerState, (listState, arguments))
    }
    
    let controller = ItemListController(context: context, state: signal |> afterDisposed {
        playSoundDisposable.dispose()
    })

    controller.enableInteractiveDismiss = true
    
    completeImpl = { [weak controller] in
        controller?.dismiss()
        modifiedPeer()
        updateState { state in
            updatePeerSound(peer.id, state.selectedSound)
            updatePeerNotificationInterval(peer.id, state.mode == .alwaysOn ? 0 : Int32.max)
            updatePeerDisplayPreviews(peer.id, state.displayPreviews == .alwaysOn ? .show : .hide)
            return state
        }
    }
    
    removeFromExceptionsImpl = { [weak controller] in
        controller?.dismiss()
        removePeerFromExceptions()
    }
    
    cancelImpl = { [weak controller] in
        controller?.dismiss()
    }

    return controller
}
