import Foundation
import MurMurHash32

public enum HashFunctions {
    public static func murMurHash32(_ s: String) -> Int32 {
        return murMurHashString32(s)
    }
    
    public static func murMurHash32(_ d: Data) -> Int32 {
        return murMurHash32Data(d)
    }
}
