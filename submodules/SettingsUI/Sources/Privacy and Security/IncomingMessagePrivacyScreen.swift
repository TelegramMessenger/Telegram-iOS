import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import PresentationDataUtils
import AccountContext
import UndoUI
import PremiumUI

private final class IncomingMessagePrivacyScreenArguments {
    let context: AccountContext
    let updateValue: (Bool) -> Void
    let disabledValuePressed: () -> Void
    let infoLinkAction: () -> Void
    
    init(
        context: AccountContext,
        updateValue: @escaping (Bool) -> Void,
        disabledValuePressed: @escaping () -> Void,
        infoLinkAction: @escaping () -> Void
    ) {
        self.context = context
        self.updateValue = updateValue
        self.disabledValuePressed = disabledValuePressed
        self.infoLinkAction = infoLinkAction
    }
}

private enum IncomingMessagePrivacySection: Int32 {
    case header
    case info
}

private enum GlobalAutoremoveEntry: ItemListNodeEntry {
    case header
    case optionEverybody(value: Bool)
    case optionPremium(value: Bool, isEnabled: Bool)
    case footer
    case info
    
    var section: ItemListSectionId {
        switch self {
        case .header, .optionEverybody, .optionPremium, .footer:
            return IncomingMessagePrivacySection.header.rawValue
        case .info:
            return IncomingMessagePrivacySection.info.rawValue
        }
    }
    
    var stableId: Int {
        return self.sortIndex
    }

    var sortIndex: Int {
        switch self {
        case .header:
            return 0
        case .optionEverybody:
            return 1
        case .optionPremium:
            return 2
        case .footer:
            return 3
        case .info:
            return 4
        }
    }
    
    static func <(lhs: GlobalAutoremoveEntry, rhs: GlobalAutoremoveEntry) -> Bool {
        return lhs.sortIndex < rhs.sortIndex
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! IncomingMessagePrivacyScreenArguments
        switch self {
        case .header:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: presentationData.strings.Privacy_Messages_SectionTitle, sectionId: self.section)
        case let .optionEverybody(value):
            return ItemListCheckboxItem(presentationData: presentationData, title: presentationData.strings.Privacy_Messages_ValueEveryone, style: .left, checked: value, zeroSeparatorInsets: false, sectionId: self.section, action: {
                arguments.updateValue(false)
            })
        case let .optionPremium(value, isEnabled):
            return ItemListCheckboxItem(presentationData: presentationData, icon: isEnabled ? nil : generateTintedImage(image: UIImage(bundleImageName: "Chat/Stickers/Lock"), color: presentationData.theme.list.itemSecondaryTextColor), iconPlacement: .check, title: presentationData.strings.Privacy_Messages_ValueContactsAndPremium, style: .left, checked: isEnabled && value, zeroSeparatorInsets: false, sectionId: self.section, action: {
                if isEnabled {
                    arguments.updateValue(true)
                } else {
                    arguments.disabledValuePressed()
                }
            })
        case .footer:
            return ItemListTextItem(presentationData: presentationData, text: .plain(presentationData.strings.Privacy_Messages_SectionFooter), sectionId: self.section)
        case .info:
            return ItemListTextItem(presentationData: presentationData, text: .markdown(presentationData.strings.Privacy_Messages_PremiumInfoFooter), sectionId: self.section, linkAction: { _ in
                arguments.infoLinkAction()
            })
        }
    }
}

private struct IncomingMessagePrivacyScreenState: Equatable {
    var updatedValue: Bool
}

private func incomingMessagePrivacyScreenEntries(presentationData: PresentationData, state: IncomingMessagePrivacyScreenState, isPremium: Bool) -> [GlobalAutoremoveEntry] {
    var entries: [GlobalAutoremoveEntry] = []
    
    entries.append(.header)
    entries.append(.optionEverybody(value: !state.updatedValue))
    entries.append(.optionPremium(value: state.updatedValue, isEnabled: isPremium))
    entries.append(.footer)
    entries.append(.info)
    
    return entries
}

public func incomingMessagePrivacyScreen(context: AccountContext, value: Bool, update: @escaping (Bool) -> Void) -> ViewController {
    let initialState = IncomingMessagePrivacyScreenState(
        updatedValue: value
    )
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((IncomingMessagePrivacyScreenState) -> IncomingMessagePrivacyScreenState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var presentControllerImpl: ((ViewController, ViewControllerPresentationArguments?) -> Void)?
    var presentInCurrentControllerImpl: ((ViewController) -> Void)?
    var pushControllerImpl: ((ViewController) -> Void)?
    var dismissImpl: (() -> Void)?
    
    let _ = dismissImpl
    let _ = pushControllerImpl
    let _ = presentControllerImpl
    
    let actionsDisposable = DisposableSet()
    
    let updateTimeoutDisposable = MetaDisposable()
    actionsDisposable.add(updateTimeoutDisposable)
    
    let arguments = IncomingMessagePrivacyScreenArguments(
        context: context,
        updateValue: { value in
            updateState { state in
                var state = state
                state.updatedValue = value
                return state
            }
        },
        disabledValuePressed: {
            let presentationData = context.sharedContext.currentPresentationData.with({ $0 })
            presentInCurrentControllerImpl?(UndoOverlayController(presentationData: presentationData, content: .premiumPaywall(title: presentationData.strings.Privacy_Messages_PremiumToast_Title, text: presentationData.strings.Privacy_Messages_PremiumToast_Text, customUndoText: presentationData.strings.Privacy_Messages_PremiumToast_Action, timeout: nil, linkAction: { _ in
            }), elevatedLayout: false, action: { action in
                if case .undo = action {
                    let controller = PremiumIntroScreen(context: context, source: .settings)
                    pushControllerImpl?(controller)
                }
                return false
            }))
        },
        infoLinkAction: {
            let controller = PremiumIntroScreen(context: context, source: .settings)
            pushControllerImpl?(controller)
        }
    )
    
    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        context.engine.data.subscribe(
            TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId)
        ),
        statePromise.get()
    )
    |> map { presentationData, accountPeer, state -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let rightNavigationButton: ItemListNavigationButton? = nil
        
        let title: ItemListControllerTitle = .text(presentationData.strings.Privacy_Messages_Title)
        
        let entries: [GlobalAutoremoveEntry] = incomingMessagePrivacyScreenEntries(presentationData: presentationData, state: state, isPremium: accountPeer?.isPremium ?? false)
        
        let animateChanges = false
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: title, leftNavigationButton: nil, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: true)
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, emptyStateItem: nil, crossfadeState: false, animateChanges: animateChanges, scrollEnabled: true)
        
        return (controllerState, (listState, arguments))
    }
    |> afterDisposed {
        actionsDisposable.dispose()
    }
    
    let controller = ItemListController(context: context, state: signal)
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
        
        controller.forEachController { c in
            if let c = c as? UndoOverlayController {
                c.dismiss()
            }
            return true
        }
        controller.present(c, in: .current, with: nil)
    }
    pushControllerImpl = { [weak controller] c in
        controller?.push(c)
    }
    controller.attemptNavigation = { _ in
        update(stateValue.with({ $0 }).updatedValue)
        return true
    }
    dismissImpl = { [weak controller] in
        controller?.dismiss()
    }
    
    return controller
}
