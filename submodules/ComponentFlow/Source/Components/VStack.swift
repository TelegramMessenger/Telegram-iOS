import Foundation
import UIKit

public final class VStack<ChildEnvironment: Equatable>: CombinedComponent {
    public typealias EnvironmentType = ChildEnvironment

    private let items: [AnyComponentWithIdentity<ChildEnvironment>]
    private let spacing: CGFloat

    public init(_ items: [AnyComponentWithIdentity<ChildEnvironment>], spacing: CGFloat) {
        self.items = items
        self.spacing = spacing
    }

    public static func ==(lhs: VStack<ChildEnvironment>, rhs: VStack<ChildEnvironment>) -> Bool {
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
                size.height += child.size.height
                size.width = max(size.width, child.size.width)
            }
            size.height += context.component.spacing * CGFloat(updatedChildren.count - 1)
            
            var nextY = 0.0
            for child in updatedChildren {
                context.add(child
                    .position(child.size.centered(in: CGRect(origin: CGPoint(x: floor((size.width - child.size.width) * 0.5), y: nextY), size: child.size)).center)
                    .appear(.default(scale: true, alpha: true))
                    .disappear(.default(scale: true, alpha: true))
                )
                nextY += child.size.height
                nextY += context.component.spacing
            }

            return size
        }
    }
}
