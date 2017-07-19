#import <UIKit/UIKit.h>

#import <LegacyComponents/PSCoding.h>

#import <LegacyComponents/TGStickerPackReference.h>

@interface TGStickerMaskDescription : NSObject <PSCoding, NSCoding>

@property (nonatomic, readonly) int32_t n;
@property (nonatomic, readonly) CGPoint point;
@property (nonatomic, readonly) CGFloat zoom;

- (instancetype)initWithN:(int32_t)n point:(CGPoint)point zoom:(CGFloat)zoom;

@end

@interface TGDocumentAttributeSticker : NSObject <PSCoding, NSCoding>

@property (nonatomic, strong, readonly) NSString *alt;
@property (nonatomic, strong, readonly) id<TGStickerPackReference> packReference;
@property (nonatomic, strong, readonly) TGStickerMaskDescription *mask;

- (instancetype)initWithAlt:(NSString *)alt packReference:(id<TGStickerPackReference>)packReference mask:(TGStickerMaskDescription *)mask;

@end
