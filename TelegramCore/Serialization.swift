import Foundation
#if os(macOS)
    import MtProtoKitMac
#else
    import MtProtoKitDynamic
#endif

public class BoxedMessage: NSObject {
    public let body: Any
    public init(_ body: Any) {
        self.body = body
    }
    
    override public var description: String {
        get {
            return "\(self.body)"
        }
    }
}

public class Serialization: NSObject, MTSerialization {
    public func currentLayer() -> UInt {
        return 68
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
                    case let .config(_, _, _, _, _, dcOptions, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _):
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
