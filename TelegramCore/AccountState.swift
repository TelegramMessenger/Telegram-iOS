import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif


private enum SentAuthorizationCodeTypeValue: Int32 {
    case otherSession = 0
    case sms = 1
    case call = 2
    case flashCall = 3
}

public enum SentAuthorizationCodeType: Coding, Equatable {
    case otherSession(length: Int32)
    case sms(length: Int32)
    case call(length: Int32)
    case flashCall(pattern: String)
    
    public init(decoder: Decoder) {
        switch decoder.decodeInt32ForKey("v", orElse: 0) {
            case SentAuthorizationCodeTypeValue.otherSession.rawValue:
                self = .otherSession(length: decoder.decodeInt32ForKey("l", orElse: 0))
            case SentAuthorizationCodeTypeValue.sms.rawValue:
                self = .sms(length: decoder.decodeInt32ForKey("l", orElse: 0))
            case SentAuthorizationCodeTypeValue.call.rawValue:
                self = .call(length: decoder.decodeInt32ForKey("l", orElse: 0))
            case SentAuthorizationCodeTypeValue.flashCall.rawValue:
                self = .flashCall(pattern: decoder.decodeStringForKey("p", orElse: ""))
            default:
                preconditionFailure()
        }
    }
    
    public func encode(_ encoder: Encoder) {
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
        }
    }
    
    public static func ==(lhs: SentAuthorizationCodeType, rhs: SentAuthorizationCodeType) -> Bool {
        switch lhs {
            case let .otherSession(length):
                if case .otherSession(length) = rhs {
                    return true
                } else {
                    return false
                }
            case let .sms(length):
                if case .sms(length) = rhs {
                    return true
                } else {
                    return false
                }
            case let .call(length):
                if case .call(length) = rhs {
                    return true
                } else {
                    return false
                }
            case let .flashCall(pattern):
                if case .flashCall(pattern) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
}

public enum AuthorizationCodeNextType: Int32 {
    case sms = 0
    case call = 1
    case flashCall = 2
}

private enum UnauthorizedAccountStateContentsValue: Int32 {
    case empty = 0
    case phoneEntry = 1
    case confirmationCodeEntry = 2
    case passwordEntry = 3
    case signUp = 5
}

public enum UnauthorizedAccountStateContents: Coding, Equatable {
    case empty
    case phoneEntry(countryCode: Int32, number: String)
    case confirmationCodeEntry(number: String, type: SentAuthorizationCodeType, hash: String, timeout: Int32?, nextType: AuthorizationCodeNextType?)
    case passwordEntry(hint: String, number: String?, code: String?)
    case signUp(number: String, codeHash: String, code: String, firstName: String, lastName: String)
    
    public init(decoder: Decoder) {
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
                self = .confirmationCodeEntry(number: decoder.decodeStringForKey("num", orElse: ""), type: decoder.decodeObjectForKey("t", decoder: { SentAuthorizationCodeType(decoder: $0) }) as! SentAuthorizationCodeType, hash: decoder.decodeStringForKey("h", orElse: ""), timeout: decoder.decodeOptionalInt32ForKey("tm"), nextType: nextType)
            case UnauthorizedAccountStateContentsValue.passwordEntry.rawValue:
                self = .passwordEntry(hint: decoder.decodeStringForKey("h", orElse: ""), number: decoder.decodeOptionalStringForKey("n"), code: decoder.decodeOptionalStringForKey("c"))
            case UnauthorizedAccountStateContentsValue.signUp.rawValue:
                self = .signUp(number: decoder.decodeStringForKey("n", orElse: ""), codeHash: decoder.decodeStringForKey("h", orElse: ""), code: decoder.decodeStringForKey("c", orElse: ""), firstName: decoder.decodeStringForKey("f", orElse: ""), lastName: decoder.decodeStringForKey("l", orElse: ""))
            default:
                assertionFailure()
                self = .empty
        }
    }
    
    public func encode(_ encoder: Encoder) {
        switch self {
            case .empty:
                encoder.encodeInt32(UnauthorizedAccountStateContentsValue.empty.rawValue, forKey: "v")
            case let .phoneEntry(countryCode, number):
                encoder.encodeInt32(UnauthorizedAccountStateContentsValue.phoneEntry.rawValue, forKey: "v")
                encoder.encodeInt32(countryCode, forKey: "cc")
                encoder.encodeString(number, forKey: "n")
            case let .confirmationCodeEntry(number, type, hash, timeout, nextType):
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
            case let .passwordEntry(hint, number, code):
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
            case let .signUp(number, codeHash, code, firstName, lastName):
                encoder.encodeInt32(UnauthorizedAccountStateContentsValue.signUp.rawValue, forKey: "v")
                encoder.encodeString(number, forKey: "n")
                encoder.encodeString(codeHash, forKey: "h")
                encoder.encodeString(code, forKey: "c")
                encoder.encodeString(firstName, forKey: "f")
                encoder.encodeString(lastName, forKey: "l")
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
            case let .confirmationCodeEntry(lhsNumber, lhsType, lhsHash, lhsTimeout, lhsNextType):
                if case let .confirmationCodeEntry(rhsNumber, rhsType, rhsHash, rhsTimeout, rhsNextType) = rhs {
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
                    return true
                } else {
                    return false
                }
            case let .passwordEntry(lhsHint, lhsNumber, lhsCode):
                if case let .passwordEntry(rhsHint, rhsNumber, rhsCode) = rhs {
                    return lhsHint == rhsHint && lhsNumber == rhsNumber && lhsCode == rhsCode
                } else {
                    return false
                }
            case let .signUp(number, codeHash, code, firstName, lastName):
                if case .signUp(number, codeHash, code, firstName, lastName) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
}

public final class UnauthorizedAccountState: AccountState {
    public let masterDatacenterId: Int32
    public let contents: UnauthorizedAccountStateContents
    
    public init(masterDatacenterId: Int32, contents: UnauthorizedAccountStateContents) {
        self.masterDatacenterId = masterDatacenterId
        self.contents = contents
    }
    
    public init(decoder: Decoder) {
        self.masterDatacenterId = decoder.decodeInt32ForKey("dc", orElse: 0)
        self.contents = decoder.decodeObjectForKey("c", decoder: { UnauthorizedAccountStateContents(decoder: $0) }) as! UnauthorizedAccountStateContents
    }
    
    public func encode(_ encoder: Encoder) {
        encoder.encodeInt32(self.masterDatacenterId, forKey: "dc")
        encoder.encodeObject(self.contents, forKey: "c")
    }
    
    public func equalsTo(_ other: AccountState) -> Bool {
        guard let other = other as? UnauthorizedAccountState else {
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

public extension SentAuthorizationCodeType {
    init(apiType: Api.auth.SentCodeType) {
        switch apiType {
            case let .sentCodeTypeApp(length):
                self = .otherSession(length: length)
            case let .sentCodeTypeSms(length):
                self = .sms(length: length)
            case let .sentCodeTypeCall(length):
                self = .call(length: length)
            case let .sentCodeTypeFlashCall(pattern):
                self = .flashCall(pattern: pattern)
        }
    }
}

public extension AuthorizationCodeNextType {
    init(apiType: Api.auth.CodeType) {
        switch apiType {
            case .codeTypeSms:
                self = .sms
            case .codeTypeCall:
                self = .call
            case .codeTypeFlashCall:
                self = .flashCall
        }
    }
}
