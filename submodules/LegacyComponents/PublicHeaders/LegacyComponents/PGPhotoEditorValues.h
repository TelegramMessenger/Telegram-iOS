#import <LegacyComponents/TGMediaEditingContext.h>

@class TGPaintingData;
@class PGRectangle;

@interface PGPhotoEditorValues : NSObject <TGMediaEditAdjustments>

@property (nonatomic, readonly) PGRectangle *cropRectangle;
@property (nonatomic, readonly) CGSize cropSize;
@property (nonatomic, readonly) bool enhanceDocument;

+ (instancetype)editorValuesWithOriginalSize:(CGSize)originalSize cropRectangle:(PGRectangle *)cropRectangle cropOrientation:(UIImageOrientation)cropOrientation cropSize:(CGSize)cropSize enhanceDocument:(bool)enhanceDocument paintingData:(TGPaintingData *)paintingData;

+ (instancetype)editorValuesWithOriginalSize:(CGSize)originalSize cropRect:(CGRect)cropRect cropRotation:(CGFloat)cropRotation cropOrientation:(UIImageOrientation)cropOrientation cropLockedAspectRatio:(CGFloat)cropLockedAspectRatio cropMirrored:(bool)cropMirrored toolValues:(NSDictionary *)toolValues paintingData:(TGPaintingData *)paintingData sendAsGif:(bool)sendAsGif;

@end
