import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import PresentationDataUtils
import AccountContext
import AuthTransferUI
import ItemListPeerActionItem
import DeviceAccess
import QrCodeUI
import ChatTimerScreen
import UndoUI

private final class GlobalAutoremoveScreenArguments {
    let context: AccountContext
    let updateValue: (Int32) -> Void
    let openCustomValue: () -> Void
    let infoLinkAction: () -> Void
    
    init(
        context: AccountContext,
        updateValue: @escaping (Int32) -> Void,
        openCustomValue: @escaping () -> Void,
        infoLinkAction: @escaping () -> Void
    ) {
        self.context = context
        self.updateValue = updateValue
        self.openCustomValue = openCustomValue
        self.infoLinkAction = infoLinkAction
    }
}

private enum GlobalAutoremoveSection: Int32 {
    case header
    case general
}

private enum GlobalAutoremoveEntry: ItemListNodeEntry {
    case header
    case sectionHeader(String)
    case timerOption(value: Int32, text: String, isSelected: Bool)
    case customAction(String)
    case info(String)
    
    var section: ItemListSectionId {
        switch self {
        case .header:
            return GlobalAutoremoveSection.header.rawValue
        case .sectionHeader, .timerOption, .customAction, .info:
            return GlobalAutoremoveSection.general.rawValue
        }
    }
    
    var stableId: Int {
        return self.sortIndex
    }

    var sortIndex: Int {
        switch self {
        case .header:
            return 0
        case .sectionHeader:
            return 1
        case let .timerOption(value, _, _):
            return 1000 + Int(value)
        case .customAction:
            return Int.max - 1000 + 0
        case .info:
            return Int.max - 1000 + 1
        }
    }
    
    static func ==(lhs: GlobalAutoremoveEntry, rhs: GlobalAutoremoveEntry) -> Bool {
        switch lhs {
        case .header:
            if case .header = rhs {
                return true
            } else {
                return false
            }
        case let .sectionHeader(text):
            if case .sectionHeader(text) = rhs {
                return true
            } else {
                return false
            }
        case let .timerOption(value, text, isSelected):
            if case .timerOption(value, text, isSelected) = rhs {
                return true
            } else {
                return false
            }
        case let .customAction(text):
            if case .customAction(text) = rhs {
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
    
    static func <(lhs: GlobalAutoremoveEntry, rhs: GlobalAutoremoveEntry) -> Bool {
        return lhs.sortIndex < rhs.sortIndex
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! GlobalAutoremoveScreenArguments
        switch self {
        case .header:
            return GlobalAutoremoveHeaderItem(context: arguments.context, theme: presentationData.theme, sectionId: self.section)
        case let .sectionHeader(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .timerOption(value, text, isSelected):
            return ItemListCheckboxItem(presentationData: presentationData, title: text, style: .right, checked: isSelected, zeroSeparatorInsets: false, sectionId: self.section, action: {
                arguments.updateValue(value)
            })
        case let .customAction(text):
            return ItemListActionItem(presentationData: presentationData, title: text, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.openCustomValue()
            })
        case let .info(text):
            return ItemListTextItem(presentationData: presentationData, text: .markdown(text), sectionId: self.section, linkAction: { _ in
                arguments.infoLinkAction()
            })
        }
    }
}

private struct GlobalAutoremoveScreenState: Equatable {
    var additionalValues: Set<Int32>
    var updatedValue: Int32
}

private func globalAutoremoveScreenEntries(presentationData: PresentationData, state: GlobalAutoremoveScreenState) -> [GlobalAutoremoveEntry] {
    var entries: [GlobalAutoremoveEntry] = []
    
    entries.append(.header)
    
    let effectiveCurrentValue = state.updatedValue
    
    entries.append(.sectionHeader(presentationData.strings.GlobalAutodeleteSettings_OptionsHeader))
    
    var values: [Int32] = [
        0,
        1 * 24 * 60 * 60,
        7 * 24 * 60 * 60,
        31 * 24 * 60 * 60
    ]
    
    if !values.contains(effectiveCurrentValue) {
        values.append(effectiveCurrentValue)
    }
    for value in state.additionalValues {
        if !values.contains(value) {
            values.append(value)
        }
    }
    
    values.sort()
    
    for value in values {
        let text: String
        if value == 0 {
            text = presentationData.strings.Autoremove_OptionOff
        } else {
            text = presentationData.strings.GlobalAutodeleteSettings_OptionTitle(timeIntervalString(strings: presentationData.strings, value: value, usage: .afterTime)).string
        }
        entries.append(.timerOption(value: value, text: text, isSelected: effectiveCurrentValue == value))
    }
    
    entries.append(.customAction(presentationData.strings.GlobalAutodeleteSettings_SetCustomTime))
    
    if effectiveCurrentValue == 0 {
        entries.append(.info(presentationData.strings.GlobalAutodeleteSettings_InfoDisabled))
    } else {
        entries.append(.info(presentationData.strings.GlobalAutodeleteSettings_InfoEnabled(timeIntervalString(strings: presentationData.strings, value: effectiveCurrentValue, usage: .afterTime)).string))
    }
    
    return entries
}

public func globalAutoremoveScreen(context: AccountContext, initialValue: Int32, updated: @escaping (Int32) -> Void) -> ViewController {
    let initialState = GlobalAutoremoveScreenState(
        additionalValues: Set([initialValue]),
        updatedValue: initialValue
    )
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((GlobalAutoremoveScreenState) -> GlobalAutoremoveScreenState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var presentControllerImpl: ((ViewController, ViewControllerPresentationArguments?) -> Void)?
    var presentInCurrentControllerImpl: ((ViewController) -> Void)?
    var pushControllerImpl: ((ViewController) -> Void)?
    var dismissImpl: (() -> Void)?
    var getController: (() -> ViewController?)?
    
    let _ = dismissImpl
    let _ = pushControllerImpl
    let _ = presentControllerImpl
    let _ = updateState
    
    let actionsDisposable = DisposableSet()
    
    let updateTimeoutDisposable = MetaDisposable()
    actionsDisposable.add(updateTimeoutDisposable)
    
    let updateValue: (Int32) -> Void = { timeout in
        let apply: (Int32) -> Void = { timeout in
            updateState { state in
                var state = state
                state.updatedValue = timeout
                if timeout != 0 {
                    state.additionalValues.removeAll()
                    state.additionalValues.insert(timeout)
                }
                return state
            }
            
            let presentationData = context.sharedContext.currentPresentationData.with({ $0 })
            
            var isOn: Bool = true
            var text: String?
            if timeout != 0 {
                text = presentationData.strings.GlobalAutodeleteSettings_SetConfirmToastEnabled(timeIntervalString(strings: presentationData.strings, value: timeout, usage: .afterTime)).string
            } else {
                isOn = false
                text = presentationData.strings.GlobalAutodeleteSettings_SetConfirmToastDisabled
            }
            if let text = text {
                var animateAsReplacement = false
                if let window = getController?()?.window {
                    window.forEachController { other in
                        if let other = other as? UndoOverlayController {
                            animateAsReplacement = true
                            other.dismiss()
                        }
                    }
                }
                if let current = getController?() {
                    current.forEachController { other in
                        if let other = other as? UndoOverlayController {
                            animateAsReplacement = true
                            other.dismiss()
                        }
                        return true
                    }
                }
                presentInCurrentControllerImpl?(UndoOverlayController(presentationData: presentationData, content: .autoDelete(isOn: isOn, title: nil, text: text), elevatedLayout: false, animateInAsReplacement: animateAsReplacement, action: { _ in return false }))
            }
            
            updateTimeoutDisposable.set((context.engine.privacy.updateGlobalMessageRemovalTimeout(timeout: timeout == 0 ? nil : timeout)
            |> deliverOnMainQueue).start(completed: {
                updated(timeout)
            }))
        }
        if timeout == 0 || stateValue.with({ $0 }).updatedValue != 0 {
            apply(timeout)
        } else {
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            let valueText = timeIntervalString(strings: presentationData.strings, value: timeout, usage: .afterTime)
            presentControllerImpl?(standardTextAlertController(
                theme: AlertControllerTheme(presentationData: presentationData),
                title: presentationData.strings.GlobalAutodeleteSettings_SetConfirmTitle,
                text: presentationData.strings.GlobalAutodeleteSettings_SetConfirmText(valueText).string,
                actions: [
                    TextAlertAction(type: .defaultAction, title: presentationData.strings.GlobalAutodeleteSettings_SetConfirmAction, action: {
                        apply(timeout)
                    }),
                    TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {})
                ],
                actionLayout: .vertical
            ), nil)
        }
    }
    
    let arguments = GlobalAutoremoveScreenArguments(
        context: context,
        updateValue: { value in
            updateValue(value)
        },
        openCustomValue: {
            let currentValue = stateValue.with({ $0 }).updatedValue
            let controller = ChatTimerScreen(context: context, updatedPresentationData: nil, style: .default, mode: .autoremove, currentTime: currentValue == 0 ? nil : currentValue, dismissByTapOutside: true, completion: { value in
                updateValue(value)
            })
            presentControllerImpl?(controller, nil)
        },
        infoLinkAction: {
            let value = stateValue.with({ $0 }).updatedValue
            if value == 0 {
                return
            }
            
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            let valueText = timeIntervalString(strings: presentationData.strings, value: value, usage: .timer)
            
            let selectionController = context.sharedContext.makeContactMultiselectionController(ContactMultiselectionControllerParams(
                context: context,
                mode: .chatSelection(ContactMultiselectionControllerMode.ChatSelection(
                    title: presentationData.strings.GlobalAutodeleteSettings_ApplyChatsTitle,
                    searchPlaceholder: presentationData.strings.GlobalAutodeleteSettings_ApplyChatsPlaceholder(valueText).string,
                    selectedChats: Set(),
                    additionalCategories: nil,
                    chatListFilters: nil,
                    displayAutoremoveTimeout: true
                )),
                options: [],
                filters: [.excludeSelf],
                isPeerEnabled: { peer in
                    var canManage = false
                    if case let .user(user) = peer {
                        if user.botInfo == nil {
                            canManage = true
                        }
                        if user.id.isRepliesOrSavedMessages(accountPeerId: context.account.peerId) {
                            return false
                        }
                    } else if case .secretChat = peer {
                        canManage = true
                    } else if case let .legacyGroup(group) = peer {
                        canManage = !group.hasBannedPermission(.banChangeInfo)
                    } else if case let .channel(channel) = peer {
                        canManage = channel.hasPermission(.changeInfo)
                    }
                    return canManage
                },
                attemptDisabledItemSelection: { peer in
                    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                    
                    let text: String
                    if case let .channel(channel) = peer {
                        if case .group = channel.info {
                            text = presentationData.strings.GlobalAutodeleteSettings_AttemptDisabledGroupSelection
                        } else {
                            text = presentationData.strings.GlobalAutodeleteSettings_AttemptDisabledChannelSelection
                        }
                    } else if case .legacyGroup = peer {
                        text = presentationData.strings.GlobalAutodeleteSettings_AttemptDisabledGroupSelection
                    } else {
                        text = presentationData.strings.GlobalAutodeleteSettings_AttemptDisabledGenericSelection
                    }
                    
                    presentControllerImpl?(standardTextAlertController(
                        theme: AlertControllerTheme(presentationData: presentationData),
                        title: nil,
                        text: text,
                        actions: [
                            TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})
                        ]
                    ), nil)
                }
            ))
            selectionController.navigationPresentation = .modal
            
            let _ = (selectionController.result
            |> take(1)
            |> deliverOnMainQueue).start(next: { [weak selectionController] result in
                var contacts: [ContactListPeerId] = []
                if case let .result(peerIdsValue, _) = result {
                    contacts = peerIdsValue
                }
                let peerIds = contacts.compactMap { item -> EnginePeer.Id? in
                    switch item {
                    case let .peer(id):
                        return id
                    case .deviceContact:
                        return nil
                    }
                }
                
                if peerIds.isEmpty {
                    selectionController?.dismiss()
                } else {
                    selectionController?.displayProgress = true
                    let _ = (context.engine.peers.setChatMessageAutoremoveTimeouts(peerIds: peerIds, timeout: value)
                    |> deliverOnMainQueue).start(completed: {
                        selectionController?.dismiss()
                        
                        let isOn: Bool = true
                        let text = presentationData.strings.GlobalAutodeleteSettings_ApplyChatsToast(timeIntervalString(strings: presentationData.strings, value: value, usage: .timer), presentationData.strings.GlobalAutodeleteSettings_ApplyChatsSubject(Int32(peerIds.count))).string
                        
                        var animateAsReplacement = false
                        if let window = getController?()?.window {
                            window.forEachController { other in
                                if let other = other as? UndoOverlayController {
                                    animateAsReplacement = true
                                    other.dismiss()
                                }
                            }
                        }
                        if let current = getController?() {
                            current.forEachController { other in
                                if let other = other as? UndoOverlayController {
                                    animateAsReplacement = true
                                    other.dismiss()
                                }
                                return true
                            }
                        }
                        presentInCurrentControllerImpl?(UndoOverlayController(presentationData: presentationData, content: .autoDelete(isOn: isOn, title: nil, text: text), elevatedLayout: false, animateInAsReplacement: animateAsReplacement, action: { _ in return false }))
                    })
                }
            })
            
            pushControllerImpl?(selectionController)
        }
    )
    
    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        statePromise.get()
    )
    |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let rightNavigationButton: ItemListNavigationButton? = nil
        
        let title: ItemListControllerTitle = .text(presentationData.strings.GlobalAutodeleteSettings_Title)
        
        let entries: [GlobalAutoremoveEntry] = globalAutoremoveScreenEntries(presentationData: presentationData, state: state)
        
        let animateChanges = false
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: title, leftNavigationButton: nil, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: true)
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, emptyStateItem: nil, crossfadeState: false, animateChanges: animateChanges, scrollEnabled: true)
        
        return (controllerState, (listState, arguments))
    }
    |> afterDisposed {
        actionsDisposable.dispose()
    }
    
    let controller = ItemListController(context: context, state: signal)
    getController = { [weak controller] in
        return controller
    }
    presentControllerImpl = { [weak controller] c, p in
        guard let controller else {
            return
        }
        controller.present(c, in: .window(.root), with: p)
    }
    presentInCurrentControllerImpl = { [weak controller] c in
        guard let controller else {
            return
        }
        controller.present(c, in: .current, with: nil)
    }
    pushControllerImpl = { [weak controller] c in
        controller?.push(c)
    }
    dismissImpl = { [weak controller] in
        controller?.dismiss()
    }
    
    return controller
}
