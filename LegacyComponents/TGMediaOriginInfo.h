#import <Foundation/Foundation.h>

typedef enum {
    TGMediaOriginTypeMessage,
    TGMediaOriginTypeSticker,
    TGMediaOriginTypeProfilePhoto,
    TGMediaOriginTypeWebpage
} TGMediaOriginType;

@interface TGMediaOriginInfo : NSObject <NSCoding>

@property (nonatomic, readonly) TGMediaOriginType type;

@property (nonatomic, readonly, strong) NSData *fileReference;
@property (nonatomic, readonly, strong) NSDictionary *fileReferences;

@property (nonatomic, readonly, strong) NSNumber *cid;
@property (nonatomic, readonly, strong) NSNumber *mid;

@property (nonatomic, readonly, strong) NSNumber *stickerPackId;
@property (nonatomic, readonly, strong) NSNumber *stickerPackAccessHash;

@property (nonatomic, readonly, strong) NSNumber *profilePhotoUserId;
@property (nonatomic, readonly, strong) NSNumber *profilePhotoOffset;

@property (nonatomic, readonly, strong) NSString *webpageUrl;

- (NSData *)fileReferenceForVolumeId:(int64_t)volumeId localId:(int32_t)localId;
- (NSString *)key;

+ (instancetype)mediaOriginInfoWithFileReference:(NSData *)fileReference fileReferences:(NSDictionary *)fileReferences cid:(int64_t)cid mid:(int32_t)mid;
+ (instancetype)mediaOriginInfoWithFileReference:(NSData *)fileReference stickerPackId:(int64_t)packId accessHash:(int64_t)accessHash;
+ (instancetype)mediaOriginInfoWithFileReference:(NSData *)fileReference fileReferences:(NSDictionary *)fileReferences userId:(int32_t)userId offset:(int32_t)offset;
+ (instancetype)mediaOriginInfoWithFileReference:(NSData *)fileReference fileReferences:(NSDictionary *)fileReferences url:(NSString *)url;

@end
