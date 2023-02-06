import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import AccountContext
import ChatPresentationInterfaceState
import WallpaperBackgroundNode
import ChatControllerInteraction
import ChatInputNode

private final class ChatButtonKeyboardInputButtonNode: HighlightTrackingButtonNode {
    var button: ReplyMarkupButton? {
        didSet {
            self.updateIcon()
        }
    }
        
    private let backgroundContainerNode: ASDisplayNode
    private var backgroundNode: WallpaperBubbleBackgroundNode?
    private let backgroundColorNode: ASDisplayNode
    private let backgroundAdditionalColorNode: ASDisplayNode
    
    private let shadowNode: ASImageNode
    private let highlightNode: ASImageNode
    
    private let textNode: ImmediateTextNode
    private var iconNode: ASImageNode?
    
    private var theme: PresentationTheme?
    
    init() {
        self.backgroundContainerNode = ASDisplayNode()
        self.backgroundContainerNode.clipsToBounds = true
        self.backgroundContainerNode.allowsGroupOpacity = true
        self.backgroundContainerNode.isUserInteractionEnabled = false
        self.backgroundContainerNode.cornerRadius = 5.0
        if #available(iOS 13.0, *) {
            self.backgroundContainerNode.layer.cornerCurve = .continuous
        }
        
        self.backgroundColorNode = ASDisplayNode()
        self.backgroundColorNode.cornerRadius = 5.0
        if #available(iOS 13.0, *) {
            self.backgroundColorNode.layer.cornerCurve = .continuous
        }
        
        self.backgroundAdditionalColorNode = ASDisplayNode()
        self.backgroundAdditionalColorNode.backgroundColor = UIColor(rgb: 0xffffff, alpha: 0.1)
        self.backgroundAdditionalColorNode.isHidden = true
        
        self.shadowNode = ASImageNode()
        self.shadowNode.isUserInteractionEnabled = false
        
        self.highlightNode = ASImageNode()
        self.highlightNode.isUserInteractionEnabled = false
        
        self.textNode = ImmediateTextNode()
        self.textNode.isUserInteractionEnabled = false
        self.textNode.textAlignment = .center
        self.textNode.maximumNumberOfLines = 2
        
        super.init()
        
        self.accessibilityTraits = [.button]
        
        self.addSubnode(self.backgroundContainerNode)
        
        self.backgroundContainerNode.addSubnode(self.backgroundColorNode)
        self.backgroundContainerNode.addSubnode(self.backgroundAdditionalColorNode)
        self.addSubnode(self.textNode)
        
        self.backgroundContainerNode.addSubnode(self.shadowNode)
        self.backgroundContainerNode.addSubnode(self.highlightNode)
                
        self.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted, !strongSelf.bounds.width.isZero {
                    let scale = (strongSelf.bounds.width - 10.0) / strongSelf.bounds.width
                    strongSelf.layer.animateScale(from: 1.0, to: scale, duration: 0.15, removeOnCompletion: false)
                    
                    strongSelf.backgroundContainerNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.backgroundContainerNode.alpha = 0.6
                } else if let presentationLayer = strongSelf.layer.presentation() {
                    strongSelf.layer.animateScale(from: CGFloat((presentationLayer.value(forKeyPath: "transform.scale.y") as? NSNumber)?.floatValue ?? 1.0), to: 1.0, duration: 0.25, removeOnCompletion: false)
                    
                    strongSelf.backgroundContainerNode.alpha = 1.0
                    strongSelf.backgroundContainerNode.layer.animateAlpha(from: 0.6, to: 1.0, duration: 0.2)
                }
            }
        }
    }
    
    override func setAttributedTitle(_ title: NSAttributedString, for state: UIControl.State) {
        self.textNode.attributedText = title
        self.accessibilityLabel = title.string
    }
    
    private var absoluteRect: (CGRect, CGSize)?
    func update(rect: CGRect, within containerSize: CGSize, transition: ContainedViewLayoutTransition) {
        self.absoluteRect = (rect, containerSize)
        
        if let backgroundNode = self.backgroundNode {
            var backgroundFrame = backgroundNode.frame
            backgroundFrame.origin.x += rect.minX
            backgroundFrame.origin.y += rect.minY
            backgroundNode.update(rect: backgroundFrame, within: containerSize, transition: transition)
        }
    }
    
    private func updateIcon() {
        guard let theme = self.theme else {
            return
        }
        var iconImage: UIImage?
        if let button = self.button {
            switch button.action {
                case .openWebView:
                    iconImage = PresentationResourcesChat.chatKeyboardActionButtonWebAppIconImage(theme)
                default:
                    iconImage = nil
            }
        }
        
        if iconImage != nil {
            if self.iconNode == nil {
                let iconNode = ASImageNode()
                iconNode.contentMode = .center
                self.iconNode = iconNode
                self.addSubnode(iconNode)
            }
            self.iconNode?.image = iconImage
        } else if let iconNode = self.iconNode {
            iconNode.removeFromSupernode()
            self.iconNode = nil
        }
        
        self.setNeedsLayout()
    }
    
    func updateTheme(theme: PresentationTheme, wallpaperBackgroundNode: WallpaperBackgroundNode?) {
        if theme !== self.theme {
            self.theme = theme
                        
            self.highlightNode.image = PresentationResourcesChat.chatInputButtonPanelButtonHighlightImage(theme)
            self.shadowNode.image = PresentationResourcesChat.chatInputButtonPanelButtonShadowImage(theme)
            
            self.updateIcon()
        }
        
        self.backgroundColorNode.backgroundColor = theme.chat.inputButtonPanel.buttonFillColor
        if let alpha = self.backgroundColorNode.backgroundColor?.alpha, alpha < 1.0 {
            self.backgroundColorNode.layer.compositingFilter = "softLightBlendMode"
            self.backgroundAdditionalColorNode.isHidden = false
        } else {
            self.backgroundColorNode.layer.compositingFilter = nil
            self.backgroundAdditionalColorNode.isHidden = true
        }
        
        if wallpaperBackgroundNode?.hasExtraBubbleBackground() == true {
            if self.backgroundNode == nil, let backgroundContent = wallpaperBackgroundNode?.makeBubbleBackground(for: .free) {
                self.backgroundNode = backgroundContent
                self.backgroundContainerNode.insertSubnode(backgroundContent, at: 0)
                
                self.setNeedsLayout()
            }
        } else {
            self.backgroundNode?.removeFromSupernode()
            self.backgroundNode = nil
        }
    }
    
    override func layout() {
        super.layout()
        
        self.backgroundContainerNode.frame = self.bounds
        self.backgroundColorNode.frame = CGRect(origin: .zero, size: CGSize(width: self.bounds.width, height: self.bounds.height - 1.0))
        self.backgroundAdditionalColorNode.frame = self.backgroundColorNode.frame
        self.backgroundNode?.frame = self.backgroundColorNode.frame
        
        self.highlightNode.frame = self.bounds
        self.shadowNode.frame = self.bounds
        
        if let (rect, containerSize) = self.absoluteRect {
            self.update(rect: rect, within: containerSize, transition: .immediate)
        }
        
        if let iconNode = self.iconNode {
            iconNode.frame = CGRect(x: self.frame.width - 16.0, y: 4.0, width: 12.0, height: 12.0)
        }
        
        let textSize = self.textNode.updateLayout(CGSize(width: self.bounds.width - 16.0, height: self.bounds.height))
        self.textNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((self.bounds.width - textSize.width) / 2.0), y: floorToScreenPixels((self.bounds.height - textSize.height) / 2.0)), size: textSize)
    }
}

final class ChatButtonKeyboardInputNode: ChatInputNode {
    private let context: AccountContext
    private let controllerInteraction: ChatControllerInteraction

    private let separatorNode: ASDisplayNode
    private let scrollNode: ASScrollNode

    private var backgroundNode: WallpaperBubbleBackgroundNode?
    private let backgroundColorNode: ASDisplayNode
    
    private var buttonNodes: [ChatButtonKeyboardInputButtonNode] = []
    private var message: Message?
    
    private var theme: PresentationTheme?
    
    init(context: AccountContext, controllerInteraction: ChatControllerInteraction) {
        self.context = context
        self.controllerInteraction = controllerInteraction
        
        self.scrollNode = ASScrollNode()
        
        self.backgroundColorNode = ASDisplayNode()
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.isLayerBacked = true
        
        super.init()
        
        self.addSubnode(self.backgroundColorNode)
        
        self.addSubnode(self.scrollNode)
        self.scrollNode.view.delaysContentTouches = false
        self.scrollNode.view.canCancelContentTouches = true
        self.scrollNode.view.alwaysBounceHorizontal = false
        self.scrollNode.view.alwaysBounceVertical = false
        
        self.addSubnode(self.separatorNode)
    }
    
    override func didLoad() {
        super.didLoad()
        
        if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
            self.scrollNode.view.contentInsetAdjustmentBehavior = .never
        }
    }
    
    private var absoluteRect: (CGRect, CGSize)?
    override func updateAbsoluteRect(_ rect: CGRect, within containerSize: CGSize, transition: ContainedViewLayoutTransition) {
        self.absoluteRect = (rect, containerSize)

        if let backgroundNode = self.backgroundNode {
            var backgroundFrame = backgroundNode.frame
            backgroundFrame.origin.x += rect.minX
            backgroundFrame.origin.y += rect.minY
            backgroundNode.update(rect: backgroundFrame, within: containerSize, transition: transition)
        }
        
        for buttonNode in self.buttonNodes {
            var buttonFrame = buttonNode.frame
            buttonFrame.origin.x += rect.minX
            buttonFrame.origin.y += rect.minY
            buttonNode.update(rect: buttonFrame, within: containerSize, transition: transition)
        }
    }
    
    override func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, standardInputHeight: CGFloat, inputHeight: CGFloat, maximumHeight: CGFloat, inputPanelHeight: CGFloat, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState, layoutMetrics: LayoutMetrics, deviceMetrics: DeviceMetrics, isVisible: Bool, isExpanded: Bool) -> (CGFloat, CGFloat) {
        transition.updateFrame(node: self.separatorNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: width, height: UIScreenPixel)))
        
        if self.backgroundNode == nil {
            if let backgroundNode = self.controllerInteraction.presentationContext.backgroundNode?.makeBubbleBackground(for: .free) {
                self.backgroundNode = backgroundNode
                self.insertSubnode(backgroundNode, at: 0)
            }
        }
        
        let updatedTheme = self.theme !== interfaceState.theme
        if updatedTheme {
            self.theme = interfaceState.theme
            
            self.separatorNode.backgroundColor = interfaceState.theme.chat.inputButtonPanel.panelSeparatorColor
            self.backgroundColorNode.backgroundColor = interfaceState.theme.chat.inputButtonPanel.panelBackgroundColor
        }
        
        var validatedMarkup: ReplyMarkupMessageAttribute?
        if let message = interfaceState.keyboardButtonsMessage {
            for attribute in message.attributes {
                if let replyMarkup = attribute as? ReplyMarkupMessageAttribute {
                    if !replyMarkup.rows.isEmpty {
                        validatedMarkup = replyMarkup
                    }
                    break
                }
            }
        }
        
        self.message = interfaceState.keyboardButtonsMessage
        
        if let markup = validatedMarkup {
            let verticalInset: CGFloat = 10.0
            let sideInset: CGFloat = 6.0 + leftInset
            var buttonHeight: CGFloat = 43.0
            let columnSpacing: CGFloat = 6.0
            let rowSpacing: CGFloat = 5.0
            
            var panelHeight = standardInputHeight
            
            let previousRowsHeight = self.scrollNode.view.contentSize.height
            let rowsHeight = verticalInset + CGFloat(markup.rows.count) * buttonHeight + CGFloat(max(0, markup.rows.count - 1)) * rowSpacing + verticalInset
            if !markup.flags.contains(.fit) && rowsHeight < panelHeight {
                buttonHeight = floor((panelHeight - bottomInset - verticalInset * 2.0 - CGFloat(max(0, markup.rows.count - 1)) * rowSpacing) / CGFloat(markup.rows.count))
            }
            
            var verticalOffset = verticalInset
            var buttonIndex = 0
            for row in markup.rows {
                let buttonWidth = floor(((width - sideInset - sideInset) + columnSpacing - CGFloat(row.buttons.count) * columnSpacing) / CGFloat(row.buttons.count))
                
                var columnIndex = 0
                for button in row.buttons {
                    let buttonNode: ChatButtonKeyboardInputButtonNode
                    if buttonIndex < self.buttonNodes.count {
                        buttonNode = self.buttonNodes[buttonIndex]
                    } else {
                        buttonNode = ChatButtonKeyboardInputButtonNode()
                        buttonNode.titleNode.maximumNumberOfLines = 2
                        buttonNode.addTarget(self, action: #selector(self.buttonPressed(_:)), forControlEvents: [.touchUpInside])
                        self.scrollNode.addSubnode(buttonNode)
                        self.buttonNodes.append(buttonNode)
                    }
                    buttonNode.updateTheme(theme: interfaceState.theme, wallpaperBackgroundNode: self.controllerInteraction.presentationContext.backgroundNode)
                    buttonIndex += 1
                    if buttonNode.button != button || updatedTheme {
                        buttonNode.button = button
                        buttonNode.setAttributedTitle(NSAttributedString(string: button.title, font: Font.regular(16.0), textColor: interfaceState.theme.chat.inputButtonPanel.buttonTextColor, paragraphAlignment: .center), for: [])
                    }
                    buttonNode.frame = CGRect(origin: CGPoint(x: sideInset + CGFloat(columnIndex) * (buttonWidth + columnSpacing), y: verticalOffset), size: CGSize(width: buttonWidth, height: buttonHeight))
                    columnIndex += 1
                }
                verticalOffset += buttonHeight + rowSpacing
            }
            
            for i in (buttonIndex ..< self.buttonNodes.count).reversed() {
                self.buttonNodes[i].removeFromSupernode()
                self.buttonNodes.remove(at: i)
            }
            
            if markup.flags.contains(.fit) {
                panelHeight = min(panelHeight + bottomInset, rowsHeight + bottomInset)
            }
            
            transition.updateFrame(node: self.scrollNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: width, height: panelHeight)))
            self.scrollNode.view.contentSize = CGSize(width: width, height: rowsHeight)
            self.scrollNode.view.contentInset = UIEdgeInsets(top: 0.0, left: 0.0, bottom: bottomInset, right: 0.0)
            if previousRowsHeight != rowsHeight {
                self.scrollNode.view.setContentOffset(CGPoint(), animated: false)
            }
            
            if let backgroundNode = self.backgroundNode {
                backgroundNode.frame = CGRect(origin: .zero, size: CGSize(width: width, height: panelHeight))
            }
            self.backgroundColorNode.frame = CGRect(origin: .zero, size: CGSize(width: width, height: panelHeight))
            
            if let (rect, containerSize) = self.absoluteRect {
                self.updateAbsoluteRect(rect, within: containerSize, transition: transition)
            }
            
            return (panelHeight, 0.0)
        } else {
            return (0.0, 0.0)
        }
    }
    
    @objc func buttonPressed(_ button: ASButtonNode) {
        if let button = button as? ChatButtonKeyboardInputButtonNode, let markupButton = button.button {
            var dismissIfOnce = false
            switch markupButton.action {
                case .text:
                    self.controllerInteraction.sendMessage(markupButton.title)
                    dismissIfOnce = true
                case let .url(url):
                    self.controllerInteraction.openUrl(url, true, nil, nil)
                case .requestMap:
                    self.controllerInteraction.shareCurrentLocation()
                case .requestPhone:
                    self.controllerInteraction.shareAccountContact()
                case .openWebApp:
                    if let message = self.message {
                        self.controllerInteraction.requestMessageActionCallback(message.id, nil, true, false)
                    }
                case let .callback(requiresPassword, data):
                    if let message = self.message {
                        self.controllerInteraction.requestMessageActionCallback(message.id, data, false, requiresPassword)
                    }
                case let .switchInline(samePeer, query):
                    if let message = message {
                        var botPeer: Peer?
                        
                        var found = false
                        for attribute in message.attributes {
                            if let attribute = attribute as? InlineBotMessageAttribute, let peerId = attribute.peerId {
                                botPeer = message.peers[peerId]
                                found = true
                            }
                        }
                        if !found {
                            botPeer = message.author
                        }
                        
                        var peer: Peer?
                        if samePeer {
                            peer = message.peers[message.id.peerId]
                        } else {
                            peer = botPeer
                        }
                        if let peer = peer, let botPeer = botPeer, let addressName = botPeer.addressName {
                            self.controllerInteraction.openPeer(EnginePeer(peer), .chat(textInputState: ChatTextInputState(inputText: NSAttributedString(string: "@\(addressName) \(query)")), subject: nil, peekData: nil), nil, .default)
                        }
                    }
                case .payment:
                    break
                case let .urlAuth(url, buttonId):
                    if let message = self.message {
                        self.controllerInteraction.requestMessageActionUrlAuth(url, .message(id: message.id, buttonId: buttonId))
                    }
                case let .setupPoll(isQuiz):
                    self.controllerInteraction.openPollCreation(isQuiz)
                case let .openUserProfile(peerId):
                    let _ = (self.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
                    |> deliverOnMainQueue).start(next: { [weak self] peer in
                        guard let self, let peer else {
                            return
                        }
                        self.controllerInteraction.openPeer(peer, .info, nil, .default)
                    })
                case let .openWebView(url, simple):
                    self.controllerInteraction.openWebView(markupButton.title, url, simple, false)
                case let .requestPeer(peerType, buttonId):
                    if let message = self.message {
                    self.controllerInteraction.openRequestedPeerSelection(message.id, peerType, buttonId)
                    }
            }
            if dismissIfOnce {
                if let message = self.message {
                    for attribute in message.attributes {
                        if let attribute = attribute as? ReplyMarkupMessageAttribute {
                            if attribute.flags.contains(.once) {
                                self.controllerInteraction.dismissReplyMarkupMessage(message)
                            }
                            break
                        }
                    }
                }
            }
        }
    }
}
