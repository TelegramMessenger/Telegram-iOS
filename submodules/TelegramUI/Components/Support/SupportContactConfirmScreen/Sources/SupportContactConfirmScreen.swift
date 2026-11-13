import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import TelegramPresentationData
import AccountContext
import ComponentFlow
import ViewControllerComponent
import BundleIconComponent
import MultilineTextComponent
import ResizableSheetComponent
import ButtonComponent
import GlassBarButtonComponent
import WallpaperBackgroundNode

public final class SupportContactConfirmScreenParams {
    public let context: AccountContext
    public let presentationData: PresentationData
    public let theme: PresentationTheme
    public let wallpaper: TelegramWallpaper
    public let accountPeer: EnginePeer?
    public let text: String
    public let contact: TelegramMediaContact
    public let canSendWithoutSwitching: Bool

    public init(context: AccountContext, presentationData: PresentationData, theme: PresentationTheme, wallpaper: TelegramWallpaper, accountPeer: EnginePeer?, text: String, contact: TelegramMediaContact, canSendWithoutSwitching: Bool) {
        self.context = context
        self.presentationData = presentationData
        self.theme = theme
        self.wallpaper = wallpaper
        self.accountPeer = accountPeer
        self.text = text
        self.contact = contact
        self.canSendWithoutSwitching = canSendWithoutSwitching
    }
}

private let buttonHeight: CGFloat = 52.0
private let buttonSpacing: CGFloat = 8.0

private final class ContentComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let params: SupportContactConfirmScreenParams

    init(params: SupportContactConfirmScreenParams) {
        self.params = params
    }

    static func ==(lhs: ContentComponent, rhs: ContentComponent) -> Bool {
        return lhs.params === rhs.params
    }

    final class View: UIView {
        private let cardView = UIView()
        private let messagesContainer = UIView()
        private var backgroundNode: WallpaperBackgroundNode?
        private var messageNodes: [ListViewItemNode]?

        override init(frame: CGRect) {
            super.init(frame: frame)

            self.cardView.clipsToBounds = true
            self.cardView.layer.cornerRadius = 16.0
            self.cardView.isUserInteractionEnabled = false
            self.messagesContainer.layer.sublayerTransform = CATransform3DMakeScale(-1.0, -1.0, 1.0)
            self.cardView.addSubview(self.messagesContainer)
            self.addSubview(self.cardView)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        private func message(params: SupportContactConfirmScreenParams, id: Int32, text: String, media: [EngineMedia]) -> EngineMessage {
            let peerId = EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value(1))
            var peers: [EnginePeer.Id: EnginePeer] = [:]
            if let accountPeer = params.accountPeer {
                peers[accountPeer.id] = accountPeer
            }
            return EngineMessage(stableId: UInt32(id), stableVersion: 0, id: EngineMessage.Id(peerId: peerId, namespace: 0, id: id), globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: Int32(Date().timeIntervalSince1970), flags: [], tags: [], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: params.accountPeer, text: text, attributes: [], media: media, peers: peers, associatedMessages: [:], associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:])
        }

        private func updateMessages(params: SupportContactConfirmScreenParams, width: CGFloat, availableHeight: CGFloat) -> CGFloat {
            let presentationData = params.presentationData
            var messages: [EngineMessage] = [self.message(params: params, id: 1, text: "", media: [.contact(params.contact)])]
            if !params.text.isEmpty {
                messages.append(self.message(params: params, id: 2, text: params.text, media: []))
            }
            let items = messages.map { message -> ListViewItem in
                return params.context.sharedContext.makeChatMessagePreviewItem(context: params.context, messages: [message], theme: params.theme, strings: presentationData.strings, wallpaper: params.wallpaper, fontSize: presentationData.chatFontSize, chatBubbleCorners: presentationData.chatBubbleCorners, dateTimeFormat: presentationData.dateTimeFormat, nameOrder: presentationData.nameDisplayOrder, forcedResourceStatus: nil, tapMessage: nil, clickThroughMessage: nil, backgroundNode: self.backgroundNode, availableReactions: nil, accountPeer: nil, isCentered: false, isPreview: true, isStandalone: false, rank: nil, rankRole: nil, isGiftMessageComposerPreview: false, activateGiftMessageInput: nil)
            }
            let layoutParams = ListViewItemLayoutParams(width: width, leftInset: 0.0, rightInset: 0.0, availableHeight: availableHeight)
            let neighbors: (Int) -> ListViewItemNeighbors = { index in
                return ListViewItemNeighbors(previous: index == 0 ? nil : items[index - 1].neighborDescriptor, next: index == items.count - 1 ? nil : items[index + 1].neighborDescriptor)
            }
            if let messageNodes = self.messageNodes {
                for i in 0 ..< items.count {
                    let itemNode = messageNodes[i]
                    items[i].updateNode(async: { $0() }, node: {
                        return itemNode
                    }, params: layoutParams, neighbors: neighbors(i), animation: .None, completion: { layout, apply in
                        itemNode.contentSize = layout.contentSize
                        itemNode.insets = layout.insets
                        itemNode.frame = CGRect(origin: itemNode.frame.origin, size: layout.size)
                        apply(ListViewItemApply())
                    })
                }
            } else {
                var messageNodes: [ListViewItemNode] = []
                for i in 0 ..< items.count {
                    var itemNode: ListViewItemNode?
                    items[i].nodeConfiguredForParams(async: { $0() }, params: layoutParams, synchronousLoads: true, neighbors: neighbors(i), completion: { node, apply in
                        itemNode = node
                        apply().1(ListViewItemApply())
                    })
                    if let itemNode {
                        itemNode.isUserInteractionEnabled = false
                        itemNode.visibility = .visible(1.0, .infinite)
                        messageNodes.append(itemNode)
                        self.messagesContainer.addSubnode(itemNode)
                    }
                }
                self.messageNodes = messageNodes
            }

            var offset: CGFloat = 0.0
            for itemNode in self.messageNodes ?? [] {
                itemNode.frame = CGRect(origin: CGPoint(x: 0.0, y: offset), size: itemNode.frame.size)
                offset += itemNode.frame.height
            }
            return offset
        }

        func update(component: ContentComponent, availableSize: CGSize, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
            let environment = environment[ViewControllerComponentContainer.Environment.self].value
            let params = component.params

            if self.backgroundNode == nil {
                let backgroundNode = createWallpaperBackgroundNode(context: params.context, forChatDisplay: false)
                backgroundNode.update(wallpaper: params.wallpaper, animated: false)
                backgroundNode.updateBubbleTheme(bubbleTheme: params.theme, bubbleCorners: params.presentationData.chatBubbleCorners)
                self.backgroundNode = backgroundNode
                self.cardView.insertSubview(backgroundNode.view, at: 0)
            }

            let cardInset: CGFloat = 16.0
            let verticalInset: CGFloat = 8.0
            let cardWidth = availableSize.width - cardInset * 2.0 - environment.safeInsets.left - environment.safeInsets.right
            let messagesHeight = self.updateMessages(params: params, width: cardWidth, availableHeight: availableSize.height)
            let cardSize = CGSize(width: cardWidth, height: messagesHeight + verticalInset * 2.0)

            var contentHeight: CGFloat = 68.0
            self.cardView.frame = CGRect(origin: CGPoint(x: cardInset + environment.safeInsets.left, y: contentHeight), size: cardSize)
            self.messagesContainer.frame = CGRect(origin: CGPoint(x: 0.0, y: verticalInset), size: CGSize(width: cardWidth, height: messagesHeight))
            if let backgroundNode = self.backgroundNode {
                backgroundNode.frame = CGRect(origin: CGPoint(), size: cardSize)
                backgroundNode.updateLayout(size: cardSize, displayMode: .aspectFill, transition: .immediate)
            }
            contentHeight += cardSize.height + 16.0

            let buttonInsets = ContainerViewLayout.concentricInsets(bottomInset: environment.safeInsets.bottom, innerDiameter: buttonHeight, sideInset: 30.0)
            contentHeight += buttonHeight
            if params.canSendWithoutSwitching {
                contentHeight += buttonSpacing + buttonHeight
            }
            contentHeight += buttonInsets.bottom

            return CGSize(width: availableSize.width, height: contentHeight)
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, environment: environment, transition: transition)
    }
}

private final class SheetContainerComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let params: SupportContactConfirmScreenParams

    init(params: SupportContactConfirmScreenParams) {
        self.params = params
    }

    static func ==(lhs: SheetContainerComponent, rhs: SheetContainerComponent) -> Bool {
        return lhs.params === rhs.params
    }

    static var body: Body {
        let sheet = Child(ResizableSheetComponent<EnvironmentType>.self)
        let animateOut = StoredActionSlot(Action<Void>.self)

        return { context in
            let component = context.component
            let environment = context.environment[EnvironmentType.self]
            let controller = environment.controller
            let theme = environment.theme

            let dismiss: (Bool) -> Void = { animated in
                if animated {
                    animateOut.invoke(Action { _ in
                        controller()?.dismiss(completion: nil)
                    })
                } else {
                    controller()?.dismiss(completion: nil)
                }
            }
            let send: (SupportContactConfirmScreen.Action) -> Void = { action in
                (controller() as? SupportContactConfirmScreen)?.complete(action)
                dismiss(true)
            }

            let makeButton: (AnyHashable, String, UIColor, UIColor, @escaping () -> Void) -> AnyComponentWithIdentity<Empty> = { id, title, color, foreground, action in
                return AnyComponentWithIdentity(id: id, component: AnyComponent(ButtonComponent(
                    background: ButtonComponent.Background(
                        style: .glass,
                        color: color,
                        foreground: foreground,
                        pressedColor: color.withMultipliedAlpha(0.9)
                    ),
                    content: AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(ButtonTextContentComponent(
                        text: title,
                        badge: 0,
                        textColor: foreground,
                        badgeBackground: foreground,
                        badgeForeground: color
                    ))),
                    action: action
                )))
            }
            var buttons: [AnyComponentWithIdentity<Empty>] = [
                makeButton("send", environment.strings.MediaPicker_Send, theme.list.itemCheckColors.fillColor, theme.list.itemCheckColors.foregroundColor, {
                    send(.send)
                })
            ]
            if component.params.canSendWithoutSwitching {
                buttons.append(makeButton("stay", environment.strings.Support_Switching_SendWithoutSwitching, theme.list.itemPrimaryTextColor.withMultipliedAlpha(0.1), theme.list.itemPrimaryTextColor, {
                    send(.sendWithoutSwitching)
                }))
            }

            let sheet = sheet.update(
                component: ResizableSheetComponent<EnvironmentType>(
                    content: AnyComponent<EnvironmentType>(ContentComponent(params: component.params)),
                    titleItem: AnyComponent(
                        MultilineTextComponent(text: .plain(NSAttributedString(string: environment.strings.Support_ContactTemplates_ConfirmTitle, font: Font.semibold(17.0), textColor: theme.actionSheet.primaryTextColor)))
                    ),
                    leftItem: AnyComponent(
                        GlassBarButtonComponent(
                            size: CGSize(width: 44.0, height: 44.0),
                            backgroundColor: nil,
                            isDark: theme.overallDarkAppearance,
                            state: .glass,
                            component: AnyComponentWithIdentity(id: "close", component: AnyComponent(
                                BundleIconComponent(
                                    name: "Navigation/Close",
                                    tintColor: theme.chat.inputPanel.panelControlColor
                                )
                            )),
                            action: { _ in
                                dismiss(true)
                            }
                        )
                    ),
                    rightItem: nil,
                    bottomItem: AnyComponent(VStack(buttons, spacing: buttonSpacing)),
                    backgroundColor: .color(theme.list.modalPlainBackgroundColor),
                    isFullscreen: false,
                    animateOut: animateOut
                ),
                environment: {
                    environment
                    ResizableSheetComponentEnvironment(
                        theme: theme,
                        statusBarHeight: environment.statusBarHeight,
                        safeInsets: environment.safeInsets,
                        inputHeight: environment.inputHeight,
                        metrics: environment.metrics,
                        deviceMetrics: environment.deviceMetrics,
                        isDisplaying: environment.value.isVisible,
                        isCentered: environment.presentsFloatingPanels,
                        screenSize: context.availableSize,
                        regularMetricsSize: CGSize(width: 430.0, height: 900.0),
                        dismiss: { animated in
                            dismiss(animated)
                        }
                    )
                },
                availableSize: context.availableSize,
                transition: context.transition
            )

            context.add(sheet
                .position(CGPoint(x: context.availableSize.width / 2.0, y: context.availableSize.height / 2.0))
            )

            return context.availableSize
        }
    }
}

public final class SupportContactConfirmScreen: ViewControllerComponentContainer {
    public enum Action {
        case send
        case sendWithoutSwitching
        case cancel
    }

    private let completion: (Action) -> Void
    private var isCompleted = false

    public init(params: SupportContactConfirmScreenParams, completion: @escaping (Action) -> Void) {
        self.completion = completion

        super.init(context: params.context, component: SheetContainerComponent(params: params), navigationBarAppearance: .none, theme: .default)

        self.statusBar.statusBarStyle = .Ignore
        self.navigationPresentation = .flatModal
        self.blocksBackgroundWhenInOverlay = true
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    fileprivate func complete(_ action: Action) {
        guard !self.isCompleted else {
            return
        }
        self.isCompleted = true
        self.completion(action)
    }

    override public func dismiss(completion: (() -> Void)? = nil) {
        self.complete(.cancel)
        super.dismiss(completion: completion)
    }
}
