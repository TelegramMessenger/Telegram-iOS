#import "TGMediaOriginInfo.h"

#import "TGStringUtils.h"
#import "TGDocumentMediaAttachment.h"

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
        
        _chatPhotoPeerId = [aDecoder decodeObjectForKey:@"cp"];
        
        _webpageUrl = [aDecoder decodeObjectForKey:@"wu"];
        
        _wallpaperId = [aDecoder decodeObjectForKey:@"wi"];
        
        _remoteStickerEmoji = [aDecoder decodeObjectForKey:@"re"];
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
    
    [aCoder encodeObject:_chatPhotoPeerId forKey:@"cp"];
    
    [aCoder encodeObject:_webpageUrl forKey:@"wu"];
    
    [aCoder encodeObject:_wallpaperId forKey:@"wi"];
    
    [aCoder encodeObject:_remoteStickerEmoji forKey:@"re"];
}

- (NSData *)fileReferenceForVolumeId:(int64_t)volumeId localId:(int32_t)localId
{
    return _fileReferences[[NSString stringWithFormat:@"%lld_%d", volumeId, localId]];
}

- (NSData *)fileReferenceForDocumentId:(int64_t)documentId accessHash:(int64_t)accessHash
{
    return _fileReferences[[NSString stringWithFormat:@"%lld_%lld", documentId, accessHash]];
}

+ (instancetype)mediaOriginInfoWithStringRepresentation:(NSString *)string
{
    if (string.length == 0)
        return nil;
    
    NSArray *components = [string componentsSeparatedByString:@";"];
    
    TGMediaOriginInfo *info = [[TGMediaOriginInfo alloc] init];
    
    NSArray *keyComponents = [components[0] componentsSeparatedByString:@"|"];
    info->_type = (TGMediaOriginType)[keyComponents.firstObject intValue];
    switch (info->_type)
    {
        case TGMediaOriginTypeUndefined:
        case TGMediaOriginTypeRecentSticker:
        case TGMediaOriginTypeRecentGif:
        case TGMediaOriginTypeFavoriteSticker:
        case TGMediaOriginTypeRecentMask:
            break;
            
        case TGMediaOriginTypeRemoteSticker:
            info->_remoteStickerEmoji = keyComponents[1];
            break;
            
        case TGMediaOriginTypeMessage:
            info->_cid = @([keyComponents[1] integerValue]);
            info->_mid = @([keyComponents[2] integerValue]);
            break;
            
        case TGMediaOriginTypeSticker:
            info->_stickerPackId = @([keyComponents[1] integerValue]);
            info->_stickerPackAccessHash = @([keyComponents[2] integerValue]);
            break;
            
        case TGMediaOriginTypeProfilePhoto:
            info->_profilePhotoUserId = @([keyComponents[1] integerValue]);
            info->_profilePhotoOffset = @([keyComponents[2] integerValue]);
            break;
            
        case TGMediaOriginTypeChatPhoto:
            info->_chatPhotoPeerId = @([keyComponents[1] integerValue]);
            break;
            
        case TGMediaOriginTypeWebpage:
        {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            NSString *url = (__bridge_transfer NSString *)CFURLCreateStringByReplacingPercentEscapesUsingEncoding(NULL, (CFStringRef)keyComponents[1], CFSTR(""), kCFStringEncodingUTF8);
            info->_webpageUrl = url;
#pragma clang diagnostic pop
        }
            break;
        
        case TGMediaOriginTypeWallpaper:
            info->_wallpaperId = @([keyComponents[1] integerValue]);
            break;
            
        default:
            return nil;
    }
    if (components.count > 1 && [components[1] length] > 0)
        info->_fileReference = [NSData dataWithHexString:components[1]];

    NSMutableDictionary *fileReferences = [[NSMutableDictionary alloc] init];
    if (components.count > 2 && [components[2] length] > 0)
    {
        NSArray *refComponents = [components[2] componentsSeparatedByString:@","];
        for (NSString *ref in refComponents)
        {
            NSArray *components = [ref componentsSeparatedByString:@":"];
            if (components.count == 2)
                fileReferences[components.firstObject] = [NSData dataWithHexString:components.lastObject];
        }
    }
    info->_fileReferences = fileReferences;
    
    return info;
}

- (NSString *)stringRepresentation
{
    NSString *fileReference = @"";
    if (self.fileReference.length > 0)
        fileReference = [self.fileReference stringByEncodingInHex];
    NSMutableString *fileReferences = [[NSMutableString alloc] init];
    if (self.fileReferences.count > 0)
    {
        [self.fileReferences enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSData *value, __unused BOOL *stop)
        {
            if (fileReferences.length > 0)
                [fileReferences appendString:@","];
            [fileReferences appendFormat:@"%@:%@", key, [value stringByEncodingInHex]];
        }];
    }
    return [NSString stringWithFormat:@"%@;%@;%@", [self key], fileReference, fileReferences];
}

- (NSString *)key
{
    switch (_type)
    {
        case TGMediaOriginTypeUndefined:
            return @"0";
            
        case TGMediaOriginTypeMessage:
            return [NSString stringWithFormat:@"%d|%@|%@", _type, _cid, _mid];
            
        case TGMediaOriginTypeSticker:
            return [NSString stringWithFormat:@"%d|%@|%@", _type, _stickerPackId, _stickerPackAccessHash];
            
        case TGMediaOriginTypeRecentSticker:
        case TGMediaOriginTypeFavoriteSticker:
        case TGMediaOriginTypeRecentGif:
        case TGMediaOriginTypeRecentMask:
            return [NSString stringWithFormat:@"%d", _type];
            
        case TGMediaOriginTypeRemoteSticker:
            return [NSString stringWithFormat:@"%d|%@", _type, _remoteStickerEmoji];
            
        case TGMediaOriginTypeProfilePhoto:
            return [NSString stringWithFormat:@"%d|%@|%@", _type, _profilePhotoUserId, _profilePhotoOffset];
            
        case TGMediaOriginTypeChatPhoto:
            return [NSString stringWithFormat:@"%d|%@", _type, _chatPhotoPeerId];
            
        case TGMediaOriginTypeWebpage:
        {
            NSString *url = [TGStringUtils stringByEscapingForURL:_webpageUrl];
            return [NSString stringWithFormat:@"%d|%@", _type, url];
        }
            
        case TGMediaOriginTypeWallpaper:
            return [NSString stringWithFormat:@"%d|%@", _type, _wallpaperId];
            
        default:
            return nil;
    }
}

+ (instancetype)mediaOriginInfoWithFileReference:(NSData *)fileReference fileReferences:(NSDictionary *)fileReferences
{
    TGMediaOriginInfo *info = [[TGMediaOriginInfo alloc] init];
    info->_type = TGMediaOriginTypeUndefined;
    info->_fileReference = fileReference;
    info->_fileReferences = fileReferences;
    return info;
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

+ (instancetype)mediaOriginInfoWithFileReference:(NSData *)fileReference fileReferences:(NSDictionary *)fileReferences stickerPackId:(int64_t)packId accessHash:(int64_t)accessHash
{
    TGMediaOriginInfo *info = [[TGMediaOriginInfo alloc] init];
    info->_type = TGMediaOriginTypeSticker;
    info->_fileReference = fileReference;
    info->_fileReferences = fileReferences;
    info->_stickerPackId = @(packId);
    info->_stickerPackAccessHash = @(accessHash);
    return info;
}

+ (instancetype)mediaOriginInfoForRecentStickerWithFileReference:(NSData *)fileReference fileReferences:(NSDictionary *)fileReferences
{
    TGMediaOriginInfo *info = [[TGMediaOriginInfo alloc] init];
    info->_type = TGMediaOriginTypeRecentSticker;
    info->_fileReference = fileReference;
    info->_fileReferences = fileReferences;
    return info;
}

+ (instancetype)mediaOriginInfoForRecentMaskWithFileReference:(NSData *)fileReference fileReferences:(NSDictionary *)fileReferences
{
    TGMediaOriginInfo *info = [[TGMediaOriginInfo alloc] init];
    info->_type = TGMediaOriginTypeRecentMask;
    info->_fileReference = fileReference;
    info->_fileReferences = fileReferences;
    return info;
}

+ (instancetype)mediaOriginInfoForFavoriteStickerWithFileReference:(NSData *)fileReference fileReferences:(NSDictionary *)fileReferences
{
    TGMediaOriginInfo *info = [[TGMediaOriginInfo alloc] init];
    info->_type = TGMediaOriginTypeFavoriteSticker;
    info->_fileReference = fileReference;
    info->_fileReferences = fileReferences;
    return info;
}

+ (instancetype)mediaOriginInfoForRecentGifWithFileReference:(NSData *)fileReference fileReferences:(NSDictionary *)fileReferences
{
    TGMediaOriginInfo *info = [[TGMediaOriginInfo alloc] init];
    info->_type = TGMediaOriginTypeRecentGif;
    info->_fileReference = fileReference;
    info->_fileReferences = fileReferences;
    return info;
}

+ (instancetype)mediaOriginInfoWithFileReference:(NSData *)fileReference fileReferences:(NSDictionary *)fileReferences userId:(int64_t)userId offset:(int32_t)offset
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

+ (instancetype)mediaOriginInfoWithFileReference:(NSData *)fileReference fileReferences:(NSDictionary *)fileReferences peerId:(int64_t)peerId
{
    TGMediaOriginInfo *info = [[TGMediaOriginInfo alloc] init];
    info->_type = TGMediaOriginTypeChatPhoto;
    info->_fileReference = fileReference;
    info->_fileReferences = fileReferences;
    info->_chatPhotoPeerId = @(peerId);
    return info;
}

+ (instancetype)mediaOriginInfoWithFileReferences:(NSDictionary *)fileReferences wallpaperId:(int32_t)wallpaperId
{
    TGMediaOriginInfo *info = [[TGMediaOriginInfo alloc] init];
    info->_type = TGMediaOriginTypeWallpaper;
    info->_fileReferences = fileReferences;
    info->_wallpaperId = @(wallpaperId);
    return info;
}

+ (instancetype)mediaOriginInfoWithFileReference:(NSData *)fileReference fileReferences:(NSDictionary *)fileReferences emoji:(NSString *)emoji
{
    TGMediaOriginInfo *info = [[TGMediaOriginInfo alloc] init];
    info->_type = TGMediaOriginTypeRemoteSticker;
    info->_fileReference = fileReference;
    info->_fileReferences = fileReferences;
    info->_remoteStickerEmoji = emoji;
    return info;
}


+ (instancetype)mediaOriginInfoForDocumentAttachment:(TGDocumentMediaAttachment *)document
{
    if ([document.stickerPackReference isKindOfClass:[TGStickerPackIdReference class]])
    {
        TGStickerPackIdReference *reference = (TGStickerPackIdReference *)document.stickerPackReference;
        return [TGMediaOriginInfo mediaOriginInfoWithFileReference:nil fileReferences:nil stickerPackId:reference.packId accessHash:reference.packAccessHash];
    }
    else if (document.isAnimated)
    {
        
    }
    return nil;
}

@end
