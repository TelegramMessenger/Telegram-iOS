import UIKit

public enum DeviceType {
    case phone
    case tablet
}

public enum DeviceMetrics: CaseIterable, Equatable {
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
    case unknown(screenSize: CGSize, statusBarHeight: CGFloat, onScreenNavigationHeight: CGFloat?)

    public static var allCases: [DeviceMetrics] {
        return [
            .iPhone4,
            .iPhone5,
            .iPhone6,
            .iPhone6Plus,
            .iPhoneX,
            .iPhoneXSMax,
            .iPad,
            .iPadPro10Inch,
            .iPadPro11Inch,
            .iPadPro,
            .iPadPro3rdGen
        ]
    }
    
    public init(screenSize: CGSize, statusBarHeight: CGFloat, onScreenNavigationHeight: CGFloat?) {
        var screenSize = screenSize
        if screenSize.width > screenSize.height {
            screenSize = CGSize(width: screenSize.height, height: screenSize.width)
        }
        
        let additionalSize = CGSize(width: screenSize.width, height: screenSize.height + 20.0)
        for device in DeviceMetrics.allCases {
            if let _ = onScreenNavigationHeight, device.onScreenNavigationHeight(inLandscape: false, systemOnScreenNavigationHeight: nil) == nil {
                if case .tablet = device.type {
                    if screenSize.height == 1024.0 && screenSize.width == 768.0 {
                    } else {
                        continue
                    }
                } else {
                    continue
                }
            }
            
            let width = device.screenSize.width
            let height = device.screenSize.height
            if ((screenSize.width.isEqual(to: width) && screenSize.height.isEqual(to: height)) || (additionalSize.width.isEqual(to: width) && additionalSize.height.isEqual(to: height))) {
                self = device
                return
            }
        }
        self = .unknown(screenSize: screenSize, statusBarHeight: statusBarHeight, onScreenNavigationHeight: onScreenNavigationHeight)
    }
    
    public var type: DeviceType {
        switch self {
            case .iPad, .iPadPro10Inch, .iPadPro11Inch, .iPadPro, .iPadPro3rdGen:
                return .tablet
            case let .unknown(screenSize, _, _) where screenSize.width >= 768.0 && screenSize.height >= 1024.0:
                return .tablet
            default:
                return .phone
        }
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
            case let .unknown(screenSize, _, _):
                return screenSize
        }
    }
    
    func safeInsets(inLandscape: Bool) -> UIEdgeInsets {
        switch self {
            case .iPhoneX, .iPhoneXSMax:
                return inLandscape ? UIEdgeInsets(top: 0.0, left: 44.0, bottom: 0.0, right: 44.0) : UIEdgeInsets(top: 44.0, left: 0.0, bottom: 0.0, right: 0.0)
            default:
                return UIEdgeInsets.zero
        }
    }
    
    func onScreenNavigationHeight(inLandscape: Bool, systemOnScreenNavigationHeight: CGFloat?) -> CGFloat? {
        switch self {
        case .iPhoneX, .iPhoneXSMax:
            return inLandscape ? 21.0 : 34.0
        case .iPadPro3rdGen, .iPadPro11Inch:
            return 21.0
        case .iPad, .iPadPro, .iPadPro10Inch:
            if let systemOnScreenNavigationHeight = systemOnScreenNavigationHeight, !systemOnScreenNavigationHeight.isZero {
                return 21.0
            } else {
                return nil
            }
        case let .unknown(_, _, onScreenNavigationHeight):
            return onScreenNavigationHeight
        default:
            return nil
        }
    }
    
    func statusBarHeight(for size: CGSize) -> CGFloat? {
        let value = self.statusBarHeight
        switch self {
        case .iPad, .iPadPro10Inch, .iPadPro11Inch, .iPadPro, .iPadPro3rdGen:
            return value
        default:
            if size.width < size.height {
                return value
            } else {
                return nil
            }
        }
    }
    
    var statusBarHeight: CGFloat {
        switch self {
            case .iPhoneX, .iPhoneXSMax:
                return 44.0
            case .iPadPro11Inch, .iPadPro3rdGen:
                return 24.0
            case let .unknown(_, statusBarHeight, _):
                return statusBarHeight
            default:
                return 20.0
        }
    }
    
    public func keyboardHeight(inLandscape: Bool) -> CGFloat {
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
                case .unknown:
                    return 216.0
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
                    return 302.0
                case .iPad, .iPadPro10Inch:
                    return 263.0
                case .iPadPro11Inch:
                    return 283.0
                case .iPadPro:
                    return 328.0
                case .iPadPro3rdGen:
                    return 348.0
                case .unknown:
                    return 216.0
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
                case .unknown:
                    return 37.0
            }
        } else {
            switch self {
                case .iPhone4, .iPhone5:
                    return 37.0
                case .iPhone6, .iPhoneX, .iPhoneXSMax:
                    return 44.0
                case .iPhone6Plus:
                    return 45.0
                case .iPad, .iPadPro10Inch, .iPadPro11Inch, .iPadPro, .iPadPro3rdGen:
                    return 50.0
                case .unknown:
                    return 44.0
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
    
    public var hasTopNotch: Bool {
        switch self {
            case .iPhoneX, .iPhoneXSMax:
                return true
            default:
                return false
        }
    }
}
