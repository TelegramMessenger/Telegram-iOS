import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import Postbox
import SwiftSignalKit
import TelegramPresentationData
import AvatarNode
import PeerOnlineMarkerNode
import LegacyComponents
import ContextUI
import LocalizedPeerData
import AccountContext
import CheckNode
import ComponentFlow
import EmojiStatusComponent
import AnimationCache
import MultiAnimationRenderer
import TelegramUIPreferences

private let avatarFont = avatarPlaceholderFont(size: 24.0)
private let textFont = Font.regular(11.0)

public final class SelectablePeerNodeTheme {
    let textColor: UIColor
    let secretTextColor: UIColor
    let selectedTextColor: UIColor
    let checkBackgroundColor: UIColor
    let checkFillColor: UIColor
    let checkColor: UIColor
    let avatarPlaceholderColor: UIColor
    
    public init(textColor: UIColor, secretTextColor: UIColor, selectedTextColor: UIColor, checkBackgroundColor: UIColor, checkFillColor: UIColor, checkColor: UIColor, avatarPlaceholderColor: UIColor) {
        self.textColor = textColor
        self.secretTextColor = secretTextColor
        self.selectedTextColor = selectedTextColor
        self.checkBackgroundColor = checkBackgroundColor
        self.checkFillColor = checkFillColor
        self.checkColor = checkColor
        self.avatarPlaceholderColor = avatarPlaceholderColor
    }
    
    public func isEqual(to: SelectablePeerNodeTheme) -> Bool {
        if self === to {
            return true
        }
        if !self.textColor.isEqual(to.textColor) {
            return false
        }
        if !self.secretTextColor.isEqual(to.secretTextColor) {
            return false
        }
        if !self.selectedTextColor.isEqual(to.selectedTextColor) {
            return false
        }
        if !self.checkBackgroundColor.isEqual(to.checkBackgroundColor) {
            return false
        }
        if !self.checkFillColor.isEqual(to.checkFillColor) {
            return false
        }
        if !self.checkColor.isEqual(to.checkColor) {
            return false
        }
        if !self.avatarPlaceholderColor.isEqual(to.avatarPlaceholderColor) {
            return false
        }
        return true
    }
}

public final class SelectablePeerNode: ASDisplayNode {
    public enum StoryMode {
        case createStory
        case repostStory
        case repostMessage
    }
    
    private let contextContainer: ContextControllerSourceNode
    private let avatarSelectionNode: ASImageNode
    private let avatarNodeContainer: ASDisplayNode
    private let avatarNode: AvatarNode
    private var avatarBadgeOutline: UIImageView?
    private var avatarBadge: UIImageView?
    private var avatarBadgeLabel: ImmediateTextView?
    private let onlineNode: PeerOnlineMarkerNode
    private var checkNode: CheckNode?
    private let textNode: ImmediateTextNode
    
    private let iconView: ComponentView<Empty>

    public var toggleSelection: ((Bool) -> Void)?
    public var contextAction: ((ASDisplayNode, ContextGesture?, CGPoint?) -> Void)? {
        didSet {
            self.contextContainer.isGestureEnabled = self.contextAction != nil
        }
    }
    
    private var currentSelected = false
    
    private var peer: EngineRenderedPeer?
    private var requiresPremiumForMessaging: Bool = false
    
    public var compact = false
    
    public var theme: SelectablePeerNodeTheme = SelectablePeerNodeTheme(textColor: .black, secretTextColor: .green, selectedTextColor: .blue, checkBackgroundColor: .white, checkFillColor: .blue, checkColor: .white, avatarPlaceholderColor: .white) {
        didSet {
            if !self.theme.isEqual(to: oldValue) {
                if let peer = self.peer, let mainPeer = peer.chatMainPeer {
                    self.textNode.attributedText = NSAttributedString(string: mainPeer.debugDisplayTitle, font: textFont, textColor: self.currentSelected ? self.theme.selectedTextColor : (peer.peerId.namespace == Namespaces.Peer.SecretChat ? self.theme.secretTextColor : self.theme.textColor), paragraphAlignment: .center)
                }
            }
        }
    }
    
    override public init() {
        self.contextContainer = ContextControllerSourceNode()
        self.contextContainer.isGestureEnabled = false
        
        self.avatarNodeContainer = ASDisplayNode()
        
        self.avatarSelectionNode = ASImageNode()
        self.avatarSelectionNode.isLayerBacked = true
        self.avatarSelectionNode.displayWithoutProcessing = true
        self.avatarSelectionNode.displaysAsynchronously = false
        self.avatarSelectionNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: 60.0, height: 60.0))
        self.avatarSelectionNode.alpha = 0.0
        
        self.avatarNode = AvatarNode(font: avatarFont)
        self.avatarNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: 60.0, height: 60.0))
        
        self.textNode = ImmediateTextNode()
        self.textNode.isUserInteractionEnabled = false
        self.textNode.displaysAsynchronously = false
        
        self.onlineNode = PeerOnlineMarkerNode()
        
        self.iconView = ComponentView<Empty>()
        
        super.init()
        
        self.addSubnode(self.contextContainer)
        self.avatarNodeContainer.addSubnode(self.avatarSelectionNode)
        self.avatarNodeContainer.addSubnode(self.avatarNode)
        self.contextContainer.addSubnode(self.avatarNodeContainer)
        self.contextContainer.addSubnode(self.textNode)
        self.contextContainer.addSubnode(self.onlineNode)
        
        self.contextContainer.activated = { [weak self] gesture, _ in
            guard let strongSelf = self, let contextAction = strongSelf.contextAction else {
                gesture.cancel()
                return
            }
            contextAction(strongSelf.contextContainer, gesture, nil)
        }
    }
    
    public func setup(context: AccountContext, theme: PresentationTheme, strings: PresentationStrings, peer: EngineRenderedPeer, requiresPremiumForMessaging: Bool, requiresStars: Int64? = nil, customTitle: String? = nil, iconId: Int64? = nil, iconColor: Int32? = nil, online: Bool = false, numberOfLines: Int = 2, synchronousLoad: Bool) {
        self.setup(
            accountPeerId: context.account.peerId,
            postbox: context.account.postbox,
            network: context.account.network,
            energyUsageSettings: context.sharedContext.energyUsageSettings,
            contentSettings: context.currentContentSettings.with { $0 },
            animationCache: context.animationCache,
            animationRenderer: context.animationRenderer,
            resolveInlineStickers: { fileIds in
                return context.engine.stickers.resolveInlineStickers(fileIds: fileIds)
            },
            theme: theme,
            strings: strings,
            peer: peer,
            requiresPremiumForMessaging: requiresPremiumForMessaging,
            requiresStars: requiresStars,
            customTitle: customTitle,
            iconId: iconId,
            iconColor: iconColor,
            online: online,
            numberOfLines: numberOfLines,
            synchronousLoad: synchronousLoad
        )
    }
    
    public func setupStoryRepost(accountPeerId: EnginePeer.Id, postbox: Postbox, network: Network, theme: PresentationTheme, strings: PresentationStrings, synchronousLoad: Bool, storyMode: StoryMode) {
        self.peer = nil
        
        let title: String
        let overrideImage: AvatarNodeImageOverride

        switch storyMode {
        case .createStory:
            title = strings.Share_PostToStory
            overrideImage = .storyIcon
        case .repostStory:
            title = strings.Share_RepostStory
            overrideImage = .repostIcon
        case .repostMessage:
            title = strings.Share_RepostToStory
            overrideImage = .repostIcon
        }
        
        self.textNode.maximumNumberOfLines = 2
        self.textNode.attributedText = NSAttributedString(string: title, font: textFont, textColor: self.theme.textColor, paragraphAlignment: .center)
        self.avatarNode.setPeer(accountPeerId: accountPeerId, postbox: postbox, network: network, contentSettings: ContentSettings.default, theme: theme, peer: nil, overrideImage: overrideImage, emptyColor: self.theme.avatarPlaceholderColor, clipStyle: .round, synchronousLoad: synchronousLoad)
        
        if case .repostIcon = overrideImage {
            self.avatarNode.playRepostAnimation()
        }
    }
    
    public func setup(accountPeerId: EnginePeer.Id, postbox: Postbox, network: Network, energyUsageSettings: EnergyUsageSettings, contentSettings: ContentSettings, animationCache: AnimationCache, animationRenderer: MultiAnimationRenderer, resolveInlineStickers: @escaping ([Int64]) -> Signal<[Int64: TelegramMediaFile], NoError>, theme: PresentationTheme, strings: PresentationStrings, peer: EngineRenderedPeer, requiresPremiumForMessaging: Bool, requiresStars: Int64? = nil, customTitle: String? = nil, iconId: Int64? = nil, iconColor: Int32? = nil, online: Bool = false, numberOfLines: Int = 2, synchronousLoad: Bool) {
        let isFirstTime = self.peer == nil
        self.peer = peer
        guard let mainPeer = peer.chatOrMonoforumMainPeer else {
            return
        }
        
        self.requiresPremiumForMessaging = requiresPremiumForMessaging
        
        let defaultColor: UIColor
        if requiresPremiumForMessaging {
            defaultColor = self.theme.textColor.withMultipliedAlpha(0.4)
        } else {
            defaultColor = peer.peerId.namespace == Namespaces.Peer.SecretChat ? self.theme.secretTextColor : self.theme.textColor
        }
        
        var isForum = false
        var isMonoforum = false
        if let peer = peer.chatMainPeer, case let .channel(channel) = peer {
            isForum = channel.isForum
            isMonoforum = channel.isMonoForum
        }
        
        let text: String
        var overrideImage: AvatarNodeImageOverride?
        if peer.peerId == accountPeerId {
            text = self.compact ? strings.DeleteAccount_SavedMessages : strings.DialogList_SavedMessages
            overrideImage = .savedMessagesIcon
        } else if peer.peerId.isReplies {
            text = strings.DialogList_Replies
            overrideImage = .repliesIcon
        } else {
            text = mainPeer.compactDisplayTitle
            if mainPeer.isDeleted {
                overrideImage = .deletedIcon
            }
        }
        self.textNode.maximumNumberOfLines = numberOfLines
        self.textNode.attributedText = NSAttributedString(string: customTitle ?? text, font: textFont, textColor: self.currentSelected ? self.theme.selectedTextColor : defaultColor, paragraphAlignment: .center)
        let clipStyle: AvatarNodeClipStyle
        if isMonoforum {
            clipStyle = .bubble
        } else if isForum {
            clipStyle = .roundedRect
        } else {
            clipStyle = .round
        }
        self.avatarNode.setPeer(accountPeerId: accountPeerId, postbox: postbox, network: network, contentSettings: contentSettings, theme: theme, peer: mainPeer, overrideImage: overrideImage, emptyColor: self.theme.avatarPlaceholderColor, clipStyle: clipStyle, synchronousLoad: synchronousLoad)
        
        if let requiresStars {
            let avatarBadgeOutline: UIImageView
            if let current = self.avatarBadgeOutline {
                avatarBadgeOutline = current
            } else {
                avatarBadgeOutline = UIImageView()
                avatarBadgeOutline.contentMode = .scaleToFill
                avatarBadgeOutline.image = PresentationResourcesChatList.shareAvatarStarsLockBadgeBackground(theme)
                avatarBadgeOutline.tintColor = theme.actionSheet.opaqueItemBackgroundColor
                self.avatarBadgeOutline = avatarBadgeOutline
                self.avatarNodeContainer.view.addSubview(avatarBadgeOutline)
            }
            
            let avatarBadge: UIImageView
            if let current = self.avatarBadge {
                avatarBadge = current
            } else {
                avatarBadge = UIImageView()
                avatarBadge.contentMode = .scaleToFill
                avatarBadge.image = PresentationResourcesChatList.shareAvatarStarsLockBadgeInnerBackground(theme)
                avatarBadge.tintColor = theme.actionSheet.controlAccentColor
                self.avatarBadge = avatarBadge
                self.avatarNodeContainer.view.addSubview(avatarBadge)
            }
            
            let avatarBadgeLabel: ImmediateTextView
            if let current = self.avatarBadgeLabel {
                avatarBadgeLabel = current
            } else {
                avatarBadgeLabel = ImmediateTextView()
                self.avatarBadgeLabel = avatarBadgeLabel
                self.avatarNodeContainer.view.addSubview(avatarBadgeLabel)
            }
            
            let badgeString = NSMutableAttributedString(string: "⭐️\(presentationStringsFormattedNumber(Int32(requiresStars), " "))", font: Font.with(size: 9.0, design: .round , weight: .bold), textColor: theme.list.itemCheckColors.foregroundColor)
            if let range = badgeString.string.range(of: "⭐️") {
                badgeString.addAttribute(.attachment, value: UIImage(bundleImageName: "Premium/SendStarsPeerBadgeStarIcon")!, range: NSRange(range, in: badgeString.string))
                badgeString.addAttribute(.baselineOffset, value: 1.5, range: NSRange(range, in: badgeString.string))
                badgeString.addAttribute(.kern, value: -0.8, range: NSRange(badgeString.string.startIndex ..< badgeString.string.endIndex, in: badgeString.string))
            }
            avatarBadgeLabel.attributedText = badgeString
            
            let avatarFrame = self.avatarNode.frame
            let badgeSize = avatarBadgeLabel.updateLayout(avatarFrame.size)
            var badgeFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((avatarFrame.width - badgeSize.width) / 2.0) - (self.currentSelected ? 15.0 : 0.0), y: avatarFrame.height - 13.0), size: badgeSize)
            let badgeBackgroundFrame = CGRect(origin: CGPoint(x: badgeFrame.minX - 2.0, y: badgeFrame.minY - 3.0 - UIScreenPixel), size: CGSize(width: badgeFrame.width + 4.0, height: 16.0))
            let badgeOutlineFrame = CGRect(origin: CGPoint(x: badgeBackgroundFrame.minX - 2.0, y: badgeBackgroundFrame.minY - 2.0), size: CGSize(width: badgeBackgroundFrame.width + 4.0, height: 20.0))
            badgeFrame = badgeFrame.offsetBy(dx: -2.0, dy: 0.0)
            
            avatarBadge.frame = badgeBackgroundFrame
            avatarBadgeOutline.frame = badgeOutlineFrame
            avatarBadgeLabel.frame = badgeFrame
        } else if requiresPremiumForMessaging {
            let avatarBadgeOutline: UIImageView
            if let current = self.avatarBadgeOutline {
                avatarBadgeOutline = current
            } else {
                avatarBadgeOutline = UIImageView()
                avatarBadgeOutline.image = PresentationResourcesChatList.shareAvatarPremiumLockBadgeBackground(theme)
                avatarBadgeOutline.tintColor = theme.chatList.itemBackgroundColor
                self.avatarBadgeOutline = avatarBadgeOutline
                self.avatarNode.view.addSubview(avatarBadgeOutline)
            }
            
            let avatarBadge: UIImageView
            if let current = self.avatarBadge {
                avatarBadge = current
            } else {
                avatarBadge = UIImageView()
                avatarBadge.image = PresentationResourcesChatList.shareAvatarPremiumLockBadge(theme)
                self.avatarBadge = avatarBadge
                self.avatarNode.view.addSubview(avatarBadge)
            }
            
            let avatarFrame = self.avatarNode.frame
            let badgeFrame = CGRect(origin: CGPoint(x: avatarFrame.width - 20.0, y: avatarFrame.height - 20.0), size: CGSize(width: 20.0, height: 20.0))
            let badgeBackgroundFrame = badgeFrame.insetBy(dx: -2.0, dy: -2.0)
            
            avatarBadgeOutline.frame = badgeBackgroundFrame
            avatarBadge.frame = badgeFrame
        } else {
            if let avatarBadgeOutline = self.avatarBadgeOutline {
                self.avatarBadgeOutline = nil
                avatarBadgeOutline.removeFromSuperview()
            }
            if let avatarBadge = self.avatarBadge {
                self.avatarBadge = nil
                avatarBadge.removeFromSuperview()
            }
            if let avatarBadgeLabel = self.avatarBadgeLabel {
                self.avatarBadgeLabel = nil
                avatarBadgeLabel.removeFromSuperview()
            }
        }
        
        let onlineLayout = self.onlineNode.asyncLayout()
        let (onlineSize, onlineApply) = onlineLayout(online, false)
        let _ = onlineApply(!isFirstTime)
        
        self.onlineNode.setImage(PresentationResourcesChatList.recentStatusOnlineIcon(theme, state: .panel), color: nil, transition: .immediate)
        self.onlineNode.frame = CGRect(origin: CGPoint(), size: onlineSize)
        
        let iconContent: EmojiStatusComponent.Content?
        if let fileId = iconId {
            iconContent = .animation(content: .customEmoji(fileId: fileId), size: CGSize(width: 18.0, height: 18.0), placeholderColor: theme.actionSheet.disabledActionTextColor, themeColor: theme.actionSheet.primaryTextColor, loopMode: .count(0))
        } else if let customTitle = customTitle {
            iconContent = .topic(title: String(customTitle.prefix(1)), color: iconColor ?? 0, size: CGSize(width: 32.0, height: 32.0))
        } else {
            iconContent = nil
        }
                
        if let iconContent = iconContent {
            let iconSize = self.iconView.update(
                transition: .easeInOut(duration: 0.2),
                component: AnyComponent(EmojiStatusComponent(
                    postbox: postbox,
                    energyUsageSettings: energyUsageSettings,
                    resolveInlineStickers: resolveInlineStickers,
                    animationCache: animationCache,
                    animationRenderer: animationRenderer,
                    content: iconContent,
                    isVisibleForAnimations: true,
                    action: nil
                )),
                environment: {},
                containerSize: CGSize(width: 18.0, height: 18.0)
            )
            
            if let iconComponentView = self.iconView.view {
                if iconComponentView.superview == nil {
                    self.view.addSubview(iconComponentView)
                }
                iconComponentView.frame = CGRect(origin: .zero, size: iconSize)
            }
        } else if let iconComponentView = self.iconView.view {
            iconComponentView.removeFromSuperview()
        }
        
        self.setNeedsLayout()
    }
    
    public func updateSelection(selected: Bool, animated: Bool) {
        if selected != self.currentSelected {
            self.currentSelected = selected
            
            if let attributedText = self.textNode.attributedText {
                self.textNode.attributedText = NSAttributedString(string: attributedText.string, font: textFont, textColor: selected ? self.theme.selectedTextColor : (self.peer?.peerId.namespace == Namespaces.Peer.SecretChat ? self.theme.secretTextColor : self.theme.textColor), paragraphAlignment: .center)
            }
            
            var isForum = false
            if let peer = self.peer?.chatMainPeer, case let .channel(channel) = peer, channel.isForumOrMonoForum {
                isForum = true
            }
            
            if selected {
                self.avatarNode.transform = CATransform3DMakeScale(0.866666, 0.866666, 1.0)
                self.avatarSelectionNode.alpha = 1.0
                self.avatarSelectionNode.image = generateImage(CGSize(width: 60.0 + 4.0, height: 60.0 + 4.0), rotatedContext: { size, context in
                    context.clear(CGRect(origin: CGPoint(), size: size))
                    let bounds = CGRect(origin: .zero, size: size)
                    if isForum {
                        context.setStrokeColor(self.theme.selectedTextColor.cgColor)
                        context.setLineWidth(2.0)
                        context.addPath(UIBezierPath(roundedRect: bounds.insetBy(dx: 1.0, dy: 1.0), cornerRadius: floorToScreenPixels(bounds.size.width * 0.26)).cgPath)
                        context.strokePath()
                    } else {
                        context.setFillColor(self.theme.selectedTextColor.cgColor)
                        context.fillEllipse(in: bounds)
                        context.setBlendMode(.copy)
                        context.setFillColor(UIColor.clear.cgColor)
                        context.fillEllipse(in: bounds.insetBy(dx: 2.0, dy: 2.0))
                    }
                })
                
                if let avatarBadgeLabel = self.avatarBadgeLabel, let avatarBadge = self.avatarBadge, let avatarBadgeOutline = self.avatarBadgeOutline {
                    avatarBadgeLabel.center = CGPoint(x: self.avatarNode.bounds.width / 2.0 - 17.0, y: avatarBadgeLabel.center.y)
                    avatarBadge.center = CGPoint(x: self.avatarNode.bounds.width / 2.0 - 15.0, y: avatarBadge.center.y)
                    avatarBadgeOutline.center = CGPoint(x: self.avatarNode.bounds.width / 2.0 - 15.0, y: avatarBadgeOutline.center.y)
                    
                    if animated {
                        avatarBadgeLabel.layer.animatePosition(from: CGPoint(x: 15.0, y: 0.0), to: .zero, duration: 0.2, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
                        avatarBadge.layer.animatePosition(from: CGPoint(x: 15.0, y: 0.0), to: .zero, duration: 0.2, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
                        avatarBadgeOutline.layer.animatePosition(from: CGPoint(x: 15.0, y: 0.0), to: .zero, duration: 0.2, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
                    }
                }
                
                if animated {
                    self.avatarNode.layer.animateScale(from: 1.0, to: 0.866666, duration: 0.2, timingFunction: kCAMediaTimingFunctionSpring)
                    self.avatarSelectionNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
                }
            } else {
                self.avatarNode.transform = CATransform3DIdentity
                self.avatarSelectionNode.alpha = 0.0
                if animated {
                    self.avatarNode.layer.animateScale(from: 0.866666, to: 1.0, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring)
                    self.avatarSelectionNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.28, completion: { [weak avatarSelectionNode] _ in
                        avatarSelectionNode?.image = nil
                    })
                } else {
                    self.avatarSelectionNode.image = nil
                }
                
                if let avatarBadgeLabel = self.avatarBadgeLabel, let avatarBadge = self.avatarBadge, let avatarBadgeOutline = self.avatarBadgeOutline {
                    avatarBadgeLabel.center = CGPoint(x: self.avatarNode.bounds.width / 2.0 - 2.0, y: avatarBadgeLabel.center.y)
                    avatarBadge.center = CGPoint(x: self.avatarNode.bounds.width / 2.0, y: avatarBadge.center.y)
                    avatarBadgeOutline.center = CGPoint(x: self.avatarNode.bounds.width / 2.0, y: avatarBadgeOutline.center.y)
                    
                    if animated {
                        avatarBadgeLabel.layer.animatePosition(from: CGPoint(x: -15.0, y: 0.0), to: .zero, duration: 0.2, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
                        avatarBadge.layer.animatePosition(from: CGPoint(x: -15.0, y: 0.0), to: .zero, duration: 0.2, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
                        avatarBadgeOutline.layer.animatePosition(from: CGPoint(x: -15.0, y: 0.0), to: .zero, duration: 0.2, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
                    }
                }
            }
            
            if selected {
                if self.checkNode == nil {
                    let checkNode = CheckNode(theme: CheckNodeTheme(backgroundColor: self.theme.checkFillColor, strokeColor: self.theme.checkColor, borderColor: self.theme.checkBackgroundColor, overlayBorder: true, hasInset: false, hasShadow: false, filledBorder: true, borderWidth: 2.0))
                    self.checkNode = checkNode
                    checkNode.isUserInteractionEnabled = false
                    self.addSubnode(checkNode)
                    
                    let avatarFrame = self.avatarNode.frame
                    let checkSize = CGSize(width: 22.0, height: 22.0)
                    checkNode.frame = CGRect(origin: CGPoint(x: avatarFrame.maxX - 14.0, y: avatarFrame.maxY - 15.0), size: checkSize)
                    checkNode.setSelected(true, animated: animated)
                }
            } else if let checkNode = self.checkNode {
                self.checkNode = nil
                checkNode.setSelected(false, animated: animated)
            }
            self.setNeedsLayout()
        }
    }
    
    override public func didLoad() {
        super.didLoad()
        
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
    }
    
    @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.toggleSelection?(self.requiresPremiumForMessaging)
        }
    }
    
    override public func layout() {
        super.layout()
        
        let bounds = self.bounds
        
        self.contextContainer.frame = bounds
        
        self.avatarNodeContainer.frame = CGRect(origin: CGPoint(x: floor((bounds.size.width - 60.0) / 2.0), y: 4.0), size: CGSize(width: 60.0, height: 60.0))
        
        let iconSize = CGSize(width: 18.0, height: 18.0)
        let textSize = self.textNode.updateLayout(bounds.size)
        var totalWidth = textSize.width
        var leftOrigin = floorToScreenPixels((bounds.width - textSize.width) / 2.0)
        if let iconView = self.iconView.view, iconView.superview != nil {
            totalWidth += iconView.frame.width + 2.0
            leftOrigin = floorToScreenPixels((bounds.width - totalWidth) / 2.0)
            iconView.frame = CGRect(origin: CGPoint(x: leftOrigin, y: 4.0 + 60.0 + 4.0 + floorToScreenPixels((textSize.height - iconSize.height) / 2.0)), size: iconSize)
            leftOrigin += iconSize.width + 2.0
        }
        self.textNode.frame = CGRect(origin: CGPoint(x: leftOrigin, y: 4.0 + 60.0 + 4.0), size: textSize)
        
        let avatarFrame = self.avatarNode.frame
        let avatarContainerFrame = self.avatarNodeContainer.frame
        
        self.onlineNode.frame = CGRect(origin: CGPoint(x: avatarContainerFrame.maxX - self.onlineNode.frame.width - 2.0, y: avatarContainerFrame.maxY - self.onlineNode.frame.height - 2.0), size: self.onlineNode.frame.size)
        
        if let checkNode = self.checkNode {
            let checkSize = CGSize(width: 22.0, height: 22.0)
            checkNode.frame = CGRect(origin: CGPoint(x: avatarFrame.maxX - 14.0, y: avatarFrame.maxY - 15.0), size: checkSize)
        }
    }
}
