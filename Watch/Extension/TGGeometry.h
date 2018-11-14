#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

@interface TGGeometry : NSObject

CGSize TGFitSize(CGSize size, CGSize maxSize);
CGSize TGFillSize(CGSize size, CGSize maxSize);
CGSize TGScaleToFill(CGSize size, CGSize boundsSize);

@end
