#import <LegacyComponents/TGPhotoPaintEntity.h>

@class TGDocumentMediaAttachment;

@interface TGPhotoPaintStickerEntity : TGPhotoPaintEntity

@property (nonatomic, readonly) TGDocumentMediaAttachment *document;
@property (nonatomic, readonly) NSString *emoji;
@property (nonatomic, readonly) CGSize baseSize;

- (instancetype)initWithDocument:(TGDocumentMediaAttachment *)document baseSize:(CGSize)baseSize;
- (instancetype)initWithEmoji:(NSString *)emoji;

@end
