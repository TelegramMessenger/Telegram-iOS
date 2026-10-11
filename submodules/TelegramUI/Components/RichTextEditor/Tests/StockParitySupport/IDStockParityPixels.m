// PORTED from /Users/isaac/Documents/InputDec/Tests/IDTextCanvasTestSupport.m
// @ fdad9ca519f5f27a07362e00dc6cefdcb73ca369.
//
// Everything below the `IDTextCanvasFixture` class is carried over VERBATIM — the pixel predicate in
// particular, because a re-tuned predicate would silently change what "the marker is present" means
// and this file's whole value is that it was not written by us. The `IDTextCanvasFixture` class
// itself is DROPPED: its initializer builds an `IDTextLayoutCanvasView`, upstream product source
// that Global Constraint 12 forbids porting. See ../PROVENANCE.md.

#import "IDStockParityPixels.h"

@import QuartzCore;

#include <stdlib.h>

BOOL IDWaitForCondition(NSTimeInterval timeout, BOOL (^condition)(void)) {
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:MAX(timeout, 0)];
    do {
        if (condition()) {
            return YES;
        }
        [NSRunLoop.mainRunLoop runUntilDate:
            [NSDate dateWithTimeIntervalSinceNow:0.01]];
    } while ([deadline timeIntervalSinceNow] > 0);
    return condition();
}

UIImage *IDRenderView(UIView *view) {
    CGSize size = CGSizeMake(MAX(CGRectGetWidth(view.bounds), 1),
                             MAX(CGRectGetHeight(view.bounds), 1));
    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat];
    format.opaque = NO;
    format.scale = 1.0;
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc]
        initWithSize:size
              format:format];
    return [renderer imageWithActions:^(UIGraphicsImageRendererContext *rendererContext) {
        [view.layer renderInContext:rendererContext.CGContext];
    }];
}

typedef BOOL (^IDPixelPredicate)(const uint8_t *pixel);

static NSArray<NSNumber *> *IDPixelCountsByRow(
    UIImage *image,
    CGRect rect,
    IDPixelPredicate predicate) {
    CGImageRef source = image.CGImage;
    if (source == NULL) {
        return @[];
    }

    size_t width = CGImageGetWidth(source);
    size_t height = CGImageGetHeight(source);
    size_t bytesPerRow = width * 4;
    uint8_t *pixels = calloc(height, bytesPerRow);
    if (pixels == NULL) {
        return @[];
    }

    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGBitmapInfo bitmapInfo = (CGBitmapInfo)kCGImageAlphaPremultipliedLast;
    bitmapInfo |= kCGBitmapByteOrder32Big;
    CGContextRef context = CGBitmapContextCreate(pixels,
                                                 width,
                                                 height,
                                                 8,
                                                 bytesPerRow,
                                                 colorSpace,
                                                 bitmapInfo);
    CGColorSpaceRelease(colorSpace);
    if (context == NULL) {
        free(pixels);
        return @[];
    }
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), source);

    CGFloat scale = image.scale > 0 ? image.scale : 1.0;
    CGRect pixelRect = CGRectIntersection(CGRectMake(0, 0, width, height),
                                          CGRectApplyAffineTransform(
                                              rect,
                                              CGAffineTransformMakeScale(scale, scale)));
    CGRect integralRect = CGRectIntegral(pixelRect);
    size_t minimumX = (size_t)MAX(CGRectGetMinX(integralRect), 0);
    size_t minimumY = (size_t)MAX(CGRectGetMinY(integralRect), 0);
    size_t maximumX = (size_t)MIN(CGRectGetMaxX(integralRect), width);
    size_t maximumY = (size_t)MIN(CGRectGetMaxY(integralRect), height);
    NSMutableArray<NSNumber *> *counts =
        [NSMutableArray arrayWithCapacity:maximumY - minimumY];
    for (size_t y = minimumY; y < maximumY; y++) {
        NSUInteger count = 0;
        for (size_t x = minimumX; x < maximumX; x++) {
            count += predicate(pixels + y * bytesPerRow + x * 4) ? 1 : 0;
        }
        [counts addObject:@(count)];
    }

    CGContextRelease(context);
    free(pixels);
    return counts.copy;
}

static NSUInteger IDCountPixels(
    UIImage *image,
    CGRect rect,
    IDPixelPredicate predicate) {
    NSUInteger count = 0;
    for (NSNumber *rowCount in
         IDPixelCountsByRow(image, rect, predicate)) {
        count += rowCount.unsignedIntegerValue;
    }
    return count;
}

static BOOL IDPixelIsRed(const uint8_t *pixel) {
    NSUInteger red = pixel[0];
    NSUInteger green = pixel[1];
    NSUInteger blue = pixel[2];
    return pixel[3] > 0 &&
        red >= 140 &&
        red * 4 > green * 5 &&
        red * 4 > blue * 5;
}

NSUInteger IDCountRedPixels(UIImage *image, CGRect rect) {
    return IDCountPixels(image, rect, ^BOOL(const uint8_t *pixel) {
        return IDPixelIsRed(pixel);
    });
}

NSArray<NSNumber *> *IDRedPixelCountsByRow(UIImage *image, CGRect rect) {
    return IDPixelCountsByRow(image, rect, ^BOOL(const uint8_t *pixel) {
        return IDPixelIsRed(pixel);
    });
}

NSUInteger IDCountNontransparentPixels(UIImage *image, CGRect rect) {
    return IDCountPixels(image, rect, ^BOOL(const uint8_t *pixel) {
        return pixel[3] > 0;
    });
}
