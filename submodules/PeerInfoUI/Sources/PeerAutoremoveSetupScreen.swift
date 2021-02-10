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
import ChatListFilterSettingsHeaderItem

private final class PeerAutoremoveSetupArguments {
    let toggleGlobal: (Bool) -> Void
    let updateValue: (Int32) -> Void
    
    init(toggleGlobal: @escaping (Bool) -> Void, updateValue: @escaping (Int32) -> Void) {
        self.toggleGlobal = toggleGlobal
        self.updateValue = updateValue
    }
}

private enum PeerAutoremoveSetupSection: Int32 {
    case header
    case time
    case global
}

private enum PeerAutoremoveSetupEntry: ItemListNodeEntry {
    case header
    case timeHeader(String)
    case timeValue(Int32, Int32, [Int32])
    case timeComment(String)
    case globalSwitch(String, Bool, Bool)
    
    var section: ItemListSectionId {
        switch self {
        case .header, .timeHeader, .timeValue, .timeComment:
            return PeerAutoremoveSetupSection.time.rawValue
        case .globalSwitch:
            return PeerAutoremoveSetupSection.global.rawValue
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
        case .globalSwitch:
            return 4
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
        case let .timeValue(lhsValue, lhsMaxValue, lhsAvailableValues):
            if case let .timeValue(rhsValue, rhsMaxValue, rhsAvailableValues) = rhs, lhsValue == rhsValue, lhsMaxValue == rhsMaxValue, lhsAvailableValues == rhsAvailableValues {
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
        case let .globalSwitch(lhsText, lhsValue, lhsEnable):
            if case let .globalSwitch(rhsText, rhsValue, rhsEnable) = rhs, lhsText == rhsText, lhsValue == rhsValue, lhsEnable == rhsEnable {
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
            return ChatListFilterSettingsHeaderItem(theme: presentationData.theme, text: "", animation: .autoRemove, sectionId: self.section)
        case let .timeHeader(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .timeValue(value, maxValue, availableValues):
            return PeerRemoveTimeoutItem(presentationData: presentationData, value: value, maxValue: maxValue, availableValues: availableValues, enabled: true, sectionId: self.section, updated: { value in
                arguments.updateValue(value)
            }, tag: nil)
        case let .timeComment(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case let .globalSwitch(text, value, enabled):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, enabled: enabled, maximumNumberOfLines: 2, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggleGlobal(value)
            })
        }
    }
}

private struct PeerAutoremoveSetupState: Equatable {
    var changedValue: Int32?
    var changedGlobalValue: Bool?
    var applyingSetting: Bool = false
}

private func peerAutoremoveSetupEntries(peer: Peer?, presentationData: PresentationData, isDebug: Bool, defaultMyValue: Int32, peerValue: Int32, defaultGlobalValue: Bool, state: PeerAutoremoveSetupState) -> [PeerAutoremoveSetupEntry] {
    var entries: [PeerAutoremoveSetupEntry] = []
    let globalValue = state.changedGlobalValue ?? defaultGlobalValue
    
    let resolvedValue: Int32
    let resolvedMaxValue: Int32
    
    if peer is TelegramUser {
        resolvedValue = state.changedValue ?? defaultMyValue
        resolvedMaxValue = peerValue
    } else {
        resolvedValue = state.changedValue ?? peerValue
        resolvedMaxValue = Int32.max
    }
    
    //TODO:localize
    entries.append(.header)
    entries.append(.timeHeader("AUTO-DELETE MESSAGES"))
    
    var availableValues: [Int32] = [
        24 * 60 * 60,
        24 * 60 * 60 * 7,
        Int32.max
    ]
    if isDebug || true {
        availableValues[0] = 60
        availableValues[1] = 5 * 60
    }
    entries.append(.timeValue(resolvedValue, resolvedMaxValue, availableValues))
    if let channel = peer as? TelegramChannel, case .broadcast = channel.info {
        entries.append(.timeComment("Automatically delete messages sent in this channel after a certain period of time."))
    } else {
        if resolvedMaxValue != Int32.max {
            entries.append(.timeComment("\(peer?.compactDisplayTitle ?? "") has set messages to auto-delete in \(timeIntervalString(strings: presentationData.strings, value: resolvedMaxValue)). You can't cancel it or make this interval longer."))
        } else {
            entries.append(.timeComment("Automatically delete messages sent in this chat after a certain period of time."))
        }
    }
    if let user = peer as? TelegramUser {
        entries.append(.globalSwitch("Also auto-delete for \(user.compactDisplayTitle)", globalValue, resolvedValue != Int32.max))
    }
    
    return entries
}

public enum PeerAutoremoveSetupScreenResult {
    public struct Updated {
        public var myValue: Int32?
        public var limitedByValue: Int32?
    }
    
    case unchanged
    case updated(Updated)
}

public func peerAutoremoveSetupScreen(context: AccountContext, peerId: PeerId, completion: @escaping (PeerAutoremoveSetupScreenResult) -> Void = { _ in }) -> ViewController {
    let statePromise = ValuePromise(PeerAutoremoveSetupState(), ignoreRepeated: true)
    let stateValue = Atomic(value: PeerAutoremoveSetupState())
    let updateState: ((PeerAutoremoveSetupState) -> PeerAutoremoveSetupState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var pushControllerImpl: ((ViewController) -> Void)?
    var dismissImpl: (() -> Void)?
    
    let actionsDisposable = DisposableSet()
    
    let applyDisposable = MetaDisposable()
    actionsDisposable.add(applyDisposable)
    
    let arguments = PeerAutoremoveSetupArguments(toggleGlobal: { value in
        updateState { state in
            var state = state
            state.changedGlobalValue = value
            return state
        }
    }, updateValue: { value in
        updateState { state in
            var state = state
            state.changedValue = value
            return state
        }
    })
    
    let signal = combineLatest(context.sharedContext.presentationData, statePromise.get(), context.account.viewTracker.peerView(peerId))
    |> deliverOnMainQueue
    |> map { presentationData, state, view -> (ItemListControllerState, (ItemListNodeState, Any)) in
        var defaultMyValue: Int32 = Int32.max
        var peerValue: Int32 = Int32.max
        var defaultGlobalValue = true
        if let cachedData = view.cachedData as? CachedChannelData {
            if case let .known(value) = cachedData.autoremoveTimeout {
                defaultMyValue = value?.myValue ?? Int32.max
                peerValue = value?.peerValue ?? Int32.max
                defaultGlobalValue = value?.isGlobal ?? true
            }
        } else if let cachedData = view.cachedData as? CachedGroupData {
            if case let .known(value) = cachedData.autoremoveTimeout {
                defaultMyValue = value?.myValue ?? Int32.max
                peerValue = value?.peerValue ?? Int32.max
                defaultGlobalValue = value?.isGlobal ?? true
            }
        } else if let cachedData = view.cachedData as? CachedUserData {
            if case let .known(value) = cachedData.autoremoveTimeout {
                defaultMyValue = value?.myValue ?? Int32.max
                peerValue = value?.peerValue ?? Int32.max
                defaultGlobalValue = value?.isGlobal ?? true
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
                var globalValue: Bool?
                updateState { state in
                    var state = state
                    state.applyingSetting = true
                    changedValue = state.changedValue
                    globalValue = state.changedGlobalValue
                    return state
                }
                
                let resolvedDefaultValue: Int32
                if peer is TelegramUser {
                    resolvedDefaultValue = defaultMyValue
                } else {
                    resolvedDefaultValue = peerValue
                }
                
                var updated = false
                if let changedValue = changedValue, changedValue != resolvedDefaultValue {
                    updated = true
                }
                if let globalValue = globalValue, globalValue != defaultGlobalValue {
                    updated = true
                }
                if updated {
                    var resolvedValue: Int32? = changedValue ?? resolvedDefaultValue
                    if resolvedValue == Int32.max {
                        resolvedValue = nil
                    }
                    
                    let resolvedMaxValue: Int32
                    if peer is TelegramUser {
                        resolvedMaxValue = peerValue
                    } else {
                        resolvedMaxValue = Int32.max
                    }
                    
                    let resolvedGlobalValue = globalValue ?? defaultGlobalValue
                    
                    let signal = setChatMessageAutoremoveTimeoutInteractively(account: context.account, peerId: peerId, timeout: resolvedValue, isGlobal: resolvedGlobalValue)
                    |> deliverOnMainQueue
                    
                    applyDisposable.set((signal
                    |> deliverOnMainQueue).start(error: { _ in
                    }, completed: {
                        dismissImpl?()
                        if resolvedValue != resolvedDefaultValue {
                            completion(.updated(PeerAutoremoveSetupScreenResult.Updated(
                                myValue: resolvedValue,
                                limitedByValue: resolvedMaxValue == Int32.max ? nil : resolvedMaxValue
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
        
        //TODO:localize
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text("Auto-Deletion"), leftNavigationButton: leftNavigationButton, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: peerAutoremoveSetupEntries(peer: peer, presentationData: presentationData, isDebug: isDebug, defaultMyValue: defaultMyValue, peerValue: peerValue, defaultGlobalValue: defaultGlobalValue, state: state), style: .blocks)
        
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
    pushControllerImpl = { [weak controller] c in
        controller?.push(c)
    }
    return controller
}
