#import "CASeeThroughTracingLayer.h"

@interface CASeeThroughTracingLayer () {
    CGPoint _parentOffset;
}

@end

@implementation CASeeThroughTracingLayer

- (void)addAnimation:(CAAnimation *)anim forKey:(NSString *)key {
    [super addAnimation:anim forKey:key];
}

- (void)setFrame:(CGRect)frame {
    [super setFrame:frame];
    
    [self _mirrorTransformToSublayers];
}

- (void)setBounds:(CGRect)bounds {
    [super setBounds:bounds];
    
    [self _mirrorTransformToSublayers];
}

- (void)setPosition:(CGPoint)position {
    [super setPosition:position];
    
    [self _mirrorTransformToSublayers];
}

- (void)_mirrorTransformToSublayers {
    CGRect bounds = self.bounds;
    CGPoint position = self.position;
    
    CGPoint sublayerParentOffset = _parentOffset;
    sublayerParentOffset.x += position.x - (bounds.size.width) / 2.0f;
    sublayerParentOffset.y += position.y - (bounds.size.width) / 2.0f;
    
    for (CALayer *sublayer in self.sublayers) {
        if ([sublayer isKindOfClass:[CASeeThroughTracingLayer class]]) {
            ((CASeeThroughTracingLayer *)sublayer)->_parentOffset = sublayerParentOffset;
            [(CASeeThroughTracingLayer *)sublayer _mirrorTransformToSublayers];
        }
    }
}

@end

@implementation CASeeThroughTracingView

+ (Class)layerClass {
    return [CASeeThroughTracingLayer class];
}

@end
