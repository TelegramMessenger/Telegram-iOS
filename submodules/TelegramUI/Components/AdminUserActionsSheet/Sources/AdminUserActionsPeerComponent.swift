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
import TelegramStringFormatting
import ListSectionComponent

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

final class AdminUserActionsPeerComponent: Component {
    enum SelectionState: Equatable {
        case none
        case editing(isSelected: Bool)
    }
    
    let context: AccountContext
    let theme: PresentationTheme
    let strings: PresentationStrings
    let baseFontSize: CGFloat
    let sideInset: CGFloat
    let title: String
    let peer: EnginePeer?
    let selectionState: SelectionState
    let action: (EnginePeer) -> Void
    
    init(
        context: AccountContext,
        theme: PresentationTheme,
        strings: PresentationStrings,
        baseFontSize: CGFloat,
        sideInset: CGFloat,
        title: String,
        peer: EnginePeer?,
        selectionState: SelectionState,
        action: @escaping (EnginePeer) -> Void
    ) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.baseFontSize = baseFontSize
        self.sideInset = sideInset
        self.title = title
        self.peer = peer
        self.selectionState = selectionState
        self.action = action
    }
    
    static func ==(lhs: AdminUserActionsPeerComponent, rhs: AdminUserActionsPeerComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.baseFontSize != rhs.baseFontSize {
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
        if lhs.selectionState != rhs.selectionState {
            return false
        }
        return true
    }
    
    final class View: UIView, ListSectionComponent.ChildView {
        private let containerButton: HighlightTrackingButton
        
        private let title = ComponentView<Empty>()
        private let label = ComponentView<Empty>()
        private let avatarNode: AvatarNode
        
        private var labelIconView: UIImageView?
        private var checkLayer: CheckLayer?
        
        private var component: AdminUserActionsPeerComponent?
        private weak var state: EmptyComponentState?
        
        public var customUpdateIsHighlighted: ((Bool) -> Void)?
        public var separatorInset: CGFloat = 0.0
        
        override init(frame: CGRect) {
            self.containerButton = HighlightTrackingButton()
            
            self.avatarNode = AvatarNode(font: avatarFont)
            self.avatarNode.isLayerBacked = true
            
            super.init(frame: frame)
            
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
        
        func update(component: AdminUserActionsPeerComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
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
            
            let contextInset: CGFloat = 0.0
            
            let height: CGFloat = 44.0
            let verticalInset: CGFloat = 1.0
            let leftInset: CGFloat = 30.0 + component.sideInset
            var rightInset: CGFloat = contextInset * 2.0 + 8.0 + component.sideInset
            var avatarLeftInset: CGFloat = component.sideInset + 10.0
            
            if case let .editing(isSelected) = component.selectionState {
                rightInset += 46.0
                avatarLeftInset += 24.0
                
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
                transition.setFrame(layer: checkLayer, frame: CGRect(origin: CGPoint(x: floor((22.0 - checkSize) * 0.5), y: floor((height - verticalInset * 2.0 - checkSize) / 2.0)), size: CGSize(width: checkSize, height: checkSize)))
            } else {
                if let checkLayer = self.checkLayer {
                    self.checkLayer = nil
                    transition.setPosition(layer: checkLayer, position: CGPoint(x: -checkLayer.bounds.width * 0.5, y: checkLayer.position.y), completion: { [weak checkLayer] _ in
                        checkLayer?.removeFromSuperlayer()
                    })
                }
            }
            
            let avatarSize: CGFloat = 30.0
            
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
                self.avatarNode.setPeer(context: component.context, theme: component.theme, peer: peer, clipStyle: clipStyle, displayDimensions: CGSize(width: avatarSize, height: avatarSize))
            }
            
            let avatarTitleSpacing: CGFloat = 5.0
            let maxTextSize = availableSize.width - avatarLeftInset - avatarSize - avatarTitleSpacing - rightInset
            
            let previousTitleFrame = self.title.view?.frame
            var previousTitleContents: UIView?
            if hasSelectionUpdated && !"".isEmpty {
                previousTitleContents = self.title.view?.snapshotView(afterScreenUpdates: false)
            }
            
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.title, font: Font.semibold(component.baseFontSize), textColor: component.theme.list.itemPrimaryTextColor))
                )),
                environment: {},
                containerSize: CGSize(width: maxTextSize, height: 100.0)
            )
            
            let centralContentHeight: CGFloat = titleSize.height
            
            let titleFrame = CGRect(origin: CGPoint(x: avatarLeftInset + avatarSize + avatarTitleSpacing, y: floor((height - verticalInset * 2.0 - centralContentHeight) / 2.0)), size: titleSize)
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
            
            let containerFrame = CGRect(origin: CGPoint(x: contextInset, y: verticalInset), size: CGSize(width: availableSize.width - contextInset * 2.0, height: height - verticalInset * 2.0))
            transition.setFrame(view: self.containerButton, frame: containerFrame)
            
            self.separatorInset = leftInset
            
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
