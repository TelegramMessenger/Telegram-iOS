import Foundation
import UIKit
import Display
import ComponentFlow
import TelegramPresentationData
import ComponentDisplayAdapters

final class VideoChatPinStatusComponent: Component {
    let theme: PresentationTheme
    let strings: PresentationStrings
    let isPinned: Bool
    let action: () -> Void

    init(
        theme: PresentationTheme,
        strings: PresentationStrings,
        isPinned: Bool,
        action: @escaping () -> Void
    ) {
        self.theme = theme
        self.strings = strings
        self.isPinned = isPinned
        self.action = action
    }

    static func ==(lhs: VideoChatPinStatusComponent, rhs: VideoChatPinStatusComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.isPinned != rhs.isPinned {
            return false
        }
        return true
    }

    final class View: UIView {
        private var pinNode: VoiceChatPinButtonNode?

        private var component: VideoChatPinStatusComponent?
        private var isUpdating: Bool = false
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
        }
        
        @objc private func pinPressed() {
            guard let component = self.component else {
                return
            }
            component.action()
        }
        
        func update(component: VideoChatPinStatusComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            self.component = component
            
            let pinNode: VoiceChatPinButtonNode
            if let current = self.pinNode {
                pinNode = current
            } else {
                pinNode = VoiceChatPinButtonNode(theme: component.theme, strings: component.strings)
                self.pinNode = pinNode
                self.addSubview(pinNode.view)
                pinNode.addTarget(self, action: #selector(self.pinPressed), forControlEvents: .touchUpInside)
            }
            let pinNodeSize = pinNode.update(size: availableSize, transition: transition.containedViewLayoutTransition)
            let pinNodeFrame = CGRect(origin: CGPoint(), size: pinNodeSize)
            transition.setFrame(view: pinNode.view, frame: pinNodeFrame)
            
            pinNode.update(pinned: component.isPinned, animated: !transition.animation.isImmediate)
            
            let size = pinNodeSize
            
            return size
        }
    }

    func makeView() -> View {
        return View()
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
