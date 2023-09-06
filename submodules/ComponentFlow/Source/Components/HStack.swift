import Foundation
import UIKit

public final class HStack<ChildEnvironment: Equatable>: CombinedComponent {
    public typealias EnvironmentType = ChildEnvironment

    private let items: [AnyComponentWithIdentity<ChildEnvironment>]
    private let spacing: CGFloat

    public init(_ items: [AnyComponentWithIdentity<ChildEnvironment>], spacing: CGFloat) {
        self.items = items
        self.spacing = spacing
    }

    public static func ==(lhs: HStack<ChildEnvironment>, rhs: HStack<ChildEnvironment>) -> Bool {
        if lhs.items != rhs.items {
            return false
        }
        if lhs.spacing != rhs.spacing {
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

            var size = CGSize(width: 0.0, height: 0.0)
            for child in updatedChildren {
                size.width += child.size.width
                size.height = max(size.height, child.size.height)
            }

            var nextX = 0.0
            for child in updatedChildren {
                context.add(child
                    .position(child.size.centered(in: CGRect(origin: CGPoint(x: nextX, y: floor((size.height - child.size.height) * 0.5)), size: child.size)).center)
                    .appear(.default(scale: true, alpha: true))
                    .disappear(.default(scale: true, alpha: true))
                )
                nextX += child.size.width
                nextX += context.component.spacing
            }

            return size
        }
    }
}
