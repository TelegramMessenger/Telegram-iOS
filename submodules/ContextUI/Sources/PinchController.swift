import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData

public protocol PinchController: ViewController {
    func addRelativeContentOffset(_ offset: CGPoint, transition: ContainedViewLayoutTransition)
}

public var makePinchControllerImpl: ((
    _ sourceNode: PinchSourceContainerNode,
    _ disableScreenshots: Bool,
    _ getContentAreaInScreenSpace: @escaping () -> CGRect
) -> PinchController)?

public func makePinchController(
    sourceNode: PinchSourceContainerNode,
    disableScreenshots: Bool = false,
    getContentAreaInScreenSpace: @escaping () -> CGRect
) -> PinchController {
    return makePinchControllerImpl!(
        sourceNode,
        disableScreenshots,
        getContentAreaInScreenSpace
    )
}
