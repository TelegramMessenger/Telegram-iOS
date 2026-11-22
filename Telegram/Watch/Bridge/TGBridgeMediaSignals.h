#import <SSignalKit/SSignalKit.h>
#import <WatchCommonWatch/WatchCommonWatch.h>

@class TGBridgeImageMediaAttachment;
@class TGBridgeVideoMediaAttachment;
@class TGBridgeDocumentMediaAttachment;

typedef enum
{
    TGMediaStickerImageTypeList,
    TGMediaStickerImageTypeNormal,
    TGMediaStickerImageTypeInput
} TGMediaStickerImageType;

@interface TGBridgeMediaSignals : NSObject

+ (SSignal *)thumbnailWithPeerId:(int64_t)peerId messageId:(int32_t)messageId size:(CGSize)size notification:(bool)notification;
+ (SSignal *)avatarWithPeerId:(int64_t)peerId url:(NSString *)url type:(TGBridgeMediaAvatarType)type;

+ (SSignal *)stickerWithDocumentId:(int64_t)documentId packId:(int64_t)packId accessHash:(int64_t)accessHash type:(TGMediaStickerImageType)type;
+ (SSignal *)stickerWithDocumentId:(int64_t)documentId peerId:(int64_t)peerId messageId:(int32_t)messageId type:(TGMediaStickerImageType)type notification:(bool)notification;

@end
