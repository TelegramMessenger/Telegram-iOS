import Foundation
import Display
import SwiftSignalKit
import Postbox
import TelegramCore

private final class VoiceCallDataSavingControllerArguments {
    let updateSelection: (VoiceCallDataSaving) -> Void
    
    init(updateSelection: @escaping (VoiceCallDataSaving) -> Void) {
        self.updateSelection = updateSelection
    }
}

private enum VoiceCallDataSavingSection: Int32 {
    case dataSaving
}

private enum VoiceCallDataSavingEntry: ItemListNodeEntry {
    case never(String, Bool)
    case cellular(String, Bool)
    case always(String, Bool)
    case info(String)
    
    var section: ItemListSectionId {
        return VoiceCallDataSavingSection.dataSaving.rawValue
    }
    
    var stableId: Int32 {
        switch self {
            case .never:
                return 0
            case .cellular:
                return 1
            case .always:
                return 2
            case .info:
                return 3
        }
    }
    
    static func ==(lhs: VoiceCallDataSavingEntry, rhs: VoiceCallDataSavingEntry) -> Bool {
        switch lhs {
            case let .never(text, value):
                if case .never(text, value) = rhs {
                    return true
                } else {
                    return false
                }
            case let .cellular(text, value):
                if case .cellular(text, value) = rhs {
                    return true
                } else {
                    return false
                }
            case let .always(text, value):
                if case .always(text, value) = rhs {
                    return true
                } else {
                    return false
                }
            case let .info(text):
                if case .info(text) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: VoiceCallDataSavingEntry, rhs: VoiceCallDataSavingEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(_ arguments: VoiceCallDataSavingControllerArguments) -> ListViewItem {
        switch self {
            case let .never(text, value):
                return ItemListCheckboxItem(title: text, checked: value, zeroSeparatorInsets: false, sectionId: self.section, action: {
                    arguments.updateSelection(.never)
                })
            case let .cellular(text, value):
                return ItemListCheckboxItem(title: text, checked: value, zeroSeparatorInsets: false, sectionId: self.section, action: {
                    arguments.updateSelection(.cellular)
                })
            case let .always(text, value):
                return ItemListCheckboxItem(title: text, checked: value, zeroSeparatorInsets: false, sectionId: self.section, action: {
                    arguments.updateSelection(.always)
                })
            case let .info(text):
                return ItemListTextItem(text: .plain(text), sectionId: self.section)
        }
    }
}

private func stringForDataSavingOption(_ option: VoiceCallDataSaving) -> String {
    switch option {
        case .never:
            return "Never"
        case .cellular:
            return "On Mobile Network"
        case .always:
            return "Always"
    }
}

private func voiceCallDataSavingControllerEntries(settings: VoiceCallSettings) -> [VoiceCallDataSavingEntry] {
    var entries: [VoiceCallDataSavingEntry] = []
    
    entries.append(.never(stringForDataSavingOption(.never), settings.dataSaving == .never))
    entries.append(.cellular(stringForDataSavingOption(.cellular), settings.dataSaving == .cellular))
    entries.append(.always(stringForDataSavingOption(.always), settings.dataSaving == .always))
    entries.append(.info("Using less data may improve your experience on bad networks, but will slightly decrease audio quality."))
    
    return entries
}

func voiceCallDataSavingController(account: Account) -> ViewController {
    let voiceCallSettingsPromise = Promise<VoiceCallSettings>()
    voiceCallSettingsPromise.set(account.postbox.preferencesView(keys: [ApplicationSpecificPreferencesKeys.voiceCallSettings])
        |> map { view -> VoiceCallSettings in
            let voiceCallSettings: VoiceCallSettings
            if let value = view.values[ApplicationSpecificPreferencesKeys.voiceCallSettings] as? VoiceCallSettings {
                voiceCallSettings = value
            } else {
                voiceCallSettings = VoiceCallSettings.defaultSettings
            }
            
            return voiceCallSettings
        })
    
    let arguments = VoiceCallDataSavingControllerArguments(updateSelection: { option in
        let _ = updateVoiceCallSettingsSettingsInteractively(postbox: account.postbox, { current in
            return current.withUpdatedDataSaving(option)
        }).start()
    })
    
    let signal = voiceCallSettingsPromise.get() |> deliverOnMainQueue
        |> map { data -> (ItemListControllerState, (ItemListNodeState<VoiceCallDataSavingEntry>, VoiceCallDataSavingEntry.ItemGenerationArguments)) in
            
            let controllerState = ItemListControllerState(title: .text("Use Less Data"), leftNavigationButton: nil, rightNavigationButton: nil, animateChanges: false)
            let listState = ItemListNodeState(entries: voiceCallDataSavingControllerEntries(settings: data), style: .blocks, emptyStateItem: nil, animateChanges: false)
            
            return (controllerState, (listState, arguments))
        }
    
    let controller = ItemListController(signal)
    controller.navigationItem.backBarButtonItem = UIBarButtonItem(title: "Back", style: .plain, target: nil, action: nil)
    
    return controller
}
