import Foundation
import UIKit
import AsyncDisplayKit
import Display
import AppBundle
import ChatInputTextViewImpl
import MessageInlineBlockBackgroundView
import TextFormat

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

open class ChatInputTextNode: ASDisplayNode, UITextViewDelegate {
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
    
    private var selectionChangedForEditedText: Bool = false
    
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
        
        self.textView.delegate = self
        self.textView.shouldRespondToAction = { [weak self] action in
            guard let self, let action else {
                return false
            }
            if let delegate = self.delegate {
                return delegate.chatInputTextNodeShouldRespondToAction(action: action)
            } else {
                return true
            }
        }
        self.textView.targetForAction = { [weak self] action in
            guard let self, let action else {
                return nil
            }
            if let delegate = self.delegate {
                return delegate.chatInputTextNodeTargetForAction(action: action).flatMap { value in
                    return ChatInputTextViewImplTargetForAction(target: value.target)
                }
            } else {
                return nil
            }
        }
    }
    
    public func resetInitialPrimaryLanguage() {
    }
    
    public func textHeightForWidth(_ width: CGFloat, rightInset: CGFloat) -> CGFloat {
        return self.textView.textHeightForWidth(width, rightInset: rightInset)
    }
    
    @objc public func textViewDidBeginEditing(_ textView: UITextView) {
        self.delegate?.chatInputTextNodeDidBeginEditing()
    }

    @objc public func textViewDidEndEditing(_ textView: UITextView) {
        self.delegate?.chatInputTextNodeDidFinishEditing()
    }

    @objc public func textViewDidChange(_ textView: UITextView) {
        self.selectionChangedForEditedText = true
        
        self.delegate?.chatInputTextNodeDidUpdateText()
        
        self.textView.updateTextContainerInset()
    }

    @objc public func textViewDidChangeSelection(_ textView: UITextView) {
        if self.textView.isPreservingSelection {
            return
        }
        
        self.selectionChangedForEditedText = false
        
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }
            self.delegate?.chatInputTextNodeDidChangeSelection(dueToEditing: self.selectionChangedForEditedText)
        }
    }

    @available(iOS 16.0, *)
    @objc public func textView(_ textView: UITextView, editMenuForTextIn range: NSRange, suggestedActions: [UIMenuElement]) -> UIMenu? {
        return self.delegate?.chatInputTextNodeMenu(forTextRange: range, suggestedActions: suggestedActions)
    }
    
    @objc public func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        guard let delegate = self.delegate else {
            return true
        }
        if self.textView.isPreservingText {
            return false
        }
        return delegate.chatInputTextNode(shouldChangeTextIn: range, replacementText: text)
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
        
        if let textStorage = self.layoutManager?.textStorage {
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

public final class ChatInputTextView: ChatInputTextViewImpl, NSLayoutManagerDelegate, NSTextStorageDelegate {
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
    
    private let customTextContainer: ChatInputTextContainer
    private let customTextStorage: NSTextStorage
    private let customLayoutManager: NSLayoutManager
    
    private let measurementTextContainer: ChatInputTextContainer
    private let measurementTextStorage: NSTextStorage
    private let measurementLayoutManager: NSLayoutManager
    
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
    
    private var didInitializePrimaryInputLanguage: Bool = false
    public var initialPrimaryLanguage: String?
    
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
        self.customTextContainer = ChatInputTextContainer(size: CGSize(width: 100.0, height: 100000.0))
        self.customLayoutManager = NSLayoutManager()
        self.customTextStorage = NSTextStorage()
        self.customTextStorage.addLayoutManager(self.customLayoutManager)
        self.customLayoutManager.addTextContainer(self.customTextContainer)
        
        self.measurementTextContainer = ChatInputTextContainer(size: CGSize(width: 100.0, height: 100000.0))
        self.measurementLayoutManager = NSLayoutManager()
        self.measurementTextStorage = NSTextStorage()
        self.measurementTextStorage.addLayoutManager(self.measurementLayoutManager)
        self.measurementLayoutManager.addTextContainer(self.measurementTextContainer)
        
        super.init(frame: CGRect(), textContainer: self.customTextContainer, disableTiling: disableTiling)
        
        self.textContainerInset = UIEdgeInsets()
        self.backgroundColor = nil
        self.isOpaque = false
        
        self.customTextContainer.widthTracksTextView = false
        self.customTextContainer.heightTracksTextView = false
        
        self.measurementTextContainer.widthTracksTextView = false
        self.measurementTextContainer.heightTracksTextView = false
        
        self.customLayoutManager.delegate = self
        self.measurementLayoutManager.delegate = self
        
        self.customTextStorage.delegate = self
        self.measurementTextStorage.delegate = self
        
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
    
    @objc public func layoutManager(_ layoutManager: NSLayoutManager, paragraphSpacingBeforeGlyphAt glyphIndex: Int, withProposedLineFragmentRect rect: CGRect) -> CGFloat {
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
    
    @objc public func layoutManager(_ layoutManager: NSLayoutManager, paragraphSpacingAfterGlyphAt glyphIndex: Int, withProposedLineFragmentRect rect: CGRect) -> CGFloat {
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
    
    public func textStorage(_ textStorage: NSTextStorage, didProcessEditing editedMask: NSTextStorage.EditActions, range editedRange: NSRange, changeInLength delta: Int) {
        if textStorage !== self.customTextStorage {
            return
        }
    }
    
    public func layoutManager(_ layoutManager: NSLayoutManager, didCompleteLayoutFor textContainer: NSTextContainer?, atEnd layoutFinishedFlag: Bool) {
        if textContainer !== self.customTextContainer {
            return
        }
        self.updateTextElements()
    }
    
    public func updateTextContainerInset() {
        var result = self.defaultTextContainerInset
        
        var horizontalInsetsUpdated = false
        if self.customTextContainer.rightInset != result.right {
            horizontalInsetsUpdated = true
            self.customTextContainer.rightInset = result.right
        }
        
        result.left = 0.0
        result.right = 0.0
        
        if self.customTextStorage.length != 0 {
            let topAttributes = self.customTextStorage.attributes(at: 0, effectiveRange: nil)
            let bottomAttributes = self.customTextStorage.attributes(at: self.customTextStorage.length - 1, effectiveRange: nil)
            
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
            self.customLayoutManager.invalidateLayout(forCharacterRange: NSRange(location: 0, length: self.customTextStorage.length), actualCharacterRange: nil)
            self.customLayoutManager.ensureLayout(for: self.customTextContainer)
        }
        
        self.updateTextElements()
    }
    
    public func textHeightForWidth(_ width: CGFloat, rightInset: CGFloat) -> CGFloat {
        let measureSize = CGSize(width: width, height: 1000000.0)
        
        if self.measurementTextStorage != self.attributedText || self.measurementTextContainer.size != measureSize || self.measurementTextContainer.rightInset != rightInset {
            self.measurementTextContainer.rightInset = rightInset
            self.measurementTextStorage.setAttributedString(self.attributedText ?? NSAttributedString())
            self.measurementTextContainer.size = measureSize
            self.measurementLayoutManager.invalidateLayout(forCharacterRange: NSRange(location: 0, length: self.measurementTextStorage.length), actualCharacterRange: nil)
            self.measurementLayoutManager.ensureLayout(for: self.measurementTextContainer)
        }
        
        let textSize = self.measurementLayoutManager.usedRect(for: self.measurementTextContainer).size
        
        return textSize.height + self.textContainerInset.top + self.textContainerInset.bottom
    }
    
    public func updateLayout(size: CGSize) {
        let measureSize = CGSize(width: size.width, height: 1000000.0)
        
        if self.textContainer.size != measureSize {
            self.textContainer.size = measureSize
            self.customLayoutManager.invalidateLayout(forCharacterRange: NSRange(location: 0, length: self.customTextStorage.length), actualCharacterRange: nil)
            self.customLayoutManager.ensureLayout(for: self.customTextContainer)
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
    
    public func updateTextElements() {
        var blockQuoteIndex = 0
        var validBlockQuotes: [Int] = []
        
        self.textStorage.enumerateAttribute(NSAttributedString.Key(rawValue: "Attribute__Blockquote"), in: NSRange(location: 0, length: self.textStorage.length), using: { value, range, _ in
            if let value = value as? ChatTextInputTextQuoteAttribute {
                let glyphRange = self.customLayoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
                if self.customLayoutManager.isValidGlyphIndex(glyphRange.location) && self.customLayoutManager.isValidGlyphIndex(glyphRange.location + glyphRange.length - 1) {
                } else {
                    return
                }
                
                let id = blockQuoteIndex
                
                let blockQuote: QuoteBackgroundView
                if let current = self.blockQuotes[id] {
                    blockQuote = current
                } else {
                    blockQuote = QuoteBackgroundView()
                    self.blockQuotes[id] = blockQuote
                    self.insertSubview(blockQuote, at: 0)
                }
                
                var boundingRect = self.customLayoutManager.boundingRect(forGlyphRange: glyphRange, in: self.customTextContainer)
                
                boundingRect = CGRect()
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
                    boundingRect.size.width = min(boundingRect.size.width, self.bounds.width - 18.0)
                }
                boundingRect.size.width = min(boundingRect.size.width, self.bounds.width)
                
                boundingRect.origin.y -= 4.0
                boundingRect.size.height += 8.0
                
                blockQuote.frame = boundingRect
                if let theme = self.theme {
                    blockQuote.update(value: value, size: boundingRect.size, theme: theme.quote)
                }
                
                validBlockQuotes.append(blockQuoteIndex)
                blockQuoteIndex += 1
            }
        })
        
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
        var result = super.caretRect(for: position)
        
        if "".isEmpty {
            return result
        }
        
        guard let textStorage = self.customLayoutManager.textStorage else {
            return result
        }
        let _ = textStorage
        
        let index = self.offset(from: self.beginningOfDocument, to: position)
        
        let glyphRange = self.customLayoutManager.glyphRange(forCharacterRange: NSMakeRange(index, 1), actualCharacterRange: nil)
        var boundingRect = self.customLayoutManager.boundingRect(forGlyphRange: glyphRange, in: self.customTextContainer)
        
        boundingRect.origin.y += 5.0
        
        result.origin.y = boundingRect.minY
        result.size.height = boundingRect.height
        
        return result
    }
    
    override public func selectionRects(for range: UITextRange) -> [UITextSelectionRect] {
        let sourceRects = super.selectionRects(for: range)
        
        var result: [UITextSelectionRect] = []
        for rect in sourceRects {
            var mappedRect = rect.rect
            //mappedRect.size.height = 10.0
            mappedRect.size.height += 0.0
            result.append(CustomTextSelectionRect(
                rect: mappedRect,
                writingDirection: rect.writingDirection,
                containsStart: rect.containsStart,
                containsEnd: rect.containsEnd,
                isVertical: rect.isVertical
            ))
        }
        
        return result
    }
    
    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let result = super.hitTest(point, with: event)
        return result
    }
}

private final class CustomTextSelectionRect: UITextSelectionRect {
    let rectValue: CGRect
    let writingDirectionValue: NSWritingDirection
    let containsStartValue: Bool
    let containsEndValue: Bool
    let isVerticalValue: Bool
    
    override var rect: CGRect {
        return self.rectValue
    }
    override var writingDirection: NSWritingDirection {
        return self.writingDirectionValue
    }
    override var containsStart: Bool {
        return self.containsStartValue
    }
    override var containsEnd: Bool {
        return self.containsEndValue
    }
    override var isVertical: Bool {
        return self.isVerticalValue
    }
    
    init(rect: CGRect, writingDirection: NSWritingDirection, containsStart: Bool, containsEnd: Bool, isVertical: Bool) {
        self.rectValue = rect
        self.writingDirectionValue = writingDirection
        self.containsStartValue = containsStart
        self.containsEndValue = containsEnd
        self.isVerticalValue = isVertical
    }
}

private let quoteIcon: UIImage = {
    return UIImage(bundleImageName: "Chat/Message/ReplyQuoteIcon")!.precomposed().withRenderingMode(.alwaysTemplate)
}()

private final class QuoteBackgroundView: UIView {
    private let backgroundView: MessageInlineBlockBackgroundView
    private let iconView: UIImageView
    
    private var theme: ChatInputTextView.Theme.Quote?
    
    override init(frame: CGRect) {
        self.backgroundView = MessageInlineBlockBackgroundView()
        self.iconView = UIImageView(image: quoteIcon)
        
        super.init(frame: frame)
        
        self.addSubview(self.backgroundView)
        self.addSubview(self.iconView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(value: ChatTextInputTextQuoteAttribute, size: CGSize, theme: ChatInputTextView.Theme.Quote) {
        if self.theme != theme {
            self.theme = theme
            
            self.iconView.tintColor = theme.foreground
        }
        
        self.iconView.frame = CGRect(origin: CGPoint(x: size.width - 4.0 - quoteIcon.size.width, y: 4.0), size: quoteIcon.size)
        
        var primaryColor: UIColor
        var secondaryColor: UIColor?
        var tertiaryColor: UIColor?
        let backgroundColor: UIColor?
        
        switch value.kind {
        case .quote:
            self.iconView.isHidden = false
            
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
