import Foundation
import UIKit

final class Button: CombinedComponent, Equatable {
    let content: AnyComponent<Empty>
    let insets: UIEdgeInsets
    let action: () -> Void

    init(
        content: AnyComponent<Empty>,
        insets: UIEdgeInsets,
        action: @escaping () -> Void
    ) {
        self.content = content
        self.insets = insets
        self.action = action
    }

    static func ==(lhs: Button, rhs: Button) -> Bool {
        if lhs.content != rhs.content {
            return false
        }
        if lhs.insets != rhs.insets {
            return false
        }
        return true
    }

    final class State: ComponentState {
        var isHighlighted = false

        override init() {
            super.init()
        }
    }

    func makeState() -> State {
        return State()
    }

    static var body: Body {
        let content = Child(environment: Empty.self)

        return { context in
            let content = content.update(
                component: context.component.content,
                availableSize: CGSize(width: context.availableSize.width, height: 44.0), transition: context.transition
            )

            let size = CGSize(width: content.size.width + context.component.insets.left + context.component.insets.right, height: content.size.height + context.component.insets.top + context.component.insets.bottom)

            let component = context.component

            context.add(content
                .position(CGPoint(x: size.width / 2.0, y: size.height / 2.0))
                .opacity(context.state.isHighlighted ? 0.2 : 1.0)
                .update(Transition.Update { component, view, transition in
                    view.frame = component.size.centered(around: component._position ?? CGPoint())
                })
                .gesture(.tap {
                    component.action()
                })
            )
            
            return size
        }
    }
}
