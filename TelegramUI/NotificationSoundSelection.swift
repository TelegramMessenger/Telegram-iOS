import Foundation
import Display
import SwiftSignalKit
import Postbox
import TelegramCore

private struct NotificationSoundSelectionArguments {
    let account: Account
    
    let selectSound: (PeerMessageSound) -> Void
    let complete: () -> Void
    let cancel: () -> Void
}

private enum NotificationSoundSelectionSection: Int32 {
    case modern
    case classic
}

private struct NotificationSoundSelectionState: Equatable {
    let selectedSound: PeerMessageSound
    
    static func ==(lhs: NotificationSoundSelectionState, rhs: NotificationSoundSelectionState) -> Bool {
        return lhs.selectedSound == rhs.selectedSound
    }
}

private enum NotificationSoundSelectionEntry: ItemListNodeEntry {
    case modernHeader
    case classicHeader
    case none(section: NotificationSoundSelectionSection, selected: Bool)
    case sound(section: NotificationSoundSelectionSection, index: Int32, sound: PeerMessageSound, selected: Bool)
    
    var section: ItemListSectionId {
        switch self {
            case .modernHeader:
                return NotificationSoundSelectionSection.modern.rawValue
            case .classicHeader:
                return NotificationSoundSelectionSection.classic.rawValue
            case let .none(section, _):
                return section.rawValue
            case let .sound(section, _, _, _):
                return section.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
            case .modernHeader:
                return 0
            case .classicHeader:
                return 1000
            case let .none(section, _):
                switch section {
                    case .modern:
                        return 1
                    case .classic:
                        return 1001
                }
            case let .sound(section, index, _, _):
                switch section {
                    case .modern:
                        return 2 + index
                    case .classic:
                        return 1002 + index
                }
        }
    }
    
    static func ==(lhs: NotificationSoundSelectionEntry, rhs: NotificationSoundSelectionEntry) -> Bool {
        switch lhs {
            case .modernHeader, .classicHeader:
                if lhs.stableId == rhs.stableId {
                    return true
                } else {
                    return false
                }
            case let .none(section, selected):
                if case .none(section, selected) = rhs {
                    return true
                } else {
                    return false
                }
            case let .sound(section, index, name, selected):
                if case .sound(section, index, name, selected) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: NotificationSoundSelectionEntry, rhs: NotificationSoundSelectionEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(_ arguments: NotificationSoundSelectionArguments) -> ListViewItem {
        switch self {
            case .modernHeader:
                return ItemListSectionHeaderItem(text: "ALERT TONES", sectionId: self.section)
            case .classicHeader:
                return ItemListSectionHeaderItem(text: "ALERT TONES", sectionId: self.section)
            case let .none(_, selected):
                return ItemListCheckboxItem(title: localizedPeerNotificationSoundString(.none), checked: selected, zeroSeparatorInsets: true, sectionId: self.section, action: {
                    arguments.selectSound(.none)
                })
            case let .sound(_, _, sound, selected):
                return ItemListCheckboxItem(title: localizedPeerNotificationSoundString(sound), checked: selected, zeroSeparatorInsets: false, sectionId: self.section, action: {
                    arguments.selectSound(sound)
                })
        }
    }
}

private func notificationsAndSoundsEntries(state: NotificationSoundSelectionState) -> [NotificationSoundSelectionEntry] {
    var entries: [NotificationSoundSelectionEntry] = []
    
    entries.append(.modernHeader)
    entries.append(.none(section: .modern, selected: state.selectedSound == .none))
    for i in 0 ..< 12 {
        let sound: PeerMessageSound = .bundledModern(id: Int32(i))
        entries.append(.sound(section: .modern, index: Int32(i), sound: sound, selected: sound == state.selectedSound))
    }
    
    entries.append(.classicHeader)
    for i in 0 ..< 8 {
        let sound: PeerMessageSound = .bundledClassic(id: Int32(i))
        entries.append(.sound(section: .classic, index: Int32(i), sound: sound, selected: sound == state.selectedSound))
    }
    
    return entries
}

public func notificationSoundSelectionController(account: Account, isModal: Bool, currentSound: PeerMessageSound) -> (ViewController, Signal<PeerMessageSound?, NoError>) {
    let statePromise = ValuePromise(NotificationSoundSelectionState(selectedSound: currentSound), ignoreRepeated: true)
    let stateValue = Atomic(value: NotificationSoundSelectionState(selectedSound: currentSound))
    let updateState: ((NotificationSoundSelectionState) -> NotificationSoundSelectionState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var completeImpl: (() -> Void)?
    var cancelImpl: (() -> Void)?
    
    let arguments = NotificationSoundSelectionArguments(account: account, selectSound: { sound in
        updateState { state in
            return NotificationSoundSelectionState(selectedSound: sound)
        }
    }, complete: {
        completeImpl?()
    }, cancel: {
        cancelImpl?()
    })
    
    let leftNavigationButton = ItemListNavigationButton(title: "Cancel", style: .regular, enabled: true, action: {
        arguments.cancel()
    })
    
    let rightNavigationButton = ItemListNavigationButton(title: "Done", style: .bold, enabled: true, action: {
        arguments.complete()
    })
    
    let signal = statePromise.get()
        |> map { state -> (ItemListControllerState, (ItemListNodeState<NotificationSoundSelectionEntry>, NotificationSoundSelectionEntry.ItemGenerationArguments)) in
            
            let controllerState = ItemListControllerState(title: "Text Tone", leftNavigationButton: leftNavigationButton, rightNavigationButton: rightNavigationButton)
            let listState = ItemListNodeState(entries: notificationsAndSoundsEntries(state: state), style: .blocks)
            
            return (controllerState, (listState, arguments))
    }
    
    let controller = ItemListController(signal)
    
    let result = Promise<PeerMessageSound?>()
    
    completeImpl = { [weak controller] in
        let sound = stateValue.with { state in
            return state.selectedSound
        }
        result.set(.single(sound))
        controller?.dismiss()
    }
    
    cancelImpl = { [weak controller] in
        result.set(.single(nil))
        controller?.dismiss()
    }
    
    return (controller, result.get())
}
