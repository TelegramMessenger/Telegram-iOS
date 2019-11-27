import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import SyncCore
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext

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
    case messagesHeader(PresentationTheme, String)
    case messagesSent(PresentationTheme, String, String)
    case messagesReceived(PresentationTheme, String, String)
    
    case imageHeader(PresentationTheme, String)
    case imageSent(PresentationTheme, String, String)
    case imageReceived(PresentationTheme, String, String)
    
    case videoHeader(PresentationTheme, String)
    case videoSent(PresentationTheme, String, String)
    case videoReceived(PresentationTheme, String, String)
    
    case audioHeader(PresentationTheme, String)
    case audioSent(PresentationTheme, String, String)
    case audioReceived(PresentationTheme, String, String)
    
    case fileHeader(PresentationTheme, String)
    case fileSent(PresentationTheme, String, String)
    case fileReceived(PresentationTheme, String, String)
    
    case callHeader(PresentationTheme, String)
    case callSent(PresentationTheme, String, String)
    case callReceived(PresentationTheme, String, String)
    
    case reset(PresentationTheme, NetworkUsageControllerSection, String)
    case resetTimestamp(PresentationTheme, String)
    
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
            case let .messagesHeader(lhsTheme, lhsText):
                if case let .messagesHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .messagesSent(lhsTheme, lhsText, lhsValue):
                if case let .messagesSent(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .messagesReceived(lhsTheme, lhsText, lhsValue):
                if case let .messagesReceived(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .imageHeader(lhsTheme, lhsText):
                if case let .imageHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .imageSent(lhsTheme, lhsText, lhsValue):
                if case let .imageSent(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .imageReceived(lhsTheme, lhsText, lhsValue):
                if case let .imageReceived(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .videoHeader(lhsTheme, lhsText):
                if case let .videoHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .videoSent(lhsTheme, lhsText, lhsValue):
                if case let .videoSent(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .videoReceived(lhsTheme, lhsText, lhsValue):
                if case let .videoReceived(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .audioHeader(lhsTheme, lhsText):
                if case let .audioHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .audioSent(lhsTheme, lhsText, lhsValue):
                if case let .audioSent(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .audioReceived(lhsTheme, lhsText, lhsValue):
                if case let .audioReceived(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .fileHeader(lhsTheme, lhsText):
                if case let .fileHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .fileSent(lhsTheme, lhsText, lhsValue):
                if case let .fileSent(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .fileReceived(lhsTheme, lhsText, lhsValue):
                if case let .fileReceived(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .callHeader(lhsTheme, lhsText):
                if case let .callHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .callSent(lhsTheme, lhsText, lhsValue):
                if case let .callSent(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .callReceived(lhsTheme, lhsText, lhsValue):
                if case let .callReceived(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .reset(lhsTheme, lhsSection, lhsText):
                if case let .reset(rhsTheme, rhsSection, rhsText) = rhs, lhsTheme === rhsTheme, lhsSection == rhsSection, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .resetTimestamp(lhsTheme, lhsText):
                if case let .resetTimestamp(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: NetworkUsageStatsEntry, rhs: NetworkUsageStatsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! NetworkUsageStatsControllerArguments
        switch self {
            case let .messagesHeader(theme, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .messagesSent(theme, text, value):
                return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, sectionId: self.section, style: .blocks, disclosureStyle: .none , action: nil)
            case let .messagesReceived(theme, text, value):
                return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, sectionId: self.section, style: .blocks, disclosureStyle: .none , action: nil)
            case let .imageHeader(theme, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .imageSent(theme, text, value):
                return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, sectionId: self.section, style: .blocks, disclosureStyle: .none , action: nil)
            case let .imageReceived(theme, text, value):
                return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, sectionId: self.section, style: .blocks, disclosureStyle: .none , action: nil)
            case let .videoHeader(theme, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .videoSent(theme, text, value):
                return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, sectionId: self.section, style: .blocks, disclosureStyle: .none , action: nil)
            case let .videoReceived(theme, text, value):
                return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, sectionId: self.section, style: .blocks, disclosureStyle: .none , action: nil)
            case let .audioHeader(theme, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .audioSent(theme, text, value):
                return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, sectionId: self.section, style: .blocks, disclosureStyle: .none , action: nil)
            case let .audioReceived(theme, text, value):
                return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, sectionId: self.section, style: .blocks, disclosureStyle: .none , action: nil)
            case let .fileHeader(theme, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .fileSent(theme, text, value):
                return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, sectionId: self.section, style: .blocks, disclosureStyle: .none , action: nil)
            case let .fileReceived(theme, text, value):
                return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, sectionId: self.section, style: .blocks, disclosureStyle: .none , action: nil)
            case let .callHeader(theme, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .callSent(theme, text, value):
                return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, sectionId: self.section, style: .blocks, disclosureStyle: .none , action: nil)
            case let .callReceived(theme, text, value):
                return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, sectionId: self.section, style: .blocks, disclosureStyle: .none , action: nil)
            case let .reset(theme, section, text):
                return ItemListActionItem(presentationData: presentationData, title: text, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                    arguments.resetStatistics(section)
                })
            case let .resetTimestamp(theme, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

private func networkUsageStatsControllerEntries(presentationData: PresentationData, section: NetworkUsageControllerSection, stats: NetworkUsageStats) -> [NetworkUsageStatsEntry] {
    var entries: [NetworkUsageStatsEntry] = []
    
    switch section {
        case .cellular:
            entries.append(.messagesHeader(presentationData.theme, presentationData.strings.NetworkUsageSettings_GeneralDataSection))
            entries.append(.messagesSent(presentationData.theme, presentationData.strings.NetworkUsageSettings_BytesSent, dataSizeString(stats.generic.cellular.outgoing, decimalSeparator: presentationData.dateTimeFormat.decimalSeparator)))
            entries.append(.messagesReceived(presentationData.theme, presentationData.strings.NetworkUsageSettings_BytesReceived, dataSizeString(stats.generic.cellular.incoming, decimalSeparator: presentationData.dateTimeFormat.decimalSeparator)))
            
            entries.append(.imageHeader(presentationData.theme, presentationData.strings.NetworkUsageSettings_MediaImageDataSection))
            entries.append(.imageSent(presentationData.theme, presentationData.strings.NetworkUsageSettings_BytesSent, dataSizeString(stats.image.cellular.outgoing, decimalSeparator: presentationData.dateTimeFormat.decimalSeparator)))
            entries.append(.imageReceived(presentationData.theme, presentationData.strings.NetworkUsageSettings_BytesReceived, dataSizeString(stats.image.cellular.incoming, decimalSeparator: presentationData.dateTimeFormat.decimalSeparator)))
            
            entries.append(.videoHeader(presentationData.theme, presentationData.strings.NetworkUsageSettings_MediaVideoDataSection))
            entries.append(.videoSent(presentationData.theme, presentationData.strings.NetworkUsageSettings_BytesSent, dataSizeString(stats.video.cellular.outgoing, decimalSeparator: presentationData.dateTimeFormat.decimalSeparator)))
            entries.append(.videoReceived(presentationData.theme, presentationData.strings.NetworkUsageSettings_BytesReceived, dataSizeString(stats.video.cellular.incoming, decimalSeparator: presentationData.dateTimeFormat.decimalSeparator)))
            
            entries.append(.audioHeader(presentationData.theme, presentationData.strings.NetworkUsageSettings_MediaAudioDataSection))
            entries.append(.audioSent(presentationData.theme, presentationData.strings.NetworkUsageSettings_BytesSent, dataSizeString(stats.audio.cellular.outgoing, decimalSeparator: presentationData.dateTimeFormat.decimalSeparator)))
            entries.append(.audioReceived(presentationData.theme, presentationData.strings.NetworkUsageSettings_BytesReceived, dataSizeString(stats.audio.cellular.incoming, decimalSeparator: presentationData.dateTimeFormat.decimalSeparator)))
            
            entries.append(.fileHeader(presentationData.theme, presentationData.strings.NetworkUsageSettings_MediaDocumentDataSection))
            entries.append(.fileSent(presentationData.theme, presentationData.strings.NetworkUsageSettings_BytesSent, dataSizeString(stats.file.cellular.outgoing, decimalSeparator: presentationData.dateTimeFormat.decimalSeparator)))
            entries.append(.fileReceived(presentationData.theme, presentationData.strings.NetworkUsageSettings_BytesReceived, dataSizeString(stats.file.cellular.incoming, decimalSeparator: presentationData.dateTimeFormat.decimalSeparator)))
            
            entries.append(.callHeader(presentationData.theme, presentationData.strings.NetworkUsageSettings_CallDataSection))
            entries.append(.callSent(presentationData.theme, presentationData.strings.NetworkUsageSettings_BytesSent, dataSizeString(stats.call.cellular.outgoing, decimalSeparator: presentationData.dateTimeFormat.decimalSeparator)))
            entries.append(.callReceived(presentationData.theme, presentationData.strings.NetworkUsageSettings_BytesReceived, dataSizeString(stats.call.cellular.incoming, decimalSeparator: presentationData.dateTimeFormat.decimalSeparator)))
            
            entries.append(.reset(presentationData.theme, section, presentationData.strings.NetworkUsageSettings_ResetStats))
        
            if stats.resetCellularTimestamp != 0 {
                let formatter = DateFormatter()
                formatter.dateFormat = "E, d MMM yyyy HH:mm"
                let dateStringPlain = formatter.string(from: Date(timeIntervalSince1970: Double(stats.resetCellularTimestamp)))
                
                entries.append(.resetTimestamp(presentationData.theme, presentationData.strings.NetworkUsageSettings_CellularUsageSince(dateStringPlain).0))
            }
        case .wifi:
            entries.append(.messagesHeader(presentationData.theme, presentationData.strings.NetworkUsageSettings_GeneralDataSection))
            entries.append(.messagesSent(presentationData.theme, presentationData.strings.NetworkUsageSettings_BytesSent, dataSizeString(stats.generic.wifi.outgoing, decimalSeparator: presentationData.dateTimeFormat.decimalSeparator)))
            entries.append(.messagesReceived(presentationData.theme, presentationData.strings.NetworkUsageSettings_BytesReceived, dataSizeString(stats.generic.wifi.incoming, decimalSeparator: presentationData.dateTimeFormat.decimalSeparator)))
            
            entries.append(.imageHeader(presentationData.theme, presentationData.strings.NetworkUsageSettings_MediaImageDataSection))
            entries.append(.imageSent(presentationData.theme, presentationData.strings.NetworkUsageSettings_BytesSent, dataSizeString(stats.image.wifi.outgoing, decimalSeparator: presentationData.dateTimeFormat.decimalSeparator)))
            entries.append(.imageReceived(presentationData.theme, presentationData.strings.NetworkUsageSettings_BytesReceived, dataSizeString(stats.image.wifi.incoming, decimalSeparator: presentationData.dateTimeFormat.decimalSeparator)))
            
            entries.append(.videoHeader(presentationData.theme, presentationData.strings.NetworkUsageSettings_MediaVideoDataSection))
            entries.append(.videoSent(presentationData.theme, presentationData.strings.NetworkUsageSettings_BytesSent, dataSizeString(stats.video.wifi.outgoing, decimalSeparator: presentationData.dateTimeFormat.decimalSeparator)))
            entries.append(.videoReceived(presentationData.theme, presentationData.strings.NetworkUsageSettings_BytesReceived, dataSizeString(stats.video.wifi.incoming, decimalSeparator: presentationData.dateTimeFormat.decimalSeparator)))
            
            entries.append(.audioHeader(presentationData.theme, presentationData.strings.NetworkUsageSettings_MediaAudioDataSection))
            entries.append(.audioSent(presentationData.theme, presentationData.strings.NetworkUsageSettings_BytesSent, dataSizeString(stats.audio.wifi.outgoing, decimalSeparator: presentationData.dateTimeFormat.decimalSeparator)))
            entries.append(.audioReceived(presentationData.theme, presentationData.strings.NetworkUsageSettings_BytesReceived, dataSizeString(stats.audio.wifi.incoming, decimalSeparator: presentationData.dateTimeFormat.decimalSeparator)))
            
            entries.append(.fileHeader(presentationData.theme, presentationData.strings.NetworkUsageSettings_MediaDocumentDataSection))
            entries.append(.fileSent(presentationData.theme, presentationData.strings.NetworkUsageSettings_BytesSent, dataSizeString(stats.file.wifi.outgoing, decimalSeparator: presentationData.dateTimeFormat.decimalSeparator)))
            entries.append(.fileReceived(presentationData.theme, presentationData.strings.NetworkUsageSettings_BytesReceived, dataSizeString(stats.file.wifi.incoming, decimalSeparator: presentationData.dateTimeFormat.decimalSeparator)))
            
            entries.append(.callHeader(presentationData.theme, presentationData.strings.NetworkUsageSettings_CallDataSection))
            entries.append(.callSent(presentationData.theme, presentationData.strings.NetworkUsageSettings_BytesSent, dataSizeString(stats.call.wifi.outgoing, decimalSeparator: presentationData.dateTimeFormat.decimalSeparator)))
            entries.append(.callReceived(presentationData.theme, presentationData.strings.NetworkUsageSettings_BytesReceived, dataSizeString(stats.call.wifi.incoming, decimalSeparator: presentationData.dateTimeFormat.decimalSeparator)))
            
            entries.append(.reset(presentationData.theme, section, presentationData.strings.NetworkUsageSettings_ResetStats))
            if stats.resetWifiTimestamp != 0 {
                let formatter = DateFormatter()
                formatter.dateFormat = "E, d MMM yyyy HH:mm"
                let dateStringPlain = formatter.string(from: Date(timeIntervalSince1970: Double(stats.resetWifiTimestamp)))
                
                entries.append(.resetTimestamp(presentationData.theme, presentationData.strings.NetworkUsageSettings_WifiUsageSince(dateStringPlain).0))
            }
    }
    
    return entries
}

func networkUsageStatsController(context: AccountContext) -> ViewController {
    let section = ValuePromise<NetworkUsageControllerSection>(.cellular)
    let stats = Promise<NetworkUsageStats>()
    stats.set(accountNetworkUsageStats(account: context.account, reset: []))
    
    var presentControllerImpl: ((ViewController) -> Void)?
    
    let arguments = NetworkUsageStatsControllerArguments(resetStatistics: { [weak stats] section in
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let controller = ActionSheetController(presentationData: presentationData)
        let dismissAction: () -> Void = { [weak controller] in
            controller?.dismissAnimated()
        }
        controller.setItemGroups([
            ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: presentationData.strings.NetworkUsageSettings_ResetStats, color: .destructive, action: {
                    dismissAction()
                    
                    let reset: ResetNetworkUsageStats
                    switch section {
                        case .wifi:
                            reset = .wifi
                        case .cellular:
                            reset = .cellular
                    }
                    stats?.set(accountNetworkUsageStats(account: context.account, reset: reset))
                }),
            ]),
            ActionSheetItemGroup(items: [ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, action: { dismissAction() })])
        ])
        presentControllerImpl?(controller)
    })
    
    let signal = combineLatest(context.sharedContext.presentationData, section.get(), stats.get()) |> deliverOnMainQueue
        |> map { presentationData, section, stats -> (ItemListControllerState, (ItemListNodeState, Any)) in
            
            let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .sectionControl([presentationData.strings.NetworkUsageSettings_Cellular, presentationData.strings.NetworkUsageSettings_Wifi], 0), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: false)
            let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: networkUsageStatsControllerEntries(presentationData: presentationData, section: section, stats: stats), style: .blocks, emptyStateItem: nil, animateChanges: false)
            
            return (controllerState, (listState, arguments))
    }
    
    let controller = ItemListController(context: context, state: signal)
    controller.titleControlValueChanged = { [weak section] index in
        section?.set(index == 0 ? .cellular : .wifi)
    }
    
    presentControllerImpl = { [weak controller] c in
        controller?.present(c, in: .window(.root), with: ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
    }
    
    return controller
}
