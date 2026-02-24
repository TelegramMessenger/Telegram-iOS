import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit
import AccountContext
import TelegramPresentationData
import PresentationDataUtils
import ComponentFlow
import ViewControllerComponent
import SheetComponent
import MultilineTextComponent
import BalancedTextComponent
import BundleIconComponent
import Markdown
import TextFormat
import TelegramStringFormatting
import GlassBarButtonComponent
import ButtonComponent
import LottieComponent
import RankChatPreviewItem
import ListSectionComponent
import ListItemComponentAdaptor

private final class ChatRankInfoSheetContent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let chatPeer: EnginePeer
    let userPeer: EnginePeer
    let role: ChatRankInfoScreenRole
    let rank: String
    let canChange: Bool
    let getController: () -> ViewController?
    let dismiss: () -> Void
    
    init(
        context: AccountContext,
        chatPeer: EnginePeer,
        userPeer: EnginePeer,
        role: ChatRankInfoScreenRole,
        rank: String,
        canChange: Bool,
        getController: @escaping () -> ViewController?,
        dismiss: @escaping () -> Void
    ) {
        self.context = context
        self.chatPeer = chatPeer
        self.userPeer = userPeer
        self.role = role
        self.rank = rank
        self.canChange = canChange
        self.getController = getController
        self.dismiss = dismiss
    }
    
    static func ==(lhs: ChatRankInfoSheetContent, rhs: ChatRankInfoSheetContent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        return true
    }
    
    final class State: ComponentState {
        private let context: AccountContext
                
        fileprivate let playButtonAnimation = ActionSlot<Void>()
        private var didPlayAnimation = false
        
        init(
            context: AccountContext
        ) {
            self.context = context
            
            super.init()
        }
        
        func playAnimationIfNeeded() {
            if !self.didPlayAnimation {
                self.didPlayAnimation = true
                self.playButtonAnimation.invoke(Void())
            }
        }
    }
    
    func makeState() -> State {
        return State(context: self.context)
    }
    
    static var body: Body {
        let closeButton = Child(GlassBarButtonComponent.self)
        let icon = Child(ZStack<Empty>.self)
        let title = Child(BalancedTextComponent.self)
        let text = Child(BalancedTextComponent.self)
        let memberPreview = Child(ListSectionComponent.self)
        let adminPreview = Child(ListSectionComponent.self)
        let additionalText = Child(BalancedTextComponent.self)
        let button = Child(ButtonComponent.self)
                                
        return { context in
            let environment = context.environment[ViewControllerComponentContainer.Environment.self].value
            let state = context.state
            let component = context.component
            let controller = environment.controller
           
            let theme = environment.theme
            let strings = environment.strings
            
            let textSideInset: CGFloat = 30.0 + environment.safeInsets.left
                                    
            let titleFont = Font.bold(24.0)
            let textFont = Font.regular(15.0)
            let boldTextFont = Font.semibold(15.0)
            let additionalTextFont = Font.regular(13.0)
            let textColor = theme.actionSheet.primaryTextColor
            let secondaryTextColor = theme.actionSheet.secondaryTextColor
                        
            let iconColor: UIColor
            let titleString: String
            let textString: String
            let linkColor: UIColor
            var linkHasBackground = true
            let additionalTextString: String? = component.canChange ? nil : strings.RankInfo_ChangeInfo
            var adminPreviewTag = strings.RankInfo_AdminTag
            var adminPreviewRole: ChatRankInfoScreenRole = .admin
            
            let userName = context.component.userPeer.compactDisplayTitle
            let chatName = context.component.chatPeer.compactDisplayTitle
            
            let canEdit = component.canChange
            switch context.component.role {
            case .creator:
                var rank = !context.component.rank.isEmpty ? context.component.rank : strings.Conversation_Owner
                rank = rank.replacingOccurrences(of: " ", with: "\u{00A0}")
                iconColor = UIColor(rgb: 0x956ac8)
                linkColor = iconColor
                titleString = strings.RankInfo_Owner_Title
                textString = strings.RankInfo_Owner_Text(" [\(rank)]() ", userName, userName, chatName).string
                adminPreviewTag = strings.RankInfo_OwnerTag
                adminPreviewRole = .creator
            case .admin:
                var rank = !context.component.rank.isEmpty ? context.component.rank : strings.Conversation_Admin
                rank = rank.replacingOccurrences(of: " ", with: "\u{00A0}")
                iconColor = UIColor(rgb: 0x49a355)
                linkColor = iconColor
                titleString = strings.RankInfo_Admin_Title
                textString = strings.RankInfo_Admin_Text(" [\(rank)]() ", userName, userName, chatName).string
            case .member:
                let rank = context.component.rank.replacingOccurrences(of: " ", with: "\u{00A0}")
                iconColor = secondaryTextColor.withMultipliedAlpha(0.85)
                linkColor = secondaryTextColor
                linkHasBackground = false
                titleString = strings.RankInfo_Member_Title
                textString = strings.RankInfo_Member_Text(" [\(rank)]() ", userName, userName, chatName).string
            }
            
            let markdownAttributes = MarkdownAttributes(body: MarkdownAttributeSet(font: textFont, textColor: textColor), bold: MarkdownAttributeSet(font: boldTextFont, textColor: textColor), link: MarkdownAttributeSet(font: textFont, textColor: linkColor), linkAttribute: { contents in
                if linkHasBackground {
                    return ("TelegramBackground", NSUnderlineStyle.single.rawValue)
                } else {
                    return nil
                }
            })
            
            var contentSize = CGSize(width: context.availableSize.width, height: 40.0)
            let icon = icon.update(
                component: ZStack([
                    AnyComponentWithIdentity(
                        id: AnyHashable(0),
                        component: AnyComponent(RoundedRectangle(color: iconColor, cornerRadius: 50.0, size: CGSize(width: 100.0, height: 100.0)))
                    ),
                    AnyComponentWithIdentity(
                        id: AnyHashable(1),
                        component: AnyComponent(BundleIconComponent(
                            name: "Chat/RankIcon",
                            tintColor: .white
                        ))
                    )
                ]),
                availableSize: CGSize(width: 100.0, height: 100.0),
                transition: .immediate
            )
            context.add(icon
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + icon.size.height / 2.0))
            )
            contentSize.height += icon.size.height
            contentSize.height += 20.0
            
            
            let title = title.update(
                component: BalancedTextComponent(
                    text: .plain(NSAttributedString(string: titleString, font: titleFont, textColor: textColor)),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.1
                ),
                availableSize: CGSize(width: context.availableSize.width - textSideInset * 2.0, height: context.availableSize.height),
                transition: .immediate
            )
            context.add(title
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + title.size.height / 2.0))
            )
            contentSize.height += title.size.height
            contentSize.height += 12.0
            

            let constrainedTextWidth = context.availableSize.width - 16.0 * 2.0
            let text = text.update(
                component: BalancedTextComponent(
                    text: .markdown(
                        text: textString,
                        attributes: markdownAttributes
                    ),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.2,
                    insets: UIEdgeInsets(top: 2.0, left: 0.0, bottom: 2.0, right: 0.0)
                ),
                availableSize: CGSize(width: constrainedTextWidth, height: context.availableSize.height),
                transition: .immediate
            )
            context.add(text
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + text.size.height / 2.0))
            )
            contentSize.height += text.size.height
            contentSize.height += 27.0
            
            let previewWidth = (context.availableSize.width - 16.0 * 2.0 - 8.0) / 2.0
            
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            
            let listItemParams = ListViewItemLayoutParams(width: previewWidth, leftInset: 0.0, rightInset: 0.0, availableHeight: 10000.0, isStandalone: true)
            
            let emptyUser = TelegramUser(id: PeerId(namespace: Namespaces.Peer.CloudUser, id: ._internalFromInt64Value(0)), accessHash: nil, firstName: "A", lastName: "", username: "", phone: "", photo: [], botInfo: nil, restrictionInfo: nil, flags: [], emojiStatus: nil, usernames: [], storiesHidden: nil, nameColor: nil, backgroundEmojiId: nil, profileColor: nil, profileBackgroundEmojiId: nil, subscriberCount: nil, verificationIconFileId: nil)
            
            let memberMessageItem = RankChatPreviewItem.MessageItem(
                peer: .user(emptyUser),
                text: "Reinhardt, we need to find you some new tunes, mkay?",
                entities: nil,
                media: [],
                rank: strings.RankInfo_MemberTag,
                rankRole: .member
            )
            
            var memberPreviewSectionItems: [AnyComponentWithIdentity<Empty>] = []
            memberPreviewSectionItems.append(
                AnyComponentWithIdentity(id: 0, component: AnyComponent(ListItemComponentAdaptor(
                    itemGenerator: RankChatPreviewItem(
                        context: component.context,
                        theme: environment.theme,
                        componentTheme: theme,
                        strings: strings,
                        sectionId: 0,
                        fontSize: presentationData.chatFontSize,
                        chatBubbleCorners: presentationData.chatBubbleCorners,
                        wallpaper: presentationData.chatWallpaper,
                        dateTimeFormat: environment.dateTimeFormat,
                        nameDisplayOrder: presentationData.nameDisplayOrder,
                        messageItems: [memberMessageItem],
                        containerWidth: context.availableSize.width - 32.0,
                        hideAvatars: true,
                        verticalInset: 9.0,
                        maskSide: true
                    ),
                    params: listItemParams
                )))
            )
            
            let memberPreview = memberPreview.update(
                component: ListSectionComponent(
                    theme: theme,
                    style: .glass,
                    header: nil,
                    footer: nil,
                    items: memberPreviewSectionItems
                ),
                availableSize: CGSize(width: previewWidth, height: context.availableSize.height),
                transition: context.transition
            )
            context.add(memberPreview
                .position(CGPoint(x: 16.0 + memberPreview.size.width / 2.0, y: contentSize.height + memberPreview.size.height / 2.0))
            )
            
            let adminMessageItem = RankChatPreviewItem.MessageItem(
                peer: .user(emptyUser),
                text: "Reinhardt, we need to find you some new tunes, mkay?",
                entities: nil,
                media: [],
                rank: adminPreviewTag,
                rankRole: adminPreviewRole
            )
            
            var adminPreviewSectionItems: [AnyComponentWithIdentity<Empty>] = []
            adminPreviewSectionItems.append(
                AnyComponentWithIdentity(id: 0, component: AnyComponent(ListItemComponentAdaptor(
                    itemGenerator: RankChatPreviewItem(
                        context: component.context,
                        theme: environment.theme,
                        componentTheme: theme,
                        strings: strings,
                        sectionId: 0,
                        fontSize: presentationData.chatFontSize,
                        chatBubbleCorners: presentationData.chatBubbleCorners,
                        wallpaper: presentationData.chatWallpaper,
                        dateTimeFormat: environment.dateTimeFormat,
                        nameDisplayOrder: presentationData.nameDisplayOrder,
                        messageItems: [adminMessageItem],
                        containerWidth: context.availableSize.width - 32.0,
                        hideAvatars: true,
                        verticalInset: 9.0,
                        maskSide: true
                    ),
                    params: listItemParams
                )))
            )
            
            let adminPreview = adminPreview.update(
                component: ListSectionComponent(
                    theme: theme,
                    style: .glass,
                    header: nil,
                    footer: nil,
                    items: adminPreviewSectionItems
                ),
                availableSize: CGSize(width: previewWidth, height: context.availableSize.height),
                transition: context.transition
            )
            context.add(adminPreview
                .position(CGPoint(x: context.availableSize.width - 16.0 - adminPreview.size.width / 2.0, y: contentSize.height + adminPreview.size.height / 2.0))
            )
            contentSize.height += adminPreview.size.height
            contentSize.height += 27.0
            
            
            if let additionalTextString {
                let additionalText = additionalText.update(
                    component: BalancedTextComponent(
                        text: .plain(NSAttributedString(string: additionalTextString, font: additionalTextFont, textColor: secondaryTextColor)),
                        horizontalAlignment: .center,
                        maximumNumberOfLines: 0,
                        lineSpacing: 0.2
                    ),
                    availableSize: CGSize(width: constrainedTextWidth, height: context.availableSize.height),
                    transition: .immediate
                )
                context.add(additionalText
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + additionalText.size.height / 2.0))
                )
                contentSize.height += additionalText.size.height
                contentSize.height += 26.0
            }
            
            let closeButton = closeButton.update(
                component: GlassBarButtonComponent(
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
                        component.dismiss()
                    }
                ),
                availableSize: CGSize(width: 44.0, height: 44.0),
                transition: .immediate
            )
            context.add(closeButton
                .position(CGPoint(x: 16.0 + closeButton.size.width / 2.0, y: 16.0 + closeButton.size.height / 2.0))
            )
            
            var buttonTitle: [AnyComponentWithIdentity<Empty>] = []
            if canEdit {
                buttonTitle.append(AnyComponentWithIdentity(id: 1, component: AnyComponent(ButtonTextContentComponent(
                    text: strings.RankInfo_SetMyTag,
                    badge: 0,
                    textColor: theme.list.itemCheckColors.foregroundColor,
                    badgeBackground: theme.list.itemCheckColors.foregroundColor,
                    badgeForeground: theme.list.itemCheckColors.fillColor
                ))))
            } else {
                buttonTitle.append(AnyComponentWithIdentity(id: 0, component: AnyComponent(LottieComponent(
                    content: LottieComponent.AppBundleContent(name: "anim_ok"),
                    color: theme.list.itemCheckColors.foregroundColor,
                    startingPosition: .begin,
                    size: CGSize(width: 28.0, height: 28.0),
                    playOnce: state.playButtonAnimation
                ))))
                buttonTitle.append(AnyComponentWithIdentity(id: 1, component: AnyComponent(ButtonTextContentComponent(
                    text: strings.CocoonInfo_Understood,
                    badge: 0,
                    textColor: theme.list.itemCheckColors.foregroundColor,
                    badgeBackground: theme.list.itemCheckColors.foregroundColor,
                    badgeForeground: theme.list.itemCheckColors.fillColor
                ))))
            }
            
            let buttonInsets = ContainerViewLayout.concentricInsets(bottomInset: environment.safeInsets.bottom, innerDiameter: 52.0, sideInset: 30.0)
            let button = button.update(
                component: ButtonComponent(
                    background: ButtonComponent.Background(
                        style: .glass,
                        color: theme.list.itemCheckColors.fillColor,
                        foreground: theme.list.itemCheckColors.foregroundColor,
                        pressedColor: theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9)
                    ),
                    content: AnyComponentWithIdentity(
                        id: AnyHashable(0),
                        component: AnyComponent(HStack(buttonTitle, spacing: 2.0))
                    ),
                    isEnabled: true,
                    displaysProgress: false,
                    action: {
                        component.dismiss()
                        
                        if canEdit, let controller = controller() as? ChatRankInfoScreen {
                            controller.completion?()
                        }
                    }
                ),
                availableSize: CGSize(width: context.availableSize.width - buttonInsets.left - buttonInsets.right, height: 52.0),
                transition: .immediate
            )
            context.add(button
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + button.size.height / 2.0))
            )
            contentSize.height += button.size.height 
            contentSize.height += buttonInsets.bottom
            
            state.playAnimationIfNeeded()
            
            return contentSize
        }
    }
}

final class ChatRankInfoSheetComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let chatPeer: EnginePeer
    let userPeer: EnginePeer
    let role: ChatRankInfoScreenRole
    let rank: String
    let canChange: Bool
    
    init(
        context: AccountContext,
        chatPeer: EnginePeer,
        userPeer: EnginePeer,
        role: ChatRankInfoScreenRole,
        rank: String,
        canChange: Bool
    ) {
        self.context = context
        self.chatPeer = chatPeer
        self.userPeer = userPeer
        self.role = role
        self.rank = rank
        self.canChange = canChange
    }
    
    static func ==(lhs: ChatRankInfoSheetComponent, rhs: ChatRankInfoSheetComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        return true
    }
    
    static var body: Body {
        let sheet = Child(SheetComponent<EnvironmentType>.self)
        let animateOut = StoredActionSlot(Action<Void>.self)
        
        let sheetExternalState = SheetComponent<EnvironmentType>.ExternalState()
        
        return { context in
            let environment = context.environment[EnvironmentType.self]
            let controller = environment.controller
            
            let dismiss: (Bool) -> Void = { animated in
                if animated {
                    if let controller = controller() as? ChatRankInfoScreen {
                        animateOut.invoke(Action { _ in
                            controller.dismiss(completion: nil)
                        })
                    }
                } else {
                    if let controller = controller() as? ChatRankInfoScreen {
                        controller.dismiss(completion: nil)
                    }
                }
            }
            
            let sheet = sheet.update(
                component: SheetComponent<EnvironmentType>(
                    content: AnyComponent<EnvironmentType>(ChatRankInfoSheetContent(
                        context: context.component.context,
                        chatPeer: context.component.chatPeer,
                        userPeer: context.component.userPeer,
                        role: context.component.role,
                        rank: context.component.rank,
                        canChange: context.component.canChange,
                        getController: controller,
                        dismiss: {
                            dismiss(true)
                        }
                    )),
                    style: .glass,
                    backgroundColor: .color(environment.theme.actionSheet.opaqueItemBackgroundColor),
                    followContentSizeChanges: true,
                    clipsContent: true,
                    autoAnimateOut: false,
                    externalState: sheetExternalState,
                    animateOut: animateOut,
                    onPan: {},
                    willDismiss: {}
                ),
                environment: {
                    environment
                    SheetComponentEnvironment(
                        metrics: environment.metrics,
                        deviceMetrics: environment.deviceMetrics,
                        isDisplaying: environment.value.isVisible,
                        isCentered: environment.metrics.widthClass == .regular,
                        hasInputHeight: !environment.inputHeight.isZero,
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
            
            if let controller = controller(), !controller.automaticallyControlPresentationContextLayout {
                var sideInset: CGFloat = 0.0
                var bottomInset: CGFloat = max(environment.safeInsets.bottom, sheetExternalState.contentHeight)
                if case .regular = environment.metrics.widthClass {
                    sideInset = floor((context.availableSize.width - 430.0) / 2.0) - 12.0
                    bottomInset = (context.availableSize.height - sheetExternalState.contentHeight) / 2.0 + sheetExternalState.contentHeight
                }
                
                let layout = ContainerViewLayout(
                    size: context.availableSize,
                    metrics: environment.metrics,
                    deviceMetrics: environment.deviceMetrics,
                    intrinsicInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: bottomInset, right: 0.0),
                    safeInsets: UIEdgeInsets(top: 0.0, left: max(sideInset, environment.safeInsets.left), bottom: 0.0, right: max(sideInset, environment.safeInsets.right)),
                    additionalInsets: .zero,
                    statusBarHeight: environment.statusBarHeight,
                    inputHeight: nil,
                    inputHeightIsInteractivellyChanging: false,
                    inVoiceOver: false
                )
                controller.presentationContext.containerLayoutUpdated(layout, transition: context.transition.containedViewLayoutTransition)
            }
            
            return context.availableSize
        }
    }
}

public final class ChatRankInfoScreen: ViewControllerComponentContainer {
    private let context: AccountContext
    fileprivate let completion: (() -> Void)?
    
    public init(
        context: AccountContext,
        chatPeer: EnginePeer,
        userPeer: EnginePeer,
        role: ChatRankInfoScreenRole,
        rank: String,
        canChange: Bool,
        completion: (() -> Void)?
    ) {
        self.context = context
        self.completion = completion
        
        super.init(
            context: context,
            component: ChatRankInfoSheetComponent(
                context: context,
                chatPeer: chatPeer,
                userPeer: userPeer,
                role: role,
                rank: rank,
                canChange: canChange
            ),
            navigationBarAppearance: .none,
            statusBarStyle: .ignore,
            theme: .default
        )
        
        self.navigationPresentation = .flatModal
        self.automaticallyControlPresentationContextLayout = false
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.disablesInteractiveModalDismiss = true
    }
    

    public func dismissAnimated() {
        if let view = self.node.hostView.findTaggedView(tag: SheetComponent<ViewControllerComponentContainer.Environment>.View.Tag()) as? SheetComponent<ViewControllerComponentContainer.Environment>.View {
            view.dismissAnimated()
        }
    }
}
