#import "Svg.h"

#import "SVGKit.h"
#import "SVGKExporterUIImage.h"


UIImage * _Nullable drawSvgImage(NSData * _Nonnull data, CGSize size) {
    NSDate *startTime = [NSDate date];
    
    SVGKImage *image = [[SVGKImage alloc] initWithData:data];
    if (image == nil) {
        return;
    }
    
    double deltaTime = -1.0f * [startTime timeIntervalSinceNow];
    //printf("parseTime = %f\n", deltaTime);
    
    UIGraphicsBeginImageContextWithOptions(size, true, 1.0);
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(context, [UIColor whiteColor].CGColor);
    CGContextFillRect(context, CGRectMake(0.0f, 0.0f, size.width, size.height));
    
    startTime = [NSDate date];
    
    [image renderToContext:context antiAliased:true curveFlatnessFactor:1.0 interpolationQuality:kCGInterpolationDefault flipYaxis:false];
    
    deltaTime = -1.0f * [startTime timeIntervalSinceNow];
    //printf("drawingTime = %f\n", deltaTime);
    
    UIImage *resultImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return resultImage;
}
