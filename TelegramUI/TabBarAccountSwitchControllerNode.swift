import Foundation
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore

private let avatarFont: UIFont = UIFont(name: ".SFCompactRounded-Semibold", size: 16.0)!

private protocol AbstractSwitchAccountItemNode {
    func updateLayout(maxWidth: CGFloat) -> (CGFloat, CGFloat, (CGFloat) -> Void)
}

private final class AddAccountItemNode: ASDisplayNode, AbstractSwitchAccountItemNode {
    private let action: () -> Void
    
    private let separatorNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    private let buttonNode: HighlightTrackingButtonNode
    private let plusNode: ASImageNode
    private let titleNode: ImmediateTextNode
    
    init(displaySeparator: Bool, presentationData: PresentationData, action: @escaping () -> Void) {
        self.action = action
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.backgroundColor = presentationData.theme.actionSheet.opaqueItemSeparatorColor
        self.separatorNode.isHidden = !displaySeparator
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.backgroundColor = presentationData.theme.actionSheet.opaqueItemHighlightedBackgroundColor
        self.highlightedBackgroundNode.alpha = 0.0
        
        self.buttonNode = HighlightTrackingButtonNode()
        
        self.titleNode = ImmediateTextNode()
        self.titleNode.maximumNumberOfLines = 1
        self.titleNode.attributedText = NSAttributedString(string: presentationData.strings.Settings_AddAccount, font: Font.regular(17.0), textColor: presentationData.theme.actionSheet.primaryTextColor)
        
        self.plusNode = ASImageNode()
        self.plusNode.image = generateItemListPlusIcon(presentationData.theme.actionSheet.primaryTextColor)
        
        super.init()
        
        self.addSubnode(self.separatorNode)
        self.addSubnode(self.highlightedBackgroundNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.plusNode)
        self.addSubnode(self.buttonNode)
        
        self.buttonNode.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
        self.buttonNode.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.highlightedBackgroundNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.highlightedBackgroundNode.alpha = 1.0
                } else {
                    strongSelf.highlightedBackgroundNode.alpha = 0.0
                    strongSelf.highlightedBackgroundNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3)
                }
            }
        }
    }
    
    func updateLayout(maxWidth: CGFloat) -> (CGFloat, CGFloat, (CGFloat) -> Void) {
        let leftInset: CGFloat = 56.0
        let rightInset: CGFloat = 10.0
        let titleSize = self.titleNode.updateLayout(CGSize(width: maxWidth - leftInset - rightInset, height: .greatestFiniteMagnitude))
        let height: CGFloat = 61.0
        
        return (titleSize.width + leftInset + rightInset, height, { width in
            self.titleNode.frame = CGRect(origin: CGPoint(x: leftInset, y: floor((height - titleSize.height) / 2.0)), size: titleSize)
            
            if let image = self.plusNode.image {
                self.plusNode.frame = CGRect(origin: CGPoint(x: floor((leftInset - image.size.width) / 2.0), y: floor((height - image.size.height) / 2.0)), size: image.size)
            }
            
            self.separatorNode.frame = CGRect(origin: CGPoint(x: 0.0, y: height - UIScreenPixel), size: CGSize(width: width, height: UIScreenPixel))
            self.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: width, height: height))
            self.buttonNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: width, height: height))
        })
    }
    
    @objc private func buttonPressed() {
        self.action()
    }
}

private final class SwitchAccountItemNode: ASDisplayNode, AbstractSwitchAccountItemNode {
    private let account: Account
    private let peer: Peer
    private let isCurrent: Bool
    private let unreadCount: Int32
    private let presentationData: PresentationData
    private let action: () -> Void
    
    private let separatorNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    private let buttonNode: HighlightTrackingButtonNode
    private let avatarNode: AvatarNode
    private let titleNode: ImmediateTextNode
    private let checkNode: ASImageNode
    
    private let badgeBackgroundNode: ASImageNode
    private let badgeTitleNode: ImmediateTextNode
    
    init(account: Account, peer: Peer, isCurrent: Bool, unreadCount: Int32, displaySeparator: Bool, presentationData: PresentationData, action: @escaping () -> Void) {
        self.account = account
        self.peer = peer
        self.isCurrent = isCurrent
        self.unreadCount = unreadCount
        self.presentationData = presentationData
        self.action = action
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.backgroundColor = presentationData.theme.actionSheet.opaqueItemSeparatorColor
        self.separatorNode.isHidden = !displaySeparator
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.backgroundColor = presentationData.theme.actionSheet.opaqueItemHighlightedBackgroundColor
        self.highlightedBackgroundNode.alpha = 0.0
        
        self.buttonNode = HighlightTrackingButtonNode()
        
        self.avatarNode = AvatarNode(font: avatarFont)
        
        self.titleNode = ImmediateTextNode()
        self.titleNode.maximumNumberOfLines = 1
        self.titleNode.attributedText = NSAttributedString(string: peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder), font: Font.regular(17.0), textColor: presentationData.theme.actionSheet.primaryTextColor)
        
        self.checkNode = ASImageNode()
        self.checkNode.image = generateItemListCheckIcon(color: presentationData.theme.actionSheet.primaryTextColor)
        self.checkNode.isHidden = !isCurrent
        
        self.badgeBackgroundNode = ASImageNode()
        self.badgeBackgroundNode.image = generateStretchableFilledCircleImage(diameter: 20.0, color: presentationData.theme.list.itemCheckColors.fillColor)
        self.badgeTitleNode = ImmediateTextNode()
        if unreadCount > 0 {
            let countString: String
            if unreadCount > 1000 {
                countString = "\(unreadCount / 1000)K"
            } else {
                countString = "\(unreadCount)"
            }
            self.badgeTitleNode.attributedText = NSAttributedString(string: countString, font: Font.regular(14.0), textColor: presentationData.theme.list.itemCheckColors.foregroundColor)
        } else {
            self.badgeBackgroundNode.isHidden = true
            self.badgeTitleNode.isHidden = true
        }
        
        super.init()
        
        self.addSubnode(self.separatorNode)
        self.addSubnode(self.highlightedBackgroundNode)
        self.addSubnode(self.avatarNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.checkNode)
        self.addSubnode(self.badgeBackgroundNode)
        self.addSubnode(self.badgeTitleNode)
        self.addSubnode(self.buttonNode)
        
        self.buttonNode.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
        self.buttonNode.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.highlightedBackgroundNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.highlightedBackgroundNode.alpha = 1.0
                } else {
                    strongSelf.highlightedBackgroundNode.alpha = 0.0
                    strongSelf.highlightedBackgroundNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3)
                }
            }
        }
    }
    
    func updateLayout(maxWidth: CGFloat) -> (CGFloat, CGFloat, (CGFloat) -> Void) {
        let leftInset: CGFloat = 56.0
        
        let badgeTitleSize = self.badgeTitleNode.updateLayout(CGSize(width: 100.0, height: .greatestFiniteMagnitude))
        let badgeMinSize = self.badgeBackgroundNode.image?.size.width ?? 20.0
        let badgeSize = CGSize(width: max(badgeMinSize, badgeTitleSize.width + 12.0), height: badgeMinSize)
        
        let rightInset: CGFloat = max(60.0, badgeSize.width + 40.0)
        
        let titleSize = self.titleNode.updateLayout(CGSize(width: maxWidth - leftInset - rightInset, height: .greatestFiniteMagnitude))
        
        let height: CGFloat = 61.0
        
        return (titleSize.width + leftInset + rightInset, height, { width in
            let avatarSize = CGSize(width: 30.0, height: 30.0)
            self.avatarNode.frame = CGRect(origin: CGPoint(x: floor((leftInset - avatarSize.width) / 2.0), y: floor((height - avatarSize.height) / 2.0)), size: avatarSize)
            self.avatarNode.setPeer(account: self.account, theme: self.presentationData.theme, peer: self.peer)
            
            self.titleNode.frame = CGRect(origin: CGPoint(x: leftInset, y: floor((height - titleSize.height) / 2.0)), size: titleSize)
            
            if let image = self.checkNode.image {
                self.checkNode.frame = CGRect(origin: CGPoint(x: width - rightInset + floor((rightInset - image.size.width) / 2.0), y: floor((height - image.size.height) / 2.0)), size: image.size)
            }
            
            let badgeBackgroundFrame = CGRect(origin: CGPoint(x: width - rightInset + floor((rightInset - badgeSize.width) / 2.0), y: floor((height - badgeSize.height) / 2.0)), size: badgeSize)
            self.badgeBackgroundNode.frame = badgeBackgroundFrame
            self.badgeTitleNode.frame = CGRect(origin: CGPoint(x: badgeBackgroundFrame.minX + floor((badgeBackgroundFrame.width - badgeTitleSize.width) / 2.0), y: badgeBackgroundFrame.minY + floor((badgeBackgroundFrame.height - badgeTitleSize.height) / 2.0)), size: badgeTitleSize)
            
            self.separatorNode.frame = CGRect(origin: CGPoint(x: 0.0, y: height - UIScreenPixel), size: CGSize(width: width, height: UIScreenPixel))
            self.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: width, height: height))
            self.buttonNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: width, height: height))
        })
    }
    
    @objc private func buttonPressed() {
        self.action()
    }
}

final class TabBarAccountSwitchControllerNode: ViewControllerTracingNode {
    private let presentationData: PresentationData
    private let cancel: () -> Void
    
    private let effectView: UIVisualEffectView
    private let tapNode: ASDisplayNode
    
    private let contentContainerNode: ASDisplayNode
    private let contentNodes: [ASDisplayNode & AbstractSwitchAccountItemNode]
    
    private let sourceNodes: [ASDisplayNode]
    private var snapshotViews: [UIView] = []
    
    private var validLayout: ContainerViewLayout?
    
    init(sharedContext: SharedAccountContext, accounts: (primary: (Account, Peer), other: [(Account, Peer, Int32)]), presentationData: PresentationData, canAddAccounts: Bool, switchToAccount: @escaping (AccountRecordId) -> Void, addAccount: @escaping () -> Void, cancel: @escaping () -> Void, sourceNodes: [ASDisplayNode]) {
        self.presentationData = presentationData
        self.cancel = cancel
        self.sourceNodes = sourceNodes
        
        self.effectView = UIVisualEffectView()
        if #available(iOS 9.0, *) {
        } else {
            if presentationData.theme.chatList.searchBarKeyboardColor == .dark {
                self.effectView.effect = UIBlurEffect(style: .dark)
            } else {
                self.effectView.effect = UIBlurEffect(style: .light)
            }
            self.effectView.alpha = 0.0
        }
        
        self.tapNode = ASDisplayNode()
        
        self.contentContainerNode = ASDisplayNode()
        self.contentContainerNode.backgroundColor = self.presentationData.theme.actionSheet.opaqueItemBackgroundColor
        self.contentContainerNode.cornerRadius = 20.0
        self.contentContainerNode.clipsToBounds = true
        
        var contentNodes: [ASDisplayNode & AbstractSwitchAccountItemNode] = []
        if canAddAccounts {
            contentNodes.append(AddAccountItemNode(displaySeparator: true, presentationData: presentationData, action: {
                addAccount()
                cancel()
            }))
        }
        contentNodes.append(SwitchAccountItemNode(account: accounts.primary.0, peer: accounts.primary.1, isCurrent: true, unreadCount: 0, displaySeparator: !accounts.other.isEmpty, presentationData: presentationData, action: {
            cancel()
        }))
        for i in 0 ..< accounts.other.count {
            let (account, peer, count) = accounts.other[i]
            let id = account.id
            contentNodes.append(SwitchAccountItemNode(account: account, peer: peer, isCurrent: false, unreadCount: count, displaySeparator: i != accounts.other.count - 1, presentationData: presentationData, action: {
                switchToAccount(id)
                cancel()
            }))
        }
        self.contentNodes = contentNodes
        
        super.init()
        
        self.view.addSubview(self.effectView)
        self.addSubnode(self.tapNode)
        self.addSubnode(self.contentContainerNode)
        self.contentNodes.forEach(self.contentContainerNode.addSubnode)
        
        self.tapNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimTapGesture(_:))))
    }
    
    func animateIn() {
        UIView.animate(withDuration: 0.3, animations: {
            if #available(iOS 9.0, *) {
                if self.presentationData.theme.chatList.searchBarKeyboardColor == .dark {
                    if #available(iOSApplicationExtension 10.0, *) {
                        self.effectView.effect = UIBlurEffect(style: .regular)
                    } else {
                        self.effectView.effect = UIBlurEffect(style: .dark)
                    }
                } else {
                    if #available(iOSApplicationExtension 10.0, *) {
                        self.effectView.effect = UIBlurEffect(style: .regular)
                    } else {
                        self.effectView.effect = UIBlurEffect(style: .light)
                    }
                }
            } else {
                self.effectView.alpha = 1.0
            }
        })
        self.contentContainerNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
        if let _ = self.validLayout, let sourceNode = self.sourceNodes.first {
            let sourceFrame = sourceNode.view.convert(sourceNode.bounds, to: self.view)
            self.contentContainerNode.layer.animateFrame(from: sourceFrame, to: self.contentContainerNode.frame, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
        }
        
        for sourceNode in self.sourceNodes {
            if let snapshot = sourceNode.view.snapshotContentTree() {
                snapshot.frame = sourceNode.view.convert(sourceNode.bounds, to: self.view)
                snapshot.isUserInteractionEnabled = false
                self.view.addSubview(snapshot)
                self.snapshotViews.append(snapshot)
            }
            sourceNode.alpha = 0.0
        }
    }
    
    func animateOut(changedAccount: Bool, completion: @escaping () -> Void) {
        UIView.animate(withDuration: 0.3, animations: {
            if #available(iOS 9.0, *) {
                self.effectView.effect = nil
            } else {
                self.effectView.alpha = 0.0
            }
        }, completion: { [weak self] _ in
            if !changedAccount {
                if let strongSelf = self {
                    for sourceNode in strongSelf.sourceNodes {
                        sourceNode.alpha = 1.0
                    }
                }
            }
            
            completion()
        })
        self.contentContainerNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.12, removeOnCompletion: false, completion: { _ in
        })
        if let _ = self.validLayout, let sourceNode = self.sourceNodes.first {
            let sourceFrame = sourceNode.view.convert(sourceNode.bounds, to: self.view)
            self.contentContainerNode.layer.animateFrame(from: self.contentContainerNode.frame, to: sourceFrame, duration: 0.15, timingFunction: kCAMediaTimingFunctionEaseIn, removeOnCompletion: false)
        }
        if changedAccount {
            for sourceNode in self.sourceNodes {
                sourceNode.alpha = 1.0
                sourceNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
            }
            for snapshotView in self.snapshotViews {
                snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false)
            }
        }
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        self.validLayout = layout
        
        transition.updateFrame(view: self.effectView, frame: CGRect(origin: CGPoint(), size: layout.size))
        transition.updateFrame(node: self.tapNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        
        let sideInset: CGFloat = 18.0
        
        var contentSize = CGSize()
        contentSize.width = min(layout.size.width - 40.0, 250.0)
        var applyNodes: [(ASDisplayNode, CGFloat, (CGFloat) -> Void)] = []
        for itemNode in self.contentNodes {
            let (width, height, apply) = itemNode.updateLayout(maxWidth: layout.size.width - sideInset * 2.0)
            applyNodes.append((itemNode, height, apply))
            contentSize.width = max(contentSize.width, width)
            contentSize.height += height
        }
        
        let contentOrigin = CGPoint(x: layout.size.width - sideInset - contentSize.width, y: layout.size.height - 66.0 - layout.intrinsicInsets.bottom - contentSize.height)
        transition.updateFrame(node: self.contentContainerNode, frame: CGRect(origin: contentOrigin, size: contentSize))
        var nextY: CGFloat = 0.0
        for (itemNode, height, apply) in applyNodes {
            transition.updateFrame(node: itemNode, frame: CGRect(origin: CGPoint(x: 0.0, y: nextY), size: CGSize(width: contentSize.width, height: height)))
            apply(contentSize.width)
            nextY += height
        }
    }
    
    @objc private func dimTapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.cancel()
        }
    }
}
