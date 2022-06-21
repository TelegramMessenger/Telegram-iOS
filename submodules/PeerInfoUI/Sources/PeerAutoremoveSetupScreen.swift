import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext
import ChatListFilterSettingsHeaderItem

private final class PeerAutoremoveSetupArguments {
    let context: AccountContext
    let updateValue: (Int32) -> Void
    
    init(context: AccountContext, updateValue: @escaping (Int32) -> Void) {
        self.context = context
        self.updateValue = updateValue
    }
}

private enum PeerAutoremoveSetupSection: Int32 {
    case header
    case time
}

private enum PeerAutoremoveSetupEntry: ItemListNodeEntry {
    case header
    case timeHeader(String)
    case timeValue(Int32, [Int32])
    case timeComment(String)
    
    var section: ItemListSectionId {
        switch self {
        case .header, .timeHeader, .timeValue, .timeComment:
            return PeerAutoremoveSetupSection.time.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
        case .header:
            return 0
        case .timeHeader:
            return 1
        case .timeValue:
            return 2
        case .timeComment:
            return 3
        }
    }
    
    static func ==(lhs: PeerAutoremoveSetupEntry, rhs: PeerAutoremoveSetupEntry) -> Bool {
        switch lhs {
        case .header:
            if case .header = rhs {
                return true
            } else {
                return false
            }
        case let .timeHeader(lhsText):
            if case let .timeHeader(rhsText) = rhs, lhsText == rhsText {
                return true
            } else {
                return false
            }
        case let .timeValue(lhsValue, lhsAvailableValues):
            if case let .timeValue(rhsValue, rhsAvailableValues) = rhs, lhsValue == rhsValue, lhsAvailableValues == rhsAvailableValues {
                return true
            } else {
                return false
            }
        case let .timeComment(lhsText):
            if case let .timeComment(rhsText) = rhs, lhsText == rhsText {
                return true
            } else {
                return false
            }
        }
    }
    
    static func <(lhs: PeerAutoremoveSetupEntry, rhs: PeerAutoremoveSetupEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! PeerAutoremoveSetupArguments
        switch self {
        case .header:
            return ChatListFilterSettingsHeaderItem(context: arguments.context, theme: presentationData.theme, text: "", animation: .autoRemove, sectionId: self.section)
        case let .timeHeader(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .timeValue(value, availableValues):
            return PeerRemoveTimeoutItem(presentationData: presentationData, value: value, availableValues: availableValues, enabled: true, sectionId: self.section, updated: { value in
                arguments.updateValue(value)
            }, tag: nil)
        case let .timeComment(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

private struct PeerAutoremoveSetupState: Equatable {
    var changedValue: Int32?
    var applyingSetting: Bool = false
}

private func peerAutoremoveSetupEntries(peer: Peer?, presentationData: PresentationData, isDebug: Bool, defaultValue: Int32, state: PeerAutoremoveSetupState) -> [PeerAutoremoveSetupEntry] {
    var entries: [PeerAutoremoveSetupEntry] = []
    
    let resolvedValue: Int32
    
    resolvedValue = state.changedValue ?? defaultValue
    
    entries.append(.header)
    entries.append(.timeHeader(presentationData.strings.AutoremoveSetup_TimeSectionHeader))
    
    var availableValues: [Int32] = [
        Int32.max,
        24 * 60 * 60,
        24 * 60 * 60 * 7,
        24 * 60 * 60 * 31,
    ]
    if isDebug {
        availableValues[1] = 5
        availableValues[2] = 5 * 60
    }
    entries.append(.timeValue(resolvedValue, availableValues))
    if let channel = peer as? TelegramChannel, case .broadcast = channel.info {
        entries.append(.timeComment(presentationData.strings.AutoremoveSetup_TimerInfoChannel))
    } else {
        entries.append(.timeComment(presentationData.strings.AutoremoveSetup_TimerInfoChat))
    }
    
    return entries
}

public enum PeerAutoremoveSetupScreenResult {
    public struct Updated {
        public var value: Int32?
    }
    
    case unchanged
    case updated(Updated)
}

public func peerAutoremoveSetupScreen(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, peerId: PeerId, completion: @escaping (PeerAutoremoveSetupScreenResult) -> Void = { _ in }) -> ViewController {
    let statePromise = ValuePromise(PeerAutoremoveSetupState(), ignoreRepeated: true)
    let stateValue = Atomic(value: PeerAutoremoveSetupState())
    let updateState: ((PeerAutoremoveSetupState) -> PeerAutoremoveSetupState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var dismissImpl: (() -> Void)?
    
    let actionsDisposable = DisposableSet()
    
    let applyDisposable = MetaDisposable()
    actionsDisposable.add(applyDisposable)
    
    let arguments = PeerAutoremoveSetupArguments(context: context, updateValue: { value in
        updateState { state in
            var state = state
            state.changedValue = value
            return state
        }
    })
    
    let presentationData = updatedPresentationData?.signal ?? context.sharedContext.presentationData
    let signal = combineLatest(presentationData, statePromise.get(), context.account.viewTracker.peerView(peerId))
    |> deliverOnMainQueue
    |> map { presentationData, state, view -> (ItemListControllerState, (ItemListNodeState, Any)) in
        var defaultValue: Int32 = Int32.max
        if let cachedData = view.cachedData as? CachedChannelData {
            if case let .known(value) = cachedData.autoremoveTimeout {
                defaultValue = value?.peerValue ?? Int32.max
            }
        } else if let cachedData = view.cachedData as? CachedGroupData {
            if case let .known(value) = cachedData.autoremoveTimeout {
                defaultValue = value?.peerValue ?? Int32.max
            }
        } else if let cachedData = view.cachedData as? CachedUserData {
            if case let .known(value) = cachedData.autoremoveTimeout {
                defaultValue = value?.peerValue ?? Int32.max
            }
        }
        
        let peer = view.peers[view.peerId]
        
        let leftNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Cancel), style: .regular, enabled: true, action: {
            dismissImpl?()
        })
        var rightNavigationButton: ItemListNavigationButton?
        if state.applyingSetting {
            rightNavigationButton = ItemListNavigationButton(content: .none, style: .activity, enabled: true, action: {})
        } else {
            rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Done), style: .bold, enabled: true, action: {
                var changedValue: Int32?
                updateState { state in
                    var state = state
                    state.applyingSetting = true
                    changedValue = state.changedValue
                    return state
                }
                
                var updated = false
                if let changedValue = changedValue, changedValue != defaultValue {
                    updated = true
                }
                
                var resolvedValue: Int32? = changedValue ?? defaultValue
                if resolvedValue == Int32.max {
                    resolvedValue = nil
                }
                
                if updated {
                    let signal = context.engine.peers.setChatMessageAutoremoveTimeoutInteractively(peerId: peerId, timeout: resolvedValue)
                    |> deliverOnMainQueue
                    
                    applyDisposable.set((signal
                    |> deliverOnMainQueue).start(error: { _ in
                    }, completed: {
                        dismissImpl?()
                        if resolvedValue != defaultValue {
                            completion(.updated(PeerAutoremoveSetupScreenResult.Updated(
                                value: resolvedValue
                            )))
                        } else {
                            completion(.unchanged)
                        }
                    }))
                } else {
                    dismissImpl?()
                    completion(.unchanged)
                }
            })
        }
        
        let isDebug = context.account.testingEnvironment
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(presentationData.strings.AutoremoveSetup_Title), leftNavigationButton: leftNavigationButton, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: peerAutoremoveSetupEntries(peer: peer, presentationData: presentationData, isDebug: isDebug, defaultValue: defaultValue, state: state), style: .blocks)
        
        return (controllerState, (listState, arguments))
    }
    |> afterDisposed {
        actionsDisposable.dispose()
    }
    
    let controller = ItemListController(context: context, state: signal)
    controller.navigationPresentation = .modal
    dismissImpl = { [weak controller] in
        controller?.view.endEditing(true)
        controller?.dismiss()
    }
    return controller
}
