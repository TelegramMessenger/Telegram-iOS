import Foundation
import FlatBuffers
import FlatSerialization
import Postbox

public func TelegramMedia_parse(flatBuffersObject: TelegramCore_Media) throws -> Media {
    //TODO:release support other media types
    switch flatBuffersObject.valueType {
    case .mediaTelegrammediafile:
        guard let value = flatBuffersObject.value(type: TelegramCore_Media_TelegramMediaFile.self) else {
            throw FlatBuffersError.missingRequiredField(file: #file, line: #line)
        }
        return try TelegramMediaFile(flatBuffersObject: value.file)
    case .mediaTelegrammediaimage:
        guard let value = flatBuffersObject.value(type: TelegramCore_Media_TelegramMediaImage.self) else {
            throw FlatBuffersError.missingRequiredField(file: #file, line: #line)
        }
        return try TelegramMediaImage(flatBuffersObject: value.image)
    case .none_:
        throw FlatBuffersError.missingRequiredField(file: #file, line: #line)
    }
}

public func TelegramMedia_serialize(media: Media, flatBuffersBuilder builder: inout FlatBufferBuilder) -> Offset? {
    //TODO:release support other media types
    switch media {
    case let file as TelegramMediaFile:
        let fileOffset = file.encodeToFlatBuffers(builder: &builder)
        let start = TelegramCore_Media_TelegramMediaFile.startMedia_TelegramMediaFile(&builder)
        TelegramCore_Media_TelegramMediaFile.add(file: fileOffset, &builder)
        let offset = TelegramCore_Media_TelegramMediaFile.endMedia_TelegramMediaFile(&builder, start: start)
        return TelegramCore_Media.createMedia(&builder, valueType: .mediaTelegrammediafile, valueOffset: offset)
    case let image as TelegramMediaImage:
        let imageOffset = image.encodeToFlatBuffers(builder: &builder)
        let start = TelegramCore_Media_TelegramMediaImage.startMedia_TelegramMediaImage(&builder)
        TelegramCore_Media_TelegramMediaImage.add(image: imageOffset, &builder)
        let offset = TelegramCore_Media_TelegramMediaImage.endMedia_TelegramMediaImage(&builder, start: start)
        return TelegramCore_Media.createMedia(&builder, valueType: .mediaTelegrammediaimage, valueOffset: offset)
    default:
        assert(false)
        return nil
    }
}

public enum TelegramMedia {
    public struct Accessor {
        let _wrappedMedia: Media?
        let _wrapped: TelegramCore_Media?
        
        public init(_ wrapped: TelegramCore_Media) {
            self._wrapped = wrapped
            self._wrappedMedia = nil
        }
        
        public init(_ wrapped: Media) {
            self._wrapped = nil
            self._wrappedMedia = wrapped
        }
        
        public func _parse() -> Media {
            if let _wrappedMedia = self._wrappedMedia {
                return _wrappedMedia
            } else {
                return try! TelegramMedia_parse(flatBuffersObject: self._wrapped!)
            }
        }
    }
}

public extension TelegramMedia.Accessor {
    var id: MediaId? {
        //TODO:release support other media types
        if let _wrappedMedia = self._wrappedMedia {
            return _wrappedMedia.id
        }
        
        switch self._wrapped!.valueType {
        case .mediaTelegrammediafile:
            guard let value = self._wrapped!.value(type: TelegramCore_Media_TelegramMediaFile.self) else {
                return nil
            }
            return MediaId(value.file.fileId)
        case .mediaTelegrammediaimage:
            guard let value = self._wrapped!.value(type: TelegramCore_Media_TelegramMediaImage.self) else {
                return nil
            }
            return MediaId(value.image.imageId)
        case .none_:
            return nil
        }
    }
}
