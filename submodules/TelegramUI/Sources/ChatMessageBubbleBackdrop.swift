import Foundation
import AsyncDisplayKit
import Display
import Postbox
import TelegramPresentationData
import WallpaperBackgroundNode

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
    private var backgroundContent: WallpaperBubbleBackgroundNode?
    
    private var currentType: ChatMessageBackgroundType?
    private var currentMaskMode: Bool?
    private var theme: ChatPresentationThemeData?
    private var essentialGraphics: PrincipalThemeEssentialGraphics?
    private weak var backgroundNode: WallpaperBackgroundNode?
    
    private var maskView: UIImageView?
    private var fixedMaskMode: Bool?

    private var absolutePosition: (CGRect, CGSize)?
    
    var hasImage: Bool {
        return self.backgroundContent != nil
    }
    
    override var frame: CGRect {
        didSet {
            if let maskView = self.maskView {
                let maskFrame = self.bounds.insetBy(dx: -maskInset, dy: -maskInset)
                if maskView.frame != maskFrame {
                    maskView.frame = maskFrame
                }
            }
            if let backgroundContent = self.backgroundContent {
                backgroundContent.frame = self.bounds
                if let (rect, containerSize) = self.absolutePosition {
                    var backgroundFrame = backgroundContent.frame
                    backgroundFrame.origin.x += rect.minX
                    backgroundFrame.origin.y += rect.minY
                    backgroundContent.update(rect: backgroundFrame, within: containerSize, transition: .immediate)
                }
            }
        }
    }
    
    override init() {
        super.init()
        
        self.clipsToBounds = true
    }
    
    func setMaskMode(_ maskMode: Bool, mediaBox: MediaBox) {
        if let currentType = self.currentType, let theme = self.theme, let essentialGraphics = self.essentialGraphics, let backgroundNode = self.backgroundNode {
            self.setType(type: currentType, theme: theme, essentialGraphics: essentialGraphics, maskMode: maskMode, backgroundNode: backgroundNode)
        }
    }
    
    func setType(type: ChatMessageBackgroundType, theme: ChatPresentationThemeData, essentialGraphics: PrincipalThemeEssentialGraphics, maskMode inputMaskMode: Bool, backgroundNode: WallpaperBackgroundNode?) {
        let maskMode = self.fixedMaskMode ?? inputMaskMode

        if self.currentType != type || self.theme != theme || self.currentMaskMode != maskMode || self.essentialGraphics !== essentialGraphics || self.backgroundNode !== backgroundNode {
            let typeUpdated = self.currentType != type || self.theme != theme || self.currentMaskMode != maskMode || self.backgroundNode !== backgroundNode

            self.currentType = type
            self.theme = theme
            self.essentialGraphics = essentialGraphics
            self.backgroundNode = backgroundNode
            
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

            if let backgroundContent = self.backgroundContent {
                backgroundContent.frame = self.bounds
                if let (rect, containerSize) = self.absolutePosition {
                    var backgroundFrame = backgroundContent.frame
                    backgroundFrame.origin.x += rect.minX
                    backgroundFrame.origin.y += rect.minY
                    backgroundContent.update(rect: backgroundFrame, within: containerSize, transition: .immediate)
                }
            }

            if typeUpdated {
                if let backgroundContent = self.backgroundContent {
                    self.backgroundContent = nil
                    backgroundContent.removeFromSupernode()
                }

                switch type {
                case .none:
                    break
                case .incoming:
                    if let backgroundContent = backgroundNode?.makeBubbleBackground(for: .incoming) {
                        backgroundContent.frame = self.bounds
                        if let (rect, containerSize) = self.absolutePosition {
                            var backgroundFrame = backgroundContent.frame
                            backgroundFrame.origin.x += rect.minX
                            backgroundFrame.origin.y += rect.minY
                            backgroundContent.update(rect: backgroundFrame, within: containerSize, transition: .immediate)
                        }
                        self.backgroundContent = backgroundContent
                        self.insertSubnode(backgroundContent, at: 0)
                    }
                case .outgoing:
                    if let backgroundContent = backgroundNode?.makeBubbleBackground(for: .outgoing) {
                        backgroundContent.frame = self.bounds
                        if let (rect, containerSize) = self.absolutePosition {
                            var backgroundFrame = backgroundContent.frame
                            backgroundFrame.origin.x += rect.minX
                            backgroundFrame.origin.y += rect.minY
                            backgroundContent.update(rect: backgroundFrame, within: containerSize, transition: .immediate)
                        }
                        self.backgroundContent = backgroundContent
                        self.insertSubnode(backgroundContent, at: 0)
                    }
                }
            }
            
            if let maskView = self.maskView {
                maskView.image = bubbleMaskForType(type, graphics: essentialGraphics)
            }
        }
    }
    
    func update(rect: CGRect, within containerSize: CGSize, transition: ContainedViewLayoutTransition = .immediate) {
        self.absolutePosition = (rect, containerSize)
        if let backgroundContent = self.backgroundContent {
            var backgroundFrame = backgroundContent.frame
            backgroundFrame.origin.x += rect.minX
            backgroundFrame.origin.y += rect.minY
            backgroundContent.update(rect: backgroundFrame, within: containerSize, transition: transition)
        }
    }
    
    func offset(value: CGPoint, animationCurve: ContainedViewLayoutTransitionCurve, duration: Double) {
        self.backgroundContent?.offset(value: value, animationCurve: animationCurve, duration: duration)
    }
    
    func offsetSpring(value: CGFloat, duration: Double, damping: CGFloat) {
        self.backgroundContent?.offsetSpring(value: value, duration: duration, damping: damping)
    }
    
    func updateFrame(_ value: CGRect, transition: ContainedViewLayoutTransition, completion: @escaping () -> Void = {}) {
        if let maskView = self.maskView {
            transition.updateFrame(view: maskView, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: value.size.width, height: value.size.height)).insetBy(dx: -maskInset, dy: -maskInset))
        }
        if let backgroundContent = self.backgroundContent {
            transition.updateFrame(layer: backgroundContent.layer, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: value.size.width, height: value.size.height)))
            if let (rect, containerSize) = self.absolutePosition {
                var backgroundFrame = backgroundContent.frame
                backgroundFrame.origin.x += rect.minX
                backgroundFrame.origin.y += rect.minY
                backgroundContent.update(rect: backgroundFrame, within: containerSize, transition: transition)
            }
        }
        transition.updateFrame(node: self, frame: value, completion: { _ in
            completion()
        })
    }

    func updateFrame(_ value: CGRect, transition: CombinedTransition, completion: @escaping () -> Void = {}) {
        if let maskView = self.maskView {
            transition.updateFrame(layer: maskView.layer, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: value.size.width, height: value.size.height)).insetBy(dx: -maskInset, dy: -maskInset))
        }
        if let backgroundContent = self.backgroundContent {
            transition.updateFrame(layer: backgroundContent.layer, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: value.size.width, height: value.size.height)))
            if let (rect, containerSize) = self.absolutePosition {
                var backgroundFrame = backgroundContent.frame
                backgroundFrame.origin.x += rect.minX
                backgroundFrame.origin.y += rect.minY
                backgroundContent.update(rect: backgroundFrame, within: containerSize, transition: transition)
            }
        }
        transition.updateFrame(layer: self.layer, frame: value, completion: { _ in
            completion()
        })
    }

    func animateFrom(sourceView: UIView, mediaBox: MediaBox, transition: CombinedTransition) {
        if transition.isAnimated {
            let previousFrame = self.frame
            self.updateFrame(CGRect(origin: CGPoint(x: previousFrame.minX, y: sourceView.frame.minY), size: sourceView.frame.size), transition: .immediate)
            self.updateFrame(previousFrame, transition: transition)

            self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.1)
        }
    }
}
