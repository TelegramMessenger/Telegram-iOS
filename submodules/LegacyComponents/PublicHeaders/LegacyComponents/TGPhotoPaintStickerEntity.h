#import <LegacyComponents/TGPhotoPaintEntity.h>

@class TGDocumentMediaAttachment;

@interface TGPhotoPaintStickerEntity : TGPhotoPaintEntity

@property (nonatomic, readonly) NSData *document;
@property (nonatomic, readonly) NSString *emoji;
@property (nonatomic, readonly) CGSize baseSize;

- (instancetype)initWithDocument:(id)document baseSize:(CGSize)baseSize animated:(bool)animated;
- (instancetype)initWithEmoji:(NSString *)emoji;

@end
