#import "SVGRect.h"

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

BOOL SVGRectIsInitialized( SVGRect rect )
{
	return rect.x != -1 || rect.y != -1 || rect.width != -1 || rect.height != -1;
}

SVGRect SVGRectUninitialized( void )
{
	return SVGRectMake( -1, -1, -1, -1 );
}

SVGRect SVGRectMake( float x, float y, float width, float height )
{
	SVGRect result = { x, y, width, height };
	return result;
}

CGRect CGRectFromSVGRect( SVGRect rect )
{
	CGRect result = CGRectMake(rect.x, rect.y, rect.width, rect.height);
	
	return result;
}

CGSize CGSizeFromSVGRect( SVGRect rect )
{
	CGSize result = CGSizeMake( rect.width, rect.height );
	
	return result;
}

NSString * NSStringFromSVGRect( SVGRect rect ) {
    CGRect cgRect = CGRectFromSVGRect(rect);
#if SVGKIT_MAC
    return NSStringFromRect(cgRect);
#else
    return NSStringFromCGRect(cgRect);
#endif
}
