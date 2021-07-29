import Foundation

extension _AdaptedPostboxDecoder {
    final class UnkeyedContainer {
        enum Content {
            case int32Array([Int32])
            case int64Array([Int64])
            case objectArray([Data])
            case stringArray([String])
            case dataArray([Data])

            var count: Int {
                switch self {
                case let .int32Array(array):
                    return array.count
                case let .int64Array(array):
                    return array.count
                case let .objectArray(array):
                    return array.count
                case let .stringArray(array):
                    return array.count
                case let .dataArray(array):
                    return array.count
                }
            }
        }

        let codingPath: [CodingKey]
        let userInfo: [CodingUserInfoKey: Any]
        let content: Content

        var count: Int? {
            return self.content.count
        }

        var isAtEnd: Bool {
            return self.currentIndex >= self.content.count
        }

        fileprivate var _currentIndex: Int = 0

        var currentIndex: Int {
            return self._currentIndex
        }
       
        init(data: Data, codingPath: [CodingKey], userInfo: [CodingUserInfoKey: Any], content: Content) {
            self.codingPath = codingPath
            self.userInfo = userInfo
            self.content = content
        }
    }
}

extension _AdaptedPostboxDecoder.UnkeyedContainer: UnkeyedDecodingContainer {
    func decodeNil() throws -> Bool {
        preconditionFailure()
    }

    func decode<T>(_ type: T.Type) throws -> T where T : Decodable {
        if type == Data.self {
            switch self.content {
            case let .dataArray(array):
                let index = self._currentIndex
                self._currentIndex += 1
                return array[index] as! T
            default:
                throw DecodingError.typeMismatch(Data.self, DecodingError.Context(codingPath: self.codingPath, debugDescription: ""))
            }
        } else {
            switch self.content {
            case let .objectArray(array):
                let index = self._currentIndex
                self._currentIndex += 1

                let data = array[index]
                return try AdaptedPostboxDecoder().decode(T.self, from: data)
            default:
                throw DecodingError.typeMismatch(T.self, DecodingError.Context(codingPath: self.codingPath, debugDescription: ""))
            }
        }
    }

    func decode(_ type: Int32.Type) throws -> Int32 {
        switch self.content {
        case let .int32Array(array):
            let index = self._currentIndex
            self._currentIndex += 1
            return array[index]
        default:
            throw DecodingError.typeMismatch(Int32.self, DecodingError.Context(codingPath: self.codingPath, debugDescription: ""))
        }
    }

    func decode(_ type: Int64.Type) throws -> Int64 {
        switch self.content {
        case let .int64Array(array):
            let index = self._currentIndex
            self._currentIndex += 1
            return array[index]
        default:
            throw DecodingError.typeMismatch(Int64.self, DecodingError.Context(codingPath: self.codingPath, debugDescription: ""))
        }
    }

    func decode(_ type: String.Type) throws -> String {
        switch self.content {
        case let .stringArray(array):
            let index = self._currentIndex
            self._currentIndex += 1
            return array[index]
        default:
            throw DecodingError.typeMismatch(String.self, DecodingError.Context(codingPath: self.codingPath, debugDescription: ""))
        }
    }

    func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
        preconditionFailure()
    }

    func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
        preconditionFailure()
    }

    func superDecoder() throws -> Decoder {
        preconditionFailure()
    }
}

extension _AdaptedPostboxDecoder.UnkeyedContainer: AdaptedPostboxDecodingContainer {}
