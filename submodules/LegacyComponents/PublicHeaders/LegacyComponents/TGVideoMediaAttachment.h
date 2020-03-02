

#import <LegacyComponents/TGMediaAttachment.h>

#import <LegacyComponents/TGVideoInfo.h>
#import <LegacyComponents/TGImageInfo.h>
#import <LegacyComponents/TGMediaOriginInfo.h>

#define TGVideoMediaAttachmentType ((int)0x338EAA20)

@interface TGVideoMediaAttachment : TGMediaAttachment <NSCoding, TGMediaAttachmentParser>

@property (nonatomic) int64_t videoId;
@property (nonatomic) int64_t accessHash;

@property (nonatomic) int64_t localVideoId;

@property (nonatomic) int duration;
@property (nonatomic) CGSize dimensions;

@property (nonatomic, strong) TGVideoInfo *videoInfo;
@property (nonatomic, strong) TGImageInfo *thumbnailInfo;

@property (nonatomic) NSString *caption;
@property (nonatomic) bool hasStickers;
@property (nonatomic, strong) NSArray *embeddedStickerDocuments;

@property (nonatomic, readonly) NSArray *textCheckingResults;

@property (nonatomic, strong) TGMediaOriginInfo *originInfo;

@property (nonatomic) bool loopVideo;
@property (nonatomic) bool roundMessage;

@end
