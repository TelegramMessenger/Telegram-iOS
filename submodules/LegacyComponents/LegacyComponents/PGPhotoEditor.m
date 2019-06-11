#import "PGPhotoEditor.h"

#import <SSignalKit/SSignalKit.h>
#import <LegacyComponents/TGMemoryImageCache.h>

#import "LegacyComponentsInternal.h"

#import <LegacyComponents/TGPhotoEditorUtils.h>
#import "TGPhotoEditorPreviewView.h"
#import "PGPhotoEditorView.h"
#import "PGPhotoEditorPicture.h"

#import <LegacyComponents/PGPhotoEditorValues.h>
#import <LegacyComponents/TGVideoEditAdjustments.h>
#import <LegacyComponents/TGPaintingData.h>

#import "PGPhotoToolComposer.h"
#import "PGEnhanceTool.h"
#import "PGExposureTool.h"
#import "PGContrastTool.h"
#import "PGWarmthTool.h"
#import "PGSaturationTool.h"
#import "PGHighlightsTool.h"
#import "PGShadowsTool.h"
#import "PGVignetteTool.h"
#import "PGGrainTool.h"
#import "PGBlurTool.h"
#import "PGSharpenTool.h"
#import "PGFadeTool.h"
#import "PGTintTool.h"
#import "PGCurvesTool.h"

#import "PGPhotoHistogramGenerator.h"

@interface PGPhotoEditor ()
{
    PGPhotoToolComposer *_toolComposer;
    
    id<TGMediaEditAdjustments> _initialAdjustments;
    
    PGPhotoEditorPicture *_currentInput;
    NSArray *_currentProcessChain;
    GPUImageOutput <GPUImageInput> *_finalFilter;
    
    PGPhotoHistogram *_currentHistogram;
    PGPhotoHistogramGenerator *_histogramGenerator;
    
    UIImageOrientation _imageCropOrientation;
    CGRect _imageCropRect;
    CGFloat _imageCropRotation;
    bool _imageCropMirrored;
    
    SPipe *_histogramPipe;
    
    SQueue *_queue;
    
    bool _forVideo;
    
    bool _processing;
    bool _needsReprocessing;
    
    bool _fullSize;
}
@end

@implementation PGPhotoEditor

- (instancetype)initWithOriginalSize:(CGSize)originalSize adjustments:(id<TGMediaEditAdjustments>)adjustments forVideo:(bool)forVideo enableStickers:(bool)enableStickers
{
    self = [super init];
    if (self != nil)
    {
        _queue = [[SQueue alloc] init];
        
        _forVideo = forVideo;
        _enableStickers = enableStickers;
        
        _originalSize = originalSize;
        _cropRect = CGRectMake(0.0f, 0.0f, _originalSize.width, _originalSize.height);
        _paintingData = adjustments.paintingData;
        
        _tools = [self toolsInit];
        _toolComposer = [[PGPhotoToolComposer alloc] init];
        [_toolComposer addPhotoTools:_tools];
        [_toolComposer compose];

        _histogramPipe = [[SPipe alloc] init];
        
        __weak PGPhotoEditor *weakSelf = self;
        _histogramGenerator = [[PGPhotoHistogramGenerator alloc] init];
        _histogramGenerator.histogramReady = ^(PGPhotoHistogram *histogram)
        {
            __strong PGPhotoEditor *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;

            strongSelf->_currentHistogram = histogram;
            strongSelf->_histogramPipe.sink(histogram);
        };
        
        [self _importAdjustments:adjustments];
    }
    return self;
}

- (void)dealloc
{
    TGDispatchAfter(1.5f, dispatch_get_main_queue(), ^
    {
        [[GPUImageContext sharedFramebufferCache] purgeAllUnassignedFramebuffers];
    });
}

- (void)cleanup
{
    [[GPUImageContext sharedFramebufferCache] purgeAllUnassignedFramebuffers];
}

- (NSArray *)toolsInit
{
    NSMutableArray *tools = [NSMutableArray array];
    for (Class toolClass in [PGPhotoEditor availableTools])
    {
        PGPhotoTool *toolInstance = [[toolClass alloc] init];
        [tools addObject:toolInstance];
    }
    
    return tools;
}

- (void)setImage:(UIImage *)image forCropRect:(CGRect)cropRect cropRotation:(CGFloat)cropRotation cropOrientation:(UIImageOrientation)cropOrientation cropMirrored:(bool)cropMirrored fullSize:(bool)fullSize
{
    [_toolComposer invalidate];
    _currentProcessChain = nil;
    
    _imageCropRect = cropRect;
    _imageCropRotation = cropRotation;
    _imageCropOrientation = cropOrientation;
    _imageCropMirrored = cropMirrored;
    
    [_currentInput removeAllTargets];
    _currentInput = [[PGPhotoEditorPicture alloc] initWithImage:image];
    
    _histogramGenerator.imageSize = image.size;
    
    _fullSize = fullSize;
}

#pragma mark - Properties

- (CGSize)rotatedCropSize
{
    if (_cropOrientation == UIImageOrientationLeft || _cropOrientation == UIImageOrientationRight)
        return CGSizeMake(_cropRect.size.height, _cropRect.size.width);
    
    return _cropRect.size;
}

- (bool)hasDefaultCropping
{
    if (!_CGRectEqualToRectWithEpsilon(self.cropRect, CGRectMake(0, 0, _originalSize.width, _originalSize.height), 1.0f) || self.cropOrientation != UIImageOrientationUp || ABS(self.cropRotation) > FLT_EPSILON || self.cropMirrored)
    {
        return false;
    }
    
    return true;
}

#pragma mark - Processing

- (bool)readyForProcessing
{
    return (_currentInput != nil);
}

- (void)processAnimated:(bool)animated completion:(void (^)(void))completion
{
    [self processAnimated:animated capture:false synchronous:false completion:completion];
}

- (void)processAnimated:(bool)animated capture:(bool)capture synchronous:(bool)synchronous completion:(void (^)(void))completion
{
    if (self.previewOutput == nil)
        return;
    
    if (iosMajorVersion() < 7)
        animated = false;
    
    if (_processing && completion == nil)
    {
        _needsReprocessing = true;
        return;
    }
    
    _processing = true;
    
    [_queue dispatch:^
    {
        NSMutableArray *processChain = [NSMutableArray array];
        
        for (PGPhotoTool *tool in _toolComposer.advancedTools)
        {
            if (!tool.shouldBeSkipped && tool.pass != nil)
                [processChain addObject:tool.pass];
        }
        
        _toolComposer.imageSize = _cropRect.size;
        [processChain addObject:_toolComposer];
        
        TGPhotoEditorPreviewView *previewOutput = self.previewOutput;
        
        if (![_currentProcessChain isEqualToArray:processChain])
        {
            [_currentInput removeAllTargets];
            
            for (PGPhotoProcessPass *pass in _currentProcessChain)
                [pass.filter removeAllTargets];
            
            _currentProcessChain = processChain;
            
            GPUImageOutput <GPUImageInput> *lastFilter = ((PGPhotoProcessPass *)_currentProcessChain.firstObject).filter;
            [_currentInput addTarget:lastFilter];
            
            NSInteger chainLength = _currentProcessChain.count;
            if (chainLength > 1)
            {
                for (NSInteger i = 1; i < chainLength; i++)
                {
                    PGPhotoProcessPass *pass = ((PGPhotoProcessPass *)_currentProcessChain[i]);
                    GPUImageOutput <GPUImageInput> *filter = pass.filter;
                    [lastFilter addTarget:filter];
                    lastFilter = filter;
                }
            }
            _finalFilter = lastFilter;
            
            [_finalFilter addTarget:previewOutput.imageView];
            [_finalFilter addTarget:_histogramGenerator];
        }
                
        if (capture)
            [_finalFilter useNextFrameForImageCapture];
        
        for (PGPhotoProcessPass *pass in _currentProcessChain)
            [pass process];
        
        if (animated)
        {
            TGDispatchOnMainThread(^
            {
                [previewOutput prepareTransitionFadeView];
            });
        }
        
        [_currentInput processSynchronous:true completion:^
        {            
            if (completion != nil)
                completion();
            
            _processing = false;
             
            if (animated)
            {
                TGDispatchOnMainThread(^
                {
                    [previewOutput performTransitionFade];
                });
            }
            
            if (_needsReprocessing && !synchronous)
            {
                _needsReprocessing = false;
                [self processAnimated:false completion:nil];
            }
        }];
    } synchronous:synchronous];
}

#pragma mark - Result

- (void)createResultImageWithCompletion:(void (^)(UIImage *image))completion
{
    [self processAnimated:false capture:true synchronous:false completion:^
    {
        UIImage *image = [_finalFilter imageFromCurrentFramebufferWithOrientation:UIImageOrientationUp];
        
        if (completion != nil)
            completion(image);
    }];
}

- (UIImage *)currentResultImage
{
    __block UIImage *image = nil;
    [self processAnimated:false capture:true synchronous:true completion:^
    {
        image = [_finalFilter imageFromCurrentFramebufferWithOrientation:UIImageOrientationUp];
    }];
    return image;
}

#pragma mark - Editor Values

- (void)_importAdjustments:(id<TGMediaEditAdjustments>)adjustments
{
    _initialAdjustments = adjustments;
    
    if (adjustments != nil)
        self.cropRect = adjustments.cropRect;
    
    self.cropOrientation = adjustments.cropOrientation;
    self.cropLockedAspectRatio = adjustments.cropLockedAspectRatio;
    self.cropMirrored = adjustments.cropMirrored;
    self.paintingData = adjustments.paintingData;
    
    if ([adjustments isKindOfClass:[PGPhotoEditorValues class]])
    {
        PGPhotoEditorValues *editorValues = (PGPhotoEditorValues *)adjustments;

        self.cropRotation = editorValues.cropRotation;

        for (PGPhotoTool *tool in self.tools)
        {
            id value = editorValues.toolValues[tool.identifier];
            if (value != nil && [value isKindOfClass:[tool valueClass]])
                tool.value = [value copy];
        }
    }
    else if ([adjustments isKindOfClass:[TGVideoEditAdjustments class]])
    {
        TGVideoEditAdjustments *videoAdjustments = (TGVideoEditAdjustments *)adjustments;
        self.trimStartValue = videoAdjustments.trimStartValue;
        self.trimEndValue = videoAdjustments.trimEndValue;
        self.sendAsGif = videoAdjustments.sendAsGif;
        self.preset = videoAdjustments.preset;
    }
}

- (id<TGMediaEditAdjustments>)exportAdjustments
{
    return [self exportAdjustmentsWithPaintingData:_paintingData];
}

- (id<TGMediaEditAdjustments>)exportAdjustmentsWithPaintingData:(TGPaintingData *)paintingData
{
    if (!_forVideo)
    {
        NSMutableDictionary *toolValues = [[NSMutableDictionary alloc] init];
        for (PGPhotoTool *tool in self.tools)
        {
            if (!tool.shouldBeSkipped)
            {
                if (!([tool.value isKindOfClass:[NSNumber class]] && ABS([tool.value floatValue] - (float)tool.defaultValue) < FLT_EPSILON))
                    toolValues[tool.identifier] = [tool.value copy];
            }
        }
        
        return [PGPhotoEditorValues editorValuesWithOriginalSize:self.originalSize cropRect:self.cropRect cropRotation:self.cropRotation cropOrientation:self.cropOrientation cropLockedAspectRatio:self.cropLockedAspectRatio cropMirrored:self.cropMirrored toolValues:toolValues paintingData:paintingData sendAsGif:self.sendAsGif];
    }
    else
    {
        TGVideoEditAdjustments *initialAdjustments = (TGVideoEditAdjustments *)_initialAdjustments;
        
        return [TGVideoEditAdjustments editAdjustmentsWithOriginalSize:self.originalSize cropRect:self.cropRect cropOrientation:self.cropOrientation cropLockedAspectRatio:self.cropLockedAspectRatio cropMirrored:self.cropMirrored trimStartValue:initialAdjustments.trimStartValue trimEndValue:initialAdjustments.trimEndValue paintingData:paintingData sendAsGif:self.sendAsGif preset:self.preset];
    }
}

- (SSignal *)histogramSignal
{
    return [[SSignal single:_currentHistogram] then:_histogramPipe.signalProducer()];
}

+ (NSArray *)availableTools
{
    static NSArray *tools;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        tools = @[ [PGEnhanceTool class],
                   [PGExposureTool class],
                   [PGContrastTool class],
                   [PGSaturationTool class],
                   [PGWarmthTool class],
                   [PGFadeTool class],
                   [PGTintTool class],
                   [PGHighlightsTool class],
                   [PGShadowsTool class],
                   [PGVignetteTool class],
                   [PGGrainTool class],
                   [PGBlurTool class],
                   [PGSharpenTool class],
                   [PGCurvesTool class] ];
    });
    
    return tools;
}

@end
