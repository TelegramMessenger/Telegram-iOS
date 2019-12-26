#import "SVGAnimatedPreserveAspectRatio.h"

@implementation SVGAnimatedPreserveAspectRatio


- (id)init
{
    self = [super init];
    if (self) {
        self.baseVal = [SVGPreserveAspectRatio new];
    }
    return self;
}

/** TODO: Current implementation (animation not supported anywhere in SVGKit yet) simply returns
 a copy of self.baseVal --- NOTE: spec REQUIRES you return a copy! It is explicit on this!
 */
-(SVGPreserveAspectRatio *)animVal
{
	SVGPreserveAspectRatio* cloneOfBase = [SVGPreserveAspectRatio new];
	
	cloneOfBase.align = self.baseVal.align;
	cloneOfBase.meetOrSlice = self.baseVal.meetOrSlice;
	
	return cloneOfBase;
}

@end
