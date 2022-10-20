#import <UIKit/UIKit.h>
#import <SSignalKit/SSignalKit.h>

@protocol TGMediaEditableItem;
@class TGMediaEditingContext;

@interface TGPaintFaceFeature : NSObject
{
    CGPoint _position;
}

@property (nonatomic, readonly) CGPoint position;

@end


@interface TGPaintFaceEye : TGPaintFaceFeature

@property (nonatomic, readonly, getter=isClosed) bool closed;

@end


@interface TGPaintFaceMouth : TGPaintFaceFeature

@property (nonatomic, readonly, getter=isSmiling) bool smiling;

@end


@interface TGPaintFace : NSObject

@property (nonatomic, readonly) NSInteger uuid;

@property (nonatomic, readonly) CGRect bounds;
@property (nonatomic, readonly) CGFloat angle;

@property (nonatomic, readonly) TGPaintFaceEye *leftEye;
@property (nonatomic, readonly) TGPaintFaceEye *rightEye;
@property (nonatomic, readonly) TGPaintFaceMouth *mouth;

- (CGPoint)foreheadPoint;
- (CGPoint)eyesCenterPointAndDistance:(CGFloat *)distance;
- (CGFloat)eyesAngle;
- (CGPoint)mouthPoint;
- (CGPoint)chinPoint;

@end


@interface TGPaintFaceDetector : NSObject

+ (SSignal *)detectFacesInImage:(UIImage *)image originalSize:(CGSize)originalSize;

+ (SSignal *)detectFacesInItem:(id<TGMediaEditableItem>)item editingContext:(TGMediaEditingContext *)editingContext;

@end


@interface TGPaintFaceUtils : NSObject

+ (CGFloat)transposeWidth:(CGFloat)width paintingSize:(CGSize)paintingSize originalSize:(CGSize)originalSize;
+ (CGPoint)transposePoint:(CGPoint)point paintingSize:(CGSize)paintingSize originalSize:(CGSize)originalSize;
+ (CGRect)transposeRect:(CGRect)rect paintingSize:(CGSize)paintingSize originalSize:(CGSize)originalSize;

@end
