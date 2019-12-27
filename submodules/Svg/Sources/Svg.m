#import "Svg.h"

#import "SVGKit.h"
#import "SVGKExporterUIImage.h"

#import "nanosvg.h"

UIImage * _Nullable drawSvgImage(NSData * _Nonnull data, CGSize size) {
    char *zeroTerminatedData = malloc(data.length + 1);
    [data getBytes:zeroTerminatedData length:data.length];
    zeroTerminatedData[data.length] = 0;
    
    NSVGimage *image = nsvgParse(zeroTerminatedData, "px", 96);
    if (image == nil || image->width < 1.0f || image->height < 1.0f) {
        return nil;
    }
    
    UIGraphicsBeginImageContextWithOptions(size, true, 1.0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(context, [UIColor whiteColor].CGColor);
    CGContextFillRect(context, CGRectMake(0.0f, 0.0f, size.width, size.height));
    CGContextScaleCTM(context, size.width / image->width, size.height / image->height);
    
    for (NSVGshape *shape = image->shapes; shape != NULL; shape = shape->next) {
        if (!(shape->flags & NSVG_FLAGS_VISIBLE)) {
            continue;
        }
        
        if (shape->fill.type != NSVG_PAINT_NONE) {
            CGContextSetFillColorWithColor(context, [[UIColor blackColor] colorWithAlphaComponent:shape->opacity].CGColor);

            for (NSVGpath *path = shape->paths; path != NULL; path = path->next) {
                CGContextBeginPath(context);
                CGContextMoveToPoint(context, path->pts[0], path->pts[1]);
                for (int i = 0; i < path->npts - 1; i += 3) {
                    float *p = &path->pts[i * 2];
                    CGContextAddCurveToPoint(context, p[2], p[3], p[4], p[5], p[6], p[7]);
                    //drawCubicBez(p[0],p[1], p[2],p[3], p[4],p[5], p[6],p[7]);
                }
                
                switch (shape->fillRule) {
                    case NSVG_FILLRULE_EVENODD:
                        CGContextEOFillPath(context);
                        break;
                    default:
                        CGContextFillPath(context);
                        break;
                }
            }
        }
        
        if (shape->stroke.type != NSVG_PAINT_NONE) {
            CGContextSetStrokeColorWithColor(context, [[UIColor blackColor] colorWithAlphaComponent:shape->opacity].CGColor);
            //CGContextSetMiterLimit(context, shape->miterLimit);
            
            CGContextSetLineWidth(context, shape->strokeWidth);
            switch (shape->strokeLineCap) {
                case NSVG_CAP_BUTT:
                    CGContextSetLineCap(context, kCGLineCapButt);
                    break;
                case NSVG_CAP_ROUND:
                    CGContextSetLineCap(context, kCGLineCapRound);
                    break;
                case NSVG_CAP_SQUARE:
                    CGContextSetLineCap(context, kCGLineCapSquare);
                    break;
                default:
                    break;
            }
            switch (shape->strokeLineJoin) {
                case NSVG_JOIN_BEVEL:
                    CGContextSetLineJoin(context, kCGLineJoinBevel);
                    break;
                case NSVG_JOIN_MITER:
                    CGContextSetLineCap(context, kCGLineJoinMiter);
                    break;
                case NSVG_JOIN_ROUND:
                    CGContextSetLineCap(context, kCGLineJoinRound);
                    break;
                default:
                    break;
            }
            
            for (NSVGpath *path = shape->paths; path != NULL; path = path->next) {
                CGContextBeginPath(context);
                CGContextMoveToPoint(context, path->pts[0], path->pts[1]);
                for (int i = 0; i < path->npts - 1; i += 3) {
                    float *p = &path->pts[i * 2];
                    CGContextAddCurveToPoint(context, p[2], p[3], p[4], p[5], p[6], p[7]);
                    //drawCubicBez(p[0],p[1], p[2],p[3], p[4],p[5], p[6],p[7]);
                }
                
                if (path->closed) {
                    CGContextClosePath(context);
                }
                CGContextStrokePath(context);
            }
        }
    }
    
    UIImage *resultImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    nsvgDelete(image);
    
    return resultImage;
}

UIImage * _Nullable drawSvgImage1(NSData * _Nonnull data, CGSize size) {
    NSDate *startTime = [NSDate date];
    
    SVGKImage *image = [[SVGKImage alloc] initWithData:data];
    if (image == nil) {
        return nil;
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
