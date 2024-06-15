import Foundation
import UIKit
import Display
import ComponentFlow
import MultilineTextComponent
import AccountContext
import Postbox
import TelegramCore
import TextNodeWithEntities
import TextFormat
import UrlEscaping
import TelegramPresentationData
import TextSelectionNode
import SwiftSignalKit
import ForwardInfoPanelComponent
import PlainButtonComponent
import InteractiveTextComponent

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
    let author: EnginePeer
    let forwardInfo: EngineStoryItem.ForwardInfo?
    let forwardInfoStory: Signal<EngineStoryItem?, NoError>?
    let entities: [MessageTextEntity]
    let entityFiles: [EngineMedia.Id: TelegramMediaFile]
    let action: (Action) -> Void
    let longTapAction: (Action) -> Void
    let textSelectionAction: (NSAttributedString, TextSelectionAction) -> Void
    let controller: () -> ViewController?
    let openStory: (EnginePeer, EngineStoryItem?) -> Void
    
    init(
        externalState: ExternalState,
        context: AccountContext,
        strings: PresentationStrings,
        theme: PresentationTheme,
        text: String,
        author: EnginePeer,
        forwardInfo: EngineStoryItem.ForwardInfo?,
        forwardInfoStory: Signal<EngineStoryItem?, NoError>?,
        entities: [MessageTextEntity],
        entityFiles: [EngineMedia.Id: TelegramMediaFile],
        action: @escaping (Action) -> Void,
        longTapAction: @escaping (Action) -> Void,
        textSelectionAction: @escaping (NSAttributedString, TextSelectionAction) -> Void,
        controller: @escaping () -> ViewController?,
        openStory: @escaping (EnginePeer, EngineStoryItem?) -> Void
    ) {
        self.externalState = externalState
        self.context = context
        self.strings = strings
        self.theme = theme
        self.author = author
        self.forwardInfo = forwardInfo
        self.forwardInfoStory = forwardInfoStory
        self.text = text
        self.entities = entities
        self.entityFiles = entityFiles
        self.action = action
        self.longTapAction = longTapAction
        self.textSelectionAction = textSelectionAction
        self.controller = controller
        self.openStory = openStory
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
        if lhs.author != rhs.author {
            return false
        }
        if lhs.forwardInfo != rhs.forwardInfo {
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
        var textNode: InteractiveTextNodeWithEntities?
        var linkHighlightingNode: LinkHighlightingNode?
        
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
        
        private var forwardInfoPanel: ComponentView<Empty>?
        private var forwardInfoDisposable: Disposable?
        private var forwardInfoStory: EngineStoryItem?
        
        private let shadowGradientView: UIImageView

        private var component: StoryContentCaptionComponent?
        private weak var state: EmptyComponentState?
        private var isUpdating: Bool = false
        
        private var itemLayout: ItemLayout?
        
        private var ignoreScrolling: Bool = false
        private var ignoreExternalState: Bool = false
        
        private var displayContentsUnderSpoilers: (value: Bool, location: CGPoint?) = (false, nil)
        private var expandedContentsBlocks: Set<Int> = Set()
        private var isExpanded: Bool = false
        
        private var codeHighlight: CachedMessageSyntaxHighlight?
        private var codeHighlightState: (specs: [CachedMessageSyntaxHighlight.Spec], disposable: Disposable)?
                
        private static let shadowImage: UIImage? = {
            UIImage(named: "Stories/PanelGradient")
        }()
        
        override init(frame: CGRect) {
            self.shadowGradientView = UIImageView()
            if let _ = StoryContentCaptionComponent.View.shadowImage {
                let height: CGFloat = 128.0
                let baseGradientAlpha: CGFloat = 0.8
                let numSteps = 8
                let firstStep = 0
                let firstLocation = 0.0
                let colors = (0 ..< numSteps).map { i -> UIColor in
                    if i < firstStep {
                        return UIColor(white: 1.0, alpha: 1.0)
                    } else {
                        let step: CGFloat = CGFloat(i - firstStep) / CGFloat(numSteps - firstStep - 1)
                        let value: CGFloat = 1.0 - bezierPoint(0.42, 0.0, 0.58, 1.0, step)
                        return UIColor(white: 0.0, alpha: baseGradientAlpha * value)
                    }
                }
                let locations = (0 ..< numSteps).map { i -> CGFloat in
                    if i < firstStep {
                        return 0.0
                    } else {
                        let step: CGFloat = CGFloat(i - firstStep) / CGFloat(numSteps - firstStep - 1)
                        return (firstLocation + (1.0 - firstLocation) * step)
                    }
                }
                
                self.shadowGradientView.image = generateGradientImage(size: CGSize(width: 8.0, height: height), colors: colors.reversed(), locations: locations.reversed().map { 1.0 - $0 })!.stretchableImage(withLeftCapWidth: 0, topCapHeight: Int(height - 1.0))
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
        
        deinit {
            self.codeHighlightState?.disposable.dispose()
            self.forwardInfoDisposable?.dispose()
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
            
            if let forwardView = self.forwardInfoPanel?.view {
                let forwardLocalPoint = self.convert(point, to: forwardView)
                if let result = forwardView.hitTest(forwardLocalPoint, with: nil) {
                    return result
                }
            }
            
            return nil
        }
        
        @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
            if case .ended = recognizer.state {
                if self.isExpanded {
                    self.collapse(transition: ComponentTransition(animation: .curve(duration: 0.4, curve: .spring)))
                } else {
                    self.expand(transition: ComponentTransition(animation: .curve(duration: 0.4, curve: .spring)))
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
        
        func expand(transition: ComponentTransition) {
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
        
        func collapse(transition: ComponentTransition) {
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
        
        private func updateScrolling(transition: ComponentTransition) {
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
            
            let shadowHeight: CGFloat = self.shadowGradientView.image?.size.height ?? 100.0
            let shadowOverflow: CGFloat = floor(shadowHeight * 0.6)
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
            
            switch recognizer.state {
            case .ended:
                if let (gesture, location) = recognizer.lastRecognizedGestureAndLocation, let component = self.component, let textNode = contentItem.textNode {
                    let titleFrame = textNode.textNode.view.bounds
                    if titleFrame.contains(location) {
                        let textLocalPoint = CGPoint(x: location.x - titleFrame.minX, y: location.y - titleFrame.minY)
                        if let (index, attributes) = textNode.textNode.attributesAtPoint(textLocalPoint) {
                            let action: Action?
                            if case .tap = gesture, let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.Spoiler)], !self.displayContentsUnderSpoilers.value {
                                self.updateDisplayContentsUnderSpoilers(value: true, at: recognizer.view?.convert(location, to: textNode.textNode.view) ?? location)
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
                                        if let blockIndex = textNode.textNode.collapsibleBlockAtPoint(textLocalPoint) {
                                            if self.expandedContentsBlocks.contains(blockIndex) {
                                                self.expandedContentsBlocks.remove(blockIndex)
                                            } else {
                                                self.expandedContentsBlocks.insert(blockIndex)
                                            }
                                            self.state?.updated(transition: .spring(duration: 0.4))
                                            self.expand(transition: ComponentTransition(animation: .curve(duration: 0.4, curve: .spring)))
                                        } else {
                                            self.collapse(transition: ComponentTransition(animation: .curve(duration: 0.4, curve: .spring)))
                                        }
                                    } else {
                                        self.expand(transition: ComponentTransition(animation: .curve(duration: 0.4, curve: .spring)))
                                    }
                                }
                            }
                        } else {
                            if case .tap = gesture {
                                if component.externalState.isSelectingText {
                                    self.cancelTextSelection()
                                } else if self.isExpanded {
                                    self.collapse(transition: ComponentTransition(animation: .curve(duration: 0.4, curve: .spring)))
                                } else {
                                    self.expand(transition: ComponentTransition(animation: .curve(duration: 0.4, curve: .spring)))
                                }
                            }
                        }
                    } else {
                        if case .tap = gesture {
                            if component.externalState.isSelectingText {
                                self.cancelTextSelection()
                            } else if self.isExpanded {
                                self.collapse(transition: ComponentTransition(animation: .curve(duration: 0.4, curve: .spring)))
                            } else {
                                self.expand(transition: ComponentTransition(animation: .curve(duration: 0.4, curve: .spring)))
                            }
                        }
                    }
                }
            default:
                break
            }
        }
        
        private func updateDisplayContentsUnderSpoilers(value: Bool, at location: CGPoint?) {
            if self.displayContentsUnderSpoilers.value == value {
                return
            }
            self.displayContentsUnderSpoilers = (value, location)
            self.state?.updated(transition: .easeInOut(duration: 0.2))
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
            
            if let spoilerRects = spoilerRects, !spoilerRects.isEmpty, !self.displayContentsUnderSpoilers.value {
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
        
        func update(component: StoryContentCaptionComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            self.ignoreExternalState = true
            
            self.component = component
            self.state = state
            
            let sideInset: CGFloat = 16.0
            let verticalInset: CGFloat = 7.0
            let textContainerSize = CGSize(width: availableSize.width - sideInset * 2.0, height: availableSize.height - verticalInset * 2.0)
            
            var baseQuoteSecondaryTintColor: UIColor?
            var baseQuoteTertiaryTintColor: UIColor?
            if let nameColor = component.author.nameColor {
                let resolvedColor = component.context.peerNameColors.get(nameColor)
                if resolvedColor.secondary != nil {
                    baseQuoteSecondaryTintColor = .clear
                }
                if resolvedColor.tertiary != nil {
                    baseQuoteTertiaryTintColor = .clear
                }
            }
            
            let codeSpec = extractMessageSyntaxHighlightSpecs(text: component.text, entities: component.entities)
            if self.codeHighlightState?.specs != codeSpec {
                let disposable = MetaDisposable()
                self.codeHighlightState = (codeSpec, disposable)
                disposable.set((asyncStanaloneSyntaxHighlight(current: self.codeHighlight, specs: codeSpec)
                |> deliverOnMainQueue).start(next: { [weak self] result in
                    guard let self else {
                        return
                    }
                    if self.codeHighlight != result {
                        self.codeHighlight = result
                        if !self.isUpdating {
                            self.state?.updated(transition: .immediate)
                        }
                    }
                }))
            }
            
            let attributedText = stringWithAppliedEntities(
                component.text,
                entities: component.entities,
                baseColor: .white,
                linkColor: .white,
                baseQuoteTintColor: .white,
                baseQuoteSecondaryTintColor: baseQuoteSecondaryTintColor,
                baseQuoteTertiaryTintColor: baseQuoteTertiaryTintColor,
                codeBlockTitleColor: .white,
                codeBlockAccentColor: .white,
                codeBlockBackgroundColor: UIColor(white: 1.0, alpha: 0.2),
                baseFont: Font.regular(16.0),
                linkFont: Font.regular(16.0),
                boldFont: Font.semibold(16.0),
                italicFont: Font.italic(16.0),
                boldItalicFont: Font.semiboldItalic(16.0),
                fixedFont: Font.monospace(16.0),
                blockQuoteFont: Font.monospace(16.0),
                message: nil,
                entityFiles: component.entityFiles,
                adjustQuoteFontSize: true,
                cachedMessageSyntaxHighlight: self.codeHighlight
            )
            
            let truncationTokenString = component.strings.Story_CaptionShowMore
            let customTruncationToken: (UIFont, Bool) -> NSAttributedString? = { baseFont, _ in
                let truncationToken = NSMutableAttributedString()
                truncationToken.append(NSAttributedString(string: "\u{2026} ", font: Font.regular(baseFont.pointSize), textColor: .white))
                truncationToken.append(NSAttributedString(string: truncationTokenString, font: Font.semibold(baseFont.pointSize), textColor: .white))
                return truncationToken
            }
            
            let textInsets = UIEdgeInsets(top: 2.0, left: 2.0, bottom: 5.0, right: 2.0)
            let collapsedTextLayout = InteractiveTextNodeWithEntities.asyncLayout(self.collapsedText.textNode)(InteractiveTextNodeLayoutArguments(
                attributedString: attributedText,
                maximumNumberOfLines: 3,
                truncationType: .end,
                constrainedSize: CGSize(width: textContainerSize.width, height: 10000.0),
                insets: textInsets,
                textShadowColor: UIColor(white: 0.0, alpha: 0.25),
                textShadowBlur: 4.0,
                displayContentsUnderSpoilers: self.displayContentsUnderSpoilers.value,
                customTruncationToken: customTruncationToken,
                expandedBlocks: self.expandedContentsBlocks
            ))
            let expandedTextLayout = InteractiveTextNodeWithEntities.asyncLayout(self.expandedText.textNode)(InteractiveTextNodeLayoutArguments(
                attributedString: attributedText,
                maximumNumberOfLines: 0,
                truncationType: .end,
                constrainedSize: CGSize(width: textContainerSize.width, height: 10000.0),
                insets: textInsets,
                textShadowColor: UIColor(white: 0.0, alpha: 0.25),
                textShadowBlur: 4.0,
                displayContentsUnderSpoilers: self.displayContentsUnderSpoilers.value,
                expandedBlocks: self.expandedContentsBlocks
            ))
            
            let visibleTextHeight = collapsedTextLayout.0.size.height - textInsets.top - textInsets.bottom
            let textOverflowHeight: CGFloat = expandedTextLayout.0.size.height - textInsets.top - textInsets.bottom - visibleTextHeight
            let scrollContentSize = CGSize(width: availableSize.width, height: availableSize.height + textOverflowHeight)
            
            if let forwardInfo = component.forwardInfo {
                let authorName: String
                let isChannel: Bool
                let text: String?
                let entities: [MessageTextEntity]
                
                switch forwardInfo {
                case let .known(peer, _, _):
                    authorName = peer.displayTitle(strings: component.strings, displayOrder: .firstLast)
                    isChannel = peer.id.isGroupOrChannel
                    
                    if let story = self.forwardInfoStory {
                        text = story.text
                        entities = story.entities
                    } else if self.forwardInfoDisposable == nil, let forwardInfoStory = component.forwardInfoStory {
                        self.forwardInfoDisposable = (forwardInfoStory
                        |> deliverOnMainQueue).start(next: { story in
                            if let story {
                                self.forwardInfoStory = story
                                if !self.isUpdating {
                                    self.state?.updated(transition: .easeInOut(duration: 0.2))
                                }
                            }
                        })
                        text = ""
                        entities = []
                    } else {
                        text = ""
                        entities = []
                    }
                case let .unknown(name, _):
                    authorName = name
                    isChannel = false
                    text = ""
                    entities = []
                }
                
                if let text {
                    let forwardInfoPanel: ComponentView<Empty>
                    if let current = self.forwardInfoPanel {
                        forwardInfoPanel = current
                    } else {
                        forwardInfoPanel = ComponentView<Empty>()
                        self.forwardInfoPanel = forwardInfoPanel
                    }
                    
                    let forwardInfoPanelSize = forwardInfoPanel.update(
                        transition: .immediate,
                        component: AnyComponent(
                            PlainButtonComponent(
                                content: AnyComponent(
                                    ForwardInfoPanelComponent(
                                        context: component.context,
                                        authorName: authorName,
                                        text: text,
                                        entities: entities,
                                        isChannel: isChannel,
                                        isVibrant: false,
                                        fillsWidth: false
                                    )
                                ),
                                effectAlignment: .center,
                                minSize: nil,
                                action: { [weak self] in
                                    if let self, case let .known(peer, _, _) = forwardInfo {
                                        self.component?.openStory(peer, self.forwardInfoStory)
                                    } else if let controller = self?.component?.controller() as? StoryContainerScreen {
                                        let tooltipController = TooltipController(content: .text(component.strings.Story_ForwardAuthorHiddenTooltip), baseFontSize: 17.0, isBlurred: true, dismissByTapOutside: true, dismissImmediatelyOnLayoutUpdate: true)
                                        controller.present(tooltipController, in: .window(.root), with: TooltipControllerPresentationArguments(sourceNodeAndRect: { [weak self, weak controller] in
                                            if let self, let controller, let forwardInfoPanel = self.forwardInfoPanel?.view {
                                                return (controller.node, forwardInfoPanel.convert(forwardInfoPanel.bounds, to: controller.view))
                                            }
                                            return nil
                                        }))
                                    }
                                }
                            )
                        ),
                        environment: {},
                        containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: availableSize.height)
                    )
                    let forwardInfoPanelFrame = CGRect(origin: CGPoint(x: sideInset, y: availableSize.height - visibleTextHeight - verticalInset - forwardInfoPanelSize.height - 10.0), size: forwardInfoPanelSize)
                    if let view = forwardInfoPanel.view {
                        if view.superview == nil {
                            self.scrollView.addSubview(view)
                            transition.animateAlpha(view: view, from: 0.0, to: 1.0)
                        }
                        view.frame = forwardInfoPanelFrame
                    }
                }
            } else if let forwardInfoPanel = self.forwardInfoPanel {
                self.forwardInfoPanel = nil
                forwardInfoPanel.view?.removeFromSuperview()
            }
            
            
            let collapsedTextFrame = CGRect(origin: CGPoint(x: sideInset - textInsets.left, y: availableSize.height - visibleTextHeight - verticalInset - textInsets.top), size: collapsedTextLayout.0.size)
            let expandedTextFrame = CGRect(origin: CGPoint(x: sideInset - textInsets.left, y: availableSize.height - visibleTextHeight - verticalInset - textInsets.top), size: expandedTextLayout.0.size)
            
            var spoilerExpandRect: CGRect?
            if let location = self.displayContentsUnderSpoilers.location {
                self.displayContentsUnderSpoilers.location = nil
                
                let mappedLocation = CGPoint(x: location.x, y: location.y)
                
                let getDistance: (CGPoint, CGPoint) -> CGFloat = { a, b in
                    let v = CGPoint(x: a.x - b.x, y: a.y - b.y)
                    return sqrt(v.x * v.x + v.y * v.y)
                }
                
                var maxDistance: CGFloat = getDistance(mappedLocation, CGPoint(x: 0.0, y: 0.0))
                maxDistance = max(maxDistance, getDistance(mappedLocation, CGPoint(x: expandedTextFrame.width, y: 0.0)))
                maxDistance = max(maxDistance, getDistance(mappedLocation, CGPoint(x: expandedTextFrame.width, y: expandedTextFrame.height)))
                maxDistance = max(maxDistance, getDistance(mappedLocation, CGPoint(x: 0.0, y: expandedTextFrame.height)))
                
                let mappedSize = CGSize(width: maxDistance * 2.0, height: maxDistance * 2.0)
                spoilerExpandRect = mappedSize.centered(around: mappedLocation)
            }
            
            let textAnimation: ListViewItemUpdateAnimation
            if case let .curve(duration, curve) = transition.animation {
                textAnimation = .System(duration: duration, transition: ControlledTransition(duration: duration, curve: curve.containedViewLayoutTransitionCurve, interactive: false))
            } else {
                textAnimation = .None
            }
            let textApplyArguments = InteractiveTextNodeWithEntities.Arguments(
                context: component.context,
                cache: component.context.animationCache,
                renderer: component.context.animationRenderer,
                placeholderColor: UIColor(white: 0.2, alpha: 1.0),
                attemptSynchronous: true,
                textColor: .white,
                spoilerEffectColor: .white,
                applyArguments: InteractiveTextNode.ApplyArguments(
                    animation: textAnimation,
                    spoilerTextColor: .white,
                    spoilerEffectColor: .white,
                    areContentAnimationsEnabled: true,
                    spoilerExpandRect: spoilerExpandRect
                )
            )
            
            do {
                let collapsedTextNode = collapsedTextLayout.1(textApplyArguments)
                if self.collapsedText.textNode !== collapsedTextNode {
                    self.collapsedText.textNode?.textNode.view.removeFromSuperview()
                    
                    collapsedTextNode.textNode.displaysAsynchronously = false
                    
                    self.collapsedText.textNode = collapsedTextNode
                    if collapsedTextNode.textNode.view.superview == nil  {
                        self.collapsedText.addSubview(collapsedTextNode.textNode.view)
                    }
                    
                    collapsedTextNode.visibilityRect = CGRect(origin: CGPoint(), size: CGSize(width: 100000.0, height: 100000.0))
                }
                
                collapsedTextNode.textNode.frame = collapsedTextFrame
            }
            
            do {
                let expandedTextNode = expandedTextLayout.1(textApplyArguments)
                if self.expandedText.textNode !== expandedTextNode {
                    self.expandedText.textNode?.textNode.view.removeFromSuperview()
                    
                    self.expandedText.textNode = expandedTextNode
                    if expandedTextNode.textNode.view.superview == nil  {
                        self.expandedText.addSubview(expandedTextNode.textNode.view)
                    }
                    
                    expandedTextNode.visibilityRect = CGRect(origin: CGPoint(), size: CGSize(width: 100000.0, height: 100000.0))
                }
                
                expandedTextNode.textNode.frame = expandedTextFrame
            }
            
            if self.textSelectionNode == nil, let controller = component.controller(), let textNode = self.expandedText.textNode?.textNode {
                let selectionColor = UIColor(white: 1.0, alpha: 0.5)
                
                if self.textSelectionKnobSurface == nil {
                    let textSelectionKnobSurface = UIView()
                    self.textSelectionKnobSurface = textSelectionKnobSurface
                    self.textSelectionKnobContainer.addSubview(textSelectionKnobSurface)
                }
                
                let textSelectionNode = TextSelectionNode(theme: TextSelectionTheme(selection: selectionColor, knob: component.theme.list.itemAccentColor, isDark: true), strings: component.strings, textNode: textNode, updateIsActive: { [weak self] value in
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
                }, rootNode: { [weak controller] in
                    return controller?.displayNode
                }, externalKnobSurface: self.textSelectionKnobSurface, performAction: { [weak self] text, action in
                    guard let self, let component = self.component else {
                        return
                    }
                    component.textSelectionAction(text, action)
                })
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
                        if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.Spoiler)], !self.displayContentsUnderSpoilers.value {
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
                
                let _ = textSelectionNode.view
                
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
            let previousBounds = self.scrollView.bounds
            
            if self.scrollView.contentSize != scrollContentSize {
                self.scrollView.contentSize = scrollContentSize
            }
            transition.setFrame(view: self.scrollView, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: availableSize.width, height: availableSize.height)))
            transition.setFrame(view: self.scrollViewContainer, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: availableSize.width, height: availableSize.height)))
            
            if !previousBounds.isEmpty, !transition.animation.isImmediate {
                let bounds = self.scrollView.bounds
                if bounds.maxY != previousBounds.maxY {
                    let offsetY = previousBounds.maxY - bounds.maxY
                    transition.animateBoundsOrigin(view: self.scrollView, from: CGPoint(x: 0.0, y: offsetY), to: CGPoint(), additive: true)
                }
            }
            
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
            
            isExpandedTransition.setAlpha(view: self.shadowGradientView, alpha: self.isExpanded ? 0.0 : 1.0)
            
            isExpandedTransition.setAlpha(view: self.scrollBottomMaskView, alpha: self.isExpanded ? 1.0 : 0.0)
            isExpandedTransition.setAlpha(view: self.scrollBottomFullMaskView, alpha: self.isExpanded ? 0.0 : 1.0)
            
            return availableSize
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
