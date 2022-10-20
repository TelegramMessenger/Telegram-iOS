struct ActivateNumberInputDTO: Encodable {
    let phoneNumber: String
    let countryCode: String
    
    enum CodingKeys: String, CodingKey {
        case phoneNumber = "phone"
        case countryCode = "country_code"
    }
}
