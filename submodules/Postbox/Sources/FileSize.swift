import Foundation

public func fileSize(_ path: String, useTotalFileAllocatedSize: Bool = false) -> Int64? {
    if useTotalFileAllocatedSize {
        let url = URL(fileURLWithPath: path)
        if let values = (try? url.resourceValues(forKeys: Set([.isRegularFileKey, .totalFileAllocatedSizeKey]))) {
            if values.isRegularFile ?? false {
                if let fileSize = values.totalFileAllocatedSize {
                    return Int64(fileSize)
                }
            }
        }
    }
    
    var value = stat()
    if stat(path, &value) == 0 {
        return value.st_size
    } else {
        return nil
    }
}
