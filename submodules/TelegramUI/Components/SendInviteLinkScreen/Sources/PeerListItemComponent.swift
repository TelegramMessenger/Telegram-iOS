import Foundation
import UIKit
import Display
import AsyncDisplayKit
import ComponentFlow
import SwiftSignalKit
import AccountContext
import TelegramCore
import MultilineTextComponent
import AvatarNode
import TelegramPresentationData
import CheckNode
import PeerPresenceStatusManager
import TelegramStringFormatting

private let avatarFont = avatarPlaceholderFont(size: 15.0)

private func cancelContextGestures(view: UIView) {
    if let gestureRecognizers = view.gestureRecognizers {
        for gesture in gestureRecognizers {
            if let gesture = gesture as? ContextGesture {
                gesture.cancel()
            }
        }
    }
    for subview in view.subviews {
        cancelContextGestures(view: subview)
    }
}

final class PeerListItemComponent: Component {
    enum SelectionState: Equatable {
        case none
        case editing(isSelected: Bool)
    }
    
    enum SubtitleIcon {
        case lock
    }
    
    enum Subtitle: Equatable {
        case presence(EnginePeer.Presence?)
        case text(text: String, icon: SubtitleIcon)
    }
    
    let context: AccountContext
    let theme: PresentationTheme
    let strings: PresentationStrings
    let sideInset: CGFloat
    let title: String
    let subtitle: Subtitle
    let peer: EnginePeer?
    let selectionState: SelectionState
    let hasNext: Bool
    let action: (EnginePeer) -> Void
    
    init(
        context: AccountContext,
        theme: PresentationTheme,
        strings: PresentationStrings,
        sideInset: CGFloat,
        title: String,
        subtitle: Subtitle,
        peer: EnginePeer?,
        selectionState: SelectionState,
        hasNext: Bool,
        action: @escaping (EnginePeer) -> Void
    ) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.sideInset = sideInset
        self.title = title
        self.subtitle = subtitle
        self.peer = peer
        self.selectionState = selectionState
        self.hasNext = hasNext
        self.action = action
    }
    
    static func ==(lhs: PeerListItemComponent, rhs: PeerListItemComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.sideInset != rhs.sideInset {
            return false
        }
        if lhs.title != rhs.title {
            return false
        }
        if lhs.subtitle != rhs.subtitle {
            return false
        }
        if lhs.peer != rhs.peer {
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
    
    final class View: UIView {
        private let containerButton: HighlightTrackingButton
        
        private let title = ComponentView<Empty>()
        private let label = ComponentView<Empty>()
        private let separatorLayer: SimpleLayer
        private let avatarNode: AvatarNode
        
        private var labelIconView: UIImageView?
        private var checkLayer: CheckLayer?
        
        private var component: PeerListItemComponent?
        private weak var state: EmptyComponentState?
        
        private var statusManager: PeerPresenceStatusManager?
        
        override init(frame: CGRect) {
            self.separatorLayer = SimpleLayer()
            
            self.containerButton = HighlightTrackingButton()
            
            self.avatarNode = AvatarNode(font: avatarFont)
            self.avatarNode.isLayerBacked = true
            
            super.init(frame: frame)
            
            self.layer.addSublayer(self.separatorLayer)
            self.addSubview(self.containerButton)
            self.containerButton.layer.addSublayer(self.avatarNode.layer)
            
            self.containerButton.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
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
        
        func update(component: PeerListItemComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
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
            
            self.component = component
            self.state = state
            
            if case let .presence(presence) = component.subtitle, let presence {
                let statusManager: PeerPresenceStatusManager
                if let current = self.statusManager {
                    statusManager = current
                } else {
                    statusManager = PeerPresenceStatusManager(update: { [weak state] in
                        state?.updated(transition: .immediate)
                    })
                    self.statusManager = statusManager
                }
                statusManager.reset(presence: presence)
            } else {
                self.statusManager = nil
            }
            
            let contextInset: CGFloat = 0.0
            
            let height: CGFloat = 60.0
            let verticalInset: CGFloat = 1.0
            let leftInset: CGFloat = 62.0 + component.sideInset
            var rightInset: CGFloat = contextInset * 2.0 + 8.0 + component.sideInset
            let avatarLeftInset: CGFloat = component.sideInset + 10.0
            
            if case let .editing(isSelected) = component.selectionState {
                rightInset += 48.0
                
                let checkSize: CGFloat = 22.0
                
                let checkLayer: CheckLayer
                if let current = self.checkLayer {
                    checkLayer = current
                    if themeUpdated {
                        checkLayer.theme = CheckNodeTheme(theme: component.theme, style: .plain)
                    }
                    checkLayer.setSelected(isSelected, animated: !transition.animation.isImmediate)
                } else {
                    checkLayer = CheckLayer(theme: CheckNodeTheme(theme: component.theme, style: .plain))
                    self.checkLayer = checkLayer
                    self.containerButton.layer.addSublayer(checkLayer)
                    checkLayer.frame = CGRect(origin: CGPoint(x: -checkSize, y: floor((height - verticalInset * 2.0 - checkSize) / 2.0)), size: CGSize(width: checkSize, height: checkSize))
                    checkLayer.setSelected(isSelected, animated: false)
                    checkLayer.setNeedsDisplay()
                }
                transition.setFrame(layer: checkLayer, frame: CGRect(origin: CGPoint(x: availableSize.width - rightInset + floor((48.0 - checkSize) * 0.5), y: floor((height - verticalInset * 2.0 - checkSize) / 2.0)), size: CGSize(width: checkSize, height: checkSize)))
            } else {
                if let checkLayer = self.checkLayer {
                    self.checkLayer = nil
                    transition.setPosition(layer: checkLayer, position: CGPoint(x: -checkLayer.bounds.width * 0.5, y: checkLayer.position.y), completion: { [weak checkLayer] _ in
                        checkLayer?.removeFromSuperlayer()
                    })
                }
            }
            
            let avatarSize: CGFloat = 40.0
            
            let avatarFrame = CGRect(origin: CGPoint(x: avatarLeftInset, y: floor((height - verticalInset * 2.0 - avatarSize) / 2.0)), size: CGSize(width: avatarSize, height: avatarSize))
            if self.avatarNode.bounds.isEmpty {
                self.avatarNode.frame = avatarFrame
            } else {
                transition.setFrame(layer: self.avatarNode.layer, frame: avatarFrame)
            }
            if let peer = component.peer {
                let clipStyle: AvatarNodeClipStyle
                if case let .channel(channel) = peer, channel.isForumOrMonoForum {
                    clipStyle = .roundedRect
                } else {
                    clipStyle = .round
                }
                if peer.id == component.context.account.peerId {
                    self.avatarNode.setPeer(context: component.context, theme: component.theme, peer: peer, overrideImage: .savedMessagesIcon, clipStyle: clipStyle, displayDimensions: CGSize(width: avatarSize, height: avatarSize))
                } else {
                    self.avatarNode.setPeer(context: component.context, theme: component.theme, peer: peer, clipStyle: clipStyle, displayDimensions: CGSize(width: avatarSize, height: avatarSize))
                }
            }
            
            var labelIcon: UIImage?
            let labelData: (String, Bool)
            switch component.subtitle {
            case let .presence(presence):
                if let presence {
                    labelData = stringAndActivityForUserPresence(strings: component.strings, dateTimeFormat: PresentationDateTimeFormat(), presence: presence, relativeTo: Int32(Date().timeIntervalSince1970))
                } else {
                    labelData = (component.strings.LastSeen_Offline, false)
                }
            case let .text(text, icon):
                switch icon {
                case .lock:
                    labelIcon = PresentationResourcesItemList.peerStatusLockedImage(component.theme)
                }
                labelData = (text, false)
            }
            
            var maxTextSize = availableSize.width - leftInset - rightInset
            if labelIcon != nil {
                maxTextSize -= 48.0
            }
            
            let labelSize = self.label.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: labelData.0, font: Font.regular(15.0), textColor: labelData.1 ? component.theme.list.itemAccentColor : component.theme.list.itemSecondaryTextColor))
                )),
                environment: {},
                containerSize: CGSize(width: maxTextSize, height: 100.0)
            )
            
            let previousTitleFrame = self.title.view?.frame
            var previousTitleContents: UIView?
            if hasSelectionUpdated && !"".isEmpty {
                previousTitleContents = self.title.view?.snapshotView(afterScreenUpdates: false)
            }
            
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.title, font: Font.semibold(17.0), textColor: component.theme.list.itemPrimaryTextColor))
                )),
                environment: {},
                containerSize: CGSize(width: maxTextSize, height: 100.0)
            )
            
            let titleSpacing: CGFloat = 1.0
            let centralContentHeight: CGFloat = titleSize.height + labelSize.height + titleSpacing
            
            let titleFrame = CGRect(origin: CGPoint(x: leftInset, y: floor((height - verticalInset * 2.0 - centralContentHeight) / 2.0)), size: titleSize)
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
            
            if let labelIcon {
                let labelIconView: UIImageView
                if let current = self.labelIconView {
                    labelIconView = current
                } else {
                    labelIconView = UIImageView()
                    self.labelIconView = labelIconView
                    self.containerButton.addSubview(labelIconView)
                }
                labelIconView.image = labelIcon
                
                let labelIconFrame = CGRect(origin: CGPoint(x: availableSize.width - rightInset - 48.0 + floor((48.0 - labelIcon.size.width) * 0.5), y: floor((height - verticalInset * 2.0 - labelIcon.size.height) / 2.0)), size: CGSize(width: labelIcon.size.width, height: labelIcon.size.height))
                transition.setFrame(view: labelIconView, frame: labelIconFrame)
            } else {
                if let labelIconView = self.labelIconView {
                    self.labelIconView = nil
                    labelIconView.removeFromSuperview()
                }
            }
            
            if let labelView = self.label.view {
                if labelView.superview == nil {
                    labelView.isUserInteractionEnabled = false
                    self.containerButton.addSubview(labelView)
                }
                transition.setFrame(view: labelView, frame: CGRect(origin: CGPoint(x: titleFrame.minX, y: titleFrame.maxY + titleSpacing), size: labelSize))
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
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
