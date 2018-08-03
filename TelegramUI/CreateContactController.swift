import Foundation
import Display
import SwiftSignalKit
import Postbox
import TelegramCore

private final class CreateContactControllerArguments {
    let account: Account
    let updateEditingName: (ItemListAvatarAndNameInfoItemName) -> Void
    let updatePhone: (Int64, String) -> Void
    let openLabelSelection: (Int64, String) -> Void
    let addPhone: () -> Void
    let deletePhone: (Int64) -> Void
    
    init(account: Account, updateEditingName: @escaping (ItemListAvatarAndNameInfoItemName) -> Void, updatePhone: @escaping (Int64, String) -> Void, openLabelSelection: @escaping (Int64, String) -> Void, addPhone: @escaping () -> Void, deletePhone: @escaping (Int64) -> Void) {
        self.account = account
        self.updateEditingName = updateEditingName
        self.updatePhone = updatePhone
        self.openLabelSelection = openLabelSelection
        self.addPhone = addPhone
        self.deletePhone = deletePhone
    }
}

private enum CreateContactSection: ItemListSectionId {
    case info
    case phones
}

private enum CreateContactEntryId: Hashable {
    case index(Int)
    case phone(Int64)
    
    static func ==(lhs: CreateContactEntryId, rhs: CreateContactEntryId) -> Bool {
        switch lhs {
            case let .index(value):
                if case .index(value) = rhs {
                    return true
                } else {
                    return false
                }
            case let .phone(value):
                if case .phone(value) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
    
    var hashValue: Int {
        switch self {
            case let .index(value):
                return value.hashValue
            case let .phone(value):
                return value.hashValue
        }
    }
}

private enum CreateContactEntry: ItemListNodeEntry {
    case info(PresentationTheme, PresentationStrings, state: ItemListAvatarAndNameInfoItemState)
    case phoneNumber(PresentationTheme, PresentationStrings, Int64, Int, String, String, Bool)
    case addPhone(PresentationTheme, String)
    
    var section: ItemListSectionId {
        switch self {
            case .info:
                return CreateContactSection.info.rawValue
            case .phoneNumber, .addPhone:
                return CreateContactSection.phones.rawValue
        }
    }
    
    var stableId: CreateContactEntryId {
        switch self {
            case .info:
                return .index(0)
            case let .phoneNumber(_, _, id, _, _, _, _):
                return .phone(id)
            case .addPhone:
                return .index(1000)
        }
    }
    
    static func ==(lhs: CreateContactEntry, rhs: CreateContactEntry) -> Bool {
        switch lhs {
            case let .info(lhsTheme, lhsStrings, lhsState):
                if case let .info(rhsTheme, rhsStrings, rhsState) = rhs {
                    if lhsTheme !== rhsTheme {
                        return false
                    }
                    if lhsStrings !== rhsStrings {
                        return false
                    }
                    if lhsState != rhsState {
                        return false
                    }
                    return true
                } else {
                    return false
                }
        case let .phoneNumber(lhsTheme, lhsStrings, lhsId, lhsIndex, lhsLabel, lhsValue, lhsHasActiveRevealControls):
                if case let .phoneNumber(rhsTheme, rhsStrings, rhsId, rhsIndex, rhsLabel, rhsValue, rhsHasActiveRevealControls) = rhs, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsId == rhsId, lhsIndex == rhsIndex, lhsLabel == rhsLabel, lhsValue == rhsValue, lhsHasActiveRevealControls == rhsHasActiveRevealControls {
                    return true
                } else {
                    return false
                }
            case let .addPhone(lhsTheme, lhsTitle):
                if case let .addPhone(rhsTheme, rhsTitle) = rhs {
                    if lhsTheme !== rhsTheme {
                        return false
                    }
                    if lhsTitle != rhsTitle {
                        return false
                    }
                    return true
                } else {
                    return false
                }
        }
    }
    
    private var sortIndex: Int {
        switch self {
            case .info:
                return 0
            case let .phoneNumber(_, _, _, index, _, _, _):
                return 2 + index
            case .addPhone:
                return 1000
        }
    }
    
    static func <(lhs: CreateContactEntry, rhs: CreateContactEntry) -> Bool {
        return lhs.sortIndex < rhs.sortIndex
    }
    
    func item(_ arguments: CreateContactControllerArguments) -> ListViewItem {
        switch self {
            case let .info(theme, strings, state):
                var firstName = ""
                var lastName = ""
                if let editingName = state.editingName {
                    switch editingName {
                        case let .personName(first, last):
                            firstName = first
                            lastName = last
                        default:
                            break
                    }
                }
                return ItemListAvatarAndNameInfoItem(account: arguments.account, theme: theme, strings: strings, mode: .generic, peer: TelegramUser(id: PeerId(namespace: -1, id: 0), accessHash: nil, firstName: firstName, lastName: lastName, username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: []), presence: nil, cachedData: nil, state: state, sectionId: self.section, style: .plain, editingNameUpdated: { editingName in
                    arguments.updateEditingName(editingName)
                }, avatarTapped: {
                }, context: nil, call: nil)
            case let .phoneNumber(theme, strings, id, _, label, value, hasActiveRevealControls):
                return UserInfoEditingPhoneItem(theme: theme, strings: strings, id: id, label: label, value: value, editing: UserInfoEditingPhoneItemEditing(editable: true, hasActiveRevealControls: hasActiveRevealControls), sectionId: self.section, setPhoneIdWithRevealedOptions: { _, _ in
                }, updated: { value in
                    arguments.updatePhone(id, value)
                }, selectLabel: {
                    arguments.openLabelSelection(id, label)
                }, delete: {
                    arguments.deletePhone(id)
                }, tag: nil)
            case let .addPhone(theme, title):
                return UserInfoEditingPhoneActionItem(theme: theme, title: title, sectionId: self.section, action: {
                    arguments.addPhone()
                })
        }
    }
}

private struct CreateContactPhoneNumber: Equatable {
    let id: Int64
    let label: String
    let value: String
    
    static func ==(lhs: CreateContactPhoneNumber, rhs: CreateContactPhoneNumber) -> Bool {
        if lhs.id != rhs.id {
            return false
        }
        if lhs.label != rhs.label {
            return false
        }
        if lhs.value != rhs.value {
            return false
        }
        return true
    }
    
    func withUpdatedLabel(_ label: String) -> CreateContactPhoneNumber {
        return CreateContactPhoneNumber(id: self.id, label: label, value: self.value)
    }
    
    func withUpdatedValue(_ value: String) -> CreateContactPhoneNumber {
        return CreateContactPhoneNumber(id: self.id, label: self.label, value: value)
    }
}

private struct CreateContactState: Equatable {
    var editingName: ItemListAvatarAndNameInfoItemName
    var phoneNumbers: [CreateContactPhoneNumber]
    var revealedPhoneId: Int64?
    
    init(editingName: ItemListAvatarAndNameInfoItemName = .personName(firstName: "", lastName: ""), phoneNumbers: [CreateContactPhoneNumber] = [], revealedPhoneId: Int64? = nil) {
        self.editingName = editingName
        self.phoneNumbers = phoneNumbers
        self.revealedPhoneId = revealedPhoneId
    }
    
    static func ==(lhs: CreateContactState, rhs: CreateContactState) -> Bool {
        if lhs.editingName != rhs.editingName {
            return false
        }
        if lhs.phoneNumbers != rhs.phoneNumbers {
            return false
        }
        return true
    }
}

private func createContactEntries(account: Account, presentationData: PresentationData, state: CreateContactState) -> [CreateContactEntry] {
    var entries: [CreateContactEntry] = []
    
    entries.append(.info(presentationData.theme, presentationData.strings, state: ItemListAvatarAndNameInfoItemState(editingName: state.editingName, updatingName: nil)))
    
    var index = 0
    for phoneNumber in state.phoneNumbers {
        entries.append(.phoneNumber(presentationData.theme, presentationData.strings, phoneNumber.id, index, phoneNumber.label, phoneNumber.value, state.revealedPhoneId == phoneNumber.id))
        index += 1
    }
    
    entries.append(.addPhone(presentationData.theme, presentationData.strings.UserInfo_AddPhone))
    
    return entries
}

public func createContactController(account: Account) -> ViewController {
    var initialState = CreateContactState()
    initialState.phoneNumbers.append(CreateContactPhoneNumber(id: arc4random64(), label: "mobile", value: ""))
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((CreateContactState) -> CreateContactState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var dismissImpl: (() -> Void)?
    var presentControllerImpl: ((ViewController, Any?) -> Void)?
    
    let actionsDisposable = DisposableSet()
    
    let arguments = CreateContactControllerArguments(account: account,
        updateEditingName: { editingName in
        updateState { state in
            var state = state
            state.editingName = editingName
            return state
        }
    }, updatePhone: { id, value in
        updateState { state in
            var state = state
            for i in 0 ..< state.phoneNumbers.count {
                if state.phoneNumbers[i].id == id {
                    state.phoneNumbers[i] = state.phoneNumbers[i].withUpdatedValue(value)
                    break
                }
            }
            return state
        }
    }, openLabelSelection: { id, label in
        
    }, addPhone: {
        updateState { state in
            var state = state
            state.phoneNumbers.append(CreateContactPhoneNumber(id: arc4random64(), label: "mobile", value: ""))
            return state
        }
    }, deletePhone: { id in
        updateState { state in
            var state = state
            for i in 0 ..< state.phoneNumbers.count {
                if state.phoneNumbers[i].id == id {
                    state.phoneNumbers.remove(at: i)
                    break
                }
            }
            return state
        }
    })
    
    let signal = combineLatest((account.applicationContext as! TelegramApplicationContext).presentationData, statePromise.get())
        |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState<CreateContactEntry>, CreateContactEntry.ItemGenerationArguments)) in
            
            var canSave = true
            switch state.editingName {
                case let .personName(first, last):
                    if first.isEmpty && last.isEmpty {
                        canSave = false
                    }
                default:
                    canSave = false
            }
            
            var hasPhoneNumbers = false
            for phoneNumber in state.phoneNumbers {
                if !phoneNumber.value.isEmpty {
                    hasPhoneNumbers = true
                }
            }
            
            if !hasPhoneNumbers {
                canSave = false
            }
            
            let leftNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Cancel), style: .regular, enabled: true, action: {
                dismissImpl?()
            })
            let rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Done), style: .bold, enabled: canSave, action: {
                var state: CreateContactState?
                updateState {
                    state = $0
                    return $0
                }
                if let state = state {
                    var firstName = ""
                    var lastName = ""
                    switch state.editingName {
                        case let .personName(first, last):
                            firstName = first
                            lastName = last
                        default:
                            break
                    }
                    var phoneNumbers: [DeviceContactPhoneNumber] = []
                    for number in state.phoneNumbers {
                        if !number.value.isEmpty {
                            phoneNumbers.append(DeviceContactPhoneNumber(label: number.label, number: DeviceContactPhoneNumberValue(plain: number.value, normalized: DeviceContactNormalizedPhoneNumber(rawValue: number.value))))
                        }
                    }
                    let _ = (account.telegramApplicationContext.contactsManager.add(firstName: firstName, lastName: lastName, phoneNumbers: phoneNumbers)
                    |> deliverOnMainQueue).start(next: { _ in
                        dismissImpl?()
                    })
                }
            })
            
            let controllerState = ItemListControllerState(theme: presentationData.theme, title: .text(presentationData.strings.NewContact_Title), leftNavigationButton: leftNavigationButton, rightNavigationButton: rightNavigationButton, backNavigationButton: nil)
            let listState = ItemListNodeState(entries: createContactEntries(account: account, presentationData: presentationData, state: state), style: .plain)
            
            return (controllerState, (listState, arguments))
        } |> afterDisposed {
            actionsDisposable.dispose()
        }
    
    let controller = ItemListController(account: account, state: signal)
    dismissImpl = { [weak controller] in
        if let navigationController = controller?.navigationController as? NavigationController {
            let _ = navigationController.popViewController(animated: true)
        } else {
            controller?.dismiss()
        }
    }
    presentControllerImpl = { [weak controller] value, presentationArguments in
        controller?.present(value, in: .window(.root), with: presentationArguments)
    }
    
    return controller
}

