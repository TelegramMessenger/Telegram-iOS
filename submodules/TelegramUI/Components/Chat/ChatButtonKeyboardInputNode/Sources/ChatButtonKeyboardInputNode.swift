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
import ComponentFlow
import ComponentDisplayAdapters
import GlassBackgroundComponent
import EmojiStatusComponent

private final class ChatButtonKeyboardInputButtonNode: HighlightTrackingButtonNode {
    private(set) var button: ReplyMarkupButton?
        
    private let backgroundContainerNode: ASDisplayNode
    private let backgroundView: UIImageView
    private var icon: ComponentView<Empty>?
    
    let tintMaskView: UIImageView
    
    private let textNode: ImmediateTextNode
    private var iconNode: ASImageNode?
    
    private var theme: PresentationTheme?
    
    init() {
        self.backgroundContainerNode = ASDisplayNode()
        self.backgroundContainerNode.allowsGroupOpacity = true
        self.backgroundContainerNode.isUserInteractionEnabled = false
        
        self.backgroundView = UIImageView()
        self.tintMaskView = UIImageView()
        
        self.textNode = ImmediateTextNode()
        self.textNode.isUserInteractionEnabled = false
        self.textNode.textAlignment = .center
        self.textNode.maximumNumberOfLines = 2
        
        super.init()
        
        self.accessibilityTraits = [.button]
        
        self.addSubnode(self.backgroundContainerNode)
        
        self.backgroundView.isUserInteractionEnabled = false
        self.backgroundContainerNode.view.addSubview(self.backgroundView)
        
        self.textNode.isUserInteractionEnabled = false
        self.addSubnode(self.textNode)
                
        self.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted, !strongSelf.bounds.width.isZero {
                    strongSelf.backgroundContainerNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.backgroundContainerNode.alpha = 0.9
                } else {
                    strongSelf.backgroundContainerNode.alpha = 1.0
                    strongSelf.backgroundContainerNode.layer.animateAlpha(from: 0.9, to: 1.0, duration: 0.2)
                }
            }
        }
    }
    
    func update(context: AccountContext, size: CGSize, theme: PresentationTheme, wallpaperBackgroundNode: WallpaperBackgroundNode?, button: ReplyMarkupButton, message: EngineMessage) {
        self.button = button
        
        if theme !== self.theme {
            self.theme = theme
        }
        
        if self.backgroundView.image == nil {
            self.backgroundView.image = generateStretchableFilledCircleImage(diameter: 20.0, color: .white)?.withRenderingMode(.alwaysTemplate)
            self.tintMaskView.image = self.backgroundView.image
        }
        self.tintMaskView.tintColor = .black
        
        var titleColor = theme.chat.inputButtonPanel.buttonTextColor
        
        if let color = button.style?.color {
            switch color {
            case .primary:
                self.backgroundView.tintColor = theme.list.itemCheckColors.fillColor
                titleColor = theme.list.itemCheckColors.foregroundColor
            case .danger:
                self.backgroundView.tintColor = UIColor(rgb: 0xFF3B30)
                titleColor = .white
            case .success:
                self.backgroundView.tintColor = UIColor(rgb: 0x21B246)
                titleColor = .white
            }
        } else {
            self.backgroundView.tintColor = theme.overallDarkAppearance ? UIColor(white: 1.0, alpha: 0.25) : UIColor(white: 1.0, alpha: 0.85)
        }
        
        let title = NSAttributedString(string: button.title, font: Font.regular(16.0), textColor: titleColor, paragraphAlignment: .center)
        
        self.textNode.attributedText = title
        self.accessibilityLabel = title.string
        
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
                iconNode.isUserInteractionEnabled = false
                self.addSubnode(iconNode)
            }
            self.iconNode?.image = iconImage
        } else if let iconNode = self.iconNode {
            iconNode.removeFromSupernode()
            self.iconNode = nil
        }
        
        self.backgroundContainerNode.frame = self.bounds
        self.backgroundView.frame = CGRect(origin: .zero, size: CGSize(width: self.bounds.width, height: self.bounds.height))
        
        if let iconNode = self.iconNode {
            iconNode.frame = CGRect(x: self.frame.width - 16.0, y: 4.0, width: 12.0, height: 12.0)
        }
        
        var maxTextWidth = size.width - 16.0
        let iconSize = CGSize(width: 24.0, height: 24.0)
        let iconSpacing: CGFloat = 6.0
        if let iconFileId = button.style?.iconFileId {
            let icon: ComponentView<Empty>
            if let current = self.icon {
                icon = current
            } else {
                icon = ComponentView()
                self.icon = icon
            }
            maxTextWidth -= iconSize.width + iconSpacing
            
            var animationContent: EmojiStatusComponent.AnimationContent = .customEmoji(fileId: iconFileId)
            if let file = message.associatedMedia[MediaId(namespace: Namespaces.Media.CloudFile, id: iconFileId)] as? TelegramMediaFile {
                animationContent = .file(file: file)
            }
            
            let _ = icon.update(
                transition: .immediate,
                component: AnyComponent(EmojiStatusComponent(
                    context: context,
                    animationCache: context.animationCache,
                    animationRenderer: context.animationRenderer,
                    content: .animation(
                        content: animationContent,
                        size: iconSize,
                        placeholderColor: theme.overallDarkAppearance ? UIColor(white: 1.0, alpha: 0.1) : UIColor(white: 0.0, alpha: 0.1),
                        themeColor: theme.list.itemPrimaryTextColor,
                        loopMode: .count(0)
                    ),
                    isVisibleForAnimations: true,
                    action: nil
                )),
                environment: {},
                containerSize: iconSize
            )
        } else if let icon = self.icon {
            self.icon = nil
            icon.view?.removeFromSuperview()
        }
        
        let textSize = self.textNode.updateLayout(CGSize(width: maxTextWidth, height: self.bounds.height))
        
        var textFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((self.bounds.width - textSize.width) / 2.0), y: floorToScreenPixels((self.bounds.height - textSize.height) / 2.0)), size: textSize)
        if let iconView = self.icon?.view {
            let contentX = floor((size.width - textSize.width - iconSize.width - iconSpacing) * 0.5)
            textFrame.origin.x = contentX + iconSize.width + iconSpacing
            
            let iconFrame = CGRect(origin: CGPoint(x: contentX, y: floor((size.height - iconSize.height) * 0.5)), size: iconSize)
            if iconView.superview == nil {
                iconView.isUserInteractionEnabled = false
                self.view.addSubview(iconView)
            }
            iconView.frame = iconFrame
        }
        
        self.textNode.frame = textFrame
    }
}

public final class ChatButtonKeyboardInputNode: ChatInputNode, UIScrollViewDelegate {
    private let context: AccountContext
    private let controllerInteraction: ChatControllerInteraction

    private let backgroundView: BlurredBackgroundView
    private let backgroundTintView: UIImageView
    private let backgroundTintMaskView: UIView
    private let backgroundChromeView: UIImageView
    
    private let scrollNode: ASScrollNode
    
    private var buttonNodes: [ChatButtonKeyboardInputButtonNode] = []
    private var message: Message?
    
    private var theme: PresentationTheme?
    
    public init(context: AccountContext, controllerInteraction: ChatControllerInteraction) {
        self.context = context
        self.controllerInteraction = controllerInteraction
        
        self.backgroundView = BlurredBackgroundView(color: .black, enableBlur: true)
        self.backgroundTintView = UIImageView()
        
        self.backgroundTintMaskView = UIView()
        self.backgroundTintMaskView.backgroundColor = .white
        
        self.backgroundChromeView = UIImageView()
        
        self.scrollNode = ASScrollNode()
        
        super.init()
        
        self.view.addSubview(self.backgroundView)
        
        self.view.addSubview(self.backgroundTintView)
        if let filter = CALayer.luminanceToAlpha() {
            self.backgroundTintMaskView.layer.filters = [filter]
            self.backgroundTintView.mask = self.backgroundTintMaskView
        }
        
        self.view.addSubview(self.backgroundChromeView)
        
        self.addSubnode(self.scrollNode)
        self.scrollNode.view.delaysContentTouches = false
        self.scrollNode.view.canCancelContentTouches = true
        self.scrollNode.view.alwaysBounceHorizontal = false
        self.scrollNode.view.alwaysBounceVertical = false
        self.scrollNode.view.delegate = self
        
        self.scrollNode.view.clipsToBounds = true
        self.scrollNode.cornerRadius = 30.0
        self.scrollNode.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        
        self.backgroundTintMaskView.clipsToBounds = true
        self.backgroundTintMaskView.layer.cornerRadius = 30.0
        self.backgroundTintMaskView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
    }
    
    override public func didLoad() {
        super.didLoad()
        
        if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
            self.scrollNode.view.contentInsetAdjustmentBehavior = .never
        }
    }
    
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        var bounds = self.backgroundTintMaskView.bounds
        bounds.origin.y = scrollView.contentOffset.y
        self.backgroundTintMaskView.bounds = bounds
    }
    
    override public func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, standardInputHeight: CGFloat, inputHeight: CGFloat, maximumHeight: CGFloat, inputPanelHeight: CGFloat, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState, layoutMetrics: LayoutMetrics, deviceMetrics: DeviceMetrics, isVisible: Bool, isExpanded: Bool) -> (CGFloat, CGFloat) {
        let updatedTheme = self.theme !== interfaceState.theme
        if updatedTheme {
            self.theme = interfaceState.theme
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
        
        if let markup = validatedMarkup, let message = self.message {
            let verticalInset: CGFloat = 18.0
            let sideInset: CGFloat = 18.0 + leftInset
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
                        self.backgroundTintMaskView.addSubview(buttonNode.tintMaskView)
                        self.buttonNodes.append(buttonNode)
                    }
                    buttonIndex += 1
                    let buttonFrame = CGRect(origin: CGPoint(x: sideInset + CGFloat(columnIndex) * (buttonWidth + columnSpacing), y: verticalOffset), size: CGSize(width: buttonWidth, height: buttonHeight))
                    buttonNode.frame = buttonFrame
                    buttonNode.tintMaskView.frame = buttonFrame
                    buttonNode.update(context: self.context, size: buttonFrame.size, theme: interfaceState.theme, wallpaperBackgroundNode: self.controllerInteraction.presentationContext.backgroundNode, button: button, message: EngineMessage(message))
                    columnIndex += 1
                }
                verticalOffset += buttonHeight + rowSpacing
            }
            
            for i in (buttonIndex ..< self.buttonNodes.count).reversed() {
                self.buttonNodes[i].removeFromSupernode()
                self.buttonNodes[i].tintMaskView.removeFromSuperview()
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
            
            var backgroundFrame = CGRect(origin: CGPoint(), size: CGSize(width: width, height: panelHeight))
            backgroundFrame.size.height += 32.0
            let keyboardCornerRadius: CGFloat = 30.0
            
            if self.backgroundChromeView.image == nil || updatedTheme {
                self.backgroundChromeView.image = GlassBackgroundView.generateForegroundImage(size: CGSize(width: keyboardCornerRadius * 2.0, height: keyboardCornerRadius * 2.0), isDark: interfaceState.theme.overallDarkAppearance, fillColor: .clear)
            }
            
            if self.backgroundTintView.image == nil {
                self.backgroundTintView.image = generateStretchableFilledCircleImage(diameter: keyboardCornerRadius * 2.0, color: .white)?.withRenderingMode(.alwaysTemplate)
            }
            self.backgroundTintView.tintColor = interfaceState.theme.chat.inputButtonPanel.panelBackgroundColor
            
            transition.updateFrame(view: self.backgroundView, frame: backgroundFrame)
            transition.updateFrame(view: self.backgroundTintView, frame: backgroundFrame)
            transition.updateFrame(view: self.backgroundTintMaskView, frame: CGRect(origin: CGPoint(), size: backgroundFrame.size))
            
            self.backgroundView.updateColor(color: .clear, forceKeepBlur: true, transition: .immediate)
            self.backgroundView.update(size: backgroundFrame.size, cornerRadius: keyboardCornerRadius, maskedCorners: [.layerMinXMinYCorner, .layerMaxXMinYCorner], transition: transition)
            
            transition.updateFrame(view: self.backgroundChromeView, frame: backgroundFrame.insetBy(dx: -1.0, dy: 0.0))
            
            return (panelHeight, 0.0)
        } else {
            return (0.0, 0.0)
        }
    }
    
    @objc private func buttonPressed(_ button: ASButtonNode) {
        if let button = button as? ChatButtonKeyboardInputButtonNode, let markupButton = button.button {
            var dismissIfOnce = false
            switch markupButton.action {
                case .text:
                    self.controllerInteraction.sendMessage(markupButton.title)
                    dismissIfOnce = true
                case let .url(url):
                    self.controllerInteraction.openUrl(ChatControllerInteraction.OpenUrl(url: url, concealed: true, progress: Promise()))
                case .requestMap:
                    self.controllerInteraction.shareCurrentLocation()
                case .requestPhone:
                    self.controllerInteraction.shareAccountContact()
                case .openWebApp:
                    if let message = self.message {
                        self.controllerInteraction.requestMessageActionCallback(message, nil, true, false, nil)
                    }
                case let .callback(requiresPassword, data):
                    if let message = self.message {
                        self.controllerInteraction.requestMessageActionCallback(message, data, false, requiresPassword, nil)
                    }
                case let .switchInline(samePeer, query, _):
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
                    |> deliverOnMainQueue).startStandalone(next: { [weak self] peer in
                        guard let self, let peer else {
                            return
                        }
                        self.controllerInteraction.openPeer(peer, .info(nil), nil, .default)
                    })
                case let .openWebView(url, simple):
                    self.controllerInteraction.openWebView(markupButton.title, url, simple, .generic)
                case let .requestPeer(peerType, buttonId, maxQuantity):
                    if let message = self.message {
                        self.controllerInteraction.openRequestedPeerSelection(message.id, peerType, buttonId, maxQuantity)
                    }
                case let .copyText(payload):
                    self.controllerInteraction.copyText(payload)
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
