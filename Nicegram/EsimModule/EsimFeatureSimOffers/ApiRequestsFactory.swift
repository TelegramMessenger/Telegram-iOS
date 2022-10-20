import EsimApiClientDefinition

public extension ApiRequest {
    static func plans(path: String = "plans") -> ApiRequest<PlansResponseDTO> {
        return .get(path: path)
    }
}
