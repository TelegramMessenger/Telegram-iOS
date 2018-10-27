public func dataSizeString(_ size: Int, forceDecimal: Bool = false) -> String {
    return dataSizeString(Int64(size), forceDecimal: forceDecimal)
}

public func dataSizeString(_ size: Int64, forceDecimal: Bool = false) -> String {
    if size >= 1024 * 1024 * 1024 {
        let remainder = (size % (1024 * 1024 * 1024)) / (1024 * 1024 * 102)
        if remainder != 0 || forceDecimal {
            return "\(size / (1024 * 1024 * 1024)),\(remainder) GB"
        } else {
            return "\(size / (1024 * 1024 * 1024)) GB"
        }
    } else if size >= 1024 * 1024 {
        let remainder = (size % (1024 * 1024)) / (1024 * 102)
        if remainder != 0 || forceDecimal {
            return "\(size / (1024 * 1024)),\(remainder) MB"
        } else {
            return "\(size / (1024 * 1024)) MB"
        }
    } else if size >= 1024 {
        let remainder = (size % (1024)) / (102)
        if remainder != 0 || forceDecimal {
            return "\(size / 1024),\(remainder) KB"
        } else {
            return "\(size / 1024) KB"
        }
    } else {
        return "\(size) B"
    }
}
