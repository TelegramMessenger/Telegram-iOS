#import "IDTouchSelectionTestSupport.h"

#import <CoreGraphics/CoreGraphics.h>

typedef struct {
    uint8_t *bytes;
    size_t width;
    size_t height;
    size_t bytesPerRow;
    CGFloat scaleX;
    CGFloat scaleY;
} IDTouchRGBAImage;

static BOOL IDTouchIsNumber(id value) {
    return [value isKindOfClass:NSNumber.class] &&
        CFGetTypeID((__bridge CFTypeRef)value) != CFBooleanGetTypeID();
}

static BOOL IDTouchFiniteNumber(id value, CGFloat *result) {
    if (!IDTouchIsNumber(value) || !isfinite([value doubleValue])) return NO;
    if (result != NULL) *result = (CGFloat)[value doubleValue];
    return YES;
}

static BOOL IDTouchUnsignedNumber(id value, NSUInteger *result) {
    if (!IDTouchIsNumber(value)) return NO;
    NSDecimal number = [value decimalValue];
    NSNumber *zeroValue = @0;
    NSNumber *maximumValue = [NSNumber numberWithUnsignedInteger:NSUIntegerMax];
    NSDecimal zero = zeroValue.decimalValue;
    NSDecimal maximum = maximumValue.decimalValue;
    if (NSDecimalIsNotANumber(&number)) return NO;
    NSDecimal integral = {0};
    NSDecimalRound(&integral, &number, 0, NSRoundPlain);
    if (NSDecimalCompare(&number, &integral) != NSOrderedSame ||
        NSDecimalCompare(&number, &zero) == NSOrderedAscending ||
        NSDecimalCompare(&number, &maximum) == NSOrderedDescending) {
        return NO;
    }
    if (result != NULL) {
        *result = (NSUInteger)[[NSDecimalNumber decimalNumberWithDecimal:number]
            unsignedLongLongValue];
    }
    return YES;
}

static BOOL IDTouchExactKeys(NSDictionary *dictionary, NSArray<NSString *> *keys) {
    return [dictionary isKindOfClass:NSDictionary.class] &&
        [[NSSet setWithArray:dictionary.allKeys] isEqualToSet:[NSSet setWithArray:keys]];
}

static BOOL IDTouchRectContainsRectWithinCoordinatePrecision(CGRect outer, CGRect inner) {
    // Screenshot pixels converted back to points can differ from UIKit geometry by a few
    // floating-point ulps. This allowance is many orders of magnitude below one pixel.
    static const CGFloat coordinatePrecision = 1.0e-9;
    return CGRectGetMinX(inner) >= CGRectGetMinX(outer) - coordinatePrecision &&
        CGRectGetMinY(inner) >= CGRectGetMinY(outer) - coordinatePrecision &&
        CGRectGetMaxX(inner) <= CGRectGetMaxX(outer) + coordinatePrecision &&
        CGRectGetMaxY(inner) <= CGRectGetMaxY(outer) + coordinatePrecision;
}

static BOOL IDTouchParsePoint(NSDictionary *dictionary, CGPoint *result) {
    if (!IDTouchExactKeys(dictionary, @[@"x", @"y"])) return NO;
    CGPoint point = CGPointZero;
    if (!IDTouchFiniteNumber(dictionary[@"x"], &point.x) ||
        !IDTouchFiniteNumber(dictionary[@"y"], &point.y)) {
        return NO;
    }
    if (result != NULL) *result = point;
    return YES;
}

static BOOL IDTouchParseRect(NSDictionary *dictionary, CGRect *result) {
    if (!IDTouchExactKeys(dictionary, @[@"height", @"width", @"x", @"y"])) return NO;
    CGRect rect = CGRectZero;
    if (!IDTouchFiniteNumber(dictionary[@"x"], &rect.origin.x) ||
        !IDTouchFiniteNumber(dictionary[@"y"], &rect.origin.y) ||
        !IDTouchFiniteNumber(dictionary[@"width"], &rect.size.width) ||
        !IDTouchFiniteNumber(dictionary[@"height"], &rect.size.height)) {
        return NO;
    }
    if (result != NULL) *result = rect;
    return YES;
}

BOOL IDTouchSelectionParseStatus(
    id value,
    IDTouchSelectionStatus *status,
    NSArray<NSDictionary<NSString *, id> *> **selectionRects) {
    NSString *string = [value isKindOfClass:NSString.class] ? value : nil;
    NSData *data = [string dataUsingEncoding:NSUTF8StringEncoding];
    if (data == nil) return NO;
    id object = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    NSArray<NSString *> *topKeys = @[
        @"blockCount", @"canonical", @"caret", @"containerCreations",
        @"containerStable", @"contentOffset", @"presentationUpdates", @"scenario",
        @"selection", @"selectionRects", @"state", @"visible",
    ];
    NSMutableArray<NSString *> *expectedTopKeys = [topKeys mutableCopy];
    if ([object isKindOfClass:NSDictionary.class] && object[@"autoscroll"] != nil)
        [expectedTopKeys addObject:@"autoscroll"];
    if ([object isKindOfClass:NSDictionary.class] && object[@"visibleHandles"] != nil)
        [expectedTopKeys addObject:@"visibleHandles"];
    if ([object isKindOfClass:NSDictionary.class] && object[@"backend"] != nil)
        [expectedTopKeys addObject:@"backend"];
    if ([object isKindOfClass:NSDictionary.class] &&
        object[@"selectionContainerIdentity"] != nil)
        [expectedTopKeys addObject:@"selectionContainerIdentity"];
    if ([object isKindOfClass:NSDictionary.class] &&
        object[@"interactionHostTopology"] != nil)
        [expectedTopKeys addObject:@"interactionHostTopology"];
    if (!IDTouchExactKeys(object, expectedTopKeys)) return NO;
    NSDictionary *dictionary = object;
    if (![dictionary[@"canonical"] isKindOfClass:NSString.class] ||
        ![dictionary[@"scenario"] isKindOfClass:NSString.class] ||
        ![dictionary[@"state"] isKindOfClass:NSString.class] ||
        (dictionary[@"backend"] != nil &&
         ![dictionary[@"backend"] isKindOfClass:NSString.class]) ||
        (dictionary[@"selectionContainerIdentity"] != nil &&
         ![dictionary[@"selectionContainerIdentity"]
             isKindOfClass:NSString.class]) ||
        (dictionary[@"interactionHostTopology"] != nil &&
         ![dictionary[@"interactionHostTopology"]
             isKindOfClass:NSDictionary.class]) ||
        CFGetTypeID((__bridge CFTypeRef)dictionary[@"containerStable"]) !=
            CFBooleanGetTypeID()) {
        return NO;
    }
    NSDictionary *autoscroll = dictionary[@"autoscroll"];
    if (autoscroll != nil) {
        if (![autoscroll isKindOfClass:NSDictionary.class] ||
            (autoscroll[@"cancelCount"] != nil &&
             !IDTouchUnsignedNumber(autoscroll[@"cancelCount"], NULL)) ||
            (autoscroll[@"startCount"] != nil &&
             !IDTouchUnsignedNumber(autoscroll[@"startCount"], NULL)) ||
            (autoscroll[@"tickCount"] != nil &&
             !IDTouchUnsignedNumber(autoscroll[@"tickCount"], NULL)) ||
            (autoscroll[@"direction"] != nil &&
             !IDTouchUnsignedNumber(autoscroll[@"direction"], NULL)) ||
            (autoscroll[@"directions"] != nil &&
             !IDTouchUnsignedNumber(autoscroll[@"directions"], NULL)) ||
            (autoscroll[@"lastPoint"] != nil &&
             !IDTouchParsePoint(autoscroll[@"lastPoint"], NULL)) ||
            (autoscroll[@"backend"] != nil &&
             ![autoscroll[@"backend"] isKindOfClass:NSString.class]) ||
            (autoscroll[@"engine"] != nil &&
             ![autoscroll[@"engine"] isKindOfClass:NSString.class]) ||
            (autoscroll[@"active"] != nil &&
             CFGetTypeID((__bridge CFTypeRef)autoscroll[@"active"]) !=
                CFBooleanGetTypeID())) {
            return NO;
        }
    }
    NSArray *visibleHandles = dictionary[@"visibleHandles"];
    if (visibleHandles != nil) {
        if (![visibleHandles isKindOfClass:NSArray.class]) return NO;
        for (id handle in visibleHandles) {
            if (!IDTouchParseRect(handle, NULL)) return NO;
        }
    }

    IDTouchSelectionStatus parsed = {0};
    NSDictionary *selection = dictionary[@"selection"];
    if (!IDTouchExactKeys(selection, @[@"length", @"location"]) ||
        !IDTouchUnsignedNumber(selection[@"location"], &parsed.selection.location) ||
        !IDTouchUnsignedNumber(selection[@"length"], &parsed.selection.length) ||
        !IDTouchParseRect(dictionary[@"caret"], &parsed.caret) ||
        !IDTouchParseRect(dictionary[@"visible"], &parsed.visible) ||
        !IDTouchParsePoint(dictionary[@"contentOffset"], &parsed.contentOffset) ||
        !IDTouchUnsignedNumber(dictionary[@"blockCount"], &parsed.blockCount) ||
        !IDTouchUnsignedNumber(dictionary[@"presentationUpdates"],
                               &parsed.presentationUpdates) ||
        !IDTouchUnsignedNumber(dictionary[@"containerCreations"],
                               &parsed.containerCreations)) {
        return NO;
    }
    parsed.containerStable = [dictionary[@"containerStable"] boolValue];

    NSArray *rectangles = dictionary[@"selectionRects"];
    if (![rectangles isKindOfClass:NSArray.class]) return NO;
    NSArray<NSString *> *rectKeys = @[
        @"containsEnd", @"containsStart", @"direction", @"height", @"width", @"x", @"y",
    ];
    for (id candidate in rectangles) {
        if (!IDTouchExactKeys(candidate, rectKeys)) return NO;
        NSDictionary *rectangle = candidate;
        if (CFGetTypeID((__bridge CFTypeRef)rectangle[@"containsEnd"]) != CFBooleanGetTypeID() ||
            CFGetTypeID((__bridge CFTypeRef)rectangle[@"containsStart"]) != CFBooleanGetTypeID() ||
            !IDTouchIsNumber(rectangle[@"direction"])) {
            return NO;
        }
        CGFloat unused = 0;
        for (NSString *key in @[@"x", @"y", @"width", @"height"]) {
            if (!IDTouchFiniteNumber(rectangle[key], &unused)) return NO;
        }
    }
    if (status != NULL) *status = parsed;
    if (selectionRects != NULL) *selectionRects = rectangles;
    return YES;
}

static IDTouchRGBAImage IDTouchCopyRGBA(XCUIScreenshot *screenshot) {
    IDTouchRGBAImage image = {0};
    CGImageRef source = screenshot.image.CGImage;
    if (source == NULL) return image;
    image.width = CGImageGetWidth(source);
    image.height = CGImageGetHeight(source);
    image.bytesPerRow = image.width * 4;
    image.scaleX = image.width / MAX(screenshot.image.size.width, 1);
    image.scaleY = image.height / MAX(screenshot.image.size.height, 1);
    image.bytes = calloc(image.height, image.bytesPerRow);
    if (image.bytes == NULL) return image;
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(
        image.bytes, image.width, image.height, 8, image.bytesPerRow, colorSpace,
        (CGBitmapInfo)kCGImageAlphaPremultipliedLast | (CGBitmapInfo)kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(colorSpace);
    if (context == NULL) {
        free(image.bytes);
        image.bytes = NULL;
        return image;
    }
    CGContextDrawImage(context, CGRectMake(0, 0, image.width, image.height), source);
    CGContextRelease(context);
    return image;
}

static CGRect IDTouchPixelROI(IDTouchRGBAImage image, CGRect screenRect) {
    if (image.bytes == NULL || CGRectIsNull(screenRect) || CGRectIsEmpty(screenRect)) {
        return CGRectNull;
    }
    CGRect pixels = CGRectIntegral(CGRectMake(screenRect.origin.x * image.scaleX,
                                               screenRect.origin.y * image.scaleY,
                                               screenRect.size.width * image.scaleX,
                                               screenRect.size.height * image.scaleY));
    pixels = CGRectIntersection(pixels, CGRectMake(0, 0, image.width, image.height));
    return CGRectIsNull(pixels) || CGRectIsEmpty(pixels) ? CGRectNull : pixels;
}

BOOL IDTouchSelectionHighlightIsVisible(
    XCUIScreenshot *screenshot,
    NSArray<NSDictionary<NSString *, id> *> *selectionRects,
    IDTouchSelectionStatus status,
    CGRect editorFrame) {
    IDTouchRGBAImage image = IDTouchCopyRGBA(screenshot);
    if (image.bytes == NULL) return NO;
    BOOL visible = NO;
    for (NSDictionary<NSString *, id> *value in selectionRects) {
        CGRect documentRect = CGRectMake(
            [value[@"x"] doubleValue], [value[@"y"] doubleValue],
            [value[@"width"] doubleValue], [value[@"height"] doubleValue]);
        CGRect screenRect = CGRectOffset(
            documentRect,
            CGRectGetMinX(editorFrame) - status.contentOffset.x,
            CGRectGetMinY(editorFrame) - status.contentOffset.y);
        CGRect roi = IDTouchPixelROI(image, screenRect);
        if (CGRectIsNull(roi)) continue;
        NSUInteger bluePixels = 0;
        NSUInteger pixelCount = 0;
        for (size_t y = (size_t)CGRectGetMinY(roi);
             y < (size_t)CGRectGetMaxY(roi); y++) {
            for (size_t x = (size_t)CGRectGetMinX(roi);
                 x < (size_t)CGRectGetMaxX(roi); x++) {
                uint8_t *pixel = image.bytes + y * image.bytesPerRow + x * 4;
                NSUInteger red = pixel[0];
                NSUInteger green = pixel[1];
                NSUInteger blue = pixel[2];
                pixelCount += 1;
                if (pixel[3] > 0 && blue >= 130 && blue >= red + 12 &&
                    blue >= green + 4) {
                    bluePixels += 1;
                }
            }
        }
        NSUInteger minimum = MAX(12U, pixelCount / 25U);
        if (bluePixels >= minimum) {
            visible = YES;
            break;
        }
    }
    free(image.bytes);
    return visible;
}

static CGRect IDTouchComponentBounds(BOOL *mask,
                                     size_t maskWidth,
                                     size_t maskHeight,
                                     size_t start,
                                     NSUInteger *pixelCount) {
    size_t capacity = maskWidth * maskHeight;
    size_t *queue = malloc(capacity * sizeof(size_t));
    if (queue == NULL) return CGRectNull;
    size_t head = 0;
    size_t tail = 0;
    queue[tail++] = start;
    mask[start] = NO;
    size_t minX = start % maskWidth;
    size_t maxX = minX;
    size_t minY = start / maskWidth;
    size_t maxY = minY;
    while (head < tail) {
        size_t current = queue[head++];
        size_t x = current % maskWidth;
        size_t y = current / maskWidth;
        minX = MIN(minX, x);
        maxX = MAX(maxX, x);
        minY = MIN(minY, y);
        maxY = MAX(maxY, y);
        for (NSInteger dy = -1; dy <= 1; dy++) {
            for (NSInteger dx = -1; dx <= 1; dx++) {
                if (dx == 0 && dy == 0) continue;
                NSInteger nextX = (NSInteger)x + dx;
                NSInteger nextY = (NSInteger)y + dy;
                if (nextX < 0 || nextY < 0 || nextX >= (NSInteger)maskWidth ||
                    nextY >= (NSInteger)maskHeight) {
                    continue;
                }
                size_t next = (size_t)nextY * maskWidth + (size_t)nextX;
                if (mask[next]) {
                    mask[next] = NO;
                    queue[tail++] = next;
                }
            }
        }
    }
    free(queue);
    if (pixelCount != NULL) *pixelCount = tail;
    return CGRectMake(minX, minY, maxX - minX + 1, maxY - minY + 1);
}

NSArray<NSValue *> *IDTouchSelectionBlueComponents(XCUIScreenshot *screenshot, CGRect screenRect) {
    IDTouchRGBAImage image = IDTouchCopyRGBA(screenshot);
    CGRect roi = IDTouchPixelROI(image, screenRect);
    if (image.bytes == NULL || CGRectIsNull(roi)) {
        free(image.bytes);
        return @[];
    }
    size_t roiX = (size_t)CGRectGetMinX(roi);
    size_t roiY = (size_t)CGRectGetMinY(roi);
    size_t roiWidth = (size_t)CGRectGetWidth(roi);
    size_t roiHeight = (size_t)CGRectGetHeight(roi);
    BOOL *mask = calloc(roiWidth * roiHeight, sizeof(BOOL));
    if (mask == NULL) {
        free(image.bytes);
        return @[];
    }
    for (size_t y = 0; y < roiHeight; y++) {
        for (size_t x = 0; x < roiWidth; x++) {
            uint8_t *pixel = image.bytes + (roiY + y) * image.bytesPerRow + (roiX + x) * 4;
            NSUInteger red = pixel[0];
            NSUInteger green = pixel[1];
            NSUInteger blue = pixel[2];
            mask[y * roiWidth + x] = pixel[3] > 0 && blue >= 120 &&
                blue > red * 1.25 && blue > green * 1.05;
        }
    }
    NSMutableArray<NSValue *> *components = [NSMutableArray array];
    for (size_t index = 0; index < roiWidth * roiHeight; index++) {
        if (!mask[index]) continue;
        CGRect bounds = IDTouchComponentBounds(mask, roiWidth, roiHeight, index, NULL);
        bounds.origin.x = (bounds.origin.x + roiX) / image.scaleX;
        bounds.origin.y = (bounds.origin.y + roiY) / image.scaleY;
        bounds.size.width /= image.scaleX;
        bounds.size.height /= image.scaleY;
        [components addObject:[NSValue valueWithCGRect:bounds]];
    }
    free(mask);
    free(image.bytes);
    return components.copy;
}

NSArray<NSValue *> *IDTouchSelectionHandleComponents(XCUIScreenshot *screenshot,
                                                     CGRect screenRect) {
    NSMutableArray<NSValue *> *handles = [NSMutableArray array];
    for (NSValue *value in IDTouchSelectionBlueComponents(screenshot, screenRect)) {
        CGRect bounds = value.CGRectValue;
        CGFloat width = CGRectGetWidth(bounds);
        CGFloat height = CGRectGetHeight(bounds);
        if (width >= 2.0 && width <= 40.0 && height >= 6.0 && height <= 64.0) {
            [handles addObject:value];
        }
    }
    return handles.copy;
}

static CGFloat IDTouchDistanceFromPointToRect(CGPoint point, CGRect rect) {
    CGFloat dx = MAX(MAX(CGRectGetMinX(rect) - point.x, 0.0),
                     point.x - CGRectGetMaxX(rect));
    CGFloat dy = MAX(MAX(CGRectGetMinY(rect) - point.y, 0.0),
                     point.y - CGRectGetMaxY(rect));
    return hypot(dx, dy);
}

CGRect IDTouchSelectionMatchedHandle(
    BOOL logicalStart,
    NSArray<NSDictionary<NSString *, id> *> *selectionRects,
    IDTouchSelectionStatus status,
    CGRect editorFrame,
    XCUIScreenshot *screenshot,
    CGFloat maximumDistance) {
    NSString *role = logicalStart ? @"containsStart" : @"containsEnd";
    NSDictionary<NSString *, id> *endpointRect = nil;
    for (NSDictionary<NSString *, id> *candidate in selectionRects) {
        if ([candidate[role] boolValue]) {
            endpointRect = candidate;
            break;
        }
    }
    if (endpointRect == nil) return CGRectNull;

    BOOL rtl = [endpointRect[@"direction"] integerValue] ==
        NSWritingDirectionRightToLeft;
    CGFloat minX = [endpointRect[@"x"] doubleValue];
    CGFloat maxX = minX + [endpointRect[@"width"] doubleValue];
    CGPoint endpoint = CGPointMake(
        CGRectGetMinX(editorFrame) +
            ((logicalStart == rtl) ? maxX : minX) - status.contentOffset.x,
        CGRectGetMinY(editorFrame) + [endpointRect[@"y"] doubleValue] +
            (logicalStart ? 0.0 : [endpointRect[@"height"] doubleValue]) -
            status.contentOffset.y);

    CGRect nearest = CGRectNull;
    CGFloat nearestDistance = CGFLOAT_MAX;
    for (NSValue *value in
            IDTouchSelectionHandleComponents(screenshot, editorFrame)) {
        CGRect candidate = value.CGRectValue;
        CGFloat distance = IDTouchDistanceFromPointToRect(endpoint, candidate);
        if (distance < nearestDistance) {
            nearest = candidate;
            nearestDistance = distance;
        }
    }
    return nearestDistance <= maximumDistance ? nearest : CGRectNull;
}

BOOL IDTouchSelectionIsLoupeSizedRegion(CGRect region) {
    if (CGRectIsNull(region) || CGRectIsInfinite(region) || CGRectIsEmpty(region)) {
        return NO;
    }
    CGFloat width = CGRectGetWidth(region);
    CGFloat height = CGRectGetHeight(region);
    CGFloat aspect = height > 0.0 ? width / height : INFINITY;
    return width >= 36.0 && width <= 180.0 &&
        height >= 36.0 && height <= 180.0 &&
        aspect >= 0.65 && aspect <= 1.55;
}

CGRect IDTouchSelectionLargestChangedRegion(XCUIScreenshot *before,
                                            XCUIScreenshot *during,
                                            CGRect screenRect,
                                            NSUInteger minimumChangedPixels) {
    IDTouchRGBAImage first = IDTouchCopyRGBA(before);
    IDTouchRGBAImage second = IDTouchCopyRGBA(during);
    CGRect firstROI = IDTouchPixelROI(first, screenRect);
    CGRect secondROI = IDTouchPixelROI(second, screenRect);
    if (first.bytes == NULL || second.bytes == NULL || CGRectIsNull(firstROI) ||
        CGRectIsNull(secondROI)) {
        free(first.bytes);
        free(second.bytes);
        return CGRectNull;
    }
    size_t width = MIN((size_t)CGRectGetWidth(firstROI), (size_t)CGRectGetWidth(secondROI));
    size_t height = MIN((size_t)CGRectGetHeight(firstROI), (size_t)CGRectGetHeight(secondROI));
    size_t firstX = (size_t)CGRectGetMinX(firstROI);
    size_t firstY = (size_t)CGRectGetMinY(firstROI);
    size_t secondX = (size_t)CGRectGetMinX(secondROI);
    size_t secondY = (size_t)CGRectGetMinY(secondROI);
    BOOL *mask = calloc(width * height, sizeof(BOOL));
    if (mask == NULL) {
        free(first.bytes);
        free(second.bytes);
        return CGRectNull;
    }
    for (size_t y = 0; y < height; y++) {
        for (size_t x = 0; x < width; x++) {
            uint8_t *a = first.bytes + (firstY + y) * first.bytesPerRow + (firstX + x) * 4;
            uint8_t *b = second.bytes + (secondY + y) * second.bytesPerRow + (secondX + x) * 4;
            mask[y * width + x] = abs((int)a[0] - (int)b[0]) > 24 ||
                abs((int)a[1] - (int)b[1]) > 24 || abs((int)a[2] - (int)b[2]) > 24 ||
                abs((int)a[3] - (int)b[3]) > 24;
        }
    }
    CGRect largest = CGRectNull;
    NSUInteger largestCount = 0;
    for (size_t index = 0; index < width * height; index++) {
        if (!mask[index]) continue;
        NSUInteger count = 0;
        CGRect bounds = IDTouchComponentBounds(mask, width, height, index, &count);
        if (count >= minimumChangedPixels && count > largestCount) {
            largest = bounds;
            largestCount = count;
        }
    }
    if (!CGRectIsNull(largest)) {
        largest.origin.x = (largest.origin.x + secondX) / second.scaleX;
        largest.origin.y = (largest.origin.y + secondY) / second.scaleY;
        largest.size.width /= second.scaleX;
        largest.size.height /= second.scaleY;
    }
    free(mask);
    free(first.bytes);
    free(second.bytes);
    return largest;
}

BOOL IDTouchSelectionResidualRegionsAreConfinedToCaretsAndNotLoupeSized(
    NSArray<NSValue *> *regions,
    NSArray<NSValue *> *caretScreenRects) {
    if (caretScreenRects.count == 0) return NO;
    for (NSValue *value in caretScreenRects) {
        CGRect caret = value.CGRectValue;
        if (CGRectIsNull(caret) || CGRectIsInfinite(caret) || CGRectIsEmpty(caret) ||
            !isfinite(caret.origin.x) || !isfinite(caret.origin.y) ||
            !isfinite(caret.size.width) || !isfinite(caret.size.height)) {
            return NO;
        }
    }
    for (NSValue *value in regions) {
        CGRect region = value.CGRectValue;
        if (CGRectIsNull(region) || CGRectIsInfinite(region) || CGRectIsEmpty(region) ||
            !isfinite(region.origin.x) || !isfinite(region.origin.y) ||
            !isfinite(region.size.width) || !isfinite(region.size.height)) {
            return NO;
        }
        CGFloat width = CGRectGetWidth(region);
        CGFloat height = CGRectGetHeight(region);
        CGFloat aspect = height > 0.0 ? width / height : INFINITY;
        BOOL loupeSized = width >= 36.0 && width <= 180.0 &&
            height >= 36.0 && height <= 180.0 && aspect >= 0.65 && aspect <= 1.55;
        if (loupeSized) return NO;
        BOOL contained = NO;
        for (NSValue *caretValue in caretScreenRects) {
            if (IDTouchRectContainsRectWithinCoordinatePrecision(
                    caretValue.CGRectValue, region)) {
                contained = YES;
                break;
            }
        }
        if (!contained) return NO;
    }
    return YES;
}

NSArray<NSValue *> *IDTouchSelectionChangedRegions(XCUIScreenshot *before,
                                                   XCUIScreenshot *during,
                                                   CGRect screenRect,
                                                   NSUInteger minimumChangedPixels) {
    IDTouchRGBAImage first = IDTouchCopyRGBA(before);
    IDTouchRGBAImage second = IDTouchCopyRGBA(during);
    CGRect firstROI = IDTouchPixelROI(first, screenRect);
    CGRect secondROI = IDTouchPixelROI(second, screenRect);
    if (first.bytes == NULL || second.bytes == NULL || CGRectIsNull(firstROI) ||
        CGRectIsNull(secondROI)) {
        free(first.bytes);
        free(second.bytes);
        return @[];
    }
    size_t width = MIN((size_t)CGRectGetWidth(firstROI), (size_t)CGRectGetWidth(secondROI));
    size_t height = MIN((size_t)CGRectGetHeight(firstROI), (size_t)CGRectGetHeight(secondROI));
    size_t firstX = (size_t)CGRectGetMinX(firstROI);
    size_t firstY = (size_t)CGRectGetMinY(firstROI);
    size_t secondX = (size_t)CGRectGetMinX(secondROI);
    size_t secondY = (size_t)CGRectGetMinY(secondROI);
    BOOL *mask = calloc(width * height, sizeof(BOOL));
    if (mask == NULL) {
        free(first.bytes);
        free(second.bytes);
        return @[];
    }
    for (size_t y = 0; y < height; y++) {
        for (size_t x = 0; x < width; x++) {
            uint8_t *a = first.bytes + (firstY + y) * first.bytesPerRow + (firstX + x) * 4;
            uint8_t *b = second.bytes + (secondY + y) * second.bytesPerRow + (secondX + x) * 4;
            mask[y * width + x] = abs((int)a[0] - (int)b[0]) > 24 ||
                abs((int)a[1] - (int)b[1]) > 24 || abs((int)a[2] - (int)b[2]) > 24 ||
                abs((int)a[3] - (int)b[3]) > 24;
        }
    }
    NSMutableArray<NSValue *> *regions = [NSMutableArray array];
    for (size_t index = 0; index < width * height; index++) {
        if (!mask[index]) continue;
        NSUInteger count = 0;
        CGRect bounds = IDTouchComponentBounds(mask, width, height, index, &count);
        if (count < minimumChangedPixels) continue;
        bounds.origin.x = (bounds.origin.x + secondX) / second.scaleX;
        bounds.origin.y = (bounds.origin.y + secondY) / second.scaleY;
        bounds.size.width /= second.scaleX;
        bounds.size.height /= second.scaleY;
        [regions addObject:[NSValue valueWithCGRect:bounds]];
    }
    free(mask);
    free(first.bytes);
    free(second.bytes);
    return regions.copy;
}
