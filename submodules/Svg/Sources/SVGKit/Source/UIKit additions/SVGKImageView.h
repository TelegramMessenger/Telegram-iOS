#import <Foundation/Foundation.h>

#import "SVGKImage.h" // cannot import "SVGKit.h" because that would cause ciruclar imports

/**
 * SVGKit's version of UIImageView - with some improvements over Apple's design. There are multiple versions of this class, for different use cases.
 
 STANDARD USAGE:
   - SVGKImageView *myImageView = [[SVGKFastImageView alloc] initWithSVGKImage: [SVGKImage imageNamed:@"image.svg"]];
   - [self.view addSubview: myImageView];
 
 NB: the "SVGKFastImageView" is the one you want 9 times in 10. The alternative classes (e.g. SVGKLayeredImageView) are for advanced usage.
 
 NB: read the class-comment for each subclass carefully before deciding what to use.
 
 */
@interface SVGKImageView : UIView

@property(nonatomic,strong) SVGKImage* image;
@property(nonatomic) BOOL showBorder; /**< mostly for debugging - adds a coloured 1-pixel border around the image */

@property(nonatomic,readonly) NSTimeInterval timeIntervalForLastReRenderOfSVGFromMemory;

- (id)initWithSVGKImage:(SVGKImage*) im;

@end
