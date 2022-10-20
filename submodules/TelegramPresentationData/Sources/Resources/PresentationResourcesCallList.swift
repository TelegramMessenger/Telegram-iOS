import Foundation
import UIKit
import Display
import AppBundle

public struct PresentationResourcesCallList {
    public static func outgoingIcon(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.callListOutgoingIcon.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Call List/OutgoingIcon"), color: theme.list.disclosureArrowColor)
        })
    }
    
    public static func outgoingVideoIcon(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.callListOutgoingVideoIcon.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Call List/OutgoingVideoIcon"), color: theme.list.disclosureArrowColor)
        })
    }
    
    public static func infoButton(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.callListInfoButton.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Call List/InfoButton"), color: theme.list.itemAccentColor)
        })
    }
}
