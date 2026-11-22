import Foundation

// Incuding at least one Objective-C class in a swift file ensures that it doesn't get stripped by the linker
private final class LinkHelperClass: NSObject {
}

public func fileSize(_ path: String, useTotalFileAllocatedSize: Bool = false) -> Int64? {
    /*if useTotalFileAllocatedSize {
        let url = URL(fileURLWithPath: path)
        if let values = (try? url.resourceValues(forKeys: Set([.isRegularFileKey, .fileAllocatedSizeKey]))) {
            if values.isRegularFile ?? false {
                if let fileSize = values.fileAllocatedSize {
                    return Int64(fileSize)
                }
            }
        }
    }*/
    
    var value = stat()
    if lstat(path, &value) == 0 {
        if (value.st_mode & S_IFMT) == S_IFLNK {
            return 0
        }
        
        if useTotalFileAllocatedSize {
            return Int64(value.st_blocks) * Int64(value.st_blksize)
        }
        
        return value.st_size
    } else {
        return nil
    }
}
