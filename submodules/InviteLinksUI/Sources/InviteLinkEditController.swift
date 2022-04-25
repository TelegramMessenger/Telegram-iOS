import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import PresentationDataUtils
import OverlayStatusController
import AccountContext
import AlertUI
import PresentationDataUtils
import AppBundle
import ContextUI
import TelegramStringFormatting
import UndoUI

private final class InviteLinkEditControllerArguments {
    let context: AccountContext
    let updateState: ((InviteLinkEditControllerState) -> InviteLinkEditControllerState) -> Void
    let scrollToUsage: () -> Void
    let dismissInput: () -> Void
    let revoke: () -> Void
    
    init(context: AccountContext, updateState: @escaping ((InviteLinkEditControllerState) -> InviteLinkEditControllerState) -> Void,  scrollToUsage: @escaping () -> Void, dismissInput: @escaping () -> Void, revoke: @escaping () -> Void) {
        self.context = context
        self.updateState = updateState
        self.scrollToUsage = scrollToUsage
        self.dismissInput = dismissInput
        self.revoke = revoke
    }
}

private enum InviteLinksEditSection: Int32 {
    case title
    case requestApproval
    case time
    case usage
    case revoke
}

private enum InviteLinksEditEntryTag: ItemListItemTag {
    case usage

    func isEqual(to other: ItemListItemTag) -> Bool {
        if let other = other as? InviteLinksEditEntryTag, self == other {
            return true
        } else {
            return false
        }
    }
}

private let invalidAmountCharacters = CharacterSet(charactersIn: "01234567890.,").inverted
func isValidNumberOfUsers(_ number: String) -> Bool {
    if number.isEmpty {
        return true
    }
    let number = normalizeArabicNumeralString(number, type: .western)
    if number.rangeOfCharacter(from: invalidAmountCharacters) != nil || number == "0" {
        return false
    }
    if let value = Int32(number), value > 0 && value < 100000 {
        return true
    } else {
        return false
    }
}

private enum InviteLinksEditEntry: ItemListNodeEntry {
    case titleHeader(PresentationTheme, String)
    case title(PresentationTheme, String, String)
    case titleInfo(PresentationTheme, String)
    
    case requestApproval(PresentationTheme, String, Bool)
    case requestApprovalInfo(PresentationTheme, String)
    
    case timeHeader(PresentationTheme, String)
    case timePicker(PresentationTheme, InviteLinkTimeLimit)
    case timeExpiryDate(PresentationTheme, PresentationDateTimeFormat, Int32?, Bool)
    case timeCustomPicker(PresentationTheme, PresentationDateTimeFormat, Int32?)
    case timeInfo(PresentationTheme, String)
    
    case usageHeader(PresentationTheme, String)
    case usagePicker(PresentationTheme, PresentationDateTimeFormat, InviteLinkUsageLimit)
    case usageCustomPicker(PresentationTheme, Int32?, Bool, Bool)
    case usageInfo(PresentationTheme, String)
    
    case revoke(PresentationTheme, String)
   
    var section: ItemListSectionId {
        switch self {
            case .titleHeader, .title, .titleInfo:
                return InviteLinksEditSection.title.rawValue
            case .requestApproval, .requestApprovalInfo:
                return InviteLinksEditSection.requestApproval.rawValue
            case .timeHeader, .timePicker, .timeExpiryDate, .timeCustomPicker, .timeInfo:
                return InviteLinksEditSection.time.rawValue
            case .usageHeader, .usagePicker, .usageCustomPicker, .usageInfo:
                return InviteLinksEditSection.usage.rawValue
            case .revoke:
                return InviteLinksEditSection.revoke.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
            case .titleHeader:
                return 0
            case .title:
                return 1
            case .titleInfo:
                return 2
            case .requestApproval:
                return 3
            case .requestApprovalInfo:
                return 4
            case .timeHeader:
                return 5
            case .timePicker:
                return 6
            case .timeExpiryDate:
                return 7
            case .timeCustomPicker:
                return 8
            case .timeInfo:
                return 9
            case .usageHeader:
                return 10
            case .usagePicker:
                return 11
            case .usageCustomPicker:
                return 12
            case .usageInfo:
                return 13
            case .revoke:
                return 14
        }
    }
    
    static func ==(lhs: InviteLinksEditEntry, rhs: InviteLinksEditEntry) -> Bool {
        switch lhs {
            case let .titleHeader(lhsTheme, lhsText):
                if case let .titleHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .title(lhsTheme, lhsPlaceholder, lhsValue):
                if case let .title(rhsTheme, rhsPlaceholder, rhsValue) = rhs, lhsTheme === rhsTheme, lhsPlaceholder == rhsPlaceholder, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .titleInfo(lhsTheme, lhsText):
                if case let .titleInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .requestApproval(lhsTheme, lhsText, lhsValue):
                if case let .requestApproval(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .requestApprovalInfo(lhsTheme, lhsText):
                if case let .requestApprovalInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .timeHeader(lhsTheme, lhsText):
                if case let .timeHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .timePicker(lhsTheme, lhsValue):
                if case let .timePicker(rhsTheme, rhsValue) = rhs, lhsTheme === rhsTheme, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .timeExpiryDate(lhsTheme, lhsDateTimeFormat, lhsDate, lhsActive):
                if case let .timeExpiryDate(rhsTheme, rhsDateTimeFormat, rhsDate, rhsActive) = rhs, lhsTheme === rhsTheme, lhsDateTimeFormat == rhsDateTimeFormat, lhsDate == rhsDate, lhsActive == rhsActive {
                    return true
                } else {
                    return false
                }
            case let .timeCustomPicker(lhsTheme, lhsDateTimeFormat, lhsDate):
                if case let .timeCustomPicker(rhsTheme, rhsDateTimeFormat, rhsDate) = rhs, lhsTheme === rhsTheme, lhsDateTimeFormat == rhsDateTimeFormat, lhsDate == rhsDate {
                    return true
                } else {
                    return false
                }
            case let .timeInfo(lhsTheme, lhsText):
                if case let .timeInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .usageHeader(lhsTheme, lhsText):
                if case let .usageHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .usagePicker(lhsTheme, lhsDateTimeFormat, lhsValue):
                if case let .usagePicker(rhsTheme, rhsDateTimeFormat, rhsValue) = rhs, lhsTheme === rhsTheme, lhsDateTimeFormat == rhsDateTimeFormat, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .usageCustomPicker(lhsTheme, lhsValue, lhsFocused, lhsCustomValue):
                if case let .usageCustomPicker(rhsTheme, rhsValue, rhsFocused, rhsCustomValue) = rhs, lhsTheme === rhsTheme, lhsValue == rhsValue, lhsFocused == rhsFocused, lhsCustomValue == rhsCustomValue {
                    return true
                } else {
                    return false
                }
            case let .usageInfo(lhsTheme, lhsText):
                if case let .usageInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .revoke(lhsTheme, lhsText):
                if case let .revoke(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: InviteLinksEditEntry, rhs: InviteLinksEditEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! InviteLinkEditControllerArguments
        switch self {
            case let .titleHeader(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .title(_, placeholder, value):
                return ItemListSingleLineInputItem(presentationData: presentationData, title: NSAttributedString(), text: value, placeholder: placeholder, maxLength: 32, sectionId: self.section, textUpdated: { value in
                    arguments.updateState { state in
                        var updatedState = state
                        updatedState.title = value
                        return updatedState
                    }
                }, action: {})
            case let .titleInfo(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
            case let .requestApproval(_, text, value):
                return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.updateState { state in
                        var updatedState = state
                        updatedState.requestApproval = value
                        return updatedState
                    }
                })
            case let .requestApprovalInfo(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
            case let .timeHeader(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .timePicker(_, value):
                return ItemListInviteLinkTimeLimitItem(theme: presentationData.theme, strings: presentationData.strings, value: value, enabled: true, sectionId: self.section, updated: { value in
                    arguments.updateState({ state in
                        var updatedState = state
                        if value != updatedState.time {
                            updatedState.pickingTimeLimit = false
                        }
                        updatedState.time = value
                        return updatedState
                    })
                })
            case let .timeExpiryDate(theme, dateTimeFormat, value, active):
                let text: String
                if let value = value {
                    text = stringForMediumDate(timestamp: value, strings: presentationData.strings, dateTimeFormat: dateTimeFormat)
                } else {
                    text = presentationData.strings.InviteLink_Create_TimeLimitExpiryDateNever
                }
                return ItemListDisclosureItem(presentationData: presentationData, title: presentationData.strings.InviteLink_Create_TimeLimitExpiryDate, label: text, labelStyle: active ? .coloredText(theme.list.itemAccentColor) : .text, sectionId: self.section, style: .blocks, disclosureStyle: .none, action: {
                    arguments.dismissInput()
                    arguments.updateState { state in
                        var updatedState = state
                        updatedState.pickingTimeLimit = !state.pickingTimeLimit
                        return updatedState
                    }
                })
            case let .timeCustomPicker(_, dateTimeFormat, date):
                return ItemListDatePickerItem(presentationData: presentationData, dateTimeFormat: dateTimeFormat, date: date, sectionId: self.section, style: .blocks, updated: { date in
                    arguments.updateState({ state in
                        var updatedState = state
                        updatedState.time = .custom(date)
                        return updatedState
                    })
                })
            case let .timeInfo(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
            case let .usageHeader(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .usagePicker(_, dateTimeFormat, value):
                return ItemListInviteLinkUsageLimitItem(theme: presentationData.theme, strings: presentationData.strings, dateTimeFormat: dateTimeFormat, value: value, enabled: true, sectionId: self.section, updated: { value in
                    arguments.dismissInput()
                    arguments.updateState({ state in
                        var updatedState = state
                        if value != updatedState.usage {
                            updatedState.pickingTimeLimit = false
                        }
                        updatedState.usage = value
                        return updatedState
                    })
                })
            case let .usageCustomPicker(theme, value, focused, customValue):
                let text: String
                if let value = value, value != 0 {
                    text = String(value)
                } else {
                    text = focused ? "" : presentationData.strings.InviteLink_Create_UsersLimitNumberOfUsersUnlimited
                }
                return ItemListSingleLineInputItem(presentationData: presentationData, title: NSAttributedString(string: presentationData.strings.InviteLink_Create_UsersLimitNumberOfUsers, textColor: theme.list.itemPrimaryTextColor), text: text, placeholder: "", type: .number, alignment: .right, selectAllOnFocus: true, secondaryStyle: !customValue, tag: InviteLinksEditEntryTag.usage, sectionId: self.section, textUpdated: { updatedText in
                    arguments.updateState { state in
                        var updatedState = state
                        if updatedText.isEmpty {
                            updatedState.usage = .unlimited
                        } else if let value = Int32(updatedText) {
                            updatedState.usage = InviteLinkUsageLimit(value: value)
                        }
                        return updatedState
                    }
                }, shouldUpdateText: { text in
                    return isValidNumberOfUsers(text)
                }, updatedFocus: { focus in
                    if focus {
                        arguments.updateState { state in
                            var updatedState = state
                            updatedState.pickingTimeLimit = false
                            updatedState.pickingUsageLimit = true
                            return updatedState
                        }
                        arguments.scrollToUsage()
                    } else {
                        arguments.updateState { state in
                            var updatedState = state
                            updatedState.pickingUsageLimit = false
                            return updatedState
                        }
                    }
                }, action: {
                    
                })
            case let .usageInfo(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
            case let .revoke(_, text):
                return ItemListActionItem(presentationData: presentationData, title: text, kind: .destructive, alignment: .center, sectionId: self.section, style: .blocks, action: {
                    arguments.revoke()
                }, tag: nil)
        }
    }
}

private func inviteLinkEditControllerEntries(invite: ExportedInvitation?, state: InviteLinkEditControllerState, isGroup: Bool, isPublic: Bool, presentationData: PresentationData) -> [InviteLinksEditEntry] {
    var entries: [InviteLinksEditEntry] = []
    
    entries.append(.titleHeader(presentationData.theme, presentationData.strings.InviteLink_Create_LinkNameTitle.uppercased()))
    entries.append(.title(presentationData.theme, presentationData.strings.InviteLink_Create_LinkName, state.title))
    entries.append(.titleInfo(presentationData.theme, presentationData.strings.InviteLink_Create_LinkNameInfo))
    
    if !isPublic {
        entries.append(.requestApproval(presentationData.theme, presentationData.strings.InviteLink_Create_RequestApproval, state.requestApproval))
        var requestApprovalInfoText = presentationData.strings.InviteLink_Create_RequestApprovalOffInfoChannel
        if state.requestApproval {
            requestApprovalInfoText = isGroup ? presentationData.strings.InviteLink_Create_RequestApprovalOnInfoGroup : presentationData.strings.InviteLink_Create_RequestApprovalOnInfoChannel
        } else {
            requestApprovalInfoText = isGroup ? presentationData.strings.InviteLink_Create_RequestApprovalOnInfoGroup : presentationData.strings.InviteLink_Create_RequestApprovalOffInfoChannel
        }
        entries.append(.requestApprovalInfo(presentationData.theme, requestApprovalInfoText))
    }
    
    entries.append(.timeHeader(presentationData.theme,  presentationData.strings.InviteLink_Create_TimeLimit.uppercased()))
    entries.append(.timePicker(presentationData.theme, state.time))
    
    let currentTime = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
    var time: Int32?
    if case let .custom(value) = state.time {
        time = value
    } else if let value = state.time.value {
        time = currentTime + value
    }
    entries.append(.timeExpiryDate(presentationData.theme, presentationData.dateTimeFormat, time, state.pickingTimeLimit))
    if state.pickingTimeLimit {
        entries.append(.timeCustomPicker(presentationData.theme, presentationData.dateTimeFormat, time))
    }
    entries.append(.timeInfo(presentationData.theme, presentationData.strings.InviteLink_Create_TimeLimitInfo))
    
    if !state.requestApproval || isPublic {
        entries.append(.usageHeader(presentationData.theme,  presentationData.strings.InviteLink_Create_UsersLimit.uppercased()))
        entries.append(.usagePicker(presentationData.theme, presentationData.dateTimeFormat, state.usage))
        
        var customValue = false
        if case .custom = state.usage {
            customValue = true
        }
        entries.append(.usageCustomPicker(presentationData.theme, state.usage.value, state.pickingUsageLimit, customValue))
        entries.append(.usageInfo(presentationData.theme, presentationData.strings.InviteLink_Create_UsersLimitInfo))
    }
    
    if let _ = invite {
        entries.append(.revoke(presentationData.theme, presentationData.strings.InviteLink_Create_Revoke))
    }
    
    return entries
}

private struct InviteLinkEditControllerState: Equatable {
    var title: String
    var usage: InviteLinkUsageLimit
    var time: InviteLinkTimeLimit
    var requestApproval = false
    var pickingTimeLimit = false
    var pickingUsageLimit = false
    var updating = false
}

public func inviteLinkEditController(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, peerId: EnginePeer.Id, invite: ExportedInvitation?, completion: ((ExportedInvitation?) -> Void)? = nil) -> ViewController {
    var presentControllerImpl: ((ViewController, ViewControllerPresentationArguments?) -> Void)?
    let actionsDisposable = DisposableSet()

    let initialState: InviteLinkEditControllerState
    if let invite = invite, case let .link(_, title, _, requestApproval, _, _, _, _, expireDate, usageLimit, count, _) = invite {
        var usageLimit = usageLimit
        if let limit = usageLimit, let count = count, count > 0 {
            usageLimit = limit - count
        }
        
        let timeLimit: InviteLinkTimeLimit
        let currentTime = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
        if let expireDate = expireDate {
            if currentTime >= expireDate {
                timeLimit = .day
            } else {
                timeLimit = .custom(expireDate)
            }
        } else {
            timeLimit = .unlimited
        }
        
        initialState = InviteLinkEditControllerState(title: title ?? "", usage: InviteLinkUsageLimit(value: usageLimit), time: timeLimit, requestApproval: requestApproval, pickingTimeLimit: false, pickingUsageLimit: false)
    } else {
        initialState = InviteLinkEditControllerState(title: "", usage: .unlimited, time: .unlimited, requestApproval: false, pickingTimeLimit: false, pickingUsageLimit: false)
    }
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((InviteLinkEditControllerState) -> InviteLinkEditControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }

    var dismissImpl: (() -> Void)?
    var dismissInputImpl: (() -> Void)?
    var scrollToUsageImpl: (() -> Void)?
    
    let arguments = InviteLinkEditControllerArguments(context: context, updateState: { f in
        updateState(f)
    }, scrollToUsage: {
        scrollToUsageImpl?()
    }, dismissInput: {
       dismissInputImpl?()
    }, revoke: {
        guard let inviteLink = invite?.link else {
            return
        }
        let _ = (context.account.postbox.loadedPeerWithId(peerId)
        |> deliverOnMainQueue).start(next: { peer in
            let isGroup: Bool
            if let peer = peer as? TelegramChannel, case .broadcast = peer.info {
                isGroup = false
            } else {
                isGroup = true
            }
            let presentationData = updatedPresentationData?.initial ?? context.sharedContext.currentPresentationData.with { $0 }
            let controller = ActionSheetController(presentationData: presentationData)
            let dismissAction: () -> Void = { [weak controller] in
                controller?.dismissAnimated()
            }
            controller.setItemGroups([
                ActionSheetItemGroup(items: [
                    ActionSheetTextItem(title: isGroup ? presentationData.strings.GroupInfo_InviteLink_RevokeAlert_Text : presentationData.strings.ChannelInfo_InviteLink_RevokeAlert_Text),
                    ActionSheetButtonItem(title: presentationData.strings.GroupInfo_InviteLink_RevokeLink, color: .destructive, action: {
                        dismissAction()
                        dismissImpl?()
                        
                        let _ = (context.engine.peers.revokePeerExportedInvitation(peerId: peerId, link: inviteLink)
                        |> timeout(10, queue: Queue.mainQueue(), alternate: .fail(.generic))
                        |> deliverOnMainQueue).start(next: { invite in
                            switch invite {
                            case .none:
                                completion?(nil)
                            case let .update(invitation):
                                completion?(invitation)
                            case let .replace(_, invitation):
                                completion?(invitation)
                            }
                            
                            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                            presentControllerImpl?(UndoOverlayController(presentationData: presentationData, content: .linkRevoked(text: presentationData.strings.InviteLink_InviteLinkRevoked), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), nil)
                        }, error: { _ in
                            updateState { state in
                                var updatedState = state
                                updatedState.updating = false
                                return updatedState
                            }
                            presentControllerImpl?(textAlertController(context: context, updatedPresentationData: updatedPresentationData, title: nil, text: presentationData.strings.Login_UnknownError, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), nil)
                        })
                    })
                ]),
                ActionSheetItemGroup(items: [ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, action: { dismissAction() })])
            ])
            presentControllerImpl?(controller, nil)
        })
    })
    
    let presentationData = updatedPresentationData?.signal ?? context.sharedContext.presentationData
    
    let previousState = Atomic<InviteLinkEditControllerState?>(value: nil)
    let signal = combineLatest(
        presentationData,
        statePromise.get(),
        context.engine.data.subscribe(
            TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)
        ))
    |> deliverOnMainQueue
    |> map { presentationData, state, peer -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let isPublic = !(peer?.addressName?.isEmpty ?? true)
        
        let leftNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Cancel), style: .regular, enabled: true, action: {
            dismissImpl?()
        })
        
        let rightNavigationButton = ItemListNavigationButton(content: .text(invite == nil ? presentationData.strings.Common_Create : presentationData.strings.Common_Save), style: state.updating ? .activity : .bold, enabled: true, action: {
            updateState { state in
                var updatedState = state
                updatedState.updating = true
                return updatedState
            }
            
            let expireDate: Int32?
            if case let .custom(value) = state.time {
                expireDate = value
            } else if let value = state.time.value {
                let currentTime = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
                expireDate = currentTime + value
            } else {
                expireDate = 0
            }

            let titleString = state.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let title = titleString.isEmpty ? nil : titleString
            let usageLimit = state.usage.value
            let requestNeeded = state.requestApproval && !isPublic
            
            if invite == nil {
                let _ = (context.engine.peers.createPeerExportedInvitation(peerId: peerId, title: title, expireDate: expireDate, usageLimit: requestNeeded ? 0 : usageLimit, requestNeeded: requestNeeded)
                |> timeout(10, queue: Queue.mainQueue(), alternate: .fail(.generic))
                |> deliverOnMainQueue).start(next: { invite in
                    completion?(invite)
                    dismissImpl?()
                }, error: { _ in
                    updateState { state in
                        var updatedState = state
                        updatedState.updating = false
                        return updatedState
                    }
                    presentControllerImpl?(textAlertController(context: context, updatedPresentationData: updatedPresentationData, title: nil, text: presentationData.strings.Login_UnknownError, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), nil)
                })
            } else if let initialInvite = invite, case let .link(link, _, _, initialRequestApproval, _, _, _, _, initialExpireDate, initialUsageLimit, _, _) = initialInvite {
                if initialExpireDate == expireDate && initialUsageLimit == usageLimit && initialRequestApproval == requestNeeded {
                    completion?(initialInvite)
                    dismissImpl?()
                    return
                }
                let _ = (context.engine.peers.editPeerExportedInvitation(peerId: peerId, link: link, title: title, expireDate: expireDate, usageLimit: requestNeeded ? 0 : usageLimit, requestNeeded: requestNeeded)
                |> timeout(10, queue: Queue.mainQueue(), alternate: .fail(.generic))
                |> deliverOnMainQueue).start(next: { invite in
                    completion?(invite)
                    dismissImpl?()
                }, error: { _ in
                    updateState { state in
                        var updatedState = state
                        updatedState.updating = false
                        return updatedState
                    }
                    presentControllerImpl?(textAlertController(context: context, updatedPresentationData: updatedPresentationData, title: nil, text: presentationData.strings.Login_UnknownError, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), nil)
                })
            }
        })
        
        let previousState = previousState.swap(state)
        var animateChanges = false
        if let previousState = previousState, previousState.pickingTimeLimit != state.pickingTimeLimit || previousState.requestApproval != state.requestApproval {
            animateChanges = true
        }
        
        let isGroup: Bool
        if case let .channel(channel) = peer, case .broadcast = channel.info {
            isGroup = false
        } else {
            isGroup = true
        }
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(invite == nil ? presentationData.strings.InviteLink_Create_Title : presentationData.strings.InviteLink_Create_EditTitle), leftNavigationButton: leftNavigationButton, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: true)
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: inviteLinkEditControllerEntries(invite: invite, state: state, isGroup: isGroup, isPublic: isPublic, presentationData: presentationData), style: .blocks, emptyStateItem: nil, crossfadeState: false, animateChanges: animateChanges)
        
        return (controllerState, (listState, arguments))
    }
    |> afterDisposed {
        actionsDisposable.dispose()
    }
    
    let controller = ItemListController(context: context, state: signal)
    controller.beganInteractiveDragging = {
        dismissInputImpl?()
    }
    presentControllerImpl = { [weak controller] c, p in
        if let controller = controller {
            controller.present(c, in: .window(.root), with: p)
        }
    }
    scrollToUsageImpl = { [weak controller] in
        controller?.afterLayout({
            guard let controller = controller else {
                return
            }
            
            var resultItemNode: ListViewItemNode?
            let _ = controller.frameForItemNode({ itemNode in
                if let itemNode = itemNode as? ItemListSingleLineInputItemNode {
                    if let tag = itemNode.tag as? InviteLinksEditEntryTag, tag == .usage {
                        resultItemNode = itemNode
                        return true
                    }
                }
                return false
            })
            if let resultItemNode = resultItemNode {
                controller.ensureItemNodeVisible(resultItemNode)
            }
        })
    }
    dismissInputImpl = { [weak controller] in
        controller?.view.endEditing(true)
    }
    dismissImpl = { [weak controller] in
        controller?.dismiss()
    }
    return controller
}
