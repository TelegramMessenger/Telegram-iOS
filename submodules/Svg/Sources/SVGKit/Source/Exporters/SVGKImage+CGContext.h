/**
 Contains methods for low-level exporting of SVGKImage into CGContext's / OpenGL textures / etc
 
 Process:
   1. Create a CGContextRef; either use your own code (e.g. with OpenGL, you usually want to do this by hand and check PoT),
       or use the [self newCGContextAutosizedToFit] method.
   2. Use the renderToContext:::: method (preferred) or the pure, low-level renderInContext: method (not preferred) to
       draw into your context
   3. ...do whatever you want with the results (e.g. use one of the Exporters to export it to raw NSData bytes, or similar)
 */
#import "SVGKImage.h"

@interface SVGKImage (CGContext)

/** Creates a CGContext with correct pixel size using sizing info from the source SVG (or returns NULL if that's not possible)
 */
-(CGContextRef) newCGContextAutosizedToFit;

/**
 WARNING: due to bugs in Apple's code (c.f. CALayer.h header file for notes from Apple - they say "use caution"),
 this method is NOT a perfect render of CA; it uses Apple's own "approximation", as used in [CALayer renderInContext:],
 which ignores e.g. masking and some other CA core features
 
 Generally, for performance and safety, you should use renderToContext:antiAliased:curveFlatnessFactor:interpolationQuality:flipYaxis:
 instead of this method (it performs checks and optional performance optimizations)
 */
- (void)renderInContext:(CGContextRef)ctx;

/**
 The standard basic method used by all the different "export..." methods in this class and others
 */
-(void) renderToContext:(CGContextRef) context antiAliased:(BOOL) shouldAntialias curveFlatnessFactor:(CGFloat) multiplyFlatness interpolationQuality:(CGInterpolationQuality) interpolationQuality flipYaxis:(BOOL) flipYaxis;

@end
