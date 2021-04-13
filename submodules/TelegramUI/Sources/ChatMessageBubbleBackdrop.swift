import Foundation
import AsyncDisplayKit
import Display
import Postbox
import TelegramPresentationData

private let maskInset: CGFloat = 1.0

func bubbleMaskForType(_ type: ChatMessageBackgroundType, graphics: PrincipalThemeEssentialGraphics) -> UIImage? {
    let image: UIImage?
    switch type {
    case .none:
        image = nil
    case let .incoming(mergeType):
        switch mergeType {
        case .None:
            image = graphics.chatMessageBackgroundIncomingMaskImage
        case let .Top(side):
            if side {
                image = graphics.chatMessageBackgroundIncomingMergedTopSideMaskImage
            } else {
                image = graphics.chatMessageBackgroundIncomingMergedTopMaskImage
            }
        case .Bottom:
            image = graphics.chatMessageBackgroundIncomingMergedBottomMaskImage
        case .Both:
            image = graphics.chatMessageBackgroundIncomingMergedBothMaskImage
        case .Side:
            image = graphics.chatMessageBackgroundIncomingMergedSideMaskImage
        case .Extracted:
            image = graphics.chatMessageBackgroundIncomingExtractedMaskImage
        }
    case let .outgoing(mergeType):
        switch mergeType {
        case .None:
            image = graphics.chatMessageBackgroundOutgoingMaskImage
        case let .Top(side):
            if side {
                image = graphics.chatMessageBackgroundOutgoingMergedTopSideMaskImage
            } else {
                image = graphics.chatMessageBackgroundOutgoingMergedTopMaskImage
            }
        case .Bottom:
            image = graphics.chatMessageBackgroundOutgoingMergedBottomMaskImage
        case .Both:
            image = graphics.chatMessageBackgroundOutgoingMergedBothMaskImage
        case .Side:
            image = graphics.chatMessageBackgroundOutgoingMergedSideMaskImage
        case .Extracted:
            image = graphics.chatMessageBackgroundOutgoingExtractedMaskImage
        }
    }
    return image
}

final class ChatMessageBubbleBackdrop: ASDisplayNode {
    private let backgroundContent: ASDisplayNode
    
    private var currentType: ChatMessageBackgroundType?
    private var currentMaskMode: Bool?
    private var theme: ChatPresentationThemeData?
    private var essentialGraphics: PrincipalThemeEssentialGraphics?
    
    private var maskView: UIImageView?

    private var fixedMaskMode: Bool?
    
    var hasImage: Bool {
        return self.backgroundContent.contents != nil
    }
    
    override var frame: CGRect {
        didSet {
            if let maskView = self.maskView {
                let maskFrame = self.bounds.insetBy(dx: -maskInset, dy: -maskInset)
                if maskView.frame != maskFrame {
                    maskView.frame = maskFrame
                }
            }
        }
    }
    
    override init() {
        self.backgroundContent = ASDisplayNode()
        
        super.init()
        
        self.clipsToBounds = true
        
        self.addSubnode(self.backgroundContent)
    }
    
    func setMaskMode(_ maskMode: Bool, mediaBox: MediaBox) {
        if let currentType = self.currentType, let theme = self.theme, let essentialGraphics = self.essentialGraphics {
            self.setType(type: currentType, theme: theme, mediaBox: mediaBox, essentialGraphics: essentialGraphics, maskMode: maskMode)
        }
    }
    
    func setType(type: ChatMessageBackgroundType, theme: ChatPresentationThemeData, mediaBox: MediaBox, essentialGraphics: PrincipalThemeEssentialGraphics, maskMode inputMaskMode: Bool) {
        let maskMode = self.fixedMaskMode ?? inputMaskMode

        if self.currentType != type || self.theme != theme || self.currentMaskMode != maskMode || self.essentialGraphics !== essentialGraphics {
            self.currentType = type
            self.theme = theme
            self.essentialGraphics = essentialGraphics
            
            if maskMode != self.currentMaskMode {
                self.currentMaskMode = maskMode
                
                if maskMode {
                    let maskView: UIImageView
                    if let current = self.maskView {
                        maskView = current
                    } else {
                        maskView = UIImageView()
                        maskView.frame = self.bounds.insetBy(dx: -maskInset, dy: -maskInset)
                        self.maskView = maskView
                        self.view.mask = maskView
                    }
                } else {
                    if let _ = self.maskView {
                        self.view.mask = nil
                        self.maskView = nil
                    }
                }
            }
            
            switch type {
            case .none:
                self.backgroundContent.contents = nil
            case .incoming:
                self.backgroundContent.contents = essentialGraphics.incomingBubbleGradientImage?.cgImage
            case .outgoing:
                self.backgroundContent.contents = essentialGraphics.outgoingBubbleGradientImage?.cgImage
            }
            
            if let maskView = self.maskView {
                maskView.image = bubbleMaskForType(type, graphics: essentialGraphics)
            }
        }
    }
    
    func update(rect: CGRect, within containerSize: CGSize) {
        self.backgroundContent.frame = CGRect(origin: CGPoint(x: -rect.minX, y: -rect.minY), size: containerSize)
    }
    
    func offset(value: CGFloat, animationCurve: ContainedViewLayoutTransitionCurve, duration: Double) {
        let transition: ContainedViewLayoutTransition = .animated(duration: duration, curve: animationCurve)
        transition.animatePositionAdditive(node: self.backgroundContent, offset: CGPoint(x: 0.0, y: -value))
    }
    
    func offsetSpring(value: CGFloat, duration: Double, damping: CGFloat) {
        self.backgroundContent.layer.animateSpring(from: NSValue(cgPoint: CGPoint(x: 0.0, y: value)), to: NSValue(cgPoint: CGPoint()), keyPath: "position", duration: duration, initialVelocity: 0.0, damping: damping, additive: true)
    }
    
    func updateFrame(_ value: CGRect, transition: ContainedViewLayoutTransition, completion: @escaping () -> Void = {}) {
        if let maskView = self.maskView {
            transition.updateFrame(view: maskView, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: value.size.width, height: value.size.height)).insetBy(dx: -maskInset, dy: -maskInset))
        }
        transition.updateFrame(node: self, frame: value, completion: { _ in
            completion()
        })
    }

    func animateFrom(sourceView: UIView, mediaBox: MediaBox, transition: ContainedViewLayoutTransition) {
        if transition.isAnimated {
            let wasMaskMode = self.currentMaskMode
            if let wasMaskMode = wasMaskMode, !wasMaskMode {
                self.fixedMaskMode = true
                self.setMaskMode(true, mediaBox: mediaBox)
            }

            let previousFrame = self.frame
            self.updateFrame(CGRect(origin: previousFrame.origin, size: sourceView.frame.size), transition: .immediate)
            self.updateFrame(previousFrame, transition: transition, completion: { [weak self] in
                if let wasMaskMode = wasMaskMode, !wasMaskMode {
                    self?.fixedMaskMode = nil
                    self?.setMaskMode(false, mediaBox: mediaBox)
                }
            })
        }
    }
}
