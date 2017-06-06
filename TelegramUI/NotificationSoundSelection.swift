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
    case modernHeader(PresentationTheme, String)
    case classicHeader(PresentationTheme, String)
    case none(section: NotificationSoundSelectionSection, theme: PresentationTheme, text: String, selected: Bool)
    case sound(section: NotificationSoundSelectionSection, index: Int32, theme: PresentationTheme, text: String, sound: PeerMessageSound, selected: Bool)
    
    var section: ItemListSectionId {
        switch self {
            case .modernHeader:
                return NotificationSoundSelectionSection.modern.rawValue
            case .classicHeader:
                return NotificationSoundSelectionSection.classic.rawValue
            case let .none(section, _, _, _):
                return section.rawValue
            case let .sound(section, _, _, _, _, _):
                return section.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
            case .modernHeader:
                return 0
            case .classicHeader:
                return 1000
            case let .none(section, _, _, _):
                switch section {
                    case .modern:
                        return 1
                    case .classic:
                        return 1001
                }
            case let .sound(section, index, _, _, _, _):
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
            case let .modernHeader(lhsTheme, lhsText):
                if case let .modernHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .classicHeader(lhsTheme, lhsText):
                if case let .classicHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .none(lhsSection, lhsTheme, lhsText, lhsSelected):
                if case let .none(rhsSection, rhsTheme, rhsText, rhsSelected) = rhs, lhsSection == rhsSection, lhsTheme === rhsTheme, lhsText == rhsText, lhsSelected == rhsSelected {
                    return true
                } else {
                    return false
                }
            case let .sound(lhsSection, lhsIndex, lhsTheme, lhsText, lhsSound, lhsSelected):
                if case let .sound(rhsSection, rhsIndex, rhsTheme, rhsText, rhsSound, rhsSelected) = rhs, lhsSection == rhsSection, lhsIndex == rhsIndex, lhsTheme === rhsTheme, lhsText == rhsText, lhsSound == rhsSound, lhsSelected == rhsSelected {
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
            case let.modernHeader(theme, text):
                return ItemListSectionHeaderItem(theme: theme, text: text, sectionId: self.section)
            case let .classicHeader(theme, text):
                return ItemListSectionHeaderItem(theme: theme, text: text, sectionId: self.section)
            case let .none(_, theme, text, selected):
                return ItemListCheckboxItem(theme: theme, title: text, checked: selected, zeroSeparatorInsets: true, sectionId: self.section, action: {
                    arguments.selectSound(.none)
                })
            case let .sound(_, _, theme, text, sound, selected):
                return ItemListCheckboxItem(theme: theme, title: text, checked: selected, zeroSeparatorInsets: false, sectionId: self.section, action: {
                    arguments.selectSound(sound)
                })
        }
    }
}

private func notificationsAndSoundsEntries(presentationData: PresentationData, state: NotificationSoundSelectionState) -> [NotificationSoundSelectionEntry] {
    var entries: [NotificationSoundSelectionEntry] = []
    
    entries.append(.modernHeader(presentationData.theme, presentationData.strings.Notifications_AlertTones))
    entries.append(.none(section: .modern, theme: presentationData.theme, text: "None", selected: state.selectedSound == .none))
    for i in 0 ..< 12 {
        let sound: PeerMessageSound = .bundledModern(id: Int32(i))
        entries.append(.sound(section: .modern, index: Int32(i), theme: presentationData.theme, text: localizedPeerNotificationSoundString(strings: presentationData.strings, sound: sound), sound: sound, selected: sound == state.selectedSound))
    }
    
    entries.append(.classicHeader(presentationData.theme, presentationData.strings.Notifications_ClassicTones))
    for i in 0 ..< 8 {
        let sound: PeerMessageSound = .bundledClassic(id: Int32(i))
        entries.append(.sound(section: .classic, index: Int32(i), theme: presentationData.theme, text: localizedPeerNotificationSoundString(strings: presentationData.strings, sound: sound), sound: sound, selected: sound == state.selectedSound))
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
    
    let signal = combineLatest((account.applicationContext as! TelegramApplicationContext).presentationData, statePromise.get())
        |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState<NotificationSoundSelectionEntry>, NotificationSoundSelectionEntry.ItemGenerationArguments)) in
            
            let leftNavigationButton = ItemListNavigationButton(title: presentationData.strings.Common_Cancel, style: .regular, enabled: true, action: {
                arguments.cancel()
            })
            
            let rightNavigationButton = ItemListNavigationButton(title: presentationData.strings.Common_Done, style: .bold, enabled: true, action: {
                arguments.complete()
            })
            
            let controllerState = ItemListControllerState(theme: presentationData.theme, title: .text(presentationData.strings.Notifications_TextTone), leftNavigationButton: leftNavigationButton, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
            let listState = ItemListNodeState(entries: notificationsAndSoundsEntries(presentationData: presentationData, state: state), style: .blocks)
            
            return (controllerState, (listState, arguments))
        }
    
    let controller = ItemListController(account: account, state: signal)
    
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
