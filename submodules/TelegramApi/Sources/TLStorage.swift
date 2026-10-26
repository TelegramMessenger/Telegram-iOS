import Foundation
import TelegramApiObjC

// Storage access for the generated payload structs. Accessors inline the first three into
// callers; the readers are shared (one copy in TelegramApi) so each field access stays small.

@_alwaysEmitIntoClient @inline(__always)
public func tlBase(_ object: TLObject) -> UnsafeRawPointer {
    return UnsafeRawPointer(Unmanaged.passUnretained(object).toOpaque())
}

@_alwaysEmitIntoClient @inline(__always)
public func tlIsNull(_ object: TLObject, _ offset: Int) -> Bool {
    return tlBase(object).load(fromByteOffset: offset, as: UnsafeRawPointer?.self) == nil
}

@_alwaysEmitIntoClient @inline(__always)
public func tlIsPresent(_ object: TLObject, _ presentOffset: Int, _ bit: Int) -> Bool {
    return (tlBase(object).load(fromByteOffset: presentOffset, as: UInt64.self) & (1 << UInt64(bit))) != 0
}

@usableFromInline func tlReference(_ object: TLObject, _ offset: Int) -> AnyObject {
    return Unmanaged<AnyObject>.fromOpaque(tlBase(object).load(fromByteOffset: offset, as: UnsafeRawPointer.self)).takeUnretainedValue()
}

@usableFromInline func tlStringAt(_ object: TLObject, _ offset: Int) -> String {
    return tlReference(object, offset) as! NSString as String
}

@usableFromInline func tlBufferAt(_ object: TLObject, _ offset: Int) -> Buffer {
    return Buffer(data: tlReference(object, offset) as! NSData as Data)
}

@usableFromInline func tlObjectAt(_ object: TLObject, _ offset: Int) -> TLObject {
    return unsafeDowncast(tlReference(object, offset), to: TLObject.self)
}

@usableFromInline func tlObjectsAt(_ object: TLObject, _ offset: Int) -> [TLObject] {
    return tlReference(object, offset) as! [TLObject]
}

@usableFromInline func tlInt32sAt(_ object: TLObject, _ offset: Int) -> [Int32] {
    return tlUnpackInt32(tlReference(object, offset) as! NSData as Data)
}

@usableFromInline func tlInt64sAt(_ object: TLObject, _ offset: Int) -> [Int64] {
    return tlUnpackInt64(tlReference(object, offset) as! NSData as Data)
}

@usableFromInline func tlStringsAt(_ object: TLObject, _ offset: Int) -> [String] {
    return tlReference(object, offset) as! [String]
}

@usableFromInline func tlBuffersAt(_ object: TLObject, _ offset: Int) -> [Buffer] {
    return (tlReference(object, offset) as! [Data]).map { Buffer(data: $0) }
}

@inline(__always)
func tlStore<T>(_ object: TLObject, _ offset: Int, _ value: T) {
    UnsafeMutableRawPointer(Unmanaged.passUnretained(object).toOpaque()).storeBytes(of: value, toByteOffset: offset, as: T.self)
}

/// Stores `value` +1 (released by TLObject's table-driven -dealloc).
func tlStoreReference(_ object: TLObject, _ offset: Int, _ value: AnyObject?) {
    let retained = value.map { Unmanaged.passRetained($0).toOpaque() }
    UnsafeMutableRawPointer(Unmanaged.passUnretained(object).toOpaque()).storeBytes(of: retained, toByteOffset: offset, as: UnsafeMutableRawPointer?.self)
}
