#import "TGPaintFaceDebugView.h"

#import "LegacyComponentsInternal.h"

#import "TGPaintFaceDetector.h"

@interface TGPaintFaceView : UIView

- (instancetype)initWithFace:(TGPaintFace *)face paintingSize:(CGSize)paintingSize originalSize:(CGSize)originalSize;

@end

@implementation TGPaintFaceDebugView

- (void)setFaces:(NSArray *)faces paintingSize:(CGSize)paintingSize originalSize:(CGSize)originalSize
{
    self.backgroundColor = UIColorRGBA(0x00ff00, 0.2f);
    
    for (UIView *view in self.subviews)
        [view removeFromSuperview];
    
    for (TGPaintFace *face in faces)
    {
        TGPaintFaceView *view = [[TGPaintFaceView alloc] initWithFace:face paintingSize:paintingSize originalSize:originalSize];
        [self addSubview:view];
    }
}

@end


@implementation TGPaintFaceView

- (instancetype)initWithFace:(TGPaintFace *)face paintingSize:(CGSize)paintingSize originalSize:(CGSize)originalSize
{
    CGRect bounds = [TGPaintFaceUtils transposeRect:face.bounds paintingSize:paintingSize originalSize:originalSize];
    self = [super initWithFrame:bounds];
    if (self != nil)
    {
        UIView *background = [[UIView alloc] initWithFrame:self.bounds];
        background.backgroundColor = UIColorRGBA(0xff0000, 0.4f);
        [self addSubview:background];
        
        void (^createViewForFeature)(TGPaintFaceFeature *) = ^(TGPaintFaceFeature *feature)
        {
            if (feature == nil)
                return;
            
            CGPoint position = [TGPaintFaceUtils transposePoint:feature.position paintingSize:paintingSize originalSize:originalSize];
            
            UIView *view = [[UIView alloc] initWithFrame:CGRectMake(position.x - 10.0f - self.frame.origin.x, position.y - 10.0f - self.frame.origin.y, 20, 20)];
            view.backgroundColor = UIColorRGBA(0x0000ff, 0.5f);
            [self addSubview:view];
        };
        
        createViewForFeature(face.leftEye);
        createViewForFeature(face.rightEye);
        createViewForFeature(face.mouth);
        
        background.transform = CGAffineTransformMakeRotation(face.angle);
    }
    return self;
}

@end
