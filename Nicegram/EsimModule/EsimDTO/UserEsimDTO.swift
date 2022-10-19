import Foundation
import EsimApiClientDefinition

public struct UserEsimDTO: Decodable {
    public let icc: String
    public let code: String
    public let providerType: String
    public let lpaDisplay: String
    public let phoneNumber: String?
    public let title: String?
    public let customTitle: String?
    public let regionId: Int
    public let isoName2: String
    public let balance: Double?
    public let usedVolumeBytes: Int
    public let totalVolumeBytes: Int
    @EsimApiOptionalDate public var endDate: Date?
    @EsimApiBool public var active: Bool
    @EsimApiBool public var expired: Bool
    @EsimApiUrl public var image: URL?
}

public struct UserEsimsResponseDTO: Decodable {
    public let profiles: [UserEsimDTO]
}

public struct UserEsimResponseDTO: Decodable {
    public let esim: UserEsimDTO
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        let esims = try container.decode([UserEsimDTO].self)
        if let esim = esims.first {
            self.esim = esim
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Empty esims list")
        }
    }
}
