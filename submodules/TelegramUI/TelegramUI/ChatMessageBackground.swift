import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData

enum ChatMessageBackgroundMergeType: Equatable {
    case None, Side, Top(side: Bool), Bottom, Both
    
    init(top: Bool, bottom: Bool, side: Bool) {
        if top && bottom {
            self = .Both
        } else if top {
            self = .Top(side: side)
        } else if bottom {
            if side {
                self = .Side
            } else {
                self = .Bottom
            }
        } else {
            if side {
                self = .Side
            } else {
                self = .None
            }
        }
    }
}

enum ChatMessageBackgroundType: Equatable {
    case none
    case incoming(ChatMessageBackgroundMergeType)
    case outgoing(ChatMessageBackgroundMergeType)

    static func ==(lhs: ChatMessageBackgroundType, rhs: ChatMessageBackgroundType) -> Bool {
        switch lhs {
            case .none:
                if case .none = rhs {
                    return true
                } else {
                    return false
                }
            case let .incoming(mergeType):
                if case .incoming(mergeType) = rhs {
                    return true
                } else {
                    return false
                }
            case let .outgoing(mergeType):
                if case .outgoing(mergeType) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
}

class ChatMessageBackground: ASImageNode {
    private(set) var type: ChatMessageBackgroundType?
    private var currentHighlighted = false
    private var graphics: PrincipalThemeEssentialGraphics?
    
    override init() {
        super.init()
        
        self.isUserInteractionEnabled = false
        self.displaysAsynchronously = false
        self.displayWithoutProcessing = true
    }
    
    func setType(type: ChatMessageBackgroundType, highlighted: Bool, graphics: PrincipalThemeEssentialGraphics, transition: ContainedViewLayoutTransition) {
        let previousType = self.type
        if let currentType = previousType, currentType == type, self.currentHighlighted == highlighted, self.graphics === graphics {
            return
        }
        self.type = type
        self.currentHighlighted = highlighted
        self.graphics = graphics
        
        let image: UIImage?
        switch type {
            case .none:
                image = nil
            case let .incoming(mergeType):
                switch mergeType {
                    case .None:
                        image = highlighted ? graphics.chatMessageBackgroundIncomingHighlightedImage : graphics.chatMessageBackgroundIncomingImage
                    case let .Top(side):
                        if side {
                            image = highlighted ? graphics.chatMessageBackgroundIncomingMergedTopSideHighlightedImage : graphics.chatMessageBackgroundIncomingMergedTopSideImage
                        } else {
                            image = highlighted ? graphics.chatMessageBackgroundIncomingMergedTopHighlightedImage : graphics.chatMessageBackgroundIncomingMergedTopImage
                        }
                    case .Bottom:
                        image = highlighted ? graphics.chatMessageBackgroundIncomingMergedBottomHighlightedImage : graphics.chatMessageBackgroundIncomingMergedBottomImage
                    case .Both:
                        image = highlighted ? graphics.chatMessageBackgroundIncomingMergedBothHighlightedImage : graphics.chatMessageBackgroundIncomingMergedBothImage
                    case .Side:
                        image = highlighted ? graphics.chatMessageBackgroundIncomingMergedSideHighlightedImage : graphics.chatMessageBackgroundIncomingMergedSideImage
                }
            case let .outgoing(mergeType):
                switch mergeType {
                    case .None:
                        image = highlighted ? graphics.chatMessageBackgroundOutgoingHighlightedImage : graphics.chatMessageBackgroundOutgoingImage
                    case let .Top(side):
                        if side {
                            image = highlighted ? graphics.chatMessageBackgroundOutgoingMergedTopSideHighlightedImage : graphics.chatMessageBackgroundOutgoingMergedTopSideImage
                        } else {
                            image = highlighted ? graphics.chatMessageBackgroundOutgoingMergedTopHighlightedImage : graphics.chatMessageBackgroundOutgoingMergedTopImage
                        }
                    case .Bottom:
                        image = highlighted ? graphics.chatMessageBackgroundOutgoingMergedBottomHighlightedImage : graphics.chatMessageBackgroundOutgoingMergedBottomImage
                    case .Both:
                        image = highlighted ? graphics.chatMessageBackgroundOutgoingMergedBothHighlightedImage : graphics.chatMessageBackgroundOutgoingMergedBothImage
                    case .Side:
                        image = highlighted ? graphics.chatMessageBackgroundOutgoingMergedSideHighlightedImage : graphics.chatMessageBackgroundOutgoingMergedSideImage
                }
        }
        
        if let previousType = previousType, previousType != .none, type == .none {
            if transition.isAnimated {
                let tempLayer = CALayer()
                tempLayer.contents = self.layer.contents
                tempLayer.contentsScale = self.layer.contentsScale
                tempLayer.rasterizationScale = self.layer.rasterizationScale
                tempLayer.contentsGravity = self.layer.contentsGravity
                tempLayer.contentsCenter = self.layer.contentsCenter
                
                tempLayer.frame = self.bounds
                self.layer.addSublayer(tempLayer)
                transition.updateAlpha(layer: tempLayer, alpha: 0.0, completion: { [weak tempLayer] _ in
                    tempLayer?.removeFromSuperlayer()
                })
            }
        }
        
        self.image = image
    }
}
