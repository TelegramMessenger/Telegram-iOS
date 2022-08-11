import Contacts

public struct AppleContactDto {
    public let id: String
    public let givenName: String
    public let familyName: String
    public let phoneNumbers: [String]
    public let displayName: String
}

public enum AppleContactsError: Error {
    case accessNotGranted
    case underlying(Error)
}

public class AppleContactsProvider {
    
    //  MARK: - Dependencies
    
    private let store: CNContactStore
    private let queue: DispatchQueue
    
    //  MARK: - Lifecycle
    
    public init(store: CNContactStore = .init(), queue: DispatchQueue = .init(label: "AppleContactsProvider", qos: .userInitiated, attributes: .concurrent)) {
        self.store = store
        self.queue = queue
    }
    
    //  MARK: - Public Functions

    public func fetchContacts(completion: ((Result<[AppleContactDto], AppleContactsError>) -> ())?) {
        queue.async {
            self.store.requestAccess(for: .contacts) { [weak self] granted, requestAccessError in
                guard let self = self else { return }
                
                guard granted else {
                    completion?(.failure(.accessNotGranted))
                    return
                }
                
                if let error = requestAccessError {
                    completion?(.failure(.underlying(error)))
                    return
                }
                
                let keysToFetch: [CNKeyDescriptor] = (
                    [CNContactIdentifierKey, CNContactGivenNameKey, CNContactFamilyNameKey, CNContactPhoneNumbersKey] as [CNKeyDescriptor]
                ) + [CNContactFormatter.descriptorForRequiredKeys(for: .fullName)]
                let request: CNContactFetchRequest = .init(keysToFetch: keysToFetch)
                request.sortOrder = .familyName
                
                var result: [AppleContactDto] = []
                do {
                    try self.store.enumerateContacts(with: request) { contact, _ in
                        result.append(self.mapCnContact(contact))
                    }
                    completion?(.success(result))
                } catch {
                    completion?(.failure(.underlying(error)))
                }
            }
        }
        
    }
    
    //  MARK: - Private Functions

    private func mapCnContact(_ contact: CNContact) -> AppleContactDto {
        let phoneNumbers = contact.phoneNumbers.map({ $0.value.stringValue })
        let displayName = CNContactFormatter.string(from: contact, style: .fullName) ?? ""
        return AppleContactDto(id: contact.identifier, givenName: contact.givenName, familyName: contact.familyName, phoneNumbers: phoneNumbers, displayName: displayName)
    }
}
