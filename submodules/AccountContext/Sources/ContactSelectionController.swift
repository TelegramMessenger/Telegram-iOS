import Foundation
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData

public protocol ContactSelectionController: ViewController {
    var result: Signal<([ContactListPeer], ContactListAction, Bool, Int32?, NSAttributedString?, ChatSendMessageActionSheetController.SendParameters?)?, NoError> { get }
    var displayProgress: Bool { get set }
    var dismissed: (() -> Void)? { get set }
    var presentScheduleTimePicker: (@escaping (Int32) -> Void) -> Void { get set }
    
    func dismissSearch()
}

public enum ContactSelectionControllerMode {
    case generic
    case starsGifting(birthdays: [EnginePeer.Id: TelegramBirthday]?, hasActions: Bool)
}

public struct ContactListAdditionalOption: Equatable {
    public let title: String
    public let icon: ContactListActionItemIcon
    public let action: () -> Void
    public let clearHighlightAutomatically: Bool
    
    public init(title: String, icon: ContactListActionItemIcon, action: @escaping () -> Void, clearHighlightAutomatically: Bool = false) {
        self.title = title
        self.icon = icon
        self.action = action
        self.clearHighlightAutomatically = clearHighlightAutomatically
    }
    
    public static func ==(lhs: ContactListAdditionalOption, rhs: ContactListAdditionalOption) -> Bool {
        return lhs.title == rhs.title && lhs.icon == rhs.icon
    }
}

public enum ContactListPeerId: Hashable {
    case peer(PeerId)
    case deviceContact(DeviceContactStableId)
}

public enum ContactListAction: Equatable {
    case generic
    case voiceCall
    case videoCall
    case more
}

public enum ContactListPeer: Equatable {
    case peer(peer: Peer, isGlobal: Bool, participantCount: Int32?)
    case deviceContact(DeviceContactStableId, DeviceContactBasicData)
    
    public var id: ContactListPeerId {
        switch self {
        case let .peer(peer, _, _):
            return .peer(peer.id)
        case let .deviceContact(id, _):
            return .deviceContact(id)
        }
    }
    
    public var indexName: PeerIndexNameRepresentation {
        switch self {
        case let .peer(peer, _, _):
            return peer.indexName
        case let .deviceContact(_, contact):
            return .personName(first: contact.firstName, last: contact.lastName, addressNames: [], phoneNumber: "")
        }
    }
    
    public static func ==(lhs: ContactListPeer, rhs: ContactListPeer) -> Bool {
        switch lhs {
        case let .peer(lhsPeer, lhsIsGlobal, lhsParticipantCount):
            if case let .peer(rhsPeer, rhsIsGlobal, rhsParticipantCount) = rhs, lhsPeer.isEqual(rhsPeer), lhsIsGlobal == rhsIsGlobal, lhsParticipantCount == rhsParticipantCount {
                return true
            } else {
                return false
            }
        case let .deviceContact(id, contact):
            if case .deviceContact(id, contact) = rhs {
                return true
            } else {
                return false
            }
        }
    }
}

public final class ContactSelectionControllerParams {
    public let context: AccountContext
    public let updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)?
    public let mode: ContactSelectionControllerMode
    public let autoDismiss: Bool
    public let title: (PresentationStrings) -> String
    public let options: Signal<[ContactListAdditionalOption], NoError>
    public let displayDeviceContacts: Bool
    public let displayCallIcons: Bool
    public let multipleSelection: Bool
    public let requirePhoneNumbers: Bool
    public let confirmation: (ContactListPeer) -> Signal<Bool, NoError>
    public let openProfile: ((EnginePeer) -> Void)?
    public let sendMessage: ((EnginePeer) -> Void)?
    
    public init(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, mode: ContactSelectionControllerMode = .generic, autoDismiss: Bool = true, title: @escaping (PresentationStrings) -> String, options: Signal<[ContactListAdditionalOption], NoError> = .single([]), displayDeviceContacts: Bool = false, displayCallIcons: Bool = false, multipleSelection: Bool = false, requirePhoneNumbers: Bool = false, confirmation: @escaping (ContactListPeer) -> Signal<Bool, NoError> = { _ in .single(true) }, openProfile: ((EnginePeer) -> Void)? = nil, sendMessage: ((EnginePeer) -> Void)? = nil) {
        self.context = context
        self.updatedPresentationData = updatedPresentationData
        self.mode = mode
        self.autoDismiss = autoDismiss
        self.title = title
        self.options = options
        self.displayDeviceContacts = displayDeviceContacts
        self.displayCallIcons = displayCallIcons
        self.multipleSelection = multipleSelection
        self.requirePhoneNumbers = requirePhoneNumbers
        self.confirmation = confirmation
        self.openProfile = openProfile
        self.sendMessage = sendMessage
    }
}
