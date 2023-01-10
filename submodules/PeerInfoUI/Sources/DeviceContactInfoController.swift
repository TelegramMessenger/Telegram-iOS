import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import MessageUI
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import TelegramStringFormatting
import AccountContext
import AlertUI
import PresentationDataUtils
import PhotoResources
import MediaResources
import LocationResources
import ItemListAvatarAndNameInfoItem
import Geocoding
import ItemListAddressItem
import LocalizedPeerData
import PhoneNumberFormat
import UndoUI

private enum DeviceContactInfoAction {
    case sendMessage
    case createContact
    case addToExisting
    case invite
}

private final class DeviceContactInfoControllerArguments {
    let context: AccountContext
    let isPlain: Bool
    let updateEditingName: (ItemListAvatarAndNameInfoItemName) -> Void
    let updatePhone: (Int64, String) -> Void
    let updatePhoneLabel: (Int64, String) -> Void
    let deletePhone: (Int64) -> Void
    let setPhoneIdWithRevealedOptions: (Int64?, Int64?) -> Void
    let addPhoneNumber: () -> Void
    let performAction: (DeviceContactInfoAction) -> Void
    let toggleSelection: (DeviceContactInfoDataId) -> Void
    let callPhone: (String) -> Void
    let openUrl: (String) -> Void
    let openAddress: (DeviceContactAddressData) -> Void
    let displayCopyContextMenu: (DeviceContactInfoEntryTag, String) -> Void
    let updateShareViaException: (Bool) -> Void
    
    init(context: AccountContext, isPlain: Bool, updateEditingName: @escaping (ItemListAvatarAndNameInfoItemName) -> Void, updatePhone: @escaping (Int64, String) -> Void, updatePhoneLabel: @escaping (Int64, String) -> Void, deletePhone: @escaping (Int64) -> Void, setPhoneIdWithRevealedOptions: @escaping (Int64?, Int64?) -> Void, addPhoneNumber: @escaping () -> Void, performAction: @escaping (DeviceContactInfoAction) -> Void, toggleSelection: @escaping (DeviceContactInfoDataId) -> Void, callPhone: @escaping (String) -> Void, openUrl: @escaping (String) -> Void, openAddress: @escaping (DeviceContactAddressData) -> Void, displayCopyContextMenu: @escaping (DeviceContactInfoEntryTag, String) -> Void, updateShareViaException: @escaping (Bool) -> Void) {
        self.context = context
        self.isPlain = isPlain
        self.updateEditingName = updateEditingName
        self.updatePhone = updatePhone
        self.updatePhoneLabel = updatePhoneLabel
        self.deletePhone = deletePhone
        self.setPhoneIdWithRevealedOptions = setPhoneIdWithRevealedOptions
        self.addPhoneNumber = addPhoneNumber
        self.performAction = performAction
        self.toggleSelection = toggleSelection
        self.callPhone = callPhone
        self.openUrl = openUrl
        self.openAddress = openAddress
        self.displayCopyContextMenu = displayCopyContextMenu
        self.updateShareViaException = updateShareViaException
    }
}

private enum DeviceContactInfoSection: ItemListSectionId {
    case info
    case editing
    case data
    case share
}

private enum DeviceContactInfoEntryTag: Equatable, ItemListItemTag {
    case info(Int)
    case birthday
    case editingPhone(Int64)
    case note
    
    func isEqual(to other: ItemListItemTag) -> Bool {
        return self == (other as? DeviceContactInfoEntryTag)
    }
}

private enum DeviceContactInfoDataId: Hashable {
    case job
    case phoneNumber(String, String)
    case email(String, String)
    case url(String, String)
    case address(DeviceContactAddressData)
    case birthday
    case socialProfile(DeviceContactSocialProfileData)
    case instantMessenger(DeviceContactInstantMessagingProfileData)
    case note
}

private enum DeviceContactInfoConstantEntryId: Hashable {
    case info
    case invite
    case sendMessage
    case createContact
    case addToExisting
    case company
    case birthday
    case addPhoneNumber
    case phoneNumberSharingInfo
    case phoneNumberShareViaException
    case phoneNumberShareViaExceptionInfo
    case note
}

private enum DeviceContactInfoEntryId: Hashable {
    case constant(DeviceContactInfoConstantEntryId)
    case phoneNumber(Int)
    case email(Int)
    case url(Int)
    case address(Int)
    case socialProfile(Int)
    case instantMessenger(Int)
    case editingPhoneNumber(Int64)
}

private enum DeviceContactInfoEntry: ItemListNodeEntry {
    case info(Int, PresentationTheme, PresentationStrings, PresentationDateTimeFormat, peer: Peer, state: ItemListAvatarAndNameInfoItemState, job: String?, isPlain: Bool)
    
    case invite(Int, PresentationTheme, String)
    case sendMessage(Int, PresentationTheme, String)
    case createContact(Int, PresentationTheme, String)
    case addToExisting(Int, PresentationTheme, String)
    
    case company(Int, PresentationTheme, String, String, Bool?)
    case phoneNumber(Int, Int, PresentationTheme, String, String, String, Bool?, Bool)
    case editingPhoneNumber(Int, PresentationTheme, PresentationStrings, Int64, String, String, String, Bool)
    case phoneNumberSharingInfo(Int, PresentationTheme, String)
    case phoneNumberShareViaException(Int, PresentationTheme, String, Bool)
    case phoneNumberShareViaExceptionInfo(Int, PresentationTheme, String)
    case addPhoneNumber(Int, PresentationTheme, String)
    case email(Int, Int, PresentationTheme, String, String, String, Bool?)
    case url(Int, Int, PresentationTheme, String, String, String, Bool?)
    case address(Int, Int, PresentationTheme, String, DeviceContactAddressData, Signal<(TransformImageArguments) -> DrawingContext?, NoError>?, Bool?)
    case birthday(Int, PresentationTheme, String, Date, String, Bool?)
    case socialProfile(Int, Int, PresentationTheme, String, DeviceContactSocialProfileData, String, Bool?)
    case instantMessenger(Int, Int, PresentationTheme, String, DeviceContactInstantMessagingProfileData, String, Bool?)
    case note(Int, PresentationTheme, String, String, Bool?)
    
    var section: ItemListSectionId {
        switch self {
            case .info:
                return DeviceContactInfoSection.info.rawValue
            case .editingPhoneNumber, .addPhoneNumber:
                return DeviceContactInfoSection.editing.rawValue
            case .invite, .sendMessage, .createContact, .addToExisting:
                return DeviceContactInfoSection.info.rawValue
            case .phoneNumberShareViaException, .phoneNumberShareViaExceptionInfo:
                return DeviceContactInfoSection.share.rawValue
            default:
                return DeviceContactInfoSection.data.rawValue
        }
    }
    
    var stableId: DeviceContactInfoEntryId {
        switch self {
            case .info:
                return .constant(.info)
            case .sendMessage:
                return .constant(.sendMessage)
            case .invite:
                return .constant(.invite)
            case .createContact:
                return .constant(.createContact)
            case .addToExisting:
                return .constant(.addToExisting)
            case .company:
                return .constant(.company)
            case let .phoneNumber(_, catIndex, _, _, _, _, _, _):
                return .phoneNumber(catIndex)
            case .phoneNumberSharingInfo:
                return .constant(.phoneNumberSharingInfo)
            case .phoneNumberShareViaException:
                return .constant(.phoneNumberShareViaException)
            case .phoneNumberShareViaExceptionInfo:
                return .constant(.phoneNumberShareViaExceptionInfo)
            case let .editingPhoneNumber(_, _, _, id, _, _, _, _):
                return .editingPhoneNumber(id)
            case .addPhoneNumber:
                return .constant(.addPhoneNumber)
            case let .email(_, catIndex, _, _, _, _, _):
                return .email(catIndex)
            case let .url(_, catIndex, _, _, _, _, _):
                return .url(catIndex)
            case let .address(_, catIndex, _, _, _, _, _):
                return .address(catIndex)
            case .birthday:
                return .constant(.birthday)
            case let .socialProfile(_, catIndex, _, _, _, _, _):
                return .socialProfile(catIndex)
            case let .instantMessenger(_, catIndex, _, _, _, _, _):
                return .instantMessenger(catIndex)
            case .note:
                return .constant(.note)
        }
    }
    
    static func ==(lhs: DeviceContactInfoEntry, rhs: DeviceContactInfoEntry) -> Bool {
        switch lhs {
            case let .info(lhsIndex, lhsTheme, lhsStrings, lhsDateTimeFormat, lhsPeer, lhsState, lhsJobSummary, lhsIsPlain):
                if case let .info(rhsIndex, rhsTheme, rhsStrings, rhsDateTimeFormat, rhsPeer, rhsState, rhsJobSummary, rhsIsPlain) = rhs {
                    if lhsIndex != rhsIndex {
                        return false
                    }
                    if lhsTheme !== rhsTheme {
                        return false
                    }
                    if lhsStrings !== rhsStrings {
                        return false
                    }
                    if lhsDateTimeFormat != rhsDateTimeFormat {
                        return false
                    }
                    if !arePeersEqual(lhsPeer, rhsPeer) {
                        return false
                    }
                    if lhsState != rhsState {
                        return false
                    }
                    if lhsJobSummary != rhsJobSummary {
                        return false
                    }
                    if lhsIsPlain != rhsIsPlain {
                        return false
                    }
                    return true
                } else {
                    return false
                }
            case let .sendMessage(lhsIndex, lhsTheme, lhsTitle):
                if case let .sendMessage(rhsIndex, rhsTheme, rhsTitle) = rhs, lhsIndex == rhsIndex, lhsTheme === rhsTheme, lhsTitle == rhsTitle {
                    return true
                } else {
                    return false
                }
            case let .invite(lhsIndex, lhsTheme, lhsTitle):
                if case let .invite(rhsIndex, rhsTheme, rhsTitle) = rhs, lhsIndex == rhsIndex, lhsTheme === rhsTheme, lhsTitle == rhsTitle {
                    return true
                } else {
                    return false
                }
            case let .createContact(lhsIndex, lhsTheme, lhsTitle):
                if case let .createContact(rhsIndex, rhsTheme, rhsTitle) = rhs, lhsIndex == rhsIndex, lhsTheme === rhsTheme, lhsTitle == rhsTitle {
                    return true
                } else {
                    return false
                }
            case let .addToExisting(lhsIndex, lhsTheme, lhsTitle):
                if case let .addToExisting(rhsIndex, rhsTheme, rhsTitle) = rhs, lhsIndex == rhsIndex, lhsTheme === rhsTheme, lhsTitle == rhsTitle {
                    return true
                } else {
                    return false
                }
            case let .company(lhsIndex, lhsTheme, lhsTitle, lhsValue, lhsSelected):
                if case let .company(rhsIndex, rhsTheme, rhsTitle, rhsValue, rhsSelected) = rhs, lhsIndex == rhsIndex, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsValue == rhsValue, lhsSelected == rhsSelected {
                    return true
                } else {
                    return false
                }
            case let .phoneNumber(lhsIndex, lhsCatIndex, lhsTheme, lhsTitle, lhsLabel, lhsValue, lhsSelected, lhsIsInteractionEnabled):
                if case let .phoneNumber(rhsIndex, rhsCatIndex, rhsTheme, rhsTitle, rhsLabel, rhsValue, rhsSelected, rhsIsInteractionEnabled) = rhs, lhsIndex == rhsIndex, lhsCatIndex == rhsCatIndex, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsLabel == rhsLabel, lhsValue == rhsValue, lhsSelected == rhsSelected, lhsIsInteractionEnabled == rhsIsInteractionEnabled {
                    return true
                } else {
                    return false
                }
            case let .phoneNumberSharingInfo(lhsIndex, lhsTheme, lhsText):
                if case let .phoneNumberSharingInfo(rhsIndex, rhsTheme, rhsText) = rhs, lhsIndex == rhsIndex, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .phoneNumberShareViaException(lhsIndex, lhsTheme, lhsText, lhsValue):
                if case let .phoneNumberShareViaException(rhsIndex, rhsTheme, rhsText, rhsValue) = rhs, lhsIndex == rhsIndex, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .phoneNumberShareViaExceptionInfo(lhsIndex, lhsTheme, lhsText):
                if case let .phoneNumberShareViaExceptionInfo(rhsIndex, rhsTheme, rhsText) = rhs, lhsIndex == rhsIndex, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .editingPhoneNumber(lhsIndex, lhsTheme, lhsStrings, lhsId, lhsTitle, lhsLabel, lhsValue, lhsSelected):
                if case let .editingPhoneNumber(rhsIndex, rhsTheme, rhsStrings, rhsId, rhsTitle, rhsLabel, rhsValue, rhsSelected) = rhs, lhsIndex == rhsIndex, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsId == rhsId, lhsTitle == rhsTitle, lhsLabel == rhsLabel, lhsValue == rhsValue, lhsSelected == rhsSelected {
                    return true
                } else {
                    return false
                }
            case let .addPhoneNumber(lhsIndex, lhsTheme, lhsTitle):
                if case let .addPhoneNumber(rhsIndex, rhsTheme, rhsTitle) = rhs, lhsIndex == rhsIndex, lhsTheme === rhsTheme, lhsTitle == rhsTitle {
                    return true
                } else {
                    return false
                }
            case let .email(lhsIndex, lhsCatIndex, lhsTheme, lhsTitle, lhsLabel, lhsValue, lhsSelected):
                if case let .email(rhsIndex, rhsCatIndex, rhsTheme, rhsTitle, rhsLabel, rhsValue, rhsSelected) = rhs, lhsCatIndex == rhsCatIndex, lhsIndex == rhsIndex, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsLabel == rhsLabel, lhsValue == rhsValue, lhsSelected == rhsSelected {
                    return true
                } else {
                    return false
                }
            case let .url(lhsIndex, lhsCatIndex, lhsTheme, lhsTitle, lhsLabel, lhsValue, lhsSelected):
                if case let .url(rhsIndex, rhsCatIndex, rhsTheme, rhsTitle, rhsLabel, rhsValue, rhsSelected) = rhs, lhsIndex == rhsIndex, lhsCatIndex == rhsCatIndex, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsLabel == rhsLabel, lhsValue == rhsValue, lhsSelected == rhsSelected {
                    return true
                } else {
                    return false
                }
            case let .address(lhsIndex, lhsCatIndex, lhsTheme, lhsTitle, lhsValue, _, lhsSelected):
                if case let .address(rhsIndex, rhsCatIndex, rhsTheme, rhsTitle, rhsValue, _, rhsSelected) = rhs, lhsIndex == rhsIndex, lhsCatIndex == rhsCatIndex, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsValue == rhsValue, lhsSelected == rhsSelected {
                    return true
                } else {
                    return false
                }
            case let .birthday(lhsIndex, lhsTheme, lhsTitle, lhsValue, lhsText, lhsSelected):
                if case let .birthday(rhsIndex, rhsTheme, rhsTitle, rhsValue, rhsText, rhsSelected) = rhs, lhsIndex == rhsIndex, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsValue == rhsValue, lhsText == rhsText, lhsSelected == rhsSelected {
                    return true
                } else {
                    return false
                }
            case let .socialProfile(lhsIndex, lhsCatIndex, lhsTheme, lhsTitle, lhsValue, lhsText, lhsSelected):
                if case let .socialProfile(rhsIndex, rhsCatIndex, rhsTheme, rhsTitle, rhsValue, rhsText, rhsSelected) = rhs, lhsIndex == rhsIndex, lhsCatIndex == rhsCatIndex, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsValue == rhsValue, lhsText == rhsText, lhsSelected == rhsSelected {
                    return true
                } else {
                    return false
                }
            case let .instantMessenger(lhsIndex, lhsCatIndex, lhsTheme, lhsTitle, lhsValue, lhsText, lhsSelected):
                if case let .instantMessenger(rhsIndex, rhsCatIndex, rhsTheme, rhsTitle, rhsValue, rhsText, rhsSelected) = rhs, lhsIndex == rhsIndex, lhsCatIndex == rhsCatIndex, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsValue == rhsValue, lhsText == rhsText, lhsSelected == rhsSelected {
                    return true
                } else {
                    return false
                }
            case let .note(lhsIndex, lhsTheme, lhsTitle, lhsText, lhsSelected):
                if case let .note(rhsIndex, rhsTheme, rhsTitle, rhsText, rhsSelected) = rhs, lhsIndex == rhsIndex, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsText == rhsText, lhsSelected == rhsSelected {
                    return true
                } else {
                    return false
                }
        }
    }
    
    private var sortIndex: Int {
        switch self {
            case let .info(index, _, _, _, _, _, _, _):
                return index
            case let .sendMessage(index, _, _):
                return index
            case let .invite(index, _, _):
                return index
            case let .createContact(index, _, _):
                return index
            case let .addToExisting(index, _, _):
                return index
            case let .company(index, _, _, _, _):
                return index
            case let .phoneNumber(index, _, _, _, _, _, _, _):
                return index
            case let .phoneNumberSharingInfo(index, _, _):
                return index
            case let .phoneNumberShareViaException(index, _, _, _):
                return index
            case let .phoneNumberShareViaExceptionInfo(index, _, _):
                return index
            case let .editingPhoneNumber(index, _, _, _, _, _, _, _):
                return index
            case let .addPhoneNumber(index, _, _):
                return index
            case let .email(index, _, _, _, _, _, _):
                return index
            case let .url(index, _, _, _, _, _, _):
                return index
            case let .address(index, _, _, _, _, _, _):
                return index
            case let .birthday(index, _, _, _, _, _):
                return index
            case let .socialProfile(index, _, _, _, _, _, _):
                return index
            case let .instantMessenger(index, _, _, _, _, _, _):
                return index
            case let .note(index, _, _, _, _):
                return index
        }
    }
    
    static func <(lhs: DeviceContactInfoEntry, rhs: DeviceContactInfoEntry) -> Bool {
        return lhs.sortIndex < rhs.sortIndex
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! DeviceContactInfoControllerArguments
        switch self {
            case let .info(_, _, _, dateTimeFormat, peer, state, jobSummary, _):
                return ItemListAvatarAndNameInfoItem(accountContext: arguments.context, presentationData: presentationData, dateTimeFormat: dateTimeFormat, mode: .contact, peer: EnginePeer(peer), presence: nil, label: jobSummary, memberCount: nil, state: state, sectionId: self.section, style: arguments.isPlain ? .plain : .blocks(withTopInset: false, withExtendedBottomInset: true), editingNameUpdated: { editingName in
                    arguments.updateEditingName(editingName)
                }, avatarTapped: {
                }, context: nil, call: nil)
            case let .sendMessage(_, _, title):
                return ItemListActionItem(presentationData: presentationData, title: title, kind: .generic, alignment: .natural, sectionId: self.section, style: arguments.isPlain ? .plain : .blocks, action: {
                    arguments.performAction(.sendMessage)
                })
            case let .invite(_, _, title):
                return ItemListActionItem(presentationData: presentationData, title: title, kind: .generic, alignment: .natural, sectionId: self.section, style: arguments.isPlain ? .plain : .blocks, action: {
                    arguments.performAction(.invite)
                })
            case let .createContact(_, _, title):
                return ItemListActionItem(presentationData: presentationData, title: title, kind: .generic, alignment: .natural, sectionId: self.section, style: arguments.isPlain ? .plain : .blocks, action: {
                    arguments.performAction(.createContact)
                })
            case let .addToExisting(_, _, title):
                return ItemListActionItem(presentationData: presentationData, title: title, kind: .generic, alignment: .natural, sectionId: self.section, style: arguments.isPlain ? .plain : .blocks, action: {
                    arguments.performAction(.addToExisting)
                })
            case let .company(_, _, title, value, selected):
                return ItemListTextWithLabelItem(presentationData: presentationData, label: title, text: value, style: arguments.isPlain ? .plain : .blocks, enabledEntityTypes: [], multiline: true, selected: selected, sectionId: self.section, action: {
                }, tag: nil)
            case let .phoneNumber(_, index, _, title, label, value, selected, isInteractionEnabled):
                return ItemListTextWithLabelItem(presentationData: presentationData, label: title, text: value, style: arguments.isPlain ? .plain : .blocks, textColor: .accent, enabledEntityTypes: [], multiline: false, selected: selected, sectionId: self.section, action: isInteractionEnabled ? {
                    if selected != nil {
                        arguments.toggleSelection(.phoneNumber(label, value))
                    } else {
                        arguments.callPhone(value)
                    }
                } : nil, longTapAction: isInteractionEnabled ? {
                    if selected == nil {
                        arguments.displayCopyContextMenu(.info(index), value)
                    }
                } : nil, tag: DeviceContactInfoEntryTag.info(index))
            case let .phoneNumberSharingInfo(_, _, text):
                return ItemListTextItem(presentationData: presentationData, text: .markdown(text), sectionId: self.section)
            case let .phoneNumberShareViaException(_, _, text, value):
                return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: arguments.isPlain ? .plain : .blocks, updated: { value in
                    arguments.updateShareViaException(value)
                })
            case let .phoneNumberShareViaExceptionInfo(_, _, text):
                return ItemListTextItem(presentationData: presentationData, text: .markdown(text), sectionId: self.section)
            case let .editingPhoneNumber(_, _, _, id, title, label, value, hasActiveRevealControls):
                return UserInfoEditingPhoneItem(presentationData: presentationData, id: id, label: title, value: value, editing: UserInfoEditingPhoneItemEditing(editable: true, hasActiveRevealControls: hasActiveRevealControls), sectionId: self.section, setPhoneIdWithRevealedOptions: { lhs, rhs in
                    arguments.setPhoneIdWithRevealedOptions(lhs, rhs)
                }, updated: { value in
                    arguments.updatePhone(id, value)
                }, selectLabel: {
                    arguments.updatePhoneLabel(id, label)
                }, delete: {
                    arguments.deletePhone(id)
                }, tag: DeviceContactInfoEntryTag.editingPhone(id))
            case let .addPhoneNumber(_, _, title):
                return UserInfoEditingPhoneActionItem(presentationData: presentationData, title: title, sectionId: self.section, action: {
                    arguments.addPhoneNumber()
                })
            case let .email(_, index, _, title, label, value, selected):
                return ItemListTextWithLabelItem(presentationData: presentationData, label: title, text: value, style: arguments.isPlain ? .plain : .blocks, textColor: .accent, enabledEntityTypes: [], multiline: false, selected: selected, sectionId: self.section, action: {
                    if selected != nil {
                        arguments.toggleSelection(.email(label, value))
                    } else {
                        arguments.openUrl("mailto:\(value)")
                    }
                }, longTapAction: {
                    if selected == nil {
                        arguments.displayCopyContextMenu(.info(index), value)
                    }
                }, tag: DeviceContactInfoEntryTag.info(index))
            case let .url(_, index, _, title, label, value, selected):
                return ItemListTextWithLabelItem(presentationData: presentationData, label: title, text: value, style: arguments.isPlain ? .plain : .blocks, textColor: .accent, enabledEntityTypes: [], multiline: false, selected: selected, sectionId: self.section, action: {
                    if selected != nil {
                        arguments.toggleSelection(.url(label, value))
                    } else {
                        arguments.openUrl(value)
                    }
                }, longTapAction: {
                    if selected == nil {
                        arguments.displayCopyContextMenu(.info(index), value)
                    }
                }, tag: DeviceContactInfoEntryTag.info(index))
            case let .address(_, index, theme, title, value, imageSignal, selected):
                var string = ""
                func combineComponent(string: inout String, component: String) {
                    if !component.isEmpty {
                        if !string.isEmpty {
                            string.append("\n")
                        }
                        string.append(component)
                    }
                }
                combineComponent(string: &string, component: value.street1)
                combineComponent(string: &string, component: value.street2)
                combineComponent(string: &string, component: value.state)
                combineComponent(string: &string, component: value.city)
                combineComponent(string: &string, component: value.country)
                combineComponent(string: &string, component: value.postcode)
                return ItemListAddressItem(theme: theme, label: title, text: string, imageSignal: imageSignal, selected: selected, sectionId: self.section, style: .plain, action: {
                    if selected != nil {
                        arguments.toggleSelection(.address(value))
                    } else {
                        arguments.openAddress(value)
                    }
                }, longTapAction: {
                    if selected == nil {
                        arguments.displayCopyContextMenu(.info(index), string)
                    }
                }, tag: DeviceContactInfoEntryTag.info(index))
            case let .birthday(_, _, title, value, text, selected):
                return ItemListTextWithLabelItem(presentationData: presentationData, label: title, text: text, style: arguments.isPlain ? .plain : .blocks, textColor: .accent, enabledEntityTypes: [], multiline: true, selected: selected, sectionId: self.section, action: {
                    if selected != nil {
                        arguments.toggleSelection(.birthday)
                    } else {
                        let calendar = Calendar(identifier: .gregorian)
                        var components = calendar.dateComponents([.month, .day], from: value)
                        let currentComponents = calendar.dateComponents([.year, .month, .day], from: Date())
                        
                        if let month = components.month, let currentMonth = currentComponents.month, let day = components.day, let currentDay = currentComponents.day, let currentYear = currentComponents.year {
                            if month >= currentMonth && (day >= currentDay || month > currentMonth) {
                                components.year = currentYear
                            } else {
                                components.year = currentYear + 1
                            }
                            components.hour = 12
                            components.minute = 0
                            
                            if let targetDate = calendar.date(from: components) {
                                let url = "calshow:\(targetDate.timeIntervalSinceReferenceDate)"
                                arguments.openUrl(url)
                            }
                        }
                    }
                }, longTapAction: {
                    if selected == nil {
                        arguments.displayCopyContextMenu(.birthday, text)
                    }
                }, tag: DeviceContactInfoEntryTag.birthday)
            case let .socialProfile(_, index, _, title, value, text, selected):
                return ItemListTextWithLabelItem(presentationData: presentationData, label: title, text: text, style: arguments.isPlain ? .plain : .blocks, textColor: .accent, enabledEntityTypes: [], multiline: true, selected: selected, sectionId: self.section, action: {
                    if selected != nil {
                        arguments.toggleSelection(.socialProfile(value))
                    } else if value.url.count > 0 {
                        arguments.openUrl(value.url)
                    }
                }, longTapAction: {
                    if selected == nil {
                        arguments.displayCopyContextMenu(.info(index), text)
                    }
                }, tag: DeviceContactInfoEntryTag.info(index))
            case let .instantMessenger(_, index, _, title, value, text, selected):
                return ItemListTextWithLabelItem(presentationData: presentationData, label: title, text: text, style: arguments.isPlain ? .plain : .blocks, textColor: .accent, enabledEntityTypes: [], multiline: true, selected: selected, sectionId: self.section, action: {
                    if selected != nil {
                        arguments.toggleSelection(.instantMessenger(value))
                    }
                }, longTapAction: {
                    if selected == nil {
                        arguments.displayCopyContextMenu(.info(index), text)
                    }
                }, tag: DeviceContactInfoEntryTag.info(index))
            case let .note(_, _, title, text, selected):
                return ItemListTextWithLabelItem(presentationData: presentationData, label: title, text: text, style: arguments.isPlain ? .plain : .blocks, enabledEntityTypes: [], multiline: true, selected: selected, sectionId: self.section, action: {
                    if selected != nil {
                        arguments.toggleSelection(.note)
                    }
                }, longTapAction: {
                    if selected == nil {
                        arguments.displayCopyContextMenu(.note, text)
                    }
                }, tag: DeviceContactInfoEntryTag.note)
        }
    }
}

private struct DeviceContactInfoEditingState: Equatable {
    var editingName: ItemListAvatarAndNameInfoItemName?
}

private struct EditingPhoneNumber: Equatable {
    var id: Int64
    var label: String
    var value: String
}

private struct DeviceContactInfoState: Equatable {
    var savingData: Bool = false
    var addToPrivacyExceptions: Bool = true
    var editingState: DeviceContactInfoEditingState? = nil
    var excludedComponents = Set<DeviceContactInfoDataId>()
    var phoneNumbers: [EditingPhoneNumber] = []
    var nextPhoneNumber: Int64 = 1
    var phoneIdWithRevealedOptions: Int64?
}

private func filteredContactData(contactData: DeviceContactExtendedData, excludedComponents: Set<DeviceContactInfoDataId>) -> DeviceContactExtendedData {
    let phoneNumbers = contactData.basicData.phoneNumbers.filter({ phoneNumber in
        return !excludedComponents.contains(.phoneNumber(phoneNumber.label, formatPhoneNumber(phoneNumber.value)))
    })
    let emailAddresses = contactData.emailAddresses.filter({ email in
        return !excludedComponents.contains(.email(email.label, email.value))
    })
    let urls = contactData.urls.filter({ url in
        return !excludedComponents.contains(.url(url.label, url.value))
    })
    let addresses = contactData.addresses.filter({ address in
        return !excludedComponents.contains(.address(address))
    })
    let socialProfiles = contactData.socialProfiles.filter({ socialProfile in
        return !excludedComponents.contains(.socialProfile(socialProfile))
    })
    let instantMessagingProfiles = contactData.instantMessagingProfiles.filter({ instantMessenger in
        return !excludedComponents.contains(.instantMessenger(instantMessenger))
    })
    let includeJob = !excludedComponents.contains(.job)
    let includeBirthday = !excludedComponents.contains(.birthday)
    let includeNote = !excludedComponents.contains(.note)
    return DeviceContactExtendedData(basicData: DeviceContactBasicData(firstName: contactData.basicData.firstName, lastName: contactData.basicData.lastName, phoneNumbers: phoneNumbers), middleName: contactData.middleName, prefix: contactData.prefix, suffix: contactData.suffix, organization: includeJob ? contactData.organization : "", jobTitle: includeJob ? contactData.jobTitle : "", department: includeJob ? contactData.department : "", emailAddresses: emailAddresses, urls: urls, addresses: addresses, birthdayDate: includeBirthday ? contactData.birthdayDate : nil, socialProfiles: socialProfiles, instantMessagingProfiles: instantMessagingProfiles, note: includeNote ? contactData.note : "")
}

private func deviceContactInfoEntries(account: Account, engine: TelegramEngine, presentationData: PresentationData, peer: Peer?, isShare: Bool, shareViaException: Bool, contactData: DeviceContactExtendedData, isContact: Bool, state: DeviceContactInfoState, selecting: Bool, editingPhoneNumbers: Bool) -> [DeviceContactInfoEntry] {
    var entries: [DeviceContactInfoEntry] = []
    
    var editingName: ItemListAvatarAndNameInfoItemName?
    
    if let editingState = state.editingState {
        editingName = editingState.editingName
    }
    
    var personName: (String, String) = (contactData.basicData.firstName, contactData.basicData.lastName)
    if let editingName = editingName {
        switch editingName {
        case let .personName(firstName, lastName, _):
            personName = (firstName, lastName)
        default:
            break
        }
    }
    
    var jobComponents: [String] = []
    if !contactData.organization.isEmpty {
        jobComponents.append(contactData.organization)
    }
    if !contactData.department.isEmpty {
        jobComponents.append(contactData.department)
    }
    if !contactData.jobTitle.isEmpty {
        jobComponents.append(contactData.jobTitle)
    }
    let jobSummary = jobComponents.joined(separator: " — ")
    
    let isOrganization = personName.0.isEmpty && personName.1.isEmpty && !contactData.organization.isEmpty

    var firstName: String = isOrganization ? contactData.organization : personName.0
    if firstName.isEmpty {
        firstName = presentationData.strings.Message_Contact
    }
    
    entries.append(.info(entries.count, presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, peer: peer ?? TelegramUser(id: PeerId(namespace: .max, id: PeerId.Id._internalFromInt64Value(0)), accessHash: nil, firstName: firstName, lastName: isOrganization ? nil : personName.1, username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [], emojiStatus: nil, usernames: []), state: ItemListAvatarAndNameInfoItemState(editingName: editingName, updatingName: nil), job: isOrganization ? nil : jobSummary, isPlain: !isShare))
    
    if !selecting {
        if let _ = peer {
            entries.append(.sendMessage(entries.count, presentationData.theme, presentationData.strings.UserInfo_SendMessage))
        } else {
            entries.append(.invite(entries.count, presentationData.theme, presentationData.strings.Contacts_InviteToTelegram))
        }
        
        if !isContact {
            entries.append(.createContact(entries.count, presentationData.theme, presentationData.strings.UserInfo_CreateNewContact))
            entries.append(.addToExisting(entries.count, presentationData.theme, presentationData.strings.UserInfo_AddToExisting))
        }
    }
    
    if isShare {
        var numberIndex = 0
        if contactData.basicData.phoneNumbers.isEmpty {
            entries.append(.phoneNumber(entries.count, numberIndex, presentationData.theme, localizedPhoneNumberLabel(label: "_$!<Mobile>!$_", strings: presentationData.strings), localizedPhoneNumberLabel(label: "_$!<Mobile>!$_", strings: presentationData.strings), presentationData.strings.ContactInfo_PhoneNumberHidden, nil, false))
            numberIndex += 1
        }
        for number in contactData.basicData.phoneNumbers {
            let formattedNumber = formatPhoneNumber(number.value)
            entries.append(.phoneNumber(entries.count, numberIndex, presentationData.theme, localizedPhoneNumberLabel(label: number.label, strings: presentationData.strings), number.label, formattedNumber, nil, false))
            numberIndex += 1
        }
        if let peer = peer {
            let personCompactName: String
            if !personName.0.isEmpty {
                personCompactName = personName.0
            } else if !personName.1.isEmpty {
                personCompactName = personName.1
            } else {
                personCompactName = EnginePeer(peer).compactDisplayTitle
            }
            
            if contactData.basicData.phoneNumbers.isEmpty {
                entries.append(.phoneNumberSharingInfo(entries.count, presentationData.theme, presentationData.strings.AddContact_ContactWillBeSharedAfterMutual(personCompactName).string))
            }
            if shareViaException {
                entries.append(.phoneNumberShareViaException(entries.count, presentationData.theme, presentationData.strings.AddContact_SharedContactException, state.addToPrivacyExceptions))
                entries.append(.phoneNumberShareViaExceptionInfo(entries.count, presentationData.theme, presentationData.strings.AddContact_SharedContactExceptionInfo(personCompactName).string))
            }
        }
    } else {
        if editingPhoneNumbers {
            for number in state.phoneNumbers {
                let label = !number.label.isEmpty ? number.label : "_$!<Mobile>!$_"
                entries.append(.editingPhoneNumber(entries.count, presentationData.theme, presentationData.strings, number.id, localizedPhoneNumberLabel(label: label, strings: presentationData.strings), label, number.value, state.phoneIdWithRevealedOptions == number.id))
            }
            entries.append(.addPhoneNumber(entries.count, presentationData.theme, presentationData.strings.UserInfo_AddPhone))
        } else {
            var numberIndex = 0
            for number in contactData.basicData.phoneNumbers {
                let formattedNumber = formatPhoneNumber(number.value)
                entries.append(.phoneNumber(entries.count, numberIndex, presentationData.theme, localizedPhoneNumberLabel(label: number.label, strings: presentationData.strings), number.label, formattedNumber, selecting ? !state.excludedComponents.contains(.phoneNumber(number.label, formattedNumber)) : nil, true))
                numberIndex += 1
            }
        }
    }
    
    var emailIndex = 0
    for email in contactData.emailAddresses {
        entries.append(.email(entries.count, emailIndex, presentationData.theme, localizedGenericContactFieldLabel(label: email.label, strings: presentationData.strings), email.label, email.value, selecting ? !state.excludedComponents.contains(.email(email.label, email.value)) : nil))
        emailIndex += 1
    }
    
    var urlIndex = 0
    for url in contactData.urls {
        entries.append(.url(entries.count, urlIndex, presentationData.theme, localizedGenericContactFieldLabel(label: url.label, strings: presentationData.strings), url.label, url.value, selecting ? !state.excludedComponents.contains(.url(url.label, url.value)) : nil))
        urlIndex += 1
    }
    
    var addressIndex = 0
    for address in contactData.addresses {
        let signal = geocodeLocation(address: address.asPostalAddress)
        |> mapToSignal { coordinates -> Signal<(TransformImageArguments) -> DrawingContext?, NoError> in
            if let (latitude, longitude) = coordinates {
                let resource = MapSnapshotMediaResource(latitude: latitude, longitude: longitude, width: 90, height: 90)
                return chatMapSnapshotImage(engine: engine, resource: resource)
            } else {
                return .single({ _ in return nil })
            }
        }
        
        entries.append(.address(entries.count, addressIndex, presentationData.theme, localizedGenericContactFieldLabel(label: address.label, strings: presentationData.strings), address, signal, selecting ? !state.excludedComponents.contains(.address(address)) : nil))
        addressIndex += 1
    }
    
    if let birthday = contactData.birthdayDate {
        let dateText: String
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents(Set([.era, .year, .month, .day]), from: birthday)
        if let year = components.year, year > 1 {
            dateText = stringForDate(date: birthday, timeZone: TimeZone.current, strings: presentationData.strings)
        } else {
            dateText = stringForDateWithoutYear(date: birthday, timeZone: TimeZone.current, strings: presentationData.strings)
        }
        entries.append(.birthday(entries.count, presentationData.theme, presentationData.strings.ContactInfo_BirthdayLabel, birthday, dateText, selecting ? !state.excludedComponents.contains(.birthday) : nil))
    }
    
    var socialProfileIndex = 0
    for profile in contactData.socialProfiles {
        var label = localizedGenericContactFieldLabel(label: profile.label, strings: presentationData.strings)
        var text = profile.username
        switch profile.service.lowercased() {
            case "twitter":
                label = "Twitter"
                text = "@\(profile.username)"
            case "facebook":
                label = "Facebook"
            default:
                if !profile.service.isEmpty {
                    label = profile.service
                }
        }
        entries.append(.socialProfile(entries.count, socialProfileIndex, presentationData.theme, label, profile, text, selecting ? !state.excludedComponents.contains(.socialProfile(profile)) : nil))
        socialProfileIndex += 1
    }
    
    var instantMessagingProfileIndex = 0
    for profile in contactData.instantMessagingProfiles {
        var label = localizedGenericContactFieldLabel(label: profile.label, strings: presentationData.strings)
        if !profile.service.isEmpty {
            label = profile.service
        }
        entries.append(.instantMessenger(entries.count, instantMessagingProfileIndex, presentationData.theme, label, profile, profile.username, selecting ? !state.excludedComponents.contains(.instantMessenger(profile)) : nil))
        instantMessagingProfileIndex += 1
    }
    
    if !contactData.note.isEmpty {
        entries.append(.note(entries.count, presentationData.theme, presentationData.strings.ContactInfo_Note, contactData.note, selecting ? !state.excludedComponents.contains(.note) : nil))
    }
    
    return entries
}

private final class DeviceContactInfoController: ItemListController, MFMessageComposeViewControllerDelegate, UINavigationControllerDelegate {
    private var composer: MFMessageComposeViewController?
    func inviteContact(presentationData: PresentationData, numbers: [String]) {
        if MFMessageComposeViewController.canSendText() {
            let composer = MFMessageComposeViewController()
            composer.messageComposeDelegate = self
            composer.recipients = Array(Set(numbers))
            let url = presentationData.strings.InviteText_URL
            let body = presentationData.strings.InviteText_SingleContact(url).string
            composer.body = body
            self.composer = composer
            if let window = self.view.window {
                window.rootViewController?.present(composer, animated: true)
            }
        }
    }
    
    @objc func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
        self.composer = nil
        
        controller.dismiss(animated: true, completion: nil)
        
        guard case .sent = result else {
            return
        }
    }
}

public func deviceContactInfoController(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, subject: DeviceContactInfoSubject, completed: (() -> Void)?, cancelled: (() -> Void)?) -> ViewController {
    var initialState = DeviceContactInfoState()
    if case let .create(peer, contactData, _, _, _) = subject {
        var peerPhoneNumber: String?
        var firstName = contactData.basicData.firstName
        var lastName = contactData.basicData.lastName
        if let peer = peer as? TelegramUser {
            firstName = peer.firstName ?? ""
            lastName = peer.lastName ?? ""
            if let phone = peer.phone {
                let formattedPhone = formatPhoneNumber(phone)
                peerPhoneNumber = formattedPhone
                initialState.phoneNumbers.append(EditingPhoneNumber(id: initialState.nextPhoneNumber, label: "_$!<Mobile>!$_", value: formattedPhone))
                initialState.nextPhoneNumber += 1
            }
        }
        for phoneNumber in contactData.basicData.phoneNumbers {
            if peerPhoneNumber != formatPhoneNumber(phoneNumber.value) {
                initialState.phoneNumbers.append(EditingPhoneNumber(id: initialState.nextPhoneNumber, label: phoneNumber.label, value: phoneNumber.value))
                initialState.nextPhoneNumber += 1
            }
        }
        initialState.editingState = DeviceContactInfoEditingState(editingName: .personName(firstName: firstName, lastName: lastName, phone: ""))
    }
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((DeviceContactInfoState) -> DeviceContactInfoState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var addToExistingImpl: (() -> Void)?
    var openChatImpl: ((PeerId) -> Void)?
    var replaceControllerImpl: ((ViewController) -> Void)?
    var pushControllerImpl: ((ViewController) -> Void)?
    var presentControllerImpl: ((ViewController, Any?) -> Void)?
    var openUrlImpl: ((String) -> Void)?
    var openAddressImpl: ((DeviceContactAddressData) -> Void)?
    var inviteImpl: (([String]) -> Void)?
    var dismissImpl: ((Bool) -> Void)?
    
    let actionsDisposable = DisposableSet()
    
    let addContactDisposable = MetaDisposable()
    actionsDisposable.add(addContactDisposable)
    
    var displayCopyContextMenuImpl: ((DeviceContactInfoEntryTag, String) -> Void)?
    
    let callImpl: (String) -> Void = { number in
        let user: Signal<TelegramUser?, NoError>
        if let peer = subject.peer {
            user = context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peer.id))
            |> map { peer -> TelegramUser? in
                if case let .user(user) = peer {
                    return user
                } else {
                    return nil
                }
            }
        } else {
            user = .single(nil)
        }
        let _ = (user
        |> deliverOnMainQueue).start(next: { user in
            if let user = user, let phone = user.phone, formatPhoneNumber(phone) == formatPhoneNumber(number) {
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                let controller = ActionSheetController(presentationData: presentationData)
                let dismissAction: () -> Void = { [weak controller] in
                    controller?.dismissAnimated()
                }
                controller.setItemGroups([
                    ActionSheetItemGroup(items: [
                        ActionSheetButtonItem(title: presentationData.strings.UserInfo_TelegramCall, action: {
                            dismissAction()
                            context.requestCall(peerId: user.id, isVideo: false, completion: {})
                        }),
                        ActionSheetButtonItem(title: presentationData.strings.UserInfo_PhoneCall, action: {
                            dismissAction()
                            context.sharedContext.applicationBindings.openUrl("tel:\(formatPhoneNumber(number).replacingOccurrences(of: " ", with: ""))")
                        }),
                    ]),
                    ActionSheetItemGroup(items: [ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, action: { dismissAction() })])
                ])
                presentControllerImpl?(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
            } else {
                context.sharedContext.applicationBindings.openUrl("tel:\(formatPhoneNumber(number).replacingOccurrences(of: " ", with: ""))")
            }
        })
    }
    
    let contactData: Signal<(Peer?, DeviceContactStableId?, DeviceContactExtendedData), NoError>
    var isShare = false
    var shareViaException = false
    switch subject {
    case let .vcard(peer, id, data):
        contactData = .single((peer, id, data))
    case let .filter(peer, id, data, _):
        contactData = .single((peer, id, data))
    case let .create(peer, data, share, shareViaExceptionValue, _):
        contactData = .single((peer, nil, data))
        isShare = share
        shareViaException = shareViaExceptionValue
    }
    
    let arguments = DeviceContactInfoControllerArguments(context: context, isPlain: !isShare, updateEditingName: { editingName in
        updateState { state in
            var state = state
            if let _ = state.editingState {
                state.editingState = DeviceContactInfoEditingState(editingName: editingName)
            }
            return state
        }
    }, updatePhone: { id, value in
        updateState { state in
            var state = state
            for i in 0 ..< state.phoneNumbers.count {
                if state.phoneNumbers[i].id == id {
                    state.phoneNumbers[i].value = value
                    break
                }
            }
            return state
        }
    }, updatePhoneLabel: { id, currentLabel in
        pushControllerImpl?(phoneLabelController(context: context, currentLabel: currentLabel, completion: { value in
            updateState { state in
                var state = state
                for i in 0 ..< state.phoneNumbers.count {
                    if state.phoneNumbers[i].id == id {
                        state.phoneNumbers[i].label = value
                        break
                    }
                }
                return state
            }
        }))
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
    }, setPhoneIdWithRevealedOptions: { id, fromId in
        updateState { state in
            var state = state
            if (id == nil && fromId == state.phoneIdWithRevealedOptions) || (id != nil && fromId == nil) {
                state.phoneIdWithRevealedOptions = id
            }
            return state
        }
    }, addPhoneNumber: {
        updateState { state in
            var state = state
            let id = state.nextPhoneNumber
            state.nextPhoneNumber += 1
            state.phoneNumbers.append(EditingPhoneNumber(id: id, label: "_$!<Mobile>!$_", value: "+"))
            return state
        }
    }, performAction: { action in
        switch action {
            case .invite:
                let inviteAction: (String) -> Void = { number in
                    inviteImpl?([number])
                }
                if subject.contactData.basicData.phoneNumbers.count == 1 {
                    inviteAction(subject.contactData.basicData.phoneNumbers[0].value)
                } else {
                    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                    let controller = ActionSheetController(presentationData: presentationData)
                    let dismissAction: () -> Void = { [weak controller] in
                        controller?.dismissAnimated()
                    }
                    var items: [ActionSheetItem] = []
                    for phoneNumber in subject.contactData.basicData.phoneNumbers {
                        items.append(ActionSheetButtonItem(title: formatPhoneNumber(phoneNumber.value), action: {
                            dismissAction()
                            inviteAction(phoneNumber.value)
                        }))
                    }
                    
                    controller.setItemGroups([
                        ActionSheetItemGroup(items: items),
                        ActionSheetItemGroup(items: [ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, action: { dismissAction() })])
                    ])
                    presentControllerImpl?(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                }
            case .createContact:
                pushControllerImpl?(deviceContactInfoController(context: context, subject: .create(peer: subject.peer, contactData: subject.contactData, isSharing: false, shareViaException: false, completion: { peer, stableId, contactData in
                    dismissImpl?(false)
                }), completed: nil, cancelled: nil))
            case .addToExisting:
                addToExistingImpl?()
            case .sendMessage:
                if let peer = subject.peer {
                    openChatImpl?(peer.id)
                }
        }
    }, toggleSelection: { dataId in
        updateState { state in
            var state = state
            if state.excludedComponents.contains(dataId) {
                state.excludedComponents.remove(dataId)
            } else {
                state.excludedComponents.insert(dataId)
            }
            return state
        }
    }, callPhone: { phoneNumber in
        callImpl(phoneNumber)
    }, openUrl: { url in
        openUrlImpl?(url)
    }, openAddress: { address in
        openAddressImpl?(address)
    }, displayCopyContextMenu: { tag, value in
        displayCopyContextMenuImpl?(tag, value)
    }, updateShareViaException: { value in
        updateState { state in
            var state = state
            state.addToPrivacyExceptions = value
            return state
        }
    })
    
    let presentationData = updatedPresentationData?.signal ?? context.sharedContext.presentationData
    let previousEditingPhoneIds = Atomic<Set<Int64>?>(value: nil)
    let signal = combineLatest(presentationData, statePromise.get(), contactData)
    |> map { presentationData, state, peerAndContactData -> (ItemListControllerState, (ItemListNodeState, Any)) in
        var leftNavigationButton: ItemListNavigationButton?
        switch subject {
            case .vcard:
                break
            case .filter, .create:
                leftNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Cancel), style: .regular, enabled: true, action: {
                    dismissImpl?(true)
                    cancelled?()
                })
        }
        
        var rightNavigationButton: ItemListNavigationButton?
        if state.savingData {
            rightNavigationButton = ItemListNavigationButton(content: .none, style: .activity, enabled: true, action: {})
        } else if case let .filter(_, _, _, completion) = subject {
            let filteredData = filteredContactData(contactData: peerAndContactData.2, excludedComponents: state.excludedComponents)
            rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.ShareMenu_Send), style: .bold, enabled: !filteredData.basicData.phoneNumbers.isEmpty, action: {
                completion(peerAndContactData.0, filteredData)
                dismissImpl?(true)
            })
        } else if case let .create(createForPeer, _, _, _, completion) = subject {
            let filteredData = filteredContactData(contactData: peerAndContactData.2, excludedComponents: state.excludedComponents)
            var filteredPhoneNumbers: [DeviceContactPhoneNumberData] = []
            for phoneNumber in state.phoneNumbers {
                if !phoneNumber.value.isEmpty && phoneNumber.value != "+" {
                    filteredPhoneNumbers.append(DeviceContactPhoneNumberData(label: phoneNumber.label, value: phoneNumber.value))
                }
            }
            var composedContactData: DeviceContactExtendedData?
            if let editingName = state.editingState?.editingName, case let .personName(firstName, lastName, _) = editingName, (!firstName.isEmpty || !lastName.isEmpty) {
                var urls = filteredData.urls
                if let createForPeer = createForPeer {
                    let appProfile = DeviceContactUrlData(appProfile: createForPeer.id)
                    var found = false
                    for url in urls {
                        if url.label == appProfile.label && url.value == appProfile.value {
                            found = true
                            break
                        }
                    }
                    if !found {
                        urls.append(appProfile)
                    }
                }
                composedContactData = DeviceContactExtendedData(basicData: DeviceContactBasicData(firstName: firstName, lastName: lastName, phoneNumbers: filteredPhoneNumbers), middleName: filteredData.middleName, prefix: filteredData.prefix, suffix: filteredData.suffix, organization: filteredData.organization, jobTitle: filteredData.jobTitle, department: filteredData.department, emailAddresses: filteredData.emailAddresses, urls: urls, addresses: filteredData.addresses, birthdayDate: filteredData.birthdayDate, socialProfiles: filteredData.socialProfiles, instantMessagingProfiles: filteredData.instantMessagingProfiles, note: filteredData.note)
            }
            rightNavigationButton = ItemListNavigationButton(content: .text(isShare ? presentationData.strings.Common_Done : presentationData.strings.Compose_Create), style: .bold, enabled: (isShare || !filteredPhoneNumbers.isEmpty) && composedContactData != nil, action: {
                if let composedContactData = composedContactData {
                    var addToPrivacyExceptions = false
                    updateState { state in
                        var state = state
                        state.savingData = true
                        addToPrivacyExceptions = state.addToPrivacyExceptions
                        return state
                    }
                    if let contactDataManager = context.sharedContext.contactDataManager {
                        switch subject {
                            case let .create(peer, _, share, shareViaException, _):
                                if share, filteredPhoneNumbers.count <= 1, let peer = peer {
                                    addContactDisposable.set((context.engine.contacts.addContactInteractively(peerId: peer.id, firstName: composedContactData.basicData.firstName, lastName: composedContactData.basicData.lastName, phoneNumber: filteredPhoneNumbers.first?.value ?? "", addToPrivacyExceptions: shareViaException && addToPrivacyExceptions)
                                    |> deliverOnMainQueue).start(error: { _ in
                                        presentControllerImpl?(textAlertController(context: context, updatedPresentationData: updatedPresentationData, title: nil, text: presentationData.strings.Login_UnknownError, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), nil)
                                    }, completed: {
                                        let _ = (contactDataManager.createContactWithData(composedContactData)
                                        |> deliverOnMainQueue).start(next: { contactIdAndData in
                                            updateState { state in
                                                var state = state
                                                state.savingData = false
                                                return state
                                            }
                                            if let contactIdAndData = contactIdAndData {
                                                completion(peer, contactIdAndData.0, contactIdAndData.1)
                                            }
                                            completed?()
                                            dismissImpl?(true)
                                        })
                                    }))
                                    return
                                }
                            default:
                                break
                        }
                        
                        let _ = (contactDataManager.createContactWithData(composedContactData)
                        |> castError(AddContactError.self)
                        |> mapToSignal { contactIdAndData -> Signal<(DeviceContactStableId, DeviceContactExtendedData, Peer?)?, AddContactError> in
                            guard let (id, data) = contactIdAndData else {
                                return .single(nil)
                            }
                            if filteredPhoneNumbers.count <= 1 {
                                switch subject {
                                    case let .create(peer, _, share, shareViaException, _):
                                        if share, let peer = peer {
                                            return context.engine.contacts.addContactInteractively(peerId: peer.id, firstName: composedContactData.basicData.firstName, lastName: composedContactData.basicData.lastName, phoneNumber: filteredPhoneNumbers.first?.value ?? "", addToPrivacyExceptions: shareViaException && addToPrivacyExceptions)
                                            |> mapToSignal { _ -> Signal<(DeviceContactStableId, DeviceContactExtendedData, Peer?)?, AddContactError> in
                                            }
                                            |> then(
                                                context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peer.id))
                                                |> castError(AddContactError.self)
                                                |> map { result -> (DeviceContactStableId, DeviceContactExtendedData, Peer?)? in
                                                    return (id, data, result?._asPeer())
                                                }
                                            )
                                        }
                                    default:
                                        break
                                }
                                
                                return context.engine.contacts.importContact(firstName: composedContactData.basicData.firstName, lastName: composedContactData.basicData.lastName, phoneNumber: filteredPhoneNumbers[0].value)
                                |> castError(AddContactError.self)
                                |> mapToSignal { peerId -> Signal<(DeviceContactStableId, DeviceContactExtendedData, Peer?)?, AddContactError> in
                                    if let peerId = peerId {
                                        return context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
                                        |> castError(AddContactError.self)
                                        |> map { result -> (DeviceContactStableId, DeviceContactExtendedData, Peer?)? in
                                            return (id, data, result?._asPeer())
                                        }
                                    } else {
                                        return .single((id, data, nil))
                                    }
                                }
                            } else {
                                return .single((id, data, nil))
                            }
                        }
                        |> deliverOnMainQueue).start(next: { contactIdAndData in
                            updateState { state in
                                var state = state
                                state.savingData = false
                                return state
                            }
                            if let contactIdAndData = contactIdAndData {
                                completion(contactIdAndData.2, contactIdAndData.0, contactIdAndData.1)
                            }
                            completed?()
                            dismissImpl?(true)
                        })
                    }
                }
            })
        }
        
        var editingPhones = false
        var selecting = false
        let title: String
        switch subject {
            case .vcard:
                title = presentationData.strings.UserInfo_Title
            case .filter:
                selecting = true
                title = presentationData.strings.UserInfo_Title
            case .create:
                selecting = true
                editingPhones = true
                title = presentationData.strings.NewContact_Title
        }
        if case .filter = subject {
            selecting = true
        }
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(title), leftNavigationButton: leftNavigationButton, rightNavigationButton: rightNavigationButton, backNavigationButton: nil)
        
        let editingPhoneIds = Set<Int64>(state.phoneNumbers.map({ $0.id }))
        let previousPhoneIds = previousEditingPhoneIds.swap(editingPhoneIds)
        let insertedPhoneIds = editingPhoneIds.subtracting(previousPhoneIds ?? Set())
        var insertedPhoneId: Int64?
        if insertedPhoneIds.count == 1, let id = insertedPhoneIds.first {
            for phoneNumber in state.phoneNumbers {
                if phoneNumber.id == id {
                    if phoneNumber.value.isEmpty || phoneNumber.value == "+" {
                        insertedPhoneId = id
                    }
                    break
                }
            }
        }
        
        var focusItemTag: ItemListItemTag?
        if let insertedPhoneId = insertedPhoneId {
            focusItemTag = DeviceContactInfoEntryTag.editingPhone(insertedPhoneId)
        }
        
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: deviceContactInfoEntries(account: context.account, engine: context.engine, presentationData: presentationData, peer: peerAndContactData.0, isShare: isShare, shareViaException: shareViaException, contactData: peerAndContactData.2, isContact: peerAndContactData.1 != nil, state: state, selecting: selecting, editingPhoneNumbers: editingPhones), style: isShare ? .blocks : .plain, focusItemTag: focusItemTag)
        
        return (controllerState, (listState, arguments))
    }
    |> afterDisposed {
        actionsDisposable.dispose()
    }
    
    let controller = DeviceContactInfoController(context: context, state: signal)
    controller.navigationPresentation = .modal
    addToExistingImpl = { [weak controller] in
        guard let controller = controller else {
            return
        }
        addContactToExisting(context: context, parentController: controller, contactData: subject.contactData, completion: { peer, contactId, contactData in
            replaceControllerImpl?(deviceContactInfoController(context: context, subject: .vcard(peer, contactId, contactData), completed: nil, cancelled: nil))
        })
    }
    openChatImpl = { [weak controller] peerId in
        let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
        |> deliverOnMainQueue).start(next: { peer in
            guard let peer = peer else {
                return
            }
            
            if let navigationController = (controller?.navigationController as? NavigationController) {
                context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(peer)))
            }
        })
    }
    replaceControllerImpl = { [weak controller] value in
        (controller?.navigationController as? NavigationController)?.replaceTopController(value, animated: true)
    }
    pushControllerImpl = { [weak controller] c in
        (controller?.navigationController as? NavigationController)?.pushViewController(c)
    }
    presentControllerImpl = { [weak controller] value, presentationArguments in
        controller?.present(value, in: .window(.root), with: presentationArguments)
    }
    dismissImpl = { [weak controller] animated in
        guard let controller = controller else {
            return
        }
        controller.view.endEditing(true)
        if let navigationController = controller.navigationController as? NavigationController {
            navigationController.filterController(controller, animated: animated)
        } else {
            controller.dismiss()
        }
    }
    inviteImpl = { [weak controller] numbers in
        controller?.inviteContact(presentationData: context.sharedContext.currentPresentationData.with { $0 }, numbers: numbers)
    }
    openAddressImpl = { [weak controller] address in
        guard let _ = controller else {
            return
        }
    }
    openUrlImpl = { [weak controller] url in
        guard let controller = controller else {
            return
        }
        context.sharedContext.openExternalUrl(context: context, urlContext: .generic, url: url, forceExternal: false, presentationData: context.sharedContext.currentPresentationData.with { $0 }, navigationController: controller.navigationController as? NavigationController, dismissInput: { [weak controller] in
            controller?.view.endEditing(true)
        })
    }
    
    displayCopyContextMenuImpl = { [weak controller] tag, value in
        if let strongController = controller {
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            var resultItemNode: ListViewItemNode?
            let _ = strongController.frameForItemNode({ itemNode in
                if let itemNode = itemNode as? ItemListTextWithLabelItemNode {
                    if let itemTag = itemNode.tag as? DeviceContactInfoEntryTag {
                        if itemTag == tag && itemNode.item?.text == value {
                            resultItemNode = itemNode
                            return true
                        }
                    }
                }
                return false
            })
            if let resultItemNode = resultItemNode {
                let contextMenuController = ContextMenuController(actions: [ContextMenuAction(content: .text(title: presentationData.strings.Conversation_ContextMenuCopy, accessibilityLabel: presentationData.strings.Conversation_ContextMenuCopy), action: {
                    UIPasteboard.general.string = value
                    
                    let content: UndoOverlayContent = .copy(text: presentationData.strings.Conversation_TextCopied)
                    presentControllerImpl?(UndoOverlayController(presentationData: presentationData, content: content, elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), nil)
                })])
                strongController.present(contextMenuController, in: .window(.root), with: ContextMenuControllerPresentationArguments(sourceNodeAndRect: { [weak resultItemNode] in
                    if let strongController = controller, let resultItemNode = resultItemNode {
                        return (resultItemNode, resultItemNode.contentBounds.insetBy(dx: 0.0, dy: -2.0), strongController.displayNode, strongController.view.bounds)
                    } else {
                        return nil
                    }
                }))
            }
        }
    }
    
    return controller
}

private func addContactToExisting(context: AccountContext, parentController: ViewController, contactData: DeviceContactExtendedData, completion: @escaping (Peer?, DeviceContactStableId, DeviceContactExtendedData) -> Void) {
    let contactsController = context.sharedContext.makeContactSelectionController(ContactSelectionControllerParams(context: context, title: { $0.Contacts_Title }, displayDeviceContacts: true))
    contactsController.navigationPresentation = .modal
    (parentController.navigationController as? NavigationController)?.pushViewController(contactsController)
    let _ = (contactsController.result
    |> deliverOnMainQueue).start(next: { result in
        if let (peers, _, _, _, _) = result, let peer = peers.first {
            let dataSignal: Signal<(Peer?, DeviceContactStableId?), NoError>
            switch peer {
                case let .peer(contact, _, _):
                    guard let contact = contact as? TelegramUser, let phoneNumber = contact.phone else {
                        return
                    }
                    dataSignal = (context.sharedContext.contactDataManager?.basicData() ?? .single([:]))
                    |> take(1)
                    |> mapToSignal { basicData -> Signal<(Peer?, DeviceContactStableId?), NoError> in
                        var stableId: String?
                        let queryPhoneNumber = formatPhoneNumber(phoneNumber)
                        outer: for (id, data) in basicData {
                            for phoneNumber in data.phoneNumbers {
                                if formatPhoneNumber(phoneNumber.value) == queryPhoneNumber {
                                    stableId = id
                                    break outer
                                }
                            }
                        }
                        return .single((contact, stableId))
                    }
                case let .deviceContact(id, _):
                    dataSignal = .single((nil, id))
            }
            let _ = (dataSignal
            |> deliverOnMainQueue).start(next: { peer, stableId in
                guard let stableId = stableId else {
                    parentController.present(deviceContactInfoController(context: context, subject: .create(peer: peer, contactData: contactData, isSharing: false, shareViaException: false, completion: { peer, stableId, contactData in
                        
                    }), completed: nil, cancelled: nil), in: .window(.root))
                    return
                }
                if let contactDataManager = context.sharedContext.contactDataManager {
                    let _ = (contactDataManager.appendContactData(contactData, to: stableId)
                    |> deliverOnMainQueue).start(next: { contactData in
                        guard let contactData = contactData else {
                            return
                        }
                        let _ = (context.engine.data.get(
                            TelegramEngine.EngineData.Item.Contacts.List(includePresences: false)
                        )
                        |> deliverOnMainQueue).start(next: { view in
                            let phones = Set<String>(contactData.basicData.phoneNumbers.map {
                                return formatPhoneNumber($0.value)
                            })
                            var foundPeer: EnginePeer?
                            for peer in view.peers {
                                if case let .user(user) = peer, let phone = user.phone {
                                    let phone = formatPhoneNumber(phone)
                                    if phones.contains(phone) {
                                        foundPeer = peer
                                        break
                                    }
                                }
                            }
                            completion(foundPeer?._asPeer(), stableId, contactData)
                        })
                    })
                }
            })
        }
    })
}

func addContactOptionsController(context: AccountContext, peer: Peer?, contactData: DeviceContactExtendedData) -> ActionSheetController {
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    let controller = ActionSheetController(presentationData: presentationData)
    let dismissAction: () -> Void = { [weak controller] in
        controller?.dismissAnimated()
    }
    
    controller.setItemGroups([
        ActionSheetItemGroup(items: [
            ActionSheetButtonItem(title: presentationData.strings.Profile_CreateNewContact, action: { [weak controller] in
                controller?.present(context.sharedContext.makeDeviceContactInfoController(context: context, subject: .create(peer: peer, contactData: contactData, isSharing: peer != nil, shareViaException: false, completion: { _, _, _ in
                }), completed: nil, cancelled: nil), in: .window(.root), with: ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                dismissAction()
            }),
            ActionSheetButtonItem(title: presentationData.strings.Profile_AddToExisting, action: { [weak controller] in
                guard let controller = controller else {
                    return
                }
                addContactToExisting(context: context, parentController: controller, contactData: contactData, completion: { peer, contactId, contactData in
                    
                })
                dismissAction()
            })
        ]),
        ActionSheetItemGroup(items: [ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, action: { dismissAction() })])
    ])
    return controller
}
