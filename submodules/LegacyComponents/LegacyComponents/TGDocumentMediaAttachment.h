

#import <LegacyComponents/TGMediaAttachment.h>

#import <LegacyComponents/TGImageInfo.h>
#import <LegacyComponents/TGMediaOriginInfo.h>

#import <LegacyComponents/TGDocumentAttributeFilename.h>
#import <LegacyComponents/TGDocumentAttributeAnimated.h>
#import <LegacyComponents/TGDocumentAttributeSticker.h>
#import <LegacyComponents/TGDocumentAttributeImageSize.h>
#import <LegacyComponents/TGDocumentAttributeAudio.h>
#import <LegacyComponents/TGDocumentAttributeVideo.h>

#define TGDocumentMediaAttachmentType ((int)0xE6C64318)

@interface TGDocumentMediaAttachment : TGMediaAttachment <TGMediaAttachmentParser, NSCoding, NSCopying>

@property (nonatomic) int64_t localDocumentId;

@property (nonatomic) int64_t documentId;
@property (nonatomic) int64_t accessHash;
@property (nonatomic) int datacenterId;
@property (nonatomic) int32_t userId;
@property (nonatomic) int date;
@property (nonatomic, strong) NSString *mimeType;
@property (nonatomic) int size;
@property (nonatomic) int32_t version;
@property (nonatomic, strong) TGImageInfo *thumbnailInfo;

@property (nonatomic, strong) NSString *documentUri;

@property (nonatomic, strong) NSArray *attributes;
@property (nonatomic, strong) NSString *caption;

@property (nonatomic, readonly) NSArray *textCheckingResults;

@property (nonatomic, strong) TGMediaOriginInfo *originInfo;

- (NSString *)safeFileName;
+ (NSString *)safeFileNameForFileName:(NSString *)fileName;
- (NSString *)fileName;

- (bool)isAnimated;
- (bool)isSticker;
- (bool)isStickerWithPack;
- (id<TGStickerPackReference>)stickerPackReference;
- (bool)isVoice;
- (CGSize)pictureSize;
- (bool)isRoundVideo;

@end
