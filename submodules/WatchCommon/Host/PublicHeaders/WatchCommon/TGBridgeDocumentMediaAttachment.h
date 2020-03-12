#import <WatchCommon/TGBridgeMediaAttachment.h>

@interface TGBridgeDocumentMediaAttachment : TGBridgeMediaAttachment

@property (nonatomic, assign) int64_t documentId;
@property (nonatomic, assign) int64_t localDocumentId;
@property (nonatomic, assign) int32_t fileSize;

@property (nonatomic, strong) NSString *fileName;
@property (nonatomic, strong) NSValue *imageSize;
@property (nonatomic, assign) bool isAnimated;
@property (nonatomic, assign) bool isSticker;
@property (nonatomic, strong) NSString *stickerAlt;
@property (nonatomic, assign) int64_t stickerPackId;
@property (nonatomic, assign) int64_t stickerPackAccessHash;

@property (nonatomic, assign) bool isVoice;
@property (nonatomic, assign) bool isAudio;
@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) NSString *performer;
@property (nonatomic, assign) int32_t duration;

@end
