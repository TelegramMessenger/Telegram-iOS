import Foundation
import UIKit
import Display
import AsyncDisplayKit
import ComponentFlow
import SwiftSignalKit
import ViewControllerComponent
import ComponentDisplayAdapters
import TelegramPresentationData
import AccountContext
import TelegramCore
import MultilineTextComponent
import EmojiStatusComponent
import TelegramStringFormatting
import CheckNode

final class DataButtonComponent: Component {
    let theme: PresentationTheme
    let title: String
    let action: () -> Void
    
    init(
        theme: PresentationTheme,
        title: String,
        action: @escaping () -> Void
    ) {
        self.theme = theme
        self.title = title
        self.action = action
    }
    
    static func ==(lhs: DataButtonComponent, rhs: DataButtonComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.title != rhs.title {
            return false
        }
        return true
    }
    
    class View: HighlightTrackingButton {
        private let title = ComponentView<Empty>()
        
        private var component: DataButtonComponent?
        
        private var highlightBackgroundFrame: CGRect?
        private var highlightBackgroundLayer: SimpleLayer?
        
        override init(frame: CGRect) {
            super.init(frame: frame)

            self.clipsToBounds = true
            self.layer.cornerRadius = 10.0
            
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
        
        func update(component: DataButtonComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            let themeUpdated = self.component?.theme !== component.theme
            
            self.component = component

            if themeUpdated {
                self.backgroundColor = component.theme.list.itemBlocksBackgroundColor
            }
            
            let titleSize = self.title.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(text: .plain(NSAttributedString(string: component.title, font: Font.regular(17.0), textColor: component.theme.list.itemDestructiveColor)))),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: 100.0)
            )
            
            let height: CGFloat = 44.0
            
            let titleFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - titleSize.width) / 2.0), y: floor((height - titleSize.height) / 2.0)), size: titleSize)
            
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    titleView.isUserInteractionEnabled = false
                    self.addSubview(titleView)
                }
                transition.setFrame(view: titleView, frame: titleFrame)
            }
            
            self.highlightBackgroundFrame = CGRect(origin: CGPoint(), size: CGSize(width: availableSize.width, height: height))
            
            return CGSize(width: availableSize.width, height: height)
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
