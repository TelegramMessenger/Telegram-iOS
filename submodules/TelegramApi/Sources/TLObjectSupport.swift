import Foundation
import TelegramApiObjC

/// Implemented by every generated `Api.*` enum: the ObjC object backing the current case.
public protocol TLObjectBacked {
    var tlBackingObject: TLObject { get }
}

/// Every generated `Api.*` enum describes itself by its constructor name only (`peerUser`).
/// Field values never appear: `"\(value)"` bypasses the logger's redaction, and the names come
/// from the schema table, so printing does not depend on Swift reflection metadata (which
/// TelegramApi's release build omits).
extension CustomStringConvertible where Self: TLObjectBacked {
    public var description: String {
        return String(cString: self.tlBackingObject.tl_constructorInfo.pointee.name)
    }
}

// MARK: - Packed integer vectors

func tlPackInt32(_ values: [Int32]) -> Data {
    return values.withUnsafeBytes { Data($0) }
}

func tlPackInt64(_ values: [Int64]) -> Data {
    return values.withUnsafeBytes { Data($0) }
}

func tlUnpackInt32(_ data: Data) -> [Int32] {
    return data.withUnsafeBytes { raw in
        (0 ..< raw.count / 4).map { raw.loadUnaligned(fromByteOffset: $0 * 4, as: Int32.self) }
    }
}

func tlUnpackInt64(_ data: Data) -> [Int64] {
    return data.withUnsafeBytes { raw in
        (0 ..< raw.count / 8).map { raw.loadUnaligned(fromByteOffset: $0 * 8, as: Int64.self) }
    }
}

// MARK: - Registry lookup

/// Turns an ObjC payload back into its Swift `Api` enum value.
func tlValue(_ object: TLObject) -> Any {
    return tlTypeRegistry[Int(object.tl_typeIndex)](object)
}

// MARK: - Description

func tlDescribedValue(_ field: TLFieldInfo, _ scalar: UnsafeRawPointer?, _ object: Any?) -> Any? {
    if let scalar = scalar {
        switch field.kind {
        case .int32:
            return scalar.load(as: Int32.self)
        case .int64:
            return scalar.load(as: Int64.self)
        case .double:
            return scalar.load(as: Double.self)
        case .int256:
            return scalar.load(as: TLInt256.self).tlInt256
        case .string, .bytes, .object, .vector:
            preconditionFailure("not a scalar kind")
        }
    }
    guard let object = object else {
        return nil
    }
    switch field.kind {
    case .string:
        return object as! String
    case .bytes:
        let data = object as! Data
        return Buffer(data: data)
    case .object:
        return tlValue(object as! TLObject)
    case .vector:
        switch field.elementKind {
        case .int32:
            return tlUnpackInt32(object as! Data)
        case .int64:
            return tlUnpackInt64(object as! Data)
        case .string:
            return object as! [String]
        case .bytes:
            return (object as! [Data]).map { Buffer(data: $0) }
        case .object:
            return (object as! [TLObject]).map { tlValue($0) }
        case .int256, .double, .vector:
            preconditionFailure("unsupported vector element kind")
        }
    case .int32, .int64, .int256, .double:
        preconditionFailure("scalar kinds arrive as pointers")
    }
}

/// `descriptionFields()` for any generated payload. Nested objects come back as Swift
/// enum values, so the logger's type-qualified redaction keys ("User.user") still match.
func tlDescriptionFields(_ object: TLObject) -> (String, [(String, ConstructorParameterDescription)]) {
    var fields: [(String, ConstructorParameterDescription)] = []
    withUnsafeMutablePointer(to: &fields) { pointer in
        TLObjectDescribe(object, pointer) { context, field, scalar, value in
            let fields = context!.assumingMemoryBound(to: [(String, ConstructorParameterDescription)].self)
            fields.pointee.append((String(cString: field.pointee.name), ConstructorParameterDescription(tlDescribedValue(field.pointee, scalar, value))))
        }
    }
    return (String(cString: object.tl_constructorInfo.pointee.name), fields)
}

// MARK: - Engine bridge

private let tlEngineInstalled: Void = {
    TLSetUnknownConstructorHandler { constructorId in
        telegramApiLog("Type constructor \(String(UInt32(bitPattern: constructorId), radix: 16, uppercase: false)) not found")
    }
}()

/// Runs `body` on a TLReader positioned at `reader`'s offset, then moves `reader` to where
/// the engine stopped.
func tlWithReader<R>(_ reader: BufferReader, _ body: (inout TLReader) -> R) -> R {
    _ = tlEngineInstalled
    let buffer = reader.buffer
    var tlReader = TLReader(bytes: buffer.data.map { UnsafePointer($0.assumingMemoryBound(to: UInt8.self)) }, length: Int(buffer._size), offset: Int(reader.offset))
    let result = body(&tlReader)
    reader.tlSetOffset(UInt(tlReader.offset))
    return result
}

/// `Api.parse(_:signature:)` for every non-primitive id.
func tlParseTopLevel(_ reader: BufferReader, signature: Int32) -> Any? {
    return tlWithReader(reader) { tlReader -> Any? in
        TLParseConstructor(&tlReader, signature, TLAnyTypeIndex).map { tlValue($0) }
    }
}

func tlSerializedData(_ object: TLObject, boxed: Swift.Bool) -> Data {
    var writer = TLWriter()
    TLSerialize(object, &writer, boxed)
    defer { TLWriterFree(&writer) }
    guard let bytes = writer.bytes else { return Data() }
    return Data(bytes: bytes, count: writer.length)
}

extension TLObjectBacked {
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
        var writer = TLWriter()
        TLSerialize(self.tlBackingObject, &writer, boxed)
        if let bytes = writer.bytes {
            buffer.appendBytes(bytes, length: UInt(writer.length))
        }
        TLWriterFree(&writer)
    }
}

extension TypeConstructorDescription where Self: TLObjectBacked {
    public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
        return tlDescriptionFields(self.tlBackingObject)
    }
}

func tlParseFunctionResult(_ buffer: Buffer, _ info: UnsafePointer<TLFunctionInfo>) -> Any? {
    let reader = BufferReader(buffer)
    return tlWithReader(reader) { tlReader -> Any? in
        guard let value = TLParseFunctionResult(&tlReader, info) else {
            return nil
        }
        return tlDescribedValue(info.pointee.result, nil, value)
    }
}

/// The non-generic core of every `Api.functions` builder.
func tlFunctionParts(_ call: TLObject) -> (FunctionDescription, Buffer, (Buffer) -> Any?) {
    var writer = TLWriter()
    TLSerialize(call, &writer, true)
    let buffer = Buffer(memory: writer.bytes.map { UnsafeMutableRawPointer($0) }, size: writer.length, capacity: writer.capacity, freeWhenDone: true)
    let info = TLObjectFunctionInfo(call)
    let description = FunctionDescription(name: String(cString: info.pointee.constructor.name), lazyParameters: {
        return tlDescriptionFields(call).1
    })
    return (description, buffer, { buffer in tlParseFunctionResult(buffer, info) })
}

/// Never specialized: one shared response closure for all 837 builders instead of one per
/// result type (measured: 42 → 1 closure copies at -O). Pinned in CLAUDE.md / plan Task 7.
@_semantics("optimize.sil.specialize.generic.never")
func tlFunction<T>(_ call: TLObject) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<T>) {
    let (description, buffer, parse) = tlFunctionParts(call)
    return (description, buffer, DeserializeFunctionResponse { parse($0) as? T })
}

extension TLInt256 {
    var tlInt256: Int256 {
        return Int256(_0: self._0, _1: self._1, _2: self._2, _3: self._3)
    }
}
