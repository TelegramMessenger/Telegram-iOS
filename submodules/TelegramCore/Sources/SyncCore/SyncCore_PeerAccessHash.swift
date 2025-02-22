import Foundation
import FlatBuffers
import FlatSerialization

public enum TelegramPeerAccessHash: Hashable {
    case personal(Int64)
    case genericPublic(Int64)
    
    public var value: Int64 {
        switch self {
        case let .personal(personal):
            return personal
        case let .genericPublic(genericPublic):
            return genericPublic
        }
    }
    
    public init(flatBuffersObject: TelegramCore_TelegramPeerAccessHash) throws {
        switch flatBuffersObject.valueType {
        case .telegrampeeraccesshashPersonal:
            guard let personal = flatBuffersObject.value(type: TelegramCore_TelegramPeerAccessHash_Personal.self) else {
                throw FlatBuffersError.missingRequiredField(file: #file, line: #line)
            }
            self = .personal(personal.accessHash)
        case .telegrampeeraccesshashGenericpublic:
            guard let genericPublic = flatBuffersObject.value(type: TelegramCore_TelegramPeerAccessHash_GenericPublic.self) else {
                throw FlatBuffersError.missingRequiredField(file: #file, line: #line)
            }
            self = .genericPublic(genericPublic.accessHash)
        case .none_:
            throw FlatBuffersError.missingRequiredField(file: #file, line: #line)
        }
    }
    
    public func encodeToFlatBuffers(builder: inout FlatBufferBuilder) -> Offset {
        let valueType: TelegramCore_TelegramPeerAccessHash_Value
        let valueOffset: Offset
        
        switch self {
        case let .personal(accessHash):
            valueType = .telegrampeeraccesshashPersonal
            let start = TelegramCore_TelegramPeerAccessHash_Personal.startTelegramPeerAccessHash_Personal(&builder)
            TelegramCore_TelegramPeerAccessHash_Personal.add(accessHash: accessHash, &builder)
            valueOffset = TelegramCore_TelegramPeerAccessHash_Personal.endTelegramPeerAccessHash_Personal(&builder, start: start)
        case let .genericPublic(accessHash):
            valueType = .telegrampeeraccesshashGenericpublic
            let start = TelegramCore_TelegramPeerAccessHash_GenericPublic.startTelegramPeerAccessHash_GenericPublic(&builder)
            TelegramCore_TelegramPeerAccessHash_GenericPublic.add(accessHash: accessHash, &builder)
            valueOffset = TelegramCore_TelegramPeerAccessHash_GenericPublic.endTelegramPeerAccessHash_GenericPublic(&builder, start: start)
        }
        
        let start = TelegramCore_TelegramPeerAccessHash.startTelegramPeerAccessHash(&builder)
        TelegramCore_TelegramPeerAccessHash.add(valueType: valueType, &builder)
        TelegramCore_TelegramPeerAccessHash.add(value: valueOffset, &builder)
        return TelegramCore_TelegramPeerAccessHash.endTelegramPeerAccessHash(&builder, start: start)
    }
}
