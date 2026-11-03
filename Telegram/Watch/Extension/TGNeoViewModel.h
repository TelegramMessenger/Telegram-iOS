#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

@interface TGNeoViewModel : NSObject

@property (nonatomic, assign) CGRect frame;
@property (nonatomic, readonly) CGRect bounds;
@property (nonatomic, assign) bool hidden;

@property (nonatomic, readonly) NSArray *submodels;
- (void)addSubmodel:(TGNeoViewModel *)viewModel;
- (void)removeSubmodel:(TGNeoViewModel *)viewModel;

- (void)drawInContext:(CGContextRef)context;
- (void)drawSubmodelsInContext:(CGContextRef)context;

- (CGSize)contentSizeWithContainerSize:(CGSize)containerSize;

@end
