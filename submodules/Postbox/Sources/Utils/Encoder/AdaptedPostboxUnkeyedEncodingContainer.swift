import Foundation
import MurMurHash32

extension _AdaptedPostboxEncoder {
    final class UnkeyedContainer {
        fileprivate enum Item {
            case int32(Int32)
            case int64(Int64)
            case string(String)
            case object(Data)
            case data(Data)
        }

        let codingPath: [CodingKey]
        let userInfo: [CodingUserInfoKey: Any]

        fileprivate var items: [Item] = []
        
        var count: Int {
            return self.items.count
        }
        
        init(codingPath: [CodingKey], userInfo: [CodingUserInfoKey : Any]) {
            self.codingPath = codingPath
            self.userInfo = userInfo
        }

        func makeData(addHeader: Bool, isDictionary: Bool) -> (Data, ValueType) {
            precondition(addHeader)
            
            if self.items.isEmpty {
                let buffer = WriteBuffer()

                var length: Int32 = Int32(self.items.count)
                buffer.write(&length, offset: 0, length: 4)

                return (buffer.makeData(), .Int32Array)
            } else if self.items.allSatisfy({ if case .int32 = $0 { return true } else { return false } }) {
                let buffer = WriteBuffer()

                var length: Int32 = Int32(self.items.count)
                buffer.write(&length, offset: 0, length: 4)

                for case .int32(var value) in self.items {
                    buffer.write(&value, offset: 0, length: 4)
                }

                return (buffer.makeData(), .Int32Array)
            } else if self.items.allSatisfy({ if case .int64 = $0 { return true } else { return false } }) {
                let buffer = WriteBuffer()

                var length: Int32 = Int32(self.items.count)
                buffer.write(&length, offset: 0, length: 4)

                for case .int64(var value) in self.items {
                    buffer.write(&value, offset: 0, length: 8)
                }

                return (buffer.makeData(), .Int64Array)
            } else if self.items.allSatisfy({ if case .string = $0 { return true } else { return false } }) {
                let buffer = WriteBuffer()

                var length: Int32 = Int32(self.items.count)
                buffer.write(&length, offset: 0, length: 4)

                for case .string(let value) in self.items {
                    let data = value.data(using: .utf8, allowLossyConversion: true) ?? (String("").data(using: .utf8)!)
                    var valueLength: Int32 = Int32(data.count)
                    buffer.write(&valueLength, offset: 0, length: 4)
                    buffer.write(data)
                }

                return (buffer.makeData(), .StringArray)
            } else if self.items.allSatisfy({ if case .object = $0 { return true } else { return false } }) {
                let buffer = WriteBuffer()

                var length: Int32 = Int32(self.items.count)
                if isDictionary {
                    precondition(length % 2 == 0)
                    length /= 2
                }
                buffer.write(&length, offset: 0, length: 4)

                for case .object(let data) in self.items {
                    buffer.write(data)
                }

                return (buffer.makeData(), isDictionary ? .ObjectDictionary : .ObjectArray)
            } else if self.items.allSatisfy({ if case .data = $0 { return true } else { return false } }) {
                let buffer = WriteBuffer()

                var length: Int32 = Int32(self.items.count)
                buffer.write(&length, offset: 0, length: 4)

                for case .data(let data) in self.items {
                    var valueLength: Int32 = Int32(data.count)
                    buffer.write(&valueLength, offset: 0, length: 4)
                    buffer.write(data)
                }

                return (buffer.makeData(), .BytesArray)
            } else {
                preconditionFailure()
            }
        }
    }
}

extension _AdaptedPostboxEncoder.UnkeyedContainer: UnkeyedEncodingContainer {
    func encodeNil() throws {
        preconditionFailure()
    }
    
    func encode<T>(_ value: T) throws where T : Encodable {
        if value is Int32 {
            try self.encode(value as! Int32)
        } else if value is Int64 {
            try self.encode(value as! Int64)
        } else if value is String {
            try self.encode(value as! String)
        } else if value is Data {
            try self.encode(value as! Data)
        } else if let value = value as? AdaptedPostboxEncoder.RawObjectData {
            let buffer = WriteBuffer()

            var typeHash: Int32 = value.typeHash
            buffer.write(&typeHash, offset: 0, length: 4)

            var length: Int32 = Int32(value.data.count)
            buffer.write(&length, offset: 0, length: 4)

            buffer.write(value.data)

            self.items.append(.object(buffer.makeData()))
        } else {
            let typeHash: Int32 = murMurHashString32("\(type(of: value))")

            let innerEncoder = _AdaptedPostboxEncoder(typeHash: typeHash)
            try! value.encode(to: innerEncoder)

            let (data, _) = innerEncoder.makeData(addHeader: true, isDictionary: false)

            let buffer = WriteBuffer()

            buffer.write(data)

            self.items.append(.object(buffer.makeData()))
        }
    }

    func encode(_ value: Int32) throws {
        self.items.append(.int32(value))
    }

    func encode(_ value: Int64) throws {
        self.items.append(.int64(value))
    }

    func encode(_ value: String) throws {
        self.items.append(.string(value))
    }

    func encode(_ value: Data) throws {
        self.items.append(.data(value))
    }
    
    func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> where NestedKey : CodingKey {
        preconditionFailure()
    }
    
    func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        preconditionFailure()
    }
    
    func superEncoder() -> Encoder {
        preconditionFailure()
    }
}

extension _AdaptedPostboxEncoder.UnkeyedContainer: AdaptedPostboxEncodingContainer {
    func makeData() -> Data {
        preconditionFailure()
    }
}
