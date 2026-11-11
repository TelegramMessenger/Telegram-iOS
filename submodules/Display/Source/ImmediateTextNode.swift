import Foundation
import UIKit

public struct ImmediateTextNodeLayoutInfo {
    public let size: CGSize
    public let truncated: Bool
    public let numberOfLines: Int
    
    public init(size: CGSize, truncated: Bool, numberOfLines: Int) {
        self.size = size
        self.truncated = truncated
        self.numberOfLines = numberOfLines
    }
}

open class ImmediateTextNode: TextNode {
    public var attributedText: NSAttributedString?
    public var textAlignment: NSTextAlignment = .natural
    public var verticalAlignment: TextVerticalAlignment = .top
    public var truncationType: CTLineTruncationType = .end
    public var maximumNumberOfLines: Int = 1
    public var lineSpacing: CGFloat = 0.0
    public var insets: UIEdgeInsets = UIEdgeInsets()
    public var textShadowColor: UIColor?
    public var textShadowBlur: CGFloat?
    public var textStroke: (UIColor, CGFloat)?
    public var cutout: TextNodeCutout?
    public var displaySpoilers = false
    
    public var truncationMode: NSLineBreakMode {
        get {
            switch self.truncationType {
            case .start:
                return .byTruncatingHead
            case .middle:
                return .byTruncatingMiddle
            case .end:
                return .byTruncatingTail
            @unknown default:
                return .byTruncatingTail
            }
        } set(value) {
            switch value {
            case .byTruncatingHead:
                self.truncationType = .start
            case .byTruncatingMiddle:
                self.truncationType = .middle
            case .byTruncatingTail:
                self.truncationType = .end
            default:
                self.truncationType = .end
            }
        }
    }
    
    private var tapRecognizer: TapLongTapOrDoubleTapGestureRecognizer?
    private var linkHighlightingNode: LinkHighlightingNode?
    
    public var linkHighlightColor: UIColor?
    
    public var trailingLineWidth: CGFloat?
    
    public var constrainedSize: CGSize?
    
    public var highlightAttributeAction: (([NSAttributedString.Key: Any]) -> NSAttributedString.Key?)? {
        didSet {
            if self.isNodeLoaded {
                self.updateInteractiveActions()
            }
        }
    }
    
    public var tapAttributeAction: (([NSAttributedString.Key: Any], Int) -> Void)?
    public var longTapAttributeAction: (([NSAttributedString.Key: Any], Int) -> Void)?
    
    public func makeCopy() -> TextNode {
        let node = TextNode()
        node.cachedLayout = self.cachedLayout
        node.frame = self.frame
        if let subnodes = self.subnodes {
            for subnode in subnodes {
                if let subnode = subnode as? ASImageNode {
                    let copySubnode = ASImageNode()
                    copySubnode.isLayerBacked = subnode.isLayerBacked
                    copySubnode.image = subnode.image
                    copySubnode.displaysAsynchronously = false
                    copySubnode.displayWithoutProcessing = true
                    copySubnode.frame = subnode.frame
                    copySubnode.alpha = subnode.alpha
                    node.addSubnode(copySubnode)
                }
            }
        }
        return node
    }
    
    open func updateLayout(_ constrainedSize: CGSize) -> CGSize {
        self.constrainedSize = constrainedSize
        
        let makeLayout = TextNode.asyncLayout(self)
        let (layout, apply) = makeLayout(TextNodeLayoutArguments(attributedString: self.attributedText, backgroundColor: nil, maximumNumberOfLines: self.maximumNumberOfLines, truncationType: self.truncationType, constrainedSize: constrainedSize, alignment: self.textAlignment, verticalAlignment: self.verticalAlignment, lineSpacing: self.lineSpacing, cutout: self.cutout, insets: self.insets, textShadowColor: self.textShadowColor, textShadowBlur: self.textShadowBlur, textStroke: self.textStroke, displaySpoilers: self.displaySpoilers))
        let _ = apply()
        if layout.numberOfLines > 1 {
            self.trailingLineWidth = layout.trailingLineWidth
        } else {
            self.trailingLineWidth = nil
        }
        return layout.size
    }
    
    public func updateLayoutInfo(_ constrainedSize: CGSize) -> ImmediateTextNodeLayoutInfo {
        self.constrainedSize = constrainedSize
        
        let makeLayout = TextNode.asyncLayout(self)
        let (layout, apply) = makeLayout(TextNodeLayoutArguments(attributedString: self.attributedText, backgroundColor: nil, maximumNumberOfLines: self.maximumNumberOfLines, truncationType: self.truncationType, constrainedSize: constrainedSize, alignment: self.textAlignment, verticalAlignment: self.verticalAlignment, lineSpacing: self.lineSpacing, cutout: self.cutout, insets: self.insets, displaySpoilers: self.displaySpoilers))
        let _ = apply()
        return ImmediateTextNodeLayoutInfo(size: layout.size, truncated: layout.truncated, numberOfLines: layout.numberOfLines)
    }
    
    public func updateLayoutFullInfo(_ constrainedSize: CGSize) -> TextNodeLayout {
        self.constrainedSize = constrainedSize
        
        let makeLayout = TextNode.asyncLayout(self)
        let (layout, apply) = makeLayout(TextNodeLayoutArguments(attributedString: self.attributedText, backgroundColor: nil, maximumNumberOfLines: self.maximumNumberOfLines, truncationType: self.truncationType, constrainedSize: constrainedSize, alignment: self.textAlignment, verticalAlignment: self.verticalAlignment, lineSpacing: self.lineSpacing, cutout: self.cutout, insets: self.insets, displaySpoilers: self.displaySpoilers))
        let _ = apply()
        return layout
    }
    
    public func redrawIfPossible() {
        if let constrainedSize = self.constrainedSize {
            let _ = self.updateLayout(constrainedSize)
        }
    }
    
    override open func didLoad() {
        super.didLoad()
        
        self.updateInteractiveActions()
    }
    
    private func updateInteractiveActions() {
        if self.highlightAttributeAction != nil {
            if self.tapRecognizer == nil {
                let tapRecognizer = TapLongTapOrDoubleTapGestureRecognizer(target: self, action: #selector(self.tapAction(_:)))
                tapRecognizer.highlight = { [weak self] point in
                    if let strongSelf = self {
                        var rects: [CGRect]?
                        if let point = point {
                            if let (index, attributes) = strongSelf.attributesAtPoint(CGPoint(x: point.x, y: point.y)) {
                                if let selectedAttribute = strongSelf.highlightAttributeAction?(attributes) {
                                    let initialRects = strongSelf.lineAndAttributeRects(name: selectedAttribute.rawValue, at: index)
                                    if let initialRects = initialRects, case .center = strongSelf.textAlignment {
                                        var mappedRects: [CGRect] = []
                                        for i in 0 ..< initialRects.count {
                                            let lineRect = initialRects[i].0
                                            var itemRect = initialRects[i].1
                                            itemRect.origin.x = floor((strongSelf.bounds.size.width - lineRect.width) / 2.0) + itemRect.origin.x
                                            mappedRects.append(itemRect)
                                        }
                                        rects = mappedRects
                                    } else {
                                        rects = strongSelf.attributeRects(name: selectedAttribute.rawValue, at: index)
                                    }
                                }
                            }
                        }
                        
                        if let rects = rects {
                            let linkHighlightingNode: LinkHighlightingNode
                            if let current = strongSelf.linkHighlightingNode {
                                linkHighlightingNode = current
                            } else {
                                linkHighlightingNode = LinkHighlightingNode(color: strongSelf.linkHighlightColor ?? .clear)
                                strongSelf.linkHighlightingNode = linkHighlightingNode
                                strongSelf.addSubnode(linkHighlightingNode)
                            }
                            linkHighlightingNode.frame = strongSelf.bounds
                            linkHighlightingNode.updateRects(rects.map { $0.offsetBy(dx: 0.0, dy: 0.0) })
                        } else if let linkHighlightingNode = strongSelf.linkHighlightingNode {
                            strongSelf.linkHighlightingNode = nil
                            linkHighlightingNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.18, removeOnCompletion: false, completion: { [weak linkHighlightingNode] _ in
                                linkHighlightingNode?.removeFromSupernode()
                            })
                        }
                    }
                }
                self.view.addGestureRecognizer(tapRecognizer)
            }
        } else if let tapRecognizer = self.tapRecognizer {
            self.tapRecognizer = nil
            self.view.removeGestureRecognizer(tapRecognizer)
        }
    }
    
    @objc private func tapAction(_ recognizer: TapLongTapOrDoubleTapGestureRecognizer) {
        switch recognizer.state {
            case .ended:
                if let (gesture, location) = recognizer.lastRecognizedGestureAndLocation {
                    switch gesture {
                        case .tap:
                            if let (index, attributes) = self.attributesAtPoint(CGPoint(x: location.x, y: location.y)) {
                                self.tapAttributeAction?(attributes, index)
                            }
                        case .longTap:
                            if let (index, attributes) = self.attributesAtPoint(CGPoint(x: location.x, y: location.y)) {
                                self.longTapAttributeAction?(attributes, index)
                            }
                        default:
                            break
                    }
                }
            default:
                break
        }
    }
}

public class ASTextNode: ImmediateTextNode {
    override public var attributedText: NSAttributedString? {
        didSet {
            self.setNeedsLayout()
        }
    }
    
    override public init() {
        super.init()
        
        self.maximumNumberOfLines = 0
    }
    
    override public func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        return self.updateLayout(constrainedSize)
    }
}

open class ImmediateTextView: TextView {
    public var attributedText: NSAttributedString?
    public var textAlignment: NSTextAlignment = .natural
    public var verticalAlignment: TextVerticalAlignment = .top
    public var truncationType: CTLineTruncationType = .end
    public var maximumNumberOfLines: Int = 1
    public var lineSpacing: CGFloat = 0.0
    public var insets: UIEdgeInsets = UIEdgeInsets()
    public var textShadowColor: UIColor?
    public var textShadowBlur: CGFloat?
    public var textStroke: (UIColor, CGFloat)?
    public var cutout: TextNodeCutout?
    public var displaySpoilers = false
    
    public var truncationMode: NSLineBreakMode {
        get {
            switch self.truncationType {
            case .start:
                return .byTruncatingHead
            case .middle:
                return .byTruncatingMiddle
            case .end:
                return .byTruncatingTail
            @unknown default:
                return .byTruncatingTail
            }
        } set(value) {
            switch value {
            case .byTruncatingHead:
                self.truncationType = .start
            case .byTruncatingMiddle:
                self.truncationType = .middle
            case .byTruncatingTail:
                self.truncationType = .end
            default:
                self.truncationType = .end
            }
        }
    }
    
    private var tapRecognizer: TapLongTapOrDoubleTapGestureRecognizer?
    private var linkHighlightingNode: LinkHighlightingNode?
    
    public var linkHighlightColor: UIColor?
    public var linkHighlightInset: UIEdgeInsets = .zero
    
    public var trailingLineWidth: CGFloat?
    
    var constrainedSize: CGSize?
    
    public var highlightAttributeAction: (([NSAttributedString.Key: Any]) -> NSAttributedString.Key?)? {
        didSet {
            self.updateInteractiveActions()
        }
    }
    
    public var tapAttributeAction: (([NSAttributedString.Key: Any], Int) -> Void)?
    public var longTapAttributeAction: (([NSAttributedString.Key: Any], Int) -> Void)?
    
    public func updateLayout(_ constrainedSize: CGSize) -> CGSize {
        self.constrainedSize = constrainedSize
        
        let makeLayout = TextView.asyncLayout(self)
        let (layout, apply) = makeLayout(TextNodeLayoutArguments(attributedString: self.attributedText, backgroundColor: nil, maximumNumberOfLines: self.maximumNumberOfLines, truncationType: self.truncationType, constrainedSize: constrainedSize, alignment: self.textAlignment, verticalAlignment: self.verticalAlignment, lineSpacing: self.lineSpacing, cutout: self.cutout, insets: self.insets, textShadowColor: self.textShadowColor, textShadowBlur: self.textShadowBlur, textStroke: self.textStroke, displaySpoilers: self.displaySpoilers))
        let _ = apply()
        if layout.numberOfLines > 1 {
            self.trailingLineWidth = layout.trailingLineWidth
        } else {
            self.trailingLineWidth = nil
        }
        return layout.size
    }
    
    public func updateLayoutInfo(_ constrainedSize: CGSize) -> ImmediateTextNodeLayoutInfo {
        self.constrainedSize = constrainedSize
        
        let makeLayout = TextView.asyncLayout(self)
        let (layout, apply) = makeLayout(TextNodeLayoutArguments(attributedString: self.attributedText, backgroundColor: nil, maximumNumberOfLines: self.maximumNumberOfLines, truncationType: self.truncationType, constrainedSize: constrainedSize, alignment: self.textAlignment, verticalAlignment: self.verticalAlignment, lineSpacing: self.lineSpacing, cutout: self.cutout, insets: self.insets, displaySpoilers: self.displaySpoilers))
        let _ = apply()
        return ImmediateTextNodeLayoutInfo(size: layout.size, truncated: layout.truncated, numberOfLines: layout.numberOfLines)
    }
    
    public func updateLayoutFullInfo(_ constrainedSize: CGSize) -> TextNodeLayout {
        self.constrainedSize = constrainedSize
        
        let makeLayout = TextView.asyncLayout(self)
        let (layout, apply) = makeLayout(TextNodeLayoutArguments(attributedString: self.attributedText, backgroundColor: nil, maximumNumberOfLines: self.maximumNumberOfLines, truncationType: self.truncationType, constrainedSize: constrainedSize, alignment: self.textAlignment, verticalAlignment: self.verticalAlignment, lineSpacing: self.lineSpacing, cutout: self.cutout, insets: self.insets, displaySpoilers: self.displaySpoilers))
        let _ = apply()
        return layout
    }
    
    public func redrawIfPossible() {
        if let constrainedSize = self.constrainedSize {
            let _ = self.updateLayout(constrainedSize)
        }
    }
    
    /// VoiceOver: the tappable ranges of the text (where `highlightAttributeAction` picks an attribute), with their
    /// words, in text order. Image attachments (an arrow glyph) are not words.
    public func accessibilityLinks() -> [(text: String, attributes: [NSAttributedString.Key: Any], index: Int)] {
        guard let attributedText = self.attributedText, let highlightAttributeAction = self.highlightAttributeAction else {
            return []
        }
        var result: [(text: String, attributes: [NSAttributedString.Key: Any], index: Int)] = []
        attributedText.enumerateAttributes(in: NSRange(location: 0, length: attributedText.length), options: []) { attributes, range, _ in
            guard highlightAttributeAction(attributes) != nil, attributes[.attachment] == nil else {
                return
            }
            let text = (attributedText.string as NSString).substring(with: range).trimmingCharacters(in: .whitespacesAndNewlines)
            if text.isEmpty {
                return
            }
            result.append((text, attributes, range.location))
        }
        return result
    }
    
    /// VoiceOver: the text as read, without image attachments.
    public var accessibilityDisplayedText: String {
        guard let attributedText = self.attributedText else {
            return ""
        }
        let mutable = NSMutableAttributedString(attributedString: attributedText)
        attributedText.enumerateAttribute(.attachment, in: NSRange(location: 0, length: attributedText.length), options: [.reverse]) { value, range, _ in
            if value != nil {
                mutable.deleteCharacters(in: range)
            }
        }
        return mutable.string.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Activating a text element with links follows its first link, as a tap on it does.
    override open func accessibilityActivate() -> Bool {
        if self.isAccessibilityElement, let tapAttributeAction = self.tapAttributeAction, let link = self.accessibilityLinks().first {
            tapAttributeAction(link.attributes, link.index)
            return true
        }
        return super.accessibilityActivate()
    }

    /// A text with several links (terms, policy, "Restore Purchases"): each link is reachable as a custom action named
    /// by its text, opened as a tap on it does. Built only when VoiceOver asks.
    override open var accessibilityCustomActions: [UIAccessibilityCustomAction]? {
        get {
            if let explicit = super.accessibilityCustomActions, !explicit.isEmpty {
                return explicit
            }
            guard self.isAccessibilityElement, self.tapAttributeAction != nil else {
                return nil
            }
            if accessibilityIsInsideViewElementsSubtree(self) {
                // Inside the chat's history subtree (see `accessibilityIsInsideViewElementsSubtree` for the boundary) the old result is kept.
                return nil
            }
            let links = self.accessibilityLinks()
            if links.count < 2 {
                return nil
            }
            return links.map { link in
                return UIAccessibilityCustomAction(name: link.text, actionHandler: { [weak self] _ in
                    guard let self, let tapAttributeAction = self.tapAttributeAction else {
                        return false
                    }
                    tapAttributeAction(link.attributes, link.index)
                    return true
                })
            }
        } set(value) {
            super.accessibilityCustomActions = value
        }
    }
    
    private func updateInteractiveActions() {
        if self.highlightAttributeAction != nil {
            if self.tapRecognizer == nil {
                let tapRecognizer = TapLongTapOrDoubleTapGestureRecognizer(target: self, action: #selector(self.tapAction(_:)))
                tapRecognizer.highlight = { [weak self] point in
                    if let strongSelf = self {
                        var rects: [CGRect]?
                        if let point = point {
                            if let (index, attributes) = strongSelf.attributesAtPoint(CGPoint(x: point.x, y: point.y)) {
                                if let selectedAttribute = strongSelf.highlightAttributeAction?(attributes) {
                                    let initialRects = strongSelf.lineAndAttributeRects(name: selectedAttribute.rawValue, at: index)
                                    if let initialRects = initialRects, case .center = strongSelf.textAlignment {
                                        var mappedRects: [CGRect] = []
                                        for i in 0 ..< initialRects.count {
                                            let lineRect = initialRects[i].0
                                            var itemRect = initialRects[i].1
                                            itemRect.origin.x = floor((strongSelf.bounds.size.width - lineRect.width) / 2.0) + itemRect.origin.x
                                            mappedRects.append(itemRect)
                                        }
                                        rects = mappedRects
                                    } else {
                                        rects = strongSelf.attributeRects(name: selectedAttribute.rawValue, at: index)
                                    }
                                }
                            }
                        }
                        
                        if var rects, !rects.isEmpty {
                            let linkHighlightingNode: LinkHighlightingNode
                            if let current = strongSelf.linkHighlightingNode {
                                linkHighlightingNode = current
                            } else {
                                linkHighlightingNode = LinkHighlightingNode(color: strongSelf.linkHighlightColor ?? .clear)
                                strongSelf.linkHighlightingNode = linkHighlightingNode
                                strongSelf.addSubnode(linkHighlightingNode)
                            }
                            linkHighlightingNode.frame = strongSelf.bounds
                            rects[rects.count - 1] = rects[rects.count - 1].inset(by: strongSelf.linkHighlightInset)
                            linkHighlightingNode.updateRects(rects)
                        } else if let linkHighlightingNode = strongSelf.linkHighlightingNode {
                            strongSelf.linkHighlightingNode = nil
                            linkHighlightingNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.18, removeOnCompletion: false, completion: { [weak linkHighlightingNode] _ in
                                linkHighlightingNode?.removeFromSupernode()
                            })
                        }
                    }
                }
                self.addGestureRecognizer(tapRecognizer)
            }
        } else if let tapRecognizer = self.tapRecognizer {
            self.tapRecognizer = nil
            self.removeGestureRecognizer(tapRecognizer)
        }
    }
    
    @objc private func tapAction(_ recognizer: TapLongTapOrDoubleTapGestureRecognizer) {
        switch recognizer.state {
        case .ended:
            if let (gesture, location) = recognizer.lastRecognizedGestureAndLocation {
                switch gesture {
                case .tap:
                    if let (index, attributes) = self.attributesAtPoint(CGPoint(x: location.x, y: location.y)) {
                        self.tapAttributeAction?(attributes, index)
                    }
                case .longTap:
                    if let (index, attributes) = self.attributesAtPoint(CGPoint(x: location.x, y: location.y)) {
                        self.longTapAttributeAction?(attributes, index)
                    }
                default:
                    break
                }
            }
        default:
            break
        }
    }
}
