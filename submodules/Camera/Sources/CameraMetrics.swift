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
    
    case iPhoneX
    case iPhoneXS
    
    case iPhone12
    case iPhone12Mini
    case iPhone12Pro
    case iPhone12ProMax
   
    case iPhone13
    case iPhone13Mini
    case iPhone13Pro
    case iPhone13ProMax
    
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
        case .iPhoneX:
            return ["iPhone11,2"]
        case .iPhoneXS:
            return ["iPhone11,4", "iPhone11,6"]
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
        case .iPhoneX:
            return "iPhone X"
        case .iPhoneXS:
            return "iPhone XS"
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
