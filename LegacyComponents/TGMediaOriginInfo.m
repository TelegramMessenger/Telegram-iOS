#import "TGMediaOriginInfo.h"

@implementation TGMediaOriginInfo

+ (instancetype)mediaOriginInfoWithFileReference:(NSData *)fileReference cid:(int64_t)cid mid:(int32_t)mid
{
    TGMediaOriginInfo *info = [[TGMediaOriginInfo alloc] init];
    info->_type = TGMediaOriginTypeMessage;
    info->_fileReference = fileReference;
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

+ (instancetype)mediaOriginInfoWithFileReference:(NSData *)fileReference userId:(int32_t)userId offset:(int32_t)offset
{
    TGMediaOriginInfo *info = [[TGMediaOriginInfo alloc] init];
    info->_type = TGMediaOriginTypeProfilePhoto;
    info->_fileReference = fileReference;
    info->_profilePhotoUserId = @(userId);
    info->_profilePhotoOffset = @(offset);
    return info;
}

@end
