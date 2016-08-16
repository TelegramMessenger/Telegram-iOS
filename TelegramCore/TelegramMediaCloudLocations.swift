import Foundation
import Postbox

public class TelegramCloudFileLocation: TelegramMediaLocation, TelegramCloudMediaLocation {
    let datacenterId: Int
    let volumeId: Int64
    let localId: Int32
    let secret: Int64
    
    public init(datacenterId: Int, volumeId: Int64, localId: Int32, secret: Int64) {
        self.datacenterId = datacenterId
        self.volumeId = volumeId
        self.localId = localId
        self.secret = secret
    }
    
    required public init(decoder: Decoder) {
        self.datacenterId = Int(decoder.decodeInt32ForKey("d"))
        self.volumeId = decoder.decodeInt64ForKey("v")
        self.localId = decoder.decodeInt32ForKey("l")
        self.secret = decoder.decodeInt64ForKey("s")
    }
    
    public func encode(_ encoder: Encoder) {
        encoder.encodeInt32(Int32(self.datacenterId), forKey: "d")
        encoder.encodeInt64(self.volumeId, forKey: "v")
        encoder.encodeInt32(self.localId, forKey: "l")
        encoder.encodeInt64(self.secret, forKey: "s")
    }
    
    public func equalsTo(_ other: TelegramMediaLocation) -> Bool {
        if let other = other as? TelegramCloudFileLocation {
            return self.localId == other.localId && self.datacenterId == other.datacenterId && self.volumeId == other.volumeId && self.secret == other.secret
        }
        return false
    }
    
    public var apiInputLocation: Api.InputFileLocation {
        return Api.InputFileLocation.inputFileLocation(volumeId: self.volumeId, localId: self.localId, secret: self.secret)
    }
    
    public var uniqueId: String {
        return "telegram-cloud-file-\(self.datacenterId)-\(self.volumeId)-\(self.localId)-\(self.secret)"
    }
}

public class TelegramCloudDocumentLocation: TelegramMediaLocation, TelegramCloudMediaLocation {
    let datacenterId: Int
    let fileId: Int64
    let accessHash: Int64
    
    public init(datacenterId: Int, fileId: Int64, accessHash: Int64) {
        self.datacenterId = datacenterId
        self.fileId = fileId
        self.accessHash = accessHash
    }
    
    required public init(decoder: Decoder) {
        self.datacenterId = Int(decoder.decodeInt32ForKey("d"))
        self.fileId = decoder.decodeInt64ForKey("i")
        self.accessHash = decoder.decodeInt64ForKey("h")
    }
    
    public func encode(_ encoder: Encoder) {
        encoder.encodeInt32(Int32(self.datacenterId), forKey: "d")
        encoder.encodeInt64(self.fileId, forKey: "i")
        encoder.encodeInt64(self.accessHash, forKey: "h")
    }
    
    public func equalsTo(_ other: TelegramMediaLocation) -> Bool {
        if let other = other as? TelegramCloudDocumentLocation {
            return self.fileId == other.fileId && self.datacenterId == other.datacenterId && self.accessHash == other.accessHash
        }
        return false
    }
    
    public var apiInputLocation: Api.InputFileLocation {
        return Api.InputFileLocation.inputDocumentFileLocation(id: self.fileId, accessHash: self.accessHash)
    }
    
    public var uniqueId: String {
        return "telegram-cloud-document-\(self.datacenterId)-\(self.fileId)-\(self.accessHash)"
    }
}

public func telegramMediaLocationFromApiLocation(_ location: Api.FileLocation) -> TelegramMediaLocation? {
    switch location {
        case let .fileLocation(dcId, volumeId, localId, secret):
            return TelegramCloudFileLocation(datacenterId: Int(dcId), volumeId: volumeId, localId: localId, secret: secret)
        case .fileLocationUnavailable:
            return nil
    }
}
