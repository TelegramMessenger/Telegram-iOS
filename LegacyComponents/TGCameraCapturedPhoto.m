#import "TGCameraCapturedPhoto.h"
#import <SSignalKit/SSignalKit.h>
#import <LegacyComponents/TGImageUtils.h>
#import <LegacyComponents/TGPhotoEditorUtils.h>
#import <LegacyComponents/PGCameraShotMetadata.h>

@interface TGCameraCapturedPhoto ()
{
    NSString *_identifier;
    CGSize _dimensions;
    
    SVariable *_thumbnail;
    UIImage *_thumbImage;
}
@end

@implementation TGCameraCapturedPhoto

- (instancetype)initWithImage:(UIImage *)image metadata:(PGCameraShotMetadata *)metadata
{
    self = [super init];
    if (self != nil)
    {
        _identifier = [NSString stringWithFormat:@"%ld", lrand48()];
        _dimensions = image.size;
        _metadata = metadata;
        _thumbnail = [[SVariable alloc] init];
        
        [self _saveToDisk:image];
    }
    return self;
}

- (void)_cleanUp
{
    [[NSFileManager defaultManager] removeItemAtPath:[self filePath] error:nil];
}

#define PGTick   NSDate *startTime = [NSDate date]
#define PGTock   NSLog(@"!=========== %s Time: %f", __func__, -[startTime timeIntervalSinceNow])

- (void)_saveToDisk:(UIImage *)image
{
    NSData *data = UIImageJPEGRepresentation(image, 0.93f);
    [data writeToFile:[self filePath] atomically:true];
    
    CGFloat thumbnailImageSide = TGPhotoThumbnailSizeForCurrentScreen().width;
    CGSize size = TGScaleToSize(image.size, CGSizeMake(thumbnailImageSide, thumbnailImageSide));
    SSignal *thumbnailSignal = [[[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        CGImageSourceRef imageSource = CGImageSourceCreateWithURL((CFURLRef)[NSURL fileURLWithPath:[self filePath]], NULL);
        if (imageSource == NULL)
        {
            [subscriber putError:nil];
            return nil;
        }
        
        CGImageRef imageRef = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, (__bridge CFDictionaryRef)@
        {
            (id)kCGImageSourceShouldAllowFloat : (id)kCFBooleanTrue,
            (id)kCGImageSourceCreateThumbnailWithTransform : (id)kCFBooleanFalse,
            (id)kCGImageSourceCreateThumbnailFromImageIfAbsent : (id)kCFBooleanTrue,
            (id)kCGImageSourceThumbnailMaxPixelSize : @(MAX(size.width, size.height) * TGScreenScaling())
        });
    
        UIImage *image = [UIImage imageWithCGImage:imageRef];
        CGImageRelease(imageRef);
        CFRelease(imageSource);
        
        [subscriber putNext:image];
        [subscriber putCompletion];

        return nil;
    }] startOn:[SQueue concurrentDefaultQueue]];
    
    [_thumbnail set:thumbnailSignal];
}

- (NSString *)filePath
{
    return [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSString alloc] initWithFormat:@"camphoto_%@.jpg", _identifier]];
}

- (NSURL *)url
{
    return [NSURL fileURLWithPath:[self filePath]];
}

- (bool)isVideo
{
    return false;
}

- (NSString *)uniqueIdentifier
{
    return _identifier;
}

- (CGSize)originalSize
{
    return _dimensions;
}

- (SSignal *)thumbnailImageSignal
{
    return _thumbnail.signal;
}

- (SSignal *)screenImageSignal:(NSTimeInterval)__unused position
{
    return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        CGImageSourceRef imageSource = CGImageSourceCreateWithURL((CFURLRef)[NSURL fileURLWithPath:[self filePath]], NULL);
        if (imageSource == NULL)
        {
            [subscriber putError:nil];
            return nil;
        }
    
        CGImageRef imageRef = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, (__bridge CFDictionaryRef)@
        {
            (id)kCGImageSourceShouldAllowFloat : (id)kCFBooleanTrue,
            (id)kCGImageSourceCreateThumbnailWithTransform : (id)kCFBooleanFalse,
            (id)kCGImageSourceCreateThumbnailFromImageIfAbsent : (id)kCFBooleanTrue,
            (id)kCGImageSourceThumbnailMaxPixelSize : @(1600)
        });
        if (imageRef == NULL)
            imageRef = CGImageSourceCreateImageAtIndex(imageSource, 0, nil);
        
        UIImage *image = [UIImage imageWithCGImage:imageRef];
        CGImageRelease(imageRef);
        CFRelease(imageSource);
        
        [subscriber putNext:image];
        [subscriber putCompletion];
        
        return nil;
    }];
}

- (SSignal *)originalImageSignal:(NSTimeInterval)__unused position
{
    return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        NSData *data = [[NSData alloc] initWithContentsOfFile:[self filePath] options:NSDataReadingMappedIfSafe error:NULL];
        if (data.length == 0)
        {
            [subscriber putError:nil];
            return nil;
        }
        
        UIImage *image = [[UIImage alloc] initWithData:data];
        if (image == nil)
        {
            [subscriber putError:nil];
            return nil;
        }
        
        [subscriber putNext:image];
        [subscriber putCompletion];
        
        return nil;
    }];
}

@end
