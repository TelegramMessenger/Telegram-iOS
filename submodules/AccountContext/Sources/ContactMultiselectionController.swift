import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData

public struct ChatListNodeAdditionalCategory {
    public enum Appearance: Equatable {
        case option(sectionTitle: String?)
        case action
    }
    
    public var id: Int
    public var icon: UIImage?
    public var smallIcon: UIImage?
    public var title: String
    public var appearance: Appearance
    
    public init(id: Int, icon: UIImage?, smallIcon: UIImage?, title: String, appearance: Appearance = .option(sectionTitle: nil)) {
        self.id = id
        self.icon = icon
        self.smallIcon = smallIcon
        self.title = title
        self.appearance = appearance
    }
}

public struct ContactMultiselectionControllerAdditionalCategories {
    public var categories: [ChatListNodeAdditionalCategory]
    public var selectedCategories: Set<Int>
    
    public init(categories: [ChatListNodeAdditionalCategory], selectedCategories: Set<Int>) {
        self.categories = categories
        self.selectedCategories = selectedCategories
    }
}

public enum ContactMultiselectionControllerMode {
    public struct ChatSelection {
        public var title: String
        public var searchPlaceholder: String
        public var selectedChats: Set<EnginePeer.Id>
        public var additionalCategories: ContactMultiselectionControllerAdditionalCategories?
        public var chatListFilters: [ChatListFilter]?
        public var displayAutoremoveTimeout: Bool
        public var displayPresence: Bool
        
        public init(
            title: String,
            searchPlaceholder: String,
            selectedChats: Set<EnginePeer.Id>,
            additionalCategories: ContactMultiselectionControllerAdditionalCategories?,
            chatListFilters: [ChatListFilter]?,
            displayAutoremoveTimeout: Bool = false,
            displayPresence: Bool = false
        ) {
            self.title = title
            self.searchPlaceholder = searchPlaceholder
            self.selectedChats = selectedChats
            self.additionalCategories = additionalCategories
            self.chatListFilters = chatListFilters
            self.displayAutoremoveTimeout = displayAutoremoveTimeout
            self.displayPresence = displayPresence
        }
    }
    
    case groupCreation
    case peerSelection(searchChatList: Bool, searchGroups: Bool, searchChannels: Bool)
    case channelCreation
    case chatSelection(ChatSelection)
}

public enum ContactListFilter {
    case excludeSelf
    case exclude([EnginePeer.Id])
    case disable([EnginePeer.Id])
}

public final class ContactMultiselectionControllerParams {
    public let context: AccountContext
    public let updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)?
    public let mode: ContactMultiselectionControllerMode
    public let options: [ContactListAdditionalOption]
    public let filters: [ContactListFilter]
    public let isPeerEnabled: ((EnginePeer) -> Bool)?
    public let attemptDisabledItemSelection: ((EnginePeer) -> Void)?
    public let alwaysEnabled: Bool
    public let limit: Int32?
    public let reachedLimit: ((Int32) -> Void)?

    public init(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, mode: ContactMultiselectionControllerMode, options: [ContactListAdditionalOption], filters: [ContactListFilter] = [.excludeSelf], isPeerEnabled: ((EnginePeer) -> Bool)? = nil, attemptDisabledItemSelection: ((EnginePeer) -> Void)? = nil, alwaysEnabled: Bool = false, limit: Int32? = nil, reachedLimit: ((Int32) -> Void)? = nil) {
        self.context = context
        self.updatedPresentationData = updatedPresentationData
        self.mode = mode
        self.options = options
        self.filters = filters
        self.isPeerEnabled = isPeerEnabled
        self.attemptDisabledItemSelection = attemptDisabledItemSelection
        self.alwaysEnabled = alwaysEnabled
        self.limit = limit
        self.reachedLimit = reachedLimit
    }
}

public enum ContactMultiselectionResult {
    case none
    case result(peerIds: [ContactListPeerId], additionalOptionIds: [Int])
}

public protocol ContactMultiselectionController: ViewController {
    var result: Signal<ContactMultiselectionResult, NoError> { get }
    var displayProgress: Bool { get set }
    var dismissed: (() -> Void)? { get set }
}
