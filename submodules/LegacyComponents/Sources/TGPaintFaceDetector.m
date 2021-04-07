#import "TGPaintFaceDetector.h"
#import <LegacyComponents/TGPhotoEditorUtils.h>
#import <LegacyComponents/TGPaintUtils.h>
#import <ImageIO/ImageIO.h>

#import "TGMediaEditingContext.h"
#import "UIImage+TG.h"

@interface TGPaintFace ()

+ (instancetype)faceWithBounds:(CGRect)bounds angle:(CGFloat)angle leftEye:(TGPaintFaceEye *)leftEye rightEye:(TGPaintFaceEye *)rightEye mouth:(TGPaintFaceMouth *)mouth;

@end


@interface TGPaintFaceEye ()

+ (instancetype)eyeWithPosition:(CGPoint)position closed:(bool)closed;

@end


@interface TGPaintFaceMouth ()

+ (instancetype)mouthWithPosition:(CGPoint)position smiling:(bool)smiling;

@end


@implementation TGPaintFaceDetector

+ (SSignal *)detectFacesInItem:(id<TGMediaEditableItem>)item editingContext:(TGMediaEditingContext *)editingContext
{
    CGSize originalSize = item.originalSize;
        
    SSignal *cachedFaces = [editingContext facesForItem:item];
    SSignal *cachedSignal = [cachedFaces mapToSignal:^SSignal *(id result)
    {
        if (result == nil)
            return [SSignal fail:nil];
        return [SSignal single:result];
    }];
    
    SSignal *imageSignal = [item screenImageSignal:0];
    SSignal *detectSignal = [[[imageSignal filter:^bool(UIImage *image)
                               {
        if (![image isKindOfClass:[UIImage class]])
            return false;
        
        if (image.degraded)
            return false;
        
        return true;
    }] take:1] mapToSignal:^SSignal *(UIImage *image) {
        return [[TGPaintFaceDetector detectFacesInImage:image originalSize:originalSize] startOn:[SQueue concurrentDefaultQueue]];
    }];
    
    return [[[cachedSignal catch:^SSignal *(__unused id error)
       {
        return detectSignal;
    }] deliverOn:[SQueue mainQueue]] onNext:^(NSArray *next)
     {
        [editingContext setFaces:next forItem:item];
    }];
}

+ (SSignal *)detectFacesInImage:(UIImage *)image originalSize:(CGSize)originalSize
{
    return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        NSDictionary *options = @
        {
            CIDetectorAccuracy: CIDetectorAccuracyHigh,
            CIDetectorMinFeatureSize : @(0.175)
        };
        
        CIDetector *detector = [CIDetector detectorOfType:CIDetectorTypeFace context:nil options:options];
        
        CIImage *ciImage = [[CIImage imageWithCGImage:image.CGImage] imageByApplyingOrientation:[self tiffOrientationFromImageOrientation:image.imageOrientation]];
        
        NSMutableArray *result = [[NSMutableArray alloc] init];
        NSArray *features = [detector featuresInImage:ciImage];
        for (CIFaceFeature *feature in features)
        {
            if (![feature isKindOfClass:[CIFaceFeature class]])
                continue;
            
            TGPaintFace *face = [self _paintFaceForFaceFeature:feature initialSize:image.size targetSize:originalSize];
            if (face != nil)
                [result addObject:face];
        }
        
        [subscriber putNext:result];
        [subscriber putCompletion];
        
        return nil;
    }];
}

+ (int)tiffOrientationFromImageOrientation:(UIImageOrientation)orientation
{
    switch (orientation)
    {
        case UIImageOrientationUp:
            return 1;
            
        case UIImageOrientationDown:
            return 3;
            
        case UIImageOrientationLeft:
            return 8;
            
        case UIImageOrientationRight:
            return 6;
            
        case UIImageOrientationUpMirrored:
            return 2;
            
        case UIImageOrientationDownMirrored:
            return 4;
            
        case UIImageOrientationLeftMirrored:
            return 5;
            
        case UIImageOrientationRightMirrored:
            return 7;
            
        default:
            return 0;
    }
}

+ (TGPaintFace *)_paintFaceForFaceFeature:(CIFaceFeature *)faceFeature initialSize:(CGSize)initialSize targetSize:(CGSize)targetSize
{
    if (faceFeature == nil)
        return nil;
    
    if (!faceFeature.hasLeftEyePosition || !faceFeature.hasRightEyePosition)
        return nil;
    
    TGPaintFaceEye *leftEye = [TGPaintFaceEye eyeWithPosition:[self _transposedPoint:faceFeature.leftEyePosition initialSize:initialSize targetSize:targetSize] closed:faceFeature.leftEyeClosed];
    TGPaintFaceEye *rightEye = [TGPaintFaceEye eyeWithPosition:[self _transposedPoint:faceFeature.rightEyePosition initialSize:initialSize targetSize:targetSize] closed:faceFeature.rightEyeClosed];
    
    TGPaintFaceMouth *mouth = nil;
    
    if (faceFeature.hasMouthPosition)
        mouth = [TGPaintFaceMouth mouthWithPosition:[self _transposedPoint:faceFeature.mouthPosition initialSize:initialSize targetSize:targetSize] smiling:faceFeature.hasSmile];
    
    return [TGPaintFace faceWithBounds:[self _transposedRect:faceFeature.bounds initialSize:initialSize targetSize:targetSize] angle:[self _transposedAngle:TGDegreesToRadians(faceFeature.faceAngle)] leftEye:leftEye rightEye:rightEye mouth:mouth];
}

+ (CGFloat)_transposedAngle:(CGFloat)angle
{
    return angle;
}

+ (CGRect)_transposedRect:(CGRect)rect initialSize:(CGSize)initialSize targetSize:(CGSize)targetSize
{
    return CGRectMake(targetSize.width * rect.origin.x / initialSize.width, targetSize.height * (initialSize.height - rect.origin.y - rect.size.height) / initialSize.height, targetSize.width * rect.size.width / initialSize.width, targetSize.height * rect.size.height / initialSize.height);
}

+ (CGPoint)_transposedPoint:(CGPoint)point initialSize:(CGSize)initialSize targetSize:(CGSize)targetSize
{
    return CGPointMake(targetSize.width * point.x / initialSize.width, targetSize.height - targetSize.height * point.y / initialSize.height);
}

@end


@implementation TGPaintFace

+ (instancetype)faceWithBounds:(CGRect)bounds angle:(CGFloat)angle leftEye:(TGPaintFaceEye *)leftEye rightEye:(TGPaintFaceEye *)rightEye mouth:(TGPaintFaceMouth *)mouth
{
    TGPaintFace *face = [[TGPaintFace alloc] init];
    arc4random_buf(&face->_uuid, sizeof(NSInteger));
    face->_bounds = bounds;
    face->_angle = angle;
    face->_leftEye = leftEye;
    face->_rightEye = rightEye;
    face->_mouth = mouth;
    return face;
}

- (CGPoint)foreheadPoint
{
    CGFloat halfFace = _bounds.size.height / 2.0f;
    CGPoint point = TGPaintCenterOfRect(_bounds);
    
    return CGPointMake(point.x + halfFace * cos(_angle - M_PI_2), point.y + halfFace * sin(_angle - M_PI_2));
}

- (CGPoint)eyesCenterPointAndDistance:(CGFloat *)distance
{
    CGPoint point = CGPointMake(0.5f * _leftEye.position.x + 0.5f * _rightEye.position.x, 0.5f * _leftEye.position.y + 0.5f * _rightEye.position.y);
    CGFloat dist = sqrt(pow(_rightEye.position.x - _leftEye.position.x, 2) + pow(_rightEye.position.y - _leftEye.position.y, 2));

    if (distance != NULL)
        *distance = dist;
    
    return point;
}

- (CGFloat)eyesAngle
{
    return atan2(_rightEye.position.y - _leftEye.position.y, _rightEye.position.x - _leftEye.position.x);
}

- (CGPoint)mouthPoint
{
    return _mouth.position;
}

- (CGPoint)chinPoint
{
    CGFloat halfFace = _bounds.size.height / 2.0f;
    CGPoint point = TGPaintCenterOfRect(_bounds);
    
    return CGPointMake(point.x + halfFace * cos(_angle + M_PI_2), point.y + halfFace * sin(_angle + M_PI_2));
}

@end


@implementation TGPaintFaceFeature

@end


@implementation TGPaintFaceEye

+ (instancetype)eyeWithPosition:(CGPoint)position closed:(bool)closed
{
    TGPaintFaceEye *eye = [[TGPaintFaceEye alloc] init];
    eye->_position = position;
    eye->_closed = closed;
    return eye;
}

@end


@implementation TGPaintFaceMouth

+ (instancetype)mouthWithPosition:(CGPoint)position smiling:(bool)smiling
{
    TGPaintFaceMouth *mouth = [[TGPaintFaceMouth alloc] init];
    mouth->_position = position;
    mouth->_smiling = smiling;
    return mouth;
}

@end


@implementation TGPaintFaceUtils

+ (CGFloat)transposeWidth:(CGFloat)width paintingSize:(CGSize)paintingSize originalSize:(CGSize)originalSize
{
    return width * paintingSize.width / originalSize.width;
}

+ (CGPoint)transposePoint:(CGPoint)point paintingSize:(CGSize)paintingSize originalSize:(CGSize)originalSize
{
    return CGPointMake(point.x * paintingSize.width / originalSize.width, point.y * paintingSize.height / originalSize.height);
}

+ (CGRect)transposeRect:(CGRect)rect paintingSize:(CGSize)paintingSize originalSize:(CGSize)originalSize
{
    CGPoint origin = [self transposePoint:rect.origin paintingSize:paintingSize originalSize:originalSize];
    CGSize size = CGSizeMake(rect.size.width * paintingSize.width / originalSize.width, rect.size.height * paintingSize.height / originalSize.height);
    
    return (CGRect){ origin, size };
}

@end
