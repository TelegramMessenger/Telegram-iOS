#import "SVGGElement.h"

#import "CALayerWithChildHitTest.h"

#import "SVGHelperUtilities.h"

@implementation SVGGElement 

@synthesize transform; // each SVGElement subclass that conforms to protocol "SVGTransformable" has to re-synthesize this to work around bugs in Apple's Objective-C 2.0 design that don't allow @properties to be extended by categories / protocols

- (CALayer *) newLayer
{
	
	CALayer* _layer = [CALayerWithChildHitTest layer];
	
	[SVGHelperUtilities configureCALayer:_layer usingElement:self];
	
	return _layer;
}

- (void)layoutLayer:(CALayer *)layer {
	
    // null rect union any other rect will return the other rect
	CGRect mainRect = CGRectNull;
	
	/** make mainrect the UNION of all sublayer's frames (i.e. their individual "bounds" inside THIS layer's space) */
	for ( CALayer *currentLayer in [layer sublayers] )
	{
		CGRect subLayerFrame = currentLayer.frame;
		mainRect = CGRectUnion(mainRect, subLayerFrame);
	}
	
    NSAssert(!CGRectIsNull(mainRect), @"A G element has been generated with non-existent size and no contents. Apple cannot cope with this. As a workaround, we are resetting your layer to empty, but this may have unwanted side-effects (hard to test)" );
    if (CGRectIsNull(mainRect))
    {
        return;
    }
    else
    {
	/** use mainrect (union of all sub-layer bounds) this layer's FRAME
	 
	 i.e. top-left-corner of this layer will be "the top left corner of the convex-hull rect of all sublayers"
	 AND: bottom-right-corner of this layer will be "the bottom-right corner of the convex-hull rect of all sublayers"
	 */
	layer.frame = mainRect;
    
    /**
     If this group layer has a mask then since we've adjusted this layer's frame we need to offset the mask's frame by the opposite amount.
     */
    if (layer.mask)
        layer.mask.frame = CGRectOffset(layer.mask.frame, -mainRect.origin.x, -mainRect.origin.y);

	/** Changing THIS layer's frame now means all DIRECT sublayers are offset by too much (because when we change the offset
	 of the parent frame (this.frame), Apple *does not* shift the sublayers around to keep them in same place.
	 
	 NB: there are bugs in some Apple code in Interface Builder where it attempts to do exactly that (incorrectly, as the API
	 is specifically designed NOT to do this), and ... Fails. But in code, thankfully, Apple *almost* never does this (there are a few method
	 calls where it appears someone at Apple forgot how their API works, and tried to do the offsetting automatically. "Paved
	 with good intentions...".
	 	 */
    
        for (CALayer *currentLayer in [layer sublayers]) {
            CGRect frame = currentLayer.frame;
            frame.origin.x -= mainRect.origin.x;
            frame.origin.y -= mainRect.origin.y;
            currentLayer.frame = frame;
        }
    }
}

@end
