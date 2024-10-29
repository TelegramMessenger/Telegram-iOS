import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramPresentationData
import ChatPresentationInterfaceState
import ComponentFlow
import AvatarNode
import MultilineTextComponent
import PlainButtonComponent
import ComponentDisplayAdapters
import AccountContext
import TelegramCore
import BundleIconComponent
import ContextUI
import SwiftSignalKit

private final class ChatManagingBotTitlePanelComponent: Component {
    let context: AccountContext
    let theme: PresentationTheme
    let strings: PresentationStrings
    let insets: UIEdgeInsets
    let peer: EnginePeer
    let managesChat: Bool
    let isPaused: Bool
    let toggleIsPaused: () -> Void
    let openSettings: (UIView) -> Void

    init(
        context: AccountContext,
        theme: PresentationTheme,
        strings: PresentationStrings,
        insets: UIEdgeInsets,
        peer: EnginePeer,
        managesChat: Bool,
        isPaused: Bool,
        toggleIsPaused: @escaping () -> Void,
        openSettings: @escaping (UIView) -> Void
    ) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.insets = insets
        self.peer = peer
        self.managesChat = managesChat
        self.isPaused = isPaused
        self.toggleIsPaused = toggleIsPaused
        self.openSettings = openSettings
    }

    static func ==(lhs: ChatManagingBotTitlePanelComponent, rhs: ChatManagingBotTitlePanelComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings != rhs.strings {
            return false
        }
        if lhs.insets != rhs.insets {
            return false
        }
        if lhs.peer != rhs.peer {
            return false
        }
        if lhs.managesChat != rhs.managesChat {
            return false
        }
        if lhs.isPaused != rhs.isPaused {
            return false
        }
        return true
    }

    final class View: UIView {
        private let title = ComponentView<Empty>()
        private let text = ComponentView<Empty>()
        private var avatarNode: AvatarNode?
        private let actionButton = ComponentView<Empty>()
        private let settingsButton = ComponentView<Empty>()
        
        private var component: ChatManagingBotTitlePanelComponent?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: ChatManagingBotTitlePanelComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            
            let topInset: CGFloat = 6.0
            let bottomInset: CGFloat = 6.0
            let avatarDiameter: CGFloat = 36.0
            let avatarTextSpacing: CGFloat = 10.0
            let titleTextSpacing: CGFloat = 1.0
            let leftInset: CGFloat = component.insets.left + 12.0
            let rightInset: CGFloat = component.insets.right + 10.0
            let actionAndSettingsButtonsSpacing: CGFloat = 8.0
            
            let actionButtonSize = self.actionButton.update(
                transition: transition,
                component: AnyComponent(PlainButtonComponent(
                    content: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(string: component.isPaused ? component.strings.Chat_BusinessBotPanel_ActionStart : component.strings.Chat_BusinessBotPanel_ActionStop, font: Font.semibold(15.0), textColor: component.theme.list.itemCheckColors.foregroundColor))
                    )),
                    background: AnyComponent(RoundedRectangle(
                        color: component.theme.list.itemCheckColors.fillColor,
                        cornerRadius: nil
                    )),
                    effectAlignment: .center,
                    contentInsets: UIEdgeInsets(top: 5.0, left: 12.0, bottom: 5.0, right: 12.0),
                    action: { [weak self] in
                        guard let self, let component = self.component else {
                            return
                        }
                        component.toggleIsPaused()
                    },
                    animateAlpha: true,
                    animateScale: false,
                    animateContents: false
                )),
                environment: {},
                containerSize: CGSize(width: 150.0, height: 100.0)
            )
            
            let settingsButtonSize = self.settingsButton.update(
                transition: transition,
                component: AnyComponent(PlainButtonComponent(
                    content: AnyComponent(BundleIconComponent(
                        name: "Chat/Context Menu/Customize",
                        tintColor: component.theme.rootController.navigationBar.controlColor
                    )),
                    effectAlignment: .center,
                    minSize: CGSize(width: 1.0, height: 40.0),
                    contentInsets: UIEdgeInsets(top: 0.0, left: 2.0, bottom: 0.0, right: 2.0),
                    action: { [weak self] in
                        guard let self, let component = self.component else {
                            return
                        }
                        guard let settingsButtonView = self.settingsButton.view else {
                            return
                        }
                        component.openSettings(settingsButtonView)
                    },
                    animateAlpha: true,
                    animateScale: false,
                    animateContents: false
                )),
                environment: {},
                containerSize: CGSize(width: 150.0, height: 100.0)
            )
            
            var maxTextWidth: CGFloat = availableSize.width - leftInset - avatarDiameter - avatarTextSpacing - rightInset - settingsButtonSize.width - 8.0
            if component.managesChat {
                maxTextWidth -= actionButtonSize.width - actionAndSettingsButtonsSpacing
            }
            
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.peer.displayTitle(strings: component.strings, displayOrder: .firstLast), font: Font.semibold(16.0), textColor: component.theme.rootController.navigationBar.primaryTextColor))
                )),
                environment: {},
                containerSize: CGSize(width: maxTextWidth, height: 100.0)
            )
            let textValue: String
            if component.isPaused {
                textValue = component.strings.Chat_BusinessBotPanel_StatusPaused
            } else {
                textValue = component.managesChat ? component.strings.Chat_BusinessBotPanel_StatusManages : component.strings.Chat_BusinessBotPanel_StatusHasAccess
            }
            let textSize = self.text.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: textValue, font: Font.regular(15.0), textColor: component.theme.rootController.navigationBar.secondaryTextColor))
                )),
                environment: {},
                containerSize: CGSize(width: maxTextWidth, height: 100.0)
            )
            
            let size = CGSize(width: availableSize.width, height: topInset + titleSize.height + titleTextSpacing + textSize.height + bottomInset)
            
            let titleFrame = CGRect(origin: CGPoint(x: leftInset + avatarDiameter + avatarTextSpacing, y: topInset), size: titleSize)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    titleView.layer.anchorPoint = CGPoint()
                    self.addSubview(titleView)
                }
                titleView.bounds = CGRect(origin: CGPoint(), size: titleFrame.size)
                transition.setPosition(view: titleView, position: titleFrame.origin)
            }
            
            let textFrame = CGRect(origin: CGPoint(x: titleFrame.minX, y: titleFrame.maxY + titleTextSpacing), size: textSize)
            if let textView = self.text.view {
                if textView.superview == nil {
                    textView.layer.anchorPoint = CGPoint()
                    self.addSubview(textView)
                }
                textView.bounds = CGRect(origin: CGPoint(), size: textFrame.size)
                transition.setPosition(view: textView, position: textFrame.origin)
            }
            
            let avatarFrame = CGRect(origin: CGPoint(x: leftInset, y: floor((size.height - avatarDiameter) * 0.5)), size: CGSize(width: avatarDiameter, height: avatarDiameter))
            let avatarNode: AvatarNode
            if let current = self.avatarNode {
                avatarNode = current
            } else {
                avatarNode = AvatarNode(font: avatarPlaceholderFont(size: 15.0))
                self.avatarNode = avatarNode
                self.addSubview(avatarNode.view)
            }
            avatarNode.frame = avatarFrame
            avatarNode.updateSize(size: avatarFrame.size)
            avatarNode.setPeer(context: component.context, theme: component.theme, peer: component.peer)
            
            let settingsButtonFrame = CGRect(origin: CGPoint(x: availableSize.width - rightInset - settingsButtonSize.width, y: floor((size.height - settingsButtonSize.height) * 0.5)), size: settingsButtonSize)
            if let settingsButtonView = self.settingsButton.view {
                if settingsButtonView.superview == nil {
                    self.addSubview(settingsButtonView)
                }
                transition.setFrame(view: settingsButtonView, frame: settingsButtonFrame)
            }
            
            let actionButtonFrame = CGRect(origin: CGPoint(x: settingsButtonFrame.minX - actionAndSettingsButtonsSpacing - actionButtonSize.width, y: floor((size.height - actionButtonSize.height) * 0.5)), size: actionButtonSize)
            if let actionButtonView = self.actionButton.view {
                if actionButtonView.superview == nil {
                    self.addSubview(actionButtonView)
                }
                transition.setFrame(view: actionButtonView, frame: actionButtonFrame)
                transition.setAlpha(view: actionButtonView, alpha: component.managesChat ? 1.0 : 0.0)
            }
            
            return size
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

final class ChatManagingBotTitlePanelNode: ChatTitleAccessoryPanelNode {
    private let context: AccountContext
    private let separatorNode: ASDisplayNode
    private let content = ComponentView<Empty>()
    
    private var chatLocation: ChatLocation?
    private var theme: PresentationTheme?
    private var managingBot: ChatManagingBot?
    
    init(context: AccountContext) {
        self.context = context
        self.separatorNode = ASDisplayNode()
        self.separatorNode.isLayerBacked = true
        
        super.init()

        self.addSubnode(self.separatorNode)
    }
    
    private func toggleIsPaused() {
        guard let chatPeerId = self.chatLocation?.peerId else {
            return
        }
        
        let _ = self.context.engine.peers.toggleChatManagingBotIsPaused(chatId: chatPeerId)
    }
    
    private func openSettingsMenu(sourceView: UIView) {
        guard let interfaceInteraction = self.interfaceInteraction else {
            return
        }
        guard let chatController = interfaceInteraction.chatController() else {
            return
        }
        guard let chatPeerId = self.chatLocation?.peerId else {
            return
        }
        guard let managingBot = self.managingBot else {
            return
        }
            
        let strings = self.context.sharedContext.currentPresentationData.with { $0 }.strings
        
        var items: [ContextMenuItem] = []
        
        items.append(.action(ContextMenuActionItem(text: strings.Chat_BusinessBotPanel_Menu_RemoveBot, textColor: .destructive, icon: { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Clear"), color: theme.contextMenu.destructiveColor)
        }, action: { [weak self] _, a in
            a(.default)
            
            guard let self else {
                return
            }
            self.context.engine.peers.removeChatManagingBot(chatId: chatPeerId)
        })))
        if let url = managingBot.settingsUrl {
            items.append(.action(ContextMenuActionItem(text: strings.Chat_BusinessBotPanel_Menu_ManageBot, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Settings"), color: theme.contextMenu.primaryColor)
            }, action: { [weak self] _, a in
                a(.default)
                
                guard let self else {
                    return
                }
                let _ = (self.context.sharedContext.resolveUrl(context: self.context, peerId: nil, url: url, skipUrlAuth: false)
                |> deliverOnMainQueue).start(next: { [weak self] result in
                    guard let self else {
                        return
                    }
                    guard let chatController = interfaceInteraction.chatController() else {
                        return
                    }
                    self.context.sharedContext.openResolvedUrl(
                        result,
                        context: self.context,
                        urlContext: .generic,
                        navigationController: chatController.navigationController as? NavigationController,
                        forceExternal: false,
                        forceUpdate: false,
                        openPeer: { [weak self] peer, navigation in
                            guard let self, let chatController = interfaceInteraction.chatController() else {
                                return
                            }
                            guard let navigationController = chatController.navigationController as? NavigationController else {
                                return
                            }
                            switch navigation {
                            case let .chat(_, subject, peekData):
                                self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: self.context, chatLocation: .peer(peer), subject: subject, peekData: peekData))
                            case let .withBotStartPayload(botStart):
                                self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: self.context, chatLocation: .peer(peer), botStart: botStart, keepStack: .always))
                            case let .withAttachBot(attachBotStart):
                                self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: self.context, chatLocation: .peer(peer), attachBotStart: attachBotStart))
                            case let .withBotApp(botAppStart):
                                self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: self.context, chatLocation: .peer(peer), botAppStart: botAppStart))
                            case .info:
                                let _ = (self.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peer.id))
                                |> deliverOnMainQueue).start(next: { [weak self] peer in
                                    guard let self, let peer, let chatController = interfaceInteraction.chatController() else {
                                        return
                                    }
                                    guard let navigationController = chatController.navigationController as? NavigationController else {
                                        return
                                    }
                                    if let controller = self.context.sharedContext.makePeerInfoController(context: self.context, updatedPresentationData: nil, peer: peer._asPeer(), mode: .generic, avatarInitiallyExpanded: false, fromChat: false, requestsContext: nil) {
                                        navigationController.pushViewController(controller)
                                    }
                                })
                            default:
                                break
                            }
                        },
                        sendFile: nil,
                        sendSticker: nil,
                        sendEmoji: nil,
                        requestMessageActionUrlAuth: nil,
                        joinVoiceChat: nil,
                        present: { [weak chatController] c, a in
                            chatController?.present(c, in: .window(.root), with: a)
                        },
                        dismissInput: {
                        },
                        contentContext: nil,
                        progress: nil,
                        completion: nil
                    )
                })
            })))
        }
        
        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        let contextController = ContextController(presentationData: presentationData, source: .reference(HeaderContextReferenceContentSource(controller: chatController, sourceView: sourceView)), items: .single(ContextController.Items(content: .list(items))), gesture: nil)
        interfaceInteraction.presentController(contextController, nil)
    }
    
    override func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState) -> LayoutResult {
        self.chatLocation = interfaceState.chatLocation
        self.managingBot = interfaceState.contactStatus?.managingBot
        
        if interfaceState.theme !== self.theme {
            self.theme = interfaceState.theme
            
            self.separatorNode.backgroundColor = interfaceState.theme.rootController.navigationBar.separatorColor
        }

        transition.updateFrame(node: self.separatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: width, height: UIScreenPixel)))

        if let managingBot = interfaceState.contactStatus?.managingBot {
            let contentSize = self.content.update(
                transition: ComponentTransition(transition),
                component: AnyComponent(ChatManagingBotTitlePanelComponent(
                    context: self.context,
                    theme: interfaceState.theme,
                    strings: interfaceState.strings,
                    insets: UIEdgeInsets(top: 0.0, left: leftInset, bottom: 0.0, right: rightInset),
                    peer: managingBot.bot,
                    managesChat: managingBot.canReply || managingBot.isPaused,
                    isPaused: managingBot.isPaused,
                    toggleIsPaused: { [weak self] in
                        guard let self else {
                            return
                        }
                        self.toggleIsPaused()
                    },
                    openSettings: { [weak self] sourceView in
                        guard let self else {
                            return
                        }
                        self.openSettingsMenu(sourceView: sourceView)
                    }
                )),
                environment: {},
                containerSize: CGSize(width: width, height: 1000.0)
            )
            if let contentView = self.content.view {
                if contentView.superview == nil {
                    self.view.addSubview(contentView)
                }
                transition.updateFrame(view: contentView, frame: CGRect(origin: CGPoint(), size: contentSize))
            }

            return LayoutResult(backgroundHeight: contentSize.height, insetHeight: contentSize.height, hitTestSlop: 0.0)
        } else {
            return LayoutResult(backgroundHeight: 0.0, insetHeight: 0.0, hitTestSlop: 0.0)
        }
        
    }
}

private final class HeaderContextReferenceContentSource: ContextReferenceContentSource {
    private let controller: ViewController
    private let sourceView: UIView

    init(controller: ViewController, sourceView: UIView) {
        self.controller = controller
        self.sourceView = sourceView
    }

    func transitionInfo() -> ContextControllerReferenceViewInfo? {
        return ContextControllerReferenceViewInfo(referenceView: self.sourceView, contentAreaInScreenSpace: UIScreen.main.bounds)
    }
}
