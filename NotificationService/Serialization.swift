import Foundation
import MtProtoKitDynamic

public class BoxedMessage: NSObject {
    public let body: Any
    public init(_ body: Any) {
        self.body = body
    }
}

public class Serialization: NSObject, MTSerialization {
    public func currentLayer() -> UInt {
        return 97
    }
    
    public func parseMessage(_ data: Data!) -> Any! {
        return nil
    }
    
    public func exportAuthorization(_ datacenterId: Int32, data: AutoreleasingUnsafeMutablePointer<NSData?>) -> MTExportAuthorizationResponseParser!
    {
        return { data -> MTExportedAuthorizationData? in
            return nil
        }
    }
    
    public func importAuthorization(_ authId: Int32, bytes: Data!) -> Data! {
        return Data()
    }
    
    public func requestDatacenterAddress(with data: AutoreleasingUnsafeMutablePointer<NSData?>) -> MTRequestDatacenterAddressListParser! {
        return { response -> MTDatacenterAddressListData? in
            return nil
        }
    }
    
    public func requestNoop(_ data: AutoreleasingUnsafeMutablePointer<NSData?>!) -> MTRequestNoopParser! {
        return { response -> AnyObject? in
            return nil
        }
    }
}
