#import "Svg.h"

#import "SVGKit.h"
#import "SVGKExporterUIImage.h"
 
CGSize aspectFillSize(CGSize size, CGSize bounds) {
    CGFloat scale = MAX(bounds.width / MAX(1.0, size.width), bounds.height / MAX(1.0, size.height));
    return CGSizeMake(floor(size.width * scale), floor(size.height * scale));
}

UIImage * _Nullable drawSvgImage(NSData * _Nonnull data, CGSize size) {
    NSDate *startTime = [NSDate date];
    
    SVGKImage *image = [[SVGKImage alloc] initWithData:data];
    image.size = aspectFillSize(image.size, size);
    
    if (image == nil) {
        return nil;
    }
        
    double deltaTime = -1.0f * [startTime timeIntervalSinceNow];
    //printf("parseTime = %f\n", deltaTime);
    
    UIGraphicsBeginImageContextWithOptions(size, true, 1.0);
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(context, [UIColor blackColor].CGColor);
    CGContextFillRect(context, CGRectMake(0.0f, 0.0f, size.width, size.height));
    
    CGContextTranslateCTM(context, (size.width - image.size.width) / 2.0f, (size.height - image.size.height) / 2.0f);
    
    startTime = [NSDate date];
        
    [image renderToContext:context antiAliased:true curveFlatnessFactor:1.0 interpolationQuality:kCGInterpolationDefault flipYaxis:false];
    
    deltaTime = -1.0f * [startTime timeIntervalSinceNow];
    //printf("drawingTime = %f\n", deltaTime);
    
    UIImage *resultImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return resultImage;
}
