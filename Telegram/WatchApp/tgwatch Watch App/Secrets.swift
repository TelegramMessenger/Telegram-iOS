import Foundation

enum Secrets {
    static var apiId: Int {
        let raw = Bundle.main.object(forInfoDictionaryKey: "TG_API_ID")
        if let i = raw as? Int { return i }
        if let s = raw as? String, let i = Int(s) { return i }
        return 0
    }

    static var apiHash: String {
        Bundle.main.object(forInfoDictionaryKey: "TG_API_HASH") as? String ?? ""
    }
}
