#import "TGCameraCapturedPhoto.h"
#import <SSignalKit/SSignalKit.h>
#import <LegacyComponents/TGImageUtils.h>
#import <LegacyComponents/TGPhotoEditorUtils.h>
#import <LegacyComponents/PGCameraShotMetadata.h>

@interface TGCameraCapturedPhoto ()
{
    NSString *_identifier;
    CGSize _dimensions;
    
    UIImage *_existingImage;
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
        _dimensions = CGSizeMake(image.size.width * image.scale, image.size.height * image.scale);
        _metadata = metadata;
        _thumbnail = [[SVariable alloc] init];
        
        [self _saveToDisk:image];
    }
    return self;
}

- (instancetype)initWithImage:(UIImage *)image rectangle:(PGRectangle *)rectangle
{
    self = [super init];
    if (self != nil)
    {
        _identifier = [NSString stringWithFormat:@"%ld", lrand48()];
        _dimensions = CGSizeMake(image.size.width * image.scale, image.size.height * image.scale);
        PGCameraShotMetadata *metadata = [[PGCameraShotMetadata alloc] init];
        metadata.rectangle = rectangle;
        _metadata = metadata;
        _thumbnail = [[SVariable alloc] init];
        
        [self _saveToDisk:image];
    }
    return self;
}

- (instancetype)initWithExistingImage:(UIImage *)image
{
    self = [super init];
    if (self != nil)
    {
        _identifier = [NSString stringWithFormat:@"%ld", lrand48()];
        _dimensions = CGSizeMake(image.size.width, image.size.height);
        _thumbnail = [[SVariable alloc] init];
        
        _existingImage = image;
        SSignal *thumbnailSignal = [[[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
        {
            CGFloat thumbnailImageSide = TGPhotoThumbnailSizeForCurrentScreen().width * TGScreenScaling();
            CGSize thumbnailSize = TGScaleToSize(image.size, CGSizeMake(thumbnailImageSide, thumbnailImageSide));
            UIImage *thumbnailImage = TGScaleImageToPixelSize(image, thumbnailSize);
            
            [subscriber putNext:thumbnailImage];
            [subscriber putCompletion];
            
            return nil;
        }] startOn:[SQueue concurrentDefaultQueue]];
        
        [_thumbnail set:thumbnailSignal];
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
    if (image == nil)
        return;
    
    TGWriteJPEGRepresentationToFile(image, 0.93f, [self filePath]);
    
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

- (PGRectangle *)rectangle
{
    return _metadata.rectangle;
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
    if (_existingImage != nil)
    {
        return [SSignal single:_existingImage];
    }
    else
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
}

- (SSignal *)originalImageSignal:(NSTimeInterval)__unused position
{
    if (_existingImage != nil)
    {
        return [SSignal single:_existingImage];
    }
    else
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
}

@end
