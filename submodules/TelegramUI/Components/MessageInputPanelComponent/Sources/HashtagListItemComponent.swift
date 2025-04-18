import Foundation
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
import ContextUI
import EmojiTextAttachmentView
import TextFormat
import PhotoResources
import ListSectionComponent
import ListItemSwipeOptionContainer

private let avatarFont = avatarPlaceholderFont(size: 15.0)

public final class HashtagListItemComponent: Component {
    public final class TransitionHint {
        public let synchronousLoad: Bool
        
        public init(synchronousLoad: Bool) {
            self.synchronousLoad = synchronousLoad
        }
    }
    
    public final class InlineAction: Equatable {
        public enum Color: Equatable {
            case destructive
        }
        
        public let id: AnyHashable
        public let title: String
        public let color: Color
        public let action: () -> Void
        
        public init(id: AnyHashable, title: String, color: Color, action: @escaping () -> Void) {
            self.id = id
            self.title = title
            self.color = color
            self.action = action
        }
        
        public static func ==(lhs: InlineAction, rhs: InlineAction) -> Bool {
            if lhs === rhs {
                return true
            }
            if lhs.id != rhs.id {
                return false
            }
            if lhs.title != rhs.title {
                return false
            }
            if lhs.color != rhs.color {
                return false
            }
            return true
        }
    }
    
    public final class InlineActionsState: Equatable {
        public let actions: [InlineAction]
        
        public init(actions: [InlineAction]) {
            self.actions = actions
        }
        
        public static func ==(lhs: InlineActionsState, rhs: InlineActionsState) -> Bool {
            if lhs === rhs {
                return true
            }
            if lhs.actions != rhs.actions {
                return false
            }
            return true
        }
    }
        
    let context: AccountContext
    let theme: PresentationTheme
    let strings: PresentationStrings
    let peer: EnginePeer?
    let title: String
    let subtitle: String?
    let hashtag: String
    let hasNext: Bool
    let action: (String, HashtagListItemComponent.View) -> Void
    let contextAction: ((String, ContextExtractedContentContainingView, ContextGesture) -> Void)?
    let inlineActions: InlineActionsState?
    
    public init(
        context: AccountContext,
        theme: PresentationTheme,
        strings: PresentationStrings,
        peer: EnginePeer?,
        title: String,
        subtitle: String?,
        hashtag: String,
        hasNext: Bool,
        action: @escaping (String, HashtagListItemComponent.View) -> Void,
        contextAction: ((String, ContextExtractedContentContainingView, ContextGesture) -> Void)? = nil,
        inlineActions: InlineActionsState? = nil
    ) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.peer = peer
        self.title = title
        self.subtitle = subtitle
        self.hashtag = hashtag
        self.hasNext = hasNext
        self.action = action
        self.contextAction = contextAction
        self.inlineActions = inlineActions
    }
    
    public static func ==(lhs: HashtagListItemComponent, rhs: HashtagListItemComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.peer != rhs.peer {
            return false
        }
        if lhs.title != rhs.title {
            return false
        }
        if lhs.subtitle != rhs.subtitle {
            return false
        }
        if lhs.hashtag != rhs.hashtag {
            return false
        }
        if lhs.hasNext != rhs.hasNext {
            return false
        }
        if lhs.inlineActions != rhs.inlineActions {
            return false
        }
        return true
    }
    
    public final class View: ContextControllerSourceView, ListSectionComponent.ChildView {
        public let extractedContainerView: ContextExtractedContentContainingView
        private let containerButton: HighlightTrackingButton
        
        private let swipeOptionContainer: ListItemSwipeOptionContainer
        
        private let iconBackgroundLayer = SimpleLayer()
        private let iconLayer = SimpleLayer()
        
        private let title = ComponentView<Empty>()
        private var label = ComponentView<Empty>()
        private let separatorLayer: SimpleLayer
        private var avatarNode: AvatarNode?
        
        private let badgeBackgroundLayer = SimpleLayer()
                
        private var component: HashtagListItemComponent?
        private weak var state: EmptyComponentState?

        public var avatarFrame: CGRect {
            if let avatarNode = self.avatarNode {
                return avatarNode.frame
            } else {
                return CGRect(origin: CGPoint(), size: CGSize())
            }
        }
        
        public var titleFrame: CGRect? {
            return self.title.view?.frame
        }
        
        public var labelFrame: CGRect? {
            guard let value = self.label.view?.frame else {
                return nil
            }
            return value
        }
        
        private var isExtractedToContextMenu: Bool = false
        
        public var customUpdateIsHighlighted: ((Bool) -> Void)?
        public private(set) var separatorInset: CGFloat = 0.0
        
        override init(frame: CGRect) {
            self.separatorLayer = SimpleLayer()
            
            self.iconBackgroundLayer.cornerRadius = 15.0
            self.badgeBackgroundLayer.cornerRadius = 4.0
            
            self.extractedContainerView = ContextExtractedContentContainingView()
            self.containerButton = HighlightTrackingButton()
            self.containerButton.layer.anchorPoint = CGPoint()
            self.containerButton.isExclusiveTouch = true
            
            self.swipeOptionContainer = ListItemSwipeOptionContainer(frame: CGRect())
            
            super.init(frame: frame)
            
            self.addSubview(self.extractedContainerView)
            self.targetViewForActivationProgress = self.extractedContainerView.contentView
            
            self.extractedContainerView.contentView.addSubview(self.swipeOptionContainer)
            
            self.swipeOptionContainer.addSubview(self.containerButton)
            
            self.layer.addSublayer(self.separatorLayer)
            
            self.containerButton.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
            
            self.extractedContainerView.isExtractedToContextPreviewUpdated = { [weak self] value in
                guard let self else {
                    return
                }
                                
                self.containerButton.clipsToBounds = value
                self.containerButton.backgroundColor = nil
                self.containerButton.layer.cornerRadius = value ? 10.0 : 0.0
            }
            self.extractedContainerView.willUpdateIsExtractedToContextPreview = { [weak self] value, transition in
                guard let self else {
                    return
                }
                self.isExtractedToContextMenu = value
                
                let mappedTransition: ComponentTransition
                if value {
                    mappedTransition = ComponentTransition(transition)
                } else {
                    mappedTransition = ComponentTransition(animation: .curve(duration: 0.2, curve: .easeInOut))
                }
                self.state?.updated(transition: mappedTransition)
            }
            
            self.activated = { [weak self] gesture, _ in
                guard let self, let component = self.component else {
                    gesture.cancel()
                    return
                }
                component.contextAction?(component.hashtag, self.extractedContainerView, gesture)
            }
            
            self.containerButton.highligthedChanged = { [weak self] highlighted in
                guard let self else {
                    return
                }
                if let customUpdateIsHighlighted = self.customUpdateIsHighlighted {
                    customUpdateIsHighlighted(highlighted)
                }
            }
            
            self.swipeOptionContainer.updateRevealOffset = { [weak self] offset, transition in
                guard let self else {
                    return
                }
                transition.setBounds(view: self.containerButton, bounds: CGRect(origin: CGPoint(x: -offset, y: 0.0), size: self.containerButton.bounds.size))
            }
            self.swipeOptionContainer.revealOptionSelected = { [weak self] option, _ in
                guard let self, let component = self.component else {
                    return
                }
                guard let inlineActions = component.inlineActions else {
                    return
                }
                self.swipeOptionContainer.setRevealOptionsOpened(false, animated: true)
                if let inlineAction = inlineActions.actions.first(where: { $0.id == option.key }) {
                    inlineAction.action()
                }
            }
            
            self.containerButton.layer.addSublayer(self.iconBackgroundLayer)
            self.iconBackgroundLayer.addSublayer(self.iconLayer)
            
            self.containerButton.layer.addSublayer(self.badgeBackgroundLayer)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
                
        @objc private func pressed() {
            guard let component = self.component else {
                return
            }
            component.action("\(component.hashtag) ", self)
        }
        
        func update(component: HashtagListItemComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            var synchronousLoad = false
            if let hint = transition.userData(TransitionHint.self) {
                synchronousLoad = hint.synchronousLoad
            }
                
            self.isGestureEnabled = false
            
            let themeUpdated = self.component?.theme !== component.theme
            
            self.component = component
            self.state = state
                                    
            let labelData: (String, UIColor)
            if let subtitle = component.subtitle {
                labelData = (subtitle, component.theme.list.itemSecondaryTextColor)
            } else {
                labelData = ("", .clear)
            }
            
            let contextInset: CGFloat
            if self.isExtractedToContextMenu {
                contextInset = 12.0
            } else {
                contextInset = 0.0
            }
            
            let height: CGFloat = 42.0
            let titleFont: UIFont = Font.semibold(14.0)
            let subtitleFont: UIFont = Font.regular(14.0)
          
            let verticalInset: CGFloat = 1.0
            let leftInset: CGFloat = 55.0
            let rightInset: CGFloat = 16.0
           
            let avatarSize: CGFloat = 30.0
            let avatarFrame = CGRect(origin: CGPoint(x: 12.0, y: floorToScreenPixels((height - verticalInset * 2.0 - avatarSize) / 2.0)), size: CGSize(width: avatarSize, height: avatarSize))
            
            if let peer = component.peer {
                let avatarNode: AvatarNode
                if let current = self.avatarNode {
                    avatarNode = current
                } else {
                    avatarNode = AvatarNode(font: avatarFont)
                    avatarNode.isLayerBacked = false
                    avatarNode.isUserInteractionEnabled = false
                    self.avatarNode = avatarNode
                    self.containerButton.layer.insertSublayer(avatarNode.layer, at: 0)
                }
                
                if avatarNode.bounds.isEmpty {
                    avatarNode.frame = avatarFrame
                } else {
                    transition.setFrame(layer: avatarNode.layer, frame: avatarFrame)
                }
                
                if peer.smallProfileImage != nil {
                    avatarNode.setPeerV2(
                        context: component.context,
                        theme: component.theme,
                        peer: peer,
                        authorOfMessage: nil,
                        overrideImage: nil,
                        emptyColor: nil,
                        clipStyle: .round,
                        synchronousLoad: synchronousLoad,
                        displayDimensions: CGSize(width: avatarSize, height: avatarSize)
                    )
                } else {
                    avatarNode.setPeer(context: component.context, theme: component.theme, peer: peer, clipStyle: .round, synchronousLoad: synchronousLoad, displayDimensions: CGSize(width: avatarSize, height: avatarSize))
                }
                self.iconBackgroundLayer.isHidden = true
            } else {
                self.iconBackgroundLayer.isHidden = false
            }
                                    
            let previousTitleFrame = self.title.view?.frame
            
            let titleAvailableWidth = availableSize.width - leftInset - rightInset
                        
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.title, font: titleFont, textColor: component.theme.list.itemPrimaryTextColor))
                )),
                environment: {},
                containerSize: CGSize(width: titleAvailableWidth, height: 100.0)
            )
            
            let labelAvailableWidth = availableSize.width - leftInset - rightInset
            let labelColor: UIColor = labelData.1
            
            let labelSize = self.label.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: labelData.0, font: subtitleFont, textColor: labelColor))
                )),
                environment: {},
                containerSize: CGSize(width: labelAvailableWidth, height: 100.0)
            )
            
            let titleVerticalOffset: CGFloat = 0.0
            let centralContentHeight: CGFloat
            if labelSize.height > 0.0 {
                centralContentHeight = titleSize.height + labelSize.height
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
            }
                        
            if let labelView = self.label.view {
                let labelFrame = CGRect(origin: CGPoint(x: titleFrame.minX, y: titleFrame.maxY), size: labelSize)
                if labelView.superview == nil {
                    labelView.isUserInteractionEnabled = false
                    labelView.layer.anchorPoint = CGPoint()
                    self.containerButton.addSubview(labelView)
                    
                    labelView.center = labelFrame.origin
                } else {
                    transition.setPosition(view: labelView, position: labelFrame.origin)
                }
                
                labelView.bounds = CGRect(origin: CGPoint(), size: labelFrame.size)
            }
              
            if self.iconLayer.contents == nil {
                self.iconLayer.contents = UIImage(bundleImageName: "Chat/Hashtag/SuggestHashtag")?.cgImage
            }
            
            if themeUpdated {
                let accentColor = UIColor(rgb: 0x007aff)
                self.separatorLayer.backgroundColor = component.theme.list.itemPlainSeparatorColor.cgColor
                self.iconBackgroundLayer.backgroundColor = accentColor.cgColor
                self.iconLayer.layerTintColor = UIColor.white.cgColor
                self.badgeBackgroundLayer.backgroundColor = accentColor.cgColor
            }
            
            transition.setFrame(layer: self.separatorLayer, frame: CGRect(origin: CGPoint(x: leftInset, y: height), size: CGSize(width: availableSize.width - leftInset, height: UIScreenPixel)))
            self.separatorLayer.isHidden = !component.hasNext
            
            let iconSize = CGSize(width: 30.0, height: 30.0)
            self.iconBackgroundLayer.frame = CGRect(origin: CGPoint(x: 12.0, y: floor((height - 30.0) / 2.0)), size: iconSize)
            self.iconLayer.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: 30.0, height: 30.0))
            
            let resultBounds = CGRect(origin: CGPoint(), size: CGSize(width: availableSize.width, height: height))
            transition.setFrame(view: self.extractedContainerView, frame: resultBounds)
            transition.setFrame(view: self.extractedContainerView.contentView, frame: resultBounds)
            self.extractedContainerView.contentRect = resultBounds
            
            let containerFrame = CGRect(origin: CGPoint(x: contextInset, y: verticalInset), size: CGSize(width: availableSize.width - contextInset * 2.0, height: height - verticalInset * 2.0))
            
            let swipeOptionContainerFrame = CGRect(origin: .zero, size: CGSize(width: availableSize.width, height: height))
            transition.setFrame(view: self.swipeOptionContainer, frame: swipeOptionContainerFrame)
            
            transition.setPosition(view: self.containerButton, position: containerFrame.origin)
            transition.setBounds(view: self.containerButton, bounds: CGRect(origin: self.containerButton.bounds.origin, size: containerFrame.size))
            
            self.separatorInset = leftInset
            
            self.swipeOptionContainer.updateLayout(size: swipeOptionContainerFrame.size, leftInset: 0.0, rightInset: 0.0)
            
            var rightOptions: [ListItemSwipeOptionContainer.Option] = []
            if let inlineActions = component.inlineActions {
                rightOptions = inlineActions.actions.map { action in
                    let color: UIColor
                    let textColor: UIColor
                    switch action.color {
                    case .destructive:
                        color = component.theme.list.itemDisclosureActions.destructive.fillColor
                        textColor = component.theme.list.itemDisclosureActions.destructive.foregroundColor
                    }
                    
                    return ListItemSwipeOptionContainer.Option(
                        key: action.id,
                        title: action.title,
                        icon: .none,
                        color: color,
                        textColor: textColor
                    )
                }
            }
            self.swipeOptionContainer.setRevealOptions(([], rightOptions))
            
            return CGSize(width: availableSize.width, height: height)
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
