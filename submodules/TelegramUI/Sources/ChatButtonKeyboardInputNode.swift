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

private final class ChatButtonKeyboardInputButtonNode: ASButtonNode {
    var button: ReplyMarkupButton? {
        didSet {
            self.updateIcon()
        }
    }
    var iconNode: ASImageNode?
    
    private var theme: PresentationTheme?
    
    init(theme: PresentationTheme) {
        super.init()
        
        self.updateTheme(theme: theme)
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
    
    func updateTheme(theme: PresentationTheme) {
        if theme !== self.theme {
            self.theme = theme
            
            self.setBackgroundImage(PresentationResourcesChat.chatInputButtonPanelButtonImage(theme), for: [])
            self.setBackgroundImage(PresentationResourcesChat.chatInputButtonPanelButtonHighlightedImage(theme), for: [.highlighted])
            
            self.updateIcon()
        }
    }
    
    override func layout() {
        super.layout()
        
        if let iconNode = self.iconNode {
            iconNode.frame = CGRect(x: self.frame.width - 16.0, y: 4.0, width: 12.0, height: 12.0)
        }
    }
}

final class ChatButtonKeyboardInputNode: ChatInputNode {
    private let context: AccountContext
    private let controllerInteraction: ChatControllerInteraction
    
    private let separatorNode: ASDisplayNode
    private let scrollNode: ASScrollNode
    
    private var buttonNodes: [ChatButtonKeyboardInputButtonNode] = []
    private var message: Message?
    
    private var theme: PresentationTheme?
    
    init(context: AccountContext, controllerInteraction: ChatControllerInteraction) {
        self.context = context
        self.controllerInteraction = controllerInteraction
        
        self.scrollNode = ASScrollNode()
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.isLayerBacked = true
        
        super.init()
        
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
    
    override func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, standardInputHeight: CGFloat, inputHeight: CGFloat, maximumHeight: CGFloat, inputPanelHeight: CGFloat, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState, deviceMetrics: DeviceMetrics, isVisible: Bool) -> (CGFloat, CGFloat) {
        transition.updateFrame(node: self.separatorNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: width, height: UIScreenPixel)))
        
        let updatedTheme = self.theme !== interfaceState.theme
        if updatedTheme {
            self.theme = interfaceState.theme
            
            self.separatorNode.backgroundColor = interfaceState.theme.chat.inputButtonPanel.panelSeparatorColor
            self.backgroundColor = interfaceState.theme.chat.inputButtonPanel.panelBackgroundColor
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
                        buttonNode.updateTheme(theme: interfaceState.theme)
                    } else {
                        buttonNode = ChatButtonKeyboardInputButtonNode(theme: interfaceState.theme)
                        buttonNode.titleNode.maximumNumberOfLines = 2
                        buttonNode.addTarget(self, action: #selector(self.buttonPressed(_:)), forControlEvents: [.touchUpInside])
                        self.scrollNode.addSubnode(buttonNode)
                        self.buttonNodes.append(buttonNode)
                    }
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
                        
                        var peerId: PeerId?
                        if samePeer {
                            peerId = message.id.peerId
                        }
                        if let botPeer = botPeer, let addressName = botPeer.addressName {
                            self.controllerInteraction.openPeer(peerId, .chat(textInputState: ChatTextInputState(inputText: NSAttributedString(string: "@\(addressName) \(query)")), subject: nil, peekData: nil), nil, nil)
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
                    self.controllerInteraction.openPeer(peerId, .info, nil, nil)
                case let .openWebView(url, simple):
                    self.controllerInteraction.openWebView(markupButton.title, url, simple, false)
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
