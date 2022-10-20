import EsimApiClientDefinition

public extension ApiRequest {
    static func secondPhoneUserInfo(path: String = "second-phone/user") -> ApiRequest<SecondPhoneUserInfoResponseDTO> {
        return .get(path: path)
    }
}
