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
import ItemListDatePickerItem
import TextFormat

private final class InviteLinkEditControllerArguments {
    let context: AccountContext
    let updateState: ((InviteLinkEditControllerState) -> InviteLinkEditControllerState) -> Void
    let focusOnItem: (InviteLinksEditEntryTag) -> Void
    let errorWithItem: (InviteLinksEditEntryTag) -> Void
    let scrollToUsage: () -> Void
    let dismissInput: () -> Void
    let revoke: () -> Void
    
    init(
        context: AccountContext, 
        updateState: @escaping ((InviteLinkEditControllerState) -> InviteLinkEditControllerState) -> Void,
        focusOnItem: @escaping (InviteLinksEditEntryTag) -> Void,
        errorWithItem: @escaping (InviteLinksEditEntryTag) -> Void,
        scrollToUsage: @escaping () -> Void,
        dismissInput: @escaping () -> Void,
        revoke: @escaping () -> Void)
    {
        self.context = context
        self.updateState = updateState
        self.focusOnItem = focusOnItem
        self.errorWithItem = errorWithItem
        self.scrollToUsage = scrollToUsage
        self.dismissInput = dismissInput
        self.revoke = revoke
    }
}

private enum InviteLinksEditSection: Int32 {
    case title
    case subscriptionFee
    case requestApproval
    case time
    case usage
    case revoke
}

private enum InviteLinksEditEntryTag: ItemListItemTag {
    case subscriptionFee
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
    
    
    case subscriptionFeeToggle(PresentationTheme, String, Bool, Bool)
    case subscriptionFee(PresentationTheme, String, Bool, Int64?, String, Int64?)
    case subscriptionFeeInfo(PresentationTheme, String)
    
    case requestApproval(PresentationTheme, String, Bool, Bool)
    case requestApprovalInfo(PresentationTheme, String)
    
    case timeHeader(PresentationTheme, String)
    case timePicker(PresentationTheme, InviteLinkTimeLimit, Bool)
    case timeExpiryDate(PresentationTheme, PresentationDateTimeFormat, Int32?, Bool, Bool)
    case timeCustomPicker(PresentationTheme, PresentationDateTimeFormat, Int32?, Bool, Bool, Bool)
    case timeInfo(PresentationTheme, String)
    
    case usageHeader(PresentationTheme, String)
    case usagePicker(PresentationTheme, PresentationDateTimeFormat, InviteLinkUsageLimit, Bool)
    case usageCustomPicker(PresentationTheme, Int32?, Bool, Bool, Bool)
    case usageInfo(PresentationTheme, String)
    
    case revoke(PresentationTheme, String)
   
    var section: ItemListSectionId {
        switch self {
            case .titleHeader, .title, .titleInfo:
                return InviteLinksEditSection.title.rawValue
            case .subscriptionFeeToggle, .subscriptionFee, .subscriptionFeeInfo:
                return InviteLinksEditSection.subscriptionFee.rawValue
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
            case .subscriptionFeeToggle:
                return 3
            case .subscriptionFee:
                return 4
            case .subscriptionFeeInfo:
                return 5
            case .requestApproval:
                return 6
            case .requestApprovalInfo:
                return 7
            case .timeHeader:
                return 8
            case .timePicker:
                return 9
            case .timeExpiryDate:
                return 10
            case .timeCustomPicker:
                return 11
            case .timeInfo:
                return 12
            case .usageHeader:
                return 13
            case .usagePicker:
                return 14
            case .usageCustomPicker:
                return 15
            case .usageInfo:
                return 16
            case .revoke:
                return 17
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
            case let .subscriptionFeeToggle(lhsTheme, lhsText, lhsValue, lhsEnabled):
                if case let .subscriptionFeeToggle(rhsTheme, rhsText, rhsValue, rhsEnabled) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue, lhsEnabled == rhsEnabled {
                    return true
                } else {
                    return false
                }
            case let .subscriptionFee(lhsTheme, lhsText, lhsValue, lhsEnabled, lhsLabel, lhsMaxValue):
                if case let .subscriptionFee(rhsTheme, rhsText, rhsValue, rhsEnabled, rhsLabel, rhsMaxValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue, lhsEnabled == rhsEnabled, lhsLabel == rhsLabel, lhsMaxValue == rhsMaxValue {
                    return true
                } else {
                    return false
                }
            case let .subscriptionFeeInfo(lhsTheme, lhsText):
                if case let .subscriptionFeeInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .requestApproval(lhsTheme, lhsText, lhsValue, lhsEnabled):
                if case let .requestApproval(rhsTheme, rhsText, rhsValue, rhsEnabled) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue, lhsEnabled == rhsEnabled {
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
            case let .timePicker(lhsTheme, lhsValue, lhsEnabled):
                if case let .timePicker(rhsTheme, rhsValue, rhsEnabled) = rhs, lhsTheme === rhsTheme, lhsValue == rhsValue, lhsEnabled == rhsEnabled {
                    return true
                } else {
                    return false
                }
            case let .timeExpiryDate(lhsTheme, lhsDateTimeFormat, lhsDate, lhsActive, lhsEnabled):
                if case let .timeExpiryDate(rhsTheme, rhsDateTimeFormat, rhsDate, rhsActive, rhsEnabled) = rhs, lhsTheme === rhsTheme, lhsDateTimeFormat == rhsDateTimeFormat, lhsDate == rhsDate, lhsActive == rhsActive, lhsEnabled == rhsEnabled {
                    return true
                } else {
                    return false
                }
            case let .timeCustomPicker(lhsTheme, lhsDateTimeFormat, lhsDate, lhsDisplayingDateSelection, lhsDisplayingTimeSelection, lhsEnabled):
                if case let .timeCustomPicker(rhsTheme, rhsDateTimeFormat, rhsDate, rhsDisplayingDateSelection, rhsDisplayingTimeSelection, rhsEnabled) = rhs, lhsTheme === rhsTheme, lhsDateTimeFormat == rhsDateTimeFormat, lhsDate == rhsDate, lhsDisplayingDateSelection == rhsDisplayingDateSelection, lhsDisplayingTimeSelection == rhsDisplayingTimeSelection, lhsEnabled == rhsEnabled {
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
            case let .usagePicker(lhsTheme, lhsDateTimeFormat, lhsValue, lhsEnabled):
                if case let .usagePicker(rhsTheme, rhsDateTimeFormat, rhsValue, rhsEnabled) = rhs, lhsTheme === rhsTheme, lhsDateTimeFormat == rhsDateTimeFormat, lhsValue == rhsValue, lhsEnabled == rhsEnabled {
                    return true
                } else {
                    return false
                }
            case let .usageCustomPicker(lhsTheme, lhsValue, lhsFocused, lhsCustomValue, lhsEnabled):
                if case let .usageCustomPicker(rhsTheme, rhsValue, rhsFocused, rhsCustomValue, rhsEnabled) = rhs, lhsTheme === rhsTheme, lhsValue == rhsValue, lhsFocused == rhsFocused, lhsCustomValue == rhsCustomValue, lhsEnabled == rhsEnabled {
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
                return ItemListSingleLineInputItem(context: arguments.context, presentationData: presentationData, title: NSAttributedString(), text: value, placeholder: placeholder, maxLength: 32, sectionId: self.section, textUpdated: { value in
                    arguments.updateState { state in
                        var updatedState = state
                        updatedState.title = value
                        return updatedState
                    }
                }, action: {})
            case let .titleInfo(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
            case let .subscriptionFeeToggle(_, text, value, enabled):
                return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, enabled: enabled, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.updateState { state in
                        var updatedState = state
                        updatedState.subscriptionEnabled = value
                        if value {
                            updatedState.requestApproval = false
                        } else {
                            updatedState.subscriptionFee = nil
                        }
                        return updatedState
                    }
                    if value {
                        Queue.mainQueue().after(0.1) {
                            arguments.focusOnItem(.subscriptionFee)
                        }
                    }
                })
            case let .subscriptionFee(_, placeholder, enabled, value, label, maxValue):
                let title = NSMutableAttributedString(string: "⭐️", font: Font.semibold(18.0), textColor: .white)
                if let range = title.string.range(of: "⭐️") {
                    title.addAttribute(ChatTextInputAttributes.customEmoji, value: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: 0, file: nil, custom: .stars(tinted: false)), range: NSRange(range, in: title.string))
                    title.addAttribute(.baselineOffset, value: -1.0, range: NSRange(range, in: title.string))
                }
                return ItemListSingleLineInputItem(context: arguments.context, presentationData: presentationData, title: title, text: value.flatMap { "\($0)" } ?? "", placeholder: placeholder, label: label, type: .number, spacing: 3.0, enabled: enabled, tag: InviteLinksEditEntryTag.subscriptionFee, sectionId: self.section, textUpdated: { text in
                    arguments.updateState { state in
                        var updatedState = state
                        if var value = Int64(text) {
                            if let maxValue, value > maxValue {
                                value = maxValue
                                arguments.errorWithItem(.subscriptionFee)
                            }
                            updatedState.subscriptionFee = value
                        } else {
                            updatedState.subscriptionFee = nil
                        }
                        return updatedState
                    }
                },  action: {})
            case let .subscriptionFeeInfo(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .markdown(text), sectionId: self.section)
            case let .requestApproval(_, text, value, enabled):
                return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, enabled: enabled, sectionId: self.section, style: .blocks, updated: { value in
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
            case let .timePicker(_, value, enabled):
                return ItemListInviteLinkTimeLimitItem(theme: presentationData.theme, strings: presentationData.strings, value: value, enabled: enabled, sectionId: self.section, updated: { value in
                    arguments.updateState({ state in
                        var updatedState = state
                        if value != updatedState.time {
                            updatedState.pickingExpiryDate = false
                            updatedState.pickingExpiryTime = false
                        }
                        updatedState.time = value
                        return updatedState
                    })
                })
            case let .timeExpiryDate(theme, dateTimeFormat, value, active, enabled):
                let text: String
                if let value = value {
                    text = stringForMediumDate(timestamp: value, strings: presentationData.strings, dateTimeFormat: dateTimeFormat)
                } else {
                    text = presentationData.strings.InviteLink_Create_TimeLimitExpiryDateNever
                }
                return ItemListDisclosureItem(presentationData: presentationData, title: presentationData.strings.InviteLink_Create_TimeLimitExpiryDate, enabled: enabled, label: text, labelStyle: active ? .coloredText(theme.list.itemAccentColor) : .text, sectionId: self.section, style: .blocks, disclosureStyle: .none, action: {
                    arguments.dismissInput()
                    arguments.updateState { state in
                        var updatedState = state
                        if updatedState.pickingExpiryTime {
                            updatedState.pickingExpiryTime = false
                        } else {
                            updatedState.pickingExpiryDate = !state.pickingExpiryDate
                        }
                        return updatedState
                    }
                })
            case let .timeCustomPicker(_, dateTimeFormat, date, displayingDateSelection, displayingTimeSelection, enabled):
                let _ = enabled
                let title = presentationData.strings.InviteLink_Create_TimeLimitExpiryTime
                return ItemListDatePickerItem(presentationData: presentationData, dateTimeFormat: dateTimeFormat, date: date, title: title, displayingDateSelection: displayingDateSelection, displayingTimeSelection: displayingTimeSelection, sectionId: self.section, style: .blocks, toggleDateSelection: {
                    arguments.updateState({ state in
                        var updatedState = state
                        updatedState.pickingExpiryDate = !updatedState.pickingExpiryDate
                        if updatedState.pickingExpiryDate {
                            updatedState.pickingExpiryTime = false
                        }
                        return updatedState
                    })
                }, toggleTimeSelection: {
                    arguments.updateState({ state in
                        var updatedState = state
                        updatedState.pickingExpiryTime = !updatedState.pickingExpiryTime
                        if updatedState.pickingExpiryTime {
                            updatedState.pickingExpiryDate = false
                        }
                        return updatedState
                    })
                }, updated: { date in
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
            case let .usagePicker(_, dateTimeFormat, value, enabled):
                return ItemListInviteLinkUsageLimitItem(theme: presentationData.theme, strings: presentationData.strings, dateTimeFormat: dateTimeFormat, value: value, enabled: enabled, sectionId: self.section, updated: { value in
                    arguments.dismissInput()
                    arguments.updateState({ state in
                        var updatedState = state
                        if value != updatedState.usage {
                            updatedState.pickingExpiryDate = false
                            updatedState.pickingExpiryTime = false
                        }
                        updatedState.usage = value
                        return updatedState
                    })
                })
            case let .usageCustomPicker(theme, value, focused, customValue, enabled):
                let text: String
                if let value = value, value != 0 {
                    text = String(value)
                } else {
                    text = focused ? "" : presentationData.strings.InviteLink_Create_UsersLimitNumberOfUsersUnlimited
                }
                return ItemListSingleLineInputItem(context: arguments.context, presentationData: presentationData, title: NSAttributedString(string: presentationData.strings.InviteLink_Create_UsersLimitNumberOfUsers, textColor: theme.list.itemPrimaryTextColor), text: text, placeholder: "", type: .number, alignment: .right, enabled: enabled, selectAllOnFocus: true, secondaryStyle: !customValue, tag: InviteLinksEditEntryTag.usage, sectionId: self.section, textUpdated: { updatedText in
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
                            updatedState.pickingExpiryDate = false
                            updatedState.pickingExpiryTime = false
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

private func inviteLinkEditControllerEntries(invite: ExportedInvitation?, state: InviteLinkEditControllerState, isGroup: Bool, isPublic: Bool, presentationData: PresentationData, configuration: StarsSubscriptionConfiguration) -> [InviteLinksEditEntry] {
    var entries: [InviteLinksEditEntry] = []
    
    entries.append(.titleHeader(presentationData.theme, presentationData.strings.InviteLink_Create_LinkNameTitle.uppercased()))
    entries.append(.title(presentationData.theme, presentationData.strings.InviteLink_Create_LinkName, state.title))
    entries.append(.titleInfo(presentationData.theme, presentationData.strings.InviteLink_Create_LinkNameInfo))
    
    let isEditingEnabled = invite?.pricing == nil
    let isSubscription = state.subscriptionEnabled
    if !isGroup {
        entries.append(.subscriptionFeeToggle(presentationData.theme, presentationData.strings.InviteLink_Create_Fee, state.subscriptionEnabled, isEditingEnabled))
        if state.subscriptionEnabled {
            var label: String = ""
            if let subscriptionFee = state.subscriptionFee, subscriptionFee > 0 {
                var usdRate = 0.012
                if let usdWithdrawRate = configuration.usdWithdrawRate {
                    usdRate = Double(usdWithdrawRate) / 1000.0 / 100.0
                }
                label = presentationData.strings.InviteLink_Create_FeePerMonth("≈\(formatTonUsdValue(subscriptionFee, divide: false, rate: usdRate, dateTimeFormat: presentationData.dateTimeFormat))").string
            }
            entries.append(.subscriptionFee(presentationData.theme, presentationData.strings.InviteLink_Create_FeePlaceholder, isEditingEnabled, state.subscriptionFee, label, configuration.maxFee))
        }
        let infoText: String
        if let _ = invite, state.subscriptionEnabled {
            infoText = presentationData.strings.InviteLink_Create_FeeEditInfo
        } else {
            infoText = presentationData.strings.InviteLink_Create_FeeInfo
        }
        entries.append(.subscriptionFeeInfo(presentationData.theme, infoText))
    }
    
    if !isPublic {
        entries.append(.requestApproval(presentationData.theme, presentationData.strings.InviteLink_Create_RequestApproval, state.requestApproval, isEditingEnabled && !isSubscription))
        var requestApprovalInfoText = presentationData.strings.InviteLink_Create_RequestApprovalOffInfoChannel
        if isSubscription {
            requestApprovalInfoText = presentationData.strings.InviteLink_Create_RequestApprovalFeeUnavailable
        } else {
            if state.requestApproval {
                requestApprovalInfoText = isGroup ? presentationData.strings.InviteLink_Create_RequestApprovalOnInfoGroup : presentationData.strings.InviteLink_Create_RequestApprovalOnInfoChannel
            } else {
                requestApprovalInfoText = isGroup ? presentationData.strings.InviteLink_Create_RequestApprovalOnInfoGroup : presentationData.strings.InviteLink_Create_RequestApprovalOffInfoChannel
            }
        }
        entries.append(.requestApprovalInfo(presentationData.theme, requestApprovalInfoText))
    }
    
    entries.append(.timeHeader(presentationData.theme,  presentationData.strings.InviteLink_Create_TimeLimit.uppercased()))
    entries.append(.timePicker(presentationData.theme, state.time, isEditingEnabled))
    
    let currentTime = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
    var time: Int32?
    if case let .custom(value) = state.time {
        time = value
    } else if let value = state.time.value {
        time = currentTime + value
    }
    entries.append(.timeExpiryDate(presentationData.theme, presentationData.dateTimeFormat, time, state.pickingExpiryDate || state.pickingExpiryTime, isEditingEnabled))
    if state.pickingExpiryDate || state.pickingExpiryTime {
        entries.append(.timeCustomPicker(presentationData.theme, presentationData.dateTimeFormat, time, state.pickingExpiryDate, state.pickingExpiryTime, isEditingEnabled))
    }
    entries.append(.timeInfo(presentationData.theme, presentationData.strings.InviteLink_Create_TimeLimitInfo))
    
    if !state.requestApproval || isPublic {
        entries.append(.usageHeader(presentationData.theme,  presentationData.strings.InviteLink_Create_UsersLimit.uppercased()))
        entries.append(.usagePicker(presentationData.theme, presentationData.dateTimeFormat, state.usage, isEditingEnabled))
        
        var customValue = false
        if case .custom = state.usage {
            customValue = true
        }
        entries.append(.usageCustomPicker(presentationData.theme, state.usage.value, state.pickingUsageLimit, customValue, isEditingEnabled))
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
    var subscriptionEnabled = false
    var subscriptionFee: Int64?
    var pickingExpiryDate = false
    var pickingExpiryTime = false
    var pickingUsageLimit = false
    var updating = false
}

public func inviteLinkEditController(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, peerId: EnginePeer.Id, invite: ExportedInvitation?, completion: ((ExportedInvitation?) -> Void)? = nil) -> ViewController {
    var presentControllerImpl: ((ViewController, ViewControllerPresentationArguments?) -> Void)?
    let actionsDisposable = DisposableSet()

    let initialState: InviteLinkEditControllerState
    if let invite = invite, case let .link(_, title, _, requestApproval, _, _, _, _, expireDate, usageLimit, count, _, pricing) = invite {
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
        
        initialState = InviteLinkEditControllerState(title: title ?? "", usage: InviteLinkUsageLimit(value: usageLimit), time: timeLimit, requestApproval: requestApproval, subscriptionEnabled: pricing != nil, subscriptionFee: pricing?.amount, pickingExpiryDate: false, pickingExpiryTime: false, pickingUsageLimit: false)
    } else {
        initialState = InviteLinkEditControllerState(title: "", usage: .unlimited, time: .unlimited, requestApproval: false, subscriptionEnabled: false, subscriptionFee: nil, pickingExpiryDate: false, pickingExpiryTime: false, pickingUsageLimit: false)
    }
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((InviteLinkEditControllerState) -> InviteLinkEditControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }

    var dismissImpl: (() -> Void)?
    var dismissInputImpl: (() -> Void)?
    var scrollToUsageImpl: (() -> Void)?
    var focusImpl: ((InviteLinksEditEntryTag) -> Void)?
    var errorImpl: ((InviteLinksEditEntryTag) -> Void)?
    
    let arguments = InviteLinkEditControllerArguments(context: context, updateState: { f in
        updateState(f)
    }, focusOnItem: { tag in
        focusImpl?(tag)
    }, errorWithItem: { tag in
        errorImpl?(tag)
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
    
    let configuration = StarsSubscriptionConfiguration.with(appConfiguration: context.currentAppConfiguration.with { $0 })
    
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
        
        var doneIsEnabled = true
        if state.subscriptionEnabled {
            if (state.subscriptionFee ?? 0) == 0 {
                doneIsEnabled = false
            }
        }
        
        let rightNavigationButton = ItemListNavigationButton(content: .text(invite == nil ? presentationData.strings.Common_Create : presentationData.strings.Common_Save), style: state.updating ? .activity : .bold, enabled: doneIsEnabled, action: {
            updateState { state in
                var updatedState = state
                updatedState.updating = true
                return updatedState
            }
            
            var expireDate: Int32?
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
            var usageLimit = state.usage.value
            var requestNeeded: Bool? = state.requestApproval && !isPublic
            
            if invite == nil {
                let subscriptionPricing: StarsSubscriptionPricing?
                if let subscriptionFee = state.subscriptionFee {
                    subscriptionPricing = StarsSubscriptionPricing(
                        period: context.account.testingEnvironment ? StarsSubscriptionPricing.testPeriod : StarsSubscriptionPricing.monthPeriod,
                        amount: subscriptionFee
                    )
                } else {
                    subscriptionPricing = nil
                }
                let _ = (context.engine.peers.createPeerExportedInvitation(peerId: peerId, title: title, expireDate: expireDate, usageLimit: requestNeeded == true ? 0 : usageLimit, requestNeeded: requestNeeded, subscriptionPricing: subscriptionPricing)
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
            } else if let initialInvite = invite, case let .link(link, initialTitle, _, initialRequestApproval, _, _, _, _, initialExpireDate, initialUsageLimit, _, _, _) = initialInvite {
                if (initialExpireDate ?? 0) == expireDate && (initialUsageLimit ?? 0) == usageLimit && initialRequestApproval == requestNeeded && (initialTitle ?? "") == title {
                    completion?(initialInvite)
                    dismissImpl?()
                    return
                }
                
                if (initialExpireDate ?? 0) == expireDate {
                    expireDate = nil
                }
                if (initialUsageLimit ?? 0) == usageLimit {
                    usageLimit = nil
                }
                if initialRequestApproval == requestNeeded {
                    requestNeeded = nil
                }
                
                let _ = (context.engine.peers.editPeerExportedInvitation(peerId: peerId, link: link, title: title, expireDate: expireDate, usageLimit: requestNeeded == true ? 0 : usageLimit, requestNeeded: requestNeeded)
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
        if let previousState = previousState, previousState.pickingExpiryDate != state.pickingExpiryDate || previousState.pickingExpiryTime != state.pickingExpiryTime || previousState.requestApproval != state.requestApproval || previousState.subscriptionEnabled != state.subscriptionEnabled {
            animateChanges = true
        }
        
        let isGroup: Bool
        if case let .channel(channel) = peer, case .broadcast = channel.info {
            isGroup = false
        } else {
            isGroup = true
        }
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(invite == nil ? presentationData.strings.InviteLink_Create_Title : presentationData.strings.InviteLink_Create_EditTitle), leftNavigationButton: leftNavigationButton, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: true)
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: inviteLinkEditControllerEntries(invite: invite, state: state, isGroup: isGroup, isPublic: isPublic, presentationData: presentationData, configuration: configuration), style: .blocks, emptyStateItem: nil, crossfadeState: false, animateChanges: animateChanges)
        
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
    focusImpl = { [weak controller] targetTag in
        controller?.forEachItemNode { itemNode in
            if let itemNode = itemNode as? ItemListSingleLineInputItemNode, let tag = itemNode.tag, tag.isEqual(to: targetTag) {
                itemNode.focus()
            }
        }
    }
    let hapticFeedback = HapticFeedback()
    errorImpl = { [weak controller] targetTag in
        hapticFeedback.error()
        controller?.forEachItemNode { itemNode in
            if let itemNode = itemNode as? ItemListSingleLineInputItemNode, let tag = itemNode.tag, tag.isEqual(to: targetTag) {
                itemNode.animateError()
            }
        }
    }
    return controller
}

struct StarsSubscriptionConfiguration {
    static var defaultValue: StarsSubscriptionConfiguration {
        return StarsSubscriptionConfiguration(maxFee: 2500, usdWithdrawRate: 1200)
    }
    
    let maxFee: Int64?
    let usdWithdrawRate: Int64?
    
    fileprivate init(maxFee: Int64?, usdWithdrawRate: Int64?) {
        self.maxFee = maxFee
        self.usdWithdrawRate = usdWithdrawRate
    }
    
    public static func with(appConfiguration: AppConfiguration) -> StarsSubscriptionConfiguration {
        if let data = appConfiguration.data, let value = data["stars_subscription_amount_max"] as? Double, let usdRate = data["stars_usd_withdraw_rate_x1000"] as? Double {
            return StarsSubscriptionConfiguration(maxFee: Int64(value), usdWithdrawRate: Int64(usdRate))
        } else {
            return .defaultValue
        }
    }
}
