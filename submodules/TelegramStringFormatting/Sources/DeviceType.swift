import UIKit

public func stringForDeviceType() -> String {
    let model = UIDevice.current.model.lowercased()
    if model.contains("ipad") {
        return "iPad"
    } else if model.contains("ipod") {
        return "iPod touch"
    } else {
        return "iPhone"
    }
}
