#import "TGMediaOriginInfo.h"

@implementation TGMediaOriginInfo

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self != nil)
    {
        _type = [aDecoder decodeInt32ForKey:@"t"];
        
        _fileReference = [aDecoder decodeObjectForKey:@"r"];
        _fileReferences = [aDecoder decodeObjectForKey:@"rs"];
        
        _cid = [aDecoder decodeObjectForKey:@"mc"];
        _mid = [aDecoder decodeObjectForKey:@"mi"];
        
        _stickerPackId = [aDecoder decodeObjectForKey:@"si"];
        _stickerPackAccessHash = [aDecoder decodeObjectForKey:@"sa"];
        
        _profilePhotoUserId = [aDecoder decodeObjectForKey:@"pi"];
        _profilePhotoOffset = [aDecoder decodeObjectForKey:@"po"];
        
        _webpageUrl = [aDecoder decodeObjectForKey:@"wu"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeInt32:_type forKey:@"t"];
    [aCoder encodeObject:_fileReference forKey:@"r"];
    [aCoder encodeObject:_fileReferences forKey:@"rs"];
    
    [aCoder encodeObject:_cid forKey:@"mc"];
    [aCoder encodeObject:_mid forKey:@"mi"];
    
    [aCoder encodeObject:_stickerPackId forKey:@"si"];
    [aCoder encodeObject:_stickerPackAccessHash forKey:@"sa"];
    
    [aCoder encodeObject:_profilePhotoUserId forKey:@"pi"];
    [aCoder encodeObject:_profilePhotoOffset forKey:@"po"];
    
    [aCoder encodeObject:_webpageUrl forKey:@"wu"];
}

- (NSData *)fileReferenceForVolumeId:(int64_t)volumeId localId:(int32_t)localId
{
    return _fileReferences[[NSString stringWithFormat:@"%lld_%d", volumeId, localId]];
}

- (NSString *)key
{
    switch (_type)
    {
        case TGMediaOriginTypeMessage:
            return [NSString stringWithFormat:@"%d_%@_%@", _type, _cid, _mid];
            
        case TGMediaOriginTypeSticker:
            return [NSString stringWithFormat:@"%d_%@_%@", _type, _stickerPackId, _stickerPackAccessHash];
            
        case TGMediaOriginTypeProfilePhoto:
            return [NSString stringWithFormat:@"%d_%@_%@", _type, _profilePhotoUserId, _profilePhotoOffset];
            
        case TGMediaOriginTypeWebpage:
            return [NSString stringWithFormat:@"%d_%@", _type, _webpageUrl];
            
        default:
            return nil;
    }
}

+ (instancetype)mediaOriginInfoWithFileReference:(NSData *)fileReference fileReferences:(NSDictionary *)fileReferences cid:(int64_t)cid mid:(int32_t)mid
{
    TGMediaOriginInfo *info = [[TGMediaOriginInfo alloc] init];
    info->_type = TGMediaOriginTypeMessage;
    info->_fileReference = fileReference;
    info->_fileReferences = fileReferences;
    info->_cid = @(cid);
    info->_mid = @(mid);
    return info;
}

+ (instancetype)mediaOriginInfoWithFileReference:(NSData *)fileReference stickerPackId:(int64_t)packId accessHash:(int64_t)accessHash
{
    TGMediaOriginInfo *info = [[TGMediaOriginInfo alloc] init];
    info->_type = TGMediaOriginTypeSticker;
    info->_fileReference = fileReference;
    info->_stickerPackId = @(packId);
    info->_stickerPackAccessHash = @(accessHash);
    return info;
}

+ (instancetype)mediaOriginInfoWithFileReference:(NSData *)fileReference fileReferences:(NSDictionary *)fileReferences userId:(int32_t)userId offset:(int32_t)offset
{
    TGMediaOriginInfo *info = [[TGMediaOriginInfo alloc] init];
    info->_type = TGMediaOriginTypeProfilePhoto;
    info->_fileReference = fileReference;
    info->_fileReferences = fileReferences;
    info->_profilePhotoUserId = @(userId);
    info->_profilePhotoOffset = @(offset);
    return info;
}

+ (instancetype)mediaOriginInfoWithFileReference:(NSData *)fileReference fileReferences:(NSDictionary *)fileReferences url:(NSString *)url
{
    TGMediaOriginInfo *info = [[TGMediaOriginInfo alloc] init];
    info->_type = TGMediaOriginTypeWebpage;
    info->_fileReference = fileReference;
    info->_fileReferences = fileReferences;
    info->_webpageUrl = url;
    return info;
}

@end
