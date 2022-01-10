import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import AVFoundation
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext
import TelegramStringFormatting
import AppBundle

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
    case `default`(section: NotificationSoundSelectionSection, theme: PresentationTheme, text: String, selected: Bool)
    case sound(section: NotificationSoundSelectionSection, index: Int32, theme: PresentationTheme, text: String, sound: PeerMessageSound, selected: Bool)
    
    var section: ItemListSectionId {
        switch self {
            case .modernHeader:
                return NotificationSoundSelectionSection.modern.rawValue
            case .classicHeader:
                return NotificationSoundSelectionSection.classic.rawValue
            case let .none(section, _, _, _):
                return section.rawValue
            case let .default(section, _, _, _):
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
                        return 2
                    case .classic:
                        return 1001
                }
            case let .default(section, _, _, _):
                switch section {
                    case .modern:
                        return 1
                    case .classic:
                        return 1002
                }
            case let .sound(section, index, _, _, _, _):
                switch section {
                    case .modern:
                        return 3 + index
                    case .classic:
                        return 1003 + index
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
            case let .default(lhsSection, lhsTheme, lhsText, lhsSelected):
                if case let .default(rhsSection, rhsTheme, rhsText, rhsSelected) = rhs, lhsSection == rhsSection, lhsTheme === rhsTheme, lhsText == rhsText, lhsSelected == rhsSelected {
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
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! NotificationSoundSelectionArguments
        switch self {
            case let.modernHeader(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .classicHeader(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .none(_, _, text, selected):
                return ItemListCheckboxItem(presentationData: presentationData, title: text, style: .left, checked: selected, zeroSeparatorInsets: true, sectionId: self.section, action: {
                    arguments.selectSound(.none)
                })
            case let .default(_, _, text, selected):
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

private func notificationsAndSoundsEntries(presentationData: PresentationData, defaultSound: PeerMessageSound?, state: NotificationSoundSelectionState) -> [NotificationSoundSelectionEntry] {
    var entries: [NotificationSoundSelectionEntry] = []
    
    entries.append(.modernHeader(presentationData.theme, presentationData.strings.Notifications_AlertTones))
    if let defaultSound = defaultSound {
        entries.append(.default(section: .modern, theme: presentationData.theme, text: localizedPeerNotificationSoundString(strings: presentationData.strings, sound: .default, default: defaultSound), selected: state.selectedSound == .default))
    }
    entries.append(.none(section: .modern, theme: presentationData.theme, text: localizedPeerNotificationSoundString(strings: presentationData.strings, sound: .none), selected: state.selectedSound == .none))
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

private final class AudioPlayerWrapper: NSObject, AVAudioPlayerDelegate {
    private let completed: () -> Void
    private var player: AVAudioPlayer?
    
    init(url: URL, completed: @escaping () -> Void) {
        self.completed = completed
        
        super.init()
        
        self.player = try? AVAudioPlayer(contentsOf: url, fileTypeHint: "m4a")
        self.player?.delegate = self
    }
    
    func play() {
        self.player?.play()
    }
    
    func stop() {
        self.player?.stop()
        self.player = nil
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        self.completed()
    }
}

public func fileNameForNotificationSound(_ sound: PeerMessageSound, defaultSound: PeerMessageSound?) -> String {
    switch sound {
        case .none:
            return ""
        case .default:
            if let defaultSound = defaultSound {
                if case .default = defaultSound {
                    return "\(100)"
                } else {
                    return fileNameForNotificationSound(defaultSound, defaultSound: nil)
                }
            } else {
                return "\(100)"
            }
        case let .bundledModern(id):
            return "\(id + 100)"
        case let .bundledClassic(id):
            return "\(id + 2)"
    }
}

public func playSound(context: AccountContext, sound: PeerMessageSound, defaultSound: PeerMessageSound?) -> Signal<Void, NoError> {
    if case .none = sound {
        return .complete()
    } else {
        return Signal { subscriber in
            var currentPlayer: AudioPlayerWrapper?
            var deactivateImpl: (() -> Void)?
            let session = context.sharedContext.mediaManager.audioSession.push(audioSessionType: .play, activate: { _ in
                Queue.mainQueue().async {
                    if let url = getAppBundle().url(forResource: fileNameForNotificationSound(sound, defaultSound: defaultSound), withExtension: "m4a") {
                        currentPlayer = AudioPlayerWrapper(url: url, completed: {
                            deactivateImpl?()
                        })
                        currentPlayer?.play()
                    }
                }
            }, deactivate: { _ in
                return Signal { subscriber in
                    Queue.mainQueue().async {
                        currentPlayer?.stop()
                        currentPlayer = nil
                        subscriber.putCompletion()
                    }
                    return EmptyDisposable
                }
            })
            deactivateImpl = {
                session.dispose()
            }
            return ActionDisposable {
                session.dispose()
                Queue.mainQueue().async {
                    currentPlayer?.stop()
                    currentPlayer = nil
                }
            }
        }
        |> runOn(Queue.mainQueue())
    }
}

public func notificationSoundSelectionController(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, isModal: Bool, currentSound: PeerMessageSound, defaultSound: PeerMessageSound?, completion: @escaping (PeerMessageSound) -> Void) -> ViewController {
    let statePromise = ValuePromise(NotificationSoundSelectionState(selectedSound: currentSound), ignoreRepeated: true)
    let stateValue = Atomic(value: NotificationSoundSelectionState(selectedSound: currentSound))
    let updateState: ((NotificationSoundSelectionState) -> NotificationSoundSelectionState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var completeImpl: (() -> Void)?
    var cancelImpl: (() -> Void)?
    
    let playSoundDisposable = MetaDisposable()
    
    let arguments = NotificationSoundSelectionArguments(account: context.account, selectSound: { sound in
        updateState { state in
            return NotificationSoundSelectionState(selectedSound: sound)
        }
        
        playSoundDisposable.set(playSound(context: context, sound: sound, defaultSound: defaultSound).start())
    }, complete: {
        completeImpl?()
    }, cancel: {
        cancelImpl?()
    })
    
    let presentationData = updatedPresentationData?.signal ?? context.sharedContext.presentationData
    let signal = combineLatest(presentationData, statePromise.get())
    |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState, Any)) in
        
        let leftNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Cancel), style: .regular, enabled: true, action: {
            arguments.cancel()
        })
        
        let rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Done), style: .bold, enabled: true, action: {
            arguments.complete()
        })
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(presentationData.strings.Notifications_TextTone), leftNavigationButton: leftNavigationButton, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: notificationsAndSoundsEntries(presentationData: presentationData, defaultSound: defaultSound, state: state), style: .blocks)
        
        return (controllerState, (listState, arguments))
    }
    
    let controller = ItemListController(context: context, state: signal |> afterDisposed {
        playSoundDisposable.dispose()
    })
    controller.enableInteractiveDismiss = true
    if isModal {
        controller.navigationPresentation = .modal
    }
    
    completeImpl = { [weak controller] in
        let sound = stateValue.with { state in
            return state.selectedSound
        }
        completion(sound)
        controller?.dismiss()
    }
    
    cancelImpl = { [weak controller] in
        controller?.dismiss()
    }
    
    return controller
}
