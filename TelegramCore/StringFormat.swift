
public func dataSizeString(_ size: Int) -> String {
    if size >= 1024 * 1024 {
        return "\(size / (1024 * 1024)) MB"
    } else if size >= 1024 {
        return "\(size / 1024) KB"
    } else {
        return "\(size) B"
    }
}
