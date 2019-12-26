#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import "CALayerWithClipRender.h"

/*!
 * Overrides Apple's CALayer purely to change one method, so that hit-testing
 * is done by checking whether the hit point lies:
 *
 *  "inside ANY of my child sub-layers (some of which have over-ridden hit-testing too)"
 *
 * This implementation is used by SVGGElement (for obvious reasons!)
 *
 * This is more useful than Apple's default implementation, but it might cause unexpected
 * problems in other code (not that I'm aware of any - this override appears to be a common
 * implementation, c.f. http://stackoverflow.com/questions/2944064/hit-testing-with-calayer-using-the-alpha-properties-of-the-calayer-contents
 */
@interface CALayerWithChildHitTest : CALayerWithClipRender {
    
}

@end
