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

class ChatMessageBackground: ASImageNode {
    private var type: ChatMessageBackgroundType?
    private var currentHighlighted = false
    
    override init() {
        super.init()
        
        self.isLayerBacked = true
        self.displaysAsynchronously = false
        self.displayWithoutProcessing = true
    }
    
    func setType(type: ChatMessageBackgroundType, highlighted: Bool, graphics: PrincipalThemeEssentialGraphics) {
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
                    image = highlighted ? graphics.chatMessageBackgroundIncomingHighlightedImage : graphics.chatMessageBackgroundIncomingImage
                case .Top:
                    image = highlighted ? graphics.chatMessageBackgroundIncomingMergedTopHighlightedImage : graphics.chatMessageBackgroundIncomingMergedTopImage
                case .Bottom:
                    image = highlighted ? graphics.chatMessageBackgroundIncomingMergedBottomHighlightedImage : graphics.chatMessageBackgroundIncomingMergedBottomImage
                case .Both:
                    image = highlighted ? graphics.chatMessageBackgroundIncomingMergedBothHighlightedImage : graphics.chatMessageBackgroundIncomingMergedBothImage
            }
        case let .Outgoing(mergeType):
            switch mergeType {
                case .None:
                    image = highlighted ? graphics.chatMessageBackgroundOutgoingHighlightedImage : graphics.chatMessageBackgroundOutgoingImage
                case .Top:
                    image = highlighted ? graphics.chatMessageBackgroundOutgoingMergedTopHighlightedImage : graphics.chatMessageBackgroundOutgoingMergedTopImage
                case .Bottom:
                    image = highlighted ? graphics.chatMessageBackgroundOutgoingMergedBottomHighlightedImage : graphics.chatMessageBackgroundOutgoingMergedBottomImage
                case .Both:
                    image = highlighted ? graphics.chatMessageBackgroundOutgoingMergedBothHighlightedImage : graphics.chatMessageBackgroundOutgoingMergedBothImage
            }
        }
        self.image = image
    }
}
