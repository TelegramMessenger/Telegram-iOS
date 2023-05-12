import Foundation
import UIKit
import Display
import ComponentFlow
import AppBundle
import BundleIconComponent
import AccountContext
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import AvatarNode

public final class StoryPeerListItemComponent: Component {
    public let context: AccountContext
    public let theme: PresentationTheme
    public let strings: PresentationStrings
    public let peer: EnginePeer
    public let hasUnseen: Bool
    public let action: (EnginePeer) -> Void
    
    public init(
        context: AccountContext,
        theme: PresentationTheme,
        strings: PresentationStrings,
        peer: EnginePeer,
        hasUnseen: Bool,
        action: @escaping (EnginePeer) -> Void
    ) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.peer = peer
        self.hasUnseen = hasUnseen
        self.action = action
    }
    
    public static func ==(lhs: StoryPeerListItemComponent, rhs: StoryPeerListItemComponent) -> Bool {
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
        if lhs.hasUnseen != rhs.hasUnseen {
            return false
        }
        return true
    }
    
    public final class View: HighlightTrackingButton {
        private var avatarNode: AvatarNode?
        private let indicatorCircleView: UIImageView
        private let title = ComponentView<Empty>()
        
        private var component: StoryPeerListItemComponent?
        private weak var componentState: EmptyComponentState?
        
        public override init(frame: CGRect) {
            self.indicatorCircleView = UIImageView()
            self.indicatorCircleView.isUserInteractionEnabled = false
            
            super.init(frame: frame)
            
            self.addSubview(self.indicatorCircleView)
            
            self.highligthedChanged = { [weak self] highlighted in
                guard let self else {
                    return
                }
                if highlighted {
                    self.alpha = 0.7
                } else {
                    let previousAlpha = self.alpha
                    self.alpha = 1.0
                    self.layer.animateAlpha(from: previousAlpha, to: self.alpha, duration: 0.25)
                }
            }
            self.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
        }
        
        required public init?(coder: NSCoder) {
            preconditionFailure()
        }
        
        @objc private func pressed() {
            guard let component = self.component else {
                return
            }
            component.action(component.peer)
        }
        
        public func transitionView() -> UIView? {
            return self.avatarNode?.view
        }
        
        func update(component: StoryPeerListItemComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            let hadUnseen = self.component?.hasUnseen ?? false
            
            self.component = component
            self.componentState = state
            
            let avatarNode: AvatarNode
            if let current = self.avatarNode {
                avatarNode = current
            } else {
                avatarNode = AvatarNode(font: avatarPlaceholderFont(size: 26.0))
                self.avatarNode = avatarNode
                avatarNode.isUserInteractionEnabled = false
                self.addSubview(avatarNode.view)
            }
            
            let avatarSize = CGSize(width: 52.0, height: 52.0)
            let avatarFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - avatarSize.width) * 0.5), y: 4.0), size: avatarSize)
            let indicatorFrame = avatarFrame.insetBy(dx: -4.0, dy: -4.0)
            
            avatarNode.setPeer(
                context: component.context,
                theme: component.theme,
                peer: component.peer
            )
            avatarNode.updateSize(size: avatarSize)
            transition.setFrame(view: avatarNode.view, frame: avatarFrame)
            
            if component.peer.id == component.context.account.peerId && !component.hasUnseen {
                self.indicatorCircleView.image = nil
            } else if self.indicatorCircleView.image == nil || hadUnseen != component.hasUnseen {
                self.indicatorCircleView.image = generateImage(indicatorFrame.size, rotatedContext: { size, context in
                    context.clear(CGRect(origin: CGPoint(), size: size))
                    
                    let lineWidth: CGFloat = 2.0
                    context.setLineWidth(lineWidth)
                    context.addEllipse(in: CGRect(origin: CGPoint(), size: size).insetBy(dx: lineWidth * 0.5, dy: lineWidth * 0.5))
                    context.replacePathWithStrokedPath()
                    context.clip()
                    
                    var locations: [CGFloat] = [1.0, 0.0]
                    let colors: [CGColor]
                    
                    if component.hasUnseen {
                        colors = [UIColor(rgb: 0x34C76F).cgColor, UIColor(rgb: 0x3DA1FD).cgColor]
                    } else {
                        colors = [UIColor(rgb: 0xD8D8E1).cgColor, UIColor(rgb: 0xD8D8E1).cgColor]
                    }
                    
                    let colorSpace = CGColorSpaceCreateDeviceRGB()
                    let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: &locations)!
                    
                    context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: 0.0, y: size.height), options: CGGradientDrawingOptions())
                })
            }
            transition.setFrame(view: self.indicatorCircleView, frame: indicatorFrame)
            
            //TODO:localize
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(Text(text: component.peer.id == component.context.account.peerId ? "My story" : component.peer.compactDisplayTitle, font: Font.regular(11.0), color: component.theme.list.itemPrimaryTextColor)),
                environment: {},
                containerSize: CGSize(width: availableSize.width + 4.0, height: 100.0)
            )
            let titleFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - titleSize.width) * 0.5), y: indicatorFrame.maxY + 3.0), size: titleSize)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    titleView.layer.anchorPoint = CGPoint()
                    titleView.isUserInteractionEnabled = false
                    self.addSubview(titleView)
                }
                transition.setPosition(view: titleView, position: titleFrame.origin)
                transition.setBounds(view: titleView, bounds: CGRect(origin: CGPoint(), size: titleFrame.size))
            }
            
            return availableSize
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
