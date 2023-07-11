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
    
    let externalState: ExternalState
    let context: AccountContext
    let text: String
    let entities: [MessageTextEntity]
    let entityFiles: [EngineMedia.Id: TelegramMediaFile]
    let action: (Action) -> Void
    let longTapAction: (Action) -> Void
    
    init(
        externalState: ExternalState,
        context: AccountContext,
        text: String,
        entities: [MessageTextEntity],
        entityFiles: [EngineMedia.Id: TelegramMediaFile],
        action: @escaping (Action) -> Void,
        longTapAction: @escaping (Action) -> Void
    ) {
        self.externalState = externalState
        self.context = context
        self.text = text
        self.entities = entities
        self.entityFiles = entityFiles
        self.action = action
        self.longTapAction = longTapAction
    }

    static func ==(lhs: StoryContentCaptionComponent, rhs: StoryContentCaptionComponent) -> Bool {
        if lhs.externalState !== rhs.externalState {
            return false
        }
        if lhs.context !== rhs.context {
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
    
    private final class ContentItem {
        var textNode: TextNodeWithEntities?
        var spoilerTextNode: TextNodeWithEntities?
        var linkHighlightingNode: LinkHighlightingNode?
        var dustNode: InvisibleInkDustNode?
        
        init() {
        }
        
        func update() {
            
        }
    }

    final class View: UIView, UIScrollViewDelegate {
        private let scrollViewContainer: UIView
        private let scrollView: UIScrollView
        
        private let collapsedText: ContentItem
        private let expandedText: ContentItem
        
        private let scrollMaskContainer: UIView
        private let scrollFullMaskView: UIView
        private let scrollCenterMaskView: UIView
        private let scrollBottomMaskView: UIImageView
        private let scrollTopMaskView: UIImageView
        
        private let shadowGradientLayer: SimpleGradientLayer
        private let shadowPlainLayer: SimpleLayer

        private var component: StoryContentCaptionComponent?
        private weak var state: EmptyComponentState?
        
        private var itemLayout: ItemLayout?
        
        private var ignoreScrolling: Bool = false
        private var ignoreExternalState: Bool = false
        
        private var isExpanded: Bool = false
        
        override init(frame: CGRect) {
            self.shadowGradientLayer = SimpleGradientLayer()
            self.shadowPlainLayer = SimpleLayer()
            
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
            
            self.scrollTopMaskView = UIImageView(image: generateGradientImage(size: CGSize(width: 8.0, height: 8.0), colors: [
                UIColor(white: 1.0, alpha: 0.0),
                UIColor(white: 1.0, alpha: 1.0)
            ], locations: [0.0, 1.0]))
            self.scrollMaskContainer.addSubview(self.scrollTopMaskView)
            
            self.collapsedText = ContentItem()
            self.expandedText = ContentItem()

            super.init(frame: frame)
            
            self.layer.addSublayer(self.shadowGradientLayer)
            self.layer.addSublayer(self.shadowPlainLayer)

            self.scrollViewContainer.addSubview(self.scrollView)
            self.scrollView.delegate = self
            self.addSubview(self.scrollViewContainer)
            
            self.scrollViewContainer.mask = self.scrollMaskContainer
            
            let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:)))
            self.addGestureRecognizer(tapRecognizer)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            if !self.bounds.contains(point) {
                return nil
            }
            
            if let textView = self.collapsedText.textNode?.textNode.view {
                let textLocalPoint = self.convert(point, to: textView)
                if textLocalPoint.y >= -7.0 {
                    return textView
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
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            if !self.ignoreScrolling {
                self.updateScrolling(transition: .immediate)
            }
        }
        
        func expand(transition: Transition) {
            self.ignoreScrolling = true
            transition.setBounds(view: self.scrollView, bounds: CGRect(origin: CGPoint(x: 0.0, y: max(0.0, self.scrollView.contentSize.height - self.scrollView.bounds.height)), size: self.scrollView.bounds.size))
            self.ignoreScrolling = false
            
            self.updateScrolling(transition: transition)
        }
        
        func collapse(transition: Transition) {
            self.ignoreScrolling = true
            transition.setBounds(view: self.scrollView, bounds: CGRect(origin: CGPoint(), size: self.scrollView.bounds.size))
            self.ignoreScrolling = false
            
            self.updateScrolling(transition: transition)
        }
        
        private func updateScrolling(transition: Transition) {
            guard let component = self.component, let itemLayout = self.itemLayout else {
                return
            }
            
            var edgeDistance = self.scrollView.contentSize.height - self.scrollView.bounds.maxY
            edgeDistance = max(0.0, min(7.0, edgeDistance))
            
            let edgeDistanceFraction = edgeDistance / 7.0
            transition.setAlpha(view: self.scrollFullMaskView, alpha: 1.0 - edgeDistanceFraction)
            
            let shadowOverflow: CGFloat = 58.0
            let shadowFrame = CGRect(origin: CGPoint(x: 0.0, y:  -self.scrollView.contentOffset.y + itemLayout.containerSize.height - itemLayout.visibleTextHeight - itemLayout.verticalInset - shadowOverflow), size: CGSize(width: itemLayout.containerSize.width, height: itemLayout.visibleTextHeight + itemLayout.verticalInset + shadowOverflow))
            transition.setFrame(layer: self.shadowGradientLayer, frame: shadowFrame)
            transition.setFrame(layer: self.shadowPlainLayer, frame: CGRect(origin: CGPoint(x: shadowFrame.minX, y: shadowFrame.maxY), size: CGSize(width: shadowFrame.width, height: self.scrollView.contentSize.height + 1000.0)))
            
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
            let contentItem = self.isExpanded ? self.expandedText : self.collapsedText
            
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
                                    if self.isExpanded {
                                        self.collapse(transition: Transition(animation: .curve(duration: 0.4, curve: .spring)))
                                    } else {
                                        self.expand(transition: Transition(animation: .curve(duration: 0.4, curve: .spring)))
                                    }
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
                    self.scrollView.insertSubview(linkHighlightingNode.view, belowSubview: textNode.textNode.view)
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
            truncationToken.append(NSAttributedString(string: "Show more", font: Font.semibold(16.0), textColor: .white))
            
            //TODO:localize
            let collapsedTextLayout = TextNodeWithEntities.asyncLayout(self.collapsedText.textNode)(TextNodeLayoutArguments(
                attributedString: attributedText,
                maximumNumberOfLines: 3,
                truncationType: .end,
                constrainedSize: textContainerSize,
                textShadowColor: UIColor(white: 0.0, alpha: 0.25),
                textShadowBlur: 4.0,
                customTruncationToken: truncationToken
            ))
            let expandedTextLayout = TextNodeWithEntities.asyncLayout(self.expandedText.textNode)(TextNodeLayoutArguments(
                attributedString: attributedText,
                maximumNumberOfLines: 0,
                truncationType: .end,
                constrainedSize: textContainerSize,
                textShadowColor: UIColor(white: 0.0, alpha: 0.25),
                textShadowBlur: 4.0
            ))
            
            let collapsedSpoilerTextLayoutAndApply: (TextNodeLayout, (TextNodeWithEntities.Arguments?) -> TextNodeWithEntities)?
            if !collapsedTextLayout.0.spoilers.isEmpty {
                collapsedSpoilerTextLayoutAndApply = TextNodeWithEntities.asyncLayout(self.collapsedText.spoilerTextNode)(TextNodeLayoutArguments(attributedString: attributedText, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: textContainerSize, textShadowColor: UIColor(white: 0.0, alpha: 0.25), textShadowBlur: 4.0, displaySpoilers: true, displayEmbeddedItemsUnderSpoilers: true))
            } else {
                collapsedSpoilerTextLayoutAndApply = nil
            }
            
            let expandedSpoilerTextLayoutAndApply: (TextNodeLayout, (TextNodeWithEntities.Arguments?) -> TextNodeWithEntities)?
            if !expandedTextLayout.0.spoilers.isEmpty {
                expandedSpoilerTextLayoutAndApply = TextNodeWithEntities.asyncLayout(self.expandedText.spoilerTextNode)(TextNodeLayoutArguments(attributedString: attributedText, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: textContainerSize, textShadowColor: UIColor(white: 0.0, alpha: 0.25), textShadowBlur: 4.0, displaySpoilers: true, displayEmbeddedItemsUnderSpoilers: true))
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
                    
                    self.collapsedText.textNode = collapsedTextNode
                    if collapsedTextNode.textNode.view.superview == nil  {
                        self.scrollView.addSubview(collapsedTextNode.textNode.view)
                        
                        let recognizer = TapLongTapOrDoubleTapGestureRecognizer(target: self, action: #selector(self.tapLongTapOrDoubleTapGesture(_:)))
                        recognizer.tapActionAtPoint = { point in
                            return .waitForSingleTap
                        }
                        recognizer.highlight = { [weak self] point in
                            guard let self else {
                                return
                            }
                            self.updateTouchesAtPoint(point)
                        }
                        collapsedTextNode.textNode.view.addGestureRecognizer(recognizer)
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
                        self.scrollView.insertSubview(collapsedSpoilerTextNode.textNode.view, belowSubview: collapsedTextNode.textNode.view)
                        
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
                        self.scrollView.insertSubview(collapsedDustNode.view, aboveSubview: collapsedSpoilerTextNode.textNode.view)
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
                        self.scrollView.addSubview(expandedTextNode.textNode.view)
                        
                        let recognizer = TapLongTapOrDoubleTapGestureRecognizer(target: self, action: #selector(self.tapLongTapOrDoubleTapGesture(_:)))
                        recognizer.tapActionAtPoint = { point in
                            return .waitForSingleTap
                        }
                        recognizer.highlight = { [weak self] point in
                            guard let self else {
                                return
                            }
                            self.updateTouchesAtPoint(point)
                        }
                        expandedTextNode.textNode.view.addGestureRecognizer(recognizer)
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
                        self.scrollView.insertSubview(expandedSpoilerTextNode.textNode.view, belowSubview: expandedTextNode.textNode.view)
                        
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
                        self.scrollView.insertSubview(expandedDustNode.view, aboveSubview: expandedSpoilerTextNode.textNode.view)
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
            
            if self.shadowGradientLayer.colors == nil {
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
            }
            
            self.ignoreScrolling = false
            self.updateScrolling(transition: transition)
            
            let gradientEdgeHeight: CGFloat = 18.0
            
            transition.setFrame(view: self.scrollFullMaskView, frame: CGRect(origin: CGPoint(x: 0.0, y: gradientEdgeHeight), size: CGSize(width: availableSize.width, height: availableSize.height - gradientEdgeHeight)))
            transition.setFrame(view: self.scrollCenterMaskView, frame: CGRect(origin: CGPoint(x: 0.0, y: gradientEdgeHeight), size: CGSize(width: availableSize.width, height: availableSize.height - gradientEdgeHeight * 2.0)))
            transition.setFrame(view: self.scrollBottomMaskView, frame: CGRect(origin: CGPoint(x: 0.0, y: availableSize.height - gradientEdgeHeight), size: CGSize(width: availableSize.width, height: gradientEdgeHeight)))
            transition.setFrame(view: self.scrollTopMaskView, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: availableSize.width, height: gradientEdgeHeight)))
            
            self.ignoreExternalState = false
            
            var isExpandedTransition = transition
            if transition.animation.isImmediate, let hint = transition.userData(TransitionHint.self), case .isExpandedUpdated = hint.kind {
                isExpandedTransition = transition.withAnimation(.curve(duration: 0.25, curve: .easeInOut))
            }
            
            if let textNode = self.collapsedText.textNode {
                isExpandedTransition.setAlpha(view: textNode.textNode.view, alpha: self.isExpanded ? 0.0 : 1.0)
            }
            if let spoilerTextNode = self.collapsedText.spoilerTextNode {
                isExpandedTransition.setAlpha(view: spoilerTextNode.textNode.view, alpha: self.isExpanded ? 0.0 : 1.0)
            }
            if let dustNode = self.collapsedText.dustNode {
                isExpandedTransition.setAlpha(view: dustNode.view, alpha: self.isExpanded ? 0.0 : 1.0)
            }
            
            if let textNode = self.expandedText.textNode {
                isExpandedTransition.setAlpha(view: textNode.textNode.view, alpha: !self.isExpanded ? 0.0 : 1.0)
            }
            if let spoilerTextNode = self.expandedText.spoilerTextNode {
                isExpandedTransition.setAlpha(view: spoilerTextNode.textNode.view, alpha: !self.isExpanded ? 0.0 : 1.0)
            }
            if let dustNode = self.expandedText.dustNode {
                isExpandedTransition.setAlpha(view: dustNode.view, alpha: !self.isExpanded ? 0.0 : 1.0)
            }
            
            isExpandedTransition.setAlpha(layer: self.shadowPlainLayer, alpha: self.isExpanded ? 0.0 : 1.0)
            isExpandedTransition.setAlpha(layer: self.shadowGradientLayer, alpha: self.isExpanded ? 0.0 : 1.0)
            
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
