import Foundation
import UIKit

public func horizontalContainerFillingSizeForLayout(layout: ContainerViewLayout, sideInset: CGFloat) -> CGFloat {
    if case .regular = layout.metrics.widthClass {
        return min(layout.size.width, 414.0) - sideInset * 2.0
    } else {
        return min(layout.size.width, 428.0) - sideInset * 2.0
    }
}
