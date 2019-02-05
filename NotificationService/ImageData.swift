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

private final class Buffer {
    var data: UnsafeMutableRawPointer?
    var _size: UInt = 0
    private var capacity: UInt = 0
    private let freeWhenDone: Bool
    
    var size: Int {
        return Int(self._size)
    }
    
    deinit {
        if self.freeWhenDone {
            free(self.data)
        }
    }
    
    init(memory: UnsafeMutableRawPointer?, size: Int, capacity: Int, freeWhenDone: Bool) {
        self.data = memory
        self._size = UInt(size)
        self.capacity = UInt(capacity)
        self.freeWhenDone = freeWhenDone
    }
    
    init() {
        self.data = nil
        self._size = 0
        self.capacity = 0
        self.freeWhenDone = true
    }
    
    convenience init(data: Data?) {
        self.init()
        
        if let data = data {
            data.withUnsafeBytes { bytes in
                self.appendBytes(bytes, length: UInt(data.count))
            }
        }
    }

    func makeData() -> Data {
        return self.withUnsafeMutablePointer { pointer, size -> Data in
            if let pointer = pointer {
                return Data(bytes: pointer.assumingMemoryBound(to: UInt8.self), count: Int(size))
            } else {
                return Data()
            }
        }
    }
    
    var description: String {
        get {
            var string = ""
            if let data = self.data {
                var i: UInt = 0
                let bytes = data.assumingMemoryBound(to: UInt8.self)
                while i < _size && i < 8 {
                    string += String(format: "%02x", Int(bytes.advanced(by: Int(i)).pointee))
                    i += 1
                }
                if i < _size {
                    string += "...\(_size)b"
                }
            } else {
                string += "<null>"
            }
            return string
        }
    }
    
    func appendBytes(_ bytes: UnsafeRawPointer, length: UInt) {
        if self.capacity < self._size + length {
            self.capacity = self._size + length + 128
            if self.data == nil {
                self.data = malloc(Int(self.capacity))!
            }
            else {
                self.data = realloc(self.data, Int(self.capacity))!
            }
        }
        
        memcpy(self.data?.advanced(by: Int(self._size)), bytes, Int(length))
        self._size += length
    }
    
    func appendBuffer(_ buffer: Buffer) {
        if self.capacity < self._size + buffer._size {
            self.capacity = self._size + buffer._size + 128
            if self.data == nil {
                self.data = malloc(Int(self.capacity))!
            }
            else {
                self.data = realloc(self.data, Int(self.capacity))!
            }
        }
        
        memcpy(self.data?.advanced(by: Int(self._size)), buffer.data, Int(buffer._size))
    }
    
    func appendInt32(_ value: Int32) {
        var v = value
        self.appendBytes(&v, length: 4)
    }
    
    func appendInt64(_ value: Int64) {
        var v = value
        self.appendBytes(&v, length: 8)
    }
    
    func appendDouble(_ value: Double) {
        var v = value
        self.appendBytes(&v, length: 8)
    }
    
    func withUnsafeMutablePointer<R>(_ f: (UnsafeMutableRawPointer?, UInt) -> R) -> R {
        return f(self.data, self._size)
    }
}

private class BufferReader {
    private let buffer: Buffer
    private(set) var offset: UInt = 0
    
    init(_ buffer: Buffer) {
        self.buffer = buffer
    }
    
    func reset() {
        self.offset = 0
    }
    
    func skip(_ count: Int) {
        self.offset = min(self.buffer._size, self.offset + UInt(count))
    }
    
    func readInt32() -> Int32? {
        if self.offset + 4 <= self.buffer._size {
            let value: Int32 = buffer.data!.advanced(by: Int(self.offset)).assumingMemoryBound(to: Int32.self).pointee
            self.offset += 4
            return value
        }
        return nil
    }
    
    func readInt64() -> Int64? {
        if self.offset + 8 <= self.buffer._size {
            let value: Int64 = buffer.data!.advanced(by: Int(self.offset)).assumingMemoryBound(to: Int64.self).pointee
            self.offset += 8
            return value
        }
        return nil
    }
    
    func readDouble() -> Double? {
        if self.offset + 8 <= self.buffer._size {
            let value: Double = buffer.data!.advanced(by: Int(self.offset)).assumingMemoryBound(to: Double.self).pointee
            self.offset += 8
            return value
        }
        return nil
    }
    
    func readBytesAsInt32(_ count: Int) -> Int32? {
        if count == 0 {
            return 0
        }
        else if count > 0 && count <= 4 || self.offset + UInt(count) <= self.buffer._size {
            var value: Int32 = 0
            memcpy(&value, self.buffer.data?.advanced(by: Int(self.offset)), count)
            self.offset += UInt(count)
            return value
        }
        return nil
    }
    
    func readBuffer(_ count: Int) -> Buffer? {
        if count >= 0 && self.offset + UInt(count) <= self.buffer._size {
            let buffer = Buffer()
            buffer.appendBytes((self.buffer.data?.advanced(by: Int(self.offset)))!, length: UInt(count))
            self.offset += UInt(count)
            return buffer
        }
        return nil
    }
}

private func serializeBytes(_ value: Buffer, buffer: Buffer, boxed: Bool) {
    if boxed {
        buffer.appendInt32(-1255641564)
    }
    
    var length: Int32 = Int32(value.size)
    var padding: Int32 = 0
    if (length >= 254)
    {
        var tmp: UInt8 = 254
        buffer.appendBytes(&tmp, length: 1)
        buffer.appendBytes(&length, length: 3)
        padding = (((length % 4) == 0 ? length : (length + 4 - (length % 4)))) - length;
    }
    else
    {
        buffer.appendBytes(&length, length: 1)
        
        let e1 = (((length + 1) % 4) == 0 ? (length + 1) : ((length + 1) + 4 - ((length + 1) % 4)))
        padding = (e1) - (length + 1)
    }
    
    if value.size != 0 {
        buffer.appendBytes(value.data!, length: UInt(length))
    }
    
    var i: Int32 = 0
    var tmp: UInt8 = 0
    while i < padding {
        buffer.appendBytes(&tmp, length: 1)
        i += 1
    }
}

private func roundUp(_ numToRound: Int, multiple: Int) -> Int {
    if multiple == 0 {
        return numToRound
    }
    
    let remainder = numToRound % multiple
    if remainder == 0 {
        return numToRound
    }
    
    return numToRound + multiple - remainder
}

private func parseBytes(_ reader: BufferReader) -> Buffer? {
    if let tmp = reader.readBytesAsInt32(1) {
        var paddingBytes: Int = 0
        var length: Int = 0
        if tmp == 254 {
            if let len = reader.readBytesAsInt32(3) {
                length = Int(len)
                paddingBytes = roundUp(length, multiple: 4) - length
            }
            else {
                return nil
            }
        }
        else {
            length = Int(tmp)
            paddingBytes = roundUp(length + 1, multiple: 4) - (length + 1)
        }
        
        let buffer = reader.readBuffer(length)
        reader.skip(paddingBytes)
        return buffer
    }
    return nil
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

func fetchImageWithAccount(account: AccountData, resource: ImageResource, completion: @escaping (Data?) -> Void) -> () -> Void {
    MTLogSetEnabled(true)
    MTLogSetLoggingFunction({ str, args in
        //let string = NSString(format: str! as NSString, args!)
        print("MT: \(str!)")
    })
    
    let serialization = Serialization()
    
    var apiEnvironment = MTApiEnvironment()
    
    apiEnvironment.apiId = BuildConfig.shared().apiId
    apiEnvironment.langPack = "ios"
    apiEnvironment.layer = NSNumber(value: Int(serialization.currentLayer()))
    apiEnvironment.disableUpdates = true
    apiEnvironment = apiEnvironment.withUpdatedLangPackCode("en")
    
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
    
    for (id, info) in account.datacenters {
        context.updateAuthInfoForDatacenter(withId: Int(id), authInfo: MTDatacenterAuthInfo(authKey: info.masterKey.data, authKeyId: info.masterKey.id, saltSet: [], authKeyAttributes: [:], mainTempAuthKey: nil, mediaTempAuthKey: nil))
    }
    
    let mtProto = MTProto(context: context, datacenterId: resource.datacenterId, usageCalculationInfo: nil)!
    mtProto.useTempAuthKeys = context.useTempAuthKeys
    mtProto.checkForProxyConnectionIssues = false
    
    let requestService = MTRequestMessageService(context: context)!
    mtProto.add(requestService)
    
    let request = MTRequest()
    
    let buffer = Buffer()
    buffer.appendInt32(-475607115) //upload.getFile
    
    buffer.appendInt32(-539317279) //InputFileLocation.inputFileLocation
    buffer.appendInt64(resource.volumeId)
    buffer.appendInt32(resource.localId)
    buffer.appendInt64(resource.secret)
    
    serializeBytes(Buffer(data: resource.fileReference), buffer: buffer, boxed: false)
    
    buffer.appendInt32(0)
    buffer.appendInt32(32 * 1024)
    
    request.setPayload(buffer.makeData(), metadata: "getFile", responseParser: { response in
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
