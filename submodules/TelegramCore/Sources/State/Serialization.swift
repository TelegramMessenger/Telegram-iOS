import Foundation
import MtProtoKit
import TelegramApi

private let apiPrefix: String = {
    let type = _typeName(Api.User.self)
    let userType = "User"
    if type.hasSuffix(userType) {
        return String(type[type.startIndex ..< type.index(type.endIndex, offsetBy: -userType.count)])
    } else {
        return "TelegramApi.Api."
    }
}()

private let apiPrefixLength = apiPrefix.count

private let redactChildrenOfType: [String: Set<String>] = [
    "Message.message": Set(["message"]),
    "Updates.updateShortMessage": Set(["message"]),
    "Updates.updateShortChatMessage": Set(["message"]),
    "BotInlineMessage.botInlineMessageText": Set(["message"]),
    "DraftMessage.draftMessage": Set(["message"]),
    "InputSingleMedia.inputSingleMedia": Set(["message"]),
    "InputContact.inputPhoneContact": Set(["phone"]),
    "User.user": Set(["phone"]),
    "Update.updateUserPhone": Set(["phone"])
]

private let redactFunctionParameters: [String: Set<String>] = [
    "messages.sendMessage": Set(["message"]),
    "messages.sendMedia": Set(["message"]),
    "messages.saveDraft": Set(["message"]),
    "messages.getWebPagePreview": Set(["message"])
]

func apiFunctionDescription(of desc: FunctionDescription) -> String {
    var result = desc.name
    if !desc.parameters.isEmpty {
        result.append("(")
        var first = true
        for param in desc.parameters {
            if first {
                first = false
            } else {
                result.append(", ")
            }
            result.append(param.0)
            result.append(": ")
            
            var redactParam = false
            if let redactParams = redactFunctionParameters[desc.name] {
                redactParam = redactParams.contains(param.0)
            }
            
            if redactParam, Logger.shared.redactSensitiveData {
                result.append("[[redacted]]")
            } else {
                result.append(recursiveDescription(redact: Logger.shared.redactSensitiveData, of: param.1))
            }
        }
        result.append(")")
    }
    return result
}

func apiShortFunctionDescription(of desc: FunctionDescription) -> String {
    return desc.name
}

private func recursiveDescription(redact: Bool, of value: Any) -> String {
    let mirror = Mirror(reflecting: value)
    var result = ""
    if let displayStyle = mirror.displayStyle {
        switch displayStyle {
            case .enum:
                result.append(_typeName(mirror.subjectType))
                if result.hasPrefix(apiPrefix) {
                    result.removeSubrange(result.startIndex ..< result.index(result.startIndex, offsetBy: apiPrefixLength))
                }
                
                if let value = value as? TypeConstructorDescription {
                    let (consName, fields) = value.descriptionFields()
                    result.append(".")
                    result.append(consName)
                    
                    let redactChildren: Set<String>?
                    if redact {
                        redactChildren = redactChildrenOfType[result]
                    } else {
                        redactChildren = nil
                    }
                    
                    if !fields.isEmpty {
                        result.append("(")
                        var first = true
                        for (fieldName, fieldValue) in fields {
                            if first {
                                first = false
                            } else {
                                result.append(", ")
                            }
                            var redactValue: Bool = false
                            if let redactChildren = redactChildren, redactChildren.contains("*") {
                                redactValue = true
                            }
                            
                            result.append(fieldName)
                            result.append(": ")
                            if let redactChildren = redactChildren, redactChildren.contains(fieldName) {
                                redactValue = true
                            }
                            
                            if redactValue {
                                result.append("[[redacted]]")
                            } else {
                                result.append(recursiveDescription(redact: redact, of: fieldValue))
                            }
                        }
                        result.append(")")
                    }
                } else {
                    inner: for child in mirror.children {
                        if let label = child.label {
                            result.append(".")
                            result.append(label)
                        }
                        let redactChildren: Set<String>?
                        if redact {
                            redactChildren = redactChildrenOfType[result]
                        } else {
                            redactChildren = nil
                        }
                        let valueMirror = Mirror(reflecting: child.value)
                        if let displayStyle = valueMirror.displayStyle {
                            switch displayStyle {
                            case .tuple:
                                var hadChildren = false
                                for child in valueMirror.children {
                                    if !hadChildren {
                                        hadChildren = true
                                        result.append("(")
                                    } else {
                                        result.append(", ")
                                    }
                                    var redactValue: Bool = false
                                    if let redactChildren = redactChildren, redactChildren.contains("*") {
                                        redactValue = true
                                    }
                                    if let label = child.label {
                                        result.append(label)
                                        result.append(": ")
                                        if let redactChildren = redactChildren, redactChildren.contains(label) {
                                            redactValue = true
                                        }
                                    }
                                    
                                    if redactValue {
                                        result.append("[[redacted]]")
                                    } else {
                                        result.append(recursiveDescription(redact: redact, of: child.value))
                                    }
                                }
                                if hadChildren {
                                    result.append(")")
                                }
                            default:
                                break
                            }
                        } else {
                            result.append("(")
                            result.append(String(describing: child.value))
                            result.append(")")
                        }
                        break
                    }
                }
            case .collection:
                result.append("[")
                var isFirst = true
                for child in mirror.children {
                    if isFirst {
                        isFirst = false
                    } else {
                        result.append(", ")
                    }
                    result.append(recursiveDescription(redact: redact, of: child.value))
                }
                result.append("]")
            default:
                result.append("\(value)")
        }
    } else {
        result.append("\(value)")
    }
    return result
}

public class BoxedMessage: NSObject {
    public let body: Any
    public init(_ body: Any) {
        self.body = body
    }
    
    override public var description: String {
        get {
            return recursiveDescription(redact: Logger.shared.redactSensitiveData, of: self.body)
        }
    }
}

public class Serialization: NSObject, MTSerialization {
    public func currentLayer() -> UInt {
        return 148
    }
    
    public func parseMessage(_ data: Data!) -> Any! {
        if let body = Api.parse(Buffer(data: data)) {
            return BoxedMessage(body)
        }
        return nil
    }
    
    public func exportAuthorization(_ datacenterId: Int32, data: AutoreleasingUnsafeMutablePointer<NSData?>) -> MTExportAuthorizationResponseParser!
    {
        let functionContext = Api.functions.auth.exportAuthorization(dcId: datacenterId)
        data.pointee = functionContext.1.makeData() as NSData
        return { data -> MTExportedAuthorizationData? in
            if let exported = functionContext.2.parse(Buffer(data: data)) {
                switch exported {
                    case let .exportedAuthorization(id, bytes):
                        return MTExportedAuthorizationData(authorizationBytes: bytes.makeData(), authorizationId: id)
                }
            } else {
                return nil
            }
        }
    }
    
    public func importAuthorization(_ authId: Int64, bytes: Data!) -> Data! {
        return Api.functions.auth.importAuthorization(id: authId, bytes: Buffer(data: bytes)).1.makeData()
    }
    
    public func requestDatacenterAddress(with data: AutoreleasingUnsafeMutablePointer<NSData?>) -> MTRequestDatacenterAddressListParser! {        
        let (_, buffer, parser) = Api.functions.help.getConfig()
        data.pointee = buffer.makeData() as NSData
        return { response -> MTDatacenterAddressListData? in
            if let config = parser.parse(Buffer(data: response)) {
                switch config {
                    case let .config(_, _, _, _, _, dcOptions, _, _, _, _, _, _,_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _):
                        var addressDict: [NSNumber: [Any]] = [:]
                        for option in dcOptions {
                            switch option {
                                case let .dcOption(flags, id, ipAddress, port, secret):
                                    if addressDict[id as NSNumber] == nil {
                                        addressDict[id as NSNumber] = []
                                    }
                                    let preferForMedia = (flags & (1 << 1)) != 0
                                    let restrictToTcp = (flags & (1 << 2)) != 0
                                    let isCdn = (flags & (1 << 3)) != 0
                                    let preferForProxy = (flags & (1 << 4)) != 0
                                    addressDict[id as NSNumber]!.append(MTDatacenterAddress(ip: ipAddress, port: UInt16(port), preferForMedia: preferForMedia, restrictToTcp: restrictToTcp, cdn: isCdn, preferForProxy: preferForProxy, secret: secret?.makeData()))
                                    break
                            }
                        }
                        return MTDatacenterAddressListData(addressList: addressDict)
                }
                
            }
            return nil
        }
    }
    
    public func requestNoop(_ data: AutoreleasingUnsafeMutablePointer<NSData?>!) -> MTRequestNoopParser! {
        let (_, buffer, parser) = Api.functions.help.test()
        data.pointee = buffer.makeData() as NSData
        
        return { response -> AnyObject? in
            if let _ = parser.parse(Buffer(data: response)) {
                return true as NSNumber
            } else {
                return nil
            }
        }
    }
}
