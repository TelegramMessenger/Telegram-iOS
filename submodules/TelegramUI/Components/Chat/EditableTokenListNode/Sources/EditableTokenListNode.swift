import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import TelegramPresentationData
import AvatarNode
import AccountContext
import GlassBackgroundComponent
import ComponentFlow
import ComponentDisplayAdapters

public struct EditableTokenListToken {
    public enum Subject {
        case peer(EnginePeer)
        case category(UIImage?)
    }
    
    public let id: AnyHashable
    public let title: String
    public let fixedPosition: Int?
    public let subject: Subject

    public init(id: AnyHashable, title: String, fixedPosition: Int?, subject: Subject) {
        self.id = id
        self.title = title
        self.fixedPosition = fixedPosition
        self.subject = subject
    }
}

private func generateRemoveIcon(_ color: UIColor) -> UIImage? {
    return generateImage(CGSize(width: 22.0, height: 22.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: .zero, size: size))
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(2.0 - UIScreenPixel)
        context.setLineCap(.round)
        
        let length: CGFloat = 8.0
        context.move(to: CGPoint(x: 7.0, y: 7.0))
        context.addLine(to: CGPoint(x: 7.0 + length, y: 7.0 + length))
        context.strokePath()
        
        context.move(to: CGPoint(x: 7.0 + length, y: 7.0))
        context.addLine(to: CGPoint(x: 7.0, y: 7.0 + length))
        context.strokePath()
    })
}

private final class TokenNode: ASDisplayNode {
    private let context: AccountContext
    private let theme: PresentationTheme
    
    let token: EditableTokenListToken
    let avatarNode: AvatarNode
    let categoryAvatarNode: ASImageNode
    let removeIconNode: ASImageNode
    let titleNode: ASTextNode
    let backgroundNode: ASImageNode
    let selectedBackgroundNode: ASImageNode
    var isSelected: Bool = false
    
    init(context: AccountContext, theme: PresentationTheme, token: EditableTokenListToken, isSelected: Bool) {
        self.context = context
        self.theme = theme
        self.token = token
        self.titleNode = ASTextNode()
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.displaysAsynchronously = false
        self.titleNode.maximumNumberOfLines = 1
        
        self.avatarNode = AvatarNode(font: avatarPlaceholderFont(size: 13.0))
        self.categoryAvatarNode = ASImageNode()
        self.categoryAvatarNode.displaysAsynchronously = false
        self.categoryAvatarNode.displayWithoutProcessing = true
        
        self.removeIconNode = ASImageNode()
        self.removeIconNode.alpha = 0.0
        self.removeIconNode.displaysAsynchronously = false
        self.removeIconNode.displayWithoutProcessing = true
        self.removeIconNode.image = generateRemoveIcon(theme.list.itemCheckColors.foregroundColor)
        
        let cornerDiameter: CGFloat
        switch token.subject {
        case .peer:
            cornerDiameter = 28.0
        case .category:
            cornerDiameter = 14.0
        }
        
        self.backgroundNode = ASImageNode()
        self.backgroundNode.displaysAsynchronously = false
        self.backgroundNode.displayWithoutProcessing = true
        self.backgroundNode.image = generateStretchableFilledCircleImage(diameter: cornerDiameter, color: theme.list.itemCheckColors.strokeColor.withAlphaComponent(0.25))
        
        self.selectedBackgroundNode = ASImageNode()
        self.selectedBackgroundNode.alpha = 0.0
        self.selectedBackgroundNode.displaysAsynchronously = false
        self.selectedBackgroundNode.displayWithoutProcessing = true
        self.selectedBackgroundNode.image = generateStretchableFilledCircleImage(diameter: cornerDiameter, color: theme.list.itemCheckColors.fillColor)
                
        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.selectedBackgroundNode)
        self.titleNode.attributedText = NSAttributedString(string: token.title, font: Font.regular(15.0), textColor: self.isSelected ? self.theme.list.itemCheckColors.foregroundColor : self.theme.list.itemPrimaryTextColor)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.removeIconNode)
        
        switch token.subject {
        case let .peer(peer):
            self.addSubnode(self.avatarNode)
            self.avatarNode.setPeer(context: context, theme: theme, peer: peer)
        case let .category(image):
            self.addSubnode(self.categoryAvatarNode)
            self.categoryAvatarNode.image = image
        }
        
        self.updateIsSelected(isSelected, animated: false)
    }
    
    override func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        let titleSize = self.titleNode.measure(CGSize(width: constrainedSize.width - 8.0, height: constrainedSize.height))
        return CGSize(width: 22.0 + titleSize.width + 16.0, height: 28.0)
    }
    
    override func layout() {
        let titleSize = self.titleNode.calculatedSize
        if titleSize.width.isZero {
            return
        }
        self.backgroundNode.frame = self.bounds
        self.selectedBackgroundNode.frame = self.bounds
        self.avatarNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: self.bounds.height, height: self.bounds.height))
        self.categoryAvatarNode.frame = self.avatarNode.frame
        self.removeIconNode.frame = self.avatarNode.frame
        
        self.titleNode.frame = CGRect(origin: CGPoint(x: 29.0, y: floor((self.bounds.size.height - titleSize.height) / 2.0)), size: titleSize)
    }
    
    func updateIsSelected(_ isSelected: Bool, animated: Bool) {
        guard self.isSelected != isSelected else {
            return
        }
        self.isSelected = isSelected
        
        self.avatarNode.alpha = isSelected ? 0.0 : 1.0
        self.categoryAvatarNode.alpha = isSelected ? 0.0 : 1.0
        self.removeIconNode.alpha = isSelected ? 1.0 : 0.0
        
        if animated {
            if isSelected {
                self.selectedBackgroundNode.alpha = 1.0
                self.selectedBackgroundNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                
                self.avatarNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
                self.avatarNode.layer.animateScale(from: 1.0, to: 0.01, duration: 0.2)
                
                self.categoryAvatarNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
                self.categoryAvatarNode.layer.animateScale(from: 1.0, to: 0.01, duration: 0.2)
                
                self.removeIconNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                self.removeIconNode.layer.animateScale(from: 0.01, to: 1.0, duration: 0.2)
            } else {
                self.selectedBackgroundNode.alpha = 0.0
                self.selectedBackgroundNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
                
                self.avatarNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                self.avatarNode.layer.animateScale(from: 0.01, to: 1.0, duration: 0.2)
                
                self.categoryAvatarNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                self.categoryAvatarNode.layer.animateScale(from: 0.01, to: 1.0, duration: 0.2)
                
                self.removeIconNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
                self.removeIconNode.layer.animateScale(from: 1.0, to: 0.01, duration: 0.2)
            }
            
            if let snapshotView = self.titleNode.view.snapshotContentTree() {
                self.titleNode.view.superview?.addSubview(snapshotView)
                snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                    snapshotView?.removeFromSuperview()
                })
            }
            self.titleNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        } else {
            if isSelected {
                self.selectedBackgroundNode.alpha = 1.0
            } else {
                self.selectedBackgroundNode.alpha = 0.0
            }
        }
        
        self.titleNode.attributedText = NSAttributedString(string: token.title, font: Font.regular(15.0), textColor: self.isSelected ? self.theme.list.itemCheckColors.foregroundColor : self.theme.list.itemPrimaryTextColor)
        self.titleNode.redrawIfPossible()
    }
}

public final class EditableTokenListNode: ASDisplayNode, UITextFieldDelegate {
    private let context: AccountContext
    private let theme: PresentationTheme
    
    private let placeholder: String
    private let shortPlaceholder: String?
    
    private let backgroundContainer: GlassBackgroundContainerView
    private let backgroundView: GlassBackgroundView
    private let scrollNode: ASScrollNode
    private let placeholderNode: ASTextNode
    private var tokenNodes: [TokenNode] = []
    private let textFieldScrollNode: ASScrollNode
    private let textFieldNode: TextFieldNode
    private var selectedTokenId: AnyHashable?
    
    public var textUpdated: ((String) -> Void)?
    public var deleteToken: ((AnyHashable) -> Void)?
    public var textReturned: (() -> Void)?
    
    public init(context: AccountContext, theme: PresentationTheme, placeholder: String, shortPlaceholder: String? = nil) {
        self.context = context
        self.theme = theme
        
        self.placeholder = placeholder
        self.shortPlaceholder = shortPlaceholder

        self.backgroundContainer = GlassBackgroundContainerView()
        self.backgroundView = GlassBackgroundView()
        self.backgroundContainer.contentView.addSubview(self.backgroundView)
        
        self.scrollNode = ASScrollNode()
        self.scrollNode.view.alwaysBounceVertical = false
        self.scrollNode.clipsToBounds = true
        
        self.placeholderNode = ASTextNode()
        self.placeholderNode.isUserInteractionEnabled = false
        self.placeholderNode.maximumNumberOfLines = 1
        self.placeholderNode.attributedText = NSAttributedString(string: placeholder, font: Font.regular(15.0), textColor: theme.list.itemPlaceholderTextColor)
        
        self.textFieldScrollNode = ASScrollNode()
        
        self.textFieldNode = TextFieldNode()
        self.textFieldNode.textField.font = Font.regular(15.0)
        self.textFieldNode.textField.textColor = theme.list.itemPrimaryTextColor
        self.textFieldNode.textField.autocorrectionType = .no
        self.textFieldNode.textField.returnKeyType = .done
        self.textFieldNode.textField.keyboardAppearance = theme.rootController.keyboardColor.keyboardAppearance
        self.textFieldNode.textField.tintColor = theme.list.itemAccentColor
        
        super.init()
        
        self.view.addSubview(self.backgroundContainer)
        
        self.addSubnode(self.scrollNode)

        self.scrollNode.addSubnode(self.placeholderNode)
        self.scrollNode.addSubnode(self.textFieldScrollNode)
        self.textFieldScrollNode.addSubnode(self.textFieldNode)
        
        self.textFieldNode.textField.delegate = self
        self.textFieldNode.textField.addTarget(self, action: #selector(self.textFieldChanged(_:)), for: .editingChanged)
        self.textFieldNode.textField.didDeleteBackwardWhileEmpty = { [weak self] in
            if let strongSelf = self {
                if let selectedTokenId = strongSelf.selectedTokenId {
                    strongSelf.deleteToken?(selectedTokenId)
                    strongSelf.updateSelectedTokenId(nil)
                } else if let tokenNode = strongSelf.tokenNodes.last {
                    strongSelf.updateSelectedTokenId(tokenNode.token.id, animated: true)
                }
            }
        }
        
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
    }
    
    public func updateLayout(tokens: [EditableTokenListToken], width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition) -> CGFloat {
        let validTokens = Set<AnyHashable>(tokens.map { $0.id })
        
        var placeholderSnapshot: UIView?
        if let shortPlaceholder = self.shortPlaceholder {
            let previousPlaceholder = self.placeholderNode.attributedText?.string ?? ""
            let placeholder = validTokens.count > 0 ? shortPlaceholder : self.placeholder
            
            if !previousPlaceholder.isEmpty && placeholder != previousPlaceholder {
                placeholderSnapshot = self.placeholderNode.layer.snapshotContentTreeAsView()
                placeholderSnapshot?.frame = self.placeholderNode.frame
            }
            self.placeholderNode.attributedText = NSAttributedString(string: placeholder, font: Font.regular(15.0), textColor: self.theme.list.itemPlaceholderTextColor)
        }
        
        for i in (0 ..< self.tokenNodes.count).reversed() {
            let tokenNode = tokenNodes[i]
            if !validTokens.contains(tokenNode.token.id) {
                self.tokenNodes.remove(at: i)
                if case .immediate = transition {
                    tokenNode.removeFromSupernode()
                } else {
                    tokenNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak tokenNode] _ in
                        tokenNode?.removeFromSupernode()
                    })
                    tokenNode.layer.animateScale(from: 1.0, to: 0.2, duration: 0.2, removeOnCompletion: false)
                }
            }
        }
        
        if let selectedTokenId = self.selectedTokenId, !validTokens.contains(selectedTokenId) {
            self.selectedTokenId = nil
        }
        
        let sideInset: CGFloat = 12.0 + leftInset
        let verticalInset: CGFloat = 8.0
        
        var animationDelay = 0.0
        var currentOffset = CGPoint(x: sideInset, y: verticalInset)
        for token in tokens {
            var currentNode: TokenNode?
            for node in self.tokenNodes {
                if node.token.id == token.id {
                    currentNode = node
                    break
                }
            }
            let tokenNode: TokenNode
            var animateIn = false
            if let currentNode = currentNode {
                tokenNode = currentNode
            } else {
                tokenNode = TokenNode(context: self.context, theme: self.theme, token: token, isSelected: self.selectedTokenId != nil && token.id == self.selectedTokenId!)
                self.tokenNodes.append(tokenNode)
                self.scrollNode.addSubnode(tokenNode)
                animateIn = true
            }
            
            let tokenSize = tokenNode.measure(CGSize(width: max(1.0, width - sideInset - sideInset), height: CGFloat.greatestFiniteMagnitude))
            if tokenSize.width + currentOffset.x >= width - sideInset && !currentOffset.x.isEqual(to: sideInset) {
                currentOffset.x = sideInset
                currentOffset.y += tokenSize.height + 6.0
            }
            let tokenFrame = CGRect(origin: CGPoint(x: currentOffset.x, y: currentOffset.y), size: tokenSize)
            currentOffset.x += ceil(tokenSize.width) + 6.0
            
            if animateIn {
                tokenNode.frame = tokenFrame
                tokenNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                tokenNode.layer.animateSpring(from: 0.2 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.4)
            } else {
                if case .immediate = transition {
                    transition.updateFrame(node: tokenNode, frame: tokenFrame)
                } else {
                    let previousFrame = tokenNode.frame
                    if !previousFrame.origin.y.isEqual(to: tokenFrame.origin.y) && previousFrame.size.width.isEqual(to: tokenFrame.size.width) {
                        let initialStartPosition = CGPoint(x: previousFrame.midX, y: previousFrame.midY)
                        let initialEndPosition = CGPoint(x: previousFrame.midY > tokenFrame.midY ? -previousFrame.size.width / 2.0 : width, y: previousFrame.midY)
                        let targetStartPosition = CGPoint(x: (previousFrame.midY > tokenFrame.midY ? (width + tokenFrame.size.width) : -tokenFrame.size.width), y: tokenFrame.midY)
                        let targetEndPosition = CGPoint(x: tokenFrame.midX, y: tokenFrame.midY)
                        tokenNode.frame = tokenFrame
                        
                        let initialAnimation = tokenNode.layer.makeAnimation(from: NSValue(cgPoint: initialStartPosition), to: NSValue(cgPoint: initialEndPosition), keyPath: "position", timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, duration: 0.12, mediaTimingFunction: nil, removeOnCompletion: true, additive: false, completion: nil)
                        let targetAnimation = tokenNode.layer.makeAnimation(from: NSValue(cgPoint: targetStartPosition), to: NSValue(cgPoint: targetEndPosition), keyPath: "position", timingFunction: kCAMediaTimingFunctionSpring, duration: 0.2 + animationDelay, mediaTimingFunction: nil, removeOnCompletion: true, additive: false, completion: nil)
                        tokenNode.layer.animateGroup([initialAnimation, targetAnimation], key: "slide")
                        animationDelay += 0.025
                    } else {
                        if !previousFrame.size.width.isEqual(to: tokenFrame.size.width) {
                            tokenNode.frame = tokenFrame
                        } else {
                            let initialStartPosition = CGPoint(x: previousFrame.midX, y: previousFrame.midY)
                            let targetEndPosition = CGPoint(x: tokenFrame.midX, y: tokenFrame.midY)
                            tokenNode.frame = tokenFrame
                            
                            let targetAnimation = tokenNode.layer.makeAnimation(from: NSValue(cgPoint: initialStartPosition), to: NSValue(cgPoint: targetEndPosition), keyPath: "position", timingFunction: kCAMediaTimingFunctionSpring, duration: 0.2 + animationDelay, mediaTimingFunction: nil, removeOnCompletion: true, additive: false, completion: nil)
                            tokenNode.layer.animateGroup([targetAnimation], key: "slide")
                            animationDelay += 0.025
                        }
                    }
                }
            }
        }
        
        let placeholderSize = self.placeholderNode.measure(CGSize(width: max(1.0, width - sideInset - sideInset), height: CGFloat.greatestFiniteMagnitude))
        if width - currentOffset.x < placeholderSize.width {
            currentOffset.y += 28.0 + 6.0
            currentOffset.x = sideInset
        }
        
        let previousPlaceholderWidth = self.placeholderNode.bounds.width
        let placeholderFrame = CGRect(origin: CGPoint(x: currentOffset.x + 4.0, y: currentOffset.y + floor((28.0 - placeholderSize.height) / 2.0)), size: placeholderSize)
        self.placeholderNode.bounds = CGRect(origin: .zero, size: placeholderSize)
        transition.updatePosition(node: self.placeholderNode, position: placeholderFrame.center)
        
        if let placeholderSnapshot {
            self.placeholderNode.view.superview?.insertSubview(placeholderSnapshot, belowSubview: self.placeholderNode.view)
            self.placeholderNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
            placeholderSnapshot.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { _ in
                placeholderSnapshot.removeFromSuperview()
            })
            let delta = (placeholderSize.width - previousPlaceholderWidth) / 2.0
            transition.updatePosition(layer: placeholderSnapshot.layer, position: CGPoint(x: placeholderFrame.center.x - delta, y: placeholderFrame.center.y))
            transition.animatePositionAdditive(node: self.placeholderNode, offset: CGPoint(x: delta, y: 0.0))
        }
        
        let textNodeFrame = CGRect(origin: CGPoint(x: currentOffset.x + 4.0, y: currentOffset.y + UIScreenPixel), size: CGSize(width: width - currentOffset.x - sideInset - 8.0, height: 28.0))
        if case .immediate = transition {
            transition.updateFrame(node: self.textFieldScrollNode, frame: textNodeFrame)
            transition.updateFrame(node: self.textFieldNode, frame: CGRect(origin: CGPoint(), size: textNodeFrame.size))
        } else {
            let previousFrame = self.textFieldScrollNode.frame
            self.textFieldScrollNode.frame = textNodeFrame
            self.textFieldScrollNode.layer.animateFrame(from: previousFrame, to: textNodeFrame, duration: 0.2 + animationDelay, timingFunction: kCAMediaTimingFunctionSpring)
            
            transition.updateFrame(node: self.textFieldNode, frame: CGRect(origin: CGPoint(), size: textNodeFrame.size))
        }
        
        let previousContentHeight = self.scrollNode.view.contentSize.height
        let contentHeight = currentOffset.y + 28.0 + verticalInset
        let nodeHeight = min(contentHeight, 110.0)
        
        transition.updateFrame(node: self.scrollNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: width, height: nodeHeight)))
        transition.updateCornerRadius(node: self.scrollNode, cornerRadius: min(44.0, nodeHeight) * 0.5)
        self.scrollNode.view.scrollIndicatorInsets = UIEdgeInsets(top: 16.0, left: 0.0, bottom: 16.0, right: 0.0)
        
        if !abs(previousContentHeight - contentHeight).isLess(than: CGFloat.ulpOfOne) {
            let contentOffset = CGPoint(x: 0.0, y: max(0.0, contentHeight - nodeHeight))
            if self.scrollNode.view.contentOffset != contentOffset {
                if case .immediate = transition {
                    self.scrollNode.view.contentOffset = contentOffset
                } else {
                    //transition.animateOffsetAdditive(node: self.scrollNode, offset: self.scrollNode.view.contentOffset.y - contentOffset.y)
                }
            }
        }
        if self.scrollNode.view.contentSize != CGSize(width: width, height: contentHeight) {
            self.scrollNode.view.contentSize = CGSize(width: width, height: contentHeight)
        }

        let backgroundFrame = CGRect(origin: CGPoint(), size: CGSize(width: width, height: nodeHeight))
        self.backgroundContainer.update(size: backgroundFrame.size, isDark: self.theme.overallDarkAppearance, transition: ComponentTransition(transition))
        transition.updateFrame(view: self.backgroundContainer, frame: backgroundFrame)
        
        self.backgroundView.update(size: backgroundFrame.size, cornerRadius: min(44.0, backgroundFrame.height) * 0.5, isDark: self.theme.overallDarkAppearance, tintColor: .init(kind: .panel), isInteractive: true, transition: ComponentTransition(transition))
        transition.updateFrame(view: self.backgroundView, frame: CGRect(origin: CGPoint(), size: backgroundFrame.size))
        
        return nodeHeight
    }
    
    @objc private func textFieldChanged(_ textField: UITextField) {
        let text = textField.text ?? ""
        self.placeholderNode.isHidden = !text.isEmpty
        self.updateSelectedTokenId(nil)
        self.textUpdated?(text)
        if !text.isEmpty {
            self.scrollNode.view.scrollRectToVisible(textFieldScrollNode.frame.offsetBy(dx: 0.0, dy: 7.0), animated: true)
        }
    }
    
    public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.textReturned?()
        return false
    }
    
    public func textFieldDidBeginEditing(_ textField: UITextField) {
    }
    
    public func textFieldDidEndEditing(_ textField: UITextField) {
    }
    
    public func setText(_ text: String) {
        self.textFieldNode.textField.text = text
        self.textFieldChanged(self.textFieldNode.textField)
    }
    
    private func updateSelectedTokenId(_ id: AnyHashable?, animated: Bool = false) {
        self.selectedTokenId = id
        for tokenNode in self.tokenNodes {
            tokenNode.updateIsSelected(id == tokenNode.token.id, animated: animated)
        }
        if id != nil && !self.textFieldNode.textField.isFirstResponder {
            self.textFieldNode.textField.becomeFirstResponder()
        }
    }
    
    @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            let point = recognizer.location(in: self.view)
            for tokenNode in self.tokenNodes {
                let convertedPoint = self.view.convert(point, to: tokenNode.view)
                if tokenNode.bounds.contains(convertedPoint) {
                    if tokenNode.isSelected {
                        self.deleteToken?(tokenNode.token.id)
                    } else {
                        self.updateSelectedTokenId(tokenNode.token.id, animated: true)
                    }
                    break
                }
            }
        }
    }
}
