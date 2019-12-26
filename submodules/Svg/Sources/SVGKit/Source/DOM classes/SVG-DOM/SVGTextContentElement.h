/**
 http://www.w3.org/TR/2011/REC-SVG11-20110816/text.html#InterfaceSVGTextContentElement
 
 interface SVGTextContentElement : SVGElement,
 SVGTests,
 SVGLangSpace,
 SVGExternalResourcesRequired,
 SVGStylable {
 
 // lengthAdjust Types
 const unsigned short LENGTHADJUST_UNKNOWN = 0;
 const unsigned short LENGTHADJUST_SPACING = 1;
 const unsigned short LENGTHADJUST_SPACINGANDGLYPHS = 2;
 
 readonly attribute SVGAnimatedLength textLength;
 readonly attribute SVGAnimatedEnumeration lengthAdjust;
 
 long getNumberOfChars();
 float getComputedTextLength();
 float getSubStringLength(in unsigned long charnum, in unsigned long nchars) raises(DOMException);
 SVGPoint getStartPositionOfChar(in unsigned long charnum) raises(DOMException);
 SVGPoint getEndPositionOfChar(in unsigned long charnum) raises(DOMException);
 SVGRect getExtentOfChar(in unsigned long charnum) raises(DOMException);
 float getRotationOfChar(in unsigned long charnum) raises(DOMException);
 long getCharNumAtPosition(in SVGPoint point);
 void selectSubString(in unsigned long charnum, in unsigned long nchars) raises(DOMException);
 */
#import "SVGElement.h"
#import "SVGStylable.h"
#import "SVGLength.h"

typedef enum SVGLengthAdjust
{
	// lengthAdjust Types
	SVGLengthAdjustUnknown = 0,
	SVGLengthAdjustSpacing = 1,
	SVGLengthAdjustSpacingAndGlyphs = 2
} SVGLengthAdjust;

@interface SVGTextContentElement : SVGElement <SVGStylable>
	
@property(weak, nonatomic,readonly) SVGLength* /* FIXMED: should be SVGAnimatedLength*/ textLength;
/**FIXME: missing:	readonly attribute SVGAnimatedEnumeration lengthAdjust;*/

/**FIXME: missing:	
	long getNumberOfChars();
	float getComputedTextLength();
	float getSubStringLength(in unsigned long charnum, in unsigned long nchars) raises(DOMException);
	SVGPoint getStartPositionOfChar(in unsigned long charnum) raises(DOMException);
	SVGPoint getEndPositionOfChar(in unsigned long charnum) raises(DOMException);
	SVGRect getExtentOfChar(in unsigned long charnum) raises(DOMException);
	float getRotationOfChar(in unsigned long charnum) raises(DOMException);
	long getCharNumAtPosition(in SVGPoint point);
	void selectSubString(in unsigned long charnum, in unsigned long nchars) raises(DOMException);
 */
@end
