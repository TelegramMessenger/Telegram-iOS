#import <Svg/Svg.h>
#import "nanosvg.h"

#define UIColorRGBA(rgb,a) ([[UIColor alloc] initWithRed:(((rgb >> 16) & 0xff) / 255.0f) green:(((rgb >> 8) & 0xff) / 255.0f) blue:(((rgb) & 0xff) / 255.0f) alpha:a])
#define CLAMP(x, min, max) ((x) < (min) ? (min) : ((x) > (max) ? (max) : (x)))

static inline CGSize aspectFillSize(CGSize size, CGSize bounds) {
    if (size.width <= 0 || size.height <= 0) return CGSizeZero;
    CGFloat scale = MAX(bounds.width / size.width, bounds.height / size.height);
    return CGSizeMake(floor(size.width * scale), floor(size.height * scale));
}

static inline CGSize aspectFitSize(CGSize size, CGSize bounds) {
    if (size.width <= 0 || size.height <= 0) return CGSizeZero;
    CGFloat scale = MIN(bounds.width / size.width, bounds.height / size.height);
    return CGSizeMake(floor(size.width * scale), floor(size.height * scale));
}

static inline CGFloat deg2rad(CGFloat deg) { return (deg * (CGFloat)M_PI) / 180.0; }

static CGSize SVGParseOneTransform(NSString *one, NSString *requiredName) {
    NSString *s = [one stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (s.length == 0) return CGSizeZero;

    NSRange paren = [s rangeOfString:@"("];
    if (paren.location == NSNotFound) return CGSizeZero;

    NSString *name = [[s substringToIndex:paren.location] lowercaseString];
    NSString *argsStr = [s substringWithRange:NSMakeRange(paren.location + 1, s.length - paren.location - 2)];

    NSMutableArray<NSNumber *> *nums = [NSMutableArray array];
    {
        NSScanner *sc = [NSScanner scannerWithString:argsStr];
        while (!sc.isAtEnd) {
            double v;
            if ([sc scanDouble:&v]) {
                [nums addObject:@(v)];
            } else {
                sc.scanLocation += 1;
            }
        }
    }

    if ([name isEqualToString:@"translate"] && [name isEqualToString:requiredName]) {
        CGFloat tx = nums.count > 0 ? nums[0].doubleValue : 0;
        CGFloat ty = nums.count > 1 ? nums[1].doubleValue : 0;
        return CGSizeMake(tx, ty);
    } else if ([name isEqualToString:@"scale"] && [name isEqualToString:requiredName]) {
        CGFloat sx = nums.count > 0 ? nums[0].doubleValue : 1;
        CGFloat sy = nums.count > 1 ? nums[1].doubleValue : sx;
        return CGSizeMake(sx, sy);
    } else if ([name isEqualToString:@"rotate"] && [name isEqualToString:requiredName]) {
        CGFloat a = nums.count > 0 ? deg2rad(nums[0].doubleValue) : 0;
        return CGSizeMake(a, a);
    }
    return CGSizeZero;
}

static CGAffineTransform SVGParseTransformList(NSString *list) {
    if (list.length == 0) {
        return CGAffineTransformMake(0.0, 1.0, 1.0, 0.0, 0.0, 0.0);
    }

    NSMutableArray<NSString *> *chunks = [NSMutableArray array];
    {
        NSMutableString *cur = [NSMutableString string];
        NSInteger depth = 0;
        for (NSUInteger i = 0; i < list.length; i++) {
            unichar ch = [list characterAtIndex:i];
            [cur appendFormat:@"%C", ch];
            if (ch == '(') depth++;
            if (ch == ')') {
                depth--;
                if (depth == 0) {
                    [chunks addObject:[cur copy]];
                    [cur setString:@""];
                }
            }
        }
    }
    CGFloat rotation = 0.0;
    CGSize scale = CGSizeMake(1.0, 1.0);
    for (NSString *part in chunks) {
        CGSize rotationValue = SVGParseOneTransform(part, @"rotate");
        if (ABS(rotationValue.width) > 0.001) {
            rotation = rotationValue.width;
        }
        CGSize scaleValue = SVGParseOneTransform(part, @"scale");
        if (ABS(scaleValue.width) > 0.001 && (ABS(scaleValue.width - 1.0) > 0.001 || ABS(scaleValue.height - 1.0) > 0.001)) {
            scale = scaleValue;
        }
    }
    return CGAffineTransformMake(rotation, scale.width, scale.height, 0.0, 0.0, 0.0);
}

@implementation GiftPatternData

@end

@implementation GiftPatternRect

@end


@interface SvgXMLParsingDelegate : NSObject <NSXMLParserDelegate>
@property (nonatomic, strong, readonly) NSMutableDictionary<NSString *, NSString *> *styles;
@property (nonatomic, strong) NSMutableArray<GiftPatternRect *> *giftRects;
@end

@implementation SvgXMLParsingDelegate {
    NSString *_elementName;
    NSMutableString *_currentStyleString;
    
    bool _inGiftPatterns;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _styles = [[NSMutableDictionary alloc] init];
        _currentStyleString = [[NSMutableString alloc] init];
        _giftRects = [NSMutableArray array];
        _inGiftPatterns = false;
    }
    return self;
}

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary<NSString *,NSString *> *)attributeDict {
    _elementName = [elementName copy];
    
    if ([_elementName isEqualToString:@"g"]) {
        NSString *gid = attributeDict[@"id"];
        if ([[gid lowercaseString] isEqualToString:@"giftpatterns"]) {
            _inGiftPatterns = true;
        }
    } else if (_inGiftPatterns && [_elementName isEqualToString:@"rect"]) {
        CGFloat x = attributeDict[@"x"] ? attributeDict[@"x"].doubleValue : 0;
        CGFloat y = attributeDict[@"y"] ? attributeDict[@"y"].doubleValue : 0;
        CGFloat w = attributeDict[@"width"]  ? attributeDict[@"width"].doubleValue  : 0;
        CGFloat h = attributeDict[@"height"] ? attributeDict[@"height"].doubleValue : 0;
        
        CGFloat side = MAX(w, h);
        
        CGAffineTransform fakeTransform = CGAffineTransformMake(0.0, 1.0, 1.0, 0.0, 0.0, 0.0);
        NSString *rt = attributeDict[@"transform"];
        if (rt.length) {
            fakeTransform = SVGParseTransformList(rt);
        }
        
        CGPoint rectCenter = CGPointMake(x + w * 0.5, y + h * 0.5);
            
        GiftPatternRect *rec = [GiftPatternRect new];
        rec.center = rectCenter;
        rec.side = side;
        rec.rotation = fakeTransform.a;
        rec.scale = fakeTransform.b;
        [_giftRects addObject:rec];
    }
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName {
    if ([_elementName isEqualToString:@"style"] && _currentStyleString.length > 0) {
        [self parseStyleString:_currentStyleString];
        [_currentStyleString setString:@""];
    }
    if ([_elementName isEqualToString:@"g"] && _inGiftPatterns) {
        _inGiftPatterns = false;
    }
    _elementName = nil;
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string {
    if ([_elementName isEqualToString:@"style"]) {
        [_currentStyleString appendString:string];
    }
}

- (void)parseStyleString:(NSString *)styleString {
    NSError *error = nil;
    NSRegularExpression *regex = [NSRegularExpression
        regularExpressionWithPattern:@"\\.([a-zA-Z0-9_-]+)\\s*\\{([^}]+)\\}"
        options:0 error:&error];
    
    if (error) {
        [self parseStyleStringLegacy:styleString];
        return;
    }
    
    [regex enumerateMatchesInString:styleString options:0 range:NSMakeRange(0, styleString.length) usingBlock:^(NSTextCheckingResult *match, NSMatchingFlags flags, BOOL *stop) {
        if (match.numberOfRanges >= 3) {
            NSString *className = [styleString substringWithRange:[match rangeAtIndex:1]];
            NSString *classContents = [styleString substringWithRange:[match rangeAtIndex:2]];
            self.styles[className] = [classContents stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]];
        }
    }];
}

- (void)parseStyleStringLegacy:(NSString *)styleString {
    NSInteger currentClassNameStartIndex = -1;
    NSInteger currentClassContentsStartIndex = -1;
    NSString *currentClassName = nil;
    NSCharacterSet *classNameChars = [NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-"];
    
    for (NSInteger i = 0; i < styleString.length; i++) {
        unichar c = [styleString characterAtIndex:i];
        
        if (currentClassNameStartIndex != -1) {
            if (![classNameChars characterIsMember:c]) {
                currentClassName = [styleString substringWithRange:NSMakeRange(currentClassNameStartIndex, i - currentClassNameStartIndex)];
                currentClassNameStartIndex = -1;
            }
        } else if (currentClassContentsStartIndex != -1) {
            if (c == '}') {
                NSString *classContents = [styleString substringWithRange:NSMakeRange(currentClassContentsStartIndex, i - currentClassContentsStartIndex)];
                if (currentClassName.length > 0 && classContents.length > 0) {
                    self.styles[currentClassName] = [classContents stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                }
                currentClassName = nil;
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

@end

void renderShape(NSVGshape *shape, CGContextRef context, UIColor *foregroundColor) {
    if (shape->fill.type != NSVG_PAINT_NONE) {
        CGContextSetFillColorWithColor(context, [foregroundColor colorWithAlphaComponent:shape->opacity].CGColor);
        
        CGContextBeginPath(context);
        bool isFirstPath = true;
        
        for (NSVGpath *path = shape->paths; path; path = path->next) {
            if (!isFirstPath && path->closed) {
                CGContextBeginPath(context);
            }
            
            CGContextMoveToPoint(context, path->pts[0], path->pts[1]);
            
            for (int i = 0; i < path->npts - 1; i += 3) {
                float *p = &path->pts[i * 2];
                CGContextAddCurveToPoint(context, p[2], p[3], p[4], p[5], p[6], p[7]);
            }
            
            if (path->closed) {
                CGContextClosePath(context);
            }
            
            isFirstPath = NO;
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
    
    if (shape->stroke.type != NSVG_PAINT_NONE && shape->strokeWidth > 0) {
        CGContextSetStrokeColorWithColor(context, [foregroundColor colorWithAlphaComponent:shape->opacity].CGColor);
        CGContextSetLineWidth(context, shape->strokeWidth);
        CGContextSetMiterLimit(context, shape->miterLimit);
        
        switch (shape->strokeLineCap) {
            case NSVG_CAP_ROUND: CGContextSetLineCap(context, kCGLineCapRound); break;
            case NSVG_CAP_SQUARE: CGContextSetLineCap(context, kCGLineCapSquare); break;
            default: CGContextSetLineCap(context, kCGLineCapButt); break;
        }
        
        switch (shape->strokeLineJoin) {
            case NSVG_JOIN_BEVEL: CGContextSetLineJoin(context, kCGLineJoinBevel); break;
            case NSVG_JOIN_ROUND: CGContextSetLineJoin(context, kCGLineJoinRound); break;
            default: CGContextSetLineJoin(context, kCGLineJoinMiter); break;
        }
        
        for (NSVGpath *path = shape->paths; path; path = path->next) {
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

UIImage * _Nullable drawSvgImage(NSData * _Nonnull data, CGSize size, UIColor *backgroundColor, UIColor *foregroundColor, CGFloat canvasScale, bool opaque) {
    if (!data || data.length == 0) return nil;
    
    NSXMLParser *parser = [[NSXMLParser alloc] initWithData:data];
    if (!parser) return nil;
    
    SvgXMLParsingDelegate *delegate = [[SvgXMLParsingDelegate alloc] init];
    parser.delegate = delegate;
    if (![parser parse]) return nil;
    
    NSMutableString *xmlString = [[NSMutableString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (!xmlString) return nil;
    
    for (NSString *styleName in delegate.styles) {
        NSString *styleValue = delegate.styles[styleName];
        NSString *searchPattern = [NSString stringWithFormat:@"class=\"%@\"", styleName];
        NSString *replacement = [NSString stringWithFormat:@"style=\"%@\"", styleValue];
        [xmlString replaceOccurrencesOfString:searchPattern withString:replacement
                                      options:NSLiteralSearch range:NSMakeRange(0, xmlString.length)];
    }
    
    const char *svgString = xmlString.UTF8String;
    NSVGimage *image = nsvgParse((char *)svgString, "px", 96);
    if (!image || image->width < 1.0f || image->height < 1.0f) {
        if (image) nsvgDelete(image);
        return nil;
    }
    
    CGSize originalSize = CGSizeMake(image->width, image->height);
    if (CGSizeEqualToSize(size, CGSizeZero)) {
        size = originalSize;
    }
    
    UIGraphicsBeginImageContextWithOptions(size, opaque, canvasScale);
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (!context) {
        nsvgDelete(image);
        return nil;
    }
    
    if (backgroundColor) {
        CGContextSetFillColorWithColor(context, backgroundColor.CGColor);
        CGContextFillRect(context, CGRectMake(0, 0, size.width, size.height));
    }
    
    CGSize drawingSize = aspectFillSize(originalSize, size);
    CGFloat scale = MAX(size.width / originalSize.width, size.height / originalSize.height);
    CGFloat offsetX = (size.width - drawingSize.width) / (2.0 * scale);
    CGFloat offsetY = (size.height - drawingSize.height) / (2.0 * scale);
    
    CGContextScaleCTM(context, scale, scale);
    CGContextTranslateCTM(context, offsetX, offsetY);
    
    for (NSVGshape *shape = image->shapes; shape; shape = shape->next) {
        if (!(shape->flags & NSVG_FLAGS_VISIBLE) || shape->opacity <= 0) continue;
        
        renderShape(shape, context, foregroundColor);
    }
    
    UIImage *resultImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    nsvgDelete(image);
    
    return resultImage;
}

typedef NS_ENUM(uint8_t, SvgRenderCommand) {
    SvgRenderCommandSetFillColorWithOpacity = 1,
    SvgRenderCommandSetupStroke = 2,
    SvgRenderCommandBeginPath = 3,
    SvgRenderCommandMoveTo = 4,
    SvgRenderCommandLineTo = 5,
    SvgRenderCommandCurveTo = 6,
    SvgRenderCommandClosePath = 7,
    SvgRenderCommandEOFillPath = 8,
    SvgRenderCommandFillPath = 9,
    SvgRenderCommandStrokePath = 10,
    SvgRenderCommandSetFillColorRGBA = 11,
    SvgRenderCommandRectsHeader = 100,
    SvgRenderCommandRectsItem = 101
};

@interface CGContextCoder : NSObject
@property (nonatomic, readonly) NSData *data;
@end

@implementation CGContextCoder {
    NSMutableData *_data;
}

- (instancetype)initWithSize:(CGSize)size {
    self = [super init];
    if (self) {
        _data = [[NSMutableData alloc] init];
        
        int32_t intWidth = (int32_t)size.width;
        int32_t intHeight = (int32_t)size.height;
        [_data appendBytes:&intWidth length:sizeof(intWidth)];
        [_data appendBytes:&intHeight length:sizeof(intHeight)];
    }
    return self;
}

- (void)setFillColorWithOpacity:(CGFloat)opacity {
    uint8_t command = SvgRenderCommandSetFillColorWithOpacity;
    uint8_t intOpacity = (uint8_t)(CLAMP(opacity, 0.0, 1.0) * 255.0);
    
    [_data appendBytes:&command length:sizeof(command)];
    [_data appendBytes:&intOpacity length:sizeof(intOpacity)];
}

- (void)setupStrokeOpacity:(CGFloat)opacity miterLimit:(CGFloat)miterLimit lineWidth:(CGFloat)lineWidth lineCap:(CGLineCap)lineCap lineJoin:(CGLineJoin)lineJoin {
    uint8_t command = SvgRenderCommandSetupStroke;
    uint8_t intOpacity = (uint8_t)(CLAMP(opacity, 0.0, 1.0) * 255.0);
    float floatMiterLimit = (float)miterLimit;
    float floatLineWidth = (float)lineWidth;
    uint8_t intLineCap = (uint8_t)lineCap;
    uint8_t intLineJoin = (uint8_t)lineJoin;
    
    [_data appendBytes:&command length:sizeof(command)];
    [_data appendBytes:&intOpacity length:sizeof(intOpacity)];
    [_data appendBytes:&floatMiterLimit length:sizeof(floatMiterLimit)];
    [_data appendBytes:&floatLineWidth length:sizeof(floatLineWidth)];
    [_data appendBytes:&intLineCap length:sizeof(intLineCap)];
    [_data appendBytes:&intLineJoin length:sizeof(intLineJoin)];
}

- (void)beginPath {
    uint8_t command = SvgRenderCommandBeginPath;
    [_data appendBytes:&command length:sizeof(command)];
}

- (void)moveToPoint:(CGPoint)point {
    uint8_t command = SvgRenderCommandMoveTo;
    float x = (float)point.x, y = (float)point.y;
    
    [_data appendBytes:&command length:sizeof(command)];
    [_data appendBytes:&x length:sizeof(x)];
    [_data appendBytes:&y length:sizeof(y)];
}

- (void)addLineToPoint:(CGPoint)point {
    uint8_t command = SvgRenderCommandLineTo;
    float x = (float)point.x, y = (float)point.y;
    
    [_data appendBytes:&command length:sizeof(command)];
    [_data appendBytes:&x length:sizeof(x)];
    [_data appendBytes:&y length:sizeof(y)];
}

- (void)addCurveToPoint:(CGPoint)p1 p2:(CGPoint)p2 p3:(CGPoint)p3 {
    uint8_t command = SvgRenderCommandCurveTo;
    float coords[6] = {(float)p1.x, (float)p1.y, (float)p2.x, (float)p2.y, (float)p3.x, (float)p3.y};
    
    [_data appendBytes:&command length:sizeof(command)];
    [_data appendBytes:coords length:sizeof(coords)];
}

- (void)closePath {
    uint8_t command = SvgRenderCommandClosePath;
    [_data appendBytes:&command length:sizeof(command)];
}

- (void)eoFillPath {
    uint8_t command = SvgRenderCommandEOFillPath;
    [_data appendBytes:&command length:sizeof(command)];
}

- (void)fillPath {
    uint8_t command = SvgRenderCommandFillPath;
    [_data appendBytes:&command length:sizeof(command)];
}

- (void)strokePath {
    uint8_t command = SvgRenderCommandStrokePath;
    [_data appendBytes:&command length:sizeof(command)];
}

- (void)setFillColor:(uint32_t)color opacity:(CGFloat)opacity {
    uint8_t command = SvgRenderCommandSetFillColorRGBA;
    uint32_t colorWithAlpha = ((uint32_t)(CLAMP(opacity, 0.0, 1.0) * 255.0) << 24) | color;
    
    [_data appendBytes:&command length:sizeof(command)];
    [_data appendBytes:&colorWithAlpha length:sizeof(colorWithAlpha)];
}

- (void)storeGiftPatternRects:(NSArray<GiftPatternRect *> *)rects {
    uint8_t command = SvgRenderCommandRectsHeader;
    [_data appendBytes:&command length:sizeof(command)];
    
    uint32_t count = (uint32_t)rects.count;
    [_data appendBytes:&count length:sizeof(count)];

    for (GiftPatternRect *rect in rects) {
        uint8_t item = SvgRenderCommandRectsItem;
        [_data appendBytes:&item length:sizeof(item)];
        
        float payload[5] = {
            (float)rect.center.x, (float)rect.center.y, (float)rect.side, (float)rect.rotation, (float)rect.scale
        };
        [_data appendBytes:payload length:sizeof(payload)];
    }
}

@end

static inline UIColor *colorWithBGRA(uint32_t bgra) {
    return [[UIColor alloc] initWithRed:(((bgra) & 0xff) / 255.0f)
                                  green:(((bgra >> 8) & 0xff) / 255.0f)
                                   blue:(((bgra >> 16) & 0xff) / 255.0f)
                                  alpha:(((bgra >> 24) & 0xff) / 255.0f)];
}

bool processRenderCommand(uint8_t cmd, NSData *data, NSUInteger *ptr, CGContextRef *context, UIColor *foregroundColor) {
    switch (cmd) {
        case SvgRenderCommandSetFillColorWithOpacity: {
            if (*ptr + 1 > data.length) return NO;
            uint8_t opacity;
            [data getBytes:&opacity range:NSMakeRange(*ptr, sizeof(opacity))];
            *ptr += sizeof(opacity);
            if (context != nil) {
                CGContextSetFillColorWithColor(*context, [foregroundColor colorWithAlphaComponent:opacity / 255.0].CGColor);
            }
            break;
        }
            
        case SvgRenderCommandSetupStroke: {
            if (*ptr + 10 > data.length) return NO;
            uint8_t opacity;
            float miterLimit, lineWidth;
            uint8_t lineCap, lineJoin;
            
            [data getBytes:&opacity range:NSMakeRange(*ptr, sizeof(opacity))];
            *ptr += sizeof(opacity);
            [data getBytes:&miterLimit range:NSMakeRange(*ptr, sizeof(miterLimit))];
            *ptr += sizeof(miterLimit);
            [data getBytes:&lineWidth range:NSMakeRange(*ptr, sizeof(lineWidth))];
            *ptr += sizeof(lineWidth);
            [data getBytes:&lineCap range:NSMakeRange(*ptr, sizeof(lineCap))];
            *ptr += sizeof(lineCap);
            [data getBytes:&lineJoin range:NSMakeRange(*ptr, sizeof(lineJoin))];
            *ptr += sizeof(lineJoin);
            
            if (context != nil) {
                CGContextSetStrokeColorWithColor(*context, [foregroundColor colorWithAlphaComponent:opacity / 255.0].CGColor);
                CGContextSetMiterLimit(*context, miterLimit);
                CGContextSetLineWidth(*context, lineWidth);
                CGContextSetLineCap(*context, (CGLineCap)lineCap);
                CGContextSetLineJoin(*context, (CGLineJoin)lineJoin);
            }
            break;
        }
            
        case SvgRenderCommandBeginPath:
            if (context != nil) {
                CGContextBeginPath(*context);
            }
            break;
            
        case SvgRenderCommandMoveTo: {
            if (*ptr + 8 > data.length) return NO;
            float x, y;
            [data getBytes:&x range:NSMakeRange(*ptr, sizeof(x))];
            *ptr += sizeof(x);
            [data getBytes:&y range:NSMakeRange(*ptr, sizeof(y))];
            *ptr += sizeof(y);
            if (context != nil) {
                CGContextMoveToPoint(*context, x, y);
            }
            break;
        }
            
        case SvgRenderCommandLineTo: {
            if (*ptr + 8 > data.length) return NO;
            float x, y;
            [data getBytes:&x range:NSMakeRange(*ptr, sizeof(x))];
            *ptr += sizeof(x);
            [data getBytes:&y range:NSMakeRange(*ptr, sizeof(y))];
            *ptr += sizeof(y);
            if (context != nil) {
                CGContextAddLineToPoint(*context, x, y);
            }
            break;
        }
            
        case SvgRenderCommandCurveTo: {
            if (*ptr + 24 > data.length) return NO;
            float coords[6];
            [data getBytes:coords range:NSMakeRange(*ptr, sizeof(coords))];
            *ptr += sizeof(coords);
            if (context != nil) {
                CGContextAddCurveToPoint(*context, coords[0], coords[1], coords[2], coords[3], coords[4], coords[5]);
            }
            break;
        }
            
        case SvgRenderCommandClosePath:
            if (context != nil) {
                CGContextClosePath(*context);
            }
            break;
            
        case SvgRenderCommandEOFillPath:
            if (context != nil) {
                CGContextEOFillPath(*context);
            }
            break;
            
        case SvgRenderCommandFillPath:
            if (context != nil) {
                CGContextFillPath(*context);
            }
            break;
            
        case SvgRenderCommandStrokePath:
            if (context != nil) {
                CGContextStrokePath(*context);
            }
            break;
            
        case SvgRenderCommandSetFillColorRGBA: {
            if (*ptr + 4 > data.length) return NO;
            uint32_t bgra;
            [data getBytes:&bgra range:NSMakeRange(*ptr, sizeof(bgra))];
            *ptr += sizeof(bgra);
            if (context != nil) {
                CGContextSetFillColorWithColor(*context, colorWithBGRA(bgra).CGColor);
            }
            break;
        }
        case SvgRenderCommandRectsHeader:
            break;
        case SvgRenderCommandRectsItem:
            break;
        default:
            return false;
    }
    return true;
}

GiftPatternData *getGiftPatternData(NSData * _Nonnull data) {
    if (!data || data.length < 8) {
        return nil;
    }
        
    NSUInteger ptr = 0;
    int32_t width, height;
    [data getBytes:&width range:NSMakeRange(ptr, sizeof(width))];
    ptr += sizeof(width);
    [data getBytes:&height range:NSMakeRange(ptr, sizeof(height))];
    ptr += sizeof(height);
    
    NSMutableArray<GiftPatternRect *> *rects = [[NSMutableArray alloc] init];
    
    while (ptr < data.length) {
        if (ptr + 1 > data.length) break;
        
        uint8_t cmd;
        [data getBytes:&cmd range:NSMakeRange(ptr, sizeof(cmd))];
        ptr += sizeof(cmd);
        
        if (cmd == SvgRenderCommandRectsHeader) {
            if (ptr + sizeof(uint32_t) > data.length) break;
            uint32_t count = 0;
            [data getBytes:&count range:NSMakeRange(ptr, sizeof(count))];
            ptr += sizeof(count);
            
            for (uint32_t i = 0; i < count; i++) {
                if (ptr + 1 > data.length) { ptr = data.length; break; }
                uint8_t itemCmd = 0;
                [data getBytes:&itemCmd range:NSMakeRange(ptr, sizeof(itemCmd))];
                ptr += sizeof(itemCmd);
                if (itemCmd != SvgRenderCommandRectsItem) {
                    ptr = data.length;
                    break;
                }
                
                if (ptr + sizeof(float) * 5 > data.length) {
                    ptr = data.length;
                    break;
                }
                float payload[5];
                [data getBytes:payload range:NSMakeRange(ptr, sizeof(payload))];
                ptr += sizeof(payload);
                
                GiftPatternRect *rect = [[GiftPatternRect alloc] init];
                rect.center = CGPointMake(payload[0], payload[1]);
                rect.side = payload[2];
                rect.rotation = payload[3];
                rect.scale = payload[4];
                [rects addObject:rect];
            }
            continue;
        }
        
        if (!processRenderCommand(cmd, data, &ptr, nil, [UIColor whiteColor])) {
            break;
        }
    }
    
    GiftPatternData *patternData = [[GiftPatternData alloc] init];
    patternData.size = CGSizeMake(width, height);
    patternData.rects = rects;
    return patternData;
}

UIImage * _Nullable renderPreparedImage(NSData * _Nonnull data, CGSize size, UIColor *backgroundColor, CGFloat scale, bool fit) {
    return renderPreparedImageWithSymbol(data, size, backgroundColor, scale, fit, nil, -1);
}

UIImage * _Nullable renderPreparedImageWithSymbol(NSData * _Nonnull data, CGSize size, UIColor *backgroundColor, CGFloat scale, bool fit, UIImage * _Nullable symbolImage, int32_t modelRectIndex) {
    if (!data || data.length < 8) {
        return nil;
    }
    
    CFTimeInterval startTime = CACurrentMediaTime();
    UIColor *foregroundColor = [UIColor whiteColor];
    
    NSUInteger ptr = 0;
    int32_t width, height;
    [data getBytes:&width range:NSMakeRange(ptr, sizeof(width))];
    ptr += sizeof(width);
    [data getBytes:&height range:NSMakeRange(ptr, sizeof(height))];
    ptr += sizeof(height);
    
    if (width <= 0 || height <= 0) return nil;
    
    CGSize svgSize = CGSizeMake(width, height);
    if (CGSizeEqualToSize(size, CGSizeZero)) {
        size = svgSize;
    }
    
    bool isTransparent = [backgroundColor isEqual:[UIColor clearColor]];
    CGSize drawingSize = fit ? aspectFitSize(svgSize, size) : aspectFillSize(svgSize, size);
    
    if (fit) size = drawingSize;
    
    UIGraphicsBeginImageContextWithOptions(size, !isTransparent, scale);
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (!context) {
        UIGraphicsEndImageContext();
        return nil;
    }
    
    if (isTransparent) {
        CGContextClearRect(context, CGRectMake(0, 0, size.width, size.height));
    } else {
        CGContextSetFillColorWithColor(context, backgroundColor.CGColor);
        CGContextFillRect(context, CGRectMake(0, 0, size.width, size.height));
    }
    
    CGFloat renderScale = fit ? MIN(size.width / svgSize.width, size.height / svgSize.height) : MAX(size.width / svgSize.width, size.height / svgSize.height);
    
    CGContextScaleCTM(context, renderScale, renderScale);
    CGContextTranslateCTM(context, (size.width - drawingSize.width) / (2.0 * renderScale), (size.height - drawingSize.height) / (2.0 * renderScale));
          
    NSMutableArray<GiftPatternRect *> *rects = symbolImage ? [[NSMutableArray alloc] init] : nil;
    
    while (ptr < data.length) {
        if (ptr + 1 > data.length) break;
        
        uint8_t cmd;
        [data getBytes:&cmd range:NSMakeRange(ptr, sizeof(cmd))];
        ptr += sizeof(cmd);
        
        if (cmd == SvgRenderCommandRectsHeader) {
            if (ptr + sizeof(uint32_t) > data.length) break;
            uint32_t count = 0;
            [data getBytes:&count range:NSMakeRange(ptr, sizeof(count))];
            ptr += sizeof(count);
            
            for (uint32_t i = 0; i < count; i++) {
                if (ptr + 1 > data.length) { ptr = data.length; break; }
                uint8_t itemCmd = 0;
                [data getBytes:&itemCmd range:NSMakeRange(ptr, sizeof(itemCmd))];
                ptr += sizeof(itemCmd);
                if (itemCmd != SvgRenderCommandRectsItem) { ptr = data.length; break; }
                
                if (ptr + sizeof(float) * 5 > data.length) { ptr = data.length; break; }
                float payload[5];
                [data getBytes:payload range:NSMakeRange(ptr, sizeof(payload))];
                ptr += sizeof(payload);
                
                if (rects) {
                    GiftPatternRect *rect = [[GiftPatternRect alloc] init];
                    rect.center = CGPointMake(payload[0], payload[1]);
                    rect.side = payload[2];
                    rect.rotation = payload[3];
                    rect.scale = payload[4];
                    [rects addObject:rect];
                }
            }
            continue;
        }
        
        if (!processRenderCommand(cmd, data, &ptr, &context, foregroundColor)) {
            break;
        }
    }
    
    if (symbolImage && rects.count > 0) {
        int32_t index = 0;
        
        NSMutableArray<GiftPatternRect *> *filteredRects = [[NSMutableArray alloc] init];
        for (GiftPatternRect *rect in rects) {
            if (rect.center.y > height * 0.1 && rect.center.y < height * 0.9) {
                [filteredRects addObject:rect];
            }
        }
        modelRectIndex = modelRectIndex % (int32_t)filteredRects.count;
        
        for (GiftPatternRect *rect in filteredRects) {
            if (index != modelRectIndex) {
                CGContextSaveGState(context);
                                
                CGContextTranslateCTM(context, rect.center.x, rect.center.y);
                CGContextRotateCTM(context, rect.rotation);
                
                CGFloat symbolAspectRatio = (symbolImage.size.height > 0.0) ? (symbolImage.size.width / symbolImage.size.height) : 1.0;
                CGFloat drawWidth = rect.side;
                CGFloat drawHeight = rect.side;
                
                if (symbolAspectRatio > 1.0) {
                    drawHeight = drawWidth / symbolAspectRatio;
                } else {
                    drawWidth = drawHeight * symbolAspectRatio;
                }
                
                CGRect symbolRect = CGRectMake(-drawWidth * 0.5, -drawHeight * 0.5, drawWidth, drawHeight);
                [symbolImage drawInRect:symbolRect blendMode:kCGBlendModeNormal alpha:1.0];
                
                CGContextRestoreGState(context);
            }
            index += 1;
        }
    }
    
    UIImage *resultImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    CFTimeInterval deltaTime = CACurrentMediaTime() - startTime;
    NSLog(@"Render time %.0fx%.0f = %.4f seconds", size.width, size.height, deltaTime);
    
    return resultImage;
}

void processShape(NSVGshape *shape, CGContextCoder *context, bool template) {
    if (shape->fill.type != NSVG_PAINT_NONE) {
        if (template) {
            [context setFillColorWithOpacity:shape->opacity];
        } else {
            [context setFillColor:shape->fill.color opacity:shape->opacity];
        }
        
        [context beginPath];
        BOOL hasStartPoint = false;
        CGPoint startPoint = CGPointZero;
        
        for (NSVGpath *path = shape->paths; path; path = path->next) {
            if (!hasStartPoint) {
                hasStartPoint = true;
                startPoint = CGPointMake(path->pts[0], path->pts[1]);
            }
            
            [context moveToPoint:CGPointMake(path->pts[0], path->pts[1])];
            
            for (int i = 0; i < path->npts - 1; i += 3) {
                float *p = &path->pts[i * 2];
                [context addCurveToPoint:CGPointMake(p[2], p[3]) p2:CGPointMake(p[4], p[5]) p3:CGPointMake(p[6], p[7])];
            }
            
            if (path->closed && hasStartPoint) {
                [context addLineToPoint:startPoint];
                hasStartPoint = NO;
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
    
    if (shape->stroke.type != NSVG_PAINT_NONE && shape->strokeWidth > 0) {
        CGLineCap lineCap = kCGLineCapButt;
        CGLineJoin lineJoin = kCGLineJoinMiter;
        
        switch (shape->strokeLineCap) {
            case NSVG_CAP_ROUND: lineCap = kCGLineCapRound; break;
            case NSVG_CAP_SQUARE: lineCap = kCGLineCapSquare; break;
            default: break;
        }
        
        switch (shape->strokeLineJoin) {
            case NSVG_JOIN_BEVEL: lineJoin = kCGLineJoinBevel; break;
            case NSVG_JOIN_ROUND: lineJoin = kCGLineJoinRound; break;
            default: break;
        }
        
        [context setupStrokeOpacity:shape->opacity
                         miterLimit:shape->miterLimit
                          lineWidth:shape->strokeWidth
                            lineCap:lineCap
                           lineJoin:lineJoin];
        
        for (NSVGpath *path = shape->paths; path; path = path->next) {
            [context beginPath];
            [context moveToPoint:CGPointMake(path->pts[0], path->pts[1])];
            
            for (int i = 0; i < path->npts - 1; i += 3) {
                float *p = &path->pts[i * 2];
                [context addCurveToPoint:CGPointMake(p[2], p[3])
                                      p2:CGPointMake(p[4], p[5])
                                      p3:CGPointMake(p[6], p[7])];
            }
            
            if (path->closed) {
                [context closePath];
            }
            [context strokePath];
        }
    }
}

NSData * _Nullable prepareSvgImage(NSData * _Nonnull data, BOOL template) {
    if (!data || data.length == 0) return nil;
    
    CFTimeInterval startTime = CACurrentMediaTime();
    
    NSXMLParser *parser = [[NSXMLParser alloc] initWithData:data];
    if (!parser) return nil;
    
    SvgXMLParsingDelegate *delegate = [[SvgXMLParsingDelegate alloc] init];
    parser.delegate = delegate;
    if (![parser parse]) return nil;
    
    NSMutableString *xmlString = [[NSMutableString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (!xmlString) return nil;
    
    for (NSString *styleName in delegate.styles) {
        NSString *styleValue = delegate.styles[styleName];
        NSString *searchPattern = [NSString stringWithFormat:@"class=\"%@\"", styleName];
        NSString *replacement = [NSString stringWithFormat:@"style=\"%@\"", styleValue];
        [xmlString replaceOccurrencesOfString:searchPattern withString:replacement
                                      options:NSLiteralSearch range:NSMakeRange(0, xmlString.length)];
    }
    
    {
        NSError *err = nil;
        NSRegularExpression *gx = [NSRegularExpression regularExpressionWithPattern:@"<g[^>]*\\bid\\s*=\\s*[\"']GiftPatterns[\"'][^>]*>[\\s\\S]*?</g>" options:NSRegularExpressionCaseInsensitive error:&err];
        if (gx) {
            xmlString = [[gx stringByReplacingMatchesInString:xmlString options:0 range:NSMakeRange(0, xmlString.length) withTemplate:@""] mutableCopy];
        }
    }
    
    const char *svgString = xmlString.UTF8String;
    NSVGimage *image = nsvgParse((char *)svgString, "px", 96);
    if (!image || image->width < 1.0f || image->height < 1.0f) {
        if (image) nsvgDelete(image);
        return nil;
    }
    
    CFTimeInterval parseTime = CACurrentMediaTime() - startTime;
    NSLog(@"Parse time: %.4f seconds", parseTime);
    
    startTime = CACurrentMediaTime();
    CGContextCoder *context = [[CGContextCoder alloc] initWithSize:CGSizeMake(image->width, image->height)];
    
    for (NSVGshape *shape = image->shapes; shape; shape = shape->next) {
        if (!(shape->flags & NSVG_FLAGS_VISIBLE) || shape->opacity <= 0) continue;
        
        processShape(shape, context, template);
    }
    
    nsvgDelete(image);
    
    [context storeGiftPatternRects:delegate.giftRects];
    
    CFTimeInterval prepTime = CACurrentMediaTime() - startTime;
    NSLog(@"Preparation time: %.4f seconds", prepTime);
    
    return context.data;
}
