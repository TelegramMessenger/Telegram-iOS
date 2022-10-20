import Foundation
import UIKit
import SwiftSignalKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import ActivityIndicator
import AppBundle

private func generateLoupeIcon(color: UIColor) -> UIImage? {
    return generateTintedImage(image: UIImage(bundleImageName: "Components/Search Bar/Loupe"), color: color)
}

private func generateClearIcon(color: UIColor) -> UIImage? {
    return generateTintedImage(image: UIImage(bundleImageName: "Components/Search Bar/Clear"), color: color)
}

private func generateBackground(foregroundColor: UIColor, diameter: CGFloat) -> UIImage? {
    return generateImage(CGSize(width: diameter, height: diameter), contextGenerator: { size, context in
        context.setBlendMode(.copy)
        context.setFillColor(UIColor.clear.cgColor)
        context.fill(CGRect(origin: CGPoint(), size: size))
        context.setBlendMode(.normal)
        context.setFillColor(foregroundColor.cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
    }, opaque: false)?.stretchableImage(withLeftCapWidth: Int(diameter / 2.0), topCapHeight: Int(diameter / 2.0))
}

public struct SearchBarToken {
    public struct Style {
        public let backgroundColor: UIColor
        public let foregroundColor: UIColor
        public let strokeColor: UIColor
        
        public init(backgroundColor: UIColor, foregroundColor: UIColor, strokeColor: UIColor) {
            self.backgroundColor = backgroundColor
            self.foregroundColor = foregroundColor
            self.strokeColor = strokeColor
        }
    }
    
    public let id: AnyHashable
    public let icon: UIImage?
    public let iconOffset: CGFloat?
    public let title: String
    public let style: Style?
    public let permanent: Bool
    
    public init(id: AnyHashable, icon: UIImage?, iconOffset: CGFloat? = 0.0, title: String, style: Style? = nil, permanent: Bool) {
        self.id = id
        self.icon = icon
        self.iconOffset = iconOffset
        self.title = title
        self.style = style
        self.permanent = permanent
    }
}

private final class TokenNode: ASDisplayNode {
    var theme: SearchBarNodeTheme
    let token: SearchBarToken
    let containerNode: ASDisplayNode
    let iconNode: ASImageNode
    let titleNode: ASTextNode
    let backgroundNode: ASImageNode
    
    var isSelected: Bool = false
    var isCollapsed: Bool = false
    
    var tapped: (() -> Void)?
    
    init(theme: SearchBarNodeTheme, token: SearchBarToken) {
        self.theme = theme
        self.token = token
        self.containerNode = ASDisplayNode()
        self.containerNode.clipsToBounds = true
        self.iconNode = ASImageNode()
        self.iconNode.displaysAsynchronously = false
        self.iconNode.displayWithoutProcessing = true
        self.titleNode = ASTextNode()
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.displaysAsynchronously = false
        self.titleNode.maximumNumberOfLines = 1
        self.backgroundNode = ASImageNode()
        self.backgroundNode.displaysAsynchronously = false
        self.backgroundNode.displayWithoutProcessing = true
        
        super.init()
        
        self.clipsToBounds = true
        self.addSubnode(self.containerNode)
        self.containerNode.addSubnode(self.backgroundNode)
        
        let backgroundColor = token.style?.backgroundColor ?? theme.inputIcon
        let strokeColor = token.style?.strokeColor ?? backgroundColor
        self.backgroundNode.image = generateStretchableFilledCircleImage(diameter: 8.0, color: backgroundColor, strokeColor: strokeColor, strokeWidth: UIScreenPixel, backgroundColor: nil)
        
        let foregroundColor = token.style?.foregroundColor ?? .white
        self.iconNode.image = generateTintedImage(image: token.icon, color: foregroundColor)
        self.containerNode.addSubnode(self.iconNode)
        
        self.titleNode.attributedText = NSAttributedString(string: token.title, font: Font.regular(17.0), textColor: foregroundColor)
        self.containerNode.addSubnode(self.titleNode)
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture)))
    }
    
    @objc private func tapGesture() {
        
        self.tapped?()
    }
    
    func animateIn() {
        let targetFrame = self.containerNode.frame
        self.containerNode.layer.animateFrame(from: CGRect(origin: targetFrame.origin, size: CGSize(width: 1.0, height: targetFrame.height)), to: targetFrame, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
        self.backgroundNode.layer.animateFrame(from: CGRect(origin: targetFrame.origin, size: CGSize(width: 1.0, height: targetFrame.height)), to: targetFrame, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
        
        self.iconNode.layer.animateScale(from: 0.1, to: 1.0, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
        self.iconNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
        self.titleNode.layer.animateScale(from: 0.1, to: 1.0, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
        self.titleNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
    }
    
    func animateOut() {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, completion: { [weak self] _ in
            self?.removeFromSupernode()
        })
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3)
    }
    
    func update(theme: SearchBarNodeTheme, token: SearchBarToken, isSelected: Bool, isCollapsed: Bool) {
        let wasSelected = self.isSelected
        self.isSelected = isSelected
        self.isCollapsed = isCollapsed
        
        if theme !== self.theme || isSelected != wasSelected {
            let backgroundColor = isSelected ? self.theme.accent : (token.style?.backgroundColor ?? self.theme.inputIcon)
            let strokeColor = isSelected ? backgroundColor : (token.style?.strokeColor ?? backgroundColor)
            self.backgroundNode.image = generateStretchableFilledCircleImage(diameter: 8.0, color: backgroundColor, strokeColor: strokeColor, strokeWidth: UIScreenPixel, backgroundColor: nil)
            
            var foregroundColor = isSelected ? .white : (token.style?.foregroundColor ?? .white)
            if foregroundColor.distance(to: backgroundColor) < 1 {
                foregroundColor = .black
            }
            
            if let image = token.icon {
                self.iconNode.image = generateTintedImage(image: image, color: foregroundColor)
            }
            self.titleNode.attributedText = NSAttributedString(string: token.title, font: Font.regular(17.0), textColor: foregroundColor)
        }
    }
    
    func updateLayout(constrainedSize: CGSize, transition: ContainedViewLayoutTransition) -> CGSize {
        let height: CGFloat = 24.0
        
        var leftInset: CGFloat = 3.0
        if let icon = self.iconNode.image {
            leftInset += 1.0
            var iconFrame = CGRect(origin: CGPoint(x: leftInset, y: floor((height - icon.size.height) / 2.0)), size: icon.size)
            if let iconOffset = self.token.iconOffset {
                iconFrame.origin.x += iconOffset
            }
            transition.updateFrame(node: self.iconNode, frame: iconFrame)
            leftInset += icon.size.width + 3.0
        }

        let iconSize = self.token.icon?.size ?? CGSize()
        let titleSize = self.titleNode.measure(CGSize(width: constrainedSize.width - 6.0, height: constrainedSize.height))
        var width = titleSize.width + 6.0
        if !iconSize.width.isZero {
            width += iconSize.width + 7.0
        }
        
        let size = CGSize(width: self.isCollapsed ? height : width, height: height)
        transition.updateFrame(node: self.containerNode, frame: CGRect(origin: CGPoint(), size: size))
        transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(), size: size))
        transition.updateFrame(node: self.titleNode, frame: CGRect(origin: CGPoint(x: leftInset, y: floor((height - titleSize.height) / 2.0)), size: titleSize))
                    
        return size
    }
}

private class SearchBarTextField: UITextField, UIScrollViewDelegate {
    public var didDeleteBackward: (() -> Bool)?
    
    let placeholderLabel: ImmediateTextNode
    var placeholderString: NSAttributedString? {
        didSet {
            self.placeholderLabel.attributedText = self.placeholderString
            self.setNeedsLayout()
        }
    }
    
    var clippingNode: PassthroughContainerNode
    var tokenContainerNode: PassthroughContainerNode
    var tokenNodes: [AnyHashable: TokenNode] = [:]
    var tokens: [SearchBarToken] = [] {
        didSet {
            self._selectedTokenIndex = nil
            self.layoutTokens(transition: .animated(duration: 0.2, curve: .easeInOut))
            self.setNeedsLayout()
            self.updateCursorColor()
        }
    }
    
    var _selectedTokenIndex: Int?
    var selectedTokenIndex: Int? {
        get {
            return self._selectedTokenIndex
        }
        set {
            _selectedTokenIndex = newValue
            self.layoutTokens(transition: .animated(duration: 0.2, curve: .easeInOut))
            self.setNeedsLayout()
            self.updateCursorColor()
        }
    }
    
    private func updateCursorColor() {
        if self._selectedTokenIndex != nil {
            super.tintColor = UIColor.clear
        } else {
            super.tintColor = self._tintColor
        }
    }
    
    var _tintColor: UIColor = .black
    override var tintColor: UIColor! {
        get {
            return super.tintColor
        }
        set {
            if newValue != UIColor.clear {
                self._tintColor = newValue
                
                if self.selectedTokenIndex == nil {
                    super.tintColor = newValue
                }
            }
        }
    }
    
    var theme: SearchBarNodeTheme
    
    fileprivate func layoutTokens(transition: ContainedViewLayoutTransition = .immediate) {
        var hasSelected = false
        for i in 0 ..< self.tokens.count {
            let token = self.tokens[i]

            let tokenNode: TokenNode
            if let current = self.tokenNodes[token.id] {
                tokenNode = current
            } else {
                tokenNode = TokenNode(theme: self.theme, token: token)
                self.tokenNodes[token.id] = tokenNode
            }
            tokenNode.tapped = { [weak self] in
                if let strongSelf = self {
                    strongSelf.selectedTokenIndex = i
                    if !strongSelf.isFirstResponder {
                        let _ = strongSelf.becomeFirstResponder()
                    } else {
                        let newPosition = strongSelf.beginningOfDocument
                        strongSelf.selectedTextRange = strongSelf.textRange(from: newPosition, to: newPosition)
                    }
                }
            }
            let isSelected = i == self.selectedTokenIndex
            if i < self.tokens.count - 1 && isSelected {
                hasSelected = true
            }
            let isCollapsed = !isSelected && (token.permanent || (i < self.tokens.count - 1 || hasSelected))
            tokenNode.update(theme: self.theme, token: token, isSelected: isSelected, isCollapsed: isCollapsed)
        }
        var removeKeys: [AnyHashable] = []
        for (id, _) in self.tokenNodes {
            if !self.tokens.contains(where: { $0.id == id }) {
                removeKeys.append(id)
            }
        }
        for id in removeKeys {
            if let itemNode = self.tokenNodes.removeValue(forKey: id) {
                if transition.isAnimated {
                    itemNode.animateOut()
                } else {
                    itemNode.removeFromSupernode()
                }
            }
        }
        
        var tokenSizes: [(AnyHashable, CGSize, TokenNode, Bool)] = []
        var totalRawTabSize: CGFloat = 0.0
        
        for token in self.tokens {
            guard let tokenNode = self.tokenNodes[token.id] else {
                continue
            }
            let wasAdded = tokenNode.view.superview == nil
            var tokenNodeTransition = transition
            if wasAdded {
                tokenNodeTransition = .immediate
                self.tokenContainerNode.addSubnode(tokenNode)
            }
            
            let constrainedSize = CGSize(width: self.bounds.size.width - 90.0, height: self.bounds.size.height)
            let nodeSize = tokenNode.updateLayout(constrainedSize: constrainedSize, transition: tokenNodeTransition)
            tokenSizes.append((token.id, nodeSize, tokenNode, wasAdded))
            totalRawTabSize += nodeSize.width
        }
        
        let minSpacing: CGFloat = 6.0
        
        let resolvedSideInset: CGFloat = 0.0
        var leftOffset: CGFloat = 0.0
        if !tokenSizes.isEmpty {
            leftOffset += resolvedSideInset
        }
        
        var longTitlesWidth: CGFloat = resolvedSideInset
        for i in 0 ..< tokenSizes.count {
            let (_, paneNodeSize, _, _) = tokenSizes[i]
            longTitlesWidth += paneNodeSize.width
            if i != tokenSizes.count - 1 {
                longTitlesWidth += minSpacing
            }
        }
        longTitlesWidth += resolvedSideInset
        
        let verticalOffset: CGFloat = 0.0
        var horizontalOffset: CGFloat = 0.0
        for i in 0 ..< tokenSizes.count {
            let (_, nodeSize, tokenNode, wasAdded) = tokenSizes[i]
            let tokenNodeTransition = transition
                        
            let nodeFrame = CGRect(origin: CGPoint(x: leftOffset, y: floor((self.frame.height - nodeSize.height) / 2.0) + verticalOffset), size: nodeSize)
            
            if wasAdded {
                if horizontalOffset > 0.0 {
                    tokenNode.frame = nodeFrame.offsetBy(dx: horizontalOffset, dy: 0.0)
                    tokenNodeTransition.updatePosition(node: tokenNode, position: nodeFrame.center)
                } else {
                    tokenNode.frame = nodeFrame
                }
                tokenNode.animateIn()
            } else {
                if nodeFrame.width < tokenNode.frame.width {
                    horizontalOffset += tokenNode.frame.width - nodeFrame.width
                }
                tokenNodeTransition.updateFrame(node: tokenNode, frame: nodeFrame)
            }
            
            tokenNode.hitTestSlop = UIEdgeInsets(top: 0.0, left: -minSpacing / 2.0, bottom: 0.0, right: -minSpacing / 2.0)
                        
            leftOffset += nodeSize.width + minSpacing
        }
        
        if !tokenSizes.isEmpty {
            leftOffset += 4.0
        }
        
        let previousTokensWidth = self.tokensWidth
        self.tokensWidth = leftOffset
        self.tokenContainerNode.frame = CGRect(origin: self.tokenContainerNode.frame.origin, size: CGSize(width: self.tokensWidth, height: self.bounds.height))
        
        if let scrollView = self.scrollView {
            if scrollView.contentInset.left != leftOffset {
                scrollView.contentInset = UIEdgeInsets(top: 0.0, left: leftOffset, bottom: 0.0, right: 0.0)
            }
            if leftOffset.isZero {
                scrollView.contentOffset = CGPoint()
            } else if self.tokensWidth != previousTokensWidth {
                scrollView.contentOffset = CGPoint(x: -leftOffset, y: 0.0)
            }
            self.updateTokenContainerPosition(transition: transition)
        }
    }
    
    private var tokensWidth: CGFloat = 0.0
    
    private let measurePrefixLabel: ImmediateTextNode
    let prefixLabel: ImmediateTextNode
    var prefixString: NSAttributedString? {
        didSet {
            self.measurePrefixLabel.attributedText = self.prefixString
            self.prefixLabel.attributedText = self.prefixString
            self.setNeedsLayout()
        }
    }
    
    init(theme: SearchBarNodeTheme) {
        self.theme = theme
                
        self.placeholderLabel = ImmediateTextNode()
        self.placeholderLabel.isUserInteractionEnabled = false
        self.placeholderLabel.displaysAsynchronously = false
        self.placeholderLabel.maximumNumberOfLines = 1
        self.placeholderLabel.truncationMode = .byTruncatingTail
        
        self.measurePrefixLabel = ImmediateTextNode()
        self.measurePrefixLabel.isUserInteractionEnabled = false
        self.measurePrefixLabel.displaysAsynchronously = false
        self.measurePrefixLabel.maximumNumberOfLines = 1
        self.measurePrefixLabel.truncationMode = .byTruncatingTail
        
        self.prefixLabel = ImmediateTextNode()
        self.prefixLabel.isUserInteractionEnabled = false
        self.prefixLabel.displaysAsynchronously = false
        self.prefixLabel.maximumNumberOfLines = 1
        self.prefixLabel.truncationMode = .byTruncatingTail
        
        self.clippingNode = PassthroughContainerNode()
        self.clippingNode.clipsToBounds = true
        
        self.tokenContainerNode = PassthroughContainerNode()
        
        super.init(frame: CGRect())
        
        self.addSubnode(self.placeholderLabel)
        self.addSubnode(self.prefixLabel)
        self.addSubnode(self.clippingNode)
        self.clippingNode.addSubnode(self.tokenContainerNode)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func addSubview(_ view: UIView) {
        super.addSubview(view)
        
        if let scrollView = view as? UIScrollView {
            scrollView.delegate = self
            self.bringSubviewToFront(self.clippingNode.view)
        }
    }
    
    private weak var _scrollView: UIScrollView?
    var scrollView: UIScrollView? {
        if let scrollView = self._scrollView {
            return scrollView
        }
        for view in self.subviews {
            if let scrollView = view as? UIScrollView {
                _scrollView = scrollView
                return scrollView
            }
        }
        return nil
    }
    
    var fixAutoScroll: CGPoint?
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if let fixAutoScroll = self.fixAutoScroll {
            self.scrollView?.setContentOffset(fixAutoScroll, animated: true)
            self.scrollView?.setContentOffset(fixAutoScroll, animated: false)
            self.fixAutoScroll = nil
        } else {
            self.updateTokenContainerPosition()
        }
    }
    
    override func becomeFirstResponder() -> Bool {
        if let contentOffset = self.scrollView?.contentOffset {
            self.fixAutoScroll = contentOffset
            Queue.mainQueue().after(0.1) {
                self.fixAutoScroll = nil
            }
        }
        return super.becomeFirstResponder()
    }
    
    private func updateTokenContainerPosition(transition: ContainedViewLayoutTransition = .immediate) {
        if let scrollView = self.scrollView {
            transition.updateFrame(node: self.tokenContainerNode, frame: CGRect(origin: CGPoint(x: -scrollView.contentOffset.x - scrollView.contentInset.left, y: 0.0), size: self.tokenContainerNode.frame.size))
        }
    }
        
    override var keyboardAppearance: UIKeyboardAppearance {
        get {
            return super.keyboardAppearance
        }
        set {
            let resigning = self.isFirstResponder
            if resigning {
                self.resignFirstResponder()
            }
            super.keyboardAppearance = newValue
            if resigning {
                let _ = self.becomeFirstResponder()
            }
        }
    }
    
    override func textRect(forBounds bounds: CGRect) -> CGRect {
        if bounds.size.width.isZero {
            return CGRect(origin: CGPoint(), size: CGSize())
        }
        var rect = bounds.insetBy(dx: 7.0, dy: 4.0)
        if #available(iOS 14.0, *) {
        } else {
            rect.origin.y += 1.0
        }
        let prefixSize = self.measurePrefixLabel.updateLayout(CGSize(width: floor(bounds.size.width * 0.7), height: bounds.size.height))
        if !prefixSize.width.isZero {
            let prefixOffset = prefixSize.width + 3.0
            rect.origin.x += prefixOffset
            rect.size.width -= prefixOffset
        }
        if !self.tokensWidth.isZero && self.scrollView?.superview == nil {
            var offset = self.tokensWidth
            if let scrollView = self.scrollView {
                offset = scrollView.contentOffset.x * -1.0
            }
            rect.origin.x += offset
            rect.size.width -= offset
         }
        rect.size.width = max(rect.size.width, 10.0)
        return rect
    }
    
    override func editingRect(forBounds bounds: CGRect) -> CGRect {
        return self.textRect(forBounds: bounds)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let bounds = self.bounds
        self.clippingNode.frame = CGRect(x: 10.0, y: 0.0, width: bounds.width - 20.0, height: bounds.height)
        
        if bounds.size.width.isZero {
            return
        }
        
        var textOffset: CGFloat = 1.0
        if bounds.height >= 36.0 {
            textOffset += 2.0
        }
        
        var placeholderOffset: CGFloat = 0.0
        if #available(iOS 14.0, *) {
            placeholderOffset = 1.0
        } else {
        }
        
        let textRect = self.textRect(forBounds: bounds)
        let labelSize = self.placeholderLabel.updateLayout(textRect.size)
        self.placeholderLabel.frame = CGRect(origin: CGPoint(x: textRect.minX, y: textRect.minY + textOffset + placeholderOffset), size: labelSize)
        
        let prefixSize = self.prefixLabel.updateLayout(CGSize(width: floor(bounds.size.width * 0.7), height: bounds.size.height))
        let prefixBounds = bounds.insetBy(dx: 4.0, dy: 4.0)
        self.prefixLabel.frame = CGRect(origin: CGPoint(x: prefixBounds.minX, y: prefixBounds.minY + textOffset + placeholderOffset), size: prefixSize)
    }
    
    override func deleteBackward() {
        var processed = false
        if let selectedRange = self.selectedTextRange {
            let cursorPosition = self.offset(from: self.beginningOfDocument, to: selectedRange.start)
            if cursorPosition == 0 && selectedRange.isEmpty && !self.tokens.isEmpty && self.selectedTokenIndex == nil {
                self.selectedTokenIndex = self.tokens.count - 1
                processed = true
            }
        }
        
        if !processed {
            processed = self.didDeleteBackward?() ?? false
        }
        if !processed {
            super.deleteBackward()
            
            if let scrollView = self.scrollView {
                if scrollView.contentSize.width <= scrollView.frame.width && scrollView.contentOffset.x > -scrollView.contentInset.left {
                    scrollView.contentOffset = CGPoint(x: max(scrollView.contentOffset.x - 5.0, -scrollView.contentInset.left), y: 0.0)
                    self.updateTokenContainerPosition()
                }
            }
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let _ = self.selectedTokenIndex {
            if let touch = touches.first, let gestureRecognizers = touch.gestureRecognizers {
                let point = touch.location(in: self.tokenContainerNode.view)
                for (_, tokenNode) in self.tokenNodes {
                    if tokenNode.frame.contains(point) {
                        super.touchesBegan(touches, with: event)
                        return
                    }
                }
                self.selectedTokenIndex = nil
                for gesture in gestureRecognizers {
                    if gesture is UITapGestureRecognizer, gesture.isEnabled {
                        gesture.isEnabled = false
                        gesture.isEnabled = true
                    }
                }
            }
        } else {
            super.touchesBegan(touches, with: event)
        }
    }
}

public final class SearchBarNodeTheme: Equatable {
    public let background: UIColor
    public let separator: UIColor
    public let inputFill: UIColor
    public let placeholder: UIColor
    public let primaryText: UIColor
    public let inputIcon: UIColor
    public let inputClear: UIColor
    public let accent: UIColor
    public let keyboard: PresentationThemeKeyboardColor
    
    public init(background: UIColor, separator: UIColor, inputFill: UIColor, primaryText: UIColor, placeholder: UIColor, inputIcon: UIColor, inputClear: UIColor, accent: UIColor, keyboard: PresentationThemeKeyboardColor) {
        self.background = background
        self.separator = separator
        self.inputFill = inputFill
        self.primaryText = primaryText
        self.placeholder = placeholder
        self.inputIcon = inputIcon
        self.inputClear = inputClear
        self.accent = accent
        self.keyboard = keyboard
    }
    
    public init(theme: PresentationTheme, hasBackground: Bool = true, hasSeparator: Bool = true, inline: Bool = false) {
        self.background = hasBackground ? theme.rootController.navigationBar.blurredBackgroundColor : .clear
        self.separator = hasSeparator ? theme.rootController.navigationBar.separatorColor : theme.rootController.navigationBar.blurredBackgroundColor
        
        var fillColor = theme.rootController.navigationSearchBar.inputFillColor
        if inline, fillColor.distance(to: theme.list.blocksBackgroundColor) < 100 {
            fillColor = fillColor.withMultipliedBrightnessBy(0.8)
        }
        self.inputFill = fillColor
        self.placeholder = theme.rootController.navigationSearchBar.inputPlaceholderTextColor
        self.primaryText = theme.rootController.navigationSearchBar.inputTextColor
        self.inputIcon = theme.rootController.navigationSearchBar.inputIconColor
        self.inputClear = theme.rootController.navigationSearchBar.inputClearButtonColor
        self.accent = theme.rootController.navigationSearchBar.accentColor
        self.keyboard = theme.rootController.keyboardColor
    }
    
    public static func ==(lhs: SearchBarNodeTheme, rhs: SearchBarNodeTheme) -> Bool {
        if lhs.background != rhs.background {
            return false
        }
        if lhs.separator != rhs.separator {
            return false
        }
        if lhs.inputFill != rhs.inputFill {
            return false
        }
        if lhs.placeholder != rhs.placeholder {
            return false
        }
        if lhs.primaryText != rhs.primaryText {
            return false
        }
        if lhs.inputIcon != rhs.inputIcon {
            return false
        }
        if lhs.inputClear != rhs.inputClear {
            return false
        }
        if lhs.accent != rhs.accent {
            return false
        }
        if lhs.keyboard != rhs.keyboard {
            return false
        }
        return true
    }
}

public enum SearchBarStyle {
    case modern
    case legacy
    
    var font: UIFont {
        switch self {
            case .modern:
                return Font.regular(17.0)
            case .legacy:
                return Font.regular(14.0)
        }
    }
    
    var cornerDiameter: CGFloat {
        switch self {
            case .modern:
                return 21.0
            case .legacy:
                return 14.0
        }
    }
    
    var height: CGFloat {
        switch self {
            case .modern:
                return 36.0
            case .legacy:
                return 28.0
        }
    }
    
    var padding: CGFloat {
        switch self {
            case .modern:
                return 10.0
            case .legacy:
                return 8.0
        }
    }
}

public class SearchBarNode: ASDisplayNode, UITextFieldDelegate {
    public var cancel: (() -> Void)?
    public var textUpdated: ((String, String?) -> Void)?
    public var textReturned: ((String) -> Void)?
    public var clearPrefix: (() -> Void)?
    public var clearTokens: (() -> Void)?
    public var focusUpdated: ((Bool) -> Void)?
    
    public var tokensUpdated: (([SearchBarToken]) -> Void)?
    
    private let backgroundNode: NavigationBackgroundNode
    private let separatorNode: ASDisplayNode
    private let textBackgroundNode: ASDisplayNode
    private var activityIndicator: ActivityIndicator?
    private let iconNode: ASImageNode
    private let textField: SearchBarTextField
    private let clearButton: HighlightableButtonNode
    private let cancelButton: HighlightableButtonNode
    
    public var placeholderString: NSAttributedString? {
        get {
            return self.textField.placeholderString
        } set(value) {
            self.textField.placeholderString = value
        }
    }
    
    public var tokens: [SearchBarToken] {
        get {
            return self.textField.tokens
        } set {
            self.textField.tokens = newValue
            self.updateIsEmpty(animated: true)
        }
    }
    
    public var prefixString: NSAttributedString? {
        get {
            return self.textField.prefixString
        } set(value) {
            let previous = self.prefixString
            let updated: Bool
            if let previous = previous, let value = value {
                updated = !previous.isEqual(to: value)
            } else {
                updated = (previous != nil) != (value != nil)
            }
            if updated {
                self.textField.prefixString = value
                self.textField.setNeedsLayout()
                self.updateIsEmpty()
            }
        }
    }
    
    public var text: String {
        get {
            return self.textField.text ?? ""
        } set(value) {
            if self.textField.text ?? "" != value {
                self.textField.text = value
                self.textFieldDidChange(self.textField)
            }
        }
    }
    
    public var activity: Bool = false {
        didSet {
            if self.activity != oldValue {
                if self.activity {
                    if self.activityIndicator == nil, let theme = self.theme {
                        let activityIndicator = ActivityIndicator(type: .custom(theme.inputIcon, 13.0, 1.0, false))
                        self.activityIndicator = activityIndicator
                        self.addSubnode(activityIndicator)
                        if let (boundingSize, leftInset, rightInset) = self.validLayout {
                            self.updateLayout(boundingSize: boundingSize, leftInset: leftInset, rightInset: rightInset, transition: .immediate)
                        }
                    }
                } else if let activityIndicator = self.activityIndicator {
                    self.activityIndicator = nil
                    activityIndicator.removeFromSupernode()
                }
                self.iconNode.isHidden = self.activity
            }
        }
    }
    
    public var hasCancelButton: Bool = true {
        didSet {
            self.cancelButton.isHidden = !self.hasCancelButton
            if let (boundingSize, leftInset, rightInset) = self.validLayout {
                self.updateLayout(boundingSize: boundingSize, leftInset: leftInset, rightInset: rightInset, transition: .immediate)
            }
        }
    }
    
    private var validLayout: (CGSize, CGFloat, CGFloat)?
    
    private let fieldStyle: SearchBarStyle
    private let forceSeparator: Bool
    private var theme: SearchBarNodeTheme?
    private var strings: PresentationStrings?
    private let cancelText: String?
    
    public init(theme: SearchBarNodeTheme, strings: PresentationStrings, fieldStyle: SearchBarStyle = .legacy, forceSeparator: Bool = false, displayBackground: Bool = true, cancelText: String? = nil) {
        self.fieldStyle = fieldStyle
        self.forceSeparator = forceSeparator
        self.cancelText = cancelText
        
        self.backgroundNode = NavigationBackgroundNode(color: theme.background)
        self.backgroundNode.isUserInteractionEnabled = false
        self.backgroundNode.isHidden = !displayBackground
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.isLayerBacked = true
        
        self.textBackgroundNode = ASDisplayNode()
        self.textBackgroundNode.isLayerBacked = false
        self.textBackgroundNode.displaysAsynchronously = false
        self.textBackgroundNode.cornerRadius = self.fieldStyle.cornerDiameter / 2.0
        
        self.iconNode = ASImageNode()
        self.iconNode.isLayerBacked = true
        self.iconNode.displaysAsynchronously = false
        self.iconNode.displayWithoutProcessing = true
        
        self.textField = SearchBarTextField(theme: theme)
        self.textField.accessibilityTraits = .searchField
        self.textField.autocorrectionType = .no
        self.textField.returnKeyType = .search
        self.textField.font = self.fieldStyle.font
        
        self.clearButton = HighlightableButtonNode(pointerStyle: .lift)
        self.clearButton.imageNode.displaysAsynchronously = false
        self.clearButton.imageNode.displayWithoutProcessing = true
        self.clearButton.displaysAsynchronously = false
        
        self.cancelButton = HighlightableButtonNode(pointerStyle: .default)
        self.cancelButton.hitTestSlop = UIEdgeInsets(top: -8.0, left: -8.0, bottom: -8.0, right: -8.0)
        self.cancelButton.displaysAsynchronously = false
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.separatorNode)
        
        self.addSubnode(self.textBackgroundNode)
        self.view.addSubview(self.textField)
        self.addSubnode(self.iconNode)
        self.addSubnode(self.clearButton)
        self.addSubnode(self.cancelButton)
        
        self.textField.delegate = self
        self.textField.addTarget(self, action: #selector(self.textFieldDidChange(_:)), for: .editingChanged)
        
        self.textField.didDeleteBackward = { [weak self] in
            guard let strongSelf = self else {
                return false
            }
            if let index = strongSelf.textField.selectedTokenIndex {
                if !strongSelf.tokens[index].permanent {
                    strongSelf.tokens.remove(at: index)
                    strongSelf.tokensUpdated?(strongSelf.tokens)
                }
                return true
            } else if strongSelf.text.isEmpty {
                strongSelf.clearPressed()
                return true
            }
            return false
        }
        
        self.cancelButton.addTarget(self, action: #selector(self.cancelPressed), forControlEvents: .touchUpInside)
        self.clearButton.addTarget(self, action: #selector(self.clearPressed), forControlEvents: .touchUpInside)
        
        self.updateThemeAndStrings(theme: theme, strings: strings)
        self.updateIsEmpty(animated: false)
    }
        
    public func updateThemeAndStrings(theme: SearchBarNodeTheme, strings: PresentationStrings) {
        if self.theme != theme || self.strings !== strings {
            self.clearButton.accessibilityLabel = strings.WebSearch_RecentSectionClear
            self.cancelButton.accessibilityLabel = self.cancelText ?? strings.Common_Cancel
            self.cancelButton.setAttributedTitle(NSAttributedString(string: self.cancelText ?? strings.Common_Cancel, font: self.cancelText != nil ? Font.semibold(17.0) : Font.regular(17.0), textColor: theme.accent), for: [])
        }
        if self.theme != theme {
            self.backgroundNode.updateColor(color: theme.background, transition: .immediate) 
            if self.fieldStyle != .modern || self.forceSeparator {
                self.separatorNode.backgroundColor = theme.separator
            }
            self.textBackgroundNode.backgroundColor = theme.inputFill
            self.textField.textColor = theme.primaryText
            self.clearButton.setImage(generateClearIcon(color: theme.inputClear), for: [])
            self.iconNode.image = generateLoupeIcon(color: theme.inputIcon)
            self.textField.keyboardAppearance = theme.keyboard.keyboardAppearance
            self.textField.tintColor = theme.accent
            
            if let activityIndicator = self.activityIndicator {
                activityIndicator.type = .custom(theme.inputIcon, 13.0, 1.0, false)
            }
        }
        
        self.theme = theme
        self.strings = strings
        if let (boundingSize, leftInset, rightInset) = self.validLayout {
            self.updateLayout(boundingSize: boundingSize, leftInset: leftInset, rightInset: rightInset, transition: .immediate)
        }
    }
    
    public func updateLayout(boundingSize: CGSize, leftInset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition) {
        self.validLayout = (boundingSize, leftInset, rightInset)
        
        self.backgroundNode.frame = self.bounds
        self.backgroundNode.update(size: self.backgroundNode.bounds.size, transition: .immediate)
        transition.updateFrame(node: self.separatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: self.bounds.size.height), size: CGSize(width: self.bounds.size.width, height: UIScreenPixel)))
        
        let verticalOffset: CGFloat = boundingSize.height - 82.0
        
        let contentFrame = CGRect(origin: CGPoint(x: leftInset, y: 0.0), size: CGSize(width: boundingSize.width - leftInset - rightInset, height: boundingSize.height))
        
        let textBackgroundHeight = self.fieldStyle.height
        let cancelButtonSize = self.cancelButton.measure(CGSize(width: 100.0, height: CGFloat.infinity))
        transition.updateFrame(node: self.cancelButton, frame: CGRect(origin: CGPoint(x: contentFrame.maxX - 10.0 - cancelButtonSize.width, y: verticalOffset + textBackgroundHeight + floorToScreenPixels((textBackgroundHeight - cancelButtonSize.height) / 2.0)), size: cancelButtonSize))
        
        let padding = self.fieldStyle.padding
        let textBackgroundFrame = CGRect(origin: CGPoint(x: contentFrame.minX + padding, y: verticalOffset + textBackgroundHeight), size: CGSize(width: contentFrame.width - padding * 2.0 - (self.hasCancelButton ? cancelButtonSize.width + 11.0 : 0.0), height: textBackgroundHeight))
        transition.updateFrame(node: self.textBackgroundNode, frame: textBackgroundFrame)
        
        let textFrame = CGRect(origin: CGPoint(x: textBackgroundFrame.minX + 24.0, y: textBackgroundFrame.minY), size: CGSize(width: max(1.0, textBackgroundFrame.size.width - 24.0 - 27.0), height: textBackgroundFrame.size.height))
        
        if let iconImage = self.iconNode.image {
            let iconSize = iconImage.size
            transition.updateFrame(node: self.iconNode, frame: CGRect(origin: CGPoint(x: textBackgroundFrame.minX + 5.0, y: textBackgroundFrame.minY + floor((textBackgroundFrame.size.height - iconSize.height) / 2.0) - UIScreenPixel), size: iconSize))
        }
        
        if let activityIndicator = self.activityIndicator {
            let indicatorSize = activityIndicator.measure(CGSize(width: 32.0, height: 32.0))
            transition.updateFrame(node: activityIndicator, frame: CGRect(origin: CGPoint(x: textBackgroundFrame.minX + 9.0 + UIScreenPixel, y: textBackgroundFrame.minY + floor((textBackgroundFrame.size.height - indicatorSize.height) / 2.0)), size: indicatorSize))
        }
        
        let clearSize = self.clearButton.measure(CGSize(width: 100.0, height: 100.0))
        transition.updateFrame(node: self.clearButton, frame: CGRect(origin: CGPoint(x: textBackgroundFrame.maxX - 6.0 - clearSize.width, y: textBackgroundFrame.minY + floor((textBackgroundFrame.size.height - clearSize.height) / 2.0)), size: clearSize))
        
        self.textField.frame = textFrame
    }
    
    @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            if let cancel = self.cancel {
                cancel()
            }
        }
    }
    
    public func activate() {
        if !self.textField.isFirstResponder {
            let _ = self.textField.becomeFirstResponder()
        }
    }
    
    public func animateIn(from node: SearchBarPlaceholderNode, duration: Double, timingFunction: String) {
        let initialTextBackgroundFrame = node.convert(node.backgroundNode.frame, to: self)
        
        let initialBackgroundFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: self.bounds.size.width, height: max(0.0, initialTextBackgroundFrame.maxY + 8.0)))
        if let fromBackgroundColor = node.backgroundColor, let toBackgroundColor = self.backgroundNode.backgroundColor {
            self.backgroundNode.layer.animate(from: fromBackgroundColor.cgColor, to: toBackgroundColor.cgColor, keyPath: "backgroundColor", timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, duration: duration * 0.7)
        } else {
            self.backgroundNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration)
        }
        self.backgroundNode.layer.animateFrame(from: initialBackgroundFrame, to: self.backgroundNode.frame, duration: duration, timingFunction: timingFunction)
        
        let initialSeparatorFrame = CGRect(origin: CGPoint(x: 0.0, y: max(0.0, initialTextBackgroundFrame.maxY + 8.0)), size: CGSize(width: self.bounds.size.width, height: UIScreenPixel))
        self.separatorNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration)
        self.separatorNode.layer.animateFrame(from: initialSeparatorFrame, to: self.separatorNode.frame, duration: duration, timingFunction: timingFunction)
        
        if let fromTextBackgroundColor = node.backgroundNode.backgroundColor, let toTextBackgroundColor = self.textBackgroundNode.backgroundColor {
            self.textBackgroundNode.layer.animate(from: fromTextBackgroundColor.cgColor, to: toTextBackgroundColor.cgColor, keyPath: "backgroundColor", timingFunction: timingFunction, duration: duration * 1.0)
        }
        self.textBackgroundNode.layer.animateFrame(from: initialTextBackgroundFrame, to: self.textBackgroundNode.frame, duration: duration, timingFunction: timingFunction)
        
        let textFieldFrame = self.textField.frame
        let initialLabelNodeFrame = CGRect(origin: node.labelNode.frame.offsetBy(dx: initialTextBackgroundFrame.origin.x - 7.0, dy: initialTextBackgroundFrame.origin.y - 8.0).origin, size: textFieldFrame.size)
        self.textField.layer.animateFrame(from: initialLabelNodeFrame, to: self.textField.frame, duration: duration, timingFunction: timingFunction)
        
        let iconFrame = self.iconNode.frame
        let initialIconFrame = CGRect(origin: node.iconNode.frame.offsetBy(dx: initialTextBackgroundFrame.origin.x, dy: initialTextBackgroundFrame.origin.y).origin, size: iconFrame.size)
        self.iconNode.layer.animateFrame(from: initialIconFrame, to: self.iconNode.frame, duration: duration, timingFunction: timingFunction)
        
        let cancelButtonFrame = self.cancelButton.frame
        self.cancelButton.layer.animatePosition(from: CGPoint(x: self.bounds.size.width + cancelButtonFrame.size.width / 2.0, y: initialTextBackgroundFrame.midY), to: self.cancelButton.layer.position, duration: duration, timingFunction: timingFunction)
        node.isHidden = true
    }
    
    public func deactivate(clear: Bool = true) {
        self.textField.resignFirstResponder()
        if clear {
            self.textField.text = nil
            self.textField.tokens = []
            self.textField.prefixString = nil
            self.textField.placeholderLabel.alpha = 1.0
        }
    }
    
    public func transitionOut(to node: SearchBarPlaceholderNode, transition: ContainedViewLayoutTransition, completion: @escaping () -> Void) {
        let targetTextBackgroundFrame = node.convert(node.backgroundNode.frame, to: self)
        
        let duration: Double = transition.isAnimated ? 0.5 : 0.0
        let timingFunction = kCAMediaTimingFunctionSpring
        
        node.isHidden = true
        self.clearButton.isHidden = true
        self.activityIndicator?.isHidden = true
        self.iconNode.isHidden = false
        self.textField.prefixString = nil
        self.textField.text = ""
        self.textField.layoutSubviews()
    
        var backgroundCompleted = false
        var separatorCompleted = false
        var textBackgroundCompleted = false
        let intermediateCompletion: () -> Void = { [weak node] in
            if backgroundCompleted && separatorCompleted && textBackgroundCompleted {
                completion()
                node?.isHidden = false
            }
        }
        
        let targetBackgroundFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: self.bounds.size.width, height: max(0.0, targetTextBackgroundFrame.maxY + 8.0)))
        if let toBackgroundColor = node.backgroundColor, let fromBackgroundColor = self.backgroundNode.backgroundColor {
            self.backgroundNode.layer.animate(from: fromBackgroundColor.cgColor, to: toBackgroundColor.cgColor, keyPath: "backgroundColor", timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, duration: duration * 0.5, removeOnCompletion: false)
        } else {
            self.backgroundNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration / 2.0, removeOnCompletion: false)
        }
        self.backgroundNode.layer.animateFrame(from: self.backgroundNode.frame, to: targetBackgroundFrame, duration: duration, timingFunction: timingFunction, removeOnCompletion: false, completion: { _ in
            backgroundCompleted = true
            intermediateCompletion()
        })
        
        let targetSeparatorFrame = CGRect(origin: CGPoint(x: 0.0, y: max(0.0, targetTextBackgroundFrame.maxY + 8.0)), size: CGSize(width: self.bounds.size.width, height: UIScreenPixel))
        self.separatorNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration / 2.0, removeOnCompletion: false)
        self.separatorNode.layer.animateFrame(from: self.separatorNode.frame, to: targetSeparatorFrame, duration: duration, timingFunction: timingFunction, removeOnCompletion: false, completion: { _ in
            separatorCompleted = true
            intermediateCompletion()
        })

        self.textBackgroundNode.isHidden = true
        
        if let accessoryComponentView = node.accessoryComponentView {
            let tempContainer = UIView()
            
            let accessorySize = accessoryComponentView.bounds.size
            tempContainer.frame = CGRect(origin: CGPoint(x: self.textBackgroundNode.frame.maxX - accessorySize.width - 4.0, y: floor((self.textBackgroundNode.frame.minY + self.textBackgroundNode.frame.height - accessorySize.height) / 2.0)), size: accessorySize)
            
            let targetTempContainerFrame = CGRect(origin: CGPoint(x: targetTextBackgroundFrame.maxX - accessorySize.width - 4.0, y: floor((targetTextBackgroundFrame.minY + 8.0 + targetTextBackgroundFrame.height - accessorySize.height) / 2.0)), size: accessorySize)
            
            tempContainer.layer.animateFrame(from: tempContainer.frame, to: targetTempContainerFrame, duration: duration, timingFunction: timingFunction, removeOnCompletion: false)
            
            accessoryComponentView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
            tempContainer.addSubview(accessoryComponentView)
            self.view.addSubview(tempContainer)
        }

        self.textBackgroundNode.layer.animateFrame(from: self.textBackgroundNode.frame, to: targetTextBackgroundFrame, duration: duration, timingFunction: timingFunction, removeOnCompletion: false, completion: { [weak node] _ in
            textBackgroundCompleted = true
            intermediateCompletion()
            
            if let node = node, let accessoryComponentContainer = node.accessoryComponentContainer, let accessoryComponentView = node.accessoryComponentView {
                accessoryComponentContainer.addSubview(accessoryComponentView)
            }
        })
        
        let transitionBackgroundNode = ASDisplayNode()
        transitionBackgroundNode.isLayerBacked = true
        transitionBackgroundNode.displaysAsynchronously = false
        transitionBackgroundNode.backgroundColor = node.backgroundNode.backgroundColor
        transitionBackgroundNode.cornerRadius = node.backgroundNode.cornerRadius
        self.insertSubnode(transitionBackgroundNode, aboveSubnode: self.textBackgroundNode)
        //transitionBackgroundNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration / 2.0, removeOnCompletion: false)
        transitionBackgroundNode.layer.animateFrame(from: self.textBackgroundNode.frame, to: targetTextBackgroundFrame, duration: duration, timingFunction: timingFunction, removeOnCompletion: false)
        
        let textFieldFrame = self.textField.frame
        let targetLabelNodeFrame = CGRect(origin: CGPoint(x: node.labelNode.frame.minX + targetTextBackgroundFrame.origin.x - 7.0, y: targetTextBackgroundFrame.minY + floorToScreenPixels((targetTextBackgroundFrame.size.height - textFieldFrame.size.height) / 2.0) - UIScreenPixel), size: textFieldFrame.size)
        self.textField.layer.animateFrame(from: self.textField.frame, to: targetLabelNodeFrame, duration: duration, timingFunction: timingFunction, removeOnCompletion: false)
        if #available(iOSApplicationExtension 10.0, iOS 10.0, *) {
            if let snapshot = node.labelNode.layer.snapshotContentTree() {
                snapshot.frame = CGRect(origin: self.textField.placeholderLabel.frame.origin.offsetBy(dx: 0.0, dy: UIScreenPixel), size: node.labelNode.frame.size)
                self.textField.layer.addSublayer(snapshot)
                snapshot.animateAlpha(from: 0.0, to: 1.0, duration: duration * 2.0 / 3.0, timingFunction: CAMediaTimingFunctionName.linear.rawValue)
                self.textField.placeholderLabel.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration, timingFunction: CAMediaTimingFunctionName.linear.rawValue, removeOnCompletion: false)
            }
        } else if let cachedLayout = node.labelNode.cachedLayout {
            let labelNode = TextNode()
            labelNode.isOpaque = false
            labelNode.isUserInteractionEnabled = false
            let labelLayout = TextNode.asyncLayout(labelNode)
            let (labelLayoutResult, labelApply) = labelLayout(TextNodeLayoutArguments(attributedString: self.placeholderString, backgroundColor: .clear, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: cachedLayout.size, alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            let _ = labelApply()
            
            self.textField.addSubnode(labelNode)
            labelNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration * 2.0 / 3.0, timingFunction: CAMediaTimingFunctionName.linear.rawValue)
            labelNode.frame = CGRect(origin: self.textField.placeholderLabel.frame.origin.offsetBy(dx: 0.0, dy: UIScreenPixel), size: labelLayoutResult.size)
            self.textField.placeholderLabel.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration, timingFunction: CAMediaTimingFunctionName.linear.rawValue, removeOnCompletion: false, completion: { _ in
                labelNode.removeFromSupernode()
            })
        }
        let iconFrame = self.iconNode.frame
        let targetIconFrame = CGRect(origin: node.iconNode.frame.offsetBy(dx: targetTextBackgroundFrame.origin.x, dy: targetTextBackgroundFrame.origin.y).origin, size: iconFrame.size)
        self.iconNode.image = node.iconNode.image
        self.iconNode.layer.animateFrame(from: self.iconNode.frame, to: targetIconFrame, duration: duration, timingFunction: timingFunction, removeOnCompletion: false)
        
        let cancelButtonFrame = self.cancelButton.frame
        self.cancelButton.layer.animatePosition(from: self.cancelButton.layer.position, to: CGPoint(x: self.bounds.size.width + cancelButtonFrame.size.width / 2.0, y: targetTextBackgroundFrame.midY), duration: duration, timingFunction: timingFunction, removeOnCompletion: false)
    }
    
    public func textFieldDidBeginEditing(_ textField: UITextField) {
        self.focusUpdated?(true)
    }
    
    public func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if let _ = self.textField.selectedTokenIndex {
            if !string.isEmpty {
                self.textField.selectedTokenIndex = nil
            }
            if string.range(of: " ") != nil {
                return false
            }
        }
        if string.range(of: "\n") != nil {
            return false
        }
        return true
    }
    
    public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.textField.resignFirstResponder()
        if let textReturned = self.textReturned {
            textReturned(textField.text ?? "")
        }
        return false
    }
    
    @objc private func textFieldDidChange(_ textField: UITextField) {
        self.updateIsEmpty()
        if let textUpdated = self.textUpdated {
            textUpdated(textField.text ?? "", textField.textInputMode?.primaryLanguage)
        }
    }
    
    public func textFieldDidEndEditing(_ textField: UITextField) {
        self.focusUpdated?(false)
        self.textField.selectedTokenIndex = nil
    }
    
    public func selectAll() {
        if !self.textField.isFirstResponder {
            let _ = self.textField.becomeFirstResponder()
        }
        self.textField.selectAll(nil)
    }
    
    public func selectLastToken() {
        if !self.textField.tokens.isEmpty {
            self.textField.selectedTokenIndex = self.textField.tokens.count - 1
            if !self.textField.isFirstResponder {
                let _ = self.textField.becomeFirstResponder()
            }
        }
    }
    
    private func updateIsEmpty(animated: Bool = false) {
        let isEmpty = (self.textField.text?.isEmpty ?? true) && self.tokens.isEmpty

        let transition: ContainedViewLayoutTransition = animated ? .animated(duration: 0.3, curve: .spring) : .immediate
        let placeholderTransition = !isEmpty ? .immediate : transition
        placeholderTransition.updateAlpha(node: self.textField.placeholderLabel, alpha: isEmpty ? 1.0 : 0.0)

        let clearIsHidden = isEmpty && self.prefixString == nil
        transition.updateAlpha(node: self.clearButton.imageNode, alpha: clearIsHidden ? 0.0 : 1.0)
        transition.updateTransformScale(node: self.clearButton, scale: clearIsHidden ? 0.2 : 1.0)
        self.clearButton.isUserInteractionEnabled = !clearIsHidden
    }
    
    @objc private func cancelPressed() {
        self.cancel?()
    }
    
    @objc private func clearPressed() {
        if (self.textField.text?.isEmpty ?? true) {
            if self.prefixString != nil {
                self.clearPrefix?()
            }
            if !self.tokens.isEmpty {
                self.clearTokens?()
            }
        } else {
            self.textField.text = ""
            self.textFieldDidChange(self.textField)
        }
    }
}
