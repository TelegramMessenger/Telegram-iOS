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
import LegacyMediaPickerUI
import AVFoundation
import UndoUI

private struct NotificationSoundSelectionArguments {
    let account: Account
    
    let selectSound: (PeerMessageSound) -> Void
    let complete: () -> Void
    let cancel: () -> Void
    let upload: () -> Void
    let deleteSound: (PeerMessageSound) -> Void
}

private enum NotificationSoundSelectionSection: Int32 {
    case cloud
    case modern
    case classic
}

private struct NotificationSoundSelectionState: Equatable {
    var selectedSound: PeerMessageSound
    var removedSounds: [PeerMessageSound]
}

private enum NotificationSoundSelectionEntry: ItemListNodeEntry {
    enum StableId: Hashable {
        case index(Int32)
        case sound(PeerMessageSound.Id)
    }
    
    case cloudHeader(String)
    case uploadSound(String)
    case cloudInfo(String)
    
    case modernHeader(PresentationTheme, String)
    case classicHeader(PresentationTheme, String)
    case none(section: NotificationSoundSelectionSection, theme: PresentationTheme, text: String, selected: Bool)
    case `default`(section: NotificationSoundSelectionSection, theme: PresentationTheme, text: String, selected: Bool)
    case sound(section: NotificationSoundSelectionSection, index: Int32, theme: PresentationTheme, text: String, sound: PeerMessageSound, selected: Bool, canBeDeleted: Bool)
    
    var section: ItemListSectionId {
        switch self {
            case .cloudHeader, .uploadSound, .cloudInfo:
                return NotificationSoundSelectionSection.cloud.rawValue
            case .modernHeader:
                return NotificationSoundSelectionSection.modern.rawValue
            case .classicHeader:
                return NotificationSoundSelectionSection.classic.rawValue
            case let .none(section, _, _, _):
                return section.rawValue
            case let .default(section, _, _, _):
                return section.rawValue
            case let .sound(section, _, _, _, _, _, _):
                return section.rawValue
        }
    }
    
    var sortId: Int32 {
        switch self {
        case .cloudHeader:
            return 0
        case .uploadSound:
            return 998
        case .cloudInfo:
            return 999
        case .modernHeader:
            return 1000
        case .classicHeader:
            return 2000
        case let .none(section, _, _, _):
            switch section {
            case .cloud:
                return 1
            case .modern:
                return 1001
            case .classic:
                return 2001
            }
        case let .default(section, _, _, _):
            switch section {
            case .cloud:
                return 2
            case .modern:
                return 1002
            case .classic:
                return 2002
            }
        case let .sound(section, index, _, _, _, _, _):
            switch section {
            case .cloud:
                return 3 + index
            case .modern:
                return 1003 + index
            case .classic:
                return 2003 + index
            }
        }
    }
    
    var stableId: StableId {
        switch self {
        case let .sound(_ , _, _, _, sound, _, _):
            return .sound(sound.id)
        default:
            return .index(self.sortId)
        }
    }
    
    static func ==(lhs: NotificationSoundSelectionEntry, rhs: NotificationSoundSelectionEntry) -> Bool {
        switch lhs {
        case let .cloudHeader(text):
            if case .cloudHeader(text) = rhs {
                return true
            } else {
                return false
            }
        case let .cloudInfo(text):
            if case .cloudInfo(text) = rhs {
                return true
            } else {
                return false
            }
        case let .uploadSound(text):
            if case .uploadSound(text) = rhs {
                return true
            } else {
                return false
            }
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
        case let .sound(lhsSection, lhsIndex, lhsTheme, lhsText, lhsSound, lhsSelected, lhsCanBeDeleted):
            if case let .sound(rhsSection, rhsIndex, rhsTheme, rhsText, rhsSound, rhsSelected, rhsCanBeDeleted) = rhs, lhsSection == rhsSection, lhsIndex == rhsIndex, lhsTheme === rhsTheme, lhsText == rhsText, lhsSound == rhsSound, lhsSelected == rhsSelected, lhsCanBeDeleted == rhsCanBeDeleted {
                return true
            } else {
                return false
            }
        }
    }
    
    static func <(lhs: NotificationSoundSelectionEntry, rhs: NotificationSoundSelectionEntry) -> Bool {
        return lhs.sortId < rhs.sortId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! NotificationSoundSelectionArguments
        switch self {
        case let .cloudHeader(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .uploadSound(text):
            let icon = PresentationResourcesItemList.uploadToneIcon(presentationData.theme)
            return ItemListCheckboxItem(presentationData: presentationData, icon: icon, iconSize: nil, iconPlacement: .check, title: text, style: .left, textColor: .accent, checked: false, zeroSeparatorInsets: false, sectionId: self.section, action: {
                arguments.upload()
            })
        case let .cloudInfo(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case let .modernHeader(_, text):
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
        case let .sound(_, _, _, text, sound, selected, canBeDeleted):
            return ItemListCheckboxItem(presentationData: presentationData, title: text, style: .left, checked: selected, zeroSeparatorInsets: false, sectionId: self.section, action: {
                arguments.selectSound(sound)
            }, deleteAction: canBeDeleted ? {
                arguments.deleteSound(sound)
            } : nil)
        }
    }
}

private func notificationsAndSoundsEntries(presentationData: PresentationData, defaultSound: PeerMessageSound?, state: NotificationSoundSelectionState, notificationSoundList: NotificationSoundList?) -> [NotificationSoundSelectionEntry] {
    let selectedSound = resolvedNotificationSound(sound: state.selectedSound, notificationSoundList: notificationSoundList)
    
    var entries: [NotificationSoundSelectionEntry] = []
    
    entries.append(.cloudHeader(presentationData.strings.Notifications_TelegramTones))
    //entries.append(.none(section: .cloud, theme: presentationData.theme, text: localizedPeerNotificationSoundString(strings: presentationData.strings, notificationSoundList: notificationSoundList, sound: .none), selected: selectedSound == .none))
    if let notificationSoundList = notificationSoundList {
        for listSound in notificationSoundList.sounds {
            let sound: PeerMessageSound = .cloud(fileId: listSound.file.fileId.id)
            if state.removedSounds.contains(where: { $0.id == sound.id }) {
                continue
            }
            entries.append(.sound(section: .cloud, index: Int32(entries.count), theme: presentationData.theme, text: localizedPeerNotificationSoundString(strings: presentationData.strings, notificationSoundList: notificationSoundList, sound: sound), sound: sound, selected: selectedSound.id == sound.id, canBeDeleted: true))
        }
    }
    entries.append(.uploadSound(presentationData.strings.Notifications_UploadSound))
    entries.append(.cloudInfo(presentationData.strings.Notifications_MessageSoundInfo))
    
    entries.append(.modernHeader(presentationData.theme, presentationData.strings.Notifications_AlertTones))
    if let defaultSound = defaultSound {
        entries.append(.default(section: .modern, theme: presentationData.theme, text: localizedPeerNotificationSoundString(strings: presentationData.strings, notificationSoundList: notificationSoundList, sound: .default, default: defaultSound), selected: selectedSound.id == .default))
    }
    entries.append(.none(section: .modern, theme: presentationData.theme, text: localizedPeerNotificationSoundString(strings: presentationData.strings, notificationSoundList: notificationSoundList, sound: .none), selected: selectedSound.id == .none))
    for i in 0 ..< 12 {
        let sound: PeerMessageSound = .bundledModern(id: Int32(i))
        entries.append(.sound(section: .modern, index: Int32(i), theme: presentationData.theme, text: localizedPeerNotificationSoundString(strings: presentationData.strings, notificationSoundList: notificationSoundList, sound: sound), sound: sound, selected: sound.id == selectedSound.id, canBeDeleted: false))
    }
    
    entries.append(.classicHeader(presentationData.theme, presentationData.strings.Notifications_ClassicTones))
    for i in 0 ..< 8 {
        let sound: PeerMessageSound = .bundledClassic(id: Int32(i))
        entries.append(.sound(section: .classic, index: Int32(i), theme: presentationData.theme, text: localizedPeerNotificationSoundString(strings: presentationData.strings, notificationSoundList: notificationSoundList, sound: sound), sound: sound, selected: sound.id == selectedSound.id, canBeDeleted: false))
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

public func fileNameForNotificationSound(account: Account, notificationSoundList: NotificationSoundList?, sound: PeerMessageSound, defaultSound: PeerMessageSound?) -> String {
    switch sound {
    case .none:
        return ""
    case .default:
        if let defaultSound = defaultSound {
            if case .default = defaultSound {
                return "\(100)"
            } else {
                return fileNameForNotificationSound(account: account, notificationSoundList: notificationSoundList, sound: defaultSound, defaultSound: nil)
            }
        } else {
            return "\(100)"
        }
    case let .bundledModern(id):
        return "\(id + 100)"
    case let .bundledClassic(id):
        return "\(id + 2)"
    case let .cloud(fileId):
        guard let notificationSoundList = notificationSoundList else {
            return ""
        }
        for sound in notificationSoundList.sounds {
            if sound.file.fileId.id == fileId {
                if let path = account.postbox.mediaBox.completedResourcePath(sound.file.resource, pathExtension: "mp3") {
                    return path
                }
            }
        }
        return ""
    }
}

public func playSound(context: AccountContext, notificationSoundList: NotificationSoundList?, sound: PeerMessageSound, defaultSound: PeerMessageSound?) -> Signal<Void, NoError> {
    if case .none = sound {
        return .complete()
    } else {
        return Signal { subscriber in
            var currentPlayer: AudioPlayerWrapper?
            var deactivateImpl: (() -> Void)?
            let session = context.sharedContext.mediaManager.audioSession.push(audioSessionType: .play, activate: { _ in
                Queue.mainQueue().async {
                    let filePath = fileNameForNotificationSound(account: context.account, notificationSoundList: notificationSoundList, sound: sound, defaultSound: defaultSound)
                    
                    if filePath.contains("/") {
                        currentPlayer = AudioPlayerWrapper(url: URL(fileURLWithPath: filePath), completed: {
                            deactivateImpl?()
                        })
                        currentPlayer?.play()
                    } else {
                        if let url = getAppBundle().url(forResource: filePath, withExtension: "m4a") {
                            currentPlayer = AudioPlayerWrapper(url: url, completed: {
                                deactivateImpl?()
                            })
                            currentPlayer?.play()
                        }
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
    let statePromise = ValuePromise(NotificationSoundSelectionState(selectedSound: currentSound, removedSounds: []), ignoreRepeated: true)
    let stateValue = Atomic(value: NotificationSoundSelectionState(selectedSound: currentSound, removedSounds: []))
    let updateState: ((NotificationSoundSelectionState) -> NotificationSoundSelectionState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var completeImpl: (() -> Void)?
    var cancelImpl: (() -> Void)?
    var presentFilePicker: (() -> Void)?
    
    let playSoundDisposable = MetaDisposable()
    let soundActionDisposable = MetaDisposable()
    
    let arguments = NotificationSoundSelectionArguments(account: context.account, selectSound: { sound in
        updateState { state in
            var state = state
            
            state.selectedSound = sound
            
            return state
        }
        
        let _ = (context.engine.peers.notificationSoundList()
        |> take(1)
        |> deliverOnMainQueue).start(next: { notificationSoundList in
            playSoundDisposable.set(playSound(context: context, notificationSoundList: notificationSoundList, sound: sound, defaultSound: defaultSound).start())
        })
    }, complete: {
        completeImpl?()
    }, cancel: {
        cancelImpl?()
    }, upload: {
        presentFilePicker?()
    }, deleteSound: { sound in
        updateState { state in
            var state = state
            
            state.removedSounds.append(sound)
            if state.selectedSound.id == sound.id {
                state.selectedSound = .bundledModern(id: 0)
            }
            
            return state
        }
        switch sound {
        case let .cloud(id):
            soundActionDisposable.set((context.engine.peers.deleteNotificationSound(fileId: id)
            |> deliverOnMainQueue).start(completed: {
            }))
        default:
            break
        }
    })
    
    let presentationData = updatedPresentationData?.signal ?? context.sharedContext.presentationData
    let signal = combineLatest(presentationData, statePromise.get(), context.engine.peers.notificationSoundList())
    |> map { presentationData, state, notificationSoundList -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let leftNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Cancel), style: .regular, enabled: true, action: {
            arguments.cancel()
        })
        
        let rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Done), style: .bold, enabled: true, action: {
            arguments.complete()
        })
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(presentationData.strings.Notifications_TextTone), leftNavigationButton: leftNavigationButton, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: notificationsAndSoundsEntries(presentationData: presentationData, defaultSound: defaultSound, state: state, notificationSoundList: notificationSoundList), style: .blocks)
        
        return (controllerState, (listState, arguments))
    }
    
    let controller = ItemListController(context: context, state: signal |> afterDisposed {
        playSoundDisposable.dispose()
        soundActionDisposable.dispose()
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
    
    presentFilePicker = { [weak controller] in
        guard let controller = controller else {
            return
        }
        presentCustomNotificationSoundFilePicker(context: context, controller: controller, disposable: soundActionDisposable)
    }
    
    return controller
}

public func presentCustomNotificationSoundFilePicker(context: AccountContext, controller: ViewController, disposable: MetaDisposable) {
    let presentUndo: (UndoOverlayContent) -> Void = { [weak controller] content in
        guard let controller = controller else {
            return
        }
        
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        controller.present(UndoOverlayController(presentationData: presentationData, content: content, elevatedLayout: false, animateInAsReplacement: true, action: { _ in return false }), in: .current)
    }
    
    let settings = NotificationSoundSettings.extract(from: context.currentAppConfiguration.with({ $0 }))
    
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    controller.present(legacyICloudFilePicker(theme: presentationData.theme, documentTypes: ["public.mp3"], completion: { urls in
        guard !urls.isEmpty, let url = urls.first else {
            return
        }
        
        if !url.startAccessingSecurityScopedResource() {
            Logger.shared.log("NotificationSoundSelection", "startAccessingSecurityScopedResource failed")
            return
        }
        
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var error: NSError?
        coordinator.coordinate(readingItemAt: url, options: .forUploading, error: &error, byAccessor: { url in
            Queue.mainQueue().async {
                do {
                    let asset = AVAsset(url: url)
                    
                    let data = try Data(contentsOf: url)
                    
                    if data.count > settings.maxSize {
                        //TODO:localize
                        presentUndo(.info(title: "Audio is too large", text: "The file is over \(dataSizeString(Int64(settings.maxSize), formatting: DataSizeStringFormatting(presentationData: presentationData)))."))
                        
                        url.stopAccessingSecurityScopedResource()
                        
                        return
                    }
                    
                    asset.loadValuesAsynchronously(forKeys: ["tracks", "duration"], completionHandler: {
                        if asset.statusOfValue(forKey: "duration", error: nil) != .loaded {
                            url.stopAccessingSecurityScopedResource()
                            
                            return
                        }
                        guard let track = asset.tracks(withMediaType: .audio).first else {
                            url.stopAccessingSecurityScopedResource()
                            
                            return
                        }
                        let duration = track.timeRange.duration.seconds
                        
                        Queue.mainQueue().async {
                            if duration > Double(settings.maxDuration) {
                                url.stopAccessingSecurityScopedResource()
                                
                                //TODO:localize
                                presentUndo(.info(title: "\(url.lastPathComponent) is too long", text: "The duration is longer than \(stringForDuration(Int32(settings.maxDuration)))."))
                            } else {
                                disposable.set((context.engine.peers.uploadNotificationSound(title: url.lastPathComponent, data: data)
                                |> deliverOnMainQueue).start(next: { _ in
                                    //TODO:localize
                                    presentUndo(.notificationSoundAdded(title: "Sound Added", text: "The sound **\(url.deletingPathExtension().lastPathComponent)** was added to your Telegram tones.**", action: nil))
                                }, error: { _ in
                                    url.stopAccessingSecurityScopedResource()
                                }, completed: {
                                    url.stopAccessingSecurityScopedResource()
                                }))
                            }
                        }
                    })
                } catch let e {
                    Logger.shared.log("NotificationSoundSelection", "Error: \(e)")
                }
            }
        })
        
        if let error = error {
            url.stopAccessingSecurityScopedResource()
            Logger.shared.log("NotificationSoundSelection", "Error: \(error)")
        }
    }), in: .window(.root))
}
