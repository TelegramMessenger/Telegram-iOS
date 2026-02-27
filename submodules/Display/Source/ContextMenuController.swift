import Foundation
import UIKit
import AsyncDisplayKit

public final class ContextMenuControllerPresentationArguments {
    public let sourceNodeAndRect: () -> (ASDisplayNode, CGRect, ASDisplayNode, CGRect)?
    public let bounce: Bool
    
    public init(sourceNodeAndRect: @escaping () -> (ASDisplayNode, CGRect, ASDisplayNode, CGRect)?, bounce: Bool = true) {
        self.sourceNodeAndRect = sourceNodeAndRect
        self.bounce = bounce
    }
}

public protocol ContextMenuController: ViewController, StandalonePresentableController {
    var centerHorizontally: Bool { get set }
    var dismissed: (() -> Void)? { get set }
    var dismissOnTap: ((UIView, CGPoint) -> Bool)? { get set }
}

public struct ContextMenuControllerArguments {
    public var actions: [ContextMenuAction]
    public var catchTapsOutside: Bool
    public var hasHapticFeedback: Bool
    public var blurred: Bool
    public var skipCoordnateConversion: Bool
    public var isDark: Bool
    
    public init(actions: [ContextMenuAction], catchTapsOutside: Bool, hasHapticFeedback: Bool, blurred: Bool, skipCoordnateConversion: Bool, isDark: Bool) {
        self.actions = actions
        self.catchTapsOutside = catchTapsOutside
        self.hasHapticFeedback = hasHapticFeedback
        self.blurred = blurred
        self.skipCoordnateConversion = skipCoordnateConversion
        self.isDark = isDark
    }
}

private var contextMenuControllerProvider: ((ContextMenuControllerArguments) -> ContextMenuController)?

public func setContextMenuControllerProvider(_ f: @escaping (ContextMenuControllerArguments) -> ContextMenuController) {
    contextMenuControllerProvider = f
}

public func makeContextMenuController(actions: [ContextMenuAction], catchTapsOutside: Bool = false, hasHapticFeedback: Bool = false, blurred: Bool = false, isDark: Bool = true, skipCoordnateConversion: Bool = false) -> ContextMenuController {
    guard let contextMenuControllerProvider = contextMenuControllerProvider else {
        preconditionFailure()
    }
    return contextMenuControllerProvider(ContextMenuControllerArguments(
        actions: actions,
        catchTapsOutside: catchTapsOutside,
        hasHapticFeedback: hasHapticFeedback,
        blurred: blurred,
        skipCoordnateConversion: skipCoordnateConversion,
        isDark: isDark
    ))
}
