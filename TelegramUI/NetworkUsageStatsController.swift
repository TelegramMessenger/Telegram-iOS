import Foundation
import Display
import SwiftSignalKit
import Postbox
import TelegramCore

private enum NetworkUsageControllerSection {
    case cellular
    case wifi
}

private final class NetworkUsageStatsControllerArguments {
    let resetStatistics: (NetworkUsageControllerSection) -> Void
    
    init(resetStatistics: @escaping (NetworkUsageControllerSection) -> Void) {
        self.resetStatistics = resetStatistics
    }
}

private enum NetworkUsageStatsSection: Int32 {
    case messages
    case image
    case video
    case audio
    case file
    case call
    case total
    case reset
}

private enum NetworkUsageStatsEntry: ItemListNodeEntry {
    case messagesHeader(String)
    case messagesSent(String, String)
    case messagesReceived(String, String)
    
    case imageHeader(String)
    case imageSent(String, String)
    case imageReceived(String, String)
    
    case videoHeader(String)
    case videoSent(String, String)
    case videoReceived(String, String)
    
    case audioHeader(String)
    case audioSent(String, String)
    case audioReceived(String, String)
    
    case fileHeader(String)
    case fileSent(String, String)
    case fileReceived(String, String)
    
    case callHeader(String)
    case callSent(String, String)
    case callReceived(String, String)
    
    case reset(NetworkUsageControllerSection, String)
    case resetTimestamp(String)
    
    var section: ItemListSectionId {
        switch self {
            case .messagesHeader, .messagesSent, .messagesReceived:
                return NetworkUsageStatsSection.messages.rawValue
            case .imageHeader, .imageSent, .imageReceived:
                return NetworkUsageStatsSection.image.rawValue
            case .videoHeader, .videoSent, .videoReceived:
                return NetworkUsageStatsSection.video.rawValue
            case .audioHeader, .audioSent, .audioReceived:
                return NetworkUsageStatsSection.audio.rawValue
            case .fileHeader, .fileSent, .fileReceived:
                return NetworkUsageStatsSection.file.rawValue
            case .callHeader, .callSent, .callReceived:
                return NetworkUsageStatsSection.call.rawValue
            case .reset, .resetTimestamp:
                return NetworkUsageStatsSection.reset.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
            case .messagesHeader:
                return 0
            case .messagesSent:
                return 1
            case .messagesReceived:
                return 2
            case .imageHeader:
                return 3
            case .imageSent:
                return 4
            case .imageReceived:
                return 5
            case .videoHeader:
                return 6
            case .videoSent:
                return 7
            case .videoReceived:
                return 8
            case .audioHeader:
                return 9
            case .audioSent:
                return 10
            case .audioReceived:
                return 11
            case .fileHeader:
                return 12
            case .fileSent:
                return 13
            case .fileReceived:
                return 14
            case .callHeader:
                return 15
            case .callSent:
                return 16
            case .callReceived:
                return 17
            case .reset:
                return 18
            case .resetTimestamp:
                return 19
        }
    }
    
    static func ==(lhs: NetworkUsageStatsEntry, rhs: NetworkUsageStatsEntry) -> Bool {
        switch lhs {
            case let .messagesHeader(text):
                if case .messagesHeader(text) = rhs {
                    return true
                } else {
                    return false
                }
            case let .messagesSent(text, value):
                if case .messagesSent(text, value) = rhs {
                    return true
                } else {
                    return false
                }
            case let .messagesReceived(text, value):
                if case .messagesReceived(text, value) = rhs {
                    return true
                } else {
                    return false
                }
            case let .imageHeader(text):
                if case .imageHeader(text) = rhs {
                    return true
                } else {
                    return false
                }
            case let .imageSent(text, value):
                if case .imageSent(text, value) = rhs {
                    return true
                } else {
                    return false
                }
            case let .imageReceived(text, value):
                if case .imageReceived(text, value) = rhs {
                    return true
                } else {
                    return false
                }
            case let .videoHeader(text):
                if case .videoHeader(text) = rhs {
                    return true
                } else {
                    return false
                }
            case let .videoSent(text, value):
                if case .videoSent(text, value) = rhs {
                    return true
                } else {
                    return false
                }
            case let .videoReceived(text, value):
                if case .videoReceived(text, value) = rhs {
                    return true
                } else {
                    return false
                }
            case let .audioHeader(text):
                if case .audioHeader(text) = rhs {
                    return true
                } else {
                    return false
                }
            case let .audioSent(text, value):
                if case .audioSent(text, value) = rhs {
                    return true
                } else {
                    return false
                }
            case let .audioReceived(text, value):
                if case .audioReceived(text, value) = rhs {
                    return true
                } else {
                    return false
                }
            case let .fileHeader(text):
                if case .fileHeader(text) = rhs {
                    return true
                } else {
                    return false
                }
            case let .fileSent(text, value):
                if case .fileSent(text, value) = rhs {
                    return true
                } else {
                    return false
                }
            case let .fileReceived(text, value):
                if case .fileReceived(text, value) = rhs {
                    return true
                } else {
                    return false
                }
            case let .callHeader(text):
                if case .callHeader(text) = rhs {
                    return true
                } else {
                    return false
                }
            case let .callSent(text, value):
                if case .callSent(text, value) = rhs {
                    return true
                } else {
                    return false
                }
            case let .callReceived(text, value):
                if case .callReceived(text, value) = rhs {
                    return true
                } else {
                    return false
                }
            case let .reset(section, text):
                if case .reset(section, text) = rhs {
                    return true
                } else {
                    return false
                }
            case let .resetTimestamp(text):
                if case .resetTimestamp(text) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: NetworkUsageStatsEntry, rhs: NetworkUsageStatsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(_ arguments: NetworkUsageStatsControllerArguments) -> ListViewItem {
        switch self {
            case let .messagesHeader(text):
                return ItemListSectionHeaderItem(text: text, sectionId: self.section)
            case let .messagesSent(text, value):
                return ItemListDisclosureItem(title: text, label: value, sectionId: self.section, style: .blocks, disclosureStyle: .none , action: nil)
            case let .messagesReceived(text, value):
                return ItemListDisclosureItem(title: text, label: value, sectionId: self.section, style: .blocks, disclosureStyle: .none , action: nil)
            case let .imageHeader(text):
                return ItemListSectionHeaderItem(text: text, sectionId: self.section)
            case let .imageSent(text, value):
                return ItemListDisclosureItem(title: text, label: value, sectionId: self.section, style: .blocks, disclosureStyle: .none , action: nil)
            case let .imageReceived(text, value):
                return ItemListDisclosureItem(title: text, label: value, sectionId: self.section, style: .blocks, disclosureStyle: .none , action: nil)
            case let .videoHeader(text):
                return ItemListSectionHeaderItem(text: text, sectionId: self.section)
            case let .videoSent(text, value):
                return ItemListDisclosureItem(title: text, label: value, sectionId: self.section, style: .blocks, disclosureStyle: .none , action: nil)
            case let .videoReceived(text, value):
                return ItemListDisclosureItem(title: text, label: value, sectionId: self.section, style: .blocks, disclosureStyle: .none , action: nil)
            case let .audioHeader(text):
                return ItemListSectionHeaderItem(text: text, sectionId: self.section)
            case let .audioSent(text, value):
                return ItemListDisclosureItem(title: text, label: value, sectionId: self.section, style: .blocks, disclosureStyle: .none , action: nil)
            case let .audioReceived(text, value):
                return ItemListDisclosureItem(title: text, label: value, sectionId: self.section, style: .blocks, disclosureStyle: .none , action: nil)
            case let .fileHeader(text):
                return ItemListSectionHeaderItem(text: text, sectionId: self.section)
            case let .fileSent(text, value):
                return ItemListDisclosureItem(title: text, label: value, sectionId: self.section, style: .blocks, disclosureStyle: .none , action: nil)
            case let .fileReceived(text, value):
                return ItemListDisclosureItem(title: text, label: value, sectionId: self.section, style: .blocks, disclosureStyle: .none , action: nil)
            case let .callHeader(text):
                return ItemListSectionHeaderItem(text: text, sectionId: self.section)
            case let .callSent(text, value):
                return ItemListDisclosureItem(title: text, label: value, sectionId: self.section, style: .blocks, disclosureStyle: .none , action: nil)
            case let .callReceived(text, value):
                return ItemListDisclosureItem(title: text, label: value, sectionId: self.section, style: .blocks, disclosureStyle: .none , action: nil)
            case let .reset(section, text):
                return ItemListActionItem(title: text, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                    arguments.resetStatistics(section)
                })
            case let .resetTimestamp(text):
                return ItemListTextItem(text: .plain(text), sectionId: self.section)
        }
    }
}

private func networkUsageStatsControllerEntries(section: NetworkUsageControllerSection, stats: NetworkUsageStats) -> [NetworkUsageStatsEntry] {
    var entries: [NetworkUsageStatsEntry] = []
    
    switch section {
        case .cellular:
            entries.append(.messagesHeader("MESSAGES"))
            entries.append(.messagesSent("Bytes Sent", dataSizeString(Int(stats.generic.cellular.outgoing))))
            entries.append(.messagesReceived("Bytes Received", dataSizeString(Int(stats.generic.cellular.incoming))))
            
            entries.append(.imageHeader("PHOTOS"))
            entries.append(.imageSent("Bytes Sent", dataSizeString(Int(stats.image.cellular.outgoing))))
            entries.append(.imageReceived("Bytes Received", dataSizeString(Int(stats.image.cellular.incoming))))
            
            entries.append(.videoHeader("VIDEOS"))
            entries.append(.videoSent("Bytes Sent", dataSizeString(Int(stats.video.cellular.outgoing))))
            entries.append(.videoReceived("Bytes Received", dataSizeString(Int(stats.video.cellular.incoming))))
            
            entries.append(.audioHeader("AUDIO"))
            entries.append(.audioSent("Bytes Sent", dataSizeString(Int(stats.audio.cellular.outgoing))))
            entries.append(.audioReceived("Bytes Received", dataSizeString(Int(stats.audio.cellular.incoming))))
            
            entries.append(.fileHeader("DOCUMENTS"))
            entries.append(.fileSent("Bytes Sent", dataSizeString(Int(stats.file.cellular.outgoing))))
            entries.append(.fileReceived("Bytes Received", dataSizeString(Int(stats.file.cellular.incoming))))
            
            entries.append(.callHeader("CALLS"))
            entries.append(.callSent("Bytes Sent", dataSizeString(0)))
            entries.append(.callReceived("Bytes Received", dataSizeString(0)))
            
            entries.append(.reset(section, "Reset Statistics"))
        
            if stats.resetCellularTimestamp != 0 {
                let formatter = DateFormatter()
                formatter.dateFormat = "E, d MMM yyyy HH:mm"
                let dateStringPlain = formatter.string(from: Date(timeIntervalSince1970: Double(stats.resetCellularTimestamp)))
                
                entries.append(.resetTimestamp("Cellular usage since \(dateStringPlain)"))
            }
        case .wifi:
            entries.append(.messagesHeader("MESSAGES"))
            entries.append(.messagesSent("Bytes Sent", dataSizeString(Int(stats.generic.wifi.outgoing))))
            entries.append(.messagesReceived("Bytes Received", dataSizeString(Int(stats.generic.wifi.incoming))))
            
            entries.append(.imageHeader("PHOTOS"))
            entries.append(.imageSent("Bytes Sent", dataSizeString(Int(stats.image.wifi.outgoing))))
            entries.append(.imageReceived("Bytes Received", dataSizeString(Int(stats.image.wifi.incoming))))
            
            entries.append(.videoHeader("VIDEOS"))
            entries.append(.videoSent("Bytes Sent", dataSizeString(Int(stats.video.wifi.outgoing))))
            entries.append(.videoReceived("Bytes Received", dataSizeString(Int(stats.video.wifi.incoming))))
            
            entries.append(.audioHeader("AUDIO"))
            entries.append(.audioSent("Bytes Sent", dataSizeString(Int(stats.audio.wifi.outgoing))))
            entries.append(.audioReceived("Bytes Received", dataSizeString(Int(stats.audio.wifi.incoming))))
            
            entries.append(.fileHeader("DOCUMENTS"))
            entries.append(.fileSent("Bytes Sent", dataSizeString(Int(stats.file.wifi.outgoing))))
            entries.append(.fileReceived("Bytes Received", dataSizeString(Int(stats.file.wifi.incoming))))
            
            entries.append(.callHeader("CALLS"))
            entries.append(.callSent("Bytes Sent", dataSizeString(0)))
            entries.append(.callReceived("Bytes Received", dataSizeString(0)))
            
            entries.append(.reset(section, "Reset Statistics"))
            if stats.resetWifiTimestamp != 0 {
                let formatter = DateFormatter()
                formatter.dateFormat = "E, d MMM yyyy HH:mm"
                let dateStringPlain = formatter.string(from: Date(timeIntervalSince1970: Double(stats.resetWifiTimestamp)))
                
                entries.append(.resetTimestamp("Wifi usage since \(dateStringPlain)"))
            }
    }
    
    return entries
}

func networkUsageStatsController(account: Account) -> ViewController {
    let section = ValuePromise<NetworkUsageControllerSection>(.cellular)
    let stats = Promise<NetworkUsageStats>()
    stats.set(accountNetworkUsageStats(account: account, reset: []))
    
    var presentControllerImpl: ((ViewController) -> Void)?
    
    let arguments = NetworkUsageStatsControllerArguments(resetStatistics: { [weak stats] section in
        let controller = ActionSheetController()
        let dismissAction: () -> Void = { [weak controller] in
            controller?.dismissAnimated()
        }
        controller.setItemGroups([
            ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: "Reset Statistics", color: .destructive, action: {
                    dismissAction()
                    
                    let reset: ResetNetworkUsageStats
                    switch section {
                        case .wifi:
                            reset = .wifi
                        case .cellular:
                            reset = .cellular
                    }
                    stats?.set(accountNetworkUsageStats(account: account, reset: reset))
                }),
            ]),
            ActionSheetItemGroup(items: [ActionSheetButtonItem(title: "Cancel", action: { dismissAction() })])
        ])
        presentControllerImpl?(controller)
    })
    
    let signal = combineLatest(section.get(), stats.get()) |> deliverOnMainQueue
        |> map { section, stats -> (ItemListControllerState, (ItemListNodeState<NetworkUsageStatsEntry>, NetworkUsageStatsEntry.ItemGenerationArguments)) in
            
            let controllerState = ItemListControllerState(title: .sectionControl(["Cellular", "Wifi"], 0), leftNavigationButton: nil, rightNavigationButton: nil, animateChanges: false)
            let listState = ItemListNodeState(entries: networkUsageStatsControllerEntries(section: section, stats: stats), style: .blocks, emptyStateItem: nil, animateChanges: false)
            
            return (controllerState, (listState, arguments))
    }
    
    let controller = ItemListController(signal)
    controller.navigationItem.backBarButtonItem = UIBarButtonItem(title: "Back", style: .plain, target: nil, action: nil)
    
    controller.titleControlValueChanged = { [weak section] index in
        section?.set(index == 0 ? .cellular : .wifi)
    }
    
    presentControllerImpl = { [weak controller] c in
        controller?.present(c, in: .window, with: ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
    }
    
    return controller
}
