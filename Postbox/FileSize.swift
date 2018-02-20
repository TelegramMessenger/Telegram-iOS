import Foundation

public func fileSize(_ path: String) -> Int? {
    var value = stat()
    if stat(path, &value) == 0 {
        return Int(value.st_size)
    } else {
        return nil
    }
}
