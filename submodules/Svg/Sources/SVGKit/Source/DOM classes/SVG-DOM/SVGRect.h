/*
 http://www.w3.org/TR/SVG/types.html#InterfaceSVGRect
 
 interface SVGRect {
 attribute float x setraises(DOMException);
 attribute float y setraises(DOMException);
 attribute float width setraises(DOMException);
 attribute float height setraises(DOMException);
 };
 */
#import <Foundation/Foundation.h>

#import <CoreGraphics/CoreGraphics.h>

typedef struct
{
	float x;
	float y;
	float width;
	float height;
} SVGRect;

#pragma mark - utility methods that are NOT in the SVG Spec, bu which we need to implement it in ObjectiveC

/** C has no way of detecting if an SVGRect is deliberately 0 width (has special meaning in SVG), or accidentally (because it was
 never initialized).
 
 Unfortunately, the SVG Spec authors defined "uninitialized" and "values of zero" to mean differnet things, so we MUST preserve
 that difference! */
SVGRect SVGRectUninitialized(void);

/** c.f. note about SVGRectUninitialized() -- this method checks if a Rect is identical to the output of that method */
BOOL SVGRectIsInitialized( SVGRect rect );

SVGRect SVGRectMake( float x, float y, float width, float height );

/** Convenience method to convert to ObjectiveC's kind of rect */
CGRect CGRectFromSVGRect( SVGRect rect );

/** Convenience method to convert to ObjectiveC's kind of size - ONLY the width and height of this rect */
CGSize CGSizeFromSVGRect( SVGRect rect );

NSString * _Nonnull NSStringFromSVGRect( SVGRect rect );
