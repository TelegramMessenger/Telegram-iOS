import Foundation
import AsyncDisplayKit

public protocol AsyncLayoutable: class {
    static func asyncLayout(maybeNode: Self?) -> (constrainedSize: CGSize) -> (CGSize, () -> Self)
}
