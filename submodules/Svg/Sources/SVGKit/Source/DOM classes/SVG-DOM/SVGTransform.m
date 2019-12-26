#import "SVGTransform.h"

@implementation SVGTransform

@synthesize type;
@synthesize matrix;
@synthesize angle;


-(void) setMatrix:(SVGMatrix*) matrix { NSAssert( FALSE, @"Not implemented yet" ); }
-(void) setTranslate:(float) tx ty:(float) ty { NSAssert( FALSE, @"Not implemented yet" ); }
-(void) setScale:(float) sx sy:(float) sy { NSAssert( FALSE, @"Not implemented yet" ); }
-(void) setRotate:(float) angle cx:(float) cx cy:(float) cy { NSAssert( FALSE, @"Not implemented yet" ); }
-(void) setSkewX:(float) angle { NSAssert( FALSE, @"Not implemented yet" ); }
-(void) setSkewY:(float) angle { NSAssert( FALSE, @"Not implemented yet" ); }

@end
