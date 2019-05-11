import Foundation
import MtProtoKitDynamic

struct ImageResource {
    let datacenterId: Int
    let volumeId: Int64
    let localId: Int32
    let secret: Int64
    let fileReference: Data?
    
    var resourceId: String {
        return "telegram-cloud-file-\(self.datacenterId)-\(self.volumeId)-\(self.localId)-\(self.secret)"
    }
}

private class Keychain: NSObject, MTKeychain {
    var dict: [String: Data] = [:]
    
    func setObject(_ object: Any!, forKey aKey: String!, group: String!) {
        let data = NSKeyedArchiver.archivedData(withRootObject: object)
        self.dict[group + ":" + aKey] = data
    }
    
    func object(forKey aKey: String!, group: String!) -> Any! {
        if let data = self.dict[group + ":" + aKey] {
            return NSKeyedUnarchiver.unarchiveObject(with: data as Data)
        }
        return nil
    }
    
    func removeObject(forKey aKey: String!, group: String!) {
        self.dict.removeValue(forKey: group + ":" + aKey)
    }
    
    func dropGroup(_ group: String!) {
    }
}

private final class ParsedFile: NSObject {
    let data: Data?
    
    init(data: Data?) {
        self.data = data
        
        super.init()
    }
}

func fetchImageWithAccount(buildConfig: BuildConfig, proxyConnection: AccountProxyConnection?, account: StoredAccountInfo, inputFileLocation: Api.InputFileLocation, datacenterId: Int32, completion: @escaping (Data?) -> Void) -> () -> Void {
    MTLogSetEnabled(true)
    MTLogSetLoggingFunction({ str, args in
        //let string = NSString(format: str! as NSString, args!)
        print("MT: \(str!)")
    })
    
    let serialization = Serialization()
    
    var apiEnvironment = MTApiEnvironment()
    
    apiEnvironment.apiId = buildConfig.apiId
    apiEnvironment.langPack = "ios"
    apiEnvironment.layer = NSNumber(value: Int(serialization.currentLayer()))
    apiEnvironment.disableUpdates = true
    apiEnvironment = apiEnvironment.withUpdatedLangPackCode("en")
    
    if let proxy = proxyConnection {
        apiEnvironment = apiEnvironment.withUpdatedSocksProxySettings(MTSocksProxySettings(ip: proxy.host, port: UInt16(clamping: proxy.port), username: proxy.username, password: proxy.password, secret: proxy.secret))
    }
    
    let context = MTContext(serialization: serialization, apiEnvironment: apiEnvironment, isTestingEnvironment: account.isTestingEnvironment, useTempAuthKeys: false)!
    
    let seedAddressList: [Int: [String]]
    
    if account.isTestingEnvironment {
        seedAddressList = [
            1: ["149.154.175.10"],
            2: ["149.154.167.40"]
        ]
    } else {
        seedAddressList = [
            1: ["149.154.175.50", "2001:b28:f23d:f001::a"],
            2: ["149.154.167.50", "2001:67c:4e8:f002::a"],
            3: ["149.154.175.100", "2001:b28:f23d:f003::a"],
            4: ["149.154.167.91", "2001:67c:4e8:f004::a"],
            5: ["149.154.171.5", "2001:b28:f23f:f005::a"]
        ]
    }
    
    for (id, ips) in seedAddressList {
        context.setSeedAddressSetForDatacenterWithId(id, seedAddressSet: MTDatacenterAddressSet(addressList: ips.map { MTDatacenterAddress(ip: $0, port: 443, preferForMedia: false, restrictToTcp: false, cdn: false, preferForProxy: false, secret: nil) }))
    }
    
    let keychain = Keychain()
    context.keychain = keychain
    
    context.performBatchUpdates({
        for (id, info) in account.datacenters {
            if !info.addressList.isEmpty {
                var addressList: [MTDatacenterAddress] = []
                for address in info.addressList {
                    addressList.append(MTDatacenterAddress(ip: address.host, port: UInt16(clamping: address.port), preferForMedia: address.isMedia, restrictToTcp: false, cdn: false, preferForProxy: false, secret: address.secret))
                }
                context.updateAddressSetForDatacenter(withId: Int(id), addressSet: MTDatacenterAddressSet(addressList: addressList), forceUpdateSchemes: true)
            }
        }
    })
    
    for (id, info) in account.datacenters {
        context.updateAuthInfoForDatacenter(withId: Int(id), authInfo: MTDatacenterAuthInfo(authKey: info.masterKey.data, authKeyId: info.masterKey.id, saltSet: [], authKeyAttributes: [:], mainTempAuthKey: nil, mediaTempAuthKey: nil))
    }
    
    let mtProto = MTProto(context: context, datacenterId: Int(datacenterId), usageCalculationInfo: nil)!
    mtProto.useTempAuthKeys = context.useTempAuthKeys
    mtProto.checkForProxyConnectionIssues = false
    
    let requestService = MTRequestMessageService(context: context)!
    mtProto.add(requestService)
    
    let request = MTRequest()
    
    let buffer = Buffer()
    buffer.appendInt32(-475607115) //upload.getFile
    Api.serializeObject(inputFileLocation, buffer: buffer, boxed: true)
    
    buffer.appendInt32(0)
    buffer.appendInt32(32 * 1024)
    
    request.setPayload(buffer.makeData(), metadata: "getFile", shortMetadata: "getFile", responseParser: { response in
        let reader = BufferReader(Buffer(data: response))
        guard let signature = reader.readInt32() else {
            return ParsedFile(data: nil)
        }
        guard signature == 157948117 else {
            return ParsedFile(data: nil)
        }
        reader.skip(4) //type
        reader.skip(4) //mtime
        guard let bytes = parseBytes(reader) else {
            return ParsedFile(data: nil)
        }
        return ParsedFile(data: bytes.makeData())
    })
    
    request.dependsOnPasswordEntry = false
    request.shouldContinueExecutionWithErrorContext = { errorContext in
        guard let _ = errorContext else {
            return true
        }
        return true
    }
    
    request.completed = { (boxedResponse, timestamp, error) -> () in
        if let _ = error {
            completion(nil)
        } else {
            if let result = boxedResponse as? ParsedFile {
                completion(result.data)
            } else {
                completion(nil)
            }
        }
    }
    
    requestService.add(request)
    mtProto.resume()
    
    let internalId = request.internalId
    return {
        requestService.removeRequest(byInternalId: internalId)
        context.performBatchUpdates({})
        mtProto.stop()
    }
}
