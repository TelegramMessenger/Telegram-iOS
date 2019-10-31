import Foundation

func paddedSecureIdData(_ data: Data) -> Data {
    var paddingCount = Int(47 + arc4random_uniform(255 - 47))
    paddingCount -= ((data.count + paddingCount) % 16)
    var result = Data(count: paddingCount + data.count)
    result.withUnsafeMutableBytes { (bytes: UnsafeMutablePointer<UInt8>) -> Void in
        bytes.advanced(by: 0).pointee = UInt8(paddingCount)
        arc4random_buf(bytes.advanced(by: 1), paddingCount - 1)
        data.withUnsafeBytes { (source: UnsafePointer<UInt8>) -> Void in
            memcpy(bytes.advanced(by: paddingCount), source, data.count)
        }
    }
    return result
}

func unpaddedSecureIdData(_ data: Data) -> Data? {
    var paddingCount: UInt8 = 0
    data.copyBytes(to: &paddingCount, count: 1)
    
    if paddingCount < 0 || paddingCount > data.count {
        return nil
    }
    
    return data.subdata(in: Int(paddingCount) ..< data.count)
}
