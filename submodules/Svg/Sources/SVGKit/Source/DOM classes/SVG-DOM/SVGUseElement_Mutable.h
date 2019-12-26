#import "SVGUseElement.h"

@interface SVGUseElement ()
@property(nonatomic, strong, readwrite) /*FIXME: should be SVGAnimatedLength instead*/ SVGLength* x;
@property(nonatomic, strong, readwrite) /*FIXME: should be SVGAnimatedLength instead*/ SVGLength* y;
@property(nonatomic, strong, readwrite) /*FIXME: should be SVGAnimatedLength instead*/ SVGLength* width;
@property(nonatomic, strong, readwrite) /*FIXME: should be SVGAnimatedLength instead*/ SVGLength* height;
@property(nonatomic, strong, readwrite) SVGElementInstance* instanceRoot;
@property(nonatomic, strong, readwrite) SVGElementInstance* animatedInstanceRoot;

@end
