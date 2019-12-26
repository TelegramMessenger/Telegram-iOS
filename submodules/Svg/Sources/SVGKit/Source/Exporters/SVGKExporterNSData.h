/**
 General-purpose exporter from loaded-SVGKImage object into an NSData byte-array.
 
 Uses the default color format from [SVGKImage+CGContext newCGContextAutosizedToFit] (currently RGBA / CGColorSpaceCreateDeviceRGB)
 */
#import <Foundation/Foundation.h>
#import "SVGKImage.h"

@interface SVGKExporterNSData : NSObject

/**
 Highest-performance version of .UIImage property (this minimizes memory usage and can lead to large speed-ups e.g. when using SVG images as textures with OpenGLES)
 
 Delegates to [ exportAsNSData:... flipYaxis:TRUE]
 */
+(NSData*) exportAsNSData:(SVGKImage*) image;

/**
 Highest-performance version of .UIImage property (this minimizes memory usage and can lead to large speed-ups e.g. when using SVG images as textures with OpenGLES)
 
 Delegates to exportAsNSData:... antiAliased:TRUE curveFlatnessFactor:1.0 interpolationQuality:kCGInterpolationDefault flipYaxis:...]
*/
+(NSData*) exportAsNSData:(SVGKImage*) image flipYaxis:(BOOL) flipYaxis;

/**
 Highest-performance version of .UIImage property (this minimizes memory usage and can lead to large speed-ups e.g. when using SVG images as textures with OpenGLES)
 
 NB: we could probably achieve get even higher performance in OpenGL by sidestepping NSData entirely and using raw byte arrays (should result in zero-copy).
 
 @param shouldAntialias = Apple defaults to TRUE, but turn it off for small speed boost
 @param multiplyFlatness = how many pixels a curve can be flattened by (Apple's internal setting) to make it faster to render but less accurate
 @param interpolationQuality = Apple internal setting, c.f. Apple docs for CGInterpolationQuality
 */
+(NSData*) exportAsNSData:(SVGKImage*) image antiAliased:(BOOL) shouldAntialias curveFlatnessFactor:(CGFloat) multiplyFlatness interpolationQuality:(CGInterpolationQuality) interpolationQuality flipYaxis:(BOOL) flipYaxis;

@end
