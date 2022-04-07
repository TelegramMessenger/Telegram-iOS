#import <Svg/Svg.h>

#import "nanosvg.h"

#define UIColorRGBA(rgb,a) ([[UIColor alloc] initWithRed:(((rgb >> 16) & 0xff) / 255.0f) green:(((rgb >> 8) & 0xff) / 255.0f) blue:(((rgb) & 0xff) / 255.0f) alpha:a])
 
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

UIImage * _Nullable drawSvgImage(NSData * _Nonnull data, CGSize size, UIColor *backgroundColor, UIColor *foregroundColor, bool opaque) {
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
    
    const char *zeroTerminatedData = xmlString.UTF8String;
    
    NSVGimage *image = nsvgParse((char *)zeroTerminatedData, "px", 96);
    if (image == nil || image->width < 1.0f || image->height < 1.0f) {
        return nil;
    }
    
    if (CGSizeEqualToSize(size, CGSizeZero)) {
        size = CGSizeMake(image->width, image->height);
    }
    
    double deltaTime = -1.0f * [startTime timeIntervalSinceNow];
    printf("parseTime = %f\n", deltaTime);
    
    startTime = [NSDate date];

    UIGraphicsBeginImageContextWithOptions(size, opaque, 1.0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(context, backgroundColor.CGColor);
    CGContextFillRect(context, CGRectMake(0.0f, 0.0f, size.width, size.height));
    
    CGSize svgSize = CGSizeMake(image->width, image->height);
    CGSize drawingSize = aspectFillSize(svgSize, size);
    
    CGFloat scale = MAX(size.width / MAX(1.0, svgSize.width), size.height / MAX(1.0, svgSize.height));
    
    CGContextScaleCTM(context, scale, scale);
    CGContextTranslateCTM(context, (size.width - drawingSize.width) / 2.0, (size.height - drawingSize.height) / 2.0);
    
    for (NSVGshape *shape = image->shapes; shape != NULL; shape = shape->next) {
        if (!(shape->flags & NSVG_FLAGS_VISIBLE)) {
            continue;
        }
        
        if (shape->fill.type != NSVG_PAINT_NONE) {
            CGContextSetFillColorWithColor(context, [foregroundColor colorWithAlphaComponent:shape->opacity].CGColor);

            bool isFirst = true;
            bool hasStartPoint = false;
            CGPoint startPoint;
            for (NSVGpath *path = shape->paths; path != NULL; path = path->next) {
                if (isFirst) {
                    CGContextBeginPath(context);
                    isFirst = false;
                    hasStartPoint = true;
                    startPoint.x = path->pts[0];
                    startPoint.y = path->pts[1];
                }
                CGContextMoveToPoint(context, path->pts[0], path->pts[1]);
                for (int i = 0; i < path->npts - 1; i += 3) {
                    float *p = &path->pts[i * 2];
                    CGContextAddCurveToPoint(context, p[2], p[3], p[4], p[5], p[6], p[7]);
                }
                
                if (path->closed) {
                    if (hasStartPoint) {
                        hasStartPoint = false;
                        CGContextAddLineToPoint(context, startPoint.x, startPoint.y);
                    }
                }
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
                    CGContextSetLineJoin(context, kCGLineJoinMiter);
                    break;
                case NSVG_JOIN_ROUND:
                    CGContextSetLineJoin(context, kCGLineJoinRound);
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
    printf("drawingTime %fx%f = %f\n", size.width, size.height, deltaTime);
    
    nsvgDelete(image);
    
    return resultImage;
}


@interface CGContextCoder : NSObject {
    NSMutableData *_data;
}

@property (nonatomic, readonly) NSData *data;

@end

@implementation CGContextCoder

- (instancetype)initWithSize:(CGSize)size {
    self = [super init];
    if (self != nil) {
        _data = [[NSMutableData alloc] init];
        
        int32_t intWidth = size.width;
        int32_t intHeight = size.height;
        [_data appendBytes:&intWidth length:sizeof(intWidth)];
        [_data appendBytes:&intHeight length:sizeof(intHeight)];
    }
    return self;
}

- (void)setFillColorWithOpacity:(CGFloat)opacity {
    uint8_t command = 1;
    [_data appendBytes:&command length:sizeof(command)];
    
    uint8_t intOpacity = opacity * 255.0;
    [_data appendBytes:&intOpacity length:sizeof(intOpacity)];
}

- (void)setupStrokeOpacity:(CGFloat)opacity mitterLimit:(CGFloat)mitterLimit lineWidth:(CGFloat)lineWidth lineCap:(CGLineCap)lineCap lineJoin:(CGLineJoin)lineJoin {
    uint8_t command = 2;
    [_data appendBytes:&command length:sizeof(command)];
    
    uint8_t intOpacity = opacity * 255.0;
    [_data appendBytes:&intOpacity length:sizeof(intOpacity)];
    
    float floatMitterLimit = mitterLimit;
    [_data appendBytes:&floatMitterLimit length:sizeof(floatMitterLimit)];
    
    float floatLineWidth = lineWidth;
    [_data appendBytes:&floatLineWidth length:sizeof(floatLineWidth)];
    
    uint8_t intLineCap = lineCap;
    [_data appendBytes:&intLineCap length:sizeof(intLineCap)];
    
    uint8_t intLineJoin = lineJoin;
    [_data appendBytes:&intLineJoin length:sizeof(intLineJoin)];
}

- (void)beginPath {
    uint8_t command = 3;
    [_data appendBytes:&command length:sizeof(command)];
}

- (void)moveToPoint:(CGPoint)point {
    uint8_t command = 4;
    [_data appendBytes:&command length:sizeof(command)];
    
    float floatX = point.x;
    [_data appendBytes:&floatX length:sizeof(floatX)];
   
    float floatY = point.y;
    [_data appendBytes:&floatY length:sizeof(floatY)];
}

- (void)addLineToPoint:(CGPoint)point {
    uint8_t command = 5;
    [_data appendBytes:&command length:sizeof(command)];
    
    float floatX = point.x;
    [_data appendBytes:&floatX length:sizeof(floatX)];
   
    float floatY = point.y;
    [_data appendBytes:&floatY length:sizeof(floatY)];
}

- (void)addCurveToPoint:(CGPoint)p1 p2:(CGPoint)p2 p3:(CGPoint)p3 {
    uint8_t command = 6;
    [_data appendBytes:&command length:sizeof(command)];
    
    float floatX1 = p1.x;
    [_data appendBytes:&floatX1 length:sizeof(floatX1)];
   
    float floatY1 = p1.y;
    [_data appendBytes:&floatY1 length:sizeof(floatY1)];
    
    float floatX2 = p2.x;
    [_data appendBytes:&floatX2 length:sizeof(floatX2)];
   
    float floatY2 = p2.y;
    [_data appendBytes:&floatY2 length:sizeof(floatY2)];
    
    float floatX3 = p3.x;
    [_data appendBytes:&floatX3 length:sizeof(floatX3)];
   
    float floatY3 = p3.y;
    [_data appendBytes:&floatY3 length:sizeof(floatY3)];
}

- (void)closePath {
    uint8_t command = 7;
    [_data appendBytes:&command length:sizeof(command)];
}

- (void)eoFillPath {
    uint8_t command = 8;
    [_data appendBytes:&command length:sizeof(command)];
}

- (void)fillPath {
    uint8_t command = 9;
    [_data appendBytes:&command length:sizeof(command)];
}

- (void)strokePath {
    uint8_t command = 10;
    [_data appendBytes:&command length:sizeof(command)];
}

@end

UIImage * _Nullable renderPreparedImage(NSData * _Nonnull data, CGSize size, UIColor *backgroundColor, CGFloat scale) {
    NSDate *startTime = [NSDate date];
    
    UIColor *foregroundColor = [UIColor whiteColor];
    
    
    int32_t ptr = 0;
    int32_t width;
    int32_t height;
    
    if (data.length < 4 * 2) {
        return nil;
    }
    
    [data getBytes:&width range:NSMakeRange(ptr, sizeof(width))];
    ptr += sizeof(width);
    [data getBytes:&height range:NSMakeRange(ptr, sizeof(height))];
    ptr += sizeof(height);
    
    if (CGSizeEqualToSize(size, CGSizeZero)) {
        size = CGSizeMake(width, height);
    }
    
    bool isTransparent = [backgroundColor isEqual:[UIColor clearColor]];
    
    UIGraphicsBeginImageContextWithOptions(size, !isTransparent, scale);
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (isTransparent) {
        CGContextClearRect(context, CGRectMake(0.0f, 0.0f, size.width, size.height));
    } else {
        CGContextSetFillColorWithColor(context, backgroundColor.CGColor);
        CGContextFillRect(context, CGRectMake(0.0f, 0.0f, size.width, size.height));
    }
    
    CGSize svgSize = CGSizeMake(width, height);
    CGSize drawingSize = aspectFillSize(svgSize, size);
    
    CGFloat renderScale = MAX(size.width / MAX(1.0, svgSize.width), size.height / MAX(1.0, svgSize.height));
    
    CGContextScaleCTM(context, renderScale, renderScale);
    CGContextTranslateCTM(context, (size.width - drawingSize.width) / 2.0, (size.height - drawingSize.height) / 2.0);
    
    while (ptr < data.length) {
        uint8_t cmd;
        [data getBytes:&cmd range:NSMakeRange(ptr, sizeof(cmd))];
        ptr += sizeof(cmd);
        
        switch (cmd) {
            case 1:
            {
                uint8_t opacity;
                [data getBytes:&opacity range:NSMakeRange(ptr, sizeof(opacity))];
                ptr += sizeof(opacity);
                CGContextSetFillColorWithColor(context, [foregroundColor colorWithAlphaComponent:opacity / 255.0].CGColor);
            }
                break;
                
            case 2:
            {
                uint8_t opacity;
                [data getBytes:&opacity range:NSMakeRange(ptr, sizeof(opacity))];
                ptr += sizeof(opacity);
                CGContextSetStrokeColorWithColor(context, [foregroundColor colorWithAlphaComponent:opacity / 255.0].CGColor);
                
                float mitterLimit;
                [data getBytes:&mitterLimit range:NSMakeRange(ptr, sizeof(mitterLimit))];
                ptr += sizeof(mitterLimit);
                CGContextSetMiterLimit(context, mitterLimit);
                
                float lineWidth;
                [data getBytes:&lineWidth range:NSMakeRange(ptr, sizeof(lineWidth))];
                ptr += sizeof(lineWidth);
                CGContextSetLineWidth(context, lineWidth);
                
                uint8_t lineCap;
                [data getBytes:&lineCap range:NSMakeRange(ptr, sizeof(lineCap))];
                ptr += sizeof(lineCap);
                CGContextSetLineCap(context, lineCap);
                
                uint8_t lineJoin;
                [data getBytes:&lineJoin range:NSMakeRange(ptr, sizeof(lineJoin))];
                ptr += sizeof(lineJoin);
                CGContextSetLineCap(context, lineJoin);
            }
                break;
                
            case 3:
            {
                CGContextBeginPath(context);
            }
                break;
                
            case 4:
            {
                float x;
                [data getBytes:&x range:NSMakeRange(ptr, sizeof(x))];
                ptr += sizeof(x);
                
                float y;
                [data getBytes:&y range:NSMakeRange(ptr, sizeof(y))];
                ptr += sizeof(y);
                
                CGContextMoveToPoint(context, x, y);
            }
                break;
                
            case 5:
            {
                float x;
                [data getBytes:&x range:NSMakeRange(ptr, sizeof(x))];
                ptr += sizeof(x);
                
                float y;
                [data getBytes:&y range:NSMakeRange(ptr, sizeof(y))];
                ptr += sizeof(y);
                
                CGContextAddLineToPoint(context, x, y);
            }
                break;
                
            case 6:
            {
                float x1;
                [data getBytes:&x1 range:NSMakeRange(ptr, sizeof(x1))];
                ptr += sizeof(x1);
                
                float y1;
                [data getBytes:&y1 range:NSMakeRange(ptr, sizeof(y1))];
                ptr += sizeof(y1);
                
                float x2;
                [data getBytes:&x2 range:NSMakeRange(ptr, sizeof(x2))];
                ptr += sizeof(x2);
                
                float y2;
                [data getBytes:&y2 range:NSMakeRange(ptr, sizeof(y2))];
                ptr += sizeof(y2);
                
                float x3;
                [data getBytes:&x3 range:NSMakeRange(ptr, sizeof(x3))];
                ptr += sizeof(x3);
                
                float y3;
                [data getBytes:&y3 range:NSMakeRange(ptr, sizeof(y3))];
                ptr += sizeof(y3);
                
                CGContextAddCurveToPoint(context, x1, y1, x2, y2, x3, y3);
            }
                break;
                
            case 7:
            {
                CGContextClosePath(context);
            }
                break;
                
            case 8:
            {
                CGContextEOFillPath(context);
            }
                break;
            
            case 9:
            {
                CGContextFillPath(context);
            }
                break;
                
            case 10:
            {
                CGContextStrokePath(context);
            }
                break;
                
            default:
                break;
        }
    }
            
    UIImage *resultImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    double deltaTime = -1.0f * [startTime timeIntervalSinceNow];
    printf("drawingTime %fx%f = %f\n", size.width, size.height, deltaTime);
    
    return resultImage;
}

NSData * _Nullable prepareSvgImage(NSData * _Nonnull data) {
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
    
    const char *zeroTerminatedData = xmlString.UTF8String;
    
    NSVGimage *image = nsvgParse((char *)zeroTerminatedData, "px", 96);
    if (image == nil || image->width < 1.0f || image->height < 1.0f) {
        return nil;
    }
    
    double deltaTime = -1.0f * [startTime timeIntervalSinceNow];
    printf("parseTime = %f\n", deltaTime);
    
    startTime = [NSDate date];
   
    CGContextCoder *context = [[CGContextCoder alloc] initWithSize:CGSizeMake(image->width, image->height)];
   
    for (NSVGshape *shape = image->shapes; shape != NULL; shape = shape->next) {
        if (!(shape->flags & NSVG_FLAGS_VISIBLE)) {
            continue;
        }
        
        if (shape->fill.type != NSVG_PAINT_NONE) {
            [context setFillColorWithOpacity:shape->opacity];

            bool isFirst = true;
            bool hasStartPoint = false;
            CGPoint startPoint;
            for (NSVGpath *path = shape->paths; path != NULL; path = path->next) {
                if (isFirst) {
                    [context beginPath];

                    isFirst = false;
                    hasStartPoint = true;
                    startPoint.x = path->pts[0];
                    startPoint.y = path->pts[1];
                }
                [context moveToPoint:CGPointMake(path->pts[0], path->pts[1])];
                for (int i = 0; i < path->npts - 1; i += 3) {
                    float *p = &path->pts[i * 2];
                    [context addCurveToPoint:CGPointMake(p[2], p[3]) p2:CGPointMake(p[4], p[5]) p3:CGPointMake(p[6], p[7])];
                }
                
                if (path->closed) {
                    if (hasStartPoint) {
                        hasStartPoint = false;
                        [context addLineToPoint:startPoint];
                    }
                }
            }
            switch (shape->fillRule) {
                case NSVG_FILLRULE_EVENODD:
                    [context eoFillPath];
                    break;
                default:
                    [context fillPath];
                    break;
            }
        }
        
        if (shape->stroke.type != NSVG_PAINT_NONE) {
            CGLineCap lineCap = kCGLineCapButt;
            CGLineJoin lineJoin = kCGLineJoinMiter;
            switch (shape->strokeLineCap) {
                case NSVG_CAP_BUTT:
                    lineCap = kCGLineCapButt;
                    break;
                case NSVG_CAP_ROUND:
                    lineCap = kCGLineCapRound;
                    break;
                case NSVG_CAP_SQUARE:
                    lineCap = kCGLineCapSquare;
                    break;
                default:
                    break;
            }
            switch (shape->strokeLineJoin) {
                case NSVG_JOIN_BEVEL:
                    lineJoin = kCGLineJoinBevel;
                    break;
                case NSVG_JOIN_MITER:
                    lineJoin = kCGLineJoinMiter;
                    break;
                case NSVG_JOIN_ROUND:
                    lineJoin = kCGLineJoinRound;
                    break;
                default:
                    break;
            }
            
            [context setupStrokeOpacity:shape->opacity mitterLimit:shape->miterLimit lineWidth:shape->strokeWidth lineCap:lineCap lineJoin:lineJoin];
            
            for (NSVGpath *path = shape->paths; path != NULL; path = path->next) {
                [context beginPath];
                [context moveToPoint:CGPointMake(path->pts[0], path->pts[1])];
                for (int i = 0; i < path->npts - 1; i += 3) {
                    float *p = &path->pts[i * 2];
                    [context addCurveToPoint:CGPointMake(p[2], p[3]) p2:CGPointMake(p[4], p[5]) p3:CGPointMake(p[6], p[7])];
                }
                
                if (path->closed) {
                    [context closePath];
                }
                [context strokePath];
            }
        }
    }
    
    nsvgDelete(image);
    return context.data;
}
