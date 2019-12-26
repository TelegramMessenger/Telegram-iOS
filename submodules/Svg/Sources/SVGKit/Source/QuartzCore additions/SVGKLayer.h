#import <QuartzCore/QuartzCore.h>

#import "SVGKit.h"

/**
 * SVGKLayer: this is the "low level" equivalent of SVGKImageView, and allows you to perform e.g. CoreAnimation on the individual elemetns / layers
 within an SVG Image.
 
 NB: this class is MORE COMPLEX than SVGKImageView, and requires you to DO MORE WORK. It is also LOWER PERFORMANCE for basic usage - it expects
 YOU to do the work if you want caching, OpenGL acceration, etc. To give you total access to the rendering, we have to disable all the performance
 optimizations coded into SVGKImageView
 
 Basic usage:
 - NOTE: most of the time, you DO NOT WANT this class, you instead want to use SVGKImageView, which does lots more work for you.
 - Usage as per CALayer:
    - SVGKLayer *skl = [[SVGKLayer alloc] init];
    - skl.SVGImage = [SVGKImage imageNamed:@"image.svg"];
    - [self.view.layer addSublayer: skl];
 
 Advanced usage:
 - Note that EVERY ELEMENT in the original SVG is rendered as a SEPARATE CALayer - you can access all the layers by name, and animate them
 - ...c.f. the demo project (currently "iOS-Demo.xcodeproj" and how we animate the Monkey.svg file, wobbling its head
 
 Performance:
 - NOTE: to give you full control of the layers, I had to delete the "auto-re-rasterize at highest pixel detail". I cannot find a way to make that work with Apple's hierarchy of CALayers (it only works when manually blitting). If anyone can figure this out, we'd all be extermely grateful!
 - NOTE: the way this works - adding all layers individually - can have complex effects on performance. Some SVG files will render surprisingly fast, others surpisingly slow.
 ... you MUST understand Apple's complete rendering system in detail to undertand what's going on (not recommended for beginners!)
 - NOTE: you MUST NOT call SVGKImage.CALayerTree.transform - that will have unexpected side-effects, because of Apple's implementation
 */
@interface SVGKLayer : CALayer

@property(nonatomic,strong) SVGKImage* SVGImage;
@property(nonatomic) BOOL showBorder; /**< mostly for debugging - adds a coloured 1-pixel border around the image */

@property (nonatomic, strong) NSDate* startRenderTime, * endRenderTime; /**< for debugging, lets you know how long it took to add/generate the CALayer (may have been cached! Only SVGKImage knows true times) */

@end
