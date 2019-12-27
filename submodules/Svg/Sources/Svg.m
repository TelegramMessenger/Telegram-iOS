#import "Svg.h"

#import "SVGKit.h"
#import "SVGKExporterUIImage.h"

#import "nanosvg.h"
 
CGSize aspectFillSize(CGSize size, CGSize bounds) {
    CGFloat scale = MAX(bounds.width / MAX(1.0, size.width), bounds.height / MAX(1.0, size.height));
    return CGSizeMake(floor(size.width * scale), floor(size.height * scale));
}

@interface SvgXMLParsingDelegate : NSObject <NSXMLParserDelegate> {
    NSString *_elementName;
    NSString *_currentStyleString;
}

@property (nonatomic, strong, readonly) NSMutableDictionary<NSString *, NSString *> *styles;

@end

@implementation SvgXMLParsingDelegate

- (instancetype)init {
    self = [super init];
    if (self != nil) {
        _styles = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary<NSString *,NSString *> *)attributeDict {
    _elementName = elementName;
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName {
    if ([_elementName isEqualToString:@"style"]) {
        int currentClassNameStartIndex = -1;
        int currentClassContentsStartIndex = -1;
        
        NSString *currentClassName = nil;
        
        NSCharacterSet *alphanumeric = [NSCharacterSet alphanumericCharacterSet];
        
        for (int i = 0; i < _currentStyleString.length; i++) {
            unichar c = [_currentStyleString characterAtIndex:i];
            if (currentClassNameStartIndex != -1) {
                if (![alphanumeric characterIsMember:c]) {
                    currentClassName = [_currentStyleString substringWithRange:NSMakeRange(currentClassNameStartIndex, i - currentClassNameStartIndex)];
                    currentClassNameStartIndex = -1;
                }
            } else if (currentClassContentsStartIndex != -1) {
                if (c == '}') {
                    NSString *classContents = [_currentStyleString substringWithRange:NSMakeRange(currentClassContentsStartIndex, i - currentClassContentsStartIndex)];
                    if (currentClassName != nil && classContents != nil) {
                        _styles[currentClassName] = classContents;
                        currentClassName = nil;
                    }
                    currentClassContentsStartIndex = -1;
                }
            }
            
            if (currentClassNameStartIndex == -1 && currentClassContentsStartIndex == -1) {
                if (c == '.') {
                    currentClassNameStartIndex = i + 1;
                } else if (c == '{') {
                    currentClassContentsStartIndex = i + 1;
                }
            }
        }
    }
    _elementName = nil;
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string {
    if ([_elementName isEqualToString:@"style"]) {
        if (_currentStyleString == nil) {
            _currentStyleString = string;
        } else {
            _currentStyleString = [_currentStyleString stringByAppendingString:string];
        }
    }
}

@end

UIImage * _Nullable drawSvgImage(NSData * _Nonnull data, CGSize size) {
    NSDate *startTime = [NSDate date];
    
    NSXMLParser *parser = [[NSXMLParser alloc] initWithData:data];
    if (parser == nil) {
        return nil;
    }
    SvgXMLParsingDelegate *delegate = [[SvgXMLParsingDelegate alloc] init];
    parser.delegate = delegate;
    [parser parse];
    
    NSMutableString *xmlString = [[NSMutableString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (xmlString == nil) {
        return nil;
    }
    
    for (NSString *styleName in delegate.styles) {
        NSString *styleValue = delegate.styles[styleName];
        [xmlString replaceOccurrencesOfString:[NSString stringWithFormat:@"class=\"%@\"", styleName] withString:[NSString stringWithFormat:@"style=\"%@\"", styleValue] options:0 range:NSMakeRange(0, xmlString.length)];
    }
    
    char *zeroTerminatedData = xmlString.UTF8String;
    
    NSVGimage *image = nsvgParse(zeroTerminatedData, "px", 96);
    if (image == nil || image->width < 1.0f || image->height < 1.0f) {
        return nil;
    }
    
    double deltaTime = -1.0f * [startTime timeIntervalSinceNow];
    printf("parseTime = %f\n", deltaTime);
    
    startTime = [NSDate date];
    
    UIColor *backgroundColor = [UIColor blackColor];
    UIColor *foregroundColor = [UIColor whiteColor];
    
    UIGraphicsBeginImageContextWithOptions(size, true, 1.0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(context, backgroundColor.CGColor);
    CGContextFillRect(context, CGRectMake(0.0f, 0.0f, size.width, size.height));
    CGContextScaleCTM(context, size.width / image->width, size.height / image->height);
    
    for (NSVGshape *shape = image->shapes; shape != NULL; shape = shape->next) {
        if (!(shape->flags & NSVG_FLAGS_VISIBLE)) {
            continue;
        }
        
        if (shape->fill.type != NSVG_PAINT_NONE) {
            CGContextSetFillColorWithColor(context, [foregroundColor colorWithAlphaComponent:shape->opacity].CGColor);

            for (NSVGpath *path = shape->paths; path != NULL; path = path->next) {
                CGContextBeginPath(context);
                CGContextMoveToPoint(context, path->pts[0], path->pts[1]);
                for (int i = 0; i < path->npts - 1; i += 3) {
                    float *p = &path->pts[i * 2];
                    CGContextAddCurveToPoint(context, p[2], p[3], p[4], p[5], p[6], p[7]);
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
            CGContextSetStrokeColorWithColor(context, [foregroundColor colorWithAlphaComponent:shape->opacity].CGColor);
            CGContextSetMiterLimit(context, shape->miterLimit);
            
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
    
    deltaTime = -1.0f * [startTime timeIntervalSinceNow];
    printf("drawingTime = %f\n", deltaTime);
    
    nsvgDelete(image);
    
    return resultImage;
}

UIImage * _Nullable drawSvgImage1(NSData * _Nonnull data, CGSize size) {
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
