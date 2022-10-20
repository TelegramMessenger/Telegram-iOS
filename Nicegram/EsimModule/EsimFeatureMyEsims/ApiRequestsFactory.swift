import EsimApiClientDefinition
import EsimDTO

public extension ApiRequest {
    static func getAllUserEsims(path: String = "profiles/list") -> ApiRequest<UserEsimsResponseDTO> {
        return .get(path: path)
    }
    
    static func getEsimsDetails(path: String = "profiles", esimsIcc: [String]) -> ApiRequest<UserEsimsResponseDTO> {
        let body = EsimDetailsBody(profiles: esimsIcc)
        return .post(path: path, body: body)
    }
}

public struct EsimDetailsBody: Encodable {
    public let profiles: [String]
    
    public init(profiles: [String]) {
        self.profiles = profiles
    }
}
