#import "SVGSVGElement.h"

@interface SVGSVGElement ()

@property (nonatomic, strong, readwrite) /*FIXME: should be SVGAnimatedLength instead*/ SVGLength* x;
@property (nonatomic, strong, readwrite) /*FIXME: should be SVGAnimatedLength instead*/ SVGLength* y;
@property (nonatomic, strong, readwrite) /*FIXME: should be SVGAnimatedLength instead*/ SVGLength* width;
@property (nonatomic, strong, readwrite) /*FIXME: should be SVGAnimatedLength instead*/ SVGLength* height;
@property (nonatomic, strong, readwrite) NSString* contentScriptType;
@property (nonatomic, strong, readwrite) NSString* contentStyleType;
@property (nonatomic, readwrite) SVGRect viewport;
@property (nonatomic, readwrite) float pixelUnitToMillimeterX;
@property (nonatomic, readwrite) float pixelUnitToMillimeterY;
@property (nonatomic, readwrite) float screenPixelToMillimeterX;
@property (nonatomic, readwrite) float screenPixelToMillimeterY;
@property (nonatomic, readwrite) BOOL useCurrentView;
@property (nonatomic, strong, readwrite) SVGViewSpec* currentView;
@property (nonatomic, readwrite) float currentScale;
@property (nonatomic, strong, readwrite) SVGPoint* currentTranslate;

@end
