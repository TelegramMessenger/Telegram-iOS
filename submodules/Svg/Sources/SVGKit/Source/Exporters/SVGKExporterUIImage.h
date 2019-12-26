/**
 General-purpose exporter from loaded-SVGKImage object into a new, rasterised UIImage.
 
 Uses the default color format from UIGraphicsBeginImageContextWithOptions(...)
 */
#import <Foundation/Foundation.h>
#import "SVGKImage.h"

@interface SVGKExporterUIImage : NSObject

/**
 Higher-performance version of .UIImage property (the property uses this method, but you can tweak the parameters for better performance / worse accuracy)
 
 NB: you can get BETTER performance using the exportNSDataAntiAliased: version of this method, becuase you bypass Apple's slow code for making UIImage objects
 
 Delegates to exportAsUIImage:... antiAliased:TRUE curveFlatnessFactor:1.0 interpolationQuality:kCGInterpolationDefault]
 */
+(UIImage*) exportAsUIImage:(SVGKImage*) image;

/**
 Higher-performance version of .UIImage property (the property uses this method, but you can tweak the parameters for better performance / worse accuracy)
 
 NB: you can get BETTER performance using the exportNSDataAntiAliased: version of this method, becuase you bypass Apple's slow code for making UIImage objects
 
 @param shouldAntialias = Apple defaults to TRUE, but turn it off for small speed boost
 @param multiplyFlatness = how many pixels a curve can be flattened by (Apple's internal setting) to make it faster to render but less accurate
 @param interpolationQuality = Apple internal setting, c.f. Apple docs for CGInterpolationQuality
 */
+(UIImage*) exportAsUIImage:(SVGKImage*) image antiAliased:(BOOL) shouldAntialias curveFlatnessFactor:(CGFloat) multiplyFlatness interpolationQuality:(CGInterpolationQuality) interpolationQuality;

@end
