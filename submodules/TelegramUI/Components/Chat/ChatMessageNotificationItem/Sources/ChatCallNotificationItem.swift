import Foundation
import UIKit
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import TelegramUIPreferences
import AvatarNode
import AccountContext
import LocalizedPeerData
import StickerResources
import PhotoResources
import TelegramStringFormatting
import TextFormat
import InvisibleInkDustNode
import TextNodeWithEntities
import AnimationCache
import MultiAnimationRenderer
import ComponentFlow
import MultilineTextComponent
import BundleIconComponent
import PlainButtonComponent

public final class ChatCallNotificationItem: NotificationItem {
    public let context: AccountContext
    public let strings: PresentationStrings
    public let nameDisplayOrder: PresentationPersonNameOrder
    public let peer: EnginePeer
    public let isVideo: Bool
    public let action: (Bool) -> Void
    
    public var groupingKey: AnyHashable? {
        return nil
    }
    
    public init(context: AccountContext, strings: PresentationStrings, nameDisplayOrder: PresentationPersonNameOrder, peer: EnginePeer, isVideo: Bool, action: @escaping (Bool) -> Void) {
        self.context = context
        self.strings = strings
        self.nameDisplayOrder = nameDisplayOrder
        self.peer = peer
        self.isVideo = isVideo
        self.action = action
    }
    
    public func node(compact: Bool) -> NotificationItemNode {
        let node = ChatCallNotificationItemNode()
        node.setupItem(self, compact: compact)
        return node
    }
    
    public func tapped(_ take: @escaping () -> (ASDisplayNode?, () -> Void)) {
    }
    
    public func canBeExpanded() -> Bool {
        return false
    }
    
    public func expand(_ take: @escaping () -> (ASDisplayNode?, () -> Void)) {
    }
}

private let compactAvatarFont = avatarPlaceholderFont(size: 20.0)
private let avatarFont = avatarPlaceholderFont(size: 24.0)

final class ChatCallNotificationItemNode: NotificationItemNode {
    private var item: ChatCallNotificationItem?
    
    private let avatarNode: AvatarNode
    private let title = ComponentView<Empty>()
    private let text = ComponentView<Empty>()
    private let answerButton = ComponentView<Empty>()
    private let declineButton = ComponentView<Empty>()
    
    private var compact: Bool?
    private var validLayout: CGFloat?
    
    override init() {
        self.avatarNode = AvatarNode(font: avatarFont)
        
        super.init()
        
        self.acceptsTouches = true
        
        self.addSubnode(self.avatarNode)
    }
    
    func setupItem(_ item: ChatCallNotificationItem, compact: Bool) {
        self.item = item
        
        self.compact = compact
        if compact {
            self.avatarNode.font = compactAvatarFont
        }
        let presentationData = item.context.sharedContext.currentPresentationData.with { $0 }
        
        self.avatarNode.setPeer(context: item.context, theme: presentationData.theme, peer: item.peer, overrideImage: nil, emptyColor: presentationData.theme.list.mediaPlaceholderColor)
        
        if let width = self.validLayout {
            let _ = self.updateLayout(width: width, transition: .immediate)
        }
    }
    
    override public func updateLayout(width: CGFloat, transition: ContainedViewLayoutTransition) -> CGFloat {
        self.validLayout = width
        
        let panelHeight: CGFloat = 66.0
        
        guard let item = self.item else {
            return panelHeight
        }
        
        let presentationData = item.context.sharedContext.currentPresentationData.with { $0 }
        
        let leftInset: CGFloat = 14.0
        let rightInset: CGFloat = 14.0
        let avatarSize: CGFloat = 38.0
        let avatarTextSpacing: CGFloat = 10.0
        let buttonSpacing: CGFloat = 14.0
        let titleTextSpacing: CGFloat = 0.0
        
        let maxTextWidth: CGFloat = width - leftInset - avatarTextSpacing - rightInset - avatarSize * 2.0 - buttonSpacing - avatarTextSpacing
        
        let titleSize = self.title.update(
            transition: .immediate,
            component: AnyComponent(MultilineTextComponent(
                text: .plain(NSAttributedString(string: item.peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder), font: Font.semibold(16.0), textColor: presentationData.theme.list.itemPrimaryTextColor))
            )),
            environment: {},
            containerSize: CGSize(width: maxTextWidth, height: 100.0)
        )
        
        let textSize = self.text.update(
            transition: .immediate,
            component: AnyComponent(MultilineTextComponent(
                text: .plain(NSAttributedString(string: item.isVideo ? presentationData.strings.Notification_VideoCallIncoming : presentationData.strings.Notification_CallIncoming, font: Font.regular(13.0), textColor: presentationData.theme.list.itemPrimaryTextColor))
            )),
            environment: {},
            containerSize: CGSize(width: maxTextWidth, height: 100.0)
        )
        
        let titleTextHeight = titleSize.height + titleTextSpacing + textSize.height
        let titleTextY = floor((panelHeight - titleTextHeight) * 0.5)
        let titleFrame = CGRect(origin: CGPoint(x: leftInset + avatarSize + avatarTextSpacing, y: titleTextY), size: titleSize)
        let textFrame = CGRect(origin: CGPoint(x: leftInset + avatarSize + avatarTextSpacing, y: titleTextY + titleSize.height + titleTextSpacing), size: textSize)
        
        if let titleView = self.title.view {
            if titleView.superview == nil {
                self.view.addSubview(titleView)
            }
            titleView.frame = titleFrame
        }
        
        if let textView = self.text.view {
            if textView.superview == nil {
                self.view.addSubview(textView)
            }
            textView.frame = textFrame
        }
        
        transition.updateFrame(node: self.avatarNode, frame: CGRect(origin: CGPoint(x: leftInset, y: (panelHeight - avatarSize) / 2.0), size: CGSize(width: avatarSize, height: avatarSize)))
        
        let answerButtonSize = self.answerButton.update(
            transition: .immediate,
            component: AnyComponent(PlainButtonComponent(
                content: AnyComponent(ZStack([
                    AnyComponentWithIdentity(id: 1, component: AnyComponent(Circle(
                        fillColor: UIColor(rgb: 0x34C759),
                        size: CGSize(width: avatarSize, height: avatarSize)
                    ))),
                    AnyComponentWithIdentity(id: 2, component: AnyComponent(BundleIconComponent(
                        name: "Call/CallNotificationAnswerIcon",
                        tintColor: .white
                    )))
                ])),
                effectAlignment: .center,
                minSize: CGSize(width: avatarSize, height: avatarSize),
                action: { [weak self] in
                    guard let self, let item = self.item else {
                        return
                    }
                    item.action(true)
                }
            )),
            environment: {},
            containerSize: CGSize(width: avatarSize, height: avatarSize)
        )
        let declineButtonSize = self.declineButton.update(
            transition: .immediate,
            component: AnyComponent(PlainButtonComponent(
                content: AnyComponent(ZStack([
                    AnyComponentWithIdentity(id: 1, component: AnyComponent(Circle(
                        fillColor: UIColor(rgb: 0xFF3B30),
                        size: CGSize(width: avatarSize, height: avatarSize)
                    ))),
                    AnyComponentWithIdentity(id: 2, component: AnyComponent(BundleIconComponent(
                        name: "Call/CallNotificationDeclineIcon",
                        tintColor: .white
                    )))
                ])),
                effectAlignment: .center,
                minSize: CGSize(width: avatarSize, height: avatarSize),
                action: { [weak self] in
                    guard let self, let item = self.item else {
                        return
                    }
                    item.action(false)
                }
            )),
            environment: {},
            containerSize: CGSize(width: avatarSize, height: avatarSize)
        )
        
        let declineButtonFrame = CGRect(origin: CGPoint(x: width - rightInset - avatarSize - buttonSpacing - declineButtonSize.width, y: floor((panelHeight - declineButtonSize.height) * 0.5)), size: declineButtonSize)
        if let declineButtonView = self.declineButton.view {
            if declineButtonView.superview == nil {
                self.view.addSubview(declineButtonView)
            }
            declineButtonView.frame = declineButtonFrame
        }
        
        let answerButtonFrame = CGRect(origin: CGPoint(x: declineButtonFrame.maxX + buttonSpacing, y: floor((panelHeight - answerButtonSize.height) * 0.5)), size: answerButtonSize)
        if let answerButtonView = self.answerButton.view {
            if answerButtonView.superview == nil {
                self.view.addSubview(answerButtonView)
            }
            answerButtonView.frame = answerButtonFrame
        }
        
        return panelHeight
    }
}
