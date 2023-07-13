import Foundation

public extension Camera {
    enum Metrics {
        case singleCamera
        case iPhone14
        case iPhone14Plus
        case iPhone14Pro
        case iPhone14ProMax
        case unknown
        
        init(model: DeviceModel) {
            switch model {
            case  .iPodTouch1, .iPodTouch2, .iPodTouch3, .iPodTouch4, .iPodTouch5, .iPodTouch6, .iPodTouch7:
                self = .singleCamera
            case .iPhone14:
                self = .iPhone14
            case .iPhone14Plus:
                self = .iPhone14Plus
            case .iPhone14Pro:
                self = .iPhone14Pro
            case .iPhone14ProMax:
                self = .iPhone14ProMax
            case .unknown:
                self = .unknown
            default:
                self = .unknown
            }
        }
        
        public var zoomLevels: [Float] {
            switch self {
            case .singleCamera:
                return [1.0]
            case .iPhone14:
                return [0.5, 1.0, 2.0]
            case .iPhone14Plus:
                return [0.5, 1.0, 2.0]
            case .iPhone14Pro:
                return [0.5, 1.0, 2.0, 3.0]
            case .iPhone14ProMax:
                return [0.5, 1.0, 2.0, 3.0]
            case .unknown:
                return [1.0, 2.0]
            }
        }
    }
}

enum DeviceModel: CaseIterable, Equatable {
    static var allCases: [DeviceModel] {
        return [
            .iPodTouch1,
            .iPodTouch2,
            .iPodTouch3,
            .iPodTouch4,
            .iPodTouch5,
            .iPodTouch6,
            .iPodTouch7,
            .iPhone,
            .iPhone3G,
            .iPhone3GS,
            .iPhone4,
            .iPhone4S,
            .iPhone5,
            .iPhone5C,
            .iPhone5S,
            .iPhone6,
            .iPhone6Plus,
            .iPhone6S,
            .iPhone6SPlus,
            .iPhoneSE,
            .iPhone7,
            .iPhone7Plus,
            .iPhone8,
            .iPhone8Plus,
            .iPhoneX,
            .iPhoneXS,
            .iPhoneXR,
            .iPhone11,
            .iPhone11Pro,
            .iPhone11ProMax,
            .iPhone12,
            .iPhone12Mini,
            .iPhone12Pro,
            .iPhone12ProMax,
            .iPhone13,
            .iPhone13Mini,
            .iPhone13Pro,
            .iPhone13ProMax,
            .iPhone14,
            .iPhone14Plus,
            .iPhone14Pro,
            .iPhone14ProMax
        ]
    }
    
    case iPodTouch1
    case iPodTouch2
    case iPodTouch3
    case iPodTouch4
    case iPodTouch5
    case iPodTouch6
    case iPodTouch7
    
    case iPhone
    case iPhone3G
    case iPhone3GS
    
    case iPhone4
    case iPhone4S
    
    case iPhone5
    case iPhone5C
    case iPhone5S
    
    case iPhone6
    case iPhone6Plus
    case iPhone6S
    case iPhone6SPlus
    
    case iPhoneSE
    
    case iPhone7
    case iPhone7Plus
    case iPhone8
    case iPhone8Plus
    
    case iPhoneX
    case iPhoneXS
    case iPhoneXSMax
    case iPhoneXR
    
    case iPhone11
    case iPhone11Pro
    case iPhone11ProMax
    
    case iPhoneSE2ndGen
        
    case iPhone12
    case iPhone12Mini
    case iPhone12Pro
    case iPhone12ProMax
   
    case iPhone13
    case iPhone13Mini
    case iPhone13Pro
    case iPhone13ProMax
    
    case iPhoneSE3rdGen
    
    case iPhone14
    case iPhone14Plus
    case iPhone14Pro
    case iPhone14ProMax
    
    case unknown(String)
    
    var modelId: [String] {
        switch self {
        case .iPodTouch1:
            return ["iPod1,1"]
        case .iPodTouch2:
            return ["iPod2,1"]
        case .iPodTouch3:
            return ["iPod3,1"]
        case .iPodTouch4:
            return ["iPod4,1"]
        case .iPodTouch5:
            return ["iPod5,1"]
        case .iPodTouch6:
            return ["iPod7,1"]
        case .iPodTouch7:
            return ["iPod9,1"]
        case .iPhone:
            return ["iPhone1,1"]
        case .iPhone3G:
            return ["iPhone1,2"]
        case .iPhone3GS:
            return ["iPhone2,1"]
        case .iPhone4:
            return ["iPhone3,1", "iPhone3,2", "iPhone3,3"]
        case .iPhone4S:
            return ["iPhone4,1", "iPhone4,2", "iPhone4,3"]
        case .iPhone5:
            return ["iPhone5,1", "iPhone5,2"]
        case .iPhone5C:
            return ["iPhone5,3", "iPhone5,4"]
        case .iPhone5S:
            return ["iPhone6,1", "iPhone6,2"]
        case .iPhone6:
            return ["iPhone7,2"]
        case .iPhone6Plus:
            return ["iPhone7,1"]
        case .iPhone6S:
            return ["iPhone8,1"]
        case .iPhone6SPlus:
            return ["iPhone8,2"]
        case .iPhoneSE:
            return ["iPhone8,4"]
        case .iPhone7:
            return ["iPhone9,1", "iPhone9,3"]
        case .iPhone7Plus:
            return ["iPhone9,2", "iPhone9,4"]
        case .iPhone8:
            return ["iPhone10,1", "iPhone10,4"]
        case .iPhone8Plus:
            return ["iPhone10,2", "iPhone10,5"]
        case .iPhoneX:
            return ["iPhone10,3", "iPhone10,6"]
        case .iPhoneXS:
            return ["iPhone11,2"]
        case .iPhoneXSMax:
            return ["iPhone11,4", "iPhone11,6"]
        case .iPhoneXR:
            return ["iPhone11,8"]
        case .iPhone11:
            return ["iPhone12,1"]
        case .iPhone11Pro:
            return ["iPhone12,3"]
        case .iPhone11ProMax:
            return ["iPhone12,5"]
        case .iPhoneSE2ndGen:
            return ["iPhone12,8"]
        case .iPhone12:
            return ["iPhone13,2"]
        case .iPhone12Mini:
            return ["iPhone13,1"]
        case .iPhone12Pro:
            return ["iPhone13,3"]
        case .iPhone12ProMax:
            return ["iPhone13,4"]
        case .iPhone13:
            return ["iPhone14,5"]
        case .iPhone13Mini:
            return ["iPhone14,4"]
        case .iPhone13Pro:
            return ["iPhone14,2"]
        case .iPhone13ProMax:
            return ["iPhone14,3"]
        case .iPhoneSE3rdGen:
            return ["iPhone14,6"]
        case .iPhone14:
            return ["iPhone14,7"]
        case .iPhone14Plus:
            return ["iPhone14,8"]
        case .iPhone14Pro:
            return ["iPhone15,2"]
        case .iPhone14ProMax:
            return ["iPhone15,3"]
        case let .unknown(modelId):
            return [modelId]
        }
    }
    
    var modelName: String {
        switch self {
        case .iPodTouch1:
            return "iPod touch 1G"
        case .iPodTouch2:
            return "iPod touch 2G"
        case .iPodTouch3:
            return "iPod touch 3G"
        case .iPodTouch4:
            return "iPod touch 4G"
        case .iPodTouch5:
            return "iPod touch 5G"
        case .iPodTouch6:
            return "iPod touch 6G"
        case .iPodTouch7:
            return "iPod touch 7G"
        case .iPhone:
            return "iPhone"
        case .iPhone3G:
            return "iPhone 3G"
        case .iPhone3GS:
            return "iPhone 3GS"
        case .iPhone4:
            return "iPhone 4"
        case .iPhone4S:
            return "iPhone 4S"
        case .iPhone5:
            return "iPhone 5"
        case .iPhone5C:
            return "iPhone 5C"
        case .iPhone5S:
            return "iPhone 5S"
        case .iPhone6:
            return "iPhone 6"
        case .iPhone6Plus:
            return "iPhone 6 Plus"
        case .iPhone6S:
            return "iPhone 6S"
        case .iPhone6SPlus:
            return "iPhone 6S Plus"
        case .iPhoneSE:
            return "iPhone SE"
        case .iPhone7:
            return "iPhone 7"
        case .iPhone7Plus:
            return "iPhone 7 Plus"
        case .iPhone8:
            return "iPhone 8"
        case .iPhone8Plus:
            return "iPhone 8 Plus"
        case .iPhoneX:
            return "iPhone X"
        case .iPhoneXS:
            return "iPhone XS"
        case .iPhoneXSMax:
            return "iPhone XS Max"
        case .iPhoneXR:
            return "iPhone XR"
        case .iPhone11:
            return "iPhone 11"
        case .iPhone11Pro:
            return "iPhone 11 Pro"
        case .iPhone11ProMax:
            return "iPhone 11 Pro Max"
        case .iPhoneSE2ndGen:
            return "iPhone SE (2nd gen)"
        case .iPhone12:
            return "iPhone 12"
        case .iPhone12Mini:
            return "iPhone 12 mini"
        case .iPhone12Pro:
            return "iPhone 12 Pro"
        case .iPhone12ProMax:
            return "iPhone 12 Pro Max"
        case .iPhone13:
            return "iPhone 13"
        case .iPhone13Mini:
            return "iPhone 13 mini"
        case .iPhone13Pro:
            return "iPhone 13 Pro"
        case .iPhone13ProMax:
            return "iPhone 13 Pro Max"
        case .iPhoneSE3rdGen:
            return "iPhone SE (3rd gen)"
        case .iPhone14:
            return "iPhone 14"
        case .iPhone14Plus:
            return "iPhone 14 Plus"
        case .iPhone14Pro:
            return "iPhone 14 Pro"
        case .iPhone14ProMax:
            return "iPhone 14 Pro Max"
        case let .unknown(modelId):
            if modelId.hasPrefix("iPhone") {
                return "Unknown iPhone"
            } else if modelId.hasPrefix("iPod") {
                return "Unknown iPod"
            } else if modelId.hasPrefix("iPad") {
                return "Unknown iPad"
            } else {
                return "Unknown Device"
            }
        }
    }
    
    var isIpad: Bool {
        return self.modelId.first?.hasPrefix("iPad") ?? false
    }
    
    static let current = DeviceModel()
    
    private init() {
        var systemInfo = utsname()
        uname(&systemInfo)
        let modelCode = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                ptr in String.init(validatingUTF8: ptr)
            }
        }
        var result: DeviceModel?
        if let modelCode {
            for model in DeviceModel.allCases {
                if model.modelId.contains(modelCode) {
                    result = model
                    break
                }
            }
        }
        if let result {
            self = result
        } else {
            self = .unknown(modelCode ?? "")
        }
    }
}
