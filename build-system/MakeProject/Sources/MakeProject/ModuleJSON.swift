import Foundation

struct ModuleDefinition: Codable {
    let name: String
    let moduleName: String?
    let type: String
    let path: String
    let sources: [String]
    let deps: [String]?
    let copts: [String]?
    let cxxopts: [String]?
    let defines: [String]?
    let includes: [String]?
    let sdkFrameworks: [String]?
    let sdkDylibs: [String]?
    let hdrs: [String]?
    let textualHdrs: [String]?
    let weakSdkFrameworks: [String]?

    enum CodingKeys: String, CodingKey {
        case name
        case moduleName = "module_name"
        case type
        case path
        case sources
        case deps
        case copts
        case cxxopts
        case defines
        case includes
        case sdkFrameworks = "sdk_frameworks"
        case sdkDylibs = "sdk_dylibs"
        case hdrs
        case textualHdrs = "textual_hdrs"
        case weakSdkFrameworks = "weak_sdk_frameworks"
    }
}

enum ModuleType: String {
    case swiftLibrary = "swift_library"
    case objcLibrary = "objc_library"
    case ccLibrary = "cc_library"
    case xcframework = "apple_static_xcframework_import"

    init?(from definition: ModuleDefinition) {
        self.init(rawValue: definition.type)
    }
}

func loadModules(from path: String) throws -> [String: ModuleDefinition] {
    let url = URL(fileURLWithPath: path)
    let data = try Data(contentsOf: url)
    return try JSONDecoder().decode([String: ModuleDefinition].self, from: data)
}
