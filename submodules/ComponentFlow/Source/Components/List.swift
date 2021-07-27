import Foundation
import UIKit

public final class List<ChildEnvironment: Equatable>: CombinedComponent {
    public typealias EnvironmentType = ChildEnvironment

    private let items: [AnyComponentWithIdentity<ChildEnvironment>]
    private let appear: Transition.Appear

    public init(_ items: [AnyComponentWithIdentity<ChildEnvironment>], appear: Transition.Appear = .default()) {
        self.items = items
        self.appear = appear
    }

    public static func ==(lhs: List<ChildEnvironment>, rhs: List<ChildEnvironment>) -> Bool {
        if lhs.items != rhs.items {
            return false
        }
        return true
    }

    public static var body: Body {
        let children = ChildMap(environment: ChildEnvironment.self, keyedBy: AnyHashable.self)

        return { context in
            let updatedChildren = context.component.items.map { item in
                return children[item.id].update(
                    component: item.component, environment: {
                        context.environment[ChildEnvironment.self]
                    },
                    availableSize: context.availableSize,
                    transition: context.transition
                )
            }

            var nextOrigin: CGFloat = 0.0
            for child in updatedChildren {
                context.add(child
                    .position(CGPoint(x: child.size.width / 2.0, y: nextOrigin + child.size.height / 2.0))
                    .appear(context.component.appear)
                )
                nextOrigin += child.size.height
            }

            return context.availableSize
        }
    }
}
