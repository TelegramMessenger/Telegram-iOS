import UIKit

public enum DeviceType {
    case phone
    case tablet
}

public enum DeviceMetrics: CaseIterable, Equatable {
    public struct Performance {
        public let isGraphicallyCapable: Bool
        
        init() {
            var length: Int = 4
            var cpuCount: UInt32 = 0
            sysctlbyname("hw.ncpu", &cpuCount, &length, nil, 0)
            
            self.isGraphicallyCapable = cpuCount >= 4
        }
    }
    
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
    case iPhone13Mini
    case iPhone13
    case iPhone13Pro
    case iPhone13ProMax
    case iPhone14Pro
    case iPhone14ProZoomed
    case iPhone14ProMax
    case iPhone14ProMaxZoomed
    case iPhone16Pro
    case iPhone16ProMax
    case iPhoneAir
    case iPhoneDuo
    case iPhone18Pro
    case iPhone18ProMax
    case iPad
    case iPadMini
    case iPad102Inch
    case iPadPro10Inch
    case iPadPro11Inch
    case iPadPro
    case iPadPro3rdGen
    case iPadMini6thGen
    case unknown(screenSize: CGSize, statusBarHeight: CGFloat, onScreenNavigationHeight: CGFloat?, screenCornerRadius: CGFloat)
    
    public static let performance = Performance()

    private static let currentModelIdentifier: String? = {
        #if targetEnvironment(simulator)
        return ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"]
        #else
        var systemInfo = utsname()
        guard uname(&systemInfo) == 0 else {
            return nil
        }
        return withUnsafeBytes(of: &systemInfo.machine) { bytes in
            return String(decoding: bytes.prefix(while: { $0 != 0 }), as: UTF8.self)
        }
        #endif
    }()

    /// The app's window moves between displays whose sensor housings and system bars differ (iPhone
    /// Duo: the outer and the inner display), so no per-model table can describe its insets and they
    /// are taken from the system instead. Keyed on the model identifier rather than on the resolved
    /// profile, because the profile is matched by screen size and depends on which display was
    /// active at launch.
    static let hasMultipleDisplays: Bool = DeviceMetrics.currentModelIdentifier == "iPhone19,4"

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
            .iPhone13Mini,
            .iPhone13,
            .iPhone13Pro,
            .iPhone13ProMax,
            .iPhone14Pro,
            .iPhone14ProZoomed,
            .iPhone14ProMax,
            .iPhone14ProMaxZoomed,
            .iPhone16Pro,
            .iPhone16ProMax,
            .iPhoneAir,
            .iPhoneDuo,
            .iPad,
            .iPadMini,
            .iPad102Inch,
            .iPadPro10Inch,
            .iPadPro11Inch,
            .iPadPro,
            .iPadPro3rdGen,
            .iPadMini6thGen,
            .iPhone18Pro,
            .iPhone18ProMax
        ]
    }
    
    public init(screenSize: CGSize, scale: CGFloat, statusBarHeight: CGFloat, onScreenNavigationHeight: CGFloat?) {
        self.init(screenSize: screenSize, scale: scale, statusBarHeight: statusBarHeight, onScreenNavigationHeight: onScreenNavigationHeight, modelIdentifier: DeviceMetrics.currentModelIdentifier)
    }

    init(screenSize: CGSize, scale: CGFloat, statusBarHeight: CGFloat, onScreenNavigationHeight: CGFloat?, modelIdentifier: String?) {
        var screenSize = screenSize
        if screenSize.width > screenSize.height {
            screenSize = CGSize(width: screenSize.height, height: screenSize.width)
        }
        
        let additionalSize = CGSize(width: screenSize.width, height: screenSize.height + 20.0)
        if let modelIdentifier = modelIdentifier {
            for device in DeviceMetrics.profiles(for: modelIdentifier) {
                let deviceScale: CGFloat = device == .iPhoneXr ? 2.0 : 3.0
                if scale == deviceScale && (device.profileScreenSize == screenSize || device.profileScreenSize == additionalSize) {
                    self = device
                    return
                }
            }
        }

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
            
            let width = device.profileScreenSize.width
            let height = device.profileScreenSize.height
            if ((screenSize.width.isEqual(to: width) && screenSize.height.isEqual(to: height)) || (additionalSize.width.isEqual(to: width) && additionalSize.height.isEqual(to: height))) {
                if case .iPhoneX = device, statusBarHeight == 47.0 {
                    self = .iPhone14ProMaxZoomed
                } else if case .iPhoneXSMax = device, scale == 2.0 {
                    self = .iPhoneXr
                } else {
                    self = device
                }
                return
            }
        }
        
        let screenCornerRadius: CGFloat
        if screenSize.width >= 1024.0 || screenSize.height >= 1024.0 {
            screenCornerRadius = 0.0
        } else if onScreenNavigationHeight != nil {
            screenCornerRadius = 39.0
        } else {
            screenCornerRadius = 0.0
        }
        
        self = .unknown(screenSize: screenSize, statusBarHeight: statusBarHeight, onScreenNavigationHeight: onScreenNavigationHeight, screenCornerRadius: screenCornerRadius)
    }

    private static func profiles(for modelIdentifier: String) -> [DeviceMetrics] {
        switch modelIdentifier {
            case "iPhone10,3", "iPhone10,6", "iPhone11,2", "iPhone12,3":
                return [.iPhoneX]
            case "iPhone11,4", "iPhone11,6", "iPhone12,5":
                return [.iPhoneXSMax]
            case "iPhone11,8", "iPhone12,1":
                return [.iPhoneXr]
            case "iPhone13,1":
                return [.iPhone12Mini]
            case "iPhone13,2", "iPhone13,3":
                return [.iPhone12]
            case "iPhone13,4":
                return [.iPhone12ProMax]
            case "iPhone14,4":
                return [.iPhone13Mini]
            case "iPhone14,5", "iPhone14,7", "iPhone17,5", "iPhone18,5":
                return [.iPhone13]
            case "iPhone14,2":
                return [.iPhone13Pro]
            case "iPhone14,3", "iPhone14,8":
                return [.iPhone13ProMax]
            case "iPhone15,2", "iPhone15,4", "iPhone16,1", "iPhone17,3":
                return [.iPhone14Pro, .iPhone14ProZoomed]
            case "iPhone15,3", "iPhone15,5", "iPhone16,2", "iPhone17,4":
                return [.iPhone14ProMax, .iPhone14ProMaxZoomed]
            case "iPhone17,1", "iPhone18,1", "iPhone18,3":
                return [.iPhone16Pro]
            case "iPhone17,2", "iPhone18,2":
                return [.iPhone16ProMax]
            case "iPhone18,4":
                return [.iPhoneAir]
            case "iPhone19,4":
                return [.iPhoneDuo]
            case "iPhone19,2":
                return [.iPhone18Pro]
            case "iPhone19,3", "iPhone19,7":
                return [.iPhone18ProMax]
            default:
                return []
        }
    }
    
    public var type: DeviceType {
        switch self {
            case .iPad, .iPad102Inch, .iPadPro10Inch, .iPadPro11Inch, .iPadPro, .iPadPro3rdGen:
                return .tablet
            case let .unknown(screenSize, _, _, _) where screenSize.width >= 744.0 && screenSize.height >= 1024.0:
                return .tablet
            default:
                return .phone
        }
    }
    
    /// The portrait screen size a profile was measured on. It exists only to recognize the device in
    /// `init(screenSize:…)`; layout must never read it, because the space an app gets is dictated by
    /// the system and can be resized (use the layout's own size, or `LayoutMetrics.windowSize`).
    private var profileScreenSize: CGSize {
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
            return CGSize(width: 375.0, height: 812.0)
        case .iPhone12:
            return CGSize(width: 390.0, height: 844.0)
        case .iPhone12ProMax:
            return CGSize(width: 428.0, height: 926.0)
        case .iPhone13Mini:
            return CGSize(width: 375.0, height: 812.0)
        case .iPhone13:
            return CGSize(width: 390.0, height: 844.0)
        case .iPhone13Pro:
            return CGSize(width: 390.0, height: 844.0)
        case .iPhone13ProMax:
            return CGSize(width: 428.0, height: 926.0)
        case .iPhone14Pro:
            return CGSize(width: 393.0, height: 852.0)
        case .iPhone14ProZoomed:
            return CGSize(width: 320.0, height: 693.0)
        case .iPhone14ProMax:
            return CGSize(width: 430.0, height: 932.0)
        case .iPhone14ProMaxZoomed:
            return CGSize(width: 375.0, height: 812.0)
        case .iPhone16Pro, .iPhone18Pro:
            return CGSize(width: 402.0, height: 874.0)
        case .iPhone16ProMax, .iPhone18ProMax:
            return CGSize(width: 440.0, height: 956.0)
        case .iPhoneAir:
            return CGSize(width: 420.0, height: 912.0)
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
        case .iPadMini6thGen:
            return CGSize(width: 744.0, height: 1133.0)
        case .iPhoneDuo:
            return CGSize(width: 466.0, height: 678.0)
        case let .unknown(screenSize, _, _, _):
            return screenSize
        }
    }
    
    public var screenCornerRadius: CGFloat {
        switch self {
            case .iPhoneX, .iPhoneXSMax:
                return 39.0
            case .iPhoneXr:
                return 41.5
            case .iPhone12Mini:
                return 44.0
            case .iPhone12, .iPhone13, .iPhone13Pro, .iPhone14ProZoomed:
                return 47.0 + UIScreenPixel
            case .iPhone12ProMax, .iPhone13ProMax, .iPhone14ProMaxZoomed:
                return 53.0 + UIScreenPixel
            case .iPhone14Pro, .iPhone14ProMax:
                return 55.0
            case .iPhone16Pro, .iPhone16ProMax, .iPhone18Pro, .iPhone18ProMax:
                return 62.0
            case .iPhoneAir:
                return 62.0
            case let .unknown(_, _, _, screenCornerRadius):
                return screenCornerRadius
            default:
                return 0.0
        }
    }
    
    func safeInsets(inLandscape: Bool) -> UIEdgeInsets {
        switch self {
            case .iPhoneX, .iPhoneXSMax, .iPhoneXr, .iPhone14ProZoomed, .iPhone14ProMaxZoomed:
                return inLandscape ? UIEdgeInsets(top: 0.0, left: 44.0, bottom: 0.0, right: 44.0) : UIEdgeInsets(top: 44.0, left: 0.0, bottom: 0.0, right: 0.0)
            case .iPhone12Mini, .iPhone12, .iPhone12ProMax, .iPhone13Mini, .iPhone13, .iPhone13Pro, .iPhone13ProMax:
                return inLandscape ? UIEdgeInsets(top: 0.0, left: 47.0, bottom: 0.0, right: 47.0) : UIEdgeInsets(top: 44.0, left: 0.0, bottom: 0.0, right: 0.0)
            case .iPhone14Pro, .iPhone14ProMax, .iPhone16Pro, .iPhone16ProMax, .iPhone18Pro, .iPhone18ProMax:
                return inLandscape ? UIEdgeInsets(top: 0.0, left: 59.0, bottom: 0.0, right: 59.0) : UIEdgeInsets(top: 44.0, left: 0.0, bottom: 0.0, right: 0.0)
            case .iPhoneAir:
                return inLandscape ? UIEdgeInsets(top: 0.0, left: 68.0, bottom: 0.0, right: 68.0) : UIEdgeInsets(top: 68.0, left: 0.0, bottom: 0.0, right: 0.0)
            default:
                return UIEdgeInsets.zero
        }
    }
    
    public func onScreenNavigationHeight(inLandscape: Bool, systemOnScreenNavigationHeight: CGFloat?) -> CGFloat? {
        switch self {
        case .iPhoneX, .iPhoneXSMax, .iPhoneXr, .iPhone12Mini, .iPhone12, .iPhone12ProMax, .iPhone13Mini, .iPhone13, .iPhone13Pro, .iPhone13ProMax, .iPhone14Pro, .iPhone14ProMax, .iPhone16Pro, .iPhone16ProMax, .iPhoneAir, .iPhoneDuo, .iPhone18Pro, .iPhone18ProMax:
            if #available(iOS 26.0, *) {
                return 20.0
            } else {
                return inLandscape ? 21.0 : 34.0
            }
        case .iPhone14ProZoomed:
            return inLandscape ? 21.0 : 28.0
        case .iPhone14ProMaxZoomed:
            return inLandscape ? 21.0 : 31.0
        case .iPadPro3rdGen, .iPadPro11Inch:
            return 21.0
        case .iPad, .iPadPro, .iPadPro10Inch, .iPadMini, .iPadMini6thGen:
            if let systemOnScreenNavigationHeight = systemOnScreenNavigationHeight, !systemOnScreenNavigationHeight.isZero {
                return 21.0
            } else {
                return nil
            }
        case let .unknown(_, _, onScreenNavigationHeight, _):
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
            case .iPhone14Pro, .iPhone14ProMax:
                return 54.0
            case .iPhone14ProMaxZoomed:
                return 47.0
            case .iPhone16Pro, .iPhone16ProMax, .iPhone18Pro, .iPhone18ProMax:
                return 54.0
            case .iPhoneAir:
                return 59.0
            case .iPhoneX, .iPhoneXSMax, .iPhoneXr, .iPhone12Mini, .iPhone12, .iPhone12ProMax, .iPhone13Mini, .iPhone13, .iPhone13Pro, .iPhone13ProMax:
                return 44.0
            case .iPadPro11Inch, .iPadPro3rdGen, .iPadMini, .iPadMini6thGen:
                return 24.0
            case let .unknown(_, statusBarHeight, _, _):
                return statusBarHeight
            default:
                return 20.0
        }
    }
    
    public func keyboardHeight(inLandscape: Bool) -> CGFloat {
        var keyboardHeight = _keyboardHeight(inLandscape: inLandscape)
        if #available(iOS 26.0, *) {
            if !inLandscape {
                keyboardHeight -= 1.0
            }
        }
        return keyboardHeight
    }
    
    private func _keyboardHeight(inLandscape: Bool) -> CGFloat {
        if inLandscape {
            switch self {
            case .iPhone4, .iPhone5:
                return 162.0
            case .iPhone6, .iPhone6Plus:
                return 163.0
            case .iPhoneX, .iPhoneXSMax, .iPhoneXr, .iPhone12Mini, .iPhone12, .iPhone12ProMax, .iPhone13Mini, .iPhone13, .iPhone13Pro, .iPhone13ProMax, .iPhone14Pro, .iPhone14ProZoomed, .iPhone14ProMax, .iPhone14ProMaxZoomed, .iPhone16Pro, .iPhone16ProMax, .iPhone18Pro, .iPhone18ProMax:
                return 172.0
            case .iPhoneAir:
                return 172.0
            case .iPad, .iPad102Inch, .iPadPro10Inch:
                return 348.0
            case .iPadPro11Inch, .iPadMini, .iPadMini6thGen:
                return 368.0
            case .iPadPro:
                return 421.0
            case .iPadPro3rdGen:
                return 441.0
            case .iPhoneDuo:
                return 172.0
            case .unknown:
                return 216.0
            }
        } else {
            switch self {
                case .iPhone4, .iPhone5, .iPhone6:
                    return 216.0
                case .iPhone6Plus:
                    return 226.0
                case .iPhoneX, .iPhone12Mini, .iPhone12, .iPhone13Mini, .iPhone13, .iPhone13Pro, .iPhone14Pro, .iPhone14ProZoomed, .iPhone14ProMaxZoomed, .iPhone16Pro, .iPhone18Pro:
                    return 292.0
                case .iPhoneAir:
                    return 292.0
                case .iPhoneXSMax, .iPhoneXr, .iPhone12ProMax, .iPhone13ProMax, .iPhone14ProMax, .iPhone16ProMax, .iPhone18ProMax:
                    return 302.0
                case .iPad, .iPad102Inch, .iPadPro10Inch:
                    return 263.0
                case .iPadPro11Inch:
                    return 283.0
                case .iPadPro, .iPadMini, .iPadMini6thGen:
                    return 328.0
                case .iPadPro3rdGen:
                    return 348.0
                case .iPhoneDuo:
                    return 292.0
                case .unknown:
                    return 216.0
            }
        }
    }
    
    func predictiveInputHeight(inLandscape: Bool) -> CGFloat {
        if inLandscape {
            switch self {
                case .iPhone4, .iPhone5, .iPhone6, .iPhone6Plus, .iPhoneX, .iPhoneXSMax, .iPhoneXr, .iPhone12Mini, .iPhone12, .iPhone12ProMax, .iPhone13Mini, .iPhone13, .iPhone13Pro, .iPhone13ProMax, .iPhone14Pro, .iPhone14ProZoomed, .iPhone14ProMax, .iPhone14ProMaxZoomed, .iPhone16Pro, .iPhone16ProMax, .iPhoneAir, .iPhoneDuo, .iPhone18Pro, .iPhone18ProMax:
                    return 37.0
                case .iPad, .iPad102Inch, .iPadPro10Inch, .iPadPro11Inch, .iPadPro, .iPadPro3rdGen, .iPadMini, .iPadMini6thGen:
                    return 50.0
                case .unknown:
                    return 37.0
            }
        } else {
            switch self {
                case .iPhone4, .iPhone5:
                    return 37.0
                case .iPhone6, .iPhoneX, .iPhoneXSMax, .iPhoneXr, .iPhone12Mini, .iPhone12, .iPhone12ProMax, .iPhone13Mini, .iPhone13, .iPhone13Pro, .iPhone13ProMax, .iPhone14Pro, .iPhone14ProZoomed, .iPhone14ProMax, .iPhone14ProMaxZoomed, .iPhone16Pro, .iPhone16ProMax, .iPhoneAir, .iPhoneDuo, .iPhone18Pro, .iPhone18ProMax:
                    return 44.0
                case .iPhone6Plus:
                    return 45.0
                case .iPad, .iPad102Inch, .iPadPro10Inch, .iPadPro11Inch, .iPadPro, .iPadPro3rdGen, .iPadMini, .iPadMini6thGen:
                    return 50.0
                case .unknown:
                    return 44.0
            }
        }
    }
    
    public func standardInputHeight(inLandscape: Bool) -> CGFloat {
        return self.keyboardHeight(inLandscape: inLandscape) + predictiveInputHeight(inLandscape: inLandscape)
    }
    
    public var cutoutFrame: CGRect? {
        let size: CGSize
        let top: CGFloat
        switch self {
        case .iPhoneX, .iPhoneXSMax:
            size = CGSize(width: 223.0, height: 30.0)
            top = 0.0
        case .iPhoneXr:
            size = CGSize(width: 246.0, height: 33.0)
            top = 0.0
        case .iPhone12Mini:
            size = CGSize(width: 242.0, height: 34.0)
            top = 0.0
        case .iPhone12, .iPhone12ProMax:
            size = CGSize(width: 222.0, height: 32.0)
            top = 0.0
        case .iPhone13Mini:
            size = CGSize(width: 189.0, height: 38.0)
            top = 0.0
        case .iPhone13, .iPhone13Pro, .iPhone13ProMax:
            size = CGSize(width: 176.0, height: 34.0)
            top = 0.0
        case .iPhone14Pro, .iPhone14ProMax:
            size = CGSize(width: 126.0, height: 112.0 / 3.0)
            top = 11.0
        case .iPhone16Pro, .iPhone16ProMax:
            size = CGSize(width: 126.0, height: 112.0 / 3.0)
            top = 41.0 / 3.0
        case .iPhone18Pro, .iPhone18ProMax:
            // Temporarily use the iPhone 16 Pro / Pro Max cutout geometry.
            size = CGSize(width: 126.0, height: 112.0 / 3.0)
            top = 41.0 / 3.0
        case .iPhoneAir:
            size = CGSize(width: 126.0, height: 112.0 / 3.0)
            top = 59.0 / 3.0
        case .iPhone14ProZoomed, .iPhone14ProMaxZoomed:
            let standardDevice: DeviceMetrics = self == .iPhone14ProZoomed ? .iPhone14Pro : .iPhone14ProMax
            guard let standardFrame = standardDevice.cutoutFrame else {
                return nil
            }
            let factor = self.profileScreenSize.width / standardDevice.profileScreenSize.width
            size = CGSize(width: standardFrame.width * factor, height: standardFrame.height * factor)
            top = standardFrame.minY * factor
        default:
            return nil
        }
        return CGRect(x: (self.profileScreenSize.width - size.width) / 2.0, y: top, width: size.width, height: size.height)
    }

    public var hasTopNotch: Bool {
        switch self {
            case .iPhoneX, .iPhoneXSMax, .iPhoneXr, .iPhone12Mini, .iPhone12, .iPhone12ProMax:
                return true
            default:
                return false
        }
    }
    
    public var hasDynamicIsland: Bool {
        switch self {
            case .iPhone14Pro, .iPhone14ProZoomed, .iPhone14ProMax, .iPhone14ProMaxZoomed, .iPhone16Pro, .iPhone16ProMax, .iPhoneAir, .iPhone18Pro, .iPhone18ProMax:
                return true
            default:
                return false
        }
    }
    
    public var showAppBadge: Bool {
        if case .iPhoneX = self {
            return false
        }
        return self.hasTopNotch
    }
}
