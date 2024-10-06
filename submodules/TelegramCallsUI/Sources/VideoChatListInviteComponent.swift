import Foundation
import UIKit
import Display
import ComponentFlow
import MultilineTextComponent
import TelegramPresentationData
import BundleIconComponent

final class VideoChatListInviteComponent: Component {
    let title: String
    let theme: PresentationTheme
    let action: () -> Void

    init(
        title: String,
        theme: PresentationTheme,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.theme = theme
        self.action = action
    }

    static func ==(lhs: VideoChatListInviteComponent, rhs: VideoChatListInviteComponent) -> Bool {
        if lhs.title != rhs.title {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        return true
    }

    final class View: HighlightTrackingButton {
        private let icon = ComponentView<Empty>()
        private let title = ComponentView<Empty>()

        private var component: VideoChatListInviteComponent?
        private var isUpdating: Bool = false
        
        private var highlightBackgroundLayer: SimpleLayer?
        private var highlightBackgroundFrame: CGRect?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.highligthedChanged = { [weak self] isHighlighted in
                guard let self, let component = self.component, let highlightBackgroundFrame = self.highlightBackgroundFrame else {
                    return
                }
                
                if isHighlighted {
                    self.superview?.bringSubviewToFront(self)
                    
                    let highlightBackgroundLayer: SimpleLayer
                    if let current = self.highlightBackgroundLayer {
                        highlightBackgroundLayer = current
                    } else {
                        highlightBackgroundLayer = SimpleLayer()
                        self.highlightBackgroundLayer = highlightBackgroundLayer
                        self.layer.insertSublayer(highlightBackgroundLayer, at: 0)
                        highlightBackgroundLayer.backgroundColor = component.theme.list.itemHighlightedBackgroundColor.cgColor
                    }
                    highlightBackgroundLayer.frame = highlightBackgroundFrame
                    highlightBackgroundLayer.opacity = 1.0
                } else {
                    if let highlightBackgroundLayer = self.highlightBackgroundLayer {
                        self.highlightBackgroundLayer = nil
                        highlightBackgroundLayer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { [weak highlightBackgroundLayer] _ in
                            highlightBackgroundLayer?.removeFromSuperlayer()
                        })
                    }
                }
            }
            self.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        @objc private func pressed() {
            guard let component = self.component else {
                return
            }
            component.action()
        }
        
        func update(component: VideoChatListInviteComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            self.component = component
            
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.title, font: Font.regular(17.0), textColor: component.theme.list.itemAccentColor))
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - 62.0 - 8.0, height: 100.0)
            )
            
            let size = CGSize(width: availableSize.width, height: 46.0)
            
            let titleFrame = CGRect(origin: CGPoint(x: 62.0, y: floor((size.height - titleSize.height) * 0.5)), size: titleSize)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    titleView.isUserInteractionEnabled = false
                    titleView.layer.anchorPoint = CGPoint()
                    self.addSubview(titleView)
                }
                transition.setPosition(view: titleView, position: titleFrame.origin)
                titleView.bounds = CGRect(origin: CGPoint(), size: titleFrame.size)
            }
            
            let iconSize = self.icon.update(
                transition: .immediate,
                component: AnyComponent(BundleIconComponent(
                    name: "Chat/Context Menu/AddUser",
                    tintColor: component.theme.list.itemAccentColor
                )),
                environment: {},
                containerSize: CGSize(width: 100.0, height: 100.0)
            )
            let iconFrame = CGRect(origin: CGPoint(x: floor((62.0 - iconSize.width) * 0.5), y: floor((size.height - iconSize.height) * 0.5)), size: iconSize)
            if let iconView = self.icon.view {
                if iconView.superview == nil {
                    iconView.isUserInteractionEnabled = false
                    self.addSubview(iconView)
                }
                transition.setFrame(view: iconView, frame: iconFrame)
            }
            
            //self.highlightBackgroundFrame = CGRect(origin: CGPoint(), size: size)
            
            return size
        }
    }

    func makeView() -> View {
        return View()
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
