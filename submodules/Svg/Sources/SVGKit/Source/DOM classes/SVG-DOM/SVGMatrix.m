
#import "SVGMatrix.h"

@implementation SVGMatrix

@synthesize a,b,c,d,e,f;

-(SVGMatrix*) multiply:(SVGMatrix*) secondMatrix { NSAssert( FALSE, @"Not implemented yet" ); return nil; }
-(SVGMatrix*) inverse { NSAssert( FALSE, @"Not implemented yet" ); return nil; }
-(SVGMatrix*) translate:(float) x y:(float) y { NSAssert( FALSE, @"Not implemented yet" ); return nil; }
-(SVGMatrix*) scale:(float) scaleFactor { NSAssert( FALSE, @"Not implemented yet" ); return nil; }
-(SVGMatrix*) scaleNonUniform:(float) scaleFactorX scaleFactorY:(float) scaleFactorY { NSAssert( FALSE, @"Not implemented yet" ); return nil; }
-(SVGMatrix*) rotate:(float) angle { NSAssert( FALSE, @"Not implemented yet" ); return nil; }
-(SVGMatrix*) rotateFromVector:(float) x y:(float) y { NSAssert( FALSE, @"Not implemented yet" ); return nil; }
-(SVGMatrix*) flipX { NSAssert( FALSE, @"Not implemented yet" ); return nil; }
-(SVGMatrix*) flipY { NSAssert( FALSE, @"Not implemented yet" ); return nil; }
-(SVGMatrix*) skewX:(float) angle { NSAssert( FALSE, @"Not implemented yet" ); return nil; }
-(SVGMatrix*) skewY:(float) angle { NSAssert( FALSE, @"Not implemented yet" ); return nil; }

@end
