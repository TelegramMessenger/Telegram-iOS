import Foundation
import Display
import SwiftSignalKit
import Postbox

public enum ContactMultiselectionControllerMode {
    case groupCreation
    case peerSelection(searchChatList: Bool, searchGroups: Bool)
    case channelCreation
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

    public init(context: AccountContext, mode: ContactMultiselectionControllerMode, options: [ContactListAdditionalOption], filters: [ContactListFilter] = [.excludeSelf]) {
        self.context = context
        self.mode = mode
        self.options = options
        self.filters = filters
    }
}

public protocol ContactMultiselectionController: ViewController {
    var result: Signal<[ContactListPeerId], NoError> { get }
    var displayProgress: Bool { get set }
    var dismissed: (() -> Void)? { get set }
}
