import Foundation

public protocol DeferredString {
    var data: NSData { get }
    var string: String { get }
}

private final class DeferredStringImpl {
    var string: String!
    var data: NSData!
    var lock: OSSpinLock = 0
    
    init(string: String!, data: NSData!) {
        self.string = string
        self.data = data
    }
}

public final class DeferredStringValue: DeferredString, CustomStringConvertible, StringLiteralConvertible {
    private var impl: DeferredStringImpl
    
    public typealias ExtendedGraphemeClusterLiteralType = StringLiteralType
    public typealias UnicodeScalarLiteralType = StringLiteralType
    
    public init(unicodeScalarLiteral value: UnicodeScalarLiteralType) {
        self.impl = DeferredStringImpl(string: "\(value)", data: nil)
    }
    
    public init(extendedGraphemeClusterLiteral value: ExtendedGraphemeClusterLiteralType) {
        self.impl = DeferredStringImpl(string: value, data: nil)
    }
    
    public init(stringLiteral value: StringLiteralType) {
        self.impl = DeferredStringImpl(string: value, data: nil)
    }
    
    public init(_ string: String) {
        self.impl = DeferredStringImpl(string: string, data: nil)
    }
    
    public init(_ data: NSData) {
        self.impl = DeferredStringImpl(string: nil, data: data)
    }
    
    public var description: String {
        return self.string
    }
    
    public var data: NSData {
        if isUniquelyReferencedNonObjC(&self.impl) {
            let value: NSData
            
            if impl.data != nil {
                value = impl.data
            } else if impl.string != nil {
                value = impl.string.dataUsingEncoding(NSUTF8StringEncoding) ?? NSData()
                impl.data = value
            } else {
                value = NSData()
            }
            
            return value
        } else {
            let value: NSData
            
            OSSpinLockLock(&impl.lock)
            if impl.data != nil {
                value = impl.data
            } else if impl.string != nil {
                value = impl.string.dataUsingEncoding(NSUTF8StringEncoding) ?? NSData()
                impl.data = value
            } else {
                value = NSData()
            }
            OSSpinLockUnlock(&impl.lock)
            
            return value
        }
    }
    
    public var string: String {
        if isUniquelyReferencedNonObjC(&self.impl) {
            let value: String
            
            if impl.string != nil {
                value = impl.string
            } else if impl.data != nil {
                let fromData = NSString(data: impl.data, encoding: NSUTF8StringEncoding)
                if fromData == nil {
                    value = ""
                    impl.string = value
                } else {
                    value = fromData as! String
                    impl.string = value
                }
            } else {
                value = ""
            }
            
            return value
        } else {
            let value: String
            
            OSSpinLockLock(&impl.lock)
            if impl.string != nil {
                value = impl.string
            } else if impl.data != nil {
                let fromData = NSString(data: impl.data, encoding: NSUTF8StringEncoding)
                if fromData == nil {
                    value = ""
                    impl.string = value
                } else {
                    value = fromData as! String
                    impl.string = value
                }
            } else {
                value = ""
            }
            OSSpinLockUnlock(&impl.lock)
            
            return value
        }
    }
}
