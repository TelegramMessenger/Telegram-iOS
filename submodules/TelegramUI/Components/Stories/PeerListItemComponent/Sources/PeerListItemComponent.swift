import Foundation
import UIKit
import Display
import AsyncDisplayKit
import ComponentFlow
import SwiftSignalKit
import AccountContext
import TelegramCore
import Postbox
import MultilineTextComponent
import AvatarNode
import TelegramPresentationData
import CheckNode
import TelegramStringFormatting
import AppBundle
import PeerPresenceStatusManager
import EmojiStatusComponent

private let avatarFont = avatarPlaceholderFont(size: 15.0)
private let readIconImage: UIImage? = generateTintedImage(image: UIImage(bundleImageName: "Chat/Message/MenuReadIcon"), color: .white)?.withRenderingMode(.alwaysTemplate)

public final class PeerListItemComponent: Component {
    public final class TransitionHint {
        public let synchronousLoad: Bool
        
        public init(synchronousLoad: Bool) {
            self.synchronousLoad = synchronousLoad
        }
    }
    
    public enum Style {
        case generic
        case compact
    }
    
    public enum SelectionState: Equatable {
        case none
        case editing(isSelected: Bool, isTinted: Bool)
    }
    
    public enum SubtitleAccessory: Equatable {
        case none
        case checks
    }
    
    let context: AccountContext
    let theme: PresentationTheme
    let strings: PresentationStrings
    let style: Style
    let sideInset: CGFloat
    let title: String
    let peer: EnginePeer?
    let storyStats: PeerStoryStats?
    let subtitle: String?
    let subtitleAccessory: SubtitleAccessory
    let presence: EnginePeer.Presence?
    let selectionState: SelectionState
    let hasNext: Bool
    let action: (EnginePeer) -> Void
    let openStories: ((EnginePeer, AvatarNode) -> Void)?
    
    public init(
        context: AccountContext,
        theme: PresentationTheme,
        strings: PresentationStrings,
        style: Style,
        sideInset: CGFloat,
        title: String,
        peer: EnginePeer?,
        storyStats: PeerStoryStats? = nil,
        subtitle: String?,
        subtitleAccessory: SubtitleAccessory,
        presence: EnginePeer.Presence?,
        selectionState: SelectionState,
        hasNext: Bool,
        action: @escaping (EnginePeer) -> Void,
        openStories: ((EnginePeer, AvatarNode) -> Void)? = nil
    ) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.style = style
        self.sideInset = sideInset
        self.title = title
        self.peer = peer
        self.storyStats = storyStats
        self.subtitle = subtitle
        self.subtitleAccessory = subtitleAccessory
        self.presence = presence
        self.selectionState = selectionState
        self.hasNext = hasNext
        self.action = action
        self.openStories = openStories
    }
    
    public static func ==(lhs: PeerListItemComponent, rhs: PeerListItemComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.style != rhs.style {
            return false
        }
        if lhs.sideInset != rhs.sideInset {
            return false
        }
        if lhs.title != rhs.title {
            return false
        }
        if lhs.peer != rhs.peer {
            return false
        }
        if lhs.storyStats != rhs.storyStats {
            return false
        }
        if lhs.subtitle != rhs.subtitle {
            return false
        }
        if lhs.subtitleAccessory != rhs.subtitleAccessory {
            return false
        }
        if lhs.presence != rhs.presence {
            return false
        }
        if lhs.selectionState != rhs.selectionState {
            return false
        }
        if lhs.hasNext != rhs.hasNext {
            return false
        }
        return true
    }
    
    public final class View: UIView {
        private let containerButton: HighlightTrackingButton
        
        private let title = ComponentView<Empty>()
        private let label = ComponentView<Empty>()
        private let separatorLayer: SimpleLayer
        private let avatarNode: AvatarNode
        private let avatarButtonView: HighlightTrackingButton
        private var avatarIcon: ComponentView<Empty>?
        
        private var iconView: UIImageView?
        private var checkLayer: CheckLayer?
        
        private var component: PeerListItemComponent?
        private weak var state: EmptyComponentState?
        
        private var presenceManager: PeerPresenceStatusManager?
        
        public var avatarFrame: CGRect {
            return self.avatarNode.frame
        }
        
        public var titleFrame: CGRect? {
            return self.title.view?.frame
        }
        
        public var labelFrame: CGRect? {
            guard var value = self.label.view?.frame else {
                return nil
            }
            if let iconView = self.iconView {
                value.size.width += value.minX - iconView.frame.minX
                value.origin.x = iconView.frame.minX
            }
            return value
        }
        
        override init(frame: CGRect) {
            self.separatorLayer = SimpleLayer()
            
            self.containerButton = HighlightTrackingButton()
            self.containerButton.isExclusiveTouch = true
            
            self.avatarNode = AvatarNode(font: avatarFont)
            self.avatarNode.isLayerBacked = false
            
            self.avatarButtonView = HighlightTrackingButton()
            
            super.init(frame: frame)
            
            self.layer.addSublayer(self.separatorLayer)
            self.addSubview(self.containerButton)
            self.containerButton.layer.addSublayer(self.avatarNode.layer)
            
            self.containerButton.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
            
            self.addSubview(self.avatarButtonView)
            self.avatarButtonView.addTarget(self, action: #selector(self.avatarButtonPressed), for: .touchUpInside)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        @objc private func pressed() {
            guard let component = self.component, let peer = component.peer else {
                return
            }
            component.action(peer)
        }
        
        @objc private func avatarButtonPressed() {
            guard let component = self.component, let peer = component.peer else {
                return
            }
            component.openStories?(peer, self.avatarNode)
        }
        
        func update(component: PeerListItemComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            var synchronousLoad = false
            if let hint = transition.userData(TransitionHint.self) {
                synchronousLoad = hint.synchronousLoad
            }
            
            let themeUpdated = self.component?.theme !== component.theme
            
            var hasSelectionUpdated = false
            if let previousComponent = self.component {
                switch previousComponent.selectionState {
                case .none:
                    if case .none = component.selectionState {
                    } else {
                        hasSelectionUpdated = true
                    }
                case .editing:
                    if case .editing = component.selectionState {
                    } else {
                        hasSelectionUpdated = true
                    }
                }
            }
            
            if let presence = component.presence {
                let presenceManager: PeerPresenceStatusManager
                if let current = self.presenceManager {
                    presenceManager = current
                } else {
                    presenceManager = PeerPresenceStatusManager(update: { [weak self] in
                        self?.state?.updated(transition: .immediate)
                    })
                    self.presenceManager = presenceManager
                }
                presenceManager.reset(presence: presence)
            } else {
                if self.presenceManager != nil {
                    self.presenceManager = nil
                }
            }
            
            self.component = component
            self.state = state
            
            self.avatarButtonView.isUserInteractionEnabled = component.storyStats != nil
            
            let labelData: (String, Bool)
            if let presence = component.presence {
                let timestamp = CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970
                labelData = stringAndActivityForUserPresence(strings: component.strings, dateTimeFormat: PresentationDateTimeFormat(), presence: presence, relativeTo: Int32(timestamp))
            } else if let subtitle = component.subtitle {
                labelData = (subtitle, false)
            } else {
                labelData = ("", false)
            }
            
            let contextInset: CGFloat = 0.0
            
            let height: CGFloat
            let titleFont: UIFont
            let subtitleFont: UIFont
            switch component.style {
            case .generic:
                titleFont = Font.semibold(17.0)
                subtitleFont = Font.regular(15.0)
                if labelData.0.isEmpty {
                    height = 50.0
                } else {
                    height = 60.0
                }
            case .compact:
                titleFont = Font.semibold(14.0)
                subtitleFont = Font.regular(14.0)
                height = 42.0
            }
            
            let verticalInset: CGFloat = 1.0
            var leftInset: CGFloat = 53.0 + component.sideInset
            if case .generic = component.style {
                leftInset += 9.0
            }
            let rightInset: CGFloat = contextInset * 2.0 + 8.0 + component.sideInset
            var avatarLeftInset: CGFloat = component.sideInset + 10.0
            
            if case let .editing(isSelected, isTinted) = component.selectionState {
                leftInset += 44.0
                avatarLeftInset += 44.0
                let checkSize: CGFloat = 22.0
                
                let checkLayer: CheckLayer
                if let current = self.checkLayer {
                    checkLayer = current
                    if themeUpdated {
                        var theme = CheckNodeTheme(theme: component.theme, style: .plain)
                        if isTinted {
                            theme.backgroundColor = theme.backgroundColor.mixedWith(component.theme.list.itemBlocksBackgroundColor, alpha: 0.5)
                        }
                        checkLayer.theme = theme
                    }
                    checkLayer.setSelected(isSelected, animated: !transition.animation.isImmediate)
                } else {
                    var theme = CheckNodeTheme(theme: component.theme, style: .plain)
                    if isTinted {
                        theme.backgroundColor = theme.backgroundColor.mixedWith(component.theme.list.itemBlocksBackgroundColor, alpha: 0.5)
                    }
                    checkLayer = CheckLayer(theme: theme)
                    self.checkLayer = checkLayer
                    self.containerButton.layer.addSublayer(checkLayer)
                    checkLayer.frame = CGRect(origin: CGPoint(x: -checkSize, y: floor((height - verticalInset * 2.0 - checkSize) / 2.0)), size: CGSize(width: checkSize, height: checkSize))
                    checkLayer.setSelected(isSelected, animated: false)
                    checkLayer.setNeedsDisplay()
                }
                transition.setFrame(layer: checkLayer, frame: CGRect(origin: CGPoint(x: floor((54.0 - checkSize) * 0.5), y: floor((height - verticalInset * 2.0 - checkSize) / 2.0)), size: CGSize(width: checkSize, height: checkSize)))
            } else {
                if let checkLayer = self.checkLayer {
                    self.checkLayer = nil
                    transition.setPosition(layer: checkLayer, position: CGPoint(x: -checkLayer.bounds.width * 0.5, y: checkLayer.position.y), completion: { [weak checkLayer] _ in
                        checkLayer?.removeFromSuperlayer()
                    })
                }
            }
            
            let avatarSize: CGFloat = component.style == .compact ? 30.0 : 40.0
            
            let avatarFrame = CGRect(origin: CGPoint(x: avatarLeftInset, y: floor((height - verticalInset * 2.0 - avatarSize) / 2.0)), size: CGSize(width: avatarSize, height: avatarSize))
            if self.avatarNode.bounds.isEmpty {
                self.avatarNode.frame = avatarFrame
            } else {
                transition.setFrame(layer: self.avatarNode.layer, frame: avatarFrame)
            }
            
            transition.setFrame(view: self.avatarButtonView, frame: avatarFrame)
            
            var statusIcon: EmojiStatusComponent.Content?
            if let peer = component.peer {
                let clipStyle: AvatarNodeClipStyle
                if case let .channel(channel) = peer, channel.flags.contains(.isForum) {
                    clipStyle = .roundedRect
                } else {
                    clipStyle = .round
                }
                self.avatarNode.setPeer(context: component.context, theme: component.theme, peer: peer, clipStyle: clipStyle, synchronousLoad: synchronousLoad, displayDimensions: CGSize(width: avatarSize, height: avatarSize))
                self.avatarNode.setStoryStats(storyStats: component.storyStats.flatMap { storyStats -> AvatarNode.StoryStats in
                    return AvatarNode.StoryStats(
                        totalCount: storyStats.totalCount == 0 ? 0 : 1,
                        unseenCount: storyStats.unseenCount == 0 ? 0 : 1,
                        hasUnseenCloseFriendsItems: storyStats.hasUnseenCloseFriends
                    )
                }, presentationParams: AvatarNode.StoryPresentationParams(
                    colors: AvatarNode.Colors(theme: component.theme),
                    lineWidth: 1.33,
                    inactiveLineWidth: 1.33
                ), transition: transition)
                
                if peer.isScam {
                    statusIcon = .text(color: component.theme.chat.message.incoming.scamColor, string: component.strings.Message_ScamAccount.uppercased())
                } else if peer.isFake {
                    statusIcon = .text(color: component.theme.chat.message.incoming.scamColor, string: component.strings.Message_FakeAccount.uppercased())
                } else if case let .user(user) = peer, let emojiStatus = user.emojiStatus {
                    statusIcon = .animation(content: .customEmoji(fileId: emojiStatus.fileId), size: CGSize(width: 20.0, height: 20.0), placeholderColor: component.theme.list.mediaPlaceholderColor, themeColor: component.theme.list.itemAccentColor, loopMode: .count(2))
                } else if peer.isVerified {
                    statusIcon = .verified(fillColor: component.theme.list.itemCheckColors.fillColor, foregroundColor: component.theme.list.itemCheckColors.foregroundColor, sizeType: .compact)
                } else if peer.isPremium {
                    statusIcon = .premium(color: component.theme.list.itemAccentColor)
                }
            }
                        
            let previousTitleFrame = self.title.view?.frame
            var previousTitleContents: UIView?
            if hasSelectionUpdated && !"".isEmpty {
                previousTitleContents = self.title.view?.snapshotView(afterScreenUpdates: false)
            }
            
            let availableTextWidth = availableSize.width - leftInset - rightInset
            let titleAvailableWidth = component.style == .compact ? availableTextWidth * 0.7 : availableSize.width - leftInset - rightInset
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.title, font: titleFont, textColor: component.theme.list.itemPrimaryTextColor))
                )),
                environment: {},
                containerSize: CGSize(width: titleAvailableWidth, height: 100.0)
            )
            
            let labelAvailableWidth = component.style == .compact ? availableTextWidth - titleSize.width : availableSize.width - leftInset - rightInset
            let labelSize = self.label.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: labelData.0, font: subtitleFont, textColor: labelData.1 ? component.theme.list.itemAccentColor : component.theme.list.itemSecondaryTextColor))
                )),
                environment: {},
                containerSize: CGSize(width: labelAvailableWidth, height: 100.0)
            )
            
            let titleSpacing: CGFloat = 2.0
            var titleVerticalOffset: CGFloat = 0.0
            let centralContentHeight: CGFloat
            if labelSize.height > 0.0, case .generic = component.style {
                centralContentHeight = titleSize.height + labelSize.height + titleSpacing
                titleVerticalOffset = -1.0
            } else {
                centralContentHeight = titleSize.height
            }
            
            let titleFrame = CGRect(origin: CGPoint(x: leftInset, y: titleVerticalOffset + floor((height - verticalInset * 2.0 - centralContentHeight) / 2.0)), size: titleSize)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    titleView.isUserInteractionEnabled = false
                    self.containerButton.addSubview(titleView)
                }
                titleView.frame = titleFrame
                if let previousTitleFrame, previousTitleFrame.origin.x != titleFrame.origin.x {
                    transition.animatePosition(view: titleView, from: CGPoint(x: previousTitleFrame.origin.x - titleFrame.origin.x, y: 0.0), to: CGPoint(), additive: true)
                }
                
                if let previousTitleFrame, let previousTitleContents, previousTitleFrame.size != titleSize {
                    previousTitleContents.frame = CGRect(origin: previousTitleFrame.origin, size: previousTitleFrame.size)
                    self.addSubview(previousTitleContents)
                    
                    transition.setFrame(view: previousTitleContents, frame: CGRect(origin: titleFrame.origin, size: previousTitleFrame.size))
                    transition.setAlpha(view: previousTitleContents, alpha: 0.0, completion: { [weak previousTitleContents] _ in
                        previousTitleContents?.removeFromSuperview()
                    })
                    transition.animateAlpha(view: titleView, from: 0.0, to: 1.0)
                }
            }
            
            if let statusIcon, case .generic = component.style {
                let animationCache = component.context.animationCache
                let animationRenderer = component.context.animationRenderer
                
                let avatarIcon: ComponentView<Empty>
                var avatarIconTransition = transition
                if let current = self.avatarIcon {
                    avatarIcon = current
                } else {
                    avatarIconTransition = transition.withAnimation(.none)
                    avatarIcon = ComponentView<Empty>()
                    self.avatarIcon = avatarIcon
                }
                
                let avatarIconComponent = EmojiStatusComponent(
                    context: component.context,
                    animationCache: animationCache,
                    animationRenderer: animationRenderer,
                    content: statusIcon,
                    isVisibleForAnimations: true,
                    action: nil,
                    emojiFileUpdated: nil
                )
                let iconSize = avatarIcon.update(
                    transition: avatarIconTransition,
                    component: AnyComponent(avatarIconComponent),
                    environment: {},
                    containerSize: CGSize(width: 20.0, height: 20.0)
                )
                
                if let avatarIconView = avatarIcon.view {
                    if avatarIconView.superview == nil {
                        avatarIconView.isUserInteractionEnabled = false
                        self.containerButton.addSubview(avatarIconView)
                    }
                    avatarIconTransition.setFrame(view: avatarIconView, frame: CGRect(origin: CGPoint(x: titleFrame.maxX + 4.0, y: floorToScreenPixels(titleFrame.midY - iconSize.height / 2.0)), size: iconSize))
                }
            } else if let avatarIcon = self.avatarIcon {
                self.avatarIcon = nil
                avatarIcon.view?.removeFromSuperview()
            }
            
            if let labelView = self.label.view {
                var iconLabelOffset: CGFloat = 0.0
                
                if case .checks = component.subtitleAccessory {
                    let iconView: UIImageView
                    if let current = self.iconView {
                        iconView = current
                    } else {
                        iconView = UIImageView(image: readIconImage)
                        iconView.tintColor = component.theme.list.itemSecondaryTextColor
                        self.iconView = iconView
                        self.containerButton.addSubview(iconView)
                    }
                    
                    if let image = iconView.image {
                        iconLabelOffset = image.size.width + 4.0
                        transition.setFrame(view: iconView, frame: CGRect(origin: CGPoint(x: titleFrame.minX, y: titleFrame.maxY + titleSpacing + 3.0 + floor((labelSize.height - image.size.height) * 0.5)), size: image.size))
                    }
                } else if let iconView = self.iconView {
                    self.iconView = nil
                    iconView.removeFromSuperview()
                }
                
                if labelView.superview == nil {
                    labelView.isUserInteractionEnabled = false
                    self.containerButton.addSubview(labelView)
                }
                
                let labelFrame: CGRect
                switch component.style {
                case .generic:
                    labelFrame = CGRect(origin: CGPoint(x: titleFrame.minX + iconLabelOffset, y: titleFrame.maxY + titleSpacing), size: labelSize)
                case .compact:
                    labelFrame = CGRect(origin: CGPoint(x: titleFrame.maxX + 4.0, y: floor((height - verticalInset * 2.0 - centralContentHeight) / 2.0)), size: labelSize)
                }
                
                transition.setFrame(view: labelView, frame: labelFrame)
            }
            
            if themeUpdated {
                self.separatorLayer.backgroundColor = component.theme.list.itemPlainSeparatorColor.cgColor
            }
            transition.setFrame(layer: self.separatorLayer, frame: CGRect(origin: CGPoint(x: leftInset, y: height), size: CGSize(width: availableSize.width - leftInset, height: UIScreenPixel)))
            self.separatorLayer.isHidden = !component.hasNext
            
            let containerFrame = CGRect(origin: CGPoint(x: contextInset, y: verticalInset), size: CGSize(width: availableSize.width - contextInset * 2.0, height: height - verticalInset * 2.0))
            transition.setFrame(view: self.containerButton, frame: containerFrame)
            
            return CGSize(width: availableSize.width, height: height)
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
