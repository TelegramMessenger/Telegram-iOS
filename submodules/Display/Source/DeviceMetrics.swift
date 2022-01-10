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
    case iPhoneXr
    case iPhone12Mini
    case iPhone12
    case iPhone12ProMax
    case iPad
    case iPadMini
    case iPad102Inch
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
            .iPhoneXr,
            .iPhone12Mini,
            .iPhone12,
            .iPhone12ProMax,
            .iPad,
            .iPadMini,
            .iPad102Inch,
            .iPadPro10Inch,
            .iPadPro11Inch,
            .iPadPro,
            .iPadPro3rdGen
        ]
    }
    
    public init(screenSize: CGSize, scale: CGFloat, statusBarHeight: CGFloat, onScreenNavigationHeight: CGFloat?) {
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
                if case .iPhoneXSMax = device, scale == 2.0 {
                    self = .iPhoneXr
                } else {
                    self = device
                }
                return
            }
        }
        self = .unknown(screenSize: screenSize, statusBarHeight: statusBarHeight, onScreenNavigationHeight: onScreenNavigationHeight)
    }
    
    public var type: DeviceType {
        switch self {
            case .iPad, .iPad102Inch, .iPadPro10Inch, .iPadPro11Inch, .iPadPro, .iPadPro3rdGen:
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
            case .iPhoneXSMax, .iPhoneXr:
                return CGSize(width: 414.0, height: 896.0)
            case .iPhone12Mini:
                return CGSize(width: 360.0, height: 780.0)
            case .iPhone12:
                return CGSize(width: 390.0, height: 844.0)
            case .iPhone12ProMax:
                return CGSize(width: 428.0, height: 926.0)
            case .iPad:
                return CGSize(width: 768.0, height: 1024.0)
            case .iPadMini:
                return CGSize(width: 744.0, height: 1133.0)
            case .iPad102Inch:
                return CGSize(width: 810.0, height: 1080.0)
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
    
    public var screenCornerRadius: CGFloat {
        switch self {
            case .iPhoneX, .iPhoneXSMax:
                return 39.0
            case .iPhoneXr:
                return 41.0 + UIScreenPixel
            case .iPhone12Mini:
                return 44.0
            case .iPhone12:
                return 47.0 + UIScreenPixel
            case .iPhone12ProMax:
                return 53.0 + UIScreenPixel
            case let .unknown(_, _, onScreenNavigationHeight):
                if let _ = onScreenNavigationHeight {
                    return 39.0
                } else {
                    return 0.0
                }
            default:
                return 0.0
        }
    }
    
    func safeInsets(inLandscape: Bool) -> UIEdgeInsets {
        switch self {
            case .iPhoneX, .iPhoneXSMax, .iPhoneXr, .iPhone12Mini, .iPhone12, .iPhone12ProMax:
                return inLandscape ? UIEdgeInsets(top: 0.0, left: 44.0, bottom: 0.0, right: 44.0) : UIEdgeInsets(top: 44.0, left: 0.0, bottom: 0.0, right: 0.0)
            default:
                return UIEdgeInsets.zero
        }
    }
    
    func onScreenNavigationHeight(inLandscape: Bool, systemOnScreenNavigationHeight: CGFloat?) -> CGFloat? {
        switch self {
        case .iPhoneX, .iPhoneXSMax, .iPhoneXr, .iPhone12Mini, .iPhone12, .iPhone12ProMax:
            return inLandscape ? 21.0 : 34.0
        case .iPadPro3rdGen, .iPadPro11Inch:
            return 21.0
        case .iPad, .iPadPro, .iPadPro10Inch, .iPadMini:
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
        if self.type == .tablet {
            return value
        } else {
            if size.width < size.height {
                return value
            } else {
                return nil
            }
        }
    }
    
    var statusBarHeight: CGFloat {
        switch self {
            case .iPhoneX, .iPhoneXSMax, .iPhoneXr, .iPhone12Mini, .iPhone12, .iPhone12ProMax:
                return 44.0
            case .iPadPro11Inch, .iPadPro3rdGen, .iPadMini:
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
                case .iPhoneX, .iPhoneXSMax, .iPhoneXr, .iPhone12Mini, .iPhone12, .iPhone12ProMax:
                    return 172.0
                case .iPad, .iPad102Inch, .iPadPro10Inch:
                    return 348.0
                case .iPadPro11Inch, .iPadMini:
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
                case .iPhoneX, .iPhone12Mini, .iPhone12:
                    return 291.0
                case .iPhoneXSMax, .iPhoneXr, .iPhone12ProMax:
                    return 302.0
                case .iPad, .iPad102Inch, .iPadPro10Inch:
                    return 263.0
                case .iPadPro11Inch:
                    return 283.0
                case .iPadPro, .iPadMini:
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
                case .iPhone4, .iPhone5, .iPhone6, .iPhone6Plus, .iPhoneX, .iPhoneXSMax, .iPhoneXr, .iPhone12Mini, .iPhone12, .iPhone12ProMax:
                    return 37.0
                case .iPad, .iPad102Inch, .iPadPro10Inch, .iPadPro11Inch, .iPadPro, .iPadPro3rdGen, .iPadMini:
                    return 50.0
                case .unknown:
                    return 37.0
            }
        } else {
            switch self {
                case .iPhone4, .iPhone5:
                    return 37.0
                case .iPhone6, .iPhoneX, .iPhoneXSMax, .iPhoneXr, .iPhone12Mini, .iPhone12, .iPhone12ProMax:
                    return 44.0
                case .iPhone6Plus:
                    return 45.0
                case .iPad, .iPad102Inch, .iPadPro10Inch, .iPadPro11Inch, .iPadPro, .iPadPro3rdGen, .iPadMini:
                    return 50.0
                case .unknown:
                    return 44.0
            }
        }
    }
    
    public var hasTopNotch: Bool {
        switch self {
            case .iPhoneX, .iPhoneXSMax, .iPhoneXr, .iPhone12Mini, .iPhone12, .iPhone12ProMax:
                return true
            default:
                return false
        }
    }
}
