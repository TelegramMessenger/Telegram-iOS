#import "SVGKExporterNSData.h"

#import "SVGKImage+CGContext.h" // needed for Context calls

@implementation SVGKExporterNSData

+(NSData*) exportAsNSData:(SVGKImage*) image
{
	return [self exportAsNSData:image flipYaxis:FALSE];
}

+(NSData*) exportAsNSData:(SVGKImage*) image flipYaxis:(BOOL) flipYaxis
{
	return [self exportAsNSData:image antiAliased:TRUE curveFlatnessFactor:1.0 interpolationQuality:kCGInterpolationDefault flipYaxis:flipYaxis];
}

+(NSData*) exportAsNSData:(SVGKImage*) image antiAliased:(BOOL) shouldAntialias curveFlatnessFactor:(CGFloat) multiplyFlatness interpolationQuality:(CGInterpolationQuality) interpolationQuality flipYaxis:(BOOL) flipYaxis
{
	CGContextRef newContext = [image newCGContextAutosizedToFit];
	
	[image renderToContext:newContext antiAliased:shouldAntialias curveFlatnessFactor:multiplyFlatness interpolationQuality:interpolationQuality flipYaxis: flipYaxis];
	
	void* resultAsVoidStar = CGBitmapContextGetData(newContext);
	
	size_t dataSize = 4 * image.size.width * image.size.height; // RGBA = 4 8-bit components
    NSData* result = [NSData dataWithBytes:resultAsVoidStar length:dataSize];
	
	CGContextRelease(newContext);
	
	return result;
}
@end
