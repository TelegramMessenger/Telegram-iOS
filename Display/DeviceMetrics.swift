import UIKit

enum DeviceMetrics {
    case iPhone4
    case iPhone5
    case iPhone6
    case iPhone6Plus
    case iPhoneX
    case iPhoneXSMax
    case iPad
    case iPadPro
    
    static let allDevices = [iPhone4, iPhone5, iPhone6, iPhone6Plus, iPhoneX, iPhoneXSMax, iPad, iPadPro]
    
    static func forScreenSize(_ size: CGSize) -> DeviceMetrics? {
        for device in allDevices {
            let width = device.screenSize.width
            let height = device.screenSize.height
            
            if (size.width.isEqual(to: width) && size.height.isEqual(to: height)) || size.height.isEqual(to: width) && size.width.isEqual(to: height) {
                return device
            }
        }
        return nil
    }
    
    var screenSize: CGSize {
        switch self {
            case .iPhone4:
                return CGSize(width: 320.0, height: 480.0)
            case .iPhone5:
                return CGSize(width: 320.0, height: 568.0)
            case .iPhone6:
                return CGSize(width: 375.0, height: 667.0)
            case .iPhone6Plus:
                return CGSize(width: 414.0, height: 736.0)
            case .iPhoneX:
                return CGSize(width: 375.0, height: 812.0)
            case .iPhoneXSMax:
                return CGSize(width: 414.0, height: 896.0)
            case .iPad:
                return CGSize(width: 768.0, height: 1024.0)
            case .iPadPro:
                return CGSize(width: 1024.0, height: 1366.0)
        }
    }
    
    func safeAreaInsets(inLandscape: Bool) -> UIEdgeInsets {
        switch self {
            case .iPhoneX, .iPhoneXSMax:
                return inLandscape ? UIEdgeInsets(top: 0.0, left: 44.0, bottom: 0.0, right: 44.0) : UIEdgeInsets(top: 44.0, left: 0.0, bottom: 0.0, right: 0.0)
            default:
                return UIEdgeInsets.zero
        }
    }
    
    func onScreenNavigationHeight(inLandscape: Bool) -> CGFloat {
        switch self {
            case .iPhoneX, .iPhoneXSMax:
                return inLandscape ? 21.0 : 34.0
            default:
                return 0.0
        }
    }
    
    func standardInputHeight(inLandscape: Bool) -> CGFloat {
        if inLandscape {
            switch self {
                case .iPhone4, .iPhone5, .iPhone6, .iPhone6Plus:
                    return 162.0
                case .iPhoneX, .iPhoneXSMax:
                    return 171.0
                case .iPad, .iPadPro:
                    return 264.0
            }
        } else {
            switch self {
                case .iPhone4, .iPhone5, .iPhone6:
                    return 216.0
                case .iPhone6Plus:
                    return 226.0
                case .iPhoneX:
                    return 291.0
                case .iPhoneXSMax:
                    return 301.0
                case .iPad, .iPadPro:
                    return 264.0
            }
        }
    }
    
    func predictiveInputHeight(inLandscape: Bool) -> CGFloat {
        if inLandscape {
            switch self {
                case .iPhone4, .iPhone5, .iPhone6, .iPhone6Plus:
                    return 38.0
                case .iPhoneX, .iPhoneXSMax:
                    return 38.0
                case .iPad, .iPadPro:
                    return 42.0
            }
        } else {
            switch self {
                case .iPhone4, .iPhone5:
                    return 37.0
                case .iPhone6, .iPhoneX:
                    return 44.0
                case .iPhone6Plus:
                    return 42.0
                case .iPhoneXSMax:
                    return 45.0
                case .iPad, .iPadPro:
                    return 42.0
            }
        }
    }
}
