import Foundation
#if os(macOS)
    import MtProtoKitMac
#else
    import MtProtoKitDynamic
#endif

private let apiPrefix = "TelegramCore.Api."
private let apiPrefixLength = apiPrefix.count

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
                
                inner: for child in mirror.children {
                    if let label = child.label {
                        result.append(".")
                        result.append(label)
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
                                    if let label = child.label {
                                        result.append(label)
                                        result.append(": ")
                                    }
                                    result.append(recursiveDescription(redact: redact, of: child.value))
                                }
                                if hadChildren {
                                    result.append(")")
                                }
                            default:
                                break
                        }
                    }
                    break
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
            let redact: Bool
            #if DEBUG
                redact = false
            #else
                redact = true
            #endif
            return recursiveDescription(redact: redact, of: self.body)
        }
    }
}

public class Serialization: NSObject, MTSerialization {
    public func currentLayer() -> UInt {
        return 78
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
        return { data -> MTExportedAuthorizationData! in
            if let exported = functionContext.2(Buffer(data: data)) {
                switch exported {
                    case let .exportedAuthorization(id, bytes):
                        return MTExportedAuthorizationData(authorizationBytes: bytes.makeData(), authorizationId: id)
                }
            } else {
                return nil
            }
        }
    }
    
    public func importAuthorization(_ authId: Int32, bytes: Data!) -> Data! {
        return Api.functions.auth.importAuthorization(id: authId, bytes: Buffer(data: bytes)).1.makeData()
    }
    
    public func requestDatacenterAddress(with data: AutoreleasingUnsafeMutablePointer<NSData?>) -> MTRequestDatacenterAddressListParser! {
        let (_, buffer, parse) = Api.functions.help.getConfig()
        data.pointee = buffer.makeData() as NSData
        return { response -> MTDatacenterAddressListData! in
            if let config = parse(Buffer(data: response)) {
                switch config {
                    case let .config(_, _, _, _, _, dcOptions, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _):
                        var addressDict: [NSNumber: [Any]] = [:]
                        for option in dcOptions {
                            switch option {
                                case let .dcOption(flags, id, ipAddress, port):
                                    if addressDict[id as NSNumber] == nil {
                                        addressDict[id as NSNumber] = []
                                    }
                                    let preferForMedia = (flags & (1 << 1)) != 0
                                    let restrictToTcp = (flags & (1 << 2)) != 0
                                    let isCdn = (flags & (1 << 3)) != 0
                                    let preferForProxy = (flags & (1 << 4)) != 0
                                    addressDict[id as NSNumber]!.append(MTDatacenterAddress(ip: ipAddress, port: UInt16(port), preferForMedia: preferForMedia, restrictToTcp: restrictToTcp, cdn: isCdn, preferForProxy: preferForProxy)!)
                                    break
                            }
                        }
                        return MTDatacenterAddressListData(addressList: addressDict)
                }
                
            }
            return nil
        }
    }
}
