import Foundation
import UIKit
import Display
import ComponentFlow
import MultilineTextComponent
import AccountContext
import TelegramCore
import TextNodeWithEntities
import TextFormat
import InvisibleInkDustNode
import UrlEscaping
import TelegramPresentationData
import TextSelectionNode

final class StoryContentCaptionComponent: Component {
    enum Action {
        case url(url: String, concealed: Bool)
        case textMention(String)
        case peerMention(peerId: EnginePeer.Id, mention: String)
        case hashtag(String?, String)
        case bankCard(String)
        case customEmoji(TelegramMediaFile)
    }
    
    final class ExternalState {
        fileprivate(set) var isExpanded: Bool = false
        fileprivate(set) var isSelectingText: Bool = false
        
        init() {
        }
    }
    
    final class TransitionHint {
        enum Kind {
            case isExpandedUpdated
        }
        
        let kind: Kind
        
        init(kind: Kind) {
            self.kind = kind
        }
    }
    
    private final class InternalTransitionHint {
        let bounceScrolling: Bool
        
        init(bounceScrolling: Bool) {
            self.bounceScrolling = bounceScrolling
        }
    }
    
    let externalState: ExternalState
    let context: AccountContext
    let strings: PresentationStrings
    let theme: PresentationTheme
    let text: String
    let entities: [MessageTextEntity]
    let entityFiles: [EngineMedia.Id: TelegramMediaFile]
    let action: (Action) -> Void
    let longTapAction: (Action) -> Void
    let textSelectionAction: (NSAttributedString, TextSelectionAction) -> Void
    let controller: () -> ViewController?
    
    init(
        externalState: ExternalState,
        context: AccountContext,
        strings: PresentationStrings,
        theme: PresentationTheme,
        text: String,
        entities: [MessageTextEntity],
        entityFiles: [EngineMedia.Id: TelegramMediaFile],
        action: @escaping (Action) -> Void,
        longTapAction: @escaping (Action) -> Void,
        textSelectionAction: @escaping (NSAttributedString, TextSelectionAction) -> Void,
        controller: @escaping () -> ViewController?
    ) {
        self.externalState = externalState
        self.context = context
        self.strings = strings
        self.theme = theme
        self.text = text
        self.entities = entities
        self.entityFiles = entityFiles
        self.action = action
        self.longTapAction = longTapAction
        self.textSelectionAction = textSelectionAction
        self.controller = controller
    }

    static func ==(lhs: StoryContentCaptionComponent, rhs: StoryContentCaptionComponent) -> Bool {
        if lhs.externalState !== rhs.externalState {
            return false
        }
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.text != rhs.text {
            return false
        }
        if lhs.entities != rhs.entities {
            return false
        }
        if lhs.entityFiles != rhs.entityFiles {
            return false
        }
        return true
    }
    
    private struct ItemLayout {
        var containerSize: CGSize
        var visibleTextHeight: CGFloat
        var verticalInset: CGFloat
        
        init(
            containerSize: CGSize,
            visibleTextHeight: CGFloat,
            verticalInset: CGFloat
        ) {
            self.containerSize = containerSize
            self.visibleTextHeight = visibleTextHeight
            self.verticalInset = verticalInset
        }
    }
    
    private final class ContentItem: UIView {
        var textNode: TextNodeWithEntities?
        var spoilerTextNode: TextNodeWithEntities?
        var linkHighlightingNode: LinkHighlightingNode?
        var dustNode: InvisibleInkDustNode?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }

    final class View: UIView, UIScrollViewDelegate {
        private let scrollViewContainer: UIView
        private let scrollView: UIScrollView
        
        private let collapsedText: ContentItem
        private let expandedText: ContentItem
        private var textSelectionNode: TextSelectionNode?
        private let textSelectionKnobContainer: UIView
        private var textSelectionKnobSurface: UIView?
        
        private let scrollMaskContainer: UIView
        private let scrollFullMaskView: UIView
        private let scrollCenterMaskView: UIView
        private let scrollBottomMaskView: UIImageView
        private let scrollBottomFullMaskView: UIView
        private let scrollTopMaskView: UIImageView
        
        private let shadowGradientView: UIImageView

        private var component: StoryContentCaptionComponent?
        private weak var state: EmptyComponentState?
        
        private var itemLayout: ItemLayout?
        
        private var ignoreScrolling: Bool = false
        private var ignoreExternalState: Bool = false
        
        private var isExpanded: Bool = false
        
        private static let shadowImage: UIImage? = {
            UIImage(named: "Stories/PanelGradient")
        }()
        
        override init(frame: CGRect) {
            self.shadowGradientView = UIImageView()
            if let image = StoryContentCaptionComponent.View.shadowImage {
                self.shadowGradientView.image = image.stretchableImage(withLeftCapWidth: 0, topCapHeight: Int(image.size.height - 1.0))
            }
            
            self.scrollViewContainer = UIView()
            
            self.scrollView = UIScrollView()
            self.scrollView.canCancelContentTouches = true
            self.scrollView.delaysContentTouches = false
            self.scrollView.showsVerticalScrollIndicator = false
            self.scrollView.contentInsetAdjustmentBehavior = .never
            self.scrollView.alwaysBounceVertical = false
            
            self.scrollMaskContainer = UIView()
            
            self.scrollFullMaskView = UIView()
            self.scrollFullMaskView.backgroundColor = .white
            self.scrollFullMaskView.alpha = 0.0
            self.scrollMaskContainer.addSubview(self.scrollFullMaskView)
            
            self.scrollCenterMaskView = UIView()
            self.scrollCenterMaskView.backgroundColor = .white
            self.scrollMaskContainer.addSubview(self.scrollCenterMaskView)
            
            self.scrollBottomMaskView = UIImageView(image: generateGradientImage(size: CGSize(width: 8.0, height: 8.0), colors: [
                UIColor(white: 1.0, alpha: 1.0),
                UIColor(white: 1.0, alpha: 0.0)
            ], locations: [0.0, 1.0]))
            self.scrollMaskContainer.addSubview(self.scrollBottomMaskView)
            
            self.scrollBottomFullMaskView = UIView()
            self.scrollBottomFullMaskView.backgroundColor = .white
            self.scrollMaskContainer.addSubview(self.scrollBottomFullMaskView)
            
            self.scrollTopMaskView = UIImageView(image: generateGradientImage(size: CGSize(width: 8.0, height: 8.0), colors: [
                UIColor(white: 1.0, alpha: 0.0),
                UIColor(white: 1.0, alpha: 1.0)
            ], locations: [0.0, 1.0]))
            self.scrollMaskContainer.addSubview(self.scrollTopMaskView)
            
            self.collapsedText = ContentItem(frame: CGRect())
            self.expandedText = ContentItem(frame: CGRect())
            
            self.textSelectionKnobContainer = UIView()
            self.textSelectionKnobContainer.isUserInteractionEnabled = false

            super.init(frame: frame)
            
            self.addSubview(self.shadowGradientView)

            self.scrollViewContainer.addSubview(self.scrollView)
            self.scrollView.delegate = self
            self.addSubview(self.scrollViewContainer)
            
            self.scrollView.addSubview(self.collapsedText)
            self.scrollView.addSubview(self.expandedText)
            
            self.scrollViewContainer.mask = self.scrollMaskContainer
            
            self.addSubview(self.textSelectionKnobContainer)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            if !self.bounds.contains(point) {
                return nil
            }
            
            let contentItem = self.isExpanded ? self.expandedText : self.collapsedText
            
            if let textView = contentItem.textNode?.textNode.view {
                let textLocalPoint = self.convert(point, to: textView)
                if textLocalPoint.y >= -7.0 {
                    return self.textSelectionNode?.view ?? textView
                }
            }
            
            return nil
        }
        
        @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
            if case .ended = recognizer.state {
                if self.isExpanded {
                    self.collapse(transition: Transition(animation: .curve(duration: 0.4, curve: .spring)))
                } else {
                    self.expand(transition: Transition(animation: .curve(duration: 0.4, curve: .spring)))
                }
            }
        }
        
        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            guard let component = self.component else {
                return
            }
            if component.externalState.isSelectingText {
                self.cancelTextSelection()
            }
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            if !self.ignoreScrolling {
                self.updateScrolling(transition: .immediate)
            }
        }
        
        func expand(transition: Transition) {
            self.ignoreScrolling = true
            if let textNode = self.expandedText.textNode?.textNode {
                var offset = textNode.frame.minY - 8.0
                offset = max(0.0, offset)
                offset = min(self.scrollView.contentSize.height - self.scrollView.bounds.height, offset)
                if transition.animation.isImmediate {
                    transition.setBounds(view: self.scrollView, bounds: CGRect(origin: CGPoint(x: 0.0, y: offset), size: self.scrollView.bounds.size))
                } else {
                    let offsetDifference = -offset + self.scrollView.bounds.minY
                    self.scrollView.bounds = CGRect(origin: CGPoint(x: 0.0, y: offset), size: self.scrollView.bounds.size)
                    self.scrollView.layer.animateSpring(from: offsetDifference as NSNumber, to: 0.0 as NSNumber, keyPath: "bounds.origin.y", duration: 0.5, damping: 120.0, additive: true)
                }
            }
            self.ignoreScrolling = false
            
            self.updateScrolling(transition: transition.withUserData(InternalTransitionHint(bounceScrolling: true)))
        }
        
        func collapse(transition: Transition) {
            self.ignoreScrolling = true
            
            if transition.animation.isImmediate {
                transition.setBounds(view: self.scrollView, bounds: CGRect(origin: CGPoint(), size: self.scrollView.bounds.size))
            } else {
                let offsetDifference = self.scrollView.bounds.minY
                self.scrollView.bounds = CGRect(origin: CGPoint(), size: self.scrollView.bounds.size)
                self.scrollView.layer.animateSpring(from: offsetDifference as NSNumber, to: 0.0 as NSNumber, keyPath: "bounds.origin.y", duration: 0.5, damping: 120.0, additive: true)
            }
            
            self.ignoreScrolling = false
            
            self.updateScrolling(transition: transition.withUserData(InternalTransitionHint(bounceScrolling: true)))
        }
        
        func cancelTextSelection() {
            self.textSelectionNode?.cancelSelection()
        }
        
        private func updateScrolling(transition: Transition) {
            guard let component = self.component, let itemLayout = self.itemLayout else {
                return
            }
            
            var bounce = false
            if let internalTransitionHint = transition.userData(InternalTransitionHint.self) {
                bounce = internalTransitionHint.bounceScrolling
            }
            
            var edgeDistance = self.scrollView.contentSize.height - self.scrollView.bounds.maxY
            edgeDistance = max(0.0, min(7.0, edgeDistance))
            
            let edgeDistanceFraction = edgeDistance / 7.0
            transition.setAlpha(view: self.scrollFullMaskView, alpha: 1.0 - edgeDistanceFraction)
            
            transition.setBounds(view: self.textSelectionKnobContainer, bounds: CGRect(origin: CGPoint(x: 0.0, y: self.scrollView.bounds.minY), size: CGSize()))
            
            let shadowOverflow: CGFloat = 58.0
            let shadowFrame = CGRect(origin: CGPoint(x: 0.0, y:  -self.scrollView.contentOffset.y + itemLayout.containerSize.height - itemLayout.visibleTextHeight - itemLayout.verticalInset - shadowOverflow), size: CGSize(width: itemLayout.containerSize.width, height: itemLayout.visibleTextHeight + itemLayout.verticalInset + shadowOverflow))
            
            let shadowGradientFrame = CGRect(origin: CGPoint(x: shadowFrame.minX, y: shadowFrame.minY), size: CGSize(width: shadowFrame.width, height: self.scrollView.contentSize.height + 1000.0))
            if self.shadowGradientView.frame != shadowGradientFrame {
                if bounce, !transition.animation.isImmediate {
                    let offsetDifference = -shadowGradientFrame.minY + self.shadowGradientView.frame.minY
                    self.shadowGradientView.frame = shadowGradientFrame
                    self.shadowGradientView.layer.animateSpring(from: NSValue(cgPoint: CGPoint(x: 0.0, y: offsetDifference)), to: NSValue(cgPoint: CGPoint()), keyPath: "position", duration: 0.5, damping: 120.0, additive: true)
                } else {
                    transition.setFrame(view: self.shadowGradientView, frame: shadowGradientFrame)
                }
            }
            
            let expandDistance: CGFloat = 50.0
            var expandFraction: CGFloat = self.scrollView.contentOffset.y / expandDistance
            expandFraction = max(0.0, min(1.0, expandFraction))
            
            let isExpanded = expandFraction > 0.0
            
            self.isExpanded = isExpanded
            
            if component.externalState.isExpanded != isExpanded {
                component.externalState.isExpanded = isExpanded
                
                if !self.ignoreExternalState {
                    self.state?.updated(transition: transition.withUserData(TransitionHint(kind: .isExpandedUpdated)))
                }
            }
        }
        
        @objc func tapLongTapOrDoubleTapGesture(_ recognizer: TapLongTapOrDoubleTapGestureRecognizer) {
            if let textSelectionNode = self.textSelectionNode {
                if textSelectionNode.didRecognizeTap {
                    return
                }
            }
            
            let contentItem = self.isExpanded ? self.expandedText : self.collapsedText
            let otherContentItem = !self.isExpanded ? self.expandedText : self.collapsedText
            
            switch recognizer.state {
            case .ended:
                if let (gesture, location) = recognizer.lastRecognizedGestureAndLocation, let component = self.component, let textNode = contentItem.textNode {
                    let titleFrame = textNode.textNode.view.bounds
                    if titleFrame.contains(location) {
                        if let (index, attributes) = textNode.textNode.attributesAtPoint(CGPoint(x: location.x - titleFrame.minX, y: location.y - titleFrame.minY)) {
                            let action: Action?
                            if case .tap = gesture, let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.Spoiler)], !(contentItem.dustNode?.isRevealed ?? true)  {
                                let convertedPoint = recognizer.view?.convert(location, to: contentItem.dustNode?.view) ?? location
                                contentItem.dustNode?.revealAtLocation(convertedPoint)
                                otherContentItem.dustNode?.revealAtLocation(convertedPoint)
                                self.state?.updated(transition: Transition(animation: .curve(duration: 0.2, curve: .easeInOut)))
                                return
                            } else if let url = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] as? String {
                                var concealed = true
                                if let (attributeText, fullText) = textNode.textNode.attributeSubstring(name: TelegramTextAttributes.URL, index: index) {
                                    concealed = !doesUrlMatchText(url: url, text: attributeText, fullText: fullText)
                                }
                                action = .url(url: url, concealed: concealed)
                            } else if let peerMention = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.PeerMention)] as? TelegramPeerMention {
                                action = .peerMention(peerId: peerMention.peerId, mention: peerMention.mention)
                            } else if let peerName = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.PeerTextMention)] as? String {
                                action = .textMention(peerName)
                            } else if let hashtag = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.Hashtag)] as? TelegramHashtag {
                                action = .hashtag(hashtag.peerName, hashtag.hashtag)
                            } else if let bankCard = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.BankCard)] as? String {
                                action = .bankCard(bankCard)
                            } else if let emoji = attributes[NSAttributedString.Key(rawValue: ChatTextInputAttributes.customEmoji.rawValue)] as? ChatTextInputTextCustomEmojiAttribute, let file = emoji.file {
                                action = .customEmoji(file)
                            } else {
                                action = nil
                            }
                            if let action {
                                switch gesture {
                                case .tap:
                                    component.action(action)
                                case .longTap:
                                    component.longTapAction(action)
                                default:
                                    return
                                }
                            } else {
                                if case .tap = gesture {
                                    if component.externalState.isSelectingText {
                                        self.cancelTextSelection()
                                    } else if self.isExpanded {
                                        self.collapse(transition: Transition(animation: .curve(duration: 0.4, curve: .spring)))
                                    } else {
                                        self.expand(transition: Transition(animation: .curve(duration: 0.4, curve: .spring)))
                                    }
                                }
                            }
                        } else {
                            if case .tap = gesture {
                                if component.externalState.isSelectingText {
                                    self.cancelTextSelection()
                                } else if self.isExpanded {
                                    self.collapse(transition: Transition(animation: .curve(duration: 0.4, curve: .spring)))
                                } else {
                                    self.expand(transition: Transition(animation: .curve(duration: 0.4, curve: .spring)))
                                }
                            }
                        }
                    }
                }
            default:
                break
            }
        }
        
        private func updateTouchesAtPoint(_ point: CGPoint?) {
            let contentItem = self.isExpanded ? self.expandedText : self.collapsedText
            
            guard let textNode = contentItem.textNode else {
                return
            }
            var rects: [CGRect]?
            var spoilerRects: [CGRect]?
            if let point = point {
                let textNodeFrame = textNode.textNode.bounds
                if let (index, attributes) = textNode.textNode.attributesAtPoint(CGPoint(x: point.x - textNodeFrame.minX, y: point.y - textNodeFrame.minY)) {
                    let possibleNames: [String] = [
                        TelegramTextAttributes.URL,
                        TelegramTextAttributes.PeerMention,
                        TelegramTextAttributes.PeerTextMention,
                        TelegramTextAttributes.BotCommand,
                        TelegramTextAttributes.Hashtag,
                        TelegramTextAttributes.Timecode,
                        TelegramTextAttributes.BankCard
                    ]
                    for name in possibleNames {
                        if let _ = attributes[NSAttributedString.Key(rawValue: name)] {
                            rects = textNode.textNode.attributeRects(name: name, at: index)
                            break
                        }
                    }
                    if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.Spoiler)] {
                        spoilerRects = textNode.textNode.attributeRects(name: TelegramTextAttributes.Spoiler, at: index)
                    }
                }
            }
            
            if let spoilerRects = spoilerRects, !spoilerRects.isEmpty, let dustNode = contentItem.dustNode, !dustNode.isRevealed {
            } else if let rects = rects {
                let linkHighlightingNode: LinkHighlightingNode
                if let current = contentItem.linkHighlightingNode {
                    linkHighlightingNode = current
                } else {
                    linkHighlightingNode = LinkHighlightingNode(color: UIColor(white: 1.0, alpha: 0.5))
                    contentItem.linkHighlightingNode = linkHighlightingNode
                    contentItem.insertSubview(linkHighlightingNode.view, belowSubview: textNode.textNode.view)
                }
                linkHighlightingNode.frame = textNode.textNode.view.frame
                linkHighlightingNode.updateRects(rects)
            } else if let linkHighlightingNode = contentItem.linkHighlightingNode {
                contentItem.linkHighlightingNode = nil
                linkHighlightingNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.18, removeOnCompletion: false, completion: { [weak linkHighlightingNode] _ in
                    linkHighlightingNode?.removeFromSupernode()
                })
            }
        }
        
        func update(component: StoryContentCaptionComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            self.ignoreExternalState = true
            
            self.component = component
            self.state = state
            
            let sideInset: CGFloat = 16.0
            let verticalInset: CGFloat = 7.0
            let textContainerSize = CGSize(width: availableSize.width - sideInset * 2.0, height: availableSize.height - verticalInset * 2.0)
            
            let attributedText = stringWithAppliedEntities(
                component.text,
                entities: component.entities,
                baseColor: .white,
                linkColor: .white,
                baseFont: Font.regular(16.0),
                linkFont: Font.regular(16.0),
                boldFont: Font.semibold(16.0),
                italicFont: Font.italic(16.0),
                boldItalicFont: Font.semiboldItalic(16.0),
                fixedFont: Font.monospace(16.0),
                blockQuoteFont: Font.monospace(16.0),
                message: nil,
                entityFiles: component.entityFiles
            )
            
            let truncationToken = NSMutableAttributedString()
            truncationToken.append(NSAttributedString(string: "\u{2026} ", font: Font.regular(16.0), textColor: .white))
            truncationToken.append(NSAttributedString(string: component.strings.Story_CaptionShowMore, font: Font.semibold(16.0), textColor: .white))
            
            let collapsedTextLayout = TextNodeWithEntities.asyncLayout(self.collapsedText.textNode)(TextNodeLayoutArguments(
                attributedString: attributedText,
                maximumNumberOfLines: 3,
                truncationType: .end,
                constrainedSize: CGSize(width: textContainerSize.width, height: 10000.0),
                textShadowColor: UIColor(white: 0.0, alpha: 0.25),
                textShadowBlur: 4.0,
                displaySpoilers: false,
                customTruncationToken: truncationToken
            ))
            let expandedTextLayout = TextNodeWithEntities.asyncLayout(self.expandedText.textNode)(TextNodeLayoutArguments(
                attributedString: attributedText,
                maximumNumberOfLines: 0,
                truncationType: .end,
                constrainedSize: CGSize(width: textContainerSize.width, height: 10000.0),
                textShadowColor: UIColor(white: 0.0, alpha: 0.25),
                textShadowBlur: 4.0,
                displaySpoilers: false
            ))
            
            let collapsedSpoilerTextLayoutAndApply: (TextNodeLayout, (TextNodeWithEntities.Arguments?) -> TextNodeWithEntities)?
            if !collapsedTextLayout.0.spoilers.isEmpty {
                collapsedSpoilerTextLayoutAndApply = TextNodeWithEntities.asyncLayout(self.collapsedText.spoilerTextNode)(TextNodeLayoutArguments(attributedString: attributedText, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: textContainerSize.width, height: 10000.0), textShadowColor: UIColor(white: 0.0, alpha: 0.25), textShadowBlur: 4.0, displaySpoilers: true, displayEmbeddedItemsUnderSpoilers: true))
            } else {
                collapsedSpoilerTextLayoutAndApply = nil
            }
            
            let expandedSpoilerTextLayoutAndApply: (TextNodeLayout, (TextNodeWithEntities.Arguments?) -> TextNodeWithEntities)?
            if !expandedTextLayout.0.spoilers.isEmpty {
                expandedSpoilerTextLayoutAndApply = TextNodeWithEntities.asyncLayout(self.expandedText.spoilerTextNode)(TextNodeLayoutArguments(attributedString: attributedText, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: textContainerSize.width, height: 10000.0), textShadowColor: UIColor(white: 0.0, alpha: 0.25), textShadowBlur: 4.0, displaySpoilers: true, displayEmbeddedItemsUnderSpoilers: true))
            } else {
                expandedSpoilerTextLayoutAndApply = nil
            }
            
            let visibleTextHeight = collapsedTextLayout.0.size.height
            let textOverflowHeight: CGFloat = expandedTextLayout.0.size.height - visibleTextHeight
            let scrollContentSize = CGSize(width: availableSize.width, height: availableSize.height + textOverflowHeight)
            
            do {
                let collapsedTextNode = collapsedTextLayout.1(TextNodeWithEntities.Arguments(
                    context: component.context,
                    cache: component.context.animationCache,
                    renderer: component.context.animationRenderer,
                    placeholderColor: UIColor(white: 0.2, alpha: 1.0),
                    attemptSynchronous: true
                ))
                if self.collapsedText.textNode !== collapsedTextNode {
                    self.collapsedText.textNode?.textNode.view.removeFromSuperview()
                    
                    collapsedTextNode.textNode.displaysAsynchronously = false
                    
                    self.collapsedText.textNode = collapsedTextNode
                    if collapsedTextNode.textNode.view.superview == nil  {
                        self.collapsedText.addSubview(collapsedTextNode.textNode.view)
                    }
                    
                    collapsedTextNode.visibilityRect = CGRect(origin: CGPoint(), size: CGSize(width: 100000.0, height: 100000.0))
                }
                
                let collapsedTextFrame = CGRect(origin: CGPoint(x: sideInset, y: availableSize.height - visibleTextHeight - verticalInset), size: collapsedTextLayout.0.size)
                collapsedTextNode.textNode.frame = collapsedTextFrame
                
                if let (_, collapsedSpoilerTextApply) = collapsedSpoilerTextLayoutAndApply {
                    let collapsedSpoilerTextNode = collapsedSpoilerTextApply(TextNodeWithEntities.Arguments(
                        context: component.context,
                        cache: component.context.animationCache,
                        renderer: component.context.animationRenderer,
                        placeholderColor: UIColor(white: 0.2, alpha: 1.0),
                        attemptSynchronous: true
                    ))
                    if self.collapsedText.spoilerTextNode == nil {
                        collapsedSpoilerTextNode.textNode.alpha = 0.0
                        collapsedSpoilerTextNode.textNode.isUserInteractionEnabled = false
                        collapsedSpoilerTextNode.textNode.contentMode = .topLeft
                        collapsedSpoilerTextNode.textNode.contentsScale = UIScreenScale
                        collapsedSpoilerTextNode.textNode.displaysAsynchronously = false
                        self.collapsedText.insertSubview(collapsedSpoilerTextNode.textNode.view, belowSubview: collapsedTextNode.textNode.view)
                        
                        collapsedSpoilerTextNode.visibilityRect = CGRect(origin: CGPoint(), size: CGSize(width: 100000.0, height: 100000.0))
                        
                        self.collapsedText.spoilerTextNode = collapsedSpoilerTextNode
                    }
                    
                    self.collapsedText.spoilerTextNode?.textNode.frame = collapsedTextFrame
                    
                    let collapsedDustNode: InvisibleInkDustNode
                    if let current = self.collapsedText.dustNode {
                        collapsedDustNode = current
                    } else {
                        collapsedDustNode = InvisibleInkDustNode(textNode: collapsedSpoilerTextNode.textNode, enableAnimations: component.context.sharedContext.energyUsageSettings.fullTranslucency)
                        self.collapsedText.dustNode = collapsedDustNode
                        self.collapsedText.insertSubview(collapsedDustNode.view, aboveSubview: collapsedSpoilerTextNode.textNode.view)
                    }
                    collapsedDustNode.frame = collapsedTextFrame.insetBy(dx: -3.0, dy: -3.0).offsetBy(dx: 0.0, dy: 0.0)
                    collapsedDustNode.update(size: collapsedDustNode.frame.size, color: .white, textColor: .white, rects: collapsedTextLayout.0.spoilers.map { $0.1.offsetBy(dx: 3.0, dy: 3.0).insetBy(dx: 1.0, dy: 1.0) }, wordRects: collapsedTextLayout.0.spoilerWords.map { $0.1.offsetBy(dx: 3.0, dy: 3.0).insetBy(dx: 1.0, dy: 1.0) })
                } else if let collapsedSpoilerTextNode = self.collapsedText.spoilerTextNode {
                    self.collapsedText.spoilerTextNode = nil
                    collapsedSpoilerTextNode.textNode.removeFromSupernode()
                    
                    if let collapsedDustNode = self.collapsedText.dustNode {
                        self.collapsedText.dustNode = nil
                        collapsedDustNode.view.removeFromSuperview()
                    }
                }
            }
            
            do {
                let expandedTextNode = expandedTextLayout.1(TextNodeWithEntities.Arguments(
                    context: component.context,
                    cache: component.context.animationCache,
                    renderer: component.context.animationRenderer,
                    placeholderColor: UIColor(white: 0.2, alpha: 1.0),
                    attemptSynchronous: true
                ))
                if self.expandedText.textNode !== expandedTextNode {
                    self.expandedText.textNode?.textNode.view.removeFromSuperview()
                    
                    self.expandedText.textNode = expandedTextNode
                    if expandedTextNode.textNode.view.superview == nil  {
                        self.expandedText.addSubview(expandedTextNode.textNode.view)
                    }
                    
                    expandedTextNode.visibilityRect = CGRect(origin: CGPoint(), size: CGSize(width: 100000.0, height: 100000.0))
                }
                
                let expandedTextFrame = CGRect(origin: CGPoint(x: sideInset, y: availableSize.height - visibleTextHeight - verticalInset), size: expandedTextLayout.0.size)
                expandedTextNode.textNode.frame = expandedTextFrame
                
                if let (_, expandedSpoilerTextApply) = expandedSpoilerTextLayoutAndApply {
                    let expandedSpoilerTextNode = expandedSpoilerTextApply(TextNodeWithEntities.Arguments(
                        context: component.context,
                        cache: component.context.animationCache,
                        renderer: component.context.animationRenderer,
                        placeholderColor: UIColor(white: 0.2, alpha: 1.0),
                        attemptSynchronous: true
                    ))
                    if self.expandedText.spoilerTextNode == nil {
                        expandedSpoilerTextNode.textNode.alpha = 0.0
                        expandedSpoilerTextNode.textNode.isUserInteractionEnabled = false
                        expandedSpoilerTextNode.textNode.contentMode = .topLeft
                        expandedSpoilerTextNode.textNode.contentsScale = UIScreenScale
                        expandedSpoilerTextNode.textNode.displaysAsynchronously = false
                        self.expandedText.insertSubview(expandedSpoilerTextNode.textNode.view, belowSubview: expandedTextNode.textNode.view)
                        
                        expandedSpoilerTextNode.visibilityRect = CGRect(origin: CGPoint(), size: CGSize(width: 100000.0, height: 100000.0))
                        
                        self.expandedText.spoilerTextNode = expandedSpoilerTextNode
                    }
                    
                    self.expandedText.spoilerTextNode?.textNode.frame = expandedTextFrame
                    
                    let expandedDustNode: InvisibleInkDustNode
                    if let current = self.expandedText.dustNode {
                        expandedDustNode = current
                    } else {
                        expandedDustNode = InvisibleInkDustNode(textNode: expandedSpoilerTextNode.textNode, enableAnimations: component.context.sharedContext.energyUsageSettings.fullTranslucency)
                        self.expandedText.dustNode = expandedDustNode
                        self.expandedText.insertSubview(expandedDustNode.view, aboveSubview: expandedSpoilerTextNode.textNode.view)
                    }
                    expandedDustNode.frame = expandedTextFrame.insetBy(dx: -3.0, dy: -3.0).offsetBy(dx: 0.0, dy: 0.0)
                    expandedDustNode.update(size: expandedDustNode.frame.size, color: .white, textColor: .white, rects: expandedTextLayout.0.spoilers.map { $0.1.offsetBy(dx: 3.0, dy: 3.0).insetBy(dx: 1.0, dy: 1.0) }, wordRects: expandedTextLayout.0.spoilerWords.map { $0.1.offsetBy(dx: 3.0, dy: 3.0).insetBy(dx: 1.0, dy: 1.0) })
                } else if let expandedSpoilerTextNode = self.expandedText.spoilerTextNode {
                    self.expandedText.spoilerTextNode = nil
                    expandedSpoilerTextNode.textNode.removeFromSupernode()
                    
                    if let expandedDustNode = self.expandedText.dustNode {
                        self.expandedText.dustNode = nil
                        expandedDustNode.view.removeFromSuperview()
                    }
                }
            }
            
            if self.textSelectionNode == nil, let controller = component.controller(), let textNode = self.expandedText.textNode?.textNode {
                let selectionColor = UIColor(white: 1.0, alpha: 0.5)
                
                if self.textSelectionKnobSurface == nil {
                    let textSelectionKnobSurface = UIView()
                    self.textSelectionKnobSurface = textSelectionKnobSurface
                    self.textSelectionKnobContainer.addSubview(textSelectionKnobSurface)
                }
                
                let textSelectionNode = TextSelectionNode(theme: TextSelectionTheme(selection: selectionColor, knob: component.theme.list.itemAccentColor), strings: component.strings, textNode: textNode, updateIsActive: { [weak self] value in
                    guard let self else {
                        return
                    }
                    if component.externalState.isSelectingText != value {
                        component.externalState.isSelectingText = value
                        
                        if !self.ignoreExternalState {
                            self.state?.updated(transition: transition)
                        }
                    }
                }, present: { [weak self] c, a in
                    guard let self, let component = self.component else {
                        return
                    }
                    component.controller()?.presentInGlobalOverlay(c, with: a)
                }, rootNode: controller.displayNode, externalKnobSurface: self.textSelectionKnobSurface, performAction: { [weak self] text, action in
                    guard let self, let component = self.component else {
                        return
                    }
                    component.textSelectionAction(text, action)
                })
                /*textSelectionNode.updateRange = { [weak self] selectionRange in
                 if let strongSelf = self, let dustNode = strongSelf.dustNode, !dustNode.isRevealed, let textLayout = strongSelf.textNode.textNode.cachedLayout, !textLayout.spoilers.isEmpty, let selectionRange = selectionRange {
                 for (spoilerRange, _) in textLayout.spoilers {
                 if let intersection = selectionRange.intersection(spoilerRange), intersection.length > 0 {
                 dustNode.update(revealed: true)
                 return
                 }
                 }
                 }
                 }*/
                textSelectionNode.enableLookup = true
                self.textSelectionNode = textSelectionNode
                self.scrollView.addSubview(textSelectionNode.view)
                self.scrollView.insertSubview(textSelectionNode.highlightAreaNode.view, at: 0)
                
                textSelectionNode.canBeginSelection = { [weak self] location in
                    guard let self else {
                        return false
                    }
                    
                    let contentItem = self.expandedText
                    guard let textNode = contentItem.textNode else {
                        return false
                    }
                    
                    let titleFrame = textNode.textNode.view.bounds
                    
                    if let (index, attributes) = textNode.textNode.attributesAtPoint(CGPoint(x: location.x - titleFrame.minX, y: location.y - titleFrame.minY)) {
                        let action: Action?
                        if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.Spoiler)], !(contentItem.dustNode?.isRevealed ?? true)  {
                            return false
                        } else if let url = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] as? String {
                            var concealed = true
                            if let (attributeText, fullText) = textNode.textNode.attributeSubstring(name: TelegramTextAttributes.URL, index: index) {
                                concealed = !doesUrlMatchText(url: url, text: attributeText, fullText: fullText)
                            }
                            action = .url(url: url, concealed: concealed)
                        } else if let peerMention = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.PeerMention)] as? TelegramPeerMention {
                            action = .peerMention(peerId: peerMention.peerId, mention: peerMention.mention)
                        } else if let peerName = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.PeerTextMention)] as? String {
                            action = .textMention(peerName)
                        } else if let hashtag = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.Hashtag)] as? TelegramHashtag {
                            action = .hashtag(hashtag.peerName, hashtag.hashtag)
                        } else if let bankCard = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.BankCard)] as? String {
                            action = .bankCard(bankCard)
                        } else if let emoji = attributes[NSAttributedString.Key(rawValue: ChatTextInputAttributes.customEmoji.rawValue)] as? ChatTextInputTextCustomEmojiAttribute, let file = emoji.file {
                            action = .customEmoji(file)
                        } else {
                            action = nil
                        }
                        if action != nil {
                            return false
                        }
                    }
                    
                    return true
                }
                
                //let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:)))
                //textSelectionNode.view.addGestureRecognizer(tapRecognizer)
                
                let _ = textSelectionNode.view
                
                let recognizer = TapLongTapOrDoubleTapGestureRecognizer(target: self, action: #selector(self.tapLongTapOrDoubleTapGesture(_:)))
                /*if let selectionRecognizer = textSelectionNode.recognizer {
                    recognizer.require(toFail: selectionRecognizer)
                }*/
                recognizer.tapActionAtPoint = { point in
                    return .waitForSingleTap
                }
                recognizer.highlight = { [weak self] point in
                    guard let self else {
                        return
                    }
                    self.updateTouchesAtPoint(point)
                }
                textSelectionNode.view.addGestureRecognizer(recognizer)
            }
            
            if let textSelectionNode = self.textSelectionNode, let textNode = self.expandedText.textNode?.textNode {
                textSelectionNode.frame = textNode.frame.offsetBy(dx: self.expandedText.frame.minX, dy: self.expandedText.frame.minY)
                textSelectionNode.highlightAreaNode.frame = textSelectionNode.frame
                if let textSelectionKnobSurface = self.textSelectionKnobSurface {
                    textSelectionKnobSurface.frame = textSelectionNode.frame
                }
            }
            
            self.itemLayout = ItemLayout(
                containerSize: availableSize,
                visibleTextHeight: visibleTextHeight,
                verticalInset: verticalInset
            )
            
            self.ignoreScrolling = true
            
            if self.scrollView.contentSize != scrollContentSize {
                self.scrollView.contentSize = scrollContentSize
            }
            transition.setFrame(view: self.scrollView, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: availableSize.width, height: availableSize.height)))
            transition.setFrame(view: self.scrollViewContainer, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: availableSize.width, height: availableSize.height)))
            
            /*if self.shadowGradientLayer.colors == nil {
                var locations: [NSNumber] = []
                var colors: [CGColor] = []
                let numStops = 10
                let baseAlpha: CGFloat = 0.6
                for i in 0 ..< numStops {
                    let step = 1.0 - CGFloat(i) / CGFloat(numStops - 1)
                    locations.append((1.0 - step) as NSNumber)
                    let alphaStep: CGFloat = pow(step, 1.0)
                    colors.append(UIColor.black.withAlphaComponent(alphaStep * baseAlpha).cgColor)
                }
                
                self.shadowGradientLayer.startPoint = CGPoint(x: 0.0, y: 1.0)
                self.shadowGradientLayer.endPoint = CGPoint(x: 0.0, y: 0.0)
                
                self.shadowGradientLayer.locations = locations
                self.shadowGradientLayer.colors = colors
                self.shadowGradientLayer.type = .axial
                
                self.shadowPlainLayer.backgroundColor = UIColor(white: 0.0, alpha: baseAlpha).cgColor
            }*/
            
            self.ignoreScrolling = false
            self.updateScrolling(transition: transition)
            
            let gradientEdgeHeight: CGFloat = 18.0
            
            transition.setFrame(view: self.scrollFullMaskView, frame: CGRect(origin: CGPoint(x: 0.0, y: gradientEdgeHeight), size: CGSize(width: availableSize.width, height: availableSize.height - gradientEdgeHeight)))
            transition.setFrame(view: self.scrollCenterMaskView, frame: CGRect(origin: CGPoint(x: 0.0, y: gradientEdgeHeight), size: CGSize(width: availableSize.width, height: availableSize.height - gradientEdgeHeight * 2.0)))
            transition.setFrame(view: self.scrollBottomMaskView, frame: CGRect(origin: CGPoint(x: 0.0, y: availableSize.height - gradientEdgeHeight), size: CGSize(width: availableSize.width, height: gradientEdgeHeight)))
            transition.setFrame(view: self.scrollBottomFullMaskView, frame: CGRect(origin: CGPoint(x: 0.0, y: availableSize.height - gradientEdgeHeight), size: CGSize(width: availableSize.width, height: gradientEdgeHeight)))
            transition.setFrame(view: self.scrollTopMaskView, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: availableSize.width, height: gradientEdgeHeight)))
            
            self.ignoreExternalState = false
            
            var isExpandedTransition = transition
            if transition.animation.isImmediate, let hint = transition.userData(TransitionHint.self), case .isExpandedUpdated = hint.kind {
                isExpandedTransition = transition.withAnimation(.curve(duration: 0.25, curve: .easeInOut))
            }
            
            isExpandedTransition.setAlpha(view: self.collapsedText, alpha: self.isExpanded ? 0.0 : 1.0)
            isExpandedTransition.setAlpha(view: self.expandedText, alpha: !self.isExpanded ? 0.0 : 1.0)
            
            /*if let spoilerTextNode = self.collapsedText.spoilerTextNode {
                var spoilerAlpha = self.isExpanded ? 0.0 : 1.0
                if let dustNode = self.collapsedText.dustNode, dustNode.isRevealed {
                } else {
                    spoilerAlpha = 0.0
                }
                isExpandedTransition.setAlpha(view: spoilerTextNode.textNode.view, alpha: spoilerAlpha)
            }
            if let dustNode = self.collapsedText.dustNode {
                isExpandedTransition.setAlpha(view: dustNode.view, alpha: self.isExpanded ? 0.0 : 1.0)
            }*/
            
            /*if let textNode = self.expandedText.textNode {
                isExpandedTransition.setAlpha(view: textNode.textNode.view, alpha: !self.isExpanded ? 0.0 : 1.0)
            }
            if let spoilerTextNode = self.expandedText.spoilerTextNode {
                var spoilerAlpha = !self.isExpanded ? 0.0 : 1.0
                if let dustNode = self.expandedText.dustNode, dustNode.isRevealed {
                } else {
                    spoilerAlpha = 0.0
                }
                isExpandedTransition.setAlpha(view: spoilerTextNode.textNode.view, alpha: spoilerAlpha)
            }
            if let dustNode = self.expandedText.dustNode {
                isExpandedTransition.setAlpha(view: dustNode.view, alpha: !self.isExpanded ? 0.0 : 1.0)
            }*/
            
            isExpandedTransition.setAlpha(view: self.shadowGradientView, alpha: self.isExpanded ? 0.0 : 1.0)
            
            isExpandedTransition.setAlpha(view: self.scrollBottomMaskView, alpha: self.isExpanded ? 1.0 : 0.0)
            isExpandedTransition.setAlpha(view: self.scrollBottomFullMaskView, alpha: self.isExpanded ? 0.0 : 1.0)
            
            return availableSize
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
