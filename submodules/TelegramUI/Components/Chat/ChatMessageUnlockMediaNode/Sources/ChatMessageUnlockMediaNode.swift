import Foundation
import UIKit
import AsyncDisplayKit
import Postbox
import Display
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import AccountContext
import LocalizedPeerData
import PhotoResources
import TelegramStringFormatting
import TextFormat
import TextNodeWithEntities
import AnimationCache
import MultiAnimationRenderer
import ComponentFlow
import ChatControllerInteraction
import HierarchyTrackingLayer

public class ChatMessageUnlockMediaNode: ASDisplayNode {
    public class Arguments {
        public let presentationData: ChatPresentationData
        public let strings: PresentationStrings
        public let context: AccountContext
        public let controllerInteraction: ChatControllerInteraction
        public let message: Message
        public let media: TelegramMediaPaidContent
        public let constrainedSize: CGSize
        public let animationCache: AnimationCache?
        public let animationRenderer: MultiAnimationRenderer?
        
        public init(
            presentationData: ChatPresentationData,
            strings: PresentationStrings,
            context: AccountContext,
            controllerInteraction: ChatControllerInteraction,
            message: Message,
            media: TelegramMediaPaidContent,
            constrainedSize: CGSize,
            animationCache: AnimationCache?,
            animationRenderer: MultiAnimationRenderer?
        ) {
            self.presentationData = presentationData
            self.strings = strings
            self.context = context
            self.controllerInteraction = controllerInteraction
            self.message = message
            self.media = media
            self.constrainedSize = constrainedSize
            self.animationCache = animationCache
            self.animationRenderer = animationRenderer
        }
    }
    
    public var visibility: Bool = false {
        didSet {
            if self.visibility != oldValue {
                self.textNode?.visibilityRect = self.visibility ? CGRect.infinite : nil
            }
        }
    }
        
    private let contentNode: HighlightTrackingButtonNode
    private let backgroundNode: NavigationBackgroundNode
    private var textNode: TextNodeWithEntities?
    private var loadingView: LoadingEffectView?
    
    private var pressed = { }
    
    private var absolutePosition: (CGRect, CGSize)?
    
    private var currentProgressDisposable: Disposable?
    
    override public init() {
        self.contentNode = HighlightTrackingButtonNode()
        
        self.backgroundNode = NavigationBackgroundNode(color: UIColor(rgb: 0x000000, alpha: 0.3))
        
        super.init()
        
        self.contentNode.isUserInteractionEnabled = true
        
        self.addSubnode(self.contentNode)
        self.contentNode.addSubnode(self.backgroundNode)
                
        self.contentNode.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
    }
    
    deinit {
        self.currentProgressDisposable?.dispose()
    }
    
    @objc private func buttonPressed() {
        self.pressed()
    }
    
    public func makeProgress() -> Promise<Bool> {
        let progress = Promise<Bool>()
        self.currentProgressDisposable?.dispose()
        self.currentProgressDisposable = (progress.get()
        |> distinctUntilChanged
        |> deliverOnMainQueue).start(next: { [weak self] hasProgress in
            guard let self, let loadingView = self.loadingView else {
                return
            }
            let transition = ContainedViewLayoutTransition.animated(duration: 0.2, curve: .easeInOut)
            if hasProgress {
                if loadingView.superview == nil {
                    loadingView.alpha = 0.0
                    self.view.addSubview(loadingView)
                    transition.updateAlpha(layer: loadingView.layer, alpha: 1.0)
                }
            } else if loadingView.superview != nil {
                transition.updateAlpha(layer: loadingView.layer, alpha: 0.0, beginWithCurrentState: true, completion: { finished in
                    if finished {
                        loadingView.removeFromSuperview()
                    }
                })
            }
        })
        return progress
    }
    
    public class func asyncLayout(_ maybeNode: ChatMessageUnlockMediaNode?) -> (_ arguments: Arguments) -> (CGSize, (Bool) -> ChatMessageUnlockMediaNode) {
        let textNodeLayout = TextNodeWithEntities.asyncLayout(maybeNode?.textNode)
    
        return { arguments in
            let fontSize = floor(arguments.presentationData.fontSize.baseDisplaySize * 14.0 / 17.0)
            let textFont = Font.medium(fontSize)
                           
            let padding: CGFloat = 10.0
            let amountString = presentationStringsFormattedNumber(Int32(arguments.media.amount), arguments.presentationData.dateTimeFormat.groupingSeparator)
            let text = NSMutableAttributedString(string: arguments.presentationData.strings.Chat_PaidMedia_UnlockMedia("⭐️ \(amountString)").string, font: textFont, textColor: .white)
            if let range = text.string.range(of: "⭐️") {
                text.addAttribute(ChatTextInputAttributes.customEmoji, value: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: 0, file: nil, custom: .stars(tinted: false)), range: NSRange(range, in: text.string))
                text.addAttribute(.baselineOffset, value: 0.5, range: NSRange(range, in: text.string))
            }
            
            let (textLayout, textApply) = textNodeLayout(TextNodeLayoutArguments(attributedString: text, backgroundColor: nil, maximumNumberOfLines: 2, truncationType: .end, constrainedSize: CGSize(width: arguments.constrainedSize.width, height: arguments.constrainedSize.height), alignment: .natural, cutout: nil, insets: .zero))
            
            let size = CGSize(width: textLayout.size.width + padding * 2.0, height: 32.0)
            
            return (size, { attemptSynchronous in
                let node: ChatMessageUnlockMediaNode
                if let maybeNode = maybeNode {
                    node = maybeNode
                } else {
                    node = ChatMessageUnlockMediaNode()
                }
                
                node.pressed = {
                    let _ = arguments.controllerInteraction.openMessage(arguments.message, OpenMessageParams(mode: .default))
                }
                                 
                node.textNode?.textNode.displaysAsynchronously = !arguments.presentationData.isPreview
                
                var textArguments: TextNodeWithEntities.Arguments?
                if let cache = arguments.animationCache, let renderer = arguments.animationRenderer {
                    textArguments = TextNodeWithEntities.Arguments(context: arguments.context, cache: cache, renderer: renderer, placeholderColor: .clear, attemptSynchronous: attemptSynchronous)
                }
                let textNode = textApply(textArguments)
                textNode.visibilityRect = node.visibility ? CGRect.infinite : nil
                
                if node.textNode == nil {
                    textNode.textNode.isUserInteractionEnabled = false
                    node.textNode = textNode
                    node.contentNode.addSubnode(textNode.textNode)
                }
                
                let textFrame = CGRect(origin: CGPoint(x: padding, y: floorToScreenPixels((size.height - textLayout.size.height) / 2.0)), size: textLayout.size)
                textNode.textNode.frame = textFrame
                 
                node.backgroundNode.frame = CGRect(origin: CGPoint(), size: size)
                node.backgroundNode.update(size: size, cornerRadius: size.height / 2.0, transition: .immediate)
                node.contentNode.frame = CGRect(origin: CGPoint(), size: size)
                
                let loadingView: LoadingEffectView
                if let current = node.loadingView {
                    loadingView = current
                } else {
                    loadingView = LoadingEffectView()
                    node.loadingView = loadingView
                }
                loadingView.frame = CGRect(origin: .zero, size: size)
                loadingView.update(color: UIColor.white, rect: CGRect(origin: .zero, size: size))
                
                return node
            })
        }
    }
}

private let shadowImage: UIImage? = {
    UIImage(named: "Stories/PanelGradient")
}()

public final class LoadingEffectView: UIView {
    let hierarchyTrackingLayer: HierarchyTrackingLayer
    
    private let maskContentsView: UIView
    private let maskHighlightNode: LinkHighlightingNode
    
    private let maskBorderContentsView: UIView
    private let maskBorderHighlightNode: LinkHighlightingNode
    
    private let backgroundView: UIImageView
    private let borderBackgroundView: UIImageView
    
    private var duration: Double
    private var gradientWidth: CGFloat
    
    private var inHierarchy = false
    private var size: CGSize?
    
    override public init(frame: CGRect) {
        self.hierarchyTrackingLayer = HierarchyTrackingLayer()
        
        self.maskContentsView = UIView()
        self.maskHighlightNode = LinkHighlightingNode(color: .black)
        self.maskHighlightNode.useModernPathCalculation = true
        
        self.maskBorderContentsView = UIView()
        self.maskBorderHighlightNode = LinkHighlightingNode(color: .black)
        self.maskBorderHighlightNode.borderOnly = true
        self.maskBorderHighlightNode.useModernPathCalculation = true
        
        self.maskBorderContentsView.addSubview(self.maskBorderHighlightNode.view)
        
        self.backgroundView = UIImageView()
        self.borderBackgroundView = UIImageView()
        
        self.gradientWidth = 120.0
        self.duration = 1.0
        
        super.init(frame: frame)
        
        self.isUserInteractionEnabled = false
        
        self.maskContentsView.mask = self.maskHighlightNode.view
        self.maskContentsView.addSubview(self.backgroundView)
        self.addSubview(self.maskContentsView)
        
        self.maskBorderContentsView.mask = self.maskBorderHighlightNode.view
        self.maskBorderContentsView.addSubview(self.borderBackgroundView)
        self.addSubview(self.maskBorderContentsView)
        
        let generateGradient: (CGFloat) -> UIImage? = { baseAlpha in
            return generateImage(CGSize(width: self.gradientWidth, height: 16.0), opaque: false, scale: 1.0, rotatedContext: { size, context in
                context.clear(CGRect(origin: CGPoint(), size: size))
                
                let foregroundColor = UIColor(white: 1.0, alpha: min(1.0, baseAlpha * 4.0))
                
                if let shadowImage {
                    UIGraphicsPushContext(context)
                    
                    for i in 0 ..< 2 {
                        let shadowFrame = CGRect(origin: CGPoint(x: CGFloat(i) * (size.width * 0.5), y: 0.0), size: CGSize(width: size.width * 0.5, height: size.height))
                        
                        context.saveGState()
                        context.translateBy(x: shadowFrame.midX, y: shadowFrame.midY)
                        context.rotate(by: CGFloat(i == 0 ? 1.0 : -1.0) * CGFloat.pi * 0.5)
                        let adjustedRect = CGRect(origin: CGPoint(x: -shadowFrame.height * 0.5, y: -shadowFrame.width * 0.5), size: CGSize(width: shadowFrame.height, height: shadowFrame.width))
                        
                        context.clip(to: adjustedRect, mask: shadowImage.cgImage!)
                        context.setFillColor(foregroundColor.cgColor)
                        context.fill(adjustedRect)
                        
                        context.restoreGState()
                    }
                    
                    UIGraphicsPopContext()
                }
            })?.withRenderingMode(.alwaysTemplate)
        }
        
        self.backgroundView.image = generateGradient(0.5)
        self.borderBackgroundView.image = generateGradient(1.0)
        
        self.layer.addSublayer(self.hierarchyTrackingLayer)
        self.hierarchyTrackingLayer.isInHierarchyUpdated = { [weak self] inHierarchy in
            guard let self, let size = self.size else {
                return
            }
            self.inHierarchy = inHierarchy
            self.updateAnimations(size: size)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func updateAnimations(size: CGSize) {
        if self.inHierarchy {
            if self.backgroundView.layer.animation(forKey: "shimmer") != nil {
                return
            }
            let animation = self.backgroundView.layer.makeAnimation(from: 0.0 as NSNumber, to: (size.width + self.gradientWidth + size.width * 0.0) as NSNumber, keyPath: "position.x", timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, duration: self.duration, delay: 0.0, mediaTimingFunction: nil, removeOnCompletion: true, additive: true)
            animation.repeatCount = Float.infinity
            self.backgroundView.layer.add(animation, forKey: "shimmer")
            self.borderBackgroundView.layer.add(animation, forKey: "shimmer")
        } else {
            self.backgroundView.layer.removeAllAnimations()
            self.borderBackgroundView.layer.removeAllAnimations()
        }
    }
    
    public func update(color: UIColor, rect: CGRect) {
        let maskFrame = CGRect(origin: CGPoint(), size: rect.size).insetBy(dx: -4.0, dy: -4.0)
        
        self.gradientWidth = 260.0
        self.duration = 1.2
        
        self.maskContentsView.backgroundColor = .clear
        self.maskBorderContentsView.backgroundColor = color.withAlphaComponent(0.12)
        
//        self.backgroundView.alpha = 0.25
        self.backgroundView.tintColor = color
        
        self.borderBackgroundView.tintColor = color
    
        self.maskContentsView.frame = maskFrame
        self.maskBorderContentsView.frame = maskFrame
        
        let rectsSet: [CGRect] = [rect]
                
        self.maskHighlightNode.outerRadius = rect.height / 2.0
        self.maskHighlightNode.updateRects(rectsSet)
        self.maskHighlightNode.frame = CGRect(origin: CGPoint(x: -maskFrame.minX, y: -maskFrame.minY), size: CGSize())
        
        self.maskBorderHighlightNode.outerRadius = rect.height / 2.0
        self.maskBorderHighlightNode.updateRects(rectsSet)
        self.maskBorderHighlightNode.frame = CGRect(origin: CGPoint(x: -maskFrame.minX, y: -maskFrame.minY), size: CGSize())
        
        if self.size != maskFrame.size {
            self.size = maskFrame.size
            
            self.backgroundView.frame = CGRect(origin: CGPoint(x: -self.gradientWidth, y: 0.0), size: CGSize(width: self.gradientWidth, height: maskFrame.height))
            self.borderBackgroundView.frame = CGRect(origin: CGPoint(x: -self.gradientWidth, y: 0.0), size: CGSize(width: self.gradientWidth, height: maskFrame.height))
            
            self.updateAnimations(size: maskFrame.size)
        }
    }
}
