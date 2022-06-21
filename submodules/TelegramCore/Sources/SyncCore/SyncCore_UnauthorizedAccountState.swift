import Postbox

private enum SentAuthorizationCodeTypeValue: Int32 {
    case otherSession = 0
    case sms = 1
    case call = 2
    case flashCall = 3
    case missedCall = 4
}

public enum SentAuthorizationCodeType: PostboxCoding, Equatable {
    case otherSession(length: Int32)
    case sms(length: Int32)
    case call(length: Int32)
    case flashCall(pattern: String)
    case missedCall(numberPrefix: String, length: Int32)
    
    public init(decoder: PostboxDecoder) {
        switch decoder.decodeInt32ForKey("v", orElse: 0) {
            case SentAuthorizationCodeTypeValue.otherSession.rawValue:
                self = .otherSession(length: decoder.decodeInt32ForKey("l", orElse: 0))
            case SentAuthorizationCodeTypeValue.sms.rawValue:
                self = .sms(length: decoder.decodeInt32ForKey("l", orElse: 0))
            case SentAuthorizationCodeTypeValue.call.rawValue:
                self = .call(length: decoder.decodeInt32ForKey("l", orElse: 0))
            case SentAuthorizationCodeTypeValue.flashCall.rawValue:
                self = .flashCall(pattern: decoder.decodeStringForKey("p", orElse: ""))
            case SentAuthorizationCodeTypeValue.missedCall.rawValue:
                self = .missedCall(numberPrefix: decoder.decodeStringForKey("n", orElse: ""), length: decoder.decodeInt32ForKey("l", orElse: 0))
            default:
                preconditionFailure()
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        switch self {
            case let .otherSession(length):
                encoder.encodeInt32(SentAuthorizationCodeTypeValue.otherSession.rawValue, forKey: "v")
                encoder.encodeInt32(length, forKey: "l")
            case let .sms(length):
                encoder.encodeInt32(SentAuthorizationCodeTypeValue.sms.rawValue, forKey: "v")
                encoder.encodeInt32(length, forKey: "l")
            case let .call(length):
                encoder.encodeInt32(SentAuthorizationCodeTypeValue.call.rawValue, forKey: "v")
                encoder.encodeInt32(length, forKey: "l")
            case let .flashCall(pattern):
                encoder.encodeInt32(SentAuthorizationCodeTypeValue.flashCall.rawValue, forKey: "v")
                encoder.encodeString(pattern, forKey: "p")
            case let .missedCall(numberPrefix, length):
                encoder.encodeInt32(SentAuthorizationCodeTypeValue.missedCall.rawValue, forKey: "v")
                encoder.encodeString(numberPrefix, forKey: "n")
                encoder.encodeInt32(length, forKey: "l")
        }
    }
}

public enum AuthorizationCodeNextType: Int32 {
    case sms = 0
    case call = 1
    case flashCall = 2
    case missedCall = 3
}

private enum UnauthorizedAccountStateContentsValue: Int32 {
    case empty = 0
    case phoneEntry = 1
    case confirmationCodeEntry = 2
    case passwordEntry = 3
    case signUp = 5
    case passwordRecovery = 6
    case awaitingAccountReset = 7
}

public struct UnauthorizedAccountTermsOfService: PostboxCoding, Equatable {
    public let id: String
    public let text: String
    public let entities: [MessageTextEntity]
    public let ageConfirmation: Int32?
    
    public init(id: String, text: String, entities: [MessageTextEntity], ageConfirmation: Int32?) {
        self.id = id
        self.text = text
        self.entities = entities
        self.ageConfirmation = ageConfirmation
    }
    
    public init(decoder: PostboxDecoder) {
        self.id = decoder.decodeStringForKey("id", orElse: "")
        self.text = decoder.decodeStringForKey("text", orElse: "")
        self.entities = (try? decoder.decodeObjectArrayWithCustomDecoderForKey("entities", decoder: { MessageTextEntity(decoder: $0) })) ?? []
        self.ageConfirmation = decoder.decodeOptionalInt32ForKey("ageConfirmation")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(self.id, forKey: "id")
        encoder.encodeString(self.text, forKey: "text")
        encoder.encodeObjectArray(self.entities, forKey: "entities")
        if let ageConfirmation = self.ageConfirmation {
            encoder.encodeInt32(ageConfirmation, forKey: "ageConfirmation")
        } else {
            encoder.encodeNil(forKey: "ageConfirmation")
        }
    }
}

public enum UnauthorizedAccountStateContents: PostboxCoding, Equatable {
    case empty
    case phoneEntry(countryCode: Int32, number: String)
    case confirmationCodeEntry(number: String, type: SentAuthorizationCodeType, hash: String, timeout: Int32?, nextType: AuthorizationCodeNextType?, syncContacts: Bool)
    case passwordEntry(hint: String, number: String?, code: String?, suggestReset: Bool, syncContacts: Bool)
    case passwordRecovery(hint: String, number: String?, code: String?, emailPattern: String, syncContacts: Bool)
    case awaitingAccountReset(protectedUntil: Int32, number: String?, syncContacts: Bool)
    case signUp(number: String, codeHash: String, firstName: String, lastName: String, termsOfService: UnauthorizedAccountTermsOfService?, syncContacts: Bool)
    
    public init(decoder: PostboxDecoder) {
        switch decoder.decodeInt32ForKey("v", orElse: 0) {
            case UnauthorizedAccountStateContentsValue.empty.rawValue:
                self = .empty
            case UnauthorizedAccountStateContentsValue.phoneEntry.rawValue:
                self = .phoneEntry(countryCode: decoder.decodeInt32ForKey("cc", orElse: 1), number: decoder.decodeStringForKey("n", orElse: ""))
            case UnauthorizedAccountStateContentsValue.confirmationCodeEntry.rawValue:
                var nextType: AuthorizationCodeNextType?
                if let value = decoder.decodeOptionalInt32ForKey("nt") {
                    nextType = AuthorizationCodeNextType(rawValue: value)
                }
                self = .confirmationCodeEntry(number: decoder.decodeStringForKey("num", orElse: ""), type: decoder.decodeObjectForKey("t", decoder: { SentAuthorizationCodeType(decoder: $0) }) as! SentAuthorizationCodeType, hash: decoder.decodeStringForKey("h", orElse: ""), timeout: decoder.decodeOptionalInt32ForKey("tm"), nextType: nextType, syncContacts: decoder.decodeInt32ForKey("syncContacts", orElse: 1) != 0)
            case UnauthorizedAccountStateContentsValue.passwordEntry.rawValue:
                self = .passwordEntry(hint: decoder.decodeStringForKey("h", orElse: ""), number: decoder.decodeOptionalStringForKey("n"), code: decoder.decodeOptionalStringForKey("c"), suggestReset: decoder.decodeInt32ForKey("suggestReset", orElse: 0) != 0, syncContacts: decoder.decodeInt32ForKey("syncContacts", orElse: 1) != 0)
            case UnauthorizedAccountStateContentsValue.passwordRecovery.rawValue:
                self = .passwordRecovery(hint: decoder.decodeStringForKey("hint", orElse: ""), number: decoder.decodeOptionalStringForKey("number"), code: decoder.decodeOptionalStringForKey("code"), emailPattern: decoder.decodeStringForKey("emailPattern", orElse: ""), syncContacts: decoder.decodeInt32ForKey("syncContacts", orElse: 1) != 0)
            case UnauthorizedAccountStateContentsValue.awaitingAccountReset.rawValue:
                self = .awaitingAccountReset(protectedUntil: decoder.decodeInt32ForKey("protectedUntil", orElse: 0), number: decoder.decodeOptionalStringForKey("number"), syncContacts: decoder.decodeInt32ForKey("syncContacts", orElse: 1) != 0)
            case UnauthorizedAccountStateContentsValue.signUp.rawValue:
                self = .signUp(number: decoder.decodeStringForKey("n", orElse: ""), codeHash: decoder.decodeStringForKey("h", orElse: ""), firstName: decoder.decodeStringForKey("f", orElse: ""), lastName: decoder.decodeStringForKey("l", orElse: ""), termsOfService: decoder.decodeObjectForKey("tos", decoder: { UnauthorizedAccountTermsOfService(decoder: $0) }) as? UnauthorizedAccountTermsOfService, syncContacts: decoder.decodeInt32ForKey("syncContacts", orElse: 1) != 0)
            default:
                assertionFailure()
                self = .empty
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        switch self {
            case .empty:
                encoder.encodeInt32(UnauthorizedAccountStateContentsValue.empty.rawValue, forKey: "v")
            case let .phoneEntry(countryCode, number):
                encoder.encodeInt32(UnauthorizedAccountStateContentsValue.phoneEntry.rawValue, forKey: "v")
                encoder.encodeInt32(countryCode, forKey: "cc")
                encoder.encodeString(number, forKey: "n")
            case let .confirmationCodeEntry(number, type, hash, timeout, nextType, syncContacts):
                encoder.encodeInt32(UnauthorizedAccountStateContentsValue.confirmationCodeEntry.rawValue, forKey: "v")
                encoder.encodeString(number, forKey: "num")
                encoder.encodeObject(type, forKey: "t")
                encoder.encodeString(hash, forKey: "h")
                if let timeout = timeout {
                    encoder.encodeInt32(timeout, forKey: "tm")
                } else {
                    encoder.encodeNil(forKey: "tm")
                }
                if let nextType = nextType {
                    encoder.encodeInt32(nextType.rawValue, forKey: "nt")
                } else {
                    encoder.encodeNil(forKey: "nt")
                }
                encoder.encodeInt32(syncContacts ? 1 : 0, forKey: "syncContacts")
            case let .passwordEntry(hint, number, code, suggestReset, syncContacts):
                encoder.encodeInt32(UnauthorizedAccountStateContentsValue.passwordEntry.rawValue, forKey: "v")
                encoder.encodeString(hint, forKey: "h")
                if let number = number {
                    encoder.encodeString(number, forKey: "n")
                } else {
                    encoder.encodeNil(forKey: "n")
                }
                if let code = code {
                    encoder.encodeString(code, forKey: "c")
                } else {
                    encoder.encodeNil(forKey: "c")
                }
                encoder.encodeInt32(suggestReset ? 1 : 0, forKey: "suggestReset")
                encoder.encodeInt32(syncContacts ? 1 : 0, forKey: "syncContacts")
            case let .passwordRecovery(hint, number, code, emailPattern, syncContacts):
                encoder.encodeInt32(UnauthorizedAccountStateContentsValue.passwordRecovery.rawValue, forKey: "v")
                encoder.encodeString(hint, forKey: "hint")
                if let number = number {
                    encoder.encodeString(number, forKey: "number")
                } else {
                    encoder.encodeNil(forKey: "number")
                }
                if let code = code {
                    encoder.encodeString(code, forKey: "code")
                } else {
                    encoder.encodeNil(forKey: "code")
                }
                encoder.encodeString(emailPattern, forKey: "emailPattern")
                encoder.encodeInt32(syncContacts ? 1 : 0, forKey: "syncContacts")
            case let .awaitingAccountReset(protectedUntil, number, syncContacts):
                encoder.encodeInt32(UnauthorizedAccountStateContentsValue.awaitingAccountReset.rawValue, forKey: "v")
                encoder.encodeInt32(protectedUntil, forKey: "protectedUntil")
                if let number = number {
                    encoder.encodeString(number, forKey: "number")
                } else {
                    encoder.encodeNil(forKey: "number")
                }
                encoder.encodeInt32(syncContacts ? 1 : 0, forKey: "syncContacts")
            case let .signUp(number, codeHash, firstName, lastName, termsOfService, syncContacts):
                encoder.encodeInt32(UnauthorizedAccountStateContentsValue.signUp.rawValue, forKey: "v")
                encoder.encodeString(number, forKey: "n")
                encoder.encodeString(codeHash, forKey: "h")
                encoder.encodeString(firstName, forKey: "f")
                encoder.encodeString(lastName, forKey: "l")
                if let termsOfService = termsOfService {
                    encoder.encodeObject(termsOfService, forKey: "tos")
                } else {
                    encoder.encodeNil(forKey: "tos")
                }
                encoder.encodeInt32(syncContacts ? 1 : 0, forKey: "syncContacts")
        }
    }
    
    public static func ==(lhs: UnauthorizedAccountStateContents, rhs: UnauthorizedAccountStateContents) -> Bool {
        switch lhs {
            case .empty:
                if case .empty = rhs {
                    return true
                } else {
                    return false
                }
            case let .phoneEntry(countryCode, number):
                if case .phoneEntry(countryCode, number) = rhs {
                    return true
                } else {
                    return false
                }
            case let .confirmationCodeEntry(lhsNumber, lhsType, lhsHash, lhsTimeout, lhsNextType, lhsSyncContacts):
                if case let .confirmationCodeEntry(rhsNumber, rhsType, rhsHash, rhsTimeout, rhsNextType, rhsSyncContacts) = rhs {
                    if lhsNumber != rhsNumber {
                        return false
                    }
                    if lhsType != rhsType {
                        return false
                    }
                    if lhsHash != rhsHash {
                        return false
                    }
                    if lhsTimeout != rhsTimeout {
                        return false
                    }
                    if lhsNextType != rhsNextType {
                        return false
                    }
                    if lhsSyncContacts != rhsSyncContacts {
                        return false
                    }
                    return true
                } else {
                    return false
                }
            case let .passwordEntry(lhsHint, lhsNumber, lhsCode, lhsSuggestReset, lhsSyncContacts):
                if case let .passwordEntry(rhsHint, rhsNumber, rhsCode, rhsSuggestReset, rhsSyncContacts) = rhs {
                    return lhsHint == rhsHint && lhsNumber == rhsNumber && lhsCode == rhsCode && lhsSuggestReset == rhsSuggestReset && lhsSyncContacts == rhsSyncContacts
                } else {
                    return false
                }
            case let .passwordRecovery(lhsHint, lhsNumber, lhsCode, lhsEmailPattern, lhsSyncContacts):
                if case let .passwordRecovery(rhsHint, rhsNumber, rhsCode, rhsEmailPattern, rhsSyncContacts) = rhs {
                    return lhsHint == rhsHint && lhsNumber == rhsNumber && lhsCode == rhsCode && lhsEmailPattern == rhsEmailPattern && lhsSyncContacts == rhsSyncContacts
                } else {
                    return false
                }
            case let .awaitingAccountReset(lhsProtectedUntil, lhsNumber, lhsSyncContacts):
                if case let .awaitingAccountReset(rhsProtectedUntil, rhsNumber, rhsSyncContacts) = rhs {
                    return lhsProtectedUntil == rhsProtectedUntil && lhsNumber == rhsNumber && lhsSyncContacts == rhsSyncContacts
                } else {
                    return false
                }
            case let .signUp(number, codeHash, firstName, lastName, termsOfService, syncContacts):
                if case .signUp(number, codeHash, firstName, lastName, termsOfService, syncContacts) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
}

public final class UnauthorizedAccountState: AccountState {
    public let isTestingEnvironment: Bool
    public let masterDatacenterId: Int32
    public let contents: UnauthorizedAccountStateContents
    
    public init(isTestingEnvironment: Bool, masterDatacenterId: Int32, contents: UnauthorizedAccountStateContents) {
        self.isTestingEnvironment = isTestingEnvironment
        self.masterDatacenterId = masterDatacenterId
        self.contents = contents
    }
    
    public init(decoder: PostboxDecoder) {
        self.isTestingEnvironment = decoder.decodeInt32ForKey("isTestingEnvironment", orElse: 0) != 0
        self.masterDatacenterId = decoder.decodeInt32ForKey("dc", orElse: 0)
        self.contents = decoder.decodeObjectForKey("c", decoder: { UnauthorizedAccountStateContents(decoder: $0) }) as! UnauthorizedAccountStateContents
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.isTestingEnvironment ? 1 : 0, forKey: "isTestingEnvironment")
        encoder.encodeInt32(self.masterDatacenterId, forKey: "dc")
        encoder.encodeObject(self.contents, forKey: "c")
    }
    
    public func equalsTo(_ other: AccountState) -> Bool {
        guard let other = other as? UnauthorizedAccountState else {
            return false
        }
        if self.isTestingEnvironment != other.isTestingEnvironment {
            return false
        }
        if self.masterDatacenterId != other.masterDatacenterId {
            return false
        }
        if self.contents != other.contents {
            return false
        }
        return true
    }
}

