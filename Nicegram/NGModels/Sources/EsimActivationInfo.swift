import Foundation

public struct EsimActivationInfo {
    public let icc: String
    public let lpa: String
    public let code: String
    
    public init(icc: String, lpa: String, code: String) {
        self.icc = icc
        self.lpa = lpa
        self.code = code
    }
}
