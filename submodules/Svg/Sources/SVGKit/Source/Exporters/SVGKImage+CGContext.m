//
//  SVGKImage+CGContext.m
//  SVGKit-iOS
//
//  Created by adam on 22/12/2013.
//  Copyright (c) 2013 na. All rights reserved.
//

#import "SVGKImage+CGContext.h"

#import "SVGRect.h"
#import "SVGSVGElement.h"

@implementation SVGKImage (CGContext)

-(CGContextRef) newCGContextAutosizedToFit
{
	NSAssert( [self hasSize], @"Cannot export this image because the SVG file has infinite size. Either fix the SVG file, or set an explicit size you want it to be exported at (by calling .size = something on this SVGKImage instance");
	if( ! [self hasSize] )
		return NULL;
	
	SVGKitLogVerbose(@"[%@] DEBUG: Generating a CGContextRef using the current root-object's viewport (may have been overridden by user code): {0,0,%2.3f,%2.3f}", [self class], self.size.width, self.size.height);
	
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	CGContextRef context = CGBitmapContextCreate( NULL/*malloc( self.size.width * self.size.height * 4 )*/, self.size.width, self.size.height, 8, 4 * self.size.width, colorSpace, (CGBitmapInfo)kCGImageAlphaNoneSkipLast );
	CGColorSpaceRelease( colorSpace );
	
	return context;
}

- (void)renderInContext:(CGContextRef)ctx
{
	[self.CALayerTree renderInContext:ctx];
}

/**
 Shared between multiple different "export..." methods
 */
-(void) renderToContext:(CGContextRef) context antiAliased:(BOOL) shouldAntialias curveFlatnessFactor:(CGFloat) multiplyFlatness interpolationQuality:(CGInterpolationQuality) interpolationQuality flipYaxis:(BOOL) flipYaxis
{
	NSAssert( [self hasSize], @"Cannot scale this image because the SVG file has infinite size. Either fix the SVG file, or set an explicit size you want it to be exported at (by calling .size = something on this SVGKImage instance");
	
	NSDate* startTime;
	
	startTime = [NSDate date];
	
	if( SVGRectIsInitialized(self.DOMTree.viewport) )
		SVGKitLogInfo(@"[%@] DEBUG: rendering to CGContext using the current root-object's viewport (may have been overridden by user code): %@", [self class], NSStringFromSVGRect(self.DOMTree.viewport) );
	
	/** Typically a 10% performance improvement right here */
	if( !shouldAntialias )
		CGContextSetShouldAntialias( context, FALSE );
	
	/** Apple refuses to let you reset this, because they are selfish */
	CGContextSetFlatness( context, multiplyFlatness );
	
	/** Apple's own performance hints system */
	CGContextSetInterpolationQuality( context, interpolationQuality );
	
	/** Quartz, CoreGraphics, and CoreAnimation all use an "upside-down" co-ordinate system.
	 This means that images rendered are upside down.
	 
	 Apple's UIImage class automatically "un-flips" this - but if you are rendering raw NSData (which is 5x-10x faster than creating UIImages!) then the flipping is "lost"
	 by Apple's API's.
	 
	 The only way to fix it is to pre-transform by y = -y
	 
	 This is VERY useful if you want to render SVG's into OpenGL textures!
	 */
	if( flipYaxis )
	{
		NSAssert( [self hasSize], @"Cannot flip this image in Y because the SVG file has infinite size. Either fix the SVG file, or set an explicit size you want it to be treated as (by calling .size = something on this SVGKImage instance");
		
		CGContextTranslateCTM(context, 0, self.size.height );
		CGContextScaleCTM(context, 1.0, -1.0);
	}
	
	/**
	 The method that everyone hates, because Apple refuses to fix / implement it properly: renderInContext:
	 
	 It's slow.
	 
	 It's broken (according to the official API docs)
	 
	 But ... it's all that Apple gives us
	 */
	[self renderInContext:context];
	
	NSMutableString* perfImprovements = [NSMutableString string];
	if( shouldAntialias )
		[perfImprovements appendString:@" NO-ANTI-ALIAS"];
	if( perfImprovements.length < 1 )
		[perfImprovements appendString:@"NONE"];
	
	SVGKitLogVerbose(@"[%@] renderToContext: time taken to render CALayers to CGContext (perf improvements:%@): %2.3f seconds)", [self class], perfImprovements, -1.0f * [startTime timeIntervalSinceNow] );
}

@end
