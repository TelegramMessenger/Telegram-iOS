import Foundation
import Postbox
import TelegramCore
import TelegramUIPreferences
import SwiftSignalKit
import Display
import ItemListUI
import TelegramPresentationData
import AccountContext
import SettingsUI
import PasscodeUI
import PtgSecretPasscodes

private final class SecretPasscodeControllerArguments {
    let changePasscode: () -> Void
    let changeTimeout: () -> Void
    let deletePasscode: () -> Void
    
    init(changePasscode: @escaping () -> Void, changeTimeout: @escaping () -> Void, deletePasscode: @escaping () -> Void) {
        self.changePasscode = changePasscode
        self.changeTimeout = changeTimeout
        self.deletePasscode = deletePasscode
    }
}

private enum SecretPasscodeControllerSection: Int32 {
    case state
    case timeout
    case changePasscode
    case delete
}

private enum SecretPasscodeControllerEntry: ItemListNodeEntry {
    case state(String)
    case timeout(String, String)
    case changePasscode(String)
    case delete(String)
    
    var section: ItemListSectionId {
        switch self {
        case .state:
            return SecretPasscodeControllerSection.state.rawValue
        case .timeout:
            return SecretPasscodeControllerSection.timeout.rawValue
        case .changePasscode:
            return SecretPasscodeControllerSection.changePasscode.rawValue
        case .delete:
            return SecretPasscodeControllerSection.delete.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
        case .state:
            return 0
        case .timeout:
            return 1
        case .changePasscode:
            return 2
        case .delete:
            return 3
        }
    }
    
    static func <(lhs: SecretPasscodeControllerEntry, rhs: SecretPasscodeControllerEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! SecretPasscodeControllerArguments
        switch self {
        case let .state(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case let .timeout(title, value):
            return ItemListDisclosureItem(presentationData: presentationData, title: title, label: value, sectionId: self.section, style: .blocks, action: {
                arguments.changeTimeout()
            })
        case let .changePasscode(title):
            return ItemListActionItem(presentationData: presentationData, title: title, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.changePasscode()
            })
        case let .delete(title):
            return ItemListActionItem(presentationData: presentationData, title: title, kind: .destructive, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.deletePasscode()
            })
        }
    }
}

private struct SecretPasscodeControllerState: Equatable {
    let settings: PtgSecretPasscode
    
    func withUpdated(settings: PtgSecretPasscode) -> SecretPasscodeControllerState {
        return SecretPasscodeControllerState(settings: settings)
    }
}

private func secretPasscodeControllerEntries(presentationData: PresentationData, settings: PtgSecretPasscode) -> [SecretPasscodeControllerEntry] {
    var entries: [SecretPasscodeControllerEntry] = []
    
    entries.append(.state(settings.active ? presentationData.strings.SecretPasscodeStatus_Revealed : presentationData.strings.SecretPasscodeStatus_Hidden))
    
    entries.append(.timeout(presentationData.strings.SecretPasscodeSettings_AutoHide, autolockStringForTimeout(strings: presentationData.strings, timeout: settings.timeout)))
    
    entries.append(.changePasscode(presentationData.strings.PasscodeSettings_ChangePasscode))
    
    entries.append(.delete(presentationData.strings.SecretPasscodeSettings_DeleteSecretPasscode))
    
    return entries
}

public func secretPasscodeController(context: AccountContext, passcode: String) -> ViewController {
    let statePromise = Promise<SecretPasscodeControllerState>()
    statePromise.set(context.sharedContext.ptgSecretPasscodes
    |> take(1)
    |> map { ptgSecretPasscodes in
        let secretPasscode = ptgSecretPasscodes.secretPasscode(passcode: passcode) ?? PtgSecretPasscode(passcode: passcode)
        return SecretPasscodeControllerState(settings: secretPasscode)
    })
    
    var pushControllerImpl: ((ViewController) -> Void)?
    var popControllerImpl: (() -> Void)?
    var presentControllerImpl: ((ViewController, ViewControllerPresentationArguments) -> Void)?
    
    let arguments = SecretPasscodeControllerArguments(changePasscode: {
        let _ = (combineLatest(context.sharedContext.ptgSecretPasscodes, statePromise.get())
        |> take(1)
        |> deliverOnMainQueue).start(next: { ptgSecretPasscodes, state in
            let controller = PasscodeSetupController(context: context, mode: .secretSetup(.digits6))
            
            controller.validate = { newPasscode in
                if ptgSecretPasscodes.secretPasscodes.contains(where: { $0.passcode == newPasscode }) && newPasscode != state.settings.passcode {
                    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                    return presentationData.strings.PasscodeSettings_PasscodeInUse
                }
                return nil
            }
            
            controller.complete = { newPasscode, numerical in
                let _ = (statePromise.get()
                |> take(1)
                |> deliverOnMainQueue).start(next: { [weak statePromise] state in
                    statePromise?.set(.single(state.withUpdated(settings: state.settings.withUpdated(passcode: newPasscode))))
                    
                    let _ = updatePtgSecretPasscodes(context.sharedContext.accountManager, { current in
                        var updated = current.secretPasscodes
                        if let ind = updated.firstIndex(where: { $0.passcode == state.settings.passcode }) {
                            updated[ind] = updated[ind].withUpdated(passcode: newPasscode)
                        }
                        return PtgSecretPasscodes(secretPasscodes: updated)
                    }).start()
                    
                    popControllerImpl?()
                })
            }
            
            pushControllerImpl?(controller)
        })
    }, changeTimeout: {
        let _ = (context.sharedContext.ptgSecretPasscodes
        |> take(1)
        |> deliverOnMainQueue).start(next: { ptgSecretPasscodes in
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            let actionSheet = ActionSheetController(presentationData: presentationData)
            var items: [ActionSheetItem] = []
            let setAction: (Int32?) -> Void = { value in
                let _ = (statePromise.get()
                |> take(1)).start(next: { [weak statePromise] state in
                    statePromise?.set(.single(state.withUpdated(settings: state.settings.withUpdated(timeout: value))))
                    
                    let _ = updatePtgSecretPasscodes(context.sharedContext.accountManager, { current in
                        var updated = current.secretPasscodes
                        if let ind = updated.firstIndex(where: { $0.passcode == state.settings.passcode }) {
                            updated[ind] = updated[ind].withUpdated(timeout: value)
                        }
                        return PtgSecretPasscodes(secretPasscodes: updated)
                    }).start()
                })
            }
            
            let values: [Int32] = [/*0, */10, 1 * 60, 5 * 60, 1 * 60 * 60, 5 * 60 * 60]
            
            for value in values {
                var t: Int32?
                if value != 0 {
                    t = value
                }
                items.append(ActionSheetButtonItem(title: autolockStringForTimeout(strings: presentationData.strings, timeout: t), color: .accent, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                    
                    setAction(t)
                }))
            }
            
            actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
                    ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                    })
                ])])
            
            presentControllerImpl?(actionSheet, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
        })
    }, deletePasscode: {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let actionSheet = ActionSheetController(presentationData: presentationData)
        
        actionSheet.setItemGroups([
            ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: presentationData.strings.SecretPasscodeSettings_DeleteSecretPasscode, color: .destructive, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                    
                    let _ = (statePromise.get()
                    |> take(1)).start(next: { state in
                        let _ = updatePtgSecretPasscodes(context.sharedContext.accountManager, { current in
                            let updated = current.secretPasscodes.filter { $0.passcode != state.settings.passcode }
                            return PtgSecretPasscodes(secretPasscodes: updated)
                        }).start()
                    })
                    
                    popControllerImpl?()
                })
            ]),
            ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                })
            ])
        ])
        
        presentControllerImpl?(actionSheet, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
    })
    
    let signal = combineLatest(context.sharedContext.presentationData, statePromise.get())
    |> deliverOnMainQueue
    |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(presentationData.strings.SecretPasscodeSettings_Title), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: false)
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: secretPasscodeControllerEntries(presentationData: presentationData, settings: state.settings), style: .blocks, animateChanges: false)
        
        return (controllerState, (listState, arguments))
    }
    
    let controller = ItemListController(context: context, state: signal)
    
    pushControllerImpl = { [weak controller] c in
        (controller?.navigationController as? NavigationController)?.pushViewController(c)
    }
    
    popControllerImpl = { [weak controller] in
        let _ = (controller?.navigationController as? NavigationController)?.popViewController(animated: true)
    }
    
    presentControllerImpl = { [weak controller] c, p in
        if let controller = controller {
            controller.present(c, in: .window(.root), with: p)
        }
    }
    
    return controller
}
