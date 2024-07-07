import Foundation
import UIKit
import AsyncDisplayKit
import Display
import AppBundle
import ChatInputTextViewImpl
import MessageInlineBlockBackgroundView
import TextFormat
import AccountContext
import TextNodeWithEntities

public protocol ChatInputTextNodeDelegate: AnyObject {
    func chatInputTextNodeDidUpdateText()
    func chatInputTextNodeShouldReturn() -> Bool
    func chatInputTextNodeDidChangeSelection(dueToEditing: Bool)
    func chatInputTextNodeDidBeginEditing()
    func chatInputTextNodeDidFinishEditing()
    func chatInputTextNodeBackspaceWhileEmpty()
    
    @available(iOS 13.0, *)
    func chatInputTextNodeMenu(forTextRange textRange: NSRange, suggestedActions: [UIMenuElement]) -> UIMenu
    
    func chatInputTextNode(shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool
    func chatInputTextNodeShouldCopy() -> Bool
    func chatInputTextNodeShouldPaste() -> Bool
    
    func chatInputTextNodeShouldRespondToAction(action: Selector) -> Bool
    func chatInputTextNodeTargetForAction(action: Selector) -> ChatInputTextNode.TargetForAction?
}

@available(iOS 15.0, *)
private final class ChatInputTextLayoutManager: NSTextLayoutManager {
    weak var contentStorage: ChatInputTextContentStorage?
    
    init(contentStorage: ChatInputTextContentStorage) {
        self.contentStorage = contentStorage
        
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @discardableResult
    override func enumerateTextLayoutFragments(from location: NSTextLocation?, options: NSTextLayoutFragment.EnumerationOptions = [], using block: (NSTextLayoutFragment) -> Bool) -> NSTextLocation? {
        /*guard let contentStorage = self.contentStorage else {
            return nil
        }
        
        var layoutFragments: [NSTextLayoutFragment] = []
        contentStorage.enumerateTextElements(from: contentStorage.documentRange.location, options: [], using: { textElement in
            if let textElement = textElement as? NSTextParagraph {
                let layoutFragment = BubbleLayoutFragment(textElement: textElement, range: textElement.elementRange)
                layoutFragments.append(layoutFragment)
            } else {
                assertionFailure()
            }
            return true
        })
        
        /*super.enumerateTextLayoutFragments(from: self.documentRange.location, options: [.ensuresLayout, .ensuresExtraLineFragment], using: { fragment in
            layoutFragments.append(fragment)
            return true
        })*/
        
        let quoteId: (NSTextLayoutFragment) -> ObjectIdentifier? = { fragment in
            guard let contentStorage = self.contentStorage else {
                return nil
            }
            let lowerBound = contentStorage.offset(from: contentStorage.documentRange.location, to: fragment.rangeInElement.location)
            let upperBound = contentStorage.offset(from: contentStorage.documentRange.location, to: fragment.rangeInElement.endLocation)
            
            if let textStorage = contentStorage.textStorage, lowerBound != NSNotFound, upperBound != NSNotFound, lowerBound >= 0, upperBound <= textStorage.length {
                let fragmentString = textStorage.attributedSubstring(from: NSRange(location: lowerBound, length: upperBound - lowerBound))
                
                if fragmentString.length != 0, let attribute = fragmentString.attribute(NSAttributedString.Key(rawValue: "Attribute__Blockquote"), at: 0, effectiveRange: nil) as? ChatTextInputTextQuoteAttribute {
                    return ObjectIdentifier(attribute)
                }
            }
            
            return nil
        }
        
        return super.enumerateTextLayoutFragments(from: location, options: options, using: { fragment in
            var fragment = fragment
            if let index = layoutFragments.firstIndex(where: { $0.rangeInElement.isEqual(to: fragment.rangeInElement) }) {
                fragment = layoutFragments[index]
                
                if let fragment = fragment as? BubbleLayoutFragment {
                    if let fragmentQuoteId = quoteId(fragment) {
                        if index == 0 {
                            fragment.quoteIsFirst = false
                        } else if quoteId(layoutFragments[index - 1]) == fragmentQuoteId {
                            fragment.quoteIsFirst = false
                        } else {
                            fragment.quoteIsFirst = true
                        }
                        
                        if index == layoutFragments.count - 1 {
                            fragment.quoteIsLast = false
                        } else if quoteId(layoutFragments[index + 1]) == fragmentQuoteId {
                            fragment.quoteIsLast = false
                        } else {
                            fragment.quoteIsLast = true
                        }
                    } else {
                        fragment.quoteIsFirst = false
                        fragment.quoteIsLast = false
                    }
                }
            } else if layoutFragments.isEmpty {
            } else {
                assertionFailure()
            }
            
            return block(fragment)
        })*/
        return super.enumerateTextLayoutFragments(from: location, options: options, using: block)
    }
}

@available(iOS 15.0, *)
private class BubbleLayoutFragment: NSTextLayoutFragment {
    var quoteIsFirst: Bool = false
    var quoteIsLast: Bool = false
    
    override var leadingPadding: CGFloat {
        return 0.0
    }
    
    override var trailingPadding: CGFloat {
        return 0.0
    }
    
    override var topMargin: CGFloat {
        return self.quoteIsFirst ? 10.0 : 0.0
    }
    
    override var bottomMargin: CGFloat {
        return self.quoteIsLast ? 10.0 : 0.0
    }
    
    override var layoutFragmentFrame: CGRect {
        let result = super.layoutFragmentFrame
        return result
    }
    
    override var renderingSurfaceBounds: CGRect {
        return super.renderingSurfaceBounds
    }
    
    private var tightTextBounds: CGRect {
        var fragmentTextBounds = CGRect.null
        for lineFragment in textLineFragments {
            let lineFragmentBounds = lineFragment.typographicBounds
            if fragmentTextBounds.isNull {
                fragmentTextBounds = lineFragmentBounds
            } else {
                fragmentTextBounds = fragmentTextBounds.union(lineFragmentBounds)
            }
        }
        return fragmentTextBounds
    }
    
    // Return the bounding rect of the chat bubble, in the space of the first line fragment.
    private var bubbleRect: CGRect { return tightTextBounds.insetBy(dx: -3, dy: -3) }
    
    private var bubbleCornerRadius: CGFloat { return 20 }
    
    private var bubbleColor: UIColor { return .systemIndigo.withAlphaComponent(0.5) }

    private func createBubblePath(with ctx: CGContext) -> CGPath {
        let bubbleRect = self.bubbleRect
        let rect = min(bubbleCornerRadius, bubbleRect.size.height / 2, bubbleRect.size.width / 2)
        return CGPath(roundedRect: bubbleRect, cornerWidth: rect, cornerHeight: rect, transform: nil)
    }
    
    override func draw(at renderingOrigin: CGPoint, in ctx: CGContext) {
        // Draw the bubble and debug outline.
        ctx.saveGState()
        let bubblePath = createBubblePath(with: ctx)
        ctx.addPath(bubblePath)
        ctx.setFillColor(bubbleColor.cgColor)
        ctx.fillPath()
        ctx.restoreGState()
        
        var offset: CGFloat = 0.0
        for textLineFragment in self.textLineFragments {
            textLineFragment.draw(at: CGPoint(x: renderingOrigin.x, y: renderingOrigin.y + offset), in: ctx)
            offset += textLineFragment.typographicBounds.height
        }
    }
}

open class ChatInputTextNode: ASDisplayNode {
    public final class TargetForAction {
        public let target: Any?
        
        public init(target: Any?) {
            self.target = target
        }
    }
    
    public weak var delegate: ChatInputTextNodeDelegate? {
        didSet {
            self.textView.customDelegate = self.delegate
        }
    }
    
    public var textView: ChatInputTextView {
        return self.view as! ChatInputTextView
    }
    
    public var keyboardAppearance: UIKeyboardAppearance {
        get {
            return self.textView.keyboardAppearance
        }
        set {
            guard newValue != self.keyboardAppearance else {
                return
            }
            self.textView.keyboardAppearance = newValue
            self.textView.reloadInputViews()
        }
    }
    
    public var initialPrimaryLanguage: String? {
        get {
            return self.textView.initialPrimaryLanguage
        } set(value) {
            self.textView.initialPrimaryLanguage = value
        }
    }
    
    public func isCurrentlyEmoji() -> Bool {
        return false
    }
    
    public var textInputMode: UITextInputMode? {
        return self.textView.textInputMode
    }
    
    public var selectedRange: NSRange {
        get {
            return self.textView.selectedRange
        } set(value) {
            if self.textView.selectedRange != value {
                self.textView.selectedRange = value
            }
        }
    }
    
    public var attributedText: NSAttributedString? {
        get {
            return self.textView.attributedText
        } set(value) {
            self.textView.attributedText = value
        }
    }
    
    public var isRTL: Bool {
        return self.textView.isRTL
    }
    
    public var selectionRect: CGRect {
        guard let range = self.textView.selectedTextRange else {
            return self.textView.bounds
        }
        return self.textView.firstRect(for: range)
    }
    
    public var textContainerInset: UIEdgeInsets {
        get {
            return self.textView.defaultTextContainerInset
        } set(value) {
            let targetValue = UIEdgeInsets(top: value.top, left: value.left, bottom: value.bottom, right: value.right)
            if self.textView.defaultTextContainerInset != value {
                self.textView.defaultTextContainerInset = targetValue
            }
        }
    }

    public init(disableTiling: Bool = false) {
        super.init()

        self.setViewBlock({
            return ChatInputTextView(disableTiling: disableTiling)
        })
    }
    
    public func resetInitialPrimaryLanguage() {
    }
    
    public func textHeightForWidth(_ width: CGFloat, rightInset: CGFloat) -> CGFloat {
        return self.textView.textHeightForWidth(width, rightInset: rightInset)
    }
    
    public func updateLayout(size: CGSize) {
        self.textView.updateLayout(size: size)
    }
}

private final class ChatInputTextContainer: NSTextContainer {
    var rightInset: CGFloat = 0.0
    
    override var isSimpleRectangularTextContainer: Bool {
        return false
    }
    
    override init(size: CGSize) {
        super.init(size: size)
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func lineFragmentRect(forProposedRect proposedRect: CGRect, at characterIndex: Int, writingDirection baseWritingDirection: NSWritingDirection, remaining remainingRect: UnsafeMutablePointer<CGRect>?) -> CGRect {
        var result = super.lineFragmentRect(forProposedRect: proposedRect, at: characterIndex, writingDirection: baseWritingDirection, remaining: remainingRect)
        
        result.origin.x -= 5.0
        result.size.width -= 5.0
        result.size.width -= self.rightInset
        
        var attributedString: NSAttributedString?
        if #available(iOS 15.0, *), let textLayoutManager = self.textLayoutManager as? ChatInputTextLayoutManager {
            attributedString = textLayoutManager.contentStorage?.attributedString
        } else if let textStorage = self.layoutManager?.textStorage {
            attributedString = textStorage
        }
        
        if let textStorage = attributedString {
            let string: NSString = textStorage.string as NSString
            let index = Int(characterIndex)
            if index >= 0 && index < string.length {
                let attributes = textStorage.attributes(at: index, effectiveRange: nil)
                let blockQuote = attributes[NSAttributedString.Key(rawValue: "Attribute__Blockquote")] as? ChatTextInputTextQuoteAttribute
                if let blockQuote {
                    result.origin.x += 9.0
                    result.size.width -= 9.0
                    result.size.width -= 7.0
                    
                    var isFirstLine = false
                    if index == 0 {
                        isFirstLine = true
                    } else {
                        let previousAttributes = textStorage.attributes(at: index - 1, effectiveRange: nil)
                        let previousBlockQuote = previousAttributes[NSAttributedString.Key(rawValue: "Attribute__Blockquote")] as? NSObject
                        if let previousBlockQuote {
                            if !blockQuote.isEqual(previousBlockQuote) {
                                isFirstLine = true
                            }
                        } else {
                            isFirstLine = true
                        }
                    }
                    
                    if isFirstLine, case .quote = blockQuote.kind {
                        result.size.width -= 18.0
                    }
                }
            }
        }
        
        result.size.width = max(1.0, result.size.width)
        
        return result
    }
}

private final class ChatInputLegacyLayoutManager: NSLayoutManager {
    override init() {
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func notShownAttribute(forGlyphAt glyphIndex: Int) -> Bool {
        return true
    }
    
    override func drawGlyphs(forGlyphRange glyphsToShow: NSRange, at origin: CGPoint) {
        guard let context = UIGraphicsGetCurrentContext() else {
            super.drawGlyphs(forGlyphRange: glyphsToShow, at: origin)
            return
        }
        let _ = context
        /*for i in glyphsToShow.lowerBound ..< glyphsToShow.upperBound {
            let rect = self.lineFragmentRect(forGlyphAt: i, effectiveRange: nil, withoutAdditionalLayout: true)
            context.setAlpha(max(0.0, min(1.0, rect.minY / 200.0)))
            let location = self.location(forGlyphAt: i)
            super.drawGlyphs(forGlyphRange: NSRange(location: i, length: 1), at: location)
        }
        context.setAlpha(1.0)*/
        super.drawGlyphs(forGlyphRange: glyphsToShow, at: origin)
    }
}

private struct DisplayBlockQuote {
    var id: Int
    var boundingRect: CGRect
    var kind: ChatTextInputTextQuoteAttribute.Kind
    var isCollapsed: Bool
    var range: NSRange
    
    init(id: Int, boundingRect: CGRect, kind: ChatTextInputTextQuoteAttribute.Kind, isCollapsed: Bool, range: NSRange) {
        self.id = id
        self.boundingRect = boundingRect
        self.kind = kind
        self.isCollapsed = isCollapsed
        self.range = range
    }
}

private protocol ChatInputTextInternal: AnyObject {
    var textContainer: ChatInputTextContainer { get }
    
    var defaultTextContainerInset: UIEdgeInsets { get set }
    
    var updateDisplayElements: (() -> Void)? { get set }
    var attributedString: NSAttributedString? { get }
    
    func invalidateLayout()
    func setAttributedString(attributedString: NSAttributedString)
    func textSize() -> CGSize
    func currentTextBoundingRect() -> CGRect
    func currentTextLastLineBoundingRect() -> CGRect
    func displayBlockQuotes() -> [DisplayBlockQuote]
}

private final class ChatInputTextLegacyInternal: NSObject, ChatInputTextInternal, NSLayoutManagerDelegate, NSTextStorageDelegate {
    let textContainer: ChatInputTextContainer
    let customTextStorage: NSTextStorage
    let customLayoutManager: ChatInputLegacyLayoutManager
    
    var defaultTextContainerInset: UIEdgeInsets = UIEdgeInsets()
    
    var updateDisplayElements: (() -> Void)?
    
    var attributedString: NSAttributedString? {
        return self.customTextStorage
    }
    
    override init() {
        self.textContainer = ChatInputTextContainer(size: CGSize(width: 100.0, height: 100000.0))
        self.customTextStorage = NSTextStorage()
        self.customLayoutManager = ChatInputLegacyLayoutManager()
        self.customTextStorage.addLayoutManager(self.customLayoutManager)
        self.customLayoutManager.addTextContainer(self.textContainer)
        
        super.init()
        
        self.textContainer.widthTracksTextView = false
        self.textContainer.heightTracksTextView = false
        
        self.customLayoutManager.delegate = self
        self.customTextStorage.delegate = self
    }
    
    @objc func layoutManager(_ layoutManager: NSLayoutManager, paragraphSpacingBeforeGlyphAt glyphIndex: Int, withProposedLineFragmentRect rect: CGRect) -> CGFloat {
        guard let textStorage = layoutManager.textStorage else {
            return 0.0
        }
        let characterIndex = Int(layoutManager.characterIndexForGlyph(at: glyphIndex))
        if characterIndex < 0 || characterIndex >= textStorage.length {
            return 0.0
        }
        
        let attributes = textStorage.attributes(at: characterIndex, effectiveRange: nil)
        guard let blockQuote = attributes[NSAttributedString.Key("Attribute__Blockquote")] as? NSObject else {
            return 0.0
        }
        
        if characterIndex != 0 {
            let previousAttributes = textStorage.attributes(at: characterIndex - 1, effectiveRange: nil)
            let previousBlockQuote = previousAttributes[NSAttributedString.Key("Attribute__Blockquote")] as? NSObject
            if let previousBlockQuote, blockQuote.isEqual(previousBlockQuote) {
                return 0.0
            }
        }
        
        return 8.0
    }
    
    @objc func layoutManager(_ layoutManager: NSLayoutManager, paragraphSpacingAfterGlyphAt glyphIndex: Int, withProposedLineFragmentRect rect: CGRect) -> CGFloat {
        guard let textStorage = layoutManager.textStorage else {
            return 0.0
        }
        var characterIndex = Int(layoutManager.characterIndexForGlyph(at: glyphIndex))
        characterIndex -= 1
        if characterIndex < 0 {
            characterIndex = 0
        }
        if characterIndex < 0 || characterIndex >= textStorage.length {
            return 0.0
        }
        
        let attributes = textStorage.attributes(at: characterIndex, effectiveRange: nil)
        guard let blockQuote = attributes[NSAttributedString.Key("Attribute__Blockquote")] as? NSObject else {
            return 0.0
        }
        
        if characterIndex + 1 < textStorage.length {
            let nextAttributes = textStorage.attributes(at: characterIndex + 1, effectiveRange: nil)
            let nextBlockQuote = nextAttributes[NSAttributedString.Key("Attribute__Blockquote")] as? NSObject
            if let nextBlockQuote, blockQuote.isEqual(nextBlockQuote) {
                return 0.0
            }
        }
        
        return 8.0
    }
    
    @objc func layoutManager(_ layoutManager: NSLayoutManager, didCompleteLayoutFor textContainer: NSTextContainer?, atEnd layoutFinishedFlag: Bool) {
        if textContainer !== self.textContainer {
            return
        }
        self.updateDisplayElements?()
    }
    
    func invalidateLayout() {
        self.customLayoutManager.invalidateLayout(forCharacterRange: NSRange(location: 0, length: self.customTextStorage.length), actualCharacterRange: nil)
        self.customLayoutManager.ensureLayout(for: self.textContainer)
    }
    
    func setAttributedString(attributedString: NSAttributedString) {
        self.customTextStorage.setAttributedString(attributedString)
    }
    
    func textSize() -> CGSize {
        return self.customLayoutManager.usedRect(for: self.textContainer).size
    }
    
    func currentTextBoundingRect() -> CGRect {
        let glyphRange = self.customLayoutManager.glyphRange(forCharacterRange: NSRange(location: 0, length: self.customTextStorage.length), actualCharacterRange: nil)
        
        var boundingRect = CGRect()
        var startIndex = glyphRange.lowerBound
        while startIndex < glyphRange.upperBound {
            var effectiveRange = NSRange(location: NSNotFound, length: 0)
            var rect = self.customLayoutManager.lineFragmentUsedRect(forGlyphAt: startIndex, effectiveRange: &effectiveRange)
            
            let characterRange = self.customLayoutManager.characterRange(forGlyphRange: NSRange(location: startIndex, length: 1), actualGlyphRange: nil)
            if characterRange.location != NSNotFound {
                if let attribute = self.customTextStorage.attribute(NSAttributedString.Key("Attribute__Blockquote"), at: characterRange.location, effectiveRange: nil) {
                    let _ = attribute
                    rect.size.width += 13.0
                } else if let attribute = self.customTextStorage.attribute(.attachment, at: characterRange.location, effectiveRange: nil) as? ChatInputTextCollapsedQuoteAttachment {
                    let _ = attribute
                    rect.size.width += 8.0
                }
            }
            
            if boundingRect.isEmpty {
                boundingRect = rect
            } else {
                boundingRect = boundingRect.union(rect)
            }
            if effectiveRange.location != NSNotFound {
                startIndex = max(startIndex + 1, effectiveRange.upperBound)
            } else {
                break
            }
        }
        
        return boundingRect
    }
    
    func currentTextLastLineBoundingRect() -> CGRect {
        let glyphRange = self.customLayoutManager.glyphRange(forCharacterRange: NSRange(location: 0, length: self.customTextStorage.length), actualCharacterRange: nil)
        var boundingRect = CGRect()
        var startIndex = glyphRange.lowerBound
        while startIndex < glyphRange.upperBound {
            var effectiveRange = NSRange(location: NSNotFound, length: 0)
            let rect = self.customLayoutManager.lineFragmentUsedRect(forGlyphAt: startIndex, effectiveRange: &effectiveRange)
            boundingRect = rect
            if effectiveRange.location != NSNotFound {
                startIndex = max(startIndex + 1, effectiveRange.upperBound)
            } else {
                break
            }
        }
        return boundingRect
    }
    
    func displayBlockQuotes() -> [DisplayBlockQuote] {
        var result: [DisplayBlockQuote] = []
        var blockQuoteIndex = 0
        self.customTextStorage.enumerateAttribute(NSAttributedString.Key(rawValue: "Attribute__Blockquote"), in: NSRange(location: 0, length: self.customTextStorage.length), using: { value, range, _ in
            if let value = value as? ChatTextInputTextQuoteAttribute {
                let glyphRange = self.customLayoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
                if self.customLayoutManager.isValidGlyphIndex(glyphRange.location) && self.customLayoutManager.isValidGlyphIndex(glyphRange.location + glyphRange.length - 1) {
                } else {
                    return
                }
                
                let id = blockQuoteIndex
                
                var boundingRect = CGRect()
                var startIndex = glyphRange.lowerBound
                while startIndex < glyphRange.upperBound {
                    var effectiveRange = NSRange(location: NSNotFound, length: 0)
                    let rect = self.customLayoutManager.lineFragmentUsedRect(forGlyphAt: startIndex, effectiveRange: &effectiveRange)
                    if boundingRect.isEmpty {
                        boundingRect = rect
                    } else {
                        boundingRect = boundingRect.union(rect)
                    }
                    if effectiveRange.location != NSNotFound {
                        startIndex = max(startIndex + 1, effectiveRange.upperBound)
                    } else {
                        break
                    }
                }
                
                boundingRect.origin.y += self.defaultTextContainerInset.top
                
                boundingRect.origin.x -= 4.0
                boundingRect.size.width += 4.0
                if case .quote = value.kind {
                    boundingRect.size.width += 18.0
                    boundingRect.size.width = min(boundingRect.size.width, self.textContainer.size.width - 18.0)
                }
                boundingRect.size.width = min(boundingRect.size.width, self.textContainer.size.width)
                
                boundingRect.origin.y -= 4.0
                boundingRect.size.height += 8.0
                
                result.append(DisplayBlockQuote(id: id, boundingRect: boundingRect, kind: value.kind, isCollapsed: value.isCollapsed, range: range))
                
                blockQuoteIndex += 1
            }
        })
        self.customTextStorage.enumerateAttribute(NSAttributedString.Key.attachment, in: NSRange(location: 0, length: self.customTextStorage.length), using: { value, range, _ in
            if let _ = value as? ChatInputTextCollapsedQuoteAttachment {
                let glyphRange = self.customLayoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
                if self.customLayoutManager.isValidGlyphIndex(glyphRange.location) && self.customLayoutManager.isValidGlyphIndex(glyphRange.location + glyphRange.length - 1) {
                } else {
                    return
                }
                
                let id = blockQuoteIndex
                
                var boundingRect = CGRect()
                var startIndex = glyphRange.lowerBound
                while startIndex < glyphRange.upperBound {
                    var effectiveRange = NSRange(location: NSNotFound, length: 0)
                    let rect = self.customLayoutManager.lineFragmentUsedRect(forGlyphAt: startIndex, effectiveRange: &effectiveRange)
                    if boundingRect.isEmpty {
                        boundingRect = rect
                    } else {
                        boundingRect = boundingRect.union(rect)
                    }
                    if effectiveRange.location != NSNotFound {
                        startIndex = max(startIndex + 1, effectiveRange.upperBound)
                    } else {
                        break
                    }
                }
                
                boundingRect.origin.y += self.defaultTextContainerInset.top
                
                boundingRect.origin.x += 5.0
                boundingRect.size.width += 4.0
                boundingRect.size.width += 18.0
                boundingRect.size.width = min(boundingRect.size.width, self.textContainer.size.width - 18.0)
                boundingRect.size.width = min(boundingRect.size.width, self.textContainer.size.width)
                
                boundingRect.origin.y += 4.0
                boundingRect.size.height -= 8.0
                
                result.append(DisplayBlockQuote(id: id, boundingRect: boundingRect, kind: .quote, isCollapsed: true, range: range))
                
                blockQuoteIndex += 1
            }
        })
        return result
    }
}

@available(iOS 15.0, *)
private final class ChatInputTextContentStorage: NSTextContentStorage {
    
}

@available(iOS 15.0, *)
private final class ChatInputTextNewInternal: NSObject, ChatInputTextInternal, NSTextContentStorageDelegate, NSTextLayoutManagerDelegate {
    let textContainer: ChatInputTextContainer
    let contentStorage: ChatInputTextContentStorage
    let customLayoutManager: ChatInputTextLayoutManager
    
    var defaultTextContainerInset: UIEdgeInsets = UIEdgeInsets()
    
    var updateDisplayElements: (() -> Void)?
    
    var attributedString: NSAttributedString? {
        return self.contentStorage.attributedString
    }
    
    override init() {
        self.textContainer = ChatInputTextContainer(size: CGSize(width: 100.0, height: 100000.0))
        self.contentStorage = ChatInputTextContentStorage()
        self.customLayoutManager = ChatInputTextLayoutManager(contentStorage: self.contentStorage)
        self.contentStorage.addTextLayoutManager(self.customLayoutManager)
        self.customLayoutManager.textContainer = self.textContainer
        
        super.init()
        
        self.contentStorage.delegate = self
        self.customLayoutManager.delegate = self
    }
    
    func invalidateLayout() {
        self.customLayoutManager.invalidateLayout(for: self.contentStorage.documentRange)
        self.customLayoutManager.ensureLayout(for: self.contentStorage.documentRange)
    }
    
    func setAttributedString(attributedString: NSAttributedString) {
        self.contentStorage.attributedString = attributedString
    }
    
    func textSize() -> CGSize {
        return self.currentTextBoundingRect().size
    }
    
    func currentTextBoundingRect() -> CGRect {
        var boundingRect = CGRect()
        self.customLayoutManager.enumerateTextLayoutFragments(from: self.contentStorage.documentRange.location, options: [.ensuresLayout, .ensuresExtraLineFragment], using: { fragment in
            let fragmentFrame = fragment.layoutFragmentFrame
            if boundingRect.isEmpty {
                boundingRect = fragmentFrame
            } else {
                boundingRect = boundingRect.union(fragmentFrame)
            }
            return true
        })
        
        return boundingRect
    }
    
    func currentTextLastLineBoundingRect() -> CGRect {
        var boundingRect = CGRect()
        self.customLayoutManager.enumerateTextLayoutFragments(from: self.contentStorage.documentRange.location, options: [.ensuresLayout, .ensuresExtraLineFragment], using: { fragment in
            let fragmentFrame = fragment.layoutFragmentFrame
            for textLineFragment in fragment.textLineFragments {
                boundingRect = textLineFragment.typographicBounds.offsetBy(dx: fragmentFrame.minX, dy: fragmentFrame.minY)
            }
            return true
        })
        
        return boundingRect
    }
    
    @objc func textLayoutManager(_ textLayoutManager: NSTextLayoutManager, textLayoutFragmentFor location: NSTextLocation, in textElement: NSTextElement) -> NSTextLayoutFragment {
        let layoutFragment = BubbleLayoutFragment(textElement: textElement, range: textElement.elementRange)
        return layoutFragment
    }
    
    func displayBlockQuotes() -> [DisplayBlockQuote] {
        var nextId = 0
        var result: [ObjectIdentifier: DisplayBlockQuote] = [:]
        
        self.customLayoutManager.enumerateTextLayoutFragments(from: self.contentStorage.documentRange.location, options: [.ensuresLayout, .ensuresExtraLineFragment], using: { fragment in
            let lowerBound = self.contentStorage.offset(from: self.contentStorage.documentRange.location, to: fragment.rangeInElement.location)
            let upperBound = self.contentStorage.offset(from: self.contentStorage.documentRange.location, to: fragment.rangeInElement.endLocation)
            if let textStorage = self.contentStorage.textStorage, lowerBound != NSNotFound, upperBound != NSNotFound, lowerBound >= 0, upperBound <= textStorage.length {
                let fragmentRange = NSRange(location: lowerBound, length: upperBound - lowerBound)
                let fragmentString = textStorage.attributedSubstring(from: fragmentRange)
                
                var fragmentFrame = fragment.layoutFragmentFrame
                
                if fragmentString.length != 0, let attribute = fragmentString.attribute(NSAttributedString.Key(rawValue: "Attribute__Blockquote"), at: 0, effectiveRange: nil) as? ChatTextInputTextQuoteAttribute {
                    fragmentFrame.origin.y += self.defaultTextContainerInset.top
                    
                    fragmentFrame.origin.x -= 4.0
                    fragmentFrame.size.width += 4.0
                    if case .quote = attribute.kind {
                        fragmentFrame.size.width += 18.0
                        fragmentFrame.size.width = min(fragmentFrame.size.width, self.textContainer.size.width - 18.0)
                    }
                    fragmentFrame.size.width = min(fragmentFrame.size.width, self.textContainer.size.width)
                    
                    let quoteId = ObjectIdentifier(attribute)
                    if var current = result[quoteId] {
                        current.boundingRect = current.boundingRect.union(fragmentFrame)
                        
                        let newLowerBound = min(current.range.lowerBound, fragmentRange.lowerBound)
                        let newUpperBound = max(current.range.upperBound, fragmentRange.upperBound)
                        
                        current.range = NSRange(location: newLowerBound, length: newUpperBound - newLowerBound)
                        result[quoteId] = current
                    } else {
                        let id = nextId
                        nextId += 1
                        result[quoteId] = DisplayBlockQuote(id: id, boundingRect: fragmentFrame, kind: attribute.kind, isCollapsed: attribute.isCollapsed, range: fragmentRange)
                    }
                }
            }
            
            return true
        })
        
        return Array(result.values).sorted(by: { lhs, rhs in
            return lhs.boundingRect.minY < rhs.boundingRect.minY
        })
    }
}

private let registeredViewProvider: Void = {
    if #available(iOS 15.0, *) {
        NSTextAttachment.registerViewProviderClass(ChatInputTextCollapsedQuoteAttachmentImpl.ViewProvider.self, forFileType: "public.data")
    }
}()

public final class ChatInputTextCollapsedQuoteAttachmentImpl: NSTextAttachment, ChatInputTextCollapsedQuoteAttachment {
    final class View: UIView {
        let attachment: ChatInputTextCollapsedQuoteAttachmentImpl
        let textNode: ImmediateTextNodeWithEntities
        
        init(attachment: ChatInputTextCollapsedQuoteAttachmentImpl) {
            self.attachment = attachment
            self.textNode = ImmediateTextNodeWithEntities()
            self.textNode.displaysAsynchronously = false
            self.textNode.maximumNumberOfLines = 3
            
            super.init(frame: CGRect())
            
            self.addSubview(self.textNode.view)
        }
        
        required init(coder: NSCoder) {
            preconditionFailure()
        }
        
        static func calculateSize(attachment: ChatInputTextCollapsedQuoteAttachmentImpl, constrainedSize: CGSize) -> CGSize {
            guard let context = attachment.attributes.context as? AccountContext else {
                return CGSize(width: 10.0, height: 10.0)
            }
            
            let renderingText = textAttributedStringForStateText(
                context: context,
                stateText: attachment.text,
                fontSize: attachment.attributes.fontSize,
                textColor: attachment.attributes.textColor,
                accentTextColor: attachment.attributes.accentTextColor,
                writingDirection: nil,
                spoilersRevealed: false,
                availableEmojis: Set(context.animatedEmojiStickersValue.keys),
                emojiViewProvider: nil,
                makeCollapsedQuoteAttachment: nil
            )
            
            let textNode = ImmediateTextNode()
            textNode.maximumNumberOfLines = 3
            
            textNode.attributedText = renderingText
            textNode.cutout = TextNodeCutout(topRight: CGSize(width: 30.0, height: 10.0))
            
            let layoutSize = textNode.updateLayout(CGSize(width: constrainedSize.width - 9.0, height: constrainedSize.height))
            
            return CGSize(width: constrainedSize.width, height: 8.0 + layoutSize.height + 8.0)
        }
        
        override func layoutSubviews() {
            super.layoutSubviews()
            
            guard let context = self.attachment.attributes.context as? AccountContext else {
                return
            }
            
            let renderingText = textAttributedStringForStateText(
                context: context, stateText: self.attachment.text,
                fontSize: self.attachment.attributes.fontSize,
                textColor: self.attachment.attributes.textColor,
                accentTextColor: self.attachment.attributes.accentTextColor,
                writingDirection: nil,
                spoilersRevealed: false,
                availableEmojis: Set(context.animatedEmojiStickersValue.keys),
                emojiViewProvider: nil,
                makeCollapsedQuoteAttachment: nil
            )
            
            /*let renderingText = NSMutableAttributedString(attributedString: attachment.text)
            renderingText.addAttribute(.font, value: attachment.attributes.font, range: NSRange(location: 0, length: renderingText.length))
            renderingText.addAttribute(.foregroundColor, value: attachment.attributes.textColor, range: NSRange(location: 0, length: renderingText.length))*/
            
            self.textNode.arguments = TextNodeWithEntities.Arguments(
                context: context,
                cache: context.animationCache,
                renderer: context.animationRenderer,
                placeholderColor: .gray,
                attemptSynchronous: true
            )
            
            self.textNode.attributedText = renderingText
            self.textNode.cutout = TextNodeCutout(topRight: CGSize(width: 30.0, height: 10.0))
            
            self.textNode.displaySpoilerEffect = true
            self.textNode.visibility = true
            
            let maxTextSize = CGSize(width: self.bounds.size.width - 9.0, height: self.bounds.size.height)
            let layoutSize = self.textNode.updateLayout(maxTextSize)
            
            self.textNode.frame = CGRect(origin: CGPoint(x: 9.0, y: 8.0), size: layoutSize)
        }
    }
    
    @available(iOS 15.0, *)
    final class ViewProvider: NSTextAttachmentViewProvider {
        override init(
            textAttachment: NSTextAttachment,
            parentView: UIView?,
            textLayoutManager: NSTextLayoutManager?,
            location: NSTextLocation
        ) {
            super.init(textAttachment: textAttachment, parentView: parentView, textLayoutManager: textLayoutManager, location: location)
        }
        
        override public func loadView() {
            if let textAttachment = self.textAttachment as? ChatInputTextCollapsedQuoteAttachmentImpl {
                self.view = View(attachment: textAttachment)
            } else {
                self.view = UIView()
            }
        }
    }
    
    public let text: NSAttributedString
    public let attributes: ChatInputTextCollapsedQuoteAttributes
    
    public init(text: NSAttributedString, attributes: ChatInputTextCollapsedQuoteAttributes) {
        let _ = registeredViewProvider
        
        self.text = text
        self.attributes = attributes
        
        super.init(data: nil, ofType: "public.data")
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func attachmentBounds(for textContainer: NSTextContainer?, proposedLineFragment lineFrag: CGRect, glyphPosition position: CGPoint, characterIndex charIndex: Int) -> CGRect {
        return CGRect(origin: CGPoint(), size: View.calculateSize(attachment: self, constrainedSize: CGSize(width: lineFrag.width, height: 10000.0)))
    }
    
    override public func image(forBounds imageBounds: CGRect, textContainer: NSTextContainer?, characterIndex charIndex: Int) -> UIImage? {
        return nil
    }
}

public final class ChatInputTextView: ChatInputTextViewImpl, UITextViewDelegate, NSLayoutManagerDelegate, NSTextStorageDelegate {
    public final class Theme: Equatable {
        public final class Quote: Equatable {
            public enum LineStyle: Equatable {
                case solid(color: UIColor)
                case doubleDashed(mainColor: UIColor, secondaryColor: UIColor)
                case tripleDashed(mainColor: UIColor, secondaryColor: UIColor, tertiaryColor: UIColor)
            }
            public let background: UIColor
            public let foreground: UIColor
            public let lineStyle: LineStyle
            public let codeBackground: UIColor
            public let codeForeground: UIColor
            
            public init(
                background: UIColor,
                foreground: UIColor,
                lineStyle: LineStyle,
                codeBackground: UIColor,
                codeForeground: UIColor
            ) {
                self.background = background
                self.foreground = foreground
                self.lineStyle = lineStyle
                self.codeBackground = codeBackground
                self.codeForeground = codeForeground
            }
            
            public static func ==(lhs: Quote, rhs: Quote) -> Bool {
                if !lhs.background.isEqual(rhs.background) {
                    return false
                }
                if !lhs.foreground.isEqual(rhs.foreground) {
                    return false
                }
                if lhs.lineStyle != rhs.lineStyle {
                    return false
                }
                if !lhs.codeBackground.isEqual(rhs.codeBackground) {
                    return false
                }
                if !lhs.codeForeground.isEqual(rhs.codeForeground) {
                    return false
                }
                return true
            }
        }
        
        public let quote: Quote
        
        public init(quote: Quote) {
            self.quote = quote
        }
        
        public static func ==(lhs: Theme, rhs: Theme) -> Bool {
            if lhs.quote != rhs.quote {
                return false
            }
            return true
        }
    }
    
    override public var attributedText: NSAttributedString? {
        get {
            return super.attributedText
        } set(value) {
            if self.attributedText != value {
                let selectedRange = self.selectedRange
                let preserveSelectedRange = selectedRange.location != self.textStorage.length
                
                super.attributedText = value ?? NSAttributedString()
                
                if preserveSelectedRange {
                    self.isPreservingSelection = true
                    self.selectedRange = selectedRange
                    self.isPreservingSelection = false
                }
                
                self.updateTextContainerInset()
            }
        }
    }
    
    fileprivate var isPreservingSelection: Bool = false
    fileprivate var isPreservingText: Bool = false
    
    public weak var customDelegate: ChatInputTextNodeDelegate?
    
    public var theme: Theme? {
        didSet {
            if self.theme != oldValue {
                self.updateTextElements()
            }
        }
    }
    
    public var toggleQuoteCollapse: ((NSRange) -> Void)?
    
    private let displayInternal: ChatInputTextInternal
    private let measureInternal: ChatInputTextInternal
    
    private var validLayoutSize: CGSize?
    private var isUpdatingLayout: Bool = false
    
    private var blockQuotes: [Int: QuoteBackgroundView] = [:]
    
    public var defaultTextContainerInset: UIEdgeInsets = UIEdgeInsets() {
        didSet {
            if self.defaultTextContainerInset != oldValue {
                self.updateTextContainerInset()
            }
        }
    }
    
    public var currentRightInset: CGFloat {
        return self.displayInternal.textContainer.rightInset
    }
    
    private var didInitializePrimaryInputLanguage: Bool = false
    public var initialPrimaryLanguage: String?
    
    private var selectionChangedForEditedText: Bool = false
    
    override public var textInputMode: UITextInputMode? {
        if !self.didInitializePrimaryInputLanguage {
            self.didInitializePrimaryInputLanguage = true
            if let initialPrimaryLanguage = self.initialPrimaryLanguage {
                for inputMode in UITextInputMode.activeInputModes {
                    if let primaryLanguage = inputMode.primaryLanguage, primaryLanguage == initialPrimaryLanguage {
                        return inputMode
                    }
                }
            }
        }
        return super.textInputMode
    }
    
    override public var bounds: CGRect {
        didSet {
            assert(true)
        }
    }
    
    public init(disableTiling: Bool) {
        let useModernImpl = !"".isEmpty
        
        if #available(iOS 15.0, *), useModernImpl {
            self.displayInternal = ChatInputTextNewInternal()
            self.measureInternal = ChatInputTextNewInternal()
        } else {
            self.displayInternal = ChatInputTextLegacyInternal()
            self.measureInternal = ChatInputTextLegacyInternal()
        }
        
        super.init(frame: CGRect(), textContainer: self.displayInternal.textContainer, disableTiling: disableTiling)
        
        self.delegate = self
        
        self.displayInternal.updateDisplayElements = { [weak self] in
            self?.updateTextElements()
        }
        
        self.shouldRespondToAction = { [weak self] action in
            guard let self, let action else {
                return false
            }
            if let delegate = self.customDelegate {
                return delegate.chatInputTextNodeShouldRespondToAction(action: action)
            } else {
                return true
            }
        }
        self.targetForAction = { [weak self] action in
            guard let self, let action else {
                return nil
            }
            if let delegate = self.customDelegate {
                return delegate.chatInputTextNodeTargetForAction(action: action).flatMap { value in
                    return ChatInputTextViewImplTargetForAction(target: value.target)
                }
            } else {
                return nil
            }
        }
        
        self.textContainerInset = UIEdgeInsets()
        self.backgroundColor = nil
        self.isOpaque = false
        
        self.dropAutocorrectioniOS16 = { [weak self] in
            guard let self else {
                return
            }
            
            self.isPreservingSelection = true
            self.isPreservingText = true
            
            let rangeCopy = self.selectedRange
            var fakeRange = rangeCopy
            if fakeRange.location != 0 {
                fakeRange.location -= 1
            }
            self.unmarkText()
            self.selectedRange = fakeRange
            self.selectedRange = rangeCopy
            
            self.isPreservingSelection = false
            self.isPreservingText = false
        }
        
        self.shouldCopy = { [weak self] in
            guard let self else {
                return true
            }
            return self.customDelegate?.chatInputTextNodeShouldCopy() ?? true
        }
        self.shouldPaste = { [weak self] in
            guard let self else {
                return true
            }
            return self.customDelegate?.chatInputTextNodeShouldPaste() ?? true
        }
        self.shouldReturn = { [weak self] in
            guard let self else {
                return true
            }
            return self.customDelegate?.chatInputTextNodeShouldReturn() ?? true
        }
        self.backspaceWhileEmpty = { [weak self] in
            guard let self else {
                return
            }
            self.customDelegate?.chatInputTextNodeBackspaceWhileEmpty()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func scrollRectToVisible(_ rect: CGRect, animated: Bool) {
        var rect = rect
        if rect.maxY > self.contentSize.height - 8.0 {
            rect = CGRect(origin: CGPoint(x: rect.minX, y: self.contentSize.height - 1.0), size: CGSize(width: rect.width, height: 1.0))
        }
        
        var animated = animated
        if self.isUpdatingLayout {
            animated = false
        }
        
        super.scrollRectToVisible(rect, animated: animated)
    }
    
    @objc public func textViewDidBeginEditing(_ textView: UITextView) {
        self.customDelegate?.chatInputTextNodeDidBeginEditing()
    }

    @objc public func textViewDidEndEditing(_ textView: UITextView) {
        self.customDelegate?.chatInputTextNodeDidFinishEditing()
    }

    @objc public func textViewDidChange(_ textView: UITextView) {
        self.selectionChangedForEditedText = true
        
        self.updateTextContainerInset()
        
        self.customDelegate?.chatInputTextNodeDidUpdateText()
        
        self.updateTextContainerInset()
    }

    @objc public func textViewDidChangeSelection(_ textView: UITextView) {
        if self.isPreservingSelection {
            return
        }
        
        self.selectionChangedForEditedText = false
        
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }
            self.customDelegate?.chatInputTextNodeDidChangeSelection(dueToEditing: self.selectionChangedForEditedText)
        }
    }

    @available(iOS 16.0, *)
    @objc public func textView(_ textView: UITextView, editMenuForTextIn range: NSRange, suggestedActions: [UIMenuElement]) -> UIMenu? {
        return self.customDelegate?.chatInputTextNodeMenu(forTextRange: range, suggestedActions: suggestedActions)
    }
    
    @objc public func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        guard let customDelegate = self.customDelegate else {
            return true
        }
        if self.isPreservingText {
            return false
        }
        return customDelegate.chatInputTextNode(shouldChangeTextIn: range, replacementText: text)
    }
    
    public func updateTextContainerInset() {
        self.displayInternal.defaultTextContainerInset = self.defaultTextContainerInset
        self.measureInternal.defaultTextContainerInset = self.defaultTextContainerInset
        
        var result = self.defaultTextContainerInset
        
        var horizontalInsetsUpdated = false
        if self.displayInternal.textContainer.rightInset != result.right {
            horizontalInsetsUpdated = true
            self.displayInternal.textContainer.rightInset = result.right
        }
        
        result.left = 0.0
        result.right = 0.0
        
        if let string = self.displayInternal.attributedString, string.length != 0 {
            let topAttributes = string.attributes(at: 0, effectiveRange: nil)
            let bottomAttributes = string.attributes(at: string.length - 1, effectiveRange: nil)
            
            if topAttributes[NSAttributedString.Key("Attribute__Blockquote")] != nil {
                result.top += 7.0
            }
            if bottomAttributes[NSAttributedString.Key("Attribute__Blockquote")] != nil {
                result.bottom += 8.0
            }
        }
        
        if self.textContainerInset != result {
            self.textContainerInset = result
        }
        if horizontalInsetsUpdated {
            self.displayInternal.invalidateLayout()
        }
        
        self.updateTextElements()
    }
    
    public func textHeightForWidth(_ width: CGFloat, rightInset: CGFloat) -> CGFloat {
        let measureSize = CGSize(width: width, height: 1000000.0)
        
        let measureText: NSAttributedString
        if let attributedText = self.attributedText, attributedText.length != 0 {
            measureText = attributedText
        } else {
            measureText = NSAttributedString(string: "A", attributes: self.typingAttributes)
        }
        
        if self.measureInternal.attributedString != measureText || self.measureInternal.textContainer.size != measureSize || self.measureInternal.textContainer.rightInset != rightInset {
            self.measureInternal.textContainer.rightInset = rightInset
            self.measureInternal.setAttributedString(attributedString: measureText)
            self.measureInternal.textContainer.size = measureSize
            self.measureInternal.invalidateLayout()
        }
        
        let textSize = self.measureInternal.textSize()
        
        return ceil(textSize.height + self.textContainerInset.top + self.textContainerInset.bottom)
    }
    
    public func updateLayout(size: CGSize) {
        let measureSize = CGSize(width: size.width, height: 1000000.0)
        
        if self.textContainer.size != measureSize {
            self.textContainer.size = measureSize
            self.displayInternal.invalidateLayout()
        }
    }
    
    override public func setNeedsLayout() {
        super.setNeedsLayout()
    }
    
    override public func layoutSubviews() {
        let isLayoutUpdated = self.validLayoutSize != self.bounds.size
        self.validLayoutSize = self.bounds.size
        
        self.isUpdatingLayout = isLayoutUpdated
        
        super.layoutSubviews()
        
        self.isUpdatingLayout = false
    }
    
    public func currentTextBoundingRect() -> CGRect {
        return self.displayInternal.currentTextBoundingRect()
    }
    
    public func lastLineBoundingRect() -> CGRect {
        return self.displayInternal.currentTextLastLineBoundingRect()
    }
    
    public func updateTextElements() {
        var validBlockQuotes: [Int] = []
        for displayBlockQuote in self.displayInternal.displayBlockQuotes() {
            let blockQuote: QuoteBackgroundView
            if let current = self.blockQuotes[displayBlockQuote.id] {
                blockQuote = current
            } else {
                blockQuote = QuoteBackgroundView(toggleCollapse: { [weak self] range in
                    guard let self else {
                        return
                    }
                    self.toggleQuoteCollapse?(range)
                })
                self.blockQuotes[displayBlockQuote.id] = blockQuote
                self.insertSubview(blockQuote, at: 0)
            }
            
            blockQuote.frame = displayBlockQuote.boundingRect
            if let theme = self.theme {
                blockQuote.update(kind: displayBlockQuote.kind, isCollapsed: displayBlockQuote.isCollapsed, range: displayBlockQuote.range, size: displayBlockQuote.boundingRect.size, theme: theme.quote)
            }
            
            validBlockQuotes.append(displayBlockQuote.id)
        }
        
        var removedBlockQuotes: [Int] = []
        for (id, blockQuote) in self.blockQuotes {
            if !validBlockQuotes.contains(id) {
                removedBlockQuotes.append(id)
                blockQuote.removeFromSuperview()
            }
        }
        for id in removedBlockQuotes {
            self.blockQuotes.removeValue(forKey: id)
        }
    }
    
    override public func caretRect(for position: UITextPosition) -> CGRect {
        return super.caretRect(for: position)
    }
    
    override public func selectionRects(for range: UITextRange) -> [UITextSelectionRect] {
        return super.selectionRects(for: range)
    }
    
    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if self.bounds.contains(point) {
            for (_, blockQuote) in self.blockQuotes {
                if let result = blockQuote.collapseButton.hitTest(self.convert(point, to: blockQuote.collapseButton), with: event) {
                    return result
                }
            }
        }
        
        let result = super.hitTest(point, with: event)
        return result
    }
}

private let quoteIcon: UIImage = {
    return UIImage(bundleImageName: "Chat/Message/ReplyQuoteIcon")!.precomposed().withRenderingMode(.alwaysTemplate)
}()

private let quoteCollapseImage: UIImage = {
    return UIImage(bundleImageName: "Media Gallery/Minimize")!.precomposed().withRenderingMode(.alwaysTemplate)
}()

private let quoteExpandImage: UIImage = {
    return UIImage(bundleImageName: "Media Gallery/Fullscreen")!.precomposed().withRenderingMode(.alwaysTemplate)
}()

private final class QuoteBackgroundView: UIView {
    private let toggleCollapse: (NSRange) -> Void
    
    private let backgroundView: MessageInlineBlockBackgroundView
    private let iconView: UIImageView
    let collapseButton: UIView
    let collapseButtonIconView: UIImageView
    
    private var range: NSRange?
    private var theme: ChatInputTextView.Theme.Quote?
    
    init(toggleCollapse: @escaping (NSRange) -> Void) {
        self.toggleCollapse = toggleCollapse
        
        self.backgroundView = MessageInlineBlockBackgroundView()
        self.iconView = UIImageView(image: quoteIcon)
        
        self.collapseButton = UIView()
        self.collapseButtonIconView = UIImageView()
        self.collapseButton.addSubview(self.collapseButtonIconView)
        
        super.init(frame: CGRect())
        
        self.addSubview(self.backgroundView)
        self.addSubview(self.iconView)
        self.addSubview(self.collapseButton)
        
        self.collapseButton.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.toggleCollapsedTapped(_:))))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func toggleCollapsedTapped(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            if let range = self.range {
                self.toggleCollapse(range)
            }
        }
    }
    
    func update(kind: ChatTextInputTextQuoteAttribute.Kind, isCollapsed: Bool, range: NSRange, size: CGSize, theme: ChatInputTextView.Theme.Quote) {
        self.range = range
        
        if self.theme != theme {
            self.theme = theme
            
            self.iconView.tintColor = theme.foreground
            self.collapseButtonIconView.tintColor = theme.foreground
        }
        
        self.iconView.frame = CGRect(origin: CGPoint(x: size.width - 4.0 - quoteIcon.size.width, y: 4.0), size: quoteIcon.size)
        
        let collapseButtonSize = CGSize(width: 18.0, height: 18.0)
        
        if isCollapsed {
            self.collapseButtonIconView.image = quoteExpandImage
            self.collapseButton.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: size)
        } else {
            self.collapseButtonIconView.image = quoteCollapseImage
            self.collapseButton.frame = CGRect(origin: CGPoint(x: size.width - 2.0 - collapseButtonSize.width, y: 2.0), size: collapseButtonSize)
        }
        if let image = self.collapseButtonIconView.image {
            let iconSize = image.size.aspectFitted(collapseButtonSize)
            self.collapseButtonIconView.frame = CGRect(origin: CGPoint(x: self.collapseButton.bounds.width - 4.0 - collapseButtonSize.width + floorToScreenPixels((collapseButtonSize.width - iconSize.width) * 0.5), y: 4.0 + floorToScreenPixels((collapseButtonSize.height - iconSize.height) * 0.5)), size: iconSize)
        }
        
        var primaryColor: UIColor
        var secondaryColor: UIColor?
        var tertiaryColor: UIColor?
        let backgroundColor: UIColor?
        
        switch kind {
        case .quote:
            if size.height >= 60.0 || isCollapsed {
                self.iconView.isHidden = true
                self.collapseButton.isHidden = false
            } else {
                self.iconView.isHidden = false
                self.collapseButton.isHidden = true
            }
            
            switch theme.lineStyle {
            case let .solid(color):
                primaryColor = color
            case let .doubleDashed(mainColor, secondaryColorValue):
                primaryColor = mainColor
                secondaryColor = secondaryColorValue
            case let .tripleDashed(mainColor, secondaryColorValue, tertiaryColorValue):
                primaryColor = mainColor
                secondaryColor = secondaryColorValue
                tertiaryColor = tertiaryColorValue
            }
            
            backgroundColor = nil
        case .code:
            self.iconView.isHidden = true
            self.collapseButton.isHidden = true
            
            primaryColor = theme.codeForeground
            backgroundColor = theme.codeBackground
        }
        
        self.backgroundView.update(
            size: size,
            isTransparent: false,
            primaryColor: primaryColor,
            secondaryColor: secondaryColor,
            thirdColor: tertiaryColor,
            backgroundColor: backgroundColor,
            pattern: nil,
            animation: .None
        )
        self.backgroundView.frame = CGRect(origin: CGPoint(), size: size)
    }
}
