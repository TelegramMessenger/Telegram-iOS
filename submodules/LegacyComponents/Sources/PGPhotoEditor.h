#import <Foundation/Foundation.h>
#import <SSignalKit/SSignalKit.h>

#import <LegacyComponents/TGVideoEditAdjustments.h>

@class TGPhotoEditorPreviewView;
@class TGPaintingData;

@interface PGPhotoEditor : NSObject

@property (nonatomic, assign) CGSize originalSize;
@property (nonatomic, assign) CGRect cropRect;
@property (nonatomic, readonly) CGSize rotatedCropSize;
@property (nonatomic, assign) CGFloat cropRotation;
@property (nonatomic, assign) UIImageOrientation cropOrientation;
@property (nonatomic, assign) CGFloat cropLockedAspectRatio;
@property (nonatomic, assign) bool cropMirrored;
@property (nonatomic, strong) TGPaintingData *paintingData;
@property (nonatomic, assign) NSTimeInterval trimStartValue;
@property (nonatomic, assign) NSTimeInterval trimEndValue;
@property (nonatomic, assign) bool sendAsGif;
@property (nonatomic, assign) TGMediaVideoConversionPreset preset;

@property (nonatomic, weak) TGPhotoEditorPreviewView *previewOutput;
@property (nonatomic, strong) NSArray *additionalOutputs;
@property (nonatomic, readonly) NSArray *tools;

@property (nonatomic, readonly) bool processing;
@property (nonatomic, readonly) bool readyForProcessing;

@property (nonatomic, readonly) bool enableStickers;

@property (nonatomic, assign) bool cropOnLast;

@property (nonatomic, readonly) bool forVideo;

@property (nonatomic, assign) bool standalone;

@property (nonatomic, assign) bool disableAll;

- (instancetype)initWithOriginalSize:(CGSize)originalSize adjustments:(id<TGMediaEditAdjustments>)adjustments forVideo:(bool)forVideo enableStickers:(bool)enableStickers;

- (void)cleanup;

- (void)setImage:(UIImage *)image forCropRect:(CGRect)cropRect cropRotation:(CGFloat)cropRotation cropOrientation:(UIImageOrientation)cropOrientation cropMirrored:(bool)cropMirrored fullSize:(bool)fullSize;
- (void)setPlayerItem:(AVPlayerItem *)playerItem forCropRect:(CGRect)cropRect cropRotation:(CGFloat)cropRotation cropOrientation:(UIImageOrientation)cropOrientation cropMirrored:(bool)cropMirrored;
- (void)setCIImage:(CIImage *)ciImage;

- (void)updateProcessChain:(bool)force;

- (void)processAnimated:(bool)animated completion:(void (^)(void))completion;
- (void)reprocess;

- (void)createResultImageWithCompletion:(void (^)(UIImage *image))completion;
- (UIImage *)currentResultImage;
- (void)currentResultCIImage:(void (^)(CIImage *image, void(^unlock)(void)))completion;

- (bool)hasDefaultCropping;

- (SSignal *)histogramSignal;

- (void)importAdjustments:(id<TGMediaEditAdjustments>)adjustments;
- (id<TGMediaEditAdjustments>)exportAdjustments;
- (id<TGMediaEditAdjustments>)exportAdjustmentsWithPaintingData:(TGPaintingData *)paintingData;

+ (UIImage *)resultImageForImage:(UIImage *)image adjustments:(id<TGMediaEditAdjustments>)adjustments;

@end
