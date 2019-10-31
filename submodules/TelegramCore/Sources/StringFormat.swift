public func dataSizeString(_ size: Int, forceDecimal: Bool = false, decimalSeparator: String = ".") -> String {
    return dataSizeString(Int64(size), forceDecimal: forceDecimal, decimalSeparator: decimalSeparator)
}

public func dataSizeString(_ size: Int64, forceDecimal: Bool = false, decimalSeparator: String = ".") -> String {
    if size >= 1024 * 1024 * 1024 {
        let remainder = Int64((Double(size % (1024 * 1024 * 1024)) / (1024 * 1024 * 102.4)).rounded(.down))
        if remainder != 0 || forceDecimal {
            return "\(size / (1024 * 1024 * 1024))\(decimalSeparator)\(remainder) GB"
        } else {
            return "\(size / (1024 * 1024 * 1024)) GB"
        }
    } else if size >= 1024 * 1024 {
        let remainder = Int64((Double(size % (1024 * 1024)) / (1024.0 * 102.4)).rounded(.down))
        if remainder != 0 || forceDecimal {
            return "\(size / (1024 * 1024))\(decimalSeparator)\(remainder) MB"
        } else {
            return "\(size / (1024 * 1024)) MB"
        }
    } else if size >= 1024 {
        let remainder = (size % (1024)) / (102)
        if remainder != 0 || forceDecimal {
            return "\(size / 1024)\(decimalSeparator)\(remainder) KB"
        } else {
            return "\(size / 1024) KB"
        }
    } else {
        return "\(size) B"
    }
}
