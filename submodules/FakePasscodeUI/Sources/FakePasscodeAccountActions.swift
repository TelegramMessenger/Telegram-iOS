import Foundation
import Display
import SwiftSignalKit
import TelegramPresentationData
import ItemListUI
import AccountContext
import FakePasscode

private final class FakePasscodeAccountActionsControllerArguments {
    let logOut: (Bool) -> Void
    let sessionsToHide: () -> Void
    
    init(logOut: @escaping (Bool) -> Void, sessionsToHide: @escaping () -> Void) {
        self.logOut = logOut
        self.sessionsToHide = sessionsToHide
    }
}

private enum FakePasscodeAccountActionsSection: Int32 {
    case sendTgMessages
    case fakePhoneNumber
    case sessionActions
    case miscActions
}

private enum FakePasscodeAccountActionsEntry: ItemListNodeEntry {
    case logOut(PresentationTheme, String, Bool)
    case sessionsToHide(PresentationTheme, String, String)
    case sessionsActionsInfo(PresentationTheme, String)
    case miscActionsInfo(PresentationTheme, String)
    
    var section: ItemListSectionId {
        switch self {
            case .sessionsToHide, .sessionsActionsInfo:
                return FakePasscodeAccountActionsSection.sessionActions.rawValue
            case .logOut, .miscActionsInfo:
                return FakePasscodeAccountActionsSection.miscActions.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
            case .sessionsToHide:
                return 0
            case .sessionsActionsInfo:
                return 1
            case .logOut:
                return 2
            case .miscActionsInfo:
                return 3
        }
    }

    static func <(lhs: FakePasscodeAccountActionsEntry, rhs: FakePasscodeAccountActionsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! FakePasscodeAccountActionsControllerArguments
        switch self {
            case let .sessionsToHide(_, title, label):
                return ItemListDisclosureItem(presentationData: presentationData, title: title, label: label, sectionId: self.section, style: .blocks, action: {
                    arguments.sessionsToHide()
                })
            case let .logOut(_, title, value):
                return ItemListSwitchItem(presentationData: presentationData, title: title, value: value, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.logOut(value)
                })
            case let .miscActionsInfo(_, text), let .sessionsActionsInfo(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

private struct FakePasscodeAccountActionsData: Equatable {
    let settings: FakePasscodeAccountActionsSettings

    func withUpdatedSettings(_ settings: FakePasscodeAccountActionsSettings) -> FakePasscodeAccountActionsData {
        return FakePasscodeAccountActionsData(settings: settings)
    }
}

private func fakePasscodeAccountActionsControllerEntries(presentationData: PresentationData, settings: FakePasscodeAccountActionsSettings) -> [FakePasscodeAccountActionsEntry] {
    var entries: [FakePasscodeAccountActionsEntry] = []

    let sessionsCount = "\(settings.sessionsToHide.count)"
    let label = settings.sessionsToHideMode == .selected ? sessionsCount
        : presentationData.strings.FakePasscodes_AccountActions_AllExceptCount(sessionsCount).string

    entries.append(.sessionsToHide(presentationData.theme, presentationData.strings.FakePasscodes_AccountActions_SessionsToHide, label))
    entries.append(.sessionsActionsInfo(presentationData.theme, presentationData.strings.FakePasscodes_AccountActions_SessionsSettingsInfo))
    entries.append(.logOut(presentationData.theme, presentationData.strings.FakePasscodes_AccountActions_LogOut, settings.logOut))
     entries.append(.miscActionsInfo(presentationData.theme, presentationData.strings.FakePasscodes_AccountActions_MiscActionsInfo))
    
    return entries
}

func fakePasscodeAccountActionsController(context: AccountContext, uuid: UUID, account: FakePasscodeActionsAccount) -> ViewController {
    let actionsDisposable = DisposableSet()

    var pushControllerImpl: ((ViewController) -> Void)?

    let accountActionsDataPromise = Promise<FakePasscodeAccountActionsData>()
    accountActionsDataPromise.set(context.sharedContext.accountManager.transaction { transaction -> FakePasscodeAccountActionsData in
        let settings = FakePasscodeSettingsHolder(transaction).getAccountActions(uuid, account)
        return FakePasscodeAccountActionsData(settings: settings)
    })

    let arguments = FakePasscodeAccountActionsControllerArguments(logOut: { enabled in
        updateAccountActionSettings(context: context, uuid: uuid, accountActionsDataPromise) { settings in
            return settings.withUpdatedLogOut(enabled)
        }
    }, sessionsToHide: {
        pushControllerImpl?(hiddenSessionsController(context: context, uuid: uuid, account: account, updated: { settings in
            accountActionsDataPromise.set(.single(FakePasscodeAccountActionsData(settings: settings)))
        }))
    })

    let signal = combineLatest(context.sharedContext.presentationData, accountActionsDataPromise.get()) |> deliverOnMainQueue
        |> map { presentationData, accountActionsData -> (ItemListControllerState, (ItemListNodeState, Any)) in
            let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(account.displayName), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: false)
            
            let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: fakePasscodeAccountActionsControllerEntries(presentationData: presentationData, settings: accountActionsData.settings), style: .blocks, emptyStateItem: nil, animateChanges: false)

            return (controllerState, (listState, arguments))
        } |> afterDisposed {
            actionsDisposable.dispose()
    }

    let controller = ItemListControllerReactiveToPasscodeSwitch(context: context, state: signal, onPasscodeSwitch: { controller in
        controller.dismiss(animated: false)
    })

    pushControllerImpl = { [weak controller] c in
        (controller?.navigationController as? NavigationController)?.pushViewController(c)
    }

    return controller
}

private func updateAccountActionSettings(context: AccountContext, uuid: UUID, _ accountActionsDataPromise: Promise<FakePasscodeAccountActionsData>, _ f: @escaping (FakePasscodeAccountActionsSettings) -> FakePasscodeAccountActionsSettings) {
    let _ = (accountActionsDataPromise.get() |> take(1)).start(next: { [weak accountActionsDataPromise] data in
        let updatedSettings = f(data.settings)
        accountActionsDataPromise?.set(.single(data.withUpdatedSettings(updatedSettings)))

        let _ = updateFakePasscodeSettingsInteractively(accountManager: context.sharedContext.accountManager, { holder in
            return holder.withUpdatedSettingsItem(holder.settings.first(where: { $0.uuid == uuid })!.withUpdatedAccountActionItem(updatedSettings))
        }).start()
    })
}
