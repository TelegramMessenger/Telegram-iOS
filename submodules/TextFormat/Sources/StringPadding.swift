import Foundation

public extension String {
    func rightJustified(width: Int, pad: String = " ", truncate: Bool = false) -> String {
        guard width > count else {
            return truncate ? String(suffix(width)) : self
        }
        return String(repeating: pad, count: width - count) + self
    }
    
    func leftJustified(width: Int, pad: String = " ", truncate: Bool = false) -> String {
        guard width > count else {
            return truncate ? String(prefix(width)) : self
        }
        return self + String(repeating: pad, count: width - count)
    }
}
