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
        return 66
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
    
    public func requestDatacenterAddressList(_ datacenterId: Int32, data: AutoreleasingUnsafeMutablePointer<NSData?>) -> MTRequestDatacenterAddressListParser! {
        let (_, buffer, parse) = Api.functions.help.getConfig()
        data.pointee = buffer.makeData() as NSData
        return { response -> MTDatacenterAddressListData! in
            if let config = parse(Buffer(data: response)) {
                switch config {
                    //config flags:# date:int expires:int test_mode:Bool this_dc:int dc_options:Vector<DcOption> chat_size_max:int megagroup_size_max:int forwarded_count_max:int online_update_period_ms:int offline_blur_timeout_ms:int offline_idle_timeout_ms:int online_cloud_timeout_ms:int notify_cloud_delay_ms:int notify_default_delay_ms:int chat_big_size:int push_chat_period_ms:int push_chat_limit:int saved_gifs_limit:int edit_time_limit:int rating_e_decay:int stickers_recent_limit:int tmp_sessions:flags.0?int phonecalls_enabled:flags.1?true disabled_features:Vector<DisabledFeature> = Config;
                    case let .config(_, _, _, _, _, dcOptions, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _):
                        var addressList = [MTDatacenterAddress]()
                        for option in dcOptions {
                            switch option {
                                case let .dcOption(flags, id, ipAddress, port) where id == datacenterId:
                                    let preferForMedia = (flags & (1 << 1)) != 0
                                    addressList.append(MTDatacenterAddress(ip: ipAddress, port: UInt16(port), preferForMedia: preferForMedia, restrictToTcp: false))
                                    break
                                default:
                                    break
                            }
                        }
                        return MTDatacenterAddressListData(addressList: addressList)
                }
                
            }
            return nil
        }
    }
}
