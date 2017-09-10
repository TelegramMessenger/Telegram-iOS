import Foundation
import UIKit

private class FrameworkBundleClass: NSObject {
}

let frameworkBundle: Bundle = Bundle(for: FrameworkBundleClass.self)
private let screenScaleFactor = Int(UIScreen.main.scale)

extension UIImage {
    convenience init?(bundleImageName: String) {
        self.init(named: bundleImageName, in: frameworkBundle, compatibleWith: nil)
    }
}
