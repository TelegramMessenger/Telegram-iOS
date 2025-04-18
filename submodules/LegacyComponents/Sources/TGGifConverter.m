#import <LegacyComponents/TGGifConverter.h>

#import "LegacyComponentsInternal.h"
#import "TGImageUtils.h"

#import <UIKit/UIKit.h>
#import <ImageIO/ImageIO.h>
#import <AVFoundation/AVFoundation.h>
#import <MobileCoreServices/MobileCoreServices.h>

const int32_t TGGifConverterFPS = 600;
const CGFloat TGGifConverterMaximumSide = 720.0f;

@implementation TGGifConverter

+ (SSignal *)convertGifToMp4:(NSData *)data
{
    return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        __block bool cancelled = false;
        SAtomic *assetWriterRef = [[SAtomic alloc] initWithValue:nil];
        
        [[SQueue concurrentDefaultQueue] dispatch:^
        {
            CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)data, NULL);
            unsigned char *bytes = (unsigned char *)data.bytes;
            NSError* error = nil;
            
            if (CGImageSourceGetStatus(source) != kCGImageStatusComplete)
            {
                CFRelease(source);
                [subscriber putError:nil];
                return;
            }
            
            size_t sourceWidth = bytes[6] + (bytes[7]<<8), sourceHeight = bytes[8] + (bytes[9]<<8);
            __block size_t currentFrameNumber = 0;
            __block Float64 totalFrameDelay = 0.f;
                
            NSString *uuidString = nil;
            {
                CFUUIDRef uuid = CFUUIDCreate(kCFAllocatorDefault);
                uuidString = (__bridge_transfer NSString *)CFUUIDCreateString(kCFAllocatorDefault, uuid);
                CFRelease(uuid);
            }
            
            NSURL *outFilePath = [[NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:true] URLByAppendingPathComponent:[uuidString stringByAppendingPathExtension:@"mp4"]];
            
            AVAssetWriter *videoWriter = [[AVAssetWriter alloc] initWithURL:outFilePath fileType:AVFileTypeMPEG4 error:&error];
            [assetWriterRef swap:videoWriter];
            if (error != nil)
            {
                CFRelease(source);
                [subscriber putError:nil];
                return;
            }
            
            if (sourceWidth > 1600 || sourceWidth == 0)
            {
                CFRelease(source);
                [subscriber putError:nil];
                return;
            }
            
            if (sourceHeight > 1600 || sourceHeight == 0)
            {
                CFRelease(source);
                [subscriber putError:nil];
                return;
            }
            
            size_t totalFrameCount = CGImageSourceGetCount(source);
            if (totalFrameCount < 2)
            {
                CFRelease(source);
                [subscriber putError:nil];
                return;
            }
            
            const CGFloat blockSize = 16.0f;
            CGFloat renderWidth = CGFloor(sourceWidth / blockSize) * blockSize;
            CGFloat renderHeight = CGFloor(sourceHeight * renderWidth / sourceWidth);
            
            CGSize renderSize = CGSizeMake(renderWidth, renderHeight);
            CGSize targetSize = TGFitSizeF(CGSizeMake(renderWidth, renderHeight), CGSizeMake(TGGifConverterMaximumSide, TGGifConverterMaximumSide));
            
            NSDictionary *videoCleanApertureSettings = @
            {
              AVVideoCleanApertureWidthKey: @((NSInteger)targetSize.width),
              AVVideoCleanApertureHeightKey: @((NSInteger)targetSize.height),
              AVVideoCleanApertureHorizontalOffsetKey: @10,
              AVVideoCleanApertureVerticalOffsetKey: @10
            };
            
            NSDictionary *videoAspectRatioSettings = @
            {
              AVVideoPixelAspectRatioHorizontalSpacingKey: @3,
              AVVideoPixelAspectRatioVerticalSpacingKey: @3
            };
            
            NSDictionary *codecSettings = @
            {
              AVVideoAverageBitRateKey: @(500000),
              AVVideoCleanApertureKey: videoCleanApertureSettings,
              AVVideoPixelAspectRatioKey: videoAspectRatioSettings
            };
            
            NSDictionary *videoSettings = @
            {
                AVVideoCodecKey : AVVideoCodecH264,
                AVVideoCompressionPropertiesKey: codecSettings,
                AVVideoWidthKey : @((NSInteger)targetSize.width),
                AVVideoHeightKey : @((NSInteger)targetSize.height)
            };
            
            AVAssetWriterInput *videoWriterInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:videoSettings];
            videoWriterInput.expectsMediaDataInRealTime = true;
            
            if (![videoWriter canAddInput:videoWriterInput])
            {
                CFRelease(source);
                [subscriber putError:nil];
                return;
            }
            [videoWriter addInput:videoWriterInput];
            
            NSDictionary *attributes = @
            {
                (NSString *)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32ARGB),
                (NSString *)kCVPixelBufferWidthKey : @(renderWidth),
                (NSString *)kCVPixelBufferHeightKey : @(renderHeight),
                (NSString *)kCVPixelBufferCGImageCompatibilityKey : @YES,
                (NSString *)kCVPixelBufferCGBitmapContextCompatibilityKey : @YES
            };
            
            AVAssetWriterInputPixelBufferAdaptor *adaptor = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:videoWriterInput sourcePixelBufferAttributes:attributes];
            
            [videoWriter startWriting];
            [videoWriter startSessionAtSourceTime:CMTimeMakeWithSeconds(totalFrameDelay, TGGifConverterFPS)];
            
            __block UIImage *previewImage = nil;
            
            while (!cancelled)
            {
                if (videoWriterInput.isReadyForMoreMediaData)
                {
                    NSDictionary *options = @{ (NSString *)kCGImageSourceTypeIdentifierHint : (id)kUTTypeGIF };
                    CGImageRef imgRef = CGImageSourceCreateImageAtIndex(source, currentFrameNumber, (__bridge CFDictionaryRef)options);
                    if (imgRef != NULL)
                    {
                        CFDictionaryRef properties = CGImageSourceCopyPropertiesAtIndex(source, currentFrameNumber, NULL);
                        CFDictionaryRef gifProperties = CFDictionaryGetValue(properties, kCGImagePropertyGIFDictionary);
                        
                        if (gifProperties != NULL)
                        {
                            CVPixelBufferRef pxBuffer = [self newBufferFrom:imgRef size:renderSize withPixelBufferPool:adaptor.pixelBufferPool andAttributes:adaptor.sourcePixelBufferAttributes];
                            if (pxBuffer != NULL)
                            {
                                if (previewImage == nil) {
                                    previewImage = TGScaleImageToPixelSize([[UIImage alloc] initWithCGImage:imgRef], renderSize);
                                }
                                float frameDuration = 0.1f;
                                NSNumber *delayTimeUnclampedProp = CFDictionaryGetValue(gifProperties, kCGImagePropertyGIFUnclampedDelayTime);
                                if (delayTimeUnclampedProp != nil)
                                {
                                    frameDuration = [delayTimeUnclampedProp floatValue];
                                }
                                else
                                {
                                    NSNumber *delayTimeProp = CFDictionaryGetValue(gifProperties, kCGImagePropertyGIFDelayTime);
                                    if (delayTimeProp != nil)
                                        frameDuration = [delayTimeProp floatValue];
                                }
                                
                                if (frameDuration < 0.011f)
                                    frameDuration = 0.100f;
                                
                                CMTime time = CMTimeMakeWithSeconds(totalFrameDelay, TGGifConverterFPS);
                                totalFrameDelay += frameDuration;
                                
                                if (![adaptor appendPixelBuffer:pxBuffer withPresentationTime:time])
                                {
                                    TGLegacyLog(@"Could not save pixel buffer!: %@", videoWriter.error);
                                    CFRelease(properties);
                                    CGImageRelease(imgRef);
                                    CVBufferRelease(pxBuffer);
                                    break;
                                }
                                
                                CVBufferRelease(pxBuffer);
                            }
                        }
                        
                        if (properties)
                            CFRelease(properties);
                        CGImageRelease(imgRef);
                        
                        currentFrameNumber++;
                    }
                    else
                    {
                        //was no image returned -> end of file?
                        [videoWriterInput markAsFinished];
                        
                        [videoWriter finishWritingWithCompletionHandler:^
                        {
                            NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
                            if ([outFilePath path] != nil) {
                                dict[@"path"] = [outFilePath path];
                            }
                            dict[@"dimensions"] = [NSValue valueWithCGSize:targetSize];
                            dict[@"duration"] = @((double)totalFrameDelay);
                            if (previewImage != nil) {
                                dict[@"previewImage"] = previewImage;
                            }
                            [subscriber putNext:dict];
                            [subscriber putCompletion];
                        }];
                        break;
                    }
                }
                else
                {
                    [NSThread sleepForTimeInterval:0.1];
                }
            };
            
            CFRelease(source);
        }];
        
        return [[SBlockDisposable alloc] initWithBlock:^
        {
            cancelled = true;
            [assetWriterRef swap:nil];
        }];
    }];
};

+ (CVPixelBufferRef)newBufferFrom:(CGImageRef)frame size:(CGSize)size withPixelBufferPool:(CVPixelBufferPoolRef)pixelBufferPool andAttributes:(NSDictionary *)attributes
{
    NSParameterAssert(frame);
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    CVPixelBufferRef pxBuffer = NULL;
    CVReturn status = kCVReturnSuccess;
    
    if (pixelBufferPool)
        status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pixelBufferPool, &pxBuffer);
    else
        status = CVPixelBufferCreate(kCFAllocatorDefault, size.width, size.height, kCVPixelFormatType_32ARGB, (__bridge CFDictionaryRef)attributes, &pxBuffer);

    NSAssert(status == kCVReturnSuccess, @"Could not create a pixel buffer");
    
    CVPixelBufferLockBaseAddress(pxBuffer, 0);
    void *pxData = CVPixelBufferGetBaseAddress(pxBuffer);
    
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(pxBuffer);
    
    CGContextRef context = CGBitmapContextCreate(pxData, size.width, size.height, 8, bytesPerRow, colorSpace, kCGImageAlphaNoneSkipFirst);
    NSAssert(context, @"Could not create a context");
    
    CGContextDrawImage(context, CGRectMake(0, 0, size.width, size.height), frame);
    
    CVPixelBufferUnlockBaseAddress(pxBuffer, 0);
    
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    
    return pxBuffer;
}

@end
