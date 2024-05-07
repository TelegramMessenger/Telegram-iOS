#ifndef LottieRenderTree_h
#define LottieRenderTree_h

#import <QuartzCore/QuartzCore.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef NS_ENUM(NSUInteger, LottiePathItemType) {
    LottiePathItemTypeMoveTo,
    LottiePathItemTypeLineTo,
    LottiePathItemTypeCurveTo,
    LottiePathItemTypeClose
};

typedef struct {
    LottiePathItemType type;
    CGPoint points[4];
} LottiePathItem;

typedef struct {
    CGFloat r;
    CGFloat g;
    CGFloat b;
    CGFloat a;
} LottieColor;

typedef NS_ENUM(NSUInteger, LottieFillRule) {
    LottieFillRuleEvenOdd,
    LottieFillRuleWinding
};

typedef NS_ENUM(NSUInteger, LottieGradientType) {
    LottieGradientTypeLinear,
    LottieGradientTypeRadial
};

@interface LottieColorStop : NSObject

@property (nonatomic, readonly, direct) LottieColor color;
@property (nonatomic, readonly, direct) CGFloat location;

- (instancetype _Nonnull)init NS_UNAVAILABLE;
- (instancetype _Nonnull)initWithColor:(LottieColor)color location:(CGFloat)location __attribute__((objc_direct));

@end

@interface LottiePath : NSObject

- (void)enumerateItems:(void (^ _Nonnull)(LottiePathItem * _Nonnull))iterate __attribute__((objc_direct));

- (instancetype _Nonnull)init NS_UNAVAILABLE;
- (instancetype _Nonnull)initWithCustomData:(NSData * _Nonnull)customData __attribute__((objc_direct));

@end

@interface LottieRenderContentShading : NSObject

@end

@interface LottieRenderContentSolidShading : LottieRenderContentShading

@property (nonatomic, readonly, direct) LottieColor color;
@property (nonatomic, readonly, direct) CGFloat opacity;

- (instancetype _Nonnull)init NS_UNAVAILABLE;
- (instancetype _Nonnull)initWithColor:(LottieColor)color opacity:(CGFloat)opacity __attribute__((objc_direct));

@end

@interface LottieRenderContentGradientShading : LottieRenderContentShading

@property (nonatomic, readonly, direct) CGFloat opacity;
@property (nonatomic, readonly, direct) LottieGradientType gradientType;
@property (nonatomic, strong, readonly, direct) NSArray<LottieColorStop *> * _Nonnull colorStops;
@property (nonatomic, readonly, direct) CGPoint start;
@property (nonatomic, readonly, direct) CGPoint end;

- (instancetype _Nonnull)init NS_UNAVAILABLE;
- (instancetype _Nonnull)initWithOpacity:(CGFloat)opacity gradientType:(LottieGradientType)gradientType colorStops:(NSArray<LottieColorStop *> * _Nonnull)colorStops start:(CGPoint)start end:(CGPoint)end __attribute__((objc_direct));

@end

@interface LottieRenderContentFill : NSObject

@property (nonatomic, strong, readonly, direct) LottieRenderContentShading * _Nonnull shading;
@property (nonatomic, readonly, direct) LottieFillRule fillRule;

- (instancetype _Nonnull)init NS_UNAVAILABLE;
- (instancetype _Nonnull)initWithShading:(LottieRenderContentShading * _Nonnull)shading fillRule:(LottieFillRule)fillRule __attribute__((objc_direct));

@end

@interface LottieRenderContentStroke : NSObject

@property (nonatomic, strong, readonly, direct) LottieRenderContentShading * _Nonnull shading;
@property (nonatomic, readonly, direct) CGFloat lineWidth;
@property (nonatomic, readonly, direct) CGLineJoin lineJoin;
@property (nonatomic, readonly, direct) CGLineCap lineCap;
@property (nonatomic, readonly, direct) CGFloat miterLimit;
@property (nonatomic, readonly, direct) CGFloat dashPhase;
@property (nonatomic, strong, readonly, direct) NSArray<NSNumber *> * _Nullable dashPattern;

- (instancetype _Nonnull)init NS_UNAVAILABLE;
- (instancetype _Nonnull)initWithShading:(LottieRenderContentShading * _Nonnull)shading lineWidth:(CGFloat)lineWidth lineJoin:(CGLineJoin)lineJoin lineCap:(CGLineCap)lineCap miterLimit:(CGFloat)miterLimit dashPhase:(CGFloat)dashPhase dashPattern:(NSArray<NSNumber *> * _Nullable)dashPattern __attribute__((objc_direct));

@end

@interface LottieRenderContent : NSObject

@property (nonatomic, strong, readonly, direct) LottiePath * _Nonnull path;
@property (nonatomic, strong, readonly, direct) LottieRenderContentStroke * _Nullable stroke;
@property (nonatomic, strong, readonly, direct) LottieRenderContentFill * _Nullable fill;

- (instancetype _Nonnull)init NS_UNAVAILABLE;
- (instancetype _Nonnull)initWithPath:(LottiePath * _Nonnull)path stroke:(LottieRenderContentStroke * _Nullable)stroke fill:(LottieRenderContentFill * _Nullable)fill __attribute__((objc_direct));

@end

@interface LottieRenderNode : NSObject

@property (nonatomic, readonly, direct) CGPoint position;
@property (nonatomic, readonly, direct) CGRect bounds;
@property (nonatomic, readonly, direct) CATransform3D transform;
@property (nonatomic, readonly, direct) CGFloat opacity;
@property (nonatomic, readonly, direct) bool masksToBounds;
@property (nonatomic, readonly, direct) bool isHidden;

@property (nonatomic, readonly, direct) CGRect globalRect;
@property (nonatomic, readonly, direct) CATransform3D globalTransform;
@property (nonatomic, readonly, direct) LottieRenderContent * _Nullable renderContent;
@property (nonatomic, readonly, direct) bool hasSimpleContents;
@property (nonatomic, readonly, direct) bool isInvertedMatte;
@property (nonatomic, readonly, direct) NSArray<LottieRenderNode *> * _Nonnull subnodes;
@property (nonatomic, readonly, direct) LottieRenderNode * _Nullable mask;

- (instancetype _Nonnull)init NS_UNAVAILABLE;
- (instancetype _Nonnull)initWithPosition:(CGPoint)position bounds:(CGRect)bounds transform:(CATransform3D)transform opacity:(CGFloat)opacity masksToBounds:(bool)masksToBounds isHidden:(bool)isHidden globalRect:(CGRect)globalRect globalTransform:(CATransform3D)globalTransform renderContent:(LottieRenderContent * _Nullable)renderContent hasSimpleContents:(bool)hasSimpleContents isInvertedMatte:(bool)isInvertedMatte subnodes:(NSArray<LottieRenderNode *> * _Nonnull)subnodes mask:(LottieRenderNode * _Nullable)mask __attribute__((objc_direct));

@end

#ifdef __cplusplus
}
#endif

#endif /* LottieRenderTree_h */
