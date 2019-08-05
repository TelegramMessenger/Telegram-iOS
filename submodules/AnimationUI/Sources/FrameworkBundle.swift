import Foundation

private class FrameworkBundleClass: NSObject {
}

let frameworkBundle: Bundle = Bundle(for: FrameworkBundleClass.self)
