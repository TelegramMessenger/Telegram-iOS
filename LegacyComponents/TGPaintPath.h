#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

@interface TGPaintPoint : NSObject

@property (nonatomic, assign) CGFloat x;
@property (nonatomic, assign) CGFloat y;
@property (nonatomic, assign) CGFloat z;

@property (nonatomic, assign) bool edge;

- (TGPaintPoint *)add:(TGPaintPoint *)point;
- (TGPaintPoint *)subtract:(TGPaintPoint *)point;
- (TGPaintPoint *)multiplyByScalar:(CGFloat)scalar;

- (CGFloat)distanceTo:(TGPaintPoint *)point;
- (TGPaintPoint *)normalize;

- (CGPoint)CGPoint;

+ (instancetype)pointWithX:(CGFloat)x y:(CGFloat)y z:(CGFloat)z;
+ (instancetype)pointWithCGPoint:(CGPoint)point z:(CGFloat)z;

@end


typedef enum
{
    TGPaintActionDraw,
    TGPaintActionErase
} TGPaintAction;

@class TGPaintBrush;

@interface TGPaintPath : NSObject

@property (nonatomic, strong) NSArray *points;

@property (nonatomic, strong) UIColor *color;
@property (nonatomic, assign) TGPaintAction action;
@property (nonatomic, assign) CGFloat baseWeight;
@property (nonatomic, strong) TGPaintBrush *brush;

@property (nonatomic, assign) CGFloat remainder;

- (instancetype)initWithPoint:(TGPaintPoint *)point;
- (instancetype)initWithPoints:(NSArray *)points;
- (void)addPoint:(TGPaintPoint *)point;

- (NSArray *)flattenedPoints;

@end

