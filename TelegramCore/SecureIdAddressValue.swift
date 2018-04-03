import Foundation

public struct SecureIdAddressValue: Equatable {
    public var street1: String
    public var street2: String
    public var city: String
    public var region: String
    public var countryCode: String
    public var postcode: String
    
    public init(street1: String, street2: String, city: String, region: String, countryCode: String, postcode: String) {
        self.street1 = street1
        self.street2 = street2
        self.city = city
        self.region = region
        self.countryCode = countryCode
        self.postcode = postcode
    }
    
    public static func ==(lhs: SecureIdAddressValue, rhs: SecureIdAddressValue) -> Bool {
        if lhs.street1 != rhs.street1 {
            return false
        }
        if lhs.street2 != rhs.street2 {
            return false
        }
        if lhs.city != rhs.city {
            return false
        }
        if lhs.region != rhs.region {
            return false
        }
        if lhs.countryCode != rhs.countryCode {
            return false
        }
        if lhs.postcode != rhs.postcode {
            return false
        }
        return true
    }
}

extension SecureIdAddressValue {
    init?(dict: [String: Any], fileReferences: [SecureIdVerificationDocumentReference]) {
        guard let street1 = dict["street_line1"] as? String else {
            return nil
        }
        let street2 = (dict["street_line2"] as? String) ?? ""
        guard let city = dict["city"] as? String else {
            return nil
        }
        guard let region = dict["region"] as? String else {
            return nil
        }
        guard let countryCode = dict["country_iso2"] as? String else {
            return nil
        }
        guard let postcode = dict["post_code"] as? String else {
            return nil
        }
        
        self.init(street1: street1, street2: street2, city: city, region: region, countryCode: countryCode, postcode: postcode)
    }
    
    func serialize() -> ([String: Any], [SecureIdVerificationDocumentReference]) {
        var dict: [String: Any] = [:]
        dict["street_line1"] = self.street1
        if !self.street2.isEmpty {
            dict["street_line2"] = self.street2   
        }
        dict["city"] = self.city
        dict["region"] = self.region
        dict["country_iso2"] = self.countryCode
        dict["post_code"] = self.postcode
        
        return (dict, [])
    }
}
