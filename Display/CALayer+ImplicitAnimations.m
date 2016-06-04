#import "CALayer+ImplicitAnimations.h"

#import <UIKit/UIKit.h>

#import "RuntimeUtils.h"
#import <AsyncDisplayKit/AsyncDisplayKit.h>

static bool recordingChanges = false;
static NSMutableArray *currentLayerAnimations()
{
    static NSMutableArray *array = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        array = [[NSMutableArray alloc] init];
    });
    
    return array;
}

@implementation CALayerAnimation

- (instancetype)initWithLayer:(CALayer *)layer
{
    self = [super init];
    if (self != nil)
    {
        _layer = layer;
        
        _startBounds = layer.bounds;
        _startPosition = layer.position;
        
        _endBounds = _startBounds;
        _endPosition = _startPosition;
    }
    return self;
}

- (void)setEndBounds:(CGRect)endBounds
{
    _endBounds = endBounds;
}

- (void)setEndPosition:(CGPoint)endPosition
{
    _endPosition = endPosition;
}

@end

@interface CALayer (_ca836a62_)

@end

@implementation CALayer (_ca836a62_)

- (void)_ca836a62_setBounds:(CGRect)bounds
{
    if (recordingChanges && [self.delegate isKindOfClass:[ASDisplayNode class]])
    {
        CALayerAnimation *animation = nil;
        for (CALayerAnimation *listAnimation in currentLayerAnimations())
        {
            if (listAnimation.layer == self)
            {
                animation = listAnimation;
                break;
            }
        }
        if (animation == nil)
        {
            animation = [[CALayerAnimation alloc] initWithLayer:self];
            [currentLayerAnimations() addObject:animation];
        }
        [animation setEndBounds:bounds];
    }
    
    [self _ca836a62_setBounds:bounds];
}

- (void)_ca836a62_setPosition:(CGPoint)position
{
    if (recordingChanges && [self.delegate isKindOfClass:[ASDisplayNode class]])
    {
        CALayerAnimation *animation = nil;
        for (CALayerAnimation *listAnimation in currentLayerAnimations())
        {
            if (listAnimation.layer == self)
            {
                animation = listAnimation;
                break;
            }
        }
        if (animation == nil)
        {
            animation = [[CALayerAnimation alloc] initWithLayer:self];
            [currentLayerAnimations() addObject:animation];
        }
        [animation setEndPosition:position];
    }
    
    [self _ca836a62_setPosition:position];
}

- (void)_ca836a62_addAnimation:(CAAnimation *)animation forKey:(NSString *)key {
    if (speedOverride != 1.0f) {
        animation.speed *= speedOverride;
    }
    [self _ca836a62_addAnimation:animation forKey:key];
}

static CGFloat speedOverride = 1.0f;

+ (void)overrideAnimationSpeed:(CGFloat)speed block:(void (^)())block {
    CGFloat previousOverride = speedOverride;
    speedOverride = speed;
    block();
    speedOverride = previousOverride;
}

@end

@interface LayerAnimationExtensions : NSObject

@end

@implementation LayerAnimationExtensions

+ (void)load
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        //[RuntimeUtils swizzleInstanceMethodOfClass:[CALayer class] currentSelector:@selector(setBounds:) newSelector:@selector(_ca836a62_setBounds:)];
        //[RuntimeUtils swizzleInstanceMethodOfClass:[CALayer class] currentSelector:@selector(setPosition:) newSelector:@selector(_ca836a62_setPosition:)];
        //[RuntimeUtils swizzleInstanceMethodOfClass:[CALayer class] currentSelector:@selector(addAnimation:forKey:) newSelector:@selector(_ca836a62_addAnimation:forKey:)];
    });
}

@end

@implementation CALayer (ImplicitAnimations)

+ (void)beginRecordingChanges
{
    recordingChanges = true;
    [currentLayerAnimations() removeAllObjects];
}

+ (NSArray *)endRecordingChanges
{
    recordingChanges = false;
    NSArray *array = [[NSArray alloc] initWithArray:currentLayerAnimations()];
    [currentLayerAnimations() removeAllObjects];
    
    return array;
}

+ (void)overrideAnimationSpeed:(CGFloat)speed block:(void (^)())block {
    
}

@end
