import Foundation
import Contacts
import TelegramCore
import FlatBuffers
import FlatSerialization

public final class DeviceContactPhoneNumberData: Equatable {
    public let label: String
    public let value: String
    
    public init(label: String, value: String) {
        self.label = label
        self.value = value
    }
    
    init(flatBuffersObject: TelegramCore_DeviceContactPhoneNumberData) {
        self.label = flatBuffersObject.label
        self.value = flatBuffersObject.value
    }
    
    public func encodeToFlatBuffers(builder: inout FlatBufferBuilder) -> Offset {
        let labelOffset = builder.create(string: self.label)
        let valueOffset = builder.create(string: self.value)
        
        return TelegramCore_DeviceContactPhoneNumberData.createDeviceContactPhoneNumberData(
            &builder,
            labelOffset: labelOffset,
            valueOffset: valueOffset
        )
    }
    
    public static func == (lhs: DeviceContactPhoneNumberData, rhs: DeviceContactPhoneNumberData) -> Bool {
        if lhs.label != rhs.label {
            return false
        }
        if lhs.value != rhs.value {
            return false
        }
        return true
    }
}

public final class DeviceContactEmailAddressData: Equatable {
    public let label: String
    public let value: String
    
    public init(label: String, value: String) {
        self.label = label
        self.value = value
    }
    
    public static func == (lhs: DeviceContactEmailAddressData, rhs: DeviceContactEmailAddressData) -> Bool {
        if lhs.label != rhs.label {
            return false
        }
        if lhs.value != rhs.value {
            return false
        }
        return true
    }
}

public final class DeviceContactUrlData: Equatable {
    public let label: String
    public let value: String
    
    public init(label: String, value: String) {
        self.label = label
        self.value = value
    }
    
    public static func == (lhs: DeviceContactUrlData, rhs: DeviceContactUrlData) -> Bool {
        if lhs.label != rhs.label {
            return false
        }
        if lhs.value != rhs.value {
            return false
        }
        return true
    }
}

public final class DeviceContactAddressData: Equatable, Hashable {
    public let label: String
    public let street1: String
    public let street2: String
    public let state: String
    public let city: String
    public let country: String
    public let postcode: String
    
    public init(label: String, street1: String, street2: String, state: String, city: String, country: String, postcode: String) {
        self.label = label
        self.street1 = street1
        self.street2 = street2
        self.state = state
        self.city = city
        self.country = country
        self.postcode = postcode
    }
    
    public static func == (lhs: DeviceContactAddressData, rhs: DeviceContactAddressData) -> Bool {
        if lhs.label != rhs.label {
            return false
        }
        if lhs.street1 != rhs.street1 {
            return false
        }
        if lhs.street2 != rhs.street2 {
            return false
        }
        if lhs.state != rhs.state {
            return false
        }
        if lhs.city != rhs.city {
            return false
        }
        if lhs.country != rhs.country {
            return false
        }
        if lhs.postcode != rhs.postcode {
            return false
        }
        return true
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.label)
        hasher.combine(self.street1)
        hasher.combine(self.street2)
        hasher.combine(self.state)
        hasher.combine(self.city)
        hasher.combine(self.country)
        hasher.combine(self.postcode)
    }
}

public final class DeviceContactSocialProfileData: Equatable, Hashable {
    public let label: String
    public let service: String
    public let username: String
    public let url: String
    
    public init(label: String, service: String, username: String, url: String) {
        self.label = label
        self.service = service
        self.username = username
        self.url = url
    }
    
    public static func == (lhs: DeviceContactSocialProfileData, rhs: DeviceContactSocialProfileData) -> Bool {
        if lhs.label != rhs.label {
            return false
        }
        if lhs.service != rhs.service {
            return false
        }
        if lhs.username != rhs.username {
            return false
        }
        if lhs.url != rhs.url {
            return false
        }
        return true
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.label)
        hasher.combine(self.service)
        hasher.combine(self.username)
        hasher.combine(self.url)
    }
}

public final class DeviceContactInstantMessagingProfileData: Equatable, Hashable {
    public let label: String
    public let service: String
    public let username: String
    
    public init(label: String, service: String, username: String) {
        self.label = label
        self.service = service
        self.username = username
    }
    
    public static func == (lhs: DeviceContactInstantMessagingProfileData, rhs: DeviceContactInstantMessagingProfileData) -> Bool {
        if lhs.label != rhs.label {
            return false
        }
        if lhs.service != rhs.service {
            return false
        }
        if lhs.username != rhs.username {
            return false
        }
        return true
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.label)
        hasher.combine(self.service)
        hasher.combine(self.username)
    }
}

public let phonebookUsernamePathPrefix = "@id"
private let phonebookUsernamePrefix = "https://t.me/" + phonebookUsernamePathPrefix

public extension DeviceContactUrlData {
    convenience init(appProfile: EnginePeer.Id) {
        self.init(label: "Telegram", value: "\(phonebookUsernamePrefix)\(appProfile.id._internalGetInt64Value())")
    }
}

public func parseAppSpecificContactReference(_ value: String) -> EnginePeer.Id? {
    if !value.hasPrefix(phonebookUsernamePrefix) {
        return nil
    }
    let idString = String(value[value.index(value.startIndex, offsetBy: phonebookUsernamePrefix.count)...])
    if let id = Int64(idString) {
        return EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value(id))
    }
    return nil
}

public final class DeviceContactBasicData: Equatable {
    public let firstName: String
    public let lastName: String
    public let phoneNumbers: [DeviceContactPhoneNumberData]
    
    public init(firstName: String, lastName: String, phoneNumbers: [DeviceContactPhoneNumberData]) {
        self.firstName = firstName
        self.lastName = lastName
        self.phoneNumbers = phoneNumbers
    }
    
    public init(flatBuffersObject: TelegramCore_StoredDeviceContactData) {
        self.firstName = flatBuffersObject.firstName
        self.lastName = flatBuffersObject.lastName
        
        if flatBuffersObject.phoneNumbersCount == 1 {
            self.phoneNumbers = [
                DeviceContactPhoneNumberData(flatBuffersObject: flatBuffersObject.phoneNumbers(at: 0)!)
            ]
        } else {
            var phoneNumbers: [DeviceContactPhoneNumberData] = []
            for i in 0 ..< flatBuffersObject.phoneNumbersCount {
                phoneNumbers.append(DeviceContactPhoneNumberData(flatBuffersObject: flatBuffersObject.phoneNumbers(at: i)!))
            }
            self.phoneNumbers = phoneNumbers
        }
    }
    
    public func encodeToFlatBuffers(builder: inout FlatBufferBuilder) -> Offset {
        let phoneNumberOffsets = self.phoneNumbers.map { $0.encodeToFlatBuffers(builder: &builder) }
        let phoneNumberOffset = builder.createVector(ofOffsets: phoneNumberOffsets, len: phoneNumberOffsets.count)
        
        let firstNameOffset = builder.create(string: self.firstName)
        let lastNameOffset = builder.create(string: self.lastName)
        
        return TelegramCore_StoredDeviceContactData.createStoredDeviceContactData(
            &builder,
            firstNameOffset: firstNameOffset,
            lastNameOffset: lastNameOffset,
            phoneNumbersVectorOffset: phoneNumberOffset
        )
    }
    
    public static func ==(lhs: DeviceContactBasicData, rhs: DeviceContactBasicData) -> Bool {
        if lhs.firstName != rhs.firstName {
            return false
        }
        if lhs.lastName != rhs.lastName {
            return false
        }
        if lhs.phoneNumbers != rhs.phoneNumbers {
            return false
        }
        return true
    }
}

public final class DeviceContactDataState: Codable {
    private enum CodingKeys: String, CodingKey {
        case contactsData
        case contactsKeys
        case telegramReferencesKeys
        case telegramReferencesValues
        case stateToken
    }
    
    public let contacts: [String: DeviceContactBasicData]
    public let telegramReferences: [EnginePeer.Id: String]
    public let stateToken: Data?
    
    public init(contacts: [String: DeviceContactBasicData], telegramReferences: [EnginePeer.Id: String], stateToken: Data?) {
        self.contacts = contacts
        self.telegramReferences = telegramReferences
        self.stateToken = stateToken
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let contactsData = try container.decode([Data].self, forKey: .contactsData).map { data in
            var byteBuffer = ByteBuffer(data: data)
            let deserializedValue = FlatBuffers_getRoot(byteBuffer: &byteBuffer) as TelegramCore_StoredDeviceContactData
            let parsedValue = DeviceContactBasicData(flatBuffersObject: deserializedValue)
            return parsedValue
        }
        let contactsKeys = try container.decode([String].self, forKey: .contactsKeys)
        
        var contacts: [String: DeviceContactBasicData] = [:]
        for i in 0 ..< min(contactsData.count, contactsKeys.count) {
            contacts[contactsKeys[i]] = contactsData[i]
        }
        self.contacts = contacts
        
        let telegramReferencesKeys = try container.decode([Int64].self, forKey: .telegramReferencesKeys).map { value in
            return EnginePeer.Id(value)
        }
        let telegramReferencesValues = try container.decode([String].self, forKey: .telegramReferencesValues)
        
        var telegramReferences: [EnginePeer.Id: String] = [:]
        for i in 0 ..< min(telegramReferencesValues.count, telegramReferencesKeys.count) {
            telegramReferences[telegramReferencesKeys[i]] = telegramReferencesValues[i]
        }
        self.telegramReferences = telegramReferences
        
        self.stateToken = try container.decodeIfPresent(Data.self, forKey: .stateToken)
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        var contactsData: [Data] = []
        var contactsKeys: [String] = []
        for (key, contact) in self.contacts {
            var builder = FlatBufferBuilder(initialSize: 1024)
            let offset = contact.encodeToFlatBuffers(builder: &builder)
            builder.finish(offset: offset)
            contactsData.append(builder.data)
            contactsKeys.append(key)
        }
        
        var telegramReferencesKeys: [Int64] = []
        var telegramReferencesValues: [String] = []
        for (key, value) in self.telegramReferences {
            telegramReferencesKeys.append(key.toInt64())
            telegramReferencesValues.append(value)
        }
        
        try container.encode(contactsKeys, forKey: .contactsKeys)
        try container.encode(contactsData, forKey: .contactsData)
        
        try container.encode(telegramReferencesKeys, forKey: .telegramReferencesKeys)
        try container.encode(telegramReferencesValues, forKey: .telegramReferencesValues)
        
        try container.encodeIfPresent(stateToken, forKey: .stateToken)
    }
}

public final class DeviceContactBasicDataWithReference: Equatable {
    public let stableId: DeviceContactStableId
    public let basicData: DeviceContactBasicData
    
    public init(stableId: DeviceContactStableId, basicData: DeviceContactBasicData) {
        self.stableId = stableId
        self.basicData = basicData
    }
    
    public static func ==(lhs: DeviceContactBasicDataWithReference, rhs: DeviceContactBasicDataWithReference) -> Bool {
        return lhs.stableId == rhs.stableId && lhs.basicData == rhs.basicData
    }
}

public final class DeviceContactExtendedData: Equatable {
    public let basicData: DeviceContactBasicData
    
    public let middleName: String
    public let prefix: String
    public let suffix: String
    public let organization: String
    public let jobTitle: String
    public let department: String
    public let emailAddresses: [DeviceContactEmailAddressData]
    public let urls: [DeviceContactUrlData]
    public let addresses: [DeviceContactAddressData]
    public let birthdayDate: Date?
    public let socialProfiles: [DeviceContactSocialProfileData]
    public let instantMessagingProfiles: [DeviceContactInstantMessagingProfileData]
    public let note: String
     
    public init(basicData: DeviceContactBasicData, middleName: String, prefix: String, suffix: String, organization: String, jobTitle: String, department: String, emailAddresses: [DeviceContactEmailAddressData], urls: [DeviceContactUrlData], addresses: [DeviceContactAddressData], birthdayDate: Date?, socialProfiles: [DeviceContactSocialProfileData], instantMessagingProfiles: [DeviceContactInstantMessagingProfileData], note: String) {
        self.basicData = basicData
        self.middleName = middleName
        self.prefix = prefix
        self.suffix = suffix
        self.organization = organization
        self.jobTitle = jobTitle
        self.department = department
        self.emailAddresses = emailAddresses
        self.urls = urls
        self.addresses = addresses
        self.birthdayDate = birthdayDate
        self.socialProfiles = socialProfiles
        self.instantMessagingProfiles = instantMessagingProfiles
        self.note = note
    }
    
    public static func ==(lhs: DeviceContactExtendedData, rhs: DeviceContactExtendedData) -> Bool {
        if lhs.basicData != rhs.basicData {
            return false
        }
        if lhs.middleName != rhs.middleName {
            return false
        }
        if lhs.prefix != rhs.prefix {
            return false
        }
        if lhs.suffix != rhs.suffix {
            return false
        }
        if lhs.organization != rhs.organization {
            return false
        }
        if lhs.jobTitle != rhs.jobTitle {
            return false
        }
        if lhs.department != rhs.department {
            return false
        }
        if lhs.emailAddresses != rhs.emailAddresses {
            return false
        }
        if lhs.urls != rhs.urls {
            return false
        }
        if lhs.addresses != rhs.addresses {
            return false
        }
        if lhs.birthdayDate != rhs.birthdayDate {
            return false
        }
        if lhs.socialProfiles != rhs.socialProfiles {
            return false
        }
        if lhs.instantMessagingProfiles != rhs.instantMessagingProfiles {
            return false
        }
        if lhs.note != rhs.note {
            return false
        }
        return true
    }
}

public extension DeviceContactExtendedData {
    convenience init?(vcard: Data) {
        guard let contact = (try? CNContactVCardSerialization.contacts(with: vcard))?.first else {
            return nil
        }
        self.init(contact: contact)
    }
    
    func asMutableCNContact() -> CNMutableContact {
        let contact = CNMutableContact()
        contact.givenName = self.basicData.firstName
        contact.familyName = self.basicData.lastName
        contact.namePrefix = self.prefix
        contact.nameSuffix = self.suffix
        contact.middleName = self.middleName
        contact.phoneNumbers = self.basicData.phoneNumbers.map { phoneNumber -> CNLabeledValue<CNPhoneNumber> in
            return CNLabeledValue<CNPhoneNumber>(label: phoneNumber.label, value: CNPhoneNumber(stringValue: phoneNumber.value))
        }
        contact.emailAddresses = self.emailAddresses.map { email -> CNLabeledValue<NSString> in
            CNLabeledValue<NSString>(label: email.label, value: email.value as NSString)
        }
        contact.urlAddresses = self.urls.map { url -> CNLabeledValue<NSString> in
            CNLabeledValue<NSString>(label: url.label, value: url.value as NSString)
        }
        contact.socialProfiles = self.socialProfiles.map({ profile -> CNLabeledValue<CNSocialProfile> in
            return CNLabeledValue<CNSocialProfile>(label: profile.label, value: CNSocialProfile(urlString: nil, username: profile.username, userIdentifier: nil, service: profile.service))
        })
        contact.instantMessageAddresses = self.instantMessagingProfiles.map({ profile -> CNLabeledValue<CNInstantMessageAddress> in
            return CNLabeledValue<CNInstantMessageAddress>(label: profile.label, value: CNInstantMessageAddress(username: profile.username, service: profile.service))
        })
        contact.postalAddresses = self.addresses.map({ address -> CNLabeledValue<CNPostalAddress> in
            let value = CNMutablePostalAddress()
            value.street = address.street1 + "\n" + address.street2
            value.state = address.state
            value.city = address.city
            value.country = address.country
            value.postalCode = address.postcode
            return CNLabeledValue<CNPostalAddress>(label: address.label, value: value)
        })
        if let birthdayDate = self.birthdayDate {
            contact.birthday = Calendar(identifier: .gregorian).dateComponents([.day, .month, .year], from: birthdayDate)
        }
        return contact
    }
    
    func serializedVCard() -> String? {
        if #available(iOSApplicationExtension 9.0, iOS 9.0, *) {
            guard let data = try? CNContactVCardSerialization.data(with: [self.asMutableCNContact()]) else {
                return nil
            }
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
    
    convenience init(contact: CNContact) {
        var phoneNumbers: [DeviceContactPhoneNumberData] = []
        for number in contact.phoneNumbers {
            phoneNumbers.append(DeviceContactPhoneNumberData(label: number.label ?? "", value: number.value.stringValue))
        }
        var emailAddresses: [DeviceContactEmailAddressData] = []
        for email in contact.emailAddresses {
            emailAddresses.append(DeviceContactEmailAddressData(label: email.label ?? "", value: email.value as String))
        }
        
        var urls: [DeviceContactUrlData] = []
        for url in contact.urlAddresses {
            urls.append(DeviceContactUrlData(label: url.label ?? "", value: url.value as String))
        }
        
        var addresses: [DeviceContactAddressData] = []
        for address in contact.postalAddresses {
            addresses.append(DeviceContactAddressData(label: address.label ?? "", street1: address.value.street, street2: "", state: address.value.state, city: address.value.city, country: address.value.country, postcode: address.value.postalCode))
        }
        
        var birthdayDate: Date?
        if let birthday = contact.birthday {
            if let date = birthday.date {
                birthdayDate = date
            }
        }
        var socialProfiles: [DeviceContactSocialProfileData] = []
        for profile in contact.socialProfiles {
            socialProfiles.append(DeviceContactSocialProfileData(label: profile.label ?? "", service: profile.value.service, username: profile.value.username, url: profile.value.urlString))
        }
        
        var instantMessagingProfiles: [DeviceContactInstantMessagingProfileData] = []
        for profile in contact.instantMessageAddresses {
            instantMessagingProfiles.append(DeviceContactInstantMessagingProfileData(label: profile.label ?? "", service: profile.value.service, username: profile.value.username))
        }
        
        let basicData = DeviceContactBasicData(firstName: contact.givenName, lastName: contact.familyName, phoneNumbers: phoneNumbers)
        self.init(basicData: basicData, middleName: contact.middleName, prefix: contact.namePrefix, suffix: contact.nameSuffix, organization: contact.organizationName, jobTitle: contact.jobTitle, department: contact.departmentName, emailAddresses: emailAddresses, urls: urls, addresses: addresses, birthdayDate: birthdayDate, socialProfiles: socialProfiles, instantMessagingProfiles: instantMessagingProfiles, note: "")
    }
    
    var isPrimitive: Bool {
        if self.basicData.phoneNumbers.count > 1 {
            return false
        }
        if !self.organization.isEmpty {
            return false
        }
        if !self.jobTitle.isEmpty {
            return false
        }
        if !self.department.isEmpty {
            return false
        }
        if !self.emailAddresses.isEmpty {
            return false
        }
        if !self.urls.isEmpty {
            return false
        }
        if !self.addresses.isEmpty {
            return false
        }
        if self.birthdayDate != nil {
            return false
        }
        if !self.socialProfiles.isEmpty {
            return false
        }
        if !self.instantMessagingProfiles.isEmpty {
            return false
        }
        if !self.note.isEmpty {
            return false
        }
        return true
    }
}
 
public extension DeviceContactExtendedData {
    convenience init?(peer: EnginePeer) {
        guard case let .user(user) = peer else {
            return nil
        }
        var phoneNumbers: [DeviceContactPhoneNumberData] = []
        if let phone = user.phone, !phone.isEmpty {
            phoneNumbers.append(DeviceContactPhoneNumberData(label: "_$!<Mobile>!$_", value: phone))
        }
        self.init(basicData: DeviceContactBasicData(firstName: user.firstName ?? "", lastName: user.lastName ?? "", phoneNumbers: phoneNumbers), middleName: "", prefix: "", suffix: "", organization: "", jobTitle: "", department: "", emailAddresses: [], urls: [], addresses: [], birthdayDate: nil, socialProfiles: [], instantMessagingProfiles: [], note: "")
    }
}

public extension DeviceContactAddressData {
    var asPostalAddress: CNPostalAddress {
        let address = CNMutablePostalAddress()
        if !self.street1.isEmpty {
            address.street = self.street1
        }
        if !self.city.isEmpty {
            address.city = self.city
        }
        if !self.state.isEmpty {
            address.state = self.state
        }
        if !self.country.isEmpty {
            address.country = self.country
        }
        if !self.postcode.isEmpty {
            address.postalCode = self.postcode
        }
        return address
    }
    
    var dictionary: [String: String]  {
        var dictionary: [String: String] = [:]
        if !self.street1.isEmpty {
            dictionary["Street"] = self.street1
        }
        if !self.city.isEmpty {
            dictionary["City"] = self.city
        }
        if !self.state.isEmpty {
            dictionary["State"] = self.state
        }
        if !self.country.isEmpty {
            dictionary["Country"] = self.country
        }
        if !self.postcode.isEmpty {
            dictionary["ZIP"] = self.postcode
        }
        return dictionary
    }
    
    var string: String {
        var array: [String] = []
        if !self.street1.isEmpty {
            array.append(self.street1)
        }
        if !self.city.isEmpty {
            array.append(self.city)
        }
        if !self.state.isEmpty {
            array.append(self.state)
        }
        if !self.country.isEmpty {
            array.append(self.country)
        }
        if !self.postcode.isEmpty {
            array.append(self.postcode)
        }
        return array.joined(separator: " ")
    }
    
    var displayString: String {
        var array: [String] = []
        if !self.street1.isEmpty {
            array.append(self.street1)
        }
        if !self.city.isEmpty {
            array.append(self.city)
        }
        if !self.state.isEmpty {
            array.append(self.state)
        }
        if !self.country.isEmpty {
            array.append(self.country)
        }
        return array.joined(separator: ", ")
    }
}
