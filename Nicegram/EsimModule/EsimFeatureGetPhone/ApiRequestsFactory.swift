import EsimApiClientDefinition

public extension ApiRequest {
    static func secondPhoneCountries(path: String = "second-phone/countries") -> ApiRequest<SecondPhoneCountriesDTO> {
        return .get(path: path)
    }
    
    static func countryPhones(path: String = "second-phone/phone-numbers", countryCode: String) -> ApiRequest<CountryPhonesDTO> {
        return .get(path: "\(path)/\(countryCode.uppercased())")
    }
    
    static func phoneServicePrices(path: String = "second-phone/prices", phoneNumber: String) -> ApiRequest<PhoneServicePricesDTO> {
        return .get(path: path, queryParams: ["phone": phoneNumber])
    }
    
    static func activatePhone(path: String = "second-phone/buy-number", phoneNumber: String, countryCode: String) -> ApiRequest<Void> {
        let body = ActivateNumberInputDTO(phoneNumber: phoneNumber, countryCode: countryCode)
        return .post(path: path, body: body)
    }
}
