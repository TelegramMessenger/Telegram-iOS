import Foundation
import AsyncDisplayKit

enum ChatMessageBackgroundMergeType {
    case None, Top, Bottom, Both
    
    init(top: Bool, bottom: Bool) {
        if top && bottom {
            self = .Both
        } else if top {
            self = .Top
        } else if bottom {
            self = .Bottom
        } else {
            self = .None
        }
    }
}

enum ChatMessageBackgroundType: Equatable {
    case Incoming(ChatMessageBackgroundMergeType), Outgoing(ChatMessageBackgroundMergeType)

    static func ==(lhs: ChatMessageBackgroundType, rhs: ChatMessageBackgroundType) -> Bool {
        switch lhs {
        case let .Incoming(lhsMergeType):
            switch rhs {
            case let .Incoming(rhsMergeType):
                return lhsMergeType == rhsMergeType
            case .Outgoing:
                return false
            }
        case let .Outgoing(lhsMergeType):
            switch rhs {
            case .Incoming:
                return false
            case let .Outgoing(rhsMergeType):
                return lhsMergeType == rhsMergeType
            }
        }
    }
}

private let chatMessageBackgroundIncomingImage = messageBubbleImage(incoming: true, neighbors: .none)
private let chatMessageBackgroundIncomingMergedTopImage = messageBubbleImage(incoming: true, neighbors: .top)
private let chatMessageBackgroundIncomingMergedBottomImage = messageBubbleImage(incoming: true, neighbors: .bottom)
private let chatMessageBackgroundIncomingMergedBothImage = messageBubbleImage(incoming: true, neighbors: .both)

private let chatMessageBackgroundOutgoingImage = messageBubbleImage(incoming: false, neighbors: .none)
private let chatMessageBackgroundOutgoingMergedTopImage = messageBubbleImage(incoming: false, neighbors: .top)
private let chatMessageBackgroundOutgoingMergedBottomImage = messageBubbleImage(incoming: false, neighbors: .bottom)
private let chatMessageBackgroundOutgoingMergedBothImage = messageBubbleImage(incoming: false, neighbors: .both)

class ChatMessageBackground: ASImageNode {
    private var type: ChatMessageBackgroundType?
    
    override init() {
        super.init()
        
        self.isLayerBacked = true
        self.displaysAsynchronously = false
        self.displayWithoutProcessing = true
    }
    
    func setType(type: ChatMessageBackgroundType) {
        if let currentType = self.type, currentType == type {
            return
        }
        self.type = type
        
        let image: UIImage?
        switch type {
        case let .Incoming(mergeType):
            switch mergeType {
            case .None:
                image = chatMessageBackgroundIncomingImage
            case .Top:
                image = chatMessageBackgroundIncomingMergedTopImage
            case .Bottom:
                image = chatMessageBackgroundIncomingMergedBottomImage
            case .Both:
                image = chatMessageBackgroundIncomingMergedBothImage
            }
        case let .Outgoing(mergeType):
            switch mergeType {
            case .None:
                image = chatMessageBackgroundOutgoingImage
            case .Top:
                image = chatMessageBackgroundOutgoingMergedTopImage
            case .Bottom:
                image = chatMessageBackgroundOutgoingMergedBottomImage
            case .Both:
                image = chatMessageBackgroundOutgoingMergedBothImage
            }
        }
        self.image = image
    }
}
