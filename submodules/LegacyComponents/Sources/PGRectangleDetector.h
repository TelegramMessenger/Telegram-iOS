#import <UIKit/UIKit.h>

@interface PGRectangle : NSObject

@property (nonatomic, readonly) CGPoint topLeft;
@property (nonatomic, readonly) CGPoint topRight;
@property (nonatomic, readonly) CGPoint bottomLeft;
@property (nonatomic, readonly) CGPoint bottomRight;

- (PGRectangle *)transform:(CGAffineTransform)transform;
- (PGRectangle *)rotate90;
- (PGRectangle *)sort;
- (PGRectangle *)cartesian:(CGFloat)height;

@end

@interface PGRectangleDetector : NSObject

@property (nonatomic, copy) void(^update)(bool, PGRectangle *);

- (void)detectRectangle:(CVPixelBufferRef)pixelBuffer;

@end

