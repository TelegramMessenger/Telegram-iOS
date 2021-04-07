#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

@class TGPainting;

@interface TGPaintSlice : NSObject

@property (nonatomic, readonly) CGRect bounds;
@property (nonatomic, readonly) NSData *data;

- (instancetype)initWithData:(NSData *)data bounds:(CGRect)bounds;

- (instancetype)swappedSliceForPainting:(TGPainting *)painting;

@end
