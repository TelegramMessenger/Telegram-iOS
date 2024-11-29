import Foundation
import UIKit

public final class TransformContents<ChildEnvironment: Equatable>: CombinedComponent {
    public typealias EnvironmentType = ChildEnvironment

    private let content: AnyComponent<ChildEnvironment>
    private let fixedSize: CGSize?
    private let translation: CGPoint

    public init(content: AnyComponent<ChildEnvironment>, fixedSize: CGSize? = nil, translation: CGPoint) {
        self.content = content
        self.fixedSize = fixedSize
        self.translation = translation
    }

    public static func ==(lhs: TransformContents<ChildEnvironment>, rhs: TransformContents<ChildEnvironment>) -> Bool {
        if lhs.content != rhs.content {
            return false
        }
        if lhs.fixedSize != rhs.fixedSize {
            return false
        }
        if lhs.translation != rhs.translation {
            return false
        }
        return true
    }

    public static var body: Body {
        let child = Child(environment: ChildEnvironment.self)

        return { context in
            let child = child.update(
                component: context.component.content,
                environment: { context.environment[ChildEnvironment.self] },
                availableSize: context.availableSize,
                transition: context.transition
            )

            let size = context.component.fixedSize ?? child.size

            var childFrame = child.size.centered(in: CGRect(origin: CGPoint(), size: size))
            childFrame.origin.x += context.component.translation.x
            childFrame.origin.y += context.component.translation.y

            context.add(child
                .position(childFrame.center)
            )

            return size
        }
    }
}
