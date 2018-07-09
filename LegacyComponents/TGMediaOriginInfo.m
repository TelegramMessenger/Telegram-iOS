#import "TGMediaOriginInfo.h"

@implementation TGMediaOriginInfo

- (NSData *)fileReferenceForVolumeId:(int64_t)volumeId localId:(int32_t)localId
{
    return _fileReferences[[NSString stringWithFormat:@"%lld_%d", volumeId, localId]];
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

@end
