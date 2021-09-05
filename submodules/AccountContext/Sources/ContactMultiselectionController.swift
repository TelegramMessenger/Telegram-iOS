import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData

public struct ChatListNodeAdditionalCategory {
    public enum Appearance {
        case option
        case action
    }
    
    public var id: Int
    public var icon: UIImage?
    public var title: String
    public var appearance: Appearance
    
    public init(id: Int, icon: UIImage?, title: String, appearance: Appearance = .option) {
        self.id = id
        self.icon = icon
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
    case groupCreation
    case peerSelection(searchChatList: Bool, searchGroups: Bool, searchChannels: Bool)
    case channelCreation
    case chatSelection(title: String, selectedChats: Set<PeerId>, additionalCategories: ContactMultiselectionControllerAdditionalCategories?, chatListFilters: [ChatListFilter]?)
}

public enum ContactListFilter {
    case excludeSelf
    case exclude([PeerId])
    case disable([PeerId])
}

public final class ContactMultiselectionControllerParams {
    public let context: AccountContext
    public let updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)?
    public let mode: ContactMultiselectionControllerMode
    public let options: [ContactListAdditionalOption]
    public let filters: [ContactListFilter]
    public let alwaysEnabled: Bool
    public let limit: Int32?

    public init(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, mode: ContactMultiselectionControllerMode, options: [ContactListAdditionalOption], filters: [ContactListFilter] = [.excludeSelf], alwaysEnabled: Bool = false, limit: Int32? = nil) {
        self.context = context
        self.updatedPresentationData = updatedPresentationData
        self.mode = mode
        self.options = options
        self.filters = filters
        self.alwaysEnabled = alwaysEnabled
        self.limit = limit
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
