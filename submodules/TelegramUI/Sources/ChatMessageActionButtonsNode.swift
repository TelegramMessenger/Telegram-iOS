import Foundation
import UIKit
import AsyncDisplayKit
import TelegramCore
import SyncCore
import Postbox
import Display
import TelegramPresentationData
import AccountContext

private let titleFont = Font.medium(16.0)

private final class ChatMessageActionButtonNode: ASDisplayNode {
    private let backgroundNode: ASImageNode
    private var titleNode: TextNode?
    private var iconNode: ASImageNode?
    private var buttonView: HighlightTrackingButton?
    
    private var button: ReplyMarkupButton?
    var pressed: ((ReplyMarkupButton) -> Void)?
    var longTapped: ((ReplyMarkupButton) -> Void)?
    
    var longTapRecognizer: UILongPressGestureRecognizer?
    
    private let accessibilityArea: AccessibilityAreaNode
    
    override init() {
        self.backgroundNode = ASImageNode()
        self.backgroundNode.displayWithoutProcessing = true
        self.backgroundNode.displaysAsynchronously = false
        self.backgroundNode.isLayerBacked = true
        self.backgroundNode.alpha = 1.0
        self.backgroundNode.isUserInteractionEnabled = false
        
        self.accessibilityArea = AccessibilityAreaNode()
        self.accessibilityArea.accessibilityTraits = .button
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.accessibilityArea)
        
        self.accessibilityArea.activate = { [weak self] in
            self?.buttonPressed()
            return true
        }
    }
    
    override func didLoad() {
        super.didLoad()
        
        let buttonView = HighlightTrackingButton(frame: self.bounds)
        buttonView.addTarget(self, action: #selector(self.buttonPressed), for: [.touchUpInside])
        self.buttonView = buttonView
        buttonView.isAccessibilityElement = false
        self.view.addSubview(buttonView)
        buttonView.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.backgroundNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.backgroundNode.alpha = 0.55
                } else {
                    strongSelf.backgroundNode.alpha = 1.0
                    strongSelf.backgroundNode.layer.animateAlpha(from: 0.55, to: 1.0, duration: 0.2)
                }
            }
        }
        
        let longTapRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(self.longTapGesture(_:)))
        longTapRecognizer.minimumPressDuration = 0.3
        buttonView.addGestureRecognizer(longTapRecognizer)
        self.longTapRecognizer = longTapRecognizer
    }
    
    @objc func buttonPressed() {
        if let button = self.button, let pressed = self.pressed {
            pressed(button)
        }
    }
    
    @objc func longTapGesture(_ recognizer: UILongPressGestureRecognizer) {
        if let button = self.button, let longTapped = self.longTapped, recognizer.state == .began {
            longTapped(button)
        }
    }
    
    class func asyncLayout(_ maybeNode: ChatMessageActionButtonNode?) -> (_ context: AccountContext, _ theme: ChatPresentationThemeData, _ bubbleCorners: PresentationChatBubbleCorners, _ strings: PresentationStrings, _ message: Message, _ button: ReplyMarkupButton, _ constrainedWidth: CGFloat, _ position: MessageBubbleActionButtonPosition) -> (minimumWidth: CGFloat, layout: ((CGFloat) -> (CGSize, () -> ChatMessageActionButtonNode))) {
        let titleLayout = TextNode.asyncLayout(maybeNode?.titleNode)
        
        return { context, theme, bubbleCorners, strings, message, button, constrainedWidth, position in
            let incoming = message.effectivelyIncoming(context.account.peerId)
            let graphics = PresentationResourcesChat.additionalGraphics(theme.theme, wallpaper: theme.wallpaper, bubbleCorners: bubbleCorners)
            
            let iconImage: UIImage?
            switch button.action {
                case .text:
                    iconImage = incoming ? graphics.chatBubbleActionButtonIncomingMessageIconImage : graphics.chatBubbleActionButtonOutgoingMessageIconImage
                case .url, .urlAuth:
                    iconImage = incoming ? graphics.chatBubbleActionButtonIncomingLinkIconImage : graphics.chatBubbleActionButtonOutgoingLinkIconImage
                case .requestPhone:
                    iconImage = incoming ? graphics.chatBubbleActionButtonIncomingPhoneIconImage : graphics.chatBubbleActionButtonOutgoingLinkIconImage
                case .requestMap:
                    iconImage = incoming ? graphics.chatBubbleActionButtonIncomingLocationIconImage : graphics.chatBubbleActionButtonOutgoingLinkIconImage
                case .switchInline:
                    iconImage = incoming ? graphics.chatBubbleActionButtonIncomingShareIconImage : graphics.chatBubbleActionButtonOutgoingLinkIconImage
                default:
                    iconImage = nil
            }
            
            let sideInset: CGFloat = 8.0
            let minimumSideInset: CGFloat = 4.0 + (iconImage?.size.width ?? 0.0)
            
            var title = button.title
            if case .payment = button.action {
                for media in message.media {
                    if let invoice = media as? TelegramMediaInvoice {
                        if invoice.receiptMessageId != nil {
                            title = strings.Message_ReplyActionButtonShowReceipt
                        }
                    }
                }
            }
            
            let messageTheme = incoming ? theme.theme.chat.message.incoming : theme.theme.chat.message.outgoing
            let (titleSize, titleApply) = titleLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: title, font: titleFont, textColor:  bubbleVariableColor(variableColor: messageTheme.actionButtonsTextColor, wallpaper: theme.wallpaper)), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: max(44.0, constrainedWidth - minimumSideInset - minimumSideInset), height: CGFloat.greatestFiniteMagnitude), alignment: .center, cutout: nil, insets: UIEdgeInsets(top: 1.0, left: 0.0, bottom: 1.0, right: 0.0)))
            
            let backgroundImage: UIImage?
            switch position {
                case .middle:
                    backgroundImage = incoming ? graphics.chatBubbleActionButtonIncomingMiddleImage : graphics.chatBubbleActionButtonOutgoingMiddleImage
                case .bottomLeft:
                    backgroundImage = incoming ? graphics.chatBubbleActionButtonIncomingBottomLeftImage : graphics.chatBubbleActionButtonOutgoingBottomLeftImage
                case .bottomRight:
                    backgroundImage = incoming ? graphics.chatBubbleActionButtonIncomingBottomRightImage : graphics.chatBubbleActionButtonOutgoingBottomRightImage
                case .bottomSingle:
                    backgroundImage = incoming ? graphics.chatBubbleActionButtonIncomingBottomSingleImage : graphics.chatBubbleActionButtonOutgoingBottomSingleImage
            }
            
            return (titleSize.size.width + sideInset + sideInset, { width in
                return (CGSize(width: width, height: 42.0), {
                    let node: ChatMessageActionButtonNode
                    if let maybeNode = maybeNode {
                        node = maybeNode
                    } else {
                        node = ChatMessageActionButtonNode()
                    }
                    
                    node.button = button
                    
                    switch button.action {
                        case .url:
                            node.longTapRecognizer?.isEnabled = true
                        default:
                            node.longTapRecognizer?.isEnabled = false
                    }
                    
                    node.backgroundNode.image = backgroundImage
                    node.backgroundNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: max(0.0, width), height: 42.0))
                    
                    if iconImage != nil {
                        if node.iconNode == nil {
                            let iconNode = ASImageNode()
                            iconNode.contentMode = .center
                            node.iconNode = iconNode
                            node.addSubnode(iconNode)
                        }
                        node.iconNode?.image = iconImage
                    } else if node.iconNode != nil {
                        node.iconNode?.removeFromSupernode()
                        node.iconNode = nil
                    }
                    
                    let titleNode = titleApply()
                    if node.titleNode !== titleNode {
                        node.titleNode = titleNode
                        node.addSubnode(titleNode)
                        titleNode.isUserInteractionEnabled = false
                    }
                    titleNode.frame = CGRect(origin: CGPoint(x: floor((width - titleSize.size.width) / 2.0), y: floor((42.0 - titleSize.size.height) / 2.0) + 1.0), size: titleSize.size)
                    
                    
                    node.buttonView?.frame = CGRect(origin: CGPoint(), size: CGSize(width: width, height: 42.0))
                    node.iconNode?.frame = CGRect(x: width - 16.0, y: 4.0, width: 12.0, height: 12.0)
                    
                    node.accessibilityArea.accessibilityLabel = title
                    node.accessibilityArea.frame = CGRect(origin: CGPoint(), size: CGSize(width: width, height: 42.0))
                    
                    return node
                })
            })
        }
    }
}

final class ChatMessageActionButtonsNode: ASDisplayNode {
    private var buttonNodes: [ChatMessageActionButtonNode] = []
    
    private var buttonPressedWrapper: ((ReplyMarkupButton) -> Void)?
    private var buttonLongTappedWrapper: ((ReplyMarkupButton) -> Void)?
    var buttonPressed: ((ReplyMarkupButton) -> Void)?
    var buttonLongTapped: ((ReplyMarkupButton) -> Void)?
    
    override init() {
        super.init()
        
        self.buttonPressedWrapper = { [weak self] button in
            if let buttonPressed = self?.buttonPressed {
                buttonPressed(button)
            }
        }
        
        self.buttonLongTappedWrapper = { [weak self] button in
            if let buttonLongTapped = self?.buttonLongTapped {
                buttonLongTapped(button)
            }
        }
    }
    
    class func asyncLayout(_ maybeNode: ChatMessageActionButtonsNode?) -> (_ context: AccountContext, _ theme: ChatPresentationThemeData, _ chatBubbleCorners: PresentationChatBubbleCorners, _ strings: PresentationStrings, _ replyMarkup: ReplyMarkupMessageAttribute, _ message: Message, _ constrainedWidth: CGFloat) -> (minWidth: CGFloat, layout: (CGFloat) -> (CGSize, (_ animated: Bool) -> ChatMessageActionButtonsNode)) {
        let currentButtonLayouts = maybeNode?.buttonNodes.map { ChatMessageActionButtonNode.asyncLayout($0) } ?? []
        
        return { context, theme, chatBubbleCorners, strings, replyMarkup, message, constrainedWidth in
            let buttonHeight: CGFloat = 42.0
            let buttonSpacing: CGFloat = 4.0
            
            var overallMinimumRowWidth: CGFloat = 0.0
            
            var finalizeRowLayouts: [[((CGFloat) -> (CGSize, () -> ChatMessageActionButtonNode))]] = []
            
            var rowIndex = 0
            var buttonIndex = 0
            for row in replyMarkup.rows {
                var maximumRowButtonWidth: CGFloat = 0.0
                let maximumButtonWidth: CGFloat = max(1.0, floor((constrainedWidth - CGFloat(max(0, row.buttons.count - 1)) * buttonSpacing) / CGFloat(row.buttons.count)))
                var finalizeRowButtonLayouts: [((CGFloat) -> (CGSize, () -> ChatMessageActionButtonNode))] = []
                var rowButtonIndex = 0
                for button in row.buttons {
                    let buttonPosition: MessageBubbleActionButtonPosition
                    if rowIndex == replyMarkup.rows.count - 1 {
                        if row.buttons.count == 1 {
                            buttonPosition = .bottomSingle
                        } else if rowButtonIndex == 0 {
                            buttonPosition = .bottomLeft
                        } else if rowButtonIndex == row.buttons.count - 1 {
                            buttonPosition = .bottomRight
                        } else {
                            buttonPosition = .middle
                        }
                    } else {
                        buttonPosition = .middle
                    }
                    
                    let prepareButtonLayout: (minimumWidth: CGFloat, layout: ((CGFloat) -> (CGSize, () -> ChatMessageActionButtonNode)))
                    if buttonIndex < currentButtonLayouts.count {
                        prepareButtonLayout = currentButtonLayouts[buttonIndex](context, theme, chatBubbleCorners, strings, message, button, maximumButtonWidth, buttonPosition)
                    } else {
                        prepareButtonLayout = ChatMessageActionButtonNode.asyncLayout(nil)(context, theme, chatBubbleCorners, strings, message, button, maximumButtonWidth, buttonPosition)
                    }
                    
                    maximumRowButtonWidth = max(maximumRowButtonWidth, prepareButtonLayout.minimumWidth)
                    finalizeRowButtonLayouts.append(prepareButtonLayout.layout)
                    
                    buttonIndex += 1
                    rowButtonIndex += 1
                }
                
                overallMinimumRowWidth = max(overallMinimumRowWidth, maximumRowButtonWidth * CGFloat(row.buttons.count) + buttonSpacing * max(0.0, CGFloat(row.buttons.count - 1)))
                finalizeRowLayouts.append(finalizeRowButtonLayouts)
                
                rowIndex += 1
            }
            
            return (min(constrainedWidth, overallMinimumRowWidth), { constrainedWidth in
                var buttonFramesAndApply: [(CGRect, () -> ChatMessageActionButtonNode)] = []
                
                var verticalRowOffset: CGFloat = 0.0
                verticalRowOffset += buttonSpacing
                
                var rowIndex = 0
                for finalizeRowButtonLayouts in finalizeRowLayouts {
                    let actualButtonWidth: CGFloat = max(1.0, floor((constrainedWidth - CGFloat(max(0, finalizeRowButtonLayouts.count - 1)) * buttonSpacing) / CGFloat(finalizeRowButtonLayouts.count)))
                    var horizontalButtonOffset: CGFloat = 0.0
                    for finalizeButtonLayout in finalizeRowButtonLayouts {
                        let (buttonSize, buttonApply) = finalizeButtonLayout(actualButtonWidth)
                        let buttonFrame = CGRect(origin: CGPoint(x: horizontalButtonOffset, y: verticalRowOffset), size: buttonSize)
                        buttonFramesAndApply.append((buttonFrame, buttonApply))
                        horizontalButtonOffset += buttonSize.width + buttonSpacing
                    }
                    
                    verticalRowOffset += buttonHeight + buttonSpacing
                    rowIndex += 1
                }
                if verticalRowOffset > 0.0 {
                    verticalRowOffset = max(0.0, verticalRowOffset - buttonSpacing)
                }
                
                return (CGSize(width: constrainedWidth, height: verticalRowOffset), { animated in
                    let node: ChatMessageActionButtonsNode
                    if let maybeNode = maybeNode {
                        node = maybeNode
                    } else {
                        node = ChatMessageActionButtonsNode()
                    }
                    
                    var updatedButtons: [ChatMessageActionButtonNode] = []
                    var index = 0
                    for (buttonFrame, buttonApply) in buttonFramesAndApply {
                        let buttonNode = buttonApply()
                        buttonNode.frame = buttonFrame
                        updatedButtons.append(buttonNode)
                        if buttonNode.supernode == nil {
                            node.addSubnode(buttonNode)
                            buttonNode.pressed = node.buttonPressedWrapper
                            buttonNode.longTapped = node.buttonLongTappedWrapper
                        }
                        index += 1
                    }
                    
                    var buttonsUpdated = false
                    if node.buttonNodes.count != updatedButtons.count {
                        buttonsUpdated = true
                    } else {
                        for i in 0 ..< updatedButtons.count {
                            if updatedButtons[i] !== node.buttonNodes[i] {
                                buttonsUpdated = true
                                break
                            }
                        }
                    }
                    if buttonsUpdated {
                        for currentButton in node.buttonNodes {
                            if !updatedButtons.contains(currentButton) {
                                currentButton.removeFromSupernode()
                            }
                        }
                    }
                    node.buttonNodes = updatedButtons
                    
                    if animated {
                        /*UIView.transition(with: node.view, duration: 0.2, options: [.transitionCrossDissolve], animations: {
                            
                        }, completion: nil)*/
                    }
                    
                    return node
                })
            })
        }
    }
}
