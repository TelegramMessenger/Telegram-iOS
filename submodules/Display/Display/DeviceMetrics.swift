import UIKit

public enum DeviceMetrics: CaseIterable {
    case iPhone4
    case iPhone5
    case iPhone6
    case iPhone6Plus
    case iPhoneX
    case iPhoneXSMax
    case iPad
    case iPadPro10Inch
    case iPadPro11Inch
    case iPadPro
    case iPadPro3rdGen

    public static func forScreenSize(_ size: CGSize, hintHasOnScreenNavigation: Bool = false) -> DeviceMetrics? {
        let additionalSize = CGSize(width: size.width, height: size.height + 20.0)
        for device in DeviceMetrics.allCases {
            let width = device.screenSize.width
            let height = device.screenSize.height
            
            if ((size.width.isEqual(to: width) && size.height.isEqual(to: height)) || size.height.isEqual(to: width) && size.width.isEqual(to: height)) || ((additionalSize.width.isEqual(to: width) && additionalSize.height.isEqual(to: height)) || additionalSize.height.isEqual(to: width) && additionalSize.width.isEqual(to: height)) {
                if hintHasOnScreenNavigation && device.onScreenNavigationHeight(inLandscape: false) == nil {
                    continue
                }
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
            case .iPadPro10Inch:
                return CGSize(width: 834.0, height: 1112.0)
            case .iPadPro11Inch:
                return CGSize(width: 834.0, height: 1194.0)
            case .iPadPro, .iPadPro3rdGen:
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
    
    func onScreenNavigationHeight(inLandscape: Bool) -> CGFloat? {
        switch self {
            case .iPhoneX, .iPhoneXSMax:
                return inLandscape ? 21.0 : 34.0
            case .iPadPro3rdGen, .iPadPro11Inch:
                return 21.0
            default:
                return nil
        }
    }
    
    var statusBarHeight: CGFloat {
        switch self {
            case .iPhoneX, .iPhoneXSMax:
                return 44.0
            case .iPadPro11Inch, .iPadPro3rdGen:
                return 24.0
            default:
                return 20.0
        }
    }
    
    public func standardInputHeight(inLandscape: Bool) -> CGFloat {
        if inLandscape {
            switch self {
                case .iPhone4, .iPhone5:
                    return 162.0
                case .iPhone6, .iPhone6Plus:
                    return 163.0
                case .iPhoneX, .iPhoneXSMax:
                    return 172.0
                case .iPad, .iPadPro10Inch:
                    return 348.0
                case .iPadPro11Inch:
                    return 368.0
                case .iPadPro:
                    return 421.0
                case .iPadPro3rdGen:
                    return 441.0
            }
        } else {
            switch self {
                case .iPhone4, .iPhone5, .iPhone6:
                    return 216.0
                case .iPhone6Plus:
                    return 227.0
                case .iPhoneX:
                    return 291.0
                case .iPhoneXSMax:
                    return 302.0
                case .iPad, .iPadPro10Inch:
                    return 263.0
                case .iPadPro11Inch:
                    return 283.0
                case .iPadPro:
                    return 328.0
                case .iPadPro3rdGen:
                    return 348.0
            }
        }
    }
    
    func predictiveInputHeight(inLandscape: Bool) -> CGFloat {
        if inLandscape {
            switch self {
                case .iPhone4, .iPhone5, .iPhone6, .iPhone6Plus, .iPhoneX, .iPhoneXSMax:
                    return 37.0
                case .iPad, .iPadPro10Inch, .iPadPro11Inch, .iPadPro, .iPadPro3rdGen:
                    return 50.0
            }
        } else {
            switch self {
                case .iPhone4, .iPhone5:
                    return 37.0
                case .iPhone6, .iPhone6Plus, .iPhoneX, .iPhoneXSMax:
                    return 44.0
                case .iPad, .iPadPro10Inch, .iPadPro11Inch, .iPadPro, .iPadPro3rdGen:
                    return 50.0
            }
        }
    }
    
    public func previewingContentSize(inLandscape: Bool) -> CGSize {
        let screenSize = self.screenSize
        if inLandscape {
            switch self {
                case .iPhone5:
                    return CGSize(width: screenSize.height, height: screenSize.width - 10.0)
                case .iPhone6:
                    return CGSize(width: screenSize.height, height: screenSize.width - 22.0)
                case .iPhone6Plus:
                    return CGSize(width: screenSize.height, height: screenSize.width - 22.0)
                case .iPhoneX:
                    return CGSize(width: screenSize.height, height: screenSize.width + 48.0)
                case .iPhoneXSMax:
                    return CGSize(width: screenSize.height, height: screenSize.width - 30.0)
                default:
                    return CGSize(width: screenSize.height, height: screenSize.width - 10.0)
            }
        } else {
            switch self {
                case .iPhone5:
                    return CGSize(width: screenSize.width, height: screenSize.height - 50.0)
                case .iPhone6:
                    return CGSize(width: screenSize.width, height: screenSize.height - 97.0)
                case .iPhone6Plus:
                    return CGSize(width: screenSize.width, height: screenSize.height - 95.0)
                case .iPhoneX:
                    return CGSize(width: screenSize.width, height: screenSize.height - 154.0)
                case .iPhoneXSMax:
                    return CGSize(width: screenSize.width, height: screenSize.height - 84.0)
                default:
                    return CGSize(width: screenSize.width, height: screenSize.height - 50.0)
            }
        }
    }
}
