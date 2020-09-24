import Foundation
import BuildConfig

public struct NGEnvObj: Decodable {
    public let premium_bundle: String
    public let ng_api_url: String
    public let validator_url: String
    public let ng_lab_url: String
    public let ng_lab_token: String
}


func parseNGEnv() -> NGEnvObj {
    let ngEnv = BuildConfig(baseAppBundleId: Bundle.main.bundleIdentifier!).ngEnv
    let decodedData = Data(base64Encoded: ngEnv)!

    return try! JSONDecoder().decode(NGEnvObj.self, from: decodedData)
}

public var NGENV = parseNGEnv()
