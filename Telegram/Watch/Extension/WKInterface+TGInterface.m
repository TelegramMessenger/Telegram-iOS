#import "WKInterface+TGInterface.h"
#import "TGWatchCommon.h"
#import <objc/runtime.h>

@implementation WKInterfaceObject (TGInterface)

@dynamic alpha, hidden;

+ (void)load
{
    TGSwizzleMethodImplementation(self.class, @selector(setAlpha:), @selector(tg_setAlpha:));
    TGSwizzleMethodImplementation(self.class, @selector(setHidden:), @selector(tg_setHidden:));
}

- (CGFloat)alpha
{
    return [objc_getAssociatedObject(self, @selector(alpha)) floatValue];
}

- (void)tg_setAlpha:(CGFloat)alpha
{
    objc_setAssociatedObject(self, @selector(alpha), @(alpha), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self tg_setAlpha:alpha];
}

- (bool)isHidden
{
    return [objc_getAssociatedObject(self, @selector(isHidden)) boolValue];
}

- (void)tg_setHidden:(BOOL)hidden
{
    objc_setAssociatedObject(self, @selector(isHidden), @(hidden), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self tg_setHidden:hidden];
}

- (void)_setInitialHidden:(bool)hidden
{
    objc_setAssociatedObject(self, @selector(isHidden), @(hidden), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (CGFloat)width
{
    return [objc_getAssociatedObject(self, @selector(width)) floatValue];
}

- (void)tg_setWidth:(CGFloat)width
{
    objc_setAssociatedObject(self, @selector(width), @(width), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self tg_setWidth:width];
}

- (CGFloat)height
{
    return [objc_getAssociatedObject(self, @selector(height)) floatValue];
}

- (void)tg_setHeight:(CGFloat)height
{
    objc_setAssociatedObject(self, @selector(height), @(height), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self tg_setHeight:height];
}

@end


@implementation WKInterfaceGroup (TGInterface)

+ (void)load
{
    TGSwizzleMethodImplementation(self.class, @selector(setBackgroundColor:), @selector(tg_setBackgroundColor:));
    TGSwizzleMethodImplementation(self.class, @selector(setCornerRadius:), @selector(tg_setCornerRadius:));
}

- (UIColor *)backgroundColor
{
    return objc_getAssociatedObject(self, @selector(backgroundColor));
}

- (void)tg_setBackgroundColor:(UIColor *)backgroundColor
{
    objc_setAssociatedObject(self, @selector(backgroundColor), backgroundColor, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self tg_setBackgroundColor:backgroundColor];
}

- (CGFloat)cornerRadius
{
    return [objc_getAssociatedObject(self, @selector(alpha)) floatValue];
}

- (void)tg_setCornerRadius:(CGFloat)cornerRadius
{
    objc_setAssociatedObject(self, @selector(cornerRadius), @(cornerRadius), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self tg_setCornerRadius:cornerRadius];
}

@end


@implementation WKInterfaceLabel (TGInterface)

@dynamic text, textColor, attributedText;

+ (void)load
{
    TGSwizzleMethodImplementation(self.class, @selector(setText:), @selector(tg_setText:));
    TGSwizzleMethodImplementation(self.class, @selector(setTextColor:), @selector(tg_setTextColor:));
    TGSwizzleMethodImplementation(self.class, @selector(setAttributedText:), @selector(tg_setAttributedText:));
}

- (NSString *)text
{
    return objc_getAssociatedObject(self, @selector(text));
}

- (void)tg_setText:(NSString *)text
{
    objc_setAssociatedObject(self, @selector(text), text, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self tg_setText:text];
}

- (UIColor *)textColor
{
    return objc_getAssociatedObject(self, @selector(textColor));
}

- (void)tg_setTextColor:(UIColor *)textColor
{
    objc_setAssociatedObject(self, @selector(textColor), textColor, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self tg_setTextColor:textColor];
}

- (NSAttributedString *)attributedText
{
    return objc_getAssociatedObject(self, @selector(attributedText));
}

- (void)tg_setAttributedText:(NSAttributedString *)attributedText
{
    objc_setAssociatedObject(self, @selector(attributedText), attributedText, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self tg_setAttributedText:attributedText];
}

- (NSString *)hyphenatedText
{
    return self.attributedText.string;
}

- (void)setHyphenatedText:(NSString *)hyphenatedText
{
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    paragraphStyle.hyphenationFactor = 1.0f;
    
    self.attributedText = [[NSAttributedString alloc] initWithString:hyphenatedText attributes:@{ NSParagraphStyleAttributeName:paragraphStyle }];
}

@end


@implementation WKInterfaceButton (TGInterface)

+ (void)load
{
    TGSwizzleMethodImplementation(self.class, @selector(setTitle:), @selector(tg_setTitle:));
    TGSwizzleMethodImplementation(self.class, @selector(setAttributedTitle:), @selector(tg_setAttributedTitle:));
    TGSwizzleMethodImplementation(self.class, @selector(setTextColor:), @selector(tg_setTextColor:));
}

- (NSString *)title
{
    return objc_getAssociatedObject(self, @selector(title));
}

- (void)tg_setTitle:(NSString *)title
{
    objc_setAssociatedObject(self, @selector(title), title, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self tg_setTitle:title];
}

- (NSAttributedString *)attributedTitle
{
    return objc_getAssociatedObject(self, @selector(attributedTitle));
}

- (void)tg_setAttributedTitle:(NSAttributedString *)attributedTitle
{
    objc_setAssociatedObject(self, @selector(attributedTitle), attributedTitle, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self tg_setAttributedTitle:attributedTitle];
}

- (bool)isEnabled
{
    return [objc_getAssociatedObject(self, @selector(isEnabled)) boolValue];
}

- (void)tg_setEnabled:(BOOL)enabled
{
    objc_setAssociatedObject(self, @selector(isEnabled), @(enabled), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self tg_setEnabled:enabled];
}

@end


@implementation WKInterfaceMap (TGInterface)

+ (void)load
{
    TGSwizzleMethodImplementation(self.class, @selector(setRegion:), @selector(tg_setRegion:));
}

- (MKCoordinateRegion)region
{
    MKCoordinateRegion region = MKCoordinateRegionMake(CLLocationCoordinate2DMake(0.0, 0.0), MKCoordinateSpanMake(0.0, 0.0));

    NSArray *values = objc_getAssociatedObject(self, @selector(region));
    if (values != nil)
        region = MKCoordinateRegionMake([values.firstObject MKCoordinateValue], [values.lastObject MKCoordinateSpanValue]);
    
    return region;
}

- (void)tg_setRegion:(MKCoordinateRegion)region
{
    MKCoordinateRegion currentRegion = self.region;
    
    if (fabs(currentRegion.center.latitude - region.center.latitude) < DBL_EPSILON && fabs(currentRegion.center.longitude - region.center.longitude) < DBL_EPSILON && fabs(currentRegion.span.latitudeDelta - region.span.latitudeDelta) < DBL_EPSILON && fabs(currentRegion.span.longitudeDelta - region.span.longitudeDelta) < DBL_EPSILON)
    {
        return;
    }
    
    NSValue *center = [NSValue valueWithMKCoordinate:region.center];
    NSValue *span = [NSValue valueWithMKCoordinateSpan:region.span];
    if (center != nil && span != nil) {
        objc_setAssociatedObject(self, @selector(region), @[ center, span ], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    [self tg_setRegion:region];
}

- (CLLocationCoordinate2D)centerPinCoordinate
{
    return [objc_getAssociatedObject(self, @selector(centerPinCoordinate)) MKCoordinateValue];
}

- (void)setCenterPinCoordinate:(CLLocationCoordinate2D)centerPinCoordinate
{
    CLLocationCoordinate2D currentCoordinate = self.centerPinCoordinate;
    
    if (fabs(currentCoordinate.latitude - centerPinCoordinate.latitude) < DBL_EPSILON && fabs(currentCoordinate.longitude - centerPinCoordinate.longitude) < DBL_EPSILON)
    {
        return;
    }
    
    [self removeAllAnnotations];
    
    if (fabs(centerPinCoordinate.latitude) > 0 || fabs(centerPinCoordinate.longitude) > 0)
        [self addAnnotation:centerPinCoordinate withPinColor:WKInterfaceMapPinColorRed];
}

@end
