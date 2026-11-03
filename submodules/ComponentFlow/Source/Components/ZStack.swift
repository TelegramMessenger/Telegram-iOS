import Foundation
import UIKit

public final class ZStack<ChildEnvironment: Equatable>: CombinedComponent {
    public typealias EnvironmentType = ChildEnvironment

    private let items: [AnyComponentWithIdentity<ChildEnvironment>]

    public init(_ items: [AnyComponentWithIdentity<ChildEnvironment>]) {
        self.items = items
    }

    public static func ==(lhs: ZStack<ChildEnvironment>, rhs: ZStack<ChildEnvironment>) -> Bool {
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

            var size = CGSize(width: 0.0, height: 0.0)
            for child in updatedChildren {
                size.width = max(size.width, child.size.width)
                size.height = max(size.height, child.size.height)
            }

            for child in updatedChildren {
                context.add(child
                    .position(child.size.centered(in: CGRect(origin: CGPoint(), size: size)).center)
                )
            }

            return size
        }
    }
}
