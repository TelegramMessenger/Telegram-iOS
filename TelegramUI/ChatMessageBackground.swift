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

private let chatMessageBackgroundIncomingImage = messageBubbleImage(incoming: true, highlighted: false, neighbors: .none)
private let chatMessageBackgroundIncomingHighlightedImage = messageBubbleImage(incoming: true, highlighted: true, neighbors: .none)
private let chatMessageBackgroundIncomingMergedTopImage = messageBubbleImage(incoming: true, highlighted: false, neighbors: .top)
private let chatMessageBackgroundIncomingMergedTopHighlightedImage = messageBubbleImage(incoming: true, highlighted: true, neighbors: .top)
private let chatMessageBackgroundIncomingMergedBottomImage = messageBubbleImage(incoming: true, highlighted: false, neighbors: .bottom)
private let chatMessageBackgroundIncomingMergedBottomHighlightedImage = messageBubbleImage(incoming: true, highlighted: true, neighbors: .bottom)
private let chatMessageBackgroundIncomingMergedBothImage = messageBubbleImage(incoming: true, highlighted: false, neighbors: .both)
private let chatMessageBackgroundIncomingMergedBothHighlightedImage = messageBubbleImage(incoming: true, highlighted: true, neighbors: .both)

private let chatMessageBackgroundOutgoingImage = messageBubbleImage(incoming: false, highlighted: false, neighbors: .none)
private let chatMessageBackgroundOutgoingHighlightedImage = messageBubbleImage(incoming: false, highlighted: true, neighbors: .none)
private let chatMessageBackgroundOutgoingMergedTopImage = messageBubbleImage(incoming: false, highlighted: false, neighbors: .top)
private let chatMessageBackgroundOutgoingMergedTopHighlightedImage = messageBubbleImage(incoming: false, highlighted: true, neighbors: .top)
private let chatMessageBackgroundOutgoingMergedBottomImage = messageBubbleImage(incoming: false, highlighted: false, neighbors: .bottom)
private let chatMessageBackgroundOutgoingMergedBottomHighlightedImage = messageBubbleImage(incoming: false, highlighted: true, neighbors: .bottom)
private let chatMessageBackgroundOutgoingMergedBothImage = messageBubbleImage(incoming: false, highlighted: false, neighbors: .both)
private let chatMessageBackgroundOutgoingMergedBothHighlightedImage = messageBubbleImage(incoming: false, highlighted: true, neighbors: .both)


class ChatMessageBackground: ASImageNode {
    private var type: ChatMessageBackgroundType?
    private var currentHighlighted = false
    
    override init() {
        super.init()
        
        self.isLayerBacked = true
        self.displaysAsynchronously = false
        self.displayWithoutProcessing = true
    }
    
    func setType(type: ChatMessageBackgroundType, highlighted: Bool) {
        if let currentType = self.type, currentType == type, self.currentHighlighted == highlighted {
            return
        }
        self.type = type
        self.currentHighlighted = highlighted
        
        let image: UIImage?
        switch type {
        case let .Incoming(mergeType):
            switch mergeType {
                case .None:
                    image = highlighted ? chatMessageBackgroundIncomingHighlightedImage : chatMessageBackgroundIncomingImage
                case .Top:
                    image = highlighted ? chatMessageBackgroundIncomingMergedTopHighlightedImage : chatMessageBackgroundIncomingMergedTopImage
                case .Bottom:
                    image = highlighted ? chatMessageBackgroundIncomingMergedBottomHighlightedImage : chatMessageBackgroundIncomingMergedBottomImage
                case .Both:
                    image = highlighted ? chatMessageBackgroundIncomingMergedBothHighlightedImage : chatMessageBackgroundIncomingMergedBothImage
            }
        case let .Outgoing(mergeType):
            switch mergeType {
                case .None:
                    image = highlighted ? chatMessageBackgroundOutgoingHighlightedImage : chatMessageBackgroundOutgoingImage
                case .Top:
                    image = highlighted ? chatMessageBackgroundOutgoingMergedTopHighlightedImage : chatMessageBackgroundOutgoingMergedTopImage
                case .Bottom:
                    image = highlighted ? chatMessageBackgroundOutgoingMergedBottomHighlightedImage : chatMessageBackgroundOutgoingMergedBottomImage
                case .Both:
                    image = highlighted ? chatMessageBackgroundOutgoingMergedBothHighlightedImage : chatMessageBackgroundOutgoingMergedBothImage
            }
        }
        self.image = image
    }
}
