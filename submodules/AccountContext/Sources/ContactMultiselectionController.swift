import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox

public struct ChatListNodeAdditionalCategory {
    public var id: Int
    public var icon: UIImage?
    public var title: String
    
    public init(id: Int, icon: UIImage?, title: String) {
        self.id = id
        self.icon = icon
        self.title = title
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
    case chatSelection(title: String, selectedChats: Set<PeerId>, additionalCategories: ContactMultiselectionControllerAdditionalCategories?)
}

public enum ContactListFilter {
    case excludeSelf
    case exclude([PeerId])
    case disable([PeerId])
}

public final class ContactMultiselectionControllerParams {
    public let context: AccountContext
    public let mode: ContactMultiselectionControllerMode
    public let options: [ContactListAdditionalOption]
    public let filters: [ContactListFilter]
    public let alwaysEnabled: Bool

    public init(context: AccountContext, mode: ContactMultiselectionControllerMode, options: [ContactListAdditionalOption], filters: [ContactListFilter] = [.excludeSelf], alwaysEnabled: Bool = false) {
        self.context = context
        self.mode = mode
        self.options = options
        self.filters = filters
        self.alwaysEnabled = alwaysEnabled
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
