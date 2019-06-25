import Foundation
import AsyncDisplayKit

protocol AnimationRenderer {
    func render(width: Int, height: Int, bytes: UnsafeRawPointer, length: Int)
}
