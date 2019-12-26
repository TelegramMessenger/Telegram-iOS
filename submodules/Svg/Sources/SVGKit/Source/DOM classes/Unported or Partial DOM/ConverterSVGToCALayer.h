#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>

@protocol ConverterSVGToCALayer < NSObject >

/*!
 NB: the returned layer has - as its "name" property - the "identifier" property of the SVGElement that created it;
 but that can be overwritten by applications (for valid reasons), so we ADDITIONALLY store the identifier into a
 custom key - kSVGElementIdentifier - on the CALayer. Because it's a custom key, it's (almost) guaranteed not to be
 overwritten / altered by other application code
 */
- (CALayer *) newLayer;
- (void)layoutLayer:(CALayer *)layer;

@end
