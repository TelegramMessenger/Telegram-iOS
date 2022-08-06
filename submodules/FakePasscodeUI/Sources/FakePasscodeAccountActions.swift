import Foundation
import Display
import SwiftSignalKit
import TelegramPresentationData
import ItemListUI
import AccountContext
import FakePasscode

private final class FakePasscodeAccountActionsControllerArguments {
    let openChatsToRemove: ([PeerWithRemoveOptions]) -> Void
    let sessionsToHide: () -> Void
    let sessionsToTerminate: (Bool) -> Void
    let switchLogOut: (Bool) -> Void
    
    init(openChatsToRemove: @escaping ([PeerWithRemoveOptions]) -> Void, sessionsToHide: @escaping () -> Void, sessionsToTerminate: @escaping (Bool) -> Void, switchLogOut: @escaping (Bool) -> Void) {
        self.openChatsToRemove = openChatsToRemove
        self.switchLogOut = switchLogOut
        self.sessionsToHide = sessionsToHide
        self.sessionsToTerminate = sessionsToTerminate
    }
}

private enum FakePasscodeAccountActionsSection: Int32 {
    case sendTgMessages
    case fakePhoneNumber
    case sessionActions
    case miscActions
}

private enum FakePasscodeAccountActionsEntry: ItemListNodeEntry {
    case chatsToRemove(PresentationTheme, String, [PeerWithRemoveOptions])
    case logOut(PresentationTheme, String, Bool)
    case sessionsToHide(PresentationTheme, String, String)
    case sessionsToTerminate(PresentationTheme, String, String, Bool)
    case sessionsActionsInfo(PresentationTheme, String)
    case miscActionsInfo(PresentationTheme, String)
    
    var section: ItemListSectionId {
        switch self {
            case .sessionsToHide, .sessionsToTerminate, .sessionsActionsInfo:
                return FakePasscodeAccountActionsSection.sessionActions.rawValue
            case .chatsToRemove, .logOut, .miscActionsInfo:
                return FakePasscodeAccountActionsSection.miscActions.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
            case .chatsToRemove:
                return 0
            case .logOut:
                return 1
            case .miscActionsInfo:
                return 2
            case .sessionsToHide:
                return 3
            case .sessionsToTerminate:
                return 4
            case .sessionsActionsInfo:
                return 5
        }
    }

    static func <(lhs: FakePasscodeAccountActionsEntry, rhs: FakePasscodeAccountActionsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! FakePasscodeAccountActionsControllerArguments
        switch self {
            case let .chatsToRemove(_, title, chatsToRemove):
                return ItemListDisclosureItem(presentationData: presentationData, title: title, label: "\(chatsToRemove.count)", sectionId: self.section, style: .blocks, action: {
                    arguments.openChatsToRemove(chatsToRemove)
                })
            case let .sessionsToHide(_, title, label):
                return ItemListDisclosureItem(presentationData: presentationData, title: title, label: label, sectionId: self.section, style: .blocks, action: {
                    arguments.sessionsToHide()
                })
            case let .sessionsToTerminate(_, title, label, skipWarning):
                return ItemListDisclosureItem(presentationData: presentationData, title: title, label: label, sectionId: self.section, style: .blocks, action: {
                    arguments.sessionsToTerminate(skipWarning)
                })
            case let .logOut(_, title, value):
                return ItemListSwitchItem(presentationData: presentationData, title: title, value: value, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.switchLogOut(value)
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
    entries.append(.chatsToRemove(presentationData.theme, presentationData.strings.FakePasscodes_AccountActions_ChatsToRemove, settings.chatsToRemove))
    entries.append(.logOut(presentationData.theme, presentationData.strings.FakePasscodes_AccountActions_LogOut, settings.logOut))
    entries.append(.miscActionsInfo(presentationData.theme, presentationData.strings.FakePasscodes_AccountActions_MiscActionsInfo))
    entries.append(.sessionsToHide(presentationData.theme, presentationData.strings.FakePasscodes_AccountActions_SessionsToHide, sessionToHideLabel(presentationData, settings.sessionsToHide)))
    entries.append(.sessionsToTerminate(presentationData.theme, presentationData.strings.FakePasscodes_AccountActions_SessionsToTerminate, sessionToHideLabel(presentationData, settings.sessionsToTerminate), !settings.sessionsToTerminateSkipWarning))
    entries.append(.sessionsActionsInfo(presentationData.theme, presentationData.strings.FakePasscodes_AccountActions_SessionsSettingsInfo))
    return entries
}

func fakePasscodeAccountActionsController(context: AccountContext, uuid: UUID, accountDisplayName: String) -> ViewController {
    var pushControllerImpl: ((ViewController) -> Void)?
    var presentControllerImpl: ((ViewController) -> Void)?

    let actionsDisposable = DisposableSet()
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }

    let accountActionsDataPromise = Promise<FakePasscodeAccountActionsData>()
    accountActionsDataPromise.set(context.sharedContext.accountManager.transaction { transaction -> FakePasscodeAccountActionsData in
        let settings = FakePasscodeSettingsHolder(transaction).getAccountActions(uuid, context.account)
        return FakePasscodeAccountActionsData(settings: settings)
    })

    let arguments = FakePasscodeAccountActionsControllerArguments(openChatsToRemove: { chatsToRemove in
        pushControllerImpl?(chatsToRemoveController(context: context, chatsToRemove: chatsToRemove, updatedSettings: { chatsToRemove in
            updateAccountActionSettings(context: context, uuid: uuid, accountActionsDataPromise) { settings in
                return settings.withUpdatedChatsToRemove(chatsToRemove)
            }
        }))
    }, sessionsToHide: {
        let _ = (accountActionsDataPromise.get() |> take(1)).start(next: { data in
            pushControllerImpl?(sessionsSelectionController(context: context, title: presentationData.strings.FakePasscodes_AccountActions_SessionsToHide, selector: data.settings.sessionsToHide, updated: { sessionsToHide in
                updateAccountActionSettings(context: context, uuid: uuid, accountActionsDataPromise) { settings in
                    settings.withUpdatedSessionsToHide(sessionsToHide)
                }
            }))
        })
    }, sessionsToTerminate: { showWarning in
        let _ = (accountActionsDataPromise.get() |> take(1)).start(next: { data in
            pushControllerImpl?(sessionsSelectionController(context: context, title: presentationData.strings.FakePasscodes_AccountActions_SessionsToTerminate, selector: data.settings.sessionsToTerminate, updated: { sessionsToTerminate in
                updateAccountActionSettings(context: context, uuid: uuid, accountActionsDataPromise) { settings in
                    settings.withUpdatedSessionsToTerminate(sessionsToTerminate)
                }
            }))

            if showWarning {
                let controller = ActionSheetController(presentationData: presentationData)
                let dismissAction: () -> Void = { [weak controller] in
                    controller?.dismissAnimated()
                }
                controller.setItemGroups([
                    ActionSheetItemGroup(items: [
                        ActionSheetTextItem(title: presentationData.strings.AccountActions_SessionsToTerminate_24hWarningMessage),
                        ActionSheetButtonItem(title: presentationData.strings.FakePasscodes_Common_DoNotShowAgain, color: .destructive, action: {
                            updateAccountActionSettings(context: context, uuid: uuid, accountActionsDataPromise) { settings in
                                settings.withDisabledSessionsToTerminateWarning()
                            }
                            dismissAction()
                        })
                    ]),
                    ActionSheetItemGroup(items: [ActionSheetButtonItem(title: presentationData.strings.Common_OK, action: { dismissAction() })])
                ])
                presentControllerImpl?(controller)
            }
        })
    }, switchLogOut: { enabled in
        updateAccountActionSettings(context: context, uuid: uuid, accountActionsDataPromise) { settings in
            return settings.withUpdatedLogOut(enabled)
        }
    })

    let signal = combineLatest(context.sharedContext.presentationData, accountActionsDataPromise.get()) |> deliverOnMainQueue
        |> map { presentationData, accountActionsData -> (ItemListControllerState, (ItemListNodeState, Any)) in
            let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(accountDisplayName), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: false)
            
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
    presentControllerImpl = { [weak controller] c in
        controller?.present(c, in: .window(.root), with: ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
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

private func sessionToHideLabel(_ presentationData: PresentationData, _ selector: SessionSelector) -> String {
    let sessionsCount = "\(selector.sessions.count)"

    switch selector.mode {
    case .selected:
        return sessionsCount
    case .excluded:
        return selector.sessions.count == 0 ? presentationData.strings.FakePasscodes_AccountActions_All : presentationData.strings.FakePasscodes_AccountActions_AllExceptCount(sessionsCount).string
    }
}
