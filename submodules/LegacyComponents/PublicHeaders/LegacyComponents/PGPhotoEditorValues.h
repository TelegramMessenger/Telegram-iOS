#import <LegacyComponents/TGMediaEditingContext.h>

@class TGPaintingData;

@interface PGPhotoEditorValues : NSObject <TGMediaEditAdjustments>

@property (nonatomic, readonly) CGFloat cropRotation;

+ (instancetype)editorValuesWithOriginalSize:(CGSize)originalSize cropRect:(CGRect)cropRect cropRotation:(CGFloat)cropRotation cropOrientation:(UIImageOrientation)cropOrientation cropLockedAspectRatio:(CGFloat)cropLockedAspectRatio cropMirrored:(bool)cropMirrored toolValues:(NSDictionary *)toolValues paintingData:(TGPaintingData *)paintingData sendAsGif:(bool)sendAsGif;

@end
