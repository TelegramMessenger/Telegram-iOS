import Foundation
import SwiftSignalKit
import AsyncDisplayKit

protocol AnimationRenderer {
    func render(queue: Queue, width: Int, height: Int, data: Data, completion: @escaping () -> Void)
}
